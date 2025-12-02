"""Cartesian merge algorithm implementation."""

from typing import Dict, List
import pandas as pd
import numpy as np


def cartesian_merge_batch(
    left: pd.DataFrame,
    right: pd.DataFrame,
    id_col: str,
    start_name: str,
    stop_name: str,
    right_exposure_cols: List[str],
    continuous_flags: Dict[str, bool],
    batch_pct: int = 20,
    n_jobs: int = 1,
) -> pd.DataFrame:
    """
    Perform Cartesian merge of two datasets with batch processing.

    Algorithm:
    1. Split IDs into batches
    2. For each batch:
       a. Cross join on ID (Cartesian product within person)
       b. Calculate interval intersection (max start, min stop)
       c. Keep valid intersections (start <= stop)
       d. For continuous exposures, prorate based on overlap
    3. Concatenate batch results

    Parameters
    ----------
    left : pd.DataFrame
        Left dataset (result of previous merges).
    right : pd.DataFrame
        Right dataset to merge.
    id_col : str
        ID column name (should be 'id' in both).
    start_name : str
        Start column name in left.
    stop_name : str
        Stop column name in left.
    right_exposure_cols : List[str]
        Exposure columns from right dataset.
    continuous_flags : Dict[str, bool]
        Mapping of exposure names to continuous flags.
    batch_pct : int
        Percentage of IDs per batch.
    n_jobs : int
        Number of parallel jobs.

    Returns
    -------
    pd.DataFrame
        Merged dataset with interval intersections.
    """
    # Get unique IDs
    unique_ids = left[id_col].unique()
    n_ids = len(unique_ids)

    # Calculate batch parameters
    batch_size = max(1, int(np.ceil(n_ids * (batch_pct / 100))))
    n_batches = int(np.ceil(n_ids / batch_size))

    print(f"    Processing {n_ids:,} unique IDs in {n_batches} batches "
          f"(batch size: {batch_size} IDs = {batch_pct}%)...")

    # Split IDs into batches
    id_batches = [
        unique_ids[i * batch_size:(i + 1) * batch_size]
        for i in range(n_batches)
    ]

    # Process batches
    if n_jobs == 1:
        # Sequential processing
        results = []
        for i, batch_ids in enumerate(id_batches, start=1):
            print(f"      Batch {i}/{n_batches}...")
            batch_result = _process_batch(
                left, right, batch_ids, id_col,
                start_name, stop_name, right_exposure_cols, continuous_flags
            )
            if len(batch_result) > 0:
                results.append(batch_result)
            else:
                print(f"        (batch {i} produced no valid intersections)")

        if not results:
            # No valid intersections - return empty with correct structure
            return _create_empty_result(left, right, right_exposure_cols, continuous_flags)

        return pd.concat(results, ignore_index=True)
    else:
        # Parallel processing with joblib
        from joblib import Parallel, delayed

        results = Parallel(n_jobs=n_jobs)(
            delayed(_process_batch)(
                left, right, batch_ids, id_col,
                start_name, stop_name, right_exposure_cols, continuous_flags
            )
            for batch_ids in id_batches
        )

        # Filter empty results
        results = [r for r in results if len(r) > 0]

        if not results:
            return _create_empty_result(left, right, right_exposure_cols, continuous_flags)

        return pd.concat(results, ignore_index=True)


def _process_batch(
    left: pd.DataFrame,
    right: pd.DataFrame,
    batch_ids: np.ndarray,
    id_col: str,
    start_name: str,
    stop_name: str,
    right_exposure_cols: List[str],
    continuous_flags: Dict[str, bool],
) -> pd.DataFrame:
    """Process a single batch of IDs."""
    # Filter to batch IDs
    left_batch = left[left[id_col].isin(batch_ids)].copy()
    right_batch = right[right[id_col].isin(batch_ids)].copy()

    # Rename right columns temporarily
    right_batch = right_batch.rename(columns={
        f'{start_name}_new': 'start_right',
        f'{stop_name}_new': 'stop_right',
    })

    # Perform cross join (Cartesian product within each ID)
    merged = left_batch.merge(right_batch, on=id_col, how='inner')

    # Calculate intersection
    merged['new_start'] = merged[[start_name, 'start_right']].max(axis=1)
    merged['new_stop'] = merged[[stop_name, 'stop_right']].min(axis=1)

    # Keep only valid intersections
    merged = merged[
        (merged['new_start'] <= merged['new_stop']) &
        merged['new_start'].notna() &
        merged['new_stop'].notna()
    ].copy()

    if len(merged) == 0:
        return pd.DataFrame()

    # For continuous exposures, prorate values
    for exp_col in right_exposure_cols:
        if continuous_flags.get(exp_col, False):
            # Calculate proportion: (overlap_days) / (original_days)
            overlap_days = merged['new_stop'] - merged['new_start'] + 1
            original_days = merged['stop_right'] - merged['start_right'] + 1

            # Avoid division by zero
            proportion = np.where(
                original_days > 0,
                overlap_days / original_days,
                1.0
            )

            # Ensure proportion doesn't exceed 1 (floating point rounding)
            proportion = np.minimum(proportion, 1.0)

            # Create period column
            merged[f'{exp_col}_period'] = merged[exp_col] * proportion

            # Update exposure to be the rate (already is, but make explicit)
            # merged[exp_col] remains unchanged

    # Replace old intervals with intersections
    merged[start_name] = merged['new_start']
    merged[stop_name] = merged['new_stop']

    # Drop temporary columns
    merged = merged.drop(columns=['new_start', 'new_stop', 'start_right', 'stop_right'])

    return merged


def _create_empty_result(
    left: pd.DataFrame,
    right: pd.DataFrame,
    right_exposure_cols: List[str],
    continuous_flags: Dict[str, bool],
) -> pd.DataFrame:
    """Create empty DataFrame with correct structure."""
    # Get all columns from left
    result_cols = list(left.columns)

    # Add exposure columns from right
    for exp_col in right_exposure_cols:
        result_cols.append(exp_col)
        if continuous_flags.get(exp_col, False):
            result_cols.append(f'{exp_col}_period')

    # Create empty DataFrame with correct dtypes
    return pd.DataFrame(columns=result_cols)

"""Diagnostic and validation functions."""

import pandas as pd
from typing import List


def check_coverage(
    df: pd.DataFrame,
    id_col: str,
    start_col: str,
    stop_col: str,
    gap_threshold: int = 1,
) -> pd.DataFrame:
    """
    Check for gaps in person-time coverage.

    Parameters
    ----------
    df : pd.DataFrame
        Merged dataset.
    id_col : str
        ID column name.
    start_col : str
        Start date column name.
    stop_col : str
        Stop date column name.
    gap_threshold : int
        Gap size threshold in days. Default: 1.

    Returns
    -------
    pd.DataFrame
        DataFrame of coverage gaps with columns:
        [id_col, start_col, stop_col, 'gap_days']
    """
    # Sort by ID and start
    df = df.sort_values([id_col, start_col, stop_col]).copy()

    # Calculate gap to next period within each person
    df['_next_start'] = df.groupby(id_col)[start_col].shift(-1)
    df['_gap'] = df['_next_start'] - df[stop_col] - 1

    # Find gaps exceeding threshold
    gaps = df[df['_gap'] > gap_threshold].copy()

    if len(gaps) > 0:
        gaps = gaps[[id_col, start_col, stop_col, '_gap']].rename(
            columns={'_gap': 'gap_days'}
        )
        return gaps

    return pd.DataFrame(columns=[id_col, start_col, stop_col, 'gap_days'])


def check_overlaps(
    df: pd.DataFrame,
    id_col: str,
    start_col: str,
    stop_col: str,
    exposure_cols: List[str],
) -> pd.DataFrame:
    """
    Check for unexpected overlapping periods.

    Overlaps are expected when exposure values differ (Cartesian product).
    This function identifies overlaps where exposure values are IDENTICAL
    (likely data errors).

    Parameters
    ----------
    df : pd.DataFrame
        Merged dataset.
    id_col : str
        ID column name.
    start_col : str
        Start date column name.
    stop_col : str
        Stop date column name.
    exposure_cols : List[str]
        List of exposure column names.

    Returns
    -------
    pd.DataFrame
        DataFrame of unexpected overlaps with columns:
        [id_col, start_col, stop_col]
    """
    # Sort by ID and start
    df = df.sort_values([id_col, start_col, stop_col]).copy()

    # Check if period starts before previous period ends
    df['_prev_stop'] = df.groupby(id_col)[stop_col].shift(1)
    df['_overlap'] = df[start_col] < df['_prev_stop']

    # For overlaps, check if exposures are identical
    df['_same_exposures'] = False

    overlapping = df[df['_overlap']].copy()
    if len(overlapping) > 0:
        for exp_col in exposure_cols:
            if exp_col in df.columns:
                prev_exp = df.groupby(id_col)[exp_col].shift(1)
                df['_same_exposures'] |= (df[exp_col] == prev_exp)

    # Keep only overlaps with identical exposures
    unexpected = df[df['_overlap'] & df['_same_exposures']].copy()

    if len(unexpected) > 0:
        return unexpected[[id_col, start_col, stop_col]]

    return pd.DataFrame(columns=[id_col, start_col, stop_col])


def summarize_dates(
    df: pd.DataFrame,
    start_col: str,
    stop_col: str,
) -> None:
    """
    Display summary statistics for start and stop dates.

    Parameters
    ----------
    df : pd.DataFrame
        Merged dataset.
    start_col : str
        Start date column name.
    stop_col : str
        Stop date column name.
    """
    print(f"\n{'='*50}")
    print("Summary Statistics:")
    print(f"\n{start_col}:")
    print(df[start_col].describe())
    print(f"\n{stop_col}:")
    print(df[stop_col].describe())
    print(f"{'='*50}\n")

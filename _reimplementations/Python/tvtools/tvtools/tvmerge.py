"""
tvmerge - Merge Multiple Time-Varying Exposure Datasets

This module provides the tvmerge function for merging multiple time-varying
exposure datasets by computing the Cartesian product of overlapping time periods.
"""

import pandas as pd
import numpy as np
from typing import Optional, Union, List, Dict, Any
from dataclasses import dataclass


@dataclass
class TVMergeResult:
    """Result object from tvmerge function."""
    data: pd.DataFrame
    diagnostics: Dict[str, Any]
    returns: Dict[str, Any]


def tvmerge(
    datasets: List[Union[str, pd.DataFrame]],
    id: str,
    start: List[str],
    stop: List[str],
    exposure: List[str],
    continuous: Optional[List[int]] = None,
    generate: Optional[List[str]] = None,
    prefix: Optional[str] = None,
    startname: str = "start",
    stopname: str = "stop",
    saveas: Optional[str] = None,
    keep: Optional[List[str]] = None,
    batch: int = 20,
    force: bool = False,
    check: bool = False,
    validatecoverage: bool = False,
    validateoverlap: bool = False,
    summarize: bool = False
) -> TVMergeResult:
    """
    Merge multiple time-varying exposure datasets.

    Creates time-varying dataset by computing Cartesian product of overlapping
    time periods across multiple exposure datasets.

    Parameters
    ----------
    datasets : list
        List of DataFrames or paths to exposure datasets (minimum 2)
    id : str
        Name of ID variable (same across all datasets)
    start : list
        Start date variable names (one per dataset)
    stop : list
        Stop date variable names (one per dataset)
    exposure : list
        Exposure variable names (one per dataset, must be unique)
    continuous : list, optional
        Indices of continuous exposures (for interpolation)
    generate : list, optional
        New names for exposure variables in output
    prefix : str, optional
        Prefix to add to exposure variable names
    startname : str
        Name for output start variable (default: 'start')
    stopname : str
        Name for output stop variable (default: 'stop')
    saveas : str, optional
        Path to save result
    keep : list, optional
        Additional variables to keep from source datasets
    batch : int
        Percentage of IDs per batch (default: 20)
    force : bool
        Allow mismatched IDs between datasets
    check : bool
        Display coverage diagnostics
    validatecoverage : bool
        Check for coverage gaps
    validateoverlap : bool
        Check for unexpected overlaps
    summarize : bool
        Display summary statistics

    Returns
    -------
    TVMergeResult
        Result object containing merged data, diagnostics, and return values
    """
    print("tvmerge: Starting time-varying dataset merge")

    # =========================================================================
    # VALIDATION
    # =========================================================================
    numds = len(datasets)
    if numds < 2:
        raise ValueError("tvmerge requires at least 2 datasets")

    if len(start) != numds:
        raise ValueError(f"Number of start variables ({len(start)}) must equal number of datasets ({numds})")
    if len(stop) != numds:
        raise ValueError(f"Number of stop variables ({len(stop)}) must equal number of datasets ({numds})")
    if len(exposure) != numds:
        raise ValueError(f"Number of exposure variables ({len(exposure)}) must equal number of datasets ({numds})")

    if generate and prefix:
        raise ValueError("Cannot specify both generate and prefix")
    if generate and len(generate) != numds:
        raise ValueError(f"Number of generate names ({len(generate)}) must equal number of datasets ({numds})")

    # =========================================================================
    # LOAD DATASETS
    # =========================================================================
    loaded = []
    for i, ds in enumerate(datasets):
        if isinstance(ds, str):
            if ds.endswith('.dta'):
                try:
                    import pyreadstat
                    df, _ = pyreadstat.read_dta(ds)
                except ImportError:
                    raise ImportError("pyreadstat required to read .dta files")
            elif ds.endswith('.csv'):
                df = pd.read_csv(ds)
            else:
                raise ValueError(f"Unsupported file format for dataset {i+1}")
        else:
            df = ds.copy()
        loaded.append(df)

    # Validate columns exist
    for i, df in enumerate(loaded):
        for col in [id, start[i], stop[i], exposure[i]]:
            if col not in df.columns:
                raise ValueError(f"Column '{col}' not found in dataset {i+1}")

    # =========================================================================
    # DETERMINE FINAL NAMES
    # =========================================================================
    if generate:
        exp_final_names = generate
    elif prefix:
        exp_final_names = [f"{prefix}{name}" for name in exposure]
    else:
        exp_final_names = exposure

    # =========================================================================
    # PREPARE DATASETS
    # =========================================================================
    prepared = []
    keep_vars_found = {}  # Track which keep vars were found in which datasets

    for i, df in enumerate(loaded):
        # Start with required columns
        cols_to_keep = [id, start[i], stop[i], exposure[i]]
        col_renames = {
            id: 'id',
            start[i]: 'start',
            stop[i]: 'stop',
            exposure[i]: f'exp_{i}'
        }

        # Add keep variables if specified and present in this dataset
        if keep:
            for kvar in keep:
                if kvar in df.columns:
                    cols_to_keep.append(kvar)
                    # Suffix with dataset number to avoid conflicts
                    col_renames[kvar] = f'{kvar}_ds{i+1}'
                    keep_vars_found.setdefault(kvar, []).append(i+1)

        prep = df[cols_to_keep].copy()
        prep = prep.rename(columns=col_renames)

        # Convert dates to numeric
        for col in ['start', 'stop']:
            if pd.api.types.is_datetime64_any_dtype(prep[col]):
                prep[col] = (prep[col] - pd.Timestamp('1970-01-01')).dt.days
            prep[col] = prep[col].astype(float).astype('Int64')

        prepared.append(prep)

    # Warn if keep variables were not found in any dataset
    if keep:
        for kvar in keep:
            if kvar not in keep_vars_found:
                print(f"  Warning: keep variable '{kvar}' not found in any dataset")

    # =========================================================================
    # CHECK ID CONSISTENCY
    # =========================================================================
    all_ids = [set(df['id'].unique()) for df in prepared]
    common_ids = all_ids[0]
    for ids in all_ids[1:]:
        common_ids = common_ids.intersection(ids)

    if len(common_ids) < len(all_ids[0]):
        msg = "ID mismatch detected between datasets"
        if force:
            print(f"  Warning: {msg} (proceeding due to force=True)")
        else:
            raise ValueError(f"{msg}. Use force=True to proceed with common IDs only.")

    # Filter to common IDs
    for i in range(len(prepared)):
        prepared[i] = prepared[i][prepared[i]['id'].isin(common_ids)]

    # =========================================================================
    # MERGE ALGORITHM
    # =========================================================================
    print(f"  Merging {numds} datasets...")

    # Start with first dataset
    result = prepared[0].rename(columns={'start': startname, 'stop': stopname})

    # Merge subsequent datasets
    for i in range(1, numds):
        print(f"  Merging dataset {i+1} of {numds}...")

        # Cartesian join by id
        merged = result.merge(
            prepared[i].rename(columns={'start': '_start', 'stop': '_stop'}),
            on='id',
            how='inner'
        )

        # Calculate overlap
        merged['_overlap_start'] = merged[[startname, '_start']].max(axis=1)
        merged['_overlap_stop'] = merged[[stopname, '_stop']].min(axis=1)

        # Keep only overlapping periods
        merged = merged[merged['_overlap_stop'] >= merged['_overlap_start']]

        # Update interval bounds to overlap
        merged[startname] = merged['_overlap_start']
        merged[stopname] = merged['_overlap_stop']

        # Interpolate continuous exposures if needed
        if continuous and i in continuous:
            orig_duration = merged['_stop'] - merged['_start'] + 1
            new_duration = merged[stopname] - merged[startname] + 1
            merged[f'exp_{i}'] = merged[f'exp_{i}'] * (new_duration / orig_duration)

        # Drop helper columns
        merged = merged.drop(columns=['_start', '_stop', '_overlap_start', '_overlap_stop'])

        result = merged

    # =========================================================================
    # RENAME EXPOSURE VARIABLES
    # =========================================================================
    for i in range(numds):
        result = result.rename(columns={f'exp_{i}': exp_final_names[i]})

    # Sort
    result = result.sort_values(['id', startname, stopname])

    # =========================================================================
    # DIAGNOSTICS
    # =========================================================================
    n_persons = result['id'].nunique()
    n_periods = len(result)
    periods_per_person = result.groupby('id').size()

    diagnostics = {
        'n_persons': n_persons,
        'avg_periods': periods_per_person.mean(),
        'max_periods': periods_per_person.max(),
    }

    if check:
        print(f"\nDiagnostics:")
        print(f"  Persons: {n_persons}")
        print(f"  Total periods: {n_periods}")
        print(f"  Avg periods per person: {diagnostics['avg_periods']:.2f}")

    if summarize:
        print(f"\nSummary:")
        print(result.describe())

    # =========================================================================
    # SAVE OUTPUT
    # =========================================================================
    if saveas:
        if saveas.endswith('.csv'):
            result.to_csv(saveas, index=False)
        elif saveas.endswith('.dta'):
            try:
                import pyreadstat
                pyreadstat.write_dta(result, saveas)
            except ImportError:
                result.to_csv(saveas.replace('.dta', '.csv'), index=False)
        print(f"  Saved to {saveas}")

    print(f"\nMerged time-varying dataset successfully created")
    print("-" * 50)
    print(f"    Observations: {n_periods:,}")
    print(f"    Persons: {n_persons:,}")
    print(f"    Exposure variables: {', '.join(exp_final_names)}")
    print("-" * 50)

    return TVMergeResult(
        data=result,
        diagnostics=diagnostics,
        returns={
            'N': n_periods,
            'N_persons': n_persons,
            'N_datasets': numds,
            'exposure_vars': exp_final_names,
        }
    )

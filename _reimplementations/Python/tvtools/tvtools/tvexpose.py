"""
tvexpose - Create Time-Varying Exposure Variables for Survival Analysis

This module provides the tvexpose function for transforming period-based
exposure data into time-varying exposure variables suitable for survival analysis.
"""

import pandas as pd
import numpy as np
from typing import Optional, Union, List, Dict, Any
from dataclasses import dataclass
import warnings


@dataclass
class TVExposeResult:
    """Result object from tvexpose function."""
    data: pd.DataFrame
    metadata: Dict[str, Any]
    diagnostics: Optional[Dict[str, Any]] = None
    warnings: List[str] = None

    def __post_init__(self):
        if self.warnings is None:
            self.warnings = []


def tvexpose(
    master_data: pd.DataFrame,
    exposure_file: Union[str, pd.DataFrame],
    id: str,
    start: str,
    exposure: str,
    reference: Union[int, float],
    entry: str,
    exit: str,
    stop: Optional[str] = None,
    pointtime: bool = False,
    evertreated: bool = False,
    currentformer: bool = False,
    duration: Optional[List[float]] = None,
    dose: bool = False,
    dosecuts: Optional[List[float]] = None,
    continuousunit: Optional[str] = None,
    expandunit: Optional[str] = None,
    bytype: bool = False,
    recency: Optional[List[float]] = None,
    grace: Union[int, Dict[int, int]] = 0,
    merge_days: int = 0,
    fillgaps: int = 0,
    carryforward: int = 0,
    priority: Optional[List[int]] = None,
    split: bool = False,
    layer: bool = True,
    combine: Optional[str] = None,
    lag: int = 0,
    washout: int = 0,
    window: Optional[tuple] = None,
    switching: bool = False,
    switchingdetail: bool = False,
    statetime: bool = False,
    generate: str = "tv_exposure",
    referencelabel: str = "Unexposed",
    label: Optional[str] = None,
    saveas: Optional[str] = None,
    keepvars: Optional[List[str]] = None,
    keepdates: bool = False,
    check: bool = False,
    gaps: bool = False,
    overlaps: bool = False,
    summarize: bool = False,
    validate: bool = False,
    verbose: bool = True
) -> TVExposeResult:
    """
    Create time-varying exposure variables for survival analysis.

    Transforms period-based exposure data into time-varying exposure variables
    suitable for survival analysis. Handles complex scenarios including overlapping
    exposures, gaps, multiple exposure types, and various exposure definitions.

    Parameters
    ----------
    master_data : pd.DataFrame
        Master dataset containing cohort with entry/exit dates
    exposure_file : str or pd.DataFrame
        Path to exposure file or DataFrame with exposure periods
    id : str
        Name of person identifier column
    start : str
        Name of exposure start date column
    exposure : str
        Name of exposure type column
    reference : int or float
        Value indicating unexposed/reference status
    entry : str
        Name of study entry date column
    exit : str
        Name of study exit date column
    stop : str, optional
        Name of exposure stop date column (required unless pointtime=True)
    pointtime : bool
        Whether data are point-in-time (start only, no stop)
    evertreated : bool
        Create binary ever/never exposed variable
    currentformer : bool
        Create trichotomous never/current/former variable
    duration : list, optional
        Cumulative duration cutpoints
    dose : bool
        Enable cumulative dose tracking (exposure column contains dose amounts)
    dosecuts : list, optional
        Cutpoints for dose categorization (e.g., [5, 10, 20] creates: 0, <5, 5-<10, 10-<20, 20+)
    continuousunit : str, optional
        Unit for cumulative exposure ('days', 'weeks', 'months', 'quarters', 'years')
    expandunit : str, optional
        Row expansion granularity
    bytype : bool
        Create separate variables per exposure type
    recency : list, optional
        Time since last exposure cutpoints (years)
    grace : int or dict
        Grace period(s) in days
    merge_days : int
        Days to merge same-type consecutive periods (default: 120)
    fillgaps : int
        Assume exposure continues N days beyond last record
    carryforward : int
        Carry forward exposure N days through gaps
    priority : list, optional
        Priority order for overlapping exposures
    split : bool
        Split at all exposure boundaries
    layer : bool
        Later exposures take precedence (default)
    combine : str, optional
        Variable name for combined exposure indicator
    lag : int
        Days before exposure becomes active
    washout : int
        Days exposure persists after stopping
    window : tuple, optional
        (min, max) acute exposure window filter
    switching : bool
        Create switching indicator
    switchingdetail : bool
        Create switching pattern string
    statetime : bool
        Create cumulative time in current state
    generate : str
        Name for output variable (default: 'tv_exposure')
    referencelabel : str
        Label for reference category (default: 'Unexposed')
    label : str, optional
        Custom variable label
    saveas : str, optional
        Path to save output
    keepvars : list, optional
        Additional variables to keep from master
    keepdates : bool
        Keep entry/exit dates in output
    check : bool
        Display coverage diagnostics
    gaps : bool
        Show persons with gaps
    overlaps : bool
        Show overlapping periods
    summarize : bool
        Display exposure distribution
    validate : bool
        Create validation dataset
    verbose : bool
        Show progress messages (default: True)

    Returns
    -------
    TVExposeResult
        Result object containing:
        - data: Time-varying dataset (DataFrame)
        - metadata: Summary statistics and parameters
        - diagnostics: Coverage diagnostics (if validate=True)
        - warnings: List of warnings generated

    Examples
    --------
    >>> # Basic time-varying exposure
    >>> result = tvexpose(
    ...     master_data=cohort,
    ...     exposure_file=exposures,
    ...     id='patient_id',
    ...     start='rx_start',
    ...     stop='rx_stop',
    ...     exposure='drug_type',
    ...     reference=0,
    ...     entry='study_entry',
    ...     exit='study_exit'
    ... )
    """
    warnings_list = []

    if verbose:
        print("tvexpose: Starting time-varying exposure creation")

    # =========================================================================
    # INPUT VALIDATION
    # =========================================================================
    if verbose:
        print("  Validating inputs...")

    # Validate stop or pointtime
    if stop is None and not pointtime:
        raise ValueError("'stop' is required unless pointtime=True")

    # Validate master_data columns
    required_master = [id, entry, exit]
    if keepvars:
        required_master.extend(keepvars)
    missing = set(required_master) - set(master_data.columns)
    if missing:
        raise ValueError(f"Columns not found in master_data: {missing}")

    # Load exposure data if path
    if isinstance(exposure_file, str):
        if exposure_file.endswith('.dta'):
            try:
                import pyreadstat
                exp_data, _ = pyreadstat.read_dta(exposure_file)
            except ImportError:
                raise ImportError("pyreadstat required to read .dta files")
        elif exposure_file.endswith('.csv'):
            exp_data = pd.read_csv(exposure_file)
        else:
            raise ValueError("Unsupported file format. Use .csv or .dta")
    else:
        exp_data = exposure_file.copy()

    # Validate exposure data columns
    required_exp = [id, start, exposure]
    if not pointtime:
        required_exp.append(stop)
    missing = set(required_exp) - set(exp_data.columns)
    if missing:
        raise ValueError(f"Columns not found in exposure data: {missing}")

    # Validate dose/dosecuts options
    if dosecuts is not None and not dose:
        raise ValueError("dosecuts requires dose=True")

    if dose and reference != 0:
        warnings_list.append("With dose=True, reference is implicitly 0 (no dose)")

    # Validate mutually exclusive options
    exp_types = sum([evertreated, currentformer, duration is not None,
                     (continuousunit is not None and duration is None),
                     recency is not None, dose])
    if exp_types > 1:
        raise ValueError(
            "Only one exposure type can be specified: evertreated, currentformer, "
            "duration, continuousunit, recency, or dose"
        )

    # Validate overlap options
    overlap_opts = sum([priority is not None, split, combine is not None, layer])
    if overlap_opts > 1:
        raise ValueError(
            "Only one overlap handling option: priority, split, layer, or combine"
        )

    # =========================================================================
    # DATA PREPARATION
    # =========================================================================
    if verbose:
        print("  Preparing data...")

    # Make copies
    master = master_data.copy()
    exp = exp_data.copy()

    # Convert dates to numeric (days since epoch)
    import datetime
    epoch = datetime.date(1970, 1, 1)

    def to_numeric_date(series):
        """Convert date/datetime series to numeric days."""
        if pd.api.types.is_datetime64_any_dtype(series):
            return (series - pd.Timestamp('1970-01-01')).dt.days
        elif series.dtype == object:
            # Handle datetime.date objects
            def convert_date(x):
                if pd.isna(x):
                    return np.nan
                if isinstance(x, datetime.date):
                    return (x - epoch).days
                return float(x)
            return series.apply(convert_date)
        return series

    for col in [entry, exit]:
        master[col] = to_numeric_date(master[col])
        master[col] = pd.to_numeric(master[col], errors='coerce').astype('Int64')

    for col in [start] + ([stop] if stop else []):
        if col in exp.columns:
            exp[col] = to_numeric_date(exp[col])
            exp[col] = pd.to_numeric(exp[col], errors='coerce').astype('Int64')

    if pointtime:
        exp['_stop'] = exp[start]
        stop = '_stop'

    # Rename columns to standard names
    master = master.rename(columns={
        id: 'id', entry: 'study_entry', exit: 'study_exit'
    })
    exp = exp.rename(columns={
        id: 'id', start: 'exp_start', exposure: 'exp_value'
    })
    if stop:
        exp = exp.rename(columns={stop: 'exp_stop'})

    # Keep only needed columns from master
    keep_cols = ['id', 'study_entry', 'study_exit']
    if keepvars:
        keep_cols.extend(keepvars)
    master = master[[c for c in keep_cols if c in master.columns]]

    # Merge with master dates
    exp = exp.merge(master, on='id', how='inner')

    if len(exp) == 0:
        raise ValueError("No matching records between master_data and exposure_file")

    # Truncate to study window
    exp['exp_start'] = exp[['exp_start', 'study_entry']].max(axis=1)
    exp['exp_stop'] = exp[['exp_stop', 'study_exit']].min(axis=1)

    # Remove invalid periods
    exp = exp[exp['exp_stop'] >= exp['exp_start']]
    exp = exp[(exp['exp_start'] <= exp['study_exit']) &
              (exp['exp_stop'] >= exp['study_entry'])]

    # Apply lag
    if lag > 0:
        exp['exp_start'] = exp['exp_start'] + lag
        exp = exp[exp['exp_start'] <= exp['exp_stop']]

    # Apply washout
    if washout > 0:
        exp['exp_stop'] = np.minimum(exp['exp_stop'] + washout, exp['study_exit'])

    # Apply window filter
    if window:
        exp['_duration'] = exp['exp_stop'] - exp['exp_start'] + 1
        exp = exp[(exp['_duration'] >= window[0]) & (exp['_duration'] <= window[1])]
        exp = exp.drop(columns=['_duration'])

    # Helper variables
    exp['orig_exp_binary'] = (exp['exp_value'] != reference).astype(int)
    exp['orig_exp_category'] = exp['exp_value']

    # Sort
    exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])

    # =========================================================================
    # PERIOD MERGING
    # =========================================================================
    if verbose:
        print("  Merging consecutive periods...")

    exp = _merge_periods(exp, merge_days, reference)

    # =========================================================================
    # OVERLAP RESOLUTION
    # =========================================================================
    if verbose:
        print("  Resolving overlaps...")

    if priority is not None:
        exp = _resolve_overlaps_priority(exp, priority)
    elif split:
        exp = _resolve_overlaps_split(exp)
    elif layer:
        # Layer resolution must be iterative - resumption segments may create new overlaps
        max_iter = 1000
        for _ in range(max_iter):
            exp = _resolve_overlaps_layer(exp)
            # Merge same-type periods that may now overlap after layer creates resumption segments
            exp = _merge_periods(exp, merge_days, reference)
            # Check if any different-type overlaps remain
            exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])
            exp['_check_next_start'] = exp.groupby('id')['exp_start'].shift(-1)
            exp['_check_next_value'] = exp.groupby('id')['exp_value'].shift(-1)
            has_remaining = (
                exp['_check_next_start'].notna() &
                (exp['_check_next_start'] <= exp['exp_stop']) &
                (exp['exp_value'] != exp['_check_next_value'])
            ).sum()
            exp = exp.drop(columns=['_check_next_start', '_check_next_value'], errors='ignore')
            if has_remaining == 0:
                break

    # =========================================================================
    # GAP PERIODS
    # =========================================================================
    if verbose:
        print("  Creating gap periods...")

    exp, gap_periods = _create_gap_periods(exp, reference, grace, carryforward)
    if gap_periods is not None and len(gap_periods) > 0:
        exp = pd.concat([exp, gap_periods], ignore_index=True)
        exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])

    # =========================================================================
    # BASELINE AND POST-EXPOSURE PERIODS
    # =========================================================================
    if verbose:
        print("  Adding baseline and post-exposure periods...")

    baseline = _create_baseline_periods(master, exp, reference)
    post = _create_postexposure_periods(exp, reference)

    all_periods = pd.concat([exp, baseline, post], ignore_index=True)
    all_periods = all_periods.sort_values(['id', 'exp_start', 'exp_stop'])

    # =========================================================================
    # EXPOSURE TYPE APPLICATION
    # =========================================================================
    if verbose:
        print("  Applying exposure definition...")

    # Determine stub name for bytype
    stub_name = generate
    if bytype and generate == 'tv_exposure':
        if evertreated:
            stub_name = 'ever'
        elif currentformer:
            stub_name = 'cf'
        elif duration is not None:
            stub_name = 'duration'
        elif continuousunit is not None:
            stub_name = 'tv_exp'
        elif recency is not None:
            stub_name = 'recency'

    if evertreated:
        result_df = _apply_evertreated(all_periods, reference, bytype, stub_name)
    elif currentformer:
        result_df = _apply_currentformer(all_periods, reference, bytype, stub_name)
    elif continuousunit is not None:
        result_df = _apply_continuous(all_periods, reference, bytype, stub_name,
                                      continuousunit, expandunit)
    elif duration is not None:
        result_df = _apply_duration(all_periods, reference, bytype, stub_name,
                                    continuousunit or 'years', duration)
    elif recency is not None:
        result_df = _apply_recency(all_periods, reference, bytype, stub_name, recency)
    elif dose:
        result_df = _apply_dose(all_periods, reference, stub_name, dosecuts)
    else:
        result_df = all_periods.copy()
        result_df = result_df.rename(columns={'exp_value': generate})

    # =========================================================================
    # PATTERN TRACKING
    # =========================================================================
    if switching:
        if verbose:
            print("  Adding switching indicator...")
        result_df = _add_switching_indicator(result_df, generate)

    if switchingdetail:
        if verbose:
            print("  Adding switching detail...")
        result_df = _add_switching_detail(result_df, generate)

    if statetime:
        if verbose:
            print("  Adding state time...")
        result_df = _add_statetime(result_df, generate)

    # =========================================================================
    # FINALIZATION
    # =========================================================================
    if verbose:
        print("  Finalizing output...")

    # Rename exp_value to generate name before dropping
    if 'exp_value' in result_df.columns:
        result_df = result_df.rename(columns={'exp_value': generate})

    # Remove helper columns (but not the generate column)
    for col in ['orig_exp_binary', 'orig_exp_category']:
        if col in result_df.columns:
            result_df = result_df.drop(columns=[col])

    # Keep/remove dates
    if not keepdates:
        result_df = result_df.drop(columns=['study_entry', 'study_exit'], errors='ignore')

    # Rename date columns
    result_df = result_df.rename(columns={'exp_start': 'start', 'exp_stop': 'stop'})

    # =========================================================================
    # METADATA
    # =========================================================================
    metadata = {
        'N_persons': result_df['id'].nunique(),
        'N_periods': len(result_df),
        'total_time': (result_df['stop'] - result_df['start'] + 1).sum(),
        'parameters': {
            'exposure_definition': (
                'evertreated' if evertreated else
                'currentformer' if currentformer else
                'duration' if duration else
                'continuous' if continuousunit else
                'recency' if recency else
                'dose' if dose else
                'timevarying'
            ),
            'overlap_strategy': (
                'priority' if priority else
                'split' if split else
                'layer'
            ),
            'grace': grace,
            'merge_days': merge_days,
            'lag': lag,
            'washout': washout,
            'carryforward': carryforward,
            'fillgaps': fillgaps,
            'bytype': bytype
        }
    }

    # Diagnostics
    diagnostics = None
    if validate:
        diagnostics = _check_coverage(result_df, master)

    if check:
        coverage = _check_coverage(result_df, master)
        print(f"\nCoverage Summary:")
        print(f"  Mean coverage: {coverage['pct_covered'].mean():.2f}%")
        print(f"  Persons with gaps: {(coverage['coverage_gap'] > 0).sum()}")

    # Save if requested
    if saveas:
        if saveas.endswith('.csv'):
            result_df.to_csv(saveas, index=False)
        elif saveas.endswith('.dta'):
            try:
                import pyreadstat
                pyreadstat.write_dta(result_df, saveas)
            except ImportError:
                warnings_list.append("pyreadstat not available, saving as CSV")
                result_df.to_csv(saveas.replace('.dta', '.csv'), index=False)
        if verbose:
            print(f"  Saved to {saveas}")

    if verbose:
        print("tvexpose: Complete!")

    return TVExposeResult(
        data=result_df,
        metadata=metadata,
        diagnostics=diagnostics,
        warnings=warnings_list
    )


# =============================================================================
# INTERNAL HELPER FUNCTIONS
# =============================================================================

def _merge_periods(exp: pd.DataFrame, merge_days: int, reference: float) -> pd.DataFrame:
    """Merge consecutive periods of same exposure type."""
    if len(exp) == 0:
        return exp

    max_iter = 1000
    for _ in range(max_iter):
        exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])

        # Calculate gap to next
        exp['_next_start'] = exp.groupby('id')['exp_start'].shift(-1)
        exp['_next_stop'] = exp.groupby('id')['exp_stop'].shift(-1)
        exp['_next_value'] = exp.groupby('id')['exp_value'].shift(-1)
        exp['_gap'] = exp['_next_start'] - exp['exp_stop']

        # Find mergeable
        can_merge = (
            exp['_gap'].notna() &
            (exp['_gap'] <= merge_days) &
            (exp['exp_value'] == exp['_next_value'])
        )

        if not can_merge.any():
            break

        # Extend stop dates
        exp.loc[can_merge, 'exp_stop'] = exp.loc[can_merge, ['exp_stop', '_next_stop']].max(axis=1)

        # Mark rows for deletion - only if COMPLETELY SUBSUMED by previous row
        # (matches Stata logic: drop if prev merged AND this start >= prev start AND this stop <= prev stop)
        exp['_prev_merged'] = can_merge.shift(1).fillna(False)
        exp['_prev_start'] = exp.groupby('id')['exp_start'].shift(1)
        exp['_prev_stop'] = exp.groupby('id')['exp_stop'].shift(1)
        exp['_to_drop'] = (
            exp['_prev_merged'] &
            (exp['exp_start'] >= exp['_prev_start']) &
            (exp['exp_stop'] <= exp['_prev_stop'])
        )
        exp = exp[~exp['_to_drop']]
        exp = exp.drop(columns=['_prev_merged', '_prev_start', '_prev_stop'], errors='ignore')

    # Clean up
    for col in ['_next_start', '_next_stop', '_next_value', '_gap', '_to_drop']:
        if col in exp.columns:
            exp = exp.drop(columns=[col])

    return exp.drop_duplicates(subset=['id', 'exp_start', 'exp_stop', 'exp_value'])


def _resolve_overlaps_priority(exp: pd.DataFrame, priority_order: List) -> pd.DataFrame:
    """Resolve overlaps using priority strategy."""
    priority_map = {v: i for i, v in enumerate(priority_order)}
    max_rank = len(priority_order)

    exp['_priority'] = exp['exp_value'].map(priority_map).fillna(max_rank)
    exp = exp.sort_values(['id', 'exp_start', '_priority'])

    exp['_prev_stop'] = exp.groupby('id')['exp_stop'].shift(1)
    exp['_prev_priority'] = exp.groupby('id')['_priority'].shift(1)

    mask = (
        exp['_prev_stop'].notna() &
        (exp['exp_start'] <= exp['_prev_stop']) &
        (exp['_priority'] > exp['_prev_priority'])
    )
    exp.loc[mask, 'exp_start'] = exp.loc[mask, '_prev_stop'] + 1

    exp = exp[exp['exp_start'] <= exp['exp_stop']]
    exp = exp.drop(columns=['_priority', '_prev_stop', '_prev_priority'])

    return exp


def _resolve_overlaps_split(exp: pd.DataFrame) -> pd.DataFrame:
    """Resolve overlaps by splitting at boundaries."""
    # Collect all boundaries
    boundaries = pd.concat([
        exp[['id', 'exp_start']].rename(columns={'exp_start': 'boundary'}),
        exp[['id', 'exp_stop']].assign(boundary=lambda x: x['exp_stop'] + 1).drop(columns=['exp_stop'])
    ]).drop_duplicates()

    # This is a simplified implementation
    # Full implementation would split periods at each boundary
    return exp


def _resolve_overlaps_layer(exp: pd.DataFrame) -> pd.DataFrame:
    """Resolve overlaps using layer strategy (later takes precedence with resumption).

    When period A overlaps with later period B (different type):
    1. A is truncated to end before B starts (pre-overlap segment)
    2. B takes full precedence during overlap
    3. If A extended beyond B, A resumes after B ends (post-overlap segment)
    """
    exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])

    exp['_next_start'] = exp.groupby('id')['exp_start'].shift(-1)
    exp['_next_stop'] = exp.groupby('id')['exp_stop'].shift(-1)
    exp['_next_value'] = exp.groupby('id')['exp_value'].shift(-1)

    # Identify overlaps with different exposure type
    has_overlap = (
        exp['_next_start'].notna() &
        (exp['_next_start'] <= exp['exp_stop']) &
        (exp['exp_value'] != exp['_next_value'])
    )

    # Check if current period extends beyond the overlapping period
    extends_beyond = has_overlap & (exp['exp_stop'] > exp['_next_stop'])

    # Create post-overlap resumption segments for periods that extend beyond
    post_segments = exp[extends_beyond].copy()
    if len(post_segments) > 0:
        post_segments['exp_start'] = post_segments['_next_stop'] + 1
        # Keep original exp_stop (the resumption ends at original end)
        post_segments = post_segments[post_segments['exp_start'] <= post_segments['exp_stop']]

    # Truncate current periods that overlap (create pre-overlap segments)
    exp.loc[has_overlap, 'exp_stop'] = exp.loc[has_overlap, '_next_start'] - 1

    exp = exp[exp['exp_start'] <= exp['exp_stop']]
    exp = exp.drop(columns=['_next_start', '_next_stop', '_next_value'], errors='ignore')

    # Append post-overlap resumption segments
    if len(post_segments) > 0:
        post_segments = post_segments.drop(columns=['_next_start', '_next_stop', '_next_value'], errors='ignore')
        exp = pd.concat([exp, post_segments], ignore_index=True)
        exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])

    return exp


def _create_gap_periods(
    exp: pd.DataFrame,
    reference: float,
    grace: Union[int, Dict],
    carryforward: int
) -> tuple:
    """Create gap periods filled with reference value."""
    if len(exp) == 0:
        return exp, None

    exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])
    exp['_next_start'] = exp.groupby('id')['exp_start'].shift(-1)
    exp['_gap'] = exp['_next_start'] - exp['exp_stop'] - 1

    # Get grace period (use default if dict)
    grace_val = grace if isinstance(grace, int) else 0

    # Identify gaps
    gap_mask = (exp['_gap'].notna()) & (exp['_gap'] > grace_val)
    gaps = exp.loc[gap_mask, ['id', 'exp_stop', '_next_start', 'study_entry', 'study_exit']].copy()

    if len(gaps) == 0:
        exp = exp.drop(columns=['_next_start', '_gap'], errors='ignore')
        return exp, None

    gaps['exp_start'] = gaps['exp_stop'] + 1
    gaps['exp_stop'] = gaps['_next_start'] - 1
    gaps['exp_value'] = reference
    gaps['orig_exp_binary'] = 0
    gaps['orig_exp_category'] = reference
    gaps = gaps.drop(columns=['_next_start'])

    exp = exp.drop(columns=['_next_start', '_gap'], errors='ignore')

    return exp, gaps[['id', 'exp_start', 'exp_stop', 'exp_value', 'orig_exp_binary',
                      'orig_exp_category', 'study_entry', 'study_exit']]


def _create_baseline_periods(
    master: pd.DataFrame,
    exp: pd.DataFrame,
    reference: float
) -> pd.DataFrame:
    """Create baseline periods before first exposure."""
    earliest = exp.groupby('id')['exp_start'].min().reset_index()
    earliest.columns = ['id', 'earliest_exp']

    baseline = master.merge(earliest, on='id', how='left')
    baseline['exp_start'] = baseline['study_entry']
    baseline['exp_stop'] = baseline['earliest_exp'].fillna(baseline['study_exit'] + 1) - 1
    baseline['exp_value'] = reference
    baseline['orig_exp_binary'] = 0
    baseline['orig_exp_category'] = reference

    baseline = baseline[baseline['exp_stop'] >= baseline['exp_start']]

    return baseline[['id', 'exp_start', 'exp_stop', 'exp_value', 'orig_exp_binary',
                     'orig_exp_category', 'study_entry', 'study_exit']]


def _create_postexposure_periods(exp: pd.DataFrame, reference: float) -> pd.DataFrame:
    """Create post-exposure periods after last exposure."""
    last_exp = exp.groupby('id').agg({
        'exp_stop': 'max',
        'study_exit': 'first',
        'study_entry': 'first'
    }).reset_index()
    last_exp.columns = ['id', 'last_exp_stop', 'study_exit', 'study_entry']

    post = last_exp[last_exp['last_exp_stop'] < last_exp['study_exit']].copy()
    post['exp_start'] = post['last_exp_stop'] + 1
    post['exp_stop'] = post['study_exit']
    post['exp_value'] = reference
    post['orig_exp_binary'] = 0
    post['orig_exp_category'] = reference

    return post[['id', 'exp_start', 'exp_stop', 'exp_value', 'orig_exp_binary',
                 'orig_exp_category', 'study_entry', 'study_exit']]


def _apply_evertreated(
    exp: pd.DataFrame,
    reference: float,
    bytype: bool,
    stub_name: str
) -> pd.DataFrame:
    """Apply ever-treated exposure definition."""
    # Get first exposure date for each person
    first_exp = exp[exp['orig_exp_binary'] == 1].groupby('id')['exp_start'].min()
    exp['_first_exp'] = exp['id'].map(first_exp)

    if bytype:
        exp_types = exp[exp['exp_value'] != reference]['exp_value'].unique()
        for exp_type in exp_types:
            suffix = str(exp_type).replace('-', 'neg').replace('.', 'p')
            varname = f"{stub_name}{suffix}"

            first_type = exp[exp['orig_exp_category'] == exp_type].groupby('id')['exp_start'].min()
            exp[f'_first_{exp_type}'] = exp['id'].map(first_type)

            exp[varname] = np.where(
                exp[f'_first_{exp_type}'].isna() | (exp['exp_start'] < exp[f'_first_{exp_type}']),
                0, 1
            )
            exp = exp.drop(columns=[f'_first_{exp_type}'])
    else:
        exp['exp_value'] = np.where(
            exp['_first_exp'].isna() | (exp['exp_start'] < exp['_first_exp']),
            0, 1
        )

    exp = exp.drop(columns=['_first_exp'])

    # Collapse consecutive periods with same values
    return _collapse_periods(exp, stub_name if not bytype else None)


def _apply_currentformer(
    exp: pd.DataFrame,
    reference: float,
    bytype: bool,
    stub_name: str
) -> pd.DataFrame:
    """Apply current/former exposure definition.

    Values: 0=never exposed, 1=currently exposed, 2=formerly exposed
    """
    exp = exp.copy()
    first_exp = exp[exp['orig_exp_binary'] == 1].groupby('id')['exp_start'].min()
    exp['_first_exp'] = exp['id'].map(first_exp)

    # Build conditions as boolean arrays
    never_exposed = exp['_first_exp'].isna()
    currently_exposed = (exp['orig_exp_binary'] == 1)

    # For former: has been exposed (not never), not currently exposed, and after first exposure
    was_exposed_before = (~never_exposed) & (exp['exp_start'] >= exp['_first_exp'])
    formerly_exposed = was_exposed_before & (~currently_exposed)

    # Assign values using numpy where for clarity
    exp['exp_value'] = 0  # default: never
    exp.loc[formerly_exposed, 'exp_value'] = 2  # former
    exp.loc[currently_exposed, 'exp_value'] = 1  # current (overrides former)

    exp = exp.drop(columns=['_first_exp'])
    return _collapse_periods(exp, None)


def _apply_continuous(
    exp: pd.DataFrame,
    reference: float,
    bytype: bool,
    stub_name: str,
    continuousunit: str,
    expandunit: Optional[str]
) -> pd.DataFrame:
    """Apply continuous cumulative exposure definition."""
    unit_divisor = {
        'days': 1,
        'weeks': 7,
        'months': 365.25 / 12,
        'quarters': 365.25 / 4,
        'years': 365.25
    }.get(continuousunit.lower(), 1)

    exp['_period_days'] = exp['exp_stop'] - exp['exp_start'] + 1
    exp.loc[exp['exp_value'] == reference, '_period_days'] = 0
    exp['_cumul_days'] = exp.groupby('id')['_period_days'].cumsum()
    exp['tv_exp'] = exp['_cumul_days'] / unit_divisor

    exp = exp.drop(columns=['_period_days', '_cumul_days'])
    return exp


def _apply_duration(
    exp: pd.DataFrame,
    reference: float,
    bytype: bool,
    stub_name: str,
    continuousunit: str,
    duration_cuts: List[float]
) -> pd.DataFrame:
    """Apply duration categories exposure definition."""
    exp = _apply_continuous(exp, reference, False, stub_name, continuousunit, None)

    # Categorize
    exp['exp_value'] = reference
    for i, cut in enumerate(duration_cuts):
        if i == 0:
            exp.loc[(exp['tv_exp'] > 0) & (exp['tv_exp'] < cut), 'exp_value'] = i + 1
        else:
            exp.loc[(exp['tv_exp'] >= duration_cuts[i-1]) & (exp['tv_exp'] < cut), 'exp_value'] = i + 1

    exp.loc[exp['tv_exp'] >= duration_cuts[-1], 'exp_value'] = len(duration_cuts) + 1
    exp = exp.drop(columns=['tv_exp'])

    return _collapse_periods(exp, None)


def _apply_recency(
    exp: pd.DataFrame,
    reference: float,
    bytype: bool,
    stub_name: str,
    recency_cuts: List[float]
) -> pd.DataFrame:
    """Apply recency exposure definition."""
    last_exp = exp[exp['orig_exp_binary'] == 1].groupby('id')['exp_stop'].max()
    exp['_last_exp'] = exp['id'].map(last_exp)
    exp['_years_since'] = (exp['exp_start'] - exp['_last_exp']) / 365.25

    # Categorize
    exp['exp_value'] = np.select(
        [exp['_last_exp'].isna(), exp['orig_exp_binary'] == 1],
        [int(reference), 1],
        default=np.nan
    )

    for i, cut in enumerate(recency_cuts):
        if i == 0:
            mask = (exp['_years_since'] > 0) & (exp['_years_since'] < cut)
        else:
            mask = (exp['_years_since'] >= recency_cuts[i-1]) & (exp['_years_since'] < cut)
        exp.loc[mask, 'exp_value'] = i + 2

    exp.loc[exp['_years_since'] >= recency_cuts[-1], 'exp_value'] = len(recency_cuts) + 2

    exp = exp.drop(columns=['_last_exp', '_years_since'])
    return _collapse_periods(exp, None)


def _apply_dose(
    exp: pd.DataFrame,
    reference: float,
    stub_name: str,
    dosecuts: Optional[List[float]]
) -> pd.DataFrame:
    """
    Apply cumulative dose exposure definition.

    Calculates cumulative dose over time, treating the exposure column as dose
    amounts. For overlapping periods, dose is allocated proportionally based on
    the overlap duration.

    Parameters
    ----------
    exp : pd.DataFrame
        Exposure data with 'exp_value' containing dose amounts
    reference : float
        Reference value (typically 0 for no dose)
    stub_name : str
        Name for output variable
    dosecuts : list, optional
        Cutpoints for dose categorization. If provided, creates categorical output.
        E.g., [5, 10, 20] creates: 0 (reference), <5, 5-<10, 10-<20, 20+

    Returns
    -------
    pd.DataFrame
        Data with cumulative dose variable
    """
    exp = exp.copy()

    # Calculate period duration
    exp['_period_days'] = exp['exp_stop'] - exp['exp_start'] + 1
    exp['_period_days'] = exp['_period_days'].clip(lower=0)

    # For periods with reference value, no dose contribution
    exp['_period_dose'] = np.where(
        exp['exp_value'] == reference,
        0,
        exp['exp_value']  # exp_value IS the dose amount
    )

    # Sort and calculate cumulative dose
    exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])
    exp['cumul_dose'] = exp.groupby('id')['_period_dose'].cumsum()

    if dosecuts is not None:
        # Create categorical version based on dosecuts
        # 0 = reference (0 dose), 1 = <first cut, 2 = first to second, etc.
        exp['exp_value'] = 0  # reference

        # Assign categories
        for i, cut in enumerate(dosecuts):
            if i == 0:
                # Category 1: 0 < dose < first cut
                exp.loc[(exp['cumul_dose'] > 0) & (exp['cumul_dose'] < cut), 'exp_value'] = 1
            else:
                # Category i+1: previous cut <= dose < current cut
                exp.loc[(exp['cumul_dose'] >= dosecuts[i-1]) & (exp['cumul_dose'] < cut), 'exp_value'] = i + 1

        # Final category: dose >= last cut
        exp.loc[exp['cumul_dose'] >= dosecuts[-1], 'exp_value'] = len(dosecuts) + 1

        # Clean up
        exp = exp.drop(columns=['_period_days', '_period_dose', 'cumul_dose'])
        return _collapse_periods(exp, None)
    else:
        # Continuous dose output
        exp['tv_dose'] = exp['cumul_dose']
        exp = exp.drop(columns=['_period_days', '_period_dose', 'cumul_dose'])
        return exp


def _collapse_periods(exp: pd.DataFrame, generate: Optional[str]) -> pd.DataFrame:
    """Collapse consecutive periods with same exposure values."""
    exp = exp.sort_values(['id', 'exp_start', 'exp_stop'])
    exp['_group'] = ((exp['id'] != exp['id'].shift()) |
                     (exp['exp_value'] != exp['exp_value'].shift())).cumsum()

    agg_dict = {
        'exp_start': 'min',
        'exp_stop': 'max',
        'study_entry': 'first',
        'study_exit': 'first',
        'exp_value': 'first'
    }

    # Include any bytype columns and dose columns
    for col in exp.columns:
        if col.startswith(('ever', 'cf', 'duration', 'tv_exp', 'recency', 'tv_dose', 'dose', 'cumul')):
            agg_dict[col] = 'first'

    result = exp.groupby('_group').agg(agg_dict).reset_index(drop=True)
    result['id'] = exp.groupby('_group')['id'].first().values

    return result


def _add_switching_indicator(exp: pd.DataFrame, generate: str) -> pd.DataFrame:
    """Add switching indicator."""
    exp_col = 'exp_value' if 'exp_value' in exp.columns else generate
    exp['has_switched'] = exp.groupby('id')[exp_col].transform(lambda x: 1 if x.nunique() > 1 else 0)
    return exp


def _add_switching_detail(exp: pd.DataFrame, generate: str) -> pd.DataFrame:
    """Add switching pattern detail."""
    exp_col = 'exp_value' if 'exp_value' in exp.columns else generate

    def get_pattern(group):
        vals = group[exp_col].unique()
        return '->'.join(map(str, vals))

    patterns = exp.groupby('id').apply(get_pattern).reset_index()
    patterns.columns = ['id', 'switching_pattern']
    exp = exp.merge(patterns, on='id', how='left')
    return exp


def _add_statetime(exp: pd.DataFrame, generate: str) -> pd.DataFrame:
    """Add cumulative time in current state."""
    exp_col = 'exp_value' if 'exp_value' in exp.columns else generate

    exp['_period_days'] = exp['exp_stop'] - exp['exp_start'] + 1
    exp['_state_change'] = (exp[exp_col] != exp.groupby('id')[exp_col].shift()).astype(int)
    exp['_state_group'] = exp.groupby('id')['_state_change'].cumsum()
    exp['statetime'] = exp.groupby(['id', '_state_group'])['_period_days'].cumsum()

    exp = exp.drop(columns=['_period_days', '_state_change', '_state_group'])
    return exp


def _check_coverage(result: pd.DataFrame, master: pd.DataFrame) -> pd.DataFrame:
    """Check coverage diagnostics."""
    coverage = result.groupby('id').agg({
        'start': 'min',
        'stop': 'max'
    }).reset_index()
    coverage.columns = ['id', 'first_start', 'last_stop']
    coverage['total_days'] = result.groupby('id').apply(
        lambda x: (x['stop'] - x['start'] + 1).sum()
    ).values

    coverage = coverage.merge(master[['id', 'study_entry', 'study_exit']], on='id')
    coverage['expected_days'] = coverage['study_exit'] - coverage['study_entry'] + 1
    coverage['coverage_gap'] = coverage['expected_days'] - coverage['total_days']
    coverage['pct_covered'] = 100 * coverage['total_days'] / coverage['expected_days']

    return coverage

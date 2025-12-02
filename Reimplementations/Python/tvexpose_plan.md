# Python Reimplementation Plan: tvexpose

## Overview

`tvexpose` creates time-varying exposure variables for survival analysis from period-based exposure data. This is the most complex command in the tvtools suite with extensive options for exposure definitions, data handling, and overlap resolution.

---

## Module Structure

```
tvtools/
├── __init__.py
├── tvexpose/
│   ├── __init__.py
│   ├── exposer.py          # Main TVExpose class
│   ├── algorithms.py       # Core algorithms (merging, overlap resolution)
│   ├── exposure_types.py   # Exposure definition implementations
│   ├── validators.py       # Input validation
│   ├── exceptions.py       # Custom exceptions
│   └── types.py           # Type definitions and dataclasses
├── tvmerge/
├── tvevent/
└── utils/
    ├── __init__.py
    ├── dates.py           # Date utilities
    └── io.py              # File I/O utilities
```

---

## Type Definitions

```python
# tvexpose/types.py

from dataclasses import dataclass, field
from typing import Optional, Union, List, Dict, Literal
from enum import Enum
import pandas as pd

class ExposureType(Enum):
    """Exposure definition type."""
    TIME_VARYING = "time_varying"      # Default categorical
    EVER_TREATED = "ever_treated"       # Binary 0/1 permanent switch
    CURRENT_FORMER = "current_former"   # Trichotomous 0/1/2
    DURATION = "duration"               # Cumulative duration categories
    CONTINUOUS = "continuous"           # Continuous cumulative
    RECENCY = "recency"                 # Time since last exposure

class OverlapMethod(Enum):
    """Method for handling overlapping exposures."""
    LAYER = "layer"         # Later takes precedence, earlier resumes (default)
    PRIORITY = "priority"   # Static priority order
    SPLIT = "split"         # Create all boundary combinations
    COMBINE = "combine"     # Encode overlaps as combined values

class TimeUnit(Enum):
    """Time units for continuous exposure."""
    DAYS = "days"
    WEEKS = "weeks"
    MONTHS = "months"
    QUARTERS = "quarters"
    YEARS = "years"

    @property
    def days_per_unit(self) -> float:
        """Days per unit for conversion."""
        mapping = {
            "days": 1.0,
            "weeks": 7.0,
            "months": 30.4375,
            "quarters": 91.3125,
            "years": 365.25
        }
        return mapping[self.value]

@dataclass
class GracePeriod:
    """Grace period specification."""
    default: int = 0
    by_category: Optional[Dict[int, int]] = None

    def get_grace(self, exposure_value: int) -> int:
        """Get grace period for an exposure value."""
        if self.by_category and exposure_value in self.by_category:
            return self.by_category[exposure_value]
        return self.default

@dataclass
class TVExposeResult:
    """Result container for tvexpose."""
    data: pd.DataFrame
    n_persons: int
    n_periods: int
    total_time: float
    exposed_time: float
    unexposed_time: float
    pct_exposed: float
    exposure_type: ExposureType
    overlap_ids: Optional[List] = None
    warnings: List[str] = field(default_factory=list)
```

---

## Main Class Design

```python
# tvexpose/exposer.py

from typing import Optional, Union, List, Dict, Literal
import pandas as pd
import numpy as np
from pathlib import Path

from .types import (
    ExposureType, OverlapMethod, TimeUnit,
    GracePeriod, TVExposeResult
)
from .validators import validate_inputs
from .algorithms import (
    merge_periods, remove_contained_periods,
    resolve_overlaps_layer, resolve_overlaps_priority,
    resolve_overlaps_split, resolve_overlaps_combine,
    create_gap_periods, create_baseline_periods,
    create_post_exposure_periods
)
from .exposure_types import (
    apply_ever_treated, apply_current_former,
    apply_duration_categories, apply_continuous_exposure,
    apply_recency_categories, apply_bytype
)
from .exceptions import TVExposeError, ValidationError


class TVExpose:
    """
    Create time-varying exposure variables for survival analysis.

    Parameters
    ----------
    exposure_data : Union[pd.DataFrame, str, Path]
        DataFrame or path to file containing exposure periods.
        Must contain id_col, start_col, exposure_col, and optionally stop_col.
    master_data : Union[pd.DataFrame, str, Path]
        DataFrame or path to file containing cohort data.
        Must contain id_col, entry_col, and exit_col.
    id_col : str
        Column name for person identifier (must exist in both datasets).
    start_col : str
        Column name for exposure period start date in exposure_data.
    exposure_col : str
        Column name for categorical exposure variable in exposure_data.
    reference : int
        Value in exposure_col indicating unexposed/reference status.
    entry_col : str
        Column name for study entry date in master_data.
    exit_col : str
        Column name for study exit date in master_data.
    stop_col : Optional[str], default=None
        Column name for exposure period end date. Required unless pointtime=True.

    Exposure Definition Options (mutually exclusive)
    ------------------------------------------------
    exposure_type : Literal["time_varying", "ever_treated", "current_former",
                           "duration", "continuous", "recency"], default="time_varying"
        Type of exposure variable to create.
    duration_cutpoints : Optional[List[float]], default=None
        Cutpoints for duration categories. Required if exposure_type="duration".
        Example: [1, 5] creates categories: unexposed, <1, 1-<5, >=5.
    continuous_unit : Optional[Literal["days", "weeks", "months", "quarters", "years"]]
        Unit for continuous exposure. Required if exposure_type="continuous" or "duration".
    expand_unit : Optional[Literal["days", "weeks", "months", "quarters", "years"]]
        Row expansion granularity. If specified, creates one row per calendar period.
    recency_cutpoints : Optional[List[float]], default=None
        Cutpoints for recency categories (years since last exposure).
    bytype : bool, default=False
        If True, create separate columns for each exposure type.

    Data Handling Options
    ---------------------
    grace : Union[int, Dict[int, int]], default=0
        Grace period in days to bridge small gaps.
        If int, applies to all categories. If dict, maps exposure values to days.
    merge_days : int, default=120
        Days within which to merge consecutive same-type periods.
    pointtime : bool, default=False
        If True, exposure data are point-in-time (no stop_col required).
    fillgaps : int, default=0
        Days to extend last exposure period beyond recorded stop.
    carryforward : int, default=0
        Days to carry forward exposure through gaps.

    Overlap Handling Options (mutually exclusive)
    ---------------------------------------------
    overlap_method : Literal["layer", "priority", "split", "combine"], default="layer"
        Method for handling overlapping exposure periods.
    priority_order : Optional[List[int]], default=None
        Priority order for overlap_method="priority". Higher priority first.
    combine_col : Optional[str], default=None
        Column name for combined exposure (overlap_method="combine").

    Lag and Washout Options
    -----------------------
    lag_days : int, default=0
        Days before exposure becomes active after start date.
    washout_days : int, default=0
        Days exposure persists after stop date.
    window : Optional[Tuple[int, int]], default=None
        (min_days, max_days) for acute exposure window.

    Pattern Tracking Options
    ------------------------
    track_switching : bool, default=False
        Create binary indicator for any exposure switching.
    track_switching_detail : bool, default=False
        Create string column showing switching pattern.
    track_state_time : bool, default=False
        Create column tracking cumulative time in current state.

    Output Options
    --------------
    output_col : str, default="tv_exposure"
        Name for output exposure column(s).
    reference_label : str, default="Unexposed"
        Label for reference category.
    keep_cols : Optional[List[str]], default=None
        Additional columns to keep from master_data.
    keep_dates : bool, default=False
        If True, keep entry and exit dates in output.

    Examples
    --------
    >>> # Basic time-varying exposure
    >>> tv = TVExpose(
    ...     exposure_data="prescriptions.csv",
    ...     master_data="cohort.csv",
    ...     id_col="patient_id",
    ...     start_col="rx_start",
    ...     stop_col="rx_stop",
    ...     exposure_col="drug_type",
    ...     reference=0,
    ...     entry_col="study_entry",
    ...     exit_col="study_exit"
    ... )
    >>> result = tv.run()
    >>> print(result.data.head())

    >>> # Ever-treated with grace period
    >>> tv = TVExpose(
    ...     exposure_data=rx_df,
    ...     master_data=cohort_df,
    ...     id_col="id",
    ...     start_col="start",
    ...     stop_col="stop",
    ...     exposure_col="treatment",
    ...     reference=0,
    ...     entry_col="entry",
    ...     exit_col="exit",
    ...     exposure_type="ever_treated",
    ...     grace=30
    ... )
    >>> result = tv.run()
    """

    def __init__(
        self,
        exposure_data: Union[pd.DataFrame, str, Path],
        master_data: Union[pd.DataFrame, str, Path],
        id_col: str,
        start_col: str,
        exposure_col: str,
        reference: int,
        entry_col: str,
        exit_col: str,
        stop_col: Optional[str] = None,
        # Exposure definition
        exposure_type: Literal["time_varying", "ever_treated", "current_former",
                               "duration", "continuous", "recency"] = "time_varying",
        duration_cutpoints: Optional[List[float]] = None,
        continuous_unit: Optional[Literal["days", "weeks", "months",
                                          "quarters", "years"]] = None,
        expand_unit: Optional[Literal["days", "weeks", "months",
                                      "quarters", "years"]] = None,
        recency_cutpoints: Optional[List[float]] = None,
        bytype: bool = False,
        # Data handling
        grace: Union[int, Dict[int, int]] = 0,
        merge_days: int = 120,
        pointtime: bool = False,
        fillgaps: int = 0,
        carryforward: int = 0,
        # Overlap handling
        overlap_method: Literal["layer", "priority", "split", "combine"] = "layer",
        priority_order: Optional[List[int]] = None,
        combine_col: Optional[str] = None,
        # Lag and washout
        lag_days: int = 0,
        washout_days: int = 0,
        window: Optional[tuple] = None,
        # Pattern tracking
        track_switching: bool = False,
        track_switching_detail: bool = False,
        track_state_time: bool = False,
        # Output
        output_col: str = "tv_exposure",
        reference_label: str = "Unexposed",
        keep_cols: Optional[List[str]] = None,
        keep_dates: bool = False
    ):
        # Store all parameters
        self.exposure_data = exposure_data
        self.master_data = master_data
        self.id_col = id_col
        self.start_col = start_col
        self.stop_col = stop_col
        self.exposure_col = exposure_col
        self.reference = reference
        self.entry_col = entry_col
        self.exit_col = exit_col

        self.exposure_type = ExposureType(exposure_type)
        self.duration_cutpoints = duration_cutpoints
        self.continuous_unit = TimeUnit(continuous_unit) if continuous_unit else None
        self.expand_unit = TimeUnit(expand_unit) if expand_unit else None
        self.recency_cutpoints = recency_cutpoints
        self.bytype = bytype

        self.grace = self._parse_grace(grace)
        self.merge_days = merge_days
        self.pointtime = pointtime
        self.fillgaps = fillgaps
        self.carryforward = carryforward

        self.overlap_method = OverlapMethod(overlap_method)
        self.priority_order = priority_order
        self.combine_col = combine_col

        self.lag_days = lag_days
        self.washout_days = washout_days
        self.window = window

        self.track_switching = track_switching
        self.track_switching_detail = track_switching_detail
        self.track_state_time = track_state_time

        self.output_col = output_col
        self.reference_label = reference_label
        self.keep_cols = keep_cols or []
        self.keep_dates = keep_dates

        # Internal state
        self._warnings: List[str] = []
        self._overlap_ids: Optional[List] = None

    def _parse_grace(self, grace: Union[int, Dict[int, int]]) -> GracePeriod:
        """Parse grace period specification."""
        if isinstance(grace, int):
            return GracePeriod(default=grace)
        elif isinstance(grace, dict):
            return GracePeriod(by_category=grace)
        else:
            raise ValidationError(f"grace must be int or dict, got {type(grace)}")

    def run(self) -> TVExposeResult:
        """
        Execute the time-varying exposure transformation.

        Returns
        -------
        TVExposeResult
            Result container with transformed data and metadata.

        Raises
        ------
        ValidationError
            If input validation fails.
        TVExposeError
            If processing fails.
        """
        # Step 1: Load and validate data
        exposure_df = self._load_data(self.exposure_data)
        master_df = self._load_data(self.master_data)
        validate_inputs(self, exposure_df, master_df)

        # Step 2: Prepare master data (entry/exit dates)
        master_dates = self._prepare_master(master_df)

        # Step 3: Prepare exposure data
        exp_df = self._prepare_exposure(exposure_df, master_dates)

        # Step 4: Apply lag, washout, window
        exp_df = self._apply_time_adjustments(exp_df)

        # Step 5: Merge close same-type periods
        exp_df = merge_periods(exp_df, self.merge_days, self.id_col)

        # Step 6: Remove contained periods
        exp_df = remove_contained_periods(exp_df, self.id_col)

        # Step 7: Resolve overlapping exposures
        exp_df, self._overlap_ids = self._resolve_overlaps(exp_df)

        # Step 8: Create gap periods (reference category)
        exp_df = create_gap_periods(
            exp_df, master_dates, self.id_col,
            self.reference, self.grace, self.carryforward
        )

        # Step 9: Create baseline periods (pre-first exposure)
        exp_df = create_baseline_periods(
            exp_df, master_dates, self.id_col, self.reference
        )

        # Step 10: Create post-exposure periods
        exp_df = create_post_exposure_periods(
            exp_df, master_dates, self.id_col, self.reference
        )

        # Step 11: Apply exposure type transformation
        exp_df = self._apply_exposure_type(exp_df)

        # Step 12: Apply pattern tracking
        if self.track_switching or self.track_switching_detail or self.track_state_time:
            exp_df = self._apply_pattern_tracking(exp_df)

        # Step 13: Expand by time unit if requested
        if self.expand_unit:
            exp_df = self._expand_by_time_unit(exp_df)

        # Step 14: Merge keepvars from master
        if self.keep_cols:
            exp_df = exp_df.merge(
                master_dates[[self.id_col] + self.keep_cols],
                on=self.id_col,
                how='left'
            )

        # Step 15: Clean up output
        exp_df = self._finalize_output(exp_df)

        # Step 16: Calculate summary statistics
        result = self._create_result(exp_df)

        return result
```

---

## Core Algorithms

### 1. Period Merging Algorithm

```python
# tvexpose/algorithms.py

def merge_periods(
    df: pd.DataFrame,
    merge_days: int,
    id_col: str
) -> pd.DataFrame:
    """
    Iteratively merge consecutive same-type periods within merge_days.

    Algorithm:
    1. Sort by id, start, stop, exposure
    2. For each person, identify mergeable pairs (same exposure, gap <= merge_days)
    3. Extend earlier period's stop to encompass later period
    4. Mark subsumed periods for deletion
    5. Repeat until no more merges possible

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data with columns: id, exp_start, exp_stop, exp_value
    merge_days : int
        Maximum gap in days to merge
    id_col : str
        ID column name

    Returns
    -------
    pd.DataFrame
        Merged exposure data
    """
    df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value']).copy()

    max_iterations = 10000
    iteration = 0

    while iteration < max_iterations:
        iteration += 1
        n_before = len(df)

        # Calculate gap to next period of same type
        df['_next_start'] = df.groupby([id_col, 'exp_value'])['exp_start'].shift(-1)
        df['_gap'] = df['_next_start'] - df['exp_stop']

        # Identify mergeable pairs
        df['_can_merge'] = (df['_gap'] <= merge_days) & df['_gap'].notna()

        # Extend stop date to encompass next period
        df['_next_stop'] = df.groupby([id_col, 'exp_value'])['exp_stop'].shift(-1)
        df.loc[df['_can_merge'], 'exp_stop'] = df.loc[df['_can_merge'], ['exp_stop', '_next_stop']].max(axis=1)

        # Mark subsumed periods
        df['_prev_can_merge'] = df.groupby([id_col, 'exp_value'])['_can_merge'].shift(1).fillna(False)
        df['_prev_stop'] = df.groupby([id_col, 'exp_value'])['exp_stop'].shift(1)
        df['_subsumed'] = df['_prev_can_merge'] & (df['exp_stop'] <= df['_prev_stop'])

        # Remove subsumed periods
        df = df[~df['_subsumed']].copy()

        # Clean up temp columns
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])

        # Check if any merges occurred
        if len(df) == n_before:
            break

        df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value'])

    return df
```

### 2. Contained Period Removal

```python
def remove_contained_periods(df: pd.DataFrame, id_col: str) -> pd.DataFrame:
    """
    Remove periods fully contained within another of same exposure type.

    A period B is contained in A if:
    - Same person, same exposure value
    - B.start >= A.start AND B.stop <= A.stop

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    id_col : str
        ID column name

    Returns
    -------
    pd.DataFrame
        Data with contained periods removed
    """
    df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value']).copy()

    max_iterations = 10000
    iteration = 0

    while iteration < max_iterations:
        iteration += 1
        n_before = len(df)

        # Get previous period boundaries for same type
        df['_prev_start'] = df.groupby([id_col, 'exp_value'])['exp_start'].shift(1)
        df['_prev_stop'] = df.groupby([id_col, 'exp_value'])['exp_stop'].shift(1)

        # Mark contained periods
        df['_contained'] = (
            df['_prev_start'].notna() &
            (df['exp_start'] >= df['_prev_start']) &
            (df['exp_stop'] <= df['_prev_stop'])
        )

        # Remove contained
        df = df[~df['_contained']].copy()
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])

        if len(df) == n_before:
            break

        df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value'])

    return df
```

### 3. Layer Overlap Resolution

```python
def resolve_overlaps_layer(df: pd.DataFrame, id_col: str) -> pd.DataFrame:
    """
    Resolve overlapping exposures using layer strategy.

    Layer strategy:
    - When exposure B starts while A is active:
      1. Truncate A to end just before B starts (pre-overlap segment)
      2. B takes full precedence during overlap
      3. If A extended beyond B, A resumes after B ends (post-overlap segment)

    Visual example:
        Before:  A: |-------------------|  (days 1-20, type 1)
                 B:      |-------|        (days 5-12, type 2)

        After:   A: |----|                (days 1-4, type 1)
                 B:      |-------|        (days 5-12, type 2)
                 A:               |----| (days 13-20, type 1)

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data with potential overlaps
    id_col : str
        ID column name

    Returns
    -------
    pd.DataFrame
        Data with overlaps resolved
    """
    df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value']).copy()

    max_iterations = 10
    iteration = 0

    while iteration < max_iterations:
        iteration += 1

        # Find overlaps with next different-type period
        df['_next_start'] = df.groupby(id_col)['exp_start'].shift(-1)
        df['_next_stop'] = df.groupby(id_col)['exp_stop'].shift(-1)
        df['_next_value'] = df.groupby(id_col)['exp_value'].shift(-1)

        # Overlap: next period starts before current ends, different type
        df['_has_overlap'] = (
            df['_next_start'].notna() &
            (df['_next_start'] <= df['exp_stop']) &
            (df['exp_value'] != df['_next_value'])
        )

        n_overlaps = df['_has_overlap'].sum()
        if n_overlaps == 0:
            df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
            break

        # Process overlaps
        # Non-overlapping periods kept as-is
        non_overlap = df[~df['_has_overlap']].copy()
        overlap = df[df['_has_overlap']].copy()

        # Pre-overlap segments: current start to next_start - 1
        pre_segments = overlap.copy()
        pre_segments['exp_stop'] = pre_segments['_next_start'] - pd.Timedelta(days=1)

        # Post-overlap segments: next_stop + 1 to current stop (if current extends beyond)
        post_segments = overlap[overlap['exp_stop'] > overlap['_next_stop']].copy()
        post_segments['exp_start'] = post_segments['_next_stop'] + pd.Timedelta(days=1)

        # Keep essential columns
        keep_cols = [id_col, 'exp_start', 'exp_stop', 'exp_value']
        extra_cols = [c for c in df.columns if c not in keep_cols and not c.startswith('_')]
        keep_cols.extend(extra_cols)

        pre_segments = pre_segments[keep_cols]
        post_segments = post_segments[keep_cols]
        non_overlap = non_overlap[[c for c in non_overlap.columns if not c.startswith('_')]]

        # Combine and clean
        df = pd.concat([non_overlap, pre_segments, post_segments], ignore_index=True)
        df = df[df['exp_start'] <= df['exp_stop']]  # Remove invalid periods
        df = df.drop_duplicates(subset=[id_col, 'exp_start', 'exp_stop', 'exp_value'])
        df = df.sort_values([id_col, 'exp_start', 'exp_stop', 'exp_value'])

    return df
```

### 4. Gap Period Creation

```python
def create_gap_periods(
    df: pd.DataFrame,
    master_dates: pd.DataFrame,
    id_col: str,
    reference: int,
    grace: GracePeriod,
    carryforward: int
) -> pd.DataFrame:
    """
    Fill gaps between exposure periods with reference (unexposed) time.

    Algorithm:
    1. Sort by id, start
    2. Calculate gap to next period
    3. Apply grace period bridging (gaps <= grace are filled by extending previous)
    4. Create reference periods for remaining gaps
    5. Apply carryforward logic if specified

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    master_dates : pd.DataFrame
        Master data with entry/exit dates
    id_col : str
        ID column name
    reference : int
        Reference/unexposed value
    grace : GracePeriod
        Grace period specification
    carryforward : int
        Days to carry forward exposure

    Returns
    -------
    pd.DataFrame
        Data with gap periods added
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Calculate gap to next period
    df['_next_start'] = df.groupby(id_col)['exp_start'].shift(-1)
    df['_gap_days'] = (df['_next_start'] - df['exp_stop']).dt.days - 1

    # Get grace period for each exposure value
    df['_grace_days'] = df['exp_value'].apply(grace.get_grace)

    # Bridge small gaps within same type by extending stop
    same_type_next = df.groupby(id_col)['exp_value'].shift(-1) == df['exp_value']
    bridge_mask = (
        same_type_next &
        df['_gap_days'].notna() &
        (df['_gap_days'] <= df['_grace_days']) &
        (df['_gap_days'] > 0)
    )
    df.loc[bridge_mask, 'exp_stop'] = df.loc[bridge_mask, '_next_start'] - pd.Timedelta(days=1)

    # Recalculate gaps after bridging
    df['_next_start'] = df.groupby(id_col)['exp_start'].shift(-1)
    df['_gap_days'] = (df['_next_start'] - df['exp_stop']).dt.days - 1

    # Identify gaps that need reference periods
    gap_mask = df['_gap_days'].notna() & (df['_gap_days'] > df['_grace_days'])
    gap_rows = df[gap_mask].copy()

    if len(gap_rows) > 0:
        if carryforward > 0:
            # Carryforward: split gap into carryforward + reference
            gap_rows['_carry_stop'] = gap_rows['exp_stop'] + pd.Timedelta(days=carryforward)
            gap_rows['_carry_stop'] = gap_rows[['_carry_stop', '_next_start']].min(axis=1) - pd.Timedelta(days=1)

            # Carryforward periods (same exposure value)
            carry_periods = gap_rows.copy()
            carry_periods['exp_start'] = carry_periods['exp_stop'] + pd.Timedelta(days=1)
            carry_periods['exp_stop'] = carry_periods['_carry_stop']
            carry_periods = carry_periods[carry_periods['exp_start'] <= carry_periods['exp_stop']]

            # Reference periods (remaining gap)
            ref_periods = gap_rows.copy()
            ref_periods['exp_start'] = ref_periods['_carry_stop'] + pd.Timedelta(days=1)
            ref_periods['exp_stop'] = ref_periods['_next_start'] - pd.Timedelta(days=1)
            ref_periods['exp_value'] = reference
            ref_periods = ref_periods[ref_periods['exp_start'] <= ref_periods['exp_stop']]

            gap_periods = pd.concat([carry_periods, ref_periods], ignore_index=True)
        else:
            # No carryforward: entire gap is reference
            gap_periods = gap_rows.copy()
            gap_periods['exp_start'] = gap_periods['exp_stop'] + pd.Timedelta(days=1)
            gap_periods['exp_stop'] = gap_periods['_next_start'] - pd.Timedelta(days=1)
            gap_periods['exp_value'] = reference

        # Keep essential columns
        keep_cols = [id_col, 'exp_start', 'exp_stop', 'exp_value']
        gap_periods = gap_periods[keep_cols]

        # Combine with original data
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
        df = pd.concat([df, gap_periods], ignore_index=True)
        df = df.sort_values([id_col, 'exp_start', 'exp_stop'])
    else:
        df = df.drop(columns=[c for c in df.columns if c.startswith('_')])

    return df
```

### 5. Baseline Period Creation

```python
def create_baseline_periods(
    df: pd.DataFrame,
    master_dates: pd.DataFrame,
    id_col: str,
    reference: int
) -> pd.DataFrame:
    """
    Create reference periods before first exposure (baseline unexposed time).

    Also handles never-exposed persons (entire follow-up is reference).

    Parameters
    ----------
    df : pd.DataFrame
        Exposure data
    master_dates : pd.DataFrame
        Master data with id, study_entry, study_exit
    id_col : str
        ID column name
    reference : int
        Reference value

    Returns
    -------
    pd.DataFrame
        Data with baseline periods added
    """
    # Get first exposure date per person
    first_exp = df.groupby(id_col)['exp_start'].min().reset_index()
    first_exp.columns = [id_col, '_first_exp']

    # Merge with master dates
    baseline = master_dates.merge(first_exp, on=id_col, how='left')

    # Create baseline period: entry to day before first exposure
    baseline['exp_start'] = baseline['study_entry']
    baseline['exp_stop'] = baseline['_first_exp'] - pd.Timedelta(days=1)

    # For never-exposed: entire follow-up is baseline
    baseline.loc[baseline['_first_exp'].isna(), 'exp_stop'] = baseline.loc[
        baseline['_first_exp'].isna(), 'study_exit'
    ]

    baseline['exp_value'] = reference

    # Keep only valid baseline periods
    baseline = baseline[baseline['exp_stop'] >= baseline['exp_start']]
    baseline = baseline[[id_col, 'exp_start', 'exp_stop', 'exp_value']]

    # Combine
    df = pd.concat([df, baseline], ignore_index=True)
    df = df.sort_values([id_col, 'exp_start', 'exp_stop'])

    return df
```

---

## Exposure Type Implementations

```python
# tvexpose/exposure_types.py

def apply_ever_treated(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str
) -> pd.DataFrame:
    """
    Create binary ever-treated variable (0 before first exposure, 1 after).

    The variable switches permanently from 0 to 1 at first non-reference exposure.
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Find first non-reference exposure per person
    non_ref = df[df['exp_value'] != reference].copy()
    first_exp = non_ref.groupby(id_col)['exp_start'].min().reset_index()
    first_exp.columns = [id_col, '_first_exp_date']

    df = df.merge(first_exp, on=id_col, how='left')

    # Before first exposure: 0, After (including): 1
    df[output_col] = np.where(
        df['_first_exp_date'].isna() | (df['exp_start'] < df['_first_exp_date']),
        0, 1
    )

    df = df.drop(columns=['_first_exp_date'])
    return df


def apply_current_former(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str
) -> pd.DataFrame:
    """
    Create trichotomous current/former variable.

    Values:
    - 0: Never exposed (no prior exposure)
    - 1: Currently exposed (non-reference value)
    - 2: Formerly exposed (reference value, but had prior exposure)
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Track if person has ever been exposed
    df['_is_exposed'] = (df['exp_value'] != reference).astype(int)
    df['_ever_exposed'] = df.groupby(id_col)['_is_exposed'].cumsum() > 0

    # Shift to get "ever exposed before this period"
    df['_was_exposed'] = df.groupby(id_col)['_ever_exposed'].shift(1).fillna(False)

    # Create trichotomous variable
    conditions = [
        df['exp_value'] != reference,           # Currently exposed
        df['_was_exposed'] | df['_ever_exposed'], # Formerly exposed
    ]
    choices = [1, 2]
    df[output_col] = np.select(conditions, choices, default=0)

    # Clean up
    df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
    return df


def apply_continuous_exposure(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str,
    time_unit: TimeUnit
) -> pd.DataFrame:
    """
    Calculate cumulative exposure in specified time units.

    Creates a continuous variable tracking total time exposed.
    """
    df = df.sort_values([id_col, 'exp_start']).copy()

    # Calculate period duration in days
    df['_duration_days'] = (df['exp_stop'] - df['exp_start']).dt.days + 1

    # Only count non-reference periods
    df['_exposed_days'] = np.where(
        df['exp_value'] != reference,
        df['_duration_days'],
        0
    )

    # Cumulative sum within person
    df['_cumul_days'] = df.groupby(id_col)['_exposed_days'].cumsum()

    # Convert to requested unit
    df[output_col] = df['_cumul_days'] / time_unit.days_per_unit

    # Clean up
    df = df.drop(columns=[c for c in df.columns if c.startswith('_')])
    return df


def apply_duration_categories(
    df: pd.DataFrame,
    id_col: str,
    reference: int,
    output_col: str,
    cutpoints: List[float],
    time_unit: TimeUnit
) -> pd.DataFrame:
    """
    Create categorical variable based on cumulative exposure duration.

    Example with cutpoints=[1, 5]:
    - 0: Unexposed
    - 1: <1 unit
    - 2: 1 to <5 units
    - 3: >=5 units
    """
    # First calculate continuous
    df = apply_continuous_exposure(df, id_col, reference, '_cumul_exp', time_unit)

    # Create categories
    bins = [-np.inf, 0] + cutpoints + [np.inf]
    labels = list(range(len(bins) - 1))

    df[output_col] = pd.cut(
        df['_cumul_exp'],
        bins=bins,
        labels=labels,
        include_lowest=True
    ).astype(int)

    # Unexposed (reference) periods get category 0
    df.loc[df['exp_value'] == reference, output_col] = 0

    df = df.drop(columns=['_cumul_exp'])
    return df
```

---

## Testing Strategy

### Test File Structure

```
tests/
├── conftest.py              # Fixtures
├── test_validators.py       # Input validation tests
├── test_algorithms.py       # Core algorithm tests
├── test_exposure_types.py   # Exposure type tests
├── test_integration.py      # End-to-end tests
├── test_edge_cases.py       # Edge case tests
└── test_performance.py      # Performance benchmarks
```

### Key Test Cases

```python
# tests/conftest.py

import pytest
import pandas as pd
import numpy as np

@pytest.fixture
def sample_master_data():
    """Sample cohort data."""
    return pd.DataFrame({
        'id': [1, 2, 3],
        'study_entry': pd.to_datetime(['2020-01-01', '2020-01-01', '2020-01-01']),
        'study_exit': pd.to_datetime(['2020-12-31', '2020-12-31', '2020-12-31']),
        'age': [50, 60, 70]
    })

@pytest.fixture
def sample_exposure_data():
    """Sample exposure periods."""
    return pd.DataFrame({
        'id': [1, 1, 2],
        'rx_start': pd.to_datetime(['2020-03-01', '2020-06-01', '2020-04-01']),
        'rx_stop': pd.to_datetime(['2020-04-30', '2020-07-31', '2020-09-30']),
        'drug_type': [1, 2, 1]
    })

@pytest.fixture
def overlapping_exposure_data():
    """Exposure data with overlaps for testing."""
    return pd.DataFrame({
        'id': [1, 1],
        'rx_start': pd.to_datetime(['2020-01-01', '2020-01-15']),
        'rx_stop': pd.to_datetime(['2020-01-31', '2020-02-15']),
        'drug_type': [1, 2]
    })


# tests/test_algorithms.py

class TestMergePeriods:
    """Tests for period merging algorithm."""

    def test_merge_adjacent_same_type(self, sample_exposure_data):
        """Adjacent same-type periods are merged."""
        # Create adjacent periods
        df = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-01-11']),
            'exp_stop': pd.to_datetime(['2020-01-10', '2020-01-20']),
            'exp_value': [1, 1]
        })

        result = merge_periods(df, merge_days=5, id_col='id')

        assert len(result) == 1
        assert result.iloc[0]['exp_start'] == pd.Timestamp('2020-01-01')
        assert result.iloc[0]['exp_stop'] == pd.Timestamp('2020-01-20')

    def test_no_merge_different_types(self):
        """Different exposure types are not merged."""
        df = pd.DataFrame({
            'id': [1, 1],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-01-11']),
            'exp_stop': pd.to_datetime(['2020-01-10', '2020-01-20']),
            'exp_value': [1, 2]
        })

        result = merge_periods(df, merge_days=5, id_col='id')

        assert len(result) == 2


class TestLayerOverlapResolution:
    """Tests for layer overlap strategy."""

    def test_later_takes_precedence(self, overlapping_exposure_data):
        """Later exposure takes precedence in overlap."""
        result = resolve_overlaps_layer(overlapping_exposure_data, 'id')

        # Should have 3 periods: pre-overlap type 1, overlap type 2, post-overlap type 1
        assert len(result) == 3

    def test_earlier_resumes_after(self, overlapping_exposure_data):
        """Earlier exposure resumes after later ends."""
        result = resolve_overlaps_layer(overlapping_exposure_data, 'id')

        # Last period should be type 1 (resumption)
        last = result.sort_values('exp_start').iloc[-1]
        assert last['exp_value'] == 1


# tests/test_exposure_types.py

class TestEverTreated:
    """Tests for ever-treated exposure type."""

    def test_switches_at_first_exposure(self):
        """Variable switches from 0 to 1 at first exposure."""
        df = pd.DataFrame({
            'id': [1, 1, 1],
            'exp_start': pd.to_datetime(['2020-01-01', '2020-03-01', '2020-06-01']),
            'exp_stop': pd.to_datetime(['2020-02-28', '2020-05-31', '2020-12-31']),
            'exp_value': [0, 1, 0]  # unexposed, exposed, back to unexposed
        })

        result = apply_ever_treated(df, 'id', reference=0, output_col='ever')

        assert result.iloc[0]['ever'] == 0  # Before first exposure
        assert result.iloc[1]['ever'] == 1  # At first exposure
        assert result.iloc[2]['ever'] == 1  # After (permanent)

    def test_never_exposed_stays_zero(self):
        """Never-exposed persons stay at 0."""
        df = pd.DataFrame({
            'id': [1],
            'exp_start': pd.to_datetime(['2020-01-01']),
            'exp_stop': pd.to_datetime(['2020-12-31']),
            'exp_value': [0]
        })

        result = apply_ever_treated(df, 'id', reference=0, output_col='ever')

        assert result.iloc[0]['ever'] == 0
```

---

## Example Usage

```python
# Example 1: Basic time-varying exposure
from tvtools import TVExpose

result = TVExpose(
    exposure_data="prescriptions.csv",
    master_data="cohort.csv",
    id_col="patient_id",
    start_col="rx_start",
    stop_col="rx_stop",
    exposure_col="drug_type",
    reference=0,
    entry_col="study_entry",
    exit_col="study_exit"
).run()

print(f"Created {result.n_periods} periods for {result.n_persons} persons")
print(f"Exposed time: {result.pct_exposed:.1f}%")


# Example 2: Ever-treated with grace period
result = TVExpose(
    exposure_data=rx_df,
    master_data=cohort_df,
    id_col="id",
    start_col="start",
    stop_col="stop",
    exposure_col="treatment",
    reference=0,
    entry_col="entry",
    exit_col="exit",
    exposure_type="ever_treated",
    grace=30,
    output_col="ever_treated"
).run()


# Example 3: Duration categories with expansion
result = TVExpose(
    exposure_data=rx_df,
    master_data=cohort_df,
    id_col="id",
    start_col="start",
    stop_col="stop",
    exposure_col="treatment",
    reference=0,
    entry_col="entry",
    exit_col="exit",
    exposure_type="duration",
    duration_cutpoints=[1, 5, 10],
    continuous_unit="years",
    expand_unit="months"
).run()


# Example 4: Current/former with lag and washout
result = TVExpose(
    exposure_data=rx_df,
    master_data=cohort_df,
    id_col="id",
    start_col="start",
    stop_col="stop",
    exposure_col="treatment",
    reference=0,
    entry_col="entry",
    exit_col="exit",
    exposure_type="current_former",
    lag_days=30,
    washout_days=90,
    keep_cols=["age", "sex"]
).run()


# Example 5: Integration with lifelines for survival analysis
from lifelines import CoxPHFitter

result = TVExpose(
    exposure_data="drugs.csv",
    master_data="cohort.csv",
    id_col="id",
    start_col="start",
    stop_col="stop",
    exposure_col="drug",
    reference=0,
    entry_col="entry",
    exit_col="exit",
    keep_cols=["age", "sex", "event", "event_time"]
).run()

# Prepare for Cox model
df = result.data.copy()
df['duration'] = (df['exp_stop'] - df['exp_start']).dt.days

cph = CoxPHFitter()
cph.fit(df, duration_col='duration', event_col='event',
        formula="tv_exposure + age + sex")
cph.print_summary()
```

---

## Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Create package structure
- [ ] Implement type definitions (types.py)
- [ ] Implement custom exceptions (exceptions.py)
- [ ] Implement date utilities (utils/dates.py)
- [ ] Implement file I/O utilities (utils/io.py)

### Phase 2: Validation
- [ ] Input validation for all parameters
- [ ] Data validation (columns exist, types correct)
- [ ] Option validation (mutually exclusive options)

### Phase 3: Core Algorithms
- [ ] Period merging (iterative)
- [ ] Contained period removal
- [ ] Gap period creation with grace/carryforward
- [ ] Baseline period creation
- [ ] Post-exposure period creation
- [ ] Layer overlap resolution
- [ ] Priority overlap resolution
- [ ] Split overlap resolution
- [ ] Combine overlap resolution

### Phase 4: Exposure Types
- [ ] Time-varying (default)
- [ ] Ever-treated
- [ ] Current/former
- [ ] Duration categories
- [ ] Continuous cumulative
- [ ] Recency categories
- [ ] Bytype support for all

### Phase 5: Advanced Features
- [ ] Lag/washout application
- [ ] Window filtering
- [ ] Row expansion by time unit
- [ ] Pattern tracking (switching, state time)
- [ ] Keep columns from master

### Phase 6: Testing and Documentation
- [ ] Unit tests for all algorithms
- [ ] Integration tests
- [ ] Edge case tests
- [ ] Performance benchmarks
- [ ] API documentation
- [ ] Usage examples

---

## Performance Considerations

### Expected Performance

| Dataset Size | Persons | Expected Time |
|-------------|---------|---------------|
| Small | 1,000 | <1 second |
| Medium | 10,000 | 2-5 seconds |
| Large | 100,000 | 20-60 seconds |
| Very Large | 1,000,000 | 5-15 minutes |

### Optimization Strategies

1. **Vectorized operations**: Use pandas/numpy vectorization, avoid loops
2. **Efficient groupby**: Use transform instead of apply where possible
3. **Memory management**: Drop unnecessary columns early
4. **Chunked processing**: For very large datasets, process in chunks
5. **Categorical dtypes**: Use categorical for exposure values to reduce memory

---

## Stata-Python Comparison

| Feature | Stata | Python |
|---------|-------|--------|
| Input | using filename | DataFrame or path |
| Output | modifies data in memory | returns TVExposeResult |
| Options | many separate options | class parameters |
| Error handling | exit codes | custom exceptions |
| Progress | noisily display | logging module |
| Performance | compiled | pandas vectorized |

---

## Success Criteria

1. **Feature parity**: All Stata options implemented
2. **Correctness**: Identical results to Stata on test cases
3. **Performance**: Within 2x of Stata performance
4. **API design**: Pythonic, type-hinted, well-documented
5. **Test coverage**: >90% code coverage
6. **Documentation**: Complete docstrings and examples

"""Main TVExpose class for time-varying exposure transformation."""

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
    resolve_overlaps_layer,
    create_gap_periods, create_baseline_periods,
    create_post_exposure_periods
)
from .exposure_types import (
    apply_ever_treated, apply_current_former,
    apply_duration_categories, apply_continuous_exposure
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

        # Parse date columns (if they're not already datetime)
        exposure_df = self._parse_dates(exposure_df,
                                       [self.start_col] + ([self.stop_col] if self.stop_col else []))
        master_df = self._parse_dates(master_df, [self.entry_col, self.exit_col])

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
        exp_df = self._resolve_overlaps(exp_df)

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

    def _load_data(self, data: Union[pd.DataFrame, str, Path]) -> pd.DataFrame:
        """Load data from DataFrame or file."""
        if isinstance(data, pd.DataFrame):
            return data.copy()
        else:
            path = Path(data)
            if path.suffix == '.csv':
                return pd.read_csv(path)
            elif path.suffix in ['.dta', '.stata']:
                return pd.read_stata(path)
            elif path.suffix in ['.parquet', '.pq']:
                return pd.read_parquet(path)
            else:
                raise ValidationError(f"Unsupported file format: {path.suffix}")

    def _parse_dates(self, df: pd.DataFrame, date_cols: List[str]) -> pd.DataFrame:
        """
        Parse date columns to datetime type if they're not already.

        Parameters
        ----------
        df : pd.DataFrame
            DataFrame to process
        date_cols : List[str]
            Column names that should be datetime

        Returns
        -------
        pd.DataFrame
            DataFrame with parsed dates
        """
        df = df.copy()
        for col in date_cols:
            if col in df.columns and not pd.api.types.is_datetime64_any_dtype(df[col]):
                df[col] = pd.to_datetime(df[col], errors='coerce')
        return df

    def _prepare_master(self, master_df: pd.DataFrame) -> pd.DataFrame:
        """Prepare master data with standardized column names."""
        master = master_df[[self.id_col, self.entry_col, self.exit_col] + self.keep_cols].copy()
        master = master.rename(columns={
            self.entry_col: 'study_entry',
            self.exit_col: 'study_exit'
        })
        return master

    def _prepare_exposure(self, exposure_df: pd.DataFrame, master_dates: pd.DataFrame) -> pd.DataFrame:
        """Prepare exposure data with standardized column names and trimming."""
        # Select and rename columns
        cols = [self.id_col, self.start_col, self.exposure_col]
        if not self.pointtime:
            cols.append(self.stop_col)

        exp = exposure_df[cols].copy()
        exp = exp.rename(columns={
            self.start_col: 'exp_start',
            self.exposure_col: 'exp_value'
        })

        if not self.pointtime:
            exp = exp.rename(columns={self.stop_col: 'exp_stop'})
        else:
            # For point-in-time, create stop = start
            exp['exp_stop'] = exp['exp_start']

        # Merge with master to get study dates
        exp = exp.merge(master_dates[[self.id_col, 'study_entry', 'study_exit']], on=self.id_col, how='inner')

        # Trim exposure periods to study period
        exp['exp_start'] = exp[['exp_start', 'study_entry']].max(axis=1)
        exp['exp_stop'] = exp[['exp_stop', 'study_exit']].min(axis=1)

        # Remove invalid periods
        exp = exp[exp['exp_start'] <= exp['exp_stop']]

        # Drop study dates (no longer needed)
        exp = exp.drop(columns=['study_entry', 'study_exit'])

        return exp

    def _apply_time_adjustments(self, df: pd.DataFrame) -> pd.DataFrame:
        """Apply lag, washout, and window adjustments."""
        df = df.copy()

        # Apply lag (shift start forward)
        if self.lag_days > 0:
            df['exp_start'] = df['exp_start'] + pd.Timedelta(days=self.lag_days)

        # Apply washout (extend stop)
        if self.washout_days > 0:
            df['exp_stop'] = df['exp_stop'] + pd.Timedelta(days=self.washout_days)

        # Apply window (keep only exposures within min/max duration)
        if self.window:
            min_days, max_days = self.window
            df['_duration'] = (df['exp_stop'] - df['exp_start']).dt.days + 1
            df = df[(df['_duration'] >= min_days) & (df['_duration'] <= max_days)]
            df = df.drop(columns=['_duration'])

        # Remove invalid periods
        df = df[df['exp_start'] <= df['exp_stop']]

        return df

    def _resolve_overlaps(self, df: pd.DataFrame) -> pd.DataFrame:
        """Resolve overlapping exposure periods."""
        if self.overlap_method == OverlapMethod.LAYER:
            return resolve_overlaps_layer(df, self.id_col)
        else:
            # For now, only layer is implemented
            # TODO: implement priority, split, combine methods
            raise NotImplementedError(f"Overlap method {self.overlap_method.value} not yet implemented")

    def _apply_exposure_type(self, df: pd.DataFrame) -> pd.DataFrame:
        """Apply exposure type transformation."""
        if self.exposure_type == ExposureType.TIME_VARYING:
            # Default: just rename exp_value to output_col
            df[self.output_col] = df['exp_value']

        elif self.exposure_type == ExposureType.EVER_TREATED:
            df = apply_ever_treated(df, self.id_col, self.reference, self.output_col)

        elif self.exposure_type == ExposureType.CURRENT_FORMER:
            df = apply_current_former(df, self.id_col, self.reference, self.output_col)

        elif self.exposure_type == ExposureType.DURATION:
            df = apply_duration_categories(
                df, self.id_col, self.reference, self.output_col,
                self.duration_cutpoints, self.continuous_unit
            )

        elif self.exposure_type == ExposureType.CONTINUOUS:
            df = apply_continuous_exposure(
                df, self.id_col, self.reference, self.output_col,
                self.continuous_unit
            )

        elif self.exposure_type == ExposureType.RECENCY:
            # TODO: implement recency
            raise NotImplementedError("Recency exposure type not yet implemented")

        return df

    def _apply_pattern_tracking(self, df: pd.DataFrame) -> pd.DataFrame:
        """Apply pattern tracking features."""
        df = df.sort_values([self.id_col, 'exp_start']).copy()

        if self.track_switching:
            # Binary indicator: has exposure ever changed?
            df['_prev_value'] = df.groupby(self.id_col)['exp_value'].shift(1)
            df['_switched'] = (df['exp_value'] != df['_prev_value']) & df['_prev_value'].notna()
            df['switching'] = df.groupby(self.id_col)['_switched'].cumsum() > 0
            df['switching'] = df['switching'].astype(int)
            df = df.drop(columns=['_prev_value', '_switched'])

        if self.track_switching_detail:
            # String showing pattern: "0→1→0→2"
            df['_exp_str'] = df['exp_value'].astype(str)
            df['switching_pattern'] = df.groupby(self.id_col)['_exp_str'].transform(
                lambda x: '→'.join(x.unique())
            )
            df = df.drop(columns=['_exp_str'])

        if self.track_state_time:
            # Cumulative time in current state
            df['_duration'] = (df['exp_stop'] - df['exp_start']).dt.days + 1
            df['_state_change'] = df.groupby(self.id_col)['exp_value'].shift(1) != df['exp_value']
            df['_state_id'] = df.groupby(self.id_col)['_state_change'].cumsum()
            df['state_time'] = df.groupby([self.id_col, '_state_id'])['_duration'].cumsum()
            df = df.drop(columns=['_duration', '_state_change', '_state_id'])

        return df

    def _expand_by_time_unit(self, df: pd.DataFrame) -> pd.DataFrame:
        """Expand each period into multiple rows by time unit."""
        # TODO: implement row expansion
        # This is complex: need to create one row per calendar period (day/week/month/etc)
        # For now, just return unchanged
        self._warnings.append("Row expansion not yet implemented")
        return df

    def _finalize_output(self, df: pd.DataFrame) -> pd.DataFrame:
        """Clean up and finalize output columns."""
        df = df.copy()

        # Ensure essential columns exist
        essential = [self.id_col, 'exp_start', 'exp_stop', self.output_col]

        # Optional columns
        optional = []
        if self.keep_dates:
            # Add study dates back if requested
            pass  # Already merged in keep_cols step

        if self.track_switching:
            optional.append('switching')
        if self.track_switching_detail:
            optional.append('switching_pattern')
        if self.track_state_time:
            optional.append('state_time')

        # Keep columns
        keep = essential + optional + self.keep_cols
        keep = [c for c in keep if c in df.columns]

        df = df[keep]

        # Sort
        df = df.sort_values([self.id_col, 'exp_start', 'exp_stop'])

        # Reset index
        df = df.reset_index(drop=True)

        return df

    def _create_result(self, df: pd.DataFrame) -> TVExposeResult:
        """Create result container with summary statistics."""
        n_persons = df[self.id_col].nunique()
        n_periods = len(df)

        # Calculate time statistics
        df['_duration'] = (df['exp_stop'] - df['exp_start']).dt.days + 1
        total_time = df['_duration'].sum()

        if self.exposure_type == ExposureType.TIME_VARYING:
            exposed_time = df[df[self.output_col] != self.reference]['_duration'].sum()
        else:
            # For transformed types, count based on original exp_value
            if 'exp_value' in df.columns:
                exposed_time = df[df['exp_value'] != self.reference]['_duration'].sum()
            else:
                exposed_time = 0

        unexposed_time = total_time - exposed_time
        pct_exposed = (exposed_time / total_time * 100) if total_time > 0 else 0

        return TVExposeResult(
            data=df.drop(columns=['_duration'] if '_duration' in df.columns else []),
            n_persons=n_persons,
            n_periods=n_periods,
            total_time=float(total_time),
            exposed_time=float(exposed_time),
            unexposed_time=float(unexposed_time),
            pct_exposed=float(pct_exposed),
            exposure_type=self.exposure_type,
            overlap_ids=self._overlap_ids,
            warnings=self._warnings
        )

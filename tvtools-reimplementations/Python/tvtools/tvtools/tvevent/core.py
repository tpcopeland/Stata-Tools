"""Core TVEvent class implementation."""

from typing import Optional, Union, List, Dict
import pandas as pd
import numpy as np
from pathlib import Path
import warnings

from .exceptions import TVEventError
from .result import TVEventResult


class TVEvent:
    """
    Integrate events and competing risks into time-varying datasets.

    This class processes interval data (from tvexpose/tvmerge) and event data
    to create survival analysis-ready datasets with proper event flags and
    competing risk handling.

    Examples
    --------
    >>> # Basic usage with competing risk
    >>> tv = TVEvent(
    ...     intervals_data=tvexpose_output,
    ...     events_data='cohort.csv',
    ...     id_col='person_id',
    ...     date_col='event_date',
    ...     compete_cols=['death_date']
    ... )
    >>> result = tv.process()

    >>> # Recurring events with time generation
    >>> tv = TVEvent(
    ...     intervals_data=intervals_df,
    ...     events_data=events_df,
    ...     id_col='id',
    ...     date_col='hospitalization_date',
    ...     event_type='recurring',
    ...     time_col='interval_years',
    ...     time_unit='years'
    ... )
    >>> result = tv.process()
    """

    def __init__(
        self,
        intervals_data: Union[pd.DataFrame, str, Path],
        events_data: Union[pd.DataFrame, str, Path],
        id_col: str,
        date_col: str,
        *,
        compete_cols: Optional[List[str]] = None,
        event_type: str = 'single',
        output_col: str = '_failure',
        continuous_cols: Optional[List[str]] = None,
        time_col: Optional[str] = None,
        time_unit: str = 'days',
        keep_cols: Optional[List[str]] = None,
        event_labels: Optional[Dict[int, str]] = None,
        replace_existing: bool = False,
    ):
        """
        Initialize TVEvent processor.

        Parameters
        ----------
        intervals_data : DataFrame, str, or Path
            Time-varying interval data with 'start' and 'stop' columns.
            If str/Path, will be loaded as CSV/pickle/parquet based on extension.

        events_data : DataFrame, str, or Path
            Event data containing id_col and date_col.
            If str/Path, will be loaded as CSV/pickle/parquet based on extension.

        id_col : str
            Person identifier column present in both datasets.

        date_col : str
            Primary event date column in events_data.

        compete_cols : list of str, optional
            Date columns in events_data representing competing risks.
            Earliest date wins. Status: 1=primary, 2=first compete, 3=second, etc.

        event_type : {'single', 'recurring'}, default 'single'
            - 'single': Terminal event, drops all follow-up after first event
            - 'recurring': Multiple events allowed, retains all intervals

        output_col : str, default '_failure'
            Name for event indicator column.
            Values: 0=censored, 1=primary event, 2+=competing events.

        continuous_cols : list of str, optional
            Columns in intervals_data to adjust proportionally when splitting.
            E.g., cumulative dose variables that should scale with interval duration.

        time_col : str, optional
            Name for generated duration column. If None, no time column created.

        time_unit : {'days', 'months', 'years'}, default 'days'
            Unit for time_col calculation.
            - 'days': stop - start
            - 'months': (stop - start) / 30.4375
            - 'years': (stop - start) / 365.25

        keep_cols : list of str, optional
            Additional columns from events_data to merge into output.
            If None, keeps all columns except id_col, date_col, and compete_cols.

        event_labels : dict, optional
            Custom labels for event status values.
            E.g., {0: 'Censored', 1: 'Disease', 2: 'Death'}
            If None, generates default labels from column names.

        replace_existing : bool, default False
            If True, overwrites output_col and time_col if they exist.
            If False, raises error if columns already exist.
        """
        # Store parameters
        self.id_col = id_col
        self.date_col = date_col
        self.compete_cols = compete_cols or []
        self.event_type = event_type.lower()
        self.output_col = output_col
        self.continuous_cols = continuous_cols or []
        self.time_col = time_col
        self.time_unit = time_unit.lower()
        self.keep_cols = keep_cols
        self.event_labels = event_labels
        self.replace_existing = replace_existing

        # Load data
        self.intervals = self._load_data(intervals_data, 'intervals_data')
        self.events = self._load_data(events_data, 'events_data')

        # Validate inputs (deferred to method)
        self._validate_inputs()

        # State tracking
        self._n_splits = 0
        self._n_events = 0

    def _load_data(
        self,
        data: Union[pd.DataFrame, str, Path],
        param_name: str
    ) -> pd.DataFrame:
        """
        Load data from DataFrame or file path.

        Parameters
        ----------
        data : DataFrame, str, or Path
            Data to load.
        param_name : str
            Parameter name for error messages.

        Returns
        -------
        pd.DataFrame
            Loaded data.

        Raises
        ------
        TVEventError
            If data cannot be loaded.
        """
        if isinstance(data, pd.DataFrame):
            return data.copy()

        path = Path(data)
        if not path.exists():
            raise TVEventError(
                f"{param_name}: File not found: {path}"
            )

        # Detect format from extension
        suffix = path.suffix.lower()
        try:
            if suffix == '.csv':
                return pd.read_csv(path)
            elif suffix in ['.pkl', '.pickle']:
                return pd.read_pickle(path)
            elif suffix == '.parquet':
                return pd.read_parquet(path)
            elif suffix in ['.dta']:
                return pd.read_stata(path)
            else:
                raise TVEventError(
                    f"{param_name}: Unsupported file format: {suffix}. "
                    f"Use .csv, .pkl, .parquet, or .dta"
                )
        except Exception as e:
            raise TVEventError(
                f"{param_name}: Failed to load {path}: {e}"
            ) from e

    def _validate_inputs(self) -> None:
        """
        Validate all inputs before processing.

        Raises
        ------
        TVEventError
            If any validation check fails.
        """
        # Validate event_type
        if self.event_type not in ['single', 'recurring']:
            raise TVEventError(
                f"event_type must be 'single' or 'recurring', got '{self.event_type}'"
            )

        # Validate time_unit
        if self.time_unit not in ['days', 'months', 'years']:
            raise TVEventError(
                f"time_unit must be 'days', 'months', or 'years', got '{self.time_unit}'"
            )

        # Validate intervals_data structure
        if 'start' not in self.intervals.columns:
            raise TVEventError(
                "intervals_data must have 'start' column. "
                "Ensure data comes from tvexpose/tvmerge."
            )
        if 'stop' not in self.intervals.columns:
            raise TVEventError(
                "intervals_data must have 'stop' column. "
                "Ensure data comes from tvexpose/tvmerge."
            )
        if self.id_col not in self.intervals.columns:
            raise TVEventError(
                f"id_col '{self.id_col}' not found in intervals_data. "
                f"Available: {list(self.intervals.columns)}"
            )

        # Validate continuous_cols exist and are numeric
        for col in self.continuous_cols:
            if col not in self.intervals.columns:
                raise TVEventError(
                    f"continuous_cols: '{col}' not found in intervals_data"
                )
            if not pd.api.types.is_numeric_dtype(self.intervals[col]):
                raise TVEventError(
                    f"continuous_cols: '{col}' must be numeric"
                )

        # Validate events_data structure
        if self.id_col not in self.events.columns:
            raise TVEventError(
                f"id_col '{self.id_col}' not found in events_data. "
                f"Available: {list(self.events.columns)}"
            )
        if self.date_col not in self.events.columns:
            raise TVEventError(
                f"date_col '{self.date_col}' not found in events_data. "
                f"Available: {list(self.events.columns)}"
            )

        # Validate compete_cols
        for col in self.compete_cols:
            if col not in self.events.columns:
                raise TVEventError(
                    f"compete_cols: '{col}' not found in events_data"
                )

        # Validate output_col doesn't exist (unless replace=True)
        if not self.replace_existing:
            if self.output_col in self.intervals.columns:
                raise TVEventError(
                    f"Column '{self.output_col}' already exists in intervals_data. "
                    f"Use replace_existing=True to overwrite."
                )
            if self.time_col and self.time_col in self.intervals.columns:
                raise TVEventError(
                    f"Column '{self.time_col}' already exists in intervals_data. "
                    f"Use replace_existing=True to overwrite."
                )

        # Validate date columns are datetime
        for col in [self.date_col] + self.compete_cols:
            if col in self.events.columns:
                if not pd.api.types.is_datetime64_any_dtype(self.events[col]):
                    # Try to convert
                    try:
                        self.events[col] = pd.to_datetime(self.events[col])
                    except Exception as e:
                        raise TVEventError(
                            f"Could not convert '{col}' to datetime: {e}"
                        ) from e

        # Validate start/stop are datetime
        for col in ['start', 'stop']:
            if not pd.api.types.is_datetime64_any_dtype(self.intervals[col]):
                try:
                    self.intervals[col] = pd.to_datetime(self.intervals[col])
                except Exception as e:
                    raise TVEventError(
                        f"Could not convert '{col}' to datetime: {e}"
                    ) from e

        # Validate intervals are valid (start < stop)
        invalid_intervals = self.intervals[
            self.intervals['start'] >= self.intervals['stop']
        ]
        if len(invalid_intervals) > 0:
            raise TVEventError(
                f"Found {len(invalid_intervals)} intervals where start >= stop. "
                f"Sample IDs: {invalid_intervals[self.id_col].head().tolist()}"
            )

        # Determine keep_cols if not specified
        if self.keep_cols is None:
            exclude_cols = {self.id_col, self.date_col} | set(self.compete_cols)
            self.keep_cols = [
                col for col in self.events.columns
                if col not in exclude_cols
            ]

    def _resolve_competing_risks(self) -> pd.DataFrame:
        """
        Resolve competing risks by selecting earliest event date.

        Algorithm:
        1. Start with primary date (date_col) as effective date, type = 1
        2. For each competing risk column:
           - If compete date < effective date (or effective is missing):
             - Update effective date to compete date
             - Update type to compete index (2, 3, 4, ...)
        3. Keep only rows with non-missing effective dates
        4. Remove duplicate id-date combinations

        Returns
        -------
        pd.DataFrame
            Events with columns:
            - id_col
            - '_eff_date': Effective event date (earliest)
            - '_eff_type': Event type (1=primary, 2+=competing)
            - keep_cols: Additional columns from events_data
        """
        events = self.events.copy()

        # Floor dates to day precision (remove time component)
        events[self.date_col] = events[self.date_col].dt.floor('D')

        # Initialize with primary event
        events['_eff_date'] = events[self.date_col]
        events['_eff_type'] = pd.NA
        events.loc[events[self.date_col].notna(), '_eff_type'] = 1

        # Check competing risks - earliest wins
        for i, comp_col in enumerate(self.compete_cols, start=2):
            events[comp_col] = events[comp_col].dt.floor('D')

            # Update when compete is earlier or primary is missing
            mask = (
                events[comp_col].notna() &
                (
                    (events[comp_col] < events['_eff_date']) |
                    events['_eff_date'].isna()
                )
            )
            events.loc[mask, '_eff_date'] = events.loc[mask, comp_col]
            events.loc[mask, '_eff_type'] = i

        # Keep only rows with events
        events = events[events['_eff_date'].notna()].copy()

        if len(events) == 0:
            raise TVEventError(
                "No events found in events_data. All date columns are missing."
            )

        # Convert type to integer
        events['_eff_type'] = events['_eff_type'].astype('Int64')

        # Select columns to keep
        keep_cols = [self.id_col, '_eff_date', '_eff_type'] + self.keep_cols
        events = events[keep_cols].copy()

        # Remove duplicates (same person, same date)
        # Keep first occurrence
        events = events.drop_duplicates(
            subset=[self.id_col, '_eff_date'],
            keep='first'
        )

        return events

    def _identify_split_points(
        self,
        events: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Identify intervals that need splitting.

        An interval needs splitting if an event occurs strictly between
        start and stop: start < event_date < stop

        Parameters
        ----------
        events : pd.DataFrame
            Resolved events from _resolve_competing_risks()

        Returns
        -------
        pd.DataFrame
            Intervals joined with events where splitting is needed.
            Contains original interval data plus:
            - '_eff_date': Event date that triggers split
            - '_needs_split': Boolean flag
        """
        # Get unique intervals for joining
        intervals_key = (
            self.intervals[[self.id_col, 'start', 'stop']]
            .drop_duplicates()
        )

        # Join intervals with events on id
        # This creates all combinations of intervals and events for each person
        merged = intervals_key.merge(
            events[[self.id_col, '_eff_date']],
            on=self.id_col,
            how='inner'
        )

        # Identify splits: event strictly between start and stop
        merged['_needs_split'] = (
            (merged['_eff_date'] > merged['start']) &
            (merged['_eff_date'] < merged['stop'])
        )

        # Keep only splits
        splits = merged[merged['_needs_split']].copy()

        # Remove duplicates (same interval might have multiple events, take first)
        splits = splits.drop_duplicates(
            subset=[self.id_col, 'start', 'stop'],
            keep='first'
        )

        self._n_splits = len(splits)

        return splits[[self.id_col, '_eff_date']]

    def _execute_splits(
        self,
        splits: pd.DataFrame,
        events: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Split intervals at event dates.

        Algorithm:
        1. Mark original duration before any changes
        2. If splits exist:
           a. Join intervals with split points
           b. Mark intervals needing split
           c. Duplicate rows that need splitting
           d. For first copy: set stop = event_date
           e. For second copy: set start = event_date
        3. Remove duplicate intervals (same id-start-stop)

        Parameters
        ----------
        splits : pd.DataFrame
            Split points from _identify_split_points()
        events : pd.DataFrame
            Resolved events

        Returns
        -------
        pd.DataFrame
            Intervals with splits applied and '_orig_duration' column.
        """
        intervals = self.intervals.copy()

        # Mark original duration BEFORE splitting
        intervals['_orig_duration'] = (
            intervals['stop'] - intervals['start']
        ).dt.total_seconds() / 86400  # Convert to days

        if len(splits) == 0:
            # No splits needed
            return intervals

        # Join intervals with split dates
        intervals = intervals.merge(
            splits,
            on=self.id_col,
            how='left'
        )

        # Mark rows that need splitting
        intervals['_needs_split'] = (
            intervals['_eff_date'].notna() &
            (intervals['_eff_date'] > intervals['start']) &
            (intervals['_eff_date'] < intervals['stop'])
        )

        # Separate into split and non-split
        to_split = intervals[intervals['_needs_split']].copy()
        no_split = intervals[~intervals['_needs_split']].copy()

        if len(to_split) > 0:
            # Create pre-event intervals (original start to event date)
            pre_event = to_split.copy()
            pre_event['stop'] = pre_event['_eff_date']

            # Create post-event intervals (event date to original stop)
            post_event = to_split.copy()
            post_event['start'] = post_event['_eff_date']

            # Combine all intervals
            intervals = pd.concat(
                [no_split, pre_event, post_event],
                ignore_index=True
            )
        else:
            intervals = no_split

        # Clean up temporary columns
        intervals = intervals.drop(columns=['_eff_date', '_needs_split'])

        # Remove exact duplicates (same id, start, stop)
        # Keep first occurrence, preserve original row order
        intervals = intervals.drop_duplicates(
            subset=[self.id_col, 'start', 'stop'],
            keep='first'
        )

        # Sort for consistent output
        intervals = intervals.sort_values(
            [self.id_col, 'start', 'stop']
        ).reset_index(drop=True)

        return intervals

    def _adjust_continuous_vars(
        self,
        intervals: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Proportionally adjust continuous variables after splitting.

        Algorithm:
        1. Calculate new duration: stop - start
        2. Calculate ratio: new_duration / orig_duration
        3. For each continuous variable: value *= ratio
        4. Handle edge cases:
           - If orig_duration == 0: ratio = 1 (no adjustment)
           - If new_duration == 0: ratio = 0 (value becomes 0)
           - Clip ratio to [0, 1] to prevent negative/inflated values

        Parameters
        ----------
        intervals : pd.DataFrame
            Intervals with '_orig_duration' column.

        Returns
        -------
        pd.DataFrame
            Intervals with adjusted continuous variables.
        """
        if not self.continuous_cols:
            # No adjustment needed
            intervals = intervals.drop(columns=['_orig_duration'])
            return intervals

        intervals = intervals.copy()

        # Calculate new duration in days
        intervals['_new_duration'] = (
            intervals['stop'] - intervals['start']
        ).dt.total_seconds() / 86400

        # Calculate adjustment ratio
        # Handle division by zero: if original is 0, ratio is 1 (no change)
        intervals['_ratio'] = np.where(
            intervals['_orig_duration'] == 0,
            1.0,
            intervals['_new_duration'] / intervals['_orig_duration']
        )

        # If new duration is 0 but original wasn't, ratio should be 0
        intervals.loc[
            (intervals['_new_duration'] == 0) & (intervals['_orig_duration'] > 0),
            '_ratio'
        ] = 0.0

        # Clip ratio to [0, 1] to prevent negative/inflated values
        intervals['_ratio'] = intervals['_ratio'].clip(0, 1)

        # Apply adjustment to each continuous variable
        for col in self.continuous_cols:
            intervals[col] = intervals[col] * intervals['_ratio']

        # Clean up temporary columns
        intervals = intervals.drop(
            columns=['_orig_duration', '_new_duration', '_ratio']
        )

        return intervals

    def _merge_event_flags(
        self,
        intervals: pd.DataFrame,
        events: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Merge event flags into intervals.

        Algorithm:
        1. Match intervals with events where:
           - id matches
           - stop == event_date (event occurs at end of interval)
        2. Create output_col:
           - 0 if no match (censored)
           - event_type if match (1, 2, 3, ...)
        3. Bring in keep_cols from events (only for matched rows)

        Parameters
        ----------
        intervals : pd.DataFrame
            Intervals after splitting and adjustment.
        events : pd.DataFrame
            Resolved events with '_eff_type'.

        Returns
        -------
        pd.DataFrame
            Intervals with event flags and keep_cols merged.
        """
        intervals = intervals.copy()

        # Prepare events for matching
        events_match = events.copy()
        events_match = events_match.rename(columns={'_eff_date': 'stop'})

        # Merge on id and stop date
        # Use left join to keep all intervals
        merge_cols = [self.id_col, 'stop']
        intervals = intervals.merge(
            events_match,
            on=merge_cols,
            how='left',
            suffixes=('', '_event')
        )

        # Create output column
        intervals[self.output_col] = intervals['_eff_type'].fillna(0).astype('Int64')

        # Drop temporary column
        intervals = intervals.drop(columns=['_eff_type'])

        # Count events
        self._n_events = (intervals[self.output_col] > 0).sum()

        return intervals

    def _apply_type_logic(
        self,
        intervals: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Apply single vs recurring event logic.

        Single Event Logic:
        1. Identify first event per person (earliest stop where event > 0)
        2. Drop all intervals starting at or after first event
        3. Set event flag to 0 for duplicate events (keep only first)

        Recurring Event Logic:
        - No changes needed, keep all intervals

        Parameters
        ----------
        intervals : pd.DataFrame
            Intervals with event flags.

        Returns
        -------
        pd.DataFrame
            Intervals with type logic applied.
        """
        if self.event_type == 'recurring':
            # No changes for recurring events
            return intervals

        # Single event logic
        intervals = intervals.copy()

        # Rank events within each person by stop date
        intervals['_event_rank'] = (
            intervals[intervals[self.output_col] > 0]
            .groupby(self.id_col)['stop']
            .rank(method='first')
        )

        # Identify first event time per person
        first_events = (
            intervals[intervals[self.output_col] > 0]
            .groupby(self.id_col)['stop']
            .min()
            .rename('_first_event_time')
        )

        # Merge first event times
        intervals = intervals.merge(
            first_events,
            left_on=self.id_col,
            right_index=True,
            how='left'
        )

        # Drop intervals starting at or after first event
        intervals = intervals[
            intervals['_first_event_time'].isna() |
            (intervals['start'] < intervals['_first_event_time'])
        ].copy()

        # Set event flag to 0 for duplicate events (keep only first)
        intervals.loc[
            (intervals['_event_rank'].notna()) & (intervals['_event_rank'] > 1),
            self.output_col
        ] = 0

        # Clean up temporary columns
        intervals = intervals.drop(
            columns=['_event_rank', '_first_event_time']
        )

        return intervals

    def _generate_time_variable(
        self,
        intervals: pd.DataFrame
    ) -> pd.DataFrame:
        """
        Generate time duration variable.

        Parameters
        ----------
        intervals : pd.DataFrame
            Final intervals.

        Returns
        -------
        pd.DataFrame
            Intervals with time column (if requested).
        """
        if not self.time_col:
            return intervals

        intervals = intervals.copy()

        # Calculate duration in days
        duration_days = (
            intervals['stop'] - intervals['start']
        ).dt.total_seconds() / 86400

        # Convert to requested unit
        if self.time_unit == 'days':
            intervals[self.time_col] = duration_days
        elif self.time_unit == 'months':
            intervals[self.time_col] = duration_days / 30.4375
        elif self.time_unit == 'years':
            intervals[self.time_col] = duration_days / 365.25

        return intervals

    def _generate_labels(
        self,
        events: pd.DataFrame
    ) -> Dict[int, str]:
        """
        Generate event labels.

        Parameters
        ----------
        events : pd.DataFrame
            Resolved events.

        Returns
        -------
        dict
            Mapping of status codes to labels.
        """
        if self.event_labels:
            # User-provided labels
            labels = {0: 'Censored', **self.event_labels}
        else:
            # Generate from column names
            labels = {0: 'Censored'}
            labels[1] = f'Event: {self.date_col}'

            for i, col in enumerate(self.compete_cols, start=2):
                labels[i] = f'Competing: {col}'

        return labels

    def _validate_and_warn_edge_cases(
        self,
        events: pd.DataFrame,
        intervals: pd.DataFrame
    ) -> None:
        """
        Check for edge cases and issue warnings.

        This is called during processing to alert users to
        potential data quality issues that don't prevent
        execution but may affect interpretation.
        """
        # Check for events outside all intervals
        events_with_intervals = events.merge(
            intervals[[self.id_col]].drop_duplicates(),
            on=self.id_col,
            how='inner'
        )
        unmatched_events = len(events) - len(events_with_intervals)
        if unmatched_events > 0:
            warnings.warn(
                f"{unmatched_events} events have no matching intervals "
                f"and will be ignored.",
                UserWarning
            )

        # Check for duplicate events (same person, same date)
        duplicates = events.duplicated(
            subset=[self.id_col, '_eff_date'],
            keep=False
        ).sum()
        if duplicates > 0:
            warnings.warn(
                f"{duplicates} duplicate events found (same person, same date). "
                f"Keeping first occurrence.",
                UserWarning
            )

        # Check for zero-duration intervals
        zero_duration = (intervals['start'] == intervals['stop']).sum()
        if zero_duration > 0:
            warnings.warn(
                f"{zero_duration} zero-duration intervals found. "
                f"These will be kept as-is.",
                UserWarning
            )

    def process(self) -> TVEventResult:
        """
        Execute the full tvevent algorithm.

        Returns
        -------
        TVEventResult
            Result object containing:
            - data: Processed DataFrame with event flags
            - n_total: Total observations
            - n_events: Number of events flagged
            - n_splits: Number of intervals split
            - event_labels: Mapping of status codes to labels
            - output_col: Name of event indicator column
            - time_col: Name of time column (if generated)
            - event_type: 'single' or 'recurring'

        Raises
        ------
        TVEventError
            If processing fails validation or encounters data issues.
        """
        # Implementation steps (methods below)
        events_resolved = self._resolve_competing_risks()

        # Validate and warn about edge cases
        self._validate_and_warn_edge_cases(events_resolved, self.intervals)

        intervals_with_events = self._identify_split_points(events_resolved)
        intervals_split = self._execute_splits(intervals_with_events, events_resolved)
        intervals_adjusted = self._adjust_continuous_vars(intervals_split)
        intervals_flagged = self._merge_event_flags(intervals_adjusted, events_resolved)
        intervals_typed = self._apply_type_logic(intervals_flagged)
        result = self._generate_time_variable(intervals_typed)
        labels = self._generate_labels(events_resolved)

        return TVEventResult(
            data=result,
            n_total=len(result),
            n_events=self._n_events,
            n_splits=self._n_splits,
            event_labels=labels,
            output_col=self.output_col,
            time_col=self.time_col,
            event_type=self.event_type,
        )

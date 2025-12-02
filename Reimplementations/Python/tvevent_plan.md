# Python Reimplementation Plan: tvevent

## Overview

**Purpose**: Integrate outcome events and competing risks into time-varying datasets created by tvexpose/tvmerge.

**Core Functionality**:
- Resolves competing risks by selecting the earliest event date
- Splits intervals when events occur mid-interval (start < event < stop)
- Proportionally adjusts continuous variables (e.g., cumulative dose) when splitting
- Flags event types (0=censored, 1=primary, 2+=competing)
- Handles single (terminal) vs recurring events
- Generates time duration variables in days/months/years

**Typical Use Case**: After creating time-varying exposure datasets with tvexpose/tvmerge, integrate outcomes (e.g., disease progression, death, emigration) to prepare for survival analysis.

---

## Design: Class-Based Implementation

**Recommendation**: Implement as a `TVEvent` class for better state management, validation, and extensibility.

### Class Structure

```python
from typing import Optional, Union, List, Dict, Tuple
import pandas as pd
import numpy as np
from pathlib import Path
from dataclasses import dataclass

@dataclass
class TVEventResult:
    """Container for tvevent results and metadata."""
    data: pd.DataFrame
    n_total: int
    n_events: int
    n_splits: int
    event_labels: Dict[int, str]
    output_col: str
    time_col: Optional[str]
    event_type: str

    def __repr__(self) -> str:
        return (
            f"TVEventResult(\n"
            f"  Total observations: {self.n_total:,}\n"
            f"  Events flagged: {self.n_events:,}\n"
            f"  Intervals split: {self.n_splits:,}\n"
            f"  Event type: {self.event_type}\n"
            f"  Output column: {self.output_col}\n"
            f")"
        )


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
```

---

## Detailed Implementation: Step-by-Step Methods

### 1. Data Loading and Validation

```python
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
```

### 2. Resolve Competing Risks

```python
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
```

### 3. Identify Split Points

```python
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
```

### 4. Execute Splits

```python
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
```

### 5. Adjust Continuous Variables

```python
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
```

### 6. Merge Event Flags

```python
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
```

### 7. Apply Type Logic

```python
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
```

### 8. Generate Time Variable

```python
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
```

---

## Custom Exceptions

```python
class TVEventError(Exception):
    """Base exception for TVEvent errors."""
    pass


class TVEventValidationError(TVEventError):
    """Raised when input validation fails."""
    pass


class TVEventProcessingError(TVEventError):
    """Raised when processing encounters an error."""
    pass
```

---

## Edge Case Handling

### Comprehensive Edge Cases

| Edge Case | Handling Strategy |
|-----------|------------------|
| **Events exactly at interval boundaries** | - Events at `start`: No split (event before interval) <br> - Events at `stop`: No split (event at end, already correct) |
| **Events outside all intervals** | - Warning logged <br> - Events not merged (no matching intervals) <br> - Return list of unmatched events |
| **Multiple events same day** | - Keep first event per person-date <br> - Log warning about duplicates |
| **Missing event dates** | - Exclude from events DataFrame <br> - Log number excluded |
| **Zero-duration intervals** | - Keep as-is (valid boundary condition) <br> - Continuous adjustment: ratio = 1 (no change) |
| **Overlapping intervals** | - Allow (may be intentional from tvmerge) <br> - Each split independently |
| **Empty events_data** | - Raise error (no events to integrate) |
| **Empty intervals_data** | - Raise error (nothing to process) |
| **No events match any intervals** | - Return intervals with all flags = 0 <br> - Warning logged |
| **Single event matches multiple intervals** | - Split all matching intervals <br> - Normal behavior for overlapping intervals |
| **Negative continuous values after adjustment** | - Prevent with ratio clipping to [0, 1] |
| **Datetime without timezone** | - Convert to timezone-naive for consistency |
| **Datetime with timezone** | - Convert to UTC then make timezone-naive |

### Implementation Pattern

```python
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
        import warnings

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
```

---

## Testing Strategy

### Test Structure with pytest

```python
# tests/test_tvevent.py

import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from tvevent import TVEvent, TVEventError

@pytest.fixture
def sample_intervals():
    """Create sample interval data."""
    return pd.DataFrame({
        'id': [1, 1, 1, 2, 2],
        'start': pd.to_datetime([
            '2020-01-01', '2020-04-01', '2020-07-01',
            '2020-01-01', '2020-06-01'
        ]),
        'stop': pd.to_datetime([
            '2020-03-31', '2020-06-30', '2020-12-31',
            '2020-05-31', '2020-12-31'
        ]),
        'exposure': [0, 1, 1, 0, 0],
        'cumulative_dose': [0.0, 100.0, 200.0, 0.0, 0.0]
    })


@pytest.fixture
def sample_events():
    """Create sample event data."""
    return pd.DataFrame({
        'id': [1, 2],
        'event_date': pd.to_datetime(['2020-05-15', '2020-08-01']),
        'death_date': pd.to_datetime(['2020-11-01', pd.NaT]),
        'diagnosis_code': ['A01', 'B02']
    })


class TestTVEventBasic:
    """Test basic functionality."""

    def test_initialization(self, sample_intervals, sample_events):
        """Test TVEvent can be initialized."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date'
        )
        assert tv.id_col == 'id'
        assert tv.event_type == 'single'

    def test_process_basic(self, sample_intervals, sample_events):
        """Test basic processing without errors."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        assert isinstance(result.data, pd.DataFrame)
        assert '_failure' in result.data.columns
        assert result.n_total > 0
        assert result.n_events >= 0

    def test_competing_risk(self, sample_intervals, sample_events):
        """Test competing risk resolution."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date',
            compete_cols=['death_date']
        )
        result = tv.process()

        # Check status values
        assert 0 in result.data['_failure'].values  # Censored
        assert 1 in result.data['_failure'].values or \
               2 in result.data['_failure'].values  # Event or compete


class TestTVEventValidation:
    """Test input validation."""

    def test_missing_start_column(self, sample_events):
        """Test error when 'start' column missing."""
        bad_intervals = pd.DataFrame({
            'id': [1, 2],
            'stop': pd.to_datetime(['2020-12-31', '2020-12-31'])
        })

        with pytest.raises(TVEventError, match="must have 'start' column"):
            TVEvent(
                intervals_data=bad_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date'
            )

    def test_missing_stop_column(self, sample_events):
        """Test error when 'stop' column missing."""
        bad_intervals = pd.DataFrame({
            'id': [1, 2],
            'start': pd.to_datetime(['2020-01-01', '2020-01-01'])
        })

        with pytest.raises(TVEventError, match="must have 'stop' column"):
            TVEvent(
                intervals_data=bad_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date'
            )

    def test_invalid_event_type(self, sample_intervals, sample_events):
        """Test error for invalid event_type."""
        with pytest.raises(TVEventError, match="event_type must be"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date',
                event_type='invalid'
            )

    def test_invalid_time_unit(self, sample_intervals, sample_events):
        """Test error for invalid time_unit."""
        with pytest.raises(TVEventError, match="time_unit must be"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date',
                time_col='duration',
                time_unit='weeks'
            )

    def test_column_exists_no_replace(self, sample_intervals, sample_events):
        """Test error when output column exists without replace."""
        sample_intervals['_failure'] = 0

        with pytest.raises(TVEventError, match="already exists"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data=sample_events,
                id_col='id',
                date_col='event_date',
                replace_existing=False
            )


class TestTVEventSplitting:
    """Test interval splitting logic."""

    def test_split_at_event(self, sample_intervals, sample_events):
        """Test interval is split when event occurs mid-interval."""
        tv = TVEvent(
            intervals_data=sample_intervals,
            events_data=sample_events,
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        # Person 1 has event on 2020-05-15 (mid-interval 2020-04-01 to 2020-06-30)
        # Should create 2 intervals from that split
        person1 = result.data[result.data['id'] == 1]

        # Check that we have an interval ending at event date
        assert any(person1['stop'] == pd.Timestamp('2020-05-15'))
        # And an interval starting at event date
        assert any(person1['start'] == pd.Timestamp('2020-05-15'))

    def test_no_split_at_boundary(self):
        """Test no split when event exactly at boundary."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-12-31'])  # Exactly at stop
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        # Should have 1 interval (no split)
        assert len(result.data) == 1
        assert result.data.iloc[0]['_failure'] == 1  # Event flagged


class TestTVEventContinuous:
    """Test continuous variable adjustment."""

    def test_continuous_adjustment(self):
        """Test continuous variables are adjusted proportionally."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),  # 366 days (leap year)
            'dose': [366.0]  # 1 unit per day
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-07-01'])  # Mid-year
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            continuous_cols=['dose']
        )
        result = tv.process()

        # Should have 2 intervals
        assert len(result.data) == 2

        # First interval: Jan 1 to Jul 1 (182 days)
        # Second interval: Jul 1 to Dec 31 (184 days)
        first = result.data[result.data['stop'] == pd.Timestamp('2020-07-01')]
        second = result.data[result.data['start'] == pd.Timestamp('2020-07-01')]

        # Doses should be proportional to duration
        assert abs(first['dose'].values[0] - 182.0) < 1e-6
        assert abs(second['dose'].values[0] - 184.0) < 1e-6


class TestTVEventTypeLogic:
    """Test single vs recurring event logic."""

    def test_single_event_censors_after_first(self):
        """Test single event type drops followup after first event."""
        intervals = pd.DataFrame({
            'id': [1, 1, 1],
            'start': pd.to_datetime(['2020-01-01', '2020-04-01', '2020-07-01']),
            'stop': pd.to_datetime(['2020-03-31', '2020-06-30', '2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1, 1],
            'event_date': pd.to_datetime(['2020-05-15', '2020-10-01'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            event_type='single'
        )
        result = tv.process()

        # Should only have intervals up to first event (2020-05-15)
        assert result.data['stop'].max() == pd.Timestamp('2020-05-15')

        # Should have exactly 1 event flagged
        assert (result.data['_failure'] > 0).sum() == 1

    def test_recurring_event_keeps_all(self):
        """Test recurring event type keeps all intervals."""
        intervals = pd.DataFrame({
            'id': [1, 1, 1],
            'start': pd.to_datetime(['2020-01-01', '2020-04-01', '2020-07-01']),
            'stop': pd.to_datetime(['2020-03-31', '2020-06-30', '2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1, 1],
            'event_date': pd.to_datetime(['2020-05-15', '2020-10-01'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            event_type='recurring'
        )
        result = tv.process()

        # Should keep intervals beyond first event
        assert result.data['stop'].max() == pd.Timestamp('2020-12-31')

        # Should have 2 events flagged
        assert (result.data['_failure'] > 0).sum() == 2


class TestTVEventTimeGeneration:
    """Test time variable generation."""

    def test_time_days(self):
        """Test time generation in days."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-01-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-01-31'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            time_col='duration',
            time_unit='days'
        )
        result = tv.process()

        assert 'duration' in result.data.columns
        assert result.data['duration'].iloc[0] == 30.0

    def test_time_months(self):
        """Test time generation in months."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-01-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-01-31'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            time_col='duration',
            time_unit='months'
        )
        result = tv.process()

        expected_months = 30.0 / 30.4375
        assert abs(result.data['duration'].iloc[0] - expected_months) < 1e-6

    def test_time_years(self):
        """Test time generation in years."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-12-31'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            time_col='duration',
            time_unit='years'
        )
        result = tv.process()

        expected_years = 365.0 / 365.25  # 2020 is leap year
        assert abs(result.data['duration'].iloc[0] - expected_years) < 1e-6


class TestTVEventEdgeCases:
    """Test edge cases."""

    def test_empty_events(self, sample_intervals):
        """Test error with no events."""
        empty_events = pd.DataFrame({
            'id': [],
            'event_date': pd.to_datetime([])
        })

        with pytest.raises(TVEventError, match="No events found"):
            tv = TVEvent(
                intervals_data=sample_intervals,
                events_data=empty_events,
                id_col='id',
                date_col='event_date'
            )
            tv.process()

    def test_events_outside_intervals(self):
        """Test events that don't match any intervals."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [2],  # Different person
            'event_date': pd.to_datetime(['2020-06-15'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date'
        )

        with pytest.warns(UserWarning, match="no matching intervals"):
            result = tv.process()

        # Should have all censored
        assert (result.data['_failure'] == 0).all()

    def test_zero_duration_interval(self):
        """Test handling of zero-duration intervals."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-01-01']),  # Same day
            'dose': [0.0]
        })
        events = pd.DataFrame({
            'id': [1],
            'event_date': pd.to_datetime(['2020-01-01'])
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date',
            continuous_cols=['dose']
        )

        result = tv.process()
        assert len(result.data) == 1
        # Dose should remain 0
        assert result.data['dose'].iloc[0] == 0.0

    def test_multiple_events_same_day(self):
        """Test multiple events on same day (duplicates)."""
        intervals = pd.DataFrame({
            'id': [1],
            'start': pd.to_datetime(['2020-01-01']),
            'stop': pd.to_datetime(['2020-12-31']),
        })
        events = pd.DataFrame({
            'id': [1, 1],
            'event_date': pd.to_datetime(['2020-06-15', '2020-06-15'])  # Same day
        })

        tv = TVEvent(
            intervals_data=intervals,
            events_data=events,
            id_col='id',
            date_col='event_date'
        )

        with pytest.warns(UserWarning, match="duplicate events"):
            result = tv.process()

        # Should have only 1 event flagged (duplicates removed)
        assert (result.data['_failure'] > 0).sum() == 1


class TestTVEventFileIO:
    """Test file loading functionality."""

    def test_load_csv(self, tmp_path, sample_intervals, sample_events):
        """Test loading from CSV files."""
        intervals_path = tmp_path / "intervals.csv"
        events_path = tmp_path / "events.csv"

        sample_intervals.to_csv(intervals_path, index=False)
        sample_events.to_csv(events_path, index=False)

        tv = TVEvent(
            intervals_data=str(intervals_path),
            events_data=str(events_path),
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        assert isinstance(result.data, pd.DataFrame)

    def test_load_pickle(self, tmp_path, sample_intervals, sample_events):
        """Test loading from pickle files."""
        intervals_path = tmp_path / "intervals.pkl"
        events_path = tmp_path / "events.pkl"

        sample_intervals.to_pickle(intervals_path)
        sample_events.to_pickle(events_path)

        tv = TVEvent(
            intervals_data=str(intervals_path),
            events_data=str(events_path),
            id_col='id',
            date_col='event_date'
        )
        result = tv.process()

        assert isinstance(result.data, pd.DataFrame)

    def test_file_not_found(self, sample_intervals):
        """Test error when file doesn't exist."""
        with pytest.raises(TVEventError, match="File not found"):
            TVEvent(
                intervals_data=sample_intervals,
                events_data='/nonexistent/file.csv',
                id_col='id',
                date_col='event_date'
            )
```

### Test Coverage Requirements

- **Minimum coverage**: 90%
- **Critical paths**: 100% coverage for:
  - Input validation
  - Competing risk resolution
  - Interval splitting
  - Continuous variable adjustment
  - Type logic (single vs recurring)

### Test Data Fixtures

Create realistic test datasets covering:
- Simple case: 1 person, 1 event, 1 interval
- Split case: Event mid-interval
- Boundary case: Event at interval boundary
- Competing risk: Primary and competing events
- Multiple events: Recurring events
- Complex case: Multiple people, multiple intervals, competing risks

---

## Integration Examples

### Example 1: Basic Workflow

```python
import pandas as pd
from tvexpose import TVExpose
from tvevent import TVEvent

# Load cohort data
cohort = pd.read_csv('cohort.csv')
exposures = pd.read_csv('medications.csv')

# Step 1: Create time-varying exposure dataset
tv_exposures = TVExpose(
    cohort_data=cohort,
    exposure_data=exposures,
    id_col='person_id',
    start_col='rx_start',
    stop_col='rx_stop',
    entry_col='study_entry',
    exit_col='study_exit',
    exposure_col='medication',
    reference_value=0
).process()

# Step 2: Integrate events with competing risk
tv_final = TVEvent(
    intervals_data=tv_exposures.data,
    events_data=cohort,
    id_col='person_id',
    date_col='disease_date',
    compete_cols=['death_date'],
    output_col='outcome',
    time_col='years',
    time_unit='years'
).process()

# Ready for survival analysis
print(tv_final)
print(tv_final.data.head())

# Save for later
tv_final.data.to_csv('analysis_dataset.csv', index=False)
```

### Example 2: Recurring Events

```python
# Track hospitalizations (can happen multiple times)
hospitalizations = TVEvent(
    intervals_data=tv_exposures.data,
    events_data='hospitalizations.csv',
    id_col='person_id',
    date_col='admission_date',
    event_type='recurring',
    output_col='hospitalized',
    keep_cols=['diagnosis_code', 'los_days']
).process()

# Count events per person
events_per_person = (
    hospitalizations.data[hospitalizations.data['hospitalized'] > 0]
    .groupby('person_id')
    .size()
)
print(f"Mean hospitalizations: {events_per_person.mean():.2f}")
```

### Example 3: Continuous Dose Adjustment

```python
# Track cumulative medication dose with proper splitting
tv_dose = TVEvent(
    intervals_data=tv_exposures.data,
    events_data=cohort,
    id_col='person_id',
    date_col='outcome_date',
    compete_cols=['death_date', 'emigration_date'],
    continuous_cols=['cumulative_dose'],  # Adjust dose on split
    output_col='status',
    event_labels={
        0: 'Censored',
        1: 'Disease Progression',
        2: 'Death',
        3: 'Loss to Follow-up'
    }
).process()

# Verify dose conservation
print(f"Total dose in output: {tv_dose.data['cumulative_dose'].sum():.2f}")
print(f"Total dose in input: {tv_exposures.data['cumulative_dose'].sum():.2f}")
# Should be equal (or very close due to floating point)
```

### Example 4: Custom Event Labels

```python
tv_labeled = TVEvent(
    intervals_data=intervals_df,
    events_data=events_df,
    id_col='id',
    date_col='primary_outcome',
    compete_cols=['death', 'emigration'],
    event_labels={
        0: 'Alive and in study',
        1: 'Primary outcome occurred',
        2: 'Died before outcome',
        3: 'Emigrated'
    }
).process()

print("Event distribution:")
print(tv_labeled.data['_failure'].value_counts().sort_index())
for code, label in tv_labeled.event_labels.items():
    count = (tv_labeled.data['_failure'] == code).sum()
    print(f"  {code}: {label} (n={count})")
```

### Example 5: Chaining with tvmerge

```python
from tvexpose import TVExpose
from tvmerge import TVMerge
from tvevent import TVEvent

# Step 1: Create exposure dataset A (medication)
cohort = pd.read_csv('cohort.csv')
meds = pd.read_csv('medications.csv')

tv_meds = TVExpose(
    cohort_data=cohort,
    exposure_data=meds,
    id_col='id',
    start_col='rx_start',
    stop_col='rx_stop',
    entry_col='entry_date',
    exit_col='exit_date',
    exposure_col='medication',
    reference_value='None'
).process()

# Step 2: Create exposure dataset B (procedure)
procedures = pd.read_csv('procedures.csv')

tv_proc = TVExpose(
    cohort_data=cohort,
    exposure_data=procedures,
    id_col='id',
    start_col='proc_start',
    stop_col='proc_stop',
    entry_col='entry_date',
    exit_col='exit_date',
    exposure_col='procedure_type',
    reference_value='None'
).process()

# Step 3: Merge the two time-varying datasets
tv_merged = TVMerge(
    datasets=[tv_meds.data, tv_proc.data],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['tv_exposure', 'tv_exposure'],
    output_cols=['medication', 'procedure']
).process()

# Step 4: Integrate events
tv_final = TVEvent(
    intervals_data=tv_merged.data,
    events_data=cohort,
    id_col='id',
    date_col='outcome_date',
    compete_cols=['death_date'],
    time_col='time_years',
    time_unit='years'
).process()

print(f"Final dataset: {len(tv_final.data)} intervals, {tv_final.n_events} events")
```

---

## Performance Considerations

### Optimization Strategies

1. **Use categorical for repetitive string columns**:
   ```python
   # Convert exposure columns to categorical
   for col in exposure_cols:
       if df[col].dtype == 'object':
           df[col] = df[col].astype('category')
   ```

2. **Vectorized operations over loops**:
   - All operations use pandas vectorized methods
   - Avoid Python loops for row-wise operations

3. **Memory efficiency**:
   ```python
   # Use Int64 (nullable int) instead of float for status
   intervals[self.output_col] = intervals['_eff_type'].fillna(0).astype('Int64')

   # Drop intermediate columns as soon as possible
   intervals = intervals.drop(columns=['_temp_col'])
   ```

4. **Efficient merging**:
   - Use `how='inner'` when possible to reduce memory
   - Drop duplicates early to reduce merge size

5. **Chunking for large datasets**:
   ```python
   def process_chunked(self, chunk_size: int = 10000) -> TVEventResult:
       """Process in chunks for large datasets."""
       # Split by person_id into chunks
       # Process each chunk
       # Concatenate results
       # (Implementation detail)
   ```

### Expected Performance

| Dataset Size | Expected Time |
|--------------|---------------|
| 1K intervals, 100 events | < 1 second |
| 10K intervals, 1K events | < 5 seconds |
| 100K intervals, 10K events | < 30 seconds |
| 1M intervals, 100K events | < 5 minutes |

---

## Documentation Requirements

### Docstring Format

Use NumPy style docstrings with:
- One-line summary
- Extended description
- Parameters section with types
- Returns section with type
- Raises section
- Examples section
- Notes section (if applicable)

### User Guide Sections

1. **Installation**
2. **Quick Start**
3. **Core Concepts**:
   - Competing risks
   - Interval splitting
   - Continuous variables
   - Single vs recurring events
4. **API Reference**
5. **Examples Gallery**
6. **FAQ**
7. **Performance Tips**
8. **Migration from Stata**

---

## Package Structure

```
tvevent/
├── tvevent/
│   ├── __init__.py
│   ├── core.py              # TVEvent class
│   ├── exceptions.py        # Custom exceptions
│   ├── utils.py             # Helper functions
│   └── validation.py        # Input validation
├── tests/
│   ├── __init__.py
│   ├── test_tvevent.py
│   ├── test_validation.py
│   ├── test_edge_cases.py
│   └── fixtures/
│       └── test_data.py
├── docs/
│   ├── index.md
│   ├── quickstart.md
│   ├── api.md
│   └── examples.md
├── examples/
│   ├── basic_workflow.py
│   ├── competing_risks.py
│   └── recurring_events.py
├── pyproject.toml
├── README.md
└── LICENSE
```

---

## Implementation Checklist

### Phase 1: Core Functionality
- [ ] Implement `TVEvent.__init__()` with parameter validation
- [ ] Implement `_load_data()` for file/DataFrame loading
- [ ] Implement `_validate_inputs()` for all validation checks
- [ ] Implement `_resolve_competing_risks()` algorithm
- [ ] Implement `_identify_split_points()` algorithm
- [ ] Implement `_execute_splits()` algorithm
- [ ] Write unit tests for Phase 1

### Phase 2: Advanced Features
- [ ] Implement `_adjust_continuous_vars()` algorithm
- [ ] Implement `_merge_event_flags()` algorithm
- [ ] Implement `_apply_type_logic()` (single vs recurring)
- [ ] Implement `_generate_time_variable()` algorithm
- [ ] Implement `_generate_labels()` algorithm
- [ ] Write unit tests for Phase 2

### Phase 3: Polish
- [ ] Implement `TVEventResult` dataclass
- [ ] Implement custom exceptions
- [ ] Add edge case warnings
- [ ] Add comprehensive docstrings
- [ ] Write integration tests
- [ ] Write edge case tests
- [ ] Achieve 90%+ test coverage

### Phase 4: Documentation
- [ ] Write README with installation and quickstart
- [ ] Write API reference documentation
- [ ] Create example notebooks
- [ ] Write user guide
- [ ] Add type stubs (.pyi files)

### Phase 5: Validation
- [ ] Compare results with Stata tvevent on test cases
- [ ] Benchmark performance
- [ ] Stress test with large datasets
- [ ] Create migration guide from Stata

---

## Key Differences from Stata Implementation

| Aspect | Stata | Python |
|--------|-------|--------|
| **Data structure** | Master/using pattern | DataFrames as parameters |
| **Frame handling** | Uses frames for merging | Uses pandas merge |
| **Type system** | Dynamic typing | Type hints with validation |
| **Missing values** | `.` (missing) | `pd.NA` or `np.nan` |
| **Date handling** | Stata date format | `pd.Timestamp` |
| **Error handling** | Error codes + messages | Exceptions with tracebacks |
| **Output** | Modifies in memory | Returns result object |
| **Labels** | Stata value labels | Dict mapping in metadata |

---

## Success Criteria

1. **Correctness**: Results match Stata tvevent on identical inputs (within floating point tolerance)
2. **Robustness**: Handles all edge cases gracefully with clear error messages
3. **Performance**: Processes 100K intervals in < 30 seconds
4. **Usability**: Clear API, comprehensive documentation, helpful error messages
5. **Testability**: 90%+ test coverage, all critical paths covered
6. **Maintainability**: Clean code, type hints, modular design

---

## End of Plan

This plan provides a complete specification for implementing the `tvevent` Stata command in Python. The design emphasizes:
- **Type safety** with comprehensive type hints
- **Robustness** with extensive validation
- **Clarity** with detailed docstrings and examples
- **Testability** with comprehensive test suite
- **Performance** with vectorized pandas operations
- **Usability** with clear error messages and result objects

The implementation should be straightforward for Sonnet to execute by following this plan step-by-step.

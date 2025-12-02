# API Reference

Complete API documentation for tvtools.

## tvtools.TVExpose

```python
class TVExpose(
    exposure_data,
    master_data,
    id_col,
    start_col,
    exposure_col,
    reference,
    entry_col,
    exit_col,
    stop_col=None,
    # Exposure definition
    exposure_type='time_varying',
    duration_cutpoints=None,
    continuous_unit=None,
    expand_unit=None,
    recency_cutpoints=None,
    bytype=False,
    # Data handling
    grace=0,
    merge_days=120,
    pointtime=False,
    fillgaps=0,
    carryforward=0,
    # Overlap handling
    overlap_method='layer',
    priority_order=None,
    combine_col=None,
    # Lag and washout
    lag_days=0,
    washout_days=0,
    window=None,
    # Pattern tracking
    track_switching=False,
    track_switching_detail=False,
    track_state_time=False,
    # Output
    output_col='tv_exposure',
    reference_label='Unexposed',
    keep_cols=None,
    keep_dates=False
)
```

### Parameters

#### Required Parameters

- **exposure_data** : DataFrame, str, or Path
  - Exposure periods dataset with id_col, start_col, exposure_col, stop_col

- **master_data** : DataFrame, str, or Path
  - Cohort dataset with id_col, entry_col, exit_col

- **id_col** : str
  - Person identifier column name (must exist in both datasets)

- **start_col** : str
  - Exposure start date column in exposure_data

- **exposure_col** : str
  - Exposure value column in exposure_data

- **reference** : int
  - Reference/unexposed value in exposure_col

- **entry_col** : str
  - Study entry date column in master_data

- **exit_col** : str
  - Study exit date column in master_data

#### Exposure Definition Parameters

- **stop_col** : str, optional
  - Exposure stop date column. Required unless pointtime=True

- **exposure_type** : {'time_varying', 'ever_treated', 'current_former', 'duration', 'continuous', 'recency'}
  - Type of exposure variable to create. Default: 'time_varying'
  - `'time_varying'`: Standard time-varying exposure
  - `'ever_treated'`: Once exposed, always exposed
  - `'current_former'`: Current vs former vs never
  - `'duration'`: Categories based on cumulative duration
  - `'continuous'`: Continuous cumulative exposure
  - `'recency'`: Time since last exposure

- **duration_cutpoints** : list of float, optional
  - Cutpoints for duration categories. Required if exposure_type='duration'

- **continuous_unit** : {'days', 'weeks', 'months', 'quarters', 'years'}, optional
  - Time unit for continuous/duration calculations

#### Data Handling Parameters

- **grace** : int or dict, default=0
  - Grace period in days to bridge gaps
  - If int: applies to all exposure values
  - If dict: maps exposure values to grace period days

- **merge_days** : int, default=120
  - Maximum days between periods to merge (same exposure type)

- **pointtime** : bool, default=False
  - If True, exposure data are point-in-time (no stop_col needed)

- **fillgaps** : int, default=0
  - Days to extend last exposure period

- **carryforward** : int, default=0
  - Days to carry exposure forward through gaps

#### Overlap Handling Parameters

- **overlap_method** : {'layer', 'priority', 'split', 'combine'}, default='layer'
  - How to handle overlapping exposures
  - `'layer'`: Create separate intervals for each overlap (Cartesian)
  - `'priority'`: Higher priority exposure wins
  - `'split'`: Split overlapping periods
  - `'combine'`: Create combined exposure categories

- **priority_order** : list of int, optional
  - Priority order for overlap_method='priority'

#### Time Adjustment Parameters

- **lag_days** : int, default=0
  - Days before exposure becomes active after start

- **washout_days** : int, default=0
  - Days exposure persists after stop

- **window** : tuple (min_days, max_days), optional
  - Keep only exposures within duration window

#### Pattern Tracking Parameters

- **track_switching** : bool, default=False
  - Create binary indicator for any exposure switching

- **track_switching_detail** : bool, default=False
  - Create detailed switching pattern string

- **track_state_time** : bool, default=False
  - Track cumulative time in current state

#### Output Parameters

- **output_col** : str, default='tv_exposure'
  - Name for output exposure column

- **keep_cols** : list of str, optional
  - Additional columns from master_data to keep

- **keep_dates** : bool, default=False
  - If True, keep entry/exit dates in output

### Methods

#### run()

Execute the time-varying exposure transformation.

**Returns**: TVExposeResult

### TVExposeResult

Result container with the following attributes:

- **data** : DataFrame - Transformed time-varying dataset
- **n_persons** : int - Number of persons
- **n_periods** : int - Number of time-varying intervals
- **total_time** : float - Total person-time (days)
- **exposed_time** : float - Exposed person-time (days)
- **unexposed_time** : float - Unexposed person-time (days)
- **pct_exposed** : float - Percentage of time exposed
- **exposure_type** : ExposureType - Type of exposure created
- **warnings** : list of str - Any warnings generated

---

## tvtools.TVMerge

```python
class TVMerge(
    datasets,
    id_col,
    start_cols,
    stop_cols,
    exposure_cols,
    continuous=None,
    output_names=None,
    prefix=None,
    start_name='start',
    stop_name='stop',
    keep_cols=None,
    batch_pct=20,
    n_jobs=1,
    validate_coverage=False,
    validate_overlap=False,
    check_diagnostics=False,
    summarize=False,
    strict_ids=True
)
```

### Parameters

#### Required Parameters

- **datasets** : list of DataFrame/str/Path
  - List of datasets to merge (minimum 2)

- **id_col** : str
  - Person identifier column (must be in all datasets)

- **start_cols** : list of str
  - Start column names for each dataset (in order)

- **stop_cols** : list of str
  - Stop column names for each dataset (in order)

- **exposure_cols** : list of str
  - Exposure column names for each dataset (in order)

#### Naming Parameters

- **continuous** : list of str/int, optional
  - Exposure names or positions (1-indexed) that are continuous
  - Continuous exposures are prorated for partial overlaps

- **output_names** : list of str, optional
  - New names for exposure columns
  - Mutually exclusive with prefix

- **prefix** : str, optional
  - Prefix to add to all exposure columns
  - Mutually exclusive with output_names

- **start_name** : str, default='start'
  - Name for output start column

- **stop_name** : str, default='stop'
  - Name for output stop column

#### Performance Parameters

- **keep_cols** : list of str, optional
  - Additional columns to keep (will be suffixed with _ds{n})

- **batch_pct** : int, default=20
  - Percentage of IDs to process per batch (1-100)

- **n_jobs** : int, default=1
  - Number of parallel jobs (-1 = all cores)

#### Validation Parameters

- **validate_coverage** : bool, default=False
  - Check for gaps in person-time coverage

- **validate_overlap** : bool, default=False
  - Check for unexpected overlapping periods

- **check_diagnostics** : bool, default=False
  - Display coverage diagnostics

- **summarize** : bool, default=False
  - Display summary statistics

- **strict_ids** : bool, default=True
  - If True, error on ID mismatches. If False, warn and continue

### Methods

#### merge()

Perform the Cartesian merge.

**Returns**: DataFrame - Merged dataset

### MergeMetadata

Metadata about the merge operation:

- **n_observations** : int
- **n_persons** : int
- **mean_periods** : float
- **max_periods** : int
- **n_datasets** : int
- **exposure_vars** : list of str
- **continuous_vars** : list of str
- **categorical_vars** : list of str
- **datasets** : list of str
- **invalid_periods** : dict
- **n_duplicates_dropped** : int

---

## tvtools.TVEvent

```python
class TVEvent(
    intervals_data,
    events_data,
    id_col,
    date_col,
    compete_cols=None,
    event_type='single',
    output_col='_failure',
    continuous_cols=None,
    time_col=None,
    time_unit='days',
    keep_cols=None,
    event_labels=None,
    replace_existing=False
)
```

### Parameters

#### Required Parameters

- **intervals_data** : DataFrame/str/Path
  - Time-varying intervals with 'start' and 'stop' columns

- **events_data** : DataFrame/str/Path
  - Events dataset with id_col and date_col

- **id_col** : str
  - Person identifier (must be in both datasets)

- **date_col** : str
  - Primary event date column in events_data

#### Event Parameters

- **compete_cols** : list of str, optional
  - Competing risk date columns. Earliest event wins
  - Status: 1=primary, 2=first compete, 3=second compete, etc.

- **event_type** : {'single', 'recurring'}, default='single'
  - `'single'`: Terminal event, drops all follow-up after first event
  - `'recurring'`: Multiple events allowed, retains all intervals

#### Output Parameters

- **output_col** : str, default='_failure'
  - Name for event indicator column
  - Values: 0=censored, 1=primary event, 2+=competing events

- **time_col** : str, optional
  - Name for generated duration column (if None, no time column created)

- **time_unit** : {'days', 'months', 'years'}, default='days'
  - Unit for time_col calculation

#### Advanced Parameters

- **continuous_cols** : list of str, optional
  - Columns to adjust proportionally when splitting intervals
  - e.g., cumulative dose variables

- **keep_cols** : list of str, optional
  - Additional columns from events_data to merge

- **event_labels** : dict, optional
  - Custom labels for event status values
  - e.g., {0: 'Censored', 1: 'MI', 2: 'Death'}

- **replace_existing** : bool, default=False
  - If True, overwrites existing output_col and time_col

### Methods

#### process()

Execute the event integration algorithm.

**Returns**: TVEventResult

### TVEventResult

Result container with the following attributes:

- **data** : DataFrame - Processed dataset with event flags
- **n_total** : int - Total observations
- **n_events** : int - Number of events flagged
- **n_splits** : int - Number of intervals split
- **event_labels** : dict - Status code to label mapping
- **output_col** : str - Name of event column
- **time_col** : str - Name of time column (or None)
- **event_type** : str - 'single' or 'recurring'

---

## Enumerations

### ExposureType

```python
from tvtools.tvexpose import ExposureType

ExposureType.TIME_VARYING    # Standard time-varying
ExposureType.EVER_TREATED    # Once exposed, always exposed
ExposureType.CURRENT_FORMER  # Current vs former vs never
ExposureType.DURATION        # Duration categories
ExposureType.CONTINUOUS      # Continuous cumulative
ExposureType.RECENCY         # Time since last exposure
```

### OverlapMethod

```python
from tvtools.tvexpose import OverlapMethod

OverlapMethod.LAYER     # Cartesian intersection
OverlapMethod.PRIORITY  # Priority-based
OverlapMethod.SPLIT     # Split periods
OverlapMethod.COMBINE   # Combined categories
```

### TimeUnit

```python
from tvtools.tvexpose import TimeUnit

TimeUnit.DAYS
TimeUnit.WEEKS
TimeUnit.MONTHS
TimeUnit.QUARTERS
TimeUnit.YEARS
```

---

## Exceptions

### TVExposeError

Base exception for TVExpose module.

### ValidationError

Input validation failure (subclass of TVExposeError).

### TVMergeError

Base exception for TVMerge module.

### IDMismatchError

ID sets don't match across datasets (subclass of TVMergeError).

### InvalidPeriodError

Invalid time periods detected (subclass of TVMergeError).

### TVEventError

Base exception for TVEvent module.

### TVEventValidationError

Input validation failure (subclass of TVEventError).

### TVEventProcessingError

Processing error (subclass of TVEventError).

---

## Utility Functions

### Date Conversion

```python
from tvtools.utils.dates import convert_dates

# Convert all date columns to datetime
df = convert_dates(df, date_cols=['start', 'stop', 'event_date'])
```

### File I/O

```python
from tvtools.utils.io import read_data, write_data

# Read various formats
df = read_data('data.csv')       # CSV
df = read_data('data.dta')       # Stata
df = read_data('data.parquet')   # Parquet

# Write various formats
write_data(df, 'output.csv')
write_data(df, 'output.parquet')
```

---

## See Also

- [TVExpose Guide](tvexpose_guide.md)
- [TVMerge Guide](tvmerge_guide.md)
- [TVEvent Guide](tvevent_guide.md)
- [Examples](../examples/)

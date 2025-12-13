# TVEvent Guide

Complete guide to integrating events and competing risks with TVEvent.

## Overview

TVEvent integrates outcome events and competing risks into time-varying datasets, preparing them for survival analysis.

**Key features**:
- Automatic interval splitting at event boundaries
- Competing risks with earliest-event priority
- Single vs recurring event handling
- Time variable generation
- Continuous variable adjustment

## Quick Example

```python
from tvtools import TVEvent

tv = TVEvent(
    intervals_data=tvexpose_output,  # From TVExpose or TVMerge
    events_data='events.csv',
    id_col='patient_id',
    date_col='mi_date',
    compete_cols=['death_date'],
    time_col='time_years',
    time_unit='years'
)

result = tv.process()
```

## Core Concepts

### 1. Interval Data Structure

TVEvent expects interval data with:
- `id` column: Person identifier
- `start` column: Period start date
- `stop` column: Period stop date
- Exposure columns (from TVExpose/TVMerge)

### 2. Event Data Structure

Events data should have:
- `id` column: Person identifier (matching intervals)
- Primary event date column
- Optional: Competing risk date columns

### 3. Event Status Codes

Output event column uses integer codes:
- **0**: Censored (no event)
- **1**: Primary event
- **2**: First competing event
- **3**: Second competing event
- etc.

## Basic Usage

### Single Event Type

```python
tv = TVEvent(
    intervals_data=intervals,
    events_data=events,
    id_col='id',
    date_col='event_date',
    event_type='single'
)

result = tv.process()
```

### Multiple Competing Risks

```python
tv = TVEvent(
    intervals_data=intervals,
    events_data=events,
    id_col='id',
    date_col='mi_date',           # Primary outcome
    compete_cols=['death_date',   # Competing risk 1
                  'ltfu_date'],    # Competing risk 2
    event_type='single'
)

result = tv.process()
```

## Event Types

### Single Events (Terminal)

Once an event occurs, all follow-up is dropped.

```python
tv = TVEvent(..., event_type='single')
```

**Use cases**:
- Death
- Disease diagnosis
- Study withdrawal
- Any terminal outcome

**Behavior**:
- Keeps only intervals up to first event
- Sets event flag at interval containing event
- Drops all subsequent intervals

### Recurring Events

Events can occur multiple times; all intervals retained.

```python
tv = TVEvent(..., event_type='recurring')
```

**Use cases**:
- Hospitalizations
- Disease relapses
- Clinic visits
- Repeated measurements

**Behavior**:
- Keeps all intervals
- Flags each event occurrence
- Retains follow-up after events

## Competing Risks

### How Competing Risks Work

When multiple event types are specified, the **earliest** event wins:

```python
events = pd.DataFrame({
    'id': [1, 1, 1],
    'mi_date': [datetime(2021, 8, 15), None, datetime(2021, 10, 1)],
    'death_date': [None, datetime(2021, 6, 1), None]
})

tv = TVEvent(
    ...,
    date_col='mi_date',
    compete_cols=['death_date']
)
```

**Result**:
- Person 1: Death on 2021-06-01 (status=2)
- Person 2: MI on 2021-08-15 (status=1)
- Person 3: MI on 2021-10-01 (status=1)

### Custom Event Labels

```python
tv = TVEvent(
    ...,
    event_labels={
        0: 'Censored',
        1: 'MI',
        2: 'Death',
        3: 'Lost to follow-up'
    }
)
```

## Time Variable Generation

### Basic Time Variable

```python
tv = TVEvent(
    ...,
    time_col='duration',
    time_unit='days'
)

result = tv.process()
# result.data has 'duration' column in days
```

### Time Units

- **'days'**: stop - start
- **'months'**: (stop - start) / 30.4375
- **'years'**: (stop - start) / 365.25

### Example

```python
# Generate person-years
tv = TVEvent(
    ...,
    time_col='time',
    time_unit='years'
)

result = tv.process()

# Calculate total person-years
total_py = result.data['time'].sum()
```

## Interval Splitting

### What is Interval Splitting?

When an event occurs in the middle of an exposure interval, TVEvent automatically splits the interval at the event boundary.

**Example**:

```
Original interval:
  Start: 2020-01-01, Stop: 2020-12-31, Exposure: Drug A

Event on 2020-07-15

Split intervals:
  1. Start: 2020-01-01, Stop: 2020-07-15, Exposure: Drug A, Event: 1
  2. Dropped (single event type)
```

For single events, only the first half is kept. For recurring events, both are kept.

### Continuous Variable Adjustment

When intervals are split, continuous variables (e.g., cumulative dose) are adjusted proportionally.

```python
tv = TVEvent(
    ...,
    continuous_cols=['cumulative_dose']
)
```

**Example**:

```
Original interval (365 days):
  cumulative_dose: 3650 mg

Split at day 180:
  Interval 1 (180 days): cumulative_dose = 3650 * (180/365) = 1800 mg
  Interval 2 (185 days): cumulative_dose = 3650 * (185/365) = 1850 mg
```

## Additional Columns

Use `keep_cols` to bring in additional variables from events data:

```python
tv = TVEvent(
    ...,
    keep_cols=['event_location', 'event_severity', 'treatment_at_event']
)

result = tv.process()
# These columns appear only in rows where events occurred
```

## Result Object

```python
result = tv.process()

# Data
result.data            # DataFrame with event flags
result.n_total         # Total intervals
result.n_events        # Number of events flagged
result.n_splits        # Number of intervals split

# Metadata
result.event_labels    # Status code → label mapping
result.output_col      # Name of event column
result.time_col        # Name of time column (or None)
result.event_type      # 'single' or 'recurring'
```

## Best Practices

### 1. Validate Event Dates

Before processing, check that event dates fall within follow-up:

```python
import pandas as pd

# Merge intervals with events
check = intervals.merge(events, on='id')

# Get min/max dates per person
person_dates = intervals.groupby('id').agg({
    'start': 'min',
    'stop': 'max'
})

check = check.merge(person_dates, on='id', suffixes=('_event', '_follow'))

# Check events within follow-up
outside = check[
    (check['event_date'] < check['start_follow']) |
    (check['event_date'] > check['stop_follow'])
]

print(f"Events outside follow-up: {len(outside)}")
```

### 2. Handle Missing Event Dates

Decide how to represent censored observations:

```python
# Option 1: Use NaT (recommended)
events['event_date'] = pd.NaT

# Option 2: Use explicit censoring variable
events['censored'] = 1
events['event_date'] = None
```

### 3. Check Event Counts

Verify events were flagged correctly:

```python
result = tv.process()

# Person-level event counts
person_events = result.data[result.data['event'] > 0].groupby('id')['event'].first()

print(f"Total persons: {result.data['id'].nunique()}")
print(f"Persons with events: {len(person_events)}")

# Event type distribution
print(result.data['event'].value_counts().sort_index())
```

### 4. Validate Splitting

Check that intervals were split correctly:

```python
# Find split intervals (same person, adjacent times)
result_data = result.data.sort_values(['id', 'start'])
result_data['next_start'] = result_data.groupby('id')['start'].shift(-1)

splits = result_data[result_data['stop'] == result_data['next_start']]
print(f"Split intervals: {len(splits)}")
```

## Common Patterns

### Pattern 1: Simple Survival Analysis

```python
# Single event type, generate person-years
tv = TVEvent(
    intervals_data=tv_exposure,
    events_data=events,
    id_col='id',
    date_col='death_date',
    event_type='single',
    time_col='time_years',
    time_unit='years'
)

result = tv.process()

# Ready for Cox regression
# Outcome: event (0/1)
# Time: time_years
# Covariates: exposure columns from intervals
```

### Pattern 2: Competing Risks

```python
# MI with death as competing risk
tv = TVEvent(
    intervals_data=merged_exposures,
    events_data=outcomes,
    id_col='id',
    date_col='mi_date',
    compete_cols=['death_date'],
    event_type='single',
    time_col='time_years',
    time_unit='years',
    event_labels={
        0: 'Censored',
        1: 'MI',
        2: 'Death'
    }
)

result = tv.process()

# Ready for Fine-Gray model
# Outcome: event (0/1/2)
# Time: time_years
```

### Pattern 3: Recurring Events

```python
# Multiple hospitalizations
tv = TVEvent(
    intervals_data=tv_exposure,
    events_data=hospitalizations,  # Multiple rows per person
    id_col='id',
    date_col='hosp_date',
    event_type='recurring',
    time_col='time_days',
    time_unit='days'
)

result = tv.process()

# Can have multiple event=1 rows per person
```

### Pattern 4: Dose Adjustment

```python
# Adjust cumulative dose when splitting
tv = TVEvent(
    intervals_data=dose_intervals,
    events_data=events,
    id_col='id',
    date_col='event_date',
    continuous_cols=['cumulative_dose', 'cumulative_cost'],
    time_col='time_years',
    time_unit='years'
)

result = tv.process()
# cumulative_dose and cumulative_cost prorated for split intervals
```

## Troubleshooting

### No Events Flagged

**Problem**: `result.n_events == 0`

**Checks**:
1. Are event dates within interval ranges?
2. Do IDs match between intervals and events?
3. Are event date columns actually datetime?

```python
# Debug
print("Interval IDs:", intervals['id'].nunique())
print("Event IDs:", events['id'].nunique())
print("Common IDs:", len(set(intervals['id']) & set(events['id'])))

# Check date overlap
print("\nInterval dates:")
print(intervals.groupby('id')[['start', 'stop']].agg(['min', 'max']))

print("\nEvent dates:")
print(events.groupby('id')['event_date'].agg(['min', 'max']))
```

### Too Many Events

**Problem**: More events flagged than expected

**Possible causes**:
- Using `event_type='recurring'` when should be 'single'
- Event data has duplicate rows
- Multiple events on same date

```python
# Check for duplicate events
duplicates = events.groupby(['id', 'event_date']).size()
print(duplicates[duplicates > 1])
```

### Unexpected Competing Risk Priority

**Problem**: Wrong event type taking precedence

**Cause**: Competing risk date is earlier than primary

```python
# Check which event is earliest
check = events.copy()
check['earliest'] = check[['mi_date', 'death_date']].min(axis=1)
check['winner'] = check[['mi_date', 'death_date']].idxmin(axis=1)

print(check[['mi_date', 'death_date', 'earliest', 'winner']])
```

## Complete Example

```python
from tvtools import TVExpose, TVEvent
import pandas as pd
from datetime import datetime

# 1. Create time-varying exposures
tv_exp = TVExpose(
    exposure_data=prescriptions,
    master_data=cohort,
    id_col='id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug',
    reference=0,
    entry_col='entry',
    exit_col='exit'
).run()

# 2. Prepare events with competing risks
events = pd.DataFrame({
    'id': [1, 2, 3],
    'mi_date': [datetime(2021, 6, 15), None, datetime(2021, 10, 1)],
    'death_date': [None, datetime(2021, 3, 1), None]
})

# 3. Integrate events
final = TVEvent(
    intervals_data=tv_exp.data,
    events_data=events,
    id_col='id',
    date_col='mi_date',
    compete_cols=['death_date'],
    event_type='single',
    time_col='time_years',
    time_unit='years',
    event_labels={
        0: 'Censored',
        1: 'MI',
        2: 'Death'
    }
).process()

# 4. Analyze
print(f"Total person-years: {final.data['time_years'].sum():.1f}")
print("\nEvent distribution:")
for status, label in final.event_labels.items():
    count = (final.data['event'] == status).sum()
    print(f"  {label}: {count}")

# 5. Prepare for analysis
print("\nReady for survival analysis:")
print(final.data[['id', 'start', 'stop', 'drug', 'event', 'time_years']].head())
```

## See Also

- [API Reference](api.md)
- [Examples](../examples/competing_risks_example.py)
- [TVExpose Guide](tvexpose_guide.md)
- [TVMerge Guide](tvmerge_guide.md)

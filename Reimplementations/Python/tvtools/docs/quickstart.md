# Quick Start Guide

This guide will get you started with tvtools in 5 minutes.

## Installation

```bash
pip install tvtools
```

## The Basics

tvtools has three main classes that work together:

1. **TVExpose** - Convert exposure periods → time-varying intervals
2. **TVMerge** - Merge multiple time-varying datasets → combined intervals
3. **TVEvent** - Add outcomes → analysis-ready dataset

## Your First Time-Varying Dataset

### Step 1: Prepare Your Data

You need two datasets:

**Cohort data** (one row per person):
```python
import pandas as pd
from datetime import datetime

cohort = pd.DataFrame({
    'patient_id': [1, 2, 3],
    'entry_date': [datetime(2020, 1, 1)] * 3,
    'exit_date': [datetime(2022, 12, 31)] * 3,
    'age': [55, 62, 58],
    'sex': ['F', 'M', 'F']
})
```

**Exposure data** (multiple rows per person):
```python
prescriptions = pd.DataFrame({
    'patient_id': [1, 1, 1, 2, 2, 3],
    'rx_start': [
        datetime(2020, 1, 15),
        datetime(2020, 8, 1),
        datetime(2021, 3, 1),
        datetime(2020, 6, 1),
        datetime(2021, 1, 1),
        datetime(2020, 3, 15)
    ],
    'rx_stop': [
        datetime(2020, 6, 30),
        datetime(2021, 1, 31),
        datetime(2022, 11, 30),
        datetime(2020, 11, 30),
        datetime(2022, 10, 31),
        datetime(2022, 2, 28)
    ],
    'drug_type': [1, 1, 2, 1, 1, 2]
})
```

### Step 2: Create Time-Varying Intervals

```python
from tvtools import TVExpose

tv = TVExpose(
    exposure_data=prescriptions,
    master_data=cohort,
    id_col='patient_id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug_type',
    reference=0,  # 0 = unexposed
    entry_col='entry_date',
    exit_col='exit_date'
)

result = tv.run()
```

### Step 3: Examine Results

```python
# View the data
print(result.data.head())

# Summary statistics
print(f"Persons: {result.n_persons}")
print(f"Intervals: {result.n_periods}")
print(f"Exposed time: {result.pct_exposed:.1f}%")
```

Output:
```
   patient_id  exp_start   exp_stop  tv_exposure
0           1 2020-01-01 2020-01-14            0
1           1 2020-01-15 2020-06-30            1
2           1 2020-07-01 2020-07-31            0
3           1 2020-08-01 2021-01-31            1
4           1 2021-02-01 2021-02-28            0
...
```

## Common Patterns

### Pattern 1: Grace Period

Bridge small gaps between exposure periods:

```python
tv = TVExpose(
    exposure_data=prescriptions,
    master_data=cohort,
    id_col='patient_id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug_type',
    reference=0,
    entry_col='entry_date',
    exit_col='exit_date',
    grace=30  # Bridge gaps <= 30 days
)
```

### Pattern 2: Ever-Treated

Once exposed, always exposed (intention-to-treat):

```python
tv = TVExpose(
    exposure_data=prescriptions,
    master_data=cohort,
    id_col='patient_id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug_type',
    reference=0,
    entry_col='entry_date',
    exit_col='exit_date',
    exposure_type='ever_treated'  # Key difference!
)
```

### Pattern 3: Merge Multiple Exposures

Combine two time-varying datasets:

```python
from tvtools import TVMerge

# Assuming you have tv_hrt and tv_statin from TVExpose

merger = TVMerge(
    datasets=[tv_hrt.data, tv_statin.data],
    id_col='patient_id',
    start_cols=['exp_start', 'exp_start'],
    stop_cols=['exp_stop', 'exp_stop'],
    exposure_cols=['hrt_type', 'statin_dose'],
    output_names=['hrt', 'statin']
)

merged = merger.merge()
```

### Pattern 4: Add Events

Integrate outcome events:

```python
from tvtools import TVEvent

# Events data
events = pd.DataFrame({
    'patient_id': [1, 2],
    'mi_date': [datetime(2021, 6, 15), datetime(2021, 9, 20)],
    'death_date': [None, None]
})

tv_event = TVEvent(
    intervals_data=merged,
    events_data=events,
    id_col='patient_id',
    date_col='mi_date',
    compete_cols=['death_date'],
    time_col='time_years',
    time_unit='years'
)

final = tv_event.process()
```

## Complete Minimal Example

Here's a complete working example from start to finish:

```python
import pandas as pd
from datetime import datetime
from tvtools import TVExpose, TVEvent

# 1. Create sample data
cohort = pd.DataFrame({
    'id': [1, 2, 3],
    'entry': [datetime(2020, 1, 1)] * 3,
    'exit': [datetime(2022, 12, 31)] * 3
})

prescriptions = pd.DataFrame({
    'id': [1, 1, 2, 3],
    'start': [
        datetime(2020, 3, 1),
        datetime(2021, 1, 1),
        datetime(2020, 6, 1),
        datetime(2020, 2, 1)
    ],
    'stop': [
        datetime(2020, 8, 31),
        datetime(2022, 10, 31),
        datetime(2021, 5, 31),
        datetime(2022, 11, 30)
    ],
    'drug': [1, 1, 1, 2]
})

events = pd.DataFrame({
    'id': [1, 2],
    'event_date': [datetime(2021, 6, 1), datetime(2021, 8, 15)],
    'death_date': [None, None]
})

# 2. Create time-varying exposure
tv = TVExpose(
    exposure_data=prescriptions,
    master_data=cohort,
    id_col='id',
    start_col='start',
    stop_col='stop',
    exposure_col='drug',
    reference=0,
    entry_col='entry',
    exit_col='exit'
).run()

# 3. Integrate events
final = TVEvent(
    intervals_data=tv.data,
    events_data=events,
    id_col='id',
    date_col='event_date',
    compete_cols=['death_date'],
    time_col='time_years',
    time_unit='years'
).process()

# 4. Ready for analysis!
print(final.data.head(10))
```

## Data Requirements

### For TVExpose

**Master data** must have:
- Person ID column
- Study entry date
- Study exit date

**Exposure data** must have:
- Person ID column (matching master)
- Exposure start date
- Exposure stop date (or use `pointtime=True`)
- Exposure value column

### For TVMerge

All datasets must have:
- Person ID column (same name or specify)
- Start date column
- Stop date column
- Exposure value column(s)

### For TVEvent

**Intervals data** must have:
- Person ID column
- `start` column
- `stop` column

**Events data** must have:
- Person ID column (matching intervals)
- Event date column
- Optional: Competing risk date columns

## Common Issues

### Issue 1: Dates Not Datetime

**Error**: `TypeError: '<' not supported between instances of 'str' and 'datetime'`

**Solution**: Convert date columns to datetime:
```python
df['date_col'] = pd.to_datetime(df['date_col'])
```

### Issue 2: No Intervals Created

**Problem**: `result.n_periods = 0`

**Check**:
1. Do exposure dates fall within study entry/exit dates?
2. Are exposure start dates <= stop dates?
3. Are there any exposures for the specified persons?

### Issue 3: Column Not Found

**Error**: `KeyError: 'column_name'`

**Solution**: Check column names match exactly:
```python
print(df.columns.tolist())
```

## Next Steps

- Read the [TVExpose Guide](tvexpose_guide.md) for detailed exposure options
- Read the [TVMerge Guide](tvmerge_guide.md) for merging strategies
- Read the [TVEvent Guide](tvevent_guide.md) for event handling
- See [Examples](../examples/) for complete working examples
- Check the [API Reference](api.md) for all parameters

## Getting Help

- Check the [full documentation](index.md)
- Look at [example scripts](../examples/)
- Open an [issue on GitHub](https://github.com/tpcopeland/Stata-Tools/issues)

## Summary

The basic workflow is:

1. **TVExpose**: exposure periods → time-varying intervals
2. **TVMerge**: multiple TV datasets → combined intervals (optional)
3. **TVEvent**: + events → analysis-ready data
4. **Analyze**: Cox models, competing risks, etc.

That's it! You're ready to start using tvtools.

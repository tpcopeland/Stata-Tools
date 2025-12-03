# TVExpose Guide

Comprehensive guide to creating time-varying exposure variables with TVExpose.

## Table of Contents

1. [Overview](#overview)
2. [Basic Usage](#basic-usage)
3. [Exposure Types](#exposure-types)
4. [Data Handling](#data-handling)
5. [Overlap Resolution](#overlap-resolution)
6. [Time Adjustments](#time-adjustments)
7. [Pattern Tracking](#pattern-tracking)
8. [Best Practices](#best-practices)

## Overview

TVExpose transforms period-based exposure data (prescriptions, treatments, interventions) into time-varying exposure intervals suitable for survival analysis.

**Input**: Exposure periods + cohort data
**Output**: Time-varying intervals where exposure is constant

## Basic Usage

Minimal example:

```python
from tvtools import TVExpose

tv = TVExpose(
    exposure_data='prescriptions.csv',  # Exposure periods
    master_data='cohort.csv',           # Cohort info
    id_col='patient_id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug_type',
    reference=0,  # Unexposed value
    entry_col='study_entry',
    exit_col='study_exit'
)

result = tv.run()
```

## Exposure Types

### 1. Time-Varying (Standard)

Standard time-varying exposure that can turn on and off.

```python
tv = TVExpose(..., exposure_type='time_varying')
```

**Timeline**:
```
|--0--|==1==|--0--|==2==|--0--|
```

### 2. Ever-Treated

Once exposed, always exposed (intention-to-treat).

```python
tv = TVExpose(..., exposure_type='ever_treated')
```

**Timeline**:
```
|--0--|========1========|
      ↑ first exposure
```

**Use cases**:
- Intention-to-treat analyses
- New-user designs
- Irreversible exposures

### 3. Current vs Former

Distinguishes current, former, and never exposed.

```python
tv = TVExpose(..., exposure_type='current_former')
```

**Output**:
- 0 = Never exposed
- 1 = Currently exposed
- 2 = Formerly exposed

**Timeline**:
```
|--0--|==1==|--2--|==1==|--2--|
```

### 4. Duration Categories

Categorize by cumulative exposure duration.

```python
tv = TVExpose(
    ...,
    exposure_type='duration',
    duration_cutpoints=[30, 90, 180],
    continuous_unit='days'
)
```

**Categories created**:
- 0 = Unexposed
- 1 = <30 days
- 2 = 30-<90 days
- 3 = 90-<180 days
- 4 = ≥180 days

### 5. Continuous Exposure

Cumulative exposure as continuous variable.

```python
tv = TVExpose(
    ...,
    exposure_type='continuous',
    continuous_unit='days'
)
```

**Output**: Cumulative days of exposure at each interval.

## Data Handling

### Grace Periods

Bridge small gaps between exposure periods.

```python
# Grace period for all exposures
tv = TVExpose(..., grace=30)  # Bridge gaps ≤30 days

# Exposure-specific grace periods
tv = TVExpose(..., grace={1: 30, 2: 60})  # 30 days for drug 1, 60 for drug 2
```

**Example**:
```
Without grace:
|==exposure==|  gap  |==exposure==|  gap  |

With grace=30 (gap ≤30 days):
|===========exposure===========|  gap  |
```

### Merge Consecutive Periods

Merge same-type periods within a time window.

```python
tv = TVExpose(..., merge_days=120)
```

Merges periods of the same exposure type if they occur within 120 days.

### Point-in-Time Data

For instantaneous exposures (no duration).

```python
tv = TVExpose(
    ...,
    pointtime=True,  # No stop_col needed
    start_col='exposure_date'
)
```

## Overlap Resolution

When exposure periods overlap, TVExpose provides several resolution strategies.

### Layer Method (Default)

Creates separate intervals for each combination.

```python
tv = TVExpose(..., overlap_method='layer')
```

**Example**:
```
Drug A:  |=====A=====|
Drug B:      |====B====|

Result:
|--A--|--A+B--|--B--|
```

### Priority Method

Higher priority exposure wins during overlaps.

```python
tv = TVExpose(
    ...,
    overlap_method='priority',
    priority_order=[2, 1, 0]  # Drug 2 > Drug 1 > Unexposed
)
```

### Split Method

Split overlapping periods into separate rows.

```python
tv = TVExpose(..., overlap_method='split')
```

### Combine Method

Create combined exposure categories.

```python
tv = TVExpose(
    ...,
    overlap_method='combine',
    combine_col='combined_exposure'
)
```

## Time Adjustments

### Lag Period

Delay exposure activation after start date.

```python
tv = TVExpose(..., lag_days=14)
```

**Example**:
```
Rx start:    |==prescription==|
With lag=14: ....|==active==|
```

**Use case**: Drugs with delayed onset of action.

### Washout Period

Extend exposure beyond stop date.

```python
tv = TVExpose(..., washout_days=30)
```

**Example**:
```
Rx stop:         |==prescription==|
With washout=30: |==prescription==|====...|
```

**Use case**: Drugs with lingering effects.

### Exposure Window

Keep only exposures within a duration range.

```python
tv = TVExpose(
    ...,
    window=(30, 180)  # Keep exposures 30-180 days long
)
```

**Use case**: Focus on specific treatment durations.

## Pattern Tracking

### Switching Indicator

Binary flag for any exposure switching.

```python
tv = TVExpose(..., track_switching=True)
```

**Output**: Column `switching` (0/1) indicating if person ever switched.

### Detailed Switching Pattern

String showing full switching sequence.

```python
tv = TVExpose(..., track_switching_detail=True)
```

**Output**: Column `switching_pattern` like "0→1→2→1".

### State Duration

Cumulative time in current exposure state.

```python
tv = TVExpose(..., track_state_time=True)
```

**Output**: Column `state_time` with days in current state.

## Output Structure

Result contains:

```python
result = tv.run()

# Data
result.data            # DataFrame with intervals
result.n_persons       # Number of persons
result.n_periods       # Number of intervals

# Summary stats
result.total_time      # Total person-days
result.exposed_time    # Exposed person-days
result.pct_exposed     # Percentage exposed

# Metadata
result.exposure_type   # Type of exposure
result.warnings        # Any warnings
```

## Best Practices

### 1. Check Your Data First

```python
# Verify date ranges
print(cohort[['entry_date', 'exit_date']].describe())
print(prescriptions[['rx_start', 'rx_stop']].describe())

# Check for missing values
print(prescriptions.isna().sum())

# Verify IDs match
cohort_ids = set(cohort['id'])
rx_ids = set(prescriptions['id'])
print(f"IDs only in cohort: {len(cohort_ids - rx_ids)}")
print(f"IDs only in prescriptions: {len(rx_ids - cohort_ids)}")
```

### 2. Start Simple

Begin with basic time-varying exposure, then add complexity:

```python
# Step 1: Basic
tv_basic = TVExpose(..., exposure_type='time_varying')

# Step 2: Add grace period
tv_grace = TVExpose(..., grace=30)

# Step 3: Add pattern tracking
tv_full = TVExpose(..., grace=30, track_switching=True)
```

### 3. Choose Appropriate Grace Period

- **No grace** (0): Strict on/off exposure
- **Short grace** (7-14 days): Refill delays
- **Medium grace** (30 days): Standard prescription gaps
- **Long grace** (60-90 days): Extended supply periods

### 4. Validate Results

```python
result = tv.run()

# Check interval counts
print(f"Intervals per person: {result.n_periods / result.n_persons:.1f}")

# Check exposure distribution
print(result.data['tv_exposure'].value_counts())

# Examine specific person
person_1 = result.data[result.data['patient_id'] == 1]
print(person_1)
```

### 5. Handle Warnings

```python
if result.warnings:
    for warning in result.warnings:
        print(f"Warning: {warning}")
```

## Common Patterns

### Pattern 1: New-User Design

```python
# Ever-treated with grace period
tv = TVExpose(
    ...,
    exposure_type='ever_treated',
    grace=30
)
```

### Pattern 2: As-Treated Analysis

```python
# Time-varying with washout
tv = TVExpose(
    ...,
    exposure_type='time_varying',
    washout_days=30
)
```

### Pattern 3: Cumulative Exposure

```python
# Duration categories
tv = TVExpose(
    ...,
    exposure_type='duration',
    duration_cutpoints=[30, 90, 180],
    continuous_unit='days'
)
```

### Pattern 4: Treatment Switching

```python
# Track switching patterns
tv = TVExpose(
    ...,
    track_switching=True,
    track_switching_detail=True
)
```

## Troubleshooting

### No Intervals Created

**Problem**: `result.n_periods == 0`

**Checks**:
1. Exposure dates within study entry/exit?
2. start_col ≤ stop_col?
3. ID column names match?

### Too Many Intervals

**Problem**: Thousands of tiny intervals

**Solutions**:
1. Increase `grace` to bridge gaps
2. Increase `merge_days` to merge nearby periods
3. Use `exposure_type='ever_treated'`

### Overlaps Not Resolving

**Problem**: Unexpected overlap behavior

**Solution**: Check `overlap_method` setting:
- Use `'layer'` for separate intervals
- Use `'priority'` with `priority_order`

## See Also

- [API Reference](api.md)
- [Examples](../examples/)
- [TVMerge Guide](tvmerge_guide.md)
- [Migration from Stata](migration_from_stata.md)

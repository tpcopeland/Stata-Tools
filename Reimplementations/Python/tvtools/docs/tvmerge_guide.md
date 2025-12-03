# TVMerge Guide

Complete guide to merging multiple time-varying exposure datasets with TVMerge.

## Overview

TVMerge implements a Cartesian merge algorithm that creates all possible combinations of overlapping time intervals across multiple datasets. This is fundamentally different from standard merges.

**Standard merge**: Matches on exact keys
**TVMerge**: Matches on time interval overlaps and creates intersection intervals

## Quick Example

```python
from tvtools import TVMerge

merger = TVMerge(
    datasets=['tv_hrt.csv', 'tv_statin.csv'],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['hrt_type', 'statin_dose'],
    output_names=['hrt', 'statin']
)

result = merger.merge()
```

## The Cartesian Merge Algorithm

### How It Works

Given two time-varying datasets:

**Dataset A (HRT)**:
```
ID  Start      Stop       HRT
1   2020-01-01 2020-06-30  1
1   2020-09-01 2020-12-31  1
```

**Dataset B (Statin)**:
```
ID  Start      Stop       Statin
1   2020-03-01 2020-10-31  20
```

**Merged Result**:
```
ID  Start      Stop       HRT  Statin
1   2020-01-01 2020-02-29  1    0      # HRT only
1   2020-03-01 2020-06-30  1   20      # HRT + Statin overlap
1   2020-07-01 2020-08-31  0   20      # Statin only
1   2020-09-01 2020-10-31  1   20      # HRT + Statin overlap
1   2020-11-01 2020-12-31  1    0      # HRT only
```

Each row represents a unique combination of exposures over a specific time period.

## Basic Usage

### Two Datasets

```python
merger = TVMerge(
    datasets=[df1, df2],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['exposure_a', 'exposure_b'],
    output_names=['exp_a', 'exp_b']
)

result = merger.merge()
```

### Three or More Datasets

```python
merger = TVMerge(
    datasets=[df1, df2, df3],
    id_col='id',
    start_cols=['start_a', 'start_b', 'start_c'],
    stop_cols=['stop_a', 'stop_b', 'stop_c'],
    exposure_cols=['exp_a', 'exp_b', 'exp_c'],
    output_names=['a', 'b', 'c']
)

result = merger.merge()
```

The algorithm merges iteratively: first df1+df2, then result+df3, etc.

## Continuous Exposures

### What are Continuous Exposures?

Continuous exposures represent **rates per day** (e.g., mg/day, dose/day) rather than categorical states.

**Problem**: When intervals overlap partially, you can't just copy the rate value - you need to prorate it based on the overlap duration.

### Specifying Continuous Exposures

```python
merger = TVMerge(
    datasets=[df1, df2],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['treatment_type', 'daily_dose'],
    output_names=['treatment', 'dose'],
    continuous=['dose']  # or continuous=[2] for position
)

result = merger.merge()
```

### How Proration Works

**Example**:

Original interval in dose dataset:
```
Start: 2020-01-01, Stop: 2020-01-31 (30 days)
Daily dose: 20 mg/day
Total for period: 600 mg
```

After merge, interval split into:
```
1. Start: 2020-01-01, Stop: 2020-01-15 (15 days)
   Daily dose: 20 mg/day (unchanged)
   Total for period: 300 mg (prorated: 15/30 * 600)

2. Start: 2020-01-16, Stop: 2020-01-31 (15 days)
   Daily dose: 20 mg/day (unchanged)
   Total for period: 300 mg (prorated: 15/30 * 600)
```

### Output Columns for Continuous Exposures

For each continuous exposure `exp`, two columns are created:

1. **exp**: The rate per day (unchanged from original)
2. **exp_period**: The total amount for this specific interval (prorated)

```python
result.columns
# ['id', 'start', 'stop', 'treatment', 'dose', 'dose_period']
```

**Use cases for _period columns**:
- Calculate total cumulative exposure per person
- Analyze exposure gradients
- Adjust for partial exposure periods

## Naming Options

### Option 1: output_names (Recommended)

Explicitly name each exposure column.

```python
merger = TVMerge(
    ...,
    exposure_cols=['hrt_type', 'statin_dose'],
    output_names=['hrt', 'statin']
)
```

### Option 2: prefix

Add a prefix to original names.

```python
merger = TVMerge(
    ...,
    exposure_cols=['hrt_type', 'statin_dose'],
    prefix='tv_'
)
# Output columns: tv_hrt_type, tv_statin_dose
```

### Option 3: Neither (Not Recommended)

Uses original exposure column names (can cause conflicts).

## Additional Columns

Use `keep_cols` to preserve additional variables:

```python
merger = TVMerge(
    ...,
    keep_cols=['baseline_risk', 'comorbidity_score']
)

result.columns
# Includes: baseline_risk_ds1, baseline_risk_ds2, comorbidity_score_ds1, ...
```

Columns are suffixed with `_ds{n}` where n is the dataset number.

## Performance Options

### Batch Processing

Process IDs in batches to control memory usage.

```python
merger = TVMerge(
    ...,
    batch_pct=50  # Process 50% of IDs per batch
)
```

- **Small batch_pct** (10-20): Lower memory, slower
- **Large batch_pct** (50-100): Higher memory, faster

### Parallel Processing

Use multiple CPU cores.

```python
merger = TVMerge(
    ...,
    n_jobs=-1  # Use all available cores
)
```

**Note**: Requires `joblib` package.

## Validation Options

### Coverage Validation

Check for gaps in person-time.

```python
merger = TVMerge(
    ...,
    validate_coverage=True
)

result = merger.merge()
# Prints: "Found 5 gaps >1 day in coverage"
```

### Overlap Validation

Check for unexpected overlapping periods (same person, overlapping times, same exposure).

```python
merger = TVMerge(
    ...,
    validate_overlap=True
)
```

### Diagnostics

Display merge statistics.

```python
merger = TVMerge(
    ...,
    check_diagnostics=True,
    summarize=True
)

result = merger.merge()
# Prints detailed statistics
```

## ID Matching

### Strict Mode (Default)

Error if IDs don't match across all datasets.

```python
merger = TVMerge(
    ...,
    strict_ids=True  # Raises IDMismatchError
)
```

### Permissive Mode

Warn and continue with common IDs only.

```python
merger = TVMerge(
    ...,
    strict_ids=False  # Warns and drops mismatched IDs
)
```

## Metadata

After merging, access metadata:

```python
result = merger.merge()
metadata = merger.metadata

print(f"Persons: {metadata.n_persons}")
print(f"Intervals: {metadata.n_observations}")
print(f"Mean intervals per person: {metadata.mean_periods:.1f}")
print(f"Continuous vars: {metadata.continuous_vars}")
print(f"Categorical vars: {metadata.categorical_vars}")
```

## Best Practices

### 1. Verify ID Matching First

```python
# Check IDs before merging
ids1 = set(df1['id'])
ids2 = set(df2['id'])

print(f"Common IDs: {len(ids1 & ids2)}")
print(f"Only in df1: {len(ids1 - ids2)}")
print(f"Only in df2: {len(ids2 - ids1)}")
```

### 2. Standardize Column Names

Before merging, ensure consistent naming:

```python
df1 = df1.rename(columns={'study_start': 'start', 'study_stop': 'stop'})
df2 = df2.rename(columns={'rx_start': 'start', 'rx_stop': 'stop'})
```

### 3. Handle Missing Exposures

Decide how to code "no exposure":
- **Categorical**: Use 0 or -1
- **Continuous**: Use 0 (not NaN)

### 4. Start with Small Sample

Test with a subset first:

```python
# Test with 10% of IDs
sample_ids = df1['id'].drop_duplicates().sample(frac=0.1)
df1_test = df1[df1['id'].isin(sample_ids)]
df2_test = df2[df2['id'].isin(sample_ids)]

merger = TVMerge(datasets=[df1_test, df2_test], ...)
```

### 5. Monitor Memory Usage

For large datasets:

```python
merger = TVMerge(
    ...,
    batch_pct=20,  # Process in smaller batches
    n_jobs=4       # Use 4 cores (not all)
)
```

## Common Patterns

### Pattern 1: Merge Two Categorical Exposures

```python
merger = TVMerge(
    datasets=[tv_drug1, tv_drug2],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['drug1_type', 'drug2_type'],
    output_names=['drug1', 'drug2']
)
```

### Pattern 2: Merge Categorical + Continuous

```python
merger = TVMerge(
    datasets=[tv_treatment, tv_dose],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['treatment_type', 'daily_dose'],
    output_names=['treatment', 'dose'],
    continuous=['dose']  # Prorate dose
)
```

### Pattern 3: Merge Multiple Continuous

```python
merger = TVMerge(
    datasets=[tv_drug1_dose, tv_drug2_dose, tv_drug3_dose],
    id_col='id',
    start_cols=['start', 'start', 'start'],
    stop_cols=['stop', 'stop', 'stop'],
    exposure_cols=['dose1', 'dose2', 'dose3'],
    continuous=['dose1', 'dose2', 'dose3']  # All continuous
)
```

## Troubleshooting

### Memory Error

**Problem**: `MemoryError` during merge

**Solutions**:
1. Reduce `batch_pct`: `batch_pct=10`
2. Reduce `n_jobs`: `n_jobs=1`
3. Filter to smaller date range
4. Process subsets of persons separately

### Too Many Intervals

**Problem**: Result has millions of tiny intervals

**Causes**:
- Many small gaps creating separate intervals
- High granularity in source data

**Solutions**:
1. Use TVExpose with `grace` parameter first
2. Merge nearby periods before TVMerge
3. Consider coarsening time granularity

### ID Mismatch Error

**Problem**: `IDMismatchError: IDs don't match`

**Solutions**:
```python
# Option 1: Fix source data to include all IDs

# Option 2: Use permissive mode
merger = TVMerge(..., strict_ids=False)

# Option 3: Filter to common IDs before merging
common_ids = set(df1['id']) & set(df2['id'])
df1 = df1[df1['id'].isin(common_ids)]
df2 = df2[df2['id'].isin(common_ids)]
```

## Example Workflow

Complete example with validation:

```python
from tvtools import TVMerge
import pandas as pd

# 1. Load data
hrt = pd.read_csv('tv_hrt.csv')
statin = pd.read_csv('tv_statin.csv')

# 2. Check data
print("HRT shape:", hrt.shape)
print("Statin shape:", statin.shape)
print("Common IDs:", len(set(hrt['id']) & set(statin['id'])))

# 3. Merge
merger = TVMerge(
    datasets=[hrt, statin],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['hrt_type', 'statin_mg'],
    output_names=['hrt', 'statin'],
    continuous=['statin'],
    check_diagnostics=True,
    validate_coverage=True,
    batch_pct=30
)

result = merger.merge()

# 4. Validate result
print("\nResult shape:", result.shape)
print("Columns:", result.columns.tolist())
print("\nFirst person trajectory:")
print(result[result['id'] == result['id'].iloc[0]])

# 5. Save
result.to_csv('merged_exposures.csv', index=False)
```

## See Also

- [API Reference](api.md)
- [TVExpose Guide](tvexpose_guide.md)
- [Examples](../examples/continuous_exposure_example.py)

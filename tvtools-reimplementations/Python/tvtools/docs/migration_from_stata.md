# Migration from Stata tvtools

Guide for users transitioning from the Stata version of tvtools to Python.

## Quick Reference

| Stata Command | Python Equivalent |
|--------------|-------------------|
| `tvexpose using exposure, master(cohort) ...` | `TVExpose(exposure_data='exposure.dta', master_data='cohort.dta', ...)` |
| `tvmerge using dataset2, ...` | `TVMerge(datasets=[df1, 'dataset2.csv'], ...)` |
| `tvevent using events, ...` | `TVEvent(intervals_data=df, events_data='events.dta', ...)` |

## Key Differences

### 1. Object-Oriented vs Procedural

**Stata (procedural)**:
```stata
use cohort, clear
tvexpose using prescriptions, id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) entry(entry_date) exit(exit_date)
```

**Python (object-oriented)**:
```python
tv = TVExpose(
    exposure_data='prescriptions.csv',
    master_data='cohort.csv',
    id_col='id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug',
    reference=0,
    entry_col='entry_date',
    exit_col='exit_date'
)
result = tv.run()
data = result.data
```

### 2. File Handling

**Stata**: Operates on data in memory, uses `using` for files

**Python**: Can work with DataFrames or file paths

```python
# From file
tv = TVExpose(exposure_data='file.csv', ...)

# From DataFrame
import pandas as pd
df = pd.read_stata('file.dta')
tv = TVExpose(exposure_data=df, ...)
```

### 3. Option Syntax

**Stata**: Options in parentheses, abbreviated names

```stata
grace(30) carryf(60) mergeper(120)
```

**Python**: Named parameters, full names

```python
grace=30, carryforward=60, merge_days=120
```

## TVExpose Migration

### Basic Call

**Stata**:
```stata
tvexpose using prescriptions, ///
    master(cohort) ///
    id(patient_id) ///
    start(rx_start) ///
    stop(rx_stop) ///
    exposure(drug_type) ///
    reference(0) ///
    entry(study_entry) ///
    exit(study_exit)
```

**Python**:
```python
from tvtools import TVExpose

tv = TVExpose(
    exposure_data='prescriptions.dta',
    master_data='cohort.dta',
    id_col='patient_id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug_type',
    reference=0,
    entry_col='study_entry',
    exit_col='study_exit'
)
result = tv.run()
```

### Common Options

| Stata Option | Python Parameter | Notes |
|-------------|------------------|-------|
| `grace(30)` | `grace=30` | Same |
| `mergeper(120)` | `merge_days=120` | Renamed |
| `carryf(60)` | `carryforward=60` | Full name |
| `lag(14)` | `lag_days=14` | Explicit unit |
| `washout(30)` | `washout_days=30` | Explicit unit |
| `generate(tv_exp)` | `output_col='tv_exp'` | Renamed |
| `keepvars(age sex)` | `keep_cols=['age', 'sex']` | List syntax |
| `keeptimes` | `keep_dates=True` | Boolean flag |

### Exposure Types

**Stata**:
```stata
* Ever-treated
tvexpose ..., evertreated

* Current/former
tvexpose ..., currformer

* Duration categories
tvexpose ..., duration(30 90 180) unit(days)
```

**Python**:
```python
# Ever-treated
tv = TVExpose(..., exposure_type='ever_treated')

# Current/former
tv = TVExpose(..., exposure_type='current_former')

# Duration categories
tv = TVExpose(
    ...,
    exposure_type='duration',
    duration_cutpoints=[30, 90, 180],
    continuous_unit='days'
)
```

### Grace Period by Type

**Stata**:
```stata
tvexpose ..., grace(1=30 2=60)
```

**Python**:
```python
tv = TVExpose(..., grace={1: 30, 2: 60})
```

## TVMerge Migration

### Basic Merge

**Stata**:
```stata
use tv_hrt, clear
tvmerge using tv_statin, ///
    id(id) ///
    generate(hrt statin)
```

**Python**:
```python
from tvtools import TVMerge

merger = TVMerge(
    datasets=['tv_hrt.dta', 'tv_statin.dta'],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['tv_exposure', 'tv_exposure'],
    output_names=['hrt', 'statin']
)
result = merger.merge()
```

### Continuous Exposures

**Stata**:
```stata
tvmerge using tv_dose, id(id) continuous(2)
* or
tvmerge using tv_dose, id(id) continuous(dose_mg)
```

**Python**:
```python
merger = TVMerge(
    ...,
    continuous=[2]  # By position (1-indexed)
    # or
    continuous=['dose_mg']  # By name
)
```

### Multiple Datasets

**Stata** (sequential):
```stata
use tv_hrt, clear
tvmerge using tv_statin, ...
tvmerge using tv_aspirin, ...
```

**Python** (all at once):
```python
merger = TVMerge(
    datasets=['tv_hrt.dta', 'tv_statin.dta', 'tv_aspirin.dta'],
    id_col='id',
    start_cols=['start', 'start', 'start'],
    stop_cols=['stop', 'stop', 'stop'],
    exposure_cols=['exp', 'exp', 'exp'],
    output_names=['hrt', 'statin', 'aspirin']
)
```

## TVEvent Migration

### Basic Event Integration

**Stata**:
```stata
use tv_intervals, clear
tvevent using events, ///
    id(id) ///
    date(mi_date) ///
    compete(death_date) ///
    generate(event) ///
    timegen(time_years) ///
    timeunit(years)
```

**Python**:
```python
from tvtools import TVEvent

tv = TVEvent(
    intervals_data='tv_intervals.dta',
    events_data='events.dta',
    id_col='id',
    date_col='mi_date',
    compete_cols=['death_date'],
    output_col='event',
    time_col='time_years',
    time_unit='years'
)
result = tv.process()
```

### Competing Risks

**Stata**:
```stata
tvevent using events, ///
    date(disease) ///
    compete(death ltfu)
```

**Python**:
```python
tv = TVEvent(
    ...,
    date_col='disease',
    compete_cols=['death', 'ltfu']
)
```

### Event Labels

**Stata**:
```stata
label define event_lbl 0 "Censored" 1 "MI" 2 "Death"
label values event event_lbl
```

**Python** (during creation):
```python
tv = TVEvent(
    ...,
    event_labels={
        0: 'Censored',
        1: 'MI',
        2: 'Death'
    }
)
```

## Data Type Equivalents

| Stata Type | Python Type | Conversion |
|-----------|-------------|------------|
| `byte`, `int`, `long` | `int64` | Automatic |
| `float`, `double` | `float64` | Automatic |
| `str`, `str#` | `object` or `string` | Automatic |
| Date (td) | `datetime64[ns]` | `pd.to_datetime()` |
| Missing (`.`) | `NaN` or `NaT` | Automatic |

### Date Handling

**Stata**:
```stata
gen date_var = date(date_string, "DMY")
format date_var %td
```

**Python**:
```python
df['date_var'] = pd.to_datetime(df['date_string'], format='%d%m%Y')
```

## File Format Conversion

### Read Stata Files

```python
import pandas as pd

# Read .dta file
df = pd.read_stata('data.dta')

# With specific encoding
df = pd.read_stata('data.dta', encoding='utf-8')

# Convert dates
df = pd.read_stata('data.dta', convert_dates=True)
```

### Write Stata Files

```python
# Write to Stata format
df.to_stata('output.dta', write_index=False)

# With specific Stata version
df.to_stata('output.dta', version=117)  # Stata 15
```

## Common Workflow Comparison

### Stata Workflow

```stata
* 1. Load cohort
use cohort, clear

* 2. Create TV exposure
tvexpose using prescriptions, ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(entry_date) exit(exit_date)
save tv_drug, replace

* 3. Merge with another exposure
use tv_drug, clear
tvmerge using tv_statin, id(id)
save tv_merged, replace

* 4. Integrate events
use tv_merged, clear
tvevent using events, id(id) date(event_date) ///
    timegen(time) timeunit(years)
save final, replace

* 5. Analyze
stset time, failure(event)
stcox drug statin
```

### Python Workflow

```python
from tvtools import TVExpose, TVMerge, TVEvent

# 1. Create TV exposures
tv_drug = TVExpose(
    exposure_data='prescriptions.csv',
    master_data='cohort.csv',
    id_col='id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug',
    reference=0,
    entry_col='entry_date',
    exit_col='exit_date'
).run()

tv_statin = TVExpose(
    exposure_data='statin_rx.csv',
    master_data='cohort.csv',
    id_col='id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='statin',
    reference=0,
    entry_col='entry_date',
    exit_col='exit_date'
).run()

# 2. Merge exposures
merged = TVMerge(
    datasets=[tv_drug.data, tv_statin.data],
    id_col='id',
    start_cols=['exp_start', 'exp_start'],
    stop_cols=['exp_stop', 'exp_stop'],
    exposure_cols=['drug', 'statin'],
    output_names=['drug', 'statin']
).merge()

# 3. Integrate events
final = TVEvent(
    intervals_data=merged,
    events_data='events.csv',
    id_col='id',
    date_col='event_date',
    time_col='time',
    time_unit='years'
).process()

# 4. Save
final.data.to_csv('final.csv', index=False)

# 5. Analyze with lifelines
from lifelines import CoxPHFitter

cph = CoxPHFitter()
cph.fit(final.data, duration_col='time', event_col='event')
cph.print_summary()
```

## Missing Features in Python

Some Stata tvtools features not yet implemented in Python 0.1.0:

1. **Row expansion** (`expand()` option): Planned for future release
2. **Recency exposure type**: Planned for future release
3. **Some overlap methods**: Only 'layer' currently implemented
4. **Dialog interfaces**: Python is code-based only

## Advantages of Python Version

1. **Integration**: Works seamlessly with pandas, numpy, scikit-learn
2. **Visualization**: Easy integration with matplotlib, seaborn
3. **ML/AI**: Direct path to machine learning tools
4. **Notebooks**: Jupyter notebook support for interactive analysis
5. **Reproducibility**: Easier version control and sharing
6. **Performance**: Parallel processing built-in for large datasets
7. **Open source**: Free, no license required

## Getting Help

### Stata Users' Common Questions

**Q: Where's the output window?**
A: Python uses print() or displays in Jupyter notebooks.

**Q: How do I see the data?**
A: Use `result.data.head()` or `print(result.data)`

**Q: Where are saved datasets?**
A: Use `result.data.to_csv('file.csv')` or similar

**Q: How do I label variables?**
A: Use DataFrame metadata or create separate label dictionaries

**Q: What about missing values?**
A: Python uses `NaN` (numeric) and `NaT` (dates)

## Further Resources

- [Python for Stata Users](https://www.stata.com/python/pystata/)
- [Pandas Documentation](https://pandas.pydata.org/docs/)
- [Lifelines (Survival Analysis)](https://lifelines.readthedocs.io/)
- [tvtools Examples](../examples/)

## Summary

| Concept | Stata | Python |
|---------|-------|--------|
| **Philosophy** | In-memory single dataset | Multiple DataFrames |
| **Syntax** | Command-based | Object-oriented |
| **File Handling** | using/save | read/write functions |
| **Output** | Replaces current data | Returns new DataFrame |
| **Options** | Parentheses `()` | Named parameters `=` |
| **Lists** | Space-separated | Python lists `[]` |
| **Dictionaries** | `key=value` pairs | `{key: value}` |

The Python version maintains the same core algorithms and logic as the Stata version while leveraging Python's ecosystem and modern programming practices.

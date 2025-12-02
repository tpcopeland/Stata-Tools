# tvtools: Time-Varying Analysis Tools for Python

**tvtools** is a Python package for creating and analyzing time-varying exposure datasets for survival analysis and epidemiological studies.

## Overview

tvtools provides three main modules that work together to prepare complex time-varying datasets for survival analysis:

### 1. **TVExpose** - Create Time-Varying Exposures
Transform period-based exposure data (prescriptions, treatments, interventions) into time-varying exposure variables with support for:
- Multiple exposure types (ever-treated, current/former, duration categories)
- Overlap resolution strategies
- Grace periods and washout periods
- Pattern tracking and switching analysis

### 2. **TVMerge** - Merge Time-Varying Datasets
Merge multiple time-varying exposure datasets using Cartesian interval intersections to create all combinations of overlapping exposures:
- Handles both categorical and continuous exposures
- Prorates continuous variables (doses, rates) for partial overlaps
- Batch processing for large datasets
- Built-in validation and diagnostics

### 3. **TVEvent** - Integrate Events and Competing Risks
Integrate outcome events and competing risks into time-varying datasets:
- Handles single and recurring events
- Competing risks with earliest-event priority
- Automatic interval splitting at event boundaries
- Generates analysis-ready survival datasets

## Why tvtools?

Traditional survival analysis often assumes exposures are fixed at baseline. In reality:
- Medication use changes over time
- People switch treatments
- Exposure accumulates or decays
- Multiple exposures overlap

tvtools handles these complexities by:
1. **Tracking exposures over time** - Create intervals where exposure status is constant
2. **Merging multiple exposures** - Combine overlapping time-varying datasets
3. **Integrating outcomes** - Flag events at the correct time points
4. **Preparing analysis-ready data** - Output ready for Cox models, competing risks, etc.

## Installation

### From PyPI (when released)
```bash
pip install tvtools
```

### From Source
```bash
git clone https://github.com/tpcopeland/Stata-Tools.git
cd Stata-Tools/Reimplementations/Python/tvtools
pip install -e .
```

### Requirements
- Python 3.8+
- pandas >= 1.5.0
- numpy >= 1.20.0

Optional dependencies:
- joblib >= 1.0.0 (for parallel processing)
- pyreadstat >= 1.1.0 (for Stata .dta file support)

## Quick Start

### Example 1: Basic Time-Varying Exposure

```python
from tvtools import TVExpose
import pandas as pd

# Load your data
prescriptions = pd.read_csv('prescriptions.csv')
cohort = pd.read_csv('cohort.csv')

# Create time-varying exposure
tv = TVExpose(
    exposure_data=prescriptions,
    master_data=cohort,
    id_col='patient_id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='drug_type',
    reference=0,
    entry_col='study_entry',
    exit_col='study_exit'
)

result = tv.run()
print(result.data.head())
```

### Example 2: Merge Multiple Exposures

```python
from tvtools import TVMerge

# Merge HRT and statin exposures
merger = TVMerge(
    datasets=['tv_hrt.csv', 'tv_statin.csv'],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['hrt_type', 'statin_dose'],
    output_names=['hrt', 'statin'],
    continuous=['statin']  # Statin dose is continuous
)

merged = merger.merge()
```

### Example 3: Integrate Events

```python
from tvtools import TVEvent

# Add events and competing risks
tv_event = TVEvent(
    intervals_data=merged,
    events_data='events.csv',
    id_col='id',
    date_col='event_date',
    compete_cols=['death_date'],
    event_type='single',
    time_col='time_years',
    time_unit='years'
)

final = tv_event.process()
```

## Complete Workflow

```python
from tvtools import TVExpose, TVMerge, TVEvent

# Step 1: Create time-varying exposures
tv_hrt = TVExpose(
    exposure_data='prescriptions_hrt.csv',
    master_data='cohort.csv',
    id_col='id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='hrt_type',
    reference=0,
    entry_col='entry_date',
    exit_col='exit_date',
    grace=30  # Bridge gaps <= 30 days
).run()

tv_statin = TVExpose(
    exposure_data='prescriptions_statin.csv',
    master_data='cohort.csv',
    id_col='id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='dose_mg',
    reference=0,
    entry_col='entry_date',
    exit_col='exit_date'
).run()

# Step 2: Merge exposures
merged = TVMerge(
    datasets=[tv_hrt.data, tv_statin.data],
    id_col='id',
    start_cols=['exp_start', 'exp_start'],
    stop_cols=['exp_stop', 'exp_stop'],
    exposure_cols=['hrt_type', 'dose_mg'],
    output_names=['hrt', 'statin']
).merge()

# Step 3: Integrate events
final = TVEvent(
    intervals_data=merged,
    events_data='events.csv',
    id_col='id',
    date_col='mi_date',
    compete_cols=['death_date'],
    time_col='time_years',
    time_unit='years'
).process()

# Ready for analysis!
print(final.data.head())
```

## Documentation

- [Quick Start Guide](quickstart.md)
- [API Reference](api.md)
- [TVExpose Guide](tvevent_guide.md)
- [TVMerge Guide](tvmerge_guide.md)
- [TVEvent Guide](tvevent_guide.md)
- [Migration from Stata](migration_from_stata.md)

## Examples

Complete working examples are available in the `examples/` directory:
- `basic_tvexpose_example.py` - Basic time-varying exposure creation
- `basic_tvmerge_example.py` - Basic merging of TV datasets
- `basic_tvevent_example.py` - Basic event integration
- `complete_workflow.py` - Full workflow using all three modules
- `competing_risks_example.py` - Competing risks analysis
- `continuous_exposure_example.py` - Continuous exposure handling
- `ever_treated_example.py` - Ever-treated exposure type

## Features

### TVExpose Features
- ✅ Multiple exposure types (time-varying, ever-treated, current/former, duration, continuous)
- ✅ Overlap resolution (layer, priority, split, combine methods)
- ✅ Grace periods to bridge gaps
- ✅ Lag and washout periods
- ✅ Pattern tracking (switching detection)
- ✅ Flexible time units

### TVMerge Features
- ✅ Cartesian interval intersection algorithm
- ✅ Continuous exposure proration
- ✅ Batch processing for large datasets
- ✅ Parallel processing support
- ✅ Coverage and overlap validation
- ✅ Comprehensive diagnostics

### TVEvent Features
- ✅ Single and recurring events
- ✅ Multiple competing risks
- ✅ Automatic interval splitting
- ✅ Time variable generation (days/months/years)
- ✅ Continuous variable adjustment
- ✅ Custom event labels

## Citation

If you use tvtools in your research, please cite:

```
Copeland, T. (2025). tvtools: Time-Varying Analysis Tools for Python.
https://github.com/tpcopeland/Stata-Tools
```

## License

MIT License. See LICENSE file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/tpcopeland/Stata-Tools/issues)
- **Documentation**: [Full Documentation](https://github.com/tpcopeland/Stata-Tools/tree/main/Reimplementations/Python/tvtools/docs)
- **Examples**: [Example Scripts](https://github.com/tpcopeland/Stata-Tools/tree/main/Reimplementations/Python/tvtools/examples)

## Version

Current version: 0.1.0 (Beta)

## Credits

Python implementation by Tom Copeland, based on the Stata tvtools package.

Original Stata implementation concepts and algorithms adapted for Python with enhancements.

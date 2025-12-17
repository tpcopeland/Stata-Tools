# tvtools - Python Time-Varying Analysis Tools

![Python 3.8+](https://img.shields.io/badge/Python-3.8%2B-blue) ![MIT License](https://img.shields.io/badge/License-MIT-green) ![Status](https://img.shields.io/badge/Status-Beta-blue)

Python reimplementation of the Stata tvtools package for time-varying exposure and event analysis in survival studies.

## Overview

**tvtools** is a comprehensive suite of tools for creating and manipulating time-varying datasets in epidemiological and survival analysis research. This Python package provides a modern, type-safe reimplementation of the original Stata tvtools, with enhanced performance, parallel processing capabilities, and integration with the Python scientific ecosystem.

### Modules

The package consists of three main modules:

1. **tvexpose** - Create time-varying exposure variables from period-based exposure data
2. **tvmerge** - Merge multiple time-varying datasets using Cartesian interval intersections
3. **tvevent** - Integrate outcome events and competing risks into time-varying datasets

## Features

- **Type-safe**: Full type hints for better IDE support and error detection
- **Fast**: Vectorized pandas operations with optional parallel processing
- **Flexible**: Works with DataFrames, CSV, Parquet, Stata .dta files
- **Well-tested**: Comprehensive test suite with >90% coverage target
- **Well-documented**: Detailed docstrings and usage examples
- **Memory-efficient**: Batch processing for large datasets
- **Compatible**: Results match Stata tvtools output

## Installation

### From source (development)

```bash
git clone https://github.com/tpcopeland/Stata-Tools
cd Stata-Tools/Reimplementations/Python/tvtools
pip install -e .
```

### With optional dependencies

```bash
# For parallel processing
pip install -e ".[parallel]"

# For development
pip install -e ".[dev]"
```

## Quick Start

### tvexpose: Create Time-Varying Exposure Variables

```python
from tvtools import TVExpose

# Basic time-varying exposure
exposer = TVExpose(
    exposure_data="prescriptions.csv",
    master_data="cohort.csv",
    id_col="patient_id",
    start_col="rx_start",
    stop_col="rx_stop",
    exposure_col="drug_type",
    reference=0,
    entry_col="study_entry",
    exit_col="study_exit"
)

result = exposer.run()
print(f"Created {result.n_periods} periods for {result.n_persons} persons")
```

### tvmerge: Merge Multiple Time-Varying Datasets

```python
from tvtools import TVMerge

# Merge two time-varying datasets
merger = TVMerge(
    datasets=['tv_hrt.csv', 'tv_dmt.csv'],
    id_col='id',
    start_cols=['rx_start', 'dmt_start'],
    stop_cols=['rx_stop', 'dmt_stop'],
    exposure_cols=['tv_exposure', 'tv_exposure'],
    output_names=['hrt', 'dmt']
)

result = merger.merge()
print(f"Merged {len(result)} time periods")
```

### tvevent: Integrate Events and Competing Risks

```python
from tvtools import TVEvent

# Add events with competing risks
tv = TVEvent(
    intervals_data=tvexpose_output,
    events_data='cohort.csv',
    id_col='person_id',
    date_col='event_date',
    compete_cols=['death_date'],
    time_col='years',
    time_unit='years'
)

result = tv.process()
print(f"Flagged {result.n_events} events in {result.n_total} periods")
```

## Complete Workflow Example

```python
import pandas as pd
from tvtools import TVExpose, TVMerge, TVEvent

# Step 1: Create time-varying exposure for medication
cohort = pd.read_csv('cohort.csv')
medications = pd.read_csv('medications.csv')

tv_meds = TVExpose(
    exposure_data=medications,
    master_data=cohort,
    id_col='person_id',
    start_col='rx_start',
    stop_col='rx_stop',
    exposure_col='medication',
    reference=0,
    entry_col='study_entry',
    exit_col='study_exit'
).run()

# Step 2: Create time-varying exposure for procedures
procedures = pd.read_csv('procedures.csv')

tv_procs = TVExpose(
    exposure_data=procedures,
    master_data=cohort,
    id_col='person_id',
    start_col='proc_start',
    stop_col='proc_stop',
    exposure_col='procedure_type',
    reference=0,
    entry_col='study_entry',
    exit_col='study_exit'
).run()

# Step 3: Merge the two time-varying datasets
tv_merged = TVMerge(
    datasets=[tv_meds.data, tv_procs.data],
    id_col='person_id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['tv_exposure', 'tv_exposure'],
    output_names=['medication', 'procedure']
).merge()

# Step 4: Integrate outcome events with competing risks
tv_final = TVEvent(
    intervals_data=tv_merged,
    events_data=cohort,
    id_col='person_id',
    date_col='disease_date',
    compete_cols=['death_date'],
    time_col='time_years',
    time_unit='years'
).process()

# Ready for survival analysis!
print(tv_final.data.head())
tv_final.data.to_csv('analysis_dataset.csv', index=False)
```

## Integration with Survival Analysis

### With lifelines (Cox Proportional Hazards)

```python
from lifelines import CoxPHFitter

# Prepare data
df = tv_final.data.copy()
df['duration'] = (df['stop'] - df['start']).dt.days / 365.25

# Fit Cox model
cph = CoxPHFitter()
cph.fit(df, duration_col='duration', event_col='_failure',
        formula="medication + procedure + age + sex")
cph.print_summary()
```

### With scikit-survival

```python
from sksurv.linear_model import CoxPHSurvivalAnalysis

# Convert to structured array format
y = np.array(
    [(row['_failure'] > 0, row['duration'])
     for _, row in df.iterrows()],
    dtype=[('event', bool), ('time', float)]
)
X = df[['medication', 'procedure', 'age', 'sex']]

# Fit Cox model
cox = CoxPHSurvivalAnalysis()
cox.fit(X, y)
```

## Performance

### Benchmarks

| Dataset Size | Operations | Time (1 core) | Time (parallel) |
|-------------|------------|---------------|-----------------|
| 1K persons  | tvexpose   | < 1s          | < 1s            |
| 10K persons | tvexpose   | 2-5s          | 1-2s            |
| 100K persons| tvexpose   | 20-60s        | 5-15s           |
| 2-dataset   | tvmerge    | 5s            | 2s              |
| 3-dataset   | tvmerge    | 30s           | 10s             |

### Memory Optimization

For large datasets, use batch processing:

```python
# Process in smaller batches to reduce memory usage
merger = TVMerge(
    datasets=['large1.csv', 'large2.csv'],
    id_col='id',
    start_cols=['start', 'start'],
    stop_cols=['stop', 'stop'],
    exposure_cols=['exp1', 'exp2'],
    batch_pct=20,  # Process 20% of IDs at a time
    n_jobs=-1      # Use all CPU cores
)
result = merger.merge()
```

## Documentation

### Comprehensive Guides

- **[Documentation Index](docs/index.md)** - Package overview and installation
- **[Quick Start Guide](docs/quickstart.md)** - Get started in 5 minutes
- **[API Reference](docs/api.md)** - Complete API documentation
- **[TVExpose Guide](docs/tvexpose_guide.md)** - Detailed exposure creation guide
- **[TVMerge Guide](docs/tvmerge_guide.md)** - Detailed merging guide
- **[TVEvent Guide](docs/tvevent_guide.md)** - Detailed event integration guide
- **[Migration from Stata](docs/migration_from_stata.md)** - Guide for Stata users

### Working Examples

Complete runnable examples in the [`examples/`](examples/) directory:

- **[basic_tvexpose_example.py](examples/basic_tvexpose_example.py)** - Basic time-varying exposure creation
- **[basic_tvmerge_example.py](examples/basic_tvmerge_example.py)** - Basic merging of TV datasets
- **[basic_tvevent_example.py](examples/basic_tvevent_example.py)** - Basic event integration
- **[complete_workflow.py](examples/complete_workflow.py)** - Full workflow using all three modules
- **[competing_risks_example.py](examples/competing_risks_example.py)** - Competing risks analysis
- **[continuous_exposure_example.py](examples/continuous_exposure_example.py)** - Continuous exposure handling
- **[ever_treated_example.py](examples/ever_treated_example.py)** - Ever-treated exposure type

### Module Documentation

#### tvexpose

Creates time-varying exposure variables from period-based exposure data. Supports:

- Time-varying categorical exposures (default)
- Ever-treated binary indicators
- Current/former trichotomous variables
- Duration categories
- Continuous cumulative exposure
- Recency categories
- Overlap resolution strategies (layer, priority, split, combine)
- Grace periods and carryforward
- Lag and washout periods

See [TVExpose Guide](docs/tvexpose_guide.md) and `tvtools.tvexpose.TVExpose` for full documentation.

#### tvmerge

Merges multiple time-varying datasets using Cartesian interval intersections. Features:

- Handles 2+ datasets
- Categorical and continuous exposures
- Automatic proration of continuous exposures
- Batch processing for memory efficiency
- Parallel processing support
- Coverage and overlap validation
- Flexible output naming

See [TVMerge Guide](docs/tvmerge_guide.md) and `tvtools.tvmerge.TVMerge` for full documentation.

#### tvevent

Integrates outcome events and competing risks into time-varying datasets. Capabilities:

- Competing risk resolution (earliest event wins)
- Interval splitting when events occur mid-period
- Proportional adjustment of continuous variables
- Single (terminal) vs recurring events
- Time variable generation (days/months/years)
- Event type labeling

See [TVEvent Guide](docs/tvevent_guide.md) and `tvtools.tvevent.TVEvent` for full documentation.

## Requirements

### Required
- Python >= 3.8
- pandas >= 1.5.0
- numpy >= 1.23.0

### Optional
- joblib >= 1.2.0 (for parallel processing)

### Development
- pytest >= 7.2.0
- pytest-cov >= 4.0.0
- black >= 22.0.0
- mypy >= 0.990
- ruff >= 0.0.200

## Development

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage report
pytest --cov=tvtools --cov-report=html

# Run specific test file
pytest tests/test_tvexpose.py

# Run with verbose output
pytest -v
```

### Code Quality

```bash
# Format code
black tvtools/ tests/

# Lint code
ruff check tvtools/ tests/

# Type check
mypy tvtools/
```

## Comparison with Stata tvtools

| Feature | Stata | Python |
|---------|-------|--------|
| **Input** | .dta files | DataFrames, CSV, Parquet, .dta |
| **Performance** | Single-threaded | Vectorized + parallel |
| **Type safety** | Dynamic | Type hints + validation |
| **Error handling** | Error codes | Custom exceptions |
| **Memory** | In-memory only | Batch processing |
| **Integration** | Stata ecosystem | Python scientific stack |
| **Platform** | Windows/Mac/Linux | Any Python platform |

## Migration from Stata

If you're familiar with Stata tvtools:

| Stata Command | Python Equivalent |
|--------------|-------------------|
| `tvexpose using expdata, ...` | `TVExpose(exposure_data='expdata.csv', ...)` |
| `tvmerge using ds1 ds2, ...` | `TVMerge(datasets=['ds1.csv', 'ds2.csv'], ...)` |
| `tvevent using events, ...` | `TVEvent(events_data='events.csv', ...)` |

Key differences:
- Python uses DataFrames instead of Stata frames
- Options are class parameters instead of command options
- Results are returned as objects instead of modifying data in memory
- Errors raise exceptions instead of setting return codes

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with tests
4. Ensure all tests pass (`pytest`)
5. Format code (`black tvtools/ tests/`)
6. Submit a pull request

## Citation

If you use tvtools in your research, please cite:

```bibtex
@software{tvtools_python,
  author = {Copeland, Tom},
  title = {tvtools: Time-Varying Analysis Tools for Python},
  year = {2025},
  url = {https://github.com/tpcopeland/Stata-Tools}
}
```

For the original Stata implementation:

```bibtex
@software{tvtools_stata,
  author = {Copeland, Tom},
  title = {tvtools: Time-Varying Analysis Tools for Stata},
  year = {2024},
  url = {https://github.com/tpcopeland/Stata-Tools}
}
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Contact

Tom Copeland<br>
Email: tpcopeland@gmail.com<br>
GitHub: https://github.com/tpcopeland/Stata-Tools

## Acknowledgments

- Original Stata tvtools implementation
- pandas and numpy development teams
- Python scientific computing community

## Version History

### 0.2.0 (2025-12-16) - Beta Release
- Added dose and dosecuts options to tvexpose for cumulative dose tracking
- Added keep option to tvmerge for preserving additional variables
- Added startvar/stopvar options to tvevent for custom column names
- Comprehensive test suite with 116 tests
- All core functionality now complete and validated

### 0.1.0 (2025-01-XX) - Initial Alpha Release
- Initial package structure
- Core module implementations
- Basic test suite
- Documentation

## Roadmap

- [x] v0.2.0: Complete tvexpose implementation (dose, dosecuts)
- [x] v0.2.0: Complete tvmerge implementation (keep option)
- [x] v0.2.0: Complete tvevent implementation (startvar/stopvar)
- [x] v0.2.0: Comprehensive testing and validation (116 tests)
- [ ] v1.0.0: First stable release
- [ ] Future: GPU acceleration, Dask support for very large datasets

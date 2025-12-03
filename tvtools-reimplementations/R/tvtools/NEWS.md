# tvtools 0.1.0 (Development)

## Initial Release

* Initial R implementation of tvtools package
* Implements three core functions:
  - `tvexpose()`: Create time-varying exposure variables from period-based data
  - `tvmerge()`: Merge multiple time-varying datasets with temporal alignment
  - `tvevent()`: Integrate outcome events and competing risks
* Full feature parity with Stata version for core functionality
* Optimized performance using data.table
* Comprehensive documentation with roxygen2
* Basic test suite for core functionality

## Known Limitations

* Some advanced diagnostic features from Stata version not yet implemented
* Limited test coverage (expanding in future releases)
* Documentation examples need expansion

## Future Plans

* Add vignettes for common use cases
* Expand test coverage
* Add more validation checks
* Performance benchmarking and optimization
* Additional helper functions for data preparation

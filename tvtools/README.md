# tvtools

Commands for formatting and merging time-varying data.

## Description

tvtools provides two commands for working with time-varying exposure data in survival analysis:

- **tvexpose** - Create time-varying exposure variables for survival analysis
- **tvmerge** - Merge time-varying datasets with comprehensive validation

Both commands include dialog interfaces and menu integration for ease of use.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools
net install tvtools
```

## Commands

### tvexpose

Create time-varying exposure variables from period-based exposure data. Supports multiple exposure types including:
- Basic time-varying exposure
- Ever-treated (binary switch)
- Current/former exposure status
- Duration categories
- Continuous cumulative exposure
- Recency categories

### tvmerge

Merge time-varying datasets with validation and gap detection. Ensures proper time alignment and data integrity.

## Dialog interfaces

Access the graphical interfaces:
```stata
db tvexpose
db tvmerge
```

Optional menu integration:
```stata
do tvtools_menu_setup.do
```

After menu setup, access via: **User > Time-varying exposures**

## Quick example - tvexpose

```stata
* Load main cohort data
use cohort, clear

* Create time-varying exposure from medication records
tvexpose using medication_periods, ///
    id(patient_id) ///
    start(rx_start) ///
    stop(rx_end) ///
    exposure(med_type) ///
    entry(study_entry) ///
    exit(study_exit) ///
    generate(tv_medication)
```

## Quick example - tvmerge

```stata
* Merge two time-varying datasets
use tv_exposures, clear
tvmerge using tv_labs, ///
    id(patient_id) ///
    start(period_start) ///
    stop(period_end)
```

## Features

- Comprehensive handling of time-varying data
- Support for multiple exposure types
- Gap detection and handling
- Overlap resolution
- Validation and diagnostic tools
- Dialog interfaces with extensive documentation
- Menu integration

## Requirements

Stata 16.0 or higher

## Author

Timothy P Copeland

## Documentation

- Command help: `help tvexpose`, `help tvmerge`
- Dialog documentation: tvexpose_dialog.md, tvmerge_dialog.md
- Installation guide: INSTALLATION.md

## Help

For more information:
```stata
help tvexpose
help tvmerge
```

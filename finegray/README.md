# finegray v1.1.0

Fine-Gray competing risks regression for Stata.

## Overview

`finegray` fits Fine-Gray subdistribution hazard models using a Mata-native O(np) forward-backward scan algorithm by default. It is typically 10-100x faster than `stcrreg` and matches it to machine precision. A `stcrprep` + `stcox` wrapper mode is available for `tvc()` and `strata()` features.

## Installation

```stata
cap ado uninstall finegray
net install finegray, from("path/to/finegray")
```

## Quick Start

```stata
* Setup competing risks data
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

* Default (Mata engine)
finegray ifp tumsize pelnode, events(status) cause(1)

* Wrapper mode (for tvc/strata features)
finegray ifp tumsize pelnode, events(status) cause(1) wrapper

* CIF prediction
finegray_predict cif_hat, cif
```

## Requirements

- Stata 16+
- `stcrprep` (SSC) for wrapper mode only; not needed for default Mata engine

## Paper

Copeland, T. P. (2026). finegray: Fast Fine-Gray competing risks regression for Stata. *Stata Journal* (submitted).

The manuscript and benchmark code are in `studies/Methods/finegray/` in the Plans-and-Proposals repository.

## Author

Timothy P Copeland
Department of Clinical Neuroscience, Karolinska Institutet

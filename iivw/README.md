# iivw

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue)

Inverse intensity of visit weighting for longitudinal data with irregular visits.

## Description

`iivw` corrects for informative visit processes in longitudinal observational studies where sicker patients visit more frequently, biasing naive analyses. It implements:

- **IIW** (inverse intensity weighting) via Andersen-Gill recurrent-event Cox models (Buzkova & Lumley 2007)
- **IPTW** (inverse probability of treatment weighting) via logistic propensity score models
- **FIPTIW** (fully inverse probability of treatment and intensity weighting) = IIW x IPTW (Tompkins et al. 2025)

The package provides two commands: `iivw_weight` for weight computation and `iivw_fit` for fitting weighted outcome models.

## Installation

```stata
net install iivw, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/iivw")
```

## Syntax

```stata
* Step 1: Compute weights
iivw_weight, id(varname) time(varname) visit_cov(varlist) [options]

* Step 2: Fit weighted outcome model
iivw_fit depvar indepvars [if] [in] [, options]
```

## Examples

```stata
* Load longitudinal MS visit data
use relapses.dta, clear

* Prepare variables
sort id edss_date
gen double days = edss_date - dx_date
gen byte relapse = !missing(relapse_date)

* IIW only (correct for informative visit timing)
iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
iivw_fit edss relapse, model(gee) timespec(linear)

* FIPTIW with treatment and truncation
bysort id (days): gen double edss_bl = edss[1]
iivw_weight, id(id) time(days) ///
    visit_cov(edss relapse) ///
    treat(treated) treat_cov(age sex edss_bl) ///
    truncate(1 99) replace nolog
iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)
```

## Requirements

- Stata 16.0 or higher

## Version

- **1.0.0** (2026-03-05): Initial release

## Author

Timothy P Copeland
Department of Clinical Neuroscience, Karolinska Institutet

## License

MIT License

## References

- Buzkova P, Lumley T (2007). Longitudinal data analysis for generalized linear models with follow-up dependent on outcome-related variables. *Can J Stat* 35:485-500.
- Tompkins G, Dubin JA, Wallace M (2025). On flexible inverse probability of treatment and intensity weighting. *Stat Methods Med Res*.
- Pullenayegum EM (2020). Meeting the assumptions of inverse-intensity weighting. *Epidemiologic Methods*.

*! cstat_surv Version 1.0.0  17November2025

*! Original Author: Tim Copeland
*! Created on  17 November 2025

capture program drop cstat_surv
program define cstat_surv, rclass
  syntax ,

  * Validation: Check if last estimates found (Cox model fitted)
  if "`e(cmd)'" == "" {
    display as error "last estimates not found"
    display as error "Run stcox before using cstat_surv"
    exit 301
  }

  * Validation: Check if last estimation was stcox
  if "`e(cmd)'" != "stcox" {
    display as error "last estimation was `e(cmd)', not stcox"
    display as error "cstat_surv requires stcox estimation"
    exit 301
  }

  * Validation: Check if data is stset
  capture assert _st == 1
  if _rc {
    display as error "data not st; use stset"
    display as error "Data must be stset before running cstat_surv"
    exit 119
  }

  * Validation: Check if somersd command is available
  capture which somersd
  if _rc {
    display as error "somersd command not found; install with: ssc install somersd"
    exit 199
  }

  * Declare temporary variables
  tempvar hrs invhr censind

  * Generate predictions and compute inverse hazard ratio
  quietly {
    capture predict double `hrs' if e(sample)
    if _rc {
      display as error "Failed to predict from Cox model"
      exit 322
    }
    gen double `invhr' = 1/`hrs'
    generate `censind' = 1 - _d if _st==1 & e(sample)
  }

  * Calculate C-statistic using somersd
  somersd _t `invhr' if _st==1 & e(sample), cenind(`censind') tdist transf(c)

  * Return somersd results
  return add
end
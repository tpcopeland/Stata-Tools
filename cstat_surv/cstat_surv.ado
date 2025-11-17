*! cstat_cox Version 1.0.0  17November2025

*! Original Author: Tim Copeland
*! Created on  17 November 2025

capture program drop cstat_surv
program define cstat_surv, nclass
  syntax ,

  * Validation: Check if last estimates found (Cox model fitted)
  if "`e(cmd)'" == "" {
    display as error "last estimates not found"
    display as error "Run stcox before using cstat_surv"
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

quietly{
predict hrs
gen invhr=1/hrs
generate censind=1-_d if _st==1
}
somersd _t invhr if _st==1, cenind(censind) tdist transf(c)
quietly drop hrs invhr censind
end
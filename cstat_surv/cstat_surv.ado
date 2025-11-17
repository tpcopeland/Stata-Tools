*! cstat_cox Version 1.0.0  17November2025

*! Original Author: Tim Copeland
*! Created on  17 November 2025

capture program drop cstat_surv
program define cstat_surv, nclass
  syntax ,
quietly{
predict hrs
gen invhr=1/hrs
generate censind=1-_d if _st==1
}
somersd _t invhr if _st==1, cenind(censind) tdist transf(c)
quietly drop hrs invhr censind 
end
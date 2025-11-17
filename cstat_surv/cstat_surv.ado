*! cstat_cox Version 1.0  15May2022

*! Original Author: Tim Copeland 
*! Created on  15 May 2022 at 15:23:00 Pacific

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
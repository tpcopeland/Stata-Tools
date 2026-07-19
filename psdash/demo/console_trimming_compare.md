---
title: "console_trimming_compare"
---

## Did trimming help? pre/post-trimming comparison

```stata
. noisily psdash support statin ps, crump compare
>     covariates(age female bmi sbp cholesterol) nograph
```

```
Common Support Assessment
Treatment:         statin
PS variable:       ps
Observations:             800

------------------------------------------------------------
Propensity Score Range
------------------------------------------------------------
                            Treated        Control
------------------------------------------------------------
                   N            551            249
              Min PS         0.3136         0.1853
              Max PS         0.9505         0.9206
------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Method:                min-max overlap (optimistic)
Lower bound:               0.3136
Upper bound:               0.9206
Outside support:               17 ( 2.12%)
  Treated outside:             12
  Control outside:              5
-------------------------------------------------------

-------------------------------------------------------
Crump et al. (2009) Optimal Trimming
-------------------------------------------------------
Optimal alpha:             0.1040
Trim region:           [0.104, 0.896]
Observations trimmed:          32 ( 4.00%)
Remaining sample:             768
-------------------------------------------------------

Support: Trimmed ( 4.0% excluded)

Pre/Post-Trimming Comparison
                      Metric          Pre         Post
                  N retained          800          768
         Outside support (%)         2.12         1.56
                ESS (% of N)         71.2         75.1
             Max |SMD| (raw)        0.472        0.426
```

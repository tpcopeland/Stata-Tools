---
title: "console_support"
---

```stata
. noisily psdash support statin ps, crump nograph
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
Lower bound:               0.3136
Upper bound:               0.9206
Outside support:               17 ( 2.12%)
  Treated outside:             12
  Control outside:              5
-------------------------------------------------------

-------------------------------------------------------
Crump et al. (2009) Optimal Trimming
-------------------------------------------------------
Optimal alpha:             0.1000
Trim region:           [0.100, 0.900]
Observations trimmed:          26 ( 3.25%)
Remaining sample:             774
-------------------------------------------------------

Support: Trimmed ( 3.2% excluded)

```

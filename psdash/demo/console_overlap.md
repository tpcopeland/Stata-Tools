---
title: "console_overlap"
---

```stata
. noisily psdash overlap statin ps, nograph
```

```
Propensity Score Overlap
Treatment:         statin
PS variable:       ps

----------------------------------------------------------------------
Propensity Score Distribution
----------------------------------------------------------------------
                            Treated        Control
----------------------------------------------------------------------
                   N            551            249
                Mean         0.7191         0.6217
                  SD         0.1325         0.1486
                 Min         0.3136         0.1853
                 Max         0.9505         0.9206
----------------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.3136
Upper bound:               0.9206
Outside support:               17 ( 2.12%)
  Treated outside:             12
  Control outside:              5
C-statistic (AUC):         0.6881
-------------------------------------------------------

Overlap: Good ( 2.1% outside support)

```

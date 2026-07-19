---
title: "console_mg_overlap"
---

## Multi-group overlap diagnostics

```stata
. noisily psdash overlap arm, psvars(ps0 ps1 ps2) nograph
```

```
Propensity Score Overlap
Treatment:         arm (3 groups)
PS variable:       ps0
Reference group:   0

-----------------------------------------------------------
Propensity Score Distribution
-----------------------------------------------------------
                          Placebo     Low dose    High dose
-----------------------------------------------------------
                   N          154          321          725
                Mean       0.1515       0.2738       0.6163
                  SD       0.0608       0.0409       0.0831
                 Min       0.0422       0.1758       0.3046
                 Max       0.3586       0.4003       0.8513
-----------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.3046
Upper bound:               0.3586
Outside support:             1129 (94.08%)
  Placebo outside:        152
  Low dose outside:        253
  High dose outside:        724
-------------------------------------------------------
Warning: >10% of observations outside common support region.

Overlap: WARNING (94.1% outside support; 1 finding(s))
  Consider: psdash support, threshold(0.05)
```

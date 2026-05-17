---
title: "console_mg_support"
---

```stata
. noisily psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1) nograph
```

```
Common Support Assessment
Treatment:         arm (3 groups)
PS variable:       ps0
Reference group:   0
Observations:           1,200

-----------------------------------------------------------
Propensity Score Range
-----------------------------------------------------------
                          Placebo     Low dose    High dose
-----------------------------------------------------------
                   N          154          321          725
              Min PS       0.0422       0.1758       0.3046
              Max PS       0.3586       0.4003       0.8513
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

-------------------------------------------------------
Manual Threshold Trimming
-------------------------------------------------------
Threshold:                 0.1000
Trim region:           [0.100, 0.900]
Observations trimmed:          30 ( 2.50%)
Remaining sample:            1170
-------------------------------------------------------
Warning: >10% of observations outside common support.

Support: Trimmed ( 2.5% excluded)

```

---
title: "console_mg_support"
---

## Multi-group common support

```stata
. noisily psdash support arm, psvars(ps0 ps1 ps2) threshold(0.1)
>     generate(mg_support) nograph
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

Support indicator generated: mg_support
Warning: >10% of observations outside common support.

Support: Trimmed ( 2.5% excluded)
```

```stata
. noisily tabulate mg_support arm, column
```

```
+-------------------+
| Key               |
|-------------------|
|     frequency     |
| column percentage |
+-------------------+

In trimmed |
   support |
   [0.100, |          Treatment arm
    0.900] |   Placebo   Low dose  High dose |     Total
-----------+---------------------------------+----------
         0 |        30          0          0 |        30
           |     19.48       0.00       0.00 |      2.50
-----------+---------------------------------+----------
         1 |       124        321        725 |     1,170
           |     80.52     100.00     100.00 |     97.50
-----------+---------------------------------+----------
     Total |       154        321        725 |     1,200
           |    100.00     100.00     100.00 |    100.00
```

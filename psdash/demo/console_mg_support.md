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
Generalized Positivity (full GPS vector)
-------------------------------------------------------
Min GPS (worst unit):       0.0214
Floor:                     0.0100
Below floor:                    0 ( 0.00%)
  min e(Placebo):       0.0214
  min e(Low dose):       0.1273
  min e(High dose):       0.3046
-------------------------------------------------------

-------------------------------------------------------
Observed-arm PS Overlap (informational)
-------------------------------------------------------
Lower bound:               0.3046
Upper bound:               0.3586
Outside overlap:             1129 (94.08%)
  Placebo outside:        152
  Low dose outside:        253
  High dose outside:        724
-------------------------------------------------------

-------------------------------------------------------
Manual Threshold Trimming
-------------------------------------------------------
Threshold:                 0.1000
Trim region:           [0.100, 0.900]
Observations trimmed:         410 (34.17%)
Remaining sample:             790
-------------------------------------------------------

Support indicator generated: mg_support
Warning: >10% of observations outside observed-arm PS overlap.

Support: Trimmed (34.2% excluded)
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

   All GPS |
components |          Treatment arm
  >= 0.100 |   Placebo   Low dose  High dose |     Total
-----------+---------------------------------+----------
         0 |        30         97        283 |       410
           |     19.48      30.22      39.03 |     34.17
-----------+---------------------------------+----------
         1 |       124        224        442 |       790
           |     80.52      69.78      60.97 |     65.83
-----------+---------------------------------+----------
     Total |       154        321        725 |     1,200
           |    100.00     100.00     100.00 |    100.00
```

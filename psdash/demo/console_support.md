---
title: "console_support"
---

## Common support with generated indicator

```stata
. noisily psdash support statin ps, crump generate(in_support) nograph
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

Support indicator generated: in_support

Support: Trimmed ( 3.2% excluded)
```

```stata
. noisily tabulate in_support statin, column
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
   [0.100, |      Statin use
    0.900] |        No        Yes |     Total
-----------+----------------------+----------
         0 |         3         23 |        26
           |      1.20       4.17 |      3.25
-----------+----------------------+----------
         1 |       246        528 |       774
           |     98.80      95.83 |     96.75
-----------+----------------------+----------
     Total |       249        551 |       800
           |    100.00     100.00 |    100.00
```

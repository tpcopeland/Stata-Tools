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

Support indicator generated: in_support

Support: Trimmed ( 4.0% excluded)
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
   [0.104, |      Statin use
    0.896] |        No        Yes |     Total
-----------+----------------------+----------
         0 |         3         29 |        32
           |      1.20       5.26 |      4.00
-----------+----------------------+----------
         1 |       246        522 |       768
           |     98.80      94.74 |     96.00
-----------+----------------------+----------
     Total |       249        551 |       800
           |    100.00     100.00 |    100.00
```

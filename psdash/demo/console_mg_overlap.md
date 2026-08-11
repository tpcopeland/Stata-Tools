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

---------------------------------------------------------------------
Mean GPS by Observed Treatment Group
---------------------------------------------------------------------
      Observed group         N   e(Placebo)  e(Low dose) e(High dose)
---------------------------------------------------------------------
             Placebo       154       0.1515       0.2775       0.5710
            Low dose       321       0.1336       0.2738       0.5926
           High dose       725       0.1211       0.2626       0.6163
---------------------------------------------------------------------

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

Overlap: No GPS-floor violation ( 0.0% below 0.010)
```

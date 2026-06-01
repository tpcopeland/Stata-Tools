---
title: "console_multi_bias"
---

## Multi-bias Monte Carlo analysis

```stata
. qba_multi, a(136) b(297) c(1432) d(6738) reps(5000)
>     seca(.85) spca(.95)
>     dist_se("trapezoidal .75 .82 .88 .95")
>     dist_sp("trapezoidal .90 .93 .97 1.0")
>     sela(.90) selb(.85) selc(.70) seld(.80)
>     dist_sela("trapezoidal .82 .87 .95 1.0")
>     dist_selb("trapezoidal .75 .82 .88 .95")
>     dist_selc("trapezoidal .58 .66 .74 .82")
>     dist_seld("trapezoidal .68 .74 .84 .90")
>     p1(.40) p0(.20) rrcd(2.0)
>     dist_p1("beta 12 18") dist_p0("beta 5 20")
>     dist_rr("trapezoidal 1.3 1.7 2.3 3.2")
>     seed(20260229)
```

```
Multi-Bias Analysis

Replications:    5,000  (valid:    5,000)

Bias corrections applied
  Cell-level order: misclass selection
  [x] Misclassification (exposure)
  [x] Selection bias
  [x] Unmeasured confounding (measure-level, applied last)

Observed 2x2 table
              Exposed   Unexposed
  Cases         136.0     297.0
  Non-cases    1432.0    6738.0

  Observed OR:     2.1546

Corrected OR (Monte Carlo)
  Median:      1.8852
  Mean:        1.9187
  SD:          0.3679
  95% CI:     1.3065 -    2.7389
```

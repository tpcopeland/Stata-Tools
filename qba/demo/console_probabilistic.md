---
title: "console_probabilistic"
---

## Probabilistic single-bias analyses

### Misclassification with trapezoidal Se/Sp distributions

```stata
. qba_misclass, a(136) b(297) c(1432) d(6738)
>     seca(.85) spca(.95) reps(5000)
>     dist_se("trapezoidal .75 .82 .88 .95")
>     dist_sp("trapezoidal .90 .93 .97 1.0")
>     seed(20260226)
```

```
Probabilistic Bias Analysis: Misclassification

Type: Nondifferential exposure misclassification
Replications:    5,000  (valid:    5,000)

Observed 2x2 table
              Exposed   Unexposed
  Cases         136.0     297.0
  Non-cases    1432.0    6738.0

  Observed OR:     2.1546

Corrected OR (Monte Carlo)
  Median:      2.6672
  Mean:        2.7112
  SD:          0.2743
  95% CI:     2.3160 -    3.3286
```

### Selection bias with four selection-probability distributions

```stata
. qba_selection, a(136) b(297) c(1432) d(6738)
>     sela(.90) selb(.85) selc(.70) seld(.80) reps(5000)
>     dist_sela("trapezoidal .82 .87 .95 1.0")
>     dist_selb("trapezoidal .75 .82 .88 .95")
>     dist_selc("trapezoidal .58 .66 .74 .82")
>     dist_seld("trapezoidal .68 .74 .84 .90")
>     seed(20260227)
```

```
Probabilistic Bias Analysis: Selection Bias

Replications:    5,000  (valid:    5,000)

Observed 2x2 table
              Exposed   Unexposed
  Cases         136.0     297.0
  Non-cases    1432.0    6738.0

  Observed OR:     2.1546

Corrected OR (Monte Carlo)
  Median:      1.7832
  Mean:        1.7960
  SD:          0.2121
  95% CI:     1.4148 -    2.2355
```

### Unmeasured confounding with Beta and trapezoidal distributions

```stata
. qba_confound, estimate(2.15) measure(OR)
>     p1(.40) p0(.20) rrcd(2.0) reps(5000)
>     dist_p1("beta 12 18") dist_p0("beta 5 20")
>     dist_rr("trapezoidal 1.3 1.7 2.3 3.2")
>     evalue ci_bound(1.30) seed(20260228)
```

```
Probabilistic Bias Analysis: Unmeasured Confounding

Replications:    5,000  (valid:    5,000)

  Observed OR:     2.1500

Corrected OR (Monte Carlo)
  Median:      1.8379
  Mean:        1.8287
  SD:          0.2053
  95% CI:     1.4166 -    2.2236

E-value (VanderWeele & Ding 2017)
  E-value (point):     3.7224
  E-value (CI):        1.9245
```

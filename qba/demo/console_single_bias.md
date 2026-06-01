---
title: "console_single_bias"
---

## Fixed-parameter single-bias analyses

### Nondifferential exposure misclassification

```stata
. qba_misclass, a(136) b(297) c(1432) d(6738)
>     seca(.85) spca(.95)
```

```
Quantitative Bias Analysis: Misclassification

Type: Nondifferential exposure misclassification

Observed 2x2 table
              Exposed   Unexposed
  Cases         136.0     297.0
  Non-cases    1432.0    6738.0

Bias parameters
  Sensitivity: 0.8500
  Specificity: 0.9500

Corrected 2x2 table
              Exposed   Unexposed
  Cases         142.9     290.1
  Non-cases    1279.4    6890.6

Measures of association
  Observed OR:     2.1546
  Corrected OR:    2.6541
  Ratio (corrected/observed): 1.2318
```

### Differential exposure misclassification

```stata
. qba_misclass, a(136) b(297) c(1432) d(6738)
>     seca(.90) spca(.96) secb(.82) spcb(.94)
```

```
Quantitative Bias Analysis: Misclassification

Type: Differential exposure misclassification

Observed 2x2 table
              Exposed   Unexposed
  Cases         136.0     297.0
  Non-cases    1432.0    6738.0

Bias parameters
  Se (cases):     0.9000
  Sp (cases):     0.9600
  Se (non-cases): 0.8200
  Sp (non-cases): 0.9400

Corrected 2x2 table
              Exposed   Unexposed
  Cases         138.0     295.0
  Non-cases    1239.2    6930.8

Measures of association
  Observed OR:     2.1546
  Corrected OR:    2.6163
  Ratio (corrected/observed): 1.2143
```

### Outcome misclassification on the RR scale

```stata
. qba_misclass, a(136) b(297) c(1432) d(6738)
>     seca(.92) spca(.98) type(outcome) measure(RR)
```

```
Quantitative Bias Analysis: Misclassification

Type: Nondifferential outcome misclassification

Observed 2x2 table
              Exposed   Unexposed
  Cases         136.0     297.0
  Non-cases    1432.0    6738.0

Bias parameters
  Sensitivity: 0.9200
  Specificity: 0.9800

Corrected 2x2 table
              Exposed   Unexposed
  Cases         116.3     173.7
  Non-cases    1451.7    6861.3

Measures of association
  Observed RR:     2.0545
  Corrected RR:    3.0037
  Ratio (corrected/observed): 1.4620
```

### Selection bias

```stata
. qba_selection, a(136) b(297) c(1432) d(6738)
>     sela(.90) selb(.85) selc(.70) seld(.80)
```

```
Quantitative Bias Analysis: Selection Bias

Observed 2x2 table
              Exposed   Unexposed
  Cases         136.0     297.0
  Non-cases    1432.0    6738.0

Selection probabilities
              Exposed   Unexposed
  Cases        0.9000    0.8500
  Non-cases    0.7000    0.8000

Corrected 2x2 table
              Exposed   Unexposed
  Cases         151.1     349.4
  Non-cases    2045.7    8422.5

Measures of association
  Observed OR:     2.1546
  Corrected OR:    1.7806
  Selection bias factor (OR scale): 1.2101
  Ratio (corrected/observed): 0.8264
```

### Unmeasured confounding with E-value

```stata
. qba_confound, estimate(2.15) measure(OR)
>     p1(.40) p0(.20) rrcd(2.0) evalue ci_bound(1.30)
```

```
Quantitative Bias Analysis: Unmeasured Confounding

  Observed OR:    2.1500

Confounding parameters
  P(U=1 | E=1): 0.4000
  P(U=1 | E=0): 0.2000
  RR(C->D):     2.0000

Results
  Bias factor:        1.1667
  Corrected OR:     1.8429
  Ratio (corrected/observed): 0.8571

E-value (VanderWeele & Ding 2017)
  E-value (point):     3.7224
  E-value (CI):        1.9245

  A strong confounder would be needed.
```

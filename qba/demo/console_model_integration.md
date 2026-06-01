---
title: "console_model_integration"
---

## Model-based confounding correction

```stata
. quietly {
```

```stata
. quietly logistic disease exposure age female bmi
```

### Logistic model estimate

```stata
. qba_confound, from_model coef(exposure)
>     p1(.45) p0(.20) rrcd(2.1) evalue
```

```
Quantitative Bias Analysis: Unmeasured Confounding

  Observed OR:    2.7551
  95% CI:        2.0421 -    3.7171
  (from last estimation command)

Confounding parameters
  P(U=1 | E=1): 0.4500
  P(U=1 | E=0): 0.2000
  RR(C->D):     2.1000

Results
  Bias factor:        1.2254
  Corrected OR:     2.2483
  Ratio (corrected/observed): 0.8161

E-value (VanderWeele & Ding 2017)
  E-value (point):     4.9541
  E-value (CI):        3.5008

  A strong confounder would be needed.
```

```stata
. quietly regress biomarker exposure age female bmi
```

### Linear model coefficient

```stata
. qba_confound, from_model coef(exposure)
>     p1(.35) p0(.10) confeffect(4.5)
```

```
Quantitative Bias Analysis: Unmeasured Confounding

  Observed Coefficient:    7.4214
  95% CI:        6.4880 -    8.3548
  (from last estimation command)

Confounding parameters
  P(U=1 | E=1): 0.3500
  P(U=1 | E=0): 0.1000
  Confounder effect:    4.5000

Results
  Correction:    -1.1250
  Corrected Coefficient:     6.2964
```

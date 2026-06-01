---
title: "console_overview"
---

## Package overview

```stata
. qba
```

```
qba - Quantitative Bias Analysis for Epidemiologic Data
Version 1.1.2 (2026-05-05)
Available commands:
  qba_misclass - Misclassification bias analysis
      Corrects 2x2 tables for exposure or outcome
      misclassification (nondifferential or differential)
  qba_selection - Selection bias analysis
      Corrects 2x2 tables using selection probabilities
  qba_confound - Unmeasured confounding analysis
      Corrects estimates for unmeasured confounders
      with optional E-value computation
  qba_multi - Multi-bias analysis
      Chains multiple bias corrections in one
      Monte Carlo simulation framework
  qba_plot - Visualization
      Tornado, distribution, and tipping point plots
Analysis modes:
  - qba_misclass, qba_selection, and qba_confound support
    simple fixed-parameter and probabilistic Monte Carlo analysis
  - qba_multi is Monte Carlo only
Based on: Lash TL, Fox MP, Fink AK. Applying Quantitative
Bias Analysis to Epidemiologic Data. 2nd ed. Springer; 2021.
```

```stata
. display as text ""
```

```stata
. display as text "Demo scenario: pesticide exposure and cancer case-control study"
```

```
Demo scenario: pesticide exposure and cancer case-control study
```

```stata
. display as text "  Exposed cases:      " as result %9.0fc 136
```

```
  Exposed cases:            136
```

```stata
. display as text "  Unexposed cases:    " as result %9.0fc 297
```

```
  Unexposed cases:          297
```

```stata
. display as text "  Exposed controls:   " as result %9.0fc 1432
```

```
  Exposed controls:       1,432
```

```stata
. display as text "  Unexposed controls: " as result %9.0fc 6738
```

```
  Unexposed controls:     6,738
```

```stata
. display as text "  Observed OR:        " as result %9.2f 2.15
```

```
  Observed OR:             2.15
```

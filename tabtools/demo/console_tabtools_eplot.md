---
title: "console_tabtools_eplot"
---

## tabtools + eplot integration

<!-- * The same effect estimates feed both a publication table and a forest plot. -->

<!-- * regtab builds the odds-ratio table and, with eplotframe(), stores a -->

<!-- * graph-ready companion frame that eplot reads directly. -->

### Adjusted odds-ratio table (regtab)

```stata
. collect clear
```

```stata
. quietly collect: logistic cv_event treated index_age female diabetes hypertension prior_cvd
```

```stata
. noisily regtab, coef("OR") noint eplotframe(or_effects, replace) display
```

```
  +-----------------------------------------------+
  |                Model                          |
  |                   OR         95% CI   p-value |
  |      Treated    1.03   (0.96, 1.10)      0.38 |
  | Age at index    1.00   (1.00, 1.01)     0.035 |
  |   Female sex    1.01   (0.94, 1.08)      0.84 |
  |-----------------------------------------------|
  |     Diabetes    1.11   (1.04, 1.19)     0.002 |
  | Hypertension    1.01   (0.94, 1.08)      0.84 |
  |    Prior CVD    1.04   (0.97, 1.12)      0.23 |
  +-----------------------------------------------+


```

### Model comparison table (comptab)

<!-- * Crude and adjusted treatment effects, each captured as a regtab frame, then -->

<!-- * combined with comptab. The composite carries its own eplot companion frame. -->

```stata
. collect clear
```

```stata
. quietly collect: logistic cv_event treated
```

```stata
. quietly regtab, coef("OR") noint frame(m_crude, replace) eplotframe(e_crude, replace)
```

```stata
. collect clear
```

```stata
. quietly collect: logistic cv_event treated index_age female diabetes hypertension prior_cvd
```

```stata
. quietly regtab, coef("OR") noint frame(m_adj, replace) eplotframe(e_adj, replace)
```

```stata
. noisily comptab m_crude m_adj, rows(1 \ 1)
>     section("Crude" \ "Adjusted")
>     title("Treatment effect across specifications")
>     display
```

```
Treatment effect across specifications
  +-------------------------------------------+
  |            Model                          |
  |               OR         95% CI   p-value |
  |    Crude                                  |
  |  Treated    1.03   (0.96, 1.11)      0.36 |
  | Adjusted                                  |
  |-------------------------------------------|
  |  Treated    1.03   (0.96, 1.10)      0.38 |
  +-------------------------------------------+


```

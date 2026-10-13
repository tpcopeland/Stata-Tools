---
title: "console_results"
---

## Fit, tabulate and predict

```stata
. collect clear
```

```stata
. noisily collect: msm_fit, model(logistic) outcome_cov(age sex)
>     period_spec(quadratic) nolog
```

```
----------------------------------------------------------------------
msm_fit - Weighted Outcome Model
----------------------------------------------------------------------

Model type:       logistic
Outcome:          outcome
Treatment var:    treatment
Period spec:      quadratic
Treatment history: none (current-treatment-only; assumes no carryover)
Covariates:       age sex
Weight var:       _msm_weight
SE type:          cluster
Cluster var:      id

Fitting pooled logistic regression...


Generalized linear models                         Number of obs   =      4,537
Optimization     : ML                             Residual df     =      4,531
                                                  Scale parameter =          1
Deviance         =  515.2905984                   (1/df) Deviance =   .1137256
Pearson          =  4575.829174                   (1/df) Pearson  =   1.009894

Variance function: V(u) = u*(1-u)                 [Bernoulli]
Link function    : g(u) = ln(u/(1-u))             [Logit]

                                                  AIC             =   .1162201
Log pseudolikelihood = -257.6452992               BIC             =  -37635.83

                                     (Std. err. adjusted for 500 clusters in id)
--------------------------------------------------------------------------------
               |               Robust
       outcome | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
---------------+----------------------------------------------------------------
     treatment |  -.2662234    .335203    -0.79   0.427    -.9232092    .3907624
        period |  -.0300596   .1902854    -0.16   0.874    -.4030121    .3428928
_msm_period_sq |   .0134486   .0216252     0.62   0.534    -.0289361    .0558332
           age |   .0515743   .0158195     3.26   0.001     .0205686      .08258
           sex |  -.0919971   .3295391    -0.28   0.780    -.7378818    .5538877
         _cons |  -7.614846   .9771727    -7.79   0.000     -9.53007   -5.699623
--------------------------------------------------------------------------------

----------------------------------------------------------------------
Treatment effect (MSM causal estimate):
  Log-odds:     -0.2662 (SE:  0.3352)
  Odds ratio:    0.7663 (95% CI:  0.3972 -  1.4781)
  p-value:       0.4271

Note: standard errors are final-stage, conditional on the estimated IP
      weights and the observed sample; they do not propagate weight-model
      estimation uncertainty (see help msm_fit).

Next step: msm_predict for counterfactual predictions
State check: msm, status
----------------------------------------------------------------------

```

```stata
. noisily regtab, xlsx("`tables_xlsx'") sheet("Outcome model") coef(OR)
>     title("Weighted pooled logistic MSM")
```

```
Weighted pooled logistic MSM
  +------------------------------------------------------------+
  |                             Model                          |
  |                                OR         95% CI   p-value |
  | Treatment indicator (0/1)    0.77   (0.40, 1.48)      0.43 |
  |         Time period (0-9)    0.97   (0.67, 1.41)      0.87 |
  |            Period squared    1.01   (0.97, 1.06)      0.53 |
  |   Age at baseline (years)    1.05   (1.02, 1.09)     0.001 |
  |    Sex (0=Female, 1=Male)    0.91   (0.48, 1.74)      0.78 |
  +------------------------------------------------------------+

Exported 8 rows × 5 cols to msm_tables.xlsx, sheet Outcome model

```

### Standardized cumulative incidence and risk differences

```stata
. noisily msm_predict, times(1 3 5 7 9) difference samples(1000)
>     seed(12345) frame(pred, replace)
```

```
----------------------------------------------------------------------
msm_predict - Counterfactual Predictions
----------------------------------------------------------------------

Strategy:         both
Prediction type:  cum_inc
MC samples:       1000
Seed used:        12345
Confidence level: 95%
Risk difference:  Yes

Computing predictions...
Running 1000 Monte Carlo simulations...

----------------------------------------------------------------------
Cumulative Incidence Estimates (95% CI)
----------------------------------------------------------------------

Period   Never-treat  Always-treat          Diff
--------------------------------------------------
     1        0.0185        0.0142       -0.0043
        (0.0109-0.0334)  (0.0073-0.0314)  (-0.0158-0.0082)
     3        0.0369        0.0284       -0.0084
        (0.0245-0.0613)  (0.0169-0.0540)  (-0.0305-0.0153)
     5        0.0572        0.0443       -0.0129
        (0.0384-0.0937)  (0.0284-0.0762)  (-0.0480-0.0228)
     7        0.0822        0.0639       -0.0183
        (0.0561-0.1267)  (0.0421-0.1041)  (-0.0662-0.0309)
     9        0.1158        0.0906       -0.0252
        (0.0793-0.1766)  (0.0603-0.1493)  (-0.0911-0.0408)

Reference population: 500 individuals

Note: Monte Carlo intervals draw from the outcome-model covariance only.
      They condition on the estimated IP weights and the reference sample
      and do not propagate weight-model estimation.
----------------------------------------------------------------------
Predictions written to frame pred

```

```stata
. matrix RD = r(rd)
```

```stata
. matrix rownames RD = "Period 1" "Period 3" "Period 5" "Period 7" "Period 9"
```

```stata
. noisily effecttab, from(RD) effect("Risk difference") digits(3)
>     xlsx("`tables_xlsx'") sheet("Risk differences")
>     title("Always minus never treated")
```

```
Always minus never treated
  +--------------------------------------------------------+
  |            Risk difference            95% CI   p-value |
  | Period 1            -0.004   (-0.016, 0.008)           |
  | Period 3            -0.008   (-0.031, 0.015)           |
  | Period 5            -0.013   (-0.048, 0.023)           |
  | Period 7            -0.018   (-0.066, 0.031)           |
  | Period 9            -0.025   (-0.091, 0.041)           |
  +--------------------------------------------------------+

Exported 8 rows × 5 cols to msm_tables.xlsx, sheet Risk differences

```

### E-value for unmeasured confounding

```stata
. noisily qba_confound, from_model coef(treatment) evalue measure(HR)
```

```
Quantitative Bias Analysis: Unmeasured Confounding

  Observed HR:    0.7663
  95% CI:        0.3972 -    1.4781
  (from last estimation command)


E-value (VanderWeele & Ding 2017)
  Scale: HR used directly as a risk ratio; Table 2 permits this only for a
         rare outcome (<15% by end of follow-up). For a common outcome
         specify commonoutcome; the E-value below is otherwise too large.
  E-value (point):     1.9360
  E-value (CI):        1.0000

  Interpret against the confounder-treatment and
  confounder-outcome associations that are plausible here;
  the E-values of the measured covariates are the natural
  comparison (VanderWeele & Ding 2017, Table 3).

```

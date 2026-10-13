---
title: "console_pipeline"
---

## Prepare, weight and diagnose

```stata
. noisily msm_prepare, id(id) period(period) treatment(treatment)
>     outcome(outcome) censor(censored)
>     covariates(biomarker comorbidity) baseline_covariates(age sex)
```

```
----------------------------------------------------------------------
msm_prepare - Data Preparation
----------------------------------------------------------------------

Variable mapping:
  ID:          id
  Period:      period (range: 0 to 9)
  Treatment:   treatment
  Outcome:     outcome
  Censoring:   censored
  Covariates:  biomarker comorbidity
  Baseline:    age sex

Data summary:
  Observations:          4,586
  Individuals:             500
  Period range:     0 - 9
  Treated obs:           1,681
  Outcome events:           47
  Censored obs:             49

Metadata stored. Next step: msm_weight
----------------------------------------------------------------------

```

```stata
. noisily msm_weight, treat_d_cov(biomarker comorbidity age sex)
>     treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex)
>     censor_n_cov(age sex) truncate(1 99) nolog
```

```
----------------------------------------------------------------------
msm_weight - Inverse Probability Weights
----------------------------------------------------------------------

Treatment denom:  biomarker comorbidity age sex
Treatment numer:  age sex
Treatment models:
  Denominator:    treatment ~ lagged treatment biomarker comorbidity age sex period
  First period:   treatment ~ biomarker comorbidity age sex
  Numerator:      treatment ~ lagged treatment age sex
  First period:   treatment ~ age sex
Censoring denom:  biomarker comorbidity age sex
Censoring numer:  age sex
Censoring models:
  Denominator:    censored ~ treatment biomarker comorbidity age sex period
  Numerator:      censored ~ treatment age sex
Stabilized:       Yes
Period basis:     denominator linear, numerator none
Model-fit policy: Stop (default)
Probability policy: Reject (default; no repair)
Truncation:       1st - 99th percentile

Fitting treatment models...
  Denominator model: treatment ~ lagged treatment biomarker comorbidity age sex period
  Numerator model:   treatment ~ lagged treatment age sex

Fitting censoring models...
  Denominator model: censored ~ treatment biomarker comorbidity age sex period
  Numerator model:   censored ~ treatment age sex

Truncating weights at 1st and 99th percentiles...
  Truncated 90 observations (45 low, 45 high)

Weight distribution:
  Mean:        0.9803
  SD:          0.3758
  Min:         0.3552
  Median:      0.9316
  Max:         2.7933
  P1:          0.3552
  P99:         2.7933

Effective sample size:    3998.5 (decision-risk rows only)

Variables created: _msm_weight _msm_tw_weight _msm_cw_weight _msm_ps
Next step: msm_diagnose, msm_fit, or psdash combined
----------------------------------------------------------------------

```

### Per-period weights and overlap (psdash reads the msm contract)

```stata
. noisily psdash combined
```

```
Longitudinal Propensity Score Diagnostics
Source:        msm
Contract:      1.1
ID variable:   id
Period:        period
Treatment:     treatment
PS variable:   _msm_ps
Weight var:    _msm_weight (analysis weight used by msm_fit)
Estimand:      ATE
Risk set:      _msm_decision_risk (0 row(s) outside excluded)
Obs:                4,586
Periods:               10

-------------------------------------------------------------------------------------------
Per-Period Propensity Score Overlap
-------------------------------------------------------------------------------------------
    Period        N  Treated  Control     Mean T     Mean C      Lower      Upper     % out
-------------------------------------------------------------------------------------------
         0      500      110      390     0.2448     0.2130     0.0969     0.4152      2.20
         1      496      152      344     0.4197     0.2835     0.1357     0.7762      1.01
         2      484      178      306     0.4410     0.3103     0.1470     0.8075      3.10
         3      473      180      293     0.4763     0.3220     0.1251     0.7557      2.75
         4      460      186      274     0.4746     0.3277     0.1258     0.7945      2.39
         5      456      183      273     0.5067     0.3322     0.1165     0.7960      1.75
         6      444      183      261     0.4894     0.3514     0.0984     0.8150      0.90
         7      434      179      255     0.5171     0.3286     0.1067     0.7711      2.76
         8      426      167      259     0.5094     0.3371     0.1344     0.8065      4.69
         9      413      163      250     0.4973     0.3345     0.1541     0.8348      7.51
-------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------
Contract Weight Distribution by Period
--------------------------------------------------------------------------------------------------------
    Period        N       Mean         SD        P95        P99        Max     ESS%    ESS% T    ESS% C
--------------------------------------------------------------------------------------------------------
         0      500     0.9967     0.1386     1.2415     1.5322     1.7797    98.11     94.10     99.28
         1      496     1.0011     0.2258     1.3955     1.8754     2.4228    95.17     91.68     97.16
         2      484     0.9861     0.2637     1.5084     1.9214     2.4935    93.34     92.37     93.92
         3      473     0.9902     0.3301     1.5478     2.5279     2.7933    90.02     86.75     93.22
         4      460     0.9822     0.3784     1.7125     2.7933     2.7933    87.10     83.18     90.11
         5      456     0.9707     0.4098     1.6801     2.7933     2.7933    84.90     80.70     88.55
         6      444     0.9766     0.4406     1.8143     2.7933     2.7933    83.12     80.65     84.88
         7      434     0.9625     0.4736     1.9118     2.7933     2.7933    80.55     77.37     82.78
         8      426     0.9623     0.4824     1.9491     2.7933     2.7933    79.96     80.40     79.78
         9      413     0.9670     0.4995     1.9847     2.7933     2.7933    78.98     80.06     78.31
--------------------------------------------------------------------------------------------------------

-------------------------------------------------------
Overall Contract Weight Summary
-------------------------------------------------------
Mean:              0.9803
SD:                0.3758
Min/Max:           0.3552 /     2.7933
P1/P5:             0.3552 /     0.5060
P50/P95/P99:       0.9316 /     1.6517 /     2.7933
CV:                0.3834
ESS:              3,998.5 ( 87.2%)
Weights >10:            0 (  0.0%)
-------------------------------------------------------

Longitudinal support: PASS (10 estimable period(s))

```

### Balance by period and prior treatment, censoring balance, positivity

```stata
. noisily msm_diagnose, threshold(0.1)
```

```
----------------------------------------------------------------------
msm_diagnose - Longitudinal Balance and Positivity
----------------------------------------------------------------------
Weight distributions: psdash weights / psdash combined, wvar(_msm_weight)

Primary treatment balance: period x prior-treatment history
  Rows: 76; covariate numbers follow balance_covariates() order.
  target=0 identifies stabilized-numerator covariates retained in the target distribution.
Separate censoring balance: period-specific risk sets
  Rows: 40

Secondary pooled person-period balance (risk set)

           Covariate    Unweighted      Weighted    Change
----------------------------------------------------------
           biomarker        0.3954        0.0003    -99.9%
         comorbidity        0.1706       -0.0206    -87.9%
                 age        0.1283        0.1370      6.8% (numerator)
                 sex        0.1154        0.1159      0.4% (numerator)
----------------------------------------------------------
Threshold: |SMD| < .1
(numerator): stabilized-numerator covariate; not a balance target
Balanced:   2/2 balance target(s)

----------------------------------------------------------------------

```

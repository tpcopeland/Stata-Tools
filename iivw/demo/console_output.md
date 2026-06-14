---
title: "console_output"
---

## Package overview

```stata
. iivw
```

```
----------------------------------------------------------------------
iivw - Visit Weighting and Diagnostic Workflow for Stata
Version 1.5.3
----------------------------------------------------------------------

Commands
  iivw_weight     - Compute IIW/IPTW/FIPTIW weights
  iivw_balance    - Check weight leverage and visit-model balance
  iivw_fit        - Fit weighted or unweighted outcome model
  iivw_exogtest   - Test whether lagged outcomes predict visit timing
  iivw_diagnose   - Decompose marginal-slope movement across models

Weight types
  IIW     - Inverse intensity weighting (visit process correction)
  IPTW    - Inverse probability of treatment weighting
  FIPTIW  - Fully inverse probability of treatment and intensity
            weighting (IIW x IPTW)

Typical diagnostic workflow

  1. iivw_fit, unweighted  Fit baseline unweighted outcome model
  2. iivw_weight           Estimate weights from visit/treatment models
  3. iivw_balance          Check leverage and visit-model balance
  4. iivw_fit              Fit weighted and artifact-adjusted models
  5. iivw_exogtest         Check measurement-process exogeneity
  6. iivw_diagnose         Summarize sampling/artifact movement

Example

  iivw_weight, id(id) time(days) ///
      visit_cov(edss relapse) ///
      treat(treated) treat_cov(age sex edss_bl) ///
      truncate(1 99) nolog

  iivw_fit edss treated age sex edss_bl, ///
      model(gee) family(gaussian) timespec(linear)

Help:  iivw  for documentation
       iivw_weight  for weight computation
       iivw_balance  for balance diagnostics
       iivw_fit  for outcome model
       iivw_exogtest  for timing exogeneity diagnostics
       iivw_diagnose  for diagnostic decomposition
----------------------------------------------------------------------

```

## Synthetic SDMT-like panel

```stata
. quietly egen byte _idtag = tag(id)
```

```stata
. count
```

```
  1,860

```

```stata
. count if _idtag
```

```
  320

```

```stata
. tabulate tx if _idtag
```

```
  Treatment |
      group |      Freq.     Percent        Cum.
------------+-----------------------------------
   RTX-like |        157       49.06       49.06
   NTZ-like |        163       50.94      100.00
------------+-----------------------------------
      Total |        320      100.00

```

```stata
. summarize years testno sdmt practice
```

```
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
       years |      1,860    1.344484    .9287128          0       4.13
      testno |      1,860    3.672581    2.052774          1          9
        sdmt |      1,860    52.95464     6.61241   33.25691   72.17889
    practice |      1,860    3.885636    1.253386   1.871497    6.21698

```

```stata
. drop _idtag
```

## Step 1: unweighted outcome model

```stata
. iivw_fit sdmt tx years tx_years relapse
>     age female edss0 dur naive sdmt0,
>     unweighted id(id) time(years) timespec(none) nolog
```

```
----------------------------------------------------------------------
iivw_fit - Unweighted Outcome Model
----------------------------------------------------------------------

Model type:       gee
Outcome:          sdmt
Predictors:        tx years tx_years relapse age female edss0 dur naive sdmt0
Time spec:        none
Family:           gaussian
Estimation:       GLM with clustered robust SEs
Weight var:       (none, unweighted)
Cluster var:      id

Fitting unweighted GEE model...


Generalized linear models                         Number of obs   =      1,860
Optimization     : ML                             Residual df     =      1,849
                                                  Scale parameter =   5.564421
Deviance         =  10288.61431                   (1/df) Deviance =   5.564421
Pearson          =  10288.61431                   (1/df) Pearson  =   5.564421

Variance function: V(u) = 1                       [Gaussian]
Link function    : g(u) = u                       [Identity]

                                                  AIC             =   4.560166
Log pseudolikelihood = -4229.954764               BIC             =  -3631.271

                                   (Std. err. adjusted for 320 clusters in id)
------------------------------------------------------------------------------
             |               Robust
        sdmt | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
          tx |   .3178287   .1975263     1.61   0.108    -.0693158    .7049732
       years |   .7261898   .0859667     8.45   0.000     .5576981    .8946814
    tx_years |   .7212067   .1193894     6.04   0.000     .4872077    .9552056
     relapse |  -.2645223   .1418538    -1.86   0.062    -.5425505     .013506
         age |  -.0085815   .0084376    -1.02   0.309    -.0251188    .0079559
      female |  -.1144725   .1147128    -1.00   0.318    -.3393055    .1103605
       edss0 |  -.3687794   .0629538    -5.86   0.000    -.4921666   -.2453921
         dur |  -.0116459   .0155437    -0.75   0.454     -.042111    .0188191
       naive |   .0958745   .1127414     0.85   0.395    -.1250946    .3168436
       sdmt0 |   .9975131   .0099789    99.96   0.000     .9779548    1.017071
       _cons |   3.541114   .6964217     5.08   0.000     2.176152    4.906075
------------------------------------------------------------------------------

----------------------------------------------------------------------
Unweighted effects:

             Variable       Coef.         SE            95% CI       P
----------------------------------------------------------------------
            Intercept      3.5411     0.6964   2.1762, 4.9061   <0.001
      Treatment group      0.3178     0.1975  -0.0693, 0.7050    0.108
   Years since trea..      0.7262     0.0860   0.5577, 0.8947   <0.001
    Treatment x years      0.7212     0.1194   0.4872, 0.9552   <0.001
       Recent relapse     -0.2645     0.1419  -0.5426, 0.0135    0.062
   Age at treatment..     -0.0086     0.0084  -0.0251, 0.0080    0.309
               Female     -0.1145     0.1147  -0.3393, 0.1104    0.318
        Baseline EDSS     -0.3688     0.0630  -0.4922,-0.2454   <0.001
     Disease duration     -0.0116     0.0155  -0.0421, 0.0188    0.454
      Treatment-naive      0.0959     0.1127  -0.1251, 0.3168    0.395
        Baseline SDMT      0.9975     0.0100   0.9780, 1.0171   <0.001
----------------------------------------------------------------------

```

```stata
. estimates store M_unweighted
```

## Step 2: FIPTIW weights and leverage diagnostics

```stata
. iivw_weight,
>     id(id) time(years)
>     visit_cov(tx age female edss0 sdmt0 dur naive)
>     lagvars(sdmt relapse)
>     treat(tx)
>     treat_cov(age female edss0 sdmt0 dur naive)
>     stabcov(tx)
>     truncate(1 99) efron replace nolog
```

```
----------------------------------------------------------------------
iivw_weight - FIPTIW Weight Computation
----------------------------------------------------------------------

ID variable:      id
Time variable:    years
Visit covariates: tx age female edss0 sdmt0 dur naive  sdmt_lag1 relapse_lag1
Treatment:        tx
Treatment covars: age female edss0 sdmt0 dur naive
Weight type:      FIPTIW
Truncation:       1th - 99th percentile

Fitting visit intensity model (Andersen-Gill Cox)...
  Visit model: stcox tx age female edss0 sdmt0 dur naive  sdmt_lag1 relapse_lag1

Survival-time data settings

           ID variable: id
         Failure event: __00000B!=0 & __00000B<.
Observed time interval: (__00000A[_n-1], __00000A]
     Enter on or after: time __000009
     Exit on or before: time .

--------------------------------------------------------------------------
      1,860  total observations
        320  observations end on or before enter()
--------------------------------------------------------------------------
      1,540  observations remaining, representing
        320  subjects
      1,540  failures in multiple-failure-per-subject data
     783.13  total analysis time at risk and under observation
                                                At risk from t =         0
                                     Earliest observed entry t =         0
                                          Last observed exit t =      4.13

         Failure _d: __00000B
   Analysis time _t: __00000A
  Enter on or after: time __000009
  Exit on or before: time .
        ID variable: id

Cox regression with Efron method for ties

No. of subjects =    320                                Number of obs =  1,540
No. of failures =  1,540
Time at risk    = 783.13
                                                        LR chi2(9)    = 171.19
Log likelihood = -8254.4622                             Prob > chi2   = 0.0000

------------------------------------------------------------------------------
          _t | Haz. ratio   Std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
          tx |   2.039861   .1199548    12.12   0.000     1.817797    2.289052
         age |   .9994888   .0038201    -0.13   0.894     .9920296    1.007004
      female |   .9623767    .052315    -0.71   0.481     .8651144    1.070574
       edss0 |   .8693846   .0276057    -4.41   0.000     .8169276      .92521
       sdmt0 |   1.051569   .0121953     4.34   0.000     1.027937    1.075745
         dur |   .9992395   .0076975    -0.10   0.921     .9842661    1.014441
       naive |   .9966408   .0540481    -0.06   0.951      .896144    1.108408
   sdmt_lag1 |   .9493935   .0102915    -4.79   0.000     .9294354    .9697802
relapse_lag1 |   .9674988   .0632921    -0.51   0.614      .851072    1.099853
------------------------------------------------------------------------------
(320 missing values generated)
  Stabilization model: stcox tx

         Failure _d: __00000B
   Analysis time _t: __00000A
  Enter on or after: time __000009
  Exit on or before: time .
        ID variable: id

Cox regression with Efron method for ties

No. of subjects =    320                                Number of obs =  1,540
No. of failures =  1,540
Time at risk    = 783.13
                                                        LR chi2(1)    = 131.70
Log likelihood = -8274.2097                             Prob > chi2   = 0.0000

------------------------------------------------------------------------------
          _t | Haz. ratio   Std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
          tx |   1.840339   .1005502    11.16   0.000     1.653449    2.048353
------------------------------------------------------------------------------
(320 missing values generated)
note: 320 subjects have missing visit model covariates at first observation
  weight set to 1 by convention; check covariate completeness
(320 real changes made)
(file /tmp/St2688209.000001 not found)
file /tmp/St2688209.000001 saved as .dta format

    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                             1,860
    -----------------------------------------
Fitting treatment model (logistic)...
  Treatment model: logit tx age female edss0 sdmt0 dur naive

Logistic regression                                     Number of obs =    320
                                                        LR chi2(6)    =  19.44
                                                        Prob > chi2   = 0.0035
Log likelihood = -212.02983                             Pseudo R2     = 0.0438

------------------------------------------------------------------------------
          tx | Coefficient  Std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
         age |  -.0511638   .0168062    -3.04   0.002    -.0841032   -.0182243
      female |    .011558   .2428638     0.05   0.962    -.4644462    .4875623
       edss0 |   .2792362   .1374955     2.03   0.042     .0097499    .5487225
       sdmt0 |   .0117131   .0202938     0.58   0.564    -.0280619    .0514882
         dur |  -.0462497   .0341505    -1.35   0.176    -.1131835     .020684
       naive |  -.4647676   .2401882    -1.94   0.053    -.9355278    .0059925
       _cons |    1.39893   1.368537     1.02   0.307    -1.283353    4.081214
------------------------------------------------------------------------------
(file /tmp/St2688209.000003 not found)
file /tmp/St2688209.000003 saved as .dta format
Truncating weights at 1th and 99th percentiles...
  Truncated 37 observations (18 low, 19 high)

Weight distribution:
  Mean:        1.6460
  SD:          0.5582
  Min:         0.7033
  Median:      1.5758
  Max:         3.3275
  P1:          0.7033
  P99:         3.3275

Observations:               1860
Subjects:                    320
Effective sample size:    1668.2 (of 1860)

Note: weight mean is 1.646
  Consider checking model specification or using truncation.

Variables created: _iivw_ps _iivw_tw _iivw_iw _iivw_weight
Next step: iivw_fit to fit weighted outcome model
----------------------------------------------------------------------

```

```stata
. display as text "FIPTIW effective sample size: " as result %9.1f r(ess)
>     as text " of " as result %9.0f r(N)
```

```
FIPTIW effective sample size:    1668.2 of      1860

```

```stata
. summarize _iivw_weight _iivw_iw _iivw_ps _iivw_tw
```

```
    Variable |        Obs        Mean    Std. dev.       Min        Max
-------------+---------------------------------------------------------
_iivw_weight |      1,860    1.645994    .5582194   .7032949   3.327522
    _iivw_iw |      1,860    1.663965    .4195706   .9795081   2.908683
    _iivw_ps |      1,860    .5202407     .120732   .2091008   .7832389
    _iivw_tw |      1,860       .9942    .2437126   .6203382   1.835502

```

## Step 3: psdash treatment-propensity diagnostics from iivw metadata

```stata
. psdash combined, saving("`psdash_dashboard'")
```

```
Propensity Score Diagnostics Dashboard
Treatment:     tx
PS variable:   _iivw_ps
Covariates:    6
Weights:       _iivw_tw
Estimand:      ATE
Source:        iivw treatment model
Weight component: treatment IPTW (_iivw_tw)

=== OVERLAP DIAGNOSTICS ===

PS Overlap
Treatment:         tx
PS variable:       _iivw_ps

----------------------------------------------------------------------
Propensity Score Distribution
----------------------------------------------------------------------
                            Treated        Control
----------------------------------------------------------------------
                   N          1,186            674
                Mean         0.5420         0.4820
                  SD         0.1166         0.1184
                 Min         0.2775         0.2091
                 Max         0.7832         0.7298
----------------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.2775
Upper bound:               0.7298
Outside support:               90 ( 4.84%)
  Treated outside:             49
  Control outside:             41
C-statistic (AUC):         0.6334
-------------------------------------------------------

Overlap: Good ( 4.8% outside support)

=== BALANCE DIAGNOSTICS ===

Covariate Balance
Treatment:     tx
Estimand:      ATE
N (treated):        1,186
N (control):          674
Weights:       _iivw_tw
Threshold:      0.100


---------------------------------------------------------------------------------------
           Covariate |  SMD Raw  VR Raw  SMD Adj  VR Adj      Status
---------------------------------------------------------------------------------------
                 age |-0.366  0.79-0.055  0.79    Balanced
              female | 0.001  1.00 0.016  0.99    Balanced
               edss0 | 0.220  0.92 0.011  0.92    Balanced
               sdmt0 | 0.033  1.21-0.008  1.23    Balanced
                 dur |-0.107  0.90 0.046  1.14    Balanced
               naive |-0.231  0.91-0.034  0.99    Balanced
---------------------------------------------------------------------------------------


Maximum |SMD| (raw):       0.366
Maximum |SMD| (adjusted):  0.055
Maximum VR (raw):           0.79
Maximum VR (adjusted):      0.79
Covariates > SMD threshold:    0 of   6
---------------------------------------------------------------------------------------

Balance: Adequate (max |SMD| =  0.055)

=== WEIGHT DIAGNOSTICS ===

IPTW Weight Diagnostics
Weight variable:   _iivw_tw
Treatment:         tx
Observations:           1,860

----------------------------------------------------------------------
Weight Distribution Summary
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                        N          1,860          1,186            674
                     Mean          0.994          0.990          1.002
                       SD          0.244          0.240          0.249
                      Min          0.620          0.650          0.620
                      Max          1.836          1.836          1.816
----------------------------------------------------------------------

----------------------------------------------------------------------
Effective Sample Size (ESS)
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                      ESS         1754.6         1120.0          634.7
               ESS % of N          94.3%          94.4%          94.2%
----------------------------------------------------------------------

--------------------------------------------------
Extreme Weight Detection
--------------------------------------------------
Coefficient of Variation:    0.245
Weights > 10:                    0 ( 0.00%)
Weights > 20:                    0
--------------------------------------------------


Weights: Acceptable (ESS = 94.3% of N)

=== COMMON SUPPORT ASSESSMENT ===

Common Support
Treatment:         tx
PS variable:       _iivw_ps
Observations:           1,860

------------------------------------------------------------
Propensity Score Range
------------------------------------------------------------
                            Treated        Control
------------------------------------------------------------
                   N          1,186            674
              Min PS         0.2775         0.2091
              Max PS         0.7832         0.7298
------------------------------------------------------------

-------------------------------------------------------
Common Support Region
-------------------------------------------------------
Lower bound:               0.2775
Upper bound:               0.7298
Outside support:               90 ( 4.84%)
  Treated outside:             49
  Control outside:             41
-------------------------------------------------------

Support: Good ( 4.8% outside support)
(file iivw/demo/iivw_psdash_dashboard.png not found)
file iivw/demo/iivw_psdash_dashboard.png written in PNG format
Overall: PASS

```

```stata
. psdash weights, iivwcomponent(final) detail graph
>     saving("`psdash_final_weights'")
```

```
IPTW Weight Diagnostics
Weight variable:   _iivw_weight
Weight component:  final FIPTIW (_iivw_weight)
Treatment:         tx
Observations:           1,860
Source:            iivw final analysis weight

----------------------------------------------------------------------
Weight Distribution Summary
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                        N          1,860          1,186            674
                     Mean          1.646          1.650          1.640
                       SD          0.558          0.500          0.649
                      Min          0.703          0.703          0.703
                      Max          3.328          3.328          3.328
----------------------------------------------------------------------

--------------------------------------------------
Percentile Distribution (Overall)
--------------------------------------------------
     Percentile         Weight
--------------------------------------------------
             1%          0.703
             5%          0.823
            10%          0.956
            25%          1.273
   50% (median)          1.576
            75%          1.930
            90%          2.432
            95%          2.699
            99%          3.328
--------------------------------------------------

----------------------------------------------------------------------
Effective Sample Size (ESS)
----------------------------------------------------------------------
                                 Overall        Treated        Control
----------------------------------------------------------------------
                      ESS         1668.2         1086.4          582.9
               ESS % of N          89.7%          91.6%          86.5%
----------------------------------------------------------------------

--------------------------------------------------
Extreme Weight Detection
--------------------------------------------------
Coefficient of Variation:    0.339
Weights > 10:                    0 ( 0.00%)
Weights > 20:                    0
--------------------------------------------------


Weights: Acceptable (ESS = 89.7% of N)

```

```stata
. display as text "psdash dashboard export: " as result "`psdash_dashboard'"
```

```
psdash dashboard export: iivw/demo/iivw_psdash_dashboard.png

```

```stata
. display as text "psdash final-weight export: " as result "`psdash_final_weights'"
```

```
psdash final-weight export: iivw/demo/iivw_psdash_final_weights.png

```

```stata
. capture graph close _all
```

## Step 4: visit-intensity leverage diagnostics

```stata
. iivw_balance, nolog
>     xlsx("`export_xlsx'") sheet("Balance") replace
```

```
----------------------------------------------------------------------
iivw_balance - Visit-Model Balance Diagnostic
----------------------------------------------------------------------

Weight type:      FIPTIW
Weight variable:  _iivw_weight
Observations:          1860
Subjects:               320

Leverage
  Weight CV:          0.3391  (low if < 0.100)
  ESS/N:              0.8969  (low if > 0.950)
  Verdict:         moderate

Weighted vs unweighted covariate means
  Covariate             Unweighted   Weighted       SMD   Missing
                  tx      0.6376     0.6391    0.0030       0
                 age     39.6173    39.8660    0.0359       0
              female      0.6457     0.6496    0.0082       0
               edss0      2.2181     2.2839    0.0740       0
               sdmt0     49.0481    48.9014   -0.0246       0
                 dur      6.7202     6.7674    0.0140       0
               naive      0.3823     0.3998    0.0361       0
           sdmt_lag1     52.7207    52.8574    0.0209     320
        relapse_lag1      0.1961     0.2051    0.0226     320

  Balance flag:    good  (modeled covariates; abs(SMD) <= 0.100)
  Informative:     1
----------------------------------------------------------------------

```

```stata
. display as text "Balance export: " as result "xlsx() sheet Balance"
```

```
Balance export: xlsx() sheet Balance

```

## Step 5: weighted and artifact-adjusted outcome models

```stata
. iivw_fit sdmt tx years tx_years relapse
>     age female edss0 dur naive sdmt0,
>     model(gee) timespec(none) replace nolog
```

```
----------------------------------------------------------------------
iivw_fit - FIPTIW Weighted Outcome Model
----------------------------------------------------------------------

Model type:       gee
Outcome:          sdmt
Predictors:        tx years tx_years relapse age female edss0 dur naive sdmt0
Time spec:        none
Family:           gaussian
Estimation:       GLM with clustered robust SEs
Weight var:       _iivw_weight
Cluster var:      id

Fitting fiptiw GEE model...


Generalized linear models                         Number of obs   =      1,860
Optimization     : ML                             Residual df     =      1,849
                                                  Scale parameter =   9.005083
Deviance         =  16650.39835                   (1/df) Deviance =   9.005083
Pearson          =  16650.39835                   (1/df) Pearson  =   9.005083

Variance function: V(u) = 1                       [Gaussian]
Link function    : g(u) = u                       [Identity]

                                                  AIC             =   7.644748
Log pseudolikelihood = -7098.615815               BIC             =   2730.513

                                   (Std. err. adjusted for 320 clusters in id)
------------------------------------------------------------------------------
             |               Robust
        sdmt | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
          tx |   .2311747   .2116722     1.09   0.275    -.1836952    .6460447
       years |   .6565875   .0826139     7.95   0.000     .4946672    .8185079
    tx_years |   .7594853   .1193715     6.36   0.000     .5255214    .9934492
     relapse |  -.2197666   .1446013    -1.52   0.129    -.5031799    .0636467
         age |  -.0143187    .008855    -1.62   0.106    -.0316743    .0030368
      female |  -.1032842   .1212742    -0.85   0.394    -.3409772    .1344088
       edss0 |  -.3758552   .0649619    -5.79   0.000    -.5031781   -.2485323
         dur |  -.0076097   .0170261    -0.45   0.655    -.0409801    .0257608
       naive |   .1273284   .1185847     1.07   0.283    -.1050933    .3597502
       sdmt0 |   1.000138   .0104235    95.95   0.000     .9797084    1.020568
       _cons |   3.749029   .7405643     5.06   0.000      2.29755    5.200508
------------------------------------------------------------------------------

----------------------------------------------------------------------
FIPTIW-weighted effects:

             Variable       Coef.         SE            95% CI       P
----------------------------------------------------------------------
            Intercept      3.7490     0.7406   2.2975, 5.2005   <0.001
      Treatment group      0.2312     0.2117  -0.1837, 0.6460    0.275
   Years since trea..      0.6566     0.0826   0.4947, 0.8185   <0.001
    Treatment x years      0.7595     0.1194   0.5255, 0.9934   <0.001
       Recent relapse     -0.2198     0.1446  -0.5032, 0.0636    0.129
   Age at treatment..     -0.0143     0.0089  -0.0317, 0.0030    0.106
               Female     -0.1033     0.1213  -0.3410, 0.1344    0.394
        Baseline EDSS     -0.3759     0.0650  -0.5032,-0.2485   <0.001
     Disease duration     -0.0076     0.0170  -0.0410, 0.0258    0.655
      Treatment-naive      0.1273     0.1186  -0.1051, 0.3598    0.283
        Baseline SDMT      1.0001     0.0104   0.9797, 1.0206   <0.001
----------------------------------------------------------------------

```

```stata
. estimates store M_fiptiw
```

```stata
. gen double log_testno = log(testno + 1)
```

```stata
. label variable log_testno "log(test number + 1)"
```

```stata
. iivw_fit sdmt tx years tx_years relapse
>     age female edss0 dur naive sdmt0 log_testno,
>     model(gee) timespec(none) replace nolog
```

```
----------------------------------------------------------------------
iivw_fit - FIPTIW Weighted Outcome Model
----------------------------------------------------------------------

Model type:       gee
Outcome:          sdmt
Predictors:        tx years tx_years relapse age female edss0 dur naive sdmt0 log_testno
Time spec:        none
Family:           gaussian
Estimation:       GLM with clustered robust SEs
Weight var:       _iivw_weight
Cluster var:      id

Fitting fiptiw GEE model...


Generalized linear models                         Number of obs   =      1,860
Optimization     : ML                             Residual df     =      1,848
                                                  Scale parameter =   8.876102
Deviance         =  16403.03706                   (1/df) Deviance =   8.876102
Pearson          =  16403.03706                   (1/df) Pearson  =   8.876102

Variance function: V(u) = 1                       [Gaussian]
Link function    : g(u) = u                       [Identity]

                                                  AIC             =   7.621187
Log pseudolikelihood = -7075.703736               BIC             =    2490.68

                                   (Std. err. adjusted for 320 clusters in id)
------------------------------------------------------------------------------
             |               Robust
        sdmt | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
          tx |   .0178063   .2079942     0.09   0.932    -.3898547    .4254674
       years |  -.4832582   .2234694    -2.16   0.031    -.9212501   -.0452663
    tx_years |   .2953327   .1496032     1.97   0.048     .0021158    .5885496
     relapse |  -.1986081   .1438256    -1.38   0.167    -.4805012    .0832849
         age |  -.0160977   .0085438    -1.88   0.060    -.0328432    .0006478
      female |  -.0771353   .1173541    -0.66   0.511    -.3071451    .1528745
       edss0 |  -.2730485   .0686154    -3.98   0.000    -.4075323   -.1385648
         dur |  -.0067593   .0169242    -0.40   0.690    -.0399302    .0264116
       naive |   .1258104   .1143092     1.10   0.271    -.0982316    .3498524
       sdmt0 |   .9998546   .0103897    96.24   0.000     .9794912    1.020218
  log_testno |   3.163754   .5811332     5.44   0.000     2.024754    4.302754
       _cons |   1.068862   .9042124     1.18   0.237    -.7033622    2.841085
------------------------------------------------------------------------------

----------------------------------------------------------------------
FIPTIW-weighted effects:

             Variable       Coef.         SE            95% CI       P
----------------------------------------------------------------------
            Intercept      1.0689     0.9042  -0.7034, 2.8411    0.237
      Treatment group      0.0178     0.2080  -0.3899, 0.4255    0.932
   Years since trea..     -0.4833     0.2235  -0.9213,-0.0453    0.031
    Treatment x years      0.2953     0.1496   0.0021, 0.5885    0.048
       Recent relapse     -0.1986     0.1438  -0.4805, 0.0833    0.167
   Age at treatment..     -0.0161     0.0085  -0.0328, 0.0006    0.060
               Female     -0.0771     0.1174  -0.3071, 0.1529    0.511
        Baseline EDSS     -0.2730     0.0686  -0.4075,-0.1386   <0.001
     Disease duration     -0.0068     0.0169  -0.0399, 0.0264    0.690
      Treatment-naive      0.1258     0.1143  -0.0982, 0.3499    0.271
        Baseline SDMT      0.9999     0.0104   0.9795, 1.0202   <0.001
   log(test number ..      3.1638     0.5811   2.0248, 4.3028   <0.001
----------------------------------------------------------------------

```

```stata
. estimates store M_adjusted
```

## Step 6: exogeneity check and diagnostic decomposition

```stata
. iivw_exogtest sdmt relapse,
>     id(id) time(years)
>     adjust(age female edss0 sdmt0 dur naive)
>     by(tx) efron nolog
>     xlsx("`export_xlsx'") sheet("Exogeneity")
>     title("SDMT visit-timing exogeneity diagnostic")
>     footnote("Outcome-dependent visits; artifact adjustment is a sensitivity range.")
>     decimals(3)
```

```
Survival-time data settings

           ID variable: id
         Failure event: __000008!=0 & __000008<.
Observed time interval: (__000007[_n-1], __000007]
     Enter on or after: time __000006
     Exit on or before: time .
      Keep observations
                if exp: __000009

--------------------------------------------------------------------------
      1,860  total observations
        320  ignored at outset because of if exp
--------------------------------------------------------------------------
      1,540  observations remaining, representing
        320  subjects
      1,540  failures in multiple-failure-per-subject data
     783.13  total analysis time at risk and under observation
                                                At risk from t =         0
                                     Earliest observed entry t =         0
                                          Last observed exit t =      4.13

----------------------------------------------------------------------
iivw_exogtest - Exogeneity Diagnostic for Visit Timing
----------------------------------------------------------------------
ID variable:      id
Time variable:    years
Lagged tests:     _iivw_exog_sdmt_lag1 _iivw_exog_relapse_lag1
Adjustment:       age female edss0 sdmt0 dur naive
By variable:      tx
Alpha:            0.050

By group: tx = RTX-like
                Predictor           HR   CI lower   CI upper          p
----------------------------------------------------------------------
   Observed SDMT score (lag 1)    0.956     0.937      0.975     <0.001
   Recent relapse (lag 1)        1.043      0.923      1.179      0.501
----------------------------------------------------------------------
Joint test p-value:   0.0001
Interpretation: lagged predictors are associated with visit timing.
  Interpret cumulative-test adjustment as potentially endogenous.

By group: tx = NTZ-like
                Predictor           HR   CI lower   CI upper          p
----------------------------------------------------------------------
   Observed SDMT score (lag 1)    0.947     0.936      0.958     <0.001
   Recent relapse (lag 1)        0.957      0.897      1.020      0.175
----------------------------------------------------------------------
Joint test p-value:   0.0000
Interpretation: lagged predictors are associated with visit timing.
  Interpret cumulative-test adjustment as potentially endogenous.

----------------------------------------------------------------------
Models fitted:     2
Groups skipped:    0
Minimum p-value:     0.0000
Minimum joint p:     0.0000
Conclusion:        evidence that lagged predictors are associated with visit timing
----------------------------------------------------------------------

```

```stata
. display as text "Exogeneity export: " as result "xlsx() sheet `r(sheet)' decimals "
>     as result %2.0f r(decimals)
```

```
Exogeneity export: xlsx() sheet Exogeneity decimals  3

```

```stata
. local exo "exogenous"
```

```stata
. if r(endogenous_flag) local exo "endogenous"
```

```stata
. iivw_diagnose years,
>     unweighted(M_unweighted) weighted(M_fiptiw) adjusted(M_adjusted)
>     estimand(marginal) exogeneity(`exo')
>     excel("`export_xlsx'") sheet("Diagnostics") replace
```

```
IIVW diagnostic decomposition for marginal/reference slope: years

                       Model       Estimate          SE   95% CI
------------------------------------------------------------------------------
                  Unweighted         0.7262      0.0860      0.5577,   0.8947
                    Weighted         0.6566      0.0826      0.4947,   0.8185
    Weighted + artifact adj.        -0.4833      0.2235     -0.9213,  -0.0453
------------------------------------------------------------------------------

Diagnostic movement
Sampling gap:           0.0696
Artifact gap:           1.1398
Total gap:              1.2094

Sampling/artifact shares are not displayed because the measurement
adjustment is marked as potentially endogenous.

Because the measurement process appears outcome-dependent, the adjusted
model may over-correct. Treat the weighted and adjusted estimates as a
diagnostic range, not a point decomposition.
Plausible diagnostic range:   -0.4833 to    0.6566

```

```stata
. display as text "Diagnostic export: " as result "excel() sheet Diagnostics"
```

```
Diagnostic export: excel() sheet Diagnostics

```

## Step 7: categorical visit-wave interactions for regtab

```stata
. preserve
```

```stata
. keep if testno <= 4
```

```
(617 observations deleted)

```

```stata
. bysort id: gen byte _nvis_wave = _N
```

```stata
. keep if _nvis_wave >= 2
```

```
(0 observations deleted)

```

```stata
. drop _nvis_wave
```

```stata
. gen byte visit_wave = testno
```

```stata
. label variable visit_wave "Visit wave"
```

```stata
. label define visit_wave_demo 1 "Baseline" 2 "Month 6"
```

```
>     3 "Month 12" 4 "Month 18", replace

```

```stata
. label values visit_wave visit_wave_demo
```

```stata
. iivw_weight,
>     id(id) time(visit_wave)
>     visit_cov(tx age female edss0 sdmt0 dur naive relapse)
>     treat(tx)
>     treat_cov(age female edss0 sdmt0 dur naive)
>     stabcov(tx)
>     truncate(1 99) efron replace nolog
```

```
----------------------------------------------------------------------
iivw_weight - FIPTIW Weight Computation
----------------------------------------------------------------------

ID variable:      id
Time variable:    visit_wave
Visit covariates: tx age female edss0 sdmt0 dur naive relapse
Treatment:        tx
Treatment covars: age female edss0 sdmt0 dur naive
Weight type:      FIPTIW
Truncation:       1th - 99th percentile

Fitting visit intensity model (Andersen-Gill Cox)...
  Visit model: stcox tx age female edss0 sdmt0 dur naive relapse

Survival-time data settings

           ID variable: id
         Failure event: __00000B!=0 & __00000B<.
Observed time interval: (__00000A[_n-1], __00000A]
     Enter on or after: time __000009
     Exit on or before: time .

--------------------------------------------------------------------------
      1,243  total observations
          0  exclusions
--------------------------------------------------------------------------
      1,243  observations remaining, representing
        320  subjects
      1,243  failures in multiple-failure-per-subject data
      1,243  total analysis time at risk and under observation
                                                At risk from t =         0
                                     Earliest observed entry t =         0
                                          Last observed exit t =         4

         Failure _d: __00000B
   Analysis time _t: __00000A
  Enter on or after: time __000009
  Exit on or before: time .
        ID variable: id

Cox regression with Efron method for ties

No. of subjects =   320                                 Number of obs =  1,243
No. of failures = 1,243
Time at risk    = 1,243
                                                        LR chi2(8)    =   0.00
Log likelihood = -5907.4017                             Prob > chi2   = 1.0000

------------------------------------------------------------------------------
          _t | Haz. ratio   Std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
          tx |          1   .0585434    -0.00   1.000     .8915953    1.121585
         age |          1   .0041568    -0.00   1.000      .991886     1.00818
      female |          1   .0598461     0.00   1.000     .8893218    1.124452
       edss0 |          1   .0338953    -0.00   1.000     .9357251     1.06869
       sdmt0 |          1    .004979     0.00   1.000     .9902888    1.009806
         dur |          1   .0084048     0.00   1.000     .9836618     1.01661
       naive |          1   .0594587    -0.00   1.000     .8899973    1.123599
     relapse |          1   .0724163    -0.00   1.000     .8676791      1.1525
------------------------------------------------------------------------------
  Stabilization model: stcox tx

         Failure _d: __00000B
   Analysis time _t: __00000A
  Enter on or after: time __000009
  Exit on or before: time .
        ID variable: id

Cox regression with Efron method for ties

No. of subjects =   320                                 Number of obs =  1,243
No. of failures = 1,243
Time at risk    = 1,243
                                                        LR chi2(1)    =   0.00
Log likelihood = -5907.4017                             Prob > chi2   = 1.0000

------------------------------------------------------------------------------
          _t | Haz. ratio   Std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
          tx |          1    .056885     0.00   1.000      .894498    1.117946
------------------------------------------------------------------------------
(320 real changes made)
(file /tmp/St2688209.000002 not found)
file /tmp/St2688209.000002 saved as .dta format

    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                             1,243
    -----------------------------------------
Fitting treatment model (logistic)...
  Treatment model: logit tx age female edss0 sdmt0 dur naive

Logistic regression                                     Number of obs =    320
                                                        LR chi2(6)    =  19.44
                                                        Prob > chi2   = 0.0035
Log likelihood = -212.02983                             Pseudo R2     = 0.0438

------------------------------------------------------------------------------
          tx | Coefficient  Std. err.      z    P>|z|     [95% conf. interval]
-------------+----------------------------------------------------------------
         age |  -.0511638   .0168062    -3.04   0.002    -.0841032   -.0182243
      female |    .011558   .2428638     0.05   0.962    -.4644462    .4875623
       edss0 |   .2792362   .1374955     2.03   0.042     .0097499    .5487225
       sdmt0 |   .0117131   .0202938     0.58   0.564    -.0280619    .0514882
         dur |  -.0462497   .0341505    -1.35   0.176    -.1131835     .020684
       naive |  -.4647676   .2401882    -1.94   0.053    -.9355278    .0059925
       _cons |    1.39893   1.368537     1.02   0.307    -1.283353    4.081214
------------------------------------------------------------------------------
(file /tmp/St2688209.000004 not found)
file /tmp/St2688209.000004 saved as .dta format
Truncating weights at 1th and 99th percentiles...
  Truncated 27 observations (12 low, 15 high)

Weight distribution:
  Mean:        0.9988
  SD:          0.2437
  Min:         0.6447
  Median:      0.9445
  Max:         1.7075
  P1:          0.6447
  P99:         1.7075

Observations:               1243
Subjects:                    320
Effective sample size:    1173.2 (of 1243)

Variables created: _iivw_ps _iivw_tw _iivw_iw _iivw_weight
Next step: iivw_fit to fit weighted outcome model
----------------------------------------------------------------------

```

```stata
. collect clear
```

```stata
. iivw_fit sdmt tx age female edss0 dur naive sdmt0 relapse,
>     model(gee) timespec(categorical) timebasecat(1)
>     categorical(tx) interaction(tx) replace nolog collect
```

```
----------------------------------------------------------------------
iivw_fit - FIPTIW Weighted Outcome Model
----------------------------------------------------------------------

Model type:       gee
Outcome:          sdmt
Predictors:        tx age female edss0 dur naive sdmt0 relapse
Time spec:        categorical
Interactions:     tx
Categorical:      tx
Family:           gaussian
Estimation:       GLM with clustered robust SEs
Weight var:       _iivw_weight
Cluster var:      id

Fitting fiptiw GEE model...


Generalized linear models                         Number of obs   =      1,243
Optimization     : ML                             Residual df     =      1,228
                                                  Scale parameter =   5.523623
Deviance         =  6783.009094                   (1/df) Deviance =   5.523623
Pearson          =  6783.009094                   (1/df) Pearson  =   5.523623

Variance function: V(u) = 1                       [Gaussian]
Link function    : g(u) = u                       [Identity]

                                                  AIC             =   4.554783
Log pseudolikelihood = -2815.797697               BIC             =  -1966.839

                                               (Std. err. adjusted for 320 clusters in id)
------------------------------------------------------------------------------------------
                         |               Robust
                    sdmt | Coefficient  std. err.      z    P>|z|     [95% conf. interval]
-------------------------+----------------------------------------------------------------
      _iivw_cat_ntz_like |   .3700799    .275793     1.34   0.180    -.1704645    .9106243
                     age |  -.0111889   .0098552    -1.14   0.256    -.0305047    .0081269
                  female |  -.0283099   .1429652    -0.20   0.843    -.3085164    .2518967
                   edss0 |  -.1991367   .0771785    -2.58   0.010    -.3504039   -.0478695
                     dur |  -.0153172   .0221315    -0.69   0.489    -.0586941    .0280597
                   naive |   .0349186   .1437519     0.24   0.808    -.2468301    .3166672
                   sdmt0 |   .9986082   .0119827    83.34   0.000     .9751224    1.022094
                 relapse |  -.1129314   .1807185    -0.62   0.532    -.4671332    .2412704
            _iivw_tcat_1 |   1.028891   .2724541     3.78   0.000     .4948908    1.562891
            _iivw_tcat_2 |   1.563186   .2788019     5.61   0.000     1.016744    2.109628
            _iivw_tcat_3 |    2.11844   .2751612     7.70   0.000     1.579133    2.657746
_iivw_ix_ntz_like_tcat_1 |  -.1226329   .3884583    -0.32   0.752    -.8839972    .6387314
_iivw_ix_ntz_like_tcat_2 |   -.088507    .369044    -0.24   0.810    -.8118198    .6348059
_iivw_ix_ntz_like_tcat_3 |   .3656814    .385371     0.95   0.343    -.3896319    1.120995
                   _cons |   2.908345   .8256661     3.52   0.000     1.290069    4.526621
------------------------------------------------------------------------------------------

----------------------------------------------------------------------
FIPTIW-weighted effects:

             Variable       Coef.         SE            95% CI       P
----------------------------------------------------------------------
            Intercept      2.9083     0.8257   1.2901, 4.5266   <0.001
   NTZ-like (vs. RT..      0.3701     0.2758  -0.1705, 0.9106    0.180
   Age at treatment..     -0.0112     0.0099  -0.0305, 0.0081    0.256
               Female     -0.0283     0.1430  -0.3085, 0.2519    0.843
        Baseline EDSS     -0.1991     0.0772  -0.3504,-0.0479    0.010
     Disease duration     -0.0153     0.0221  -0.0587, 0.0281    0.489
      Treatment-naive      0.0349     0.1438  -0.2468, 0.3167    0.808
        Baseline SDMT      0.9986     0.0120   0.9751, 1.0221   <0.001
       Recent relapse     -0.1129     0.1807  -0.4671, 0.2413    0.532
   Visit wave: Mont..      1.0289     0.2725   0.4949, 1.5629   <0.001
   Visit wave: Mont..      1.5632     0.2788   1.0167, 2.1096   <0.001
   Visit wave: Mont..      2.1184     0.2752   1.5791, 2.6577   <0.001
   NTZ-like x Visit..     -0.1226     0.3885  -0.8840, 0.6387    0.752
   NTZ-like x Visit..     -0.0885     0.3690  -0.8118, 0.6348    0.810
   NTZ-like x Visit..      0.3657     0.3854  -0.3896, 1.1210    0.343
----------------------------------------------------------------------

```

```stata
. local cat_time "`e(iivw_time_cat_vars)'"
```

```stata
. local cat_ix "`e(iivw_ix_vars)'"
```

```stata
. regtab, title("Treatment by visit wave") stats(n) relabel
```

```
Treatment by visit wave
  +------------------------------------------------------------------------+
  |                                       Model                            |
  |                                       Coef.           95% CI   p-value |
  |             NTZ-like (vs. RTX-like)    0.37    (-0.17, 0.91)      0.18 |
  |              Age at treatment start   -0.01    (-0.03, 0.01)      0.26 |
  |                              Female   -0.03    (-0.31, 0.25)      0.84 |
  |------------------------------------------------------------------------|
  |                       Baseline EDSS   -0.20   (-0.35, -0.05)     0.010 |
  |                    Disease duration   -0.02    (-0.06, 0.03)      0.49 |
  |                     Treatment-naive    0.03    (-0.25, 0.32)      0.81 |
  |                       Baseline SDMT    1.00     (0.98, 1.02)    <0.001 |
  |                      Recent relapse   -0.11    (-0.47, 0.24)      0.53 |
  |------------------------------------------------------------------------|
  |  Visit wave: Month 6 (vs. Baseline)    1.03     (0.49, 1.56)    <0.001 |
  | Visit wave: Month 12 (vs. Baseline)    1.56     (1.02, 2.11)    <0.001 |
  | Visit wave: Month 18 (vs. Baseline)    2.12     (1.58, 2.66)    <0.001 |
  |      NTZ-like x Visit wave: Month 6   -0.12    (-0.88, 0.64)      0.75 |
  |     NTZ-like x Visit wave: Month 12   -0.09    (-0.81, 0.63)      0.81 |
  |------------------------------------------------------------------------|
  |     NTZ-like x Visit wave: Month 18    0.37    (-0.39, 1.12)      0.34 |
  |                           Intercept    2.91     (1.29, 4.53)    <0.001 |
  |                        Observations   1,243                            |
  +------------------------------------------------------------------------+


```

```stata
. display as text "Generated categorical-time terms: " as result "`cat_time'"
```

```
Generated categorical-time terms: _iivw_tcat_1 _iivw_tcat_2 _iivw_tcat_3

```

```stata
. display as text "Generated treatment-by-wave terms: " as result "`cat_ix'"
```

```
Generated treatment-by-wave terms:  _iivw_ix_ntz_like_tcat_1 _iivw_ix_ntz_like_tcat_2 _iivw_ix_ntz_like_tcat_3

```

```stata
. foreach v of local cat_ix {
```

```
  2.     local ixlbl : variable label `v'
  3.     display as text "  `v': " as result `"`ixlbl'"'
  4. }
  _iivw_ix_ntz_like_tcat_1: NTZ-like x Visit wave: Month 6
  _iivw_ix_ntz_like_tcat_2: NTZ-like x Visit wave: Month 12
  _iivw_ix_ntz_like_tcat_3: NTZ-like x Visit wave: Month 18

```

```stata
. restore
```

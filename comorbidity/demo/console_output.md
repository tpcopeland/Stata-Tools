---
title: "console_output"
---

## Charlson Original With Collapse And Score Bands

```stata
. quietly {
```

```stata
. noisily comorbidity dx1 dx2, id(pid) charlson(original) collapse band
```

```
(note: condition pvd matched 0 observations)
(note: condition cvd matched 0 observations)
(note: condition dementia matched 0 observations)
(note: condition copd matched 0 observations)
(note: condition rheumatic matched 0 observations)
(note: condition peptic matched 0 observations)
(note: condition liver_mild matched 0 observations)
(note: condition dm_comp matched 0 observations)
(note: condition hemiplegia matched 0 observations)
(note: condition renal matched 0 observations)
(note: condition cancer matched 0 observations)
(note: condition liver_severe matched 0 observations)
(note: condition hiv matched 0 observations)
(note: mi and chf overlap in 1 obs, 100% of smaller group)

codescan: 17 conditions, 2 variables, N =          3 pid values

  Condition              Matches   Prevalence
  --------------------------------------------
  Myocardial Infarction        1        33.3%
  Congestive Heart Fai~        1        33.3%
  Peripheral Vascular ~        0         0.0%
  Cerebrovascular Dise~        0         0.0%
  Dementia                     0         0.0%
  Chronic Pulmonary Di~        0         0.0%
  Rheumatic Disease            0         0.0%
  Peptic Ulcer Disease         0         0.0%
  Mild Liver Disease           0         0.0%
  Diabetes without Com~        1        33.3%
  Diabetes with Compli~        0         0.0%
  Hemiplegia or Parapl~        0         0.0%
  Renal Disease                0         0.0%
  Any Malignancy               0         0.0%
  Moderate or Severe L~        0         0.0%
  Metastatic Solid Tum~        1        33.3%
  HIV/AIDS                     0         0.0%

  Collapsed to          3 unique pid values

comorbidity: charlson (original), N =          3
  score: mean =   3.00, range = [     0.00,      6.00]
  bands n (<0 / 0 / >0-<3 / 3-<5 / 5+):         0         1         0         1         1

```

```stata
. noisily list pid charlson mi chf dm_uncomp metastatic, noobs abbreviate(16)
```

```
  +----------------------------------------------------+
  | pid   charlson   mi   chf   dm_uncomp   metastatic |
  |----------------------------------------------------|
  |   1          3    1     1           1            0 |
  |   2          6    0     0           0            1 |
  |   3          0    0     0           0            0 |
  +----------------------------------------------------+

```

```stata
. noisily matrix list r(bands)
```

```
r(bands)[5,2]
                      n    percent
score_nega~e          0          0
      score0          1  33.333333
    score1_2          0          0
    score3_4          1  33.333333
  score5plus          1  33.333333

```

## Charlson Quan 2011 With Merge, Generate, And Replace

```stata
. quietly {
```

```stata
. noisily comorbidity dx1 dx2, id(pid) charlson(quan2011) merge generate(cmb_) replace
```

```
(note: condition cmb_pvd matched 0 observations)
(note: condition cmb_cvd matched 0 observations)
(note: condition cmb_dementia matched 0 observations)
(note: condition cmb_copd matched 0 observations)
(note: condition cmb_rheumatic matched 0 observations)
(note: condition cmb_peptic matched 0 observations)
(note: condition cmb_liver_mild matched 0 observations)
(note: condition cmb_dm_comp matched 0 observations)
(note: condition cmb_hemiplegia matched 0 observations)
(note: condition cmb_renal matched 0 observations)
(note: condition cmb_cancer matched 0 observations)
(note: condition cmb_liver_severe matched 0 observations)
(note: condition cmb_hiv matched 0 observations)
(note: cmb_mi and cmb_chf overlap in 1 obs, 100% of smaller group)

codescan: 17 conditions, 2 variables, N =          2 pid values

  Condition              Matches   Prevalence
  --------------------------------------------
  Myocardial Infarction        1        50.0%
  Congestive Heart Fai~        1        50.0%
  Peripheral Vascular ~        0         0.0%
  Cerebrovascular Dise~        0         0.0%
  Dementia                     0         0.0%
  Chronic Pulmonary Di~        0         0.0%
  Rheumatic Disease            0         0.0%
  Peptic Ulcer Disease         0         0.0%
  Mild Liver Disease           0         0.0%
  Diabetes without Com~        1        50.0%
  Diabetes with Compli~        0         0.0%
  Hemiplegia or Parapl~        0         0.0%
  Renal Disease                0         0.0%
  Any Malignancy               0         0.0%
  Moderate or Severe L~        0         0.0%
  Metastatic Solid Tum~        1        50.0%
  HIV/AIDS                     0         0.0%

  Merged patient-level indicators for          2 unique pid values

comorbidity: charlson (quan2011), N =          2
  score: mean =   4.00, range = [     2.00,      6.00]

```

```stata
. noisily list pid dx1 dx2 cmb_score cmb_mi cmb_chf cmb_dm_uncomp cmb_metastatic, noobs abbreviate(16)
```

```
  +----------------------------------------------------------------------------------+
  | pid    dx1   dx2   cmb_score   cmb_mi   cmb_chf   cmb_dm_uncomp   cmb_metastatic |
  |----------------------------------------------------------------------------------|
  |   1    I21   I50           2        1         1               1                0 |
  |   1   E119                 2        1         1               1                0 |
  |   2   C780                 6        0         0               0                1 |
  +----------------------------------------------------------------------------------+

```

## Elixhauser Van Walraven With Verbose Scanning

```stata
. quietly {
```

```stata
. noisily comorbidity dx1 dx2 dx3, id(pid) elixhauser(vanwalraven) collapse
>     generate(elx_) replace noisily
```

```
  elx_chf: 1 matches across 3 variables
  elx_arrhythmia: 0 matches across 3 variables
(note: condition elx_arrhythmia matched 0 observations)
  elx_valvular: 0 matches across 3 variables
(note: condition elx_valvular matched 0 observations)
  elx_pulmonary_circ: 0 matches across 3 variables
(note: condition elx_pulmonary_circ matched 0 observations)
  elx_pvd: 0 matches across 3 variables
(note: condition elx_pvd matched 0 observations)
  elx_htn_uncomp: 1 matches across 3 variables
  elx_htn_comp: 1 matches across 3 variables
  elx_paralysis: 0 matches across 3 variables
(note: condition elx_paralysis matched 0 observations)
  elx_neuro_other: 0 matches across 3 variables
(note: condition elx_neuro_other matched 0 observations)
  elx_copd: 0 matches across 3 variables
(note: condition elx_copd matched 0 observations)
  elx_dm_uncomp: 0 matches across 3 variables
(note: condition elx_dm_uncomp matched 0 observations)
  elx_dm_comp: 1 matches across 3 variables
  elx_hypothyroid: 0 matches across 3 variables
(note: condition elx_hypothyroid matched 0 observations)
  elx_renal: 0 matches across 3 variables
(note: condition elx_renal matched 0 observations)
  elx_liver: 0 matches across 3 variables
(note: condition elx_liver matched 0 observations)
  elx_pud: 0 matches across 3 variables
(note: condition elx_pud matched 0 observations)
  elx_hiv: 0 matches across 3 variables
(note: condition elx_hiv matched 0 observations)
  elx_lymphoma: 0 matches across 3 variables
(note: condition elx_lymphoma matched 0 observations)
  elx_metastatic: 1 matches across 3 variables
  elx_solid_tumor: 0 matches across 3 variables
(note: condition elx_solid_tumor matched 0 observations)
  elx_rheumatoid: 0 matches across 3 variables
(note: condition elx_rheumatoid matched 0 observations)
  elx_coagulopathy: 0 matches across 3 variables
(note: condition elx_coagulopathy matched 0 observations)
  elx_obesity: 1 matches across 3 variables
  elx_weight_loss: 0 matches across 3 variables
(note: condition elx_weight_loss matched 0 observations)
  elx_fluid_electrolyte: 0 matches across 3 variables
(note: condition elx_fluid_electrolyte matched 0 observations)
  elx_blood_loss_anemia: 0 matches across 3 variables
(note: condition elx_blood_loss_anemia matched 0 observations)
  elx_deficiency_anemia: 0 matches across 3 variables
(note: condition elx_deficiency_anemia matched 0 observations)
  elx_alcohol: 0 matches across 3 variables
(note: condition elx_alcohol matched 0 observations)
  elx_drug: 1 matches across 3 variables
  elx_psychoses: 0 matches across 3 variables
(note: condition elx_psychoses matched 0 observations)
  elx_depression: 1 matches across 3 variables
(note: elx_chf and elx_metastatic overlap in 1 obs, 100% of smaller group)
(note: elx_chf and elx_drug overlap in 1 obs, 100% of smaller group)
(note: elx_htn_uncomp and elx_htn_comp overlap in 1 obs, 100% of smaller group)
(note: elx_htn_uncomp and elx_dm_comp overlap in 1 obs, 100% of smaller group)
(note: elx_htn_comp and elx_dm_comp overlap in 1 obs, 100% of smaller group)
(note: elx_metastatic and elx_drug overlap in 1 obs, 100% of smaller group)
(note: elx_obesity and elx_depression overlap in 1 obs, 100% of smaller group)

codescan: 31 conditions, 3 variables, N =          3 pid values

  Condition              Matches   Prevalence
  --------------------------------------------
  Congestive Heart Fai~        1        33.3%
  Cardiac Arrhythmias          0         0.0%
  Valvular Disease             0         0.0%
  Pulmonary Circulatio~        0         0.0%
  Peripheral Vascular ~        0         0.0%
  Hypertension Uncompl~        1        33.3%
  Hypertension Complic~        1        33.3%
  Paralysis                    0         0.0%
  Other Neurological D~        0         0.0%
  Chronic Pulmonary Di~        0         0.0%
  Diabetes Uncomplicat~        0         0.0%
  Diabetes Complicated         1        33.3%
  Hypothyroidism               0         0.0%
  Renal Failure                0         0.0%
  Liver Disease                0         0.0%
  Peptic Ulcer Disease~        0         0.0%
  AIDS/HIV                     0         0.0%
  Lymphoma                     0         0.0%
  Metastatic Cancer            1        33.3%
  Solid Tumor Without ~        0         0.0%
  Rheumatoid Arthritis~        0         0.0%
  Coagulopathy                 0         0.0%
  Obesity                      1        33.3%
  Weight Loss                  0         0.0%
  Fluid and Electrolyt~        0         0.0%
  Blood Loss Anemia            0         0.0%
  Deficiency Anemia            0         0.0%
  Alcohol Abuse                0         0.0%
  Drug Abuse                   1        33.3%
  Psychoses                    0         0.0%
  Depression                   1        33.3%

  Collapsed to          3 unique pid values

comorbidity: elixhauser (vanwalraven), N =          3
  score: mean =   1.67, range = [    -7.00,     12.00]

```

```stata
. noisily list pid elx_score elx_chf elx_metastatic elx_drug elx_obesity
>     elx_depression elx_htn_comp elx_htn_uncomp elx_dm_comp elx_dm_uncomp,
>     noobs abbreviate(16)
```

```
  +-----------------------------------------------------------------------------------------------------+
  | pid | elx_score | elx_chf | elx_metastatic | elx_drug | elx_obesity | elx_depression | elx_htn_comp |
  |   1 |        12 |       1 |              1 |        1 |           0 |              0 |            0 |
  |-----------------------------------------------------------------------------------------------------|
  |          elx_htn_uncomp          |          elx_dm_comp          |          elx_dm_uncomp           |
  |                       0          |                    0          |                      0           |
  +-----------------------------------------------------------------------------------------------------+

  +-----------------------------------------------------------------------------------------------------+
  | pid | elx_score | elx_chf | elx_metastatic | elx_drug | elx_obesity | elx_depression | elx_htn_comp |
  |   2 |        -7 |       0 |              0 |        0 |           1 |              1 |            0 |
  |-----------------------------------------------------------------------------------------------------|
  |          elx_htn_uncomp          |          elx_dm_comp          |          elx_dm_uncomp           |
  |                       0          |                    0          |                      0           |
  +-----------------------------------------------------------------------------------------------------+

  +-----------------------------------------------------------------------------------------------------+
  | pid | elx_score | elx_chf | elx_metastatic | elx_drug | elx_obesity | elx_depression | elx_htn_comp |
  |   3 |         0 |       0 |              0 |        0 |           0 |              0 |            1 |
  |-----------------------------------------------------------------------------------------------------|
  |          elx_htn_uncomp          |          elx_dm_comp          |          elx_dm_uncomp           |
  |                       0          |                    1          |                      0           |
  +-----------------------------------------------------------------------------------------------------+

```

## Date-Windowed Scanning

```stata
. quietly {
```

```stata
. noisily comorbidity dx1, id(pid) charlson(original) collapse
>     date(dxdate) refdate(refdate) lookback(30) lookforward(10) inclusive
```

```
(note: condition pvd matched 0 observations)
(note: condition cvd matched 0 observations)
(note: condition dementia matched 0 observations)
(note: condition copd matched 0 observations)
(note: condition rheumatic matched 0 observations)
(note: condition peptic matched 0 observations)
(note: condition liver_mild matched 0 observations)
(note: condition dm_uncomp matched 0 observations)
(note: condition dm_comp matched 0 observations)
(note: condition hemiplegia matched 0 observations)
(note: condition renal matched 0 observations)
(note: condition cancer matched 0 observations)
(note: condition liver_severe matched 0 observations)
(note: condition metastatic matched 0 observations)
(note: condition hiv matched 0 observations)

codescan: 17 conditions, 1 variable, N =          1 pid values
Window: 30 days before to 10 days after refdate (inclusive)

  Condition              Matches   Prevalence
  --------------------------------------------
  Myocardial Infarction        1       100.0%
  Congestive Heart Fai~        1       100.0%
  Peripheral Vascular ~        0         0.0%
  Cerebrovascular Dise~        0         0.0%
  Dementia                     0         0.0%
  Chronic Pulmonary Di~        0         0.0%
  Rheumatic Disease            0         0.0%
  Peptic Ulcer Disease         0         0.0%
  Mild Liver Disease           0         0.0%
  Diabetes without Com~        0         0.0%
  Diabetes with Compli~        0         0.0%
  Hemiplegia or Parapl~        0         0.0%
  Renal Disease                0         0.0%
  Any Malignancy               0         0.0%
  Moderate or Severe L~        0         0.0%
  Metastatic Solid Tum~        0         0.0%
  HIV/AIDS                     0         0.0%

  Collapsed to          1 unique pid values

comorbidity: charlson (original), N =          1
  score: mean =   2.00, range = [     2.00,      2.00]

```

```stata
. noisily list pid charlson mi chf, noobs abbreviate(16)
```

```
  +---------------------------+
  | pid   charlson   mi   chf |
  |---------------------------|
  |   1          2    1     1 |
  +---------------------------+

```

## Hierarchy Toggle

```stata
. quietly {
```

```stata
. noisily comorbidity dx1 dx2, id(pid) charlson(original) collapse
```

```
(note: condition mi matched 0 observations)
(note: condition chf matched 0 observations)
(note: condition pvd matched 0 observations)
(note: condition cvd matched 0 observations)
(note: condition dementia matched 0 observations)
(note: condition copd matched 0 observations)
(note: condition rheumatic matched 0 observations)
(note: condition peptic matched 0 observations)
(note: condition liver_mild matched 0 observations)
(note: condition dm_uncomp matched 0 observations)
(note: condition dm_comp matched 0 observations)
(note: condition hemiplegia matched 0 observations)
(note: condition renal matched 0 observations)
(note: condition liver_severe matched 0 observations)
(note: condition hiv matched 0 observations)
(note: cancer and metastatic overlap in 1 obs, 100% of smaller group)

codescan: 17 conditions, 2 variables, N =          1 pid values

  Condition              Matches   Prevalence
  --------------------------------------------
  Myocardial Infarction        0         0.0%
  Congestive Heart Fai~        0         0.0%
  Peripheral Vascular ~        0         0.0%
  Cerebrovascular Dise~        0         0.0%
  Dementia                     0         0.0%
  Chronic Pulmonary Di~        0         0.0%
  Rheumatic Disease            0         0.0%
  Peptic Ulcer Disease         0         0.0%
  Mild Liver Disease           0         0.0%
  Diabetes without Com~        0         0.0%
  Diabetes with Compli~        0         0.0%
  Hemiplegia or Parapl~        0         0.0%
  Renal Disease                0         0.0%
  Any Malignancy               1       100.0%
  Moderate or Severe L~        0         0.0%
  Metastatic Solid Tum~        1       100.0%
  HIV/AIDS                     0         0.0%

  Collapsed to          1 unique pid values

comorbidity: charlson (original), N =          1
  score: mean =   6.00, range = [     6.00,      6.00]

```

```stata
. noisily list pid charlson cancer metastatic, noobs abbreviate(16)
```

```
  +--------------------------------------+
  | pid   charlson   cancer   metastatic |
  |--------------------------------------|
  |   1          6        0            1 |
  +--------------------------------------+

```

```stata
. quietly use "`hierarchy_data'", clear
```

```stata
. noisily comorbidity dx1 dx2, id(pid) charlson(original) collapse nohierarchy replace
```

```
(note: condition mi matched 0 observations)
(note: condition chf matched 0 observations)
(note: condition pvd matched 0 observations)
(note: condition cvd matched 0 observations)
(note: condition dementia matched 0 observations)
(note: condition copd matched 0 observations)
(note: condition rheumatic matched 0 observations)
(note: condition peptic matched 0 observations)
(note: condition liver_mild matched 0 observations)
(note: condition dm_uncomp matched 0 observations)
(note: condition dm_comp matched 0 observations)
(note: condition hemiplegia matched 0 observations)
(note: condition renal matched 0 observations)
(note: condition liver_severe matched 0 observations)
(note: condition hiv matched 0 observations)
(note: cancer and metastatic overlap in 1 obs, 100% of smaller group)

codescan: 17 conditions, 2 variables, N =          1 pid values

  Condition              Matches   Prevalence
  --------------------------------------------
  Myocardial Infarction        0         0.0%
  Congestive Heart Fai~        0         0.0%
  Peripheral Vascular ~        0         0.0%
  Cerebrovascular Dise~        0         0.0%
  Dementia                     0         0.0%
  Chronic Pulmonary Di~        0         0.0%
  Rheumatic Disease            0         0.0%
  Peptic Ulcer Disease         0         0.0%
  Mild Liver Disease           0         0.0%
  Diabetes without Com~        0         0.0%
  Diabetes with Compli~        0         0.0%
  Hemiplegia or Parapl~        0         0.0%
  Renal Disease                0         0.0%
  Any Malignancy               1       100.0%
  Moderate or Severe L~        0         0.0%
  Metastatic Solid Tum~        1       100.0%
  HIV/AIDS                     0         0.0%

  Collapsed to          1 unique pid values

comorbidity: charlson (original), N =          1
  score: mean =   8.00, range = [     8.00,      8.00]

```

```stata
. noisily list pid charlson cancer metastatic, noobs abbreviate(16)
```

```
  +--------------------------------------+
  | pid   charlson   cancer   metastatic |
  |--------------------------------------|
  |   1          8        1            1 |
  +--------------------------------------+

```

## Custom Weighted Code File

```stata
. quietly {
```

```stata
. noisily comorbidity dx1 dx2, id(pid) custom("`custom_codes'.dta") collapse replace
```

```
(note: mi and chf overlap in 1 obs, 100% of smaller group)

codescan: 3 conditions, 2 variables, N =          2 pid values

  Condition              Matches   Prevalence
  --------------------------------------------
  mi                           1        50.0%
  chf                          1        50.0%
  dm                           1        50.0%

  Collapsed to          2 unique pid values

comorbidity: custom (custom), N =          2
  score: mean =   8.00, range = [     4.00,     12.00]

```

```stata
. noisily list pid custom mi chf dm, noobs abbreviate(16)
```

```
  +------------------------------+
  | pid   custom   mi   chf   dm |
  |------------------------------|
  |   1       12    1     1    0 |
  |   2        4    0     0    1 |
  +------------------------------+

```

```stata
. display "RESULT: demo_comorbidity tests=6 pass=6 fail=0"
```

```
RESULT: demo_comorbidity tests=6 pass=6 fail=0

```

---
title: "console_compete"
---

## Aalen-Johansen cumulative incidence at 1, 5, and 10 years

```stata
. kmplot, by(treated) byorder(1 0) compete(status == 2) landmark(1 5 10) nodraw
```

```
Aalen-Johansen cumulative incidence plot
  Observations: 14999
  Groups:       2
  Competing:    status == 2 (1201 records)
```

```stata
. display as text "Estimator: " as result "`r(estimator)'" ///
>     as text "   Groups: " as result `"`r(group_labels)'"'
```

```
Estimator: aalen_johansen   Groups: SNRI | SSRI
```

```stata
. matrix list r(landmarks), format(%7.4f)
```

```
r(landmarks)[6,5]
       group      time  estimate     lower     upper
r1    1.0000    1.0000    0.0265         .         .
r2    1.0000    5.0000    0.1153         .         .
r3    1.0000   10.0000    0.2018         .         .
r4    2.0000    1.0000    0.0282         .         .
r5    2.0000    5.0000    0.1188         .         .
r6    2.0000   10.0000    0.2030         .         .
```

## 1 - Kaplan-Meier treats deaths as censored and overstates the risk

```stata
. kmplot, by(treated) byorder(1 0) failure landmark(10) nodraw
```

```
Kaplan-Meier plot
  Observations: 14999
  Groups:       2
```

```stata
. display as text "Estimator: " as result "`r(estimator)'"
```

```
Estimator: km_failure
```

```stata
. matrix list r(landmarks), format(%7.4f)
```

```
r(landmarks)[2,5]
       group      time  estimate     lower     upper
r1    1.0000   10.0000    0.2154         .         .
r2    2.0000   10.0000    0.2164         .         .
```

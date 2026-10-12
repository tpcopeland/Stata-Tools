---
title: "console_landmarks"
---

## Cumulative incidence at 1, 5, and 10 years

<!-- * Rows are indexed by group: 1, 2, ... in the order of r(group_labels) -->

```stata
. kmplot, by(treated) failure ci landmark(1 5 10) name(demo11, replace)
```

```
Kaplan-Meier plot
  Observations: 14998
  Groups:       2
  CI transform: loglog
```

```stata
. display as text "Groups: " as result `"`r(group_labels)'"'
```

```
Groups: SSRI | SNRI
```

```stata
. matrix list r(landmarks), format(%7.4f)
```

```
r(landmarks)[6,5]
       group      time  estimate     lower     upper
r1    1.0000    1.0000    0.0536    0.0491    0.0585
r2    1.0000    5.0000    0.2243    0.2154    0.2335
r3    1.0000   10.0000    0.3678    0.3564    0.3795
r4    2.0000    1.0000    0.0517    0.0463    0.0576
r5    2.0000    5.0000    0.2258    0.2150    0.2370
r6    2.0000   10.0000    0.3816    0.3675    0.3961
```

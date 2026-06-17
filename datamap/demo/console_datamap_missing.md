---
title: "console_datamap_missing"
---

## Missing-data pattern output

```stata
. noisily datamap, single("`pkg_dir'/_demo_missing.dta")
>     output("`pkg_dir'/datamap_missing.txt")
>     exclude(id) missing(pattern) quality mincell(5) noguidance
```

```
(file datamap/demo/datamap_missing.txt not found)
(file /tmp/St1678980.000003 not found)
Output written to: datamap/demo/datamap_missing.txt
Documentation generated successfully

```

```stata
. noisily _demo_strip_trailing_spaces using "`pkg_dir'/datamap_missing.txt"
```

```
(file /tmp/St1678980.000001 not found)

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_missing.txt", lines(80)
```

```
Dataset Documentation
Generated: 17 Jun 2026 21:48:47

========================================
DATASET: _demo_missing.dta
========================================

METADATA
--------
Observations: 80
Variables: 6
Label: Biomarker Study with Missing Data Patterns
Data Signature: 80:6(26080):323884870:1380290782

DISCLOSURE RISK SUMMARY
-----------------------
Excluded variables: 1
Small-cell threshold: 5
Date-safe mode: off
Likely identifiers not excluded: 0

DESCRIPTION
-----------
This dataset contains cross-sectional data. It includes 80 observations and 6 variables. Key variable categories include
> : identifiers, outcomes.

Missing Data Summary
  Variables with >50% missing: 0
  Variables with >10% missing: 4
  Observations with complete data: 38 (47.5%)

========================================
VARIABLE SUMMARY
========================================

QUICK REFERENCE
----------------------------------------
  Variable                Type      Class          Miss%  Unique
  id                      double    excluded        0.0%       .
  x1                      double    continuous     25.0%      60
  x2                      double    continuous     25.0%      60
  x3                      double    continuous     35.0%      52
  x4                      double    continuous     12.5%      70
  outcome                 double    categorical     0.0%       2
----------------------------------------

  id
    Type: double
    Format: %10.0g
    Label: Subject ID
    Missing: 0 (0.0%)
    Classification: excluded

  x1
    Type: double
    Format: %10.0g
    Label: Biomarker A
    Missing: 20 (25.0%)
    Classification: continuous

  x2
    Type: double
    Format: %10.0g
    Label: Biomarker B
    Missing: 20 (25.0%)
    Classification: continuous

  x3
    Type: double
    Format: %10.0g
    Label: Biomarker C
    Missing: 28 (35.0%)
    Classification: continuous

  x4
    Type: double
    Format: %10.0g
    Label: Biomarker D
    Missing: 10 (12.5%)
    Classification: continuous

... [output truncated]

```

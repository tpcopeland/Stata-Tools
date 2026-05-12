---
title: "workflow"
---

## Exposure-window matching

```stata
. quietly {
```

```stata
. use "`exposures'", clear
```

```stata
. noisily rangematch event_date exposure_start exposure_end using "`adverse_events'",
>     by(patient_id) keepusing(event_id event_date event_type severity)
>     generate(match_status) masterid(exposure_row) usingid(event_row)
>     frame(exposure_events) replace stats
```

```
    Result                       Number of obs
    -------------------------------------------------
    Not matched                                       0
    Matched                                           4
    -------------------------------------------------
    Total output                                      4
    Output frame                           exposure_events

    Match density                Value
    -------------------------------------------------
    Matched master rows                               4
    Unmatched master rows                             0
    Unmatched using rows                              3
    Max matches/master row                            1
    Mean matches/master row                       1.000
    p50 matches/master row                        1.000
    p90 matches/master row                        1.000
    p99 matches/master row                        1.000
    Master groups with no using keys                  0
    Master groups considered                          3

```

```stata
. noisily frame exposure_events: list patient_id drug exposure_start exposure_end
>     event_id event_date event_type severity match_status, sepby(patient_id) noobs
```

```
  +----------------------------------------------------------------------------------------------------+
  | patien~d     drug   exposur~t   exposur~d   event_id   event_d~e   event_t~e   severity   match_~s |
  |----------------------------------------------------------------------------------------------------|
  |      101   drug_a   15jan2020   14feb2020       1001   20jan2020        rash          2    matched |
  |      101   drug_b   01mar2020   15mar2020       1003   10mar2020      nausea          2    matched |
  |----------------------------------------------------------------------------------------------------|
  |      102   drug_a   10feb2020   02mar2020       1004   15feb2020   dizziness          3    matched |
  |----------------------------------------------------------------------------------------------------|
  |      103   drug_c   20feb2020   01mar2020       1006   25feb2020        rash          1    matched |
  +----------------------------------------------------------------------------------------------------+

```

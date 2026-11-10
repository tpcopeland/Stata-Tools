---
title: "console_dataprobe_diff"
---

## Snapshot before a data step

```stata
. use "`pkg_dir'/_demo_cohort.dta", clear
```

```
(Synthetic Clinical Trial Cohort (N=1200))

```

```stata
. capture frame drop baseline
```

```stata
. noisily dataprobe, snapshot(baseline) gatesonly
```

```
snapshot: frame baseline, key patient_id
dataprobe: gatesonly with no gates declared; nothing was checked

```

```stata
. noisily display as text "Snapshot frame: `r(snapshot)'; key: `r(snapshot_key)'"
```

```
Snapshot frame: baseline; key: patient_id

```

## A data step that goes wrong

```stata
. quietly {
```

## Diff against the snapshot

```stata
. noisily dataprobe, diff(baseline) gatesonly
```

```
DIFF
  baseline: frame baseline
  N: current 1210, baseline 1200, delta 10
  key patient_id: unique before, not unique after (10 surplus rows)
  patient_id: mean 100601 -> 100596
  subject_id: mean 5600.5 -> 5595.58
  age: mean 57.5937 -> 57.5517
  sex: mean .511667 -> .512397
  smoking: missing 188 -> 190 (+2); mean .993083 -> .995098
  bmi: dropped (double)
  sbp: mean 135.773 -> 135.756
  creatinine: missing 142 -> 359 (+217); distinct 168 -> 159 (-9); mean 1.03267 -> 1.02756; range -.07 to 2.27 -> -.06 to 2.02
  pct_adherence: missing 232 -> 235 (+3); mean 78.0089 -> 78.0966
  follow_up_time: mean 3.53087 -> 3.54679
  event: mean .273333 -> .27438
  treatment: mean .485833 -> .487603
  site: mean 3.4875 -> 3.50248
  rare_marker: mean .0025 -> .00495868
  bmi_group: added (double, categorical)
dataprobe: gatesonly with no gates declared; nothing was checked

```

## keyset() preflight before a merge

```stata
. use "`pkg_dir'/_demo_cohort.dta", clear
```

```
(Synthetic Clinical Trial Cohort (N=1200))

```

```stata
. noisily dataprobe, gatesonly keyset(patient_id using "`pkg_dir'/_demo_labs.dta") warn
```

```
KEYSET PREFLIGHT: patient_id using _demo_labs
  types: patient_id double in memory, double in _demo_labs
  unique: memory yes, _demo_labs yes; merge 1:1
  keys: 627 matched, 573 memory only, 0 _demo_labs only
  merge 1:1 would report: 627 matched, 573 master only, 0 using only
  shared non-key variables: (none)

WARNINGS (1): _demo_cohort
  keyset(patient_id): equal — 573 keys not in _demo_labs; 0 keys of _demo_labs absent

```

```stata
. capture frame drop baseline
```

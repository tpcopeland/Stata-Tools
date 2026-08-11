---
title: "tvbuild: The Whole Route as One Call"
---

## tvbuild: The Whole Route as One Call

### The one-source shortcut

<!-- * The smallest useful tvbuild call. It reads the raw dispensing extract as it -->

<!-- * stands -- one row per dispensed episode, nothing coded to the unexposed -->

<!-- * reference category -- tiles it against each person's follow-up window, and -->

<!-- * commits a named analysis frame plus a provenance manifest as one transaction. -->

<!-- * No specification frame, no intermediate save/use, and the caller's cohort in -->

<!-- * memory is read and never written. -->

<!-- * manifestframe() is not given: since 1.12.0 tvbuild derives it from frameout(), -->

<!-- * so the provenance record arrives with the result rather than only on request. -->

```stata
use "`cohort'", clear
```

```stata
noisily tvbuild, sourceusing("`episodes_antidep'")
id(id) entry(study_entry) exit(study_exit)
start(rx_start) stop(rx_stop) exposure(drug) reference(0)
referencelabel("Unexposed") label("Antidepressant class")
generate(tv_drug) keepvars(age female)
frameout(tvdemo_analysis) replace
```

```
tvbuild plan
--------------------------------------------------------------------
  master frame                 : default
  persons                      :            200
  id / entry / exit            : id study_entry study_exit
  output bounds                : start stop
  coverage policy              : strict
  files loaded                 :              1
--------------------------------------------------------------------
  source 1                     : tv_drug  (episodes, file)
  locator                      : tvdemo_episodes_antidep.dta
  rows                         :            281
  persons in source            :            166
  rows outside window          :             17  (reported and ignored)
  mapping                      : drug -> tv_drug
  engine                       : tvexpose_categorical
--------------------------------------------------------------------
  master keepvars              : age female
  entry/exit                   : retained
  event stage                  : none
  frameout()                   : tvdemo_analysis  (create)
  manifestframe()              : tvdemo_analysis_manifest  (create)
--------------------------------------------------------------------
tvbuild result
--------------------------------------------------------------------
  frameout()                   : tvdemo_analysis
  persons                      :            200
  periods                      :            589
  key / bounds                 : id start stop
  study window                 : study_entry study_exit
  output variables             : tv_drug
  manifestframe()              : tvdemo_analysis_manifest
  coverage                     : strict  (every master day is represented)
--------------------------------------------------------------------
  Next steps (not run by tvbuild):
```

```stata
frame change tvdemo_analysis
```

```stata
tvdiagnose, id(id) start(start) stop(stop) entry(study_entry) exit(study_exit) all
```

```stata
stset stop, id(id) time0(start - 1)
```

```stata
noisily display "committed frame rows: " as result r(N_periods)
as text "   persons: " as result r(N_persons)
as text "   bounds: " as result "`r(startvar)'/`r(stopvar)'"
as text "   exposure vars: " as result "`r(exposure_vars)'"
```

```
committed frame rows: 589   persons: 200   bounds: start/stop   exposure vars: tv_drug
```

### What the shortcut committed

```stata
noisily frame tvdemo_analysis: list id start stop tv_drug age female in 1/10,
noobs abbreviate(12)
```

```
  +---------------------------------------------------------+
  | id        start         stop     tv_drug   age   female |
  |---------------------------------------------------------|
  |  1   2015/05/20   2019/12/07   Unexposed    40        1 |
  |  2   2015/01/13   2015/09/29        SNRI    40        0 |
  |  2   2015/09/30   2019/11/08   Unexposed    40        0 |
  |  3   2015/01/13   2015/11/06        SNRI    40        0 |
  |  3   2015/11/07   2018/04/26   Unexposed    40        0 |
  |---------------------------------------------------------|
  |  4   2015/02/23   2015/10/18        SNRI    63        0 |
  |  4   2015/10/19   2016/04/10   Unexposed    63        0 |
  |  5   2015/02/09   2015/09/11        SNRI    56        1 |
  |  5   2015/09/12   2015/10/01   Unexposed    56        1 |
  |  5   2015/10/02   2016/05/11        SNRI    56        1 |
  +---------------------------------------------------------+
```

### Its provenance manifest

```stata
noisily frame tvdemo_analysis_manifest: list stage source_name n_input n_output n_persons,
noobs
```

```
  +---------------------------------------------------+
  |  stage   source~e   n_input   n_output   n_pers~s |
  |---------------------------------------------------|
  | master                  200        200        200 |
  | source    tv_drug       281        589        166 |
  | output                  589        589        200 |
  +---------------------------------------------------+
```

### The multi-source specification: one tvspec call per source

<!-- * Describing two sources used to take twelve generate statements across nine -->

<!-- * typed columns, which is why this block used to be built with the log closed. -->

<!-- * tvspec writes the same columns, so it can be shown where it belongs. -->

```stata
noisily tvspec create tvdemo_spec, replace
```

```stata
noisily tvspec add tvdemo_spec, name(antidep) using("`episodes_antidep'")
start(rx_start) stop(rx_stop) exposure(drug) reference(0)
generate(`gA') referencelabel("Unexposed") label("Antidepressant class")
```

```stata
noisily tvspec add tvdemo_spec, name(benzo) using("`episodes_benzo'")
start(rx_start) stop(rx_stop) exposure(benzo_use) reference(0)
generate(`gB') referencelabel("No benzo") label("Benzodiazepine use")
```

### The specification tvbuild will read

```stata
noisily tvspec list tvdemo_spec
```

```
tvbuild specification: tvdemo_spec
--------------------------------------------------------------------
  source 1                     : antidep  (episodes, file)
  locator                      : tvdemo_episodes_antidep.dta
  interval bounds              : rx_start rx_stop
  mapping                      : drug -> tv_drug
  reference                    :              0
  reference label              : Unexposed
  variable label               : Antidepressant class
--------------------------------------------------------------------
  source 2                     : benzo  (episodes, file)
  locator                      : tvdemo_episodes_benzo.dta
  interval bounds              : rx_start rx_stop
  mapping                      : benzo_use -> tv_benzo_use
  reference                    :              0
  reference label              : No benzo
  variable label               : Benzodiazepine use
--------------------------------------------------------------------
  Build it with:
```

```stata
tvbuild, specframe(tvdemo_spec) id(idvar) entry(entryvar) exit(exitvar) frameout(result)
```

<!-- * tvbuild reads the same two raw episode files Steps 1-4 consumed and -->

<!-- * coordinates the same tvexpose, tvmerge, and tvevent engines rather than -->

<!-- * reimplementing interval semantics: it tiles each episode source, aligns them, -->

<!-- * places the events, and commits the output frame and its provenance manifest -->

<!-- * as a single transaction. -->

### The plan, validated against the data, changing nothing

<!-- * dryrun is not a syntax check: it runs the same parser, normalizer, name -->

<!-- * planner, data validators, and destination preflight the real run uses. -->

```stata
use "`cohort'", clear
```

```stata
noisily tvbuild, specframe(tvdemo_spec)
id(id) entry(study_entry) exit(study_exit) keepvars(age female)
eventusing("`events'") eventdate(cv_event_date) compete(death_date)
eventgenerate(outcome)
frameout(tvdemo_full) manifestframe(tvdemo_full_manifest) replace dryrun
```

```
tvbuild plan (dry run)
--------------------------------------------------------------------
  master frame                 : default
  persons                      :            200
  id / entry / exit            : id study_entry study_exit
  output bounds                : start stop
  coverage policy              : strict
  files loaded                 :              3
--------------------------------------------------------------------
  source 1                     : antidep  (episodes, file)
  locator                      : tvdemo_episodes_antidep.dta
  rows                         :            281
  persons in source            :            166
  rows outside window          :             17  (reported and ignored)
  mapping                      : drug -> tv_drug
  engine                       : tvexpose_categorical
--------------------------------------------------------------------
  source 2                     : benzo  (episodes, file)
  locator                      : tvdemo_episodes_benzo.dta
  rows                         :            100
  persons in source            :             86
  mapping                      : benzo_use -> tv_benzo_use
  engine                       : tvexpose_categorical
--------------------------------------------------------------------
  master keepvars              : age female
  entry/exit                   : retained
  event stage                  : outcome  (event data from the file)
  frameout()                   : tvdemo_full  (create)
  manifestframe()              : tvdemo_full_manifest  (create)
--------------------------------------------------------------------
  Dry run: no frame, variable, value label, or file was created or changed.
```

### The committed run

```stata
use "`cohort'", clear
```

```stata
noisily tvbuild, specframe(tvdemo_spec)
id(id) entry(study_entry) exit(study_exit) keepvars(age female)
eventusing("`events'") eventdate(cv_event_date) compete(death_date)
eventgenerate(outcome)
frameout(tvdemo_full) manifestframe(tvdemo_full_manifest) replace
```

```
tvbuild plan
--------------------------------------------------------------------
  master frame                 : default
  persons                      :            200
  id / entry / exit            : id study_entry study_exit
  output bounds                : start stop
  coverage policy              : strict
  files loaded                 :              3
--------------------------------------------------------------------
  source 1                     : antidep  (episodes, file)
  locator                      : tvdemo_episodes_antidep.dta
  rows                         :            281
  persons in source            :            166
  rows outside window          :             17  (reported and ignored)
  mapping                      : drug -> tv_drug
  engine                       : tvexpose_categorical
--------------------------------------------------------------------
  source 2                     : benzo  (episodes, file)
  locator                      : tvdemo_episodes_benzo.dta
  rows                         :            100
  persons in source            :             86
  mapping                      : benzo_use -> tv_benzo_use
  engine                       : tvexpose_categorical
--------------------------------------------------------------------
  master keepvars              : age female
  entry/exit                   : retained
  event stage                  : outcome  (event data from the file)
  frameout()                   : tvdemo_full  (create)
  manifestframe()              : tvdemo_full_manifest  (create)
--------------------------------------------------------------------
tvbuild result
--------------------------------------------------------------------
  frameout()                   : tvdemo_full
  persons                      :            200
  periods                      :            764
  key / bounds                 : id start stop
  study window                 : study_entry study_exit
  output variables             : tv_drug tv_benzo_use
  event variable               : outcome
  manifestframe()              : tvdemo_full_manifest
  coverage                     : strict  (every master day is represented)
--------------------------------------------------------------------
  Next steps (not run by tvbuild):
```

```stata
frame change tvdemo_full
```

```stata
tvdiagnose, id(id) start(start) stop(stop) entry(study_entry) exit(study_exit) all
```

```stata
stset stop, id(id) failure(outcome == 1) time0(start - 1)
```

```stata
local build_periods = r(N_periods)
```

```stata
noisily display "committed periods: " as result r(N_periods)
```

```
>     "   signature: " as result "`r(datasignature)'"
committed periods: 764   signature: 764:10(40091):2831415381:3111537191
```

```stata
noisily matrix list r(stage_counts)
```

```
r(stage_counts)[5,5]
                 N_in         N_out  N_persons_in  N_persons_~t  uncovered_~s
source1           281           589           166           200             0
source2           100           398            86           200             0
  merge           987           787           200           200             0
  event           787           764           200           200             .
 output           764           764           200           200             .
```

### Provenance manifest: one row per stage, in execution order

```stata
noisily frame tvdemo_full_manifest: list stage source_name n_input n_output n_persons, noobs
```

```
  +---------------------------------------------------+
  |  stage   source~e   n_input   n_output   n_pers~s |
  |---------------------------------------------------|
  | master                  200        200        200 |
  | source    antidep       281        589        166 |
  | source      benzo       100        398         86 |
  |  merge                  987        787        200 |
  |  event                  787        764        200 |
  |---------------------------------------------------|
  | output                  764        764        200 |
  +---------------------------------------------------+
```

### Same inputs, same engines, same records

<!-- * The four-call route and the single call are compared on the columns they -->

<!-- * share, after an identical sort. cf is the right test here and datasignature -->

<!-- * is not: tvbuild keeps the master's id storage type and commits its bounds as -->

<!-- * doubles, so the two routes carry identical values under different storage -->

<!-- * types, which datasignature folds into its checksum. -->

<!-- * The keep/sort/save bookkeeping below is closed out of the log: it prepares -->

<!-- * the comparison, it is not part of what tvbuild does. -->

```stata
noisily cf _all using "`prim_cmp'", verbose
```

```stata
local cmp_diffs = r(Nsum)
```

```stata
assert `cmp_diffs' == 0
```

```stata
noisily display "tvexpose x2 + tvmerge + tvevent: " as result `prim_periods' as text " periods"
```

```
tvexpose x2 + tvmerge + tvevent: 764 periods
```

```stata
noisily display "one tvbuild call:                " as result `build_periods' as text " periods"
```

```
one tvbuild call:                764 periods
```

```stata
noisily display "cf mismatching values:           " as result `cmp_diffs'
```

```
cf mismatching values:           0
```

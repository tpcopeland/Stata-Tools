---
title: "tvtools: Frames-First Primitives"
---

## tvtools: Frames-First Time-Varying Primitives

### Package overview

```stata
use "`cohort'", clear
```

```stata
noisily tvtools
```

```
tvtools - Time-Varying Exposure Analysis Suite
Version 1.15.0
--------------------------------------------------------------------
Data Preparation
  tvbuild    - Build a committed interval frame end to end
  tvspec     - Build a tvbuild specification frame
  tvexpose   - Create time-varying exposure variables
  tvmerge    - Merge multiple time-varying datasets
  tvevent    - Integrate events and competing risks
  tvage      - Expand person-level follow-up into age bands
  tvband     - Split intervals on one date-derived axis
  tvsplit    - Multi-timescale Lexis interval splitting
  tvpanel    - Build fixed-width MSM panel grid
Diagnostics
  tvdiagnose - Diagnostic tools for TV datasets
Weighting
  tvweight   - Calculate IPTW weights
--------------------------------------------------------------------
  total commands               :             11
  workflow guide               : help tvtools
  individual command help      : help <command>
--------------------------------------------------------------------
```

### Step 1: tvexpose -> frame (caller's data left intact)

<!-- * The exposure interval set is written to a frame; the cohort stays in memory. -->

<!-- * The generated variable name is returned in r(genvar). -->

```stata
use "`cohort'", clear
```

```stata
noisily tvexpose using "`episodes_antidep'",
id(id) start(rx_start) stop(rx_stop)
exposure(drug) reference(0)
entry(study_entry) exit(study_exit)
keepvars(age female) keepdates frameout(tvdemo_antidep)
```

```
Note: output exposure variable named tv_drug (from exposure(drug)); use generate() to override.
tvexpose result
--------------------------------------------------------------------
  persons                      :            200
  time-varying periods         :            589
  total person-time (days)     :        222,316
  exposed person-time          :         52,917  (23.8%)
  unexposed person-time        :        169,399  (76.2%)
  operationalization           : timevarying
  result frame                 : tvdemo_antidep
--------------------------------------------------------------------
  Baseline periods included (complete person-time coverage).
```

```stata
local gA = r(genvar)
```

```stata
noisily display "antidepressant exposure variable: " as result "`gA'"
```

```
antidepressant exposure variable: tv_drug
```

```stata
quietly tvexpose using "`episodes_benzo'",
id(id) start(rx_start) stop(rx_stop)
exposure(benzo_use) reference(0)
entry(study_entry) exit(study_exit)
keepvars(age female) keepdates frameout(tvdemo_benzo)
```

```stata
local gB = r(genvar)
```

```stata
noisily display "benzodiazepine exposure variable: " as result "`gB'"
```

```
benzodiazepine exposure variable: tv_benzo_use
```

### Step 2: tvdiagnose on the in-memory frame

```stata
noisily frame tvdemo_antidep: tvdiagnose, id(id) start(rx_start) stop(rx_stop)
entry(study_entry) exit(study_exit) coverage gaps
```

```
Time-Varying Data Diagnostics
------------------------------------------------------------------------------
Dataset summary
  observations                 :            589
  persons                      :            200
  periods per person           :            2.9
------------------------------------------------------------------------------
Coverage Diagnostics
------------------------------------------------------------------------------
Coverage Summary
  mean coverage                :          100.0  %
  min coverage                 :          100.0  %
  max coverage                 :          100.0  %
  persons with gaps            :              0  (0.0%)
------------------------------------------------------------------------------
Gap Analysis
------------------------------------------------------------------------------
  No gaps found in coverage.
------------------------------------------------------------------------------
Diagnostic Complete
------------------------------------------------------------------------------
```

### Step 3: tvmerge reads both frames, writes a merged frame

```stata
noisily tvmerge, frames(tvdemo_antidep tvdemo_benzo) id(id)
start(rx_start rx_start) stop(rx_stop rx_stop)
exposure(`gA' `gB') frameout(tvdemo_merged)
```

```
tvmerge result
--------------------------------------------------------------------
  observations                 :            787
  persons                      :            200
  exposure variables           : tv_drug tv_benzo_use
  result placed in frame       : tvdemo_merged
--------------------------------------------------------------------
```

```stata
noisily display "merged interval vars: " as result "`r(startname)' / `r(stopname)'"
```

```
merged interval vars: start / stop
```

### Step 4: tvevent reads the merged frame, adds the outcome in memory

```stata
use "`events'", clear
```

```stata
noisily tvevent, frame(tvdemo_merged) id(id)
date(cv_event_date) compete(death_date) generate(outcome)
```

```
Splitting intervals for 22 internal events...
Single event type: Censored person-time after first event.
tvevent result
--------------------------------------------------------------------
  observations                 :            764
  events flagged (outcome)     :             22
  outcome labels
    0                          : Censored
    1                          : Event: cv_event_date
    2                          : Competing: death_date
--------------------------------------------------------------------
```

```stata
noisily display "event indicator: " as result "`r(generate)'"
```

```
>     "   intervals: " as result "`r(startvar)'/`r(stopvar)'"
event indicator: outcome   intervals: start/stop
```

<!-- * Keep the four-call result so the tvbuild section can be checked against it -->

<!-- * rather than merely described as equivalent. -->

```stata
local prim_periods = c(N)
```

```stata
quietly save "`primitive_out'", replace
```

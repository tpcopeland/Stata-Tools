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
----------------------------------------------------------------------
tvtools - Time-Varying Exposure Analysis Suite
----------------------------------------------------------------------

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

----------------------------------------------------------------------
Total commands: 11

Help: help tvtools for workflow guide
      help <command> for individual command help
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

Time-varying exposure dataset created
Exposure Operationalization: timevarying
--------------------------------------------------
    Persons:            200
    Time-varying periods:            589
    Total person-time (days):        222,316
    Exposed person-time:         52,917 (23.8%)
    Unexposed person-time:        169,399
    Note: Baseline periods included (complete person-time coverage)
--------------------------------------------------
Result placed in frame: tvdemo_antidep
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
----------------------------------------------------------------------
Time-Varying Data Diagnostics
----------------------------------------------------------------------
Dataset summary:
  Observations:          589
  Persons:          200
  Periods/person:      2.9

----------------------------------------------------------------------
Coverage Diagnostics
----------------------------------------------------------------------
----------------------------------------------------------------------
Coverage Summary:
  Mean coverage: 100.0%
  Min coverage:  100.0%
  Max coverage:  100.0%
  Persons with gaps: 0 ( 0.0%)
----------------------------------------------------------------------

----------------------------------------------------------------------
Gap Analysis
----------------------------------------------------------------------
No gaps found in coverage

----------------------------------------------------------------------
Diagnostic Complete
----------------------------------------------------------------------
```

### Step 3: tvmerge reads both frames, writes a merged frame

```stata
noisily tvmerge, frames(tvdemo_antidep tvdemo_benzo) id(id)
start(rx_start rx_start) stop(rx_stop rx_stop)
exposure(`gA' `gB') frameout(tvdemo_merged)
```

```
Merged time-varying dataset successfully created
--------------------------------------------------
    Observations:            787
    Persons:            200
    Exposure variables:  tv_drug tv_benzo_use
--------------------------------------------------
Result placed in frame: tvdemo_merged
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
id            start         stop          tv_drug       tv_benzo_use
Splitting intervals for 22 internal events...
Single event type: Censored person-time after first event.


--------------------------------------------------
Event integration complete
  Observations: 764
  Events flagged (outcome): 22
  Variable outcome labels:
    0 = Censored
    1 = Event: cv_event_date
    2 = Competing: death_date
--------------------------------------------------
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

---
title: "console_recurrent"
---

## Recurrent Events: PWP / Andersen-Gill Formatting

### tvevent type(recurring) with enum stratum + gap-time clock

<!-- * The base follow-up interval is split at each hospitalization; tvevent adds the -->

<!-- * event-sequence stratum (enum) and a gap-time clock that resets at each event, -->

<!-- * so the output feeds Andersen-Gill, PWP total-time, and PWP gap-time models. -->

```stata
use "`pkg_dir'/_recur.dta", clear
```

```stata
rename study_entry win_start
```

```stata
rename study_exit win_stop
```

```stata
keep id win_start win_stop
```

```stata
tempfile recint
```

```stata
save "`recint'"
```

```
file /tmp/St1753999.000001 saved as .dta format

```

```stata
use "`pkg_dir'/_recur.dta", clear
```

```stata
keep id hosp1 hosp2 hosp3
```

```stata
noisily tvevent using "`recint'", id(id) date(hosp) type(recurring)
generate(hosp_ev) start(win_start) stop(win_stop)
enum(stratum) gaptime gapstart(t0) gapstop(t) timegen(tstop) timeunit(days)
```

```
Recurring events: Found 3 event variables (hosp1 hosp2 hosp3)
Splitting intervals for 297 internal events...
Recurring event type: Retained all person-time.
Recurrent formatting: stratum stratum + gap time (t0,t) added.


--------------------------------------------------
Event integration complete
  Observations: 497
  Events flagged (hosp_ev): 297
  Variable hosp_ev labels:
0 1
    0 = Censored
    1 = Event: hosp
--------------------------------------------------

```

```stata
noisily display "stratum var: " as result "`r(enum)'"
```

```
>     "   gap-time clock: " as result "`r(gapstart)'/`r(gapstop)'"
stratum var: stratum   gap-time clock: t0/t

```

### A few persons with repeated events

```stata
noisily list id win_start win_stop hosp_ev stratum t0 t in 1/12,
sepby(id) noobs abbreviate(12)
```

```
  +------------------------------------------------------------------+
  | id    win_start     win_stop       hosp_ev   stratum   t0      t |
  |------------------------------------------------------------------|
  |  1   2015/05/20   2015/11/12   Event: hosp         1    0    176 |
  |  1   2015/11/13   2019/12/07      Censored         2    0   1485 |
  |------------------------------------------------------------------|
  |  2   2015/01/13   2019/11/08      Censored         1    0   1760 |
  |------------------------------------------------------------------|
  |  3   2015/01/13   2015/10/06   Event: hosp         1    0    266 |
  |  3   2015/10/07   2018/04/26      Censored         2    0    932 |
  |------------------------------------------------------------------|
  |  4   2015/02/23   2015/12/09   Event: hosp         1    0    289 |
  |  4   2015/12/10   2016/04/10      Censored         2    0    122 |
  |------------------------------------------------------------------|
  |  5   2015/02/09   2015/06/20   Event: hosp         1    0    131 |
  |  5   2015/06/21   2019/12/27      Censored         2    0   1650 |
  |------------------------------------------------------------------|
  |  6   2015/01/05   2015/04/07   Event: hosp         1    0     92 |
  |  6   2015/04/08   2015/06/29   Event: hosp         2    0     82 |
  |  6   2015/06/30   2018/03/12      Censored         3    0    986 |
  +------------------------------------------------------------------+

```

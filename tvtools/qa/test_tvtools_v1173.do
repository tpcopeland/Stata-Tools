*! test_tvtools_v1173.do
*! Release regressions: layer precedence under entry clipping, clipped dose,
*! pre-entry washout, pre-entry acute windows, last-stop fillgaps, unflagged
*! terminal events, and whole-number band widths
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
quietly log using "test_tvtools_v1173.log", replace text nomsg
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local tests = 0
local pass = 0
local fail = 0

**# Layer ranks episodes by their own start, not the entry date they clip to
* Episode A [100,120] drug 1 and episode B [105,130] drug 3: B began later, so
* B wins every shared day. With entry 110 both clip to start 110; the old
* engine then broke the tie by source row and let A win 110-120 when A was
* the later row.
local ++tests
capture noisily {
    clear
    input long id double(start stop) byte drug
    1 105 130 3
    1 100 120 1
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 110 125
    end
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv)
    assert _N == 1
    assert start == 110 & stop == 125 & tv == 3
}
if _rc == 0 local ++pass
else local ++fail

**# Same-value merging keeps layer precedence on a same-start tie
* A [101,110] v1 (row 1), C [103,125] v3 (row 2), B [103,120] v1 (row 3).
* B and C start together; B is the later source row, so v1 holds 103-120
* and v3 only 121-125. The old merge absorbed B into A and C then won.
local ++tests
capture noisily {
    clear
    input long id double(start stop) byte drug
    1 101 110 1
    1 103 125 3
    1 103 120 1
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 101 130
    end
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv)
    sort start
    assert _N == 3
    assert start[1] == 101 & stop[1] == 120 & tv[1] == 1
    assert start[2] == 121 & stop[2] == 125 & tv[2] == 3
    assert start[3] == 126 & stop[3] == 130 & tv[3] == 0
}
if _rc == 0 local ++pass
else local ++fail

**# Layer matches an independent daily oracle under clipping, ties, washout
* Oracle: on day d the covering episode with the latest start wins, ties to
* the later source row; washout extends each episode's stop. Built by
* expanding to person-days, never through tvexpose's own boundaries.
local ++tests
capture noisily {
    local nbad = 0
    foreach cfg in "0 1" "12 1" "0 7" {
        gettoken wo coarse : cfg
        forvalues seed = 1/25 {
            quietly {
                clear
                set seed `seed'
                set obs 6
                gen long id = _n
                gen double entry = 21915 + floor(runiform() * 20)
                gen double exit = entry + floor(runiform() * 60)
                tempfile master exp orc
                save `master'
                clear
                set obs 14
                gen long id = 1 + floor(runiform() * 6)
                gen long ord = _n
                gen double start = 21905 + `coarse' * floor(runiform() * 80 / `coarse')
                gen double stop = start + floor(runiform() * 20)
                gen byte drug = 1 + floor(runiform() * 3)
                save `exp'
                use `master', clear
                gen long n = exit - entry + 1
                expand n
                bysort id: gen double d = entry + _n - 1
                keep id d
                joinby id using `exp', unmatched(master)
                gen byte cover = _merge == 3 & start <= d & d <= stop + `wo'
                replace drug = 0 if !cover
                replace start = . if !cover
                replace ord = . if !cover
                gsort id d -cover -start -ord
                by id d: keep if _n == 1
                keep id d drug
                rename drug oracle
                save `orc'
                use `master', clear
                tvexpose using `exp', id(id) start(start) stop(stop) ///
                    exposure(drug) reference(0) entry(entry) exit(exit) ///
                    generate(tv) washout(`wo')
                gen long n = stop - start + 1
                count if n < 1
                local bad = r(N)
                expand n
                bysort id start: gen double d = start + _n - 1
                keep id d tv
                merge 1:1 id d using `orc'
                count if _merge != 3 | tv != oracle
                local bad = `bad' + r(N)
            }
            if `bad' local ++nbad
        }
    }
    display as text "layer oracle: `nbad' of 75 draws disagree"
    assert `nbad' == 0
}
if _rc == 0 local ++pass
else local ++fail

**# dose: an episode clipped at entry keeps only its in-window share
* 100 units over [90,109] is 5 units/day; entry 100 keeps days 100-109 = 50.
* id 2 adds an overlapping clipped episode and an int-typed amount:
* 7 units over [95,101] keeps 2 days = 2 units; plus 100 over [90,109] -> 50.
local ++tests
capture noisily {
    clear
    input long id double(start stop) int dose
    1 90 109 100
    2 90 109 100
    2 95 101 7
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 100 200
    2 100 200
    end
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(dose) dose ///
        entry(entry) exit(exit) generate(cumd)
    sort id start
    assert !missing(cumd)
    * id 1 is exactly two rows: [100,109] then [110,200]
    quietly count if id == 1
    assert r(N) == 2
    assert start[1] == 100 & stop[1] == 109 & abs(cumd[1] - 0) < 1e-9
    assert start[2] == 110 & stop[2] == 200 & abs(cumd[2] - 50) < 1e-9
    quietly summarize cumd if id == 2, meanonly
    assert !missing(r(max))
    assert abs(r(max) - 52) < 1e-9
    * at day 102 id 2 has received 2 units from the short episode and
    * 2 days x 5 units from the long one
    quietly count if id == 2 & start == 102
    assert r(N) == 1
    assert abs(cumd - 12) < 1e-9 if id == 2 & start == 102
}
if _rc == 0 local ++pass
else local ++fail

**# dose matches an independent daily-rate oracle under clipping and overlap
local ++tests
capture noisily {
    local nbad = 0
    forvalues seed = 1/25 {
        quietly {
            clear
            set seed `seed'
            set obs 5
            gen long id = _n
            gen double entry = 200 + floor(runiform() * 20)
            gen double exit = entry + floor(runiform() * 80)
            tempfile master exp rates
            save `master'
            clear
            set obs 12
            gen long id = 1 + floor(runiform() * 5)
            gen double start = 180 + floor(runiform() * 100)
            gen double stop = start + floor(runiform() * 25)
            gen int dose = 1 + floor(runiform() * 100)
            save `exp'
            gen long n = stop - start + 1
            gen double rate = dose / n
            expand n
            bysort id start stop dose: gen double d = start + _n - 1
            collapse (sum) rate, by(id d)
            save `rates'
            use `master', clear
            tvexpose using `exp', id(id) start(start) stop(stop) ///
                exposure(dose) dose entry(entry) exit(exit) generate(cumd)
            gen long row = _n
            joinby id using `rates', unmatched(master)
            merge m:1 id using `master', keepusing(entry) nogen
            gen double c = rate * (_merge == 3 & d >= entry & d < start)
            collapse (sum) oc = c (first) cumd, by(row)
            count if abs(oc - cumd) > 1e-6
        }
        if r(N) local ++nbad
    }
    display as text "dose oracle: `nbad' of 25 draws disagree"
    assert `nbad' == 0
}
if _rc == 0 local ++pass
else local ++fail

**# washout reaches past entry for an episode that ended before entry
* [50,90] + washout(30) is active through day 120. [10,20] + 30 ends at 50,
* still before entry 100, and is the only episode outside follow-up.
local ++tests
capture noisily {
    clear
    input long id double(start stop) byte drug
    1 50 90 1
    2 10 20 1
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 100 200
    2 100 200
    end
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv) washout(30)
    assert r(n_outside_window) == 1
    sort id start
    assert _N == 3
    assert start[1] == 100 & stop[1] == 120 & tv[1] == 1 & id[1] == 1
    assert start[2] == 121 & stop[2] == 200 & tv[2] == 0 & id[2] == 1
    assert start[3] == 100 & stop[3] == 200 & tv[3] == 0 & id[3] == 2
}
if _rc == 0 local ++pass
else local ++fail

**# An acute window that closes before entry is outside follow-up, not an error
* [90,200] with window(1 5) is active 91-95, wholly before entry 100. The
* default construction path used to stop with "start after stop".
local ++tests
capture noisily {
    clear
    input long id double(start stop) byte drug
    1 90 200 1
    2 150 250 2
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 100 200
    2 100 200
    end
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv) window(1 5)
    assert r(n_outside_window) == 1
    sort id start
    assert _N == 4
    assert start[1] == 100 & stop[1] == 200 & tv[1] == 0
    assert start[3] == 151 & stop[3] == 155 & tv[3] == 2
}
if _rc == 0 local ++pass
else local ++fail

**# fillgaps extends the episode that ends last, not the one that starts last
* [100,180] drug 1 encloses [110,120] drug 2. The last recorded stop is 180,
* so fillgaps(30) keeps drug 1 through 210. The old rule extended the
* latest-START episode (drug 2, to 150), which drug 1 already covered.
local ++tests
capture noisily {
    clear
    input long id double(start stop) byte drug
    1 100 180 1
    1 110 120 2
    end
    tempfile ep
    save `ep'
    clear
    input long id double(entry exit)
    1 100 300
    end
    tvexpose using `ep', id(id) start(start) stop(stop) exposure(drug) ///
        reference(0) entry(entry) exit(exit) generate(tv) fillgaps(30)
    sort start
    assert _N == 4
    assert start[1] == 100 & stop[1] == 109 & tv[1] == 1
    assert start[2] == 110 & stop[2] == 120 & tv[2] == 2
    assert start[3] == 121 & stop[3] == 210 & tv[3] == 1
    assert start[4] == 211 & stop[4] == 300 & tv[4] == 0
}
if _rc == 0 local ++pass
else local ++fail

**# fillgaps matches a daily oracle with nesting, equal stops, lag, washout
* Oracle: the episodes ending on the person's latest raw stop are extended by
* F; lag L then moves every start and drops an episode whose lagged start
* passes its (extended) stop; washout W extends every stop. On day d the
* active episode with the latest start wins, ties to the later source row.
* Coarse stop dates force equal-stop ties; long episodes force nesting.
local ++tests
capture noisily {
    local nbad = 0
    foreach cfg in "25 0 0" "25 5 0" "25 0 10" "40 7 12" {
        tokenize `cfg'
        local F = `1'
        local L = `2'
        local W = `3'
        forvalues seed = 1/20 {
            quietly {
                clear
                set seed `seed'
                set obs 5
                gen long id = _n
                gen double entry = 1000 + floor(runiform() * 15)
                gen double exit = entry + 40 + floor(runiform() * 80)
                tempfile master exp orc
                save `master'
                clear
                set obs 12
                gen long id = 1 + floor(runiform() * 5)
                gen long ord = _n
                gen double start = 990 + floor(runiform() * 60)
                gen double stop = start + 5 * floor(runiform() * 8)
                gen byte drug = 1 + floor(runiform() * 3)
                save `exp'
                bysort id: egen double maxstop = max(stop)
                gen double es = start + `L'
                gen double ee = stop + `F' * (stop == maxstop)
                drop if es > ee
                replace ee = ee + `W'
                keep id ord es ee drug
                tempfile eff
                save `eff'
                use `master', clear
                gen long n = exit - entry + 1
                expand n
                bysort id: gen double d = entry + _n - 1
                keep id d
                joinby id using `eff', unmatched(master)
                gen byte cover = _merge == 3 & es <= d & d <= ee
                replace drug = 0 if !cover
                replace es = . if !cover
                replace ord = . if !cover
                gsort id d -cover -es -ord
                by id d: keep if _n == 1
                keep id d drug
                rename drug oracle
                save `orc'
                use `master', clear
                tvexpose using `exp', id(id) start(start) stop(stop) ///
                    exposure(drug) reference(0) entry(entry) exit(exit) ///
                    generate(tv) fillgaps(`F') lag(`L') washout(`W')
                gen long n = stop - start + 1
                count if n < 1
                local bad = r(N)
                expand n
                bysort id start: gen double d = start + _n - 1
                keep id d tv
                merge 1:1 id d using `orc'
                count if _merge != 3 | tv != oracle
                local bad = `bad' + r(N)
            }
            if `bad' local ++nbad
        }
    }
    display as text "fillgaps oracle: `nbad' of 80 draws disagree"
    assert `nbad' == 0
}
if _rc == 0 local ++pass
else local ++fail

**# type(single): a first event in a coverage gap still ends follow-up
* id 1: event on day 5 falls in the gap between [1,3] and [7,10]; the later
* event on day 8 is not the first event. id 2: an event before its only
* interval is pre-study history and stays ignored. id 3: no event.
local ++tests
capture noisily {
    clear
    input long id double(start stop)
    1 1 3
    1 7 10
    2 5 9
    3 1 10
    end
    tempfile iv
    save `iv'
    clear
    input long id double eventdate
    1 5
    1 8
    2 2
    3 .
    end
    tvevent using `iv', id(id) date(eventdate) generate(outcome)
    assert r(N) == 3 & r(N_events) == 0
    sort id start
    assert id[1] == 1 & start[1] == 1 & stop[1] == 3 & outcome[1] == 0
    assert id[2] == 2 & start[2] == 5 & stop[2] == 9 & outcome[2] == 0
    assert id[3] == 3 & start[3] == 1 & stop[3] == 10 & outcome[3] == 0
}
if _rc == 0 local ++pass
else local ++fail

**# type(single): gap events with competing risks and flagged events coexist
* id 1 dies (compete) on day 125 in the gap 121-130: rows from 131 go.
* id 2 has a flagged event on day 140 and keeps its pre-event rows.
local ++tests
capture noisily {
    clear
    input long id double(start stop)
    1 100 120
    1 131 150
    2 100 150
    end
    tempfile iv
    save `iv'
    clear
    input long id double(evdt dth)
    1 . 125
    2 140 .
    end
    tvevent using `iv', id(id) date(evdt) compete(dth) generate(fail)
    sort id start
    assert _N == 2
    assert id[1] == 1 & stop[1] == 120 & fail[1] == 0
    assert id[2] == 2 & stop[2] == 140 & fail[2] == 1
}
if _rc == 0 local ++pass
else local ++fail

**# type(single): a pre-study event does not hide a later gap event
* Event on day 2 precedes the first interval and is ignored; the day-15 gap
* event is then the first in-study event and ends follow-up at [21,30].
local ++tests
capture noisily {
    clear
    input long id double(start stop)
    1 10 12
    1 21 30
    end
    tempfile iv
    save `iv'
    clear
    input long id double eventdate
    1 2
    1 15
    end
    tvevent using `iv', id(id) date(eventdate)
    assert _N == 1 & start == 10 & stop == 12 & _failure == 0
}
if _rc == 0 local ++pass
else local ++fail

**# type(recurring) keeps person-time after a gap event
local ++tests
capture noisily {
    clear
    input long id double(start stop)
    1 1 3
    1 7 10
    end
    tempfile iv
    save `iv'
    clear
    input long id double(ev1 ev2)
    1 5 8
    end
    tvevent using `iv', id(id) date(ev) type(recurring)
    sort start
    assert _N == 3
    assert _failure == (stop == 8)
    assert stop[3] == 10
}
if _rc == 0 local ++pass
else local ++fail

**# Band widths and anchors must be whole numbers; data untouched on refusal
local ++tests
capture noisily {
    clear
    input long id double(start stop ref)
    1 21915 21924 21915
    end
    datasignature set, reset
    capture noisily tvband, id(id) start(start) stop(stop) type(elapsed) ///
        origin(ref) width(1.5) generate(b)
    assert _rc == 198
    datasignature confirm
    capture noisily tvsplit, id(id) start(start) stop(stop) ///
        elapsed(ref, width(2.5))
    assert _rc == 198
    datasignature confirm
    capture noisily tvsplit, id(id) start(start) stop(stop) ///
        calendar(, anchor(2019.5))
    assert _rc == 198
    datasignature confirm
    * whole-day widths still split exactly on integer bounds
    tvsplit, id(id) start(start) stop(stop) elapsed(ref, width(3))
    assert _N == 4
    assert start == floor(start) & stop == floor(stop)
    assert start == 21915 + fuband
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_tvtools_v1173 tests=`tests' pass=`pass' fail=`fail' skip=0"
capture log close _all
if `fail' exit 1

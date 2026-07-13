*! crossval_tvevent_recurring.do -- recurrent-event PWP/AG formatting for tvevent
*!
*!  PART A  Independent in-Stata oracle (always runs). For randomized multi-event
*!          persons, the PWP stratum and gap-time clock are recomputed FROM THE
*!          EVENT-DATE SET (a different derivation than tvevent's running-sum over
*!          output rows): stratum at calendar date s = 1 + #{events < s}; the gap
*!          origin is (last event before s)+1, or the person's entry for stratum 1.
*!          tvevent's enum/t0/t must match this row-for-row.
*!  PART B  R cross-computation. R reads tvevent's (id,start,stop,ev)
*!          output and independently rebuilds the stratum and gap-time clock with
*!          its own cumulative logic; must agree exactly. Different language/engine.
*!
*!  Conventions checked: inclusive [start,stop]; event marked on the segment ending
*!  at the event date; next stratum begins at event_date+1; gap-time resets to 0.
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "crossval_tvevent_recurring.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

display as result "tvtools crossval: tvevent recurrent formatting -- $S_DATE $S_TIME"

**# Randomized recurrent fixture
* Build randomized recurrent data: each person has a base interval and
* 0-4 strictly-increasing interior event dates in wide format (ev1..ev4).
local K = 4
clear
set seed 71717
set obs 500
gen long id = _n
gen double entry = mdy(1,1,2010)
gen double exit  = entry + 1000
* draw up to K interior event offsets, strictly increasing
gen int nev = floor(runiform()*(`K'+1))          // 0..K events
forvalues k = 1/`K' {
    gen double off`k' = .
}
* sequential increasing offsets within (1, 999)
gen double _prev = 0
forvalues k = 1/`K' {
    replace off`k' = _prev + ceil(runiform()*180) if `k' <= nev
    replace _prev = off`k' if `k' <= nev
}
* keep only offsets that stay strictly inside the interval
forvalues k = 1/`K' {
    replace off`k' = . if !missing(off`k') & off`k' >= 999
}
forvalues k = 1/`K' {
    gen double ev`k' = entry + off`k' if !missing(off`k')
    format ev`k' %td
}
drop _prev off* nev

* interval (using) data: one base interval per person
preserve
keep id entry exit
rename entry start
rename exit stop
format start stop %td
tempfile iv
save `iv'
restore

* event data (master, in memory): id + wide event dates
keep id ev1 ev2 ev3 ev4
tempfile events
save `events'

**# Run tvevent with recurrent formatting
* Run tvevent with recurrent formatting
use `events', clear
tvevent using `iv', id(id) date(ev) type(recurring) generate(ev_flag) ///
    enum(stratum) gaptime gapstart(t0) gapstop(t) replace
tempfile tvout
save `tvout'

**# Part A: independent Stata oracle
* PART A: independent oracle from the event-date set
capture noisily {
    use `tvout', clear
    * bring the wide event dates back alongside each output row
    merge m:1 id using `events', nogen

    gen long enum_oracle = 1
    gen double origin_oracle = .
    forvalues k = 1/`K' {
        replace enum_oracle = enum_oracle + 1 if !missing(ev`k') & ev`k' < start
        replace origin_oracle = max(origin_oracle, ev`k') ///
            if !missing(ev`k') & ev`k' < start
    }
    * stratum > 1: origin = (last event before start) + 1; stratum 1: entry
    replace origin_oracle = origin_oracle + 1 if !missing(origin_oracle)
    bysort id (start): replace origin_oracle = start[1] if missing(origin_oracle)

    gen double t0_oracle = start - origin_oracle
    gen double t_oracle  = stop  - origin_oracle

    assert stratum == enum_oracle
    assert t0 == t0_oracle
    assert t  == t_oracle
    * sanity: every stratum's first row has gap-time 0
    bysort id (start): assert t0 == 0 if _n == 1 | stratum != stratum[_n-1]
}
if _rc == 0 {
    display as result "  PASS [A]: enum + gap-time match the event-date oracle (row-for-row)"
    local ++pass_count
}
else {
    display as error "  FAIL [A]: recurrent-formatting oracle mismatch (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A"
}

**# Part B: R cross-computation
_tvtools_qa_probe_rscript
local has_rscript = r(available)

if `has_rscript' {
    capture noisily {
        use `tvout', clear
        gen byte evb = (ev_flag > 0) & !missing(ev_flag)
        preserve
        keep id start stop evb stratum t0 t
        * strip %td formats so dates export as plain integers (not date strings)
        format start stop t0 t %12.0g
        local _input "$TVTOOLS_QA_RUN_DIR/_xv_recur.csv"
        local _script "$TVTOOLS_QA_RUN_DIR/_xv_recur.R"
        local _output "$TVTOOLS_QA_RUN_DIR/_xv_recur_r.txt"
        local _rlog "$TVTOOLS_QA_RUN_DIR/_xv_recur_r.log"
        export delimited id start stop evb stratum t0 t using "`_input'", replace
        restore
    }
    local _setup_rc = _rc
    if `_setup_rc' == 0 {
        capture file close _rf
        tempname _rf
        file open _rf using "`_script'", write replace
        file write _rf "args <- commandArgs(trailingOnly=TRUE)" _n
        file write _rf "d <- read.csv(args[1])" _n
        file write _rf "d <- d[order(d\$id, d\$start), ]" _n
        file write _rf "spl <- split(d, d\$id)" _n
        file write _rf "ok <- TRUE" _n
        file write _rf "for (g in spl) {" _n
        file write _rf "  prior <- cumsum(c(0, head(g\$evb, -1)))" _n
        file write _rf "  enum_r <- 1 + prior" _n
        file write _rf "  origin <- numeric(nrow(g))" _n
        file write _rf "  cur <- g\$start[1]" _n
        file write _rf "  for (i in seq_len(nrow(g))) {" _n
        file write _rf "    if (i==1 || enum_r[i] != enum_r[i-1]) cur <- g\$start[i]" _n
        file write _rf "    origin[i] <- cur" _n
        file write _rf "  }" _n
        file write _rf "  t0_r <- g\$start - origin; t_r <- g\$stop - origin" _n
        file write _rf "  if (any(enum_r != g\$stratum) || any(t0_r != g\$t0) || any(t_r != g\$t)) ok <- FALSE" _n
        file write _rf "}" _n
        file write _rf "writeLines(if (ok) 'MATCH' else 'MISMATCH', args[2])" _n
        file close _rf

        shell Rscript "`_script'" "`_input'" "`_output'" > "`_rlog'" 2>&1
        capture confirm file "`_output'"
        if _rc == 0 {
            file open _rr using "`_output'", read
            file read _rr _verdict
            file close _rr
            if "`_verdict'" == "MATCH" {
                display as result "  PASS [B]: R independently reproduces enum + gap-time"
                local ++pass_count
            }
            else {
                display as error "  FAIL [B]: R cross-computation reported `_verdict'"
                local ++fail_count
                local failed_tests "`failed_tests' B"
            }
        }
        else {
            display as error "  FAIL [B]: R produced no output (see `_rlog')"
            local ++fail_count
            local failed_tests "`failed_tests' B-R"
        }
    }
    else {
        display as error "  FAIL [B]: Stata setup for R cross-check failed (rc `_setup_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' B-setup"
    }
    capture erase "`_input'"
    capture erase "`_script'"
    capture erase "`_output'"
    capture erase "`_rlog'"
}
else {
    display as text "  SKIP [B]: Rscript not found"
    local ++skip_count
}

**# Summary
local test_count = `pass_count' + `fail_count' + `skip_count'
display as result _newline "tvevent recurrent crossval Results -- $S_DATE $S_TIME"
display as text "Checks: `test_count'"
display as text "Passed: `pass_count'"
display as text "Failed: `fail_count'"
display as text "Skipped: `skip_count'"
display "RESULT: crossval_tvevent_recurring tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
if `fail_count' > 0 {
    display as error "CROSSVAL FAILED: `failed_tests'"
    exit 1
}
display as result "ALL RECURRENT CROSSVAL CHECKS PASSED (or skipped)"

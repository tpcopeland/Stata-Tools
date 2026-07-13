*! crossval_tvsplit_lexis.do -- multi-timescale Lexis parity for tvsplit
*!
*! Three independent oracles confirm the Lexis grid tvsplit produces:
*!   PART A  Stata stsplit (the Stata-blessed multi-timescale splitter) -- age
*!           axis: same number of split records and same age-band set per person.
*!   PART B  R Epi::splitMulti (Carstensen's Lexis machinery) -- calendar + elapsed
*!           axes in DAY units, so cut dates are exact integers and parity is
*!           day-exact (age is excluded here because tvtools rounds each
*!           round(dob + a*365.25) boundary, a tvtools-specific convention).
*!   PART C  An independent in-Stata re-derivation (explicit cut enumeration, a
*!           different code path from the engine) -- exact, always runs offline.
*!
*! PART B skips only when Rscript is absent. Once R is available, a missing Epi
*! package, failed R process, or missing oracle output is a test failure.
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "crossval_tvsplit_lexis.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

display as result "tvtools crossval: tvsplit Lexis parity -- $S_DATE $S_TIME"

**# Independent cut-enumeration oracle
* PART C: independent cut-enumeration oracle (single person, exact)
*   entry=01jan2019, exit=entry+700; calendar(1) + elapsed(entry,day,200)
*   interior cuts (offsets): elapsed 200,400,600 ; calendar Jan1-2020 = 365
*   -> starts offsets {0,200,365,400,600}; stops {199,364,399,599,700}
local ++test_count
capture {
    clear
    set obs 1
    gen long id = 1
    gen double entry = mdy(1,1,2019)
    gen double exitd = entry + 700
    format entry exitd %td
    tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1)) ///
        elapsed(entry, width(200) unit(day) generate(fu))
    sort entry
    gen double soff = entry - mdy(1,1,2019)
    gen double eoff = exitd - mdy(1,1,2019)
    assert _N == 5
    assert soff[1]==0   & eoff[1]==199
    assert soff[2]==200 & eoff[2]==364
    assert soff[3]==365 & eoff[3]==399
    assert soff[4]==400 & eoff[4]==599
    assert soff[5]==600 & eoff[5]==700
}
if _rc==0 {
    display as result "  PASS [C.independent]: exact cut-enumeration grid"
    local ++pass_count
}
else {
    display as error "  FAIL [C.independent] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C.indep"
}

**# Stata stsplit parity on the age axis
* PART A: Stata stsplit parity on the age axis
*   tvband age width(1) must produce the same number of records and the same
*   set of integer ages per person as stsplit on an age-scaled stset.
local ++test_count
capture {
    clear
    set obs 6
    gen long id = _n
    gen double dob   = mdy(1,1,1955) + (_n-1)*220
    gen double entry = mdy(3,1,2010)
    gen double exitd = mdy(8,1,2016)
    gen byte dead = 0
    format dob entry exitd %td

    * --- tvtools: age bands ---
    preserve
    tvband, id(id) start(entry) stop(exitd) type(age) origin(dob) width(1) generate(ageb)
    bysort id ageb: keep if _n==1
    bysort id: gen long ntv = _N
    keep id ageb ntv
    sort id ageb
    tempfile tv
    save "`tv'"
    restore

    * --- Stata stsplit: age scale ---
    stset exitd, id(id) failure(dead) origin(time dob) enter(time entry) scale(365.25)
    stsplit ssage, at(0(1)120)
    * ssage carries the integer age (lower edge); count records per person
    bysort id ssage: keep if _n==1
    bysort id: gen long nss = _N
    keep id ssage nss
    rename ssage ageb
    sort id ageb
    tempfile ss
    save "`ss'"

    use "`tv'", clear
    merge 1:1 id ageb using "`ss'"
    * every tvtools age band matches an stsplit age band and vice versa
    assert _merge == 3
    assert ntv == nss
}
if _rc==0 {
    display as result "  PASS [A.stsplit]: age-band record/set parity vs stsplit"
    local ++pass_count
}
else {
    display as error "  FAIL [A.stsplit] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A.stsplit"
}

**# R Epi parity for calendar and elapsed axes
* PART B: R Epi::splitMulti parity (calendar + elapsed, day-exact)
local ++test_count
_tvtools_qa_probe_rscript
local has_r = r(available)

if `has_r' {
    capture {
        local W = 180
        clear
        set obs 8
        gen long id = _n
        gen double entry = mdy(1,1,2017) + (_n-1)*70
        gen double exitd = entry + 500 + (_n-1)*90
        format entry exitd %td

        * tvtools result
        preserve
        tvsplit, id(id) start(entry) stop(exitd) calendar(, width(1)) ///
            elapsed(entry, width(`W') unit(day) generate(fu))
        gen long tstart = entry
        gen long tstop  = exitd
        keep id tstart tstop
        sort id tstart
        tempfile tvb
        save "`tvb'"
        restore

        * export cohort for R (integer Stata days)
        gen long e0 = entry
        gen long e1 = exitd
        keep id e0 e1
        local _cohort "$TVTOOLS_QA_RUN_DIR/_xv_cohort.csv"
        local _rscript "$TVTOOLS_QA_RUN_DIR/_xv_lexis.R"
        local _rout "$TVTOOLS_QA_RUN_DIR/_xv_rsplit.csv"
        local _rlog "$TVTOOLS_QA_RUN_DIR/_xv_r.log"
        export delimited id e0 e1 using "`_cohort'", replace

        * R script: Lexis in day units, split on calendar Jan-1 and elapsed W
        tempname rf
        file open `rf' using "`_rscript'", write replace
        file write `rf' "args <- commandArgs(trailingOnly=TRUE)" _n
        file write `rf' "suppressMessages(library(Epi))" _n
        file write `rf' "d <- read.csv(args[1])" _n
        * tvtools intervals are inclusive [start,stop]; Epi Lexis is half-open
        * [entry,exit). Passing exit = e1 + 1 makes Epi's [e0, e1+1) match the
        * inclusive convention day-for-day (stop_inclusive = per + lex.dur - 1).
        file write `rf' "lx <- Lexis(entry=list(per=d\$e0, tfe=0)," _n
        file write `rf' "            exit=list(per=d\$e1 + 1), exit.status=0, id=d\$id, data=d)" _n
        file write `rf' "yr0 <- as.numeric(format(as.Date(min(d\$e0),origin='1960-01-01'),'%Y'))" _n
        file write `rf' "yr1 <- as.numeric(format(as.Date(max(d\$e1),origin='1960-01-01'),'%Y'))+1" _n
        file write `rf' "jan1 <- as.numeric(as.Date(paste0(yr0:yr1,'-01-01')) - as.Date('1960-01-01'))" _n
        file write `rf' "maxsp <- max(d\$e1 - d\$e0) + `W'" _n
        file write `rf' "tcuts <- seq(0, maxsp, by=`W')" _n
        file write `rf' "sx <- splitLexis(lx, breaks=jan1, time.scale='per')" _n
        file write `rf' "sx <- splitLexis(sx, breaks=tcuts, time.scale='tfe')" _n
        file write `rf' "out <- data.frame(id=sx\$lex.id, rstart=sx\$per, rstop=sx\$per+sx\$lex.dur-1)" _n
        file write `rf' "out <- out[order(out\$id, out\$rstart),]" _n
        file write `rf' "write.csv(out, args[2], row.names=FALSE)" _n
        file close `rf'

        shell Rscript "`_rscript'" "`_cohort'" "`_rout'" > "`_rlog'" 2>&1

        capture confirm file "`_rout'"
        if _rc {
            display as error "R oracle failed; see `_rlog'"
            error 499
        }

        import delimited using "`_rout'", clear varnames(1)
        rename rstart tstart
        rename rstop  tstop
        gen long idl = id
        drop id
        rename idl id
        sort id tstart
        * compare row-for-row to tvtools
        tempfile rsp
        save "`rsp'"
        use "`tvb'", clear
        sort id tstart
        cf _all using "`rsp'"
    }
    local xrc = _rc
    capture erase "`_cohort'"
    capture erase "`_rscript'"
    capture erase "`_rout'"
    capture erase "`_rlog'"
    if `xrc'==0 {
        display as result "  PASS [B.Epi]: day-exact calendar+elapsed parity vs Epi::splitMulti"
        local ++pass_count
    }
    else {
        display as error "  FAIL [B.Epi] (rc=`xrc')"
        local ++fail_count
        local failed_tests "`failed_tests' B.Epi"
    }
}
else {
    display as text "  SKIP [B.Epi]: Rscript not found"
    local ++skip_count
}

**# Summary
local test_count = `pass_count' + `fail_count' + `skip_count'
display as result _newline "tvtools crossval tvsplit Lexis Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display as text "Skipped:    `skip_count'"
display "RESULT: crossval_tvsplit_lexis tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

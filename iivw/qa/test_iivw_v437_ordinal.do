* test_iivw_v437_ordinal.do
* Regression for 4.3.7: the trimming message names percentiles with correct
* English ordinals ("1st and 99th percentiles"; 4.3.6 printed "1th").
* budget: 5
*
*   T1  truncfinal(1 99), truncvisit(2 98), trunctreat(3 97): 1st/2nd/3rd
*   T2  11, 12 and 13 take "th"; 21 takes "st"; one-sided requests name one
*       ordinal ("the 91st percentile (upper tail only)")
*   T3  a non-integer percentile (2.5) takes "th"
* guard: T3 is expected green at HEAD (behaviour-preservation: non-integer percentiles keep "th")
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v437_ordinal.do [case#]

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_v437"

capture program drop _v437_panel
program define _v437_panel
    version 16.0
    clear
    set rng mt64s
    set rngstream 1
    set seed 4713
    quietly set obs 150
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    quietly expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    quietly drop if runiform() > keeppr & j > 1
    sort id t
end

* Run iivw_weight under a text log; return the trimming lines as one string.
capture program drop _v437_run
program define _v437_run, rclass
    version 16.0
    syntax , OPTS(string) LOG(string)
    _v437_panel
    quietly log using "`log'", text replace name(v437)
    capture noisily iivw_weight, id(id) time(t) visit_cov(z1) treat(a) ///
        treat_cov(k1) wtype(fiptiw) maxfu(7) nolog `opts'
    local rc = _rc
    quietly log close v437
    mata: st_local("txt", invtokens(select(cat(st_local("log")), ///
        strpos(cat(st_local("log")), "Trimming the") :> 0)', "|"))
    return scalar rc = `rc'
    return local txt `"`txt'"'
end


local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _v437_run, opts(truncfinal(1 99) truncvisit(2 98) trunctreat(3 97)) log("`work'_1.log")
    assert r(rc) == 0
    local txt `"`r(txt)'"'
    assert strpos(`"`txt'"', "VISIT component at the 2nd and 98th percentiles") > 0
    assert strpos(`"`txt'"', "TREATMENT component at the 3rd and 97th percentiles") > 0
    assert strpos(`"`txt'"', "FINAL weight at the 1st and 99th percentiles") > 0
    assert strpos(`"`txt'"', "1th") == 0 & strpos(`"`txt'"', "2th") == 0 & strpos(`"`txt'"', "3th") == 0
    display as result "T1 PASS: 1st, 2nd and 3rd"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T1"
    display as error "T1 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _v437_run, opts(truncfinal(11 99) truncvisit(12 98) trunctreat(21 87)) log("`work'_2.log")
    assert r(rc) == 0
    local txt `"`r(txt)'"'
    assert strpos(`"`txt'"', "VISIT component at the 12th and 98th percentiles") > 0
    assert strpos(`"`txt'"', "TREATMENT component at the 21st and 87th percentiles") > 0
    assert strpos(`"`txt'"', "FINAL weight at the 11th and 99th percentiles") > 0
    _v437_run, opts(truncfinal(0 91)) log("`work'_2b.log")
    assert r(rc) == 0
    assert strpos(`"`r(txt)'"', "FINAL weight at the 91st percentile (upper tail only)") > 0
    _v437_run, opts(truncfinal(13 100)) log("`work'_2c.log")
    assert r(rc) == 0
    assert strpos(`"`r(txt)'"', "FINAL weight at the 13th percentile (lower tail only)") > 0
    display as result "T2 PASS: teens take th; 21st; one-sided wording"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T2"
    display as error "T2 FAIL"
}
}

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _v437_run, opts(truncfinal(2.5 97.5)) log("`work'_3.log")
    assert r(rc) == 0
    assert strpos(`"`r(txt)'"', "FINAL weight at the 2.5th and 97.5th percentiles") > 0
    display as result "T3 PASS: non-integer percentile"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' T3"
    display as error "T3 FAIL"
}
}

**# Summary

iivw_qa_summary, name(test_iivw_v437_ordinal) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")

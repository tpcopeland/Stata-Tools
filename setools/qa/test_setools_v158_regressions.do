* test_setools_v158_regressions.do
* Regressions fixed in setools 1.5.8.
*
* W1-W3 - pira anchored its relapse window on the relapse instead of on the
*   progression onset. It classified a first CDP as RAW when
*       relapse - windowbefore <= CDP onset <= relapse + windowafter,
*   i.e. when a relapse began up to 30 days BEFORE the onset or up to 90 days
*   AFTER it under the defaults. The published rule is the mirror image: no
*   relapse within 90 days before and 30 days after the disability-worsening
*   event (Kappos et al. 2020, JAMA Neurol 77:1132 - RAW when the initial
*   increase is preceded by a relapse in the last 90 days; Portaccio et al.
*   2024, J Neurol 271:5074 - PIRA is a CDA event ">90 days after and >30 days
*   before the onset of a relapse"). On 1.5.7 a progression 60 days after a
*   relapse (textbook RAW) was returned as PIRA at rc=0, and a progression 60
*   days before an unrelated later relapse was returned as RAW. Expected values
*   below are hand-derived from the published rule, not from the code.
*
* W4 - relapses() rejected a filename without an extension (r(601)) although
*   -use- resolves it to the .dta file, as migrations' migfile() already does.
*
* I1-I3 - cci_se windowed each diagnosis row by that row's own indexdate().
*   Conflicting index dates within one id() silently mixed two lookback
*   periods into one patient-level score. 1.5.8 errors r(459), matching the
*   person-level date contract of cdp/pira/sustainedss.

clear all
set more off
set varabbrev off

**# Bootstrap
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar rg_tests = 0
scalar rg_pass = 0
scalar rg_fail = 0
capture program drop rg_check
program define rg_check
    args label ok
    scalar rg_tests = rg_tests + 1
    if `ok' {
        scalar rg_pass = rg_pass + 1
        display as result "  PASS: `label'"
    }
    else {
        scalar rg_fail = rg_fail + 1
        display as error "  FAIL: `label'"
    }
end

**# Shared EDSS fixture
* Every person has the same history: baseline EDSS 2.0 on day 700 (= dx),
* progression to 3.5 on day 1060 (the CDP onset), confirmed on day 1300.
* Only the relapse date differs. Offsets are relapse day minus onset day.
local offsets "-91 -90 -60 0 30 31 60"
local npers : word count `offsets'

tempfile edss rel
clear
set obs `=3 * `npers''
gen long id = ceil(_n / 3)
gen byte k = mod(_n - 1, 3) + 1
gen double edss = cond(k == 1, 2.0, 3.5)
gen long edss_dt = cond(k == 1, 700, cond(k == 2, 1060, 1300))
gen long dx_date = 700
drop k
format edss_dt dx_date %td
save `edss', replace

clear
set obs `npers'
gen long id = _n
gen long relapse_date = .
forvalues i = 1/`npers' {
    local off : word `i' of `offsets'
    quietly replace relapse_date = 1060 + `off' in `i'
}
format relapse_date %td
save `rel', replace

**# W1: default window [onset - 90, onset + 30] classifies each offset
use `edss', clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`rel'") ///
    keepall quietly
local ok = (_rc == 0)
local n_pira = r(N_pira)
local n_raw = r(N_raw)
if `ok' {
    quietly bysort id: keep if _n == 1
    * Hand classification under the published rule (RAW iff -90 <= off <= 30)
    local i = 0
    foreach off of local offsets {
        local ++i
        local want_raw = inrange(`off', -90, 30)
        quietly count if id == `i' & raw_date == 1060 & missing(pira_date)
        local is_raw = (r(N) == 1)
        quietly count if id == `i' & pira_date == 1060 & missing(raw_date)
        local is_pira = (r(N) == 1)
        local got = cond(`want_raw', `is_raw', `is_pira')
        if !`got' {
            local ok = 0
            display as error "    offset `off': expected " ///
                cond(`want_raw', "RAW", "PIRA")
        }
    }
}
rg_check "W1: default window is anchored on the CDP onset (-90..+30 RAW)" `ok'
rg_check "W1b: default counts N_pira=3 (offsets -91,31,60) N_raw=4" ///
    `=(`n_pira' == 3 & `n_raw' == 4)'

**# W2: the two options map to the documented sides
* windowbefore(10) windowafter(0): only a relapse 0-10 days BEFORE onset is RAW.
clear
input long id long relapse_date
1 1050
2 1049
3 1061
4 1060
end
format relapse_date %td
tempfile rel_asym
save `rel_asym', replace

use `edss', clear
quietly keep if id <= 4
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`rel_asym'") ///
    windowbefore(10) windowafter(0) keepall quietly
local ok = (_rc == 0)
if `ok' {
    quietly bysort id: keep if _n == 1
    quietly count if id == 1 & raw_date == 1060
    local ok = (`ok' & r(N) == 1)
    quietly count if id == 2 & pira_date == 1060
    local ok = (`ok' & r(N) == 1)
    quietly count if id == 3 & pira_date == 1060
    local ok = (`ok' & r(N) == 1)
    quietly count if id == 4 & raw_date == 1060
    local ok = (`ok' & r(N) == 1)
}
rg_check "W2: windowbefore() looks back from onset, windowafter() forward" `ok'

* windowbefore(0) windowafter(10): only a relapse 0-10 days AFTER onset is RAW.
use `edss', clear
quietly keep if id <= 4
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`rel_asym'") ///
    windowbefore(0) windowafter(10) keepall quietly
local ok = (_rc == 0)
if `ok' {
    quietly bysort id: keep if _n == 1
    quietly count if id == 1 & pira_date == 1060
    local ok = (`ok' & r(N) == 1)
    quietly count if id == 2 & pira_date == 1060
    local ok = (`ok' & r(N) == 1)
    quietly count if id == 3 & raw_date == 1060
    local ok = (`ok' & r(N) == 1)
    quietly count if id == 4 & raw_date == 1060
    local ok = (`ok' & r(N) == 1)
}
rg_check "W3: windowafter() alone admits only post-onset relapses" `ok'

**# W4: relapses() without an extension resolves to the .dta file
local stub "`c(tmpdir)'/_setools_v158_relstub_`c(current_time)'"
local stub = subinstr("`stub'", ":", "", .)
capture erase "`stub'.dta"
use `rel', clear
quietly save "`stub'.dta", replace
use `edss', clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`stub'") ///
    keepall quietly
local rc_noext = _rc
local np_noext = r(N_pira)
local nr_noext = r(N_raw)
capture erase "`stub'.dta"
rg_check "W4: relapses() without .dta runs and matches W1 counts" ///
    `=(`rc_noext' == 0 & `np_noext' == `n_pira' & `nr_noext' == `n_raw')'

**# I1: cci_se rejects conflicting index dates within one id
clear
input long id str10 icd long visit_date long ix
1 "I21" 21000 21500
1 "C78" 21400 21300
2 "I50" 21000 21500
end
format visit_date ix %td
tempfile cci_in
save `cci_in', replace
datasignature
local sig_before "`r(datasignature)'"
capture noisily cci_se, id(id) icd(icd) date(visit_date) indexdate(ix)
local rc = _rc
datasignature
local sig_after "`r(datasignature)'"
rg_check "I1: conflicting indexdate() within id errors r(459)" `=(`rc' == 459)'
rg_check "I1b: the error leaves the data unchanged" ///
    `=("`sig_before'" == "`sig_after'")'
capture confirm variable charlson
rg_check "I1c: no score variable is created on the error path" `=(_rc != 0)'

**# I2: a constant index date with missing-index rows keeps working
* Person 1: MI before index (1), metastasis after index (excluded) -> 1.
* The missing-index row is dropped with a note, as documented.
clear
input long id str10 icd long visit_date long ix
1 "I21" 21000 21300
1 "C78" 21400 21300
1 "I50" 21100 .
2 "I50" 21000 21500
end
format visit_date ix %td
capture noisily cci_se, id(id) icd(icd) date(visit_date) indexdate(ix)
local ok = (_rc == 0)
if `ok' {
    quietly count if id == 1 & charlson == 1
    local ok = (r(N) == 1)
    quietly count if id == 2 & charlson == 1
    local ok = (`ok' & r(N) == 1)
}
rg_check "I2: constant indexdate() plus missing-index rows scores 1 and 1" `ok'

**# I3: the constancy check is scoped to the if/in sample
use `cci_in', clear
capture noisily cci_se if icd != "C78", id(id) icd(icd) date(visit_date) ///
    indexdate(ix)
local ok = (_rc == 0)
if `ok' {
    quietly count if id == 1 & charlson == 1
    local ok = (r(N) == 1)
}
rg_check "I3: a conflict only outside the if() sample is not an error" `ok'

**# Summary
display as result "Results: " rg_pass "/" rg_tests " passed, " rg_fail " failed"
display "RESULT: test_setools_v158_regressions tests=" rg_tests ///
    " pass=" rg_pass " fail=" rg_fail
if rg_fail > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
display as result "ALL TESTS PASSED"

do "`qa_dir'/_setools_qa_common.do" teardown

clear all
set varabbrev off
version 16.0

capture log close
log using "validation_cci_se_date_hierarchy.log", replace nomsg

* validation_cci_se_date_hierarchy.do
* Known-answer coverage for the cci_se dates() hierarchy PROMOTION arithmetic
* (cci_se.ado lines ~322-340). _test_cci_dates.do only checks that each
* component date is nonmissing iff the indicator is 1; it never verifies the
* date value produced when the Charlson hierarchy promotes/clears a component:
*   - mild liver (13) + ascites (14)  -> severe (15); severe date = max(mild,
*     ascites) diagnosis dates; mild-liver date cleared.
*   - a DIRECT severe code keeps its own (earlier) date when no ascites promotes.
*   - diabetes uncomplicated (10) cleared (date -> .) when complicated (11) present.
*   - non-metastatic cancer (17) cleared (date -> .) when metastatic (18) present.
* Oracle is hand-computed from the diagnosis dates below (all ICD-10, year>=1998).
* Run from setools/qa:
*   stata-mp -b do validation_cci_se_date_hierarchy.do

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

capture program drop runval
program define runval
    args name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  PASS: `name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  FAIL: `name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
    }
end
scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0

**# Build diagnosis-level data with the four hierarchy scenarios
clear
input id str10 icd str10 dstr
1 "K73"  "2010-01-01"
1 "R18"  "2010-06-01"
2 "E109" "2011-01-01"
2 "E102" "2011-03-01"
3 "C50"  "2012-01-01"
3 "C78"  "2012-05-01"
4 "I850" "2013-01-01"
4 "K73"  "2013-06-01"
end
gen date = daily(dstr, "YMD")
format date %td
drop dstr

cci_se, id(id) icd(icd) date(date) dates

**# Scenario A (id 1): mild + ascites promote to severe; severe date = max
quietly count if id == 1 & charlson == 3
local ok = (r(N) == 1)
runval "A: mild+ascites -> Charlson 3 (severe liver weight)" `ok'
quietly count if id == 1 & cci_livsev == 1 & cci_livsev_date == td(01jun2010)
local ok = (r(N) == 1)
runval "A: livsev_date == max(mild,ascites) == 2010-06-01" `ok'
quietly count if id == 1 & cci_livmild == 0 & missing(cci_livmild_date)
local ok = (r(N) == 1)
runval "A: mild-liver cleared, mild date wiped" `ok'

**# Scenario D (id 4): direct severe code keeps its own earlier date (no ascites)
quietly count if id == 4 & cci_livsev == 1 & cci_livsev_date == td(01jan2013)
local ok = (r(N) == 1)
runval "D: direct severe date preserved (no false promotion)" `ok'
quietly count if id == 4 & cci_livmild == 0 & missing(cci_livmild_date)
local ok = (r(N) == 1)
runval "D: mild-liver cleared under direct severe" `ok'

**# Scenario B (id 2): diabetes complicated clears uncomplicated (+ its date)
quietly count if id == 2 & charlson == 2 & cci_diabcomp == 1 & cci_diabcomp_date == td(01mar2011)
local ok = (r(N) == 1)
runval "B: diabcomp retained with its date" `ok'
quietly count if id == 2 & cci_diab == 0 & missing(cci_diab_date)
local ok = (r(N) == 1)
runval "B: uncomplicated diabetes cleared, date wiped" `ok'

**# Scenario C (id 3): metastatic clears non-metastatic (+ its date)
quietly count if id == 3 & charlson == 6 & cci_mets == 1 & cci_mets_date == td(01may2012)
local ok = (r(N) == 1)
runval "C: metastatic retained with its date" `ok'
quietly count if id == 3 & cci_cancer == 0 & missing(cci_cancer_date)
local ok = (r(N) == 1)
runval "C: non-metastatic cancer cleared, date wiped" `ok'

**# Invariant: after hierarchy, no component has a date without its indicator set
local anybad = 0
foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab diabcomp renal ///
             livmild livsev pud cancer mets aids {
    quietly count if cci_`v' == 0 & !missing(cci_`v'_date)
    if r(N) > 0 local anybad = 1
}
local ok = (`anybad' == 0)
runval "Invariant: no date survives a cleared indicator" `ok'

**# Summary
display as text _n "{hline 60}"
display "RESULT: validation_cci_se_date_hierarchy tests=" scalar(gs_ntest) ///
    " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    log close _all
    exit 1
}
display as result "ALL TESTS PASSED"
scalar drop gs_ntest gs_npass gs_nfail
log close _all

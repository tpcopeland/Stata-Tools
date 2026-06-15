clear all
version 16.0
capture log close _all
log using "test_setools_v140_features.log", replace nomsg
set varabbrev off

* test_setools_v140_features.do
* Coverage for v1.4.0 additions, all opt-in:
*   sustainedss/cdp/pira : exit(varname) post-exit event censoring
*   migrations           : broadened long-format event_type recognition (R1),
*                          intype()/outtype() overrides, unrecognized diagnostic,
*                          flag mode (U3), r(flow) CONSORT matrix (O1)
*   cci_se               : zero-match smell diagnostic (R2)
* Run from setools/qa:
*   stata-mp -b do test_setools_v140_features.do

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_val
program define run_val
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  PASS: `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  FAIL: `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures "${gs_failures}; `test_name'"
    }
end

capture program drop make_edss
program define make_edss
    quietly {
        gen date = daily(dstr, "YMD")
        format date %td
        gen exitd = daily(exitstr, "YMD")
        format exitd %td
        drop dstr exitstr
    }
end

**# sustainedss: exit() censors a post-exit event, keeps a pre-exit event
clear
input id edss str10 dstr str10 exitstr
1 3.0 "2010-01-01" "2010-06-01"
1 6.0 "2010-07-01" "2010-06-01"
1 6.0 "2011-02-01" "2010-06-01"
2 3.0 "2010-01-01" "2012-01-01"
2 6.0 "2010-07-01" "2012-01-01"
2 6.0 "2011-02-01" "2012-01-01"
3 3.0 "2010-01-01" ""
3 6.0 "2010-07-01" ""
3 6.0 "2011-02-01" ""
end
make_edss
sustainedss id edss date, threshold(6) confirmwindow(30) keepall ///
    eventvar(ss_ev) exit(exitd) quietly
local ncens = r(N_censored_exit)
local nev = r(N_events)
local exname = "`r(exit)'"
quietly count if id == 1 & ss_ev == 0 & missing(sustained6_dt)
local ok = (r(N) == 3)
run_val "sustainedss exit() censors post-exit event (id1)" `ok'
quietly count if id == 2 & ss_ev == 1 & !missing(sustained6_dt)
local ok = (r(N) == 3)
run_val "sustainedss exit() keeps pre-exit event (id2)" `ok'
quietly count if id == 3 & ss_ev == 1 & !missing(sustained6_dt)
local ok = (r(N) == 3)
run_val "sustainedss exit() missing exit left intact (id3)" `ok'
local ok = (`ncens' == 1)
run_val "sustainedss r(N_censored_exit) == 1" `ok'
local ok = (`nev' == 2)
run_val "sustainedss r(N_events) post-censor == 2" `ok'
local ok = ("`exname'" == "exitd")
run_val "sustainedss r(exit) macro set" `ok'

* exit() must be a %td daily date
clear
input id edss str10 dstr
1 6.0 "2010-07-01"
1 6.0 "2011-02-01"
end
gen date = daily(dstr, "YMD")
format date %td
gen exitm = mofd(date)
format exitm %tm
cap noi sustainedss id edss date, threshold(6) exit(exitm) quietly
local ok = (_rc == 109)
run_val "sustainedss exit() rejects non-%td rc109" `ok'

**# cdp: exit() censors post-exit CDP, keeps pre-exit CDP
clear
input id edss str10 dstr str10 exitstr
1 1.0 "2010-01-01" "2010-06-01"
1 3.0 "2010-07-01" "2010-06-01"
1 3.0 "2011-02-01" "2010-06-01"
2 1.0 "2010-01-01" "2012-06-01"
2 3.0 "2010-07-01" "2012-06-01"
2 3.0 "2011-02-01" "2012-06-01"
end
make_edss
gen dx = daily("2010-01-01", "YMD")
format dx %td
cdp id edss date, dxdate(dx) keepall eventvar(cdp_ev) exit(exitd) quietly
local ncens = r(N_censored_exit)
local exname = "`r(exit)'"
quietly count if id == 1 & cdp_ev == 0 & missing(cdp_date)
local ok = (r(N) == 3)
run_val "cdp exit() censors post-exit CDP (id1)" `ok'
quietly count if id == 2 & cdp_ev == 1 & !missing(cdp_date)
local ok = (r(N) == 3)
run_val "cdp exit() keeps pre-exit CDP (id2)" `ok'
local ok = (`ncens' == 1)
run_val "cdp r(N_censored_exit) == 1" `ok'
local ok = ("`exname'" == "exitd")
run_val "cdp r(exit) macro set" `ok'

**# pira: exit() censors both PIRA and RAW dates
clear
input str10 dstr2
"2030-01-01"
end
gen id = 1
gen relapse_date = daily(dstr2, "YMD")
format relapse_date %td
drop dstr2
tempfile rel
save `rel'
clear
input id edss str10 dstr str10 exitstr
1 1.0 "2010-01-01" "2010-06-01"
1 3.0 "2010-07-01" "2010-06-01"
1 3.0 "2011-02-01" "2010-06-01"
2 1.0 "2010-01-01" "2015-01-01"
2 3.0 "2010-07-01" "2015-01-01"
2 3.0 "2011-02-01" "2015-01-01"
end
make_edss
gen dx = daily("2010-01-01", "YMD")
format dx %td
pira id edss date, dxdate(dx) relapses("`rel'") keepall ///
    eventvar(pira_ev) exit(exitd) quietly
local ncens = r(N_censored_exit)
local exname = "`r(exit)'"
quietly count if id == 1 & pira_ev == 0 & missing(pira_date) & missing(raw_date)
local ok = (r(N) == 3)
run_val "pira exit() censors post-exit PIRA+RAW (id1)" `ok'
quietly count if id == 2 & pira_ev == 1 & !missing(pira_date)
local ok = (r(N) == 3)
run_val "pira exit() keeps pre-exit PIRA (id2)" `ok'
local ok = (`ncens' == 1)
run_val "pira r(N_censored_exit) == 1" `ok'
local ok = ("`exname'" == "exitd")
run_val "pira r(exit) macro set" `ok'

**# migrations: master cohort + long files
clear
set obs 5
gen long id = _n
gen long study_start = td(01jan2018)
format study_start %td
tempfile master
save `master', replace

* Long file with FULL Swedish words (R1 reproduced failure)
clear
input long id double event_date str20 event_type
2 . "Utvandring"
3 . "Invandring"
4 . "Utvandring"
4 . "Invandring"
end
replace event_date = td(01jun2020) in 1
replace event_date = td(20feb2018) in 2
replace event_date = td(01dec2016) in 3
replace event_date = td(01feb2018) in 4
format event_date %td
tempfile migSwe
save `migSwe', replace

**# R1: full Swedish words recognized
use `master', clear
cap noi migrations, migfile("`migSwe'")
local ok = (_rc == 0)
run_val "migrations recognizes Invandring/Utvandring rc0" `ok'

**# O1: r(flow) matrix returned with CONSORT rows
use `master', clear
quietly migrations, migfile("`migSwe'")
matrix F = r(flow)
local nr = rowsof(F)
local cstart = F[1,1]
local exctot = r(N_excluded_total)
local nfinal = r(N_final)
local ok = (`nr' == 7)
run_val "migrations r(flow) has 7 rows (no minres/keepimm)" `ok'
local ok = (`cstart' == 5)
run_val "migrations r(flow) Cohort_start == 5" `ok'
local ok = (`nfinal' == 5 - `exctot')
run_val "migrations r(flow) Final == start - excluded" `ok'

**# U3: flag mode retains all rows, marks exclusions
use `master', clear
cap noi migrations, migfile("`migSwe'") flag
local rc = _rc
local ok = (`rc' == 0)
run_val "migrations flag mode rc0" `ok'
quietly count
local ok = (r(N) == 5)
run_val "migrations flag retains full cohort (N==5)" `ok'
quietly count if mig_excluded == 1 & trim(mig_exclude_reason) != ""
local ok = (r(N) > 0)
run_val "migrations flag marks excluded with reason" `ok'
capture confirm variable mig_excluded
local ok = (_rc == 0)
run_val "migrations flag creates mig_excluded" `ok'

**# U3: flag preflight collision
use `master', clear
gen byte mig_excluded = 0
cap noi migrations, migfile("`migSwe'") flag
local ok = (_rc == 110)
run_val "migrations flag preflight collision rc110" `ok'

**# R1: unlabeled numeric codes via intype()/outtype()
clear
input long id double event_date byte event_type
2 . 2
3 . 1
4 . 2
end
replace event_date = td(01jun2020) in 1
replace event_date = td(20feb2018) in 2
replace event_date = td(01dec2016) in 3
format event_date %td
tempfile migNum
save `migNum', replace
use `master', clear
cap noi migrations, migfile("`migNum'") intype(1) outtype(2)
local ok = (_rc == 0)
run_val "migrations intype()/outtype() numeric override rc0" `ok'

* unlabeled numeric WITHOUT override -> clear rc109
use `master', clear
cap noi migrations, migfile("`migNum'")
local ok = (_rc == 109)
run_val "migrations unlabeled numeric no override rc109" `ok'

* intype()/outtype() must be disjoint
use `master', clear
cap noi migrations, migfile("`migSwe'") intype(in) outtype(in)
local ok = (_rc == 198)
run_val "migrations intype/outtype overlap rc198" `ok'

**# R1: unrecognized event_type -> clear rc198 diagnostic
clear
input long id double event_date str20 event_type
2 . "Ovrigt"
3 . "Ovrigt"
end
replace event_date = td(01jun2020)
format event_date %td
tempfile migBad
save `migBad', replace
use `master', clear
cap noi migrations, migfile("`migBad'")
local ok = (_rc == 198)
run_val "migrations unrecognized event_type rc198" `ok'

**# R2: cci_se zero-match diagnostic
* Codes present but NONE are Charlson components -> N_any == 0, rc0
clear
input id str10 icd str10 dstr
1 "O80"  "2010-06-15"
1 "S720" "2010-06-15"
2 "Z000" "2010-06-15"
2 "M545" "2010-06-15"
end
gen date = daily(dstr, "YMD")
format date %td
drop dstr
cap noi cci_se, id(id) icd(icd) date(date)
local rc = _rc
local nany = r(N_any)
local ok = (`rc' == 0)
run_val "cci_se zero-match path succeeds rc0" `ok'
local ok = (`nany' == 0)
run_val "cci_se zero-match N_any == 0" `ok'

* A real MI code present -> N_any > 0 (no false alarm on real matches)
clear
input id str10 icd str10 dstr
1 "I21"  "2010-06-15"
1 "O80"  "2010-06-15"
2 "E119" "2010-06-15"
end
gen date = daily(dstr, "YMD")
format date %td
drop dstr
cci_se, id(id) icd(icd) date(date)
local ok = (r(N_any) > 0)
run_val "cci_se real matches give N_any > 0" `ok'

**# Summary
display as text _n "{hline 60}"
display "RESULT: test_setools_v140_features tests=" scalar(gs_ntest) ///
    " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS:${gs_failures}"
    log close _all
    error 9
}
display as result "ALL TESTS PASSED"
scalar drop gs_ntest gs_npass gs_nfail
global gs_failures
log close _all

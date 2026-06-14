clear all
version 16.0
capture log close _all
log using "test_setools_v130_features.log", replace nomsg
set varabbrev off

* test_setools_v130_features.do
* Coverage for v1.3.0 additions and bug fixes:
*   cdp/pira : threetier, confirmtype(sustained|visit), eventvar(), r(converged)
*   sustainedss: eventvar()
*   cci_se   : indexdate(), lookback(), separator-insensitive ICD-7/8 matching
*   pira     : relapseidvar()/relapsedatevar() (non-default names + type mismatch)
*   migrations: exclude_reason no longer leaks; _mig_*/_neg_* namespace preflight
* Run from setools/qa:
*   stata-mp -b do test_setools_v130_features.do

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
    syntax , dx(string)
    quietly {
        gen date = daily(dstr, "YMD")
        format date %td
        gen dx = daily("`dx'", "YMD")
        format dx %td
        drop dstr
    }
end

**# cdp: three-tier vs two-tier at baseline 0
clear
input id edss str10 dstr
1 0.0 "2010-01-01"
1 1.0 "2010-07-01"
1 1.0 "2011-02-01"
end
make_edss, dx("2010-01-01")
preserve
cdp id edss date, dxdate(dx) keepall quietly
local n = r(N_events)
local tt = "`r(threetier)'"
local ok = (`n' == 1 & "`tt'" == "no")
run_val "cdp two-tier: baseline-0 +1.0 is CDP" `ok'
restore, preserve
cdp id edss date, dxdate(dx) threetier keepall quietly
local n = r(N_events)
local tt = "`r(threetier)'"
local ok = (`n' == 0 & "`tt'" == "yes")
run_val "cdp threetier: baseline-0 +1.0 is NOT CDP" `ok'
restore

**# cdp: confirmtype sustained vs visit (later dip below threshold)
clear
input id edss str10 dstr
1 1.0 "2010-01-01"
1 2.0 "2010-07-01"
1 2.0 "2011-01-05"
1 1.0 "2012-01-01"
end
make_edss, dx("2010-01-01")
preserve
cdp id edss date, dxdate(dx) confirmtype(sustained) keepall quietly
local n = r(N_events)
local ct = "`r(confirmtype)'"
local ok = (`n' == 0 & "`ct'" == "sustained")
run_val "cdp confirmtype(sustained) rejects later dip" `ok'
restore, preserve
cdp id edss date, dxdate(dx) confirmtype(visit) keepall quietly
local n = r(N_events)
local ct = "`r(confirmtype)'"
local ok = (`n' == 1 & "`ct'" == "visit")
run_val "cdp confirmtype(visit) accepts first conf visit" `ok'
restore

**# cdp: eventvar + converged + validation
clear
input id edss str10 dstr
1 1.0 "2010-01-01"
1 2.0 "2010-07-01"
1 2.0 "2011-02-01"
2 3.0 "2010-01-01"
2 3.0 "2010-07-01"
end
make_edss, dx("2010-01-01")
preserve
cdp id edss date, dxdate(dx) keepall eventvar(cdp_ev) quietly
local conv = r(converged)
local evname = "`r(eventvar)'"
local ev1 = cdp_ev[1]
quietly count if id == 2 & cdp_ev == 0
local n0 = r(N)
local ok = (`ev1' == 1)
run_val "cdp eventvar 1 for progressor" `ok'
local ok = (`n0' == 2)
run_val "cdp eventvar 0 for non-progressor" `ok'
local ok = (`conv' == 1)
run_val "cdp r(converged) == 1" `ok'
local ok = ("`evname'" == "cdp_ev")
run_val "cdp r(eventvar) macro set" `ok'
restore, preserve
cap noi cdp id edss date, dxdate(dx) confirmtype(bogus)
local ok = (_rc == 198)
run_val "cdp confirmtype(bogus) rejected rc198" `ok'
restore, preserve
cap noi cdp id edss date, dxdate(dx) eventvar(edss)
local ok = (_rc == 110)
run_val "cdp eventvar collides with existing var rc110" `ok'
restore

**# cdp: roving honors threetier + confirmtype (runs clean)
clear
input id edss str10 dstr
1 0.0 "2010-01-01"
1 1.5 "2010-07-01"
1 1.5 "2011-02-01"
1 3.0 "2011-08-01"
1 3.0 "2012-03-01"
end
make_edss, dx("2010-01-01")
preserve
cap noi cdp id edss date, dxdate(dx) roving allevents threetier confirmtype(visit) keepall quietly
local rc = _rc
local tt = "`r(threetier)'"
local ok = (`rc' == 0 & "`tt'" == "yes")
run_val "cdp roving + threetier + confirmtype(visit) runs" `ok'
restore

**# sustainedss: eventvar
clear
input id edss str10 dstr
1 3.0 "2010-01-01"
1 4.0 "2010-07-01"
1 4.0 "2011-02-01"
2 2.0 "2010-01-01"
2 2.0 "2011-02-01"
end
gen date = daily(dstr, "YMD")
format date %td
drop dstr
sustainedss id edss date, threshold(4) keepall eventvar(ss_ev) quietly
local evname = "`r(eventvar)'"
local ev1 = ss_ev[1]
quietly count if id == 2 & ss_ev == 0
local n0 = r(N)
local ok = (`ev1' == 1)
run_val "sustainedss eventvar 1 for event" `ok'
local ok = (`n0' == 2)
run_val "sustainedss eventvar 0 for non-event" `ok'
local ok = ("`evname'" == "ss_ev")
run_val "sustainedss r(eventvar) macro" `ok'

**# cci_se: separator-insensitive ICD-8 sub-code (#8)
clear
input id str10 icd str10 dstr
1 "412,01" "1980-03-01"
2 "412.01" "1980-03-01"
3 "41201"  "1980-03-01"
end
gen date = daily(dstr, "YMD")
format date %td
drop dstr
cci_se, id(id) icd(icd) date(date)
quietly count if charlson == 1
local n = r(N)
local ok = (`n' == 3)
run_val "cci_se comma/dot/stripped ICD-8 all score MI" `ok'

**# cci_se: indexdate + lookback windowing (#1)
clear
input id str10 icd str10 dstr
1 "I21" "2014-01-01"
1 "I50" "2018-06-01"
1 "C50" "2020-09-01"
end
gen date = daily(dstr, "YMD")
format date %td
gen idx = daily("2019-01-01", "YMD")
format idx %td
preserve
cci_se, id(id) icd(icd) date(date) indexdate(idx) components
local nin = r(N_input)
local nex = r(N_excluded_window)
local mi = cci_mi[1]
local chf = cci_chf[1]
local ca = cci_cancer[1]
local ok = (`nin' == 2 & `nex' == 1)
run_val "cci_se indexdate excludes post-index" `ok'
local ok = (`mi' == 1 & `chf' == 1 & `ca' == 0)
run_val "cci_se indexdate keeps pre-index MI+CHF" `ok'
restore, preserve
cci_se, id(id) icd(icd) date(date) indexdate(idx) lookback(1096) components
local nin = r(N_input)
local lb = r(lookback)
local mi = cci_mi[1]
local chf = cci_chf[1]
local ok = (`nin' == 1 & `lb' == 1096)
run_val "cci_se lookback lower bound applied" `ok'
local ok = (`chf' == 1 & `mi' == 0)
run_val "cci_se lookback keeps only in-window CHF" `ok'
restore, preserve
cap noi cci_se, id(id) icd(icd) date(date) lookback(365)
local ok = (_rc == 198)
run_val "cci_se lookback without indexdate rc198" `ok'
restore

**# pira: non-default relapse columns + type mismatch (clarity #5)
clear
input str10 dstr2
"2009-06-01"
"2012-06-01"
end
gen pid = 1
gen rdate = daily(dstr2, "YMD")
format rdate %td
drop dstr2
tempfile rel
save `rel'
clear
input id edss str10 dstr
1 1.0 "2010-01-01"
1 2.0 "2010-07-01"
1 2.0 "2011-02-01"
end
make_edss, dx("2010-01-01")
preserve
cap noi pira id edss date, dxdate(dx) relapses("`rel'") ///
    relapseidvar(pid) relapsedatevar(rdate) keepall quietly
local ok = (_rc == 0)
run_val "pira relapseidvar()/relapsedatevar() success path" `ok'
restore, preserve
clear
input str4 pid str10 dstr2
"1"  "2009-06-01"
end
gen rdate = daily(dstr2, "YMD")
format rdate %td
drop dstr2
tempfile rel_str
save `rel_str'
restore, preserve
cap noi pira id edss date, dxdate(dx) relapses("`rel_str'") ///
    relapseidvar(pid) relapsedatevar(rdate) keepall quietly
local ok = (_rc == 109)
run_val "pira relapse ID type mismatch rc109" `ok'
restore

**# pira: threetier + confirmtype + eventvar surface
clear
input str10 dstr2
"2030-01-01"
end
gen id = 1
gen relapse_date = daily(dstr2, "YMD")
format relapse_date %td
drop dstr2
tempfile rel2
save `rel2'
clear
input id edss str10 dstr
1 1.0 "2010-01-01"
1 2.0 "2010-07-01"
1 2.0 "2011-02-01"
end
make_edss, dx("2010-01-01")
pira id edss date, dxdate(dx) relapses("`rel2'") threetier confirmtype(visit) ///
    eventvar(pira_ev) keepall quietly
local tt = "`r(threetier)'"
local ct = "`r(confirmtype)'"
local conv = r(converged)
local evname = "`r(eventvar)'"
local ev1 = pira_ev[1]
local ok = ("`tt'" == "yes" & "`ct'" == "visit")
run_val "pira threetier/confirmtype surface" `ok'
local ok = (`conv' == 1)
run_val "pira r(converged) present" `ok'
local ok = (`ev1' == 1 & "`evname'" == "pira_ev")
run_val "pira eventvar created" `ok'

**# migrations: exclude_reason must not leak; user column survives (BUG #1)
clear
set obs 3
gen long id = _n
gen long in_1 = .
gen long out_1 = .
replace out_1 = td(01jun2020) if id == 2
gen long in_2 = .
gen long out_2 = .
format in_1 out_1 in_2 out_2 %td
tempfile mig
save `mig'
clear
set obs 3
gen long id = _n
gen long study_start = td(01jan2018)
format study_start %td
gen str10 keepme = "x"
migrations, migfile("`mig'")
capture confirm variable exclude_reason
local ok = (_rc != 0)
run_val "migrations does not leak exclude_reason" `ok'
capture confirm variable keepme
local ok = (_rc == 0)
run_val "migrations preserves user column keepme" `ok'

**# migrations: _neg_*/_mig_* namespace preflight (#12)
clear
set obs 3
gen long id = _n
gen long study_start = td(01jan2018)
format study_start %td
gen byte _neg_out = 1
cap noi migrations, migfile("`mig'")
local ok = (_rc == 110)
run_val "migrations _neg_* namespace preflight rc110" `ok'

**# Summary
display as text _n "{hline 60}"
display "RESULT: test_setools_v130_features tests=" scalar(gs_ntest) ///
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

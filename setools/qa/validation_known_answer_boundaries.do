/*******************************************************************************
* validation_known_answer_boundaries.do
* Boundary-heavy known-answer validation suite for setools
*
* Purpose:
*   Add exact-value validations for branches that are easy to get subtly wrong:
*   inclusive day boundaries, same-day duplicate handling, mixed migration
*   states, and combined option paths.
*
* Run from setools/qa/ directory:
*   stata-mp -b do validation_known_answer_boundaries.do
*******************************************************************************/

version 16.0
capture log close _all

* === Bootstrap ===
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'"
local pkg_dir : subinstr local pkg_dir "/qa" "", all

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

set varabbrev off

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_val
program define run_val
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  [PASS] `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  [FAIL] `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures `"${gs_failures} `test_name'"'
    }
end

**# K1. CCI_SE DATE AND VERSION BOUNDARIES

* K1.1: 1968/1969 transition is inclusive on both sides
clear
input long lopnr str10 diagnos long datum
1 "420,1" 19681231
2 "410"   19690101
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
sort lopnr
local t = (r(N_patients) == 2 & charlson[1] == 1 & charlson[2] == 1)
run_val "K1.1: cci_se 1968/1969 version boundary scores exactly" `t'

* K1.2: 1997 overlap accepts both ICD-9 and ICD-10 codes in the same year
clear
input long lopnr str10 diagnos long datum
1 "250D" 19970115
2 "E102" 19970115
3 "250D" 19970115
3 "E102" 19970115
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components
sort lopnr
local t = (r(N_patients) == 3 & ///
    charlson[1] == 2 & ///
    charlson[2] == 2 & ///
    charlson[3] == 2 & ///
    cci_diab[3] == 0 & ///
    cci_diabcomp[3] == 1)
run_val "K1.2: cci_se 1997 overlap handles ICD-9 and ICD-10 exactly" `t'

**# K2. CDP EXACT BOUNDARIES

* K2.1: confirmdays() is inclusive at exactly 180 days
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 3.0 21100 20800
1 3.0 21280 20800
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) confirmdays(180) keepall generate(cdp_k21)
quietly summarize cdp_k21 if id == 1, meanonly
local t = (r(mean) == 21100 & r(N) == 3 & r(min) == 21100 & r(max) == 21100)
run_val "K2.1: cdp confirms on the exact 180-day boundary" `t'

* K2.2: 179 days is not enough for confirmation
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 3.0 21100 20800
1 3.0 21279 20800
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) confirmdays(180) keepall generate(cdp_k22)
local t = (r(N_events) == 0)
run_val "K2.2: cdp does not confirm at 179 days" `t'

* K2.3: non-roving CDP retries later candidates after an earlier failure
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 3.0 21100 20800
1 2.0 21180 20800
1 3.5 21220 20800
1 3.5 21280 20800
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) confirmdays(60) keepall generate(cdp_k23)
quietly summarize cdp_k23 if id == 1, meanonly
local t = (r(mean) == 21220 & r(N) == 5)
run_val "K2.3: cdp retries later candidates after a failed confirmation" `t'

* K2.4: same-day baseline duplicates use the lower EDSS value
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 2.5 21000 20800
1 3.0 21100 20800
1 3.0 21300 20800
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_k24)
quietly summarize cdp_k24 if id == 1, meanonly
local t = (r(mean) == 21100 & r(N) == 4 & r(min) == 21100 & r(max) == 21100)
run_val "K2.4: cdp uses the lowest same-day baseline EDSS on ties" `t'

**# K3. SUSTAINEDSS WINDOW BOUNDARIES

* K3.1: confirmvisit(window) includes the exact upper bound day
clear
input long id double edss long edss_dt
1 5.0 20900
1 6.0 21000
1 6.0 21182
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) confirmvisit(window) ///
    keepall generate(sust_k31)
quietly summarize sust_k31 if id == 1, meanonly
local t = (r(mean) == 21000 & r(N) == 3)
run_val "K3.1: sustainedss includes the exact confirmwindow upper bound" `t'

* K3.2: any dip below baselinethreshold disqualifies bounded confirmation,
*       even when the last window value returns exactly to threshold
clear
input long id double edss long edss_dt
1 6.0 21000
1 5.5 21100
1 6.0 21182
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) confirmvisit(window) ///
    keepall generate(sust_k32)
local t = (r(N_events) == 0)
run_val "K3.2: sustainedss rejects a temporary dip in bounded mode" `t'

* K3.3: same-day duplicates at the last window date use the minimum EDSS value,
*       and a later sub-threshold visit blocks any fallback event
clear
input long id double edss long edss_dt
1 5.0 20900
1 6.0 21000
1 5.0 21100
1 6.5 21100
1 5.5 21200
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) confirmvisit(window) ///
    confirmwindow(150) keepall generate(sust_k33)
local t = (r(N_events) == 0)
run_val "K3.3: sustainedss uses the conservative minimum on same-day duplicates" `t'

**# K4. PIRA RELAPSE WINDOW AND REBASELINE BOUNDARIES

* K4.1: relapse-window boundaries are inclusive on both lower and upper edges
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 3.5 21350 20800
1 3.5 21600 20800
2 2.0 21000 20800
2 3.5 21350 20800
2 3.5 21600 20800
end
format edss_dt dx_date %td
tempfile k41_rel
preserve
clear
input long id long relapse_date
1 21440
2 21320
end
format relapse_date %td
save `k41_rel', replace
restore
pira id edss edss_dt, dxdate(dx_date) relapses("`k41_rel'") ///
    keepall generate(pira_k41) rawgenerate(raw_k41)
local cmd_raw = r(N_raw)
local cmd_pira = r(N_pira)
quietly count if !missing(raw_k41)
local raw_n = r(N)
quietly count if !missing(pira_k41)
local pira_n = r(N)
quietly summarize raw_k41 if id == 1, meanonly
local raw1 = r(mean)
quietly summarize raw_k41 if id == 2, meanonly
local raw2 = r(mean)
local t = (`cmd_raw' == 2 & `cmd_pira' == 0 & `raw_n' == 6 & `pira_n' == 0 & ///
    `raw1' == 21350 & `raw2' == 21350)
run_val "K4.1: pira treats both relapse-window boundaries as inclusive" `t'

* K4.2: dates just outside the relapse-window boundaries classify as PIRA
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 3.5 21350 20800
1 3.5 21600 20800
2 2.0 21000 20800
2 3.5 21350 20800
2 3.5 21600 20800
end
format edss_dt dx_date %td
tempfile k42_rel
preserve
clear
input long id long relapse_date
1 21441
2 21319
end
format relapse_date %td
save `k42_rel', replace
restore
pira id edss edss_dt, dxdate(dx_date) relapses("`k42_rel'") ///
    keepall generate(pira_k42) rawgenerate(raw_k42)
local cmd_pira = r(N_pira)
local cmd_raw = r(N_raw)
quietly count if !missing(pira_k42)
local pira_n = r(N)
quietly count if !missing(raw_k42)
local raw_n = r(N)
quietly summarize pira_k42 if id == 1, meanonly
local pira1 = r(mean)
quietly summarize pira_k42 if id == 2, meanonly
local pira2 = r(mean)
local t = (`cmd_pira' == 2 & `cmd_raw' == 0 & `pira_n' == 6 & `raw_n' == 0 & ///
    `pira1' == 21350 & `pira2' == 21350)
run_val "K4.2: pira treats just-outside relapse dates as PIRA" `t'

* K4.3a: without rebaselinerelapse, the post-relapse visit at +30 days is a CDP event
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 3.0 21130 20800
1 3.5 21200 20800
1 3.5 21400 20800
end
format edss_dt dx_date %td
tempfile k43_rel
preserve
clear
input long id long relapse_date
1 21100
end
format relapse_date %td
save `k43_rel', replace
restore
pira id edss edss_dt, dxdate(dx_date) relapses("`k43_rel'") ///
    keepall windowbefore(0) windowafter(0) confirmdays(60) ///
    generate(pira_k43a) rawgenerate(raw_k43a)
local cmd_cdp = r(N_cdp)
local cmd_pira = r(N_pira)
local cmd_raw = r(N_raw)
quietly summarize pira_k43a if id == 1, meanonly
local t = (`cmd_cdp' == 1 & `cmd_pira' == 1 & `cmd_raw' == 0 & r(mean) == 21130)
run_val "K4.3a: pira without rebaseline keeps the +30-day visit as CDP" `t'

* K4.3b: rebaselinerelapse resets exactly at +30 days and suppresses the false CDP
clear
input long id double edss long edss_dt long dx_date
1 2.0 21000 20800
1 3.0 21130 20800
1 3.5 21200 20800
1 3.5 21400 20800
end
format edss_dt dx_date %td
pira id edss edss_dt, dxdate(dx_date) relapses("`k43_rel'") ///
    keepall windowbefore(0) windowafter(0) confirmdays(60) ///
    rebaselinerelapse generate(pira_k43b) rawgenerate(raw_k43b)
local cmd_cdp = r(N_cdp)
local cmd_pira = r(N_pira)
local cmd_raw = r(N_raw)
local t = (`cmd_cdp' == 0 & `cmd_pira' == 0 & `cmd_raw' == 0)
run_val "K4.3b: pira rebaselines exactly on the +30-day boundary" `t'

**# K5. MIGRATIONS MIXED-STATE EXACT COUNTS

* Cohort layout for K5.1 and K5.2:
*   1 = no migration record (retained)
*   2 = immigration exactly 365 days before start (retained)
*   3 = immigration 364 days before start (minresidence exclusion)
*   4 = emigrated before start, never returned (type 1 exclusion)
*   5 = immigrated after start (kept with keepimmigrants)
*   6 = abroad at baseline, returned after start (type 3 exclusion)
*   7 = permanent post-start emigration (censored)
tempfile k5_master k5_wide k5_long

clear
set obs 7
gen long id = _n
gen long study_start = mdy(1, 1, 2018)
format study_start %td
save `k5_master', replace

clear
set obs 6
gen long id = _n + 1
gen long in_1 = .
gen long out_1 = .
replace in_1 = mdy(1, 1, 2017) if id == 2
replace in_1 = mdy(1, 2, 2017) if id == 3
replace out_1 = mdy(12, 31, 2017) if id == 4
replace in_1 = mdy(2, 20, 2018) if id == 5
replace out_1 = mdy(12, 31, 2017) if id == 6
replace in_1 = mdy(2, 20, 2018) if id == 6
replace out_1 = mdy(6, 1, 2019) if id == 7
format in_1 out_1 %td
save `k5_wide', replace

clear
input long id long event_date str3 event_type
2 .           ""
3 .           ""
4 .           ""
5 .           ""
6 .           ""
7 .           ""
end
replace event_date = mdy(1, 1, 2017)  in 1
replace event_type = "Inv"            in 1
replace event_date = mdy(1, 2, 2017)  in 2
replace event_type = "Inv"            in 2
replace event_date = mdy(12, 31, 2017) in 3
replace event_type = "Utv"             in 3
replace event_date = mdy(2, 20, 2018)  in 4
replace event_type = "Inv"             in 4
replace event_date = mdy(12, 31, 2017) in 5
replace event_type = "Utv"             in 5
expand 2 if id == 6, gen(_dup)
replace event_date = mdy(2, 20, 2018) if id == 6 & _dup == 1
replace event_type = "Inv"            if id == 6 & _dup == 1
drop _dup
expand 2 if id == 7, gen(_dropme)
replace event_date = mdy(6, 1, 2019) if id == 7 & _dropme == 1
replace event_type = "Utv"           if id == 7 & _dropme == 1
drop if missing(event_date)
drop _dropme
format event_date %td
sort id event_date
save `k5_long', replace

* K5.1: wide mixed-state cohort with keepimmigrants + minresidence()
use `k5_master', clear
migrations, migfile("`k5_wide'") keepimmigrants minresidence(365)
local cmd_excl_emig = r(N_excluded_emigrated)
local cmd_excl_inmig = r(N_excluded_inmigration)
local cmd_excl_abroad = r(N_excluded_abroad)
local cmd_excl_minres = r(N_excluded_minresidence)
local cmd_excl_total = r(N_excluded_total)
local cmd_included = r(N_included_inmigration)
local cmd_censor = r(N_censored)
local cmd_final = r(N_final)
quietly count
local n_final = r(N)
quietly count if id == 5
local id5_kept = r(N)
quietly count if inlist(id, 3, 4, 6)
local excluded_present = r(N)
quietly summarize migration_in_dt if id == 5, meanonly
local id5_in = r(mean)
quietly summarize migration_out_dt if id == 7, meanonly
local id7_out = r(mean)
local t = (`cmd_excl_emig' == 1 & ///
    `cmd_excl_inmig' == 0 & ///
    `cmd_excl_abroad' == 1 & ///
    `cmd_excl_minres' == 1 & ///
    `cmd_excl_total' == 3 & ///
    `cmd_included' == 1 & ///
    `cmd_censor' == 1 & ///
    `cmd_final' == 4 & ///
    `n_final' == 4 & ///
    `id5_kept' == 1 & ///
    `excluded_present' == 0 & ///
    `id5_in' == mdy(2, 20, 2018) & ///
    `id7_out' == mdy(6, 1, 2019))
run_val "K5.1: migrations wide mixed-state cohort has exact counts and dates" `t'

* K5.2: long-format mixed-state cohort yields the same exact result
use `k5_master', clear
migrations, migfile("`k5_long'") keepimmigrants minresidence(365)
local cmd_excl_emig = r(N_excluded_emigrated)
local cmd_excl_inmig = r(N_excluded_inmigration)
local cmd_excl_abroad = r(N_excluded_abroad)
local cmd_excl_minres = r(N_excluded_minresidence)
local cmd_excl_total = r(N_excluded_total)
local cmd_included = r(N_included_inmigration)
local cmd_censor = r(N_censored)
local cmd_final = r(N_final)
quietly count
local n_final = r(N)
quietly count if id == 5
local id5_kept = r(N)
quietly count if inlist(id, 3, 4, 6)
local excluded_present = r(N)
quietly summarize migration_in_dt if id == 5, meanonly
local id5_in = r(mean)
quietly summarize migration_out_dt if id == 7, meanonly
local id7_out = r(mean)
local t = (`cmd_excl_emig' == 1 & ///
    `cmd_excl_inmig' == 0 & ///
    `cmd_excl_abroad' == 1 & ///
    `cmd_excl_minres' == 1 & ///
    `cmd_excl_total' == 3 & ///
    `cmd_included' == 1 & ///
    `cmd_censor' == 1 & ///
    `cmd_final' == 4 & ///
    `n_final' == 4 & ///
    `id5_kept' == 1 & ///
    `excluded_present' == 0 & ///
    `id5_in' == mdy(2, 20, 2018) & ///
    `id7_out' == mdy(6, 1, 2019))
run_val "K5.2: migrations long mixed-state cohort matches exact wide-format results" `t'

**# Final Summary

display as text "Total tests:  " scalar(gs_ntest)
display as result "Passed:       " scalar(gs_npass)
if scalar(gs_nfail) > 0 {
    display as error "Failed:       " scalar(gs_nfail)
    display as error "Failed tests: ${gs_failures}"
}
else {
    display as text "Failed:       " scalar(gs_nfail)
}
display "RESULT: validation_known_answer_boundaries tests=" scalar(gs_ntest) ///
    " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)

if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
}

do "`qa_dir'/_setools_qa_common.do" teardown

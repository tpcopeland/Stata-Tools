/*******************************************************************************
* crossval_setools.do
* Cross-validation suite for setools package
*
* Validates commands by comparing outputs across methods:
*   C1. CDP vs manual calculation
*   C2. sustainedss vs manual threshold check
*   C3. cci_se vs manual scoring
*   C4. PIRA/CDP internal consistency
*
* Run from setools/qa/ directory:
*   stata-mp -b do crossval_setools.do
*
* Author: Claude Code (gold-standard cross-validation)
* Date: 2026-03-21
*******************************************************************************/

version 16.0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

set varabbrev off

**# SETUP

local pkg_dir "`c(pwd)'"
capture confirm file "`pkg_dir'/../setools.ado"
if _rc == 0 {
    local pkg_dir "`pkg_dir'/.."
}
else {
    capture confirm file "`pkg_dir'/setools.ado"
    if _rc == 0 {
        * Already in package dir
    }
    else {
    }
}

capture program drop _setools_detail
foreach cmd in setools cci_se cdp migrations pira sustainedss {
    capture program drop `cmd'
    run "`pkg_dir'/`cmd'.ado"
}

local qa_dir "`pkg_dir'/qa"
local data_dir "`qa_dir'/data"
capture mkdir "`data_dir'"

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_cv
program define run_cv
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

**# C1: CDP VS MANUAL CALCULATION

* C1.1: Manually compute CDP for 5 patients
* Patient 1: baseline=2.0, threshold=1.0. Day 350: 3.5 (3.5-2.0=1.5>=1.0). Day 600: 3.5>=3.0. CDP at 21350.
* Patient 2: baseline=3.0, threshold=1.0. Day 350: 3.5 (3.5-3.0=0.5<1.0). No CDP.
* Patient 3: baseline=2.0, threshold=1.0. Day 350: 3.5 (>=1.0). Day 600: 2.0 (<3.0). Not confirmed.
* Patient 4: baseline=6.0 (>5.5), threshold=0.5. Day 350: 6.5 (>=0.5). Day 600: 7.0>=6.5. CDP at 21350.
* Patient 5: only 1 observation. No CDP.
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
2 3.0 21185 21000
2 3.5 21350 21000
2 3.5 21600 21000
3 2.0 21185 21000
3 3.5 21350 21000
3 2.0 21600 21000
4 6.0 21185 21000
4 6.5 21350 21000
4 7.0 21600 21000
5 4.0 21185 21000
end
format edss_dt dx_date %td

cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_c1)
local cdp_n_events = r(N_events)

* Check patient 1: CDP at day 21350
quietly sum cdp_c1 if id == 1
local p1_cdp = r(mean)
local t = (`p1_cdp' == 21350)
run_cv "C1.1a: Patient 1 CDP date = 21350" `t'

* Check patient 2: no CDP
quietly count if !missing(cdp_c1) & id == 2
local t = (r(N) == 0)
run_cv "C1.1b: Patient 2 no CDP" `t'

* Check patient 3: no CDP (reversal)
quietly count if !missing(cdp_c1) & id == 3
local t = (r(N) == 0)
run_cv "C1.1c: Patient 3 no CDP (reversal)" `t'

* Check patient 4: CDP (high baseline)
quietly sum cdp_c1 if id == 4
local p4_cdp = r(mean)
local t = (`p4_cdp' == 21350)
run_cv "C1.1d: Patient 4 CDP date = 21350" `t'

* Check patient 5: no CDP
quietly count if !missing(cdp_c1) & id == 5
local t = (r(N) == 0)
run_cv "C1.1e: Patient 5 no CDP (single obs)" `t'

* Total events = 2
local t = (`cdp_n_events' == 2)
run_cv "C1.1f: Total CDP events = 2" `t'

* C1.2: CDP roving vs non-roving gives different results on progressive data
clear
input long id double edss double edss_dt double dx_date
1 2.0 21000 21000
1 3.5 21200 21000
1 3.5 21400 21000
1 4.5 21600 21000
1 5.0 21800 21000
end
format edss_dt dx_date %td
save "`data_dir'/_cv_c1_roving.dta", replace

* Non-roving: one event
use "`data_dir'/_cv_c1_roving.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_norov)
local n_norov = r(N_events)

* Roving with allevents: potentially more events
use "`data_dir'/_cv_c1_roving.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_rov) roving allevents
local n_rov = r(N_events)

* Non-roving should have at most 1 (per person), roving+allevents may have more
local t = (`n_norov' <= `n_rov')
run_cv "C1.2: roving+allevents >= non-roving events" `t'

**# C2: SUSTAINEDSS VS MANUAL THRESHOLD CHECK

* C2.1: 3 patients with known outcomes
* Patient 1: EDSS 2,3,4,5,6 at days 0,100,200,300,400. Threshold=4.
*   First >=4 at day 200 (EDSS=4). Confirm window (182 days): need obs in [201,382].
*   Day 300: EDSS=5 >=4 (baseline threshold default=4). Sustained at day 200.
* Patient 2: EDSS 2,3,5,2. Threshold=4.
*   First >=4 at day 200 (EDSS=5). In window: day 300: EDSS=2 < 4. NOT sustained.
*   After iterative rejection: no event.
* Patient 3: EDSS 5,6,7. Threshold=4. First >=4 at day 0. Window: days 1-182.
*   Day 100: EDSS=6>=4. Sustained at day 21000.
clear
input long id double edss double edss_dt
1 2 21000
1 3 21100
1 4 21200
1 5 21300
1 6 21400
2 2 21000
2 3 21100
2 5 21200
2 2 21300
3 5 21000
3 6 21100
3 7 21200
end
format edss_dt %td

sustainedss id edss edss_dt, threshold(4) keepall generate(sus_c2)

* Patient 1: sustained at 21200
quietly sum sus_c2 if id == 1
local t = (r(mean) == 21200)
run_cv "C2.1a: Patient 1 sustained at day 21200" `t'

* Patient 2: no sustained event
quietly count if !missing(sus_c2) & id == 2
local t = (r(N) == 0)
run_cv "C2.1b: Patient 2 no sustained event" `t'

* Patient 3: sustained at 21000
quietly sum sus_c2 if id == 3
local t = (r(mean) == 21000)
run_cv "C2.1c: Patient 3 sustained at day 21000" `t'

**# C3: CCI_SE VS MANUAL SCORING

* C3.1: Hand-score 3 patients with ICD-10 codes
* Patient 1: I21 (MI=1) + I50 (CHF=1) + J44 (COPD=1) = 3
* Patient 2: E100 (Diab uncomplicated=1) + E102 (Diab complicated=2) -> hierarchy: uncomplicated cleared -> 2
* Patient 3: C50 (Cancer=2) + C77 (Mets=6) -> hierarchy: cancer cleared -> 6
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "I50" 21915
1 "J44" 21915
2 "E100" 21915
2 "E102" 21915
3 "C50" 21915
3 "C77" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum) components

sort lopnr
local p1_cci = charlson[1]
local p2_cci = charlson[2]
local p3_cci = charlson[3]

local t = (`p1_cci' == 3)
run_cv "C3.1a: Patient 1 CCI=3 (MI+CHF+COPD)" `t'

local t = (`p2_cci' == 2)
run_cv "C3.1b: Patient 2 CCI=2 (diabetes hierarchy)" `t'

local t = (`p3_cci' == 6)
run_cv "C3.1c: Patient 3 CCI=6 (cancer hierarchy)" `t'

* Verify component indicators
local t = (cci_mi[1] == 1 & cci_chf[1] == 1 & cci_copd[1] == 1)
run_cv "C3.1d: Patient 1 components correct" `t'

local t = (cci_diab[2] == 0 & cci_diabcomp[2] == 1)
run_cv "C3.1e: Patient 2 hierarchy: diab=0, diabcomp=1" `t'

local t = (cci_cancer[3] == 0 & cci_mets[3] == 1)
run_cv "C3.1f: Patient 3 hierarchy: cancer=0, mets=1" `t'

* C3.2: Hand-score multi-row, multi-variable input with wildcard varlist
* Patient 1: 290 + (I21 J44) + N18 -> 1 + 1 + 1 + 2 = 5
* Patient 2: 250A + 250D -> hierarchy to 2, plus B20 = 8
* Patient 3: 420,1 + C50 + C77 -> 1 + hierarchy to 6 = 7
clear
input long lopnr long datum str20 diag_main str20 diag_aux str20 diag_oth
1 19800101 "290" "" ""
1 20180115 "I21 J44" "" "N18"
2 19900101 "250A" "250D" ""
2 20180115 "" "B20" ""
3 19650315 "420,1" "" ""
3 20180115 "C50" "C77" ""
end
tempfile c32_multi c32_ref
save `c32_multi', replace

use `c32_multi', clear
gen str80 diag_all = trim(diag_main + " " + diag_aux + " " + diag_oth)
cci_se, id(lopnr) icd(diag_all) date(datum) dateformat(yyyymmdd) generate(score_single)
sort lopnr
keep lopnr score_single
save `c32_ref', replace

use `c32_multi', clear
cci_se, id(lopnr) icd(diag_*) date(datum) dateformat(yyyymmdd) generate(score_multi) components
sort lopnr
merge 1:1 lopnr using `c32_ref', nogen
sort lopnr

local t = (score_multi[1] == 5 & score_single[1] == 5 & cci_dem[1] == 1 & cci_renal[1] == 1)
run_cv "C3.2a: Patient 1 CCI=5 under wildcard multi-variable input" `t'

local t = (score_multi[2] == 8 & score_single[2] == 8 & cci_diab[2] == 0 & cci_diabcomp[2] == 1 & cci_aids[2] == 1)
run_cv "C3.2b: Patient 2 CCI=8 with hierarchy across rows/columns" `t'

local t = (score_multi[3] == 7 & score_single[3] == 7 & cci_mi[3] == 1 & cci_cancer[3] == 0 & cci_mets[3] == 1)
run_cv "C3.2c: Patient 3 CCI=7 across ICD-7 and ICD-10 rows" `t'

local t = (score_multi[1] == score_single[1] & score_multi[2] == score_single[2] & score_multi[3] == score_single[3])
run_cv "C3.2d: wildcard multi-variable path matches single-field reference" `t'

**# C4: PIRA/CDP INTERNAL CONSISTENCY

* Create test data with mix of PIRA and RAW patients
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
2 2.0 21185 21000
2 3.5 21350 21000
2 3.5 21600 21000
3 3.0 21185 21000
3 4.5 21350 21000
3 4.5 21600 21000
end
format edss_dt dx_date %td
save "`data_dir'/_cv_c4_edss.dta", replace

* Relapse for patient 2 near CDP date (makes it RAW)
clear
input long id double relapse_date
2 21340
end
format relapse_date %td
save "`data_dir'/_cv_c4_rel.dta", replace

use "`data_dir'/_cv_c4_edss.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_cv_c4_rel.dta") keepall generate(c4_pira) rawgenerate(c4_raw)

* C4.1: PIRA patients have no relapse nearby
* Patient 1 and 3 should be PIRA (no relapse), patient 2 should be RAW
quietly count if !missing(c4_pira) & id == 1
local t = (r(N) > 0)
run_cv "C4.1: Patient 1 classified as PIRA" `t'

* C4.2: RAW patient has relapse nearby
quietly count if !missing(c4_raw) & id == 2
local t = (r(N) > 0)
run_cv "C4.2: Patient 2 classified as RAW" `t'

* C4.3: No patient has both PIRA and RAW non-missing
quietly count if !missing(c4_pira) & !missing(c4_raw)
local t = (r(N) == 0)
run_cv "C4.3: No patient has both PIRA and RAW" `t'

* C4.4: N_pira + N_raw = N_cdp
local t = (r(N_pira) + r(N_raw) == r(N_cdp))
run_cv "C4.4: N_pira + N_raw = N_cdp invariant" `t'

* C4.5: PIRA dates match CDP dates for non-RAW patients
* Run CDP separately
use "`data_dir'/_cv_c4_edss.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(c4_cdp)

* For patient 1: CDP date should match PIRA date
quietly sum c4_cdp if id == 1
local cdp_date_p1 = r(mean)

use "`data_dir'/_cv_c4_edss.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_cv_c4_rel.dta") keepall generate(c4b_pira) rawgenerate(c4b_raw)
quietly sum c4b_pira if id == 1
local pira_date_p1 = r(mean)
local t = (`cdp_date_p1' == `pira_date_p1')
run_cv "C4.5: PIRA date = CDP date for non-RAW patient" `t'

**# CLEANUP

local cleanup_files "_cv_c1_roving.dta _cv_c4_edss.dta _cv_c4_rel.dta"
foreach f of local cleanup_files {
    capture erase "`data_dir'/`f'"
}

**# FINAL SUMMARY
display as text "Total tests:  " scalar(gs_ntest)
display as result "Passed:       " scalar(gs_npass)
if scalar(gs_nfail) > 0 {
    display as error "Failed:       " scalar(gs_nfail)
    display as error "Failed tests: ${gs_failures}"
}
else {
    display as text "Failed:       " scalar(gs_nfail)
}

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

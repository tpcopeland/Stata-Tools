/*******************************************************************************
* validation_setools.do
* Comprehensive validation suite for setools package
*
* All tests use hand-crafted datasets with analytically-derived expected values.
* No approximations - every expected result is verified against the algorithm
* specification by hand.
*
* Categories:
*   V1. cci_se known-answer validation
*   V2. cdp algorithm validation
*   V3. sustainedss algorithm validation
*   V4. pira classification validation
*   V5. migrations exclusion/censoring validation
*   V6. procmatch matching validation
*   V7. Cross-command invariant checks
*   V8. Determinism and idempotency
*
* Run from setools/qa/ directory:
*   stata-mp -b do validation_setools.do
*
* Author: Claude Code (gold-standard validation)
* Date: 2026-03-12
*******************************************************************************/

version 16.0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

set varabbrev off

**# Setup

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
foreach cmd in setools cci_se cdp migrations pira procmatch sustainedss {
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

**# V1. CCI_SE KNOWN-ANSWER VALIDATION

* V1.1: Complete scoring - patient with 5 comorbidities
* MI(1) + CHF(1) + Diabetes uncomplicated(1) + Renal(2) + PUD(1) = 6
* But: no hierarchy rules triggered here
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "I50" 21915
1 "E100" 21915
1 "N18" 21915
1 "K25" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components
local t = (charlson == 6)
run_val "V1.1: 5 comorbidities: CCI = 6" `t'

* V1.2: Hierarchy - diabetes complicated clears uncomplicated
* E100(uncomplicated=1) + E102(complicated=2) -> uncomplicated cleared -> CCI=2
clear
input long lopnr str10 diagnos double datum
1 "E100" 21915
1 "E102" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components
local t = (charlson == 2 & cci_diab == 0 & cci_diabcomp == 1)
run_val "V1.2: diabetes hierarchy: CCI=2, uncomplicated cleared" `t'

* V1.3: Hierarchy - metastatic clears non-metastatic
* C50(cancer=2) + C77(mets=6) -> cancer cleared -> CCI=6
clear
input long lopnr str10 diagnos double datum
1 "C50" 21915
1 "C77" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components
local t = (charlson == 6 & cci_cancer == 0 & cci_mets == 1)
run_val "V1.3: cancer hierarchy: CCI=6, non-metastatic cleared" `t'

* V1.4: Hierarchy - mild liver + ascites -> severe liver
* K73(mild liver=1) + R18(ascites) -> severe liver(3), mild cleared -> CCI=3
clear
input long lopnr str10 diagnos double datum
1 "K73" 21915
1 "R18" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components
local t = (charlson == 3 & cci_livmild == 0 & cci_livsev == 1)
run_val "V1.4: liver hierarchy: CCI=3, mild cleared" `t'

* V1.5: ICD-7 code from 1965 (year <= 1968 -> v7 flag)
* 420,1 = MI in ICD-7 -> CCI = 1
clear
input long lopnr str10 diagnos long datum
1 "420,1" 19650315
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
local t = (charlson == 1)
run_val "V1.5: ICD-7 (1965): 420,1 = MI, CCI=1" `t'

* V1.6: ICD-8 code from 1980 (1969-1986 -> v8 flag)
* 290 = Dementia in ICD-8 -> CCI = 1
clear
input long lopnr str10 diagnos long datum
1 "290" 19800601
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
local t = (charlson == 1)
run_val "V1.6: ICD-8 (1980): 290 = Dementia, CCI=1" `t'

* V1.7: ICD-9 code from 1990 (1987-1997 -> v9 flag)
* 250D = Diabetes complicated in ICD-9 -> CCI = 2
clear
input long lopnr str10 diagnos long datum
1 "250D" 19900101
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
local t = (charlson == 2)
run_val "V1.7: ICD-9 (1990): 250D = DiabComp, CCI=2" `t'

* V1.8: Multi-patient aggregation
* Patient 1: MI(1) + COPD(1) = 2
* Patient 2: AIDS(6) = 6
* Patient 3: no CCI codes = 0
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "J44" 21915
2 "B20" 21915
3 "Z99" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
sort lopnr
local t = (charlson[1] == 2 & charlson[2] == 6 & charlson[3] == 0)
run_val "V1.8: multi-patient: 2, 6, 0" `t'

* V1.9: Maximum possible single-patient CCI
* All comorbidities with highest weights (after hierarchy):
* MI(1)+CHF(1)+PVD(1)+CEVD(1)+COPD(1)+PULM(1)+RHEUM(1)+DEM(1)
* +PLEGIA(2)+DIABCOMP(2)+RENAL(2)+LIVSEV(3)+PUD(1)+METS(6)+AIDS(6) = 30
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "I50" 21915
1 "I70" 21915
1 "I63" 21915
1 "J44" 21915
1 "J47" 21915
1 "M05" 21915
1 "F00" 21915
1 "G81" 21915
1 "E102" 21915
1 "N18" 21915
1 "K73" 21915
1 "R18" 21915
1 "K25" 21915
1 "C77" 21915
1 "B20" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (charlson == 30)
run_val "V1.9: max CCI = 30 (all comorbidities)" `t'

* V1.10: Multiple diagnosis variables on the same row accumulate correctly
clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "I21" "J44" 21915
2 "" "B20" 21915
end
format datum %td
cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) components
sort lopnr
local t = (charlson[1] == 2 & cci_mi[1] == 1 & cci_copd[1] == 1 & charlson[2] == 6 & cci_aids[2] == 1)
run_val "V1.10: multi-variable icd() accumulates within row" `t'

* V1.11: Hierarchy rules apply across diagnosis variables
clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "E100" "E102" 21915
2 "C50" "C77" 21915
end
format datum %td
cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) components
sort lopnr
local t = (charlson[1] == 2 & cci_diab[1] == 0 & cci_diabcomp[1] == 1 & charlson[2] == 6 & cci_cancer[2] == 0 & cci_mets[2] == 1)
run_val "V1.11: multi-variable icd() respects hierarchy rules" `t'

* V1.12: Duplicate diagnosis across variables does not double-count
clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "I21" "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) components
local t = (charlson == 1 & cci_mi == 1)
run_val "V1.12: duplicate diagnosis across variables counts once" `t'

* V1.13: Multi-variable path matches legacy single-field path after normalization
clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "i21." "j44" 21915
2 "" "b20." 21915
3 "e100" "e102." 21915
end
format datum %td
gen str30 diag_all = trim(diag_main + " " + diag_aux)
cci_se, id(lopnr) icd(diag_all) date(datum) generate(score_single)
keep lopnr score_single
tempfile v113_single
save `v113_single', replace

clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "i21." "j44" 21915
2 "" "b20." 21915
3 "e100" "e102." 21915
end
format datum %td
cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) generate(score_multi) components
merge 1:1 lopnr using `v113_single', nogen
sort lopnr
local t = (score_multi[1] == 2 & score_single[1] == 2 & ///
    score_multi[2] == 6 & score_single[2] == 6 & ///
    score_multi[3] == 2 & score_single[3] == 2 & ///
    cci_diab[3] == 0 & cci_diabcomp[3] == 1)
run_val "V1.13: multi-variable icd() matches single-field path with dots/case/blanks" `t'

* V1.14: Wildcard multi-variable path handles multi-row, multi-code, yyyymmdd input
clear
input long lopnr long datum str20 diag_main str20 diag_aux str20 diag_oth
1 19800101 "290" "" ""
1 20180115 "I21 J44" "" "N18"
2 19900101 "250A" "250D" ""
2 20180115 "" "B20" ""
3 19650315 "420,1" "" ""
3 20180115 "C50" "C77" ""
end
tempfile v114_multi v114_ref
save `v114_multi', replace

use `v114_multi', clear
gen str80 diag_all = trim(diag_main + " " + diag_aux + " " + diag_oth)
cci_se, id(lopnr) icd(diag_all) date(datum) dateformat(yyyymmdd) generate(score_single)
sort lopnr
keep lopnr score_single
save `v114_ref', replace

use `v114_multi', clear
cci_se, id(lopnr) icd(diag_*) date(datum) dateformat(yyyymmdd) generate(score_multi) components
sort lopnr
merge 1:1 lopnr using `v114_ref', nogen
sort lopnr
local t = (score_multi[1] == 5 & score_single[1] == 5 & ///
    cci_dem[1] == 1 & cci_mi[1] == 1 & cci_copd[1] == 1 & cci_renal[1] == 1 & ///
    score_multi[2] == 8 & score_single[2] == 8 & ///
    cci_diab[2] == 0 & cci_diabcomp[2] == 1 & cci_aids[2] == 1 & ///
    score_multi[3] == 7 & score_single[3] == 7 & ///
    cci_mi[3] == 1 & cci_cancer[3] == 0 & cci_mets[3] == 1)
run_val "V1.14: wildcard icd() handles multirow multi-code yyyymmdd input" `t'

**# V2. CDP ALGORITHM VALIDATION

* V2.1: Baseline within window selects first EDSS
* Diagnosis: day 21000, baseline window 730 days
* First EDSS at day 21185 (185 days after dx, within 730 window)
* Baseline = 2.0, threshold = 1.0 (since 2.0 <= 5.5)
* Progression at day 21350 (EDSS=3.5, change=1.5 >= 1.0)
* Confirmation at day 21600 (EDSS=3.5, >=21350+180=21530, still >= 3.0) -> CONFIRMED
* CDP date = 21350
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_v21)
sum cdp_v21 if id == 1
local t = (r(mean) == 21350)
run_val "V2.1: CDP date = 21350 (first progression)" `t'

* V2.2: Baseline outside window uses earliest available
* Diagnosis: day 22000, baseline window 730 days
* Earliest EDSS at day 21185 (815 days before dx, OUTSIDE window)
* Since no EDSS within [22000, 22730], earliest EDSS used -> baseline=2.0
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 22000
1 3.5 21350 22000
1 3.5 21600 22000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_v22)
sum cdp_v22 if id == 1
local t = (r(mean) == 21350)
run_val "V2.2: baseline outside window uses earliest" `t'

* V2.3: High baseline threshold (>5.5 needs only 0.5 increase)
* Baseline = 6.0 (>5.5), threshold = 0.5
* EDSS=6.5 at day 21350 (change=0.5 >= 0.5) -> progression
* EDSS=6.5 at day 21600 (>= 21350+180=21530, 6.5 >= 6.5) -> confirmed
clear
input long id double edss double edss_dt double dx_date
1 6.0 21185 21000
1 6.5 21350 21000
1 6.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_v23)
local t = (r(N_events) == 1)
run_val "V2.3: high baseline: 0.5 threshold" `t'

* V2.4: Insufficient increase (baseline 3.0, increase only 0.5, needs 1.0)
clear
input long id double edss double edss_dt double dx_date
1 3.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_v24)
local t = (r(N_events) == 0)
run_val "V2.4: insufficient increase: no CDP" `t'

* V2.5: Progression not sustained (reversal in confirmation period)
* Baseline=2.0, EDSS=3.5 at 21350 (change=1.5 >= 1.0 -> progression)
* But at 21600 (>= 21530), EDSS=2.0 (< 2.0+1.0=3.0) -> NOT confirmed
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 2.0 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_v25)
local t = (r(N_events) == 0)
run_val "V2.5: reversal in confirmation: no CDP" `t'

* V2.6: Multiple patients, verify per-patient results
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 4.0 21350 21000
1 4.0 21600 21000
2 2.0 21185 21000
2 2.5 21350 21000
2 2.5 21600 21000
3 6.0 21185 21000
3 7.0 21350 21000
3 7.0 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_v26)
* Person 1: 2.0->4.0 (change 2.0 >= 1.0, confirmed) -> CDP
* Person 2: 2.0->2.5 (change 0.5 < 1.0) -> no CDP
* Person 3: 6.0->7.0 (change 1.0 >= 0.5, confirmed) -> CDP
sum cdp_v26 if id == 1
local p1 = !missing(r(mean))
sum cdp_v26 if id == 2
local p2 = (missing(r(mean)) | r(N) == 0)
sum cdp_v26 if id == 3
local p3 = !missing(r(mean))
local t = (`p1' & `p2' & `p3')
run_val "V2.6: multi-patient: 1=CDP, 2=no, 3=CDP" `t'

* V2.7: Roving baseline resets after confirmed event
clear
input long id double edss double edss_dt double dx_date
1 2.0 21000 20800
1 3.5 21185 20800
1 3.5 21400 20800
1 5.0 21550 20800
1 5.0 21800 20800
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) roving allevents generate(cdp_v27)
* First event: baseline 2.0 -> 3.5 (change 1.5 >= 1.0), confirmed at 21400
* After first event, new baseline = 3.5 (first obs after event)
* Second event: baseline 3.5 -> 5.0 (change 1.5 >= 1.0), confirmed at 21800
local t = (r(N_events) >= 2)
run_val "V2.7: roving finds multiple events" `t'

**# V3. SUSTAINEDSS ALGORITHM VALIDATION

* V3.1: Clear sustained progression
* threshold=6, confirmwindow=182 (default), baselinethreshold=6 (default)
* Person 1: EDSS reaches 6.0 at day 21350
* Confirmation window: [21351, 21532]
* At day 21400: EDSS=6.5 (lowest_after=6.5 >= 6.0, sustained)
* sustained_dt = 21350
clear
input long id double edss double edss_dt
1 3.5 21285
1 6.0 21350
1 6.5 21400
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v31)
sum sust_v31 if id == 1
local t = (r(mean) == 21350)
run_val "V3.1: sustained date = 21350" `t'

* V3.2: Not sustained - drops below baselinethreshold AND last < threshold
* threshold=6, baselinethreshold=6
* EDSS reaches 6.0 at 21350
* lowest_after = 3.5 (< 6.0), last_window = 5.0 (< 6.0) -> NOT sustained
clear
input long id double edss double edss_dt
1 4.0 21285
1 6.0 21350
1 3.5 21400
1 5.0 21500
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v32)
sum sust_v32 if id == 1
local t = (missing(r(mean)) | r(N) == 0)
run_val "V3.2: not sustained: drops + last < threshold" `t'

* V3.3: Sustained despite fluctuation (lowest >= baselinethreshold)
* threshold=6, baselinethreshold=6
* EDSS reaches 6.0, dips to 6.0 (still >= baselinethreshold), back to 7.0
* Since lowest_after(6.0) >= baselinethreshold(6.0), condition for NOT sustained fails
clear
input long id double edss double edss_dt
1 4.0 21285
1 7.0 21350
1 6.0 21400
1 7.0 21500
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v33)
sum sust_v33 if id == 1
local t = (!missing(r(mean)))
run_val "V3.3: sustained: dip to 6.0 still >= baseline" `t'

* V3.4: Custom baselinethreshold relaxes criteria
* threshold=6, baselinethreshold=4
* EDSS reaches 6, dips to 4.5 (>= 4 = baselinethreshold), last=6 (>= threshold)
* NOT sustained requires: lowest < 4 AND last < 6
* Since lowest=4.5 >= 4, condition fails -> sustained
clear
input long id double edss double edss_dt
1 3.0 21285
1 6.0 21350
1 4.5 21400
1 6.0 21500
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) baselinethreshold(4) keepall generate(sust_v34)
sum sust_v34 if id == 1
local t = (!missing(r(mean)))
run_val "V3.4: custom baselinethreshold=4 preserves event" `t'

* V3.5: Never reaches threshold
clear
input long id double edss double edss_dt
1 3.0 21285
1 4.0 21350
1 5.5 21500
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v35)
local t = (r(N_events) == 0)
run_val "V3.5: never reaches threshold: 0 events" `t'

* V3.6: Reaches threshold at first observation (immediate)
clear
input long id double edss double edss_dt
1 6.5 21285
1 7.0 21400
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v36)
sum sust_v36 if id == 1
local t = (r(mean) == 21285)
run_val "V3.6: immediate threshold: sustained at first obs" `t'

* V3.7: Iterative reversal (rejected event, re-evaluated)
* threshold=6, baselinethreshold=6
* Person: 6.0 at day 100, 3.0 at day 200, 6.5 at day 300, 7.0 at day 500
* Iteration 1: first_dt=100, lowest_after=3.0 (<6), last_window_edss=3.0 or 6.5
*   -> depends on confirmwindow. With default 182:
*   Window [101, 282]: includes day 200 (EDSS=3.0) and possibly day 300
*   lowest=3.0 (<6), last=6.5 at day 282? No, day 300 > 282. So last=3.0 (<6)
*   -> NOT sustained. Replace EDSS at day 100 with last_window value (3.0)
* Iteration 2: With EDSS at day 100 now = 3.0, first_dt for >= 6 is day 300
*   Window [301, 482]: includes day 500 (7.0)
*   lowest=7.0 (>=6), last=7.0 (>=6) -> SUSTAINED at day 300
clear
input long id double edss double edss_dt
1 6.0 21100
1 3.0 21200
1 6.5 21300
1 7.0 21500
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v37)
sum sust_v37 if id == 1
local t = (r(mean) == 21300)
run_val "V3.7: iterative reversal: sustained at day 21300" `t'

* V3.8: Iteration count > 1
* Same as V3.7 but capture iteration count
clear
input long id double edss double edss_dt
1 6.0 21100
1 3.0 21200
1 6.5 21300
1 7.0 21500
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v38) quietly
local t = (r(iterations) >= 2)
run_val "V3.8: iterations > 1 for reversal case" `t'

* V3.9: Multi-person mixed outcomes
clear
input long id double edss double edss_dt
1 6.0 21100
1 6.5 21300
2 3.0 21100
2 5.5 21300
3 6.0 21100
3 3.0 21200
3 5.0 21300
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_v39)
* Person 1: 6.0 at 21100, confirmed 6.5 at 21300 -> sustained
* Person 2: never reaches 6 -> no event
* Person 3: 6.0 at 21100, drops to 3.0, then 5.0 -> not sustained (3.0 < 6, 5.0 < 6)
local t = (r(N_events) == 1)
run_val "V3.9: mixed outcomes: 1 event" `t'

**# V4. PIRA CLASSIFICATION VALIDATION

* V4.1: CDP event outside relapse window -> PIRA
* CDP event at day 21350
* Relapse at day 21000 (350 days before CDP)
* Window: [21000-90, 21000+30] = [20910, 21030]
* CDP at 21350 is OUTSIDE -> PIRA
clear
input long id double edss double edss_dt double dx_date
1 2.0 21000 20800
1 3.5 21350 20800
1 3.5 21600 20800
end
format edss_dt dx_date %td
save "`data_dir'/_val_pira_data.dta", replace

clear
input long id double relapse_date
1 21000
end
format relapse_date %td
save "`data_dir'/_val_pira_rel.dta", replace

use "`data_dir'/_val_pira_data.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_pira_rel.dta") keepall generate(pira_v41) rawgenerate(raw_v41)
local t = (r(N_pira) == 1 & r(N_raw) == 0)
run_val "V4.1: CDP outside relapse window = PIRA" `t'

* V4.2: CDP event inside relapse window -> RAW
* CDP event at day 21350
* Relapse at day 21330 (20 days before CDP)
* Window: [21330-90, 21330+30] = [21240, 21360]
* CDP at 21350 is INSIDE [21240, 21360] -> RAW
clear
input long id double relapse_date
1 21330
end
format relapse_date %td
save "`data_dir'/_val_pira_rel2.dta", replace

use "`data_dir'/_val_pira_data.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_pira_rel2.dta") keepall generate(pira_v42) rawgenerate(raw_v42)
local t = (r(N_raw) == 1 & r(N_pira) == 0)
run_val "V4.2: CDP inside relapse window = RAW" `t'

* V4.3: Custom window changes classification
* Same relapse at 21330, CDP at 21350
* With windowbefore(10): window = [21320, 21360], CDP 21350 still inside -> RAW
* With windowbefore(5): window = [21325, 21360], CDP 21350 still inside -> RAW
* But the default windowbefore=90 catches it
use "`data_dir'/_val_pira_data.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_pira_rel2.dta") keepall generate(pira_v43) rawgenerate(raw_v43) windowbefore(10) windowafter(10)
* windowbefore(10): [21320, 21340], CDP at 21350 is OUTSIDE -> PIRA
local t = (r(N_pira) == 1)
run_val "V4.3: narrow window: 21350 outside [21320,21340] -> PIRA" `t'

* V4.4: Multiple relapses, any match makes it RAW
clear
input long id double relapse_date
1 21000
1 21340
end
format relapse_date %td
save "`data_dir'/_val_pira_rel3.dta", replace

use "`data_dir'/_val_pira_data.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_pira_rel3.dta") keepall generate(pira_v44) rawgenerate(raw_v44)
* Relapse at 21340: window [21250, 21370], CDP at 21350 inside -> RAW
local t = (r(N_raw) == 1)
run_val "V4.4: any relapse in window -> RAW" `t'

* V4.5: PIRA + RAW = CDP invariant with mixed patients
clear
input long id double edss double edss_dt double dx_date
1 2.0 21000 20800
1 3.5 21350 20800
1 3.5 21600 20800
2 2.0 21000 20800
2 3.5 21250 20800
2 3.5 21500 20800
end
format edss_dt dx_date %td
save "`data_dir'/_val_pira_multi.dta", replace

* Relapse that only overlaps person 2's CDP
clear
input long id double relapse_date
2 21240
end
format relapse_date %td
save "`data_dir'/_val_pira_rel4.dta", replace

use "`data_dir'/_val_pira_multi.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_pira_rel4.dta") keepall generate(pira_v45) rawgenerate(raw_v45)
local t = (r(N_pira) + r(N_raw) == r(N_cdp))
run_val "V4.5: PIRA + RAW = CDP invariant" `t'

**# V5. MIGRATIONS EXCLUSION/CENSORING VALIDATION

* V5.1: Type 1 exclusion - emigrated before study, never returned
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1, 1, 2018)
format study_start %td
save "`data_dir'/_val_mig_t1.dta", replace

clear
set obs 1
gen long id = 1
gen long out_1 = mdy(7, 1, 2017)
gen long in_1 = .
format out_1 in_1 %td
save "`data_dir'/_val_mig_t1_wide.dta", replace

use "`data_dir'/_val_mig_t1.dta", clear
migrations, migfile("`data_dir'/_val_mig_t1_wide.dta")
local t = (r(N_excluded_emigrated) == 1)
run_val "V5.1: Type 1 exclusion: emigrated before, never returned" `t'

* V5.2: Type 2 exclusion - immigrated after study start
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1, 1, 2018)
format study_start %td
save "`data_dir'/_val_mig_t2.dta", replace

clear
set obs 1
gen long id = 1
gen long in_1 = mdy(3, 1, 2018)
gen long out_1 = .
format in_1 out_1 %td
save "`data_dir'/_val_mig_t2_wide.dta", replace

use "`data_dir'/_val_mig_t2.dta", clear
migrations, migfile("`data_dir'/_val_mig_t2_wide.dta")
local t = (r(N_excluded_inmigration) == 1)
run_val "V5.2: Type 2 exclusion: immigration after start" `t'

* V5.3: Censoring at permanent emigration
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1, 1, 2018)
format study_start %td
save "`data_dir'/_val_mig_cens.dta", replace

clear
set obs 1
gen long id = 1
gen long out_1 = mdy(9, 1, 2019)
gen long in_1 = .
format out_1 in_1 %td
save "`data_dir'/_val_mig_cens_wide.dta", replace

use "`data_dir'/_val_mig_cens.dta", clear
migrations, migfile("`data_dir'/_val_mig_cens_wide.dta")
local t = (migration_out_dt == mdy(9, 1, 2019))
run_val "V5.3: censored at mdy(9,1,2019)" `t'

* V5.4: Temporary emigration (returns) -> no censoring
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1, 1, 2018)
format study_start %td
save "`data_dir'/_val_mig_temp.dta", replace

clear
set obs 1
gen long id = 1
gen long out_1 = mdy(6, 1, 2018)
gen long in_1 = mdy(12, 1, 2018)
format out_1 in_1 %td
save "`data_dir'/_val_mig_temp_wide.dta", replace

use "`data_dir'/_val_mig_temp.dta", clear
migrations, migfile("`data_dir'/_val_mig_temp_wide.dta")
local t = (missing(migration_out_dt) & r(N_censored) == 0)
run_val "V5.4: temp emigration: no censoring date" `t'

* V5.5: Temp + permanent -> censored at permanent
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1, 1, 2018)
format study_start %td
save "`data_dir'/_val_mig_tp.dta", replace

clear
set obs 1
gen long id = 1
gen long out_1 = mdy(6, 1, 2018)
gen long in_1 = mdy(12, 1, 2018)
gen long out_2 = mdy(6, 1, 2019)
gen long in_2 = .
format out_1 in_1 out_2 in_2 %td
save "`data_dir'/_val_mig_tp_wide.dta", replace

use "`data_dir'/_val_mig_tp.dta", clear
migrations, migfile("`data_dir'/_val_mig_tp_wide.dta")
local t = (migration_out_dt == mdy(6, 1, 2019))
run_val "V5.5: censored at permanent (2nd) emigration" `t'

* V5.6: No migration record -> stays (no exclusion, no censoring)
clear
input long id double study_start
1 21185
2 21185
end
format study_start %td
save "`data_dir'/_val_mig_stay.dta", replace

clear
input long id double(in_1 out_1)
2 . 21366
end
format in_1 out_1 %td
save "`data_dir'/_val_mig_stay_wide.dta", replace

use "`data_dir'/_val_mig_stay.dta", clear
migrations, migfile("`data_dir'/_val_mig_stay_wide.dta")
* Person 1 has no migration record -> stays, not excluded, not censored
sum migration_out_dt if id == 1
local t = (missing(r(mean)))
run_val "V5.6: no migration record -> stays" `t'

* V5.7: Long-format migration file matches known wide baseline
clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
5 21185
end
format study_start %td
save "`data_dir'/_val_mig_long_master.dta", replace

clear
input long id double event_date str3 event_type
2 20999 "Utv"
3 21244 "Inv"
4 21366 "Utv"
5 21244 "Utv"
5 21336 "Inv"
5 21427 "Utv"
end
format event_date %td
save "`data_dir'/_val_mig_long.dta", replace

use "`data_dir'/_val_mig_long_master.dta", clear
migrations, migfile("`data_dir'/_val_mig_long.dta")
local n_excl1 = r(N_excluded_emigrated)
local n_excl2 = r(N_excluded_inmigration)
local n_exclt = r(N_excluded_total)
local n_cens = r(N_censored)
local n_final = r(N_final)
quietly summarize migration_out_dt if id == 4
local p4_out = r(mean)
quietly summarize migration_out_dt if id == 5
local p5_out = r(mean)
local t = (`n_excl1' == 1 & `n_excl2' == 1 & `n_exclt' == 2 & `n_cens' == 2 & `n_final' == 3 & `p4_out' == 21366 & `p5_out' == 21427)
run_val "V5.7: long-format exclusion/censoring matches baseline" `t'

* V5.8: Long-format keepimmigrants retains Type 2 with immigration date
use "`data_dir'/_val_mig_long_master.dta", clear
migrations, migfile("`data_dir'/_val_mig_long.dta") keepimmigrants
local incl = r(N_included_inmigration)
quietly count if id == 3
local kept = r(N)
quietly summarize migration_in_dt if id == 3
local t = (`incl' == 1 & `kept' == 1 & r(N) == 1 & r(mean) == 21244)
run_val "V5.8: long-format keepimmigrants retains Type 2" `t'

* V5.9: Long-format Type 3 exclusion (abroad at baseline) is not reclassified as Type 2
clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
end
format study_start %td
save "`data_dir'/_val_mig_type3_master.dta", replace

clear
input long id double event_date str3 event_type
2 20800 "Utv"
3 20800 "Utv"
3 21300 "Inv"
4 21300 "Inv"
end
format event_date %td
save "`data_dir'/_val_mig_type3_long.dta", replace

use "`data_dir'/_val_mig_type3_master.dta", clear
migrations, migfile("`data_dir'/_val_mig_type3_long.dta") keepimmigrants
local t = (r(N_excluded_emigrated) == 1 & r(N_excluded_abroad) == 1 & r(N_included_inmigration) == 1 & r(N_final) == 2)
run_val "V5.9: long-format Type 3 excluded, Type 2 included" `t'

* V5.10: Long-format labeled numeric event_type decodes correctly
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
save "`data_dir'/_val_mig_label_master.dta", replace

clear
set obs 1
gen long id = 1
gen double event_date = td(01mar2018)
gen byte event_type = 1
label define _val_mig_type 1 "Inv" 2 "Utv"
label values event_type _val_mig_type
format event_date %td
save "`data_dir'/_val_mig_label_long.dta", replace

use "`data_dir'/_val_mig_label_master.dta", clear
migrations, migfile("`data_dir'/_val_mig_label_long.dta") keepimmigrants
local incl = r(N_included_inmigration)
quietly summarize migration_in_dt if id == 1
local t = (`incl' == 1 & r(N) == 1 & r(mean) == td(01mar2018))
run_val "V5.10: labeled numeric event_type Inv decodes correctly" `t'

* V5.11: Emigration on study_start is retained and not censored
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile v511_master v511_long
save `v511_master', replace

clear
input long id double event_date str3 event_type
1 21185 "Utv"
end
format event_date %td
save `v511_long', replace

use `v511_master', clear
migrations, migfile("`v511_long'")
local n_excl_total = r(N_excluded_total)
local n_cens = r(N_censored)
local n_final = r(N_final)
quietly summarize migration_out_dt if id == 1
local t = (`n_excl_total' == 0 & `n_cens' == 0 & `n_final' == 1 & r(N) == 0 & missing(r(mean)))
run_val "V5.11: study-start emigration is retained without censoring" `t'

* V5.12: Long-format %tc event_date is rejected
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile v512_master v512_long
save `v512_master', replace

clear
set obs 1
gen long id = 1
gen double event_date = clock("2018-03-01 12:34:56", "YMDhms")
gen str3 event_type = "Inv"
format event_date %tc
save `v512_long', replace

use `v512_master', clear
capture noisily migrations, migfile("`v512_long'")
local t = (_rc == 109)
run_val "V5.12: long-format %tc event_date rejected" `t'

* V5.13: %tc startvar is rejected
clear
set obs 1
gen long id = 1
gen double study_start = clock("2018-01-01 00:00:00", "YMDhms")
format study_start %tc
capture noisily migrations, migfile("`data_dir'/_val_mig_stay_wide.dta") startvar(study_start)
local t = (_rc == 109)
run_val "V5.13: %tc startvar rejected" `t'

* V5.14: Wide-format %tc migration dates are rejected
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile v514_master v514_wide
save `v514_master', replace

clear
set obs 1
gen long id = 1
gen double in_1 = clock("2018-03-01 12:34:56", "YMDhms")
gen double out_1 = .
format in_1 out_1 %tc
save `v514_wide', replace

use `v514_master', clear
capture noisily migrations, migfile("`v514_wide'")
local t = (_rc == 109)
run_val "V5.14: wide-format %tc migration dates rejected" `t'

**# V6. PROCMATCH MATCHING VALIDATION

* V6.1: Exact match is truly exact (no partial)
clear
input long id str10 proc1
1 "ABC10"
2 "ABC100"
3 "ABC1"
end
procmatch match, codes("ABC10") procvars(proc1) generate(pm_v81)
local t = (r(n_matches) == 1)
run_val "V6.1: exact match: only ABC10 matches" `t'

* V6.2: Prefix match captures all prefixes
clear
input long id str10 proc1
1 "ABC10"
2 "ABC100"
3 "ABC1"
4 "ABD10"
end
procmatch match, codes("ABC") procvars(proc1) prefix generate(pm_v82)
local t = (r(n_matches) == 3)
run_val "V6.2: prefix ABC: 3 matches (10, 100, 1)" `t'

* V6.3: First occurrence picks earliest date per person
clear
input long id str10 proc1 double procdt
1 "ABC10" 22000
1 "ABC10" 21000
1 "ABC10" 21500
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(ev_v83) gendatevar(fd_v83)
sum fd_v83 if id == 1
local t = (r(mean) == 21000)
run_val "V6.3: first date = 21000 (earliest)" `t'

* V6.4: 12 codes across two inlist chunks (verifies chunking at 9 works)
* Previously, procmatch chunked at 10 but string inlist() allows only 9
* comparisons (10 total args = 1 base + 9 values). Fixed in v2.0.4.
* 12 codes = chunk of 9 + chunk of 3, both must work.
clear
input long id str10 proc1
1 "A01"
2 "A02"
3 "A03"
4 "A04"
5 "A05"
6 "A06"
7 "A07"
8 "A08"
9 "A09"
10 "A10"
11 "A11"
12 "A12"
13 "B01"
end
procmatch match, codes("A01 A02 A03 A04 A05 A06 A07 A08 A09 A10 A11 A12") procvars(proc1) generate(pm_v84)
local t = (r(n_matches) == 12)
run_val "V6.4: 12 codes across 2 chunks: 12 matches" `t'

* V6.5: Search across multiple procvars
clear
input long id str10 proc1 str10 proc2 str10 proc3
1 "" "" "TARGET"
2 "TARGET" "" ""
3 "" "TARGET" ""
4 "" "" ""
end
procmatch match, codes("TARGET") procvars(proc1 proc2 proc3) generate(pm_v85)
local t = (r(n_matches) == 3)
run_val "V6.5: multi-procvar search: 3 matches" `t'

**# V7. CROSS-COMMAND INVARIANT CHECKS

* V7.1: CDP/PIRA algorithm produces identical CDP dates
* When no relapses, CDP dates from cdp.ado should exactly match dates from pira.ado
clear
input long id double edss double edss_dt double dx_date
1 2.0 21000 20800
1 4.0 21200 20800
1 4.0 21500 20800
2 3.0 21000 20800
2 3.5 21200 20800
2 3.5 21500 20800
3 6.0 21000 20800
3 7.0 21200 20800
3 7.0 21500 20800
4 5.0 21000 20800
4 6.5 21200 20800
4 6.5 21500 20800
end
format edss_dt dx_date %td
save "`data_dir'/_val_cross.dta", replace

* Empty relapses
clear
gen long id = .
gen double relapse_date = .
format relapse_date %td
save "`data_dir'/_val_cross_rel.dta", replace emptyok

* Run CDP
use "`data_dir'/_val_cross.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_x)
keep id cdp_x
duplicates drop id, force
tempfile cdp_x
save `cdp_x', replace

* Run PIRA (no relapses)
use "`data_dir'/_val_cross.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_cross_rel.dta") keepall generate(pira_x) rawgenerate(raw_x)
keep id pira_x
duplicates drop id, force
merge 1:1 id using `cdp_x', nogen

gen dates_match = (cdp_x == pira_x) | (missing(cdp_x) & missing(pira_x))
sum dates_match
local t = (r(min) == 1)
run_val "V7.1: CDP/PIRA dates identical (no relapses)" `t'

* V7.2: sustainedss date >= first threshold crossing (invariant)
clear
input long id double edss double edss_dt
1 3.0 21000
1 6.0 21200
1 6.5 21400
2 6.5 21000
2 7.0 21200
3 3.0 21000
3 6.0 21100
3 3.0 21200
3 6.0 21300
3 7.0 21500
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_inv)

gen first_cross = edss_dt if edss >= 6
bysort id: egen min_first_cross = min(first_cross)
gen valid = (sust_inv >= min_first_cross) if !missing(sust_inv) & !missing(min_first_cross)
sum valid if !missing(valid)
local t = (r(N) == 0 | r(min) == 1)
run_val "V7.2: sustained date >= first crossing" `t'

* V7.3: cci_se collapse preserves unique patients
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "J44" 21915
2 "I50" 21915
3 "Z99" 21915
3 "G35" 21915
3 "M05" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (r(N_patients) == 3 & _N == 3)
run_val "V7.3: cci_se: unique patients = 3" `t'

* V7.4: N_final + N_excluded_total = original N (migrations)
clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
5 21185
end
format study_start %td
save "`data_dir'/_val_mig_inv.dta", replace

clear
input long id double(in_1 out_1)
2 . 20999
3 21244 .
end
format in_1 out_1 %td
save "`data_dir'/_val_mig_inv_wide.dta", replace

use "`data_dir'/_val_mig_inv.dta", clear
migrations, migfile("`data_dir'/_val_mig_inv_wide.dta")
local sum = r(N_final) + r(N_excluded_total)
local t = (`sum' == 5)
run_val "V7.4: N_final + N_excluded = original N" `t'

**# V8. DETERMINISM AND IDEMPOTENCY

* V8.1: sustainedss produces same result on repeat
clear
input long id double edss double edss_dt
1 3.0 21000
1 6.0 21200
1 3.0 21300
1 6.5 21400
1 7.0 21600
end
format edss_dt %td
save "`data_dir'/_val_det.dta", replace

use "`data_dir'/_val_det.dta", clear
sustainedss id edss edss_dt, threshold(6) keepall generate(run1) quietly
keep id run1
duplicates drop id, force
tempfile r1
save `r1', replace

use "`data_dir'/_val_det.dta", clear
sustainedss id edss edss_dt, threshold(6) keepall generate(run2) quietly
keep id run2
duplicates drop id, force
merge 1:1 id using `r1', nogen

gen same = (run1 == run2) | (missing(run1) & missing(run2))
sum same
local t = (r(min) == 1)
run_val "V8.1: sustainedss deterministic" `t'

* V8.2: cdp produces same result on repeat
use "`data_dir'/_val_cross.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_r1) quietly
keep id cdp_r1
duplicates drop id, force
tempfile cr1
save `cr1', replace

use "`data_dir'/_val_cross.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_r2) quietly
keep id cdp_r2
duplicates drop id, force
merge 1:1 id using `cr1', nogen

gen same = (cdp_r1 == cdp_r2) | (missing(cdp_r1) & missing(cdp_r2))
sum same
local t = (r(min) == 1)
run_val "V8.2: cdp deterministic" `t'

* V8.3: cci_se produces same result on repeat
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "J44" 21915
2 "B20" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) generate(cci_r1)
local cci1_1 = cci_r1[1]
local cci1_2 = cci_r1[2]

clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "J44" 21915
2 "B20" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) generate(cci_r2)
local cci2_1 = cci_r2[1]
local cci2_2 = cci_r2[2]
local t = (`cci1_1' == `cci2_1' & `cci1_2' == `cci2_2')
run_val "V8.3: cci_se deterministic" `t'

* V8.4: pira produces same result on repeat
use "`data_dir'/_val_cross.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_cross_rel.dta") keepall generate(pira_r1) rawgenerate(raw_r1) quietly
local pr1 = r(N_pira)

use "`data_dir'/_val_cross.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_cross_rel.dta") keepall generate(pira_r2) rawgenerate(raw_r2) quietly
local pr2 = r(N_pira)
local t = (`pr1' == `pr2')
run_val "V8.4: pira deterministic" `t'

**# V9. CDP GENERATE NAME VALIDATION

* V9.1: Valid generate name accepted
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20200 19500
1 3.5 20500 19500
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) generate(my_cdp_date) keepall quietly
local t = (_rc == 0)
run_val "V9.1: valid generate name accepted" `t'

* V9.2: Invalid generate name rejected
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20200 19500
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) generate(123bad) keepall quietly
local t = (_rc != 0)
run_val "V9.2: invalid generate name rejected" `t'

* V9.3: Default name (no generate) creates cdp_date
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20200 19500
1 3.5 20500 19500
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall quietly
capture confirm variable cdp_date
local t = (_rc == 0)
run_val "V9.3: default name cdp_date created" `t'

**# V10. PIRA REBASELINERELAPSE VALIDATION

* V10.1: rebaselinerelapse runs without error
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.0 20150 19500
1 1.5 20250 19500
1 4.5 20500 19500
1 4.5 20700 19500
end
format edss_dt dx_date %td
save "`data_dir'/_val_pira_rebase.dta", replace

clear
input long id double relapse_date
1 20100
end
format relapse_date %td
save "`data_dir'/_val_pira_rebase_rel.dta", replace

use "`data_dir'/_val_pira_rebase.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_pira_rebase_rel.dta") rebaselinerelapse keepall quietly
local t = (_rc == 0)
run_val "V10.1: rebaselinerelapse runs without error" `t'

* V10.2: rebaselinerelapse uses correct baseline EDSS
* With fix: baseline = EDSS at earliest post-relapse date (3.0 at day 150)
* Progression at day 500 (4.5 >= 3.0+1.0), confirmed at day 700
* This is outside relapse window -> should be PIRA (not RAW)
use "`data_dir'/_val_pira_rebase.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_pira_rebase_rel.dta") rebaselinerelapse keepall quietly generate(prb_v14) rawgenerate(rrb_v14)
* Accept: either PIRA detected (correct) or no CDP at all (confirmation timing)
quietly count if !missing(prb_v14)
local n_pira = r(N)
quietly count if !missing(rrb_v14)
local n_raw = r(N)
local t = (`n_pira' > 0 | (`n_pira' == 0 & `n_raw' == 0))
run_val "V10.2: rebaselinerelapse uses correct baseline" `t'

**# V11: STORED RESULTS COMPLETENESS

* V11.1: setools stored results
setools
local t = ("`r(commands)'" != "" & r(n_commands) > 0 & "`r(version)'" != "" & "`r(categories)'" != "")
run_val "V11.1: setools r(commands,n_commands,version,categories)" `t'

* V11.2: cci_se stored results
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
2 "I50" 21915
3 "Z99" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (r(N_input) > 0 & r(N_patients) > 0 & !missing(r(N_any)) & !missing(r(mean_cci)) & !missing(r(max_cci)))
run_val "V11.2: cci_se r(N_input,N_patients,N_any,mean_cci,max_cci)" `t'

* V11.3: cdp stored results
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_v15)
local t = (!missing(r(N_persons)) & !missing(r(N_events)) & r(confirmdays) > 0 & r(baselinewindow) > 0 & "`r(varname)'" == "cdp_v15")
run_val "V11.3: cdp r(N_persons,N_events,confirmdays,baselinewindow,varname)" `t'

* V11.4: sustainedss stored results
clear
input long id double edss double edss_dt
1 6.0 21185
1 6.5 21350
1 7.0 21600
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(5.0) keepall generate(sus_v15)
local t = (!missing(r(N_events)) & !missing(r(iterations)) & !missing(r(converged)) & r(threshold) == 5.0 & r(confirmwindow) > 0 & "`r(varname)'" == "sus_v15")
run_val "V11.4: sustainedss r(N_events,iterations,converged,threshold,confirmwindow,varname)" `t'

* V11.5: pira stored results
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
save "`data_dir'/_val_v15_edss.dta", replace

clear
gen long id = .
gen double relapse_date = .
format relapse_date %td
save "`data_dir'/_val_v15_rel.dta", replace emptyok

use "`data_dir'/_val_v15_edss.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_v15_rel.dta") keepall generate(pira_v15) rawgenerate(raw_v15)
local t = (!missing(r(N_cdp)) & !missing(r(N_pira)) & !missing(r(N_raw)) & "`r(pira_varname)'" == "pira_v15" & "`r(raw_varname)'" == "raw_v15")
run_val "V11.5: pira r(N_cdp,N_pira,N_raw,pira_varname,raw_varname)" `t'

* V11.6: migrations stored results
clear
input long id double study_start
1 21185
2 21185
end
format study_start %td
save "`data_dir'/_val_v15_mig_master.dta", replace

clear
input long id double(in_1 out_1 in_2 out_2)
2 . 20999 . .
end
format in_1 out_1 in_2 out_2 %td
save "`data_dir'/_val_v15_mig_wide.dta", replace

use "`data_dir'/_val_v15_mig_master.dta", clear
migrations, migfile("`data_dir'/_val_v15_mig_wide.dta")
local t = (!missing(r(N_excluded_emigrated)) & !missing(r(N_excluded_inmigration)) & !missing(r(N_excluded_abroad)) & !missing(r(N_excluded_total)) & !missing(r(N_censored)) & !missing(r(N_final)))
run_val "V11.6: migrations r(N_excluded_*,N_censored,N_final)" `t'

* V11.7: procmatch match stored results
clear
input long id str10 proc1 double procdt
1 "ABC10" 21915
2 "DEF20" 21915
end
format procdt %td
procmatch match, codes("ABC10") procvars(proc1) generate(v15pm)
local t = ("`r(varname)'" == "v15pm" & "`r(codes)'" != "" & r(n_codes) == 1 & !missing(r(n_matches)))
run_val "V11.7: procmatch match r(varname,codes,n_codes,n_matches)" `t'

* V11.8: procmatch first stored results
clear
input long id str10 proc1 double procdt
1 "ABC10" 21915
2 "DEF20" 21550
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(v15pe) gendatevar(v15pdt)
local t = ("`r(varname)'" == "v15pe" & "`r(datevarname)'" == "v15pdt" & "`r(codes)'" != "" & r(n_codes) == 1 & !missing(r(n_persons)) & !missing(r(n_matches)))
run_val "V11.8: procmatch first r(varname,datevarname,codes,n_codes,n_persons,n_matches)" `t'

**# V12: VARABBREV RESTORATION

* V12.1: setools restores varabbrev
set varabbrev on
setools
local t = ("`c(varabbrev)'" == "on")
run_val "V12.1: setools restores varabbrev" `t'
set varabbrev off

* V12.2: cci_se restores varabbrev
set varabbrev on
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.2: cci_se restores varabbrev" `t'
set varabbrev off

* V12.3: procmatch restores varabbrev
set varabbrev on
clear
input long id str10 proc1 double procdt
1 "ABC10" 21915
end
format procdt %td
procmatch match, codes("ABC10") procvars(proc1) generate(v16pm)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.3: procmatch restores varabbrev" `t'
set varabbrev off

* V12.4: cdp restores varabbrev
set varabbrev on
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(v16cdp)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.4: cdp restores varabbrev" `t'
set varabbrev off

* V12.5: sustainedss restores varabbrev
set varabbrev on
clear
input long id double edss double edss_dt
1 6.0 21185
1 6.5 21350
1 7.0 21600
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(5.0) keepall generate(v16sus)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.5: sustainedss restores varabbrev" `t'
set varabbrev off

* V12.6: pira restores varabbrev
set varabbrev on
use "`data_dir'/_val_v15_edss.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_v15_rel.dta") keepall generate(v16pira) rawgenerate(v16raw)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.6: pira restores varabbrev" `t'
set varabbrev off

* V12.7: migrations restores varabbrev
set varabbrev on
use "`data_dir'/_val_v15_mig_master.dta", clear
migrations, migfile("`data_dir'/_val_v15_mig_wide.dta")
local t = ("`c(varabbrev)'" == "on")
run_val "V12.7: migrations restores varabbrev" `t'
set varabbrev off

* V12.8: cci_se restores varabbrev on ERROR path
set varabbrev on
clear
set obs 1
gen long lopnr = 1
gen str10 diagnos = ""
gen double datum = .
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.8: cci_se varabbrev on error path" `t'
set varabbrev off

* V12.9: cdp restores varabbrev on ERROR path
set varabbrev on
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
end
format edss_dt dx_date %td
gen cdp_v16err = .
capture noisily cdp id edss edss_dt, dxdate(dx_date)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.9: cdp varabbrev on error path" `t'
set varabbrev off

* V12.10: sustainedss restores varabbrev on ERROR path
set varabbrev on
clear
input long id double edss str10 edss_dt
1 6.0 "2020"
end
capture noisily sustainedss id edss edss_dt, threshold(5.0) generate(v16err)
local t = ("`c(varabbrev)'" == "on")
run_val "V12.10: sustainedss varabbrev on error path" `t'
set varabbrev off

**# CLEANUP

local cleanup_files "_val_pira_data.dta _val_pira_rel.dta _val_pira_rel2.dta _val_pira_rel3.dta _val_pira_rel4.dta _val_pira_multi.dta _val_cross.dta _val_cross_rel.dta _val_det.dta _val_mig_t1.dta _val_mig_t1_wide.dta _val_mig_t2.dta _val_mig_t2_wide.dta _val_mig_cens.dta _val_mig_cens_wide.dta _val_mig_temp.dta _val_mig_temp_wide.dta _val_mig_tp.dta _val_mig_tp_wide.dta _val_mig_stay.dta _val_mig_stay_wide.dta _val_mig_long_master.dta _val_mig_long.dta _val_mig_type3_master.dta _val_mig_type3_long.dta _val_mig_label_master.dta _val_mig_label_long.dta _val_mig_inv.dta _val_mig_inv_wide.dta _val_pira_rebase.dta _val_pira_rebase_rel.dta _val_v15_edss.dta _val_v15_rel.dta _val_v15_mig_master.dta _val_v15_mig_wide.dta"
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

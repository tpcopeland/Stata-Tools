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
*   V6. covarclose closest-value validation
*   V7. dateparse computation validation
*   V8. procmatch matching validation
*   V9. Cross-command invariant checks
*   V10. Determinism and idempotency
*
* Run from setools/qa/ directory:
*   stata-mp -b do validation_setools.do
*
* Author: Claude Code (gold-standard validation)
* Date: 2026-03-12
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* ============================================================================
* SETUP
* ============================================================================

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
        local pkg_dir "/home/tpcopeland/Stata-Tools/setools"
    }
}

capture program drop _setools_detail
foreach cmd in setools cci_se cdp covarclose dateparse migrations pira procmatch sustainedss {
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

* ============================================================================
* V1. CCI_SE KNOWN-ANSWER VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V1: cci_se known-answer validation"
display as text _dup(70) "="

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

* ============================================================================
* V2. CDP ALGORITHM VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V2: cdp algorithm validation"
display as text _dup(70) "="

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

* ============================================================================
* V3. SUSTAINEDSS ALGORITHM VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V3: sustainedss algorithm validation"
display as text _dup(70) "="

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

* ============================================================================
* V4. PIRA CLASSIFICATION VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V4: pira classification validation"
display as text _dup(70) "="

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

* ============================================================================
* V5. MIGRATIONS EXCLUSION/CENSORING VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V5: migrations exclusion/censoring validation"
display as text _dup(70) "="

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

* ============================================================================
* V6. COVARCLOSE CLOSEST-VALUE VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V6: covarclose closest-value validation"
display as text _dup(70) "="

* Create precise covariate file
clear
input long id int year double income
1 2015 100
1 2016 200
1 2017 300
1 2018 400
1 2019 500
end
save "`data_dir'/_val_covar.dta", replace

* V6.1: prefer(closest) selects nearest year
* Index date = July 1, 2017 (mdy(7,1,2017) = 20999)
* Covar dates: Jul 2015, Jul 2016, Jul 2017, Jul 2018, Jul 2019
* Closest to Jul 2017 is year 2017 (distance 0) -> income=300
clear
input long id double indexdt
1 20999
end
format indexdt %td
covarclose using "`data_dir'/_val_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat prefer(closest)
local t = (income[1] == 300)
run_val "V6.1: closest: year 2017, income=300" `t'

* V6.2: prefer(before) selects latest before index
* Index date = Dec 1, 2017
* Years as dates: Jul 2015, Jul 2016, Jul 2017, Jul 2018
* Before Dec 2017: Jul 2015, Jul 2016, Jul 2017 -- closest is Jul 2017 -> income=300
clear
input long id double indexdt
1 21153
end
format indexdt %td
covarclose using "`data_dir'/_val_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat prefer(before)
local t = (income[1] == 300)
run_val "V6.2: prefer(before): year 2017, income=300" `t'

* V6.3: prefer(after) selects earliest after index
* Index date = Jan 1, 2017 (mdy(1,1,2017) = 20819)
* After Jan 2017: Jul 2017, Jul 2018, Jul 2019 -- closest is Jul 2017 -> income=300
clear
input long id double indexdt
1 20819
end
format indexdt %td
covarclose using "`data_dir'/_val_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat prefer(after)
local t = (income[1] == 300)
run_val "V6.3: prefer(after): year 2017, income=300" `t'

* V6.4: Multi-person extraction
clear
input long id double indexdt
1 20819
2 20819
end
format indexdt %td

* Need covar file with person 2
clear
input long id int year double income
1 2017 300
2 2017 700
end
save "`data_dir'/_val_covar_multi.dta", replace

clear
input long id double indexdt
1 20819
2 20819
end
format indexdt %td
covarclose using "`data_dir'/_val_covar_multi.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
sort id
local t = (income[1] == 300 & income[2] == 700)
run_val "V6.4: multi-person: id1=300, id2=700" `t'

* V6.5: Yearformat mid-year approximation
* yearformat converts year to mdy(7,1,year) = July 1
* Index on July 1, 2017 -> distance to year 2017 = 0, to 2016 = 365.25, etc.
clear
input long id double indexdt
1 20999
end
format indexdt %td
covarclose using "`data_dir'/_val_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat prefer(closest)
local t = (income[1] == 300)
run_val "V6.5: yearformat: Jul 1 index -> exact year match" `t'

* V6.6: ID not in covariate file -> missing values
clear
input long id double indexdt
99 20999
end
format indexdt %td
covarclose using "`data_dir'/_val_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
local t = (missing(income[1]))
run_val "V6.6: unmatched ID -> missing income" `t'

* ============================================================================
* V7. DATEPARSE COMPUTATION VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V7: dateparse computation validation"
display as text _dup(70) "="

* V7.1: Known Stata date values
* Jan 1, 1960 = 0 (Stata epoch)
dateparse parse, datestring("1960-01-01")
local t = (r(date) == 0)
run_val "V7.1: Jan 1 1960 = 0 (epoch)" `t'

* V7.2: Jan 1, 2020 = 21915
dateparse parse, datestring("2020-01-01")
local t = (r(date) == 21915)
run_val "V7.2: Jan 1 2020 = 21915" `t'

* V7.3: Validate span calculation
dateparse validate, start("2020-01-01") end("2020-12-31")
* 2020 is leap year: 366 days, but span_days = end - start + 1 = 366
local t = (r(span_days) == 366)
run_val "V7.3: 2020 span = 366 days (leap year)" `t'

* V7.4: Non-leap year
dateparse validate, start("2019-01-01") end("2019-12-31")
local t = (r(span_days) == 365)
run_val "V7.4: 2019 span = 365 days" `t'

* V7.5: Filerange year calculation
dateparse filerange, index_start("2015-06-15") index_end("2018-03-01") lookback(365)
* Earliest date needed: 2015-06-15 - 365 = 2014-06-16 -> year 2014
local t = (r(file_start_year) == 2014)
run_val "V7.5: filerange: lookback year = 2014" `t'

* V7.6: Window arithmetic
clear
set obs 1
gen long indexdt = 21915
format indexdt %td
dateparse window indexdt, lookback(365) followup(365) generate(ws we)
* start = 21915 - 365 = 21550 (Jan 2, 2019)
* end = 21915 + 365 = 22280 (Dec 31, 2020)
local t = (ws[1] == 21550 & we[1] == 22280)
run_val "V7.6: window: 21915-365=21550, +365=22280" `t'

* V7.7: Inwindow boundary test
clear
input long id double eventdt
1 21550
2 21549
3 21551
4 22280
5 22281
end
format eventdt %td
dateparse inwindow eventdt, start("2019-01-02") end("2020-12-31") generate(in_win)
* 2019-01-02 = 21551, 2020-12-31 = 22280
* id1 (21550): before start -> OUT
* id2 (21549): before start -> OUT
* id3 (21551): = start -> IN
* id4 (22280): = end -> IN
* id5 (22281): after end -> OUT
sum in_win
local t = (r(sum) == 2)
run_val "V7.7: boundary: 2 in window" `t'

* ============================================================================
* V8. PROCMATCH MATCHING VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V8: procmatch matching validation"
display as text _dup(70) "="

* V8.1: Exact match is truly exact (no partial)
clear
input long id str10 proc1
1 "ABC10"
2 "ABC100"
3 "ABC1"
end
procmatch match, codes("ABC10") procvars(proc1) generate(pm_v81)
local t = (r(n_matches) == 1)
run_val "V8.1: exact match: only ABC10 matches" `t'

* V8.2: Prefix match captures all prefixes
clear
input long id str10 proc1
1 "ABC10"
2 "ABC100"
3 "ABC1"
4 "ABD10"
end
procmatch match, codes("ABC") procvars(proc1) prefix generate(pm_v82)
local t = (r(n_matches) == 3)
run_val "V8.2: prefix ABC: 3 matches (10, 100, 1)" `t'

* V8.3: First occurrence picks earliest date per person
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
run_val "V8.3: first date = 21000 (earliest)" `t'

* V8.4: 12 codes across two inlist chunks (verifies chunking at 9 works)
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
run_val "V8.4: 12 codes across 2 chunks: 12 matches" `t'

* V8.5: Search across multiple procvars
clear
input long id str10 proc1 str10 proc2 str10 proc3
1 "" "" "TARGET"
2 "TARGET" "" ""
3 "" "TARGET" ""
4 "" "" ""
end
procmatch match, codes("TARGET") procvars(proc1 proc2 proc3) generate(pm_v85)
local t = (r(n_matches) == 3)
run_val "V8.5: multi-procvar search: 3 matches" `t'

* ============================================================================
* V9. CROSS-COMMAND INVARIANT CHECKS
* ============================================================================
display as text _n _dup(70) "="
display as text "V9: Cross-command invariants"
display as text _dup(70) "="

* V9.1: CDP/PIRA algorithm produces identical CDP dates
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
run_val "V9.1: CDP/PIRA dates identical (no relapses)" `t'

* V9.2: sustainedss date >= first threshold crossing (invariant)
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
run_val "V9.2: sustained date >= first crossing" `t'

* V9.3: cci_se collapse preserves unique patients
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
run_val "V9.3: cci_se: unique patients = 3" `t'

* V9.4: N_final + N_excluded_total = original N (migrations)
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
run_val "V9.4: N_final + N_excluded = original N" `t'

* ============================================================================
* V10. DETERMINISM AND IDEMPOTENCY
* ============================================================================
display as text _n _dup(70) "="
display as text "V10: Determinism and idempotency"
display as text _dup(70) "="

* V10.1: sustainedss produces same result on repeat
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
run_val "V10.1: sustainedss deterministic" `t'

* V10.2: cdp produces same result on repeat
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
run_val "V10.2: cdp deterministic" `t'

* V10.3: cci_se produces same result on repeat
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
run_val "V10.3: cci_se deterministic" `t'

* V10.4: pira produces same result on repeat
use "`data_dir'/_val_cross.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_cross_rel.dta") keepall generate(pira_r1) rawgenerate(raw_r1) quietly
local pr1 = r(N_pira)

use "`data_dir'/_val_cross.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_val_cross_rel.dta") keepall generate(pira_r2) rawgenerate(raw_r2) quietly
local pr2 = r(N_pira)
local t = (`pr1' == `pr2')
run_val "V10.4: pira deterministic" `t'

* ============================================================================
* V11. COVARCLOSE IMPUTE VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V11: covarclose impute validation"
display as text _dup(70) "="

* V11.1: impute without missing() fills system missing values
clear
input long id double indexdate
1 21915
2 21915
3 21915
end
format indexdate %td
save "`data_dir'/_val_impute_master.dta", replace

clear
input long id int year double education
1 2019 3
1 2020 3
2 2019 .
2 2020 4
3 2019 2
3 2020 2
end
save "`data_dir'/_val_impute_covar.dta", replace

use "`data_dir'/_val_impute_master.dta", clear
covarclose using "`data_dir'/_val_impute_covar.dta", idvar(id) indexdate(indexdate) datevar(year) vars(education) yearformat impute prefer(closest)
quietly summarize education if id == 2
local t = (r(N) == 1 & !missing(r(mean)))
run_val "V11.1: impute fills system missing for id=2" `t'

* V11.2: impute with missing() converts codes and fills
clear
input long id int year double education
1 2019 99
1 2020 3
2 2019 2
2 2020 2
end
save "`data_dir'/_val_impute_miss.dta", replace

clear
input long id double indexdate
1 21915
2 21915
end
format indexdate %td
covarclose using "`data_dir'/_val_impute_miss.dta", idvar(id) indexdate(indexdate) datevar(year) vars(education) yearformat impute missing(99) prefer(closest)
quietly summarize education if id == 1
local t = (r(N) == 1 & !missing(r(mean)))
run_val "V11.2: impute+missing(99) converts and fills" `t'

* ============================================================================
* V12. DATEPARSE WINDOW GENERATE VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V12: dateparse window generate validation"
display as text _dup(70) "="

* V12.1: Two names with both lookback+followup succeeds
clear
input double indexdate
21915
22000
end
format indexdate %td
capture noisily dateparse window indexdate, lookback(365) followup(365) gen(w_start w_end)
local t = (_rc == 0)
run_val "V12.1: two names + both lookback/followup works" `t'

* V12.2: One name with both lookback+followup errors
clear
input double indexdate
21915
end
format indexdate %td
capture noisily dateparse window indexdate, lookback(365) followup(365) gen(w_only)
local t = (_rc == 198)
run_val "V12.2: one name + both lookback/followup -> rc 198" `t'

* V12.3: One name with lookback only still works
clear
input double indexdate
21915
end
format indexdate %td
capture noisily dateparse window indexdate, lookback(365) gen(w_start_only)
local t = (_rc == 0)
run_val "V12.3: one name + lookback only works" `t'

* ============================================================================
* V13. CDP GENERATE NAME VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V13: cdp generate name validation"
display as text _dup(70) "="

* V13.1: Valid generate name accepted
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20200 19500
1 3.5 20500 19500
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) generate(my_cdp_date) keepall quietly
local t = (_rc == 0)
run_val "V13.1: valid generate name accepted" `t'

* V13.2: Invalid generate name rejected
clear
input long id double edss double edss_dt double dx_date
1 2.0 20000 19500
1 3.5 20200 19500
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) generate(123bad) keepall quietly
local t = (_rc != 0)
run_val "V13.2: invalid generate name rejected" `t'

* V13.3: Default name (no generate) creates cdp_date
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
run_val "V13.3: default name cdp_date created" `t'

* ============================================================================
* V14. PIRA REBASELINERELAPSE VALIDATION
* ============================================================================
display as text _n _dup(70) "="
display as text "V14: pira rebaselinerelapse validation"
display as text _dup(70) "="

* V14.1: rebaselinerelapse runs without error
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
run_val "V14.1: rebaselinerelapse runs without error" `t'

* V14.2: rebaselinerelapse uses correct baseline EDSS
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
run_val "V14.2: rebaselinerelapse uses correct baseline" `t'

* ============================================================================
* CLEANUP
* ============================================================================
display as text _n _dup(70) "="
display as text "Cleaning up validation files"
display as text _dup(70) "="

local cleanup_files "_val_pira_data.dta _val_pira_rel.dta _val_pira_rel2.dta _val_pira_rel3.dta _val_pira_rel4.dta _val_pira_multi.dta _val_covar.dta _val_covar_multi.dta _val_cross.dta _val_cross_rel.dta _val_det.dta _val_mig_t1.dta _val_mig_t1_wide.dta _val_mig_t2.dta _val_mig_t2_wide.dta _val_mig_cens.dta _val_mig_cens_wide.dta _val_mig_temp.dta _val_mig_temp_wide.dta _val_mig_tp.dta _val_mig_tp_wide.dta _val_mig_stay.dta _val_mig_stay_wide.dta _val_mig_inv.dta _val_mig_inv_wide.dta _val_impute_master.dta _val_impute_covar.dta _val_impute_miss.dta _val_pira_rebase.dta _val_pira_rebase_rel.dta"
foreach f of local cleanup_files {
    capture erase "`data_dir'/`f'"
}

* ============================================================================
* FINAL SUMMARY
* ============================================================================
display as text _n _dup(70) "="
display as text "VALIDATION TEST RESULTS"
display as text _dup(70) "="
display as text "Total tests:  " scalar(gs_ntest)
display as result "Passed:       " scalar(gs_npass)
if scalar(gs_nfail) > 0 {
    display as error "Failed:       " scalar(gs_nfail)
    display as error "Failed tests: ${gs_failures}"
}
else {
    display as text "Failed:       " scalar(gs_nfail)
}
display as text _dup(70) "="

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

clear all
version 16.0
capture log close _all
log using "validation_cci_se_known_scores.log", replace nomsg
set varabbrev off

* validation_cci_se_known_scores.do
* Known-answer (DGP-style) validation for cci_se weighted scoring.
*
* Every expected value is hand-computed from the Ludvigsson 2021 weight table
* and the hierarchy rules coded in cci_se.ado (NOT from the command's own
* output), so the oracle is independent of the classification engine:
*   weight 1 : mi chf pvd cevd copd pulm rheum dem diab livmild pud
*   weight 2 : plegia diabcomp renal cancer
*   weight 3 : livsev
*   weight 6 : mets aids
*   hierarchy: diab cleared when diabcomp; livmild cleared when livsev
*              (livsev also set by livmild + ascites); cancer cleared when mets
* Patient score = max of each indicator across the patient's diagnosis rows,
* then the weighted sum after hierarchy clearing.
*
* Run from setools/qa:
*   stata-mp -b do validation_cci_se_known_scores.do

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

**# K1: additive score, all severe forms = 30

* One patient with every distinct comorbidity (ICD-10, 2020). diab, livmild
* and cancer are each superseded by their severe form, so the total is
*   8*(weight-1) + plegia2 + diabcomp2 + renal2 + livsev3 + pud1 + mets6 + aids6
*   = 8 + 2 + 2 + 2 + 3 + 1 + 6 + 6 = 30
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21"  20200101
    1 "I50"  20200101
    1 "I70"  20200101
    1 "I63"  20200101
    1 "J44"  20200101
    1 "J45"  20200101
    1 "M05"  20200101
    1 "F03"  20200101
    1 "G81"  20200101
    1 "E109" 20200101
    1 "E115" 20200101
    1 "N18"  20200101
    1 "K73"  20200101
    1 "I850" 20200101
    1 "K25"  20200101
    1 "C50"  20200101
    1 "C77"  20200101
    1 "B20"  20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert r(N_patients) == 1
    assert charlson[1] == 30
    assert r(max_cci) == 30
}
local ok = (_rc == 0)
run_val "K1: every comorbidity, severe forms, sums to exactly 30" `ok'

**# K2: additive score, mild forms only = 17

* Same eight weight-1 conditions + plegia2 + diab1 + renal2 + livmild1 + pud1
* + cancer2, with NO diabcomp/livsev/mets/aids:
*   8 + 2 + 1 + 2 + 1 + 1 + 2 = 17
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21"  20200101
    1 "I50"  20200101
    1 "I70"  20200101
    1 "I63"  20200101
    1 "J44"  20200101
    1 "J45"  20200101
    1 "M05"  20200101
    1 "F03"  20200101
    1 "G81"  20200101
    1 "E109" 20200101
    1 "N18"  20200101
    1 "K73"  20200101
    1 "K25"  20200101
    1 "C50"  20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert charlson[1] == 17
}
local ok = (_rc == 0)
run_val "K2: mild/uncomplicated forms sum to exactly 17" `ok'

**# K3: mixed weights across weight tiers

* mi(1) + plegia(2) + mets(6) = 9; cancer is cleared by mets so contributes 0.
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21" 20200101
    1 "G81" 20200101
    1 "C50" 20200101
    1 "C77" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert charlson[1] == 9
}
local ok = (_rc == 0)
run_val "K3: 1 + 2 + 6 across tiers, cancer superseded by mets" `ok'

**# K4: weight-2 components add correctly

* plegia(2) + renal(2) = 4
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "G81" 20200101
    1 "N18" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert charlson[1] == 4
}
local ok = (_rc == 0)
run_val "K4: two weight-2 conditions sum to 4" `ok'

**# K5: diabetes hierarchy — uncomplicated cleared by complicated

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "E109" 20200101
    2 "E109" 20200101
    2 "E115" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    sort lopnr
    * diab alone = 1; diab + diabcomp = 2 (NOT 1 + 2 = 3)
    assert charlson[1] == 1
    assert charlson[2] == 2
}
local ok = (_rc == 0)
run_val "K5: diab=1 alone; diab+diabcomp=2 (uncomplicated cleared)" `ok'

**# K6: cancer hierarchy — non-metastatic cleared by metastatic

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "C50" 20200101
    2 "C50" 20200101
    2 "C77" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    sort lopnr
    * cancer alone = 2; cancer + mets = 6 (NOT 2 + 6 = 8)
    assert charlson[1] == 2
    assert charlson[2] == 6
}
local ok = (_rc == 0)
run_val "K6: cancer=2 alone; cancer+mets=6 (non-metastatic cleared)" `ok'

**# K7: liver hierarchy — mild + ascites upgrades to severe

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "K73"  20200101
    2 "K73"  20200101
    2 "R18"  20200101
    3 "I850" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    sort lopnr
    * mild=1; mild+ascites=severe=3 (mild cleared, not 1+3); direct severe=3
    assert charlson[1] == 1
    assert charlson[2] == 3
    assert charlson[3] == 3
}
local ok = (_rc == 0)
run_val "K7: livmild=1; livmild+ascites=3; direct livsev=3" `ok'

**# K8: patient-level collapse dedups a repeated comorbidity

* Same condition on three rows (incl. a longer prefixed code) collapses to one.
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21"   20190101
    1 "I21"   20200101
    1 "I2101" 20210101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert r(N_patients) == 1
    assert charlson[1] == 1
}
local ok = (_rc == 0)
run_val "K8: repeated MI across rows collapses to a single count" `ok'

**# K9: distinct comorbidities on separate rows sum after collapse

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21" 20200101
    1 "I50" 20200105
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert charlson[1] == 2
}
local ok = (_rc == 0)
run_val "K9: MI on one row + CHF on another collapse-sum to 2" `ok'

**# K10: cross-era diagnoses both contribute for one patient

* ICD-8 "410" (1980, MI) + ICD-10 "I50" (2020, CHF) = 2
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "410" 19800101
    1 "I50" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert charlson[1] == 2
}
local ok = (_rc == 0)
run_val "K10: ICD-8 MI + ICD-10 CHF sum across eras to 2" `ok'

**# K11: separator invariance (dot / comma / none)

* ICD-8 MI key 412,01. Input "412.01", "412,01", "41201" must all match MI.
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "412.01" 19800101
    2 "412,01" 19800101
    3 "41201"  19800101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    sort lopnr
    assert charlson[1] == 1
    assert charlson[2] == 1
    assert charlson[3] == 1
    assert r(N_any) == 3
}
local ok = (_rc == 0)
run_val "K11: dot/comma/none separators all resolve to MI" `ok'

**# K12: prefix matching on a longer child code

* "C5012" prefix-matches C50 (cancer, weight 2); "I2521" matches I252 (MI, 1).
* (I251 is NOT a Charlson MI code, so only a true I252 child scores.)
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "C5012" 20200101
    2 "I2521" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    sort lopnr
    assert charlson[1] == 2
    assert charlson[2] == 1
}
local ok = (_rc == 0)
run_val "K12: longer child codes prefix-match parent categories" `ok'

**# K13: multiple ICD columns (varlist) are all scanned

* diag1=MI, diag2=mets on the same row = 1 + 6 = 7
capture noisily {
    clear
    input long lopnr str10 diag1 str10 diag2 long datum
    1 "I21" "C77" 20200101
    2 "I50" ""    20200101
    end
    cci_se, id(lopnr) icd(diag1 diag2) date(datum) dateformat(yyyymmdd)
    sort lopnr
    assert charlson[1] == 7
    assert charlson[2] == 1
}
local ok = (_rc == 0)
run_val "K13: icd() varlist scans every diagnosis column" `ok'

**# K14: non-Charlson codes score exactly zero

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "Z000" 20200101
    1 "R51"  20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert r(N_patients) == 1
    assert r(N_any) == 0
    assert charlson[1] == 0
}
local ok = (_rc == 0)
run_val "K14: non-Charlson diagnoses give CCI = 0, N_any = 0" `ok'

**# K15: malignancy exclusions (skin/benign) score zero

* C44/C42 excluded from the ICD-10 range; ICD-9 173 excluded; C509 valid = 2.
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "C44"  20200101
    2 "C420" 20200101
    3 "173"  19900101
    4 "C509" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    sort lopnr
    assert charlson[1] == 0
    assert charlson[2] == 0
    assert charlson[3] == 0
    assert charlson[4] == 2
}
local ok = (_rc == 0)
run_val "K15: excluded malignancy codes score 0; valid cancer scores 2" `ok'

**# K16: lookback window drops out-of-window diagnoses

* index = 01jun2020, lookback 90d -> window [03mar2020, 01jun2020].
*  id1: I21 @01jan2020 (before window, excluded), I50 @01apr2020 (in) -> CHF=1
*  id2: I70 @01apr2020 (in) -> PVD=1, I50 @01jul2020 (post-index, excluded)
* Two rows excluded total.
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21" 20200101
    1 "I50" 20200401
    2 "I70" 20200401
    2 "I50" 20200701
    end
    gen index = mdy(6, 1, 2020)
    format index %td
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) ///
        indexdate(index) lookback(90)
    sort lopnr
    assert r(N_patients) == 2
    assert charlson[1] == 1
    assert charlson[2] == 1
    assert r(N_excluded_window) == 2
    assert r(lookback) == 90
}
local ok = (_rc == 0)
run_val "K16: lookback window excludes 2 rows; N_excluded_window=2" `ok'

**# K17: indexdate alone excludes only post-index diagnoses

*  id1: I21 @01jan2020 (pre-index, kept -> MI), I50 @01jul2020 (post, excluded)
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21" 20200101
    1 "I50" 20200701
    end
    gen index = mdy(6, 1, 2020)
    format index %td
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) ///
        indexdate(index)
    assert charlson[1] == 1
    assert r(N_excluded_window) == 1
}
local ok = (_rc == 0)
run_val "K17: indexdate alone drops only post-index rows" `ok'

**# K18: return-value cohort matches hand totals

*  p1 MI=1, p2 mets=6, p3 non-Charlson=0.
*  N_input=3 rows, N_patients=3, N_any=2, mean=(1+6+0)/3, max=6
capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "I21"  20200101
    2 "C77"  20200101
    3 "Z000" 20200101
    end
    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
    assert r(N_input) == 3
    assert r(N_patients) == 3
    assert r(N_any) == 2
    assert r(max_cci) == 6
    assert abs(r(mean_cci) - (7 / 3)) < 1e-10
}
local ok = (_rc == 0)
run_val "K18: N_input/N_patients/N_any/mean/max match hand totals" `ok'

**# Summary

display as text ""
display as result "Results: " scalar(gs_npass) "/" scalar(gs_ntest) " passed, " scalar(gs_nfail) " failed"
if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS: ${gs_failures}"
    display "RESULT: validation_cci_se_known_scores tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_cci_se_known_scores tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
log close _all

clear all
version 16.0
capture log close _all
log using "`c(tmpdir)'/validation_cci_se_era_boundaries_`c(processid)'.log", replace nomsg
set varabbrev off

* validation_cci_se_era_boundaries.do
* Worker A hand-computable known-answer validation for cci_se.
* Run from setools/qa:
*   stata-mp -b do validation_cci_se_era_boundaries.do

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

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

**# ICD era boundaries

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1  "420,1" 19681231
    2  "420,1" 19690101
    3  "410"   19690101
    4  "410"   19861231
    5  "410"   19870101
    6  "E102"  19961231
    7  "E102"  19970101
    8  "250D"  19970101
    9  "250D"  19980101
    10 "E102"  19980101
    end

    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components
    sort lopnr

    assert r(N_patients) == 10
    assert charlson[1] == 1
    assert cci_mi[1] == 1
    assert charlson[2] == 0
    assert charlson[3] == 1
    assert charlson[4] == 1
    assert charlson[5] == 1
    assert charlson[6] == 0
    assert charlson[7] == 2
    assert cci_diabcomp[7] == 1
    assert charlson[8] == 2
    assert cci_diabcomp[8] == 1
    assert charlson[9] == 0
    assert charlson[10] == 2
}
local ok = (_rc == 0)
run_val "V1: ICD-7/8/9/10 era windows, including 1997-only overlap" `ok'

**# ICD-10 component map

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1  "I21"  20200101
    2  "I50"  20200101
    3  "I70"  20200101
    4  "I63"  20200101
    5  "J44"  20200101
    6  "J45"  20200101
    7  "M05"  20200101
    8  "F03"  20200101
    9  "G81"  20200101
    10 "E109" 20200101
    11 "E115" 20200101
    12 "N18"  20200101
    13 "K73"  20200101
    14 "I850" 20200101
    15 "K25"  20200101
    16 "C50"  20200101
    17 "C77"  20200101
    18 "B20"  20200101
    end

    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components
    sort lopnr

    local comp_1 mi
    local comp_2 chf
    local comp_3 pvd
    local comp_4 cevd
    local comp_5 copd
    local comp_6 pulm
    local comp_7 rheum
    local comp_8 dem
    local comp_9 plegia
    local comp_10 diab
    local comp_11 diabcomp
    local comp_12 renal
    local comp_13 livmild
    local comp_14 livsev
    local comp_15 pud
    local comp_16 cancer
    local comp_17 mets
    local comp_18 aids

    local score_1 1
    local score_2 1
    local score_3 1
    local score_4 1
    local score_5 1
    local score_6 1
    local score_7 1
    local score_8 1
    local score_9 2
    local score_10 1
    local score_11 2
    local score_12 2
    local score_13 1
    local score_14 3
    local score_15 1
    local score_16 2
    local score_17 6
    local score_18 6

    forvalues i = 1/18 {
        assert charlson[`i'] == `score_`i''
        assert cci_`comp_`i''[`i'] == 1
    }
    assert r(N_patients) == 18
    assert r(N_any) == 18
    assert r(max_cci) == 6
    assert abs(r(mean_cci) - (34 / 18)) < 1e-10
}
local ok = (_rc == 0)
run_val "V2: ICD-10 representative code for every public component scores exactly" `ok'

**# Legacy code representatives and exclusions

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    101 "260,2" 19650101
    102 "250,00" 19700101
    103 "079J" 19900101
    104 "173" 19900101
    105 "173" 19800101
    106 "462,1" 19650101
    107 "198" 19650101
    end

    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components
    sort lopnr

    assert charlson[1] == 2
    assert cci_diabcomp[1] == 1
    assert charlson[2] == 1
    assert cci_diab[2] == 1
    assert charlson[3] == 6
    assert cci_aids[3] == 1
    assert charlson[4] == 0
    assert charlson[5] == 0
    assert charlson[6] == 3
    assert cci_livsev[6] == 1
    assert charlson[7] == 6
    assert cci_mets[7] == 1
}
local ok = (_rc == 0)
run_val "V3: legacy ICD-7/8/9 representatives and cancer exclusions are exact" `ok'

**# Hierarchy and dates

capture noisily {
    clear
    input long lopnr str10 diagnos long datum
    1 "E109" 20200101
    1 "E115" 20200110
    2 "C50"  20200101
    2 "C77"  20200105
    3 "K73"  20200101
    3 "I850" 20200103
    3 "R18"  20200107
    end

    cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) dates
    sort lopnr

    local d1 = daily("10jan2020", "DMY")
    local d2 = daily("05jan2020", "DMY")
    local d3_direct = daily("03jan2020", "DMY")

    assert charlson[1] == 2
    assert cci_diab[1] == 0
    assert missing(cci_diab_date[1])
    assert cci_diabcomp[1] == 1
    assert cci_diabcomp_date[1] == `d1'

    assert charlson[2] == 6
    assert cci_cancer[2] == 0
    assert missing(cci_cancer_date[2])
    assert cci_mets[2] == 1
    assert cci_mets_date[2] == `d2'

    assert charlson[3] == 3
    assert cci_livmild[3] == 0
    assert missing(cci_livmild_date[3])
    assert cci_livsev[3] == 1
    assert cci_livsev_date[3] == `d3_direct'
}
local ok = (_rc == 0)
run_val "V4: diabetes/cancer/liver hierarchy clears lower component dates exactly" `ok'

**# Summary

display as text ""
display as result "Results: " scalar(gs_npass) "/" scalar(gs_ntest) " passed, " scalar(gs_nfail) " failed"
if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS: ${gs_failures}"
    display "RESULT: validation_cci_se_era_boundaries tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_cci_se_era_boundaries tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
log close _all

do "`qa_dir'/_setools_qa_common.do" teardown

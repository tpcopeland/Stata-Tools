clear all
version 16.0
capture log close _all
log using "`c(tmpdir)'/test_cci_se_adversarial_`c(processid)'.log", replace nomsg
set varabbrev off

* test_cci_se_adversarial.do
* Worker A adversarial functional QA for cci_se.
* Run from setools/qa:
*   stata-mp -b do test_cci_se_adversarial.do

**# Bootstrap

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_test
program define run_test
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

**# Installation surface

capture noisily {
    which cci_se
}
local ok = (_rc == 0)
run_test "C1: cci_se is installed and discoverable" `ok'

**# Syntax, normalization, duplicates, and aggregation

capture noisily {
    clear
    input str4 lopnr str30 diag_main str20 diag_aux double datum
    "A" " i25.2  I252 " "j44.9" 21915
    "A" "I21"          ""      21916
    "B" ""             " Z99 "  21915
    end
    format datum %td

    cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) components
    sort lopnr

    assert r(N_input) == 3
    assert r(N_patients) == 2
    assert r(N_any) == 1
    assert _N == 2
    assert lopnr[1] == "A"
    assert charlson[1] == 2
    assert cci_mi[1] == 1
    assert cci_copd[1] == 1
    assert cci_chf[1] == 0
    assert lopnr[2] == "B"
    assert charlson[2] == 0
}
local ok = (_rc == 0)
run_test "C2: dot/no-dot/case normalization, duplicate codes, and by-id max aggregation" `ok'

capture noisily {
    clear
    input str4 lopnr str10 diagnos str12 datum byte include
    "1" "I21" "2020-01-01" 1
    "1" "I50" "bad"        1
    ""  "B20" "2020-01-02" 1
    "2" "B20" "2020/01/03" 1
    "3" "I21" ""           1
    "4" "I21" "2020-01-04" 0
    end

    cci_se if include == 1, id(lopnr) icd(diagnos) date(datum) ///
        dateformat(yyyymmdd)
    sort lopnr

    assert r(N_input) == 2
    assert r(N_patients) == 2
    assert r(N_any) == 2
    assert abs(r(mean_cci) - 3.5) < 1e-10
    assert r(max_cci) == 6
    assert lopnr[1] == "1"
    assert charlson[1] == 1
    assert lopnr[2] == "2"
    assert charlson[2] == 6
}
local ok = (_rc == 0)
run_test "C3: if qualifier, missing IDs/dates, and malformed string dates handled exactly" `ok'

capture noisily {
    clear
    input long lopnr str10 diagnos double datum
    1 "I21" 21915
    2 "B20" 21916
    end
    format datum %td

    cci_se, id(lopnr) icd(diagnos) date(datum) generate(score_only)
    capture confirm variable cci_mi
    assert _rc != 0
    confirm variable score_only
    assert score_only[1] == 1
    assert score_only[2] == 6
    assert r(N_input) == 2
    assert r(N_patients) == 2
    assert r(N_any) == 2
    assert abs(r(mean_cci) - 3.5) < 1e-10
    assert r(max_cci) == 6
}
local ok = (_rc == 0)
run_test "C4: score-only path has exact returns and no component leakage" `ok'

capture noisily {
    clear
    input long lopnr str10 diagnos double datum
    1 "I21" 21915
    end
    format datum %td

    cci_se, id(lopnr) icd(diagnos) date(datum) dates prefix(ch_) generate(score)
    confirm variable ch_mi
    confirm variable ch_mi_date
    assert score == 1
    assert ch_mi == 1
    assert ch_mi_date == 21915
    capture confirm variable cci_mi
    assert _rc != 0
}
local ok = (_rc == 0)
run_test "C5: dates implies components and honors custom prefix without default-name leakage" `ok'

**# Expected errors and state restoration

capture noisily {
    clear
    input long lopnr long diagnos double datum
    1 21 21915
    2 50 21916
    end
    format datum %td

    set varabbrev on
    capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
    assert _N == 2
    assert diagnos[1] == 21
}
local ok = (_rc == 0)
run_test "C6: numeric icd() rejected, varabbrev restored, data unchanged" `ok'
set varabbrev off

capture noisily {
    clear
    input long lopnr str10 diagnos str10 datum
    1 "I21" "2020-01-01"
    end

    set varabbrev on
    capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(stata)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    assert _N == 1
    assert datum[1] == "2020-01-01"
}
local ok = (_rc == 0)
run_test "C7: invalid dateformat/type combination restores varabbrev and data" `ok'
set varabbrev off

capture noisily {
    clear
    input long lopnr str10 diagnos double datum byte _cci_1
    1 "I21" 21915 7
    end
    format datum %td

    set varabbrev on
    capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
    assert _rc == 110
    assert "`c(varabbrev)'" == "on"
    assert _N == 1
    assert _cci_1 == 7
    assert diagnos == "I21"
}
local ok = (_rc == 0)
run_test "C8: post-preserve _cci_* conflict restores original data and varabbrev" `ok'
set varabbrev off

capture noisily {
    clear
    input long lopnr str10 diagnos double datum
    1 "I21" 21915
    end
    format datum %td

    capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) ///
        generate(cci_mi) components
    assert _rc == 198
}
local ok = (_rc == 0)
run_test "C9: generate() cannot collide with component prefix" `ok'

**# Summary

display as text ""
display as result "Results: " scalar(gs_npass) "/" scalar(gs_ntest) " passed, " scalar(gs_nfail) " failed"
if scalar(gs_nfail) > 0 {
    display as error "FAILED TESTS: ${gs_failures}"
    display "RESULT: test_cci_se_adversarial tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_cci_se_adversarial tests=" scalar(gs_ntest) " pass=" scalar(gs_npass) " fail=" scalar(gs_nfail)
log close _all

do "`qa_dir'/_setools_qa_common.do" teardown

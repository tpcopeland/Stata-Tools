* test_cci_se.do - Functional tests for cci_se command
* Part of setools package testing

clear all
set more off

cap program drop cci_se
run "/home/tpcopeland/Stata-Tools/setools/cci_se.ado"

local n_tests = 0
local n_passed = 0
local n_failed = 0

capture program drop run_test
program define run_test
    args test_name result
    c_local n_tests = `n_tests' + 1
    if `result' {
        display as result "[PASS] `test_name'"
        c_local n_passed = `n_passed' + 1
    }
    else {
        display as error "[FAIL] `test_name'"
        c_local n_failed = `n_failed' + 1
    }
end

display as text ""
display as text _dup(60) "="
display as text "Testing cci_se command"
display as text _dup(60) "="
display as text ""

* =============================================================
* TEST 1: Basic ICD-10 - single patient with MI + COPD
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
1 "J44" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t1a = (charlson == 2)
run_test "T1a: MI + COPD = CCI 2" `t1a'

local t1b = (_N == 1)
run_test "T1b: Collapsed to 1 patient" `t1b'

* =============================================================
* TEST 2: ICD-10 with dots stripped correctly
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I25.2" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t2 = (charlson == 1)
run_test "T2: ICD with dot (I25.2) matches MI" `t2'

* =============================================================
* TEST 3: Case insensitivity
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "i21" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t3 = (charlson == 1)
run_test "T3: Lowercase i21 matches MI" `t3'

* =============================================================
* TEST 4: Components option generates all 18 variables
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum) components

local t4a = (cci_mi == 1)
run_test "T4a: cci_mi = 1 for MI" `t4a'

local t4b = (cci_chf == 0)
run_test "T4b: cci_chf = 0 for non-CHF" `t4b'

local n_comps = 0
foreach v of varlist cci_* {
    local ++n_comps
}
local t4c = (`n_comps' == 18)
run_test "T4c: 18 component variables created" `t4c'

* =============================================================
* TEST 5: Diabetes hierarchy
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "E100" 21915
1 "E102" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum) components

local t5a = (cci_diab == 0)
run_test "T5a: Diabetes uncomplicated cleared" `t5a'

local t5b = (cci_diabcomp == 1)
run_test "T5b: Diabetes complicated = 1" `t5b'

local t5c = (charlson == 2)
run_test "T5c: CCI = 2 (diabcomp weight)" `t5c'

* =============================================================
* TEST 6: Cancer hierarchy
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "C50" 21915
1 "C77" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum) components

local t6a = (cci_cancer == 0)
run_test "T6a: Non-metastatic cleared" `t6a'

local t6b = (cci_mets == 1)
run_test "T6b: Metastatic = 1" `t6b'

local t6c = (charlson == 6)
run_test "T6c: CCI = 6 (mets weight)" `t6c'

* =============================================================
* TEST 7: Liver hierarchy
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "K73" 21915
1 "R18" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum) components

local t7a = (cci_livmild == 0)
run_test "T7a: Mild liver cleared (upgraded)" `t7a'

local t7b = (cci_livsev == 1)
run_test "T7b: Severe liver = 1" `t7b'

local t7c = (charlson == 3)
run_test "T7c: CCI = 3 (severe liver weight)" `t7c'

* =============================================================
* TEST 8: YYYYMMDD numeric date format
* =============================================================
clear
input long lopnr str10 diagnos long datum
1 "I21" 20200115
end

cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)

local t8 = (charlson == 1)
run_test "T8: YYYYMMDD numeric date format works" `t8'

* =============================================================
* TEST 9: ICD-9 Swedish codes
* =============================================================
clear
input long lopnr str10 diagnos long datum
1 "250D" 19950601
end

cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)

local t9 = (charlson == 2)
run_test "T9: ICD-9 Swedish code 250D (diabcomp)" `t9'

* =============================================================
* TEST 10: ICD-7 codes with commas
* =============================================================
clear
input long lopnr str10 diagnos long datum
1 "420,1" 19650315
end

cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)

local t10 = (charlson == 1)
run_test "T10: ICD-7 code 420,1 (MI)" `t10'

* =============================================================
* TEST 11: Multiple patients
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
2 "I50" 21915
2 "J44" 21915
3 "G35" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t11a = (_N == 3)
run_test "T11a: 3 patients in output" `t11a'

local t11b = (charlson[1] == 1)
run_test "T11b: Patient 1 CCI = 1 (MI)" `t11b'

local t11c = (charlson[2] == 2)
run_test "T11c: Patient 2 CCI = 2 (CHF + COPD)" `t11c'

local t11d = (charlson[3] == 0)
run_test "T11d: Patient 3 CCI = 0 (G35 not in CCI)" `t11d'

* =============================================================
* TEST 12: No matching codes gets CCI = 0
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "Z99" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t12 = (charlson == 0)
run_test "T12: Non-CCI code gets CCI = 0" `t12'

* =============================================================
* TEST 13: Custom generate and prefix names
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum) generate(my_cci) components prefix(ch_)

capture confirm variable my_cci
local t13a = (_rc == 0)
run_test "T13a: Custom generate name works" `t13a'

capture confirm variable ch_mi
local t13b = (_rc == 0)
run_test "T13b: Custom prefix works" `t13b'

* =============================================================
* TEST 14: if qualifier restricts input
* =============================================================
clear
input long lopnr str10 diagnos double datum byte include
1 "I21" 21915 1
1 "C50" 21915 0
end
format datum %td

cci_se if include == 1, id(lopnr) icd(diagnos) date(datum)

local t14 = (charlson == 1)
run_test "T14: if qualifier restricts to MI only" `t14'

* =============================================================
* TEST 15: Stored results
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
2 "I50" 21915
3 "Z99" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t15a = (r(N_input) == 3)
run_test "T15a: r(N_input) = 3" `t15a'

local t15b = (r(N_patients) == 3)
run_test "T15b: r(N_patients) = 3" `t15b'

local t15c = (r(N_any) == 2)
run_test "T15c: r(N_any) = 2" `t15c'

* =============================================================
* TEST 16: Hemiplegia weight = 2
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "G81" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t16 = (charlson == 2)
run_test "T16: Hemiplegia weight = 2" `t16'

* =============================================================
* TEST 17: AIDS weight = 6
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "B20" 21915
end
format datum %td

cci_se, id(lopnr) icd(diagnos) date(datum)

local t17 = (charlson == 6)
run_test "T17: AIDS weight = 6" `t17'

* =============================================================
* TEST 18: Noisily option
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td

capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) noisily

local t18 = (_rc == 0)
run_test "T18: noisily option runs without error" `t18'

* =============================================================
* TEST 19: Error on no observations (all missing dates)
* =============================================================
clear
input long lopnr str10 diagnos double datum
1 "I21" .
end

capture cci_se, id(lopnr) icd(diagnos) date(datum)

local t19 = (_rc == 2000)
run_test "T19: Error 2000 on all-missing dates" `t19'

* =============================================================
* TEST 20: String date - YYYYMMDD format
* =============================================================
clear
input long lopnr str10 diagnos str10 datum
1 "I21" "20200115"
end

cci_se, id(lopnr) icd(diagnos) date(datum)

local t20 = (charlson == 1)
run_test "T20: String YYYYMMDD date works" `t20'

* =============================================================
* TEST 21: String date - YYYY-MM-DD format (with dateformat)
* =============================================================
clear
input long lopnr str10 diagnos str12 datum
1 "I50" "2020-03-15"
end

cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(ymd)

local t21 = (charlson == 1)
run_test "T21: String YYYY-MM-DD date with dateformat(ymd)" `t21'

* =============================================================
* TEST 22: String date - YYYYMMDD with dashes auto-stripped
* =============================================================
clear
input long lopnr str12 diagnos str12 datum
1 "I21" "2020-01-15"
end

cci_se, id(lopnr) icd(diagnos) date(datum)

local t22 = (charlson == 1)
run_test "T22: String date with dashes auto-stripped" `t22'

* =============================================================
* TEST 23: Multi-ICD-version spanning data
* =============================================================
clear
input long lopnr str10 diagnos long datum
1 "420,1" 19650101
1 "I21" 20200101
2 "290" 19800601
end

cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components

local t23a = (charlson[1] == 1)
run_test "T23a: Patient 1 MI across ICD-7 and ICD-10" `t23a'

local t23b = (cci_dem[2] == 1)
run_test "T23b: Patient 2 dementia from ICD-8 code" `t23b'

* =============================================================
* SUMMARY
* =============================================================
display as text ""
display as text _dup(60) "="
display as text "Test Results: `n_passed'/`n_tests' passed, `n_failed' failed"
display as text _dup(60) "="

if `n_failed' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

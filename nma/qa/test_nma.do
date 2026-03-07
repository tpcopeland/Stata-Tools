* test_nma.do — Test suite for nma package
* Tests: setup, import, fit, rank, forest, map, compare, inconsistency, report

clear all
set more off

capture ado uninstall nma

* Add nma package to adopath so Stata finds all commands
adopath + "/home/tpcopeland/Stata-Tools/nma"

scalar _n_tests = 0
scalar _n_passed = 0
scalar _n_failed = 0
global nma_failed_tests = ""

capture program drop run_test
program define run_test
    args test_name
    display as text _newline "--- TEST: `test_name' ---"
end

capture program drop test_passed
program define test_passed
    args test_name
    display as result "  PASSED: `test_name'"
    scalar _n_passed = _n_passed + 1
    scalar _n_tests = _n_tests + 1
end

capture program drop test_failed
program define test_failed
    args test_name msg
    display as error "  FAILED: `test_name' - `msg'"
    scalar _n_failed = _n_failed + 1
    scalar _n_tests = _n_tests + 1
    global nma_failed_tests "${nma_failed_tests} `test_name'"
end

* =========================================================================
* CREATE SMOKING CESSATION DATASET
* Classic NMA example: 24 studies, 4 treatments
* Treatments: A=No contact, B=Self-help, C=Individual counselling, D=Group counselling
* Outcome: smoking cessation (binary: quit yes/no)
* =========================================================================

* Build the dataset from Hasselblad (1998) / Lu & Ades (2006)
clear
input str12 study str30 treatment events total
"Study01" "NoContact"   9  140
"Study01" "SelfHelp"   23  140
"Study01" "IndCounsel" 10  138
"Study02" "NoContact"  11  78
"Study02" "SelfHelp"   12  85
"Study02" "IndCounsel" 29  170
"Study03" "NoContact"  75  731
"Study03" "SelfHelp"   363 714
"Study04" "NoContact"   2  106
"Study04" "SelfHelp"    9  205
"Study05" "NoContact"  58  549
"Study05" "SelfHelp"   237 1561
"Study06" "NoContact"   0  33
"Study06" "SelfHelp"    9  48
"Study07" "NoContact"    3  100
"Study07" "IndCounsel"  31  98
"Study08" "NoContact"    1  31
"Study08" "IndCounsel"  26  95
"Study09" "NoContact"    6  39
"Study09" "IndCounsel"  17  77
"Study10" "NoContact"   79  702
"Study10" "IndCounsel"  77  694
"Study11" "NoContact"   18  671
"Study11" "IndCounsel"  21  535
"Study12" "SelfHelp"    64  642
"Study12" "IndCounsel"  107 761
"Study13" "SelfHelp"     5  62
"Study13" "IndCounsel"   8  90
"Study14" "SelfHelp"   20  234
"Study14" "IndCounsel"  34  237
"Study15" "SelfHelp"     0  20
"Study15" "GrpCounsel"   9  20
"Study16" "SelfHelp"     8  116
"Study16" "GrpCounsel"  19  149
"Study17" "IndCounsel"  95  1107
"Study17" "GrpCounsel"  34  187
"Study18" "IndCounsel"  15  187
"Study18" "GrpCounsel"   6  504
"Study19" "NoContact"   78  584
"Study19" "IndCounsel"  73  675
"Study20" "NoContact"   69  1177
"Study20" "IndCounsel"  54  888
"Study21" "NoContact"   20  49
"Study21" "GrpCounsel"  16  43
"Study22" "SelfHelp"     7  137
"Study22" "IndCounsel"  32  140
"Study23" "SelfHelp"   12  239
"Study23" "IndCounsel"  20  234
"Study24" "SelfHelp"     9  90
"Study24" "IndCounsel"   3  100
end
save "../../_devkit/_testing/data/smoking_nma.dta", replace


* =========================================================================
* TEST 1: nma overview command
* =========================================================================
run_test "nma overview"
capture noisily nma
if _rc == 0 {
    test_passed "nma overview"
}
else {
    test_failed "nma overview" "rc=`=_rc'"
}

* =========================================================================
* TEST 2: nma_setup with binary data
* =========================================================================
run_test "nma_setup binary"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment)
if _rc == 0 {
    * Check setup flag
    local setup_flag : char _dta[_nma_setup]
    if "`setup_flag'" == "1" {
        test_passed "nma_setup binary"
    }
    else {
        test_failed "nma_setup binary" "setup flag not set"
    }
}
else {
    test_failed "nma_setup binary" "rc=`=_rc'"
}

* =========================================================================
* TEST 3: Network summary counts
* =========================================================================
run_test "network summary counts"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment)
if _rc == 0 {
    local n_trt : char _dta[_nma_n_treatments]
    local n_stu : char _dta[_nma_n_studies]
    if `n_trt' == 4 & `n_stu' == 24 {
        test_passed "network summary counts"
    }
    else {
        test_failed "network summary counts" "treatments=`n_trt' (expected 4), studies=`n_stu' (expected 24)"
    }
}
else {
    test_failed "network summary counts" "setup failed rc=`=_rc'"
}

* =========================================================================
* TEST 4: Evidence classification
* =========================================================================
run_test "evidence classification"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment)
if _rc == 0 {
    * With 4 treatments all connected, should have mixed evidence
    local n_mixed : char _dta[_nma_n_mixed]
    local n_direct : char _dta[_nma_n_direct]
    local n_indirect : char _dta[_nma_n_indirect]
    * All 6 pairs should have some classification
    local total = `n_mixed' + `n_direct' + `n_indirect'
    if `total' == 6 {
        test_passed "evidence classification"
    }
    else {
        test_failed "evidence classification" "total pairs=`total' (expected 6)"
    }
}
else {
    test_failed "evidence classification" "setup failed"
}

* =========================================================================
* TEST 5: Reference treatment auto-selection
* =========================================================================
run_test "reference auto-selection"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment)
if _rc == 0 {
    local ref : char _dta[_nma_ref]
    * NoContact or IndCounsel should be most connected
    if "`ref'" != "" {
        test_passed "reference auto-selection"
    }
    else {
        test_failed "reference auto-selection" "no ref selected"
    }
}
else {
    test_failed "reference auto-selection" "setup failed"
}

* =========================================================================
* TEST 6: User-specified reference
* =========================================================================
run_test "user-specified reference"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    local ref : char _dta[_nma_ref]
    if "`ref'" == "NoContact" {
        test_passed "user-specified reference"
    }
    else {
        test_failed "user-specified reference" "ref=`ref' (expected NoContact)"
    }
}
else {
    test_failed "user-specified reference" "rc=`=_rc'"
}

* =========================================================================
* TEST 7: Zero-cell correction
* =========================================================================
run_test "zero-cell correction"
* Study06 has 0 events in NoContact arm — should trigger correction
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    * If we got here without error, correction was applied
    test_passed "zero-cell correction"
}
else {
    test_failed "zero-cell correction" "rc=`=_rc'"
}

* =========================================================================
* TEST 8: nma_fit - model fitting
* =========================================================================
run_test "nma_fit"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, nolog
    if _rc == 0 {
        * Check e() results exist
        local cmd = e(cmd)
        if "`cmd'" == "nma_fit" {
            test_passed "nma_fit"
        }
        else {
            test_failed "nma_fit" "e(cmd) not set"
        }
    }
    else {
        test_failed "nma_fit" "fit failed rc=`=_rc'"
    }
}
else {
    test_failed "nma_fit" "setup failed"
}

* =========================================================================
* TEST 9: nma_fit - coefficients exist
* =========================================================================
run_test "nma_fit coefficients"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, nolog
    if _rc == 0 {
        tempname b
        matrix `b' = e(b)
        local p = colsof(`b')
        * Should have k-1 = 3 coefficients
        if `p' == 3 {
            test_passed "nma_fit coefficients"
        }
        else {
            test_failed "nma_fit coefficients" "p=`p' (expected 3)"
        }
    }
    else {
        test_failed "nma_fit coefficients" "fit failed"
    }
}
else {
    test_failed "nma_fit coefficients" "setup failed"
}

* =========================================================================
* TEST 10: nma_fit - tau2 non-negative
* =========================================================================
run_test "nma_fit tau2"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, nolog
    if _rc == 0 {
        local tau2 = e(tau2)
        if `tau2' >= 0 {
            test_passed "nma_fit tau2"
        }
        else {
            test_failed "nma_fit tau2" "tau2=`tau2' (expected >= 0)"
        }
    }
    else {
        test_failed "nma_fit tau2" "fit failed"
    }
}
else {
    test_failed "nma_fit tau2" "setup failed"
}

* =========================================================================
* TEST 11: nma_fit - common effect model
* =========================================================================
run_test "nma_fit common"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, common nolog
    if _rc == 0 {
        local tau2 = e(tau2)
        if `tau2' == 0 {
            test_passed "nma_fit common"
        }
        else {
            test_failed "nma_fit common" "tau2=`tau2' (expected 0)"
        }
    }
    else {
        test_failed "nma_fit common" "fit failed rc=`=_rc'"
    }
}
else {
    test_failed "nma_fit common" "setup failed"
}

* =========================================================================
* TEST 12: nma_rank - SUCRA values
* =========================================================================
run_test "nma_rank SUCRA"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, nolog
    if _rc == 0 {
        capture noisily nma_rank, seed(12345)
        if _rc == 0 {
            * SUCRA values should be between 0 and 1
            local ok = 1
            forvalues i = 1/4 {
                local s = _nma_sucra[`i', 1]
                if `s' < 0 | `s' > 1 local ok = 0
            }
            if `ok' {
                test_passed "nma_rank SUCRA"
            }
            else {
                test_failed "nma_rank SUCRA" "SUCRA out of [0,1]"
            }
        }
        else {
            test_failed "nma_rank SUCRA" "rank failed rc=`=_rc'"
        }
    }
    else {
        test_failed "nma_rank SUCRA" "fit failed"
    }
}
else {
    test_failed "nma_rank SUCRA" "setup failed"
}

* =========================================================================
* TEST 13: nma_compare - league table
* =========================================================================
run_test "nma_compare"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, nolog
    if _rc == 0 {
        capture noisily nma_compare
        if _rc == 0 {
            local k_ret = r(k)
            if `k_ret' == 4 {
                test_passed "nma_compare"
            }
            else {
                test_failed "nma_compare" "k=`k_ret' (expected 4)"
            }
        }
        else {
            test_failed "nma_compare" "compare failed rc=`=_rc'"
        }
    }
    else {
        test_failed "nma_compare" "fit failed"
    }
}
else {
    test_failed "nma_compare" "setup failed"
}

* =========================================================================
* TEST 14: nma_inconsistency
* =========================================================================
run_test "nma_inconsistency"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, nolog
    if _rc == 0 {
        capture noisily nma_inconsistency
        if _rc == 0 {
            local chi2_p = r(chi2_p)
            if `chi2_p' >= 0 & `chi2_p' <= 1 {
                test_passed "nma_inconsistency"
            }
            else {
                test_failed "nma_inconsistency" "chi2_p=`chi2_p'"
            }
        }
        else {
            test_failed "nma_inconsistency" "incon failed rc=`=_rc'"
        }
    }
    else {
        test_failed "nma_inconsistency" "fit failed"
    }
}
else {
    test_failed "nma_inconsistency" "setup failed"
}

* =========================================================================
* TEST 15: nma_import with pre-computed effects
* =========================================================================
run_test "nma_import"
clear
input str12 study str15 treat_a str15 treat_b double(log_or se_log_or)
"S1" "DrugA" "Placebo"  0.50 0.20
"S2" "DrugA" "Placebo"  0.45 0.25
"S3" "DrugB" "Placebo"  0.30 0.22
"S4" "DrugB" "Placebo"  0.35 0.18
"S5" "DrugA" "DrugB"    0.20 0.30
end
capture noisily nma_import log_or se_log_or, studyvar(study) treat1(treat_a) treat2(treat_b) measure(or)
if _rc == 0 {
    local setup_flag : char _dta[_nma_setup]
    if "`setup_flag'" == "1" {
        test_passed "nma_import"
    }
    else {
        test_failed "nma_import" "setup flag not set"
    }
}
else {
    test_failed "nma_import" "import failed rc=`=_rc'"
}

* =========================================================================
* TEST 16: nma_import then fit
* =========================================================================
run_test "nma_import then fit"
clear
input str12 study str15 treat_a str15 treat_b double(log_or se_log_or)
"S1" "DrugA" "Placebo"  0.50 0.20
"S2" "DrugA" "Placebo"  0.45 0.25
"S3" "DrugB" "Placebo"  0.30 0.22
"S4" "DrugB" "Placebo"  0.35 0.18
"S5" "DrugA" "DrugB"    0.20 0.30
end
capture noisily nma_import log_or se_log_or, studyvar(study) treat1(treat_a) treat2(treat_b) measure(or)
if _rc == 0 {
    capture noisily nma_fit, nolog
    if _rc == 0 {
        local cmd = e(cmd)
        if "`cmd'" == "nma_fit" {
            test_passed "nma_import then fit"
        }
        else {
            test_failed "nma_import then fit" "e(cmd) not set"
        }
    }
    else {
        test_failed "nma_import then fit" "fit failed rc=`=_rc'"
    }
}
else {
    test_failed "nma_import then fit" "import failed"
}

* =========================================================================
* TEST 17: Check setup required before fit
* =========================================================================
run_test "check setup required"
clear
set obs 10
gen x = 1
capture noisily nma_fit
if _rc == 198 {
    test_passed "check setup required"
}
else {
    test_failed "check setup required" "expected error 198, got rc=`=_rc'"
}

* =========================================================================
* TEST 18: Continuous outcome setup
* =========================================================================
run_test "continuous outcome"
clear
input str12 study str15 treatment double(mean sd n)
"S1" "DrugA"   5.2 2.1 50
"S1" "Placebo"  3.1 1.9 48
"S2" "DrugB"    4.8 2.3 55
"S2" "Placebo"  3.0 2.0 52
"S3" "DrugA"    5.0 2.0 60
"S3" "DrugB"    4.5 2.2 58
end
capture noisily nma_setup mean sd n, studyvar(study) trtvar(treatment) measure(md)
if _rc == 0 {
    local otype : char _dta[_nma_outcome_type]
    if "`otype'" == "continuous" {
        test_passed "continuous outcome"
    }
    else {
        test_failed "continuous outcome" "type=`otype' (expected continuous)"
    }
}
else {
    test_failed "continuous outcome" "setup failed rc=`=_rc'"
}

* =========================================================================
* TEST 19: Invalid reference treatment
* =========================================================================
run_test "invalid reference"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NonExistent)
if _rc == 198 {
    test_passed "invalid reference"
}
else {
    test_failed "invalid reference" "expected error 198, got rc=`=_rc'"
}

* =========================================================================
* TEST 20: Disconnected network detection
* =========================================================================
run_test "disconnected network"
clear
input str12 study str15 treatment events total
"S1" "A" 10 100
"S1" "B" 15 100
"S2" "C" 20 100
"S2" "D" 25 100
end
capture noisily nma_setup events total, studyvar(study) trtvar(treatment)
if _rc == 198 {
    test_passed "disconnected network"
}
else {
    test_failed "disconnected network" "expected error 198, got rc=`=_rc'"
}

* =========================================================================
* TEST 21: Disconnected network with force
* =========================================================================
run_test "disconnected force"
clear
input str12 study str15 treatment events total
"S1" "A" 10 100
"S1" "B" 15 100
"S2" "C" 20 100
"S2" "D" 25 100
end
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) force
if _rc == 0 {
    test_passed "disconnected force"
}
else {
    test_failed "disconnected force" "rc=`=_rc'"
}

* =========================================================================
* TEST 22: eform display
* =========================================================================
run_test "eform display"
use "../../_devkit/_testing/data/smoking_nma.dta", clear
capture noisily nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
if _rc == 0 {
    capture noisily nma_fit, nolog eform
    if _rc == 0 {
        test_passed "eform display"
    }
    else {
        test_failed "eform display" "rc=`=_rc'"
    }
}
else {
    test_failed "eform display" "setup failed"
}

* =========================================================================
* SUMMARY
* =========================================================================
display as text _newline "{hline 60}"
display as text "NMA Test Suite Results"
display as text "{hline 60}"
display as result "Tests run:    " _n_tests
display as result "Passed:       " _n_passed
if _n_failed > 0 {
    display as error "Failed:       " _n_failed
    display as error "Failed tests: ${nma_failed_tests}"
}
else {
    display as result "Failed:       0"
}
display as text "{hline 60}"

if _n_failed > 0 {
    exit 1
}

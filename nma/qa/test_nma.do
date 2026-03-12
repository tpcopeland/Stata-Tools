* test_nma.do - Functional tests for nma package
* Tests: nma, nma_setup, nma_fit, nma_import, nma_rank, nma_compare,
*        nma_inconsistency, nma_forest, nma_map, nma_report
* Location: ~/Stata-Tools/nma/qa/
* Run: stata-mp -b do qa/test_nma.do
* Date: 2026-03-13

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

capture ado uninstall nma
adopath ++ "/home/tpcopeland/Stata-Tools/nma"

* Create smoking cessation dataset: Hasselblad (1998) / Lu & Ades (2006)
* 24 studies, 4 treatments
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
save "qa/data/smoking_nma.dta", replace


* ============================================================
* nma overview
* ============================================================

* Test 1: nma overview command runs
local ++test_count
capture noisily {
    nma
}
if _rc == 0 {
    display as result "  PASS: nma overview"
    local ++pass_count
}
else {
    display as error "  FAIL: nma overview (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_setup — basic functionality
* ============================================================

* Test 2: Binary setup sets _nma_setup flag
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment)
    local setup_flag : char _dta[_nma_setup]
    assert "`setup_flag'" == "1"
}
if _rc == 0 {
    display as result "  PASS: nma_setup binary — flag set"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_setup binary — flag set (error `=_rc')"
    local ++fail_count
}

* Test 3: Network counts — 4 treatments, 24 studies
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment)
    local n_trt : char _dta[_nma_n_treatments]
    local n_stu : char _dta[_nma_n_studies]
    assert `n_trt' == 4
    assert `n_stu' == 24
}
if _rc == 0 {
    display as result "  PASS: nma_setup network counts (4 trt, 24 studies)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_setup network counts (error `=_rc')"
    local ++fail_count
}

* Test 4: Evidence classification — 6 total pairs
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment)
    local n_mixed : char _dta[_nma_n_mixed]
    local n_direct : char _dta[_nma_n_direct]
    local n_indirect : char _dta[_nma_n_indirect]
    assert `n_mixed' + `n_direct' + `n_indirect' == 6
}
if _rc == 0 {
    display as result "  PASS: nma_setup evidence classification (6 pairs)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_setup evidence classification (error `=_rc')"
    local ++fail_count
}

* Test 5: Reference auto-selection returns non-empty
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment)
    local ref : char _dta[_nma_ref]
    assert "`ref'" != ""
}
if _rc == 0 {
    display as result "  PASS: nma_setup reference auto-selection"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_setup reference auto-selection (error `=_rc')"
    local ++fail_count
}

* Test 6: User-specified reference
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    local ref : char _dta[_nma_ref]
    assert "`ref'" == "NoContact"
}
if _rc == 0 {
    display as result "  PASS: nma_setup user-specified reference"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_setup user-specified reference (error `=_rc')"
    local ++fail_count
}

* Test 7: Zero-cell correction (Study06 has 0/33 in NoContact)
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
}
if _rc == 0 {
    display as result "  PASS: nma_setup zero-cell correction"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_setup zero-cell correction (error `=_rc')"
    local ++fail_count
}

* Test 8: Continuous outcome detected
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment double(mean sd n)
    "S1" "DrugA"   5.2 2.1 50
    "S1" "Placebo"  3.1 1.9 48
    "S2" "DrugB"    4.8 2.3 55
    "S2" "Placebo"  3.0 2.0 52
    "S3" "DrugA"    5.0 2.0 60
    "S3" "DrugB"    4.5 2.2 58
    end
    nma_setup mean sd n, studyvar(study) trtvar(treatment) measure(md)
    local otype : char _dta[_nma_outcome_type]
    assert "`otype'" == "continuous"
}
if _rc == 0 {
    display as result "  PASS: nma_setup continuous outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_setup continuous outcome (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_fit — model fitting
* ============================================================

* Test 9: Basic fit sets e(cmd)
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, nolog
    assert "`e(cmd)'" == "nma_fit"
}
if _rc == 0 {
    display as result "  PASS: nma_fit e(cmd) set"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_fit e(cmd) set (error `=_rc')"
    local ++fail_count
}

* Test 10: Coefficient count = k-1 = 3
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, nolog
    tempname b
    matrix `b' = e(b)
    assert colsof(`b') == 3
}
if _rc == 0 {
    display as result "  PASS: nma_fit coefficient count (3)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_fit coefficient count (error `=_rc')"
    local ++fail_count
}

* Test 11: tau2 non-negative
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, nolog
    assert e(tau2) >= 0
}
if _rc == 0 {
    display as result "  PASS: nma_fit tau2 >= 0"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_fit tau2 >= 0 (error `=_rc')"
    local ++fail_count
}

* Test 12: Common-effect model forces tau2 = 0
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, common nolog
    assert e(tau2) == 0
}
if _rc == 0 {
    display as result "  PASS: nma_fit common-effect tau2=0"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_fit common-effect tau2=0 (error `=_rc')"
    local ++fail_count
}

* Test 13: eform display
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, nolog eform
}
if _rc == 0 {
    display as result "  PASS: nma_fit eform"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_fit eform (error `=_rc')"
    local ++fail_count
}

* Test 14: Data preservation — _N unchanged after fit
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    local N_after_setup = _N
    nma_fit, nolog
    assert _N == `N_after_setup'
}
if _rc == 0 {
    display as result "  PASS: nma_fit data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_fit data preservation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_rank
* ============================================================

* Test 15: SUCRA values in [0, 1]
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, nolog
    nma_rank, seed(12345)
    forvalues i = 1/4 {
        assert _nma_sucra[`i', 1] >= 0 & _nma_sucra[`i', 1] <= 1
    }
}
if _rc == 0 {
    display as result "  PASS: nma_rank SUCRA in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_rank SUCRA in [0,1] (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_compare
* ============================================================

* Test 16: League table returns r(k) = 4
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, nolog
    nma_compare
    assert r(k) == 4
}
if _rc == 0 {
    display as result "  PASS: nma_compare league table (k=4)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_compare league table (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_inconsistency
* ============================================================

* Test 17: chi2_p in [0, 1]
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NoContact)
    nma_fit, nolog
    nma_inconsistency
    assert r(chi2_p) >= 0 & r(chi2_p) <= 1
}
if _rc == 0 {
    display as result "  PASS: nma_inconsistency chi2_p in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_inconsistency chi2_p (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_import — pre-computed effects
* ============================================================

* Test 18: Import sets _nma_setup flag
local ++test_count
capture noisily {
    clear
    input str12 study str15 treat_a str15 treat_b double(log_or se_log_or)
    "S1" "DrugA" "Placebo"  0.50 0.20
    "S2" "DrugA" "Placebo"  0.45 0.25
    "S3" "DrugB" "Placebo"  0.30 0.22
    "S4" "DrugB" "Placebo"  0.35 0.18
    "S5" "DrugA" "DrugB"    0.20 0.30
    end
    nma_import log_or se_log_or, studyvar(study) treat1(treat_a) treat2(treat_b) measure(or)
    local setup_flag : char _dta[_nma_setup]
    assert "`setup_flag'" == "1"
}
if _rc == 0 {
    display as result "  PASS: nma_import sets setup flag"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_import sets setup flag (error `=_rc')"
    local ++fail_count
}

* Test 19: Import then fit produces e(cmd)
local ++test_count
capture noisily {
    clear
    input str12 study str15 treat_a str15 treat_b double(log_or se_log_or)
    "S1" "DrugA" "Placebo"  0.50 0.20
    "S2" "DrugA" "Placebo"  0.45 0.25
    "S3" "DrugB" "Placebo"  0.30 0.22
    "S4" "DrugB" "Placebo"  0.35 0.18
    "S5" "DrugA" "DrugB"    0.20 0.30
    end
    nma_import log_or se_log_or, studyvar(study) treat1(treat_a) treat2(treat_b) measure(or)
    nma_fit, nolog
    assert "`e(cmd)'" == "nma_fit"
}
if _rc == 0 {
    display as result "  PASS: nma_import then fit"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_import then fit (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Error handling
* ============================================================

* Test 20: Setup required before fit (rc=198)
local ++test_count
capture noisily {
    clear
    set obs 10
    gen x = 1
    nma_fit
}
if _rc == 198 {
    display as result "  PASS: setup required before fit (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: setup required before fit — expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test 21: Invalid reference rejected (rc=198)
local ++test_count
capture noisily {
    use "qa/data/smoking_nma.dta", clear
    nma_setup events total, studyvar(study) trtvar(treatment) ref(NonExistent)
}
if _rc == 198 {
    display as result "  PASS: invalid reference rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid reference — expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test 22: Disconnected network detected (rc=198)
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "C" 20 100
    "S2" "D" 25 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment)
}
if _rc == 198 {
    display as result "  PASS: disconnected network detected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: disconnected network — expected rc=198, got `=_rc'"
    local ++fail_count
}

* Test 23: Disconnected network with force option
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "C" 20 100
    "S2" "D" 25 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) force
}
if _rc == 0 {
    display as result "  PASS: disconnected force accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: disconnected force accepted (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Cross-command integration — full pipeline
* ============================================================

* Test 24: setup → fit → rank → compare → inconsistency
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_rank, seed(42)
    nma_compare
    nma_inconsistency
}
if _rc == 0 {
    display as result "  PASS: full pipeline (setup→fit→rank→compare→inconsistency)"
    local ++pass_count
}
else {
    display as error "  FAIL: full pipeline (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_forest — basic functionality
* ============================================================

* Test 25: Fully connected network — all mixed evidence
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_forest
    assert r(n_comparisons) == 3
    assert r(n_mixed) == 3
    assert r(n_direct) == 0
    assert r(n_indirect) == 0
    assert "`r(ref)'" == "A"
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest basic (fully connected)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest basic (error `=_rc')"
    local ++fail_count
}

* Test 26: Star network — direct + indirect evidence
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "Ref" 10 100
    "S1" "D1"  15 100
    "S2" "Ref" 12 110
    "S2" "D2"  20 105
    "S3" "Ref" 18 100
    "S3" "D3"  22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(Ref)
    nma_fit, nolog
    nma_forest
    assert r(n_comparisons) == 6
    assert r(n_direct) == 3
    assert r(n_indirect) == 3
    assert r(n_mixed) == 0
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest star network (3 direct, 3 indirect)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest star network (error `=_rc')"
    local ++fail_count
}

* Test 27: Contrast-level import (Senn diabetes data)
local ++test_count
capture noisily {
    use "qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog
    nma_forest
    assert r(n_comparisons) > 0
    assert "`r(ref)'" == "Placebo"
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest Senn diabetes import"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest Senn diabetes import (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_forest — option tests
* ============================================================

* Test 28: comparisons(mixed) — no mixed in star network
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "Ref" 10 100
    "S1" "D1"  15 100
    "S2" "Ref" 12 110
    "S2" "D2"  20 105
    "S3" "Ref" 18 100
    "S3" "D3"  22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(Ref)
    nma_fit, nolog
    nma_forest, comparisons(mixed)
    assert r(n_comparisons) == 0
    assert r(n_mixed) == 0
}
if _rc == 0 {
    display as result "  PASS: nma_forest comparisons(mixed) no mixed"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest comparisons(mixed) no mixed (error `=_rc')"
    local ++fail_count
}

* Test 29: comparisons(mixed) — with mixed evidence
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_forest, comparisons(mixed)
    assert r(n_comparisons) == 3
    assert r(n_mixed) == 3
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest comparisons(mixed) with mixed"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest comparisons(mixed) with mixed (error `=_rc')"
    local ++fail_count
}

* Test 30: textcol and dp options
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_forest, textcol dp(3)
    assert r(n_comparisons) == 3
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest textcol dp(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest textcol dp(3) (error `=_rc')"
    local ++fail_count
}

* Test 31: eform option
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A) measure(or)
    nma_fit, nolog
    nma_forest, eform
    assert r(n_comparisons) == 3
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest eform"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest eform (error `=_rc')"
    local ++fail_count
}

* Test 32: Custom colors
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_forest, colors(cranberry teal black)
    assert r(n_comparisons) == 3
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest custom colors"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest custom colors (error `=_rc')"
    local ++fail_count
}

* Test 33: title and xtitle
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_forest, title("Custom Title") xtitle("Custom X")
    assert r(n_comparisons) == 3
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest title and xtitle"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest title and xtitle (error `=_rc')"
    local ++fail_count
}

* Test 34: name and saving options
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    tempfile gph
    nma_forest, name(test_forest) saving("`gph'") replace
    assert r(n_comparisons) == 3
    confirm file "`gph'"
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest name and saving"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest name and saving (error `=_rc')"
    local ++fail_count
}

* Test 35: level option
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_forest, eform textcol dp(1) comparisons(mixed) ///
        colors(cranberry teal black) title("Combined") ///
        xtitle("Effect") level(90)
    assert r(n_comparisons) == 3
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: nma_forest all options combined"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest all options combined (error `=_rc')"
    local ++fail_count
}


* ============================================================
* nma_forest — error handling
* ============================================================

* Test 36: Invalid comparisons() rejected (rc=198)
local ++test_count
capture noisily {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end
    nma_setup events total, studyvar(study) trtvar(treatment) ref(A)
    nma_fit, nolog
    nma_forest, comparisons(invalid)
}
if _rc == 198 {
    display as result "  PASS: nma_forest invalid comparisons() rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: nma_forest invalid comparisons() — expected rc=198, got `=_rc'"
    local ++fail_count
}


* ============================================================
* Summary
* ============================================================

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

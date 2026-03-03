* test_nma_forest.do — Tests for nma_forest evidence decomposition
* Location: ~/Stata-Tools/nma/qa/
clear all
set more off
mata: mata clear
capture ado uninstall nma
net install nma, from("/home/tpcopeland/Stata-Tools/nma/")

local n_pass = 0
local n_fail = 0
local n_tests = 0

* ===================================================================
* TEST 1: Basic plot — fully connected network (3 treatments, all mixed)
* ===================================================================
local ++n_tests
capture {
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
    display as result "PASS: Test 1 — Basic fully connected forest plot"
    local ++n_pass
}
else {
    display as error "FAIL: Test 1 — Basic fully connected forest plot (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 2: Star network — direct-only and indirect-only evidence
* ===================================================================
local ++n_tests
capture {
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
    * Star network: 3 direct pairs (vs ref), 3 indirect pairs (non-ref)
    assert r(n_comparisons) == 6
    assert r(n_direct) == 3
    assert r(n_indirect) == 3
    assert r(n_mixed) == 0
    graph close _all
}
if _rc == 0 {
    display as result "PASS: Test 2 — Star network (direct + indirect)"
    local ++n_pass
}
else {
    display as error "FAIL: Test 2 — Star network (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 3: Senn diabetes data (contrast-level import, MD)
* ===================================================================
local ++n_tests
capture {
    use "/home/tpcopeland/Stata-Tools/nma/qa/data/senn2013_diabetes.dta", clear
    nma_import te se_te, studyvar(study) treat1(treat1) treat2(treat2) ///
        measure(md) ref(Placebo)
    nma_fit, nolog

    nma_forest
    assert r(n_comparisons) > 0
    assert "`r(ref)'" == "Placebo"
    graph close _all
}
if _rc == 0 {
    display as result "PASS: Test 3 — Senn diabetes forest plot"
    local ++n_pass
}
else {
    display as error "FAIL: Test 3 — Senn diabetes (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 4: comparisons(mixed) filter
* ===================================================================
local ++n_tests
capture {
    * Use star network — has 0 mixed, should exit cleanly
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
    display as result "PASS: Test 4 — comparisons(mixed) with no mixed pairs"
    local ++n_pass
}
else {
    display as error "FAIL: Test 4 — comparisons(mixed) filter (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 5: comparisons(mixed) with mixed evidence present
* ===================================================================
local ++n_tests
capture {
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
    display as result "PASS: Test 5 — comparisons(mixed) with mixed evidence"
    local ++n_pass
}
else {
    display as error "FAIL: Test 5 — comparisons(mixed) with mixed (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 6: textcol option
* ===================================================================
local ++n_tests
capture {
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
    display as result "PASS: Test 6 — textcol with dp(3)"
    local ++n_pass
}
else {
    display as error "FAIL: Test 6 — textcol option (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 7: eform option (binary outcome)
* ===================================================================
local ++n_tests
capture {
    clear
    input str12 study str15 treatment events total
    "S1" "A" 10 100
    "S1" "B" 15 100
    "S2" "A" 12 110
    "S2" "C" 20 105
    "S3" "B" 18 95
    "S3" "C" 22 100
    end

    nma_setup events total, studyvar(study) trtvar(treatment) ///
        ref(A) measure(or)
    nma_fit, nolog

    nma_forest, eform
    assert r(n_comparisons) == 3
    graph close _all
}
if _rc == 0 {
    display as result "PASS: Test 7 — eform option"
    local ++n_pass
}
else {
    display as error "FAIL: Test 7 — eform option (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 8: Custom colors
* ===================================================================
local ++n_tests
capture {
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
    display as result "PASS: Test 8 — Custom colors"
    local ++n_pass
}
else {
    display as error "FAIL: Test 8 — Custom colors (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 9: title and xtitle options
* ===================================================================
local ++n_tests
capture {
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
    display as result "PASS: Test 9 — title and xtitle options"
    local ++n_pass
}
else {
    display as error "FAIL: Test 9 — title and xtitle (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 10: name and saving options
* ===================================================================
local ++n_tests
capture {
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
    display as result "PASS: Test 10 — name and saving options"
    local ++n_pass
}
else {
    display as error "FAIL: Test 10 — name and saving (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 11: Invalid comparisons() option
* ===================================================================
local ++n_tests
capture {
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
    display as result "PASS: Test 11 — Invalid comparisons() rejected"
    local ++n_pass
}
else {
    display as error "FAIL: Test 11 — Should reject invalid comparisons() (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* TEST 12: All options combined
* ===================================================================
local ++n_tests
capture {
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
        colors(cranberry teal black) title("Combined Test") ///
        xtitle("Custom Effect") level(90)
    assert r(n_comparisons) == 3
    graph close _all
}
if _rc == 0 {
    display as result "PASS: Test 12 — All options combined"
    local ++n_pass
}
else {
    display as error "FAIL: Test 12 — All options combined (rc=" _rc ")"
    local ++n_fail
}

* ===================================================================
* SUMMARY
* ===================================================================
display _newline as text "==============================="
display as text "nma_forest tests: `n_pass'/`n_tests' passed, `n_fail' failed"
display as text "==============================="

if `n_fail' > 0 {
    exit 9
}

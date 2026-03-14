clear all
set more off
version 16.0

* validation_raincloud.do - Correctness validation for raincloud package
* Generated: 2026-03-13
* Tests: 20

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

capture ado uninstall raincloud
quietly net install raincloud, from("/home/tpcopeland/Stata-Dev/raincloud")

* ============================================================
* V1: Stats Matrix - Known-answer tests (sysuse auto)
* ============================================================

* Hand-calculated from sysuse auto:
*   summarize mpg if foreign == 0, detail  →  N=52, mean≈19.83, sd≈4.74,
*       median=19, q25=16.5, q75=22, iqr=5.5
*   summarize mpg if foreign == 1, detail  →  N=22, mean≈24.77, sd≈6.61,
*       median=24.5, q25=21, q75=28, iqr=7

* Test V1.1: Stats matrix N values
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    * Row 1 = Domestic (foreign==0), Row 2 = Foreign (foreign==1)
    assert S[1,1] == 52
    assert S[2,1] == 22
}
if _rc == 0 {
    display as result "  PASS: V1.1 - stats matrix N values"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 - stats matrix N values (error `=_rc')"
    local ++fail_count
}

* Test V1.2: Stats matrix mean values
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    * Domestic mean ≈ 19.83
    assert abs(S[1,2] - 19.826923) < 0.001
    * Foreign mean ≈ 24.77
    assert abs(S[2,2] - 24.772727) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V1.2 - stats matrix mean values"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.2 - stats matrix mean values (error `=_rc')"
    local ++fail_count
}

* Test V1.3: Stats matrix median values
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    assert S[1,4] == 19
    assert S[2,4] == 24.5
}
if _rc == 0 {
    display as result "  PASS: V1.3 - stats matrix median values"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.3 - stats matrix median values (error `=_rc')"
    local ++fail_count
}

* Test V1.4: Stats matrix quartile values
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    * Domestic: q25=16.5, q75=22
    assert S[1,5] == 16.5
    assert S[1,6] == 22
    * Foreign: q25=21, q75=28
    assert S[2,5] == 21
    assert S[2,6] == 28
}
if _rc == 0 {
    display as result "  PASS: V1.4 - stats matrix quartile values"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.4 - stats matrix quartile values (error `=_rc')"
    local ++fail_count
}

* Test V1.5: Stats matrix IQR = q75 - q25
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    * IQR = q75 - q25 for each group
    assert abs(S[1,7] - (S[1,6] - S[1,5])) < 0.0001
    assert abs(S[2,7] - (S[2,6] - S[2,5])) < 0.0001
    * Domestic: IQR = 22-16.5 = 5.5
    assert S[1,7] == 5.5
    * Foreign: IQR = 28-21 = 7
    assert S[2,7] == 7
}
if _rc == 0 {
    display as result "  PASS: V1.5 - stats matrix IQR = q75 - q25"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.5 - stats matrix IQR = q75 - q25 (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: Single Group Invariants
* ============================================================

* Test V2.1: Single group stats match summarize, detail
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly summarize mpg, detail
    local exp_n    = r(N)
    local exp_mean = r(mean)
    local exp_sd   = r(sd)
    local exp_med  = r(p50)
    local exp_q25  = r(p25)
    local exp_q75  = r(p75)

    raincloud mpg
    matrix S = r(stats)
    assert S[1,1] == `exp_n'
    assert abs(S[1,2] - `exp_mean') < 0.0001
    assert abs(S[1,3] - `exp_sd')   < 0.0001
    assert S[1,4] == `exp_med'
    assert S[1,5] == `exp_q25'
    assert S[1,6] == `exp_q75'
}
if _rc == 0 {
    display as result "  PASS: V2.1 - single group matches summarize detail"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.1 - single group matches summarize detail (error `=_rc')"
    local ++fail_count
}

* Test V2.2: Total N across groups equals r(N)
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(foreign)
    matrix S = r(stats)
    * Sum of group Ns should equal total N
    assert S[1,1] + S[2,1] == r(N)
}
if _rc == 0 {
    display as result "  PASS: V2.2 - sum of group N equals total N"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.2 - sum of group N equals total N (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V3: Inline Dataset - Hand-Computed Values
* ============================================================

* Hand-computed dataset: x = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
* N = 10, mean = 5.5, sd = 3.02765..., median = 5.5
* q25 = 3 (Stata convention), q75 = 8
* IQR = 5

* Test V3.1: Known-answer with simple data
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double x = _n
    raincloud x
    matrix S = r(stats)
    assert S[1,1] == 10
    assert abs(S[1,2] - 5.5) < 0.0001
    assert S[1,4] == 5.5
}
if _rc == 0 {
    display as result "  PASS: V3.1 - known-answer simple sequence"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.1 - known-answer simple sequence (error `=_rc')"
    local ++fail_count
}

* Test V3.2: Two-group inline dataset
local ++test_count
capture noisily {
    clear
    input double x byte grp
        10 1
        20 1
        30 1
        40 1
        50 1
        100 2
        200 2
        300 2
        400 2
        500 2
    end
    raincloud x, over(grp)
    matrix S = r(stats)
    * Group 1: N=5, mean=30, median=30
    assert S[1,1] == 5
    assert abs(S[1,2] - 30) < 0.0001
    assert S[1,4] == 30
    * Group 2: N=5, mean=300, median=300
    assert S[2,1] == 5
    assert abs(S[2,2] - 300) < 0.0001
    assert S[2,4] == 300
}
if _rc == 0 {
    display as result "  PASS: V3.2 - two-group inline dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.2 - two-group inline dataset (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: Invariant Tests
* ============================================================

* Test V4.1: q25 <= median <= q75 for all groups
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(rep78)
    matrix S = r(stats)
    local ngrp = rowsof(S)
    forvalues g = 1/`ngrp' {
        assert S[`g', 5] <= S[`g', 4]
        assert S[`g', 4] <= S[`g', 6]
    }
}
if _rc == 0 {
    display as result "  PASS: V4.1 - q25 <= median <= q75 invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.1 - q25 <= median <= q75 invariant (error `=_rc')"
    local ++fail_count
}

* Test V4.2: IQR >= 0 for all groups
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(rep78)
    matrix S = r(stats)
    local ngrp = rowsof(S)
    forvalues g = 1/`ngrp' {
        assert S[`g', 7] >= 0
    }
}
if _rc == 0 {
    display as result "  PASS: V4.2 - IQR >= 0 invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.2 - IQR >= 0 invariant (error `=_rc')"
    local ++fail_count
}

* Test V4.3: sd >= 0 for all groups
local ++test_count
capture noisily {
    sysuse auto, clear
    raincloud mpg, over(rep78)
    matrix S = r(stats)
    local ngrp = rowsof(S)
    forvalues g = 1/`ngrp' {
        assert S[`g', 3] >= 0
    }
}
if _rc == 0 {
    display as result "  PASS: V4.3 - sd >= 0 invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.3 - sd >= 0 invariant (error `=_rc')"
    local ++fail_count
}

* Test V4.4: n_groups matches levelsof count
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly levelsof rep78, local(levs)
    local expected : word count `levs'
    raincloud mpg, over(rep78)
    assert r(n_groups) == `expected'
}
if _rc == 0 {
    display as result "  PASS: V4.4 - n_groups matches levelsof"
    local ++pass_count
}
else {
    display as error "  FAIL: V4.4 - n_groups matches levelsof (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V5: if/in Restriction Validation
* ============================================================

* Test V5.1: Stats match when computed on restricted sample
local ++test_count
capture noisily {
    sysuse auto, clear
    * Compute expected values on restricted sample
    quietly summarize mpg if price > 6000, detail
    local exp_n = r(N)
    local exp_mean = r(mean)
    local exp_med = r(p50)

    raincloud mpg if price > 6000
    matrix S = r(stats)
    assert S[1,1] == `exp_n'
    assert abs(S[1,2] - `exp_mean') < 0.0001
    assert S[1,4] == `exp_med'
}
if _rc == 0 {
    display as result "  PASS: V5.1 - if restriction stats match"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.1 - if restriction stats match (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V6: Missing Value Handling
* ============================================================

* Test V6.1: Missing values in main variable excluded
local ++test_count
capture noisily {
    sysuse auto, clear
    replace mpg = . in 1/10
    raincloud mpg
    assert r(N) == 64
    matrix S = r(stats)
    assert S[1,1] == 64
}
if _rc == 0 {
    display as result "  PASS: V6.1 - missing values excluded"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.1 - missing values excluded (error `=_rc')"
    local ++fail_count
}

* Test V6.2: Missing values in over variable excluded
local ++test_count
capture noisily {
    sysuse auto, clear
    * rep78 has 5 missing values
    raincloud mpg, over(rep78)
    assert r(N) == 69
}
if _rc == 0 {
    display as result "  PASS: V6.2 - missing over values excluded"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.2 - missing over values excluded (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V7: Constant Variable Edge Case
* ============================================================

* When all values are identical: sd=0, q25=q75=median=mean, IQR=0

* Test V7.1: Constant variable stats
local ++test_count
capture noisily {
    clear
    set obs 20
    gen double x = 42
    raincloud x
    matrix S = r(stats)
    assert S[1,1] == 20
    assert abs(S[1,2] - 42) < 0.0001
    assert S[1,3] == 0
    assert S[1,4] == 42
    assert S[1,5] == 42
    assert S[1,6] == 42
    assert S[1,7] == 0
}
if _rc == 0 {
    display as result "  PASS: V7.1 - constant variable stats"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.1 - constant variable stats (error `=_rc')"
    local ++fail_count
}

* Test V7.2: Single observation stats
local ++test_count
capture noisily {
    clear
    set obs 1
    gen double x = 99
    raincloud x
    matrix S = r(stats)
    assert S[1,1] == 1
    assert abs(S[1,2] - 99) < 0.0001
    assert S[1,4] == 99
}
if _rc == 0 {
    display as result "  PASS: V7.2 - single observation stats"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.2 - single observation stats (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Summary
* ============================================================

display as result _newline "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}

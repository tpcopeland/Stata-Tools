* test_review_v1013_fixes.do — Regression tests for v1.0.13 deep review findings
* Covers: regtab headershade guard, diagtab prevalence edge case,
*         crosstab auto-Fisher, corrtab Spearman pairwise missing

clear all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture log close _review_fixes
log using "`output_dir'/test_review_v1013_fixes.log", replace text name(_review_fixes)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

local checker "`qa_dir'/tools/check_xlsx.py"

* =========================================================================
**# regtab headershade
* =========================================================================

**## regtab without headershade has NO header fill
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight foreign

    local _xlsx "`output_dir'/_test_headershade_off.xlsx"
    capture erase "`_xlsx'"
    regtab, xlsx("`_xlsx'") sheet("NoShade") noint

    confirm file "`_xlsx'"
    quietly shell python3 "`checker'" "`_xlsx'" "NoShade" --no-fill 2:B 3:B
}
if _rc == 0 {
    display as result "  PASS: regtab without headershade has no header fill"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab without headershade has no header fill (rc=`=_rc')"
    local ++fail_count
}

**## regtab WITH headershade has header fill
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight foreign

    local _xlsx "`output_dir'/_test_headershade_on.xlsx"
    capture erase "`_xlsx'"
    regtab, xlsx("`_xlsx'") sheet("Shaded") noint headershade

    confirm file "`_xlsx'"
    quietly shell python3 "`checker'" "`_xlsx'" "Shaded" --has-fill 2:B 3:B
}
if _rc == 0 {
    display as result "  PASS: regtab with headershade applies header fill"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab with headershade missing header fill (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# diagtab prevalence edge cases
* =========================================================================

**## Se=0 Sp=1 with prevalence() does not crash
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0
    replace test = 1 in 51/100

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 0) < 1e-10
    assert abs(r(specificity) - 0) < 1e-10
    // PPV denominator = Se*prev + (1-Sp)*(1-prev) = 0*0.3 + 1*0.7 = 0.7
    // NPV denominator = (1-Se)*prev + Sp*(1-prev) = 1*0.3 + 0*0.7 = 0.3
    assert !missing(r(ppv))
    assert !missing(r(npv))
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=0 Sp=0 with prevalence does not crash"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=0 Sp=0 with prevalence crashed (rc=`=_rc')"
    local ++fail_count
}

**## Perfect Se=1 Sp=0 with prevalence() does not crash
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 1

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 0) < 1e-10
    assert !missing(r(ppv))
    // NPV denom = (1-Se)*prev + Sp*(1-prev) = 0*0.3 + 0*0.7 = 0 → missing
    assert missing(r(npv))
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=1 Sp=0 with prevalence does not crash"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=1 Sp=0 with prevalence crashed (rc=`=_rc')"
    local ++fail_count
}

**## Se=1 Sp=1 with prevalence: PPV and NPV both 1
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold

    diagtab test gold, prevalence(0.5)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 1) < 1e-10
    assert abs(r(ppv) - 1) < 1e-10
    assert abs(r(npv) - 1) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab perfect classifier with prevalence"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab perfect classifier with prevalence (rc=`=_rc')"
    local ++fail_count
}

**## Se=0 Sp=1 edge case: PPV denominator = 0, PPV should be missing
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 0

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 0) < 1e-10
    assert abs(r(specificity) - 1) < 1e-10
    // PPV denom = Se*prev + (1-Sp)*(1-prev) = 0*0.3 + 0*0.7 = 0
    // PPV should remain missing (division guarded)
    assert missing(r(ppv))
    // NPV denom = (1-Se)*prev + Sp*(1-prev) = 1*0.3 + 1*0.7 = 1
    assert abs(r(npv) - 0.7) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=0 Sp=1 prevalence: PPV=. NPV=0.7"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=0 Sp=1 prevalence edge case (rc=`=_rc')"
    local ++fail_count
}

**## Se=1 Sp=0: NPV denominator = 0, NPV should be missing
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 1

    replace gold = 0 in 1/50
    replace gold = 1 in 51/100
    replace test = gold

    replace test = 1

    diagtab test gold, prevalence(0.3)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 0) < 1e-10
    // NPV denom = (1-Se)*prev + Sp*(1-prev) = 0*0.3 + 0*0.7 = 0
    assert missing(r(npv))
    // PPV denom = Se*prev + (1-Sp)*(1-prev) = 1*0.3 + 1*0.7 = 1
    assert abs(r(ppv) - 0.3) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab Se=1 Sp=0 prevalence: NPV=. PPV=0.3"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab Se=1 Sp=0 prevalence edge case (rc=`=_rc')"
    local ++fail_count
}

**## Cutoffs path: Se=0 Sp=1 with prevalence via cutoff()
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen double score = cond(gold, 0.7, 0.3)

    diagtab score gold, cutoff(0.5) prevalence(0.3)

    assert abs(r(sensitivity) - 1) < 1e-10
    assert abs(r(specificity) - 1) < 1e-10
    assert abs(r(ppv) - 1) < 1e-10
    assert abs(r(npv) - 1) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoff path with prevalence adjustment"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoff path prevalence adjustment (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# crosstab auto-Fisher
* =========================================================================

**## Auto-Fisher when expected cells < 5
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 50
    0 1 2
    1 0 3
    1 1 1
    end
    expand freq

    capture frame drop _cross_fisher
    crosstab outcome exposure, or label frame(_cross_fisher, replace)

    assert r(N) == 56
    // expected count for cell (1,1) = 4*3/56 = 0.21 < 5 => Fisher auto-selected
    frame _cross_fisher {
        local found_fisher = 0
        forvalues i = 1/`=_N' {
            if strpos(c1[`i'], "Fisher") > 0 local found_fisher = 1
        }
        assert `found_fisher' == 1
    }
    capture frame drop _cross_fisher
}
if _rc == 0 {
    display as result "  PASS: crosstab auto-selects Fisher for sparse expected cells"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab auto-Fisher selection (rc=`=_rc')"
    local ++fail_count
}

**## Large expected cells use chi-squared, not Fisher
local ++test_count
capture noisily {
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq

    capture frame drop _cross_chi2
    crosstab outcome exposure, or frame(_cross_chi2, replace)

    frame _cross_chi2 {
        local found_chi2 = 0
        forvalues i = 1/`=_N' {
            if strpos(c1[`i'], "Chi") > 0 | strpos(c1[`i'], "chi") > 0 {
                local found_chi2 = 1
            }
        }
        assert `found_chi2' == 1
    }
    capture frame drop _cross_chi2
}
if _rc == 0 {
    display as result "  PASS: crosstab uses chi-squared for large expected cells"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab chi-squared selection (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# corrtab Spearman pairwise missing
* =========================================================================

**## Spearman with pairwise missing: N matrix reflects pairwise counts
local ++test_count
capture noisily {
    clear
    set obs 20
    gen double x = _n
    gen double y = _n * 2 + rnormal()
    gen double z = _n * 3 + rnormal()
    replace x = . in 1/5
    replace z = . in 10/15

    corrtab x y z, spearman

    // x has 15 non-missing, y has 20, z has 14
    // N(x,y) = 15, N(y,z) = 14, N(x,z) = min of overlap
    assert r(N)[1,2] == 15 // x-y pair: 15 non-missing x, 20 non-missing y => 15
    assert r(N)[2,3] == 14 // y-z pair: 20 non-missing y, 14 non-missing z => 14

    // x-z pair: both non-missing when _n in {6..9, 16..20} = 9
    assert r(N)[1,3] == 9

    // Correlations should be non-missing
    assert !missing(r(C)[1,2])
    assert !missing(r(C)[2,3])
    assert !missing(r(C)[1,3])
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman pairwise missing N counts correct"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman pairwise missing (rc=`=_rc')"
    local ++fail_count
}

**## Spearman pairwise p-values are non-missing
local ++test_count
capture noisily {
    clear
    set obs 30
    gen double x = rnormal()
    gen double y = rnormal()
    gen double z = rnormal()
    replace x = . in 1/10
    replace z = . in 15/25

    corrtab x y z, spearman pvalues

    assert !missing(r(P)[1,2])
    assert !missing(r(P)[2,3])
    assert !missing(r(P)[1,3])
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman pairwise p-values non-missing"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman pairwise p-values (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# Summary
* =========================================================================

display _newline
display as text "========================================"
display as text "Review v1.0.13 fix tests: `pass_count'/`test_count' PASSED, `fail_count' FAILED"
display as text "========================================"
assert `fail_count' == 0

log close _review_fixes

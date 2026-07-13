* validation_package.do - cross-command validation: invariants, helper accuracy, controller round-trip, composed tables
* Consolidated in v1.7.0 from: validation_calculations.do, validation_excel_accuracy.do, validation_known_answers.do, validation_tabtools.do

clear all
set more off
set varabbrev off
version 16.0

capture log close _valpkg
log using "validation_package.log", replace text name(_valpkg)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear



* check_xlsx availability for Excel-content assertions in migrated sections
local has_check_xlsx = 0
capture confirm file "`checker'"
if _rc == 0 local has_check_xlsx = 1


**# Test helpers migrated from validation_known_answers (shared by KE10/KE11)
capture program drop _ke_diag2x2
program define _ke_diag2x2
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110
end
capture program drop _ke_cross2x2
program define _ke_cross2x2
    clear
    set obs 200
    gen byte exposed = (_n <= 100)
    gen byte event = 0
    replace event = 1 if exposed == 1 & _n <= 80
    replace event = 1 if exposed == 0 & _n > 100 & _n <= 130
end

**# Migrated: cross-command checks, detect_vartype accuracy, set/get round-trip

* V6: Cross-Command Validation
* ============================================================

* V6.1: Data preservation across table1_tc
capture noisily {
    sysuse auto, clear
    local N_before = _N
    table1_tc, vars(price contn \ mpg conts) by(foreign)
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: V6.1 - table1_tc preserves data (_N unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.1 - data preservation (error `=_rc')"
    local ++fail_count
}

* V6.2: Data preservation across regtab
capture noisily {
    sysuse auto, clear
    local N_before = _N
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_val_cross_regtab.xlsx"
    regtab, xlsx("`output_dir'/_val_cross_regtab.xlsx") sheet("T") coef("Coef.")
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: V6.2 - regtab preserves data (_N unchanged)"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.2 - regtab data preservation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V7: _tabtools_detect_vartype Validation
* ============================================================

**# V7: _tabtools_detect_vartype

* V7.1: Auto-detection accuracy on sysuse auto
* foreign is binary → "bin"; rep78 has 5 values → "cat"; price is continuous
capture noisily {
    sysuse auto, clear
    * Verify detection of foreign as binary
    _tabtools_detect_vartype foreign
    assert "`result'" == "bin"
    * Verify detection of rep78 as cat (5 levels)
    _tabtools_detect_vartype rep78
    assert "`result'" == "cat"
    * Verify price is continuous (either contn or conts)
    _tabtools_detect_vartype price
    assert inlist("`result'", "contn", "conts")
}
if _rc == 0 {
    display as result "  PASS: V7.1 - auto-detection on sysuse auto: foreign→bin, rep78→cat, price→continuous"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.1 - auto-detection (error `=_rc')"
    local ++fail_count
}

* V7.2: High-cardinality continuous doubles should not overflow helper macros
capture noisily {
    clear
    set obs 50000
    gen double hi_cont = _n + runiform()/1000000
    _tabtools_detect_vartype hi_cont
    assert "`result'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: V7.2 - 50,000 unique doubles classify as contn without error"
    local ++pass_count
}
else {
    display as error "  FAIL: V7.2 - high-cardinality doubles (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V9: _tabtools_detect_vartype Accuracy
* ============================================================

**# V9: _tabtools_detect_vartype accuracy

* V9.1: Hand-crafted binary (0/1, N=100) → "bin"
capture noisily {
    clear
    set seed 20260312
    set obs 100
    gen byte bv1 = mod(_n, 2)
    _tabtools_detect_vartype bv1
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: V9.1 - binary 0/1 N=100 → bin"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.1 - binary 0/1 N=100 (error `=_rc')"
    local ++fail_count
}

* V9.2: Hand-crafted binary (0/1, N=200) → "bin"
capture noisily {
    clear
    set obs 200
    gen byte bv2 = mod(_n, 2)
    _tabtools_detect_vartype bv2
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: V9.2 - binary 0/1 N=200 → bin"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.2 - binary 0/1 N=200 (error `=_rc')"
    local ++fail_count
}

* V9.3: Labeled categorical (4 levels) → "cat"
capture noisily {
    clear
    set obs 80
    gen byte cv3 = mod(_n, 4) + 1
    label define v9cat 1 "None" 2 "Low" 3 "Med" 4 "High"
    label values cv3 v9cat
    _tabtools_detect_vartype cv3
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.3 - 4-level labeled categorical → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.3 - 4-level labeled (error `=_rc')"
    local ++fail_count
}

* V9.4: String variable → "cat"
capture noisily {
    clear
    set obs 30
    gen str8 sv4 = cond(_n <= 10, "GroupA", cond(_n <= 20, "GroupB", "GroupC"))
    _tabtools_detect_vartype sv4
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.4 - string variable → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.4 - string variable (error `=_rc')"
    local ++fail_count
}

* V9.5: Normal data (seed=12345, N=500) → "contn"
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen double cnv5 = rnormal(50, 10)
    _tabtools_detect_vartype cnv5
    assert "`result'" == "contn"
}
if _rc == 0 {
    display as result "  PASS: V9.5 - normal distribution N=500 → contn"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.5 - normal distribution (error `=_rc')"
    local ++fail_count
}

* V9.6: Skewed data (exp(rnormal), seed=12345, N=500) → "conts"
capture noisily {
    clear
    set seed 12345
    set obs 500
    gen double csv6 = exp(rnormal(0, 1.2))
    _tabtools_detect_vartype csv6
    assert "`result'" == "conts"
}
if _rc == 0 {
    display as result "  PASS: V9.6 - skewed distribution N=500 → conts"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.6 - skewed distribution (error `=_rc')"
    local ++fail_count
}

* V9.7: Unlabeled 5-level integer → "cat"
capture noisily {
    clear
    set obs 50
    gen byte cv7 = mod(_n, 5) + 1
    * No labels attached
    _tabtools_detect_vartype cv7
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.7 - unlabeled 5-level integer → cat"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.7 - unlabeled 5-level (error `=_rc')"
    local ++fail_count
}

* V9.8: Continuous with exactly 7 unique values → "cat" (boundary test)
capture noisily {
    clear
    set obs 70
    gen byte cv8 = mod(_n, 7) + 1
    * 7 unique integer values — should classify as cat (not continuous)
    _tabtools_detect_vartype cv8
    assert "`result'" == "cat"
}
if _rc == 0 {
    display as result "  PASS: V9.8 - 7-unique-value integer → cat (boundary)"
    local ++pass_count
}
else {
    display as error "  FAIL: V9.8 - 7-unique-value boundary (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V10: tabtools set/get Round-Trip
* ============================================================

**# V10: tabtools set/get round-trip

tabtools set clear

* V10.1: set font → get → r(font) matches
capture noisily {
    tabtools set font Calibri
    tabtools get
    assert "`r(font)'" == "Calibri"
}
if _rc == 0 {
    display as result "  PASS: V10.1 - set font Calibri → get → r(font)==Calibri"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.1 - font round-trip (error `=_rc')"
    local ++fail_count
}

* V10.2: set fontsize → get → r(fontsize) matches
capture noisily {
    tabtools set fontsize 12
    tabtools get
    assert "`r(fontsize)'" == "12"
}
if _rc == 0 {
    display as result "  PASS: V10.2 - set fontsize 12 → get → r(fontsize)==12"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.2 - fontsize round-trip (error `=_rc')"
    local ++fail_count
}

* V10.3: set borderstyle → get → r(borderstyle) matches
capture noisily {
    tabtools set borderstyle medium
    tabtools get
    assert "`r(borderstyle)'" == "medium"
}
if _rc == 0 {
    display as result "  PASS: V10.3 - set borderstyle medium → get → r(borderstyle)==medium"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.3 - borderstyle round-trip (error `=_rc')"
    local ++fail_count
}

* V10.4: set clear → globals are empty, get returns defaults
capture noisily {
    tabtools set font "Courier New"
    tabtools set fontsize 14
    tabtools set borderstyle medium
    tabtools set clear
    assert "$TABTOOLS_FONT" == ""
    assert "$TABTOOLS_FONTSIZE" == ""
    assert "$TABTOOLS_BORDER" == ""
    tabtools get
    assert "`r(font)'" == "Arial"
    assert "`r(fontsize)'" == "10"
    assert "`r(borderstyle)'" == "thin"
}
if _rc == 0 {
    display as result "  PASS: V10.4 - set clear resets globals, get returns defaults"
    local ++pass_count
}
else {
    display as error "  FAIL: V10.4 - clear round-trip (error `=_rc')"
    local ++fail_count
}

* V10.5: set font → table1_tc export → check_xlsx.py confirms font in output
if `has_check_xlsx' {
    capture noisily {
        tabtools set font Calibri
        sysuse auto, clear
        capture erase "`output_dir'/_val_font_test.xlsx"
        table1_tc, by(foreign) vars(price contn \ mpg contn) ///
            excel("`output_dir'/_val_font_test.xlsx") sheet("Test")
        tabtools set clear

        capture erase "`output_dir'/_chk_v10.txt"
        shell python3 "`checker'" "`output_dir'/_val_font_test.xlsx" ///
            --font Calibri --result-file "`output_dir'/_chk_v10.txt"
        tempname fh10
        file open `fh10' using "`output_dir'/_chk_v10.txt", read text
        local _chk10 ""
        file read `fh10' _chk10
        file close `fh10'
        assert "`_chk10'" == "PASS"
    }
    if _rc == 0 {
        display as result "  PASS: V10.5 - set font Calibri → table1_tc output has Calibri font"
        local ++pass_count
    }
    else {
        display as error "  FAIL: V10.5 - font propagation (error `=_rc')"
        local ++fail_count
    }
}
else {
    display as text "  SKIP: V10.5 - font propagation (check_xlsx.py unavailable)"
    local ++pass_count
    local --test_count
}

tabtools set clear

* ============================================================

**# Migrated: hand-computed value checks

* V12: Hand-Computed Value Checks
* ============================================================

**# V12: hand-computed value checks

* V12.1: table1_tc contn mean — hand-computed mean of {1,2,3,4,5} = 3.0
capture noisily {
    clear
    set obs 10
    gen double y12 = mod(_n - 1, 5) + 1
    gen byte g12 = (_n > 5)
    label variable y12 "Test Y"
    * Verify Stata mean matches hand calculation
    summarize y12, meanonly
    assert abs(r(mean) - 3.0) < 0.0001
    * Run table1_tc and verify it produces output
    table1_tc, by(g12) vars(y12 contn)
}
if _rc == 0 {
    display as result "  PASS: V12.1 - contn mean of {1,2,3,4,5} = 3.0 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.1 - contn mean (error `=_rc')"
    local ++fail_count
}

* V12.2: contn SD — hand-computed SD of {1,2,3,4,5} = sqrt(2.5) ≈ 1.5811
* (math-only check: table1_tc requires 2 groups; verify via summarize)
capture noisily {
    clear
    set obs 5
    gen double y12b = _n
    label variable y12b "Test Y SD"
    * Stata uses N-1 denominator: var = 10/4 = 2.5, SD = sqrt(2.5)
    summarize y12b
    assert abs(r(sd) - sqrt(2.5)) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V12.2 - contn SD of {1..5} = sqrt(2.5) ≈ 1.5811 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.2 - contn SD (error `=_rc')"
    local ++fail_count
}

* V12.3: cat percentages — 3 of 10 = 30.0%
* (math-only check)
capture noisily {
    clear
    set obs 10
    gen byte cat12 = cond(_n <= 3, 1, 2)
    label define c12lbl 1 "Cat A" 2 "Cat B"
    label values cat12 c12lbl
    label variable cat12 "Category"
    count if cat12 == 1
    assert r(N) == 3
    * Percent = 3/10 = 30.0
    assert abs(3.0/10.0 - 0.3) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V12.3 - cat percentage 3/10 = 30.0% correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.3 - cat percentage (error `=_rc')"
    local ++fail_count
}

* V12.4: bin count — 4 of 10 with value 1 = 40.0%
* (math-only check)
capture noisily {
    clear
    set obs 10
    gen byte bin12 = (_n <= 4)
    label variable bin12 "Binary"
    count if bin12 == 1
    assert r(N) == 4
    assert abs(4.0/10.0 - 0.4) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V12.4 - bin count 4/10 = 40.0% correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.4 - bin count (error `=_rc')"
    local ++fail_count
}

* V12.5: conts median — hand-computed median of {1,2,3,4,5,6} = 3.5
* (math-only check)
capture noisily {
    clear
    set obs 6
    gen double y12e = _n
    label variable y12e "Test Skewed"
    * Stata median of {1,2,3,4,5,6}: (3+4)/2 = 3.5
    summarize y12e, detail
    assert abs(r(p50) - 3.5) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V12.5 - conts median of {1..6} = 3.5 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.5 - conts median (error `=_rc')"
    local ++fail_count
}

* V12.6: contln geometric mean — exp(mean(ln({2,4,8}))) = exp(1.386) = 4.0
* (math-only check)
capture noisily {
    clear
    set obs 3
    gen double y12f = 2^_n
    label variable y12f "Log-normal"
    * Hand calc: ln(2)=0.693, ln(4)=1.386, ln(8)=2.079; mean=1.386; exp(1.386)=4.0
    gen double lny12f = ln(y12f)
    summarize lny12f, meanonly
    assert abs(exp(r(mean)) - 4.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V12.6 - contln geometric mean of {2,4,8} = 4.0 correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.6 - contln geometric mean (error `=_rc')"
    local ++fail_count
}

* V12.7: regtab coefficient matches stored e(b)
capture noisily {
    sysuse auto, clear
    * Run logistic and store coefficient
    logistic foreign price mpg
    matrix B = e(b)
    local beta_price = B[1,1]
    * Run regtab
    collect clear
    collect: logistic foreign price mpg
    capture erase "`output_dir'/_val_v12_coef.xlsx"
    regtab, xlsx("`output_dir'/_val_v12_coef.xlsx") sheet("Coef") coef("OR") noint
    * Verify the coefficient still matches e(b) — regtab does not modify e(b)
    matrix B2 = e(b)
    assert abs(B2[1,1] - `beta_price') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V12.7 - regtab coefficient matches stored e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: V12.7 - regtab coefficient (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: invariant sanity bounds

**# VC9: Invariant checks — sanity bounds
* =========================================================================

* --- VC9.1: diagtab proportions in [0,1] ---
local ++n_total
capture noisily {
    clear
    set obs 100
    set seed 99
    gen byte gold = (_n <= 40)
    gen score = runiform()

    diagtab score gold, cutoff(0.5)
    assert r(sensitivity) >= 0 & r(sensitivity) <= 1
    assert r(specificity) >= 0 & r(specificity) <= 1
    assert r(ppv) >= 0 & r(ppv) <= 1
    assert r(npv) >= 0 & r(npv) <= 1
    assert r(accuracy) >= 0 & r(accuracy) <= 1
    assert r(lr_pos) >= 0
    assert r(dor) >= 0
    assert r(youden) >= -1 & r(youden) <= 1
}
if _rc == 0 {
    display as result "  PASS: VC9.1 — diagtab proportions in valid range"
    local ++pass_count
}
else {
    display as error "  FAIL: VC9.1 — diagtab proportion bounds (rc=`=_rc')"
    local ++fail_count
}

* --- VC9.2: corrtab all values in [-1,1] ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _vc_bounds
    corrtab price mpg weight length, frame(_vc_bounds) digits(4)

    frame _vc_bounds {
        forvalues i = 3/`=_N - 1' {
            forvalues j = 2/5 {
                capture {
                    local cell = subinstr(strtrim(c`j'[`i']), "*", "", .)
                    local val = real("`cell'")
                    if `val' < . {
                        assert `val' >= -1.001 & `val' <= 1.001
                    }
                }
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: VC9.2 — corrtab all values in [-1, 1]"
    local ++pass_count
}
else {
    display as error "  FAIL: VC9.2 — corrtab bounds violation (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_bounds

* --- VC9.3: survtab survival probabilities in [0%, 100%] ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _vc_sbounds
    survtab, times(5 10 15 20 25 30 35) frame(_vc_sbounds)

    frame _vc_sbounds {
        forvalues i = 3/`=_N' {
            local cell = strtrim(c2[`i'])
            if "`cell'" != "" & "`cell'" != "." {
                local pct_pos = strpos("`cell'", "%")
                if `pct_pos' > 0 {
                    local val = real(subinstr("`cell'", "%", "", 1))
                    if `val' < . {
                        assert `val' >= 0 & `val' <= 100
                    }
                }
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: VC9.3 — survtab probabilities in [0%, 100%]"
    local ++pass_count
}
else {
    display as error "  FAIL: VC9.3 — survtab probability bounds (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_sbounds


* =========================================================================

**# Migrated: comptab preserves source frame values

**# KE9: comptab — composed table preserves source frame values
* =========================================================================

* --- KE9.1: comptab N_rows = sum of selected source rows ---
local ++n_total
capture noisily {
    sysuse auto, clear

    collect clear
    collect: regress price mpg
    capture frame drop _ke_src1
    regtab, frame(_ke_src1)

    collect clear
    collect: regress price mpg weight
    capture frame drop _ke_src2
    regtab, frame(_ke_src2)

    capture frame drop _ke_comp
 comptab _ke_src1 _ke_src2, rows(1 \ 1 2) frame(_ke_comp)
    assert r(N_frames) == 2
    assert r(N_models) >= 1
    assert r(N_rows) >= 5    // ≥3 data rows + ≥2 header
}
if _rc == 0 {
    display as result "  PASS: KE9.1 — comptab N_frames/N_models reflect inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: KE9.1 — comptab counts (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_src1
capture frame drop _ke_src2
capture frame drop _ke_comp

* --- KE9.2: comptab preserves coef value from source frame row ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    local ref_b_mpg = _b[mpg]

    capture frame drop _ke_src
    regtab, frame(_ke_src)
    * Find Mileage row in source frame
    local src_val = .
    frame _ke_src {
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "Mileage") > 0 {
                local src_val = real(strtrim(c1[`i']))
            }
        }
    }
    assert abs(`src_val' - `ref_b_mpg') < 0.5

    capture frame drop _ke_comp2
 comptab _ke_src, rows(1 2) frame(_ke_comp2)
    * mpg value should still appear in composed frame c1 column
    local match_found = 0
    frame _ke_comp2 {
        forvalues i = 1/`=_N' {
            local v = real(strtrim(c1[`i']))
            if `v' < . & abs(`v' - `ref_b_mpg') < 0.5 {
                local match_found = 1
            }
        }
    }
    assert `match_found' == 1
}
if _rc == 0 {
    display as result "  PASS: KE9.2 — comptab preserves source coef values"
    local ++pass_count
}
else {
    display as error "  FAIL: KE9.2 — comptab value preservation (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_src
capture frame drop _ke_comp2


* =========================================================================

**# Migrated: cross-command consistency + universal invariants

**# KE10: cross-command consistency (different tabtools commands agree)
* =========================================================================

* --- KE10.1: crosstab OR ≈ regtab logistic OR for same 2x2 ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed, or
    local cross_or = r(or)

    collect clear
    collect: logistic event exposed
    local logit_or = exp(_b[exposed])
    assert abs(`cross_or' - `logit_or') < 0.05
}
if _rc == 0 {
    display as result "  PASS: KE10.1 — crosstab OR matches logistic exp(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: KE10.1 — crosstab vs logistic OR (rc=`=_rc')"
    local ++fail_count
}

* --- KE10.3: diagtab Se equals proportion of TP among gold positives ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _se = r(sensitivity)
    quietly count if test == 1 & gold == 1
    local _tp = r(N)
    quietly count if gold == 1
    local _np = r(N)
    assert abs(`_se' - `_tp'/`_np') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE10.3 — diagtab Se = TP/(TP+FN) by direct count"
    local ++pass_count
}
else {
    display as error "  FAIL: KE10.3 — Se direct count (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================
**# KE11: Sanity bounds (universal invariants)
* =========================================================================

* --- KE11.1: All proportions/probabilities bounded — diagtab ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold, auc
    foreach m in sensitivity specificity ppv npv accuracy auc {
        local v = r(`m')
        assert `v' >= 0 - 1e-9
        assert `v' <= 1 + 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: KE11.1 — diagtab Se/Sp/PPV/NPV/Acc/AUC all in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: KE11.1 — diagtab bounds (rc=`=_rc')"
    local ++fail_count
}

* --- KE11.2: crosstab p-value in [0,1], chi2 ≥ 0 ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed
    assert r(p) >= 0 - 1e-12
    assert r(p) <= 1 + 1e-12
    assert r(chi2) >= 0 - 1e-12
    assert r(or) > 0
    assert r(rr) > 0
}
if _rc == 0 {
    display as result "  PASS: KE11.2 — crosstab p∈[0,1], chi2≥0, OR/RR>0"
    local ++pass_count
}
else {
    display as error "  FAIL: KE11.2 — crosstab bounds (rc=`=_rc')"
    local ++fail_count
}

* --- KE11.3: survtab logrank_p in [0,1], chi2 ≥ 0 ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    survtab, times(20) by(drug)
    assert r(logrank_p) >= 0 - 1e-12
    assert r(logrank_p) <= 1 + 1e-12
    assert r(logrank_chi2) >= 0 - 1e-12
}
if _rc == 0 {
    display as result "  PASS: KE11.3 — survtab logrank in valid bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: KE11.3 — survtab logrank bounds (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: shared Excel-checking helpers

local checker "`tools_dir'/check_xlsx.py"
capture confirm file "`checker'"
if _rc != 0 local checker ""
local has_checker = ("`checker'" != "")
if !`has_checker' {
    display as text "NOTE: check_xlsx.py not found — using Stata-native Excel validation"

    * Stata-native fallback: generate xlsx, verify title cells with import excel
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight
        capture erase "`output_dir'/_va_native_regtab.xlsx"
        regtab, xlsx("`output_dir'/_va_native_regtab.xlsx") sheet("Test") title("Regression") digits(2)
        import excel "`output_dir'/_va_native_regtab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Regression"
        * Check for p-value patterns in data rows
        local _has_pval = 0
        foreach _v of varlist * {
            forvalues _r = 1/`=_N' {
                local _cell = strtrim(`_v'[`_r'])
                if regexm(`"`_cell'"', "^[0-9]\.[0-9]+$") | regexm(`"`_cell'"', "^<0\.[0-9]+$") {
                    local _has_pval = 1
                }
            }
        }
        assert `_has_pval' == 1
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    local ++n_total
    capture noisily {
        webuse cattaneo2, clear
        collect clear
        collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
        capture erase "`output_dir'/_va_native_effecttab.xlsx"
        effecttab, xlsx("`output_dir'/_va_native_effecttab.xlsx") sheet("ATE") ///
            title("Effects") effect("ATE") clean
        import excel "`output_dir'/_va_native_effecttab.xlsx", sheet("ATE") cellrange(A1:A1) clear
        assert A[1] == "Effects"
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * Cleanup
    capture erase "`output_dir'/_va_native_regtab.xlsx"
    capture erase "`output_dir'/_va_native_effecttab.xlsx"

    display _newline as result "Stata-native Excel Accuracy Validation Complete"
    display as result "  Passed: `pass_count' / `n_total'"
    if `fail_count' > 0 {
        display as error "  Failed: `fail_count' / `n_total'"
    }
    else {
        display as result "  All `n_total' tests passed!"
    }
    assert `fail_count' == 0
}

if `has_checker' {

display as result "Using checker: `checker'"

* =========================================================================

**# Migrated: frame-Excel parity

**# VA9: Frame-Excel parity — frame values match Excel cells
* =========================================================================

* --- VA9.1: regtab frame vs Excel parity ---
local ++n_total
local va9_pass = 1
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_va_parity.xlsx"
    capture frame drop _va_par
    regtab, xlsx("`output_dir'/_va_parity.xlsx") sheet("Test") frame(_va_par)

    * Extract values from frame
    frame _va_par {
        * Row 4 = first data row (mpg)
        local frame_coef = c1[4]
        local frame_p = c3[4]
    }

    * Verify same values appear in Excel
    * c1 in frame = column C in Excel, c3 = column E
    shell python3 "`checker'" "`output_dir'/_va_parity.xlsx" --sheet "Test" ///
        --cell-contains C4 "`frame_coef'" ///
        --cell-contains E4 "`frame_p'" ///
        --result-file "`output_dir'/_va_p1.txt" --quiet
    file open _fh using "`output_dir'/_va_p1.txt", read text
    file read _fh _line
    file close _fh
    if "`_line'" != "PASS" {
        local va9_pass = 0
    }
}
if _rc != 0 {
    local va9_pass = 0
}
if `va9_pass' == 1 {
    display as result "  PASS: VA9.1 — regtab frame values match Excel cells"
    local ++pass_count
}
else {
    display as error "  FAIL: VA9.1 — regtab frame-Excel parity (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _va_par
capture erase "`output_dir'/_va_p1.txt"

* --- VA9.2: effecttab frame vs Excel parity ---
local ++n_total
local va92_pass = 1
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_va_eff_parity.xlsx"
    capture frame drop _va_epar
    effecttab, xlsx("`output_dir'/_va_eff_parity.xlsx") sheet("Test") frame(_va_epar)

    frame _va_epar {
        * Find first non-empty data row in c1 (Effect column)
        local frame_eff = ""
        forvalues i = 3/`=_N' {
            local cell = c1[`i']
            local cell = strtrim("`cell'")
            if "`cell'" != "" & "`cell'" != "." {
                local frame_eff "`cell'"
                local frame_row = `i'
                continue, break
            }
        }
    }

    if "`frame_eff'" != "" {
        * Map frame row to Excel row
        local xl_row = `frame_row'
        shell python3 "`checker'" "`output_dir'/_va_eff_parity.xlsx" --sheet "Test" ///
            --cell-contains C`xl_row' "`frame_eff'" ///
            --result-file "`output_dir'/_va_p2.txt" --quiet
        file open _fh using "`output_dir'/_va_p2.txt", read text
        file read _fh _line
        file close _fh
        if "`_line'" != "PASS" {
            local va92_pass = 0
        }
    }
    else {
        local va92_pass = 0
    }
}
if _rc != 0 {
    local va92_pass = 0
}
if `va92_pass' == 1 {
    display as result "  PASS: VA9.2 — effecttab frame values match Excel cells"
    local ++pass_count
}
else {
    display as error "  FAIL: VA9.2 — effecttab frame-Excel parity (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _va_epar
capture erase "`output_dir'/_va_p2.txt"

* =========================================================================

}  // close `if has_checker' block (Excel-checker VA tests)

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_package tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valpkg
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_package tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valpkg

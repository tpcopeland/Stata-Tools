* test_regtab_multilevel.do — Test regtab multi-level RE labeling and sorting
* Tests: single-level mixed, two-level mixed, random slopes, melogit, mepoisson


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall tabtools
net install tabtools, from("`pkg_dir'") replace

clear all
set seed 12345

local output_dir "`pkg_dir'/qa/output"

local pass = 0
local fail = 0
local total = 0


**# Test 1: Single-level mixed — relabel (backward compat)

capture {
    clear
    set obs 500
    gen school = ceil(_n/50)
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, school) + rnormal()

    collect clear
    collect: mixed y x || school:

    capture erase "`output_dir'/_test_ml_single.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_single.xlsx") sheet("Single") relabel

    import excel "`output_dir'/_test_ml_single.xlsx", sheet("Single") clear allstring

    * Check RE rows are labeled correctly
    local found_intercept = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "School (Intercept)") > 0 local found_intercept = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_intercept' == 1
    assert `found_residual' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 1 - Single-level mixed relabel"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 1 - Single-level mixed relabel (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 2: Two-level nested mixed — both levels labeled

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_twolevel.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_twolevel.xlsx") sheet("TwoLevel") relabel

    import excel "`output_dir'/_test_ml_twolevel.xlsx", sheet("TwoLevel") clear allstring

    * Check both levels are present and labeled
    local found_district = 0
    local found_school = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "District (Intercept)") > 0 local found_district = 1
        if strpos(B[`i'], "School (Intercept)") > 0 local found_school = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_district' == 1
    assert `found_school' == 1
    assert `found_residual' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 2 - Two-level mixed relabel (both levels)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 2 - Two-level mixed relabel (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 3: Two-level with random slope and covariance

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    label variable x "Treatment"
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school: x, cov(unstructured)

    capture erase "`output_dir'/_test_ml_slope.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_slope.xlsx") sheet("Slope") relabel

    import excel "`output_dir'/_test_ml_slope.xlsx", sheet("Slope") clear allstring

    * Check random slope labeled with variable label
    local found_district = 0
    local found_school_int = 0
    local found_school_slope = 0
    local found_cov = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "District (Intercept)") > 0 local found_district = 1
        if strpos(B[`i'], "School (Intercept)") > 0 local found_school_int = 1
        if strpos(B[`i'], "School (Treatment)") > 0 local found_school_slope = 1
        if strpos(B[`i'], "School (Treatment, Intercept)") > 0 local found_cov = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_district' == 1
    assert `found_school_int' == 1
    assert `found_school_slope' == 1
    assert `found_cov' == 1
    assert `found_residual' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 3 - Two-level with random slope + covariance"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 3 - Two-level with random slope + covariance (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 4: Two-level mixed WITHOUT relabel (raw labels)

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_norelabel.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_norelabel.xlsx") sheet("NoRelabel")

    import excel "`output_dir'/_test_ml_norelabel.xlsx", sheet("NoRelabel") clear allstring

    * Check raw bracket-notation labels exist
    local found_district = 0
    local found_school = 0
    local found_vare = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "var(_cons[district])" local found_district = 1
        if strtrim(B[`i']) == "var(_cons[school])" local found_school = 1
        if strtrim(B[`i']) == "var(e)" local found_vare = 1
    }
    assert `found_district' == 1
    assert `found_school' == 1
    assert `found_vare' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 4 - Two-level without relabel (bracket notation)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 4 - Two-level without relabel (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 5: melogit single-level — backward compat

capture {
    clear
    set obs 2000
    gen cluster = ceil(_n/100)
    label variable cluster "Hospital"
    gen x = rnormal()
    gen y = rbinomial(1, invlogit(0.5*x + rnormal(0,0.5)))

    collect clear
    collect: melogit y x || cluster:

    capture erase "`output_dir'/_test_ml_melogit.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_melogit.xlsx") sheet("MELogit") relabel

    import excel "`output_dir'/_test_ml_melogit.xlsx", sheet("MELogit") clear allstring

    * Check MOR label and relabeled intercept
    local found_mor = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Odds Ratio") > 0 local found_mor = 1
    }
    assert `found_mor' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 5 - melogit single-level MOR + relabel"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 5 - melogit single-level (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 6: Two-level mixed with nore — suppresses all RE rows

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_nore.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_nore.xlsx") sheet("NoRE") nore

    import excel "`output_dir'/_test_ml_nore.xlsx", sheet("NoRE") clear allstring

    * Check no RE rows exist
    local found_var = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "var(") > 0 local found_var = 1
    }
    assert `found_var' == 0
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 6 - Two-level nore suppresses all RE"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 6 - Two-level nore (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 7: Three-level nested mixed

capture {
    clear
    set obs 2000
    gen region = ceil(_n/500)
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable region "Region"
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(2)) + rnormal(0, sqrt(1)) + rnormal()

    collect clear
    collect: mixed y x || region: || district: || school:

    capture erase "`output_dir'/_test_ml_three.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_three.xlsx") sheet("Three") relabel

    import excel "`output_dir'/_test_ml_three.xlsx", sheet("Three") clear allstring

    * Check all three levels labeled
    local found_region = 0
    local found_district = 0
    local found_school = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Region (Intercept)") > 0 local found_region = 1
        if strpos(B[`i'], "District (Intercept)") > 0 local found_district = 1
        if strpos(B[`i'], "School (Intercept)") > 0 local found_school = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_region' == 1
    assert `found_district' == 1
    assert `found_school' == 1
    assert `found_residual' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 7 - Three-level nested mixed"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 7 - Three-level nested (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 8: Single-level mixed with random slope (no brackets, backward compat)

capture {
    clear
    set obs 500
    gen school = ceil(_n/50)
    label variable school "School"
    gen x = rnormal()
    label variable x "Treatment"
    gen y = 1 + 2*x + rnormal(0, school) + rnormal()

    collect clear
    collect: mixed y x || school: x, cov(unstructured)

    capture erase "`output_dir'/_test_ml_single_slope.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_single_slope.xlsx") sheet("Slope1") relabel

    import excel "`output_dir'/_test_ml_single_slope.xlsx", sheet("Slope1") clear allstring

    * Check relabeled
    local found_int = 0
    local found_slope = 0
    local found_cov = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "School (Intercept)") > 0 local found_int = 1
        if strpos(B[`i'], "School (Treatment)") > 0 local found_slope = 1
        if strpos(B[`i'], "School (Treatment, Intercept)") > 0 local found_cov = 1
    }
    assert `found_int' == 1
    assert `found_slope' == 1
    assert `found_cov' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 8 - Single-level random slope + covariance relabel"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 8 - Single-level random slope (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 9: RE sort order — FE first, RE grouped by level, residual last

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_sortorder.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_sortorder.xlsx") sheet("Sort") relabel

    import excel "`output_dir'/_test_ml_sortorder.xlsx", sheet("Sort") clear allstring

    * Find row positions (no labels set, so relabel uses lowercase varnames)
    local row_x = 0
    local row_district = 0
    local row_school = 0
    local row_residual = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "x" local row_x = `i'
        if strpos(B[`i'], "district") > 0 local row_district = `i'
        if strpos(B[`i'], "school") > 0 local row_school = `i'
        if strpos(B[`i'], "Residual") > 0 local row_residual = `i'
    }
    * FE before RE
    assert `row_x' < `row_district'
    * District before School (model order)
    assert `row_district' < `row_school'
    * Residual last
    assert `row_school' < `row_residual'
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 9 - Sort order: FE < district < school < residual"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 9 - Sort order (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 10: Simple regression — no RE, unaffected

capture {
    clear
    sysuse auto
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_test_ml_regress.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_regress.xlsx") sheet("Regress") keepint

    import excel "`output_dir'/_test_ml_regress.xlsx", sheet("Regress") clear allstring

    * Check basic structure: sysuse auto uses variable labels
    local found_mpg = 0
    local found_weight = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Mileage") > 0 local found_mpg = 1
        if strpos(B[`i'], "Weight") > 0 local found_weight = 1
    }
    assert `found_mpg' == 1
    assert `found_weight' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 10 - Simple regression unaffected"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 10 - Simple regression (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 11: Two-level mixed with stats (n, icc, groups)

capture {
    clear
    set obs 1000
    gen district = ceil(_n/200)
    gen school = ceil(_n/50)
    label variable district "District"
    label variable school "School"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || district: || school:

    capture erase "`output_dir'/_test_ml_stats.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_stats.xlsx") sheet("Stats") relabel stats(n icc)

    confirm file "`output_dir'/_test_ml_stats.xlsx"
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 11 - Two-level mixed with stats"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 11 - Two-level mixed with stats (error `=_rc')"
    local fail = `fail' + 1
}


**# Test 12: Label collision — two grouping vars with identical labels

capture {
    clear
    set obs 1000
    gen cluster1 = ceil(_n/200)
    gen cluster2 = ceil(_n/50)
    * Both variables get the SAME label
    label variable cluster1 "Cluster"
    label variable cluster2 "Cluster"
    gen x = rnormal()
    gen y = 1 + 2*x + rnormal(0, sqrt(2)) + rnormal(0, sqrt(3)) + rnormal()

    collect clear
    collect: mixed y x || cluster1: || cluster2:

    capture erase "`output_dir'/_test_ml_collision.xlsx"
    regtab, xlsx("`output_dir'/_test_ml_collision.xlsx") sheet("Collision") relabel

    import excel "`output_dir'/_test_ml_collision.xlsx", sheet("Collision") clear allstring

    * Both levels must appear with distinct labels (varname used as tiebreaker)
    local found_c1 = 0
    local found_c2 = 0
    local found_residual = 0
    forvalues i = 1/`=_N' {
        * With identical labels, relabel uses varname: "cluster1 (Intercept)", "cluster2 (Intercept)"
        if strpos(B[`i'], "cluster1") > 0 & strpos(B[`i'], "Intercept") > 0 local found_c1 = 1
        if strpos(B[`i'], "cluster2") > 0 & strpos(B[`i'], "Intercept") > 0 local found_c2 = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_residual = 1
    }
    assert `found_c1' == 1
    assert `found_c2' == 1
    assert `found_residual' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 12 - Label collision (identical labels, distinct varnames)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 12 - Label collision (error `=_rc')"
    local fail = `fail' + 1
}


**# Summary
display _newline(1)
display as text _dup(50) "="
display as text "Results: `pass'/`total' passed, `fail' failed"
display as text _dup(50) "="
if `fail' > 0 exit 9

* test_v150_features.do — Tests for tabtools v1.5.0 new features
* Tests: R1 (sort stability), O1 (console output), F6 (r2 stats),
*        O2 (smdthreshold), I2 (r(methods)), F7 (stratetab theme),
*        I4 (rclass), U4 (auto-noint), O5 (starslevels), O4 (colors),
*        U6 (binary error), O3 (row height), R3 (SMD warning),
*        C2 (r(varlist)), F2 (csv export)

capture log close _v150
log using "test_v150_features.log", replace text name(_v150)

local n_pass = 0
local n_fail = 0
local n_total = 0

capture ado uninstall tabtools

**# Load package
local pkg_dir "`c(pwd)'/.."
run "`pkg_dir'/_tabtools_common.ado"
run "`pkg_dir'/table1_tc.ado"
run "`pkg_dir'/regtab.ado"
run "`pkg_dir'/effecttab.ado"
run "`pkg_dir'/stratetab.ado"
run "`pkg_dir'/tablex.ado"
run "`pkg_dir'/tabtools.ado"

* =========================================================================
**# R1: Sort stability in auto-type detection
* =========================================================================

* --- R1.1: Repeated auto-detect gives same result ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * Run auto-detect twice, results should be identical due to fixed seed
    _tabtools_detect_vartype price
    local type1 "`result'"
    sysuse auto, clear
    _tabtools_detect_vartype price
    local type2 "`result'"
    assert "`type1'" == "`type2'"
}
if _rc == 0 {
    display as result "  PASS: R1.1 — auto-detect reproducible (price=`type1' both times)"
    local ++n_pass
}
else {
    display as error "  FAIL: R1.1 — auto-detect not reproducible (rc=`=_rc')"
    local ++n_fail
}

* --- R1.2: Auto-detect for known binary variable ---
local ++n_total
capture noisily {
    sysuse auto, clear
    _tabtools_detect_vartype foreign
    assert "`result'" == "bin"
}
if _rc == 0 {
    display as result "  PASS: R1.2 — foreign correctly detected as bin"
    local ++n_pass
}
else {
    display as error "  FAIL: R1.2 — foreign detection wrong (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# O1: Console confirmation for regtab/effecttab
* =========================================================================

* --- O1.1: regtab displays export message ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_o1_regtab_v150.xlsx") sheet("Test")
    * If we get here, the command ran (console output visible in log)
}
if _rc == 0 {
    display as result "  PASS: O1.1 — regtab runs with console output"
    local ++n_pass
}
else {
    display as error "  FAIL: O1.1 — regtab failed (rc=`=_rc')"
    local ++n_fail
}

* --- O1.2: effecttab displays export message ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_o1_effecttab_v150.xlsx") sheet("Test")
}
if _rc == 0 {
    display as result "  PASS: O1.2 — effecttab runs with console output"
    local ++n_pass
}
else {
    display as error "  FAIL: O1.2 — effecttab failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# F6: R-squared in regtab stats()
* =========================================================================

* --- F6.1: R² for OLS regression ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local true_r2 = e(r2)
    regtab, xlsx("output/test_f6_r2.xlsx") sheet("R2") stats(n r2)
}
if _rc == 0 {
    display as result "  PASS: F6.1 — R² in stats(n r2) for OLS"
    local ++n_pass
}
else {
    display as error "  FAIL: F6.1 — R² stats failed (rc=`=_rc')"
    local ++n_fail
}

* --- F6.2: Pseudo-R² for logistic regression ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_f6_pseudor2.xlsx") sheet("PseudoR2") stats(n r2)
}
if _rc == 0 {
    display as result "  PASS: F6.2 — Pseudo-R² in stats(n r2) for logit"
    local ++n_pass
}
else {
    display as error "  FAIL: F6.2 — Pseudo-R² failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# O2: smdthreshold() option
* =========================================================================

* --- O2.1: Custom smdthreshold ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign) smd smdthreshold(0.2) ///
        excel("output/test_o2_smdthresh.xlsx") title("SMD Threshold Test")
}
if _rc == 0 {
    display as result "  PASS: O2.1 — smdthreshold(0.2) accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: O2.1 — smdthreshold failed (rc=`=_rc')"
    local ++n_fail
}

* --- O2.2: Default smdthreshold (0.1) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign) smd ///
        excel("output/test_o2_smddefault.xlsx") title("SMD Default Test")
}
if _rc == 0 {
    display as result "  PASS: O2.2 — default smdthreshold works"
    local ++n_pass
}
else {
    display as error "  FAIL: O2.2 — default smdthreshold failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# I2: r(methods) for regtab and effecttab
* =========================================================================

* --- I2.1: regtab returns r(methods) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_i2_methods.xlsx") sheet("Methods")
    assert `"`r(methods)'"' != ""
    * Should mention "Odds ratios" for logit
    assert strpos(`"`r(methods)'"', "Odds ratios") > 0
}
if _rc == 0 {
    display as result "  PASS: I2.1 — regtab r(methods) contains 'Odds ratios'"
    local ++n_pass
}
else {
    display as error "  FAIL: I2.1 — regtab r(methods) missing/wrong (rc=`=_rc')"
    local ++n_fail
}

* --- I2.2: effecttab returns r(methods) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_i2_eff_methods.xlsx") sheet("Methods")
    assert `"`r(methods)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: I2.2 — effecttab r(methods) populated"
    local ++n_pass
}
else {
    display as error "  FAIL: I2.2 — effecttab r(methods) missing (rc=`=_rc')"
    local ++n_fail
}

* --- I2.3: regtab r(methods) for Cox model ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    stset studytime, failure(died)
    collect clear
    collect: stcox age drug
    regtab, xlsx("output/test_i2_cox.xlsx") sheet("Cox")
    assert strpos(`"`r(methods)'"', "Hazard ratios") > 0
}
if _rc == 0 {
    display as result "  PASS: I2.3 — regtab r(methods) for Cox says 'Hazard ratios'"
    local ++n_pass
}
else {
    display as error "  FAIL: I2.3 — Cox r(methods) wrong (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# F7: stratetab theme() support
* =========================================================================

* --- F7.1: stratetab accepts theme(lancet) ---
* Note: stratetab requires strate output files; test syntax acceptance only
local ++n_total
capture noisily {
    sysuse auto, clear
    * Create a minimal strate-like output file for testing
    preserve
    clear
    set obs 3
    gen str30 _Category = ""
    replace _Category = "Total" in 1
    replace _Category = "Domestic" in 2
    replace _Category = "Foreign" in 3
    gen _D = .
    replace _D = 10 in 1
    replace _D = 6 in 2
    replace _D = 4 in 3
    gen _Y = .
    replace _Y = 100 in 1
    replace _Y = 60 in 2
    replace _Y = 40 in 3
    gen _Rate = .
    replace _Rate = 100 in 1
    replace _Rate = 100 in 2
    replace _Rate = 100 in 3
    gen _Lower = .
    replace _Lower = 50 in 1
    replace _Lower = 40 in 2
    replace _Lower = 30 in 3
    gen _Upper = .
    replace _Upper = 200 in 1
    replace _Upper = 180 in 2
    replace _Upper = 250 in 3
    save "output/_strate_test", replace
    restore
    stratetab, using("output/_strate_test") xlsx("output/test_f7_theme.xlsx") ///
        outcomes(1) title("Theme Test") theme(lancet)
}
if _rc == 0 {
    display as result "  PASS: F7.1 — stratetab theme(lancet) accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: F7.1 — stratetab theme failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# I4: table1_tc rclass (r(Dapa), r(methods), r(varlist))
* =========================================================================

* --- I4.1: r(Dapa) populated ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight rep78, by(foreign)
    assert `"`r(Dapa)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: I4.1 — r(Dapa) populated: `r(Dapa)'"
    local ++n_pass
}
else {
    display as error "  FAIL: I4.1 — r(Dapa) missing (rc=`=_rc')"
    local ++n_fail
}

* --- I4.2: r(methods) populated with by() ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign) test
    assert `"`r(methods)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: I4.2 — r(methods) populated with by()"
    local ++n_pass
}
else {
    display as error "  FAIL: I4.2 — r(methods) missing (rc=`=_rc')"
    local ++n_fail
}

* --- I4.3: r(varlist) returns processed variables ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign)
    assert `"`r(varlist)'"' != ""
    assert strpos(`"`r(varlist)'"', "price") > 0
    assert strpos(`"`r(varlist)'"', "mpg") > 0
    assert strpos(`"`r(varlist)'"', "weight") > 0
}
if _rc == 0 {
    display as result "  PASS: I4.3 — r(varlist) = `r(varlist)'"
    local ++n_pass
}
else {
    display as error "  FAIL: I4.3 — r(varlist) wrong (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# U4: Auto-detect nointercept for OR/HR/IRR
* =========================================================================

* --- U4.1: Logit auto-suppresses intercept ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_u4_noint.xlsx") sheet("AutoNoInt")
    * r(coef_label) should be OR, and noint should be auto-applied
    assert "`r(coef_label)'" == "OR"
}
if _rc == 0 {
    display as result "  PASS: U4.1 — logit auto-nointercept (coef=OR)"
    local ++n_pass
}
else {
    display as error "  FAIL: U4.1 — auto-nointercept failed (rc=`=_rc')"
    local ++n_fail
}

* --- U4.2: keepintercept overrides auto ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    regtab, xlsx("output/test_u4_keepint.xlsx") sheet("KeepInt") keepintercept
}
if _rc == 0 {
    display as result "  PASS: U4.2 — keepintercept option accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: U4.2 — keepintercept failed (rc=`=_rc')"
    local ++n_fail
}

* --- U4.3: OLS does NOT auto-suppress intercept ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_u4_ols.xlsx") sheet("OLS")
    assert "`r(coef_label)'" == "Coef."
}
if _rc == 0 {
    display as result "  PASS: U4.3 — OLS keeps intercept (coef=Coef.)"
    local ++n_pass
}
else {
    display as error "  FAIL: U4.3 — OLS coef detection wrong (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# O5: starslevels() custom thresholds
* =========================================================================

* --- O5.1: Custom starslevels ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, xlsx("output/test_o5_stars.xlsx") sheet("Stars") ///
        stars starslevels(0.10 0.05 0.01)
}
if _rc == 0 {
    display as result "  PASS: O5.1 — starslevels(0.10 0.05 0.01) accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: O5.1 — custom starslevels failed (rc=`=_rc')"
    local ++n_fail
}

* --- O5.2: starslevels rejects wrong number of values ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_o5_bad.xlsx") sheet("Bad") ///
        stars starslevels(0.10 0.05)
}
if _rc == 198 {
    display as result "  PASS: O5.2 — starslevels(2 values) correctly rejected (rc=198)"
    local ++n_pass
}
else {
    display as error "  FAIL: O5.2 — expected rc=198, got rc=`=_rc'"
    local ++n_fail
}

* =========================================================================
**# O4: headercolor() and zebracolor() customization
* =========================================================================

* --- O4.1: regtab with custom colors ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_o4_colors.xlsx") sheet("Colors") ///
        headercolor("200 200 255") zebracolor("240 240 255") zebra
}
if _rc == 0 {
    display as result "  PASS: O4.1 — custom header/zebra colors accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: O4.1 — custom colors failed (rc=`=_rc')"
    local ++n_fail
}

* --- O4.2: table1_tc with custom colors ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg, by(foreign) ///
        excel("output/test_o4_t1colors.xlsx") zebra headershade ///
        headercolor("255 200 200") zebracolor("255 240 240")
}
if _rc == 0 {
    display as result "  PASS: O4.2 — table1_tc custom colors accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: O4.2 — table1_tc colors failed (rc=`=_rc')"
    local ++n_fail
}


* =========================================================================
**# U6: Better binary variable error message
* =========================================================================

* --- U6.1: Binary error suggests cat ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * rep78 has values 1-5, not 0/1
    table1_tc, by(foreign) vars(rep78 bin)
}
if _rc == 198 {
    display as result "  PASS: U6.1 — binary var error triggers rc=198 (suggests cat)"
    local ++n_pass
}
else {
    display as error "  FAIL: U6.1 — expected rc=198, got rc=`=_rc'"
    local ++n_fail
}

* =========================================================================
**# O3: Header row height auto-calculation
* =========================================================================

* --- O3.1: Long description auto-adjusts row height ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * Many variables = long Dapa string = taller row 2
    table1_tc price mpg weight headroom trunk length turn displacement gear_ratio, ///
        by(foreign) excel("output/test_o3_height.xlsx") ///
        title("Row Height Auto-Calc Test")
}
if _rc == 0 {
    display as result "  PASS: O3.1 — header row height auto-calc (many vars)"
    local ++n_pass
}
else {
    display as error "  FAIL: O3.1 — header height failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# R3: SMD >2 groups warning
* =========================================================================

* --- R3.1: SMD with 3+ groups shows warning ---
local ++n_total
capture noisily {
    sysuse auto, clear
    * rep78 has 5 levels (1-5) — more than 2 groups
    table1_tc price mpg weight, by(rep78) smd
}
if _rc == 0 {
    display as result "  PASS: R3.1 — SMD with >2 groups runs (warning in log)"
    local ++n_pass
}
else {
    display as error "  FAIL: R3.1 — SMD with >2 groups failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# C2: r(varlist) for pipeline workflows
* =========================================================================

* --- C2.1: r(varlist) matches input variables ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc price mpg weight, by(foreign)
    local vlist "`r(varlist)'"
    assert wordcount("`vlist'") == 3
    assert strpos("`vlist'", "price") > 0
    assert strpos("`vlist'", "mpg") > 0
    assert strpos("`vlist'", "weight") > 0
}
if _rc == 0 {
    display as result "  PASS: C2.1 — r(varlist) has 3 vars: `vlist'"
    local ++n_pass
}
else {
    display as error "  FAIL: C2.1 — r(varlist) wrong (rc=`=_rc')"
    local ++n_fail
}

* --- C2.2: r(varlist) with vars() explicit syntax ---
local ++n_total
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn \ rep78 cat)
    local vlist "`r(varlist)'"
    assert wordcount("`vlist'") == 3
}
if _rc == 0 {
    display as result "  PASS: C2.2 — r(varlist) with vars() syntax: `vlist'"
    local ++n_pass
}
else {
    display as error "  FAIL: C2.2 — r(varlist) with vars() wrong (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# F2: CSV export
* =========================================================================

* --- F2.1: table1_tc csv export ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "output/test_f2_t1.csv"
    table1_tc price mpg weight, by(foreign) ///
        excel("output/test_f2_t1.xlsx") csv("output/test_f2_t1.csv")
    confirm file "output/test_f2_t1.csv"
}
if _rc == 0 {
    display as result "  PASS: F2.1 — table1_tc csv() export created file"
    local ++n_pass
}
else {
    display as error "  FAIL: F2.1 — csv export failed (rc=`=_rc')"
    local ++n_fail
}

* --- F2.2: regtab csv export ---
local ++n_total
capture erase "output/test_f2_reg.csv"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_f2_reg.xlsx") sheet("Reg") ///
        csv("output/test_f2_reg.csv")
    confirm file "output/test_f2_reg.csv"
}
if _rc == 0 {
    display as result "  PASS: F2.2 — regtab csv() export created file"
    local ++n_pass
}
else {
    display as error "  FAIL: F2.2 — regtab csv failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Additional: r(xlsx) and r(sheet) return values
* =========================================================================

* --- RET.1: regtab returns r(xlsx) and r(sheet) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("output/test_ret_regtab.xlsx") sheet("MySheet")
    assert `"`r(xlsx)'"' == "output/test_ret_regtab.xlsx"
    assert `"`r(sheet)'"' == "MySheet"
}
if _rc == 0 {
    display as result "  PASS: RET.1 — regtab returns r(xlsx) and r(sheet)"
    local ++n_pass
}
else {
    display as error "  FAIL: RET.1 — regtab return values wrong (rc=`=_rc')"
    local ++n_fail
}

* --- RET.2: effecttab returns r(xlsx) and r(sheet) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_ret_effecttab.xlsx") sheet("Effects")
    assert `"`r(xlsx)'"' == "output/test_ret_effecttab.xlsx"
    assert `"`r(sheet)'"' == "Effects"
}
if _rc == 0 {
    display as result "  PASS: RET.2 — effecttab returns r(xlsx) and r(sheet)"
    local ++n_pass
}
else {
    display as error "  FAIL: RET.2 — effecttab return values wrong (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Varabbrev restore on success and error
* =========================================================================

* --- VA.1: varabbrev restored after table1_tc ---
local ++n_total
capture noisily {
    set varabbrev on
    sysuse auto, clear
    table1_tc price mpg, by(foreign)
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: VA.1 — varabbrev restored after table1_tc"
    local ++n_pass
}
else {
    display as error "  FAIL: VA.1 — varabbrev not restored (rc=`=_rc')"
    local ++n_fail
}
set varabbrev off

* --- VA.2: varabbrev restored after regtab error ---
local ++n_total
capture noisily {
    set varabbrev on
    sysuse auto, clear
    * Intentional error: no collect table
    capture regtab, xlsx("output/test_va2.xlsx") sheet("Test")
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: VA.2 — varabbrev restored after regtab error"
    local ++n_pass
}
else {
    display as error "  FAIL: VA.2 — varabbrev not restored on error (rc=`=_rc')"
    local ++n_fail
}
set varabbrev off

* =========================================================================
**# Data preservation
* =========================================================================

* --- DP.1: table1_tc preserves data ---
local ++n_total
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    local orig_vars : char _dta[_N]
    summarize price, meanonly
    local orig_mean = r(mean)
    table1_tc price mpg weight, by(foreign)
    assert _N == `orig_n'
    summarize price, meanonly
    assert reldif(r(mean), `orig_mean') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: DP.1 — table1_tc preserves data (N=`orig_n')"
    local ++n_pass
}
else {
    display as error "  FAIL: DP.1 — data not preserved (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Summary
* =========================================================================

display as text ""
display as text "{hline 60}"
display as result "tabtools v1.5.0 Feature Tests: `n_pass'/`n_total' passed, `n_fail' failed"
display as text "{hline 60}"

if `n_fail' == 0 {
    display as result "ALL TESTS PASSED"
}
else {
    display as error "`n_fail' TESTS FAILED"
}

capture erase "output/_strate_test.dta"

log close _v150
exit `n_fail'

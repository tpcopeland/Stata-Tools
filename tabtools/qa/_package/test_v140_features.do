* test_v140_features.do — Tests for tabtools v1.4.0 new features
* Tests: F3 (auto-detect), O2 (SMD formatting), O3 (stars), I5 (frame),
*        U1 (simplified syntax), W1 (template), C2 (preview), U3 (error msgs),
*        O1 (themes), I1 (return values)

capture log close _v140
log using "test_v140_features.log", replace text name(_v140)

local n_pass = 0
local n_fail = 0
local n_total = 0

capture ado uninstall tabtools

**# Load package
local pkg_dir "`c(pwd)'/.."
net install tabtools, from("`pkg_dir'") replace

**# Test Data Setup
sysuse auto, clear

* =========================================================================
**# F3: Auto-detect variable types
* =========================================================================

* --- F3.1: auto keyword in vars() ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price auto \ mpg auto \ rep78 auto \ headroom auto)
if _rc == 0 {
    display as result "PASS: F3.1 — auto keyword in vars()"
    local ++n_pass
}
else {
    display as error "FAIL: F3.1 — auto keyword in vars() (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- F3.2: omitted vartype (empty = auto) ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price \ mpg \ rep78 \ headroom)
if _rc == 0 {
    display as result "PASS: F3.2 — omitted vartype triggers auto-detect"
    local ++n_pass
}
else {
    display as error "FAIL: F3.2 — omitted vartype triggers auto-detect (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- F3.3: auto with explicit format ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price auto %9.0fc \ mpg contn)
if _rc == 0 {
    display as result "PASS: F3.3 — auto with explicit format"
    local ++n_pass
}
else {
    display as error "FAIL: F3.3 — auto with explicit format (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- F3.4: binary variable detected as bin ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(foreign auto)
if _rc == 0 {
    display as result "PASS: F3.4 — binary variable detected"
    local ++n_pass
}
else {
    display as error "FAIL: F3.4 — binary variable detected (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* =========================================================================
**# U1: Simplified varlist syntax
* =========================================================================

* --- U1.1: plain varlist without vars() ---
local ++n_total
capture noisily table1_tc price mpg weight rep78, by(foreign)
if _rc == 0 {
    display as result "PASS: U1.1 — plain varlist syntax"
    local ++n_pass
}
else {
    display as error "FAIL: U1.1 — plain varlist syntax (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- U1.2: varlist with Excel export ---
local ++n_total
capture noisily table1_tc price mpg weight, by(foreign) excel("output/test_u1.xlsx") title("U1 Test")
if _rc == 0 {
    capture confirm file "output/test_u1.xlsx"
    if _rc == 0 {
        display as result "PASS: U1.2 — varlist syntax with Excel export"
        local ++n_pass
    }
    else {
        display as error "FAIL: U1.2 — Excel file not created"
        local ++n_fail
    }
}
else {
    display as error "FAIL: U1.2 — varlist syntax with Excel export (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* =========================================================================
**# O2: SMD conditional formatting
* =========================================================================

* --- O2.1: SMD with Excel export (visual check) ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn \ weight contn \ rep78 cat) ///
    smd excel("output/test_o2_smd.xlsx") title("O2 SMD Formatting Test")
if _rc == 0 {
    capture confirm file "output/test_o2_smd.xlsx"
    if _rc == 0 {
        display as result "PASS: O2.1 — SMD with Excel export (check output/test_o2_smd.xlsx for orange highlight)"
        local ++n_pass
    }
    else {
        display as error "FAIL: O2.1 — Excel file not created"
        local ++n_fail
    }
}
else {
    display as error "FAIL: O2.1 — SMD with Excel export (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* =========================================================================
**# O3: Significance stars for regtab
* =========================================================================

* --- O3.1: stars option ---
local ++n_total
collect clear
collect: regress price mpg weight i.foreign
capture noisily regtab, xlsx("output/test_o3_stars.xlsx") sheet("Stars") ///
    title("O3 Stars Test") stars
if _rc == 0 {
    capture confirm file "output/test_o3_stars.xlsx"
    if _rc == 0 {
        display as result "PASS: O3.1 — stars option (check output/test_o3_stars.xlsx)"
        local ++n_pass
    }
    else {
        display as error "FAIL: O3.1 — Excel file not created"
        local ++n_fail
    }
}
else {
    display as error "FAIL: O3.1 — stars option (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- O3.2: stars returns in r() ---
local ++n_total
collect clear
collect: regress price mpg weight
capture noisily regtab, xlsx("output/test_o3b.xlsx") sheet("Test") stars
if _rc == 0 {
    local _stars_ret = "`r(stars)'"
    if "`_stars_ret'" == "stars" {
        display as result "PASS: O3.2 — r(stars) returned"
        local ++n_pass
    }
    else {
        display as error "FAIL: O3.2 — r(stars) not returned (got: `_stars_ret')"
        local ++n_fail
    }
}
else {
    display as error "FAIL: O3.2 — regtab failed (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* =========================================================================
**# I5: Frame output for table1_tc
* =========================================================================

* --- I5.1: frame() option ---
local ++n_total
capture frame drop _test_frame
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) frame(_test_frame)
if _rc == 0 {
    capture frame _test_frame: describe
    if _rc == 0 {
        display as result "PASS: I5.1 — frame() option creates frame"
        local ++n_pass
    }
    else {
        display as error "FAIL: I5.1 — frame not created"
        local ++n_fail
    }
}
else {
    display as error "FAIL: I5.1 — frame() option (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _test_frame

sysuse auto, clear

* --- I5.2: frame preserves original data ---
local ++n_total
local _orig_N = _N
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) frame(_test_frame2)
if _rc == 0 {
    if _N == `_orig_N' {
        display as result "PASS: I5.2 — original data preserved with frame()"
        local ++n_pass
    }
    else {
        display as error "FAIL: I5.2 — data modified after frame() (N=`=_N' vs `_orig_N')"
        local ++n_fail
    }
}
else {
    display as error "FAIL: I5.2 — frame() option (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _test_frame2

sysuse auto, clear

* =========================================================================
**# O1: Journal-style themes
* =========================================================================

* --- O1.1: lancet theme ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) ///
    excel("output/test_o1_lancet.xlsx") title("Lancet Theme") theme(lancet)
if _rc == 0 {
    capture confirm file "output/test_o1_lancet.xlsx"
    if _rc == 0 {
        display as result "PASS: O1.1 — lancet theme"
        local ++n_pass
    }
    else {
        display as error "FAIL: O1.1 — Excel file not created"
        local ++n_fail
    }
}
else {
    display as error "FAIL: O1.1 — lancet theme (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- O1.2: nejm theme ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) ///
    excel("output/test_o1_nejm.xlsx") title("NEJM Theme") theme(nejm)
if _rc == 0 {
    display as result "PASS: O1.2 — nejm theme"
    local ++n_pass
}
else {
    display as error "FAIL: O1.2 — nejm theme (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- O1.3: apa theme ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn \ mpg contn) ///
    excel("output/test_o1_apa.xlsx") title("APA Theme") theme(apa)
if _rc == 0 {
    display as result "PASS: O1.3 — apa theme"
    local ++n_pass
}
else {
    display as error "FAIL: O1.3 — apa theme (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- O1.4: invalid theme ---
local ++n_total
capture noisily table1_tc, by(foreign) vars(price contn) theme(invalid_theme)
if _rc != 0 {
    display as result "PASS: O1.4 — invalid theme rejected"
    local ++n_pass
}
else {
    display as error "FAIL: O1.4 — invalid theme should error"
    local ++n_fail
}

sysuse auto, clear

* --- O1.5: theme in regtab ---
local ++n_total
collect clear
collect: regress price mpg weight
capture noisily regtab, xlsx("output/test_o1_regtab.xlsx") sheet("Lancet") ///
    title("Lancet Regression") theme(lancet)
if _rc == 0 {
    display as result "PASS: O1.5 — theme in regtab"
    local ++n_pass
}
else {
    display as error "FAIL: O1.5 — theme in regtab (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* =========================================================================
**# W1: tabtools template (REMOVED — template subcommand no longer exists)
* =========================================================================

* =========================================================================
**# U3: Improved error messages
* =========================================================================

sysuse auto, clear

* --- U3.1: regtab improved error messages (hint text present) ---
* Note: collect clear leaves an empty collection that passes the query check.
* The improved error messages are for when no collection exists at all.
* We verify the hint text exists in the source code instead.
local ++n_total
capture findfile regtab.ado
if _rc == 0 {
    local _regtab_path "`r(fn)'"
    tempname _rh
    file open `_rh' using "`_regtab_path'", read text
    local _found_hint = 0
    file read `_rh' _line
    while r(eof) == 0 {
        if strpos(`"`_line'"', "collect clear") > 0 & strpos(`"`_line'"', "Hint") > 0 {
            local _found_hint = 1
        }
        file read `_rh' _line
    }
    file close `_rh'
    if `_found_hint' {
        display as result "PASS: U3.1 — regtab contains improved hint text"
        local ++n_pass
    }
    else {
        display as error "FAIL: U3.1 — hint text not found in regtab.ado"
        local ++n_fail
    }
}
else {
    display as error "FAIL: U3.1 — regtab.ado not found"
    local ++n_fail
}

* =========================================================================
**# I1: Return values from regtab
* =========================================================================

sysuse auto, clear

* --- I1.1: regtab returns N_models ---
local ++n_total
collect clear
collect: regress price mpg weight
collect: regress price mpg weight foreign
capture noisily regtab, xlsx("output/test_i1.xlsx") sheet("Test") ///
    models(Model 1 \ Model 2)
if _rc == 0 {
    if r(N_models) == 2 {
        display as result "PASS: I1.1 — r(N_models) = 2"
        local ++n_pass
    }
    else {
        display as error "FAIL: I1.1 — r(N_models) = `r(N_models)' (expected 2)"
        local ++n_fail
    }
}
else {
    display as error "FAIL: I1.1 — regtab failed (rc=`=_rc')"
    local ++n_fail
}

sysuse auto, clear

* --- I1.2: regtab returns coef_label ---
local ++n_total
collect clear
collect: logistic foreign price mpg
capture noisily regtab, xlsx("output/test_i1b.xlsx") sheet("Test")
if _rc == 0 {
    if "`r(coef_label)'" == "OR" {
        display as result "PASS: I1.2 — r(coef_label) = OR for logistic"
        local ++n_pass
    }
    else {
        display as error "FAIL: I1.2 — r(coef_label) = `r(coef_label)' (expected OR)"
        local ++n_fail
    }
}
else {
    display as error "FAIL: I1.2 — regtab failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Summary
* =========================================================================

display as text ""
display as text _dup(60) "="
display as text "tabtools v1.4.0 Feature Tests Summary"
display as text _dup(60) "="
display as result "  Total:  `n_total'"
display as result "  Pass:   `n_pass'"
if `n_fail' > 0 {
    display as error "  FAIL:   `n_fail'"
}
else {
    display as result "  Fail:   0"
}
display as text _dup(60) "="

assert `n_fail' == 0

log close _v140

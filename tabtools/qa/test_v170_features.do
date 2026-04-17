* test_v170_features.do — Tests for tabtools v1.7.0 new features
* Coverage:
*   F4: regtab compact mode (estimate+CI merged)
*   F5: survtab events option (Events/N row)
*   F1: digits() for crosstab, survtab, diagtab, corrtab
*   W1/W2: Persistent digits/boldp via tabtools set
*   U2: frame(name, replace) for all 10 frame-capable commands
*   O5: refcat() for regtab
*   I3: addrow() for effecttab, survtab
*   O1: pdp()/highpdp() for regtab, effecttab, survtab

capture log close _v170
log using "test_v170_features.log", replace text name(_v170)

local n_pass = 0
local n_fail = 0
local n_total = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

* Ensure persistent defaults are clean
tabtools set clear

* =========================================================================
**# F4: regtab compact mode
* =========================================================================

* --- F4.1: compact merges estimate+CI into one column ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _f4_1
    regtab, frame(_f4_1) compact
    * In compact mode: title, A, c1 (est+CI), c2 (p) = 4 vars
    * Normal mode would have: title, A, c1 (est), c2 (CI), c3 (p) = 5 vars
    frame _f4_1 {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
    }
}
if _rc == 0 {
    display as result "  PASS: F4.1 — compact mode produces 2 data columns (est+CI, p)"
    local ++n_pass
}
else {
    display as error "  FAIL: F4.1 — compact mode column count wrong (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f4_1

* --- F4.2: compact mode cell contains both estimate and CI ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _f4_2
    regtab, frame(_f4_2) compact
    frame _f4_2 {
        * Rows 1-3 are title/header; row 4+ are data rows
        local cell = c1[4]
        assert strpos("`cell'", "(") > 0
        assert strpos("`cell'", ")") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: F4.2 — compact cell contains estimate and CI"
    local ++n_pass
}
else {
    display as error "  FAIL: F4.2 — compact cell format wrong (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f4_2

* --- F4.3: compact mode with multi-model ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    capture frame drop _f4_3
    regtab, frame(_f4_3) compact models("Model 1 \ Model 2")
    frame _f4_3 {
        quietly ds c*
        local ncvars : word count `r(varlist)'
        * 2 models * 2 cols each = 4 c-columns
        assert `ncvars' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: F4.3 — compact mode with 2 models produces 4 data columns"
    local ++n_pass
}
else {
    display as error "  FAIL: F4.3 — compact multi-model column count wrong (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f4_3

* --- F4.4: compact mode Excel export ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/test_v170_compact.xlsx"
    regtab, xlsx("output/test_v170_compact.xlsx") sheet("Test") compact
    confirm file "output/test_v170_compact.xlsx"
}
if _rc == 0 {
    display as result "  PASS: F4.4 — compact mode Excel export succeeds"
    local ++n_pass
}
else {
    display as error "  FAIL: F4.4 — compact mode Excel export failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# F5: survtab events option
* =========================================================================

* --- F5.1: events option adds Events/N row ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _f5_1
    survtab, times(10 20 30) by(drug) events frame(_f5_1)
    frame _f5_1 {
        * Check that Events / N row exists
        gen byte _has_events = strpos(c1, "Events / N") > 0
        summarize _has_events, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F5.1 — survtab events option produces Events/N row"
    local ++n_pass
}
else {
    display as error "  FAIL: F5.1 — survtab events option failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f5_1

* --- F5.2: events return values ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) events
    * Should have events_1, atrisk_1, etc.
    assert r(events_1) > 0
    assert r(atrisk_1) > 0
    assert r(events_1) <= r(atrisk_1)
}
if _rc == 0 {
    display as result "  PASS: F5.2 — survtab events returns events/atrisk scalars"
    local ++n_pass
}
else {
    display as error "  FAIL: F5.2 — survtab events return values failed (rc=`=_rc')"
    local ++n_fail
}

* --- F5.3: events content is correct ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    * Count expected events and N for drug==1
    qui count if drug == 1 & _st & _d == 1
    local expected_events = r(N)
    qui count if drug == 1 & _st
    local expected_n = r(N)
    survtab, times(10 20 30) by(drug) events
    assert r(events_1) == `expected_events'
    assert r(atrisk_1) == `expected_n'
}
if _rc == 0 {
    display as result "  PASS: F5.3 — survtab events counts are correct"
    local ++n_pass
}
else {
    display as error "  FAIL: F5.3 — survtab events counts incorrect (rc=`=_rc')"
    local ++n_fail
}

* --- F5.4: events without by() ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) events
    assert r(events_1) > 0
    assert r(atrisk_1) > 0
}
if _rc == 0 {
    display as result "  PASS: F5.4 — survtab events works without by()"
    local ++n_pass
}
else {
    display as error "  FAIL: F5.4 — survtab events without by() failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# F1: digits() for crosstab, survtab, diagtab, corrtab
* =========================================================================

* --- F1.1: crosstab digits(3) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _f1_1
    crosstab foreign rep78, colpct digits(3) frame(_f1_1)
    frame _f1_1 {
        * Find a cell with a percentage — should have 3 decimal places
        local cell = c2[3]
        * Cell format: "N (XX.XXX%)" — check 3 digits after decimal
        local pct_part = substr("`cell'", strpos("`cell'", "(") + 1, .)
        local dot_pos = strpos("`pct_part'", ".")
        local pct_end = strpos("`pct_part'", "%")
        local n_decimals = `pct_end' - `dot_pos' - 1
        assert `n_decimals' == 3
    }
}
if _rc == 0 {
    display as result "  PASS: F1.1 — crosstab digits(3) formats percentages correctly"
    local ++n_pass
}
else {
    display as error "  FAIL: F1.1 — crosstab digits(3) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f1_1

* --- F1.2: survtab digits(2) ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _f1_2
    survtab, times(10 20) by(drug) digits(2) frame(_f1_2)
    frame _f1_2 {
        * Find a survival percentage row (contains %)
        gen byte _haspct = strpos(c2, "%") > 0
        summarize _haspct, meanonly
        assert r(max) == 1
        * Check a percentage cell has 2 decimals
        local found = 0
        forvalues i = 1/`=_N' {
            local cell = c2[`i']
            if strpos("`cell'", "%") > 0 {
                local dot_pos = strpos("`cell'", ".")
                local pct_pos = strpos("`cell'", "%")
                if `dot_pos' > 0 {
                    local n_dec = `pct_pos' - `dot_pos' - 1
                    assert `n_dec' == 2
                    local found = 1
                    continue, break
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F1.2 — survtab digits(2) formats percentages correctly"
    local ++n_pass
}
else {
    display as error "  FAIL: F1.2 — survtab digits(2) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f1_2

* --- F1.3: diagtab digits(3) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highprice = price > 6000
    gen byte bigcar = weight > 3000
    capture frame drop _f1_3
    diagtab highprice bigcar, digits(3) frame(_f1_3)
    frame _f1_3 {
        * Find Sensitivity row — value should have 3 decimal places
        local found = 0
        forvalues i = 1/`=_N' {
            local label = c1[`i']
            if strtrim("`label'") == "Sensitivity" {
                local val = c2[`i']
                local dot_pos = strpos("`val'", ".")
                local pct_pos = strpos("`val'", "%")
                if `dot_pos' > 0 & `pct_pos' > 0 {
                    local n_dec = `pct_pos' - `dot_pos' - 1
                    assert `n_dec' == 3
                    local found = 1
                }
                continue, break
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F1.3 — diagtab digits(3) formats correctly"
    local ++n_pass
}
else {
    display as error "  FAIL: F1.3 — diagtab digits(3) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f1_3

* --- F1.4: corrtab digits(4) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _f1_4
    corrtab price mpg weight, digits(4) frame(_f1_4)
    frame _f1_4 {
        * Off-diagonal cells have actual correlations; row 4 is first off-diag in c2
        local cell = c2[4]
        local dot_pos = strpos("`cell'", ".")
        assert `dot_pos' > 0
        local after_dot = substr("`cell'", `dot_pos' + 1, .)
        * Strip trailing stars and whitespace
        local after_dot : subinstr local after_dot "*" "", all
        local after_dot = strtrim("`after_dot'")
        local n_dec = strlen("`after_dot'")
        assert `n_dec' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: F1.4 — corrtab digits(4) formats correctly"
    local ++n_pass
}
else {
    display as error "  FAIL: F1.4 — corrtab digits(4) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _f1_4

* --- F1.5: digits validation (out of range) ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10) digits(7)
}
if _rc != 0 {
    display as result "  PASS: F1.5 — digits(7) correctly rejected for survtab"
    local ++n_pass
}
else {
    display as error "  FAIL: F1.5 — digits(7) should have been rejected"
    local ++n_fail
}

* =========================================================================
**# W1/W2: Persistent digits/boldp via tabtools set
* =========================================================================

* --- W1.1: tabtools set digits ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 3
    tabtools get
    assert r(digits) == "3"
}
if _rc == 0 {
    display as result "  PASS: W1.1 — tabtools set digits 3 stores correctly"
    local ++n_pass
}
else {
    display as error "  FAIL: W1.1 — tabtools set digits failed (rc=`=_rc')"
    local ++n_fail
}

* --- W1.2: persistent digits applies to regtab ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 4
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _w1_2
    regtab, frame(_w1_2)
    frame _w1_2 {
        * Row 4 is first data row (rows 1-3 are title/headers)
        local cell = c1[4]
        local dot_pos = strpos("`cell'", ".")
        assert `dot_pos' > 0
        local after = substr("`cell'", `dot_pos' + 1, .)
        local n_dec = strlen(strtrim("`after'"))
        assert `n_dec' == 4
    }
}
if _rc == 0 {
    display as result "  PASS: W1.2 — persistent digits(4) applies to regtab"
    local ++n_pass
}
else {
    display as error "  FAIL: W1.2 — persistent digits for regtab failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _w1_2
tabtools set clear

* --- W1.3: local digits() overrides persistent ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 4
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _w1_3
    regtab, frame(_w1_3) digits(1)
    frame _w1_3 {
        * Row 4 is first data row
        local cell = c1[4]
        local dot_pos = strpos("`cell'", ".")
        assert `dot_pos' > 0
        local after = substr("`cell'", `dot_pos' + 1, .)
        local n_dec = strlen(strtrim("`after'"))
        assert `n_dec' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: W1.3 — local digits(1) overrides persistent digits(4)"
    local ++n_pass
}
else {
    display as error "  FAIL: W1.3 — digits override failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _w1_3
tabtools set clear

* --- W2.1: tabtools set boldp ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set boldp 0.05
    tabtools get
    assert r(boldp) == "0.05"
}
if _rc == 0 {
    display as result "  PASS: W2.1 — tabtools set boldp 0.05 stores correctly"
    local ++n_pass
}
else {
    display as error "  FAIL: W2.1 — tabtools set boldp failed (rc=`=_rc')"
    local ++n_fail
}

* --- W2.2: tabtools set boldp validation (out of range) ---
local ++n_total
capture noisily {
    tabtools set boldp 1.5
}
if _rc != 0 {
    display as result "  PASS: W2.2 — boldp 1.5 correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: W2.2 — boldp 1.5 should have been rejected"
    local ++n_fail
}

* --- W2.3: tabtools set boldp validation (zero) ---
local ++n_total
capture noisily {
    tabtools set boldp 0
}
if _rc != 0 {
    display as result "  PASS: W2.3 — boldp 0 correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: W2.3 — boldp 0 should have been rejected"
    local ++n_fail
}

* --- W2.4: tabtools set digits validation (non-integer) ---
local ++n_total
capture noisily {
    tabtools set digits 2.5
}
if _rc != 0 {
    display as result "  PASS: W2.4 — digits 2.5 correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: W2.4 — digits 2.5 should have been rejected"
    local ++n_fail
}

* --- W2.5: tabtools set digits validation (out of range) ---
local ++n_total
capture noisily {
    tabtools set digits 7
}
if _rc != 0 {
    display as result "  PASS: W2.5 — digits 7 correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: W2.5 — digits 7 should have been rejected"
    local ++n_fail
}

* --- W2.6: tabtools set clear clears digits and boldp ---
local ++n_total
capture noisily {
    tabtools set digits 3
    tabtools set boldp 0.05
    tabtools set clear
    tabtools get
    assert `"`r(digits)'"' == ""
    assert `"`r(boldp)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: W2.6 — set clear clears digits and boldp"
    local ++n_pass
}
else {
    display as error "  FAIL: W2.6 — set clear did not clear digits/boldp (rc=`=_rc')"
    local ++n_fail
}
tabtools set clear

* =========================================================================
**# U2: frame(name, replace) for all frame-capable commands
* =========================================================================

* --- U2.1: frame(name, replace) for regtab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _u2_1
    regtab, frame(_u2_1)
    * Now call again with replace — should succeed
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, frame(_u2_1, replace)
    frame _u2_1: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.1 — regtab frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.1 — regtab frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_1

* --- U2.3: frame(name, replace) for effecttab ---
local ++n_total
capture noisily {
    capture frame drop _u2_3
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, frame(_u2_3)
    * Replace — reload data because effecttab uses preserve/restore
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, frame(_u2_3, replace)
    frame _u2_3: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.3 — effecttab frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.3 — effecttab frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_3

* --- U2.2: frame without replace errors on existing ---
* NOTE: placed after U2.3 because the intentional error leaves stale preserve
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _u2_2
    regtab, frame(_u2_2)
    * Call again without replace — should error
    collect clear
    collect: regress price mpg weight
    regtab, frame(_u2_2)
}
if _rc != 0 {
    display as result "  PASS: U2.2 — frame without replace errors on existing frame"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.2 — should have errored on existing frame"
    local ++n_fail
}
capture frame drop _u2_2
capture restore

* --- U2.4: frame(name, replace) for survtab ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _u2_4
    survtab, times(10 20) by(drug) frame(_u2_4)
    survtab, times(10 20) by(drug) frame(_u2_4, replace)
    frame _u2_4: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.4 — survtab frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.4 — survtab frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_4

* --- U2.5: frame(name, replace) for crosstab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _u2_5
    crosstab foreign rep78, frame(_u2_5)
    crosstab foreign rep78, colpct frame(_u2_5, replace)
    frame _u2_5: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.5 — crosstab frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.5 — crosstab frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_5

* --- U2.6: frame(name, replace) for corrtab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _u2_6
    corrtab price mpg weight, frame(_u2_6)
    corrtab price mpg weight, spearman frame(_u2_6, replace)
    frame _u2_6: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.6 — corrtab frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.6 — corrtab frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_6

* --- U2.7: frame(name, replace) for diagtab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highprice = price > 6000
    gen byte bigcar = weight > 3000
    capture frame drop _u2_7
    diagtab highprice bigcar, frame(_u2_7)
    diagtab highprice bigcar, frame(_u2_7, replace)
    frame _u2_7: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.7 — diagtab frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.7 — diagtab frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_7

* --- U2.8: frame(name, replace) for fittab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    estimates clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight i.foreign
    estimates store m2
    capture frame drop _u2_8
    fittab m1 m2, frame(_u2_8)
    fittab m1 m2, frame(_u2_8, replace)
    frame _u2_8: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.8 — fittab frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.8 — fittab frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_8
estimates clear

* --- U2.9: frame(name, replace) for table1_tc ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _u2_9
    table1_tc, vars(price conts \ mpg conts \ weight conts) frame(_u2_9)
    table1_tc, vars(price conts \ mpg conts) frame(_u2_9, replace)
    frame _u2_9: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: U2.9 — table1_tc frame(name, replace) works"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.9 — table1_tc frame(name, replace) failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _u2_9

* --- U2.10: frame invalid sub-option rejected ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _u2_10
    regtab, frame(_u2_10, append)
}
if _rc != 0 {
    display as result "  PASS: U2.10 — frame(name, append) correctly rejected"
    local ++n_pass
}
else {
    display as error "  FAIL: U2.10 — frame(name, append) should have been rejected"
    local ++n_fail
}
capture frame drop _u2_10

* =========================================================================
**# O5: refcat() for regtab
* =========================================================================

* --- O5.1: refcat changes reference label ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _o5_1
    regtab, frame(_o5_1) refcat("Ref.")
    frame _o5_1 {
        gen byte _has_ref = strpos(c1, "Ref.") > 0
        summarize _has_ref, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: O5.1 — refcat(Ref.) changes reference label"
    local ++n_pass
}
else {
    display as error "  FAIL: O5.1 — refcat() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _o5_1

* --- O5.2: default refcat is "Reference" ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _o5_2
    regtab, frame(_o5_2)
    frame _o5_2 {
        gen byte _has_ref = strpos(c1, "Reference") > 0
        summarize _has_ref, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: O5.2 — default refcat is 'Reference'"
    local ++n_pass
}
else {
    display as error "  FAIL: O5.2 — default refcat check failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _o5_2

* =========================================================================
**# I3: addrow() for effecttab and survtab
* =========================================================================

* --- I3.1: effecttab addrow ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture frame drop _i3_1
    effecttab, frame(_i3_1) addrow("P interaction" 0.034)
    frame _i3_1 {
        gen byte _has_pint = strpos(A, "P interaction") > 0
        summarize _has_pint, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: I3.1 — effecttab addrow() adds custom row"
    local ++n_pass
}
else {
    display as error "  FAIL: I3.1 — effecttab addrow() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _i3_1

* --- I3.2: survtab addrow ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _i3_2
    survtab, times(10 20) by(drug) frame(_i3_2) addrow("P trend" 0.012 0.045 0.089)
    frame _i3_2 {
        gen byte _has_ptrend = strpos(c1, "P trend") > 0
        summarize _has_ptrend, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: I3.2 — survtab addrow() adds custom row"
    local ++n_pass
}
else {
    display as error "  FAIL: I3.2 — survtab addrow() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _i3_2

* --- I3.3: regtab addrow with multiple rows (backslash separator) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _i3_3
    regtab, frame(_i3_3) addrow("P trend" 0.012 \ "P interaction" 0.045)
    frame _i3_3 {
        gen byte _has_ptrend = strpos(A, "P trend") > 0
        gen byte _has_pint = strpos(A, "P interaction") > 0
        summarize _has_ptrend, meanonly
        assert r(max) == 1
        summarize _has_pint, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: I3.3 — regtab addrow() with multiple rows via backslash"
    local ++n_pass
}
else {
    display as error "  FAIL: I3.3 — regtab multi addrow() failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _i3_3

* --- I3.4: effecttab addrow with Excel export ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "output/test_v170_addrow.xlsx"
    effecttab, xlsx("output/test_v170_addrow.xlsx") sheet("Test") ///
        addrow("P interaction" 0.034)
    confirm file "output/test_v170_addrow.xlsx"
}
if _rc == 0 {
    display as result "  PASS: I3.4 — effecttab addrow with Excel export"
    local ++n_pass
}
else {
    display as error "  FAIL: I3.4 — effecttab addrow Excel failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# O1: pdp()/highpdp() for regtab, effecttab, survtab
* =========================================================================

* --- O1.1: regtab pdp(4) produces 4-decimal p-values for small p ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _o1_1
    regtab, frame(_o1_1) pdp(4) highpdp(3)
    frame _o1_1 {
        * p-value column is c3; data rows start at row 4
        local found = 0
        forvalues i = 4/`=_N' {
            local cell = c3[`i']
            if "`cell'" != "" & "`cell'" != "." {
                if substr("`cell'", 1, 1) != "<" {
                    local dot_pos = strpos("`cell'", ".")
                    if `dot_pos' > 0 {
                        local after = substr("`cell'", `dot_pos' + 1, .)
                        local n_dec = strlen(strtrim("`after'"))
                        * Should be either pdp(4) or highpdp(3)
                        assert `n_dec' == 4 | `n_dec' == 3
                        local found = 1
                    }
                }
                else {
                    * "<0.0001" format — pdp(4) means 4 decimal places
                    assert strpos("`cell'", "0.0001") > 0
                    local found = 1
                }
                continue, break
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: O1.1 — regtab pdp(4)/highpdp(3) formats p-values"
    local ++n_pass
}
else {
    display as error "  FAIL: O1.1 — regtab pdp/highpdp failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _o1_1

* --- O1.2: effecttab pdp(4) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, pdp(4) highpdp(2)
}
if _rc == 0 {
    display as result "  PASS: O1.2 — effecttab pdp(4)/highpdp(2) accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: O1.2 — effecttab pdp/highpdp failed (rc=`=_rc')"
    local ++n_fail
}

* --- O1.3: survtab pdp(4) ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20) by(drug) pdp(4) highpdp(2)
}
if _rc == 0 {
    display as result "  PASS: O1.3 — survtab pdp(4)/highpdp(2) accepted"
    local ++n_pass
}
else {
    display as error "  FAIL: O1.3 — survtab pdp/highpdp failed (rc=`=_rc')"
    local ++n_fail
}

* --- O1.4: pdp default is 3 (verify <0.001 format) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _o1_4
    regtab, frame(_o1_4)
    * Default pdp=3 means threshold is 0.001
    * We just verify the command runs with defaults
    frame _o1_4: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: O1.4 — regtab default pdp/highpdp works"
    local ++n_pass
}
else {
    display as error "  FAIL: O1.4 — regtab default pdp/highpdp failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _o1_4

* =========================================================================
**# Combined feature interaction tests
* =========================================================================

* --- COMBO.1: compact + refcat ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _combo1
    regtab, frame(_combo1) compact refcat("--")
    frame _combo1 {
        * Verify compact (2 c-columns per model)
        quietly ds c*
        local ncvars : word count `r(varlist)'
        assert `ncvars' == 2
        * Verify refcat
        gen byte _has_ref = strpos(c1, "--") > 0
        summarize _has_ref, meanonly
        assert r(max) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: COMBO.1 — compact + refcat together"
    local ++n_pass
}
else {
    display as error "  FAIL: COMBO.1 — compact + refcat failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _combo1

* --- COMBO.2: persistent digits + events + frame(replace) ---
local ++n_total
capture noisily {
    tabtools set clear
    tabtools set digits 3
    sysuse cancer, clear
    stset studytime, failure(died)
    capture frame drop _combo2
    survtab, times(10 20) by(drug) events frame(_combo2)
    * Replace frame
    survtab, times(10 20 30) by(drug) events frame(_combo2, replace)
    frame _combo2: assert _N > 0
    assert r(events_1) > 0
}
if _rc == 0 {
    display as result "  PASS: COMBO.2 — persistent digits + events + frame(replace)"
    local ++n_pass
}
else {
    display as error "  FAIL: COMBO.2 — combo test failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _combo2
tabtools set clear

* --- COMBO.3: compact + addrow + Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/test_v170_combo3.xlsx"
    regtab, xlsx("output/test_v170_combo3.xlsx") sheet("Test") ///
        compact addrow("P trend" 0.034)
    confirm file "output/test_v170_combo3.xlsx"
}
if _rc == 0 {
    display as result "  PASS: COMBO.3 — compact + addrow + Excel export"
    local ++n_pass
}
else {
    display as error "  FAIL: COMBO.3 — compact + addrow + Excel failed (rc=`=_rc')"
    local ++n_fail
}

* --- COMBO.4: pdp + boldp + compact ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "output/test_v170_combo4.xlsx"
    regtab, xlsx("output/test_v170_combo4.xlsx") sheet("Test") ///
        compact boldp(0.05) pdp(4) highpdp(2)
    confirm file "output/test_v170_combo4.xlsx"
}
if _rc == 0 {
    display as result "  PASS: COMBO.4 — pdp + boldp + compact + Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: COMBO.4 — pdp + boldp + compact + Excel failed (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Data preservation
* =========================================================================

* --- DP.1: regtab compact preserves user data ---
local ++n_total
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    local orig_vars : char _dta[__ReportVars]
    collect clear
    collect: regress price mpg weight
    regtab, compact
    assert _N == `orig_n'
    confirm variable price mpg weight foreign
}
if _rc == 0 {
    display as result "  PASS: DP.1 — regtab compact preserves user data"
    local ++n_pass
}
else {
    display as error "  FAIL: DP.1 — user data changed after compact regtab (rc=`=_rc')"
    local ++n_fail
}

* --- DP.2: survtab events preserves user data ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local orig_n = _N
    survtab, times(10 20) by(drug) events
    assert _N == `orig_n'
    confirm variable studytime died drug
}
if _rc == 0 {
    display as result "  PASS: DP.2 — survtab events preserves user data"
    local ++n_pass
}
else {
    display as error "  FAIL: DP.2 — user data changed after survtab events (rc=`=_rc')"
    local ++n_fail
}

* =========================================================================
**# Summary
* =========================================================================

display as text ""
display as text "{hline 60}"
display as text "v1.7.0 Feature Tests Complete"
display as text "{hline 60}"
display as result "  Passed: `n_pass' / `n_total'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail' / `n_total'"
}
else {
    display as result "  All tests passed!"
}
display as text "{hline 60}"

assert `n_fail' == 0

log close _v170

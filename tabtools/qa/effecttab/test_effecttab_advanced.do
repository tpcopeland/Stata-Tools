* Advanced effecttab tests: from() matrix, multi-model, edge cases
clear all
set more off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local n_pass = 0
local n_fail = 0

* ============================================================
* Test 1: from() matrix path (should be unaffected by IPTW changes)
* ============================================================
sysuse auto, clear
matrix mymat = (1.5, 0.8, 2.2, 0.04 \ 2.3, 1.1, 3.5, 0.001 \ -0.5, -1.2, 0.2, 0.15)
matrix rownames mymat = Age Sex BMI

capture noisily {
    effecttab, from(mymat) display title("From Matrix Test") effect("OR")
    assert r(N_rows) > 0
    * from() with no prior teffects defaults to margins type
    assert r(type) == "margins"
    assert strpos(lower(`"`r(methods)'"'), "supplied matrix") > 0
}
if _rc == 0 {
    display as result "PASS: T1 — from() matrix works"
    local ++n_pass
}
else {
    display as error "FAIL: T1 — from() matrix failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 2: from() matrix with Excel export
* ============================================================
capture noisily {
    effecttab, from(mymat) xlsx("/tmp/test_from_matrix.xlsx") sheet("Matrix") ///
        title("Matrix Results") effect("OR") digits(2)
    confirm file "/tmp/test_from_matrix.xlsx"
}
if _rc == 0 {
    display as result "PASS: T2 — from() matrix Excel export works"
    local ++n_pass
}
	else {
	    display as error "FAIL: T2 — from() matrix Excel export failed (rc=`=_rc')"
	    local ++n_fail
	}

	**# Test 2a: from() matrix CI strings do not contain fixed-width double spaces
	capture frame drop eff_ci_from
	capture noisily {
	    matrix cimat = (0.10, -0.01, 0.02, 0.20 \ 0.35, 0.34, 0.36, 0.001)
	    matrix rownames cimat = NearZero Tight
	    effecttab, from(cimat) frame(eff_ci_from, replace) display digits(2)
	    frame eff_ci_from {
	        ds, has(type string)
	        local string_vars `r(varlist)'
	        foreach v of varlist `string_vars' {
	            quietly count if strpos(`v', ",  ") > 0 ///
	                & strpos(`v', "(") > 0 & strpos(`v', ")") > 0
	            assert r(N) == 0
	        }
	    }
	}
	if _rc == 0 {
	    display as result "PASS: T2a — from() CI strings are normalized"
	    local ++n_pass
	}
	else {
	    display as error "FAIL: T2a — from() CI strings contain double spaces (rc=`=_rc')"
	    local ++n_fail
	}
	capture frame drop eff_ci_from
	capture matrix drop cimat

	**# Test 2c: final missing workbook guard returns rc=601
	capture noisily {
	    local final_missing "/tmp/test_from_matrix_final_missing.xlsx"
	    capture erase "`final_missing'"
	    global TABTOOLS_QA_EFFECTTAB_ERASE_XLSX "`final_missing'"
	    capture noisily effecttab, from(mymat) xlsx("`final_missing'") sheet("Missing") ///
	        title("Final Missing Guard") effect("OR")
	    local got_rc = _rc
	    global TABTOOLS_QA_EFFECTTAB_ERASE_XLSX
	    capture confirm file "`final_missing'"
	    assert `got_rc' == 601
	    assert _rc == 601
	}
	if _rc == 0 {
	    display as result "PASS: T2c — final missing workbook guard returns rc=601"
	    local ++n_pass
	}
	else {
	    global TABTOOLS_QA_EFFECTTAB_ERASE_XLSX
	    display as error "FAIL: T2c — final missing workbook guard did not return rc=601 (rc=`=_rc')"
	    local ++n_fail
	}

	* ============================================================
	* Test 2b: invalid from() matrix preserves user data on error
* ============================================================
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    local orig_price = price[1]
    matrix shortmat = (1.5, 0.8, 2.2 \ 2.3, 1.1, 3.5)
    capture noisily effecttab, from(shortmat) display
    assert _rc == 198
    assert _N == `orig_n'
    assert price[1] == `orig_price'
}
if _rc == 0 {
    display as result "PASS: T2b — invalid from() matrix restores user data"
    local ++n_pass
}
else {
    display as error "FAIL: T2b — invalid from() matrix leaked user data (rc=`=_rc')"
    local ++n_fail
}
capture matrix drop shortmat

* ============================================================
* Test 3: Multi-model effecttab (two teffects collected)
* ============================================================
webuse cattaneo2, clear
label define smokelbl 0 "Non-smoker" 1 "Smoker"
label values mbsmoke smokelbl

capture noisily {
    collect clear
    collect: teffects ra (bweight mage prenatal1 mmarried fbaby) (mbsmoke), ate
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, display title("Multi-Model") effect("ATE") ///
        models("RA \ IPW") clean
    assert r(N_rows) > 0
    assert strpos(lower(`"`r(methods)'"'), "multiple collected models") > 0
    assert strpos(lower(`"`r(methods)'"'), "inverse probability weighting") == 0
    assert strpos(lower(`"`r(methods)'"'), "regression adjustment") == 0
}
if _rc == 0 {
    display as result "PASS: T3 — multi-model effecttab works"
    local ++n_pass
}
else {
    display as error "FAIL: T3 — multi-model effecttab failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 3b: single-model methods use collect metadata, not ambient e()
* ============================================================
capture noisily {
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    quietly teffects ra (bweight mage prenatal1 mmarried fbaby) (mbsmoke), ate
    effecttab, display effect("ATE")
    assert strpos(lower(`"`r(methods)'"'), "inverse probability weighting") > 0
    assert strpos(lower(`"`r(methods)'"'), "regression adjustment") == 0
}
if _rc == 0 {
    display as result "PASS: T3b — single-model methods ignore ambient e()"
    local ++n_pass
}
else {
    display as error "FAIL: T3b — single-model methods reused ambient e() (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 4: effecttab with psmatch
* ============================================================
capture noisily {
    collect clear
    collect: teffects psmatch (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, display title("PSMatch") effect("ATE")
    local _nrows = r(N_rows)
    * Should be filtered (no PS model coefficients)
    assert `_nrows' <= 8
}
if _rc == 0 {
    display as result "PASS: T4 — psmatch effecttab filtered (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T4 — psmatch effecttab failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 5: effecttab with nnmatch
* ============================================================
capture noisily {
    collect clear
    collect: teffects nnmatch (bweight mage prenatal1 mmarried fbaby) (mbsmoke), ate nneighbor(1)
    effecttab, display title("NNMatch") effect("ATE")
    local _nrows = r(N_rows)
    assert `_nrows' <= 8
}
if _rc == 0 {
    display as result "PASS: T5 — nnmatch effecttab filtered (`_nrows' rows)"
    local ++n_pass
}
else {
    display as error "FAIL: T5 — nnmatch effecttab failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 6: effecttab with addrow()
* ============================================================
capture noisily {
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, display title("IPTW + AddRow") effect("ATE") clean ///
        addrow("N" 4642)
    assert r(N_rows) > 5
}
if _rc == 0 {
    display as result "PASS: T6 — addrow() with IPTW works"
    local ++n_pass
}
else {
    display as error "FAIL: T6 — addrow() with IPTW failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 7: effecttab frame() + display combined
* ============================================================
capture frame drop _eff_frame
capture noisily {
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, display title("IPTW Frame") effect("ATE") clean frame(_eff_frame)
    assert r(frame) == "_eff_frame"
    frame _eff_frame: assert _N > 0
}
if _rc == 0 {
    display as result "PASS: T7 — frame() + display with IPTW works"
    local ++n_pass
}
else {
    display as error "FAIL: T7 — frame() + display with IPTW failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _eff_frame

* ============================================================
* Test 7b: collect CI strings do not contain fixed-width double spaces
* ============================================================
capture frame drop eff_ci_collect
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, frame(eff_ci_collect, replace) effect("ATE") clean display digits(2)
    frame eff_ci_collect {
        ds, has(type string)
        local string_vars `r(varlist)'
        foreach v of varlist `string_vars' {
            quietly count if strpos(`v', ",  ") > 0 ///
                & strpos(`v', "(") > 0 & strpos(`v', ")") > 0
            assert r(N) == 0
        }
    }
}
if _rc == 0 {
    display as result "PASS: T7b — collect CI strings are normalized"
    local ++n_pass
}
else {
    display as error "FAIL: T7b — collect CI strings contain double spaces (rc=`=_rc')"
    local ++n_fail
}
capture frame drop eff_ci_collect

* ============================================================
* Test 7c: collect CI bounds honor digits()
* ============================================================
capture frame drop eff_ci_digits_collect
capture noisily {
    sysuse auto, clear
    gen byte high_price = price > 5000
    quietly logit high_price c.mpg
    collect clear
    collect: margins, dydx(mpg)
    effecttab, frame(eff_ci_digits_collect, replace) effect("AME") display digits(4)
    frame eff_ci_digits_collect {
        local _found_ci = 0
        forvalues _r = 3/`=_N' {
            local _ci = strtrim(c2[`_r'])
            if "`_ci'" != "" & strpos("`_ci'", "(") == 1 & strpos("`_ci'", ", ") > 0 {
                local _body = substr("`_ci'", 2, strlen("`_ci'") - 2)
                local _split = strpos("`_body'", ", ")
                local _lo = strtrim(substr("`_body'", 1, `_split' - 1))
                local _hi = strtrim(substr("`_body'", `_split' + 2, .))
                local _lopos = strpos("`_lo'", ".")
                local _hipos = strpos("`_hi'", ".")
                assert `_lopos' > 0
                assert `_hipos' > 0
                assert strlen(substr("`_lo'", `_lopos' + 1, .)) == 4
                assert strlen(substr("`_hi'", `_hipos' + 1, .)) == 4
                local _found_ci = 1
                continue, break
            }
        }
        assert `_found_ci' == 1
    }
}
if _rc == 0 {
    display as result "PASS: T7c — collect CI bounds honor digits()"
    local ++n_pass
}
else {
    display as error "FAIL: T7c — collect CI bounds ignore digits() (rc=`=_rc')"
    local ++n_fail
}
capture frame drop eff_ci_digits_collect
quietly webuse cattaneo2, clear

* ============================================================
* Test 8: effecttab CSV export
* ============================================================
capture noisily {
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    capture frame drop _eff_csv
    capture erase "/tmp/test_iptw.csv"
    effecttab, csv("/tmp/test_iptw.csv") title("IPTW CSV") effect("ATE") clean ///
        frame(_eff_csv, replace)
    confirm file "/tmp/test_iptw.csv"
    assert r(frame) == "_eff_csv"
    frame _eff_csv {
        local _csv_found = 0
        forvalues _r = 1/`=_N' {
            local _lbl = strtrim(A[`_r'])
            local _est = strtrim(c1[`_r'])
            local _p = strtrim(c3[`_r'])
            if "`_lbl'" != "" & "`_est'" != "" {
                local _frame_label "`_lbl'"
                local _frame_est "`_est'"
                local _frame_p "`_p'"
                local _csv_found = 1
                continue, break
            }
        }
        assert `_csv_found' == 1
    }
    preserve
    import delimited "/tmp/test_iptw.csv", clear varnames(1)
    local _csv_match = 0
    forvalues _r = 1/`=_N' {
        local _lbl = strtrim(a[`_r'])
        if "`_lbl'" == "`_frame_label'" {
            assert strtrim(c1[`_r']) == "`_frame_est'"
            assert strtrim(c3[`_r']) == "`_frame_p'"
            local _csv_match = 1
            continue, break
        }
    }
    assert `_csv_match' == 1
    restore
}
if _rc == 0 {
    display as result "PASS: T8 — CSV export with IPTW works"
    local ++n_pass
}
else {
    display as error "FAIL: T8 — CSV export with IPTW failed (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _eff_csv

* ============================================================
* Test 9: effecttab r(table) matrix correctness
* ============================================================
capture noisily {
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, display title("IPTW r(table)") effect("ATE") clean
    matrix list r(table)
    * r(table) should have estimate and p-value columns
    local _ncols = colsof(r(table))
    assert `_ncols' == 2
    * Row 1 may be a section header (missing); row 2 has the ATE value
    local _nrtable = rowsof(r(table))
    assert `_nrtable' >= 2
}
if _rc == 0 {
    display as result "PASS: T9 — r(table) matrix correct for IPTW"
    local ++n_pass
}
else {
    display as error "FAIL: T9 — r(table) matrix wrong for IPTW (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 10: Data preservation after effecttab
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    local orig_n = _N
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, display effect("ATE")
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "PASS: T10 — data preserved after effecttab"
    local ++n_pass
}
else {
    display as error "FAIL: T10 — data not preserved (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 11: effecttab with footnote
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, xlsx("/tmp/test_iptw_footnote.xlsx") sheet("Foot") ///
        title("IPTW Effect") ///
        footnote("Source: Cattaneo 2010") effect("ATE")
    confirm file "/tmp/test_iptw_footnote.xlsx"
}
if _rc == 0 {
    display as result "PASS: T11 — footnote with IPTW works"
    local ++n_pass
}
else {
    display as error "FAIL: T11 — footnote failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 12: effecttab with theme
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, xlsx("/tmp/test_iptw_theme.xlsx") sheet("Lancet") ///
        title("IPTW Lancet") effect("ATE") theme(lancet)
    confirm file "/tmp/test_iptw_theme.xlsx"
}
if _rc == 0 {
    display as result "PASS: T12 — theme with IPTW works"
    local ++n_pass
}
else {
    display as error "FAIL: T12 — theme with IPTW failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 13: effecttab with boldp + highlight
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    effecttab, xlsx("/tmp/test_iptw_boldp.xlsx") sheet("Bold") ///
        title("IPTW Bold") effect("ATE") boldp(0.05) highlight(0.01)
    confirm file "/tmp/test_iptw_boldp.xlsx"
}
if _rc == 0 {
    display as result "PASS: T13 — boldp + highlight with IPTW works"
    local ++n_pass
}
else {
    display as error "FAIL: T13 — boldp + highlight failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 14: margins dydx (should be unaffected by IPTW changes)
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    gen byte low_bw = bweight < 2500
    logit low_bw i.mbsmoke mage prenatal1 mmarried fbaby
    collect clear
    collect: margins, dydx(mbsmoke)
    effecttab, display title("AME") effect("AME")
    assert r(type) == "margins"
    assert r(N_rows) >= 4
}
if _rc == 0 {
    display as result "PASS: T14 — margins dydx works"
    local ++n_pass
}
else {
    display as error "FAIL: T14 — margins dydx failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 15: margins at() (should be unaffected)
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    gen byte low_bw = bweight < 2500
    logit low_bw i.mbsmoke mage prenatal1 mmarried fbaby
    collect clear
    collect: margins, at(mage=(20 25 30 35 40))
    effecttab, display title("Predicted at ages") effect("Pr(Y)")
    assert r(N_rows) >= 7
}
if _rc == 0 {
    display as result "PASS: T15 — margins at() works"
    local ++n_pass
}
else {
    display as error "FAIL: T15 — margins at() failed (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 16: ATE value in frame matches direct teffects r(table)
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    matrix _te = r(table)
    local _ref_ate = _te[1,1]
    local _ref_pval = _te[4,1]

    effecttab, frame(eff_adv, replace) effect("ATE") clean display

    * c1 contains the estimate, A contains the row label
    frame eff_adv {
        local _found = 0
        forvalues _r = 1/`=_N' {
            local _val = real(strtrim(c1[`_r']))
            if !missing(`_val') {
                * First numeric c1 value is the ATE
                assert abs(`_val' - round(`_ref_ate', 0.01)) < 0.015
                local _found = 1
                continue, break
            }
        }
        assert `_found' == 1
    }
    capture frame drop eff_adv
}
if _rc == 0 {
    display as result "PASS: T16 — ATE frame value matches direct teffects"
    local ++n_pass
}
else {
    display as error "FAIL: T16 — ATE value mismatch (rc=`=_rc')"
    local ++n_fail
    capture frame drop eff_adv
}

* ============================================================
* Test 17: helper bundle reloads after a partial helper drop
* ============================================================
capture noisily {
    matrix helpermat = (1.5, 0.8, 2.2, 0.04)
    matrix rownames helpermat = Helper
    effecttab, from(helpermat) display
    capture program drop _tabtools_validate_sheet
    effecttab, from(helpermat) display
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "PASS: T17 — helper bundle reloads after partial drop"
    local ++n_pass
}
else {
    display as error "FAIL: T17 — helper reload failed (rc=`=_rc')"
    local ++n_fail
}
capture matrix drop helpermat

* ============================================================
* Test 18: from() ignores ambient collect state
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    matrix stalecheck = (1.5, 0.8, 2.2, 1e-7)
    matrix rownames stalecheck = MatrixOnly
    effecttab, from(stalecheck) display
    assert r(type) == "margins"
}
if _rc == 0 {
    display as result "PASS: T18 — from() stays isolated from ambient teffects state"
    local ++n_pass
}
else {
    display as error "FAIL: T18 — from() inherited ambient teffects state (rc=`=_rc')"
    local ++n_fail
}
capture matrix drop stalecheck

* ============================================================
* Test 19: tiny matrix p-values survive until final formatting
* ============================================================
capture frame drop eff_small
capture noisily {
    matrix smallmat = (1.5, 0.8, 2.2, 1e-7)
    matrix rownames smallmat = TinyP
    effecttab, from(smallmat) frame(eff_small, replace) display
    frame eff_small {
        local found = 0
        forvalues _r = 1/`=_N' {
            local _p = strtrim(c3[`_r'])
            if "`_p'" != "" & "`_p'" != "p" {
                assert "`_p'" == "<0.001"
                local found = 1
                continue, break
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "PASS: T19 — tiny matrix p-values format correctly"
    local ++n_pass
}
else {
    display as error "FAIL: T19 — tiny matrix p-values lost (rc=`=_rc')"
    local ++n_fail
}
capture frame drop eff_small
capture matrix drop smallmat

* ============================================================
* Test 20: invalid pdp()/highpdp() are rejected
* ============================================================
capture noisily {
    matrix precmat = (1.5, 0.8, 2.2, 0.04)
    matrix rownames precmat = Prec
    capture noisily effecttab, from(precmat) display pdp(0)
    assert _rc == 198
    capture noisily effecttab, from(precmat) display highpdp(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS: T20 — invalid p-value precision is rejected"
    local ++n_pass
}
else {
    display as error "FAIL: T20 — invalid p-value precision accepted (rc=`=_rc')"
    local ++n_fail
}
capture matrix drop precmat

* ============================================================
* Test 21: unsupported active collect is rejected
* ============================================================
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture noisily effecttab, display
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS: T21 — unsupported collect rejected"
    local ++n_pass
}
else {
    display as error "FAIL: T21 — unsupported collect was accepted (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 21b: contrast-backed margins collect is rejected
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    gen byte low_bw = bweight < 2500
    logit low_bw i.mbsmoke mage prenatal1 mmarried fbaby
    collect clear
    collect: margins r.mbsmoke
    capture noisily effecttab, display
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS: T21b — margins contrast collect rejected"
    local ++n_pass
}
else {
    display as error "FAIL: T21b — margins contrast collect accepted (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 22: mixed teffects + margins collection is rejected
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    gen byte low_bw = bweight < 2500
    collect clear
    collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
    logit low_bw i.mbsmoke mage prenatal1 mmarried fbaby
    collect: margins, dydx(mbsmoke)
    capture noisily effecttab, display
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS: T22 — mixed teffects/margins collect rejected"
    local ++n_pass
}
else {
    display as error "FAIL: T22 — mixed teffects/margins collect accepted (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 23: explicit type() mismatch is rejected
* ============================================================
capture noisily {
    webuse cattaneo2, clear
    gen byte low_bw = bweight < 2500
    logit low_bw i.mbsmoke mage prenatal1 mmarried fbaby
    collect clear
    collect: margins, dydx(mbsmoke)
    capture noisily effecttab, display type(teffects)
    assert _rc == 198
}
if _rc == 0 {
    display as result "PASS: T23 — explicit type mismatch rejected"
    local ++n_pass
}
else {
    display as error "FAIL: T23 — explicit type mismatch accepted (rc=`=_rc')"
    local ++n_fail
}

* ============================================================
* Test 24: r(table) is returned above 100 rows
* ============================================================
capture noisily {
    matrix bigmat = J(101, 4, .)
    forvalues _i = 1/101 {
        matrix bigmat[`_i', 1] = `_i' / 100
        matrix bigmat[`_i', 2] = (`_i' / 100) - 0.05
        matrix bigmat[`_i', 3] = (`_i' / 100) + 0.05
        matrix bigmat[`_i', 4] = 0.20
    }
    effecttab, from(bigmat) display
    assert rowsof(r(table)) == 101
}
if _rc == 0 {
    display as result "PASS: T24 — r(table) persists above 100 rows"
    local ++n_pass
}
else {
    display as error "FAIL: T24 — r(table) truncated above 100 rows (rc=`=_rc')"
    local ++n_fail
}
capture matrix drop bigmat

* Summary
display _newline
display "============================="
display "  Results: `n_pass' passed, `n_fail' failed"
display "============================="
assert `n_fail' == 0

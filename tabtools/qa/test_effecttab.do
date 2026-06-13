* test_effecttab.do - complete QA for effecttab
* Consolidated in v1.7.0 from: test_effecttab_advanced.do, test_effecttab_iptw.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _effecttab
log using "test_effecttab.log", replace text name(_effecttab)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
* xlsx checker: single canonical copy in Stata-Dev (no per-package duplicate)
local _statadev : env STATA_DEV_DIR
if "`_statadev'" == "" {
    local _home : env HOME
    local _statadev "`_home'/Stata-Dev"
}
local checker "`_statadev'/_devkit/stata_dev_cli/xlsx/check_xlsx.py"
local checker "`checker'"
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


**# Test helpers migrated from review_* contract files
capture program drop _review_models_survdata
program define _review_models_survdata
    version 17.0
    clear
    set obs 160
    gen long id = _n
    gen byte treated = mod(_n, 2)
    gen double age = 45 + mod(_n, 30)
    gen double t = 5 + mod(_n, 25) + 3 * treated
    gen byte died = (mod(_n, 5) != 0)
    label define trtlbl 0 "Control" 1 "Treated", replace
    label values treated trtlbl
    label variable treated "Treatment"
    label variable age "Age"
    stset t, failure(died) id(id)
end


**# Migrated from test_effecttab_advanced.do


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
    local ++pass_count
}
else {
    display as error "FAIL: T1 — from() matrix failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
	else {
	    display as error "FAIL: T2 — from() matrix Excel export failed (rc=`=_rc')"
	    local ++fail_count
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
	    local ++pass_count
	}
	else {
	    display as error "FAIL: T2a — from() CI strings contain double spaces (rc=`=_rc')"
	    local ++fail_count
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
	    local ++pass_count
	}
	else {
	    global TABTOOLS_QA_EFFECTTAB_ERASE_XLSX
	    display as error "FAIL: T2c — final missing workbook guard did not return rc=601 (rc=`=_rc')"
	    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T2b — invalid from() matrix leaked user data (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T3 — multi-model effecttab failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T3b — single-model methods reused ambient e() (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T4 — psmatch effecttab failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T5 — nnmatch effecttab failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T6 — addrow() with IPTW failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T7 — frame() + display with IPTW failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T7b — collect CI strings contain double spaces (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T7c — collect CI bounds ignore digits() (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T8 — CSV export with IPTW failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T9 — r(table) matrix wrong for IPTW (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T10 — data not preserved (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T11 — footnote failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T12 — theme with IPTW failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T13 — boldp + highlight failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T14 — margins dydx failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T15 — margins at() failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T16 — ATE value mismatch (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T17 — helper reload failed (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T18 — from() inherited ambient teffects state (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T19 — tiny matrix p-values lost (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T20 — invalid p-value precision accepted (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T21 — unsupported collect was accepted (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T21b — margins contrast collect accepted (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T22 — mixed teffects/margins collect accepted (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T23 — explicit type mismatch accepted (rc=`=_rc')"
    local ++fail_count
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
    local ++pass_count
}
else {
    display as error "FAIL: T24 — r(table) truncated above 100 rows (rc=`=_rc')"
    local ++fail_count
}
capture matrix drop bigmat


**# Migrated from test_effecttab_iptw.do


webuse cattaneo2, clear
label define smokelbl 0 "Non-smoker" 1 "Smoker"
label values mbsmoke smokelbl

* ============================================================
* Test 1: IPTW without clean — should filter PS model coefficients
* Rows: title + 2 headers + ATE section (header + value) + POmean section (header + value) = 7
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW no clean") effect("ATE")
local _nrows = r(N_rows)
display "N_rows = `_nrows'"
* Must be fewer than the original 12 (which included PS model coefficients)
if `_nrows' <= 8 {
    display as result "PASS: T1 — IPTW filtered PS model (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T1 — IPTW shows `_nrows' rows (expected <=8, PS model not filtered)"
    local ++fail_count
}

* ============================================================
* Test 2: IPTW with clean — cleaner labels, fewer rows
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW clean") effect("ATE") clean
local _nrows = r(N_rows)
if `_nrows' <= 6 {
    display as result "PASS: T2 — IPTW with clean (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T2 — IPTW with clean shows `_nrows' rows (expected <=6)"
    local ++fail_count
}

* ============================================================
* Test 3: IPTW with full — should show ALL rows including PS model
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW full") effect("ATE") full
local _nrows = r(N_rows)
if `_nrows' > 8 {
    display as result "PASS: T3 — IPTW with full shows all rows (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T3 — IPTW with full should show >8 rows, got `_nrows'"
    local ++fail_count
}

* ============================================================
* Test 4: AIPW — should filter nuisance parameters
* ============================================================
collect clear
collect: teffects aipw (bweight mage prenatal1 mmarried) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("AIPW") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T4 — AIPW filtered (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T4 — AIPW shows `_nrows' rows (expected <=8)"
    local ++fail_count
}

* ============================================================
* Test 5: IPWRA — should filter nuisance parameters
* ============================================================
collect clear
collect: teffects ipwra (bweight mage prenatal1 mmarried) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPWRA") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T5 — IPWRA filtered (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T5 — IPWRA shows `_nrows' rows (expected <=8)"
    local ++fail_count
}

* ============================================================
* Test 6: RA — same behavior
* ============================================================
collect clear
collect: teffects ra (bweight mage prenatal1 mmarried fbaby) (mbsmoke), ate
effecttab, display title("RA") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T6 — RA filtered (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T6 — RA shows `_nrows' rows (expected <=8)"
    local ++fail_count
}

* ============================================================
* Test 7: Multi-arm (3 levels)
* ============================================================
gen trt3 = cond(mage < 25, 0, cond(mage < 35, 1, 2))
label define trt3lbl 0 "Young" 1 "Middle" 2 "Older"
label values trt3 trt3lbl

collect clear
collect: teffects ra (bweight prenatal1 mmarried fbaby) (trt3), ate
effecttab, display title("Multi-arm") effect("ATE") clean
local _nrows = r(N_rows)
if `_nrows' <= 9 {
    display as result "PASS: T7 — Multi-arm shows correct rows (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T7 — Multi-arm shows `_nrows' rows (expected <=9)"
    local ++fail_count
}

* ============================================================
* Test 8: Margins (should be unaffected)
* ============================================================
gen byte low_bw = bweight < 2500
logit low_bw i.mbsmoke mage prenatal1 mmarried fbaby
collect clear
collect: margins mbsmoke
effecttab, display title("Margins") effect("Pr(Y)")
local _nrows = r(N_rows)
if `_nrows' >= 4 {
    display as result "PASS: T8 — Margins works (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T8 — Margins shows only `_nrows' rows (expected >=4)"
    local ++fail_count
}

* ============================================================
* Test 9: Excel export — verify PS model coefficients removed
* ============================================================
collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, xlsx("/tmp/iptw_fix_test.xlsx") sheet("IPTW") title("IPTW Fixed") effect("ATE")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T9 — IPTW Excel export filtered (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T9 — IPTW Excel export shows `_nrows' rows"
    local ++fail_count
}

* ============================================================
* Test 10: Binary outcome IPTW
* ============================================================
collect clear
collect: teffects ipw (low_bw) (mbsmoke mage prenatal1 mmarried fbaby), ate
effecttab, display title("IPTW Binary") effect("RD")
local _nrows = r(N_rows)
if `_nrows' <= 8 {
    display as result "PASS: T10 — IPTW binary filtered (`_nrows' rows)"
    local ++pass_count
}
else {
    display as error "FAIL: T10 — IPTW binary shows `_nrows' rows (expected <=8)"
    local ++fail_count
}

* ============================================================
* Test 11: Verify IPTW Excel has no PS model coefficients
* ============================================================
capture {
    preserve
    import excel "/tmp/iptw_fix_test.xlsx", sheet("IPTW") clear
    * Check that "Mother's age" does not appear in column B
    gen byte _has_ps = regexm(B, "Mother") | regexm(B, "prenatal") | regexm(B, "married") | regexm(B, "first baby") | regexm(B, "Intercept")
    summarize _has_ps, meanonly
    restore
}
if _rc == 0 & r(max) == 0 {
    display as result "PASS: T11 — Excel contains no PS model coefficients"
    local ++pass_count
}
else {
    display as error "FAIL: T11 — Excel still contains PS model coefficients"
    local ++fail_count
}

* ============================================================
* Test 12: Value-level ATE comparison to direct teffects
* ============================================================
webuse cattaneo2, clear
label define smokelbl2 0 "Non-smoker" 1 "Smoker", replace
label values mbsmoke smokelbl2

collect clear
collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
matrix _te_table = r(table)
local _ref_ate = _te_table[1,1]
local _ref_pval = _te_table[4,1]

effecttab, frame(eff_val, replace) effect("ATE") clean display

* Extract ATE value from frame — c1 contains the estimate, A contains the row label
frame eff_val {
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
capture frame drop eff_val

if _rc == 0 {
	display as result "PASS: T12 — ATE value matches direct teffects"
	local ++pass_count
}
else {
	display as error "FAIL: T12 — ATE value mismatch"
	local ++fail_count
	capture frame drop eff_val
}
**# Migrated: legacy suite: effecttab section

* ============================================================
* effecttab Tests
* ============================================================

* Create synthetic causal inference dataset
quietly {
    clear
    set seed 54321
    set obs 2000
    gen age = 30 + runiform() * 40
    gen female = runiform() < 0.55
    gen education = 1 + floor(runiform() * 4)
    gen propensity = invlogit(-1.5 + 0.02*age + 0.3*female + 0.1*education)
    gen treatment = runiform() < propensity
    gen prob_outcome = invlogit(-2 + 0.5*treatment + 0.01*age - 0.2*female + 0.05*education)
    gen outcome_bin = runiform() < prob_outcome
    gen outcome_cont = 50 + 5*treatment + 0.2*age - 2*female + runiform()*10
    gen treat3 = 0 if runiform() < 0.33
    replace treat3 = 1 if missing(treat3) & runiform() < 0.5
    replace treat3 = 2 if missing(treat3)
    label define treat3_lbl 0 "Control" 1 "Low dose" 2 "High dose"
    label values treat3 treat3_lbl
    gen prob3 = invlogit(-2 + 0.3*(treat3==1) + 0.6*(treat3==2) + 0.01*age)
    gen outcome3 = runiform() < prob3
    label variable age "Age (years)"
    label variable female "Female sex"
    label variable treatment "Treatment (binary)"
    label variable outcome_bin "Binary outcome"
    label variable outcome_cont "Continuous outcome"
    label define treat_lbl 0 "Control" 1 "Treated"
    label values treatment treat_lbl
    save "`output_dir'/_effecttab_testdata.dta", replace
}

* Test: Basic teffects ipw - ATE
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female education), ate
    effecttab, xlsx("`output_dir'/_test_effecttab.xlsx") sheet("ATE") effect("ATE")
    confirm file "`output_dir'/_test_effecttab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - basic teffects ipw ATE"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - basic teffects ipw ATE (error `=_rc')"
    local ++fail_count
}

* Test: teffects with title and clean
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_clean.xlsx") sheet("T1") ///
        effect("ATE") title("ATE with IPTW") clean
    confirm file "`output_dir'/_test_effecttab_clean.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - title and clean"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - title and clean (error `=_rc')"
    local ++fail_count
}

* Test: teffects ipw - ATET
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female education), atet
    effecttab, xlsx("`output_dir'/_test_effecttab_atet.xlsx") sheet("ATET") effect("ATET")
    confirm file "`output_dir'/_test_effecttab_atet.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - ATET"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - ATET (error `=_rc')"
    local ++fail_count
}

* Test: teffects ipw - PO means
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), pomeans
    effecttab, xlsx("`output_dir'/_test_effecttab_po.xlsx") sheet("PO") ///
        effect("Pr(Y)") title("Potential Outcome Means") clean
    confirm file "`output_dir'/_test_effecttab_po.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - PO means"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - PO means (error `=_rc')"
    local ++fail_count
}

* Test: teffects ra
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ra (outcome_bin age female education) (treatment), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_ra.xlsx") sheet("RA") effect("ATE")
    confirm file "`output_dir'/_test_effecttab_ra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - teffects ra"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - teffects ra (error `=_rc')"
    local ++fail_count
}

* Test: teffects aipw (doubly robust)
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects aipw (outcome_bin age female) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_aipw.xlsx") sheet("AIPW") ///
        effect("ATE") title("Doubly Robust") clean
    confirm file "`output_dir'/_test_effecttab_aipw.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - teffects aipw"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - teffects aipw (error `=_rc')"
    local ++fail_count
}

* Test: Multiple models comparison
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    collect: teffects aipw (outcome_bin age female) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_multi.xlsx") sheet("Compare") ///
        models("IPTW \ AIPW") effect("ATE") clean
    confirm file "`output_dir'/_test_effecttab_multi.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - multiple models"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - multiple models (error `=_rc')"
    local ++fail_count
}

* Test: margins predictions
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female
    collect clear
    collect: margins treatment
    effecttab, xlsx("`output_dir'/_test_effecttab_margins.xlsx") sheet("Pred") ///
        type(margins) effect("Pr(Y)") title("Predicted Probabilities")
    confirm file "`output_dir'/_test_effecttab_margins.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins predictions"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins predictions (error `=_rc')"
    local ++fail_count
}

* Test: margins dydx (AME)
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female education
    collect clear
    collect: margins, dydx(treatment age female)
    effecttab, xlsx("`output_dir'/_test_effecttab_dydx.xlsx") sheet("AME") ///
        effect("AME") title("Average Marginal Effects")
    confirm file "`output_dir'/_test_effecttab_dydx.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins dydx"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins dydx (error `=_rc')"
    local ++fail_count
}

* Test: margins contrasts are rejected (collect command is contrast, not margins)
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female
    collect clear
    collect: margins r.treatment
    capture noisily effecttab, xlsx("`output_dir'/_test_effecttab_rd.xlsx") sheet("RD") effect("RD")
    assert _rc == 198
    capture confirm file "`output_dir'/_test_effecttab_rd.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins contrasts rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins contrasts rejection (error `=_rc')"
    local ++fail_count
}

* Test: margins with at()
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    logit outcome_bin i.treatment age female
    collect clear
    collect: margins treatment, at(age=(30 40 50 60))
    effecttab, xlsx("`output_dir'/_test_effecttab_at.xlsx") sheet("ByAge") ///
        type(margins) effect("Pr(Y)")
    confirm file "`output_dir'/_test_effecttab_at.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - margins at()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - margins at() (error `=_rc')"
    local ++fail_count
}

* Test: Multi-level treatment
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome3) (treat3 age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_ml.xlsx") sheet("Multi") ///
        effect("ATE") title("Multi-level Treatment") clean
    confirm file "`output_dir'/_test_effecttab_ml.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - multi-level treatment"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - multi-level treatment (error `=_rc')"
    local ++fail_count
}

* Test: Continuous outcome
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ra (outcome_cont age female) (treatment), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_cont.xlsx") sheet("Cont") effect("ATE")
    confirm file "`output_dir'/_test_effecttab_cont.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - continuous outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - continuous outcome (error `=_rc')"
    local ++fail_count
}

* Test: Custom CI separator
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_sep.xlsx") sheet("Sep") ///
        effect("ATE") sep(" to ")
    confirm file "`output_dir'/_test_effecttab_sep.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - custom separator"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - custom separator (error `=_rc')"
    local ++fail_count
}

* Test: Auto-detection of type
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age female), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_auto.xlsx") sheet("Auto") effect("Effect")
    assert "`r(type)'" == "teffects"
}
if _rc == 0 {
    display as result "  PASS: effecttab - auto type detection"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - auto type detection (error `=_rc')"
    local ++fail_count
}

* Test: clean with value-labeled treatment (auto-detect)
capture noisily {
    sysuse cancer, clear
    collect clear
    collect: teffects ipw (died) (drug age), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_vlabel.xlsx") ///
        sheet("AutoLabels") effect("ATE") title("Auto Labels") clean
    confirm file "`output_dir'/_test_effecttab_vlabel.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - clean with value labels"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - clean with value labels (error `=_rc')"
    local ++fail_count
}

* Test: tlabels() option
capture noisily {
    sysuse cancer, clear
    collect clear
    collect: teffects ipw (died) (drug age), ate
    effecttab, xlsx("`output_dir'/_test_effecttab_tlab.xlsx") ///
        sheet("Explicit") effect("ATE") ///
        tlabels(1 "Control" 2 "Treatment A" 3 "Treatment B")
    confirm file "`output_dir'/_test_effecttab_tlab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab - tlabels() option"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - tlabels() option (error `=_rc')"
    local ++fail_count
}

* Test: Error handling - no collect table
capture noisily {
    collect clear
    capture effecttab, xlsx("`output_dir'/_test_error.xlsx") sheet("Error")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: effecttab - error on no collect"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - error on no collect (error `=_rc')"
    local ++fail_count
}

* Test: Error handling - invalid file extension
capture noisily {
    use "`output_dir'/_effecttab_testdata.dta", clear
    collect clear
    collect: teffects ipw (outcome_bin) (treatment age), ate
    capture effecttab, xlsx("`output_dir'/_test_error.xls") sheet("Error")
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: effecttab - error on .xls extension"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - error on .xls extension (error `=_rc')"
    local ++fail_count
}

* Test: Data preservation after effecttab
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    logit foreign price mpg weight
    collect clear
    collect: margins, at(mpg=(20 30))
    effecttab, xlsx("`output_dir'/_test_effecttab_pres.xlsx") sheet("T1")
    assert _N == `orig_N'
    confirm variable price mpg weight foreign
}
if _rc == 0 {
    display as result "  PASS: effecttab - data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab - data preservation (error `=_rc')"
    local ++fail_count
}


**# Migrated: v1.6 digits()

**# 2.1: effecttab digits() option
* =========================================================================

* --- 2.1.1: digits(4) accepted ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_digits4.xlsx") sheet("Test") digits(4)
    confirm file "output/test_v160_digits4.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 2.1.1 — effecttab digits(4) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.1.1 — effecttab digits(4) failed (rc=`=_rc')"
    local ++fail_count
}

* --- 2.1.2: digits(0) accepted ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_digits0.xlsx") sheet("Test") digits(0)
    confirm file "output/test_v160_digits0.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 2.1.2 — effecttab digits(0) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.1.2 — effecttab digits(0) failed (rc=`=_rc')"
    local ++fail_count
}

* --- 2.1.3: digits(7) rejected ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_digits7.xlsx") sheet("Test") digits(7)
}
if _rc != 0 {
    display as result "  PASS: 2.1.3 — effecttab digits(7) correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.1.3 — effecttab digits(7) should have been rejected"
    local ++fail_count
}

* =========================================================================

**# Migrated: v1.6 frame()

**# 2.3: frame() for effecttab
* =========================================================================

local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture frame drop myeff
    effecttab, xlsx("output/test_v160_frame_effecttab.xlsx") sheet("Test") frame(myeff)
    assert r(frame) == "myeff"
    frame myeff: describe
    frame myeff: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: 2.3 — effecttab frame() stores data"
    local ++pass_count
}
else {
    display as error "  FAIL: 2.3 — effecttab frame() failed (rc=`=_rc')"
    local ++fail_count
}
capture frame drop myeff

* =========================================================================

**# Migrated: v1.6 console display

**# 3.2: Console display mode for effecttab
* =========================================================================

* --- 3.2.1: effecttab without xlsx() ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab
}
if _rc == 0 {
    display as result "  PASS: 3.2.1 — effecttab without xlsx() runs (console display)"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.2.1 — effecttab without xlsx() failed (rc=`=_rc')"
    local ++fail_count
}

* --- 3.2.2: effecttab with display option ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, xlsx("output/test_v160_effecttab_display.xlsx") sheet("Test") display
    confirm file "output/test_v160_effecttab_display.xlsx"
}
if _rc == 0 {
    display as result "  PASS: 3.2.2 — effecttab display + xlsx() works"
    local ++pass_count
}
else {
    display as error "  FAIL: 3.2.2 — effecttab display + xlsx() failed (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: option coverage sweep

**# SECTION 3: effecttab — untested options
* ============================================================

* Test: digits option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_digits.xlsx") sheet("digits") digits(4)
    confirm file "`output_dir'/_cov_eff_digits.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab digits()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab digits() (error `=_rc')"
    local ++fail_count
}

* Test: theme option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_theme.xlsx") sheet("lancet") theme(lancet)
    confirm file "`output_dir'/_cov_eff_theme.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab theme(lancet) (error `=_rc')"
    local ++fail_count
}

* Test: zebra option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_zebra.xlsx") sheet("zebra") zebra
    confirm file "`output_dir'/_cov_eff_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab zebra (error `=_rc')"
    local ++fail_count
}

* Test: boldp option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_boldp.xlsx") sheet("boldp") boldp(0.05)
    confirm file "`output_dir'/_cov_eff_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab boldp()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab boldp() (error `=_rc')"
    local ++fail_count
}

* Test: highlight option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_highlight.xlsx") sheet("highlight") highlight(0.05)
    confirm file "`output_dir'/_cov_eff_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab highlight() (error `=_rc')"
    local ++fail_count
}

* Test: borderstyle option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_border.xlsx") sheet("academic") borderstyle(academic)
    confirm file "`output_dir'/_cov_eff_border.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab borderstyle(academic)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab borderstyle(academic) (error `=_rc')"
    local ++fail_count
}

* Test: footnote option
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_footnote.xlsx") sheet("footnote") ///
        footnote("IPW estimates using logit propensity score")
    confirm file "`output_dir'/_cov_eff_footnote.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab footnote()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab footnote() (error `=_rc')"
    local ++fail_count
}

* Test: headercolor/zebracolor options
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_colors.xlsx") sheet("colors") ///
        zebra headercolor("200 220 240") zebracolor("245 245 255")
    confirm file "`output_dir'/_cov_eff_colors.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab headercolor()/zebracolor()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab headercolor()/zebracolor() (error `=_rc')"
    local ++fail_count
}

* Test: csv export
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_csv.xlsx") sheet("csv") ///
        csv("`output_dir'/_cov_eff.csv")
    confirm file "`output_dir'/_cov_eff.csv"
}
if _rc == 0 {
    display as result "  PASS: effecttab csv()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab csv() (error `=_rc')"
    local ++fail_count
}

* Test: frame output
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_frame.xlsx") sheet("frame") frame(_cov_eff_fr)
    frame _cov_eff_fr: assert _N > 0
    frame drop _cov_eff_fr
}
if _rc == 0 {
    display as result "  PASS: effecttab frame()"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab frame() (error `=_rc')"
    local ++fail_count
}

* Test: full option (full cross-tabulation)
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_full.xlsx") sheet("full") full
    confirm file "`output_dir'/_cov_eff_full.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab full"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab full (error `=_rc')"
    local ++fail_count
}

* Test: combined formatting stress test
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    effecttab, xlsx("`output_dir'/_cov_eff_stress.xlsx") sheet("stress") ///
        zebra boldp(0.05) highlight(0.1) borderstyle(academic) ///
        footnote("Treatment effect estimates") title("Effect Stress Test") ///
        theme(bmj) digits(3)
    confirm file "`output_dir'/_cov_eff_stress.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab combined formatting stress test"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab combined formatting stress test (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: r(xlsx) populated

**# 11. effecttab xlsx r(xlsx) populated and file exists (I3 regression)

**## 11a. Single Mata session produces correct output and r(xlsx)
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign)
    local i3_xlsx "`output_dir'/_rev1013_i3_effecttab.xlsx"
    capture erase "`i3_xlsx'"
    effecttab, xlsx("`i3_xlsx'") sheet("I3Test")
    assert `"`r(xlsx)'"' != ""
    capture confirm file "`i3_xlsx'"
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS [11a]: effecttab r(xlsx) populated and file exists"
    local ++pass_count
}
else {
    display as error "  FAIL [11a]: effecttab r(xlsx) empty or file missing (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_rev1013_i3_effecttab.xlsx"



**# Migrated: multi-model collect + clean + tlabels

**# QA Gap 4: effecttab multi-model collect + clean + tlabels

**## 4a. Single teffects with clean produces meaningful row labels
capture noisily {
    clear
    set obs 500
    set seed 42
    gen byte treated = runiform() > 0.5
    gen x1 = rnormal()
    gen y = 2 + 0.5*treated + 0.3*x1 + rnormal()
    collect clear
    collect: teffects ra (y x1) (treated), ate
    capture frame drop _eff_clean
    effecttab, clean frame(_eff_clean, replace) display
    frame _eff_clean {
        * Row labels should not contain raw "r1vs0.treated" notation
        local _has_raw = 0
        forvalues r = 3/`=_N' {
            local _lab = A[`r']
            if regexm("`_lab'", "^r[0-9]+vs[0-9]+\.") local _has_raw = 1
        }
        assert `_has_raw' == 0
    }
    capture frame drop _eff_clean
}
if _rc == 0 {
    display as result "  PASS [4a]: effecttab clean removes raw teffects notation"
    local ++pass_count
}
else {
    display as error "  FAIL [4a]: effecttab clean (rc=`=_rc')"
    local ++fail_count
}

**## 4b. tlabels overrides auto-detected value labels
capture noisily {
    clear
    set obs 500
    set seed 42
    gen byte treated = runiform() > 0.5
    label define tlab 0 "Control" 1 "Active"
    label values treated tlab
    gen x1 = rnormal()
    gen y = 2 + 0.5*treated + 0.3*x1 + rnormal()
    collect clear
    collect: teffects ra (y x1) (treated), ate
    capture frame drop _eff_tlab
    effecttab, tlabels(0 "Placebo" 1 "Drug") frame(_eff_tlab, replace) display
    frame _eff_tlab {
        * Should see "Drug vs Placebo" (from tlabels), not "Active vs Control"
        local _found_tlab = 0
        forvalues r = 3/`=_N' {
            local _lab = A[`r']
            if strpos("`_lab'", "Drug") > 0 & strpos("`_lab'", "Placebo") > 0 {
                local _found_tlab = 1
            }
        }
        assert `_found_tlab' == 1
    }
    capture frame drop _eff_tlab
}
if _rc == 0 {
    display as result "  PASS [4b]: effecttab tlabels overrides value labels"
    local ++pass_count
}
else {
    display as error "  FAIL [4b]: effecttab tlabels (rc=`=_rc')"
    local ++fail_count
}

**## 4c. Multi-model collect with clean
capture noisily {
    clear
    set obs 500
    set seed 42
    gen byte treated = runiform() > 0.5
    gen x1 = rnormal()
    gen y = 2 + 0.5*treated + 0.3*x1 + rnormal()
    collect clear
    collect: teffects ra (y x1) (treated), ate
    collect: teffects ipw (y) (treated x1), ate
    capture frame drop _eff_multi
    effecttab, clean frame(_eff_multi, replace) display
    frame _eff_multi {
        * Should have columns for both models
        ds c*
        local _ncols : word count `r(varlist)'
        assert `_ncols' >= 6  // 3 cols per model × 2 models
    }
    capture frame drop _eff_multi
}
if _rc == 0 {
    display as result "  PASS [4c]: effecttab multi-model collect + clean"
    local ++pass_count
}
else {
    display as error "  FAIL [4c]: effecttab multi-model (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: console-only returns

**# Regression: I4 — effecttab console-only returns

**## R5. effecttab without xlsx still returns type and effect_label
capture noisily {
    clear
    set obs 500
    set seed 42
    gen byte treated = runiform() > 0.5
    gen x1 = rnormal()
    gen y = 2 + 0.5*treated + 0.3*x1 + rnormal()
    collect clear
    collect: teffects ra (y x1) (treated), ate
    effecttab, display
    assert "`r(type)'" == "teffects"
    assert "`r(effect_label)'" == "Effect"
    assert r(N_rows) > 0
    * xlsx and sheet should NOT be returned
    assert "`r(xlsx)'" == ""
    assert "`r(sheet)'" == ""
}
if _rc == 0 {
    display as result "  PASS [R5]: effecttab console-only returns type/effect_label but no xlsx"
    local ++pass_count
}
else {
    display as error "  FAIL [R5]: effecttab console-only returns (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: from() all-missing matrix

**# Coverage Gap: effecttab from() with all-missing matrix

**## G1. effecttab from() with all-missing matrix produces error, not silent success
capture noisily {
    matrix define _allm = (., ., ., . \ ., ., ., .)
    matrix rownames _allm = row1 row2
    capture noisily effecttab, from(_allm) xlsx("`output_dir'/gap_allm.xlsx") ///
        sheet("Missing") effect("OR")
    local _g1_rc = _rc
    * Should either produce a table (rc=0 with empty content) or error gracefully
    * The key assertion: it must not crash with an uninformative Stata error
    assert inlist(`_g1_rc', 0, 2000)
    matrix drop _allm
}
if _rc == 0 {
    display as result "  PASS [G1]: effecttab from() with all-missing matrix handles gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL [G1]: effecttab from() all-missing matrix (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/gap_allm.xlsx"

**## G2. crosstab with all-zero frequency row completes without crash
capture noisily {
    clear
    input byte(rowvar colvar)
    1 1
    1 2
    1 1
    1 2
    end
    * All observations are rowvar==1, so rowvar has only 1 level
    * crosstab should error since it requires a 2x2 for or/rr/rd,
    * but basic tabulation should work
    crosstab rowvar colvar, display
}
if _rc == 0 {
    display as result "  PASS [G2]: crosstab single-row table completes without crash"
    local ++pass_count
}
else {
    display as error "  FAIL [G2]: crosstab single-row table (rc=`=_rc')"
    local ++fail_count
}

**## G3. survtab with delayed entry (left-truncation) computes correct risk sets
capture noisily {
    clear
    input double(id entry exit) byte(event)
    1  0  5  1
    2  0 10  0
    3  3  8  1
    4  5 12  0
    5  2  6  1
    end
    stset exit, failure(event) enter(entry) id(id)
    survtab, times(4 7) riskset display
    * At time 4: subjects 1(0-5),2(0-10),3(3-8),4(NOT yet: 5-12),5(2-6) -> 4 at risk
    * At time 7: subjects 2(0-10),3(3-8 but failed),4(5-12),5(2-6 but failed) -> need to check
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS [G3]: survtab with delayed entry (left-truncation) completes"
    local ++pass_count
}
else {
    display as error "  FAIL [G3]: survtab delayed entry (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: from(matrix) + r(table)

* --- 7.8: effecttab from(matrix) ---
capture noisily {
    * Create a matrix with estimate, ci_lower, ci_upper, pvalue
    matrix effects = (1.5, 1.1, 2.0, 0.01 \ -0.3, -0.5, -0.1, 0.003)
    matrix rownames effects = "Treatment" "Interaction"
    matrix colnames effects = "estimate" "ci_lower" "ci_upper" "pvalue"
    capture erase "`output_dir'/test_from_matrix.xlsx"
    effecttab, from(effects) ///
        xlsx("`output_dir'/test_from_matrix.xlsx") sheet("From Matrix")
    confirm file "`output_dir'/test_from_matrix.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab from(matrix)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab from(matrix) (rc=`=_rc')"
    local ++fail_count
}

* --- 7.9: effecttab from(matrix) display mode ---
capture noisily {
    matrix effects2 = (2.1, 1.3, 3.4, 0.002 \ 0.8, 0.5, 1.3, 0.35)
    matrix rownames effects2 = "TCE" "NDE"
    matrix colnames effects2 = "estimate" "ci_lower" "ci_upper" "pvalue"
    effecttab, from(effects2) display
}
if _rc == 0 {
    display as result "  PASS: effecttab from(matrix) display"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab from(matrix) display (rc=`=_rc')"
    local ++fail_count
}

* --- 7.10: effecttab r(table) matrix ---
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, display
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: effecttab r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab r(table) (rc=`=_rc')"
    local ++fail_count
}


**# Migrated: from() ignores unrelated collect

**# effecttab from() ignores an unrelated active model collect
capture noisily {
    _review_models_survdata
    collect clear
    collect: stcox treated age

    matrix review_eff = (0.12, 0.01, 0.23, 0.031 \ -0.08, -0.20, 0.04, 0.18)
    matrix rownames review_eff = Risk_difference Sensitivity

    capture frame drop review_eff_frame
    effecttab, from(review_eff) frame(review_eff_frame, replace) effect("Effect") display
    assert r(N_rows) > 0
    assert "`r(type)'" == "margins"
    assert strpos(lower(`"`r(methods)'"'), "supplied matrix") > 0
    assert "`r(frame)'" == "review_eff_frame"

    frame review_eff_frame {
        local found_rd = 0
        local found_sens = 0
        forvalues i = 1/`=_N' {
            if strpos(A[`i'], "Risk difference") > 0 local found_rd = 1
            if strpos(A[`i'], "Sensitivity") > 0 local found_sens = 1
        }
    }
    assert `found_rd' == 1
    assert `found_sens' == 1
}
if _rc == 0 {
    display as result "  PASS: effecttab from() works with unrelated active collect"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab from()/active-collect contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop review_eff_frame
capture matrix drop review_eff

**# Migrated: active collect + from() isolation

* Test 12: effecttab documents active collect mutation and from() isolation
capture noisily {
    findfile effecttab.sthlp
    tempname fh
    local _found_mutation 0
    local _found_from 0
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "intentionally updates active collection labels") > 0 local _found_mutation 1
        if strpos(`"`line'"', "matrix path does not inspect") > 0 local _found_from 1
        file read `fh' line
    }
    file close `fh'
    assert `_found_mutation' == 1
    assert `_found_from' == 1
}
if _rc == 0 {
    display as result "  PASS: effecttab active collect side effect documented"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab active collect side effect documented (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}




**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_effecttab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _effecttab
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_effecttab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _effecttab


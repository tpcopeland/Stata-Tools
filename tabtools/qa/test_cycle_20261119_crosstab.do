* test_cycle_20261119_crosstab.do - 2026-11-19 review cycle, unit crosstab
*   F1 an auto-selected Fisher test that tabulate cannot compute (rc 910 /
*      1400) falls back to Pearson's chi-squared test with a note; an
*      explicit exact/fisher request still errors, with a hint.
*   F2 a table with one row or one column level prints no "chi2 = ., p = ."
*      test row, stores no r(chi2)/r(p) and makes no methods test claim.
*   F3 xlsx() and excel() together is an error, not a silently dropped file.
*   (found while fixing F2) an unlabeled colvar kept gettoken's leading blank:
*      "for one by  b" in r(methods), "No test of association:  one".

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_crosstab
log using "test_cycle_20261119_crosstab.log", replace text name(_cyc_crosstab)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* 4x4 table, N=5000, one sparse level: tabulate's exact test exceeds memory.
capture program drop _cyc_ct_memdata
program define _cyc_ct_memdata
    clear
    set seed 7
    set obs 5000
    generate byte a = 1 + (runiform() < .5) + (runiform() < .2)
    generate byte b = 1 + (runiform() < .5) + (runiform() < .3)
    replace b = 4 in 1/2
    replace a = 4 in 1/2
end

* 8x9 table, N=4000, column 9 in 3 obs: margins too large for the exact test.
capture program drop _cyc_ct_bigdata
program define _cyc_ct_bigdata
    clear
    set seed 11
    set obs 4000
    generate byte a = 1 + floor(8 * runiform())
    generate byte b = 1 + floor(8 * runiform())
    replace b = 9 in 1/3
end

**# F1: auto-selected Fisher that cannot be computed falls back to chi2
local ++test_count
capture noisily {
    _cyc_ct_memdata
    * Preconditions: the table is sparse and tabulate's exact test fails.
    capture tab a b, exact
    local _tab_rc = _rc
    assert `_tab_rc' != 0
    quietly tab a b, chi2
    local _ref_chi2 = r(chi2)
    local _ref_p = r(p)

    local _csv "`output_dir'/_cyc_ct_f1.csv"
    capture erase "`_csv'"
    capture frame drop _cyc_ct_f1
    crosstab a b, frame(_cyc_ct_f1) csv("`_csv'")
    assert reldif(r(chi2), `_ref_chi2') < 1e-12
    assert reldif(r(p), `_ref_p') < 1e-12
    assert strpos(`"`r(methods)'"', "assessed using Pearson's chi-squared test because Fisher's exact test, selected for expected cell counts below 5, could not be computed") > 0
    assert _N == 5000
    local _want = "Pearson's chi-squared test (Fisher's exact test not computable): chi2 = " + ///
        strtrim(string(`_ref_chi2', "%6.2f")) + ", "
    frame _cyc_ct_f1 {
        quietly count if strpos(c1, `"`_want'"') == 1
        assert r(N) == 1
        quietly count if strpos(c1, "Fisher's exact test:") > 0
        assert r(N) == 0
    }
    * The exported CSV carries the same test row.
    preserve
    import delimited using "`_csv'", clear varnames(nonames) stringcols(_all)
    quietly count if strpos(v1, `"`_want'"') == 1
    assert r(N) == 1
    restore
    capture frame drop _cyc_ct_f1
}
if _rc == 0 {
    display as result "  PASS: F1 auto Fisher (rc 910 table) falls back to chi2 with a note"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 auto Fisher (rc 910 table) fallback (rc=`=_rc')"
    local ++fail_count
}

**# F1: margin-overflow table, rowpct, auto-selected Fisher falls back
local ++test_count
capture noisily {
    _cyc_ct_bigdata
    capture tab a b, exact
    assert _rc != 0
    quietly tab a b, chi2
    local _ref_chi2 = r(chi2)
    capture frame drop _cyc_ct_f1b
    crosstab a b, rowpct frame(_cyc_ct_f1b)
    assert reldif(r(chi2), `_ref_chi2') < 1e-12
    assert r(N) == 4000
    frame _cyc_ct_f1b {
        quietly count if strpos(c1, "Pearson's chi-squared test (Fisher's exact test not computable): chi2 = ") == 1
        assert r(N) == 1
    }
    capture frame drop _cyc_ct_f1b
}
if _rc == 0 {
    display as result "  PASS: F1 auto Fisher (8x9 overflow table) falls back to chi2"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 auto Fisher (8x9 overflow table) fallback (rc=`=_rc')"
    local ++fail_count
}

**# F1: an explicit exact/fisher request that cannot be computed stays an error
local ++test_count
capture noisily {
    _cyc_ct_memdata
    capture tab a b, exact
    local _tab_rc = _rc
    assert `_tab_rc' != 0
    set varabbrev on
    foreach _o in exact fisher {
        capture noisily crosstab a b, `_o'
        assert _rc == `_tab_rc'
        assert _N == 5000
        assert "`c(varabbrev)'" == "on"
    }
    set varabbrev off
    _cyc_ct_bigdata
    capture tab a b, exact
    local _tab_rc = _rc
    capture noisily crosstab a b, exact
    assert _rc == `_tab_rc' & _rc != 0
}
if _rc == 0 {
    display as result "  PASS: F1 explicit exact/fisher keeps tabulate's error"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 explicit exact/fisher error contract (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

**# F1 control: a computable sparse table still reports Fisher's exact test
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
    quietly tab outcome exposure, exact
    local _ref_p = r(p_exact)
    capture frame drop _cyc_ct_ctl
    crosstab outcome exposure, frame(_cyc_ct_ctl)
    assert reldif(r(p), `_ref_p') < 1e-12
    assert strpos(`"`r(methods)'"', "assessed using Fisher's exact test.") > 0
    frame _cyc_ct_ctl {
        quietly count if strpos(c1, "Fisher's exact test: p = ") == 1
        assert r(N) == 1
        quietly count if strpos(c1, "not computable") > 0
        assert r(N) == 0
    }
    capture frame drop _cyc_ct_ctl
}
if _rc == 0 {
    display as result "  PASS: F1 control, computable sparse table keeps Fisher"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 control, computable sparse table (rc=`=_rc')"
    local ++fail_count
}

**# F2: one-level row variable (chi2 path) has no test row, r(p) or claim
local ++test_count
capture noisily {
    clear
    set obs 120
    generate byte one = 1
    generate byte b = mod(_n, 2)
    local _csv "`output_dir'/_cyc_ct_f2.csv"
    capture erase "`_csv'"
    capture frame drop _cyc_ct_f2
    crosstab one b, frame(_cyc_ct_f2) csv("`_csv'")
    local _sc : r(scalars)
    assert !strpos(" `_sc' ", " p ") & !strpos(" `_sc' ", " chi2 ")
    assert r(N) == 120
    assert strpos(`"`r(methods)'"', "No test of association was performed because one has only one level.") > 0
    assert strpos(`"`r(methods)'"', "Statistical significance") == 0
    * an unlabeled colvar is named with one space ("by b", not "by  b")
    assert strpos(`"`r(methods)'"', "performed for one by b.") > 0
    frame _cyc_ct_f2 {
        quietly count if c1 == "No test of association: one has one level"
        assert r(N) == 1
        quietly count if strpos(c1, "p = .") > 0 | strpos(c1, "chi2 = .") > 0
        assert r(N) == 0
    }
    preserve
    import delimited using "`_csv'", clear varnames(nonames) stringcols(_all)
    quietly count if v1 == "No test of association: one has one level"
    assert r(N) == 1
    quietly count if strpos(v1, "p = .") > 0
    assert r(N) == 0
    restore
    capture frame drop _cyc_ct_f2
}
if _rc == 0 {
    display as result "  PASS: F2 one-level row variable has no test row or claim"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 one-level row variable (rc=`=_rc')"
    local ++fail_count
}

**# F2: one-level column variable on a sparse table (Fisher path), and exact
local ++test_count
capture noisily {
    clear
    set obs 6
    generate byte one = 1
    generate byte b = mod(_n, 2)
    foreach _o in "" exact {
        capture frame drop _cyc_ct_f2b
        crosstab b one, `_o' frame(_cyc_ct_f2b)
        local _sc : r(scalars)
        assert !strpos(" `_sc' ", " p ")
        assert strpos(`"`r(methods)'"', "No test of association was performed because one has only one level.") > 0
        frame _cyc_ct_f2b {
            quietly count if c1 == "No test of association: one has one level"
            assert r(N) == 1
            quietly count if strpos(c1, "Fisher") > 0
            assert r(N) == 0
        }
    }
    capture frame drop _cyc_ct_f2b
}
if _rc == 0 {
    display as result "  PASS: F2 one-level column variable, Fisher path and exact"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 one-level column variable (rc=`=_rc')"
    local ++fail_count
}

**# F2: one-level table under smallcells() full and primary
local ++test_count
capture noisily {
    clear
    set obs 6
    generate byte one = 1
    generate byte b = mod(_n, 2)
    foreach _m in "5" "5, primary" {
        capture frame drop _cyc_ct_f2c
        crosstab one b, smallcells(`_m') frame(_cyc_ct_f2c)
        local _sc : r(scalars)
        assert !strpos(" `_sc' ", " p ") & !strpos(" `_sc' ", " chi2 ")
        assert strpos(`"`r(methods)'"', "No test of association was performed") > 0
        assert strpos(`"`r(methods)'"', "Count-dependent tests") == 0
        frame _cyc_ct_f2c {
            quietly count if c1 == "No test of association: one has one level"
            assert r(N) == 1
            quietly count if strpos(c1, "Fisher") > 0 | strpos(c1, "p = .") > 0
            assert r(N) == 0
        }
    }
    capture frame drop _cyc_ct_f2c
}
if _rc == 0 {
    display as result "  PASS: F2 one-level table under smallcells() full and primary"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 one-level table under smallcells() (rc=`=_rc')"
    local ++fail_count
}

**# F3: xlsx() and excel() together are refused before anything is written
local ++test_count
capture noisily {
    clear
    set obs 60
    generate byte a = mod(_n, 2)
    generate byte b = mod(_n, 3) == 0
    local _x1 "`output_dir'/_cyc_ct_f3a.xlsx"
    local _x2 "`output_dir'/_cyc_ct_f3b.xlsx"
    capture erase "`_x1'"
    capture erase "`_x2'"
    capture noisily crosstab a b, xlsx("`_x1'") excel("`_x2'")
    assert _rc == 198
    capture confirm file "`_x1'"
    assert _rc == 601
    capture confirm file "`_x2'"
    assert _rc == 601
    * Each synonym alone still writes its workbook.
    crosstab a b, excel("`_x2'")
    assert `"`r(xlsx)'"' == "`_x2'"
    confirm file "`_x2'"
    capture erase "`_x2'"
}
if _rc == 0 {
    display as result "  PASS: F3 xlsx() with excel() is error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 xlsx() with excel() (rc=`=_rc')"
    local ++fail_count
}

display as result "test_cycle_20261119_crosstab summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_crosstab tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cyc_crosstab
if `fail_count' > 0 exit 1

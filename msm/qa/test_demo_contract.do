* test_demo_contract.do
* qa-hygiene: no-package-code -- greps demo source and shell-checks committed artifacts; never executes the demo or msm
* Q13: demo-lane contract. Guards the demo against drift without re-running the
* (multi-minute) full demo: the demo .do keeps its deterministic, portable,
* data-derived, IPCW-inclusive form; the committed artifacts exist and are
* non-empty; and every image the README embeds actually resolves.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_demo_contract.log", replace text nomsg

local qa_dir   "`c(pwd)'"
local pkg_dir  "`qa_dir'/.."
local demo_dir "`pkg_dir'/demo"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _dc_grep
program define _dc_grep, rclass
    * returns hit=1 if `needle' appears anywhere in text file `using'. Uses Mata
    * cat() so backticks/quotes/markup in the file are never macro-expanded.
    version 16.0
    syntax using/, needle(string)
    mata: st_numscalar("r_hit", ///
        any(strpos(cat(st_local("using")), st_local("needle")) :> 0))
    return scalar hit = r_hit
end

capture program drop _dc_assert_pass
program define _dc_assert_pass
    version 16.0
    syntax using/
    tempname fh
    file open `fh' using "`using'", read text
    file read `fh' line
    file close `fh'
    assert strtrim(`"`line'"') == "PASS"
end

* =========================================================================
* DC1: demo .do is deterministic, portable, data-derived, and runs IPCW.
* =========================================================================
local ++test_count
capture noisily {
    local dofile "`demo_dir'/demo_msm.do"
    capture confirm file "`dofile'"
    assert _rc == 0
    foreach needle in "set linesize 120" "set scheme plotplainblind" ///
        "capture log close _all" "censor_d_cov" "censor_n_cov" {
        _dc_grep using "`dofile'", needle("`needle'")
        assert r(hit) == 1
    }
    * counts must be derived from the data, not the old hardcoded "5000"
    _dc_grep using "`dofile'", needle("quietly count")
    assert r(hit) == 1
    _dc_grep using "`dofile'", needle("n_rows =")
    assert r(hit) == 1
    _dc_grep using "`dofile'", needle("5000 person-period observations")
    assert r(hit) == 0
}
if _rc == 0 {
    display as result "PASS DC1: demo .do is deterministic/portable/data-derived/IPCW"
    local ++pass_count
}
else {
    display as error "FAIL DC1: demo .do contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC1"
}

* =========================================================================
* DC2: committed demo artifacts exist and have their documented structure.
* =========================================================================
local ++test_count
capture noisily {
    foreach a in survival_plot.png weight_plot.png balance_plot.png ///
        msm_protocol.xlsx msm_report.xlsx msm_tables.xlsx {
        capture confirm file "`demo_dir'/`a'"
        assert _rc == 0
        quietly checksum "`demo_dir'/`a'"
        assert !missing(r(filelen))
        assert r(filelen) > 0
    }

    local xlsx_checker "`qa_dir'/tools/check_xlsx.py"
    local png_checker "`qa_dir'/tools/check_png.py"
    capture confirm file "`xlsx_checker'"
    assert _rc == 0
    capture confirm file "`png_checker'"
    assert _rc == 0

    tempfile artifact_status
    shell python3 "`xlsx_checker'" "`demo_dir'/msm_protocol.xlsx" ///
        --sheet-order Protocol --sheet Protocol --exact-cols 2 --min-rows 8 ///
        --header-exact 1 component description ///
        --result-file "`artifact_status'" --quiet
    _dc_assert_pass using "`artifact_status'"

    shell python3 "`xlsx_checker'" "`demo_dir'/msm_report.xlsx" ///
        --sheet-order Summary Coefficients --sheet Summary ///
        --cell A1 "MSM Analysis Summary" --min-rows 10 --min-cols 2 ///
        --result-file "`artifact_status'" --quiet
    _dc_assert_pass using "`artifact_status'"

    shell python3 "`xlsx_checker'" "`demo_dir'/msm_tables.xlsx" ///
        --sheet-order Coefficients Predictions Balance Weights Sensitivity ///
        --sheet Coefficients --cell A2 Variable --min-rows 5 --min-cols 4 ///
        --result-file "`artifact_status'" --quiet
    _dc_assert_pass using "`artifact_status'"

    foreach img in survival_plot.png weight_plot.png balance_plot.png {
        shell python3 "`png_checker'" "`demo_dir'/`img'" ///
            --width 1200 --height 800 --result-file "`artifact_status'"
        _dc_assert_pass using "`artifact_status'"
    }
}
if _rc == 0 {
    display as result "PASS DC2: demo workbooks and PNGs have the expected structure"
    local ++pass_count
}
else {
    display as error "FAIL DC2: demo artifacts (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC2"
}

* =========================================================================
* DC3: every image the README embeds from demo/ actually exists (no dangling
* reference to a removed screenshot).
* =========================================================================
local ++test_count
capture noisily {
    local readme "`pkg_dir'/README.md"
    capture confirm file "`readme'"
    assert _rc == 0
    * the three regenerated graphs must be referenced; the removed Excel
    * screenshots must NOT be.
    foreach img in survival_plot.png weight_plot.png balance_plot.png {
        _dc_grep using "`readme'", needle("demo/`img'")
        assert r(hit) == 1
        capture confirm file "`demo_dir'/`img'"
        assert _rc == 0
    }
    foreach gone in msm_protocol.png msm_report.png msm_tables.png {
        _dc_grep using "`readme'", needle("demo/`gone'")
        assert r(hit) == 0
    }
}
if _rc == 0 {
    display as result "PASS DC3: README demo image references all resolve"
    local ++pass_count
}
else {
    display as error "FAIL DC3: README demo references (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC3"
}

* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
do "`qa_dir'/_record_qa_result.do" test_demo_contract ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_demo_contract tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1

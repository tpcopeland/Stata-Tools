* test_demo_contract.do
* qa-hygiene: no-package-code -- greps demo source and shell-checks committed artifacts; never executes the demo or msm
* Q13: demo-lane contract. Guards the demo against drift without re-running the
* (multi-minute) full demo: the demo .do keeps its deterministic, portable,
* sandboxed, IPCW-inclusive msm 2.0.0 form; its root derivation survives a
* path containing "/demo" elsewhere; the committed artifacts exist and have
* their documented structure; and every image the README embeds resolves.

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
* DC1: demo .do is deterministic, portable, sandboxed, and runs IPCW.
* =========================================================================
local ++test_count
capture noisily {
    local dofile "`demo_dir'/demo_msm.do"
    capture confirm file "`dofile'"
    assert _rc == 0
    foreach needle in "set linesize 120" "set scheme white_tableau" ///
        `"== "white_tableau""' ///
        "capture log close _all" "censor_d_cov" "censor_n_cov" ///
        "sysdir set PLUS" "sysdir set PERSONAL" "samples(1000)" ///
        "seed(12345)" "frame(pred, replace)" ///
        `""/demo$", "")"' ///
        "covariates(biomarker comorbidity) wvar(_msm_weight) loveplot" {
        _dc_grep using "`dofile'", needle(`"`needle'"')
        assert r(hit) == 1
    }
    * 1.4.x stripped the first "/demo" anywhere; never again. No removed
    * command, no numerator covariate in the Love plot, no real-tree install.
    foreach needle in `"subinstr local pkg_dir "/demo""' "msm_plot," ///
        "msm_report," "msm_table," "msm_protocol," "msm_validate," ///
        "msm_sensitivity," "covariates(biomarker comorbidity age sex) wvar" ///
        "net set ado" "plotplainblind" {
        _dc_grep using "`dofile'", needle(`"`needle'"')
        assert r(hit) == 0
    }
}
if _rc == 0 {
    display as result "PASS DC1: demo .do is deterministic/portable/sandboxed/IPCW"
    local ++pass_count
}
else {
    display as error "FAIL DC1: demo .do contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC1"
}

* =========================================================================
* DC2: the demo's root derivation keeps a "/demo" elsewhere in the path.
* Runs the demo's own Paths block (up to the install) in a fake layout under
* <tmp>/demos_x/repo_demo_y/msm/demo and checks every working directory it
* supports. 1.4.12 resolved such a path to a non-existent root (r(601)).
* =========================================================================
local ++test_count
capture noisily {
    tempfile anchor
    local base "`anchor'_demos_x"
    local repo "`base'/repo_demo_y"
    foreach d in "`base'" "`repo'" "`repo'/msm" "`repo'/msm/demo" {
        capture mkdir "`d'"
    }
    foreach p in msm tabtools psdash eplot qba tc_schemes logdoc {
        capture mkdir "`repo'/`p'"
        tempname fh
        file open `fh' using "`repo'/`p'/`p'.pkg", write text replace
        file write `fh' "v 3" _n
        file close `fh'
    }
    copy "`demo_dir'/demo_msm.do" "`repo'/msm/demo/demo_msm.do", replace
    * the Paths block only; Mata copies the lines verbatim (Stata's file
    * write would expand the block's own macros at copy time)
    local block "`anchor'_paths.do"
    mata: _dc_L = cat(st_local("demo_dir") + "/demo_msm.do")
    mata: _dc_a = selectindex(strpos(_dc_L, "**# Paths") :== 1)[1]
    mata: _dc_b = selectindex(strpos(_dc_L, "**# Isolated install") :== 1)[1]
    mata: _dc_fh = fopen(st_local("block"), "w")
    mata: for (_dc_i = _dc_a; _dc_i < _dc_b; _dc_i++) fput(_dc_fh, _dc_L[_dc_i])
    mata: fclose(_dc_fh)
    local orig "`c(pwd)'"
    foreach wd in "`repo'/msm/demo" "`repo'/msm" "`repo'" {
        quietly cd "`wd'"
        include "`block'"
        quietly cd "`orig'"
        assert "`pkg_root'" == "`repo'/msm"
        assert "`repo_root'" == "`repo'"
        assert "`demo_dir'" == "`repo'/msm/demo"
    }
    local demo_dir "`pkg_dir'/demo"
}
local dc2_rc = _rc
capture cd "`orig'"
if `dc2_rc' == 0 {
    display as result "PASS DC2: root derivation survives /demo elsewhere in the path"
    local ++pass_count
}
else {
    display as error "FAIL DC2: demo root derivation (rc=`dc2_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC2"
}
local demo_dir "`pkg_dir'/demo"

* =========================================================================
* DC3: committed demo artifacts exist and have their documented structure.
* =========================================================================
local ++test_count
capture noisily {
    foreach a in survival_plot.png rd_forest.png weight_plot.png ///
        balance_plot.png msm_tables.xlsx console_pipeline.md console_results.md {
        capture confirm file "`demo_dir'/`a'"
        assert _rc == 0
        quietly checksum "`demo_dir'/`a'"
        assert !missing(r(filelen))
        assert r(filelen) > 0
    }
    * the 1.4.x protocol/report workbooks are gone
    foreach gone in msm_protocol.xlsx msm_report.xlsx {
        capture confirm file "`demo_dir'/`gone'"
        assert _rc != 0
    }

    local xlsx_checker "`qa_dir'/tools/check_xlsx.py"
    local png_checker "`qa_dir'/tools/check_png.py"
    tempfile artifact_status
    shell python3 "`xlsx_checker'" "`demo_dir'/msm_tables.xlsx" ///
        --sheet-order "Outcome model" "Risk differences" ///
        --sheet "Risk differences" --min-rows 6 --min-cols 3 ///
        --result-file "`artifact_status'" --quiet
    _dc_assert_pass using "`artifact_status'"

    foreach img in survival_plot.png rd_forest.png weight_plot.png balance_plot.png {
        shell python3 "`png_checker'" "`demo_dir'/`img'" ///
            --width 1400 --height 933 --result-file "`artifact_status'"
        _dc_assert_pass using "`artifact_status'"
    }
    * console transcripts carry no machine path
    foreach md in console_pipeline.md console_results.md {
        _dc_grep using "`demo_dir'/`md'", needle("/home/")
        assert r(hit) == 0
        _dc_grep using "`demo_dir'/`md'", needle("/tmp/")
        assert r(hit) == 0
    }
}
if _rc == 0 {
    display as result "PASS DC3: demo workbook, PNGs and transcripts have the expected structure"
    local ++pass_count
}
else {
    display as error "FAIL DC3: demo artifacts (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC3"
}

* =========================================================================
* DC4: every image the README embeds from demo/ exists.
* =========================================================================
local ++test_count
capture noisily {
    local readme "`pkg_dir'/README.md"
    foreach img in survival_plot.png rd_forest.png weight_plot.png balance_plot.png {
        _dc_grep using "`readme'", needle("demo/`img'")
        assert r(hit) == 1
        capture confirm file "`demo_dir'/`img'"
        assert _rc == 0
    }
    foreach gone in msm_protocol msm_report.xlsx {
        _dc_grep using "`readme'", needle("demo/`gone'")
        assert r(hit) == 0
    }
}
if _rc == 0 {
    display as result "PASS DC4: README demo image references all resolve"
    local ++pass_count
}
else {
    display as error "FAIL DC4: README demo references (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' DC4"
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

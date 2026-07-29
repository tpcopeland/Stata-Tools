* test_package_release.do
* Q11: release-contract test. Verifies the installed-user surface: every public
* command resolves, the umbrella manifest is canonical, the .pkg ships every
* .ado/.sthlp in the package, stata.toc is canonical, a documented workflow runs
* end to end, and the key r()/e() results are present.
*
* Runs against the isolated install so it exercises exactly what a user gets
* from `net install`.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_package_release.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local public "msm msm_prepare msm_validate msm_weight msm_diagnose msm_diagtab msm_fit msm_predict msm_plot msm_table msm_report msm_protocol msm_sensitivity"

* Render help through Stata's SMCL interpreter. Source-text grep cannot detect
* directives that become literal markup only after rendering.
capture program drop _qa_sthlp_render
program define _qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "  render: file not found: `f'"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }

        tempfile rlog
        capture log off
        log using "`rlog'", replace text name(_qarender)
        type "`f'", smcl
        log close _qarender
        capture log on

        local hits 0
        local nlines 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local shown = subinstr(`"`line'"',  "{",     char(1), .)
                local shown = subinstr(`"`shown'"', "}",     char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL: `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        if `nlines' == 0 {
            display as error "  render produced no output for `f' -- FAILING"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }
        if `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

* =========================================================================
* R1: every public command (umbrella + 12 subcommands) resolves for a user
* =========================================================================
local ++test_count
capture noisily {
    foreach c of local public {
        capture which `c'
        assert _rc == 0
    }
    * exactly thirteen public entry points (umbrella + 12)
    assert `: word count `public'' == 13
}
if _rc == 0 {
    display as result "PASS R1: all 13 public entry points resolve"
    local ++pass_count
}
else {
    display as error "FAIL R1: command resolution (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R1"
}

* =========================================================================
* R2: the umbrella manifest is the canonical 12-subcommand set incl. msm_diagtab
* =========================================================================
local ++test_count
capture noisily {
    msm, list
    local cmds "`r(commands)'"
    assert r(n_commands) == 12
    assert `: word count `cmds'' == 12
    * every subcommand in the manifest is a real, resolvable command
    foreach c of local cmds {
        assert `: list posof "`c'" in public' > 0
        capture which `c'
        assert _rc == 0
    }
    assert `: list posof "msm_diagtab" in cmds' > 0
}
if _rc == 0 {
    display as result "PASS R2: umbrella manifest is the canonical 12-command set"
    local ++pass_count
}
else {
    display as error "FAIL R2: manifest contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R2"
}

* =========================================================================
* R3: msm.pkg has an exact, duplicate-free shipped-file manifest. A helper
* omitted from the .pkg does not install; an extra entry can mask stale files.
* =========================================================================
local ++test_count
capture noisily {
    tempname fh
    local pkgfiles ""
    file open `fh' using "`pkg_dir'/msm.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`line'"', "^f ([^ ]+)$") {
            local candidate = regexs(1)
            local already : list candidate in pkgfiles
            assert `already' == 0
            local pkgfiles "`pkgfiles' `candidate'"
        }
        file read `fh' line
    }
    file close `fh'

    local ados : dir "`pkg_dir'" files "*.ado"
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local expected "`ados' `sthlps' msm_example.dta"
    local missing : list expected - pkgfiles
    local extra   : list pkgfiles - expected
    assert "`missing'" == ""
    assert "`extra'" == ""
    assert `: word count `pkgfiles'' == `: word count `expected''
}
if _rc == 0 {
    display as result "PASS R3: msm.pkg shipped-file manifest is exact"
    local ++pass_count
}
else {
    display as error "FAIL R3: .pkg completeness (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R3"
}

* =========================================================================
* R4: stata.toc is the canonical five-line form (CLAUDE.md Distribution Standard)
* =========================================================================
local ++test_count
capture noisily {
    tempname fh
    local toc_n = 0
    local toc1 "v 3"
    local toc2 "d Stata-Tools: msm"
    local toc3 "d Timothy P Copeland, Karolinska Institutet"
    local toc4 "d https://github.com/tpcopeland/Stata-Tools"
    local toc5 "p msm"
    file open `fh' using "`pkg_dir'/stata.toc", read text
    file read `fh' line
    while r(eof) == 0 {
        local ++toc_n
        assert `toc_n' <= 5
        assert `"`line'"' == `"`toc`toc_n''"'
        file read `fh' line
    }
    file close `fh'
    assert `toc_n' == 5
}
if _rc == 0 {
    display as result "PASS R4: stata.toc is canonical"
    local ++pass_count
}
else {
    display as error "FAIL R4: stata.toc (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R4"
}

* =========================================================================
* R5: released-package version and date surfaces are synchronized.
* =========================================================================
local ++test_count
capture noisily {
    tempname fh
    file open `fh' using "`pkg_dir'/msm.ado", read text
    file read `fh' ado_header
    file close `fh'
    assert regexm(`"`ado_header'"', "Version ([0-9]+\.[0-9]+\.[0-9]+)  ([0-9][0-9][0-9][0-9])/([0-9][0-9])/([0-9][0-9])")
    local version = regexs(1)
    local yyyy = regexs(2)
    local mm = regexs(3)
    local dd = regexs(4)
    local dist_date "`yyyy'`mm'`dd'"
    local iso_date "`yyyy'-`mm'-`dd'"
    local help_date : display %tdDDmonCCYY mdy(real("`mm'"), real("`dd'"), real("`yyyy'"))
    local help_date = lower(strtrim("`help_date'"))

    file open `fh' using "`pkg_dir'/msm.sthlp", read text
    file read `fh' sthlp_line
    file read `fh' sthlp_line
    file close `fh'
    assert strpos(lower(`"`sthlp_line'"'), "version `version'") > 0
    assert strpos(lower(`"`sthlp_line'"'), "`help_date'") > 0

    local pkg_date ""
    file open `fh' using "`pkg_dir'/msm.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        if regexm(`"`line'"', "^d Distribution-Date: ([0-9]+)$") {
            local pkg_date = regexs(1)
        }
        file read `fh' line
    }
    file close `fh'
    assert "`pkg_date'" == "`dist_date'"

    mata: st_numscalar("r_pkg_readme", ///
        any(strpos(cat(st_local("pkg_dir") + "/README.md"), ///
        "**Version " + st_local("version") + "** | " + st_local("iso_date")) :> 0))
    assert r_pkg_readme == 1

    * The repository README is intentionally outside the package copied by
    * qa run --isolated. Check it when present; the repository-level
    * `version check msm --repo tools` gate verifies it on every audit.
    capture confirm file "`pkg_dir'/../README.md"
    local root_readme_available = (_rc == 0)
    if `root_readme_available' {
        mata: st_numscalar("r_root_badge", ///
            any(strpos(cat(st_local("pkg_dir") + "/../README.md"), ///
            "msm) | ![version](https://img.shields.io/badge/version-" + ///
            st_local("version") + "-blue) | ![updated](https://img.shields.io/badge/updated-" + ///
            subinstr(st_local("iso_date"), "-", "--", .) + "-brightgreen)") :> 0))
        assert r_root_badge == 1
    }
    else {
        display as text "  repository badge check deferred to version check (isolated scratch)"
    }
}
if _rc == 0 {
    display as result "PASS R5: shipped version and distribution-date surfaces agree"
    local ++pass_count
}
else {
    display as error "FAIL R5: version/date synchronization (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R5"
}

* =========================================================================
* R6: every help file renders cleanly, and the oracle catches a known defect.
* =========================================================================
local ++test_count
capture noisily {
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    assert `: word count `sthlps'' == 13
    local paths ""
    foreach s of local sthlps {
        local paths "`paths' `pkg_dir'/`s'"
    }
    _qa_sthlp_render `paths'
    assert r(nbad) == 0

    tempfile broken_anchor
    local broken "`broken_anchor'.sthlp"
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _qa_sthlp_render `broken'
    assert r(nbad) == 1
    erase "`broken'"
}
if _rc == 0 {
    display as result "PASS R6: all help renders cleanly and the oracle rejects its broken probe"
    local ++pass_count
}
else {
    display as error "FAIL R6: rendered-help contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R6"
}

* =========================================================================
* R7: the documented Quick Start workflow runs end to end and posts its
* headline results (r()/e()), including the fit's r(id)-style artifact id.
* =========================================================================
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog
    msm_fit, model(logistic) outcome_cov(age sex) nolog
    * the fit posts its effect matrix and a stable artifact identity
    assert e(msm_cmd) == "msm_fit"
    matrix _e = e(effects)
    assert rowsof(_e) >= 1 & colsof(_e) == 4
    assert "`: char _dta[_msm_fitted]'" == "1"
    msm_predict, times(1 3) samples(20) seed(1)
    assert r(n_times) == 2
    matrix _p = r(predictions)
    assert rowsof(_p) == 2
    * umbrella status reflects the completed pipeline
    msm, status
    assert r(prepared) == 1 & r(weighted) == 1 & r(fitted) == 1
}
if _rc == 0 {
    display as result "PASS R7: documented pipeline runs end to end with results"
    local ++pass_count
}
else {
    display as error "FAIL R7: runnable release workflow (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R7"
}

* =========================================================================
* R8: ancillary example data is retrievable through the documented net get
* workflow. net install deliberately installs command/help files only.
* =========================================================================
local ++test_count
tempfile netget_anchor
local netget_dir "`netget_anchor'_dir"
local original_pwd "`c(pwd)'"
capture mkdir "`netget_dir'"
capture noisily {
    cd "`netget_dir'"
    net get msm, from("`pkg_dir'") replace
    confirm file msm_example.dta
    use msm_example.dta, clear
    assert _N == 4586
    isid id period
    confirm variable treatment outcome biomarker comorbidity age sex
}
local netget_rc = _rc
capture cd "`original_pwd'"
clear
capture erase "`netget_dir'/msm_example.dta"
capture rmdir "`netget_dir'"
capture assert `netget_rc' == 0
if _rc == 0 {
    display as result "PASS R8: net get retrieves usable ancillary example data"
    local ++pass_count
}
else {
    display as error "FAIL R8: ancillary example data retrieval (rc=`netget_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R8"
}

* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
do "`qa_dir'/_record_qa_result.do" test_package_release ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1

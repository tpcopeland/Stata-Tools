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
* R3: msm.pkg ships every .ado and .sthlp in the package directory. A helper
* left out of the .pkg does not install, so a fresh user hits r(199).
* =========================================================================
local ++test_count
capture noisily {
    * read the whole .pkg once
    tempname fh
    local pkgtext ""
    file open `fh' using "`pkg_dir'/msm.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        local pkgtext `"`pkgtext' `line'"'
        file read `fh' line
    }
    file close `fh'

    local missing ""
    local ados : dir "`pkg_dir'" files "*.ado"
    foreach a of local ados {
        if strpos(`"`pkgtext'"', "`a'") == 0 local missing "`missing' `a'"
    }
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    foreach s of local sthlps {
        if strpos(`"`pkgtext'"', "`s'") == 0 local missing "`missing' `s'"
    }
    if "`missing'" != "" {
        display as error "files in the package dir but NOT in msm.pkg:`missing'"
    }
    assert "`missing'" == ""
}
if _rc == 0 {
    display as result "PASS R3: msm.pkg lists every shipped .ado and .sthlp"
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
    local toc ""
    file open `fh' using "`pkg_dir'/stata.toc", read text
    file read `fh' line
    while r(eof) == 0 {
        local toc `"`toc'|`line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`toc'"', "v 3") > 0
    assert strpos(`"`toc'"', "Stata-Tools: msm") > 0
    assert strpos(`"`toc'"', "Timothy P Copeland, Karolinska Institutet") > 0
    assert strpos(`"`toc'"', "github.com/tpcopeland/Stata-Tools") > 0
    assert strpos(`"`toc'"', "|p msm") > 0
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
* R5: the documented Quick Start workflow runs end to end and posts its
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
    display as result "PASS R5: documented pipeline runs end to end with results"
    local ++pass_count
}
else {
    display as error "FAIL R5: runnable release workflow (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' R5"
}

* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
display as text "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 1

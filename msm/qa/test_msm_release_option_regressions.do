* test_msm_release_option_regressions.do
* Documentation, release-surface, and option-combination regressions.
*
* Findings covered (audit 2026-07-12):
*   A32  one canonical public-command manifest lists the 5 core subcommands
*        (msm 2.0.0) and every listed command resolves
*   A35  incompatible/meaningless option combinations are rejected rc 198;
*        the umbrella accepts at most one mode option
*
* Every refusal test is paired with a positive control. Reference:
* rc198_error_test_needs_positive_control.

version 16.0
clear all
set more off
set varabbrev off

capture log close _all
log using "test_msm_release_option_regressions.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =========================================================================
* A32: canonical manifest lists the 5 core subcommands, and every listed
* command resolves for an installed user.
* =========================================================================
local ++test_count
capture noisily {
    msm, list
    local cmds "`r(commands)'"
    local nc = r(n_commands)
    assert `nc' == 5
    assert `: word count `cmds'' == 5
    assert `: list posof "msm_diagtab" in cmds' == 0
    * n_commands must agree with the manifest length, not a stale literal
    assert `nc' == `: word count `cmds''
    * every command in the manifest resolves (installed-user reality)
    foreach c of local cmds {
        capture which `c'
        assert _rc == 0
    }
}
if _rc == 0 {
    display as result "PASS A32: manifest lists the 5 core commands; all resolve"
    local ++pass_count
}
else {
    display as error "FAIL A32: command manifest (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A32"
}

* =========================================================================
* A35: the umbrella accepts at most one mode option.
* =========================================================================
local ++test_count
capture noisily {
    * conflicting mode options (two at once) -> rejected (old code silently honoured one)
    capture msm, list detail
    assert _rc == 198
    capture msm, detail status
    assert _rc == 198
    * the removed protocol mode is refused even alone
    capture msm, protocol
    assert _rc == 198
    * positive control: a single mode runs
    capture msm, list
    assert _rc == 0
    capture msm, status
    assert _rc == 0
}
if _rc == 0 {
    display as result "PASS A35a: umbrella rejects multiple mode options"
    local ++pass_count
}
else {
    display as error "FAIL A35a: umbrella multi-mode (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A35a"
}

* =========================================================================
* A35: msm_diagnose rejects contrast()/outcome() (removed in msm 2.0.0
* with accumulate(); still parsed so the refusal names the replacement).
* =========================================================================
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog

    * contrast()/outcome() were accumulate() labels; both are refused
    capture msm_diagnose, contrast("armA")
    assert _rc == 198
    capture msm_diagnose, outcome("death")
    assert _rc == 198
    * positive control: a plain diagnose runs
    capture msm_diagnose
    assert _rc == 0
}
if _rc == 0 {
    display as result "PASS A35b: msm_diagnose rejects the removed contrast()/outcome()"
    local ++pass_count
}
else {
    display as error "FAIL A35b: msm_diagnose option combo (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A35b"
}


* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
do "`qa_dir'/_record_qa_result.do" test_msm_release_option_regressions ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_release_option_regressions tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1

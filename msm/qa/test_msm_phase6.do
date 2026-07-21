* test_msm_phase6.do
* Phase 6 regressions: documentation & release surface.
*
* Findings covered (audit 2026-07-12):
*   A32  one canonical public-command manifest lists all 12 subcommands
*        (including msm_diagtab) and every listed command resolves
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
log using "test_msm_phase6.log", replace text nomsg

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* =========================================================================
* A32: canonical manifest lists all 12 subcommands incl. msm_diagtab, and
* every listed command resolves for an installed user.
* =========================================================================
local ++test_count
capture noisily {
    msm, list
    local cmds "`r(commands)'"
    local nc = r(n_commands)
    assert `nc' == 12
    assert `: word count `cmds'' == 12
    assert `: list posof "msm_diagtab" in cmds' > 0
    * n_commands must agree with the manifest length, not a stale literal
    assert `nc' == `: word count `cmds''
    * every command in the manifest resolves (installed-user reality)
    foreach c of local cmds {
        capture which `c'
        assert _rc == 0
    }
}
if _rc == 0 {
    display as result "PASS A32: manifest lists all 12 commands incl. msm_diagtab; all resolve"
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
    * two mode options -> rejected (old code silently honoured one)
    capture msm, list detail
    assert _rc == 198
    capture msm, protocol status
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
* A35: msm_diagnose rejects contrast()/outcome() without accumulate().
* =========================================================================
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog

    * contrast() only labels an accumulate row; alone it is a silent no-op
    capture msm_diagnose, contrast("armA")
    assert _rc == 198
    capture msm_diagnose, outcome("death")
    assert _rc == 198
    * positive control: a plain diagnose runs
    capture msm_diagnose
    assert _rc == 0
}
if _rc == 0 {
    display as result "PASS A35b: msm_diagnose rejects contrast()/outcome() without accumulate()"
    local ++pass_count
}
else {
    display as error "FAIL A35b: msm_diagnose option combo (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A35b"
}

* =========================================================================
* A35: msm_protocol rejects export() with format(display).
* =========================================================================
local ++test_count
capture noisily {
    capture msm_protocol, population("adults") treatment("statin") ///
        confounders("age ldl") outcome("MI") causal_contrast("always vs never") ///
        weight_spec("stabilized IPTW") analysis("pooled logistic") ///
        format(display) export("`c(pwd)'/_p6_noop.csv")
    assert _rc == 198
    * positive control: format(display) with no export() runs
    capture msm_protocol, population("adults") treatment("statin") ///
        confounders("age ldl") outcome("MI") causal_contrast("always vs never") ///
        weight_spec("stabilized IPTW") analysis("pooled logistic")
    assert _rc == 0
}
if _rc == 0 {
    display as result "PASS A35c: msm_protocol rejects display+export"
    local ++pass_count
}
else {
    display as error "FAIL A35c: msm_protocol display+export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A35c"
}

* -------------------------------------------------------------------------
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
}
display as text "RESULT: test_msm_phase6 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 1

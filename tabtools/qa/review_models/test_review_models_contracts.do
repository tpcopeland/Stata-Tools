*! test_review_models_contracts.do - Review-owned contracts for model/survival/diagnostic commands

clear all
set more off
set varabbrev off
version 17.0

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/review_models$") {
    local pkg_dir = regexr("`_cwd'", "/qa/review_models$", "")
    local qa_dir = regexr("`_cwd'", "/review_models$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_dir = regexr("`_cwd'", "/qa$", "")
    local qa_dir "`_cwd'"
}
else {
    local pkg_dir "`_cwd'"
    local qa_dir "`pkg_dir'/qa"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

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

**# Cox model and survival table contracts
local ++test_count
capture noisily {
    _review_models_survdata
    collect clear
    collect: stcox treated age

    capture frame drop review_regcox
    regtab, frame(review_regcox, replace) noint stats(n n_sub ll)
    assert "`r(coef_label)'" == "HR"
    assert r(N_models) == 1
    assert strpos(lower(`"`r(methods)'"'), "hazard ratios") > 0

    local found_treated = 0
    local found_age = 0
    frame review_regcox {
        forvalues i = 1/`=_N' {
            if strpos(A[`i'], "Treatment") > 0 local found_treated = 1
            if strpos(A[`i'], "Age") > 0 local found_age = 1
        }
    }
    assert `found_treated' == 1
    assert `found_age' == 1

    capture frame drop review_surv
    survtab, times(10 20) by(treated) events riskset frame(review_surv, replace)
    assert r(N_rows) > 0
    assert r(events_1) + r(events_2) > 0
    assert r(atrisk_1) + r(atrisk_2) == 160
    assert r(logrank_p) >= 0 & r(logrank_p) <= 1
    assert "`r(frame)'" == "review_surv"
    assert strpos(lower(`"`r(methods)'"'), "kaplan-meier") > 0

    local found_events = 0
    local found_logrank = 0
    frame review_surv {
        forvalues i = 1/`=_N' {
            if strtrim(c1[`i']) == "Events / N" local found_events = 1
            if strpos(c1[`i'], "Log-rank") > 0 local found_logrank = 1
        }
    }
    assert `found_events' == 1
    assert `found_logrank' == 1
}
if _rc == 0 {
    display as result "  PASS: Cox regtab and grouped survtab contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: Cox regtab and grouped survtab contracts (rc=`=_rc')"
    local ++fail_count
}
capture frame drop review_regcox
capture frame drop review_surv

**# Diagnostic reporting after an estimation command
local ++test_count
capture noisily {
    webuse lbw, clear
    quietly logit low age lwt smoke
    local before_cmd "`e(cmd)'"
    predict double phat, pr

    capture frame drop review_diag
    diagtab phat low, cutoff(0.30) auc frame(review_diag, replace)

    assert "`before_cmd'" == "logit"
    assert "`e(cmd)'" == "logit"
    assert r(TP) + r(FP) + r(FN) + r(TN) == e(N)
    assert r(auc) >= 0 & r(auc) <= 1
    assert "`r(frame)'" == "review_diag"
    assert strpos(lower(`"`r(methods)'"'), "diagnostic accuracy") > 0

    frame review_diag {
        assert _N >= 6
        local found_auc = 0
        forvalues i = 1/`=_N' {
            if strpos(lower(c1[`i']), "auc") > 0 local found_auc = 1
        }
    }
    assert `found_auc' == 1
}
if _rc == 0 {
    display as result "  PASS: diagtab preserves estimation state and reports AUC"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab estimation-state/AUC contract (rc=`=_rc')"
    local ++fail_count
}
capture frame drop review_diag

**# effecttab from() ignores an unrelated active model collect
local ++test_count
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

display as result "review_models QA summary: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    exit 1
}

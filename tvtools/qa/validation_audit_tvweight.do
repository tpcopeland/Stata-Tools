/*******************************************************************************
* validation_audit_tvweight.do
*
* Audit-closure known-answer checks for positivity concentration, coherent
* multinomial probability algebra, panel keys, factor terms, estimate-state
* transactions, and scriptable graph diagnostics.
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-07-13
*******************************************************************************/

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_audit_tvweight.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

display as result "tvtools QA: audit closure for tvweight -- $S_DATE $S_TIME"

**# 1. top-1% mass selects exactly ceil(.01*N) rows, including a tie fixture
local ++test_count
capture noisily {
    foreach n in 37 100 101 {
        clear
        set obs `n'
        generate byte a = mod(_n, 2)
        generate double x = 1
        tvweight a, covariates(x) generate(w) nolog
        local expected_n = ceil(.01 * `n')
        local returned_n = r(n_top1_rows)
        local returned_share = r(top1_wt_share)
        generate long original_order = _n
        gsort -w original_order
        quietly summarize w
        local all_mass = r(sum)
        quietly summarize w in 1/`expected_n'
        local top_mass = r(sum)
        local expected_share = 100 * `top_mass' / `all_mass'
        assert `returned_n' == `expected_n'
        assert abs(`returned_share' - `expected_share') < 1e-10
        if `n' == 100 {
            assert w == 2
            assert abs(`returned_share' - 1) < 1e-10
        }
    }
}
if _rc == 0 {
    display as result "  PASS: top-1% concentration uses an exact row count under ties"
    local ++pass_count
}
else {
    display as error "  FAIL: exact top-1% row mass (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' top1_rows"
}

**# 2. multinomial ATO/matching use one uncapped raw probability vector
local ++test_count
capture noisily {
    clear
    set obs 1200
    generate double x = -6 + 12 * (_n - 1) / 1199
    generate byte a = cond(x < -1, 0, cond(x > 1, 2, 1))
    replace a = 2 in 1
    replace a = 1 in 2
    replace a = 0 in 1200
    replace a = 1 in 1199

    tvweight a, covariates(x) generate(w_ato) wtype(ato) ///
        denominator(pobs_ato) nolog
    local n_extreme = r(n_ps_extreme)
    local n_boundary = r(n_ps_boundary)

    quietly mlogit a x, baseoutcome(0) nolog
    quietly predict double p0, pr outcome(0)
    quietly predict double p1, pr outcome(1)
    quietly predict double p2, pr outcome(2)
    generate double pobs_raw = cond(a == 0, p0, cond(a == 1, p1, p2))
    generate double h_raw = 1 / ((1 / p0) + (1 / p1) + (1 / p2))
    generate double ato_expected = h_raw / pobs_raw
    quietly count if pobs_raw < .001 | pobs_raw > .999
    assert r(N) > 0 & `n_extreme' == r(N)
    assert `n_boundary' == 0
    generate double ato_diff = abs(w_ato - ato_expected)
    generate double pobs_diff = abs(pobs_ato - pobs_raw)
    quietly summarize ato_diff, meanonly
    assert r(max) < 1e-10
    quietly summarize pobs_diff, meanonly
    assert r(max) < 1e-12

    tvweight a, covariates(x) generate(w_match) wtype(matching) ///
        denominator(pobs_match) nolog
    generate double match_expected = min(p0, p1, p2) / pobs_raw
    generate double match_diff = abs(w_match - match_expected)
    quietly summarize match_diff, meanonly
    assert r(max) < 1e-10
    assert abs(pobs_match - pobs_raw) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: extreme multinomial probabilities remain algebraically coherent"
    local ++pass_count
}
else {
    display as error "  FAIL: multinomial probability algebra (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' mlogit_probability_vector"
}

**# 3. every history-dependent mode rejects duplicate id-time keys transactionally
local ++test_count
capture noisily {
    clear
    set seed 20260713
    set obs 120
    generate long id = ceil(_n / 4)
    bysort id: generate byte t = _n
    replace t = 1 in 2
    generate double x = rnormal()
    generate double z = rnormal()
    generate byte a = runiform() < invlogit(.2 + .4*x - .2*z)
    generate byte cens = runiform() < .15
    generate long sentinel = 7000 + _n

    foreach mode in cumulative tvcovariates ipcw {
        local opts "id(id) time(t)"
        if "`mode'" == "cumulative" local opts "`opts' cumulative"
        if "`mode'" == "tvcovariates" local opts "`opts' tvcovariates(z)"
        if "`mode'" == "ipcw" local opts "`opts' ipcw(cens)"
        capture noisily tvweight a, covariates(x) generate(w_`mode') ///
            `opts' nolog
        local cmdrc = _rc
        assert `cmdrc' == 459
        capture confirm variable w_`mode'
        assert _rc == 111
        assert _N == 120 & sentinel[1] == 7001 & sentinel[120] == 7120
    }
}
if _rc == 0 {
    display as result "  PASS: duplicate panel keys fail before any persistent mutation"
    local ++pass_count
}
else {
    display as error "  FAIL: duplicate id-time key contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' duplicate_panel_key"
}

**# 4. factor-variable main effects/interactions work in models and balance
local ++test_count
capture noisily {
    clear
    set seed 8421
    set obs 900
    generate byte g = mod(_n, 3)
    generate double x = rnormal()
    generate double lp = -.4 + .3*x + .35*(g == 1) - .25*(g == 2) ///
        + .2*x*(g == 1) - .15*x*(g == 2)
    generate byte a = runiform() < invlogit(lp)

    quietly logit a i.g c.x##i.g, nolog
    quietly predict double p_manual, pr
    tvweight a, covariates(i.g c.x##i.g) generate(w_fv) ///
        denominator(p_fv) balance nolog
    matrix B_fv = r(balance)
    local balance_terms "`r(balance_terms)'"
    assert rowsof(B_fv) == 5 & colsof(B_fv) == 2
    assert "`balance_terms'" == "1.g 2.g x 1.g#c.x 2.g#c.x"
    generate double fv_diff = abs(p_fv - p_manual)
    quietly summarize fv_diff, meanonly
    assert r(max) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: factor terms and interactions have exact model parity"
    local ++pass_count
}
else {
    display as error "  FAIL: factor-variable support (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' factor_variables"
}

**# 5. stored estimates and caller e() are transactional
local ++test_count
capture noisily {
    clear
    set seed 118
    set obs 500
    generate double x = rnormal()
    generate double z = rnormal()
    generate double y = 2 + x - 2*z + rnormal()
    generate byte a = runiform() < invlogit(.2 + .5*x - .3*z)

    quietly regress y x
    estimates store target_model
    quietly regress y z
    local caller_cmd "`e(cmd)'"
    local caller_rhs : colnames e(b)

    capture noisily tvweight a, covariates(x z) generate(w_blocked) ///
        estname(target_model) nolog
    local cmdrc = _rc
    assert `cmdrc' == 110
    assert "`e(cmd)'" == "`caller_cmd'"
    local after_rhs : colnames e(b)
    assert "`after_rhs'" == "`caller_rhs'"
    capture confirm variable w_blocked
    assert _rc == 111
    estimates restore target_model
    assert "`e(cmd)'" == "regress"
    local stored_rhs : colnames e(b)
    assert strpos("`stored_rhs'", "x") > 0 & strpos("`stored_rhs'", "z") == 0

    quietly regress y z
    tvweight a, covariates(x z) generate(w_replace_est) ///
        estname(target_model) estreplace nolog
    assert "`e(cmd)'" == "regress"
    local restored_rhs : colnames e(b)
    assert "`restored_rhs'" == "`caller_rhs'"
    estimates restore target_model
    assert "`e(cmd)'" == "logit"

    * A failure after estname() has been overwritten must restore both the
    * prior stored estimate and the caller's active estimation results.
    estimates drop target_model
    quietly regress y x if mod(_n, 3) != 0
    generate byte expected_target_sample = e(sample)
    estimates store target_model
    quietly regress y z if mod(_n, 5) != 0
    generate byte expected_caller_sample = e(sample)
    generate long id = ceil(_n / 2)
    bysort id: generate byte t = _n
    generate byte cens = 0
    capture noisily tvweight a, covariates(x z) id(id) time(t) ///
        ipcw(cens) generate(w_late_fail) estname(target_model) ///
        estreplace nolog
    local late_rc = _rc
    assert `late_rc' != 0
    assert "`e(cmd)'" == "regress"
    local late_caller_rhs : colnames e(b)
    assert strpos("`late_caller_rhs'", "z") > 0
    assert e(sample) == expected_caller_sample
    predict double caller_xb_after if e(sample), xb
    assert !missing(caller_xb_after) if expected_caller_sample
    capture confirm variable w_late_fail
    assert _rc == 111
    capture confirm variable ipcw
    assert _rc == 111
    estimates restore target_model
    assert "`e(cmd)'" == "regress"
    local restored_target_rhs : colnames e(b)
    assert strpos("`restored_target_rhs'", "x") > 0
    assert strpos("`restored_target_rhs'", "z") == 0
    assert e(sample) == expected_target_sample
    predict double target_xb_after if e(sample), xb
    assert !missing(target_xb_after) if expected_target_sample
}
if _rc == 0 {
    display as result "  PASS: estimate targets and active e() require explicit replacement"
    local ++pass_count
}
else {
    display as error "  FAIL: estimate-state transaction (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' estimate_transaction"
}

**# 6. optional graph outcomes are returned, not only printed
local ++test_count
capture noisily {
    clear
    set seed 919
    set obs 400
    generate double x = rnormal()
    generate byte a = runiform() < invlogit(.2 + .4*x)
    capture graph drop tvw_histogram
    tvweight a, covariates(x) generate(w_graph) histogram nolog
    assert r(histogram_created) == 1
    assert r(loveplot_created) == 0
    assert r(graph_created) == 1
    graph dir tvw_histogram
    graph drop tvw_histogram
}
if _rc == 0 {
    display as result "  PASS: graph creation is machine-readable"
    local ++pass_count
}
else {
    display as error "  FAIL: graph creation returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' graph_returns"
}

**# 7. top-1% diagnostic uses the final combined IPTW-IPCW weight
local ++test_count
capture noisily {
    clear
    set seed 4447
    set obs 600
    generate long id = ceil(_n / 3)
    bysort id: generate byte t = _n
    generate double x = rnormal()
    generate byte a = runiform() < invlogit(.1 + .4*x + .1*t)
    generate byte cens = runiform() < invlogit(-2.2 + .25*x + .1*t)
    tvweight a, covariates(x) id(id) time(t) ipcw(cens) ///
        generate(w_treat) censgenerate(w_cens) combgenerate(w_final) nolog
    local returned_share = r(top1_wt_share)
    local returned_n = r(n_top1_rows)
    local ntop = ceil(.01 * r(N))
    assert `returned_n' == `ntop'
    generate long original_order = _n
    gsort -w_final original_order
    quietly summarize w_final
    local all_mass = r(sum)
    quietly summarize w_final in 1/`ntop'
    local top_mass = r(sum)
    local expected_share = 100 * `top_mass' / `all_mass'
    assert abs(`returned_share' - `expected_share') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: final combined weight drives the exact-rank diagnostic"
    local ++pass_count
}
else {
    display as error "  FAIL: combined top-1% diagnostic (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' combined_top1"
}

**# 8. censor-model exclusions cannot become fabricated finite IPCW values
local ++test_count
capture noisily {
    clear
    set seed 8801
    set obs 200
    generate long id = _n
    generate byte t = 1
    generate double z = rnormal()
    generate byte a = runiform() < invlogit(.2 + .35*z)
    generate byte x_sep = (_n <= 20)
    generate byte cens = x_sep
    replace cens = mod(_n, 4) == 0 if !x_sep
    generate long sentinel = 90000 + _n

    capture noisily tvweight a, covariates(z) id(id) time(t) ///
        ipcw(cens) censorcovariates(x_sep) generate(w_bad_cens) ///
        censgenerate(cw_bad_cens) combgenerate(wc_bad_cens) nolog
    local cmdrc = _rc
    assert `cmdrc' == 498
    foreach v in w_bad_cens cw_bad_cens wc_bad_cens {
        capture confirm variable `v'
        assert _rc == 111
    }
    assert _N == 200 & sentinel[1] == 90001 & sentinel[200] == 90200
}
if _rc == 0 {
    display as result "  PASS: censor-model prediction exclusions fail transactionally"
    local ++pass_count
}
else {
    display as error "  FAIL: censor-model probability boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' censor_probability_boundary"
}

**# 9. finite extreme uncensoring probabilities are reported but retained raw
local ++test_count
capture noisily {
    clear
    set obs 2200
    generate long id = _n
    generate byte t = 1
    generate byte x_hi = (_n > 1100)
    generate double z = sin(_n / 37)
    generate byte a = mod(_n, 2)
    generate byte cens = x_hi
    replace cens = 1 in 1
    replace cens = 0 in 2200

    tvweight a, covariates(z) id(id) time(t) ipcw(cens) ///
        censorcovariates(x_hi) generate(w_ext_cens) ///
        censgenerate(cw_ext_cens) combgenerate(wc_ext_cens) nolog
    local returned_extreme = r(n_cens_extreme)
    local returned_boundary = r(n_cens_boundary)

    * With an intercept and binary x_hi, the model is saturated: each fitted
    * censoring probability is its group's observed proportion. Stata's
    * convergence tolerance permits tiny drift at this extreme, so compare by
    * relative difference to the analytic group oracle.
    generate double punc_manual = cond(x_hi, 1/1100, 1099/1100)
    generate double cw_manual = 1 / punc_manual
    quietly count if punc_manual < .001 | punc_manual > .999
    local expected_extreme = r(N)
    assert `expected_extreme' == 2200
    assert `returned_extreme' == `expected_extreme'
    assert `returned_boundary' == 0
    generate double cw_ext_reldif = reldif(cw_ext_cens, cw_manual)
    quietly summarize cw_ext_reldif, meanonly
    assert r(max) < 2e-4
    quietly summarize cw_ext_cens if x_hi, meanonly
    assert r(mean) > 1050
}
if _rc == 0 {
    display as result "  PASS: finite extreme censoring probabilities retain raw algebra"
    local ++pass_count
}
else {
    display as error "  FAIL: raw finite-extreme IPCW algebra (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' censor_probability_extremes"
}

display "RESULT: validation_audit_tvweight tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}

capture graph drop _all
capture estimates drop target_model
capture log close _all

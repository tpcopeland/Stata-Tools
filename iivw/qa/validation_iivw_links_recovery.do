clear all
set more off
version 16.0
set varabbrev off

* validation_iivw_links_recovery.do
* Tests: 7
*
* WHAT THIS COVERS
* ----------------
* Known-truth recovery of the weighted GEE point estimate for the Poisson-log and
* binomial-logit links in an INFORMATIVE-VISIT design: iivw_weight (IIW, visit model
* on the observed visit driver Z) then iivw_fit, family(poisson|binomial), vce(fixed).
* The unweighted fit on the same data is biased (sanity contrast). Parity of the weighted
* link fits against geeglm already lives in crossval_iivw_external.do.
*
* ORACLE: the truth set in the DGP (_iivw_links_dgp.do header has the full DGP and the
* derivation). TRUTH IS THE MARGINAL (population-average) COEFFICIENT, not the conditional
* one in the outcome equation:
*   poisson: exact by construction, b_x = .3 + ln[(1-pz1+pz1 e^C)/(1-pz0+pz0 e^C)] = 1.0906
*            (conditional .3), b_t = .2;
*   logit:   the marginal curve is not logistic; truth = root of the population estimating
*            equations from deterministic quadrature over (x, Z, subject effect, t) in
*            _lk_truth (no Monte Carlo error): DGP1 b_x 1.1132, b_t .2386; DGP2 .9319,
*            .2022 (conditional .3 and .25).
* Two structurally different DGPs per link: DGP1 constant baseline visit intensity, no
* subject effect; DGP2 rising baseline intensity .6(1+t) plus a subject effect (gamma
* frailty for counts, N(0,1) random intercept for the logit) that does not drive visits.
*
* TOLERANCE (TOLERANCE_FRAMEWORK.md Class M): PASS iff |mean(b) - truth| < 3 * MCSE,
* MCSE = SD(b)/sqrt(R), computed in the suite. Every replicate must fit (n_ok == R).
*   T1 poisson DGP1   T2 poisson DGP2   T3 logit DGP1   T4 logit DGP2
*      (n = 1000 subjects, R = 200; weighted b_x and b_t recover; the unweighted b_x MISSES
*      by > 3 MCSE; the weighted b_x also MISSES the CONDITIONAL .3 by > 3 MCSE, proving
*      the marginal parameter is the right target)
*   T5 scale: n = 4000, R = 20, all four cells, weighted b_x and b_t within 3 MCSE
*   T6 truth construction: the quadrature machinery reproduces the closed-form Poisson
*      truth (b_x, b_t) to 1e-6, and the logit marginal b_x differs from the conditional
*      by > .5 (collapsibility does not hide behind the tolerance)
*   T7 seed ledger: first replicate of T1 replays from its c(rngstate)
* Seeds: set seed 20261401 (T1), 20261402 (T2), 20261403 (T3), 20261404 (T4), 20261405
* (T5, per cell: seed + cell index), set once per block.
* DGP NOTE (found in exploration): the first DGP draft dropped subjects with no visit in
* (0, tau] from the carrier rows; that is a selection on the visit count (it lowered the
* Cox visit coefficient to 1.15 vs the true 1.2 and left a -0.008 bias, z = 3.3, that the
* weights cannot undo). Carrier rows are now built from the full subject table, and the
* visit coefficient matches the direct Poisson-count MLE exactly.
* WORKED RUN (weighted b_x bias, MCSE in parentheses; unweighted b_x bias / z)
*   poisson DGP1 n=1000 R=200: -0.0018 (.0025); unweighted -0.245 (z 84)
*   poisson DGP2:              -0.0012 (.0040); unweighted -0.243 (z 50)
*   logit   DGP1:              +0.0038 (.0044); unweighted -0.132 (z 30)
*   logit   DGP2:              -0.0003 (.0055); unweighted -0.112 (z 19)
*   n=4000 R=20: all eight b_x/b_t biases within 3 MCSE

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "validation_iivw_links_recovery.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap
do "`qa_dir'/_iivw_links_dgp.do"

local MCSE_K = 3
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _lk_mc
program define _lk_mc
    version 16.0
    syntax , DGP(integer) LINK(string) N(integer) R(integer) FILE(string) SEED(integer)
    local fam = cond("`link'" == "logit", "binomial", "poisson")
    tempname P
    postfile `P' int rep int rc double(bx bt bu) using "`file'", replace
    set seed `seed'
    forvalues r = 1/`r' {
        _lk_gen, dgp(`dgp') link(`link') n(`n')
        local bx = .
        local bt = .
        local bu = .
        capture quietly {
            iivw_fit y x, unweighted id(id) time(t) family(`fam') timespec(linear) nolog
            local bu = _b[x]
            iivw_weight, id(id) time(t) visit_cov(Z) wtype(iivw) maxfu(3) baseline(entry) nolog replace
            iivw_fit y x, family(`fam') vce(fixed) timespec(linear) nolog replace
            local bx = _b[x]
            local bt = _b[t]
        }
        post `P' (`r') (_rc) (`bx') (`bt') (`bu')
    }
    postclose `P'
end

capture program drop _lk_verdict
program define _lk_verdict, rclass
    syntax , VAR(string) TRUTH(real) K(real) R(integer)
    quietly summarize `var'
    local nok = r(N)
    local mean = r(mean)
    local mcse = r(sd) / sqrt(r(N))
    return scalar ok = (`nok' == `r') & (abs(`mean' - `truth') < `k' * `mcse') & (`mcse' < .)
    return scalar bias = `mean' - `truth'
    return scalar mcse = `mcse'
    return scalar n = `nok'
    return scalar z = abs(`mean' - `truth') / `mcse'
end

* one cell test: recovery of weighted b_x, b_t; contrast with unweighted and conditional
capture program drop _lk_cell
program define _lk_cell, rclass
    syntax , DGP(integer) LINK(string) N(integer) R(integer) SEED(integer) K(real) ///
        [CONTRAST]
    tempfile f
    _lk_truth, dgp(`dgp') link(`link')
    local tbx = r(bx)
    local tbt = r(bt)
    _lk_mc, dgp(`dgp') link(`link') n(`n') r(`r') file("`f'") seed(`seed')
    use "`f'", clear
    quietly count if rc != 0
    local nfail = r(N)
    _lk_verdict, var(bx) truth(`tbx') k(`k') r(`r')
    local ok = r(ok)
    display as text "  `link' dgp`dgp' n=`n': truth b_x " %8.4f `tbx' " weighted bias " %8.4f r(bias) " (MCSE " %7.4f r(mcse) ", z " %5.2f r(z) ")"
    _lk_verdict, var(bt) truth(`tbt') k(`k') r(`r')
    local ok = `ok' & r(ok)
    display as text "  `link' dgp`dgp' n=`n': truth b_t " %8.4f `tbt' " weighted bias " %8.4f r(bias) " (MCSE " %7.4f r(mcse) ", z " %5.2f r(z) ")"
    return scalar ok = `ok' & (`nfail' == 0)
    if "`contrast'" != "" {
        _lk_verdict, var(bu) truth(`tbx') k(`k') r(`r')
        display as text "  `link' dgp`dgp': UNWEIGHTED b_x bias " %8.4f r(bias) " (z " %6.1f r(z) ") -> must miss"
        return scalar unw_miss = (r(ok) == 0) & (r(n) == `r')
        _lk_verdict, var(bx) truth(.3) k(`k') r(`r')
        display as text "  `link' dgp`dgp': weighted b_x vs CONDITIONAL .3: z " %6.1f r(z) " -> must miss"
        return scalar cond_miss = (r(ok) == 0) & (r(n) == `r')
    }
end

local cells "poisson:1:1:20261401 poisson:2:2:20261402 logit:1:3:20261403 logit:2:4:20261404"
foreach c of local cells {
    tokenize "`c'", parse(":")
    local link `1'
    local dgp `3'
    local tn `5'
    local sd `7'
    if `run_only' == 0 | `run_only' == `tn' {
        local ++test_count
        capture noisily {
            _lk_cell, dgp(`dgp') link(`link') n(1000) r(200) seed(`sd') k(`MCSE_K') contrast
            assert r(ok) == 1
            assert r(unw_miss) == 1
            assert r(cond_miss) == 1
        }
        if _rc == 0 {
            display as result "  PASS: T`tn' `link' DGP`dgp' weighted recovers marginal b_x, b_t; unweighted and conditional miss"
            local ++pass_count
        }
        else {
            display as error "  FAIL: T`tn' `link' DGP`dgp'"
            local ++fail_count
            local failed_tests "`failed_tests' T`tn'"
        }
    }
    else {
        local ++test_count
    }
}

**# T5: scale
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        local allok 1
        local i 0
        foreach c of local cells {
            tokenize "`c'", parse(":")
            local ++i
            _lk_cell, dgp(`3') link(`1') n(4000) r(20) seed(`=20261405 + `i'') k(`MCSE_K')
            if r(ok) != 1 local allok 0
        }
        assert `allok' == 1
    }
    if _rc == 0 {
        display as result "  PASS: T5 recovery holds at n=4000 in all four cells"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T5 scale"
        local ++fail_count
        local failed_tests "`failed_tests' T5"
    }
}

**# T6: truth construction
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        * Poisson closed form vs the Z-averaged marginal mean fitted numerically on a t grid
        clear
        quietly set obs 4
        gen byte cell = _n
        gen byte x = inlist(cell, 3, 4)
        gen byte Z = inlist(cell, 2, 4)
        quietly expand 80
        bysort cell: gen int j = _n
        gen double t = (j - .5) / 80 * 3
        gen double pzx = cond(x == 1, .85, .15)
        gen double wz = cond(Z == 1, pzx, 1 - pzx)
        gen double mu = exp(.3*x + .2*t + 1.2*Z) * wz
        collapse (sum) m = mu, by(x t)
        quietly glm m x t, family(poisson) link(log) vce(robust) nolog
        local qx = _b[x]
        local qt = _b[t]
        _lk_truth, dgp(1) link(poisson)
        display as text "  Poisson closed form b_x " %10.7f r(bx) " vs numeric " %10.7f `qx' "; b_t " %10.7f r(bt) " vs " %10.7f `qt'
        assert abs(r(bx) - `qx') < 1e-6 & abs(r(bt) - `qt') < 1e-6
        * logit marginal vs conditional
        foreach d in 1 2 {
            _lk_truth, dgp(`d') link(logit)
            display as text "  logit DGP`d' marginal b_x " %8.4f r(bx) " vs conditional .3"
            assert r(bx) < . & abs(r(bx) - .3) > .5
        }
    }
    if _rc == 0 {
        display as result "  PASS: T6 truth constructions are internally consistent"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T6 truth construction"
        local ++fail_count
        local failed_tests "`failed_tests' T6"
    }
}

**# T7: replay
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        tempfile f
        set seed 20261401
        local st0 = c(rngstate)
        _lk_gen, dgp(1) link(poisson) n(1000)
        quietly iivw_weight, id(id) time(t) visit_cov(Z) wtype(iivw) maxfu(3) baseline(entry) nolog replace
        quietly iivw_fit y x, family(poisson) vce(fixed) timespec(linear) nolog replace
        local b1 = _b[x]
        set rngstate `st0'
        _lk_gen, dgp(1) link(poisson) n(1000)
        quietly iivw_weight, id(id) time(t) visit_cov(Z) wtype(iivw) maxfu(3) baseline(entry) nolog replace
        quietly iivw_fit y x, family(poisson) vce(fixed) timespec(linear) nolog replace
        local b2 = _b[x]
        assert `b1' < . & `b1' == `b2'
        _lk_mc, dgp(1) link(poisson) n(1000) r(1) file("`f'") seed(20261401)
        use "`f'", clear
        assert abs(bx[1] - `b1') < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS: T7 first replicate replays from its seed/rngstate"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T7 replay"
        local ++fail_count
        local failed_tests "`failed_tests' T7"
    }
}

**# Summary
iivw_qa_summary, name(validation_iivw_links_recovery) tests(`test_count') pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests(`failed_tests')

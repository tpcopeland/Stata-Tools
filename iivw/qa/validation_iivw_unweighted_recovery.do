clear all
set more off
version 16.0
set varabbrev off

* validation_iivw_unweighted_recovery.do
* Tests: 5
*
* WHAT THIS COVERS
* ----------------
* Known-truth recovery for `iivw_fit, unweighted' (independence-GEE via glm with a
* cluster-robust sandwich). Visits are NON-informative, so the unweighted fit is
* consistent for the population-average mean parameters set in the DGP.
*
* ORACLE: the truth set in the DGP (_iivw_unw_dgp.do). Two structurally different
* DGPs: A = subject random intercept with a subject-level binary x; B = time-varying
* x that trends with time, random intercept + random slope, heteroscedastic error.
* Identity link, so the conditional and population-average parameters coincide by
* construction (header of _iivw_unw_dgp.do). No other estimator supplies the truth.
*
* TOLERANCE (TOLERANCE_FRAMEWORK.md Class M): per coefficient, PASS iff
* |mean(b) - truth| < 3 * MCSE with MCSE = SD(b)/sqrt(R), computed below. No typed
* tolerance. Every replicate must fit (n_ok == R) or the test fails.
*   T1  DGP A, n = 300, R = 500   b_x, b_t, b_cons
*   T2  DGP B, n = 300, R = 500   b_x, b_t, b_cons
*   T3  scale: both DGPs at n = 100 and n = 1200 (R = 300 each); bias within 3 MCSE
*       at both sizes AND the MCSE shrinks with n (the estimator's spread is not
*       dominated by a fixed component)
*   T4  scenario bites: in DGP B, dropping time (timespec(none)) must MISS b_x by
*       more than 3 MCSE, so the recovery in T2 is not vacuous (x trends with t)
*   T5  seed ledger: the first replicate of T1 reproduces from its stored
*       c(rngstate) (the replicates are replayable)
* Seeds: set seed 20261101 once for T1; 20261102 (T2); 20261103 (T3 n=100);
* 20261104 (T3 n=1200); T4 reuses the T2 replicates (same data, extra fit).
*
* WORKED RUN (first run, tolerances unchanged afterwards; bias, MCSE in parentheses)
*   DGP A n=300 R=500: b_x -0.0087 (.0065)  b_t -0.0001 (.0010)  b_cons +0.0041 (.0048)
*   DGP B n=300 R=500: b_x -0.0034 (.0021)  b_t +0.0010 (.0019)  b_cons -0.0014 (.0039)
*   scale, all |bias| < 3 MCSE at n=100 and n=1200 in both DGPs
*   DGP B with time omitted: b_x bias -0.118 = 62.7 MCSE (the comparator bites)

args run_only
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "validation_iivw_unweighted_recovery.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap
do "`qa_dir'/_iivw_unw_dgp.do"

local MCSE_K = 3
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* _unw_mc: R replicates of DGP `dgp' at size `n'; posts b/se for cons, x, t, plus the
* time-free x slope. Result file `file'.
capture program drop _unw_mc
program define _unw_mc
    version 16.0
    syntax , DGP(string) N(integer) R(integer) FILE(string) SEED(integer)
    tempname P
    postfile `P' int rep int rc double(b_x b_t b_c b_x_notime) using "`file'", replace
    set seed `seed'
    forvalues r = 1/`r' {
        _unw_gen, dgp(`dgp') n(`n')
        capture quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
        local rc = _rc
        local bx = .
        local bt = .
        local bc = .
        local bn = .
        if `rc' == 0 {
            local bx = _b[x]
            local bt = _b[t]
            local bc = _b[_cons]
            capture quietly iivw_fit y x, unweighted id(id) time(t) timespec(none) nolog
            if _rc == 0 local bn = _b[x]
        }
        post `P' (`r') (`rc') (`bx') (`bt') (`bc') (`bn')
    }
    postclose `P'
end

* _unw_verdict: |mean - truth| < K*MCSE for one column; returns bias, mcse, ok
capture program drop _unw_verdict
program define _unw_verdict, rclass
    syntax , VAR(string) TRUTH(real) K(real) R(integer)
    quietly summarize `var'
    local nok = r(N)
    local mean = r(mean)
    local mcse = r(sd) / sqrt(r(N))
    local ok = (`nok' == `r') & (abs(`mean' - `truth') < `k' * `mcse') & (`mcse' < .)
    return scalar bias = `mean' - `truth'
    return scalar mcse = `mcse'
    return scalar n = `nok'
    return scalar ok = `ok'
end

tempfile fA fB f100 f1200

**# T1: DGP A, n=300, R=500
local ++test_count
local R1 = 500
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _unw_mc, dgp(A) n(300) r(`R1') file("`fA'") seed(20261101)
        use "`fA'", clear
        count if rc != 0
        assert r(N) == 0
        local allok 1
        foreach c in x:.5 t:.3 c:1 {
            gettoken v tr : c, parse(":")
            local tr = substr("`tr'", 2, .)
            _unw_verdict, var(b_`v') truth(`tr') k(`MCSE_K') r(`R1')
            display as text "  DGP A b_`v': truth `tr' bias " %9.5f r(bias) " MCSE " %8.5f r(mcse) " ok=" r(ok)
            if r(ok) != 1 local allok 0
        }
        assert `allok' == 1
    }
    if _rc == 0 {
        display as result "  PASS: T1 DGP A recovers b_x, b_t, b_cons within 3 MCSE"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T1 DGP A recovery"
        local ++fail_count
        local failed_tests "`failed_tests' T1"
    }
}

**# T2: DGP B, n=300, R=500
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _unw_mc, dgp(B) n(300) r(`R1') file("`fB'") seed(20261102)
        use "`fB'", clear
        count if rc != 0
        assert r(N) == 0
        local allok 1
        foreach c in x:.7 t:-.4 c:2 {
            gettoken v tr : c, parse(":")
            local tr = substr("`tr'", 2, .)
            _unw_verdict, var(b_`v') truth(`tr') k(`MCSE_K') r(`R1')
            display as text "  DGP B b_`v': truth `tr' bias " %9.5f r(bias) " MCSE " %8.5f r(mcse) " ok=" r(ok)
            if r(ok) != 1 local allok 0
        }
        assert `allok' == 1
        * T4 piggybacks on these same data: the time-free fit must miss b_x
        _unw_verdict, var(b_x_notime) truth(.7) k(`MCSE_K') r(`R1')
        display as text "  DGP B time-free b_x: bias " %9.5f r(bias) " MCSE " %8.5f r(mcse)
        scalar _t4_ok = (r(ok) == 0) & (r(n) == `R1')
        scalar _t4_bias = r(bias)
        scalar _t4_mcse = r(mcse)
    }
    if _rc == 0 {
        display as result "  PASS: T2 DGP B recovers b_x, b_t, b_cons within 3 MCSE"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T2 DGP B recovery"
        local ++fail_count
        local failed_tests "`failed_tests' T2"
    }
}

**# T3: scale (n = 100 vs 1200), both DGPs
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        local R3 = 300
        local allok 1
        foreach d in A B {
            local tx = cond("`d'" == "A", .5, .7)
            local tt = cond("`d'" == "A", .3, -.4)
            _unw_mc, dgp(`d') n(100) r(`R3') file("`f100'") seed(20261103)
            use "`f100'", clear
            _unw_verdict, var(b_x) truth(`tx') k(`MCSE_K') r(`R3')
            local m100 = r(mcse)
            if r(ok) != 1 local allok 0
            display as text "  DGP `d' n=100  b_x bias " %9.5f r(bias) " MCSE " %8.5f r(mcse) " ok=" r(ok)
            _unw_verdict, var(b_t) truth(`tt') k(`MCSE_K') r(`R3')
            if r(ok) != 1 local allok 0
            display as text "  DGP `d' n=100  b_t bias " %9.5f r(bias) " MCSE " %8.5f r(mcse) " ok=" r(ok)
            _unw_mc, dgp(`d') n(1200) r(`R3') file("`f1200'") seed(20261104)
            use "`f1200'", clear
            _unw_verdict, var(b_x) truth(`tx') k(`MCSE_K') r(`R3')
            local m1200 = r(mcse)
            if r(ok) != 1 local allok 0
            display as text "  DGP `d' n=1200 b_x bias " %9.5f r(bias) " MCSE " %8.5f r(mcse) " ok=" r(ok)
            _unw_verdict, var(b_t) truth(`tt') k(`MCSE_K') r(`R3')
            if r(ok) != 1 local allok 0
            display as text "  DGP `d' n=1200 b_t bias " %9.5f r(bias) " MCSE " %8.5f r(mcse) " ok=" r(ok)
            * spread shrinks ~ 1/sqrt(n): 12x the subjects must cut MCSE by well over 2x
            assert `m1200' < . & `m100' < . & `m1200' < `m100' / 2
        }
        assert `allok' == 1
    }
    if _rc == 0 {
        display as result "  PASS: T3 recovery holds at n=100 and n=1200 and spread shrinks with n"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T3 scale"
        local ++fail_count
        local failed_tests "`failed_tests' T3"
    }
}

**# T4: scenario bites (time omitted must miss b_x in DGP B)
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        if `run_only' == 4 {
            _unw_mc, dgp(B) n(300) r(`R1') file("`fB'") seed(20261102)
            use "`fB'", clear
            _unw_verdict, var(b_x_notime) truth(.7) k(`MCSE_K') r(`R1')
            scalar _t4_ok = (r(ok) == 0) & (r(n) == `R1')
            scalar _t4_bias = r(bias)
            scalar _t4_mcse = r(mcse)
        }
        display as text "  time-free b_x bias " %9.5f scalar(_t4_bias) " (" %6.1f abs(scalar(_t4_bias)) / scalar(_t4_mcse) " MCSE)"
        assert scalar(_t4_ok) == 1
    }
    if _rc == 0 {
        display as result "  PASS: T4 comparator (time omitted) misses b_x in DGP B"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T4 scenario does not bite"
        local ++fail_count
        local failed_tests "`failed_tests' T4"
    }
}

**# T5: replicate replay from stored rngstate
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        set seed 20261101
        local st0 = c(rngstate)
        _unw_gen, dgp(A) n(300)
        quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
        local b1 = _b[x]
        set rngstate `st0'
        _unw_gen, dgp(A) n(300)
        quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
        local b2 = _b[x]
        assert `b1' < . & `b2' < .
        assert `b1' == `b2'
        * and it is the same draw T1 used for its first replicate
        _unw_mc, dgp(A) n(300) r(1) file("`fA'") seed(20261101)
        use "`fA'", clear
        assert abs(b_x[1] - `b1') < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS: T5 first replicate replays from its seed/rngstate"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T5 replay"
        local ++fail_count
        local failed_tests "`failed_tests' T5"
    }
}

**# Summary
iivw_qa_summary, name(validation_iivw_unweighted_recovery) tests(`test_count') pass(`pass_count') fail(`fail_count') runonly(`run_only') failedtests(`failed_tests')

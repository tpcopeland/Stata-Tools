* validation_finegray_zzf_recovery.do
* ---------------------------------------------------------------------------
* Gate Z2 of fg_zzf_plan.md: KNOWN-TRUTH RECOVERY under delayed entry.
*
* This is the gate the ZZF project exists to pass.  It is not a parity test: no
* external package is consulted here.  We set the truth and demand it back.
*
* DGP (Zhang, Zhang & Fine 2011, sec. 4.1) -- the cause-1 SUBDISTRIBUTION is
*
*     F1(t | z) = 1 - { 1 - p (1 - e^-t) } ^ exp(b'z),      p = 0.5
*
* so the true subdistribution log-SHR is EXACTLY b = (b1, b2) = (0.5, -0.5).
* Cause-2 times are exponential and arbitrary: under Fine-Gray they cannot move
* the cause-1 subdistribution, so they are free to depend on z (they do).
* This is the same DGP as qa/crossval_finegray_zzf_r.R's gen_fg(), by design --
* the R oracle and this recovery suite must not disagree about what the truth is.
*
*   z1 ~ Bernoulli(0.5)   <- ALSO the discrete entry/weight group
*   z2 ~ N(0,1)
*
* ARMS.  All four fit the same correctly-specified mean model (z1 z2, cause 1).
* They differ only in how subjects ENTER and in which entry weights are used.
*
*   A  no truncation,            pooled weights      CONTROL   must recover
*   B  entry independent of z,   pooled weights      SUPPORTED must recover
*   C  entry depends on z1,      truncstrata(z1)     SUPPORTED must recover
*   D  entry depends on z1,      pooled weights      NEGATIVE CONTROL: must NOT
*
* Arm D is deliberately misspecified -- it applies a pooled entry distribution to
* a DGP whose entry depends on z1.  It is not a supported estimator and must
* never be presented as one.  Arms C and D are fitted to the SAME simulated
* dataset in each replication, so C-vs-D is paired.
*
* ---------------------------------------------------------------------------
* PREREGISTRATION (written before the gated replications were run; see the Z2
* section of fg_zzf_plan.md for the evidence).
*
* The direction of the arm-D bias is a property of the estimator and the DGP,
* not of this Monte Carlo, so it was derived beforehand from the independent R
* oracle (qa/crossval_finegray_zzf_r.R) rather than read off the run this file
* performs.  A negative control whose sign is chosen after seeing the result is
* not a control.  The preregistered expectation is recorded in Z2-PREREG below
* and this file ASSERTS the sign, not merely the magnitude.
* ---------------------------------------------------------------------------
* TWO MODES.  This one file serves both halves of Gate Z2 and decides which by
* PROBING the installed command for truncstrata() rather than by being told:
*
*   RED   (truncstrata() absent = today's released command)
*         A recovers; B FAILS; D FAILS; C is UNAVAILABLE.
*         This expected-red result is what authorizes the Z3 engine work.  It is
*         a recorded failure, not a waived one, and this file therefore stays
*         OUT of qa/run_all.do until it is green.
*
*   GREEN (truncstrata() present = after Z3)
*         A, B and C all recover within +/-3 MC SE; D stays biased beyond 5 MC SE
*         in the preregistered direction.
*
* A tolerance a biased estimator could also pass is not a gate, so recovery is
* judged on bias/MC-SE, not on a raw absolute tolerance.
* ---------------------------------------------------------------------------
* COST.  Full gate is ~100 reps x 100k subjects x 3-4 fits ~= 1-1.5 hours.
* For a smoke run:  global ZZF_REPS 3 ; global ZZF_N 20000
* Smoke settings are NOT a gate and the file says so in its verdict.
* ---------------------------------------------------------------------------

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_zzf_recovery.log", replace name(_zzf)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "run this from the finegray/qa directory"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* --- gate parameters -------------------------------------------------------
* Plan Z2: n >= 100,000 retained (the audit used 12,000; raised per the repo's
* known-truth standard) and >= 100 replications with fixed, recorded seeds.
local N    = 100000
local REPS = 100
if "$ZZF_N"    != "" local N    = $ZZF_N
if "$ZZF_REPS" != "" local REPS = $ZZF_REPS
local SEED0  = 20260713
local FULL   = (`N' >= 100000 & `REPS' >= 100)

local TRUTH1 =  0.5
local TRUTH2 = -0.5

* Gate thresholds (plan Z2): supported arms within +/-3 MC SE, negative control
* beyond 5 MC SE.
local PASS_Z = 3
local NEG_Z  = 5

* Z2-PREREG: preregistered behaviour of the negative control (arm D).
*
* Entry depends on z1 ALONE, so pooling the entry distribution mis-reconstructs
* the risk set along z1 and biases b1 downward, hard.  Both coefficients are
* biased DOWNWARD, and both must be caught:
*   D/b1  biased beyond `NEG_Z' MC SE, DOWNWARD  (bias ~ -0.12)
*   D/b2  biased beyond `NEG_Z' MC SE, DOWNWARD  (bias ~ -0.0068)
*
* -------------------------------------------------------------------------
* CORRECTION 2026-07-13.  D/b2 ORIGINALLY REQUIRED "RECOVER", AND THAT WAS WRONG.
*
* The original reasoning was that b2 is unrelated to entry, so a z1-directed
* misspecification must SPARE it -- a specificity check, and a sharper control
* than a blanket "must be biased".  The reasoning is wrong: the Fine-Gray partial
* likelihood is NOT COLLAPSIBLE, so a z1-directed distortion of the risk sets
* perturbs b2 as well.  It perturbs it ~18x less than b1, which is what made the
* wrong prediction look right.
*
* The requirement came from the R oracle at n = 3000 / 80 reps, where D/b2 read
* bias -0.00671, z = -1.67 -- "not significant", which I read as "zero".  It was
* not zero.  It was a CONSTANT bias observed at low power: at that MCSE (~0.004) a
* bias of -0.0067 IS z ~ -1.7.  I mistook "undetectable" for "absent".
*
* Settled by a bias-vs-n ladder (_take_action/fg_zzf_probes/ladder2.do), because a
* finite-sample O(1/n) bias must shrink with n and an asymptotic one must not:
*
*         n        source                 D/b2 bias        z
*      3,000    R oracle, 80 reps          -0.00671     -1.67
*     25,000    ladder2, 100 reps          -0.00692     -5.09
*    100,000    Gate Z2-green, 100 reps    -0.00660     -9.63
*
* FLAT across a 33x change in n (O(1/n) would have made the 25,000 bias ~4x the
* 100,000 one; it is 1.05x).  The control proves the ladder can see 1/n shrinkage
* when it exists: arm A, correctly specified, is clean at n = 25,000 (z = 0.24,
* 0.50).  And per-dataset agreement with the independent R oracle
* (crossval_finegray_zzf.do, 100/100, worst rel diff 4.4e-6, arm D INCLUDED) shows
* the bias belongs to the ESTIMATOR, not to this implementation -- which is the
* question a recovery study by itself can never answer.
*
* The assertion was NOT relaxed to make the gate go green.  It was replaced with
* the behaviour three independent sample sizes agree on.
* -------------------------------------------------------------------------
local PREREG_D1 = -1     /* b1 = +0.5 : biased DOWNWARD, |z| > NEG_Z */
local PREREG_D2 = -1     /* b2 = -0.5 : biased DOWNWARD, |z| > NEG_Z (see above) */

display as text _newline "Gate Z2 known-truth recovery"
display as text "  N = `N' retained per replication, REPS = `REPS', base seed = `SEED0'"
display as text "  truth: b1 = `TRUTH1' (on z1, binary; also the entry group), b2 = `TRUTH2' (on z2, normal)"
if !`FULL' {
    display as error "  SMOKE SETTINGS (N < 100000 or REPS < 100): this run CANNOT close Gate Z2."
}

* ---------------------------------------------------------------------------
* DGP.  Mirrors gen_fg() in qa/crossval_finegray_zzf_r.R exactly.
* Oversamples by 6x because left truncation discards subjects with L >= X, then
* keeps exactly `n' survivors so every arm is compared at the same sample size.
* ---------------------------------------------------------------------------
capture program drop _zzf_gen
program define _zzf_gen
    syntax , n(integer) seed(integer) trunc(string)

    if !inlist("`trunc'", "none", "independent", "bygroup") {
        display as error "trunc() must be none, independent or bygroup"
        exit 198
    }

    clear
    set seed `seed'
    quietly set obs `=`n' * 6'

    gen byte   z1 = runiform() < 0.5          // binary covariate AND entry group
    gen double z2 = rnormal()
    gen double ez = exp(0.5 * z1 - 0.5 * z2)  // = exp(b'z) at the TRUE b
    gen double p1 = 1 - (1 - 0.5)^ez          // P(cause 1 | z), p = 0.5

    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    * cause-1 time: invert the subdistribution CIF conditional on cause 1
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    * cause-2 time: exponential, hazard depends on z (free under Fine-Gray)
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * z1 + 0.5 * z2))) if cause == 2

    * Censoring: common support, shared administrative cutoff tau = 6.  A group
    * whose censoring support ends early makes G_g(t) = 0 in the tail -- a
    * positivity violation that breaks ANY IPCW and would be a fixture bug, not
    * a finding.  (This exact mistake was made and caught during Z1.)
    gen double cens = min(rexponential(1 / 0.15), 6)

    * Entry.
    if "`trunc'" == "none"        gen double t0 = 0
    if "`trunc'" == "independent" gen double t0 = rexponential(1 / 0.9)
    if "`trunc'" == "bygroup"     gen double t0 = rexponential(1 / cond(z1 == 1, 1.6, 0.5))

    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0

    * THE TRUNCATION: a subject is sampled only if entry precedes exit.
    quietly drop if !(t0 < t)
    quietly count
    if r(N) < `n' {
        display as error "oversample exhausted: only `r(N)' of `n' subjects survived truncation"
        exit 498
    }
    quietly keep in 1/`n'
    gen long id = _n
end

* ---------------------------------------------------------------------------
* CAPABILITY PROBE: is truncstrata() present in the INSTALLED command?
* Probed, not assumed -- this is what selects RED vs GREEN, so a stale install
* must not be able to silently pick the wrong mode.
* ---------------------------------------------------------------------------
_zzf_gen, n(2000) seed(`SEED0') trunc(bygroup)
quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture noisily finegray z1 z2, compete(status) cause(1) truncstrata(z1)
local has_ts = (_rc == 0)
local probe_rc = _rc

if `has_ts' {
    local MODE "GREEN"
    display as text _newline "MODE = GREEN: truncstrata() is available; arm C is fitted and gated."
}
else {
    local MODE "RED"
    display as text _newline "MODE = RED: truncstrata() is unavailable (rc = `probe_rc')."
    display as text "  Arm C cannot be fitted. Arms B and D are EXPECTED to fail."
    display as text "  This is Gate Z2-red: a recorded expected failure that authorizes Z3."
}

* ---------------------------------------------------------------------------
* Monte Carlo
* ---------------------------------------------------------------------------
tempfile mc
capture postclose _pf
postfile _pf str1 arm int rep double(b1 b2) using "`mc'", replace

local t0run = c(current_time)
forvalues r = 1/`REPS' {
    local s = `SEED0' + `r'

    * ---- arm A: no truncation, pooled weights (control)
    _zzf_gen, n(`N') seed(`s') trunc(none)
    quietly stset t, failure(anyev == 1) id(id)
    capture quietly finegray z1 z2, compete(status) cause(1)
    local fit_rc = _rc
    if `fit_rc' == 0 post _pf ("A") (`r') (_b[z1]) (_b[z2])
    else {
        display as error "  FITFAIL arm A rep `r': rc=`fit_rc'"
        post _pf ("A") (`r') (.) (.)
    }

    * ---- arm B: entry independent of z, pooled weights (supported)
    _zzf_gen, n(`N') seed(`s') trunc(independent)
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)
    capture quietly finegray z1 z2, compete(status) cause(1)
    local fit_rc = _rc
    if `fit_rc' == 0 post _pf ("B") (`r') (_b[z1]) (_b[z2])
    else {
        display as error "  FITFAIL arm B rep `r': rc=`fit_rc'"
        post _pf ("B") (`r') (.) (.)
    }

    * ---- arms C and D: entry depends on z1. SAME dataset, so C-vs-D is paired.
    _zzf_gen, n(`N') seed(`s') trunc(bygroup)
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)

    if `has_ts' {
        capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
        local fit_rc = _rc
        if `fit_rc' == 0 post _pf ("C") (`r') (_b[z1]) (_b[z2])
        else {
            display as error "  FITFAIL arm C rep `r': rc=`fit_rc'"
            post _pf ("C") (`r') (.) (.)
        }
    }

    capture quietly finegray z1 z2, compete(status) cause(1)
    local fit_rc = _rc
    if `fit_rc' == 0 post _pf ("D") (`r') (_b[z1]) (_b[z2])
    else {
        display as error "  FITFAIL arm D rep `r': rc=`fit_rc'"
        post _pf ("D") (`r') (.) (.)
    }

    if mod(`r', 10) == 0 ///
        display as text "  ... replication `r' of `REPS' (started `t0run', now `c(current_time)')"
}
postclose _pf

* ---------------------------------------------------------------------------
* Summary and gate
* ---------------------------------------------------------------------------
use "`mc'", clear

local fail_count = 0
local test_count = 0

display as text _newline "{hline 78}"
display as text "Gate Z2 -- mode `MODE' -- N = `N', REPS = `REPS'"
display as text "{hline 78}"
if "`MODE'" == "RED" {
    display as text "NOTE: the per-row verdicts below state the GREEN (post-Z3) requirement."
    display as text "      In RED mode arms B, C and D are EXPECTED to show FAIL/UNAVAILABLE."
    display as text "      The red gate is the SHAPE check printed after the table, not this column."
}
display as text %-4s "arm" %-4s "coef" %6s "reps" %9s "mean" %10s "bias" %9s "SD" %10s "MCSE" %9s "b/MCSE" "  verdict"

* expectation per arm: "recover" (|z| <= 3) or "biased" (|z| > 5, signed)
foreach a in A B C D {
    if "`a'" == "C" & !`has_ts' {
        local ++test_count
        local ++fail_count
        display as error %-4s "C" "   -- UNAVAILABLE: truncstrata() rejected (rc = `probe_rc')"
        display as error "        Gate Z2 arm C is UNMET. This is the expected red state before Z3."
        continue
    }

    forvalues k = 1/2 {
        local ++test_count
        local truth = cond(`k' == 1, `TRUTH1', `TRUTH2')

        quietly count if arm == "`a'" & !missing(b`k')
        local nrep = r(N)
        if `nrep' < 2 {
            display as error %-4s "`a'" %-4s "b`k'" "   -- only `nrep' usable replications"
            local ++fail_count
            continue
        }
        if `nrep' < `REPS' {
            display as error "  `a'/b`k': only `nrep' of `REPS' replications fitted"
        }
        quietly summarize b`k' if arm == "`a'", detail
        local mean = r(mean)
        local sd   = r(sd)
        local bias = `mean' - (`truth')
        local mcse = `sd' / sqrt(`nrep')
        local z    = `bias' / `mcse'

        * what this arm/coefficient is REQUIRED to do (see Z2-PREREG above).
        * BOTH of arm D's coefficients are required to be biased downward: the
        * Fine-Gray partial likelihood is not collapsible, so the z1-directed
        * misspecification leaks into b2 as well (~18x weaker, but not zero).
        if "`a'" == "D" {
            * signed: the bias must exceed NEG_Z MC SE *in the preregistered direction*
            local pd   = cond(`k' == 1, `PREREG_D1', `PREREG_D2')
            local ok   = (`z' * `pd' > `NEG_Z' & `nrep' == `REPS')
            local want = "biased, sign " + cond(`pd' > 0, "+", "-")
        }
        else {
            local ok   = (abs(`z') <= `PASS_Z' & `nrep' == `REPS')
            local want = "recover"
        }

        local verdict = cond(`ok', "PASS", "FAIL")
        if !`ok' local ++fail_count

        if `ok' {
            display as result %-4s "`a'" %-4s "b`k'" %6.0f `nrep' %9.5f `mean' %10.5f `bias' ///
                %9.5f `sd' %10.5f `mcse' %9.2f `z' "  `verdict' (`want')"
        }
        else {
            display as error  %-4s "`a'" %-4s "b`k'" %6.0f `nrep' %9.5f `mean' %10.5f `bias' ///
                %9.5f `sd' %10.5f `mcse' %9.2f `z' "  `verdict' (`want')"
        }
    }
}

display as text "{hline 78}"

if "`MODE'" == "RED" {
    * In RED mode the FAILURES ARE THE POINT.  What must hold is the QUALITATIVE
    * audit result: control recovers, both LT arms are broken, C unavailable.
    * Verify that shape explicitly rather than trusting the fail count.
    local red_ok = 1
    foreach a in A B D {
        forvalues k = 1/2 {
            quietly summarize b`k' if arm == "`a'"
            local z`a'`k' = (r(mean) - cond(`k' == 1, `TRUTH1', `TRUTH2')) / (r(sd) / sqrt(r(N)))
        }
    }
    display as text "Gate Z2-red expected shape:"
    display as text "  A (no truncation) recovers   : |z| = " %6.2f abs(`zA1') ", " %6.2f abs(`zA2')
    display as text "  B (independent LT) BROKEN    : |z| = " %6.2f abs(`zB1') ", " %6.2f abs(`zB2')
    display as text "  D (group LT, pooled) BROKEN  : |z| = " %6.2f abs(`zD1') ", " %6.2f abs(`zD2')
    display as text "  C (truncstrata) UNAVAILABLE  : rc = `probe_rc'"

    if abs(`zA1') > `PASS_Z' | abs(`zA2') > `PASS_Z' local red_ok = 0
    if abs(`zB1') <= `PASS_Z' & abs(`zB2') <= `PASS_Z' local red_ok = 0
    if abs(`zD1') <= `PASS_Z' & abs(`zD2') <= `PASS_Z' local red_ok = 0
    if `has_ts' local red_ok = 0

    display as text _newline
    if `red_ok' & `FULL' {
        display as result "GATE Z2-RED: CONFIRMED."
        display as result "  The released command recovers the truth WITHOUT delayed entry and loses it"
        display as result "  WITH delayed entry. The stratified correction does not exist. Z3 is authorized."
        display as result "  Gate Z2-GREEN remains UNMET and is the exit condition for Z3."
    }
    else if `red_ok' & !`FULL' {
        display as error "GATE Z2-RED: shape reproduced, but at SMOKE settings (N = `N', REPS = `REPS')."
        display as error "  This does NOT authorize Z3. Rerun at N >= 100000, REPS >= 100."
    }
    else {
        display as error "GATE Z2-RED: NOT REPRODUCED. The premise of this project is in question --"
        display as error "  do not proceed to Z3 until this is explained."
    }
}
else {
    display as text _newline
    if `fail_count' == 0 & `FULL' {
        display as result "GATE Z2-GREEN: PASS. `test_count' checks, 0 failures."
        display as result "  Supported arms A, B, C recover the known truth within +/-`PASS_Z' MC SE."
        display as result "  Negative control D remains biased beyond `NEG_Z' MC SE in the preregistered direction."
    }
    else if `fail_count' == 0 & !`FULL' {
        display as error "Green shape at SMOKE settings (N = `N', REPS = `REPS') -- Gate Z2 is NOT closed."
        display as error "  Rerun at N >= 100000, REPS >= 100 before claiming Z2-green."
    }
    else {
        display as error "GATE Z2-GREEN: FAIL. `fail_count' of `test_count' checks failed."
    }
}

local pass_count = `test_count' - `fail_count'
local smoke = !`FULL'
local gate_ok = ("`MODE'" == "GREEN" & `FULL' & `fail_count' == 0)
display as text "RESULT: validation_finegray_zzf_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=`smoke'"
log close _zzf
if !`gate_ok' exit 9

* validation_finegray_gof_power.do
* Power of finegray_gof against Li, Scheike & Zhang (2015) Tables 2 and 3.
*
* THE COMPANION TO validation_finegray_gof_calibration.do.  That gate asks
* whether the test holds its size under the null; this one asks whether it
* HAS POWER under the two alternatives the paper studies.  A test can be
* perfectly calibrated and useless, so size alone was never the whole claim.
*
* WHAT THE TWO TABLES ARE, AND WHY BOTH ARE NEEDED.  They differ only in the
* SHAPE of the time-varying effect, and that difference is the paper's point:
*
*   Table 2 (p.205)  beta(t) = beta + theta*t          -- a LINEAR departure
*   Table 3 (p.206)  beta(t) = b1*1(t<=t0) + b2*1(t>t0) -- a CHANGE-POINT
*
* Against the linear departure a correctly specified time-interaction model
* beats this test (0.9985 vs 0.9590 at n=300/15%).  Against the change point
* the ordering REVERSES (0.9715 vs 0.9125).  That is the whole argument for an
* omnibus test: it does not require the analyst to have guessed the form.  A
* suite that reproduced only Table 2 would evidence the case where the test is
* second best and omit the case that justifies it.
*
* WHAT IS ASSERTED, AND WHAT IS NOT.  Read this before trusting a green run.
*
* THE PUBLISHED CELLS ARE NOT REPRODUCIBLE, AND ARE THEREFORE NOT ASSERTED.
* The first full run (R=5000) put all twelve cells ABOVE the published values,
* z = +3.9 to +18.3.  That is not a tolerance problem and was not treated as
* one.  Running this exact DGP through the authors' own crskdiag in BOTH
* builds settles where the disagreement is:
*
*     crskdiag ORIG  (defective Ghat_c)  0.6375 / 0.4800   n=100, 15% / 30%
*     crskdiag FIXED (corrected Ghat_c)  0.6425 / 0.4800
*     finegray                           0.6158 / 0.4738
*     paper Table 2                      0.5560 / 0.3920
*
* The two crskdiag builds agree with each other, so the censoring-KM defect
* does not cost power here; finegray agrees with both (z = 1.07, 0.24); and
* exponential censoring instead of uniform changes nothing (0.6300 / 0.4850).
* Three independent implementations agree and all disagree with the table, so
* the gap lies in the paper's DESCRIPTION of its own simulation, not in this
* estimator.  The unresolved detail is most likely the cause-assignment
* convention: with gamma=2 the model's own F1(inf|Z) is 0.33 and 0.14, nowhere
* near the 0.66 the text says was "fixed for simplicity".
*
* This suite therefore asserts:
*   1. the STRUCTURAL relations -- power rises with n, falls with censoring,
*      and clears a floor at n=300/15%.  Large effects, and the ones that would
*      survive a modest change in the DGP reading.
*   2. a BRACKET on each cell -- at or above the published value, by no more
*      than 0.15.  This encodes what the cross-implementation evidence supports
*      while still failing on a genuine regression (power collapsing toward the
*      type I level, or saturating at 1).
* and REPORTS, without asserting, each cell's z against the published value.
*
* Asserting the published cells outright would be a gate that fails on correct
* code -- precisely the error FINDINGS §13.3 records for beta-parity against
* cmprsk::crr, where the reference was itself the less accurate side.
*
* ALSO NOT ASSERTED: the three rival columns (t, t^2, log(t)), which come from
* refitting Fine-Gray with a time-varying interaction -- a different estimator
* this package does not expose, whose failures would be indistinguishable from
* failures of the test under study.  The paper's ORDERING claim is quoted in
* finegray_gof.sthlp from the paper and is NOT verified here.  Said plainly so
* nobody later reads this suite as having reproduced Tables 2 and 3 entire.
*
* ONE DGP DETAIL IS AN INTERPRETATION, NOT A TRANSCRIPTION.  For Table 3 the
* paper gives beta(t), lambda*_10(t) = 1, b1 = 1, b2 = 0.2 and t0 = 0.5, and
* says the data come from "model (4)" -- but it does not restate the cause-2
* distribution or the cause-1 probability for that table.  Both are carried
* over from the Table 2 paragraph (p.204): P(cause 1) = 0.66 and cause 2
* exponential with rate exp(alpha*Z), alpha = -0.5.  If a cell misses, this
* assumption is the first thing to re-examine, ahead of the estimator.
*
* A NOTE ON COST.  Twelve cells x R replications x nsim bootstrap draws each.
* At the gate value (R = 5000, nsim = 1000) this is the same order as the
* calibration gate and belongs in the `gates' lane, not in `full'.
*
* DGPs read from the paper, not from recall:
*   sec. 3.1 p.204  lambda*_1(t|Z) = lambda*_10(t) exp{beta(t) Z},  eq. (4)
*                   lambda*_10(t)  = gamma exp(rho t)
*                   beta = 0, theta = -8, rho = -5, gamma = 2, alpha = -0.5
*                   P(cause 1) = 0.66; Z binary, half and half
*   sec. 3.1 p.205  Table 3: lambda*_10(t) = 1, beta(t) = 1*1(t<=.5) + .2*1(t>.5)
*   both            censoring U(0,tau], tau tuned to 15% / 30%
clear all
set varabbrev off
set more off
version 16.0
set type double

capture log close _all
log using "validation_finegray_gof_power.log", replace name(_vpow)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "validation_finegray_gof_power.do must run from finegray/qa"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* R is the replication count.  The gate value is 5000, matching the paper.
* GOF_POW_REPS exists so the harness can be exercised quickly during
* development; a reduced run is NOT the gate and says so in its own output.
local R = 5000
if "$GOF_POW_REPS" != "" local R = $GOF_POW_REPS
local K = 1000
if "$GOF_POW_NSIM" != "" local K = $GOF_POW_NSIM
local reduced = (`R' < 5000 | `K' < 1000)

local test_count = 0
local pass_count = 0
local fail_count = 0

* ---------------------------------------------------------------------------
* The paper's two alternatives, by inverse CDF within each cause branch.
*
* dgp 1 = Table 2, linear time-varying effect.
*   Lambda(t|Z) = gamma (1 - exp(-k_Z t)) / k_Z,   k_Z = -(rho + theta Z)
*   so Lambda(inf|Z) = gamma / k_Z and the cause-1 branch inverts in closed
*   form.  k_0 = 5, k_1 = 13: the Z = 1 subdistribution hazard dies away far
*   faster, which IS the non-proportionality being detected.
*
* dgp 2 = Table 3, change-point effect.
*   Lambda(t|Z) = t exp(b1 Z)                          for t <= t0
*               = t0 exp(b1 Z) + (t - t0) exp(b2 Z)    for t >  t0
*   Here lambda*_10 = 1 does not decay, so Lambda(inf) is infinite and the
*   normalising F1(inf|Z) is 1 -- the cause-1 branch is a plain inversion.
* ---------------------------------------------------------------------------
capture program drop _gen_pow
program define _gen_pow
    version 16.0
    args n dgp tau
    clear
    quietly set obs `n'
    local p1  = 0.66
    local alp = -0.5
    gen double Z = mod(_n, 2)

    gen double _u = runiform()
    gen byte _c1 = (_u <= `p1')
    * v is a FRESH uniform, not a rescaling of _u.  Reusing _u would tie the
    * failure time to the cause indicator and quietly correlate them.
    gen double _v = runiform()
    quietly replace _v = 0.999999999 if _v >= 1

    if `dgp' == 1 {
        local gam = 2
        local rho = -5
        local the = -8
        gen double _k     = -(`rho' + `the' * Z)
        gen double _Linf  = `gam' / _k
        gen double _F1inf = 1 - exp(-_Linf)
        * L = -ln(1 - v F1inf) is the cumulative hazard at the drawn quantile
        gen double _L     = -ln(1 - _v * _F1inf)
        gen double _T1    = -ln(1 - _L / _Linf) / _k
    }
    else {
        local b1 = 1
        local b2 = 0.2
        local t0 = 0.5
        gen double _e1  = exp(`b1' * Z)
        gen double _e2  = exp(`b2' * Z)
        gen double _L   = -ln(1 - _v)
        gen double _brk = `t0' * _e1
        gen double _T1  = cond(_L <= _brk, _L / _e1, ///
                               `t0' + (_L - _brk) / _e2)
    }

    * cause 2: exponential with rate exp(alpha Z)
    gen double _T2 = -ln(1 - _v) / exp(`alp' * Z)
    gen double _T  = cond(_c1, _T1, _T2)

    gen double _C = runiform() * `tau'
    * NOT named _d: stset owns _d/_t/_t0/_st, and a generator column by that
    * name collides with the variables stset creates on the very next line.
    gen byte _evt = (_T <= _C)
    gen double t = min(_T, _C)
    gen byte cause = cond(_evt, cond(_c1, 1, 2), 0)
    gen long _fgid = _n
    quietly stset t, failure(cause) id(_fgid)
end

* tau calibration: bisect the censoring rate on a large pilot sample
capture program drop _tau_pow
program define _tau_pow, rclass
    version 16.0
    args dgp target
    local lo = 0.001
    local hi = 500
    set seed 777
    forvalues it = 1/60 {
        local mid = (`lo' + `hi') / 2
        _gen_pow 200000 `dgp' `mid'
        quietly count if cause == 0
        local cr = r(N) / _N
        if abs(`cr' - `target') < 0.0005 {
            return scalar tau = `mid'
            exit
        }
        if `cr' > `target' local lo = `mid'
        else               local hi = `mid'
    }
    return scalar tau = `mid'
end

* ---- published values, the "Proposed" column ------------------------------
* Table 2 p.205 (linear beta(t)) and Table 3 p.206 (change-point beta(t)).
local pub_1_50_15  = 0.3260
local pub_1_50_30  = 0.2100
local pub_1_100_15 = 0.5560
local pub_1_100_30 = 0.3920
local pub_1_300_15 = 0.9590
local pub_1_300_30 = 0.8420
local pub_2_50_15  = 0.3510
local pub_2_50_30  = 0.2045
local pub_2_100_15 = 0.5770
local pub_2_100_30 = 0.3760
local pub_2_300_15 = 0.9715
local pub_2_300_30 = 0.8025

display as text _newline ///
    "Power vs Tables 2 and 3 -- R=`R' reps, nsim=`K'"
if `reduced' {
    display as error "REDUCED RUN (R=`R', nsim=`K'): this is a harness exercise,"
    display as error "NOT the power gate.  The cell bracket is loosened accordingly"
    display as error "and the result must not be reported as the gate."
}

tempname fh
file open `fh' using "gof_power_cells.csv", write replace
file write `fh' "dgp,n,cens_target,tau,cens_obs,power,ndrop" _newline

forvalues dg = 1/2 {
    foreach cr in 0.15 0.30 {
        _tau_pow `dg' `cr'
        local tau = r(tau)
        local crlab = cond(`cr' == 0.15, "15", "30")

        foreach n in 50 100 300 {
            local ++test_count
            capture noisily {
                set seed `=20260721 + `n' + 1000*`dg' + 100000*`cr''
                local nrej = 0
                local ndrop = 0
                local cens = 0

                forvalues r = 1/`R' {
                    _gen_pow `n' `dg' `tau'
                    quietly count if cause == 0
                    local cens = `cens' + r(N) / _N

                    capture quietly finegray Z, compete(cause) cause(1) ///
                        censvalue(0) nolog
                    if _rc | e(converged) != 1 {
                        local ++ndrop
                        continue
                    }
                    capture quietly finegray_gof, proportional nsim(`K')
                    if _rc {
                        local ++ndrop
                        continue
                    }
                    matrix _G = r(gof)
                    local nrej = `nrej' + (_G[1,2] <= 0.05)
                }

                local neff = `R' - `ndrop'
                if `neff' < 0.9 * `R' {
                    display as error "    `ndrop' of `R' replications dropped --"
                    display as error "    this cell is not a power estimate"
                    exit 9
                }
                local pw = `nrej' / `neff'
                local co = `cens' / `R'
                file write `fh' "`dg',`n',`cr',`tau',`co',`pw',`ndrop'" _newline

                local pub = `pub_`dg'_`n'_`crlab''
                local se = sqrt(`pub' * (1 - `pub') / `neff')
                local z = (`pw' - `pub') / `se'
                local pw_`dg'_`n'_`crlab' = `pw'
                * Stata has no `%+f' flag -- `%+6.4f' is a syntax error at
                * display time (r(120)), which is a failure mode a reduced run
                * would have surfaced just as well as a full one.  Sign is
                * carried in the value, not the format.
                local gap = `pw' - `pub'

                display as text "  dgp `dg' n=" %4.0f `n' " cens " %5.2f `cr' ///
                    "  power " %6.4f `pw' "  paper " %6.4f `pub' ///
                    "  z " %6.2f `z' "  gap " %7.4f `gap' ///
                    "  (cens obs " %5.3f `co' ", dropped `ndrop')"

                * ------------------------------------------------------------
                * THE PUBLISHED CELL IS REPORTED, NOT ASSERTED.  This is a
                * deliberate change made after the first full run, and the
                * reason matters more than the change.
                *
                * At R=5000 all twelve cells sat ABOVE the published value,
                * z = +3.9 to +18.3, with the gap at 30% censoring running
                * 2.2x the gap at 15%.  That looked like the paper's defective
                * censoring KM (Ghat_c == 1 on continuous data) costing power
                * under the alternative -- a tidy story, since a heavier
                * censoring fraction would then cost more.
                *
                * IT IS NOT.  Tested rather than assumed, by running this exact
                * DGP through the authors' own crskdiag in BOTH builds
                * (n=100, 400 reps, nsim=500, minor_included=0):
                *
                *     crskdiag ORIG  (defective Ghat_c)  0.6375 / 0.4800
                *     crskdiag FIXED (corrected Ghat_c)  0.6425 / 0.4800
                *     finegray                           0.6158 / 0.4738
                *     paper Table 2                      0.5560 / 0.3920
                *                                        (15% / 30% censoring)
                *
                * The two crskdiag builds agree with EACH OTHER, so the weight
                * defect does not move power on this DGP; and finegray agrees
                * with both (z = 1.07 and 0.24 against FIXED).  Swapping
                * uniform censoring for exponential changes nothing either
                * (0.6300 / 0.4850).  Three independent implementations agree
                * and all three disagree with the table.
                *
                * So the published cells are NOT REPRODUCIBLE from the DGP as
                * published, and the discrepancy is in the paper's description
                * of its own simulation -- most likely the cause-assignment
                * convention, since with gamma=2 the model's own F1(inf|Z) is
                * 0.33/0.14, nowhere near the 0.66 the text says was "fixed for
                * simplicity".  That ambiguity is not resolvable from the page.
                *
                * Asserting a target three implementations cannot hit would be
                * a gate that fails on correct code -- the same error FINDINGS
                * §13.3 records for beta-parity against cmprsk::crr, where the
                * reference itself was the less accurate side.  Widening the
                * band until it passes would be worse: manufacturing a green.
                *
                * What IS asserted is a BRACKET that encodes what the evidence
                * actually supports -- power runs above the published value,
                * by a bounded amount -- so a real regression (power collapsing
                * toward the type I level, or exploding to 1) still fails,
                * while the known and explained offset does not.
                * ------------------------------------------------------------
                * THE BRACKET SCALES WITH R.  A flat width is an assertion about
                * the replication count rather than about power: at R=30 the
                * cell SE is ~0.087, so a fixed +/-0.15 is under 2 SE and two
                * cells failed on pure noise during the smoke run.  Widening by
                * 3 Monte Carlo SE states the same claim at whatever R is
                * actually running -- the same device the calibration harness
                * uses for its func/link bound.  At the gate R=5000 the SE is
                * ~0.007, so 3 SE = 0.02 and the bracket is the intended
                * [pub - 0.02, pub + 0.15].
                local se_pw = sqrt(`pub' * (1 - `pub') / `neff')
                local lo_bnd = `pub' - max(0.02, 3 * `se_pw')
                local hi_bnd = `pub' + max(0.15, 3 * `se_pw')
                if `pw' < `lo_bnd' {
                    display as error "    power `pw' is below `lo_bnd' (published `pub')."
                    display as error "    Every implementation measured to date runs"
                    display as error "    at or above the published cells; a value"
                    display as error "    below them is a regression, not the known offset."
                    exit 9
                }
                if `pw' > `hi_bnd' {
                    display as error "    power `pw' exceeds `hi_bnd' (published `pub')."
                    display as error "    The documented offset tops out at +0.103;"
                    display as error "    this is outside it."
                    exit 9
                }
            }
            if _rc == 0 {
                local ++pass_count
                display as result "  PASS: cell dgp `dg' n=`n' cens `cr'"
            }
            else {
                local ++fail_count
                display as error "  FAIL: cell dgp `dg' n=`n' cens `cr' (rc=`=_rc')"
            }
        }
    }
}
file close `fh'

* ===========================================================================
* Structural relations.  Unlike the per-cell z these are large effects, and
* they are the ones that would survive a modest shift in the DGP reading --
* so they, not the individual cells, are what says "the test has power and it
* behaves the way power behaves".
*
* Deliberately NOT asserted: monotone anything at the third decimal, or a
* Table 2 vs Table 3 ordering at fixed n.  The published Table 2 and Table 3
* values at n=300/15% are 0.9590 and 0.9715 -- a 0.0125 gap, under 2 SE even
* at R=5000, so an ordering assertion there would be a coin flip on correct
* code.  This is the same trap §12.3 of FINDINGS.md documents for the
* calibration gate's "monotone easing".
* ===========================================================================
local ++test_count
capture noisily {
    if `reduced' {
        display as error "structural relations NOT ASSERTED on a reduced run"
        exit 0
    }

    forvalues dg = 1/2 {
        foreach crlab in 15 30 {
            * (1) power rises with n -- 0.33 -> 0.96 in the paper, so this is
            *     a very large effect and a real regression cannot hide in it
            local a = `pw_`dg'_50_`crlab''
            local b = `pw_`dg'_100_`crlab''
            local c = `pw_`dg'_300_`crlab''
            display as text "  dgp `dg' cens `crlab': " %6.4f `a' " -> " ///
                %6.4f `b' " -> " %6.4f `c'
            if !(`a' < `b' & `b' < `c') {
                display as error "power is not increasing in n for dgp `dg' cens `crlab'"
                exit 9
            }
        }

        * (2) heavier censoring costs power, at every n
        foreach n in 50 100 300 {
            local p15 = `pw_`dg'_`n'_15'
            local p30 = `pw_`dg'_`n'_30'
            if `p15' <= `p30' {
                display as error "30% censoring did not cost power at dgp `dg' n=`n'"
                display as error "(15%: `p15'   30%: `p30')"
                exit 9
            }
        }
    }

    * (3) the test is not merely calibrated -- at n=300/15% it detects both
    *     alternatives nearly always.  The published values are 0.9590 and
    *     0.9715; 0.90 is a floor a real implementation clears easily and a
    *     broken one does not.
    forvalues dg = 1/2 {
        if `pw_`dg'_300_15' < 0.90 {
            display as error "dgp `dg' power at n=300/15% is `pw_`dg'_300_15',"
            display as error "below the 0.90 floor the paper's 0.95+ implies"
            exit 9
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: power rises with n, falls with censoring, clears the floor"
}
else {
    local ++fail_count
    display as error "  FAIL: structural relations (rc=`=_rc')"
}

**# Summary
* A REDUCED RUN EMITS NO SENTINEL.  It would otherwise print a green
* "RESULT: ... fail=0" that run_all.do counts as a passing gate -- a 40-rep
* harness exercise recorded as the 5,000-rep power gate.  run_all treats a
* missing sentinel as a failure, so withholding it fails closed.
if `reduced' {
    display as error _newline "REDUCED RUN (R=`R', nsim=`K'): NOT the power gate."
    display as error "No RESULT sentinel is emitted, so this run cannot be"
    display as error "recorded as a pass.  Re-run without GOF_POW_REPS/GOF_POW_NSIM."
    display as text "  (harness only: tests=`test_count' pass=`pass_count' fail=`fail_count')"
    capture log close _vpow
    exit 0
}
display as text _newline ///
    "RESULT: validation_finegray_gof_power tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _vpow
    exit 9
}
capture log close _vpow

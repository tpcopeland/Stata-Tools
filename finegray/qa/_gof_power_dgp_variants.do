* _gof_power_dgp_variants.do
* Discriminating experiment: WHICH reading of Li, Scheike & Zhang (2015)
* sec. 3.1's ALTERNATIVE paragraph (p.204) generated Tables 2 and 3?
*
* WHY THIS EXISTS.  validation_finegray_gof_power.do stopped asserting the
* published cells because all twelve ran high (z = +3.9 to +18.3).  That
* decision rests on "the DGP as published is not reproducible", which had been
* established only for ONE reading of the paragraph.  This screen tests three
* NAMED readings so the claim becomes "not reproducible across these three",
* or dissolves entirely because one of them lands.
*
* THE PARAGRAPH CONTRAST THAT MOTIVATES READING B.  On p.204 the two DGP
* paragraphs differ in a way that is hard to read as accidental:
*
*   NULL (Table 1):  "...the failure time was generated from F1(t|zi)/F1(inf|zi)
*                     using inverse distribution method"        -- NORMALISED
*   ALT  (Table 2):  "If u <= 0.66, the failure time was generated from
*                     F1(t|Z)"                                  -- NOT normalised
*
* The current generator carries the NULL convention into the ALTERNATIVE.
*
* THE THREE READINGS.
*   A  branch-normalised (current): P(cause 1) = 0.66 flat; given cause 1,
*      time from F1(t|Z)/F1(inf|Z).
*   B  literal / improper CIF: P(cause 1) = 0.66 flat; given cause 1, time from
*      F1(t|Z) UNNORMALISED, so a draw v > F1(inf|Z) has no solution and the
*      subject NEVER FAILS.
*   C  model-consistent: cause assigned by u <= F1(inf|Z) as in the NULL
*      paragraph, ignoring the flat 0.66 -- the reading that honours the
*      paper's own clause "given F2(inf|Z) = 1 - F1(inf|Z)".
*
* SCOPE: DGP 1 (Table 2) ONLY, AND THAT IS A RESULT, NOT A SHORTCUT.
* For Table 3 the paper sets lambda*_10(t) = 1 (p.205), so Lambda*_1(inf) is
* infinite and F1(inf|Z) = 1.  Therefore:
*   - normalisation is a NO-OP, so reading A and reading B are IDENTICAL;
*   - reading C degenerates -- u <= F1(inf|Z) = 1 always, so every subject is
*     cause 1 and the cause-2 branch vanishes.
* The screen is mathematically incapable of discriminating on dgp 2.  Table 3's
* ambiguity is a DIFFERENT one (its cause-2 branch is never restated), so
* fixing dgp 1 cannot fix dgp 2 and the two tables must be graded separately.
* Asserted below as an identity check rather than left as a comment.
*
* WHAT IS GATED BEFORE ANY POWER NUMBER IS BELIEVED.  A wrong inversion
* produces a plausible-looking power value, so the generator is verified
* against closed forms FIRST:
*   1. empirical P(cause 1 | Z) matches the reading's stated value;
*   2. empirical cause-1 CIF matches the closed form at four grid points;
*   3. for reading B, the never-failing fraction matches 0.66(1 - F1(inf|Z));
*   4. the reading can ACTUALLY REACH the paper's 15% / 30% censoring targets.
*
* Gate 4 is not in the original plan and it is the one that bites.  _tau_pow
* bisects tau against the generator's own censoring rate and, on failure to
* converge, RETURNS ITS LAST MIDPOINT WITH NO ERROR.  Under reading B roughly
* half of all subjects never fail and are recorded as cause == 0, so the
* censoring rate has a FLOOR near 0.50 and the 15% / 30% cells do not exist --
* yet a bisection would still hand back a tau and the harness would report a
* power number for a cell that cannot be constructed.  That is an rc=0-but-wrong
* of exactly the class the evidence standard exists to catch.
clear all
set varabbrev off
set more off
version 16.0
set type double

capture log close _all
log using "_gof_power_dgp_variants.log", replace name(_vdgp)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "_gof_power_dgp_variants.do must run from finegray/qa"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* R / K exist so the whole screen can be smoked at trivial cost before the real
* run -- second_op.md sec.4's lesson, where a 35-minute Monte Carlo died on
* cell 1 of 12 because of a bad display format.
* THE OVERRIDE READS THE ENVIRONMENT, NOT JUST A GLOBAL.  Stata does NOT
* import environment variables into globals, so `DGPV_REPS=15 stata-mp -b do
* ...' leaves $DGPV_REPS EMPTY and the harness silently runs at full size --
* the operator believes they smoked it and did not.  That is exactly how the
* documented smoke procedure for the production power gate behaves today
* (second_op.md sec.6).  Reading `: environment' as a fallback makes both the
* env-var and the global form work.
foreach _v in DGPV_REPS DGPV_NSIM DGPV_NBIG {
    if "${`_v'}" == "" {
        global `_v' : environment `_v'
    }
}
local R = 1000
if "$DGPV_REPS" != "" local R = $DGPV_REPS
local K = 500
if "$DGPV_NSIM" != "" local K = $DGPV_NSIM
local NBIG = 200000
if "$DGPV_NBIG" != "" local NBIG = $DGPV_NBIG

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

* ---------------------------------------------------------------------------
* Generator, parameterised by reading.
*
* dgp 1 closed forms (paper p.204, beta = 0):
*   Lambda_1(t|Z) = gam (1 - exp(-k_Z t)) / k_Z,   k_Z = -(rho + theta Z)
*   k_0 = 5, k_1 = 13;  Lambda_1(inf|Z) = gam / k_Z
*   F1(t|Z) = 1 - exp(-Lambda_1(t|Z));  F1(inf|Z) = 0.32968 / 0.14261
* ---------------------------------------------------------------------------
capture program drop _gen_pow_v
program define _gen_pow_v
    version 16.0
    args n dgp tau reading
    clear
    quietly set obs `n'
    local p1  = 0.66
    local alp = -0.5
    gen double Z = mod(_n, 2)

    gen double _u = runiform()
    * v is a FRESH uniform, not a rescaling of _u.  Reusing _u would tie the
    * failure time to the cause indicator and quietly correlate them.
    gen double _v = runiform()
    quietly replace _v = 0.999999999 if _v >= 1

    * _nofail marks a cause-1 subject whose draw has no solution (reading B).
    gen byte _nofail = 0

    if `dgp' == 1 {
        local gam = 2
        local rho = -5
        local the = -8
        gen double _k     = -(`rho' + `the' * Z)
        gen double _Linf  = `gam' / _k
        gen double _F1inf = 1 - exp(-_Linf)

        if "`reading'" == "C" {
            * cause by the model's own F1(inf|Z), as the NULL paragraph does
            gen byte _c1 = (_u <= _F1inf)
        }
        else {
            gen byte _c1 = (_u <= `p1')
        }

        if "`reading'" == "B" {
            * UNNORMALISED: Lambda(T) = -ln(1 - v) must be < Lambda(inf),
            * which holds exactly when v < F1(inf|Z).  Otherwise no failure.
            gen double _L = -ln(1 - _v)
            quietly replace _nofail = 1 if _c1 & _v >= _F1inf
            gen double _T1 = cond(_nofail, ., -ln(1 - _L / _Linf) / _k)
        }
        else {
            * NORMALISED: F1(T|Z)/F1(inf|Z) = v
            gen double _L  = -ln(1 - _v * _F1inf)
            gen double _T1 = -ln(1 - _L / _Linf) / _k
        }
    }
    else {
        * dgp 2: lambda*_10 = 1 so F1(inf|Z) = 1; all readings coincide and
        * reading C degenerates to "everyone is cause 1".
        local b1 = 1
        local b2 = 0.2
        local t0 = 0.5
        gen double _F1inf = 1
        if "`reading'" == "C" gen byte _c1 = 1
        else                  gen byte _c1 = (_u <= `p1')
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
    * NOT named _d: stset owns _d/_t/_t0/_st.
    * A never-failing subject (_T == .) is censored at _C: min() IGNORES
    * missing, so _T must be screened explicitly or a never-failing subject
    * would silently be given event time _C and counted as an EVENT.
    gen byte _evt = (_T < . & _T <= _C)
    gen double t = cond(_T < ., min(_T, _C), _C)
    gen byte cause = cond(_evt, cond(_c1, 1, 2), 0)
    gen long _fgid = _n
    quietly stset t, failure(cause) id(_fgid)
end

* ---------------------------------------------------------------------------
* tau bisection, WITH a convergence verdict.  The production _tau_pow returns
* its last midpoint whether or not it converged; this one reports.
* ---------------------------------------------------------------------------
capture program drop _tau_pow_v
program define _tau_pow_v, rclass
    version 16.0
    args dgp target reading nbig
    local lo = 0.001
    local hi = 500
    set seed 777
    local conv = 0
    forvalues it = 1/60 {
        local mid = (`lo' + `hi') / 2
        _gen_pow_v `nbig' `dgp' `mid' "`reading'"
        quietly count if cause == 0
        local cr = r(N) / _N
        if abs(`cr' - `target') < 0.0005 {
            local conv = 1
            continue, break
        }
        if `cr' > `target' local lo = `mid'
        else               local hi = `mid'
    }
    * the censoring FLOOR: at tau = hi (essentially no administrative
    * censoring) whatever remains as cause == 0 is structural.
    _gen_pow_v `nbig' `dgp' 100000 "`reading'"
    quietly count if cause == 0
    local floor = r(N) / _N
    return scalar tau = `mid'
    return scalar cr = `cr'
    return scalar conv = `conv'
    return scalar floor = `floor'
end

display as text _newline "DGP reading screen -- dgp 1 (Table 2), R=`R' nsim=`K' nbig=`NBIG'"

**# Gate V0 -- dgp 2 is reading-invariant (corollary, asserted not assumed)
local ++test_count
capture noisily {
    set seed 4242
    _gen_pow_v 200000 2 100000 "A"
    quietly count if cause == 1
    local a1 = r(N)
    quietly summarize t if cause == 1, meanonly
    local am = r(mean)
    set seed 4242
    _gen_pow_v 200000 2 100000 "B"
    quietly count if cause == 1
    local b1 = r(N)
    quietly summarize t if cause == 1, meanonly
    local bm = r(mean)
    display as text "  dgp2 reading A: n_cause1=`a1' mean t=" %8.6f `am'
    display as text "  dgp2 reading B: n_cause1=`b1' mean t=" %8.6f `bm'
    if `a1' != `b1' | reldif(`am', `bm') > 1e-12 {
        display as error "dgp 2 readings A and B differ -- the F1(inf)=1 argument is wrong"
        exit 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS V0: dgp 2 is identical under readings A and B (F1(inf|Z) = 1)"
}
else {
    local ++fail_count
    display as error "  FAIL V0 (rc=`=_rc')"
}

**# Gate V1 -- generator identities per reading, dgp 1
foreach rd in A B C {
    local ++test_count
    capture noisily {
        set seed 20260722
        _gen_pow_v `NBIG' 1 100000 "`rd'"

        * (1) P(cause 1 | Z) against the reading's stated value.
        *     A, B: 0.66 flat.  C: F1(inf|Z) = 0.32968 / 0.14261.
        *     Under B a cause-1 subject may never fail, so the cause-1 SHARE is
        *     measured on the assignment (_c1), not on observed events.
        forvalues z = 0/1 {
            quietly summarize _c1 if Z == `z', meanonly
            local pc`z' = r(mean)
            quietly summarize _F1inf if Z == `z', meanonly
            local f`z' = r(mean)
        }
        if "`rd'" == "C" {
            local e0 = `f0'
            local e1 = `f1'
        }
        else {
            local e0 = 0.66
            local e1 = 0.66
        }
        display as text "  `rd': P(cause1|Z=0)=" %6.4f `pc0' " (expect " %6.4f `e0' ///
            ")   P(cause1|Z=1)=" %6.4f `pc1' " (expect " %6.4f `e1' ")"
        if abs(`pc0' - `e0') > 0.005 | abs(`pc1' - `e1') > 0.005 {
            display as error "  `rd': cause-1 probability does not match the reading"
            exit 9
        }

        * (2) empirical cause-1 CIF vs closed form at four grid points.
        *     Computed on an UNCENSORED draw, so the empirical CIF is just the
        *     fraction with cause 1 and T <= s -- no estimator involved, which
        *     is what makes this an independent check of the inversion.
        forvalues z = 0/1 {
            local k = cond(`z' == 0, 5, 13)
            local Linf = 2 / `k'
            foreach s in 0.05 0.10 0.20 0.40 {
                * closed form: F1(s|Z) = 1 - exp(-Lambda(s)),
                *   Lambda(s) = 2 (1 - exp(-k s)) / k
                local Ls = 2 * (1 - exp(-`k' * `s')) / `k'
                local cf = 1 - exp(-`Ls')
                * Unconditional P(cause 1, T <= s), by reading:
                *   A: 0.66 * F1(s)/F1(inf)  -- cause-1 branch RESCALED onto 0.66
                *   B: 0.66 * F1(s)          -- cause 1 w.p. 0.66, then the
                *                                improper draw fails only if
                *                                v <= F1(s); no rescaling
                *   C: F1(inf) * F1(s)/F1(inf) = F1(s) -- the model's own CIF,
                *                                which is the point of reading C
                if "`rd'" == "A"      local exp_c = 0.66 * `cf' / (1 - exp(-`Linf'))
                else if "`rd'" == "B" local exp_c = 0.66 * `cf'
                else                  local exp_c = `cf'
                quietly count if Z == `z' & cause == 1 & t <= `s'
                local num = r(N)
                quietly count if Z == `z'
                local den = r(N)
                local emp = `num' / `den'
                if abs(`emp' - `exp_c') > 0.01 {
                    display as error "  `rd': CIF mismatch Z=`z' s=`s' emp=`emp' expect=`exp_c'"
                    exit 9
                }
            }
        }
        display as text "  `rd': cause-1 CIF matches closed form at 8 grid points (tol 1e-2)"

        * (3) reading B only: never-failing fraction = 0.66 (1 - F1(inf|Z))
        if "`rd'" == "B" {
            forvalues z = 0/1 {
                quietly summarize _nofail if Z == `z', meanonly
                local nf = r(mean)
                local expnf = 0.66 * (1 - `f`z'')
                display as text "  B: never-fail frac Z=`z' = " %6.4f `nf' ///
                    " (expect " %6.4f `expnf' ")"
                if abs(`nf' - `expnf') > 0.005 {
                    display as error "  B: never-fail fraction wrong at Z=`z'"
                    exit 9
                }
            }
        }
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS V1-`rd': generator identities hold"
    }
    else {
        local ++fail_count
        display as error "  FAIL V1-`rd' (rc=`=_rc')"
    }
}

**# Gate V2 -- can each reading REACH the paper's censoring targets?
* The gate the plan did not have.  A reading whose structural censoring floor
* exceeds the target cannot produce that cell at any tau, and the production
* bisection would hide that behind a returned midpoint.
tempname fh
file open `fh' using "_gof_power_dgp_variants_tau.csv", write replace
file write `fh' "reading,target,tau,cr,converged,floor,reachable" _newline

* NOTE the crlab indirection.  A macro named `tau_A_0.15' is not a legal Stata
* macro name -- the period is illegal -- and the whole V2 block failed r(198)
* on every cell the first time this ran.  Cell labels are "15"/"30".
foreach rd in A B C {
    foreach cr in 0.15 0.30 {
        local crlab = cond(`cr' == 0.15, "15", "30")
        local ++test_count
        capture noisily {
            _tau_pow_v 1 `cr' "`rd'" `NBIG'
            local tau_`rd'_`crlab' = r(tau)
            local conv = r(conv)
            local got = r(cr)
            local floor = r(floor)
            local reach = (`floor' < `cr')
            local reach_`rd'_`crlab' = `reach'
            file write `fh' "`rd',`cr',`=r(tau)',`got',`conv',`floor',`reach'" _newline
            display as text "  `rd' target " %4.2f `cr' ": tau=" %9.4f r(tau) ///
                " achieved cr=" %6.4f `got' "  converged=`conv'" ///
                "  structural floor=" %6.4f `floor'

            * READING B IS EXPECTED TO BE UNREACHABLE, AND THAT IS AN ASSERTION,
            * NOT A FAILURE.  Under B roughly half of all subjects never fail,
            * so the censoring rate has a floor near 0.50 and the paper's 15% /
            * 30% cells cannot be constructed at any tau.  Asserting the floor
            * is what makes this a gate rather than a one-off screen: if a
            * later edit to the generator quietly made B reachable, the
            * refutation recorded in FINDINGS would be silently false.
            if "`rd'" == "B" {
                if `reach' | `conv' {
                    display as error "  B: expected UNREACHABLE at target `cr', but"
                    display as error "  floor=`floor' reach=`reach' conv=`conv'."
                    display as error "  The recorded refutation of reading B no longer holds."
                    exit 9
                }
                if abs(`floor' - 0.5041) > 0.02 {
                    display as error "  B: censoring floor `floor' is not the predicted"
                    display as error "  0.66*(1-F1(inf|Z)) averaged over Z = 0.5041."
                    exit 9
                }
                display as text "  B: UNREACHABLE as predicted (floor " %6.4f `floor' ///
                    " vs analytic 0.5041) -- cell does not exist under this reading"
            }
            else {
                if !`reach' {
                    display as error "  `rd': censoring floor " %6.4f `floor' ///
                        " EXCEEDS the target `cr' -- this cell CANNOT be constructed"
                    exit 9
                }
                if !`conv' {
                    display as error "  `rd': bisection did not converge to `cr'"
                    exit 9
                }
            }
        }
        if _rc == 0 {
            local ++pass_count
            display as result "  PASS V2-`rd'-`cr'"
        }
        else {
            local ++fail_count
            display as error "  FAIL V2-`rd'-`cr' (rc=`=_rc')"
        }
    }
}
file close `fh'

**# Gate V3 -- power screen, only for readings whose cells are constructible
local pub_100_15 = 0.5560
local pub_100_30 = 0.3920

tempname fp
file open `fp' using "_gof_power_dgp_variants_power.csv", write replace
file write `fp' "reading,n,cens,tau,power,neff,ndrop,pub,se_diff,z" _newline

foreach rd in A B C {
    foreach cr in 0.15 0.30 {
        local crlab = cond(`cr' == 0.15, "15", "30")
        local ++test_count
        * DO NOT use `exit 0' to skip a cell here.  Inside `capture noisily' in
        * a DO-FILE (as opposed to a program) `exit 0' is NOT trapped by
        * capture: it breaks out of the enclosing loop and skips the trailing
        * pass/fail branch entirely, so the cell increments test_count and
        * NEITHER counter.  That silently under-counts the sentinel -- this
        * file reported `tests=16 pass=14 fail=0' before this was found, and
        * the two missing cells looked exactly like a clean run.  Skip with a
        * flag instead, and reconcile the counters at the end.
        local skipped = 0
        capture noisily {
            * NOT A SKIP.  An unconstructible cell here is a CONFIRMED
            * PREDICTION, not an unrun check.  V2 has already asserted which
            * readings admit a tau: B does not (its improper F1 leaves ~50% of
            * subjects unfailing, so the censoring rate floors near 0.50 and the
            * paper's 15%/30% cells are unreachable at ANY tau), while A and C
            * do.  V3 arriving at the same place is evidence, so it is scored as
            * a pass and skip_count is NOT incremented.
            *
            * This distinction is not cosmetic.  run_all.do fails any suite
            * reporting skip>0, because its skip rule exists for a MISSING
            * DEPENDENCY -- an oracle that did not run and therefore proves
            * nothing.  Reporting these cells as skips conflated the two and
            * turned a designed, asserted result into a red lane.
            *
            * The two branches below are new and fail closed in BOTH directions:
            * a reading that stops being constructible when V2 says it must be,
            * and B becoming constructible when V2 says it cannot.  Previously
            * neither was checked -- any reading going unconstructible was
            * silently absorbed as a skip.
            if `reach_`rd'_`crlab'' == 0 {
                if "`rd'" != "B" {
                    display as error "  `rd' at `cr' is NOT constructible, but V2"
                    display as error "  asserts it must be.  The readings have moved."
                    exit 9
                }
                display as text "  `rd' at `cr': not constructible, exactly as V2" ///
                    " asserts -- confirmed, not skipped"
                local skipped = 1
            }
            else if "`rd'" == "B" {
                display as error "  B at `cr' IS constructible, contradicting V2's"
                display as error "  assertion that its censoring floor makes the"
                display as error "  paper's cells unreachable.  Re-derive the floor."
                exit 9
            }
            if !`skipped' {
            local tau = `tau_`rd'_`crlab''
            local pub = `pub_100_`crlab''
            set seed `=20260722 + 100000*`cr''
            local nrej = 0
            local ndrop = 0
            forvalues r = 1/`R' {
                _gen_pow_v 100 1 `tau' "`rd'"
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
                display as error "  `rd' `cr': `ndrop' of `R' dropped -- not a power estimate"
                exit 9
            }
            local pw = `nrej' / `neff'
            * TWO-SAMPLE SE.  The published value is itself a Monte Carlo
            * estimate from 2,000 samples (p.203), not a constant, so the
            * one-sample z used previously understates the uncertainty.
            local se = sqrt(`pub' * (1 - `pub') / 2000 + `pw' * (1 - `pw') / `neff')
            local z = (`pw' - `pub') / `se'
            file write `fp' "`rd',100,`cr',`tau',`pw',`neff',`ndrop',`pub',`se',`z'" _newline
            display as text "  `rd' n=100 cens " %4.2f `cr' ": power " %6.4f `pw' ///
                "  paper " %6.4f `pub' "  z " %7.2f `z' ///
                "  gap " %7.4f `=`pw' - `pub'' "  (dropped `ndrop')"

            * THE BRACKETING RESULT, ASSERTED.  Reading A runs ABOVE the
            * published cell and reading C runs BELOW it.  This is the finding
            * the screen exists to record, and it is more informative than
            * either reading alone: the published value is attainable only by
            * a cause-1 probability strictly between the model's own
            * F1(inf|Z) (reading C) and the flat 0.66 (reading A), which is
            * consistent with the paper having run a gamma or a p1 other than
            * the one it printed.  Assert the SIGN and a generous magnitude,
            * not the value -- the value is a 1,000-rep Monte Carlo estimate.
            if "`rd'" == "A" & `pw' <= `pub' {
                display as error "  A no longer runs above the published cell"
                exit 9
            }
            if "`rd'" == "C" & `pw' >= `pub' {
                display as error "  C no longer runs below the published cell"
                exit 9
            }
            }
        }
        if _rc == 0 {
            local ++pass_count
            * skip_count is deliberately NOT incremented for an unconstructible
            * cell -- see the note above.  Note plainly: after that change NO
            * path in this file increments skip_count, so the sentinel's skip=
            * field is a constant 0.  It is emitted anyway, as an affirmative
            * statement that nothing went unrun rather than as a live counter.
            * This suite has no external-oracle dependency to skip; if one is
            * ever added, increment skip_count THERE so run_all's dependency
            * rule can fail the lane as designed.
        }
        else {
            local ++fail_count
        }
    }
}
file close `fp'

**# Summary
* WHAT A GREEN RUN OF THIS FILE MEANS, PRECISELY.  It does NOT mean the paper
* was reproduced -- none of the three readings reproduces Tables 2 and 3.  It
* means the three named readings still behave as recorded in FINDINGS sec.20:
* their generator identities hold against closed forms, reading B still cannot
* construct the paper's censoring cells, and readings A and C still bracket the
* published value from above and below.  Those are the facts the power gate's
* weakened assertions rest on, so they are gated rather than narrated.
* COUNTER RECONCILIATION.  Every counted test must land in exactly one of
* pass/fail.  A test that increments test_count and neither counter is the
* failure this file already shipped once (see the `exit 0' note in V3), and it
* is invisible in a summary line that only reports fail=0.
if `pass_count' + `fail_count' != `test_count' {
    display as error "COUNTER MISMATCH: tests=`test_count' but pass+fail=" ///
        `=`pass_count' + `fail_count''
    display as error "Some test incremented neither counter -- the sentinel below"
    display as error "would understate the run.  This is a harness defect."
    capture log close _vdgp
    exit 9
}
display as text _newline ///
    "RESULT: _gof_power_dgp_variants tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _vdgp
    exit 9
}
capture log close _vdgp

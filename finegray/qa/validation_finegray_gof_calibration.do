* validation_finegray_gof_calibration.do
* Type I error of finegray_gof against Li, Scheike & Zhang (2015) Tables 1 and 4.
*
* THIS GATE DOES NOT ASSERT 0.05.  The test is anticonservative at small n BY
* THE AUTHORS' OWN MEASUREMENT (Table 1: 0.0624 at n=50), so a gate demanding
* 0.05 at n=50 fails on a correct implementation.  What is asserted is each
* cell's distance from the PUBLISHED value, plus three structural relations
* that hold across cells.
*
* WHY NOT THE MONOTONE EASING.  An earlier design asserted that type I error
* decreases monotonically toward 0.05 as n grows -- "the shape is stronger
* evidence than any single cell".  IT IS NOT, AND THAT GATE FAILS ON CORRECT
* CODE.  Measured at R=5000, neither censoring level is monotone:
*
*     15% censoring:  n=50 0.0616   n=100 0.0638   n=300 0.0566
*     30% censoring:  n=50 0.0600   n=100 0.0550   n=300 0.0586
*
* Adjacent-cell differences are smaller than the Monte Carlo noise on their
* difference, and even the n=50 -> n=300 endpoint drop is only +1.05 SE at 15%
* and +0.29 SE at 30%.  The paper's own monotone-looking column is within noise
* of these numbers.  Asserting the shape would go red on correct code roughly
* one run in three, which is worse than having no gate: a flaky gate trains its
* readers to re-run until green.  The relations asserted below were chosen
* because they are resolvable at this R; the shape is not.
*
* THE PAPER'S OWN NUMBERS WERE PRODUCED UNDER A DEFECTIVE WEIGHT, and that has
* now been checked rather than left as a caveat.  Tables 1 and 4 come from
* crskdiag, whose censoring KM is identically 1 on continuous data.  A
* simulation-calibrated test CAN stay correctly sized under a mis-specified
* weight, because observed and simulated processes share it -- but nobody had
* verified it.  With a correct censoring KM this implementation reproduces the
* published values (pooled prop 0.0593 vs 0.0585, z=+0.59; pooled func 0.0531
* vs 0.0531, z=-0.03) while both sit decisively above 0.05.  So the documented
* anticonservatism is a property of the statistic at small n, not an artifact
* of the authors' defect.
*
* RUNS THROUGH THE COMMAND, NOT THE MATA.  The Gate L4 development driver
* called _finegray_gof_* directly with a hand-rolled Newton fit, which is
* faster but leaves the entire ado layer -- option parsing, the refusal gates,
* preserve/restore, r() -- outside the calibration claim.  This suite fits with
* `finegray' and tests with `finegray_gof' so the numbers belong to the shipped
* command.
*
* DGPs read from the paper, not from recall:
*   sec. 3.1 p.204  F1(t|Z) = 1 - {1 - p1(1-e^-t)}^exp(bZ),  p1 = .66, b = .2
*                   F2(t|Z) = (1-p1)^exp(bZ) {1 - e^(-t exp(bZ))}
*                   Z binary, half and half.
*   sec. 3.2 p.206  same model, single covariate Z in {0,...,9}, equal shares.
*   both            censoring U(0,tau], tau tuned to 15% / 30%; 5,000 reps.
clear all
set varabbrev off
set more off
version 16.0
set type double

capture log close _all
log using "validation_finegray_gof_calibration.log", replace name(_vgof)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "validation_finegray_gof_calibration.do must run from finegray/qa"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* R is the replication count.  The gate value is 5000, matching the paper.
* GOF_CAL_REPS exists so the harness can be exercised quickly during
* development; a reduced run is NOT the gate and says so in its own output.
local R = 5000
if "$GOF_CAL_REPS" != "" local R = $GOF_CAL_REPS
local K = 1000
local reduced = (`R' < 5000)

local test_count = 0
local pass_count = 0
local fail_count = 0

* ---------------------------------------------------------------------------
* The paper's DGP, by inverse CDF within each cause branch.
* design 1: Z binary (proportionality cells, Table 1)
* design 2: Z in {0,...,9} (functional-form and link cells, Table 4)
* ---------------------------------------------------------------------------
capture program drop _gen_lsz
program define _gen_lsz
    version 16.0
    args n design tau
    clear
    quietly set obs `n'
    local p1 = 0.66
    local bet = 0.2
    if `design' == 1 gen double Z = mod(_n, 2)
    else             gen double Z = mod(_n - 1, 10)

    gen double _a = exp(`bet' * Z)
    gen double _F1inf = 1 - (1 - `p1') ^ _a
    gen double _u = runiform()
    gen byte _c1 = (_u <= _F1inf)
    gen double _up = cond(_c1, _u / _F1inf, (_u - _F1inf) / (1 - _F1inf))
    quietly replace _up = 0.999999999 if _up >= 1
    gen double _T = cond(_c1, ///
        -ln(1 - (1 - (1 - _up * (1 - (1 - `p1') ^ _a)) ^ (1 / _a)) / `p1'), ///
        -ln(1 - _up) / _a)
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
capture program drop _tau_for
program define _tau_for, rclass
    version 16.0
    args design target
    local lo = 0.05
    local hi = 500
    set seed 777
    forvalues it = 1/60 {
        local mid = (`lo' + `hi') / 2
        _gen_lsz 200000 `design' `mid'
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

* ---- published values (Tables 1 and 4) ------------------------------------
* prop: design 1;  func/link: design 2.  Indexed n x censoring.
local pub_prop_50_15  = 0.0624
local pub_prop_100_15 = 0.0606
local pub_prop_300_15 = 0.0536
local pub_prop_50_30  = 0.0642
local pub_prop_100_30 = 0.0564
local pub_prop_300_30 = 0.0536
local pub_func_50_15  = 0.0568
local pub_func_100_15 = 0.0514
local pub_func_300_15 = 0.0478
local pub_func_50_30  = 0.0556
local pub_func_100_30 = 0.0566
local pub_func_300_30 = 0.0506

display as text _newline "Gate L4 -- type I error at nominal 0.05, R=`R' reps, nsim=`K'"
if `reduced' {
    display as error "REDUCED RUN (R=`R' < 5000): this is a harness exercise,"
    display as error "NOT the calibration gate.  Cell tolerances are widened"
    display as error "accordingly and the result must not be reported as the gate."
}

tempname fh
file open `fh' using "gof_calibration_cells.csv", write replace
file write `fh' "design,n,cens_target,tau,cens_obs,rej_prop,rej_func,rej_link,ndrop" _newline

* accumulators for the pooled comparisons
local sum_prop = 0
local n_prop = 0
local sum_func = 0
local n_func = 0

forvalues dg = 1/2 {
    foreach cr in 0.15 0.30 {
        _tau_for `dg' `cr'
        local tau = r(tau)
        local crlab = cond(`cr' == 0.15, "15", "30")

        foreach n in 50 100 300 {
            local ++test_count
            capture noisily {
                set seed `=20260720 + `n' + 1000*`dg' + 100000*`cr''
                local nrej_p = 0
                local nrej_f = 0
                local nrej_l = 0
                local ndrop = 0
                local cens = 0

                forvalues r = 1/`R' {
                    _gen_lsz `n' `dg' `tau'
                    quietly count if cause == 0
                    local cens = `cens' + r(N) / _N

                    capture quietly finegray Z, compete(cause) cause(1) ///
                        censvalue(0) nolog
                    if _rc | e(converged) != 1 {
                        local ++ndrop
                        continue
                    }
                    if `dg' == 1 {
                        capture quietly finegray_gof, proportional nsim(`K')
                        if _rc {
                            local ++ndrop
                            continue
                        }
                        matrix _G = r(gof)
                        local nrej_p = `nrej_p' + (_G[1,2] <= 0.05)
                    }
                    else {
                        capture quietly finegray_gof, funcform(Z) link nsim(`K')
                        if _rc {
                            local ++ndrop
                            continue
                        }
                        matrix _F = r(funcform)
                        local nrej_f = `nrej_f' + (_F[1,2] <= 0.05)
                        local nrej_l = `nrej_l' + (r(p_link) <= 0.05)
                    }
                }

                local neff = `R' - `ndrop'
                if `neff' < 0.9 * `R' {
                    display as error "    `ndrop' of `R' replications dropped --"
                    display as error "    the cell is not a type I error at this n"
                    exit 9
                }
                local rp = `nrej_p' / `neff'
                local rf = `nrej_f' / `neff'
                local rl = `nrej_l' / `neff'
                local co = `cens' / `R'
                file write `fh' "`dg',`n',`cr',`tau',`co',`rp',`rf',`rl',`ndrop'" _newline

                * Monte Carlo SE of the cell, at the published value
                if `dg' == 1 {
                    local obs = `rp'
                    local pub = `pub_prop_`n'_`crlab''
                    local lab "prop"
                    local sum_prop = `sum_prop' + `nrej_p'
                    local n_prop = `n_prop' + `neff'
                }
                else {
                    local obs = `rf'
                    local pub = `pub_func_`n'_`crlab''
                    local lab "func"
                    local sum_func = `sum_func' + `nrej_f'
                    local n_func = `n_func' + `neff'
                }
                local se = sqrt(`pub' * (1 - `pub') / `neff')
                local z = (`obs' - `pub') / `se'

                display as text "  `lab' n=" %4.0f `n' " cens " %5.2f `cr' ///
                    "  obs " %6.4f `obs' "  paper " %6.4f `pub' ///
                    "  z " %6.2f `z' "  (cens obs " %5.3f `co' ", dropped `ndrop')"

                * A reduced run has a larger SE, so the band is widened by the
                * SAME factor rather than being quietly reused at gate width.
                local band = cond(`reduced', 4, 3)
                if abs(`z') > `band' {
                    display as error "    cell is `=abs(`z')' SE from the published value"
                    exit 9
                }

                * design 2 also produces the link cell.  With ONE covariate the
                * link indicator set and the functional-form indicator set are
                * the same set, so the two statistics must agree closely; a
                * large gap means the link axis is being built from something
                * other than the linear predictor.
                if `dg' == 2 {
                    local dfl = abs(`rf' - `rl')
                    * The bound SCALES WITH R.  A flat 0.010 is an assertion
                    * about the replication count, not about the link axis: at
                    * R=60 a single differing rejection is 0.0167 and trips it,
                    * so a reduced run fails on correct code.  3 Monte Carlo SE
                    * of the difference is the same claim expressed at whatever
                    * R is actually running.
                    local se_fl = sqrt(2 * `rf' * (1 - `rf') / `neff')
                    local bnd_fl = max(0.010, 3 * `se_fl')
                    display as text "        link " %6.4f `rl' ///
                        "   |func - link| " %6.4f `dfl' ///
                        "   bound " %6.4f `bnd_fl'
                    if `dfl' > `bnd_fl' {
                        display as error "    func and link differ by `dfl' with a"
                        display as error "    single covariate, where they index the"
                        display as error "    same set -- the link axis is wrong"
                        exit 9
                    }
                }
            }
            if _rc == 0 {
                local ++pass_count
                display as result "  PASS: cell design `dg' n=`n' cens `cr'"
            }
            else {
                local ++fail_count
                display as error "  FAIL: cell design `dg' n=`n' cens `cr' (rc=`=_rc')"
            }
        }
    }
}
file close `fh'

* ===========================================================================
* Pooled relations.  These are what survive at R=5000; the per-cell z above is
* noisy, the pooled contrast is not.
* ===========================================================================
local ++test_count
capture noisily {
    local pool_prop = `sum_prop' / `n_prop'
    local pool_func = `sum_func' / `n_func'
    local se_prop = sqrt(`pool_prop' * (1 - `pool_prop') / `n_prop')
    local se_func = sqrt(`pool_func' * (1 - `pool_func') / `n_func')

    local z_prop_05 = (`pool_prop' - 0.05) / `se_prop'
    local z_func_05 = (`pool_func' - 0.05) / `se_func'
    local se_diff = sqrt(`se_prop'^2 + `se_func'^2)
    local z_diff = (`pool_prop' - `pool_func') / `se_diff'

    display as text _newline "pooled proportionality " %6.4f `pool_prop' ///
        "  (vs 0.05: z = " %5.2f `z_prop_05' ")"
    display as text "pooled functional form " %6.4f `pool_func' ///
        "  (vs 0.05: z = " %5.2f `z_func_05' ")"
    display as text "prop - func            " %6.4f `=`pool_prop' - `pool_func'' ///
        "  (z = " %5.2f `z_diff' ")"

    * THE POOLED ASSERTIONS ARE GATE-ONLY.  Both are statements about
    * resolving a ~0.008 effect, which needs the full R: at R=60 the SE of a
    * cell is 0.028 and z=1.27 is indistinguishable from noise.  Asserting them
    * on a reduced run fails on correct code and teaches the reader that the
    * suite is flaky.  They are printed either way so the reduced run still
    * shows its numbers.
    if `reduced' {
        display as error "pooled relations NOT ASSERTED at R=`R' -- they need"
        display as error "R=5000 to resolve.  This run makes no calibration claim."
        exit 0
    }

    * (1) the proportionality test IS anticonservative -- the paper's central
    *     claim about it, and the reason the help file says so
    if `z_prop_05' < 2 {
        display as error "pooled proportionality is not above 0.05 (z=`z_prop_05');"
        display as error "the paper reports 0.0585 pooled, so this is a regression"
        display as error "in the test, not a happy correction of it"
        exit 9
    }
    * (2) proportionality is MORE anticonservative than functional form, which
    *     is the ordering the paper's Tables 1 and 4 show
    if `z_diff' < 1.5 {
        display as error "proportionality is not more anticonservative than"
        display as error "functional form (z=`z_diff'); the paper's ordering is lost"
        exit 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: pooled relations match the paper's ordering"
}
else {
    local ++fail_count
    display as error "  FAIL: pooled relations (rc=`=_rc')"
}

**# Summary
* A REDUCED RUN EMITS NO SENTINEL.  It would otherwise print a green
* "RESULT: ... fail=0" that run_all.do counts as a passing gate -- a 60-rep
* harness exercise recorded as the 5,000-rep calibration.  run_all treats a
* missing sentinel as a failure, so withholding it fails closed.
if `reduced' {
    display as error _newline "REDUCED RUN (R=`R'): NOT the calibration gate."
    display as error "No RESULT sentinel is emitted, so this run cannot be"
    display as error "recorded as a pass.  Re-run without GOF_CAL_REPS for the gate."
    display as text "  (harness only: tests=`test_count' pass=`pass_count' fail=`fail_count')"
    capture log close _vgof
    exit 0
}
display as text _newline ///
    "RESULT: validation_finegray_gof_calibration tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _vgof
    exit 9
}
capture log close _vgof

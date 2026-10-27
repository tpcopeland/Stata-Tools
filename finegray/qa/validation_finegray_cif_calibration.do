* validation_finegray_cif_calibration.do - Inference calibration of the
* analytic finegray_cif interval (right censoring, unclustered, no delayed
* entry) against the true population CIF (Monte Carlo)
* Package: finegray
*
* Usage (from finegray/qa):
*   stata-mp -b do validation_finegray_cif_calibration.do          gate (R = 2000)
*   stata-mp -b do validation_finegray_cif_calibration.do smoke    10 replicates
*   global FG_CAL_REPS 50, then run the file                       50 replicates
* Any run whose R differs from R_GATE is a smoke run: it checks the code path
* (every replicate returns a finite CIF, SE and CI at every cell; counters
* reconcile; the CI contract holds), never applies a band, prints smoke=1 on
* the RESULT line, and is never gate evidence.
*
* Companion of validation_finegray_cif_recovery.do (point recovery at large
* N on the same generator) and of validation_finegray_lt_cluster_cif_se.do
* (the same question for the clustered delayed-entry route, whose structure
* this file follows). This file covers the plain route those two leave open.
*
* WHAT IS BEING CALIBRATED. finegray_cif, at(...) attime(...) ci reports in
* r(table) the CIF (col 2), its influence-function standard error on the CIF
* scale (col 3), and limits (cols 4-5). finegray_cif.sthlp (option ci): the
* SE is an influence-function sandwich that treats the fitted censoring
* weights as known, and the limits are formed on the complementary log-log
* scale, theta = ln(-ln(1 - F)), se_theta = se / {(1 - F)(-ln(1 - F))}
* (delta method), limits 1 - exp(-exp(theta -/+ z se_theta)); the code is
* _finegray_cloglog_ci in _finegray_mata.ado. So the SE gate is on the CIF
* scale and the coverage gate is on the reported cloglog interval. The
* sthlp warns the fixed-weight SE "can omit weight-estimation variability"
* under heavy censoring; design H exists to measure that.
*
* Fine & Gray (1999) sec. 5, pp.501-502 (notes _literature/finegray/
* fine-gray-1999.notes.md): the CIF process has a subject-level martingale
* representation with baseline, regression-estimation and censoring-
* estimation contributions; finegray's analytic SE carries the first two and
* drops the third (fixed weights). The corpus gives no sign for the dropped
* term, so neither over- nor under-coverage is predicted.
*
* ADEMP (written 2026-10-27 before the gated run; Morris, White & Crowther
* 2019, Table 1)
*   Aims        Is the analytic CIF SE calibrated, and does the reported 95%
*               cloglog interval cover the true population CIF at the
*               nominal rate, at several horizons and covariate profiles?
*   DGP         Fine & Gray (1999) direct CIF model, generator _fg_cif_dgp
*               copied from validation_finegray_cif_recovery.do (the one
*               change: the seed is set once per design by the caller, not
*               on every call). z1 ~ N(0,1), p = 0.4, b = 0.5, cause-2 times
*               Exp(1), censoring C ~ U(0, cmax), N = 500 per replicate.
*                 L  cmax = 8   (light censoring, about 11% censored;
*                               G(2) = 0.75)
*                 H  cmax = 2.5 (heavy censoring, about 37% censored;
*                               G(2) = 0.20)
*   Estimand    F1(t; z) = 1 - (1 - p(1 - exp(-t)))^exp(b z) at profiles
*               z1 = 0 (F1 = p(1 - exp(-t))) and z1 = 1, horizons t = 0.5, 1,
*               2: six cells per design. G0 below checks the generator
*               against this closed form before any replicate is run.
*   Methods     finegray z1, compete(status) cause(1) (default fixed-weight
*               fit), then finegray_cif, at(z1=0) / at(z1=1) attime(0.5 1 2)
*               ci nograph; r(se_method) must be "analytic". The interval
*               read is the one the command reports, never rebuilt.
*               Negative control: the reported interval halved in width on
*               the cloglog scale (the same replicates), which must fall
*               below the band in every design-L cell.
*   Performance per cell: coverage of F1(t; z) by the reported 95% CI
*               (gate); ModSE/EmpSE of the CIF with ModSE = sqrt(mean(se^2))
*               (gate); bias with MCSE, EmpSE with MCSE, bias-eliminated
*               coverage and mean width (reported, diagnostic); replicate
*               failures (gate: zero).
*
* R AND ITS MCSE. R = 2000 per design, sized by R = p(1-p)/MCSE^2 (Morris et
* al. eq. 1, p.2089) for a coverage MCSE of 0.5 points at p = 0.95 (1900,
* rounded up): band [0.9354, 0.9646]; ModSE/EmpSE MCSE about 0.016, so the
* ratio gate is about 1 +/- 0.047. Pilot timing (20 replicates, processors
* 1): 0.05 s per replicate (one fit, two finegray_cif calls); the full run is
* 2 x 2000 replicates, well inside 30 minutes single-threaded.
*
* SEEDS. set rng mt64; design L seed 20261031, design H 20261101, G0
* 20261102, each set once; every replicate's c(rngstate) is retained in the
* result set, so a failing replicate is replayed alone with set rngstate.
*
* GATES (computed below from R, never typed)
*   coverage in 0.95 +/- 3*sqrt(0.95*0.05/R), every cell
*   |ModSE/EmpSE - 1| <= 3*MCSE(ratio), MCSE per Morris et al. Table 6,
*   every cell
*   every replicate: the fit converges and both finegray_cif calls return
*   se_method analytic and a finite CIF, positive SE and finite CI at every
*   horizon (n_ok == R)
*   CI contract: the reported limits equal the cloglog construction above
*   to 1e-10 on every replicate and cell
*   negative control: half-width interval below the band, every L cell
* 24 band gates at 3 MCSE: the Bonferroni bound on a correct estimator
* tripping one by Monte Carlo noise is 6.5%; the cells share replicates and
* are strongly correlated, so the real rate is lower. Seeds are fixed, so the
* outcome is a deterministic draw, not a flaky gate.
*
* EXPECTED CLASS PER CELL (pre-registered)
*   L, all six cells: NOMINAL.
*   H, all six cells: NOMINAL, at risk at t = 2 where the weights matter
*   most. No route is documented as conservative, so CONSERVATIVE-DECLARED
*   is unavailable: a miss in either direction is DEFECT.
*
* WORKED RUN 2026-10-27 (Stata 17 MP, processors 1, R = 2000 per design,
* 175 s; recorded after the gates above were frozen). 2000/2000 replicates
* usable in both designs; censored fraction 0.124 (L), 0.360 (H). Ratio
* MCSE 0.016 and coverage band [0.9354, 0.9646] in every cell; |bias| below
* 0.0010 everywhere (at most 1.9 MCSE).
*   cell        L coverage  L ratio   H coverage  H ratio
*   z1=0 t=0.5  0.9540      0.9871    0.9470      0.9890
*   z1=0 t=1    0.9580      1.0091    0.9560      1.0161
*   z1=0 t=2    0.9480      0.9941    0.9565      1.0344
*   z1=1 t=0.5  0.9450      0.9854    0.9565      1.0136
*   z1=1 t=1    0.9455      1.0101    0.9590      1.0296
*   z1=1 t=2    0.9470      1.0112    0.9570      1.0300
* Half-width negative control coverage 0.656-0.687 in every L cell.
* Classes: all twelve cells NOMINAL. Under heavy censoring the fixed-weight
* SE drifts conservative (ratio 1.03 at t >= 1, about 2 MCSE, coverage
* 0.956-0.959), inside the band: on this DGP ignoring weight estimation
* overstates rather than understates the CIF variance.

version 16.0
clear all
set more off
set varabbrev off
set rng mt64
set linesize 160

args mode
local smoke_arg = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke_arg' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}

local qa_dir "`c(pwd)'"
local suite "validation_finegray_cif_calibration"
capture log close _cifcal
log using "`qa_dir'/`suite'.log", replace text name(_cifcal)

**# Setup
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"

**# Predeclared design
local R_GATE  = 2000
local SMOKE_R = 10
local R = `R_GATE'
if `smoke_arg' local R = `SMOKE_R'
if "$FG_CAL_REPS" != "" {
    capture confirm integer number $FG_CAL_REPS
    local bad_reps = _rc
    if !`bad_reps' local bad_reps = ($FG_CAL_REPS < 2)
    if `bad_reps' {
        display as error "FG_CAL_REPS must be an integer of at least 2"
        exit 198
    }
    local R = $FG_CAL_REPS
}
local smoke = (`R' != `R_GATE')

local NOMINAL = 0.95
local NOBS    = 500
local P       = 0.4
local B       = 0.5
local PROFS   0 1
local HORIZ   0.5 1 2
local NP : word count `PROFS'
local NH : word count `HORIZ'
local SEED_L  = 20261031
local SEED_H  = 20261101
local SEED_G  = 20261102

local cov_mcse = sqrt(`NOMINAL' * (1 - `NOMINAL') / `R')
local cov_lo   = `NOMINAL' - 3 * `cov_mcse'
local cov_hi   = `NOMINAL' + 3 * `cov_mcse'

* True population CIF of the DGP at profile z1 = j, horizon t = k
forvalues j = 1/`NP' {
    local zz : word `j' of `PROFS'
    forvalues k = 1/`NH' {
        local tt : word `k' of `HORIZ'
        local truth_`j'_`k' = 1 - (1 - `P'*(1 - exp(-`tt')))^exp(`B'*`zz')
    }
}

display as text "`suite': R=`R' per design (gate R=`R_GATE'), smoke=`smoke', N=`NOBS'"
display as text "  coverage band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (MCSE " %6.4f `cov_mcse' ")"

local test_count = 0
local pass_count = 0
local fail_count = 0

timer clear 1
timer on 1

capture program drop _cal_test
program define _cal_test
    args ok label
    if `ok' == 1 {
        display as result "  PASS: `label'"
    }
    else {
        display as error "  FAIL: `label'"
    }
end

**# Generator (from validation_finegray_cif_recovery.do; seed set by caller)
capture program drop _fg_cif_dgp
program define _fg_cif_dgp
    syntax , n(integer) p(real) b(real) [seed(integer 0) cmax(real 8)]
    clear
    if `seed' > 0 set seed `seed'
    quietly set obs `n'
    * stata-dev-ignore: unseeded-draw — this is a generator PROGRAM, not a script: the seed is set once per design before its replicate loop (SEED_L/SEED_H) or passed by G0, and each replicate's c(rngstate) is retained, so every draw in this file replays
    gen double z1 = rnormal()
    gen double lp = `b'*z1
    gen double _pz = 1 - (1-`p')^exp(lp)
    gen double _u  = runiform()
    gen byte cause = cond(runiform() < _pz, 1, 2)
    gen double _t1 = -ln(1 - (1 - (1 - _u*_pz)^exp(-lp))/`p')
    gen double _t2 = -ln(runiform())
    gen double tevent = cond(cause==1, _t1, _t2)
    gen double c = runiform()*`cmax'
    gen double time = min(tevent, c)
    gen byte status = cond(tevent <= c, cause, 0)
    gen byte anyevent = status > 0
    gen long id = _n
    drop _pz _u _t1 _t2
end

**# G0: the generator produces the closed-form CIF
* With no effective censoring, the empirical proportion of cause-1 events by
* t must equal the sample average of F1(t; z1) over the drawn z1, and the
* subsample near z1 = 0 and z1 = 1 must match the profile truths used as
* the estimand below.
local ++test_count
local g0max = .
capture noisily {
    _fg_cif_dgp, n(400000) p(`P') b(`B') seed(`SEED_G') cmax(1e6)
    local g0max = 0
    foreach tt of local HORIZ {
        gen double ftrue = 1 - (1 - `P'*(1 - exp(-`tt')))^exp(`B'*z1)
        gen byte hit = (cause == 1 & tevent <= `tt')
        quietly summarize ftrue, meanonly
        local fbar = r(mean)
        quietly summarize hit, meanonly
        local g0err = abs(r(mean) - `fbar')
        assert !missing(`g0err')
        * 3 Monte Carlo SEs of a proportion at n = 400,000 is at most 0.0024
        assert `g0err' < 0.004
        if `g0err' > `g0max' local g0max = `g0err'
        forvalues j = 1/`NP' {
            local zz : word `j' of `PROFS'
            local k : list posof "`tt'" in HORIZ
            quietly summarize hit if abs(z1 - `zz') < 0.03, meanonly
            local nwin = r(N)
            local werr = abs(r(mean) - `truth_`j'_`k'')
            assert `nwin' > 5000
            * F1 is near-linear in z1 over a +/-0.03 window (slope under 0.2),
            * so the window adds well under 0.001; binomial 3 MCSE at
            * n > 5000 is at most 0.021
            assert !missing(`werr')
            assert `werr' < 0.025
        }
        drop ftrue hit
    }
}
local ok = (_rc == 0)
_cal_test `ok' "G0 generator matches the closed-form CIF (max |marginal diff| `=string(`g0max', "%7.5f")')"
if `ok' local ++pass_count
else local ++fail_count

**# Replication engine
* One pass per design. Every replicate is posted, including failures, with
* the rc of the first failing step and its start-of-replicate c(rngstate).
* Cell (j, k) = profile j, horizon k; variables f_j_k, s_j_k, l_j_k, u_j_k.
capture program drop _cifcal_run
program define _cifcal_run
    syntax , R(integer) NOBS(integer) P(real) B(real) CMAX(real) ///
        SEED(integer) PROFS(numlist) HORIZ(numlist) SAVING(string)
    local np : word count `profs'
    local nh : word count `horiz'
    local zcrit = invnormal(0.975)

    local pvars ""
    forvalues j = 1/`np' {
        forvalues k = 1/`nh' {
            local pvars "`pvars' f_`j'_`k' s_`j'_`k' l_`j'_`k' u_`j'_`k'"
        }
    }
    tempname PF T CI
    postfile `PF' long rep int(rc step) double(cens dev `pvars') ///
        using "`saving'", replace
    mata: _cifcal_states = J(`r', 1, "")
    set seed `seed'
    forvalues i = 1/`r' {
        mata: _cifcal_states[`i'] = c("rngstate")
        _fg_cif_dgp, n(`nobs') p(`p') b(`b') cmax(`cmax')
        quietly count if status == 0
        local cens = r(N)/_N
        quietly stset time, failure(anyevent==1) id(id)

        local rc = 0
        local step = 0
        local dev = 0
        forvalues j = 1/`np' {
            forvalues k = 1/`nh' {
                foreach v in f s l u {
                    local `v'_`j'_`k' = .
                }
            }
        }
        capture quietly finegray z1, compete(status) cause(1) nolog
        local rc = _rc
        if !`rc' & e(converged) != 1 local rc = 430
        forvalues j = 1/`np' {
            if `rc' continue
            local zz : word `j' of `profs'
            capture quietly finegray_cif, at(z1=`zz') attime(`horiz') ci nograph
            local rc = _rc
            if !`rc' & `"`r(se_method)'"' != "analytic" local rc = 3300
            if !`rc' {
                matrix `T' = r(table)
                if rowsof(`T') != `nh' local rc = 3301
            }
            if !`rc' {
                forvalues k = 1/`nh' {
                    local tt : word `k' of `horiz'
                    if reldif(`T'[`k', 1], `tt') > 1e-12 local rc = 3302
                    local f_`j'_`k' = `T'[`k', 2]
                    local s_`j'_`k' = `T'[`k', 3]
                    local l_`j'_`k' = `T'[`k', 4]
                    local u_`j'_`k' = `T'[`k', 5]
                    if missing(`f_`j'_`k'', `s_`j'_`k'', `l_`j'_`k'', `u_`j'_`k'') ///
                        | `s_`j'_`k'' <= 0 local rc = 504
                    if !`rc' {
                        * Independent rebuild of the documented cloglog limits.
                        local F = `f_`j'_`k''
                        local a = -ln(1 - `F')
                        local st = `s_`j'_`k'' / ((1 - `F') * `a')
                        local lo = 1 - exp(-exp(ln(`a') - `zcrit'*`st'))
                        local hi = 1 - exp(-exp(ln(`a') + `zcrit'*`st'))
                        local dev = max(`dev', abs(`lo' - `l_`j'_`k''), ///
                            abs(`hi' - `u_`j'_`k''))
                    }
                }
            }
            if `rc' local step = `j'
        }
        if `rc' local dev = .
        local plist ""
        forvalues j = 1/`np' {
            forvalues k = 1/`nh' {
                local plist "`plist' (`f_`j'_`k'') (`s_`j'_`k'') (`l_`j'_`k'') (`u_`j'_`k'')"
            }
        }
        post `PF' (`i') (`rc') (`step') (`cens') (`dev') `plist'
    }
    postclose `PF'
    preserve
    use "`saving'", clear
    sort rep
    quietly gen strL rngstate = ""
    mata: st_sstore(., "rngstate", _cifcal_states)
    mata: mata drop _cifcal_states
    quietly save "`saving'", replace
    restore
end

* Performance of one cell on the posted result set (in memory).
capture program drop _cal_metrics
program define _cal_metrics, rclass
    syntax , B(varname) SE(varname) LO(varname) HI(varname) TRUTH(real)
    tempvar v cv cvbe cvneg
    local okif "!missing(`b', `se', `lo', `hi')"
    quietly count if `okif'
    local n = r(N)
    return scalar n = `n'
    if `n' < 2 {
        foreach s in bias bias_mcse empse empse_mcse modse ratio ratio_mcse ///
            coverage becoverage negcoverage width {
            return scalar `s' = .
        }
        exit
    }
    quietly summarize `b' if `okif'
    local mean_b = r(mean)
    local empse = r(sd)
    return scalar bias = `mean_b' - `truth'
    return scalar bias_mcse = r(sd) / sqrt(`n')
    return scalar empse = `empse'
    return scalar empse_mcse = `empse' / sqrt(2 * (`n' - 1))
    quietly gen double `v' = `se'^2 if `okif'
    quietly summarize `v'
    local modse = sqrt(r(mean))
    local var_v = r(Var)
    return scalar modse = `modse'
    return scalar ratio = `modse' / `empse'
    * Morris et al. Table 6, relative error in ModSE, evaluated at ratio 1.
    return scalar ratio_mcse = sqrt(`var_v' / (4 * `n' * `modse'^4) + 1 / (2 * (`n' - 1)))
    quietly gen byte `cv' = (`lo' <= `truth' & `truth' <= `hi') if `okif'
    quietly summarize `cv', meanonly
    return scalar coverage = r(mean)
    * Bias-eliminated coverage (Morris et al. p.2087): a diagnostic only.
    quietly gen byte `cvbe' = (`lo' <= `mean_b' & `mean_b' <= `hi') if `okif'
    quietly summarize `cvbe', meanonly
    return scalar becoverage = r(mean)
    * Negative control: the reported interval at half its cloglog half-width.
    * On theta = ln(-ln(1-F)) the reported limits are theta -/+ d, so the
    * half-width limits are the cloglog midpoint -/+ d/2.
    local cll "ln(-ln(1 - `lo'))"
    local cul "ln(-ln(1 - `hi'))"
    quietly gen byte `cvneg' = ///
        (1 - exp(-exp(0.75*`cll' + 0.25*`cul')) <= `truth' & ///
         `truth' <= 1 - exp(-exp(0.25*`cll' + 0.75*`cul'))) if `okif'
    quietly summarize `cvneg', meanonly
    return scalar negcoverage = r(mean)
    tempvar w
    quietly gen double `w' = `hi' - `lo' if `okif'
    quietly summarize `w', meanonly
    return scalar width = r(mean)
end

**# Designs
local designs "L H"
local L_cmax = 8
local L_seed = `SEED_L'
local L_label "light censoring, C ~ U(0, 8)"
local H_cmax = 2.5
local H_seed = `SEED_H'
local H_label "heavy censoring, C ~ U(0, 2.5)"

foreach d of local designs {
    display as text _newline "Design `d': ``d'_label', N=`NOBS', R=`R', seed ``d'_seed'"
    tempfile res`d'
    _cifcal_run, r(`R') nobs(`NOBS') p(`P') b(`B') cmax(``d'_cmax') ///
        seed(``d'_seed') profs(`PROFS') horiz(`HORIZ') saving("`res`d''")

    use "`res`d''", clear
    quietly count if rc == 0
    local `d'_nok = r(N)
    quietly count if rc != 0
    local `d'_nbad = r(N)
    quietly summarize cens, meanonly
    local `d'_cens = r(mean)
    quietly summarize dev, meanonly
    local `d'_dev = r(max)
    if ``d'_nbad' > 0 {
        quietly levelsof rep if rc != 0, local(badreps)
        display as error "    failed replicates: `badreps' (replay with set rngstate from the result set)"
        tabulate rc step if rc != 0
    }
    display as text "    replicates usable ``d'_nok' of `R' (failed ``d'_nbad'); mean censored fraction " %5.3f ``d'_cens'

    local cells_n_ok = 1
    forvalues j = 1/`NP' {
        local zz : word `j' of `PROFS'
        forvalues k = 1/`NH' {
            local tt : word `k' of `HORIZ'
            _cal_metrics, b(f_`j'_`k') se(s_`j'_`k') lo(l_`j'_`k') ///
                hi(u_`j'_`k') truth(`truth_`j'_`k'')
            foreach s in n bias bias_mcse empse empse_mcse modse ratio ///
                ratio_mcse coverage becoverage negcoverage width {
                local `d'_`j'_`k'_`s' = r(`s')
            }
            if ``d'_`j'_`k'_n' != `R' local cells_n_ok = 0
            display as text "    z1=`zz' t=`tt'  truth " %7.5f `truth_`j'_`k'' ///
                "  bias " %8.5f ``d'_`j'_`k'_bias' " (MCSE " %7.5f ``d'_`j'_`k'_bias_mcse' ///
                ")  EmpSE " %7.5f ``d'_`j'_`k'_empse' " (MCSE " %7.5f ``d'_`j'_`k'_empse_mcse' ///
                ")  ModSE " %7.5f ``d'_`j'_`k'_modse'
            display as text "                  ratio " %6.4f ``d'_`j'_`k'_ratio' ///
                " (MCSE " %6.4f ``d'_`j'_`k'_ratio_mcse' ")  coverage " %6.4f ``d'_`j'_`k'_coverage' ///
                "  bias-elim. " %6.4f ``d'_`j'_`k'_becoverage' ///
                "  half-width neg. " %6.4f ``d'_`j'_`k'_negcoverage' ///
                "  mean width " %6.4f ``d'_`j'_`k'_width'
        }
    }

    **## Every replicate retained and usable (both modes)
    local ++test_count
    local ok = (``d'_nok' == `R' & ``d'_nbad' == 0 & `cells_n_ok')
    _cal_test `ok' "`d' all `R' replicates converged and returned analytic CIF, SE, CI at all `=`NP'*`NH'' cells (failed: ``d'_nbad')"
    if `ok' local ++pass_count
    else local ++fail_count

    **## CI contract: reported limits are the documented cloglog interval
    local ++test_count
    local ok = (``d'_dev' < 1e-10 & ``d'_dev' < .)
    local lab : display "`d' CI contract: max |reported - rebuilt cloglog limit| " %8.2e ``d'_dev'
    _cal_test `ok' "`lab'"
    if `ok' local ++pass_count
    else local ++fail_count

    if !`smoke' {
        forvalues j = 1/`NP' {
            local zz : word `j' of `PROFS'
            forvalues k = 1/`NH' {
                local tt : word `k' of `HORIZ'

                **## Coverage of the reported 95% CI inside nominal +/- 3 MCSE
                local ++test_count
                local c = ``d'_`j'_`k'_coverage'
                local ok = (`c' >= `cov_lo' & `c' <= `cov_hi' & `c' < .)
                local lab : display "`d' z1=`zz' t=`tt' coverage " %6.4f `c' " in [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "]"
                _cal_test `ok' "`lab'"
                if `ok' local ++pass_count
                else local ++fail_count

                **## ModSE/EmpSE inside 1 +/- 3 MCSE
                local ++test_count
                local q = ``d'_`j'_`k'_ratio'
                local qm = ``d'_`j'_`k'_ratio_mcse'
                local ok = (abs(`q' - 1) <= 3 * `qm' & `q' < . & `qm' < .)
                local lab : display "`d' z1=`zz' t=`tt' ModSE/EmpSE " %6.4f `q' " within 1 +/- " %6.4f 3*`qm'
                _cal_test `ok' "`lab'"
                if `ok' local ++pass_count
                else local ++fail_count
            }
        }
    }
}

**# Negative control (gate mode only)
* The half-width interval on the same design-L replicates must fall below the
* band in every cell: a gate that cannot go red on an SE that is half its
* size cannot detect one that is too small.
if !`smoke' {
    local ++test_count
    local ok = 1
    local negmax = 0
    forvalues j = 1/`NP' {
        forvalues k = 1/`NH' {
            local c = `L_`j'_`k'_negcoverage'
            if !(`c' < `cov_lo' & `c' < .) local ok = 0
            if `c' > `negmax' | missing(`c') local negmax = `c'
        }
    }
    local lab : display "L half-width negative control: max coverage " %6.4f `negmax' " below " %6.4f `cov_lo' " in every cell"
    _cal_test `ok' "`lab'"
    if `ok' local ++pass_count
    else local ++fail_count
}

**# Summary
timer off 1
quietly timer list 1
local secs = round(r(t1))

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

display as text _newline "Results: `pass_count'/`test_count' passed, `fail_count' failed; runtime `secs' s"
display "RESULT: `suite' tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=`smoke' secs=`secs'"
if `fail_count' > 0 {
    display as error "SOME CHECKS FAILED"
    log close _cifcal
    exit 1
}
if `smoke' {
    display as text "SMOKE RUN: code path exercised only; not gate evidence"
    log close _cifcal
    exit 0
}
display as result "ALL CHECKS PASSED"
log close _cifcal

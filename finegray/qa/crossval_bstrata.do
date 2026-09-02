* crossval_bstrata.do - cross-validation of bstrata() against crrSC::crrs
* Package: finegray
*
* crrs() is the reference implementation of Zhou, Latouche, Rocha & Fine (2011),
* "Competing risks regression for stratified data", Biometrics 67(2):661-670 --
* the paper bstrata() implements.  It is independent code (R, its own optimizer,
* its own IPCW construction), so agreement is evidence about the ESTIMATOR and
* not about this package's internals.
*
* THE TWO MAPPINGS.  crrs always stratifies the baseline on `strata'; its
* `ctype' argument decides only how the censoring distribution G is estimated,
* which in finegray is the separate strata() axis:
*
*   ctype = 1   G within strata   ==   finegray, bstrata(v) strata(v)
*   ctype = 2   G pooled          ==   finegray, bstrata(v)
*
* Both mappings are checked, because getting them backwards is exactly the
* confusion the help file's three-strata table exists to prevent -- and a build
* that quietly routed bstrata() into the censoring strata would agree with
* ctype = 1 and disagree with ctype = 2.
*
* WHAT IS COMPARED, AND WHAT IS NOT.
*   coefficients   both ctypes, tightly (1e-5): the estimating equation is the
*                  same object in both implementations.  This is the oracle of
*                  this suite -- it establishes equality, and it is the only
*                  comparison here that does.
*   variance       ctype = 1 ONLY, and since 2026-08-26 it is a REAL ORACLE, not a
*                  proximity check.  Zhou et al. (2011) sec. 4.1 defines the
*                  regularly-stratified variance as Sigma_rk = E{(eta_ki +
*                  psi_ki)^2} summed over strata -- Fine & Gray (1999) eq. 7-8
*                  within stratum, INCLUDING the psi term for having estimated
*                  G -- and crrs assembles exactly that under ctype = 1 by
*                  running cmprsk's unmodified per-stratum crrvv and summing
*                  (R/crrs.r -> crrvvs()).  finegray computes the same object in
*                  one scan with a stratum index when asked for it:
*                      finegray ..., bstrata(v) strata(v) nuisance
*                  so the two are the same estimator computed twice, by
*                  independent code, and are gated at VTOL.
*                    MEASURED 2026-08-26 across the three fixtures: 8.1e-09,
*                    2.1e-08, 3.1e-08 relative.  Optimizer tolerance.
*                  The eta-only (fixed-weight, no `nuisance') arm is still
*                  compared at STOL, but only as a DRIFT ALARM between two
*                  documentedly different variance contracts.  Its measured gap
*                  IS the psi term and the suite prints both numbers side by
*                  side: 1.1e-03/2.3e-03/2.5e-03 on these fixtures, matching
*                  "psi moves the se by" to the digit.  So a future fixture
*                  where psi matters more widens the eta-only gap without any
*                  defect existing -- which is exactly why the eta+psi arm, not
*                  that one, is the gate.
*                  ctype = 2 SEs are not compared at all: in the paper ctype is
*                  also an asymptotic-regime declaration, and ctype = 2 carries
*                  the highly-stratified (many small strata) variance -- a
*                  different derivation reached by a different C routine,
*                  crrvvh -- which finegray does not implement and does not
*                  claim to.  finegray's own bstrata()-without-strata() cell is
*                  a stratified baseline with a POOLED Ghat, which crrs has no
*                  counterpart for at all; it is validated by simulation in
*                  validation_bstrata_recovery.do, not here.
*                  The Stata side uses noadjust so that the finite-sample
*                  N/(N-1) factor -- StataCorp's stcrreg contract, not crrs's --
*                  is out of the comparison.
*   baseline       NOT COMPARED: crrs returns no baseline in either regime.
*                  That is the half validation_bstrata_recovery.do covers, by
*                  simulation against a closed-form truth.

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"

* Run-unique scratch directory.  A fixed one lets an old R CSV survive a failed
* Rscript call and satisfy the later file-exists check, which would turn "R did
* not run" into "R agreed".
tempfile _cv_anchor
local datadir "`_cv_anchor'_dir"
capture mkdir "`datadir'"

capture log close _all
log using "`qadir'/crossval_bstrata.log", replace text name(_cvbs)

capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

* Agreement tolerances.  Measured on these fixtures 2026-08-25, across all six
* fixture x ctype comparisons: coefficients agree to 4.4e-9 - 3.6e-8 (both
* optimizers solve the same score equation to their own tolerance), regime-1
* standard errors to 1.1e-3 - 2.5e-3 relative -- which is how far apart Zhou's
* eta+psi variance and finegray's eta-only fixed-weight sandwich happen to land
* on these fixtures, NOT two routes to one number (see the header).  Each run
* prints its own measured worst case below, so the slack is visible rather than
* assumed.  The gates are roughly three and one orders looser respectively, and
* both are far tighter than any difference a wrong stratum axis produces
* (measured: >1e-1).
local BTOL = 1e-5
local STOL = 0.02
* VTOL gates the 2026-08-26 VARIANCE ORACLE: finegray's `nuisance bstrata(v)
* strata(v)' against crrs ctype=1.  These are the same estimator computed twice
* -- Zhou (2011) sec. 4.1's Sigma_rk = E{(eta_ki + psi_ki)^2} summed over
* strata, which crrs assembles as per-stratum crrvv() calls (crrvvs) and
* finegray as one scan with a stratum index -- so the gate is a real agreement
* tolerance, not a proximity alarm.  Each run prints its own measured worst
* case, so the slack is visible rather than assumed.  Measured 2026-08-26:
* 8.1e-09 / 2.1e-08 / 3.1e-08, so the gate is ~1.5 orders looser than the worst
* observed and still ~5 orders tighter than the omitted-psi gap it must catch.
local VTOL = 1e-6

* -----------------------------------------------------------------------------
* FIXTURES
* -----------------------------------------------------------------------------
* Each has a genuinely stratum-specific cause-1 baseline and a shared beta.
*   K2      two strata, continuous times (no ties)
*   K4      four strata, continuous times -- more strata, thinner risk sets
*   TIES    three strata, times rounded to a coarse grid so most event times
*           carry several events; the Breslow tie convention is the one place
*           two implementations most easily part company
capture program drop _cvbs_gen
program define _cvbs_gen
    version 16.0
    syntax , n(integer) k(integer) seed(integer) [ties(integer 0)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte strata = 1 + mod(_n - 1, `k')
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double lam1 = (0.20 + 0.25 * strata) * exp(0.50 * x1 - 0.70 * x2)
    gen double lam2 = 0.45 * exp(0.20 * x1)
    gen double tt1 = -ln(runiform()) / lam1
    gen double tt2 = -ln(runiform()) / lam2
    gen double tc  = rexponential(2.2)
    gen double time = min(tt1, tt2, tc)
    gen byte status = cond(time == tt1, 1, cond(time == tt2, 2, 0))
    if `ties' {
        quietly replace time = ceil(time * 4) / 4
        quietly replace time = 0.25 if time <= 0
    }
    gen byte anyevent = status != 0
    quietly stset time, failure(anyevent == 1) id(id)
end

* -----------------------------------------------------------------------------
* EXPORT THE FIXTURES FOR R
* -----------------------------------------------------------------------------
local r_available = 1
capture noisily {
    tempfile stack
    local first = 1
    foreach spec in "K2 800 2 4242 0" "K4 800 4 4243 0" "TIES 800 3 4244 1" {
        local nm : word 1 of `spec'
        local nn : word 2 of `spec'
        local kk : word 3 of `spec'
        local sd : word 4 of `spec'
        local ti : word 5 of `spec'
        _cvbs_gen, n(`nn') k(`kk') seed(`sd') ties(`ti')
        gen str8 dataset = "`nm'"
        keep id time status strata dataset x1 x2
        if `first' {
            quietly save `"`stack'"', replace
            local first = 0
        }
        else {
            quietly append using `"`stack'"'
            quietly save `"`stack'"', replace
        }
    }
    use `"`stack'"', clear
    export delimited using "`datadir'/bstrata_r_input.csv", replace
}
if _rc {
    display as error "  SKIP: could not export fixtures for the R cross-check"
    local r_available = 0
}

if `r_available' {
    capture erase "`datadir'/bstrata_r_output.csv"
    capture noisily {
        shell Rscript "`qadir'/crossval_bstrata_r.R" ///
            "`datadir'/bstrata_r_input.csv" ///
            "`datadir'/bstrata_r_output.csv"
    }
    capture confirm file "`datadir'/bstrata_r_output.csv"
    if _rc {
        display as error "  SKIP: Rscript failed or crrSC is unavailable"
        local r_available = 0
    }
}

* -----------------------------------------------------------------------------
* COMPARE
* -----------------------------------------------------------------------------
if `r_available' {
    * Pull the R results into locals before refitting anything: the comparison
    * loop below replaces the data in memory, and reading R's numbers out of a
    * dataset that is no longer loaded is how a crossval ends up comparing a
    * fixture with itself.
    preserve
    import delimited using "`datadir'/bstrata_r_output.csv", clear varnames(1)
    local nr = _N
    forvalues i = 1/`nr' {
        local ds  = dataset[`i']
        local ct  = ctype[`i']
        local qt  = quantity[`i']
        local vr  = variable[`i']
        local rv`ds'_`ct'_`qt'_`vr' = value[`i']
        local seen_`ds'_`ct' = 1
    }
    restore

    foreach spec in "K2 800 2 4242 0" "K4 800 4 4243 0" "TIES 800 3 4244 1" {
        local nm : word 1 of `spec'
        local nn : word 2 of `spec'
        local kk : word 3 of `spec'
        local sd : word 4 of `spec'
        local ti : word 5 of `spec'

        forvalues ct = 1/2 {
            local ++test_count
            if "`seen_`nm'_`ct''" != "1" {
                display as error "  SKIP: `nm' ctype=`ct' -- no R result"
                local ++skip_count
                continue
            }
            capture noisily {
                _cvbs_gen, n(`nn') k(`kk') seed(`sd') ties(`ti')
                if `ct' == 1 {
                    quietly finegray x1 x2, compete(status) cause(1) nolog ///
                        bstrata(strata) strata(strata) noadjust
                }
                else {
                    quietly finegray x1 x2, compete(status) cause(1) nolog ///
                        bstrata(strata) noadjust
                }
                assert e(converged) == 1
                assert e(k_bstrata) == `kk'
                assert `rv`nm'_`ct'_converged__all' == 1

                local worstb = 0
                local worsts = 0
                foreach v in x1 x2 {
                    local rb = `rv`nm'_`ct'_coef_`v''
                    assert !missing(_b[`v'], `rb')
                    local db = abs(_b[`v'] - `rb')
                    if `db' > `worstb' local worstb = `db'
                    assert `db' < `BTOL'

                    * Regime-1 SE PROXIMITY only -- a drift alarm between two
                    * documented-different variance estimators (crrs: Zhou
                    * eta+psi; finegray without nuisance: eta-only fixed
                    * weight), not a variance oracle.  See the header.  The
                    * eta+psi arm below is the oracle.
                    if `ct' == 1 {
                        local rs = `rv`nm'_`ct'_se_`v''
                        assert !missing(_se[`v'], `rs')
                        assert `rs' > 0
                        local ds_ = abs(_se[`v'] - `rs') / `rs'
                        if `ds_' > `worsts' local worsts = `ds_'
                        assert `ds_' < `STOL'
                    }
                }

                * ---- THE VARIANCE ORACLE (2026-08-26) ----------------------------
                * ctype = 1 is crrs's per-stratum crrvvs(): cmprsk's unmodified
                * FG eq. (7)-(8) variance run on each stratum's rows with that
                * stratum's own Ghat, summed over strata.  Since 2026-08-26
                * finegray computes the same object -- `nuisance bstrata(v)
                * strata(v)' -- so this is a genuine two-implementation
                * comparison of the SAME estimator, not a proximity check, and
                * it is gated tightly.
                *
                * It also measures how big the psi term IS on this fixture
                * (worstpsi), so a run where the eta-only proximity above looks
                * good only because psi is negligible is visible rather than
                * flattering.
                if `ct' == 1 {
                    local worstpsi = 0
                    local worstv = 0
                    tempname SE_ETA
                    matrix `SE_ETA' = J(1, 2, .)
                    local jj = 0
                    foreach v in x1 x2 {
                        local ++jj
                        matrix `SE_ETA'[1, `jj'] = _se[`v']
                    }
                    quietly finegray x1 x2, compete(status) cause(1) nolog ///
                        bstrata(strata) strata(strata) nuisance noadjust
                    assert e(converged) == 1
                    assert `"`e(vce_meat)'"' == "nuisance_adjusted"
                    local jj = 0
                    foreach v in x1 x2 {
                        local ++jj
                        local rs = `rv`nm'_`ct'_se_`v''
                        assert !missing(_se[`v'], `rs')
                        assert _se[`v'] > 0
                        local dv = abs(_se[`v'] - `rs') / `rs'
                        if `dv' > `worstv' local worstv = `dv'
                        local dp = abs(_se[`v'] - `SE_ETA'[1, `jj']) / _se[`v']
                        if `dp' > `worstpsi' local worstpsi = `dp'
                        assert `dv' < `VTOL'
                    }
                }
            }
            if _rc == 0 {
                if `ct' == 1 {
                    display as result ///
                        "  PASS: `nm' ctype=1 (bstrata+strata) b within `=string(`worstb',"%8.2e")'; eta+psi se vs crrs `=string(`worstv',"%8.2e")' (same estimator); eta-only proximity `=string(`worsts',"%8.2e")'; psi moves the se by `=string(`worstpsi',"%8.2e")'"
                }
                else {
                    display as result ///
                        "  PASS: `nm' ctype=2 (bstrata only) b within `=string(`worstb',"%8.2e")'"
                }
                local ++pass_count
            }
            else {
                display as error "  FAIL: `nm' ctype=`ct' vs crrs (rc=`=_rc')"
                local ++fail_count
            }
        }
    }

    * ------------------------------------------------------------------
    * The mapping is not symmetric: ctype=1 and ctype=2 are different fits,
    * so a build that ignored one of the two axes would still match ONE of
    * them.  Assert the two Stata fits actually differ.
    * ------------------------------------------------------------------
    local ++test_count
    capture noisily {
        _cvbs_gen, n(800) k(4) seed(4243)
        quietly finegray x1 x2, compete(status) cause(1) nolog ///
            bstrata(strata) strata(strata) noadjust
        matrix _cv1 = e(b)
        quietly finegray x1 x2, compete(status) cause(1) nolog ///
            bstrata(strata) noadjust
        matrix _cv2 = e(b)
        mata: st_numscalar("_cvd", ///
            max(abs(st_matrix("_cv1") - st_matrix("_cv2"))))
        assert _cvd > `BTOL'
    }
    if _rc == 0 {
        display as result "  PASS: the two ctype mappings are distinct fits"
        local ++pass_count
    }
    else {
        display as error "  FAIL: ctype mappings are not distinguishable (rc=`=_rc')"
        local ++fail_count
    }
}
else {
    * Six mapping comparisons plus the distinctness check.
    forvalues i = 1/7 {
        local ++test_count
        local ++skip_count
    }
}

* -----------------------------------------------------------------------------
* SUMMARY
* -----------------------------------------------------------------------------
display as text _newline ///
    "RESULT: crossval_bstrata tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

capture erase "`datadir'/bstrata_r_input.csv"
capture erase "`datadir'/bstrata_r_output.csv"
capture rmdir "`datadir'"

* A SKIPPED EXTERNAL ORACLE IS AN UNRUN CHECK, NOT A PASS (2026-09-02).
* This suite used to print "RESULT: PASS (n passed, k skipped)" and exit 0 when
* the R oracle was unavailable, so a machine with no R -- or with the package
* missing -- produced a green cross-validation that had cross-validated nothing.
* run_all.do already treats skip > 0 as a lane failure by parsing the machine
* sentinel, but a human reading the suite's own last line was told PASS.  Match
* crossval_pweight.do: skip > 0 exits 1, and the word PASS is not printed on a
* skipped run.  The machine sentinel above is unchanged -- run_all.do parses
* `RESULT: <name> tests=.. pass=.. fail=.. skip=..' and nothing else.
if `fail_count' > 0 {
    display as error "RESULT: FAIL (`fail_count' of `test_count' tests failed)"
    log close _cvbs
    exit 1
}
else if `skip_count' > 0 {
    display as error ///
        "RESULT: NOT RUN (`pass_count' checked, `skip_count' SKIPPED -- the R oracle was unavailable)"
    display as error "Install the missing R dependency and re-run; a skipped oracle is not evidence."
    log close _cvbs
    exit 1
}
display as result "RESULT: PASS (all `test_count' tests passed)"
log close _cvbs

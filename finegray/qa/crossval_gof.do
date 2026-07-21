* crossval_gof.do
* Parity of finegray_gof against the Li/Scheike/Zhang (2015) R oracle.
*
* ORACLE.  crossval_gof_r.R computes all four test processes from the paper's
* formulae (pp. 201-202, 215-216).  It calls no goodness-of-fit library: it is
* anchored to cmprsk::crr through fg_sandwich_hand() (0 ulp on the variance,
* asserted per fixture) and to exact algebraic identities that need no external
* library at all.  crskdiag, the authors' own R package, is deliberately NOT the
* oracle -- its censoring KM is identically 1 on continuous data and its default
* minor_included = 1 feeds a defective nuisance term into the test process
* itself.  See the R script's header.
*
* WHY THIS IS A CROSSVAL AND NOT A test_.  It needs R.  qa/data/ is gitignored
* (regenerable oracle output, never committed), so the fixtures are rebuilt here
* before use.  The R-free part of the contract -- refusals, returns, seed and
* nsim semantics, the p-value floor, state hygiene -- lives in
* test_finegray_gof.do and runs in the quick lane without R.
*
* WHAT IS COMPARED, AND WHY NOT THE P-VALUE.  p depends on the RNG stream, so R
* and Stata cannot agree on it to any useful tolerance; comparing p would only
* assert that both drew nsim normals.  The deterministic quantities are compared
* instead:
*
*   obs   the observed process on the grid
*   wv    V0' W for a FIXED, non-random V0_i = sin(i)
*   sup   the observed suprema, through the finegray_gof COMMAND
*
* wv is the multiplier bootstrap with the randomness removed: it contracts the
* full n x ngrid influence matrix with a vector both languages build exactly.
* THIS IS THE LOAD-BEARING CHECK.  obs is BLIND to terms 2 and 3 -- they cancel
* across subjects in the aggregate but not pointwise -- so a port missing either
* term reproduces obs to 1e-15 and is caught only by wv.  Mutation-tested:
* dropping term 3 leaves obs at 8.3e-15 and moves wv to 3.5e-02.
*
* THE STANDARDIZING FACTOR {I^-1_jj}^(1/2) IS CHECKED ONLY BY sup_overall.  It
* multiplies observed and simulated suprema identically in every per-covariate
* test, so it CANCELS there: reading e(V) (a sandwich) instead of the inverse
* information, or dropping the square root the paper's Appendix drops, leaves
* all per-covariate results untouched and is wrong only in the overall
* statistic, where the covariates are summed before the supremum is taken.
* X3 exists for that one number.
*
* TWO TOLERANCES, AND THEY ARE NOT INTERCHANGEABLE.
*   1e-10        process parity (X1/X2), where Stata is handed R's beta.
*   amplified    command parity (X3), where Stata REFITS to its OWN beta.  The
*                supremum is a smooth function of beta, so the band is derived
*                from the observed beta difference per fixture rather than
*                fixed at a constant -- it stays tight (1e-8) where the betas
*                agree tightly and only widens where they do not.
*
* FINEGRAY DOES NOT AGREE WITH crr TO 1e-9, AND ASSERTING THAT WOULD BE WRONG.
* The first version of X4 asserted beta parity against crr and failed on gof-b
* at 9e-06.  Scoring both betas through the oracle's own estimating equation --
* colSums(eta), which is 0 at the solution and belongs to neither package --
* showed why:
*
*     fixture   |U| at crr's beta   |U| at finegray's beta
*     gof-a           1.3e-09              4.1e-14
*     gof-b           5.4e-05              1.9e-11
*     gof-c           3.1e-08              9.3e-15
*
* finegray solves the estimating equation four to six orders of magnitude
* BETTER than crr does.  crr is the under-converged side, most visibly on
* gof-b, whose last cause-1 event lands at the very end of follow-up where
* Ghat(t-) has fallen to 0.02 and the IPCW weights are amplified ~50x.  So X4
* asserts the SCORE, not agreement with crr: holding the package to crr's beta
* would pin it to a looser reference and would break whenever crr's convergence
* happened to be poor on a future fixture.
clear all
set varabbrev off
version 16.0

* MANDATORY, and the reason an early version of this check read 1e-7 instead of
* 1e-10.  `import delimited' picks the NARROWEST type that holds each column,
* which for a decimal column is `float' -- 7 significant digits.  The R fixtures
* carry 15.  Without this the fixture is silently truncated on the way in and
* every downstream comparison inherits a ~1e-7 floor that looks exactly like a
* porting error.
set type double

capture log close _all
log using "crossval_gof.log", replace name(_xvgof)

local qadir "`c(pwd)'"
local pkg_dir = subinstr("`qadir'", "/qa", "", 1)
local datadir "`qadir'/data"
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "crossval_gof.do must run from finegray/qa"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* ---- fail-closed oracle regeneration -------------------------------------
*
* Stata's `shell' does not surface the child's exit status in _rc, so the oracle
* output is erased BEFORE R runs and R's real exit code is captured through a
* sentinel.  A broken or missing Rscript therefore cannot let a stale data/
* cache from a prior run be consumed as if it were fresh.
*
* The sentinel is written with `&& echo 0 || echo 1' rather than `echo $?'.
* `$?' is sh/bash syntax: fish exposes the status as $status, and in csh a bare
* `$?' is a syntax error, so on a Stata whose `shell' honours a non-sh login
* shell the sentinel would come back empty.  That fails CLOSED (empty -> missing
* -> `missing != 0' is true -> exit 9), so it could never produce a false green
* -- but it would report "R oracle generation failed" on a machine where R is
* fine, sending the next reader after the wrong bug.  `&&'/`||' are portable
* across sh, bash, fish and csh.  Redirect ONLY the echo, never the whole group.
foreach f in gof-a gof-b gof-c {
    capture erase "`datadir'/`f'.csv"
}
foreach f in reference_gof reference_proc reference_beta {
    capture erase "`datadir'/`f'.csv"
}
tempfile rcsent
shell Rscript "`qadir'/crossval_gof_r.R" && echo 0 > "`rcsent'" || echo 1 > "`rcsent'"
capture confirm file "`rcsent'"
if _rc {
    display as error "R oracle wrapper produced no exit-status sentinel"
    exit 9
}
tempname _shrc
file open `_shrc' using "`rcsent'", read text
file read `_shrc' _rc_line
file close `_shrc'
local _rexit = real(trim("`_rc_line'"))
if `_rexit' != 0 {
    display as error "R oracle generation failed (sentinel `=trim(`"`_rc_line'"')')"
    display as error "no stale oracle is consumed: data/ was erased before R ran"
    display as error "an EMPTY sentinel means the shell could not run the wrapper,"
    display as error "not that R failed; check Rscript is on PATH first"
    exit 9
}
foreach _o in reference_gof reference_proc reference_beta gof-a gof-b gof-c {
    capture confirm file "`datadir'/`_o'.csv"
    if _rc {
        display as error "MISSING ORACLE: `datadir'/`_o'.csv"
        exit 601
    }
}

run "`pkg_dir'/_finegray_mata.ado"

* ===========================================================================
* X1/X2  process parity at R's beta
* ===========================================================================
mata:
void _xg_emit(string scalar fx, string scalar tst, real scalar term,
              real colvector obs, real colvector wv)
{
    external real scalar _xg_fh
    real scalar k
    for (k = 1; k <= rows(obs); k++)
        fput(_xg_fh, sprintf("%s,%s,%g,%g,%21.17e,%21.17e",
             fx, tst, term, k, obs[k], wv[k]))
}

void _xg_run(string scalar fx)
{
    struct _finegray_gof_sc scalar sc
    real colvector t, ct, d, one, zero, G, beta, obs, grid, V0, lp, scl
    real matrix Z, Wp, Uall
    real scalar n, j, escale, edge

    t  = st_data(., "t")
    ct = st_data(., "cause")
    d  = st_data(., "_delta")
    Z  = st_data(., ("Z1", "Z2"))
    n  = rows(t)
    one  = J(n, 1, 1)
    zero = J(n, 1, 0)
    beta = st_matrix("BETA")

    G  = _finegray_km_censor(t, d, 0, ct, one, zero, 1)
    sc = _finegray_gof_scaffold(t, d, 1, 0, ct, Z, beta, G, one, zero, one)

    /* The free self-check: W_i(edge) must be 0 for every subject in every test.
       Printed relative to the scale of eta so it reads as a relative error.
       This identity needs no oracle at all and catches C(.), Omega^-1, tie
       multiplicity and term 3 simultaneously. */
    escale = max(abs(sc.eta))
    V0 = sin(1::n)

    Uall = J(sc.m, 2, 0)
    for (j = 1; j <= 2; j++) {
        Wp = _finegray_gof_prop(sc, j, obs)
        Uall[., j] = obs
        edge = _finegray_gof_edge(Wp) / escale
        printf("  %s prop j=%g  edge |W(tmax)| = %10.3e\n", fx, j, edge)
        if (edge > 1e-8) {
            errprintf("%s prop j=%g violates W_i(tmax)==0\n", fx, j)
            exit(9)
        }
        _xg_emit(fx, "prop", j, obs, (V0' * Wp)')
    }
    scl = _finegray_gof_scale(sc)
    _xg_emit(fx, "overall", 0, max(rowsum(abs(Uall :* scl'))), 0)
    st_numscalar("_xg_overall", max(rowsum(abs(Uall :* scl'))))

    for (j = 1; j <= 2; j++) {
        Wp = _finegray_gof_xaxis(sc, Z[., j], grid, obs)
        edge = _finegray_gof_edge(Wp) / escale
        printf("  %s func j=%g  edge |W(xmax)| = %10.3e   ngrid=%g\n",
               fx, j, edge, rows(grid))
        if (edge > 1e-8) {
            errprintf("%s func j=%g violates W_i(xmax)==0\n", fx, j)
            exit(9)
        }
        _xg_emit(fx, "func", j, obs, (V0' * Wp)')
    }
    lp = Z * beta
    Wp = _finegray_gof_xaxis(sc, lp, grid, obs)
    edge = _finegray_gof_edge(Wp) / escale
    printf("  %s link      edge |W(xmax)| = %10.3e   ngrid=%g\n",
           fx, edge, rows(grid))
    if (edge > 1e-8) {
        errprintf("%s link violates W_i(xmax)==0\n", fx)
        exit(9)
    }
    _xg_emit(fx, "link", 0, obs, (V0' * Wp)')
}
end

tempfile mineraw
capture erase "`mineraw'"
mata: _xg_fh = fopen("`mineraw'", "w")
mata: fput(_xg_fh, "fixture,test,term,k,obs,wv")

local ++test_count
capture noisily {
    foreach f in gof-a gof-b gof-c {
        import delimited using "`datadir'/reference_beta.csv", clear ///
            varnames(1) case(preserve)
        quietly keep if fixture == "`f'"
        assert _N == 2
        local b1 = beta[1]
        local b2 = beta[2]
        matrix BETA = (`b1' \ `b2')

        import delimited using "`datadir'/`f'.csv", clear varnames(1) case(preserve)
        gen long _r = _n
        * V0 indexes ROWS, so Stata must sort exactly as the R oracle does:
        * order(X) stable, i.e. (t, original row).  A different tie order
        * silently permutes V0 and the check fails for a reason that is not
        * the port.
        sort t _r
        gen byte _delta = cause != 0
        mata: _xg_run("`f'")
    }
    mata: fclose(_xg_fh)
}
if _rc {
    display as error "  FAIL: X1 process build failed (rc=`=_rc')"
    local ++fail_count
}
else {
    local ++pass_count
    display as result "  PASS: X1 all 18 processes built; W_i(edge)==0 identity holds"
}

* ---- comparison -----------------------------------------------------------
local ++test_count
capture noisily {
    import delimited using "`mineraw'", clear varnames(1) case(preserve)
    rename (obs wv) (m_obs m_wv)
    tempfile mine
    quietly save "`mine'"

    * The overall statistic lives in reference_gof.csv (one row per fixture),
    * not in the per-grid-point reference_proc.csv, so it is folded in here.
    import delimited using "`datadir'/reference_gof.csv", clear ///
        varnames(1) case(preserve)
    quietly keep if test == "prop_overall"
    quietly replace test = "overall"
    quietly keep fixture test term sup
    rename sup obs
    gen int k = 1
    gen double wv = 0
    tempfile ovr
    quietly save "`ovr'"

    import delimited using "`datadir'/reference_proc.csv", clear ///
        varnames(1) case(preserve)
    quietly keep fixture test term k obs wv
    quietly append using "`ovr'"
    quietly merge 1:1 fixture test term k using "`mine'"
    quietly count if _merge != 3
    if r(N) > 0 {
        display as error "grid mismatch: `r(N)' unmatched rows -- the Mata and R"
        display as error "grids differ in length or values, which is a defect,"
        display as error "not a tolerance issue"
        tabulate fixture test if _merge != 3
        exit 9
    }

    * Relative to the SCALE of each process, not element-wise: a process passes
    * through zero, so element-relative error there measures nothing.
    bysort fixture test term: egen double _sc_o = max(abs(obs))
    bysort fixture test term: egen double _sc_w = max(abs(wv))
    gen double _e_o = abs(m_obs - obs) / max(_sc_o, 1e-300)
    gen double _e_w = abs(m_wv  - wv ) / max(_sc_w, 1e-300)

    * THE DEGENERATE BINARY-COVARIATE CASE.
    *
    * Z2 is 0/1, so its functional-form grid is {0,1} and BOTH points are pinned
    * to zero: x=1 by the f == 1 identity, x=0 by the score equation together
    * with colSums(dM) == 0 exactly.  The process is identically zero in both
    * languages and what remains is floating-point residue, so a RELATIVE
    * comparison there divides two different piles of noise and is meaningless.
    *
    * It is not dropped silently.  The claim actually being made is "both
    * implementations agree this process is degenerate", so that is what gets
    * asserted: its scale must be negligible beside a real process on the same
    * fixture.  finegray_gof REFUSES funcform() on a <= 2-level covariate
    * (exit 198) precisely because a p-value here is decided by residue.
    gen byte _degen = (test == "func" & term == 2)
    quietly summarize _sc_o if _degen
    local degen_scale = r(max)
    quietly summarize _sc_o if test == "func" & term == 1
    local real_scale = r(max)
    display as text _newline "degenerate binary funcform: scale " ///
        %10.3e `degen_scale' " vs real funcform scale " %10.3e `real_scale'
    if `degen_scale' > 1e-4 * `real_scale' {
        display as error "the 2-level funcform process is NOT degenerate -- the"
        display as error "premise of the refusal gate is wrong, not the tolerance"
        exit 9
    }
    quietly replace _e_o = 0 if _degen
    quietly replace _e_w = 0 if _degen

    display as text _newline "per-process agreement (max relative deviation):"
    display as text "  fixture   test  term   ngrid        obs          wv"
    levelsof fixture, local(fl) clean
    foreach ff of local fl {
        levelsof test if fixture == "`ff'", local(tl) clean
        foreach tt of local tl {
            levelsof term if fixture == "`ff'" & test == "`tt'", local(jl) clean
            foreach jj of local jl {
                quietly summarize _e_o if fixture == "`ff'" & test == "`tt'" ///
                    & term == `jj'
                local eo = r(max)
                local ng = r(N)
                quietly summarize _e_w if fixture == "`ff'" & test == "`tt'" ///
                    & term == `jj'
                local ew = r(max)
                display as text "  " %-8s "`ff'" "  " %-5s "`tt'" "  " ///
                    %4.0f `jj' "   " %5.0f `ng' "  " %10.3e `eo' "  " %10.3e `ew'
            }
        }
    }

    quietly summarize _e_o
    local worst_o = r(max)
    quietly summarize _e_w
    local worst_w = r(max)
    display as text _newline "worst obs = " %10.3e `worst_o' ///
        "   worst wv = " %10.3e `worst_w'

    if `worst_o' > 1e-10 | `worst_w' > 1e-10 {
        display as error "Mata does not reproduce the R oracle to 1e-10"
        exit 9
    }
}
if _rc {
    display as error "  FAIL: X2 (rc=`=_rc')"
    local ++fail_count
}
else {
    local ++pass_count
    display as result "  PASS: X2 obs and wv reproduce the R oracle to 1e-10 on 3 fixtures"
}

* ===========================================================================
* X3  COMMAND-level parity: the suprema finegray_gof actually reports
*
* X1/X2 exercise the Mata directly at R's beta.  This asserts that the shipped
* COMMAND -- its own fit, its own scaffolding, its own display and returns --
* delivers those same numbers, so a defect in the ado layer between Mata and
* r() cannot hide behind a green process check.
*
* The band is DERIVED, not fixed: the oracle's suprema are evaluated at crr's
* beta and Stata's at its own, so the two differ by however much the betas do,
* amplified by the local sensitivity of the supremum.  A constant 1e-6 would be
* simultaneously too tight on gof-b (where crr under-converges) and far too
* loose on gof-a and gof-c (where the betas agree to 1e-10) -- i.e. it would
* let a real regression through on two of the three fixtures.  The bound is
* max(1e-8, 50 * beta_reldif), which keeps the assertion tight exactly where
* the inputs are tight.
*
* sup_overall is the ONLY check on the {I^-1_jj}^(1/2) standardizing factor.
* ===========================================================================
tempname sbfh
file open `sbfh' using "`datadir'/stata_beta.csv", write replace
file write `sbfh' "fixture,b1,b2" _newline

foreach f in gof-a gof-b gof-c {
    local ++test_count
    capture noisily {
        import delimited using "`datadir'/reference_gof.csv", clear ///
            varnames(1) case(preserve)
        quietly keep if fixture == "`f'"
        quietly levelsof sup if test == "prop" & term == 1, local(r_p1) clean
        quietly levelsof sup if test == "prop" & term == 2, local(r_p2) clean
        quietly levelsof sup if test == "prop_overall", local(r_ov) clean
        quietly levelsof sup if test == "func" & term == 1, local(r_f1) clean
        quietly levelsof sup if test == "link", local(r_lk) clean

        import delimited using "`datadir'/reference_beta.csv", clear ///
            varnames(1) case(preserve)
        quietly keep if fixture == "`f'"
        local rb1 = beta[1]
        local rb2 = beta[2]

        import delimited using "`datadir'/`f'.csv", clear varnames(1) case(preserve)
        gen long _fgid = _n
        quietly stset t, failure(cause) id(_fgid)
        quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

        file write `sbfh' "`f'," (string(_b[Z1], "%21.17e")) "," ///
            (string(_b[Z2], "%21.17e")) _newline

        local db = max(abs(_b[Z1] - `rb1') / max(abs(`rb1'), 1e-300), ///
                       abs(_b[Z2] - `rb2') / max(abs(`rb2'), 1e-300))
        local bound = max(1e-8, 50 * `db')

        quietly finegray_gof, proportional funcform(Z1) link seed(4242) nsim(200)
        matrix Gm = r(gof)
        local s_p1 = Gm[1,1]
        local s_p2 = Gm[2,1]
        local s_ov = r(sup_overall)
        matrix Fm = r(funcform)
        local s_f1 = Fm[1,1]
        local s_lk = r(sup_link)

        display as text _newline "`f'  command vs oracle" ///
            "  (beta reldif " %10.3e `db' " -> bound " %10.3e `bound' ")"
        foreach q in p1 p2 ov f1 lk {
            local d_`q' = abs(`s_`q'' - `r_`q'') / max(abs(`r_`q''), 1e-300)
            display as text "    " %-4s "`q'" "  stata " %14.8f `s_`q'' ///
                "  R " %14.8f `r_`q'' "  reldif " %10.3e `d_`q''
            if `d_`q'' > `bound' {
                display as error "    `f' `q': command supremum differs from the"
                display as error "    oracle by more than the beta difference explains"
                exit 9
            }
        }
        * called out explicitly: this is the standardizing-factor check, the
        * one number in the whole suite that sees {I^-1_jj}^(1/2)
        if `d_ov' > `bound' {
            display as error "    sup_overall mismatch -- {I^-1_jj}^(1/2) is wrong"
            exit 9
        }
    }
    if _rc {
        display as error "  FAIL: X3-`f' (rc=`=_rc')"
        local ++fail_count
    }
    else {
        local ++pass_count
        display as result "  PASS: X3-`f' finegray_gof suprema match the oracle (incl. sup_overall)"
    }
}
file close `sbfh'

* ===========================================================================
* X4  finegray's beta SOLVES the oracle's estimating equation
*
* Not "finegray agrees with crr" -- see the header.  crr is the under-converged
* side on these fixtures, so parity with it is the wrong assertion and fails on
* correct code.  What must be true is that whatever beta finegray reports makes
* the oracle's score colSums(eta) vanish; fg_sandwich_hand() computes eta from
* the formulae and calls no estimation library, so this is independent of both
* implementations.
*
* crr's score is printed alongside, unasserted, so the contrast stays visible
* to the next reader instead of being rediscovered from scratch.
* ===========================================================================
local ++test_count
capture noisily {
    shell Rscript "`qadir'/crossval_gof_r.R" && echo 0 > "`rcsent'" || echo 1 > "`rcsent'"
    tempname _shrc2
    file open `_shrc2' using "`rcsent'", read text
    file read `_shrc2' _rc_line2
    file close `_shrc2'
    if real(trim("`_rc_line2'")) != 0 {
        display as error "R scoring pass failed (sentinel `=trim(`"`_rc_line2'"')')"
        exit 9
    }
    capture confirm file "`datadir'/reference_score.csv"
    if _rc {
        display as error "scoring pass produced no reference_score.csv -- it is"
        display as error "gated on data/stata_beta.csv, which X3 writes"
        exit 601
    }

    import delimited using "`datadir'/reference_score.csv", clear ///
        varnames(1) case(preserve)
    assert _N == 3
    forvalues i = 1/`=_N' {
        local fx = fixture[`i']
        local us = u_stata[`i']
        local uc = u_crr[`i']
        local gm = gmin[`i']
        display as text "  " %-7s "`fx'" "  |U| stata " %10.3e `us' ///
            "   crr " %10.3e `uc' "   min Ghat " %8.4f `gm'
        if `us' > 1e-9 {
            display as error "  `fx': finegray's beta does not solve the oracle's"
            display as error "  score equation (|U| = `us' relative to the eta scale)"
            exit 9
        }
    }
}
if _rc {
    display as error "  FAIL: X4 (rc=`=_rc')"
    local ++fail_count
}
else {
    local ++pass_count
    display as result "  PASS: X4 finegray's beta solves the oracle score equation to 1e-9"
}

**# Summary
* The runner parses this sentinel and requires tests == pass + fail with
* fail == 0.  A suite that exits 0 without it is counted as a FAILURE, not a
* pass -- emitting it is part of the lane contract, not decoration.
display as text _newline ///
    "RESULT: crossval_gof tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _xvgof
    exit 9
}
capture log close _xvgof

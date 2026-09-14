* crossval_finegray_zzf_ties.do - TIED delayed-entry data: Stata engine vs the
* published ZZF weight (independent R construction) and survival::finegray
* Package: finegray
*
* WHAT THIS ANSWERS.  crossval_finegray_zzf.do settles, on continuous data,
* that finegray computes the stabilized Zhang-Zhang-Fine Weight-1 estimator.
* Continuous data cannot see a tie convention: entry, event and censoring times
* never coincide there.  The 2026-09-13 clarity audit showed that the engine's
* censoring product-limit used a tie ordering under which G(t-)H(t-) is NOT
* b(t)/S(t-), so on data with event/censoring collisions the converged
* coefficient was 1.2e-3 off the published weight while every continuous
* crossval and the R-only tie gate stayed green (1.3.4).  This file compares
* the LIVE Stata engine on fixtures built out of exact ties -- every collision
* class asserted present before anything is fitted -- against the canonical
* b_g/S_g construction in R, which involves no product limit and no tie
* choice, and against survival::finegray on the pooled fixtures.
*
* FIXTURES (all times on a quarter-unit grid, so they round-trip through CSV
* exactly and collide in bulk):
*   grid_pooled     one weight cell, entries at 0 and on the grid
*   grid_strata     two groups with different censoring and entry; fitted
*                   pooled AND with strata(g) truncstrata(g) (ZZF eq. 6)
*   gap_pooled      grid_pooled with a lone early entrant censored before the
*                   next entry: a gap in the pooled sample
*   gap_strata      grid_strata with the same gap inside group 0 while group 1
*                   bridges it: a gap in one censoring stratum
*
* COMPARED, per fixture and spec: both coefficients (1e-8, the two-Newton-
* solver floor argued in test_finegray_ties.do), e(ll) on the one-cell specs
* (the oracle's weights are the engine's ratios there), the largest retained
* weight (1e-10), and the whole Breslow baseline on the oracle's event grid.
* survival::finegray is compared on the gap-free pooled fixtures only: across
* a gap it produces NaN weights (see the R side), so it is not a reference
* there -- which is itself worth knowing when reading an R comparison.
*
* ORACLE.  crossval_finegray_zzf_ties_r.R, which sources zzf_weights /
* coxph_on_our_weights from the frozen crossval_finegray_zzf_r.R.  Routine
* runs restore the checked frozen reference (qa/oracles/finegray_zzf_ties);
* FG_ORACLE_REFRESH=1 regenerates it.  Fail-closed generation as in
* crossval_finegray_zzf.do: the outputs are erased before R runs and R's real
* exit status comes back through a sentinel file.

clear all
set more off
set varabbrev off
version 16.0
set type double

local test_count = 0
local pass_count = 0
local fail_count = 0

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

capture log close _all
log using "`qadir'/crossval_finegray_zzf_ties.log", replace text name(_xv_ties)

capture ado uninstall finegray
net install finegray, from("`pkgroot'") replace

tempfile _anchor
local datadir "`_anchor'_dir"
capture mkdir "`datadir'"
local fin  "`datadir'/zzf_ties_input.csv"
local fout "`datadir'/zzf_ties_output.csv"
local fbl  "`datadir'/zzf_ties_baseline.csv"

* -----------------------------------------------------------------------------
* Fixture builders
* -----------------------------------------------------------------------------
* Quarter-grid delayed-entry competing-risks data.  Entry L is 0 for about
* 40% and otherwise on {0.25, ..., 2}; exit X = L + a grid step in
* {0.25, ..., 4}; status 1 (cause), 2 (competing), 0 (censored) with
* group-specific censoring.  Nothing here is a known-truth model -- the point
* is the collisions, and the comparison is implementation against
* implementation on the SAME data.
capture program drop _xvt_grid
program define _xvt_grid
    version 16.0
    syntax , n(integer) seed(integer) [groups]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte g = 0
    if "`groups'" != "" quietly replace g = _n > `n' / 2
    gen double z1 = rnormal()
    gen double z2 = runiform() < 0.5
    gen double L = cond(runiform() < 0.4, 0, ceil(8 * runiform()) / 4)
    quietly replace L = L + 0.5 if g == 1
    gen double X = L + ceil(16 * runiform()) / 4
    gen double u = runiform()
    gen byte status = cond(u < 0.55, 1, cond(u < 0.80, 2, 0))
    quietly replace status = 0 if g == 1 & u >= 0.65
    drop u
end

* Move subject 1 into a lone early observation window: enters at 0.25, is
* censored at 0.5, and no other member of its sample (its group for the
* stratified fixture, everyone for the pooled one) is under observation then.
capture program drop _xvt_gap
program define _xvt_gap
    version 16.0
    syntax , [stratum]
    quietly replace g = 0 in 1
    quietly replace L = 0.25 in 1
    quietly replace X = 0.5 in 1
    quietly replace status = 0 in 1
    if "`stratum'" != "" {
        quietly replace L = max(L, 1) if g == 0 & id != 1
    }
    else {
        quietly replace L = max(L, 1) if id != 1
    }
    quietly replace X = L + ceil(16 * runiform()) / 4 if X <= L
end

* Collision classes, asserted present so that a tie gate cannot pass on data
* without ties.  Returns the six counts.
capture program drop _xvt_collisions
program define _xvt_collisions, rclass
    version 16.0
    tempvar tag anyc anye anyk anyl tagl
    quietly bysort X: egen byte `anyc' = max(status == 0)
    quietly bysort X: egen byte `anye' = max(status == 1)
    quietly bysort X: egen byte `anyk' = max(status == 2)
    quietly bysort X: gen byte `tag' = _n == 1
    quietly count if `tag' & `anyc' & `anye'
    return scalar censor_cause = r(N)
    quietly count if `tag' & `anye' & `anyk'
    return scalar cause_competing = r(N)
    quietly count if `tag' & `anyc' & `anye' & `anyk'
    return scalar three_way = r(N)
    * entry times that coincide with an exit of each kind
    tempvar isL
    quietly levelsof L if L > 0, local(_lt)
    local n_lc = 0
    local n_le = 0
    local n_lk = 0
    foreach u of local _lt {
        quietly count if X == `u' & status == 0
        if r(N) > 0 local ++n_lc
        quietly count if X == `u' & status == 1
        if r(N) > 0 local ++n_le
        quietly count if X == `u' & status == 2
        if r(N) > 0 local ++n_lk
    }
    return scalar entry_censor = `n_lc'
    return scalar entry_cause = `n_le'
    return scalar entry_competing = `n_lk'
end

* -----------------------------------------------------------------------------
* Build and export the fixtures
* -----------------------------------------------------------------------------
tempfile stack
local first = 1
local fixtures "grid_pooled grid_strata gap_pooled gap_strata"
foreach fx of local fixtures {
    if "`fx'" == "grid_pooled" _xvt_grid, n(600) seed(20260913)
    if "`fx'" == "grid_strata" _xvt_grid, n(800) seed(20260914) groups
    if "`fx'" == "gap_pooled" {
        _xvt_grid, n(600) seed(20260915)
        _xvt_gap
    }
    if "`fx'" == "gap_strata" {
        _xvt_grid, n(800) seed(20260916) groups
        _xvt_gap, stratum
    }
    assert L < X
    _xvt_collisions
    display as text "  `fx': collisions censor/cause=`r(censor_cause)' cause/competing=`r(cause_competing)' " ///
        "three-way=`r(three_way)' entry/cause=`r(entry_cause)' entry/competing=`r(entry_competing)' " ///
        "entry/censor=`r(entry_censor)'"
    local ++test_count
    if r(censor_cause) > 0 & r(cause_competing) > 0 & r(three_way) > 0 & ///
       r(entry_cause) > 0 & r(entry_competing) > 0 & r(entry_censor) > 0 {
        local ++pass_count
        display as result "  PASS: `fx' collides in every class"
    }
    else {
        local ++fail_count
        display as error "  FAIL: `fx' is missing a collision class -- the fixture cannot test it"
    }
    gen str12 fixture = "`fx'"
    keep fixture id g L X status z1 z2
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
sort fixture id
export delimited fixture id g L X status z1 z2 using "`fin'", replace

* -----------------------------------------------------------------------------
* Oracle, fail-closed (see crossval_finegray_zzf.do for the sentinel rationale)
* -----------------------------------------------------------------------------
capture erase "`fout'"
capture erase "`fbl'"
tempfile rcsent
shell Rscript "`qadir'/crossval_finegray_zzf_ties_r.R" "`fin'" "`fout'" "`fbl'" && echo 0 > "`rcsent'" || echo 1 > "`rcsent'"
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
    display as error "no stale oracle is consumed: the outputs were erased before R ran"
    exit 9
}
capture confirm file "`fout'"
if _rc {
    display as error "R oracle produced no output file"
    exit 9
}
capture confirm file "`fbl'"
if _rc {
    display as error "R oracle produced no baseline file"
    exit 9
}

* Pull the oracle into locals before any refit replaces the data in memory.
preserve
import delimited using "`fout'", clear varnames(1) case(preserve)
quietly count
if r(N) == 0 {
    display as error "R oracle output is empty"
    exit 9
}
forvalues i = 1/`=_N' {
    local _fx = fixture[`i']
    local _sp = spec[`i']
    local _qt = quantity[`i']
    local _vr = variable[`i']
    local o_`_fx'_`_sp'_`_qt'_`_vr' = value[`i']
}
restore

* -----------------------------------------------------------------------------
* Compare
* -----------------------------------------------------------------------------
local tol_coef = 1e-8
local tol_ll   = 1e-10
local tol_wt   = 1e-10
local tol_bh   = 1e-7

foreach fx of local fixtures {
    quietly use `"`stack'"', clear
    quietly keep if fixture == "`fx'"
    sort id
    gen byte anyev = status != 0
    quietly stset X, failure(anyev) id(id) enter(time L)
    local specs "pooled"
    quietly count if g == 1
    if r(N) > 0 local specs "pooled strata"
    foreach sp of local specs {
        local wopts ""
        if "`sp'" == "strata" local wopts "strata(g) truncstrata(g)"
        capture noisily finegray z1 z2, compete(status) cause(1) `wopts' basehaz noadjust nolog
        local fit_rc = _rc
        if `fit_rc' == 0 & e(converged) != 1 local fit_rc = 430
        local ++test_count
        if `fit_rc' {
            local ++fail_count
            display as error "  FAIL: `fx'/`sp' -- finegray rc `fit_rc'"
            continue
        }
        local d1 = reldif(_b[z1], `o_`fx'_`sp'_b_z1')
        local d2 = reldif(_b[z2], `o_`fx'_`sp'_b_z2')
        local dmax = max(`d1', `d2')
        display as text "  `fx'/`sp': engine b = " %18.12f _b[z1] " " %18.12f _b[z2] ///
            "  oracle b = " %18.12f `o_`fx'_`sp'_b_z1' " " %18.12f `o_`fx'_`sp'_b_z2' ///
            "  max reldif " %9.2e `dmax'
        if `dmax' < `tol_coef' {
            local ++pass_count
            display as result "  PASS: `fx'/`sp' coefficients match the published b/S weight"
        }
        else {
            local ++fail_count
            display as error "  FAIL: `fx'/`sp' coefficients differ from the published weight (reldif `dmax')"
        }

        * the largest retained weight the engine consulted
        local ++test_count
        local dw = reldif(e(max_lt_weight), `o_`fx'_`sp'_mw_a')
        display as text "      max retained weight: engine " %14.10f e(max_lt_weight) ///
            "  oracle " %14.10f `o_`fx'_`sp'_mw_a' "  reldif " %9.2e `dw'
        if `dw' < `tol_wt' {
            local ++pass_count
        }
        else {
            local ++fail_count
            display as error "  FAIL: `fx'/`sp' largest retained weight differs (reldif `dw')"
        }

        * e(ll) on the one-cell specs, where the oracle's weights are the engine's ratios
        if "`sp'" == "pooled" {
            local ++test_count
            local dll = reldif(e(ll), `o_`fx'_`sp'_ll_a')
            display as text "      e(ll) " %16.10f e(ll) "  oracle " %16.10f `o_`fx'_`sp'_ll_a' "  reldif " %9.2e `dll'
            if `dll' < `tol_ll' {
                local ++pass_count
            }
            else {
                local ++fail_count
                display as error "  FAIL: `fx'/`sp' e(ll) differs from the oracle (reldif `dll')"
            }
            * reference software on the same target.  Not across a gap:
            * survival::finegray's product-limit collapses there and it hands
            * coxph NaN weights, which coxph drops without a word (1918 of
            * 2518 expanded rows on gap_pooled), so its coefficient is not a
            * reference for anything.  The oracle reports the NaN count; a
            * fixture with any is reported, not compared, and a gap-free
            * fixture must have none for the comparison to mean something.
            local ++test_count
            local ds = max(reldif(_b[z1], `o_`fx'_`sp'_bs_z1'), ///
                           reldif(_b[z2], `o_`fx'_`sp'_bs_z2'))
            local sn = `o_`fx'_`sp'_sn_a'
            if `sn' > 0 {
                display as text "      survival::finegray + coxph: `sn' NaN weights across the gap; its coefficient " ///
                    "(max reldif " %9.2e `ds' ") is reported, not compared"
                if strpos("`fx'", "gap") == 1 {
                    local ++pass_count
                }
                else {
                    local ++fail_count
                    display as error "  FAIL: `fx'/`sp' has no gap but survival::finegray produced NaN weights"
                }
            }
            else {
                display as text "      survival::finegray + coxph: max reldif " %9.2e `ds'
                if `ds' < `tol_coef' {
                    local ++pass_count
                    display as result "  PASS: `fx'/`sp' matches survival::finegray"
                }
                else {
                    local ++fail_count
                    display as error "  FAIL: `fx'/`sp' differs from survival::finegray (reldif `ds')"
                }
            }
        }

        * the whole baseline on the oracle's event grid
        local ++test_count
        tempname _BH
        matrix `_BH' = e(basehaz)
        local _bhrows = rowsof(`_BH')
        preserve
        import delimited using "`fbl'", clear varnames(1) case(preserve)
        quietly keep if fixture == "`fx'" & spec == "`sp'"
        quietly count
        local _lamrows = r(N)
        if `_bhrows' != `_lamrows' {
            local ++fail_count
            display as error "  FAIL: `fx'/`sp' e(basehaz) has `_bhrows' rows, oracle `_lamrows'"
        }
        else {
            mata: _bhm = st_matrix("`_BH'"); _lamm = st_data(., ("time", "Lambda0"))
            mata: st_numscalar("_bh_dt", max(abs(_bhm[,1] :- _lamm[,1])))
            mata: st_numscalar("_bh_dl", max(abs(_bhm[,2] :- _lamm[,2]) :/ rowmax((abs(_lamm[,2]), J(rows(_lamm), 1, 1e-8)))))
            local _dt = scalar(_bh_dt)
            local _dl = scalar(_bh_dl)
            display as text "      basehaz: `_bhrows' points, max time diff " %9.2e `_dt' ", max rel Lambda0 diff " %9.2e `_dl'
            if `_dt' == 0 & `_dl' < `tol_bh' {
                local ++pass_count
            }
            else {
                local ++fail_count
                display as error "  FAIL: `fx'/`sp' baseline differs from the oracle"
            }
        }
        restore
    }
}

capture erase "`fin'"
capture erase "`fout'"
capture erase "`fbl'"
capture rmdir "`datadir'"

display as text _newline ///
    "RESULT: crossval_finegray_zzf_ties tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _xv_ties
    exit 1
}
display as result "ALL TESTS PASSED"
log close _xv_ties

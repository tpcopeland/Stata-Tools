* test_finegray_zzf.do - ZZF delayed-entry surface: options, contract, guards
* Package: finegray
*
* Covers the truncstrata() option and the combined-weight e() contract added for
* the stabilized Zhang-Zhang-Fine Weight-1 delayed-entry estimator.
*
* WHAT THIS FILE IS NOT.  It does not check that the estimator is CORRECT -- that
* is validation_finegray_zzf_recovery.do (known-truth recovery) and
* crossval_finegray_zzf.do (per-dataset agreement with the independent R oracle).
* This file checks the SURFACE: parsing, guards, the stored contract, and that
* postestimation rebuilds the same weight design it was fitted with.
*
* Run from finegray/qa:  stata-mp -b do test_finegray_zzf.do

clear all
set more off
set varabbrev off
version 16.0

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
log using "`qadir'/test_finegray_zzf.log", replace text name(_test_finegray_zzf)

capture ado uninstall finegray
net install finegray, from("`pkgroot'") replace

* ---------------------------------------------------------------------------
* Fixture: competing risks with group-dependent delayed entry.
* ---------------------------------------------------------------------------
program define _zzf_fix
    syntax , n(integer) seed(integer) [NOTRUNC]

    clear
    set seed `seed'
    quietly set obs `=`n' * 6'

    gen byte   z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen byte   g4 = ceil(runiform() * 4)
    gen double ez = exp(0.5 * z1 - 0.5 * z2)
    gen double p1 = 1 - (1 - 0.5)^ez

    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * z1 + 0.5 * z2))) if cause == 2
    gen double cens = min(rexponential(1 / 0.15), 6)

    if "`notrunc'" != "" gen double t0 = 0
    else                 gen double t0 = rexponential(1 / cond(z1 == 1, 1.6, 0.5))

    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0

    quietly drop if !(t0 < t)
    quietly keep in 1/`n'
    gen long id = _n
end

program define _zzf_ok
    args tag rc
    display as result "  PASS: `tag'"
end

* ===========================================================================
* 1. OPTION PARSING AND GUARDS
* ===========================================================================
display as text _newline "1. truncstrata() parsing and guards"

_zzf_fix, n(4000) seed(20260713)
quietly stset t, failure(anyev == 1) id(id) enter(time t0)

* Z1: truncstrata() accepted on delayed-entry data
local ++test_count
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
if !_rc {
    local ++pass_count
    display as result "  PASS: Z1 truncstrata() accepted under delayed entry"
}
else {
    local ++fail_count
    display as error "  FAIL: Z1 truncstrata() rejected (rc=`=_rc')"
}

* Z2: truncstrata() must be REJECTED with no delayed entry.  Pooling H over a
* single entry level is not wrong, it is meaningless -- and silently accepting
* the option would tell the user their entry strata were honoured when there is
* no entry to stratify.
local ++test_count
preserve
_zzf_fix, n(4000) seed(20260713) notrunc
quietly stset t, failure(anyev == 1) id(id)
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
local _rc_notrunc = _rc
restore
if `_rc_notrunc' == 198 {
    local ++pass_count
    display as result "  PASS: Z2 truncstrata() without delayed entry is r(198)"
}
else {
    local ++fail_count
    display as error "  FAIL: Z2 expected r(198), got rc=`_rc_notrunc'"
}

* Z3: missing values in truncstrata() are marked out, not silently grouped as a
* level of their own.
local ++test_count
quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture drop zmiss
quietly gen byte zmiss = z1
quietly replace zmiss = . in 1/50
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(zmiss)
local _n_miss = e(N)
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
local _n_full = e(N)
if `_n_miss' == `_n_full' - 50 {
    local ++pass_count
    display as result "  PASS: Z3 truncstrata() missings marked out (`_n_full' -> `_n_miss')"
}
else {
    local ++fail_count
    display as error "  FAIL: Z3 expected N = `=`_n_full' - 50', got `_n_miss'"
}

* Z4: a truncstrata() variable that varies within subject must be refused.
local ++test_count
preserve
quietly expand 2
quietly bysort id: gen byte rec = _n
quietly gen double t0b = cond(rec == 1, 0, t / 2)
quietly gen double tb  = cond(rec == 1, t / 2, t)
quietly gen byte   evb = cond(rec == 1, 0, anyev)
quietly gen byte   stb = cond(rec == 1, 0, status)
quietly gen byte   vary = cond(rec == 1, 0, 1)
quietly stset tb, failure(evb == 1) id(id) enter(time t0b) time0(t0b)
capture quietly finegray z1 z2, compete(stb) cause(1) truncstrata(vary)
local _rc_vary = _rc
restore
if `_rc_vary' != 0 {
    local ++pass_count
    display as result "  PASS: Z4 within-subject varying truncstrata() refused (rc=`_rc_vary')"
}
else {
    local ++fail_count
    display as error "  FAIL: Z4 varying truncstrata() was ACCEPTED"
}

* ===========================================================================
* 2. SUPPORT BOUNDARIES (hard failures; groups are never silently pooled)
* ===========================================================================
display as text _newline "2. support boundaries"

quietly stset t, failure(anyev == 1) id(id) enter(time t0)

* Z5: more than 100 observed joint weight strata is r(459)
local ++test_count
capture drop many
quietly gen int many = ceil(runiform() * 150)
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(many)
if _rc == 459 {
    local ++pass_count
    display as result "  PASS: Z5 >100 joint weight strata is r(459)"
}
else {
    local ++fail_count
    display as error "  FAIL: Z5 expected r(459), got rc=`=_rc'"
}

* Z6: a weight stratum with fewer than 20 subjects is r(459)
local ++test_count
capture drop few
quietly gen int few = ceil(runiform() * 40)
quietly replace few = 41 in 1/5
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(few)
if _rc == 459 {
    local ++pass_count
    display as result "  PASS: Z6 a <20-subject weight stratum is r(459)"
}
else {
    local ++fail_count
    display as error "  FAIL: Z6 expected r(459), got rc=`=_rc'"
}

* Z7: the limits are CROSS-CLASSIFIED.  strata() and truncstrata() each legal on
* their own can still exceed 100 jointly -- 4 x 40 = 160.  A check that looked at
* either option alone would pass this and then estimate weights on 160 groups.
local ++test_count
capture drop t40
quietly gen int t40 = ceil(runiform() * 40)
capture quietly finegray z1 z2, compete(status) cause(1) strata(g4) truncstrata(t40)
if _rc == 459 {
    local ++pass_count
    display as result "  PASS: Z7 cross-classified count enforces the 100 limit"
}
else {
    local ++fail_count
    display as error "  FAIL: Z7 expected r(459) on 4x40 joint groups, got rc=`=_rc'"
}

* Z8: the boundaries must NOT be imposed on the no-LT branch.  A right-censoring
* fit with many strata() levels is existing released behaviour; turning it into an
* error would be a silent breaking change (the no-LT path must stay bit-identical,
* and an error is not bit-identical).
local ++test_count
preserve
_zzf_fix, n(4000) seed(20260713) notrunc
quietly stset t, failure(anyev == 1) id(id)
capture drop many
quietly gen int many = ceil(runiform() * 150)
capture quietly finegray z1 z2, compete(status) cause(1) strata(many)
local _rc_nolt = _rc
restore
if `_rc_nolt' == 0 {
    local ++pass_count
    display as result "  PASS: Z8 no-LT branch keeps released many-strata behaviour"
}
else {
    local ++fail_count
    display as error "  FAIL: Z8 no-LT fit with 150 strata now errors (rc=`_rc_nolt')"
}

* ===========================================================================
* 3. THE STORED CONTRACT
* ===========================================================================
display as text _newline "3. e() combined-weight contract"

_zzf_fix, n(4000) seed(20260713)
quietly stset t, failure(anyev == 1) id(id) enter(time t0)
quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)

* Z9: every contract element exists on a ZZF fit
local ++test_count
local _missing ""
foreach s in N_weight_strata min_weight_prob max_lt_weight N_prob_warn N_weight_warn {
    if e(`s') >= . local _missing "`_missing' `s'"
}
if `"`e(lt_weight)'"' == "" local _missing "`_missing' lt_weight"
if `"`e(truncstrata)'"' == "" local _missing "`_missing' truncstrata"
if "`_missing'" == "" {
    local ++pass_count
    display as result "  PASS: Z9 full weight contract posted"
}
else {
    local ++fail_count
    display as error "  FAIL: Z9 missing from e():`_missing'"
}

* Z10: lt_weight names the weight ACTUALLY computed, on both branches
local ++test_count
local _lt_zzf `"`e(lt_weight)'"'
preserve
_zzf_fix, n(4000) seed(20260713) notrunc
quietly stset t, failure(anyev == 1) id(id)
quietly finegray z1 z2, compete(status) cause(1)
local _lt_rc `"`e(lt_weight)'"'
local _maxw_rc = e(max_lt_weight)
restore
if "`_lt_zzf'" == "zzf1_geskus" & "`_lt_rc'" == "right_censoring" {
    local ++pass_count
    display as result "  PASS: Z10 e(lt_weight) = zzf1_geskus / right_censoring"
}
else {
    local ++fail_count
    display as error "  FAIL: Z10 got `_lt_zzf' / `_lt_rc'"
}

* Z11: with no delayed entry H == 1, so A == G is nonincreasing and EVERY weight
* is <= 1.  This is a theoretical bound, not a tolerance: a max weight above 1 on
* the no-LT branch would mean the combined weight is not collapsing to G.
local ++test_count
if `_maxw_rc' <= 1 + 1e-12 & `_maxw_rc' > 0 {
    local ++pass_count
    display as result "  PASS: Z11 no-LT max weight = `_maxw_rc' (bound is 1)"
}
else {
    local ++fail_count
    display as error "  FAIL: Z11 no-LT max weight `_maxw_rc' exceeds the bound of 1"
}

* Z12: under left truncation H rises, so A need not be monotone and weights above
* 1 are legitimate.  If this were <= 1 the ZZF branch would not be doing anything.
local ++test_count
quietly stset t, failure(anyev == 1) id(id) enter(time t0)
quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
if e(max_lt_weight) > 1 {
    local ++pass_count
    display as result "  PASS: Z12 LT max weight = `=string(e(max_lt_weight), "%9.3f")' (> 1, as ZZF requires)"
}
else {
    local ++fail_count
    display as error "  FAIL: Z12 LT max weight `=e(max_lt_weight)' is <= 1 -- H is not acting"
}

* Z13: N_weight_strata counts OBSERVED JOINT groups, not the options' levels
local ++test_count
quietly finegray z1 z2, compete(status) cause(1) strata(g4) truncstrata(z1)
local _nj = e(N_weight_strata)
if `_nj' == 8 {
    local ++pass_count
    display as result "  PASS: Z13 N_weight_strata = 8 (4 censoring x 2 truncation)"
}
else {
    local ++fail_count
    display as error "  FAIL: Z13 expected 8 joint strata, got `_nj'"
}

* Z14: a clean fixture must raise NO sensitivity warnings.  A diagnostic that
* fires on healthy data is noise the user will learn to ignore.
local ++test_count
quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
if e(N_prob_warn) == 0 & e(N_weight_warn) == 0 & `"`e(weight_warn_strata)'"' == "" {
    local ++pass_count
    display as result "  PASS: Z14 clean fixture raises no weight warnings"
}
else {
    local ++fail_count
    display as error "  FAIL: Z14 spurious warning on clean data" ///
        " (prob=`=e(N_prob_warn)' wt=`=e(N_weight_warn)' strata=`e(weight_warn_strata)')"
}

* ===========================================================================
* 4. POSTESTIMATION REBUILDS THE SAME WEIGHT DESIGN
* ===========================================================================
display as text _newline "4. postestimation group reconstruction"

quietly stset t, failure(anyev == 1) id(id) enter(time t0)
quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)

* Z15: every postestimation path runs on a truncstrata() fit
local ++test_count
local _pe_fail ""
capture drop _xb
capture quietly predict double _xb, xb
if _rc local _pe_fail "`_pe_fail' predict(rc=`=_rc')"
capture quietly finegray_cif, at(z1=1 z2=0) attime(1 3 5) nograph
if _rc local _pe_fail "`_pe_fail' cif(rc=`=_rc')"
capture quietly finegray_phtest
if _rc local _pe_fail "`_pe_fail' phtest(rc=`=_rc')"
if "`_pe_fail'" == "" {
    local ++pass_count
    display as result "  PASS: Z15 predict / cif / phtest all run under truncstrata()"
}
else {
    local ++fail_count
    display as error "  FAIL: Z15 postestimation failed:`_pe_fail'"
}

* Z16: THE ONE THAT MATTERS.  truncstrata() variables define the weight design,
* so they are in the estimation-data signature.  Changing one after the fit must
* make the commands that REBUILD that design FAIL -- never silently rebuild a
* DIFFERENT design and report the result as if it came from the model that was fit.
*
* The rebuilding paths are finegray_cif and finegray_phtest.  `predict, xb` is
* deliberately NOT one of them: xb is a linear combination of the stored betas and
* is legitimately allowed on modified or out-of-sample data, exactly as after any
* other estimation command.  Asserting that xb also fails would be asserting a bug.
local ++test_count
quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
preserve
quietly replace z1 = 1 - z1 in 1/100
local _cif_rc = 0
local _pht_rc = 0
capture quietly finegray_cif, at(z1=1 z2=0) attime(1 3 5) nograph
local _cif_rc = _rc
capture quietly finegray_phtest
local _pht_rc = _rc
restore
if `_cif_rc' != 0 & `_pht_rc' != 0 {
    local ++pass_count
    display as result "  PASS: Z16 tampering with a truncstrata() var breaks cif (rc=`_cif_rc') and phtest (rc=`_pht_rc')"
}
else {
    local ++fail_count
    display as error "  FAIL: Z16 a changed weight design was silently accepted" ///
        " (cif rc=`_cif_rc', phtest rc=`_pht_rc')"
}

* Z17: the installed package can resolve the shared group helper
local ++test_count
capture which _finegray_weight_groups
if !_rc {
    local ++pass_count
    display as result "  PASS: Z17 _finegray_weight_groups.ado is installed"
}
else {
    local ++fail_count
    display as error "  FAIL: Z17 _finegray_weight_groups.ado not resolvable"
}

* ===========================================================================
display as text _newline "RESULT: test_finegray_zzf tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _test_finegray_zzf
    exit 9
}
display as result "ALL TESTS PASSED"
log close _test_finegray_zzf

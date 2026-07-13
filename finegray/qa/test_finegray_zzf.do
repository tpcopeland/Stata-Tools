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

* Z20: e(min_weight_prob) is the smallest CONSULTED A.  A is a product of two
* survival-type probabilities, so it must lie in (0, 1] -- a value above 1 would
* mean H is not a probability, and a value of 0 would mean the scan divided by
* zero and reported success anyway.
*
* (This assertion exists partly because the QA return-coverage checker reads
* literal e(name) references: Z9 reaches min_weight_prob through a loop variable,
* so it does not count. A stored result no test names by hand is a stored result
* nobody is really checking.)
local ++test_count
quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1)
local _mp = e(min_weight_prob)
if `_mp' > 0 & `_mp' <= 1 {
    local ++pass_count
    display as result "  PASS: Z20 e(min_weight_prob) = `=string(`_mp', "%9.3e")' is in (0, 1]"
}
else {
    local ++fail_count
    display as error "  FAIL: Z20 e(min_weight_prob) = `_mp' is not a probability"
}

* ===========================================================================
* 5. FG-M06 LIMITING CASES
*
* The "no competing events" and "no censored observations" guards are removed.
* Both are legitimate limiting cases, and refusing to fit a well-defined model is
* its own kind of wrong answer -- but only if the estimator actually degrades to
* the right thing, which is what these two tests assert.
* ===========================================================================
display as text _newline "5. FG-M06 limiting cases"

* Z18: NO COMPETING EVENTS.  With nobody to retain past their own exit, the
* subdistribution risk set IS the ordinary risk set, so finegray must collapse to
* Cox on this cause.  Asserting merely "it does not error" would be worthless --
* the point of removing the guard is that the answer is RIGHT, so compare to stcox.
local ++test_count
preserve
_zzf_fix, n(3000) seed(99) notrunc
quietly replace status = 0 if status == 2      // competing events -> censored
quietly replace anyev = status > 0
quietly stset t, failure(anyev == 1) id(id)
capture quietly finegray z1 z2, compete(status) cause(1)
local _rc_nc = _rc
if `_rc_nc' == 0 {
    local _fg_z1 = _b[z1]
    local _fg_z2 = _b[z2]
    quietly stcox z1 z2, nolog
    local _cx_z1 = _b[z1]
    local _cx_z2 = _b[z2]
    local _d1 = abs(`_fg_z1' - `_cx_z1')
    local _d2 = abs(`_fg_z2' - `_cx_z2')
    local _dmax = max(`_d1', `_d2')
}
restore
if `_rc_nc' == 0 & `_dmax' < 1e-7 {
    local ++pass_count
    display as result "  PASS: Z18 no competing events collapses to stcox (max diff `=string(`_dmax', "%9.2e")')"
}
else if `_rc_nc' != 0 {
    local ++fail_count
    display as error "  FAIL: Z18 no-competing-events fit refused (rc=`_rc_nc')"
}
else {
    local ++fail_count
    display as error "  FAIL: Z18 no competing events does NOT match stcox (max diff `_dmax')"
}

* Z19: NO CENSORING.  G(t) == 1 everywhere, so every weight is exactly 1.  The
* max-weight diagnostic is the check: if G were not collapsing to 1 the retained
* weights would not be either.
local ++test_count
preserve
_zzf_fix, n(3000) seed(99) notrunc
quietly replace status = cond(runiform() < 0.5, 1, 2)   // nobody censored
quietly replace anyev = 1
quietly stset t, failure(anyev == 1) id(id)
capture quietly finegray z1 z2, compete(status) cause(1)
local _rc_ncen = _rc
local _maxw_ncen = e(max_lt_weight)
local _ncens = e(N_cens)
restore
if `_rc_ncen' == 0 & abs(`_maxw_ncen' - 1) < 1e-12 {
    local ++pass_count
    display as result "  PASS: Z19 no censoring fits, e(N_cens)=`_ncens', all weights = 1"
}
else if `_rc_ncen' != 0 {
    local ++fail_count
    display as error "  FAIL: Z19 no-censoring fit refused (rc=`_rc_ncen')"
}
else {
    local ++fail_count
    display as error "  FAIL: Z19 no censoring but max weight is `_maxw_ncen', not 1"
}

* ===========================================================================
* 6. THE DELAYED-ENTRY BREAKING CHANGE (found by /reviewer, not by design)
* ===========================================================================
* Under delayed entry the weights are A = G*H and A is estimated per joint group,
* so 150 censoring strata are 150 weight strata EVEN WITH NO truncstrata().  The
* >100 boundary therefore fires on a model that fit in the released version.
*
* That asymmetry is defensible -- the no-LT branch must stay bit-identical, and an
* error is not bit-identical -- but it must be a WRITTEN CONTRACT, not a side
* effect of which local the support check happens to test.  Z8 already pins the
* rc=0 half (no-LT + strata(150) still fits); these pin the r(459) half.
display as text _newline "6. delayed-entry breaking change"

quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture drop many150
quietly gen int many150 = ceil(runiform() * 150)

* Z21: LT + >100 strata() levels and NO truncstrata() is r(459).
local ++test_count
capture quietly finegray z1 z2, compete(status) cause(1) strata(many150)
if _rc == 459 {
    local ++pass_count
    display as result "  PASS: Z21 LT + strata(150) with no truncstrata() is r(459)"
}
else {
    local ++fail_count
    display as error "  FAIL: Z21 expected r(459), got rc=`=_rc'"
}

* Z22: the refusal must name the option the user actually typed.  The first
* version of this message blamed a cross-classification with truncstrata() even
* when truncstrata() was never specified, sending the user to look for an option
* they had not used.  A guard that fires correctly but explains itself falsely is
* still a defect, so the message text is part of the contract.
local ++test_count
tempfile _z22log
quietly log using "`_z22log'", replace text name(_z22)
capture noisily finegray z1 z2, compete(status) cause(1) strata(many150)
quietly log close _z22

local _saw_strata = 0
local _saw_cross  = 0
tempname fh
file open `fh' using "`_z22log'", read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "levels of strata()") local _saw_strata = 1
    if strpos(`"`macval(line)'"', "cross-classified")   local _saw_cross  = 1
    file read `fh' line
}
file close `fh'

if `_saw_strata' & !`_saw_cross' {
    local ++pass_count
    display as result "  PASS: Z22 the r(459) message names strata(), not truncstrata()"
}
else {
    local ++fail_count
    display as error "  FAIL: Z22 message wrong (names strata=`_saw_strata', blames cross-classification=`_saw_cross')"
}
capture drop many150

* ===========================================================================
* 7. HARD POSITIVITY FAILURE (Gate Z3-functional)
* ===========================================================================
* A retained competing-event subject carries weight A_g(t-)/A_g(X_i-).  If its own
* stratum's A_g(X_i-) is ZERO the weight is undefined -- and Mata returns MISSING
* for x/0, not infinity, so before the guard existed this surfaced downstream as
* "the null log pseudo-likelihood is not finite" and r(430) "convergence not
* achieved": a message that blames the optimizer for a property of the data and
* names no stratum, leaving the user nothing to act on.
*
* FOUND, not designed: a benchmark lane (n = 8,000, 50 truncation strata) died on
* it, and 39 competing subjects had A(X_i-) exactly 0 -- bit-exact -- in a stratum
* holding 168 subjects.  That is EIGHT TIMES the >=20-subject support boundary,
* which is the point of this test: THE SIZE BOUNDARY DOES NOT PROTECT AGAINST
* THIS.  It bounds how many subjects a stratum holds, not whether A stays away
* from zero where the scan actually divides by it.  Z6 cannot stand in for Z23.
display as text _newline "7. hard positivity failure"

* Z23: A(X_i-) = 0 for a retained competing subject is a hard r(459), not r(430).
local ++test_count
preserve
clear
set seed 4242
quietly set obs 120
gen long id = _n
gen byte tgz = cond(_n <= 60, 1, 2)
gen byte z1 = mod(_n, 2)
gen double z2 = rnormal()
gen double t0 = runiform() * 0.2
gen double t  = t0 + 0.5 + runiform()
gen byte status = cond(runiform() < 0.5, 1, cond(runiform() < 0.6, 2, 0))

* The pathological subject: stratum 2, earliest entry, immediate competing exit.
* Every other subject in stratum 2 enters only AFTER that exit, so the stratum's
* entry-distribution product limit is still 0 there.
quietly replace t0     = 0.001 in 61
quietly replace t      = 0.010 in 61
quietly replace status = 2     in 61
quietly replace t0 = 0.30 + runiform() * 0.2 in 62/120
quietly replace t  = t0 + 0.5 + runiform()   in 62/120
gen byte anyev = status > 0

* Both strata hold 60 subjects -- 3x the >=20 boundary -- so Z6's guard is silent.
quietly bysort tgz: gen long _nper = _N
quietly summarize _nper, meanonly
local _minper = r(min)

quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(tgz)
local _rc_pos = _rc
restore

if `_rc_pos' == 459 & `_minper' >= 20 {
    local ++pass_count
    display as result "  PASS: Z23 A(X_i-)=0 is r(459) (stratum held `_minper' subjects, boundary is 20)"
}
else if `_rc_pos' == 430 {
    local ++fail_count
    display as error "  FAIL: Z23 REGRESSED to r(430) convergence-not-achieved -- the positivity guard is gone"
}
else {
    local ++fail_count
    display as error "  FAIL: Z23 expected r(459), got rc=`_rc_pos' (min stratum size `_minper')"
}

* ===========================================================================
* 8. REFIT-COMMAND FIDELITY (Gate Z3-functional: bootstrap/refit propagation)
* ===========================================================================
* e(refitcmd) is what finegray_cif's bootstrap re-issues on every resample.  A fit
* option dropped from it does NOT error there: the refit converges, its covariates
* still match the stored profile, so the replication is ACCEPTED -- and the
* bootstrap silently describes a DIFFERENT estimator than the point estimate it is
* wrapped around.  truncstrata() was in fact missing, so a bootstrapped ZZF fit was
* resampling the POOLED-weight estimator.
*
* This test does NOT look for truncstrata() by name.  It asserts the INVARIANT --
* running e(refitcmd) must reproduce e(b) -- so any fit option dropped from that
* list in future fails here without anyone remembering to add a case for it.
display as text _newline "8. refit-command fidelity"

* Z24: e(refitcmd) reproduces e(b) exactly.
local ++test_count
quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture drop cs
quietly gen byte cs = mod(id, 2)
quietly finegray z1 z2, compete(status) cause(1) strata(cs) truncstrata(z1)
tempname B_fit B_refit
matrix `B_fit' = e(b)
local _refit `"`e(refitcmd)'"'

capture quietly `_refit'
local _rc_refit = _rc
if `_rc_refit' == 0 matrix `B_refit' = e(b)

if `_rc_refit' != 0 {
    local ++fail_count
    display as error "  FAIL: Z24 e(refitcmd) would not run (rc=`_rc_refit'): `_refit'"
}
else {
    local _bad = 0
    local _maxd = 0
    local _p = colsof(`B_fit')
    forvalues j = 1/`_p' {
        local _d = abs(`B_fit'[1, `j'] - `B_refit'[1, `j'])
        if `_d' > `_maxd' local _maxd = `_d'
        if `_d' > 1e-12 local _bad = 1
    }
    if !`_bad' {
        local ++pass_count
        display as result "  PASS: Z24 e(refitcmd) reproduces e(b) (max diff `=string(`_maxd', "%9.2e")')"
    }
    else {
        local ++fail_count
        display as error "  FAIL: Z24 e(refitcmd) does NOT reproduce e(b) (max diff `=string(`_maxd', "%9.2e")')"
        display as error "        a fit option is missing from e(refitcmd): `_refit'"
    }
}
capture drop cs

* ===========================================================================
* 9. THE SOFT WARNINGS ACTUALLY FIRE (Gate Z3-functional: low-A / extreme weight)
* ===========================================================================
* Z14 only proves the warnings STAY SILENT on clean data.  That is the cheap half:
* a warning that can never fire also passes Z14.  This fires them.
*
* It also guards a collision the positivity guard (Z23) created and that had to be
* undone: the first version of that guard errored whenever A(X_i-) <= 1e-10 -- the
* SAME threshold as the low-A warning -- so the fit aborted before the warning
* could ever be reached, and the denominator half of the documented e() warning
* contract was unreachable dead code.  The two are now distinct:
*
*     A == 0            weight UNDEFINED (Mata: x/0 is missing)  -> hard r(459)
*     0 < A < 1e-10     weight defined but enormous              -> WARN, still fit
*
* Construction.  H_g is estimated from stratum g's subjects ALONE, so stratum 2
* holds nothing but a chain of 70 subjects that each enter while only ~3 are at
* risk.  H then accumulates 70 factors of ~2/3 and DECAYS to ~3.5e-13 instead of
* collapsing to 0.  A target subject exits from a competing event below the whole
* chain, so its denominator is that tiny value: the weight is ~1e12 -- extreme, but
* computable, which is exactly what the warnings are for.  (A first attempt put
* filler subjects in stratum 2 as well; they were at risk during the chain, which
* inflated every risk set and left H at 0.35.  H is per truncation stratum.)
display as text _newline "9. low-A and extreme-weight warnings"

* Z25: a defined-but-enormous weight WARNS and still fits (it must not error).
local ++test_count
preserve
clear
set seed 20260713
local K 70
quietly set obs `=`K' + 132'
gen long id = _n
gen byte tgw = 1
gen double t0 = .
gen double t  = .
gen byte status = .

* the spanner: keeps stratum 2's truncation risk set from ever emptying (an empty
* risk set makes a factor exactly 0, which is the Z23 hard failure, not a warning)
quietly replace tgw = 2    in 1
quietly replace t0 = 0.02  in 1
quietly replace t  = 1.00  in 1
quietly replace status = 0 in 1

* the target: competing exit BELOW the chain, so its A(X_i-) is the decayed value
quietly replace tgw = 2    in 2
quietly replace t0 = 0.001 in 2
quietly replace t  = 0.050 in 2
quietly replace status = 2 in 2

* the chain
forvalues k = 1/`K' {
    local r = 2 + `k'
    quietly replace tgw = 2 in `r'
    quietly replace t0 = 0.10 + 0.01 * `k'         in `r'
    quietly replace t  = 0.10 + 0.01 * `k' + 0.015 in `r'
    quietly replace status = 0 in `r'
}

* fillers supply the cause-1 events, and live in stratum 1 ONLY
forvalues r = `=`K' + 3'/`=`K' + 132' {
    quietly replace tgw = 1 in `r'
    quietly replace t0 = 0.01 * runiform() in `r'
    quietly replace t  = 0.6 + runiform()  in `r'
    quietly replace status = cond(runiform() < 0.6, 1, 2) in `r'
}

gen byte z1 = mod(id, 2)
gen double z2 = rnormal()
gen byte anyev = status > 0

quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture quietly finegray z1 z2, compete(status) cause(1) truncstrata(tgw)
local _rc_w  = _rc
local _mp    = e(min_weight_prob)
local _mw    = e(max_lt_weight)
local _npw   = e(N_prob_warn)
local _nww   = e(N_weight_warn)
local _ws    = "`e(weight_warn_strata)'"
restore

if `_rc_w' == 459 {
    local ++fail_count
    display as error "  FAIL: Z25 a defined-but-enormous weight was REFUSED as a positivity failure"
    display as error "        the hard guard is eating the warning; the two thresholds have collided again"
}
else if `_rc_w' != 0 {
    local ++fail_count
    display as error "  FAIL: Z25 fit failed (rc=`_rc_w'); expected a warning, not an error"
}
else if `_npw' > 0 & `_nww' > 0 & "`_ws'" != "" & `_mp' > 0 & `_mp' < 1e-10 {
    local ++pass_count
    display as result "  PASS: Z25 warnings fire (minA=`=string(`_mp', "%9.2e")', maxwt=`=string(`_mw', "%9.2e")', strata `_ws') and the fit still runs"
}
else {
    local ++fail_count
    display as error "  FAIL: Z25 warnings did not fire: nprobwarn=`_npw' nwtwarn=`_nww' minA=`_mp' strata='`_ws''"
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

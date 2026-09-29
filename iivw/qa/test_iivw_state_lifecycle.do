* test_iivw_state_lifecycle.do
* Session fingerprint for every public iivw command, and the lifecycle
* scenarios for stored results, cached weights and pooled shard files
* (DOTHIS 2026-09-28 Part 3.2 and 3.4, step 7).
* budget: 90
*
* Cells (each can fail; the audit finding each would have caught is named):
*   fingerprint  iivw, iivw_weight, iivw_balance, iivw_exogtest, iivw_fit,
*                iivw_diagnose, iivw_bspool on a success and an early-error
*                path, with a foreign active e() (regress, predict round
*                trip), a user matrix, scalar and global, and varabbrev on
*                planted; allow() names only what each help file documents
*   lifecycle    iivw_fit: fit A (categorical time) -> fit B (later support,
*                replace) -> restore A -> predict reproduces or refuses r(459)
*                (F03); iivw_weight: weights and fit A -> reweighted fit B ->
*                restore A -> predict reproduces or refuses r(459);
*                iivw_diagnose over stored roles after an unrelated fit B
*   pool         qa_lifecycle_pool on genuine iivw_fit bootstrap shards:
*                A+B, AB, AB+B, AB+A, AB+CD, a failed rerun of A, and x.dta
*                beside x.dta.dta (F05, F06); qa_counterfeit_twin kind(scale)
*                shards with equal b and N from different outcome data (F04)
* The stale scenario is declared accept: a worker that fails leaves the
* previous run's genuine shard file, which iivw_bspool cannot tell from a
* fresh one. Refusing stale artifacts is the job of demo/shard_driver.do
* (F07), pinned by test_iivw_codexaudit_2026_09_27_b.do C11, which launches
* child Stata processes and is not repeated here.
*
* Run from iivw/qa:  stata-mp -b do test_iivw_state_lifecycle.do

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_lifecycle.do"
do "`qa_dir'/_qa_hostile.do"

if `"`1'"' != "" {
    display as error "test_iivw_state_lifecycle takes no selector"
    exit 198
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""
tempfile _stub
global IVL_W "`_stub'_ivl"
capture mkdir "$IVL_W"

capture program drop _ivl_result
program define _ivl_result, rclass
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (rc=`rc')"
    return scalar pass = (`rc' == 0)
end

**# Fixtures

* The pinned FIPTIW panel of test_iivw_codexaudit_2026_09_27_a/b, before
* weighting; `w' also builds the weights.
capture program drop _ivl_panel
program define _ivl_panel
    version 16.0
    args w
    clear
    set rng mt64s
    set rngstream 1
    set seed 4713
    quietly set obs 150
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    quietly expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    quietly drop if runiform() > keeppr & j > 1
    sort id t
    if "`w'" != "" {
        quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
            wtype(fiptiw) maxfu(7) scores nolog
    }
end

* Globals: success paths allow the global category only so this check can
* name the exact set. Exempt: Stata's saved-result globals S_# and S_E_*
* (stset, ereturn post), GLIST (left by official glm itself), and the
* package's fit-token counter IIVW_FIT_SERIAL (a session counter in the
* package's namespace, undocumented; noted in qa/README.md).
capture mata: mata drop _ivl_globals() _ivl_exempt() _ivl_gdiff()
mata:
string matrix _ivl_globals()
{
    string colvector n
    string matrix G
    real scalar i
    n = st_dir("global", "macro", "*")
    G = J(rows(n), 2, "")
    for (i = 1; i <= rows(n); i++) G[i, .] = (n[i], st_global(n[i]))
    return(G)
}
real scalar _ivl_exempt(string scalar nm)
{
    return(regexm(nm, "^S_[0-9]+$") | substr(nm, 1, 4) == "S_E_" |
        nm == "GLIST" | nm == "IIVW_FIT_SERIAL")
}
string scalar _ivl_gdiff(string matrix A, string matrix B)
{
    string scalar out, nm
    real scalar i, j, hit
    out = ""
    for (i = 1; i <= rows(A); i++) {
        nm = A[i, 1]
        if (_ivl_exempt(nm)) continue
        hit = 0
        for (j = 1; j <= rows(B); j++) if (B[j, 1] == nm) hit = (B[j, 2] == A[i, 2]) + 1
        if (hit != 2) out = out + " " + nm
    }
    for (j = 1; j <= rows(B); j++) {
        nm = B[j, 1]
        if (!_ivl_exempt(nm) & !anyof(A[., 1], nm)) out = out + " +" + nm
    }
    return(out)
}
end
capture program drop _ivl_gcheck
program define _ivl_gcheck
    version 16.0
    mata: st_local("gd", _ivl_gdiff(_ivl_g0, _ivl_globals()))
    if `"`gd'"' != "" {
        display as error "globals changed outside the exempt set:`gd'"
        exit 9
    }
end

* Foreign model and user objects the commands must not touch.
capture program drop _ivl_plant
program define _ivl_plant
    version 16.0
    quietly regress y k1
    matrix M = (1, 2 \ 3, 4)
    scalar s1 = 7
    global IVL_USER "user value"
    set varabbrev on
end

* Intercept-only data, 80 subjects (shards).
capture program drop _ivl_flat
program define _ivl_flat
    version 16.0
    clear
    set seed 8080
    quietly set obs 80
    gen long id = _n
    * continuous, so genuine bootstrap draws do not tie (the pool helper
    * counts distinct rows)
    gen double y = 1 + rnormal()
end

**# Fingerprint sweep

**## FP-iivw
local ++test_count
capture noisily {
    _ivl_panel
    _ivl_plant
    qa_state_snapshot, tag(iv_ok) predict(xb)
    iivw
    qa_state_compare, tag(iv_ok) allow(r)
    _ivl_plant
    qa_state_snapshot, tag(iv_bad) predict(xb)
    capture iivw junk
    assert _rc == 101
    qa_state_compare, tag(iv_bad)
}
_ivl_result `=_rc' "FP-iivw leaves caller state intact (success + r(101))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FP-iivw"

**## FP-iivw_weight
* OPEN LEDGER, emptied in 4.3.2 (found 2026-09-28, present at 166dfd10 and
* on 4.3.1): iivw_weight left the caller's data marked stset (_dta[_dta] = st
* plus st_* characteristics) naming temporary variables it had dropped, so a
* later stdescribe or st command failed r(111). With the ledger empty the
* contract compare (r() and the documented _iivw_* columns and contract)
* must pass and the data must not be stset (red on 4.3.1); a second compare
* that also exempts characteristics and globals must pass too.
local iw_open ""
local ++test_count
capture noisily {
    _ivl_panel
    _ivl_plant
    qa_state_snapshot, tag(iw_ok) predict(xb) charns(_iivw_)
    mata: _ivl_g0 = _ivl_globals()
    iivw_weight, id(id) time(t) visit_cov(z1) maxfu(7) nolog
    confirm variable _iivw_weight
    * global: stset inside the visit fit leaves Stata's saved-result
    * globals S_#, exempt by name here as in every other block; _ivl_gcheck
    * below holds every other global to no change.
    capture noisily qa_state_compare, tag(iw_ok) allow(r data global) keep
    local crc = _rc
    qa_state_compare, tag(iw_ok) allow(r data char global)
    _ivl_gcheck
    local sig "clean"
    local dd : char _dta[_dta]
    capture stdescribe
    if "`dd'" == "st" & _rc == 111 local sig "stset-dangling"
    display as text "FP-iivw_weight side effect: [`sig'] compare rc `crc'; recorded open: [`iw_open']"
    if "`iw_open'" == "" assert `crc' == 0 & "`sig'" == "clean"
    else assert `crc' == 9 & "`sig'" == "`iw_open'"
    _ivl_plant
    qa_state_snapshot, tag(iw_bad) predict(xb) charns(_iivw_)
    capture iivw_weight, id(id) time(nosuchvar) nolog
    assert _rc == 111
    qa_state_compare, tag(iw_bad)
}
_ivl_result `=_rc' "FP-iivw_weight caller state: no stset side effect, nothing else changed (success + r(111))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FP-iivw_weight"

**## FP-iivw_balance
local ++test_count
capture noisily {
    _ivl_panel w
    _ivl_plant
    qa_state_snapshot, tag(ib_ok) predict(xb)
    mata: _ivl_g0 = _ivl_globals()
    iivw_balance k1 z1
    qa_state_compare, tag(ib_ok) allow(r global)
    _ivl_gcheck
    _ivl_plant
    qa_state_snapshot, tag(ib_bad) predict(xb)
    capture iivw_balance k1, component(bogus)
    assert _rc == 198
    qa_state_compare, tag(ib_bad)
}
_ivl_result `=_rc' "FP-iivw_balance leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FP-iivw_balance"

**## FP-iivw_exogtest
local ++test_count
capture noisily {
    _ivl_panel w
    _ivl_plant
    qa_state_snapshot, tag(ie_ok) predict(xb)
    mata: _ivl_g0 = _ivl_globals()
    iivw_exogtest y, id(id) time(t) maxfu(7) nolog
    * documented: generated lag variables remain (generate(), default
    * prefix _iivw_exog_)
    qa_state_compare, tag(ie_ok) allow(r data global)
    _ivl_gcheck
    confirm variable _iivw_exog_y_lag1
    _ivl_plant
    qa_state_snapshot, tag(ie_bad) predict(xb)
    capture iivw_exogtest y, id(id)
    assert _rc == 198
    qa_state_compare, tag(ie_bad)
}
_ivl_result `=_rc' "FP-iivw_exogtest leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FP-iivw_exogtest"

**## FP-iivw_fit
local ++test_count
capture noisily {
    _ivl_panel w
    _ivl_plant
    qa_state_snapshot, tag(if_ok) charns(_iivw_)
    mata: _ivl_g0 = _ivl_globals()
    iivw_fit y a z1, timespec(linear) replace
    * eclass: e() is the documented change; the fit records its design in
    * the _dta[_iivw_*] contract (charns)
    qa_state_compare, tag(if_ok) allow(e global)
    _ivl_gcheck
    _ivl_plant
    qa_state_snapshot, tag(if_bad) predict(xb) charns(_iivw_)
    capture iivw_fit y a z1, model(bogus) replace
    assert _rc == 198
    qa_state_compare, tag(if_bad)
}
_ivl_result `=_rc' "FP-iivw_fit leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FP-iivw_fit"

**## FP-iivw_diagnose
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store ivl_U
    quietly regress price mpg weight length
    estimates store ivl_W
    quietly regress price mpg weight length turn
    estimates store ivl_A
    gen double y = price
    gen double k1 = mpg
    * Stata's own estimates restore moves each _est_<name> esample column
    * to the end of the data; one warm call puts them there, so the
    * fingerprinted call can be held to an unchanged variable order.
    quietly iivw_diagnose mpg, unweighted(ivl_U) weighted(ivl_W) adjusted(ivl_A) force
    _ivl_plant
    qa_state_snapshot, tag(id_ok) predict(xb)
    iivw_diagnose mpg, unweighted(ivl_U) weighted(ivl_W) adjusted(ivl_A) force
    qa_state_compare, tag(id_ok) allow(r)
    _ivl_plant
    qa_state_snapshot, tag(id_bad) predict(xb)
    capture iivw_diagnose mpg, unweighted(ivl_U)
    assert _rc == 198
    qa_state_compare, tag(id_bad)
}
_ivl_result `=_rc' "FP-iivw_diagnose leaves caller state intact (success + r(198))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FP-iivw_diagnose"

**## FP-iivw_bspool
local ++test_count
capture noisily {
    _ivl_flat
    forvalues s = 1/2 {
        quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
            vce(bootstrap, reps(10) fixedweights seed(11)) rngstream(`s') ///
            saving("$IVL_W/fp_`s'", replace)
    }
    gen double k1 = mod(id, 3)
    quietly regress y k1
    matrix M = (1, 2 \ 3, 4)
    scalar s1 = 7
    global IVL_USER "user value"
    set varabbrev on
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
        vce(bootstrap, reps(10) fixedweights seed(11)) rngstream(2) ///
        saving("$IVL_W/fp_2", replace)
    qa_state_snapshot, tag(ip_ok)
    mata: _ivl_g0 = _ivl_globals()
    iivw_bspool using "$IVL_W/fp_1.dta $IVL_W/fp_2.dta", notable
    * eclass: the pooled result replaces e() (documented)
    qa_state_compare, tag(ip_ok) allow(e global)
    _ivl_gcheck
    assert e(iivw_bs_reps_completed) == 20
    quietly regress y k1
    qa_state_snapshot, tag(ip_bad) predict(xb)
    * the active estimates are a foreign regress: no iivw_fit anchor
    capture iivw_bspool using "$IVL_W/nosuchfile.dta"
    assert _rc == 301
    qa_state_compare, tag(ip_bad)
}
_ivl_result `=_rc' "FP-iivw_bspool leaves caller state intact (success + r(301))"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' FP-iivw_bspool"
set varabbrev off

**# Lifecycle

**## LC-fit (F03) categorical-time fit A, later-support fit B, restore A
local ++test_count
capture noisily {
    _ivl_panel w
    qa_lifecycle, fita(iivw_fit y a z1, timespec(categorical) vce(fixed) replace) ///
        fitb(iivw_fit y a z1 if t > 1, timespec(categorical) vce(fixed) replace) ///
        post(predict double lp1, mu; predict double lp2, xb) refusal(459)
}
_ivl_result `=_rc' "LC-fit F03: restored fit A predicts as before or refuses r(459)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-fit"

**## LC-weight reweighted fit B, restore A: stale weights reproduce or refuse
capture program drop _ivl_wfit
program define _ivl_wfit
    version 16.0
    args covs
    quietly iivw_weight, id(id) time(t) visit_cov(`covs') maxfu(7) nolog replace
    iivw_fit y a z1, timespec(linear) vce(fixed) replace
end
local ++test_count
capture noisily {
    _ivl_panel
    qa_lifecycle, fita(_ivl_wfit z1) fitb(_ivl_wfit z1 k1) ///
        post(predict double lw1, mu; iivw_balance k1 z1) refusal(459)
}
_ivl_result `=_rc' "LC-weight restored fit A after reweighting reproduces or refuses r(459)"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-weight"

**## LC-diagnose stored roles, unrelated fit B in between
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store ivl_U
    quietly regress price mpg weight length
    estimates store ivl_W
    quietly regress price mpg weight length turn
    estimates store ivl_A
    qa_lifecycle, fita(regress price mpg) fitb(regress trunk mpg if foreign) ///
        post(iivw_diagnose mpg, unweighted(ivl_U) weighted(ivl_W) adjusted(ivl_A) force)
}
_ivl_result `=_rc' "LC-diagnose diagnosis over stored roles unchanged by an unrelated later fit"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-diagnose"

**## LC-pool (F05, F06) genuine shards through every pooling scenario
* shard: label A-D -> RNG substream 1-4 of one seed, 10 draws; the anchor
* estimates are saved beside the draws as <file>.ster. fail: the worker dies
* before fitting and leaves whatever an earlier run wrote.
capture program drop _ivl_shard
program define _ivl_shard
    version 16.0
    args label file fail
    if "`fail'" != "" exit 498
    local s = strpos("ABCD", "`label'")
    _ivl_flat
    quietly iivw_fit y, unweighted id(id) timespec(none) citype(percentile) ///
        vce(bootstrap, reps(10) fixedweights seed(11)) rngstream(`s') ///
        saving("`file'", replace)
    quietly estimates save "`file'.ster", replace
end
* pool: anchor on the first input's estimates, pool, save the pooled result
* and its estimates.
capture program drop _ivl_pool
program define _ivl_pool
    version 16.0
    gettoken out 0 : 0
    local lst ""
    foreach f of local 0 {
        local lst "`lst' `f'"
    }
    local lst : list retokenize lst
    local first : word 1 of `lst'
    clear
    quietly estimates use "`first'.ster"
    iivw_bspool using "`lst'", notable saving("`out'", replace)
    quietly estimates save "`out'.ster", replace
end
local ++test_count
capture noisily {
    qa_lifecycle_pool, shard(_ivl_shard) pool(_ivl_pool) ///
        expect(A+B=accept AB=accept AB+B=refuse AB+A=refuse AB+CD=accept ///
        stale=accept neighbour=accept)
}
_ivl_result `=_rc' "LC-pool F05/F06: every pooling scenario has its declared outcome"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' LC-pool"

**## TW-pool (F04) equal b and N from different outcome data are not one analysis
local ++test_count
capture noisily {
    * distinct substreams of one seed, as genuine shards of one run would
    * have: identical streams would be refused for that reason alone
    foreach tw in a b {
        qa_counterfeit_twin, kind(scale) twin(`tw') clear
        local st = cond("`tw'" == "a", 1, 2)
        quietly iivw_fit y, unweighted id(id) timespec(none) ///
            vce(bootstrap, reps(20) fixedweights seed(11)) rngstream(`st') ///
            saving("$IVL_W/tw_`tw'", replace)
        local b_`tw' = _b[_cons]
        estimates store ivl_tw_`tw'
    }
    * the proxies agree: same intercept, same N
    assert !missing(`b_a', `b_b')
    assert reldif(`b_a', `b_b') < 1e-12
    estimates restore ivl_tw_a
    capture iivw_bspool using "$IVL_W/tw_a.dta $IVL_W/tw_b.dta", notable
    assert _rc == 459
}
_ivl_result `=_rc' "TW-pool F04: counterfeit-twin shards (y = 1 +- 1 vs 1 +- 10) are refused"
local pass_count = `pass_count' + r(pass)
if !r(pass) local failed "`failed' TW-pool"

**# Summary
capture estimates drop ivl_*
capture matrix drop M
capture scalar drop s1
capture shell rm -rf "$IVL_W"
macro drop IVL_W IVL_USER
local fail_count = `test_count' - `pass_count'
iivw_qa_summary, name(test_iivw_state_lifecycle) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests(`failed')

*! test_finegray_adversarial_v130 Version 1.0.0  2026/08/26
*! Adversarial coverage for the v1.3.0 features: mi, tvc()/tsplit(), bstrata()
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS SUITE EXISTS.
*
* test_finegray_mi.do, test_finegray_tvc.do and test_finegray_bstrata.do each
* probe one feature along the axis its author was thinking about: does the
* estimator agree with a reference, does the contract hold, does each fence
* refuse. All three are deep and all three are mutation-audited. What none of
* them asks is what happens when the features are pushed OFF that axis:
*
*  1. CROSS-FEATURE. mi x bstrata(), mi x tvc(), tvc() x strata() x cluster().
*     Each pair is legal and none is covered. A pooling rule that aligned
*     coefficients positionally, or a piecewise scan that quietly ignored a
*     censoring stratum, would be invisible to every single-feature suite.
*
*  2. HOSTILE FIXTURES. Value labels holding a space, a quote, `=' and `<';
*     32-character covariate names sharing a 30-character prefix; strata
*     numbered 3, 17, 40 and -5; a covariate whose imputed level support differs
*     between imputations. Each of these is a way for an identity to be lost at
*     rc 0 -- the class this package's audit history is made of.
*
*  3. NAMESPACE. The package writes _fg_<term> and _fg_entry into the caller's
*     data off mi, and into tempvars on mi. A user variable already holding one
*     of those names, and a stale column left by a PREVIOUS fit, are two
*     different ways for fit 2 to answer from fit 1's columns.
*
*  4. DEGENERATE MASS. A tsplit() interval carrying exactly one cause event; a
*     baseline stratum with three subjects; K = 20 strata over 200 subjects.
*     The question is never "does it converge" but "does it say what it rests
*     on".
*
* Every numeric claim below is checked against a route that is NOT the package:
* a hand-built (start, stop] episode Cox fit for the interval assignment, hand
* Rubin's rules for the pooled estimates, the finite-sample factor g/(g-1) read
* off the cluster count for the variance adjustment, and Mata arithmetic on
* e(basehaz) itself for the stratified baseline layout.

clear all
set more off
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_adversarial_v130.log", replace text name(_fgadv130)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgadv_result
program define _fgadv_result, rclass
    version 16.0
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* Count the occurrences of a phrase in a text file. The rendered output is a
* separate axis from e(): a fit that converges on one cause event is only
* honest if the reader is TOLD, and no ereturn assertion can see that.
capture program drop _fgadv_saw
program define _fgadv_saw, rclass
    version 16.0
    syntax using/, PHrase(string)
    tempname fh
    local n = 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`phrase'"') > 0 local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar saw = `n'
end

* Run one command with its console output captured, and report both the return
* code and how often a phrase appeared. The command arrives as a single
* compound-quoted token because every call carries commas of its own, which a
* `syntax' line would split on.
capture program drop _fgadv_cap
program define _fgadv_cap, rclass
    version 16.0
    gettoken cmd 0 : 0
    gettoken phrase 0 : 0
    tempfile cap
    capture log close _fgadvcap
    log using `"`cap'"', replace text name(_fgadvcap)
    capture noisily `cmd'
    local rc = _rc
    capture log close _fgadvcap
    _fgadv_saw using `"`cap'"', phrase(`"`phrase'"')
    return scalar saw = r(saw)
    return scalar rc = `rc'
end

* Ordinary single-record competing-risks fixture on a coarse time grid, so
* event times are heavily tied and a boundary can be placed exactly on one.
capture program drop _fgadv_cr
program define _fgadv_cr
    version 16.0
    syntax [, N(integer 400) SEED(integer 20260826) K(integer 4)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x = rnormal()
    gen double zz = rnormal()
    gen byte grp = 1 + mod(_n, 3)
    gen byte s = 1 + mod(_n, `k')
    gen long cl = 1 + mod(_n, 50)
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly stset t, failure(anyev) id(id)
end

* No competing events, heavily tied integer times. With no competing event no
* subject is ever retained past its own exit, so the subdistribution risk set IS
* the ordinary risk set and a hand-split episode Cox fit is a legitimate oracle
* for the interval assignment.
capture program drop _fgadv_tie
program define _fgadv_tie
    version 16.0
    syntax [, N(integer 900) SEED(integer 5309)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double lp = 0.6 * x1 - 0.4 * x2
    gen double tt = 1 + floor(6 * runiform()^exp(-lp))
    gen double tc = 1 + floor(7 * runiform())
    gen double t = min(tt, tc)
    gen byte status = cond(tt <= tc, 1, 0)
    gen byte anyev = status != 0
    quietly stset t, failure(anyev == 1) id(id)
end

* Build the (start, stop] episode split by hand. NOT stsplit: stsplit blanks
* the stset failure variable on every non-terminal episode, and rebuilding it
* afterwards is the same work with an extra way to get it wrong.
capture program drop _fgadv_split
program define _fgadv_split
    version 16.0
    args c1 c2
    if "`c2'" == "" local c2 = .
    quietly expand 3
    quietly bysort id: gen byte iv = _n
    quietly gen double start = cond(iv == 1, 0, cond(iv == 2, `c1', `c2'))
    quietly gen double _hi   = cond(iv == 1, `c1', cond(iv == 2, `c2', .))
    quietly gen double stop  = cond(missing(_hi), t, min(t, _hi))
    quietly drop if missing(start) | start >= t
    quietly gen byte fail = (status == 1) & (stop == t)
    quietly stset stop, failure(fail == 1) id(id) time0(start)
end

* -----------------------------------------------------------------------------
**# A1 an imputed level that exists in only SOME imputations
* -----------------------------------------------------------------------------
* grp is observed on {1, 2} only; imputation 1 fills every missing record with 1
* or 2, imputations 2 and 3 introduce level 3. finegray therefore fits two
* different designs, and the danger is a pooled estimate that lines the two up
* by POSITION -- which would pair the level-3 coefficient of m=2 with the x
* coefficient of m=1 and report the average as if it were one parameter.
*
* The guard that makes that impossible is that finegray reports the levels
* ACTUALLY PRESENT rather than padding a phantom column: e(b) is 2 wide on m=1
* and 3 wide on m=2, and mi's own consistency check then refuses to pool them.
* A package that emitted a zero level-3 column on m=1 would pool silently, and
* the pooled level-3 coefficient would be an average over an imputation that
* never estimated it.
local ++test_count
capture noisily {
    clear
    set seed 5150
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = (status > 0)
    drop u
    gen byte grp = 1 + mod(_n, 2)
    quietly replace grp = . if _n <= 60
    gen byte g1 = grp
    quietly replace g1 = 1 + mod(_n, 2) if missing(grp)
    gen byte g2 = grp
    quietly replace g2 = 3 if missing(grp) & mod(_n, 3) == 0
    quietly replace g2 = 1 + mod(_n, 2) if missing(g2)
    gen byte g3 = grp
    quietly replace g3 = 3 if missing(grp) & mod(_n, 3) != 0
    quietly replace g3 = 1 + mod(_n, 2) if missing(g3)
    quietly mi import wide, imputed(grp = g1 g2 g3) drop clear
    quietly mi register regular x t status anyev id
    quietly mi stset t, failure(anyev) id(id)

    * the fixture really is heterogeneous
    quietly count if _1_grp == 3
    assert !missing(r(N))
    assert r(N) == 0
    quietly count if _2_grp == 3
    assert !missing(r(N))
    assert r(N) > 0

    * Each per-imputation fit reports the levels it actually has. Assert the
    * DESIGN, not the coefficient-stripe spelling: `: colnames' hands a factor
    * name back through Stata's fv canonicaliser, which re-derives the base
    * marker from the data in memory -- and after `mi xeq' returns, that is the
    * m = 0 data, where grp has no level 3 at all. The same matrix therefore
    * reads back as `2.grp' or `2bn.grp' depending on which m is in memory.
    * e(fvsemantic) is the package's own record of the fitted expansion and is
    * what every rebuild path reads, so it is the thing worth pinning.
    * e(b) carries the base level 1b.grp as a zero column, so it is one
    * wider than the design in both imputations
    quietly mi xeq 1: finegray i.grp x, compete(status) cause(1) nolog
    assert colsof(e(b)) == 3
    assert "`e(designvars)'" != "" & `: word count `e(designvars)'' == 2
    assert "`e(fvsemantic)'" == "1b.grp 2.grp x"
    quietly mi xeq 2: finegray i.grp x, compete(status) cause(1) nolog
    assert colsof(e(b)) == 4
    assert "`e(fvsemantic)'" == "1b.grp 2.grp 3.grp x"

    * so mi refuses to pool them, and says why
    _fgadv_cap ///
        `"mi estimate, cmdok: finegray i.grp x, compete(status) cause(1) nolog"' ///
        "omitted terms vary"
    assert r(rc) == 498
    assert r(saw) == 1
}
local _rc = _rc
_fgadv_result `_rc' "A1 an imputation-specific factor level is refused, not pooled by position"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# A2 an imputation whose covariate is degenerate
* -----------------------------------------------------------------------------
* z is missing on every record, so its m = 1 fill is free to be constant. A
* constant covariate carries no information at any risk set; the fit must refuse
* rather than return a coefficient for a direction the likelihood is flat in.
* Under `mi estimate' the refusal must surface: either the whole pooled command
* fails, or -- with errorok -- the reduced M is reported and recorded in
* e(M_mi), e(m_est_mi) and e(rc_mi). Pooling three imputations' worth of
* uncertainty over two fits at rc 0 would be the silent-corruption case.
local ++test_count
capture noisily {
    clear
    set seed 6161
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = (status > 0)
    drop u
    gen double z = .
    gen double z1 = 0
    gen double z2 = rnormal()
    gen double z3 = rnormal()
    quietly mi import wide, imputed(z = z1 z2 z3) drop clear
    quietly mi register regular x t status anyev id
    quietly mi stset t, failure(anyev) id(id)
    quietly summarize _1_z
    assert !missing(r(sd))
    assert r(sd) == 0

    * the per-imputation refusal names the offending term
    _fgadv_cap `"mi xeq 1: finegray x z, compete(status) cause(1) nolog"' ///
        "constant or collinear term(s): z"
    assert r(rc) == 459
    assert r(saw) == 1

    * without errorok the pooled command fails and attributes the failure to m
    _fgadv_cap ///
        `"mi estimate, cmdok: finegray x z, compete(status) cause(1) nolog"' ///
        "an error occurred when mi estimate executed finegray on m=1"
    assert r(rc) == 459
    assert r(saw) == 1

    * with errorok it pools the survivors and DISCLOSES the count
    _fgadv_cap ///
        `"mi estimate, cmdok errorok: finegray x z, compete(status) cause(1) nolog"' ///
        "1 imputation ignored because of a failure to estimate parameters"
    assert r(rc) == 0
    assert r(saw) == 1
    assert e(M_mi) == 2
    assert e(N_mi) == 300
    assert "`e(m_est_mi)'" == "2 3"
    assert "`e(rc_mi)'" == "459 0 0"
}
local _rc = _rc
_fgadv_result `_rc' "A2 a failing imputation is surfaced, never pooled as a success"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# A3 the _fg_* namespace: a user's column, and a PREVIOUS fit's column
* -----------------------------------------------------------------------------
* Off mi the package writes permanent columns into the caller's data. Two ways
* that can destroy something: overwriting a user variable that already holds the
* name, and letting fit 1's columns be read back by fit 2's post-estimation.
* The first must refuse with the user's values untouched; the second must drop
* the stale columns and say so, so that finegray_cif after fit 2 rebuilds fit
* 2's design rather than fit 1's.
local ++test_count
capture noisily {
    * (a) a user variable already named _fg_grp_2
    _fgadv_cr
    gen double _fg_grp_2 = 99
    capture noisily finegray i.grp x, compete(status) cause(1) nolog
    assert _rc == 198
    confirm variable _fg_grp_2
    quietly summarize _fg_grp_2
    assert !missing(r(mean), r(sd))
    assert r(mean) == 99
    assert r(sd) == 0

    * (b) a user variable already named _fg_entry, on multiple-record data
    _fgadv_cr, n(200)
    quietly expand 2
    quietly bysort id: gen byte rec = _n
    quietly gen double start = cond(rec == 1, 0, 1)
    quietly gen double stop  = cond(rec == 1, 1, max(t, 2))
    quietly gen byte fail = (status != 0) & (rec == 2)
    quietly stset stop, failure(fail == 1) id(id) time0(start)
    gen double _fg_entry = -99
    capture noisily finegray x, compete(status) cause(1) nolog
    assert _rc == 198
    confirm variable _fg_entry
    quietly summarize _fg_entry
    assert !missing(r(mean), r(sd))
    assert r(mean) == -99
    assert r(sd) == 0
    * and with the name free the fit takes it
    drop _fg_entry
    quietly finegray x, compete(status) cause(1) nolog
    confirm variable _fg_entry

    * (c) fit 2 does not inherit fit 1's design columns
    _fgadv_cr
    gen byte grp2 = 1 + mod(_n, 4)
    quietly finegray i.grp x, compete(status) cause(1) nolog
    quietly ds _fg_*
    assert "`r(varlist)'" == "_fg_grp_2 _fg_grp_3"
    _fgadv_cap `"finegray i.grp2 x, compete(status) cause(1) nolog"' ///
        "dropping prior finegray FV variables"
    assert r(rc) == 0
    assert r(saw) == 1
    quietly ds _fg_*
    assert "`r(varlist)'" == "_fg_grp2_2 _fg_grp2_3 _fg_grp2_4"
    assert "`e(designvars)'" == "_fg_grp2_2 _fg_grp2_3 _fg_grp2_4 x"
    * the post-estimation that follows answers from fit 2's design
    quietly finegray_cif, at(grp2=1 x=0) attime(4) nograph
    matrix _a3 = r(at)
    assert colsof(_a3) == 4
    * a third fit with no factor variables clears them entirely
    quietly finegray x, compete(status) cause(1) nolog
    capture quietly ds _fg_*
    assert _rc != 0
}
local _rc = _rc
_fgadv_result `_rc' "A3 _fg_* refuses a user's name and never leaks between fits"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# A4a mi estimate x bstrata(): pooling checked by hand Rubin's rules
* -----------------------------------------------------------------------------
* Neither feature's own suite runs the other. Pooling a stratified fit is not
* different arithmetic, but the fit it pools has an extra e() surface
* (k_bstrata, bstrata_noevent, a K x 3 baseline) and a wider chance of a
* per-imputation fit that quietly differs in shape. Check the pooled numbers
* against Rubin (1987) computed here from the per-imputation e(b)/e(V), and
* check that the stratified fit really was the thing pooled.
local ++test_count
capture noisily {
    clear
    set seed 7272
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen byte s = 1 + mod(_n, 3)
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = (status > 0)
    drop u
    gen double z = rnormal()
    quietly replace z = . if mod(_n, 5) == 0
    quietly mi set wide
    quietly mi register imputed z
    quietly mi register regular x t status anyev id s
    set seed 33
    quietly mi impute regress z = x, add(4)
    quietly mi stset t, failure(anyev) id(id)
    local M = 4

    quietly mi estimate, cmdok: finegray x z, compete(status) cause(1) ///
        bstrata(s) nolog
    tempname Qmi Tmi
    matrix `Qmi' = e(b_mi)
    matrix `Tmi' = e(V_mi)
    local p = colsof(`Qmi')
    assert e(M_mi) == `M'
    assert `p' == 2

    tempname Qbar Ubar Bmat Qm Um Tman dev
    matrix `Qbar' = J(1, `p', 0)
    matrix `Ubar' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        quietly mi xeq `m': finegray x z, compete(status) cause(1) ///
            bstrata(s) nolog
        assert e(k_bstrata) == 3
        assert "`e(bstrata)'" == "s"
        matrix `Qm' = e(b)
        matrix `Um' = e(V)
        matrix `Qbar' = `Qbar' + `Qm' / `M'
        matrix `Ubar' = `Ubar' + `Um' / `M'
        matrix _A4Q`m' = `Qm'
    }
    matrix `Bmat' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        matrix `dev' = _A4Q`m' - `Qbar'
        matrix `Bmat' = `Bmat' + (`dev'' * `dev') / (`M' - 1)
    }
    matrix `Tman' = `Ubar' + (1 + 1 / `M') * `Bmat'
    forvalues j = 1/`p' {
        assert !missing(`Qbar'[1, `j'], `Qmi'[1, `j'])
        assert reldif(`Qbar'[1, `j'], `Qmi'[1, `j']) < 1e-12
        forvalues k = 1/`p' {
            assert !missing(`Tman'[`j', `k'], `Tmi'[`j', `k'])
            assert reldif(`Tman'[`j', `k'], `Tmi'[`j', `k']) < 1e-10
        }
    }
}
local _rc = _rc
_fgadv_result `_rc' "A4a mi estimate pools a bstrata() fit by Rubin's rules"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# A4b mi estimate x tvc(), and a tvc() fit typed DIRECTLY on mi data
* -----------------------------------------------------------------------------
* Under tvc() the coefficient vector is wider than the design and carries
* equation names. Pooling has to align on (equation, name) pairs; the hand
* Rubin's rules below pool the same columns in the same order and must agree.
*
* Then the routing half: typed directly on mi data a tvc() fit must still send
* its support columns to tempvars. A residue check on `ds _fg_*' is not enough
* -- mi's own audit is what a user sees -- so `mi describe' must report no
* unregistered variables and `mi update' must have nothing to repair.
local ++test_count
capture noisily {
    clear
    set seed 8383
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = (status > 0)
    drop u
    gen double z = rnormal()
    quietly replace z = . if mod(_n, 5) == 0
    quietly mi set wide
    quietly mi register imputed z
    quietly mi register regular x t status anyev id
    set seed 34
    quietly mi impute regress z = x, add(4)
    quietly mi stset t, failure(anyev) id(id)
    local M = 4

    quietly mi estimate, cmdok: finegray x z, compete(status) cause(1) ///
        tvc(x) tsplit(4) nolog
    tempname Qmi Tmi
    matrix `Qmi' = e(b_mi)
    matrix `Tmi' = e(V_mi)
    local p = colsof(`Qmi')
    assert e(M_mi) == `M'
    assert `p' == 3
    local _ce : coleq `Qmi'
    assert "`_ce'" == "main tvc1 tvc2"

    tempname Qbar Ubar Bmat Qm Um Tman dev
    matrix `Qbar' = J(1, `p', 0)
    matrix `Ubar' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        quietly mi xeq `m': finegray x z, compete(status) cause(1) ///
            tvc(x) tsplit(4) nolog
        assert e(n_intervals) == 2
        matrix `Qm' = e(b)
        matrix `Um' = e(V)
        matrix `Qbar' = `Qbar' + `Qm' / `M'
        matrix `Ubar' = `Ubar' + `Um' / `M'
        matrix _A4bQ`m' = `Qm'
    }
    matrix `Bmat' = J(`p', `p', 0)
    forvalues m = 1/`M' {
        matrix `dev' = _A4bQ`m' - `Qbar'
        matrix `Bmat' = `Bmat' + (`dev'' * `dev') / (`M' - 1)
    }
    matrix `Tman' = `Ubar' + (1 + 1 / `M') * `Bmat'
    forvalues j = 1/`p' {
        assert !missing(`Qbar'[1, `j'], `Qmi'[1, `j'])
        assert reldif(`Qbar'[1, `j'], `Qmi'[1, `j']) < 1e-12
        forvalues k = 1/`p' {
            assert !missing(`Tman'[`j', `k'], `Tmi'[`j', `k'])
            assert reldif(`Tman'[`j', `k'], `Tmi'[`j', `k']) < 1e-10
        }
    }

    * typed directly: tempvar routing, mi flags, and a clean mi audit
    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) nolog
    assert e(n_intervals) == 2
    assert "`e(mi_data)'" == "1"
    assert "`e(postest)'" == "unavailable_mi"
    capture quietly ds _fg_*
    assert _rc != 0
    _fgadv_cap `"mi describe"' "there are no unregistered variables"
    assert r(rc) == 0
    assert r(saw) == 1
    capture noisily mi update
    assert _rc == 0
    * and post-estimation on that fit is refused by name
    capture noisily finegray_predict _a4bxb, xb
    assert _rc == 301
    capture confirm variable _a4bxb
    assert _rc == 111
}
local _rc = _rc
_fgadv_result `_rc' "A4b mi estimate pools a tvc() fit; a direct tvc() fit leaves no residue"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# A5 flongsep and mlong typed DIRECTLY, not under mi estimate
* -----------------------------------------------------------------------------
* test_finegray_mi.do covers mlong/wide/flong under `mi estimate'; the styles
* typed directly are the historically buggy path and flongsep is not covered at
* all. flongsep is also the style where _dta[_mi_style] survives, so it is the
* one that would keep working if detection silently narrowed.
*
* mlong is here for the opposite reason: it stacks M + 1 copies of every subject
* under one id, so a direct fit could fit each subject M + 1 times. It must not
* -- and it does not, because the copies share (t0, t] and the contiguity check
* sees them as overlapping records.
local ++test_count
capture noisily {
    clear
    set seed 909
    quietly set obs 250
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = (status > 0)
    gen byte grp = 1 + mod(_n, 3)
    drop u
    gen double z = rnormal()
    quietly replace z = . if mod(_n, 5) == 0
    quietly mi set wide
    quietly mi register imputed z
    quietly mi register regular x t status anyev id grp
    set seed 33
    quietly mi impute regress z = x, add(3)
    quietly mi stset t, failure(anyev) id(id)
    quietly save "`c(tmpdir)'/_fgadv_a5_src.dta", replace

    * flongsep writes one dataset per imputation, so it needs a directory of its
    * own; the qa/ tree must not collect them.
    tempfile anchor
    local sepdir "`anchor'_sep"
    capture mkdir "`sepdir'"
    quietly cd "`sepdir'"
    quietly mi convert flongsep fgadvsep, clear
    assert `"`: char _dta[_mi_style]'"' == "flongsep"

    quietly finegray i.grp z, compete(status) cause(1) nolog
    assert "`e(mi_data)'" == "1"
    assert "`e(postest)'" == "unavailable_mi"
    * NO estimation-state characteristic is written at all.
    *
    * This line used to assert "0", the INVALIDATED mark.  That was pinning a
    * defect as a contract: on mi data the fit mutates nothing permanent, so
    * there is nothing for the mark to invalidate, and writing it put seven
    * _dta[_finegray_*] characteristics into the caller's mi dataset against
    * finegray.ado's own stated contract.  Corrected 2026-08-26 with defect
    * D0-1; the regressions live in qa/test_finegray_mi_lattice.do
    * (FGML-01/02/03) and the same correction was made to FGMI-1 in
    * qa/test_finegray_mi.do.  ABSENT means UNKNOWN and is adjudicated against
    * e(), which is the right state for a dataset the fit never touched.
    assert `"`: char _dta[_finegray_estimated]'"' == ""
    local _a5cs : char _dta[]
    local _a5n = 0
    foreach _a5c of local _a5cs {
        if substr("`_a5c'", 1, 10) == "_finegray_" local ++_a5n
    }
    assert `_a5n' == 0
    capture quietly ds _fg_*
    assert _rc != 0
    foreach _c in "finegray_predict _a5xb, xb" "finegray_cif, attime(3) nograph" ///
        "finegray_phtest" {
        capture noisily `_c'
        assert _rc == 301
    }
    _fgadv_cap `"mi describe"' "there are no unregistered variables"
    assert r(saw) == 1
    capture noisily mi update
    assert _rc == 0
    quietly mi convert wide, clear
    quietly cd "`qa_dir'"
    capture shell rm -rf "`sepdir'"

    * mlong typed directly: M + 1 stacked copies must not be fitted as episodes
    quietly use "`c(tmpdir)'/_fgadv_a5_src.dta", clear
    quietly mi convert mlong, clear
    quietly count
    assert !missing(r(N))
    assert r(N) > 250
    _fgadv_cap `"finegray x i.grp, compete(status) cause(1) nolog"' ///
        "subject records have gaps or overlaps"
    assert r(rc) == 198
    assert r(saw) == 1
    capture quietly ds _fg_*
    assert _rc != 0
    capture noisily mi update
    assert _rc == 0
}
local _rc = _rc
capture quietly cd "`qa_dir'"
_fgadv_result `_rc' "A5 flongsep typed directly is detected; mlong is refused, not multiplied"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)
capture erase "`c(tmpdir)'/_fgadv_a5_src.dta"

* -----------------------------------------------------------------------------
**# A6 the estimation sample does not leak the m = 0 complete-case rows
* -----------------------------------------------------------------------------
* A direct fit on mi data uses m = 0, where the imputed covariate is still
* missing, so markout drops those rows. Under `mi estimate' every imputation is
* complete and every fit must use all of them: an e(N) that varied by m, or a
* pooled N equal to the complete-case count, would mean the completed data were
* not being used.
local ++test_count
capture noisily {
    clear
    set seed 909
    quietly set obs 250
    gen long id = _n
    gen double x = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = (status > 0)
    drop u
    gen double z = rnormal()
    quietly replace z = . if mod(_n, 5) == 0
    quietly mi set wide
    quietly mi register imputed z
    quietly mi register regular x t status anyev id
    set seed 33
    quietly mi impute regress z = x, add(3)
    quietly mi stset t, failure(anyev) id(id)

    quietly count
    local _ntot = r(N)
    quietly count if missing(z)
    local _nmiss = r(N)
    assert `_nmiss' > 0

    quietly finegray x z, compete(status) cause(1) nolog
    assert e(N) == `_ntot' - `_nmiss'

    forvalues m = 1/3 {
        quietly mi xeq `m': finegray x z, compete(status) cause(1) nolog
        assert e(N) == `_ntot'
    }
    quietly mi estimate, cmdok: finegray x z, compete(status) cause(1) nolog
    assert e(N_mi) == `_ntot'
    assert e(N_min_mi) == `_ntot'
    assert e(N_max_mi) == `_ntot'
    assert e(esampvary_mi) == 0
}
local _rc = _rc
_fgadv_result `_rc' "A6 every imputation is fitted whole; the m=0 complete case does not leak"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B1 32-character covariate names sharing a 30-character prefix, both tvc()
* -----------------------------------------------------------------------------
* Stata's variable-name limit is 32 characters, and the package truncates its
* own _fg_<term> names AT 32 -- so two names that agree on their first 30
* characters are the shape in which a truncation collision would show. Under
* tvc() each name also appears once per interval, under its own equation, and
* every round trip (test, e(refitcmd), predict) has to keep them apart.
local ++test_count
capture noisily {
    local nm1 "abcdefghijklmnopqrstuvwxyzabcdAA"
    local nm2 "abcdefghijklmnopqrstuvwxyzabcdBB"
    assert length("`nm1'") == 32
    assert length("`nm2'") == 32
    assert substr("`nm1'", 1, 30) == substr("`nm2'", 1, 30)

    clear
    set seed 1234
    quietly set obs 400
    gen long id = _n
    gen double `nm1' = rnormal()
    gen double `nm2' = rnormal()
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly stset t, failure(anyev) id(id)

    quietly finegray `nm1' `nm2', compete(status) cause(1) ///
        tvc(`nm1' `nm2') tsplit(4) nolog
    assert colsof(e(b)) == 4
    local _cn : colnames e(b)
    local _ce : coleq e(b)
    assert "`_cn'" == "`nm1' `nm2' `nm1' `nm2'"
    assert "`_ce'" == "tvc1 tvc1 tvc2 tvc2"

    * the four coefficients are four distinct numbers, addressed by equation
    quietly test [tvc2]`nm1'
    assert r(df) == 1
    quietly test [tvc1]`nm1' = [tvc2]`nm1'
    assert r(df) == 1
    quietly test [tvc1]`nm1' = [tvc1]`nm2'
    assert r(df) == 1

    matrix _b1 = e(b)
    local _refit `"`e(refitcmd)'"'
    assert strpos(`"`_refit'"', "`nm1'") > 0
    assert strpos(`"`_refit'"', "`nm2'") > 0
    quietly `_refit'
    assert mreldif(_b1, e(b)) == 0

    quietly finegray_predict _b1xb, xb
    assert !missing(_b1xb[1])
    quietly finegray_predict _b1cif, cif
    quietly summarize _b1cif
    assert !missing(r(min), r(max))
    assert r(min) >= 0 & r(max) <= 1
}
local _rc = _rc
_fgadv_result `_rc' "B1 32-char names sharing a 30-char prefix stay distinct through tvc()"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B2 boundaries stacked on the edges of the cause-event support
* -----------------------------------------------------------------------------
* T15 in test_finegray_tvc.do places a boundary BEYOND the last cause event.
* The adversarial cases are the two edges themselves: a cut exactly ON the last
* cause-event time (the last interval is (c, .] and empty, because the interval
* is closed on the right) and a cut just below the first (the leading interval
* is empty). Both must name the interval; a cut exactly ON the first cause-event
* time is legal, and the difference between those two is the whole tie
* convention.
local ++test_count
capture noisily {
    _fgadv_cr
    quietly summarize t if status == 1
    assert !missing(r(min), r(max))
    local _tmin = r(min)
    local _tmax = r(max)

    _fgadv_cap ///
        `"finegray x, compete(status) cause(1) tvc(x) tsplit(`_tmax') nolog"' ///
        "contains no cause 1 event"
    assert r(rc) == 459
    assert r(saw) == 1

    _fgadv_cap ///
        `"finegray x, compete(status) cause(1) tvc(x) tsplit(`= `_tmin' - 0.5') nolog"' ///
        "contains no cause 1 event"
    assert r(rc) == 459
    assert r(saw) == 1

    * the lower edge itself is inside the support, because the interval is
    * (0, cut] and the events at cut belong to it
    quietly count if status == 1 & t <= `_tmin'
    assert !missing(r(N))
    local _n1 = r(N)
    assert `_n1' > 0
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(`_tmin') nolog
    assert e(n_intervals) == 2
    local _nf : word 1 of `e(tsplit_nfail)'
    assert `_nf' == `_n1'
}
local _rc = _rc
_fgadv_result `_rc' "B2 a cut at the last cause event and below the first are both refused"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B3 a boundary ON a heavily tied event time, against a hand-split Cox oracle
* -----------------------------------------------------------------------------
* T04 moves ONE event onto the boundary and checks the direction against
* stcrreg's texp(). Here 99 events sit exactly on the cut, so the two
* conventions differ by percent rather than by ulps, and the oracle is a
* different one: a hand-built (start, stop] episode split fitted with stcox and
* ibn.interval#c.x. Because the fixture has no competing events, the
* subdistribution risk set IS the ordinary risk set and that fit estimates the
* same model by an entirely separate code path.
*
* The oracle is run three ways: split at the tied time (must agree), split just
* below it (the opposite convention -- must NOT agree), and split at a
* non-integer time between two tied event times (agree again). Only the first
* two together pin the direction; agreement alone would be satisfied by both
* conventions if no event sat on the boundary.
local ++test_count
capture noisily {
    _fgadv_tie
    quietly count if t == 3 & status == 1
    assert !missing(r(N))
    assert r(N) > 50

    quietly finegray x2 x1, compete(status) cause(1) tvc(x1) tsplit(3) ///
        nolog norobust
    matrix _b3f = e(b)
    local _b3ll = e(ll)

    _fgadv_tie
    _fgadv_split 3
    quietly stcox x2 ibn.iv#c.x1, breslow nolog
    matrix _b3c = e(b)
    local _b3cll = e(ll)
    forvalues j = 1/3 {
        assert !missing(_b3f[1, `j'], _b3c[1, `j'])
        assert reldif(_b3f[1, `j'], _b3c[1, `j']) < 1e-9
    }
    assert !missing(`_b3ll', `_b3cll')
    assert reldif(`_b3ll', `_b3cll') < 1e-10

    * the opposite convention must be visibly different, not merely different
    _fgadv_tie
    _fgadv_split 2.999999
    quietly stcox x2 ibn.iv#c.x1, breslow nolog
    matrix _b3w = e(b)
    assert !missing(_b3w[1, 2], _b3w[1, 3])
    assert reldif(_b3f[1, 2], _b3w[1, 2]) > 1e-3
    assert reldif(_b3f[1, 3], _b3w[1, 3]) > 1e-3

    * a non-integer boundary between two tied integer event times
    _fgadv_tie
    quietly count if t == 4 & status == 1
    assert !missing(r(N))
    assert r(N) > 20
    quietly finegray x2 x1, compete(status) cause(1) tvc(x1) tsplit(3.5) ///
        nolog norobust
    matrix _b5f = e(b)
    local _b5ll = e(ll)
    _fgadv_tie
    _fgadv_split 3.5
    quietly stcox x2 ibn.iv#c.x1, breslow nolog
    matrix _b5c = e(b)
    forvalues j = 1/3 {
        assert !missing(_b5f[1, `j'], _b5c[1, `j'])
        assert reldif(_b5f[1, `j'], _b5c[1, `j']) < 1e-9
    }
    assert !missing(`_b5ll', e(ll))
    assert reldif(`_b5ll', e(ll)) < 1e-10
}
local _rc = _rc
_fgadv_result `_rc' "B3 a boundary on 99 tied events matches a hand-split Cox fit, and only one way"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B4 tvc() with strata() and cluster(), neither of which is fenced off
* -----------------------------------------------------------------------------
* No reference implementation reaches this combination, so the checks are
* invariances that a wrong composition would break:
*   (a) two strata holding IDENTICAL data have identical censoring KMs, so the
*       stratified G equals the pooled G and the fit must not move at all;
*   (b) strata whose censoring really differs must move it;
*   (c) relabelling clusters is a permutation of names, not of the partition, so
*       neither the coefficients nor the cluster-robust variance may change.
local ++test_count
capture noisily {
    clear
    set seed 2718
    quietly set obs 400
    gen long base = _n
    gen double x = rnormal()
    gen double z = rbinomial(1, .5)
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    drop u
    quietly expand 2
    quietly bysort base: gen byte s = _n
    gen long id = _n
    gen byte anyev = status > 0
    gen long cl = 1 + mod(base, 100)
    quietly stset t, failure(anyev) id(id)

    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) nolog
    matrix _b4u = e(b)
    matrix _b4uV = e(V)
    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) ///
        strata(s) nolog
    assert "`e(strata)'" != ""
    forvalues j = 1/3 {
        assert !missing(_b4u[1, `j'], e(b)[1, `j'])
        assert reldif(_b4u[1, `j'], e(b)[1, `j']) < 1e-9
    }

    * strata that really differ move the estimate
    gen byte s2 = mod(_n, 2)
    quietly replace t = min(t, 3) if s2 == 1 & status == 0
    quietly stset t, failure(anyev) id(id)
    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) nolog
    matrix _b4p = e(b)
    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) ///
        strata(s2) nolog
    local _moved = 0
    forvalues j = 1/3 {
        assert !missing(_b4p[1, `j'], e(b)[1, `j'])
        if reldif(_b4p[1, `j'], e(b)[1, `j']) > 1e-6 local _moved = 1
    }
    assert `_moved' == 1

    * cluster relabelling is invariant, and the clustering really happened
    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) ///
        strata(s2) cluster(cl) nolog
    assert "`e(vce)'" == "cluster"
    assert e(N_clust) == 100
    matrix _b4c = e(b)
    matrix _b4cV = e(V)
    gen long cl2 = mod(cl * 41 + 7, 100) + 1
    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) ///
        strata(s2) cluster(cl2) nolog
    assert e(N_clust) == 100
    assert mreldif(_b4c, e(b)) == 0
    forvalues j = 1/3 {
        forvalues k = 1/3 {
            assert !missing(_b4cV[`j', `k'], e(V)[`j', `k'])
            assert abs(_b4cV[`j', `k'] - e(V)[`j', `k']) < 1e-14
        }
    }
    * and the cluster-robust variance is not the unclustered one
    quietly finegray x z, compete(status) cause(1) tvc(x) tsplit(4) ///
        strata(s2) nolog
    assert reldif(_b4cV[1, 1], e(V)[1, 1]) > 1e-8
}
local _rc = _rc
_fgadv_result `_rc' "B4 tvc() with strata() and cluster() holds its invariances"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# B5 an interval carrying exactly ONE cause event
* -----------------------------------------------------------------------------
* The empty-interval fence needs one event to let a fit through, so one event is
* the worst case it permits: two coefficients estimated from a single event
* reach a monotone likelihood and converge, printing a finite subhazard ratio.
* The requirement is not that the fit be refused -- it is identified in the
* formal sense -- but that the reader be TOLD, in the rendered output, what the
* interval rests on, and that the per-interval counts be in e().
local ++test_count
capture noisily {
    clear
    set seed 31415
    quietly set obs 600
    gen long id = _n
    gen double x = rnormal()
    gen double w = rnormal()
    gen double u = runiform()
    gen double t = 3 + floor(6 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    drop u
    quietly replace t = 1 in 1/20
    quietly replace status = 1 in 1/20
    quietly replace t = 2 in 21
    quietly replace status = 1 in 21
    quietly replace t = 2 in 22/40
    quietly replace status = 2 in 22/40
    gen byte anyev = status > 0
    quietly stset t, failure(anyev) id(id)
    quietly count if status == 1 & t > 1 & t <= 2
    assert !missing(r(N))
    assert r(N) == 1

    _fgadv_cap ///
        `"finegray x w, compete(status) cause(1) tvc(x w) tsplit(1 2) nolog"' ///
        "an interval carries only 1 cause 1 event"
    assert r(rc) == 0
    assert r(saw) == 1

    assert e(n_intervals) == 3
    assert colsof(e(b)) == 6
    assert "`e(tsplit_nfail)'" == "20 1 282"
    local _ce : coleq e(b)
    assert "`_ce'" == "tvc1 tvc1 tvc2 tvc2 tvc3 tvc3"
    * no bare dots and no nonsense on the log scale
    matrix _b5b = e(b)
    matrix _b5V = e(V)
    forvalues j = 1/6 {
        assert !missing(_b5b[1, `j'], _b5V[`j', `j'])
        assert _b5V[`j', `j'] > 0
        assert abs(_b5b[1, `j']) < 20
    }
    assert e(converged) == 1
    assert e(rank) == 6

    * the warning is about THIS fit, not printed on every piecewise fit
    _fgadv_cap ///
        `"finegray x w, compete(status) cause(1) tvc(x w) tsplit(4) nolog"' ///
        "an interval carries only"
    assert r(rc) == 0
    assert r(saw) == 0
}
local _rc = _rc
_fgadv_result `_rc' "B5 a one-event interval converges but says what it rests on"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C1 a missing value in the bstrata() variable
* -----------------------------------------------------------------------------
* The help says such rows are excluded from the estimation sample. That is a
* documented markout, not the r(198) the compete() outcome gets -- and the
* difference is defensible because bstrata() is a design variable, not the
* outcome classification. What has to be true for it to stay defensible is that
* the exclusion be VISIBLE and EXACT: e(N) and e(sample) must both show it, and
* the fit must equal the one the user would have written by hand with `if'.
local ++test_count
capture noisily {
    _fgadv_cr
    quietly count
    local _ntot = r(N)
    quietly replace s = . in 1/7
    quietly finegray x, compete(status) cause(1) bstrata(s) nolog
    assert e(N) == `_ntot' - 7
    quietly count if e(sample)
    assert !missing(r(N))
    assert r(N) == `_ntot' - 7
    quietly count if e(sample) & missing(s)
    assert !missing(r(N))
    assert r(N) == 0
    assert e(k_bstrata) == 4
    matrix _c1b = e(b)
    matrix _c1V = e(V)

    quietly finegray x if !missing(s), compete(status) cause(1) bstrata(s) nolog
    assert e(N) == `_ntot' - 7
    assert mreldif(_c1b, e(b)) == 0
    assert mreldif(_c1V, e(V)) == 0
}
local _rc = _rc
_fgadv_result `_rc' "C1 a missing bstrata() value is excluded exactly as an if would"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C2 hostile stratum labels: a space, a quote, an `=' and a `<'
* -----------------------------------------------------------------------------
* Stata drops a matrix row or column name it cannot parse and substitutes the
* positional default r1/r2 without erroring, so a stratified baseline that
* carried its identity in a NAME would lose that identity at rc 0 the moment a
* value label held a space or a quote. e(basehaz) is built the other way -- the
* stratum VALUE is data, in column 1, and only the three column names are names
* -- and this test pins that, because the alternative fails silently.
local ++test_count
capture noisily {
    _fgadv_cr
    label define _fgadvlbl 1 "a b" 2 `"q="z"' 3 "lt<gt>" 4 "x:y z", replace
    label values s _fgadvlbl
    quietly finegray x, compete(status) cause(1) bstrata(s) basehaz nolog
    assert e(k_bstrata) == 4
    matrix _c2B = e(basehaz)
    assert colsof(_c2B) == 3
    local _bcn : colnames _c2B
    assert "`_bcn'" == "bstratum time cumhazard"

    * the four fitted strata are present in the baseline, by VALUE
    mata: st_matrix("_c2u", uniqrows(st_matrix("_c2B")[., 1]))
    assert rowsof(_c2u) == 4
    forvalues i = 1/4 {
        assert !missing(_c2u[`i', 1])
        assert _c2u[`i', 1] == `i'
    }

    * post-estimation still resolves the stratum, and replay still works
    quietly finegray_cif, bstratum(3) attime(4) nograph
    assert !missing(r(bstratum))
    assert r(bstratum) == 3
    assert "`r(bstrata)'" == "s"
    matrix _c2t = r(table)
    assert !missing(_c2t[1, 2])
    assert _c2t[1, 2] >= 0 & _c2t[1, 2] <= 1
    quietly test x
    assert r(df) == 1
    quietly finegray
    assert "`e(cmd)'" == "finegray"
    assert e(k_bstrata) == 4
    label drop _fgadvlbl
}
local _rc = _rc
_fgadv_result `_rc' "C2 hostile value labels do not cost e(basehaz) its stratum identity"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C3 non-consecutive and negative stratum values
* -----------------------------------------------------------------------------
* bstratum() has to address a stratum by its VALUE, because the engine's
* internal 1..K coding is not something the user can see. Strata numbered
* 3, 17, 40 and -5 separate the two: an implementation that took bstratum(#) as
* a position would answer bstratum(2) from the second block instead of refusing.
local ++test_count
capture noisily {
    _fgadv_cr
    quietly replace s = cond(s == 1, 3, cond(s == 2, 17, cond(s == 3, 40, -5)))
    quietly finegray x, compete(status) cause(1) bstrata(s) basehaz nolog
    assert e(k_bstrata) == 4
    matrix _c3B = e(basehaz)
    mata: st_matrix("_c3u", uniqrows(st_matrix("_c3B")[., 1]))
    assert rowsof(_c3u) == 4
    assert _c3u[1, 1] == -5
    assert _c3u[2, 1] == 3
    assert _c3u[3, 1] == 17
    assert _c3u[4, 1] == 40

    foreach _v in -5 3 17 40 {
        quietly finegray_cif, bstratum(`_v') attime(4) nograph
        assert !missing(r(bstratum))
        assert r(bstratum) == `_v'
        matrix _c3t = r(table)
        assert !missing(_c3t[1, 2])
        assert _c3t[1, 2] >= 0 & _c3t[1, 2] <= 1
        matrix _c3`= abs(`_v')' = _c3t
    }
    * distinct strata give distinct curves -- one shared curve would satisfy
    * every existence check above
    assert reldif(_c35[1, 2], _c317[1, 2]) > 1e-6

    * a value that is not a fitted level is refused, and the message lists what is
    _fgadv_cap `"finegray_cif, bstratum(2) attime(4) nograph"' ///
        "is not a fitted baseline stratum"
    assert r(rc) == 459
    assert r(saw) == 1
    _fgadv_cap `"finegray_cif, bstratum(1) attime(4) nograph"' ///
        "the estimation sample holds s levels: -5 3 17 40"
    assert r(rc) == 459
    assert r(saw) == 1
}
local _rc = _rc
_fgadv_result `_rc' "C3 bstratum() addresses strata by value, and refuses a non-level"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C4 the bstrata() variable in the covariate list, and in strata()
* -----------------------------------------------------------------------------
* i.s with bstrata(s) is not identified: the stratified baseline already absorbs
* every within-stratum level shift, so the indicator columns contribute nothing
* at any cause-event risk set. A fit that converged there and printed finite
* standard errors would be reporting a parameter the data cannot speak to.
* bstrata(s) strata(s) is the opposite case -- documented, meaningful (the
* baseline free by s AND the censoring KM estimated within s), and it must run
* and differ from bstrata(s) alone.
local ++test_count
capture noisily {
    _fgadv_cr
    _fgadv_cap `"finegray i.s x, compete(status) cause(1) bstrata(s) nolog"' ///
        "contributing no information at any cause-event risk set"
    assert r(rc) == 459
    assert r(saw) == 1

    _fgadv_cr
    quietly finegray x, compete(status) cause(1) bstrata(s) nolog
    matrix _c4b = e(b)
    quietly finegray x, compete(status) cause(1) bstrata(s) strata(s) nolog
    assert "`e(bstrata)'" == "s"
    assert "`e(strata)'" == "s"
    assert e(k_bstrata) == 4
    assert !missing(_c4b[1, 1], e(b)[1, 1])
    assert reldif(_c4b[1, 1], e(b)[1, 1]) > 1e-9
}
local _rc = _rc
_fgadv_result `_rc' "C4 i.s with bstrata(s) is refused; bstrata(s) strata(s) is a real second axis"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C5 K = 20 strata over 200 subjects, one of them with a single cause event
* -----------------------------------------------------------------------------
* The stratified baseline is K blocks stacked in one matrix, so the thing that
* can go wrong at rc 0 is a block that belongs to the wrong stratum: rows sorted
* globally rather than within stratum, a stratum silently sharing another's
* curve, or a stratum missing entirely. Every check below is computed from
* e(basehaz) in Mata against the data's own per-stratum cause-event times -- not
* through finegray_cif or any other package helper, which would share whatever
* mapping the matrix already has.
local ++test_count
capture noisily {
    clear
    set seed 8080
    quietly set obs 200
    gen long id = _n
    gen double x = rnormal()
    gen byte s = 1 + mod(_n, 20)
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly replace s = 1 + mod(_n, 19) if s == 20 & _n > 60
    quietly stset t, failure(anyev) id(id)
    quietly count if s == 20
    assert !missing(r(N))
    assert r(N) <= 3
    quietly count if s == 20 & status == 1
    assert !missing(r(N))
    assert r(N) == 1

    quietly finegray x, compete(status) cause(1) bstrata(s) basehaz nolog
    assert e(k_bstrata) == 20
    assert "`e(bstrata_noevent)'" == ""
    matrix _c5B = e(basehaz)
    assert colsof(_c5B) == 3

    * every stratum present exactly once as a contiguous block, times strictly
    * increasing inside it, cumulative hazard nonnegative and nondecreasing
    * Single-line mata: a multi-line mata:/end block inside a braced
    * `capture noisily' block is not reliably entered as a block.
    mata: B = st_matrix("_c5B"); u = uniqrows(B[., 1]); bad = 0;              ///
        if (rows(u) != 20) bad = bad + 1000;                                  ///
        for (i = 1; i <= rows(u); i++) {                                      ///
            idx = selectindex(B[., 1] :== u[i]);                              ///
            if (max(idx) - min(idx) + 1 != rows(idx)) bad = bad + 1;          ///
            tt = B[idx, 2]; ch = B[idx, 3];                                   ///
            if (min(ch) < 0) bad = bad + 10;                                  ///
            if (rows(idx) > 1) {                                              ///
                if (min(tt[2::rows(tt)] - tt[1::rows(tt) - 1]) <= 0)          ///
                    bad = bad + 100;                                          ///
                if (min(ch[2::rows(ch)] - ch[1::rows(ch) - 1]) < 0)           ///
                    bad = bad + 100;                                          ///
            }                                                                 ///
        };                                                                    ///
        st_local("c5bad", strofreal(bad))
    assert `c5bad' == 0

    * and each block's time range is that stratum's OWN cause-event range
    levelsof s, local(_c5lv)
    foreach _l of local _c5lv {
        quietly summarize t if s == `_l' & status == 1
        assert !missing(r(min), r(max), r(N))
        local _lo = r(min)
        local _hi = r(max)
        mata: B = st_matrix("_c5B");                                       ///
            idx = selectindex(B[., 1] :== strtoreal(st_local("_l")));         ///
            st_local("c5lo", strofreal(min(B[idx, 2])));                      ///
            st_local("c5hi", strofreal(max(B[idx, 2])));                      ///
            st_local("c5n", strofreal(rows(idx)))
        assert `c5lo' == `_lo'
        assert `c5hi' == `_hi'
        * one baseline row per distinct cause-event time in that stratum
        quietly levelsof t if s == `_l' & status == 1, local(_c5tv)
        local _nd : word count `_c5tv'
        assert `c5n' == `_nd'
    }
}
local _rc = _rc
_fgadv_result `_rc' "C5 twenty baseline blocks each carry their own stratum's event times"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C6 bstrata() with cluster() and noadjust, jointly
* -----------------------------------------------------------------------------
* All three are legal together and no suite runs them together. The variance
* contract is checkable exactly rather than approximately: relabelling clusters
* is a permutation of names and must change nothing at all, and StataCorp's
* finite-sample factor is g/(g-1), so the adjusted variance must be the
* unadjusted one times exactly that. Note that mreldif() is useless here -- it
* divides by |y| + 1, so on a variance of 0.005 it reports 6e-5 for a 1.3%
* difference; the ratio is the quantity with meaning.
local ++test_count
capture noisily {
    clear
    set seed 9090
    quietly set obs 400
    gen long cid = 1 + mod(_n, 80)
    gen long id = _n
    gen double x = rnormal()
    gen byte s = 1 + mod(_n, 4)
    gen double u = runiform()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(u < .5, 1, cond(u < .8, 2, 0))
    gen byte anyev = status > 0
    drop u
    quietly stset t, failure(anyev) id(id)

    quietly finegray x, compete(status) cause(1) bstrata(s) cluster(cid) ///
        noadjust nolog
    assert "`e(vce)'" == "cluster"
    assert "`e(vce_meat)'" == "fixed_weight"
    assert "`e(clustvar)'" == "cid"
    assert e(N_clust) == 80
    assert e(k_bstrata) == 4
    matrix _c6b = e(b)
    matrix _c6V = e(V)
    local _G = e(N_clust)

    gen long cid2 = mod(cid * 37 + 11, 80) + 1
    quietly finegray x, compete(status) cause(1) bstrata(s) cluster(cid2) ///
        noadjust nolog
    assert e(N_clust) == 80
    assert mreldif(_c6b, e(b)) == 0
    assert !missing(_c6V[1, 1], e(V)[1, 1])
    assert abs(_c6V[1, 1] - e(V)[1, 1]) < 1e-16

    * the adjustment is exactly g/(g-1) on top of the same meat
    quietly finegray x, compete(status) cause(1) bstrata(s) cluster(cid) nolog
    assert "`e(vce_meat)'" == "fixed_weight"
    assert !missing(e(V)[1, 1])
    assert _c6V[1, 1] > 0
    assert !missing(e(V)[1, 1] / _c6V[1, 1], `_G' / (`_G' - 1))
    assert reldif(e(V)[1, 1] / _c6V[1, 1], `_G' / (`_G' - 1)) < 1e-12
}
local _rc = _rc
_fgadv_result `_rc' "C6 bstrata() + cluster() + noadjust: label-invariant, and adjusted by g/(g-1)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C7  a failure record that is not the subject's last is refused, not silently reduced
* -----------------------------------------------------------------------------
* WATCHED FAIL 2026-09-01.  `stset ..., exit(time .)' lets a subject carry more
* than one _d == 1 record.  finegray's multiple-record reduction keeps the
* record at max(_t) and drops the rest from touse, so a subject whose CAUSE-1
* event at t1 is followed by a COMPETING event at t2 entered the estimation as
* a cause-2 subject: the cause-of-interest failure vanished from the numerator
* and from e(N_fail), at rc 0, with only the routine "records reduced to
* subjects" note on screen.  Measured on the pre-fix build with the fixture
* below: e(N_fail) = 100 against the 200 cause-1 events the data holds.
*
* The fixture is built so the OLD code CONVERGES -- 200 single-record cause-1
* subjects keep the likelihood well posed -- because a fixture that merely
* errors differently proves nothing about a silent drop.
local ++test_count
capture noisily {
    clear
    set seed 20260901
    quietly set obs 200
    gen long id = _n
    gen double x = rnormal()
    * two records: cause 1 at t1, then a competing event at t2
    gen double t1 = 1 + floor(5 * runiform())
    gen double t2 = t1 + 1 + floor(5 * runiform())
    expand 2
    bysort id: gen byte rec = _n
    gen double t0 = cond(rec == 1, 0, t1)
    gen double t  = cond(rec == 1, t1, t2)
    gen byte status = cond(rec == 1, 1, 2)
    * 200 ordinary single-record subjects so the model is identified either way
    quietly count
    local _add = r(N)
    quietly set obs `=`_add' + 200'
    quietly replace id = 1000 + (_n - `_add') if missing(id)
    quietly replace x = rnormal() if missing(x)
    quietly replace t0 = 0 if missing(t0)
    quietly replace t = 1 + floor(8 * runiform()) if missing(t)
    quietly replace status = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0)) ///
        if missing(status)
    quietly replace rec = 1 if missing(rec)
    quietly stset t, failure(status) id(id) time0(t0) exit(time .)
    * the data really does carry two failure records for 200 subjects
    quietly count if _d == 1
    local _nfailrec = r(N)
    quietly bysort id: egen byte _nf = total(_d == 1)
    quietly count if _nf > 1 & rec == 1
    display as text "  fixture: `r(N)' subjects carry more than one failure record"
    assert r(N) == 200
    drop _nf

    capture noisily finegray x, compete(status) cause(1) nolog
    display as text "  multi-failure-record fit rc = `=_rc'"
    assert _rc == 198

    * SECOND SHAPE (independent review 2026-09-01).  ONE failure record, then
    * follow-up continued past it as a censored record.  Counting _d == 1
    * rows per subject does not see this -- there is only one -- yet the
    * reduction keeps the censored record and the subject enters as
    * censored.  Measured on the count-based guard: rc 0, e(N_fail) 161
    * against 197 cause-1 subjects.
    clear
    set seed 20260902
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double t1 = 1 + floor(5 * runiform())
    gen byte s1 = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    expand 2 if s1 == 1 & id <= 60
    bysort id: gen byte rec = _n
    gen double t0 = cond(rec == 1, 0, t1)
    gen double t  = cond(rec == 1, t1, t1 + 3)
    gen byte status = cond(rec == 1, s1, 0)
    quietly stset t, failure(status) id(id) time0(t0) exit(time .)
    quietly bysort id: egen byte _nrec = count(rec)
    quietly count if _nrec > 1 & rec == 1 & _d == 1
    display as text "  fixture: `r(N)' subjects have a failure followed by a censored record"
    assert !missing(r(N))
    assert r(N) > 0
    quietly bysort id: egen byte _nf = total(_d == 1)
    quietly count if _nf > 1
    assert r(N) == 0
    drop _nrec _nf
    capture noisily finegray x, compete(status) cause(1) nolog
    display as text "  failure-then-censored fit rc = `=_rc'"
    assert _rc == 198

    * POSITIVE CONTROL.  An ordinary stsplit multi-record fixture -- one failure
    * per subject spread over several contiguous intervals -- still fits, so the
    * guard refuses recurrent failures and not multiple records as such.
    clear
    set seed 20260901
    quietly set obs 400
    gen long id = _n
    gen double x = rnormal()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(status) id(id)
    quietly stsplit iv, at(2 4 6)
    * stsplit blanks the failure() variable on every non-terminal episode; carry
    * the subject's event type onto all of them, as finegray's own message says
    * to.  _d still marks exactly one terminal failure per subject, which is the
    * property the C7 guard counts.
    quietly bysort id (_t): replace status = status[_N]
    quietly count
    display as text "  stsplit control: `r(N)' records"
    assert !missing(r(N))
    assert r(N) > 400
    capture noisily finegray x, compete(status) cause(1) nolog
    display as text "  stsplit multi-record fit rc = `=_rc'"
    assert _rc == 0
    assert e(N) == 400
    quietly count if _d == 1 & status == 1
    assert e(N_fail) == r(N)
}
local _rc = _rc
capture restore
_fgadv_result `_rc' "C7 failure record not the subject's last (second failure, or follow-up past it) refused r(198); ordinary stsplit multi-record data still fits"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# C8 the constancy and contiguity rules hold at any time scale
* -----------------------------------------------------------------------------
* Through v1.3.0 both rules used an ABSOLUTE 1e-9 band: a covariate that moved
* by 5e-10 within a subject was "constant", and a 5e-10 gap between adjacent
* records was "contiguous" -- true regardless of whether follow-up spanned
* years or 1e-10 of a unit.  Rescale time and a covariate by 1e-10 and both
* refusals must still fire, and a genuinely contiguous dataset on the same
* scale must still fit.
local ++test_count
capture noisily {
    * a covariate that moves within subject, by 5e-10
    clear
    set seed 4242
    quietly set obs 400
    gen long id = ceil(_n / 2)
    bysort id: gen byte epi = _n
    gen double t0 = cond(epi == 1, 0, 1)
    gen double t  = cond(epi == 1, 1, 2)
    gen byte status = 0
    bysort id (epi): replace status = cond(mod(id, 3) == 0, 1, ///
        cond(mod(id, 3) == 1, 2, 0)) if _n == _N
    gen byte fail = status > 0
    gen double z = 0.5 + mod(id, 5) * 0.1
    quietly replace z = z + 5e-10 if epi == 2
    quietly stset t, failure(fail==1) id(id) time0(t0)
    _fgadv_cap `"finegray z, compete(status) cause(1) nolog"' ///
        "covariate z varies within subject"
    assert r(rc) == 198
    assert r(saw) == 1

    * ...and the same 5e-10 move on covariate values of order 1e-10
    quietly replace z = z * 1e-10
    quietly stset t, failure(fail==1) id(id) time0(t0)
    _fgadv_cap `"finegray z, compete(status) cause(1) nolog"' ///
        "covariate z varies within subject"
    assert r(rc) == 198
    assert r(saw) == 1

    * a 5e-10 gap on times of order 1e-10: the gap is FIVE TIMES the whole
    * follow-up, and the absolute band called it contiguous
    quietly replace z = 0.5 + mod(id, 5) * 0.1
    quietly replace t0 = t0 * 1e-10
    quietly replace t  = t * 1e-10
    quietly replace t0 = t0 + 5e-10 if epi == 2
    quietly replace t  = t  + 5e-10 if epi == 2
    quietly stset t, failure(fail==1) id(id) time0(t0)
    _fgadv_cap `"finegray z, compete(status) cause(1) nolog"' ///
        "subject records have gaps or overlaps"
    assert r(rc) == 198
    assert r(saw) == 1

    * ...and a genuinely contiguous dataset on the same 1e-10 scale still fits
    quietly replace t0 = cond(epi == 1, 0, 1) * 1e-10
    quietly replace t  = cond(epi == 1, 1, 2) * 1e-10
    quietly stset t, failure(fail==1) id(id) time0(t0)
    quietly finegray z, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert !missing(e(N))
    assert e(N) > 0
    assert !missing(e(N_fail))
    assert e(N_fail) > 0

    * ...and a DAY-SCALE boundary pair built by two DIFFERENT arithmetic
    * routes must FIT.  Real data reach the same instant along different
    * expressions -- (d2 - o)/365.25 on one record, d2/365.25 - o/365.25 on
    * the next -- and the two doubles differ in their last bits.  A band of a
    * few units in the last place is a rule about rounding, not about
    * follow-up, so the band is 1e-12 RELATIVE: it forgives this and still
    * refuses a gap that is small only in absolute terms.
    sort id epi
    * The later boundary is the one built the LONG way, so the pair is a gap of
    * a few units in the last place rather than an overlap: `stset' drops an
    * overlapping record before finegray ever sees it, which would make the
    * arm measure stset rather than the adjacency rule.
    quietly replace t0 = cond(epi == 1, 0, 1095836/365.25 - 85/365.25)
    quietly replace t  = cond(epi == 1, (1095836 - 85)/365.25, ///
        (2191672 - 85)/365.25)
    * the two routes really are different doubles, so the assertion below is a
    * measurement and not a tautology
    assert t[1] != t0[2]
    assert t0[2] > t[1]
    * stata-dev-ignore: missing-passes-reldif — fail-closed: `assert t[1] != t0[2]' two lines above is false when both are missing (. != . is 0), so this reldif cannot be reached with missing operands
    assert reldif(t[1], t0[2]) < 1e-13
    quietly stset t, failure(fail==1) id(id) time0(t0)
    quietly finegray z, compete(status) cause(1) nolog
    assert e(converged) == 1
    * stata-dev-ignore: missing-passes-assert — fail-closed: `assert e(converged) == 1' on the line above is false when the fit posted nothing (. == 1 is 0), so e(N) here is a posted finite count
    assert e(N) > 0
    * stata-dev-ignore: missing-passes-assert — fail-closed: `assert e(converged) == 1' two lines above is false when the fit posted nothing (. == 1 is 0), so e(N_fail) here is a posted finite count
    assert e(N_fail) > 0

    * a boundary pair a few hundred units in the last place apart -- inside
    * 1e-12 relative, outside the eight-ulp band the rule used to carry --
    * still fits at day scale
    quietly replace t0 = t0 * (1 + 2e-14) if epi == 2
    sort id epi
    assert reldif(t[1], t0[2]) > 1e-15
    * stata-dev-ignore: missing-passes-reldif — fail-closed: `assert reldif(t[1], t0[2]) > 1e-15' on the line above is false when both are missing (reldif(., .) == 0), so this upper bound cannot be reached with missing operands
    assert reldif(t[1], t0[2]) < 1e-12
    quietly stset t, failure(fail==1) id(id) time0(t0)
    quietly finegray z, compete(status) cause(1) nolog
    assert e(converged) == 1

    * a 1e-8 gap at the same scale is 3e-12 relative and is still refused
    quietly replace t0 = cond(epi == 1, 0, 1095836/365.25 - 85/365.25)
    quietly replace t0 = t0 + 1e-8 if epi == 2
    quietly stset t, failure(fail==1) id(id) time0(t0)
    _fgadv_cap `"finegray z, compete(status) cause(1) nolog"' ///
        "subject records have gaps or overlaps"
    assert r(rc) == 198
    assert r(saw) == 1
}
local _rc = _rc
capture restore
_fgadv_result `_rc' "C8 constancy exact and contiguity 1e-12 relative: refusals fire at 1e-10 scale, two arithmetic routes fit at day scale"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* -----------------------------------------------------------------------------
**# Summary
* -----------------------------------------------------------------------------
display "RESULT: test_finegray_adversarial_v130 tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _fgadv130
if `fail_count' > 0 exit 1
exit 0

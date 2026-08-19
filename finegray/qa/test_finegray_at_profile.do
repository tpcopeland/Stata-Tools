* test_finegray_at_profile.do
* at() covariate profiles on factor and interaction designs (shipped in 1.2.0;
* "pre-fix" below means 1.2.0 as of 2026-08-18).
*
*   Through 1.2.0 at() REFUSED a variable that entered an interaction
*   ("grp enters an interaction; set its _fg_* dummies directly"), and a
*   CONTINUOUS variable that entered one was accepted while its interaction
*   columns kept their means: at(x=0) after `finegray i.grp##c.x' returned
*   r(at) = .33333 .33333 0 1.6344536 1.698486 -- a profile no subject can
*   have, reported at rc 0.
*
*   ATP-1..ATP-4 and ATP-7..ATP-8 fail on the pre-fix build.  ATP-5 is the
*   backward-compatibility pin and fails on any "fix" that recomputes columns
*   at() never named: an interaction column's estimation-sample mean is the
*   mean of the PRODUCT, which is not the product of the means (live:
*   1.6344536 against .33333 * 4.9750159 = 1.6583), so a blanket recompute
*   would silently move the default curve of every factor fit.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_at_profile.log", replace name(_atp)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* i.grp##c.x: three-level factor crossed with a continuous covariate.
* e(covariates) = _fg_grp_2 _fg_grp_3 x _fg_grp_2Xx _fg_grp_3Xx
capture program drop _mk_atp
program define _mk_atp
    version 16.0
    clear
    set seed 5150
    quietly set obs 600
    gen long id = _n
    gen byte grp = 1 + mod(_n, 3)
    gen double x = rnormal() + 5
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
end

* i.a##i.b: two binary factors, so all four (a,b) cells are reachable.
* e(covariates) = _fg_a_2 _fg_b_2 _fg_a_2Xb_2
capture program drop _mk_atp_ff
program define _mk_atp_ff
    version 16.0
    clear
    set seed 5150
    quietly set obs 800
    gen long id = _n
    gen byte a = 1 + mod(_n, 2)
    gen byte b = 1 + mod(int(_n / 2), 2)
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
end

**# 1. ATP-1: natural spec == explicit design-column spec [FAILS PRE-FIX]
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    assert "`e(covariates)'" == "_fg_grp_2 _fg_grp_3 x _fg_grp_2Xx _fg_grp_3Xx"

    quietly finegray_cif, at(grp=2 x=10) attime(4) ci nograph
    matrix Z_nat = r(at)
    matrix T_nat = r(table)

    quietly finegray_cif, ///
        at(_fg_grp_2=1 _fg_grp_3=0 x=10 _fg_grp_2Xx=10 _fg_grp_3Xx=0) ///
        attime(4) ci nograph
    matrix Z_exp = r(at)
    matrix T_exp = r(table)

    assert mreldif(Z_nat, Z_exp) < 1e-12
    assert mreldif(T_nat, T_exp) < 1e-12
    * and the profile is the one asked for, not merely self-consistent
    assert Z_nat[1,1] == 1
    assert Z_nat[1,2] == 0
    assert Z_nat[1,3] == 10
    assert Z_nat[1,4] == 10
    assert Z_nat[1,5] == 0
}
if _rc == 0 {
    display as result "  PASS: ATP-1 natural at() equals explicit design columns"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-1 natural/explicit at() disagree (rc=`=_rc')"
    local ++fail_count
}

**# 2. ATP-2: the reference level zeroes the indicator AND its interactions
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    quietly finegray_cif, at(grp=1 x=10) attime(4) nograph
    matrix Z_base = r(at)
    assert Z_base[1,1] == 0
    assert Z_base[1,2] == 0
    assert Z_base[1,3] == 10
    assert Z_base[1,4] == 0
    assert Z_base[1,5] == 0
}
if _rc == 0 {
    display as result "  PASS: ATP-2 base level zeroes indicators and interactions"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-2 base-level profile (rc=`=_rc')"
    local ++fail_count
}

**# 3. ATP-3: a term mixing a set and an unset part holds the unset part at its mean
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    quietly summarize x if e(sample), meanonly
    local _mx = r(mean)
    quietly finegray_cif, at(grp=2) attime(4) nograph
    matrix Z_part = r(at)
    assert Z_part[1,1] == 1
    assert Z_part[1,2] == 0
    assert reldif(Z_part[1,3], `_mx') < 1e-12
    assert reldif(Z_part[1,4], `_mx') < 1e-12
    assert Z_part[1,5] == 0
}
if _rc == 0 {
    display as result "  PASS: ATP-3 unset interaction part held at its mean"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-3 partial profile (rc=`=_rc')"
    local ++fail_count
}

**# 4. ATP-4: continuous setting reaches its interactions [FAILS PRE-FIX]
* Pre-fix this returned .33333 .33333 0 1.6344536 1.698486 -- x pinned to 0
* while grp#c.x stayed at the mean of the product.  The columns grp alone
* drives (1 and 2) are NOT recomputed: at() never named grp, so they keep
* their own estimation-sample means.
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    quietly summarize _fg_grp_2 if e(sample), meanonly
    local _m2 = r(mean)
    quietly summarize _fg_grp_3 if e(sample), meanonly
    local _m3 = r(mean)
    quietly finegray_cif, at(x=0) attime(4) nograph
    matrix Z_x0 = r(at)
    assert reldif(Z_x0[1,1], `_m2') < 1e-12
    assert reldif(Z_x0[1,2], `_m3') < 1e-12
    assert Z_x0[1,3] == 0
    assert Z_x0[1,4] == 0
    assert Z_x0[1,5] == 0
}
if _rc == 0 {
    display as result "  PASS: ATP-4 at(x=0) collapses every column x enters"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-4 continuous interaction profile (rc=`=_rc')"
    local ++fail_count
}

**# 5. ATP-5: no at() is bit-identical to the estimation-sample means
* The one thing standing between this change and a silently different default
* curve for every factor user.  Do not weaken it, and do not update the
* expected values if it fails: element j must equal column j's own mean.
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    local _covs "`e(covariates)'"
    quietly finegray_cif, attime(4) nograph
    matrix Z_def = r(at)
    local _cj = 0
    foreach _cv of local _covs {
        local ++_cj
        quietly summarize `_cv' if e(sample), meanonly
        assert reldif(Z_def[1, `_cj'], r(mean)) < 1e-12
    }
    assert `_cj' == colsof(Z_def)
    * and the interaction column really is the mean of the product, not the
    * product of the means -- otherwise this test could not tell the two apart
    quietly summarize _fg_grp_2 if e(sample), meanonly
    local _pm2 = r(mean)
    quietly summarize x if e(sample), meanonly
    local _pmx = r(mean)
    assert reldif(Z_def[1,4], `_pm2' * `_pmx') > 1e-3

    * same pin on a main-effects-only fit
    _mk_atp
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    local _covs2 "`e(covariates)'"
    quietly finegray_cif, attime(4) nograph
    matrix Z_def2 = r(at)
    local _cj = 0
    foreach _cv of local _covs2 {
        local ++_cj
        quietly summarize `_cv' if e(sample), meanonly
        assert reldif(Z_def2[1, `_cj'], r(mean)) < 1e-12
    }
    assert `_cj' == colsof(Z_def2)
}
if _rc == 0 {
    display as result "  PASS: ATP-5 default profile is the estimation-sample means"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-5 default profile drifted (rc=`=_rc')"
    local ++fail_count
}

**# 6. ATP-6: direct _fg_* overrides work alone, and win over a raw setting
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    quietly summarize _fg_grp_3 if e(sample), meanonly
    local _m3 = r(mean)
    quietly summarize _fg_grp_3Xx if e(sample), meanonly
    local _m3x = r(mean)

    * alone: only the named column moves
    quietly finegray_cif, at(_fg_grp_2=1) attime(4) nograph
    matrix Z_d1 = r(at)
    assert Z_d1[1,1] == 1
    assert reldif(Z_d1[1,2], `_m3') < 1e-12
    assert reldif(Z_d1[1,5], `_m3x') < 1e-12

    * mixed: the direct value wins over what grp=2 x=10 would have implied
    quietly finegray_cif, at(grp=2 x=10 _fg_grp_2Xx=99) attime(4) nograph
    matrix Z_d2 = r(at)
    assert Z_d2[1,1] == 1
    assert Z_d2[1,2] == 0
    assert Z_d2[1,3] == 10
    assert Z_d2[1,4] == 99
    assert Z_d2[1,5] == 0
}
if _rc == 0 {
    display as result "  PASS: ATP-6 direct _fg_* settings applied last and win"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-6 direct design-column override (rc=`=_rc')"
    local ++fail_count
}

**# 7. ATP-7: factor x factor, all four cells [FAILS PRE-FIX]
local ++test_count
capture noisily {
    _mk_atp_ff
    quietly finegray i.a##i.b, compete(ev) cause(1) nolog
    assert "`e(covariates)'" == "_fg_a_2 _fg_b_2 _fg_a_2Xb_2"
    forvalues _ai = 1/2 {
        forvalues _bi = 1/2 {
            quietly finegray_cif, at(a=`_ai' b=`_bi') attime(4) nograph
            matrix Z_ff = r(at)
            assert Z_ff[1,1] == (`_ai' == 2)
            assert Z_ff[1,2] == (`_bi' == 2)
            assert Z_ff[1,3] == (`_ai' == 2) * (`_bi' == 2)
        }
    }
    * partial: b unset sits at its sample proportion, and so does the product
    quietly summarize _fg_b_2 if e(sample), meanonly
    local _pb = r(mean)
    quietly finegray_cif, at(a=2) attime(4) nograph
    matrix Z_fp = r(at)
    assert Z_fp[1,1] == 1
    assert reldif(Z_fp[1,2], `_pb') < 1e-12
    assert reldif(Z_fp[1,3], `_pb') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: ATP-7 factor#factor cells resolve correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-7 factor#factor profile (rc=`=_rc')"
    local ++fail_count
}

**# 8. ATP-8: a truncated interaction column name is reachable by raw name
* Stata's 32-character limit truncates _fg_abcdefghij_group_1000000000Xx to
* _fg_abcdefghij_group_1000000000X, so a consumer that string-builds the
* internal name gets a variable that does not exist.  The raw-variable spec
* does not depend on the name at all.  (A 30-character source name, as in
* test_finegray_postest.do FG-M05, cannot be used here: with an interaction
* the main-effect and interaction names truncate to the SAME 32 characters
* and finegray refuses the fit outright with r(198).)
local ++test_count
capture noisily {
    clear
    set seed 5150
    quietly set obs 800
    gen long id = _n
    gen double abcdefghij_group = cond(mod(_n, 2), 0, 1000000000)
    gen double x = rnormal() + 5
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray i.abcdefghij_group##c.x, compete(ev) cause(1) nolog

    local _c1 : word 1 of `e(covariates)'
    local _c3 : word 3 of `e(covariates)'
    assert length("`_c3'") == 32
    * the name a string-builder would have constructed does not exist
    capture confirm variable _fg_abcdefghij_group_1000000000Xx
    assert _rc != 0

    quietly finegray_cif, at(abcdefghij_group=1000000000 x=3) attime(4) nograph
    matrix Z_tr = r(at)
    quietly finegray_cif, at(`_c1'=1 x=3 `_c3'=3) attime(4) nograph
    matrix Z_te = r(at)
    assert Z_tr[1,1] == 1
    assert Z_tr[1,2] == 3
    assert Z_tr[1,3] == 3
    assert mreldif(Z_tr, Z_te) < 1e-12
    * scientific spelling of the ten-digit level agrees
    quietly finegray_cif, at(abcdefghij_group=1e9 x=3) attime(4) nograph
    assert mreldif(Z_tr, r(at)) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: ATP-8 truncated interaction name reached by raw name"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-8 truncated name resolution (rc=`=_rc')"
    local ++fail_count
}

**# 9. ATP-9: numerically equivalent level spellings agree on the interaction path
* FG-M04's contract.  If anyone reintroduces `real()' into the value path the
* literal token is rendered at about 8 significant digits and these diverge.
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    quietly finegray_cif, at(grp=2 x=10) attime(4) ci nograph
    matrix Z_i = r(at)
    matrix T_i = r(table)
    quietly finegray_cif, at(grp=2.0 x=10) attime(4) ci nograph
    matrix Z_d = r(at)
    matrix T_d = r(table)
    quietly finegray_cif, at(grp=2e0 x=10) attime(4) ci nograph
    matrix Z_s = r(at)
    matrix T_s = r(table)
    assert mreldif(Z_i, Z_d) < 1e-12
    assert mreldif(Z_i, Z_s) < 1e-12
    assert mreldif(T_i, T_d) < 1e-12
    assert mreldif(T_i, T_s) < 1e-12

    * a continuous value must survive with more than 8 significant digits
    quietly finegray_cif, at(grp=2 x=0.33333333333333331) attime(4) nograph
    matrix Z_p = r(at)
    assert reldif(Z_p[1,3], 1/3) < 1e-15
    assert reldif(Z_p[1,4], 1/3) < 1e-15
}
if _rc == 0 {
    display as result "  PASS: ATP-9 equivalent spellings and full precision preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-9 value precision on the interaction path (rc=`=_rc')"
    local ++fail_count
}

**# 10. ATP-10: rejected at() specifications
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    capture finegray_cif, at(grp=99) attime(4) nograph
    assert _rc == 198
    capture finegray_cif, at(nosuchvar=1) attime(4) nograph
    assert _rc == 198
    capture finegray_cif, at(grp=abc) attime(4) nograph
    assert _rc == 198
    capture finegray_cif, at(grp) attime(4) nograph
    assert _rc == 198
    capture finegray_cif, at(grp=1 grp=2) attime(4) nograph
    assert _rc == 198
    capture finegray_cif, at(x=.) attime(4) nograph
    assert _rc == 198
    * a duplicate direct design column is refused too
    capture finegray_cif, at(_fg_grp_2=1 _fg_grp_2=0) attime(4) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: ATP-10 malformed at() specifications refused"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-10 at() error paths (rc=`=_rc')"
    local ++fail_count
}

**# 11. ATP-11: the ci path reads the same profile
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    quietly finegray_cif, at(grp=2 x=10) attime(1 4 7) ci nograph
    matrix T_cn = r(table)
    quietly finegray_cif, ///
        at(_fg_grp_2=1 _fg_grp_3=0 x=10 _fg_grp_2Xx=10 _fg_grp_3Xx=0) ///
        attime(1 4 7) ci nograph
    matrix T_ce = r(table)
    * columns 4 and 5 of r(table) are lci and uci
    forvalues _r = 1/3 {
        assert reldif(T_cn[`_r', 4], T_ce[`_r', 4]) < 1e-12
        assert reldif(T_cn[`_r', 5], T_ce[`_r', 5]) < 1e-12
    }
    assert mreldif(T_cn, T_ce) < 1e-12
    * and the influence-function SE is real, so the comparison is not vacuous
    assert T_cn[2, 3] > 0 & T_cn[2, 3] < .
}
if _rc == 0 {
    display as result "  PASS: ATP-11 ci limits agree on natural and explicit specs"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-11 ci path profile (rc=`=_rc')"
    local ++fail_count
}

**# 12. ATP-12: the rebuild path and the profile path agree, and leak nothing
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    quietly finegray_cif, at(grp=2 x=10) attime(4) ci nograph
    matrix Z_keep = r(at)
    matrix T_keep = r(table)

    drop _fg_*
    quietly finegray_cif, at(grp=2 x=10) attime(4) ci nograph
    matrix Z_reb = r(at)
    matrix T_reb = r(table)

    assert mreldif(Z_keep, Z_reb) < 1e-12
    assert mreldif(T_keep, T_reb) < 1e-12
    * read-only: no rebuilt column may be left behind
    capture confirm variable _fg_grp_2
    assert _rc != 0
    capture confirm variable _fg_grp_2Xx
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: ATP-12 rebuild path matches and leaves no columns"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-12 rebuild/profile agreement (rc=`=_rc')"
    local ++fail_count
}

**# 13. ATP-13: a non-factor fit is unaffected
local ++test_count
capture noisily {
    clear
    set seed 5150
    quietly set obs 800
    gen long id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x1 x2, compete(ev) cause(1) nolog
    assert `"`e(fvsemantic)'"' == "" | `"`e(fvsemantic)'"' == "."
    quietly finegray_cif, at(x1=0 x2=1) attime(4) nograph
    matrix Z_nf = r(at)
    assert Z_nf[1,1] == 0
    assert Z_nf[1,2] == 1
    capture finegray_cif, at(zz=1) attime(4) nograph
    assert _rc == 198
    quietly finegray_cif, attime(4) nograph
    matrix Z_nfd = r(at)
    quietly summarize x1 if e(sample), meanonly
    assert reldif(Z_nfd[1,1], r(mean)) < 1e-12
    quietly summarize x2 if e(sample), meanonly
    assert reldif(Z_nfd[1,2], r(mean)) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: ATP-13 non-factor fit unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-13 non-factor at() path (rc=`=_rc')"
    local ++fail_count
}

**# 14. ATP-14: _finegray_fv_design publishes the decomposition
* r() is one shared queue: every return must be read before the next command
* runs, which is exactly the failure mode finegray_cif's copy loop guards.
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray i.grp##c.x, compete(ev) cause(1) nolog
    _finegray_fv_design, caller(test_finegray_at_profile)
    local _k    = r(k)
    local _raw  "`r(rawvars)'"
    local _fv   "`r(fvars)'"
    local _p1   "`r(pieces1)'"
    local _p3   "`r(pieces3)'"
    local _p4   "`r(pieces4)'"
    local _p5   "`r(pieces5)'"
    assert `_k' == 5
    assert "`_raw'" == "grp x"
    assert "`_fv'"  == "grp"
    assert "`_p1'"  == "grp:2"
    assert "`_p3'"  == "x"
    assert "`_p4'"  == "grp:2 x"
    assert "`_p5'"  == "grp:3 x"
}
if _rc == 0 {
    display as result "  PASS: ATP-14 fv_design returns rawvars/fvars/pieces#"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-14 fv_design decomposition (rc=`=_rc')"
    local ++fail_count
}

**# 15. ATP-15: ibn. inside an interaction keeps every level
* ibn. omits no reference, so `1bn.grp#c.x' carries a real coefficient and
* must NOT be filtered out as a base term.  The design is three columns, one
* per level, and at(grp=2 x=10) must light exactly one of them.
local ++test_count
capture noisily {
    _mk_atp
    quietly finegray ibn.grp#c.x, compete(ev) cause(1) nolog
    assert "`e(covariates)'" == "_fg_grp_1Xx _fg_grp_2Xx _fg_grp_3Xx"

    quietly finegray_cif, at(grp=2 x=10) attime(4) nograph
    matrix Z_bn = r(at)
    assert Z_bn[1,1] == 0
    assert Z_bn[1,2] == 10
    assert Z_bn[1,3] == 0

    * x alone: each column collapses to its level's sample proportion times 10
    quietly summarize _fg_grp_1Xx if e(sample), meanonly
    local _bn1 = r(mean)
    quietly count if e(sample)
    local _bnn = r(N)
    quietly count if e(sample) & grp == 1
    local _bnp = r(N) / `_bnn'
    quietly finegray_cif, at(x=10) attime(4) nograph
    matrix Z_bx = r(at)
    assert reldif(Z_bx[1,1], `_bnp' * 10) < 1e-12
    * and that is NOT the untouched mean, so the assertion has content
    assert reldif(Z_bx[1,1], `_bn1') > 1e-3
}
if _rc == 0 {
    display as result "  PASS: ATP-15 ibn. interaction levels resolve"
    local ++pass_count
}
else {
    display as error "  FAIL: ATP-15 ibn. interaction profile (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_at_profile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _atp
    exit 1
}
display as result "ALL TESTS PASSED"
log close _atp

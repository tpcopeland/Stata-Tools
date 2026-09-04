* test_finegray_cif_overflow.do
* exp(xb) overflow at a finite covariate profile (FG-A02, 2026-09-04 error
* report), across finegray_cif (analytic and bootstrap), finegray_predict,
* and the piecewise tvc() paths.
*
*   Through 1.3.0 a profile whose exp(z'b) exceeded double precision --
*   at(x=-20000) on a fit with a negative coefficient -- made rstar missing
*   in _finegray_cif_core; the missing value propagated into the CIF and the
*   influence vector, and colsum() treated the missing contributions as
*   zeros, so finegray_cif posted (cif, se) = (., 0) at rc 0: an unusable
*   point estimate with a fabricated zero SE.  finegray_predict, cif on the
*   same profile produced missing values, and in the piecewise CIF an
*   overflowed interval was dropped from Lambda by rowsum().
*
*   Contract now: with a finite linear predictor the CIF is evaluated to its
*   double-precision limit -- Lambda above maxdouble means exp(-Lambda) = 0,
*   CIF = 1, and the influence factor exp(xb - Lambda) = 0 gives SE 0, the
*   same answer the shipped arithmetic returns one step short of the overflow
*   (x=-800 on the same fit) -- and H0 = 0 means CIF = 0 however large xb is.
*   A nonfinite linear predictor is refused, never posted.
*
*   OV-1, OV-2, OV-4, OV-5, OV-7 and OV-8 fail on the pre-fix build; OV-3,
*   OV-6 and OV-9 are the finite positive controls and refusal pin.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_cif_overflow.log", replace name(_fgov)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Report fixture: 100 cause-1 events at .1000000000000001, 100 competing
* events at 1, seeded continuous x.  Fitted SHR .9364694 (beta < 0), so a
* very negative x drives exp(xb) past maxdouble.
capture program drop _mk_ov
program define _mk_ov
    version 16.0
    clear
    quietly set obs 200
    gen long id = _n
    gen double t = cond(_n <= 100, .1000000000000001, 1)
    gen byte status = cond(_n <= 100, 1, 2)
    set seed 87421
    gen double x = rnormal()
    quietly stset t, failure(status==1 2) id(id)
    quietly finegray x, compete(status) cause(1) nolog
end

* Piecewise fixture: cause events on both sides of the tsplit() cut.
capture program drop _mk_ov_tvc
program define _mk_ov_tvc
    version 16.0
    clear
    quietly set obs 300
    set seed 2026
    gen long id = _n
    gen double x = rnormal()
    gen double t = runiform() * 2
    gen byte status = 1 + (runiform() > .5)
    quietly stset t, failure(status==1 2) id(id)
    quietly finegray x, compete(status) cause(1) tvc(x) tsplit(1) nolog
end

* OV-1: the reported row.  CIF exactly 1, SE exactly 0, no limits, rc 0.
local ++test_count
capture noisily {
    _mk_ov
    assert _b[x] < 0
    finegray_cif, at(x=-20000) attime(1) ci nograph
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 1
    assert `T'[1,1] == 1
    assert !missing(`T'[1,2], `T'[1,3])
    assert `T'[1,2] == 1
    assert `T'[1,3] == 0
    assert missing(`T'[1,4]) & missing(`T'[1,5])
}
if _rc == 0 {
    display as result "  PASS: OV-1 overflowing profile: CIF 1, SE 0, no limits, never missing"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-1 overflowing profile (rc=`=_rc')"
    local ++fail_count
}

* OV-2: finite positive control one step short of the overflow gives the
* identical row, so the overflow branch reproduces the arithmetic's limit.
local ++test_count
capture noisily {
    _mk_ov
    finegray_cif, at(x=-800) attime(1) ci nograph
    tempname A
    matrix `A' = r(table)
    assert !missing(`A'[1,2], `A'[1,3])
    assert `A'[1,2] == 1
    assert `A'[1,3] == 0
    finegray_cif, at(x=-20000) attime(1) ci nograph
    tempname B
    matrix `B' = r(table)
    assert !missing(`B'[1,2], `B'[1,3])
    assert `A'[1,2] == `B'[1,2]
    assert `A'[1,3] == `B'[1,3]
}
if _rc == 0 {
    display as result "  PASS: OV-2 x=-800 (finite) and x=-20000 (overflow) give the same row"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-2 finite positive control (rc=`=_rc')"
    local ++fail_count
}

* OV-3: interior positive control: a real CIF with a real SE and limits, and
* equal to the default-grid value at the same horizon.
local ++test_count
capture noisily {
    _mk_ov
    finegray_cif, at(x=0) nograph
    tempname G
    matrix `G' = r(table)
    finegray_cif, at(x=0) attime(1) ci nograph
    tempname T
    matrix `T' = r(table)
    assert !missing(`T'[1,2], `T'[1,3], `T'[1,4], `T'[1,5], `G'[1,2])
    assert `T'[1,2] > 0 & `T'[1,2] < 1
    assert `T'[1,3] > 0
    assert `T'[1,4] < `T'[1,2] & `T'[1,2] < `T'[1,5]
    assert !missing(`T'[1,2], `G'[1,2])
    assert reldif(`T'[1,2], `G'[1,2]) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: OV-3 interior profile unchanged: CIF in (0,1), SE > 0, limits bracket"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-3 interior control (rc=`=_rc')"
    local ++fail_count
}

* OV-4: the bootstrap on the overflowing profile.  Every replication's CIF
* is finite (each refit's own overflow evaluates to 0 or 1), so the SD is a
* number and the point CIF is 1.
local ++test_count
capture noisily {
    _mk_ov
    finegray_cif, at(x=-20000) attime(.05 1) ci nograph bootstrap(25) seed(1)
    tempname T
    matrix `T' = r(table)
    assert rowsof(`T') == 2
    assert !missing(`T'[1,2], `T'[1,3], `T'[2,2], `T'[2,3])
    assert `T'[1,2] == 0
    assert `T'[2,2] == 1
    assert `T'[2,3] >= 0
    assert r(bootstrap_success) == 25
}
if _rc == 0 {
    display as result "  PASS: OV-4 bootstrap on the overflowing profile posts a finite SD and CIF 1"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-4 bootstrap at overflow (rc=`=_rc')"
    local ++fail_count
}

* OV-5: finegray_predict, cif on the overflowing profile: exactly 1 after
* the first cause event, and exactly 0 before it (H0 = 0, where Stata's
* 0 * missing is missing).
local ++test_count
capture noisily {
    _mk_ov
    gen double h1 = 1
    gen double h0 = .05
    replace x = -20000
    finegray_predict double p1, cif timevar(h1)
    finegray_predict double p0, cif timevar(h0)
    assert !missing(p1, p0) if e(sample)
    assert p1 == 1 if e(sample)
    assert p0 == 0 if e(sample)
}
if _rc == 0 {
    display as result "  PASS: OV-5 predict cif at overflow: 1 after the first event, 0 before it"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-5 predict cif at overflow (rc=`=_rc')"
    local ++fail_count
}

* OV-6: predict cif ci on the fitted data is unchanged (finite interior CIF,
* SE and limits).  The ci path scores e(sample) rows only and refuses a
* changed estimation sample (rc 459), and an in-sample linear predictor is
* bounded by the fit, so the influence-function SE cannot meet the overflow
* through predict; the overflow branch of that engine is exercised by
* finegray_cif in OV-1/OV-2.
local ++test_count
capture noisily {
    _mk_ov
    gen double h1 = 1
    finegray_predict double q, cif ci timevar(h1)
    assert !missing(q, q_lci, q_uci) if e(sample)
    assert q > 0 & q < 1 if e(sample)
    assert q_lci < q & q < q_uci if e(sample)
    finegray_cif, at(x=0) attime(1) ci nograph
    tempname T
    matrix `T' = r(table)
    assert !missing(`T'[1,2], `T'[1,3])
    * x = 0 is not a data row, so check the identity at a row's own x:
    * predict there equals finegray_cif at that profile.
    quietly summarize x if e(sample), meanonly
    local x1 = r(min)
    finegray_cif, at(x=`x1') attime(1) ci nograph
    matrix `T' = r(table)
    * `x1' holds 16 significant digits of the row's x, so match the row by
    * reldif rather than equality; the 1e-16 profile difference is far
    * inside the tolerances below.
    quietly summarize q if e(sample) & reldif(x, `x1') < 1e-13, meanonly
    assert r(N) == 1
    assert !missing(r(mean), `T'[1,2])
    assert reldif(r(mean), `T'[1,2]) < 1e-10
    quietly summarize q_lci if e(sample) & reldif(x, `x1') < 1e-13, meanonly
    assert !missing(r(mean), `T'[1,4])
    assert reldif(r(mean), `T'[1,4]) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: OV-6 predict cif ci on the fitted data agrees with finegray_cif"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-6 predict cif ci (rc=`=_rc')"
    local ++fail_count
}

* OV-7: the piecewise (tvc) CIF at an overflowing profile: (1, 0) in
* finegray_cif, 1 / 0 in predict, and a finite bootstrap SD.
local ++test_count
capture noisily {
    _mk_ov_tvc
    local xo = cond(_b[x] < 0, 20000, -20000)
    local xo = -`xo'
    * `xo' now has the sign that makes exp(x * beta_1) overflow; the second
    * interval's coefficient may differ in sign, so also check both signs.
    foreach v in -20000 20000 {
        finegray_cif, at(x=`v') attime(.5 1.5) ci nograph
        tempname T
        matrix `T' = r(table)
        assert rowsof(`T') == 2
        assert !missing(`T'[1,2], `T'[1,3], `T'[2,2], `T'[2,3])
        assert `T'[1,2] == 0 | `T'[1,2] == 1
        assert `T'[2,2] == 0 | `T'[2,2] == 1
        assert `T'[2,2] >= `T'[1,2]
        assert `T'[1,3] == 0 & `T'[2,3] == 0
    }
    finegray_cif, at(x=0) attime(.5 1.5) ci nograph
    tempname C
    matrix `C' = r(table)
    assert !missing(`C'[1,2], `C'[1,3], `C'[2,2], `C'[2,3])
    assert `C'[1,2] > 0 & `C'[2,2] < 1 & `C'[2,2] > `C'[1,2]
    assert `C'[1,3] > 0 & `C'[2,3] > 0
    finegray_cif, at(x=`xo') attime(1.5) ci nograph bootstrap(25) seed(3)
    tempname B
    matrix `B' = r(table)
    assert !missing(`B'[1,2], `B'[1,3])
    assert `B'[1,2] == 1
    assert `B'[1,3] >= 0
    * Point predictions score the caller's data, so the profile can be
    * written into x here (the bootstrap above needed the fitted data).
    gen double h1 = 1.5
    quietly summarize _t if _d & status == 1, meanonly
    gen double h0 = r(min) / 2
    replace x = `xo'
    finegray_predict double p1, cif timevar(h1)
    finegray_predict double p0, cif timevar(h0)
    assert !missing(p1, p0) if e(sample)
    assert p1 == 1 if e(sample)
    assert p0 == 0 if e(sample)
}
if _rc == 0 {
    display as result "  PASS: OV-7 tvc() piecewise CIF at overflow: (1, 0), predict 1/0, finite bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-7 tvc() overflow (rc=`=_rc')"
    local ++fail_count
}

* OV-8: predict xb is finite at the overflowing profile (the linear predictor
* itself does not overflow), so the CIF's 1 is the exp() of a finite number
* and not the artefact of a missing input.
local ++test_count
capture noisily {
    _mk_ov
    replace x = -20000
    finegray_predict double xb, xb
    assert !missing(xb) if e(sample)
    assert xb > 709 if e(sample)
    gen double h1 = 1
    finegray_predict double p1, cif timevar(h1)
    assert !missing(p1) if e(sample)
    assert p1 == 1 if e(sample)
}
if _rc == 0 {
    display as result "  PASS: OV-8 finite xb beyond exp()'s range still yields CIF 1"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-8 finite xb control (rc=`=_rc')"
    local ++fail_count
}

* OV-9: a nonfinite profile is refused, not evaluated.
local ++test_count
capture noisily {
    _mk_ov
    * A failed rclass command leaves the previous r() standing, so clear it
    * with an rclass command that posts no r(table) before the refusal.
    quietly summarize x
    capture finegray_cif, at(x=.) attime(1) nograph
    assert _rc != 0
    * r(table) in an expression is a missing scalar when absent, so ask
    * whether the matrix exists rather than copy it.
    capture matrix list r(table)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: OV-9 at(x=.) is refused with nothing posted"
    local ++pass_count
}
else {
    display as error "  FAIL: OV-9 nonfinite profile refusal (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_cif_overflow tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgov
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgov

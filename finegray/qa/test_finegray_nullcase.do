* test_finegray_nullcase.do
* Degenerate-artifact (fail-open) contracts: Critical Rules 14 and 15.
*
* Every block here supplies a DEGENERATE artifact -- an input that is
* well-formed enough to travel the whole command and produce nothing -- and
* requires a nonzero return code.  A well-formed fixture cannot reach these
* paths, which is exactly why they shipped: the suite's 60 other files all
* build data the commands can answer.
*
* THE COMMIT CONTRACT (Rule 15).  `touse' non-empty is not the same fact as
* "the result has a value on any row".  finegray_predict guards the first at
* finegray_predict.ado:374 and, before this file, never counted the second.
* Measured on the pre-fix build (webuse hypoxia, n = 109):
*
*   finegray_predict nc_cif, cif   after `replace ifp = .'
*       -> rc 0, nc_cif created, 0 of 109 non-missing
*   finegray_predict nc_p, cif ci timevar(t), t below the first cause event
*       -> rc 0, nc_p identically 0, nc_p_lci and nc_p_uci 0 of 109 non-missing
*
* Both now exit 2000 and, because the committed names are registered in
* `_created_vars' before the check, leave the dataset exactly as it was.  Each
* refusal is paired with a POSITIVE CONTROL on the same command and fixture, so
* a guard that refuses everything fails this file rather than passing it.
*
* THE RESOLVE CONTRACT (Rule 14) is not exercised here, and that is a finding
* rather than an omission: no finegray command takes an explicitly named
* source.  There is no using(), no named bundle and no frame() anywhere in the
* package (checked across all 14 `syntax' statements), so every post-estimation
* command is an AMBIENT request against the active e() and its emptiness
* fallbacks are the legitimate branch of Rule 14, not the defective one.  The
* one place a named source could be crossed with ambient state -- the baseline
* curve -- already fails closed on identity rather than on emptiness:
* _finegray_resolve_baseline keys the Mata cache by e(bh_key) and refuses a
* mismatch, and its rebuild branch is the only one that reads the data and the
* only one that verifies them.  NC-5 pins that refusal so the contract cannot
* quietly become a fallback.

version 16.0

capture log close _all
log using "test_finegray_nullcase.log", replace name(_fgnull)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

program define _finegray_use_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
end

program define _mk_nullcase
    _finegray_use_hypoxia
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

display as text _newline "test_finegray_nullcase: fail-open contracts"

**# NC-1: cif on rows where every scoring covariate is missing
* The linear predictor is matrix-scored from the caller's data, so a covariate
* that is missing on every prediction row makes every CIF missing.  `touse' is
* full, the baseline resolves from the warm cache, nothing errors.
local ++test_count
capture noisily {
    _mk_nullcase
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly replace ifp = .
    capture noisily finegray_predict nc_cif, cif
    local nc1_rc = _rc
    display as text "  NC-1 rc = `nc1_rc' (expected 2000)"
    assert `nc1_rc' == 2000
    * fail CLOSED, not half-open: the refused variable must not be left behind
    capture confirm variable nc_cif
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: NC-1 all-missing covariate refuses the cif commit"
    local ++pass_count
}
else {
    display as error "  FAIL: NC-1 cif commit contract (rc=`=_rc')"
    local ++fail_count
}

**# NC-1p: positive control for NC-1 on the same command and fixture
local ++test_count
capture noisily {
    _mk_nullcase
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict nc_cif_ok, cif
    quietly count if !missing(nc_cif_ok)
    local nc1p_n = r(N)
    display as text "  NC-1p non-missing cif values = `nc1p_n' of `=_N'"
    assert `nc1p_n' == e(N)
    quietly summarize nc_cif_ok
    * stata-dev-ignore: missing-passes-assert — fail-closed: `assert `nc1p_n' == e(N)' above, where `nc1p_n' counts !missing(nc_cif_ok), already refuses an all-missing column
    assert r(min) >= 0 & r(max) <= 1 & r(max) > 0
    drop nc_cif_ok
}
if _rc == 0 {
    display as result "  PASS: NC-1p intact covariates still commit a usable cif"
    local ++pass_count
}
else {
    display as error "  FAIL: NC-1p cif positive control (rc=`=_rc')"
    local ++fail_count
}

**# NC-2: cif ci at a horizon before the first cause event
* CIF is identically 0 there, so g = ln(-ln(1-CIF)) is undefined on every row
* and both limits come back missing.  A row-wise missing limit is deliberate
* (v1.1.0 refused to collapse it onto the point estimate); ALL of them missing
* is not a confidence interval.
local ++test_count
capture noisily {
    _mk_nullcase
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly summarize _t if _d == 1, meanonly
    local nc2_first = r(min)
    gen double nc_t = `nc2_first' / 10
    display as text "  NC-2 horizon `=nc_t[1]' precedes first event time `nc2_first'"
    capture noisily finegray_predict nc_p, cif ci timevar(nc_t)
    local nc2_rc = _rc
    display as text "  NC-2 rc = `nc2_rc' (expected 2000)"
    assert `nc2_rc' == 2000
    * the point estimate is dropped with its limits: a refused ci call must not
    * leave a bare cif column behind that the user might read as the answer
    foreach v in nc_p nc_p_lci nc_p_uci {
        capture confirm variable `v'
        assert _rc == 111
    }
}
if _rc == 0 {
    display as result "  PASS: NC-2 degenerate CIF refuses the confidence-limit commit"
    local ++pass_count
}
else {
    display as error "  FAIL: NC-2 ci commit contract (rc=`=_rc')"
    local ++fail_count
}

**# NC-2p: positive control for NC-2 at a horizon the data can answer
local ++test_count
capture noisily {
    _mk_nullcase
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double nc_t_ok = 5
    finegray_predict nc_q, cif ci timevar(nc_t_ok)
    quietly count if !missing(nc_q_lci)
    local nc2p_l = r(N)
    quietly count if !missing(nc_q_uci)
    local nc2p_u = r(N)
    display as text "  NC-2p non-missing limits: lci = `nc2p_l', uci = `nc2p_u'"
    assert `nc2p_l' > 0 & `nc2p_u' > 0
    quietly count if nc_q_lci <= nc_q & nc_q <= nc_q_uci & !missing(nc_q_lci)
    assert r(N) == `nc2p_l'
    drop nc_q nc_q_lci nc_q_uci nc_t_ok
}
if _rc == 0 {
    display as result "  PASS: NC-2p an answerable horizon still commits both limits"
    local ++pass_count
}
else {
    display as error "  FAIL: NC-2p ci positive control (rc=`=_rc')"
    local ++fail_count
}

**# NC-3: the guard itself has teeth in both directions
* A contract enforced by a helper is only as good as the helper.  Zero usable
* values must exit 2000, a short count 459, a usable count must return r(N),
* and allowzero must permit the documented empty case -- otherwise the guard
* either never fires or fires on everything.
local ++test_count
capture noisily {
    clear
    quietly set obs 10
    gen double all_missing = .
    gen double half_there = cond(mod(_n, 2), 1.5, .)
    gen byte in_sample = (_n <= 4)

    capture _finegray_assert_cardinality all_missing
    display as text "  NC-3 zero usable rc = `=_rc' (expected 2000)"
    assert _rc == 2000

    capture _finegray_assert_cardinality all_missing, allowzero
    assert _rc == 0
    assert r(N) == 0

    _finegray_assert_cardinality half_there
    assert r(N) == 5

    _finegray_assert_cardinality half_there, touse(in_sample)
    assert r(N) == 2

    capture _finegray_assert_cardinality half_there 6
    display as text "  NC-3 short-count rc = `=_rc' (expected 459)"
    assert _rc == 459

    _finegray_assert_cardinality half_there 5
    assert r(N) == 5 & r(expected) == 5
}
if _rc == 0 {
    display as result "  PASS: NC-3 cardinality guard fires on empty and passes content"
    local ++pass_count
}
else {
    display as error "  FAIL: NC-3 cardinality guard (rc=`=_rc')"
    local ++fail_count
}

**# NC-4: the subject-level reduction commits a counted sample
* finegray.ado counts the subjects the multiple-record reduction KEEPS before
* it narrows `touse', and refuses an empty result.  No degenerate input reaches
* that refusal -- the emptiness guard upstream already requires a marked
* record, and reducing a non-empty sample cannot produce none -- so this block
* is a positive control only, and says so rather than claiming a RED it cannot
* produce.  What it pins is that the count committed as e(N) is the SUBJECT
* count and not the record count.
local ++test_count
capture noisily {
    clear
    set seed 20260904
    quietly set obs 120
    gen long id = _n
    * covariates are subject-level, and the event is carried by the LAST record
    * only: finegray refuses a covariate that varies within id(), and refuses
    * data whose failure record is not the subject's last.
    gen double x = rnormal()
    gen double _u = runiform()
    gen byte _ev_final = cond(_u < 0.45, 1, cond(_u < 0.70, 2, 0))
    gen double _dur = 3.01 + 2*runiform()
    quietly expand 2
    by id, sort: gen byte rec = _n
    gen double _start = cond(rec == 1, 0, 3)
    gen double _stop = cond(rec == 1, 3, _dur)
    gen byte ev = cond(rec == 2, _ev_final, 0)
    * the stset failure indicator marks ANY event; compete() names its type,
    * which is the convention every finegray fixture in this suite follows.
    gen byte anyev = (ev != 0)
    stset _stop, failure(anyev==1) id(id) time0(_start)
    quietly finegray x, compete(ev) cause(1) nolog
    local nc4_n = e(N)
    quietly levelsof id if e(sample), local(nc4_ids)
    local nc4_k : word count `nc4_ids'
    display as text "  NC-4 e(N) = `nc4_n', distinct subjects = `nc4_k', records = 240"
    assert `nc4_n' == `nc4_k'
    assert `nc4_n' > 0 & `nc4_n' < 240
}
if _rc == 0 {
    display as result "  PASS: NC-4 reduction commits the counted subject sample"
    local ++pass_count
}
else {
    display as error "  FAIL: NC-4 reduction cardinality (rc=`=_rc')"
    local ++fail_count
}

**# NC-5: the baseline resolves by identity, never by ambient availability
* Rule 14 in the one place finegray could cross a named source with ambient
* state.  With the estimation data gone AND the Mata cache cleared there is no
* baseline to answer from, and the command must say so instead of rebuilding
* one from whatever is now in memory.
local ++test_count
capture noisily {
    _mk_nullcase
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    * a fresh dataset with the same covariate names but no estimation sample
    clear
    quietly set obs 5
    gen double ifp = 20
    gen double tumsize = 5
    gen byte pelnode = 0
    gen double nc_h = 3
    mata: mata clear
    capture noisily finegray_predict nc_r, cif timevar(nc_h)
    local nc5_rc = _rc
    display as text "  NC-5 rc = `nc5_rc' (expected 459)"
    assert `nc5_rc' == 459
    capture confirm variable nc_r
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: NC-5 an unresolvable baseline is refused, not rebuilt from ambient data"
    local ++pass_count
}
else {
    display as error "  FAIL: NC-5 baseline resolve contract (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_nullcase tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgnull
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgnull

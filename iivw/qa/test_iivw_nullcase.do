clear all
version 16.0
set varabbrev off

* test_iivw_nullcase.do - degenerate-artifact (fail-open) contracts
*
* IIVW-02 (2026-09-02 audit): with allowmissingweights, a run whose visit model
* and treatment model had DISJOINT complete-case sets produced an all-missing
* final weight, and iivw_weight committed its signed _iivw_ contract and
* returned ordinary success:
*
*     240 of 240 observations have no weight
*     DISJOINT_FIPTIW_RC=0
*     DISJOINT_FIPTIW_N_WEIGHTED=0
*
* test_iivw_sample_contract.do T7 does not reach this path: an all-missing
* visit covariate makes the nuisance model fail before final-weight assembly,
* so the guard under test is never exercised. Here both nuisance models fit and
* only their intersection is empty.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_nullcase.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_nullcase.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _iivw_nc_disjoint
program define _iivw_nc_disjoint
    * 60 subjects, 4 visits each. The visit-model covariate is observed only on
    * subjects 1-30 and the treatment-model covariate only on subjects 31-60,
    * so both models fit on their own complete cases and no row can receive a
    * final FIPTIW weight. baseline(event) keeps the first visit inside the
    * visit model: under the default baseline(entry) every first visit is
    * handed a study-entry intensity weight of exactly 1, which would leave 30
    * rows weighted and hide the all-missing case under test.
    version 16.0
    args mode split

    if "`mode'" == "" local mode "disjoint"
    if "`split'" == "" local split 30
    clear
    set seed 20260903
    set obs 60
    gen long id = _n
    gen double Lvisit = rnormal()
    gen double Ztreat = rnormal()
    gen byte treat = runiform() < invlogit(0.3 + 0.6 * Ztreat)
    gen double fu_end = 22
    expand 4
    bysort id: gen int k = _n
    gen double time = k * 4 + runiform() * 2
    if "`mode'" == "disjoint" {
        quietly replace Lvisit = . if id > `split'
        quietly replace Ztreat = . if id <= `split'
    }
end

**## N1 nullcase: zero usable weights is refused even with allowmissingweights
* Both nuisance models fit; their complete-case sets do not overlap. The old
* code reported "240 of 240 observations have no weight" and returned 0.
local ++test_count
capture noisily {
    _iivw_nc_disjoint disjoint 30
    capture noisily iivw_weight, id(id) time(time) treat(treat) ///
        treat_cov(Ztreat) visit_cov(Lvisit) wtype(fiptiw) censor(fu_end) ///
        baseline(event) allowmissingweights nolog
    local n1_rc = _rc
    display as text "    disjoint FIPTIW rc=`n1_rc'"
    if `n1_rc' == 0 {
        display as error "  commit contract: an all-missing weight variable was committed at rc 0"
        error 9
    }
    * A refused weighting must not leave a signed contract behind.
    local n1_weighted : char _dta[_iivw_weighted]
    if "`n1_weighted'" == "1" {
        display as error "  commit contract: the refused run still stamped _iivw_weighted"
        error 9
    }
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N1 zero usable weights refused before commit"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 zero usable weights (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N1"
}

**## N2 nullcase: partial loss with the acknowledgment still succeeds
* Positive control for N1: allowmissingweights must keep meaning "some rows",
* so the fix must not turn every complete-case analysis into an error.
local ++test_count
capture noisily {
    _iivw_nc_disjoint complete
    quietly replace Ztreat = . if id <= 5
    capture noisily iivw_weight, id(id) time(time) treat(treat) ///
        treat_cov(Ztreat) visit_cov(Lvisit) wtype(fiptiw) censor(fu_end) ///
        baseline(event) allowmissingweights nolog
    local n2_rc = _rc
    display as text "    partial-loss FIPTIW rc=`n2_rc'"
    assert `n2_rc' == 0
    quietly count if !missing(_iivw_weight)
    local n2_weighted = r(N)
    display as text "    weighted rows=`n2_weighted'"
    assert `n2_weighted' > 0
    quietly count if missing(_iivw_weight)
    assert !missing(r(N))
    assert r(N) > 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N2 partial loss with the acknowledgment still succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 partial loss (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N2"
}

**## N3 nullcase: _iivw_assert_cardinality helper contract
local ++test_count
capture noisily {
    clear
    set obs 50
    gen double allmiss = .
    gen double partial = cond(_n <= 10, 1, .)
    gen byte insample = (_n <= 30)

    capture _iivw_assert_cardinality allmiss
    assert _rc == 2000
    capture _iivw_assert_cardinality allmiss, allowzero
    assert _rc == 0
    capture _iivw_assert_cardinality partial 25
    assert _rc == 459
    capture _iivw_assert_cardinality partial 10
    assert _rc == 0
    quietly _iivw_assert_cardinality partial, touse(insample)
    assert r(N) == 10
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N3 cardinality helper contract"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 cardinality helper contract (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N3"
}

* Poster for the iivw_diagnose null cases below. Two variants, one flag apart:
* the degenerate one omits e(depvar) exactly as a hand-posted estimate does.
capture program drop _iivw_nc_post
program define _iivw_nc_post, eclass
    version 16.0
    args estname bval withdepvar
    tempname b V
    matrix `b' = (`bval', 0)
    matrix colnames `b' = x _cons
    matrix `V' = I(2) * 0.04
    matrix colnames `V' = x _cons
    matrix rownames `V' = x _cons
    * esample() consumes the marker variable it is handed, so it is rebuilt on
    * every call. Without a marker the sample check reports "cannot verify" and
    * masks the metadata gap under test.
    tempvar tuse
    quietly generate byte `tuse' = 1
    ereturn post `b' `V', esample(`tuse') obs(20)
    ereturn local cmd "regress"
    if "`withdepvar'" == "1" ereturn local depvar "y"
    estimates store `estname'
end

capture program drop _iivw_nc_estdata
program define _iivw_nc_estdata
    version 16.0
    clear
    set obs 20
    gen double x = rnormal()
end

**## N4 nullcase: stored estimates carrying no e(depvar) are refused
* IIVW-14a. iivw_diagnose decides "the three estimates are the same estimand"
* by comparing e(depvar) and e(cmd) ACROSS the three roles. Three estimates
* that carry NEITHER field compare equal to one another on "" == "", so every
* branch of that gate passes without one fact having been checked. Measured on
* the pre-4.1.1 tree, this degenerate artifact -- e(cmd) = "regress", an
* esample() marker, missing metadata in e(depvar) -- returned:
*
*     R3_RC=0
*     R3_DECOMPOSABLE=1
*     R3_SAMPLE_IDENTICAL=1
*     R3_DEPVAR=||
*
* a printed sampling/artifact decomposition certified as valid between
* coefficients whose outcomes were never established to be the same one.
local ++test_count
capture noisily {
    _iivw_nc_estdata
    estimates clear
    _iivw_nc_post nc_u 1 0
    _iivw_nc_post nc_w 2 0
    _iivw_nc_post nc_a 3 0
    * The degenerate artifact: three stored estimates with missing metadata
    * in e(depvar), so the comparability gate compares "" with "".
    capture noisily iivw_diagnose x, unweighted(nc_u) weighted(nc_w) adjusted(nc_a)
    local n4_rc = _rc
    display as text "    no-metadata diagnose rc=`n4_rc'"
    assert `n4_rc' != 0
    assert `n4_rc' == 198
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N4 metadata-free stored estimates refused"
    local ++pass_count
}
else {
    display as error "  FAIL: N4 metadata-free stored estimates (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N4"
}

**## N5 positive control for N4: the same estimates WITH e(depvar) still decompose
* The resolve contract must reject only what genuinely cannot answer the
* question the gate asks. One `ereturn local depvar' apart from N4.
local ++test_count
capture noisily {
    _iivw_nc_estdata
    estimates clear
    _iivw_nc_post pc_u 1 1
    _iivw_nc_post pc_w 2 1
    _iivw_nc_post pc_a 3 1
    capture noisily iivw_diagnose x, unweighted(pc_u) weighted(pc_w) adjusted(pc_a)
    local n5_rc = _rc
    display as text "    with-metadata diagnose rc=`n5_rc'"
    assert `n5_rc' == 0
    assert "`r(depvar)'" == "y"
    assert r(decomposable) == 1
    assert r(sample_identical) == 1
    * The gaps are ROWS of r(decomp), not scalars: reading them as
    * r(sampling_gap) yields missing, and `missing < 1e-12' is false, so the
    * wrong spelling turns this control into a permanent failure. Named row
    * lookup rather than a fixed subscript, so a reordered matrix is caught.
    matrix nc_D = r(decomp)
    local nc_samp = rownumb(nc_D, "sampling_gap")
    local nc_art  = rownumb(nc_D, "artifact_gap")
    local nc_tot  = rownumb(nc_D, "total_gap")
    assert !missing(`nc_samp', `nc_art', `nc_tot')
    assert !missing(nc_D[`nc_samp', 1])
    assert reldif(nc_D[`nc_samp', 1], -1) < 1e-12
    assert !missing(nc_D[`nc_art', 1])
    assert reldif(nc_D[`nc_art', 1], -1) < 1e-12
    assert !missing(nc_D[`nc_tot', 1])
    assert reldif(nc_D[`nc_tot', 1], -2) < 1e-12
    matrix drop nc_D
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N5 complete metadata still decomposes"
    local ++pass_count
}
else {
    display as error "  FAIL: N5 complete metadata (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N5"
}

**## N6 nullcase: an iivw.ado header with no readable version is refused
* IIVW-14b. iivw resolves its displayed version from the *! header of the
* iivw.ado it names through findfile -- an explicitly named source. A header
* the regex cannot match is a degenerate artifact, and the pre-4.1.1 code left
* the local at its "unknown" default and returned, measured on that tree:
*
*     R2_RC=0
*     R2_VERSION=|unknown|
*
* reporting the install as present but unidentifiable rather than refusing.
* r(version) is what a downstream compatibility check reads.
local nc_mangle "`c(tmpdir)'/iivw_nc_mangled_`c(pid)'"
capture mkdir "`nc_mangle'"
local ++test_count
capture noisily {
    * Build the degenerate copy: every shipped file verbatim, except an
    * iivw.ado whose header has lost its "Version" token.
    local nc_ship : dir "`pkg_dir'" files "*.ado"
    local nc_ship2 : dir "`pkg_dir'" files "*.sthlp"
    foreach f of local nc_ship {
        if "`f'" != "iivw.ado" quietly copy "`pkg_dir'/`f'" "`nc_mangle'/`f'", replace
    }
    foreach f of local nc_ship2 {
        quietly copy "`pkg_dir'/`f'" "`nc_mangle'/`f'", replace
    }
    quietly copy "`pkg_dir'/iivw.pkg"  "`nc_mangle'/iivw.pkg", replace
    quietly copy "`pkg_dir'/stata.toc" "`nc_mangle'/stata.toc", replace
    quietly filefilter "`pkg_dir'/iivw.ado" "`nc_mangle'/iivw.ado", ///
        from("*! iivw Version") to("*! iivw") replace
    * Confirm the fixture really is degenerate before trusting the refusal:
    * a copy that still carried a version would make this test pass for the
    * wrong reason.
    tempname nc_fh
    file open `nc_fh' using "`nc_mangle'/iivw.ado", read text
    file read `nc_fh' nc_header
    file close `nc_fh'
    assert !regexm("`nc_header'", "Version ([0-9.]+)")

    capture ado uninstall iivw
    quietly net install iivw, from("`nc_mangle'") replace
    discard
    * The degenerate artifact is installed: a null-case iivw.ado header the
    * version regex cannot match.
    capture noisily iivw
    local n6_rc = _rc
    display as text "    version-less header rc=`n6_rc'"
    assert `n6_rc' != 0
    assert `n6_rc' == 198
}
local rc = _rc
* Restore the real install unconditionally: N7 and any later suite in the same
* process must not inherit the mangled tree if the block above exited early.
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard
if `rc' == 0 {
    display as result "  PASS: N6 unreadable iivw.ado header refused"
    local ++pass_count
}
else {
    display as error "  FAIL: N6 unreadable iivw.ado header (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N6"
}

**## N7 positive control for N6: the shipped header still resolves
* The refusal must be about an unreadable header, not about reading one.
local ++test_count
capture noisily {
    tempname nc_fh2
    file open `nc_fh2' using "`pkg_dir'/iivw.ado", read text
    file read `nc_fh2' nc_header2
    file close `nc_fh2'
    assert regexm("`nc_header2'", "Version ([0-9.]+)")
    local nc_expected = regexs(1)

    capture noisily iivw
    local n7_rc = _rc
    display as text "    shipped header rc=`n7_rc' version=`r(version)'"
    assert `n7_rc' == 0
    assert "`r(version)'" == "`nc_expected'"
    assert "`r(version)'" != "unknown"
    assert r(n_commands) == 5
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N7 shipped header resolves to the package version"
    local ++pass_count
}
else {
    display as error "  FAIL: N7 shipped header (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N7"
}

**# Summary

display as result "iivw null-case results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_nullcase tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW NULL-CASE TESTS PASSED"
display "RESULT: test_iivw_nullcase tests=`test_count' pass=`pass_count' fail=`fail_count'"

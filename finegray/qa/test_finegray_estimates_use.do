* test_finegray_estimates_use.do
* The estimates save / estimates use round trip.
*
* WHY THIS SUITE EXISTS.  Across the 33-suite inventory not one file mentioned
* `estimates save' or `estimates use', although finegray.sthlp documents the
* `basehaz' option specifically for that workflow ("a saved estimation set
* carries only e() -- so without e(basehaz) in it, predict, cif after estimates
* use cannot recover the baseline").  The workflow was documented and untested,
* and the untested half was wrong:
*
*   `estimates use' restores e() but NOT e(sample).  The marker is a property of
*   the data in memory and a saved estimation set does not carry one, so after
*   `estimates use' no observation is marked.  _finegray_check_data then computed
*   its signature over zero rows, got `0:6:0:0' against a stored
*   `899:6:3425757853:1203472247', and reported "data have changed since finegray
*   was estimated" -- of data the user had not touched.  finegray_cif and
*   finegray_phtest were unusable after the very command the help file named as
*   the remedy for the same r(459).
*
* Tests 3 and 4 FAIL on the pre-fix tree by construction: there the message is
* the "data have changed" one.  Tests 1, 2, 5 and 6 pass on both and are the
* no-regression half -- 5 and 6 in particular assert that the recovery route
* reproduces the pre-save numbers rather than merely returning rc 0.
*
* Tests 7-9 were added 2026-08-19 for the second half of the same defect.  The
* `_finegray_estimated' characteristic travels with the DATASET, so which
* failure the user meets depends on when they saved their data:
*
*   scenario B -- data saved AFTER the fit -> the characteristic is present ->
*     r(459) with the documented `estimates esample:' guidance.  Tests 1-6.
*   scenario A -- data saved BEFORE the fit -> no characteristic ->
*     r(301) "estimation state is not active / re-run finegray", which is the
*     wrong instruction: the documented one-line repair does work.  Scenario A
*     is the natural workflow and the one the help file describes, and this
*     suite covered only B.  Tests 7 and 8; test 9 is the guard that the
*     fall-through did not become a way in.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_estimates_use.log", replace name(_teu)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Competing-risks fixture with a factor covariate, so the reload exercises the
* fit-time expansion path as well as the plain one.
capture program drop _mk_eu
program define _mk_eu
    clear
    set seed 20260810
    quietly set obs 700
    gen long id = _n
    gen byte grp = 1 + mod(_n, 3)
    gen double z = rnormal()
    gen double lp = 0.5 * (grp == 2) - 0.3 * (grp == 3) + 0.4 * z
    gen double t1 = -ln(runiform()) / (0.05 * exp(lp))
    gen double t2 = -ln(runiform()) / 0.04
    gen double tc = -ln(runiform()) / 0.03
    gen double t  = min(t1, t2, tc)
    gen byte ev = cond(t == tc, 0, cond(t == t1, 1, 2))
    quietly replace t = round(t, 0.01)
    quietly replace t = 0.01 if t <= 0
    quietly stset t, failure(ev == 1 2) id(id)
end

* Fit, record the reference numbers, and save both the estimates and the data.
tempfile eu_data eu_data_pre eu_est
_mk_eu
* Save the analysis data BEFORE the fit as well.  This is scenario A of the two
* cross-session round trips, and the difference between them is not cosmetic:
* the `_finegray_estimated' characteristic is stored in the DATASET, so a copy
* written before the fit does not carry it and a copy written after it does.
* Everything below through test 6 uses the after-the-fit copy; tests 7 and 8 use
* this one.
quietly save "`eu_data_pre'", replace
quietly finegray i.grp z, compete(ev) cause(1) nolog basehaz
local ref_cause = e(cause)
* Reference values are carried in LOCALS, not tempname matrices.  Every test
* below opens with `clear all' -- which is the point of them, because it also
* wipes the Mata baseline cache and so forces the reload to come from
* e(basehaz) rather than from a warm in-session curve -- and `clear all' takes
* every matrix with it, tempname or not.  A matrix reference would be gone by
* the first assertion.
local ref_nb = colsof(e(b))
forvalues k = 1/`ref_nb' {
    local ref_b`k' = e(b)[1, `k']
}
quietly finegray_cif, attime(2 5) nograph
tempname R0
matrix `R0' = r(table)
local ref_cif2 = `R0'[1, 2]
local ref_se2  = `R0'[1, 3]
local ref_cif5 = `R0'[2, 2]
local ref_se5  = `R0'[2, 3]
quietly finegray_phtest
tempname P0
matrix `P0' = r(phtest)
local ref_np = rowsof(`P0')
forvalues k = 1/`ref_np' {
    local ref_ph`k' = `P0'[`k', 1]
}
quietly finegray_predict _eu_ref_cif, cif
quietly summarize _eu_ref_cif, meanonly
local ref_predmean = r(mean)
quietly drop _eu_ref_cif
quietly save "`eu_data'", replace
quietly estimates save "`eu_est'", replace

* -----------------------------------------------------------------------------
**# 1. estimates use restores e(), and e(sample) comes back EMPTY
* -----------------------------------------------------------------------------
* The premise the rest of the suite rests on.  Asserted rather than assumed:
* if a future Stata release starts restoring e(sample), tests 3 and 4 would
* silently stop exercising anything and this one says so first.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data'", clear
    quietly estimates use "`eu_est'"
    assert "`e(cmd)'" == "finegray"
    assert e(cause) == `ref_cause'
    quietly count if e(sample)
    assert r(N) == 0
    * e(basehaz) is what makes the reload useful at all; it is why the help
    * file tells the user to fit with basehaz before saving.
    capture confirm matrix e(basehaz)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: EU-1 estimates use restores e() with an empty e(sample)"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-1 estimates use premise (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 2. The commands that do not read e(sample) still work, and still agree
* -----------------------------------------------------------------------------
* finegray_predict xb/cif and the replay read e(b) and the baseline only, so
* the empty sample cannot reach them.  This is the documented promise of
* basehaz, and it is checked on the NUMBERS, not on rc.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data'", clear
    quietly estimates use "`eu_est'"

    quietly finegray_predict _eu_cif, cif
    quietly summarize _eu_cif, meanonly
    assert !missing(r(mean), `ref_predmean')
    assert reldif(r(mean), `ref_predmean') < 1e-10

    quietly finegray_predict _eu_xb, xb
    quietly count if missing(_eu_xb)
    assert r(N) == 0

    * The replay reads e() only.
    quietly finegray
    assert "`e(cmd)'" == "finegray"
}
if _rc == 0 {
    display as result "  PASS: EU-2 predict xb/cif and replay survive estimates use"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-2 predict/replay after estimates use (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 3. finegray_cif names the EMPTY SAMPLE, not "data have changed"
* -----------------------------------------------------------------------------
* FAILS on the pre-fix tree: there the message is "data have changed since
* finegray was estimated", which is false and sends the reader to inspect data
* they never modified.  The assertion is on the message text, because the
* return code was already 459 before the fix and is 459 after it -- rc alone
* cannot tell the two diagnoses apart.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data'", clear
    quietly estimates use "`eu_est'"

    tempfile eucap
    capture log close _eucap
    log using "`eucap'", replace text name(_eucap)
    capture noisily finegray_cif, attime(2) nograph
    local cif_rc = _rc
    log close _eucap

    assert `cif_rc' == 459

    tempname fh
    local saw_empty = 0
    local saw_changed = 0
    file open `fh' using "`eucap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "estimation sample is empty") > 0 local saw_empty = 1
        if strpos(`"`line'"', "data have changed") > 0 local saw_changed = 1
        file read `fh' line
    }
    file close `fh'
    assert `saw_empty' == 1
    assert `saw_changed' == 0
}
if _rc == 0 {
    display as result "  PASS: EU-3 finegray_cif reports the empty estimation sample"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-3 finegray_cif empty-sample diagnosis (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 4. finegray_phtest gives the same diagnosis, and names the recovery
* -----------------------------------------------------------------------------
* Same guard on the second consumer, plus the half that makes the message
* actionable: it must name `estimates esample:'.  A correct diagnosis the user
* cannot act on is only half a fix.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data'", clear
    quietly estimates use "`eu_est'"

    tempfile eucap2
    capture log close _eucap2
    log using "`eucap2'", replace text name(_eucap2)
    capture noisily finegray_phtest
    local ph_rc = _rc
    log close _eucap2

    assert `ph_rc' == 459

    tempname fh2
    local saw_empty2 = 0
    local saw_remedy = 0
    file open `fh2' using "`eucap2'", read text
    file read `fh2' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "estimation sample is empty") > 0 local saw_empty2 = 1
        if strpos(`"`line'"', "estimates esample:") > 0 local saw_remedy = 1
        file read `fh2' line
    }
    file close `fh2'
    assert `saw_empty2' == 1
    assert `saw_remedy' == 1
}
if _rc == 0 {
    display as result "  PASS: EU-4 finegray_phtest reports it and names estimates esample:"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-4 finegray_phtest empty-sample diagnosis (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 5. estimates esample: restores the workflow, to the same NUMBERS
* -----------------------------------------------------------------------------
* The message is only worth printing if the remedy it names actually works, and
* "works" means the pre-save r(table) and r(phtest), not rc 0.  A recovery route
* that returned different numbers would be worse than the refusal.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data'", clear
    quietly estimates use "`eu_est'"
    quietly estimates esample: `e(datasignaturevars)' if !missing(_t)

    quietly count if e(sample)
    assert r(N) == e(N)

    quietly finegray_cif, attime(2 5) nograph
    tempname GOT_CIF
    matrix `GOT_CIF' = r(table)
    assert !missing(`GOT_CIF'[1, 2], `ref_cif2')
    assert reldif(`GOT_CIF'[1, 2], `ref_cif2') < 1e-12
    assert !missing(`GOT_CIF'[1, 3], `ref_se2')
    assert reldif(`GOT_CIF'[1, 3], `ref_se2')  < 1e-12
    assert !missing(`GOT_CIF'[2, 2], `ref_cif5')
    assert reldif(`GOT_CIF'[2, 2], `ref_cif5') < 1e-12
    assert !missing(`GOT_CIF'[2, 3], `ref_se5')
    assert reldif(`GOT_CIF'[2, 3], `ref_se5')  < 1e-12

    quietly finegray_phtest
    tempname GOT_PH
    matrix `GOT_PH' = r(phtest)
    assert rowsof(`GOT_PH') == `ref_np'
    forvalues k = 1/`ref_np' {
        assert !missing(`GOT_PH'[`k', 1], `ref_ph`k'')
        assert reldif(`GOT_PH'[`k', 1], `ref_ph`k'') < 1e-12
    }

    * e(b) must not have moved either: esample changes the marker, not the fit.
    * Compared to 1e-15, not bit-for-bit.  `estimates save'/`use' round-trips
    * e(b) exactly (checked in hex: two of three coefficients return the
    * identical bit pattern), but `local ref = e(b)[1,k]' does not -- the macro
    * is a decimal string and one coefficient came back one ULP away
    * (...3b26bX-002 stored, ...3b26cX-002 reloaded).  The claim being made here
    * is "the fit did not move", and one ULP is inside it; asserting equality
    * would be testing Stata's macro formatter.
    assert colsof(e(b)) == `ref_nb'
    forvalues k = 1/`ref_nb' {
        assert !missing(e(b)[1, `k'], `ref_b`k'')
        assert reldif(e(b)[1, `k'], `ref_b`k'') < 1e-15
    }
}
if _rc == 0 {
    display as result "  PASS: EU-5 estimates esample: reproduces the pre-save numbers"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-5 esample recovery numbers (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 6. A WRONG esample is still refused by the data signature
* -----------------------------------------------------------------------------
* The new guard must not become a way in.  Declaring a sample that is not the
* fit's has to fail on the signature exactly as it did before -- otherwise the
* recovery route would let a user answer for a fit with the wrong rows, at rc 0.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data'", clear
    quietly estimates use "`eu_est'"
    * Half the sample: nonempty, so it clears the new check, and wrong, so it
    * must not clear the signature.
    quietly estimates esample: `e(datasignaturevars)' if !missing(_t) & mod(id, 2) == 0

    quietly count if e(sample)
    assert !missing(r(N))
    assert r(N) > 0

    tempfile eucap3
    capture log close _eucap3
    log using "`eucap3'", replace text name(_eucap3)
    capture noisily finegray_cif, attime(2) nograph
    local bad_rc = _rc
    log close _eucap3

    assert `bad_rc' == 459

    tempname fh3
    local saw_changed3 = 0
    file open `fh3' using "`eucap3'", read text
    file read `fh3' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "data have changed") > 0 local saw_changed3 = 1
        file read `fh3' line
    }
    file close `fh3'
    assert `saw_changed3' == 1
}
if _rc == 0 {
    display as result "  PASS: EU-6 a wrong esample is still caught by the signature"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-6 wrong esample not refused (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 7. SCENARIO A: the data were saved BEFORE the fit
* -----------------------------------------------------------------------------
* The natural cross-session workflow -- save the analysis dataset, fit, save the
* estimates, come back tomorrow -- and precisely the one finegray.sthlp
* describes when it documents r(459) and the `estimates esample:' repair.  The
* dataset on disk predates the fit, so it carries no `_finegray_estimated'
* characteristic, and _finegray_check_data tested that characteristic BEFORE the
* curated empty-sample branch.  Result: r(301) "finegray estimation state is not
* active / re-run finegray" -- fail-closed, but it sends the user to refit when
* the documented one-line repair would have worked, and it contradicts the help
* file.  Tests 1-6 could not see this because they save after the fit.
*
* FAILS on the pre-fix tree: there the rc is 301 and neither phrase appears.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data_pre'", clear
    * The premise, asserted rather than assumed.
    local _pre_char : char _dta[_finegray_estimated]
    assert "`_pre_char'" != "1"
    quietly estimates use "`eu_est'"
    assert "`e(cmd)'" == "finegray"

    tempfile eucap7
    capture log close _eucap7
    log using "`eucap7'", replace text name(_eucap7)
    capture noisily finegray_cif, attime(2) nograph
    local a_rc = _rc
    log close _eucap7

    assert `a_rc' == 459

    tempname fh7
    local saw_empty7 = 0
    local saw_remedy7 = 0
    local saw_notactive7 = 0
    file open `fh7' using "`eucap7'", read text
    file read `fh7' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "estimation sample is empty") > 0 local saw_empty7 = 1
        if strpos(`"`line'"', "estimates esample:") > 0 local saw_remedy7 = 1
        if strpos(`"`line'"', "estimation state is not active") > 0 local saw_notactive7 = 1
        file read `fh7' line
    }
    file close `fh7'
    assert `saw_empty7' == 1
    assert `saw_remedy7' == 1
    assert `saw_notactive7' == 0
}
if _rc == 0 {
    display as result "  PASS: EU-7 scenario A reports the empty sample and names the repair"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-7 scenario A diagnosis (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 8. Scenario A: the repair the message names reproduces the pre-save numbers
* -----------------------------------------------------------------------------
* A correct diagnosis is only worth printing if the remedy works, and "works"
* means the pre-save r(table) and r(phtest) -- not rc 0.  Note that the pre-fit
* dataset holds no package-owned _fg_* design columns either, so this also
* exercises the cold rebuild of the factor expansion.
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data_pre'", clear
    quietly estimates use "`eu_est'"
    quietly estimates esample: `e(datasignaturevars)' if !missing(_t)

    quietly count if e(sample)
    assert r(N) == e(N)

    quietly finegray_cif, attime(2 5) nograph
    tempname A_CIF
    matrix `A_CIF' = r(table)
    assert !missing(`A_CIF'[1, 2], `ref_cif2')
    assert reldif(`A_CIF'[1, 2], `ref_cif2') < 1e-12
    assert !missing(`A_CIF'[1, 3], `ref_se2')
    assert reldif(`A_CIF'[1, 3], `ref_se2')  < 1e-12
    assert !missing(`A_CIF'[2, 2], `ref_cif5')
    assert reldif(`A_CIF'[2, 2], `ref_cif5') < 1e-12
    assert !missing(`A_CIF'[2, 3], `ref_se5')
    assert reldif(`A_CIF'[2, 3], `ref_se5')  < 1e-12

    quietly finegray_phtest
    tempname A_PH
    matrix `A_PH' = r(phtest)
    assert rowsof(`A_PH') == `ref_np'
    forvalues k = 1/`ref_np' {
        assert !missing(`A_PH'[`k', 1], `ref_ph`k'')
        assert reldif(`A_PH'[`k', 1], `ref_ph`k'') < 1e-12
    }
}
if _rc == 0 {
    display as result "  PASS: EU-8 scenario A esample recovery reproduces the numbers"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-8 scenario A esample recovery (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 9. The fall-through is not a way in: no finegray in e() is still r(301)
* -----------------------------------------------------------------------------
* The scenario-A relaxation is conditional on e() actually holding a finegray
* fit with a signature.  Without one there is nothing to fall through to, and
* the answer must still be "estimation state is not active".
local ++test_count
capture noisily {
    clear all
    quietly use "`eu_data_pre'", clear
    capture noisily finegray_cif, attime(2) nograph
    assert _rc == 301
    capture noisily finegray_phtest
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: EU-9 no finegray in e() still refuses at r(301)"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-9 missing-estimates guard (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
**# 10. Scenario A on a MULTIPLE-RECORD fit stays fail-closed, by name
* -----------------------------------------------------------------------------
* The relaxation in test 7 must not open a silent path here.  A multiple-record
* fit reads its subject-level entry times from a package-owned _fg_entry column
* that a pre-fit dataset does not contain; answering from per-record _t0 instead
* would be a wrong answer at rc 0.  It does not happen, and this test pins the
* two independent reasons why: _fg_entry is in e(datasignaturevars), so the
* variable check names it; and the column is now recorded in e(entryvar) as well
* as in the dataset characteristic, so a consumer that has lost the
* characteristic still asks for the right variable rather than falling back to
* _t0.  On the pre-fix tree this stopped at r(301) "estimation state is not
* active" -- fail-closed too, but naming neither.
local ++test_count
capture noisily {
    tempfile mr_pre mr_est
    * Built INLINE, not from a helper program: every test above opens with
    * `clear all', which drops user programs along with everything else, so
    * _mk_eu is long gone by the time this block runs.
    *
    * NOTE the stset: the failure indicator is a SEPARATE variable from
    * compete().  stsplit blanks whatever variable the failure() expression is
    * built on -- the by-name form AND the expression form, verified 2026-08-19
    * -- and finegray now refuses a missing compete(), so `failure(ev == 1 2)'
    * with `compete(ev)' would abort here at r(198).
    clear
    set seed 20260819
    quietly set obs 700
    gen long id = _n
    gen double z = rnormal()
    gen double lp = 0.4 * z
    gen double t1 = -ln(runiform()) / (0.05 * exp(lp))
    gen double t2 = -ln(runiform()) / 0.04
    gen double tc = -ln(runiform()) / 0.03
    gen double t  = min(t1, t2, tc)
    gen byte ev = cond(t == tc, 0, cond(t == t1, 1, 2))
    quietly replace t = round(t, 0.01)
    quietly replace t = 0.01 if t <= 0
    drop t1 t2 tc lp
    gen byte anyev = ev != 0
    quietly stset t, failure(anyev == 1) id(id)
    quietly stsplit sp, at(2 6)
    quietly save "`mr_pre'", replace
    quietly finegray z, compete(ev) cause(1) nolog basehaz
    * The two records of the same fact must agree.
    local mr_char : char _dta[_finegray_entryvar]
    assert "`mr_char'" == "_fg_entry"
    assert "`e(entryvar)'" == "_fg_entry"
    * and the reduction really happened
    assert e(N) < _N
    quietly estimates save "`mr_est'", replace

    clear all
    quietly use "`mr_pre'", clear
    capture confirm variable _fg_entry
    assert _rc != 0
    quietly estimates use "`mr_est'"

    tempfile eucap10
    capture log close _eucap10
    log using "`eucap10'", replace text name(_eucap10)
    capture noisily finegray_cif, attime(2) nograph
    local mr_rc = _rc
    log close _eucap10

    assert `mr_rc' == 459

    tempname fh10
    local saw_named = 0
    local saw_notactive10 = 0
    file open `fh10' using "`eucap10'", read text
    file read `fh10' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "_fg_entry") > 0 local saw_named = 1
        if strpos(`"`line'"', "estimation state is not active") > 0 local saw_notactive10 = 1
        file read `fh10' line
    }
    file close `fh10'
    assert `saw_named' == 1
    assert `saw_notactive10' == 0
}
if _rc == 0 {
    display as result "  PASS: EU-10 multi-record scenario A fails closed naming _fg_entry"
    local ++pass_count
}
else {
    display as error "  FAIL: EU-10 multi-record scenario A (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_estimates_use tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _teu
    exit 1
}
display as result "ALL TESTS PASSED"
log close _teu

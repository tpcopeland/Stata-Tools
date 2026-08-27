*! test_finegray_errors.do - Public error-contract coverage for finegray
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
capture log close _all
log using "test_finegray_errors.log", replace text name(_test_finegray_errors)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

capture program drop _fge_make
program define _fge_make
    clear
    set seed 20260823
    set obs 240
    generate long id = _n
    generate double x = rnormal()
    generate byte event = cond(_n <= 90, 1, cond(_n <= 150, 2, 0))
    generate double time = 1 + mod(_n, 12)
    generate byte marker = 97
    quietly stset time, failure(event) id(id)
end

capture program drop _fge_record
program define _fge_record
    args rc label
    if `rc' == 0 display as result "  PASS: `label'"
    else display as error "  FAIL: `label' (error `rc')"
end

**# Estimation command early option conflict and legal fit
local ++test_count
capture noisily {
    _fge_make
    capture noisily finegray x, compete(event) cause(1) adjust(noadjust) robust(norobust)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 97
    assert _N == 240
    capture noisily finegray x, compete(event) cause(1) nolog
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert "`e(cmd)'" == "finegray"
    matrix FGE_b = e(b)
}
local block_rc = _rc
_fge_record `block_rc' "finegray rejects incompatible adjustment/robust options; legal fit posts e()"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# CIF mid-path grid conflict preserves fitted state and data
local ++test_count
capture noisily {
    capture noisily finegray_cif, attime(4) timepoints(2 4) nograph
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 97
    assert "`e(cmd)'" == "finegray"
    assert mreldif(FGE_b, e(b)) < 1e-12
    capture noisily finegray_cif, attime(4) nograph
    local legal_rc = _rc
    assert `legal_rc' == 0
    tempname cif_table cif_profile
    matrix `cif_table' = r(table)
    matrix `cif_profile' = r(at)
    assert rowsof(`cif_table') == 1
    assert `cif_table'[1, 1] == 4
    assert !missing(`cif_table'[1, 1], `cif_table'[1, 2], `cif_table'[1, 3])
    assert missing(`cif_table'[1, 4], `cif_table'[1, 5])
    mata: assert(!hasmissing(st_matrix("`cif_profile'")))
}
local block_rc = _rc
_fge_record `block_rc' "finegray_cif rejects competing grids without mutating fit; attime() works"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# PH diagnostic option contract
local ++test_count
capture noisily {
    quietly finegray_phtest
    assert "`r(time)'" == "rank"
    capture noisily finegray_phtest, time(badscale)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 97
    assert "`e(cmd)'" == "finegray"
    assert mreldif(FGE_b, e(b)) < 1e-12
    capture noisily finegray_phtest, time(rank)
    local legal_rc = _rc
    assert `legal_rc' == 0
    confirm matrix r(phtest)
}
local block_rc = _rc
_fge_record `block_rc' "finegray_phtest defaults to rank, rejects invalid time scales, and preserves fit"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Prediction option ignored-success probe and legal inverse
local ++test_count
capture noisily {
    capture noisily finegray_predict badxb, xb seed(1)
    local call_rc = _rc
    assert `call_rc' == 198
    capture confirm variable badxb
    assert _rc == 111
    assert marker == 97
    assert "`e(cmd)'" == "finegray"
    assert mreldif(FGE_b, e(b)) < 1e-12
    capture noisily finegray_predict goodxb, xb
    local legal_rc = _rc
    assert `legal_rc' == 0
    confirm variable goodxb
    assert !missing(goodxb)
}
local block_rc = _rc
_fge_record `block_rc' "finegray_predict refuses ignored seed(); legal xb creates exactly its target"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# THE WORDING CANARY
* -----------------------------------------------------------------------------
* This is the ONLY test in the whole finegray suite that pins the exact text of
* a refusal.  Everywhere else -- and in particular in test_finegray_fences.do,
* which holds the whole option lattice -- the assertions are on the return code
* and on the OPTION NAMES the message contains.  That split is deliberate: it
* means rewording a refusal breaks exactly one test, in one file, on purpose,
* instead of turning a lattice of unrelated suites red and creating pressure to
* soften the message rather than keep the fence honest.
*
* WHEN THIS FAILS.  Read the diff.  If the reword is intended, update the
* string here and nothing else.  If it is NOT intended, a message changed
* without anyone deciding to change it -- which is what this test is for.
*
* One line per refusal: the FIRST line, which is the sentence a user reads and
* the one that has to name the reason.  The continuation lines are explanation
* and are not pinned anywhere.
local ++test_count
capture noisily {
    _fge_make
    quietly generate byte ctr = 1 + mod(_n, 2)
    quietly generate double w = rnormal()

    capture program drop _fge_first
    program define _fge_first, rclass
        version 16.0
        syntax , CMD(string) EXPect(string)
        tempfile cap
        capture log close _fgecan
        quietly log using "`cap'", replace text name(_fgecan)
        capture noisily `cmd'
        capture log close _fgecan
        tempname fh
        local saw = 0
        file open `fh' using "`cap'", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`line'"', `"`expect'"') > 0 local saw = 1
            file read `fh' line
        }
        file close `fh'
        if !`saw' {
            display as error `"wording canary: expected first line not found"'
            display as error `"  command:  `cmd'"'
            display as error `"  expected: `expect'"'
        }
        return scalar saw = `saw'
    end

    * Three refusals that USED to be pinned here -- nuisance x bstrata(),
    * nuisance x tvc(), and tvc() x bstrata() -- were lifted in v1.4.0 and have
    * no message left to pin.  Their cells are now positive assertions in
    * test_finegray_fences.do (FGFEN-03).

    _fge_first, cmd(`"finegray x, compete(event) cause(1) nuisance norobust nolog"') ///
        expect("nuisance is not allowed with norobust")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) cluster(ctr) norobust nolog"') ///
        expect("cluster() is not allowed with norobust")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) noadjust norobust nolog"') ///
        expect("noadjust is not allowed with norobust")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) tvc(x) nolog"') ///
        expect("tvc() requires tsplit()")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) tsplit(6) nolog"') ///
        expect("tsplit() requires tvc()")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) tvc(x) tsplit(0) nolog"') ///
        expect("tsplit() boundaries must be positive")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) truncstrata(ctr) nolog"') ///
        expect("truncstrata() requires delayed entry")
    assert r(saw) == 1

    * the delayed-entry family needs delayed-entry data
    quietly generate double ent = cond(mod(_n, 3) == 0, 1, 0)
    quietly stset time, failure(event) id(id) enter(time ent)

    _fge_first, cmd(`"finegray x, compete(event) cause(1) nuisance nolog"') ///
        expect("nuisance is not allowed with delayed entry")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) bstrata(ctr) nolog"') ///
        expect("bstrata() with delayed entry is an unsourced composition, not implemented")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray x, compete(event) cause(1) tvc(x) tsplit(6) nolog"') ///
        expect("tvc() is not supported with delayed entry")
    assert r(saw) == 1

    * post-estimation refusals
    quietly stset time, failure(event) id(id)
    quietly finegray x, compete(event) cause(1) tvc(x) tsplit(6) nolog

    * The analytic-ci refusal was LIFTED in v1.4.0 (the CIF influence function
    * was re-derived for a piecewise beta(t)), so it has no message left to pin.
    * The schoenfeld and phtest refusals remain and are pinned instead.
    _fge_first, cmd(`"finegray_predict double schq2, schoenfeld"') ///
        expect("schoenfeld is not available after a fit with tvc()")
    assert r(saw) == 1

    _fge_first, cmd(`"finegray_phtest"') ///
        expect("finegray_phtest is not available after a fit with tvc()")
    assert r(saw) == 1

    quietly finegray x, compete(event) cause(1) bstrata(ctr) nolog
    _fge_first, cmd(`"finegray_cif, at(x=0) nograph"') ///
        expect("bstratum() is required after a fit with bstrata(ctr)")
    assert r(saw) == 1
}
local block_rc = _rc
_fge_record `block_rc' "wording canary: refusal first lines are unchanged"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_finegray_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _test_finegray_errors
if `fail_count' > 0 exit 1
exit 0

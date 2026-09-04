* test_finegray_failclosed.do - missing-injection regressions for the QA guard constructs
* Package: finegray
*
* Purpose
* -------
* Stata's missing values compare GREATER than every finite number, and
* reldif(., .) is exactly 0.  So the two commonest QA assertion shapes
*
*     assert q > 0
*     assert reldif(a, b) < tol
*
* are both SATISFIED when their operands are missing.  A suite built only from
* those shapes cannot tell "the estimator produced the right number" from "the
* estimator produced nothing", and the 2026-09-02 audit (FG-08A) found 42 such
* sites in this suite.
*
* qa/FAILCLOSED_GUARD_MAP.md maps every one of those 42 sites to the guard
* construct that now closes it.  This file is the executable half of that map:
* for each DISTINCT guard construct it
*
*   (a) builds a fixture in which the guarded quantity IS missing,
*   (b) proves the UNGUARDED construct still passes on it (rc == 0) -- so the
*       fixture really is a fail-open fixture and the guard is not decorative,
*   (c) proves the GUARD construct exits nonzero on it, and
*   (d) proves the guard construct passes on finite content, so it is not
*       simply always-red.
*
* It deliberately tests the CONSTRUCTS, not the 42 call sites: the constructs
* are Stata-language semantics, they are what a future edit can get wrong, and
* pinning them here means the map above is checkable rather than asserted.
*
* This suite needs no finegray fit; the estimation-context checks post their
* own e() results so the missing case can be reached at all.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_failclosed.log", replace text name(_fclosed)

* The guard constructs below are Stata-language semantics and need no finegray
* fit, but this suite still installs the local build first: an installed copy
* earlier on the adopath would otherwise shadow it, and the QA hygiene contract
* is that every suite in a lane runs against the tree it claims to test.
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "test_finegray_failclosed.do must run from finegray/qa"
    capture log close _fclosed
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

display as text _newline "finegray fail-closed guard regressions"

* An estimation context whose posted content can be made missing on demand.
* `ereturn post' itself REFUSES a coefficient vector containing a missing value
* (r(504)), which is a structural closure in its own right; the reachable
* missing-content cases are therefore the posted scalars and e(ll).
capture program drop _fc_post
program define _fc_post, eclass
    syntax , [CONVerged(string) ENN(string) LL(string)]
    tempname b V
    matrix `b' = (0.3, 0.5)
    matrix `V' = I(2)
    matrix colnames `b' = x1 x2
    matrix colnames `V' = x1 x2
    matrix rownames `V' = x1 x2
    ereturn post `b' `V'
    if "`converged'" != "" ereturn scalar converged = `converged'
    if "`enn'" != ""       ereturn scalar N = `enn'
    if "`ll'" != ""        ereturn scalar ll = `ll'
end

* -----------------------------------------------------------------------------
* FC-1  G1: assert !missing(A, B) before assert reldif(A, B) < tol
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    * the arithmetic fact the whole class rests on
    assert reldif(., .) == 0

    scalar _fc_a = .
    scalar _fc_b = .
    * (b) unguarded: passes on two missings
    capture assert reldif(_fc_a, _fc_b) < 1e-12
    local rc = _rc
    assert `rc' == 0
    * (c) guarded: refuses
    capture assert !missing(_fc_a, _fc_b)
    local rc = _rc
    assert `rc' != 0
    * one-sided missingness is caught by the unguarded form too, but the guard
    * must catch it as well
    scalar _fc_b = 1
    capture assert !missing(_fc_a, _fc_b)
    local rc = _rc
    assert `rc' != 0
    * (d) finite content: the guard passes and the comparison still bites
    scalar _fc_a = 1
    capture assert !missing(_fc_a, _fc_b)
    local rc = _rc
    assert `rc' == 0
    scalar _fc_b = 2
    capture assert reldif(_fc_a, _fc_b) < 1e-12
    local rc = _rc
    assert `rc' != 0
    scalar drop _fc_a _fc_b
}
if _rc == 0 {
    display as result "  PASS: FC-1 G1 !missing() before scalar reldif"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-1 G1 !missing() before scalar reldif (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-2  G2: assert !missing(q) before a scalar inequality
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double allmiss = .
    quietly summarize allmiss
    * summarize on an all-missing column sets r(N) to 0 and r(sd)/r(min)/r(max)
    * to missing
    assert r(N) == 0
    assert missing(r(sd)) & missing(r(min)) & missing(r(max))

    * (b) unguarded inequalities pass on the missing returns
    capture assert r(sd) > 0
    local rc = _rc
    assert `rc' == 0
    capture assert r(max) > 0
    local rc = _rc
    assert `rc' == 0
    capture assert r(min) >= 0
    local rc = _rc
    assert `rc' == 0
    * the documentation-example shape with no upper bound is fail-open ...
    capture assert r(min) >= 0 & r(max) > 0
    local rc = _rc
    assert `rc' == 0
    * ... while a bounded-above range assert closes on its own, because a
    * missing r(max) is NOT <= 1.  Both shapes appear in this suite.
    capture assert r(min) >= 0 & r(max) <= 1 & r(max) > 0
    local rc = _rc
    assert `rc' != 0

    * (c) the guard refuses
    capture assert !missing(r(sd))
    local rc = _rc
    assert `rc' != 0
    capture assert !missing(r(min))
    local rc = _rc
    assert `rc' != 0

    * (d) finite content: guard passes, inequality still discriminates
    quietly replace allmiss = _n
    quietly summarize allmiss
    capture assert !missing(r(sd))
    local rc = _rc
    assert `rc' == 0
    capture assert r(min) >= 0
    local rc = _rc
    assert `rc' == 0
    capture assert r(min) > 100
    local rc = _rc
    assert `rc' != 0
}
if _rc == 0 {
    display as result "  PASS: FC-2 G2 !missing() before scalar inequality"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-2 G2 !missing() before scalar inequality (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-3  G3: assert !missing(A, B) if touse before a ROW-WISE reldif
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 20
    gen byte touse = 1
    gen double lhs = _n
    gen double rhs = _n
    * inject a row missing on BOTH sides: it satisfies the row-wise reldif
    quietly replace lhs = . in 7
    quietly replace rhs = . in 7

    * (b) unguarded row-wise reldif passes despite the hole
    capture assert reldif(lhs, rhs) < 1e-12
    local rc = _rc
    assert `rc' == 0
    * (c) the guard refuses
    capture assert !missing(lhs, rhs) if touse
    local rc = _rc
    assert `rc' != 0
    * a one-sided hole is caught by both
    quietly replace rhs = 7 in 7
    capture assert !missing(lhs, rhs) if touse
    local rc = _rc
    assert `rc' != 0
    * (d) finite content
    quietly replace lhs = 7 in 7
    capture assert !missing(lhs, rhs) if touse
    local rc = _rc
    assert `rc' == 0
    capture assert reldif(lhs, rhs) < 1e-12
    local rc = _rc
    assert `rc' == 0
}
if _rc == 0 {
    display as result "  PASS: FC-3 G3 row-wise !missing() before row-wise reldif"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-3 G3 row-wise !missing() (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-4  G4: missingness-pattern pin + nonempty compared count
*           (for quantities whose missingness is LEGITIMATELY partial, such as
*            CI limits that exist only where the estimate does)
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 20
    gen byte touse = 1
    gen double lci_a = .
    gen double lci_b = .

    * (b) both all-missing: the pattern pin PASSES and the row-wise reldif
    * PASSES, so the pattern pin alone is not a guard
    capture assert missing(lci_a) == missing(lci_b) if touse
    local rc = _rc
    assert `rc' == 0
    capture assert reldif(lci_a, lci_b) < 1e-10
    local rc = _rc
    assert `rc' == 0
    * (c) the compared-count leg refuses
    quietly count if touse & !missing(lci_a, lci_b)
    assert r(N) == 0
    capture assert !missing(r(N))
    local rc = _rc
    assert `rc' == 0
    capture assert r(N) > 0
    local rc = _rc
    assert `rc' != 0

    * (d) a legitimate partial pattern: some rows compared, pattern matched
    quietly replace lci_a = _n if _n <= 12
    quietly replace lci_b = _n if _n <= 12
    capture assert missing(lci_a) == missing(lci_b) if touse
    local rc = _rc
    assert `rc' == 0
    quietly count if touse & !missing(lci_a, lci_b)
    assert r(N) == 12
    capture assert r(N) > 0
    local rc = _rc
    assert `rc' == 0
    * and a mismatched pattern is refused by the pin
    quietly replace lci_b = 99 in 15
    capture assert missing(lci_a) == missing(lci_b) if touse
    local rc = _rc
    assert `rc' != 0
}
if _rc == 0 {
    display as result "  PASS: FC-4 G4 pattern pin + compared count"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-4 G4 pattern pin + compared count (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-5  G5: forvalues !missing() sweep before a block of matrix-cell reldifs
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    tempname LO AT HI
    matrix `LO' = (1, ., .)
    matrix `AT' = (1, ., .)
    matrix `HI' = (1, ., .)

    * (b) the cell reldifs all pass on the missing columns
    capture assert reldif(`LO'[1, 2], `AT'[1, 2]) < 1e-10
    local rc = _rc
    assert `rc' == 0
    capture assert reldif(`AT'[1, 3], `HI'[1, 3]) < 1e-10
    local rc = _rc
    assert `rc' == 0
    * (c) the sweep refuses
    capture {
        forvalues c = 2/3 {
            assert !missing(`LO'[1, `c'], `AT'[1, `c'], `HI'[1, `c'])
        }
    }
    local rc = _rc
    assert `rc' != 0
    * (d) finite content: sweep passes, and the cell comparison still bites
    matrix `LO' = (1, 2, 3)
    matrix `AT' = (1, 2, 3)
    matrix `HI' = (1, 2, 3)
    capture {
        forvalues c = 2/3 {
            assert !missing(`LO'[1, `c'], `AT'[1, `c'], `HI'[1, `c'])
        }
    }
    local rc = _rc
    assert `rc' == 0
    matrix `HI' = (1, 2, 3.5)
    capture assert reldif(`AT'[1, 3], `HI'[1, 3]) < 1e-10
    local rc = _rc
    assert `rc' != 0
}
if _rc == 0 {
    display as result "  PASS: FC-5 G5 matrix-cell !missing() sweep"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-5 G5 matrix-cell !missing() sweep (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-6  W1: nonmissing-count-equals-N before a range assert on a generated column
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 40
    gen double cif_d = .
    _fc_post, enn(40)
    assert e(N) == 40

    * (b) the doc-example range shape passes on an all-missing column
    quietly summarize cif_d
    capture assert r(min) >= 0 & r(max) > 0
    local rc = _rc
    assert `rc' == 0
    * (c) the count guard refuses
    quietly count if !missing(cif_d)
    assert r(N) == 0
    capture assert r(N) == e(N)
    local rc = _rc
    assert `rc' != 0
    * a PARTIALLY missing column is also refused -- this is what distinguishes
    * the count-equals-N guard from a bare `count > 0'
    quietly replace cif_d = 0.5 if _n <= 30
    quietly count if !missing(cif_d)
    assert r(N) == 30
    capture assert r(N) == e(N)
    local rc = _rc
    assert `rc' != 0
    capture assert r(N) > 0
    local rc = _rc
    assert `rc' == 0
    * (d) a fully populated column passes
    quietly replace cif_d = 0.5
    quietly count if !missing(cif_d)
    capture assert r(N) == e(N)
    local rc = _rc
    assert `rc' == 0
    ereturn clear
}
if _rc == 0 {
    display as result "  PASS: FC-6 W1 nonmissing-count-equals-N"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-6 W1 nonmissing-count-equals-N (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-7  W2: assert r(N) > 0 & r(sd) > 0 is self-guarding on one summarize
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 30
    gen double xb = .
    quietly summarize xb
    * summarize sets r(N) to 0, NOT missing, so the first conjunct is false
    assert r(N) == 0 & !missing(r(N))
    assert missing(r(sd))
    capture assert r(N) > 0 & r(sd) > 0
    local rc = _rc
    assert `rc' != 0
    * the second conjunct alone would have passed
    capture assert r(sd) > 0
    local rc = _rc
    assert `rc' == 0
    * (d) a real column passes, and a CONSTANT column -- the silent-failure case
    * the r(sd) leg exists for -- is still refused
    quietly replace xb = _n
    quietly summarize xb
    capture assert r(N) > 0 & r(sd) > 0
    local rc = _rc
    assert `rc' == 0
    quietly replace xb = 3
    quietly summarize xb
    capture assert r(N) > 0 & r(sd) > 0
    local rc = _rc
    assert `rc' != 0
}
if _rc == 0 {
    display as result "  PASS: FC-7 W2 r(N) > 0 & r(sd) > 0 self-guarding"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-7 W2 r(N) > 0 & r(sd) > 0 self-guarding (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-8  W3: assert t[1] != t0[2] as the precondition for a reldif on that pair
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 2
    gen double t  = .
    gen double t0 = .
    * (b) the reldif passes on the missing pair
    capture assert reldif(t[1], t0[2]) < 1e-13
    local rc = _rc
    assert `rc' == 0
    * (c) the inequality precondition refuses: . != . is 0
    capture assert t[1] != t0[2]
    local rc = _rc
    assert `rc' != 0
    * (d) two genuinely different doubles: precondition passes, reldif bites
    quietly replace t  = 1095836/365.25 - 85/365.25 in 1
    quietly replace t0 = (1095836 - 85)/365.25     in 2
    capture assert t[1] != t0[2]
    local rc = _rc
    assert `rc' == 0
    capture assert reldif(t[1], t0[2]) < 1e-13
    local rc = _rc
    assert `rc' == 0
    quietly replace t0 = t0[2] * 1.5 in 2
    capture assert reldif(t[1], t0[2]) < 1e-13
    local rc = _rc
    assert `rc' != 0
}
if _rc == 0 {
    display as result "  PASS: FC-8 W3 inequality precondition on a missing pair"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-8 W3 inequality precondition (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-9  W4: a LOWER reldif bound as the precondition for an upper reldif bound
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 2
    gen double t  = .
    gen double t0 = .
    capture assert reldif(t[1], t0[2]) < 1e-12
    local rc = _rc
    assert `rc' == 0
    * reldif(., .) == 0 fails a strict positive lower bound
    capture assert reldif(t[1], t0[2]) > 1e-15
    local rc = _rc
    assert `rc' != 0
    * (d) a real few-ulp gap satisfies both bounds
    quietly replace t  = 3.0 in 1
    quietly replace t0 = 3.0 * (1 + 2e-14) in 2
    capture assert reldif(t[1], t0[2]) > 1e-15
    local rc = _rc
    assert `rc' == 0
    capture assert reldif(t[1], t0[2]) < 1e-12
    local rc = _rc
    assert `rc' == 0
}
if _rc == 0 {
    display as result "  PASS: FC-9 W4 lower reldif bound as precondition"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-9 W4 lower reldif bound as precondition (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-10 W5: assert e(converged) == 1 as the precondition for e(N) > 0
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    * a "fit" that posted no convergence flag and no sample size
    _fc_post, converged(.) enn(.)
    assert missing(e(converged)) & missing(e(N))
    * (b) the sample-size inequalities pass on missing e() scalars
    capture assert e(N) > 0
    local rc = _rc
    assert `rc' == 0
    * (c) the convergence precondition refuses
    capture assert e(converged) == 1
    local rc = _rc
    assert `rc' != 0
    * a posted-but-failed convergence flag is refused too
    _fc_post, converged(0) enn(100)
    capture assert e(converged) == 1
    local rc = _rc
    assert `rc' != 0
    * (d) a converged fit passes and e(N) is then a posted finite count
    _fc_post, converged(1) enn(100)
    capture assert e(converged) == 1
    local rc = _rc
    assert `rc' == 0
    assert !missing(e(N)) & e(N) == 100
    ereturn clear
}
if _rc == 0 {
    display as result "  PASS: FC-10 W5 e(converged) == 1 precondition"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-10 W5 e(converged) == 1 precondition (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-11 W6: a trailing !missing() on posted content, and the two structural
*           closures that stand behind it
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    * Structural closure 1: `ereturn post' REFUSES a coefficient vector holding
    * a missing value, so `assert !missing(el(e(b), 1, 1))' can only fire on a
    * hand-built e(b); the reachable missing-content case is a posted scalar.
    tempname bmiss Vok
    matrix `bmiss' = (., 0.5)
    matrix `Vok'   = I(2)
    matrix colnames `bmiss' = x1 x2
    matrix colnames `Vok'   = x1 x2
    matrix rownames `Vok'   = x1 x2
    capture ereturn post `bmiss' `Vok'
    local rc = _rc
    assert `rc' != 0
    display as text "  FC-11 ereturn post with a missing coefficient: rc=`rc'"

    * Structural closure 2: colsof(e(b)) on an absent e(b) is a type mismatch,
    * not a silently satisfied inequality.
    ereturn clear
    capture assert colsof(e(b)) > 0
    local rc = _rc
    assert `rc' != 0

    * The reachable case: a posted fit whose log likelihood is missing.  The
    * inequality-only shape passes; the trailing !missing() refuses.
    _fc_post, converged(1) enn(100) ll(.)
    capture assert e(N) > 0 & colsof(e(b)) > 0
    local rc = _rc
    assert `rc' == 0
    capture assert !missing(el(e(b), 1, 1)) & !missing(e(ll))
    local rc = _rc
    assert `rc' != 0
    * (d) finite content passes
    _fc_post, converged(1) enn(100) ll(-42.5)
    capture assert !missing(el(e(b), 1, 1)) & !missing(e(ll))
    local rc = _rc
    assert `rc' == 0
    ereturn clear
}
if _rc == 0 {
    display as result "  PASS: FC-11 W6 trailing !missing() on posted content"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-11 W6 trailing !missing() on posted content (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* FC-12 The T98 site repaired on 2026-09-04, reproduced as a construct.  It is
*       the only audited site where BOTH legs of the check were fail-open at
*       once, and it is fail-open only when the MAIN EFFECT column is missing
*       as well -- which is exactly the failure mode the check exists to catch
*       (a design build that produced nothing).  Both regimes are pinned here.
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 50
    gen double base = .
    gen double ifp  = _n
    gen double prod = .
    _fc_post, enn(50)

    * (b) design build produced nothing: BOTH pre-fix legs pass.
    * reldif(., .) == 0, so the product check counts zero discrepancies, and
    * summarize's missing r(sd) compares greater than 0.
    quietly count if reldif(prod, base * ifp) > 1e-12
    assert r(N) == 0
    capture assert r(N) == 0
    local rc = _rc
    assert `rc' == 0
    quietly summarize prod
    capture assert r(sd) > 0
    local rc = _rc
    assert `rc' == 0

    * (c) the repaired form refuses all three ways
    quietly count if !missing(prod, base, ifp)
    capture assert r(N) == e(N)
    local rc = _rc
    assert `rc' != 0
    quietly summarize prod
    capture assert r(N) == e(N)
    local rc = _rc
    assert `rc' != 0
    capture assert !missing(r(sd))
    local rc = _rc
    assert `rc' != 0

    * The neighbouring regime, measured rather than assumed: when the main
    * effect is FINITE and only the product column is missing, reldif(., finite)
    * is itself missing, missing > 1e-12 is true, and the pre-fix product leg
    * already refused.  The pre-fix hole was the all-missing-design case above.
    quietly replace base = mod(_n, 2)
    quietly count if reldif(prod, base * ifp) > 1e-12
    assert r(N) == 50
    capture assert r(N) == 0
    local rc = _rc
    assert `rc' != 0

    * (d) the correct product passes every leg, and a WRONG product is refused
    quietly replace prod = base * ifp
    quietly count if !missing(prod, base, ifp)
    capture assert r(N) == e(N)
    local rc = _rc
    assert `rc' == 0
    quietly count if reldif(prod, base * ifp) > 1e-12
    capture assert r(N) == 0
    local rc = _rc
    assert `rc' == 0
    quietly summarize prod
    capture assert r(N) == e(N) & !missing(r(sd)) & r(sd) > 0
    local rc = _rc
    assert `rc' == 0
    quietly replace prod = base * ifp + 1
    quietly count if reldif(prod, base * ifp) > 1e-12
    capture assert r(N) == 0
    local rc = _rc
    assert `rc' != 0
    ereturn clear
}
if _rc == 0 {
    display as result "  PASS: FC-12 T98 interaction-column identity, repaired form"
    local ++pass_count
}
else {
    display as error "  FAIL: FC-12 T98 interaction-column identity (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
capture program drop _fc_post

display _newline as text "RESULT: test_finegray_failclosed tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "test_finegray_failclosed: `fail_count' check(s) FAILED"
    capture log close _fclosed
    exit 9
}

display as result "test_finegray_failclosed: all `test_count' guard constructs are fail-closed"
capture log close _fclosed

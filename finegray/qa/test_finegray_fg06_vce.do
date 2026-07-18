* test_finegray_fg06_vce.do
* Regression tests for the delayed-entry variance CONTRACT (FG-06).
*
* The delayed-entry default variance is a FIXED-WEIGHT sandwich: it treats the
* estimated censoring distribution G (and, under delayed entry, the entry
* distribution H) as fixed and does NOT add the Fine-Gray (1999) eq. 7-8 /
* Zhang-Zhang-Fine (2011) nuisance-adjusted term.  It was formerly mislabeled
* e(lt_vce)="fg_sandwich" and attributed to "Fine-Gray eq. 7-8".  It is now
* e(lt_vce)="fixed_weight_sandwich".  For coefficient inference that DOES
* propagate weight estimation, the documented remedy is a whole-fit bootstrap.
*
* Test 1 fails on the pre-FG-06 code, where e(lt_vce)=="fg_sandwich".
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_fg06_vce.log", replace name(_fg06)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_lt06
program define _mk_lt06
    clear
    set seed 20260714
    quietly set obs 1500
    gen long id = _n
    gen double z1 = rnormal()
    gen double z2 = rnormal()
    gen double t0 = runiform() * 2
    gen double t  = t0 + 0.2 + rexponential(1) * exp(-0.4 * z1)
    gen byte ev = cond(runiform() < .5, 1, cond(runiform() < .5, 2, 0))
    quietly replace ev = 0 if t > 8
    quietly replace t = 8 if t > 8
    quietly stset t, failure(ev) id(id) enter(time t0)
end

**# 1. e(lt_vce) reports fixed_weight_sandwich on the delayed-entry default
* On the pre-FG-06 code this is "fg_sandwich" -> the assert fails.
local ++test_count
capture noisily {
    _mk_lt06
    finegray z1 z2, compete(ev) cause(1) nolog
    assert "`e(lt_vce)'" == "fixed_weight_sandwich"
    * norobust path is the model-based inverse information
    finegray z1 z2, compete(ev) cause(1) norobust nolog
    assert "`e(lt_vce)'" == "model_based"
    * the retired mislabel must not reappear anywhere
    finegray z1 z2, compete(ev) cause(1) nolog
    assert "`e(lt_vce)'" != "fg_sandwich"
    assert "`e(lt_vce)'" != "nuisance_adjusted"
}
if _rc == 0 {
    display as result "  PASS: FG06-1 e(lt_vce) = fixed_weight_sandwich (not fg_sandwich)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG06-1 e(lt_vce) contract (rc=`=_rc')"
    local ++fail_count
}

**# 2. no delayed entry -> not_applicable (unchanged right-censoring branch)
local ++test_count
capture noisily {
    clear
    set seed 99
    quietly set obs 800
    gen long id = _n
    gen double z1 = rnormal()
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    finegray z1, compete(ev) cause(1) nolog
    assert "`e(lt_vce)'" == "not_applicable"
}
if _rc == 0 {
    display as result "  PASS: FG06-2 no-LT fit reports not_applicable"
    local ++pass_count
}
else {
    display as error "  FAIL: FG06-2 not_applicable (rc=`=_rc')"
    local ++fail_count
}

**# 3. the documented coefficient-bootstrap recipe runs and yields a coef SE
* This is the remedy the help/README point to for nuisance-adjusted coefficient
* inference.  It must actually work: resample subjects, re-stset, refit, post e(b).
local ++test_count
capture noisily {
    _mk_lt06
    capture program drop _fg_bootfit06
    program define _fg_bootfit06, eclass
        quietly stset t, failure(ev) id(id) enter(time t0)
        quietly finegray z1 z2, compete(ev) cause(1) nolog
    end
    bootstrap _b, reps(40) seed(4321) nodots ///
        cluster(id) idcluster(_newid06) group(id): _fg_bootfit06
    assert e(N_reps) == 40
    assert !missing(_se[z1]) & _se[z1] > 0
    assert !missing(_se[z2]) & _se[z2] > 0
}
if _rc == 0 {
    display as result "  PASS: FG06-3 documented coefficient bootstrap recipe works"
    local ++pass_count
}
else {
    display as error "  FAIL: FG06-3 coefficient bootstrap recipe (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_fg06_vce tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg06
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg06

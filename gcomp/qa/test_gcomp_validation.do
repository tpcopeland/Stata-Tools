* test_gcomp_validation.do - Input validation tests for gcomp v1.1.0
* Coverage: all validation checks added in Part 1 of v1.1.0 update

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace
discard

capture program drop _make_med_data
program define _make_med_data
    clear
    set seed 7701
    set obs 500
    gen double c = rnormal(50, 10)
    gen byte x = rbinomial(1, invlogit(-2 + 0.02 * c))
    gen byte m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
    gen byte y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))
end

capture program drop _make_tv_data
program define _make_tv_data
    clear
    set seed 7702
    set obs 150
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    gen double L = rnormal() + 0.2 * time
    gen byte A = rbinomial(1, invlogit(-0.8 + 0.35 * L))
    gen byte Y = rbinomial(1, invlogit(-1.7 + 0.4 * L + 0.35 * A))
    sort id time
    by id: gen double Alag = A[_n-1]
    by id: gen double Llag = L[_n-1]
    replace Alag = 0 if time == 1
    replace Llag = 0 if time == 1
end

display as text _n "=============================================="
display as text "gcomp v1.1.0 Input Validation Tests"
display as text "=============================================="

**# V1: Valid mediation passes all checks
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert e(tce) != .
}
if _rc == 0 {
    display as result "  PASS: V1 valid mediation passes all checks"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 valid mediation (error `=_rc')"
    local ++fail_count
}

**# V2: Unsupported command in commands()
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: probit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V2 unsupported command (probit) caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 unsupported command (error `=_rc')"
    local ++fail_count
}

**# V3: Missing command for a variable
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V3 missing command for y caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 missing command (error `=_rc')"
    local ++fail_count
}

**# V4: Missing equation for a variable
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V4 missing equation for y caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 missing equation (error `=_rc')"
    local ++fail_count
}

**# V5: Predictor not in dataset
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x z_nonexistent, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: V5 missing predictor z_nonexistent caught rc=111"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 missing predictor (error `=_rc')"
    local ++fail_count
}

**# V6: Outcome in its own equation
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c y) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V6 outcome self-reference caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 outcome self-reference (error `=_rc')"
    local ++fail_count
}

**# V7: Exposure in base_confs
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c x) sim(500) samples(20) seed(42)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V7 exposure in base_confs caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 exposure in base_confs (error `=_rc')"
    local ++fail_count
}

**# V8: Mediator in base_confs
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c m) sim(500) samples(20) seed(42)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V8 mediator in base_confs caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 mediator in base_confs (error `=_rc')"
    local ++fail_count
}

**# V9: Logit on 3-level variable (warning, not error)
local ++test_count
capture noisily {
    _make_med_data
    gen byte m3 = mod(_n, 3)
    gcomp y m3 x c, outcome(y) mediation obe ///
        exposure(x) mediator(m3) ///
        commands(m3: logit, y: logit) ///
        equations(m3: x c, y: m3 x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
}
if _rc == 0 {
    display as result "  PASS: V9 logit on 3-level variable warns but proceeds"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 logit on 3-level variable (error `=_rc')"
    local ++fail_count
}

**# V10: Regress on binary variable (note, not error)
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: regress, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert e(tce) != .
}
if _rc == 0 {
    display as result "  PASS: V10 regress on binary notes but succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 regress on binary (error `=_rc')"
    local ++fail_count
}

**# V11: impute() without imp_cmd()
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) impute(c) sim(500) samples(20) seed(42)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: V11 impute() without imp_cmd() caught as error"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 impute without imp_cmd (error `=_rc')"
    local ++fail_count
}

**# V12: impute() without imp_eq()
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) impute(c) imp_cmd(c: regress) sim(500) samples(20) seed(42)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: V12 impute() without imp_eq() caught as error"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 impute without imp_eq (error `=_rc')"
    local ++fail_count
}

**# V13: imp_cmd() with unsupported command
local ++test_count
capture noisily {
    _make_med_data
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) impute(c) imp_cmd(c: probit) imp_eq(c: x m) ///
        sim(500) samples(20) seed(42)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V13 unsupported imp_cmd (probit) caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V13 unsupported imp_cmd (error `=_rc')"
    local ++fail_count
}

**# V14: Varabbrev restore after validation error
local ++test_count
capture noisily {
    _make_med_data
    set varabbrev on
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: probit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: V14 varabbrev restored after validation error"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 varabbrev leak after validation error (error `=_rc')"
    local ++fail_count
}

**# V15: Data preserved after validation error
local ++test_count
capture noisily {
    _make_med_data
    local orig_N = _N
    local orig_vars : char _dta[_varnames_]
    qui describe, short
    local orig_k = r(k)
    capture noisily gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: probit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    assert _N == `orig_N'
    qui describe, short
    assert r(k) == `orig_k'
}
if _rc == 0 {
    display as result "  PASS: V15 data preserved after validation error"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 data not preserved (error `=_rc')"
    local ++fail_count
}

**# V16: intvars variable not in varlist (time-varying)
local ++test_count
capture noisily {
    _make_tv_data
    gen byte extra_var = 1
    capture noisily gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A extra_var) interventions(A=1, A=0) ///
        sim(50) samples(5) seed(42) eofu
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V16 intvars missing from varlist caught rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 intvars check (error `=_rc')"
    local ++fail_count
}

display _n as text "=============================================="
display as result "Validation tests: `pass_count' passed, `fail_count' failed out of `test_count'"
display as text "=============================================="
if `fail_count' > 0 exit 1

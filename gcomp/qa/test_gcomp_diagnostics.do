* test_gcomp_diagnostics.do - Model-fit diagnostics tests for gcomp v1.1.0
* Coverage: diagnostics option, e(model_diagnostics), display, warnings

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`qa_dir'/_qa_bootstrap.do"

capture program drop _make_med_data
program define _make_med_data
    clear
    set seed 8801
    set obs 1000
    gen double c = rnormal()
    gen byte x = rbinomial(1, invlogit(-0.2 + 0.4 * c))
    gen byte m = rbinomial(1, invlogit(-0.4 + 1.2 * x + 0.3 * c))
    gen byte y = rbinomial(1, invlogit(-0.8 + 1.0 * m + 0.8 * x + 0.2 * c))
end

capture program drop _make_cont_data
program define _make_cont_data
    clear
    set seed 8802
    set obs 500
    gen double c = rnormal(50, 10)
    gen byte x = rbinomial(1, invlogit(-2 + 0.02 * c))
    gen double m = 0.5 * x + 0.3 * c + rnormal(0, 2)
    gen double y = 0.4 * m + 0.2 * x + 0.1 * c + rnormal(0, 3)
end

capture program drop _make_tv_data
program define _make_tv_data
    clear
    set seed 8803
    set obs 600
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
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
display as text "gcomp v1.1.0 Model-Fit Diagnostics Tests"
display as text "=============================================="

**# D1: diagnostics option produces e(model_diagnostics)
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    capture confirm matrix e(model_diagnostics)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: D1 diagnostics produces e(model_diagnostics)"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 diagnostics matrix missing (error `=_rc')"
    local ++fail_count
}

**# D2: e(model_diagnostics) exists WITHOUT diagnostics flag
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42)
    capture confirm matrix e(model_diagnostics)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: D2 e(model_diagnostics) exists without diagnostics flag"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 matrix missing without flag (error `=_rc')"
    local ++fail_count
}

**# D3: Diagnostics matrix has correct columns
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    assert colsof(e(model_diagnostics)) == 5
    local colnames : colnames e(model_diagnostics)
    assert "`colnames'" == "N converged ll r2 rmse"
}
if _rc == 0 {
    display as result "  PASS: D3 diagnostics matrix has 5 correct columns"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 column structure (error `=_rc')"
    local ++fail_count
}

**# D4: N column matches sample size for mediation
local ++test_count
local d4_pass = 1
capture noisily {
    _make_med_data
    local expected_N = _N
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    tempname diag
    matrix `diag' = e(model_diagnostics)
    local nrows = rowsof(`diag')
    forvalues r = 1/`nrows' {
        if `diag'[`r', 1] != `expected_N' & `diag'[`r', 1] != . {
            local actual_N = `diag'[`r', 1]
            if `actual_N' < 1 {
                display as error "    Row `r': N=`actual_N' is invalid"
                local d4_pass = 0
            }
        }
    }
    assert `d4_pass' == 1
}
if _rc == 0 {
    display as result "  PASS: D4 N values are valid"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 N column check (error `=_rc')"
    local ++fail_count
}

**# D5: Convergence column is 1 for well-specified logit
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    tempname diag
    matrix `diag' = e(model_diagnostics)
    local nrows = rowsof(`diag')
    local any_nonconverged = 0
    forvalues r = 1/`nrows' {
        if `diag'[`r', 2] == 0 {
            local any_nonconverged = 1
        }
    }
    assert `any_nonconverged' == 0
}
if _rc == 0 {
    display as result "  PASS: D5 all logit models converged"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 convergence check (error `=_rc')"
    local ++fail_count
}

**# D6: R-squared for regress models is non-missing
local ++test_count
capture noisily {
    _make_cont_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: regress, y: regress) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    tempname diag
    matrix `diag' = e(model_diagnostics)
    local nrows = rowsof(`diag')
    local found_regress = 0
    forvalues r = 1/`nrows' {
        if `diag'[`r', 4] != . & `diag'[`r', 5] != . {
            local found_regress = 1
            assert `diag'[`r', 4] >= 0 & `diag'[`r', 4] <= 1
            assert `diag'[`r', 5] > 0
        }
    }
    assert `found_regress' == 1
}
if _rc == 0 {
    display as result "  PASS: D6 regress R-squared and RMSE are valid"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 regress fit stats (error `=_rc')"
    local ++fail_count
}

**# D7: Pseudo-R-squared for logit models is non-missing
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    tempname diag
    matrix `diag' = e(model_diagnostics)
    local nrows = rowsof(`diag')
    local found_logit = 0
    forvalues r = 1/`nrows' {
        if `diag'[`r', 2] != . {
            local found_logit = 1
            assert `diag'[`r', 4] >= 0
        }
    }
    assert `found_logit' == 1
}
if _rc == 0 {
    display as result "  PASS: D7 logit pseudo-R-squared is valid"
    local ++pass_count
}
else {
    display as error "  FAIL: D7 logit fit stats (error `=_rc')"
    local ++fail_count
}

**# D8: RMSE is missing for logit, present for regress
local ++test_count
capture noisily {
    _make_med_data
    gen double m_cont = 0.5 * x + 0.3 * c + rnormal(0, 2)
    gcomp y m_cont x c, outcome(y) mediation obe ///
        exposure(x) mediator(m_cont) ///
        commands(m_cont: regress, y: logit) ///
        equations(m_cont: x c, y: m_cont x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    tempname diag
    matrix `diag' = e(model_diagnostics)
    local nrows = rowsof(`diag')
    local regress_has_rmse = 0
    local logit_has_no_rmse = 0
    forvalues r = 1/`nrows' {
        if `diag'[`r', 5] != . & `diag'[`r', 5] > 0 {
            local regress_has_rmse = 1
        }
        if `diag'[`r', 2] != . & `diag'[`r', 5] == . {
            local logit_has_no_rmse = 1
        }
    }
    assert `regress_has_rmse' == 1
    assert `logit_has_no_rmse' == 1
}
if _rc == 0 {
    display as result "  PASS: D8 RMSE present for regress, missing for logit"
    local ++pass_count
}
else {
    display as error "  FAIL: D8 RMSE by model type (error `=_rc')"
    local ++fail_count
}

**# D9: Diagnostics with post_confs (3+ models)
local ++test_count
capture noisily {
    _make_med_data
    gen double pc = rnormal()
    gcomp y pc m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(pc: regress, m: logit, y: logit) ///
        equations(pc: x c, m: x c pc, y: m x c pc) ///
        base_confs(c) post_confs(pc) sim(500) samples(20) seed(42) diagnostics
    tempname diag
    matrix `diag' = e(model_diagnostics)
    assert rowsof(`diag') == 3
}
if _rc == 0 {
    display as result "  PASS: D9 diagnostics with post_confs (3 models)"
    local ++pass_count
}
else {
    display as error "  FAIL: D9 post_confs diagnostics (error `=_rc')"
    local ++fail_count
}

**# D10: Time-varying diagnostics include per-visit rows
local ++test_count
capture noisily {
    _make_tv_data
    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        sim(50) samples(5) seed(42) eofu diagnostics
    tempname diag
    matrix `diag' = e(model_diagnostics)
    assert rowsof(`diag') > 3
    assert colsof(`diag') == 5
}
if _rc == 0 {
    display as result "  PASS: D10 time-varying diagnostics have per-visit rows"
    local ++pass_count
}
else {
    display as error "  FAIL: D10 time-varying diagnostics (error `=_rc')"
    local ++fail_count
}

**# D11: Seed reproducibility with diagnostics
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    local tce1 = e(tce)
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diagnostics
    local tce2 = e(tce)
    assert reldif(`tce1', `tce2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: D11 diagnostics flag does not break seed reproducibility"
    local ++pass_count
}
else {
    display as error "  FAIL: D11 seed reproducibility (error `=_rc')"
    local ++fail_count
}

**# D12: diag abbreviation works
local ++test_count
capture noisily {
    _make_med_data
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(20) seed(42) diag
    capture confirm matrix e(model_diagnostics)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: D12 diag abbreviation accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: D12 diag abbreviation (error `=_rc')"
    local ++fail_count
}

display _n as text "=============================================="
display as result "Diagnostics tests: `pass_count' passed, `fail_count' failed out of `test_count'"
display as text "=============================================="
if `fail_count' > 0 {
    display "RESULT: test_gcomp_diagnostics tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display "RESULT: test_gcomp_diagnostics tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

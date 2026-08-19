* test_fit_sample_loss.do - Component-model estimation-sample warning regressions
* The separation fixture has a known direct-fit N of 1,485 from 2,000 rows.

clear all
version 16.0
set linesize 255

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

capture program drop _gc_make_sample_loss
program define _gc_make_sample_loss, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        clear
        set seed 424242
        set obs 2000
        gen double c = rnormal()
        gen byte x = floor(runiform() * 3)
        gen double mu = exp(-0.1 + 0.8 * x + 0.2 * c)
        gen int m = rpoisson(rgamma(2, mu * 0.5))
        gen byte y = 0
        replace y = rbinomial(1, invlogit(-1.2 + 0.35 * m + 0.25 * x + 0.1 * c)) if m > 0
        recode m (0=0) (1=1) (2=2) (3=3) (4/max=4), gen(mcat)
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _gc_make_clean
program define _gc_make_clean, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        clear
        set seed 424243
        set obs 1000
        gen double c = rnormal()
        gen byte x = rbinomial(1, invlogit(-0.2 + 0.3 * c))
        gen byte m = rbinomial(1, invlogit(-0.4 + 0.8 * x + 0.2 * c))
        gen byte y = rbinomial(1, invlogit(-1.0 + 0.5 * m + 0.4 * x + 0.2 * c))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _gc_make_tv_sample_loss
program define _gc_make_tv_sample_loss, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        clear
        set seed 424244
        set obs 600
        gen long id = ceil(_n / 3)
        bysort id: gen byte time = _n
        gen byte Z = mod(id, 2)
        gen double L0 = rnormal()
        bysort id (time): replace L0 = L0[1]
        gen byte A = rbinomial(1, invlogit(-0.3 + 0.2 * L0))
        gen double L = 0.4 * L0 + 0.2 * A + rnormal()
        sort id time
        by id: gen double Alag = A[_n - 1]
        by id: gen double Llag = L[_n - 1]
        replace Alag = 0 if time == 1
        replace Llag = 0 if time == 1
        gen byte Y = 0
        replace Y = rbinomial(1, invlogit(-0.8 + 0.3 * Alag + ///
            0.2 * Llag + 0.1 * L0)) if time == 3 & Z == 1
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _gc_log_has_sample_warning
program define _gc_log_has_sample_warning, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _file_open = 0
    capture noisily {
        args path
        local _found = 0
        capture file close _gcwarnfh
        file open _gcwarnfh using `"`path'"', read text
        local _file_open = 1
        file read _gcwarnfh _line
        while r(eof) == 0 {
            if strpos(`"`macval(_line)'"', "eligible observations") local _found = 1
            file read _gcwarnfh _line
        }
        file close _gcwarnfh
        local _file_open = 0
        return scalar found = `_found'
    }
    local rc = _rc
    if `_file_open' capture file close _gcwarnfh
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

**# Exact separation warning

**## Warning without diagnostics
local ++test_count
tempfile _lossbase
local _losslog "`_lossbase'.txt"
capture log close _gc_loss
capture noisily {
    _gc_make_sample_loss
    quietly logit y i.mcat i.x c
    assert e(N) == 1485
    log using "`_losslog'", text replace name(_gc_loss)
    gcomp y mcat x c, outcome(y) mediation oce exposure(x) mediator(mcat) ///
        commands(mcat: ologit, y: logit) ///
        equations(mcat: i.x c, y: i.mcat i.x c) ///
        base_confs(c) baseline(0) sim(300) samples(2) seed(11)
    log close _gc_loss
    _gc_log_has_sample_warning "`_losslog'"
    assert r(found) == 1

    capture file close _gcwarnfh
    file open _gcwarnfh using "`_losslog'", read text
    local _found_exact = 0
    file read _gcwarnfh _line
    while r(eof) == 0 {
        if strpos(`"`macval(_line)'"', "logit model for y used 1485 of 2000 eligible observations; 515 rows omitted") local _found_exact = 1
        file read _gcwarnfh _line
    }
    file close _gcwarnfh
    assert `_found_exact' == 1
}
local _test_rc = _rc
capture log close _gc_loss
capture file close _gcwarnfh
if `_test_rc' == 0 {
    display as result "  PASS: sample-loss warning reports y and the exact 515-row shortfall"
    local ++pass_count
}
else {
    display as error "  FAIL: sample-loss warning without diagnostics (error `_test_rc')"
    local ++fail_count
}

**## Warning with diagnostics
local ++test_count
tempfile _diagbase
local _diaglog "`_diagbase'.txt"
capture log close _gc_diag
capture noisily {
    _gc_make_sample_loss
    log using "`_diaglog'", text replace name(_gc_diag)
    gcomp y mcat x c, outcome(y) mediation oce exposure(x) mediator(mcat) ///
        commands(mcat: ologit, y: logit) ///
        equations(mcat: i.x c, y: i.mcat i.x c) ///
        base_confs(c) baseline(0) sim(300) samples(2) seed(11) diagnostics
    log close _gc_diag
    _gc_log_has_sample_warning "`_diaglog'"
    assert r(found) == 1
}
local _test_rc = _rc
capture log close _gc_diag
capture file close _gcwarnfh
if `_test_rc' == 0 {
    display as result "  PASS: diagnostics does not gate the sample-loss warning"
    local ++pass_count
}
else {
    display as error "  FAIL: sample-loss warning with diagnostics (error `_test_rc')"
    local ++fail_count
}

**## Time-varying outcome warning
local ++test_count
tempfile _tvbase
local _tvlog "`_tvbase'.txt"
capture log close _gc_tv
capture noisily {
    _gc_make_tv_sample_loss
    quietly logit Y i.Z Alag Llag L0 if time == 3
    assert e(N) == 100
    log using "`_tvlog'", text replace name(_gc_tv)
    gcomp Y L0 Z A L Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0 Z) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L Z, Y: i.Z Alag Llag L0, ///
            L: Alag Llag L0 Z) intvars(A) interventions(A=1, A=0) ///
        sim(50) samples(2) seed(42) eofu
    log close _gc_tv
    _gc_log_has_sample_warning "`_tvlog'"
    assert r(found) == 1

    capture file close _gcwarnfh
    file open _gcwarnfh using "`_tvlog'", read text
    local _found_exact = 0
    file read _gcwarnfh _line
    while r(eof) == 0 {
        if strpos(`"`macval(_line)'"', "logit model for Y (t=3) used 100 of 200 eligible observations; 100 rows omitted") local _found_exact = 1
        file read _gcwarnfh _line
    }
    file close _gcwarnfh
    assert `_found_exact' == 1
}
local _test_rc = _rc
capture log close _gc_tv
capture file close _gcwarnfh
if `_test_rc' == 0 {
    display as result "  PASS: time-varying outcome warning reports the exact visit shortfall"
    local ++pass_count
}
else {
    display as error "  FAIL: time-varying outcome warning (error `_test_rc')"
    local ++fail_count
}

**# No-warning controls

**## Complete clean specification
local ++test_count
tempfile _cleanbase
local _cleanlog "`_cleanbase'.txt"
capture log close _gc_clean
capture noisily {
    _gc_make_clean
    log using "`_cleanlog'", text replace name(_gc_clean)
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) sim(300) samples(2) seed(12)
    log close _gc_clean
    _gc_log_has_sample_warning "`_cleanlog'"
    assert r(found) == 0
}
local _test_rc = _rc
capture log close _gc_clean
capture file close _gcwarnfh
if `_test_rc' == 0 {
    display as result "  PASS: complete component fits emit no sample-loss warning"
    local ++pass_count
}
else {
    display as error "  FAIL: clean specification warning control (error `_test_rc')"
    local ++fail_count
}

**## Declared imputation exclusion
local ++test_count
tempfile _impbase
local _implog "`_impbase'.txt"
capture log close _gc_imp
capture noisily {
    _gc_make_clean
    gen double z = rnormal()
    replace c = . in 1/100
    replace z = . in 1/50
    log using "`_implog'", text replace name(_gc_imp)
    gcomp y m x c z, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) impute(c) imp_cmd(c: regress) imp_eq(c: z) ///
        imp_cycles(3) sim(300) samples(2) seed(13)
    log close _gc_imp
    assert e(impute_dropped_1) == 50
    _gc_log_has_sample_warning "`_implog'"
    assert r(found) == 0
}
local _test_rc = _rc
capture log close _gc_imp
capture file close _gcwarnfh
if `_test_rc' == 0 {
    display as result "  PASS: declared imputation exclusions emit no spurious warning"
    local ++pass_count
}
else {
    display as error "  FAIL: imputation exclusion warning control (error `_test_rc')"
    local ++fail_count
}

**# Summary

display as result "test_fit_sample_loss Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_fit_sample_loss tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display "RESULT: test_fit_sample_loss tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

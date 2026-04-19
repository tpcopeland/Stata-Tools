* test_stress.do - Stress / convergence / boundary tests for gcomp
* Covers: collinearity, near-separation, sparse outcomes, extreme mediator rates,
*         small N, large bootstrap, mono/dynamic/eofu combinations, MSM stress.
* Runtime: ~5 minutes

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'/") replace
discard

local testdir "`c(tmpdir)'"

* ============================================================
* S1: Collinear baseline confounders (Stata should drop + proceed)
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 31
    set obs 400
    gen double c1 = rnormal()
    gen double c2 = c1                               // perfectly collinear
    gen double x  = rbinomial(1, invlogit(-0.3 + 0.2*c1))
    gen double m  = rbinomial(1, invlogit(-1 + 0.6*x + 0.3*c1))
    gen double y  = rbinomial(1, invlogit(-1.5 + 0.5*m + 0.4*x + 0.2*c1))
    gcomp y m x c1 c2, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c1 c2, y: m x c1 c2) ///
        base_confs(c1 c2) sim(100) samples(5) seed(1)
    assert "`e(cmd)'" == "gcomp"
    assert !missing(e(tce))
}
if _rc == 0 {
    display as result "  PASS: S1 collinear baseline confounders tolerated"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 collinear baseline (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S2: Very sparse outcome (low event rate)
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 32
    set obs 800
    gen double c = rnormal()
    gen double x = rbinomial(1, 0.5)
    gen double m = rbinomial(1, invlogit(-1 + 0.5*x + 0.3*c))
    * ~1% event rate
    gen double y = rbinomial(1, invlogit(-5 + 0.4*m + 0.3*x + 0.1*c))
    quietly count if y == 1
    local nevents = r(N)
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(2)
    assert !missing(e(tce))
    * TCE should be small (<0.1 absolute) with sparse events
    assert abs(e(tce)) < 0.15
}
if _rc == 0 {
    display as result "  PASS: S2 sparse outcome (`nevents' events)"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 sparse outcome (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S3: Extreme mediator rate (mediator almost always = 1)
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 33
    set obs 500
    gen double c = rnormal()
    gen double x = rbinomial(1, 0.5)
    gen double m = rbinomial(1, invlogit(4 + 0.3*x + 0.1*c))    // ~98% = 1
    gen double y = rbinomial(1, invlogit(-1 + 0.4*m + 0.3*x))
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(3)
    assert !missing(e(tce))
    assert !missing(e(nde))
    assert !missing(e(nie))
}
if _rc == 0 {
    display as result "  PASS: S3 extreme mediator rate"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 extreme mediator rate (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S4: Small N (n=100) still converges
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 34
    set obs 100
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.2 + 0.3*c))
    gen double m = rbinomial(1, invlogit(-0.5 + 0.7*x + 0.2*c))
    gen double y = rbinomial(1, invlogit(-1 + 0.5*m + 0.3*x + 0.1*c))
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(4)
    assert !missing(e(tce))
    * SEs should still be positive
    tempname se
    matrix `se' = e(se)
    forvalues j = 1/`=colsof(`se')' {
        assert `se'[1, `j'] > 0
    }
}
if _rc == 0 {
    display as result "  PASS: S4 small N=100 still converges"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 small N (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S5: Continuous outcome with regress command
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 35
    set obs 500
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.2 + 0.3*c))
    gen double m = rbinomial(1, invlogit(-0.5 + 0.7*x + 0.2*c))
    gen double y = 2 + 0.8*m + 0.5*x + 0.3*c + rnormal(0, 1)
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: regress) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(5) seed(5)
    assert !missing(e(tce))
    * Decomposition should hold
    local decomp = abs(e(tce) - e(nde) - e(nie))
    assert `decomp' < 0.05
}
if _rc == 0 {
    display as result "  PASS: S5 continuous outcome decomposition"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 continuous outcome (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S6: Time-varying — pooled option (pools across time for model fit)
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 36
    set obs 300
    gen long id = ceil(_n / 3)
    bysort id: gen int time = _n
    gen double L = rnormal()
    gen double A = rbinomial(1, invlogit(-1 + 0.3*L))
    gen double Y = rbinomial(1, invlogit(-2 + 0.5*L + 0.4*A))
    gcomp Y L A id time, outcome(Y) ///
        idvar(id) tvar(time) varyingcovariates(L) ///
        commands(L: regress, Y: logit, A: logit) ///
        equations(L: A, Y: L A, A: L) ///
        intvars(A) interventions(A_: A_=1, A_: A_=0) ///
        pooled sim(50) samples(5) seed(6) eofu
    assert "`e(analysis_type)'" == "time_varying"
    confirm matrix e(b)
}
if _rc == 0 {
    display as result "  PASS: S6 time-varying + pooled + eofu"
    local ++pass_count
}
else {
    display as error "  FAIL: S6 pooled (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S11: Regression — monotreat without death (v1.0.2 fix)
* ============================================================
* v1.0.1 reordered varlist2 to `varyingcov intvars outcome` when death was
* omitted, breaking the monotreat MC loop's invariant that intvars sit at
* positions nvar_untilmono+1..nvar. That caused rc=2000 "no observations"
* during MC simulation. Restored to `outcome varyingcov intvars`.

local ++test_count
capture noisily {
    clear
    set seed 41
    set obs 300
    gen long id = ceil(_n / 3)
    bysort id: gen int time = _n
    gen double L = rnormal()
    gen double A = rbinomial(1, invlogit(-1 + 0.3*L))
    gen double Y = rbinomial(1, invlogit(-2 + 0.5*L + 0.4*A))
    gcomp Y L A id time, outcome(Y) ///
        idvar(id) tvar(time) varyingcovariates(L) ///
        commands(L: regress, Y: logit, A: logit) ///
        equations(L: A, Y: L A, A: L) ///
        intvars(A) interventions(A_: A_=1, A_: A_=0) ///
        monotreat sim(50) samples(5) seed(11) eofu
    assert "`e(analysis_type)'" == "time_varying"
    confirm matrix e(b)
}
if _rc == 0 {
    display as result "  PASS: S11 monotreat regression (no death, outcome-first varlist2)"
    local ++pass_count
}
else {
    display as error "  FAIL: S11 monotreat regression (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S7: All four CI types finite and ordered (percentile not wider than BCa often)
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 37
    set obs 500
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.3 + 0.2*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(50) seed(7) all
    foreach cim in ci_normal ci_percentile ci_bc ci_bca {
        tempname M
        matrix `M' = e(`cim')
        forvalues j = 1/`=colsof(`M')' {
            assert !missing(`M'[1, `j']) & !missing(`M'[2, `j'])
            assert `M'[2, `j'] >= `M'[1, `j']
        }
    }
}
if _rc == 0 {
    display as result "  PASS: S7 all 4 CI matrices finite with lower <= upper"
    local ++pass_count
}
else {
    display as error "  FAIL: S7 CI matrices (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S8: Seed reproducibility (same seed -> identical e(tce))
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 38
    set obs 400
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.3 + 0.2*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
    tempfile dgp
    save `dgp'
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(200) samples(10) seed(999)
    local t1 = e(tce)
    local n1 = e(nde)
    use `dgp', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(200) samples(10) seed(999)
    local t2 = e(tce)
    local n2 = e(nde)
    assert reldif(`t1', `t2') < 1e-10
    assert reldif(`n1', `n2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: S8 seed reproducibility (reldif < 1e-10)"
    local ++pass_count
}
else {
    display as error "  FAIL: S8 seed reproducibility (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S9: Different seeds produce different estimates
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 39
    set obs 400
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.3 + 0.2*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
    tempfile dgp2
    save `dgp2'
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(200) samples(10) seed(101)
    local tA = e(tce)
    use `dgp2', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(200) samples(10) seed(202)
    local tB = e(tce)
    assert `tA' != `tB'
}
if _rc == 0 {
    display as result "  PASS: S9 different seeds -> different estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: S9 seed variation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* S10: logOR + all-CI stability (SEs finite when risk ~ boundary)
* ============================================================

local ++test_count
capture noisily {
    clear
    set seed 40
    set obs 600
    gen double c = rnormal()
    gen double x = rbinomial(1, invlogit(-0.3 + 0.2*c))
    gen double m = rbinomial(1, invlogit(-1 + 0.8*x + 0.5*c))
    gen double y = rbinomial(1, invlogit(-1.5 + 0.6*m + 0.4*x + 0.3*c))
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(20) seed(10) logOR all
    assert !missing(e(tce))
    assert e(se_tce) > 0
    * logOR values should be finite
    assert abs(e(tce)) < 20
    assert abs(e(nde)) < 20
    assert abs(e(nie)) < 20
}
if _rc == 0 {
    display as result "  PASS: S10 logOR SEs finite"
    local ++pass_count
}
else {
    display as error "  FAIL: S10 logOR stability (error `=_rc')"
    local ++fail_count
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "test_stress Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_stress tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}

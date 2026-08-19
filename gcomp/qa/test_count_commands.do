* test_count_commands.do - Poisson and NB2 component-model contracts
* Oracles: known count DGP, independent gamma-Poisson simulation, saved draws,
*   validation errors, and count-model imputation smoke

clear all
version 16.0
set linesize 255

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

capture program drop _gc_count_dgp
program define _gc_count_dgp, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , OBS(integer) SEED(integer) [POISSON]
        clear
        set seed `seed'
        set obs `obs'
        gen double c = rnormal()
        gen byte x = rbinomial(1, invlogit(-0.2 + 0.25 * c))
        gen double mu = exp(-0.15 + 0.55 * x + 0.20 * c)
        if "`poisson'" == "" {
            gen long m = rpoisson(rgamma(2, 0.5 * mu))
        }
        else {
            gen long m = rpoisson(mu)
        }
        gen double y = 0.20 + 0.35 * x + 0.55 * m + 0.15 * c + rnormal(0, 0.40)
        drop mu
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

**# C1: NB2 mediation recovers its analytic decomposition and saves count draws

local ++test_count
tempfile _c1data _c1saved
capture noisily {
    _gc_count_dgp, obs(5000) seed(52001)
    gen double _mu0 = exp(-0.15 + 0.20 * c)
    gen double _mu1 = exp(-0.15 + 0.55 + 0.20 * c)
    quietly summarize _mu0, meanonly
    local _mean0 = r(mean)
    quietly summarize _mu1, meanonly
    local _mean1 = r(mean)
    local _true_nde = 0.35
    local _true_nie = 0.55 * (`_mean1' - `_mean0')
    local _true_tce = `_true_nde' + `_true_nie'
    drop _mu0 _mu1
    save `_c1data'

    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: nbreg, y: regress) equations(m: x c, y: m x c) ///
        base_confs(c) sim(5000) samples(2) seed(52001) diagnostics ///
        saving(`"`_c1saved'"') replace

    assert abs(e(tce) - `_true_tce') < 0.10
    assert abs(e(nde) - `_true_nde') < 0.08
    assert abs(e(nie) - `_true_nie') < 0.10
    tempname _diag
    matrix `_diag' = e(model_diagnostics)
    local _diag_rows : rownames `_diag'
    assert "`_diag_rows'" == "m y"
    assert `_diag'[1, 1] == 5000
    assert `_diag'[1, 2] == 1
    assert `_diag'[1, 3] < .
    assert `_diag'[1, 4] < .
    assert missing(`_diag'[1, 5])

    use `"`_c1saved'"', clear
    assert m >= 0 if _int > 0 & !missing(m)
    assert m == floor(m) if _int > 0 & !missing(m)
}
local _test_rc = _rc
capture erase `"`_c1saved'"'
if `_test_rc' == 0 {
    display as result "  PASS: NB2 mediation recovers known effects and saves nonnegative integer draws"
    local ++pass_count
}
else {
    display as error "  FAIL: NB2 DGP recovery/count-draw contract (error `_test_rc')"
    local ++fail_count
}

**# C2: Independent gamma-Poisson standardization agrees with gcomp NB2

local ++test_count
capture noisily {
    use `_c1data', clear
    quietly nbreg m x c, dispersion(mean)
    scalar _gc_alpha = e(alpha)
    scalar _gc_m_b0 = _b[_cons]
    scalar _gc_m_bx = _b[x]
    scalar _gc_m_bc = _b[c]
    quietly regress y m x c
    scalar _gc_y_b0 = _b[_cons]
    scalar _gc_y_bm = _b[m]
    scalar _gc_y_bx = _b[x]
    scalar _gc_y_bc = _b[c]

    expand 3
    bysort c x m y: gen byte _world = _n - 1
    gen byte _mx = (_world == 2)
    gen byte _yx = (_world > 0)
    gen double _mu = exp(_gc_m_b0 + _gc_m_bx * _mx + _gc_m_bc * c)
    gen long _mdraw = rpoisson(rgamma(1 / _gc_alpha, _mu * _gc_alpha))
    gen double _ymean = _gc_y_b0 + _gc_y_bm * _mdraw + _gc_y_bx * _yx + _gc_y_bc * c
    quietly summarize _ymean if _world == 0, meanonly
    local _manual_00 = r(mean)
    quietly summarize _ymean if _world == 1, meanonly
    local _manual_10 = r(mean)
    quietly summarize _ymean if _world == 2, meanonly
    local _manual_11 = r(mean)
    local _manual_tce = `_manual_11' - `_manual_00'
    local _manual_nde = `_manual_10' - `_manual_00'
    local _manual_nie = `_manual_11' - `_manual_10'

    use `_c1data', clear
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: nbreg, y: regress) equations(m: x c, y: m x c) ///
        base_confs(c) sim(5000) samples(2) seed(52002)
    assert abs(e(tce) - `_manual_tce') < 0.10
    assert abs(e(nde) - `_manual_nde') < 0.08
    assert abs(e(nie) - `_manual_nie') < 0.10
}
local _test_rc = _rc
if `_test_rc' == 0 {
    display as result "  PASS: NB2 agrees with an independent fitted gamma-Poisson standardization"
    local ++pass_count
}
else {
    display as error "  FAIL: NB2 manual gamma-Poisson agreement (error `_test_rc')"
    local ++fail_count
}

**# C3: Poisson mediation recovers the same known mean-model decomposition

local ++test_count
tempfile _c3saved
capture noisily {
    _gc_count_dgp, obs(4000) seed(52003) poisson
    gen double _mu0 = exp(-0.15 + 0.20 * c)
    gen double _mu1 = exp(-0.15 + 0.55 + 0.20 * c)
    quietly summarize _mu0, meanonly
    local _mean0 = r(mean)
    quietly summarize _mu1, meanonly
    local _mean1 = r(mean)
    local _true_nie = 0.55 * (`_mean1' - `_mean0')
    local _true_tce = 0.35 + `_true_nie'
    drop _mu0 _mu1

    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: poisson, y: regress) equations(m: x c, y: m x c) ///
        base_confs(c) sim(4000) samples(2) seed(52003) ///
        saving(`"`_c3saved'"') replace
    assert abs(e(tce) - `_true_tce') < 0.10
    assert abs(e(nde) - 0.35) < 0.08
    assert abs(e(nie) - `_true_nie') < 0.10

    use `"`_c3saved'"', clear
    assert m >= 0 if _int > 0 & !missing(m)
    assert m == floor(m) if _int > 0 & !missing(m)
}
local _test_rc = _rc
capture erase `"`_c3saved'"'
if `_test_rc' == 0 {
    display as result "  PASS: Poisson mediation recovers known effects and saves count draws"
    local ++pass_count
}
else {
    display as error "  FAIL: Poisson DGP recovery/count-draw contract (error `_test_rc')"
    local ++fail_count
}

**# C4: Count commands reject non-count targets, unsupported NB1 syntax, and unsupported control values

local ++test_count
capture noisily {
    _gc_count_dgp, obs(500) seed(52004)
    replace m = 1.5 in 1
    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: nbreg, y: regress) equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(2) seed(52004)
    assert _rc == 459

    replace m = 1 in 1
    replace m = -1 in 2
    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: poisson, y: regress) equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(2) seed(52004)
    assert _rc == 459

    replace m = 0 in 2
    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: nbreg dispersion(constant), y: regress) ///
        equations(m: x c, y: m x c) base_confs(c) ///
        sim(100) samples(2) seed(52004)
    assert _rc == 198

    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        control(999) commands(m: nbreg, y: regress) ///
        equations(m: x c, y: m x c) base_confs(c) ///
        sim(100) samples(2) seed(52004)
    assert _rc == 459
}
local _test_rc = _rc
if `_test_rc' == 0 {
    display as result "  PASS: count-family support, NB1, and control validation fail closed"
    local ++pass_count
}
else {
    display as error "  FAIL: count-command validation matrix (error `_test_rc')"
    local ++fail_count
}

**# C5: NB2 and Poisson imputation commands produce usable mediation results

local ++test_count
capture noisily {
    foreach _imp_cmd in nbreg poisson {
        local _poisson_opt ""
        if "`_imp_cmd'" == "poisson" local _poisson_opt "poisson"
        _gc_count_dgp, obs(900) seed(52005) `_poisson_opt'
        replace m = . if runiform() < 0.12
        gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
            commands(m: `_imp_cmd', y: regress) equations(m: x c, y: m x c) ///
            base_confs(c) impute(m) imp_cmd(m: `_imp_cmd') imp_eq(m: x c) ///
            imp_cycles(3) sim(300) samples(2) seed(52005)
        confirm scalar e(tce)
        assert e(tce) < .
    }
}
local _test_rc = _rc
if `_test_rc' == 0 {
    display as result "  PASS: NB2 and Poisson imputation commands return usable mediation results"
    local ++pass_count
}
else {
    display as error "  FAIL: count-command imputation smoke (error `_test_rc')"
    local ++fail_count
}

**# Summary

display as result "test_count_commands Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_count_commands tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display "RESULT: test_count_commands tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

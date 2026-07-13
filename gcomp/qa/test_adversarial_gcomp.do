* test_adversarial_gcomp.do - Adversarial estimator contract tests for gcomp
* Focus: state restoration, data preservation, invalid paths, diagnostics,
*        time-varying panel edge cases, and stochastic reproducibility

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`qa_dir'/_qa_bootstrap.do"

capture program drop _adv_make_med_data
program define _adv_make_med_data
    version 16.0
    syntax, Observations(integer) [NullIndirect]

    clear
    set seed 91001
    set obs `observations'
    gen long rowid = _n
    gen double c = rnormal()
    gen byte x = rbinomial(1, invlogit(-0.45 + 0.35 * c))
    if "`nullindirect'" == "" {
        gen byte m = rbinomial(1, invlogit(-0.80 + 0.85 * x + 0.35 * c))
    }
    else {
        gen byte m = rbinomial(1, invlogit(-0.80 + 0.45 * c))
    }
    gen byte y = rbinomial(1, invlogit(-1.30 + 0.70 * x + 0.45 * m + 0.25 * c))
end

capture program drop _adv_make_tv_data
program define _adv_make_tv_data
    version 16.0
    syntax, Subjects(integer) [Unsorted MISSingfinal]

    clear
    set seed 91002
    set obs `=`subjects' * 3'
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0

    bysort id (time): replace L = 0.10 + 0.60 * L0 + rnormal(0, 0.35) if time == 1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.65 * L + 0.20 * L0)) if time == 1

    bysort id (time): replace L = 0.05 + 0.62 * L[_n-1] - 0.50 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2

    bysort id (time): replace L = 0.02 + 0.58 * L[_n-1] - 0.50 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3

    bysort id (time): replace Alag = A[_n-1] if _n > 1
    bysort id (time): replace Llag = L[_n-1] if _n > 1
    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.25 - 0.85 * A[_n-1] + 0.70 * L[_n-1] + 0.20 * L0)) if time == 3

    if "`missingfinal'" != "" {
        replace Y = . if time == 3
    }
    if "`unsorted'" != "" {
        gen double shuffle = runiform()
        sort shuffle
        drop shuffle
    }
    gen long original_order = _n
end

capture program drop _adv_fit_med
program define _adv_fit_med, eclass
    version 16.0
    syntax [, SIMulations(integer 160) SAMples(integer 5) SEED(integer 7101) DIAGnostics]

    gcomp y m x c rowid, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(`simulations') samples(`samples') seed(`seed') `diagnostics'
end

capture program drop _adv_fit_tv
program define _adv_fit_tv, eclass
    version 16.0
    syntax [, SIMulations(integer 90) SAMples(integer 3) SEED(integer 7201) DIAGnostics]

    gcomp Y L0 A L Alag Llag id time original_order, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        eofu sim(`simulations') samples(`samples') seed(`seed') `diagnostics'
end

capture program drop _adv_make_tv_cont_data
program define _adv_make_tv_cont_data
    version 16.0
    syntax, Subjects(integer)

    clear
    set seed 91003
    set obs `=`subjects' * 3'
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0
    gen double Ycont = .

    bysort id (time): replace L = 0.25 + 0.60 * L0 + rnormal(0, 0.35) if time == 1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.45 + 0.55 * L + 0.20 * L0)) if time == 1
    bysort id (time): replace Ycont = 1 + 0.45 * A + 0.35 * L + 0.20 * L0 + rnormal(0, 0.7) if time == 1

    bysort id (time): replace L = 0.15 + 0.55 * L[_n-1] - 0.35 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.50 * L + 0.20 * L0)) if time == 2
    bysort id (time): replace Ycont = 1 + 0.45 * A + 0.35 * L + 0.20 * L0 + rnormal(0, 0.7) if time == 2

    bysort id (time): replace L = 0.10 + 0.50 * L[_n-1] - 0.35 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.45 * L + 0.20 * L0)) if time == 3
    bysort id (time): replace Ycont = 1 + 0.45 * A + 0.35 * L + 0.20 * L0 + rnormal(0, 0.7) if time == 3

    bysort id (time): replace Alag = A[_n-1] if _n > 1
    bysort id (time): replace Llag = L[_n-1] if _n > 1
end

capture program drop _adv_fit_tv_cont
program define _adv_fit_tv_cont, eclass
    version 16.0
    syntax [, SIMulations(integer 90) SAMples(integer 3) SEED(integer 8701) MSM(string)]

    gcomp Ycont L0 A L Alag Llag id time, outcome(Ycont) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(L: regress, Ycont: regress, A: logit) ///
        equations(L: Alag Llag L0, Ycont: Alag Llag L0, A: L0 L) ///
        intvars(A) interventions(A=1, A=0) ///
        eofu sim(`simulations') samples(`samples') seed(`seed') msm(`msm')
end

**# A1: Mediation success preserves data and restores varabbrev from off
local ++test_count
capture noisily {
    _adv_make_med_data, observations(360)
    tempfile before_a1
    save `before_a1'

    set varabbrev off
    _adv_fit_med, simulations(140) samples(4) seed(7101)

    assert "`c(varabbrev)'" == "off"
    cf _all using `before_a1'

    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
    assert "`e(mediation_type)'" == "obe"
    assert "`e(scale)'" == "RD"
    assert e(N) == 360
    assert e(MC_sims) == 140
    assert e(samples) == 4

    tempname b V se cin effects
    matrix `b' = e(b)
    matrix `V' = e(V)
    matrix `se' = e(se)
    matrix `cin' = e(ci_normal)
    matrix `effects' = e(effects)
    local bcols : colnames `b'
    local secols : colnames `se'
    local vcols : colnames `V'
    assert "`bcols'" == "tce nde nie pm"
    assert "`secols'" == "`bcols'"
    assert "`vcols'" == "`bcols'"
    assert colsof(`cin') == colsof(`b')
    assert rowsof(`cin') == 2
    assert rowsof(`effects') == 4
    assert colsof(`effects') == 4
    forvalues i = 1/4 {
        assert `effects'[`i', 4] >= 0
        assert `effects'[`i', 4] <= 1
    }
}
if _rc == 0 {
    display as result "  PASS: A1 mediation success preserves data, state, and e() contract"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 mediation success contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A1"
}

**# A2: Mediation seed reproducibility and seed sensitivity
local ++test_count
capture noisily {
    _adv_make_med_data, observations(320)
    tempfile med_seed
    save `med_seed'

    _adv_fit_med, simulations(600) samples(4) seed(8101)
    tempname b1
    matrix `b1' = e(b)

    use `med_seed', clear
    _adv_fit_med, simulations(600) samples(4) seed(8101)
    tempname b2
    matrix `b2' = e(b)

    use `med_seed', clear
    _adv_fit_med, simulations(600) samples(4) seed(8102)
    tempname b3
    matrix `b3' = e(b)

    local changed = 0
    forvalues j = 1/`=colsof(`b1')' {
        assert reldif(`b1'[1,`j'], `b2'[1,`j']) < 1e-10
        if reldif(`b1'[1,`j'], `b3'[1,`j']) > 1e-8 {
            local changed = 1
        }
    }
    assert `changed' == 1
}
if _rc == 0 {
    display as result "  PASS: A2 same seed reproduces; different seed changes estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 seed contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A2"
}

**# A3: Invalid equation path preserves data, varabbrev, and prior e()
local ++test_count
capture noisily {
    _adv_make_med_data, observations(300)
    _adv_fit_med, simulations(100) samples(3) seed(8201)
    tempname old_b
    matrix `old_b' = e(b)

    tempfile before_a3
    save `before_a3'
    set varabbrev off
    capture gcomp y m x c rowid, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x typo_missing, y: m x c) ///
        base_confs(c) sim(80) samples(2) seed(8202)
    assert _rc == 111
    assert "`c(varabbrev)'" == "off"
    cf _all using `before_a3'
    assert "`e(cmd)'" == "gcomp"
    tempname now_b
    matrix `now_b' = e(b)
    forvalues j = 1/`=colsof(`old_b')' {
        assert reldif(`old_b'[1,`j'], `now_b'[1,`j']) < 1e-10
    }
}
if _rc == 0 {
    display as result "  PASS: A3 invalid equation path preserves data, state, and prior e()"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 invalid equation path (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A3"
}

**# A4: High-value invalid option combinations fail early with rc 198
local ++test_count
capture noisily {
    _adv_make_med_data, observations(260)
    set varabbrev on

    capture gcomp y m x c rowid, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(x) sim(80) samples(2) seed(8301)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"

    capture gcomp y m x c rowid, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) impute(m) imp_eq(m: x c) ///
        sim(80) samples(2) seed(8302)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"

    capture gcomp y m x c rowid, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) impute(m) imp_cmd(m: poisson) imp_eq(m: x c) ///
        sim(80) samples(2) seed(8303)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: A4 invalid option combinations return rc 198 and restore state"
    local ++pass_count
}
else {
    display as error "  FAIL: A4 invalid option combinations (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A4"
}

**# A5: Unsorted time-varying panels use unique subjects and preserve row order
local ++test_count
capture noisily {
    _adv_make_tv_data, subjects(90) unsorted
    tempfile before_a5
    save `before_a5'
    egen byte id_tag = tag(id)
    quietly count if id_tag
    local unique_subjects = r(N)
    drop id_tag

    _adv_fit_tv, simulations(70) samples(3) seed(8401)
    assert e(N) == `unique_subjects'
    assert e(MC_sims) == 70
    cf _all using `before_a5'

    tempname b
    matrix `b' = e(b)
    assert colsof(`b') == 3
    assert `b'[1,1] >= 0 & `b'[1,1] <= 1
    assert `b'[1,2] >= 0 & `b'[1,2] <= 1
    assert abs(`b'[1,1] - `b'[1,2]) > 0.005
}
if _rc == 0 {
    display as result "  PASS: A5 unsorted time-varying panel keeps subject count and row order"
    local ++pass_count
}
else {
    display as error "  FAIL: A5 unsorted time-varying panel (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A5"
}

**# A6: All-missing final outcomes cannot produce successful eofu output
local ++test_count
capture noisily {
    _adv_make_tv_data, subjects(50) missingfinal
    tempfile before_a6
    save `before_a6'
    set varabbrev on
    capture _adv_fit_tv, simulations(40) samples(2) seed(8501)
    assert _rc != 0
    assert "`c(varabbrev)'" == "on"
    cf _all using `before_a6'
}
if _rc == 0 {
    display as result "  PASS: A6 all-missing final outcomes fail without changing data/state"
    local ++pass_count
}
else {
    display as error "  FAIL: A6 all-missing final outcomes guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A6"
}

**# A7: Diagnostics matrix is posted and scratch matrix is cleaned
local ++test_count
capture noisily {
    _adv_make_tv_data, subjects(80)
    _adv_fit_tv, simulations(60) samples(3) seed(8601) diagnostics

    capture confirm matrix e(model_diagnostics)
    assert _rc == 0
    tempname diag
    matrix `diag' = e(model_diagnostics)
    assert colsof(`diag') == 5
    local colnames : colnames `diag'
    assert "`colnames'" == "N converged ll r2 rmse"
    assert rowsof(`diag') >= 3
    forvalues r = 1/`=rowsof(`diag')' {
        assert `diag'[`r', 1] > 0
        assert `diag'[`r', 1] <= e(N)
        assert inlist(`diag'[`r', 2], 0, 1, .)
    }
    capture confirm matrix _gc_diag_result
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: A7 diagnostics contract and scratch cleanup hold"
    local ++pass_count
}
else {
    display as error "  FAIL: A7 diagnostics contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A7"
}

**# A8: Time-varying eofu continuous outcome is supported with documented syntax
local ++test_count
capture noisily {
    _adv_make_tv_cont_data, subjects(120)
    tempfile before_a8
    save `before_a8'

    _adv_fit_tv_cont, simulations(80) samples(3) seed(8701)
    cf _all using `before_a8'

    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "time_varying"
    assert e(N) == 120
    tempname b
    matrix `b' = e(b)
    assert colsof(`b') == 3
    forvalues j = 1/3 {
        assert `b'[1,`j'] < .
    }
    assert abs(`b'[1,1] - `b'[1,2]) > 0.02
}
if _rc == 0 {
    display as result "  PASS: A8 time-varying eofu continuous outcome succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: A8 time-varying eofu continuous outcome (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A8"
}

**# A9: Time-varying eofu logit MSM succeeds and posts MSM coefficient
local ++test_count
capture noisily {
    _adv_make_tv_data, subjects(120)
    _adv_fit_tv, simulations(80) samples(3) seed(8801)
    tempname no_msm_b
    matrix `no_msm_b' = e(b)

    _adv_make_tv_data, subjects(120)
    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        eofu msm(logit Y A) sim(80) samples(3) seed(8801)

    assert "`e(msm)'" == "logit Y A"
    tempname b
    matrix `b' = e(b)
    local cols : colnames `b'
    assert strpos("`cols'", "A") > 0
    assert colsof(`b') > colsof(`no_msm_b')
    forvalues j = 1/`=colsof(`b')' {
        assert `b'[1,`j'] < .
    }
}
if _rc == 0 {
    display as result "  PASS: A9 time-varying eofu logit MSM succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: A9 time-varying eofu logit MSM (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A9"
}

**# A10: Time-varying eofu regress MSM succeeds for continuous outcome
local ++test_count
capture noisily {
    _adv_make_tv_cont_data, subjects(120)
    _adv_fit_tv_cont, simulations(80) samples(3) seed(8901) msm("regress Ycont A")

    assert "`e(msm)'" == "regress Ycont A"
    tempname b
    matrix `b' = e(b)
    local cols : colnames `b'
    assert strpos("`cols'", "A") > 0
    assert colsof(`b') > 3
    forvalues j = 1/`=colsof(`b')' {
        assert `b'[1,`j'] < .
    }
}
if _rc == 0 {
    display as result "  PASS: A10 time-varying eofu regress MSM succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: A10 time-varying eofu regress MSM (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A10"
}

**# A11: Mediation bootstrap posts full covariance, not diagonal-only V
local ++test_count
capture noisily {
    _adv_make_med_data, observations(420)
    _adv_fit_med, simulations(180) samples(12) seed(9001)

    tempname V se
    matrix `V' = e(V)
    matrix `se' = e(se)
    local k = colsof(`V')
    assert rowsof(`V') == `k'
    assert colsof(`se') == `k'

    local offdiag_nonzero = 0
    forvalues i = 1/`k' {
        assert reldif(sqrt(`V'[`i', `i']), `se'[1, `i']) < 1e-10
        if `i' < `k' {
            forvalues j = `=`i' + 1'/`k' {
                if abs(`V'[`i', `j']) > 1e-12 {
                    local offdiag_nonzero = 1
                }
            }
        }
    }
    assert `offdiag_nonzero' == 1
}
if _rc == 0 {
    display as result "  PASS: A11 mediation bootstrap e(V) keeps covariance terms"
    local ++pass_count
}
else {
    display as error "  FAIL: A11 mediation bootstrap covariance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A11"
}

**# A12: Time-varying bootstrap posts full covariance, not diagonal-only V
local ++test_count
capture noisily {
    _adv_make_tv_data, subjects(160)
    _adv_fit_tv, simulations(110) samples(8) seed(9002)

    tempname V se
    matrix `V' = e(V)
    matrix `se' = e(se)
    local k = colsof(`V')
    assert rowsof(`V') == `k'
    assert colsof(`se') == `k'

    local offdiag_nonzero = 0
    forvalues i = 1/`k' {
        assert reldif(sqrt(`V'[`i', `i']), `se'[1, `i']) < 1e-10
        if `i' < `k' {
            forvalues j = `=`i' + 1'/`k' {
                if abs(`V'[`i', `j']) > 1e-12 {
                    local offdiag_nonzero = 1
                }
            }
        }
    }
    assert `offdiag_nonzero' == 1
}
if _rc == 0 {
    display as result "  PASS: A12 time-varying bootstrap e(V) keeps covariance terms"
    local ++pass_count
}
else {
    display as error "  FAIL: A12 time-varying bootstrap covariance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A12"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED: `failed_tests'"
    display "RESULT: test_adversarial_gcomp tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_adversarial_gcomp tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

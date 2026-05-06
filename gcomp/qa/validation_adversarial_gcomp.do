* validation_adversarial_gcomp.do - Semantic adversarial validation for gcomp
* Focus: known-direction effects, null indirect effects, sorted/unsorted panel
*        equivalence, and zero-result guards

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

capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace
discard

capture program drop _vadv_make_null_indirect
program define _vadv_make_null_indirect
    version 16.0
    syntax, Observations(integer)

    clear
    set seed 92001
    set obs `observations'
    gen double c = rnormal()
    gen byte x = rbinomial(1, invlogit(-0.35 + 0.30 * c))
    gen byte m = rbinomial(1, invlogit(-0.75 + 0.55 * c))
    gen byte y = rbinomial(1, invlogit(-1.20 + 0.80 * x + 0.45 * m + 0.25 * c))
end

capture program drop _vadv_make_cde_data
program define _vadv_make_cde_data
    version 16.0
    syntax, Observations(integer)

    clear
    set seed 92002
    set obs `observations'
    gen double c = rnormal()
    gen byte x = rbinomial(1, invlogit(-0.30 + 0.30 * c))
    gen byte m = rbinomial(1, invlogit(-0.90 + 0.90 * x + 0.35 * c))
    gen byte y = rbinomial(1, invlogit(-1.35 + 0.70 * x + 0.50 * m + 0.25 * c))
end

capture program drop _vadv_make_tv_data
program define _vadv_make_tv_data
    version 16.0
    syntax, Subjects(integer) [Unsorted MissingFinal]

    clear
    set seed 92003
    set obs `=`subjects' * 3'
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0

    bysort id (time): replace L = 0.15 + 0.65 * L0 + rnormal(0, 0.35) if time == 1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.70 * L + 0.20 * L0)) if time == 1

    bysort id (time): replace L = 0.10 + 0.60 * L[_n-1] - 0.55 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2

    bysort id (time): replace L = 0.05 + 0.55 * L[_n-1] - 0.55 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3

    bysort id (time): replace Alag = A[_n-1] if _n > 1
    bysort id (time): replace Llag = L[_n-1] if _n > 1
    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3

    if "`missingfinal'" != "" {
        replace Y = . if time == 3
    }
    if "`unsorted'" != "" {
        gen double shuffle = runiform()
        sort shuffle
        drop shuffle
    }
end

capture program drop _vadv_fit_tv
program define _vadv_fit_tv, eclass
    version 16.0
    syntax [, SIMulations(integer 140) SAMples(integer 4) SEED(integer 9301)]

    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        eofu sim(`simulations') samples(`samples') seed(`seed')
end

**# VA1: Null exposure-to-mediator path yields negligible indirect effect
local ++test_count
capture noisily {
    _vadv_make_null_indirect, observations(1200)
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(700) samples(25) seed(9301)

    assert e(tce) > 0.05
    assert e(nde) > 0.05
    assert abs(e(nie)) < 0.035
    assert abs(e(tce) - e(nde)) < 0.035
    assert abs(e(pm)) < 0.35
}
if _rc == 0 {
    display as result "  PASS: VA1 null mediator path has near-zero NIE"
    local ++pass_count
}
else {
    display as error "  FAIL: VA1 null indirect-effect validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' VA1"
}

**# VA2: control() adds CDE without breaking natural-effect decomposition
local ++test_count
capture noisily {
    _vadv_make_cde_data, observations(900)
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) control(0) sim(600) samples(20) seed(9302)

    tempname b effects
    matrix `b' = e(b)
    matrix `effects' = e(effects)
    assert "`e(mediation_type)'" == "obe"
    assert colsof(`b') == 5
    assert colnumb(`b', "cde") == 5
    assert rowsof(`effects') == 5
    assert e(tce) > 0
    assert e(nde) > 0
    assert e(nie) > 0
    assert abs(e(tce) - (e(nde) + e(nie))) < 0.005
    assert e(cde) > 0
    assert e(se_cde) > 0
}
if _rc == 0 {
    display as result "  PASS: VA2 control() posts CDE and preserves decomposition"
    local ++pass_count
}
else {
    display as error "  FAIL: VA2 CDE/decomposition validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' VA2"
}

**# VA3: Sorted and unsorted panels produce identical time-varying estimates
local ++test_count
capture noisily {
    _vadv_make_tv_data, subjects(140)
    tempfile tv_sorted
    save `tv_sorted'

    _vadv_fit_tv, simulations(110) samples(4) seed(9303)
    tempname b_sorted
    matrix `b_sorted' = e(b)
    local n_sorted = e(N)
    local obs_sorted = e(obs_data)

    use `tv_sorted', clear
    set seed 92004
    gen double shuffle = runiform()
    sort shuffle
    drop shuffle
    tempfile tv_unsorted
    save `tv_unsorted'

    _vadv_fit_tv, simulations(110) samples(4) seed(9303)
    tempname b_unsorted
    matrix `b_unsorted' = e(b)

    assert e(N) == `n_sorted'
    assert reldif(e(obs_data), `obs_sorted') < 1e-10
    forvalues j = 1/`=colsof(`b_sorted')' {
        assert reldif(`b_sorted'[1,`j'], `b_unsorted'[1,`j']) < 1e-10
    }
    use `tv_unsorted', clear
}
if _rc == 0 {
    display as result "  PASS: VA3 sorted and unsorted panels are estimation-equivalent"
    local ++pass_count
}
else {
    display as error "  FAIL: VA3 sorted/unsorted panel equivalence (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' VA3"
}

**# VA4: Time-varying POs obey known ordering under protective treatment DGP
local ++test_count
capture noisily {
    _vadv_make_tv_data, subjects(180)
    _vadv_fit_tv, simulations(140) samples(5) seed(9304)

    tempname b
    matrix `b' = e(b)
    local po_treat = `b'[1,1]
    local po_never = `b'[1,2]
    local po_nat = `b'[1,3]

    assert `po_treat' >= 0 & `po_treat' <= 1
    assert `po_never' >= 0 & `po_never' <= 1
    assert `po_nat' >= 0 & `po_nat' <= 1
    assert abs(`po_treat' - `po_never') > 0.02
    assert `po_treat' < `po_never'
    assert `po_nat' > `po_treat'
    assert `po_nat' < `po_never'
}
if _rc == 0 {
    display as result "  PASS: VA4 time-varying POs follow known protective-treatment ordering"
    local ++pass_count
}
else {
    display as error "  FAIL: VA4 time-varying PO ordering (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' VA4"
}

**# VA5: Empty analysis sample refuses to post usable results
local ++test_count
capture noisily {
    _vadv_make_null_indirect, observations(200)
    replace y = .
    set varabbrev on
    capture gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(100) samples(3) seed(9305)
    assert _rc == 2000
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: VA5 empty analysis sample returns rc 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: VA5 empty analysis sample guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' VA5"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED: `failed_tests'"
    display "RESULT: validation_adversarial_gcomp tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL VALIDATIONS PASSED"
display "RESULT: validation_adversarial_gcomp tests=`test_count' pass=`pass_count' fail=`fail_count'"

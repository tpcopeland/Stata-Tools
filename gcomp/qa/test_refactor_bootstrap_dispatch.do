* test_refactor_bootstrap_dispatch.do - Refactor gate coverage for gcomp bootstrap dispatch
* Coverage: local install, OBE mediation bootstrap contract, time-varying EOFU
*   bootstrap contract, CI matrix naming, diagnostics posting, fixed-seed repeatability

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local testdir "`c(tmpdir)'"

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`testdir'/gcomp_refactor_plus_`install_tag'"
local personal_dir "`testdir'/gcomp_refactor_personal_`install_tag'"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
capture ado uninstall gcomp
quietly net install gcomp, from("`pkg_dir'") replace
discard

**# OBE mediation setup
clear
set seed 202605151
set obs 360
gen double c = rnormal()
gen byte x = rbinomial(1, invlogit(-0.45 + 0.35 * c))
gen byte m = rbinomial(1, invlogit(-0.95 + 0.80 * x + 0.30 * c))
gen byte y = rbinomial(1, invlogit(-1.35 + 0.55 * m + 0.35 * x + 0.25 * c))
tempfile med_data
save `med_data'

**# B1: OBE mediation posts stable bootstrap e() contract
local ++test_count
capture noisily {
    use `med_data', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(140) samples(6) seed(202605151) diagnostics

    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "mediation"
    assert e(N) == _N

    tempname b1 se1 V1 ci1 diag1
    matrix `b1' = e(b)
    matrix `se1' = e(se)
    matrix `V1' = e(V)
    matrix `ci1' = e(ci_normal)
    matrix `diag1' = e(model_diagnostics)

    local expected "tce nde nie pm"
    local bcols : colnames `b1'
    local secols : colnames `se1'
    local Vcols : colnames `V1'
    local Vrows : rownames `V1'
    local cicols : colnames `ci1'
    assert "`bcols'" == "`expected'"
    assert "`secols'" == "`expected'"
    assert "`Vcols'" == "`expected'"
    assert "`Vrows'" == "`expected'"
    assert "`cicols'" == "`expected'"
    assert rowsof(`b1') == 1
    assert colsof(`b1') == 4
    assert rowsof(`se1') == 1
    assert colsof(`se1') == 4
    assert rowsof(`V1') == 4
    assert colsof(`V1') == 4
    assert rowsof(`ci1') == 2
    assert colsof(`ci1') == 4

    forvalues j = 1/4 {
        assert `se1'[1,`j'] > 0
        assert reldif(sqrt(`V1'[`j',`j']), `se1'[1,`j']) < 1e-10
        assert `ci1'[1,`j'] < `ci1'[2,`j']
    }

    assert colsof(`diag1') == 5
    assert rowsof(`diag1') >= 2
    local diagcols : colnames `diag1'
    assert "`diagcols'" == "N converged ll r2 rmse"

    use `med_data', clear
    gcomp y m x c, outcome(y) mediation obe ///
        exposure(x) mediator(m) ///
        commands(m: logit, y: logit) ///
        equations(m: x c, y: m x c) ///
        base_confs(c) sim(140) samples(6) seed(202605151) diagnostics

    tempname b2 se2 V2 ci2 diag2
    matrix `b2' = e(b)
    matrix `se2' = e(se)
    matrix `V2' = e(V)
    matrix `ci2' = e(ci_normal)
    matrix `diag2' = e(model_diagnostics)

    forvalues j = 1/4 {
        assert reldif(`b1'[1,`j'], `b2'[1,`j']) < 1e-10
        assert reldif(`se1'[1,`j'], `se2'[1,`j']) < 1e-10
        assert reldif(`ci1'[1,`j'], `ci2'[1,`j']) < 1e-10
        assert reldif(`ci1'[2,`j'], `ci2'[2,`j']) < 1e-10
        forvalues k = 1/4 {
            assert reldif(`V1'[`j',`k'], `V2'[`j',`k']) < 1e-10
        }
    }

    assert rowsof(`diag1') == rowsof(`diag2')
    assert colsof(`diag1') == colsof(`diag2')
}
if _rc == 0 {
    display as result "  PASS: B1 OBE mediation bootstrap e() contract is stable"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 OBE mediation bootstrap contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B1"
}

**# Time-varying EOFU setup
clear
set seed 202605152
set obs 420
gen long id = ceil(_n / 3)
bysort id: gen byte time = _n
gen double L0 = rnormal()
bysort id (time): replace L0 = L0[1]
gen byte A = .
gen double L = .
gen byte Alag = 0
gen double Llag = 0

bysort id (time): replace L = 0.20 + 0.60 * L0 + rnormal(0, 0.35) if time == 1
bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.65 * L + 0.20 * L0)) if time == 1

bysort id (time): replace L = 0.10 + 0.55 * L[_n-1] - 0.45 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.55 * L + 0.20 * L0)) if time == 2

bysort id (time): replace L = 0.05 + 0.50 * L[_n-1] - 0.45 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.50 * L + 0.20 * L0)) if time == 3

bysort id (time): replace Alag = A[_n-1] if _n > 1
bysort id (time): replace Llag = L[_n-1] if _n > 1

gen byte Y = 0
bysort id (time): replace Y = rbinomial(1, invlogit(-1.30 - 0.80 * A[_n-1] + 0.70 * L[_n-1] + 0.20 * L0)) if time == 3

quietly count if time == 3
local tv_subjects = r(N)
tempfile tv_data
save `tv_data'

**# B2: Time-varying EOFU bootstrap posts stable e() contract
local ++test_count
capture noisily {
    use `tv_data', clear
    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        sim(140) samples(6) seed(202605152) eofu diagnostics

    assert "`e(cmd)'" == "gcomp"
    assert "`e(analysis_type)'" == "time_varying"
    assert e(N) == `tv_subjects'

    tempname tb1 tse1 tV1 tci1 tdiag1
    matrix `tb1' = e(b)
    matrix `tse1' = e(se)
    matrix `tV1' = e(V)
    matrix `tci1' = e(ci_normal)
    matrix `tdiag1' = e(model_diagnostics)

    local expected "PO1 PO2 PO3"
    local bcols : colnames `tb1'
    local secols : colnames `tse1'
    local Vcols : colnames `tV1'
    local Vrows : rownames `tV1'
    local cicols : colnames `tci1'
    assert "`bcols'" == "`expected'"
    assert "`secols'" == "`expected'"
    assert "`Vcols'" == "`expected'"
    assert "`Vrows'" == "`expected'"
    assert "`cicols'" == "`expected'"
    assert rowsof(`tb1') == 1
    assert colsof(`tb1') == 3
    assert rowsof(`tse1') == 1
    assert colsof(`tse1') == 3
    assert rowsof(`tV1') == 3
    assert colsof(`tV1') == 3
    assert rowsof(`tci1') == 2
    assert colsof(`tci1') == 3

    forvalues j = 1/3 {
        assert `tb1'[1,`j'] >= 0 & `tb1'[1,`j'] <= 1
        assert `tse1'[1,`j'] > 0
        assert reldif(sqrt(`tV1'[`j',`j']), `tse1'[1,`j']) < 1e-10
        assert `tci1'[1,`j'] < `tci1'[2,`j']
    }

    assert colsof(`tdiag1') == 5
    assert rowsof(`tdiag1') >= 3
    local diagcols : colnames `tdiag1'
    assert "`diagcols'" == "N converged ll r2 rmse"

    use `tv_data', clear
    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        intvars(A) interventions(A=1, A=0) ///
        sim(140) samples(6) seed(202605152) eofu diagnostics

    tempname tb2 tse2 tV2 tci2 tdiag2
    matrix `tb2' = e(b)
    matrix `tse2' = e(se)
    matrix `tV2' = e(V)
    matrix `tci2' = e(ci_normal)
    matrix `tdiag2' = e(model_diagnostics)

    forvalues j = 1/3 {
        assert reldif(`tb1'[1,`j'], `tb2'[1,`j']) < 1e-10
        assert reldif(`tse1'[1,`j'], `tse2'[1,`j']) < 1e-10
        assert reldif(`tci1'[1,`j'], `tci2'[1,`j']) < 1e-10
        assert reldif(`tci1'[2,`j'], `tci2'[2,`j']) < 1e-10
        forvalues k = 1/3 {
            assert reldif(`tV1'[`j',`k'], `tV2'[`j',`k']) < 1e-10
        }
    }

    assert rowsof(`tdiag1') == rowsof(`tdiag2')
    assert colsof(`tdiag1') == colsof(`tdiag2')
}
if _rc == 0 {
    display as result "  PASS: B2 time-varying EOFU bootstrap e() contract is stable"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 time-varying EOFU bootstrap contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B2"
}

display ""
display as result "test_refactor_bootstrap_dispatch Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_refactor_bootstrap_dispatch tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
}
else {
    display as result "PASS"
}

capture ado uninstall gcomp
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}

* test_gcomp_v201_hotpath.do - Seeded hot-path regression coverage for gcomp 2.0.1
* Coverage: cascading post-death absorption, monotreat reproducibility,
*   and longitudinal imputation reproducibility with exact saved-arm identity

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

capture program drop _hp_make_death
program define _hp_make_death
    version 16.0
    clear
    set seed 33335
    set obs 600
    gen long id = ceil(_n / 3)
    bysort id: gen int time = _n
    gen double c = rnormal()
    bysort id (time): replace c = c[1]
    gen double l = 0.30*c + 0.10*time + rnormal(0, 0.45)
    gen byte a = rbinomial(1, invlogit(-0.20 + 0.45*l + 0.20*c))
    gen byte d = 0
    replace d = rbinomial(1, invlogit(-0.4 + 0.20*c)) if time >= 2
    gen byte y = rbinomial(1, invlogit(-1.2 + 0.55*a + 0.30*l + 0.15*c))
    replace y = 0 if d == 1
    bysort id (time): gen long _prior_deaths = sum(d==1) - (d==1)
    drop if _prior_deaths > 0
    drop _prior_deaths
end

capture program drop _hp_make_tv
program define _hp_make_tv
    version 16.0
    args with_missing
    clear
    set seed 4321
    set obs 500
    gen long id = _n
    gen double L0 = rnormal()
    expand 3
    bysort id: gen byte time = _n
    gen double L = 0
    gen byte A = 0
    gen byte Alag = 0
    gen double Llag = 0
    bysort id (time): replace L = 0.15 + 0.65*L0 + rnormal(0,0.35) if time==1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35+0.70*L+0.20*L0)) if time==1
    bysort id (time): replace L = 0.10 + 0.60*L[_n-1] - 0.55*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if time==2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25+0.60*L+0.20*L0)) if time==2
    bysort id (time): replace A = 1 if time==2 & A[_n-1]==1
    bysort id (time): replace L = 0.05 + 0.55*L[_n-1] - 0.55*A[_n-1] + 0.10*L0 + rnormal(0,0.35) if time==3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15+0.55*L+0.20*L0)) if time==3
    bysort id (time): replace A = 1 if time==3 & A[_n-1]==1
    gen byte M = rbinomial(1, invlogit(-0.2 + 0.4*L + 0.2*L0))
    if `with_missing' replace M = . if runiform() < 0.10
    bysort id (time): replace Alag = A[_n-1] if _n>1
    bysort id (time): replace Llag = L[_n-1] if _n>1
    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.35 - 0.90*A[_n-1] + 0.75*L[_n-1] + 0.25*M[_n-1] + 0.20*L0)) if time==3
end

**# H1: A first simulated death absorbs every later visit
local ++test_count
capture noisily {
    tempfile death_saved
    _hp_make_death
    gcomp y d l a c id time, outcome(y) idvar(id) tvar(time) ///
        varyingcovariates(l) fixedcovariates(c) ///
        commands(d: logit, l: regress, a: logit, y: logit) ///
        equations(d: c time, l: c time, a: c l time, y: a l c time) ///
        intvars(a) interventions(a=1, a=0) death(d) pooled ///
        sim(160) samples(3) seed(202608281) ///
        saving("`death_saved'") replace
    use "`death_saved'", clear
    isid _int _id time
    bysort _int _id (time): gen long _prior_deaths = sum(d==1) - (d==1)
    assert _prior_deaths == 0
    quietly count if _int>0 & d==1 & time<3
    assert !missing(r(N))
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: H1 simulated death absorbs the complete later-visit tail"
    local ++pass_count
}
else {
    display as error "  FAIL: H1 post-death absorption (error `=_rc')"
    local ++fail_count
}

**# H2: Monotreat is exactly reproducible, including saved arms
local ++test_count
capture noisily {
    tempfile mono_data mono_save1 mono_save2
    _hp_make_tv 0
    save `mono_data'
    gcomp Y L0 A L M Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L M) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress, M: logit) ///
        equations(A: L0 L, Y: Alag Llag L0 M, L: Alag Llag L0, M: L L0) ///
        intvars(A) interventions(A=1, A=0) monotreat eofu ///
        sim(120) samples(3) seed(202608282) saving("`mono_save1'") replace
    tempname mb1 mV1
    matrix `mb1' = e(b)
    matrix `mV1' = e(V)
    local mrng1 "`e(rngstate)'"

    use `mono_data', clear
    gcomp Y L0 A L M Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L M) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress, M: logit) ///
        equations(A: L0 L, Y: Alag Llag L0 M, L: Alag Llag L0, M: L L0) ///
        intvars(A) interventions(A=1, A=0) monotreat eofu ///
        sim(120) samples(3) seed(202608282) saving("`mono_save2'") replace
    assert mreldif(`mb1', e(b)) == 0
    assert mreldif(`mV1', e(V)) == 0
    assert "`mrng1'" == "`e(rngstate)'"
    use "`mono_save1'", clear
    unab mono_vars : _all
    quietly describe using "`mono_save2'", varlist
    assert "`mono_vars'" == "`r(varlist)'"
    cf _all using "`mono_save2'"
}
if _rc == 0 {
    display as result "  PASS: H2 monotreat e() and saved arms are exactly reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: H2 monotreat reproducibility (error `=_rc')"
    local ++fail_count
}

**# H3: Longitudinal imputation is exactly reproducible, including saved arms
local ++test_count
capture noisily {
    tempfile imp_data imp_save1 imp_save2
    _hp_make_tv 1
    save `imp_data'
    gcomp Y L0 A L M Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L M) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress, M: regress) ///
        equations(A: L0 L, Y: Alag Llag L0 M, L: Alag Llag L0, M: L L0) ///
        intvars(A) interventions(A=1, A=0) ///
        impute(M) imp_cmd(M: logit) imp_eq(M: L L0) imp_cycles(3) eofu ///
        sim(120) samples(3) seed(202608283) saving("`imp_save1'") replace
    tempname ib1 iV1
    matrix `ib1' = e(b)
    matrix `iV1' = e(V)
    local irng1 "`e(rngstate)'"

    use `imp_data', clear
    gcomp Y L0 A L M Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L M) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress, M: regress) ///
        equations(A: L0 L, Y: Alag Llag L0 M, L: Alag Llag L0, M: L L0) ///
        intvars(A) interventions(A=1, A=0) ///
        impute(M) imp_cmd(M: logit) imp_eq(M: L L0) imp_cycles(3) eofu ///
        sim(120) samples(3) seed(202608283) saving("`imp_save2'") replace
    assert mreldif(`ib1', e(b)) == 0
    assert mreldif(`iV1', e(V)) == 0
    assert "`irng1'" == "`e(rngstate)'"
    use "`imp_save1'", clear
    unab imp_vars : _all
    quietly describe using "`imp_save2'", varlist
    assert "`imp_vars'" == "`r(varlist)'"
    cf _all using "`imp_save2'"
}
if _rc == 0 {
    display as result "  PASS: H3 imputation e() and saved arms are exactly reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: H3 imputation reproducibility (error `=_rc')"
    local ++fail_count
}

display as result "test_gcomp_v201_hotpath Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_gcomp_v201_hotpath tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display "RESULT: test_gcomp_v201_hotpath tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

* test_structural_rules.do - Deterministic structural() fit-and-draw contracts
* Oracles: known row counts, analytic DGP recovery, saved-arm identities, and exact errors

clear all
version 16.0
set linesize 255

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

capture program drop _gc_structural_dgp
program define _gc_structural_dgp, nclass
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

capture program drop _gc_log_has_text
program define _gc_log_has_text, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _file_open = 0
    capture noisily {
        syntax using/, TEXT(string)
        local _found = 0
        capture file close _gcstructfh
        file open _gcstructfh using `"`using'"', read text
        local _file_open = 1
        file read _gcstructfh _line
        while r(eof) == 0 {
            if strpos(`"`macval(_line)'"', `"`text'"') local _found = 1
            file read _gcstructfh _line
        }
        file close _gcstructfh
        local _file_open = 0
        return scalar found = `_found'
    }
    local rc = _rc
    if `_file_open' capture file close _gcstructfh
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

**# S1: Feature-0 DGP recovery, complement N, quiet warning, and saved refit

local ++test_count
tempfile _s1base
local _s1log "`_s1base'.txt"
capture log close _gcs1
capture noisily {
    _gc_structural_dgp
    quietly count if mcat != 0
    assert r(N) == 1485
    log using "`_s1log'", text replace name(_gcs1)
    gcomp y mcat x c, outcome(y) mediation oce exposure(x) mediator(mcat) ///
        commands(mcat: ologit, y: logit) ///
        equations(mcat: i.x c, y: i.mcat i.x c) ///
        structural(y: mcat == 0 => 0) base_confs(c) baseline(0) ///
        sim(6000) samples(2) seed(11) diagnostics showmodels
    log close _gcs1

    assert abs(e(tce_1) - 0.188) < 0.05
    assert abs(e(tce_2) - 0.402) < 0.05
    assert `"`e(structural)'"' == "y: mcat == 0 => 0"
    tempname _diag
    matrix `_diag' = e(model_diagnostics)
    local _diag_rows : rownames `_diag'
    assert "`_diag_rows'" == "mcat y"
    assert `_diag'[2, 1] == 1485
    local _models "`e(model_names)'"
    local _outcome_model : word 2 of `_models'
    estimates restore `_outcome_model'
    assert e(N) == 1485

    _gc_log_has_text using "`_s1log'", text("N = 1485")
    assert r(found) == 1
    _gc_log_has_text using "`_s1log'", text("eligible observations")
    assert r(found) == 0
}
local _test_rc = _rc
capture log close _gcs1
capture file close _gcstructfh
if `_test_rc' == 0 {
    display as result "  PASS: structural outcome recovers the DGP effects and uses the 1,485-row complement"
    local ++pass_count
}
else {
    display as error "  FAIL: structural recovery/complement/refit contract (error `_test_rc')"
    local ++fail_count
}

**# S2: The condition follows the simulated mediator, including under minsim

local ++test_count
tempfile _s2saved
capture noisily {
    clear
    set seed 51002
    set obs 1200
    gen double c = rnormal()
    gen byte x = rbinomial(1, 0.5)
    gen byte m = rbinomial(1, invlogit(-2.2 + 4.4 * x + 0.3 * c))
    gen double y = 0
    replace y = 10 + 0.7 * x + 0.2 * c + rnormal(0, 0.2) if m == 1

    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: regress) equations(m: x c, y: m x c) ///
        structural(y: m == 0 => 0) base_confs(c) minsim ///
        sim(1200) samples(2) seed(51002) saving(`"`_s2saved'"') replace
    use `"`_s2saved'"', clear
    confirm variable _int _id y m x c
    assert y == 0 if _int > 0 & m == 0
    assert y > 1 if _int > 0 & m == 1

    bysort _id: egen byte _obs_m = max(cond(_int == 0, m, .))
    quietly count if _int > 0 & _obs_m == 0 & m == 1
    assert !missing(r(N))
    assert r(N) > 25
    assert y > 1 if _int > 0 & _obs_m == 0 & m == 1
    quietly count if _int > 0 & _obs_m == 1 & m == 0
    assert !missing(r(N))
    assert r(N) > 25
    assert y == 0 if _int > 0 & _obs_m == 1 & m == 0
}
local _test_rc = _rc
capture erase `"`_s2saved'"'
if `_test_rc' == 0 {
    display as result "  PASS: structural assignment follows simulated rather than observed mediator values"
    local ++pass_count
}
else {
    display as error "  FAIL: simulated-value structural condition (error `_test_rc')"
    local ++fail_count
}

**# S3: A structural mediator is forced before the downstream outcome draw

local ++test_count
tempfile _s3saved
capture noisily {
    clear
    set seed 51003
    set obs 1000
    gen double c = rnormal()
    gen byte x = rbinomial(1, 0.5)
    gen byte m = 0
    replace m = rbinomial(1, invlogit(-0.3 + 0.2 * c)) if x == 1
    gen byte y = 0
    replace y = rbinomial(1, invlogit(-1 + 0.2 * x + 0.2 * c)) if m == 1

    quietly count if x == 1
    local _fit_n = r(N)
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        structural(m: x == 0 => 0, y: m == 0 => 0) base_confs(c) ///
        sim(1000) samples(2) seed(51003) saving(`"`_s3saved'"') replace
    tempname _diag
    matrix `_diag' = e(model_diagnostics)
    assert `_diag'[1, 1] == `_fit_n'
    assert `"`e(structural)'"' == "m: x == 0 => 0, y: m == 0 => 0"
    use `"`_s3saved'"', clear
    assert m == 0 if _int > 0 & x == 0
    assert y == 0 if _int > 0 & m == 0
    quietly count if _int > 0 & x == 1 & m == 1
    assert !missing(r(N))
    assert r(N) > 25
    quietly count if _int > 0 & m == 1 & y == 1
    assert !missing(r(N))
    assert r(N) > 0
}
local _test_rc = _rc
capture erase `"`_s3saved'"'
if `_test_rc' == 0 {
    display as result "  PASS: chained structural mediator/outcome rules fit complements and feed downstream simulation"
    local ++pass_count
}
else {
    display as error "  FAIL: structural mediator contract (error `_test_rc')"
    local ++fail_count
}

**# S4: Never-true rules are loud no-ops with exact seeded identity

local ++test_count
tempfile _s4base
local _s4log "`_s4base'.txt"
capture log close _gcs4
capture noisily {
    clear
    set seed 51004
    set obs 700
    gen double c = rnormal()
    gen byte x = rbinomial(1, invlogit(0.2 * c))
    gen byte m = rbinomial(1, invlogit(-0.4 + 0.7 * x + 0.2 * c))
    gen byte y = rbinomial(1, invlogit(-1 + 0.5 * x + 0.8 * m + 0.2 * c))

    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) sim(500) samples(2) seed(51004)
    tempname _b0 _b1 _delta
    matrix `_b0' = e(b)

    log using "`_s4log'", text replace name(_gcs4)
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        structural(y: m == 9 => 0) base_confs(c) ///
        sim(500) samples(2) seed(51004)
    log close _gcs4
    matrix `_b1' = e(b)
    matrix `_delta' = `_b0' - `_b1'
    mata: st_numscalar("_gc_struct_delta", max(abs(st_matrix("`_delta'"))))
    assert _gc_struct_delta == 0
    assert `"`e(structural)'"' == "y: m == 9 => 0"
    _gc_log_has_text using "`_s4log'", text("never true")
    assert r(found) == 1
}
local _test_rc = _rc
capture log close _gcs4
capture file close _gcstructfh
if `_test_rc' == 0 {
    display as result "  PASS: never-true structural rule warns and is exactly seed-identical to no rule"
    local ++pass_count
}
else {
    display as error "  FAIL: never-true no-op identity (error `_test_rc')"
    local ++fail_count
}

**# S5: A controlled setting wholly inside the deterministic set is rejected

local ++test_count
capture noisily {
    clear
    set seed 51005
    set obs 500
    gen double c = rnormal()
    gen byte x = rbinomial(1, 0.5)
    gen byte m = rbinomial(1, invlogit(-0.5 + 0.8 * x + 0.2 * c))
    gen byte y = 0
    replace y = rbinomial(1, invlogit(-1 + 0.4 * x + 0.2 * c)) if m == 1
    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        control(0) commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        structural(y: m == 0 => 0) base_confs(c) ///
        sim(200) samples(2) seed(51005)
    assert _rc == 198
}
local _test_rc = _rc
if `_test_rc' == 0 {
    display as result "  PASS: degenerate controlled direct effect fails with rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: control-inside-structural-set validation (error `_test_rc')"
    local ++fail_count
}

**# S6: Invalid target, dependency, and support contracts fail closed

local ++test_count
capture noisily {
    clear
    set seed 51006
    set obs 500
    gen double c = rnormal()
    gen byte z = mod(_n, 2)
    gen byte x = rbinomial(1, 0.5)
    gen byte m = rbinomial(1, invlogit(-0.5 + 0.8 * x + 0.2 * c))
    gen byte y = rbinomial(1, invlogit(-1 + 0.4 * x + 0.7 * m + 0.2 * c))

    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        structural(y: z == 0 => 0) base_confs(c) sim(100) samples(2)
    assert _rc == 198

    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        structural(y: m == 0 => 2) base_confs(c) sim(100) samples(2)
    assert _rc == 459

    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        structural(c: x == 0 => 0) base_confs(c) sim(100) samples(2)
    assert _rc == 198

    capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        structural(m: y == 0 => 0) base_confs(c) sim(100) samples(2)
    assert _rc == 198
}
local _test_rc = _rc
if `_test_rc' == 0 {
    display as result "  PASS: structural validation rejects outside, unsupported, unmodelled, and later-node rules"
    local ++pass_count
}
else {
    display as error "  FAIL: structural validation matrix (error `_test_rc')"
    local ++fail_count
}

**# S7: Time-varying outcome rules use the visit-specific complement and draw path

local ++test_count
tempfile _s7saved _s7base
local _s7log "`_s7base'.txt"
capture log close _gcs7
capture noisily {
    clear
    set seed 51007
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

    log using "`_s7log'", text replace name(_gcs7)
    gcomp Y L0 Z A L Alag Llag id time, outcome(Y) idvar(id) tvar(time) ///
        varyingcovariates(L) fixedcovariates(L0 Z) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L Z, Y: i.Z Alag Llag L0, ///
            L: Alag Llag L0 Z) intvars(A) interventions(A=1, A=0) ///
        structural(Y: Z == 0 => 0) sim(50) samples(2) seed(51007) ///
        eofu diagnostics saving(`"`_s7saved'"') replace
    log close _gcs7

    tempname _diag
    matrix `_diag' = e(model_diagnostics)
    local _found_y_n = 0
    local _diag_rows : rownames `_diag'
    forvalues _r = 1/`=rowsof(`_diag')' {
        local _row : word `_r' of `_diag_rows'
        if strpos("`_row'", "Y") & `_diag'[`_r', 1] == 100 {
            local _found_y_n = 1
        }
    }
    assert `_found_y_n' == 1
    _gc_log_has_text using "`_s7log'", text("eligible observations")
    assert r(found) == 0

    use `"`_s7saved'"', clear
    assert Y == 0 if _int > 0 & time == 3 & Z == 0
    quietly count if _int > 0 & time == 3 & Z == 1 & Y == 1
    assert !missing(r(N))
    assert r(N) > 0
}
local _test_rc = _rc
capture log close _gcs7
capture file close _gcstructfh
capture erase `"`_s7saved'"'
if `_test_rc' == 0 {
    display as result "  PASS: time-varying structural outcome uses complement fitting and forced draws"
    local ++pass_count
}
else {
    display as error "  FAIL: time-varying structural outcome contract (error `_test_rc')"
    local ++fail_count
}

**# Summary

display as result "test_structural_rules Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display "RESULT: test_structural_rules tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display "RESULT: test_structural_rules tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

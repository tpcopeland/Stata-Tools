*! validation_fixture_phase2_iivw.do  2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! Numerical scope: estimator relations, raw-double arithmetic and supported6-place export.
*! Friendly numerical prerequisite: approved26 conditional WLS projection draft.
clear all
version 16.0
set more off
set varabbrev off
capture log close _all
tempfile suite_log
log using "`suite_log'", text replace name(phase2)
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_metamorphic.do
do _iivw_fixture_excel.do
capture program drop _phase2_iivw_relation
program define _phase2_iivw_relation, rclass
    version 16.0
    syntax , SOURCE(varname) [WEIGHTED ORDER(numlist)]
    local covars "`source' u"
    if "`order'"!="" {
        local sorted : list sort order
        assert "`sorted'"=="1 2"
        local covars ""
        foreach role of numlist `order' {
            if `role'==1 local covars "`covars' `source'"
            if `role'==2 local covars "`covars' u"
        }
    }
    local wanted_N=_N
    if "`weighted'"!="" {
        iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) nolog
        iivw_fit y `covars', categorical(`source') interaction(`source') timespec(linear) vce(fixed) nolog
    }
    else iivw_fit y `covars', categorical(`source') interaction(`source') timespec(linear) unweighted id(id) time(time) nolog
    assert e(N)==`wanted_N'
    tempname B V P
    matrix `B'=e(b)
    matrix `V'=e(V)
    if "`order'"!="" {
        * Varlist order legitimately changes parameter positions. Use exact
        * unique full identities to align both b and every V cell before the
        * actual unsorted_list helper compares the returned matrices.
        local names : colfullnames `B'
        local unique : list uniq names
        assert "`names'"=="`unique'"
        local canonical : list sort names
        local K=colsof(`B')
        tempname alignedB alignedV
        matrix `alignedB'=J(1,`K',.)
        matrix `alignedV'=J(`K',`K',.)
        local j=0
        foreach name of local canonical {
            local ++j
            local idx=colnumb(`B',"`name'")
            assert !missing(`idx')
            local exact : word `idx' of `names'
            assert "`exact'"=="`name'"
            matrix `alignedB'[1,`j']=`B'[1,`idx']
            local k=0
            foreach name2 of local canonical {
                local ++k
                local idx2=colnumb(`B',"`name2'")
                assert !missing(`idx2')
                local exact2 : word `idx2' of `names'
                assert "`exact2'"=="`name2'"
                matrix `alignedV'[`j',`k']=`V'[`idx',`idx2']
            }
        }
        matrix `B'=`alignedB'
        matrix `V'=`alignedV'
    }
    tempvar fitted
    predict double `fitted', xb
    assert !missing(`fitted')
    * Compare predictions under exactly matching original row identities.
    sort id time
    mkmat `fitted', matrix(`P')
    return matrix B=`B'
    return matrix V=`V'
    return matrix prediction=`P'
    return scalar N=`wanted_N'
end
capture program drop _phase2_iivw_projection
program define _phase2_iivw_projection
    version 16.0
    syntax , EXPECTED(name) PREDICTION(name) [WEIGHT(varname)]
    generate double `prediction'=.
    mata: _p2_w=J(st_nobs(),1,1)
    if "`weight'"!="" mata: _p2_w=st_data(.,"`weight'")
    * Separate QR implementation: all raw time/y rows are used, no e(sample).
    mata: _p2_t=st_data(.,"time");_p2_y=st_data(.,"y");_p2_X=(_p2_t,_p2_t:^2,J(st_nobs(),1,1));_p2_A=sqrt(_p2_w):*_p2_X;assert(rank(_p2_A)==3);_p2_B=qrsolve(_p2_A,sqrt(_p2_w):*_p2_y);st_matrix("`expected'",_p2_B');st_store(.,"`prediction'",_p2_X*_p2_B)
    mata: mata drop _p2_t _p2_y _p2_w _p2_X _p2_A _p2_B
    matrix colnames `expected'=time _iivw_time_sq _cons
end
capture program drop _phase2_iivw_precision
program define _phase2_iivw_precision, rclass
    version 16.0
    args profile
    drop if !visit
    local absbound=1e-7
    if "`profile'"=="large" replace y=12345678.123456789+1234567.89012345*y
    if "`profile'"=="nearzero" {
        replace y=1.23456789012345e-7*y
        local absbound=1e-20
    }
    if "`profile'"=="nearone" {
        replace y=.999999991234567+1.23456789012345e-9*y
        local absbound=2e-13
    }
    assert !missing(y)
    local N=_N
    tempname U W B E
    tempvar wantedU wantedW
    _phase2_iivw_projection, expected(`U') prediction(`wantedU')
    iivw_fit y, timespec(quadratic) unweighted id(id) time(time) nolog
    assert e(N)==`N'
    local names : colnames e(b)
    assert "`names'"=="time _iivw_time_sq _cons"
    matrix `B'=e(b)
    mata: assert(all(abs(st_matrix("`B'"):-st_matrix("`U'")):<(`absbound':+1e-12:*abs(st_matrix("`U'")))))
    predict double _p2_gotU, xb
    assert !missing(_p2_gotU,`wantedU') & abs(_p2_gotU-`wantedU')<`absbound'+1e-12*abs(`wantedU')
    estimates store p2_naive
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) nolog
    assert !missing(_iivw_weight) & _iivw_weight>0
    _phase2_iivw_projection, expected(`W') prediction(`wantedW') weight(_iivw_weight)
    iivw_fit y, timespec(quadratic) vce(fixed) nolog replace
    assert e(N)==`N'
    matrix `B'=e(b)
    mata: assert(all(abs(st_matrix("`B'"):-st_matrix("`W'")):<(`absbound':+1e-12:*abs(st_matrix("`W'")))))
    predict double _p2_gotW, xb
    assert !missing(_p2_gotW,`wantedW') & abs(_p2_gotW-`wantedW')<`absbound'+1e-12*abs(`wantedW')
    estimates store p2_weighted
    tempfile stub marker
    local workbook "`stub'.xlsx"
    iivw_diagnose time, unweighted(p2_naive) weighted(p2_weighted) adjusted(p2_weighted) exogeneity(exogenous) xlsx("`workbook'") sheet(Precision) decimals(6) replace
    matrix `E'=r(estimates)
    assert !missing(`E'[1,1],`E'[2,1])
    assert abs(`E'[1,1]-`U'[1,1])<`absbound'+1e-12*abs(`U'[1,1])
    assert abs(`E'[2,1]-`W'[1,1])<`absbound'+1e-12*abs(`W'[1,1])
    * Existing checker validates actual numerical text C4; expected value comes
    * from independent raw QR, not the package's returned table. At6 places,
    * nearzero legitimately rounds to0; raw-double checks above carry precision.
    local numeric : display %21.17g `U'[1,1]
    shell python3 "`c(pwd)'/tools/check_iivw_format.py" "`workbook'" Precision diagnostics 6 Arial "`numeric'" "`marker'" C4
    confirm file "`marker'"
    erase "`marker'"
    erase "`workbook'"
    local tests=1
    local pass=1
    local fail=0
    foreach route in balance diagnose exogtest {
        local ++tests
        capture noisily {
            local command `"iivw_balance, decimals(8) xlsx("refused_precision.xlsx") replace"'
            if "`route'"=="diagnose" local command `"iivw_diagnose time, unweighted(p2_naive) weighted(p2_weighted) adjusted(p2_weighted) decimals(8) xlsx("refused_precision.xlsx") replace"'
            if "`route'"=="exogtest" local command `"iivw_exogtest y, id(id) time(time) maxfu(4) decimals(8) xlsx("refused_precision.xlsx") replace nolog"'
            _fx_fmt_refusal, command(`command') cause("decimals() must be between 0 and 6")
        }
        local rc=_rc
        if `rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL phase2 IIVW `profile' decimal8 `route' rc=`rc'"
        }
    }
    di "ORACLE phase2 IIVW `profile': raw coefficients/every prediction plus correctly rounded6-place cell"
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
foreach weighted in no yes {
    foreach relation in unsorted codes_multidigit codes_sparse long_names {
        local ++tests
        capture noisily {
            qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
            drop if !visit
            generate byte xcat=mod(floor((id-1)/2),3)+1
            replace y=y+.137*xcat+.071*xcat*time
            local w ""
            if "`weighted'"=="yes" local w weighted
            local v ""
            if "`relation'"!="unsorted" local v "var(xcat)"
            * expect: INVARIANT
            qa_metamorphic `relation', command(_phase2_iivw_relation, source(@var@) `w') returns(r(B) r(V) r(prediction) r(N)) var(xcat) tol(1e-9)
        }
        local rc=_rc
        if `rc'==0 local ++pass
        else {
            local ++fail
            di as error "FAIL phase2 IIVW `weighted' `relation' rc=`rc'"
        }
    }
}
foreach weighted in no yes {
    local ++tests
    capture noisily {
        qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
        drop if !visit
        generate byte xcat=mod(floor((id-1)/2),3)+1
        replace y=y+.137*xcat+.071*xcat*time
        local w ""
        if "`weighted'"=="yes" local w weighted
        * expect: INVARIANT
        qa_metamorphic unsorted_list, command(_phase2_iivw_relation, source(xcat) order(@list@) `w') returns(r(B) r(V) r(prediction) r(N)) list(1 2) tol(1e-9)
        di "ORACLE phase2 IIVW `weighted': actual unsorted_list adapter, exact full b/V identities and every row"
    }
    local rc=_rc
    if `rc'==0 local ++pass
    else {
        local ++fail
        di as error "FAIL phase2 IIVW `weighted' covariate order rc=`rc'"
    }
}
foreach profile in large nearzero nearone {
    local ++tests
    capture noisily {
        qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
        _phase2_iivw_precision `profile'
        local added_tests=r(tests)-1
        local added_pass=r(pass)-1
        local added_fail=r(fail)
    }
    local rc=_rc
    if `rc'==0 {
        local tests=`tests'+`added_tests'
        local pass=`pass'+1+`added_pass'
        local fail=`fail'+`added_fail'
    }
    else {
        local ++fail
        di as error "FAIL phase2 IIVW precision `profile' rc=`rc'"
    }
}
display "RESULT: validation_fixture_phase2_iivw tests=`tests' pass=`pass' fail=`fail' skip=0"
log close phase2
iivw_qa_sandbox_restore
if `fail'>0 exit 1

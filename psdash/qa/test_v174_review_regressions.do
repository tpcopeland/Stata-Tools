* test_v174_review_regressions.do -- one-arm degeneracy, scale invariance, Crump crossing
* Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
capture log close _all
log using test_v174_review_regressions.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0

**# F1: both orientations, raw and weighted, binary and multi-group
foreach k in 2 3 {
    foreach reverse in 0 1 {
        foreach weighted in 0 1 {
            capture noisily {
                clear
                set obs `=3*`k''
                generate byte tr = floor((_n-1)/3)
                generate double ps = .5
                generate double gps0 = 1/3
                generate double gps1 = 1/3
                generate double gps2 = 1/3
                local score "ps"
                local gpsopt ""
                if `k' == 3 {
                    local score ""
                    local gpsopt "psvars(gps0 gps1 gps2)"
                }
                generate double w = 1
                generate double x = mod(_n-1,3)-1
                if `reverse' == 0 replace x = 0 if tr == 1
                else replace x = 0 if tr == 0
                local opt "nowvar"
                if `weighted' local opt "wvar(w)"
                psdash balance tr `score', `gpsopt' covariates(x) `opt' ks
                matrix B = r(balance)
                local expected = cond(`reverse', .a, 0)
                assert B[1,4] == `expected'
                if `weighted' {
                    local adjcol = cond(`k'==2,9,14)
                    assert B[1,`adjcol'] == `expected'
                    assert r(max_vr_adj) == `expected'
                }
                assert r(max_vr_raw) == `expected'
                assert r(n_vr_imbalanced) == 1
                assert !missing(r(n_warnings))
                assert r(n_warnings) > 0
                psdash combined tr `score', `gpsopt' covariates(x) wvar(w) nooverlap noweights nosupport
                assert "`r(verdict)'" == "FAIL"
            }
            local rc = _rc
            local ++tests
            if `rc' local ++fail
            else local ++pass
            display "F1 k=`k' reverse=`reverse' weighted=`weighted' rc=`rc'"
        }
    }
}

**# F2: complete matrices, unequal weights, per-arm scales and missing covariates
foreach k in 2 3 {
    foreach incomplete in 0 1 {
        capture noisily {
            clear
            set obs `=6*`k''
            generate byte tr = floor((_n-1)/6)
            generate double ps = .5
                generate double gps0 = 1/3
                generate double gps1 = 1/3
                generate double gps2 = 1/3
                local score "ps"
                local gpsopt ""
                if `k' == 3 {
                    local score ""
                    local gpsopt "psvars(gps0 gps1 gps2)"
                }
            generate double x = (mod(_n-1,6)-2.5)*cond(tr==1,10,1)
            generate double z = x
            if `incomplete' replace z = .a if mod(_n,6)==1
            generate double w = 1+mod(_n,3)
            psdash balance tr `score', `gpsopt' covariates(x z) wvar(w) ks
            matrix Base = r(balance)
            local warnings = r(n_warnings)
            local findings = r(n_vr_imbalanced)
            forvalues i=1/2 {
                forvalues j=1/`=colsof(Base)' {
                    assert !missing(Base[`i',`j'])
                }
            }
            foreach scale in 1e200 1e-200 {
                replace w = (1+mod(_n,3))*`scale'
                psdash balance tr `score', `gpsopt' covariates(x z) wvar(w) ks
                matrix Scaled = r(balance)
                forvalues i=1/2 {
                    forvalues j=1/`=colsof(Base)' {
                        assert !missing(Scaled[`i',`j'])
                    }
                }
                assert mreldif(Base,Scaled)<1e-12
                assert r(n_warnings)==`warnings'
                assert r(n_vr_imbalanced)==`findings'
            }
            replace w = cond(tr==0,1e200,1e-200)
            psdash balance tr `score', `gpsopt' covariates(x z) wvar(w) ks
            matrix Equal = r(balance)
            local adjcol = cond(`k'==2,9,14)
            assert !missing(Equal[1,`adjcol'])
            assert abs(Equal[1,`adjcol']-100)<1e-10
        }
        local rc = _rc
        local ++tests
        if `rc' local ++fail
        else local ++pass
        display "F2 k=`k' incomplete=`incomplete' rc=`rc'"
    }
}

**# F3: published first inequality crossing on a multiple-crossing distribution
capture noisily {
    clear
    set obs 40
    generate byte tr = _n>20
    generate double ps = .01
    replace ps = .03 if mod(_n-1,20)==4
    replace ps = .07 if inrange(mod(_n-1,20),5,9)
    replace ps = .20 if mod(_n-1,20)==10
    replace ps = .30 if inrange(mod(_n-1,20),11,16)
    replace ps = .40 if mod(_n-1,20)>=17
    generate double inv = 1/(ps*(1-ps))
    quietly summarize inv if inrange(ps,.065,.935), meanonly
    assert r(N)==30
    assert 1/(.065*.935)<=2*r(mean)
    forvalues a=1/64 {
        local alpha=`a'/1000
        quietly summarize inv if inrange(ps,`alpha',1-`alpha'), meanonly
        assert 1/(`alpha'*(1-`alpha'))>2*r(mean)
    }
    psdash support tr ps, crump nograph generate(keep)
    assert abs(r(crump_alpha)-.065)<1e-12
    assert r(N_remaining)==30
    assert keep==(ps>=.065 & ps<=.935)
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
display "F3 rc=`rc'"
**# Undefined both-arm and insufficient variances stay distinct from infinity
foreach k in 2 3 {
    capture noisily {
        clear
        set obs `=3*`k''
        generate byte tr = floor((_n-1)/3)
        generate double w = 1
        generate double x = 0
        psdash balance tr, covariates(x) wvar(w)
        matrix B = r(balance)
        assert B[1,4] == .
        assert r(n_vr_imbalanced) == 0
        replace x = mod(_n-1,3)-1
        replace x = .a if tr==1 & mod(_n-1,3)!=1
        psdash balance tr, covariates(x) wvar(w)
        matrix B = r(balance)
        assert B[1,4] == .
        local adjcol = cond(`k'==2,9,14)
        assert B[1,`adjcol'] == .
        assert r(n_vr_imbalanced) == 0
    }
    local rc = _rc
    local ++tests
    if `rc' local ++fail
    else local ++pass
}

**# No crossing is an error, with caller setting and generated data preserved
capture noisily {
    clear
    set obs 6
    generate byte tr = _n>3
    generate double ps = .0001
    replace ps = 0 in 1
    set varabbrev on
    capture psdash support tr ps, crump nograph generate(keep)
    local rc = _rc
    assert `rc' == 498
    assert "`c(varabbrev)'" == "on"
    capture confirm variable keep
    assert _rc == 111
}
local rc = _rc
local ++tests
if `rc' local ++fail
else local ++pass
display "RESULT: test_v174_review_regressions tests=`tests' pass=`pass' fail=`fail' skip=0"
_psdash_qa_cleanup
log close
if `fail' exit 1

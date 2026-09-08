* test_finegray_entry_state.do -- restored-fit entry metadata and new-data predictions.
* Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_finegray_entry_state.log", text replace
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace
local pass = 0
local fail = 0
capture program drop _fg_entry_fixture
program define _fg_entry_fixture
    clear
    set seed 30922
    quietly set obs 300
    gen long id = _n
    gen double x = rnormal()
    gen double t = 1 + 5*runiform()
    gen byte status = cond(runiform()<.5,1,cond(runiform()<.5,2,0))
    expand 2
    bysort id: gen byte episode = _n
    bysort id: gen double stop = cond(_n==1,t/2,t)
    gen byte event = cond(episode==1,0,status)
    quietly stset stop, id(id) failure(event==1 2)
end
**# A restored single-record fit must ignore a later multiple-record fit's metadata.
foreach target in baseline cif phtest {
    capture noisily {
        _fg_entry_fixture
        quietly finegray x if episode==2, compete(event) cause(1) nolog
        assert e(converged)==1
        assert `"`e(entryvar)'"' == ""
        if "`target'" == "baseline" quietly predict double expected, basecshazard
        if "`target'" == "cif" {
            quietly finegray_cif, at(x=0) attime(2 3) ci nograph
            matrix expected = r(table)
        }
        if "`target'" == "phtest" {
            quietly finegray_phtest
            matrix expected = r(phtest)
        }
        estimates store original
        quietly finegray x, compete(event) cause(1) nolog
        assert e(converged)==1
        assert `"`e(entryvar)'"' == "_fg_entry"
        estimates restore original
        mata: mata clear
        if "`target'" == "baseline" {
            quietly predict double actual, basecshazard
            assert !missing(expected,actual)
            assert abs(expected-actual)<1e-12
        }
        if "`target'" == "cif" {
            quietly finegray_cif, at(x=0) attime(2 3) ci nograph
            matrix actual = r(table)
            mata: assert(!hasmissing(st_matrix("actual")))
            assert mreldif(expected,actual)<1e-12
        }
        if "`target'" == "phtest" {
            quietly finegray_phtest
            matrix actual = r(phtest)
            mata: assert(!hasmissing(st_matrix("actual")))
            assert mreldif(expected,actual)<1e-12
        }
    }
    if _rc local ++fail
    else local ++pass
}
**# Point prediction uses the baseline without an unused entry column on new data.
foreach storage in cache posted {
    capture noisily {
        _fg_entry_fixture
        local option ""
        if "`storage'" == "posted" local option "basehaz"
        quietly finegray x, compete(event) cause(1) nolog `option'
        assert e(converged)==1
        gen double horizon = 2
        quietly predict double cref, cif timevar(horizon)
        quietly predict double href, basecshazard timevar(horizon)
        scalar c0 = cref[1]
        scalar h0 = href[1]
        keep in 1
        keep x horizon
        if "`storage'" == "posted" mata: mata clear
        quietly predict double cnew, cif timevar(horizon)
        quietly predict double hnew, basecshazard timevar(horizon)
        assert !missing(cnew,hnew,c0,h0)
        assert abs(cnew-c0)<1e-12 & abs(hnew-h0)<1e-12
        drop x
        quietly predict double hbare, basecshazard timevar(horizon)
        assert !missing(hbare) & abs(hbare-h0)<1e-12
    }
    if _rc local ++fail
    else local ++pass
}
**# Fractional baseline-stratum keys must survive piecewise boundary lookup.
capture noisily {
    clear
    set obs 400
    set seed 984298
    gen long id = _n
    gen double x = rnormal()
    gen double t = 1+5*runiform()
    gen byte event = cond(runiform()<.5,1,cond(runiform()<.5,2,0))
    gen double bs = cond(mod(id,2),.1,.1+5e-17)
    quietly stset t, id(id) failure(event==1 2)
    quietly finegray x, compete(event) cause(1) tvc(x) tsplit(3) bstrata(bs) nolog
    assert e(converged)==1
    quietly predict double fractional, cif
    replace bs = cond(mod(id,2),1,2)
    quietly finegray x, compete(event) cause(1) tvc(x) tsplit(3) bstrata(bs) nolog
    assert e(converged)==1
    quietly predict double integer, cif
    assert !missing(fractional,integer)
    assert abs(fractional-integer)<1e-12
}
if _rc local ++fail
else local ++pass
display "RESULT: test_finegray_entry_state tests=`=`pass'+`fail'' pass=`pass' fail=`fail'"
log close
if `fail' exit 9

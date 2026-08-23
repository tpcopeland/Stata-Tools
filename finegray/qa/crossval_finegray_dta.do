* crossval_finegray_dta.do - Fine-Gray parity against cmprsk::crr via .dta.
* Seed: 404001. The fixed tied fixture is intentionally not regenerated from CSV.
clear all
set more off
set varabbrev off
version 16.0
set seed 404001

local test_count = 0
local pass_count = 0
local fail_count = 0
local qadir "`c(pwd)'"
local pkg_dir = subinstr("`qadir'", "/qa", "", 1)

capture log close _all
log using "crossval_finegray_dta.log", replace text name(_crossval_finegray_dta)

capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* CVD1: tied causes, one covariate, and Fine--Gray (1999) eq. (7)-(8) variance.
local ++test_count
capture noisily {
    clear
    input double time byte status double z
     1 1 0
     1 0 1
     2 1 1
     2 1 0
     3 1 0
     3 0 1
     4 2 1
     4 1 0
     5 0 1
     5 1 0
     6 1 1
     6 2 1
     7 0 0
     7 1 1
     8 2 0
     8 1 1
     9 0 1
    10 1 0
    11 2 1
    12 0 0
    end

    * Exchange the exact double fixture, rather than a delimited approximation.
    tempfile fixture oracle rcsent
    save "`fixture'", replace
    generate long id = _n
    generate byte anyevent = status != 0
    quietly stset time, failure(anyevent == 1) id(id)
    quietly finegray z, compete(status) cause(1) robust noadjust nuisance nolog
    assert e(converged) == 1
    tempname Bfg Vfg
    matrix `Bfg' = e(b)
    matrix `Vfg' = e(V)
    local b_fg = `Bfg'[1, 1]
    local se_fg = sqrt(`Vfg'[1, 1])
    assert !missing(`b_fg')
    assert !missing(`se_fg')

    * cmprsk::crr defaults to Breslow handling of tied failures and its full
    * censoring-estimation sandwich. nuisance noadjust requests that same
    * variance estimand: no finite-sample N/(N-1) multiplier is left to explain.
    shell Rscript "`qadir'/crossval_finegray_dta_r.R" "`fixture'" "`oracle'" && echo 0 > "`rcsent'" || echo 1 > "`rcsent'"
    confirm file "`rcsent'"
    tempname fh
    file open `fh' using "`rcsent'", read text
    file read `fh' rline
    file close `fh'
    assert real(strtrim("`rline'")) == 0
    confirm file "`oracle'"

    use "`oracle'", clear
    assert _N == 1
    foreach v in beta se n n_tied_cause1 {
        confirm variable `v'
        assert !missing(`v'[1])
    }
    assert n[1] == 20
    assert n_tied_cause1[1] == 2
    local b_r = beta[1]
    local se_r = se[1]
    display as text "finegray beta=" %21.16g `b_fg' " se=" %21.16g `se_fg'
    display as text "cmprsk beta=" %21.16g `b_r' " se=" %21.16g `se_r'
    * The two independent optimizers differ by 6.1e-6 relative on the tied
    * coefficient even when finegray's convergence tolerance is tightened;
    * their full nuisance-sandwich SEs differ by 6.8e-7.  Separate gates retain
    * measured numerical headroom without hiding a 1e-4-level method change.
    assert reldif(`b_fg', `b_r') < 1e-5
    assert reldif(`se_fg', `se_r') < 1e-6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: CVD1 .dta tied coefficient (<1e-5) and nuisance SE (<1e-6) parity vs cmprsk::crr"
}
else {
    local ++fail_count
    display as error "  FAIL: CVD1 .dta tied coefficient or nuisance SE parity vs cmprsk::crr (rc=`=_rc')"
}

display "RESULT: crossval_finegray_dta tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _crossval_finegray_dta
if `fail_count' > 0 exit 1

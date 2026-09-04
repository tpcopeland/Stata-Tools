* crossval_cobalt.do — balance parity against the external R cobalt package
* Usage: cd psdash/qa && stata-mp -b do crossval_cobalt.do

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "crossval_cobalt.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_COBALT_TESTS = 0
global PSDASH_COBALT_PASS = 0
global PSDASH_COBALT_FAIL = 0
global PSDASH_COBALT_FAILED ""

capture program drop _psdash_cobalt_record
program define _psdash_cobalt_record
    args id rc
    global PSDASH_COBALT_TESTS = $PSDASH_COBALT_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_COBALT_PASS = $PSDASH_COBALT_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_COBALT_FAIL = $PSDASH_COBALT_FAIL + 1
        global PSDASH_COBALT_FAILED "$PSDASH_COBALT_FAILED `id'"
    }
end

capture program drop _psdash_cobalt_data
program define _psdash_cobalt_data
    clear
    set obs 12
    generate byte treat = floor((_n - 1) / 4)
    generate double x1 = .
    replace x1 = 1 in 1
    replace x1 = 5 in 2
    replace x1 = 6 in 3
    replace x1 = 8 in 4
    replace x1 = 2 in 5
    replace x1 = 4 in 6
    replace x1 = 7 in 7
    replace x1 = 9 in 8
    replace x1 = 0 in 9
    replace x1 = 3 in 10
    replace x1 = 5 in 11
    replace x1 = 10 in 12
    generate byte x2 = inlist(_n, 2, 3, 4, 7, 8, 10, 12)
    generate double wt = .
    replace wt = 2 in 1
    replace wt = 1 in 2
    replace wt = 2 in 3
    replace wt = 1 in 4
    replace wt = 1 in 5
    replace wt = 2 in 6
    replace wt = 1 in 7
    replace wt = 3 in 8
    replace wt = 3 in 9
    replace wt = 1 in 10
    replace wt = 2 in 11
    replace wt = 2 in 12
end

tempfile cobalt_data cobalt_ref r_dep_ok r_run_ok
capture erase "`r_dep_ok'"
shell Rscript -e "quit(status=ifelse(requireNamespace('cobalt', quietly=TRUE), 0, 1))" > /dev/null 2>&1 && touch "`r_dep_ok'"
capture confirm file "`r_dep_ok'"
if _rc {
    display as text "SKIP (dependency): Rscript or R package cobalt unavailable"
    display as text "RESULT: crossval_cobalt tests=0 pass=0 fail=0 skip=0 skipped=dependency_unavailable"
    _psdash_qa_cleanup
    macro drop PSDASH_COBALT_TESTS PSDASH_COBALT_PASS ///
        PSDASH_COBALT_FAIL PSDASH_COBALT_FAILED
    capture log close _all
    exit 77
}

capture noisily {
    _psdash_cobalt_data
    export delimited treat x1 x2 wt using "`cobalt_data'", replace
    capture erase "`r_run_ok'"
    shell Rscript "`qa_dir'/_cobalt_reference_psdash.R" ///
        "`cobalt_data'" "`cobalt_ref'" && touch "`r_run_ok'"
    confirm file "`r_run_ok'"
    confirm file "`cobalt_ref'"
    import delimited using "`cobalt_ref'", varnames(1) stringcols(_all) clear
    assert _N == 20
    forvalues i = 1/`=_N' {
        local key = metric[`i']
        local cb_`key' = real(value[`i'])
        assert !missing(`cb_`key'')
    }
}
_psdash_cobalt_record cobalt_reference_generated `=_rc'

capture noisily {
    _psdash_cobalt_data
    keep if inlist(treat, 0, 1)
    generate byte treated = (treat == 1)
    psdash balance treated, covariates(x1 x2) wvar(wt)
    matrix B = r(balance)

    assert abs(B[1,3] - `cb_p1_x1_smd_raw') < 1e-10
    assert abs(B[1,4] - `cb_p1_x1_vr_raw') < 1e-10
    assert abs(B[1,5] - `cb_p1_x1_ks_raw') < 1e-10
    assert abs(B[1,8] - `cb_p1_x1_smd_adj') < 1e-10
    assert abs(B[1,9] - `cb_p1_x1_vr_adj') < 1e-10
    assert abs(B[1,10] - `cb_p1_x1_ks_adj') < 1e-10
    assert abs(B[2,3] - `cb_p1_x2_smd_raw') < 1e-10
    assert abs(B[2,5] - `cb_p1_x2_ks_raw') < 1e-10
    assert abs(B[2,8] - `cb_p1_x2_smd_adj') < 1e-10
    assert abs(B[2,10] - `cb_p1_x2_ks_adj') < 1e-10
}
_psdash_cobalt_record binary_balance_matches_cobalt `=_rc'

capture noisily {
    _psdash_cobalt_data
    psdash balance treat, covariates(x1 x2) wvar(wt) reference(0)
    matrix M = r(balance)

    foreach pair in 1 2 {
        local raw_base = (`pair' - 1) * 5
        local adj_base = 10 + (`pair' - 1) * 5
        assert abs(M[1,`raw_base' + 3] - `cb_p`pair'_x1_smd_raw') < 1e-10
        assert abs(M[1,`raw_base' + 4] - `cb_p`pair'_x1_vr_raw') < 1e-10
        assert abs(M[1,`raw_base' + 5] - `cb_p`pair'_x1_ks_raw') < 1e-10
        assert abs(M[1,`adj_base' + 3] - `cb_p`pair'_x1_smd_adj') < 1e-10
        assert abs(M[1,`adj_base' + 4] - `cb_p`pair'_x1_vr_adj') < 1e-10
        assert abs(M[1,`adj_base' + 5] - `cb_p`pair'_x1_ks_adj') < 1e-10
        assert abs(M[2,`raw_base' + 3] - `cb_p`pair'_x2_smd_raw') < 1e-10
        assert abs(M[2,`raw_base' + 5] - `cb_p`pair'_x2_ks_raw') < 1e-10
        assert abs(M[2,`adj_base' + 3] - `cb_p`pair'_x2_smd_adj') < 1e-10
        assert abs(M[2,`adj_base' + 5] - `cb_p`pair'_x2_ks_adj') < 1e-10
    }
}
_psdash_cobalt_record multigroup_pairwise_balance_matches_cobalt `=_rc'

capture noisily {
    _psdash_cobalt_data
    psdash balance treat, covariates(x1 x2) wvar(wt) reference(0)
    matrix W1 = r(balance)
    replace wt = 10 * wt
    psdash balance treat, covariates(x1 x2) wvar(wt) reference(0)
    matrix W10 = r(balance)
    mata: st_numscalar("__psdash_cobalt_diff", ///
        max(abs(st_matrix("W1") :- st_matrix("W10"))))
    assert scalar(__psdash_cobalt_diff) < 1e-10
    scalar drop __psdash_cobalt_diff
}
_psdash_cobalt_record weighted_balance_scale_invariant `=_rc'

display as text _n "RESULT: crossval_cobalt tests=$PSDASH_COBALT_TESTS pass=$PSDASH_COBALT_PASS fail=$PSDASH_COBALT_FAIL skip=0"

local final_fail = $PSDASH_COBALT_FAIL
local failed "$PSDASH_COBALT_FAILED"
macro drop PSDASH_COBALT_TESTS PSDASH_COBALT_PASS ///
    PSDASH_COBALT_FAIL PSDASH_COBALT_FAILED
_psdash_qa_cleanup
capture log close _all

if `final_fail' {
    display as error "Failed tests:`failed'"
    exit 9
}

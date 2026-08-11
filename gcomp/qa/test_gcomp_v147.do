*! test_gcomp_v147.do - Regression tests for gcomp 1.4.7 fixes
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: do-file (QA regression suite)

clear all
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"

* -----------------------------------------------------------------------------
* 1. Default inference must not post the BCa matrix reserved for all
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set seed 14701
    set obs 240
    generate double c = rnormal()
    generate byte x = runiform() > invlogit(-0.2 + 0.3*c)
    generate double m = 0.8*x + 0.4*c + rnormal()
    generate double y = 0.7*m + 0.5*x + 0.2*c + rnormal()

    gcomp y m x c, outcome(y) mediation linexp exposure(x) mediator(m) ///
        commands(m: regress, y: regress) equations(m: x c, y: m x c) ///
        base_confs(c) sim(120) samples(4) seed(14702) minsim

    tempname b cin cip cibc
    matrix `b' = e(b)
    matrix `cin' = e(ci_normal)
    matrix `cip' = e(ci_percentile)
    matrix `cibc' = e(ci_bc)
    assert rowsof(`cin') == 2 & colsof(`cin') == colsof(`b')
    assert rowsof(`cip') == 2 & colsof(`cip') == colsof(`b')
    assert rowsof(`cibc') == 2 & colsof(`cibc') == colsof(`b')
    assert "`e(outcome_cmd)'" == "regress"
    capture confirm matrix e(ci_bca)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: default inference omits e(ci_bca)"
    local ++pass_count
}
else {
    display as error "  FAIL: default inference BCa return contract (rc=`=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* 2. regress component models must use residual-df t inference
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    input double(x y)
        0  0.2
        1  1.9
        2  1.4
        3  3.6
        4  4.1
        5  5.9
        6  5.2
        7  8.4
    end
    regress y x
    estimates store gc_v147_ols
    local _b = _b[x]
    local _se = _se[x]
    local _df = e(df_r)
    local _crit = invttail(`_df', 0.025)
    local _lo = `_b' - `_crit' * `_se'
    local _hi = `_b' + `_crit' * `_se'
    local _p = 2 * ttail(`_df', abs(`_b' / `_se'))
    local _lo_s : display %14.6f `_lo'
    local _hi_s : display %14.6f `_hi'
    local _p_s : display %12.6f `_p'
    local _lo_s = strtrim("`_lo_s'")
    local _hi_s = strtrim("`_hi_s'")
    local _p_s = strtrim("`_p_s'")
    local _expected_ci "[`_lo_s', `_hi_s']"

    tempfile model_csv
    local model_path "`model_csv'.csv"
    gcomptab, models usemodels(gc_v147_ols) csv("`model_path'") digits(6)
    import delimited using "`model_path'", varnames(nonames) stringcols(_all) clear
    generate long _row = _n
    quietly count if v1 == "x"
    assert r(N) == 1
    quietly summarize _row if v1 == "x", meanonly
    local _row = r(mean)
    assert v3[`_row'] == "`_expected_ci'"
    assert v4[`_row'] == "`_p_s'"
    capture estimates drop gc_v147_ols
}
if _rc == 0 {
    display as result "  PASS: models-mode regress rows use t inference"
    local ++pass_count
}
else {
    display as error "  FAIL: models-mode regress inference contract (rc=`=_rc')"
    capture estimates drop gc_v147_ols
    local ++fail_count
}

* -----------------------------------------------------------------------------
* 3. stats() must be case-normalized
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 12
    generate double x = _n
    generate double y = 1 + 2*x + mod(_n, 3)
    regress y x
    estimates store gc_v147_stats

    tempfile stats_csv
    local stats_path "`stats_csv'.csv"
    gcomptab, models usemodels(gc_v147_stats) csv("`stats_path'") stats(N)
    import delimited using "`stats_path'", varnames(nonames) stringcols(_all) clear
    quietly count if v1 == "N"
    assert r(N) == 1

    capture estimates drop gc_v147_stats
}
if _rc == 0 {
    display as result "  PASS: models-mode stats() normalizes requests"
    local ++pass_count
}
else {
    display as error "  FAIL: models-mode stats() normalization contract (rc=`=_rc')"
    capture estimates drop gc_v147_stats
    local ++fail_count
}

* -----------------------------------------------------------------------------
* 4. stats() must reject unsupported statistics
* -----------------------------------------------------------------------------
local ++test_count
capture noisily {
    clear
    set obs 12
    generate double x = _n
    generate double y = 1 + 2*x + mod(_n, 3)
    regress y x
    estimates store gc_v147_stats_bad
    capture noisily gcomptab, models usemodels(gc_v147_stats_bad) display stats(foo)
    assert _rc == 198
    capture estimates drop gc_v147_stats_bad
}
if _rc == 0 {
    display as result "  PASS: models-mode stats() rejects unsupported requests"
    local ++pass_count
}
else {
    display as error "  FAIL: models-mode stats() validation contract (rc=`=_rc')"
    capture estimates drop gc_v147_stats_bad
    local ++fail_count
}

display as text _n "{hline 60}"
display as text "test_gcomp_v147.do: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "{hline 60}"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_gcomp_v147 tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 9
}
display as result "ALL TESTS PASSED"
display "RESULT: test_gcomp_v147 tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

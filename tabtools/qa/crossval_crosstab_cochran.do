*! crossval_crosstab_cochran.do  2026/10/01
*! Author: Timothy P Copeland, Karolinska Institutet
* Native R stats::prop.trend.test parity: score translation/scale/direction.
version 17.0
clear all
set more off
capture log close _all
log using "crossval_crosstab_cochran.log", replace text name(_cv_cochran)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_parity.do"
local pass_count 0
local fail_count 0
tempfile oracle rows
capture noisily shell Rscript "`qa_dir'/crossval_crosstab_cochran.R" "`oracle'"
* Fresh unique tempfile and exact row/content gates prevent stale-oracle reuse.
capture noisily {
    confirm file "`oracle'"
    import delimited "`oracle'", clear varnames(1) asdouble
    assert _N == 12
    assert !missing(case,score,events,trials,z,chi2,p)
}
local prereq_rc = _rc
if `prereq_rc' {
    display as error "FAIL: fresh native R oracle prerequisite (rc=`prereq_rc')"
    display as result "RESULT: crossval_crosstab_cochran tests=1 pass=0 fail=1 skip=0"
    log close _cv_cochran
    exit `prereq_rc'
}
expand 2
bysort case score: generate byte y = _n-1
generate long w = cond(y, events, trials-events)
save `rows'
foreach case in 1 2 3 4 {
    foreach transform in ordinary positive_shift negative_shift positive_large negative_large positive_small negative_small {
        capture noisily {
            use `rows', clear
            keep if case == `case'
            tempname wantz wantchi wantp
            scalar `wantz' = z[1]
            scalar `wantchi' = chi2[1]
            scalar `wantp' = p[1]
            generate double x = score
            local shift = cond(`case' == 4, 1e12, 1e16)
            if "`transform'" == "positive_shift" replace x = x + `shift'
            if "`transform'" == "negative_shift" replace x = x - `shift'
            local direction 1
            if "`transform'" == "positive_large" replace x = x*1e150
            if "`transform'" == "negative_large" {
                replace x = x*(-1e150)
                local direction -1
            }
            if "`transform'" == "positive_small" replace x = x*1e-150
            if "`transform'" == "negative_small" {
                replace x = x*(-1e-150)
                local direction -1
            }
            assert !missing(x)
            quietly crosstab y x [fw=w], cochran
            assert !missing(r(z_trend),r(chi2_trend),r(p_trend))
            scalar `wantz' = scalar(`wantz')*`direction'
            qa_assert_equal r(z_trend) scalar(`wantz'), property(native R signed z) tol(1e-11)
            quietly crosstab y x [fw=w], cochran
            qa_assert_equal r(chi2_trend) scalar(`wantchi'), property(native R chi2) tol(1e-11)
            quietly crosstab y x [fw=w], cochran
            qa_assert_equal r(p_trend) scalar(`wantp'), property(native R p) tol(1e-11)
        }
        local rc = _rc
        if `rc' == 0 {
            local ++pass_count
            display as result "PASS case `case': `transform'"
        }
        else {
            local ++fail_count
            display as error "FAIL case `case': `transform' (rc=`rc')"
        }
    }
}
local tests = `pass_count' + `fail_count'
display as result "RESULT: crossval_crosstab_cochran tests=`tests' pass=`pass_count' fail=`fail_count' skip=0"
log close _cv_cochran
if `fail_count' exit 1

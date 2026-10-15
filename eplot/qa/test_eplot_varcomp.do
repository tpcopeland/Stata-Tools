*! test_eplot_varcomp.do - Variance components of mixed are not effects
*! mixed and xtmixed post their variance components (lns#_#_#, atr#_#_#_#,
*! lnsig_e, r_*) as equations of their own rather than in "/", so they had
*! been plotted as coefficients on the log-SD/atanh metric with a Wald
*! interval Stata never reports.  Only the first e(k_f) coefficients (the
*! fixed effects) are plotted, for the active and for named results.  The
*! oracle is Stata's own coefficient table (ereturn display, r(table)).

clear all
set varabbrev off
set graphics off
version 16.0

capture log close _all
log using "test_eplot_varcomp.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Fixed-effect rows of Stata's own table, (b, ll, ul) in stripe order, from
* a replay of the estimation command at the requested level.
capture program drop _vc_oracle
program define _vc_oracle
    args out level
    quietly `e(cmd)', level(`level')
    tempname T
    matrix `T' = r(table)'
    local kf = e(k_f)
    matrix `out' = (`T'[1..`kf', 1], `T'[1..`kf', 5..6])
end

**# 1. eplot . after mixed plots only the e(k_f) fixed effects
local ++test_count
capture noisily {
    webuse pig, clear
    quietly mixed weight week || id: week, covariance(unstructured)
    local kf = e(k_f)
    assert colsof(e(b)) > `kf'
    _vc_oracle O 95
    eplot ., nodraw
    assert r(k) == `kf'
    matrix E = r(table)
    assert rowsof(E) == `kf'
    forvalues i = 1/`kf' {
        forvalues j = 1/3 {
            assert !missing(E[`i', `j']) & !missing(O[`i', `j'])
            assert reldif(E[`i', `j'], O[`i', `j']) < 1e-12
        }
    }
    * The variance-component equations name none of the plotted rows, and
    * the fixed effects lose the equation prefix their _cons twins forced.
    local rn : rownames E
    assert !strpos("`rn'", "lns") & !strpos("`rn'", "atr") & !strpos("`rn'", "lnsig")
    assert "`rn'" == "week _cons"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 2. the omission is reported with a note
local ++test_count
capture noisily {
    webuse pig, clear
    quietly mixed weight week || id: week, covariance(unstructured)
    local nvc = colsof(e(b)) - e(k_f)
    tempfile lg
    quietly log using "`lg'", text replace name(vc2)
    eplot ., nodraw
    quietly log close vc2
    mata: st_numscalar("r(hit)", strpos(invtokens(cat(st_local("lg"))', " "), ///
        "(note: `nvc' variance-component parameter(s) omitted)") > 0)
    assert r(hit) == 1
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 3. named results: mixed beside regress, level(90), residual structure
local ++test_count
capture noisily {
    webuse pig, clear
    estimates clear
    quietly mixed weight week || id:, residuals(ar 1, t(week))
    estimates store mx
    _vc_oracle O 90
    quietly regress weight week
    estimates store ols
    eplot mx ols, level(90) nodraw
    matrix E = r(table)
    * Two coefficients (week, _cons) shared by both models: the mixed fixed
    * effects align with regress by name, with no extra rows.
    assert rowsof(E) == 2
    local rn : rownames E
    assert "`rn'" == "week _cons"
    assert colsof(E) == 6
    forvalues i = 1/2 {
        forvalues j = 1/3 {
            assert !missing(E[`i', `j']) & !missing(O[`i', `j'])
            assert reldif(E[`i', `j'], O[`i', `j']) < 1e-12
        }
    }
    * The active result (regress) is left in place.
    assert "`e(cmd)'" == "regress"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 4. xtmixed and a constant-only random part
local ++test_count
capture noisily {
    webuse pig, clear
    quietly xtmixed weight week || id:
    assert "`e(cmd)'" == "xtmixed"
    local kf = e(k_f)
    _vc_oracle O 95
    eplot ., nodraw
    assert r(k) == `kf'
    matrix E = r(table)
    forvalues i = 1/`kf' {
        assert !missing(E[`i', 1]) & !missing(O[`i', 1])
        assert reldif(E[`i', 1], O[`i', 1]) < 1e-12
        assert !missing(E[`i', 3]) & !missing(O[`i', 3])
        assert reldif(E[`i', 3], O[`i', 3]) < 1e-12
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 5. dfmethod(kroger) keeps its per-coefficient df and drops the components
local ++test_count
capture noisily {
    webuse pig, clear
    quietly mixed weight week || id: week, reml dfmethod(kroger)
    local kf = e(k_f)
    * The fit's own table (a replay does not redisplay the KR df).
    matrix O = r(table)'
    matrix O = (O[1..`kf', 1], O[1..`kf', 5..6])
    assert !missing(O[1, 2])
    eplot ., nodraw
    assert r(k) == `kf'
    matrix E = r(table)
    forvalues i = 1/`kf' {
        forvalues j = 1/3 {
            assert !missing(E[`i', `j']) & !missing(O[`i', `j'])
            assert reldif(E[`i', `j'], O[`i', `j']) < 1e-10
        }
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

**# 6. a non-mixed multi-equation model keeps every equation
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly sureg (price mpg) (weight mpg length)
    eplot ., nodraw
    assert r(k) == colsof(e(b))
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

capture graph drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_varcomp, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close

*! test_simtab_errors.do
*! Error-path contracts for simtab option validation.

clear all
set varabbrev off
version 17.0
capture log close _all
log using "test_simtab_errors.log", replace text name(simtab_errors)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall simtab
quietly net install simtab, from("`pkg_dir'") replace

local tests = 0
local pass = 0
local fail = 0

* An Excel-forbidden sheet name must error before any caller data are changed.
local ++tests
capture noisily {
    clear
    input byte estimator double estimate se true
    1 .10 .05 0
    1 .20 .05 0
    end
    tempfile before out
    unab vars_before : _all
    save "`before'", replace
    local xlsx "`out'.xlsx"
    capture noisily simtab estimator, estimate(estimate) se(se) true(true) xlsx("`xlsx'") sheet("bad:name")
    local rc = _rc
    assert `rc' == 198
    unab vars_after : _all
    assert "`vars_after'" == "`vars_before'"
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

* Values below the documented -1 default sentinel must fail before mutation.
local ++tests
capture noisily {
    clear
    input byte estimator double estimate se true
    1 .10 .05 0
    1 .20 .05 0
    end
    tempfile before out
    unab vars_before : _all
    save "`before'", replace
    local xlsx "`out'.xlsx"
    capture noisily simtab estimator, estimate(estimate) se(se) true(true) ///
        digits(-2) sedigits(2) xlsx("`xlsx'") sheet("Results")
    local rc = _rc
    assert `rc' == 198
    unab vars_after : _all
    assert "`vars_after'" == "`vars_before'"
    cf _all using "`before'"
    capture confirm file "`xlsx'"
    assert _rc == 601
}
if _rc == 0 local ++pass
else local ++fail

* Summary coverage mappings must be proportions in [0,1].
local ++tests
capture noisily {
    clear
    input byte method double value
    1 1.2
    end
    tempfile before
    unab vars_before : _all
    save "`before'", replace
    capture noisily simtab, from(summary) estimatorvar(method) ///
        measures(coverage=value) display
    assert _rc == 198
    unab vars_after : _all
    assert "`vars_after'" == "`vars_before'"
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

* Summary power mappings must also be proportions in [0,1].
local ++tests
capture noisily {
    clear
    input byte method double value
    1 -0.1
    end
    tempfile before
    unab vars_before : _all
    save "`before'", replace
    capture noisily simtab, from(summary) estimatorvar(method) ///
        measures(power=value) display
    assert _rc == 198
    unab vars_after : _all
    assert "`vars_after'" == "`vars_before'"
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

* Duplicate simsum measure rows cannot be mapped to a unique cell.
local ++tests
capture noisily {
    clear
    input str8 perfmeascode double estimate0
    "bias" 1
    "bias" 2
    end
    label variable estimate0 "Method A"
    tempfile before
    unab vars_before : _all
    save "`before'", replace
    capture noisily simtab, from(simsum) display
    assert _rc == 459
    unab vars_after : _all
    assert "`vars_after'" == "`vars_before'"
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

* open is valid only with an Excel output target.
local ++tests
capture noisily {
    clear
    input byte estimator double estimate se true
    1 .10 .05 0
    1 .20 .05 0
    end
    capture noisily simtab estimator, estimate(estimate) se(se) true(true) open display
    assert _rc == 198
}
if _rc == 0 local ++pass
else local ++fail

* A valid sheet name is not caught by the guard.
local ++tests
capture noisily {
    clear
    input byte estimator double estimate se true
    1 .10 .05 0
    1 .20 .05 0
    end
    tempfile out
    local xlsx "`out'.xlsx"
    simtab estimator, estimate(estimate) se(se) true(true) xlsx("`xlsx'") sheet("Results")
    confirm file "`xlsx'"
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_simtab_errors tests=`tests' pass=`pass' fail=`fail'"
log close simtab_errors
if `fail' exit 1

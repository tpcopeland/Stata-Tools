* test_simtab_negzero.do - a value that rounds to zero prints without a sign
*
*   T1: a small negative bias (-0.001, digits(2)) renders "0.00", never "-0.00"
*   T2: a small positive bias renders "0.00", never "+0.00" (sign shown by default)
*   T3: a bias that survives rounding keeps its sign ("-0.30" and "+0.30")

clear all
set varabbrev off
version 17.0

capture log close _all
log using "test_simtab_negzero.log", replace text name(_simtab)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall simtab
quietly net install simtab, from("`pkg_dir'") replace
discard

* One estimator, 20 reps; the estimate sits a fixed offset from the truth.
capture program drop _nz_data
program define _nz_data
    args offset
    clear
    quietly set obs 20
    gen long sim = _n
    gen double truev = 1
    gen double est = truev + `offset'
    gen double se = 0.1
    gen byte estid = 1
end

* Count frame cells (any c* variable) equal to a string.
capture program drop _nz_count
program define _nz_count, rclass
    args fr text
    local n 0
    frame `fr' {
        foreach v of varlist c* {
            quietly count if `v' == "`text'"
            local n = `n' + r(N)
        }
    }
    return scalar n = `n'
end

local ++test_count
capture noisily {
    _nz_data -0.001
    simtab estid, estimate(est) se(se) true(truev) metrics(bias) frame(nz1, replace)
    _nz_count nz1 "-0.00"
    assert r(n) == 0
    _nz_count nz1 "0.00"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T1 small negative bias prints 0.00"
}
else {
    local ++fail_count
    display as error "  FAIL: T1 small negative bias prints 0.00"
}

local ++test_count
capture noisily {
    _nz_data 0.001
    simtab estid, estimate(est) se(se) true(truev) metrics(bias) frame(nz2, replace)
    _nz_count nz2 "+0.00"
    assert r(n) == 0
    _nz_count nz2 "0.00"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T2 small positive bias prints 0.00"
}
else {
    local ++fail_count
    display as error "  FAIL: T2 small positive bias prints 0.00"
}

local ++test_count
* guard: expected green at HEAD (behaviour-preservation: surviving signs are kept)
capture noisily {
    _nz_data -0.3
    simtab estid, estimate(est) se(se) true(truev) metrics(bias) frame(nz3a, replace)
    _nz_count nz3a "-0.30"
    assert r(n) == 1
    _nz_data 0.3
    simtab estid, estimate(est) se(se) true(truev) metrics(bias) frame(nz3b, replace)
    _nz_count nz3b "+0.30"
    assert r(n) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T3 surviving signs are kept"
}
else {
    local ++fail_count
    display as error "  FAIL: T3 surviving signs are kept"
}

display "RESULT: test_simtab_negzero tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 exit 9

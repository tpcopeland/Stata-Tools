*! test_v164_regressions Version 1.1.0  2026/08/10
*! Regression coverage for the psdash 1.6.4-1.6.5 review fixes
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
version 16.0
set varabbrev off
set seed 1640810

capture log close _all
log using "test_v164_regressions.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global v164_test_count = 0
global v164_pass_count = 0
global v164_fail_count = 0
global v164_failed_tests ""

capture program drop _v164_result
program define _v164_result
    args test_id rc
    global v164_test_count = $v164_test_count + 1
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global v164_pass_count = $v164_pass_count + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global v164_fail_count = $v164_fail_count + 1
        global v164_failed_tests "$v164_failed_tests `test_id'"
    }
end

**# V164-1 — explicit treatment-only calls outrank stale estimation state
capture noisily {
    clear
    set obs 100
    generate double x = rnormal()
    generate byte intended = mod(_n, 2)
    generate byte fitted_y = runiform() < invlogit(0.25 * x)
    generate double w = 1 + 0.1 * intended
    quietly logit fitted_y x

    psdash balance intended, covariates(x) wvar(w)
    assert "`r(treatment)'" == "intended"
    assert r(N) == 100

    psdash weights intended, wvar(w) nograph
    assert "`r(treatment)'" == "intended"
    assert r(N) == 100
}
_v164_result "treatment_only_ignores_stale_estimation" `=_rc'

**# V164-2 — built-in estimation contexts diagnose only e(sample)
capture noisily {
    clear
    set obs 120
    generate double x = rnormal()
    generate byte treat = runiform() < invlogit(0.35 * x)
    quietly logit treat x if _n <= 70
    local nfit = e(N)
    predict double ps_logit, pr
    psdash overlap ps_logit, nograph
    assert r(N) == `nfit'
    assert r(n_estimation) == `nfit'
    assert r(n_excluded) == 120 - `nfit'

    quietly probit treat x in 11/90
    local nfit = e(N)
    predict double ps_probit, pr
    psdash overlap ps_probit, nograph
    assert r(N) == `nfit'
    assert r(n_estimation) == `nfit'
    assert r(n_excluded) == 120 - `nfit'

    generate byte arm = floor(3 * runiform())
    quietly mlogit arm x if _n <= 95
    local nfit = e(N)
    predict double p0 p1 p2, pr
    psdash overlap, psvars(p0 p1 p2) nograph
    assert r(N) == `nfit'
    assert r(n_estimation) == `nfit'
    assert r(n_excluded) == 120 - `nfit'
}
_v164_result "builtin_contexts_respect_esample" `=_rc'

**# V164-3 — Crump's full-sample solution is represented by alpha = 0
capture noisily {
    clear
    set obs 100
    generate byte treat = mod(_n, 2)
    generate double ps = 0.5
    psdash support treat ps, crump nograph
    assert r(crump_alpha) == 0
    assert r(trim_lower) == 0
    assert r(trim_upper) == 1
    assert r(n_trimmed) == 0
}
_v164_result "crump_alpha_zero_full_sample" `=_rc'

**# V164-4 — equal point support is valid common support
capture noisily {
    clear
    set obs 100
    generate byte treat = mod(_n, 2)
    generate double ps = 0.5
    psdash support treat ps, nograph
    assert r(lower_bound) == r(upper_bound)
    assert r(n_outside) == 0
    assert r(n_warnings) == 0
}
_v164_result "equal_point_support_is_valid" `=_rc'

**# V164-5 — exact PS boundaries cannot receive Crump's alpha-zero solution
capture noisily {
    clear
    set obs 100
    generate byte treat = mod(_n, 2)
    generate double ps = 0.5
    replace ps = 0 in 1
    replace ps = 1 in 2

    psdash support treat ps, crump generate(keep_crump) nograph
    local alpha = r(crump_alpha)
    local n_trimmed = r(n_trimmed)
    local n_remaining = r(N_remaining)

    assert `alpha' > 0 & `alpha' < 0.5
    assert `n_trimmed' == 2
    assert `n_remaining' == 98
    assert keep_crump == 0 if ps == 0 | ps == 1
    assert keep_crump == 1 if ps == 0.5

    clear
    set obs 20
    generate byte treat = mod(_n, 2)
    generate double ps = treat
    capture noisily psdash support treat ps, ///
        crump generate(no_support) nograph
    assert _rc == 459
    capture confirm variable no_support
    assert _rc == 111
}
_v164_result "crump_boundaries_not_alpha_zero" `=_rc'

**# V164-6 — README cites the implemented multi-treatment sources
capture noisily {
    tempfile li_ok mccaffrey_ok old_present
    shell grep -Fq "Li, F., and F. Li. 2019" "`pkg_dir'/README.md" && touch "`li_ok'"
    confirm file "`li_ok'"
    shell grep -Fq "McCaffrey, D. F., B. A. Griffin, D. Almirall, M. E. Slaughter, R. Ramchand, and L. F. Burgette. 2013." "`pkg_dir'/README.md" && touch "`mccaffrey_ok'"
    confirm file "`mccaffrey_ok'"
    shell grep -Fq "Ridgeway, and A. R. Morral. 2004" "`pkg_dir'/README.md" && touch "`old_present'"
    capture confirm file "`old_present'"
    assert _rc == 601
}
_v164_result "readme_multi_treatment_sources" `=_rc'

display as text _n "RESULT: test_v164_regressions tests=$v164_test_count pass=$v164_pass_count fail=$v164_fail_count"

_psdash_qa_cleanup
capture log close _all

if $v164_fail_count > 0 {
    display as error "Failed tests:$v164_failed_tests"
    macro drop v164_test_count v164_pass_count v164_fail_count v164_failed_tests
    exit 9
}
macro drop v164_test_count v164_pass_count v164_fail_count v164_failed_tests

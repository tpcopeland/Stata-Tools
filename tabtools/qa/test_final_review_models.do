*! test_final_review_models.do Version 1.0.0  2026/09/09
*! Regression tests from the final model-table command review
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
version 17.0
set varabbrev off

capture log close _all
log using "test_final_review_models.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir = c(pwd)
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which regtab

* Keep the real collect renderer under a test-only name, then shadow its public
* entry point so only the main render fails. Metadata renders still use the real
* implementation, which drives regtab/effecttab into their workbook fallback.
tempfile _renamed_renderer
local _renamed_renderer_ado "`_renamed_renderer'.ado"
filefilter "`pkg_dir'/_tabtools_collect_render.ado" "`_renamed_renderer_ado'", ///
    from("program define _tabtools_collect_render, rclass") ///
    to("program define _qa_real_collect_render, rclass") replace
assert r(occurrences) == 1
run "`_renamed_renderer_ado'"
erase "`_renamed_renderer_ado'"

capture program drop _tabtools_collect_render
program define _tabtools_collect_render, rclass
    version 17.0
    if strpos(lower(`"`0'"'), "type(main)") error 459
    _qa_real_collect_render `0'
    return add
end

* The fallback workbook is valid; this mock isolates its reader's error path.
capture program drop _tabtools_xlsx_read
program define _tabtools_xlsx_read, rclass
    version 17.0
    error 601
end

**# Fallback workbook-reader failures retain their return codes

**## regtab fallback reader
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    local n_before = _N
    local price_before = price[1]
    set varabbrev on
    capture noisily regtab
    local got_rc = _rc
    assert `got_rc' == 601
    assert _N == `n_before'
    assert price[1] == `price_before'
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: regtab fallback reader returns r(601) and restores state"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab fallback reader return/state contract (rc=`=_rc')"
    local ++fail_count
}

**## effecttab fallback reader
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg
    collect clear
    collect: margins, dydx(mpg)
    local n_before = _N
    local price_before = price[1]
    local cmd_before "`e(cmd)'"
    set varabbrev on
    capture noisily effecttab, type(margins)
    local got_rc = _rc
    assert `got_rc' == 601
    assert _N == `n_before'
    assert price[1] == `price_before'
    assert "`e(cmd)'" == "`cmd_before'"
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: effecttab fallback reader returns r(601) and restores state"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab fallback reader return/state contract (rc=`=_rc')"
    local ++fail_count
}

**## regtab never attributes unrelated active e() statistics to a collection
capture program drop _tabtools_collect_render
program define _tabtools_collect_render, rclass
    version 17.0
    if strpos(lower(`"`0'"'), "type(stats)") error 459
    _qa_real_collect_render `0'
    return add
end

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg if foreign == 0
    assert e(N) == 52
    quietly logit foreign mpg
    assert e(N) == 74
    set varabbrev on
    capture noisily regtab, stats(n)
    local got_rc = _rc
    assert `got_rc' == 459
    assert _N == 74
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: regtab rejects unrelated active e() statistics fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab accepted unrelated active e() statistics (rc=`=_rc')"
    local ++fail_count
}

**## regtab does not treat a matching command line as fit identity
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg if foreign == 0
    replace price = price + 1000 in 1
    quietly regress price mpg if foreign == 0
    assert lower(strtrim(`"`e(cmdline)'"')) == ///
        "regress price mpg if foreign == 0"
    capture noisily regtab, stats(n)
    local got_rc = _rc
    assert `got_rc' == 459
}
if _rc == 0 {
    display as result "  PASS: regtab rejects same-command refit statistics fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab accepted same-command refit statistics (rc=`=_rc')"
    local ++fail_count
}

**## regtab never backfills a missing collected group count from active e()
capture program drop _tabtools_collect_render
program define _tabtools_collect_render, rclass
    version 17.0
    _qa_real_collect_render `0'
    if strpos(lower(`"`0'"'), "type(stats)") {
        ds
        foreach v of varlist `r(varlist)' {
            if `v'[1] == "N_g" replace `v' = "" in 2/L
        }
    }
    return add
end

local ++test_count
capture noisily {
    clear
    set seed 92341
    set obs 60
    generate int group = ceil(_n / 10)
    generate double x = rnormal()
    generate double y = x + group + rnormal()
    collect clear
    collect: mixed y x || group:
    preserve
    keep in 1/30
    quietly mixed y x || group:
    restore
    capture noisily regtab, stats(groups)
    local got_rc = _rc
    assert `got_rc' == 459
}
if _rc == 0 {
    display as result "  PASS: regtab rejects active e() group-count backfill"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab accepted active e() group count (rc=`=_rc')"
    local ++fail_count
}

**## ordinary collected mixed-model group and ICC statistics remain available
capture program drop _tabtools_collect_render
program define _tabtools_collect_render, rclass
    version 17.0
    _qa_real_collect_render `0'
    return add
end

local ++test_count
capture noisily {
    clear
    set seed 92341
    set obs 60
    generate int group = ceil(_n / 10)
    generate double x = rnormal()
    generate double y = x + group + rnormal()
    collect clear
    collect: mixed y x || group:
    regtab, stats(groups icc)
    assert r(groups_1) == 6
    assert !missing(r(icc_1))
}
if _rc == 0 {
    display as result "  PASS: collection supplies mixed-model groups and ICC"
    local ++pass_count
}
else {
    display as error "  FAIL: collected mixed-model groups/ICC unavailable (rc=`=_rc')"
    local ++fail_count
}

**## melogit ICC remains tied to the collection after an uncollected fit
local ++test_count
capture noisily {
    clear
    set seed 92344
    set obs 600
    generate int group1 = ceil(_n / 20)
    generate int group2 = ceil(_n / 50)
    generate double x = rnormal()
    generate double z = rnormal()
    generate double u1 = rnormal() if mod(_n - 1, 20) == 0
    bysort group1: replace u1 = u1[1]
    generate byte y = runiform() < invlogit(0.5 * x + u1)
    collect clear
    collect: melogit y x || group1:
    quietly estat icc
    local collected_icc = r(icc2)
    quietly melogit y z || group2:
    regtab, stats(icc)
    assert reldif(r(icc_1), `collected_icc') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: melogit ICC remains collection-derived after another fit"
    local ++pass_count
}
else {
    display as error "  FAIL: melogit ICC used active e(b) (rc=`=_rc')"
    local ++fail_count
}

**## random-effects labels come from collected metadata, not active e()
local ++test_count
capture noisily {
    clear
    set seed 92342
    set obs 80
    generate int group1 = ceil(_n / 10)
    generate int group2 = ceil(_n / 20)
    generate double x1 = rnormal()
    generate double x2 = rnormal()
    generate double y = x1 + group1 + rnormal()
    label variable group1 "Collected clusters"
    label variable group2 "Ambient clusters"
    label variable x1 "Collected slope"
    label variable x2 "Ambient slope"
    collect clear
    collect: mixed y x1 || group1: x1
    quietly mixed y x2 || group2: x2
    regtab, relabel frame(_qa_re_labels, replace)
    frame _qa_re_labels: count if strpos(A, "Collected clusters") > 0
    assert r(N) >= 1
    frame _qa_re_labels: count if strpos(A, "Ambient clusters") > 0
    assert r(N) == 0
    frame drop _qa_re_labels
}
if _rc == 0 {
    display as result "  PASS: random-effects labels use collected metadata"
    local ++pass_count
}
else {
    capture frame drop _qa_re_labels
    display as error "  FAIL: random-effects labels used active e() (rc=`=_rc')"
    local ++fail_count
}

**## ambiguous multi-model random-effects metadata reject relabel
local ++test_count
capture noisily {
    clear
    set seed 92343
    set obs 120
    generate int group1 = ceil(_n / 10)
    generate int group2 = ceil(_n / 15)
    generate double x = rnormal()
    generate double z = rnormal()
    generate double y = x + group1 + rnormal()
    collect clear
    collect: mixed y x || group1:
    collect: mixed y x z || group2:
    capture noisily regtab, relabel
    local got_rc = _rc
    assert `got_rc' == 459
}
if _rc == 0 {
    display as result "  PASS: ambiguous collected random-effects relabel is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: ambiguous random-effects relabel was guessed (rc=`=_rc')"
    local ++fail_count
}

**# Statistical-method provenance

**## stratetab reports the independence assumption behind rate-ratio intervals
local ++test_count
capture noisily {
    tempfile _rate_ref _rate_cmp
    local _rate_ref_base "`_rate_ref'_ref"
    local _rate_cmp_base "`_rate_cmp'_cmp"

    clear
    input byte group double(_Rate _Lower _Upper _D _Y)
    1 0.01 0.008 0.012 100 10000
    end
    label variable _Lower "Lower 95% CI"
    label variable _Upper "Upper 95% CI"
    save "`_rate_ref_base'.dta", replace

    clear
    input byte group double(_Rate _Lower _Upper _D _Y)
    1 0.02 0.017 0.023 200 10000
    end
    label variable _Lower "Lower 95% CI"
    label variable _Upper "Upper 95% CI"
    save "`_rate_cmp_base'.dta", replace

    stratetab, using(`_rate_ref_base' `_rate_cmp_base') outcomes(1) ///
        rateratio level(95)
    assert strpos(lower(`"`r(methods)'"'), "independent-rate") > 0
    erase "`_rate_ref_base'.dta"
    erase "`_rate_cmp_base'.dta"
}
if _rc == 0 {
    display as result "  PASS: stratetab methods report the rate-ratio independence assumption"
    local ++pass_count
}
else {
    local _test_rc = _rc
    capture erase "`_rate_ref_base'.dta"
    capture erase "`_rate_cmp_base'.dta"
    display as error "  FAIL: stratetab rate-ratio methods assumption (rc=`_test_rc')"
    local ++fail_count
}

**# Summary

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_final_review_models tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close

if `fail_count' > 0 exit 1

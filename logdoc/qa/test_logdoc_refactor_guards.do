* test_logdoc_refactor_guards.do - focused guards for logdoc refactors
* Location: logdoc/qa/
* Run: stata-mp -b do test_logdoc_refactor_guards.do

clear all
set more off
capture log close _all

local qadir = regexr("`c(pwd)'", "/+$", "")
capture confirm file "`qadir'/logdoc.pkg"
if _rc == 0 {
    local pkgdir "`qadir'"
    local qadir "`pkgdir'/qa"
}
else {
    local pkgdir = regexr("`qadir'", "/qa/?$", "")
}
capture confirm file "`pkgdir'/logdoc.pkg"
if _rc {
    display as error "Could not locate logdoc package root from c(pwd)=`c(pwd)'"
    exit 601
}

capture ado uninstall logdoc
net install logdoc, from("`pkgdir'") replace

mata:
void _logdoc_guard_file_has(
    string scalar path,
    string scalar needle,
    string scalar result
)
{
    real scalar fh, found
    string scalar line

    found = 0
    fh = fopen(path, "r")
    if (fh < 0) {
        st_local(result, "0")
        return
    }
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, needle) > 0) found = 1
    }
    fclose(fh)
    st_local(result, strofreal(found))
}
end

capture program drop _logdoc_guard_contains
program define _logdoc_guard_contains
    args file needle resultvar
    local found 0
    mata: _logdoc_guard_file_has(st_local("file"), st_local("needle"), "found")
    c_local `resultvar' `found'
end

local test_pass = 0
local test_fail = 0
local test_total = 0
local oldpwd "`c(pwd)'"

local outdir "`c(tmpdir)'/logdoc_refactor_guards"
capture mkdir "`outdir'"

local smcl_fixture "`outdir'/guard_input.smcl"
tempname fh
file open `fh' using "`smcl_fixture'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{com}. sysuse auto, clear" _n
file write `fh' "{txt}(1978 automobile data)" _n
file write `fh' `"{com}. display "KEEP_SENTINEL""' _n
file write `fh' "{res}KEEP_SENTINEL" _n
file write `fh' "{com}. regress price mpg weight" _n
file write `fh' "{txt}REGRESS_SENTINEL" _n
file close `fh'

local smcl_compare "`outdir'/guard_compare.smcl"
tempname fh2
file open `fh2' using "`smcl_compare'", write text replace
file write `fh2' "{smcl}" _n
file write `fh2' `"{com}. display "COMPARE_SENTINEL""' _n
file write `fh2' "{res}COMPARE_SENTINEL" _n
file close `fh2'

* ---------------------------------------------------------------------------
* G1: Invalid options fail before conversion
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily logdoc using "`smcl_fixture'", output("`outdir'/bad_format.html") ///
    format(bogus) replace quiet
local g1a = _rc
capture noisily logdoc using "`smcl_fixture'", output("`outdir'/bad_width.html") ///
    graphwidth(0) replace quiet
local g1b = _rc
capture noisily logdoc using "`smcl_fixture'", output("`outdir'/bad_height.html") ///
    graphheight(foo) replace quiet
local g1c = _rc
capture noisily logdoc using "`smcl_fixture'", output("`outdir'/missing_css.html") ///
    css("`outdir'/does_not_exist.css") replace quiet
local g1d = _rc
capture noisily logdoc using "`smcl_fixture'", output("`outdir'/missing_annot.html") ///
    annotate("`outdir'/does_not_exist.txt") replace quiet
local g1e = _rc
capture noisily logdoc using "`smcl_fixture'", output("`outdir'/quiet_verbose.html") ///
    quiet verbose replace
local g1f = _rc
if `g1a' == 198 & `g1b' == 198 & `g1c' == 198 & ///
    `g1d' == 601 & `g1e' == 601 & `g1f' == 198 {
    display as result "G1 PASS: invalid option guards preserved"
    local test_pass = `test_pass' + 1
}
else {
    display as error "G1 FAIL: invalid option rc contract changed"
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G2: .logdocrc defaults apply and unknown keys are harmless
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
local rcdir "`outdir'/rc_defaults"
capture mkdir "`rcdir'"
tempname rcfh
file open `rcfh' using "`rcdir'/.logdocrc", write text replace
file write `rcfh' "theme=dark" _n
file write `rcfh' "format=md" _n
file write `rcfh' "unknown=ignored" _n
file close `rcfh'
capture noisily {
    cd "`rcdir'"
    logdoc using "`smcl_fixture'", output("`outdir'/rc_default_output") replace quiet
    assert "`r(format)'" == "md"
    assert "`r(theme)'" == "dark"
    confirm file "`outdir'/rc_default_output"
    cd "`oldpwd'"
}
if _rc == 0 {
    display as result "G2 PASS: .logdocrc defaults and unknown keys preserved"
    local test_pass = `test_pass' + 1
}
else {
    display as error "G2 FAIL: .logdocrc defaults changed"
    capture cd "`oldpwd'"
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G3: Custom css() overrides default CSS
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
local cssfile "`outdir'/custom_guard.css"
tempname cssfh
file open `cssfh' using "`cssfile'", write text replace
file write `cssfh' "/* CUSTOM_GUARD_CSS */" _n
file write `cssfh' "body { --logdoc-guard: 1; }" _n
file close `cssfh'
local g3_out "`outdir'/custom_css.html"
capture noisily logdoc using "`smcl_fixture'", output("`g3_out'") ///
    css("`cssfile'") replace quiet
if _rc == 0 {
    _logdoc_guard_contains "`g3_out'" "CUSTOM_GUARD_CSS" g3_css
    if `g3_css' {
        display as result "G3 PASS: custom css() content used"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "G3 FAIL: custom CSS sentinel missing"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "G3 FAIL: css() conversion failed with rc=" _rc
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G4: Adopath/current-directory CSS discovery feeds enhanced HTML
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
local cssdir "`outdir'/css_discovery"
capture mkdir "`cssdir'"
tempname lightfh
file open `lightfh' using "`cssdir'/logdoc_light.css", write text replace
file write `lightfh' "/* ADOPATH_LIGHT_GUARD */" _n
file write `lightfh' ".toolbar { --logdoc-guard: 2; }" _n
file close `lightfh'
local g4_out "`outdir'/css_discovery.html"
capture noisily {
    cd "`cssdir'"
    logdoc using "`smcl_fixture'", output("`g4_out'") copy replace quiet
    cd "`oldpwd'"
}
if _rc == 0 {
    _logdoc_guard_contains "`g4_out'" "ADOPATH_LIGHT_GUARD" g4_css
    if `g4_css' {
        display as result "G4 PASS: discovered light CSS used for enhanced HTML"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "G4 FAIL: discovered CSS sentinel missing"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "G4 FAIL: CSS discovery conversion failed with rc=" _rc
    capture cd "`oldpwd'"
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G5: keep()/drop() pass through tempfile argument files
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
local g5_out "`outdir'/keep_drop.html"
capture noisily logdoc using "`smcl_fixture'", output("`g5_out'") ///
    keep("display") drop("regress") replace quiet
if _rc == 0 {
    _logdoc_guard_contains "`g5_out'" "KEEP_SENTINEL" g5_keep
    _logdoc_guard_contains "`g5_out'" "REGRESS_SENTINEL" g5_drop
    if `g5_keep' & !`g5_drop' {
        display as result "G5 PASS: keep/drop filtering preserved"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "G5 FAIL: keep/drop filtering changed"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "G5 FAIL: keep/drop conversion failed with rc=" _rc
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G6: Conversion r-class metadata is usable
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
capture noisily logdoc using "`smcl_fixture'", output("`outdir'/metadata.html") ///
    replace quiet
if _rc == 0 & r(nblocks) > 0 & r(filesize) > 0 {
    display as result "G6 PASS: r(nblocks) and r(filesize) populated"
    local test_pass = `test_pass' + 1
}
else {
    display as error "G6 FAIL: conversion metadata missing"
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G7: batch and diff r-class contracts are populated
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
local batchin "`outdir'/batch_in"
local batchout "`outdir'/batch_out"
capture mkdir "`batchin'"
capture mkdir "`batchout'"
copy "`smcl_fixture'" "`batchin'/case1.smcl", replace
copy "`smcl_compare'" "`batchin'/case2.smcl", replace
local diffout "`outdir'/guard_diff.html"
capture noisily {
    logdoc batch, input("`batchin'/*.smcl") outdir("`batchout'") ///
        css("`cssfile'") keep("display") drop("regress") ///
        copy generated replace quiet
    assert r(n_files) == 2
    assert r(n_failed) == 0
    _logdoc_guard_contains "`batchout'/case1.html" "CUSTOM_GUARD_CSS" g7_css
    _logdoc_guard_contains "`batchout'/case1.html" "KEEP_SENTINEL" g7_keep
    _logdoc_guard_contains "`batchout'/case1.html" "REGRESS_SENTINEL" g7_drop
    _logdoc_guard_contains "`batchout'/case1.html" "copy-btn" g7_copy
    _logdoc_guard_contains "`batchout'/case1.html" "Generated" g7_generated
    assert `g7_css'
    assert `g7_keep'
    assert !`g7_drop'
    assert `g7_copy'
    assert `g7_generated'
    logdoc diff using "`smcl_fixture'", compare("`smcl_compare'") ///
        output("`diffout'") replace quiet
    assert "`r(output)'" == "`diffout'"
    assert "`r(input)'" == "`smcl_fixture'"
    assert "`r(compare)'" == "`smcl_compare'"
}
if _rc == 0 {
    display as result "G7 PASS: batch and diff r-class contracts preserved"
    local test_pass = `test_pass' + 1
}
else {
    display as error "G7 FAIL: batch/diff r-class contract changed"
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G8: replay preserves tempfile-backed options and allows overrides
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
local g8_out "`outdir'/replay_options.html"
local g8_css "`outdir'/replay_custom.css"
tempname g8cssfh
file open `g8cssfh' using "`g8_css'", write text replace
file write `g8cssfh' "/* REPLAY_GUARD_CSS */" _n
file write `g8cssfh' "body { --logdoc-guard: 8; }" _n
file close `g8cssfh'
capture noisily {
    logdoc using "`smcl_fixture'", output("`g8_out'") css("`g8_css'") ///
        keep("display") drop("regress") copy generated replace quiet
    logdoc replay, theme(dark)
    assert "`r(theme)'" == "dark"
}
if _rc == 0 {
    _logdoc_guard_contains "`g8_out'" "REPLAY_GUARD_CSS" g8_css_found
    _logdoc_guard_contains "`g8_out'" "KEEP_SENTINEL" g8_keep
    _logdoc_guard_contains "`g8_out'" "REGRESS_SENTINEL" g8_drop
    _logdoc_guard_contains "`g8_out'" "copy-btn" g8_copy
    _logdoc_guard_contains "`g8_out'" "Generated" g8_generated
    if `g8_css_found' & `g8_keep' & !`g8_drop' & `g8_copy' & `g8_generated' {
        display as result "G8 PASS: replay option pass-through preserved"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "G8 FAIL: replay pass-through output changed"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "G8 FAIL: replay pass-through command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G9: start/stop preserves tempfile-backed options
* ---------------------------------------------------------------------------
local test_total = `test_total' + 1
local g9_out "`outdir'/session_options.html"
local g9_css "`outdir'/session_custom.css"
tempname g9cssfh
file open `g9cssfh' using "`g9_css'", write text replace
file write `g9cssfh' "/* SESSION_GUARD_CSS */" _n
file write `g9cssfh' "body { --logdoc-guard: 9; }" _n
file close `g9cssfh'
capture noisily {
    logdoc start, output("`g9_out'") css("`g9_css'") ///
        keep("display") drop("regress") copy generated replace quiet
    display "SESSION_KEEP_SENTINEL"
    sysuse auto, clear
    regress price mpg
    logdoc stop
}
if _rc == 0 {
    _logdoc_guard_contains "`g9_out'" "SESSION_GUARD_CSS" g9_css_found
    _logdoc_guard_contains "`g9_out'" "SESSION_KEEP_SENTINEL" g9_keep
    _logdoc_guard_contains "`g9_out'" "regress price mpg" g9_drop
    _logdoc_guard_contains "`g9_out'" "copy-btn" g9_copy
    _logdoc_guard_contains "`g9_out'" "Generated" g9_generated
    if `g9_css_found' & `g9_keep' & !`g9_drop' & `g9_copy' & `g9_generated' {
        display as result "G9 PASS: start/stop option pass-through preserved"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "G9 FAIL: start/stop pass-through output changed"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "G9 FAIL: start/stop pass-through command failed with rc=" _rc
    capture logdoc stop
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G10: logdoc start is RNG-neutral (does not perturb c(rngstate))
* ---------------------------------------------------------------------------
* The uniqueness draw for the temp-log name must not advance the caller's
* RNG, or a seeded bootstrap/simulate wrapped in a logdoc session would
* silently change results. See clarity audit IMPORTANT #1.
local test_total = `test_total' + 1
local g10_out "`outdir'/rng_neutral.html"
set seed 123456
local g10_before = c(rngstate)
capture noisily {
    logdoc start, output("`g10_out'") replace quiet
    logdoc stop
}
local g10_rc = _rc
local g10_after = c(rngstate)
if `g10_rc' == 0 & "`g10_before'" == "`g10_after'" {
    display as result "G10 PASS: logdoc start preserves c(rngstate)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "G10 FAIL: rngstate perturbed (rc=`g10_rc')"
    capture logdoc stop
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G11: diff compare() accepts its documented minimum abbreviation (comp)
* ---------------------------------------------------------------------------
* sthlp documents {opt comp:are(...)}; COMPare(string) min abbrev is `comp'.
* Typing `comp(...)' must not raise rc 198. See clarity audit IMPORTANT #3.
local test_total = `test_total' + 1
local g11_in "`outdir'/g11_a.smcl"
local g11_cmp "`outdir'/g11_b.smcl"
tempname g11fh
file open `g11fh' using "`g11_in'", write text replace
file write `g11fh' "{smcl}" _n `"{com}. display "G11_A""' _n "{res}G11_A" _n
file close `g11fh'
file open `g11fh' using "`g11_cmp'", write text replace
file write `g11fh' "{smcl}" _n `"{com}. display "G11_B""' _n "{res}G11_B" _n
file close `g11fh'
capture noisily logdoc diff using "`g11_in'", comp("`g11_cmp'") ///
    output("`outdir'/g11_diff.html") replace quiet
local g11_rc = _rc
if `g11_rc' != 198 {
    display as result "G11 PASS: comp() abbreviation parses (rc=`g11_rc')"
    local test_pass = `test_pass' + 1
}
else {
    display as error "G11 FAIL: comp() rejected with rc 198"
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* G12: stataexe() rejects shell metacharacters in the run executable
* ---------------------------------------------------------------------------
* stataexe() is interpolated into a shell command; metacharacters must be
* refused with rc 198 before any shell call. See clarity audit IMPORTANT #2.
local test_total = `test_total' + 1
local g12_do "`outdir'/g12_run.do"
tempname g12fh
file open `g12fh' using "`g12_do'", write text replace
file write `g12fh' "display 1" _n
file close `g12fh'
capture noisily logdoc using "`g12_do'", run output("`outdir'/g12.html") ///
    stataexe("stata|evil") replace
local g12_rc = _rc
if `g12_rc' == 198 {
    display as result "G12 PASS: stataexe() metacharacter guard fires (rc=198)"
    local test_pass = `test_pass' + 1
}
else {
    display as error "G12 FAIL: stataexe() guard did not fire (rc=`g12_rc')"
    local test_fail = `test_fail' + 1
}

* ---------------------------------------------------------------------------
* Cleanup
* ---------------------------------------------------------------------------
capture cd "`oldpwd'"
capture erase "`outdir'/rng_neutral.html"
capture erase "`outdir'/g11_a.smcl"
capture erase "`outdir'/g11_b.smcl"
capture erase "`outdir'/g11_diff.html"
capture erase "`outdir'/g12_run.do"
capture erase "`outdir'/g12.html"
capture erase "`smcl_fixture'"
capture erase "`smcl_compare'"
capture erase "`outdir'/bad_format.html"
capture erase "`outdir'/bad_width.html"
capture erase "`outdir'/bad_height.html"
capture erase "`outdir'/missing_css.html"
capture erase "`outdir'/missing_annot.html"
capture erase "`outdir'/quiet_verbose.html"
capture erase "`outdir'/rc_defaults/.logdocrc"
capture erase "`outdir'/rc_default_output"
capture erase "`outdir'/custom_guard.css"
capture erase "`outdir'/custom_css.html"
capture erase "`outdir'/css_discovery/logdoc_light.css"
capture erase "`outdir'/css_discovery.html"
capture erase "`outdir'/keep_drop.html"
capture erase "`outdir'/metadata.html"
capture erase "`outdir'/batch_in/case1.smcl"
capture erase "`outdir'/batch_in/case2.smcl"
capture erase "`outdir'/batch_out/case1.html"
capture erase "`outdir'/batch_out/case2.html"
capture erase "`outdir'/guard_diff.html"
capture erase "`outdir'/replay_custom.css"
capture erase "`outdir'/replay_options.html"
capture erase "`outdir'/session_custom.css"
capture erase "`outdir'/session_options.html"

display ""
display as result "Refactor guard results: `test_pass'/`test_total' passed, `test_fail' failed"
if `test_fail' > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
}

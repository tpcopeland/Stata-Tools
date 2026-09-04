* test_codescan_v421.do - Regression tests for the v4.2.1 fixes
* Date: 2026-09-02
*
* Covers:
*   T1-T5:  non-ASCII zero-width regexes rejected on the live scan axis (C1)
*   T6-T10: casefold-equivalent codefile columns rejected as ambiguous (C2)
*   T11-T15: save() commits no codefile unless the whole call succeeds (I1)
*
* Each block asserts the caller's state as well as the return code: a guard that
* refuses the call but leaves an output variable, a mutated dataset, or a
* changed session setting behind has not restored anything.

clear all
version 16.0
set varabbrev off
set seed 42100
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

local _qa_va0 "`c(varabbrev)'"


* ============================================================
* C1 - zero-width assertions keyed to a non-ASCII character
*
* The option-time guard probes printable ASCII leading characters, which is
* every character the probe can know about before the data is read. An
* assertion keyed to a character outside that alphabet scored 0 on every probe,
* passed validation, and then matched a position rather than a code: it defined
* cohort membership at rc=0 while consuming nothing.
* ============================================================

**# T1: non-ASCII lookahead as an inclusion is rejected, with nothing left behind

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str10 code = cond(_n == 1, "å00", "A00")
    tempfile before1
    save "`before1'", replace

    set varabbrev on
    capture codescan code, define(hit "(?=å)")
    local _rc1 = _rc
    assert `_rc1' == 198
    assert "`c(varabbrev)'" == "on"
    capture confirm variable hit
    assert _rc != 0
    cf _all using "`before1'"
    unab _t1_vars : _all
    assert "`_t1_vars'" == "code"
    assert _N == 2
    set varabbrev `_qa_va0'
}
if _rc == 0 {
    display as result "  PASS: T1 - non-ASCII zero-width inclusion rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - non-ASCII zero-width inclusion (error `=_rc')"
    local ++fail_count
}
set varabbrev `_qa_va0'


**# T2: the same assertion used as an exclusion is rejected

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str10 code = cond(_n == 1, "å00", "E11")
    tempfile before2
    save "`before2'", replace

    capture codescan code, define(hit "." ~ "(?=å)")
    assert _rc == 198
    capture confirm variable hit
    assert _rc != 0
    cf _all using "`before2'"
    unab _t2_vars : _all
    assert "`_t2_vars'" == "code"
    assert _N == 2
}
if _rc == 0 {
    display as result "  PASS: T2 - non-ASCII zero-width exclusion rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - non-ASCII zero-width exclusion (error `=_rc')"
    local ++fail_count
}


**# T3: a consuming non-ASCII inclusion still matches

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 code = ""
    replace code = "å00" in 1
    replace code = "A00" in 2
    replace code = "å11" in 3

    codescan code, define(hit "å")
    assert hit[1] == 1
    assert hit[2] == 0
    assert hit[3] == 1
    assert r(conditions) == "hit"
}
if _rc == 0 {
    display as result "  PASS: T3 - consuming non-ASCII inclusion unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - consuming non-ASCII inclusion (error `=_rc')"
    local ++fail_count
}


**# T4: a consuming non-ASCII exclusion still excludes

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str10 code = cond(_n == 1, "å00", "E11")

    codescan code, define(hit "." ~ "å")
    assert hit[1] == 0
    assert hit[2] == 1
}
if _rc == 0 {
    display as result "  PASS: T4 - consuming non-ASCII exclusion unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - consuming non-ASCII exclusion (error `=_rc')"
    local ++fail_count
}


**# T5: the ASCII case is still refused at option-validation time, before work

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str10 code = cond(_n == 1, "E11", "Z00")
    * No å in this data at all: the ASCII probe alphabet must still catch it
    * without any code value having to expose it.
    capture codescan code, define(hit "(?=E)")
    assert _rc == 198
    capture confirm variable hit
    assert _rc != 0
    capture codescan code, define(hit "\b")
    assert _rc == 198
    capture codescan code, define(hit "A*")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T5 - ASCII zero-width patterns still rejected up front"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - ASCII zero-width validation (error `=_rc')"
    local ++fail_count
}


* ============================================================
* C2 - casefold-equivalent codefile columns
*
* Stata allows case-distinct variable names, so a .dta codefile can carry both
* `name' and `Name'. Resolving one of them by physical spelling and storage
* order makes the same file define a different cohort depending on how it was
* written. The mapping must be unique or refused.
* ============================================================

**# T6: two spellings of a required column are refused

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str10 name = "lower"
    gen str10 Name = "upper"
    gen str10 pattern = "E11"
    * .dta extension on purpose: codefile() rejects an extension-less path with
    * the same r(198), so a bare tempfile would have made this block pass
    * without ever reaching the schema resolver.
    tempfile stem6
    local cf_dupname "`stem6'.dta"
    save "`cf_dupname'", replace

    clear
    set obs 1
    gen str6 dx = "E110"
    tempfile before6
    save "`before6'", replace

    set varabbrev on
    capture codescan dx, codefile("`cf_dupname'")
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    capture confirm variable lower
    assert _rc != 0
    capture confirm variable upper
    assert _rc != 0
    cf _all using "`before6'"
    unab _t6_vars : _all
    assert "`_t6_vars'" == "dx"
    assert _N == 1
    set varabbrev `_qa_va0'

    * Paired control: the identical call on the identical file succeeds once the
    * ambiguity is removed, so the r(198) above is the schema guard.
    preserve
    use "`cf_dupname'", clear
    drop Name
    save "`cf_dupname'", replace
    restore
    codescan dx, codefile("`cf_dupname'")
    assert lower[1] == 1
    drop lower
}
if _rc == 0 {
    display as result "  PASS: T6 - duplicate casefold name column refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - duplicate casefold name column (error `=_rc')"
    local ++fail_count
}
set varabbrev `_qa_va0'


**# T7: two NON-lowercase spellings of a required column are refused

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str10 name = "cond1"
    gen str10 PATTERN = "E11"
    gen str10 Pattern = "I10"
    tempfile stem7
    local cf_duppat "`stem7'.dta"
    save "`cf_duppat'", replace

    clear
    set obs 1
    gen str6 dx = "I10"
    capture codescan dx, codefile("`cf_duppat'")
    assert _rc == 198
    capture confirm variable cond1
    assert _rc != 0
    unab _t7_vars : _all
    assert "`_t7_vars'" == "dx"

    preserve
    use "`cf_duppat'", clear
    drop PATTERN
    save "`cf_duppat'", replace
    restore
    codescan dx, codefile("`cf_duppat'")
    assert cond1[1] == 1
    drop cond1
}
if _rc == 0 {
    display as result "  PASS: T7 - two non-lowercase pattern columns refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - two non-lowercase pattern columns (error `=_rc')"
    local ++fail_count
}


**# T8: an ambiguous OPTIONAL column is refused, not silently dropped

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str10 name = "cond1"
    gen str10 pattern = "E11"
    gen str10 exclusion = ""
    gen str10 ExClUsIoN = "E116"
    tempfile stem8
    local cf_dupexcl "`stem8'.dta"
    save "`cf_dupexcl'", replace

    clear
    set obs 2
    gen str6 dx = cond(_n == 1, "E110", "E116")
    capture codescan dx, codefile("`cf_dupexcl'")
    assert _rc == 198
    capture confirm variable cond1
    assert _rc != 0

    * With the empty lowercase duplicate gone, the surviving ExClUsIoN column is
    * the exclusion rule -- and it is applied, which is exactly the cohort the
    * ambiguous file could have silently produced either way.
    preserve
    use "`cf_dupexcl'", clear
    drop exclusion
    save "`cf_dupexcl'", replace
    restore
    codescan dx, codefile("`cf_dupexcl'")
    assert cond1[1] == 1
    assert cond1[2] == 0
    drop cond1
}
if _rc == 0 {
    display as result "  PASS: T8 - duplicate casefold exclusion column refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - duplicate casefold exclusion column (error `=_rc')"
    local ++fail_count
}


**# T9: an ambiguous label column is refused

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str20 name = "cond1"
    gen str20 pattern = "E11"
    gen str20 label = "canonical"
    gen str20 LaBeL = "variant"
    tempfile stem9
    local cf_duplab "`stem9'.dta"
    save "`cf_duplab'", replace

    clear
    set obs 1
    gen str6 dx = "E110"
    capture codescan dx, codefile("`cf_duplab'")
    assert _rc == 198
    capture confirm variable cond1
    assert _rc != 0

    preserve
    use "`cf_duplab'", clear
    drop LaBeL
    save "`cf_duplab'", replace
    restore
    codescan dx, codefile("`cf_duplab'")
    local _t9_lbl : variable label cond1
    assert "`_t9_lbl'" == "canonical"
    drop cond1
}
if _rc == 0 {
    display as result "  PASS: T9 - duplicate casefold label column refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - duplicate casefold label column (error `=_rc')"
    local ++fail_count
}


**# T10: a single case variant per field still resolves, in every field

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str20 NAME = "dm2"
    gen str20 Pattern = "E11"
    gen str20 EXCLUSION = "E116"
    gen str20 LABEL = "Type 2 diabetes"
    tempfile stem10
    local cf_variant "`stem10'.dta"
    save "`cf_variant'", replace

    clear
    set obs 3
    gen str6 dx = ""
    replace dx = "E110" in 1
    replace dx = "E116" in 2
    replace dx = "Z00"  in 3

    codescan dx, codefile("`cf_variant'")
    assert dm2[1] == 1
    assert dm2[2] == 0
    assert dm2[3] == 0
    local _lbl : variable label dm2
    assert "`_lbl'" == "Type 2 diabetes"
}
if _rc == 0 {
    display as result "  PASS: T10 - single case-variant schema still resolves"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - single case-variant schema (error `=_rc')"
    local ++fail_count
}


* ============================================================
* I1 - save() must not commit a codefile for a call that failed
*
* The definition CSV used to be written during option handling, so a scan that
* then failed left a file and the "(define() saved to ...)" message behind. Any
* workflow that treats artifact presence as success read that as a completed
* operation.
* ============================================================

**# T11: an empty analysis sample leaves no codefile

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str3 code = "E11"
    tempfile stem11
    local csv11 "`stem11'.csv"
    capture erase "`csv11'"

    capture codescan code if 0, define(hit "E11") save("`csv11'", replace)
    assert _rc == 2000
    capture confirm file "`csv11'"
    assert _rc != 0
    capture confirm variable hit
    assert _rc != 0
    assert _N == 1
}
if _rc == 0 {
    display as result "  PASS: T11 - empty sample writes no save() codefile"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - empty sample save() artifact (error `=_rc')"
    local ++fail_count
}


**# T12: a failing late side effect leaves no codefile either

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str3 code = cond(_n == 1, "E11", "Z00")
    tempfile stem12
    local csv12 "`stem12'.csv"
    local badexport "`stem12'_nodir/out.csv"
    capture erase "`csv12'"

    capture codescan code, define(hit "E11") save("`csv12'", replace) ///
        export("`badexport'")
    assert _rc != 0
    capture confirm file "`csv12'"
    assert _rc != 0
    unab _t12_vars : _all
    assert "`_t12_vars'" == "code"
}
if _rc == 0 {
    display as result "  PASS: T12 - failed export() writes no save() codefile"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - failed export() save() artifact (error `=_rc')"
    local ++fail_count
}


**# T13: a successful call still writes the documented four-column codefile

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str6 code = ""
    replace code = "E110" in 1
    replace code = "E116" in 2
    replace code = "Z00"  in 3
    tempfile stem13
    local csv13 "`stem13'.csv"
    capture erase "`csv13'"

    codescan code, define(dm2 "E11" ~ "E116") label(dm2 "Type 2 diabetes") ///
        save("`csv13'", replace)
    assert dm2[1] == 1
    assert dm2[2] == 0
    assert dm2[3] == 0
    confirm file "`csv13'"
    * The caller's data survives the deferred write unchanged.
    unab _t13_vars : _all
    assert "`_t13_vars'" == "code dm2"
    assert _N == 3

    preserve
    import delimited using "`csv13'", clear varnames(1) stringcols(_all)
    assert _N == 1
    unab _cols : _all
    assert "`_cols'" == "name pattern exclusion label"
    assert name[1] == "dm2"
    assert pattern[1] == "E11"
    assert exclusion[1] == "E116"
    assert label[1] == "Type 2 diabetes"
    restore
}
if _rc == 0 {
    display as result "  PASS: T13 - successful call writes the save() codefile"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - successful save() codefile (error `=_rc')"
    local ++fail_count
}


**# T14: the codefile written by save() round-trips through codefile()

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str6 code = ""
    replace code = "E110" in 1
    replace code = "E116" in 2
    replace code = "Z00"  in 3
    tempfile stem14
    local csv14 "`stem14'.csv"
    capture erase "`csv14'"

    codescan code, define(dm2 "E11" ~ "E116") save("`csv14'", replace)
    drop dm2
    codescan code, codefile("`csv14'")
    assert dm2[1] == 1
    assert dm2[2] == 0
    assert dm2[3] == 0
}
if _rc == 0 {
    display as result "  PASS: T14 - save() output round-trips through codefile()"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 - save() round-trip (error `=_rc')"
    local ++fail_count
}


**# T15: overwrite authorization is still enforced before any work

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str3 code = cond(_n == 1, "E11", "Z00")
    tempfile stem15
    local csv15 "`stem15'.csv"
    capture erase "`csv15'"

    * Pre-existing file with known content.
    tempname fh15
    file open `fh15' using "`csv15'", write replace text
    file write `fh15' "sentinel" _n
    file close `fh15'

    capture codescan code, define(hit "E11") save("`csv15'")
    assert _rc == 602
    capture confirm variable hit
    assert _rc != 0

    * The refused write left the existing file exactly as it was.
    preserve
    import delimited using "`csv15'", clear varnames(nonames) stringcols(_all)
    assert _N == 1
    assert v1[1] == "sentinel"
    restore
}
if _rc == 0 {
    display as result "  PASS: T15 - save() overwrite refusal leaves the file untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 - save() overwrite refusal (error `=_rc')"
    local ++fail_count
}


**# T16: the mid-scan rejection rolls back an in-place replacement

local ++test_count
capture noisily {
    * The zero-width guard is the first error codescan can raise DURING the
    * scan: every other rejection happens while options are parsed, before any
    * output exists. Under replace, a planned output name that collides with a
    * caller variable is dropped and rebuilt, so this failure site must reach the
    * internal snapshot rollback and give the caller its own variable back.
    clear
    set obs 3
    gen str10 code = ""
    replace code = "å00" in 1
    replace code = "E11" in 2
    replace code = "Z00" in 3
    gen double hit = 42
    label variable hit "caller's own variable"
    format hit %9.2f
    tempfile before16
    save "`before16'", replace

    capture codescan code, define(hit "(?=å)") replace
    assert _rc == 198
    cf _all using "`before16'"
    unab _t16_vars : _all
    assert "`_t16_vars'" == "code hit"
    assert _N == 3
    assert hit[1] == 42 & hit[2] == 42 & hit[3] == 42
    local _t16_lbl : variable label hit
    assert "`_t16_lbl'" == "caller's own variable"
    local _t16_fmt : format hit
    assert "`_t16_fmt'" == "%9.2f"
    local _t16_type : type hit
    assert "`_t16_type'" == "double"
}
if _rc == 0 {
    display as result "  PASS: T16 - mid-scan rejection restores a replaced caller variable"
    local ++pass_count
}
else {
    display as error "  FAIL: T16 - mid-scan replace rollback (error `=_rc')"
    local ++fail_count
}


**# T17: the mid-scan rejection does not leave the data collapsed

local ++test_count
capture noisily {
    clear
    set obs 4
    gen long pid = ceil(_n / 2)
    gen str10 code = ""
    replace code = "å00" in 1
    replace code = "E11" in 2
    replace code = "Z00" in 3
    replace code = "I10" in 4
    tempfile before17
    save "`before17'", replace

    capture codescan code, define(hit "(?=å)") id(pid) collapse
    assert _rc == 198
    cf _all using "`before17'"
    unab _t17_vars : _all
    assert "`_t17_vars'" == "pid code"
    assert _N == 4
}
if _rc == 0 {
    display as result "  PASS: T17 - mid-scan rejection leaves collapse() data uncollapsed"
    local ++pass_count
}
else {
    display as error "  FAIL: T17 - mid-scan collapse rollback (error `=_rc')"
    local ++fail_count
}


**# Settings hygiene

local ++test_count
capture noisily {
    assert "`c(varabbrev)'" == "`_qa_va0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v421" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v421 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Functional Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"

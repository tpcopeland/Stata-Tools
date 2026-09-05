* test_codescan_v422.do - Regression tests for the v4.2.2 fixes
* Date: 2026-09-06
*
* Covers:
*   T1-T2:  frame() naming the current frame refused at validation (I1)
*   T3:     the output frame carries no internal tempvars (I3)
*   T4-T6:  no artifact column truncates a long label/pattern/exclusion (M1, contract)
*   T7-T8:  an output name that differs from an input only by case refused (M3)
*   T9-T10: a codefile() value Stata cannot re-quote is refused, cleanly (M2)
*   T11-T12: the shipped documentation carries the fixes that are doc-only (M4, I5)
*
* Each block asserts the caller's state as well as the return code: a guard that
* refuses the call but leaves an output variable, a mutated dataset, or a
* changed session setting behind has not restored anything.

clear all
version 16.0
set varabbrev off
set seed 42200
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

* Long values used by the M1 blocks. Built once so every block compares against
* the same strings the call was given.
local _v422_lab "Type 2 diabetes mellitus defined from primary and secondary ICD-10 diagnosis fields, per the Swedish National Patient Register algorithm"
local _v422_pad ""
forvalues i = 1/26 {
    local _v422_pad "`_v422_pad'XXXXXXXXXX"
}
local _v422_pat "E11(?:`_v422_pad')?"
local _v422_exc "(?:`_v422_pad')"


* ============================================================
* I1 - frame() naming the current frame
*
* The current frame can be neither dropped (r(119)) nor written into by
* frame put (r(110)). frame(default) with replace passed option validation and
* then failed at commit time, after the scan and every side effect had already
* run. The name default is not the problem -- the CURRENT frame is -- so the
* same call from another frame must still work.
* ============================================================

**# T1: frame() naming the current frame is refused before any work is done

local ++test_count
capture noisily {
    clear
    set obs 6
    gen long pid = ceil(_n/2)
    gen str10 dx1 = cond(mod(_n,2) == 1, "E11", "I10")
    gen str10 dx2 = "Z00"
    tempfile before1
    save "`before1'", replace

    set varabbrev on
    capture codescan dx1 dx2, define(dm2 "E11") id(pid) collapse ///
        frame(default) replace
    local _rc1 = _rc
    assert `_rc1' == 198
    assert "`c(varabbrev)'" == "on"
    capture confirm variable dm2
    assert _rc != 0
    cf _all using "`before1'"
    unab _t1_vars : _all
    assert "`_t1_vars'" == "pid dx1 dx2"
    assert _N == 6
    set varabbrev `_qa_va0'
}
if _rc == 0 {
    display as result "  PASS: T1 - frame(current) refused at validation (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - frame(current) refusal (error `=_rc')"
    local ++fail_count
}
set varabbrev `_qa_va0'


**# T2: control - frame(default) from another frame is still legal

local ++test_count
capture noisily {
    clear
    capture frame drop v422work
    frame create v422work
    frame change v422work
    set obs 6
    gen long pid = ceil(_n/2)
    gen str10 dx1 = cond(mod(_n,2) == 1, "E11", "I10")

    codescan dx1, define(dm2 "E11") id(pid) collapse frame(default) replace
    assert _rc == 0
    * The result landed in default: one row per id, carrying the indicator.
    frame default: assert _N == 3
    frame default: unab _t2_vars : _all
    frame default: assert "`_t2_vars'" == "pid dm2"
    * ...and the caller's own frame is untouched.
    assert _N == 6
    capture confirm variable dm2
    assert _rc != 0

    frame change default
    frame drop v422work
}
if _rc == 0 {
    display as result "  PASS: T2 - frame(default) from another frame still writes there"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - frame(default) from another frame (error `=_rc')"
    local ++fail_count
}
capture frame change default
capture frame drop v422work


* ============================================================
* I3 - internal tempvars must not reach the output frame
*
* frame put * copies every variable, tempvars included. Stata sweeps tempvars
* out of every frame when the defining program ends, so the leak was transient,
* but an output contract should not rest on that: saving() has always dropped
* the list explicitly and the frame writer now shares it.
* ============================================================

**# T3: the output frame holds the deliverable and nothing else

local ++test_count
capture noisily {
    clear
    set obs 8
    gen long pid = ceil(_n/2)
    * tostring puts _scan_string_* in play; merge puts the merge scaffolding
    * (input order, uniq id, rowmatch/mtag summaries) in play. Both are live at
    * frame-put time.
    gen dxn1 = 100 + mod(_n, 3)
    gen str10 dx2 = "E11"
    capture frame drop v422res
    codescan dxn1 dx2, define(dm2 "E11") id(pid) tostring merge countrows ///
        frame(v422res) replace
    assert _rc == 0

    frame v422res: unab _t3_vars : _all
    frame v422res: local _t3_n = _N
    assert "`_t3_vars'" == "pid dxn1 dx2 dm2 dm2_nrows"
    assert `_t3_n' == 8
    * No __-prefixed name of any kind survived the copy.
    foreach _v of local _t3_vars {
        assert substr("`_v'", 1, 2) != "__"
    }
    frame drop v422res
}
if _rc == 0 {
    display as result "  PASS: T3 - output frame carries no internal tempvars"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - output frame tempvars (error `=_rc')"
    local ++fail_count
}
capture frame drop v422res


* ============================================================
* M1 - long labels, patterns, and exclusions reach the artifact whole
*
* The audit read the fixed str80/str244 column declarations in the export(),
* save(), and graph writers as silent truncation at rc=0. They are not: every
* value is written with `replace', which widens a string variable to fit
* ("variable s was str10 now str40"), so the declared width is a floor and the
* finding is refuted. These blocks pin the contract the audit was right to care
* about -- the artifact must describe the rule the scanner actually applied --
* on the axis a user lives on: the bytes in the file, not the type in source.
* ============================================================

**# T4: a label longer than 80 characters reaches export() whole

local ++test_count
capture noisily {
    clear
    set obs 6
    gen str10 dx1 = cond(mod(_n,2) == 1, "E11", "I10")

    assert strlen("`_v422_lab'") > 80
    codescan dx1, define(dm2 "E11") label(dm2 "`_v422_lab'") ///
        export("`qa_dir'/v422_exp.csv", replace)
    assert _rc == 0

    preserve
    import delimited using "`qa_dir'/v422_exp.csv", varnames(1) ///
        stringcols(_all) clear
    assert _N == 1
    assert label[1] == "`_v422_lab'"
    assert strlen(label[1]) == strlen("`_v422_lab'")
    restore
    capture erase "`qa_dir'/v422_exp.csv"
}
if _rc == 0 {
    display as result "  PASS: T4 - long label round-trips through export()"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - long label through export() (error `=_rc')"
    local ++fail_count
}
capture erase "`qa_dir'/v422_exp.csv"


**# T5: a pattern and an exclusion longer than 244 reach export() whole

local ++test_count
capture noisily {
    clear
    set obs 6
    gen str10 dx1 = cond(mod(_n,2) == 1, "E11", "I10")

    assert strlen("`_v422_pat'") > 244
    assert strlen("`_v422_exc'") > 244
    codescan dx1, define(dm2 "`_v422_pat'" ~ "`_v422_exc'") ///
        export("`qa_dir'/v422_exp2.csv", replace)
    assert _rc == 0
    * The rule the scanner actually applied: E11 rows match, nothing is excluded.
    assert dm2 == (dx1 == "E11")

    preserve
    import delimited using "`qa_dir'/v422_exp2.csv", varnames(1) ///
        stringcols(_all) clear
    assert _N == 1
    assert pattern[1] == "`_v422_pat'"
    assert exclusion[1] == "`_v422_exc'"
    restore
    capture erase "`qa_dir'/v422_exp2.csv"
}
if _rc == 0 {
    display as result "  PASS: T5 - long pattern/exclusion round-trip through export()"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - long pattern/exclusion through export() (error `=_rc')"
    local ++fail_count
}
capture erase "`qa_dir'/v422_exp2.csv"


**# T6: save() writes a codefile that reproduces the same long rule

local ++test_count
capture noisily {
    clear
    set obs 6
    gen str10 dx1 = cond(mod(_n,2) == 1, "E11", "I10")

    codescan dx1, define(dm2 "`_v422_pat'" ~ "`_v422_exc'") ///
        label(dm2 "`_v422_lab'") save("`qa_dir'/v422_rules.csv", replace)
    assert _rc == 0

    preserve
    import delimited using "`qa_dir'/v422_rules.csv", varnames(1) ///
        stringcols(_all) clear
    assert _N == 1
    assert pattern[1] == "`_v422_pat'"
    assert exclusion[1] == "`_v422_exc'"
    assert label[1] == "`_v422_lab'"
    restore

    * Oracle independence: the saved codefile is a rule set, so replay it and
    * require the same cohort a truncated pattern could not have produced.
    drop dm2
    codescan dx1, codefile("`qa_dir'/v422_rules.csv")
    assert _rc == 0
    assert dm2 == (dx1 == "E11")
    capture erase "`qa_dir'/v422_rules.csv"
}
if _rc == 0 {
    display as result "  PASS: T6 - save() codefile replays the untruncated rule"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - save() codefile replay (error `=_rc')"
    local ++fail_count
}
capture erase "`qa_dir'/v422_rules.csv"


* ============================================================
* M3 - case-folded collision with the caller's own variables
*
* Condition names already had to be unique ignoring case among themselves;
* the discipline stopped at the data boundary, so DM2 over a scanned dm2
* created a second, near-identical variable at rc=0.
* ============================================================

**# T7: an output name differing from a scanned variable only by case is refused

local ++test_count
capture noisily {
    clear
    set obs 4
    gen str10 dx1 = "E11"
    gen str10 dx2 = "I10"
    tempfile before7
    save "`before7'", replace

    capture codescan dx1 dx2, define(DX1 "E11")
    assert _rc == 198
    capture confirm variable DX1
    assert _rc != 0
    cf _all using "`before7'"
    unab _t7_vars : _all
    assert "`_t7_vars'" == "dx1 dx2"
    assert _N == 4
}
if _rc == 0 {
    display as result "  PASS: T7 - casefold collision with a scanned variable refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - casefold collision with a scanned variable (error `=_rc')"
    local ++fail_count
}


**# T8: the same rule holds for id(), and a genuinely distinct name still runs

local ++test_count
capture noisily {
    clear
    set obs 4
    gen long pid = ceil(_n/2)
    gen str10 dx1 = "E11"

    capture codescan dx1, define(PID "E11") id(pid) collapse
    assert _rc == 198
    capture confirm variable PID
    assert _rc != 0
    assert _N == 4

    * Control: a name that is not a case variant of any input is unaffected.
    codescan dx1, define(dm2 "E11") id(pid) collapse
    assert _rc == 0
    assert _N == 2
    assert dm2 == 1
}
if _rc == 0 {
    display as result "  PASS: T8 - casefold collision with id() refused, distinct name runs"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - casefold collision with id() (error `=_rc')"
    local ++fail_count
}


* ============================================================
* M2 - a codefile() value Stata cannot carry through a macro
*
* The audit located this at the regex validator's mata: call. The break is
* earlier and more general: EVERY field read from a codefile is round-tripped
* through compound quotes, which the two-character sequence " followed by '
* terminates. codescan reported "too few quotes" against an unrelated line and
* died at r(199) while still parsing options. A lone double quote is not
* affected and must keep working.
* ============================================================

**# T9: a codefile value Stata cannot re-quote is refused with a real message

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str32 name = ""
    gen str80 pattern = ""
    gen str80 label = ""
    replace name = "q1" in 1
    replace pattern = "E1" + char(34) + char(39) + "1" in 1
    replace label = "quote then apostrophe" in 1
    replace name = "dm2" in 2
    replace pattern = "E11" in 2
    replace label = "diabetes" in 2
    export delimited using "`qa_dir'/v422_cf_quote.csv", replace

    clear
    set obs 4
    gen str10 dx1 = "E11"
    tempfile before9
    save "`before9'", replace

    capture codescan dx1, codefile("`qa_dir'/v422_cf_quote.csv")
    * 198, the package's own refusal -- not 199, which is what the corrupted
    * expansion produced when it ran on into the following line.
    assert _rc == 198
    capture confirm variable q1
    assert _rc != 0
    capture confirm variable dm2
    assert _rc != 0
    cf _all using "`before9'"
    unab _t9_vars : _all
    assert "`_t9_vars'" == "dx1"
    assert _N == 4
    capture erase "`qa_dir'/v422_cf_quote.csv"
}
if _rc == 0 {
    display as result "  PASS: T9 - unroundtrippable codefile value refused (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - unroundtrippable codefile value (error `=_rc')"
    local ++fail_count
}
capture erase "`qa_dir'/v422_cf_quote.csv"


**# T10: control - a lone double quote in a codefile pattern still scans

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str32 name = ""
    gen str80 pattern = ""
    gen str80 label = ""
    replace name = "q1" in 1
    replace pattern = "E1" + char(34) + "1" in 1
    replace label = "quote in pattern" in 1
    replace name = "dm2" in 2
    replace pattern = "E11" in 2
    replace label = "diabetes" in 2
    export delimited using "`qa_dir'/v422_cf_quote2.csv", replace

    clear
    set obs 4
    gen str10 dx1 = "E11"
    codescan dx1, codefile("`qa_dir'/v422_cf_quote2.csv")
    assert _rc == 0
    * The quoted pattern is a literal no code here carries, so it matches
    * nothing; the rule alongside it must still match, proving the whole file
    * was parsed rather than abandoned.
    assert q1 == 0
    assert dm2 == 1
    capture erase "`qa_dir'/v422_cf_quote2.csv"
}
if _rc == 0 {
    display as result "  PASS: T10 - lone double quote in a codefile pattern still scans"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - lone double quote in a codefile pattern (error `=_rc')"
    local ++fail_count
}
capture erase "`qa_dir'/v422_cf_quote2.csv"


* ============================================================
* M4 / I5 - documentation fixes, checked against the shipped files
*
* These two are doc-only, so the axis a user lives on is the shipped text
* itself: an example that cannot be rerun as written, and a return the README
* omits from the contract table.
* ============================================================

**# T11: the sthlp examples that write files are rerunnable as written

local ++test_count
capture noisily {
    tempname fh
    local _t11_save_ok = 0
    local _t11_exp_ok = 0
    local _t11_save_seen = 0
    local _t11_exp_seen = 0
    file open `fh' using "`pkg_dir'/codescan.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "save(dm_rules.csv") > 0 {
            local ++_t11_save_seen
            if strpos(`"`macval(line)'"', "save(dm_rules.csv, replace)") > 0 {
                local _t11_save_ok = 1
            }
        }
        if strpos(`"`macval(line)'"', "export(codescan_results.xlsx") > 0 {
            local ++_t11_exp_seen
            if strpos(`"`macval(line)'"', "export(codescan_results.xlsx, replace)") > 0 {
                local _t11_exp_ok = 1
            }
        }
        file read `fh' line
    }
    file close `fh'
    assert `_t11_save_seen' == 1
    assert `_t11_exp_seen' == 1
    assert `_t11_save_ok' == 1
    assert `_t11_exp_ok' == 1

    * ...and the commands those lines document do rerun.
    clear
    set obs 6
    gen str10 dx1 = cond(mod(_n,2) == 1, "E11", "I10")
    gen str10 dx2 = "Z00"
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") ///
        save("`qa_dir'/v422_dm_rules.csv", replace)
    drop dm2 htn
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") ///
        save("`qa_dir'/v422_dm_rules.csv", replace)
    assert _rc == 0
    capture erase "`qa_dir'/v422_dm_rules.csv"
}
if _rc == 0 {
    display as result "  PASS: T11 - sthlp file-writing examples carry replace"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - sthlp file-writing examples (error `=_rc')"
    local ++fail_count
}
capture erase "`qa_dir'/v422_dm_rules.csv"


**# T12: r(chapter_#) is returned, and the README documents it

local ++test_count
capture noisily {
    clear
    set obs 6
    gen str10 dx1 = cond(mod(_n,2) == 1, "E11", "I10")
    gen str10 dx2 = "Z00"
    codescan_describe dx1 dx2
    assert _rc == 0
    local _t12_nch = rowsof(r(chapters))
    assert `_t12_nch' > 0
    forvalues i = 1/`_t12_nch' {
        assert `"`r(chapter_`i')'"' != ""
    }

    * Read the README as DATA, not through macros: its lines carry backquotes
    * and double quotes, which a `"`macval(line)'"' round-trip cannot survive
    * (r(132), the same class of defect as M2 above).
    quietly import delimited using "`pkg_dir'/README.md", delimiter("\t") ///
        varnames(nonames) stringcols(_all) bindquote(nobind) clear
    * The row must be part of the stored-results TABLE, not a changelog bullet:
    * the release note announcing r(chapter_#) has been in the README since
    * 4.1.x while the contract table omitted it.
    quietly count if strpos(v1, "r(chapter_#)") > 0 & substr(trim(v1), 1, 1) == "|"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: T12 - r(chapter_#) returned and documented in README"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - r(chapter_#) contract (error `=_rc')"
    local ++fail_count
}


**# T13: no session setting leaked

local ++test_count
capture noisily {
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(frame)'" == "default"
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
_codescan_qa_publish "test_codescan_v422" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v422 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Functional Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"

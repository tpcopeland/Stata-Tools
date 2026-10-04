* test_codescan_v430.do - Regression tests for the v4.3.0 fixes
* Date: 2026-10-04
*
* Covers:
*   T1-T2:  a single-observation dataset with an empty or "." cell scans
*           (was r(3301) from a 1x0 selectindex() result)
*   T3-T5:  row-level indicators are missing on rows outside the analysis
*           sample, matching unmatched() and merge's three-state contract
*   T6-T8:  nodots refuses a regex literal period (\. or [.]) that can never
*           match the undotted data; the any-character "." stays accepted
*   T9-T11: codescan_describe returns byte-exact codes and chapters for
*           non-UTF-8 data, and its draft codefile escapes regex metacharacters
*   T12-T14: two output options aliased through a symlink are refused before
*           any work, and leave no file behind
*   T15-T18: save() records the matching options; codefile() refuses a call
*           whose options differ, and still accepts files without the column
*   T19:    the multi-window sensitivity table honours format()
*   T20:    no session setting leaked
*
* Every expected value is derived by hand from the input block next to it.

clear all
version 16.0
set varabbrev off
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
local _tmp "`c(tmpdir)'"
if substr("`_tmp'", -1, 1) != "/" local _tmp "`_tmp'/"
* A per-process unique stem: a fixed or seeded name collides with artifacts a
* previous (or concurrent) run left in the shared tmpdir.
tempfile _stem
local _tag = substr("`_stem'", strrpos("`_stem'", "/") + 1, .) + "_cs430"


**# T1: one observation, the second scan cell empty (regex and prefix)

local ++test_count
capture noisily {
    foreach _m in regex prefix {
        clear
        set obs 1
        gen str5 dx1 = "E11"
        gen str5 dx2 = ""
        codescan dx1 dx2, define(dm2 "E11") mode(`_m')
        assert r(N) == 1
        assert dm2[1] == 1
        assert r(summary)[1, 4] == 1
    }
}
if _rc == 0 {
    display as result "  PASS: T1 - single observation with an empty cell"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - single observation with an empty cell (error `=_rc')"
    local ++fail_count
}


**# T2: one observation, the first cell the "." placeholder, match in slot 2

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str5 dx1 = "."
    gen str5 dx2 = "I10"
    codescan dx1 dx2, define(htn "I1" | dm2 "E11") detail matched_code(mc)
    assert htn[1] == 1 & dm2[1] == 0
    assert mc[1] == "I10"
    * detail: the htn hit lives in dx2 (column 2), never in dx1
    assert r(varcounts)[1, 1] == 0 & r(varcounts)[1, 2] == 1
}
if _rc == 0 {
    display as result "  PASS: T2 - single observation with a placeholder cell"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - single observation with a placeholder cell (error `=_rc')"
    local ++fail_count
}


**# T3: row-level indicator is missing outside the time window

* Rows (date, refdate=110, lookback 30 exclusive): row 1 day 100 is in the
* window; rows 2 and 4 (day 10) are out; row 3 (day 100) is in. Analyzed
* rows 1 and 3: one E11 -> prevalence 1/2 = 50%.
local ++test_count
capture noisily {
    clear
    input str5 dx1 pid date refdate
    "E11" 1 100 110
    "E11" 1 10  110
    "I10" 2 100 110
    "E11" 3 10  110
    end
    codescan dx1, define(dm2 "E11") date(date) refdate(refdate) ///
        lookback(30) unmatched(um)
    assert r(N) == 2
    assert abs(r(summary)[1, 2] - 50) < 1e-9
    assert dm2[1] == 1 & dm2[3] == 0
    assert missing(dm2[2]) & missing(dm2[4])
    * One population: the indicator, unmatched(), and r(N) agree
    assert missing(dm2) == missing(um)
    count if !missing(dm2)
    assert r(N) == 2
    summarize dm2, meanonly
    assert abs(r(mean) - 0.5) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: T3 - indicator missing outside the window"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - indicator missing outside the window (error `=_rc')"
    local ++fail_count
}


**# T4: row-level countmode under if: counts missing outside, display intact

* Rows 1-3 analyzed (in 1/3): row 1 has two E11 slots (count 2), row 2 none,
* row 3 one. Row 4 is excluded and carries E11 twice. Hits 3, units 2 of 3.
local ++test_count
capture noisily {
    clear
    input str5 dx1 str5 dx2
    "E11" "E119"
    "I10" ""
    "E11" ""
    "E11" "E11"
    end
    codescan dx1 dx2 in 1/3, define(dm2 "E11") countmode cooccurrence
    assert r(N) == 3
    assert r(summary)[1, 3] == 3
    assert r(summary)[1, 4] == 2
    assert abs(r(summary)[1, 2] - 200/3) < 1e-9
    assert r(cooccurrence)[1, 1] == 2
    assert dm2[1] == 2 & dm2[2] == 0 & dm2[3] == 1
    assert missing(dm2[4])
}
if _rc == 0 {
    display as result "  PASS: T4 - countmode counts missing outside the sample"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - countmode outside the sample (error `=_rc')"
    local ++fail_count
}


**# T5: collapse and merge are unchanged by the row-level missing rule

* pid 1: rows in window, E11 -> 1. pid 2: in window, no match -> 0.
* pid 3: no row in window -> absent from collapse, missing under merge.
local ++test_count
capture noisily {
    clear
    input str5 dx1 pid date refdate
    "E11" 1 100 110
    "E11" 1 10  110
    "I10" 2 100 110
    "E11" 3 10  110
    end
    capture restore, not
    preserve
    codescan dx1, define(dm2 "E11") id(pid) date(date) refdate(refdate) ///
        lookback(30) collapse
    assert _N == 2
    sort pid
    assert dm2[1] == 1 & dm2[2] == 0
    restore
    codescan dx1, define(dm2 "E11") id(pid) date(date) refdate(refdate) ///
        lookback(30) merge
    assert dm2[1] == 1 & dm2[2] == 1 & dm2[3] == 0
    assert missing(dm2[4])
}
if _rc == 0 {
    display as result "  PASS: T5 - collapse/merge person-level values unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - collapse/merge values (error `=_rc')"
    local ++fail_count
}


**# T6: nodots refuses a regex escaped period in an inclusion pattern

local ++test_count
capture noisily {
    clear
    input str8 dx1
    "E11.0"
    "E11.9"
    end
    capture codescan dx1, define(dm2 "E11\.") nodots
    assert _rc == 198
    capture confirm variable dm2
    assert _rc == 111
    * Same pattern without nodots: both rows carry a literal period
    codescan dx1, define(dm2 "E11\.")
    assert r(summary)[1, 4] == 2
}
if _rc == 0 {
    display as result "  PASS: T6 - nodots refuses a regex literal period"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - nodots regex literal period (error `=_rc')"
    local ++fail_count
}


**# T7: nodots refuses [.] and an escaped period in an exclusion

local ++test_count
capture noisily {
    clear
    input str8 dx1
    "E11.0"
    "E11.9"
    end
    capture codescan dx1, define(dm2 "E11[.]") nodots
    assert _rc == 198
    * A dead exclusion would silently exclude nothing: E119 must not count
    capture codescan dx1, define(dm2 "E11" ~ "E11\.9") nodots
    assert _rc == 198
    * The undotted exclusion is the working form: only E110 remains
    codescan dx1, define(dm2 "E11" ~ "E119") nodots
    assert r(summary)[1, 4] == 1
}
if _rc == 0 {
    display as result "  PASS: T7 - nodots refuses [.] and dotted exclusions"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - nodots [.] / exclusion (error `=_rc')"
    local ++fail_count
}


**# T8: nodots keeps accepting the regex any-character "." and \\.

* "E1." -> E11 followed by any character: E110 and E119 both match.
* "E\\" -> a literal backslash after E is not a period: accepted, matches 0.
local ++test_count
capture noisily {
    clear
    input str8 dx1
    "E11.0"
    "E11.9"
    end
    codescan dx1, define(dm2 "E11.") nodots
    assert r(summary)[1, 4] == 2
    drop dm2
    codescan dx1, define(bs "E\\.") nodots
    assert r(summary)[1, 4] == 0
}
if _rc == 0 {
    display as result "  PASS: T8 - regex any-character period still accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - regex any-character period (error `=_rc')"
    local ++fail_count
}


**# T9: describe returns byte-exact codes and chapters for non-UTF-8 bytes

* Two entries "<0xE5>X1" (Latin-1 a-ring, invalid as UTF-8) and one "E11".
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str5 dx1 = char(229) + "X1"
    replace dx1 = "E11" in 3
    codescan_describe dx1
    assert r(n_unique) == 2
    assert r(top_codes)[1, 1] == 2
    assert `"`r(top_code_1)'"' == char(229) + "X1"
    assert strlen(`"`r(top_code_1)'"') == 3
    assert `"`r(chapter_1)'"' == char(229)
    assert `"`r(top_code_2)'"' == "E11"
    assert `"`r(chapter_2)'"' == "E"
}
if _rc == 0 {
    display as result "  PASS: T9 - describe returns byte-exact non-UTF-8 values"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - describe non-UTF-8 values (error `=_rc')"
    local ++fail_count
}


**# T10: describe's draft codefile escapes regex metacharacters

* Chapters "." (from ".5X") and "E". Unescaped, the "." rule would match every
* code; escaped, it matches only the one row that starts with a period.
local ++test_count
capture noisily {
    local _draft "`_tmp'`_tag'_draft.csv"
    capture erase "`_draft'"
    clear
    input str5 dx1
    ".5X"
    "E11"
    "E12"
    end
    codescan_describe dx1, save("`_draft'")
    capture restore, not
    preserve
    import delimited using "`_draft'", clear stringcols(_all) varnames(1)
    assert _N == 2
    assert pattern == "E" if name == "chapter_E"
    assert pattern == "\." if name != "chapter_E"
    restore
    codescan dx1, codefile("`_draft'")
    * chapter_E: 2 of 3 rows; the period chapter: 1 of 3
    assert r(summary)[rownumb(r(summary), "chapter_E"), 4] == 2
    local _pr = cond(rownumb(r(summary), "chapter_E") == 1, 2, 1)
    assert r(summary)[`_pr', 4] == 1
    erase "`_draft'"
}
if _rc == 0 {
    display as result "  PASS: T10 - draft codefile patterns are regex-escaped"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - draft codefile escaping (error `=_rc')"
    local ++fail_count
}


**# T11: describe draft pattern for a non-UTF-8 chapter is the raw byte

local ++test_count
capture noisily {
    local _draft "`_tmp'`_tag'_draft2.csv"
    capture erase "`_draft'"
    clear
    set obs 2
    gen str5 dx1 = char(229) + "X1"
    replace dx1 = "E11" in 2
    codescan_describe dx1, save("`_draft'")
    tempname fh
    file open `fh' using "`_draft'", read text
    file read `fh' line
    local _found = 0
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', char(229)) > 0 local _found = 1
        if strpos(`"`macval(line)'"', ustrunescape("�")) > 0 local _found = -1
        file read `fh' line
    }
    file close `fh'
    assert `_found' == 1
    erase "`_draft'"
}
if _rc == 0 {
    display as result "  PASS: T11 - draft codefile keeps the raw chapter byte"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - draft codefile raw byte (error `=_rc')"
    local ++fail_count
}


**# T12-T14: output options aliased through a symlink

local _symlink_ok = 0
if "`c(os)'" != "Windows" {
    local _real "`_tmp'`_tag'_real"
    local _lnk  "`_tmp'`_tag'_lnk"
    capture mkdir "`_real'"
    shell ln -s "`_real'" "`_lnk'"
    capture confirm file "`_lnk'/."
    if _rc == 0 local _symlink_ok = 1
}

**## T12: export and save naming one new file through a symlink are refused

local ++test_count
capture noisily {
    if `_symlink_ok' {
        clear
        input str5 dx1
        "E11"
        "I10"
        end
        capture codescan dx1, define(dm2 "E11") ///
            export("`_real'/out.csv") save("`_lnk'/out.csv")
        assert _rc == 198
        * Refused before any work: no file, no indicator
        capture confirm file "`_real'/out.csv"
        assert _rc == 601
        capture confirm variable dm2
        assert _rc == 111
    }
}
if _rc == 0 {
    display as result "  PASS: T12 - symlink-aliased new targets refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - symlink-aliased new targets (error `=_rc')"
    local ++fail_count
}

**## T13: aliased pre-existing targets authorized with replace are refused

local ++test_count
capture noisily {
    if `_symlink_ok' {
        clear
        input str5 dx1
        "E11"
        "I10"
        end
        codescan dx1, define(dm2 "E11") export("`_real'/pre.csv")
        drop dm2
        checksum "`_real'/pre.csv"
        local _ck0 = r(checksum)
        capture codescan dx1, define(dm2 "E11") ///
            export("`_real'/pre.csv", replace) save("`_lnk'/pre.csv", replace)
        assert _rc == 198
        checksum "`_real'/pre.csv"
        assert r(checksum) == `_ck0'
        erase "`_real'/pre.csv"
    }
}
if _rc == 0 {
    display as result "  PASS: T13 - symlink-aliased existing targets refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - symlink-aliased existing targets (error `=_rc')"
    local ++fail_count
}

**## T14: distinct targets in the same directory still both write

local ++test_count
capture noisily {
    if `_symlink_ok' {
        clear
        input str5 dx1
        "E11"
        "I10"
        end
        codescan dx1, define(dm2 "E11") ///
            export("`_real'/a.csv") save("`_lnk'/b.csv")
        confirm file "`_real'/a.csv"
        confirm file "`_real'/b.csv"
        capture restore, not
        preserve
        import delimited using "`_real'/a.csv", clear varnames(1)
        assert condition[1] == "dm2" & positive_units[1] == 1
        import delimited using "`_real'/b.csv", clear varnames(1) stringcols(_all)
        assert name[1] == "dm2" & pattern[1] == "E11"
        restore
        erase "`_real'/a.csv"
        erase "`_real'/b.csv"
    }
    if "`c(os)'" != "Windows" {
        capture erase "`_lnk'"
        shell rm -f "`_lnk'"
        shell rmdir "`_real'"
    }
}
if _rc == 0 {
    display as result "  PASS: T14 - distinct targets unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 - distinct targets (error `=_rc')"
    local ++fail_count
}


**# T15: save() records the matching options in a match column

local ++test_count
capture noisily {
    local _cf "`_tmp'`_tag'_rules.csv"
    capture erase "`_cf'"
    clear
    input str6 dx1
    "E1.1"
    "E1X1"
    end
    codescan dx1, define(c1 "E1.1") mode(prefix) nocase save("`_cf'")
    assert r(summary)[1, 4] == 1
    capture restore, not
    preserve
    import delimited using "`_cf'", clear stringcols(_all) varnames(1)
    assert match[1] == "mode(prefix) nocase"
    restore
}
if _rc == 0 {
    display as result "  PASS: T15 - save() writes the match column"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 - save() match column (error `=_rc')"
    local ++fail_count
}


**# T16: codefile() refuses a call whose matching options differ

* Reloaded in the default regex mode, "E1.1" would match both rows (was 2).
local ++test_count
capture noisily {
    clear
    input str6 dx1
    "E1.1"
    "E1X1"
    end
    capture codescan dx1, codefile("`_cf'")
    assert _rc == 198
    capture confirm variable c1
    assert _rc == 111
    capture codescan dx1, codefile("`_cf'") mode(prefix)
    assert _rc == 198
    * Same options: same cohort as the call that saved it
    codescan dx1, codefile("`_cf'") mode(prefix) nocase
    assert r(summary)[1, 4] == 1
    assert c1[1] == 1 & c1[2] == 0
    erase "`_cf'"
}
if _rc == 0 {
    display as result "  PASS: T16 - codefile() enforces the saved match options"
    local ++pass_count
}
else {
    display as error "  FAIL: T16 - codefile() match enforcement (error `=_rc')"
    local ++fail_count
}


**# T17: a codefile without a match column keeps working in any mode

local ++test_count
capture noisily {
    local _cf2 "`_tmp'`_tag'_hand.csv"
    capture erase "`_cf2'"
    tempname fh
    file open `fh' using "`_cf2'", write text replace
    file write `fh' "name,pattern" _n "dm2,E11" _n
    file close `fh'
    clear
    input str6 dx1
    "E110"
    "I10"
    end
    codescan dx1, codefile("`_cf2'")
    assert r(summary)[1, 4] == 1
    drop dm2
    codescan dx1, codefile("`_cf2'") mode(prefix)
    assert r(summary)[1, 4] == 1
    erase "`_cf2'"
}
if _rc == 0 {
    display as result "  PASS: T17 - codefile without match column accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T17 - codefile without match column (error `=_rc')"
    local ++fail_count
}


**# T18: inconsistent or unknown match values are refused

local ++test_count
capture noisily {
    local _cf3 "`_tmp'`_tag'_bad.csv"
    tempname fh
    clear
    input str6 dx1
    "E110"
    end
    foreach _body in "dm2,E11,mode(prefix)|htn,I10,mode(regex)" ///
                     "dm2,E11,mode(fuzzy)" "dm2,E11,nocase extra" {
        capture erase "`_cf3'"
        file open `fh' using "`_cf3'", write text replace
        file write `fh' "name,pattern,match" _n
        local _rest "`_body'"
        while "`_rest'" != "" {
            gettoken _line _rest : _rest, parse("|")
            if "`_line'" != "|" file write `fh' "`_line'" _n
        }
        file close `fh'
        capture codescan dx1, codefile("`_cf3'") mode(prefix)
        assert _rc == 198
    }
    erase "`_cf3'"
}
if _rc == 0 {
    display as result "  PASS: T18 - malformed match column refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T18 - malformed match column (error `=_rc')"
    local ++fail_count
}


**# T19: the multi-window sensitivity table honours format()

* pid1 E11 day -20; pid2 E11 day -80; pid3 I10 day -10. 30d: ids {1,3}, one
* match -> 50.000; 90d: ids {1,2,3}, two matches -> 66.667 (2/3).
local ++test_count
capture noisily {
    clear
    input pid str5 dx1 date
    1 "E11" -20
    2 "E11" -80
    3 "I10" -10
    end
    gen refdate = 0
    local _lg "`_tmp'`_tag'_sens.log"
    capture erase "`_lg'"
    log using "`_lg'", text name(_cs430) replace
    codescan dx1, define(dm2 "E11") id(pid) date(date) refdate(refdate) ///
        lookback(30 90) collapse format(%9.3f)
    matrix _cs430_S = r(sensitivity)
    log close _cs430
    assert abs(_cs430_S[1, 2] - 200/3) < 1e-9
    tempname fh
    file open `fh' using "`_lg'", read text
    local _hit = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "50.000") & strpos(`"`macval(line)'"', "66.667") {
            local _hit = 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `_hit' == 1
    erase "`_lg'"
}
if _rc == 0 {
    display as result "  PASS: T19 - sensitivity table uses format()"
    local ++pass_count
}
else {
    local _t19_rc = _rc
    capture log close _cs430
    display as error "  FAIL: T19 - sensitivity table format() (error `_t19_rc')"
    local ++fail_count
}


**# T20: no session setting leaked

local ++test_count
capture noisily {
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(frame)'" == "default"
}
if _rc == 0 {
    display as result "  PASS: T20 - no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: T20 - session setting leaked (error `=_rc')"
    local ++fail_count
}


**# Summary

_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v430" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v430 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Functional Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"

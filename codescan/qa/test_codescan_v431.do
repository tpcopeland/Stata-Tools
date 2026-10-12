* test_codescan_v431.do - Regression tests for the v4.3.1 fixes
*
* Covers:
*   T1:    codescan_describe returns every distinct code, byte exact
*   T2:    a regex pattern or exclusion keeps its outer spaces and matches
*          them literally, with a note in the log; prefix patterns still
*          trim; an internal space is kept; an all-space pattern is accepted
*   T3:    the regex backreference matches (case-sensitive and nocase); the
*          empty-match guards still refuse
*   T4:    a failed export() rolls back the new indicator, the collapse, and
*          the dataset; a valid export() is the positive control
*   T5:    codefile() ignores fully blank trailing rows; a row with an empty
*          name but a pattern is refused
*   T6:    the no-space separators | and ~ parse like the spaced forms; a
*          quoted | stays regex alternation
*   T7:    saving() refuses a .csv/.tsv/.txt/.xlsx/.xls extension and writes
*          nothing; a tempfile, a hex-extension tempfile-style name, and an
*          upper-case .DTA name are accepted
*   T8:    the describe draft carries a match column; the draft round-trips
*          through codefile() for regex-escaped and letter-only chapters
*   T9:    describe with one code works; a save() to a missing directory fails
*          with r(603) before any r() is posted
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
local _tag = substr("`_stem'", strrpos("`_stem'", "/") + 1, .) + "_cs431"


**# T1: describe returns all seven distinct codes

* Seven distinct codes; each must come back byte for byte as its own entry.
local ++test_count
capture noisily {
    clear
    input str8 dx1
    "E11.A"
    "a.b"
    "i.x"
    "1[A"
    "A#B"
    "E11.9"
    "I10"
    end
    codescan_describe dx1
    assert r(n_unique) == 7
    assert r(n_entries) == 7
    local _want1 "E11.A"
    local _want2 "a.b"
    local _want3 "i.x"
    local _want4 "1[A"
    local _want5 "A#B"
    local _want6 "E11.9"
    local _want7 "I10"
    forvalues _j = 1/7 {
        local _hit = 0
        forvalues _i = 1/7 {
            if `"`r(top_code_`_i')'"' == `"`_want`_j''"' local _hit = 1
        }
        assert `_hit' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: T1 - describe returns all seven distinct codes"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - describe seven distinct codes (error `=_rc')"
    local ++fail_count
}


**# T2: regex patterns keep their spaces and get a note; prefix trims; internal space kept

* Regex edge spaces are matched literally, never trimmed. codescan prints a
* note for an edge space, so each note is captured from a text log and read
* back. Long lines are not wrapped, so a note reads as one line.
local _ls_t2 = c(linesize)
set linesize 255

* Codes I10, E110, E116, X. The regex and prefix cases differ on " I10 ".
local ++test_count
capture noisily {
    clear
    input str6 dx1
    "I10"
    "E110"
    "E116"
    "X"
    end
    * Prefix mode still trims each prefix: " I10 " selects I10 only
    codescan dx1, define(pre " I10 ") mode(prefix)
    assert pre[1] == 1 & pre[2] == 0
    assert r(summary)[1, 4] == 1
    drop pre
    tempfile _t2log
    capture log close _t2
    log using "`_t2log'", text replace name(_t2)
    * Regex mode keeps the spaces: " I10 " matches no code here, with a note
    codescan dx1, define(htn " I10 ")
    assert htn[1] == 0 & htn[2] == 0
    assert r(summary)[1, 4] == 0
    drop htn
    * Exclusion "E116 " keeps its trailing space, so nothing is removed
    codescan dx1, define(dm2 "E11" ~ "E116 ")
    assert dm2[2] == 1 & dm2[3] == 1
    assert r(summary)[1, 4] == 2
    drop dm2
    * An all-space pattern is accepted, matches nothing, and is noted
    codescan dx1, define(x "  ")
    assert x[1] == 0 & x[4] == 0
    assert r(summary)[1, 4] == 0
    drop x
    log close _t2
    local _saw_h 0
    local _saw_e 0
    local _saw_x 0
    tempname fh
    file open `fh' using "`_t2log'", read text
    file read `fh' _t2line
    while r(eof) == 0 {
        if strpos(`"`macval(_t2line)'"', "regex pattern for htn begins with a space") local _saw_h 1
        if strpos(`"`macval(_t2line)'"', "regex exclusion for dm2 ends with a space") local _saw_e 1
        if strpos(`"`macval(_t2line)'"', "regex pattern for x begins with a space") local _saw_x 1
        file read `fh' _t2line
    }
    file close `fh'
    erase "`_t2log'"
    assert `_saw_h' == 1 & `_saw_e' == 1 & `_saw_x' == 1
}
if _rc == 0 {
    display as result "  PASS: T2a - define() regex keeps padding, notes it, prefix still trims"
    local ++pass_count
}
else {
    capture log close _t2
    display as error "  FAIL: T2a - define() regex padding and notes (error `=_rc')"
    local ++fail_count
}

* Codefile rows: the pattern " I10" and "E11 " keep their spaces; name and
* label are trimmed. Both padded regex fields get a note.
local ++test_count
capture noisily {
    local _cf "`_tmp'`_tag'_t2.csv"
    capture erase "`_cf'"
    tempname fh
    file open `fh' using "`_cf'", write text replace
    file write `fh' "name,pattern,exclusion,label" _n
    file write `fh' "dm2,E11 ,E116 ," _n
    file write `fh' "htn, I10,," _n
    file close `fh'
    clear
    input str6 dx1
    "I10"
    "E110"
    "E116"
    "X"
    end
    tempfile _t2log
    capture log close _t2
    log using "`_t2log'", text replace name(_t2)
    codescan dx1, codefile("`_cf'")
    * " I10" as a regex needs a leading space, so htn matches nothing
    assert htn[1] == 0 & htn[2] == 0
    assert r(summary)[rownumb(r(summary), "htn"), 4] == 0
    * "E11 " needs a trailing space, so dm2 matches nothing
    assert dm2[2] == 0 & dm2[3] == 0
    assert r(summary)[rownumb(r(summary), "dm2"), 4] == 0
    * log close clears r(), so it waits until the r() asserts have run
    log close _t2
    local _saw_h 0
    local _saw_d 0
    tempname lh
    file open `lh' using "`_t2log'", read text
    file read `lh' _t2line
    while r(eof) == 0 {
        if strpos(`"`macval(_t2line)'"', "regex pattern for htn begins with a space") local _saw_h 1
        if strpos(`"`macval(_t2line)'"', "regex pattern for dm2 ends with a space") local _saw_d 1
        file read `lh' _t2line
    }
    file close `lh'
    erase "`_t2log'"
    erase "`_cf'"
    assert `_saw_h' == 1 & `_saw_d' == 1
}
if _rc == 0 {
    display as result "  PASS: T2b - codefile() keeps padded regex fields literal, with notes"
    local ++pass_count
}
else {
    capture log close _t2
    display as error "  FAIL: T2b - codefile() padded regex fields (error `=_rc')"
    local ++fail_count
}

* An internal space is part of the code, not a separator
local ++test_count
capture noisily {
    clear
    input str6 dx1
    "E11 9"
    "E119"
    end
    codescan dx1, define(sp "E11 9")
    assert sp[1] == 1 & sp[2] == 0
    assert r(summary)[1, 4] == 1
}
if _rc == 0 {
    display as result "  PASS: T2c - internal space kept in the pattern"
    local ++pass_count
}
else {
    display as error "  FAIL: T2c - internal space (error `=_rc')"
    local ++fail_count
}

* A regex with optional leading spaces (" *I21") is deliberate: no note
local ++test_count
capture noisily {
    clear
    input str8 dx1
    "I21"
    "  I21"
    "I20"
    end
    tempfile _t2log
    capture log close _t2
    log using "`_t2log'", text replace name(_t2)
    codescan dx1, define(mi " *I21")
    assert mi[1] == 1 & mi[2] == 1 & mi[3] == 0
    assert r(summary)[1, 4] == 2
    * log close clears r(), so it waits until the r() asserts have run
    log close _t2
    local _bad 0
    tempname nh
    file open `nh' using "`_t2log'", read text
    file read `nh' _t2line
    while r(eof) == 0 {
        if strpos(`"`macval(_t2line)'"', "must match literally") local _bad 1
        if strpos(`"`macval(_t2line)'"', "begins with a space") local _bad 1
        if strpos(`"`macval(_t2line)'"', "ends with a space") local _bad 1
        file read `nh' _t2line
    }
    file close `nh'
    erase "`_t2log'"
    assert `_bad' == 0
}
if _rc == 0 {
    display as result "  PASS: T2d - optional-space regex matches both rows, no note"
    local ++pass_count
}
else {
    capture log close _t2
    display as error "  FAIL: T2d - optional-space regex (error `=_rc')"
    local ++fail_count
}

set linesize `_ls_t2'



**# T3: backreference matches; empty-match guards still refuse

local ++test_count
capture noisily {
    clear
    input str4 dx1
    "AA1"
    "AB1"
    "aa1"
    end
    codescan dx1, define(dbl "(A)\1")
    assert dbl[1] == 1 & dbl[2] == 0 & dbl[3] == 0
    assert r(summary)[1, 4] == 1
    drop dbl
    * nocase folds the case: aa1 now matches the backreference too
    codescan dx1, define(dbl "(A)\1") nocase
    assert dbl[1] == 1 & dbl[2] == 0 & dbl[3] == 1
    assert r(summary)[1, 4] == 2
}
if _rc == 0 {
    display as result "  PASS: T3a - backreference matches, nocase folds case"
    local ++pass_count
}
else {
    display as error "  FAIL: T3a - backreference (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str4 dx1
    "AA1"
    end
    capture codescan dx1, define(x "\b")
    assert _rc == 198
    capture codescan dx1, define(x "A*")
    assert _rc == 198
    capture codescan dx1, define(x "E11|")
    assert _rc == 198
    capture confirm variable x
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T3b - empty-match patterns still refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T3b - empty-match guards (error `=_rc')"
    local ++fail_count
}


**# T4: failed export() rolls back everything; valid export is the control

local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    "I10" 3
    end
    capture codescan dx1, define(dm2 "E11") export("/nonexistent_dir_cs431/x.csv")
    assert _rc == 603
    capture confirm variable dm2
    assert _rc == 111
    assert "`r(newvars)'" == ""
    assert _N == 4
    assert r(merged) == 0
    assert "`r(frame)'" == ""
}
if _rc == 0 {
    display as result "  PASS: T4a - failed export() leaves no indicator"
    local ++pass_count
}
else {
    display as error "  FAIL: T4a - failed export() rollback (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    "I10" 3
    end
    capture codescan dx1, define(dm2 "E11") id(pid) collapse preserve ///
        export("/nonexistent_dir_cs431/x.csv")
    assert _rc == 603
    assert _N == 4
    assert r(collapsed) == 0
    capture confirm variable dm2
    assert _rc == 111
    assert r(merged) == 0
    assert "`r(frame)'" == ""
}
if _rc == 0 {
    display as result "  PASS: T4b - failed export() with collapse restores the dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: T4b - failed export() with collapse (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    "I10" 3
    end
    capture codescan dx1, define(dm2 "E11") id(pid) merge ///
        export("/nonexistent_dir_cs431/x.csv")
    assert _rc == 603
    capture confirm variable dm2
    assert _rc == 111
    assert _N == 4
    assert r(merged) == 0
    assert "`r(newvars)'" == ""
}
if _rc == 0 {
    display as result "  PASS: T4d - failed export() with merge leaves no indicator"
    local ++pass_count
}
else {
    display as error "  FAIL: T4d - failed export() with merge (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    "I10" 3
    end
    local _ok "`_tmp'`_tag'_ok.csv"
    capture erase "`_ok'"
    codescan dx1, define(dm2 "E11") export("`_ok'")
    assert "`r(newvars)'" == "dm2"
    assert dm2[1] == 1 & dm2[2] == 0 & dm2[3] == 1
    confirm file "`_ok'"
    erase "`_ok'"
    * The same valid export under collapse reports the collapse
    drop dm2
    codescan dx1, define(dm2 "E11") id(pid) collapse export("`_ok'")
    assert r(collapsed) == 1
    assert _N == 3
    erase "`_ok'"
}
if _rc == 0 {
    display as result "  PASS: T4c - valid export() positive control"
    local ++pass_count
}
else {
    display as error "  FAIL: T4c - valid export() control (error `=_rc')"
    local ++fail_count
}


**# T5: blank trailing codefile rows ignored; empty-name row refused

local ++test_count
capture noisily {
    local _cf "`_tmp'`_tag'_t5.csv"
    capture erase "`_cf'"
    tempname fh
    file open `fh' using "`_cf'", write text replace
    file write `fh' "name,pattern,exclusion,label" _n
    file write `fh' "dm2,E11,," _n
    file write `fh' ",,," _n
    file write `fh' "htn,I10,," _n
    file write `fh' ",," _n
    file close `fh'
    clear
    input str6 dx1
    "E110"
    "I10"
    "X"
    end
    codescan dx1, codefile("`_cf'")
    assert r(n_conditions) == 2
    assert dm2[1] == 1 & dm2[3] == 0
    assert htn[2] == 1 & htn[3] == 0
    assert r(summary)[rownumb(r(summary), "dm2"), 4] == 1
    assert r(summary)[rownumb(r(summary), "htn"), 4] == 1
    erase "`_cf'"
}
if _rc == 0 {
    display as result "  PASS: T5a - blank trailing rows ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: T5a - blank trailing rows (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local _cf "`_tmp'`_tag'_t5b.csv"
    capture erase "`_cf'"
    tempname fh
    file open `fh' using "`_cf'", write text replace
    file write `fh' "name,pattern,exclusion,label" _n
    file write `fh' "dm2,E11,," _n
    file write `fh' ",I10,," _n
    file close `fh'
    clear
    input str6 dx1
    "E110"
    end
    capture codescan dx1, codefile("`_cf'")
    assert _rc == 198
    capture confirm variable dm2
    assert _rc == 111
    erase "`_cf'"
}
if _rc == 0 {
    display as result "  PASS: T5b - row with empty name but a pattern refused"
    local ++pass_count
}
else {
    display as error "  FAIL: T5b - empty-name row (error `=_rc')"
    local ++fail_count
}


**# T6: no-space separators parse like the spaced forms

* Two runs with different names; each pair must agree row by row.
local ++test_count
capture noisily {
    clear
    input str6 dx1
    "E110"
    "E116"
    "I10"
    "X"
    end
    codescan dx1, define(a1 "E11"|b1 "I10")
    codescan dx1, define(a2 "E11" | b2 "I10")
    assert a1 == a2 & b1 == b2
    assert a1[1] == 1 & a1[2] == 1 & a1[3] == 0
    assert b1[3] == 1 & b1[1] == 0
    codescan dx1, define(c1 "E11"~"E116"|d1 "I10")
    codescan dx1, define(c2 "E11" ~ "E116" | d2 "I10")
    assert c1 == c2 & d1 == d2
    assert c1[1] == 1 & c1[2] == 0 & d1[3] == 1
}
if _rc == 0 {
    display as result "  PASS: T6a - no-space | and ~ match the spaced forms"
    local ++pass_count
}
else {
    display as error "  FAIL: T6a - no-space separators (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str6 dx1
    "E110"
    "I10"
    "X"
    end
    codescan dx1, define(a "E11|I10")
    assert a[1] == 1 & a[2] == 1 & a[3] == 0
    assert r(summary)[1, 4] == 2
}
if _rc == 0 {
    display as result "  PASS: T6b - quoted | stays regex alternation"
    local ++pass_count
}
else {
    display as error "  FAIL: T6b - quoted pipe alternation (error `=_rc')"
    local ++fail_count
}


**# T7: saving() refuses a .csv/.tsv/.txt/.xlsx/.xls extension and writes nothing; a tempfile, a hex-extension tempfile-style name, and an upper-case .DTA name are accepted

local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    end
    foreach _ext in csv tsv txt xlsx xls TXT XLSX {
        local _sv "`_tmp'`_tag'_rules.`_ext'"
        capture erase "`_sv'"
        capture codescan dx1, define(dm2 "E11") id(pid) collapse saving("`_sv'")
        assert _rc == 198
        capture confirm file "`_sv'"
        assert _rc == 601
        capture confirm variable dm2
        assert _rc == 111
        assert _N == 3
    }
}
if _rc == 0 {
    display as result "  PASS: T7a - saving() refuses csv/tsv/txt/xlsx/xls/TXT/XLSX, no file"
    local ++pass_count
}
else {
    display as error "  FAIL: T7a - saving() extension refusal (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    end
    tempfile tf
    capture restore, not
    preserve
    codescan dx1, define(dm2 "E11") id(pid) collapse saving(`tf')
    assert _N == 2
    restore
    confirm file `tf'
    use `tf', clear
    assert _N == 2
    sort pid
    assert dm2[1] == 1 & dm2[2] == 1
}
if _rc == 0 {
    display as result "  PASS: T7b - saving() to a tempfile writes the collapsed data"
    local ++pass_count
}
else {
    display as error "  FAIL: T7b - saving() tempfile (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    end
    tempfile base
    local _up "`base'.DTA"
    capture erase "`_up'"
    capture restore, not
    preserve
    codescan dx1, define(dm2 "E11") id(pid) collapse saving("`_up'")
    restore
    confirm file "`_up'"
    use "`_up'", clear
    assert _N == 2
    sort pid
    assert dm2[1] == 1 & dm2[2] == 1
    erase "`_up'"
}
if _rc == 0 {
    display as result "  PASS: T7c - saving() accepts an upper-case .DTA name"
    local ++pass_count
}
else {
    display as error "  FAIL: T7c - saving() .DTA name (error `=_rc')"
    local ++fail_count
}

* A Stata tempfile name carries a hex extension (St<digits>.<hex>) and a
* .v2 name is an ordinary extension; both must save and reload.
local ++test_count
capture noisily {
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    end
    local _st "`_tmp'`_tag'_St99999.00000d"
    local _v2 "`_tmp'`_tag'_snap.v2"
    capture erase "`_st'"
    capture erase "`_v2'"
    capture restore, not
    preserve
    codescan dx1, define(dm2 "E11") id(pid) collapse saving("`_st'")
    assert _N == 2
    restore
    confirm file "`_st'"
    use "`_st'", clear
    assert _N == 2
    sort pid
    assert dm2[1] == 1 & dm2[2] == 1
    erase "`_st'"
    clear
    input str5 dx1 long pid
    "E11" 1
    "I10" 1
    "E11" 2
    end
    capture restore, not
    preserve
    codescan dx1, define(dm2 "E11") id(pid) collapse saving("`_v2'")
    assert _N == 2
    restore
    confirm file "`_v2'"
    use "`_v2'", clear
    assert _N == 2
    sort pid
    assert dm2[1] == 1 & dm2[2] == 1
    erase "`_v2'"
}
if _rc == 0 {
    display as result "  PASS: T7d - saving() accepts a hex-extension tempfile-style name and .v2"
    local ++pass_count
}
else {
    display as error "  FAIL: T7d - saving() hex-extension and .v2 names (error `=_rc')"
    local ++fail_count
}


**# T8: describe draft round-trips through codefile()

* Chapters "$" (regex metacharacter, escaped) and "(" and "E". The draft's
* match column is mode(regex) on every row because one chapter is a regex.
local ++test_count
capture noisily {
    local _dr "`_tmp'`_tag'_draft.csv"
    capture erase "`_dr'"
    clear
    input str6 dx1
    "$AB"
    "(CD"
    "E11"
    end
    codescan_describe dx1, save("`_dr'", replace)
    capture restore, not
    preserve
    import delimited using "`_dr'", clear stringcols(_all) varnames(1)
    assert _N == 3
    count if !strpos(match, "regex")
    assert r(N) == 0
    count if strpos(pattern, char(36)) > 0
    assert r(N) == 1
    count if pattern == char(92) + char(36)
    assert r(N) == 1
    levelsof name if strpos(pattern, char(36)) > 0, local(_dname) clean
    restore
    * The "$" chapter matches the one row that starts with a dollar sign
    codescan dx1, codefile("`_dr'")
    assert r(summary)[rownumb(r(summary), "`_dname'"), 4] == 1
    * The draft pins regex matching: prefix mode is refused
    capture codescan dx1, codefile("`_dr'") mode(prefix)
    assert _rc == 198
    erase "`_dr'"
}
if _rc == 0 {
    display as result "  PASS: T8a - regex draft has match column and round-trips"
    local ++pass_count
}
else {
    display as error "  FAIL: T8a - regex draft round-trip (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local _dr2 "`_tmp'`_tag'_letters.csv"
    capture erase "`_dr2'"
    clear
    input str6 dx1
    "E11"
    "I10"
    end
    codescan_describe dx1, save("`_dr2'", replace)
    capture restore, not
    preserve
    import delimited using "`_dr2'", clear stringcols(_all) varnames(1)
    assert _N == 2
    * Letters-only chapters leave match empty on every row
    count if strtrim(match) != ""
    assert r(N) == 0
    restore
    * Letter chapters are ordinary text: prefix mode works on the draft
    clear
    input str6 dx1
    "E110"
    "E119"
    "I10"
    "X"
    end
    codescan dx1, codefile("`_dr2'") mode(prefix)
    assert r(summary)[rownumb(r(summary), "chapter_E"), 4] == 2
    assert r(summary)[rownumb(r(summary), "chapter_I"), 4] == 1
    erase "`_dr2'"
}
if _rc == 0 {
    display as result "  PASS: T8b - letters-only draft accepted in prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: T8b - letters-only draft (error `=_rc')"
    local ++fail_count
}


**# T9: single-code describe; save() to a missing directory fails early

local ++test_count
capture noisily {
    clear
    input str5 dx1
    "E11"
    end
    tempfile _t9log
    capture log close _t9
    log using "`_t9log'", text replace name(_t9)
    codescan_describe dx1
    assert r(n_unique) == 1
    assert r(n_entries) == 1
    assert `"`r(top_code_1)'"' == "E11"
    log close _t9
    * The header pluralizes on the counts: singular for one code and one entry
    local _saw_code 0
    local _saw_entry 0
    local _saw_plural 0
    file open _t9fh using "`_t9log'", read text
    file read _t9fh _t9line
    while r(eof) == 0 {
        if strpos(`"`macval(_t9line)'"', "1 unique code,") local _saw_code 1
        if strpos(`"`macval(_t9line)'"', "1 total entry") local _saw_entry 1
        if strpos(`"`macval(_t9line)'"', "total entries") local _saw_plural 1
        file read _t9fh _t9line
    }
    file close _t9fh
    assert `_saw_code' == 1
    assert `_saw_entry' == 1
    assert `_saw_plural' == 0
}
if _rc == 0 {
    display as result "  PASS: T9a - single-code describe, singular header text"
    local ++pass_count
}
else {
    capture log close _t9
    display as error "  FAIL: T9a - single-code describe (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str5 dx1
    "E11"
    "I10"
    end
    return clear
    capture codescan_describe dx1, save("/nonexistent_dir_cs431/x.csv")
    assert _rc == 603
    assert "`r(n_unique)'" == ""
}
if _rc == 0 {
    display as result "  PASS: T9b - save() to missing directory fails with 603"
    local ++pass_count
}
else {
    display as error "  FAIL: T9b - save() missing directory (error `=_rc')"
    local ++fail_count
}


**# Summary

assert "`c(varabbrev)'" == "`_qa_va0'"
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v431" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v431 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Functional Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"

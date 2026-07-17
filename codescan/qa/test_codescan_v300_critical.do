* test_codescan_v300_critical.do
* Regression suite for the five critical defects C1-C5 reported in the
* 2026-07-11 deep audit. Every block here was confirmed RED on v2.0.9 before
* the corresponding fix was written.
*
* C1 late-error rollback        C2 empty-match regexes    C3 codefile column types
* C4 extended numeric missings  C5 file-overwrite authorization
*
* Two traps this suite is built to avoid, both of which produced false greens
* during authoring:
*   - `cf _all using' compares only the variables present in the MASTER data, so
*     it cannot see a variable that was wrongly dropped. Data integrity is
*     therefore asserted with datasignature (which covers K) plus an explicit
*     varlist comparison, and cf only for values.
*   - `tempfile' yields an extensionless path. codefile()/export()/save() screen
*     the extension first, so a tempfile target fails with r(198) from the
*     extension check and never reaches the code under test. All file targets
*     here carry a real extension under c(tmpdir).

clear all
set varabbrev off
version 16.0

capture log close
log using "test_codescan_v300_critical.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


local tmp "`c(tmpdir)'"

**# Helpers

* Assert that a text file contains a literal string.
*
* Two traps, both of which produced a false green while this was being written:
*
*   - text() takes `string', NOT `string asis'. With asis the option value keeps
*     its own quotes, so text("Hits") searched for the 5 characters "Hits"
*     INCLUDING quotes -- which a Stata log always contains, because it echoes
*     the command line that has label(dm2 "Hits") in it. The assertion then
*     passes on the echo and never looks at the output.
*   - The file is read as DATA, not into macros: those same echoed quotes kill
*     a `file read' line the moment it is re-quoted (r(132)). bindquotes(nobind)
*     stops import delimited treating them as string delimiters.
*   - The delimiter is char(1), which cannot occur in a log or an SVG, so each
*     line arrives whole in v1. A tab delimiter looks like the obvious choice
*     and is wrong: Stata indents exported SVG with tabs, so every bar label
*     landed in v2 and a search of v1 found nothing.
capture program drop _assert_file_has
program define _assert_file_has
    syntax , file(string) text(string) [reload(string)]
    local sep = char(1)
    quietly import delimited using "`file'", clear delimiter("`sep'") ///
        varnames(nonames) stringcols(_all) bindquotes(nobind)
    quietly count if strpos(v1, `"`text'"') > 0
    local hits = r(N)
    if `"`reload'"' != "" quietly use `"`reload'"', clear
    if `hits' == 0 {
        display as error `"`file' does not contain: `text'"'
        exit 9
    }
end

* Inverse of the above: prove a string is ABSENT. Without this, "the console
* shows the label" passes just as well on output that shows the label AND the
* raw name, which is not what the contract promises for the Condition column.
capture program drop _assert_file_lacks
program define _assert_file_lacks
    syntax , file(string) text(string) [reload(string)]
    local sep = char(1)
    quietly import delimited using "`file'", clear delimiter("`sep'") ///
        varnames(nonames) stringcols(_all) bindquotes(nobind)
    quietly count if strpos(v1, `"`text'"') > 0
    local hits = r(N)
    if `"`reload'"' != "" quietly use `"`reload'"', clear
    if `hits' > 0 {
        display as error `"`file' unexpectedly contains: `text'"'
        exit 9
    }
end

* Two patients whose hit counts and slot positions differ, which is what makes
* I3 and I5 observable at all:
*   pid 1 row 1 carries E11 in BOTH dx1 and dx2 -> 2 hits, 1 unit, and a row
*                whose detail attribution depends on varlist order
*   pid 2 row 3 carries E11 in dx2 only        -> 1 hit,  1 unit
* So total_hits = 3 while positive_units = 2, and reversing the varlist moves
* row 1 from dx1 to dx2 in r(varcounts) without touching the cohort.
*
* Built with gen/replace rather than `input': the `end' that closes an input
* block would close the `program define' instead, and the program silently ends
* up holding only the input header.
capture program drop _mk_slots_data
program define _mk_slots_data
    clear
    quietly set obs 3
    quietly gen long pid = cond(_n < 3, 1, 2)
    quietly gen str6 dx1 = ""
    quietly gen str6 dx2 = ""
    quietly replace dx1 = "E110" in 1
    quietly replace dx2 = "E119" in 1
    quietly replace dx1 = "I10"  in 2
    quietly replace dx2 = "Z00"  in 2
    quietly replace dx1 = "Z00"  in 3
    quietly replace dx2 = "E118" in 3
end

* The audit's reproducer: two rows, a pre-existing byte dm2 = 7, 9 whose name
* collides with the planned output.
capture program drop _mk_c1_data
program define _mk_c1_data
    clear
    set obs 2
    gen str5 dx1 = "E11" in 1
    quietly replace dx1 = "I10" in 2
    gen long pid = _n
    gen byte dm2 = 7 in 1
    quietly replace dm2 = 9 in 2
end

* Record the full identity of the current data.
capture program drop _snap_data
program define _snap_data, rclass
    quietly datasignature
    return local sig "`r(datasignature)'"
    quietly ds
    return local vars "`r(varlist)'"
end

* Assert the current data is identical to a recorded snapshot. datasignature
* covers N, K, and values -- crucially it changes when a variable is dropped,
* which cf _all cannot detect.
capture program drop _assert_intact
program define _assert_intact
    args snapfile sig0 vars0
    quietly datasignature
    if "`r(datasignature)'" != "`sig0'" {
        display as error "  datasignature drift: expected `sig0' got `r(datasignature)'"
        exit 9
    }
    quietly ds
    if "`r(varlist)'" != "`vars0'" {
        display as error "  varlist drift: expected [`vars0'] got [`r(varlist)']"
        exit 9
    }
    cf _all using "`snapfile'"
end

* Write a one-column sentinel CSV whose survival proves no overwrite happened.
capture program drop _mk_sentinel_csv
program define _mk_sentinel_csv
    args path
    preserve
    clear
    set obs 1
    gen byte sentinel = 1
    quietly export delimited using "`path'", replace
    restore
end

capture program drop _assert_sentinel_alive
program define _assert_sentinel_alive
    args path
    preserve
    quietly import delimited using "`path'", clear varnames(1)
    confirm variable sentinel
    restore
end

**# C1: late errors must not damage the caller dataset

**## C1a: preserve + replace, late saving() failure

* The failure must land AFTER the indicators are built and the pre-existing dm2
* has been dropped -- that is the window C1 is about. An occupied target no
* longer works, because C5's authorization check now rejects that at option-
* validation time, before any mutation. A nonexistent directory passes both the
* metacharacter screen and the existence check, and fails at `save' time.
local ++test_count
capture noisily {
    _mk_c1_data
    local c1a_snap "`tmp'/codescan_qa_c1a_snap.dta"
    quietly save "`c1a_snap'", replace
    _snap_data
    local c1a_sig "`r(sig)'"
    local c1a_vars "`r(vars)'"

    capture codescan dx1, define(dm2 "E11") id(pid) collapse preserve replace ///
        saving("`tmp'/codescan_qa_no_such_dir/out.dta")
    assert _rc != 0

    _assert_intact "`c1a_snap'" "`c1a_sig'" "`c1a_vars'"
}
if _rc {
    local ++fail_count
    display as error "FAIL: C1a preserve+replace late saving() failure damages caller data"
}
else {
    local ++pass_count
    display as text "PASS: C1a preserve+replace late saving() failure preserves caller data"
}
capture erase "`tmp'/codescan_qa_c1a_snap.dta"

**## C1b: in-place (no preserve) replace, late export() failure

local ++test_count
capture noisily {
    _mk_c1_data
    local c1b_snap "`tmp'/codescan_qa_c1b_snap.dta"
    quietly save "`c1b_snap'", replace
    _snap_data
    local c1b_sig "`r(sig)'"
    local c1b_vars "`r(vars)'"

    * A nonexistent directory passes _codescan_validate_path (which screens shell
    * metacharacters, not existence) and fails at export time -- i.e. after the
    * pre-existing dm2 has already been dropped and replaced.
    capture codescan dx1, define(dm2 "E11") replace ///
        export("`tmp'/codescan_qa_no_such_dir/out.csv")
    assert _rc != 0

    _assert_intact "`c1b_snap'" "`c1b_sig'" "`c1b_vars'"
}
if _rc {
    local ++fail_count
    display as error "FAIL: C1b in-place replace late export() failure damages caller data"
}
else {
    local ++pass_count
    display as text "PASS: C1b in-place replace late export() failure preserves caller data"
}
capture erase "`tmp'/codescan_qa_c1b_snap.dta"

**## C1c: in-place replace with no pre-existing collision, late failure

local ++test_count
capture noisily {
    clear
    set obs 2
    gen str5 dx1 = "E11" in 1
    quietly replace dx1 = "I10" in 2
    gen long pid = _n
    local c1c_snap "`tmp'/codescan_qa_c1c_snap.dta"
    quietly save "`c1c_snap'", replace
    _snap_data
    local c1c_sig "`r(sig)'"
    local c1c_vars "`r(vars)'"

    capture codescan dx1, define(dm2 "E11") replace ///
        export("`tmp'/codescan_qa_no_such_dir/out.csv")
    assert _rc != 0

    * dm2 did not exist before the call, so rollback must leave it absent.
    _assert_intact "`c1c_snap'" "`c1c_sig'" "`c1c_vars'"
}
if _rc {
    local ++fail_count
    display as error "FAIL: C1c late failure left a partial output variable behind"
}
else {
    local ++pass_count
    display as text "PASS: C1c late failure leaves no partial output variable"
}
capture erase "`tmp'/codescan_qa_c1c_snap.dta"

**# C2: every empty-match regex must be rejected before any output is created

* Each of these anchors as ^(pat) and matches the start of every code: as an
* inclusion it is match-everything, as an exclusion it is exclude-everything.
* Note: define() splits conditions on "|", so an alternation cannot be passed
* inline here; the (E11|) case is covered through codefile() below.
local c2_pats `" "()" "(())" "A*" "A?" "A{0}" "'

foreach p of local c2_pats {
    local ++test_count
    capture noisily {
        _mk_c1_data
        capture codescan dx1, define(empty `"`p'"')
        assert _rc == 198
        capture confirm variable empty
        assert _rc != 0
    }
    if _rc {
        local ++fail_count
        display as error `"FAIL: C2 inclusion `p' not rejected"'
    }
    else {
        local ++pass_count
        display as text `"PASS: C2 inclusion `p' rejected with r(198)"'
    }
}

foreach p of local c2_pats {
    local ++test_count
    capture noisily {
        _mk_c1_data
        capture codescan dx1, define(dm2 "E11" ~ `"`p'"')
        assert _rc == 198
        * A rejected exclusion must not leave the indicator behind, and must not
        * disturb the pre-existing dm2.
        assert dm2[1] == 7 & dm2[2] == 9
    }
    if _rc {
        local ++fail_count
        display as error `"FAIL: C2 exclusion `p' not rejected"'
    }
    else {
        local ++pass_count
        display as text `"PASS: C2 exclusion `p' rejected with r(198)"'
    }
}

**## C2: empty-match patterns are rejected from a codefile source too

local ++test_count
capture noisily {
    local c2_cf "`tmp'/codescan_qa_c2_cf.dta"
    preserve
    clear
    set obs 1
    gen str10 name = "empty"
    gen str10 pattern = "(E11|)"
    quietly save "`c2_cf'", replace
    restore

    _mk_c1_data
    capture codescan dx1, codefile("`c2_cf'")
    assert _rc == 198
    capture confirm variable empty
    assert _rc != 0
}
if _rc {
    local ++fail_count
    display as error "FAIL: C2 empty-match pattern from codefile not rejected"
}
else {
    local ++pass_count
    display as text "PASS: C2 empty-match pattern from codefile rejected with r(198)"
}
capture erase "`tmp'/codescan_qa_c2_cf.dta"

**## C2: legitimate patterns must still be accepted

local ++test_count
capture noisily {
    _mk_c1_data
    codescan dx1, define(dm2 "E11" | htn "I1[0-35]") replace
    assert dm2[1] == 1 & dm2[2] == 0
    assert htn[1] == 0 & htn[2] == 1
}
if _rc {
    local ++fail_count
    display as error "FAIL: C2 legitimate patterns rejected or mismatched"
}
else {
    local ++pass_count
    display as text "PASS: C2 legitimate patterns still accepted"
}

**# C3: optional codefile columns present with the wrong type must error

**## C3a: numeric exclusion column

local ++test_count
capture noisily {
    local c3a_cf "`tmp'/codescan_qa_c3a_cf.dta"
    preserve
    clear
    set obs 1
    gen str10 name = "dm2"
    gen str10 pattern = "1"
    gen int exclusion = 116
    quietly save "`c3a_cf'", replace
    restore

    clear
    set obs 2
    gen str5 dx1 = "116" in 1
    quietly replace dx1 = "200" in 2

    capture codescan dx1, codefile("`c3a_cf'")
    assert _rc == 198
    capture confirm variable dm2
    assert _rc != 0
}
if _rc {
    local ++fail_count
    display as error "FAIL: C3a numeric exclusion column silently ignored"
}
else {
    local ++pass_count
    display as text "PASS: C3a numeric exclusion column rejected with r(198)"
}
capture erase "`tmp'/codescan_qa_c3a_cf.dta"

**## C3b: numeric label column

local ++test_count
capture noisily {
    local c3b_cf "`tmp'/codescan_qa_c3b_cf.dta"
    preserve
    clear
    set obs 1
    gen str10 name = "dm2"
    gen str10 pattern = "E11"
    gen int label = 42
    quietly save "`c3b_cf'", replace
    restore

    _mk_c1_data
    capture codescan dx1, codefile("`c3b_cf'") replace
    assert _rc == 198
}
if _rc {
    local ++fail_count
    display as error "FAIL: C3b numeric label column silently ignored"
}
else {
    local ++pass_count
    display as text "PASS: C3b numeric label column rejected with r(198)"
}
capture erase "`tmp'/codescan_qa_c3b_cf.dta"

**## C3c: valid string optional columns still work

local ++test_count
capture noisily {
    local c3c_cf "`tmp'/codescan_qa_c3c_cf.dta"
    preserve
    clear
    set obs 1
    gen str10 name = "dm2"
    gen str10 pattern = "1"
    gen str10 exclusion = "116"
    quietly save "`c3c_cf'", replace
    restore

    clear
    set obs 2
    gen str5 dx1 = "116" in 1
    quietly replace dx1 = "117" in 2

    codescan dx1, codefile("`c3c_cf'")
    * "116" matches the pattern but is excluded; "117" matches and survives.
    assert dm2[1] == 0
    assert dm2[2] == 1
}
if _rc {
    local ++fail_count
    display as error "FAIL: C3c valid string exclusion column broken"
}
else {
    local ++pass_count
    display as text "PASS: C3c valid string exclusion column honored"
}
capture erase "`tmp'/codescan_qa_c3c_cf.dta"

**# C4: extended numeric missings must never become matchable codes

**## C4a: .a must not match under tostring nodots nocase

local ++test_count
capture noisily {
    clear
    set obs 3
    gen double code = .a in 1
    quietly replace code = 10 in 2
    quietly replace code = 20 in 3

    codescan code, define(missing_a "A") tostring nodots nocase
    * .a stringifies to ".a" -> nodots -> "a" -> nocase -> matches "A".
    assert missing_a[1] == 0
    assert missing_a[2] == 0
    assert missing_a[3] == 0
}
if _rc {
    local ++fail_count
    display as error "FAIL: C4a extended numeric missing .a matched a real pattern"
}
else {
    local ++pass_count
    display as text "PASS: C4a extended numeric missing .a is not matchable"
}

**## C4b: codescan_describe must not count numeric missings as codes

local ++test_count
capture noisily {
    clear
    set obs 3
    gen double code = .a in 1
    quietly replace code = 10 in 2
    quietly replace code = 20 in 3

    codescan_describe code, tostring
    assert r(n_entries) == 2
    assert r(n_unique) == 2
}
if _rc {
    local ++fail_count
    display as error "FAIL: C4b codescan_describe counts numeric missings as codes"
}
else {
    local ++pass_count
    display as text "PASS: C4b codescan_describe excludes numeric missings"
}

**## C4c: the full .a-.z range and plain . are all unmatchable

local ++test_count
capture noisily {
    clear
    set obs 4
    gen double code = .a in 1
    quietly replace code = .m in 2
    quietly replace code = .z in 3
    quietly replace code = . in 4

    codescan code, define(anyletter "[A-Za-z]") tostring nodots nocase
    quietly count if anyletter == 1
    assert r(N) == 0

    codescan_describe code, tostring
    assert r(n_entries) == 0
    assert r(n_unique) == 0
}
if _rc {
    local ++fail_count
    display as error "FAIL: C4c some extended numeric missing remained matchable"
}
else {
    local ++pass_count
    display as text "PASS: C4c all numeric missings unmatchable and uncounted"
}

**## C4d: nonmissing numerics still scan correctly under tostring

local ++test_count
capture noisily {
    clear
    set obs 3
    gen double code = .a in 1
    quietly replace code = 116 in 2
    quietly replace code = 200 in 3

    codescan code, define(c116 "116") tostring
    assert c116[1] == 0
    assert c116[2] == 1
    assert c116[3] == 0
    * The original numeric variable must be untouched.
    assert code[1] == .a & code[2] == 116 & code[3] == 200
}
if _rc {
    local ++fail_count
    display as error "FAIL: C4d nonmissing numeric scanning regressed"
}
else {
    local ++pass_count
    display as text "PASS: C4d nonmissing numerics scan correctly under tostring"
}

**# C5: file outputs must not overwrite without explicit authorization

**## C5a: codescan, export() refuses an existing file

local ++test_count
capture noisily {
    local c5a "`tmp'/codescan_qa_c5a.csv"
    _mk_sentinel_csv "`c5a'"

    _mk_c1_data
    capture codescan dx1, define(dm2 "E11") replace export("`c5a'")
    assert _rc == 602
    _assert_sentinel_alive "`c5a'"
}
if _rc {
    local ++fail_count
    display as error "FAIL: C5a export() overwrote an existing file without authorization"
}
else {
    local ++pass_count
    display as text "PASS: C5a export() refuses an existing file with r(602)"
}
capture erase "`tmp'/codescan_qa_c5a.csv"

**## C5b: codescan, export(, replace) succeeds

local ++test_count
capture noisily {
    local c5b "`tmp'/codescan_qa_c5b.csv"
    _mk_sentinel_csv "`c5b'"

    _mk_c1_data
    codescan dx1, define(dm2 "E11") replace export("`c5b'", replace)

    preserve
    quietly import delimited using "`c5b'", clear varnames(1)
    capture confirm variable sentinel
    assert _rc != 0
    restore
}
if _rc {
    local ++fail_count
    display as error "FAIL: C5b export(, replace) did not overwrite"
}
else {
    local ++pass_count
    display as text "PASS: C5b export(, replace) overwrites as authorized"
}
capture erase "`tmp'/codescan_qa_c5b.csv"

**## C5c: codescan, save() refuses an existing file

local ++test_count
capture noisily {
    local c5c "`tmp'/codescan_qa_c5c.csv"
    _mk_sentinel_csv "`c5c'"

    _mk_c1_data
    capture codescan dx1, define(dm2 "E11") replace save("`c5c'")
    assert _rc == 602
    _assert_sentinel_alive "`c5c'"
}
if _rc {
    local ++fail_count
    display as error "FAIL: C5c save() overwrote an existing file without authorization"
}
else {
    local ++pass_count
    display as text "PASS: C5c save() refuses an existing file with r(602)"
}
capture erase "`tmp'/codescan_qa_c5c.csv"

**## C5d: codescan, save(, replace) succeeds

local ++test_count
capture noisily {
    local c5d "`tmp'/codescan_qa_c5d.csv"
    _mk_sentinel_csv "`c5d'"

    _mk_c1_data
    codescan dx1, define(dm2 "E11") replace save("`c5d'", replace)

    preserve
    quietly import delimited using "`c5d'", clear varnames(1)
    confirm variable name
    confirm variable pattern
    restore
}
if _rc {
    local ++fail_count
    display as error "FAIL: C5d save(, replace) did not overwrite"
}
else {
    local ++pass_count
    display as text "PASS: C5d save(, replace) overwrites as authorized"
}
capture erase "`tmp'/codescan_qa_c5d.csv"

**## C5e: codescan_describe, save() refuses an existing file

local ++test_count
capture noisily {
    local c5e "`tmp'/codescan_qa_c5e.csv"
    _mk_sentinel_csv "`c5e'"

    _mk_c1_data
    capture codescan_describe dx1, save("`c5e'")
    assert _rc == 602
    _assert_sentinel_alive "`c5e'"
}
if _rc {
    local ++fail_count
    display as error "FAIL: C5e codescan_describe save() overwrote without authorization"
}
else {
    local ++pass_count
    display as text "PASS: C5e codescan_describe save() refuses an existing file"
}
capture erase "`tmp'/codescan_qa_c5e.csv"

**## C5f: a refused overwrite leaves the caller data untouched

local ++test_count
capture noisily {
    local c5f "`tmp'/codescan_qa_c5f.csv"
    _mk_sentinel_csv "`c5f'"

    _mk_c1_data
    local c5f_snap "`tmp'/codescan_qa_c5f_snap.dta"
    quietly save "`c5f_snap'", replace
    _snap_data
    local c5f_sig "`r(sig)'"
    local c5f_vars "`r(vars)'"

    capture codescan dx1, define(dm2 "E11") replace export("`c5f'")
    assert _rc == 602
    _assert_intact "`c5f_snap'" "`c5f_sig'" "`c5f_vars'"
}
if _rc {
    local ++fail_count
    display as error "FAIL: C5f refused overwrite still mutated the caller data"
}
else {
    local ++pass_count
    display as text "PASS: C5f refused overwrite leaves caller data untouched"
}
capture erase "`tmp'/codescan_qa_c5f.csv"
capture erase "`tmp'/codescan_qa_c5f_snap.dta"

**# I2: multi-window sensitivity must expose its per-window denominators

* The audit's two-ID probe: widening the window changes the DENOMINATOR as well
* as the numerator, so 100% at 30d vs 50% at 200d reflects population entry, not
* ascertainment sensitivity. The percentages alone cannot show that; the
* denominators must be returned.
local ++test_count
capture noisily {
    * pid 1 has a MATCHING row 10 days before refdate -> inside both windows.
    * pid 2 has a NON-matching row 150 days before refdate -> inside the 200d
    * window only. So widening 30d -> 200d adds one ID to the denominator and
    * none to the numerator: prevalence falls 100% -> 50% purely from population
    * entry, with no change whatsoever in ascertainment.
    clear
    input long pid str10 dx1 int offset
    1 "E110"  10
    2 "Z00"  150
    end
    gen refd = mdy(1,1,2020)
    gen edate = refd - offset
    format refd edate %td

    codescan dx1, define(dm2 "E11") id(pid) date(edate) refdate(refd) ///
        lookback("30 200") collapse preserve

    matrix S = r(sensitivity)
    matrix N = r(sensitivity_n)
    assert rowsof(N) == 1
    assert colsof(N) == 2
    * The denominators the percentages are computed over.
    assert N[1,1] == 1
    assert N[1,2] == 2
    * The audit's reported percentages: the drop is entirely denominator-driven.
    assert reldif(S[1,1], 100) < 1e-6
    assert reldif(S[1,2],  50) < 1e-6
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I2 r(sensitivity_n) exposes per-window denominators"
}
else {
    local ++fail_count
    display as error "FAIL: I2 per-window denominators missing or wrong"
}

**# I4: unmatched() distinguishes not-analyzed from matched

local ++test_count
capture noisily {
    clear
    input byte keepme str10 dx1
    1 "E110"
    0 "E110"
    1 "Z00"
    0 "Z00"
    end
    codescan dx1 if keepme, define(dm2 "E11") unmatched(nohit)
    * analyzed + matched -> 0
    assert nohit[1] == 0
    * analyzed + no match -> 1
    assert nohit[3] == 1
    * NOT analyzed -> missing, not 0
    assert missing(nohit[2])
    assert missing(nohit[4])
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I4 unmatched() marks non-analyzed rows missing"
}
else {
    local ++fail_count
    display as error "FAIL: I4 unmatched() conflates non-analyzed with matched"
}

**# I1: label() must reach the console, the graph, and the export

* The audit's probe: the VARIABLE label was correct while the console and the
* export kept showing the raw name. Asserting the variable label alone is
* therefore a false green for this defect — it was already passing on 2.0.9.
**## I1a: the console Condition column shows the label, not the name
local ++test_count
capture noisily {
    _mk_slots_data
    tempfile i1raw
    quietly save `i1raw'

    quietly log using "`tmp'/i1_console.log", replace text name(i1c)
    codescan dx1 dx2, define(dm2 "E11") label(dm2 "Type 2 diabetes")
    quietly log close i1c

    _assert_file_has, file("`tmp'/i1_console.log") text("Type 2 diabetes") ///
        reload("`i1raw'")
    * The table row must not fall back to the raw name. "dm2" still appears in
    * the log via the echoed command line and the header, so anchor on the
    * two-space indent the table row uses.
    _assert_file_lacks, file("`tmp'/i1_console.log") text("  dm2  ") ///
        reload("`i1raw'")
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I1a console Condition column uses label()"
}
else {
    local ++fail_count
    display as error "FAIL: I1a console shows the raw name despite label()"
}

**## I1b: r() and matrix row names keep the stable machine name
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") ///
        label(dm2 "Type 2 diabetes" \ htn "Hypertension")

    * Labels are presentation. Anything a do-file keys on stays the name, so
    * relabeling a condition can never break downstream code.
    assert "`r(conditions)'" == "dm2 htn"
    matrix S = r(summary)
    local rn : rowfullnames S
    assert "`rn'" == "dm2 htn"
    matrix C = r(codelist)
    local cn : rowfullnames C
    assert "`cn'" == "dm2 htn"
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I1b machine names survive labelling in r()/matrices"
}
else {
    local ++fail_count
    display as error "FAIL: I1b labels leaked into the machine identifiers"
}

**## I1c: the export carries condition AND label as separate fields
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11" | htn "I10") ///
        label(dm2 "Type 2 diabetes") ///
        export("`tmp'/i1_export.csv", replace)

    quietly import delimited using "`tmp'/i1_export.csv", clear varnames(1) ///
        stringcols(_all)
    quietly count if condition == "dm2" & label == "Type 2 diabetes"
    assert r(N) == 1
    * Unlabelled conditions fall back to the name rather than exporting blank,
    * so a consumer can always use label as a display column.
    quietly count if condition == "htn" & label == "htn"
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I1c export has condition + label with name fallback"
}
else {
    local ++fail_count
    display as error "FAIL: I1c export label field missing or wrong"
}

**## I1d: the graph's bar text is the label
local ++test_count
capture noisily {
    _mk_slots_data
    tempfile i1graw
    quietly save `i1graw'

    codescan dx1 dx2, define(dm2 "E11") label(dm2 "Type 2 diabetes") ///
        graph
    * SVG is text, so the rendered bar label is directly assertable — the only
    * check here that actually sees what the user sees.
    quietly graph export "`tmp'/i1_graph.svg", replace
    _assert_file_has, file("`tmp'/i1_graph.svg") text("Type 2 diabetes") ///
        reload("`i1graw'")
    graph drop _all
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I1d graph bar labels use label()"
}
else {
    local ++fail_count
    display as error "FAIL: I1d graph shows raw names despite label()"
}

**## I1e: label() overrides a codefile label, and hostile label text survives
local ++test_count
capture noisily {
    * A codefile supplies a label; label() must win.
    quietly {
        clear
        set obs 1
        gen str8 name = "dm2"
        gen str8 pattern = "E11"
        gen str40 label = "From codefile"
        export delimited using "`tmp'/i1_codes.csv", replace
    }
    _mk_slots_data
    codescan dx1 dx2, codefile("`tmp'/i1_codes.csv") ///
        label(dm2 "From option") export("`tmp'/i1_prec.csv", replace)

    quietly import delimited using "`tmp'/i1_prec.csv", clear varnames(1) ///
        stringcols(_all)
    assert label[1] == "From option"

    * A backslash (Windows path) must survive even though \ is also the entry
    * separator, and a unicode label must survive the console's truncation
    * arithmetic. Both reach the export whole -- the export is not width-limited.
    _mk_slots_data
    codescan dx1 dx2, define(a "E11" | b "I10") ///
        label(a "C:\data\dm2" \ b "Diabetes typ 2 — förhöjt blodsocker hos vuxna patienter") ///
        export("`tmp'/i1_hostile.csv", replace)

    * encoding("utf-8") is required, not decorative: this suite runs under
    * version 16.0, where import delimited defaults to latin1. Without it the
    * unicode label reads back as "Diabetes typ 2 â fÃ¶rhÃ¶jt ..." (66 bytes,
    * not 59) and the assertion fails on a correct export -- the reader then
    * goes hunting for an encoding bug in codescan that is not there.
    quietly import delimited using "`tmp'/i1_hostile.csv", clear varnames(1) ///
        stringcols(_all) encoding("utf-8")
    assert label[1] == "C:\data\dm2"
    assert label[2] == "Diabetes typ 2 — förhöjt blodsocker hos vuxna patienter"
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I1e label precedence and hostile label text"
}
else {
    local ++fail_count
    display as error "FAIL: I1e label precedence or escaping is broken"
}

**## I1f: a long label truncates the console column instead of misaligning it
local ++test_count
capture noisily {
    _mk_slots_data
    tempfile i1lraw
    quietly save `i1lraw'

    quietly log using "`tmp'/i1_long.log", replace text name(i1l)
    codescan dx1 dx2, define(dm2 "E11") ///
        label(dm2 "Diabetes mellitus type 2 with complications")
    quietly log close i1l

    * Truncated at 20 characters plus a "~" marker, so the numeric columns stay
    * where the header says they are.
    _assert_file_has, file("`tmp'/i1_long.log") text("Diabetes mellitus ty~") ///
        reload("`i1lraw'")
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I1f long console labels truncate with a marker"
}
else {
    local ++fail_count
    display as error "FAIL: I1f long label misaligns or is silently cut"
}

**## I1g: a label() entry written with define()'s separator is rejected
local ++test_count
capture noisily {
    * Found while writing I1b, which made this mistake. label() splits entries
    * on \ ; define() splits on |. Using | yields ONE entry whose text is
    *     Type 2 diabetes" | htn "Hypertension
    * -- an odd number of quotes. Before v3.0.0 that was accepted silently: dm2
    * got the nonsense text as its variable label and htn got none, at rc=0.
    * Now that labels are also the console/graph/export text, the same input
    * additionally aborted the results table with a bare r(132) naming neither
    * label() nor the condition.
    _mk_slots_data
    capture codescan dx1 dx2, define(dm2 "E11" | htn "I10") ///
        label(dm2 "Type 2 diabetes" | htn "Hypertension")
    assert _rc == 198

    * A compound-quoted label is also rejected, but by Stata's own option
    * parser (r(132)) before codescan's validation runs -- so this asserts
    * "rejected with nothing created", not a specific code. Embedded quotes are
    * unsupported either way: the entry parser strips plain quotes only, so
    * `"He said "yes""' would otherwise reach the variable label, the bar label,
    * and the export cell with its compound markers intact.
    _mk_slots_data
    capture codescan dx1 dx2, define(dm2 "E11") label(dm2 `"He said "yes""')
    assert _rc != 0
    capture confirm variable dm2
    assert _rc != 0

    * The rule must not be broader than that: an ordinary label still works.
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") label(dm2 "Plain text label") ///
        export("`tmp'/i1_bal.csv", replace)
    quietly import delimited using "`tmp'/i1_bal.csv", clear varnames(1) ///
        stringcols(_all)
    assert label[1] == "Plain text label"
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I1g wrong label() separator errors instead of mislabelling"
}
else {
    local ++fail_count
    display as error "FAIL: I1g malformed label() entry silently accepted"
}

**# I3: countmode must separate total hits from positive units

* Under countmode the audit found column 1 / the export's "matches" holding the
* SLOT-hit total while prevalence was built from positive units. Both numbers
* are legitimate; the defect is that only one was reported, under a name that
* reads like the other.
**## I3a: the two quantities are returned separately and genuinely differ
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countmode preserve

    matrix S = r(summary)
    local cn : colfullnames S
    assert "`cn'" == "count prevalence ci_low ci_high total_hits positive_units"
    * 3 slot hits (E110, E119 on pid 1; E118 on pid 2) across 2 patients.
    assert S[1,5] == 3
    assert S[1,6] == 2
    * The legacy column keeps its legacy meaning: the hit total under countmode.
    assert S[1,1] == S[1,5]
    * Prevalence is built from positive_units, not from the hit total. If it
    * used hits it would read 150%.
    assert reldif(S[1,2], 100) < 1e-6

    matrix C = r(codelist)
    local ccn : colfullnames C
    assert "`ccn'" == "count prevalence total_hits positive_units"
    assert C[1,3] == 3
    assert C[1,4] == 2
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I3a countmode returns total_hits and positive_units"
}
else {
    local ++fail_count
    display as error "FAIL: I3a countmode conflates hits with positive units"
}

**## I3b: binary mode reports no hit total rather than a fake one
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse preserve

    matrix S = r(summary)
    * Binary mode never counts repeat hits, so there is no hit total to report.
    * Missing says that; copying positive_units here would assert one hit per
    * unit, which is false for pid 1 (two hits).
    assert missing(S[1,5])
    assert S[1,6] == 2
    * Legacy column 1 is the matched-unit count without countmode.
    assert S[1,1] == S[1,6]
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I3b binary mode leaves total_hits missing"
}
else {
    local ++fail_count
    display as error "FAIL: I3b binary mode fabricates a hit total"
}

**## I3c: the export names both quantities
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countmode ///
        export("`tmp'/i3_export.csv", replace)

    quietly import delimited using "`tmp'/i3_export.csv", clear varnames(1)
    assert total_hits[1] == 3
    assert positive_units[1] == 2
    * matches is retained for compatibility and keeps its old value.
    assert matches[1] == 3
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I3c export carries total_hits and positive_units"
}
else {
    local ++fail_count
    display as error "FAIL: I3c export omits the separated count quantities"
}

**## I3d: the console names both quantities
local ++test_count
capture noisily {
    _mk_slots_data
    tempfile i3raw
    quietly save `i3raw'

    quietly log using "`tmp'/i3_console.log", replace text name(i3c)
    codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countmode preserve
    quietly log close i3c

    _assert_file_has, file("`tmp'/i3_console.log") text("Hits") reload("`i3raw'")
    _assert_file_has, file("`tmp'/i3_console.log") text("Units>0") reload("`i3raw'")
    _assert_file_has, file("`tmp'/i3_console.log") ///
        text("Hits = total matching code slots") reload("`i3raw'")
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I3d console headings name hits vs units"
}
else {
    local ++fail_count
    display as error "FAIL: I3d console headings still ambiguous"
}

**# I5: detail attribution is order-dependent by default, order-free on request

**## I5a: reversing varlist moves detail without moving the cohort
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") detail
    matrix V1 = r(varcounts)
    local n1 = r(N)
    matrix S1 = r(summary)
    assert r(detail_allslots) == 0

    _mk_slots_data
    codescan dx2 dx1, define(dm2 "E11") detail
    matrix V2 = r(varcounts)
    matrix S2 = r(summary)

    * The audit's claim, made concrete. Row 1 carries E11 in both slots, so it
    * is attributed to whichever variable comes first.
    assert V1[1,1] == 1     // dx1 first: row 1 -> dx1, row 3 -> dx2
    assert V1[1,2] == 1
    assert V2[1,1] == 2     // dx2 first: rows 1 and 3 both -> dx2
    assert V2[1,2] == 0

    * ... while the cohort is untouched. This is the whole point: the detail
    * table moved, the result did not.
    assert S1[1,1] == S2[1,1]
    assert reldif(S1[1,2], S2[1,2]) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I5a first-slot attribution reproduced, cohort stable"
}
else {
    local ++fail_count
    display as error "FAIL: I5a detail attribution not as documented"
}

**## I5b: allslots is order-invariant and still leaves the cohort alone
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") detail allslots
    matrix A1 = r(varcounts)
    matrix SA1 = r(summary)
    assert r(detail_allslots) == 1

    _mk_slots_data
    codescan dx2 dx1, define(dm2 "E11") detail allslots
    matrix A2 = r(varcounts)

    * Every matching slot counted, so row 1 contributes to BOTH variables.
    assert A1[1,1] == 1     // dx1
    assert A1[1,2] == 2     // dx2 (row 1 and row 3)
    * Reversed varlist: the same per-variable numbers, in the reversed column
    * order. This is what the default cannot do.
    assert A2[1,1] == 2     // dx2
    assert A2[1,2] == 1     // dx1

    * The row total now equals the slot-hit total countmode reports...
    assert A1[1,1] + A1[1,2] == 3
    * ... but the indicator is still binary and the cohort is unchanged.
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") detail
    matrix SD = r(summary)
    assert SA1[1,1] == SD[1,1]
    assert reldif(SA1[1,2], SD[1,2]) < 1e-12
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I5b allslots is order-invariant, cohort unchanged"
}
else {
    local ++fail_count
    display as error "FAIL: I5b allslots changed the cohort or stayed order-dependent"
}

**## I5c: allslots leaves the indicator binary, unlike countmode
local ++test_count
capture noisily {
    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") detail allslots
    * Row 1 has two hits. Under allslots the DETAIL sees both, but the variable
    * is still 0/1 — this is the line between allslots and countmode.
    assert dm2[1] == 1
    quietly count if dm2 > 1 & !missing(dm2)
    assert r(N) == 0

    _mk_slots_data
    codescan dx1 dx2, define(dm2 "E11") countmode detail
    assert dm2[1] == 2
    * countmode already counts every slot, so its detail is order-free without
    * allslots.
    matrix VC = r(varcounts)
    assert VC[1,1] == 1
    assert VC[1,2] == 2
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I5c allslots keeps binary indicators; countmode counts"
}
else {
    local ++fail_count
    display as error "FAIL: I5c allslots leaked count semantics into the indicator"
}

**## I5d: allslots without detail is an error, not a silent no-op
local ++test_count
capture noisily {
    _mk_slots_data
    capture codescan dx1 dx2, define(dm2 "E11") allslots
    assert _rc == 198
    * A silently ignored option is worse than a rejected one: the user believes
    * they changed the attribution rule and reads the table as if they had.
}
if _rc == 0 {
    local ++pass_count
    display as text "PASS: I5d allslots requires detail (rc=198)"
}
else {
    local ++fail_count
    display as error "FAIL: I5d allslots silently ignored without detail"
}


**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
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

capture program drop _assert_file_has
capture program drop _assert_file_lacks
capture program drop _mk_slots_data
capture program drop _mk_c1_data
capture program drop _snap_data
capture program drop _assert_intact
capture program drop _mk_sentinel_csv
capture program drop _assert_sentinel_alive

display as text _newline "codescan v3.0.0 critical-defect regressions"
display as text "  tests:  `test_count'"
display as text "  passed: `pass_count'"
display as text "  failed: `fail_count'"

display as text "RESULT: test_codescan_v300_critical tests=`test_count' pass=`pass_count' fail=`fail_count'"

capture log close

if `fail_count' > 0 exit 1

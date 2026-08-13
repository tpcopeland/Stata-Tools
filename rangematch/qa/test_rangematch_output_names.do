*! test_rangematch_output_names.do
*! v1.5.3: output-name construction contract for carried using variables.
*!
*! The subject is _rangematch_build_output_names' decision about WHICH name a
*! carried using variable lands under, and when prefix()/suffix() are allowed to
*! fail the command.
*!
*! REGRESSION (1.5.3). The `confirm name' gate on `prefix'`v'`suffix' ran
*! unconditionally, before the code decided whether the decorated name was even
*! going to be used. Under the default rules a carried variable is renamed only
*! when its name collides with a master variable; a non-colliding variable keeps
*! its own name and the decorated form is discarded. So any using variable whose
*! name ran to 31 or 32 characters aborted the entire join with rc=198 --
*! "prefix()/suffix() constructs invalid output name" -- naming a variable the
*! command had no intention of creating, while the real column would have been
*! carried under its own perfectly legal name. There was no way around it
*! either: prefix("") and suffix("") both parse as NOT SUPPLIED, so rangematch
*! reapplies the "_U" default, and the user's only recourse was to rename the
*! source column. 31 and 32 characters are ordinary registry variable names.
*!
*! The gate now fires only for names that are actually applied, so the tests
*! below pin BOTH directions: a non-colliding long name must join, and a
*! genuinely-needed decorated name that overflows Stata's 32-character cap must
*! still be rejected. T6/T7 pin the other direction of the fix -- moving the
*! gate must not let a malformed prefix()/suffix() become a silent no-op
*! whenever nothing happens to collide.
*!
*! T9 is the rc=0-but-wrong guard: a carried long-named column that EXISTS but
*! holds the wrong values would satisfy every name-shaped assertion above.

version 16.1
clear all
set more off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap

local FAIL 0
local TESTS 0

* 31 and 32 characters: decorating either with the default "_U" suffix
* overflows Stata's 32-character variable-name cap.
local N31 "abcdefghijabcdefghijabcdefghijk"
local N32 "abcdefghijabcdefghijabcdefghijkl"
* 30 characters: "_U" still fits, so this is the control.
local N30 "abcdefghijabcdefghijabcdefghij"

tempfile U31 U32 U30

clear
quietly set obs 5
gen long urow = _n
gen double ukey = _n
gen double `N31' = _n * 100
quietly save "`U31'", replace

clear
quietly set obs 5
gen long urow = _n
gen double ukey = _n
gen double `N32' = _n * 100
quietly save "`U32'", replace

clear
quietly set obs 5
gen long urow = _n
gen double ukey = _n
gen double `N30' = _n * 100
quietly save "`U30'", replace

capture program drop _rm_mkmaster
program define _rm_mkmaster
    version 16.1
    args extravar
    clear
    quietly set obs 3
    gen long mrow = _n
    gen double lo = _n
    gen double hi = _n + 2
    if "`extravar'" != "" quietly gen double `extravar' = -1
end

* --- T1: a 31-character using variable with no master collision joins --------
_rm_mkmaster
capture noisily rangematch ukey lo hi using "`U31'", unmatched(none)
local rc = _rc
local ++TESTS
if `rc' {
    di as error "T1 31-char non-colliding using variable failed rc=`rc'"
    local ++FAIL
}
else {
    capture confirm variable `N31'
    if _rc {
        di as error "T1 31-char variable was not carried under its own name"
        local ++FAIL
    }
}

* --- T2: 32 characters, the cap itself ---------------------------------------
_rm_mkmaster
capture noisily rangematch ukey lo hi using "`U32'", unmatched(none)
local rc = _rc
local ++TESTS
if `rc' {
    di as error "T2 32-char non-colliding using variable failed rc=`rc'"
    local ++FAIL
}
else {
    capture confirm variable `N32'
    if _rc {
        di as error "T2 32-char variable was not carried under its own name"
        local ++FAIL
    }
}

* --- T3: the same name requested explicitly through keepusing() --------------
_rm_mkmaster
capture noisily rangematch ukey lo hi using "`U31'", keepusing(`N31') unmatched(none)
local rc = _rc
local ++TESTS
if `rc' {
    di as error "T3 keepusing() of a 31-char variable failed rc=`rc'"
    local ++FAIL
}

* --- T4: a genuine collision that overflows the cap must still be rejected ---
* Here the decorated name IS the one the command needs, so failing is correct:
* both columns cannot coexist and the rename that would separate them is not
* expressible within 32 characters.
_rm_mkmaster `N31'
capture noisily rangematch ukey lo hi using "`U31'", unmatched(none)
local rc = _rc
local ++TESTS
if `rc' != 198 {
    di as error "T4 colliding 31-char name gave rc=`rc' (want 198)"
    local ++FAIL
}

* --- T5: all applies the suffix to every carried variable, so it must fail ---
_rm_mkmaster
capture noisily rangematch ukey lo hi using "`U31'", all unmatched(none)
local rc = _rc
local ++TESTS
if `rc' != 198 {
    di as error "T5 all with a 31-char name gave rc=`rc' (want 198)"
    local ++FAIL
}

* --- T6: a malformed prefix() must not become a silent no-op -----------------
* Nothing collides here, so the decorated name is never applied; the prefix is
* still illegal and saying nothing would accept a typo that changes no output.
_rm_mkmaster
capture noisily rangematch ukey lo hi using "`U30'", prefix(2x) unmatched(none)
local rc = _rc
local ++TESTS
if `rc' != 198 {
    di as error "T6 malformed prefix(2x) gave rc=`rc' (want 198)"
    local ++FAIL
}

* --- T7: likewise a malformed suffix() ---------------------------------------
_rm_mkmaster
capture noisily rangematch ukey lo hi using "`U30'", suffix(-z) unmatched(none)
local rc = _rc
local ++TESTS
if `rc' != 198 {
    di as error "T7 malformed suffix(-z) gave rc=`rc' (want 198)"
    local ++FAIL
}

* --- T8: a legal collision still renames, and both columns survive -----------
_rm_mkmaster `N30'
capture noisily rangematch ukey lo hi using "`U30'", unmatched(none)
local rc = _rc
local ++TESTS
if `rc' {
    di as error "T8 legal 30-char collision failed rc=`rc'"
    local ++FAIL
}
else {
    capture confirm variable `N30'
    local m_rc = _rc
    capture confirm variable `N30'_U
    local u_rc = _rc
    if `m_rc' | `u_rc' {
        di as error "T8 collision did not yield both `N30' (rc=`m_rc') and `N30'_U (rc=`u_rc')"
        local ++FAIL
    }
}

* --- T9: the carried long-named column holds the RIGHT values ----------------
* Name-shaped assertions cannot tell a correctly carried column from one that
* exists and is wrong. usingid() gives the source row, so the carried value is
* checked against the rule that produced it (row * 100).
_rm_mkmaster
capture noisily rangematch ukey lo hi using "`U31'", unmatched(none) usingid(uid)
local rc = _rc
local ++TESTS
if `rc' {
    di as error "T9 setup failed rc=`rc'"
    local ++FAIL
}
else {
    quietly count
    local nrows = r(N)
    capture assert `N31' == uid * 100
    local val_rc = _rc
    if `nrows' == 0 | `val_rc' {
        di as error "T9 carried 31-char column wrong (rows=`nrows', assert rc=`val_rc')"
        local ++FAIL
    }
}

* --- T10/T11: an affix containing whitespace must be refused ----------------
* REGRESSION (1.5.3), and the silent one. prefix()/suffix() are declared
* string, so either may carry a space; the decorated name is then appended to a
* SPACE-DELIMITED macro list, which re-splits it into two words while
* carry_vars keeps one word per variable. _rm_materialize pairs the two lists
* positionally, so every carried variable after the first decorated name landed
* under the NEXT name in the list. With using variables dup1, zz, ukey and a
* master colliding on dup1, prefix("p q") returned rc=0 and an output holding a
* column named qdup1 that contained zz's values and a column named zz that
* contained the match key. Nothing warned, and the values were internally
* consistent -- only the names were wrong, which is the hardest kind to notice.
*
* The uniqueness screen was not a backstop: it fired only when a stray token
* happened to collide with another name, so TWO colliding variables errored
* rc=110 while ONE returned wrong output rc=0.
*
* T11 pins the mis-mapping directly rather than only the return code: it is the
* assertion that would have caught the defect had the command not been fixed to
* refuse the input outright.
tempfile USHIFT
clear
quietly set obs 5
gen double dup1 = _n * 10
gen double zz   = _n * 1000
gen double ukey = _n
quietly save "`USHIFT'", replace

_rm_mkmaster dup1
capture noisily rangematch ukey lo hi using "`USHIFT'", prefix("p q") unmatched(none)
local rc = _rc
local ++TESTS
if `rc' != 198 {
    di as error "T10 prefix() containing a space gave rc=`rc' (want 198)"
    local ++FAIL
}

_rm_mkmaster dup1
capture noisily rangematch ukey lo hi using "`USHIFT'", suffix("a b") unmatched(none)
local rc = _rc
local ++TESTS
if `rc' != 198 {
    di as error "T11 suffix() containing a space gave rc=`rc' (want 198)"
    local ++FAIL
}

* --- T12: on the same data, a legal affix maps every column correctly --------
* This is the positive half of T10/T11 and the assertion that names the damage.
* The fixture is built so a shift by one is visible in the DATA, not just the
* variable list: dup1 is 10*row, zz is 1000*row, and ukey is the row itself, so
* a column carrying its neighbour's values fails the arithmetic outright. Under
* the defect this same layout put zz's values in a column named qdup1 and the
* match key in a column named zz.
_rm_mkmaster dup1
capture noisily rangematch ukey lo hi using "`USHIFT'", prefix(p_) unmatched(none) usingid(uid)
local rc = _rc
local ++TESTS
if `rc' {
    di as error "T12 legal prefix(p_) failed rc=`rc'"
    local ++FAIL
}
else {
    capture confirm variable p_dup1
    local n_rc = _rc
    capture confirm variable zz
    local z_rc = _rc
    if `n_rc' | `z_rc' {
        di as error "T12 expected p_dup1 (rc=`n_rc') and zz (rc=`z_rc')"
        local ++FAIL
    }
    else {
        quietly count
        local nrows = r(N)
        capture assert p_dup1 == uid * 10 & zz == uid * 1000 & ukey == uid
        local map_rc = _rc
        if `nrows' == 0 | `map_rc' {
            di as error "T12 carried columns are mis-mapped (rows=`nrows', assert rc=`map_rc')"
            local ++FAIL
        }
    }
}

display "RESULT: test_rangematch_output_names tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_output_names: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_output_names: PASSED"

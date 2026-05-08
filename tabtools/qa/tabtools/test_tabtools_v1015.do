* test_tabtools_v1015.do — regression tests for tabtools v1.0.15 fixes
* Tests D, E, F, G from the 2026-05-07 reviewer punch list:
*   D. by-variable name restriction surfaces a clear, documented error
*   E. Mata workspace leak on Excel formatting failure is plugged
*   F. Sthlp source contains the new "Reserved by() variable names" section
*      with all reserved prefixes/names documented
*   G. `help table1_tc` renders that section: anchor + title + body land in
*      the SMCL viewer output captured to a log
*
* Run from the package qa/tabtools/ directory.

clear all
set more off

* Resolve package directory from cwd. Supports two callers:
*   (a) standalone:  cwd = .../tabtools/qa/tabtools
*   (b) run_all.do:  cwd = .../tabtools/qa
local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/tabtools$") {
    local pkg_root = regexr("`_cwd'", "/qa/tabtools$", "")
    local qa_dir = regexr("`_cwd'", "/tabtools$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_root = regexr("`_cwd'", "/qa$", "")
    local qa_dir "`_cwd'"
}
else {
    local pkg_root "`_cwd'"
    local qa_dir "`pkg_root'/qa"
}
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_root'") replace
discard

local pass = 0
local fail = 0
local total = 0

**# Helper: assert ALL needles appear in a captured log/sthlp file
* Reads `path' line by line; asserts that every newline-separated entry in
* `needles_local' (passed by name) appears in at least one line.
capture program drop _v1015_assert_all_in_file
program define _v1015_assert_all_in_file
    args path needles_local
    capture confirm file `"`path'"'
    if _rc {
        display as error "  file not found: `path'"
        exit 601
    }
    * Slurp file content into one local for substring checks. SMCL is
    * line-oriented; a single pass collecting all lines is sufficient.
    tempname _vfh
    local _content ""
    file open `_vfh' using `"`path'"', read text
    file read `_vfh' line
    while r(eof) == 0 {
        local _content `"`_content' `line'"'
        file read `_vfh' line
    }
    file close `_vfh'

    local _missing ""
    foreach _n of local `needles_local' {
        if strpos(`"`_content'"', `"`_n'"') == 0 {
            local _missing `"`_missing' [`_n']"'
        }
    }
    if `"`_missing'"' != "" {
        display as error "  missing in `path':`_missing'"
        exit 9
    }
end

display as text _newline "=== test_tabtools_v1015 ==="

**# Test D: by() variable name restriction
* The reshape pipeline reserves N_*, m_*, _column* columns. A by-variable named
* N_age (or any blacklisted name) must produce error 498 with a message that
* points at the help file.
local _d_log "`c(tmpdir)'/_t1tc_by_reserved.log"
capture erase "`_d_log'"
local ++total
capture noisily {
    sysuse auto, clear
    rename rep78 N_age   // alias one of the reserved prefixes

    log using `"`_d_log'"', replace text name(_v1015_D)
    capture noisily table1_tc mpg, by(N_age)
    local rc_D = _rc
    capture log close _v1015_D
    assert `rc_D' == 498
    local needles_D
    local needles_D `" "by() variable name N_age collides with internal reshape columns" "Reserved prefixes: N_, m_" "reserved names: N, m" "help table1_tc" "'
    _v1015_assert_all_in_file `"`_d_log'"' needles_D
}
local rc_D_outer = _rc
capture log close _v1015_D
if `rc_D_outer' == 0 & `rc_D' == 498 {
    display as result "  PASS: Test D (by(N_age) raised rc=498 with documented message)"
    local ++pass
}
else {
    display as error "  FAIL: Test D (outer rc=`rc_D_outer'; inner rc=`rc_D')"
    local ++fail
}

**# Test E: Mata workspace leak on Excel format failure
* Run table1_tc with an excel target that fails the Mata xl() block. Hardest
* path to trigger is the load_book step on a non-existent file — but
* export excel succeeds and creates the file, so we instead simulate by
* dropping the Mata vector mid-flight is impossible from outside.
* Practical approach: run table1_tc, then assert _p_raw_save and _smd_raw_save
* do NOT exist in Mata afterward (success path also drops them). Then run
* against an impossible output path to exercise the error branch.
local ++total
capture noisily {
    sysuse auto, clear

    * Pre-condition: clear any leftover state from a prior failed run.
    capture mata: mata drop _p_raw_save
    capture mata: mata drop _smd_raw_save

    tempfile xlsx_ok
    capture erase "`xlsx_ok'.xlsx"

    quietly table1_tc mpg headroom, by(foreign) xlsx("`xlsx_ok'.xlsx") smd

    * Both saved-state Mata vectors must be cleaned up after a successful run.
    * `mata describe NAME` errors with rc=3499 when NAME does not exist.
    capture mata: mata describe _p_raw_save
    local _have_p_after = _rc == 0
    capture mata: mata describe _smd_raw_save
    local _have_s_after = _rc == 0
    assert `_have_p_after' == 0
    assert `_have_s_after' == 0

    capture erase "`xlsx_ok'.xlsx"

    * Now exercise the error branch: an impossible output directory forces
    * export/formatting to fail after the raw Mata vectors have been saved.
    tempfile bad_xlsx
    local bad_xlsx "`bad_xlsx'_missing_dir/out.xlsx"

    capture noisily table1_tc mpg headroom, by(foreign) xlsx("`bad_xlsx'") smd
    local rc_bad = _rc
    assert `rc_bad' != 0

    * The cleanup must drop the saved state after the error branch.
    capture mata: mata describe _p_raw_save
    local _have_p_after2 = _rc == 0
    capture mata: mata describe _smd_raw_save
    local _have_s_after2 = _rc == 0
    assert `_have_p_after2' == 0
    assert `_have_s_after2' == 0

    capture erase "`bad_xlsx'"
}
local rc_E = _rc
if `rc_E' == 0 {
    display as result "  PASS: Test E (Mata workspace clean after success and after format failure)"
    local ++pass
}
else {
    display as error "  FAIL: Test E (rc=`rc_E')"
    local ++fail
}

**# Test F: sthlp source contains the new "Reserved by() variable names" section
* Verify the markup we shipped: the {marker technical} anchor, the bold
* section header, every reserved-name token, and a rename example. This
* locks the source-of-truth so a future sthlp rewrite cannot silently drop
* the documentation that the table1_tc.ado error message points at.
local ++total
capture noisily {
    capture findfile table1_tc.sthlp
    if _rc {
        display as error "  table1_tc.sthlp not found on adopath"
        exit 601
    }
    local _sthlp_path "`r(fn)'"

    * Tokens that must all be present in the .sthlp source.
    local needles_F
    local needles_F : list needles_F | needles_F
    local needles_F `" "{marker technical}" "{bf:Reserved by() variable names:}" "{cmd:N_<level>}" "{cmd:m_<level>}" "{cmd:_columna_<level>}" "{cmd:_columnb_<level>}" "rejects such names with rc=498" "{cmd:rename N_age age_n}" "'

    _v1015_assert_all_in_file `"`_sthlp_path'"' needles_F
}
local rc_F = _rc
if `rc_F' == 0 {
    display as result "  PASS: Test F (sthlp source contains Reserved by() variable names section + all reserved tokens)"
    local ++pass
}
else {
    display as error "  FAIL: Test F (rc=`rc_F'; sthlp markup incomplete)"
    local ++fail
}

**# Test G: `help table1_tc` renders the new section to a log-captured viewer
* `help` in batch mode resolves the .sthlp through Stata's viewer pipeline
* and prints the rendered output to the log. Asserting on the rendered
* form (post-SMCL) catches markup that compiles but renders blank — the
* failure mode visual inspection would catch.
local _g_log "`c(tmpdir)'/_t1tc_help_render.log"
capture erase "`_g_log'"
local ++total
capture noisily {
    log using `"`_g_log'"', replace text name(_v1015_G_t1tc)
    capture noisily help table1_tc
    capture log close _v1015_G_t1tc

    * After SMCL rendering the bracket markers are stripped. Assert on
    * the surface text the user actually sees: the section title, a
    * representative reserved name, and the actionable rename guidance.
    local needles_G
    local needles_G `" "Reserved by() variable names" "N_<level>" "m_<level>" "rc=498" "rename N_age age_n" "Technical notes" "'

    _v1015_assert_all_in_file `"`_g_log'"' needles_G
}
local rc_G = _rc
capture log close _v1015_G_t1tc
if `rc_G' == 0 {
    display as result "  PASS: Test G (help table1_tc renders Reserved by() section in viewer)"
    local ++pass
}
else {
    display as error "  FAIL: Test G (rc=`rc_G'; see `_g_log')"
    local ++fail
}

**# Summary
display as text _newline "=== Summary ==="
display as text "Total : `total'"
display as result "Pass  : `pass'"
if `fail' > 0 display as error "Fail  : `fail'"
else display as text "Fail  : 0"

if `fail' > 0 exit `fail'

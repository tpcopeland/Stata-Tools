* test_msm_removed_stubs.do
* msm 2.0.0 removed seven commands. Each ships as a stub for all of 2.x that
* prints its replacement and exits 199, so that an upgrade cannot leave the
* 1.4.x command live against the 2.0 core: `net install msm, replace' does not
* delete files dropped from the package, only a same-named file displaces them.
*
*   RS1  each stub exits 199, names msm 2.0.0 and its replacement, and leaves
*        data, sort order, e(), r() and varabbrev untouched
*   RS2  upgrade without uninstall: a 1.4.x-style msm with a live msm_table
*        is installed, then this package with replace; every removed name
*        resolves to the 2.0 stub
*   RS3  upgrade with `ado uninstall msm' first (the documented route)
*   RS4  every stub has a help file that renders and names the replacement
*   RS5  each stub called by its literal name exits 199 and names its replacement

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_removed_stubs.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

local stubs "msm_protocol msm_validate msm_plot msm_report msm_table msm_diagtab msm_sensitivity"
* What each stub must point at (a substring of its message).
local want_msm_protocol   "no replacement"
local want_msm_validate   "msm_prepare"
local want_msm_plot       "psdash"
local want_msm_report     "regtab"
local want_msm_table      "effecttab"
local want_msm_diagtab    "frame post"
local want_msm_sensitivity "qba_confound, from_model coef(treatment) evalue measure(HR)"

capture program drop _rs_text_in_file
program define _rs_text_in_file, rclass
    syntax using/, TEXT(string)
    tempname fh
    local found 0
    file open `fh' using "`using'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`text'"') local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

**# RS1: stub contract
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    set seed 1
    gen double _u = runiform()
    sort _u
    gen long row = _n
    quietly regress outcome treatment
    local ecmd "`e(cmd)'"
    tempname eb
    matrix `eb' = e(b)
    foreach s of local stubs {
        tempfile slog
        set varabbrev on
        log using "`slog'", text replace name(stublog)
        quietly summarize age
        local rmean = r(mean)
        capture noisily `s', anything(1) xlsx("never.xlsx")
        local src = _rc
        local rmean_after = r(mean)
        log close stublog
        assert `src' == 199
        assert c(varabbrev) == "on"
        set varabbrev off
        assert row == _n
        assert "`e(cmd)'" == "`ecmd'" & mreldif(e(b), `eb') == 0
        assert `rmean_after' == `rmean'
        _rs_text_in_file using "`slog'", text("`s' was removed in msm 2.0.0")
        assert r(found) == 1
        _rs_text_in_file using "`slog'", text("`want_`s''")
        assert r(found) == 1
        capture confirm file "never.xlsx"
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "PASS RS1: every stub exits 199 with its replacement and touches nothing"
    local ++pass_count
}
else {
    display as error "FAIL RS1: stub contract (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' RS1"
}

* A 1.4.x-shaped msm package: a live msm_table plus an orphan helper.
tempfile oldanchor
local olddir "`oldanchor'_old"
capture mkdir "`olddir'"
tempname fh
file open `fh' using "`olddir'/stata.toc", write text replace
file write `fh' "v 3" _n "p msm" _n
file close `fh'
file open `fh' using "`olddir'/msm.pkg", write text replace
file write `fh' "v 3" _n "d msm 1.4.12 (QA stand-in)" _n
file write `fh' "f msm.ado" _n "f msm_table.ado" _n "f msm_report.ado" _n "f _msm_tbl_coef.ado" _n
file close `fh'
foreach f in msm msm_table msm_report _msm_tbl_coef {
    file open `fh' using "`olddir'/`f'.ado", write text replace
    file write `fh' "*! `f' Version 1.4.12  2026/10/09" _n
    file write `fh' "program define `f'" _n
    file write `fh' `"    display "OLD-1.4.12-`f'""' _n
    file write `fh' "end" _n
    file close `fh'
}

capture program drop _rs_resolve_all
program define _rs_resolve_all
    args stubs
    foreach s of local stubs {
        capture program drop `s'
        quietly findfile `s'.ado
        tempname fh
        file open `fh' using "`r(fn)'", read text
        file read `fh' line
        file close `fh'
        * the installed file is the 2.0.0 stub, not the 1.4.x command
        assert regexm(`"`line'"', "Version 2\.")
        capture `s'
        assert _rc == 199
    }
end

**# RS2: upgrade over 1.4.x WITHOUT uninstalling
local ++test_count
capture noisily {
    capture ado uninstall msm
    capture ado uninstall msm
    quietly net install msm, from("`olddir'") replace
    capture program drop msm_table
    msm_table
    quietly net install msm, from("`pkg_dir'") replace
    discard
    _rs_resolve_all "`stubs'"
    * msm itself is the 2.0 dispatcher
    quietly msm, list
    assert r(n_commands) == 5
}
if _rc == 0 {
    display as result "PASS RS2: net install over 1.4.x resolves every removed name to its stub"
    local ++pass_count
}
else {
    display as error "FAIL RS2: upgrade without uninstall (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' RS2"
}

**# RS3: documented upgrade route (uninstall first)
* RS2 leaves two msm entries in the sandbox (the old and the new), and
* `ado uninstall msm' refuses an ambiguous name, so clear by entry number,
* highest first. This sandbox holds msm only.
local ++test_count
capture noisily {
    forvalues i = 9(-1)1 {
        capture ado uninstall [`i']
    }
    quietly net install msm, from("`olddir'") replace
    capture ado uninstall msm
    quietly net install msm, from("`pkg_dir'") replace
    discard
    _rs_resolve_all "`stubs'"
    capture findfile _msm_tbl_coef.ado
    assert _rc != 0
}
if _rc == 0 {
    display as result "PASS RS3: uninstall-then-install leaves only 2.0 files"
    local ++pass_count
}
else {
    display as error "FAIL RS3: documented upgrade (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' RS3"
}

**# RS4: stub help files render and name the replacement
local ++test_count
capture noisily {
    foreach s of local stubs {
        local f "`pkg_dir'/`s'.sthlp"
        confirm file "`f'"
        tempfile hlog
        log using "`hlog'", text replace name(hlplog)
        type "`f'", smcl
        log close hlplog
        _rs_text_in_file using "`hlog'", text("Removed in msm 2.0.0")
        assert r(found) == 1
        _rs_text_in_file using "`hlog'", text("return code 199")
        assert r(found) == 1
        _rs_text_in_file using "`hlog'", text("{")
        assert r(found) == 0
    }
}
if _rc == 0 {
    display as result "PASS RS4: stub help files render"
    local ++pass_count
}
else {
    display as error "FAIL RS4: stub help (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' RS4"
}

capture erase "`olddir'/msm.pkg"
capture erase "`olddir'/stata.toc"
foreach f in msm msm_table msm_report _msm_tbl_coef {
    capture erase "`olddir'/`f'.ado"
}
capture rmdir "`olddir'"

**# RS5: each removed command called by its literal name exits 199 and names its replacement
* A removed command is refused before it looks at the data, so even a
* degenerate (empty) dataset gets the 199 replacement message, not a data error.
local ++test_count
capture noisily {
    clear
    set obs 0
    tempfile rs5log
    log using "`rs5log'", text replace name(rs5)
    * nullcase: msm_protocol msm_validate msm_plot msm_report msm_table msm_diagtab msm_sensitivity
    capture noisily msm_protocol
    assert _rc == 199
    capture noisily msm_validate, anything(1)
    assert _rc == 199
    capture noisily msm_plot, anything(1)
    assert _rc == 199
    capture noisily msm_report, anything(1) xlsx("never5.xlsx")
    assert _rc == 199
    capture noisily msm_table, anything(1)
    assert _rc == 199
    capture noisily msm_diagtab, anything(1)
    assert _rc == 199
    capture noisily msm_sensitivity, anything(1)
    assert _rc == 199
    log close rs5
    foreach s in protocol validate plot report table diagtab sensitivity {
        _rs_text_in_file using "`rs5log'", text("msm_`s' was removed in msm 2.0.0")
        assert r(found) == 1
        _rs_text_in_file using "`rs5log'", text("`want_msm_`s''")
        assert r(found) == 1
    }
    assert _N == 0 & c(k) == 0
    capture confirm file "never5.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "PASS RS5: literal invocations exit 199 with their replacement"
    local ++pass_count
}
else {
    capture log close rs5
    display as error "FAIL RS5: literal stub invocations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' RS5"
}

**# Summary
if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" test_msm_removed_stubs ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_removed_stubs tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1

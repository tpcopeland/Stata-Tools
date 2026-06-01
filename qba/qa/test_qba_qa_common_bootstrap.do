* test_qba_qa_common_bootstrap.do -- QA helper root and install bootstrap tests
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_qa_common_bootstrap.do

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

local test_count = 0
local pass_count = 0
local fail_count = 0

**# B1: root detection returns package and QA directories
local ++test_count
capture noisily {
    _qba_qa_root
    local pkg_dir `"`r(pkg_dir)'"'
    local qa_dir `"`r(qa_dir)'"'
    confirm file "`pkg_dir'/qba.pkg"
    confirm file "`qa_dir'/run_all.do"
    confirm file "`qa_dir'/_qba_qa_common.do"
}
if _rc == 0 {
    display as result "  PASS: B1 root detection"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 root detection (error `=_rc')"
    local ++fail_count
}

**# B2: standard bootstrap installs qba from detected root
local ++test_count
capture noisily {
    _qba_qa_bootstrap
    local pkg_dir `"`r(pkg_dir)'"'
    which qba
    findfile _qba_distributions.ado
    confirm file "`r(fn)'"
    capture ado uninstall qba
}
if _rc == 0 {
    display as result "  PASS: B2 standard bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 standard bootstrap (error `=_rc')"
    local ++fail_count
}

**# B3: isolated bootstrap restores PLUS and PERSONAL
local ++test_count
local before_plus "`c(sysdir_plus)'"
local before_personal "`c(sysdir_personal)'"
capture noisily {
    _qba_qa_bootstrap, isolated
    local orig_plus `"`r(orig_plus)'"'
    local orig_personal `"`r(orig_personal)'"'
    local plusdir `"`r(plusdir)'"'
    local personaldir `"`r(personaldir)'"'
    assert "`c(sysdir_plus)'" == "`plusdir'/"
    assert "`c(sysdir_personal)'" == "`personaldir'/"
    which qba_misclass
    qba_misclass, a(80) b(120) c(200) d(600) seca(.8) spca(.9)
    assert r(corrected) > 0
    _qba_qa_restore_isolation, origplus("`orig_plus'") ///
        origpersonal("`orig_personal'") plusdir("`plusdir'") ///
        personaldir("`personaldir'") uninstall
    local got_plus "`c(sysdir_plus)'"
    local got_personal "`c(sysdir_personal)'"
    if substr("`got_plus'", -1, 1) == "/" local got_plus = substr("`got_plus'", 1, length("`got_plus'") - 1)
    if substr("`orig_plus'", -1, 1) == "/" local orig_plus = substr("`orig_plus'", 1, length("`orig_plus'") - 1)
    if substr("`got_personal'", -1, 1) == "/" local got_personal = substr("`got_personal'", 1, length("`got_personal'") - 1)
    if substr("`orig_personal'", -1, 1) == "/" local orig_personal = substr("`orig_personal'", 1, length("`orig_personal'") - 1)
    assert "`got_plus'" == "`orig_plus'"
    assert "`got_personal'" == "`orig_personal'"
    capture confirm file "`plusdir'/stata.trk"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: B3 isolated bootstrap restore"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 isolated bootstrap restore (error `=_rc')"
    capture _qba_qa_restore_isolation, origplus("`before_plus'") ///
        origpersonal("`before_personal'") plusdir("`plusdir'") ///
        personaldir("`personaldir'") uninstall
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_qa_common_bootstrap tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_qa_common_bootstrap tests=`test_count' pass=`pass_count' fail=`fail_count'"

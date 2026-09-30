*! test_pkgtransfer_fixture_state.do -- exact native scalar presence/type/value on every exit
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_pkgtransfer_fixture_state.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
do _pkgtransfer_qa_common.do
_pkgtransfer_qa_setup, pkgdir("`pkg_dir'")
local transferroot `"`r(root)'"'
local originalplus `"`r(original_plus)'"'
local originalpersonal `"`r(original_personal)'"'
local tests 0
local pass 0
local fail 0

**# absent success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    qa_state_snapshot, tag(pkg_cv)
    local output `"`macval(root)'/installer.do"'
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: absent success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent success"
}

**# absent early
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, qa_bad_option
    assert _rc==198
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: absent early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent early"
}

**# absent late
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, limited(alpha fre) dofile(`"`macval(root)'/missing_parent/installer.do"')
    assert _rc==603
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: absent late rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent late"
}

**# numeric success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    mata: st_numscalar("cv",.12345678901234564)
    qa_state_snapshot, tag(pkg_cv)
    local output `"`macval(root)'/installer.do"'
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: numeric success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: numeric success"
}

**# numeric early
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    mata: st_numscalar("cv",.12345678901234564)
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, qa_bad_option
    assert _rc==198
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: numeric early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: numeric early"
}

**# numeric late
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    mata: st_numscalar("cv",.12345678901234564)
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, limited(alpha fre) dofile(`"`macval(root)'/missing_parent/installer.do"')
    assert _rc==603
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: numeric late rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: numeric late"
}

**# string success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    mata: st_strscalar("cv",char(36)+"OPAQUE "+char(96)+"tick"+char(39)+" "+char(34)+"dq"+char(34))
    qa_state_snapshot, tag(pkg_cv)
    local output `"`macval(root)'/installer.do"'
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: string success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: string success"
}

**# string early
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    mata: st_strscalar("cv",char(36)+"OPAQUE "+char(96)+"tick"+char(39)+" "+char(34)+"dq"+char(34))
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, qa_bad_option
    assert _rc==198
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: string early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: string early"
}

**# string late
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    mata: st_strscalar("cv",char(36)+"OPAQUE "+char(96)+"tick"+char(39)+" "+char(34)+"dq"+char(34))
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, limited(alpha fre) dofile(`"`macval(root)'/missing_parent/installer.do"')
    assert _rc==603
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: string late rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: string late"
}

**# variable_shadow success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    generate double cv=id/3
    qa_state_snapshot, tag(pkg_cv)
    local output `"`macval(root)'/installer.do"'
    quietly pkgtransfer, limited(alpha fre) dofile(`"`macval(output)'"')
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    assert `"`r(dofile)'"'==`"`macval(output)'"'
    python: _t=__import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text(); assert _t.count("ssc install fre")==1 and _t.count("net install alpha")==1
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: variable_shadow success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: variable_shadow success"
}

**# variable_shadow early
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    generate double cv=id/3
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, qa_bad_option
    assert _rc==198
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: variable_shadow early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: variable_shadow early"
}

**# variable_shadow late
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    capture scalar drop cv
    generate double cv=id/3
    qa_state_snapshot, tag(pkg_cv)
    * expect: REFUSED
    python: _pkg_cv_tree={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    capture noisily pkgtransfer, limited(alpha fre) dofile(`"`macval(root)'/missing_parent/installer.do"')
    assert _rc==603
    assert r(N_packages)==2 & "`r(package_list)'"=="alpha fre"
    python: assert _pkg_cv_tree=={str(p.relative_to(__import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")))):p.read_bytes() for p in __import__("pathlib").Path(__import__("sfi").Macro.getLocal("root")).rglob("*") if p.is_file()}
    qa_state_compare, tag(pkg_cv)
    * The boundary must not inhibit the next ordinary native import.
    local nextfile `"`macval(root)'/next.csv"'
    python: __import__("pathlib").Path(__import__("sfi").Macro.getLocal("nextfile")).write_text("value\n11\n22\n")
    preserve
    import delimited using `"`nextfile'"', clear
    assert _N==2 & value==11*_n
    assert scalar(cv)==16
    restore
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: variable_shadow late rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: variable_shadow late"
}

capture noisily _pkgtransfer_qa_cleanup, root(`"`transferroot'"') originalplus(`"`originalplus'"') originalpersonal(`"`originalpersonal'"')
if _rc {
    local ++tests
    local ++fail
}
display "RESULT: test_pkgtransfer_fixture_state tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1

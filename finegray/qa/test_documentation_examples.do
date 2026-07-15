* test_documentation_examples.do
* Every runnable code block in README.md (and the flagship .sthlp Examples) must
* run for an installed user, verbatim, with rc 0.  This is the axis the release
* gate `runnable_examples' probes and the one the other suites do not: they test
* the commands, not the documented invocations of them.  A doc example that no
* longer parses -- a renamed option, a dropped default, a changed syntax -- is
* invisible to every test that calls the command its own way.
*
* Each block is copied AS PRINTED.  Do not "improve" them here; if a block needs
* changing, change the doc first, then mirror it.  The `webuse hypoxia' preamble
* is repeated per block exactly as the README repeats it, so each block is proven
* to stand on its own the way a reader would run it.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_documentation_examples.log", replace name(_docex)

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Run one documented block; PASS iff it completes with rc 0.  Blocks are wrapped
* in capture noisily so a failure is reported, not fatal, and the remaining
* blocks still run.
capture program drop _docblock
program define _docblock
    args tag
    display as text _newline "=== example: `tag' ==="
end

**# README block 0 -- Quick Start
local ++test_count
capture noisily {
    _docblock "README Quick Start"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)

    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_cif, attime(1 5 8) ci
    finegray_phtest
}
if _rc == 0 {
    display as result "  PASS: README Quick Start"
    local ++pass_count
}
else {
    display as error "  FAIL: README Quick Start (rc=`=_rc')"
    local ++fail_count
}

**# README block 2 -- basic fit
local ++test_count
capture noisily {
    _docblock "README basic fit"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)

    finegray ifp tumsize pelnode, compete(status) cause(1)
}
if _rc == 0 {
    display as result "  PASS: README basic fit"
    local ++pass_count
}
else {
    display as error "  FAIL: README basic fit (rc=`=_rc')"
    local ++fail_count
}

**# README block 3 -- predict cif and timevar
local ++test_count
capture noisily {
    _docblock "README predict cif"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)

    finegray_predict cif_hat, cif
    gen double t5 = 5
    finegray_predict cif_at5, cif timevar(t5)
}
if _rc == 0 {
    display as result "  PASS: README predict cif"
    local ++pass_count
}
else {
    display as error "  FAIL: README predict cif (rc=`=_rc')"
    local ++fail_count
}

**# README block 4 -- phtest variants
local ++test_count
capture noisily {
    _docblock "README phtest"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)

    finegray_phtest
    finegray_phtest, time(log)
}
if _rc == 0 {
    display as result "  PASS: README phtest variants"
    local ++pass_count
}
else {
    display as error "  FAIL: README phtest variants (rc=`=_rc')"
    local ++fail_count
}

**# README block 5 -- fv, strata, norobust, noshr
local ++test_count
capture noisily {
    _docblock "README fit variants"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)

    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1)
    finegray ifp tumsize, compete(status) cause(1) strata(pelnode)
    finegray ifp tumsize pelnode, compete(status) cause(1) norobust
    finegray ifp tumsize pelnode, compete(status) cause(1) noshr
}
if _rc == 0 {
    display as result "  PASS: README fit variants"
    local ++pass_count
}
else {
    display as error "  FAIL: README fit variants (rc=`=_rc')"
    local ++fail_count
}

**# README block 6 -- cif and predict with CI, saving
local ++test_count
capture noisily {
    _docblock "README cif/predict CI"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)

    finegray_cif, ci
    finegray_cif, at(pelnode=1 ifp=20) ci
    finegray_cif, attime(1 5 8) ci
    finegray_cif, ci nograph saving("`c(tmpdir)'/cifcurve.dta", replace)

    gen double t5 = 5
    finegray_predict cif5, cif timevar(t5) ci
    confirm variable cif5_lci
    confirm variable cif5_uci
}
if _rc == 0 {
    display as result "  PASS: README cif/predict CI"
    local ++pass_count
}
else {
    display as error "  FAIL: README cif/predict CI (rc=`=_rc')"
    local ++fail_count
}

**# Doc-advertised new-in-1.2.0 invocations: basehaz + basecshazard
* These are documented (Options table, Stored results, help) but appear in no
* README code block; a reader who copies the prose must still be able to run them.
local ++test_count
capture noisily {
    _docblock "basehaz + basecshazard"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)

    finegray ifp tumsize pelnode, compete(status) cause(1) basehaz
    confirm matrix e(basehaz)
    finegray_predict bch, basecshazard
    confirm variable bch
}
if _rc == 0 {
    display as result "  PASS: basehaz + basecshazard"
    local ++pass_count
}
else {
    display as error "  FAIL: basehaz + basecshazard (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _docex
    exit 1
}
display as result "ALL TESTS PASSED"
log close _docex

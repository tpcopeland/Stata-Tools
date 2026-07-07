* test_qba_docs.do -- documentation and installed-surface tests for qba
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_docs.do

clear all

* === Bootstrap ===
capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap
local qa_dir `"`r(qa_dir)'"'
local pkg_dir `"`r(pkg_dir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0

* D1: Installed package surface is discoverable
local ++test_count
capture noisily {
    foreach cmd in qba qba_misclass qba_selection qba_confound qba_multi qba_plot {
        which `cmd'
    }
    foreach f in qba.sthlp qba_misclass.sthlp qba_selection.sthlp ///
        qba_confound.sthlp qba_multi.sthlp qba_plot.sthlp ///
        _qba_distributions.ado _qba_detect_contract.ado {
        findfile `f'
        confirm file "`r(fn)'"
	    }
	    qba
	    * Assert a well-formed semantic version rather than pinning a literal
	    * that goes stale on every bump (currency is enforced by the CLI
	    * version check, not this suite).
	    assert regexm("`r(version)'", "^[0-9]+\.[0-9]+\.[0-9]+$")
	    assert "`r(commands)'" == "qba_misclass qba_selection qba_confound qba_multi qba_plot"
	}
if _rc == 0 {
    display as result "  PASS: D1 Installed commands, help files, and helper are discoverable"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 Installed package surface (error `=_rc')"
    local ++fail_count
}

* D2: README from_model example runs as displayed
local ++test_count
capture noisily {
    sysuse auto, clear
    logistic foreign mpg weight
    qba_confound, from_model coef(mpg) p1(.35) p0(.15) rrcd(1.8) evalue
    assert "`r(measure)'" == "OR"
    assert r(observed) > 0
    assert r(corrected) > 0
    assert r(evalue) > 0
}
if _rc == 0 {
    display as result "  PASS: D2 README from_model example runs"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 README from_model example (error `=_rc')"
    local ++fail_count
}

* D3: qba.sthlp probabilistic example feeds qba_plot as displayed
local ++test_count
capture noisily {
    capture erase "mc_misclass.dta"
    qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        reps(10000) dist_se("trapezoidal .75 .82 .88 .95") ///
        dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345) saving(mc_misclass, replace)
    confirm file "mc_misclass.dta"
    qba_plot, distribution using(mc_misclass) observed(2.15)
    assert "`r(plot_type)'" == "distribution"
    capture graph close _all
    capture erase "mc_misclass.dta"
}
if _rc == 0 {
    display as result "  PASS: D3 qba.sthlp saved-MC plotting workflow runs"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 qba.sthlp plotting workflow (error `=_rc')"
    local ++fail_count
    capture graph close _all
    capture erase "mc_misclass.dta"
}

* D4: TMLE/LTMLE contract workflow is documented in package docs
local ++test_count
capture noisily {
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "Use qba_confound after tmle or ltmle")
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "active estimation contract")
    assert strpos(fileread("`pkg_dir'/qba_confound.sthlp"), ///
        "After tmle or ltmle")
    assert strpos(fileread("`pkg_dir'/qba_confound.sthlp"), ///
        "active {cmd:tmle} or {cmd:ltmle} estimation")
    assert strpos(fileread("`pkg_dir'/qba.sthlp"), ///
        "active {cmd:tmle}/{cmd:ltmle}")
}
if _rc == 0 {
    display as result "  PASS: D4 TMLE/LTMLE contract workflow documented"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 TMLE/LTMLE documentation contract (error `=_rc')"
    local ++fail_count
}

* D5: Selection distribution and stored-result tokens are individually documented
local ++test_count
capture noisily {
    foreach token in ///
        "{synopt:{opt dist_sela(distribution)}}" ///
        "{synopt:{opt dist_selb(distribution)}}" ///
        "{synopt:{opt dist_selc(distribution)}}" ///
        "{synopt:{opt dist_seld(distribution)}}" {
        assert strpos(fileread("`pkg_dir'/qba_multi.sthlp"), "`token'")
    }
    foreach token in ///
        "{synopt:{cmd:r(a)}}" ///
        "{synopt:{cmd:r(b)}}" ///
        "{synopt:{cmd:r(c)}}" ///
        "{synopt:{cmd:r(d)}}" ///
        "{synopt:{cmd:r(corrected_a)}}" ///
        "{synopt:{cmd:r(corrected_b)}}" ///
        "{synopt:{cmd:r(corrected_c)}}" ///
        "{synopt:{cmd:r(corrected_d)}}" ///
        "{synopt:{cmd:r(sela)}}" ///
        "{synopt:{cmd:r(selb)}}" ///
        "{synopt:{cmd:r(selc)}}" ///
        "{synopt:{cmd:r(seld)}}" {
        assert strpos(fileread("`pkg_dir'/qba_selection.sthlp"), "`token'")
    }
}
if _rc == 0 {
    display as result "  PASS: D5 Selection docs expose explicit distribution and stored-result tokens"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 Selection docs token coverage (error `=_rc')"
    local ++fail_count
}

display as text ""
display as result "Documentation QA: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    capture ado uninstall qba
}

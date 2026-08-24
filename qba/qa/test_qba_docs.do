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

* Render help through Stata's SMCL interpreter and fail on literal markup.
capture program drop _qa_sthlp_render
program define _qa_sthlp_render, rclass
    version 16.0
    syntax anything(name=files id="help files")

    local files = subinstr(`"`files'"', char(34), "", .)
    local nbad 0
    local badfiles ""

    foreach f of local files {
        capture confirm file "`f'"
        if _rc {
            display as error "  render: file not found: `f'"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }

        tempfile rlog
        capture log off
        log using "`rlog'", replace text name(_qarender)
        type "`f'", smcl
        log close _qarender
        capture log on

        local hits 0
        local nlines 0
        tempname fh
        file open `fh' using "`rlog'", read text
        file read `fh' line
        while r(eof) == 0 {
            local ++nlines
            if regexm(`"`line'"', "\{(pstd|phang|pmore|pin|p_end|psee|synopt|p2col|cmd:|it:|bf:|opt |opth |helpb |hline|title:|marker |dlgtab:|break)") {
                local shown = subinstr(`"`line'"', "{", char(1), .)
                local shown = subinstr(`"`shown'"', "}", char(2), .)
                local shown = subinstr(`"`shown'"', char(1), "{c -(}", .)
                local shown = subinstr(`"`shown'"', char(2), "{c )-}", .)
                display as error "  literal SMCL: `shown'"
                local ++hits
            }
            file read `fh' line
        }
        file close `fh'

        if `nlines' == 0 {
            display as error "  render produced no output for `f' -- FAILING"
            local ++nbad
            local badfiles "`badfiles' `f'"
            continue
        }
        if `hits' > 0 {
            local ++nbad
            local badfiles "`badfiles' `f'"
        }
    }

    return scalar nbad = `nbad'
    return local badfiles "`badfiles'"
end

* D1: Installed package surface is discoverable
local ++test_count
capture noisily {
    foreach cmd in qba qba_misclass qba_selection qba_confound qba_multi qba_plot {
        which `cmd'
    }
    foreach f in qba.sthlp qba_misclass.sthlp qba_selection.sthlp ///
        qba_confound.sthlp qba_multi.sthlp qba_plot.sthlp ///
        _qba_distributions.ado _qba_detect_contract.ado ///
        _qba_evalue_scale.ado {
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
    assert !missing(r(observed))
    assert r(observed) > 0
    assert !missing(r(corrected))
    assert r(corrected) > 0
    assert !missing(r(evalue))
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

* D6: Every shipped help file renders cleanly; the oracle catches a known defect
local ++test_count
capture noisily {
    local sthlps : dir "`pkg_dir'" files "*.sthlp"
    local paths ""
    foreach s of local sthlps {
        local paths "`paths' `pkg_dir'/`s'"
    }
    _qa_sthlp_render `paths'
    assert r(nbad) == 0

    tempfile broken
    tempname bfh
    file open `bfh' using "`broken'", write replace text
    file write `bfh' "{smcl}" _n
    file write `bfh' "{title:Render probe}" _n _n
    file write `bfh' "{pstd}" _n
    file write `bfh' "A directive split across a source newline: {bf:broken" _n
    file write `bfh' "directive} renders as literal markup." _n
    file close `bfh'
    _qa_sthlp_render `broken'
    assert r(nbad) == 1
}
if _rc == 0 {
    display as result "  PASS: D6 shipped help renders; positive control fails"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 SMCL render oracle (error `=_rc')"
    local ++fail_count
}

display as text ""
display as result "Documentation QA: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    display "RESULT: test_qba_docs tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    capture ado uninstall qba
    display "RESULT: test_qba_docs tests=`test_count' pass=`pass_count' fail=`fail_count'"
}

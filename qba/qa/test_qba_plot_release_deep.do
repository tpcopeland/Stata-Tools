* test_qba_plot_release_deep.do -- release-surface and installed qba_plot QA
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_plot_release_deep.do

clear all
version 16.0

**# Bootstrap
capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap, isolated
local qa_dir `"`r(qa_dir)'"'
local pkg_dir `"`r(pkg_dir)'"'
local orig_plus `"`r(orig_plus)'"'
local orig_personal `"`r(orig_personal)'"'
local plusdir `"`r(plusdir)'"'
local personaldir `"`r(personaldir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _qba_drop_graph_if_exists
program define _qba_drop_graph_if_exists
    args graph_name
    quietly graph dir
    local graph_list " `r(list)' "
    if "`graph_name'" == "_all" {
        if trim("`graph_list'") != "" {
            graph drop _all
        }
        exit
    }
    if strpos("`graph_list'", " `graph_name' ") {
        graph drop `graph_name'
    }
end

capture program drop _make_mc_or
program define _make_mc_or
    syntax , SAving(string)
    clear
    set obs 50
    gen double corrected_or = 1 + _n / 100
    save "`saving'", replace
end

**# R1: installed surface is complete from qba.pkg
local ++test_count
capture noisily {
    foreach cmd in qba qba_misclass qba_selection qba_confound qba_multi qba_plot {
        which `cmd'
    }
    foreach f in qba.sthlp qba_misclass.sthlp qba_selection.sthlp ///
        qba_confound.sthlp qba_multi.sthlp qba_plot.sthlp ///
        _qba_distributions.ado {
        findfile `f'
        confirm file "`r(fn)'"
    }
    qba
    * Assert a well-formed semantic version rather than pinning a literal that
    * goes stale on every bump (currency is enforced by the CLI version check).
    assert regexm("`r(version)'", "^[0-9]+\.[0-9]+\.[0-9]+$")
    assert "`r(commands)'" == "qba_misclass qba_selection qba_confound qba_multi qba_plot"

    findfile _qba_distributions.ado
    run "`r(fn)'"
    _qba_parse_dist, dist("trapezoidal .75 .82 .88 .95")
    assert "`r(dtype)'" == "trapezoidal"
}
if _rc == 0 {
    display as result "  PASS: R1 installed package surface and helper autoload"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 installed package surface (error `=_rc')"
    local ++fail_count
}

**# R2: release metadata, version/date sync, and package file list
local ++test_count
capture noisily {
    _assert_file_contains "`pkg_dir'/qba.ado" "Version 1.0.1  2026/06/19"
    _assert_file_contains "`pkg_dir'/qba_plot.ado" "Version 1.0.1  2026/06/19"
    _assert_file_contains "`pkg_dir'/qba.sthlp" "version 1.0.1  19jun2026"
    * House standard: only the flagship qba.sthlp carries a version line;
    * sub-command help files must not (see CLAUDE.md version-consistency rule).
    * (Stata's shell does not propagate grep's exit code to _rc, so assert on
    * file content via the helper rather than on _rc after a shell grep.)
    _assert_text_file_not_contains "`pkg_dir'/qba_plot.sthlp" "version 1.0.1"
    _assert_text_file_not_contains "`pkg_dir'/qba_plot.sthlp" "Version 1.0.1"
    * README is prose with markdown code fences; reading it line-by-line into a
    * macro is fragile (unbalanced backticks). Grep the count into a temp file
    * and read the integer -- Stata's shell does not propagate grep's exit code.
    tempfile _grep_cnt
    shell grep -Fc "Version 1.0.1" "`pkg_dir'/README.md" > "`_grep_cnt'"
    file open _gfh using "`_grep_cnt'", read text
    file read _gfh _gline
    file close _gfh
    assert real("`_gline'") > 0
    shell grep -Fc "2026-06-19" "`pkg_dir'/README.md" > "`_grep_cnt'"
    file open _gfh using "`_grep_cnt'", read text
    file read _gfh _gline
    file close _gfh
    assert real("`_gline'") > 0
    _assert_file_contains "`pkg_dir'/qba.pkg" "Distribution-Date: 20260619"
    _assert_file_contains "`pkg_dir'/qba.pkg" "Author: Timothy P Copeland, Karolinska Institutet"

    foreach f in qba.ado qba.sthlp qba_misclass.ado qba_misclass.sthlp ///
        qba_selection.ado qba_selection.sthlp qba_confound.ado ///
        qba_confound.sthlp qba_multi.ado qba_multi.sthlp ///
        qba_plot.ado qba_plot.sthlp _qba_distributions.ado {
        _assert_file_contains "`pkg_dir'/qba.pkg" "f `f'"
    }

    _assert_file_contains "`pkg_dir'/stata.toc" "v 3"
    _assert_file_contains "`pkg_dir'/stata.toc" "d Stata-Tools: qba"
    _assert_file_contains "`pkg_dir'/stata.toc" "d Timothy P Copeland, Karolinska Institutet"
    _assert_file_contains "`pkg_dir'/stata.toc" "d https://github.com/tpcopeland/Stata-Tools"
    _assert_file_contains "`pkg_dir'/stata.toc" "p qba"
}
if _rc == 0 {
    display as result "  PASS: R2 release metadata and package file list"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 release metadata/package list (error `=_rc')"
    local ++fail_count
}

**# R3: README and help examples run after net install
local ++test_count
capture noisily {
    tempfile mc_results

    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)
    assert "`r(method)'" == "simple"

    qba_selection, a(136) b(297) c(1432) d(6738) ///
        sela(.9) selb(.85) selc(.7) seld(.8)
    assert "`r(method)'" == "simple"

    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) evalue ci_bound(1.1)
    assert "`r(method)'" == "simple"
    assert r(evalue) > 0

    sysuse auto, clear
    logistic foreign mpg weight
    qba_confound, from_model coef(mpg) p1(.35) p0(.15) rrcd(1.8) evalue
    assert "`r(measure)'" == "OR"

    sysuse auto, clear
    regress price mpg weight
    qba_confound, from_model coef(weight) p1(.3) p0(.1) confeffect(500)
    assert "`r(measure)'" == "coefficient"
    assert "`r(correction_type)'" == "subtractive"

    qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95) ///
        reps(10000) dist_se("trapezoidal .75 .82 .88 .95") ///
        dist_sp("trapezoidal .90 .93 .97 1.0") seed(12345) ///
        saving("`mc_results'", replace)
    assert r(reps) == 10000

    qba_multi, a(136) b(297) c(1432) d(6738) reps(10000) ///
        seca(.85) spca(.95) dist_se("trapezoidal .75 .82 .88 .95") ///
        sela(.9) selb(.85) selc(.7) seld(.8) ///
        p1(.4) p0(.2) rrcd(2.0) seed(12345)
    assert "`r(method)'" == "multi-bias"

    qba_plot, distribution using("`mc_results'") observed(2.15) ///
        name(qba_rel_dist, replace)
    assert "`r(plot_type)'" == "distribution"
    assert "`r(measure)'" == "OR"
    _qba_drop_graph_if_exists qba_rel_dist

    qba_plot, tornado a(136) b(297) c(1432) d(6738) ///
        param1(se) range1(.7 1) param2(sp) range2(.8 1) ///
        name(qba_rel_tornado, replace)
    assert "`r(plot_type)'" == "tornado"
    _qba_drop_graph_if_exists qba_rel_tornado

    qba_plot, tipping a(136) b(297) c(1432) d(6738) ///
        param1(se) range1(.6 1) param2(sp) range2(.6 1) ///
        name(qba_rel_tipping, replace)
    assert "`r(plot_type)'" == "tipping"
    _qba_drop_graph_if_exists qba_rel_tipping
}
if _rc == 0 {
    display as result "  PASS: R3 README/help examples run after net install"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 README/help examples (error `=_rc')"
    _qba_drop_graph_if_exists qba_rel_dist
    _qba_drop_graph_if_exists qba_rel_tornado
    _qba_drop_graph_if_exists qba_rel_tipping
    local ++fail_count
}

**# R4: qba_plot graph failure paths retain r() payload
local ++test_count
capture noisily {
    tempfile dist_data
    _make_mc_or, saving("`dist_data'")

    local export_svg "`c(tmpdir)'/qba_release_deep_existing.svg"
    capture erase "`export_svg'"
    qba_plot, distribution using("`dist_data'") observed(1.2) ///
        saving("`export_svg'") name(qba_rel_export_seed, replace) replace
    confirm file "`export_svg'"
    _qba_drop_graph_if_exists qba_rel_export_seed

    capture qba_plot, distribution using("`dist_data'") observed(1.2) ///
        saving("`export_svg'") name(qba_rel_export_fail, replace)
    local export_rc = _rc
    assert `export_rc' == 602
    assert "`r(plot_type)'" == "distribution"
    assert "`r(measure)'" == "OR"
    _qba_drop_graph_if_exists qba_rel_export_fail

    qba_plot, distribution using("`dist_data'") observed(1.2) ///
        replace saving("`export_svg'") name(qba_rel_export_order, replace)
    confirm file "`export_svg'"
    _qba_drop_graph_if_exists qba_rel_export_order

    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) steps(4) name(qba_rel_name_collision, replace)
    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) steps(4) name(qba_rel_name_collision)
    local rename_rc = _rc
    assert `rename_rc' != 0
    assert "`r(plot_type)'" == "tornado"
    assert "`r(measure)'" == "OR"

    capture erase "`export_svg'"
    _qba_drop_graph_if_exists qba_rel_name_collision
}
if _rc == 0 {
    display as result "  PASS: R4 graph export/name failure keeps r() payload"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 graph failure return semantics (error `=_rc')"
    capture erase "`export_svg'"
    _qba_drop_graph_if_exists qba_rel_export_seed
    _qba_drop_graph_if_exists qba_rel_export_fail
    _qba_drop_graph_if_exists qba_rel_name_collision
    local ++fail_count
}

**# Summary
display as text ""
display as result "Release-deep qba_plot QA: `pass_count'/`test_count' passed, `fail_count' failed"

_qba_drop_graph_if_exists _all
_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_plot_release_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
    display "RESULT: test_qba_plot_release_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
}

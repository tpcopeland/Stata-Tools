clear all
set more off
version 16.0
set varabbrev off

* test_iivw_release_adversarial.do - release surface, install, and docs QA
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_release_adversarial.do

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/iivw.pkg"
if _rc {
    display as error "Run this test from the iivw/qa directory"
    exit 601
}
local repo_dir = subinstr("`pkg_dir'", "/iivw", "", 1)

local old_cwd "`c(pwd)'"
local old_plus "`c(sysdir_plus)'"
local old_personal "`c(sysdir_personal)'"

tempfile __plus_stub __personal_stub __work_stub
local plus_dir "`__plus_stub'_plus"
local personal_dir "`__personal_stub'_personal"
local work_dir "`__work_stub'_work"

local test_count = 0
local pass_count = 0
local fail_count = 0
local installed_ready = 0
local tabtools_ready = 0
local install_path ""

capture mata: mata drop _qa_iivw_file_has()
mata:
real scalar _qa_iivw_file_has(string scalar file, string scalar pattern)
{
    real scalar fh, found
    string scalar line

    fh = fopen(file, "r")
    found = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, pattern) > 0) {
            found = 1
        }
    }
    fclose(fh)
    return(found)
}
end

capture program drop _qa_iivw_file_has
program define _qa_iivw_file_has, rclass
    version 16.0
    syntax , FILE(string) PATTERN(string)

    tempname found
    mata: st_numscalar("`found'", _qa_iivw_file_has(st_local("file"), st_local("pattern")))
    return scalar found = scalar(`found')
end

capture program drop _qa_iivw_must_contain
program define _qa_iivw_must_contain
    version 16.0
    syntax , FILE(string) PATTERN(string)

    quietly _qa_iivw_file_has, file("`file'") pattern(`"`pattern'"')
    if r(found) != 1 {
        display as error "missing expected text in `file'"
        display as error "  pattern: `pattern'"
        exit 9
    }
end

capture program drop _qa_iivw_must_not_contain
program define _qa_iivw_must_not_contain
    version 16.0
    syntax , FILE(string) PATTERN(string)

    quietly _qa_iivw_file_has, file("`file'") pattern(`"`pattern'"')
    if r(found) == 1 {
        display as error "forbidden release-surface text found in `file'"
        display as error "  pattern: `pattern'"
        exit 9
    }
end

capture program drop _qa_iivw_doc_data
program define _qa_iivw_doc_data
    version 16.0

    clear
    set seed 20260417
    set obs 320
    gen long id = ceil(_n/4)
    bysort id: gen byte visit = _n
    gen double days = (visit - 1) * 90 + runiform() * 20
    replace days = 0 if visit == 1
    gen double edss_bl = 2 + 3 * runiform()
    bysort id: replace edss_bl = edss_bl[1]
    gen double age = 35 + 15 * runiform()
    bysort id: replace age = age[1]
    gen byte sex = runiform() > 0.5
    bysort id: replace sex = sex[1]
    gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))
    bysort id: replace treated = treated[1]
    gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)
    gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))
    gen byte treatment = cond(treated == 0, 0, cond(edss_bl < 3.5, 1, 2))
    capture label drop arm
    label define arm 0 "Placebo" 1 "Low dose" 2 "High dose"
    label values treatment arm
end

capture program drop _qa_iivw_ensure_tabtools
program define _qa_iivw_ensure_tabtools
    version 16.0
    syntax , FROM(string)

    capture which regtab
    if _rc {
        capture ado uninstall tabtools
        quietly net install tabtools, from("`from'") replace
        discard
    }

    capture which regtab
    if _rc {
        display as error "regtab is unavailable after tabtools install"
        display as error "  from: `from'"
        exit 111
    }
end

**# Release Metadata And Static Surface

local ++test_count
capture noisily {
    local version "1.2.3"
    local ado_date "2026/05/26"
    local sthlp_date "26may2026"
    local iso_date "2026-05-26"
    local pkg_date "20260526"

    _qa_iivw_must_contain, file("`pkg_dir'/README.md") ///
        pattern("**Version `version'** | `iso_date'")
    _qa_iivw_must_contain, file("`pkg_dir'/iivw.pkg") ///
        pattern("d Distribution-Date: `pkg_date'")
    _qa_iivw_must_contain, file("`pkg_dir'/iivw.pkg") ///
        pattern("d Author: Timothy P Copeland, Karolinska Institutet")

    _qa_iivw_must_contain, file("`pkg_dir'/stata.toc") ///
        pattern("v 3")
    _qa_iivw_must_contain, file("`pkg_dir'/stata.toc") ///
        pattern("d Stata-Tools: iivw")
    _qa_iivw_must_contain, file("`pkg_dir'/stata.toc") ///
        pattern("d Timothy P Copeland, Karolinska Institutet")
    _qa_iivw_must_contain, file("`pkg_dir'/stata.toc") ///
        pattern("d https://github.com/tpcopeland/Stata-Tools")
    _qa_iivw_must_contain, file("`pkg_dir'/stata.toc") ///
        pattern("p iivw")

    foreach pair in ///
        "iivw.ado|iivw" ///
        "iivw_weight.ado|iivw_weight" ///
        "iivw_balance.ado|iivw_balance" ///
        "iivw_fit.ado|iivw_fit" ///
        "iivw_exogtest.ado|iivw_exogtest" ///
        "iivw_diagnose.ado|iivw_diagnose" ///
        "_iivw_get_settings.ado|_iivw_get_settings" ///
        "_iivw_check_weighted.ado|_iivw_check_weighted" ///
        "_iivw_bs_estimate.ado|_iivw_bs_estimate" {
        gettoken file cmd : pair, parse("|")
        local cmd = substr("`cmd'", 2, .)
        _qa_iivw_must_contain, file("`pkg_dir'/`file'") ///
            pattern("*! `cmd' Version `version'  `ado_date'")
        _qa_iivw_must_contain, file("`pkg_dir'/`file'") ///
            pattern("*! Author: Timothy P Copeland, Karolinska Institutet")
        _qa_iivw_must_not_contain, file("`pkg_dir'/`file'") ///
            pattern("*! Department of Clinical Neuroscience")
    }

    foreach help in iivw iivw_weight iivw_balance iivw_fit iivw_exogtest iivw_diagnose {
        _qa_iivw_must_contain, file("`pkg_dir'/`help'.sthlp") ///
            pattern("{* *! version `version'  `sthlp_date'}")
        _qa_iivw_must_contain, file("`pkg_dir'/`help'.sthlp") ///
            pattern("{pstd}Timothy P Copeland, Karolinska Institutet{p_end}")
        _qa_iivw_must_not_contain, file("`pkg_dir'/`help'.sthlp") ///
            pattern("{pstd}Department of Clinical Neuroscience{p_end}")
        _qa_iivw_must_contain, file("`pkg_dir'/`help'.sthlp") ///
            pattern("Version `version', `iso_date'")
    }
}
if _rc == 0 {
    display as result "  PASS: release metadata and version strings are synchronized"
    local ++pass_count
}
else {
    display as error "  FAIL: release metadata/version sync (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local package_files ///
        iivw.ado ///
        iivw.sthlp ///
        iivw_weight.ado ///
        iivw_weight.sthlp ///
        iivw_balance.ado ///
        iivw_balance.sthlp ///
        iivw_fit.ado ///
        iivw_fit.sthlp ///
        iivw_exogtest.ado ///
        iivw_exogtest.sthlp ///
        iivw_diagnose.ado ///
        iivw_diagnose.sthlp ///
        _iivw_get_settings.ado ///
        _iivw_check_weighted.ado ///
        _iivw_bs_estimate.ado

    foreach file of local package_files {
        capture confirm file "`pkg_dir'/`file'"
        if _rc {
            display as error "missing shipped file: `file'"
            exit 601
        }
        _qa_iivw_must_contain, file("`pkg_dir'/iivw.pkg") pattern("f `file'")
    }
}
if _rc == 0 {
    display as result "  PASS: iivw.pkg lists all runtime and help files"
    local ++pass_count
}
else {
    display as error "  FAIL: iivw.pkg completeness (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local shipped_files ///
        README.md ///
        iivw.pkg ///
        stata.toc ///
        iivw.ado ///
        iivw.sthlp ///
        iivw_weight.ado ///
        iivw_weight.sthlp ///
        iivw_balance.ado ///
        iivw_balance.sthlp ///
        iivw_fit.ado ///
        iivw_fit.sthlp ///
        iivw_exogtest.ado ///
        iivw_exogtest.sthlp ///
        iivw_diagnose.ado ///
        iivw_diagnose.sthlp ///
        _iivw_get_settings.ado ///
        _iivw_check_weighted.ado ///
        _iivw_bs_estimate.ado ///
        demo/demo_iivw.do

    local slash = char(47)
    local dot = char(46)
    local dash = char(45)
    local tilde = char(126)
    local dev_leak "Stata`dash'Dev"
    local home_leak "`slash'home`slash'"
    local codex_leak "`dot'codex"
    local claude_leak "`dot'claude"
    local codex_home "`tilde'`slash'`dot'codex"
    local claude_home "`tilde'`slash'`dot'claude"

    foreach file of local shipped_files {
        foreach pattern in "`dev_leak'" "`home_leak'" "`codex_leak'" ///
            "`claude_leak'" "`codex_home'" "`claude_home'" {
            _qa_iivw_must_not_contain, file("`pkg_dir'/`file'") pattern("`pattern'")
        }
    }
}
if _rc == 0 {
    display as result "  PASS: shipped user-facing files have no dev-path leaks"
    local ++pass_count
}
else {
    display as error "  FAIL: self-contained release leak check (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local allowed_logs ///
        run_all.log ///
        test_iivw_release_adversarial.log ///
        test_iivw_balance.log ///
        test_iivw_performance.log ///
        test_iivw_v105_regressions.log ///
        test_iivw_v106_regressions.log ///
        test_iivw_final_adversarial.log ///
        test_iivw_fit_unweighted.log ///
        test_iivw_exogtest.log ///
        test_iivw_diagnose.log ///
        test_iivw_diagnostic_workflow.log ///
        test_iivw_exogtest_adversarial.log ///
        validation_iivw_diagnostics_known_answers.log

    foreach folder in "`pkg_dir'" "`pkg_dir'/qa" {
        foreach ext in log smcl dta xlsx {
            local debris : dir "`folder'" files "*.`ext'"
            foreach f of local debris {
                local allowed = 0
                foreach allowed_log of local allowed_logs {
                    if "`f'" == "`allowed_log'" {
                        local allowed = 1
                    }
                }
                if !`allowed' {
                    display as error "runtime artifact found: `folder'/`f'"
                    exit 9
                }
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: no root/qa runtime debris from release QA"
    local ++pass_count
}
else {
    display as error "  FAIL: generated artifact hygiene (error `=_rc')"
    local ++fail_count
}

**# Isolated Install Smoke

local ++test_count
capture noisily {
    capture mkdir "`plus_dir'"
    if _rc exit _rc
    capture mkdir "`personal_dir'"
    if _rc exit _rc
    capture mkdir "`work_dir'"
    if _rc exit _rc

    sysdir set PLUS "`plus_dir'"
    sysdir set PERSONAL "`personal_dir'"
    cd "`work_dir'"

    capture ado uninstall iivw
    discard

    quietly net install iivw, from("`pkg_dir'") replace
    _qa_iivw_ensure_tabtools, from("`repo_dir'/tabtools")
    discard

    foreach file in ///
        iivw.ado ///
        iivw_weight.ado ///
        iivw_fit.ado ///
        iivw_exogtest.ado ///
        iivw_diagnose.ado ///
        _iivw_get_settings.ado ///
        _iivw_check_weighted.ado ///
        _iivw_bs_estimate.ado ///
        regtab.ado ///
        tabtools.ado ///
        _tabtools_common.ado ///
        iivw.sthlp ///
        iivw_weight.sthlp ///
        iivw_fit.sthlp ///
        iivw_exogtest.sthlp ///
        iivw_diagnose.sthlp {
        findfile `file'
        assert strpos("`r(fn)'", "`plus_dir'") > 0
    }

    findfile iivw.ado
    local install_path "`r(fn)'"

    ado uninstall iivw
    discard
    capture confirm file "`install_path'"
    assert _rc != 0

    quietly net install iivw, from("`pkg_dir'") replace
    quietly net install iivw, from("`pkg_dir'") replace
    discard

    findfile iivw.ado
    assert strpos("`r(fn)'", "`plus_dir'") > 0

    findfile regtab.ado
    assert strpos("`r(fn)'", "`plus_dir'") > 0
    local tabtools_ready = 1

    local installed_ready = 1
}
if _rc == 0 {
    display as result "  PASS: isolated net install plus tabtools/regtab dependency smoke"
    local ++pass_count
}
else {
    display as error "  FAIL: isolated net install/tabtools smoke (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    if `installed_ready' != 1 exit 9
    if `tabtools_ready' != 1 exit 9

    discard
    _qa_iivw_doc_data

    iivw
    assert r(n_commands) == 5
    assert "`r(version)'" == "1.2.3"

    iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog
    assert "`r(weighttype)'" == "iivw"
    assert r(N) == 320
    assert r(n_ids) == 80
    confirm variable _iivw_iw
    confirm variable _iivw_weight
    iivw_balance, nolog
    assert r(N) == 320
    assert "`r(weighttype)'" == "iivw"

    capture program drop _iivw_check_weighted
    capture program drop _iivw_get_settings
    iivw_fit edss treated edss_bl, model(gee) timespec(linear) nolog
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_model)'" == "gee"
    assert "`e(iivw_weighttype)'" == "iivw"

    capture program drop _iivw_bs_estimate
    iivw_fit edss treated edss_bl, bootstrap(2) nolog replace
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert e(N_reps) == 2
}
if _rc == 0 {
    display as result "  PASS: public commands and helper auto-loading work after install"
    local ++pass_count
}
else {
    display as error "  FAIL: public command/helper installed-user smoke (error `=_rc')"
    local ++fail_count
}

**# Documentation Examples After Install

local ++test_count
capture noisily {
    if `installed_ready' != 1 exit 9

    discard
    _qa_iivw_doc_data

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) nolog
    summarize _iivw_weight, detail
    iivw_fit edss treated edss_bl, model(gee) timespec(linear)

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        treat(treated) treat_cov(age sex edss_bl) ///
        truncate(1 99) replace nolog

    iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)

    iivw_fit edss treated age sex edss_bl, ///
        model(gee) timespec(ns(3)) interaction(treated) replace

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) replace nolog
    iivw_fit edss treatment edss_bl, ///
        categorical(treatment) timespec(ns(3)) interaction(treatment) replace

    iivw_fit edss treated edss_bl, bootstrap(2) nolog replace

    collect clear
    iivw_fit edss treated edss_bl, model(gee) nolog replace collect
    which regtab
    regtab, xlsx(iivw_results.xlsx) sheet(Results) title(IIW Analysis) stats(n)
    capture confirm file "`work_dir'/iivw_results.xlsx"
    assert _rc == 0
    erase "`work_dir'/iivw_results.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README and iivw.sthlp worked examples run after install"
    local ++pass_count
}
else {
    display as error "  FAIL: README/iivw.sthlp examples after install (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    if `installed_ready' != 1 exit 9
    if `tabtools_ready' != 1 exit 9

    discard
    _qa_iivw_doc_data

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) nolog
    summarize _iivw_weight, detail

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        treat(treated) treat_cov(age sex edss_bl) truncate(1 99) replace nolog

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) replace nolog
    confirm variable edss_lag1
    confirm variable relapse_lag1

    iivw_weight, id(id) time(days) visit_cov(edss_bl) lagvars(edss) ///
        generate(w_) replace nolog
    confirm variable w_iw
    confirm variable w_weight

    iivw_weight, id(id) time(days) treat(treated) ///
        treat_cov(age sex edss_bl) wtype(iptw) replace nolog
    assert "`r(weighttype)'" == "iptw"
    confirm variable _iivw_tw

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        stabcov(treated) replace nolog
    assert "`r(weighttype)'" == "iivw"

    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        efron replace nolog
    assert "`r(weighttype)'" == "iivw"
}
if _rc == 0 {
    display as result "  PASS: iivw_weight.sthlp examples run after install"
    local ++pass_count
}
else {
    display as error "  FAIL: iivw_weight.sthlp examples after install (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    if `installed_ready' != 1 exit 9

    discard
    _qa_iivw_doc_data
    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) nolog

    iivw_fit edss treated edss_bl, model(gee) timespec(linear)
    iivw_fit edss treated edss_bl, timespec(quadratic) replace
    iivw_fit edss treated edss_bl, timespec(ns(3)) replace
    iivw_fit edss treated edss_bl, timespec(linear) interaction(treated) replace
    iivw_fit edss treated edss_bl, bootstrap(2) nolog replace
    iivw_fit relapse treated edss_bl, family(binomial) link(logit) replace

    collect clear
    iivw_fit edss treated edss_bl, model(gee) nolog replace collect
    which regtab
    regtab, xlsx(iivw_results.xlsx) sheet(Results) title(IIW Analysis) stats(n)
    capture confirm file "`work_dir'/iivw_results.xlsx"
    assert _rc == 0
    erase "`work_dir'/iivw_results.xlsx"

    iivw_fit edss treated edss_bl, timespec(ns(3)) interaction(treated) replace
    iivw_fit edss treated age edss_bl, timespec(quadratic) interaction(treated age) replace

    collect clear
    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        truncate(1 99) replace nolog
    iivw_fit edss treated edss_bl, model(gee) nolog collect
    iivw_weight, id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        treat(treated) treat_cov(age sex edss_bl) truncate(1 99) replace nolog
    iivw_fit edss treated edss_bl, model(gee) nolog replace collect
    which regtab
    regtab, xlsx(iivw_results.xlsx) sheet(Comparison) ///
        models(IIW \ FIPTIW) title(IIW vs FIPTIW) stats(n) noint
    capture confirm file "`work_dir'/iivw_results.xlsx"
    assert _rc == 0
    erase "`work_dir'/iivw_results.xlsx"

    iivw_fit edss treatment edss_bl, categorical(treatment) replace
    iivw_fit edss treatment edss_bl, categorical(treatment) basecat(2) replace
    iivw_fit edss treatment edss_bl, timespec(ns(3)) ///
        categorical(treatment) interaction(treatment) replace
    iivw_fit edss treated edss_bl, timespec(none) replace

    if c(stata_version) >= 17 {
        iivw_fit edss treated edss_bl, model(mixed) replace
    }
    else {
        display as text "note: Stata < 17; documented mixed-model example not run"
    }
}
if _rc == 0 {
    display as result "  PASS: iivw_fit.sthlp examples run after install"
    local ++pass_count
}
else {
    display as error "  FAIL: iivw_fit.sthlp examples after install (error `=_rc')"
    local ++fail_count
}

**# Cleanup And Summary

capture ado uninstall tabtools
capture ado uninstall iivw
discard
capture cd "`old_cwd'"
capture sysdir set PLUS "`old_plus'"
capture sysdir set PERSONAL "`old_personal'"

capture confirm file "`work_dir'/iivw_results.xlsx"
if _rc == 0 erase "`work_dir'/iivw_results.xlsx"

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_release_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_release_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"

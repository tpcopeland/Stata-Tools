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
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"
capture confirm file "`pkg_dir'/iivw.pkg"
if _rc {
    display as error "Run this test from the iivw/qa directory"
    exit 601
}

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

* Flag any help-file line on which SMCL braces do not balance -- i.e. a
* directive left open across a newline, which the Viewer renders literally.
* Sets `smcl_bad' to the number of offending lines.
capture mata: mata drop _iivw_smcl_scan()
mata:
void _iivw_smcl_scan(string scalar pkg_dir)
{
    string vector files
    string scalar  path, line, s
    real scalar    f, fh, ln, nopen, nclose, bad

    files = ("iivw", "iivw_weight", "iivw_balance", "iivw_fit",
             "iivw_exogtest", "iivw_diagnose")
    bad = 0

    for (f = 1; f <= cols(files); f++) {
        path = pkg_dir + "/" + files[f] + ".sthlp"
        fh = fopen(path, "r")
        ln = 0
        while ((line = fget(fh)) != J(0, 0, "")) {
            ln++
            /* {c -(} and {c )-} are the SMCL escapes for a literal brace and
               are not directives; they must not count toward the balance. */
            s = subinstr(line, "{c -(}", "")
            s = subinstr(s, "{c )-}", "")
            nopen  = strlen(s) - strlen(subinstr(s, "{", ""))
            nclose = strlen(s) - strlen(subinstr(s, "}", ""))
            if (nopen != nclose) {
                printf("{err}  %s.sthlp:%f: unbalanced SMCL braces\n",
                       files[f], ln)
                printf("{err}    %s\n", line)
                bad++
            }
        }
        fclose(fh)
    }
    st_local("smcl_bad", strofreal(bad))
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
    * VERSION comes from the canonical iivw.ado header; every shipped file must
    * carry it in lockstep (asserted per-file below).
    *
    * DISTRIBUTION DATE comes from iivw.pkg, NOT from the iivw.ado header date.
    * These are different facts and they are allowed to differ: a doc-only
    * .sthlp render fix bumps the Distribution-Date and the README date badge
    * while every .ado -- and therefore every .ado header date -- is untouched
    * (CLAUDE.md, "Doc-only .sthlp render fixes bump the date, not the
    * version").  Deriving the expected date from iivw.ado made that legal state
    * fail this gate, which is how the gate, not the package, was wrong.
    *
    * The drift this gate exists to catch is preserved and is still asserted:
    *   - README's date badge must mirror the .pkg Distribution-Date exactly
    *     (the iivw/tabtools README release-date drift was a real defect);
    *   - the .pkg date must be a well-formed YYYYMMDD; and
    *   - the .pkg date may never be OLDER than the newest .ado header date,
    *     which is what a forgotten .pkg bump after a code change looks like.
    tempname _relvh
    file open `_relvh' using "`pkg_dir'/iivw.ado", read text
    file read `_relvh' _relvline
    file close `_relvh'
    local version ""
    local ado_date ""
    if regexm(`"`_relvline'"', "Version ([0-9.]+) +([0-9/]+)") {
        local version = regexs(1)
        local ado_date = regexs(2)
    }
    assert "`version'" != "" & "`ado_date'" != ""
    local ado_datenum = subinstr("`ado_date'", "/", "", .)
    * The flagship iivw.sthlp prose "Version X, <date>" line tracks the SOURCE
    * date (the .ado header), not the distribution date: a doc-only render fix
    * leaves it untouched by rule.  Only the README badge mirrors the .pkg.
    local ado_iso = subinstr("`ado_date'", "/", "-", .)

    tempname _relph
    local pkg_date ""
    file open `_relph' using "`pkg_dir'/iivw.pkg", read text
    file read `_relph' _relpline
    while r(eof) == 0 {
        if regexm(`"`_relpline'"', "^d Distribution-Date: ([0-9]+)$") {
            local pkg_date = regexs(1)
        }
        file read `_relph' _relpline
    }
    file close `_relph'
    * A malformed or absent Distribution-Date must fail loudly, not silently
    * leave `pkg_date' empty and make every date assertion below vacuous.
    assert strlen("`pkg_date'") == 8 & real("`pkg_date'") < .
    assert real("`pkg_date'") >= real("`ado_datenum'")
    local iso_date = substr("`pkg_date'", 1, 4) + "-" ///
        + substr("`pkg_date'", 5, 2) + "-" + substr("`pkg_date'", 7, 2)

    tempname _relsh
    file open `_relsh' using "`pkg_dir'/iivw.sthlp", read text
    file read `_relsh' _relsline
    file read `_relsh' _relsline
    file close `_relsh'
    local sthlp_date ""
    if regexm(`"`_relsline'"', "version [0-9.]+ +([0-9a-z]+)") {
        local sthlp_date = regexs(1)
    }
    assert "`sthlp_date'" != ""

    _qa_iivw_must_contain, file("`pkg_dir'/README.md") ///
        pattern("**Version `version'** | `iso_date'")
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
        "_iivw_bs_estimate.ado|_iivw_bs_estimate" ///
        "_iivw_bs_refit.ado|_iivw_bs_refit" ///
        "_iivw_reserve_names.ado|_iivw_reserve_names" ///
        "_iivw_require_converged.ado|_iivw_require_converged" ///
        "_iivw_weight_signature.ado|_iivw_weight_signature" ///
        "_iivw_export_table.ado|_iivw_export_table" {
        gettoken file cmd : pair, parse("|")
        local cmd = substr("`cmd'", 2, .)
        _qa_iivw_must_contain, file("`pkg_dir'/`file'") ///
            pattern("*! `cmd' Version `version'  `ado_date'")
        _qa_iivw_must_contain, file("`pkg_dir'/`file'") ///
            pattern("*! Author: Timothy P Copeland, Karolinska Institutet")
        _qa_iivw_must_not_contain, file("`pkg_dir'/`file'") ///
            pattern("*! Department of Clinical Neuroscience")
    }

    _qa_iivw_must_contain, file("`pkg_dir'/iivw_weight.ado") ///
        pattern("could not preserve active estimation results")
    _qa_iivw_must_contain, file("`pkg_dir'/iivw_weight.ado") ///
        pattern("could not restore active estimation results")

    * Author/affiliation checks apply to every help file...
    foreach help in iivw iivw_weight iivw_balance iivw_fit iivw_exogtest iivw_diagnose {
        _qa_iivw_must_contain, file("`pkg_dir'/`help'.sthlp") ///
            pattern("{pstd}Timothy P Copeland, Karolinska Institutet{p_end}")
        _qa_iivw_must_not_contain, file("`pkg_dir'/`help'.sthlp") ///
            pattern("{pstd}Department of Clinical Neuroscience{p_end}")
    }

    * ...but the package version lives only in the flagship iivw.sthlp.
    * Sub-command help files intentionally carry no version line (removed in
    * v1.7.3); the version is recorded once in iivw.sthlp plus the .pkg and README.
    _qa_iivw_must_contain, file("`pkg_dir'/iivw.sthlp") ///
        pattern("{* *! version `version'  `sthlp_date'}")
    _qa_iivw_must_contain, file("`pkg_dir'/iivw.sthlp") ///
        pattern("Version `version', `ado_iso'")
    foreach help in iivw_weight iivw_balance iivw_fit iivw_exogtest iivw_diagnose {
        _qa_iivw_must_not_contain, file("`pkg_dir'/`help'.sthlp") ///
            pattern("{* *! version")
    }

    _qa_iivw_must_contain, file("`pkg_dir'/iivw.sthlp") ///
        pattern("https://github.com/tpcopeland/Stata-Tools/tree/main/iivw/demo")
    _qa_iivw_must_not_contain, file("`pkg_dir'/iivw.sthlp") ///
        pattern("The package demo, {cmd:iivw/demo/demo_iivw.do}")
}
if _rc == 0 {
    display as result "  PASS: release metadata and version strings are synchronized"
    local ++pass_count
}
else {
    display as error "  FAIL: release metadata/version sync (error `=_rc')"
    local ++fail_count
}

* -----------------------------------------------------------------------------
* SMCL render integrity: no directive may span a newline
*
* An SMCL directive must open and close on ONE line.  Wrap a paragraph so that
* "{it:Mean-1" ends a line and "normalization}" begins the next, and Stata's
* Viewer does not render italics -- it prints the brace text literally and the
* markup leaks into the visible help page.  It is invisible in the source, it
* survives every content check the gate already runs (the words are all still
* there, in order), and it shipped: iivw_weight.sthlp carried exactly this
* defect at lines 565-566 in v2.0.0 and no test caught it.
*
* Detection: strip the two literal-brace escapes ({c -(} and {c )-}), then
* require the braces on each line to balance.  Verified to flag both halves of
* the shipped defect and to leave all six current help files clean.
* -----------------------------------------------------------------------------
* Done in Mata, not with `file read' + macros: a help-file line legitimately
* contains double quotes and unbalanced braces, and expanding one into a Stata
* string literal to count its characters corrupts the line (or errors, r(198)).
* Mata handles the bytes as data.
local ++test_count
capture noisily {
    mata: _iivw_smcl_scan("`pkg_dir'")
    assert `smcl_bad' == 0
}
if _rc == 0 {
    display as result "  PASS: all help files render without literal SMCL markup"
    local ++pass_count
}
else {
    display as error "  FAIL: SMCL render integrity (error `=_rc')"
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
        _iivw_bs_estimate.ado ///
        _iivw_bs_refit.ado ///
        _iivw_reserve_names.ado ///
        _iivw_require_converged.ado ///
        _iivw_weight_signature.ado ///
        _iivw_export_table.ado

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
        _iivw_bs_refit.ado ///
        _iivw_reserve_names.ado ///
        _iivw_require_converged.ado ///
        _iivw_weight_signature.ado ///
        _iivw_export_table.ado ///
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
    * Q6: this gate used to whitelist <suite>.log for EVERY .do in qa/, so the
    * 4 MB of license-bearing runtime logs it was supposed to catch were exactly
    * the files it declared clean. No suite writes a named log into the tree any
    * more (they stage to c(tmpdir)), so the only .log that can legitimately be
    * here is the batch log of the invocation currently running: run_all.log
    * under the runner, or this suite's own log when it is run standalone.
    * Anything else is debris and must be deleted before release.
    local allowed_logs run_all.log test_iivw_release_adversarial.log

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
                    display as error "  QA runs must not leave artifacts in the package tree."
                    display as error "  Cross-validation logs also carry the local Stata license"
                    display as error "  header, so they are sensitive debris, not just clutter."
                    display as error "  Delete it and re-run: erase `folder'/`f'"
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
        iivw_balance.ado ///
        iivw_fit.ado ///
        iivw_exogtest.ado ///
        iivw_diagnose.ado ///
        _iivw_get_settings.ado ///
        _iivw_check_weighted.ado ///
        _iivw_bs_estimate.ado ///
        _iivw_bs_refit.ado ///
        _iivw_reserve_names.ado ///
        _iivw_require_converged.ado ///
        _iivw_weight_signature.ado ///
        _iivw_export_table.ado ///
        regtab.ado ///
        tabtools.ado ///
        _tabtools_common.ado ///
        iivw.sthlp ///
        iivw_weight.sthlp ///
        iivw_balance.sthlp ///
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
    assert regexm("`r(version)'", "^[0-9]+\.[0-9]+\.[0-9]+$")

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss relapse) nolog
    assert "`r(weighttype)'" == "iivw"
    assert r(N) == 320
    assert r(n_ids) == 80
    confirm variable _iivw_iw
    confirm variable _iivw_weight
    iivw_balance, nolog
    assert r(N) == 320
    assert "`r(weighttype)'" == "iivw"
    iivw_balance, nolog xlsx(iivw_balance_export.xlsx) ///
        sheet(Balance) replace
    assert "`r(sheet)'" == "Balance"
    capture confirm file "`work_dir'/iivw_balance_export.xlsx"
    assert _rc == 0
    erase "`work_dir'/iivw_balance_export.xlsx"

    capture program drop _iivw_check_weighted
    capture program drop _iivw_get_settings
    iivw_fit edss treated edss_bl, model(gee) timespec(linear) nolog
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_model)'" == "gee"
    assert "`e(iivw_weighttype)'" == "iivw"

    capture program drop _iivw_bs_estimate
    capture program drop _iivw_bs_refit
    capture program drop _iivw_reserve_names
    capture program drop _iivw_require_converged
    capture program drop _iivw_weight_signature
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

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) nolog
    summarize _iivw_weight, detail
    iivw_fit edss treated edss_bl, model(gee) timespec(linear)

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        treat(treated) treat_cov(age sex edss_bl) ///
        truncate(1 99) replace nolog

    iivw_fit edss treated age sex edss_bl, model(gee) timespec(quadratic)

    iivw_fit edss treated age sex edss_bl, ///
        model(gee) timespec(ns(3)) interaction(treated) replace

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
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

    estimates clear
    regress edss days
    estimates store R_unweighted
    regress edss days [pw=_iivw_weight]
    estimates store R_weighted
    regress edss days edss_bl [pw=_iivw_weight]
    estimates store R_adjusted
    iivw_diagnose days, unweighted(R_unweighted) weighted(R_weighted) ///
        adjusted(R_adjusted) exogeneity(unknown) ///
        xlsx(iivw_diagnose_export.xlsx) sheet(Diagnostics) ///
        replace
    assert "`r(sheet)'" == "Diagnostics"
    capture confirm file "`work_dir'/iivw_diagnose_export.xlsx"
    assert _rc == 0
    erase "`work_dir'/iivw_diagnose_export.xlsx"
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

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) nolog
    summarize _iivw_weight, detail

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        treat(treated) treat_cov(age sex edss_bl) truncate(1 99) replace nolog

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) replace nolog
    confirm variable edss_lag1
    confirm variable relapse_lag1

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(edss_bl) lagvars(edss) ///
        generate(w_) replace nolog
    confirm variable w_iw
    confirm variable w_weight

    iivw_weight, id(id) time(days) treat(treated) ///
        treat_cov(age sex edss_bl) wtype(iptw) replace nolog
    assert "`r(weighttype)'" == "iptw"
    confirm variable _iivw_tw

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        stabcov(treated) replace nolog
    assert "`r(weighttype)'" == "iivw"

    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
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
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
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
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
        visit_cov(edss_bl age sex) lagvars(edss relapse) ///
        truncate(1 99) replace nolog
    iivw_fit edss treated edss_bl, model(gee) nolog collect
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) ///
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
        iivw_fit edss treated edss_bl, model(mixed) experimentalmixed replace
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
capture confirm file "`work_dir'/iivw_balance_export.xlsx"
if _rc == 0 erase "`work_dir'/iivw_balance_export.xlsx"
capture confirm file "`work_dir'/iivw_diagnose_export.xlsx"
if _rc == 0 erase "`work_dir'/iivw_diagnose_export.xlsx"
capture frame drop __rel_balance
capture frame drop __rel_diag

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_release_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_release_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"

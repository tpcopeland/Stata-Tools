* test_package_release.do - release gates: manifest, inventory, documentation, demo and baseline artifacts
* Consolidated in v1.7.0 from: test_baseline_artifacts.do, test_demo_artifacts.do, test_documentation_contracts.do, test_public_inventory_v136.do, test_review_package_contracts.do, test_review_v1013.do, test_ssc_release_gates.do

clear all
set more off
set varabbrev off
version 16.0

capture log close _pkgrel
log using "test_package_release.log", replace text name(_pkgrel)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
local checker "`tools_dir'/check_xlsx.py"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated: SSC release gates


**# Package integrity
**## Required package artifacts exist
capture noisily {
    foreach f in README.md stata.toc tabtools.pkg ///
        tabtools.ado tabtools.sthlp table1_tc.ado table1_tc.sthlp ///
        regtab.ado regtab.sthlp effecttab.ado effecttab.sthlp ///
        stratetab.ado stratetab.sthlp hrcomptab.ado hrcomptab.sthlp ///
        comptab.ado comptab.sthlp survtab.ado survtab.sthlp ///
        crosstab.ado crosstab.sthlp diagtab.ado diagtab.sthlp ///
        corrtab.ado corrtab.sthlp tabtools_tips.ado tabtools_tips.sthlp {
        confirm file "`pkg_dir'/`f'"
    }
}
if _rc == 0 {
    display as result "  PASS: required package artifacts exist"
    local ++pass_count
}
else {
    display as error "  FAIL: required package artifacts exist (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' artifacts"
}

**## stata.toc and .pkg metadata are present and well formed
capture noisily {
    tempname toc_fh pkg_fh

    file open `toc_fh' using "`pkg_dir'/stata.toc", read text
    file read `toc_fh' toc1
    file read `toc_fh' toc2
    file read `toc_fh' toc3
    file read `toc_fh' toc4
    file read `toc_fh' toc5
    file close `toc_fh'

    assert strtrim(`"`toc1'"') == "v 3"
    assert strtrim(`"`toc2'"') == "d Stata-Tools: tabtools"
    assert strtrim(`"`toc3'"') == "d Timothy P Copeland, Karolinska Institutet"
    assert strtrim(`"`toc4'"') == "d https://github.com/tpcopeland/Stata-Tools"
    assert strtrim(`"`toc5'"') == "p tabtools"

    local saw_date = 0
    local saw_author = 0
    file open `pkg_fh' using "`pkg_dir'/tabtools.pkg", read text
    file read `pkg_fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if regexm(`"`raw'"', "^d Distribution-Date: [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$") {
            local saw_date = 1
        }
        if strtrim(`"`raw'"') == "d Author: Timothy P Copeland, Karolinska Institutet" {
            local saw_author = 1
        }
        file read `pkg_fh' line
    }
    file close `pkg_fh'

    assert `saw_date' == 1
    assert `saw_author' == 1
}
if _rc == 0 {
    display as result "  PASS: stata.toc and .pkg metadata look well formed"
    local ++pass_count
}
else {
    display as error "  FAIL: stata.toc/.pkg metadata check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' metadata"
}

**## .pkg manifest matches shipped ado/sthlp files
capture noisily {
    local pkg_files ""
    tempname fh

    file open `fh' using "`pkg_dir'/tabtools.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if substr(`"`raw'"', 1, 2) == "f " {
            local pkg_file = strtrim(substr(`"`raw'"', 3, .))
            capture confirm file "`pkg_dir'/`pkg_file'"
            assert _rc == 0
            local pkg_files : list pkg_files | pkg_file
        }
        file read `fh' line
    }
    file close `fh'

    local ado_files : dir "`pkg_dir'" files "*.ado"
    local sthlp_files : dir "`pkg_dir'" files "*.sthlp"
    local dist_files : list ado_files | sthlp_files

    foreach f of local dist_files {
        local in_pkg : list f in pkg_files
        assert `in_pkg'
    }

    local n_pkg : word count `pkg_files'
    local n_dist : word count `dist_files'
    assert `n_pkg' == `n_dist'
}
if _rc == 0 {
    display as result "  PASS: .pkg manifest matches shipped ado/sthlp files"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg manifest completeness (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' pkg_manifest"
}

**## Shipped text artifacts do not contain dev-only paths or legacy repo refs
capture noisily {
    * Distribution surface: what installs/ships to users, plus the demo doc.
    * Zero tolerance: any dev-only token is a release blocker here.
    local ship_files "README.md stata.toc tabtools.pkg demo/demo_tabtools.do"

    local root_ado : dir "`pkg_dir'" files "*.ado"
    foreach f of local root_ado {
        local ship_files `"`ship_files' `f'"'
    }

    local root_sthlp : dir "`pkg_dir'" files "*.sthlp"
    foreach f of local root_sthlp {
        local ship_files `"`ship_files' `f'"'
    }

    * QA tooling is also self-contained. This release gate test itself
    * builds dev-token probes below, so it is excluded from the scanned set.
    local qa_files "qa/README.md qa/run_all.do qa/crossval_tabtools_companion.R qa/baseline/baseline_manifest.tsv"
    foreach ext in do py R md {
        local rootfiles : dir "`pkg_dir'/qa" files "*.`ext'"
        foreach f of local rootfiles {
            if "`f'" == "test_package_release.do" continue
            local qa_files `"`qa_files' qa/`f'"'
        }
        local toolfiles : dir "`pkg_dir'/qa/tools" files "*.`ext'"
        foreach f of local toolfiles {
            local qa_files `"`qa_files' qa/tools/`f'"'
        }
    }

    local devref_count = 0
    local home_user "/home/"
    local home_user "`home_user'tpcopeland/"
    local tools_ref "~/"
    local tools_ref "`tools_ref'Stata-Tools"
    local dev_name "Stata"
    local dev_suffix "-D"
    local dev_suffix "`dev_suffix'ev"
    local dev_name "`dev_name'`dev_suffix'"
    local dev_ref "~/"
    local dev_ref "`dev_ref'`dev_name'"
    local codex_ref ".codex"
    local codex_ref "`codex_ref'/skills/"
    local examples_ref "_"
    local examples_ref "`examples_ref'examples/"
    local slash_dev "/"
    local slash_dev "`slash_dev'`dev_name'"
    local patterns_ship "`home_user'|`tools_ref'|`dev_ref'|`codex_ref'|`examples_ref'|`slash_dev'"
    local patterns_qa   "`home_user'|`tools_ref'|`dev_ref'|`codex_ref'|`examples_ref'|`slash_dev'"
    tempfile _grep_out
    foreach relpath of local ship_files {
        capture confirm file "`pkg_dir'/`relpath'"
        if _rc continue

        shell grep -cE "`patterns_ship'" "`pkg_dir'/`relpath'" > "`_grep_out'" 2>/dev/null
        tempname gfh
        file open `gfh' using "`_grep_out'", read text
        file read `gfh' _gline
        file close `gfh'
        if real("`_gline'") > 0 {
            display as error "  DEV REF (shipped): `relpath'"
            local ++devref_count
        }
    }
    foreach relpath of local qa_files {
        capture confirm file "`pkg_dir'/`relpath'"
        if _rc continue

        shell grep -cE "`patterns_qa'" "`pkg_dir'/`relpath'" > "`_grep_out'" 2>/dev/null
        tempname gfhqa
        file open `gfhqa' using "`_grep_out'", read text
        file read `gfhqa' _gline
        file close `gfhqa'
        if real("`_gline'") > 0 {
            display as error "  DEV REF (qa): `relpath'"
            local ++devref_count
        }
    }

    assert `devref_count' == 0
}
if _rc == 0 {
    display as result "  PASS: shipped text artifacts are free of dev-only paths"
    local ++pass_count
}
else {
    display as error "  FAIL: shipped text artifacts include dev-only paths (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' dev_refs"
}

**## Dev-path gate discrimination — forbidden tokens flagged everywhere
* Locks in the release contract: shipped files and QA tooling are both
* self-contained. Without this guard, a future scan-pattern edit could
* silently weaken the gate.
capture noisily {
    * Rebuild the token pieces (kept split so this file's own scan stays clean).
    local home_user "/home/"
    local home_user "`home_user'tpcopeland/"
    local tools_ref "~/"
    local tools_ref "`tools_ref'Stata-Tools"
    local dev_name "Stata"
    local dev_suffix "-D"
    local dev_suffix "`dev_suffix'ev"
    local dev_name "`dev_name'`dev_suffix'"
    local dev_ref "~/"
    local dev_ref "`dev_ref'`dev_name'"
    local codex_ref ".codex"
    local codex_ref "`codex_ref'/skills/"
    local examples_ref "_"
    local examples_ref "`examples_ref'examples/"
    local slash_dev "/"
    local slash_dev "`slash_dev'`dev_name'"
    local patterns_ship "`home_user'|`tools_ref'|`dev_ref'|`codex_ref'|`examples_ref'|`slash_dev'"
    local patterns_qa   "`home_user'|`tools_ref'|`dev_ref'|`codex_ref'|`examples_ref'|`slash_dev'"

    * Probe lines synthesised from the split tokens (never literals). Each mirrors
    * how the real source text would read, so the scan sees realistic content.
    local probe_machine "local p `home_user'pkg/foo.ado"
    local probe_tilde   "local p `dev_ref'/tool/check_xlsx.py"
    local probe_tools   "local p `tools_ref'/tabtools/x.do"
    local probe_shim    "local checker DIR`slash_dev'/tool/check_xlsx.py"

    tempfile _probe _gout
    foreach probe in machine tilde tools shim {
        tempname pfh
        file open `pfh' using "`_probe'", write replace text
        file write `pfh' `"`probe_`probe''"' _n
        file close `pfh'
        foreach scan in ship qa {
            shell grep -cE "`patterns_`scan''" "`_probe'" > "`_gout'" 2>/dev/null
            tempname gfh
            file open `gfh' using "`_gout'", read text
            file read `gfh' _gl
            file close `gfh'
            local cnt_`probe'_`scan' = real("`_gl'")
        }
    }

    * Forbidden tokens must be caught by BOTH the shipped and qa scans.
    assert `cnt_machine_ship' > 0 & `cnt_machine_qa' > 0
    assert `cnt_tilde_ship'   > 0 & `cnt_tilde_qa'   > 0
    assert `cnt_tools_ship'   > 0 & `cnt_tools_qa'   > 0
    * A macro-ref plus bare dev-repo token is blocked in both scans.
    assert `cnt_shim_ship' > 0
    assert `cnt_shim_qa'   > 0
}
if _rc == 0 {
    display as result "  PASS: dev-path gate flags forbidden tokens in shipped files and qa"
    local ++pass_count
}
else {
    display as error "  FAIL: dev-path gate discrimination (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' dev_gate_discrimination"
}

**## tabtools.ado package version literal matches the header version
capture noisily {
    tempname ado_fh
    local header_version ""
    local package_version ""

    file open `ado_fh' using "`pkg_dir'/tabtools.ado", read text
    file read `ado_fh' line
    while r(eof) == 0 {
        if `"`header_version'"' == "" & strpos(`"`line'"', "Version ") > 0 {
            local header_tail = subinstr(`"`line'"', "Version ", "", 1)
            local header_version = word(`"`header_tail'"', 3)
        }
        if `"`package_version'"' == "" & strpos(`"`line'"', "_package_version") > 0 {
            local package_version = subinstr(`"`line'"', "local _package_version ", "", 1)
            local package_version = subinstr(`"`package_version'"', char(34), "", .)
            local package_version = strtrim(`"`package_version'"')
        }
        file read `ado_fh' line
    }
    file close `ado_fh'

    assert `"`header_version'"' != ""
    assert `"`package_version'"' != ""
    assert `"`header_version'"' == `"`package_version'"'
}
if _rc == 0 {
    display as result "  PASS: tabtools.ado header and package version literal match"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools.ado version synchronization (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tabtools_version_sync"
}

**# Fresh-install discoverability
**## Public commands resolve after net install
capture noisily {
    foreach cmd in tabtools table1_tc regtab effecttab stratetab hrcomptab ///
        comptab survtab crosstab diagtab corrtab {
        which `cmd'
    }
}
if _rc == 0 {
    display as result "  PASS: public commands resolve after fresh install"
    local ++pass_count
}
else {
    display as error "  FAIL: public command discoverability (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' which"
}

**## Bundled helper ado files are on adopath
capture noisily {
    foreach helper in _tabtools_common.ado {
        findfile `helper'
    }
}
if _rc == 0 {
    display as result "  PASS: bundled helper ado files resolve after install"
    local ++pass_count
}
else {
    display as error "  FAIL: bundled helper ado files resolve after install (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' helpers"
}

**## Retired refactor helpers are not shipped
capture noisily {
    foreach helper in _tabtools_guard.ado _tabtools_settings.ado ///
        _tabtools_table_spec.ado _tabtools_render_excel.ado ///
        _tabtools_export.ado _tabtools_collect_bridge.ado {
        capture confirm file "`pkg_dir'/`helper'"
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: retired refactor helpers are absent from the source tree"
    local ++pass_count
}
else {
    display as error "  FAIL: retired refactor helpers still present in source tree (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' retired_helpers"
}

**# Documentation reality
**## README example: table1_tc runs as displayed
capture noisily {
    sysuse auto, clear
    capture erase "table1.xlsx"
    table1_tc price mpg weight rep78, by(foreign) ///
        xlsx(table1.xlsx) sheet("Table 1") ///
        title("Table 1. Vehicle Characteristics by Origin") ///
        smd zebra
    confirm file "table1.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README table1_tc example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README table1_tc example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_table1"
}

**## README example: regtab runs as displayed
capture noisily {
    sysuse auto, clear
    capture erase "regression.xlsx"
    generate byte expensive = (price > 6000)
    collect clear
    collect: logistic expensive mpg weight i.foreign
    regtab, xlsx(regression.xlsx) sheet("Logistic") ///
        title("Table 2. Predictors of High Price") ///
        noint boldp(0.05) zebra
    confirm file "regression.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README regtab example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README regtab example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_regtab"
}

**## README example: effecttab runs as displayed
capture noisily {
    webuse cattaneo2, clear
    capture erase "effects.xlsx"
    collect clear
    collect: teffects ipw (bweight) ///
        (mbsmoke mage medu mmarried fbaby, logit), ate
    effecttab, xlsx(effects.xlsx) sheet("ATE") ///
        effect("ATE") ///
        title("Average Treatment Effect on Birthweight") ///
        clean
    confirm file "effects.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README effecttab example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README effecttab example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_effecttab"
}

**## README example: comptab runs as displayed
capture noisily {
    sysuse auto, clear
    capture erase "composite.xlsx"
    capture frame drop m1
    capture frame drop m2
    generate byte expensive = (price > 6000)
    collect clear
    collect: logistic expensive i.foreign
    regtab, frame(m1) noint
    collect clear
    collect: logistic expensive i.foreign mpg weight
    regtab, frame(m2) noint
    comptab m1 m2, rownames("foreign \ foreign") ///
        xlsx(composite.xlsx) sheet("Models") ///
        title("Table 3. Association with Price (OR, 95% CI)") ///
        zebra
    confirm file "composite.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README comptab example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README comptab example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_comptab"
}

**## README example: crosstab and corrtab run as displayed
capture noisily {
    sysuse auto, clear
    capture erase "crosstab.xlsx"
    capture erase "corrtab.xlsx"
    generate byte expensive = (price > 6000)
    crosstab expensive foreign, or label ///
        xlsx(crosstab.xlsx) ///
        title("Price by Origin")
    confirm file "crosstab.xlsx"
    corrtab price mpg weight length, xlsx(corrtab.xlsx) ///
        lower title("Correlation Matrix")
    confirm file "corrtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README crosstab/corrtab example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README crosstab/corrtab example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_crosstab_corrtab"
}

**## README example: survtab and stratetab run as displayed
capture noisily {
    capture erase "survival.xlsx"
    capture erase "rates.xlsx"
    capture erase "rate_hienergy.dta"
    webuse drugtr, clear
    stset studytime, failure(died)
    survtab, times(5 10 15 20) by(drug) ///
        median riskset difference ///
        xlsx(survival.xlsx) sheet("KM") ///
        title("Survival by Treatment Group")
    confirm file "survival.xlsx"
    webuse diet, clear
    stset dox, failure(fail) origin(time dob) enter(time doe) ///
        scale(365.25) id(id)
    strate hienergy, per(1000) output(rate_hienergy, replace)
    stratetab, using(rate_hienergy) outcomes(1) ///
        xlsx(rates.xlsx) sheet("Rates") ///
        outlabels("CHD Death") explabels("Energy Intake") ///
        title("Incidence Rates per 1,000 Person-Years")
    confirm file "rates.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README survtab/stratetab example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README survtab/stratetab example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_surv_strate"
}

**## README example: diagtab runs as displayed
capture noisily {
    webuse lbw, clear
    capture erase "diagtab.xlsx"
    logit low age lwt smoke
    predict phat
    diagtab phat low, cutoff(0.4) auc ///
        xlsx(diagtab.xlsx) ///
        title("Diagnostic Accuracy: Low Birth Weight Prediction")
    confirm file "diagtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: README diagtab example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: README diagtab example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_diagtab"
}

**## regtab.sthlp example runs as displayed
capture noisily {
    webuse nhanes2, clear
    collect clear
    collect: logit diabetes age female i.race bmi highbp
    capture erase "regression.xlsx"
    regtab, xlsx(regression.xlsx) sheet("Diabetes") ///
        title("Odds Ratios for Diabetes") coef(OR)
    confirm file "regression.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab.sthlp example runs unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab.sthlp example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' regtab_sthlp"
}

**## tabtools.sthlp example returns expected filtered command list
capture noisily {
    tabtools, category(descriptive)
    assert r(n_commands) == 4
    assert strpos("`r(commands)'", "table1_tc") > 0
    assert strpos("`r(commands)'", "desctab") > 0
    assert strpos("`r(commands)'", "crosstab") > 0
    assert strpos("`r(commands)'", "corrtab") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools.sthlp category example behaves as documented"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools.sthlp category example (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tabtools_sthlp"
}

**## tabtools set/get/clear cycle behaves for help-file workflow
capture noisily {
    tabtools set clear
    tabtools set font "Times New Roman"
    assert "$TABTOOLS_FONT" == "Times New Roman"
    tabtools set fontsize 10
    assert "$TABTOOLS_FONTSIZE" == "10"
    tabtools set borderstyle academic
    assert "$TABTOOLS_BORDER" == "academic"
    tabtools get
    tabtools set clear
    assert "$TABTOOLS_FONT" == ""
    assert "$TABTOOLS_FONTSIZE" == ""
    assert "$TABTOOLS_BORDER" == ""
}
if _rc == 0 {
    display as result "  PASS: tabtools help-file set/get/clear workflow works"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools help-file set/get/clear workflow (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' set_get_clear"
}


**# Migrated: public command inventory


local public_cmds "tabtools table1_tc desctab regtab effecttab stratetab hrcomptab comptab survtab crosstab diagtab corrtab puttab stacktab simtab tabtools_tips"
local advertised_cmds "table1_tc desctab crosstab corrtab regtab effecttab stratetab survtab diagtab comptab hrcomptab puttab stacktab simtab tabtools tabtools_tips"

**# Public Inventory

capture noisily {
    local public_ado ""
    local root_ado : dir "`pkg_dir'" files "*.ado"
    foreach f of local root_ado {
        if substr("`f'", 1, 1) != "_" {
            local public_ado : list public_ado | f
        }
    }

    local n_public : word count `public_ado'
    assert `n_public' == 16

    foreach cmd of local public_cmds {
        local ado_file "`cmd'.ado"
        local help_file "`cmd'.sthlp"
        local has_ado : list ado_file in public_ado
        assert `has_ado'
        confirm file "`pkg_dir'/`help_file'"
    }
}
if _rc == 0 {
    display as result "  PASS: source tree has exact 16-command public inventory"
    local ++pass_count
}
else {
    display as error "  FAIL: source tree public inventory drifted (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' source_inventory"
}

capture noisily {
    foreach cmd of local public_cmds {
        which `cmd'
        findfile `cmd'.sthlp
    }
}
if _rc == 0 {
    display as result "  PASS: all public commands and help files resolve after net install"
    local ++pass_count
}
else {
    display as error "  FAIL: installed public command/help resolution (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' install_resolution"
}

capture noisily {
    tempname pkgfh
    local pkg_files ""
    file open `pkgfh' using "`pkg_dir'/tabtools.pkg", read text
    file read `pkgfh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if substr(`"`raw'"', 1, 2) == "f " {
            local pkg_file = strtrim(substr(`"`raw'"', 3, .))
            local pkg_files : list pkg_files | pkg_file
        }
        file read `pkgfh' line
    }
    file close `pkgfh'

    foreach cmd of local public_cmds {
        local ado_file "`cmd'.ado"
        local help_file "`cmd'.sthlp"
        local has_ado : list ado_file in pkg_files
        local has_help : list help_file in pkg_files
        assert `has_ado'
        assert `has_help'
    }
}
if _rc == 0 {
    display as result "  PASS: .pkg manifest ships every public command and help file"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg public command manifest completeness (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' pkg_public_manifest"
}

**# Dispatcher Contract

capture noisily {
    tabtools
    assert r(n_commands) == 16
    local commands " `r(commands)' "
    foreach cmd of local advertised_cmds {
        assert strpos("`commands'", " `cmd' ") > 0
    }
    tabtools, category(export)
    assert r(n_commands) == 2
    local export_commands " `r(commands)' "
    assert strpos("`export_commands'", " puttab ") > 0
    assert strpos("`export_commands'", " stacktab ") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools advertises 16 current commands"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools dispatcher inventory contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_inventory"
}


**# Migrated: documentation contracts

clear all
version 16.0

capture log close _doc_contracts
log using "test_documentation_contracts.log", replace text name(_doc_contracts)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local failed_tests ""

**# Documentation Contract Checks

capture noisily {
    tempname fh
    local saw_excel_alias 0

    file open `fh' using "`pkg_dir'/regtab.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "{cmd:regtab},") > 0 & ///
            strpos(`"`line'"', "{opt excel(filename)}") > 0 {
            local saw_excel_alias 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `saw_excel_alias' == 1
}
if _rc == 0 {
    display as result "  PASS: regtab syntax documents excel() alias"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab syntax documents excel() alias (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' regtab_excel_alias"
}

capture noisily {
    tempname fh
    local saw_optional_by 0

    file open `fh' using "`pkg_dir'/table1_tc.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "{opt table1_tc}") > 0 & ///
            strpos(`"`line'"', "[{cmd:,} {opt by(varname)} {it:options}]") > 0 {
            local saw_optional_by 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `saw_optional_by' == 1
}
if _rc == 0 {
    display as result "  PASS: table1_tc quick-start syntax shows optional by()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc quick-start syntax shows optional by() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' table1_optional_by"
}

capture noisily {
    tempfile grep_out
    shell grep -cE 'Repository Checkout Demo|not part of the net install payload' "`pkg_dir'/README.md" > "`grep_out'" 2>/dev/null
    tempname fh
    file open `fh' using "`grep_out'", read text
    file read `fh' line
    file close `fh'
    assert real("`line'") == 2
}
if _rc == 0 {
    display as result "  PASS: README labels demo as checkout-only"
    local ++pass_count
}
else {
    display as error "  FAIL: README labels demo as checkout-only (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_demo_scope"
}

foreach helpfile in stratetab hrcomptab {
    capture noisily {
        tempname fh
        local saw_sketch 0
        local saw_cookbook 0

        file open `fh' using "`pkg_dir'/`helpfile'.sthlp", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`line'"', "workflow sketches") > 0 local saw_sketch 1
            if strpos(`"`line'"', "tabtools_tips") > 0 local saw_cookbook 1
            file read `fh' line
        }
        file close `fh'

        assert `saw_sketch' == 1
        assert `saw_cookbook' == 1
    }
    if _rc == 0 {
        display as result "  PASS: `helpfile' examples are scoped as sketches"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `helpfile' examples are scoped as sketches (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `helpfile'_example_scope"
    }
}


**# Migrated: release manifest + installed-user contracts

local public_commands tabtools table1_tc desctab regtab effecttab stratetab ///
    hrcomptab comptab survtab crosstab diagtab corrtab puttab stacktab ///
    simtab tabtools_tips
local helper_files _tabtools_common.ado _tabtools_xlsx_write.ado ///
    _tabtools_xlsx_read.ado _tabtools_collect_render.ado ///
    _tabtools_markdown_write.ado _tabtools_simtab_ingest.ado ///
    _tabtools_xlsx_apply_styles.ado _tabtools_xlsx_build_styles.ado ///
    _tabtools_table1_fast_collect.ado

**# Release Manifest Contracts
**## .pkg explicitly ships every public command ado/help file and backend helper
capture noisily {
    local pkg_entries ""
    tempname fh
    file open `fh' using "`pkg_dir'/tabtools.pkg", read text
    file read `fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if substr(`"`raw'"', 1, 2) == "f " {
            local entry = strtrim(substr(`"`raw'"', 3, .))
            local pkg_entries : list pkg_entries | entry
        }
        file read `fh' line
    }
    file close `fh'

    foreach cmd of local public_commands {
        local ado_file "`cmd'.ado"
        local help_file "`cmd'.sthlp"
        local has_ado : list ado_file in pkg_entries
        local has_help : list help_file in pkg_entries
        assert `has_ado'
        assert `has_help'
    }
    foreach helper of local helper_files {
        local has_helper : list helper in pkg_entries
        assert `has_helper'
    }
}
if _rc == 0 {
    display as result "  PASS: .pkg ships every public command and backend helper"
    local ++pass_count
}
else {
    display as error "  FAIL: .pkg public command/helper manifest (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' pkg_manifest_public_surface"
}

**# Installed-User Contracts
**## Fresh install resolves every public command and backend helper
capture noisily {
    foreach cmd of local public_commands {
        which `cmd'
    }
    foreach helper of local helper_files {
        findfile `helper'
    }
}
if _rc == 0 {
    display as result "  PASS: fresh install resolves all public commands and helpers"
    local ++pass_count
}
else {
    display as error "  FAIL: fresh-install public command/helper resolution (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' installed_resolution"
}

**# Dispatcher And Documentation Contracts
**## tabtools dispatcher exposes the export category and its public commands
capture noisily {
    quietly tabtools, category(export)
    assert r(n_commands) == 2
    assert strpos("`r(commands)'", "puttab") > 0
    assert strpos("`r(commands)'", "stacktab") > 0

    quietly tabtools
    assert strpos("`r(categories)'", "export") > 0
    assert strpos("`r(commands)'", "puttab") > 0
    assert strpos("`r(commands)'", "stacktab") > 0
}
if _rc == 0 {
    display as result "  PASS: tabtools dispatcher exposes export category"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools export-category dispatcher contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' dispatcher_export"
}

**## tabtools.sthlp documents every dispatcher category returned by r(categories)
capture noisily {
    quietly tabtools
    local categories "`r(categories)'"

    tempname hf
    file open `hf' using "`pkg_dir'/tabtools.sthlp", read text
    file read `hf' line
    local help_text ""
    while r(eof) == 0 {
        local help_text `"`help_text' `line'"'
        file read `hf' line
    }
    file close `hf'

    foreach cat of local categories {
        assert strpos(`"`help_text'"', "{cmd:`cat'}") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: tabtools.sthlp documents returned categories"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools.sthlp returned-category documentation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' sthlp_categories"
}


**# Migrated: sthlp version consistency

**# 13. Version consistency across sthlp files (I1 regression)

**## 13a. EVERY .sthlp prose version line matches the .ado version
* Generalized in 1.8.x: §13a previously opened only tabtools.sthlp and matched
* solely "{bf:Version}", so stale prose versions in the other 15 help files
* slipped through (I1: simtab/stacktab read 1.8.0 while headers were 1.8.2).
* Now loops over all shipped .sthlp and accepts the three prose formats in use:
* "{bf:Version} X.Y.Z", "{pstd}Version X.Y.Z{p_end}", and bare "Version X.Y.Z".
* Each file must contribute at least one match, so a dropped or reformatted
* prose-version line fails loudly instead of going unchecked.
capture noisily {
    * Get .ado version from first line of tabtools.ado header
    tempname fh_ado
    local ado_version ""
    file open `fh_ado' using "`pkg_dir'/tabtools.ado", read text
    file read `fh_ado' line
    * First line: *! tabtools Version X.Y.Z  YYYY/MM/DD
    local ado_version = strtrim(word(`"`line'"', 4))
    file close `fh_ado'

    local sthlp_files : dir "`pkg_dir'" files "*.sthlp"
    foreach sf of local sthlp_files {
        tempname fh_ver
        local file_found = 0
        file open `fh_ver' using "`pkg_dir'/`sf'", read text
        file read `fh_ver' line
        while r(eof) == 0 {
            * Capital "Version" + X.Y.Z = a prose version line. The lowercase
            * header "{* *! version ...}" is skipped (regexm is case-sensitive).
            if regexm(`"`line'"', "Version[^0-9]*([0-9]+\.[0-9]+\.[0-9]+)") {
                local sthlp_version = regexs(1)
                assert "`sthlp_version'" == "`ado_version'"
                local file_found = 1
            }
            file read `fh_ver' line
        }
        file close `fh_ver'
        * Guard: this file must carry a prose version line that the scan matched.
        assert `file_found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS [13a]: all .sthlp prose versions match .ado version"
    local ++pass_count
}
else {
    display as error "  FAIL [13a]: .sthlp prose version mismatch/missing (rc=`=_rc')"
    local ++fail_count
}

* 13b removed in v1.7.0: tabtools_cheatsheet.sthlp was retired (merged into
* tabtools_tips), so its version-consistency check no longer applies.



**# Migrated: demo artifacts regenerate

* test_demo_artifacts.do - Run repo-only demo and verify produced artifacts

clear all
set more off
set varabbrev off
version 16.0


local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local repo_root = subinstr("`pkg_dir'", "/tabtools", "", 1)
local demo_dir "`pkg_dir'/demo"
local old_pwd "`c(pwd)'"

local skip_count = 0
local failed_tests ""

capture confirm file "`repo_root'/_data/cohort.dta"
local has_data = (_rc == 0)
capture confirm file "`repo_root'/tc_schemes/stata.toc"
local has_scheme = (_rc == 0)

if !`has_data' | !`has_scheme' {
    display as text "  SKIP: repo-only demo assets not available"
    local ++skip_count
}
else {
    **# Run Demo
    capture noisily {
        cd "`demo_dir'"
        do "demo_tabtools.do"
        cd "`old_pwd'"
    }
    local demo_rc = _rc
    capture cd "`old_pwd'"
    if `demo_rc' == 0 {
        display as result "  PASS: demo/demo_tabtools.do runs from demo directory"
        local ++pass_count
    }
    else {
        display as error "  FAIL: demo/demo_tabtools.do run (rc=`demo_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' demo_run"
    }

    **# Verify Artifacts
    capture noisily {
        local xlsx_files ///
            demo_table1.xlsx ///
            demo_desctab.xlsx ///
            demo_regtab.xlsx ///
            demo_regtab_models.xlsx ///
            demo_comptab.xlsx ///
            demo_effecttab.xlsx ///
            demo_stratetab.xlsx ///
            demo_corrtab.xlsx ///
            demo_crosstab.xlsx ///
            demo_diagtab.xlsx ///
            demo_survtab.xlsx ///
            demo_hrcomptab.xlsx ///
            demo_puttab.xlsx ///
            demo_stacktab.xlsx

        local actual_sheets 0
        confirm file "`checker'"
        assert "`python_cmd'" != ""
        foreach f of local xlsx_files {
            local artifact "`demo_dir'/`f'"
            confirm file "`artifact'"
            shell test -s "`artifact'"
            import excel using "`artifact'", describe
            local nsheets = r(N_worksheet)
            local actual_sheets = `actual_sheets' + `nsheets'
            forvalues s = 1/`nsheets' {
                local sheet_`s' `"`r(worksheet_`s')'"'
            }
            import excel "`artifact'", cellrange(A1:A1) clear

            forvalues s = 1/`nsheets' {
                import excel using "`artifact'", sheet(`"`sheet_`s''"') clear allstring
                foreach v of varlist _all {
                    quietly count if strpos(`v', "Table X.") > 0
                    assert r(N) == 0

                    quietly count if strpos(`v', "* p<0.05") > 0 ///
                        & strpos(substr(`v', strpos(`v', "* p<0.05") + 1, .), "* p<0.05") > 0
                    assert r(N) == 0

                    quietly count if strpos(`v', ",  ") > 0 ///
                        & strpos(`v', "(") > 0 & strpos(`v', ")") > 0
                    assert r(N) == 0
                }
            }

            tempfile width_status
            shell "`python_cmd'" "`checker'" "`artifact'" --all-col-widths-fit 1 4 ///
                --quiet --result-file "`width_status'"
            tempname widthfh
            file open `widthfh' using "`width_status'", read text
            file read `widthfh' width_line
            file close `widthfh'
            assert substr("`width_line'", 1, 4) == "PASS"
        }
        assert `actual_sheets' == 72
        tempfile readme_hit
        shell grep -F "(`actual_sheets' sheets total)" "`pkg_dir'/README.md" > "`readme_hit'"
        tempname readmefh
        file open `readmefh' using "`readme_hit'", read text
        file read `readmefh' readme_line
        assert r(eof) == 0
        file close `readmefh'

        confirm file "`demo_dir'/console_output.log"
        shell test -s "`demo_dir'/console_output.log"
        confirm file "`demo_dir'/console_output.md"
        shell test -s "`demo_dir'/console_output.md"
        tempfile setget_hit corrupt_hit
        shell grep -F "set and get" "`demo_dir'/console_output.md" > "`setget_hit'"
        tempname setfh
        file open `setfh' using "`setget_hit'", read text
        file read `setfh' setget_line
        assert r(eof) == 0
        file close `setfh'

        shell grep -F "and ." "`demo_dir'/console_output.md" > "`corrupt_hit'"
        tempname corruptfh
        file open `corruptfh' using "`corrupt_hit'", read text
        file read `corruptfh' corrupt_line
        assert r(eof) != 0
        file close `corruptfh'
    }
    if _rc == 0 {
        display as result "  PASS: demo workbooks and console output are readable, width-fit, and free of release text anomalies"
        local ++pass_count
    }
    else {
        display as error "  FAIL: demo artifact verification (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' demo_artifacts"
    }
}


**# Migrated: golden-output baseline digests

local baseline_dir "`qa_dir'/baseline"
local summary_dir "`baseline_dir'/summaries"
local manifest_file "`baseline_dir'/baseline_manifest.tsv"


* Assert a summarize_xlsx.py verdict file says PASS. Stata's `shell` does not
* propagate the tool's exit code to _rc, so the comparison result must be read
* from the --status-file the tool writes and asserted here.
capture program drop _assert_summary_status
program define _assert_summary_status
    args status_file
    capture confirm file "`status_file'"
    if _rc {
        display as error "summary status file not written: `status_file'"
        exit 459
    }
    tempname fh
    file open `fh' using "`status_file'", read text
    file read `fh' _line
    file close `fh'
    if substr("`_line'", 1, 4) != "PASS" {
        display as error "summary comparison failed: `_line'"
        exit 9
    }
end

**# T1: Manifest lists only passing, materialized baseline summary artifacts
capture noisily {
    capture confirm file "`manifest_file'"
    assert _rc == 0

    preserve
    import delimited "`manifest_file'", varnames(1) stringcols(_all) clear
    assert _N >= 15
    forvalues i = 1/`=_N' {
        assert status[`i'] == "PASS"
        assert xlsx[`i'] != ""
        assert summary_file[`i'] != ""
        local _summary = summary_file[`i']
        capture confirm file "`pkg_dir'/`_summary'"
        assert _rc == 0
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: T1 - baseline manifest summaries are present and PASS"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - baseline manifest has missing summaries or non-PASS rows (rc=`=_rc')"
    local ++fail_count
}

**# T2: Every summary carries a content-sensitive digest and never SKIP
capture noisily {
    preserve
    import delimited "`manifest_file'", varnames(1) stringcols(_all) clear
    forvalues i = 1/`=_N' {
        local _summary = "`pkg_dir'/" + summary_file[`i']
        tempname fh
        file open `fh' using "`_summary'", read text
        file read `fh' _header
        file read `fh' _row
        file close `fh'
        assert strpos(`"`_header'"', "content_digest") > 0
        assert strpos(`"`_header'"', "nonempty_text_count") > 0
        assert substr(`"`_row'"', 1, 4) == "PASS"
        assert strpos(`"`_row'"', "SKIP") == 0
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: T2 - baseline summaries include payload digests with no SKIP rows"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - baseline summaries are missing digest data or contain SKIP (rc=`=_rc')"
    local ++fail_count
}

**# T3: crosstab 2x2 current output matches baseline payload digest
capture noisily {
    local xlsx "`output_dir'/_baseline_crosstab_2x2.xlsx"
    local actual "`output_dir'/_baseline_crosstab_2x2.tsv"
    capture erase "`xlsx'"
    capture erase "`actual'"
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    crosstab outcome exposure, xlsx("`xlsx'") sheet("Cross2x2") ///
        title("Refactor Baseline: crosstab 2x2")
    local status "`output_dir'/_baseline_crosstab_2x2_status.txt"
    capture erase "`status'"
    shell `python_cmd' "`summary_tool'" "`xlsx'" --sheet "Cross2x2" ///
        --result-file "`actual'" ///
        --expect-file "`summary_dir'/crosstab_2x2_chi2.tsv" ///
        --compare-columns status sheet title max_row max_col n_merges nonempty_text_count content_digest ///
        --status-file "`status'"
    _assert_summary_status "`status'"
    capture erase "`status'"
}
if _rc == 0 {
    display as result "  PASS: T3 - crosstab baseline payload reproduces"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - crosstab baseline payload changed (rc=`=_rc')"
    local ++fail_count
}

**# T4: regtab single-model current output matches baseline payload digest
capture noisily {
    local xlsx "`output_dir'/_baseline_regtab_single.xlsx"
    local actual "`output_dir'/_baseline_regtab_single.tsv"
    capture erase "`xlsx'"
    capture erase "`actual'"
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    regtab, xlsx("`xlsx'") sheet("Single") title("Refactor Baseline: regtab single")
    local status "`output_dir'/_baseline_regtab_single_status.txt"
    capture erase "`status'"
    shell `python_cmd' "`summary_tool'" "`xlsx'" --sheet "Single" ///
        --result-file "`actual'" ///
        --expect-file "`summary_dir'/regtab_single_model.tsv" ///
        --compare-columns status sheet title max_row max_col n_merges nonempty_text_count content_digest ///
        --status-file "`status'"
    _assert_summary_status "`status'"
    capture erase "`status'"
}
if _rc == 0 {
    display as result "  PASS: T4 - regtab baseline payload reproduces"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - regtab baseline payload changed (rc=`=_rc')"
    local ++fail_count
}

**# T5: table1_tc current output matches baseline payload digest
capture noisily {
    local xlsx "`output_dir'/_baseline_table1_auto.xlsx"
    local actual "`output_dir'/_baseline_table1_auto.tsv"
    capture erase "`xlsx'"
    capture erase "`actual'"
    sysuse auto, clear
    table1_tc, by(foreign) vars(price auto \ mpg auto \ rep78 auto \ headroom auto) ///
        xlsx("`xlsx'") sheet("Auto") title("Refactor Baseline: table1 auto")
    local status "`output_dir'/_baseline_table1_auto_status.txt"
    capture erase "`status'"
    shell `python_cmd' "`summary_tool'" "`xlsx'" --sheet "Auto" ///
        --result-file "`actual'" ///
        --expect-file "`summary_dir'/table1_tc_autodetect.tsv" ///
        --compare-columns status sheet title max_row max_col n_merges nonempty_text_count content_digest ///
        --status-file "`status'"
    _assert_summary_status "`status'"
    capture erase "`status'"
}
if _rc == 0 {
    display as result "  PASS: T5 - table1_tc baseline payload reproduces"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - table1_tc baseline payload changed (rc=`=_rc')"
    local ++fail_count
}


**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _pkgrel
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pkgrel

*! test_package_release.do
*! Installed-user, documentation, dialog, menu, and demo release reality.

clear all
set varabbrev off
set more off
version 16.0

capture log close _all
quietly log using "test_package_release.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local qa_dir "$TVTOOLS_QA_DIR"
local pkg_dir "$TVTOOLS_QA_PKG_DIR"
local original_cwd "`c(pwd)'"

capture mata: mata drop _tvtools_release_file_has()
mata:
real scalar _tvtools_release_file_has(string scalar path, string scalar needle)
{
    real scalar fh, found
    string scalar line

    fh = fopen(path, "r")
    found = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, needle) > 0) found = 1
    }
    fclose(fh)
    return(found)
}
end

**# 1. All public commands and help files resolve from the isolated install

local ++test_count
capture noisily {
    foreach command in tvtools tvage tvband tvsplit tvpanel tvexpose tvmerge ///
        tvevent tvweight tvdiagnose {
        findfile `command'.ado
        assert strpos("`r(fn)'", "$TVTOOLS_QA_PLUS") == 1
        findfile `command'.sthlp
        assert strpos("`r(fn)'", "$TVTOOLS_QA_PLUS") == 1
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' public_install"
}

**# 2. Private helpers, dialogs, and menu setup resolve from the install

local ++test_count
capture noisily {
    foreach helper in _tvband_split _tvexpose_diagnose _tvexpose_mata ///
        _tvmerge_mata _tvtools_new_vallabel {
        findfile `helper'.ado
        assert strpos("`r(fn)'", "$TVTOOLS_QA_PLUS") == 1
    }
    foreach dialog in tvexpose tvmerge tvevent {
        findfile `dialog'.dlg
        assert strpos("`r(fn)'", "$TVTOOLS_QA_PLUS") == 1
    }
    confirm file "`pkg_dir'/tvtools_menu_setup.do"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' support_install"
}

**# 3. Package f-lines exactly match the distribution surface

local ++test_count
capture noisily {
    local pkg_files ""
    tempname pkg_fh
    file open `pkg_fh' using "`pkg_dir'/tvtools.pkg", read text
    file read `pkg_fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if substr(`"`raw'"', 1, 2) == "f " {
            local pkg_file = strtrim(substr(`"`raw'"', 3, .))
            confirm file "`pkg_dir'/`pkg_file'"
            local pkg_files : list pkg_files | pkg_file
        }
        file read `pkg_fh' line
    }
    file close `pkg_fh'

    local ado_files : dir "`pkg_dir'" files "*.ado"
    local help_files : dir "`pkg_dir'" files "*.sthlp"
    local dialog_files : dir "`pkg_dir'" files "*.dlg"
    local dist_files : list ado_files | help_files
    local dist_files : list dist_files | dialog_files
    local menu_file tvtools_menu_setup.do
    local dist_files : list dist_files | menu_file
    foreach file of local dist_files {
        local listed : list file in pkg_files
        assert `listed'
    }
    local n_pkg : word count `pkg_files'
    local n_dist : word count `dist_files'
    assert `n_pkg' == `n_dist'
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' pkg_inventory"
}

**# 4. Release metadata are canonical and shipped files are self-contained

local ++test_count
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
    assert strtrim(`"`toc2'"') == "d Stata-Tools: tvtools"
    assert strtrim(`"`toc3'"') == ///
        "d Timothy P Copeland, Karolinska Institutet"
    assert strtrim(`"`toc4'"') == ///
        "d https://github.com/tpcopeland/Stata-Tools"
    assert strtrim(`"`toc5'"') == "p tvtools"

    local saw_date = 0
    local saw_author = 0
    file open `pkg_fh' using "`pkg_dir'/tvtools.pkg", read text
    file read `pkg_fh' line
    while r(eof) == 0 {
        local raw = strtrim(`"`line'"')
        if regexm(`"`raw'"', ///
            "^d Distribution-Date: [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$") ///
            local saw_date = 1
        if `"`raw'"' == ///
            "d Author: Timothy P Copeland, Karolinska Institutet" ///
            local saw_author = 1
        file read `pkg_fh' line
    }
    file close `pkg_fh'
    assert `saw_date' & `saw_author'

    local ship_files README.md stata.toc tvtools.pkg ///
        demo/demo_tvtools.do
    foreach extension in ado sthlp dlg do {
        local files : dir "`pkg_dir'" files "*.`extension'"
        foreach file of local files {
            local ship_files `ship_files' `file'
        }
    }
    local forbidden_home "/home/"
    local forbidden_home "`forbidden_home'tpcopeland/"
    local forbidden_dev "Stata"
    local forbidden_dev "`forbidden_dev'-Dev"
    local forbidden_codex ".codex"
    local forbidden_codex "`forbidden_codex'/skills/"
    local forbidden_claude "~/"
    local hidden_prefix "."
    local claude_name "clau"
    local claude_name "`claude_name'de"
    local forbidden_claude ///
        "`forbidden_claude'`hidden_prefix'`claude_name'/"
    local forbidden_examples "_"
    local forbidden_examples "`forbidden_examples'examples/"
    foreach file of local ship_files {
        foreach forbidden in "`forbidden_home'" "`forbidden_dev'" ///
            "`forbidden_codex'" "`forbidden_claude'" ///
            "`forbidden_examples'" {
            mata: st_numscalar("__has_forbidden", ///
                _tvtools_release_file_has(st_local("pkg_dir") + "/" + ///
                    st_local("file"), st_local("forbidden")))
            assert scalar(__has_forbidden) == 0
        }
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' metadata_paths"
}

**# 5. Autoload and execution work outside any repository directory

local ++test_count
capture noisily {
    capture mkdir "$TVTOOLS_QA_RUN_DIR/outside"
    cd "$TVTOOLS_QA_RUN_DIR/outside"
    discard
    tvtools, list
    clear
    set obs 1
    generate long id = 1
    generate double dob = 0
    generate double entry = 10000
    generate double exitd = 10365
    tvage, id(id) dob(dob) entry(entry) exit(exitd)
    clear
    set obs 250
    set seed 8121
    generate double x = rnormal()
    generate byte a = runiform() < invlogit(0.3*x)
    tvweight a, covariates(x) generate(w) nolog
    assert !missing(w)
    cd "`qa_dir'"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' outside_repo"
    capture cd "`qa_dir'"
}

**# 6. Curated installed-user end-to-end example uses inclusive survival time

local ++test_count
capture noisily {
    tempfile cohort episodes intervals
    clear
    input long id double(entry exitd)
    1 100 109
    2 100 109
    end
    save `cohort'
    clear
    input long id double(rx_start rx_stop) byte drug
    1 102 105 1
    end
    save `episodes'
    use `cohort', clear
    tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exitd) ///
        generate(tv_drug) keepdates
    save `intervals'
    clear
    input long id double(eventdate)
    1 105
    2 .
    end
    tvevent using `intervals', id(id) date(eventdate) ///
        start(rx_start) stop(rx_stop) generate(fail)
    generate double start0 = rx_start - 1
    stset rx_stop, id(id) failure(fail) time0(start0)
    generate double analysis_time = _t - _t0
    quietly summarize analysis_time
    assert r(sum) == 16
    assert _d == fail
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' installed_example"
}

**# 7. Installed documentation has no checkout-only or stale recipes

local ++test_count
capture noisily {
    local docs README.md
    local help_files : dir "`pkg_dir'" files "*.sthlp"
    local docs `docs' `help_files'
    foreach file of local docs {
        foreach forbidden in "_data/" "tv_exposure" ///
            "enter(start)" "enter(rx_start)" "splitMulti" {
            mata: st_numscalar("__has_stale", ///
                _tvtools_release_file_has(st_local("pkg_dir") + "/" + ///
                    st_local("file"), st_local("forbidden")))
            assert scalar(__has_stale) == 0
        }
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' docs_surface"
}

**# 8. Dialog files load through Stata and expose the command contracts

local ++test_count
capture noisily {
    foreach dialog in tvexpose tvmerge tvevent {
        capture noisily db `dialog'
        local dialog_rc = _rc
        assert inlist(`dialog_rc', 0, 8005)
    }
    mata: st_numscalar("__dlg_tvevent_role", ///
        _tvtools_release_file_has(st_local("pkg_dir") + ///
            "/tvevent.dlg", "Interval dataset"))
    mata: st_numscalar("__dlg_tvevent_start", ///
        _tvtools_release_file_has(st_local("pkg_dir") + ///
            "/tvevent.dlg", "option(start)"))
    mata: st_numscalar("__dlg_tvevent_stop", ///
        _tvtools_release_file_has(st_local("pkg_dir") + ///
            "/tvevent.dlg", "option(stop)"))
    assert scalar(__dlg_tvevent_role) == 1
    assert scalar(__dlg_tvevent_start) == 1
    assert scalar(__dlg_tvevent_stop) == 1
    mata: st_numscalar("__dlg_bad_merge_default", ///
        _tvtools_release_file_has(st_local("pkg_dir") + ///
            "/tvexpose.dlg", "default(120)"))
    mata: st_numscalar("__dlg_bad_gen_default", ///
        _tvtools_release_file_has(st_local("pkg_dir") + ///
            "/tvexpose.dlg", "default(tv_exposure)"))
    assert scalar(__dlg_bad_merge_default) == 0
    assert scalar(__dlg_bad_gen_default) == 0
    foreach token in "option(dose)" "option(dosecuts)" ///
        "option(frameout)" "option(flow)" "option(verbose)" {
        mata: st_numscalar("__dlg_token", ///
            _tvtools_release_file_has(st_local("pkg_dir") + ///
                "/tvexpose.dlg", st_local("token")))
        assert scalar(__dlg_token) == 1
    }
    foreach token in "option(frames)" "option(frameout)" ///
        "option(force)" "option(flow)" "option(verbose)" {
        mata: st_numscalar("__dlg_token", ///
            _tvtools_release_file_has(st_local("pkg_dir") + ///
                "/tvmerge.dlg", st_local("token")))
        assert scalar(__dlg_token) == 1
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' dialogs"
}

**# 9. Menu setup is safe and idempotent in one session

local ++test_count
capture noisily {
    local menu_setup "`pkg_dir'/tvtools_menu_setup.do"
    capture program drop tvtools_menu_setup
    do "`menu_setup'"
    do "`menu_setup'"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' menu_twice"
}

**# 10. Demo is rerunnable and restores session settings

local ++test_count
capture noisily {
    local demo_more = c(more)
    local demo_varabbrev = c(varabbrev)
    local demo_linesize = c(linesize)
    local demo_scheme "`c(scheme)'"
    local demo_frame "`c(frame)'"
    capture noisily do "`pkg_dir'/demo/demo_tvtools.do"
    local demo_rc1 = _rc
    capture log close _all
    quietly log using "`qa_dir'/test_package_release.log", append nomsg
    capture noisily do "`pkg_dir'/demo/demo_tvtools.do"
    local demo_rc2 = _rc
    capture log close _all
    quietly log using "`qa_dir'/test_package_release.log", append nomsg
    assert `demo_rc1' == 0 & `demo_rc2' == 0
    assert "`c(more)'" == "`demo_more'"
    assert "`c(varabbrev)'" == "`demo_varabbrev'"
    assert c(linesize) == `demo_linesize'
    assert "`c(scheme)'" == "`demo_scheme'"
    assert "`c(frame)'" == "`demo_frame'"
    confirm file "`pkg_dir'/demo/balance_loveplot.png"
    confirm file "`pkg_dir'/demo/swimlane_plot.png"
    capture frame f_antidep: describe
    assert _rc != 0
    capture frame f_benzo: describe
    assert _rc != 0
    capture frame f_merged: describe
    assert _rc != 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' demo_twice"
}

capture cd "`qa_dir'"
display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "release-contract failures:`failed_tests'"
    exit 1
}

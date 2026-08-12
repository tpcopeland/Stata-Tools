/*  demo_asof.do - Guided demonstration of asof

    Produces, in asof/demo/ (and refreshes .md when logdoc is installed):
      1. Data-layout walkthrough          -> console_data_layout.log -> .md
      2. First as-of join and r() results -> console_quick_start.log -> .md
      3. Direction, selection, and ties   -> console_selection_rules.log -> .md
      4. Windows, ranges, and missingness -> console_windows_missingness.log -> .md
      5. Frames and multi-variable carry  -> console_frames_multivariable.log -> .md

    Run from the repository root, the asof package directory, or
    asof/demo/. The package root is resolved from c(pwd).

    The examples use invented patient data. They illustrate the mechanics of
    selecting measurements around an index date; they are not an analysis
    protocol or clinical recommendation.
*/

version 16.0
local _demo_varabbrev = c(varabbrev)
local _demo_linesize = c(linesize)
local _demo_more = c(more)
local _demo_plus_orig "`c(sysdir_plus)'"
local _demo_personal_orig "`c(sysdir_personal)'"
local _demo_launch_dir "`c(pwd)'"
local _demo_rc = 0

capture findfile logdoc.ado
local _demo_has_logdoc = (_rc == 0)

capture log close _all
capture frame drop asof_demo_events
set varabbrev off
set linesize 120
set more off

* Install into temporary PLUS and PERSONAL directories. This exercises the
* local package manifest without replacing packages in the user's real ado
* directories.
tempfile _demo_marker
local _demo_sysroot "`_demo_marker'_sysdir"
capture mkdir "`_demo_sysroot'"
capture mkdir "`_demo_sysroot'/plus"
capture mkdir "`_demo_sysroot'/personal"
sysdir set PLUS "`_demo_sysroot'/plus"
sysdir set PERSONAL "`_demo_sysroot'/personal"

capture noisily {
    **# Paths and local installation
    local cwd = subinstr("`c(pwd)'", "\", "/", .)
    local pkg_dir ""

    if fileexists("`cwd'/asof.pkg") {
        local pkg_dir "`cwd'"
    }
    else if fileexists("`cwd'/../asof.pkg") {
        local pkg_dir = substr("`cwd'", 1, length("`cwd'") - 5)
    }
    else if fileexists("`cwd'/asof/asof.pkg") {
        local pkg_dir "`cwd'/asof"
    }
    else {
        display as error "demo_asof.do must be run from the repository root, asof, or asof/demo"
        exit 601
    }

    local demo_dir "`pkg_dir'/demo"
    capture mkdir "`demo_dir'"

    capture ado uninstall asof
    quietly net install asof, from("`pkg_dir'") replace

    * Leave the source directory before command resolution so a current-folder
    * asof.ado cannot shadow the sandbox-installed copy.
    cd "`_demo_sysroot'"
    quietly findfile asof.ado
    local installed_asof = subinstr("`r(fn)'", "\", "/", .)
    if strpos("`installed_asof'", "`_demo_sysroot'/plus/") != 1 {
        display as error "demo_asof.do did not resolve the sandbox-installed asof.ado"
        exit 601
    }

    **# Remove stale generated documentation artifacts
    local console_files data_layout quick_start selection_rules ///
        windows_missingness frames_multivariable
    foreach f of local console_files {
        capture erase "`demo_dir'/console_`f'.log"
        if `_demo_has_logdoc' capture erase "`demo_dir'/console_`f'.md"
    }

    **# Build the long measurement table
    tempfile events master
    clear
    input long id str10 visit_iso double(score edss eq5d_uk eq5d_se) str10 status
    101 "2024-02-14" 48 2.0 .90 .88 "stable"
    101 "2024-03-15" 52 2.5 .86 .84 "improved"
    101 "2024-06-01" 58 3.0 .80 .78 "worsened"
    102 "2024-01-15" 40 1.0 .92 .90 "stable"
    102 "2024-04-10" 59 2.0 .88 .86 "stable"
    102 "2024-04-15" 60   . .87 .85 "pending"
    102 "2024-07-20" 65 2.5 .80 .78 "improved"
    103 "2024-05-15" 70 3.0 .76 .74 "stable"
    103 "2024-06-25" 72 3.5 .72 .70 "stable"
    103 "2024-07-10"  . 4.0 .68   . "worsened"
    103 "2024-10-15" 75 4.5 .60 .58 "worsened"
    105 "2024-02-01" 80 1.0 .95 .94 "stable"
    end
    generate double visit_date = daily(visit_iso, "YMD")
    format visit_date %tdCCYY-NN-DD
    drop visit_iso
    order id visit_date score edss eq5d_uk eq5d_se status
    label variable id "Patient ID"
    label variable visit_date "Measurement date"
    label variable score "Symptom score"
    label variable edss "Disability score"
    label variable eq5d_uk "EQ-5D UK"
    label variable eq5d_se "EQ-5D Sweden"
    label variable status "Clinical status"
    save "`events'", replace

    frame create asof_demo_events
    frame asof_demo_events: use "`events'", clear

    **# Build the master cohort
    clear
    input long id str10(index_iso start_iso end_iso) str8 cohort
    101 "2024-02-29" "2024-01-01" "2024-12-31" "A"
    102 "2024-04-15" "2024-02-01" "2024-10-31" "A"
    103 "2024-07-01" "2024-05-01" "2024-09-30" "B"
    104 "2024-08-01" "2024-01-01" "2024-12-31" "B"
    end
    generate double index_date = daily(index_iso, "YMD")
    generate double study_start = daily(start_iso, "YMD")
    generate double followup_date = daily(end_iso, "YMD")
    format index_date study_start followup_date %tdCCYY-NN-DD
    drop index_iso start_iso end_iso
    order id cohort index_date study_start followup_date
    label variable id "Patient ID"
    label variable cohort "Study cohort"
    label variable index_date "Index date"
    label variable study_start "Start of observability"
    label variable followup_date "End of follow-up"
    save "`master'", replace

    **# 1. Understand the two data layouts
    use "`master'", clear
    log using "`demo_dir'/console_data_layout.log", replace text ///
        name(data_layout) nomsg
    * # Start with a master cohort and a long measurement table
    * ## Master data in memory: one row per patient and index date
    list id cohort index_date study_start followup_date, ///
        noobs sep(0) abbreviate(16)
    * ## Using data: repeated dated measurements per patient
    frame asof_demo_events: list id visit_date score edss status, ///
        noobs sepby(id) abbreviate(16)
    log close data_layout

    **# 2. First as-of join
    use "`master'", clear
    log using "`demo_dir'/console_quick_start.log", replace text ///
        name(quick_start) nomsg
    * # Closest nonmissing score on either side of index
    asof score using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(both) select(nearest) ///
        generate(score_index) datename(score_date) gapname(score_gap) ///
        matchname(score_found) noisily
    * ## Stored results make match coverage auditable
    return list
    * ## The master rows stay in place and receive the selected values
    list id index_date score_index score_date score_gap score_found, ///
        noobs sep(0) abbreviate(16)
    log close quick_start
    assert score_index[1] == 48 & score_gap[1] == -15
    assert score_index[2] == 60 & score_gap[2] == 0
    assert score_index[3] == 72 & score_gap[3] == -6
    assert score_found == (id != 104)

    **# 3. Direction, selection, and tie behavior
    use "`master'", clear
    keep if id == 101
    log using "`demo_dir'/console_selection_rules.log", replace text ///
        name(selection_rules) nomsg
    * # Compare selection rules for the same patient and anchor
    * ## Patient 101 has equidistant records before and after index
    asof score using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(before) select(nearest) ///
        generate(before_nearest) datename(before_date)
    asof score using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(after) select(nearest) ///
        generate(after_nearest) datename(after_date)
    asof score using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(both) select(nearest) ///
        generate(both_default) datename(default_date)
    asof score using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(both) select(nearest) ties(after) ///
        generate(both_tie_after) datename(tie_after_date)
    asof score using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(both) select(first) ///
        generate(first_any) datename(first_date)
    asof score using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(both) select(last) ///
        generate(last_any) datename(last_date)
    * ## Nearest defaults to the earlier record when distances tie
    list index_date before_nearest before_date after_nearest after_date, ///
        noobs sep(0) abbreviate(16)
    list both_default default_date both_tie_after tie_after_date, ///
        noobs sep(0) abbreviate(16)
    * ## first and last select the earliest and latest eligible dates
    list first_any first_date last_any last_date, ///
        noobs sep(0) abbreviate(16)
    log close selection_rules
    assert before_nearest == 48 & after_nearest == 52
    assert both_default == 48 & both_tie_after == 52
    assert first_any == 48 & last_any == 58

    **# 4. Protocol windows, observability, and missingness
    use "`master'", clear
    log using "`demo_dir'/console_windows_missingness.log", replace text ///
        name(windows_missingness) nomsg
    * # Intersect a protocol window with each patient's observed period
    * ## By default, every carried value must be nonmissing
    asof edss using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(onorbefore) select(nearest) ///
        window(-45 0) range(study_start followup_date) ///
        generate(edss_baseline) datename(edss_date) gapname(edss_gap) ///
        matchname(edss_found) noisily
    * ## require() can allow a matched record whose carried value is missing
    asof edss using "`events'", id(id) date(visit_date) ///
        anchor(index_date) direction(onorbefore) select(nearest) ///
        window(-45 0) range(study_start followup_date) ///
        require(visit_date) generate(edss_any) ///
        datename(edss_date_any) matchname(edss_found_any)
    list id index_date edss_baseline edss_date edss_gap edss_found, ///
        noobs sep(0) abbreviate(16)
    list id edss_any edss_date_any edss_found_any, ///
        noobs sep(0) abbreviate(16)
    log close windows_missingness
    assert edss_baseline[1] == 2 & edss_baseline[2] == 2
    assert edss_baseline[3] == 3.5 & edss_found[4] == 0
    assert missing(edss_any[2]) & edss_date_any[2] == daily("2024-04-15", "YMD")
    assert edss_found_any[2] == 1 & edss_found_any[4] == 0

    **# 5. Frame input, multiple variables, and repeated master rows
    use "`master'", clear
    expand 2 if id == 101
    generate long master_row = _n
    order master_row
    log using "`demo_dir'/console_frames_multivariable.log", replace text ///
        name(frames_multivariable) nomsg
    * # Carry several variables from an in-memory frame
    * ## Wildcards resolve in the using frame; require() controls missingness
    asof eq5d_* status using events_in_memory, frame(asof_demo_events) ///
        id(id) date(visit_date) anchor(followup_date) ///
        direction(onorbefore) select(last) ///
        range(study_start followup_date) require(visit_date) ///
        suffix(_last) datename(last_visit) gapname(last_gap) ///
        matchname(last_found) noisily
    * ## Repeated master keys receive the same selection without changing order
    list master_row id followup_date eq5d_uk_last eq5d_se_last ///
        status_last last_visit last_gap last_found, ///
        noobs sep(0) abbreviate(16)
    * ## The complete r() contract remains available after frame input
    return list
    log close frames_multivariable
    assert master_row == _n
    assert eq5d_uk_last[1] == .8 & eq5d_uk_last[5] == .8
    assert missing(eq5d_se_last[3]) & last_found[3] == 1
    assert last_found[4] == 0

    **# Convert console logs to markdown when logdoc is already installed
    sysdir set PLUS "`_demo_plus_orig'"
    sysdir set PERSONAL "`_demo_personal_orig'"
    if `_demo_has_logdoc' {
        foreach f of local console_files {
            logdoc using "`demo_dir'/console_`f'.log", ///
                output("`demo_dir'/console_`f'.md") ///
                format(md) replace quiet
        }
    }
    else {
        display as text "(note: logdoc is not installed; .log files were generated and existing .md files were left unchanged)"
    }
}
local _demo_rc = _rc

**# Cleanup and restore session settings
capture log close _all
capture frame drop asof_demo_events
capture graph close _all
clear
capture cd "`_demo_launch_dir'"
sysdir set PLUS "`_demo_plus_orig'"
sysdir set PERSONAL "`_demo_personal_orig'"
set varabbrev `_demo_varabbrev'
set linesize `_demo_linesize'
set more `_demo_more'

if `_demo_rc' exit `_demo_rc'

*! test_datamap_v168.do Version 1.0.0  2026/08/30
*! Regression coverage for hostile text payloads, state restoration, and help widths
*! 2026-11-10 (datamap 2.0.0): datadict is removed.  T1-T4 run on datamap's
*! Markdown writer (the detail and stats options are gone: the label column and
*! the statistics are always there); T8 pinned the internal helper
*! _datadict_FileListMacro, which was deleted with datadict, and now asserts the
*! same promise (varabbrev restored on every path) at datamap's public surface;
*! T9 no longer lists datadict.sthlp.
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_datamap_v168.log", replace text

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
do "`qa_dir'/_qa_md.do"

capture program drop _v168_record
program define _v168_record
    version 16.0
    args rc pass fail label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        c_local pass_count = `pass' + 1
        c_local fail_count = `fail'
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        c_local pass_count = `pass'
        c_local fail_count = `fail' + 1
    }
end

capture mata: mata drop _v168_readme_count()
mata:
real scalar _v168_readme_count(string scalar path, string scalar needle)
{
    real scalar fh, in_index, occurrences
    string scalar line

    fh = fopen(path, "r")
    if (fh < 0) return(-1)
    in_index = 0
    occurrences = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (line == "## File index") in_index = 1
        else if (line == "## Coverage map") in_index = 0
        else if (in_index) {
            occurrences = occurrences + ///
                (strlen(line) - strlen(subinstr(line, needle, ""))) / strlen(needle)
        }
    }
    fclose(fh)
    return(occurrences)
}

real scalar _v168_svg_has_hostile_label(string scalar path, string scalar needle)
{
    real scalar fh, found
    string scalar line

    fh = fopen(path, "r")
    if (fh < 0) return(0)
    found = 0
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, needle)) {
            found = 1
        }
    }
    fclose(fh)
    return(found)
}
end

local hostile = "Cost " + char(34) + "quoted" + char(34) + ///
    " " + char(36) + "UNSET " + char(96) + "tick | <angle>"
local escaped = "Cost " + char(34) + "quoted" + char(34) + ///
    " &#36;UNSET &#96;tick " + char(92) + "| &lt;angle&gt;"
local metadata_hostile = "Cost " + char(34) + "quoted" + char(34) + ///
    " " + char(36) + "UNSET " + char(96) + "tick | <angle>"
local metadata_escaped = "Cost " + char(34) + "quoted" + char(34) + ///
    " &#36;UNSET &#96;tick " + char(92) + "| &lt;angle&gt;"

**# T1: datamap preserves and Markdown-escapes hostile variable labels
local ++test_count
capture noisily {
    clear
    set obs 3
    generate byte x = _n
    mata: st_varlabel(1, st_local("hostile"))
    tempfile varlabel_out varlabel_meta
    datamap, output("`varlabel_out'.md") mincell(0) ///
        saving("`varlabel_meta'", replace)

    qa_md_contains using "`varlabel_out'.md", needle(`"`macval(escaped)'"')
    assert r(n) == 1

    preserve
    quietly use "`varlabel_meta'", clear
    quietly keep if variable == "x"
    assert _N == 1
    mata: st_numscalar("__v168_label_match", ///
        st_sdata(1, "variable_label") == st_local("hostile"))
    assert scalar(__v168_label_match) == 1
    restore
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "datamap hostile variable label round-trip"

**# T2: datamap preserves and Markdown-escapes hostile dataset labels
local ++test_count
capture noisily {
    clear
    set obs 3
    generate byte x = _n
    label data `"`macval(hostile)'"'
    tempfile dslabel_out dslabel_meta
    datamap, output("`dslabel_out'.md") ///
        saving("`dslabel_meta'", replace)

    qa_md_contains using "`dslabel_out'.md", needle(`"- Label: `macval(escaped)'"') exact
    assert r(n) == 1

    preserve
    quietly use "`dslabel_meta'", clear
    assert _N == 1
    mata: st_numscalar("__v168_dslabel_match", ///
        st_sdata(1, "dataset_label") == st_local("hostile"))
    assert scalar(__v168_dslabel_match) == 1
    restore

    label data "__DATAMAP_68F73A__D literal"
    tempfile marker_out
    datamap, output("`marker_out'.md")
    qa_md_contains using "`marker_out'.md", needle("- Label: __DATAMAP_68F73A__D literal") exact
    assert r(n) == 1
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "datamap hostile dataset label round-trip"

**# T3: datamap preserves and Markdown-escapes hostile value labels
local ++test_count
capture noisily {
    clear
    set obs 6
    generate byte x = mod(_n, 3) + 1
    label define hostile_vl 1 `"`macval(hostile)'"' 2 "Normal" 3 "Normal 3"
    label values x hostile_vl
    tempfile vallabel_out
    datamap, output("`vallabel_out'.md") mincell(0)

    qa_md_contains using "`vallabel_out'.md", needle(`"1 `macval(escaped)': 2 (33.3%)"')
    assert r(n) == 1
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "datamap hostile value label round-trip"

**# T4: datamap accepts hostile title/subtitle/author prose
local ++test_count
capture noisily {
    clear
    set obs 3
    generate byte x = _n
    tempfile metadata_out
    datamap, output("`metadata_out'.md") title(`"`macval(metadata_hostile)'"') ///
        subtitle(`"`macval(metadata_hostile)'"') ///
        author(`"`macval(metadata_hostile)'"') ///
        notes(`"`macval(metadata_hostile)'"') ///
        changelog(`"`macval(metadata_hostile)'"')

    * the escaped text appears in the title, subtitle, author, notes and change log
    qa_md_contains using "`metadata_out'.md", needle(`"`macval(metadata_escaped)'"')
    assert !missing(r(n))
    assert r(n) >= 5
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "datamap hostile document metadata round-trip"

**# T5: datamvp accepts hostile variable labels and returns exact counts
local ++test_count
capture noisily {
    clear
    set obs 4
    generate double x = _n
    replace x = . in 2
    mata: st_varlabel(1, "Cost " + char(36) + "UNSET " + char(96) + "tick | <angle>")
    set varabbrev on
    datamvp x
    assert r(N) == 4
    assert r(N_complete) == 3
    assert r(N_incomplete) == 1
    assert "`c(varabbrev)'" == "on"
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "datamvp hostile variable label and return contract"

**# T6: datamvp graph titles survive quotes, dollar signs, and backticks
local ++test_count
capture noisily {
    clear
    set obs 4
    generate double x = _n
    replace x = . in 2
    local graph_title = "Patient " + char(34) + "quoted" + char(34) + ///
        " " + char(36) + "UNSET " + char(96) + "tick"
    datamvp x, graph(bar) title(`"`macval(graph_title)'"') gname(v168_title)
    tempfile title_svg
    graph export "`title_svg'.svg", name(v168_title) as(svg) replace

    local saw_patient 0
    local saw_quoted 0
    local saw_dollar 0
    local saw_tick 0
    tempname fh
    file open `fh' using "`title_svg'.svg", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Patient") local saw_patient 1
        if strpos(`"`macval(line)'"', char(34) + "quoted" + char(34)) {
            local saw_quoted 1
        }
        if strpos(`"`macval(line)'"', char(36) + "UNSET") local saw_dollar 1
        if strpos(`"`macval(line)'"', "tick") local saw_tick 1
        file read `fh' line
    }
    file close `fh'
    assert `saw_patient' & `saw_quoted' & `saw_dollar' & `saw_tick'
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "datamvp hostile graph title round-trip"

**# T7: datamvp preserves hostile value labels in grouped graph output
local ++test_count
capture noisily {
    clear
    set obs 6
    generate double x = _n
    replace x = . in 2
    generate byte g = mod(_n, 2)
    local graph_hostile = char(34) + char(36) + char(96)
    label define hostile_group 0 "Normal" 1 `"`macval(graph_hostile)'"'
    label values g hostile_group
    datamvp x, graph(bar) gby(g) gname(v168_group)
    assert "`r(gby_levels)'" == "0 1"
    tempfile group_svg
    graph export "`group_svg'.svg", name(v168_group) as(svg) replace

    local svg_path "`group_svg'.svg"
    mata: st_numscalar("__v168_svg_ok", ///
        _v168_svg_has_hostile_label(st_local("svg_path"), ///
            st_local("graph_hostile")))
    assert scalar(__v168_svg_ok) == 1

    datamvp x, graph(bar) over(g) gname(v168_over)
    tempfile over_svg
    graph export "`over_svg'.svg", name(v168_over) as(svg) replace
    local svg_path "`over_svg'.svg"
    mata: st_numscalar("__v168_svg_ok", ///
        _v168_svg_has_hostile_label(st_local("svg_path"), ///
            st_local("graph_hostile")))
    assert scalar(__v168_svg_ok) == 1

    local pattern_hostile = char(36)
    label define hostile_group 1 `"`macval(pattern_hostile)'"', modify
    datamvp x, graph(patterns) gby(g) top(2) gname(v168_patterns)
    tempfile patterns_svg
    graph export "`patterns_svg'.svg", name(v168_patterns) as(svg) replace
    local svg_path "`patterns_svg'.svg"
    mata: st_numscalar("__v168_svg_ok", ///
        _v168_svg_has_hostile_label(st_local("svg_path"), ///
            st_local("pattern_hostile")))
    assert scalar(__v168_svg_ok) == 1
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "datamvp hostile grouped graph labels"

**# T8: varabbrev is restored on datamap's memory and filelist branches
* (was _datadict_FileListMacro's early-return branch; the helper is deleted)
local ++test_count
capture noisily {
    clear
    set obs 1
    generate byte x = 1
    tempfile fl_dta
    quietly save "`fl_dta'.dta", replace
    set varabbrev on
    datamap, output("`fl_dta'_m.md")
    assert "`r(mode)'" == "memory"
    assert "`c(varabbrev)'" == "on"
    datamap, filelist("`fl_dta'") output("`fl_dta'_f.md")
    assert "`r(mode)'" == "filelist"
    assert "`c(varabbrev)'" == "on"
    capture datamap, filelist("`fl_dta'_nope") output("`fl_dta'_g.md")
    assert _rc != 0
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
    datamap, output("`fl_dta'_m2.md")
    assert "`c(varabbrev)'" == "off"
}
local test_rc = _rc
set varabbrev off
_v168_record `test_rc' `pass_count' `fail_count' "datamap memory/filelist branches restore varabbrev"

**# T9: every synopt description fits its active Viewer column
local ++test_count
capture noisily {
    local help_files datamap.sthlp dataprobe.sthlp datamvp.sthlp dataqa.sthlp
    local nbad 0
    foreach help_file of local help_files {
        local synopt_width 0
        tempname fh
        file open `fh' using "`pkg_dir'/`help_file'", read text
        file read `fh' line
        while r(eof) == 0 {
            if regexm(`"`macval(line)'"', "^\{synoptset ([0-9]+)") {
                local synopt_width = real(regexs(1))
            }
            if strpos(`"`macval(line)'"', "{synopt:") == 1 {
                local split = strpos(`"`macval(line)'"', "}}")
                if `split' > 0 & `synopt_width' > 0 {
                    local desc = substr(`"`macval(line)'"', `split' + 2, .)
                    local rendered = ustrregexra(`"`macval(desc)'"', "\{[^}]*\}", "")
                    if ustrlen(`"`macval(rendered)'"') > 71 - `synopt_width' {
                        local ++nbad
                        display as error "overwide synopt: `help_file': `line'"
                    }
                }
            }
            file read `fh' line
        }
        file close `fh'
    }
    assert `nbad' == 0
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "help synopt descriptions fit rendered width"

**# T10: qa/README.md indexes every runnable do-file exactly once
local ++test_count
capture noisily {
    local do_files : dir "`qa_dir'" files "*.do"
    foreach do_file of local do_files {
        if "`do_file'" == "profile.do" continue
        mata: st_numscalar("__v168_index_count", ///
            _v168_readme_count("`qa_dir'/README.md", "`do_file'"))
        assert scalar(__v168_index_count) == 1
    }
}
local test_rc = _rc
_v168_record `test_rc' `pass_count' `fail_count' "QA README indexes each runnable suite and runner once"

display "RESULT: test_datamap_v168 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close
if `fail_count' > 0 exit 1

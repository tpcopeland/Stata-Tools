* test_cycle_20261119_ratetab_outtab.do - 2026-11-19 review cycle, ratetab and outtab
* F1 ratetab ci(cluster()) leaves the caller's e() as it was (success and error)
* F2 ratetab keeps "$name" in default outcome/grouping labels (table, CSV, saving())
* F3 outtab panels() keeps "$name" in the outcome label (frame, CSV)
* F4 outtab frame() is refused before any file is written
* F5 ratetab saving(..., replace) refuses an unwritable file before any output

clear all
set more off
set varabbrev off
version 17.0

capture log close _cyc_ro
log using "test_cycle_20261119_ratetab_outtab.log", replace text name(_cyc_ro)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* count of string cells in the current frame that contain pat
mata:
real scalar _cyc_cells(string scalar pat)
{
    real scalar j, n
    n = 0
    for (j = 1; j <= st_nvar(); j++) {
        if (st_isstrvar(j)) n = n + sum(strpos(st_sdata(., j), pat) :> 0)
    }
    return(n)
}
real scalar _cyc_file(string scalar fn, string scalar pat)
{
    return(sum(strpos(cat(fn), pat) :> 0))
}
end

* a global that a re-expanded "$x" would turn into EXPANDED
global x EXPANDED

capture program drop _cyc_data
program define _cyc_data
    clear
    set seed 20261119
    set obs 200
    gen long id = ceil(_n / 4)
    gen byte g = mod(_n, 3)
    gen double pt = 1 + runiform()
    gen byte ev = mod(_n, 4) == 0
    gen byte ev2 = mod(_n, 5) == 0
    gen byte y = runiform() < .3
    gen byte x = mod(_n, 2)
    gen byte pan = 1
    mata: st_varlabel("g", "Cost " + char(36) + "x group")
    mata: st_varlabel("ev", "Deaths " + char(36) + "x here")
    mata: st_varlabel("ev2", "Second " + char(36) + "x out")
    mata: st_varlabel("y", "Outcome " + char(36) + "x lbl")
end

**# F1 ratetab ci(cluster()) and the caller's e()
**## success path: e() of the earlier regress survives, with e(sample)
local ++test_count
capture noisily {
    _cyc_data
    regress pt g
    local b0 = _b[g]
    quietly count if e(sample)
    local ns0 = r(N)
    ratetab g, events(ev) exposure(pt) ci(cluster(id))
    assert "`r(ci_method)'" == "cluster"
    assert "`e(cmd)'" == "regress"
    assert "`e(depvar)'" == "pt"
    assert reldif(_b[g], `b0') < 1e-12
    quietly count if e(sample)
    assert r(N) == `ns0'
}
if _rc == 0 {
    display as result "  PASS: F1 ratetab ci(cluster()) keeps the caller's e()"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 ratetab ci(cluster()) keeps the caller's e() (rc=`=_rc')"
    local ++fail_count
}

**## error path (refusal after the fits) and no prior estimates
local ++test_count
capture noisily {
    _cyc_data
    regress pt g
    capture noisily ratetab g, events(ev) exposure(pt) ci(cluster(id)) frame(default, replace)
    assert _rc != 0
    assert "`e(cmd)'" == "regress"
    assert "`e(depvar)'" == "pt"
    ereturn clear
    ratetab g, events(ev) exposure(pt) ci(cluster(id))
    assert "`e(cmd)'" == ""
}
if _rc == 0 {
    display as result "  PASS: F1 e() kept on the error path; none stays none"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 e() kept on the error path; none stays none (rc=`=_rc')"
    local ++fail_count
}

**# F2 ratetab default labels with "$name"
**## frame and CSV cells keep the labels verbatim (two outcomes)
local ++test_count
capture noisily {
    _cyc_data
    local csv "`output_dir'/cyc_ro_f2.csv"
    capture erase "`csv'"
    ratetab g, events(ev ev2) exposure(pt) frame(_cyc_f2, replace) csv("`csv'")
    frame _cyc_f2 {
        mata: st_local("n1", strofreal(_cyc_cells("Deaths " + char(36) + "x here")))
        mata: st_local("n2", strofreal(_cyc_cells("Second " + char(36) + "x out")))
        mata: st_local("n3", strofreal(_cyc_cells("Cost " + char(36) + "x group")))
        mata: st_local("nx", strofreal(_cyc_cells("EXPANDED")))
    }
    assert `n1' == 1 & `n2' == 1 & `n3' == 1 & `nx' == 0
    mata: st_local("c1", strofreal(_cyc_file(st_local("csv"), "Deaths " + char(36) + "x here")))
    mata: st_local("c3", strofreal(_cyc_file(st_local("csv"), "Cost " + char(36) + "x group")))
    mata: st_local("cx", strofreal(_cyc_file(st_local("csv"), "EXPANDED")))
    assert `c1' == 1 & `c3' == 1 & `cx' == 0
    frame drop _cyc_f2
}
if _rc == 0 {
    display as result "  PASS: F2 ratetab frame and CSV keep \$name in default labels"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 ratetab frame and CSV keep \$name in default labels (rc=`=_rc')"
    local ++fail_count
}

**## saving() outcome_label and a typed outlabels() keep "$name"
local ++test_count
capture noisily {
    _cyc_data
    local sv "`output_dir'/cyc_ro_f2sv.dta"
    ratetab g, events(ev ev2) exposure(pt) saving("`sv'", replace)
    ratetab g, events(ev) exposure(pt) outlabels("Typed \$x lab") frame(_cyc_f2b, replace)
    frame _cyc_f2b {
        mata: st_local("nt", strofreal(_cyc_cells("Typed " + char(36) + "x lab")))
        mata: st_local("nx", strofreal(_cyc_cells("EXPANDED")))
    }
    assert `nt' == 1 & `nx' == 0
    frame drop _cyc_f2b
    preserve
    use "`sv'", clear
    mata: st_local("s1", strofreal(sum(st_sdata(., "outcome_label") :== "Deaths " + char(36) + "x here")))
    mata: st_local("s2", strofreal(sum(st_sdata(., "outcome_label") :== "Second " + char(36) + "x out")))
    quietly count if outcome == 1
    local no1 = r(N)
    quietly count if outcome == 2
    local no2 = r(N)
    restore
    assert `s1' == `no1' & `no1' == 3
    assert `s2' == `no2' & `no2' == 3
}
if _rc == 0 {
    display as result "  PASS: F2 saving() outcome_label and typed outlabels() keep \$name"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 saving() outcome_label and typed outlabels() keep \$name (rc=`=_rc')"
    local ++fail_count
}

**# F3 outtab panels() outcome label with "$name"
local ++test_count
capture noisily {
    _cyc_data
    local csv "`output_dir'/cyc_ro_f3.csv"
    capture erase "`csv'"
    outtab y, exposure(x) panels(pan) frame(_cyc_f3, replace) csv("`csv'")
    frame _cyc_f3 {
        mata: st_local("ok", strofreal(st_sdata(2, "rowlabel") == "   Outcome " + char(36) + "x lbl"))
        mata: st_local("nx", strofreal(_cyc_cells("EXPANDED")))
    }
    assert `ok' == 1 & `nx' == 0
    mata: st_local("c1", strofreal(_cyc_file(st_local("csv"), "Outcome " + char(36) + "x lbl")))
    mata: st_local("cx", strofreal(_cyc_file(st_local("csv"), "EXPANDED")))
    assert `c1' == 1 & `cx' == 0
    * without panels() the label was already verbatim: both agree now
    outtab y, exposure(x) frame(_cyc_f3b, replace)
    frame _cyc_f3b: mata: st_local("ok2", strofreal(st_sdata(1, "rowlabel") == "Outcome " + char(36) + "x lbl"))
    assert `ok2' == 1
    frame drop _cyc_f3
    frame drop _cyc_f3b
}
if _rc == 0 {
    display as result "  PASS: F3 outtab panels() keeps \$name in the outcome label"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 outtab panels() keeps \$name in the outcome label (rc=`=_rc')"
    local ++fail_count
}

**# F4 outtab frame() refused before any file
local ++test_count
capture noisily {
    _cyc_data
    local csv "`output_dir'/cyc_ro_f4.csv"
    local md "`output_dir'/cyc_ro_f4.md"
    * invalid name
    capture erase "`csv'"
    summarize pt, meanonly
    local m0 = r(mean)
    capture noisily outtab y, exposure(x) csv("`csv'") frame(1bad)
    assert _rc == 198
    capture confirm file "`csv'"
    assert _rc == 601
    assert reldif(r(mean), `m0') < 1e-12
    * occupied frame without replace
    frame create _cyc_f4occ
    capture noisily outtab y, exposure(x) csv("`csv'") markdown("`md'") frame(_cyc_f4occ)
    assert _rc == 110
    capture confirm file "`csv'"
    assert _rc == 601
    capture confirm file "`md'"
    assert _rc == 601
    * the current frame, with replace
    capture noisily outtab y, exposure(x) csv("`csv'") frame(`c(frame)', replace)
    assert _rc == 198
    capture confirm file "`csv'"
    assert _rc == 601
    assert c(frame) == "default"
    quietly count
    assert r(N) == 200
    * the occupied frame with replace still works, and is replaced
    outtab y, exposure(x) csv("`csv'") frame(_cyc_f4occ, replace)
    assert "`r(frame)'" == "_cyc_f4occ"
    capture confirm file "`csv'"
    assert _rc == 0
    frame _cyc_f4occ: confirm variable rowlabel c1 c2 c3
    frame drop _cyc_f4occ
}
if _rc == 0 {
    display as result "  PASS: F4 outtab frame() refusals precede the exports"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 outtab frame() refusals precede the exports (rc=`=_rc')"
    local ++fail_count
}

**# F5 ratetab saving(..., replace) writability checked up front
**## unwritable location and missing directory: no table, frame, or r() change
local ++test_count
capture noisily {
    _cyc_data
    capture frame drop _cyc_f5
    summarize pt, meanonly
    local m0 = r(mean)
    capture noisily ratetab g, events(ev) exposure(pt) ptunit(years) saving(/proc/cyc_sv.dta, replace) frame(_cyc_f5, replace)
    assert _rc == 603
    assert reldif(r(mean), `m0') < 1e-12
    assert "`r(frame)'" == ""
    capture confirm frame _cyc_f5
    assert _rc == 111
    capture noisily ratetab g, events(ev) exposure(pt) ptunit(years) saving("`output_dir'/no_such_dir_cyc/sv", replace) frame(_cyc_f5, replace)
    assert _rc == 603
    assert reldif(r(mean), `m0') < 1e-12
    capture confirm frame _cyc_f5
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: F5 saving(, replace) to an unwritable path refused up front"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 saving(, replace) to an unwritable path refused up front (rc=`=_rc')"
    local ++fail_count
}

**## read-only existing file; writable file still replaced; suffix as save writes it
local ++test_count
capture noisily {
    _cyc_data
    local ro "`output_dir'/cyc_ro_f5ro.dta"
    capture shell chmod u+w "`ro'"
    ratetab g, events(ev) exposure(pt) ptunit(years) saving("`ro'", replace)
    shell chmod a-w "`ro'"
    capture frame drop _cyc_f5
    summarize pt, meanonly
    local m0 = r(mean)
    capture noisily ratetab g, events(ev ev2) exposure(pt) ptunit(years) saving("`ro'", replace) frame(_cyc_f5, replace)
    local rc_ro = _rc
    shell chmod u+w "`ro'"
    assert `rc_ro' != 0
    assert reldif(r(mean), `m0') < 1e-12
    capture confirm frame _cyc_f5
    assert _rc == 111
    * the file is untouched: one outcome, three levels
    preserve
    use "`ro'", clear
    assert _N == 3
    restore
    * writable now: replace rewrites it (two outcomes)
    ratetab g, events(ev ev2) exposure(pt) ptunit(years) saving("`ro'", replace)
    assert `"`r(saving)'"' == "`ro'"
    preserve
    use "`ro'", clear
    assert _N == 6
    restore
    * a name with a suffix is checked as save writes it (no .dta appended)
    local sfx "`output_dir'/cyc_ro_f5.v1"
    capture erase "`sfx'"
    ratetab g, events(ev) exposure(pt) ptunit(years) saving("`sfx'")
    capture confirm file "`sfx'"
    assert _rc == 0
    capture noisily ratetab g, events(ev) exposure(pt) ptunit(years) saving("`sfx'") frame(_cyc_f5, replace)
    assert _rc == 602
    capture confirm frame _cyc_f5
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: F5 read-only file refused, writable file replaced, suffix checked"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 read-only file refused, writable file replaced, suffix checked (rc=`=_rc')"
    local ++fail_count
}

macro drop x
set varabbrev off

display as result "test_cycle_20261119_ratetab_outtab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_ratetab_outtab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _cyc_ro

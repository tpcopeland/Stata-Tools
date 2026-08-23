* test_kmplot_v130.do
* Rendered-geometry regression tests for the kmplot 1.3.0 risk-table layout
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-21
*
* The 1.2.7-1.2.11 layouts kept the two panels' time axes aligned by giving
* both a large plotregion(margin(l=)).  That is blank space *inside* the
* plotting region, so the main plot's time origin drifted away from its own
* y axis while every alignment test still passed.  These tests measure the
* rendered SVG and pin the relationships the earlier suites never checked.

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

**# Helvetica advance widths (ASCII 32-126), thousandths of an em.
* Stata declares Helvetica in the SVG; digits and parentheses render at these
* widths to within 0.5%, letters up to 6% wider, so letter-based extents are
* inflated before they are asserted on.
mata:
mata clear
real scalar km_emw(string scalar s)
{
    real rowvector V
    real scalar i, j, w
    string scalar K
    V = (278,278,355,556,556,889,667,191,333,333,389,584,278,333,278,278,
         556,556,556,556,556,556,556,556,556,556,
         278,278,584,584,584,556,1015,
         667,667,722,722,667,611,778,722,278,500,667,556,833,722,778,667,
         778,722,667,611,722,667,944,667,667,611,
         278,278,278,469,556,333,
         556,556,500,556,556,278,556,556,222,222,500,222,833,556,556,556,
         556,333,500,278,556,500,722,500,500,500,
         334,260,334,584)
    K = ""
    for (i=32; i<=126; i++) K = K + char(i)
    w = 0
    for (i=1; i<=strlen(s); i++) {
        j = strpos(K, substr(s,i,1))
        w = w + (j>0 ? V[j] : 556)
    }
    return(w/1000)
}
end

capture program drop _km_emw
program define _km_emw, rclass
    version 16.0
    args s
    tempname w
    mata: st_numscalar("`w'", km_emw(st_local("s")))
    return scalar w = `w'
end

**# Scan a rendered SVG for the coordinates the layout contract depends on.
capture program drop _km_geom
program define _km_geom, rclass
    version 16.0
    syntax using/, GRP(string) ZERO(string) LAST(string) TITLE(string)

    local width = .
    local height = .
    local yaxis_x = .
    local mainzero_x = .
    local mainzero_y = .
    local grp_x = .
    local grp_fs = .
    local grp_vis = 0
    local grp_inv = 0
    local zero_x = .
    local zero_fs = .
    local zero_n = 0
    local last_x = .
    local last_fs = .
    local last_n = 0
    local title_x = .
    local title_fs = .
    local ylab_vis = 0
    local ylab_inv = 0

    tempname fh
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "viewBox=") & ///
            regexm(`"`line'"', `"viewBox="0 0 ([0-9.]+) ([0-9.]+)""') {
            local width = real(regexs(1))
            local height = real(regexs(2))
        }
        * vertical rules: the tallest one is the main panel's y axis
        if strpos(`"`line'"', "<line ") & ///
            regexm(`"`line'"', ///
            `"x1="([0-9.]+)" y1="([0-9.]+)" x2="([0-9.]+)" y2="([0-9.]+)""') {
            local lx1 = real(regexs(1))
            local ly1 = real(regexs(2))
            local lx2 = real(regexs(3))
            local ly2 = real(regexs(4))
            if abs(`lx1' - `lx2') < 0.01 & ///
                abs(`ly2' - `ly1') > 0.3 * `height' {
                if missing(`yaxis_x') | `lx1' < `yaxis_x' {
                    local yaxis_x = `lx1'
                }
            }
        }
        if strpos(`"`line'"', "<text ") {
            local tx = .
            local ty = .
            local tfs = .
            if regexm(`"`line'"', `"<text x="([0-9.-]+)" y="([0-9.-]+)""') {
                local tx = real(regexs(1))
                local ty = real(regexs(2))
            }
            if regexm(`"`line'"', "font-size:([0-9.]+)px") {
                local tfs = real(regexs(1))
            }
            local vis = (strpos(`"`line'"', "opacity:0.00") == 0)
            local rot = (strpos(`"`line'"', "rotate") > 0)
            local endanc = (strpos(`"`line'"', `"text-anchor="end""') > 0)
            local midanc = (strpos(`"`line'"', `"text-anchor="middle""') > 0)

            * main-panel time-zero tick: topmost "0" on a horizontal axis
            if strpos(`"`line'"', ">0</text>") & `midanc' & !`rot' {
                if missing(`mainzero_y') | `ty' < `mainzero_y' {
                    local mainzero_y = `ty'
                    local mainzero_x = `tx'
                }
            }
            if strpos(`"`line'"', `">`grp'</text>"') & `endanc' & !`rot' {
                if `vis' {
                    local ++grp_vis
                    local grp_x = `tx'
                    local grp_fs = `tfs'
                }
                else local ++grp_inv
            }
            if strpos(`"`line'"', `">`zero'</text>"') & `midanc' & `vis' {
                local ++zero_n
                local zero_x = `tx'
                local zero_fs = `tfs'
            }
            if strpos(`"`line'"', `">`last'</text>"') & `midanc' & `vis' {
                local ++last_n
                local last_x = `tx'
                local last_fs = `tfs'
            }
            if strpos(`"`line'"', `">`title'</text>"') & `rot' {
                local title_x = `tx'
                local title_fs = `tfs'
            }
            if strpos(`"`line'"', ">0.50</text>") & `endanc' {
                if `vis' local ++ylab_vis
                else local ++ylab_inv
            }
        }
        file read `fh' line
    }
    file close `fh'

    return scalar width = `width'
    return scalar height = `height'
    return scalar yaxis_x = `yaxis_x'
    return scalar mainzero_x = `mainzero_x'
    return scalar grp_x = `grp_x'
    return scalar grp_fs = `grp_fs'
    return scalar grp_vis = `grp_vis'
    return scalar grp_inv = `grp_inv'
    return scalar zero_x = `zero_x'
    return scalar zero_fs = `zero_fs'
    return scalar zero_n = `zero_n'
    return scalar last_x = `last_x'
    return scalar last_fs = `last_fs'
    return scalar last_n = `last_n'
    return scalar title_x = `title_x'
    return scalar title_fs = `title_fs'
    return scalar ylab_vis = `ylab_vis'
    return scalar ylab_inv = `ylab_inv'
end

**# Fixture: two groups carrying the exact labels from the field report.
capture program drop _km_v130_data
program define _km_v130_data
    version 16.0
    args g1 g2
    if `"`g1'"' == "" local g1 "None"
    if `"`g2'"' == "" local g2 "Current HRT use"
    clear
    set obs 12000
    generate byte grp = cond(_n <= 6000, 1, 2)
    bysort grp: generate long within = _n
    generate double ftime = 20
    generate byte fail = within <= 2000
    replace ftime = 1 + mod(within - 1, 19) if fail
    label define grplbl 1 `"`g1'"' 2 `"`g2'"', replace
    label values grp grplbl
    stset ftime, failure(fail)
end

local test_count = 0
local pass_count = 0
local fail_count = 0

**# R1-R4: the geometric contract, one scheme per test.
* Option pattern is exactly the one reported: no timepoints(), no xlabel().
local rnum = 0
foreach sch in s2color s1mono s1color sj {
    local ++rnum
    local ++test_count
    capture noisily {
        _km_v130_data
        tempfile svgbase
        local svg "`svgbase'.svg"
        kmplot, by(grp) colors(black gray) lpattern(solid dash) ///
            risktable riskevents riskmono scheme(`sch') ///
            name(v130_`sch', replace)
        graph display v130_`sch', xsize(7.5) ysize(4.5)
        graph export "`svg'", as(svg) replace

        _km_geom using "`svg'", grp("Current HRT use") ///
            zero("6,000 (0)") last("4,000 (2,000)") ///
            title("No. at risk (events)")

        foreach _r in width height yaxis_x mainzero_x grp_x grp_fs ///
            grp_vis grp_inv zero_x zero_fs zero_n last_x last_fs last_n ///
            title_x title_fs ylab_vis ylab_inv {
            local `_r' = r(`_r')
        }

        assert !missing(`width', `yaxis_x', `mainzero_x')
        assert !missing(`grp_x', `zero_x', `last_x', `title_x')

        * counts carry thousands separators in both rows
        assert `zero_n' == 2
        assert `last_n' == 2

        * (1) the check every earlier suite was blind to: the main plot's
        * time origin sits on the main y axis, with no gutter inside the
        * plotting region.
        assert abs(`yaxis_x' - `mainzero_x') < 2

        * (2) the two panels share a time origin
        assert abs(`mainzero_x' - `zero_x') < 2

        * (3) the row label clears the time-zero count, whose label is
        * centred on the axis and so reaches back into the label column
        _km_emw "6,000 (0)"
        local zero_left = `zero_x' - `r(w)' * `zero_fs' / 2
        assert `zero_left' > `grp_x' + 10

        * (4) the row label clears the vertical table title.  Letters render
        * up to 6% wider than the declared metric, so inflate by 10% before
        * asserting.
        _km_emw "Current HRT use"
        local grp_left = `grp_x' - `r(w)' * `grp_fs' * 1.10
        local title_right = `title_x' + 0.75 * `title_fs'
        assert `grp_left' > `title_right'

        * (5) the row label stays inside the left graph boundary
        assert `grp_left' > 0

        * (6) the final count is fully visible, text width included
        _km_emw "4,000 (2,000)"
        local last_right = `last_x' + `r(w)' * `last_fs' / 2
        assert `last_right' < `width' - 3

        * (7) each panel carries the other's labels invisibly: that is what
        * makes the two label columns, and so the two time axes, the same
        * width.  A style option leaking across the whole axis would blank
        * the visible set.
        assert `grp_vis' == 1
        assert `grp_inv' == 1
        assert `ylab_vis' == 1
        assert `ylab_inv' == 1

        erase "`svg'"
    }
    if _rc == 0 {
        display as result "  PASS: R`rnum' layout geometry (`sch')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: R`rnum' layout geometry (`sch') (rc=`=_rc')"
        local ++fail_count
    }
}

**# R5: long row labels must not run over the vertical table title.
local ++test_count
capture noisily {
    _km_v130_data "Never used hormone replacement therapy" ///
        "Currently using hormone replacement therapy"
    tempfile svgbase
    local svg "`svgbase'.svg"
    kmplot, by(grp) risktable riskevents riskmono scheme(s1mono) ///
        name(v130_long, replace)
    graph display v130_long, xsize(7.5) ysize(4.5)
    graph export "`svg'", as(svg) replace

    _km_geom using "`svg'", grp("Currently using hormone replacement therapy") ///
        zero("6,000 (0)") last("4,000 (2,000)") title("No. at risk (events)")

    foreach _r in yaxis_x mainzero_x zero_x grp_x grp_fs title_x title_fs {
        local `_r' = r(`_r')
    }
    assert abs(`yaxis_x' - `mainzero_x') < 2
    assert abs(`mainzero_x' - `zero_x') < 2
    _km_emw "Currently using hormone replacement therapy"
    local grp_left = `grp_x' - `r(w)' * `grp_fs' * 1.10
    local title_right = `title_x' + 0.75 * `title_fs'
    assert `grp_left' > `title_right'
    assert `grp_left' > 0
    erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: R5 long row labels clear the table title"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 long row labels clear the table title (rc=`=_rc')"
    local ++fail_count
}

**# R6: the contract holds at other canvas sizes (the reserves are
**# expressed as fractions of the graph, not as fixed distances).
local ++test_count
capture noisily {
    _km_v130_data
    kmplot, by(grp) risktable riskevents riskmono scheme(s2color) ///
        name(v130_size, replace)
    foreach dim in "5.5 4" "11 5" "6 6" {
        tokenize `dim'
        tempfile svgbase
        local svg "`svgbase'.svg"
        graph display v130_size, xsize(`1') ysize(`2')
        graph export "`svg'", as(svg) replace
        _km_geom using "`svg'", grp("Current HRT use") ///
            zero("6,000 (0)") last("4,000 (2,000)") ///
            title("No. at risk (events)")
        foreach _r in width yaxis_x mainzero_x zero_x zero_fs grp_x ///
            last_x last_fs {
            local `_r' = r(`_r')
        }
        assert abs(`yaxis_x' - `mainzero_x') < 2
        assert abs(`mainzero_x' - `zero_x') < 2
        _km_emw "6,000 (0)"
        local zero_left = `zero_x' - `r(w)' * `zero_fs' / 2
        assert `zero_left' > `grp_x' + 5
        _km_emw "4,000 (2,000)"
        local last_right = `last_x' + `r(w)' * `last_fs' / 2
        assert `last_right' < `width' - 3
        erase "`svg'"
    }
}
if _rc == 0 {
    display as result "  PASS: R6 layout holds across canvas sizes"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 layout holds across canvas sizes (rc=`=_rc')"
    local ++fail_count
}

**# R7: plain risktable (no events) and a four-group table.
local ++test_count
capture noisily {
    _km_v130_data
    tempfile svgbase
    local svg "`svgbase'.svg"
    kmplot, by(grp) risktable riskmono scheme(s2color) name(v130_plain, replace)
    graph display v130_plain, xsize(7.5) ysize(4.5)
    graph export "`svg'", as(svg) replace
    _km_geom using "`svg'", grp("Current HRT use") ///
        zero("6,000") last("4,000") title("No. at risk")
    foreach _r in yaxis_x mainzero_x zero_x zero_fs zero_n grp_x {
        local `_r' = r(`_r')
    }
    assert `zero_n' == 2
    assert abs(`yaxis_x' - `mainzero_x') < 2
    assert abs(`mainzero_x' - `zero_x') < 2
    _km_emw "6,000"
    local zero_left = `zero_x' - `r(w)' * `zero_fs' / 2
    assert `zero_left' > `grp_x' + 5
    erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: R7 plain risktable geometry"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 plain risktable geometry (rc=`=_rc')"
    local ++fail_count
}

**# R8: helper returns the margins the main panel needs, and the left
**# plotregion margin stays at zero.  A stale in-memory helper that does not
**# return them is what produced the four gsize(.) warnings in 1.2.9.
local ++test_count
capture noisily {
    * version the command declares to the helper
    quietly findfile kmplot.ado
    local _km_ver = ""
    tempname vfh
    file open `vfh' using `"`r(fn)'"', read text
    file read `vfh' vline
    while r(eof) == 0 & "`_km_ver'" == "" {
        if regexm(`"`vline'"', "kmplot Version ([0-9.]+)") {
            local _km_ver = regexs(1)
        }
        file read `vfh' vline
    }
    file close `vfh'
    assert "`_km_ver'" != ""
    _km_v130_data
    kmplot, by(grp) risktable riskevents riskmono name(v130_ret, replace)
    quietly _kmplot_risktable, grpvar(grp) ngroups(2) ///
        graphname(v130_helper) colors(black gray) mono events toptimeaxis ///
        callerversion("`_km_ver'")
    assert r(plot_margin_left) == 0
    assert !missing(r(plot_margin_right))
    assert r(plot_margin_right) >= 4
    assert !missing(r(row_offset), r(row_labgap), r(title_gap))
    assert !missing(r(row_offset))
    assert r(row_offset) > 0 & r(row_offset) < 0.5
}
if _rc == 0 {
    display as result "  PASS: R8 helper margin contract"
    local ++pass_count
}
else {
    display as error "  FAIL: R8 helper margin contract (rc=`=_rc')"
    local ++fail_count
}

**# R9: command and helper must agree on their version.  A package update
**# mid-session leaves the previous kmplot.ado in memory while the helper is
**# reloaded from disk; without this handshake the panels misalign silently.
local ++test_count
capture noisily {
    _km_v130_data
    capture _kmplot_risktable, grpvar(grp) ngroups(2) ///
        graphname(v130_bad) colors(black gray) mono events toptimeaxis
    assert _rc == 498
    capture _kmplot_risktable, grpvar(grp) ngroups(2) ///
        graphname(v130_bad) colors(black gray) mono events toptimeaxis ///
        callerversion("1.2.11")
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: R9 command/helper version handshake"
    local ++pass_count
}
else {
    display as error "  FAIL: R9 command/helper version handshake (rc=`=_rc')"
    local ++fail_count
}

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v130 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v130 tests=`test_count' pass=`pass_count' fail=`fail_count'"

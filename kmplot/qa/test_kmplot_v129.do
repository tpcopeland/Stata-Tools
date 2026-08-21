* test_kmplot_v129.do
* Regression tests for kmplot 1.2.9
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-08-21

clear all
version 16.0
set varabbrev off

**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Graph-layout proxy
local proxy_scheme "`c(tmpdir)'/scheme-kmplot_v129proxy.scheme"
tempname scheme_fh
file open `scheme_fh' using "`proxy_scheme'", write text replace
file write `scheme_fh' "* 7.5 x 4.5 white-background layout proxy" _n
file write `scheme_fh' "#include s2color" _n
file write `scheme_fh' "graphsize x 7.5" _n
file write `scheme_fh' "graphsize y 4.5" _n
file write `scheme_fh' "color background white" _n
file write `scheme_fh' "clockdir legend_position 3" _n
file write `scheme_fh' "numstyle legend_cols 1" _n
file close `scheme_fh'
adopath ++ "`c(tmpdir)'"

**# Regression tests
**## R1: Default endpoint columns align and retain usable edge reserves

local ++test_count
capture noisily {
    clear
    set obs 12000
    generate byte grp = cond(_n <= 6000, 1, 2)
    bysort grp: generate long within = _n
    generate double ftime = 20
    generate byte fail = within <= 2000
    replace ftime = 1 + mod(within - 1, 19) if fail
    label define grplbl 1 "No HRT use" 2 "Current HRT use"
    label values grp grplbl
    stset ftime, failure(fail)

    tempfile svgbase
    local svg "`svgbase'.svg"
    kmplot, by(grp) colors(black gray) lpattern(solid dash) ///
        risktable riskevents riskmono timepoints(0(2)20) ///
        xlabel(0(2)20) scheme(kmplot_v129proxy) ///
        name(v129_default, replace)
    graph display v129_default, xsize(7.5) ysize(4.5)
    graph export "`svg'", as(svg) replace

    local first_n = 0
    local last_n = 0
    local count_n = 0
    local count_x = .
    local group_x = .
    local ytitle_x = .
    local view_width = .
    tempname fh
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "viewBox=") & ///
            regexm(`"`line'"', `"viewBox="0 0 ([0-9.]+) [0-9.]+""') {
            local view_width = real(regexs(1))
        }
        if strpos(`"`line'"', ">0</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ++first_n
            if `first_n' <= 2 local first_x`first_n' = real(regexs(1))
        }
        if strpos(`"`line'"', ">20</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ++last_n
            if `last_n' <= 2 local last_x`last_n' = real(regexs(1))
        }
        if strpos(`"`line'"', ">4,000 (2,000)</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ++count_n
            local count_x = real(regexs(1))
        }
        if strpos(`"`line'"', ">Current HRT use</text>") & ///
            strpos(`"`line'"', `"text-anchor="end""') & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local group_x = real(regexs(1))
        }
        if strpos(`"`line'"', ">No. at risk (events)</text>") & ///
            regexm(`"`line'"', `" x="([0-9.]+)""') {
            local ytitle_x = real(regexs(1))
        }
        file read `fh' line
    }
    file close `fh'

    assert `first_n' == 2
    assert `last_n' == 2
    assert `count_n' == 2
    assert !missing(`view_width', `count_x', `group_x', `ytitle_x')
    assert abs(`first_x1' - `first_x2') < 0.1
    assert abs(`last_x1' - `last_x2') < 0.1
    assert `count_x' <= `view_width' - 200
    assert `group_x' >= 400
    assert `ytitle_x' >= 100
    erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: R1 matched endpoints and edge reserves"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 matched endpoints and edge reserves (rc=`=_rc')"
    local ++fail_count
}

**## R2: Custom x- and y-label specifications retain matched geometry

local ++test_count
capture noisily {
    sysuse cancer, clear
    keep if inlist(drug, 1, 2)
    stset studytime, failure(died)

    tempfile svgbase
    local svg "`svgbase'.svg"
    kmplot, by(drug) risktable riskevents riskmono ///
        timepoints(0 5 10 15 20 25 30 35) ///
        xlabel(0 "Baseline" 35 "End", labsize(medsmall) angle(30)) ///
        ylabel(0 "Zero" .5 "Half" 1 "One", angle(horizontal)) ///
        scheme(s2color) name(v129_custom, replace)
    graph display v129_custom, xsize(7.5) ysize(4.5)
    graph export "`svg'", as(svg) replace

    foreach tag in baseline end zero half one {
        local `tag'_n = 0
    }
    tempname fh
    file open `fh' using "`svg'", read text
    file read `fh' line
    while r(eof) == 0 {
        foreach tag in baseline end zero half one {
            local label = proper("`tag'")
            if strpos(`"`line'"', ">`label'</text>") & ///
                regexm(`"`line'"', `" x="([0-9.]+)""') {
                local ++`tag'_n
                if ``tag'_n' <= 2 local `tag'_x``tag'_n' = real(regexs(1))
            }
        }
        file read `fh' line
    }
    file close `fh'

    foreach tag in baseline end zero half one {
        assert ``tag'_n' == 2
        assert abs(``tag'_x1' - ``tag'_x2') < 0.1
    }
    erase "`svg'"
}
if _rc == 0 {
    display as result "  PASS: R2 custom axis geometry"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 custom axis geometry (rc=`=_rc')"
    local ++fail_count
}

capture erase "`proxy_scheme'"

**# Summary
if `fail_count' > 0 {
    display as error "RESULT: test_kmplot_v129 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "RESULT: test_kmplot_v129 tests=`test_count' pass=`pass_count' fail=`fail_count'"

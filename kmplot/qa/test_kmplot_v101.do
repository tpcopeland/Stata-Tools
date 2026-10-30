* test_kmplot_v101.do
* Regression tests for kmplot 1.0.1: the x axis ends at tmax()
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-10-30
*
* Through 1.0.0 a tmax() that was not one of Stata's default ticks ran on to
* the next one: tmax(12) drew a 0-15 axis with blank space after the curves.
* Without risktable the default labels (0 5 10 15) widened it; with risktable
* the risk panel's hidden bottom axis kept Stata's default ticks, and
* graph combine, xcommon rounded the shared range up again. 1.0.1 labels the
* default risk-table grid (or timepoints() for an xlabel() with sub-options
* only), gives the hidden axis the timepoints, and drops xcommon when tmax()
* is given and the two panels were built on the same range.
*
*   A1-A4  drawn x range of each panel (.graph.plotregion1.xscale) is [0, tmax]
*   B1-B3  risk-table columns sit under the same times on the curve panel,
*          measured in the exported SVG: the curve panel's x labels are drawn
*          invisibly at its own scale, the counts at the table's
*   C1-C3  default labels are the risk-table grid; xlabel() kept; xlabel()
*          with sub-options only labels timepoints() or the grid
*   D1-D5  passthrough xscale()/xtick() that widen still widen both panels
*          together; xline() and x options that do not widen leave [0, tmax];
*          a left-widened curve panel keeps the panels on one range
*   E1     plots without tmax(), or with tmax() on a default tick, keep the
*          1.0.0 ranges
*
* Run from kmplot/qa:  stata-mp -b do test_kmplot_v101.do

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_kmplot_qa_common.do"
quietly do "`qa_dir'/_kmplot_qa_cifsupport.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers
* Drawn x range of a graph, or of panel # of a combined graph.  A missing
* member (wrong name, graph not drawn) is an error, never an empty pass.
capture program drop _v101_xrange
program define _v101_xrange, rclass
    version 16.0
    args gname panel
    if "`panel'" == "" {
        local lo `.`gname'.plotregion1.xscale.curmin'
        local hi `.`gname'.plotregion1.xscale.curmax'
    }
    else {
        local lo `.`gname'.graphs[`panel'].plotregion1.xscale.curmin'
        local hi `.`gname'.graphs[`panel'].plotregion1.xscale.curmax'
    }
    confirm number `lo'
    confirm number `hi'
    return scalar min = `lo'
    return scalar max = `hi'
end

* Both panels of a combined risk-table graph span [lo, hi].
capture program drop _v101_panels
program define _v101_panels
    version 16.0
    args gname lo hi
    forvalues p = 1/2 {
        _v101_xrange `gname' `p'
        assert !missing(r(min), r(max), `lo', `hi')
        assert reldif(r(min), `lo') < 1e-9
        assert reldif(r(max), `hi') < 1e-9
    }
end

* Alignment in the exported SVG.  The curve panel's x labels are drawn with
* labcolor(none) at the curve panel's scale; the bottom risk-table row is
* drawn at the table's.  Every time present in both must sit at the same x,
* to within tol x the curve panel's label span.
capture program drop _v101_align
program define _v101_align, rclass
    version 16.0
    syntax using/, TIMEpoints(numlist) [TOL(real 0.002)]
    preserve
    _kmqa_svgtext using `"`using'"'
    quietly keep if midanc == 1 & rot == 0
    tempfile all main
    quietly save `all'
    * curve panel: invisible numeric x labels
    quietly keep if vis == 0
    quietly gen double val = real(txt)
    quietly keep if val < .
    quietly count
    if r(N) < 2 {
        display as error "fewer than two invisible x labels in the SVG"
        exit 9
    }
    quietly summarize x, meanonly
    local span = r(max) - r(min)
    keep val x
    rename x xmain
    quietly save `main'
    * risk table: the bottom row of visible counts (digits or a masked <#)
    use `all', clear
    quietly keep if vis == 1 & regexm(txt, "^[0-9<]")
    quietly summarize y, meanonly
    quietly keep if abs(y - r(max)) < 1
    sort x
    local ntp : word count `timepoints'
    quietly count
    if r(N) != `ntp' {
        display as error "bottom risk row has " r(N) " columns, expected `ntp'"
        exit 9
    }
    quietly gen double val = .
    forvalues j = 1/`ntp' {
        local t : word `j' of `timepoints'
        quietly replace val = `t' in `j'
    }
    keep val x
    quietly merge 1:1 val using `main', keep(match) nogenerate
    quietly count
    local nmatch = r(N)
    if `nmatch' < 2 {
        display as error "fewer than two times shared by the panels"
        exit 9
    }
    quietly gen double d = abs(x - xmain)
    quietly summarize d, meanonly
    local worst = r(max) / `span'
    display as text "  alignment: `nmatch' shared times, worst offset " ///
        %9.6f `worst' " of the label span"
    return scalar worst = `worst'
    return scalar nmatch = `nmatch'
    assert `worst' < `tol'
end

* Visible x labels of a graph without a risk table, sorted, as a string.
capture program drop _v101_xlabels
program define _v101_xlabels, rclass
    version 16.0
    syntax using/
    preserve
    _kmqa_svgtext using `"`using'"'
    quietly keep if vis == 1 & midanc == 1 & rot == 0
    quietly gen double val = real(txt)
    quietly keep if val < .
    * the x labels share the lowest numeric row
    quietly summarize y, meanonly
    quietly keep if abs(y - r(max)) < 1
    sort val
    local labs ""
    forvalues i = 1/`=_N' {
        local labs "`labs' `=val[`i']'"
    }
    return local labels = strtrim("`labs'")
end

capture program drop _v101_cancer
program define _v101_cancer
    version 16.0
    sysuse cancer, clear
    quietly stset studytime, failure(died)
end

**# A1: risktable, tmax(12): both panels span [0, 12]
local ++test_count
capture noisily {
    _v101_cancer
    kmplot, by(drug) risktable tmax(12) name(v101, replace)
    assert "`r(timepoints)'" == "0 2 4 6 8 10 12"
    * 1.0.0: both panels 0-15
    _v101_panels v101 0 12
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A1 risktable tmax(12): both panels end at 12"
}
else {
    local ++fail_count
    display as error "FAIL: A1 risktable tmax(12): both panels end at 12 (rc=" _rc ")"
}

**# A2: no risktable, tmax(12): the axis spans [0, 12]
local ++test_count
capture noisily {
    _v101_cancer
    kmplot, by(drug) ci tmax(12) name(v101, replace)
    _v101_xrange v101
    assert r(min) == 0
    * 1.0.0: 15
    assert !missing(r(max))
    assert reldif(r(max), 12) < 1e-9
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A2 no risktable tmax(12): axis ends at 12"
}
else {
    local ++fail_count
    display as error "FAIL: A2 no risktable tmax(12): axis ends at 12 (rc=" _rc ")"
}

**# A3: compete(), percent, ci, median and censor marks with tmax(13)
* every layer the curve panel draws, on a competing-risk fixture
local ++test_count
capture noisily {
    _v101_cancer
    gen byte status = died
    replace status = 2 if !died & mod(_n, 3) == 0
    quietly stset studytime, failure(status == 1)
    kmplot, by(drug) compete(status == 2) percent ci censor risktable ///
        tmax(13) name(v101, replace)
    assert "`r(timepoints)'" == "0 3 6 9 12"
    * 1.0.0: both panels 0-15
    _v101_panels v101 0 13
    _v101_cancer
    kmplot, by(drug) median censor pvalue risktable tmax(13) name(v101, replace)
    _v101_panels v101 0 13
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A3 every curve-panel layer stops at tmax(13)"
}
else {
    local ++fail_count
    display as error "FAIL: A3 every curve-panel layer stops at tmax(13) (rc=" _rc ")"
}

**# A4: timepoints() and xlabel() that differ, and a tmax() past the data
local ++test_count
capture noisily {
    _v101_cancer
    kmplot, by(drug) risktable tmax(12) timepoints(0 3 6 9 12) ///
        xlabel(0 4 8 12) name(v101, replace)
    _v101_panels v101 0 12
    * tmax() beyond the longest follow-up (39): the axis still ends at tmax()
    kmplot, by(drug) risktable tmax(44) name(v101, replace)
    _v101_panels v101 0 44
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A4 timepoints()/xlabel() and tmax() past the data"
}
else {
    local ++fail_count
    display as error "FAIL: A4 timepoints()/xlabel() and tmax() past the data (rc=" _rc ")"
}

**# B1: risk-table columns align with the curve panel (tmax(12))
* guard: expected green at pre-fix ref (1.0.0 aligned the panels through xcommon)
local ++test_count
capture noisily {
    _v101_cancer
    local svg "`c(tmpdir)'/kmplot_v101_b1.svg"
    capture erase "`svg'"
    kmplot, by(drug) risktable tmax(12) name(v101, replace)
    local tp "`r(timepoints)'"
    graph export "`svg'", name(v101) replace
    _v101_align using "`svg'", timepoints(`tp')
    assert r(nmatch) == 7
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: B1 risk-table columns align with the curves"
}
else {
    local ++fail_count
    display as error "FAIL: B1 risk-table columns align with the curves (rc=" _rc ")"
}

**# B2: alignment with long group labels, compete() and percent
* guard: expected green at pre-fix ref (1.0.0 aligned the panels through xcommon)
* the label columns of the two panels must come out the same width
local ++test_count
capture noisily {
    _v101_cancer
    label define type 1 "Placebo (reference arm, open label)" ///
        2 "A" 3 "Drug B", modify
    gen byte status = died
    replace status = 2 if !died & mod(_n, 3) == 0
    quietly stset studytime, failure(status == 1)
    local svg "`c(tmpdir)'/kmplot_v101_b2.svg"
    capture erase "`svg'"
    kmplot, by(drug) compete(status == 2) percent ci risktable ///
        tmax(26) name(v101, replace)
    local tp "`r(timepoints)'"
    graph export "`svg'", name(v101) replace
    _v101_align using "`svg'", timepoints(`tp')
    assert r(nmatch) == 6
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: B2 alignment with long labels, compete(), percent"
}
else {
    local ++fail_count
    display as error "FAIL: B2 alignment with long labels, compete(), percent (rc=" _rc ")"
}

**# B3: alignment with timepoints() and xlabel() that differ
* guard: expected green at pre-fix ref (1.0.0 aligned the panels through xcommon)
local ++test_count
capture noisily {
    _v101_cancer
    local svg "`c(tmpdir)'/kmplot_v101_b3.svg"
    capture erase "`svg'"
    kmplot, by(drug) risktable tmax(12) timepoints(0 3 6 9 12) ///
        xlabel(0 4 8 12) combineopts(xsize(9)) name(v101, replace)
    graph export "`svg'", name(v101) replace
    * shared times are 0 and 12
    _v101_align using "`svg'", timepoints(0 3 6 9 12)
    assert r(nmatch) == 2
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: B3 alignment with differing timepoints()/xlabel()"
}
else {
    local ++fail_count
    display as error "FAIL: B3 alignment with differing timepoints()/xlabel() (rc=" _rc ")"
}

**# C1: no risktable: default labels are the risk-table grid
local ++test_count
capture noisily {
    _v101_cancer
    local svg "`c(tmpdir)'/kmplot_v101_c1.svg"
    capture erase "`svg'"
    kmplot, by(drug) tmax(12) name(v101, replace)
    graph export "`svg'", name(v101) replace
    _v101_xlabels using "`svg'"
    * 1.0.0: 0 5 10 15
    assert "`r(labels)'" == "0 2 4 6 8 10 12"
    * the same grid the risk table gets
    kmplot, by(drug) risktable tmax(12) name(v101, replace)
    assert "`r(timepoints)'" == "0 2 4 6 8 10 12"
    * a fractional horizon: step 0.06, axis ends at 0.3
    gen double t100 = studytime / 100
    quietly stset t100, failure(died)
    kmplot, by(drug) tmax(0.3) name(v101, replace)
    _v101_xrange v101
    assert !missing(r(max))
    assert reldif(r(max), 0.3) < 1e-9
    graph export "`svg'", name(v101) replace
    _v101_xlabels using "`svg'"
    assert wordcount("`r(labels)'") == 6
    local last : word 6 of `r(labels)'
    assert !missing(`last')
    assert reldif(`last', 0.3) < 1e-9
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C1 no risktable: default labels are the risk-table grid"
}
else {
    local ++fail_count
    display as error "FAIL: C1 no risktable: default labels are the risk-table grid (rc=" _rc ")"
}

**# C2: no risktable: xlabel() is kept as given
* guard: expected green at pre-fix ref (explicit xlabel() already ended the axis at 12)
local ++test_count
capture noisily {
    _v101_cancer
    local svg "`c(tmpdir)'/kmplot_v101_c2.svg"
    capture erase "`svg'"
    kmplot, by(drug) tmax(12) xlabel(0 3 6 9 12) name(v101, replace)
    graph export "`svg'", name(v101) replace
    _v101_xlabels using "`svg'"
    assert "`r(labels)'" == "0 3 6 9 12"
    _v101_xrange v101
    assert !missing(r(max))
    assert reldif(r(max), 12) < 1e-9
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C2 no risktable: xlabel() kept"
}
else {
    local ++fail_count
    display as error "FAIL: C2 no risktable: xlabel() kept (rc=" _rc ")"
}

**# D1: passthrough xscale(range()) still widens both panels together
* guard: expected green at pre-fix ref (behaviour kept: xcommon stays on)
local ++test_count
capture noisily {
    _v101_cancer
    local svg "`c(tmpdir)'/kmplot_v101_d1.svg"
    capture erase "`svg'"
    kmplot, by(drug) risktable tmax(12) xscale(range(0 20)) name(v101, replace)
    local tp "`r(timepoints)'"
    _v101_panels v101 0 20
    graph export "`svg'", name(v101) replace
    _v101_align using "`svg'", timepoints(`tp')
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: D1 xscale(range(0 20)) widens both panels, aligned"
}
else {
    local ++fail_count
    display as error "FAIL: D1 xscale(range(0 20)) widens both panels, aligned (rc=" _rc ")"
}

**# D2: passthrough xtick() and an abbreviated xsc() keep the panels together
* guard: expected green at pre-fix ref (behaviour kept: xcommon stays on)
local ++test_count
capture noisily {
    _v101_cancer
    kmplot, by(drug) risktable tmax(12) xtick(18) name(v101, replace)
    _v101_xrange v101 1
    local hi1 = r(max)
    _v101_xrange v101 2
    assert !missing(r(max), `hi1')
    assert reldif(r(max), `hi1') < 1e-9
    assert `hi1' >= 18
    kmplot, by(drug) risktable tmax(12) xsc(r(0 16)) name(v101, replace)
    _v101_xrange v101 1
    local hi1 = r(max)
    _v101_xrange v101 2
    assert !missing(r(max), `hi1')
    assert reldif(r(max), `hi1') < 1e-9
    assert `hi1' >= 16
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: D2 xtick() and xsc() keep both panels on one range"
}
else {
    local ++fail_count
    display as error "FAIL: D2 xtick() and xsc() keep both panels on one range (rc=" _rc ")"
}

**# D3: xline() beyond tmax() does not widen either panel
local ++test_count
capture noisily {
    _v101_cancer
    kmplot, by(drug) risktable tmax(12) xline(20) name(v101, replace)
    * 1.0.0: 0-15 (xcommon)
    _v101_panels v101 0 12
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: D3 xline(20) leaves both panels at [0, 12]"
}
else {
    local ++fail_count
    display as error "FAIL: D3 xline(20) leaves both panels at [0, 12] (rc=" _rc ")"
}

**# E1: no tmax(), or tmax() on a default tick: the 1.0.0 ranges
* guard: expected green at pre-fix ref (behaviour-preservation pin)
* Pinned from 1.0.0, which drew these identically: cancer follow-up ends at
* 39, so Stata's default ticks run to 40; tmax(30) is itself a tick.
local ++test_count
capture noisily {
    _v101_cancer
    kmplot, by(drug) risktable name(v101, replace)
    _v101_panels v101 0 40
    kmplot, by(drug) ci risktable median pvalue censor riskevents ///
        timepoints(0 10 20 30) name(v101, replace)
    _v101_panels v101 0 40
    kmplot, by(drug) ci name(v101, replace)
    _v101_xrange v101
    assert !missing(r(min), r(max))
    assert r(min) == 0 & reldif(r(max), 40) < 1e-9
    kmplot, by(drug) risktable tmax(30) name(v101, replace)
    _v101_panels v101 0 30
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: E1 plots without an off-tick tmax() keep the 1.0.0 ranges"
}
else {
    local ++fail_count
    display as error "FAIL: E1 plots without an off-tick tmax() keep the 1.0.0 ranges (rc=" _rc ")"
}

**# C3: xlabel() with sub-options only gets positions
local ++test_count
capture noisily {
    _v101_cancer
    local svg "`c(tmpdir)'/kmplot_v101_c3.svg"
    capture erase "`svg'"
    * no risktable: the default grid (1.0.0: 0-15)
    kmplot, by(drug) tmax(12) xlabel(, angle(45)) name(v101, replace)
    _v101_xrange v101
    assert !missing(r(min), r(max))
    assert r(min) == 0 & reldif(r(max), 12) < 1e-9
    * risktable with timepoints(): the timepoints (1.0.0: 0-15)
    kmplot, by(drug) risktable tmax(12) timepoints(0 4 8 12) ///
        xlabel(, labsize(small)) name(v101, replace)
    assert "`r(timepoints)'" == "0 4 8 12"
    _v101_panels v101 0 12
    graph export "`svg'", name(v101) replace
    _v101_align using "`svg'", timepoints(0 4 8 12)
    assert r(nmatch) == 4
    * risktable without timepoints(): the grid (1.0.0: r(198), no positions)
    kmplot, by(drug) risktable tmax(12) xlabel(, angle(45)) name(v101, replace)
    assert "`r(timepoints)'" == "0 2 4 6 8 10 12"
    _v101_panels v101 0 12
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C3 xlabel() with sub-options only gets positions"
}
else {
    local ++fail_count
    display as error "FAIL: C3 xlabel() with sub-options only gets positions (rc=" _rc ")"
}

**# D4: x options that do not widen leave both panels at [0, tmax]
local ++test_count
capture noisily {
    _v101_cancer
    * 1.0.0: each 0-15 (xcommon)
    foreach o in "xtick(0(2)12)" "xmtick(0(1)12)" "xscale(range(0 12))" ///
        "xscale(noextend)" "xscale(titlegap(5))" {
        kmplot, by(drug) risktable tmax(12) `o' name(v101, replace)
        capture noisily _v101_panels v101 0 12
        if _rc {
            display as error "panels not [0, 12] with `o'"
            exit 9
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: D4 non-widening x options leave both panels at [0, 12]"
}
else {
    local ++fail_count
    display as error "FAIL: D4 non-widening x options leave both panels at [0, 12] (rc=" _rc ")"
}

**# D5: a curve panel widened to the left keeps the panels on one range
* guard: expected green at pre-fix ref (1.0.0 always used xcommon)
local ++test_count
capture noisily {
    _v101_cancer
    local svg "`c(tmpdir)'/kmplot_v101_d5.svg"
    capture erase "`svg'"
    kmplot, by(drug) risktable tmax(12) xscale(range(-3 12)) name(v101, replace)
    local tp "`r(timepoints)'"
    _v101_xrange v101 1
    local lo1 = r(min)
    local hi1 = r(max)
    _v101_xrange v101 2
    assert !missing(r(min), r(max), `lo1', `hi1')
    assert reldif(r(min), `lo1') < 1e-9 & reldif(r(max), `hi1') < 1e-9
    assert `lo1' <= -3
    graph export "`svg'", name(v101) replace
    _v101_align using "`svg'", timepoints(`tp')
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: D5 left-widened curve panel keeps one range"
}
else {
    local ++fail_count
    display as error "FAIL: D5 left-widened curve panel keeps one range (rc=" _rc ")"
}

**# Summary
display "RESULT: test_kmplot_v101 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    exit 1
}

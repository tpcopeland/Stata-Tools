* test_kmplot_v102.do
* Regression tests for kmplot 1.0.2: y-title placement beside a risk table,
* and a legend() that names no keys
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-11-04
*
* Through 1.0.1 the curve panel carried the risk table's group labels as
* invisible y labels, so both panels' label columns came out the same width,
* and Stata set the y title outside that column: a long group label left the
* title far from the visible y labels; anything else that widened one column
* (a large title, wide y labels, an empty title) broke the alignment.  1.0.2
* drops the invisible labels, lays both panels out with graphics off, and pads
* the narrower panel's title margin until the plotting regions line up.
* Through 1.0.1 a legend() without order()/label()/lastlabel() showed Stata's
* default keys, which were kmplot's temporary variable names, and a
* ytitle() margin() with risktable stopped with Stata's r(198).
*
*   A1,A3  the y title's distance from the time origin, read from the
*          exported SVG, is the same with long and with short group labels
*          (failure, compete())
*   A2     ytitle() margin() with risktable is refused (1.0.1: Stata r(198)
*          on a doubled margin()); without risktable it is kept
*   A4     long labels: the risk-table columns still sit under the curve
*          panel's x labels
*   A5     ytitle(""), nodraw, set dp comma: run; c(graphics) restored; no
*          graph left over
*   A6-A8  the panels stay aligned with a large two-line y title, an empty
*          title with wide y labels, and a label too long for the panel (which
*          also prints a note); A8b: in a wider graph that label needs no
*          note; A8c: a label too long to align at all says so
*   A9     combineopts(saving()) is not run by the layout probe
*   A10    a redrawn risk panel (ci, tmax()) prints the first draw's counts
*   B1-B3  legend(position()) keeps the group labels; legend(order()) and
*          legend(label()) are the user's; legend(off) shows none
*   B4     "label (" inside the legend's quoted title is not label()
*   C1-C5  legendpos(): top right for survival and top left for failure by
*          default; the four corners, with risktable and with legend(); the
*          legend and the p-value never share a corner; invalid values
*   D1     byorder() prefers the exact level; ambiguous float matches error
*   D2     export() with combineopts(nodraw) is refused (r(198))
*
* Run from kmplot/qa:  stata-mp -b do test_kmplot_v102.do

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
* Fixture: two groups, rare outcome, value labels set by -long-.
capture program drop _v102_data
program define _v102_data
    version 16.0
    args long
    clear
    set seed 12
    quietly set obs 4000
    quietly gen byte grp = runiform() < 0.3
    if `long' == 3 {
        label define _v102g 0 "Matched population women" 1 "Patients initiating high-efficacy disease-modifying therapy within two years of diagnosis, excluding prior users", replace
    }
    else if `long' == 2 {
        label define _v102g 0 "Matched population women" 1 "Patients initiating high-efficacy disease-modifying therapy within 2 years", replace
    }
    else if `long' {
        label define _v102g 0 "Matched population women" 1 "Anti-CD20 new users on treatment", replace
    }
    else {
        label define _v102g 0 "A" 1 "B", replace
    }
    label values grp _v102g
    quietly gen double t = rexponential(400)
    quietly gen byte d = t < 5
    quietly replace t = min(t, 5)
    quietly gen byte cause = cond(d, 1 + (runiform() < 0.3), 0)
    quietly stset t, failure(d)
end

* Distance, in SVG units, from the visible rotated y title to the curve
* panel's invisible time-zero x label (the time origin).
capture program drop _v102_gap
program define _v102_gap, rclass
    version 16.0
    syntax using/, TItle(string)
    preserve
    _kmqa_svgtext using `"`using'"'
    quietly count if vis == 1 & rot == 1 & txt == `"`title'"'
    if r(N) != 1 {
        display as error `"expected one visible y title "`title'", found "' r(N)
        exit 9
    }
    quietly summarize x if vis == 1 & rot == 1 & txt == `"`title'"', meanonly
    local tx = r(mean)
    quietly count if vis == 0 & rot == 0 & midanc == 1 & txt == "0"
    if r(N) != 1 {
        display as error "expected one invisible time-zero label, found " r(N)
        exit 9
    }
    quietly summarize x if vis == 0 & rot == 0 & midanc == 1 & txt == "0", meanonly
    local ox = r(mean)
    quietly summarize fs if vis == 1 & rot == 1 & txt == `"`title'"', meanonly
    return scalar fs = r(mean)
    return scalar gap = `ox' - `tx'
end

* Same gap from the long-label and the short-label graph, to within a
* quarter of the title's font size.
capture program drop _v102_same_gap
program define _v102_same_gap
    version 16.0
    syntax, TItle(string) [KMopts(string asis)]
    local svg "`c(tmpdir)'/kmplot_v102_gap.svg"
    foreach long in 1 0 {
        _v102_data `long'
        kmplot, by(grp) failure risktable timepoints(0(1)5) ///
            ylabel(, format(%5.3f) angle(horizontal)) `kmopts' name(v102, replace)
        graph export "`svg'", name(v102) replace
        _v102_gap using "`svg'", title(`"`title'"')
        local gap`long' = r(gap)
        local fs = r(fs)
    }
    erase "`svg'"
    display as text "  title gap: long labels " %8.2f `gap1' ", short labels " %8.2f `gap0' " (font " %5.2f `fs' ")"
    assert !missing(`gap1', `gap0', `fs')
    assert `gap0' > 0
    * 1.0.1: the long-label gap was several times the short-label gap
    assert abs(`gap1' - `gap0') < 0.25 * `fs'
end

* Worst horizontal offset, as a share of the time span, between the curve
* panel's invisible x labels at 0..5 and the top risk-table row's counts.
capture program drop _v102_align
program define _v102_align, rclass
    version 16.0
    syntax using/
    preserve
    _kmqa_svgtext using `"`using'"'
    quietly keep if midanc == 1 & rot == 0
    tempfile all main
    quietly save `all'
    quietly keep if vis == 0
    quietly gen double val = real(txt)
    quietly keep if inrange(val, 0, 5)
    assert _N == 6
    quietly summarize x, meanonly
    local span = r(max) - r(min)
    keep val x
    rename x xmain
    quietly save `main'
    use `all', clear
    quietly keep if vis == 1 & regexm(txt, "^[0-9<]")
    quietly summarize y, meanonly
    quietly keep if abs(y - r(max)) < 1
    sort x
    assert _N == 6
    quietly gen double val = _n - 1
    keep val x
    quietly merge 1:1 val using `main', assert(match) nogenerate
    quietly gen double d = abs(x - xmain) / `span'
    quietly summarize d, meanonly
    return scalar worst = r(max)
end

* r(found) = 1 when a text log holds kmplot's squeezed-axis note.
capture program drop _v102_hasnote
program define _v102_hasnote, rclass
    version 16.0
    syntax using/ [, TEXT(string)]
    if `"`text'"' == "" local text "panel too little width, so"
    tempname fh
    local found = 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`text'"') local found = 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

* Where a legend key's text sits: r(right) = 1 when it is right of the
* middle of the x tick labels, r(top) = 1 when above the middle of the y tick
* labels (SVG y grows downward).
capture program drop _v102_legxy
program define _v102_legxy, rclass
    version 16.0
    syntax using/, KEY(string)
    preserve
    _kmqa_svgtext using `"`using'"'
    * legend text is start-anchored; a risk-table row label is end-anchored
    quietly summarize x if vis == 1 & rot == 0 & endanc == 0 & midanc == 0 & txt == `"`key'"', meanonly
    assert r(N) == 1
    local kx = r(mean)
    quietly summarize y if vis == 1 & rot == 0 & endanc == 0 & midanc == 0 & txt == `"`key'"', meanonly
    local ky = r(mean)
    quietly summarize x if vis == 1 & rot == 0 & midanc == 1 & regexm(txt, "^[0-9]+$"), meanonly
    local xmid = (r(min) + r(max)) / 2
    quietly summarize y if vis == 1 & rot == 0 & endanc == 1 & regexm(txt, "^[0-9.]+$"), meanonly
    local ymid = (r(min) + r(max)) / 2
    assert !missing(`kx', `ky', `xmid', `ymid')
    return scalar right = (`kx' > `xmid')
    return scalar top = (`ky' < `ymid')
end

* Text of the visible, unrotated SVG text elements, as a dataset.
capture program drop _v102_texts
program define _v102_texts
    version 16.0
    syntax using/
    _kmqa_svgtext using `"`using'"'
    quietly keep if vis == 1 & rot == 0
end

**# A1: default y title sits at the same distance with long and short labels
local ++test_count
capture restore
capture noisily {
    _v102_same_gap, title("Cumulative incidence (proportion)") ///
        kmopts(ytitle("Cumulative incidence (proportion)"))
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A1 y title beside its labels with long group labels"
}
else {
    local ++fail_count
    display as error "FAIL: A1 y title beside its labels with long group labels (rc=" _rc ")"
}

**# A2: ytitle() margin() with risktable is refused; kept without it
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    * 1.0.1: r(198) from Stata, "option margin() not allowed"
    foreach m in "margin(r=6)" "m(l=1)" "size(small) marg(r=2)" {
        capture noisily kmplot, by(grp) failure risktable ytitle(, `m') name(v102, replace)
        assert _rc == 198
    }
    * bmargin() is a different option
    kmplot, by(grp) failure risktable ytitle(, bmargin(r=1)) name(v102, replace)
    kmplot, by(grp) failure ytitle(, margin(r=6)) name(v102, replace)
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A2 ytitle() margin() refused with risktable only"
}
else {
    local ++fail_count
    display as error "FAIL: A2 ytitle() margin() refused with risktable only (rc=" _rc ")"
}

**# A3: compete(): the CIF panel's title moves in too
local ++test_count
capture restore
capture noisily {
    local svg "`c(tmpdir)'/kmplot_v102_a3.svg"
    foreach long in 1 0 {
        _v102_data `long'
        quietly stset t, failure(cause == 1)
        kmplot, by(grp) compete(cause == 2) risktable timepoints(0(1)5) ///
            ylabel(, format(%5.3f) angle(horizontal)) name(v102, replace)
        graph export "`svg'", name(v102) replace
        _v102_gap using "`svg'", title("Cumulative incidence")
        local gap`long' = r(gap)
        local fs = r(fs)
    }
    erase "`svg'"
    assert !missing(`gap1', `gap0')
    assert abs(`gap1' - `gap0') < 0.25 * `fs'
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A3 compete() title beside its labels"
}
else {
    local ++fail_count
    display as error "FAIL: A3 compete() title beside its labels (rc=" _rc ")"
}

**# A4: long labels: risk-table columns still under the curve panel's x labels
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local svg "`c(tmpdir)'/kmplot_v102_a4.svg"
    kmplot, by(grp) failure risktable timepoints(0(1)5) ///
        ytitle("Cumulative incidence (proportion)") ///
        ylabel(, format(%5.3f) angle(horizontal)) name(v102, replace)
    graph export "`svg'", name(v102) replace
    _v102_align using "`svg'"
    erase "`svg'"
    display as text "  worst column offset " %9.6f r(worst) " of the time span"
    assert r(worst) < 0.002
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A4 long labels: panels stay aligned"
}
else {
    local ++fail_count
    display as error "FAIL: A4 long labels: panels stay aligned (rc=" _rc ")"
}

**# A5: ytitle(""), nodraw; graphics setting restored; no graph left over
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local gr0 "`c(graphics)'"
    graph drop _all
    kmplot, by(grp) failure risktable timepoints(0(1)5) ytitle("") name(v102, replace)
    assert "`c(graphics)'" == "`gr0'"
    kmplot, by(grp) failure risktable timepoints(0(1)5) nodraw name(v102b, replace)
    assert "`c(graphics)'" == "`gr0'"
    * set dp comma must not reach the title margin (a decimal comma there
    * was a syntax error)
    set dp comma
    capture noisily kmplot, by(grp) failure risktable timepoints(0(1)5) name(v102c, replace)
    local dprc = _rc
    set dp period
    assert `dprc' == 0
    quietly graph dir
    local left "`r(list)'"
    local left : list sort left
    assert "`left'" == "v102 v102b v102c"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A5 empty ytitle and nodraw; no state left behind"
}
else {
    local ++fail_count
    display as error "FAIL: A5 empty ytitle and nodraw; no state left behind (rc=" _rc ")"
}

**# A6-A8: the panels align whatever widens one y-axis column
* 1.0.1 equalised the two columns by giving both the same label strings, so
* anything else that widened one column moved its time axis: a large y title,
* an empty title against "No. at risk", or a label too long for the panel
* (Stata then compresses the column).  1.0.2 measures and pads.
foreach case in A6 A7 A8 {
    local ++test_count
    capture restore
    capture noisily {
        local svg "`c(tmpdir)'/kmplot_v102_`case'.svg"
        if "`case'" == "A6" {
            _v102_data 0
            local what "a two-line large y title"
            kmplot, by(grp) failure risktable timepoints(0(1)5) ///
                ytitle("Cumulative" "incidence (proportion)", size(large)) name(v102, replace)
        }
        else if "`case'" == "A7" {
            _v102_data 0
            local what "an empty y title with wide y labels"
            kmplot, by(grp) failure risktable timepoints(0(1)5) ytitle("") ///
                ylabel(, format(%9.6f) angle(horizontal)) name(v102, replace)
        }
        else {
            _v102_data 2
            local what "a 74-character group label"
            * The labels leave the curve panel less room than its legend
            * needs: Stata squeezes its y axis, kmplot still aligns the table
            * and says how to make room.
            local lg "`c(tmpdir)'/kmplot_v102_a8.log"
            quietly log using "`lg'", text replace name(_v102a8)
            kmplot, by(grp) failure risktable timepoints(0(1)5) ///
                ytitle("Cumulative incidence (proportion)") ///
                ylabel(, format(%5.3f) angle(horizontal)) name(v102, replace)
            quietly log close _v102a8
            _v102_hasnote using "`lg'"
            assert r(found) == 1
            erase "`lg'"
        }
        graph export "`svg'", name(v102) replace
        _v102_align using "`svg'"
        display as text "  worst column offset " %9.6f r(worst) " of the time span"
        assert r(worst) < 0.002
        erase "`svg'"
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: `case' panels aligned with `what'"
    }
    else {
        local ++fail_count
        display as error "FAIL: `case' panels aligned with `what' (rc=" _rc ")"
    }
}

**# A8b: with room (a wider graph) the long label needs no squeeze and no note
local ++test_count
capture restore
capture noisily {
    _v102_data 2
    local lg "`c(tmpdir)'/kmplot_v102_a8b.log"
    local svg "`c(tmpdir)'/kmplot_v102_a8b.svg"
    quietly log using "`lg'", text replace name(_v102a8b)
    kmplot, by(grp) failure risktable timepoints(0(1)5) ///
        ytitle("Cumulative incidence (proportion)") ///
        ylabel(, format(%5.3f) angle(horizontal)) combineopts(xsize(10)) name(v102, replace)
    quietly log close _v102a8b
    _v102_hasnote using "`lg'"
    assert r(found) == 0
    erase "`lg'"
    graph export "`svg'", name(v102) replace
    _v102_align using "`svg'"
    assert r(worst) < 0.002
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A8b long label in a wider graph: aligned, no note"
}
else {
    local ++fail_count
    display as error "FAIL: A8b long label in a wider graph: aligned, no note (rc=" _rc ")"
}

**# A8c: a label too long to align at all says so
local ++test_count
capture restore
capture noisily {
    _v102_data 3
    local lg "`c(tmpdir)'/kmplot_v102_a8c.log"
    quietly log using "`lg'", text replace name(_v102a8c)
    kmplot, by(grp) failure risktable timepoints(0(1)5) name(v102, replace)
    quietly log close _v102a8c
    _v102_hasnote using "`lg'", text("panel too little width to")
    assert r(found) == 1
    erase "`lg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A8c unalignable label prints its note"
}
else {
    local ++fail_count
    display as error "FAIL: A8c unalignable label prints its note (rc=" _rc ")"
}

**# A9: combineopts(saving()) acts once, on the plot, not on the layout probe
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local gph "`c(tmpdir)'/kmplot_v102_a9.gph"
    capture erase "`gph'"
    * saving() without replace: a probe that saved first made this fail
    kmplot, by(grp) failure risktable timepoints(0(1)5) ///
        combineopts(saving("`gph'")) name(v102, replace)
    confirm file "`gph'"
    * the saved file is the drawn plot, the final combine named v102, not
    * the probe (which carries a temporary name)
    graph describe "`gph'"
    assert strpos(`"`r(command)'"', "combine ") == 1
    assert strpos(`"`r(command)'"', "name(v102,") > 0
    erase "`gph'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A9 combineopts(saving()) saved once"
}
else {
    local ++fail_count
    display as error "FAIL: A9 combineopts(saving()) saved once (rc=" _rc ")"
}

**# A10: a redrawn risk panel prints the counts of the first draw
* A large y title makes kmplot redraw the risk panel with a wider title
* margin, from the rows the first draw saw: the plot-only rows that ci and
* tmax() add later must not enter the counts.
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local N0 = _N
    local svg "`c(tmpdir)'/kmplot_v102_a10.svg"
    foreach big in 0 1 {
        local yt ""
        if `big' local yt `"ytitle("Cumulative" "incidence", size(vlarge))"'
        kmplot, by(grp) failure ci tmax(4) risktable riskevents timepoints(0(1)4) ///
            `yt' name(v102, replace)
        matrix _v102_rt`big' = r(risktable)
        graph export "`svg'", name(v102) replace
        preserve
        _v102_texts using "`svg'"
        quietly keep if regexm(txt, "^[0-9][0-9,]* \([0-9,]+\)$")
        assert _N == 10
        sort txt
        quietly levelsof txt, local(cells`big') clean separate(|)
        restore
    }
    erase "`svg'"
    assert _N == `N0'
    assert mreldif(_v102_rt0, _v102_rt1) == 0
    assert `"`cells0'"' == `"`cells1'"'
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: A10 redrawn risk panel keeps its counts"
}
else {
    local ++fail_count
    display as error "FAIL: A10 redrawn risk panel keeps its counts (rc=" _rc ")"
}

**# B1: legend() that only places the legend keeps the group labels
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local svg "`c(tmpdir)'/kmplot_v102_b1.svg"
    kmplot, by(grp) failure legend(position(11) ring(0) cols(1)) name(v102, replace)
    graph export "`svg'", name(v102) replace
    preserve
    _v102_texts using "`svg'"
    erase "`svg'"
    * 1.0.1: both keys read __00000#
    quietly count if substr(txt, 1, 2) == "__"
    assert r(N) == 0
    quietly count if txt == "Matched population women"
    assert r(N) == 1
    quietly count if txt == "Anti-CD20 new users on treatment"
    assert r(N) == 1
    restore
    * the same with a risk table: legend + table row
    kmplot, by(grp) failure risktable legend(position(11) ring(0)) name(v102, replace)
    graph export "`svg'", name(v102) replace
    preserve
    _v102_texts using "`svg'"
    erase "`svg'"
    quietly count if substr(txt, 1, 2) == "__"
    assert r(N) == 0
    quietly count if txt == "Anti-CD20 new users on treatment"
    assert r(N) == 2
    restore
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: B1 legend(position()) keeps the group labels"
}
else {
    local ++fail_count
    display as error "FAIL: B1 legend(position()) keeps the group labels (rc=" _rc ")"
}

**# B2: legend(order()) and legend(label()) are the user's own
local ++test_count
capture restore
capture noisily {
    _v102_data 0
    local svg "`c(tmpdir)'/kmplot_v102_b2.svg"
    kmplot, by(grp) failure legend(order(2 "Second" 1 "First")) name(v102, replace)
    graph export "`svg'", name(v102) replace
    preserve
    _v102_texts using "`svg'"
    quietly count if inlist(txt, "Second", "First")
    assert r(N) == 2
    quietly count if inlist(txt, "A", "B")
    assert r(N) == 0
    * "Second" is the first key: above "First", or level with it and left
    quietly summarize y if txt == "Second", meanonly
    local y2 = r(mean)
    quietly summarize x if txt == "Second", meanonly
    local x2 = r(mean)
    quietly summarize y if txt == "First", meanonly
    local y1 = r(mean)
    quietly summarize x if txt == "First", meanonly
    assert `y2' < `y1' - 1 | (abs(`y2' - `y1') <= 1 & `x2' < r(mean))
    restore
    * label(): had kmplot prepended order(# "label"), label() could not
    * change the text
    kmplot, by(grp) failure legend(label(1 "Relabelled") position(6)) name(v102, replace)
    graph export "`svg'", name(v102) replace
    preserve
    _v102_texts using "`svg'"
    erase "`svg'"
    quietly count if txt == "Relabelled"
    assert r(N) == 1
    restore
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: B2 legend(order()) and legend(label()) kept"
}
else {
    local ++fail_count
    display as error "FAIL: B2 legend(order()) and legend(label()) kept (rc=" _rc ")"
}

**# B3: legend(off) still shows no keys
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local svg "`c(tmpdir)'/kmplot_v102_b3.svg"
    kmplot, by(grp) failure legend(off) name(v102, replace)
    graph export "`svg'", name(v102) replace
    preserve
    _v102_texts using "`svg'"
    erase "`svg'"
    quietly count if inlist(txt, "Matched population women", "Anti-CD20 new users on treatment")
    assert r(N) == 0
    quietly count if substr(txt, 1, 2) == "__"
    assert r(N) == 0
    restore
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: B3 legend(off) shows no keys"
}
else {
    local ++fail_count
    display as error "FAIL: B3 legend(off) shows no keys (rc=" _rc ")"
}

**# B4: words in the legend's quoted text are not key options
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local svg "`c(tmpdir)'/kmplot_v102_b4.svg"
    kmplot, by(grp) failure legend(title("Per label (n)") position(6)) name(v102, replace)
    graph export "`svg'", name(v102) replace
    preserve
    _v102_texts using "`svg'"
    erase "`svg'"
    * reviewer finding: the title's "label (" read as label() and the keys
    * fell back to temporary variable names
    quietly count if substr(txt, 1, 2) == "__"
    assert r(N) == 0
    quietly count if txt == "Anti-CD20 new users on treatment"
    assert r(N) == 1
    restore
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: B4 legend title text is not read as options"
}
else {
    local ++fail_count
    display as error "FAIL: B4 legend title text is not read as options (rc=" _rc ")"
}

**# C1: legendpos() default: top right for survival, top left for failure
* 1.0.1 put every default legend top right, over rising failure curves.
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local svg "`c(tmpdir)'/kmplot_v102_c1.svg"
    local key "Matched population women"
    foreach spec in "" "failure" "compete" {
        if "`spec'" == "compete" {
            quietly stset t, failure(cause == 1)
            kmplot, by(grp) compete(cause == 2) name(v102, replace)
        }
        else {
            quietly stset t, failure(d)
            kmplot, by(grp) `spec' name(v102, replace)
        }
        local want = cond("`spec'" == "", "topright", "topleft")
        assert "`r(legendpos)'" == "`want'"
        graph export "`svg'", name(v102) replace
        _v102_legxy using "`svg'", key("`key'")
        assert r(top) == 1
        assert r(right) == ("`want'" == "topright")
    }
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C1 legend top right for survival, top left for failure"
}
else {
    local ++fail_count
    display as error "FAIL: C1 legend top right for survival, top left for failure (rc=" _rc ")"
}

**# C2: legendpos() puts the legend in each corner, with and without risktable
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local svg "`c(tmpdir)'/kmplot_v102_c2.svg"
    local key "Matched population women"
    foreach rt in "" "risktable" {
        foreach c in topleft topright bottomleft bottomright {
            kmplot, by(grp) failure `rt' legendpos(`c') name(v102, replace)
            assert "`r(legendpos)'" == "`c'"
            graph export "`svg'", name(v102) replace
            _v102_legxy using "`svg'", key("`key'")
            assert r(top) == (substr("`c'", 1, 3) == "top")
            assert r(right) == (strpos("`c'", "right") > 0)
        }
    }
    erase "`svg'"
    * case-insensitive, abbreviated to legendp()
    kmplot, by(grp) legendp(BottomLeft) name(v102, replace)
    assert "`r(legendpos)'" == "bottomleft"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C2 legendpos() corners"
}
else {
    local ++fail_count
    display as error "FAIL: C2 legendpos() corners (rc=" _rc ")"
}

**# C3: legendpos() with legend(): the corner, the user's styling, the user's
* own position() wins
local ++test_count
capture restore
capture noisily {
    * short keys, so a one-row legend still sits wholly in its corner
    _v102_data 0
    local svg "`c(tmpdir)'/kmplot_v102_c3.svg"
    kmplot, by(grp) failure legendpos(bottomright) legend(rows(1)) name(v102, replace)
    assert "`r(legendpos)'" == "bottomright"
    graph export "`svg'", name(v102) replace
    _v102_legxy using "`svg'", key("A")
    assert r(top) == 0 & r(right) == 1
    * rows(1): both keys on one line
    preserve
    _v102_texts using "`svg'"
    quietly summarize y if txt == "A", meanonly
    local y1 = r(mean)
    quietly summarize y if txt == "B", meanonly
    assert abs(r(mean) - `y1') < 1
    restore
    _v102_data 1
    * an explicit position() in legend() is the user's: no corner reported
    kmplot, by(grp) failure legendpos(bottomright) legend(position(11) ring(0)) name(v102, replace)
    assert "`r(legendpos)'" == ""
    graph export "`svg'", name(v102) replace
    _v102_legxy using "`svg'", key("Matched population women")
    assert r(top) == 1 & r(right) == 0
    * position() nested in a suboption is not the legend's own
    kmplot, by(grp) failure legendpos(topleft) legend(title("Groups", position(6))) name(v102, replace)
    assert "`r(legendpos)'" == "topleft"
    * ring(0) alone keeps the corner (it is where legendpos() put it), so the
    * p-value clash is still caught; ring(1) moves the legend out of the plot
    kmplot, by(grp) failure legendpos(topleft) legend(ring(0) rows(2)) name(v102, replace)
    assert "`r(legendpos)'" == "topleft"
    capture noisily kmplot, by(grp) failure pvalue pvaluepos(topleft) legendpos(topleft) ///
        legend(ring(0) rows(2)) name(v102, replace)
    assert _rc == 198
    kmplot, by(grp) failure legendpos(topleft) legend(ring(1)) name(v102, replace)
    assert "`r(legendpos)'" == ""
    * a legend() without legendpos() is placed by Stata, as before
    kmplot, by(grp) failure legend(rows(1)) name(v102, replace)
    assert "`r(legendpos)'" == ""
    * legend(off) wins
    kmplot, by(grp) failure legend(off) legendpos(topright) name(v102, replace)
    assert "`r(legendpos)'" == ""
    graph export "`svg'", name(v102) replace
    preserve
    _v102_texts using "`svg'"
    quietly count if txt == "Matched population women"
    assert r(N) == 0
    restore
    erase "`svg'"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C3 legendpos() with legend()"
}
else {
    local ++fail_count
    display as error "FAIL: C3 legendpos() with legend() (rc=" _rc ")"
}

**# C4: the legend and the p-value never share a corner
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    * both named: refused
    capture noisily kmplot, by(grp) pvalue legendpos(bottomright) pvaluepos(bottomright) name(v102, replace)
    assert _rc == 198
    * legend named: the default p-value corner moves to the next empty one
    kmplot, by(grp) failure pvalue legendpos(bottomright) name(v102, replace)
    assert "`r(legendpos)'" == "bottomright" & "`r(pvalue_pos)'" == "topleft"
    kmplot, by(grp) pvalue legendpos(bottomright) name(v102, replace)
    assert "`r(legendpos)'" == "bottomright" & "`r(pvalue_pos)'" == "bottomleft"
    * p-value named: the automatic legend moves instead
    kmplot, by(grp) failure pvalue pvaluepos(topleft) name(v102, replace)
    assert "`r(legendpos)'" == "bottomright" & "`r(pvalue_pos)'" == "topleft"
    kmplot, by(grp) pvalue pvaluepos(topright) name(v102, replace)
    assert "`r(legendpos)'" == "bottomleft" & "`r(pvalue_pos)'" == "topright"
    * no clash, nothing moves
    kmplot, by(grp) failure pvalue name(v102, replace)
    assert "`r(legendpos)'" == "topleft" & "`r(pvalue_pos)'" == "bottomright"
    * legendpos(auto) names no corner: the automatic legend still moves
    kmplot, by(grp) pvalue pvaluepos(topright) legendpos(auto) name(v102, replace)
    assert "`r(legendpos)'" == "bottomleft" & "`r(pvalue_pos)'" == "topright"
    * a pos() inside a legend() suboption places that suboption, not the
    * legend: the corner still counts, so the p-value moves
    kmplot, by(grp) pvalue legendpos(bottomright) legend(title("Groups", pos(6))) name(v102, replace)
    assert "`r(legendpos)'" == "bottomright" & "`r(pvalue_pos)'" == "bottomleft"
    * pvalueat() places the p-value by coordinates: no corner to share
    kmplot, by(grp) failure pvalue pvalueat(0.001 1) legendpos(bottomright) name(v102, replace)
    assert "`r(legendpos)'" == "bottomright"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C4 legend and p-value corners"
}
else {
    local ++fail_count
    display as error "FAIL: C4 legend and p-value corners (rc=" _rc ")"
}

**# C5: legendpos() refuses other values; one group still has no legend
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    foreach bad in "middle" "1" "top left" "auto topleft" {
        capture noisily kmplot, by(grp) legendpos(`bad') name(v102, replace)
        assert _rc == 198
    }
    kmplot, by(grp) legendpos(auto) failure name(v102, replace)
    assert "`r(legendpos)'" == "topleft"
    kmplot, legendpos(topleft) name(v102, replace)
    assert "`r(legendpos)'" == ""
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: C5 legendpos() values; one group, no legend"
}
else {
    local ++fail_count
    display as error "FAIL: C5 legendpos() values; one group, no legend (rc=" _rc ")"
}

**# D1: byorder() takes the exact level; two float-precision matches are refused
* Through 1.0.1 the last level equal at float precision won, so byorder(.1)
* could put .10000000001 first at rc 0.
local ++test_count
capture restore
capture noisily {
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly gen double dv = cond(drug == 1, .1, cond(drug == 2, .10000000001, .5))
    kmplot, by(dv) byorder(.1) landmark(10) nodraw
    matrix L = r(landmarks)
    * the first group is dv == .1 (drug 1): its S(10) from sts list
    quietly sts generate s_km = s if dv == .1
    quietly summarize s_km if dv == .1 & _t <= 10, meanonly
    local want = r(min)
    assert reldif(L[1, 3], `want') < 1e-10
    * a float by() variable typed in decimal still matches
    quietly gen float fv = cond(drug == 1, .1, cond(drug == 2, .2, .3))
    kmplot, by(fv) byorder(.2 .1) nodraw
    * two levels equal at float precision and neither exact: refused
    quietly gen double dv2 = cond(drug == 1, .1000000001, cond(drug == 2, .10000000001, .5))
    capture noisily kmplot, by(dv2) byorder(.1) nodraw
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: D1 byorder() exact level first, ambiguity refused"
}
else {
    local ++fail_count
    display as error "FAIL: D1 byorder() exact level first, ambiguity refused (rc=" _rc ")"
}

**# D2: export() with combineopts(nodraw) is refused like nodraw
local ++test_count
capture restore
capture noisily {
    _v102_data 1
    local png "`c(tmpdir)'/kmplot_v102_d2.png"
    capture erase "`png'"
    * 1.0.1: graph export's own r(693), "could not find Graph window"
    capture noisily kmplot, by(grp) failure risktable combineopts(nodraw) ///
        export("`png'", replace) name(v102, replace)
    assert _rc == 198
    capture confirm file "`png'"
    assert _rc == 601
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: D2 export() with combineopts(nodraw) refused"
}
else {
    local ++fail_count
    display as error "FAIL: D2 export() with combineopts(nodraw) refused (rc=" _rc ")"
}

**# Summary
display "RESULT: test_kmplot_v102 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    exit 1
}

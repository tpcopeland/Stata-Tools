* test_v190_weights_graphs.do -- psdash weights graph aesthetics (v1.9.0)
* Author: Timothy P Copeland, Karolinska Institutet
*
* Fail-on-old (psdash 1.8.x): the binary histogram plotted raw frequencies
* with a "Frequency" ytitle, forced title(size(medsmall)) and axis-title /
* label sizes, a %4.2f / %9.0gc y format, had no key for the dashed weight = 1
* line, and a user xlabel() never limited the displayed range (the sparse far
* tail drew flat segments at y ~ 0). Assertions read real graph state: the
* in-memory serset behind each histogram plot and the executed graph command.
* Display only: every r() statistic stays computed on all weights.
version 16.0
capture log close _all
log using test_v190_weights_graphs.log, replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
local tests = 0
local pass = 0
local fail = 0
local failed ""


capture program drop _v190_ser
* Serset behind plot `p' of graph `g': sum of bar heights, max bin centre.
* The plot's own y and x columns are read through .yvar/.xvar, so the helper
* works whether the plots share one serset (twoway bar) or not (histogram).
* With keep, the plot's (h x) pairs are left in memory as variables h and x.
program define _v190_ser, rclass
    args g p keep
    local s = `.`g'.plotregion1.plot`p'.serset.id'
    local iy = `.`g'.plotregion1.plot`p'.yvar'
    local ix = `.`g'.plotregion1.plot`p'.xvar'
    if "`keep'" == "" preserve
    serset set `s'
    serset use, clear
    quietly ds
    local vy : word `iy' of `r(varlist)'
    local vx : word `ix' of `r(varlist)'
    keep `vy' `vx'
    rename `vy' h
    rename `vx' x
    quietly drop if missing(h) & missing(x)
    quietly summarize h
    return scalar hsum = r(sum)
    return scalar hmax = r(max)
    quietly summarize x
    return scalar xmax = r(max)
    return scalar xmin = r(min)
    if "`keep'" == "" restore
end

* Binary fixture: unequal arms (30% treated), weights 1-4 plus a 3-weight tail
capture program drop _v190_bin
program define _v190_bin
    args tail
    clear
    set seed 20261029
    set obs 800
    gen byte t = runiform() < .3
    gen double ps = .5
    gen double w = 1 + 3 * runiform()
    if "`tail'" == "tail" replace w = 30 in 1/3
end

**# fraction scaling and ytitle (no tail)
capture noisily {
    _v190_bin none
    quietly psdash weights t ps, wvar(w) graph name(v190_a, replace)
    graph describe v190_a
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "frequency") == 0
    assert strpos(`"`cmd'"', `"ytitle("Fraction")"') > 0
    * each arm's bars sum to one (within-arm fraction), not to arm counts
    _v190_ser v190_a 1
    assert abs(r(hsum) - 1) < 1e-6
    _v190_ser v190_a 2
    assert abs(r(hsum) - 1) < 1e-6
    * nothing is cut off: no omitted note, dashed line explained
    assert strpos(`"`cmd'"', "omitted") == 0
    assert strpos(`"`cmd'"', "Dashed line: weight = 1") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' fraction_ytitle_dashed_note"
}
else local ++pass

**# scheme-default text sizes and default y axis format
capture noisily {
    _v190_bin none
    quietly psdash weights t ps, wvar(w) graph name(v190_b, replace)
    graph describe v190_b
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "size(") == 0
    assert strpos(`"`cmd'"', "labsize(") == 0
    assert strpos(`"`cmd'"', "format(") == 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' scheme_default_sizes"
}
else local ++pass

**# truncated tail: same rule and wording as the multi-group path
capture noisily {
    _v190_bin tail
    quietly psdash weights t ps, wvar(w) graph name(v190_c, replace)
    graph describe v190_c
    local cmd `"`r(command)'"'
    assert regexm(`"`cmd'"', "([0-9]+) weights above ([0-9.]+) omitted")
    local up = real(regexs(2))
    quietly count if w > `up'
    local nclip = r(N)
    assert `nclip' == 3
    assert strpos(`"`cmd'"', "`nclip' weights above `up' omitted; maximum = 30") > 0
    _v190_ser v190_c 2
    assert r(xmax) <= `up'
    _v190_ser v190_c 1
    assert r(xmax) <= `up'
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' tail_truncated_note"
}
else local ++pass

**# a user xlabel() sets the displayed limit and the note stays truthful
capture noisily {
    _v190_bin tail
    quietly psdash weights t ps, wvar(w) graph xlabel(0 2 4) name(v190_d, replace)
    graph describe v190_d
    local cmd `"`r(command)'"'
    quietly count if w > 4
    local nclip = r(N)
    assert strpos(`"`cmd'"', "xlabel(0 2 4)") > 0
    assert strpos(`"`cmd'"', "`nclip' weights above 4 omitted; maximum = 30") > 0
    _v190_ser v190_d 2
    assert r(xmax) <= 4

    * a user axis wider than the data cuts nothing: no note
    quietly psdash weights t ps, wvar(w) graph xlabel(0(10)40) name(v190_e, replace)
    graph describe v190_e
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "omitted") == 0
    _v190_ser v190_e 1
    assert !missing(r(xmax))
    assert r(xmax) > 29

    * user xlabel() above the bulk but below the max still truthful (demo style)
    _v190_bin none
    quietly psdash weights t ps, wvar(w) graph xlabel(0(3)15) name(v190_f, replace)
    graph describe v190_f
    assert strpos(`"`r(command)'"', "omitted") == 0

    * xscale() in graphoptions() hands the whole axis to the user: no cut, no note
    _v190_bin tail
    quietly psdash weights t ps, wvar(w) graph graphoptions(xscale(range(0 35))) name(v190_g, replace)
    graph describe v190_g
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', "omitted") == 0
    assert strpos(`"`cmd'"', "xscale(range(0 35))") > 0
    _v190_ser v190_g 1
    assert !missing(r(xmax))
    assert r(xmax) > 29
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' user_xlabel_xscale"
}
else local ++pass

**# multi-group path: fraction, default y labels, same note wording, consistent user xlabel
capture noisily {
    clear
    set seed 20261029
    set obs 900
    gen byte a = mod(_n, 3)
    gen double p0 = .3
    gen double p1 = .3
    gen double p2 = .4
    gen double w = 1 + 3 * runiform()
    replace w = 30 in 1/4
    quietly psdash weights a, psvars(p0 p1 p2) wvar(w) graph name(v190_m1, replace)
    graph describe v190_m1
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', `"ytitle("Fraction")"') > 0
    assert strpos(`"`cmd'"', "frequency") == 0
    assert strpos(`"`cmd'"', "format(") == 0
    assert strpos(`"`cmd'"', "size(") == 0
    assert strpos(`"`cmd'"', "Dashed line: weight = 1") > 0
    assert regexm(`"`cmd'"', "([0-9]+) weights above ([0-9.]+) omitted")
    local up = real(regexs(2))
    quietly count if w > `up'
    local nclip = r(N)
    assert strpos(`"`cmd'"', "`nclip' weights above `up' omitted; maximum = 30") > 0

    quietly psdash weights a, psvars(p0 p1 p2) wvar(w) graph xlabel(0 2 4) name(v190_m2, replace)
    graph describe v190_m2
    local cmd `"`r(command)'"'
    quietly count if w > 4
    local nclip = r(N)
    assert strpos(`"`cmd'"', "`nclip' weights above 4 omitted; maximum = 30") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' multigroup_consistent"
}
else local ++pass

**# binary dashboard weights panel inherits the changes
capture noisily {
    _v190_bin tail
    quietly psdash combined t ps, wvar(w) nooverlap nosupport nobalance
    graph describe psdash_c_weights
    local cmd `"`r(command)'"'
    assert strpos(`"`cmd'"', `"ytitle("Fraction""') > 0
    * a dashboard panel fixes small text so larger-type schemes still fit
    assert strpos(`"`cmd'"', "size(small)") > 0
    assert strpos(`"`cmd'"', "3 weights above") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' dashboard_panel"
}
else local ++pass

**# displayed range never changes returned statistics
capture noisily {
    _v190_bin tail
    quietly psdash weights t ps, wvar(w)
    local names : r(scalars)
    foreach n of local names {
        local base_`n' = r(`n')
    }
    quietly psdash weights t ps, wvar(w) graph xlabel(0 2 4) name(v190_r, replace)
    foreach n of local names {
        assert missing(`base_`n'') == missing(r(`n'))
        if !missing(`base_`n'') {
            assert !missing(`base_`n'', r(`n'))
            assert reldif(`base_`n'', r(`n')) < 1e-12
        }
    }
    assert abs(r(max_wt) - 30) < 1e-9
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' returns_unchanged"
}
else local ++pass

**# fix 1: a clipped arm's bars are fractions of ALL of the arm's weights
* Oracle: counts per bin computed here from the fixture by hand (bin j covers
* [start + (j-1)bw, start + j bw), start = the arm's smallest shown weight,
* bw = the spacing of the plotted bin centres), divided by the arm's full N.
* psdash 1.9.0 (pre-fix) drew fractions of the displayed weights only, so the
* clipped control arm summed to 1 and every bar was 100/80 too tall.
capture noisily {
    clear
    set seed 41
    set obs 300
    gen byte t = _n <= 200
    gen double ps = .5
    gen double w = cond(t, 1 + runiform(), 1 + 2 * runiform())
    replace w = 25 if !t & _n > 280
    quietly count if !t
    local n0 = r(N)
    quietly count if !t & w <= 3
    local k0 = r(N)
    assert `n0' == 100 & `k0' == 80
    tempfile fx
    save `fx'
    quietly psdash weights t ps, wvar(w) graph xlabel(0 1 2 3) name(v190_o1, replace)
    graph describe v190_o1
    assert strpos(`"`r(command)'"', "20 weights above 3 omitted; maximum = 25") > 0
    * treated arm: nothing omitted, bars sum to 1
    _v190_ser v190_o1 1
    assert abs(r(hsum) - 1) < 1e-6
    * control arm: bars sum to kept / all = 0.8, and bin by bin
    * bin width = the drawn bar width; only occupied bins are plotted, so
    * each bar is matched to its bin by its centre, not by its row
    local bw = `.v190_o1.plotregion1.plot2.bar_size'
    assert `bw' > 0 & `bw' < .
    _v190_ser v190_o1 2 keep
    assert abs(r(hsum) - `k0' / `n0') < 1e-6
    local nb = _N
    mkmat h x, matrix(V190H)
    use `fx', clear
    quietly summarize w if !t & w <= 3
    local start = r(min)
    local kmax = 0
    forvalues j = 1/`nb' {
        local kmax = max(`kmax', round((V190H[`j', 2] - `start') / `bw' - .5))
    }
    gen long bin = floor((w - `start') / `bw') if !t & w <= 3
    replace bin = `kmax' if bin > `kmax' & !missing(bin)
    local hsum = 0
    forvalues j = 1/`nb' {
        local k = round((V190H[`j', 2] - `start') / `bw' - .5)
        quietly count if bin == `k'
        assert !missing(r(N))
        assert r(N) > 0
        assert abs(V190H[`j', 1] - r(N) / `n0') < 1e-6
    }
    * every kept control weight lands in a drawn bar
    quietly count if !missing(bin)
    assert r(N) == `k0'
    matrix drop V190H

    * multi-group default axis: the arm whose tail is cut keeps its true scale
    clear
    set seed 42
    set obs 900
    gen byte a = mod(_n, 3)
    gen double p0 = .3
    gen double p1 = .3
    gen double p2 = .4
    gen double w = 1 + 3 * runiform()
    replace w = 30 if a == 2 & _n <= 15
    quietly count if a == 2
    local na = r(N)
    quietly psdash weights a, psvars(p0 p1 p2) wvar(w) graph name(v190_o2, replace)
    graph describe v190_o2
    assert regexm(`"`r(command)'"', "([0-9]+) weights above ([0-9.]+) omitted")
    local up = real(regexs(2))
    quietly count if a == 2 & w <= `up'
    local ka = r(N)
    assert `ka' < `na'
    _v190_ser v190_o2 3
    assert abs(r(hsum) - `ka' / `na') < 1e-6
    _v190_ser v190_o2 1
    assert abs(r(hsum) - 1) < 1e-6
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' clipped_arm_true_fraction"
}
else local ++pass

**# fix 2: an xlabel() that would empty an arm does not limit the axis
* Pre-fix: xlabel(0 .5) under every weight drew an empty plot at rc 0 with
* "800 weights above .5 omitted".
capture noisily {
    _v190_bin none
    quietly psdash weights t ps, wvar(w) graph xlabel(0 .5) name(v190_x1, replace)
    graph describe v190_x1
    assert strpos(`"`r(command)'"', "omitted") == 0
    _v190_ser v190_x1 1
    assert !missing(r(hsum), r(xmax))
    assert abs(r(hsum) - 1) < 1e-6 & r(xmax) > 3
    _v190_ser v190_x1 2
    assert abs(r(hsum) - 1) < 1e-6

    * one arm entirely above the label range: still not limited
    clear
    set seed 43
    set obs 200
    gen byte t = _n <= 100
    gen double ps = .5
    gen double w = cond(t, 1 + runiform(), 5 + runiform())
    quietly psdash weights t ps, wvar(w) graph xlabel(0 1 2 3) name(v190_x2, replace)
    graph describe v190_x2
    assert strpos(`"`r(command)'"', "omitted") == 0
    _v190_ser v190_x2 2
    assert !missing(r(hsum), r(xmin))
    assert abs(r(hsum) - 1) < 1e-6 & r(xmin) > 4.9

    * xlabel() is a numlist: text labels and suboptions are refused at parse
    capture psdash weights t ps, wvar(w) graph xlabel(0 "zero" 5 10)
    assert _rc == 121
    capture psdash weights t ps, wvar(w) graph xlabel(0(3)15, labsize(small))
    assert _rc == 121
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' xlabel_never_empties_an_arm"
}
else local ++pass

**# fix 6: xsc() (minimum abbreviation of xscale) also hands over the axis
capture noisily {
    _v190_bin tail
    quietly psdash weights t ps, wvar(w) graph xlabel(0(1)4) ///
        graphoptions(xsc(range(0 35))) name(v190_xs, replace)
    graph describe v190_xs
    assert strpos(`"`r(command)'"', "omitted") == 0
    _v190_ser v190_xs 1
    local m1 = r(xmax)
    _v190_ser v190_xs 2
    assert !missing(`m1', r(xmax))
    assert max(`m1', r(xmax)) > 29
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' xsc_abbreviation_no_clip"
}
else local ++pass

**# nit: the weight = 1 line and its note only when 1 is on the axis
capture noisily {
    clear
    set seed 44
    set obs 300
    gen byte t = _n <= 150
    gen double ps = .5
    gen double w = 2 + 2 * runiform()
    quietly psdash weights t ps, wvar(w) graph xlabel(2 3 4) name(v190_one, replace)
    graph describe v190_one
    assert strpos(`"`r(command)'"', "Dashed line: weight = 1") == 0
    assert strpos(`"`r(command)'"', "xline(1") == 0
    * default axis starts at 0, so the line is drawn and explained
    quietly psdash weights t ps, wvar(w) graph name(v190_one2, replace)
    graph describe v190_one2
    assert strpos(`"`r(command)'"', "Dashed line: weight = 1") > 0
}
local rc = _rc
local ++tests
if `rc' {
    local ++fail
    local failed "`failed' weight_one_note_in_range"
}
else local ++pass

graph drop _all
display "RESULT: test_v190_weights_graphs tests=`tests' pass=`pass' fail=`fail'"
if `fail' display as error "Failed:`failed'"
_psdash_qa_cleanup
log close
if `fail' exit 1

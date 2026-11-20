* test_cycle_20261119_regtab.do - regtab review cycle 2026-11-19 regressions
*
* F1 random-effects rows are known by their raw coefficient name, never by a
*    covariate's display label ("Exposure per sd(1.0)" stays a fixed effect:
*    exponentiated, kept by nore, left in place); a corr() row is one.
* F2 stars, boldp(), and highlight() decide on one numeric p: p = 0.0496
*    prints 0.050 yet is starred, bolded, and highlighted; p = 0.0504 is none.
* F3 starslevels() must be three decreasing values in (0,1) and needs stars.
* F4 models(): more labels than models is r(198); fewer leaves "Model #".
* F5 xlsx() vs a different excel(), and nointercept with keepintercept, are
*    r(198).
* F1.5-F1.6 (follow-up) two-level mixed models and relabel also key on the
*    raw name: "Age per sd(10)" never becomes "Age per sd(10[y])", and relabel
*    leaves labels such as "Dose cov(x)" or "var(e)" on covariates alone.
* F6 models() text is kept as typed: quoted labels in a compound-quoted list,
*    embedded double quotes, backticks; blanks trimmed.
* Oracles: _b/_se from e() of the fitted model, the CSV text, the display
*    frame, r(table), the eplotframe, and the workbook read back by openpyxl
*    (a helper written below, run with python3 -I).

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _cyrt
log using "test_cycle_20261119_regtab.log", replace text name(_cyrt)

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

* Workbook style reader: one "bold CELL" / "fill CELL RGB" / "value CELL TEXT"
* line per fact, read back by Stata.
local xlpy "`output_dir'/_cyrt_xlfacts.py"
tempname ph
file open `ph' using "`xlpy'", write text replace
file write `ph' "import sys" _n
file write `ph' "from openpyxl import load_workbook" _n
file write `ph' "ws = load_workbook(sys.argv[1])[sys.argv[2]]" _n
file write `ph' "with open(sys.argv[3], 'w') as f:" _n
file write `ph' "    for row in ws.iter_rows():" _n
file write `ph' "        for c in row:" _n
file write `ph' "            if c.value not in (None, ''):" _n
file write `ph' "                f.write('value %s %s\n' % (c.coordinate, c.value))" _n
file write `ph' "            if c.font is not None and c.font.b:" _n
file write `ph' "                f.write('bold %s\n' % c.coordinate)" _n
file write `ph' "            if c.fill is not None and c.fill.fill_type:" _n
file write `ph' "                f.write('fill %s %s\n' % (c.coordinate, c.fill.fgColor.rgb))" _n
file close `ph'

capture program drop _cyrt_facts
program define _cyrt_facts, rclass
    * _cyrt_facts <py> <book> <sheet> <out>: r(facts) = "|line|line|..."
    args py book sheet out
    capture erase "`out'"
    shell python3 -I "`py'" "`book'" "`sheet'" "`out'"
    confirm file "`out'"
    tempname h
    local facts "|"
    file open `h' using "`out'", read text
    file read `h' line
    while r(eof) == 0 {
        local facts `"`facts'`line'|"'
        file read `h' line
    }
    file close `h'
    return local facts `"`facts'"'
end

capture program drop _cyrt_csv
program define _cyrt_csv, rclass
    * _cyrt_csv <file>: r(text) = the CSV lines joined by "|"
    args fn
    tempname h
    local txt "|"
    file open `h' using "`fn'", read text
    file read `h' line
    while r(eof) == 0 {
        local txt `"`macval(txt)'`macval(line)'|"'
        file read `h' line
    }
    file close `h'
    return local text `"`macval(txt)'"'
end

**# F1: a covariate labelled with sd(/var(/cov( is a fixed effect
**## F1.1 logit OR: exponentiated, in place, in r(table) and the eplotframe
local ++test_count
capture noisily {
    clear
    set seed 7
    set obs 600
    gen x = rnormal()
    gen z = rnormal()
    gen y = runiform() < invlogit(0.5*x + 0.3*z)
    label var x "Exposure per sd(1.0)"
    label var z "Second covariate"
    quietly logit y x z
    local or_x = exp(_b[x])
    local lo_x = exp(_b[x] - invnormal(0.975)*_se[x])
    local hi_x = exp(_b[x] + invnormal(0.975)*_se[x])
    local s_or = strtrim(string(round(`or_x', 0.01), "%9.2f"))
    local s_ci = "(" + strtrim(string(round(`lo_x', 0.01), "%9.2f")) + ", " ///
        + strtrim(string(round(`hi_x', 0.01), "%9.2f")) + ")"
    collect clear
    quietly collect: logit y x z
    regtab, csv("`output_dir'/_cyrt_f1.csv") frame(_cyrt_f1, replace) ///
        eplotframe(_cyrt_f1e, replace)
    tempname rt
    matrix `rt' = r(table)
    assert reldif(`rt'[1, 1], `or_x') < 1e-6
    frame _cyrt_f1 {
        assert strtrim(A[4]) == "Exposure per sd(1.0)"
        assert strtrim(c1[4]) == "`s_or'"
        assert strtrim(c2[4]) == "`s_ci'"
        assert strtrim(A[5]) == "Second covariate"
    }
    frame _cyrt_f1e {
        quietly count if label == "Exposure per sd(1.0)"
        assert r(N) == 1
        quietly summarize estimate if label == "Exposure per sd(1.0)", meanonly
        assert reldif(r(mean), `or_x') < 1e-6
    }
    _cyrt_csv "`output_dir'/_cyrt_f1.csv"
    local t `"`r(text)'"'
    assert strpos(`"`t'"', `"|Exposure per sd(1.0),`s_or',"`s_ci'",<0.001|Second covariate,"') > 0
}
if _rc == 0 {
    display as result "  PASS: F1.1 sd(-labelled covariate exponentiated and in place"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.1 sd(-labelled covariate (rc=`=_rc')"
    local ++fail_count
}

**## F1.2 nore keeps covariates labelled sd(, var(, cov(
local ++test_count
capture noisily {
    clear
    set seed 7
    set obs 600
    gen x = rnormal()
    gen z = rnormal()
    gen w = rnormal()
    gen y = 0.5*x + 0.3*z + 0.2*w + rnormal()
    label var x "Exposure per sd(1.0)"
    label var z "var(z) per unit"
    label var w "Adj. cov(w)"
    quietly regress y x z w
    local s_z = strtrim(string(round(_b[z], 0.01), "%9.2f"))
    collect clear
    quietly collect: regress y x z w
    regtab, nore frame(_cyrt_f12, replace)
    frame _cyrt_f12 {
        assert _N == 7
        assert strtrim(A[4]) == "Exposure per sd(1.0)"
        assert strtrim(A[5]) == "var(z) per unit"
        assert strtrim(A[6]) == "Adj. cov(w)"
        assert strtrim(A[7]) == "Intercept"
        assert strtrim(c1[5]) == "`s_z'"
        * an ordinary coefficient keeps its p-value
        assert strtrim(c3[5]) != ""
    }
}
if _rc == 0 {
    display as result "  PASS: F1.2 nore keeps sd(/var(/cov(-labelled covariates"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.2 nore and labelled covariates (rc=`=_rc')"
    local ++fail_count
}

**## F1.3 mixed model: the labelled covariate is a fixed effect; nore still drops RE rows
local ++test_count
capture noisily {
    clear
    set seed 11
    set obs 600
    gen id = ceil(_n/10)
    gen u0 = rnormal() if mod(_n, 10) == 1
    bysort id: replace u0 = u0[1]
    gen x = rnormal()
    gen y = 0.3*x + u0 + rnormal()
    label var x "Age per sd(10)"
    collect clear
    quietly collect: mixed y x || id:
    regtab, frame(_cyrt_f13a, replace)
    frame _cyrt_f13a {
        assert _N == 7
        assert strtrim(A[4]) == "Age per sd(10)"
        assert strtrim(A[5]) == "Intercept"
        assert strtrim(A[6]) == "var(_cons)"
        assert strtrim(A[7]) == "var(e)"
    }
    regtab, nore frame(_cyrt_f13b, replace)
    frame _cyrt_f13b {
        assert _N == 5
        assert strtrim(A[4]) == "Age per sd(10)"
        assert strtrim(A[5]) == "Intercept"
    }
    gen yb = y > 0
    quietly melogit yb x || id:
    local s_or = strtrim(string(round(exp(_b[x]), 0.01), "%9.2f"))
    collect clear
    quietly collect: melogit yb x || id:, or
    regtab, frame(_cyrt_f13c, replace)
    frame _cyrt_f13c {
        assert strtrim(A[4]) == "Age per sd(10)"
        assert strtrim(c1[4]) == "`s_or'"
        assert strtrim(A[5]) == "Median Odds Ratio (id)"
    }
}
if _rc == 0 {
    display as result "  PASS: F1.3 mixed/melogit labelled covariate is a fixed effect"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.3 mixed/melogit labelled covariate (rc=`=_rc')"
    local ++fail_count
}

**## F1.4 a corr() random-effects row sits in the RE block and nore drops it
local ++test_count
capture noisily {
    clear
    set seed 11
    set obs 800
    gen id = ceil(_n/10)
    gen u0 = rnormal() if mod(_n, 10) == 1
    bysort id: replace u0 = u0[1]
    gen u1 = 0.5*rnormal() if mod(_n, 10) == 1
    bysort id: replace u1 = u1[1]
    gen x = rnormal()
    gen y = 0.3*x + u0 + u1*x + rnormal()
    collect clear
    quietly collect: mixed y x || id: x, cov(unstructured) stddeviations
    regtab, frame(_cyrt_f14a, replace)
    frame _cyrt_f14a {
        assert strtrim(A[4]) == "x"
        assert strtrim(A[5]) == "Intercept"
        quietly generate long _r = _n
        quietly summarize _r if strtrim(A) == "corr(x,_cons)", meanonly
        assert r(N) == 1
        assert r(min) > 5
    }
    regtab, nore frame(_cyrt_f14b, replace)
    frame _cyrt_f14b {
        assert _N == 5
        assert strtrim(A[4]) == "x"
        assert strtrim(A[5]) == "Intercept"
    }
}
if _rc == 0 {
    display as result "  PASS: F1.4 corr() row is a random effect"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.4 corr() row placement and nore (rc=`=_rc')"
    local ++fail_count
}

**## F1.5 two-level mixed: the labelled covariate keeps its label; RE rows get their group
local ++test_count
capture noisily {
    clear
    set seed 11
    set obs 400
    gen sch = ceil(_n/40)
    gen id = ceil(_n/4)
    gen x = rnormal()
    gen y = 1 + .5*x + rnormal() + rnormal()*(sch/10)
    label var x "Age per sd(10)"
    collect clear
    quietly collect: mixed y x || sch: || id:
    regtab, frame(_cyrt_f15a, replace)
    frame _cyrt_f15a {
        assert _N == 8
        assert strtrim(A[4]) == "Age per sd(10)"
        assert strtrim(A[5]) == "Intercept"
        assert strtrim(A[6]) == "var(_cons[sch])"
        assert strtrim(A[7]) == "var(_cons[id])"
        assert strtrim(A[8]) == "var(e)"
    }
    regtab, relabel frame(_cyrt_f15b, replace)
    frame _cyrt_f15b {
        assert strtrim(A[4]) == "Age per sd(10)"
        assert strtrim(A[6]) == "Variance: sch (Intercept)"
        assert strtrim(A[7]) == "Variance: id (Intercept)"
        assert strtrim(A[8]) == "Residual Variance"
    }
    regtab, nore frame(_cyrt_f15c, replace)
    frame _cyrt_f15c {
        assert _N == 5
        assert strtrim(A[4]) == "Age per sd(10)"
    }
    * a random slope at the first of two levels: the slope's own label
    * (which itself holds "sd(") names it once relabelled
    collect clear
    quietly collect: mixed y x || sch: x, cov(unstructured) || id:
    regtab, frame(_cyrt_f15d, replace)
    frame _cyrt_f15d {
        assert strtrim(A[4]) == "Age per sd(10)"
        quietly count if strtrim(A) == "var(x[sch])"
        assert r(N) == 1
        quietly count if strtrim(A) == "cov(x,_cons[sch])"
        assert r(N) == 1
        quietly count if strpos(A, "sd(10[")
        assert r(N) == 0
    }
    regtab, relabel frame(_cyrt_f15e, replace)
    frame _cyrt_f15e {
        assert strtrim(A[4]) == "Age per sd(10)"
        quietly count if strtrim(A) == "Variance: sch (Age per sd(10))"
        assert r(N) == 1
        quietly count if strtrim(A) == "Covariance: sch (Age per sd(10), Intercept)"
        assert r(N) == 1
        quietly count if strtrim(A) == "Variance: id (Intercept)"
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F1.5 two-level mixed labelled covariate keeps its label"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.5 two-level mixed labelled covariate (rc=`=_rc')"
    local ++fail_count
}

**## F1.6 relabel never rewrites a covariate label holding cov(, var(, sd(
local ++test_count
capture noisily {
    clear
    set seed 11
    set obs 400
    gen sch = ceil(_n/40)
    gen x = rnormal()
    gen z = rnormal()
    gen w = rnormal()
    gen y = 1 + .5*x + .2*z + .1*w + rnormal() + rnormal()*(sch/10)
    label var x "Age per sd(10)"
    label var z "Dose cov(x)"
    label var w "var(e)"
    collect clear
    quietly collect: mixed y x z w || sch:
    regtab, relabel frame(_cyrt_f16a, replace)
    frame _cyrt_f16a {
        assert strtrim(A[4]) == "Age per sd(10)"
        assert strtrim(A[5]) == "Dose cov(x)"
        assert strtrim(A[6]) == "var(e)"
        assert strtrim(A[7]) == "Intercept"
        assert strtrim(A[8]) == "Variance: sch (Intercept)"
        assert strtrim(A[9]) == "Residual Variance"
    }
    collect clear
    quietly collect: mixed y x z w || sch: x, cov(unstructured)
    regtab, relabel frame(_cyrt_f16b, replace)
    frame _cyrt_f16b {
        assert strtrim(A[5]) == "Dose cov(x)"
        quietly count if strtrim(A) == "Covariance: sch (Age per sd(10), Intercept)"
        assert r(N) == 1
        quietly count if strpos(A, "Covariance:")
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: F1.6 relabel leaves cov(/var(/sd(-labelled covariates alone"
    local ++pass_count
}
else {
    display as error "  FAIL: F1.6 relabel and labelled covariates (rc=`=_rc')"
    local ++fail_count
}

**# F2: stars, boldp(), highlight() agree on one numeric p
**## F2.1 p = 0.0496 prints 0.050: starred, bolded, highlighted
local ++test_count
capture noisily {
    clear
    set obs 200
    gen x = .
    gen y = .
    set seed 2189
    replace x = rnormal()
    replace y = 0.2*x + rnormal()
    quietly regress y x
    local p = 2*ttail(e(df_r), abs(_b[x]/_se[x]))
    assert `p' >= 0.0495 & `p' < 0.05
    local s_b = strtrim(string(round(_b[x], 0.01), "%9.2f"))
    collect clear
    quietly collect: regress y x
    local bk "`output_dir'/_cyrt_f21.xlsx"
    capture erase "`bk'"
    regtab, stars boldp(0.05) highlight(0.05) xlsx("`bk'") sheet("P") ///
        csv("`output_dir'/_cyrt_f21.csv")
    _cyrt_csv "`output_dir'/_cyrt_f21.csv"
    assert strpos(`"`r(text)'"', `"|x,`s_b'*,"') > 0
    assert strpos(`"`r(text)'"', `"",0.050|Intercept,"') > 0
    _cyrt_facts "`xlpy'" "`bk'" "P" "`output_dir'/_cyrt_f21.txt"
    local f `"`r(facts)'"'
    assert strpos(`"`f'"', "|value E4 0.050|") > 0
    assert strpos(`"`f'"', "|value C4 `s_b'*|") > 0
    assert strpos(`"`f'"', "|bold E4|") > 0
    assert strpos(`"`f'"', "|fill B4 ") > 0
    assert strpos(`"`f'"', "|fill E4 ") > 0
    * the intercept (p = 0.38) is not flagged
    assert strpos(`"`f'"', "|bold E5|") == 0
    assert strpos(`"`f'"', "|fill B5 ") == 0
}
if _rc == 0 {
    display as result "  PASS: F2.1 p=0.0496 starred, bold, and highlighted together"
    local ++pass_count
}
else {
    display as error "  FAIL: F2.1 p just below 0.05 (rc=`=_rc')"
    local ++fail_count
}

**## F2.2 p = 0.0504 prints 0.050: neither starred, bolded, nor highlighted
local ++test_count
capture noisily {
    clear
    set obs 200
    gen x = .
    gen y = .
    set seed 354
    replace x = rnormal()
    replace y = 0.2*x + rnormal()
    quietly regress y x
    local p = 2*ttail(e(df_r), abs(_b[x]/_se[x]))
    assert `p' > 0.05 & `p' < 0.0505
    collect clear
    quietly collect: regress y x
    local bk "`output_dir'/_cyrt_f22.xlsx"
    capture erase "`bk'"
    regtab, stars boldp(0.05) highlight(0.05) xlsx("`bk'") sheet("P")
    _cyrt_facts "`xlpy'" "`bk'" "P" "`output_dir'/_cyrt_f22.txt"
    local f `"`r(facts)'"'
    assert strpos(`"`f'"', "|value E4 0.050|") > 0
    assert strpos(`"`f'"', "|bold E4|") == 0
    assert strpos(`"`f'"', "|fill B4 ") == 0
    assert strpos(`"`f'"', "|fill E4 ") == 0
    mata: st_local("_c4", select(tokens(st_local("f"), "|"), strmatch(tokens(st_local("f"), "|"), "value C4 *"))[1])
    assert strpos(`"`_c4'"', "*") == 0
}
if _rc == 0 {
    display as result "  PASS: F2.2 p=0.0504 not starred, bold, or highlighted"
    local ++pass_count
}
else {
    display as error "  FAIL: F2.2 p just above 0.05 (rc=`=_rc')"
    local ++fail_count
}

**# F3: starslevels() validation
**## F3.1 out-of-range, misordered, tied, and stars-less lists are r(198)
local ++test_count
capture noisily {
    clear
    set seed 5
    set obs 400
    gen x = rnormal()
    gen z = rnormal()
    gen y = 0.15*x + rnormal()
    collect clear
    quietly collect: regress y x z
    foreach sl in "5 1 0.1" "0.001 0.01 0.05" "0.05 0.05 0.01" "0.5 0.1 0" "1 0.5 0.1" {
        capture erase "`output_dir'/_cyrt_f31.csv"
        set varabbrev on
        capture noisily regtab, stars starslevels(`sl') csv("`output_dir'/_cyrt_f31.csv")
        assert _rc == 198
        assert "`c(varabbrev)'" == "on"
        set varabbrev off
        capture confirm file "`output_dir'/_cyrt_f31.csv"
        assert _rc == 601
    }
    capture noisily regtab, starslevels(0.10 0.05 0.01)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: F3.1 invalid starslevels() refused"
    local ++pass_count
}
else {
    display as error "  FAIL: F3.1 starslevels() validation (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

**## F3.2 a valid custom list still stars by its thresholds
local ++test_count
capture noisily {
    clear
    set obs 200
    gen x = .
    gen y = .
    set seed 354
    replace x = rnormal()
    replace y = 0.2*x + rnormal()
    collect clear
    quietly collect: regress y x
    regtab, stars starslevels(0.10 0.05 0.01) csv("`output_dir'/_cyrt_f32.csv")
    _cyrt_csv "`output_dir'/_cyrt_f32.csv"
    * p = 0.0504: one star at 0.10, none at 0.05
    assert strpos(`"`r(text)'"', `"|x,0.14*,"') > 0
    assert strpos(`"`r(text)'"', `"|x,0.14**,"') == 0
}
if _rc == 0 {
    display as result "  PASS: F3.2 valid starslevels() stars by its thresholds"
    local ++pass_count
}
else {
    display as error "  FAIL: F3.2 valid starslevels() (rc=`=_rc')"
    local ++fail_count
}

**# F4: models() label count
**## F4.1 more labels than models is r(198) with a message; fewer fill "Model #"
local ++test_count
capture noisily {
    clear
    set seed 2
    set obs 400
    gen y = rnormal()
    gen x = rnormal()
    gen z = rnormal()
    collect clear
    quietly collect: regress y x
    quietly collect: regress y x z
    set varabbrev on
    capture noisily regtab, models("A \ B \ C")
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
    assert _N == 400
    regtab, models("OnlyOne") csv("`output_dir'/_cyrt_f41.csv") frame(_cyrt_f41, replace)
    _cyrt_csv "`output_dir'/_cyrt_f41.csv"
    assert strpos(`"`r(text)'"', "|,OnlyOne,,,Model 2,,|") > 0
    frame _cyrt_f41 {
        assert strtrim(c1[2]) == "OnlyOne"
        assert strtrim(c4[2]) == "Model 2"
    }
    regtab, models("A \ B") frame(_cyrt_f41b, replace)
    frame _cyrt_f41b {
        assert strtrim(c1[2]) == "A"
        assert strtrim(c4[2]) == "B"
    }
    regtab, models("First" \ "Second") frame(_cyrt_f41c, replace)
    frame _cyrt_f41c {
        assert strtrim(c1[2]) == "First"
        assert strtrim(c4[2]) == "Second"
    }
}
if _rc == 0 {
    display as result "  PASS: F4.1 models() label count checked"
    local ++pass_count
}
else {
    display as error "  FAIL: F4.1 models() label count (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

**# F5: contradictory option pairs
**## F5.1 xlsx() and a different excel(); nointercept with keepintercept
local ++test_count
capture noisily {
    clear
    set seed 2
    set obs 200
    gen y = rnormal()
    gen x = rnormal()
    collect clear
    quietly collect: regress y x
    local b2 "`output_dir'/_cyrt_f5a.xlsx"
    local b3 "`output_dir'/_cyrt_f5b.xlsx"
    capture erase "`b2'"
    capture erase "`b3'"
    capture noisily regtab, xlsx("`b2'") excel("`b3'")
    assert _rc == 198
    capture confirm file "`b2'"
    assert _rc == 601
    capture confirm file "`b3'"
    assert _rc == 601
    * the same file named twice is not a conflict
    regtab, xlsx("`b2'") excel("`b2'")
    confirm file "`b2'"
    capture noisily regtab, nointercept keepintercept csv("`output_dir'/_cyrt_f5.csv")
    assert _rc == 198
    regtab, keepintercept frame(_cyrt_f5k, replace)
    frame _cyrt_f5k {
        assert strtrim(A[5]) == "Intercept"
    }
}
if _rc == 0 {
    display as result "  PASS: F5.1 contradictory option pairs refused"
    local ++pass_count
}
else {
    display as error "  FAIL: F5.1 contradictory option pairs (rc=`=_rc')"
    local ++fail_count
}

**# F6: models() text is kept as typed
**## F6.1 quoted labels, embedded double quotes, backticks, and blanks
local ++test_count
capture noisily {
    clear
    set seed 2
    set obs 200
    gen y = rnormal()
    gen x = rnormal()
    gen z = rnormal()
    collect clear
    quietly collect: regress y x
    quietly collect: regress y x z
    * labels in double quotes inside a compound-quoted models(): before,
    * both headers fell back to "Model 1" / "Model 2" at rc 0
    local m = char(34) + "First" + char(34) + " \ " + char(34) + "Second" + char(34)
    regtab, models(`"`macval(m)'"') frame(_cyrt_f61a, replace)
    frame _cyrt_f61a: mata: assert(st_sdata(2, "c1") == "First")
    frame _cyrt_f61a: mata: assert(st_sdata(2, "c4") == "Second")
    * an embedded pair of double quotes and a backtick print as typed
    local m = "Adj " + char(34) + "full" + char(34) + " \ it" + char(96) + "s"
    regtab, models(`"`macval(m)'"') frame(_cyrt_f61b, replace)
    frame _cyrt_f61b: mata: assert(st_sdata(2, "c1") == "Adj " + char(34) + "full" + char(34))
    frame _cyrt_f61b: mata: assert(st_sdata(2, "c4") == "it" + char(96) + "s")
    * surrounding blanks and empty labels are dropped; a long label is kept whole
    local m = " \ A long first label that is wider than any other header cell \  \ B "
    regtab, models(`"`macval(m)'"') frame(_cyrt_f61c, replace)
    frame _cyrt_f61c: mata: assert(st_sdata(2, "c1") == "A long first label that is wider than any other header cell")
    frame _cyrt_f61c: mata: assert(st_sdata(2, "c4") == "B")
    * still refused: more labels than models, and nothing left behind in Mata
    capture noisily regtab, models(`"A \ "B" \ C"')
    assert _rc == 198
    capture mata: mata describe _regtab_mdl
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: F6.1 models() text kept as typed"
    local ++pass_count
}
else {
    display as error "  FAIL: F6.1 models() text kept as typed (rc=`=_rc')"
    local ++fail_count
}

display as result "test_cycle_20261119_regtab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_regtab tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cyrt
if `fail_count' > 0 exit 1

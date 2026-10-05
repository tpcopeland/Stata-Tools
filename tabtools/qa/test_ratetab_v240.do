* test_ratetab_v240.do - ratetab zerocells(..., persontime), a level with no
* person-time left empty in every sink, and saving() keeping the grouping
* variables (names, types, formats, variable and value labels)
*
* Oracles: event and person-time sums written into the fixture by hand;
* exact Poisson limits by the chi-square route (Ulm 1990):
*     lower = invchi2(2D, alpha/2) / 2 / Y,  upper = invchi2(2(D+1), 1-alpha/2) / 2 / Y
* not the invpoisson() route ratetab uses. Workbook cells are read back with
* openpyxl (tools/xlsx_facts.py), CSV and Markdown as raw lines, the console
* from a text log of the call.
*
* Fixture (12 rows, g = Low/Mid/High, 4 rows each):
*   Low : e1 = 0 (D 0, Y 10)   e2 = 1 each (D 4, Y 4)
*   Mid : e1 = 1 each (D 4, Y 20)   e2 = 0 (D 0, Y 8)
*   High: e1 = 2 each (D 8, Y 40)   e2 = 0, py2 = 0 (no person-time)

clear all
set more off
set varabbrev off
version 17.0

capture log close _rt240
log using "test_ratetab_v240.log", replace text name(_rt240)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global RT240_TOOL "`qa_dir'/tools/xlsx_facts.py"
global RT240_RES "`output_dir'/rt240_facts.txt"
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _rt240_data
program define _rt240_data
    version 17.0
    clear
    quietly set obs 12
    gen long id = _n
    gen byte g = 1 + (_n > 4) + (_n > 8)
    label define _rt240_gl 1 "Low" 2 "Mid" 3 "High" .a "Unknown", replace
    label values g _rt240_gl
    label variable g "Dose group"
    gen long e1 = cond(g == 1, 0, cond(g == 2, 1, 2))
    gen long e2 = (g == 1)
    gen double py1 = cond(g == 1, 2.5, cond(g == 2, 5, 10))
    gen double py2 = cond(g == 1, 1, cond(g == 2, 2, 0))
end

* exact limits per 1000 by the chi-square route, formatted %24.1f
capture program drop _rt240_ci
program define _rt240_ci, rclass
    version 17.0
    args D Y
    local a = 0.025
    local r = 1000 * `D' / `Y'
    if `D' == 0 local lo 0
    else local lo = 1000 * invchi2(2 * `D', `a') / 2 / `Y'
    local hi = 1000 * invchi2(2 * (`D' + 1), 1 - `a') / 2 / `Y'
    local f "%24.1f"
    return local cell = strtrim(string(round(`r', 0.1), "`f'")) + " (" + ///
        strtrim(string(round(`lo', 0.1), "`f'")) + ", " + ///
        strtrim(string(round(`hi', 0.1), "`f'")) + ")"
end

* exactly one line of file `1' equals `2'
capture program drop _rt240_hasline
program define _rt240_hasline
    version 17.0
    args file want
    mata: st_local("_n", strofreal(sum(cat(st_local("file")) :== st_local("want"))))
    if `_n' != 1 {
        display as error `"line not found once (`_n'): `want'"'
        exit 9
    }
end

* workbook fact (from xlsx_facts.py) present exactly once / absent
capture program drop _rt240_fact
program define _rt240_fact
    version 17.0
    args want
    mata: st_local("_n", strofreal(sum(cat("$RT240_RES") :== st_local("want"))))
    if `_n' != 1 {
        display as error `"workbook fact not found once (`_n'): `want'"'
        exit 9
    }
end
capture program drop _rt240_nocell
program define _rt240_nocell
    version 17.0
    args cell
    mata: _f = cat("$RT240_RES"); _p = "value " + st_local("cell") + " "; ///
        st_local("_n", strofreal(sum(substr(_f, 1, strlen(_p)) :== _p)))
    if `_n' != 0 {
        display as error "workbook cell `cell' is not empty"
        exit 9
    }
end

**# Z1: zerocells(dash, persontime) withholds count, person-time and rate
local ++test_count
capture noisily {
    _rt240_data
    ratetab g, events(e1 e2) exposure(py1 py2) frame(_z1, replace) zerocells(dash, persontime)
    * Low e1 and Mid e2 are the zero-event cells: all three cells a dash
    frame _z1: assert c2[5] == "–" & c3[5] == "–" & c4[5] == "–"
    frame _z1: assert c5[6] == "–" & c6[6] == "–" & c7[6] == "–"
    * computable cells untouched
    _rt240_ci 4 20
    frame _z1: assert c2[6] == "4" & c3[6] == "20" & c4[6] == "`r(cell)'"
    _rt240_ci 4 4
    frame _z1: assert c5[5] == "4" & c6[5] == "4" & c7[5] == "`r(cell)'"
    * r() keeps the numbers of a withheld cell
    ratetab g, events(e1 e2) exposure(py1 py2) zerocells(dash, persontime)
    matrix E = r(estimates)
    assert E[1, 4] == 0 & E[1, 5] == 10 & E[1, 6] == 0
    assert reldif(E[1, 8], 1000 * -ln(0.025) / 10) < 1e-12
    assert r(N_zero) == 2
    assert strpos(`"`r(methods)'"', "without a count, person-time or rate") > 0
    * without persontime the person-time stays (2.3.1 behaviour)
    ratetab g, events(e1 e2) exposure(py1 py2) frame(_z1, replace) zerocells(dash)
    frame _z1: assert c2[5] == "–" & c3[5] == "10" & c4[5] == "–"
    frame _z1: assert c5[6] == "–" & c6[6] == "8" & c7[6] == "–"
    assert strpos(`"`r(methods)'"', "without a count or rate") > 0
    * blank, persontime: all three empty; case and spacing are free
    ratetab g, events(e1 e2) exposure(py1 py2) frame(_z1, replace) zerocells(BLANK ,PersonTime)
    frame _z1: assert c2[5] == "" & c3[5] == "" & c4[5] == ""
    frame _z1: assert c2[7] == "8" & c3[7] == "40"
    frame drop _z1
    * refusals
    foreach bad in `"zerocells(, persontime)"' `"zerocells(dash, pt)"' ///
        `"zerocells(dash persontime)"' `"zerocells(dash, persontime extra)"' `"zerocells(zero)"' {
        capture ratetab g, events(e1 e2) exposure(py1 py2) `bad'
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: Z1 zerocells(dash|blank, persontime) cells, numbers kept, refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: Z1 zerocells persontime (rc=`=_rc')"
    local ++fail_count
}

**# Z2: stratetab takes the same zerocells(dash, persontime)
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    gen str4 lev = cond(_n == 1, "A", "B")
    gen double _D = cond(_n == 1, 0, 3)
    gen double _Y = cond(_n == 1, 100, 200)
    gen double _Rate = _D / _Y
    gen double _Lower = cond(_n == 1, ., invpoissontail(3, 0.025) / 200)
    gen double _Upper = cond(_n == 1, ., invpoisson(3, 0.025) / 200)
    label variable _Lower "Lower 95% bound"
    label variable _Upper "Upper 95% bound"
    local f "`output_dir'/rt240_strate"
    quietly save "`f'", replace
    stratetab, using("`f'") outcomes(1) frame(_z2, replace) zerocells(dash, persontime)
    frame _z2: assert c2[5] == "–" & c3[5] == "–" & c4[5] == "–"
    frame _z2: assert c2[6] == "3" & c3[6] == "200"
    stratetab, using("`f'") outcomes(1) frame(_z2, replace) zerocells(dash)
    frame _z2: assert c3[5] == "100"
    frame drop _z2
    capture stratetab, using("`f'") outcomes(1) zerocells(dash, nope)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Z2 stratetab zerocells(dash, persontime)"
    local ++pass_count
}
else {
    display as error "  FAIL: Z2 stratetab zerocells persontime (rc=`=_rc')"
    local ++fail_count
}

**# N1: a level with no person-time is an empty cell in every sink
* (2.3.1 stopped with r(459) "a level of g has no person-time")
local ++test_count
capture noisily {
    _rt240_data
    local book "`output_dir'/rt240_nopt.xlsx"
    local csv "`output_dir'/rt240_nopt.csv"
    local md "`output_dir'/rt240_nopt.md"
    local con "`output_dir'/rt240_console.txt"
    foreach x in book csv md con {
        capture erase "``x''"
    }
    local f "`output_dir'/rt240_nopt"
    capture erase "`f'.dta"
    local _ls = c(linesize)
    set linesize 255
    log using "`con'", text replace name(_rt240c)
    ratetab g, events(e1 e2) exposure(py1 py2) frame(_n1, replace) ///
        xlsx("`book'") sheet("nopt") csv("`csv'") markdown("`md'") saving("`f'")
    * read r() before log close, which is r-class
    matrix E = r(estimates)
    matrix R = r(rates)
    local n_nopt = r(N_nopt)
    local n_zero = r(N_zero)
    local meth `"`r(methods)'"'
    log close _rt240c
    set linesize `_ls'
    assert `n_nopt' == 1
    * Low e1 and Mid e2 have zero events; High e2 is not a zero-event cell
    assert `n_zero' == 2
    assert strpos(`"`meth'"', "no person-time for an outcome have no rate and are left empty") > 0
    _rt240_ci 8 40
    local hi1 `"`r(cell)'"'
    _rt240_ci 0 10
    local lo1 `"`r(cell)'"'
    * frame
    frame _n1: assert c2[7] == "8" & c3[7] == "40" & c4[7] == `"`hi1'"'
    frame _n1: assert c5[7] == "" & c6[7] == "" & c7[7] == ""
    frame _n1: assert c2[5] == "0" & c3[5] == "10" & c4[5] == `"`lo1'"'
    * r(estimates): row 6 is outcome 2, level 3: 0 events, 0 person-time,
    * rate and limits missing (not 0, not an upper limit)
    assert E[6, 1] == 2 & E[6, 3] == 3
    assert E[6, 4] == 0 & E[6, 5] == 0
    assert missing(E[6, 6]) & missing(E[6, 7]) & missing(E[6, 8])
    * r(rates): Low/Mid/High x e1/e2; High e2 missing
    assert missing(R[3, 2]) & reldif(R[3, 1], 200) < 1e-12
    * workbook
    capture erase "$RT240_RES"
    shell python3 "$RT240_TOOL" "`book'" "nopt" "$RT240_RES"
    confirm file "$RT240_RES"
    _rt240_fact "value C7 8"
    _rt240_fact "value D7 40"
    _rt240_fact "value E7 `hi1'"
    _rt240_nocell F7
    _rt240_nocell G7
    _rt240_nocell H7
    _rt240_fact "value F6 0"
    _rt240_fact "value G6 8"
    * CSV and Markdown
    _rt240_hasline "`csv'" `"   High,8,40,"`hi1'",,,"'
    _rt240_hasline "`md'" "| &nbsp;&nbsp;&nbsp;High | 8 | 40 | `hi1' |  |  |  |"
    * console: nothing after the e1 rate on the High line
    mata: _c = cat(st_local("con"))
    mata: _c = select(_c, (strpos(_c, "High") :> 0) :& (strpos(_c, "|") :> 0))
    mata: st_local("_nc", strofreal(rows(_c)))
    assert `_nc' == 1
    mata: st_local("_cl", _c[1])
    assert `_nc' == 1
    assert regexm(`"`_cl'"', "High +8 +40 +200\.0 \(86\.3, 394\.1\) +\|$")
    * saving(): missing rate and limits, flagged
    preserve
    use "`f'", clear
    assert _N == 6
    assert outcome[6] == 2 & level[6] == 3 & events[6] == 0 & persontime[6] == 0
    assert missing(rate[6]) & missing(lb[6]) & missing(ub[6])
    assert nopersontime[6] == 1
    quietly count if nopersontime
    assert r(N) == 1
    assert ub[1] < . & lb[1] == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: N1 no-person-time cell empty in frame, xlsx, CSV, Markdown, console, r(), saving()"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 no-person-time cell (rc=`=_rc')"
    local ++fail_count
}
capture log close _rt240c
capture frame drop _n1

**# N2: other intervals and zerocells() leave the no-person-time cell empty
local ++test_count
capture noisily {
    _rt240_data
    foreach opt in `"ci(poisson)"' `"ci(cluster(id))"' `"zerocells(dash)"' `"zerocells(dash, persontime)"' `"smallcells(3) masktext("x")"' {
        ratetab g, events(e1 e2) exposure(py1 py2) frame(_n2, replace) `opt'
        frame _n2: assert c5[7] == "" & c6[7] == "" & c7[7] == ""
        frame _n2: assert c2[7] == "8" & c3[7] == "40"
        assert r(N_nopt) == 1
        matrix E = r(estimates)
        assert missing(E[6, 6]) & missing(E[6, 7]) & missing(E[6, 8])
    }
    * a grouping variable with no person-time for a whole outcome is still
    * a table: every level of that outcome is empty
    replace py2 = 0
    replace e2 = 0
    ratetab g, events(e1 e2) exposure(py1 py2) frame(_n2, replace)
    assert r(N_nopt) == 3
    frame _n2: assert c5[5] == "" & c5[6] == "" & c5[7] == ""
    frame _n2: assert c2[6] == "4"
    frame drop _n2
    * nothing computable anywhere: refused, nothing written
    local f "`output_dir'/rt240_none"
    capture erase "`f'.dta"
    capture ratetab g, events(e2) exposure(py2) saving("`f'")
    assert _rc == 459
    capture confirm file "`f'.dta"
    assert _rc != 0
    * events without person-time are still refused
    _rt240_data
    replace e2 = 1 in 12
    capture ratetab g, events(e1 e2) exposure(py1 py2)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: N2 empty cell under poisson/cluster/zerocells/smallcells; all-empty refused"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 no-person-time variants (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _n2

**# N3: stratetab leaves a zero person-time row empty; refuses events without it
local ++test_count
capture noisily {
    clear
    quietly set obs 2
    gen str4 lev = cond(_n == 1, "A", "B")
    gen double _D = 0
    replace _D = 3 in 2
    gen double _Y = cond(_n == 1, 0, 200)
    gen double _Rate = _D / _Y
    gen double _Lower = cond(_n == 1, ., invpoissontail(3, 0.025) / 200)
    gen double _Upper = cond(_n == 1, ., invpoisson(3, 0.025) / 200)
    label variable _Lower "Lower 95% bound"
    label variable _Upper "Upper 95% bound"
    local f "`output_dir'/rt240_strate0"
    quietly save "`f'", replace
    stratetab, using("`f'" "`f'") outcomes(1) frame(_n3, replace) rateratio zerocells(dash)
    assert r(N_nopt) == 2
    assert missing(el(r(rates), 1, 1))
    * first section (reference): A empty -- its "Ref." too, since it has no
    * rate to be the reference for -- and B printed with "Ref."
    frame _n3: assert c2[5] == "" & c3[5] == "" & c4[5] == "" & c5[5] == ""
    frame _n3: assert c5[6] == "Ref."
    frame _n3: assert c2[6] == "3" & c3[6] == "200"
    * second section: A empty including its rate ratio
    frame _n3: assert c2[8] == "" & c4[8] == "" & c5[8] == ""
    frame drop _n3
    replace _D = 1 in 1
    quietly save "`f'", replace
    capture stratetab, using("`f'") outcomes(1)
    assert _rc == 459
    replace _D = 0
    replace _Y = 0
    quietly save "`f'", replace
    capture stratetab, using("`f'") outcomes(1)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: N3 stratetab zero person-time rows empty; refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 stratetab zero person-time (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _n3

**# S1: saving() keeps the grouping variables with their labels and types
local ++test_count
capture noisily {
    _rt240_data
    * a string, a float with fractional codes, and a long with a format
    gen str7 site = cond(id <= 6, "North A", "South")
    gen float dose = cond(id <= 3, 0.1, 0.7)
    gen long big = cond(id <= 8, 100000, 2000000)
    label define _rt240_bl 100000 "Hundred thousand" 2000000 "Two million", replace
    label values big _rt240_bl
    label variable big "Big code"
    format big %12.0fc
    * values a decimal or %9.0g transport would change: 1/3 as a double and
    * longs of 9 digits
    gen double third = cond(id <= 6, 1/3, 2/3)
    gen long huge = cond(id <= 6, 123456789, 987654321)
    local fmt_big : format big
    local fmt_g : format g
    local fmt_site : format site
    local f "`output_dir'/rt240_saved"
    capture erase "`f'.dta"
    ratetab g site dose big third huge, events(e1 e2) exposure(py1 py2) saving("`f'")
    matrix E = r(estimates)
    local nr = rowsof(E)
    preserve
    use "`f'", clear
    assert _N == `nr'
    * existing columns unchanged and in their 2.3.1 order
    unab all : *
    assert "`all'" == "outcome outcome_var outcome_label group groupvar level level_label events persontime rate lb ub masked nopersontime g site dose big third huge"
    forvalues r = 1/`nr' {
        assert outcome[`r'] == E[`r', 1] & group[`r'] == E[`r', 2] & level[`r'] == E[`r', 3]
        assert events[`r'] == E[`r', 4] & persontime[`r'] == E[`r', 5]
        assert (rate[`r'] == E[`r', 6]) | (missing(rate[`r']) & missing(E[`r', 6]))
    }
    * types, formats, labels of the grouping variables
    assert "`: type g'" == "byte" & "`: type site'" == "str7"
    assert "`: type dose'" == "float" & "`: type big'" == "long"
    assert "`: format big'" == "`fmt_big'" & "`fmt_big'" == "%12.0fc"
    assert "`: format g'" == "`fmt_g'" & "`: format site'" == "`fmt_site'"
    assert "`: value label g'" == "_rt240_gl" & "`: value label big'" == "_rt240_bl"
    assert "`: value label site'" == "" & "`: value label dose'" == ""
    assert `"`: variable label g'"' == "Dose group" & `"`: variable label big'"' == "Big code"
    assert `"`: label _rt240_gl 1'"' == "Low" & `"`: label _rt240_gl 3'"' == "High"
    assert `"`: label _rt240_gl .a'"' == "Unknown"
    assert `"`: label _rt240_bl 2000000'"' == "Two million"
    * values on their own rows, missing on the other grouping variables' rows
    assert g == level if groupvar == "g"
    assert missing(g) if groupvar != "g"
    quietly count if groupvar == "site" & site == "North A" & level_label == "North A"
    assert r(N) == 2
    assert site == "" if groupvar != "site"
    quietly count if groupvar == "dose" & dose == float(0.1)
    assert r(N) == 2
    quietly count if groupvar == "dose" & dose == float(0.7)
    assert r(N) == 2
    assert missing(dose) if groupvar != "dose"
    quietly count if groupvar == "big" & big == 2000000 & level_label == "Two million"
    assert r(N) == 2
    assert missing(big) if groupvar != "big"
    assert "`: type third'" == "double" & "`: type huge'" == "long"
    quietly count if groupvar == "third" & third == 1/3
    assert r(N) == 2
    quietly count if groupvar == "third" & third == 2/3
    assert r(N) == 2
    quietly count if groupvar == "huge" & huge == 123456789
    assert r(N) == 2
    quietly count if groupvar == "huge" & huge == 987654321
    assert r(N) == 2
    * the labelled value decodes to the printed level label
    tempvar dg
    decode g, gen(`dg')
    assert `dg' == level_label if groupvar == "g"
    restore
}
if _rc == 0 {
    display as result "  PASS: S1 saving() keeps grouping variables: names, types, formats, labels, values"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 saving() grouping variables (rc=`=_rc')"
    local ++fail_count
}

**# S2: stset data and a name collision with a fixed column
local ++test_count
capture restore
capture noisily {
    _rt240_data
    gen double t = py1
    gen byte d = e1 > 0
    stset t, failure(d)
    local f "`output_dir'/rt240_st"
    capture erase "`f'.dta"
    ratetab g, saving("`f'")
    preserve
    use "`f'", clear
    assert _N == 3 & "`: value label g'" == "_rt240_gl"
    assert g == level
    restore
    * a grouping variable named like a saved column saves (2.3.1 saved it):
    * the fixed column keeps its meaning and the copy is g_<name>, or
    * g2_<name> when g_<name> is itself a grouping variable
    _rt240_data
    gen byte group = g
    gen byte level = 4 - g
    gen byte g_group = g
    gen byte nopersontime = g
    label values group _rt240_gl
    local f "`output_dir'/rt240_coll"
    capture erase "`f'.dta"
    ratetab group level g_group nopersontime, events(e1) exposure(py1) saving("`f'")
    assert r(N) == 12
    preserve
    use "`f'", clear
    unab all : *
    assert "`all'" == "outcome outcome_var outcome_label group groupvar level level_label events persontime rate lb ub masked nopersontime g2_group g_level g_group g_nopersontime"
    * fixed columns: group is the grouping-variable number, level the level
    * number, nopersontime the flag
    assert group == 1 if groupvar == "group"
    assert group == 4 if groupvar == "nopersontime"
    assert level == g2_group if groupvar == "group"
    assert nopersontime == 0
    * the copies hold the values (level = 4 - g: level number 1 is value 1)
    assert g_level == level if groupvar == "level"
    assert missing(g_level) if groupvar != "level"
    assert g_group == level if groupvar == "g_group"
    assert g_nopersontime == level if groupvar == "nopersontime"
    assert "`: value label g2_group'" == "_rt240_gl"
    assert "`g2_group[ratetab_groupvar]'" == "group"
    assert "`g_level[ratetab_groupvar]'" == "level"
    assert "`g_nopersontime[ratetab_groupvar]'" == "nopersontime"
    assert "`g_group[ratetab_groupvar]'" == ""
    local ren : char _dta[ratetab_renamed]
    assert "`ren'" == "group=g2_group level=g_level nopersontime=g_nopersontime"
    restore
    * the exact 2.3.1 call
    _rt240_data
    gen byte group = g
    ratetab group, events(e1) exposure(py1) saving("`f'", replace)
    preserve
    use "`f'", clear
    assert g_group == level & group == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: S2 saving() with stset data; fixed-name grouping variables saved as g_<name>"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 saving() stset/collision (rc=`=_rc')"
    local ++fail_count
}

**# S4: a repeated grouping variable fills the rows of every listing
local ++test_count
capture restore
capture noisily {
    _rt240_data
    local f "`output_dir'/rt240_rep"
    capture erase "`f'.dta"
    ratetab g g, events(e1) exposure(py1) saving("`f'")
    preserve
    use "`f'", clear
    assert _N == 6
    unab all : *
    assert word("`all'", -1) == "g" & word("`all'", -2) == "nopersontime"
    assert g == level
    quietly count if group == 2 & !missing(g)
    assert r(N) == 3
    restore
}
if _rc == 0 {
    display as result "  PASS: S4 repeated grouping variable: one column, every listing filled"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 repeated grouping variable (rc=`=_rc')"
    local ++fail_count
}

**# M1: missing grouping values (., .a) are left out of that variable's table only
* (as tabulate; unchanged from 2.3.1). Low keeps its other three rows.
local ++test_count
capture restore
capture noisily {
    _rt240_data
    replace g = .a in 1
    replace g = . in 5
    gen byte h = 1
    ratetab g, events(e1) exposure(py1)
    matrix E = r(estimates)
    assert r(N) == 10
    assert rowsof(E) == 3
    assert E[1, 4] == 0 & E[1, 5] == 7.5
    assert E[2, 4] == 3 & E[2, 5] == 15
    assert E[3, 4] == 8 & E[3, 5] == 40
    * h keeps every row; g's table still drops its two
    ratetab g h, events(e1) exposure(py1)
    matrix E = r(estimates)
    assert r(N) == 12
    assert E[4, 4] == 12 & E[4, 5] == 70
    assert E[1, 5] + E[2, 5] + E[3, 5] == 70 - 2.5 - 5
}
if _rc == 0 {
    display as result "  PASS: M1 missing and extended-missing grouping values left out of that table only"
    local ++pass_count
}
else {
    display as error "  FAIL: M1 missing grouping values (rc=`=_rc')"
    local ++fail_count
}

**# C1: comptab rateframe() carries the empty no-person-time cells through
local ++test_count
capture noisily {
    _rt240_data
    gen double y = _n + mod(_n, 3)
    ratetab g, events(e2) exposure(py2) frame(_c1r, replace)
    collect clear
    quietly collect: poisson y i.g, irr
    quietly regtab, frame(_c1m, replace) noint compact
    comptab _c1m, rateframe(_c1r) rows(all) allmodels keyed effect("IRR") frame(_c1c, replace)
    * High (row 7): rate side empty, no 0 or dash; model side filled
    frame _c1c: assert c2[7] == "" & c3[7] == "" & c4[7] == ""
    frame _c1m: local hi = strtrim(c1[7])
    frame _c1c: assert c5[7] == "`hi'" & "`hi'" != ""
    * the other rows keep their rate cells
    _rt240_ci 4 4
    frame _c1c: assert c2[5] == "4" & c3[5] == "4" & c4[5] == "`r(cell)'"
    frame _c1c: assert c5[5] == "Reference"
    frame _c1c: assert c2[6] == "0" & c3[6] == "8"
    frame drop _c1r _c1m _c1c
}
if _rc == 0 {
    display as result "  PASS: C1 comptab rateframe() keeps no-person-time cells empty"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 comptab pass-through (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _c1r
capture frame drop _c1m
capture frame drop _c1c
collect clear

**# S3: session hygiene on the new paths
local ++test_count
capture noisily {
    _rt240_data
    set varabbrev on
    quietly frames dir
    local before `"`r(frames)'"'
    local f "`output_dir'/rt240_hyg"
    ratetab g, events(e1 e2) exposure(py1 py2) zerocells(dash, persontime) saving("`f'", replace)
    assert c(varabbrev) == "on"
    gen double py0 = 0
    gen byte e0 = 0
    capture ratetab g, events(e0) exposure(py0)
    assert _rc == 459 & c(varabbrev) == "on"
    quietly frames dir
    assert `"`r(frames)'"' == `"`before'"'
    * the caller's data are unchanged
    assert _N == 12
    unab vl : *
    assert "`vl'" == "id g e1 e2 py1 py2 py0 e0"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: S3 varabbrev, frames and data restored"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 session hygiene (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

display "RESULT: test_ratetab_v240 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rt240
if `fail_count' > 0 exit 1

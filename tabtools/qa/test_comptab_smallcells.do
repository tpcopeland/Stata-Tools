* test_comptab_smallcells.do - comptab / hrcomptab smallcells(# [, primary])
* and nosmallcells (1.2.0)
*
* Contract (spec tabtools_smallcells_puttab_comptab_2026-11-18, Priority 2):
* in rate mode a composite masks exactly as its stratetab input would: an
* event count from 1 to #-1 prints <#, its person-time and rate are withheld,
* the effect, interval and p-value of a row are withheld when its own or its
* section's reference count is masked; complementary suppression (>=#) only
* beside a printed total row; a stratetab frame masked at k keeps its masks
* and its threshold applies without smallcells(); nosmallcells overrides. In
* vertical mode regtab's built-in count statistic rows mask 1..#-1 as <#.
* Masking governs printed output only: r() and eplotframe() keep numbers.
*
* Oracles: the raw event counts typed into the strate fixtures (never the
* package's parse of printed text), stratetab's own unmasked and masked
* output, the unmasked comptab composite, the workbook read back with
* openpyxl (tools/xlsx_facts.py), CSV/Markdown/LaTeX/console text, and an
* independent enumeration of the feasible values of every masked cell.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _cs
log using "test_comptab_smallcells.log", replace text name(_cs)

local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "run from the package qa/ directory"
    exit 198
}
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
local repo_dir = regexr("`pkg_dir'", "/tabtools$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global CS_OUT "`output_dir'"
global CS_TOOLS "`qa_dir'/tools"

capture confirm file "`repo_dir'/eplot/eplot.ado"
if _rc {
    display as error "Sibling eplot package not found at `repo_dir'/eplot (required for the forest test)"
    exit 601
}
capture ado uninstall tabtools
capture ado uninstall eplot
quietly net install eplot, from("`repo_dir'/eplot") replace
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

global CS_DASH = uchar(8211)
global CS_GE = uchar(8805)

**# Helpers

* every "value <cell> <text>" fact of one sheet into frame <fr> (cell, text)
capture program drop _cs_xvals
program define _cs_xvals
    version 17.0
    args book sheet fr
    local out "$CS_OUT/_cs_facts_`fr'.txt"
    capture erase "`out'"
    shell python3 "$CS_TOOLS/xlsx_facts.py" "`book'" "`sheet'" "`out'"
    confirm file "`out'"
    capture frame drop `fr'
    frame create `fr' str12 cell strL text
    tempname h
    file open `h' using "`out'", read text
    file read `h' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 6) == "value " {
            local rest = substr(`"`macval(line)'"', 7, .)
            local sp = strpos(`"`macval(rest)'"', " ")
            local cell = substr(`"`macval(rest)'"', 1, `sp' - 1)
            local txt = substr(`"`macval(rest)'"', `sp' + 1, .)
            frame post `fr' ("`cell'") (`"`macval(txt)'"')
        }
        file read `h' line
    }
    file close `h'
end

* r(text) of one cell of an _cs_xvals frame ("" when the cell is empty)
capture program drop _cs_xget
program define _cs_xget, rclass
    version 17.0
    args fr cell
    local t ""
    frame `fr' {
        forvalues i = 1/`=_N' {
            if cell[`i'] == "`cell'" local t = text[`i']
        }
    }
    return local text `"`t'"'
end

* r(n) = number of lines of a text file holding needle; r(found) = r(n) > 0
capture program drop _cs_count
program define _cs_count, rclass
    version 17.0
    args file needle
    tempname h
    local n 0
    file open `h' using `"`file'"', read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local ++n
        file read `h' line
    }
    file close `h'
    return scalar n = `n'
    return scalar found = (`n' > 0)
end

* assert two frames agree in every observation of the named string vars
capture program drop _cs_same
program define _cs_same
    version 17.0
    args f1 f2 vars
    frame `f1': local n1 = _N
    frame `f2': local n2 = _N
    assert `n1' == `n2'
    foreach v of local vars {
        forvalues i = 1/`n1' {
            frame `f1': local a = `v'[`i']
            frame `f2': local b = `v'[`i']
            if `"`a'"' != `"`b'"' {
                display as error `"  `v'[`i']: "`a'" vs "`b'""'
                exit 9
            }
        }
    }
end

* Excel column letter of composite variable c<j> (title is column A)
capture program drop _cs_col
program define _cs_col, rclass
    version 17.0
    args j
    return local L = char(65 + `j')
end

* r(found) = 1 when value v is held (within 1e-6) by any numeric variable
* of any serset in memory: the data a drawn graph actually plotted
capture program drop _cs_inserset
program define _cs_inserset, rclass
    version 17.0
    args v
    local found 0
    preserve
    forvalues id = 0/40 {
        capture serset set `id'
        if _rc continue
        capture serset use, clear
        if _rc continue
        foreach x of varlist _all {
            capture confirm numeric variable `x'
            if _rc continue
            quietly count if abs(`x' - `v') < 1e-6
            if r(N) local found 1
        }
    }
    restore
    return scalar found = `found'
end

* Feasibility from printed cells only: frame fr, total row tr, three
* section rows r1-r3 of column c2. A cell prints a number (fixed), "<5"
* (1..4) or ">=5" (5..cap). Enumerates every assignment of the section
* cells, derives the total, and keeps those consistent with the printed
* total. r(min_feasible) = fewest feasible values of any masked cell
* (total included); 99 when nothing is masked.
capture program drop _cs_feasible
program define _cs_feasible, rclass
    version 17.0
    args fr tr r1 r2 r3
    local cap 40
    local j 0
    foreach r in `tr' `r1' `r2' `r3' {
        frame `fr': local t = strtrim(c2[`r'])
        if "`t'" == "<5" {
            local lo_`j' 1
            local hi_`j' 4
            local m_`j' 1
        }
        else if "`t'" == "$CS_GE" + "5" {
            local lo_`j' 5
            local hi_`j' `cap'
            local m_`j' 1
        }
        else {
            local v = real(subinstr("`t'", ",", "", .))
            assert !missing(`v')
            local lo_`j' `v'
            local hi_`j' `v'
            local m_`j' 0
        }
        local f_`j' ""
        local ++j
    }
    forvalues a = `lo_1'/`hi_1' {
        forvalues b = `lo_2'/`hi_2' {
            forvalues c = `lo_3'/`hi_3' {
                local t = `a' + `b' + `c'
                if `t' < `lo_0' | `t' > `hi_0' continue
                local f_0 : list f_0 | t
                local f_1 : list f_1 | a
                local f_2 : list f_2 | b
                local f_3 : list f_3 | c
            }
        }
    }
    local minf 99
    forvalues j = 0/3 {
        if `m_`j'' {
            local nf : word count `f_`j''
            local minf = min(`minf', `nf')
        }
    }
    return scalar min_feasible = `minf'
end

**# Fixtures

* Raw event counts (the oracle). Two outcomes, k = 5:
*   Binary  None    D1 = 12  D2 = 3    (outcome-2 reference masked)
*           Current D1 = 4   D2 = 20   (outcome-1 count masked)
*   Dose    None    D1 = 10  D2 = 8
*           Low     D1 = 5   D2 = 1    (5 = k prints; 1 masked)
*           High    D1 = 0   D2 = 9    (0 prints)
* Section sums differ (16/15 and 23/18), and no section has one category,
* so no total row exists: primary masking is complete.
capture program drop _cs_strate
program define _cs_strate
    version 17.0
    args name lab dvals yvals
    clear
    local n : word count `dvals'
    quietly set obs `n'
    gen exposure = _n - 1
    gen double _D = .
    gen double _Y = .
    forvalues i = 1/`n' {
        quietly replace _D = `: word `i' of `dvals'' in `i'
        quietly replace _Y = `: word `i' of `yvals'' in `i'
    }
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.8
    gen double _Upper = _Rate * 1.2 + 0.0001
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    if "`lab'" == "b" label define _csb 0 "None" 1 "Current", replace
    if "`lab'" == "d" label define _csd 0 "None" 1 "Low" 2 "High", replace
    if "`lab'" == "o" {
        replace exposure = 1
        label define _cso 1 "All", replace
    }
    label values exposure _cs`lab'
    quietly save "$CS_OUT/`name'.dta", replace
end

capture program drop _cs_fixture
program define _cs_fixture
    version 17.0
    _cs_strate _csb1 b "12 4" "1000 300"
    _cs_strate _csb2 b "3 20" "1000 300"
    _cs_strate _csd1 d "10 5 0" "1000 300 400"
    _cs_strate _csd2 d "8 1 9" "1000 300 400"
    local u "$CS_OUT/_csb1 $CS_OUT/_csb2 $CS_OUT/_csd1 $CS_OUT/_csd2"
    quietly stratetab, using(`u') outcomes(2) frame(_cs_rf0, replace) ///
        outlabels("Outcome 1" \ "Outcome 2") outcomeids("t1" \ "t2") ///
        explabels("Binary" \ "Dose")
    quietly stratetab, using(`u') outcomes(2) frame(_cs_rf5, replace) ///
        outlabels("Outcome 1" \ "Outcome 2") outcomeids("t1" \ "t2") ///
        explabels("Binary" \ "Dose") smallcells(5)
    * models: i.cur and i.dose, one Cox model per outcome
    clear
    quietly set obs 300
    set seed 20261118
    gen byte dose = mod(_n, 3)
    label define _csd 0 "None" 1 "Low" 2 "High", replace
    label values dose _csd
    gen byte cur = dose > 0
    label define _csb 0 "None" 1 "Current", replace
    label values cur _csb
    gen double t1 = 1 + 12 * runiform() * exp(-0.3 * cur)
    gen byte d1 = mod(_n, 4) != 0
    gen double t2 = 1 + 10 * runiform() * exp(-0.2 * dose)
    gen byte d2 = mod(_n, 5) != 0
    collect clear
    quietly stset t1, failure(d1)
    quietly collect: stcox i.cur, nolog
    quietly stset t2, failure(d2)
    quietly collect: stcox i.cur, nolog
    quietly regtab, models("Outcome 1" \ "Outcome 2") frame(_cs_mb, replace) ///
        eplotframe(_cs_mbe, replace) noint
    collect clear
    quietly stset t1, failure(d1)
    quietly collect: stcox i.dose, nolog
    quietly stset t2, failure(d2)
    quietly collect: stcox i.dose, nolog
    quietly regtab, models("Outcome 1" \ "Outcome 2") frame(_cs_md, replace) ///
        eplotframe(_cs_mde, replace) noint
    collect clear
    quietly stset t1, failure(d1)
    quietly collect: stcox i.dose, nolog
    quietly regtab, models("Outcome 1") frame(_cs_md1, replace) noint
    clear
end

* composite rows: 5 None(b) 6 Current 8 None(d) 9 Low 10 High
* outcome o: events c(2+5(o-1)), py +1, rate +2, effect +3, p +4
global CS_CMP `"modelframes(_cs_mb _cs_md) rows(3 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2")"'

_cs_fixture
* the unmasked composite: oracle for every printed effect
quietly comptab _cs_rf0, $CS_CMP frame(_cs_o0, replace) eplotframe(_cs_o0e, replace)

**# T1: comptab smallcells(5) on a rate frame = stratetab smallcells(5), cell for cell
local ++test_count
capture noisily {
    local sx "$CS_OUT/cs_t1_strate.xlsx"
    local cx "$CS_OUT/cs_t1_comp.xlsx"
    capture erase "`sx'"
    capture erase "`cx'"
    _cs_fixture
    local u "$CS_OUT/_csb1 $CS_OUT/_csb2 $CS_OUT/_csd1 $CS_OUT/_csd2"
    quietly stratetab, using(`u') outcomes(2) frame(_cs_s5, replace) ///
        outlabels("Outcome 1" \ "Outcome 2") outcomeids("t1" \ "t2") ///
        explabels("Binary" \ "Dose") smallcells(5) xlsx("`sx'") sheet("S")
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) frame(_cs_c5, replace) xlsx("`cx'") sheet("C")
    _cs_xvals "`sx'" "S" _cs_xs
    _cs_xvals "`cx'" "C" _cs_xc
    frame _cs_s5: local N = _N
    frame _cs_c5: assert _N == `N'
    local ncmp 0
    forvalues r = 4/`=`N' + 1' {
        * label column, then events / person-time / rate of each outcome
        _cs_xget _cs_xs "B`r'"
        local a `"`r(text)'"'
        _cs_xget _cs_xc "B`r'"
        assert `"`a'"' == `"`r(text)'"'
        forvalues o = 1/2 {
            forvalues j = 0/2 {
                _cs_col `=2 + (`o' - 1) * 3 + `j''
                _cs_xget _cs_xs "`r(L)'`r'"
                local a `"`r(text)'"'
                _cs_col `=2 + (`o' - 1) * 5 + `j''
                _cs_xget _cs_xc "`r(L)'`r'"
                if `"`a'"' != `"`r(text)'"' {
                    display as error `"  row `r' outcome `o' stat `j': stratetab "`a'" comptab "`r(text)'""'
                    exit 9
                }
                local ++ncmp
            }
        }
    }
    assert `ncmp' > 40
    * the frames agree the same way
    forvalues o = 1/2 {
        forvalues j = 0/2 {
            local sv = 2 + (`o' - 1) * 3 + `j'
            local cv = 2 + (`o' - 1) * 5 + `j'
            forvalues r = 4/`N' {
                frame _cs_s5: local a = c`sv'[`r']
                frame _cs_c5: local b = c`cv'[`r']
                assert `"`a'"' == `"`b'"'
            }
        }
    }
    * and stratetab really masked three cells (the fixture is not trivial)
    frame _cs_s5: assert c2[6] == "<5" & c5[5] == "<5" & c5[9] == "<5"
}
if _rc == 0 {
    display as result "  PASS: T1 comptab smallcells(5) matches stratetab smallcells(5) cell for cell (workbook read back, frames)"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 stratetab parity (rc=`=_rc')"
    local ++fail_count
}

**# T2: boundary and withheld cells, against the raw counts
local ++test_count
capture noisily {
    _cs_fixture
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) frame(_cs_c5, replace)
    local r_nw = r(N_withheld)
    * raw D by row: row 5 (12, 3) 6 (4, 20) 8 (10, 8) 9 (5, 1) 10 (0, 9)
    * section reference rows: 5 (Binary) and 8 (Dose)
    local rows "5 6 8 9 10"
    local D1 "12 4 10 5 0"
    local D2 "3 20 8 1 9"
    local refof "5 5 8 8 8"
    local nwh 0
    forvalues i = 1/5 {
        local r : word `i' of `rows'
        local rr : word `i' of `refof'
        forvalues o = 1/2 {
            local d : word `i' of `D`o''
            local ri = cond(`rr' == 5, 1, 3)
            local dref : word `ri' of `D`o''
            local m = (`d' >= 1 & `d' < 5)
            local mref = (`dref' >= 1 & `dref' < 5)
            local ev = 2 + (`o' - 1) * 5
            local sv = 2 + (`o' - 1) * 3
            frame _cs_c5 {
                local e = c`ev'[`r']
                local py = c`=`ev' + 1'[`r']
                local rt = c`=`ev' + 2'[`r']
                local ef = c`=`ev' + 3'[`r']
                local p = c`=`ev' + 4'[`r']
            }
            frame _cs_rf0 {
                local e0 = c`sv'[`r']
                local py0 = c`=`sv' + 1'[`r']
                local rt0 = c`=`sv' + 2'[`r']
            }
            frame _cs_o0 {
                local ef0 = c`=`ev' + 3'[`r']
                local p0 = c`=`ev' + 4'[`r']
            }
            if `m' {
                assert "`e'" == "<5"
                assert "`py'" == "$CS_DASH" & "`rt'" == "$CS_DASH"
            }
            else {
                assert "`e'" == "`e0'" & "`py'" == "`py0'" & "`rt'" == "`rt0'"
            }
            if `r' == `rr' {
                assert "`ef'" == "Reference"
            }
            else if `m' | `mref' {
                assert "`ef'" == "$CS_DASH" & "`p'" == "$CS_DASH"
                local nwh = `nwh' + 2
            }
            else {
                assert "`ef'" == "`ef0'" & "`p'" == "`p0'"
                assert strpos("`ef'", "(") > 0
            }
        }
    }
    * the boundary cells by name: 5 and 0 print, 4, 3 and 1 do not
    frame _cs_c5 {
        assert c2[9] == "5" & c2[10] == "0"
        assert c2[6] == "<5" & c7[5] == "<5" & c7[9] == "<5"
        * a printed count beside a masked reference: its effect is withheld
        assert c7[6] == "20" & c10[6] == "$CS_DASH"
    }
    assert `nwh' == 6
    assert `r_nw' == 6
}
if _rc == 0 {
    display as result "  PASS: T2 #-1 masked, # and 0 printed; person-time, rate, effect, CI and p withheld exactly where required (reference rule)"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 boundary/withheld cells (rc=`=_rc')"
    local ++fail_count
}

**# T3: r(), data and eplotframe() are not masked; new scalars
local ++test_count
capture noisily {
    _cs_fixture
    sysuse auto, clear
    datasignature
    local sig0 "`r(datasignature)'"
    quietly comptab _cs_rf0, $CS_CMP frame(_cs_u, replace) eplotframe(_cs_ue, replace)
    foreach s in N_rows N_outcomes N_sections N_modelrows N_modelframes N_models_per_outcome N_modelonly ci_level {
        local u_`s' = r(`s')
    }
    assert r(smallcells) == 0
    assert missing(r(N_primary_suppressed))
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) frame(_cs_m, replace) eplotframe(_cs_me, replace)
    foreach s in N_rows N_outcomes N_sections N_modelrows N_modelframes N_models_per_outcome N_modelonly ci_level {
        assert r(`s') == `u_`s''
    }
    assert r(smallcells) == 5
    assert "`r(smallcells_mode)'" == "full"
    assert r(N_primary_suppressed) == 3
    assert r(N_secondary_suppressed) == 0
    assert r(N_withheld) == 6
    datasignature
    assert "`r(datasignature)'" == "`sig0'"
    * the numeric companion keeps every estimate
    frame _cs_ue: local n = _N
    frame _cs_me: assert _N == `n'
    foreach v in estimate ll ul pvalue {
        forvalues i = 1/`n' {
            frame _cs_ue: local a = `v'[`i']
            frame _cs_me: local b = `v'[`i']
            assert "`a'" == "`b'"
        }
    }
    frame _cs_me: count if !missing(estimate)
    assert r(N) == 6
    frame _cs_m: local ch : char _dta[tabtools_smallcells]
    assert "`ch'" == "5"
    frame _cs_u: local ch : char _dta[tabtools_smallcells]
    assert "`ch'" == "0"
}
if _rc == 0 {
    display as result "  PASS: T3 r() unchanged apart from r(smallcells)/r(N_*); data unchanged; eplotframe keeps numbers; frame records the threshold"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 returns/data/companion (rc=`=_rc')"
    local ++fail_count
}

**# T4: every sink masked identically (Excel, CSV, Markdown, LaTeX, console)
local ++test_count
capture noisily {
    _cs_fixture
    local x "$CS_OUT/cs_t4.xlsx"
    local c "$CS_OUT/cs_t4.csv"
    local m "$CS_OUT/cs_t4.md"
    local t "$CS_OUT/cs_t4.tex"
    local k "$CS_OUT/cs_t4_console.log"
    foreach f in x c m t k {
        capture erase "``f''"
    }
    frame _cs_o0: local hr_cur1 = c5[6]
    frame _cs_o0: local hr_cur2 = c10[6]
    frame _cs_o0: local hr_low2 = c10[9]
    frame _cs_o0: local hr_hi1 = c5[10]
    frame _cs_rf0: local rt_cur1 = c4[6]
    log using "`k'", text replace name(_cs_con)
    comptab _cs_rf0, $CS_CMP smallcells(5) xlsx("`x'") sheet("T4") ///
        csv("`c'") markdown("`m'") latex("`t'")
    log close _cs_con
    _cs_xvals "`x'" "T4" _cs_x4
    * workbook: the composite cells as written (c<j> in column j+1)
    _cs_xget _cs_x4 "C6"
    assert `"`r(text)'"' == "<5"
    _cs_xget _cs_x4 "D6"
    assert `"`r(text)'"' == "$CS_DASH"
    _cs_xget _cs_x4 "F6"
    assert `"`r(text)'"' == "$CS_DASH"
    _cs_xget _cs_x4 "K6"
    assert `"`r(text)'"' == "$CS_DASH"
    _cs_xget _cs_x4 "H5"
    assert `"`r(text)'"' == "<5"
    _cs_xget _cs_x4 "H9"
    assert `"`r(text)'"' == "<5"
    _cs_xget _cs_x4 "F10"
    assert `"`r(text)'"' == `"`hr_hi1'"'
    local nlt 0
    frame _cs_x4: count if text == "<5"
    assert r(N) == 3
    * text sinks: three masks, and no withheld effect or rate anywhere
    foreach f in c m t k {
        foreach needle in "`hr_cur1'" "`hr_cur2'" "`hr_low2'" "`rt_cur1'" {
            _cs_count "``f''" "`needle'"
            if r(found) {
                display as error "  ``f'' prints withheld text `needle'"
                exit 9
            }
        }
        _cs_count "``f''" "`hr_hi1'"
        assert r(found)
    }
    * the mask token as each sink prints it, once per masked row
    _cs_count "`c'" "<5"
    assert r(n) == 3
    _cs_count "`k'" "<5"
    assert r(n) == 3
    _cs_count "`m'" "<5"
    local md_n = r(n)
    _cs_count "`m'" "&lt;5"
    local md_n = `md_n' + r(n)
    assert `md_n' == 3
    _cs_count "`t'" "<5"
    local tx_n = r(n)
    _cs_count "`t'" "\textless{}5"
    local tx_n = `tx_n' + r(n)
    _cs_count "`t'" "$<$5"
    local tx_n = `tx_n' + r(n)
    assert `tx_n' == 3
}
if _rc == 0 {
    display as result "  PASS: T4 Excel, CSV, Markdown, LaTeX and console masked identically; no withheld effect or rate in any sink"
    local ++pass_count
}
else {
    local rc = _rc
    capture log close _cs_con
    display as error "  FAIL: T4 sinks (rc=`rc')"
    local ++fail_count
}

**# T5: total row -> complementary suppression; no masked cell recoverable
local ++test_count
capture noisily {
    * Overall (All) 23 = Dose None 10 + Low 4 + High 9
    _cs_strate _cso1 o "23" "1700"
    _cs_strate _csd1 d "10 4 9" "1000 300 400"
    quietly stratetab, using($CS_OUT/_cso1 $CS_OUT/_csd1) outcomes(1) frame(_cs_rt0, replace) ///
        outlabels("Outcome 1") outcomeids("t1") explabels("Overall" \ "Dose")
    _cs_fixture
    quietly comptab _cs_rt0, modelframes(_cs_md1) rows(3/4) outcomemap("Outcome 1") keyed ///
        smallcells(5) frame(_cs_t5, replace)
    assert r(N_primary_suppressed) == 1 & r(N_secondary_suppressed) == 1
    * rows: 5 All, 7 None, 8 Low, 9 High
    frame _cs_t5 {
        assert c2[5] == "23" & c2[7] == "10"
        assert c2[8] == "<5"
        assert c2[9] == "$CS_GE" + "5"
        assert c3[9] == "$CS_DASH" & c4[9] == "$CS_DASH"
        assert c5[9] == "$CS_DASH" & c5[8] == "$CS_DASH"
    }
    * Independent recomputation: from the printed cells alone, enumerate
    * every assignment of the masked cells (primary 1..4, complementary 5..
    * total) that reproduces the printed total; each masked cell must keep
    * at least two feasible values.
    local total 0
    local known 0
    local masked ""
    frame _cs_t5 {
        local total = real(subinstr(c2[5], ",", "", .))
        foreach r in 7 8 9 {
            local txt = c2[`r']
            if "`txt'" == "<5" local masked "`masked' p`r'"
            else if "`txt'" == "$CS_GE" + "5" local masked "`masked' s`r'"
            else local known = `known' + real(subinstr("`txt'", ",", "", .))
        }
    }
    local nm : word count `masked'
    assert `nm' == 2
    local gap = `total' - `known'
    local m1 : word 1 of `masked'
    local m2 : word 2 of `masked'
    local vals1 ""
    local vals2 ""
    forvalues a = 0/`gap' {
        local b = `gap' - `a'
        local ok1 = cond(substr("`m1'", 1, 1) == "p", `a' >= 1 & `a' <= 4, `a' >= 5)
        local ok2 = cond(substr("`m2'", 1, 1) == "p", `b' >= 1 & `b' <= 4, `b' >= 5)
        if `ok1' & `ok2' {
            local vals1 : list vals1 | a
            local vals2 : list vals2 | b
        }
    }
    assert `: word count `vals1'' >= 2
    assert `: word count `vals2'' >= 2
    * primary turns it off, and the masked count is then recoverable: the
    * documented consequence of primary, shown by the same arithmetic
    quietly comptab _cs_rt0, modelframes(_cs_md1) rows(3/4) outcomemap("Outcome 1") keyed ///
        smallcells(5, primary) frame(_cs_t5p, replace)
    assert "`r(smallcells_mode)'" == "primary" & r(N_secondary_suppressed) == 0
    frame _cs_t5p {
        assert c2[8] == "<5" & c2[9] == "9"
        assert real(c2[5]) - real(c2[7]) - real(c2[9]) == 4
    }
}
if _rc == 0 {
    display as result "  PASS: T5 total row brings one >=5 cell (withheld with its person-time, rate and effect); every masked cell keeps 2+ feasible values; primary turns it off"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 complementary suppression (rc=`=_rc')"
    local ++fail_count
}

**# T6: session default, primary session mode, nosmallcells
local ++test_count
capture noisily {
    _cs_fixture
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) frame(_cs_c5, replace)
    quietly tabtools set smallcells 5
    local k "$CS_OUT/cs_t6.log"
    capture erase "`k'"
    log using "`k'", text replace name(_cs_con)
    comptab _cs_rf0, $CS_CMP frame(_cs_s, replace)
    local r_k = r(smallcells)
    local r_mode "`r(smallcells_mode)'"
    log close _cs_con
    assert `r_k' == 5 & "`r_mode'" == "full"
    _cs_count "`k'" "(tabtools: using session smallcells(5))"
    assert r(found)
    _cs_same _cs_s _cs_c5 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
    quietly comptab _cs_rf0, $CS_CMP nosmallcells frame(_cs_n, replace)
    assert r(smallcells) == 0
    _cs_same _cs_n _cs_o0 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
    quietly tabtools set smallcells 5 primary
    quietly comptab _cs_rf0, $CS_CMP frame(_cs_sp, replace)
    assert "`r(smallcells_mode)'" == "primary"
    _cs_same _cs_sp _cs_c5 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
    quietly tabtools set clear
    quietly comptab _cs_rf0, $CS_CMP frame(_cs_none, replace)
    assert r(smallcells) == 0
    _cs_same _cs_none _cs_o0 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
}
if _rc == 0 {
    display as result "  PASS: T6 session default applies and is echoed; primary session mode; nosmallcells overrides it"
    local ++pass_count
}
else {
    local rc = _rc
    capture log close _cs_con
    quietly tabtools set clear
    display as error "  FAIL: T6 session default / nosmallcells (rc=`rc')"
    local ++fail_count
}

**# T7: fail-safe on a rate frame stratetab masked (char tabtools_smallcells)
local ++test_count
capture noisily {
    _cs_fixture
    frame _cs_rf5: local ch : char _dta[tabtools_smallcells]
    assert "`ch'" == "5"
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) frame(_cs_c5, replace)
    * no option: the frame's threshold applies to the whole table
    local k "$CS_OUT/cs_t7.log"
    capture erase "`k'"
    log using "`k'", text replace name(_cs_con)
    comptab _cs_rf5, $CS_CMP frame(_cs_f, replace)
    local r_k = r(smallcells)
    log close _cs_con
    assert `r_k' == 5
    _cs_count "`k'" "was masked by stratetab at smallcells(5)"
    assert r(found)
    _cs_same _cs_f _cs_c5 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
    * a smaller explicit threshold is raised to the frame's: never fewer masks
    quietly comptab _cs_rf5, $CS_CMP smallcells(3) frame(_cs_f3, replace)
    assert r(smallcells) == 5
    _cs_same _cs_f3 _cs_c5 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
    * a larger one masks more (the Low/outcome-1 count of 5 at k = 6)
    quietly comptab _cs_rf5, $CS_CMP smallcells(6) frame(_cs_f6, replace)
    assert r(smallcells) == 6
    frame _cs_f6: assert c2[9] == "<6" & c2[6] == "<5"
    * nosmallcells: masked text stays as stratetab printed it, but comptab
    * withholds nothing (the effect of the masked row prints)
    quietly comptab _cs_rf5, $CS_CMP nosmallcells frame(_cs_fn, replace)
    assert r(smallcells) == 0
    frame _cs_o0: local hr = c5[6]
    frame _cs_fn: assert c2[6] == "<5" & c5[6] == "`hr'"
    frame _cs_fn: local ch : char _dta[tabtools_smallcells]
    assert "`ch'" == "5"
    * before this change comptab printed the masked row's effect from such a
    * frame with no option at all; it now never does
    frame _cs_f: assert c5[6] == "$CS_DASH"
}
if _rc == 0 {
    display as result "  PASS: T7 a stratetab-masked frame keeps its masks; its threshold applies without smallcells(), raises a smaller one; nosmallcells is the explicit override"
    local ++pass_count
}
else {
    local rc = _rc
    capture log close _cs_con
    display as error "  FAIL: T7 frame-char fail-safe (rc=`rc')"
    local ++fail_count
}

**# T8: vertical mode masks regtab's count statistic rows (mincell style)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg in 1/4
    quietly collect: regress price mpg in 1/5
    quietly collect: regress price mpg
    quietly regtab, frame(_cs_v, replace) noint stats(n) models("A \ B \ C")
    frame _cs_v: local nr = _N
    * data rows: 1 mpg, 2 Observations
    frame _cs_v: assert A[5] == "Observations"
    quietly comptab _cs_v, rows(1 2) frame(_cs_v0, replace)
    assert r(smallcells) == 0
    quietly comptab _cs_v, rows(1 2) smallcells(5) frame(_cs_v5, replace)
    assert r(smallcells) == 5 & r(N_primary_suppressed) == 1
    frame _cs_v5 {
        assert A[5] == "Observations"
        assert c1[5] == "<5" & c4[5] == "5" & c7[5] == "74"
    }
    * estimate rows are untouched
    _cs_same _cs_v5 _cs_v0 "c2 c3 c4 c5 c6 c7 c8 c9"
    frame _cs_v0: local e = c1[4]
    frame _cs_v5: assert c1[4] == "`e'"
    * a composite remembers its threshold; reused as a source it applies again
    frame _cs_v5: local ch : char _dta[tabtools_smallcells]
    assert "`ch'" == "5"
    quietly comptab _cs_v, rows(1 2) nosmallcells frame(_cs_vn, replace)
    frame _cs_vn: assert c1[5] == "4"
    quietly comptab _cs_v, rows(1 2) smallcells(5, primary) frame(_cs_vp, replace)
    assert "`r(smallcells_mode)'" == "primary"
    frame _cs_vp: assert c1[5] == "<5"
}
if _rc == 0 {
    display as result "  PASS: T8 vertical mode: Observations 4 -> <5, 5 and 74 printed; estimates untouched; nosmallcells/primary"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 vertical mode (rc=`=_rc')"
    local ++fail_count
}

**# T9: hrcomptab forwards smallcells()/nosmallcells: same output as comptab
local ++test_count
capture noisily {
    _cs_fixture
    local cx "$CS_OUT/cs_t9_c.csv"
    local hx "$CS_OUT/cs_t9_h.csv"
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) frame(_cs_c5, replace) csv("`cx'")
    local c_np = r(N_primary_suppressed)
    local c_nw = r(N_withheld)
    quietly hrcomptab _cs_rf0, $CS_CMP smallc(5) frame(_cs_h5, replace) csv("`hx'")
    assert r(smallcells) == 5 & r(N_primary_suppressed) == `c_np' & r(N_withheld) == `c_nw'
    _cs_same _cs_h5 _cs_c5 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
    * identical CSV bytes
    tempname h1 h2
    file open `h1' using "`cx'", read text
    file open `h2' using "`hx'", read text
    file read `h1' l1
    file read `h2' l2
    while r(eof) == 0 {
        assert `"`macval(l1)'"' == `"`macval(l2)'"'
        file read `h1' l1
        file read `h2' l2
    }
    file close `h1'
    file close `h2'
    quietly hrcomptab _cs_rf5, $CS_CMP nosmallc frame(_cs_hn, replace)
    assert r(smallcells) == 0
    quietly hrcomptab _cs_rf5, $CS_CMP frame(_cs_hf, replace)
    _cs_same _cs_hf _cs_c5 "c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11"
}
if _rc == 0 {
    display as result "  PASS: T9 hrcomptab smallc(5)/nosmallc forward to comptab: same frame, CSV and r()"
    local ++pass_count
}
else {
    local rc = _rc
    capture file close `h1'
    capture file close `h2'
    display as error "  FAIL: T9 hrcomptab forwarding (rc=`rc')"
    local ++fail_count
}

**# T10: forest plot withholds; eplotframe keeps numbers
local ++test_count
capture noisily {
    _cs_fixture
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) forest eplotframe(_cs_fe, replace) ///
        eplotoptions(name(_cs_g, replace))
    frame _cs_fe: count if !missing(estimate)
    assert r(N) == 6
    capture graph drop _cs_g
    * What the forest plotted, read from the graph's sersets. From the raw
    * counts: withheld are Current (outcome 1 count 4; outcome 2 reference
    * 3) and Low outcome 2 (count 1); plotted are Low 1, High 1 and High 2.
    frame _cs_fe {
        local n_wh 0
        local n_pl 0
        forvalues i = 1/`=_N' {
            if missing(estimate[`i']) continue
            local lab = strtrim(label[`i'])
            local m = model[`i']
            local wh = ("`lab'" == "Current") | ("`lab'" == "Low" & `m' == 2)
            if `wh' {
                local ++n_wh
                local wh_`n_wh' = estimate[`i']
            }
            else {
                local ++n_pl
                local pl_`n_pl' = estimate[`i']
            }
        }
    }
    assert `n_wh' == 3 & `n_pl' == 3
    serset clear
    graph drop _all
    quietly comptab _cs_rf0, $CS_CMP smallcells(5) forest eplotoptions(name(_cs_g, replace))
    forvalues i = 1/3 {
        _cs_inserset `wh_`i''
        assert r(found) == 0
        _cs_inserset `pl_`i''
        assert r(found) == 1
    }
    * control: without masking the same probe sees every estimate
    serset clear
    graph drop _all
    quietly comptab _cs_rf0, $CS_CMP forest eplotoptions(name(_cs_g, replace))
    forvalues i = 1/3 {
        _cs_inserset `wh_`i''
        assert r(found) == 1
    }
    serset clear
    capture graph drop _cs_g
}
if _rc == 0 {
    display as result "  PASS: T10 forest plots only the 3 unwithheld estimates (sersets); eplotframe() keeps all 6"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 forest (rc=`=_rc')"
    local ++fail_count
}

**# T11: errors
local ++test_count
capture noisily {
    _cs_fixture
    foreach bad in "smallcells(2)" "smallcells(0)" "smallcells(abc)" "smallcells(5, full)" "smallcells(5) nosmallcells" {
        capture comptab _cs_rf0, $CS_CMP `bad'
        if _rc != 198 {
            display as error "  `bad': rc `=_rc', expected 198"
            exit 9
        }
    }
    capture comptab _cs_v, rows(1 2) smallcells(2)
    assert _rc == 198
    capture hrcomptab _cs_rf0, $CS_CMP smallcells(1)
    assert _rc == 198
    * a stratetab-masked section beside a total row cannot be certified
    _cs_strate _cso1 o "23" "1700"
    _cs_strate _csd1 d "10 4 9" "1000 300 400"
    quietly stratetab, using($CS_OUT/_cso1 $CS_OUT/_csd1) outcomes(1) frame(_cs_rt5, replace) ///
        outlabels("Outcome 1") outcomeids("t1") explabels("Overall" \ "Dose") smallcells(5)
    _cs_fixture
    capture comptab _cs_rt5, modelframes(_cs_md1) rows(3/4) outcomemap("Outcome 1") keyed
    assert _rc == 459
    * an unreadable event count in an unmasked frame is an error, not a guess
    frame copy _cs_rf0 _cs_bad, replace
    frame _cs_bad: replace c2 = "n/a" in 6
    frame _cs_bad: char _dta[tabtools_smallcells] "0"
    capture comptab _cs_bad, $CS_CMP smallcells(5)
    assert _rc == 459
    * without smallcells() the same frame is copied as before
    capture comptab _cs_bad, $CS_CMP
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: T11 invalid thresholds, smallcells()+nosmallcells, uncertifiable masked frame and unreadable counts are errors"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 errors (rc=`=_rc')"
    local ++fail_count
}

**# T12: the engine masks the total row itself (rowmask); nothing recoverable
local ++test_count
capture noisily {
    _cs_fixture
    * Overall = Dose None + Low + High; with 0/4/4 and 4/4/4 no unmasked
    * nonzero cell of Dose can be the complement, so the total must go
    foreach case in "0 4 4" "4 4 4" {
        local tot 0
        foreach v of local case {
            local tot = `tot' + `v'
        }
        _cs_strate _cso1 o "`tot'" "1700"
        _cs_strate _csd1 d "`case'" "1000 300 400"
        quietly stratetab, using($CS_OUT/_cso1 $CS_OUT/_csd1) outcomes(1) frame(_cs_rt0, replace) ///
            outlabels("Outcome 1") outcomeids("t1") explabels("Overall" \ "Dose")
        quietly comptab _cs_rt0, modelframes(_cs_md1) rows(3/4) outcomemap("Outcome 1") keyed ///
            smallcells(5) frame(_cs_t12, replace)
        assert r(N_secondary_suppressed) == 1
        * rows: 5 All, 7 None, 8 Low, 9 High
        frame _cs_t12 {
            assert c2[5] == "$CS_GE" + "5"
            assert c3[5] == "$CS_DASH" & c4[5] == "$CS_DASH"
            assert c2[8] == "<5" & c2[9] == "<5"
            if "`case'" == "0 4 4" assert c2[7] == "0"
            else assert c2[7] == "<5"
        }
        _cs_feasible _cs_t12 5 7 8 9
        if r(min_feasible) < 2 {
            display as error "  `case': a masked cell has `r(min_feasible)' feasible value(s)"
            exit 9
        }
    }
}
if _rc == 0 {
    display as result "  PASS: T12 counts 0/4/4 and 4/4/4 beside a total: the total prints >=5 (person-time, rate withheld); every masked cell keeps 2+ feasible values"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 total row masked by the engine (rc=`=_rc')"
    local ++fail_count
}

**# T13: a masked total that a second section also sums to is an error
local ++test_count
capture noisily {
    _cs_fixture
    _cs_strate _cso1 o "8" "1700"
    _cs_strate _csd1 d "0 4 4" "1000 300 400"
    * Sex 8/0/0 (nothing masked) and 5/3/0 (one masked) both add up to 8
    foreach sex in "8 0 0" "5 3 0" {
        _cs_strate _csd2 d "`sex'" "1000 300 400"
        quietly stratetab, using($CS_OUT/_cso1 $CS_OUT/_csd1 $CS_OUT/_csd2) outcomes(1) ///
            frame(_cs_rt3, replace) outlabels("Outcome 1") outcomeids("t1") ///
            explabels("Overall" \ "Dose" \ "Sex")
        capture comptab _cs_rt3, modelframes(_cs_md1) rows(3/4) outcomemap("Outcome 1") keyed smallcells(5)
        if _rc != 459 {
            display as error "  Sex `sex': rc `=_rc', expected 459"
            exit 9
        }
        * primary has no complementary step: it runs (and documents the risk)
        capture comptab _cs_rt3, modelframes(_cs_md1) rows(3/4) outcomemap("Outcome 1") keyed ///
            smallcells(5, primary)
        assert _rc == 0
    }
    * an unmasked total anchored by two sections stays fine
    _cs_strate _cso1 o "23" "1700"
    _cs_strate _csd1 d "10 4 9" "1000 300 400"
    _cs_strate _csd2 d "20 3 0" "1000 300 400"
    quietly stratetab, using($CS_OUT/_cso1 $CS_OUT/_csd1 $CS_OUT/_csd2) outcomes(1) ///
        frame(_cs_rt3, replace) outlabels("Outcome 1") outcomeids("t1") ///
        explabels("Overall" \ "Dose" \ "Sex")
    quietly comptab _cs_rt3, modelframes(_cs_md1) rows(3/4) outcomemap("Outcome 1") keyed ///
        smallcells(5) frame(_cs_t13, replace)
    assert r(N_primary_suppressed) == 2 & r(N_secondary_suppressed) == 2
    frame _cs_t13: assert c2[5] == "23"
}
if _rc == 0 {
    display as result "  PASS: T13 a total the engine must mask but another section sums to is error 459 (8/0/0 and 5/3/0); primary runs; an unmasked shared total is fine"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 cross-section total (rc=`=_rc')"
    local ++fail_count
}

**# T14: vertical mode masks custom and paired count statistic rows
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    * N 6, rank 2, df_r 4
    quietly collect: regress price mpg in 1/6
    quietly regtab, frame(_cs_w, replace) noint stats(e(N|rank) e(df_r)="Residual df" n)
    frame _cs_w: local nr = _N
    local row_pair 0
    local row_df 0
    local row_obs 0
    local row_est 0
    frame _cs_w {
        forvalues i = 1/`nr' {
            local a = strtrim(A[`i'])
            if "`a'" == "N (rank)" local row_pair `i'
            if "`a'" == "Residual df" local row_df `i'
            if "`a'" == "Observations" local row_obs `i'
            if "`a'" == "Mileage (mpg)" local row_est `i'
        }
    }
    assert `row_pair' > 0 & `row_df' > 0 & `row_obs' > 0 & `row_est' > 0
    frame _cs_w: assert c1[`row_pair'] == "6 (2)" & c1[`row_df'] == "4" & c1[`row_obs'] == "6"
    * data rows are numbered after the 3 header rows
    local d1 = `row_est' - 3
    local d2 = `nr' - 3
    quietly comptab _cs_w, rows(`d1'/`d2') frame(_cs_w0, replace)
    local k "$CS_OUT/cs_t14.log"
    capture erase "`k'"
    log using "`k'", text name(_cs14) replace
    comptab _cs_w, rows(`d1'/`d2') smallcells(5) frame(_cs_w5, replace)
    local np = r(N_primary_suppressed)
    log close _cs14
    assert `np' == 2
    local seen 0
    frame _cs_w5 {
        forvalues i = 1/`=_N' {
            local a = strtrim(A[`i'])
            if "`a'" == "N (rank)" {
                assert c1[`i'] == "6 (<5)"
                local ++seen
            }
            if "`a'" == "Residual df" {
                assert c1[`i'] == "<5"
                local ++seen
            }
            if "`a'" == "Observations" {
                assert c1[`i'] == "6"
                local ++seen
            }
        }
    }
    assert `seen' == 3
    * estimates untouched
    _cs_same _cs_w5 _cs_w0 "c2 c3"
    frame _cs_w0: local e = c1[4]
    frame _cs_w5: assert c1[4] == "`e'"
    * the note names the custom rows
    _cs_count "`k'" "whole numbers in row"
    assert r(found)
    _cs_count "`k'" `"N (rank)"'
    assert r(found)
    quietly comptab _cs_w, rows(`d1'/`d2') smallcells(8) frame(_cs_w8, replace)
    assert r(N_primary_suppressed) == 4
    frame _cs_w8 {
        forvalues i = 1/`=_N' {
            local a = strtrim(A[`i'])
            if "`a'" == "N (rank)" assert c1[`i'] == "<8 (<8)"
            if "`a'" == "Observations" assert c1[`i'] == "<8"
        }
    }
    quietly comptab _cs_w, rows(`d1'/`d2') nosmallcells frame(_cs_wn, replace)
    _cs_same _cs_wn _cs_w0 "A c1 c2 c3"
}
if _rc == 0 {
    display as result "  PASS: T14 vertical: e(N|rank) 6 (2) -> 6 (<5), e(df_r)=Residual df 4 -> <5, Observations 6 kept; note names custom rows; estimates untouched"
    local ++pass_count
}
else {
    local rc = _rc
    capture log close _cs14
    display as error "  FAIL: T14 vertical custom count rows (rc=`rc')"
    local ++fail_count
}

**# Cleanup
quietly tabtools set clear
foreach f in _csb1 _csb2 _csd1 _csd2 _cso1 {
    capture erase "$CS_OUT/`f'.dta"
}
local _f : dir "$CS_OUT" files "_cs_facts_*.txt"
foreach f of local _f {
    capture erase "$CS_OUT/`f'"
}
foreach f in cs_t1_strate.xlsx cs_t1_comp.xlsx cs_t4.xlsx cs_t4.csv cs_t4.md cs_t4.tex cs_t4_console.log cs_t6.log cs_t7.log cs_t9_c.csv cs_t9_h.csv cs_t14.log {
    capture erase "$CS_OUT/`f'"
}

local _tc = `pass_count' + `fail_count'
assert `_tc' == `test_count'
display "RESULT: test_comptab_smallcells tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _cs
if `fail_count' > 0 exit 1

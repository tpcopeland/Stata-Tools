* test_cycle_20261119_comptab.do - comptab forest when smallcells() withholds
* every effect (review cycle 2026-11-19, finding F1)
*
* Contract: in rate mode, forest with no effect row left to draw is the
* clean r(2000) "forest requires an eplotframe with effect rows", also when
* smallcells() withholds every effect, and it is raised before the table is
* printed or any file or frame is written. One surviving effect still plots.
*
* Oracle: the raw event counts typed into the strate fixtures. Effects and
* the counts that withhold them (row count, section reference count):
*   outcome 1: Current (4; ref 12), Low (5; ref 10), High (0; ref 10)
*   outcome 2: Current (20; ref 3), Low (1; ref 8), High (9; ref 8)
* smallcells(10) masks 1..9: only High of outcome 1 survives.
* smallcells(11) masks 1..10: every effect is withheld.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _cy
log using "test_cycle_20261119_comptab.log", replace text name(_cy)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local repo_dir = regexr("`pkg_dir'", "/tabtools$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global CS_OUT "`output_dir'"

capture confirm file "`repo_dir'/eplot/eplot.ado"
if _rc {
    display as error "Sibling eplot package not found at `repo_dir'/eplot (required for the forest tests)"
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

**# Helpers

* r(found)=1 when text file <file> contains <needle> on some line
capture program drop _cy_grep
program define _cy_grep, rclass
    version 17.0
    args file needle
    tempname h
    local found 0
    file open `h' using "`file'", read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`needle'"') local found 1
        file read `h' line
    }
    file close `h'
    return scalar found = `found'
end

* run one comptab call under a private text log; r(rc) and the log path
capture program drop _cy_run
program define _cy_run, rclass
    version 17.0
    gettoken logf 0 : 0
    capture erase "`logf'"
    capture log close _cyl
    quietly log using "`logf'", text replace name(_cyl)
    capture noisily comptab `0'
    local rc = _rc
    quietly log close _cyl
    return scalar rc = `rc'
end

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

global CY_CMP `"_cs_rf0, modelframes(_cs_mb _cs_md) rows(3 \ 3/4) outcomemap("Outcome 1" \ "Outcome 2")"'

**# T1: every effect withheld: clean r(2000) before anything is printed or written
local ++test_count
capture noisily {
    _cs_fixture
    local csv "$CS_OUT/cy_t1.csv"
    local md "$CS_OUT/cy_t1.md"
    local lg "$CS_OUT/cy_t1_log.txt"
    capture erase "`csv'"
    capture erase "`md'"
    capture graph drop _cy_g1
    * a caller frame that must survive the failed call unchanged
    capture frame drop _cy_v1
    frame create _cy_v1 str8 sentinel
    frame _cy_v1: set obs 1
    frame _cy_v1: replace sentinel = "keep"
    capture frame drop _cy_e1
    _cy_run "`lg'" $CY_CMP smallcells(11) forest ///
        eplotoptions(name(_cy_g1, replace)) frame(_cy_v1, replace) ///
        eplotframe(_cy_e1, replace) csv("`csv'") markdown("`md'")
    assert r(rc) == 2000
    _cy_grep "`lg'" "forest requires an eplotframe with effect rows"
    assert r(found) == 1
    _cy_grep "`lg'" "smallcells() withholds every effect estimate"
    assert r(found) == 1
    * eplot never ran
    _cy_grep "`lg'" "no valid confidence intervals"
    assert r(found) == 0
    * the table was not printed (its masked count cells read <11)
    _cy_grep "`lg'" "<11"
    assert r(found) == 0
    capture confirm file "`csv'"
    assert _rc == 601
    capture confirm file "`md'"
    assert _rc == 601
    capture graph describe _cy_g1
    assert _rc != 0
    frame _cy_v1 {
        confirm variable sentinel
        assert _N == 1 & sentinel[1] == "keep"
        capture confirm variable c1
        assert _rc != 0
    }
    capture confirm frame _cy_e1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T1 all effects withheld: r(2000) with forest message; nothing printed, written or committed"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 all effects withheld (rc=`=_rc')"
    local ++fail_count
}

**# T2: the same composite without forest prints and writes every masked cell
local ++test_count
capture noisily {
    _cs_fixture
    local csv "$CS_OUT/cy_t2.csv"
    local lg "$CS_OUT/cy_t2_log.txt"
    capture erase "`csv'"
    _cy_run "`lg'" $CY_CMP smallcells(11) frame(_cy_v2, replace) csv("`csv'")
    assert r(rc) == 0
    _cy_grep "`lg'" "<11"
    assert r(found) == 1
    confirm file "`csv'"
    _cy_grep "`csv'" "<11"
    assert r(found) == 1
    * every effect cell of the display frame is withheld: the label is c1,
    * and the effect column of each non-reference category row reads "–"
    * for outcome 1 (c5) and outcome 2 (c10)
    frame _cy_v2 {
        local n_eff 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(c1[`i'])
            if inlist("`lab'", "Current", "Low", "High") {
                assert strtrim(c5) == "–" in `i'
                assert strtrim(c10) == "–" in `i'
                local ++n_eff
            }
        }
        assert `n_eff' == 3
    }
}
if _rc == 0 {
    display as result "  PASS: T2 smallcells(11) without forest prints, writes and commits the masked table"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 smallcells(11) without forest (rc=`=_rc')"
    local ++fail_count
}

**# T3: boundary: one surviving effect (smallcells(10)) still plots and commits
local ++test_count
capture noisily {
    _cs_fixture
    local csv "$CS_OUT/cy_t3.csv"
    local lg "$CS_OUT/cy_t3_log.txt"
    capture erase "`csv'"
    capture graph drop _cy_g3
    _cy_run "`lg'" $CY_CMP smallcells(10) forest ///
        eplotoptions(name(_cy_g3, replace)) frame(_cy_v3, replace) ///
        eplotframe(_cy_e3, replace) csv("`csv'")
    assert r(rc) == 0
    _cy_grep "`lg'" "forest requires"
    assert r(found) == 0
    confirm file "`csv'"
    graph describe _cy_g3
    confirm frame _cy_v3
    * eplotframe() keeps all 6 numbers although 5 are withheld from the plot
    frame _cy_e3: count if rowtype == "effect" & !missing(estimate)
    assert r(N) == 6
    capture graph drop _cy_g3
}
if _rc == 0 {
    display as result "  PASS: T3 smallcells(10): one surviving effect plots; frame() and csv committed"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 one surviving effect (rc=`=_rc')"
    local ++fail_count
}

**# T4: unmasked forest of the same composite is unaffected
local ++test_count
capture noisily {
    _cs_fixture
    local lg "$CS_OUT/cy_t4_log.txt"
    capture graph drop _cy_g4
    _cy_run "`lg'" $CY_CMP forest eplotoptions(name(_cy_g4, replace)) frame(_cy_v4, replace)
    assert r(rc) == 0
    graph describe _cy_g4
    confirm frame _cy_v4
    capture graph drop _cy_g4
}
if _rc == 0 {
    display as result "  PASS: T4 unmasked forest unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 unmasked forest (rc=`=_rc')"
    local ++fail_count
}

capture frame drop _cy_v1
capture frame drop _cy_v2
capture frame drop _cy_v3
capture frame drop _cy_v4
capture frame drop _cy_e3

display as result "test_cycle_20261119_comptab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_comptab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _cy

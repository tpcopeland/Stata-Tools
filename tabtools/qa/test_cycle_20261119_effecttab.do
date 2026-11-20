* test_cycle_20261119_effecttab.do - effecttab regressions (review cycle
* 2026-11-19, unit effecttab)
*
*   F1  from(<missing matrix>) is refused with r(111) and a plain message;
*       c(varabbrev) is restored (the bad call left it off, rc 199).
*   F2  r(table) row names are cut to 32 bytes on a character boundary: a
*       non-ASCII label never yields an invalid UTF-8 name, and the _2 suffix
*       of a repeated name keeps whole characters too.
*   F3  boldp() and highlight() test the numeric p-value, not its display
*       text: p = .0496 shown 0.050 is styled under .05, a p shown <0.001 is
*       styled only when it is below the threshold. Read back with openpyxl.
*   F4  models() naming more models than the table holds is r(198) before
*       anything is written (was r(111) "variable c4 not found").
*   F5  effect() and models() text with double quotes or a backtick is shown
*       as typed in the header (was cut at the first quote at rc 0).
* Oracles: the typed labels and matrix inputs, Stata's own teffects r(table),
* and workbooks read back by qa/tools/xlsx_facts.py / xlsx_style_facts.py.

clear all
set more off
set varabbrev off
version 17.0

capture log close _c19et
log using "test_cycle_20261119_effecttab.log", replace text name(_c19et)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global C19ET_TOOLS "`qa_dir'/tools"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

* Facts of one worksheet (bold cells, fills, values) in one file, one per line
capture program drop _c19et_facts
program define _c19et_facts
    version 17.0
    args book sheet out
    capture erase `"`out'.a"'
    capture erase `"`out'.b"'
    quietly shell python3 "$C19ET_TOOLS/xlsx_facts.py" "`book'" "`sheet'" "`out'.a"
    quietly shell python3 "$C19ET_TOOLS/xlsx_style_facts.py" "`book'" "`sheet'" "`out'.b"
    confirm file `"`out'.a"'
    confirm file `"`out'.b"'
end

* r(found) = 1 when the facts file holds the exact line
capture program drop _c19et_has
program define _c19et_has, rclass
    version 17.0
    gettoken out 0 : 0
    gettoken needle 0 : 0
    local found 0
    tempname h
    foreach sfx in a b {
        file open `h' using `"`out'.`sfx'"', read text
        file read `h' line
        while r(eof) == 0 {
            if `"`macval(line)'"' == `"`macval(needle)'"' local found 1
            file read `h' line
        }
        file close `h'
    }
    return scalar found = `found'
end

* One-model teffects collection with p = .0325 for its ATE
capture program drop _c19et_te
program define _c19et_te
    version 17.0
    clear
    set seed 123
    set obs 600
    gen age = rnormal(50, 10)
    gen treat = runiform() < invlogit((age - 50) / 10)
    gen y = 0.12 * treat + 0.05 * age + rnormal()
    collect clear
    quietly collect: teffects ipw (y) (treat age, logit), ate
end

**# F1 from() with a missing matrix

**## r(111), message, varabbrev restored from on and from off
local ++test_count
capture noisily {
    clear
    matrix drop _all
    matrix E = (1, .5, 1.5, .04 \ 2, 1, 3, .02)
    set varabbrev on
    capture noisily effecttab, from(nosuch)
    local rc1 = _rc
    local va1 = c(varabbrev)
    set varabbrev off
    capture noisily effecttab, from(nosuch)
    local rc2 = _rc
    local va2 = c(varabbrev)
    assert `rc1' == 111
    assert "`va1'" == "on"
    assert `rc2' == 111
    assert "`va2'" == "off"
    * the existing matrix still works after the refused call
    effecttab, from(E)
    assert rowsof(r(table)) == 2
}
if _rc == 0 {
    display as result "  PASS: F1 from(nosuch) is r(111) and restores varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 from(nosuch) is r(111) and restores varabbrev (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

**# F2 r(table) row names cut on a character boundary

**## tlabels() with a long non-ASCII label
local ++test_count
capture noisily {
    clear
    matrix drop _all
    set seed 5
    set obs 900
    gen age = rnormal(50, 10)
    gen t3 = floor(runiform() * 3)
    gen y3 = t3 + rnormal()
    collect clear
    quietly collect: teffects ra (y3 age) (t3), ate
    local lab2 "Ünïcode ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓"
    effecttab, tlabels(0 "Ref" 1 "T1" 2 "`lab2'") frame(c19f2, replace)
    tempname M
    matrix `M' = r(table)
    local rn : rownames `M'
    local bad 0
    foreach r of local rn {
        if ustrinvalidcnt("`r'") > 0 | strlen("`r'") > 32 local bad 1
    }
    assert `bad' == 0
    * expected name: spaces to _, then the longest whole-character prefix
    * within 32 bytes ("Ünïcode_" is 10 bytes, each check mark 3): 7 marks
    local want "Ünïcode_✓✓✓✓✓✓✓"
    assert strlen("`want'") == 31
    assert rownumb(`M', "`want'") < .
    * the displayed label is the full text
    frame c19f2: count if A == "`lab2' vs Ref"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: F2 non-ASCII row name is valid UTF-8 within 32 bytes"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 non-ASCII row name is valid UTF-8 within 32 bytes (rc=`=_rc')"
    local ++fail_count
}

**## Repeated truncated multibyte names keep whole characters in the _2 suffix
local ++test_count
capture noisily {
    clear
    matrix drop _all
    matrix E = (1, .5, 1.5, .04 \ 2, 1, 3, .02)
    matrix rownames E = "aÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄx" "aÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄy"
    effecttab, from(E)
    tempname M
    matrix `M' = r(table)
    local rn : rownames `M'
    local r1 : word 1 of `rn'
    local r2 : word 2 of `rn'
    * 1 + 2k bytes: a byte cut at 32 (or 30 for _2) splits an Ä
    assert "`r1'" == "aÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ"
    assert "`r2'" == "aÄÄÄÄÄÄÄÄÄÄÄÄÄÄ_2"
    assert ustrinvalidcnt("`r1'") == 0 & ustrinvalidcnt("`r2'") == 0
    assert strlen("`r1'") <= 32 & strlen("`r2'") <= 32
    assert `M'[2, 1] == 2
}
if _rc == 0 {
    display as result "  PASS: F2 repeated multibyte names stay valid and distinct"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 repeated multibyte names stay valid and distinct (rc=`=_rc')"
    local ++fail_count
}

**# F3 boldp() and highlight() use the numeric p-value

**## from(): .0496 shown 0.050 is styled under .05; .0504 is not
local ++test_count
capture noisily {
    clear
    matrix drop _all
    matrix E = (1, .5, 1.5, .0496 \ 2, 1, 3, .0504 \ 3, 2, 4, .0004 \ 4, 1, 5, .0004999)
    matrix rownames E = a b c d
    local book "`output_dir'/c19et_f3a.xlsx"
    capture erase "`book'"
    effecttab, from(E) xlsx("`book'") boldp(0.05) highlight(0.05) sheet(S) pdp(3)
    local facts "`output_dir'/c19et_f3a"
    _c19et_facts "`book'" S "`facts'"
    * the display text is the same for a and b
    _c19et_has "`facts'" "value E4 0.050"
    assert r(found) == 1
    _c19et_has "`facts'" "value E5 0.050"
    assert r(found) == 1
    * a (p = .0496): bold and filled
    _c19et_has "`facts'" "bold E4"
    assert r(found) == 1
    _c19et_has "`facts'" "fill E4 FFFFFFCC"
    assert r(found) == 1
    * b (p = .0504): neither
    _c19et_has "`facts'" "bold E5"
    assert r(found) == 0
    _c19et_has "`facts'" "fill E5 FFFFFFCC"
    assert r(found) == 0
    _c19et_has "`facts'" "fill B5 FFFFFFCC"
    assert r(found) == 0
    * c, d (< .001): both
    _c19et_has "`facts'" "bold E6"
    assert r(found) == 1
    _c19et_has "`facts'" "bold E7"
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: F3 p = .0496 shown 0.050 is styled, .0504 is not"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 p = .0496 shown 0.050 is styled, .0504 is not (rc=`=_rc')"
    local ++fail_count
}

**## from(): a p shown <0.001 is styled only below the threshold
local ++test_count
capture noisily {
    clear
    matrix drop _all
    matrix E = (3, 2, 4, .0004 \ 4, 1, 5, .0004999 \ 5, 4, 6, .00005)
    matrix rownames E = c d e
    local book "`output_dir'/c19et_f3b.xlsx"
    capture erase "`book'"
    effecttab, from(E) xlsx("`book'") boldp(0.0001) highlight(0.0001) sheet(S) pdp(3)
    local facts "`output_dir'/c19et_f3b"
    _c19et_facts "`book'" S "`facts'"
    forvalues r = 4/6 {
        _c19et_has "`facts'" "value E`r' <0.001"
        assert r(found) == 1
    }
    _c19et_has "`facts'" "bold E4"
    assert r(found) == 0
    _c19et_has "`facts'" "bold E5"
    assert r(found) == 0
    _c19et_has "`facts'" "fill E4 FFFFFFCC"
    assert r(found) == 0
    _c19et_has "`facts'" "fill E5 FFFFFFCC"
    assert r(found) == 0
    _c19et_has "`facts'" "bold E6"
    assert r(found) == 1
    _c19et_has "`facts'" "fill E6 FFFFFFCC"
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: F3 <0.001 rows styled only when p < boldp()/highlight()"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 <0.001 rows styled only when p < boldp()/highlight() (rc=`=_rc')"
    local ++fail_count
}

**## collect path: a threshold between the shown and the true p decides
local ++test_count
capture noisily {
    _c19et_te
    tempname T
    matrix `T' = r(table)
    local p = `T'[4, 1]
    * the shown p (3 decimals) is below the true p, so a threshold just under
    * the true p separates the two readings
    assert real(string(`p', "%5.3f")) < `p'
    assert `p' > .001 & `p' < .1
    local below = `p' * (1 - 1e-6)
    local above = `p' * (1 + 1e-6)
    local book "`output_dir'/c19et_f3c.xlsx"
    capture erase "`book'"
    effecttab, xlsx("`book'") sheet(Lo) boldp(`below') highlight(`below')
    effecttab, xlsx("`book'") sheet(Hi) boldp(`above') highlight(`above')
    local facts "`output_dir'/c19et_f3c"
    _c19et_facts "`book'" Lo "`facts'_lo"
    _c19et_facts "`book'" Hi "`facts'_hi"
    _c19et_has "`facts'_lo" "value B4 r1vs0.treat"
    assert r(found) == 1
    _c19et_has "`facts'_lo" "value E4 `=string(`p', "%5.3f")'"
    assert r(found) == 1
    _c19et_has "`facts'_lo" "bold E4"
    assert r(found) == 0
    _c19et_has "`facts'_lo" "fill E4 FFFFFFCC"
    assert r(found) == 0
    _c19et_has "`facts'_hi" "bold E4"
    assert r(found) == 1
    _c19et_has "`facts'_hi" "fill E4 FFFFFFCC"
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: F3 collect path styles by the numeric p"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 collect path styles by the numeric p (rc=`=_rc')"
    local ++fail_count
}

**## addrow() rows below a styled table are never styled
local ++test_count
capture noisily {
    clear
    matrix drop _all
    matrix E = (1, .5, 1.5, .01)
    matrix rownames E = a
    local book "`output_dir'/c19et_f3d.xlsx"
    capture erase "`book'"
    effecttab, from(E) xlsx("`book'") sheet(S) boldp(0.05) highlight(0.05) addrow(N 100)
    local facts "`output_dir'/c19et_f3d"
    _c19et_facts "`book'" S "`facts'"
    _c19et_has "`facts'" "bold E4"
    assert r(found) == 1
    _c19et_has "`facts'" "value B5 N"
    assert r(found) == 1
    _c19et_has "`facts'" "fill B5 FFFFFFCC"
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: F3 addrow() rows keep no p-value styling"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 addrow() rows keep no p-value styling (rc=`=_rc')"
    local ++fail_count
}

**# F4 models() with more names than models

**## collect and from() paths: r(198), nothing written, varabbrev restored
local ++test_count
capture noisily {
    _c19et_te
    local book "`output_dir'/c19et_f4.xlsx"
    capture erase "`book'"
    set varabbrev on
    capture noisily effecttab, models("A \ B \ C") effect(ATE) xlsx("`book'") sheet(S)
    local rc1 = _rc
    local va1 = c(varabbrev)
    set varabbrev off
    assert `rc1' == 198
    assert "`va1'" == "on"
    capture confirm file "`book'"
    assert _rc == 601
    matrix E = (1, .5, 1.5, .04)
    capture noisily effecttab, from(E) models("A \ B")
    assert _rc == 198
    * a matching count still labels the model
    effecttab, models("A") effect(ATE) frame(c19f4, replace, flat)
    frame c19f4: local l : variable label c1
    assert `"`l'"' == "A, ATE"
}
if _rc == 0 {
    display as result "  PASS: F4 too many models() names is r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 too many models() names is r(198) (rc=`=_rc')"
    local ++fail_count
}
set varabbrev off

**# F5 effect() and models() text shown as typed

**## double quotes, collect path: frame label, r(effect_label), Excel header
local ++test_count
capture noisily {
    _c19et_te
    local book "`output_dir'/c19et_f5.xlsx"
    capture erase "`book'"
    effecttab, models(`"My "quoted" mdl"') effect(`"Eff "x" y"') ///
        frame(c19f5, replace, flat) xlsx("`book'") sheet(S)
    assert `"`r(effect_label)'"' == `"Eff "x" y"'
    frame c19f5: local l : variable label c1
    assert `"`l'"' == `"My "quoted" mdl, Eff "x" y"'
    local facts "`output_dir'/c19et_f5"
    _c19et_facts "`book'" S "`facts'"
    _c19et_has "`facts'" `"value C2 My "quoted" mdl"'
    assert r(found) == 1
    _c19et_has "`facts'" `"value C3 Eff "x" y"'
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: F5 quoted effect()/models() text kept whole"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 quoted effect()/models() text kept whole (rc=`=_rc')"
    local ++fail_count
}

**## backtick in effect() and models()
local ++test_count
capture noisily {
    _c19et_te
    local bt = char(96)
    effecttab, models("Back`bt'tick") effect("E`bt'x") frame(c19f5b, replace, flat)
    frame c19f5b: local l : variable label c1
    assert `"`macval(l)'"' == "Back" + char(96) + "tick, E" + char(96) + "x"
}
if _rc == 0 {
    display as result "  PASS: F5 backtick in effect()/models() kept"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 backtick in effect()/models() kept (rc=`=_rc')"
    local ++fail_count
}

**## two models and the from() path keep the plain headers
local ++test_count
capture noisily {
    _c19et_te
    quietly collect: teffects ra (y age) (treat), ate
    effecttab, models("IPW \ RA") effect(ATE) frame(c19f5c, replace, flat)
    frame c19f5c {
        local l1 : variable label c1
        local l4 : variable label c4
        local l6 : variable label c6
    }
    assert `"`l1'"' == "IPW, ATE"
    assert `"`l4'"' == "RA, ATE"
    assert `"`l6'"' == "RA, p-value"
    matrix E = (1, .5, 1.5, .04)
    effecttab, from(E) effect(`"R "r""') frame(c19f5d, replace, flat)
    frame c19f5d: local l : variable label c1
    assert `"`l'"' == `"R "r""'
    assert `"`r(effect_label)'"' == `"R "r""'
}
if _rc == 0 {
    display as result "  PASS: F5 multi-model and from() headers"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 multi-model and from() headers (rc=`=_rc')"
    local ++fail_count
}

* Summary
display as result "test_cycle_20261119_effecttab: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_effecttab tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _c19et
if `fail_count' > 0 exit 1

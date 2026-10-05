* test_puttab_v250.do - puttab: the Markdown header under noheader with
* panel() rows, and blockheader (model names over a regtab flat frame)
*
* Oracles: expected cells, merges and rules are written out from the option
* contract and read back from the workbook with openpyxl
* (tools/xlsx_facts.py), never through the xl() writer under test; CSV and
* Markdown are read line by line with Mata cat(). The block names come from
* the frame's own characteristics, set by regtab or by hand, and the joined
* Markdown header is checked against char c#[tabtools_header], which regtab
* writes by a different route (_tabtools_flatframe) than puttab's span fold.

clear all
set more off
set varabbrev off
version 17.0

capture log close _pt250
log using "test_puttab_v250.log", replace text name(_pt250)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/pt250_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"
do "`qa_dir'/_qa_state.do"

* Fixture (as in test_puttab_v240.do): two panels with per-panel headers.
clear
input str20 lab str8(a b c) byte blk str10(h1 h2 h3 h4)
"Age <55" "1" "2" "3" 1 "" "Events" "PY" "Rate"
"Age 55+" "4" "5" "6" 1 "" "Events" "PY" "Rate"
"Repleted" "7" "8" "9" 2 "" "Scans" "Pct" "RR"
end
label define blk 1 "A. Relapses" 2 "B. MRI", replace
label values blk blk
label variable lab "Row"
label variable a "Col A"
label variable b "Col B"
label variable c "Col C"
tempfile pt250_fixture
quietly save "`pt250_fixture'"
global PT250_FIX "`pt250_fixture'"
capture program drop _pt250_data
program define _pt250_data
    quietly use "$PT250_FIX", clear
end

* Line `n' of text file `file' is exactly `text'.
capture program drop _pt250_lineat
program define _pt250_lineat
    version 17.0
    gettoken file 0 : 0
    gettoken n 0 : 0
    gettoken text 0 : 0
    mata: _l = cat(st_local("file")); st_local("_ok", strofreal(rows(_l) >= `n'))
    if `_ok' mata: st_local("_got", _l[`n'])
    if !`_ok' {
        display as error "`file' has fewer than `n' lines"
        exit 9
    }
    mata: st_local("_eq", strofreal(st_local("_got") == st_local("text")))
    if !`_eq' {
        display as error `"line `n' of `file' is "`macval(_got)'", expected "`macval(text)'""'
        exit 9
    }
end

* A two-model regtab flat frame named `1' with model names `2' and `3'.
capture program drop _pt250_models
program define _pt250_models
    version 17.0
    args fr m1 m2
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    quietly collect: logit foreign mpg weight
    quietly regtab, frame(`fr', replace flat) models("`m1'" \ "`m2'")
end

**# B1: noheader panelinline: Markdown takes the shared row as its header
* 2.4.0 wrote an empty "|  |  |  |  |" header and the first shared row as a
* bold body row under it. The workbook and the CSV never had an empty header
* row; they are pinned here so the fix cannot move one there.
local ++test_count
capture noisily {
    local book "`output_dir'/pt250_b1.xlsx"
    local csv "`output_dir'/pt250_b1.csv"
    local md "`output_dir'/pt250_b1.md"
    capture erase "`book'"
    _pt250_data
    puttab lab a b c using "`book'", sheet("B1") panel(blk) ///
        panelheader(h1 h2 h3 h4) panelinline noheader csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 5 & r(n_panels) == 2
    * the promoted row is the header, so four body rows remain
    assert r(markdown_rows) == 4
    _pt250_lineat "`md'" 1 "| A. Relapses | Events | PY | Rate |"
    _pt250_lineat "`md'" 2 "| --- | --- | --- | --- |"
    _pt250_lineat "`md'" 3 "| &nbsp;&nbsp;&nbsp;Age \<55 | 1 | 2 | 3 |"
    _v_line "`md'" "|  |  |  |  |" 0
    _v_line "`md'" "| **A. Relapses** | **Events** | **PY** | **Rate** |" 0
    * a later shared row stays a bold body row
    _v_line "`md'" "| **B. MRI** | **Scans** | **Pct** | **RR** |" 1
    * CSV: the shared row is the first line; no empty header line
    _pt250_lineat "`csv'" 1 "A. Relapses,Events,PY,Rate"
    _v_line "`csv'" ",,," 0
    * workbook: reserved title row 1, the shared row at once in row 2
    _v_facts "`book'" "B1"
    _v_value B2 "A. Relapses"
    _v_value E2 "Rate"
    _v_value B3 "   Age <55"
    _v_has top thin "B2 C2 D2 E2"
    _v_has bottom thin "B2 C2 D2 E2"
    _v_none value "B1 C1 D1 E1"
    * with title(): the heading, a blank line, then the promoted header
    local md2 "`output_dir'/pt250_b1t.md"
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) panelinline ///
        noheader markdown("`md2'") title("Table 3")
    _pt250_lineat "`md2'" 1 "### Table 3"
    _pt250_lineat "`md2'" 2 ""
    _pt250_lineat "`md2'" 3 "| A. Relapses | Events | PY | Rate |"
    _pt250_lineat "`md2'" 4 "| --- | --- | --- | --- |"
    assert r(markdown_rows) == 4
}
if _rc == 0 {
    display as result "  PASS: B1 noheader panelinline: shared row is the Markdown header"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 noheader panelinline Markdown header (rc=`=_rc')"
    local ++fail_count
}

**# B2: the other panel layouts, mdappend, and data never promoted
local ++test_count
capture noisily {
    * heading row then its own header row: the heading takes the slot
    local md "`output_dir'/pt250_b2.md"
    _pt250_data
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) noheader markdown("`md'")
    _pt250_lineat "`md'" 1 "| A. Relapses |  |  |  |"
    _pt250_lineat "`md'" 3 "|  | **Events** | **PY** | **Rate** |"
    assert r(markdown_rows) == 6
    * panel() alone
    puttab lab a b c, panel(blk) noheader markdown("`md'")
    _pt250_lineat "`md'" 1 "| A. Relapses |  |  |  |"
    _pt250_lineat "`md'" 3 "| &nbsp;&nbsp;&nbsp;Age \<55 | 1 | 2 | 3 |"
    _v_line "`md'" "| **B. MRI** |  |  |  |" 1
    * mdappend: each appended table starts with its own promoted header
    capture erase "`md'"
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) panelinline ///
        noheader markdown("`md'")
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) panelinline ///
        noheader markdown("`md'") mdappend
    _v_line "`md'" "| A. Relapses | Events | PY | Rate |" 2
    _v_line "`md'" "|  |  |  |  |" 0
    * no panel: the header stays blank and the first data row is a body row
    puttab lab a b c, noheader markdown("`md'")
    _pt250_lineat "`md'" 1 "|  |  |  |  |"
    _pt250_lineat "`md'" 3 "| Age \<55 | 1 | 2 | 3 |"
    assert r(markdown_rows) == 3
    * a first panel without a heading (missing value): its first row is data,
    * so it is not promoted either
    _pt250_data
    replace blk = . in 1
    puttab lab a b c, panel(blk) noheader markdown("`md'")
    _pt250_lineat "`md'" 1 "|  |  |  |  |"
    _pt250_lineat "`md'" 3 "| Age \<55 | 1 | 2 | 3 |"
    * with a header row nothing changes: the header is the labels
    _pt250_data
    puttab lab a b c, panel(blk) varlabels markdown("`md'")
    _pt250_lineat "`md'" 1 "| Row | Col A | Col B | Col C |"
}
if _rc == 0 {
    display as result "  PASS: B2 heading/header layouts, mdappend, data never promoted"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 noheader panel layouts (rc=`=_rc')"
    local ++fail_count
}

**# K1: blockheader writes the model names over the statistic labels
local ++test_count
capture noisily {
    local book "`output_dir'/pt250_k1.xlsx"
    local csv "`output_dir'/pt250_k1.csv"
    local md "`output_dir'/pt250_k1.md"
    capture erase "`book'"
    _pt250_models _pt250m "Crude" "Adjusted"
    frame _pt250m {
        * the frame's own record of each column: label, block, full header
        forvalues j = 1/6 {
            local L`j' : variable label c`j'
            mata: st_local("H`j'", st_global("c`j'[tabtools_header]"))
        }
        assert `"`: char c1[tabtools_block]'"' == "Crude"
        assert `"`: char c4[tabtools_block]'"' == "Adjusted"
        puttab rowlabel c* using "`book'", sheet("K1") blockheader ///
            csv("`csv'") markdown("`md'")
        assert r(n_spans) == 2
        local nrows = r(n_rows)
        local ndat = r(n_datarows)
        assert `ndat' == _N
        * one span row above the header: N data rows + span + header
        assert `nrows' == _N + 2
    }
    _v_facts "`book'" "K1"
    _v_value C2 "Crude"
    _v_value F2 "Adjusted"
    _v_empty B2
    _v_none value "D2 E2 G2 H2"
    _v_has merge "" "C2:E2 F2:H2"
    _v_none merge "C2:H2"
    _v_has bold "" "C2 F2"
    _v_has bottom thin "C2 F2"
    forvalues j = 1/6 {
        local col : word `j' of C D E F G H
        _v_value `col'3 "`L`j''"
    }
    * CSV: the name row with each name in its block's first column
    _pt250_lineat "`csv'" 1 ",Crude,,,Adjusted,,"
    * Markdown: one header row, "model, statistic" = char tabtools_header
    local want "|  |"
    forvalues j = 1/6 {
        local want `"`want' `H`j'' |"'
    }
    _pt250_lineat "`md'" 1 `"`want'"'
    assert "`H1'" == "Crude, `L1'" & "`H6'" == "Adjusted, `L6'"
}
if _rc == 0 {
    display as result "  PASS: K1 blockheader: names merged over each model, every sink"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 blockheader (rc=`=_rc')"
    local ++fail_count
}

**# K2: blocks are grouped by identity, never by equal names
local ++test_count
capture noisily {
    local book "`output_dir'/pt250_k2.xlsx"
    capture erase "`book'"
    _pt250_models _pt250s "Same" "Same"
    frame _pt250s {
        assert `"`: char c1[tabtools_block_id]'"' != `"`: char c4[tabtools_block_id]'"'
        assert `"`: char c1[tabtools_block_id]'"' == `"`: char c3[tabtools_block_id]'"'
        puttab rowlabel c* using "`book'", sheet("K2") blockheader
        assert r(n_spans) == 2
    }
    _v_facts "`book'" "K2"
    _v_has merge "" "C2:E2 F2:H2"
    _v_none merge "C2:H2"
    _v_value C2 "Same"
    _v_value F2 "Same"
    * columns reordered: the spans follow the exported order
    frame _pt250m {
        puttab rowlabel c4 c5 c6 c1 c2 c3 using "`book'", sheet("K2b") blockheader
        assert r(n_spans) == 2
    }
    _v_facts "`book'" "K2b"
    _v_value C2 "Adjusted"
    _v_value F2 "Crude"
    * a column the caller added (no characteristic) splits a block: it has a
    * blank cell, and the two parts of the block are spans of their own
    frame _pt250m {
        generate str8 extra = "x"
        label variable extra "Extra"
        puttab rowlabel c1 c2 extra c3 using "`book'", sheet("K2c") blockheader
        assert r(n_spans) == 2
        drop extra
    }
    _v_facts "`book'" "K2c"
    _v_has merge "" "C2:D2"
    _v_value C2 "Crude"
    _v_empty E2
    _v_value F2 "Crude"
    _v_value E3 "Extra"
    * no block identifier (a frame from before it existed): each named
    * column is a span of its own, never merged by name
    frame copy _pt250m _pt250n, replace
    frame _pt250n {
        forvalues j = 1/6 {
            char c`j'[tabtools_block_id]
        }
        puttab rowlabel c* using "`book'", sheet("K2d") blockheader
        assert r(n_spans) == 6
    }
    _v_facts "`book'" "K2d"
    _v_count merge
    * the reserved title row is the only merge
    assert r(n) == 1
    _v_value C2 "Crude"
    _v_value D2 "Crude"
    _v_value H2 "Adjusted"
    frame drop _pt250n
    frame drop _pt250s
}
if _rc == 0 {
    display as result "  PASS: K2 spans by block identity, export order, added columns"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 block identity (rc=`=_rc')"
    local ++fail_count
}

**# K3: no characteristic, transpose, frame() source with in
local ++test_count
capture noisily {
    local md "`output_dir'/pt250_k3.md"
    * plain data: a note, no row, the labels as the header
    _pt250_data
    puttab lab a b c, blockheader markdown("`md'")
    assert r(n_spans) == 0
    _pt250_lineat "`md'" 1 "| Row | Col A | Col B | Col C |"
    * a transposed flat frame keeps the term in each label: no block names
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    quietly collect: logit foreign mpg weight
    quietly regtab, frame(_pt250t, replace flat) transpose
    frame _pt250t {
        puttab rowlabel c*, blockheader markdown("`md'")
        assert r(n_spans) == 0
    }
    frame drop _pt250t
    * frame() source and in: the characteristics travel with the source
    clear
    puttab rowlabel c1 c2 c3 in 1/2, frame(_pt250m) blockheader ///
        csv("`output_dir'/pt250_k3.csv") markdown("`md'")
    assert r(n_spans) == 1 & r(n_datarows) == 2
    _pt250_lineat "`output_dir'/pt250_k3.csv" 1 ",Crude,,"
}
if _rc == 0 {
    display as result "  PASS: K3 fallbacks: no names, transpose, frame() source"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 blockheader fallbacks (rc=`=_rc')"
    local ++fail_count
}

**# K4: refusals
local ++test_count
capture noisily {
    local md "`output_dir'/pt250_k4.md"
    frame _pt250m {
        * control: the same call without the conflicting option succeeds, so
        * each 198 below is the conflict, not an unknown option
        puttab rowlabel c*, blockheader markdown("`md'")
        assert r(n_spans) == 2
        capture puttab rowlabel c*, blockheader noheader markdown("`md'")
        assert _rc == 198
        capture puttab rowlabel c*, blockheader spanheader("x" 2/3) markdown("`md'")
        assert _rc == 198
    }
    matrix M = (1, 2 \ 3, 4)
    capture puttab, matrix(M) blockheader markdown("`md'")
    assert _rc == 198
    * a mistyped option is still refused
    frame _pt250m {
        capture puttab rowlabel c*, blockheaders markdown("`md'")
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: K4 blockheader refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 refusals (rc=`=_rc')"
    local ++fail_count
}

**# K5: a block name is data: $name, backquote and quote print as typed
local ++test_count
capture noisily {
    local book "`output_dir'/pt250_k5.xlsx"
    local csv "`output_dir'/pt250_k5.csv"
    capture erase "`book'"
    global PT250_X "EXPANDED"
    frame copy _pt250m _pt250h, replace
    frame _pt250h {
        mata: _nm = "Arm " + char(36) + "PT250_X " + char(96) + "q" + char(39) + " " + char(34) + "z" + char(34)
        forvalues j = 1/3 {
            mata: st_global("c`j'[tabtools_block]", _nm)
        }
        puttab rowlabel c1 c2 c3 using "`book'", sheet("K5") blockheader csv("`csv'")
    }
    _v_facts "`book'" "K5"
    mata: _f = cat("$V230_RES"); st_local("ok", strofreal(sum(_f :== "value C2 " + _nm) == 1)); ///
        st_local("bad", strofreal(sum(strpos(_f, "EXPANDED") :> 0)))
    assert `ok' == 1 & `bad' == 0
    mata: _c = cat(st_local("csv")); st_local("bad2", strofreal(strpos(_c[1], "EXPANDED") > 0)); ///
        st_local("ok2", strofreal(strpos(_c[1], char(96) + "q" + char(39)) > 0))
    assert `bad2' == 0 & `ok2' == 1
    mata: mata drop _nm _f _c
    frame drop _pt250h
    macro drop PT250_X
}
if _rc == 0 {
    display as result "  PASS: K5 block names are data (byte-for-byte, no expansion)"
    local ++pass_count
}
else {
    display as error "  FAIL: K5 block name as data (rc=`=_rc')"
    local ++fail_count
}

**# K6: key columns (char <var>[tabtools_key] 1) are left out unless named
* The frame is built by hand with the layout regtab's frame(name, flat keys)
* produces: _order, _term, _rowtype and one _state# per model, each marked.
* Oracle: the same table without key columns, exported with rowlabel c*;
* every sink must be identical, byte for byte (the workbook through its
* openpyxl facts).
local ++test_count
capture noisily {
    frame copy _pt250m _pt250k, replace
    frame _pt250k {
        generate int _order = _n
        generate str32 _term = "t" + string(_n)
        generate str8 _rowtype = cond(strtrim(c1) == "", "header", "coef")
        generate str8 _state1 = "est"
        generate str8 _state2 = "est"
        foreach v in _order _term _rowtype _state1 _state2 {
            char `v'[tabtools_key] 1
        }
        order _order _term _rowtype rowlabel c1 c2 c3 _state1 c4 c5 c6 _state2
    }
    local ref "`output_dir'/pt250_k6ref"
    local key "`output_dir'/pt250_k6key"
    foreach f in ref key {
        capture erase "``f''.xlsx"
    }
    frame _pt250m: puttab rowlabel c* using "`ref'.xlsx", sheet("K") blockheader ///
        csv("`ref'.csv") markdown("`ref'.md")
    local refcols = r(n_cols)
    _v_facts "`ref'.xlsx" "K"
    copy "$V230_RES" "`ref'.facts", replace
    * no varlist: the keys are skipped in every sink, blockheader included
    clear
    puttab using "`key'.xlsx", frame(_pt250k) sheet("K") blockheader ///
        csv("`key'.csv") markdown("`key'.md")
    assert r(n_cols) == `refcols' & r(n_cols) == 7 & r(n_spans) == 2
    _v_facts "`key'.xlsx" "K"
    foreach ext in csv md {
        mata: st_local("same", strofreal(cat("`ref'.`ext'") == cat("`key'.`ext'")))
        assert `same' == 1
    }
    mata: st_local("same", strofreal(cat("`ref'.facts") == cat("$V230_RES")))
    assert `same' == 1
    * a wildcard or a range does not name a key column
    frame _pt250k {
        puttab * using "`key'.xlsx", sheet("K") blockheader csv("`key'.csv") markdown("`key'.md")
        assert r(n_cols) == 7
        mata: st_local("same", strofreal(cat("`ref'.csv") == cat("`key'.csv")))
        assert `same' == 1
        puttab _order-_state2, markdown("`key'.md") varlabels
        assert r(n_cols) == 7
    }
    * named literally, a key column is exported like any other
    frame _pt250k {
        puttab rowlabel _term c1 c2 c3, blockheader csv("`key'.csv") markdown("`key'.md")
        assert r(n_cols) == 5 & r(n_spans) == 1
        _pt250_lineat "`key'.csv" 1 ",,Crude,,"
        _pt250_lineat "`key'.csv" 2 " ,_term,`L1',`L2',`L3'"
        mata: _l = cat("`key'.csv"); st_local("ok3", strofreal(strpos(_l[3], ///
            strtrim(st_sdata(1, "rowlabel")) + ",t1," + strtrim(st_sdata(1, "c1")) + ",") == 1))
        assert `ok3' == 1
        * if may use a key column
        quietly count if _rowtype == "coef"
        local ncoef = r(N)
        puttab rowlabel c* if _rowtype == "coef", markdown("`key'.md")
        assert r(n_datarows) == `ncoef' & `ncoef' < _N
    }
    * the default is unchanged without the characteristic: a variable named
    * _order, or one whose tabtools_key is not 1, is exported
    frame copy _pt250k _pt250u, replace
    frame _pt250u {
        char _order[tabtools_key]
        char _term[tabtools_key] 0
        puttab, frame(_pt250u) markdown("`key'.md")
        assert r(n_cols) == 9
    }
    frame drop _pt250u
}
if _rc == 0 {
    display as result "  PASS: K6 key columns skipped in every sink unless named literally"
    local ++pass_count
}
else {
    display as error "  FAIL: K6 key columns (rc=`=_rc')"
    local ++fail_count
}

**# K7: hlines() at rows computed from _term, on a keyed frame
local ++test_count
capture noisily {
    local book "`output_dir'/pt250_k7.xlsx"
    capture erase "`book'"
    frame _pt250k {
        * the row of a term, counted as puttab counts data rows
        assert _N >= 2
        generate long _rn = _n
        quietly summarize _rn if _term == "t2", meanonly
        local r3 = r(min)
        drop _rn
        assert `r3' == 2
        local lab3 = strtrim(rowlabel[`r3'])
        puttab using "`book'", frame(_pt250k) sheet("K7") blockheader hlines(`r3')
    }
    * reserved title row 1, names row 2, header row 3, data from row 4
    local xr = 3 + `r3'
    _v_facts "`book'" "K7"
    _v_value B`xr' "`lab3'"
    _v_has top thin "B`xr' C`xr' D`xr' E`xr' F`xr' G`xr' H`xr'"
    local xr1 = `xr' + 1
    _v_none top "C`xr1'"
    * no key column reached the sheet
    _v_none value "I3 J3 K3"
    mata: _f = cat("$V230_RES"); st_local("bad", strofreal(sum(strpos(_f, "_order") :> 0) + ///
        sum(strpos(_f, "value C3 _term") :> 0)))
    assert `bad' == 0
    mata: mata drop _f
}
if _rc == 0 {
    display as result "  PASS: K7 hlines() at a row computed from _term"
    local ++pass_count
}
else {
    display as error "  FAIL: K7 hlines() on a keyed frame (rc=`=_rc')"
    local ++fail_count
}

**# K8: two separate regtab calls, same model name, side by side
* The block id must be unique per call, not per program: Stata hands the
* same tempname out again in a later call, so ids built from one made the
* two "Crude" models one block and blockheader merged C2:H2 (rc 0). The
* oracle is the call structure: frame _pt250a and _pt250b come from two
* regtab calls, so their columns are two blocks whatever their names.
local ++test_count
capture noisily {
    local book "`output_dir'/pt250_k8.xlsx"
    local md "`output_dir'/pt250_k8.md"
    capture erase "`book'"
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    quietly regtab, frame(_pt250a, replace flat) models("Crude")
    collect clear
    quietly collect: logit foreign mpg if rep78 >= 3
    quietly regtab, frame(_pt250b, replace flat) models("Crude")
    frame _pt250a: local ida : char c1[tabtools_block_id]
    frame _pt250b: local idb : char c1[tabtools_block_id]
    assert `"`ida'"' != "" & `"`idb'"' != "" & `"`ida'"' != `"`idb'"'
    * with the package's sequence restarted (as mata clear would), a new
    * call still gets an id no live frame uses: the sequence alone would
    * hand out a token frame _pt250b's block ids already carry
    capture mata: mata drop _tabtools_companion_seq
    collect clear
    quietly collect: logit foreign mpg
    quietly regtab, frame(_pt250c, replace flat) models("Crude")
    frame _pt250c: local idc : char c1[tabtools_block_id]
    assert `"`idc'"' != `"`ida'"' & `"`idc'"' != `"`idb'"'
    * side by side, rows aligned on the row label
    frame _pt250b {
        rename (c1 c2 c3) (d1 d2 d3)
        tempfile pb
        quietly save "`pb'"
    }
    frame copy _pt250a _pt250ab, replace
    frame _pt250ab {
        quietly merge 1:1 rowlabel using "`pb'", nogenerate
        puttab rowlabel c1 c2 c3 d1 d2 d3 using "`book'", sheet("K8") blockheader markdown("`md'")
        assert r(n_spans) == 2
    }
    _v_facts "`book'" "K8"
    _v_has merge "" "C2:E2 F2:H2"
    _v_none merge "C2:H2"
    _v_value C2 "Crude"
    _v_value F2 "Crude"
    * the columns of an earlier flat frame outlive it (copied into a frame
    * of the caller's, the producer's frame dropped) and the sequence starts
    * over: the next call's token would be the one those columns carry, so
    * the block ids are checked against every live frame
    capture mata: mata drop _tabtools_companion_seq
    collect clear
    quietly collect: logit foreign mpg
    quietly regtab, frame(_pt250d, replace flat) models("Crude")
    frame copy _pt250d _pt250keep, replace
    frame _pt250keep: char _dta[tabtools_companion_id]
    frame drop _pt250d
    frame _pt250keep: local idd : char c1[tabtools_block_id]
    capture mata: mata drop _tabtools_companion_seq
    quietly regtab, frame(_pt250e, replace flat) models("Crude")
    frame _pt250e: local ide : char c1[tabtools_block_id]
    assert `"`idd'"' != "" & `"`ide'"' != `"`idd'"'
    foreach f in _pt250a _pt250b _pt250c _pt250ab _pt250keep _pt250e {
        frame drop `f'
    }
}
if _rc == 0 {
    display as result "  PASS: K8 two calls with one model name stay two blocks"
    local ++pass_count
}
else {
    display as error "  FAIL: K8 block ids across calls (rc=`=_rc')"
    local ++fail_count
}

**# K9: effecttab flat frames side by side: no block names, nothing merged
* effecttab writes the full header as each label and no block name, so
* blockheader adds no row; two such frames side by side are never merged.
local ++test_count
capture noisily {
    local md "`output_dir'/pt250_k9.md"
    sysuse auto, clear
    generate byte treat = foreign
    collect clear
    quietly collect: teffects ra (price mpg) (treat), ate
    quietly effecttab, frame(_pt250e1, replace flat)
    collect clear
    quietly collect: teffects ra (price weight) (treat), ate
    quietly effecttab, frame(_pt250e2, replace flat)
    frame _pt250e1 {
        unab ev : c*
        foreach v of local ev {
            assert `"`: char `v'[tabtools_block]'"' == ""
        }
    }
    frame _pt250e2 {
        unab ev2 : c*
        local nn : word count `ev2'
        forvalues j = 1/`nn' {
            rename c`j' d`j'
        }
        tempfile pe
        quietly save "`pe'"
    }
    frame copy _pt250e1 _pt250ee, replace
    frame _pt250ee {
        quietly merge 1:1 rowlabel using "`pe'", nogenerate
        puttab rowlabel c* d*, blockheader markdown("`md'")
        assert r(n_spans) == 0
    }
    foreach f in _pt250e1 _pt250e2 _pt250ee {
        frame drop `f'
    }
}
if _rc == 0 {
    display as result "  PASS: K9 effecttab flat frames: no block row, nothing merged"
    local ++pass_count
}
else {
    display as error "  FAIL: K9 effecttab flat frames (rc=`=_rc')"
    local ++fail_count
}

**# K10: a companion id is never one a live frame already carries
* _tabtools_companion_id scans the live frames for its candidate; the scan
* counted the frames with cols() of a column vector, so it looked at the
* first frame only and, with the sequence restarted, handed out the id of a
* frame later in the list.
local ++test_count
capture noisily {
    capture mata: mata drop _tabtools_companion_seq
    _tabtools_companion_id
    local cida : copy local _companion_id
    frame create _pt250zz
    frame _pt250zz: mata: st_global("_dta[tabtools_companion_id]", st_local("cida"))
    frame create _pt250aa
    capture mata: mata drop _tabtools_companion_seq
    _tabtools_companion_id
    local cidb : copy local _companion_id
    assert `"`cida'"' != "" & `"`cidb'"' != `"`cida'"'
    frame drop _pt250zz
    frame drop _pt250aa
}
if _rc == 0 {
    display as result "  PASS: K10 companion ids skip every live frame's id"
    local ++pass_count
}
else {
    display as error "  FAIL: K10 companion id scan (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _pt250zz
capture frame drop _pt250aa

**# H1: caller state is untouched on success and on a refusal
local ++test_count
capture noisily {
    set varabbrev on
    frame change _pt250m
    qa_state_snapshot, tag(pt250)
    puttab rowlabel c* using "`output_dir'/pt250_h1.xlsx", blockheader
    qa_state_compare, tag(pt250)
    qa_state_snapshot, tag(pt250)
    capture puttab rowlabel c*, blockheader noheader markdown("`output_dir'/pt250_h1.md")
    local call_rc = _rc
    qa_state_compare, tag(pt250)
    assert `call_rc' == 198
    frame change default
    _pt250_data
    qa_state_snapshot, tag(pt250)
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) panelinline ///
        noheader markdown("`output_dir'/pt250_h1.md")
    qa_state_compare, tag(pt250)
    assert c(varabbrev) == "on"
}
if _rc == 0 {
    display as result "  PASS: H1 session fingerprint unchanged (success and refusal)"
    local ++pass_count
}
else {
    display as error "  FAIL: H1 session fingerprint (rc=`=_rc')"
    local ++fail_count
}
capture frame change default
set varabbrev off
capture frame drop _pt250m
capture frame drop _pt250k
capture matrix drop M
capture mata: mata drop _l
macro drop PT250_FIX V230_TOOL V230_RES

display "RESULT: test_puttab_v250 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pt250
if `fail_count' > 0 exit 1

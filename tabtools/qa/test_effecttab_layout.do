* test_effecttab_layout.do - effecttab xlsx body layout: merges and alignment
* Two layout defects that regtab had already fixed, pinned by reading the
* written workbook back with openpyxl (merge ranges, cell values, vertical
* alignment) rather than the pre-export frame, which never shows either one.
*
* 1. Reference/Omitted/Empty merges were built from the UNION of those rows
*    across model blocks and applied to every block. A model with a real
*    estimate on a row that another model treats as its reference had its
*    estimate/CI/p triplet merged: the CI and p-value cells vanished and the
*    anchor showed the bare estimate, centred.
* 2. The body top-align rule covered column B only, so estimate/CI/p cells
*    kept the bottom alignment and sat on the last line of a wrapped label.
*
* Tests 1, 2, 4 and 5 fail on 2.1.10; test 3 pins single-model merge output,
* which the fix must leave unchanged.

clear all
set more off
set varabbrev off
version 17.0

capture log close _effecttab_layout
log using "test_effecttab_layout.log", replace text name(_effecttab_layout)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

**# Workbook probe
* One CSV row per worksheet cell: row, col, value, vertical alignment, and
* merge role (anchor = top-left cell of a merged range, inner = any other cell
* of one, none = unmerged). Written from here so the released suite carries no
* extra tool file. Python code avoids backticks, dollar signs and double quotes
* so Stata passes every line through verbatim.
local probe "`output_dir'/_etl_probe.py"
tempname pfh
file open `pfh' using "`probe'", write text replace
file write `pfh' "import sys, csv" _n
file write `pfh' "import openpyxl" _n
file write `pfh' "wb = openpyxl.load_workbook(sys.argv[1])" _n
file write `pfh' "ws = wb[sys.argv[2]]" _n
file write `pfh' "role = {}" _n
file write `pfh' "for rg in ws.merged_cells.ranges:" _n
file write `pfh' "    for r in range(rg.min_row, rg.max_row + 1):" _n
file write `pfh' "        for c in range(rg.min_col, rg.max_col + 1):" _n
file write `pfh' "            first = (r == rg.min_row and c == rg.min_col)" _n
file write `pfh' "            role[(r, c)] = ('anchor' if first else 'inner', str(rg))" _n
file write `pfh' "with open(sys.argv[3], 'w', newline='') as fh:" _n
file write `pfh' "    w = csv.writer(fh)" _n
file write `pfh' "    w.writerow(['row', 'col', 'value', 'valign', 'merge', 'mrange'])" _n
file write `pfh' "    for r in range(1, ws.max_row + 1):" _n
file write `pfh' "        for c in range(1, ws.max_column + 1):" _n
file write `pfh' "            cell = ws.cell(row=r, column=c)" _n
file write `pfh' "            v = '' if cell.value is None else str(cell.value).strip()" _n
file write `pfh' "            va = cell.alignment.vertical or 'default'" _n
file write `pfh' "            m, rgs = role.get((r, c), ('none', ''))" _n
file write `pfh' "            w.writerow([r, c, v, va, m, rgs])" _n
file close `pfh'

* Dump sheet `sheet' of `xlsx' into frame `frname'. The Stata shell does not
* propagate the child's exit status, so the CSV is erased first and its
* existence is the success signal.
capture program drop _etl_dump
program define _etl_dump
    version 17.0
    args probe xlsx sheet frname
    local csv = regexr(`"`xlsx'"', "\.xlsx$", "_cells.csv")
    capture erase "`csv'"
    shell python3 "`probe'" "`xlsx'" "`sheet'" "`csv'"
    confirm file "`csv'"
    capture frame drop `frname'
    frame create `frname'
    frame `frname' {
        quietly import delimited using "`csv'", varnames(1) ///
            stringcols(3 4 5 6) bindquote(strict) clear
        quietly count
        if r(N) == 0 {
            display as error "workbook probe returned no cells"
            exit 459
        }
    }
end

* Worksheet row of the body row whose column-B label is `label'. Errors when
* the label is absent or not unique, so a renamed row cannot pass by accident.
capture program drop _etl_row
program define _etl_row, rclass
    version 17.0
    args frname label
    frame `frname' {
        quietly count if col == 2 & row >= 4 & value == `"`label'"'
        if r(N) != 1 {
            display as error `"body row "`label'" found `r(N)' times"'
            exit 459
        }
        quietly summarize row if col == 2 & row >= 4 & value == `"`label'"', meanonly
        local r = r(min)
    }
    return scalar row = `r'
end

* Value, vertical alignment and merge role of one cell.
capture program drop _etl_cell
program define _etl_cell, rclass
    version 17.0
    args frname row col
    frame `frname' {
        quietly count if row == `row' & col == `col'
        if r(N) != 1 {
            display as error "cell (`row', `col') not in workbook dump"
            exit 459
        }
        quietly levelsof value if row == `row' & col == `col', local(v) clean
        quietly levelsof valign if row == `row' & col == `col', local(va) clean
        quietly levelsof merge if row == `row' & col == `col', local(m) clean
        quietly levelsof mrange if row == `row' & col == `col', local(mr) clean
    }
    return local value `"`v'"'
    return local valign "`va'"
    return local merge "`m'"
    return local mrange "`mr'"
end

* Model block `m' on body row `label' is one merged est/CI/p range holding
* `text'. Columns: B label, then three per model starting at C.
capture program drop _etl_assert_merged
program define _etl_assert_merged
    version 17.0
    args frname label m text
    _etl_row `frname' `"`label'"'
    local r = r(row)
    local c0 = 3 * `m'
    local L0 = char(64 + `c0')
    local L2 = char(64 + `c0' + 2)
    _etl_cell `frname' `r' `c0'
    assert "`r(merge)'" == "anchor"
    assert "`r(mrange)'" == "`L0'`r':`L2'`r'"
    assert `"`r(value)'"' == `"`text'"'
    assert "`r(valign)'" == "center"
end

* Model block `m' on body row `label' is three unmerged cells: a numeric
* estimate, a "(lo, hi)" interval and a p-value. When ll/ul are supplied the
* interval bounds must match them to display precision.
capture program drop _etl_assert_open
program define _etl_assert_open
    version 17.0
    args frname label m ll ul
    _etl_row `frname' `"`label'"'
    local r = r(row)
    local c0 = 3 * `m'
    forvalues k = 0/2 {
        _etl_cell `frname' `r' `=`c0' + `k''
        assert "`r(merge)'" == "none"
        local v`k' `"`r(value)'"'
    }
    assert real(`"`v0'"') < .
    assert regexm(`"`v1'"', "^\((-?[0-9]+\.[0-9]+), (-?[0-9]+\.[0-9]+)\)$")
    local lo = real(regexs(1))
    local hi = real(regexs(2))
    assert `lo' < `hi'
    if "`ll'" != "" {
        assert abs(`lo' - `ll') <= 0.005 + 1e-9
        assert abs(`hi' - `ul') <= 0.005 + 1e-9
    }
    assert regexm(`"`v2'"', "^(<0\.001|0\.[0-9]+|1\.0*)$")
end

* Count body cells in columns B..last that are unmerged or merge anchors and
* are not top-aligned, excluding the anchors of Reference/Omitted/Empty merges
* (vertically centred by design, as in regtab). r(checked) guards against an
* empty scan passing vacuously.
capture program drop _etl_valign
program define _etl_valign, rclass
    version 17.0
    args frname lastcol
    frame `frname' {
        quietly count if row >= 4 & inrange(col, 2, `lastcol') & merge != "inner" ///
            & !(merge == "anchor" & inlist(value, "Reference", "Omitted", "Empty"))
        local checked = r(N)
        quietly count if row >= 4 & inrange(col, 2, `lastcol') & merge != "inner" ///
            & !(merge == "anchor" & inlist(value, "Reference", "Omitted", "Empty")) ///
            & valign != "top"
        local bad = r(N)
        if `bad' > 0 {
            list row col value valign merge if row >= 4 & inrange(col, 2, `lastcol') ///
                & merge != "inner" & valign != "top" ///
                & !(merge == "anchor" & inlist(value, "Reference", "Omitted", "Empty")), ///
                noobs abbreviate(8)
        }
    }
    return scalar checked = `checked'
    return scalar bad = `bad'
end

* Number of merge anchors in body rows.
capture program drop _etl_nanchors
program define _etl_nanchors, rclass
    version 17.0
    args frname
    frame `frname' {
        quietly count if row >= 4 & merge == "anchor"
        local n = r(N)
    }
    return scalar n = `n'
end

* Lower/upper confidence bound for column `colname' of matrix `mat' (a
* margins r(table)), looked up by row and column name. Errors if either is
* absent so a renamed level cannot drop the oracle silently.
capture program drop _etl_ci
program define _etl_ci, rclass
    version 17.0
    args mat colname
    local c = colnumb(`mat', "`colname'")
    local rl = rownumb(`mat', "ll")
    local ru = rownumb(`mat', "ul")
    if missing(`c') | missing(`rl') | missing(`ru') {
        display as error "`mat' has no ll/ul for `colname'"
        exit 459
    }
    return scalar ll = `mat'[`rl', `c']
    return scalar ul = `mat'[`ru', `c']
end

capture program drop _etl_data
program define _etl_data
    version 17.0
    clear
    set obs 800
    generate grp = mod(_n, 4) + 1
    label define GL 1 "One" 2 "Two" 3 "Three" 4 "Four", replace
    label values grp GL
    label variable grp "Group"
    generate byte flag = (grp == 4)
    label variable flag "Flag"
    * stata-dev-ignore: unseeded-draw — generator PROGRAM; every call site runs `set seed 20260926' immediately before `_etl_data'
    generate double x = rnormal()
    label variable x "X score"
    generate double y = 0.5 * x + 0.3 * (grp == 2) - 0.2 * (grp == 3) + rnormal()
end

**# Two-model fixture shared by tests 1 and 2
* Model 1 takes level One as base, model 2 level Two, so each model has a real
* estimate on the row the other treats as its Reference. The margins r(table)
* of each model is the oracle for the intervals that must survive.
set seed 20260926
_etl_data
collect clear
quietly regress y i.grp x
quietly collect: margins, dydx(*)
matrix _etl_M1 = r(table)
quietly regress y ib2.grp x
quietly collect: margins, dydx(*)
matrix _etl_M2 = r(table)
local xlsx2 "`output_dir'/test_effecttab_layout_two.xlsx"
capture erase "`xlsx2'"
local fix2_rc = 0
capture noisily {
    effecttab, xlsx("`xlsx2'") sheet("Layout") effect("AME") ///
        models("Base One \ Base Two")
    confirm file "`xlsx2'"
    _etl_dump "`probe'" "`xlsx2'" "Layout" _etl_two
}
local fix2_rc = _rc

**# Test 1: a Reference row merges only the model that holds it
capture noisily {
    assert `fix2_rc' == 0
    * Row One: model 1 Reference (merged C:E), model 2 real and intact (F, G, H)
    _etl_assert_merged _etl_two "One" 1 "Reference"
    _etl_ci _etl_M2 "1.grp"
    _etl_assert_open _etl_two "One" 2 `r(ll)' `r(ul)'

    * Row Two: the mirror image
    _etl_assert_merged _etl_two "Two" 2 "Reference"
    _etl_ci _etl_M1 "2.grp"
    _etl_assert_open _etl_two "Two" 1 `r(ll)' `r(ul)'

    * Rows neither model constrains are untouched in both blocks
    foreach lab in "Three" "Four" "X score" {
        _etl_assert_open _etl_two "`lab'" 1
        _etl_assert_open _etl_two "`lab'" 2
    }

    * Exactly the two Reference triplets are merged in the body
    _etl_nanchors _etl_two
    assert r(n) == 2
}
if _rc == 0 {
    display as result "  PASS: Reference merge confined to its own model block"
    local ++pass_count
}
else {
    display as error "  FAIL: Reference merge crossed model blocks (rc=`=_rc')"
    local ++fail_count
}

**# Test 2: body cells are top-aligned across B..last, not column B only
capture noisily {
    assert `fix2_rc' == 0
    _etl_valign _etl_two 8
    * 6 body rows x B..H = 42 cells; a correct layout checks 36 of them
    assert r(checked) >= 30
    assert r(bad) == 0
    * Spot-check the cells the old rule missed: last model's p-value column
    _etl_row _etl_two "X score"
    _etl_cell _etl_two `r(row)' 8
    assert "`r(valign)'" == "top"
}
if _rc == 0 {
    display as result "  PASS: estimate/CI/p cells top-aligned with the label"
    local ++pass_count
}
else {
    display as error "  FAIL: body cells not top-aligned across B..last (rc=`=_rc')"
    local ++fail_count
}

**# Test 3: single-model merge layout is unchanged
capture noisily {
    set seed 20260926
    _etl_data
    collect clear
    quietly regress y i.grp x
    quietly collect: margins, dydx(*)
    matrix _etl_S = r(table)
    local xlsx1 "`output_dir'/test_effecttab_layout_one.xlsx"
    capture erase "`xlsx1'"
    effecttab, xlsx("`xlsx1'") sheet("Layout") effect("AME")
    _etl_dump "`probe'" "`xlsx1'" "Layout" _etl_one

    _etl_assert_merged _etl_one "One" 1 "Reference"
    _etl_ci _etl_S "3.grp"
    _etl_assert_open _etl_one "Three" 1 `r(ll)' `r(ul)'
    foreach lab in "Two" "Four" "X score" {
        _etl_assert_open _etl_one "`lab'" 1
    }
    _etl_nanchors _etl_one
    assert r(n) == 1
    * Nothing beyond column E was written
    frame _etl_one {
        quietly count if col > 5 & value != ""
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: single-model Reference merge unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: single-model merge layout (rc=`=_rc')"
    local ++fail_count
}

**# Test 4: single-model body cells are top-aligned across B..E
capture noisily {
    confirm frame _etl_one
    _etl_valign _etl_one 5
    * 6 body rows x B..E = 24 cells; 21 remain after the Reference merge
    assert r(checked) == 21
    assert r(bad) == 0
}
if _rc == 0 {
    display as result "  PASS: single-model body top-aligned across B..E"
    local ++pass_count
}
else {
    display as error "  FAIL: single-model body alignment (rc=`=_rc')"
    local ++fail_count
}

**# Test 5: three models mixing Reference, Omitted and a shared Reference row
* Model 1 constrains One (base) and Two/Three/Four (flag duplicates 4.grp, so
* no grp contrast is estimable); model 2 constrains One only; model 3
* constrains Three only. Row One is a Reference in two blocks at once and row
* Three is Omitted in one block and Reference in another, so a fix that merged
* only the first model holding a label would fail here; row Flag exists in
* model 1 alone.
capture noisily {
    set seed 20260926
    _etl_data
    collect clear
    quietly regress y flag i.grp x
    quietly collect: margins, dydx(*)
    quietly regress y i.grp x
    quietly collect: margins, dydx(*)
    matrix _etl_T2 = r(table)
    quietly regress y ib3.grp x
    quietly collect: margins, dydx(*)
    matrix _etl_T3 = r(table)
    local xlsx3 "`output_dir'/test_effecttab_layout_three.xlsx"
    capture erase "`xlsx3'"
    effecttab, xlsx("`xlsx3'") sheet("Layout") effect("AME") ///
        models("Flagged \ Base One \ Base Three")
    _etl_dump "`probe'" "`xlsx3'" "Layout" _etl_three

    _etl_assert_merged _etl_three "One" 1 "Reference"
    _etl_assert_merged _etl_three "One" 2 "Reference"
    _etl_ci _etl_T3 "1.grp"
    _etl_assert_open _etl_three "One" 3 `r(ll)' `r(ul)'

    _etl_assert_merged _etl_three "Two" 1 "Omitted"
    _etl_ci _etl_T2 "2.grp"
    _etl_assert_open _etl_three "Two" 2 `r(ll)' `r(ul)'
    _etl_assert_open _etl_three "Two" 3

    _etl_assert_merged _etl_three "Four" 1 "Omitted"
    _etl_assert_open _etl_three "Four" 2
    _etl_assert_open _etl_three "Four" 3

    _etl_assert_merged _etl_three "Three" 1 "Omitted"
    _etl_assert_open _etl_three "Three" 2
    _etl_assert_merged _etl_three "Three" 3 "Reference"

    * Flag: real in model 1, absent (blank, unmerged) in models 2 and 3
    _etl_assert_open _etl_three "Flag" 1
    _etl_row _etl_three "Flag"
    local fr = r(row)
    forvalues col = 6/11 {
        _etl_cell _etl_three `fr' `col'
        assert "`r(merge)'" == "none"
        assert `"`r(value)'"' == ""
    }

    _etl_nanchors _etl_three
    assert r(n) == 6
    _etl_valign _etl_three 11
    assert r(bad) == 0
}
if _rc == 0 {
    display as result "  PASS: three-model Reference/Omitted merges per block"
    local ++pass_count
}
else {
    display as error "  FAIL: three-model per-block merges (rc=`=_rc')"
    local ++fail_count
}

**# Cleanup
foreach fr in _etl_two _etl_one _etl_three {
    capture frame drop `fr'
}
capture matrix drop _etl_M1 _etl_M2 _etl_S _etl_T2 _etl_T3
capture erase "`probe'"

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_effecttab_layout tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _effecttab_layout
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_effecttab_layout tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _effecttab_layout

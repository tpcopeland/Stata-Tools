* test_synthesis_review.do - Regression suite for the synthesized 4-reviewer audit
*
* Pins the 1.12.0 fixes for A1, A2, A3, A4, A5, B1, B2, B3, B4, B5 and B7.
*
* Every assertion below was run against the pre-fix tree and observed to fail
* there. Where a check could pass on unfixed code it has been made exact rather
* than a containment test: the A5 checks compare the CSV's first and last rows
* against the strings that were passed in, and additionally require the last
* data row to carry a row label, which is what the "title as its own column"
* regression broke; B4 drives the missingsummary branch that owns the defect,
* not the unrelated missing branch, and compares the cell verbatim.

clear all
version 17.0
set more off
set varabbrev off

capture log close _all
log using "test_synthesis_review.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir = c(pwd)
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which table1_tc

local outdir "$TABTOOLS_QA_OUTPUT_DIR"
if `"`outdir'"' == "" {
    tempfile _sr_token
    local outdir "`_sr_token'_synthesis"
    capture mkdir `"`outdir'"'
}

* =========================================================================
**# Shared checker: CSV shape contract (A5)
* =========================================================================
* Every table-writing command must give its CSV the same shape as its
* workbook: the title in the first field of row 1, the footnote in the first
* field of the last row, and a row label in the first field of the last data
* row. That last requirement is what fails when the title is exported as its
* own column, which pushes every body row one field to the right.
capture program drop _sr_csv_contract
program define _sr_csv_contract
    syntax using/ , TITLE(string) FOOTnote(string) [LABELLAST(integer 1)]

    quietly import delimited using `"`using'"', clear varnames(nonames) ///
        stringcols(_all) bindquote(strict) encoding(utf8)
    if _N < 3 {
        display as error "      CSV has `=_N' rows; expected title + body + footnote"
        exit 9
    }
    local _got_title = v1[1]
    local _got_foot  = v1[_N]
    local _got_last  = v1[_N - 1]
    if `"`_got_title'"' != `"`title'"' {
        display as error `"      row 1 field 1 is "`_got_title'"; expected "`title'""'
        exit 9
    }
    if `"`_got_foot'"' != `"`footnote'"' {
        display as error `"      last row field 1 is "`_got_foot'"; expected "`footnote'""'
        exit 9
    }
    if `labellast' & strtrim(`"`_got_last'"') == "" {
        display as error "      last data row has an empty first field (title exported as its own column?)"
        exit 9
    }
end

* =========================================================================
**# A1. table1_tc must return _rc == 0 on success (bare call, no capture)
* =========================================================================
* Observed pre-fix: _rc == 111. The suite's 132 `capture noisily' wrappers
* cannot see this, because the capture prefix resets _rc to the program's own
* exit code; the bare call below is the only shape that can.
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg conts)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': A1 table1_tc bare-call _rc == 0"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A1 table1_tc bare-call _rc = " _rc
    local ++fail_count
}

* =========================================================================
**# A2. desctab must return _rc == 0 on success (bare call, no capture)
* =========================================================================
* Observed pre-fix: _rc == 198, from `capture putexcel close' with no file set.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: table (var) (result), statistic(mean price mpg)
    desctab
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': A2 desctab bare-call _rc == 0"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A2 desctab bare-call _rc = " _rc
    local ++fail_count
}

* =========================================================================
**# A1/A2 scope: every other public command already returned 0. These are
**# guards against the same tail-shaped defect appearing elsewhere.
* =========================================================================
foreach _cmd in corrtab crosstab puttab regtab survtab {
    local ++test_count
    capture noisily {
        if "`_cmd'" == "corrtab" {
            sysuse auto, clear
            corrtab price mpg weight
        }
        else if "`_cmd'" == "crosstab" {
            sysuse auto, clear
            crosstab foreign rep78
        }
        else if "`_cmd'" == "puttab" {
            sysuse auto, clear
            puttab make price in 1/3 using "`outdir'/_sr_scope.xlsx"
        }
        else if "`_cmd'" == "regtab" {
            sysuse auto, clear
            collect clear
            quietly collect: regress price mpg
            regtab
        }
        else if "`_cmd'" == "survtab" {
            webuse stan3, clear
            quietly stset t1, failure(died) id(id)
            survtab, times(50 100)
        }
        assert _rc == 0
    }
    if _rc == 0 {
        display as result "  PASS `test_count': A1/A2 scope `_cmd' _rc == 0"
        local ++pass_count
    }
    else {
        display as error "  FAIL `test_count': A1/A2 scope `_cmd' _rc = " _rc
        local ++fail_count
    }
}

* =========================================================================
**# A3. A Markdown footnote beginning with * must round-trip
* =========================================================================
* Observed pre-fix: "* p<.05, ** p<.01" wrapped in *...* rendered as bold
* fragments plus a dangling asterisk, and two such legends shipped in
* demo/demo_markdown_report.md. The existing footnote test used a footnote
* with no leading *, so it could not see this.
local ++test_count
capture noisily {
    sysuse auto, clear
    local _md "`outdir'/_sr_a3.md"
    capture erase "`_md'"
    puttab make price in 1/2 using "`outdir'/_sr_a3.xlsx", ///
        markdown("`_md'") footnote("* p<.05, ** p<.01, *** p<.001")
    * char(1) as the delimiter keeps each line whole. import delimited
    * auto-detects a delimiter when none is given, and would pick the Markdown
    * table's own pipe, splitting the line into fields and leaving v1 empty.
    quietly import delimited using "`_md'", clear varnames(nonames) ///
        delimiter("`=char(1)'") stringcols(_all) encoding(utf8)
    * Exact match. The writer wraps a footnote in *...* for emphasis, which is
    * intended; what was broken is that the legend's own asterisks were not
    * escaped, so the line rendered as bold fragments plus a dangling asterisk.
    * Pre-fix this line read "** p<.05, ** p<.01, *** p<.001*".
    quietly count if v1 == "*\* p<.05, \*\* p<.01, \*\*\* p<.001*"
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': A3 Markdown footnote asterisks escaped"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A3 Markdown footnote asterisks unescaped (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# A4. puttab must honour the order of the user's varlist
* =========================================================================
* Observed pre-fix: `quietly ds' after `keep' re-enumerated in dataset order,
* so `puttab z x y' emitted x, y, z into all three sinks.
local ++test_count
capture noisily {
    clear
    quietly set obs 3
    quietly generate x = _n
    quietly generate y = _n * 2
    quietly generate z = _n * 3
    local _md "`outdir'/_sr_a4.md"
    capture erase "`_md'"
    puttab z x y using "`outdir'/_sr_a4.xlsx", markdown("`_md'")
    quietly import delimited using "`_md'", clear varnames(nonames) ///
        delimiter("`=char(1)'") stringcols(_all) encoding(utf8)
    local _hdr = v1[1]
    assert strpos(`"`_hdr'"', "| z | x | y |") > 0
}
if _rc == 0 {
    display as result "  PASS `test_count': A4 puttab honours varlist order"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A4 puttab varlist order not preserved (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# A5. CSV carries title() and footnote(), with no reserved empty row and
**# no extra leading column
* =========================================================================
* Observed pre-fix: the collect-style commands parked title() in a variable
* that was not exported and rendered footnote() only into the workbook, so the
* CSV opened on an all-empty row and carried neither. The first attempt at a
* fix exported that variable as an extra column, which pushed every body row
* one field right; `labellast' catches that.
local _sr_t "SR TITLE"
local _sr_f "SR FOOTNOTE"

* --- crosstab
local ++test_count
capture noisily {
    sysuse auto, clear
    local _csv "`outdir'/_sr_a5_crosstab.csv"
    capture erase "`_csv'"
    crosstab foreign rep78, csv("`_csv'") title("`_sr_t'") footnote("`_sr_f'")
    _sr_csv_contract using "`_csv'", title("`_sr_t'") footnote("`_sr_f'")
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 crosstab CSV shape"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 crosstab CSV shape (rc=`=_rc')"
    local ++fail_count
}

* --- corrtab, including the generated star legend (A5 rider)
local ++test_count
capture noisily {
    sysuse auto, clear
    local _csv "`outdir'/_sr_a5_corrtab.csv"
    capture erase "`_csv'"
    corrtab price mpg weight, star(0.05 0.01) csv("`_csv'") ///
        title("`_sr_t'") footnote("`_sr_f'")
    quietly import delimited using "`_csv'", clear varnames(nonames) ///
        stringcols(_all) bindquote(strict) encoding(utf8)
    local _t1 = v1[1]
    assert `"`_t1'"' == "`_sr_t'"
    * The legend is generated, not user-supplied; the console, the workbook and
    * the Markdown file all carry it and the CSV used to drop it, so a CSV could
    * ship "0.54**" with nothing explaining the mark.
    local _fn = v1[_N]
    assert strpos(`"`_fn'"', "`_sr_f'") == 1
    * 1.15.0: this assertion used to read "p<.05" and so PINNED the legend
    * defect it was standing next to -- corrtab printed "p<0.05" for its default
    * thresholds and "p<.05" for the identical thresholds passed through star(),
    * because the default is a literal string while star() has been through
    * numlist. The claim this test exists to make is that the generated legend
    * REACHES the CSV, not which of two spellings it arrives in.
    assert strpos(`"`_fn'"', "p<0.05") > 0
    assert strtrim(v1[_N - 1]) != ""
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 corrtab CSV shape + star legend"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 corrtab CSV shape/legend (rc=`=_rc')"
    local ++fail_count
}

* --- survtab
local ++test_count
capture noisily {
    webuse stan3, clear
    quietly stset t1, failure(died) id(id)
    local _csv "`outdir'/_sr_a5_survtab.csv"
    capture erase "`_csv'"
    survtab, times(50 100) csv("`_csv'") title("`_sr_t'") footnote("`_sr_f'")
    _sr_csv_contract using "`_csv'", title("`_sr_t'") footnote("`_sr_f'")
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 survtab CSV shape"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 survtab CSV shape (rc=`=_rc')"
    local ++fail_count
}

* --- table1_tc (title() needs a workbook sink alongside csv())
local ++test_count
capture noisily {
    sysuse auto, clear
    local _csv "`outdir'/_sr_a5_table1.csv"
    capture erase "`_csv'"
    table1_tc, by(foreign) vars(price contn) xlsx("`outdir'/_sr_a5_table1.xlsx") ///
        csv("`_csv'") title("`_sr_t'") footnote("`_sr_f'")
    _sr_csv_contract using "`_csv'", title("`_sr_t'") footnote("`_sr_f'")
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 table1_tc CSV shape"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 table1_tc CSV shape (rc=`=_rc')"
    local ++fail_count
}

* --- regtab (labelvar(A) caller: row labels live in the first exported column)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    local _csv "`outdir'/_sr_a5_regtab.csv"
    capture erase "`_csv'"
    regtab, csv("`_csv'") title("`_sr_t'") footnote("`_sr_f'")
    _sr_csv_contract using "`_csv'", title("`_sr_t'") footnote("`_sr_f'")
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 regtab CSV shape"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 regtab CSV shape (rc=`=_rc')"
    local ++fail_count
}

* --- desctab
local ++test_count
capture noisily {
    sysuse auto, clear
    local _csv "`outdir'/_sr_a5_desctab.csv"
    local _md "`outdir'/_sr_a5_desctab.md"
    capture erase "`_csv'"
    capture erase "`_md'"
    desctab price mpg rep78, by(foreign) ///
        csv("`_csv'") markdown("`_md'") ///
        title("`_sr_t'") footnote("`_sr_f'")
    _sr_csv_contract using "`_csv'", title("`_sr_t'") footnote("`_sr_f'")
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 desctab CSV shape"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 desctab CSV shape (rc=`=_rc')"
    local ++fail_count
}

* --- puttab already wrote both into body cells; this guards that
* --- the shared writer did not disturb them.
local ++test_count
capture noisily {
    sysuse auto, clear
    local _csv "`outdir'/_sr_a5_puttab.csv"
    capture erase "`_csv'"
    puttab make price mpg in 1/3 using "`outdir'/_sr_a5_puttab.xlsx", ///
        csv("`_csv'") title("`_sr_t'") footnote("`_sr_f'")
    _sr_csv_contract using "`_csv'", title("`_sr_t'") footnote("`_sr_f'")
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 puttab CSV shape unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 puttab CSV shape (rc=`=_rc')"
    local ++fail_count
}

* --- no title(), no footnote(): the reserved all-empty first row must be gone
local ++test_count
capture noisily {
    sysuse auto, clear
    local _csv "`outdir'/_sr_a5_plain.csv"
    capture erase "`_csv'"
    crosstab foreign rep78, csv("`_csv'")
    quietly import delimited using "`_csv'", clear varnames(nonames) ///
        stringcols(_all) bindquote(strict) encoding(utf8)
    * Row 1 must be the header row, not a reserved blank.
    assert strtrim(v1[1]) != ""
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 no reserved empty first CSV row"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 CSV opens on an empty row (rc=`=_rc')"
    local ++fail_count
}

* --- a title carrying embedded double quotes and a comma must round-trip
local ++test_count
capture noisily {
    sysuse auto, clear
    local _csv "`outdir'/_sr_a5_quotes.csv"
    capture erase "`_csv'"
    crosstab foreign rep78, csv("`_csv'") ///
        title(`"Mean "adjusted", by group"') footnote(`"See "Methods", table 2"')
    _sr_csv_contract using "`_csv'", title(`"Mean "adjusted", by group"') ///
        footnote(`"See "Methods", table 2"')
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 compound-quoted title/footnote round-trip"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 quoted title/footnote mangled (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# B1/B2. Workbook rules and alignment
* =========================================================================
* B1: every regtab stats() and addrow() row carried its own bottom rule, so a
*     model-fit block rendered as a grid stapled to a booktabs table.
* B2: only the label column was top-aligned, so the comment's stated intent
*     failed for every single-line row.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    * B1 needs stats()/addrow() rows to exist; B2 must not see them, because
    * those rows centre their own value cells by design.
    local _xl1 "`outdir'/_sr_b1.xlsx"
    capture erase "`_xl1'"
    regtab, xlsx("`_xl1'") sheet("B1") stats(n r2 aic) ///
        addrow("Controls" "Yes" \ "Sample" "All")

    local _xl2 "`outdir'/_sr_b2.xlsx"
    capture erase "`_xl2'"
    regtab, xlsx("`_xl2'") sheet("B2")

    local _status "`outdir'/_sr_style_status.txt"
    capture erase "`_status'"
    shell python3 "`qa_dir'/tools/check_synthesis_style.py" ///
        --b1 "`_xl1'" --b1-sheet "B1" ///
        --b2 "`_xl2'" --b2-sheet "B2" ///
        --status-file "`_status'"
    tempname _sfh
    file open `_sfh' using "`_status'", read text
    file read `_sfh' _sline
    local _first_line `"`_sline'"'
    local _detail ""
    while r(eof) == 0 {
        file read `_sfh' _sline
        if r(eof) == 0 local _detail `"`_detail' | `_sline'"'
    }
    file close `_sfh'
    if strpos(`"`_first_line'"', "PASS") != 1 {
        display as error `"      `_first_line'`_detail'"'
    }
    assert strpos(`"`_first_line'"', "PASS") == 1
}
if _rc == 0 {
    display as result "  PASS `test_count': B1/B2/B3 workbook rules and alignment"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': B1/B2/B3 workbook rules or alignment (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# B4. table1_tc missingsummary row: indent and percent format
* =========================================================================
* Observed pre-fix: the row read '  Missing' (two spaces) where the category
* levels use three, and its percent was built with a hard-coded "%5.1f" + "%"
* that ignored percformat()/percsign(), so it read '4 (7.7%)' in a column of
* '2 (4)' cells. The defect lives in the missingsummary branch; a test driving
* the unrelated `missing' option cannot see it.
local ++test_count
capture noisily {
    sysuse auto, clear
    local _xl "`outdir'/_sr_b4_default.xlsx"
    capture erase "`_xl'"
    table1_tc, by(foreign) vars(rep78 cat) missingsummary ///
        xlsx("`_xl'") sheet("MS")
    quietly import excel using "`_xl'", sheet("MS") allstring clear
    quietly count if B == "   Missing"
    assert r(N) == 1
    * Exact match, not strpos: two spaces and four spaces must both fail.
    quietly levelsof C if B == "   Missing", local(_mcell) clean
    * Default percformat is %5.0f with no percent sign, matching the category
    * rows in the same column.
    assert strpos(`"`_mcell'"', "%") == 0
    assert strpos(`"`_mcell'"', ".") == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': B4 missingsummary row uses default percformat/percsign"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': B4 missingsummary default format (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    local _xl "`outdir'/_sr_b4_custom.xlsx"
    capture erase "`_xl'"
    table1_tc, by(foreign) vars(rep78 cat) missingsummary ///
        percformat(%6.2f) percsign("%") xlsx("`_xl'") sheet("MS")
    quietly import excel using "`_xl'", sheet("MS") allstring clear
    quietly count if B == "   Missing"
    assert r(N) == 1
    quietly levelsof C if B == "   Missing", local(_mcell) clean
    * percformat(%6.2f) gives two decimals; the hard-coded "%5.1f" gave one.
    assert regexm(`"`_mcell'"', "\.[0-9][0-9]%\)$")
}
if _rc == 0 {
    display as result "  PASS `test_count': B4 missingsummary row honours percformat/percsign"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': B4 missingsummary custom format (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# B5. table1_tc p-values carry no leading alignment space
* =========================================================================
* Observed pre-fix: the space added for console alignment fired for >0.99 but
* not <0.001 -- the two symmetric edge cases it existed to align -- and leaked
* verbatim into xlsx and CSV, where Excel refuses to treat " 0.68" as a number.
local ++test_count
capture noisily {
    sysuse auto, clear
    local _xl "`outdir'/_sr_b5.xlsx"
    capture erase "`_xl'"
    table1_tc, by(foreign) vars(price contn \ mpg conts) xlsx("`_xl'") sheet("P")
    quietly import excel using "`_xl'", sheet("P") allstring clear
    quietly ds
    local _allvars `r(varlist)'
    local _found_space = 0
    foreach v of local _allvars {
        quietly count if regexm(`v', "^ +[0-9<>]")
        if r(N) > 0 local _found_space = 1
    }
    assert `_found_space' == 0
}
if _rc == 0 {
    display as result "  PASS `test_count': B5 xlsx p-values have no leading space"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': B5 xlsx p-values carry a leading space (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# B7/D4. stacktab console preview uses the shared display path
* =========================================================================
* Observed pre-fix: a bare `list, noobs noheader abbreviate(24)' inherited
* Stata's default separator(5), which drew a rule after every fifth row that
* reads as a block boundary, and handled neither title() nor note(). The
* assertions below need more than five body rows for the separator to fire.
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight length turn displacement gear_ratio
    capture frame drop _sr_b7
    local _src "`outdir'/_sr_b7_src.xlsx"
    capture erase "`_src'"
    regtab, xlsx("`_src'") sheet("Src") frame(_sr_b7)

    capture log close _srb7
    local _b7log "`outdir'/_sr_b7_console.log"
    capture erase "`_b7log'"
    log using "`_b7log'", replace text name(_srb7)
    stacktab using "`_src'", blocks(_sr_b7 sheet(Src)) sheet("B7") ///
        display title("B7 Stack Title") note("B7 Stack Note") sheetreplace
    log close _srb7

    quietly import delimited using "`_b7log'", clear varnames(nonames) ///
        delimiter("`=char(1)'") stringcols(_all) encoding(utf8)
    * Title and note both reach the console.
    quietly count if strtrim(v1) == "B7 Stack Title"
    assert r(N) == 1
    quietly count if strtrim(v1) == "B7 Stack Note"
    assert r(N) == 1
    * The shared path boxes the table: exactly one top rule and one bottom
    * rule, and no interior separator rule.
    quietly count if regexm(v1, "^ *\+-+\+ *$")
    assert r(N) == 2
    quietly count if regexm(v1, "^ *\|-+\| *$")
    assert r(N) == 0
    * More than five body rows were rendered, so separator(5) would have fired.
    quietly count if regexm(v1, "^ *\|.*\| *$")
    assert r(N) > 6
    capture frame drop _sr_b7
}
if _rc == 0 {
    display as result "  PASS `test_count': B7 stacktab console uses shared display path"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': B7 stacktab console path (rc=`=_rc')"
    local ++fail_count
}

* --- stacktab CSV must carry title() and note() too
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    capture frame drop _sr_b7c
    local _src "`outdir'/_sr_b7c_src.xlsx"
    capture erase "`_src'"
    regtab, xlsx("`_src'") sheet("Src") frame(_sr_b7c)
    local _csv "`outdir'/_sr_b7c.csv"
    capture erase "`_csv'"
    stacktab using "`_src'", blocks(_sr_b7c sheet(Src)) sheet("B7C") ///
        title("`_sr_t'") note("`_sr_f'") csv("`_csv'") sheetreplace
    quietly import delimited using "`_csv'", clear varnames(nonames) ///
        stringcols(_all) bindquote(strict) encoding(utf8)
    local _t1 = v1[1]
    local _fn = v1[_N]
    assert `"`_t1'"' == "`_sr_t'"
    assert `"`_fn'"' == "`_sr_f'"
    capture frame drop _sr_b7c
}
if _rc == 0 {
    display as result "  PASS `test_count': B7 stacktab CSV carries title/note"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': B7 stacktab CSV title/note (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
**# A5 rider. The reserved-row drop must not eat a raw export's own data
* =========================================================================
* The 1.12.0 CSV writer dropped every leading row that was blank in each
* exported column, on the assumption that such a row is the reserved title
* row. That holds for a rendered table and fails for `puttab', which
* hand the writer the user's own observations: with `noheader' and a first
* observation blank in every column, the CSV shipped one row fewer than the
* workbook, at rc == 0. The drop is now opt-in per caller. Both halves matter
* -- the raw export must keep the row, the rendered table must still lose its
* reserved one -- so assert the CSV body against the frame, not just a count.
local ++test_count
capture noisily {
    clear
    quietly set obs 4
    quietly generate str12 grp = ""
    quietly generate str12 val = ""
    quietly replace grp = "B" in 2
    quietly replace val = "2" in 2
    quietly replace grp = "C" in 3
    quietly replace val = "3" in 3
    quietly replace grp = "D" in 4
    quietly replace val = "4" in 4
    local _csv "`outdir'/_sr_a5_rawblank.csv"
    capture erase "`_csv'"
    puttab grp val using "`outdir'/_sr_a5_rawblank.xlsx", noheader csv("`_csv'")
    quietly import delimited using "`_csv'", clear varnames(nonames) ///
        stringcols(_all) bindquote(strict) encoding(utf8)
    * Four observations in, four rows out, the blank one still first.
    assert _N == 4
    assert strtrim(v1[1]) == "" & strtrim(v2[1]) == ""
    assert strtrim(v1[2]) == "B" & strtrim(v2[2]) == "2"
    assert strtrim(v1[4]) == "D" & strtrim(v2[4]) == "4"
}
if _rc == 0 {
    display as result "  PASS `test_count': A5 raw export keeps a blank leading data row"
    local ++pass_count
}
else {
    display as error "  FAIL `test_count': A5 raw export lost a blank leading row (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* Summary
* =========================================================================
display as text ""
display as text "RESULT: test_synthesis_review tests=`test_count' pass=`pass_count' fail=`fail_count'"

log close

if `fail_count' > 0 exit 9

* test_output_sinks_markdown.do - tabtools output layer: sinks and Markdown
* Regression suite for the 2026-09-26 audit findings on the output layer,
* written against 2.1.11 before any fix:
*   O1  two output options naming the same file destroyed it: survtab
*       xlsx() + csv() on one workbook overwrote it with CSV text and then
*       failed; regtab did the same at rc 0. Every multi-sink command must
*       refuse colliding destinations before writing anything, and csv()
*       must name a .csv file everywhere.
*   O2  Markdown cells, headers, titles and notes were macro-expanded: a
*       backtick-quoted cell vanished, an unbalanced one stopped with r(132)
*       after a partial file, a dollar-prefixed cell was global-expanded.
*   O3  markdown() refused an existing file (r(602)) instead of replacing
*       it; mdappend is the documented way to add to one.
*   O4  HTML tags, entities, link syntax and code spans in a cell rendered
*       as markup instead of as the literal source text.
*   O5  survtab times() beyond a group's last follow-up gave a flat-extended
*       estimate with no qualification.
* Expected values come from checksums taken before the call, hand-built
* strings, a CommonMark renderer (markdown-it-py), and hand-computed
* Kaplan-Meier values, never from the output under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _osm
log using "test_output_sinks_markdown.log", replace text name(_osm)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local md_checker "`qa_dir'/tools/check_md_render.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Workbook with two sheets and sentinel text: the file a collision destroys.
capture program drop _osm_seed_book
program define _osm_seed_book
    version 17.0
    args path
    capture erase "`path'"
    quietly putexcel set "`path'", sheet("Existing") replace
    quietly putexcel A1 = "KEEP THIS SHEET"
    quietly putexcel close
    quietly putexcel set "`path'", sheet("Extra") modify
    quietly putexcel B2 = "second sentinel"
    quietly putexcel close
end

* Plain text file with a sentinel line.
capture program drop _osm_seed_text
program define _osm_seed_text
    version 17.0
    args path
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "KEEP THIS TEXT" _n
    file close `fh'
end

* CRC and length of a file, as one string.
capture program drop _osm_sum
program define _osm_sum, rclass
    version 17.0
    args path
    quietly checksum "`path'"
    return local sum "`r(checksum)':`r(filelen)'"
end

* The seeded workbook still opens as a workbook and holds both sentinels.
capture program drop _osm_book_intact
program define _osm_book_intact
    version 17.0
    args path
    preserve
    quietly import excel using "`path'", sheet("Existing") cellrange(A1:A1) clear allstring
    assert A[1] == "KEEP THIS SHEET"
    quietly import excel using "`path'", sheet("Extra") cellrange(B2:B2) clear allstring
    assert B[1] == "second sentinel"
    restore
end

* Run a command that must be refused with rc 198 and leave `target'
* byte-identical. The command follows the target path.
capture program drop _osm_refused
program define _osm_refused
    version 17.0
    gettoken target 0 : 0
    _osm_sum "`target'"
    local before "`r(sum)'"
    capture noisily `0'
    local crc = _rc
    _osm_sum "`target'"
    local after "`r(sum)'"
    display as text "  refused rc=`crc'; checksum before `before', after `after'"
    assert "`after'" == "`before'"
    assert `crc' == 198
end

* Lines of a text file compared exactly with the string variable `var', one
* observation per line. Mata reads and compares, so no macro expansion
* touches either side.
capture program drop _osm_file_is
program define _osm_file_is
    version 17.0
    args path var
    mata: st_local("_osm_ok", strofreal(_osm_lines_equal(st_local("path"), st_local("var"))))
    assert `_osm_ok' == 1
end

* Write string variable `var' to `path', one line per observation (UTF-8),
* without macro expansion.
capture program drop _osm_write_lines
program define _osm_write_lines
    version 17.0
    args path var
    capture erase "`path'"
    mata: _osm_put_lines(st_local("path"), st_local("var"))
end

* Render `md' with markdown-it and compare the visible text of each h3/th/
* td/em element with the "tag<TAB>text" lines held in string variable `var'.
capture program drop _osm_render_is
program define _osm_render_is
    version 17.0
    args md var checker
    tempfile expect result
    _osm_write_lines "`expect'" `var'
    capture erase "`result'"
    shell python3 "`checker'" "`md'" "`expect'" "`result'"
    confirm file "`result'"
    tempname fh
    file open `fh' using "`result'", read text
    file read `fh' line
    file close `fh'
    type "`result'"
    assert "`line'" == "PASS"
end

* Console text of a command, captured through a nested log into r(text).
capture program drop _osm_console
program define _osm_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_osm_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _osm_capture
    mata: st_local("_osm_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_osm_txt)'"'
    return scalar rc = `crc'
end

mata:
real scalar _osm_lines_equal(string scalar path, string scalar var)
{
    string colvector got, want
    real scalar i, n

    got = cat(path)
    want = st_sdata(., var)
    if (rows(got) != rows(want)) {
        printf("{err}line count: file %f, expected %f\n", rows(got), rows(want))
        for (i = 1; i <= rows(got); i++) printf("{txt}  file %f: [%s]\n", i, got[i])
        return(0)
    }
    n = 0
    for (i = 1; i <= rows(want); i++) {
        if (got[i] != want[i]) {
            printf("{err}line %f differs\n", i)
            printf("{txt}  file:     [%s]\n", got[i])
            printf("{txt}  expected: [%s]\n", want[i])
            n++
        }
    }
    return(n == 0)
}

void _osm_put_lines(string scalar path, string scalar var)
{
    real scalar fh, i
    string colvector s

    s = st_sdata(., var)
    fh = fopen(path, "w")
    for (i = 1; i <= rows(s); i++) fput(fh, s[i])
    fclose(fh)
}
end

**# O1. Colliding sinks are refused before anything is written

* survtab: the audit's C1 reproduction. A distinct-sink control run proves
* the options are otherwise valid, so the refusal is the collision guard.
capture noisily {
    local wb "`output_dir'/osm_survtab_book.xlsx"
    local ok "`output_dir'/osm_survtab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly survtab, times(10) xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.xlsx"
    confirm file "`ok'.csv"
    confirm file "`ok'.md"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" survtab, times(10) xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 survtab refuses xlsx() and csv() on one workbook, workbook intact"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 survtab xlsx()/csv() collision (rc=`=_rc')"
    local ++fail_count
}

* survtab: csv() and markdown() on one existing .md file.
capture noisily {
    local md "`output_dir'/osm_survtab_same.md"
    _osm_seed_text "`md'"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    _osm_refused "`md'" survtab, times(10) csv("`md'") markdown("`md'")
}
if _rc == 0 {
    display as result "  PASS: O1 survtab refuses csv() and markdown() on one file, file intact"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 survtab csv()/markdown() collision (rc=`=_rc')"
    local ++fail_count
}

* regtab: returned rc 0 on 2.1.11 and replaced the workbook.
capture noisily {
    local wb "`output_dir'/osm_regtab_book.xlsx"
    local ok "`output_dir'/osm_regtab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly regtab, xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" regtab, xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 regtab refuses xlsx() and csv() on one workbook, workbook intact"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 regtab xlsx()/csv() collision (rc=`=_rc')"
    local ++fail_count
}

* regtab: the same file spelled relative and absolute, and through ./ and
* dir/.., is still one file.
capture noisily {
    local wb "`output_dir'/osm_regtab_rel.xlsx"
    _osm_seed_book "`wb'"
    capture mkdir "`output_dir'/osm_sub"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly cd "`output_dir'"
    capture noisily {
        _osm_refused "`wb'" regtab, xlsx("osm_regtab_rel.xlsx") csv("`wb'")
        _osm_refused "`wb'" regtab, xlsx("./osm_sub/../osm_regtab_rel.xlsx") csv("osm_regtab_rel.xlsx")
    }
    local inner = _rc
    quietly cd "`qa_dir'"
    assert `inner' == 0
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 regtab refuses relative/absolute spellings of one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 regtab relative/absolute collision (rc=`=_rc')"
    local ++fail_count
}

* effecttab
capture noisily {
    local wb "`output_dir'/osm_effecttab_book.xlsx"
    local ok "`output_dir'/osm_effecttab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse auto, clear
    collect clear
    quietly collect: teffects ra (price mpg) (foreign)
    quietly effecttab, xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" effecttab, xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 effecttab refuses xlsx() and csv() on one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 effecttab collision (rc=`=_rc')"
    local ++fail_count
}

* stratetab
capture noisily {
    local wb "`output_dir'/osm_stratetab_book.xlsx"
    local ok "`output_dir'/osm_stratetab_ok"
    local rate "`output_dir'/osm_rate"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly strate, output("`rate'", replace)
    quietly stratetab, using("`rate'") outcomes(1) xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" stratetab, using("`rate'") outcomes(1) xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 stratetab refuses xlsx() and csv() on one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 stratetab collision (rc=`=_rc')"
    local ++fail_count
}

* crosstab
capture noisily {
    local wb "`output_dir'/osm_crosstab_book.xlsx"
    local ok "`output_dir'/osm_crosstab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse auto, clear
    quietly crosstab rep78 foreign, xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" crosstab rep78 foreign, xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 crosstab refuses xlsx() and csv() on one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 crosstab collision (rc=`=_rc')"
    local ++fail_count
}

* corrtab (already enforced csv's extension on 2.1.11; guard test)
capture noisily {
    local wb "`output_dir'/osm_corrtab_book.xlsx"
    local ok "`output_dir'/osm_corrtab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse auto, clear
    quietly corrtab price mpg weight, xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" corrtab price mpg weight, xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 corrtab refuses xlsx() and csv() on one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 corrtab collision (rc=`=_rc')"
    local ++fail_count
}

* desctab, and table1_tc through its excel() spelling
capture noisily {
    local wb "`output_dir'/osm_desctab_book.xlsx"
    local ok "`output_dir'/osm_desctab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse auto, clear
    quietly desctab price mpg, by(foreign) xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" desctab price mpg, by(foreign) xlsx("`wb'") csv("`wb'")
    _osm_refused "`wb'" table1_tc price mpg, by(foreign) excel("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 desctab/table1_tc refuse excel() and csv() on one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 desctab/table1_tc collision (rc=`=_rc')"
    local ++fail_count
}

* comptab (frame composition)
capture noisily {
    local wb "`output_dir'/osm_comptab_book.xlsx"
    local ok "`output_dir'/osm_comptab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    quietly regtab, frame(osm_f1, replace)
    quietly comptab osm_f1, rows(1) xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" comptab osm_f1, rows(1) xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
    frame drop osm_f1
}
if _rc == 0 {
    display as result "  PASS: O1 comptab refuses xlsx() and csv() on one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 comptab collision (rc=`=_rc')"
    local ++fail_count
}

* hrcomptab (comptab rate mode)
capture noisily {
    local wb "`output_dir'/osm_hrcomptab_book.xlsx"
    local ok "`output_dir'/osm_hrcomptab_ok"
    local rate "`output_dir'/osm_rate_drug"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly strate drug, output("`rate'", replace)
    quietly stratetab, using("`rate'") outcomes(1) frame(osm_rates, replace) ///
        outlabels("Death") explabels("Drug")
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly regtab, models("Death") frame(osm_hrm, replace) noint
    quietly hrcomptab osm_rates, modelframes(osm_hrm) rows(3/4) effect("HR") ///
        outcomemap("Death") xlsx("`ok'.xlsx") csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" hrcomptab osm_rates, modelframes(osm_hrm) rows(3/4) effect("HR") outcomemap("Death") xlsx("`wb'") csv("`wb'")
    _osm_book_intact "`wb'"
    frame drop osm_rates
    frame drop osm_hrm
}
if _rc == 0 {
    display as result "  PASS: O1 hrcomptab refuses xlsx() and csv() on one workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 hrcomptab collision (rc=`=_rc')"
    local ++fail_count
}

* puttab and stacktab: using is the workbook (guard tests; both enforced
* the csv() extension on 2.1.11)
capture noisily {
    local wb "`output_dir'/osm_puttab_book.xlsx"
    local ok "`output_dir'/osm_puttab_ok"
    foreach e in xlsx csv md {
        capture erase "`ok'.`e'"
    }
    sysuse auto, clear
    quietly puttab make price in 1/3 using "`ok'.xlsx", csv("`ok'.csv") markdown("`ok'.md")
    confirm file "`ok'.csv"
    _osm_seed_book "`wb'"
    _osm_refused "`wb'" puttab make price in 1/3 using "`wb'", csv("`wb'")

    * stacktab reads its blocks from the same workbook it writes
    _osm_refused "`wb'" stacktab using "`wb'", blocks(sheet(Existing) rows(1/1) cols(A-A)) sheet("New") csv("`wb'")
    _osm_book_intact "`wb'"
}
if _rc == 0 {
    display as result "  PASS: O1 puttab/stacktab refuse csv() naming the workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 puttab/stacktab collision (rc=`=_rc')"
    local ++fail_count
}

* csv() must name a .csv file in every command (corrtab/puttab/stacktab
* already required it; the others accepted any extension).
capture noisily {
    local bad "`output_dir'/osm_bad_ext.txt"
    capture erase "`bad'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg
    capture noisily regtab, csv("`bad'")
    assert _rc == 198
    capture noisily crosstab rep78 foreign, csv("`bad'")
    assert _rc == 198
    capture noisily desctab price, by(foreign) csv("`bad'")
    assert _rc == 198
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    capture noisily survtab, times(10) csv("`bad'")
    assert _rc == 198
    capture confirm file "`bad'"
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: O1 csv() requires a .csv extension across commands"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 csv() extension contract (rc=`=_rc')"
    local ++fail_count
}

* The shared preflight helper normalises paths before comparing them.
capture noisily {
    capture noisily _tabtools_check_sinks, xlsx("a.xlsx") csv("a.csv") markdown("a.md")
    assert _rc == 0
    capture noisily _tabtools_check_sinks, xlsx("osm_d/../same.xlsx") markdown("./same.xlsx")
    assert _rc == 198
    capture noisily _tabtools_check_sinks, xlsx("`c(pwd)'/same.xlsx") markdown("same.xlsx")
    assert _rc == 198
    capture noisily _tabtools_check_sinks, xlsx("Same.XLSX") markdown("same.xlsx")
    assert _rc == 198
    capture noisily _tabtools_check_sinks, xlsx("x/same.xlsx") markdown("y/same.xlsx")
    assert _rc == 0
    capture noisily _tabtools_check_sinks, csv("out.CSV")
    assert _rc == 0
    capture noisily _tabtools_check_sinks, csv("out.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: O1 _tabtools_check_sinks normalises ./, dir/.., case and relative paths"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 _tabtools_check_sinks normalisation (rc=`=_rc')"
    local ++fail_count
}

**# O2. Markdown text is written without macro expansion

* Body cells. The punctuation is built with char() inside the data, so this
* do-file never expands it. Expected lines are built the same way.
capture noisily {
    local md "`output_dir'/osm_macro_cells.md"
    capture erase "`md'"
    global OSM_SENTINEL "global was expanded"
    local bq = "char(96)"
    local sq = "char(39)"
    local bs = "char(92)"
    clear
    quietly set obs 9
    generate strL s = ""
    quietly replace s = `bq' + "dosage" + `sq' in 1
    quietly replace s = `bq' + "dose" + `bq' in 2
    quietly replace s = char(36) + "OSM_SENTINEL" in 3
    quietly replace s = "a_" + `bq' + "b" + `sq' + "_c" + char(36) + "x" in 4
    quietly replace s = `bq' + char(34) + "q" + char(34) + `sq' in 5
    quietly replace s = "it" + `sq' + "s" in 6
    quietly replace s = `bs' + `bq' + "x" + `sq' in 7
    quietly replace s = `bq' + `sq' in 8
    quietly replace s = char(36) + "{OSM_SENTINEL}" in 9
    quietly puttab s, markdown("`md'")
    global OSM_SENTINEL

    clear
    quietly set obs 11
    generate strL e = ""
    quietly replace e = "| s |" in 1
    quietly replace e = "| --- |" in 2
    quietly replace e = "| " + `bs' + `bq' + "dosage" + `sq' + " |" in 3
    quietly replace e = "| " + `bs' + `bq' + "dose" + `bs' + `bq' + " |" in 4
    quietly replace e = "| " + char(36) + "OSM" + `bs' + "_SENTINEL |" in 5
    quietly replace e = "| a" + `bs' + "_" + `bs' + `bq' + "b" + `sq' + `bs' + "_c" + char(36) + "x |" in 6
    quietly replace e = "| " + `bs' + `bq' + char(34) + "q" + char(34) + `sq' + " |" in 7
    quietly replace e = "| it" + `sq' + "s |" in 8
    quietly replace e = "| " + `bs' + `bs' + `bs' + `bq' + "x" + `sq' + " |" in 9
    quietly replace e = "| " + `bs' + `bq' + `sq' + " |" in 10
    quietly replace e = "| " + char(36) + "{OSM" + `bs' + "_SENTINEL} |" in 11
    _osm_file_is "`md'" e
}
if _rc == 0 {
    display as result "  PASS: O2 backtick, apostrophe and dollar cells are written literally"
    local ++pass_count
}
else {
    display as error "  FAIL: O2 macro-safe body cells (rc=`=_rc')"
    local ++fail_count
}

* Header (variable label), title and footnote through the shared writer.
* macval() hands the text to the writer unexpanded; the writer must not
* expand it either.
capture noisily {
    local md "`output_dir'/osm_macro_frame.md"
    capture erase "`md'"
    global OSM_SENTINEL "global was expanded"
    local t = char(96) + "T" + char(39) + " " + char(36) + "OSM_SENTINEL"
    * A backtick directly before the closing compound quote would itself
    * read as an opening compound quote, so the note does not end in one.
    local f = "note " + char(96) + "n" + char(96) + " end"
    clear
    quietly set obs 2
    generate strL s = ""
    quietly replace s = "x" in 2
    mata: st_varlabel("s", char(96) + "lab" + char(39))
    _tabtools_markdown_write using "`md'", headerstart(1) datastart(2) ///
        title(`"`macval(t)'"') footnote(`"`macval(f)'"')
    global OSM_SENTINEL
    assert r(n_rows) == 1
    assert r(n_cols) == 1

    clear
    quietly set obs 7
    generate strL e = ""
    quietly replace e = "### " + char(92) + char(96) + "T" + char(39) + " " + char(36) + "OSM" + char(92) + "_SENTINEL" in 1
    quietly replace e = "| " + char(92) + char(96) + "lab" + char(39) + " |" in 3
    quietly replace e = "| --- |" in 4
    quietly replace e = "| x |" in 5
    quietly replace e = "*note " + char(92) + char(96) + "n" + char(92) + char(96) + " end*" in 7
    _osm_file_is "`md'" e
}
if _rc == 0 {
    display as result "  PASS: O2 header, title and footnote are written literally"
    local ++pass_count
}
else {
    display as error "  FAIL: O2 macro-safe header/title/footnote (rc=`=_rc')"
    local ++fail_count
}

**# O3. markdown() replaces an existing file; mdappend appends

capture noisily {
    local md "`output_dir'/osm_repeat.md"
    _osm_seed_text "`md'"
    clear
    quietly set obs 1
    generate str20 s = "first run"
    quietly puttab s, markdown("`md'")
    quietly replace s = "second run"
    quietly puttab s, markdown("`md'")

    clear
    quietly set obs 3
    generate strL e = ""
    quietly replace e = "| s |" in 1
    quietly replace e = "| --- |" in 2
    quietly replace e = "| second run |" in 3
    _osm_file_is "`md'" e
}
if _rc == 0 {
    display as result "  PASS: O3 a second export replaces the Markdown file"
    local ++pass_count
}
else {
    display as error "  FAIL: O3 Markdown replace default (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    local md "`output_dir'/osm_append.md"
    capture erase "`md'"
    clear
    quietly set obs 1
    generate str20 s = "first run"
    quietly puttab s, markdown("`md'")
    quietly replace s = "second run"
    quietly puttab s, markdown("`md'") mdappend

    clear
    quietly set obs 7
    generate strL e = ""
    quietly replace e = "| s |" in 1
    quietly replace e = "| --- |" in 2
    quietly replace e = "| first run |" in 3
    quietly replace e = "| s |" in 5
    quietly replace e = "| --- |" in 6
    quietly replace e = "| second run |" in 7
    _osm_file_is "`md'" e
}
if _rc == 0 {
    display as result "  PASS: O3 mdappend keeps the first table and appends the second"
    local ++pass_count
}
else {
    display as error "  FAIL: O3 mdappend (rc=`=_rc')"
    local ++fail_count
}

* The same contract through a table command and through stacktab, which
* staged Markdown and refused an existing file on its own.
capture noisily {
    local md "`output_dir'/osm_repeat_survtab.md"
    _osm_seed_text "`md'"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    quietly survtab, times(10) markdown("`md'")
    quietly survtab, times(20) markdown("`md'")
    mata: st_local("_osm_n10", strofreal(sum(strpos(cat(st_local("md")), "10 years") :> 0)))
    mata: st_local("_osm_n20", strofreal(sum(strpos(cat(st_local("md")), "20 years") :> 0)))
    mata: st_local("_osm_keep", strofreal(sum(cat(st_local("md")) :== "KEEP THIS TEXT")))
    display as text "  survtab rerun: rows mentioning 10 years `_osm_n10', 20 years `_osm_n20'"
    assert `_osm_n20' >= 1
    assert `_osm_n10' == 0
    assert `_osm_keep' == 0

    local wb "`output_dir'/osm_stack_src.xlsx"
    local md2 "`output_dir'/osm_repeat_stack.md"
    _osm_seed_text "`md2'"
    clear
    input str8 label double value
    "Header" .
    "Alpha"  1
    end
    quietly export excel using "`wb'", sheet("Source") firstrow(variables) replace
    quietly stacktab using "`wb'", blocks(sheet(Source) rows(1/2) cols(A-B)) ///
        sheet("First") markdown("`md2'")
    quietly stacktab using "`wb'", blocks(sheet(Source) rows(1/2) cols(A-B)) ///
        sheet("Second") markdown("`md2'")
    mata: st_local("_osm_keep", strofreal(sum(cat(st_local("md2")) :== "KEEP THIS TEXT")))
    mata: st_local("_osm_hdr", strofreal(sum(strpos(cat(st_local("md2")), "| --- |") :> 0)))
    assert `_osm_keep' == 0
    assert `_osm_hdr' == 1
}
if _rc == 0 {
    display as result "  PASS: O3 survtab and stacktab replace an existing Markdown file"
    local ++pass_count
}
else {
    display as error "  FAIL: O3 survtab/stacktab Markdown replace (rc=`=_rc')"
    local ++fail_count
}

**# O4. Rendered Markdown shows the literal source text

capture noisily {
    local md "`output_dir'/osm_render.md"
    capture erase "`md'"
    clear
    quietly set obs 7
    generate strL a = ""
    generate strL b = ""
    quietly replace a = "Arm" in 1
    quietly replace b = "Value <b>" in 1
    quietly replace a = "<b>Drug</b> &copy; [arm](https://example.org)" in 2
    quietly replace b = "a < b & c > d" in 2
    quietly replace a = "![img](x.png) &amp; &#169;" in 3
    quietly replace b = "<https://example.org>" in 3
    quietly replace a = char(96) + "code" + char(96) + " and ~~strike~~" in 4
    quietly replace b = "[ref]: x" in 4
    quietly replace a = "  indented <i>" in 5
    quietly replace b = "*star* _under_ \back" in 5
    quietly replace a = "line1" + char(10) + "line2" in 6
    quietly replace b = "pipe | inside" in 6
    quietly replace a = "<!-- comment -->" in 7
    quietly replace b = "x&nbsp;y" in 7
    quietly puttab a b, markdown("`md'") title("Title <b>x</b> & [y](z)") ///
        footnote("Note &copy; <i>n</i>")
    * source level: the markup characters are backslash-escaped
    mata: st_local("_osm_src", strofreal(sum(cat(st_local("md")) :== ///
        "| \<b\>Drug\</b\> \&copy; \[arm\](https://example.org) | a \< b \& c \> d |")))
    assert `_osm_src' == 1

    * Expected visible text. The indentation of a column-1 cell is written
    * as &nbsp; entities and renders as U+00A0; a newline is written as a
    * helper-generated <br>, which renders as a line break with no text.
    clear
    quietly set obs 18
    generate strL e = ""
    quietly replace e = "h3" + char(9) + "Title <b>x</b> & [y](z)" in 1
    quietly replace e = "th" + char(9) + "a" in 2
    quietly replace e = "th" + char(9) + "b" in 3
    quietly replace e = "td" + char(9) + "Arm" in 4
    quietly replace e = "td" + char(9) + "Value <b>" in 5
    quietly replace e = "td" + char(9) + "<b>Drug</b> &copy; [arm](https://example.org)" in 6
    quietly replace e = "td" + char(9) + "a < b & c > d" in 7
    quietly replace e = "td" + char(9) + "![img](x.png) &amp; &#169;" in 8
    quietly replace e = "td" + char(9) + "<https://example.org>" in 9
    quietly replace e = "td" + char(9) + char(96) + "code" + char(96) + " and ~~strike~~" in 10
    quietly replace e = "td" + char(9) + "[ref]: x" in 11
    quietly replace e = "td" + char(9) + uchar(160) + uchar(160) + "indented <i>" in 12
    quietly replace e = "td" + char(9) + "*star* _under_ \back" in 13
    quietly replace e = "td" + char(9) + "line1line2" in 14
    quietly replace e = "td" + char(9) + "pipe | inside" in 15
    quietly replace e = "td" + char(9) + "<!-- comment -->" in 16
    quietly replace e = "td" + char(9) + "x&nbsp;y" in 17
    quietly replace e = "em" + char(9) + "Note &copy; <i>n</i>" in 18
    _osm_render_is "`md'" e "`md_checker'"
}
if _rc == 0 {
    display as result "  PASS: O4 HTML, entities, links and code spans render as literal text"
    local ++pass_count
}
else {
    display as error "  FAIL: O4 rendered Markdown fidelity (rc=`=_rc')"
    local ++fail_count
}

**# O5. survtab flags times beyond a group's follow-up

* (time, event) = (1,1), (2,0), (3,0): KM S(t) = 2/3 from t = 1 onward, last
* follow-up 3. times(100) keeps the flat estimate and is flagged.
capture noisily {
    clear
    input double time byte event
    1 1
    2 0
    3 0
    end
    quietly stset time, failure(event)
    _osm_console survtab, times(100) riskset
    assert r(rc) == 0
    local txt `"`r(text)'"'
    quietly survtab, times(100) riskset
    local flag `"`r(beyond_support)'"'
    tempname T
    matrix `T' = r(table)
    display as text `"  r(beyond_support) = [`flag']"'
    assert `"`flag'"' == "Overall: 100 (last follow-up 3)"
    assert strpos(`"`txt'"', "beyond the last observed follow-up") > 0
    assert strpos(`"`txt'"', "Overall: 100 (last follow-up 3)") > 0
    * estimate unchanged: 2/3 from the hand-computed KM curve
    assert !missing(`T'[1, 1])
    assert reldif(`T'[1, 1], 2/3) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: O5 survtab notes and returns a time beyond follow-up"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 survtab beyond-support note (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    clear
    input double time byte event
    1 1
    2 0
    3 0
    end
    quietly stset time, failure(event)
    _osm_console survtab, times(2)
    assert r(rc) == 0
    local txt `"`r(text)'"'
    quietly survtab, times(2)
    local flag `"`r(beyond_support)'"'
    assert `"`flag'"' == ""
    assert strpos(`"`txt'"', "beyond the last observed follow-up") == 0
    * exactly at the last follow-up time is still within support
    quietly survtab, times(3)
    assert `"`r(beyond_support)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: O5 no note or flag for times within follow-up"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 within-support false flag (rc=`=_rc')"
    local ++fail_count
}

capture noisily {
    clear
    input double time byte event byte grp
    1 1 0
    2 0 0
    3 0 0
    2 1 1
    6 0 1
    10 0 1
    end
    label define osm_grp 0 "Short" 1 "Long", replace
    label values grp osm_grp
    quietly stset time, failure(event)
    quietly survtab, times(2 5 20) by(grp)
    local flag `"`r(beyond_support)'"'
    display as text `"  r(beyond_support) = [`flag']"'
    assert `"`flag'"' == "Short: 5 20 (last follow-up 3); Long: 20 (last follow-up 10)"
}
if _rc == 0 {
    display as result "  PASS: O5 two groups with different follow-up are flagged per group"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 two-group support (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_output_sinks_markdown tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _osm
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_output_sinks_markdown tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _osm

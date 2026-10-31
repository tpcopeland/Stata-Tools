* test_latex_direct.do - tabtools: latex()/texappend through puttab, outtab and stacktab
* (_take_action/tabtools_latex_export_2026-10-31.md, wave 2b)
*   D1  puttab varlist: every sink from one call, parity with the CSV
*   D2  puttab spanheader(): real span row, spans equal the workbook's merges
*   D3  puttab blockheader: spans from a regtab flat frame
*   D4  puttab panel(), boldrows(): bold rows agree with the workbook
*   D5  puttab panelheader()/panelinline/noheader: no LaTeX header block
*   D6  puttab matrix() and frame() sources, noembedheader, varlabels
*   D7  puttab keepblank: a blank data row is a body row in both outputs
*   D8  puttab texappend: replace, append, labels, create-on-append
*   D9  puttab session sink (tabtools set latex): replace then append
*   D10 puttab refusals leave a pre-seeded target intact
*   D11 puttab failed LaTeX write keeps the analytical r()
*   D12 outtab: every sink, panel heading rows bold in LaTeX and workbook
*   D13 outtab texappend, refusal, failed write
*   D14 stacktab blocks(): every sink, label stem, no stage leftovers
*   D15 stacktab texappend and the session sink
*   D16 stacktab: a failed LaTeX write or a late failure touches nothing
*   D17 stacktab frames(): panels bold, texappend, session sink
* Expected values come from the command's other outputs (CSV, Markdown,
* workbook read back with openpyxl, r()) and hand-built strings, never from
* the .tex under test alone; check_latex.py compiles every table with
* pdflatex on the documented minimal preamble.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _ld
log using "test_latex_direct.log", replace text name(_ld)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global LD_CHECKER "`qa_dir'/tools/check_latex.py"
global LD_ND "`output_dir'/ld_needles.txt"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/ld_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* CRC and length of a file, as one string ("absent" when there is none).
capture program drop _ld_sum
program define _ld_sum, rclass
    version 17.0
    args path
    capture confirm file "`path'"
    if _rc {
        return local sum "absent"
        exit
    }
    quietly checksum "`path'"
    return local sum "`r(checksum)':`r(filelen)'"
end

* Plain text file with a sentinel line.
capture program drop _ld_seed_text
program define _ld_seed_text
    version 17.0
    args path
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "KEEP THIS TEXT" _n
    file close `fh'
end

* Needle file for check_latex.py: _ld_nd reset | _ld_nd kind text. Text
* with a backslash or brace never passes through the shell this way.
capture program drop _ld_nd
program define _ld_nd
    version 17.0
    gettoken kind 0 : 0
    if "`kind'" == "reset" {
        capture erase "$LD_ND"
        exit
    }
    local text `0'
    mata: _ld_fh = fopen(st_global("LD_ND"), "a"); ///
        fput(_ld_fh, st_local("kind") + char(9) + st_local("text")); ///
        fclose(_ld_fh)
end

* check_latex.py on a .tex file with the options that follow it; any needles
* queued with _ld_nd are passed and cleared. The verdict must start with PASS.
capture program drop _ld_check
program define _ld_check
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    local nd ""
    capture confirm file "$LD_ND"
    if !_rc local nd `"--needles "$LD_ND""'
    shell python3 "$LD_CHECKER" "`tex'" `0' `nd' --result "`res'"
    capture erase "$LD_ND"
    confirm file "`res'"
    mata: printf("{txt}  check_latex: %s\n", cat(st_local("res"))[1])
    mata: st_local("_ld_ok", strofreal(substr(cat(st_local("res"))[1], 1, 4) == "PASS"))
    assert `_ld_ok' == 1
end

* Lines of a text file containing a literal substring, in r(n).
capture program drop _ld_count
program define _ld_count, rclass
    version 17.0
    args file needle
    mata: st_local("_ld_n", strofreal(sum(strpos(cat(st_local("file")), st_local("needle")) :> 0)))
    return scalar n = `_ld_n'
end

* Number of columns and rows of a CSV file, in r(k) and r(N).
capture program drop _ld_csvdim
program define _ld_csvdim, rclass
    version 17.0
    args file
    tempname fr
    frame create `fr'
    frame `fr' {
        quietly import delimited using "`file'", varnames(nonames) ///
            stringcols(_all) bindquote(strict) clear
        return scalar k = c(k)
        return scalar N = _N
    }
    frame drop `fr'
end

* Console text of a command, captured through a nested log into r(text).
capture program drop _ld_console
program define _ld_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_ld_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _ld_capture
    mata: st_local("_ld_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_ld_txt)'"'
    return scalar rc = `crc'
end

* A command that must be refused with rc 198 and a message containing
* needle, leaving target byte-identical (or absent).
capture program drop _ld_refused
program define _ld_refused
    version 17.0
    gettoken target 0 : 0
    gettoken needle 0 : 0
    _ld_sum "`target'"
    local before "`r(sum)'"
    _ld_console `0'
    local crc = r(rc)
    local txt `"`r(text)'"'
    _ld_sum "`target'"
    local after "`r(sum)'"
    display as text "  refused rc=`crc'; checksum before `before', after `after'"
    assert "`after'" == "`before'"
    assert `crc' == 198
    if `"`needle'"' != "" {
        local hit = strpos(`"`macval(txt)'"', `"`needle'"') > 0
        if !`hit' display as error `"  message lacks: `needle'"'
        assert `hit'
    }
end

* This process's entries (files and directories) in c(tmpdir), in r(tmp).
capture program drop _ld_tmpls
program define _ld_tmpls, rclass
    version 17.0
    tempfile probe
    mata: st_local("pfx", pathbasename(st_local("probe")))
    local pfx = substr("`pfx'", 1, strpos("`pfx'", "."))
    local f : dir "`c(tmpdir)'" files "`pfx'*", respectcase
    local d : dir "`c(tmpdir)'" dirs "`pfx'*", respectcase
    local f : list sort f
    local d : list sort d
    return local tmp `"`f' | `d'"'
end

* The multi-column merged ranges of the workbook row `wbrow' read back by
* _v_facts, as a check_latex.py --spans string (header-block row, first and
* last visible column) in r(spans) and their number in r(n). Workbook column
* B is table column 1 and the header block starts at workbook row 2.
capture program drop _ld_wb_spans
program define _ld_wb_spans, rclass
    version 17.0
    args wbrow
    mata: _ld_wb_spans(st_local("wbrow"))
    return local spans "`_ld_sp'"
    return scalar n = `_ld_nsp'
end

mata:
mata set matastrict off

real scalar _ld_colnum(string scalar s)
{
    real scalar i, n
    n = 0
    for (i = 1; i <= strlen(s); i++) n = n * 26 + ascii(substr(s, i, 1)) - 64
    return(n)
}

void _ld_wb_spans(string scalar wbrow)
{
    string colvector f
    string scalar out, a, b
    real scalar i, n, r1, r2, c1, c2
    f = cat(st_global("V230_RES"))
    out = ""
    n = 0
    for (i = 1; i <= rows(f); i++) {
        if (substr(f[i], 1, 6) != "merge ") continue
        if (!regexm(f[i], "^merge ([A-Z]+)([0-9]+):([A-Z]+)([0-9]+)$")) continue
        c1 = _ld_colnum(regexs(1))
        r1 = strtoreal(regexs(2))
        c2 = _ld_colnum(regexs(3))
        r2 = strtoreal(regexs(4))
        if (r1 != strtoreal(wbrow) | r2 != r1) continue
        out = out + (n ? "," : "") + strofreal(r1 - 1) + ":" + strofreal(c1 - 1) + "-" + strofreal(c2 - 1)
        n++
    }
    st_local("_ld_sp", out)
    st_local("_ld_nsp", strofreal(n))
}

end

* Fixture: Domestic cars sorted before Foreign cars, two of each.
capture program drop _ld_cars4
program define _ld_cars4
    version 17.0
    sysuse auto, clear
    sort foreign make
    bysort foreign (make): keep if _n <= 2
    sort foreign make
end

* Fixture of test_puttab_v250: two panels, per-panel header cells.
capture program drop _ld_blocks
program define _ld_blocks
    version 17.0
    clear
    quietly set obs 3
    quietly gen str20 lab = word("Age<55 Age55+ Repleted", _n)
    quietly replace lab = "Age <55" in 1
    quietly replace lab = "Age 55+" in 2
    quietly gen str8 a = string(1 + 3 * (_n - 1))
    quietly gen str8 b = string(2 + 3 * (_n - 1))
    quietly gen str8 c = string(3 + 3 * (_n - 1))
    quietly gen byte blk = cond(_n <= 2, 1, 2)
    quietly gen str10 h1 = ""
    quietly gen str10 h2 = cond(_n <= 2, "Events", "Scans")
    quietly gen str10 h3 = cond(_n <= 2, "PY", "Pct")
    quietly gen str10 h4 = cond(_n <= 2, "Rate", "RR")
    label define ldblk 1 "A. Relapses" 2 "B. MRI", replace
    label values blk ldblk
    label variable lab "Row"
    label variable a "Col A"
    label variable b "Col B"
    label variable c "Col C"
end

**# D1. puttab varlist: every sink from one call, parity with the CSV
capture noisily {  // stata-dev-ignore: capture-braced-block — _rc is read right after the closing brace; a needle ending in a literal } (e.g. a closing \par}) unbalances the rule's brace count
    local stem "ld_d1"
    local book "`output_dir'/`stem'.xlsx"
    local csv "`output_dir'/`stem'.csv"
    local md "`output_dir'/`stem'.md"
    local tex "`output_dir'/`stem'.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    sysuse auto, clear
    puttab make price mpg weight in 1/6 using "`book'", sheet("D1") ///
        latex("`tex'") markdown("`md'") csv("`csv'") varlabels ///
        title("Auto & co 50%") footnote("Note a \ Note b")
    * the analytical returns: rows = title + header + 6 data + 2 notes
    assert r(n_datarows) == 6 & r(n_rows) == 10
    assert `"`r(latex)'"' == "`tex'"
    assert r(latex_rows) == 6
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 4 & r(latex_cols) == r(markdown_cols)
    _ld_csvdim "`csv'"
    assert r(k) == 4
    _ld_nd contains \caption{Auto \& co 50\%}
    _ld_nd contains \label{tab:ld_d1}
    _ld_nd contains Make and model & Price & Mileage (mpg) & Weight (lbs.) \\
    _ld_nd contains AMC Concord & 4099 & 22 & 2930 \\
    _ld_nd contains AMC Pacer & 4749 & 17 & 3350 \\
    _ld_nd contains Buick LeSabre & 5788 & 18 & 3670 \\
    _ld_nd contains Note a\par
    _ld_nd contains Note b\par}
    _ld_nd pdftext Auto & co 50%
    _ld_nd pdftext Make and model
    _ld_nd pdftext Mileage (mpg)
    _ld_check "`tex'" --compile --cols 4 --header-rows 1 --body-rows 6 ///
        --spans none --parity-csv "`csv'" --csv-rows 3:8
    * the workbook holds the same body: first and last data cells
    _v_facts "`book'" "D1"
    _v_value B3 "AMC Concord"
    _v_value C3 "4099"
    _v_value B8 "Buick LeSabre"
    _v_value E8 "3670"
}
if _rc == 0 {
    display as result "  PASS: D1 puttab varlist: all sinks, returns, CSV parity, compiles"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 puttab varlist (rc=`=_rc')"
    local ++fail_count
}

**# D2. puttab spanheader(): the real span row, spans equal the workbook merges
capture noisily {
    local stem "ld_d2"
    local book "`output_dir'/`stem'.xlsx"
    local csv "`output_dir'/`stem'.csv"
    local md "`output_dir'/`stem'.md"
    local tex "`output_dir'/`stem'.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    sysuse auto, clear
    puttab make price mpg weight length in 1/6 using "`book'", sheet("D2") ///
        latex("`tex'") markdown("`md'") csv("`csv'") varlabels ///
        spanheader("Cost" 2/3 \ "Size" 4/5) title("Spans") ///
        footnote("Source: auto.dta")
    assert r(n_spans) == 2 & r(n_datarows) == 6
    assert r(latex_rows) == 6 & r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 5 & r(markdown_cols) == 5
    * workbook merges, read back with openpyxl, are the oracle for the spans
    _v_facts "`book'" "D2"
    _ld_wb_spans 2
    assert r(n) == 2
    local wbspans "`r(spans)'"
    assert "`wbspans'" == "1:2-3,1:4-5"
    * Markdown folds the span label into each column header; LaTeX must not
    _v_line "`md'" "| Make and model | Cost, Price | Cost, Mileage (mpg) | Size, Weight (lbs.) | Size, Length (in.) |" 1
    _ld_nd absent Cost, Price
    _ld_nd absent Size, Weight
    _ld_nd contains  & \multicolumn{2}{c}{Cost} & \multicolumn{2}{c}{Size} \\
    _ld_nd contains \cmidrule(lr){2-3} \cmidrule(lr){4-5}
    _ld_nd contains Make and model & Price & Mileage (mpg) & Weight (lbs.) & Length (in.) \\
    _ld_nd pdftext Cost
    _ld_nd pdftext Size
    _ld_nd pdftext Mileage (mpg)
    _ld_check "`tex'" --compile --cols 5 --header-rows 2 --body-rows 6 ///
        --spans "`wbspans'" --parity-csv "`csv'" --csv-rows 4:9
    _ld_count "`tex'" "\midrule"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: D2 puttab spanheader(): two header rows, spans = workbook merges, Markdown flattening not seen"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 puttab spanheader() (rc=`=_rc')"
    local ++fail_count
}

**# D2b. a one-column span and a gap: declared, not inferred from blanks
capture noisily {
    local stem "ld_d2b"
    local book "`output_dir'/`stem'.xlsx"
    local csv "`output_dir'/`stem'.csv"
    local tex "`output_dir'/`stem'.tex"
    foreach f in book csv tex {
        capture erase "``f''"
    }
    sysuse auto, clear
    puttab make price mpg weight length in 1/4 using "`book'", sheet("D2b") ///
        latex("`tex'") csv("`csv'") varlabels spanheader("Solo" 2 \ "Pair" 4/5)
    assert r(n_spans) == 2 & r(latex_rows) == 4 & r(latex_cols) == 5
    * the workbook merges only the two-column span; the one-column label
    * is still a span in LaTeX, and column 3 is a plain blank cell
    _v_facts "`book'" "D2b"
    _ld_wb_spans 2
    assert r(n) == 1 & "`r(spans)'" == "1:4-5"
    _ld_nd contains  & \multicolumn{1}{c}{Solo} &  & \multicolumn{2}{c}{Pair} \\
    _ld_nd contains \cmidrule(lr){2-2} \cmidrule(lr){4-5}
    _ld_check "`tex'" --compile --cols 5 --header-rows 2 --body-rows 4 ///
        --spans "1:2-2,1:4-5" --parity-csv "`csv'" --csv-rows 3:6
    * a span row needs a header row: refused before anything is written
    capture erase "`output_dir'/ld_d2b_bad.tex"
    _ld_refused "`output_dir'/ld_d2b_bad.tex" "spanheader() requires a header row" ///
        puttab make price in 1/3, latex("`output_dir'/ld_d2b_bad.tex") noheader ///
        spanheader("Cost" 2)
}
if _rc == 0 {
    display as result "  PASS: D2b one-column span declared, gap column blank, noheader refusal"
    local ++pass_count
}
else {
    display as error "  FAIL: D2b one-column span (rc=`=_rc')"
    local ++fail_count
}

**# D3. puttab blockheader: spans from a regtab flat frame's blocks
capture noisily {
    local stem "ld_d3"
    local book "`output_dir'/`stem'.xlsx"
    local csv "`output_dir'/`stem'.csv"
    local md "`output_dir'/`stem'.md"
    local tex "`output_dir'/`stem'.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    capture frame drop _ld_models
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    quietly collect: logit foreign mpg weight
    quietly regtab, frame(_ld_models, replace flat) models("Crude" \ "Adjusted")
    frame _ld_models {
        puttab rowlabel c* using "`book'", sheet("D3") blockheader ///
            latex("`tex'") markdown("`md'") csv("`csv'")
        assert r(n_spans) == 2
        local nd = r(n_datarows)
        assert r(latex_rows) == `nd' & r(latex_rows) == r(markdown_rows)
        local k = r(latex_cols)
        assert `k' == r(markdown_cols)
    }
    _v_facts "`book'" "D3"
    _ld_wb_spans 2
    assert r(n) == 2
    local wbspans "`r(spans)'"
    _ld_nd contains \multicolumn
    _ld_nd contains {Crude}
    _ld_nd contains {Adjusted}
    _ld_nd absent Crude,
    _ld_nd pdftext Crude
    _ld_nd pdftext Adjusted
    _ld_check "`tex'" --compile --cols `k' --header-rows 2 --body-rows `nd' ///
        --spans "`wbspans'" --parity-csv "`csv'" --csv-rows 3:`=2 + `nd''
}
if _rc == 0 {
    display as result "  PASS: D3 puttab blockheader: block spans = workbook merges"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 puttab blockheader (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ld_models

**# D4. puttab panel() and boldrows(): bold rows agree with the workbook
capture noisily {
    local stem "ld_d4"
    local book "`output_dir'/`stem'.xlsx"
    local csv "`output_dir'/`stem'.csv"
    local md "`output_dir'/`stem'.md"
    local tex "`output_dir'/`stem'.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    _ld_cars4
    local car1 = make[1]
    puttab make price mpg weight using "`book'", sheet("D4") panel(foreign) ///
        boldrows(2) latex("`tex'") markdown("`md'") csv("`csv'") title("Panels")
    * heading, 2 cars, heading, 2 cars
    assert r(n_datarows) == 6 & r(n_panels) == 2
    assert r(latex_rows) == 6 & r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 4
    * workbook: row 1 title, 2 header, data rows 3..8; bold = headings
    * (data rows 1 and 4) and boldrows(2) (row 4)
    _v_facts "`book'" "D4"
    _v_has bold "" "B3 B4 B6"
    _v_none bold "B5 B7 B8"
    _ld_nd contains \textbf{Domestic}
    _ld_nd contains \textbf{Foreign}
    _ld_nd contains \hspace*{1.5em}\textbf{`car1'}
    _ld_check "`tex'" --compile --cols 4 --header-rows 1 --body-rows 6 ///
        --parity-csv "`csv'" --csv-rows 3:8
    * exactly three bold rows: the two headings and boldrows(2)
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 3
}
if _rc == 0 {
    display as result "  PASS: D4 puttab panel()/boldrows(): bold rows = workbook bold rows"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 puttab panel()/boldrows() (rc=`=_rc')"
    local ++fail_count
}

**# D5. puttab panelheader(), panelinline, noheader: the Markdown header slot
capture noisily {
    * (a) panel headings and panel header rows under one header row
    local tex "`output_dir'/ld_d5a.tex"
    local csv "`output_dir'/ld_d5a.csv"
    local md "`output_dir'/ld_d5a.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    _ld_blocks
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) latex("`tex'") ///
        csv("`csv'") markdown("`md'")
    * 2 headings + 2 header rows + 3 data rows
    assert r(n_datarows) == 7 & r(n_panels) == 2
    assert r(latex_rows) == 7 & r(latex_rows) == r(markdown_rows) & r(latex_cols) == 4
    _ld_nd contains lab & a & b & c \\
    _ld_nd contains \multicolumn{4}{l}{\textbf{A. Relapses}} \\
    _ld_nd contains \textbf{Events} & \textbf{PY} & \textbf{Rate} \\
    _ld_nd contains \hspace*{1.5em}Age \textless{}55 & 1 & 2 & 3 \\
    _ld_check "`tex'" --compile --cols 4 --header-rows 1 --body-rows 7 ///
        --parity-csv "`csv'" --csv-rows 2:
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 4

    * (b) panelinline: the heading and its header cells share one row
    local tex "`output_dir'/ld_d5b.tex"
    local csv "`output_dir'/ld_d5b.csv"
    local md "`output_dir'/ld_d5b.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    _ld_blocks
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) panelinline ///
        latex("`tex'") csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 5
    assert r(latex_rows) == 5 & r(latex_rows) == r(markdown_rows)
    _ld_nd contains \textbf{A. Relapses} & \textbf{Events} & \textbf{PY} & \textbf{Rate} \\
    _ld_nd contains \textbf{B. MRI} & \textbf{Scans} & \textbf{Pct} & \textbf{RR} \\
    _ld_check "`tex'" --compile --cols 4 --header-rows 1 --body-rows 5 ///
        --parity-csv "`csv'" --csv-rows 2:
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 2

    * (c) noheader panelinline: no header block in LaTeX. Markdown must have a
    * header line, so it promotes the shared first row into it and counts one
    * row fewer; LaTeX keeps that row as a bold body row, so r(latex_rows) is
    * r(markdown_rows) + 1 here (the intended exception to equality).
    local tex "`output_dir'/ld_d5c.tex"
    local csv "`output_dir'/ld_d5c.csv"
    local md "`output_dir'/ld_d5c.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    _ld_blocks
    puttab lab a b c, panel(blk) panelheader(h1 h2 h3 h4) panelinline noheader ///
        latex("`tex'") csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 5
    assert r(markdown_rows) == 4
    assert r(latex_rows) == 5 & r(latex_rows) == r(markdown_rows) + 1
    _ld_nd contains \textbf{A. Relapses} & \textbf{Events} & \textbf{PY} & \textbf{Rate} \\
    _ld_nd contains \textbf{B. MRI} & \textbf{Scans} & \textbf{Pct} & \textbf{RR} \\
    _ld_check "`tex'" --compile --cols 4 --header-rows 0 --body-rows 5 ///
        --parity-csv "`csv'" --csv-rows 1:
    _ld_count "`tex'" "\midrule"
    assert r(n) == 0
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 2

    * (d) noheader without panels: no header block, data stay data
    local tex "`output_dir'/ld_d5d.tex"
    local csv "`output_dir'/ld_d5d.csv"
    local md "`output_dir'/ld_d5d.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    _ld_blocks
    puttab lab a b c, noheader latex("`tex'") csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 3
    assert r(latex_rows) == 3 & r(latex_rows) == r(markdown_rows)
    _ld_check "`tex'" --compile --cols 4 --header-rows 0 --body-rows 3 ///
        --parity-csv "`csv'" --csv-rows 1:
    _ld_count "`tex'" "Age \textless{}55 & 1 & 2 & 3"
    assert r(n) == 1

    * (e) noheader with panel(): two panel headings. Neither is promoted:
    * LaTeX has no header block, both headings are bold full-width rows in
    * the body, and there is no \midrule. Markdown promotes the first heading
    * into its header line, so r(latex_rows) = r(markdown_rows) + 1 (the
    * intended exception to equality).
    local tex "`output_dir'/ld_d5e.tex"
    local csv "`output_dir'/ld_d5e.csv"
    local md "`output_dir'/ld_d5e.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    _ld_blocks
    puttab lab a b c, panel(blk) noheader latex("`tex'") csv("`csv'") markdown("`md'")
    * heading, 2 rows, heading, 1 row
    assert r(n_datarows) == 5
    assert r(markdown_rows) == 4
    assert r(latex_rows) == 5 & r(latex_rows) == r(markdown_rows) + 1
    _ld_nd contains \multicolumn{4}{l}{\textbf{A. Relapses}} \\
    _ld_nd contains \multicolumn{4}{l}{\textbf{B. MRI}} \\
    _ld_nd contains \hspace*{1.5em}Age \textless{}55 & 1 & 2 & 3 \\
    _ld_nd absent \midrule
    _ld_check "`tex'" --compile --cols 4 --header-rows 0 --body-rows 5 ///
        --parity-csv "`csv'" --csv-rows 1:
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 2
    _ld_count "`tex'" "\multicolumn{4}{l}{\textbf{"
    assert r(n) == 2
}
if _rc == 0 {
    display as result "  PASS: D5 puttab panelheader/panelinline/noheader: no header block under noheader, headings stay bold body rows"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 puttab panelheader/panelinline/noheader (rc=`=_rc')"
    local ++fail_count
}

**# D6. puttab matrix() and frame() sources, embedded header, varlabels
capture noisily {
    * matrix(): the row-label column's header is blank, as in the CSV
    local tex "`output_dir'/ld_d6m.tex"
    local csv "`output_dir'/ld_d6m.csv"
    local md "`output_dir'/ld_d6m.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    matrix LDM = (1.5, 2.25 \ 3, 4.1 \ 5.5, 6)
    matrix rownames LDM = alpha beta gamma
    matrix colnames LDM = est se
    puttab, matrix(LDM) digits(2) latex("`tex'") csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 3 & r(n_cols) == 3
    assert r(latex_rows) == 3 & r(latex_rows) == r(markdown_rows) & r(latex_cols) == 3
    _ld_nd contains  & est & se \\
    _ld_nd contains alpha & 1.50 & 2.25 \\
    _ld_nd contains beta & 3.00 & 4.10 \\
    _ld_nd contains gamma & 5.50 & 6.00 \\
    _ld_check "`tex'" --compile --cols 3 --header-rows 1 --body-rows 3 ///
        --parity-csv "`csv'" --csv-rows 2:

    * matrix(r(table)) after an estimation command
    local tex "`output_dir'/ld_d6t.tex"
    local csv "`output_dir'/ld_d6t.csv"
    foreach f in tex csv {
        capture erase "``f''"
    }
    sysuse auto, clear
    quietly regress price mpg weight
    puttab, matrix(r(table)) latex("`tex'") csv("`csv'")
    assert r(latex_cols) == r(n_cols) & r(latex_rows) == r(n_datarows)
    _ld_check "`tex'" --compile --cols `=r(n_cols)' --header-rows 1 ///
        --body-rows `=r(n_datarows)' --parity-csv "`csv'" --csv-rows 2:

    * frame(): the frame is the source; the current data are untouched
    local tex "`output_dir'/ld_d6f.tex"
    local csv "`output_dir'/ld_d6f.csv"
    local md "`output_dir'/ld_d6f.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    capture frame drop _ld_src
    frame create _ld_src
    frame _ld_src {
        quietly sysuse auto
        quietly keep make price mpg
        quietly keep in 1/4
    }
    quietly sysuse auto, clear
    puttab make price mpg, frame(_ld_src) varlabels latex("`tex'") ///
        csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 4 & r(latex_rows) == 4 & r(latex_rows) == r(markdown_rows)
    assert _N == 74
    _ld_nd contains Make and model & Price & Mileage (mpg) \\
    _ld_nd contains AMC Spirit & 3799 & 22 \\
    _ld_check "`tex'" --compile --cols 3 --header-rows 1 --body-rows 4 ///
        --parity-csv "`csv'" --csv-rows 2:

    * embedded header row: consumed by default, a body row under noembedheader
    capture frame drop _ld_emb
    frame create _ld_emb
    frame _ld_emb {
        quietly set obs 3
        quietly gen str8 c1 = ""
        quietly gen str8 c2 = ""
        label variable c1 "Group"
        label variable c2 "Mean"
        quietly replace c1 = "Group" in 1
        quietly replace c2 = "Mean" in 1
        quietly replace c1 = "G1" in 2
        quietly replace c2 = "1.5" in 2
        quietly replace c1 = "G2" in 3
        quietly replace c2 = "2.5" in 3
    }
    local tex "`output_dir'/ld_d6e.tex"
    local csv "`output_dir'/ld_d6e.csv"
    local md "`output_dir'/ld_d6e.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    puttab c1 c2, frame(_ld_emb) varlabels latex("`tex'") csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 2 & r(latex_rows) == 2 & r(latex_rows) == r(markdown_rows)
    _ld_check "`tex'" --compile --cols 2 --header-rows 1 --body-rows 2 ///
        --parity-csv "`csv'" --csv-rows 2:
    local tex "`output_dir'/ld_d6n.tex"
    local csv "`output_dir'/ld_d6n.csv"
    local md "`output_dir'/ld_d6n.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    puttab c1 c2, frame(_ld_emb) varlabels noembedheader latex("`tex'") ///
        csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 3 & r(latex_rows) == 3 & r(latex_rows) == r(markdown_rows)
    _ld_check "`tex'" --compile --cols 2 --header-rows 1 --body-rows 3 ///
        --parity-csv "`csv'" --csv-rows 2:
}
if _rc == 0 {
    display as result "  PASS: D6 puttab matrix()/frame() sources, noembedheader, varlabels"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 puttab sources (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ld_src
capture frame drop _ld_emb

**# D7. puttab keepblank: a blank data row is a body row in both outputs
capture noisily {
    local tex "`output_dir'/ld_d7.tex"
    local csv "`output_dir'/ld_d7.csv"
    local md "`output_dir'/ld_d7.md"
    foreach f in tex csv md {
        capture erase "``f''"
    }
    clear
    input str8 lab double v
    "first" 1
    "" .
    "third" 3
    end
    puttab lab v, latex("`tex'") csv("`csv'") markdown("`md'")
    assert r(n_datarows) == 3
    assert r(latex_rows) == 3 & r(latex_rows) == r(markdown_rows)
    _ld_nd contains & \\
    _ld_nd absent \addlinespace
    _ld_check "`tex'" --compile --cols 2 --header-rows 1 --body-rows 3 ///
        --keep-blank --parity-csv "`csv'" --csv-rows 2:
}
if _rc == 0 {
    display as result "  PASS: D7 puttab keepblank: blank data row is a body row (latex_rows = markdown_rows)"
    local ++pass_count
}
else {
    display as error "  FAIL: D7 puttab keepblank (rc=`=_rc')"
    local ++fail_count
}

**# D8. puttab texappend: replace, append, labels, create-on-append
capture noisily {
    local stem "ld_d8"
    local tex "`output_dir'/`stem'.tex"
    _ld_seed_text "`tex'"
    sysuse auto, clear
    * a plain latex() replaces an existing file
    puttab make price in 1/3, latex("`tex'") title("First")
    assert r(latex_rows) == 3
    _ld_nd absent KEEP THIS TEXT
    _ld_nd contains \label{tab:ld_d8}
    _ld_check "`tex'" --compile --tables 1 --body-rows 3
    * texappend adds a table; the first keeps its bare label
    puttab make mpg in 4/7, latex("`tex'") texappend title("Second")
    assert r(latex_rows) == 4 & r(latex_cols) == 2
    puttab make weight in 8/9, latex("`tex'") texappend title("Third")
    assert r(latex_rows) == 2
    _ld_nd contains \label{tab:ld_d8}
    _ld_nd contains \label{tab:ld_d8-2}
    _ld_nd contains \label{tab:ld_d8-3}
    _ld_nd contains \caption{Second}
    _ld_nd absent KEEP THIS TEXT
    _ld_check "`tex'" --compile --tables 3
    _ld_check "`tex'" --table 2 --cols 2 --body-rows 4
    _ld_check "`tex'" --table 3 --cols 2 --body-rows 2
    * texappend to a file that does not exist creates it
    local tex2 "`output_dir'/ld_d8_new.tex"
    capture erase "`tex2'"
    puttab make price in 1/2, latex("`tex2'") texappend
    assert r(latex_rows) == 2
    _ld_check "`tex2'" --compile --tables 1 --body-rows 2
    * the command-line option wins over nothing else: a plain call replaces
    puttab make price in 1/2, latex("`tex'")
    _ld_check "`tex'" --compile --tables 1 --body-rows 2
}
if _rc == 0 {
    display as result "  PASS: D8 puttab latex() replaces, texappend appends with -2/-3 labels, creates when absent"
    local ++pass_count
}
else {
    display as error "  FAIL: D8 puttab texappend (rc=`=_rc')"
    local ++fail_count
}

**# D9. puttab session sink: first write replaces, later writes append
capture noisily {
    local sess "`output_dir'/ld_d9_sess.tex"
    local other "`output_dir'/ld_d9_other.tex"
    local book "`output_dir'/ld_d9.xlsx"
    capture erase "`other'"
    capture erase "`book'"
    _ld_seed_text "`sess'"
    sysuse auto, clear
    quietly tabtools set latex "`sess'"
    * no latex() and no using: the session file alone is a sink
    puttab make price in 1/3, csv("`output_dir'/ld_d9.csv")
    assert `"`r(latex)'"' == "`sess'" & r(latex_rows) == 3
    _ld_nd absent KEEP THIS TEXT
    _ld_check "`sess'" --compile --tables 1 --body-rows 3
    puttab make mpg in 4/8, csv("`output_dir'/ld_d9.csv")
    assert r(latex_rows) == 5
    _ld_check "`sess'" --compile --tables 2
    _ld_check "`sess'" --table 2 --body-rows 5
    * an explicit latex() wins and leaves the session file alone
    _ld_sum "`sess'"
    local before "`r(sum)'"
    puttab make price in 1/2, latex("`other'")
    _ld_sum "`sess'"
    assert "`r(sum)'" == "`before'"
    _ld_check "`other'" --compile --tables 1 --body-rows 2
    * a session workbook is used when using is omitted, alongside latex()
    quietly tabtools set workbook "`book'"
    puttab make price in 1/2
    confirm file "`book'"
    _ld_check "`sess'" --compile --tables 3
    quietly tabtools set clear
}
local drc = _rc
quietly tabtools set clear
if `drc' == 0 {
    display as result "  PASS: D9 puttab session latex sink: replace then append, explicit wins"
    local ++pass_count
}
else {
    display as error "  FAIL: D9 puttab session sink (rc=`drc')"
    local ++fail_count
}

**# D10. puttab refusals leave a pre-seeded target intact
capture noisily {
    local m "`output_dir'/ld_d10.md"
    local s "`output_dir'/ld_d10_same.tex"
    local t "`output_dir'/ld_d10_t.tex"
    capture erase "`t'"
    sysuse auto, clear
    * texappend without latex(): the same refusal as mdappend without markdown()
    _ld_refused "`t'" "texappend requires latex()" ///
        puttab make price in 1/3, markdown("`m'") texappend
    _ld_refused "`t'" "texappend requires latex()" ///
        puttab make price in 1/3, texappend
    _ld_refused "`t'" "mdappend requires markdown()" ///
        puttab make price in 1/3, latex("`t'") mdappend
    _ld_refused "`t'" "mdappend requires markdown()" ///
        puttab make price in 1/3, mdappend
    * a .tex path under another sink never overwrites: the extension refusal
    * comes first, and the seeded file is byte-identical afterwards
    _ld_seed_text "`s'"
    _ld_refused "`s'" "markdown() must specify" ///
        puttab make price in 1/3, markdown("`s'") latex("`t'")
    _ld_refused "`s'" "csv() must have a .csv extension" ///
        puttab make price in 1/3, csv("`s'") latex("`t'")
    _ld_refused "`s'" "using file must have a .xlsx extension" ///
        puttab make price in 1/3 using "`s'", latex("`t'")
    * latex() itself must be a .tex file; the other sinks' files stay intact
    local nm "`output_dir'/ld_d10_notex.md"
    _ld_seed_text "`nm'"
    _ld_refused "`nm'" "latex() must specify a .tex file" ///
        puttab make price in 1/3, latex("`nm'")
    _ld_refused "`nm'" "latex() must specify a .tex file" ///
        puttab make price in 1/3, latex("`nm'") texappend
    * nothing written means nothing posted
    puttab make price in 1/3, csv("`output_dir'/ld_d10.csv")
    assert `"`r(latex)'"' == "" & r(latex_rows) == . & r(latex_cols) == .
}
if _rc == 0 {
    display as result "  PASS: D10 puttab refusals: texappend without latex(), extensions, seeded targets intact"
    local ++pass_count
}
else {
    display as error "  FAIL: D10 puttab refusals (rc=`=_rc')"
    local ++fail_count
}

**# D11. puttab failed LaTeX write keeps the analytical r() like Markdown
capture noisily {
    local bad_root "`output_dir'/ld_no_such_dir"
    capture rmdir "`bad_root'"
    local m "`output_dir'/ld_d11.md"
    capture erase "`m'"
    sysuse auto, clear
    * the pin in test_package_adversarial.do for the workbook, here for latex()
    return clear
    capture noisily puttab make mpg in 1/2, latex("`bad_root'/ld.tex")
    local lrc = _rc
    assert `lrc' != 0
    assert r(n_rows) == 3 & r(n_cols) == 2 & r(n_datarows) == 2
    assert "`r(source)'" == "data"
    assert `"`r(latex)'"' == "" & r(latex_rows) == . & r(latex_cols) == .
    return clear
    capture noisily puttab make mpg in 1/2, markdown("`bad_root'/ld.md")
    * the same code as a failed Markdown write
    assert `lrc' == _rc
    * a failure after the Markdown file was written: it stays reported
    return clear
    capture noisily puttab make mpg in 1/2, markdown("`m'") latex("`bad_root'/ld.tex")
    assert _rc == `lrc'
    assert `"`r(markdown)'"' == "`m'" & `"`r(latex)'"' == ""
    assert r(n_rows) == 3
    confirm file "`m'"
    * the failure message names the sink
    _ld_console puttab make mpg in 1/2, latex("`bad_root'/ld.tex")
    assert r(rc) == `lrc'
    assert strpos(`"`r(text)'"', "Failed to export LaTeX to") > 0
    * and the data in memory are unchanged
    assert _N == 74
}
if _rc == 0 {
    display as result "  PASS: D11 puttab failed latex(): same rc and analytical r() as a failed markdown()"
    local ++pass_count
}
else {
    display as error "  FAIL: D11 puttab failed latex() (rc=`=_rc')"
    local ++fail_count
}

**# D12. outtab: every sink, panel heading rows bold in LaTeX and workbook
* Fixture: a synthetic births file, as in test_outtab_v230.do.
capture program drop _ld_births
program define _ld_births
    version 17.0
    clear
    set seed 20261031
    set obs 3000
    gen long id = ceil(_n / 2)
    gen byte narc = runiform() < 0.1
    label define _ldn 1 "Narcolepsy" 0 "Comparator", replace
    label values narc _ldn
    gen double age = rnormal(30, 5)
    gen byte cs = runiform() < invlogit(-1.5 + 0.5 * narc + 0.03 * (age - 30))
    gen byte ptb = runiform() < 0.05 + 0.02 * narc
    label variable cs "Caesarean section"
    label variable ptb "Preterm birth"
    gen byte prim = 1
    gen byte sens = runiform() < 0.8
    label variable prim "Primary analysis"
    label variable sens "Sensitivity analysis"
end

capture noisily {  // stata-dev-ignore: capture-braced-block — _rc is read right after the closing brace; a needle ending in a literal } (e.g. a closing \par}) unbalances the rule's brace count
    local stem "ld_d12"
    local book "`output_dir'/`stem'.xlsx"
    local csv "`output_dir'/`stem'.csv"
    local md "`output_dir'/`stem'.md"
    local tex "`output_dir'/`stem'.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    _ld_births
    outtab cs ptb, exposure(narc) models("" \ "age") ///
        modellabels("Crude" \ "Adjusted") panels(prim sens) ///
        xlsx("`book'") csv("`csv'") markdown("`md'") latex("`tex'") ///
        title("Outcomes & ratios") footnote("RR = risk ratio")
    * two panels x two outcomes: 2 headings + 4 outcome rows = 6 rows
    assert r(N_rows) == 6 & r(N_panels) == 2 & r(N_models) == 2
    _ld_csvdim "`csv'"
    local k = r(k)
    assert `k' == 5
    * Markdown body rows = table lines minus header and rule
    _v_grep "`md'" "^[|] "
    local nmd = r(n) - 2
    assert `nmd' == 6
    _ld_nd contains \caption{Outcomes \& ratios}
    _ld_nd contains \label{tab:ld_d12}
    _ld_nd contains  & Narcolepsy, events/N (\%) & Comparator, events/N (\%) & Crude, RR (95\% CI) & Adjusted, RR (95\% CI) \\
    _ld_nd contains \textbf{Primary analysis}
    _ld_nd contains \textbf{Sensitivity analysis}
    _ld_nd contains \hspace*{1.5em}Caesarean section &
    _ld_nd contains RR = risk ratio\par}
    _ld_nd pdftext Outcomes
    _ld_nd pdftext Narcolepsy
    _ld_nd pdftext Primary analysis
    _ld_check "`tex'" --compile --cols `k' --header-rows 1 --body-rows `nmd' ///
        --parity-csv "`csv'" --csv-rows 3:-2
    * the heading rows (and only they) are bold: in LaTeX and in the workbook
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 2
    _v_facts "`book'" "Table"
    _v_value B3 "Primary analysis"
    _v_value B6 "Sensitivity analysis"
    _v_has bold "" "B3 B6"
    _v_none bold "B4 B5 B7 B8"
}
if _rc == 0 {
    display as result "  PASS: D12 outtab: all sinks, CSV parity, panel headings bold in LaTeX and workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: D12 outtab (rc=`=_rc')"
    local ++fail_count
}

**# D13. outtab texappend, refusal, failed write
capture noisily {
    local tex "`output_dir'/ld_d13.tex"
    local t2 "`output_dir'/ld_d13_nodir/x.tex"
    local m "`output_dir'/ld_d13.md"
    capture erase "`tex'"
    capture erase "`m'"
    _ld_births
    * no panels: a plain header-and-body table, no bold rows
    outtab cs ptb, exposure(narc) latex("`tex'") title("One")
    _ld_check "`tex'" --compile --tables 1 --cols 4 --header-rows 1 --body-rows 2
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 0
    outtab cs ptb, exposure(narc) models("" \ "age") latex("`tex'") texappend title("Two")
    _ld_nd contains \label{tab:ld_d13}
    _ld_nd contains \label{tab:ld_d13-2}
    _ld_check "`tex'" --compile --tables 2
    _ld_check "`tex'" --table 2 --cols 5 --body-rows 2
    * texappend without latex() and without a session file: puttab refuses
    * (rc 198, its own message reaches the user), nothing is written
    _ld_refused "`tex'" "texappend requires latex()" ///
        outtab cs ptb, exposure(narc) markdown("`m'") texappend
    capture confirm file "`m'"
    assert _rc != 0
    _ld_refused "`tex'" "texappend requires latex()" ///
        outtab cs ptb, exposure(narc) texappend
    * mdappend alone: the same two outcomes for the Markdown sink
    * (previously working call: a note, rc 0, nothing written; also with
    * another sink, where mdappend is dropped and the other sink is written)
    _ld_sum "`m'"
    local msum "`r(sum)'"
    _ld_sum "`tex'"
    local tsum "`r(sum)'"
    _ld_console outtab cs ptb, exposure(narc) mdappend
    assert r(rc) == 0
    assert strpos(`"`r(text)'"', "(outtab: mdappend ignored; no markdown() and no session Markdown file)") > 0
    _ld_sum "`m'"
    assert "`r(sum)'" == "`msum'"
    _ld_sum "`tex'"
    assert "`r(sum)'" == "`tsum'"
    local tex3 "`output_dir'/ld_d13_md.tex"
    capture erase "`tex3'"
    _ld_console outtab cs ptb, exposure(narc) latex("`tex3'") mdappend
    assert r(rc) == 0
    assert strpos(`"`r(text)'"', "mdappend ignored") > 0
    _ld_check "`tex3'" --compile --tables 1 --body-rows 2
    * puttab itself still refuses a lone mdappend
    local msess "`output_dir'/ld_d13_sess.md"
    _ld_seed_text "`msess'"
    quietly tabtools set markdown "`msess'"
    outtab cs ptb, exposure(narc) mdappend title("M1")
    outtab cs ptb, exposure(narc) mdappend title("M2")
    _v_line "`msess'" "KEEP THIS TEXT" 1
    _v_line "`msess'" "### M1" 1
    _v_line "`msess'" "### M2" 1
    quietly tabtools set clear
    * with a session file, texappend alone is accepted and appends there
    local sess "`output_dir'/ld_d13_sess.tex"
    capture erase "`sess'"
    quietly tabtools set latex "`sess'"
    outtab cs ptb, exposure(narc) texappend title("S1")
    _ld_check "`sess'" --compile --tables 1 --cols 4 --body-rows 2
    outtab cs ptb, exposure(narc) texappend title("S2")
    _ld_nd contains \label{tab:ld_d13_sess}
    _ld_nd contains \label{tab:ld_d13_sess-2}
    _ld_check "`sess'" --compile --tables 2 --cols 4 --body-rows 2
    quietly tabtools set clear
    * a latex() that is not .tex is refused with the target intact
    _ld_seed_text "`m'"
    _ld_refused "`m'" "latex() must specify a .tex file" ///
        outtab cs ptb, exposure(narc) latex("`m'")
    * a failed write: the message names the sink, rc is the Markdown one
    _ld_console outtab cs ptb, exposure(narc) latex("`t2'")
    local lrc = r(rc)
    assert `lrc' != 0 & strpos(`"`r(text)'"', "Failed to export LaTeX to") > 0
    _ld_console outtab cs ptb, exposure(narc) markdown("`output_dir'/ld_d13_nodir/x.md")
    assert r(rc) == `lrc'
    * the earlier tables are still there
    _ld_check "`tex'" --tables 2
}
local drc = _rc
quietly tabtools set clear
if `drc' == 0 {
    display as result "  PASS: D13 outtab texappend, session file, refusals, failed write"
    local ++pass_count
}
else {
    display as error "  FAIL: D13 outtab texappend/refusals (rc=`drc')"
    local ++fail_count
}

**# D14. stacktab blocks(): every sink, label stem, no stage leftovers
* Source workbook, as in test_stacktab.do.
local wb "`output_dir'/ld_stack_src.xlsx"
capture erase "`wb'"
clear
input str20 label str10 est str16 ci
"Category"   "HR"    "95% CI"
"Binary HRT" "1.23"  "(1.05, 1.44)"
"Active"     "1.45"  "(1.20, 1.75)"
"Recent"     "0.98"  "(0.82, 1.17)"
end
quietly export excel "`wb'", sheet("SrcA") sheetreplace
clear
input str20 label str10 est str16 ci
"Dose category" "aHR"    "95% CI"
"Low dose"      "1.10"   "(0.90, 1.35)"
"High dose"     "1.67"   "(1.30, 2.15)"
end
quietly export excel "`wb'", sheet("SrcB") sheetreplace
local blocks2 "sheet(SrcA) rows(1/4) cols(A-C) \ sheet(SrcB) rows(1/3) cols(A-C)"

capture noisily {  // stata-dev-ignore: capture-braced-block — _rc is read right after the closing brace; a needle ending in a literal } (e.g. a closing \par}) unbalances the rule's brace count
    local stem "ld_d14"
    local csv "`output_dir'/`stem'.csv"
    local md "`output_dir'/`stem'.md"
    local tex "`output_dir'/`stem'.tex"
    foreach f in csv md tex {
        capture erase "``f''"
    }
    _ld_tmpls
    local tmp0 `"`r(tmp)'"'
    stacktab using "`wb'", blocks(`blocks2') sheet("D14") sheetreplace ///
        title("Stack & 5%") note("n1 \ n2") csv("`csv'") markdown("`md'") ///
        latex("`tex'")
    assert r(blocks_loaded) == 2 & r(rows_written) == 7
    assert `"`r(latex)'"' == "`tex'"
    * header + 6 data rows: the Markdown writer's count, from the same call
    assert r(latex_rows) == 6 & r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 3 & r(latex_cols) == r(markdown_cols)
    * no stage file or directory is left in the temp directory
    _ld_tmpls
    assert `"`r(tmp)'"' == `"`tmp0'"'
    * the label stem is the target's, not the stage file's
    _ld_nd contains \label{tab:ld_d14}
    _ld_nd contains \caption{Stack \& 5\%}
    _ld_nd contains Category & HR & 95\% CI \\
    _ld_nd contains Binary HRT & 1.23 & (1.05, 1.44) \\
    _ld_nd contains Dose category & aHR & 95\% CI \\
    _ld_nd contains High dose & 1.67 & (1.30, 2.15) \\
    _ld_nd contains n1\par
    _ld_nd contains n2\par}
    _ld_nd pdftext Stack
    _ld_nd pdftext Binary HRT
    _ld_nd pdftext Low dose
    _ld_check "`tex'" --compile --tables 1 --cols 3 --header-rows 1 --body-rows 6 ///
        --parity-csv "`csv'" --csv-rows 3:8
    * and the workbook sheet holds the same table
    _v_facts "`wb'" "D14"
    _v_value B2 "Category"
    _v_value B3 "Binary HRT"
}
if _rc == 0 {
    display as result "  PASS: D14 stacktab blocks(): all sinks, CSV parity, target-stem label, no stage leftovers"
    local ++pass_count
}
else {
    display as error "  FAIL: D14 stacktab blocks() (rc=`=_rc')"
    local ++fail_count
}

**# D15. stacktab texappend and the session sink
capture noisily {
    local tex "`output_dir'/ld_d15.tex"
    local sess "`output_dir'/ld_d15_sess.tex"
    _ld_seed_text "`tex'"
    stacktab using "`wb'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D15a") sheetreplace title("First") latex("`tex'")
    assert r(latex_rows) == 3
    _ld_nd absent KEEP THIS TEXT
    _ld_check "`tex'" --compile --tables 1 --body-rows 3
    * texappend copies the existing file in, appends, commits with the workbook
    stacktab using "`wb'", blocks(sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("D15b") sheetreplace title("Second") latex("`tex'") texappend
    assert r(latex_rows) == 2
    _ld_nd contains \label{tab:ld_d15}
    _ld_nd contains \label{tab:ld_d15-2}
    _ld_nd contains \caption{Second}
    _ld_check "`tex'" --compile --tables 2
    _ld_check "`tex'" --table 1 --body-rows 3
    _ld_check "`tex'" --table 2 --body-rows 2
    * texappend without latex() is refused with every file intact
    _ld_refused "`tex'" "texappend requires latex()" ///
        stacktab using "`wb'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D15c") sheetreplace texappend
    * a .tex path that is not .tex
    local nm "`output_dir'/ld_d15_notex.md"
    _ld_seed_text "`nm'"
    _ld_refused "`nm'" "latex() must specify a .tex file" ///
        stacktab using "`wb'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D15c") sheetreplace latex("`nm'")
    * session sink: the first write replaces, later writes append
    _ld_seed_text "`sess'"
    quietly tabtools set latex "`sess'"
    stacktab using "`wb'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D15s1") sheetreplace
    assert `"`r(latex)'"' == "`sess'" & r(latex_rows) == 3
    _ld_nd absent KEEP THIS TEXT
    _ld_check "`sess'" --compile --tables 1
    stacktab using "`wb'", blocks(sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("D15s2") sheetreplace
    assert r(latex_rows) == 2
    _ld_check "`sess'" --compile --tables 2
    quietly tabtools set clear
}
local drc = _rc
quietly tabtools set clear
if `drc' == 0 {
    display as result "  PASS: D15 stacktab texappend, refusals, session sink"
    local ++pass_count
}
else {
    display as error "  FAIL: D15 stacktab texappend/session (rc=`drc')"
    local ++fail_count
}

**# D16. stacktab: a failed LaTeX write or a late failure touches nothing
capture noisily {  // stata-dev-ignore: capture-braced-block — _rc is read right after the closing brace; a needle ending in a literal } (e.g. a closing \par}) unbalances the rule's brace count
    local book "`output_dir'/ld_d16.xlsx"
    local csv "`output_dir'/ld_d16.csv"
    local md "`output_dir'/ld_d16.md"
    local tex "`output_dir'/ld_d16.tex"
    local bad "`output_dir'/ld_d16_nodir/x.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    quietly copy "`wb'" "`book'", replace
    _ld_seed_text "`csv'"
    _ld_seed_text "`md'"
    _ld_seed_text "`tex'"
    _ld_sum "`book'"
    local sb "`r(sum)'"
    _ld_sum "`csv'"
    local sc "`r(sum)'"
    _ld_sum "`md'"
    local sm "`r(sum)'"
    _ld_sum "`tex'"
    local st "`r(sum)'"
    _ld_tmpls
    local tmp0 `"`r(tmp)'"'
    * (a) latex() into a missing directory: the commit fails; the workbook,
    * the CSV and the Markdown file are rolled back to the seeded bytes
    capture noisily stacktab using "`book'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D16") title("T") csv("`csv'") markdown("`md'") latex("`bad'")
    local lrc = _rc
    assert `lrc' != 0
    _ld_sum "`book'"
    assert "`r(sum)'" == "`sb'"
    _ld_sum "`csv'"
    assert "`r(sum)'" == "`sc'"
    _ld_sum "`md'"
    assert "`r(sum)'" == "`sm'"
    capture confirm file "`bad'"
    assert _rc != 0
    quietly import excel using "`book'", describe
    local found 0
    forvalues s = 1/`r(N_worksheet)' {
        if `"`r(worksheet_`s')'"' == "D16" local found 1
    }
    assert `found' == 0
    _ld_tmpls
    assert `"`r(tmp)'"' == `"`tmp0'"'
    * the same code as a failed Markdown commit
    capture noisily stacktab using "`book'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D16") title("T") markdown("`output_dir'/ld_d16_nodir/x.md")
    assert _rc == `lrc'
    * (b) a late failure after every stage succeeded: all four files untouched
    global TABTOOLS_QA_STACK_FAIL 1
    capture noisily stacktab using "`book'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D16") title("T") csv("`csv'") markdown("`md'") latex("`tex'")
    local frc = _rc
    global TABTOOLS_QA_STACK_FAIL
    assert `frc' == 459
    _ld_sum "`book'"
    assert "`r(sum)'" == "`sb'"
    _ld_sum "`csv'"
    assert "`r(sum)'" == "`sc'"
    _ld_sum "`md'"
    assert "`r(sum)'" == "`sm'"
    _ld_sum "`tex'"
    assert "`r(sum)'" == "`st'"
    _ld_tmpls
    assert `"`r(tmp)'"' == `"`tmp0'"'
    * (c) texappend and a late failure: the existing tables survive
    global TABTOOLS_QA_STACK_FAIL 1
    capture noisily stacktab using "`book'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D16") latex("`tex'") texappend
    global TABTOOLS_QA_STACK_FAIL
    assert _rc == 459
    _ld_sum "`tex'"
    assert "`r(sum)'" == "`st'"
    * and a clean run afterwards commits everything together
    stacktab using "`book'", blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("D16") title("T") csv("`csv'") markdown("`md'") latex("`tex'")
    _ld_check "`tex'" --compile --tables 1 --body-rows 3 --absent "KEEP THIS TEXT"
}
global TABTOOLS_QA_STACK_FAIL
if _rc == 0 {
    display as result "  PASS: D16 stacktab failed LaTeX commit / late failure: every target untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: D16 stacktab failure atomicity (rc=`=_rc')"
    local ++fail_count
}

**# D17. stacktab frames(): panels bold, texappend, session sink
capture noisily {  // stata-dev-ignore: capture-braced-block — _rc is read right after the closing brace; a needle ending in a literal } (e.g. a closing \par}) unbalances the rule's brace count
    local stem "ld_d17"
    local book "`output_dir'/`stem'.xlsx"
    local csv "`output_dir'/`stem'.csv"
    local md "`output_dir'/`stem'.md"
    local tex "`output_dir'/`stem'.tex"
    foreach f in book csv md tex {
        capture erase "``f''"
    }
    capture frame drop _ld_fa
    capture frame drop _ld_fb
    frame create _ld_fa
    frame _ld_fa {
        quietly set obs 3
        quietly gen str12 lab = word("Mean Median Range", _n)
        quietly gen str8 v1 = word("1.5 2.0 1-3", _n)
        quietly gen str8 v2 = word("2.5 3.0 2-4", _n)
        label variable lab "Statistic"
        label variable v1 "Group 1"
        label variable v2 "Group 2"
    }
    frame create _ld_fb
    frame _ld_fb {
        quietly set obs 2
        quietly gen str12 lab = word("Mean Median", _n)
        quietly gen str8 v1 = word("7.5 8.0", _n)
        quietly gen str8 v2 = word("8.5 9.0", _n)
        label variable lab "Statistic"
        label variable v1 "Group 1"
        label variable v2 "Group 2"
    }
    * the target workbook must exist for using
    clear
    set obs 1
    gen x = 1
    quietly export excel "`book'", sheet("seed") sheetreplace
    stacktab using "`book'", frames(_ld_fa "All cars" \ _ld_fb "Expensive cars") ///
        sheet("D17") title("Frames") note("n = 5") csv("`csv'") markdown("`md'") ///
        latex("`tex'")
    * 2 headings + 5 rows
    assert r(n_frames) == 2 & r(n_panels) == 2 & r(n_datarows) == 7
    assert r(latex_rows) == 7 & r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 3 & r(latex_cols) == r(markdown_cols)
    _ld_nd contains \caption{Frames}
    _ld_nd contains \label{tab:ld_d17}
    _ld_nd contains Statistic & Group 1 & Group 2 \\
    _ld_nd contains \multicolumn{3}{l}{\textbf{All cars}} \\
    _ld_nd contains \multicolumn{3}{l}{\textbf{Expensive cars}} \\
    _ld_nd contains \hspace*{1.5em}Mean & 1.5 & 2.5 \\
    _ld_nd contains n = 5\par}
    _ld_nd pdftext Frames
    _ld_nd pdftext Statistic
    _ld_nd pdftext Expensive cars
    _ld_check "`tex'" --compile --cols 3 --header-rows 1 --body-rows 7 ///
        --parity-csv "`csv'" --csv-rows 3:9
    _ld_count "`tex'" "\textbf{"
    assert r(n) == 2
    * the workbook agrees: the headings are bold, the rows under them are not
    _v_facts "`book'" "D17"
    _v_value B3 "All cars"
    _v_has bold "" "B3 B7"
    * texappend through the frames form
    stacktab using "`book'", frames(_ld_fb "Only B") sheet("D17b") ///
        latex("`tex'") texappend title("Again")
    assert r(latex_rows) == 3
    _ld_nd contains \label{tab:ld_d17-2}
    _ld_check "`tex'" --compile --tables 2
    * texappend without latex() is the puttab refusal
    _ld_refused "`tex'" "texappend requires latex()" ///
        stacktab using "`book'", frames(_ld_fb) sheet("D17c") texappend
    * session sink
    local sess "`output_dir'/ld_d17_sess.tex"
    _ld_seed_text "`sess'"
    quietly tabtools set latex "`sess'"
    stacktab using "`book'", frames(_ld_fa "A") sheet("D17s1")
    assert `"`r(latex)'"' == "`sess'" & r(latex_rows) == 4
    _ld_nd absent KEEP THIS TEXT
    _ld_check "`sess'" --compile --tables 1
    stacktab using "`book'", frames(_ld_fb "B") sheet("D17s2")
    _ld_check "`sess'" --compile --tables 2
    quietly tabtools set clear
}
local drc = _rc
quietly tabtools set clear
capture frame drop _ld_fa
capture frame drop _ld_fb
if `drc' == 0 {
    display as result "  PASS: D17 stacktab frames(): panels, texappend, session sink"
    local ++pass_count
}
else {
    display as error "  FAIL: D17 stacktab frames() (rc=`drc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_latex_direct tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _ld
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_latex_direct tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ld

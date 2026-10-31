* test_latex_descriptive.do - LaTeX export (latex()/texappend) for desctab,
* table1_tc, crosstab and survtab
* (_take_action/tabtools_latex_export_2026-10-31.md, builder group B3)
*   D1  desctab by() test smd total(after): every sink from one call, header
*       block, workbook merges, unflattened header, sink independence
*   D2  desctab without by()       D3 desctab total(before) test statistic
*   D4  desctab wt() wtcompare     D5 desctab smallcells(): masked cells render
*   D6  table1_tc (wrapper) by() and without by()
*   D7  crosstab: 2x2 with measures, multi-level rowpct, smallcells
*   D8  survtab: by() with several times(), no by(), three groups
*   D9  texappend across the four commands, label numbering
*   D10 session sink (tabtools set latex): first write replaces, later append,
*       only when sheet() is given, explicit latex() wins
*   D11 same-file and extension refusals leave every target byte-identical
*   D12 texappend without latex() is r(198)
*   D13 latex() into a missing directory: same rc and message shape as
*       markdown(), analytical r() preserved
* Expected values are hand-built strings, counts taken from the data, the
* workbook's own merged ranges (read back with openpyxl through
* tools/xlsx_facts.py), the CSV and Markdown the same call wrote, and the
* independent checker (pdflatex on the documented minimal preamble plus
* pdftotext), never the .tex under test alone.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _ld
log using "test_latex_descriptive.log", replace text name(_ld)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global LD_CHECKER "`qa_dir'/tools/check_latex.py"
global LD_FACTS "`qa_dir'/tools/xlsx_facts.py"
local ld "`output_dir'/ld"
capture mkdir "`ld'"
foreach pat in "*.tex" "*.csv" "*.md" "*.xlsx" "*.txt" {
    local old : dir "`ld'" files "`pat'", respectcase
    foreach f of local old {
        capture erase "`ld'/`f'"
    }
}
capture mkdir "`ld'/solo"
local old : dir "`ld'/solo" files "*", respectcase
foreach f of local old {
    capture erase "`ld'/solo/`f'"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

* CRC and length of a file ("absent" when there is none).
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

capture program drop _ld_seed
program define _ld_seed
    version 17.0
    args path
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "KEEP THIS TEXT" _n
    file close `fh'
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

* check_latex.py on a .tex file with the options that follow it; the verdict
* line must start with PASS.
capture program drop _ld_check
program define _ld_check
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    shell python3 "$LD_CHECKER" "`tex'" `0' --result "`res'"
    confirm file "`res'"
    mata: printf("{txt}  check_latex: %s\n", cat(st_local("res"))[1])
    mata: st_local("_ld_ok", strofreal(substr(cat(st_local("res"))[1], 1, 4) == "PASS"))
    assert `_ld_ok' == 1
end

* Needle file: one "kind<TAB>text" line per call argument pair.
capture program drop _ld_needle_file
program define _ld_needle_file
    version 17.0
    gettoken path 0 : 0
    tempname fh
    file open `fh' using "`path'", write text replace
    while `"`0'"' != "" {
        gettoken kind 0 : 0
        gettoken text 0 : 0
        file write `fh' `"`kind'"' _tab `"`text'"' _n
    }
    file close `fh'
end

* Does the file hold a line equal to text (exact), or containing text?
capture program drop _ld_hasline
program define _ld_hasline, rclass
    version 17.0
    args path text
    mata: st_local("_ld_h", strofreal(any(cat(st_local("path")) :== st_local("text"))))
    return scalar has = `_ld_h'
end
capture program drop _ld_hastext
program define _ld_hastext, rclass
    version 17.0
    args path text
    mata: st_local("_ld_h", strofreal(any(strpos(cat(st_local("path")), st_local("text")) :> 0)))
    return scalar has = `_ld_h'
end

* The column spanners the workbook merged in its header rows, in the
* writer's coordinates: "r:c1-c2,..." with r the header row within the
* block (hdr1 = 1) and c the visible-column index (workbook column A is the
* title column, so LaTeX column = workbook column - 1). Vertical single-column
* merges are counted in r(nvert): LaTeX has no multirow, so they are not
* spans.
capture program drop _ld_hspans
program define _ld_hspans, rclass
    version 17.0
    args book sheet hdr1 hdr2
    tempfile facts
    shell python3 "$LD_FACTS" "`book'" "`sheet'" "`facts'"
    confirm file "`facts'"
    local _ld_spans ""
    local _ld_nm 0
    local _ld_nv 0
    mata: _ld_hspans_parse(st_local("facts"), `hdr1', `hdr2')
    return local spans "`_ld_spans'"
    return scalar nmerge = `_ld_nm'
    return scalar nvert = `_ld_nv'
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
void _ld_hspans_parse(string scalar path, real scalar h1, real scalar h2)
{
    string colvector L
    string scalar out, rng, a, b
    real scalar i, nm, nv, r1, c1, r2, c2, p
    L = cat(path)
    out = ""
    nm = 0
    nv = 0
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 6) != "merge ") continue
        rng = substr(L[i], 7, .)
        p = strpos(rng, ":")
        a = substr(rng, 1, p - 1)
        b = substr(rng, p + 1, .)
        if (!regexm(a, "^([A-Z]+)([0-9]+)$")) continue
        c1 = _ld_colnum(regexs(1))
        r1 = strtoreal(regexs(2))
        if (!regexm(b, "^([A-Z]+)([0-9]+)$")) continue
        c2 = _ld_colnum(regexs(1))
        r2 = strtoreal(regexs(2))
        if (r1 < h1 | r2 > h2) continue
        nm++
        if (c2 > c1) out = out + (out == "" ? "" : ",") + sprintf("%g:%g-%g", r1 - h1 + 1, c1 - 1, c2 - 1)
        else nv++
    }
    st_local("_ld_spans", out)
    st_local("_ld_nm", strofreal(nm))
    st_local("_ld_nv", strofreal(nv))
}
end

* Full verification of one table: compile, shape, workbook-merge spanners,
* CSV body parity.
*   _ld_verify tex csv book sheet xh1 xh2 ncols nhdr nbody csvrows [extra]
capture program drop _ld_verify
program define _ld_verify, rclass
    version 17.0
    gettoken tex 0 : 0
    gettoken csv 0 : 0
    gettoken book 0 : 0
    gettoken sheet 0 : 0
    gettoken xh1 0 : 0
    gettoken xh2 0 : 0
    gettoken ncols 0 : 0
    gettoken nhdr 0 : 0
    gettoken nbody 0 : 0
    gettoken csvrows 0 : 0
    _ld_hspans "`book'" "`sheet'" `xh1' `xh2'
    local spans "`r(spans)'"
    display as text "  workbook header merges: `r(nmerge)' (vertical `r(nvert)'), spans `=cond("`spans'" == "", "none", "`spans'")'"
    if "`spans'" == "" local spans "none"
    _ld_check "`tex'" --compile --tables 1 --cols `ncols' --header-rows `nhdr' ///
        --body-rows `nbody' --spans "`spans'" --parity-csv "`csv'" ///
        --csv-rows "`csvrows'" `0'
    return local spans "`spans'"
end

capture program drop _ld_record
program define _ld_record
    args label rc passed failed
    if `rc' == 0 {
        display as result "  PASS: `label'"
        c_local pass_count = `passed' + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        c_local fail_count = `failed' + 1
    }
end

**# Fixtures
capture program drop _ld_auto
program define _ld_auto
    version 17.0
    sysuse auto, clear
    label define ld_fl 0 "Domestic" 1 "Foreign", replace
    label values foreign ld_fl
end

capture program drop _ld_wt
program define _ld_wt
    version 17.0
    clear
    set obs 200
    set seed 20261031
    generate byte group = _n > 100
    generate double x = rnormal() + group
    generate byte bin = runiform() < .4 + .2 * group
    generate double ipw = .5 + runiform()
    generate byte cat = 1 + (runiform() < .3) + (runiform() < .3)
    label define ld_gl 0 "Control" 1 "Treated", replace
    label values group ld_gl
end

* Small cells: group 0 has 2 and 8, group 1 has 6 and 4 in the two levels of
* a binary variable, so a printed count below 5 and a complementary cell exist.
capture program drop _ld_small
program define _ld_small
    version 17.0
    clear
    quietly set obs 4
    generate byte group = floor((_n - 1) / 2)
    generate byte category = mod(_n - 1, 2)
    generate int frequency = cond(_n == 1, 2, cond(_n == 2, 8, cond(_n == 3, 6, 4)))
    quietly expand frequency
    drop frequency
    generate double age = 40 + mod(_n, 17)
    label define ld_gs 0 "Alpha" 1 "Beta", replace
    label values group ld_gs
end

capture program drop _ld_surv
program define _ld_surv
    version 17.0
    sysuse cancer, clear
    generate byte arm = drug > 1
    label define ld_arm 0 "Placebo" 1 "Active", replace
    label values arm ld_arm
    quietly stset studytime, failure(died)
end

**# D1. desctab by() test smd total(after): every sink from one call
local ++test_count
capture noisily {
    _ld_auto
    quietly count if foreign == 0
    local n0 = r(N)
    quietly count if foreign == 1
    local n1 = r(N)
    local n = _N
    local f "`ld'/d1.tex"
    local fnote "Medians shown. \ Second paragraph."
    desctab price mpg rep78, by(foreign) test smd total(after) title("Auto data") ///
        footnote("`fnote'") latex("`f'") csv("`ld'/d1.csv") markdown("`ld'/d1.md") ///
        xlsx("`ld'/d1.xlsx") sheet(T)
    assert `"`r(latex)'"' == "`f'"
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == r(markdown_cols)
    * stub + 2 groups + test + total + p-value + SMD
    assert r(latex_cols) == 7
    * Price, Mileage, Repair record, five levels
    assert r(latex_rows) == 8
    _ld_verify "`f'" "`ld'/d1.csv" "`ld'/d1.xlsx" T 2 3 7 2 8 "4:-3"
    * The workbook merges only single columns vertically (stub, Test, p, SMD)
    assert r(spans) == "none"
    * Header block, hand-built from the group counts: two real header rows
    _ld_hasline "`f'" " & Domestic & Foreign & Test & Total & p-value & SMD \\"
    assert r(has)
    _ld_hasline "`f'" "No. (Column \%) or Median (Q1, Q3) & N=`n0' & N=`n1' &  & N=`n' &  &  \\"
    assert r(has)
    * Markdown flattens "Domestic (N=52)"; LaTeX must never see that state
    _ld_hastext "`ld'/d1.md" "Domestic (N=`n0')"
    assert r(has)
    _ld_hastext "`f'" "Domestic (N="
    assert !r(has)
    * Footnote paragraphs, hand-split on " \ "
    _ld_needle_file "`ld'/d1.needles" contains "Medians shown.\par" contains "Second paragraph.\par" ///
        pdftext "Medians shown." pdftext "Second paragraph." pdftext "Domestic" pdftext "Wilcoxon rank-sum" ///
        contains "p-value & SMD"
    _ld_check "`f'" --needles "`ld'/d1.needles"
}
_ld_record "D1 desctab by() test smd total(after): header block, merges, parity, unflattened" `=_rc' `pass_count' `fail_count'

* D1b. The same call with latex() alone writes the same bytes
local ++test_count
capture noisily {
    _ld_auto
    desctab price mpg rep78, by(foreign) test smd total(after) title("Auto data") ///
        footnote("Medians shown. \ Second paragraph.") latex("`ld'/solo/d1.tex")
    _ld_sum "`ld'/d1.tex"
    local a "`r(sum)'"
    _ld_sum "`ld'/solo/d1.tex"
    display as text "  all sinks `a' vs latex only `r(sum)'"
    assert "`r(sum)'" == "`a'"
    assert "`a'" != "absent"
}
_ld_record "D1b desctab latex() bytes do not depend on the other sinks" `=_rc' `pass_count' `fail_count'

**# D2. desctab without by()
local ++test_count
capture noisily {
    _ld_auto
    local f "`ld'/d2.tex"
    desctab price mpg rep78, vars(price contn \ mpg contn \ rep78 cat) title("Overall") ///
        latex("`f'") csv("`ld'/d2.csv") markdown("`ld'/d2.md") xlsx("`ld'/d2.xlsx")
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 2
    assert r(latex_rows) == 8
    _ld_verify "`f'" "`ld'/d2.csv" "`ld'/d2.xlsx" "Table 1" 2 3 2 2 8 "4:-1"
    assert r(spans) == "none"
    * Mean±SD: the plus-minus sign is typeset, not copied raw
    _ld_needle_file "`ld'/d2.needles" contains "Mean\ensuremath{\pm}SD & N=74" absent "±" pdftext "Total"
    _ld_check "`f'" --needles "`ld'/d2.needles"
}
_ld_record "D2 desctab without by(): Total only, two-row header" `=_rc' `pass_count' `fail_count'

**# D3. desctab total(before) test statistic
local ++test_count
capture noisily {
    _ld_auto
    local f "`ld'/d3.tex"
    desctab price mpg, by(foreign) test statistic total(before) latex("`f'") ///
        csv("`ld'/d3.csv") markdown("`ld'/d3.md") xlsx("`ld'/d3.xlsx") title("Total first")
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == r(markdown_cols)
    * stub + total + 2 groups + test + statistic + p-value
    assert r(latex_cols) == 7
    assert r(latex_rows) == 2
    _ld_verify "`f'" "`ld'/d3.csv" "`ld'/d3.xlsx" "Table 1" 2 3 7 2 2 "4:-1"
    assert r(spans) == "none"
    * Total precedes the groups in the header row, as in the CSV
    _ld_hastext "`f'" " & Total & Domestic & Foreign &"
    assert r(has)
}
_ld_record "D3 desctab total(before) test statistic" `=_rc' `pass_count' `fail_count'

**# D4. desctab wt() wtcompare
local ++test_count
capture noisily {
    _ld_wt
    local f "`ld'/d4.tex"
    desctab x bin cat, by(group) vars(x contn \ bin bin \ cat cat) wt(ipw) wtcompare wtn smd ///
        title("Weighted") latex("`f'") csv("`ld'/d4.csv") markdown("`ld'/d4.md") ///
        xlsx("`ld'/d4.xlsx")
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 6
    * Effective sample size, x, bin, cat and three levels
    assert r(latex_rows) == 7
    _ld_verify "`f'" "`ld'/d4.csv" "`ld'/d4.xlsx" "Table 1" 2 3 6 2 7 "4:-1"
    assert r(spans) == "none"
    _ld_hasline "`f'" " & Crude Control & Crude Treated & Weighted Control & Weighted Treated & SMD \\"
    assert r(has)
    _ld_hastext "`f'" "Effective sample size"
    assert r(has)
}
_ld_record "D4 desctab wt() wtcompare wtn smd" `=_rc' `pass_count' `fail_count'

**# D5. desctab smallcells(): masked cells render
local ++test_count
capture noisily {
    _ld_small
    local f "`ld'/d5.tex"
    desctab category, by(group) vars(category cat) smallcells(5) title("Masked") ///
        latex("`f'") csv("`ld'/d5.csv") markdown("`ld'/d5.md") xlsx("`ld'/d5.xlsx")
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == r(markdown_cols)
    * The suppression note is a footnote on every sink: CSV last row, last paragraph
    _ld_verify "`f'" "`ld'/d5.csv" "`ld'/d5.xlsx" "Table 1" 2 3 `=r(latex_cols)' 2 `=r(latex_rows)' "4:-2"
    assert r(spans) == "none"
    _ld_needle_file "`ld'/d5.needles" contains "\textless{}5" contains "\ensuremath{\geq}5" ///
        pdftext "<5" pdftext "≥5" pdftext "Counts below 5 are shown" absent "<5"
    _ld_check "`f'" --needles "`ld'/d5.needles"
    * and the masked text is what the CSV holds
    _ld_hastext "`ld'/d5.csv" "<5"
    assert r(has)
    _ld_hastext "`ld'/d5.csv" "≥5"
    assert r(has)
}
_ld_record "D5 desctab smallcells(5): <5 and >=5 render and match the CSV" `=_rc' `pass_count' `fail_count'

**# D6. table1_tc (forwards the whole command line to desctab)
local ++test_count
capture noisily {
    _ld_auto
    quietly count if foreign == 0
    local n0 = r(N)
    local f "`ld'/d6.tex"
    table1_tc price mpg rep78, by(foreign) test smd title("Wrapper") ///
        latex("`f'") csv("`ld'/d6.csv") markdown("`ld'/d6.md") xlsx("`ld'/d6.xlsx")
    assert `"`r(latex)'"' == "`f'"
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == r(markdown_cols)
    * stub + 2 groups + test + p-value + SMD
    assert r(latex_cols) == 6
    assert r(latex_rows) == 8
    _ld_verify "`f'" "`ld'/d6.csv" "`ld'/d6.xlsx" "Table 1" 2 3 6 2 8 "4:-1"
    assert r(spans) == "none"
    _ld_hasline "`f'" "No. (Column \%) or Median (Q1, Q3) & N=`n0' & N=`=_N-`n0'' &  &  &  \\"
    assert r(has)
    * no by(): the same wrapper, Total only
    table1_tc price mpg, vars(price contn \ mpg contn) title("Wrapper total") ///
        latex("`ld'/d6b.tex") csv("`ld'/d6b.csv") markdown("`ld'/d6b.md") xlsx("`ld'/d6b.xlsx")
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 2
    _ld_verify "`ld'/d6b.tex" "`ld'/d6b.csv" "`ld'/d6b.xlsx" "Table 1" 2 3 2 2 2 "4:-1"
    * the wrapper and desctab write the same bytes
    desctab price mpg, vars(price contn \ mpg contn) title("Wrapper total") ///
        latex("`ld'/solo/d6b.tex")
    _ld_sum "`ld'/d6b.tex"
    local a "`r(sum)'"
    _ld_sum "`ld'/solo/d6b.tex"
    assert "`r(sum)'" == "`a'"
    * texappend through the wrapper
    table1_tc price mpg, vars(price contn \ mpg contn) title("Second") ///
        latex("`ld'/d6b.tex") texappend
    _ld_check "`ld'/d6b.tex" --compile --tables 2
}
_ld_record "D6 table1_tc: latex(), texappend, same bytes as desctab" `=_rc' `pass_count' `fail_count'

**# D7. crosstab measure layouts
local ++test_count
capture noisily {
    _ld_auto
    generate byte hi = mpg > 20
    label define ld_hi 0 "Low mpg" 1 "High mpg", replace
    label values hi ld_hi
    quietly count if foreign == 0 & hi == 0
    local c00 = r(N)
    quietly count if hi == 0
    local m0 = r(N)
    local f "`ld'/d7a.tex"
    * 2x2 with OR, RR, RD and a trend line
    crosstab foreign hi, colpct or rr rd trend label title("Origin by mpg") ///
        latex("`f'") csv("`ld'/d7a.csv") markdown("`ld'/d7a.md") xlsx("`ld'/d7a.xlsx")
    assert `"`r(latex)'"' == "`f'"
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == r(markdown_cols)
    * row label + 2 columns + Total
    assert r(latex_cols) == 4
    * Domestic, Foreign, Total, test, OR, RR, RD, trend
    assert r(latex_rows) == 8
    _ld_verify "`f'" "`ld'/d7a.csv" "`ld'/d7a.xlsx" Crosstab 2 2 4 1 8 "3:-1"
    assert r(spans) == "none"
    _ld_hasline "`f'" "Car origin & Low mpg & High mpg & Total \\"
    assert r(has)
    _ld_hastext "`f'" "Domestic & `c00' ("
    assert r(has)
    _ld_hastext "`f'" "Total & `m0' &"
    assert r(has)
    * 3-level column variable, row percentages, Fisher, Cochran-Armitage trend
    local f "`ld'/d7b.tex"
    crosstab foreign rep78, rowpct fisher cochran title("Origin by repair") ///
        latex("`f'") csv("`ld'/d7b.csv") markdown("`ld'/d7b.md") xlsx("`ld'/d7b.xlsx")
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 7
    _ld_verify "`f'" "`ld'/d7b.csv" "`ld'/d7b.xlsx" Crosstab 2 2 7 1 `=r(latex_rows)' "3:-1"
    assert r(spans) == "none"
    _ld_hastext "`f'" "Fisher's exact test"
    assert r(has)
    * smallcells
    local f "`ld'/d7c.tex"
    crosstab foreign rep78, rowpct smallcells(5) title("Masked") footnote("Own note.") ///
        latex("`f'") csv("`ld'/d7c.csv") markdown("`ld'/d7c.md") xlsx("`ld'/d7c.xlsx")
    assert r(latex_rows) == r(markdown_rows)
    _ld_verify "`f'" "`ld'/d7c.csv" "`ld'/d7c.xlsx" Crosstab 2 2 7 1 `=r(latex_rows)' "3:-2"
    _ld_needle_file "`ld'/d7c.needles" contains "\textless{}5" contains "\ensuremath{\geq}5" ///
        pdftext "<5" pdftext "≥5" pdftext "Own note." pdftext "reconstruction"
    _ld_check "`f'" --needles "`ld'/d7c.needles"
}
_ld_record "D7 crosstab: 2x2 measures, 3-level rowpct/fisher/cochran, smallcells" `=_rc' `pass_count' `fail_count'

**# D8. survtab by() with several times()
local ++test_count
capture noisily {
    _ld_surv
    quietly count if arm == 0
    local n0 = r(N)
    quietly count if arm == 1
    local n1 = r(N)
    local f "`ld'/d8a.tex"
    survtab, times(10 20 30) by(arm) difference events median rmst(20) title("Survival") ///
        latex("`f'") csv("`ld'/d8a.csv") markdown("`ld'/d8a.md") xlsx("`ld'/d8a.xlsx")
    assert `"`r(latex)'"' == "`f'"
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == r(markdown_cols)
    * stub + 2 groups + Difference + p
    assert r(latex_cols) == 5
    * median, CI, events, three times, RMST, log-rank
    assert r(latex_rows) == 9
    _ld_verify "`f'" "`ld'/d8a.csv" "`ld'/d8a.xlsx" Survival 2 2 5 1 9 "3:-2" --pdftext "Survival probability"
    assert r(spans) == "none"
    _ld_hasline "`f'" " & Placebo (N=`n0') & Active (N=`n1') & Difference (Placebo - Active) & p \\"
    assert r(has)
    _ld_hastext "`f'" "\hspace*{1em}10 years"
    assert r(has)
    * no by(): one group
    survtab, times(10 20) median events latex("`ld'/d8b.tex") csv("`ld'/d8b.csv") ///
        markdown("`ld'/d8b.md") xlsx("`ld'/d8b.xlsx") title("Overall")
    assert r(latex_rows) == r(markdown_rows)
    assert r(latex_cols) == 2
    _ld_verify "`ld'/d8b.tex" "`ld'/d8b.csv" "`ld'/d8b.xlsx" Survival 2 2 2 1 `=r(latex_rows)' "3:-1"
    * three by() groups, no difference column
    survtab, times(10 20 30) by(drug) latex("`ld'/d8c.tex") csv("`ld'/d8c.csv") ///
        markdown("`ld'/d8c.md") xlsx("`ld'/d8c.xlsx") title("Three arms")
    assert r(latex_rows) == r(markdown_rows)
    * stub + 3 groups + p
    assert r(latex_cols) == 5
    _ld_verify "`ld'/d8c.tex" "`ld'/d8c.csv" "`ld'/d8c.xlsx" Survival 2 2 5 1 `=r(latex_rows)' "3:-2"
}
_ld_record "D8 survtab: by() difference, no by(), three groups" `=_rc' `pass_count' `fail_count'

**# D9. texappend across the four commands
local ++test_count
capture noisily {
    local f "`ld'/d9.tex"
    capture erase "`f'"
    _ld_auto
    desctab price mpg, by(foreign) title("First") latex("`f'")
    assert r(latex_cols) == 4
    generate byte hi = mpg > 20
    crosstab foreign hi, title("Second") latex("`f'") texappend
    assert r(latex_cols) == 4
    _ld_surv
    survtab, times(10 20) by(arm) title("Third") latex("`f'") texappend
    assert r(latex_cols) == 4
    _ld_auto
    table1_tc mpg, vars(mpg contn) title("Fourth") latex("`f'") texappend
    assert r(latex_cols) == 2
    _ld_check "`f'" --compile --tables 4
    _ld_check "`f'" --table 1 --cols 4
    _ld_check "`f'" --table 2 --cols 4
    _ld_check "`f'" --table 3 --cols 4
    _ld_check "`f'" --table 4 --cols 2
    * labels: the first table keeps the bare label; table k (k > 1) is stem-k
    _ld_needle_file "`ld'/d9.needles" contains "\label{tab:d9}" contains "\label{tab:d9-2}" ///
        contains "\label{tab:d9-3}" contains "\label{tab:d9-4}" absent "\label{tab:d9-1}" absent "\label{tab:d9-5}" ///
        pdftext "First" pdftext "Second" pdftext "Third" pdftext "Fourth"
    _ld_check "`f'" --needles "`ld'/d9.needles"
    * latex() without texappend replaces the whole file
    _ld_auto
    desctab price mpg, by(foreign) title("Again") latex("`f'")
    _ld_check "`f'" --compile --tables 1 --absent "Second"
    * texappend onto a file that does not exist yet creates it
    capture erase "`ld'/d9new.tex"
    crosstab foreign rep78, title("New") latex("`ld'/d9new.tex") texappend
    _ld_check "`ld'/d9new.tex" --compile --tables 1
}
_ld_record "D9 texappend: four commands in one file, label numbering, replace" `=_rc' `pass_count' `fail_count'

**# D10. session sink (tabtools set latex)
local ++test_count
capture noisily {
    local s "`ld'/d10.tex"
    local wb "`ld'/d10.xlsx"
    capture erase "`wb'"
    _ld_seed "`s'"
    tabtools set latex "`s'"
    tabtools set workbook "`wb'"
    _ld_auto
    * 1: sheet() uses the session sinks; the first write replaces the seed
    desctab price mpg, by(foreign) title("Session one") sheet(S1)
    assert `"`r(latex)'"' == "`s'"
    assert r(latex_cols) == 4
    _ld_check "`s'" --compile --tables 1 --absent "KEEP THIS TEXT"
    tabtools query
    assert "`r(latex_fresh)'" == "0"
    * 2: later writes append
    generate byte hi = mpg > 20
    crosstab foreign hi, title("Session two") sheet(S2)
    assert `"`r(latex)'"' == "`s'"
    assert r(latex_cols) == 4
    _ld_surv
    survtab, times(10 20) by(arm) title("Session three") sheet(S3)
    assert `"`r(latex)'"' == "`s'"
    assert r(latex_cols) == 4
    _ld_check "`s'" --compile --tables 3
    _ld_check "`s'" --table 1 --cols 4
    _ld_check "`s'" --table 2 --cols 4
    _ld_check "`s'" --table 3 --cols 4
    * 3: no sheet() means no session write, with or without other sinks
    _ld_sum "`s'"
    local before "`r(sum)'"
    _ld_auto
    desctab price mpg, by(foreign)
    assert `"`r(latex)'"' == ""
    desctab price mpg, by(foreign) csv("`ld'/d10.csv")
    assert `"`r(latex)'"' == ""
    _ld_sum "`s'"
    assert "`r(sum)'" == "`before'"
    * 4: an explicit latex() wins over the session target
    local o "`ld'/d10other.tex"
    capture erase "`o'"
    desctab price mpg, by(foreign) title("Explicit") sheet(S4) latex("`o'")
    assert `"`r(latex)'"' == "`o'"
    _ld_check "`o'" --compile --tables 1
    _ld_sum "`s'"
    assert "`r(sum)'" == "`before'"
    * 5: the same table-1 path for table1_tc
    table1_tc price mpg, by(foreign) title("Session wrapper") sheet(S5)
    assert `"`r(latex)'"' == "`s'"
    _ld_check "`s'" --compile --tables 4
    * 6: a session target already written this session is never replaced
    quietly tabtools set latex "`s'"
    desctab price mpg, by(foreign) title("Session six") sheet(S6)
    _ld_check "`s'" --compile --tables 5
    quietly tabtools set clear
}
local _ld_blockrc = _rc
capture tabtools set clear
_ld_record "D10 tabtools set latex: replace first, append later, only with sheet()" `_ld_blockrc' `pass_count' `fail_count'

**# D11. same-file and extension refusals leave targets byte-identical
local ++test_count
capture noisily {
    _ld_auto
    generate byte hi = mpg > 20
    local t "`ld'/d11.tex"
    local bad "`ld'/d11.txt"
    foreach pair in "csv" "markdown" "xlsx" {
        _ld_seed "`t'"
        _ld_sum "`t'"
        local before "`r(sum)'"
        _ld_console desctab price mpg, by(foreign) latex("`t'") `pair'("`t'") title(T)
        assert r(rc) == 198
        _ld_console crosstab foreign hi, latex("`t'") `pair'("`t'") title(T)
        assert r(rc) == 198
        _ld_console table1_tc price mpg, by(foreign) latex("`t'") `pair'("`t'") title(T)
        assert r(rc) == 198
        _ld_surv
        _ld_console survtab, times(10 20) by(arm) latex("`t'") `pair'("`t'") title(T)
        assert r(rc) == 198
        _ld_auto
        generate byte hi = mpg > 20
        _ld_sum "`t'"
        assert "`r(sum)'" == "`before'"
    }
    * the same file named by latex() and the CSV in another spelling
    _ld_seed "`ld'/d11.tex"
    _ld_sum "`ld'/d11.tex"
    local before "`r(sum)'"
    _ld_console desctab price mpg, by(foreign) latex("`ld'/d11.tex") csv("`ld'/./d11.tex")
    assert r(rc) == 198
    _ld_sum "`ld'/d11.tex"
    assert "`r(sum)'" == "`before'"
    * non-.tex target: refused, nothing created
    capture erase "`bad'"
    _ld_console desctab price mpg, by(foreign) latex("`bad'") title(T)
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', ".tex") > 0
    _ld_console table1_tc price mpg, by(foreign) latex("`bad'") title(T)
    assert r(rc) == 198
    _ld_console crosstab foreign hi, latex("`bad'") title(T)
    assert r(rc) == 198
    _ld_surv
    _ld_console survtab, times(10 20) by(arm) latex("`bad'") title(T)
    assert r(rc) == 198
    _ld_sum "`bad'"
    assert "`r(sum)'" == "absent"
}
_ld_record "D11 collision and extension refusals: targets unchanged" `=_rc' `pass_count' `fail_count'

**# D12. texappend without latex()
local ++test_count
capture noisily {
    _ld_auto
    generate byte hi = mpg > 20
    local m "`ld'/d12.md"
    _ld_seed "`m'"
    _ld_sum "`m'"
    local before "`r(sum)'"
    _ld_console desctab price mpg, by(foreign) texappend markdown("`m'")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "texappend requires latex()") > 0
    _ld_console table1_tc price mpg, by(foreign) texappend markdown("`m'")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "texappend requires latex()") > 0
    _ld_console crosstab foreign hi, texappend markdown("`m'")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "texappend requires latex()") > 0
    _ld_surv
    _ld_console survtab, times(10 20) by(arm) texappend markdown("`m'")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "texappend requires latex()") > 0
    _ld_sum "`m'"
    assert "`r(sum)'" == "`before'"
    * the mdappend refusal is unchanged
    _ld_auto
    _ld_console desctab price mpg, by(foreign) mdappend
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "mdappend requires markdown()") > 0
}
_ld_record "D12 texappend without latex() is r(198), markdown target untouched" `=_rc' `pass_count' `fail_count'

**# D13. latex() into a missing directory behaves like markdown()
local ++test_count
capture noisily {
    local bad_root "`ld'/__missing_export_dir__"
    * table1_tc
    _ld_auto
    return clear
    capture noisily table1_tc price mpg weight, by(foreign) latex("`bad_root'/t.tex")
    local tex_rc = _rc
    assert `tex_rc' != 0
    assert strpos("`r(varlist)'", "price") > 0
    tempname t1
    matrix `t1' = r(table)
    assert rowsof(`t1') > 0
    assert `"`r(latex)'"' == ""
    capture noisily table1_tc price mpg weight, by(foreign) markdown("`bad_root'/t.md")
    assert _rc == `tex_rc'
    * desctab direct, message shape
    _ld_console desctab price mpg weight, by(foreign) latex("`bad_root'/t.tex")
    assert r(rc) == `tex_rc'
    assert strpos(`"`r(text)'"', "Failed to export LaTeX to `bad_root'/t.tex") > 0
    _ld_console desctab price mpg weight, by(foreign) markdown("`bad_root'/t.md")
    assert strpos(`"`r(text)'"', "Failed to export Markdown to `bad_root'/t.md") > 0
    * crosstab
    clear
    input byte outcome byte exposure int freq
    0 0 40
    0 1 20
    1 0 10
    1 1 30
    end
    expand freq
    return clear
    capture noisily crosstab outcome exposure, latex("`bad_root'/c.tex")
    assert _rc == `tex_rc'
    assert r(N) == 100
    tempname ct
    matrix `ct' = r(table)
    assert rowsof(`ct') > 0
    assert `"`r(latex)'"' == ""
    capture noisily crosstab outcome exposure, markdown("`bad_root'/c.md")
    assert _rc == `tex_rc'
    _ld_console crosstab outcome exposure, latex("`bad_root'/c.tex")
    assert strpos(`"`r(text)'"', "Failed to export LaTeX to `bad_root'/c.tex") > 0
    * survtab
    _ld_surv
    return clear
    capture noisily survtab, times(10 20) by(arm) latex("`bad_root'/s.tex")
    assert _rc == `tex_rc'
    assert !missing(r(N_rows))
    assert r(N_rows) > 0
    tempname st
    matrix `st' = r(table)
    assert rowsof(`st') > 0
    assert `"`r(latex)'"' == ""
    capture noisily survtab, times(10 20) by(arm) markdown("`bad_root'/s.md")
    assert _rc == `tex_rc'
    _ld_console survtab, times(10 20) by(arm) latex("`bad_root'/s.tex")
    assert strpos(`"`r(text)'"', "Failed to export LaTeX to `bad_root'/s.tex") > 0
    * nothing was created, and an existing target survives a failed append
    capture confirm file "`bad_root'/t.tex"
    assert _rc != 0
    _ld_auto
    local keep "`ld'/d13keep.tex"
    desctab price mpg, by(foreign) title("Keep") latex("`keep'")
    _ld_sum "`keep'"
    local before "`r(sum)'"
    capture noisily desctab price mpg, by(foreign) latex("`bad_root'/x.tex") texappend
    assert _rc != 0
    _ld_sum "`keep'"
    assert "`r(sum)'" == "`before'"
}
_ld_record "D13 latex() failure: same rc and message shape as markdown(), r() preserved" `=_rc' `pass_count' `fail_count'

**# Summary
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_latex_descriptive tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _ld
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_latex_descriptive tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ld

* test_latex_composite_rates.do - latex()/texappend in comptab (composition
* and rateframe paths), hrcomptab, stratetab and ratetab
* (_take_action/tabtools_latex_export_2026-10-31.md, builder group B2):
*   R1  comptab composition: one call writes LaTeX, CSV, Markdown and xlsx;
*       compiles; columns; body parity with the CSV; model spanners equal
*       the workbook's merged header ranges; two header rows, no flattened
*       "model: statistic" text; r(latex*) = r(markdown*)
*   R2  comptab composition, compact: two-column model spanners
*   R3  comptab rateframe() with allmodels (two models under one outcome)
*   R4  hrcomptab, two outcomes
*   R5  stratetab, two outcomes, smallcells() masking
*   R6  ratetab, two outcomes (forwarded to stratetab)
*   R7  texappend: a second table appended, the first kept byte for byte
*   R8  tabtools set latex: the session file through sheet()
*   R9  same-file refusal (csv() and latex()), the pre-seeded file intact
*   R10 texappend without latex() is refused in every command
*   R11 export failure: latex() into a missing directory keeps the
*       analytical r() pinned by test_package_adversarial.do and the frame()
*       destination; a failed Markdown write behaves the same way
*       (stratetab, comptab composition and rateframe paths, hrcomptab)
*   R12 comptab composition with no model label, and with a label on only
*       some models: header block, spans, compile, CSV parity, Markdown
*   R13 the session LaTeX (and Markdown) file is ignored without sheet()
*   R14 a failed latex() through ratetab restores the caller's own r()
* Expected values come from the command's other outputs (the CSV it wrote,
* the merged ranges of the workbook it wrote, read with openpyxl via
* tools/xlsx_facts.py, r(N_rows)) and from hand-built strings; the .tex is
* judged by the independent checker tools/check_latex.py (pdflatex on the
* documented minimal preamble). Workbook column j is LaTeX column j - 1:
* workbook column A is the title/spacer column that no text sink writes.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _lcr
log using "test_latex_composite_rates.log", replace text name(_lcr)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local out "`output_dir'/lcr"
capture mkdir "`out'"
global LCR_CHECKER "`qa_dir'/tools/check_latex.py"
global LCR_FACTS "`qa_dir'/tools/xlsx_facts.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

**# Helpers
* check_latex.py on tex with the given options; must report PASS.
capture program drop _lcr_check
program define _lcr_check
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    shell python3 "$LCR_CHECKER" "`tex'" `0' --result "`res'"
    confirm file "`res'"
    mata: printf("{txt}  check_latex: %s\n", cat(st_local("res"))[1])
    mata: st_local("_ok", strofreal(substr(cat(st_local("res"))[1], 1, 4) == "PASS"))
    assert `_ok' == 1
end

* Needles file for --needles: pairs of kind and text after the path.
capture program drop _lcr_needles
program define _lcr_needles
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

* CRC and length of a file ("absent" when there is none).
capture program drop _lcr_sum
program define _lcr_sum, rclass
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

* r(found) = 1 when file contains needle; r(count) = occurrences.
capture program drop _lcr_has
program define _lcr_has, rclass
    version 17.0
    args path needle
    mata: _lcr_t = invtokens(cat(st_local("path"))', char(10))
    mata: st_local("_n", strofreal((strlen(_lcr_t) - strlen(subinstr(_lcr_t, st_local("needle"), ""))) / max((strlen(st_local("needle")), 1))))
    return scalar count = `_n'
    return scalar found = (`_n' > 0)
end

* Number of columns of a CSV, read by import delimited in a scratch frame.
capture program drop _lcr_csvcols
program define _lcr_csvcols, rclass
    version 17.0
    args path
    tempname fr
    frame create `fr'
    frame `fr' {
        quietly import delimited using "`path'", varnames(nonames) stringcols(_all) clear
        local k = c(k)
    }
    frame drop `fr'
    return scalar k = `k'
end

* Header spans of the workbook (merged ranges inside row 2, mapped to LaTeX
* columns as workbook column - 1) as a check_latex --spans string in
* r(spans), and a needles file with one "contains \multicolumn{w}{c}{text}"
* line per merge, text being the workbook's own anchor cell.
capture program drop _lcr_merges
program define _lcr_merges, rclass
    version 17.0
    args book sheet facts needles
    capture erase "`facts'"
    capture erase "`needles'"
    shell python3 "$LCR_FACTS" "`book'" "`sheet'" "`facts'"
    confirm file "`facts'"
    mata: _lcr_merge_spans(st_local("facts"), st_local("needles"))
    return local spans "`_spans'"
    return scalar n = `_nspans'
end

mata:
real scalar _lcr_colnum(string scalar letters)
{
    real scalar i, n
    n = 0
    for (i = 1; i <= strlen(letters); i++) {
        n = n * 26 + ascii(substr(letters, i, 1))[1] - 64
    }
    return(n)
}

void _lcr_merge_spans(string scalar facts, string scalar needles)
{
    string colvector L
    string scalar spans, a, b, ca, cb, txt, anchor
    real scalar i, j, k, fh, ra, rb, c1, c2, nsp
    L = cat(facts)
    spans = ""
    nsp = 0
    fh = fopen(needles, "w")
    for (i = 1; i <= rows(L); i++) {
        if (!regexm(L[i], "^merge ([A-Z]+)([0-9]+):([A-Z]+)([0-9]+)$")) continue
        ca = regexs(1); ra = strtoreal(regexs(2))
        cb = regexs(3); rb = strtoreal(regexs(4))
        if (ra != 2 | rb != 2) continue
        c1 = _lcr_colnum(ca) - 1
        c2 = _lcr_colnum(cb) - 1
        spans = spans + (spans == "" ? "" : ",") + "1:" + strofreal(c1) + "-" + strofreal(c2)
        nsp++
        anchor = "value " + ca + "2 "
        txt = ""
        for (j = 1; j <= rows(L); j++) {
            if (substr(L[j], 1, strlen(anchor)) == anchor) txt = substr(L[j], strlen(anchor) + 1, .)
        }
        fput(fh, "contains" + char(9) + "\multicolumn{" + strofreal(c2 - c1 + 1) + "}{c}{" + txt + "}")
    }
    fclose(fh)
    st_local("_spans", spans)
    st_local("_nspans", strofreal(nsp))
}
end

* Console text of a command (nested log) in r(text), its rc in r(rc).
capture program drop _lcr_console
program define _lcr_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_lcr_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _lcr_capture
    mata: st_local("_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_txt)'"'
    return scalar rc = `crc'
end

**# Fixtures
* Composition: two regtab frames, two models each.
capture program drop _lcr_comp_frames
program define _lcr_comp_frames
    version 17.0
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    quietly regtab, frame(_lcf1, replace) noint models("Base \ Adjusted")
    collect clear
    quietly collect: regress price i.rep78 mpg
    quietly collect: regress price i.rep78 mpg foreign
    quietly regtab, frame(_lcf2, replace) noint models("Base \ Adjusted")
end

* Rates: strate files for two outcomes, stratetab frames with one and two
* outcomes, Cox model frames to compose with them.
capture program drop _lcr_rate_frames
program define _lcr_rate_frames
    version 17.0
    args out
    sysuse cancer, clear
    generate byte early = died & studytime < 15
    quietly stset studytime, failure(died)
    quietly strate drug, output("`out'/lcr_r1", replace)
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly collect: stcox i.drug age, nolog
    quietly regtab, models("Unadjusted \ Adjusted") frame(_lchr1, replace) noint
    collect clear
    quietly collect: stcox i.drug, nolog
    quietly stset studytime, failure(early)
    quietly strate drug, output("`out'/lcr_r2", replace)
    quietly collect: stcox i.drug, nolog
    quietly regtab, models("Death \ Early death") frame(_lchr2, replace) noint
    quietly stratetab, using("`out'/lcr_r1") outcomes(1) outlabels("Death") ///
        explabels("Drug") frame(_lcrt1, replace)
    quietly stratetab, using("`out'/lcr_r1" "`out'/lcr_r2") outcomes(2) ///
        outlabels("Death \ Early death") explabels("Drug") frame(_lcrt2, replace)
end

* The checks every layout gets, from one call that wrote tex, csv, md and
* xlsx: compile, columns (= the CSV's), two header rows, body rows
* (= r(N_rows) - 3, the title and two header rows), body parity with the
* CSV body (the CSV leaves out an empty title row, so its body starts on
* row 4 with a title and on row 3 without: csvstart()), spanners = the
* workbook's merged row-2 ranges and the hand-built spans, r(latex_rows) = r(markdown_rows), r(latex_cols) =
* r(markdown_cols) = the CSV's columns. Call right after the command.
capture program drop _lcr_layout
program define _lcr_layout
    version 17.0
    syntax , STEM(string) SHEET(string) SPANS(string) COLS(integer) [NEEDLES(string) CSVSTART(integer 3)]
    local nrows = r(N_rows)
    local lrows = r(latex_rows)
    local mrows = r(markdown_rows)
    local lcols = r(latex_cols)
    local mcols = r(markdown_cols)
    local ltex `"`r(latex)'"'
    assert `"`ltex'"' == "`stem'.tex"
    assert `lrows' == `nrows' - 3
    assert `lrows' == `mrows'
    assert `lcols' == `mcols'
    _lcr_csvcols "`stem'.csv"
    assert r(k) == `cols'
    assert `lcols' == `cols'
    _lcr_merges "`stem'.xlsx" "`sheet'" "`stem'_facts.txt" "`stem'_wbneedles.txt"
    display as text "  workbook header merges -> LaTeX spans: `r(spans)'"
    assert "`r(spans)'" != ""
    local wbspans "`r(spans)'"
    _lcr_check "`stem'.tex" --compile --cols `cols' --header-rows 2 ///
        --body-rows `=`nrows' - 3' --spans "`wbspans'" --needles "`stem'_wbneedles.txt"
    _lcr_check "`stem'.tex" --spans "`spans'" ///
        --parity-csv "`stem'.csv" --csv-rows `csvstart':`=`csvstart' + `nrows' - 4'
    if `"`needles'"' != "" _lcr_check "`stem'.tex" --needles "`needles'"
end

**# R1: comptab composition, all sinks from one call
capture noisily {
    _lcr_comp_frames
    local s "`out'/lcr_comp"
    foreach e in tex csv md xlsx {
        capture erase "`s'.`e'"
    }
    * hand-built: one stub column + two models x (Coef., 95% CI, p-value)
    _lcr_needles "`s'_needles.txt" ///
        contains "\multicolumn{3}{c}{Base} & \multicolumn{3}{c}{Adjusted} \\" ///
        contains "\cmidrule(lr){2-4} \cmidrule(lr){5-7}" ///
        contains " & Coef. & 95\% CI & p-value & Coef. & 95\% CI & p-value \\" ///
        contains "\caption{price \& weight}" ///
        pdftext "Table 1: price & weight" pdftext-absent "Table 2: price" ///
        contains "Second note, 50\% shown.\par" ///
        absent "Base:" absent "Adjusted:" ///
        pdftext "Linear terms" pdftext "Repair record"
    comptab _lcf1 _lcf2, rows(1 2 \ 5) section("Linear terms" \ "Repair record") ///
        xlsx("`s'.xlsx") sheet("C1") csv("`s'.csv") markdown("`s'.md") latex("`s'.tex") ///
        title("Table 2: price & weight") footnote("First note. \ Second note, 50% shown.")
    _lcr_layout, stem("`s'") sheet("C1") spans("1:2-4,1:5-7") cols(7) needles("`s'_needles.txt") csvstart(4)
    * the label appears only as the spanner (never flattened into a cell)
    _lcr_has "`s'.tex" "Base"
    assert r(count) == 1
    * ... while Markdown, one header row, writes "model: statistic"
    _lcr_has "`s'.md" "| Base: Coef. | Base: 95% CI | Base: p-value | Adjusted: Coef. |"
    assert r(found)
}
if _rc == 0 {
    display as result "  PASS: R1 comptab composition: compiles, parity, spanners = workbook merges, r(latex*) = r(markdown*)"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 comptab composition (rc=`=_rc')"
    local ++fail_count
}

**# R2: comptab composition, compact (two columns per model)
capture noisily {
    _lcr_comp_frames
    local s "`out'/lcr_compact"
    foreach e in tex csv md xlsx {
        capture erase "`s'.`e'"
    }
    _lcr_needles "`s'_needles.txt" ///
        contains "\multicolumn{2}{c}{Base} & \multicolumn{2}{c}{Adjusted} \\" ///
        absent "Base:" absent "\caption"
    comptab _lcf1, rows(1 2) compact ///
        xlsx("`s'.xlsx") sheet("C2") csv("`s'.csv") markdown("`s'.md") latex("`s'.tex")
    _lcr_layout, stem("`s'") sheet("C2") spans("1:2-3,1:4-5") cols(5) needles("`s'_needles.txt")
}
if _rc == 0 {
    display as result "  PASS: R2 comptab compact: two-column spanners equal the workbook merges"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 comptab compact (rc=`=_rc')"
    local ++fail_count
}

**# R3: comptab rateframe(), allmodels (K = 2 under one outcome)
capture noisily {
    _lcr_rate_frames "`out'"
    local s "`out'/lcr_rate1"
    foreach e in tex csv md xlsx {
        capture erase "`s'.`e'"
    }
    * 1 + (events, PY, rate, 2 x (aHR, p)) = 8 columns, one outcome spanner
    _lcr_needles "`s'_needles.txt" ///
        contains "\multicolumn{7}{c}{Death} \\" ///
        contains "\cmidrule(lr){2-8}" ///
        contains "Exposure & Events & Person-Years (PY) & Per 1,000 PY (95\% CI) & Unadjusted, aHR (95\% CI) & Unadjusted, p-value & Adjusted, aHR (95\% CI) & Adjusted, p-value \\" ///
        absent "Death:" absent "Death &"
    comptab _lchr1, rateframe(_lcrt1) rows(3/4) allmodels ///
        xlsx("`s'.xlsx") sheet("C3") csv("`s'.csv") markdown("`s'.md") latex("`s'.tex")
    _lcr_layout, stem("`s'") sheet("C3") spans("1:2-8") cols(8) needles("`s'_needles.txt")
    _lcr_has "`s'.md" "| Exposure | Death: Events | Death: Person-Years (PY) |"
    assert r(found)
}
if _rc == 0 {
    display as result "  PASS: R3 comptab rateframe(): outcome spanner over K = 2 model blocks"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 comptab rateframe() (rc=`=_rc')"
    local ++fail_count
}

**# R4: hrcomptab, two outcomes
capture noisily {
    _lcr_rate_frames "`out'"
    local s "`out'/lcr_hrc"
    foreach e in tex csv md xlsx {
        capture erase "`s'.`e'"
    }
    _lcr_needles "`s'_needles.txt" ///
        contains "\multicolumn{5}{c}{Death} & \multicolumn{5}{c}{Early death} \\" ///
        contains "\cmidrule(lr){2-6} \cmidrule(lr){7-11}" ///
        contains "Exposure & Events & Person-Years (PY) & Per 1,000 PY (95\% CI) & HR (95\% CI) & p-value & Events & Person-Years (PY) & Per 1,000 PY (95\% CI) & HR (95\% CI) & p-value \\" ///
        absent "Death:" absent "Early death:"
    hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) effect("HR") ///
        outcomemap(Death \ Early death) ///
        xlsx("`s'.xlsx") sheet("C4") csv("`s'.csv") markdown("`s'.md") latex("`s'.tex")
    _lcr_layout, stem("`s'") sheet("C4") spans("1:2-6,1:7-11") cols(11) needles("`s'_needles.txt")
    _lcr_has "`s'.tex" "Exposure"
    assert r(count) == 1
}
if _rc == 0 {
    display as result "  PASS: R4 hrcomptab: two outcome spanners equal the workbook merges"
    local ++pass_count
}
else {
    display as error "  FAIL: R4 hrcomptab (rc=`=_rc')"
    local ++fail_count
}

**# R5: stratetab, two outcomes, smallcells masking
capture noisily {
    _lcr_rate_frames "`out'"
    local s "`out'/lcr_strate"
    foreach e in tex csv md xlsx {
        capture erase "`s'.`e'"
    }
    * masked cells: "<10" and the en dash, as LaTeX text
    _lcr_needles "`s'_needles.txt" ///
        contains "\multicolumn{3}{c}{Death} & \multicolumn{3}{c}{Early death} \\" ///
        contains "\cmidrule(lr){2-4} \cmidrule(lr){5-7}" ///
        contains "Exposure & Events & Person-Years (PY) & Per 1,000 PY (95\% CI) & Events & Person-Years (PY) & Per 1,000 PY (95\% CI) \\" ///
        contains "\textless{}10 & -- & --" ///
        absent "Death:" absent "Early death:" ///
        pdftext "<10"
    stratetab, using("`out'/lcr_r1" "`out'/lcr_r2") outcomes(2) ///
        outlabels("Death \ Early death") explabels("Drug") smallcells(10) ///
        xlsx("`s'.xlsx") sheet("S5") csv("`s'.csv") markdown("`s'.md") latex("`s'.tex")
    assert r(smallcells) == 10
    _lcr_layout, stem("`s'") sheet("S5") spans("1:2-4,1:5-7") cols(7) needles("`s'_needles.txt")
    _lcr_has "`s'.tex" "Exposure"
    assert r(count) == 1
    _lcr_has "`s'.csv" "<10"
    assert r(found)
}
if _rc == 0 {
    display as result "  PASS: R5 stratetab two outcomes, smallcells: masked cells, spanners, parity"
    local ++pass_count
}
else {
    display as error "  FAIL: R5 stratetab (rc=`=_rc')"
    local ++fail_count
}

**# R6: ratetab, two outcomes (latex() forwarded to stratetab)
capture noisily {
    sysuse cancer, clear
    generate byte early = died & studytime < 15
    generate double pt = studytime
    generate double pt2 = studytime
    local s "`out'/lcr_ratetab"
    foreach e in tex csv md xlsx {
        capture erase "`s'.`e'"
    }
    _lcr_needles "`s'_needles.txt" ///
        contains "\multicolumn{3}{c}{Death} & \multicolumn{3}{c}{Early death} \\" ///
        absent "Death:"
    ratetab drug, events(died early) exposure(pt pt2) outlabels("Death \ Early death") ///
        xlsx("`s'.xlsx") sheet("R6") csv("`s'.csv") markdown("`s'.md") latex("`s'.tex")
    _lcr_layout, stem("`s'") sheet("R6") spans("1:2-4,1:5-7") cols(7) needles("`s'_needles.txt")
}
if _rc == 0 {
    display as result "  PASS: R6 ratetab forwards latex(): spanners, parity, r(latex*)"
    local ++pass_count
}
else {
    display as error "  FAIL: R6 ratetab (rc=`=_rc')"
    local ++fail_count
}

**# R7: texappend keeps the first table byte for byte
capture noisily {
    _lcr_comp_frames
    _lcr_rate_frames "`out'"
    _lcr_comp_frames
    local i 0
    foreach cmd in comp hrc strate ratetab {
        local ++i
        local f "`out'/lcr_app_`cmd'.tex"
        capture erase "`f'"
        if "`cmd'" == "comp" {
            local c1 `"comptab _lcf1, rows(1 2) latex("`f'") title("First")"'
            local c2 `"comptab _lcf1, rows(1) latex("`f'") texappend title("Second")"'
        }
        if "`cmd'" == "hrc" {
            local c1 `"hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) outcomemap(Death \ Early death) latex("`f'") title("First")"'
            local c2 `"hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) outcomemap(Death \ Early death) latex("`f'") texapp title("Second")"'
        }
        if "`cmd'" == "strate" {
            local c1 `"stratetab, using("`out'/lcr_r1") outcomes(1) latex("`f'") title("First")"'
            local c2 `"stratetab, using("`out'/lcr_r1" "`out'/lcr_r2") outcomes(2) latex("`f'") texappend title("Second")"'
        }
        if "`cmd'" == "ratetab" {
            local c1 `"ratetab drug, latex("`f'") title("First")"'
            local c2 `"ratetab drug, latex("`f'") texappend title("Second")"'
        }
        if "`cmd'" == "ratetab" {
            sysuse cancer, clear
            quietly stset studytime, failure(died)
        }
        quietly `c1'
        copy "`f'" "`f'.first", replace
        quietly `c2'
        assert `"`r(latex)'"' == "`f'"
        * the appended file starts with the first file's lines, unchanged
        mata: _lcr_a = cat(st_local("f") + ".first"); _lcr_b = cat(st_local("f"))
        mata: st_local("_pre", strofreal(rows(_lcr_b) > rows(_lcr_a) & _lcr_b[|1 \ rows(_lcr_a)|] == _lcr_a))
        assert `_pre' == 1
        _lcr_needles "`out'/lcr_app_`cmd'_n.txt" ///
            contains "\label{tab:lcr_app_`cmd'}" contains "\label{tab:lcr_app_`cmd'-2}" ///
            contains "\caption{Second}"
        _lcr_check "`f'" --compile --tables 2 --needles "`out'/lcr_app_`cmd'_n.txt"
    }
}
if _rc == 0 {
    display as result "  PASS: R7 texappend: comptab, hrcomptab, stratetab, ratetab append a second table; first kept"
    local ++pass_count
}
else {
    display as error "  FAIL: R7 texappend (rc=`=_rc')"
    local ++fail_count
}

**# R8: tabtools set latex, through sheet() (as the session Markdown file)
capture noisily {
    _lcr_comp_frames
    _lcr_rate_frames "`out'"
    _lcr_comp_frames
    foreach cmd in comp hrc strate ratetab {
        local f "`out'/lcr_sess_`cmd'.tex"
        local wb "`out'/lcr_sess_`cmd'.xlsx"
        capture erase "`wb'"
        * a stale file: the first session write replaces it
        _lcr_needles "`f'" contains "STALE"
        quietly tabtools set latex "`f'"
        if "`cmd'" == "comp" local c `"comptab _lcf1, rows(1 2) xlsx("`wb'")"'
        if "`cmd'" == "hrc" local c `"hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) outcomemap(Death \ Early death) xlsx("`wb'")"'
        if "`cmd'" == "strate" local c `"stratetab, using("`out'/lcr_r1") outcomes(1) xlsx("`wb'")"'
        if "`cmd'" == "ratetab" {
            sysuse cancer, clear
            quietly stset studytime, failure(died)
            local c `"ratetab drug, xlsx("`wb'")"'
        }
        quietly `c' sheet("One")
        local p1 `"`r(latex)'"'
        local r1 = r(latex_rows)
        quietly `c' sheet("Two")
        local p2 `"`r(latex)'"'
        quietly tabtools query
        local fresh "`r(latex_fresh)'"
        quietly tabtools set latex clear
        assert `"`p1'"' != "" & `"`p2'"' != ""
        assert `r1' > 0 & `r1' < .
        assert "`fresh'" == "0"
        _lcr_has "`f'" "STALE"
        assert r(found) == 0
        _lcr_check "`f'" --compile --tables 2
    }
}
* tabtools set clear runs captures of its own and resets _rc: save it first
local _blk_rc = _rc
quietly tabtools set clear
if `_blk_rc' == 0 {
    display as result "  PASS: R8 tabtools set latex: first sheet() write replaces, second appends (all four commands)"
    local ++pass_count
}
else {
    display as error "  FAIL: R8 session LaTeX sink (rc=`_blk_rc')"
    local ++fail_count
}

**# R9: csv() and latex() naming one file are refused; the file is kept
capture noisily {
    _lcr_comp_frames
    _lcr_rate_frames "`out'"
    _lcr_comp_frames
    local f "`out'/lcr_same.tex"
    _lcr_needles "`f'" contains "KEEP THIS TEXT"
    _lcr_sum "`f'"
    local before "`r(sum)'"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    foreach c in ///
        `"comptab _lcf1, rows(1 2) csv("`f'") latex("`f'")"' ///
        `"comptab _lchr1, rateframe(_lcrt1) rows(3/4) allmodels csv("`f'") latex("`f'")"' ///
        `"hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) outcomemap(Death \ Early death) csv("`f'") latex("`f'")"' ///
        `"stratetab, using("`out'/lcr_r1") outcomes(1) csv("`f'") latex("`f'")"' ///
        `"ratetab drug, csv("`f'") latex("`f'")"' {
        _lcr_console `c'
        local crc = r(rc)
        local txt `"`r(text)'"'
        _lcr_sum "`f'"
        display as text "  rc=`crc'; checksum `before' -> `r(sum)'"
        assert `crc' == 198
        assert "`r(sum)'" == "`before'"
        assert strpos(`"`txt'"', "csv() and latex() name the same file") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: R9 same-file refusal in every command; the pre-seeded file is unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: R9 same-file refusal (rc=`=_rc')"
    local ++fail_count
}

**# R10: texappend without latex() is refused
capture noisily {
    _lcr_comp_frames
    _lcr_rate_frames "`out'"
    _lcr_comp_frames
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    foreach c in ///
        `"comptab _lcf1, rows(1 2) texappend"' ///
        `"comptab _lchr1, rateframe(_lcrt1) rows(3/4) allmodels texapp"' ///
        `"hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) outcomemap(Death \ Early death) texappend"' ///
        `"stratetab, using("`out'/lcr_r1") outcomes(1) texappend"' ///
        `"ratetab drug, texappend"' {
        _lcr_console `c'
        assert r(rc) == 198
        assert strpos(`"`r(text)'"', "texappend requires latex()") > 0
    }
}
if _rc == 0 {
    display as result "  PASS: R10 texappend without latex() is r(198) in every command"
    local ++pass_count
}
else {
    display as error "  FAIL: R10 texappend without latex() (rc=`=_rc')"
    local ++fail_count
}

**# R11: a failed LaTeX (and Markdown) write keeps the analytical r()
* The r() pinned by test_package_adversarial.do ("... preserves r() after
* export failure"), against the same call without an export; the frame()
* destination is not touched; the LaTeX and Markdown failures share rc and
* message shape.
capture noisily {
    local bad "`out'/__missing_latex_dir__"
    _lcr_comp_frames
    _lcr_rate_frames "`out'"
    _lcr_comp_frames
    local i 0
    foreach cmd in strate comp rate hrc {
        if "`cmd'" == "strate" {
            local base `"stratetab, using("`out'/lcr_r1" "`out'/lcr_r2") outcomes(2)"'
            local pins "N_rows N_exposures N_outcomes"
        }
        if "`cmd'" == "comp" {
            local base `"comptab _lcf1 _lcf2, rows(1 \ 1)"'
            local pins "N_rows N_frames N_models N_cols"
        }
        if "`cmd'" == "rate" {
            local base `"comptab _lchr1, rateframe(_lcrt1) rows(3/4) allmodels"'
            local pins "N_rows N_outcomes N_modelframes N_models_per_outcome N_modelrows"
        }
        if "`cmd'" == "hrc" {
            local base `"hrcomptab _lcrt2, modelframes(_lchr2) rows(3/4) outcomemap(Death \ Early death)"'
            local pins "N_rows N_outcomes N_modelframes"
        }
        quietly `base'
        foreach p of local pins {
            local want_`p' = r(`p')
        }
        if "`cmd'" == "strate" {
            tempname want_rates
            matrix `want_rates' = r(rates)
        }
        foreach sink in latex markdown {
            local ext = cond("`sink'" == "latex", "tex", "md")
            local lbl = cond("`sink'" == "latex", "LaTeX", "Markdown")
            capture frame drop _lcr_dest
            frame create _lcr_dest
            frame _lcr_dest: quietly set obs 1
            frame _lcr_dest: generate str8 sentinel = "old"
            return clear
            _lcr_console `base' `sink'("`bad'/x.`ext'") frame(_lcr_dest, replace)
            local rc_`sink' = r(rc)
            local txt `"`r(text)'"'
            * r() after the failed call: _lcr_console is rclass, so rerun
            * the call itself to read the command's own returns
            return clear
            capture `base' `sink'("`bad'/x.`ext'") frame(_lcr_dest, replace)
            assert _rc == `rc_`sink''
            foreach p of local pins {
                display as text "  `cmd' `sink' failure: r(`p') = " r(`p') " (want `want_`p'')"
                assert r(`p') == `want_`p''
            }
            if "`cmd'" == "strate" {
                assert mreldif(r(rates), `want_rates') == 0
                assert `"`r(xlsx)'"' == ""
            }
            assert `"`r(`sink')'"' == ""
            assert strpos(`"`txt'"', "Failed to export `lbl' to `bad'/x.`ext'") > 0
            frame _lcr_dest: assert sentinel[1] == "old" & _N == 1
            capture confirm file "`bad'/x.`ext'"
            assert _rc != 0
        }
        assert `rc_latex' == `rc_markdown'
        assert `rc_latex' != 0
    }
    capture frame drop _lcr_dest
}
if _rc == 0 {
    display as result "  PASS: R11 failed latex()/markdown(): same rc and message shape; analytical r() and frame() kept"
    local ++pass_count
}
else {
    display as error "  FAIL: R11 export failure (rc=`=_rc')"
    local ++fail_count
}

**# R12: comptab composition with no model label, and with some labels
* A model label lives in row 2 of the source frame; the fixtures blank it
* there (both models, or the second only). Expected header rows, spans and
* Markdown header lines are hand-built; parity is with the CSV the same call
* wrote (the CSV leaves out all-blank rows: with no label at all its header
* is one row, so its body starts on row 2).
capture noisily {
    _lcr_comp_frames
    capture frame drop _lcfn
    capture frame drop _lcfm
    frame copy _lcf1 _lcfn
    frame _lcfn: quietly replace c1 = "" in 2
    frame _lcfn: quietly replace c4 = "" in 2
    frame copy _lcf1 _lcfm
    frame _lcfm: quietly replace c4 = "" in 2
    foreach case in none mixed {
        local s "`out'/lcr_lab_`case'"
        foreach e in tex csv md xlsx {
            capture erase "`s'.`e'"
        }
        local src = cond("`case'" == "none", "_lcfn", "_lcfm")
        comptab `src', rows(1 2) ///
            xlsx("`s'.xlsx") sheet("L") csv("`s'.csv") markdown("`s'.md") latex("`s'.tex")
        local nrows = r(N_rows)
        assert r(latex_rows) == `nrows' - 3
        assert r(latex_rows) == r(markdown_rows)
        assert r(latex_cols) == r(markdown_cols)
        assert r(latex_cols) == 7
        _lcr_csvcols "`s'.csv"
        assert r(k) == 7
        if "`case'" == "none" {
            _lcr_needles "`s'_needles.txt" ///
                contains "\toprule" ///
                contains " & Coef. & 95\% CI & p-value & Coef. & 95\% CI & p-value \\" ///
                absent "\multicolumn" absent "\cmidrule" absent "Base"
            _lcr_check "`s'.tex" --compile --cols 7 --header-rows 1 ///
                --body-rows `=`nrows' - 3' --spans none --needles "`s'_needles.txt" ///
                --parity-csv "`s'.csv" --csv-rows 2:`=`nrows' - 2'
            _lcr_has "`s'.md" "|  | Coef. | 95% CI | p-value | Coef. | 95% CI | p-value |"
            assert r(found)
        }
        else {
            _lcr_needles "`s'_needles.txt" ///
                contains " & \multicolumn{3}{c}{Base} &  &  &  \\" ///
                contains "\cmidrule(lr){2-4}" ///
                contains " & Coef. & 95\% CI & p-value & Coef. & 95\% CI & p-value \\" ///
                absent "Base:" absent "Adjusted"
            _lcr_check "`s'.tex" --compile --cols 7 --header-rows 2 ///
                --body-rows `=`nrows' - 3' --spans "1:2-4" --needles "`s'_needles.txt" ///
                --parity-csv "`s'.csv" --csv-rows 3:`=`nrows' - 1'
            * the declared span is the workbook's merge over the labelled model
            _lcr_merges "`s'.xlsx" "L" "`s'_facts.txt" "`s'_wbneedles.txt"
            assert strpos(",`r(spans)',", ",1:2-4,") > 0
            * Markdown: only the labelled model is prefixed
            _lcr_has "`s'.md" "|  | Base: Coef. | Base: 95% CI | Base: p-value | Coef. | 95% CI | p-value |"
            assert r(found)
        }
    }
    frame drop _lcfn
    frame drop _lcfm
}
if _rc == 0 {
    display as result "  PASS: R12 comptab composition, no label / some labels: header block, spans, compile, parity, Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: R12 comptab composition model labels (rc=`=_rc')"
    local ++fail_count
}

**# R13: the session LaTeX file is ignored without sheet()
* As the session Markdown file is: comptab and stratetab apply session
* destinations only when sheet() asks for a sheet. Both session files are
* pre-seeded; their checksums must not move and no path is returned.
capture noisily {
    _lcr_comp_frames
    _lcr_rate_frames "`out'"
    _lcr_comp_frames
    local ft "`out'/lcr_nosheet.tex"
    local fm "`out'/lcr_nosheet.md"
    _lcr_needles "`ft'" contains "KEEP THIS TEXT"
    _lcr_needles "`fm'" contains "KEEP THIS TEXT"
    _lcr_sum "`ft'"
    local st0 "`r(sum)'"
    _lcr_sum "`fm'"
    local sm0 "`r(sum)'"
    quietly tabtools set latex "`ft'"
    quietly tabtools set markdown "`fm'"
    foreach c in ///
        `"comptab _lcf1, rows(1 2)"' ///
        `"comptab _lchr1, rateframe(_lcrt1) rows(3/4) allmodels"' ///
        `"stratetab, using("`out'/lcr_r1") outcomes(1)"' {
        quietly `c'
        assert `"`r(latex)'"' == ""
        assert `"`r(markdown)'"' == ""
        assert missing(r(latex_rows)) & missing(r(markdown_rows))
        _lcr_sum "`ft'"
        assert "`r(sum)'" == "`st0'"
        _lcr_sum "`fm'"
        assert "`r(sum)'" == "`sm0'"
    }
    quietly tabtools query
    assert "`r(latex_fresh)'" == "1"
    assert "`r(markdown_fresh)'" == "1"
}
* tabtools set clear runs captures of its own and resets _rc: save it first
local _blk_rc = _rc
quietly tabtools set clear
if `_blk_rc' == 0 {
    display as result "  PASS: R13 session LaTeX and Markdown files untouched without sheet() (comptab both paths, stratetab)"
    local ++pass_count
}
else {
    display as error "  FAIL: R13 session sink without sheet() (rc=`_blk_rc')"
    local ++fail_count
}

**# R14: a failed latex() through ratetab restores the caller's r()
* ratetab's documented rule (ratetab.ado): a refusal or export failure
* inside stratetab is ratetab's own refusal, and the caller's r() is
* restored, so neither stratetab's nor ratetab's results are posted.
capture noisily {
    local bad "`out'/__missing_latex_dir__"
    sysuse cancer, clear
    quietly stset studytime, failure(died)
    _lcr_console ratetab drug, latex("`bad'/x.tex")
    local crc = r(rc)
    assert `crc' == 603
    assert strpos(`"`r(text)'"', "Failed to export LaTeX to `bad'/x.tex") > 0
    quietly summarize age
    local want_mean = r(mean)
    local want_N = r(N)
    capture ratetab drug, latex("`bad'/x.tex")
    assert _rc == `crc'
    assert r(mean) == `want_mean' & r(N) == `want_N'
    assert missing(r(N_rows)) & missing(r(latex_rows)) & missing(r(per))
    assert `"`r(latex)'"' == "" & `"`r(methods)'"' == ""
    capture confirm file "`bad'/x.tex"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: R14 ratetab latex() failure: rc 603, LaTeX message, caller's r() restored"
    local ++pass_count
}
else {
    display as error "  FAIL: R14 ratetab latex() failure (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_latex_composite_rates tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _lcr
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_latex_composite_rates tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _lcr

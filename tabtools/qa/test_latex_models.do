* test_latex_models.do - latex()/texappend in regtab and effecttab
* (_take_action/tabtools_latex_export_2026-10-31.md, builder group "models")
*   M1  regtab layouts: two models (3 columns each), compact, nopvalue,
*       compact nopvalue, transpose with addcol, one model with stats(),
*       addrow(), stars and a two-paragraph footnote, mlogit (several
*       equations), mixed (random-effects rows)
*   M2  effecttab layouts: margins without models(), two teffects models,
*       full, from() matrix, models() naming only the first model
*   M3  the Markdown flatten ("Model A: OR") never reaches the .tex
*   M4  texappend: three tables in one file, labels tab:<stem>-2 and -3
*   M5  session sink (tabtools set latex): first write replaces, later
*       writes append, only with sheet(), an explicit latex() wins
*   M6  same-file refusal (latex() = markdown(), case-only difference too)
*       and the .tex extension refusal: nothing written
*   M7  texappend without latex(): r(198)
*   M8  latex() into a missing directory: the analytical r() survives, rc
*       and payload match a failed markdown() write
* Every layout case writes xlsx(), csv(), markdown() and latex() from one
* call. Expected values: the column count, header-row count and spanner
* ranges are read back from the workbook the same call wrote (openpyxl,
* workbook column B = LaTeX column 1) and also compared with a hand-built
* span list; body cells are compared with the CSV; row and column counts
* with r(markdown_rows)/r(markdown_cols). The .tex is judged by the
* independent checker qa/tools/check_latex.py (structure, escaping,
* pdflatex on the documented minimal preamble), never by itself.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _ltm
log using "test_latex_models.log", replace text name(_ltm)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global LTM_OUT "`output_dir'"
global LTM_CHECKER "`qa_dir'/tools/check_latex.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

* Workbook facts for one sheet: LaTeX column count (columns B.. holding any
* value), header rows (2 when row 2 has text right of the label column, else
* 1), and the row-2 merged ranges at least two columns wide whose anchor has
* text, as LaTeX spans "1:c1-c2" (workbook column j = LaTeX column j-1). A
* one-cell merge is no spanner, and a merge over blank cells (effecttab
* without models()) is counted separately as "blankmerge".
local probe "`output_dir'/_ltm_wbfacts.py"
tempname pfh
file open `pfh' using "`probe'", write text replace
file write `pfh' "import sys" _n
file write `pfh' "import openpyxl" _n
file write `pfh' "wb = openpyxl.load_workbook(sys.argv[1])" _n
file write `pfh' "ws = wb[sys.argv[2]]" _n
file write `pfh' "def val(r, c):" _n
file write `pfh' "    v = ws.cell(row=r, column=c).value" _n
file write `pfh' "    return '' if v is None else str(v).strip()" _n
file write `pfh' "last = 2" _n
file write `pfh' "for r in range(2, ws.max_row + 1):" _n
file write `pfh' "    for c in range(2, ws.max_column + 1):" _n
file write `pfh' "        if val(r, c) != '' and c > last:" _n
file write `pfh' "            last = c" _n
file write `pfh' "hdr = 2 if any(val(2, c) != '' for c in range(3, last + 1)) else 1" _n
file write `pfh' "spans = []" _n
file write `pfh' "blank = 0" _n
file write `pfh' "for rg in ws.merged_cells.ranges:" _n
file write `pfh' "    if rg.min_row == 2 and rg.max_row == 2 and rg.max_col > rg.min_col:" _n
file write `pfh' "        if val(2, rg.min_col) != '':" _n
file write `pfh' "            spans.append((rg.min_col - 1, rg.max_col - 1))" _n
file write `pfh' "        else:" _n
file write `pfh' "            blank += 1" _n
file write `pfh' "spans.sort()" _n
file write `pfh' "s = ','.join('1:%d-%d' % sp for sp in spans) if spans else 'none'" _n
file write `pfh' "with open(sys.argv[3], 'w') as fh:" _n
file write `pfh' "    fh.write('cols %d\n' % (last - 1))" _n
file write `pfh' "    fh.write('hdr %d\n' % hdr)" _n
file write `pfh' "    fh.write('spans %s\n' % s)" _n
file write `pfh' "    fh.write('blankmerge %d\n' % blank)" _n
file close `pfh'
global LTM_PROBE "`probe'"

capture program drop _ltm_wbfacts
program define _ltm_wbfacts
    version 17.0
    args book sheet
    tempfile res
    capture erase "`res'"
    shell python3 "$LTM_PROBE" "`book'" "`sheet'" "`res'"
    confirm file "`res'"
    tempname fh
    file open `fh' using "`res'", read text
    file read `fh' line
    while r(eof) == 0 {
        gettoken key rest : line
        local val = strtrim(`"`rest'"')
        c_local wb_`key' `"`val'"'
        file read `fh' line
    }
    file close `fh'
end

* check_latex.py verdict must be PASS (the shell drops exit codes, so the
* verdict goes through --result).
capture program drop _ltm_check
program define _ltm_check
    version 17.0
    gettoken tex 0 : 0
    tempfile res
    capture erase "`res'"
    shell python3 "$LTM_CHECKER" "`tex'" `0' --result "`res'"
    confirm file "`res'"
    mata: printf("{txt}  check_latex: %s\n", cat(st_local("res"))[1])
    mata: st_local("_ok", strofreal(substr(cat(st_local("res"))[1], 1, 4) == "PASS"))
    assert `_ok' == 1
end

capture program drop _ltm_sum
program define _ltm_sum, rclass
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

capture program drop _ltm_seed
program define _ltm_seed
    version 17.0
    args path
    capture erase "`path'"
    tempname fh
    file open `fh' using "`path'", write text
    file write `fh' "KEEP THIS TEXT" _n
    file close `fh'
end

* Does a text file contain a string (read in Mata, never through a macro)?
capture program drop _ltm_has
program define _ltm_has, rclass
    version 17.0
    args path needle
    mata: st_local("_has", strofreal(strpos(invtokens(cat(st_local("path"))', char(10)), st_local("needle")) > 0))
    return scalar has = `_has'
end

* Console text of a command (nested log) in r(text), its rc in r(rc).
capture program drop _ltm_console
program define _ltm_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_ltm_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _ltm_capture
    mata: st_local("_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_txt)'"'
    return scalar rc = `crc'
end

* One layout case: _ltm_case stem csvrows expspans needles : command, opts
* Appends xlsx() sheet(S) csv() markdown() latex() to the command, then
* checks r(latex*) against r(markdown*) and the workbook, the hand-built
* spans against the workbook's merged ranges, and the .tex with the checker
* (compile, one table, columns, header rows, exact spans + cmidrules, body
* rows, body-cell parity with the CSV rows csvrows, optional needles file).
capture program drop _ltm_case
program define _ltm_case
    version 17.0
    gettoken stem 0 : 0
    gettoken csvrows 0 : 0
    gettoken expspans 0 : 0
    gettoken needles 0 : 0
    gettoken colon 0 : 0
    assert "`colon'" == ":"
    local f "$LTM_OUT/`stem'"
    foreach e in xlsx csv md tex {
        capture erase "`f'.`e'"
    }
    `0' xlsx("`f'.xlsx") sheet("S") csv("`f'.csv") markdown("`f'.md") latex("`f'.tex")
    local r_latex `"`r(latex)'"'
    local lr = r(latex_rows)
    local lc = r(latex_cols)
    local mr = r(markdown_rows)
    local mc = r(markdown_cols)
    display as text "  `stem': latex_rows=`lr' markdown_rows=`mr' latex_cols=`lc' markdown_cols=`mc'"
    assert `"`r_latex'"' == "`f'.tex"
    assert !missing(`lr') & `lr' > 0 & `lr' == `mr'
    assert !missing(`lc') & `lc' == `mc'
    _ltm_wbfacts "`f'.xlsx" "S"
    display as text "  workbook: cols=`wb_cols' hdr=`wb_hdr' spans=`wb_spans' blankmerge=`wb_blankmerge'"
    assert `lc' == `wb_cols'
    assert "`wb_spans'" == "`expspans'"
    local nd ""
    if "`needles'" != "-" local nd `"--needles "`needles'""'
    _ltm_check "`f'.tex" --compile --tables 1 --cols `wb_cols' ///
        --header-rows `wb_hdr' --spans "`wb_spans'" --body-rows `lr' ///
        --parity-csv "`f'.csv" --csv-rows "`csvrows'" `nd'
    c_local wb_hdr `wb_hdr'
    c_local wb_blankmerge `wb_blankmerge'
end

* Needles file: one "kind<TAB>text" line per argument pair.
capture program drop _ltm_needles
program define _ltm_needles
    version 17.0
    gettoken path 0 : 0
    tempname fh
    file open `fh' using "`path'", write text replace
    while `"`0'"' != "" {
        gettoken kind 0 : 0
        gettoken text 0 : 0
        file write `fh' "`kind'" _char(9) `"`text'"' _n
    }
    file close `fh'
end

local bad_root "`output_dir'/__missing_latex_dir__"
capture rmdir "`bad_root'"

**# M1. regtab layouts

**## M1a two models, three columns each; the flatten stays out (M3)
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg weight
    quietly collect: logit foreign mpg weight i.rep78
    local nf "`output_dir'/_ltm_r2.needles"
    _ltm_needles "`nf'" contains "\multicolumn{3}{c}{Model A}" ///
        contains "\multicolumn{3}{c}{Model B}" ///
        contains " & OR & 95\% CI & p-value & OR & 95\% CI & p-value \\" ///
        absent "Model A: OR" absent "Model B: p-value" ///
        contains "\caption{Two models}" contains "\label{tab:_ltm_r2}" ///
        pdftext "Model A" pdftext "Repair record 1978"
    _ltm_case _ltm_r2 "4:" "1:2-4,1:5-7" "`nf'" : ///
        regtab, models("Model A \ Model B") title("Two models") noint
    assert `wb_hdr' == 2
    * the same call's Markdown did flatten, so the absent needles are not vacuous
    _ltm_has "`output_dir'/_ltm_r2.md" "Model A: OR"
    assert r(has) == 1
}
if _rc == 0 {
    display as result "  PASS: M1a regtab two models: spans 2-4 and 5-7, no flattened header"
    local ++pass_count
}
else {
    display as error "  FAIL: M1a regtab two models (rc=`=_rc')"
    local ++fail_count
}

**## M1b compact, nopvalue, compact nopvalue
foreach v in compact nopvalue cnp {
    capture noisily {
        sysuse auto, clear
        collect clear
        quietly collect: logit foreign mpg weight
        quietly collect: logit foreign mpg weight i.rep78
        local opt "`v'"
        local exp "1:2-3,1:4-5"
        if "`v'" == "cnp" {
            local opt "compact nopvalue"
            * one-column blocks: the workbook's one-cell merge is no spanner
            local exp "none"
        }
        local nf "`output_dir'/_ltm_r_`v'.needles"
        _ltm_needles "`nf'" absent "Model A: " absent "Model B: " ///
            pdftext "Model B"
        _ltm_case _ltm_r_`v' "4:" "`exp'" "`nf'" : ///
            regtab, models("Model A \ Model B") title("Layout `v'") noint `opt'
        assert `wb_hdr' == 2
    }
    if _rc == 0 {
        display as result "  PASS: M1b regtab `v': spans `exp'"
        local ++pass_count
    }
    else {
        display as error "  FAIL: M1b regtab `v' (rc=`=_rc')"
        local ++fail_count
    }
}

**## M1c transpose with addcol(): terms over statistics, no spanner
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: logit foreign mpg
    quietly collect: logit foreign mpg weight
    local nf "`output_dir'/_ltm_r_tp.needles"
    _ltm_needles "`nf'" contains " & Mileage (mpg) & Mileage (mpg) & Weight (lbs.) & Weight (lbs.) & AUC \\" ///
        contains " & OR (95\% CI) & p-value & OR (95\% CI) & p-value &  \\" ///
        absent "Mileage (mpg): " absent "\multicolumn"
    _ltm_case _ltm_r_tp "3:" "none" "`nf'" : ///
        regtab, transpose addcol("AUC" 0.71 0.88) noint
    assert `wb_hdr' == 2
}
if _rc == 0 {
    display as result "  PASS: M1c regtab transpose addcol(): two header rows, no spans"
    local ++pass_count
}
else {
    display as error "  FAIL: M1c regtab transpose (rc=`=_rc')"
    local ++fail_count
}

**## M1d one model: stats(), addrow(), stars, footnote paragraphs, no title
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    local nf "`output_dir'/_ltm_r_st.needles"
    _ltm_needles "`nf'" contains "\multicolumn{3}{c}{Model}" absent "Model: " ///
        absent "\caption" absent "\label" ///
        contains "Observations & 74 &  &  \\" contains "P trend & 0.032 &  &  \\" ///
        contains "Note one.\par" contains "Note two.\par" ///
        pdftext "Note two." pdftext "1.75**"
    * CSV: model row, statistic row, body, then two footnote rows
    _ltm_case _ltm_r_st "3:-3" "1:2-4" "`nf'" : ///
        regtab, stats(n aic) addrow("P trend" 0.032) stars ///
        footnote("Note one. \ Note two.")
}
if _rc == 0 {
    display as result "  PASS: M1d regtab stats/addrow/stars/footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: M1d regtab stats/addrow/stars/footnote (rc=`=_rc')"
    local ++fail_count
}

**## M1e several equations (mlogit) and random-effects rows (mixed)
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: mlogit rep78 mpg weight, baseoutcome(3)
    local nf "`output_dir'/_ltm_r_ml.needles"
    _ltm_needles "`nf'" contains "5: Weight (lbs.) & " absent "Model: " pdftext "RRR"
    _ltm_case _ltm_r_ml "3:" "1:2-4" "`nf'" : regtab, noint
    sysuse auto, clear
    collect clear
    quietly collect: mixed price mpg || rep78:
    local nf "`output_dir'/_ltm_r_mx.needles"
    _ltm_needles "`nf'" contains "\multicolumn{3}{c}{Mixed}" absent "Mixed: " ///
        pdftext "Variance"
    _ltm_case _ltm_r_mx "4:" "1:2-4" "`nf'" : ///
        regtab, models("Mixed") relabel stats(n groups) title("Mixed")
}
if _rc == 0 {
    display as result "  PASS: M1e regtab mlogit equations and mixed random effects"
    local ++pass_count
}
else {
    display as error "  FAIL: M1e regtab mlogit/mixed (rc=`=_rc')"
    local ++fail_count
}

**# M2. effecttab layouts

**## M2a margins without models(): one header row although the workbook merges row 2
capture noisily {
    sysuse auto, clear
    quietly regress price mpg i.foreign
    collect clear
    quietly collect: margins foreign
    local nf "`output_dir'/_ltm_e_nm.needles"
    * "}{c}{" is a header spanner; a stub-only body row is \multicolumn{k}{l}
    _ltm_needles "`nf'" contains " & Estimate & 95\% CI & p-value \\" ///
        absent "}{c}{" absent "\cmidrule" ///
        contains "\hspace*{1em}Domestic & " pdftext "Foreign"
    _ltm_case _ltm_e_nm "2:" "none" "`nf'" : effecttab, type(margins)
    assert `wb_hdr' == 1
    * the workbook does merge the blank model row: the fallback is deliberate
    assert `wb_blankmerge' >= 1
}
if _rc == 0 {
    display as result "  PASS: M2a effecttab without models(): single header row"
    local ++pass_count
}
else {
    display as error "  FAIL: M2a effecttab without models() (rc=`=_rc')"
    local ++fail_count
}

**## M2b two teffects models; M2c the same with full (equation rows)
webuse cattaneo2, clear
label define smokelbl 0 "Non-smoker" 1 "Smoker", replace
label values mbsmoke smokelbl
collect clear
quietly collect: teffects ra (bweight mage prenatal1 mmarried fbaby) (mbsmoke), ate
quietly collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
capture noisily {
    local nf "`output_dir'/_ltm_e_te.needles"
    _ltm_needles "`nf'" contains "\multicolumn{3}{c}{RA} & \multicolumn{3}{c}{IPW}" ///
        contains "\cmidrule(lr){2-4} \cmidrule(lr){5-7}" ///
        absent "RA: ATE" absent "IPW: p-value" pdftext "IPW"
    _ltm_case _ltm_e_te "3:" "1:2-4,1:5-7" "`nf'" : ///
        effecttab, effect("ATE") models("RA \ IPW") clean
    _ltm_has "`output_dir'/_ltm_e_te.md" "RA: ATE"
    assert r(has) == 1
}
if _rc == 0 {
    display as result "  PASS: M2b effecttab two models: spans 2-4 and 5-7"
    local ++pass_count
}
else {
    display as error "  FAIL: M2b effecttab two models (rc=`=_rc')"
    local ++fail_count
}
capture noisily {
    local nf "`output_dir'/_ltm_e_full.needles"
    * equation rows carry text in column 1 only: one full-width cell
    _ltm_needles "`nf'" contains "\multicolumn{7}{l}{OME0} \\" ///
        contains "\multicolumn{7}{l}{TME1} \\" absent "RA: "
    _ltm_case _ltm_e_full "3:" "1:2-4,1:5-7" "`nf'" : ///
        effecttab, effect("ATE") models("RA \ IPW") full
}
if _rc == 0 {
    display as result "  PASS: M2c effecttab full: equation rows, spans kept"
    local ++pass_count
}
else {
    display as error "  FAIL: M2c effecttab full (rc=`=_rc')"
    local ++fail_count
}

**## M2d models() names only the first of two models: one spanner
capture noisily {
    local nf "`output_dir'/_ltm_e_part.needles"
    _ltm_needles "`nf'" contains " & \multicolumn{3}{c}{RA} &  &  &  \\" ///
        contains "\cmidrule(lr){2-4}" absent "\cmidrule(lr){5-7}"
    _ltm_case _ltm_e_part "3:" "1:2-4" "`nf'" : ///
        effecttab, effect("ATE") models("RA") clean
    assert `wb_blankmerge' >= 1
}
if _rc == 0 {
    display as result "  PASS: M2d effecttab partly named models: one spanner"
    local ++pass_count
}
else {
    display as error "  FAIL: M2d effecttab partly named models (rc=`=_rc')"
    local ++fail_count
}

**## M2e from() matrix with a title
capture noisily {
    sysuse auto, clear
    matrix ltm_m = (1.5, 0.8, 2.2, 0.04 \ 2.3, 1.1, 3.5, 0.001 \ -0.5, -1.2, 0.2, 0.15)
    matrix rownames ltm_m = Age Sex BMI
    local nf "`output_dir'/_ltm_e_fm.needles"
    _ltm_needles "`nf'" contains "\multicolumn{3}{c}{Main}" ///
        contains "\caption{From matrix}" absent "Main: " contains "BMI & -0.50 & (-1.20, 0.20) & 0.15 \\"
    _ltm_case _ltm_e_fm "4:" "1:2-4" "`nf'" : ///
        effecttab, from(ltm_m) effect("OR") models("Main") title("From matrix")
}
if _rc == 0 {
    display as result "  PASS: M2e effecttab from() matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: M2e effecttab from() (rc=`=_rc')"
    local ++fail_count
}

**# M4. texappend: regtab, regtab texappend, effecttab texappend
capture noisily {
    local f "`output_dir'/_ltm_app.tex"
    _ltm_seed "`f'"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    regtab, latex("`f'") title("First") noint
    assert r(latex_rows) == 2
    regtab, latex("`f'") texappend title("Second") noint
    assert `"`r(latex)'"' == "`f'" & r(latex_rows) == 2 & r(latex_cols) == 4
    quietly regress price mpg i.foreign
    collect clear
    quietly collect: margins foreign
    effecttab, type(margins) latex("`f'") texapp title("Third")
    assert r(latex_rows) == 3
    local nf "`output_dir'/_ltm_app.needles"
    _ltm_needles "`nf'" absent "KEEP THIS TEXT" ///
        contains "\label{tab:_ltm_app}" contains "\label{tab:_ltm_app-2}" ///
        contains "\label{tab:_ltm_app-3}" pdftext "Third"
    _ltm_check "`f'" --compile --tables 3 --needles "`nf'"
    _ltm_check "`f'" --table 3 --cols 4 --header-rows 1 --spans none
}
if _rc == 0 {
    display as result "  PASS: M4 texappend: three tables, labels -2 and -3"
    local ++pass_count
}
else {
    display as error "  FAIL: M4 texappend (rc=`=_rc')"
    local ++fail_count
}

**# M5. Session sink (tabtools set latex)
capture noisily {
    local s "`output_dir'/_ltm_sess.tex"
    local x "`output_dir'/_ltm_sess_explicit.tex"
    capture erase "`x'"
    _ltm_seed "`s'"
    quietly tabtools set clear
    tabtools set latex "`s'"
    tabtools query
    assert "`r(latex_fresh)'" == "1"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    * without sheet() the session target is not used (the rule for every sink)
    _ltm_sum "`s'"
    local before "`r(sum)'"
    regtab, noint
    assert `"`r(latex)'"' == "" & missing(r(latex_rows)) & missing(r(latex_cols))
    _ltm_sum "`s'"
    assert "`r(sum)'" == "`before'"
    * first session write replaces the seeded file
    regtab, sheet("S") noint title("Session one")
    assert `"`r(latex)'"' == "`s'" & r(latex_rows) == 2
    tabtools query
    assert "`r(latex_fresh)'" == "0"
    _ltm_check "`s'" --tables 1 --absent "KEEP THIS TEXT"
    * an explicit latex() wins and leaves the session file alone
    _ltm_sum "`s'"
    local before "`r(sum)'"
    regtab, sheet("S") noint latex("`x'")
    assert `"`r(latex)'"' == "`x'"
    _ltm_sum "`s'"
    assert "`r(sum)'" == "`before'"
    * the next session write appends
    quietly regress price mpg i.foreign
    collect clear
    quietly collect: margins foreign
    effecttab, type(margins) sheet("E") title("Session two")
    assert `"`r(latex)'"' == "`s'" & r(latex_rows) == 3
    _ltm_check "`s'" --compile --tables 2 --contains "\label{tab:_ltm_sess-2}"
    _ltm_check "`x'" --compile --tables 1
    tabtools set latex clear
    tabtools query
    assert `"`r(latex)'"' == ""
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: M5 session sink: sheet() gate, replace then append, explicit wins"
    local ++pass_count
}
else {
    display as error "  FAIL: M5 session sink (rc=`=_rc')"
    local ++fail_count
    capture tabtools set clear
}

**# M6. Same-file and extension refusals: nothing written
capture noisily {
    local md "`output_dir'/_ltm_coll.md"
    local mdup "`output_dir'/_LTM_COLL.md"
    local xl "`output_dir'/_ltm_coll.xlsx"
    local cs "`output_dir'/_ltm_coll.csv"
    local tx "`output_dir'/_ltm_coll.txt"
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    foreach cmd in regtab effecttab {
        if "`cmd'" == "effecttab" {
            quietly regress price mpg i.foreign
            collect clear
            quietly collect: margins foreign
        }
        foreach lpath in "`md'" "`mdup'" {
            _ltm_seed "`md'"
            capture erase "`xl'"
            capture erase "`cs'"
            _ltm_sum "`md'"
            local before "`r(sum)'"
            _ltm_console `cmd', xlsx("`xl'") sheet("S") csv("`cs'") ///
                markdown("`md'") latex("`lpath'")
            assert r(rc) == 198
            assert strpos(`"`r(text)'"', "markdown() and latex() name the same file") > 0
            _ltm_sum "`md'"
            assert "`r(sum)'" == "`before'"
            capture confirm file "`xl'"
            assert _rc != 0
            capture confirm file "`cs'"
            assert _rc != 0
        }
        * latex() must name a .tex file
        capture erase "`tx'"
        _ltm_console `cmd', xlsx("`xl'") sheet("S") latex("`tx'")
        assert r(rc) == 198
        assert strpos(`"`r(text)'"', "latex() must specify a .tex file") > 0
        capture confirm file "`tx'"
        assert _rc != 0
        capture confirm file "`xl'"
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: M6 latex() = markdown() (and case twin) refused, .tex enforced, nothing written"
    local ++pass_count
}
else {
    display as error "  FAIL: M6 refusals (rc=`=_rc')"
    local ++fail_count
}

**# M7. texappend without latex()
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    _ltm_console regtab, texappend noint
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "texappend requires latex()") > 0
    quietly regress price mpg i.foreign
    collect clear
    quietly collect: margins foreign
    _ltm_console effecttab, type(margins) texappend
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "texappend requires latex()") > 0
}
if _rc == 0 {
    display as result "  PASS: M7 texappend requires latex() in both commands"
    local ++pass_count
}
else {
    display as error "  FAIL: M7 texappend without latex() (rc=`=_rc')"
    local ++fail_count
}

**# M8. latex() into a missing directory: analytical r() survives
* Mirrors test_package_adversarial.do (export failure r() survival) and pins
* that a failed LaTeX write behaves as a failed Markdown write: same rc, same
* surviving payload, data restored.
**## regtab
capture noisily {
    foreach sink in markdown latex {
        sysuse auto, clear
        collect clear
        quietly collect: regress price mpg weight
        return clear
        local ext = cond("`sink'" == "latex", "tex", "md")
        _ltm_console regtab, `sink'("`bad_root'/regtab.`ext'")
        local rc_`sink' = r(rc)
        assert `rc_`sink'' != 0
        local lbl = cond("`sink'" == "latex", "LaTeX", "Markdown")
        assert strpos(`"`r(text)'"', "Failed to export `lbl' to") > 0
        * _ltm_console is rclass: rerun bare to read the command's own r()
        capture regtab, `sink'("`bad_root'/regtab.`ext'")
        assert _rc == `rc_`sink''
        assert r(N_models) == 1
        tempname rg
        matrix `rg' = r(table)
        assert rowsof(`rg') > 0
        assert `"`r(latex)'"' == "" & missing(r(latex_rows)) & missing(r(latex_cols))
        assert `"`r(markdown)'"' == "" & missing(r(markdown_rows))
        assert _N == 74 & c(k) == 12
        capture confirm file "`bad_root'/regtab.`ext'"
        assert _rc != 0
    }
    assert `rc_latex' == `rc_markdown'
}
if _rc == 0 {
    display as result "  PASS: M8 regtab preserves r() after latex() failure (rc = markdown's `rc_markdown')"
    local ++pass_count
}
else {
    display as error "  FAIL: M8 regtab latex() failure returns (rc=`=_rc')"
    local ++fail_count
}

**## effecttab
capture noisily {
    foreach sink in markdown latex {
        sysuse auto, clear
        quietly regress price mpg weight
        collect clear
        quietly collect: margins, dydx(mpg weight)
        return clear
        local ext = cond("`sink'" == "latex", "tex", "md")
        _ltm_console effecttab, type(margins) `sink'("`bad_root'/effecttab.`ext'")
        local rc_`sink' = r(rc)
        assert `rc_`sink'' != 0
        local lbl = cond("`sink'" == "latex", "LaTeX", "Markdown")
        assert strpos(`"`r(text)'"', "Failed to export `lbl' to") > 0
        capture effecttab, type(margins) `sink'("`bad_root'/effecttab.`ext'")
        assert _rc == `rc_`sink''
        assert "`r(type)'" == "margins"
        tempname ef
        matrix `ef' = r(table)
        assert rowsof(`ef') > 0
        assert `"`r(latex)'"' == "" & missing(r(latex_rows)) & missing(r(latex_cols))
        assert `"`r(markdown)'"' == "" & missing(r(markdown_rows))
        assert _N == 74 & c(k) == 12
        capture confirm file "`bad_root'/effecttab.`ext'"
        assert _rc != 0
    }
    assert `rc_latex' == `rc_markdown'
}
if _rc == 0 {
    display as result "  PASS: M8 effecttab preserves r() after latex() failure (rc = markdown's `rc_markdown')"
    local ++pass_count
}
else {
    display as error "  FAIL: M8 effecttab latex() failure returns (rc=`=_rc')"
    local ++fail_count
}

**# Summary
quietly tabtools set clear
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_latex_models tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _ltm
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_latex_models tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ltm

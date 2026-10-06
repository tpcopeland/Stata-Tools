* test_codex_audit_2026_09_26.do - the nine findings of the 2026-09-26 Codex
* audit; its regression provenance is recorded below.
* Regression suite, written against commit 96f090d8 (tabtools 2.1.13) before
* any fix. Every test below failed on 96f090d8.
*   C1  a variable label, a value label and a collected label holding a
*       $global (of a global that exists), a balanced backtick-quote pair, an
*       unbalanced backtick and double quotes reach the frame, xlsx, CSV and
*       Markdown as typed, in corrtab, desctab, table1_tc, regtab, effecttab
*       (margins and teffects), crosstab, survtab, stratetab and hrcomptab
*       (comptab composing a rate frame with a model frame by label)
*   C2  an occupied, invalid or current frame() (and eplotframe()) is refused
*       before any file is written: xlsx, CSV and Markdown sentinels keep their
*       checksums, in every command with frame()/eplotframe()
*   C3  puttab keeps every observation as a Markdown body row, leading,
*       interior, trailing and all-missing ones included, so
*       r(markdown_rows) == r(n_datarows) and the rows line up with xlsx/CSV
*   C4  puttab if/in counts the source's own observations; in 1 never exports
*       observation 2; noembedheader exports a label-shaped observation 1 as
*       data while the header still comes from the labels
*   C5  survtab by() with no failures still produces the grouped table, omits
*       the log-rank test with a note and returns r(logrank_p) missing; with
*       failures the test is still reported
*   C6  effecttab r(table) and eplotframe() values are the input numbers,
*       identical across digits(0), digits(2) and digits(6), from() and
*       collect paths
*   C7  effecttab from() refuses a p-value outside [0, 1] or a lower limit
*       above the upper one with r(198) naming the row and writes nothing;
*       p = 0, p = 1, ll == ul, missing values and an estimate outside its
*       interval are accepted
*   C8  stacktab reads block suboptions only at the top level; text inside
*       label() is not a row selection; unknown and duplicate suboptions and
*       stray text are r(198)
*   C9  stacktab accepts quoted labels and sheet names; parentheses and the
*       block separator inside quoted text are literal; quoted and unquoted
*       forms export identical rows
* Oracles: literal strings built with char() and stored with Mata (the
* do-file never spells a macro reference it would itself expand), workbooks
* read back with openpyxl (tools/xlsx_facts.py), Markdown rendered with
* markdown-it-py (tools/md_facts.py), CSV parsed field by field in Mata,
* checksums taken before the call, and input matrices / e(b).

clear all
set more off
set varabbrev off
version 17.0

capture log close _ca
log using "test_codex_audit_2026_09_26.log", replace text name(_ca)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global CA_TOOLS "`qa_dir'/tools"
global CA_OUT "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

**# Hostile label texts (C1)
* L: a $global of a global that exists, a balanced backtick-quote pair and
*    double quotes.  U: an unbalanced backtick.  P: a $global and an
*    unbalanced backtick.  VL/VU: value-label texts of the same kinds.
global CA_GLB "EXPANDED"
mata: st_global("CA_L", "V " + char(36) + "CA_GLB " + char(96) + "lit" + char(39) + " " + char(34) + "dq" + char(34) + " end")
mata: st_global("CA_U", "U " + char(96) + "tick end")
mata: st_global("CA_P", "P " + char(36) + "CA_GLB " + char(96) + "q")
mata: st_global("CA_VL", "VL " + char(36) + "CA_GLB " + char(96) + "lit" + char(39) + " z")
mata: st_global("CA_VU", "VU " + char(96) + "t")

mata:
// Any line of a facts file (xlsx_facts.py / md_facts.py output) holds want.
real scalar _ca_facts_has(string scalar path, string scalar want)
{
    string colvector lines
    real scalar i

    lines = cat(path)
    for (i = 1; i <= rows(lines); i++) {
        if (strpos(lines[i], want)) return(1)
    }
    return(0)
}

// The fields of one CSV record (RFC 4180 quoting, no embedded newlines).
string rowvector _ca_csv_fields(string scalar line)
{
    string rowvector out
    string scalar cur, c
    real scalar i, n, inq

    out = J(1, 0, "")
    cur = ""
    inq = 0
    n = strlen(line)
    for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (inq) {
            if (c == char(34)) {
                if (substr(line, i + 1, 1) == char(34)) {
                    cur = cur + char(34)
                    i++
                }
                else inq = 0
            }
            else cur = cur + c
        }
        else if (c == char(34)) inq = 1
        else if (c == ",") {
            out = out, cur
            cur = ""
        }
        else cur = cur + c
    }
    return((out, cur))
}

// Some CSV field holds want.
real scalar _ca_csv_has(string scalar path, string scalar want)
{
    string colvector lines
    string rowvector f
    real scalar i, j

    lines = cat(path)
    for (i = 1; i <= rows(lines); i++) {
        f = _ca_csv_fields(lines[i])
        for (j = 1; j <= cols(f); j++) {
            if (strpos(f[j], want)) return(1)
        }
    }
    return(0)
}

// Number of CSV records.
real scalar _ca_csv_nrec(string scalar path)
{
    return(rows(cat(path)))
}

// Trimmed field j of CSV record i ("" when absent).
string scalar _ca_csv_cell(string scalar path, real scalar i, real scalar j)
{
    string colvector lines
    string rowvector f

    lines = cat(path)
    if (i > rows(lines)) return("")
    f = _ca_csv_fields(lines[i])
    if (j > cols(f)) return("")
    return(strtrim(f[j]))
}

// Some string cell of the current frame holds want.
real scalar _ca_data_has(string scalar want)
{
    real scalar j, i

    for (j = 1; j <= st_nvar(); j++) {
        if (!st_isstrvar(j)) continue
        for (i = 1; i <= st_nobs(); i++) {
            if (strpos(st_sdata(i, j), want)) return(1)
        }
    }
    return(0)
}

// Raw bytes of a file hold want.
real scalar _ca_file_has(string scalar path, string scalar want)
{
    real scalar fh
    string scalar s

    fh = fopen(path, "r")
    s = fread(fh, 10000000)
    fclose(fh)
    if (s == J(0, 0, "")) return(0)
    return(strpos(s, want) > 0)
}

// Markdown table body rows: lines starting with "|" after the separator row.
real scalar _ca_md_body_rows(string scalar path)
{
    string colvector lines
    real scalar i, n, sep

    lines = cat(path)
    n = 0
    sep = 0
    for (i = 1; i <= rows(lines); i++) {
        if (substr(lines[i], 1, 5) == "| ---") {
            sep = 1
            continue
        }
        if (sep & substr(lines[i], 1, 1) == "|") n++
    }
    return(n)
}

// Cells of Markdown body row k, trimmed, split on unescaped pipes.
string rowvector _ca_md_row(string scalar path, real scalar k)
{
    string colvector lines
    string rowvector out
    string scalar s, cur, c
    real scalar i, n, sep, j

    lines = cat(path)
    n = 0
    sep = 0
    for (i = 1; i <= rows(lines); i++) {
        if (substr(lines[i], 1, 5) == "| ---") {
            sep = 1
            continue
        }
        if (!(sep & substr(lines[i], 1, 1) == "|")) continue
        n++
        if (n != k) continue
        s = lines[i]
        out = J(1, 0, "")
        cur = ""
        for (j = 2; j <= strlen(s); j++) {
            c = substr(s, j, 1)
            if (c == char(92) & j < strlen(s)) {
                cur = cur + substr(s, j + 1, 1)
                j++
            }
            else if (c == "|") {
                out = out, strtrim(cur)
                cur = ""
            }
            else cur = cur + c
        }
        return(out)
    }
    return(J(1, 0, ""))
}
end

**# Helper programs

* The text in global CA_<which> is present in the workbook sheet (openpyxl),
* the CSV and the rendered Markdown of stem, and "EXPANDED" is in none of
* them. A sink whose file name is "-" is skipped.
capture program drop _ca_sinks_have
program define _ca_sinks_have
    version 17.0
    args stem sheet which
    local want "CA_`which'"
    tempfile xres mres
    capture erase "`xres'"
    capture erase "`mres'"
    shell python3 "$CA_TOOLS/xlsx_facts.py" "`stem'.xlsx" "`sheet'" "`xres'"
    confirm file "`xres'"
    shell python3 "$CA_TOOLS/md_facts.py" "`stem'.md" "`mres'"
    confirm file "`mres'"
    mata: st_local("ok_x", strofreal(_ca_facts_has(st_local("xres"), st_global("`want'"))))
    mata: st_local("ok_c", strofreal(_ca_csv_has(st_local("stem") + ".csv", st_global("`want'"))))
    mata: st_local("ok_m", strofreal(_ca_facts_has(st_local("mres"), st_global("`want'"))))
    mata: st_local("bad_x", strofreal(_ca_facts_has(st_local("xres"), "EXPANDED")))
    mata: st_local("bad_c", strofreal(_ca_file_has(st_local("stem") + ".csv", "EXPANDED")))
    mata: st_local("bad_m", strofreal(_ca_file_has(st_local("stem") + ".md", "EXPANDED")))
    if `ok_x' != 1 | `ok_c' != 1 | `ok_m' != 1 | `bad_x' | `bad_c' | `bad_m' {
        display as error "`stem': text `want' xlsx=`ok_x' csv=`ok_c' md=`ok_m'; EXPANDED xlsx=`bad_x' csv=`bad_c' md=`bad_m'"
        exit 9
    }
end

* The text in global CA_<which> is a string cell of frame fr, and no cell of
* the frame holds "EXPANDED".
capture program drop _ca_frame_has
program define _ca_frame_has
    version 17.0
    args fr which
    frame `fr' {
        mata: st_local("ok", strofreal(_ca_data_has(st_global("CA_`which'"))))
        mata: st_local("bad", strofreal(_ca_data_has("EXPANDED")))
    }
    if `ok' != 1 | `bad' {
        display as error "frame `fr': text CA_`which' present=`ok', EXPANDED=`bad'"
        exit 9
    }
end

capture program drop _ca_clear_stem
program define _ca_clear_stem
    version 17.0
    args stem
    foreach e in xlsx csv md {
        capture erase "`stem'.`e'"
    }
end

* CRC and length of a file, as one string ("absent" when it does not exist).
capture program drop _ca_sum
program define _ca_sum, rclass
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

* Fresh xlsx/CSV/Markdown sentinels at stem.
capture program drop _ca_sentinels
program define _ca_sentinels
    version 17.0
    args stem
    foreach e in md csv {
        capture erase "`stem'.`e'"
        tempname fh
        file open `fh' using "`stem'.`e'", write replace
        file write `fh' "KEEP THIS ORIGINAL" _n
        file close `fh'
    }
    preserve
    clear
    quietly set obs 1
    quietly generate str10 keep = "KEEP"
    capture erase "`stem'.xlsx"
    quietly export excel using "`stem'.xlsx", sheet("Keep") replace
    restore
end

* The C1 fixture: labelled variables x (L), u (U), c (P, value labels VL/VU)
* and g (value labels VL/VU), 40 observations.
capture program drop _ca_c1_data
program define _ca_c1_data
    version 17.0
    clear
    quietly set obs 40
    quietly generate double x = _n
    quietly generate double u = mod(_n * 7, 11)
    quietly generate double y = mod(_n * 3, 13) + 0.25 * _n
    quietly generate byte c = mod(_n, 2)
    quietly generate byte g = _n > 20
    quietly generate byte b = mod(_n * 5, 7) > 3
    mata: st_varlabel("x", st_global("CA_L"))
    mata: st_varlabel("u", st_global("CA_U"))
    mata: st_varlabel("c", st_global("CA_P"))
    mata: st_vlmodify("ca_vl", (0 \ 1), (st_global("CA_VL") \ st_global("CA_VU")))
    label values c ca_vl
    label values g ca_vl
end

**# C1 macro-safe labels

* C1a corrtab: variable labels in header and stub
capture noisily {
    local stem "$CA_OUT/ca_c1_corrtab"
    _ca_clear_stem "`stem'"
    _ca_c1_data
    capture frame drop ca_c1f
    corrtab x u y, xlsx("`stem'.xlsx") sheet("C1") csv("`stem'.csv") ///
        markdown("`stem'.md") frame(ca_c1f)
    foreach w in L U {
        _ca_sinks_have "`stem'" "C1" `w'
        _ca_frame_has ca_c1f `w'
    }
    capture frame drop ca_c1f
}
if _rc == 0 {
    display as result "  PASS: C1a corrtab labels literal in frame, xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: C1a corrtab labels (rc=`=_rc')"
    local ++fail_count
}

* C1b desctab and C1c table1_tc: variable, category and group value labels
foreach cmd in desctab table1_tc {
    local tid = cond("`cmd'" == "desctab", "C1b", "C1c")
    capture noisily {
        local stem "$CA_OUT/ca_c1_`cmd'"
        _ca_clear_stem "`stem'"
        _ca_c1_data
        capture frame drop ca_c1f
        `cmd', vars(x contn \ u contn \ c cat) by(g) excel("`stem'.xlsx") ///
            sheet("C1") csv("`stem'.csv") markdown("`stem'.md") frame(ca_c1f)
        foreach w in L U P VL VU {
            _ca_sinks_have "`stem'" "C1" `w'
            _ca_frame_has ca_c1f `w'
        }
        capture frame drop ca_c1f
    }
    if _rc == 0 {
        display as result "  PASS: `tid' `cmd' labels literal in frame, xlsx, CSV and Markdown"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `tid' `cmd' labels (rc=`=_rc')"
        local ++fail_count
    }
}

* C1d regtab: collected variable labels, factor parent and level labels
capture noisily {
    local stem "$CA_OUT/ca_c1_regtab"
    _ca_clear_stem "`stem'"
    _ca_c1_data
    collect clear
    quietly collect: regress y x u i.c
    capture frame drop ca_c1f
    capture frame drop ca_c1e
    regtab, xlsx("`stem'.xlsx") sheet("C1") csv("`stem'.csv") ///
        markdown("`stem'.md") frame(ca_c1f) eplotframe(ca_c1e)
    foreach w in L U P VL VU {
        _ca_sinks_have "`stem'" "C1" `w'
        _ca_frame_has ca_c1f `w'
    }
    _ca_frame_has ca_c1e L
    _ca_frame_has ca_c1e VU
    capture frame drop ca_c1f
    capture frame drop ca_c1e
}
if _rc == 0 {
    display as result "  PASS: C1d regtab collected labels literal in frames, xlsx, CSV and Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: C1d regtab labels (rc=`=_rc')"
    local ++fail_count
}

* C1e effecttab: margins over a labelled factor
capture noisily {
    local stem "$CA_OUT/ca_c1_effecttab"
    _ca_clear_stem "`stem'"
    _ca_c1_data
    quietly logit b x i.c
    collect clear
    quietly collect: margins c
    capture frame drop ca_c1f
    capture frame drop ca_c1e
    effecttab, xlsx("`stem'.xlsx") sheet("C1") csv("`stem'.csv") ///
        markdown("`stem'.md") frame(ca_c1f) eplotframe(ca_c1e)
    foreach w in P VL VU {
        _ca_sinks_have "`stem'" "C1" `w'
        _ca_frame_has ca_c1f `w'
    }
    _ca_frame_has ca_c1e VL
    _ca_frame_has ca_c1e VU
    capture frame drop ca_c1f
    capture frame drop ca_c1e
}
if _rc == 0 {
    display as result "  PASS: C1e effecttab margins labels literal in frames and sinks"
    local ++pass_count
}
else {
    display as error "  FAIL: C1e effecttab margins labels (rc=`=_rc')"
    local ++fail_count
}

* C1f effecttab teffects with clean: treatment value labels
capture noisily {
    local stem "$CA_OUT/ca_c1_teffects"
    _ca_clear_stem "`stem'"
    _ca_c1_data
    collect clear
    quietly collect: teffects ra (y x) (c)
    effecttab, clean xlsx("`stem'.xlsx") sheet("C1") csv("`stem'.csv") ///
        markdown("`stem'.md")
    foreach w in VL VU {
        _ca_sinks_have "`stem'" "C1" `w'
    }
}
if _rc == 0 {
    display as result "  PASS: C1f effecttab teffects clean labels literal"
    local ++pass_count
}
else {
    display as error "  FAIL: C1f effecttab teffects clean labels (rc=`=_rc')"
    local ++fail_count
}

* C1g crosstab: row variable label and row/column value labels
capture noisily {
    local stem "$CA_OUT/ca_c1_crosstab"
    _ca_clear_stem "`stem'"
    _ca_c1_data
    capture frame drop ca_c1f
    crosstab c g, label xlsx("`stem'.xlsx") sheet("C1") csv("`stem'.csv") ///
        markdown("`stem'.md") frame(ca_c1f)
    foreach w in P VL VU {
        _ca_sinks_have "`stem'" "C1" `w'
        _ca_frame_has ca_c1f `w'
    }
    mata: st_local("bad", strofreal(strpos(st_global("r(methods)"), "EXPANDED") > 0))
    assert `bad' == 0
    capture frame drop ca_c1f
}
if _rc == 0 {
    display as result "  PASS: C1g crosstab labels literal in frame, sinks and r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: C1g crosstab labels (rc=`=_rc')"
    local ++fail_count
}

* C1h survtab: group value labels, including the log-rank test path
capture noisily {
    local stem "$CA_OUT/ca_c1_survtab"
    _ca_clear_stem "`stem'"
    _ca_c1_data
    quietly generate double t = x
    quietly generate byte d = mod(_n, 3) == 0
    quietly stset t, failure(d)
    capture frame drop ca_c1f
    survtab, times(10 20) by(g) xlsx("`stem'.xlsx") sheet("C1") ///
        csv("`stem'.csv") markdown("`stem'.md") frame(ca_c1f)
    assert !missing(r(logrank_p))
    mata: st_local("same", strofreal(st_global("r(group_1_label)") == st_global("CA_VL")))
    assert `same' == 1
    foreach w in VL VU {
        _ca_sinks_have "`stem'" "C1" `w'
        _ca_frame_has ca_c1f `w'
    }
    capture frame drop ca_c1f
}
if _rc == 0 {
    display as result "  PASS: C1h survtab group labels literal in frame, sinks and r()"
    local ++pass_count
}
else {
    display as error "  FAIL: C1h survtab group labels (rc=`=_rc')"
    local ++fail_count
}

* C1i stratetab: category value labels carried by the strate file
capture noisily {
    local stem "$CA_OUT/ca_c1_stratetab"
    _ca_clear_stem "`stem'"
    _ca_c1_data
    quietly generate double t = x
    quietly generate byte d = mod(_n, 3) == 0
    quietly stset t, failure(d)
    quietly strate g, output("$CA_OUT/ca_c1_strate", replace)
    capture frame drop ca_c1f
    stratetab, using("$CA_OUT/ca_c1_strate") outcomes(1) xlsx("`stem'.xlsx") ///
        sheet("C1") csv("`stem'.csv") markdown("`stem'.md") frame(ca_c1f)
    foreach w in VL VU {
        _ca_sinks_have "`stem'" "C1" `w'
        _ca_frame_has ca_c1f `w'
    }
    capture frame drop ca_c1f
}
if _rc == 0 {
    display as result "  PASS: C1i stratetab category labels literal in frame and sinks"
    local ++pass_count
}
else {
    display as error "  FAIL: C1i stratetab category labels (rc=`=_rc')"
    local ++fail_count
}

* C1j hrcomptab (comptab): rate-frame category labels matched to model rows
* by label, composed, and carried into the eplot frame
capture noisily {
    local stem "$CA_OUT/ca_c1_hrcomptab"
    _ca_clear_stem "`stem'"
    clear
    quietly set obs 3
    quietly generate exposure = _n - 1
    quietly generate double _D = cond(_n == 1, 10, cond(_n == 2, 4, 6))
    quietly generate double _Y = cond(_n == 1, 1000, cond(_n == 2, 300, 400))
    quietly generate double _Rate = _D / _Y
    quietly generate double _Lower = _Rate * 0.80
    quietly generate double _Upper = _Rate * 1.20
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    mata: st_vlmodify("ca_hl", (0 \ 1 \ 2), (st_global("CA_VL") \ st_global("CA_VU") \ "High"))
    label values exposure ca_hl
    quietly save "$CA_OUT/ca_c1_hrc_rate.dta", replace
    clear
    quietly stratetab, using("$CA_OUT/ca_c1_hrc_rate") outcomes(1) frame(ca_hrc_rates, replace) ///
        outlabels("Outcome 1") outcomeids("t1") explabels("Dose")
    clear
    quietly set obs 300
    set seed 20260926
    quietly generate byte dose = mod(_n, 3)
    mata: st_vlmodify("ca_hl", (0 \ 1 \ 2), (st_global("CA_VL") \ st_global("CA_VU") \ "High"))
    label values dose ca_hl
    quietly generate double t1 = 1 + 12 * runiform() * exp(-0.20 * (dose == 1) - 0.35 * (dose == 2))
    quietly generate byte d1 = mod(_n, 4) != 0
    collect clear
    quietly stset t1, failure(d1)
    quietly collect: stcox i.dose, nolog
    quietly regtab, models("Outcome 1") frame(ca_hrc_dose, replace) ///
        eplotframe(ca_hrc_dose_plot, replace) noint
    hrcomptab ca_hrc_rates, modelframes(ca_hrc_dose) rows(3/4) ///
        outcomemap("Outcome 1") effect("aHR") frame(ca_c1f, replace) ///
        eplotframe(ca_c1e, replace) xlsx("`stem'.xlsx") sheet("C1") ///
        csv("`stem'.csv") markdown("`stem'.md")
    assert r(N_modelrows) == 2
    foreach w in VL VU {
        _ca_sinks_have "`stem'" "C1" `w'
        _ca_frame_has ca_c1f `w'
        _ca_frame_has ca_c1e `w'
    }
    foreach f in ca_c1f ca_c1e ca_hrc_rates ca_hrc_dose ca_hrc_dose_plot {
        capture frame drop `f'
    }
}
if _rc == 0 {
    display as result "  PASS: C1j hrcomptab rate-frame category labels literal in frames and sinks"
    local ++pass_count
}
else {
    display as error "  FAIL: C1j hrcomptab category labels (rc=`=_rc')"
    local ++fail_count
}

**# C2 frame() refused before any write

* One call per command and frame specification. Each must fail with the
* expected rc and leave all three sentinels byte-identical.
capture program drop _ca_c2_call
program define _ca_c2_call
    version 17.0
    args cmd fs stem
    local sinks `"xlsx("`stem'.xlsx") sheet("New") csv("`stem'.csv") markdown("`stem'.md")"'
    sysuse auto, clear
    if "`cmd'" == "corrtab" corrtab price mpg, `sinks' frame(`fs')
    if "`cmd'" == "crosstab" crosstab foreign rep78, `sinks' frame(`fs')
    if "`cmd'" == "survtab" {
        quietly generate double t = mpg
        quietly generate byte d = price > 5000
        quietly stset t, failure(d)
        survtab, times(15 20) by(foreign) `sinks' frame(`fs')
    }
    if inlist("`cmd'", "desctab", "table1_tc") {
        `cmd', vars(mpg contn) by(foreign) excel("`stem'.xlsx") sheet("New") ///
            csv("`stem'.csv") markdown("`stem'.md") frame(`fs')
    }
    if inlist("`cmd'", "regtab", "regtab_ep") {
        collect clear
        quietly collect: regress price mpg
        if "`cmd'" == "regtab" regtab, `sinks' frame(`fs')
        else regtab, `sinks' eplotframe(`fs')
    }
    if inlist("`cmd'", "effecttab", "effecttab_ep") {
        matrix CA_M = (1.5, 0.8, 2.2, 0.03)
        matrix rownames CA_M = Treated
        if "`cmd'" == "effecttab" effecttab, from(CA_M) `sinks' frame(`fs')
        else effecttab, from(CA_M) `sinks' eplotframe(`fs')
    }
    if inlist("`cmd'", "comptab", "comptab_ep") {
        collect clear
        quietly collect: regress price mpg weight
        quietly regtab, frame(ca_c2src, replace)
        if "`cmd'" == "comptab" comptab ca_c2src, rows(1) `sinks' frame(`fs')
        else comptab ca_c2src, rows(1) `sinks' eplotframe(`fs')
    }
    if "`cmd'" == "stratetab" {
        stratetab, using("$CA_OUT/ca_c2_strate") outcomes(1) `sinks' frame(`fs')
    }
    if "`cmd'" == "stacktab" {
        stacktab using "`stem'.xlsx", blocks(sheet(Keep)) sheet("New") ///
            csv("`stem'.csv") markdown("`stem'.md") frame(`fs')
    }
end

sysuse auto, clear
quietly generate double t = mpg
quietly generate byte d = price > 5000
quietly stset t, failure(d)
quietly strate foreign, output("$CA_OUT/ca_c2_strate", replace)

foreach cmd in corrtab crosstab survtab desctab table1_tc regtab regtab_ep ///
    effecttab effecttab_ep comptab comptab_ep stratetab stacktab {
    capture noisily {
        local stem "$CA_OUT/ca_c2_`cmd'"
        foreach spec in occupied invalid current {
            capture frame drop ca_occ
            frame create ca_occ
            if "`spec'" == "occupied" {
                local fs "ca_occ"
                local want_rc = 110
            }
            if "`spec'" == "invalid" {
                local fs "1bad"
                local want_rc = 198
            }
            if "`spec'" == "current" {
                local fs "default, replace"
                local want_rc = 198
            }
            _ca_sentinels "`stem'"
            local before ""
            foreach e in xlsx csv md {
                _ca_sum "`stem'.`e'"
                local before "`before' `r(sum)'"
            }
            capture noisily _ca_c2_call `cmd' "`fs'" "`stem'"
            local got_rc = _rc
            local after ""
            foreach e in xlsx csv md {
                _ca_sum "`stem'.`e'"
                local after "`after' `r(sum)'"
            }
            if `got_rc' != `want_rc' | "`before'" != "`after'" {
                display as error "`cmd' frame(`fs'): rc=`got_rc' (want `want_rc'); sentinels before `before' after `after'"
                exit 9
            }
            capture frame drop ca_occ
        }
        capture frame drop ca_c2src
    }
    if _rc == 0 {
        display as result "  PASS: C2 `cmd' refuses a bad frame before writing (sentinels unchanged)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C2 `cmd' frame validation after writes (rc=`=_rc')"
        local ++fail_count
    }
}

**# C3 puttab keeps all-missing observations in Markdown

* C3a leading, interior and trailing all-missing observations
capture noisily {
    local stem "$CA_OUT/ca_c3_mixed"
    _ca_clear_stem "`stem'"
    clear
    quietly set obs 5
    quietly generate double x = .
    quietly generate str3 s = ""
    quietly replace x = 1 in 2
    quietly replace s = "a" in 2
    quietly replace x = 3 in 4
    quietly replace s = "c" in 4
    puttab x s using "`stem'.xlsx", csv("`stem'.csv") markdown("`stem'.md")
    assert r(n_datarows) == 5
    assert r(markdown_rows) == 5
    * Markdown: five body rows, the data rows in observation positions 2 and 4
    mata: st_local("nb", strofreal(_ca_md_body_rows(st_local("stem") + ".md")))
    assert `nb' == 5
    foreach k in 1 3 5 {
        mata: st_local("cells", invtokens(_ca_md_row(st_local("stem") + ".md", `k'), "|"))
        assert `"`cells'"' == "|"
    }
    mata: st_local("cells", invtokens(_ca_md_row(st_local("stem") + ".md", 2), "|"))
    assert `"`cells'"' == "1|a"
    mata: st_local("cells", invtokens(_ca_md_row(st_local("stem") + ".md", 4), "|"))
    assert `"`cells'"' == "3|c"
    * CSV: header + five records, same positions
    mata: st_local("nr", strofreal(_ca_csv_nrec(st_local("stem") + ".csv")))
    assert `nr' == 6
    mata: st_local("v", _ca_csv_cell(st_local("stem") + ".csv", 3, 1))
    assert "`v'" == "1"
    mata: st_local("v", _ca_csv_cell(st_local("stem") + ".csv", 5, 2))
    assert "`v'" == "c"
    * Workbook: header in row 2, observation i in row 2 + i
    tempfile xres
    capture erase "`xres'"
    shell python3 "$CA_TOOLS/xlsx_facts.py" "`stem'.xlsx" "Table" "`xres'"
    mata: st_local("ok1", strofreal(_ca_facts_has(st_local("xres"), "value B4 1")))
    mata: st_local("ok3", strofreal(_ca_facts_has(st_local("xres"), "value C6 c")))
    assert `ok1' == 1 & `ok3' == 1
}
if _rc == 0 {
    display as result "  PASS: C3a puttab Markdown keeps leading/interior/trailing blank observations"
    local ++pass_count
}
else {
    display as error "  FAIL: C3a puttab Markdown blank observations (rc=`=_rc')"
    local ++fail_count
}

* C3b every observation missing
capture noisily {
    local stem "$CA_OUT/ca_c3_allmiss"
    _ca_clear_stem "`stem'"
    clear
    quietly set obs 2
    quietly generate double x = .
    puttab x using "`stem'.xlsx", csv("`stem'.csv") markdown("`stem'.md")
    assert r(n_datarows) == 2
    assert r(markdown_rows) == 2
    mata: st_local("nb", strofreal(_ca_md_body_rows(st_local("stem") + ".md")))
    assert `nb' == 2
    mata: st_local("nr", strofreal(_ca_csv_nrec(st_local("stem") + ".csv")))
    assert `nr' == 3
}
if _rc == 0 {
    display as result "  PASS: C3b puttab Markdown keeps all-missing observations"
    local ++pass_count
}
else {
    display as error "  FAIL: C3b puttab all-missing observations (rc=`=_rc')"
    local ++fail_count
}

**# C4 puttab if/in and embedded-header detection

capture program drop _ca_c4_data
program define _ca_c4_data
    version 17.0
    clear
    quietly set obs 2
    quietly generate str12 kind = cond(_n == 1, "Kind", "second")
    quietly generate str12 value = cond(_n == 1, "Value", "retained")
    label variable kind "Kind"
    label variable value "Value"
end

* C4a the audit repro with noembedheader: in 1 exports observation 1 as data
capture noisily {
    local stem "$CA_OUT/ca_c4_noemb"
    _ca_clear_stem "`stem'"
    _ca_c4_data
    puttab kind value in 1 using "`stem'.xlsx", varlabels noembedheader ///
        csv("`stem'.csv") markdown("`stem'.md")
    assert r(n_datarows) == 1
    * CSV: header Kind,Value then the data row Kind,Value; never "second"
    mata: st_local("nr", strofreal(_ca_csv_nrec(st_local("stem") + ".csv")))
    assert `nr' == 2
    forvalues i = 1/2 {
        mata: st_local("a", _ca_csv_cell(st_local("stem") + ".csv", `i', 1))
        mata: st_local("b", _ca_csv_cell(st_local("stem") + ".csv", `i', 2))
        assert "`a'" == "Kind" & "`b'" == "Value"
    }
    mata: st_local("bad", strofreal(_ca_file_has(st_local("stem") + ".csv", "second")))
    assert `bad' == 0
    * Markdown: one body row Kind | Value
    mata: st_local("nb", strofreal(_ca_md_body_rows(st_local("stem") + ".md")))
    assert `nb' == 1
    mata: st_local("cells", invtokens(_ca_md_row(st_local("stem") + ".md", 1), "|"))
    assert `"`cells'"' == "Kind|Value"
    * Workbook: header row 2 and data row 3 both Kind / Value, nothing else
    tempfile xres
    capture erase "`xres'"
    shell python3 "$CA_TOOLS/xlsx_facts.py" "`stem'.xlsx" "Table" "`xres'"
    mata: st_local("ok", strofreal(_ca_facts_has(st_local("xres"), "value B3 Kind") & ///
        _ca_facts_has(st_local("xres"), "value C3 Value") & ///
        !_ca_facts_has(st_local("xres"), "second")))
    assert `ok' == 1
}
if _rc == 0 {
    display as result "  PASS: C4a noembedheader keeps observation 1 as data under in 1"
    local ++pass_count
}
else {
    display as error "  FAIL: C4a noembedheader in 1 (rc=`=_rc')"
    local ++fail_count
}

* C4b default detection: in 1 selects observation 1 (the embedded header), so
* nothing is exported, and observation 2 never is
capture noisily {
    local stem "$CA_OUT/ca_c4_default"
    _ca_clear_stem "`stem'"
    _ca_c4_data
    capture noisily puttab kind value in 1 using "`stem'.xlsx", varlabels ///
        csv("`stem'.csv") markdown("`stem'.md")
    assert _rc == 2000
    foreach e in xlsx csv md {
        capture confirm file "`stem'.`e'"
        assert _rc != 0
    }
}
if _rc == 0 {
    display as result "  PASS: C4b default in 1 never exports observation 2"
    local ++pass_count
}
else {
    display as error "  FAIL: C4b default in 1 (rc=`=_rc')"
    local ++fail_count
}

* C4c in 2 is observation 2; without if/in the embedded header is consumed
* (backward compatible); noembedheader keeps both observations
capture noisily {
    local stem "$CA_OUT/ca_c4_in2"
    _ca_clear_stem "`stem'"
    _ca_c4_data
    puttab kind value in 2 using "`stem'.xlsx", varlabels csv("`stem'.csv")
    assert r(n_datarows) == 1
    mata: st_local("a", _ca_csv_cell(st_local("stem") + ".csv", 2, 1))
    assert "`a'" == "second"
    _ca_clear_stem "`stem'"
    puttab kind value using "`stem'.xlsx", varlabels csv("`stem'.csv")
    assert r(n_datarows) == 1
    mata: st_local("a", _ca_csv_cell(st_local("stem") + ".csv", 2, 1))
    assert "`a'" == "second"
    _ca_clear_stem "`stem'"
    puttab kind value using "`stem'.xlsx", varlabels noemb csv("`stem'.csv")
    assert r(n_datarows) == 2
    mata: st_local("a", _ca_csv_cell(st_local("stem") + ".csv", 2, 1))
    mata: st_local("b", _ca_csv_cell(st_local("stem") + ".csv", 3, 1))
    assert "`a'" == "Kind" & "`b'" == "second"
}
if _rc == 0 {
    display as result "  PASS: C4c in 2 is observation 2; default and noemb row counts"
    local ++pass_count
}
else {
    display as error "  FAIL: C4c puttab in 2 / noemb (rc=`=_rc')"
    local ++fail_count
}

* C4d if selects by the source's values; observation 1 outside the selection
* is never examined
capture noisily {
    local stem "$CA_OUT/ca_c4_if"
    _ca_clear_stem "`stem'"
    _ca_c4_data
    puttab kind value if kind == "second" using "`stem'.xlsx", varlabels ///
        csv("`stem'.csv")
    assert r(n_datarows) == 1
    mata: st_local("a", _ca_csv_cell(st_local("stem") + ".csv", 2, 2))
    assert "`a'" == "retained"
}
if _rc == 0 {
    display as result "  PASS: C4d if selects source observations"
    local ++pass_count
}
else {
    display as error "  FAIL: C4d puttab if (rc=`=_rc')"
    local ++fail_count
}

**# C5 survtab by() with no failures

* C5a zero events: grouped table, note, missing test results
capture noisily {
    local stem "$CA_OUT/ca_c5_noevents"
    _ca_clear_stem "`stem'"
    clear
    quietly set obs 20
    quietly generate double t = _n
    quietly generate byte d = 0
    quietly generate byte g = mod(_n, 2)
    quietly stset t, failure(d)
    survtab, times(5 10) by(g) xlsx("`stem'.xlsx") sheet("C5") ///
        csv("`stem'.csv") markdown("`stem'.md")
    assert missing(r(logrank_p))
    assert missing(r(logrank_chi2))
    assert r(n_groups) == 2
    mata: st_local("m", strofreal(strpos(st_global("r(methods)"), "no failures") > 0))
    assert `m' == 1
    mata: st_global("CA_N0", "0 (N=10)")
    mata: st_global("CA_N1", "1 (N=10)")
    mata: st_global("CA_NOTE", "Log-rank test not possible: no failures in the analysis sample")
    foreach w in N0 N1 NOTE {
        _ca_sinks_have "`stem'" "C5" `w'
    }
}
if _rc == 0 {
    display as result "  PASS: C5a survtab by() without failures gives the grouped table"
    local ++pass_count
}
else {
    display as error "  FAIL: C5a survtab by() without failures (rc=`=_rc')"
    local ++fail_count
}

* C5b guard: with failures the log-rank test is still reported, and matches
* sts test run here
capture noisily {
    clear
    quietly set obs 40
    quietly generate double t = _n
    quietly generate byte d = mod(_n, 3) == 0
    quietly generate byte g = _n > 20
    quietly stset t, failure(d)
    quietly sts test g
    local want_p = chi2tail(r(df), r(chi2))
    quietly survtab, times(10 20) by(g)
    assert !missing(r(logrank_p))
    assert !missing(`want_p')
    assert reldif(r(logrank_p), `want_p') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: C5b survtab by() with failures still reports the log-rank test"
    local ++pass_count
}
else {
    display as error "  FAIL: C5b survtab log-rank with failures (rc=`=_rc')"
    local ++fail_count
}

**# C6 effecttab numeric returns are the input numbers

* C6a from(): r(table) and eplotframe identical across digits, equal to M
capture noisily {
    matrix CA_M = (0.123456789, 0.01, 0.3, 0.0123456789 \ 2.718281828459, 1.5, 4.25, 0.5)
    matrix rownames CA_M = exposure second
    foreach d in 0 2 6 {
        capture frame drop ca_c6e
        quietly effecttab, from(CA_M) digits(`d') eplotframe(ca_c6e)
        matrix CA_T`d' = r(table)
        forvalues i = 1/2 {
            assert CA_T`d'[`i', 1] == CA_M[`i', 1]
            assert CA_T`d'[`i', 2] == CA_M[`i', 4]
            frame ca_c6e {
                assert estimate[`i'] == CA_M[`i', 1]
                assert ll[`i'] == CA_M[`i', 2]
                assert ul[`i'] == CA_M[`i', 3]
                assert pvalue[`i'] == CA_M[`i', 4]
            }
        }
    }
    assert mreldif(CA_T0, CA_T6) == 0
    assert mreldif(CA_T2, CA_T6) == 0
    capture frame drop ca_c6e
}
if _rc == 0 {
    display as result "  PASS: C6a effecttab from() r(table)/eplotframe are the input numbers"
    local ++pass_count
}
else {
    display as error "  FAIL: C6a effecttab from() returns rounded (rc=`=_rc')"
    local ++fail_count
}

* C6b collect path: r(table) and eplotframe estimate independent of digits,
* equal to the margins results
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg i.rep78
    collect clear
    quietly collect: margins rep78
    matrix CA_B = r(table)
    foreach d in 0 6 {
        capture frame drop ca_c6e
        quietly effecttab, digits(`d') eplotframe(ca_c6e)
        matrix CA_R`d' = r(table)
        forvalues i = 1/3 {
            assert !missing(CA_R`d'[`i', 1], CA_B[1, `i'])
            assert reldif(CA_R`d'[`i', 1], CA_B[1, `i']) < 1e-12
            frame ca_c6e: assert reldif(estimate[`i'], CA_B[1, `i']) < 1e-12
            frame ca_c6e: assert reldif(ll[`i'], CA_B[5, `i']) < 1e-12
        }
    }
    assert mreldif(CA_R0, CA_R6) == 0
    capture frame drop ca_c6e
}
if _rc == 0 {
    display as result "  PASS: C6b effecttab collect r(table)/eplotframe independent of digits()"
    local ++pass_count
}
else {
    display as error "  FAIL: C6b effecttab collect returns depend on digits() (rc=`=_rc')"
    local ++fail_count
}

**# C7 effecttab from() refuses impossible rows

* C7a invalid rows: r(198), message names the row, nothing written
capture noisily {
    local stem "$CA_OUT/ca_c7_bad"
    local k = 0
    foreach m in "(1, 0.5, 2, 0.4 \ 1, 3, 2, 0.5)" "(1, 0.5, 2, 1.5)" "(1, 0.5, 2, -0.1)" {
        local ++k
        _ca_clear_stem "`stem'"
        matrix CA_BAD = `m'
        local msglog "$CA_OUT/ca_c7_msg.log"
        capture erase "`msglog'"
        capture log close _ca_msg
        log using "`msglog'", text replace name(_ca_msg)
        capture noisily effecttab, from(CA_BAD) xlsx("`stem'.xlsx") ///
            csv("`stem'.csv") markdown("`stem'.md")
        local got = _rc
        log close _ca_msg
        assert `got' == 198
        foreach e in xlsx csv md {
            capture confirm file "`stem'.`e'"
            assert _rc != 0
        }
        local want_row = cond(`k' == 1, "from() row 2 (r2)", "from() row 1 (r1)")
        mata: st_local("hit", strofreal(_ca_file_has(st_local("msglog"), st_local("want_row"))))
        assert `hit' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: C7a effecttab from() rejects ll > ul and p outside [0, 1]"
    local ++pass_count
}
else {
    display as error "  FAIL: C7a effecttab from() invalid rows (rc=`=_rc')"
    local ++fail_count
}

* C7b boundaries and missing values are accepted
capture noisily {
    foreach m in "(1, 0.5, 2, 0)" "(1, 0.5, 2, 1)" "(1, 2, 2, 0.5)" "(5, 0.5, 2, 0.5)" "(., ., ., .)" "(1, ., 2, .)" {
        matrix CA_OK = `m'
        quietly effecttab, from(CA_OK)
    }
}
if _rc == 0 {
    display as result "  PASS: C7b effecttab from() accepts p = 0/1, ll == ul, missing values"
    local ++pass_count
}
else {
    display as error "  FAIL: C7b effecttab from() valid boundaries (rc=`=_rc')"
    local ++fail_count
}

**# C8 stacktab block suboptions

capture program drop _ca_stack_src
program define _ca_stack_src
    version 17.0
    args book
    capture erase "`book'"
    clear
    quietly set obs 3
    quietly generate double x = _n
    quietly puttab x using "`book'", sheet(Source)
    quietly puttab x using "`book'", sheet(Two Words)
end

* C8a text inside label() is not a row selection
capture noisily {
    local book "$CA_OUT/ca_c8_parse.xlsx"
    _ca_stack_src "`book'"
    local csv "$CA_OUT/ca_c8_nested.csv"
    capture erase "`csv'"
    stacktab using "`book'", blocks(sheet(Source) label(rows(3/3))) ///
        sheet(NestedLabel) csv("`csv'")
    * the whole Source sheet (blank title row, header x, values 1-3)
    mata: st_local("nr", strofreal(_ca_csv_nrec(st_local("csv"))))
    assert `nr' == 5
    mata: st_local("a", _ca_csv_cell(st_local("csv"), 1, 1))
    assert "`a'" == "rows(3/3)"
    mata: st_local("v", invtokens((_ca_csv_cell(st_local("csv"), 3, 2), ///
        _ca_csv_cell(st_local("csv"), 4, 2), _ca_csv_cell(st_local("csv"), 5, 2)), ","))
    assert "`v'" == "1,2,3"
}
if _rc == 0 {
    display as result "  PASS: C8a stacktab label(rows(3/3)) is a label, not a row selection"
    local ++pass_count
}
else {
    display as error "  FAIL: C8a stacktab nested label (rc=`=_rc')"
    local ++fail_count
}

* C8b unknown, duplicate and stray block text: r(198), nothing written
capture noisily {
    local book "$CA_OUT/ca_c8_parse.xlsx"
    _ca_stack_src "`book'"
    local csv "$CA_OUT/ca_c8_bad.csv"
    _ca_sum "`book'"
    local book_before "`r(sum)'"
    foreach spec in "sheet(Source) rowz(3/3)" "sheet(Source) rows(2/3) rows(4/5)" ///
        "sheet(Source) junk" "stray sheet(Source)" "sheet(Source) sheet(Source)" {
        capture erase "`csv'"
        capture noisily stacktab using "`book'", blocks(`spec') sheet(Bad) csv("`csv'")
        assert _rc == 198
        capture confirm file "`csv'"
        assert _rc != 0
    }
    _ca_sum "`book'"
    assert "`r(sum)'" == "`book_before'"
}
if _rc == 0 {
    display as result "  PASS: C8b stacktab rejects unknown, duplicate and stray block text"
    local ++pass_count
}
else {
    display as error "  FAIL: C8b stacktab block option validation (rc=`=_rc')"
    local ++fail_count
}

**# C9 stacktab quoted block text

* C9a quoted and unquoted labels export identical rows
capture noisily {
    local book "$CA_OUT/ca_c9_parse.xlsx"
    _ca_stack_src "`book'"
    local q "$CA_OUT/ca_c9_quoted.csv"
    local u "$CA_OUT/ca_c9_unquoted.csv"
    capture erase "`q'"
    capture erase "`u'"
    stacktab using "`book'", blocks(sheet(Source) rows(2/5) label("Plain label")) ///
        sheet(Quoted) csv("`q'")
    stacktab using "`book'", blocks(sheet(Source) rows(2/5) label(Plain label)) ///
        sheet(Unquoted) csv("`u'")
    _ca_sum "`q'"
    local sq "`r(sum)'"
    _ca_sum "`u'"
    assert "`sq'" == "`r(sum)'"
    mata: st_local("nr", strofreal(_ca_csv_nrec(st_local("q"))))
    assert `nr' == 4
    mata: st_local("a", _ca_csv_cell(st_local("q"), 1, 1))
    assert "`a'" == "Plain label"
}
if _rc == 0 {
    display as result "  PASS: C9a stacktab quoted and unquoted labels export identical rows"
    local ++pass_count
}
else {
    display as error "  FAIL: C9a stacktab quoted label (rc=`=_rc')"
    local ++fail_count
}

* C9b quoted sheet name; parentheses and a backslash inside quoted text
capture noisily {
    local book "$CA_OUT/ca_c9_parse.xlsx"
    _ca_stack_src "`book'"
    local csv "$CA_OUT/ca_c9_paren.csv"
    capture erase "`csv'"
    stacktab using "`book'", blocks(sheet("Two Words") rows(2/5) label("a ) b \ c")) ///
        sheet(Paren) csv("`csv'")
    mata: st_local("nr", strofreal(_ca_csv_nrec(st_local("csv"))))
    assert `nr' == 4
    mata: st_local("ok", strofreal(_ca_csv_cell(st_local("csv"), 1, 1) == "a ) b " + char(92) + " c"))
    assert `ok' == 1
}
if _rc == 0 {
    display as result "  PASS: C9b stacktab quoted sheet name and literal ) and backslash"
    local ++pass_count
}
else {
    display as error "  FAIL: C9b stacktab quoted parentheses (rc=`=_rc')"
    local ++fail_count
}

* C9c the block separator inside quoted text does not split blocks
capture noisily {
    local book "$CA_OUT/ca_c9_parse.xlsx"
    _ca_stack_src "`book'"
    local csv "$CA_OUT/ca_c9_sep.csv"
    capture erase "`csv'"
    stacktab using "`book'", blocks(sheet(Source) rows(2/3) \ ///
        sheet("Two Words") rows(4/5) label("sep \ in (quote)")) sheet(Sep) csv("`csv'")
    assert r(blocks_loaded) == 2
    mata: st_local("nr", strofreal(_ca_csv_nrec(st_local("csv"))))
    assert `nr' == 4
    mata: st_local("ok", strofreal(_ca_csv_cell(st_local("csv"), 3, 1) == "sep " + char(92) + " in (quote)"))
    assert `ok' == 1
    mata: st_local("v", _ca_csv_cell(st_local("csv"), 4, 2))
    assert "`v'" == "3"
}
if _rc == 0 {
    display as result "  PASS: C9c stacktab separator inside quoted text is literal"
    local ++pass_count
}
else {
    display as error "  FAIL: C9c stacktab quoted separator (rc=`=_rc')"
    local ++fail_count
}

**# Summary
capture frame drop ca_occ
capture frame drop ca_c2src
local test_count = `pass_count' + `fail_count'
display "RESULT: test_codex_audit_2026_09_26 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ca
if `fail_count' > 0 exit 1

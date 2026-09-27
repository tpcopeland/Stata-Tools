* test_open_items_2026_09_27.do - open regtab, comptab and stratetab items
* after 68c37a90, found by the R tabtools port.
* Regression suite, written against commit 68c37a90 (tabtools 2.1.13) before
* any fix:
*   K1  regtab classifies clogit like logit: OR header over odds ratios
*       (exponentiated when collected without or), "conditional logistic
*       regression" in the methods sentence, dimnonsig judged against 1, no
*       intercept row beside a logistic model, and no invented group count
*   K2  comptab vertical mode merges a Reference block only in the model whose
*       own estimate cell reads Reference; r(sheet) is the workbook's spelling
*       of a replaced sheet; eplotframe() follows the table (each selected row
*       once, in frame order); the help file names modelframes() correctly
*   K3  stratetab reads a "97,5%" interval label written under set dp comma
*       as 97.5; rateratio with an all-empty comparison exposure returns the
*       table without r(ratios); a rateratio frame is marked irr_ci and
*       comptab refuses it by name; a zero-event rate with missing bounds
*       prints "0.0 (–)"; the Markdown header is the flattened
*       "outcome: statistic" row; the rule above an exposure block does not
*       depend on the block's label; rate cells round at the exact unit; a
*       quoted outcomeids() list is split into its identities
* Oracles: each fit's own e(b) and hand-built strate files, rate ratios from
* the Poisson formula exp(log(IRR) +/- z sqrt(1/D1 + 1/D2)) with z from
* invnormal(), workbooks read back with openpyxl (tools/xlsx_facts.py and an
* inline font/sheet reader), Markdown rendered by markdown-it-py
* (tools/md_facts.py), and the help file's own text.

clear all
set more off
set varabbrev off
version 17.0

capture log close _oi
log using "test_open_items_2026_09_27.log", replace text name(_oi)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global OI_TOOLS "`qa_dir'/tools"
global OI_OUT "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* openpyxl reader: argv = book result mode [labels...]. mode "dim" writes 1/0
* per label for "the column C cell of the row labelled <label> in column B
* has the dimmed A0A0A0 font"; mode "sheets" writes the sheet names.
tempname fh
file open `fh' using "`output_dir'/oi_xlsx.py", write text replace
file write `fh' "import sys, openpyxl" _n
file write `fh' "wb = openpyxl.load_workbook(sys.argv[1])" _n
file write `fh' "out = []" _n
file write `fh' "if sys.argv[3] == 'sheets':" _n
file write `fh' "    out = list(wb.sheetnames)" _n
file write `fh' "else:" _n
file write `fh' "    ws = wb.active" _n
file write `fh' "    for lab in sys.argv[4:]:" _n
file write `fh' "        row = [r for r in range(1, ws.max_row + 1) if str(ws.cell(r, 2).value or '').strip() == lab]" _n
file write `fh' "        c = ws.cell(row[0], 3)" _n
file write `fh' "        rgb = c.font.color.rgb if c.font.color is not None else ''" _n
file write `fh' "        out.append('1' if str(rgb).upper().endswith('A0A0A0') else '0')" _n
file write `fh' "open(sys.argv[2], 'w').write('|'.join(out))" _n
file close `fh'

* Read the one-line result file of oi_xlsx.py into r(line).
capture program drop _oi_readline
program define _oi_readline, rclass
    version 17.0
    args file
    tempname h
    file open `h' using "`file'", read text
    file read `h' line
    file close `h'
    return local line `"`line'"'
end

* Trimmed cell of column `col' on the one frame row whose trimmed column-A
* label is `label' (rows 4 and later).
capture program drop _oi_cell
program define _oi_cell, rclass
    version 17.0
    args frname label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(A) == `"`label'"' & _n >= 4
        if r(N) != 1 {
            display as error `"frame `frname': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(A) == `"`label'"' & _n >= 4, meanonly
        local cell = strtrim(`col'[r(min)])
    }
    return local cell `"`cell'"'
end

* Whether the facts file of xlsx_facts.py holds the exact line `want'.
capture program drop _oi_hasfact
program define _oi_hasfact, rclass
    version 17.0
    args file want
    tempname h
    local found 0
    file open `h' using "`file'", read text
    file read `h' line
    while r(eof) == 0 {
        if `"`line'"' == `"`want'"' local found 1
        file read `h' line
    }
    file close `h'
    return scalar found = `found'
end

* A matched case-control fixture: 300 sets of one case and two controls.
capture program drop _oi_clogit_data
program define _oi_clogit_data
    version 17.0
    clear
    set seed 2709
    quietly set obs 300
    generate long set = _n
    quietly expand 3
    generate double x1 = rnormal()
    generate double noise = rnormal()
    generate byte smoke = runiform() < .4
    generate double u = runiform() * exp(0.8 * x1 + 0.5 * smoke)
    bysort set (u): generate byte case = _n == _N
    label variable x1 "Exposure score"
    label variable noise "Noise"
    label variable smoke "Smoker"
end

* A strate-like output file: categories 0/1, events, person-years, bounds.
capture program drop _oi_strate
program define _oi_strate
    version 17.0
    syntax , file(string) d0(real) d1(real) y0(real) y1(real) ///
        [level(string) lo0(real -1) hi0(real -1)]
    if "`level'" == "" local level "95"
    clear
    quietly set obs 2
    generate byte cat = _n - 1
    generate double _D = cond(_n == 1, `d0', `d1')
    generate double _Y = cond(_n == 1, `y0', `y1')
    generate double _Rate = _D / _Y
    local z = invnormal(1 - (1 - `level' / 100) / 2)
    generate double _Lower = _Rate * exp(-`z' / sqrt(_D))
    generate double _Upper = _Rate * exp(`z' / sqrt(_D))
    if `lo0' != -1 quietly replace _Lower = `lo0' in 1
    if `hi0' != -1 quietly replace _Upper = `hi0' in 1
    label variable _Lower "Lower `level'% confidence limit"
    label variable _Upper "Upper `level'% confidence limit"
    quietly save "`file'", replace
end

**# K1: regtab classifies clogit
* K1a: clogit, or. The collection holds odds ratios exp(b).
capture noisily {
    _oi_clogit_data
    collect clear
    quietly collect: clogit case x1 noise smoke, group(set) or
    local want_x1 = strtrim(string(exp(_b[x1]), "%9.2f"))
    local want_sm = strtrim(string(exp(_b[smoke]), "%9.2f"))
    regtab, frame(_oi1, replace)
    local methods `"`r(methods)'"'
    frame _oi1: assert strtrim(c1[3]) == "OR"
    _oi_cell _oi1 "Exposure score" c1
    assert "`r(cell)'" == "`want_x1'"
    _oi_cell _oi1 "Smoker" c1
    assert "`r(cell)'" == "`want_sm'"
    assert strpos(`"`methods'"', "Odds ratios") == 1
    assert strpos(`"`methods'"', "conditional logistic regression") > 0
    assert strpos(`"`methods'"', "multivariable") > 0
}
if _rc == 0 {
    display as result "  PASS: K1a clogit, or: OR header, odds ratios, conditional logistic methods"
    local ++pass_count
}
else {
    display as error "  FAIL: K1a clogit, or (rc=`=_rc')"
    local ++fail_count
}

* K1b: clogit without or is shown on the ratio scale too, as logit is:
* the collected log odds are exponentiated under an OR header.
capture noisily {
    _oi_clogit_data
    collect clear
    quietly collect: clogit case x1 noise smoke, group(set)
    local want_x1 = strtrim(string(exp(_b[x1]), "%9.2f"))
    regtab, frame(_oi1, replace)
    local methods `"`r(methods)'"'
    frame _oi1: assert strtrim(c1[3]) == "OR"
    _oi_cell _oi1 "Exposure score" c1
    assert "`r(cell)'" == "`want_x1'"
    assert strpos(`"`methods'"', "conditional logistic regression") > 0
}
if _rc == 0 {
    display as result "  PASS: K1b clogit without or is exponentiated under an OR header"
    local ++pass_count
}
else {
    display as error "  FAIL: K1b clogit without or (rc=`=_rc')"
    local ++fail_count
}

* K1c: beside logistic, one OR header, no Intercept row by default, and both
* model nouns in the methods sentence. clogit stores no group count
* (e(N_group) is absent), so stats(groups) adds no invented Groups row.
capture noisily {
    _oi_clogit_data
    collect clear
    quietly collect: clogit case x1 noise smoke, group(set) or
    quietly collect: logistic case x1 noise smoke
    regtab, frame(_oi1, replace) stats(N groups)
    local methods `"`r(methods)'"'
    assert "`r(coef_label)'" == "OR"
    frame _oi1: assert strtrim(c1[3]) == "OR"
    frame _oi1: quietly count if strtrim(A) == "Intercept"
    assert r(N) == 0
    frame _oi1: quietly count if strtrim(A) == "Groups"
    assert r(N) == 0
    _oi_cell _oi1 "Observations" c1
    assert "`r(cell)'" == "900"
    assert strpos(`"`methods'"', "Odds ratios") == 1
    assert strpos(`"`methods'"', "conditional logistic regression") > 0
}
if _rc == 0 {
    display as result "  PASS: K1c clogit beside logistic: one OR header, no intercept, both nouns"
    local ++pass_count
}
else {
    display as error "  FAIL: K1c clogit beside logistic (rc=`=_rc')"
    local ++fail_count
}

* K1d: dimnonsig judges clogit odds ratios against 1. Noise's OR interval
* spans 1 (dimmed); Exposure score's excludes it (not dimmed). Against the
* old null of 0 neither interval contains the null.
capture noisily {
    _oi_clogit_data
    collect clear
    quietly collect: clogit case x1 noise smoke, group(set) or
    assert exp(_b[noise] - invnormal(.975) * _se[noise]) < 1
    assert exp(_b[noise] + invnormal(.975) * _se[noise]) > 1
    local x "$OI_OUT/oi_clogit_dim.xlsx"
    capture erase "`x'"
    quietly regtab, xlsx("`x'") sheet("T") dimnonsig
    local res "$OI_OUT/oi_clogit_dim.txt"
    capture erase "`res'"
    shell python3 "$OI_OUT/oi_xlsx.py" "`x'" "`res'" dim "Noise" "Exposure score"
    _oi_readline "`res'"
    display as text "  dimmed (Noise|Exposure score): `r(line)'"
    assert "`r(line)'" == "1|0"
}
if _rc == 0 {
    display as result "  PASS: K1d dimnonsig judges clogit odds ratios against 1"
    local ++pass_count
}
else {
    display as error "  FAIL: K1d dimnonsig for clogit (rc=`=_rc')"
    local ++fail_count
}

**# K2: comptab vertical mode
* Base 1 has its Reference on row "1" (Excel row 5), Base 3 on row "3"
* (Excel row 7). Only those blocks are merged; the other model's estimate,
* interval and p-value on the same row stay in their own cells.
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.rep78 mpg
    local b1_3 = strtrim(string(_b[3.rep78], "%9.2f"))
    quietly collect: regress price ib3.rep78 mpg
    local b3_1 = strtrim(string(_b[1.rep78], "%9.2f"))
    quietly regtab, frame(_oip, replace) eplotframe(_oipe, replace) noint ///
        models("Base 1 \ Base 3")
    local x "$OI_OUT/oi_comptab_ref.xlsx"
    capture erase "`x'"
    comptab _oip, rows(1/7) xlsx("`x'") sheet("Ref")
    local res "$OI_OUT/oi_comptab_ref.txt"
    capture erase "`res'"
    shell python3 "$OI_TOOLS/xlsx_facts.py" "`x'" "Ref" "`res'"
    foreach m in "merge C5:E5" "merge F7:H7" "value F5 `b3_1'" "value C7 `b1_3'" {
        _oi_hasfact "`res'" `"`m'"'
        if !r(found) display as error `"  missing: `m'"'
        assert r(found)
    }
    foreach m in "merge F5:H5" "merge C7:E7" {
        _oi_hasfact "`res'" `"`m'"'
        if r(found) display as error `"  unexpected: `m'"'
        assert !r(found)
    }
    * the hidden cells: the other model's interval and p-value are present
    foreach c in G5 H5 D7 E7 {
        local seen 0
        tempname h
        file open `h' using "`res'", read text
        file read `h' line
        while r(eof) == 0 {
            if substr(`"`line'"', 1, 7 + strlen("`c'")) == "value `c' " local seen 1
            file read `h' line
        }
        file close `h'
        assert `seen'
    }
}
if _rc == 0 {
    display as result "  PASS: K2a vertical Reference merges stay in their own model"
    local ++pass_count
}
else {
    display as error "  FAIL: K2a vertical Reference merges (rc=`=_rc')"
    local ++fail_count
}

* K2b: replacing a sheet typed in another case returns the workbook's name.
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly regtab, frame(_oip, replace) noint
    local x "$OI_OUT/oi_comptab_sheet.xlsx"
    capture erase "`x'"
    comptab _oip, rows(1/2) xlsx("`x'") sheet("Ref")
    comptab _oip, rows(1/2) xlsx("`x'") sheet("REF")
    local got "`r(sheet)'"
    local res "$OI_OUT/oi_comptab_sheet.txt"
    capture erase "`res'"
    shell python3 "$OI_OUT/oi_xlsx.py" "`x'" "`res'" sheets
    _oi_readline "`res'"
    display as text "  r(sheet) `got'; workbook sheets `r(line)'"
    assert "`r(line)'" == "Ref"
    assert "`got'" == "Ref"
}
if _rc == 0 {
    display as result "  PASS: K2b vertical r(sheet) is the workbook's spelling"
    local ++pass_count
}
else {
    display as error "  FAIL: K2b vertical r(sheet) (rc=`=_rc')"
    local ++fail_count
}

* K2c: rows(7 3 3) plots rows 3 and 7 once each, row 3 first, as the table
* shows them. The source companion holds one row per model per body row.
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price i.rep78 mpg
    quietly collect: regress price ib3.rep78 mpg
    quietly regtab, frame(_oip, replace) eplotframe(_oipe, replace) noint ///
        models("Base 1 \ Base 3")
    frame _oipe: quietly count if source_row == 3
    local n3 = r(N)
    frame _oipe: quietly count if source_row == 7
    local n7 = r(N)
    assert `n3' == 2 & `n7' == 2
    quietly comptab _oip, rows(7 3 3) eplotframe(_oiep, replace)
    frame _oiep {
        quietly count if source_row == 3
        assert r(N) == `n3'
        quietly count if source_row == 7
        assert r(N) == `n7'
        assert _N == `n3' + `n7'
        assert source_row[1] == 3
        assert source_row[_N] == 7
    }
}
if _rc == 0 {
    display as result "  PASS: K2c vertical eplotframe() follows the table rows once, in order"
    local ++pass_count
}
else {
    display as error "  FAIL: K2c vertical eplotframe() order (rc=`=_rc')"
    local ++fail_count
}

* K2d: the help file abbreviates modelframes() as modelf:rames.
capture noisily {
    quietly findfile comptab.sthlp
    local help "`r(fn)'"
    local bad 0
    local good 0
    tempname h
    file open `h' using "`help'", read text
    file read `h' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "modelf:ames") local ++bad
        if strpos(`"`line'"', "modelf:rames") local ++good
        file read `h' line
    }
    file close `h'
    display as text "  modelf:ames `bad', modelf:rames `good'"
    assert `bad' == 0 & `good' >= 2
}
if _rc == 0 {
    display as result "  PASS: K2d comptab help names modelf:rames()"
    local ++pass_count
}
else {
    display as error "  FAIL: K2d comptab help option name (rc=`=_rc')"
    local ++fail_count
}

**# K3: stratetab
* K3a: under set dp comma strate labels its bounds "97,5%". The level is
* 97.5, the headers say so, and the rate-ratio interval uses z(97.5%).
capture noisily {
    clear
    set seed 5
    quietly set obs 400
    generate byte g = mod(_n, 2)
    generate double t = rexponential(10) * (1 + 0.3 * g)
    generate byte d = runiform() < .5
    quietly stset t, failure(d)
    local cwd "`c(pwd)'"
    quietly cd "$OI_OUT"
    set dp comma
    capture noisily {
        quietly strate g, output(oi_dp_1, replace) level(97.5) nolist
        quietly strate g, output(oi_dp_2, replace) level(97.5) nolist
    }
    local src = _rc
    set dp period
    if `src' exit `src'
    use oi_dp_1, clear
    local lab : variable label _Lower
    assert strpos(`"`lab'"', "97,5%") > 0
    local d0 = _D[1]
    local z = invnormal(1 - (1 - .975) / 2)
    local want_lo = strtrim(string(exp(-`z' * sqrt(2 / `d0')), "%9.2f"))
    local want_hi = strtrim(string(exp(`z' * sqrt(2 / `d0')), "%9.2f"))
    stratetab, using(oi_dp_1 oi_dp_2) outcomes(1) rateratio frame(_ois, replace)
    local lvl = r(ci_level)
    quietly cd "`cwd'"
    assert reldif(`lvl', 97.5) < 1e-12
    frame _ois: assert strtrim(c4[3]) == "Per 1,000 PY (97.5% CI)"
    frame _ois: assert strtrim(c5[3]) == "IRR (97.5% CI)"
    frame _ois: local cell = strtrim(c5[8])
    display as text "  IRR cell: `cell'; want 1.00 (`want_lo', `want_hi')"
    assert "`cell'" == "1.00 (`want_lo', `want_hi')"
}
if _rc == 0 {
    display as result "  PASS: K3a set dp comma 97,5% labels are read as 97.5"
    local ++pass_count
}
else {
    display as error "  FAIL: K3a set dp comma level (rc=`=_rc')"
    local ++fail_count
}
set dp period

* K3b: an all-empty comparison exposure: the table and r(rates) come back,
* r(ratios) is absent instead of r(111).
capture noisily {
    _oi_strate, file("$OI_OUT/oi_ref.dta") d0(10) d1(20) y0(1000) y1(1500)
    quietly drop in 1/l
    quietly save "$OI_OUT/oi_empty.dta", replace
    _oi_strate, file("$OI_OUT/oi_ref.dta") d0(10) d1(20) y0(1000) y1(1500)
    stratetab, using("$OI_OUT/oi_ref" "$OI_OUT/oi_empty") outcomes(1) rateratio
    capture confirm matrix r(ratios)
    assert _rc != 0
    confirm matrix r(rates)
    assert r(N_exposures) == 2
}
if _rc == 0 {
    display as result "  PASS: K3b rateratio with an empty comparison exposure returns the table"
    local ++pass_count
}
else {
    display as error "  FAIL: K3b rateratio with an empty exposure (rc=`=_rc')"
    local ++fail_count
}

* K3c: a rateratio frame says so, and comptab refuses it by name (rc 198),
* including the 3-outcome frame whose width matches a plain 4-outcome one.
capture noisily {
    _oi_strate, file("$OI_OUT/oi_ref.dta") d0(10) d1(20) y0(1000) y1(1500)
    _oi_strate, file("$OI_OUT/oi_cmp.dta") d0(12) d1(25) y0(1100) y1(1400)
    local f1 "$OI_OUT/oi_ref"
    local f2 "$OI_OUT/oi_cmp"
    stratetab, using("`f1'" "`f2'" "`f1'" "`f2'" "`f1'" "`f2'") outcomes(3) ///
        rateratio frame(_oir3, replace)
    frame _oir3: local ids : char _dta[tabtools_statistic_ids]
    assert "`ids'" == "events person_years rate_ci irr_ci"
    frame _oir3: assert c(k) == 14
    sysuse auto, clear
    collect clear
    quietly collect: poisson rep78 mpg
    quietly regtab, frame(_oim, replace)
    capture noisily comptab _oim, rateframe(_oir3) rows(1)
    local crc = _rc
    display as text "  comptab rc `crc'"
    assert `crc' == 198
}
if _rc == 0 {
    display as result "  PASS: K3c rateratio frames carry irr_ci and comptab refuses them by name"
    local ++pass_count
}
else {
    display as error "  FAIL: K3c rateratio frame provenance (rc=`=_rc')"
    local ++fail_count
}

* K3d: zero events, missing bounds: "0.0 (–)", as the IRR column shows a
* missing estimate, never "0.0 (., .)".
capture noisily {
    _oi_strate, file("$OI_OUT/oi_zero.dta") d0(0) d1(20) y0(1000) y1(1500) ///
        lo0(.) hi0(.)
    stratetab, using("$OI_OUT/oi_zero") outcomes(1) frame(_oiz, replace)
    frame _oiz: local cell = strtrim(c4[5])
    display as text "  zero-event cell: `cell'"
    assert `"`cell'"' == "0.0 (" + uchar(8211) + ")"
    frame _oiz: local cell2 = strtrim(c4[6])
    assert strpos(`"`cell2'"', "13.3 (") == 1
}
if _rc == 0 {
    display as result "  PASS: K3d zero-event rate with missing bounds prints 0.0 (–)"
    local ++pass_count
}
else {
    display as error "  FAIL: K3d zero-event rate cell (rc=`=_rc')"
    local ++fail_count
}

* K3e: the Markdown header is one flattened row; the sub-header row is not
* a body row and r(markdown_rows) counts the data rows only.
capture noisily {
    _oi_strate, file("$OI_OUT/oi_ref.dta") d0(10) d1(20) y0(1000) y1(1500)
    local md "$OI_OUT/oi_strate.md"
    capture erase "`md'"
    stratetab, using("$OI_OUT/oi_ref") outcomes(1) outlabels("CV Events") ///
        markdown("`md'") frame(_oim, replace)
    local mrows = r(markdown_rows)
    frame _oim: local nbody = _N - 3
    assert `mrows' == `nbody'
    local res "$OI_OUT/oi_strate_md.txt"
    capture erase "`res'"
    shell python3 "$OI_TOOLS/md_facts.py" "`md'" "`res'"
    local tab = char(9)
    foreach want in "th`tab'Exposure" "th`tab'CV Events: Events" ///
        "th`tab'CV Events: Person-Years (PY)" "th`tab'CV Events: Per 1,000 PY (95% CI)" {
        _oi_hasfact "`res'" `"`want'"'
        if !r(found) display as error `"  missing: `want'"'
        assert r(found)
    }
    _oi_hasfact "`res'" "td`tab'Events"
    assert !r(found)
}
if _rc == 0 {
    display as result "  PASS: K3e Markdown header is the flattened outcome: statistic row"
    local ++pass_count
}
else {
    display as error "  FAIL: K3e Markdown header (rc=`=_rc')"
    local ++fail_count
}

* K3f: the rule above the second exposure block is drawn when that block is
* labelled "Exposure", as it is for any other label.
capture noisily {
    _oi_strate, file("$OI_OUT/oi_ref.dta") d0(10) d1(20) y0(1000) y1(1500)
    _oi_strate, file("$OI_OUT/oi_cmp.dta") d0(12) d1(25) y0(1100) y1(1400)
    foreach lab in "Other" "Exposure" {
        local x "$OI_OUT/oi_strate_rule.xlsx"
        capture erase "`x'"
        stratetab, using("$OI_OUT/oi_ref" "$OI_OUT/oi_cmp") outcomes(1) ///
            explabels("Dose \ `lab'") xlsx("`x'") sheet("S") frame(_oir, replace)
        * exposure 2 header is frame row 7 (title, 2 headers, Dose, 2 rows)
        frame _oir: assert strtrim(c1[7]) == "`lab'"
        local res "$OI_OUT/oi_strate_rule.txt"
        capture erase "`res'"
        shell python3 "$OI_TOOLS/xlsx_facts.py" "`x'" "S" "`res'"
        local seen 0
        tempname h
        file open `h' using "`res'", read text
        file read `h' line
        while r(eof) == 0 {
            if substr(`"`line'"', 1, 10) == "bottom B6 " local seen 1
            file read `h' line
        }
        file close `h'
        display as text "  label `lab': rule under row 6 = `seen'"
        assert `seen'
    }
}
if _rc == 0 {
    display as result "  PASS: K3f exposure-block rule does not depend on the block label"
    local ++pass_count
}
else {
    display as error "  FAIL: K3f exposure-block rule (rc=`=_rc')"
    local ++fail_count
}

* K3g: rate cells round at the exact unit 0.01, as regtab does: a rate
* whose per-1,000 value is the double nearest 422.395 shows as round(x, .01)
* gives it. 10^(-2) is one ulp above 0.01 and rounded it down.
capture noisily {
    clear
    quietly set obs 2
    generate byte cat = _n - 1
    generate double _D = 50
    generate double _Y = 1000
    generate double _Rate = 0.422395
    generate double _Lower = _Rate / 2
    generate double _Upper = _Rate * 2
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    quietly save "$OI_OUT/oi_tie.dta", replace
    local x = 0.422395 * 1000
    local want = strtrim(string(round(`x', .01), "%11.2f"))
    assert round(`x', .01) != round(`x', 10^(-2))
    stratetab, using("$OI_OUT/oi_tie") outcomes(1) digits(2) frame(_oit, replace)
    frame _oit: local cell = strtrim(c4[5])
    display as text "  cell `cell'; want rate `want'"
    assert strpos(`"`cell'"', "`want' (") == 1
}
if _rc == 0 {
    display as result "  PASS: K3g rate cells round at the exact unit"
    local ++pass_count
}
else {
    display as error "  FAIL: K3g rate rounding unit (rc=`=_rc')"
    local ++fail_count
}

* K3h: a quoted outcomeids() list is split into its identities.
capture noisily {
    _oi_strate, file("$OI_OUT/oi_ref.dta") d0(10) d1(20) y0(1000) y1(1500)
    _oi_strate, file("$OI_OUT/oi_cmp.dta") d0(12) d1(25) y0(1100) y1(1400)
    stratetab, using("$OI_OUT/oi_ref" "$OI_OUT/oi_cmp") outcomes(2) ///
        outcomeids("cv_event \ rare_event") frame(_oiq, replace)
    frame _oiq: local id1 : char _dta[tabtools_outcome_id_1]
    frame _oiq: local id2 : char _dta[tabtools_outcome_id_2]
    display as text "  ids: `id1' | `id2'"
    assert "`id1'" == "cv_event" & "`id2'" == "rare_event"
    stratetab, using("$OI_OUT/oi_ref" "$OI_OUT/oi_cmp") outcomes(2) ///
        outcomeids(cv_event \ rare_event) frame(_oiq2, replace)
    frame _oiq2: local u1 : char _dta[tabtools_outcome_id_1]
    assert "`u1'" == "cv_event"
    * guard: items quoted one by one keep working
    stratetab, using("$OI_OUT/oi_ref" "$OI_OUT/oi_cmp") outcomes(2) ///
        outcomeids("t1" \ "t2") frame(_oiq2, replace)
    frame _oiq2: local v1 : char _dta[tabtools_outcome_id_1]
    frame _oiq2: local v2 : char _dta[tabtools_outcome_id_2]
    assert "`v1'" == "t1" & "`v2'" == "t2"
}
if _rc == 0 {
    display as result "  PASS: K3h quoted outcomeids() list is split into identities"
    local ++pass_count
}
else {
    display as error "  FAIL: K3h quoted outcomeids() (rc=`=_rc')"
    local ++fail_count
}

**# Summary
set dp period
foreach f in _oi1 _oip _oipe _oiep _ois _oir3 _oim _oiz _oir _oit _oiq _oiq2 {
    capture frame drop `f'
}
global OI_TOOLS
global OI_OUT
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_open_items_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _oi
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_open_items_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _oi

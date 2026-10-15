* test_ssc_prerelease_2026_10_15.do - SSC pre-submission output and help-example fixes
*
* Findings from the 1.0.0 SSC readiness pass (2026-10-15), each red on the
* 2026-10-13 tree:
*   1. comptab rate mode / hrcomptab echoed footnote() to the console with
*      the raw " \ " paragraph separator; the workbook already split it.
*   2. stacktab echoed note() the same way.
*   3. tabtools, detail printed a broken desctab sentence ("...Table 1
*      engine" / "number formats and ...").
*   4. survtab help Example 2 asked for rmst(30) on drugtr, beyond the
*      placebo group's follow-up (23), so the example failed with r(198).
*   5. puttab help Examples 2-3 ran after Example 1's collapse without
*      reloading auto, so they failed with r(111).
*   6. The xlsx completion line differed by command ("Exported 13 rows x 5
*      cols to", "Exported to", "puttab: wrote ... data rows x", "stacktab:
*      2 blocks -> ...", none at all for table1_tc/desctab). Every command
*      now prints "Exported <r> rows × <c> cols to <file>, sheet <s>", and
*      <r> x <c> is the sheet's final used range -- title, notes and
*      footnotes included -- checked against openpyxl (tools/xlsx_dims.py).
*   7. survtab printed the group N without thousands separators (N=8000).
*   8. A value that rounds to zero printed with its sign, "(-0.00, 0.05)",
*      in every sink (console, xlsx, CSV, Markdown, frame) and in tabcell.
*      The sign is dropped where tabtools formats a number; caller strings
*      and value labels such as "Wk -0" or "Stage-0.0)" pass unchanged.
*   9. The small-cell notes of crosstab and desctab/table1_tc were one long
*      display line, hard-wrapped mid-word ("wit" / "> hheld").
*  10. Two number-to-text paths outside string()/strofreal() still printed
*      a signed zero: effecttab's tostring of margins estimates under
*      cformat() ("-0.00" in C4) and the desctab/table1_tc test statistic
*      ("t(398)= -0.00"); also effecttab from() interval bounds and a
*      puttab numeric column.
* Console output is captured with a second named text log and read back
* line by line.

clear all
set more off
set varabbrev off
version 17.0

capture log close _spr
log using "test_ssc_prerelease_2026_10_15.log", replace text name(_spr)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local cap "`output_dir'/spr_console.txt"
global SPR_TOOL "`qa_dir'/tools/xlsx_dims.py"

* Installs into PLUS: only ever inside run_all.do's sandboxed sysdir.
if strpos(c(sysdir_plus), "_tabtools_plus") == 0 {
    display as error "run this suite through run_all.do (sandboxed PLUS)"
    exit 198
}
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

**# Helper
* Count lines of text log `file' equal to `exact' (r(n_exact)) and lines
* starting with `sub' (r(n_sub)), both after trimming. Command echoes start
* with ". " or "> ", so they never count as printed output.
capture program drop _spr_lines
program define _spr_lines, rclass
    version 17.0
    args file exact sub
    tempname fh
    local n_exact = 0
    local n_sub = 0
    file open `fh' using "`file'", read text
    file read `fh' line
    while r(eof) == 0 {
        local t = strtrim(`"`macval(line)'"')
        if `"`macval(t)'"' == `"`exact'"' local ++n_exact
        if `"`sub'"' != "" & strpos(`"`macval(t)'"', `"`sub'"') == 1 local ++n_sub
        file read `fh' line
    }
    file close `fh'
    return scalar n_exact = `n_exact'
    return scalar n_sub = `n_sub'
end

* r(nr), r(nc): the used range of sheet `sheet' in `book', read with
* openpyxl (tools/xlsx_dims.py), independent of tabtools' own reader.
capture program drop _spr_range
program define _spr_range, rclass
    version 17.0
    args book sheet
    local res "$SPR_CAP.dims"
    capture erase "`res'"
    shell python3 "$SPR_TOOL" "`book'" "`sheet'" "`res'"
    tempname fh
    file open `fh' using "`res'", read text
    file read `fh' line
    file close `fh'
    gettoken nr nc : line
    return scalar nr = real("`nr'")
    return scalar nc = real(strtrim("`nc'"))
end

* Run `0' with its console captured in `cap' (linesize 255, so a status
* line is never wrapped) and check its single "Exported" line: the shared
* wording, sheet `$SPR_SHEET' of `$SPR_BOOK', and r x c equal to the
* sheet's used range. No legacy wording may appear.
capture program drop _spr_status
program define _spr_status
    version 17.0
    local cap "$SPR_CAP"
    local ls = c(linesize)
    set linesize 255
    capture erase "`cap'"
    quietly log using "`cap'", text replace name(_spr_cap)
    capture noisily `0'
    local crc = _rc
    quietly log close _spr_cap
    set linesize `ls'
    if `crc' exit `crc'
    tempname fh
    local n 0
    local legacy 0
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if ustrregexm(`"`macval(line)'"', "^Exported ([0-9]+) rows × ([0-9]+) cols to (.+), sheet (.+)$") {
            local ++n
            local nr = real(ustrregexs(1))
            local nc = real(ustrregexs(2))
            local fl = ustrregexs(3)
            local sh = ustrregexs(4)
        }
        if strpos(`"`macval(line)'"', "Exported to ") == 1 | ///
            strpos(`"`macval(line)'"', "puttab: wrote") == 1 | ///
            ustrregexm(`"`macval(line)'"', "^stacktab: [0-9]+ blocks") local ++legacy
        file read `fh' line
    }
    file close `fh'
    assert `n' == 1
    assert `legacy' == 0
    assert `"`fl'"' == `"$SPR_BOOK"'
    assert `"`sh'"' == `"$SPR_SHEET"'
    _spr_range "$SPR_BOOK" "$SPR_SHEET"
    if r(nr) != `nr' | r(nc) != `nc' {
        display as error "status `nr' x `nc', sheet used range `r(nr)' x `r(nc)'"
        exit 9
    }
end

**# 1. hrcomptab / comptab rate mode footnote paragraphs on the console
local ++test_count
capture noisily {
    webuse drugtr, clear
    generate byte agegrp = 1 + (age >= 55) + (age >= 60)
    label define agegrp 1 "<55" 2 "55-59" 3 "60+"
    label values agegrp agegrp
    label variable agegrp "Age band"
    generate byte older = age >= 57
    label variable older "Rates only"
    stset studytime, failure(died)
    quietly ratetab agegrp older, outlabels("Death") frame(rates, replace)
    collect clear
    quietly collect: stcox i.agegrp drug
    quietly collect: stcox i.agegrp drug age
    quietly regtab, frame(models, replace) noint compact models("M1 \ M2") addrow("Events" "31" "31")
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    hrcomptab rates, modelframes(models) rows(all) allmodels modelonly ///
        effect("Rate ratio") footnote("SPR para one. \ SPR para two.")
    log close _spr_cap
    _spr_lines "`cap'" "SPR para one." "SPR para one. \"
    assert r(n_exact) == 1
    assert r(n_sub) == 0
    _spr_lines "`cap'" "SPR para two." ""
    assert r(n_exact) == 1
}
if _rc == 0 {
    display as result "  PASS: hrcomptab footnote paragraphs print on separate console lines"
    local ++pass_count
}
else {
    local _spr_rc = _rc
    capture log close _spr_cap
    display as error "  FAIL: hrcomptab footnote console split (rc=`_spr_rc')"
    local ++fail_count
}

**# 2. stacktab note paragraphs on the console
local ++test_count
capture noisily {
    local book "`output_dir'/spr_stack.xlsx"
    capture erase "`book'"
    matrix MA = (1.23, 1.05, 1.44)
    matrix colnames MA = HR LL UL
    quietly puttab using "`book'", sheet("A") matrix(MA) title("Model A")
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    stacktab using "`book'", sheet("T") blocks(sheet(A)) note("SPR note one. \ SPR note two.") display
    log close _spr_cap
    _spr_lines "`cap'" "SPR note one." "SPR note one. \"
    assert r(n_exact) == 1
    assert r(n_sub) == 0
    _spr_lines "`cap'" "SPR note two." ""
    assert r(n_exact) == 1
}
if _rc == 0 {
    display as result "  PASS: stacktab note paragraphs print on separate console lines"
    local ++pass_count
}
else {
    local _spr_rc = _rc
    capture log close _spr_cap
    display as error "  FAIL: stacktab note console split (rc=`_spr_rc')"
    local ++fail_count
}

**# 3. tabtools, detail desctab description reads as a sentence
local ++test_count
capture noisily {
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    tabtools, detail
    log close _spr_cap
    _spr_lines "`cap'" "with number formats and optional composite cells" ""
    assert r(n_exact) == 1
    _spr_lines "`cap'" "number formats and optional composite cells such" ""
    assert r(n_exact) == 0
}
if _rc == 0 {
    display as result "  PASS: tabtools, detail desctab description"
    local ++pass_count
}
else {
    local _spr_rc = _rc
    capture log close _spr_cap
    display as error "  FAIL: tabtools, detail desctab description (rc=`_spr_rc')"
    local ++fail_count
}

**# 4. survtab help Examples 1-2 run in help order
local ++test_count
capture noisily {
    findfile survtab.sthlp
    _spr_lines "`r(fn)'" "" "{phang2}{cmd:. survtab, times(10 20 30) by(drug) reverse rmst(20) ///}"
    assert r(n_sub) == 1
    local book "`output_dir'/spr_survival.xlsx"
    capture erase "`book'"
    webuse drugtr, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) xlsx("`book'") sheet("KM") title("Table 2. Survival")
    survtab, times(10 20 30) by(drug) reverse rmst(20) xlsx("`book'") sheet("CI") ///
        title("Cumulative Incidence") timeunit(months)
}
if _rc == 0 {
    display as result "  PASS: survtab help Example 2 runs after Example 1"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab help Example 2 (rc=`=_rc')"
    local ++fail_count
}

**# 5. puttab help Examples 1-3 run in help order
local ++test_count
capture noisily {
    findfile puttab.sthlp
    local hf "`r(fn)'"
    tempname fh
    local after_ex2 = 0
    local reload = 0
    file open `fh' using "`hf'", read text
    file read `fh' line
    while r(eof) == 0 {
        if `after_ex2' == 1 {
            if strpos(`"`macval(line)'"', "{cmd:. sysuse auto, clear}") local reload = 1
            local after_ex2 = 2
        }
        if strpos(`"`macval(line)'"', "{bf:Example 2: A named frame}") local after_ex2 = 1
        file read `fh' line
    }
    file close `fh'
    assert `reload' == 1
    local book "`output_dir'/spr_puttab.xlsx"
    capture erase "`book'"
    capture frame drop top
    sysuse auto, clear
    collapse (mean) price mpg (count) n=price, by(foreign)
    puttab foreign price mpg n using "`book'", sheet("ByOrigin")
    sysuse auto, clear
    frame put make mpg price in 1/10, into(top)
    puttab using "`book'", sheet("Top10") frame(top)
    regress price mpg weight foreign
    matrix T = r(table)'
    puttab using "`book'", sheet("Coefs") matrix(T)
    frame drop top
}
if _rc == 0 {
    display as result "  PASS: puttab help Examples 1-3 run in help order"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab help Examples 1-3 (rc=`=_rc')"
    local ++fail_count
}

**# 6. one completion line, equal to the final sheet, for every table command
local ++test_count
capture noisily {
    local book "`output_dir'/spr_status.xlsx"
    capture erase "`book'"
    global SPR_CAP "`cap'"
    global SPR_BOOK "`book'"
    sysuse auto, clear
    global SPR_SHEET "ct"
    _spr_status crosstab foreign rep78, xlsx("`book'") sheet(ct)
    global SPR_SHEET "ct2"
    _spr_status crosstab foreign rep78, xlsx("`book'") sheet(ct2) title("Table 1") footnote("Note: a \ b")
    global SPR_SHEET "t1"
    _spr_status table1_tc, by(foreign) vars(price contn \ rep78 cat) excel("`book'") sheet(t1)
    global SPR_SHEET "t1b"
    _spr_status table1_tc, by(foreign) vars(price contn \ rep78 cat) excel("`book'") sheet(t1b) title("Table 1") footnote("Note: a")
    global SPR_SHEET "dt"
    _spr_status desctab, by(foreign) vars(price contn \ rep78 cat) excel("`book'") sheet(dt) smallcells(5)
    collect clear
    quietly collect: regress price i.foreign mpg weight
    global SPR_SHEET "rg"
    _spr_status regtab, xlsx("`book'") sheet(rg) frame(spr_f1, replace) noint
    global SPR_SHEET "rg2"
    _spr_status regtab, xlsx("`book'") sheet(rg2) noint title("Table 2") footnote("Note: a \ b")
    collect clear
    quietly collect: regress price i.foreign##c.mpg weight
    quietly regtab, frame(spr_f2, replace) noint
    global SPR_SHEET "cp"
    _spr_status comptab spr_f1 spr_f2, rows(1 \ 1 2) xlsx("`book'") sheet(cp)
    global SPR_SHEET "cp2"
    _spr_status comptab spr_f1 spr_f2, rows(1 \ 1 2) xlsx("`book'") sheet(cp2) title("Table 3") footnote("Note: a \ b")
    matrix spr_E = (2, 1, 3, 0.01)
    matrix rownames spr_E = Effect
    global SPR_SHEET "ef"
    _spr_status effecttab, from(spr_E) xlsx("`book'") sheet(ef) title("Table 4") footnote("Note: a \ b")
    capture frame drop spr_pf
    frame put make price in 1/3, into(spr_pf)
    global SPR_SHEET "pt"
    _spr_status puttab using "`book'", frame(spr_pf) sheet(pt)
    global SPR_SHEET "pt2"
    _spr_status puttab using "`book'", frame(spr_pf) sheet(pt2) title("Table 5") footnote("Note: a \ b")
    * puttab's r() still counts the assembled table (documented), while
    * the completion line reports the sheet: blank row 1 and column A
    quietly puttab using "`book'", frame(spr_pf) sheet(pt3)
    assert r(n_rows) == 4 & r(n_cols) == 2
    _spr_range "`book'" "pt3"
    assert r(nr) == 5 & r(nc) == 3
    matrix spr_MA = (1.23, 1.05, 1.44)
    matrix colnames spr_MA = HR LL UL
    global SPR_SHEET "pm"
    _spr_status puttab using "`book'", sheet(pm) matrix(spr_MA) title("Model A")
    global SPR_SHEET "st"
    _spr_status stacktab using "`book'", sheet(st) blocks(sheet(pm)) title("Stacked") note("Note. \ Two.")
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    global SPR_SHEET "sv"
    _spr_status survtab, times(10 20) by(drug) xlsx("`book'") sheet(sv)
    * a time beyond a group's follow-up adds survtab's own note row
    global SPR_SHEET "sv2"
    _spr_status survtab, times(10 20 30) by(drug) xlsx("`book'") sheet(sv2) title("Table 6") footnote("Note: a")
    global SPR_SHEET "rt"
    _spr_status ratetab drug, xlsx("`book'") sheet(rt) title("Table 7") footnote("Note: a \ b")
    generate byte agegrp = 1 + (age >= 55) + (age >= 60)
    quietly ratetab agegrp, outlabels("Death") frame(spr_rates, replace)
    collect clear
    quietly collect: stcox i.agegrp drug
    quietly regtab, frame(spr_models, replace) noint compact
    global SPR_SHEET "hc"
    _spr_status hrcomptab spr_rates, modelframes(spr_models) rows(all) allmodels modelonly effect("Rate ratio") xlsx("`book'") sheet(hc) title("Table 8") footnote("Note: a \ b")
    frame drop spr_pf
}
local _t6 = _rc
capture frame drop spr_pf
macro drop SPR_BOOK SPR_SHEET
if `_t6' == 0 {
    display as result "  PASS: one shared Exported line, equal to the final used range (title/notes/footnotes)"
    local ++pass_count
}
else {
    display as error "  FAIL: shared Exported line (rc=`_t6')"
    local ++fail_count
}

**# 7. survtab group N with thousands separators
local ++test_count
capture noisily {
    local book "`output_dir'/spr_survn.xlsx"
    capture erase "`book'"
    webuse drugtr, clear
    quietly expand 400
    quietly stset studytime, failure(died)
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    survtab, times(10 20) by(drug) xlsx("`book'") sheet("N")
    log close _spr_cap
    local found 0
    tempname fh
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "0 (N=8,000)") & strpos(`"`macval(line)'"', "1 (N=11,200)") local ++found
        assert strpos(`"`macval(line)'"', "N=8000") == 0
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
    import excel using "`book'", sheet("N") allstring clear
    local hits 0
    foreach v of varlist _all {
        quietly count if inlist(`v', "0 (N=8,000)", "1 (N=11,200)")
        local hits = `hits' + r(N)
    }
    assert `hits' == 2
}
if _rc == 0 {
    display as result "  PASS: survtab N=8,000 / N=11,200 on the console and in the workbook"
    local ++pass_count
}
else {
    local _spr_rc = _rc
    capture log close _spr_cap
    display as error "  FAIL: survtab N thousands separators (rc=`_spr_rc')"
    local ++fail_count
}

**# 8. a value that rounds to zero prints unsigned; caller strings unchanged
local ++test_count
capture noisily {
    local stem "`output_dir'/spr_nz"
    foreach ext in xlsx csv md {
        capture erase "`stem'.`ext'"
    }
    matrix spr_Z = (-0.003, -0.004, 0.05, 0.9 \ -1.004, -1.2, -0.8, 0.01)
    matrix rownames spr_Z = Effect Other
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    effecttab, from(spr_Z) xlsx("`stem'.xlsx") sheet("Z") csv("`stem'.csv") ///
        markdown("`stem'.md") frame(spr_zf, replace)
    log close _spr_cap
    * console, CSV, Markdown: the zero row unsigned, the negative row signed
    foreach f in "`cap'" "`stem'.csv" "`stem'.md" {
        local z 0
        local neg 0
        local bad 0
        tempname fh
        file open `fh' using "`f'", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "-0.00") local ++bad
            if strpos(`"`macval(line)'"', "(0.00, 0.05)") local ++z
            if strpos(`"`macval(line)'"', "(-1.20, -0.80)") & strpos(`"`macval(line)'"', "-1.00") local ++neg
            file read `fh' line
        }
        file close `fh'
        assert `bad' == 0
        assert `z' == 1
        assert `neg' == 1
    }
    frame spr_zf {
        quietly count if c1 == "0.00" & c2 == "(0.00, 0.05)"
        assert r(N) == 1
        quietly count if c1 == "-1.00" & c2 == "(-1.20, -0.80)"
        assert r(N) == 1
    }
    frame drop spr_zf
    import excel using "`stem'.xlsx", sheet("Z") allstring clear
    quietly count if C == "0.00" & D == "(0.00, 0.05)"
    assert r(N) == 1
    quietly count if C == "-1.00" & D == "(-1.20, -0.80)"
    assert r(N) == 1
    * tabcell: the cell, its stored copy, a genuinely negative cell, sep("-")
    tabcell est, b(-0.003) ll(-0.004) ul(0.05) local(spr_c)
    assert `"`r(cell)'"' == "0.00 (0.00, 0.05)"
    assert `"`spr_c'"' == "0.00 (0.00, 0.05)"
    tabcell est, b(-1.003) ll(-1.204) ul(-0.996)
    assert `"`r(cell)'"' == "-1.00 (-1.20, -1.00)"
    tabcell est, b(-0.0004) ll(-0.0012) ul(0.0007) format(%5.3f)
    assert `"`r(cell)'"' == "0.000 (-0.001, 0.001)"
    tabcell est, b(-0.5) ll(-1) ul(-0.001) sep("-")
    assert `"`r(cell)'"' == "-0.50 (-1.00-0.00)"
    * a collected model whose estimate and interval all round to -0.00
    clear
    set seed 20261015
    quietly set obs 400
    generate double x = rnormal()
    generate double y = -0.003 * x + 1e-5 * rnormal()
    collect clear
    quietly collect: regress y x
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    regtab, xlsx("`stem'.xlsx") sheet("R") csv("`stem'_r.csv") frame(spr_rf, replace) noint
    log close _spr_cap
    local hits 0
    tempname fh
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if ustrregexm(`"`macval(line)'"', "\| +x +0\.00 +\(0\.00, 0\.00\)") local ++hits
        assert strpos(`"`macval(line)'"', "-0.00") == 0
        file read `fh' line
    }
    file close `fh'
    assert `hits' == 1
    frame spr_rf: quietly count if strpos(c1, "-0.00") | strpos(c2, "-0.00")
    assert r(N) == 0
    frame drop spr_rf
    * caller strings and value labels are never rewritten
    clear
    input str20 s
    "Stage-0.0)"
    "Wk -0"
    "Group -0"
    "Age -0.0 yrs"
    "BMI(-0.0)"
    "-0.00-0.01"
    "-0.00"
    end
    quietly puttab s using "`stem'.xlsx", sheet("S") csv("`stem'_s.csv") markdown("`stem'_s.md")
    import excel using "`stem'.xlsx", sheet("S") allstring clear
    foreach t in "Stage-0.0)" "Wk -0" "Group -0" "Age -0.0 yrs" "BMI(-0.0)" "-0.00-0.01" "-0.00" {
        quietly count if B == "`t'"
        assert r(N) == 1
        _spr_lines "`stem'_s.csv" "`t'" ""
        assert r(n_exact) == 1
        _spr_lines "`stem'_s.md" "| `t' |" ""
        assert r(n_exact) == 1
    }
    clear
    set seed 1
    quietly set obs 600
    generate byte g = mod(_n, 3)
    label define spr_gl 0 "Stage-0.0)" 1 "Wk -0" 2 "Group -0"
    label values g spr_gl
    generate double x = rnormal()
    generate double y = x + rnormal()
    collect clear
    quietly collect: regress y x i.g
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    regtab, xlsx("`stem'.xlsx") sheet("L") noint
    log close _spr_cap
    foreach t in "Stage-0.0)" "Wk -0" "Group -0" {
        local hit 0
        tempname fh
        file open `fh' using "`cap'", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "| `t' ") | strpos(`"`macval(line)'"', " `t' ") local ++hit
            file read `fh' line
        }
        file close `fh'
        assert `hit' >= 1
    }
    import excel using "`stem'.xlsx", sheet("L") allstring clear
    foreach t in "Stage-0.0)" "Wk -0" "Group -0" {
        quietly count if strtrim(B) == "`t'"
        assert r(N) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: rounds-to-zero values unsigned in every sink; caller strings and labels unchanged"
    local ++pass_count
}
else {
    local _spr_rc = _rc
    capture log close _spr_cap
    capture frame drop spr_zf
    capture frame drop spr_rf
    display as error "  FAIL: negative zero / caller strings (rc=`_spr_rc')"
    local ++fail_count
}

**# 9. small-cell notes wrap at word boundaries
local ++test_count
capture noisily {
    local ls = c(linesize)
    set linesize 80
    sysuse auto, clear
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    crosstab foreign rep78, smallcells(5)
    table1_tc, by(foreign) vars(rep78 cat) smallcells(5)
    log close _spr_cap
    set linesize `ls'
    tempname fh
    local cont 0
    local seen 0
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        if ustrregexm(`"`macval(line)'"', "reconstruction|withheld|complementary|suppressed") {
            local ++seen
            if substr(`"`macval(line)'"', 1, 2) == "> " local ++cont
        }
        file read `fh' line
    }
    file close `fh'
    assert `seen' >= 2
    assert `cont' == 0
}
if _rc == 0 {
    display as result "  PASS: small-cell notes wrap on word boundaries"
    local ++pass_count
}
else {
    local _spr_rc = _rc
    capture log close _spr_cap
    set linesize 80
    display as error "  FAIL: small-cell note wrapping (rc=`_spr_rc')"
    local ++fail_count
}

**# 10. remaining number-to-text paths print a zero unsigned
local ++test_count
capture noisily {
    local stem "`output_dir'/spr_nz10"
    foreach ext in xlsx csv md {
        capture erase "`stem'.`ext'"
    }
    * B1: effecttab margins under cformat(): tostring path
    clear
    set seed 101
    quietly set obs 4000
    generate byte g = mod(_n, 2)
    generate double y = -0.0004 * g + 1e-7 * rnormal()
    quietly regress y i.g
    collect clear
    quietly collect: margins, dydx(g)
    quietly effecttab, xlsx("`stem'.xlsx") sheet("E1") cformat(%9.2f) csv("`stem'.csv") markdown("`stem'.md")
    import excel using "`stem'.xlsx", sheet("E1") allstring clear
    local negz 0
    foreach v of varlist _all {
        quietly count if ustrregexm(`v', "(^|[( ])-0\.00($|[,) ])")
        local negz = `negz' + r(N)
    }
    assert `negz' == 0
    foreach f in "`stem'.csv" "`stem'.md" {
        tempname fh
        file open `fh' using "`f'", read text
        file read `fh' line
        while r(eof) == 0 {
            assert !ustrregexm(`"`macval(line)'"', "(^|[|,( ])-0\.00($|[|,) ])")
            file read `fh' line
        }
        file close `fh'
    }
    * the estimate itself rounds to zero, so the check above saw a zero cell
    import excel using "`stem'.xlsx", sheet("E1") allstring clear
    quietly count if C == "0.00"
    assert r(N) >= 1
    * B2: table1_tc t statistic that rounds to zero
    clear
    quietly set obs 400
    generate byte g = _n > 200
    generate double x = cond(mod(_n, 2), 1, -1) + 1e-5 * g
    capture erase "`cap'"
    log using "`cap'", text replace name(_spr_cap)
    table1_tc, by(g) vars(x contn %6.2f) excel("`stem'.xlsx") sheet("T") statistic
    log close _spr_cap
    local tline 0
    tempname fh
    file open `fh' using "`cap'", read text
    file read `fh' line
    while r(eof) == 0 {
        assert strpos(`"`macval(line)'"', "= -0.00") == 0
        if strpos(`"`macval(line)'"', "t(398)=  0.00") local ++tline
        file read `fh' line
    }
    file close `fh'
    assert `tline' >= 1
    import excel using "`stem'.xlsx", sheet("T") allstring clear
    local hit 0
    foreach v of varlist _all {
        quietly count if strpos(`v', "t(398)=") & strpos(`v', "-0.00")
        assert r(N) == 0
        quietly count if strpos(`v', "t(398)=  0.00")
        local hit = `hit' + r(N)
    }
    assert `hit' == 1
    * effecttab from(): interval bounds through the display-format path
    matrix spr_F = (-0.003, -0.004, -0.001, 0.9)
    matrix rownames spr_F = Effect
    quietly effecttab, from(spr_F) cformat(%9.2f) frame(spr_ff, replace)
    frame spr_ff: quietly count if c1 == "0.00" & c2 == "(0.00, 0.00)"
    frame spr_ff: assert r(N) == 1
    frame drop spr_ff
    * puttab numeric column formatted by puttab
    clear
    quietly set obs 2
    generate double v = cond(_n == 1, -0.0004, -1.2)
    format v %4.2f
    quietly puttab v using "`stem'.xlsx", sheet("P") csv("`stem'_p.csv") markdown("`stem'_p.md")
    import excel using "`stem'.xlsx", sheet("P") allstring clear
    quietly count if B == "0.00"
    assert r(N) == 1
    quietly count if B == "-1.20"
    assert r(N) == 1
    _spr_lines "`stem'_p.md" "| 0.00 |" ""
    assert r(n_exact) == 1
}
if _rc == 0 {
    display as result "  PASS: effecttab tostring/from() and desctab statistics print a zero unsigned"
    local ++pass_count
}
else {
    local _spr_rc = _rc
    capture log close _spr_cap
    capture frame drop spr_ff
    display as error "  FAIL: remaining number-to-text paths (rc=`_spr_rc')"
    local ++fail_count
}

capture erase "`cap'"
macro drop SPR_CAP SPR_TOOL
tabtools set clear
display "RESULT: test_ssc_prerelease_2026_10_15 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _spr
if `fail_count' > 0 exit 1

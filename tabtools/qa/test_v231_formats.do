* test_v231_formats.do - tabtools 2.3.1: puttab nformat(), fc column formats,
* literal panelheader() and noindent; desctab/table1_tc nosmdhighlight and the smdthreshold() parse
*
* Expected cell text is written out by hand from the documented rules and
* read back with openpyxl (tools/xlsx_facts.py for values, an inline openpyxl
* read for SMD fill and bold); CSV and Markdown are read line by line.
* Nothing is checked through the xl() writer under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _v231
log using "test_v231_formats.log", replace text name(_v231)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/v231_facts.txt"
global V231_OUT "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* Fixture: integer counts (one beyond 1e9, one negative), a fractional
* column, a near-zero negative, a missing, a value-labelled integer column
* and a date column.
clear
input str4 grp double(n py tiny) long(cnt lab) double dt
"a" 1234567     98765.432  -0.001 1234567890  1 21915
"b" 12          1234.5      0.25  -1234       2 21916
"c" .           0           1     0           1 .
end
label define lab 1 "One" 2 "Two", replace
label values lab lab
format dt %td
tempfile v231_fixture
quietly save "`v231_fixture'"
global V231_FIX "`v231_fixture'"
capture program drop _v231_data
program define _v231_data
    quietly use "$V231_FIX", clear
end

* SMD fill/bold facts of sheet `sheet' of `book': one "fill <cell> <rgb>"
* line per filled cell and "bold <cell>" per bold cell, in $V231_SMD.
capture program drop _v231_style
program define _v231_style
    version 17.0
    args book sheet
    global V231_SMD "$V231_OUT/v231_style.txt"
    capture erase "$V231_SMD"
    shell python3 -c "import openpyxl,sys; ws=openpyxl.load_workbook(sys.argv[1])[sys.argv[2]]; out=[]; [out.extend((['fill '+c.coordinate+' '+str(c.fill.fgColor.rgb)] if c.fill.fill_type else [])+(['bold '+c.coordinate] if c.font.b else [])) for r in ws.iter_rows() for c in r if c.value is not None]; open(sys.argv[3],'w').write('\n'.join(out)+'\n')" "`book'" "`sheet'" "$V231_SMD"
    confirm file "$V231_SMD"
end

* Line `want' appears exactly `times' times in $V231_SMD.
capture program drop _v231_smd
program define _v231_smd
    version 17.0
    gettoken want 0 : 0
    gettoken times 0 : 0
    mata: st_local("_n", strofreal(sum(cat("$V231_SMD") :== st_local("want"))))
    if `_n' != `times' {
        display as error `"style fact "`want'" found `_n' times, expected `times'"'
        exit 9
    }
end

**# puttab nformat(): all three sinks, integer columns only
local ++test_count
capture noisily {
    local book "`output_dir'/v231_nf.xlsx"
    local csv "`output_dir'/v231_nf.csv"
    local md "`output_dir'/v231_nf.md"
    capture erase "`book'"
    _v231_data
    puttab grp n py cnt using "`book'", sheet("N") nformat(%12.0fc) ///
        digits(1) csv("`csv'") markdown("`md'")
    * Header row 2 at B2; data rows 3-5. Fractional py keeps digits(1), no
    * separators: its own format is the default %10.0g.
    _v_facts "`book'" "N"
    _v_value C3 "1,234,567"
    _v_value C4 "12"
    _v_empty C5
    _v_value D3 "98765.4"
    _v_value D4 "1234.5"
    _v_value D5 "0.0"
    _v_value E3 "1,234,567,890"
    _v_value E4 "-1,234"
    _v_value E5 "0"
    _v_line "`csv'" `"a,"1,234,567",98765.4,"1,234,567,890""' 1
    _v_line "`csv'" `"b,12,1234.5,"-1,234""' 1
    _v_line "`md'" "| a | 1,234,567 | 98765.4 | 1,234,567,890 |" 1
    _v_line "`md'" "| c |  | 0.0 | 0 |" 1
}
if _rc == 0 {
    display as result "  PASS: P1 nformat() groups integer columns in xlsx, csv, md"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 nformat() sinks (rc=`=_rc')"
    local ++fail_count
}

**# nformat(): a narrow width never overflows to scientific notation
local ++test_count
capture noisily {
    local md "`output_dir'/v231_wide.md"
    _v231_data
    puttab grp cnt, markdown("`md'") nformat(%6.0fc)
    _v_line "`md'" "| a | 1,234,567,890 |" 1
    _v_grep "`md'" "e[+]"
    assert r(n) == 0
    * nformat() decimals are honoured on integer columns
    puttab grp cnt, markdown("`md'") nformat(%5.1f)
    _v_line "`md'" "| a | 1234567890.0 |" 1
    _v_line "`md'" "| b | -1234.0 |" 1
}
if _rc == 0 {
    display as result "  PASS: P2 nformat() width rewrite and decimals"
    local ++pass_count
}
else {
    display as error "  FAIL: P2 nformat() width (rc=`=_rc')"
    local ++fail_count
}

**# A column's own fc format keeps separators; digits() sets decimals; gc does not
local ++test_count
capture noisily {
    local md "`output_dir'/v231_fc.md"
    _v231_data
    format py %12.1fc
    format n %9.0gc
    format tiny %9.3fc
    puttab grp n py tiny cnt, markdown("`md'") digits(2)
    * py: commas, 2 decimals (digits wins over the format's 1); n: %9.0gc
    * is not followed (auto's price carries %8.0gc), so no commas; cnt
    * (%12.0g) stays ungrouped; -0.001 under fc still loses its minus sign.
    _v_line "`md'" "| a | 1234567 | 98,765.43 | 0.00 | 1234567890 |" 1
    _v_line "`md'" "| b | 12 | 1,234.50 | 0.25 | -1234 |" 1
}
if _rc == 0 {
    display as result "  PASS: P3 fc display formats group without nformat(); gc ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: P3 fc/gc display formats (rc=`=_rc')"
    local ++fail_count
}

**# Default output unchanged; nformat() wins over an own fc format;
* value labels and dates are never reformatted
local ++test_count
capture noisily {
    local md "`output_dir'/v231_prec.md"
    _v231_data
    puttab grp n cnt lab dt, markdown("`md'")
    _v_line "`md'" "| a | 1234567 | 1234567890 | One | 01jan2020 |" 1
    format n %12.0fc
    puttab grp n cnt lab dt, markdown("`md'") nformat(%9.0f)
    _v_line "`md'" "| a | 1234567 | 1234567890 | One | 01jan2020 |" 1
    puttab grp n cnt lab dt, markdown("`md'") nformat(%12.0fc)
    _v_line "`md'" "| a | 1,234,567 | 1,234,567,890 | One | 01jan2020 |" 1
    _v_line "`md'" "| b | 12 | -1,234 | Two | 02jan2020 |" 1
}
if _rc == 0 {
    display as result "  PASS: P4 default unchanged; precedence; labels and dates untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: P4 precedence (rc=`=_rc')"
    local ++fail_count
}

**# matrix() and frame() sources
local ++test_count
capture noisily {
    local md "`output_dir'/v231_src.md"
    matrix M = (1234567, 1.5 \ 89, 2.25)
    matrix colnames M = count ratio
    matrix rownames M = r1 r2
    puttab, matrix(M) markdown("`md'") nformat(%12.0gc)
    _v_line "`md'" "| r1 | 1,234,567 | 1.50 |" 1
    _v_line "`md'" "| r2 | 89 | 2.25 |" 1
    _v231_data
    capture frame drop V231F
    frame copy default V231F
    clear
    local book "`output_dir'/v231_frame.xlsx"
    capture erase "`book'"
    puttab grp cnt using "`book'", frame(V231F) sheet("F") nformat(%12.0fc)
    _v_facts "`book'" "F"
    _v_value C3 "1,234,567,890"
    _v_value C4 "-1,234"
    frame drop V231F
}
if _rc == 0 {
    display as result "  PASS: P5 nformat() on matrix and frame sources"
    local ++pass_count
}
else {
    display as error "  FAIL: P5 matrix/frame sources (rc=`=_rc')"
    local ++fail_count
}

**# panel(): a numeric panel heading is not run through nformat()
local ++test_count
capture noisily {
    local md "`output_dir'/v231_panel.md"
    clear
    input int yr str4 lab double n
    2020 "x" 1500
    2021 "y" 2500
    end
    puttab lab n, markdown("`md'") panel(yr) nformat(%12.0fc)
    _v_line "`md'" "| **2020** |  |" 1
    _v_line "`md'" "| **2021** |  |" 1
    _v_line "`md'" "| &nbsp;&nbsp;&nbsp;x | 1,500 |" 1
}
if _rc == 0 {
    display as result "  PASS: P6 panel heading text unaffected by nformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: P6 panel heading (rc=`=_rc')"
    local ++fail_count
}

**# nformat() refusals write nothing
local ++test_count
capture noisily {
    local md "`output_dir'/v231_bad.md"
    foreach f in "%td" "junk" "%9s" "%9.2e" "12.0fc" {
        capture erase "`md'"
        _v231_data
        capture puttab grp n, markdown("`md'") nformat(`f')
        if _rc != 198 {
            display as error "nformat(`f') gave rc=`=_rc', expected 198"
            exit 9
        }
        capture confirm file "`md'"
        assert _rc == 601
    }
}
if _rc == 0 {
    display as result "  PASS: P7 invalid nformat() refused with 198, no file written"
    local ++pass_count
}
else {
    display as error "  FAIL: P7 nformat() refusals (rc=`=_rc')"
    local ++fail_count
}

**# panel(): literal panelheader() text and noindent
local ++test_count
capture noisily {
    local book "`output_dir'/v231_ph.xlsx"
    local md "`output_dir'/v231_ph.md"
    local csv "`output_dir'/v231_ph.csv"
    capture erase "`book'"
    clear
    input str10 lab double(e py) byte blk
    "Age <55" 10 1500 1
    "Age 55+" 20 2500 1
    "All" 5 900 2
    end
    label define blk 1 "A. Relapses" 2 "B. MRI", replace
    label values blk blk
    puttab lab e py using "`book'", sheet("L") panel(blk) noindent ///
        panelheader("" `"Rate "x""' "Person-years") nformat(%12.0fc) ///
        markdown("`md'") csv("`csv'")
    assert r(n_panels) == 2
    * Rows: header 2, A heading 3, its header 4, data 5-6, B heading 7,
    * its header 8, data 9; the literal text repeats under each heading.
    _v_facts "`book'" "L"
    _v_value B3 "A. Relapses"
    _v_value C4 `"Rate "x""'
    _v_value D4 "Person-years"
    _v_value B5 "Age <55"
    _v_value D6 "2,500"
    _v_value C8 `"Rate "x""'
    _v_value B9 "All"
    _v_line "`md'" "| Age 55+ | 20 | 2,500 |" 1
    _v_line "`csv'" "B. MRI,," 1
    * Default keeps the three-space indent.
    puttab lab e py using "`book'", sheet("I") panel(blk) panelheader("" "E" "PY")
    _v_facts "`book'" "I"
    _v_value B5 "   Age <55"
    _v_value C4 "E"
    * Refusals
    capture puttab lab e py, markdown("`md'") panel(blk) panelheader("" "a")
    assert _rc == 198
    capture puttab lab e py, markdown("`md'") noindent
    assert _rc == 198
    capture puttab lab e py, markdown("`md'") panelheader("" "a" "b")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P8 literal panelheader() text and noindent"
    local ++pass_count
}
else {
    display as error "  FAIL: P8 literal panelheader()/noindent (rc=`=_rc')"
    local ++fail_count
}

**# SMD highlighting: default, threshold, nosmdhighlight, smdthreshold(-1)
* auto: price SMD 0.109, mpg SMD 0.860 (body rows 4-5, SMD column F).
local ++test_count
capture noisily {
    local book "`output_dir'/v231_smd.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    desctab price mpg, by(foreign) smd xlsx("`book'") sheet("def")
    desctab price mpg, by(foreign) smd smdthreshold(0.2) xlsx("`book'") sheet("t02")
    desctab price mpg, by(foreign) smd nosmdhighlight xlsx("`book'") sheet("off")
    desctab price mpg, by(foreign) smd smdthreshold(-1) xlsx("`book'") sheet("m1")
    desctab price mpg, by(foreign) smd nosmdh xlsx("`book'") sheet("abbr")
    _v231_style "`book'" "def"
    _v231_smd "fill F4 FFFFEBCD" 1
    _v231_smd "fill F5 FFFFEBCD" 1
    _v231_smd "bold F4" 1
    _v231_smd "bold F5" 1
    _v231_style "`book'" "t02"
    _v231_smd "fill F4 FFFFEBCD" 0
    _v231_smd "fill F5 FFFFEBCD" 1
    foreach s in off m1 abbr {
        _v231_style "`book'" "`s'"
        _v231_smd "fill F4 FFFFEBCD" 0
        _v231_smd "fill F5 FFFFEBCD" 0
        _v231_smd "bold F4" 0
        _v231_smd "bold F5" 0
        _v_facts "`book'" "`s'"
        _v_value F4 "0.109"
        _v_value F5 "0.860"
    }
}
if _rc == 0 {
    display as result "  PASS: S1 nosmdhighlight removes fill and bold; values kept"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 SMD highlighting (rc=`=_rc')"
    local ++fail_count
}

**# table1_tc forwards nosmdhighlight; wtcompare honours it
local ++test_count
capture noisily {
    local book "`output_dir'/v231_smd2.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    table1_tc price mpg, by(foreign) smd nosmdhighlight xlsx("`book'") sheet("t1")
    _v231_style "`book'" "t1"
    _v231_smd "fill F5 FFFFEBCD" 0
    table1_tc price mpg, by(foreign) smd xlsx("`book'") sheet("t1d")
    _v231_style "`book'" "t1d"
    _v231_smd "fill F5 FFFFEBCD" 1
    set seed 231
    generate double w = 0.5 + runiform()
    desctab price mpg, by(foreign) smd wt(w) wtcompare xlsx("`book'") sheet("wd")
    _v231_style "`book'" "wd"
    _v_grep "$V231_SMD" "^fill .* FFFFEBCD$"
    local _wd = r(n)
    assert `_wd' >= 1
    desctab price mpg, by(foreign) smd wt(w) wtcompare nosmdhighlight ///
        xlsx("`book'") sheet("wo")
    _v231_style "`book'" "wo"
    _v_grep "$V231_SMD" "^fill .* FFFFEBCD$"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: S2 table1_tc and wtcompare honour nosmdhighlight"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 table1_tc/wtcompare (rc=`=_rc')"
    local ++fail_count
}

**# Conflicts and invalid thresholds refused before any output
local ++test_count
capture noisily {
    local book "`output_dir'/v231_smdbad.xlsx"
    foreach o in "nosmdhighlight smdthreshold(0.2)" "nosmdhighlight smdthreshold(0.1)" ///
        "smdthreshold(abc)" "smdthreshold(.)" "smdthreshold(0)" "smdthreshold(-0.5)" ///
        "smdthreshold(0.1 0.2)" {
        capture erase "`book'"
        sysuse auto, clear
        capture desctab price mpg, by(foreign) smd `o' xlsx("`book'")
        if _rc != 198 {
            display as error "`o' gave rc=`=_rc', expected 198"
            exit 9
        }
        capture confirm file "`book'"
        assert _rc == 601
    }
    * Accepted forms: scientific notation, and -1
    sysuse auto, clear
    desctab price mpg, by(foreign) smd smdthreshold(1e-1) xlsx("`book'") sheet("e")
    desctab price mpg, by(foreign) smd smdthreshold(-1) nopvalue xlsx("`book'") sheet("m")
}
if _rc == 0 {
    display as result "  PASS: S3 smdthreshold()/nosmdhighlight conflicts refused with 198"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 refusals (rc=`=_rc')"
    local ++fail_count
}

**# Markdown is never SMD-highlighted (documented in 2.3.1)
local ++test_count
capture noisily {
    local md "`output_dir'/v231_smd.md"
    sysuse auto, clear
    desctab price mpg, by(foreign) smd markdown("`md'")
    _v_grep "`md'" "0[.]860"
    assert r(n) == 1
    _v_grep "`md'" "[*][*]0[.]860"
    assert r(n) == 0
}
if _rc == 0 {
    display as result "  PASS: S4 Markdown SMD cells carry no highlight"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 Markdown SMD (rc=`=_rc')"
    local ++fail_count
}

**# Two Table 1 blocks in one sheet: table1_tc frame() + stacktab frames()
* The documented answer to a "blocks" request; pinned so the route keeps working.
local ++test_count
capture noisily {
    local book "`output_dir'/v231_blocks.xlsx"
    local md "`output_dir'/v231_blocks.md"
    capture erase "`book'"
    sysuse auto, clear
    table1_tc price mpg, by(foreign) frame(v231b1, replace)
    table1_tc headroom, by(foreign) frame(v231b2, replace)
    stacktab using "`book'", frames(v231b1 "A. Price" \ v231b2 "B. Size") ///
        sheet("Table 1") markdown("`md'")
    _v_line "`md'" "| Factor | Domestic | Foreign | p-value |" 1
    _v_line "`md'" "| **A. Price** |  |  |  |" 1
    _v_line "`md'" "| &nbsp;&nbsp;&nbsp;Price | 4782 (4184, 6234) | 5759 (4499, 7140) | 0.30 |" 1
    _v_line "`md'" "| **B. Size** |  |  |  |" 1
    _v_grep "`md'" "Headroom"
    assert r(n) == 1
    _v_facts "`book'" "Table 1"
    _v_value B3 "A. Price"
    frame drop v231b1
    frame drop v231b2
}
if _rc == 0 {
    display as result "  PASS: S5 two Table 1 blocks stacked in one sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 Table 1 blocks (rc=`=_rc')"
    local ++fail_count
}
capture frame drop v231b1
capture frame drop v231b2

**# Summary
display as result "RESULT: test_v231_formats tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _v231
if `fail_count' > 0 exit 1

* test_cycle_20261119_shared_core.do - shared-core option contracts
* (review cycle 2026-11-19, unit shared_core, findings F1-F3)
*
* Contracts:
*   F1  an empty smallcells() (also smallcells( ) and an abbreviation such
*       as smallc(), or smallcells(`k') with k undefined) is r(198) in
*       crosstab, desctab, puttab and comptab. It is never read as "no
*       masking" and never falls through to the session default; nothing is
*       printed or exported. Text inside another option (a title holding
*       "smallcells()") is not mistaken for the option. A session default
*       global written directly as +5 or 05 prints <5.
*   F2  frame() takes one name: frame(res replace), with the comma
*       forgotten, is r(198) and creates or replaces nothing; the private
*       helpers _tabtools_frame_preflight/_tabtools_frame_put refuse a
*       multi-word name too. frame(res, replace) still replaces.
*   F3  fontsize(-1) is a typed value and is refused (r(198)) like
*       fontsize(-5); it used to be the "not given" sentinel and exported at
*       the default size. fontsize(12) writes size 12 (read back with
*       openpyxl), an omitted fontsize writes 10 or the session default.
*       Follow-up: the same in regtab, effecttab, outtab and stacktab
*       frames(), which declared FONTSIZE(integer -1).
*
* Oracles: the data typed below (cells a=1 x b=0/1 hold 1 each), the console
* text captured in a side log, frame dir, and the workbook fonts read back by
* openpyxl (independent of the Mata xl() writer).

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _cy
log using "test_cycle_20261119_shared_core.log", replace text name(_cy)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global CY_OUT "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers
* _cy_run <command>: run it under capture noisily with a side log; the rc
* goes to $CY_RC and the console text to $CY_LOG.
capture program drop _cy_run
program define _cy_run
    version 17.0
    local _lg "$CY_OUT/_cy_side.log"
    capture log close _cyside
    quietly log using "`_lg'", text replace name(_cyside)
    capture noisily `0'
    global CY_RC = _rc
    quietly log close _cyside
    global CY_LOG = fileread("`_lg'")
end

* _cy_has <text>: 1 when the last _cy_run console text holds <text>
capture program drop _cy_has
program define _cy_has, rclass
    version 17.0
    return scalar has = strpos(`"$CY_LOG"', `"`0'"') > 0
end

* _cy_fonts <book> <sheet>: the distinct font sizes of the non-empty cells
* of one sheet, read back with openpyxl, into $CY_FONTS (space-separated)
capture program drop _cy_fonts
program define _cy_fonts
    version 17.0
    args book sheet
    local py "$CY_OUT/_cy_fonts.py"
    local out "$CY_OUT/_cy_fonts.txt"
    capture erase "`out'"
    tempname h
    file open `h' using "`py'", write text replace
    file write `h' "import sys" _n
    file write `h' "from openpyxl import load_workbook" _n
    file write `h' "ws = load_workbook(sys.argv[1])[sys.argv[2]]" _n
    file write `h' "s = sorted({int(c.font.sz) for r in ws.iter_rows() for c in r if c.value not in (None, '') and c.font is not None and c.font.sz is not None})" _n
    file write `h' "open(sys.argv[3], 'w').write(' '.join(str(x) for x in s))" _n
    file close `h'
    shell python3 "`py'" "`book'" "`sheet'" "`out'"
    confirm file "`out'"
    global CY_FONTS = fileread("`out'")
end

* the fixture: a=1 holds one person in each b column (2 x 3 table, N=60)
capture program drop _cy_data
program define _cy_data
    version 17.0
    clear
    quietly set obs 60
    gen byte a = cond(_n <= 2, 1, cond(_n <= 30, 2, 3))
    gen byte b = mod(_n, 2)
end

**# F1: empty smallcells() is refused

**## crosstab smallcells() is r(198) and prints no table
local ++test_count
capture noisily {
    _cy_data
    * unmasked, the a=1 cells print as "1 (3.3%)"; that text is the leak
    _cy_run crosstab a b
    assert $CY_RC == 0
    _cy_has 1 (3.3%)
    assert r(has) == 1
    _cy_run crosstab a b, smallcells()
    assert $CY_RC == 198
    _cy_has smallcells() is empty
    assert r(has) == 1
    _cy_has (3.3%)
    assert r(has) == 0
    _cy_has Total
    assert r(has) == 0
}
if _rc == 0 {
    display as result "  PASS: F1 crosstab smallcells() is r(198), no table printed"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 crosstab smallcells() is r(198), no table printed (rc=`=_rc')"
    local ++fail_count
}

**## blanks, an abbreviation and an undefined macro are refused too
local ++test_count
capture noisily {
    _cy_data
    foreach o in "smallcells( )" "smallc()" "smallcel(  )" "smallcells(`undefined_k')" {
        _cy_run crosstab a b, `o'
        if $CY_RC != 198 display as error "    `o': rc $CY_RC"
        assert $CY_RC == 198
        _cy_has (3.3%)
        assert r(has) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: F1 smallcells( ), smallc(), smallcells(\`undefined') are r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 blank/abbreviated/undefined smallcells() (rc=`=_rc')"
    local ++fail_count
}

**## an empty smallcells() does not fall through to the session default
local ++test_count
capture noisily {
    _cy_data
    quietly tabtools set smallcells 5
    * without the option the session default masks (sanity)
    _cy_run crosstab a b
    assert $CY_RC == 0
    _cy_has using session smallcells(5)
    assert r(has) == 1
    _cy_has <5
    assert r(has) == 1
    _cy_has (3.3%)
    assert r(has) == 0
    * with an empty option: refused, not silently the session default
    _cy_run crosstab a b, smallcells()
    assert $CY_RC == 198
    _cy_has using session
    assert r(has) == 0
    _cy_has <5
    assert r(has) == 0
    quietly tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: F1 empty smallcells() is refused, not the session default"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 empty smallcells() vs the session default (rc=`=_rc')"
    local ++fail_count
}
capture quietly tabtools set clear

**## a session global written directly as +5 or 05 prints <5 (the number, not its spelling)
local ++test_count
capture noisily {
    _cy_data
    foreach sp in "+5" "05" " 5" {
        quietly tabtools set clear
        global TABTOOLS_set_smallcells "`sp'"
        _cy_run crosstab a b
        assert $CY_RC == 0
        _cy_has using session smallcells(5)
        assert r(has) == 1
        _cy_has <5
        assert r(has) == 1
        _cy_has <+5
        assert r(has) == 0
        _cy_has <05
        assert r(has) == 0
    }
    global TABTOOLS_set_smallcells
    quietly tabtools set clear
}
global TABTOOLS_set_smallcells
if _rc == 0 {
    display as result "  PASS: F1 session smallcells global +5/05 prints <5"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 session smallcells global spelling (rc=`=_rc')"
    local ++fail_count
}
capture quietly tabtools set clear

**## text inside another option is not the option; valid forms still work
local ++test_count
capture noisily {
    _cy_data
    _cy_run crosstab a b, title("see smallcells() and smallc( ) below")
    assert $CY_RC == 0
    _cy_has 1 (3.3%)
    assert r(has) == 1
    _cy_run crosstab a b, smallcells(5) title("smallcells()")
    assert $CY_RC == 0
    _cy_has <5
    assert r(has) == 1
    _cy_has (3.3%)
    assert r(has) == 0
    _cy_run crosstab a b, smallcells(5, primary)
    assert $CY_RC == 0
    _cy_has <5
    assert r(has) == 1
    _cy_run crosstab a b, nosmallcells
    assert $CY_RC == 0
    _cy_has 1 (3.3%)
    assert r(has) == 1
}
if _rc == 0 {
    display as result "  PASS: F1 a title holding smallcells() is not refused; valid forms work"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 false positives or valid forms (rc=`=_rc')"
    local ++fail_count
}

**## desctab smallcells() is r(198) and prints no table
local ++test_count
capture noisily {
    _cy_data
    _cy_run desctab a, by(b)
    assert $CY_RC == 0
    _cy_has N=30
    assert r(has) == 1
    _cy_run desctab a, by(b) smallcells()
    assert $CY_RC == 198
    _cy_has smallcells() is empty
    assert r(has) == 1
    _cy_has N=30
    assert r(has) == 0
}
if _rc == 0 {
    display as result "  PASS: F1 desctab smallcells() is r(198), no table printed"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 desctab smallcells() (rc=`=_rc')"
    local ++fail_count
}

**## puttab smallcells() is r(198), with and without counts(); no workbook
local ++test_count
capture noisily {
    clear
    input str8 grp int n
    "A" 2
    "B" 40
    end
    local f "$CY_OUT/_cy_put.xlsx"
    capture erase "`f'"
    _cy_run puttab grp n using "`f'", sheet("S") smallcells()
    assert $CY_RC == 198
    _cy_has smallcells() is empty
    assert r(has) == 1
    capture confirm file "`f'"
    assert _rc != 0
    * with counts() and a session default the empty option used to take
    * the default at rc 0
    quietly tabtools set smallcells 5
    _cy_run puttab grp n using "`f'", sheet("S") counts(n) smallcells()
    assert $CY_RC == 198
    _cy_has smallcells() is empty
    assert r(has) == 1
    capture confirm file "`f'"
    assert _rc != 0
    quietly tabtools set clear
    * a threshold still masks the count 2
    capture erase "`f'"
    _cy_run puttab grp n using "`f'", sheet("S") counts(n) smallcells(5)
    assert $CY_RC == 0
    import excel using "`f'", sheet("S") allstring clear
    local _n_lt5 0
    local _n_raw2 0
    foreach v of varlist _all {
        quietly count if strtrim(`v') == "<5"
        local _n_lt5 = `_n_lt5' + r(N)
        quietly count if strtrim(`v') == "2"
        local _n_raw2 = `_n_raw2' + r(N)
    }
    assert `_n_lt5' == 1
    assert `_n_raw2' == 0
}
if _rc == 0 {
    display as result "  PASS: F1 puttab smallcells() is r(198) with and without counts()"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 puttab smallcells() (rc=`=_rc')"
    local ++fail_count
}
capture quietly tabtools set clear

**## comptab smallcells() is r(198) (the dispatcher used to drop it)
local ++test_count
capture noisily {
    clear
    quietly set obs 80
    set seed 20261119
    gen double x = rnormal()
    gen double y = 1 + 0.5 * x + rnormal()
    collect clear
    quietly collect: regress y x
    capture frame drop _cy_r1
    quietly regtab, frame(_cy_r1) noint
    _cy_run comptab _cy_r1, rows(1)
    assert $CY_RC == 0
    _cy_run comptab _cy_r1, rows(1) smallcells()
    assert $CY_RC == 198
    _cy_has smallcells() is empty
    assert r(has) == 1
}
if _rc == 0 {
    display as result "  PASS: F1 comptab smallcells() is r(198)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 comptab smallcells() (rc=`=_rc')"
    local ++fail_count
}

**# F2: frame() takes one name

**## desctab frame(res replace) is r(198) and creates nothing
local ++test_count
capture noisily {
    _cy_data
    capture frame drop res
    _cy_run desctab a, by(b) frame(res replace)
    assert $CY_RC == 198
    _cy_has invalid frame name
    assert r(has) == 1
    _cy_has frame(res, replace)
    assert r(has) == 1
    capture confirm frame res
    assert _rc != 0
    _cy_has N=30
    assert r(has) == 0
}
if _rc == 0 {
    display as result "  PASS: F2 desctab frame(res replace) is r(198), no frame created"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 desctab frame(res replace) (rc=`=_rc')"
    local ++fail_count
}

**## an existing frame is left untouched; frame(res, replace) still replaces
local ++test_count
capture noisily {
    capture frame drop res
    frame create res
    frame res: quietly set obs 99
    frame res: gen byte _cy_mark = 1
    _cy_data
    _cy_run crosstab a b, frame(res replace)
    assert $CY_RC == 198
    _cy_has invalid frame name
    assert r(has) == 1
    frame res: assert _N == 99
    frame res: confirm variable _cy_mark
    _cy_run crosstab a b, frame(res, replace)
    assert $CY_RC == 0
    frame res: capture confirm variable _cy_mark
    assert _rc != 0
    frame res: assert _N != 99
    capture frame drop bad
    _cy_run crosstab a b, frame(bad name)
    assert $CY_RC == 198
    capture confirm frame bad
    assert _rc != 0
    capture frame drop res
}
if _rc == 0 {
    display as result "  PASS: F2 crosstab frame(res replace)/frame(bad name) refused; frame(res, replace) replaces"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 crosstab frame() one-name contract (rc=`=_rc')"
    local ++fail_count
}

**## the private helpers refuse a multi-word frame name
local ++test_count
capture noisily {
    _cy_data
    capture frame drop bad
    capture frame drop res
    capture noisily _tabtools_frame_preflight "res replace" "frame()"
    assert _rc == 198
    capture noisily _tabtools_frame_put "bad name"
    assert _rc == 198
    capture confirm frame bad
    assert _rc != 0
    capture noisily _tabtools_frame_preflight "res, replace" "frame()"
    assert _rc == 0
    assert "`r(name)'" == "res"
    assert r(replace) == 1
}
if _rc == 0 {
    display as result "  PASS: F2 frame preflight/put refuse a multi-word name"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 frame preflight/put multi-word name (rc=`=_rc')"
    local ++fail_count
}

**# F3: fontsize(-1) is a typed value

**## fontsize(-1) is r(198) like fontsize(-5) in all four commands; no workbook
local ++test_count
capture noisily {
    _cy_data
    local f "$CY_OUT/_cy_fs.xlsx"
    foreach fs in -1 -5 0 73 {
        capture erase "`f'"
        _cy_run crosstab a b, xlsx("`f'") sheet("A") fontsize(`fs')
        if $CY_RC != 198 display as error "    crosstab fontsize(`fs'): rc $CY_RC"
        assert $CY_RC == 198
        _cy_has fontsize() must be between 1 and 72
        assert r(has) == 1
        capture confirm file "`f'"
        assert _rc != 0
    }
    capture erase "`f'"
    _cy_run desctab a, by(b) excel("`f'") sheet("A") fontsize(-1)
    assert $CY_RC == 198
    _cy_has fontsize() must be between 1 and 72
    assert r(has) == 1
    capture confirm file "`f'"
    assert _rc != 0
    clear
    input str8 grp int n
    "A" 2
    "B" 40
    end
    _cy_run puttab grp n using "`f'", sheet("A") fontsize(-1)
    assert $CY_RC == 198
    _cy_has fontsize() must be between 1 and 72
    assert r(has) == 1
    capture confirm file "`f'"
    assert _rc != 0
    clear
    quietly set obs 80
    set seed 20261119
    gen double x = rnormal()
    gen double y = 1 + 0.5 * x + rnormal()
    collect clear
    quietly collect: regress y x
    capture frame drop _cy_r1
    quietly regtab, frame(_cy_r1) noint
    _cy_run comptab _cy_r1, rows(1) xlsx("`f'") sheet("A") fontsize(-1)
    assert $CY_RC == 198
    _cy_has fontsize() must be between 1 and 72
    assert r(has) == 1
    capture confirm file "`f'"
    assert _rc != 0
    _cy_data
    _cy_run crosstab a b, xlsx("`f'") sheet("A") fontsize(abc)
    assert $CY_RC == 198
    capture confirm file "`f'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: F3 fontsize(-1) is r(198) in crosstab/desctab/puttab/comptab"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 fontsize(-1) refusal (rc=`=_rc')"
    local ++fail_count
}

**## typed, omitted and session font sizes reach the workbook
local ++test_count
capture noisily {
    _cy_data
    local f "$CY_OUT/_cy_fs_ok.xlsx"
    capture erase "`f'"
    quietly crosstab a b, xlsx("`f'") sheet("T12") fontsize(12)
    quietly crosstab a b, xlsx("`f'") sheet("T0")
    quietly tabtools set fontsize 11
    quietly crosstab a b, xlsx("`f'") sheet("TS")
    quietly crosstab a b, xlsx("`f'") sheet("TS9") fontsize(9)
    quietly tabtools set clear
    _cy_fonts "`f'" "T12"
    display "    T12 fonts: $CY_FONTS"
    assert strpos(" $CY_FONTS ", " 12 ") > 0
    assert strpos(" $CY_FONTS ", " 10 ") == 0
    _cy_fonts "`f'" "T0"
    display "    T0 fonts: $CY_FONTS"
    assert strpos(" $CY_FONTS ", " 10 ") > 0
    _cy_fonts "`f'" "TS"
    display "    TS fonts: $CY_FONTS"
    assert strpos(" $CY_FONTS ", " 11 ") > 0
    assert strpos(" $CY_FONTS ", " 10 ") == 0
    _cy_fonts "`f'" "TS9"
    display "    TS9 fonts: $CY_FONTS"
    assert strpos(" $CY_FONTS ", " 9 ") > 0
    assert strpos(" $CY_FONTS ", " 11 ") == 0
}
if _rc == 0 {
    display as result "  PASS: F3 fontsize(12), default 10, session 11 and override 9 reach the workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 workbook font sizes (rc=`=_rc')"
    local ++fail_count
}
capture quietly tabtools set clear

**## regtab, effecttab, outtab and stacktab frames(): fontsize(-1) is r(198); no workbook
local ++test_count
capture noisily {
    local f "$CY_OUT/_cy_fs2.xlsx"
    clear
    quietly set obs 300
    set seed 20261119
    gen byte e = runiform() < .5
    gen byte y = runiform() < .3 + .2 * e
    gen double x = rnormal()
    collect clear
    quietly collect: logit y x
    matrix _cy_M = (1.5, 0.8, 2.2, 0.04 \ 2.3, 1.1, 3.5, 0.001)
    matrix rownames _cy_M = Age Sex
    capture frame drop _cy_sa
    capture frame drop _cy_sb
    frame create _cy_sa
    frame _cy_sa {
        quietly set obs 2
        gen str5 a = "x"
        gen str5 b = "1"
    }
    frame copy _cy_sa _cy_sb
    foreach fs in -1 -5 abc {
        local cmds `"`"regtab, xlsx("`f'") sheet("A") noint fontsize(`fs')"' `"effecttab, from(_cy_M) xlsx("`f'") sheet("A") fontsize(`fs')"' `"outtab y, exposure(e) xlsx("`f'") sheet("A") fontsize(`fs')"' `"stacktab using "`f'", frames(_cy_sa "A" \ _cy_sb "B") sheet("A") fontsize(`fs')"'"'
        foreach c of local cmds {
            capture erase "`f'"
            _cy_run `c'
            if $CY_RC != 198 display as error `"    `macval(c)': rc $CY_RC"'
            assert $CY_RC == 198
            if "`fs'" != "abc" {
                _cy_has fontsize() must be between 1 and 72
                assert r(has) == 1
            }
            capture confirm file "`f'"
            assert _rc != 0
        }
    }
    * a typed size still reaches the workbook
    capture erase "`f'"
    quietly regtab, xlsx("`f'") sheet("R") noint fontsize(12)
    _cy_fonts "`f'" "R"
    assert strpos(" $CY_FONTS ", " 12 ") > 0
    quietly outtab y, exposure(e) xlsx("`f'") sheet("O") fontsize(+9)
    _cy_fonts "`f'" "O"
    assert strpos(" $CY_FONTS ", " 9 ") > 0
    quietly stacktab using "`f'", frames(_cy_sa "A" \ _cy_sb "B") sheet("S") fontsize(11)
    _cy_fonts "`f'" "S"
    assert strpos(" $CY_FONTS ", " 11 ") > 0
    quietly effecttab, from(_cy_M) xlsx("`f'") sheet("E") fontsize(13)
    _cy_fonts "`f'" "E"
    assert strpos(" $CY_FONTS ", " 13 ") > 0
}
local _rc_f3b = _rc
capture frame drop _cy_sa
capture frame drop _cy_sb
capture matrix drop _cy_M
if `_rc_f3b' == 0 {
    display as result "  PASS: F3 fontsize(-1) is r(198) in regtab/effecttab/outtab/stacktab frames()"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 fontsize(-1) in regtab/effecttab/outtab/stacktab (rc=`_rc_f3b')"
    local ++fail_count
}

**# X1: frame(default, replace) from another frame is refused and leaves the data
local ++test_count
capture noisily {
    frame change default
    sysuse auto, clear
    local _n0 = _N
    local _k0 = c(k)
    capture frame drop _cy_work
    frame create _cy_work
    frame change _cy_work
    sysuse auto, clear
    capture noisily desctab price mpg, by(foreign) frame(default, replace)
    assert _rc == 198
    capture noisily crosstab rep78 foreign, frame(default, replace)
    assert _rc == 198
    generate byte heavy = weight > 3000
    capture noisily outtab foreign, exposure(heavy) estimator(regress) frame(default, replace)
    assert _rc == 198
    frame change default
    assert _N == `_n0' & c(k) == `_k0'
    confirm variable make price mpg
}
local _rc_x1 = _rc
capture frame change default
capture frame drop _cy_work
if `_rc_x1' == 0 {
    display as result "  PASS: X1 frame(default, replace) is r(198) in desctab/crosstab/outtab; default data intact"
    local ++pass_count
}
else {
    display as error "  FAIL: X1 frame(default, replace) (rc=`_rc_x1')"
    local ++fail_count
}

**# X2: desctab with no varlist leaves the fweight and wt() variables out
local ++test_count
capture noisily {
    clear
    set obs 60
    generate byte g = mod(_n, 2)
    generate double x = _n / 7
    generate byte fw = 1 + mod(_n, 3)
    generate double pw = 1 + mod(_n, 4) / 4
    tempfile _x2
    quietly desctab [fw=fw], by(g) csv("`_x2'.csv")
    mata: _cy_L = cat(st_local("_x2") + ".csv")
    mata: assert(sum(strpos(_cy_L, "fw") :== 1) == 0)
    mata: assert(sum(strpos(_cy_L, "pw") :== 1) == 1)
    quietly desctab, by(g) wt(pw) csv("`_x2'b.csv")
    mata: _cy_L = cat(st_local("_x2") + "b.csv")
    mata: assert(sum(strpos(_cy_L, "pw") :== 1) == 0)
    mata: assert(sum(strpos(_cy_L, "fw") :== 1) == 1)
    capture mata: mata drop _cy_L
    capture erase "`_x2'.csv"
    capture erase "`_x2'b.csv"
}
local _rc_x2 = _rc
if `_rc_x2' == 0 {
    display as result "  PASS: X2 desctab default varlist omits the weight variables"
    local ++pass_count
}
else {
    display as error "  FAIL: X2 desctab default varlist and weights (rc=`_rc_x2')"
    local ++fail_count
}

capture frame drop _cy_r1
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_shared_core tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cy
if `fail_count' > 0 exit 1

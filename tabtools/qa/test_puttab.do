* test_puttab.do - Dedicated QA for puttab (styled in-memory exporter)

clear all
set more off
set varabbrev off

capture log close _puttab
log using "test_puttab.log", replace text name(_puttab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Source 1: current data, known-answer readback
**## collapse output exports with correct title, header, values
local ++test_count
local f1 "`output_dir'/test_puttab_data.xlsx"
capture erase "`f1'"
capture noisily {
    sysuse auto, clear
    collapse (mean) price (count) n=price, by(foreign)
    puttab foreign price n using "`f1'", sheet("ByOrigin") ///
        title("Means by origin") footnote("note") varlabels digits(1) zebra
    assert r(source) == "data"
    assert r(n_datarows) == 2
    assert r(n_cols) == 3
    assert r(n_rows) == 5
    assert "`r(sheet)'" == "ByOrigin"

    import excel using "`f1'", sheet("ByOrigin") clear allstring
    assert _N == 5
    assert A[1] == "Means by origin"
    * row 2 header: varlabels -> Car origin label, value-label honored in col 1
    assert strpos(A[2], "rigin") > 0 | A[2] == "Car origin" | A[2] == "Car type"
    assert A[3] == "Domestic"
    assert A[4] == "Foreign"
    assert A[5] == "note"
    * price mean for Domestic = 6072.4 -> 1 decimal "6072.4"
    assert B[3] == "6072.4"
    * n is integer-valued -> no decimals despite digits(1)
    assert C[3] == "52"
    assert C[4] == "22"
}
if _rc == 0 {
    display as result "  PASS: data source known-answer readback"
    local ++pass_count
}
else {
    display as error "  FAIL: data source known-answer readback (rc=`=_rc')"
    local ++fail_count
}

**## if/in row subsetting
local ++test_count
local f2 "`output_dir'/test_puttab_ifin.xlsx"
capture erase "`f2'"
capture noisily {
    sysuse auto, clear
    puttab make mpg if foreign==1 using "`f2'", sheet("F")
    assert r(n_datarows) == 22
    sysuse auto, clear
    puttab make mpg in 1/10 using "`f2'", sheet("G")
    assert r(n_datarows) == 10
}
if _rc == 0 {
    display as result "  PASS: if/in row subsetting"
    local ++pass_count
}
else {
    display as error "  FAIL: if/in row subsetting (rc=`=_rc')"
    local ++fail_count
}

**## varlist column subset + noheader
local ++test_count
local f3 "`output_dir'/test_puttab_noheader.xlsx"
capture erase "`f3'"
capture noisily {
    sysuse auto, clear
    puttab make mpg price in 1/3 using "`f3'", sheet("NH") noheader title("t")
    * title row + 3 data rows = 4, 3 cols
    assert r(n_cols) == 3
    assert r(n_datarows) == 3
    assert r(n_rows) == 4
    import excel using "`f3'", sheet("NH") clear allstring
    assert _N == 4
    assert A[1] == "t"
    * no header row: row 2 is first data row (make of obs 1)
    assert A[2] != "make"
}
if _rc == 0 {
    display as result "  PASS: varlist subset + noheader"
    local ++pass_count
}
else {
    display as error "  FAIL: varlist subset + noheader (rc=`=_rc')"
    local ++fail_count
}

**# Source 2: named frame
**## frame source exports, current data and frame unchanged
local ++test_count
local f4 "`output_dir'/test_puttab_frame.xlsx"
capture erase "`f4'"
capture noisily {
    sysuse auto, clear
    capture frame drop fmini
    frame put make mpg foreign in 1/5, into(fmini)
    local n_before = _N
    puttab using "`f4'", sheet("FR") frame(fmini) headershade borderstyle(academic)
    assert r(source) == "frame"
    assert r(n_datarows) == 5
    * current data unchanged
    assert _N == `n_before'
    assert "`:type make'" != ""
    * frame still intact
    frame fmini: assert _N == 5
    import excel using "`f4'", sheet("FR") clear allstring
    assert _N == 6
    assert A[1] == "make"
}
if _rc == 0 {
    display as result "  PASS: frame source + frame/data unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: frame source + frame/data unchanged (rc=`=_rc')"
    local ++fail_count
}
capture frame drop fmini

**## if on a frame subsets the frame's rows
local ++test_count
local f5 "`output_dir'/test_puttab_frameif.xlsx"
capture erase "`f5'"
capture noisily {
    sysuse auto, clear
    capture frame drop fall
    frame put make mpg foreign, into(fall)
    puttab if foreign==0 using "`f5'", sheet("D") frame(fall) noheader
    assert r(n_datarows) == 52
}
if _rc == 0 {
    display as result "  PASS: if on frame source"
    local ++pass_count
}
else {
    display as error "  FAIL: if on frame source (rc=`=_rc')"
    local ++fail_count
}
capture frame drop fall

**# Source 3: matrix
**## matrix exports rownames as labels, colnames as header, per-column digits
local ++test_count
local f6 "`output_dir'/test_puttab_matrix.xlsx"
capture erase "`f6'"
capture noisily {
    clear
    matrix M = (1.5, 70 \ 3.25, 70)
    matrix rownames M = alpha beta
    matrix colnames M = est df
    puttab using "`f6'", sheet("M") matrix(M) digits(2) title("Coefs")
    assert r(source) == "matrix"
    assert r(n_datarows) == 2
    assert r(n_cols) == 3
    import excel using "`f6'", sheet("M") clear allstring
    assert _N == 4
    assert A[1] == "Coefs"
    * header: corner blank, est, df
    assert A[2] == ""
    assert B[2] == "est"
    assert C[2] == "df"
    * rownames as label column
    assert A[3] == "alpha"
    assert A[4] == "beta"
    * per-column: est col has a fractional value -> 2 decimals
    assert B[3] == "1.50"
    assert B[4] == "3.25"
    * df column is integer-valued -> no decimals
    assert C[3] == "70"
    assert C[4] == "70"
}
if _rc == 0 {
    display as result "  PASS: matrix source per-column formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: matrix source per-column formatting (rc=`=_rc')"
    local ++fail_count
}

**## e(b)-style equation names combine as eq:name
local ++test_count
local f7 "`output_dir'/test_puttab_eqn.xlsx"
capture erase "`f7'"
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    matrix B = e(b)
    puttab using "`f7'", sheet("B") matrix(B) noheader
    import excel using "`f7'", sheet("B") clear allstring
    * single-row e(b): label column holds the (blank-eq) rowname, data are coefs
    assert _N == 1
    assert C[1] != ""
}
if _rc == 0 {
    display as result "  PASS: e(b) matrix source"
    local ++pass_count
}
else {
    display as error "  FAIL: e(b) matrix source (rc=`=_rc')"
    local ++fail_count
}

**# Multi-sheet workbook + CSV mirror
**## multiple sheets in one workbook; re-running replaces a sheet
local ++test_count
local f8 "`output_dir'/test_puttab_multi.xlsx"
local c8 "`output_dir'/test_puttab_multi.csv"
capture erase "`f8'"
capture erase "`c8'"
capture noisily {
    sysuse auto, clear
    puttab make mpg in 1/4 using "`f8'", sheet("A")
    puttab make price in 1/4 using "`f8'", sheet("B") csv("`c8'")
    assert "`r(csv)'" == "`c8'"
    confirm file "`c8'"
    * both sheets present
    import excel using "`f8'", describe
    assert r(N_worksheet) == 2
    * replace sheet A with different content
    puttab foreign using "`f8'", sheet("A")
    import excel using "`f8'", describe
    assert r(N_worksheet) == 2
    import excel using "`f8'", sheet("A") clear allstring
    assert A[1] == "foreign"
}
if _rc == 0 {
    display as result "  PASS: multi-sheet workbook + CSV mirror + sheet replace"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-sheet workbook + CSV mirror + sheet replace (rc=`=_rc')"
    local ++fail_count
}

**# Error paths
**## each error path returns the right code without leaking state
local ++test_count
local fe "`output_dir'/test_puttab_err.xlsx"
capture erase "`fe'"
capture noisily {
    sysuse auto, clear

    * no source (no varlist, no frame/matrix)
    capture puttab using "`fe'", sheet("X")
    assert _rc == 198

    * matrix + varlist
    matrix Q = (1,2)
    capture puttab mpg using "`fe'", sheet("X") matrix(Q)
    assert _rc == 198

    * matrix + if
    capture puttab if mpg>20 using "`fe'", sheet("X") matrix(Q)
    assert _rc == 198

    * bad varlist
    capture puttab nosuchvar using "`fe'", sheet("X")
    assert _rc == 111

    * empty sample
    capture puttab make if mpg>9999 using "`fe'", sheet("X")
    assert _rc == 2000

    * non-xlsx using
    capture puttab make using "`output_dir'/bad.txt", sheet("X")
    assert _rc == 198

    * missing frame
    capture frame drop nope
    capture puttab using "`fe'", sheet("X") frame(nope)
    assert _rc == 111

    * bad digits
    capture puttab make using "`fe'", sheet("X") digits(9)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: error paths return correct codes"
    local ++pass_count
}
else {
    display as error "  FAIL: error paths return correct codes (rc=`=_rc')"
    local ++fail_count
}

**# State restoration
**## varabbrev round-trips and data/sort unchanged across all sources
local ++test_count
local fs "`output_dir'/test_puttab_state.xlsx"
capture erase "`fs'"
capture noisily {
    * varabbrev ON preserved
    sysuse auto, clear
    sort price
    local sig0 = price[1] + price[_N]
    set varabbrev on
    puttab make mpg using "`fs'", sheet("on")
    assert c(varabbrev) == "on"
    * data + sort unchanged
    assert _N == 74
    assert c(k) == 12
    assert price[1] + price[_N] == `sig0'

    * varabbrev OFF preserved (incl. after a frame source)
    set varabbrev off
    capture frame drop fs1
    frame put make mpg, into(fs1)
    puttab using "`fs'", sheet("off") frame(fs1)
    assert c(varabbrev) == "off"
    assert _N == 74

    * varabbrev preserved on an error path
    set varabbrev on
    capture puttab nosuchvar using "`fs'", sheet("err")
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: state restoration (varabbrev, data, sort)"
    local ++pass_count
}
else {
    display as error "  FAIL: state restoration (varabbrev, data, sort) (rc=`=_rc')"
    local ++fail_count
}
capture frame drop fs1

**# Geometry: title/footnote/zebra/headershade applied
**## styled sheet has merged title, footnote row, and full extent
local ++test_count
local fg "`output_dir'/test_puttab_geom.xlsx"
capture erase "`fg'"
capture noisily {
    sysuse auto, clear
    puttab make mpg price in 1/6 using "`fg'", sheet("S") ///
        title("My Title") footnote("My footnote") zebra headershade theme(nejm)
    * title(1) + header(1) + data(6) + footnote(1) = 9 rows
    assert r(n_rows) == 9
    assert r(n_datarows) == 6
    import excel using "`fg'", sheet("S") clear allstring
    assert A[1] == "My Title"
    assert A[2] == "make"
    assert A[9] == "My footnote"
}
if _rc == 0 {
    display as result "  PASS: geometry title/footnote/extent"
    local ++pass_count
}
else {
    display as error "  FAIL: geometry title/footnote/extent (rc=`=_rc')"
    local ++fail_count
}

**# Dispatcher registration
**## tabtools lists puttab under the export category
local ++test_count
capture noisily {
    quietly tabtools, category(export)
    assert strpos("`r(commands)'", "puttab") > 0
    quietly tabtools
    assert strpos("`r(commands)'", "puttab") > 0
}
if _rc == 0 {
    display as result "  PASS: dispatcher registration"
    local ++pass_count
}
else {
    display as error "  FAIL: dispatcher registration (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as result "puttab QA summary: `pass_count' passed, `fail_count' failed"
display "RESULT: test_puttab tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _puttab

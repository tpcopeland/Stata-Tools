* test_desctab.do - focused QA for desctab
* Run from tabtools/qa or tabtools/qa/desctab.

clear all
version 17.0
set more off

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/desctab$") {
    local pkg_root = regexr("`_cwd'", "/qa/desctab$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_root = regexr("`_cwd'", "/qa$", "")
}
else {
    local pkg_root "`_cwd'"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_root'") replace
discard

local pass = 0
local fail = 0
local total = 0

tempname outstem
local outdir "`c(tmpdir)'/desctab_`outstem'"
capture mkdir "`outdir'"

display as text "test_desctab"

**# T1 active collect required and varabbrev restore on error
local ++total
capture noisily {
    set varabbrev on
    collect clear
    capture desctab, display
    assert _rc == 119
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: active collect required"
    local ++pass
}
else {
    display as error "  FAIL: active collect required"
    local ++fail
}

**# T2 events_n_pct literal cell
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)
    capture frame drop _dt_events
    desctab, frame(_dt_events, replace) compose(events_n_pct) pctdigits(1)
    local cell ""
    frame _dt_events {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_events
    assert "`cell'" == "3 / 30 (10.0%)"
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: events_n_pct literal cell"
    local ++pass
}
else {
    display as error "  FAIL: events_n_pct literal cell"
    local ++fail
}

**# T3 per-stat formats in wide row x column layout
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)
    capture frame drop _dt_wide
    desctab, frame(_dt_wide, replace) digits(1)
    local count_cell ""
    local mean_cell ""
    frame _dt_wide {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" {
                local count_cell = strtrim(c1[`i'])
                local mean_cell = strtrim(c2[`i'])
            }
        }
    }
    frame drop _dt_wide
    assert "`count_cell'" == "27"
    assert "`mean_cell'" == "6607.1"
}
if _rc == 0 {
    display as result "  PASS: per-stat formats"
    local ++pass
}
else {
    display as error "  FAIL: per-stat formats"
    local ++fail
}

**# T4 nformats override
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(mean price)
    capture frame drop _dt_fmt
    desctab, frame(_dt_fmt, replace) nformats("mean %9.3f")
    local cell ""
    frame _dt_fmt {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "1" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_fmt
    assert "`cell'" == "4564.500"
}
if _rc == 0 {
    display as result "  PASS: nformats override"
    local ++pass
}
else {
    display as error "  FAIL: nformats override"
    local ++fail
}

**# T5 xlsx export writes requested sheet
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)
    local xlsx "`outdir'/desctab_export.xlsx"
    desctab, xlsx("`xlsx'") sheet("Events") compose(events_n_pct) title("Events")
    confirm file "`xlsx'"
    preserve
    import excel using "`xlsx'", sheet("Events") clear allstring
    assert A[1] == "Events"
    restore
}
if _rc == 0 {
    display as result "  PASS: xlsx export"
    local ++pass
}
else {
    display as error "  FAIL: xlsx export"
    local ++fail
}

**# T6 nototals drops row and column totals
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78 foreign, statistic(count price)
    capture frame drop _dt_notot
    desctab, frame(_dt_notot, replace) nototals
    local has_total = 0
    frame _dt_notot {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "Total" local has_total = 1
            forvalues j = 1/`=c(k)-2' {
                if strtrim(c`j'[`i']) == "Total" local has_total = 1
            }
        }
    }
    frame drop _dt_notot
    assert `has_total' == 0
}
if _rc == 0 {
    display as result "  PASS: nototals"
    local ++pass
}
else {
    display as error "  FAIL: nototals"
    local ++fail
}

**# T7 statorder reorders result columns
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price) statistic(mean price)
    capture frame drop _dt_order
    desctab, frame(_dt_order, replace) statorder(mean count)
    local header = ""
    frame _dt_order {
        local header = strtrim(c1[2])
    }
    frame drop _dt_order
    assert "`header'" == "Mean"
}
if _rc == 0 {
    display as result "  PASS: statorder"
    local ++pass
}
else {
    display as error "  FAIL: statorder"
    local ++fail
}

**# T8 missing-stat compose error restores varabbrev
local ++total
capture noisily {
    set varabbrev off
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price) statistic(mean price)
    capture desctab, compose(events_n_pct)
    assert _rc == 459
    assert "`c(varabbrev)'" == "off"
}
if _rc == 0 {
    display as result "  PASS: missing-stat compose error"
    local ++pass
}
else {
    display as error "  FAIL: missing-stat compose error"
    local ++fail
}

**# T9 returned metadata and numeric r(table)
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture frame drop _dt_returns
    desctab, frame(_dt_returns, replace)
    assert "`r(version)'" == "1.2.0"
    assert "`r(rowvar)'" == "rep78"
    assert "`r(stats)'" == "count"
    assert r(N_cells) > 0
    matrix M = r(table)
    assert M[1,1] == 2
    frame drop _dt_returns
}
if _rc == 0 {
    display as result "  PASS: returned metadata"
    local ++pass
}
else {
    display as error "  FAIL: returned metadata"
    local ++fail
}

**# T10 default output is display mode
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    desctab
    assert r(N_cells) > 0
}
if _rc == 0 {
    display as result "  PASS: default display mode"
    local ++pass
}
else {
    display as error "  FAIL: default display mode"
    local ++fail
}

**# T11 csv mirror is written
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    local csv "`outdir'/desctab_export.csv"
    desctab, csv("`csv'")
    confirm file "`csv'"
}
if _rc == 0 {
    display as result "  PASS: csv export"
    local ++pass
}
else {
    display as error "  FAIL: csv export"
    local ++fail
}

**# T12 excel() synonym records xlsx return
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    local xlsx "`outdir'/desctab_excel_synonym.xlsx"
    desctab, excel("`xlsx'") sheet("Synonym")
    confirm file "`xlsx'"
    assert `"`r(xlsx)'"' == `"`xlsx'"'
    assert "`r(sheet)'" == "Synonym"
}
if _rc == 0 {
    display as result "  PASS: excel synonym"
    local ++pass
}
else {
    display as error "  FAIL: excel synonym"
    local ++fail
}

**# T13 invalid pctscale rejected
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(mean foreign)
    capture desctab, pctscale(bad)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid pctscale"
    local ++pass
}
else {
    display as error "  FAIL: invalid pctscale"
    local ++fail
}

**# T14 keep() filters displayed row levels
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture frame drop _dt_keep
    desctab, frame(_dt_keep, replace) keep(3 4)
    local has3 = 0
    local has4 = 0
    local has5 = 0
    frame _dt_keep {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local has3 = 1
            if strtrim(A[`i']) == "4" local has4 = 1
            if strtrim(A[`i']) == "5" local has5 = 1
        }
    }
    frame drop _dt_keep
    assert `has3' == 1
    assert `has4' == 1
    assert `has5' == 0
}
if _rc == 0 {
    display as result "  PASS: keep filters"
    local ++pass
}
else {
    display as error "  FAIL: keep filters"
    local ++fail
}

**# T15 drop() filters displayed row levels
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture frame drop _dt_drop
    desctab, frame(_dt_drop, replace) drop(3)
    local has3 = 0
    frame _dt_drop {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local has3 = 1
        }
    }
    frame drop _dt_drop
    assert `has3' == 0
}
if _rc == 0 {
    display as result "  PASS: drop filters"
    local ++pass
}
else {
    display as error "  FAIL: drop filters"
    local ++fail
}

**# T16 statlabels override statistic headers
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price) statistic(mean price)
    capture frame drop _dt_labels
    desctab, frame(_dt_labels, replace) statlabels("count=N \ mean=Average")
    frame _dt_labels {
        assert strtrim(c1[2]) == "N"
        assert strtrim(c2[2]) == "Average"
    }
    frame drop _dt_labels
}
if _rc == 0 {
    display as result "  PASS: statlabels"
    local ++pass
}
else {
    display as error "  FAIL: statlabels"
    local ++fail
}

**# T17 custom compose template
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(sum foreign) statistic(count foreign)
    capture frame drop _dt_custom
    desctab, frame(_dt_custom, replace) compose("{total}/{count}")
    local cell ""
    frame _dt_custom {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_custom
    assert "`cell'" == "3/30"
}
if _rc == 0 {
    display as result "  PASS: custom compose"
    local ++pass
}
else {
    display as error "  FAIL: custom compose"
    local ++fail
}

**# T18 n_pct preset with binary mean
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count foreign) statistic(mean foreign)
    capture frame drop _dt_npct
    desctab, frame(_dt_npct, replace) compose(n_pct) pctdigits(1)
    local cell ""
    frame _dt_npct {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_npct
    assert "`cell'" == "30 (10.0%)"
}
if _rc == 0 {
    display as result "  PASS: n_pct compose"
    local ++pass
}
else {
    display as error "  FAIL: n_pct compose"
    local ++fail
}

**# T19 mean_sd does not percent-scale continuous means
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table (var) (foreign), statistic(mean mpg weight) statistic(sd mpg weight)
    capture frame drop _dt_meansd
    desctab, frame(_dt_meansd, replace) compose(mean_sd) digits(1)
    local cell ""
    frame _dt_meansd {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "Mileage (mpg)" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_meansd
    assert "`cell'" == "19.8 (4.7)"
}
if _rc == 0 {
    display as result "  PASS: mean_sd compose"
    local ++pass
}
else {
    display as error "  FAIL: mean_sd compose"
    local ++fail
}

**# T20 median_range preset
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(p50 price) statistic(min price) statistic(max price)
    capture frame drop _dt_range
    desctab, frame(_dt_range, replace) compose(median_range) digits(0)
    local cell ""
    frame _dt_range {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "Domestic" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_range
    assert strpos("`cell'", "(") > 0
    assert strpos("`cell'", "-") > 0
}
if _rc == 0 {
    display as result "  PASS: median_range compose"
    local ++pass
}
else {
    display as error "  FAIL: median_range compose"
    local ++fail
}

**# T21 median_iqr preset
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(p25 price) statistic(p50 price) statistic(p75 price)
    capture frame drop _dt_iqr
    desctab, frame(_dt_iqr, replace) compose(median_iqr) digits(0)
    local cell ""
    frame _dt_iqr {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "Domestic" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_iqr
    assert strpos("`cell'", "(") > 0
    assert strpos("`cell'", "-") > 0
}
if _rc == 0 {
    display as result "  PASS: median_iqr compose"
    local ++pass
}
else {
    display as error "  FAIL: median_iqr compose"
    local ++fail
}

**# T22 mean_ci preset derives an interval
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(mean price) statistic(sd price) statistic(count price)
    capture frame drop _dt_ci
    desctab, frame(_dt_ci, replace) compose(mean_ci) digits(1)
    local cell ""
    frame _dt_ci {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "Domestic" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_ci
    assert strpos("`cell'", "(") > 0
    assert strpos("`cell'", "-") > 0
}
if _rc == 0 {
    display as result "  PASS: mean_ci compose"
    local ++pass
}
else {
    display as error "  FAIL: mean_ci compose"
    local ++fail
}

**# T23 events_n preset
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(sum foreign) statistic(count foreign)
    capture frame drop _dt_events_n
    desctab, frame(_dt_events_n, replace) compose(events_n)
    local cell ""
    frame _dt_events_n {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_events_n
    assert "`cell'" == "3 / 30"
}
if _rc == 0 {
    display as result "  PASS: events_n compose"
    local ++pass
}
else {
    display as error "  FAIL: events_n compose"
    local ++fail
}

**# T24 continuous sum keeps decimals
local ++total
capture noisily {
    sysuse auto, clear
    gen cont = price / 100
    collect clear
    collect: table rep78, statistic(sum cont)
    capture frame drop _dt_cont_sum
    desctab, frame(_dt_cont_sum, replace) digits(2)
    local cell ""
    frame _dt_cont_sum {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "1" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_cont_sum
    assert "`cell'" == "91.29"
}
if _rc == 0 {
    display as result "  PASS: continuous sum format"
    local ++pass
}
else {
    display as error "  FAIL: continuous sum format"
    local ++fail
}

**# T25 integer-valued sum uses integer format
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(sum price)
    capture frame drop _dt_int_sum
    desctab, frame(_dt_int_sum, replace) digits(2)
    local cell ""
    frame _dt_int_sum {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "1" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_int_sum
    assert "`cell'" == "9,129"
}
if _rc == 0 {
    display as result "  PASS: integer sum format"
    local ++pass
}
else {
    display as error "  FAIL: integer sum format"
    local ++fail
}

**# T26 pctscale(0to100) applies to binary mean without compose
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(mean foreign)
    capture frame drop _dt_pctscale
    desctab, frame(_dt_pctscale, replace) pctscale(0to100) pctsign pctdigits(1)
    local cell ""
    frame _dt_pctscale {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_pctscale
    assert "`cell'" == "10.0%"
}
if _rc == 0 {
    display as result "  PASS: pctscale binary mean"
    local ++pass
}
else {
    display as error "  FAIL: pctscale binary mean"
    local ++fail
}

**# T27 native-scale binary mean remains decimal by default
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(mean foreign)
    capture frame drop _dt_native_mean
    desctab, frame(_dt_native_mean, replace) digits(2)
    local cell ""
    frame _dt_native_mean {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local cell = strtrim(c1[`i'])
        }
    }
    frame drop _dt_native_mean
    assert "`cell'" == "0.10"
}
if _rc == 0 {
    display as result "  PASS: native-scale mean"
    local ++pass
}
else {
    display as error "  FAIL: native-scale mean"
    local ++fail
}

**# T28 invalid xlsx extension rejected
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture desctab, xlsx("`outdir'/bad.xls")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid xlsx extension"
    local ++pass
}
else {
    display as error "  FAIL: invalid xlsx extension"
    local ++fail
}

**# T29 open requires xlsx/excel
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture desctab, open
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: open requires xlsx"
    local ++pass
}
else {
    display as error "  FAIL: open requires xlsx"
    local ++fail
}

**# T30 keep() and drop() cannot be combined
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(count price)
    capture desctab, keep(3) drop(4)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: keep/drop conflict"
    local ++pass
}
else {
    display as error "  FAIL: keep/drop conflict"
    local ++fail
}

**# T31 frame without replace protects existing frame
local ++total
capture noisily {
    sysuse auto, clear
    capture frame drop _dt_exists
    frame create _dt_exists
    collect clear
    collect: table rep78, statistic(count price)
    capture desctab, frame(_dt_exists)
    local rc = _rc
    frame drop _dt_exists
    assert `rc' == 110
}
if _rc == 0 {
    display as result "  PASS: frame replace guard"
    local ++pass
}
else {
    display as error "  FAIL: frame replace guard"
    local ++fail
}

**# T32 frame replace overwrites existing frame
local ++total
capture noisily {
    sysuse auto, clear
    capture frame drop _dt_replace
    frame create _dt_replace
    collect clear
    collect: table rep78, statistic(count price)
    desctab, frame(_dt_replace, replace)
    frame _dt_replace {
        assert _N > 0
    }
    frame drop _dt_replace
}
if _rc == 0 {
    display as result "  PASS: frame replace"
    local ++pass
}
else {
    display as error "  FAIL: frame replace"
    local ++fail
}

**# T33 repeated calls on the same collect are stable
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)
    capture frame drop _dt_first
    capture frame drop _dt_second
    desctab, frame(_dt_first, replace) compose(events_n_pct)
    desctab, frame(_dt_second, replace) compose(events_n_pct)
    local first ""
    local second ""
    frame _dt_first {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local first = strtrim(c1[`i'])
        }
    }
    frame _dt_second {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "3" local second = strtrim(c1[`i'])
        }
    }
    frame drop _dt_first
    frame drop _dt_second
    assert "`first'" == "`second'"
}
if _rc == 0 {
    display as result "  PASS: repeated calls"
    local ++pass
}
else {
    display as error "  FAIL: repeated calls"
    local ++fail
}

**# T34 nototals coltotals keeps column totals
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78 foreign, statistic(count price)
    capture frame drop _dt_coltot
    desctab, frame(_dt_coltot, replace) nototals coltotals
    frame _dt_coltot {
        assert strtrim(c3[3]) == "Total"
    }
    frame drop _dt_coltot
}
if _rc == 0 {
    display as result "  PASS: coltotals override"
    local ++pass
}
else {
    display as error "  FAIL: coltotals override"
    local ++fail
}

**# T35 nototals rowtotals keeps row totals
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78 foreign, statistic(count price)
    capture frame drop _dt_rowtot
    desctab, frame(_dt_rowtot, replace) nototals rowtotals
    local has_total = 0
    frame _dt_rowtot {
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "Total" local has_total = 1
        }
    }
    frame drop _dt_rowtot
    assert `has_total' == 1
}
if _rc == 0 {
    display as result "  PASS: rowtotals override"
    local ++pass
}
else {
    display as error "  FAIL: rowtotals override"
    local ++fail
}

**# T36 Excel row-label column width is content-driven
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(count price)
    local xlsx "`outdir'/desctab_width.xlsx"
    tempfile sheetxml
    desctab, xlsx("`xlsx'") sheet("Width") title("Width")
    shell unzip -p "`xlsx'" xl/worksheets/sheet1.xml > "`sheetxml'"
    file open _xfh using "`sheetxml'", read text
    file read _xfh line
    local xml ""
    while r(eof) == 0 {
        local xml `"`xml'`line'"'
        file read _xfh line
    }
    file close _xfh
    local q = char(34)
    local pat "<col min=`q'2`q' max=`q'2`q' width=`q'([0-9.]+)"
    assert regexm(`"`xml'"', `"`pat'"')
    local bwidth = real(regexs(1))
    assert `bwidth' < 18
}
if _rc == 0 {
    display as result "  PASS: content-driven label column width"
    local ++pass
}
else {
    display as error "  FAIL: content-driven label column width"
    local ++fail
}

**# T37 Theme alone does not imply shaded fills
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(count price)
    local xlsx "`outdir'/desctab_no_shade.xlsx"
    tempfile stylesxml
    desctab, xlsx("`xlsx'") sheet("NoShade") title("No Shade") theme(lancet)
    shell unzip -p "`xlsx'" xl/styles.xml > "`stylesxml'"
    file open _sfh using "`stylesxml'", read text
    file read _sfh line
    local styles ""
    while r(eof) == 0 {
        local styles `"`styles'`line'"'
        file read _sfh line
    }
    file close _sfh
    local q = char(34)
    local pat "<fills count=`q'([0-9]+)`q'"
    assert regexm(`"`styles'"', `"`pat'"')
    local fillcount = real(regexs(1))
    assert `fillcount' == 2
}
if _rc == 0 {
    display as result "  PASS: theme alone leaves shading off"
    local ++pass
}
else {
    display as error "  FAIL: theme alone leaves shading off"
    local ++fail
}

**# T38 Row x column x statistic headers are merged and compact
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)
    local xlsx "`outdir'/desctab_merged_headers.xlsx"
    tempfile sheetxml sharedxml
    desctab, xlsx("`xlsx'") sheet("Merged") ///
        title("Merged Headers") statorder(count mean sd) ///
        statlabels("count=N \ mean=Mean \ sd=SD") ///
        nformats("count %8.0fc mean %8.1f sd %8.1f")
    preserve
    import excel using "`xlsx'", sheet("Merged") clear allstring
    assert A[1] == "Merged Headers"
    assert strtrim(B[2]) == "Repair record 1978"
    assert strtrim(C[2]) == "Domestic"
    assert strtrim(D[2]) == ""
    assert strtrim(E[2]) == ""
    assert strtrim(F[2]) == "Foreign"
    assert strtrim(I[2]) == "Total"
    assert strtrim(B[3]) == ""
    assert strtrim(C[3]) == "N"
    assert strtrim(D[3]) == "Mean"
    assert strtrim(E[3]) == "SD"
    assert strtrim(B[4]) == "1"
    restore
    shell unzip -p "`xlsx'" xl/worksheets/sheet1.xml > "`sheetxml'"
    file open _mfh using "`sheetxml'", read text
    file read _mfh line
    local xml ""
    while r(eof) == 0 {
        local xml `"`xml'`line'"'
        file read _mfh line
    }
    file close _mfh
    assert strpos(`"`xml'"', "B2:B3") > 0
    assert strpos(`"`xml'"', "C2:E2") > 0
    assert strpos(`"`xml'"', "F2:H2") > 0
    assert strpos(`"`xml'"', "I2:K2") > 0
    shell unzip -p "`xlsx'" xl/sharedStrings.xml > "`sharedxml'"
    file open _ssh using "`sharedxml'", read text
    file read _ssh line
    local shared ""
    while r(eof) == 0 {
        local shared `"`shared'`line'"'
        file read _ssh line
    }
    file close _ssh
    assert strpos(`"`shared'"', "Car origin") == 0
}
if _rc == 0 {
    display as result "  PASS: merged row-column-stat headers"
    local ++pass
}
else {
    display as error "  FAIL: merged row-column-stat headers"
    local ++fail
}

display as result "Results: `pass'/`total' passed, `fail' failed"
if `fail' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_desctab tests=`total' pass=`pass' fail=`fail'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_desctab tests=`total' pass=`pass' fail=`fail'"

/*  desctab_demo.do - Demo output for desctab

    Produces:
      1. demo_desctab.xlsx, sheet Events         - events / N (%) composite cells
      2. demo_desctab.xlsx, sheet Styled Events  - explicit opt-in shaded styling
      3. demo_desctab.xlsx, sheet Mean SD        - mean (SD) composite cells
      4. demo_desctab.xlsx, sheet Median IQR     - median (IQR) composite cells
      5. demo_desctab.xlsx, sheet Separate Stats - per-statistic columns and labels
      6. demo_desctab.xlsx, sheet Custom         - custom compose() template
*/

version 17.0
local _orig_more = c(more)
local _orig_varabbrev = c(varabbrev)
local _orig_linesize = c(linesize)
local _orig_plus "`c(sysdir_plus)'"
local _orig_personal "`c(sysdir_personal)'"
tempname _demo_id
local _demo_tag = subinstr("`_demo_id'", "__", "", .)
local _demo_plus "`c(tmpdir)'/desctab_demo_plus_`_demo_tag'"
local _demo_personal "`c(tmpdir)'/desctab_demo_personal_`_demo_tag'"
local _demo_isolated 0
local _demo_success ""

capture noisily {
    clear all
    set more off
    set varabbrev off
    set linesize 120

    **# Paths
    local cwd "`c(pwd)'"
    capture confirm file "`cwd'/tabtools.pkg"
    if _rc == 0 {
        local pkg_root "`cwd'"
        local demo_dir "`pkg_root'/demo"
    }
    else {
        capture confirm file "`cwd'/tabtools/tabtools.pkg"
        if _rc == 0 {
            local pkg_root "`cwd'/tabtools"
            local demo_dir "`pkg_root'/demo"
        }
        else {
            local pkg_root = regexr("`cwd'", "/demo$", "")
            capture confirm file "`pkg_root'/tabtools.pkg"
            if _rc {
                display as error "Run desctab_demo.do from Stata-Tools, tabtools, or tabtools/demo"
                exit 601
            }
            local demo_dir "`cwd'"
        }
    }
    capture mkdir "`demo_dir'"
    local xlsx "`demo_dir'/demo_desctab.xlsx"
    capture erase "`xlsx'"

    **# Isolated install
    capture mkdir "`_demo_plus'"
    capture mkdir "`_demo_personal'"
    sysdir set PLUS "`_demo_plus'"
    sysdir set PERSONAL "`_demo_personal'"
    discard
    local _demo_isolated 1
    capture ado uninstall tabtools
    quietly net install tabtools, from("`pkg_root'") replace
    discard

    **# Events / N (%) default styling
    sysuse auto, clear
    collect clear
    collect: table rep78, ///
        statistic(sum foreign) statistic(count foreign) statistic(mean foreign)
    desctab, xlsx("`xlsx'") sheet("Events") ///
        title("Foreign cars by repair record") compose(events_n_pct) ///
        pctdigits(1)

    **# Events / N (%) with explicit shading
    desctab, xlsx("`xlsx'") sheet("Styled Events") ///
        title("Foreign cars by repair record") compose(events_n_pct) ///
        pctdigits(1) headershade zebra

    **# Mean (SD)
    collect clear
    collect: table (var) (foreign), ///
        statistic(mean mpg weight) statistic(sd mpg weight)
    desctab, xlsx("`xlsx'") sheet("Mean SD") ///
        title("Vehicle characteristics by origin") compose(mean_sd) ///
        digits(1)

    **# Median (IQR)
    collect clear
    collect: table foreign, ///
        statistic(p25 price) statistic(p50 price) statistic(p75 price)
    desctab, xlsx("`xlsx'") sheet("Median IQR") ///
        title("Vehicle price by origin") compose(median_iqr) ///
        digits(0)

    **# Separate statistic columns
    collect clear
    collect: table rep78 foreign, ///
        statistic(count price) statistic(mean price) statistic(sd price)
    desctab, xlsx("`xlsx'") sheet("Separate Stats") ///
        title("Price statistics by repair record and origin") ///
        statorder(count mean sd) ///
        statlabels("count=N \ mean=Mean \ sd=SD") ///
        nformats("count %8.0fc mean %8.0fc sd %8.0fc")

    **# Custom compose() template
    collect clear
    collect: table rep78, ///
        statistic(sum foreign) statistic(count foreign) statistic(mean foreign)
    desctab, xlsx("`xlsx'") sheet("Custom") ///
        title("Custom composition template") ///
        compose("{total} of {count} ({mean})") pctscale(0to100) pctsign ///
        pctdigits(1)

    **# Verify workbook content
    preserve
    import excel using "`xlsx'", sheet("Events") clear allstring
    assert A[1] == "Foreign cars by repair record"
    restore

    preserve
    import excel using "`xlsx'", sheet("Mean SD") clear allstring
    assert A[1] == "Vehicle characteristics by origin"
    restore

    preserve
    import excel using "`xlsx'", sheet("Median IQR") clear allstring
    assert A[1] == "Vehicle price by origin"
    restore

    preserve
    import excel using "`xlsx'", sheet("Separate Stats") clear allstring
    assert A[1] == "Price statistics by repair record and origin"
    assert B[2] == "Repair record 1978"
    assert C[2] == "Domestic"
    assert D[2] == ""
    assert E[2] == ""
    assert F[2] == "Foreign"
    assert I[2] == "Total"
    assert B[3] == ""
    assert C[3] == "N"
    assert D[3] == "Mean"
    assert E[3] == "SD"
    assert strtrim(B[4]) == "1"
    restore

    preserve
    import excel using "`xlsx'", sheet("Custom") clear allstring
    assert A[1] == "Custom composition template"
    restore

    display as result "desctab demo complete: `xlsx'"
    local _demo_success "1"
}
local _rc = _rc
if "`_demo_success'" == "1" local _rc = 0
set linesize `_orig_linesize'
set varabbrev `_orig_varabbrev'
set more `_orig_more'
if `_demo_isolated' {
    capture ado uninstall tabtools
    sysdir set PLUS "`_orig_plus'"
    sysdir set PERSONAL "`_orig_personal'"
    discard
    capture shell rm -rf "`_demo_plus'" "`_demo_personal'"
}
if `_rc' exit `_rc'

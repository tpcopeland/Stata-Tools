version 16.0

* Shared QA scaffold for codescan.
*
* This package tracks no .dta input fixtures: every suite builds its own
* synthetic data inline (input blocks or seeded generators) and writes any
* transient artifact to the qa/ root, where .gitignore keeps it untracked.
*
* _codescan_qa_bootstrap sandboxes the install so the suite never touches the
* developer's real PLUS/PERSONAL adopath, then installs the local package copy
* (not a shadowing SSC/GitHub build higher in the adopath). run_all.do calls it
* once; the per-suite `net install codescan, replace` calls inside each test file
* then refresh into the same sandboxed PLUS, so running a file standalone still
* works against the local source.

capture program drop _codescan_qa_bootstrap
program define _codescan_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local _qa_len = strlen("`qa_dir'")
    local pkg_dir = substr("`qa_dir'", 1, `_qa_len' - 3)
    local _pkg_len = strlen("`pkg_dir'")
    local repo_dir = substr("`pkg_dir'", 1, `_pkg_len' - 9)

    if "$CODESCAN_QA_ISOLATED" == "" {
        tempfile _codescan_qa_base
        local plus_dir "`_codescan_qa_base'_plus"
        local personal_dir "`_codescan_qa_base'_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global CODESCAN_QA_PLUS "`plus_dir'"
        global CODESCAN_QA_PERSONAL "`personal_dir'"
        global CODESCAN_QA_ISOLATED "1"
    }

    sysdir set PLUS "$CODESCAN_QA_PLUS"
    sysdir set PERSONAL "$CODESCAN_QA_PERSONAL"

    capture ado uninstall codescan
    quietly net install codescan, from("`pkg_dir'") replace
    discard

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
    return local repo_dir "`repo_dir'"
end


* ============================================================
* Helper: Create standard test dataset
* ============================================================

capture program drop _make_test_data
program define _make_test_data
    clear
    set obs 20
    gen long pid = ceil(_n / 4)

    * 5 patients, 4 rows each
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""
    gen double visit_dt = .
    gen double index_dt = .
    format visit_dt index_dt %td

    * Patient 1: DM2 + obesity, visits around index
    replace dx1 = "E110" if _n == 1
    replace dx2 = "E660" if _n == 1
    replace dx1 = "I10"  if _n == 2
    replace dx1 = "E119" if _n == 3
    replace dx1 = "J45"  if _n == 4

    * Patient 2: HTN only
    replace dx1 = "I10"  if _n == 5
    replace dx1 = "I13"  if _n == 6
    replace dx1 = "J45"  if _n == 7
    replace dx1 = "K21"  if _n == 8

    * Patient 3: CVD + DM2
    replace dx1 = "I21"  if _n == 9
    replace dx2 = "I25"  if _n == 10
    replace dx1 = "E110" if _n == 11
    replace dx1 = "Z00"  if _n == 12

    * Patient 4: depression + DM2
    replace dx1 = "F32"  if _n == 13
    replace dx2 = "E111" if _n == 14
    replace dx1 = "F33"  if _n == 15
    replace dx1 = "Z00"  if _n == 16

    * Patient 5: no matches
    replace dx1 = "Z00"  if _n == 17
    replace dx1 = "Z01"  if _n == 18
    replace dx1 = "Z02"  if _n == 19
    replace dx1 = "Z03"  if _n == 20

    * Dates: index = 2020-01-01 for all
    replace index_dt = mdy(1, 1, 2020)

    * Visits spread around index
    replace visit_dt = mdy(6, 15, 2019) if mod(_n - 1, 4) == 0
    replace visit_dt = mdy(12, 1, 2019) if mod(_n - 1, 4) == 1
    replace visit_dt = mdy(1, 1, 2020)  if mod(_n - 1, 4) == 2
    replace visit_dt = mdy(6, 15, 2020) if mod(_n - 1, 4) == 3
end

* validation_codescan_output.do - Known-answer validation for codescan export and graph outputs
* Date: 2026-04-23

clear all
set seed 97531
version 16.0
set varabbrev off

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local tools_dir "`qa_dir'/tools"

* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


capture program drop _read_check_status
program define _read_check_status, rclass
    version 16.0
    args status_file

    local status "FAIL"
    capture confirm file "`status_file'"
    if _rc == 0 {
        tempname fh
        file open `fh' using "`status_file'", read text
        file read `fh' status
        file close `fh'
    }

    return local status "`status'"
end

capture shell python3 -c "import openpyxl"
if _rc {
    display as error "python3 with openpyxl is required for validation_codescan_output.do"
    exit 499
}

* ============================================================
* V1: XLSX export exact workbook contents and formatting
* ============================================================

local ++test_count
capture noisily {
    tempfile out_base status_base
    local out_xlsx "`out_base'.xlsx"
    local status_txt "`status_base'.txt"

    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" ""
    "E110" "J45"
    "I10"  ""
    end

    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | asthma "J45") ///
        cooccurrence export("`out_xlsx'")

    confirm file "`out_xlsx'"

    shell python3 "`tools_dir'/check_codescan_artifacts.py" ///
        xlsx "`out_xlsx'" "`status_txt'"

    quietly _read_check_status "`status_txt'"
    assert "`r(status)'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: V1 - XLSX export exact workbook validation"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 - XLSX export exact workbook validation (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V2: Graph output exact SVG text and order
* ============================================================

local ++test_count
capture noisily {
    tempfile graph_base status_base
    local out_svg "`graph_base'.svg"
    local status_txt "`status_base'.txt"

    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" ""
    "E110" "J45"
    "I10"  ""
    end

    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | asthma "J45") graph

    graph describe Graph
    assert "`r(fn)'" == "Graph"
    assert "`r(family)'" == "bar"
    assert strpos(`"`r(command)'"', "hbar prevalence") > 0
    assert strpos(`"`r(command)'"', "Condition Prevalence") > 0
    assert strpos(`"`r(command)'"', "Prevalence (%)") > 0
    assert strpos(`"`r(command)'"', "blabel(bar, format(%4.1f))") > 0

    graph export "`out_svg'", as(svg) replace
    confirm file "`out_svg'"

    shell python3 "`tools_dir'/check_codescan_artifacts.py" ///
        svg "`out_svg'" "`status_txt'"

    quietly _read_check_status "`status_txt'"
    assert "`r(status)'" == "PASS"

    graph close _all
}
if _rc == 0 {
    display as result "  PASS: V2 - Graph exact SVG validation"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 - Graph exact SVG validation (error `=_rc')"
    local ++fail_count
    capture graph close _all
}

* ============================================================
* V3: Failed export restores post-scan data and keeps r()
* ============================================================

local ++test_count
capture noisily {
    tempfile expected badbase
    local bad_xlsx "`badbase'_missing_dir/out.xlsx"

    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" ""
    "E110" "J45"
    "I10"  ""
    end

    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | asthma "J45")
    matrix expected_summary = r(summary)
    local expected_N = r(N)
    local expected_conditions "`r(conditions)'"
    save "`expected'", replace

    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" ""
    "E110" "J45"
    "I10"  ""
    end

    capture codescan dx1 dx2, define(dm2 "E11" | htn "I10" | asthma "J45") ///
        export("`bad_xlsx'")
    local export_rc = _rc
    assert `export_rc' != 0

    local got_N = r(N)
    local got_conditions "`r(conditions)'"
    matrix got_summary = r(summary)
    assert `got_N' == `expected_N'
    assert "`got_conditions'" == "`expected_conditions'"
    assert el(got_summary, 1, 1) == el(expected_summary, 1, 1)
    assert el(got_summary, 2, 1) == el(expected_summary, 2, 1)
    assert el(got_summary, 3, 1) == el(expected_summary, 3, 1)

    cf _all using "`expected'"
}
if _rc == 0 {
    display as result "  PASS: V3 - unwritable export restores data and keeps r()"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 - failed export restore/return contract (error `=_rc')"
    local ++fail_count
}

* ============================================================
* V4: Non-default format() reaches the exported workbook
* ============================================================
* format() is documented as the display AND export format. `export excel'
* propagates the variable's display format, so a non-default format(%9.2f) must
* land on the prevalence/CI cells as Excel format "0.00" while the integer
* match count stays "0". Without this, V1 only ever exercises the default and a
* regression that dropped format() on the export path would stay green.

local ++test_count
capture noisily {
    tempfile out_base status_base
    local out_xlsx "`out_base'.xlsx"
    local status_txt "`status_base'.txt"

    clear
    input str10 dx1 str10 dx2
    "E110" "I10"
    "E110" ""
    "E110" "J45"
    "I10"  ""
    end

    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | asthma "J45") ///
        cooccurrence export("`out_xlsx'", replace) format(%9.2f)

    confirm file "`out_xlsx'"

    shell python3 "`tools_dir'/check_codescan_artifacts.py" ///
        xlsx "`out_xlsx'" "`status_txt'" --number-format "0.00"

    quietly _read_check_status "`status_txt'"
    assert "`r(status)'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: V4 - format(%9.2f) reaches exported XLSX cell format"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 - format(%9.2f) reaches exported XLSX cell format (error `=_rc')"
    local ++fail_count
}

display ""

**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


_codescan_qa_publish "validation_codescan_output" `test_count' `pass_count' `fail_count'
display as result "RESULT: validation_codescan_output tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}

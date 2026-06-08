* test_simtab_styling.do - Regression QA for simtab xlsx styling (v1.6.1)
*
* Locks in the styling fix that aligned simtab's Excel output with regtab's
* conventions:
*   1. Table is offset to B2 - column A is a narrow spacer, the title sits in
*      A1, and all table content (headers, body) starts at column B. The box
*      top-left corner is B2, so the left border is visible (not hard against
*      the sheet edge).
*   2. No header background fill by DEFAULT (headershade is opt-in). The
*      headershade option still applies a fill when explicitly requested.
*   3. Vertical separators: right border after the scenario column, after the
*      estimator column, and between estimand section groups.
*   4. A full box border (top/bottom/left/right) around the table.
*   5. A horizontal rule under the estimand group-header row.
*
* borderstyle(academic) maps to medium border weight, so the box and separator
* rules are asserted as "medium"; the scenario group separator is "thin".

clear all
set more off
set varabbrev off

capture log close _simtab_style
log using "test_simtab_styling.log", replace text name(_simtab_style)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
local tools_dir "`qa_dir'/tools"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

* require the xlsx checker - styling assertions depend on it
capture confirm file "`tools_dir'/check_xlsx.py"
if _rc {
    display as error "check_xlsx.py not found in `tools_dir'; cannot validate styling"
    exit 601
}
local checker "`tools_dir'/check_xlsx.py"

local test_count = 0
local pass_count = 0
local fail_count = 0

* ---- deterministic long sim dataset with labelled grouping vars ----
program drop _all
program define _simtab_style_data
    syntax , [Reps(integer 60) Estimands(integer 2)]
    clear
    local cells = `reps' * 2 * 3 * `estimands'
    set obs `cells'
    set seed 20260608
    gen long sim = mod(_n-1, `reps') + 1
    gen byte sc = mod(floor((_n-1)/(`reps'*3)), 2) + 1
    gen byte estid = mod(floor((_n-1)/`reps'), 3) + 1
    gen byte emd = floor((_n-1)/(`reps'*3*2)) + 1
    label define sclbl 1 "A" 2 "B", replace
    label values sc sclbl
    label define estlbl 1 "Unweighted" 2 "IIW" 3 "IIW+log", replace
    label values estid estlbl
    label define emdlbl 1 "Marginal" 2 "Contrast", replace
    label values emd emdlbl
    label variable sc "Scenario"
    label variable estid "Estimator"
    gen double truev = cond(emd==1, 0.10, 0.50)
    gen double est = truev + rnormal(0, 0.04)
    gen double se = 0.04 + runiform()*0.004
end

* helper: run check_xlsx.py and assert PASS via the result file
capture program drop _xl_pass
program define _xl_pass
    args result_file
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

* =====================================================================
**# T1: multi-estimand (by + 2 estimands) - B2 offset, box, separators
* =====================================================================
* Layout (title + by + 2 estimands + 5 metrics):
*   col A = spacer, B = scenario, C = estimator, D-H = marginal, I-M = contrast
*   row 1 = title, 2 = group header, 3 = metric header, 4-9 = data, 10 = footnote
local x1 "`output_dir'/_style_multi.xlsx"
local r1 "`output_dir'/_style_r1.txt"
local ++test_count
capture noisily {
    _simtab_style_data, reps(60) estimands(2)
    capture erase "`x1'"
    simtab estid, estimate(est) se(se) true(truev) by(sc) estimand(emd) sim(sim) ///
        metrics(mean bias empse coverage n) digits(3) ///
        title("Styling Regression") ///
        footnote("Regression fixture for the B2-offset styling fix.") ///
        borderstyle(academic) ///
        xlsx("`x1'") sheet("Tab")

    shell python3 "`checker'" "`x1'" --sheet "Tab" ///
        --cell A1 "Styling Regression" ///
        --cell B3 "Scenario" --cell C3 "Estimator" ///
        --cell D2 "Marginal" --cell I2 "Contrast" ///
        --cell-border B2 left medium ///
        --cell-border M2 right medium ///
        --cell-border D2 top medium ///
        --cell-border B9 bottom medium ///
        --cell-border M9 bottom medium ///
        --cell-border D2 bottom medium ///
        --cell-border D3 bottom medium ///
        --cell-border B4 right medium ///
        --cell-border C4 right medium ///
        --cell-border H4 right medium ///
        --cell-border B7 top thin ///
        --cell-no-fill B3 C3 D2 D3 I2 ///
        --result-file "`r1'" --quiet
    _xl_pass "`r1'"
}
if _rc == 0 {
    display as result "  PASS: T1 multi-estimand B2 offset + box + separators + no fill"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 (rc=`=_rc')"
    local ++fail_count
}
capture erase "`r1'"

* =====================================================================
**# T2: single estimand (no by) - B2 offset, three-line box, no group row
* =====================================================================
* Layout (title + no by + 1 estimand + 5 metrics):
*   col A = spacer, B = estimator, C-G = metrics
*   row 1 = title, 2 = metric header, 3-5 = data, 6 = footnote
local x2 "`output_dir'/_style_single.xlsx"
local r2 "`output_dir'/_style_r2.txt"
local ++test_count
capture noisily {
    _simtab_style_data, reps(60) estimands(1)
    keep if sc == 1
    capture erase "`x2'"
    simtab estid, estimate(est) se(se) true(truev) sim(sim) ///
        metrics(mean bias empse coverage n) digits(3) ///
        title("Single Estimand") ///
        borderstyle(academic) ///
        xlsx("`x2'") sheet("Tab")

    shell python3 "`checker'" "`x2'" --sheet "Tab" ///
        --cell A1 "Single Estimand" ///
        --cell B2 "Estimator" ///
        --cell-border B2 left medium ///
        --cell-border G2 right medium ///
        --cell-border B2 top medium ///
        --cell-border B5 bottom medium ///
        --cell-border B2 right medium ///
        --cell-no-fill B2 C2 ///
        --result-file "`r2'" --quiet
    _xl_pass "`r2'"
}
if _rc == 0 {
    display as result "  PASS: T2 single-estimand B2 offset + three-line box"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 (rc=`=_rc')"
    local ++fail_count
}
capture erase "`r2'"

* =====================================================================
**# T3: headershade is opt-in - explicit headershade still fills header
* =====================================================================
* Confirms the default-no-fill change did not break the headershade option.
local x3 "`output_dir'/_style_shade.xlsx"
local r3 "`output_dir'/_style_r3.txt"
local ++test_count
capture noisily {
    _simtab_style_data, reps(60) estimands(2)
    capture erase "`x3'"
    simtab estid, estimate(est) se(se) true(truev) by(sc) estimand(emd) sim(sim) ///
        metrics(mean bias empse coverage n) digits(3) ///
        title("Shaded Header") ///
        borderstyle(academic) headershade ///
        xlsx("`x3'") sheet("Tab")

    * with headershade, the metric-header row (row 3) carries a solid fill,
    * and the B2 offset / left border are still present
    shell python3 "`checker'" "`x3'" --sheet "Tab" ///
        --cell A1 "Shaded Header" ///
        --cell-border B2 left medium ///
        --has-fill 3 ///
        --result-file "`r3'" --quiet
    _xl_pass "`r3'"
}
if _rc == 0 {
    display as result "  PASS: T3 headershade opt-in still applies header fill"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 (rc=`=_rc')"
    local ++fail_count
}
capture erase "`r3'"

* =====================================================================
**# Summary
* =====================================================================
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_simtab_styling tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_simtab_styling tests=`test_count' pass=`pass_count' fail=`fail_count'"

capture log close _simtab_style

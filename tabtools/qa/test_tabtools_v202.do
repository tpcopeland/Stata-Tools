*! test_tabtools_v202.do - Regression tests for tabtools 2.0.2
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set processors 1
set varabbrev off
version 17.0

capture log close _all
log using "test_tabtools_v202.log", replace text name(_v202)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

**# R1. Public Excel exports preserve caller-owned Mata objects
local ++test_count
local puttab_book "`output_dir'/v202_mata_state.xlsx"
capture erase "`puttab_book'"
capture mata: mata drop b
capture noisily {
    mata: b = 1729
    sysuse auto, clear
    puttab make mpg in 1/3 using "`puttab_book'", sheet("State")
    tempname b_after
    mata: st_numscalar("`b_after'", b)
    assert scalar(`b_after') == 1729
}
local mata_b_rc = _rc
capture mata: mata drop b
if `mata_b_rc' == 0 {
    display as result "  PASS R1: Excel export preserves caller Mata object b"
    local ++pass_count
}
else {
    display as error "  FAIL R1: Excel export clobbered caller Mata object b (rc=`mata_b_rc')"
    local ++fail_count
}

**# R2. desctab preserves caller objects matching its former scratch names
local ++test_count
capture mata: mata drop _p_raw_save
capture mata: mata drop _smd_raw_save
capture noisily {
    mata: _p_raw_save = 101
    mata: _smd_raw_save = 202
    sysuse auto, clear
    desctab price mpg, by(foreign) smd test
    confirm matrix r(table)
    assert rowsof(r(table)) > 0
    tempname p_after smd_after
    mata: st_numscalar("`p_after'", _p_raw_save)
    mata: st_numscalar("`smd_after'", _smd_raw_save)
    assert scalar(`p_after') == 101
    assert scalar(`smd_after') == 202
}
local desc_state_rc = _rc
capture mata: mata drop _p_raw_save
capture mata: mata drop _smd_raw_save
if `desc_state_rc' == 0 {
    display as result "  PASS R2: desctab preserves caller Mata namespace"
    local ++pass_count
}
else {
    display as error "  FAIL R2: desctab clobbered caller Mata namespace (rc=`desc_state_rc')"
    local ++fail_count
}

**# R3. stacktab preserves caller objects matching its former workbook names
local ++test_count
local stack_state_book "`output_dir'/v202_stack_state.xlsx"
capture erase "`stack_state_book'"
capture mata: mata drop _stacktab_book
capture mata: mata drop _stacktab_write_book
capture noisily {
    clear
    input str8 label double value
    "Header" .
    "Alpha"  1
    end
    export excel using "`stack_state_book'", sheet("Source") firstrow(variables) replace
    mata: _stacktab_book = 303
    mata: _stacktab_write_book = 404
    stacktab using "`stack_state_book'", ///
        blocks(sheet(Source) rows(1/2) cols(A-B)) sheet("StateTarget")
    tempname stack_after write_after
    mata: st_numscalar("`stack_after'", _stacktab_book)
    mata: st_numscalar("`write_after'", _stacktab_write_book)
    assert scalar(`stack_after') == 303
    assert scalar(`write_after') == 404
}
local stack_state_rc = _rc
capture mata: mata drop _stacktab_book
capture mata: mata drop _stacktab_write_book
if `stack_state_rc' == 0 {
    display as result "  PASS R3: stacktab preserves caller Mata namespace"
    local ++pass_count
}
else {
    display as error "  FAIL R3: stacktab clobbered caller Mata namespace (rc=`stack_state_rc')"
    local ++fail_count
}

**# R4. A post-stage stacktab failure leaves every destination unchanged
local ++test_count
local tx_book "`output_dir'/v202_stack_transaction.xlsx"
local tx_csv "`output_dir'/v202_stack_transaction.csv"
local tx_md "`output_dir'/v202_stack_transaction.md"
capture erase "`tx_book'"
capture erase "`tx_csv'"
capture erase "`tx_md'"
capture frame drop v202_tx_frame
capture noisily {
    clear
    input str8 label double value
    "Header" .
    "Alpha"  1
    end
    export excel using "`tx_book'", sheet("Source") firstrow(variables) replace

    tempname csv_fh
    file open `csv_fh' using "`tx_csv'", write text replace
    file write `csv_fh' "sentinel-csv" _n
    file close `csv_fh'

    frame create v202_tx_frame
    frame v202_tx_frame: set obs 1
    frame v202_tx_frame: generate str20 sentinel = "sentinel-frame"

    global TABTOOLS_QA_STACK_FAIL 1
    capture noisily stacktab using "`tx_book'", ///
        blocks(sheet(Source) rows(1/2) cols(A-B)) sheet("Target") ///
        frame(v202_tx_frame, replace) csv("`tx_csv'") markdown("`tx_md'")
    local tx_rc = _rc
    global TABTOOLS_QA_STACK_FAIL

    assert `tx_rc' == 459
    frame v202_tx_frame: confirm variable sentinel
    frame v202_tx_frame: assert sentinel[1] == "sentinel-frame"

    file open `csv_fh' using "`tx_csv'", read text
    file read `csv_fh' csv_first
    file close `csv_fh'
    assert "`csv_first'" == "sentinel-csv"
    capture confirm file "`tx_md'"
    assert _rc == 601

    quietly import excel using "`tx_book'", describe
    local target_found = 0
    forvalues s = 1/`r(N_worksheet)' {
        if lower(`"`r(worksheet_`s')'"') == "target" local target_found = 1
    }
    assert `target_found' == 0
}
local stack_tx_rc = _rc
global TABTOOLS_QA_STACK_FAIL
capture frame drop v202_tx_frame
if `stack_tx_rc' == 0 {
    display as result "  PASS R4: stacktab post-stage failure is transaction-safe"
    local ++pass_count
}
else {
    display as error "  FAIL R4: stacktab left a partial destination (rc=`stack_tx_rc')"
    local ++fail_count
}

**# R5. Source carries no fixed workbook objects or captured return postings
local ++test_count
capture mata: mata drop _v202_source_audit()
mata:
real rowvector _v202_source_audit(string scalar path)
{
    string colvector files
    string scalar line, lower_line
    real scalar i, fh, return_violations, state_violations

    files = dir(path, "files", "*.ado")
    return_violations = 0
    state_violations = 0
    for (i = 1; i <= rows(files); i++) {
        fh = fopen(path + "/" + files[i], "r")
        while ((line = fget(fh)) != J(0, 0, "")) {
            lower_line = strlower(line)
            return_violations = return_violations +
                (strpos(lower_line, "capture return ") > 0)
            state_violations = state_violations +
                (strpos(line, "book(b)") > 0) +
                (strpos(lower_line, "mata drop b") > 0) +
                (strpos(line, "_p_raw_save") > 0) +
                (strpos(line, "_smd_raw_save") > 0) +
                (strpos(line, "_stacktab_book") > 0) +
                (strpos(line, "_stacktab_write_book") > 0)
        }
        fclose(fh)
    }
    return((return_violations, state_violations))
}
end
capture noisily {
    tempname source_audit
    mata: st_matrix("`source_audit'", _v202_source_audit("`pkg_dir'"))
    assert `source_audit'[1, 1] == 0
    assert `source_audit'[1, 2] == 0
}
local source_rc = _rc
capture mata: mata drop _v202_source_audit()
if `source_rc' == 0 {
    display as result "  PASS R5: source rejects silent returns and fixed Mata scratch names"
    local ++pass_count
}
else {
    display as error "  FAIL R5: source still contains a reviewed anti-pattern (rc=`source_rc')"
    local ++fail_count
}

**# R6. survtab's three-group RMST contract omits two-group contrasts
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20) by(drug) rmst(20)
    confirm matrix r(table)
    assert r(n_groups) == 3
    forvalues g = 1/3 {
        assert !missing(r(rmst_`g'))
        assert !missing(r(rmst_se_`g'))
    }
    capture confirm scalar r(rmst_diff)
    assert _rc != 0
    capture confirm scalar r(rmst_diff_se)
    assert _rc != 0
}
local surv_three_rc = _rc
if `surv_three_rc' == 0 {
    display as result "  PASS R6: survtab three-group RMST return surface is exact"
    local ++pass_count
}
else {
    display as error "  FAIL R6: survtab three-group RMST return surface drifted (rc=`surv_three_rc')"
    local ++fail_count
}

**# R7. Repeated stacktab Markdown stages do not collide in one session
local ++test_count
local repeat_book "`output_dir'/v202_stack_repeat.xlsx"
local repeat_md1 "`output_dir'/v202_stack_repeat_1.md"
local repeat_md2 "`output_dir'/v202_stack_repeat_2.md"
capture erase "`repeat_book'"
capture erase "`repeat_md1'"
capture erase "`repeat_md2'"
capture noisily {
    clear
    input str8 label double value
    "Header" .
    "Alpha"  1
    end
    export excel using "`repeat_book'", sheet("Source") firstrow(variables) replace
    stacktab using "`repeat_book'", ///
        blocks(sheet(Source) rows(1/2) cols(A-B)) sheet("First") ///
        markdown("`repeat_md1'")
    assert _rc == 0
    stacktab using "`repeat_book'", ///
        blocks(sheet(Source) rows(1/2) cols(A-B)) sheet("Second") ///
        markdown("`repeat_md2'")
    assert _rc == 0
    confirm file "`repeat_md1'"
    confirm file "`repeat_md2'"
}
local repeat_md_rc = _rc
if `repeat_md_rc' == 0 {
    display as result "  PASS R7: repeated stacktab Markdown staging is collision-free"
    local ++pass_count
}
else {
    display as error "  FAIL R7: repeated stacktab Markdown staging collided (rc=`repeat_md_rc')"
    local ++fail_count
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_tabtools_v202 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _v202
if `fail_count' > 0 exit 1

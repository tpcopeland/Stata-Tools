*! test_comptab.do - Focused QA for comptab

capture log close _comptab
log using "test_comptab.log", replace text name(_comptab)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* -------------------------------------------------------------------------
* Build stable source frames once
* -------------------------------------------------------------------------
sysuse auto, clear

collect clear
collect: regress price foreign mpg weight
capture frame drop ct_std1
regtab, frame(ct_std1) noint

collect clear
collect: regress price foreign mpg weight length
capture frame drop ct_std2
regtab, frame(ct_std2) noint

collect clear
collect: regress price foreign mpg weight
collect: regress price foreign mpg weight length
capture frame drop ct_stdm
regtab, frame(ct_stdm) noint models("Model A" \ "Model B")

collect clear
collect: regress price foreign mpg weight
collect: regress price foreign mpg weight length
capture frame drop ct_cmp2
regtab, compact frame(ct_cmp2) noint models("Model A" \ "Model B")

capture frame drop ct_cmp3
frame copy ct_cmp2 ct_cmp3
frame ct_cmp3 {
    gen str244 c5 = c1
    gen str244 c6 = c2
}

* -------------------------------------------------------------------------
* 1. Standard rows() workflow
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop ct_out_rows
    comptab ct_std1 ct_std2, rows(1 \ 1 2) frame(ct_out_rows, replace)
    assert r(N_frames) == 2
    assert r(N_models) == 1
    assert r(N_rows) == 6
    assert r(N_cols) == 5
    frame ct_out_rows {
        assert A[4] == "Car origin"
        assert A[5] == "Car origin"
        assert A[6] == "Mileage (mpg)"
    }
    capture frame drop ct_out_rows
}
if _rc == 0 {
    display as result "  PASS: comptab rows() composes standard source frames"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab rows() workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop ct_out_rows

* -------------------------------------------------------------------------
* 2. rownames() matches rendered labels
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop ct_out_labels
    comptab ct_std1 ct_std2, rownames("origin" \ "origin weight") ///
        frame(ct_out_labels, replace)
    assert r(N_rows) == 6
    frame ct_out_labels {
        assert A[4] == "Car origin"
        assert A[5] == "Car origin"
        assert A[6] == "Weight (lbs.)"
    }
    capture frame drop ct_out_labels
}
if _rc == 0 {
    display as result "  PASS: comptab rownames() matches rendered row labels"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab rownames() label matching (rc=`=_rc')"
    local ++fail_count
}
capture frame drop ct_out_labels

* -------------------------------------------------------------------------
* 3. Source variable names are not part of the rownames() contract
* -------------------------------------------------------------------------
local ++test_count
capture noisily comptab ct_std1, rownames("foreign") display
if _rc == 198 {
    display as result "  PASS: comptab rownames() rejects source variable names"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab rownames() variable-name rejection (expected 198, got `=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 4. Compact source frames are accepted directly
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    capture frame drop ct_out_compact
    comptab ct_cmp2, rows(1 2) frame(ct_out_compact, replace)
    assert r(N_models) == 2
    assert r(N_rows) == 5
    assert r(N_cols) == 6
    frame ct_out_compact {
        assert strpos(c1[3], "CI") > 0
        assert c2[3] == "p-value"
        assert c4[3] == "p-value"
    }
    capture frame drop ct_out_compact
}
if _rc == 0 {
    display as result "  PASS: comptab accepts compact regtab source frames"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab compact-source workflow (rc=`=_rc')"
    local ++fail_count
}
capture frame drop ct_out_compact

* -------------------------------------------------------------------------
* 5. Ambiguous mixed layouts are rejected using header-pattern validation
* -------------------------------------------------------------------------
local ++test_count
capture noisily comptab ct_stdm ct_cmp3, rows(1 \ 1) display
if _rc == 198 {
    display as result "  PASS: comptab rejects mixed standard/compact source layouts"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab mixed-layout rejection (expected 198, got `=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 6. open requires Excel output
* -------------------------------------------------------------------------
local ++test_count
capture noisily comptab ct_std1, rows(1) open
if _rc == 198 {
    display as result "  PASS: comptab rejects open without xlsx()/excel()"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab open guard (expected 198, got `=_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* 7. excel() synonym works and apostrophes are valid in sheet names
* -------------------------------------------------------------------------
local ++test_count
capture noisily {
    local xlsx "`output_dir'/test_comptab.xlsx"
    capture erase "`xlsx'"
    comptab ct_std1 ct_std2, rows(1 \ 1) ///
        excel("`xlsx'") sheet("O'Brien") ///
        title("Composite test")
    confirm file "`xlsx'"
    assert "`r(xlsx)'" == "`xlsx'"
    assert "`r(sheet)'" == "O'Brien"
}
if _rc == 0 {
    display as result "  PASS: comptab excel() synonym and apostrophe sheet()"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab excel()/sheet() export (rc=`=_rc')"
    local ++fail_count
}
**# Migrated: varabbrev restore on error

**# 4. comptab restores varabbrev on error (auto-load inside capture noisily)

**## 4a. varabbrev restored after error with nonexistent frame
capture noisily {
    set varabbrev on
    capture comptab _nonexistent_frame_xyz_, rows(1)
    local comptab_rc = _rc
    local va_after = c(varabbrev)
    set varabbrev off
    assert `comptab_rc' != 0
    assert "`va_after'" == "on"
}
if _rc == 0 {
    display as result "  PASS [4a]: comptab restores varabbrev on error (frame not found)"
    local ++pass_count
}
else {
    display as error "  FAIL [4a]: comptab did not restore varabbrev on error (rc=`=_rc')"
    local ++fail_count
}

**## 4b. varabbrev restored after error with missing rows/rownames
capture noisily {
    set varabbrev on
    capture comptab _nonexistent_frame_xyz_
    local comptab_rc = _rc
    local va_after = c(varabbrev)
    set varabbrev off
    assert `comptab_rc' != 0
    assert "`va_after'" == "on"
}
if _rc == 0 {
    display as result "  PASS [4b]: comptab restores varabbrev on error (missing required options)"
    local ++pass_count
}
else {
    display as error "  FAIL [4b]: comptab did not restore varabbrev on error (rc=`=_rc')"
    local ++fail_count
}



**# Migrated: dis/border on composite

* T6: comptab uses regtab frames; just exercise dis/border on the
*     downstream call. Build a small regtab frame first.
collect clear
quietly collect: regress price mpg weight
capture noisily regtab, frame(_v103_fr1, replace)
if _rc == 0 {
    capture noisily comptab _v103_fr1, ///
        rows("1 2") border(thin) dis
}
if _rc == 0 {
    display as result "  PASS T6: comptab dis/border abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL T6: comptab abbreviations (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}
capture frame drop _v103_fr1
collect clear




display as result "comptab QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_comptab tests=`_tc' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1

log close _comptab

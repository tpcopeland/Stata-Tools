*! test_diagtab_errors.do - Public error-contract coverage for diagtab
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
version 17.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall diagtab
quietly net install diagtab, from("`pkg_dir'") replace
discard

capture program drop _dte_record
program define _dte_record
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
    }
    else {
        display as error "  FAIL: `label' (error `rc')"
    }
end

**# Early output-option validation

local ++test_count
capture noisily {
    clear
    input byte test gold marker
    1 1 81
    1 0 81
    0 1 81
    0 0 81
    end

    capture noisily diagtab test gold, open
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 81
    assert _N == 4

    capture noisily diagtab test gold
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(TP) == 1
    assert r(TN) == 1
}
local block_rc = _rc
_dte_record `block_rc' "open requires xlsx()/excel() and leaves the input unchanged"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    clear
    input byte test gold marker
    1 1 84
    1 0 84
    0 1 84
    0 0 84
    end

    capture noisily diagtab test gold, cutoff(.)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 84
    assert _N == 4

    capture noisily diagtab test gold, cutoff(-999)
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(TP) == 2
    assert r(FP) == 2
    assert r(FN) == 0
    assert r(TN) == 0

    capture noisily diagtab test gold, cutoffs(.)
    assert _rc == 198
    capture noisily diagtab test gold, cutoffs(0.5 0.5)
    assert _rc == 198
}
local block_rc = _rc
_dte_record `block_rc' "missing cutoff is rejected while cutoff(-999) remains a valid threshold"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    clear
    input byte test gold marker
    1 1 85
    1 0 85
    0 1 85
    0 0 85
    end

    tempname alias_tag
    local xlsx_path "`c(tmpdir)'/`alias_tag'_xlsx.xlsx"
    local excel_path "`c(tmpdir)'/`alias_tag'_excel.xlsx"
    capture erase "`xlsx_path'"
    capture erase "`excel_path'"

    capture noisily diagtab test gold, xlsx("`xlsx_path'") excel("`excel_path'")
    local call_rc = _rc
    capture confirm file "`xlsx_path'"
    local xlsx_exists = (_rc == 0)
    capture confirm file "`excel_path'"
    local excel_exists = (_rc == 0)
    capture erase "`xlsx_path'"
    capture erase "`excel_path'"

    assert `call_rc' == 198
    assert !`xlsx_exists'
    assert !`excel_exists'
    assert marker == 85
}
local block_rc = _rc
_dte_record `block_rc' "xlsx() and excel() aliases are mutually exclusive and create no file"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

local ++test_count
capture noisily {
    clear
    input byte test gold marker
    1 1 86
    1 0 86
    0 1 86
    0 0 86
    end

    tempname font_tag
    local xlsx_path "`c(tmpdir)'/`font_tag'_font.xlsx"
    capture erase "`xlsx_path'"
    local old_fontsize "$DIAGTAB_FONTSIZE"
    global DIAGTAB_FONTSIZE 0
    capture noisily diagtab test gold, xlsx("`xlsx_path'")
    local call_rc = _rc
    if `"`old_fontsize'"' == "" global DIAGTAB_FONTSIZE
    else global DIAGTAB_FONTSIZE `"`old_fontsize'"'
    capture confirm file "`xlsx_path'"
    local file_exists = (_rc == 0)
    capture erase "`xlsx_path'"

    assert `call_rc' == 198
    assert !`file_exists'
    assert marker == 86
    assert _N == 4

    local old_digits "$DIAGTAB_DIGITS"
    global DIAGTAB_DIGITS 2.5
    capture noisily diagtab test gold
    local digits_rc = _rc
    if `"`old_digits'"' == "" global DIAGTAB_DIGITS
    else global DIAGTAB_DIGITS `"`old_digits'"'
    assert `digits_rc' == 198
}
local block_rc = _rc
_dte_record `block_rc' "invalid formatting globals fail before output or data mutation"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Mid-path empty marked sample

local ++test_count
capture noisily {
    clear
    input long id byte test gold marker
    1 1 1 82
    2 1 0 82
    3 0 1 82
    4 0 0 82
    end

    capture noisily diagtab test gold if id < 0
    local call_rc = _rc
    assert `call_rc' == 2000
    assert marker == 82
    assert test == (id <= 2)
    assert gold == inlist(id, 1, 3)

    capture noisily diagtab test gold if id <= 4
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(TP) + r(FP) + r(FN) + r(TN) == 4
}
local block_rc = _rc
_dte_record `block_rc' "an empty if-sample errors without mutation; the legal sample runs"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Late frame destination collision must not silently overwrite

local ++test_count
capture noisily {
    clear
    input byte test gold marker
    1 1 83
    1 0 83
    0 1 83
    0 0 83
    end
    capture frame drop diagtab_existing
    capture frame drop diagtab_result
    frame create diagtab_existing
    frame diagtab_existing: clear
    frame diagtab_existing: set obs 1
    frame diagtab_existing: generate byte sentinel = 99

    tempname atomic_tag
    local csv_path "`c(tmpdir)'/`atomic_tag'.csv"
    local markdown_path "`c(tmpdir)'/`atomic_tag'.md"
    capture erase "`csv_path'"
    capture erase "`markdown_path'"

    capture noisily diagtab test gold, frame(diagtab_existing) ///
        csv("`csv_path'") markdown("`markdown_path'")
    local call_rc = _rc
    capture confirm file "`csv_path'"
    local csv_exists = (_rc == 0)
    capture confirm file "`markdown_path'"
    local markdown_exists = (_rc == 0)
    assert `call_rc' == 110
    assert !`csv_exists'
    assert !`markdown_exists'
    assert marker == 83
    frame diagtab_existing: assert sentinel == 99

    capture noisily diagtab test gold, frame(diagtab_result)
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert "`r(frame)'" == "diagtab_result"
    frame diagtab_result: confirm variable c1
    assert marker == 83
    capture erase "`csv_path'"
    capture erase "`markdown_path'"
    capture frame drop diagtab_existing
    capture frame drop diagtab_result
}
local block_rc = _rc
_dte_record `block_rc' "frame conflicts are preflighted before any output destination is mutated"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_diagtab_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
exit 0

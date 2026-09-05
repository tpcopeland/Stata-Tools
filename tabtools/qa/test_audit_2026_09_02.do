*! test_audit_2026_09_02.do - Regressions from the 2026-09-02 comprehensive audit
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
version 17.0
set processors 1
set varabbrev off

capture log close _all
log using "test_audit_2026_09_02.log", replace text name(_audit0902)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

capture program drop fakeextmiss
program define fakeextmiss, eclass
    version 17.0
    quietly regress price mpg
    ereturn scalar N = .a
    ereturn scalar ll = .b
    ereturn local cmd "fakeextmiss"
end

capture program drop __tt_make_rate_file
program define __tt_make_rate_file
    version 17.0
    syntax, SAVING(string) SCALE(real)
    clear
    set obs 2
    generate byte exposure = _n - 1
    generate double _D = cond(_n == 1, 10, 20)
    generate double _Y = 1000
    generate double _Rate = (_D / _Y) * `scale'
    generate double _Lower = _Rate * 0.8
    generate double _Upper = _Rate * 1.2
    label variable _Lower "Lower 95% confidence limit"
    label variable _Upper "Upper 95% confidence limit"
    label define __tt_rate 0 "Low" 1 "High", replace
    label values exposure __tt_rate
    quietly save "`saving'.dta", replace
end

**# A1. Extended missing fit statistics are absent from output and r()
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: fakeextmiss
    capture frame drop __tt_extmiss
    regtab, stats(n ll aic bic) frame(__tt_extmiss, replace)

    assert r(n_1) == .
    assert r(ll_1) == .
    assert r(aic_1) == .
    assert r(bic_1) == .
    frame __tt_extmiss: quietly count if inlist(strtrim(A), ///
        "Observations", "Log-likelihood", "AIC", "BIC")
    assert r(N) == 0
}
local a1_rc = _rc
capture frame drop __tt_extmiss
if `a1_rc' == 0 {
    display as result "  PASS A1: extended missing fit statistics are not published"
    local ++pass_count
}
else {
    display as error "  FAIL A1: extended missing fit-statistic guard (rc=`a1_rc')"
    local ++fail_count
}

**# A2. System and extended missing categories have distinct public labels
local ++test_count
capture noisily {
    clear
    input double row double col
    .  .
    .a .a
    0  0
    1  1
    .  0
    .a 1
    0  .
    1  .a
    end
    capture frame drop __tt_missing
    crosstab row col, missing frame(__tt_missing, replace)
    frame __tt_missing: quietly count if c1 == "Missing"
    assert r(N) == 1
    frame __tt_missing: quietly count if c1 == "Missing (.a)"
    assert r(N) == 1
    frame __tt_missing: assert c4[2] == "Missing"
    frame __tt_missing: assert c5[2] == "Missing (.a)"
}
local a2_rc = _rc
capture frame drop __tt_missing
if `a2_rc' == 0 {
    display as result "  PASS A2: missing categories retain distinct labels"
    local ++pass_count
}
else {
    display as error "  FAIL A2: distinct missing-category labels (rc=`a2_rc')"
    local ++fail_count
}

**# A2b. Fractional categories are not mistaken for missing values
local ++test_count
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local decimal_csv "`output_dir'/audit_decimal.csv"
local decimal_md "`output_dir'/audit_decimal.md"
local decimal_xlsx "`output_dir'/audit_decimal.xlsx"
capture erase "`decimal_csv'"
capture erase "`decimal_md'"
capture erase "`decimal_xlsx'"
capture noisily {
    clear
    input double row double col
    .25 .5
    .25 1
    1 .5
    1 1
    . .
    .a .a
    end

    capture frame drop __tt_decimal
    crosstab row col, missing frame(__tt_decimal, replace) ///
        csv("`decimal_csv'") markdown("`decimal_md'") ///
        xlsx("`decimal_xlsx'") sheet("Decimal")

    frame __tt_decimal: count if c1 == ".25"
    assert r(N) == 1
    frame __tt_decimal: count if c1 == "Missing (.25)"
    assert r(N) == 0
    frame __tt_decimal: count if c2 == ".5"
    assert r(N) == 1
    frame __tt_decimal: count if c2 == "Missing (.5)"
    assert r(N) == 0
    frame __tt_decimal: count if c1 == "Missing"
    assert r(N) == 1
    frame __tt_decimal: count if c1 == "Missing (.a)"
    assert r(N) == 1

    preserve
    import delimited "`decimal_csv'", clear varnames(nonames) stringcols(_all)
    quietly count if v1 == ".25"
    assert r(N) == 1
    quietly count if v1 == "Missing (.25)"
    assert r(N) == 0
    quietly count if v2 == ".5"
    assert r(N) == 1
    quietly count if v2 == "Missing (.5)"
    assert r(N) == 0
    restore

    preserve
    import excel using "`decimal_xlsx'", sheet("Decimal") clear allstring
    local saw_fraction 0
    local saw_false_missing 0
    foreach _v of varlist _all {
        quietly count if `_v' == ".25" | `_v' == ".5"
        if r(N) > 0 local saw_fraction 1
        quietly count if `_v' == "Missing (.25)" | `_v' == "Missing (.5)"
        if r(N) > 0 local saw_false_missing 1
    }
    assert `saw_fraction' == 1
    assert `saw_false_missing' == 0
    restore

    tempname decimal_fh
    local saw_md_fraction 0
    local saw_md_false_missing 0
    local decimal_line ""
    file open `decimal_fh' using "`decimal_md'", read text
    file read `decimal_fh' decimal_line
    while r(eof) == 0 {
        if strpos(`"`decimal_line'"', ".25") > 0 | strpos(`"`decimal_line'"', ".5") > 0 {
            local saw_md_fraction 1
        }
        if strpos(`"`decimal_line'"', "Missing (.25)") > 0 | ///
            strpos(`"`decimal_line'"', "Missing (.5)") > 0 {
            local saw_md_false_missing 1
        }
        file read `decimal_fh' decimal_line
    }
    file close `decimal_fh'
    assert `saw_md_fraction' == 1
    assert `saw_md_false_missing' == 0
}
local a2b_rc = _rc
capture frame drop __tt_decimal
capture erase "`decimal_csv'"
capture erase "`decimal_md'"
capture erase "`decimal_xlsx'"
if `a2b_rc' == 0 {
    display as result "  PASS A2b: fractional categories retain numeric labels across sinks"
    local ++pass_count
}
else {
    display as error "  FAIL A2b: fractional category labels (rc=`a2b_rc')"
    local ++fail_count
}

**# A3. stratetab matrix columns use collision-safe outcome identities
local ++test_count
tempfile rate_one rate_two
capture noisily {
    __tt_make_rate_file, saving("`rate_one'") scale(1)
    __tt_make_rate_file, saving("`rate_two'") scale(2)
    clear
    stratetab, using("`rate_one'" "`rate_two'") outcomes(2) ///
        outlabels("A B \ A_B") outcomeids(first_id \ second_id)
    local rate_names : colnames r(rates)
    assert "`rate_names'" == "first_id second_id"

    stratetab, using("`rate_one'" "`rate_two'") outcomes(2) ///
        outlabels("First \ Second") ///
        outcomeids(abcdefghijklmnopqrstuvwxyzABCDEF_one \ abcdefghijklmnopqrstuvwxyzABCDEF_two)
    local long_names : colnames r(rates)
    local long_1 : word 1 of `long_names'
    local long_2 : word 2 of `long_names'
    assert "`long_1'" != "`long_2'"
}
local a3_rc = _rc
capture erase "`rate_one'.dta"
capture erase "`rate_two'.dta"
if `a3_rc' == 0 {
    display as result "  PASS A3: stratetab outcome identities are legal and unique"
    local ++pass_count
}
else {
    display as error "  FAIL A3: stratetab matrix column identities (rc=`a3_rc')"
    local ++fail_count
}

**# A4. survtab matrix columns are legal, unique identifiers
local ++test_count
capture noisily {
    sysuse cancer, clear
    label define drug 1 "Control group" 2 "Control_group" 3 "!!!", replace
    label values drug drug
    stset studytime, failure(died)
    survtab, times(10 20) by(drug)
    local group_names : colnames r(table)
    assert "`group_names'" == "Control_group Control_group_2 group3"
    assert "`r(group_1_label)'" == "Control group"
    assert "`r(group_2_label)'" == "Control_group"
    assert "`r(group_3_label)'" == "!!!"
}
local a4_rc = _rc
if `a4_rc' == 0 {
    display as result "  PASS A4: survtab matrix identifiers preserve separate display labels"
    local ++pass_count
}
else {
    display as error "  FAIL A4: survtab matrix column identifiers (rc=`a4_rc')"
    local ++fail_count
}

**# A5. frame replacement is transactional after staging
local ++test_count
capture noisily {
    capture frame drop __tt_destination
    frame create __tt_destination
    frame __tt_destination: set obs 1
    frame __tt_destination: generate str20 sentinel = "old-destination"
    clear
    set obs 2
    generate double replacement = _n
    global TABTOOLS_QA_FRAME_STAGE_FAIL 1
    capture noisily _tabtools_frame_put "__tt_destination, replace"
    local frame_rc = _rc
    global TABTOOLS_QA_FRAME_STAGE_FAIL
    assert `frame_rc' == 459
    frame __tt_destination: confirm variable sentinel
    frame __tt_destination: assert sentinel[1] == "old-destination"
}
local a5_rc = _rc
global TABTOOLS_QA_FRAME_STAGE_FAIL
capture frame drop __tt_destination
if `a5_rc' == 0 {
    display as result "  PASS A5: staged frame failure preserves the old destination"
    local ++pass_count
}
else {
    display as error "  FAIL A5: transactional frame replacement (rc=`a5_rc')"
    local ++fail_count
}

**# A6. Persistent font-size defaults receive the same range validation
local ++test_count
local saved_fontsize `"$TABTOOLS_FONTSIZE"'
capture noisily {
    global TABTOOLS_FONTSIZE 0
    capture noisily _tabtools_resolve_format
    assert _rc == 198
    global TABTOOLS_FONTSIZE 100
    capture noisily _tabtools_resolve_format
    assert _rc == 198
    global TABTOOLS_FONTSIZE not_a_number
    capture noisily _tabtools_resolve_format
    assert _rc == 198
}
local a6_rc = _rc
global TABTOOLS_FONTSIZE `"`saved_fontsize'"'
if `a6_rc' == 0 {
    display as result "  PASS A6: invalid persistent font sizes are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL A6: persistent font-size validation (rc=`a6_rc')"
    local ++fail_count
}

**# A7. meta/stats rendering rejects unsupported column dimensions
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    quietly collect: regress price mpg weight
    quietly collect: regress price mpg weight foreign
    collect layout (colname) (cmdset#result[_r_b])
    preserve
    capture noisily _tabtools_collect_render, type(stats) rowdim(colname) ///
        coldim(cmdset) results(_r_b)
    local render_rc = _rc
    restore
    assert `render_rc' == 198
}
local a7_rc = _rc
if `a7_rc' == 0 {
    display as result "  PASS A7: unsupported meta/stats coldim() is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL A7: meta/stats coldim() contract (rc=`a7_rc')"
    local ++fail_count
}

**# A8. An explicitly missing console label variable is rejected
local ++test_count
capture noisily {
    clear
    set obs 2
    generate str10 c1 = "value"
    capture noisily _tabtools_console_display 1 "Test", labelvar(not_here)
    assert _rc == 111
}
local a8_rc = _rc
if `a8_rc' == 0 {
    display as result "  PASS A8: missing labelvar() is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL A8: explicit labelvar() validation (rc=`a8_rc')"
    local ++fail_count
}

**# A9. stratetab accepts a case-insensitive .xlsx extension
local ++test_count
tempfile rate_upper book_upper
local upper_book "`book_upper'.XLSX"
capture noisily {
    __tt_make_rate_file, saving("`rate_upper'") scale(1)
    clear
    stratetab, using("`rate_upper'") outcomes(1) xlsx("`upper_book'")
    confirm file "`upper_book'"
}
local a9_rc = _rc
capture erase "`rate_upper'.dta"
capture erase "`upper_book'"
if `a9_rc' == 0 {
    display as result "  PASS A9: stratetab accepts uppercase .XLSX"
    local ++pass_count
}
else {
    display as error "  FAIL A9: case-insensitive xlsx extension (rc=`a9_rc')"
    local ++fail_count
}

capture frame drop __tt_extmiss
capture frame drop __tt_missing
capture frame drop __tt_destination
capture program drop fakeextmiss
capture program drop __tt_make_rate_file
collect clear

display as result "RESULT: test_audit_2026_09_02 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
log close _audit0902
if `fail_count' > 0 exit 1

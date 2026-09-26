* test_audit_2026_09_26_fixes.do - regressions from the 26 September 2026 audit
* Each section failed on 2.1.11 before its fix:
*   N7   stratetab accepted missing pyscale()/ratescale() (audit I5) and
*        printed missing person-time or rates
*   N8   effecttab's methods text fell back to the active e(subcmd) when the
*        collected command line could not be parsed (audit I8)
*   N9   effecttab r(table) row names could collide after sanitizing and
*        truncation, and from() split a row name containing a space across
*        two rows (audit I4, effecttab part)
*   N10  the vendored qa/tools/check_xlsx.py passed --col-not-empty on an
*        empty or header-only sheet (audit I6)
* Expected values come from the data (summarize), the fitted model's own
* r(b), or hand-built workbooks, never from the command under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _audit0926
log using "test_audit_2026_09_26_fixes.log", replace text name(_audit0926)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local checker "`qa_dir'/tools/check_xlsx.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

* Trimmed contents of column `col' in frame `frname' on the one row whose
* trimmed first-column label is `label'.
capture program drop _a26_cell
program define _a26_cell, rclass
    version 17.0
    args frname labelvar label col
    frame `frname' {
        tempvar rn
        quietly generate long `rn' = _n
        quietly count if strtrim(`labelvar') == `"`label'"'
        if r(N) != 1 {
            display as error `"frame `frname': `r(N)' rows labelled "`label'""'
            exit 459
        }
        quietly summarize `rn' if strtrim(`labelvar') == `"`label'"', meanonly
        local cell = strtrim(`col'[r(min)])
    }
    return local cell `"`cell'"'
end

* Run check_xlsx.py --col-not-empty A on one sheet; returns PASS or FAIL.
capture program drop _a26_colcheck
program define _a26_colcheck, rclass
    version 17.0
    args checker book sheet result
    capture erase "`result'"
    shell python3 "`checker'" "`book'" --sheet "`sheet'" --col-not-empty A ///
        --result-file "`result'" --quiet
    confirm file "`result'"
    tempname fh
    file open `fh' using "`result'", read text
    file read `fh' line
    file close `fh'
    return local status = strtrim(`"`line'"')
end

**# N7: stratetab rejects missing, zero and negative scales
* strate on sysuse cancer: 31 deaths over 744 person-years.
sysuse cancer, clear
quietly stset studytime, failure(died)
quietly strate, output("`output_dir'/_a26_rate", replace)
quietly summarize studytime
local want_py = r(sum)
quietly summarize died
local want_d = r(sum)

capture noisily {
    assert `want_py' == 744 & `want_d' == 31
    foreach opt in pyscale ratescale {
        foreach val in . .a 0 -1 {
            local book "`output_dir'/_a26_scale.xlsx"
            capture erase "`book'"
            capture frame drop _a26_scale
            capture stratetab, using("`output_dir'/_a26_rate") outcomes(1) ///
                `opt'(`val') xlsx("`book'") frame(_a26_scale)
            local rc = _rc
            if `rc' != 198 {
                display as error "  `opt'(`val') returned rc=`rc', want 198"
                exit 9
            }
            capture confirm file "`book'"
            if _rc == 0 {
                display as error "  `opt'(`val') wrote `book' before rejecting"
                exit 9
            }
            capture confirm frame _a26_scale
            if _rc == 0 {
                display as error "  `opt'(`val') created a frame before rejecting"
                exit 9
            }
        }
    }
}
if _rc == 0 {
    display as result "  PASS: N7 pyscale()/ratescale() of . .a 0 -1 rejected before output"
    local ++pass_count
}
else {
    display as error "  FAIL: N7 missing or non-positive scales (rc=`=_rc')"
    local ++fail_count
}

* A valid scale still gives the right numbers: default scales, then
* pyscale(2) halves the person-time.
capture noisily {
    capture frame drop _a26_ok
    stratetab, using("`output_dir'/_a26_rate") outcomes(1) frame(_a26_ok)
    _a26_cell _a26_ok c1 "Overall" c2
    assert "`r(cell)'" == "`want_d'"
    _a26_cell _a26_ok c1 "Overall" c3
    assert "`r(cell)'" == "`want_py'"
    _a26_cell _a26_ok c1 "Overall" c4
    local want_rate = string(1000 * `want_d' / `want_py', "%9.1f")
    assert strpos("`r(cell)'", "`want_rate' (") == 1
    capture frame drop _a26_ok2
    stratetab, using("`output_dir'/_a26_rate") outcomes(1) pyscale(2) frame(_a26_ok2)
    _a26_cell _a26_ok2 c1 "Overall" c3
    assert "`r(cell)'" == "`=`want_py' / 2'"
}
if _rc == 0 {
    display as result "  PASS: N7 valid scales give person-time 744 (372 with pyscale(2))"
    local ++pass_count
}
else {
    display as error "  FAIL: N7 valid-scale numerical check (rc=`=_rc')"
    local ++fail_count
}

**# N8: effecttab methods text never comes from ambient e()
* Each case collects a regression-adjustment fit and then leaves an
* unrelated IPW fit active, so e(subcmd) is "ipw".
webuse cattaneo2, clear
local tail "with 95% confidence intervals. Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."

capture program drop _a26_repost
program define _a26_repost, eclass
    version 17.0
    args cmdline
    ereturn local cmdline `"`cmdline'"'
end

* Guard: an ordinary collect: prefix records "teffects ra ...".
capture noisily {
    collect clear
    quietly collect: teffects ra (bweight mage) (mbsmoke)
    quietly teffects ipw (bweight) (mbsmoke mage)
    assert "`e(subcmd)'" == "ipw"
    effecttab
    display `"methods: `r(methods)'"'
    assert `"`r(methods)'"' == "Average treatment effects estimated using regression adjustment `tail'"
}
if _rc == 0 {
    display as result "  PASS: N8 guard collected RA fit described as regression adjustment"
    local ++pass_count
}
else {
    display as error "  FAIL: N8 guard collected RA fit (rc=`=_rc')"
    local ++fail_count
}

* The collection's command line is recorded in capitals: the estimator is
* still the collection's own (RA), never the active IPW fit.
capture noisily {
    collect clear
    quietly teffects ra (bweight mage) (mbsmoke)
    _a26_repost "TEFFECTS ra (bweight mage) (mbsmoke)"
    quietly collect get e()
    collect label levels result cmd "Command" cmdline "Command line as typed", modify
    quietly teffects ipw (bweight) (mbsmoke mage)
    assert "`e(subcmd)'" == "ipw"
    effecttab
    display `"methods: `r(methods)'"'
    assert `"`r(methods)'"' == "Average treatment effects estimated using regression adjustment `tail'"
}
if _rc == 0 {
    display as result "  PASS: N8 capitalised collected command line still describes RA"
    local ++pass_count
}
else {
    display as error "  FAIL: N8 capitalised collected command line (rc=`=_rc')"
    local ++fail_count
}

* The collection's command line names no teffects estimator: the text must
* be generic rather than borrow "ipw" from the active estimates.
capture noisily {
    collect clear
    quietly teffects ra (bweight mage) (mbsmoke)
    _a26_repost "tfx ra (bweight mage) (mbsmoke)"
    quietly collect get e()
    collect label levels result cmd "Command" cmdline "Command line as typed", modify
    quietly teffects ipw (bweight) (mbsmoke mage)
    assert "`e(subcmd)'" == "ipw"
    effecttab
    display `"methods: `r(methods)'"'
    assert `"`r(methods)'"' == "Average treatment effects estimated using teffects `tail'"
}
if _rc == 0 {
    display as result "  PASS: N8 unparseable collected command line gives the generic description"
    local ++pass_count
}
else {
    display as error "  FAIL: N8 unparseable collected command line (rc=`=_rc')"
    local ++fail_count
}

**# N9: effecttab r(table) row names are unique and map to the right rows
* Two binary factors share value labels, and the factor a has two levels
* whose labels differ only by punctuation, so the sanitized names collide.
capture program drop _a26_margdata
program define _a26_margdata
    version 17.0
    clear
    set seed 20260926
    quietly set obs 400
    generate byte a = runiform() < 0.5
    generate byte b = runiform() < 0.5
    generate byte y = runiform() < invlogit(-0.5 + a + 0.3 * b)
    label define A26_YN 0 "No" 1 "Yes", replace
    label values b A26_YN
    label define A26_A 0 "Dose 1.0" 1 "Dose 1 0", replace
    label values a A26_A
    label variable a "Dose group"
    label variable b "Exposed"
end

* Assert that r(table) rows are uniquely named and that looking each name up
* returns the estimate expected for that row.
capture program drop _a26_rowcheck
program define _a26_rowcheck
    version 17.0
    args mat want
    local names : rownames `mat'
    local nr = rowsof(`mat')
    local nw : word count `want'
    if `nr' != `nw' {
        display as error "  r(table) has `nr' rows, want `nw'"
        exit 9
    }
    local uniq : list uniq names
    if `: word count `uniq'' != `nr' {
        display as error "  r(table) row names are not unique: `names'"
        exit 9
    }
    forvalues i = 1/`nr' {
        local nm : word `i' of `names'
        local w : word `i' of `want'
        if rownumb(`mat', "`nm'") != `i' {
            display as error "  rownumb(`nm') != `i'"
            exit 9
        }
        if reldif(`mat'[rownumb(`mat', "`nm'"), 1], `w') > 1e-6 {
            display as error "  row `nm': " `mat'[`i', 1] " want `w'"
            exit 9
        }
    }
end

capture noisily {
    _a26_margdata
    quietly logit y i.a i.b
    collect clear
    quietly collect: margins a b
    matrix _a26_mb = r(b)
    local want
    foreach c in 0.a 1.a 0.b 1.b {
        local want "`want' `=_a26_mb[1, colnumb(_a26_mb, "`c'")]'"
    }
    effecttab
    matrix _a26_rt = r(table)
    _a26_rowcheck _a26_rt "`want'"
    local names : rownames _a26_rt
    assert "`names'" == "__Dose_1_0 __Dose_1_0_2 __No __Yes"
}
if _rc == 0 {
    display as result "  PASS: N9 punctuation-only label differences give distinct r(table) names"
    local ++pass_count
}
else {
    display as error "  FAIL: N9 punctuation-only label collision (rc=`=_rc')"
    local ++fail_count
}

* Shared value labels across two factors.
capture noisily {
    _a26_margdata
    label values a A26_YN
    quietly logit y i.a i.b
    collect clear
    quietly collect: margins a b
    matrix _a26_mb = r(b)
    local want
    foreach c in 0.a 1.a 0.b 1.b {
        local want "`want' `=_a26_mb[1, colnumb(_a26_mb, "`c'")]'"
    }
    effecttab
    matrix _a26_rt = r(table)
    _a26_rowcheck _a26_rt "`want'"
    local names : rownames _a26_rt
    assert "`names'" == "__No __Yes __No_2 __Yes_2"
}
if _rc == 0 {
    display as result "  PASS: N9 shared value labels give distinct r(table) names"
    local ++pass_count
}
else {
    display as error "  FAIL: N9 shared value labels (rc=`=_rc')"
    local ++fail_count
}

* Long labels that agree in their first 32 sanitized characters.
capture noisily {
    _a26_margdata
    label define A26_LONG 0 "Treatment arm with a long shared prefix, first" ///
        1 "Treatment arm with a long shared prefix, second", replace
    label values a A26_LONG
    quietly logit y i.a i.b
    collect clear
    quietly collect: margins a
    matrix _a26_mb = r(b)
    local want
    foreach c in 0.a 1.a {
        local want "`want' `=_a26_mb[1, colnumb(_a26_mb, "`c'")]'"
    }
    effecttab
    matrix _a26_rt = r(table)
    _a26_rowcheck _a26_rt "`want'"
    local names : rownames _a26_rt
    foreach nm of local names {
        assert strlen("`nm'") <= 32
    }
}
if _rc == 0 {
    display as result "  PASS: N9 long labels sharing a 32-character prefix stay distinct"
    local ++pass_count
}
else {
    display as error "  FAIL: N9 long shared-prefix labels (rc=`=_rc')"
    local ++fail_count
}

* from(): duplicate row names, and a row name containing a space, keep one
* display row each and distinct r(table) names.
capture noisily {
    matrix _a26_M = (1.5, 1.1, 2.0, .01 \ 2.5, 2.1, 3.0, .02 \ 3.5, 3.1, 4.0, .03)
    matrix colnames _a26_M = b ll ul p
    matrix rownames _a26_M = "Same label" "Same label" x
    capture frame drop _a26_from
    effecttab, from(_a26_M) frame(_a26_from)
    matrix _a26_rt = r(table)
    _a26_rowcheck _a26_rt "1.5 2.5 3.5"
    frame _a26_from {
        quietly count if strtrim(A) == "Same label"
        assert r(N) == 2
        quietly count if inlist(strtrim(A), "Same", "label")
        assert r(N) == 0
    }
}
if _rc == 0 {
    display as result "  PASS: N9 from() duplicate and spaced row names"
    local ++pass_count
}
else {
    display as error "  FAIL: N9 from() duplicate and spaced row names (rc=`=_rc')"
    local ++fail_count
}

**# N10: vendored check_xlsx.py --col-not-empty needs a data range
* Hand-built sheets: whitespace only (no content), header only, and a
* populated column. Only the populated sheet may pass.
local book "`output_dir'/_a26_colcheck.xlsx"
local cres "`output_dir'/_a26_colcheck.txt"
capture noisily {
    capture erase "`book'"
    quietly putexcel set "`book'", sheet("Empty") replace
    quietly putexcel A1 = " "
    quietly putexcel set "`book'", sheet("HeaderOnly") modify
    quietly putexcel A1 = "Header"
    quietly putexcel set "`book'", sheet("Populated") modify
    quietly putexcel A1 = "Header" A2 = "first" A3 = "second"
    quietly putexcel set "`book'", sheet("Gap") modify
    quietly putexcel A1 = "Header" A2 = "first" B3 = "other" A4 = "third"
    putexcel clear
    _a26_colcheck "`checker'" "`book'" Empty "`cres'"
    assert "`r(status)'" == "FAIL"
    _a26_colcheck "`checker'" "`book'" HeaderOnly "`cres'"
    assert "`r(status)'" == "FAIL"
    _a26_colcheck "`checker'" "`book'" Populated "`cres'"
    assert "`r(status)'" == "PASS"
    _a26_colcheck "`checker'" "`book'" Gap "`cres'"
    assert "`r(status)'" == "FAIL"
}
if _rc == 0 {
    display as result "  PASS: N10 --col-not-empty fails empty/header-only sheets, passes a populated one"
    local ++pass_count
}
else {
    display as error "  FAIL: N10 --col-not-empty data-range guard (rc=`=_rc')"
    local ++fail_count
}
capture erase "`book'"
capture erase "`cres'"
capture erase "`output_dir'/_a26_rate.dta"
capture erase "`output_dir'/_a26_scale.xlsx"

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_audit_2026_09_26_fixes tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _audit0926
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_audit_2026_09_26_fixes tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _audit0926

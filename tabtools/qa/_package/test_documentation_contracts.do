clear all
version 16.0

capture log close _doc_contracts
log using "test_documentation_contracts.log", replace text name(_doc_contracts)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Documentation Contract Checks

local ++test_count
capture noisily {
    tempname fh
    local saw_excel_alias 0

    file open `fh' using "`pkg_dir'/regtab.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "{cmd:regtab},") > 0 & ///
            strpos(`"`line'"', "{opt excel(filename)}") > 0 {
            local saw_excel_alias 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `saw_excel_alias' == 1
}
if _rc == 0 {
    display as result "  PASS: regtab syntax documents excel() alias"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab syntax documents excel() alias (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' regtab_excel_alias"
}

local ++test_count
capture noisily {
    tempname fh
    local saw_optional_by 0

    file open `fh' using "`pkg_dir'/table1_tc.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "{opt table1_tc}") > 0 & ///
            strpos(`"`line'"', "[{cmd:,} {opt by(varname)} {it:options}]") > 0 {
            local saw_optional_by 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `saw_optional_by' == 1
}
if _rc == 0 {
    display as result "  PASS: table1_tc quick-start syntax shows optional by()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc quick-start syntax shows optional by() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' table1_optional_by"
}

local ++test_count
capture noisily {
    tempfile grep_out
    shell grep -cE 'Repository Checkout Demo|not part of the net install payload' "`pkg_dir'/README.md" > "`grep_out'" 2>/dev/null
    tempname fh
    file open `fh' using "`grep_out'", read text
    file read `fh' line
    file close `fh'
    assert real("`line'") == 2
}
if _rc == 0 {
    display as result "  PASS: README labels demo as checkout-only"
    local ++pass_count
}
else {
    display as error "  FAIL: README labels demo as checkout-only (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' readme_demo_scope"
}

foreach helpfile in stratetab hrcomptab {
    local ++test_count
    capture noisily {
        tempname fh
        local saw_sketch 0
        local saw_cookbook 0

        file open `fh' using "`pkg_dir'/`helpfile'.sthlp", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`line'"', "workflow sketches") > 0 local saw_sketch 1
            if strpos(`"`line'"', "tabtools_tips") > 0 local saw_cookbook 1
            file read `fh' line
        }
        file close `fh'

        assert `saw_sketch' == 1
        assert `saw_cookbook' == 1
    }
    if _rc == 0 {
        display as result "  PASS: `helpfile' examples are scoped as sketches"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `helpfile' examples are scoped as sketches (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' `helpfile'_example_scope"
    }
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failed tests:`failed_tests'"
    capture log close _doc_contracts
    exit 1
}

display as result "ALL TESTS PASSED"
capture log close _doc_contracts

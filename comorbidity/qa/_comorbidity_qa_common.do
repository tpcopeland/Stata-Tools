version 16.0

capture program drop _comorbidity_qa_bootstrap
program define _comorbidity_qa_bootstrap
    version 16.0

    local qa_dir "`c(pwd)'"
    local slash = strrpos("`qa_dir'", "/")
    local pkg_dir = substr("`qa_dir'", 1, `slash' - 1)
    local slash = strrpos("`pkg_dir'", "/")
    local repo_dir = substr("`pkg_dir'", 1, `slash' - 1)
    local slash = strrpos("`repo_dir'", "/")
    local parent = substr("`repo_dir'", 1, `slash' - 1)
    local codescan_dir "`parent'/Stata-Tools/codescan"

    tempfile sysbase
    local plus "`sysbase'_plus"
    local personal "`sysbase'_personal"
    local site "`sysbase'_site"
    local oldplace "`sysbase'_oldplace"
    capture mkdir "`plus'"
    capture mkdir "`personal'"
    capture mkdir "`site'"
    capture mkdir "`oldplace'"
    sysdir set SITE "`site'"
    sysdir set PLUS "`plus'"
    sysdir set PERSONAL "`personal'"
    sysdir set OLDPLACE "`oldplace'"

    capture ado uninstall comorbidity
    quietly net install comorbidity, from("`pkg_dir'") replace

    capture confirm file "`codescan_dir'/codescan.ado"
    if !_rc {
        quietly net install codescan, from("`codescan_dir'") replace
    }
    else {
        capture which codescan
        if _rc {
            display as error "codescan dependency unavailable for QA"
            exit 199
        }
    }
    discard
end

capture program drop _comorbidity_result
program define _comorbidity_result
    version 16.0
    args name tests pass fail
    display as result "Results: `pass'/`tests' passed, `fail' failed"
    if `fail' > 0 {
        display as error "SOME TESTS FAILED"
        display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail'"
        exit 1
    }
    display as result "ALL TESTS PASSED"
    display "RESULT: `name' tests=`tests' pass=`pass' fail=`fail'"
end

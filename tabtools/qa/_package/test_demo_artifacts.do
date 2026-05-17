* test_demo_artifacts.do - Run repo-only demo and verify produced artifacts

clear all
set more off
set varabbrev off
version 16.0

capture log close _demoqa
log using "test_demo_artifacts.log", replace text name(_demoqa)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local repo_root = subinstr("`pkg_dir'", "/tabtools", "", 1)
local demo_dir "`pkg_dir'/demo"
local old_pwd "`c(pwd)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

capture confirm file "`repo_root'/_data/cohort.dta"
local has_data = (_rc == 0)
capture confirm file "`repo_root'/tc_schemes/stata.toc"
local has_scheme = (_rc == 0)

if !`has_data' | !`has_scheme' {
    display as text "  SKIP: repo-only demo assets not available"
    local ++skip_count
}
else {
    **# Run Demo
    local ++test_count
    capture noisily {
        cd "`demo_dir'"
        do "demo_tabtools.do"
        cd "`old_pwd'"
    }
    local demo_rc = _rc
    capture cd "`old_pwd'"
    if `demo_rc' == 0 {
        display as result "  PASS: demo/demo_tabtools.do runs from demo directory"
        local ++pass_count
    }
    else {
        display as error "  FAIL: demo/demo_tabtools.do run (rc=`demo_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' demo_run"
    }

    **# Verify Artifacts
    local ++test_count
    capture noisily {
        local xlsx_files ///
            demo_table1.xlsx ///
            demo_desctab.xlsx ///
            demo_regtab.xlsx ///
            demo_comptab.xlsx ///
            demo_effecttab.xlsx ///
            demo_stratetab.xlsx ///
            demo_corrtab.xlsx ///
            demo_crosstab.xlsx ///
            demo_diagtab.xlsx ///
            demo_survtab.xlsx ///
            demo_hrcomptab.xlsx

        foreach f of local xlsx_files {
            local artifact "`demo_dir'/`f'"
            confirm file "`artifact'"
            shell test -s "`artifact'"
            import excel "`artifact'", cellrange(A1:A1) clear
        }

        confirm file "`demo_dir'/console_output.smcl"
        shell test -s "`demo_dir'/console_output.smcl"
    }
    if _rc == 0 {
        display as result "  PASS: demo workbooks and console log exist and are readable"
        local ++pass_count
    }
    else {
        display as error "  FAIL: demo artifact verification (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' demo_artifacts"
    }
}

**# Summary
display as result "Demo QA summary: `pass_count' passed, `fail_count' failed, `skip_count' skipped out of `test_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    capture log close _demoqa
    exit 1
}

capture log close _demoqa

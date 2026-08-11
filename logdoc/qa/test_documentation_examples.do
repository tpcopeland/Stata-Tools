* test_documentation_examples.do - installed-user README/help workflows
* Run: stata-mp -b do test_documentation_examples.do

clear all
set more off
capture log close _all

local qadir = regexr("`c(pwd)'", "/+$", "")
capture confirm file "`qadir'/logdoc.pkg"
if _rc == 0 {
    local pkgdir "`qadir'"
    local qadir "`pkgdir'/qa"
}
else {
    local pkgdir = regexr("`qadir'", "/qa/?$", "")
}
capture confirm file "`pkgdir'/logdoc.pkg"
if _rc {
    display as error "Could not locate logdoc package root from c(pwd)=`c(pwd)'"
    exit 601
}

capture ado uninstall logdoc
net install logdoc, from("`pkgdir'") replace

local test_pass = 0
local test_fail = 0
local test_total = 0
local outdir "`c(tmpdir)'/logdoc_documentation_examples"
capture mkdir "`outdir'"
local oldpwd "`c(pwd)'"

mata:
void _logdoc_docs_file_has(
    string scalar path,
    string scalar needle,
    string scalar result
)
{
    real scalar fh, found
    string scalar line

    found = 0
    fh = fopen(path, "r")
    if (fh < 0) {
        st_local(result, "0")
        return
    }
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (strpos(line, needle) > 0) {
            found = 1
            break
        }
    }
    fclose(fh)
    st_local(result, strofreal(found))
}
end

capture program drop _logdoc_docs_contains
program define _logdoc_docs_contains
    args file needle resultvar
    local found 0
    mata: _logdoc_docs_file_has(st_local("file"), st_local("needle"), "found")
    c_local `resultvar' `found'
end

* Create the input used by the documented workflows.
local smcl "`outdir'/analysis.smcl"
capture cd "`outdir'"
capture log close _all
log using "analysis.smcl", replace smcl name(analysis) nomsg
sysuse auto, clear
summarize price mpg weight
regress price mpg weight
log close analysis
capture cd "`oldpwd'"

* DOC-T1: README Quick Start creates and converts a real SMCL log.
local ++test_total
capture noisily {
    logdoc_py
    logdoc using "`smcl'", output("`outdir'/analysis.html") replace
    _logdoc_docs_contains "`outdir'/analysis.html" "DOCTYPE html" t1_html
    _logdoc_docs_contains "`outdir'/analysis.html" "1978 automobile data" t1_data
    assert `t1_html' & `t1_data'
}
local t1_rc = _rc
if `t1_rc' == 0 {
    display as result "DOC-T1 PASS: Quick Start SMCL-to-HTML workflow"
    local ++test_pass
}
else {
    display as error "DOC-T1 FAIL: Quick Start workflow (rc=`t1_rc')"
    local ++test_fail
}

* DOC-T2: extension detection, format(both), enhancements, and filtering.
local ++test_total
capture noisily {
    logdoc using "`smcl'", output("`outdir'/analysis.md") replace
    logdoc using "`smcl'", output("`outdir'/analysis.html") format(both) replace
    logdoc using "`smcl'", output("`outdir'/analysis_enhanced.html") ///
        legacy toc linenumbers generated replace
    logdoc using "`smcl'", output("`outdir'/regressions.html") ///
        theme(dark) keep("regress|margins") nodots replace
    confirm file "`outdir'/analysis.md"
    confirm file "`outdir'/analysis.html"
    confirm file "`outdir'/analysis_enhanced.html"
    confirm file "`outdir'/regressions.html"
    _logdoc_docs_contains "`outdir'/analysis_enhanced.html" "copy-btn" t2_copy
    _logdoc_docs_contains "`outdir'/analysis_enhanced.html" "Generated" t2_generated
    _logdoc_docs_contains "`outdir'/regressions.html" "regress price mpg weight" t2_regress
    assert `t2_copy' & `t2_generated' & `t2_regress'
}
local t2_rc = _rc
if `t2_rc' == 0 {
    display as result "DOC-T2 PASS: format, enhancement, and filter workflows"
    local ++test_pass
}
else {
    display as error "DOC-T2 FAIL: format/enhancement/filter workflows (rc=`t2_rc')"
    local ++test_fail
}

* DOC-T3: the documented live-session workflow restores and converts cleanly.
local ++test_total
capture noisily {
    logdoc start, output("`outdir'/session.html") theme(dark) notebook replace
    sysuse auto, clear
    summarize price mpg
    regress price mpg weight
    logdoc stop
    local t3_blocks = r(nblocks)
    _logdoc_docs_contains "`outdir'/session.html" "regress price mpg weight" t3_regress
    assert `t3_blocks' > 0 & `t3_regress'
}
local t3_rc = _rc
if `t3_rc' == 0 {
    display as result "DOC-T3 PASS: live session start/stop workflow"
    local ++test_pass
}
else {
    display as error "DOC-T3 FAIL: live session workflow (rc=`t3_rc')"
    capture logdoc stop
    local ++test_fail
}

* DOC-T4: run a do-file and convert its generated SMCL log.
local ++test_total
local run_do "`outdir'/analysis.do"
tempname runfh
file open `runfh' using "`run_do'", write text replace
file write `runfh' "sysuse auto, clear" _n
file write `runfh' "display 114004" _n
file close `runfh'
capture noisily logdoc using "`run_do'", output("`outdir'/run.html") run ///
    stataexe("stata-mp")
local t4_rc = _rc
local t4_found 0
if `t4_rc' == 0 _logdoc_docs_contains "`outdir'/run.html" "114004" t4_found
if `t4_rc' == 0 & `t4_found' {
    display as result "DOC-T4 PASS: run/stataexe workflow"
    local ++test_pass
}
else {
    display as error "DOC-T4 FAIL: run/stataexe workflow (rc=`t4_rc')"
    local ++test_fail
}

* Prepare the files used by the documented batch/combine/diff examples.
local logdir "`outdir'/logs"
local reportdir "`outdir'/reports"
capture mkdir "`logdir'"
capture mkdir "`reportdir'"
copy "`smcl'" "`logdir'/setup.smcl", replace
copy "`smcl'" "`logdir'/models.smcl", replace
copy "`smcl'" "`logdir'/new.smcl", replace

* DOC-T5: batch, combine, and diff workflows produce content-bearing output.
local ++test_total
capture noisily {
    logdoc batch, input("`logdir'/*.smcl") outdir("`reportdir'") replace
    logdoc combine using "`logdir'/setup.smcl" "`logdir'/models.smcl", ///
        output("`reportdir'/project.html") toc replace
    logdoc diff using "`logdir'/setup.smcl", compare("`logdir'/new.smcl") ///
        output("`reportdir'/diff.html") replace
    _logdoc_docs_contains "`reportdir'/setup.html" "DOCTYPE html" t5_batch
    _logdoc_docs_contains "`reportdir'/project.html" "Contents" t5_combine
    _logdoc_docs_contains "`reportdir'/diff.html" "diff" t5_diff
    assert `t5_batch' & `t5_combine' & `t5_diff'
}
local t5_rc = _rc
if `t5_rc' == 0 {
    display as result "DOC-T5 PASS: batch/combine/diff workflows"
    local ++test_pass
}
else {
    display as error "DOC-T5 FAIL: batch/combine/diff workflows (rc=`t5_rc')"
    local ++test_fail
}

* DOC-T6: append and replay workflows preserve usable output.
local ++test_total
capture noisily {
    logdoc using "`smcl'", output("`outdir'/project.html") replace
    logdoc using "`logdir'/models.smcl", output("`outdir'/project.html") append
    logdoc using "`smcl'", output("`outdir'/replay.html") ///
        title("Analysis") replace
    logdoc replay, theme(dark)
    _logdoc_docs_contains "`outdir'/project.html" "1978 automobile data" t6_project
    _logdoc_docs_contains "`outdir'/replay.html" "Analysis" t6_replay
    assert `t6_project' & `t6_replay'
}
local t6_rc = _rc
if `t6_rc' == 0 {
    display as result "DOC-T6 PASS: append/replay workflows"
    local ++test_pass
}
else {
    display as error "DOC-T6 FAIL: append/replay workflows (rc=`t6_rc')"
    local ++test_fail
}

* DOC-T7: Python diagnostics and dry-run installation example.
local ++test_total
capture noisily {
    logdoc_py
    assert r(ok) == 1
    logdoc_py, install(jinja2) dryrun
    assert strpos(r(install_cmd), ///
        "-m pip install " + char(34) + "jinja2" + char(34)) > 0
}
local t7_rc = _rc
if `t7_rc' == 0 {
    display as result "DOC-T7 PASS: Python diagnostic/install workflow"
    local ++test_pass
}
else {
    display as error "DOC-T7 FAIL: Python diagnostic/install workflow (rc=`t7_rc')"
    local ++test_fail
}

capture cd "`oldpwd'"
display as result "RESULT: test_documentation_examples tests=`test_total' pass=`test_pass' fail=`test_fail'"
if `test_fail' > 0 exit 9

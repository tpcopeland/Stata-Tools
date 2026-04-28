* Phase 7-8 feature tests for logdoc v1.4.2
* Tests: P78-T1 through P78-T15
clear all
set more off

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
quietly net install logdoc, from("`pkgdir'") replace

local test_pass = 0
local test_fail = 0
local test_total = 0

* Create test output directory
local outdir "`c(tmpdir)'/logdoc_p78_tests"
capture mkdir "`outdir'"

* Create a minimal SMCL fixture for testing
local smcl_fixture "`outdir'/test_input.smcl"
tempname fh
file open `fh' using "`smcl_fixture'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{com}. sysuse auto, clear" _n
file write `fh' "{txt}(1978 automobile data)" _n
file write `fh' "{com}. summarize price" _n
file write `fh' "{txt}" _n
file write `fh' "    Variable {c |}        Obs        Mean    Std. dev.       Min        Max" _n
file write `fh' "{hline 13}{c +}{hline 57}" _n
file write `fh' "       price {c |}         74    6165.257    2949.496       3291      15906" _n
file write `fh' "{hline 13}{c BT}{hline 57}" _n
file write `fh' "{com}. regress price mpg weight" _n
file write `fh' "{txt}      Source {c |}       SS           df       MS" _n
file write `fh' "{hline 13}{c +}{hline 34}" _n
file write `fh' "       Model {c |}   1.4e+08         2   70144555" _n
file write `fh' "    Residual {c |}   4.9e+08        71    6890071" _n
file write `fh' "{hline 13}{c +}{hline 34}" _n
file write `fh' "       Total {c |}   6.3e+08        73    8699526" _n
file write `fh' "{hline 13}{c BT}{hline 34}" _n
file write `fh' "" _n
file write `fh' "{com}. display 2+2" _n
file write `fh' "{res}4" _n
file write `fh' "{com}. * end of test" _n
file close `fh'

* Create a second SMCL for batch/diff testing
local smcl_fixture2 "`outdir'/test_input2.smcl"
tempname fh2
file open `fh2' using "`smcl_fixture2'", write text replace
file write `fh2' "{smcl}" _n
file write `fh2' "{com}. display 1+1" _n
file write `fh2' "{res}2" _n
file write `fh2' "{com}. display 3+3" _n
file write `fh2' "{res}6" _n
file close `fh2'

* Create annotation file for C7 test
local annot_file "`outdir'/test_annotations.txt"
tempname fh3
file open `fh3' using "`annot_file'", write text replace
file write `fh3' `"@block 1: This is a note about the first command"' _n
file write `fh3' `"@command "regress": Regression command detected"' _n
file close `fh3'


* =========================================================================
* P78-T1: Notebook mode produces notebook-cell divs
* =========================================================================
local test_total = `test_total' + 1
local t1_out "`outdir'/t1_notebook.html"
capture erase "`t1_out'"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t1_out'") notebook replace quiet
}
if _rc == 0 {
    * Check for notebook-cell class in output
    tempfile grepout
    shell grep -c "notebook-cell" "`t1_out'" > "`grepout'" 2>&1
    tempname gfh
    file open `gfh' using "`grepout'", read text
    file read `gfh' _gline
    file close `gfh'
    local _ncells = real("`_gline'")
    if `_ncells' > 0 {
        display as result "P78-T1 PASS: notebook-cell divs found (`_ncells' occurrences)"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T1 FAIL: no notebook-cell divs in output"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T1 FAIL: logdoc command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T2: logdoc batch converts multiple files
* =========================================================================
local test_total = `test_total' + 1
local batchout "`outdir'/batch_output"
capture mkdir "`batchout'"
capture erase "`batchout'/test_input.html"
capture erase "`batchout'/test_input2.html"
capture noisily {
    logdoc batch, input("`outdir'/*.smcl") outdir("`batchout'") replace quiet
}
if _rc == 0 {
    * Check that both output files were created
    local _both_exist = 0
    capture confirm file "`batchout'/test_input.html"
    if !_rc {
        capture confirm file "`batchout'/test_input2.html"
        if !_rc {
            local _both_exist = 1
        }
    }
    if `_both_exist' {
        display as result "P78-T2 PASS: batch converted both files"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T2 FAIL: not all batch output files created"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T2 FAIL: logdoc batch failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T3: Append option adds content to existing file
* =========================================================================
local test_total = `test_total' + 1
local t3_out "`outdir'/t3_append.html"
capture erase "`t3_out'"
* First conversion
capture noisily {
    logdoc using "`smcl_fixture'", output("`t3_out'") replace quiet
}
if _rc == 0 {
    * Get original file size
    tempfile szout1
    shell wc -c < "`t3_out'" > "`szout1'" 2>&1
    tempname szfh1
    file open `szfh1' using "`szout1'", read text
    file read `szfh1' _sz1
    file close `szfh1'
    local _origsize = real(strtrim("`_sz1'"))

    * Append second file
    capture noisily {
        logdoc using "`smcl_fixture2'", output("`t3_out'") append quiet
    }
    if _rc == 0 {
        * Get new file size — should be larger
        tempfile szout2
        shell wc -c < "`t3_out'" > "`szout2'" 2>&1
        tempname szfh2
        file open `szfh2' using "`szout2'", read text
        file read `szfh2' _sz2
        file close `szfh2'
        local _newsize = real(strtrim("`_sz2'"))
        if `_newsize' > `_origsize' {
            display as result "P78-T3 PASS: appended content is larger (orig=`_origsize' new=`_newsize')"
            local test_pass = `test_pass' + 1
        }
        else {
            display as error "P78-T3 FAIL: file did not grow after append"
            local test_fail = `test_fail' + 1
        }
    }
    else {
        display as error "P78-T3 FAIL: append call failed"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T3 FAIL: initial logdoc call failed"
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T4: Email mode produces no <style> block
* =========================================================================
local test_total = `test_total' + 1
local t4_out "`outdir'/t4_email.html"
capture erase "`t4_out'"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t4_out'") email replace quiet
}
if _rc == 0 {
    * Check that <style> is absent
    tempfile grepout4
    shell grep -c "<style>" "`t4_out'" > "`grepout4'" 2>&1
    tempname gfh4
    file open `gfh4' using "`grepout4'", read text
    file read `gfh4' _gline4
    file close `gfh4'
    local _nstyle = real("`_gline4'")
    * grep -c returns 0 when no match, but also returns exit code 1
    * so _nstyle might be missing. Treat missing or 0 as success
    if `_nstyle' == 0 | `_nstyle' == . {
        * Also verify there IS a style="" attribute somewhere
        tempfile grepout4b
        shell grep -c 'style="' "`t4_out'" > "`grepout4b'" 2>&1
        tempname gfh4b
        file open `gfh4b' using "`grepout4b'", read text
        file read `gfh4b' _gline4b
        file close `gfh4b'
        local _nstyleattr = real("`_gline4b'")
        if `_nstyleattr' > 0 {
            display as result "P78-T4 PASS: no <style> block, has inline style= attributes"
            local test_pass = `test_pass' + 1
        }
        else {
            display as error "P78-T4 FAIL: no <style> and no inline styles found"
            local test_fail = `test_fail' + 1
        }
    }
    else {
        display as error "P78-T4 FAIL: <style> block found in email output"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T4 FAIL: logdoc email command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T5: Annotate mode adds annotation aside elements
* =========================================================================
local test_total = `test_total' + 1
local t5_out "`outdir'/t5_annotate.html"
capture erase "`t5_out'"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t5_out'") ///
        annotate("`annot_file'") replace quiet
}
if _rc == 0 {
    tempfile grepout5
    shell grep -c "annotation" "`t5_out'" > "`grepout5'" 2>&1
    tempname gfh5
    file open `gfh5' using "`grepout5'", read text
    file read `gfh5' _gline5
    file close `gfh5'
    local _nannot = real("`_gline5'")
    if `_nannot' > 0 {
        display as result "P78-T5 PASS: annotation elements found (`_nannot' occurrences)"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T5 FAIL: no annotation elements in output"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T5 FAIL: logdoc annotate command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T6: logdoc diff produces diff output
* =========================================================================
local test_total = `test_total' + 1
local t6_out "`outdir'/t6_diff.html"
capture erase "`t6_out'"
capture noisily {
    logdoc diff using "`smcl_fixture'", compare("`smcl_fixture2'") ///
        output("`t6_out'") replace
}
if _rc == 0 {
    capture confirm file "`t6_out'"
    if !_rc {
        * Check for diff-related content
        tempfile grepout6
        shell grep -c "diff-removed\|diff-added" "`t6_out'" > "`grepout6'" 2>&1
        tempname gfh6
        file open `gfh6' using "`grepout6'", read text
        file read `gfh6' _gline6
        file close `gfh6'
        local _ndiff = real("`_gline6'")
        if `_ndiff' > 0 {
            display as result "P78-T6 PASS: diff output generated with diff markers"
            local test_pass = `test_pass' + 1
        }
        else {
            display as error "P78-T6 FAIL: diff output missing diff markers"
            local test_fail = `test_fail' + 1
        }
    }
    else {
        display as error "P78-T6 FAIL: diff output file not created"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T6 FAIL: logdoc diff command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T7: Replay without prior call -> error 198
* =========================================================================
local test_total = `test_total' + 1
* Clear the replay global to ensure clean state
global LOGDOC_LAST_ARGS ""
global LOGDOC_LAST_INPUT ""
capture noisily {
    logdoc replay
}
if _rc == 198 {
    display as result "P78-T7 PASS: replay without prior call correctly returns error 198"
    local test_pass = `test_pass' + 1
}
else {
    display as error "P78-T7 FAIL: expected rc=198 but got rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T8: Basic HTML still works (regression)
* =========================================================================
local test_total = `test_total' + 1
local t8_out "`outdir'/t8_basic.html"
capture erase "`t8_out'"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t8_out'") ///
        title("Regression Test") replace quiet
}
if _rc == 0 {
    capture confirm file "`t8_out'"
    if !_rc {
        * Verify basic structure
        tempfile grepout8
        shell grep -c "logdoc-body" "`t8_out'" > "`grepout8'" 2>&1
        tempname gfh8
        file open `gfh8' using "`grepout8'", read text
        file read `gfh8' _gline8
        file close `gfh8'
        local _nbody = real("`_gline8'")
        if `_nbody' > 0 {
            display as result "P78-T8 PASS: basic HTML conversion works"
            local test_pass = `test_pass' + 1
        }
        else {
            display as error "P78-T8 FAIL: output missing logdoc-body"
            local test_fail = `test_fail' + 1
        }
    }
    else {
        display as error "P78-T8 FAIL: output file not created"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T8 FAIL: basic logdoc command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T9: Session mode carries annotate() into logdoc stop
* =========================================================================
local test_total = `test_total' + 1
local t9_out "`outdir'/t9_session.html"
local _old_linesize = c(linesize)
capture erase "`t9_out'"
capture noisily {
    set linesize 90
    logdoc start, output("`t9_out'") ///
        title("Session Annotate Test") annotate("`annot_file'") replace quiet
    sysuse auto, clear
    display c(linesize)
    regress price mpg
    logdoc stop
    assert c(linesize) == 90
}
local _t9_rc = _rc
capture set linesize `_old_linesize'
if `_t9_rc' == 0 {
    tempfile grepout9a
    shell grep -c "Session Annotate Test" "`t9_out'" > "`grepout9a'" 2>&1
    tempname gfh9a
    file open `gfh9a' using "`grepout9a'", read text
    file read `gfh9a' _gline9a
    file close `gfh9a'
    local _ntitle = real("`_gline9a'")

    tempfile grepout9b
    shell grep -c "Regression command detected" "`t9_out'" > "`grepout9b'" 2>&1
    tempname gfh9b
    file open `gfh9b' using "`grepout9b'", read text
    file read `gfh9b' _gline9b
    file close `gfh9b'
    local _nannot = real("`_gline9b'")

    tempfile grepout9c
    shell grep -c "255" "`t9_out'" > "`grepout9c'" 2>&1
    tempname gfh9c
    file open `gfh9c' using "`grepout9c'", read text
    file read `gfh9c' _gline9c
    file close `gfh9c'
    local _nlinesize = real("`_gline9c'")

    if `_ntitle' > 0 & `_nannot' > 0 & `_nlinesize' > 0 {
        display as result "P78-T9 PASS: session mode preserved title, annotations, and linesize"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T9 FAIL: session output missing title, annotation, or linesize"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T9 FAIL: session mode command failed with rc=`_t9_rc'"
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T10: Replay preserves metadata while allowing overrides
* =========================================================================
local test_total = `test_total' + 1
local t10_out "`outdir'/t10_replay.html"
capture erase "`t10_out'"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t10_out'") ///
        title("Replay Title") date("2026-04-23") ///
        footer("Replay footer") replace quiet
    logdoc replay, theme(dark)
}
if _rc == 0 {
    tempfile grepout10a
    shell grep -c "Replay Title" "`t10_out'" > "`grepout10a'" 2>&1
    tempname gfh10a
    file open `gfh10a' using "`grepout10a'", read text
    file read `gfh10a' _gline10a
    file close `gfh10a'
    local _ntitle = real("`_gline10a'")

    tempfile grepout10b
    shell grep -c "2026-04-23" "`t10_out'" > "`grepout10b'" 2>&1
    tempname gfh10b
    file open `gfh10b' using "`grepout10b'", read text
    file read `gfh10b' _gline10b
    file close `gfh10b'
    local _ndate = real("`_gline10b'")

    tempfile grepout10c
    shell grep -c "Replay footer" "`t10_out'" > "`grepout10c'" 2>&1
    tempname gfh10c
    file open `gfh10c' using "`grepout10c'", read text
    file read `gfh10c' _gline10c
    file close `gfh10c'
    local _nfooter = real("`_gline10c'")

    tempfile grepout10d
    shell grep -c "#191a1f" "`t10_out'" > "`grepout10d'" 2>&1
    tempname gfh10d
    file open `gfh10d' using "`grepout10d'", read text
    file read `gfh10d' _gline10d
    file close `gfh10d'
    local _ndark = real("`_gline10d'")

    if `_ntitle' > 0 & `_ndate' > 0 & `_nfooter' > 0 & `_ndark' > 0 {
        display as result "P78-T10 PASS: replay preserved metadata and applied override"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T10 FAIL: replay output missing preserved metadata or theme override"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T10 FAIL: replay command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T11: batch format(docx) uses .docx outputs, not mislabeled .html files
* =========================================================================
local test_total = `test_total' + 1
local t11_dir "`outdir'/batch_docx"
capture mkdir "`t11_dir'"
capture erase "`t11_dir'/test_input.docx"
capture erase "`t11_dir'/test_input2.docx"
capture erase "`t11_dir'/test_input.html"
capture erase "`t11_dir'/test_input2.html"
capture noisily {
    logdoc batch, input("`outdir'/*.smcl") outdir("`t11_dir'") ///
        format(docx) replace quiet
}
if _rc == 0 {
    local _docx_ok = 1
    local _html_leak = 0
    capture confirm file "`t11_dir'/test_input.docx"
    if _rc local _docx_ok = 0
    capture confirm file "`t11_dir'/test_input2.docx"
    if _rc local _docx_ok = 0
    capture confirm file "`t11_dir'/test_input.html"
    if !_rc local _html_leak = 1
    capture confirm file "`t11_dir'/test_input2.html"
    if !_rc local _html_leak = 1

    if `_docx_ok' & !`_html_leak' {
        display as result "P78-T11 PASS: batch docx outputs use the correct extension"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T11 FAIL: batch docx output paths are mislabeled"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T11 FAIL: batch docx command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T12: python() accepts executable paths with spaces
* =========================================================================
local test_total = `test_total' + 1
local t12_out "`outdir'/t12_space_python.html"
capture erase "`t12_out'"
local spaced_py_dir "`outdir'/python space/bin"
capture mkdir "`outdir'/python space"
capture mkdir "`spaced_py_dir'"
tempfile pybinout
shell command -v python3 > "`pybinout'" 2>&1
tempname pyfh
file open `pyfh' using "`pybinout'", read text
file read `pyfh' _pybin
file close `pyfh'
local _pybin = strtrim("`_pybin'")
capture erase "`spaced_py_dir'/python3"
shell ln -sf "`_pybin'" "`spaced_py_dir'/python3"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t12_out'") ///
        python("`spaced_py_dir'/python3") replace quiet
}
if _rc == 0 {
    capture confirm file "`t12_out'"
    if !_rc {
        display as result "P78-T12 PASS: python() path with spaces works"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T12 FAIL: output file not created"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T12 FAIL: spaced python path failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T13: Markdown append keeps a single YAML front matter block
* =========================================================================
local test_total = `test_total' + 1
local t13_out "`outdir'/t13_append.md"
capture erase "`t13_out'"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t13_out'") format(md) replace quiet
    logdoc using "`smcl_fixture2'", output("`t13_out'") format(md) append quiet
}
if _rc == 0 {
    tempfile grepout13
    shell grep -c '^title:' "`t13_out'" > "`grepout13'" 2>&1
    tempname gfh13
    file open `gfh13' using "`grepout13'", read text
    file read `gfh13' _gline13
    file close `gfh13'
    local _ntitles = real(strtrim("`_gline13'"))
    if `_ntitles' == 1 {
        display as result "P78-T13 PASS: markdown append preserves one YAML title block"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T13 FAIL: markdown append duplicated YAML front matter"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T13 FAIL: markdown append command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T14: TeX append keeps a single LaTeX document wrapper
* =========================================================================
local test_total = `test_total' + 1
local t14_out "`outdir'/t14_append.tex"
capture erase "`t14_out'"
capture noisily {
    logdoc using "`smcl_fixture'", output("`t14_out'") format(tex) replace quiet
    logdoc using "`smcl_fixture2'", output("`t14_out'") format(tex) append quiet
}
if _rc == 0 {
    tempfile grepout14
    shell grep -c '^\\documentclass' "`t14_out'" > "`grepout14'" 2>&1
    tempname gfh14
    file open `gfh14' using "`grepout14'", read text
    file read `gfh14' _gline14
    file close `gfh14'
    local _ndocclass = real(strtrim("`_gline14'"))
    if `_ndocclass' == 1 {
        display as result "P78-T14 PASS: tex append preserves one document wrapper"
        local test_pass = `test_pass' + 1
    }
    else {
        display as error "P78-T14 FAIL: tex append duplicated the LaTeX preamble"
        local test_fail = `test_fail' + 1
    }
}
else {
    display as error "P78-T14 FAIL: tex append command failed with rc=" _rc
    local test_fail = `test_fail' + 1
}


* =========================================================================
* P78-T15: Missing wkhtmltopdf fails cleanly without writing HTML as .pdf
* =========================================================================
local test_total = `test_total' + 1
local t15_pdf "`outdir'/t15_missing.pdf"
local t15_do "`outdir'/t15_missing_pdf.do"
local t15_sh "`outdir'/t15_missing_pdf.sh"
local t15_stdout "`outdir'/t15_missing_pdf.stdout"
local t15_rcfile "`outdir'/t15_missing_pdf.rc"
local t15_empty_path "`outdir'/t15_empty_path"
capture mkdir "`t15_empty_path'"
capture erase "`t15_pdf'"
capture erase "`t15_do'"
capture erase "`t15_sh'"
capture erase "`t15_stdout'"
capture erase "`t15_rcfile'"

tempname t15dofh
file open `t15dofh' using "`t15_do'", write text replace
file write `t15dofh' "clear all" _n
file write `t15dofh' "set more off" _n
file write `t15dofh' "capture ado uninstall logdoc" _n
file write `t15dofh' `"net install logdoc, from("`pkgdir'") replace"' _n
file write `t15dofh' `"capture erase "`t15_pdf'""' _n
file write `t15dofh' ///
    `"logdoc using "`smcl_fixture'", output("`t15_pdf'") format(pdf) python("/usr/bin/python3") replace"' _n
file write `t15dofh' "exit _rc" _n
file close `t15dofh'

tempname t15shfh
file open `t15shfh' using "`t15_sh'", write text replace
file write `t15shfh' "#!/usr/bin/env bash" _n
file write `t15shfh' "set +e" _n
file write `t15shfh' `"STATA_BIN="$(command -v stata-mp)""' _n
file write `t15shfh' `"env PATH="`t15_empty_path'" "$STATA_BIN" -b do "`t15_do'" > "`t15_stdout'" 2>&1"' _n
file write `t15shfh' `"printf "%s" $? > "`t15_rcfile'""' _n
file close `t15shfh'
shell chmod +x "`t15_sh'"
shell bash "`t15_sh'"

tempname t15rcfh
file open `t15rcfh' using "`t15_rcfile'", read text
file read `t15rcfh' _t15rc
file close `t15rcfh'
local _t15_rc = real(strtrim("`_t15rc'"))
local _t15_pdf_exists = 0
capture confirm file "`t15_pdf'"
if !_rc local _t15_pdf_exists = 1

if `_t15_rc' != 0 & !`_t15_pdf_exists' {
    display as result "P78-T15 PASS: missing wkhtmltopdf stops cleanly without a fake PDF"
    local test_pass = `test_pass' + 1
}
else {
    display as error "P78-T15 FAIL: missing wkhtmltopdf still produced a misleading PDF path"
    local test_fail = `test_fail' + 1
}


* =========================================================================
* Summary
* =========================================================================
* Summary
display as result "Phase 7-8 Test Results: `test_pass'/`test_total' passed, `test_fail' failed"

if `test_fail' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

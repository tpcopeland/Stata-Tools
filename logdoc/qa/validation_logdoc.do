* validation_logdoc.do — Content validation for logdoc package
* Location: ~/Stata-Dev/_devkit/_validation/
* Validates that generated HTML/MD content is correct, not just that files exist.
* Uses shell grep for content checks (avoids Stata file I/O issues with HTML).
* Run: stata-mp -e do validation_logdoc.do

clear all
set more off

capture ado uninstall logdoc
net install logdoc, from("/home/tpcopeland/Stata-Dev/logdoc/") replace

local test_pass = 0
local test_fail = 0
local test_total = 0

local smcl_fixture "/home/tpcopeland/Stata-Tools/iivw/demo/console_output.smcl"
local outdir "/tmp/logdoc_validation"
capture mkdir "`outdir'"

* Helper: check if a pattern exists in a file using Python
* More reliable than grep through Stata shell (avoids backtick issues)
capture program drop _logdoc_grep_check
program define _logdoc_grep_check
    args file pattern resultvar
    tempfile grepout
    shell python3 -c "import re,sys; t=open(sys.argv[1],'r',errors='replace').read(); print(1 if re.search(sys.argv[2],t) else 0)" "`file'" "`pattern'" > "`grepout'" 2>/dev/null || echo "0" > "`grepout'"
    file open gfh using "`grepout'", read text
    file read gfh line
    file close gfh
    local count = real("`line'")
    if `count' == . local count = 0
    c_local `resultvar' = (`count' > 0)
end

* =======================================================================
* V1: HTML contains expected structural elements
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v1.html") replace

    _logdoc_grep_check "`outdir'/v1.html" "DOCTYPE html" has_doctype
    _logdoc_grep_check "`outdir'/v1.html" "code-block" has_code_block
    _logdoc_grep_check "`outdir'/v1.html" "output-block" has_output_block
    _logdoc_grep_check "`outdir'/v1.html" "stata-table" has_table
    _logdoc_grep_check "`outdir'/v1.html" "logdoc-header" has_header
    _logdoc_grep_check "`outdir'/v1.html" "logdoc-footer" has_footer

    assert `has_doctype' == 1
    assert `has_code_block' == 1
    assert `has_output_block' == 1
    assert `has_table' == 1
    assert `has_header' == 1
    assert `has_footer' == 1
}
if _rc == 0 {
    display as result "PASS: V1 - HTML structure validated"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V1 - HTML structure (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V2: HTML contains inlined CSS (self-contained)
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    _logdoc_grep_check "`outdir'/v1.html" "<style>" has_style
    _logdoc_grep_check "`outdir'/v1.html" "max-width" has_maxwidth

    assert `has_style' == 1
    assert `has_maxwidth' == 1
}
if _rc == 0 {
    display as result "PASS: V2 - CSS inlined in HTML"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V2 - CSS inlined (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V3: Dark theme uses Catppuccin dark background color
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v3_dark.html") ///
        theme(dark) replace

    _logdoc_grep_check "`outdir'/v3_dark.html" "#1e1e2e" has_dark_bg
    assert `has_dark_bg' == 1
}
if _rc == 0 {
    display as result "PASS: V3 - Dark theme applied"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V3 - Dark theme (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V4: Preformatted mode skips HTML tables
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v4_pre.html") ///
        preformatted replace

    * Check for actual <table> elements (not CSS class names)
    _logdoc_grep_check "`outdir'/v4_pre.html" "<table " has_table
    assert `has_table' == 0
}
if _rc == 0 {
    display as result "PASS: V4 - Preformatted skips HTML tables"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V4 - Preformatted (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V5: Nofold disables collapsible sections
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v5_nofold.html") ///
        nofold replace

    _logdoc_grep_check "`outdir'/v5_nofold.html" "<details" has_details
    assert `has_details' == 0
}
if _rc == 0 {
    display as result "PASS: V5 - Nofold disables collapsible sections"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V5 - Nofold (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V6: Markdown has YAML front matter with title
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v6.md") ///
        format(md) title("Test Title") replace

    _logdoc_grep_check "`outdir'/v6.md" "^---" has_yaml
    _logdoc_grep_check "`outdir'/v6.md" "Test Title" has_title
    assert `has_yaml' == 1
    assert `has_title' == 1
}
if _rc == 0 {
    display as result "PASS: V6 - Markdown YAML front matter"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V6 - Markdown YAML (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V7: Markdown contains stata code blocks
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    _logdoc_grep_check "`outdir'/v6.md" "stata" has_stata_block
    assert `has_stata_block' == 1
}
if _rc == 0 {
    display as result "PASS: V7 - Markdown stata code blocks"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V7 - Markdown code blocks (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V8: HTML title matches option
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v8.html") ///
        title("My Analysis Report") replace

    _logdoc_grep_check "`outdir'/v8.html" "My Analysis Report" has_title
    assert `has_title' == 1
}
if _rc == 0 {
    display as result "PASS: V8 - HTML title from option"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V8 - HTML title (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V9: No log metadata in output
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    _logdoc_grep_check "`outdir'/v1.html" "opened on:" has_opened
    _logdoc_grep_check "`outdir'/v1.html" "closed on:" has_closed
    assert `has_opened' == 0
    assert `has_closed' == 0
}
if _rc == 0 {
    display as result "PASS: V9 - Log metadata stripped"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V9 - Log metadata present (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V10: SMCL tags fully stripped in output
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    _logdoc_grep_check "`outdir'/v1.html" "{com}" has_com
    _logdoc_grep_check "`outdir'/v1.html" "{txt}" has_txt
    _logdoc_grep_check "`outdir'/v1.html" "{c TT}" has_ctt
    assert `has_com' == 0
    assert `has_txt' == 0
    assert `has_ctt' == 0
}
if _rc == 0 {
    display as result "PASS: V10 - SMCL tags fully expanded"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V10 - Raw SMCL tags in output (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V11: Format both produces non-empty files
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v11.html") ///
        format(both) replace
    confirm file "`outdir'/v11.html"
    confirm file "`outdir'/v11.md"

    * Check both are non-trivially sized (>500 bytes)
    shell wc -c < "`outdir'/v11.html" > "`outdir'/_sz_html.txt"
    shell wc -c < "`outdir'/v11.md" > "`outdir'/_sz_md.txt"

    file open szfh using "`outdir'/_sz_html.txt", read text
    file read szfh htmlsz
    file close szfh
    local htmlsz = real(trim("`htmlsz'"))
    assert `htmlsz' > 500

    file open szfh using "`outdir'/_sz_md.txt", read text
    file read szfh mdsz
    file close szfh
    local mdsz = real(trim("`mdsz'"))
    assert `mdsz' > 100
}
if _rc == 0 {
    display as result "PASS: V11 - Format both produces content"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V11 - Format both (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V12: Box-drawing characters rendered in preformatted mode
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    * Preformatted mode preserves box-drawing chars (not converted to HTML tables)
    logdoc using "`smcl_fixture'", output("`outdir'/v12_pre.html") ///
        preformatted replace
    _logdoc_grep_check "`outdir'/v12_pre.html" "─" has_hline
    assert `has_hline' == 1
}
if _rc == 0 {
    display as result "PASS: V12 - Box-drawing characters rendered"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V12 - Box drawing (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V13: Nested SMCL tags expanded correctly
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    * {ralign 78:(Std. err. adjusted for {res:200} clusters in {res:patid})}
    _logdoc_grep_check "`outdir'/v1.html" "200.*clusters" has_nested
    assert `has_nested' == 1
}
if _rc == 0 {
    display as result "PASS: V13 - Nested SMCL tags expanded"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V13 - Nested tags (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V14: Nodots strips dot prompts from HTML
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v14_nodots.html") ///
        nodots replace

    * Commands should NOT start with ". " in nodots mode
    * Check that code blocks exist but don't have dot prompts
    _logdoc_grep_check "`outdir'/v14_nodots.html" "code-block" has_code
    assert `has_code' == 1

    * The dot prompt ". summarize" or ". regress" should not appear
    * But the command word itself should still be there
    _logdoc_grep_check "`outdir'/v14_nodots.html" ">\\. " has_dot_prompt
    assert `has_dot_prompt' == 0
}
if _rc == 0 {
    display as result "PASS: V14 - Nodots strips dot prompts"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V14 - Nodots (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V15: Date subtitle appears in HTML
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v15_date.html") ///
        date("March 2026") replace

    _logdoc_grep_check "`outdir'/v15_date.html" "March 2026" has_date
    _logdoc_grep_check "`outdir'/v15_date.html" "subtitle" has_subtitle
    assert `has_date' == 1
    assert `has_subtitle' == 1
}
if _rc == 0 {
    display as result "PASS: V15 - Date subtitle in HTML"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V15 - Date subtitle (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V16: Generation timestamp in footer
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    _logdoc_grep_check "`outdir'/v15_date.html" "middot" has_timestamp
    assert `has_timestamp' == 1
}
if _rc == 0 {
    display as result "PASS: V16 - Generation timestamp in footer"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V16 - Timestamp (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V17: Copy button in HTML code blocks
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    _logdoc_grep_check "`outdir'/v1.html" "copy-btn" has_copybtn
    _logdoc_grep_check "`outdir'/v1.html" "clipboard" has_clipboard
    assert `has_copybtn' == 1
    assert `has_clipboard' == 1
}
if _rc == 0 {
    display as result "PASS: V17 - Copy button in code blocks"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V17 - Copy button (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V18: Print CSS present in HTML
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    _logdoc_grep_check "`outdir'/v1.html" "@media print" has_print
    assert `has_print' == 1
}
if _rc == 0 {
    display as result "PASS: V18 - Print CSS present"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V18 - Print CSS (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V19: Markdown date in YAML front matter
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    logdoc using "`smcl_fixture'", output("`outdir'/v19.md") ///
        format(md) date("2026-03-15") replace

    _logdoc_grep_check "`outdir'/v19.md" "date:" has_yaml_date
    _logdoc_grep_check "`outdir'/v19.md" "2026-03-15" has_date_val
    assert `has_yaml_date' == 1
    assert `has_date_val' == 1
}
if _rc == 0 {
    display as result "PASS: V19 - Markdown date in YAML"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V19 - Markdown date (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V20: No empty output blocks in HTML
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    * Check that there are no output blocks with only empty spans
    * Pattern: output-block containing only whitespace and span tags
    _logdoc_grep_check "`outdir'/v1.html" "output-block.*><pre><span[^>]*></span></pre>" has_empty
    assert `has_empty' == 0
}
if _rc == 0 {
    display as result "PASS: V20 - No empty output blocks"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V20 - Empty output blocks (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* V21: Comment lines not detected as graph exports
* =======================================================================
local test_total = `test_total' + 1
capture noisily {
    * Create a SMCL with a comment containing "graph export" text
    local testsmcl "`outdir'/_test_comment.smcl"
    file open fh using "`testsmcl'", write replace
    file write fh "{smcl}" _n
    file write fh "{com}. * This is about graph export usage" _n
    file write fh "{com}. sysuse auto, clear" _n
    file write fh "{txt}(1978 automobile data)" _n
    file close fh

    logdoc using "`testsmcl'", output("`outdir'/_test_comment.html") replace
    * Should have NO graph-missing divs (the comment should not trigger graph detection)
    _logdoc_grep_check "`outdir'/_test_comment.html" "<div class=.graph-missing.>" has_graph_err
    assert `has_graph_err' == 0
}
if _rc == 0 {
    display as result "PASS: V21 - Comment not detected as graph export"
    local test_pass = `test_pass' + 1
}
else {
    display as error "FAIL: V21 - Comment graph detection (rc = " _rc ")"
    local test_fail = `test_fail' + 1
}

* =======================================================================
* RESULTS
* =======================================================================
display ""
display as text "RESULT: `test_pass'/`test_total' validation tests passed, `test_fail' failed"
if `test_fail' > 0 {
    display as error "SOME VALIDATION TESTS FAILED"
    exit 9
}
else {
    display as result "ALL VALIDATION TESTS PASSED"
}

* test_logdoc_v115.do - regression coverage for the 1.1.5 review fixes
* Run: stata-mp -b do test_logdoc_v115.do

version 16.0
clear all
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
quietly net install logdoc, from("`pkgdir'") replace
quietly logdoc_py
local python `"`r(python)'"'
local renderer `"`r(renderer)'"'

local test_pass = 0
local test_fail = 0
local test_total = 0
local outdir "`c(tmpdir)'/logdoc_v115_tests"
capture mkdir "`outdir'"

mata:
void _logdoc_v115_file_count(
    string scalar path,
    string scalar needle,
    string scalar result
)
{
    real scalar fh, count, pos, hit
    string scalar line, tail

    count = 0
    fh = fopen(path, "r")
    if (fh < 0) {
        st_local(result, "0")
        return
    }
    while ((line = fget(fh)) != J(0, 0, "")) {
        pos = 1
        while (pos <= strlen(line)) {
            tail = substr(line, pos, .)
            hit = strpos(tail, needle)
            if (hit == 0) break
            count = count + 1
            pos = pos + hit + strlen(needle) - 1
        }
    }
    fclose(fh)
    st_local(result, strofreal(count))
}
end

capture program drop _logdoc_v115_count
program define _logdoc_v115_count
    args file needle resultvar
    local count 0
    mata: _logdoc_v115_file_count(st_local("file"), st_local("needle"), "count")
    c_local `resultvar' `count'
end

capture program drop _logdoc_v115_first_line
program define _logdoc_v115_first_line
    args file resultvar
    local line ""
    tempname fh
    capture file open `fh' using "`file'", read text
    if _rc == 0 {
        file read `fh' line
        file close `fh'
    }
    c_local `resultvar' `"`line'"'
end

tempname fh
local fixture "`outdir'/fixture.smcl"
file open `fh' using "`fixture'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{com}. display 115000" _n
file write `fh' "{res}115000" _n
file close `fh'

**# User-data and execution safety

* V115-T1: output() must never overwrite the input source.
local ++test_total
local samepath "`outdir'/same_source.smcl"
file open `fh' using "`samepath'", write text replace
file write `fh' "{smcl}" _n "{txt}SOURCE_SENTINEL" _n
file close `fh'
capture noisily logdoc using "`samepath'", output("`samepath'") ///
    format(html) replace quiet
local t1_rc = _rc
_logdoc_v115_count "`samepath'" "SOURCE_SENTINEL" t1_source
if `t1_rc' == 198 & `t1_source' == 1 {
    display as result "V115-T1 PASS: same-path output rejected without changing source"
    local ++test_pass
}
else {
    display as error "V115-T1 FAIL: same-path guard (rc=`t1_rc', sentinel=`t1_source')"
    local ++test_fail
}

* V115-T2: run propagates the child do-file's exact failure code.
local ++test_total
local child_do "`outdir'/child_failure.do"
local child_out "`outdir'/child_failure.html"
capture erase "`child_out'"
file open `fh' using "`child_do'", write text replace
file write `fh' "display 115002" _n
file write `fh' "error 459" _n
file close `fh'
capture noisily logdoc using "`child_do'", output("`child_out'") run quiet
local t2_rc = _rc
capture confirm file "`child_out'"
local t2_output = (_rc == 0)
if `t2_rc' == 459 & !`t2_output' {
    display as result "V115-T2 PASS: child do-file failure is propagated"
    local ++test_pass
}
else {
    display as error "V115-T2 FAIL: child failure (rc=`t2_rc', output=`t2_output')"
    local ++test_fail
}

* V115-T3: appending to foreign HTML must fail without corrupting it.
local ++test_total
local foreign_html "`outdir'/foreign.html"
file open `fh' using "`foreign_html'", write text replace
file write `fh' "<html><body>OWNER_SENTINEL</body></html>" _n
file close `fh'
capture noisily logdoc using "`fixture'", output("`foreign_html'") append quiet
local t3_rc = _rc
_logdoc_v115_count "`foreign_html'" "OWNER_SENTINEL" t3_owner
_logdoc_v115_count "`foreign_html'" "<!DOCTYPE html>" t3_doctype
if `t3_rc' != 0 & `t3_owner' == 1 & `t3_doctype' == 0 {
    display as result "V115-T3 PASS: foreign HTML append rejected without mutation"
    local ++test_pass
}
else {
    display as error "V115-T3 FAIL: foreign append (rc=`t3_rc', owner=`t3_owner', doctype=`t3_doctype')"
    local ++test_fail
}

**# HTML and renderer fidelity

* V115-T4: every notebook cell is closed, including adjacent commands.
local ++test_total
local notebook_smcl "`outdir'/notebook_adjacent.smcl"
local notebook_html "`outdir'/notebook_adjacent.html"
local notebook_py "`outdir'/check_notebook.py"
local notebook_result "`outdir'/check_notebook.txt"
file open `fh' using "`notebook_smcl'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{com}. display 1" _n
file write `fh' "{com}. display 2" _n
file close `fh'
capture noisily logdoc using "`notebook_smcl'", ///
    output("`notebook_html'") notebook replace quiet
local t4_rc = _rc
local t4_open 0
local t4_close 0
if `t4_rc' == 0 {
    file open `fh' using "`notebook_py'", write text replace
    file write `fh' "import sys" _n
    file write `fh' "text = open(sys.argv[1], encoding='utf-8').read()" _n
    file write `fh' `"print(text.count('<div class=\"notebook-cell\">'), text.count('</div><!-- /notebook-cell -->'))"' _n
    file close `fh'
    shell "`python'" "`notebook_py'" "`notebook_html'" > "`notebook_result'" 2>&1
    _logdoc_v115_first_line "`notebook_result'" t4_counts
    tokenize "`t4_counts'"
    local t4_open "`1'"
    local t4_close "`2'"
}
if `t4_rc' == 0 & `t4_open' == 2 & `t4_close' == 2 {
    display as result "V115-T4 PASS: adjacent notebook cells are balanced"
    local ++test_pass
}
else {
    display as error "V115-T4 FAIL: notebook balance (rc=`t4_rc', open=`t4_open', close=`t4_close')"
    local ++test_fail
}

* V115-T5: a quoted title cannot create an extra HTML event attribute.
local ++test_total
local attrs_html "`outdir'/download_attrs.html"
local attrs_py "`outdir'/check_attrs.py"
local attrs_result "`outdir'/check_attrs.txt"
local attrs_title "`outdir'/download_title.txt"
local evil_title = "Report" + char(34) + " onmouseover=" + char(34) + "alert(1)"
file open `fh' using "`attrs_title'", write text replace
file write `fh' `"`evil_title'"'
file close `fh'
file open `fh' using "`attrs_py'", write text replace
file write `fh' "import sys" _n
file write `fh' "from html.parser import HTMLParser" _n
file write `fh' "class P(HTMLParser):" _n
file write `fh' "    def __init__(self):" _n
file write `fh' "        super().__init__(); self.bad = 0" _n
file write `fh' "    def handle_starttag(self, tag, attrs):" _n
file write `fh' "        if tag == 'button' and any(k not in ('class', 'onclick') for k, _ in attrs):" _n
file write `fh' "            self.bad += 1" _n
file write `fh' "p = P()" _n
file write `fh' "p.feed(open(sys.argv[1], encoding='utf-8').read())" _n
file write `fh' "print(p.bad)" _n
file close `fh'
capture erase "`attrs_html'"
shell "`python'" "`renderer'" "`fixture'" "`attrs_html'" ///
    --title-file "`attrs_title'" --download > "`outdir'/download_attrs.log" 2>&1
capture confirm file "`attrs_html'"
local t5_rc = _rc
capture erase "`attrs_result'"
if `t5_rc' == 0 {
    shell "`python'" "`attrs_py'" "`attrs_html'" > "`attrs_result'" 2>&1
}
_logdoc_v115_first_line "`attrs_result'" t5_bad
if `t5_rc' == 0 & strtrim("`t5_bad'") == "0" {
    display as result "V115-T5 PASS: download title stays inside onclick"
    local ++test_pass
}
else {
    display as error "V115-T5 FAIL: injected button attributes (rc=`t5_rc', bad=`t5_bad')"
    local ++test_fail
}

* V115-T6: parsed HTML tables preserve an empty middle cell.
local ++test_total
local table_smcl "`outdir'/empty_cell.smcl"
local table_html "`outdir'/empty_cell.html"
file open `fh' using "`table_smcl'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{txt}{hline 4}{c TT}{hline 4}{c TT}{hline 4}" _n
file write `fh' "{txt}A{col 6}{c |}B{col 11}{c |}C" _n
file write `fh' "{txt}{hline 4}{c +}{hline 4}{c +}{hline 4}" _n
file write `fh' "{txt}x{col 6}{c |}{col 11}{c |}z" _n
file write `fh' "{txt}{hline 4}{c BT}{hline 4}{c BT}{hline 4}" _n
file close `fh'
capture noisily logdoc using "`table_smcl'", output("`table_html'") ///
    tables replace quiet
local t6_rc = _rc
local t6_cells 0
if `t6_rc' == 0 _logdoc_v115_count "`table_html'" "<td" t6_cells
if `t6_rc' == 0 & `t6_cells' == 3 {
    display as result "V115-T6 PASS: parsed table preserves blank middle cell"
    local ++test_pass
}
else {
    display as error "V115-T6 FAIL: parsed table cells (rc=`t6_rc', cells=`t6_cells')"
    local ++test_fail
}

* V115-T7: repeated graph exports are counted and embedded independently.
local ++test_total
local graph_smcl "`outdir'/duplicate_graph.smcl"
local graph_file "`outdir'/duplicate.png"
local graph_html "`outdir'/duplicate_graph.html"
file open `fh' using "`graph_file'", write text replace
file write `fh' "image-bytes" _n
file close `fh'
file open `fh' using "`graph_smcl'", write text replace
file write `fh' "{smcl}" _n
file write `fh' "{com}. graph export duplicate.png, replace" _n
file write `fh' "{com}. graph export duplicate.png, replace" _n
file close `fh'
capture noisily logdoc using "`graph_smcl'", output("`graph_html'") replace quiet
local t7_rc = _rc
local t7_graphs = -1
local t7_embeds 0
if `t7_rc' == 0 {
    local t7_graphs = r(ngraphs)
    _logdoc_v115_count "`graph_html'" "data:image/png;base64" t7_embeds
}
if `t7_rc' == 0 & `t7_graphs' == 2 & `t7_embeds' == 2 {
    display as result "V115-T7 PASS: duplicate graph exports remain distinct"
    local ++test_pass
}
else {
    display as error "V115-T7 FAIL: duplicate graphs (rc=`t7_rc', r(ngraphs)=`t7_graphs', embeds=`t7_embeds')"
    local ++test_fail
}

* V115-T8: HTML append preserves the original custom footer.
local ++test_total
local footer_html "`outdir'/footer_append.html"
capture noisily logdoc using "`fixture'", output("`footer_html'") ///
    footer("OWNER_FOOTER") replace quiet
local t8_first_rc = _rc
if `t8_first_rc' == 0 {
    capture noisily logdoc using "`fixture'", output("`footer_html'") append quiet
}
local t8_rc = _rc
_logdoc_v115_count "`footer_html'" "OWNER_FOOTER" t8_owner
_logdoc_v115_count "`footer_html'" "<p>Generated " t8_generated
if `t8_first_rc' == 0 & `t8_rc' == 0 & `t8_owner' == 1 & `t8_generated' == 0 {
    display as result "V115-T8 PASS: append preserves custom footer"
    local ++test_pass
}
else {
    display as error "V115-T8 FAIL: append footer (first=`t8_first_rc', rc=`t8_rc', owner=`t8_owner', generated=`t8_generated')"
    local ++test_fail
}

* V115-T9: multiline metadata stays on one physical YAML line.
local ++test_total
local title_file "`outdir'/multiline_title.txt"
local yaml_out "`outdir'/multiline.md"
local yaml_log "`outdir'/multiline.log"
file open `fh' using "`title_file'", write text replace
file write `fh' "good" _n "injected: true" _n
file close `fh'
capture erase "`yaml_out'"
shell "`python'" "`renderer'" "`fixture'" "`yaml_out'" ///
    --format md --title-file "`title_file'" > "`yaml_log'" 2>&1
local t9_line3 ""
capture file open `fh' using "`yaml_out'", read text
if _rc == 0 {
    file read `fh' t9_line1
    file read `fh' t9_line2
    file read `fh' t9_line3
    file close `fh'
}
if strtrim(`"`t9_line3'"') == "---" {
    display as result "V115-T9 PASS: multiline YAML metadata is escaped"
    local ++test_pass
}
else {
    display as error `"V115-T9 FAIL: third YAML line is `t9_line3'"'
    local ++test_fail
}

**# Failure atomicity and direct-renderer validation

* V115-T10: a failed xhtml2pdf conversion leaves no partial PDF.
local ++test_total
local fake_dir "`outdir'/fake_xhtml2pdf"
capture mkdir "`fake_dir'"
local fake_module "`fake_dir'/xhtml2pdf.py"
local pdf_check "`outdir'/check_pdf_atomic.py"
local pdf_html "`outdir'/pdf_input.html"
local pdf_out "`outdir'/partial.pdf"
local pdf_result "`outdir'/pdf_atomic.txt"
file open `fh' using "`fake_module'", write text replace
file write `fh' "class _Status:" _n "    err = 1" _n
file write `fh' "class _Pisa:" _n "    @staticmethod" _n
file write `fh' "    def CreatePDF(html, dest):" _n
file write `fh' "        dest.write(b'PARTIAL')" _n
file write `fh' "        return _Status()" _n
file write `fh' "pisa = _Pisa()" _n
file close `fh'
file open `fh' using "`pdf_html'", write text replace
file write `fh' "<html><body>test</body></html>" _n
file close `fh'
file open `fh' using "`pdf_check'", write text replace
file write `fh' "import importlib.util, os, sys" _n
file write `fh' "sys.path.insert(0, sys.argv[1])" _n
file write `fh' "spec = importlib.util.spec_from_file_location('lr', sys.argv[2])" _n
file write `fh' "mod = importlib.util.module_from_spec(spec)" _n
file write `fh' "spec.loader.exec_module(mod)" _n
file write `fh' "try:" _n "    mod.convert_html_to_pdf(sys.argv[3], sys.argv[4])" _n
file write `fh' "except RuntimeError:" _n "    pass" _n
file write `fh' "print(0 if os.path.exists(sys.argv[4]) else 1)" _n
file close `fh'
capture erase "`pdf_out'"
capture erase "`pdf_result'"
shell "`python'" "`pdf_check'" "`fake_dir'" "`renderer'" ///
    "`pdf_html'" "`pdf_out'" > "`pdf_result'" 2>&1
_logdoc_v115_first_line "`pdf_result'" t10_atomic
if strtrim("`t10_atomic'") == "1" {
    display as result "V115-T10 PASS: failed PDF conversion is atomic"
    local ++test_pass
}
else {
    display as error "V115-T10 FAIL: partial PDF remains (`t10_atomic')"
    local ++test_fail
}

* V115-T11: direct renderer rejects nonnumeric graph dimensions.
local ++test_total
local bad_dim_out "`outdir'/bad_dimension.html"
local bad_dim_log "`outdir'/bad_dimension.log"
capture erase "`bad_dim_out'"
shell "`python'" "`renderer'" "`fixture'" "`bad_dim_out'" ///
    --graphwidth not-a-number > "`bad_dim_log'" 2>&1
capture confirm file "`bad_dim_out'"
local t11_created = (_rc == 0)
if !`t11_created' {
    display as result "V115-T11 PASS: invalid direct-renderer dimension rejected"
    local ++test_pass
}
else {
    display as error "V115-T11 FAIL: invalid dimension produced output"
    local ++test_fail
}

* V115-T12: direct renderer rejects missing CSS and annotation files.
local ++test_total
local missing_css_out "`outdir'/missing_css.html"
local missing_ann_out "`outdir'/missing_annotation.html"
local direct_log "`outdir'/missing_assets.log"
capture erase "`missing_css_out'"
capture erase "`missing_ann_out'"
shell "`python'" "`renderer'" "`fixture'" "`missing_css_out'" ///
    --css "`outdir'/does_not_exist.css" > "`direct_log'" 2>&1
shell "`python'" "`renderer'" "`fixture'" "`missing_ann_out'" ///
    --annotate "`outdir'/does_not_exist.txt" >> "`direct_log'" 2>&1
capture confirm file "`missing_css_out'"
local t12_css = (_rc == 0)
capture confirm file "`missing_ann_out'"
local t12_ann = (_rc == 0)
if !`t12_css' & !`t12_ann' {
    display as result "V115-T12 PASS: missing direct-renderer assets rejected"
    local ++test_pass
}
else {
    display as error "V115-T12 FAIL: missing assets produced output (css=`t12_css', annotate=`t12_ann')"
    local ++test_fail
}

**# Command and release-surface contracts

* V115-T13: pip package tokens are individually quoted against glob expansion.
local ++test_total
capture noisily logdoc_py, install(*) dryrun quiet
local t13_rc = _rc
local t13_cmd ""
if `t13_rc' == 0 local t13_cmd `"`r(install_cmd)'"'
local t13_quoted = 0
if `t13_rc' == 0 {
    local t13_quoted = (strpos(`"`t13_cmd'"', char(34) + "*" + char(34)) > 0)
}
if `t13_rc' == 0 & `t13_quoted' {
    display as result "V115-T13 PASS: pip package token is shell-quoted"
    local ++test_pass
}
else {
    display as error `"V115-T13 FAIL: install command is `t13_cmd'"'
    local ++test_fail
}

* V115-T14: the direct renderer also preserves a same-path input.
local ++test_total
local direct_same "`outdir'/direct_same.smcl"
local direct_same_log "`outdir'/direct_same.log"
file open `fh' using "`direct_same'", write text replace
file write `fh' "{smcl}" _n "{txt}DIRECT_SOURCE_SENTINEL" _n
file close `fh'
shell "`python'" "`renderer'" "`direct_same'" "`direct_same'" ///
    > "`direct_same_log'" 2>&1
_logdoc_v115_first_line "`direct_same'" t14_first
if strtrim("`t14_first'") == "{smcl}" {
    display as result "V115-T14 PASS: direct same-path input is preserved"
    local ++test_pass
}
else {
    display as error "V115-T14 FAIL: direct same-path input was overwritten"
    local ++test_fail
}

* V115-T15: the dialog exposes stataexe() when run is selected.
local ++test_total
_logdoc_v115_count "`pkgdir'/logdoc.dlg" "ed_stataexe" t15_control
_logdoc_v115_count "`pkgdir'/logdoc.dlg" "stataexe(" t15_builder
if `t15_control' > 0 & `t15_builder' > 0 {
    display as result "V115-T15 PASS: dialog exposes stataexe()"
    local ++test_pass
}
else {
    display as error "V115-T15 FAIL: dialog stataexe surface missing"
    local ++test_fail
}

* V115-T16: the PDF fallback uses the Windows executable locator.
local ++test_total
_logdoc_v115_count "`pkgdir'/logdoc.ado" "where wkhtmltopdf" t16_where
if `t16_where' > 0 {
    display as result "V115-T16 PASS: Windows wkhtmltopdf lookup is implemented"
    local ++test_pass
}
else {
    display as error "V115-T16 FAIL: Windows wkhtmltopdf lookup missing"
    local ++test_fail
}

* V115-T17: combine and diff reject output aliases before mutating sources.
local ++test_total
local combine_a "`outdir'/combine_collision_a.smcl"
local combine_b "`outdir'/combine_collision_b.smcl"
local diff_a "`outdir'/diff_collision_a.smcl"
local diff_b "`outdir'/diff_collision_b.smcl"
foreach target in combine_a combine_b diff_a diff_b {
    file open `fh' using "``target''", write text replace
    file write `fh' "{smcl}" _n "{txt}COLLISION_SENTINEL" _n
    file close `fh'
}
capture noisily logdoc combine using "`combine_a'" "`combine_b'", ///
    output("`combine_a'") replace quiet
local t17_combine_rc = _rc
capture noisily logdoc diff using "`diff_a'", compare("`diff_b'") ///
    output("`diff_a'") replace quiet
local t17_diff_rc = _rc
_logdoc_v115_first_line "`combine_a'" t17_combine_first
_logdoc_v115_first_line "`diff_a'" t17_diff_first
if `t17_combine_rc' == 198 & `t17_diff_rc' == 198 & ///
    strtrim("`t17_combine_first'") == "{smcl}" & ///
    strtrim("`t17_diff_first'") == "{smcl}" {
    display as result "V115-T17 PASS: combine/diff source aliases rejected"
    local ++test_pass
}
else {
    display as error "V115-T17 FAIL: combine/diff collision guards"
    local ++test_fail
}

display as result "RESULT: test_logdoc_v115 tests=`test_total' pass=`test_pass' fail=`test_fail'"
if `test_fail' > 0 exit 9

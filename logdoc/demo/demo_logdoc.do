/*  demo_logdoc.do - Generate demonstration outputs for logdoc

    Exercises all logdoc options with consolidated examples. Outputs:
      Source:    sample_analysis.smcl, sample_followup.smcl, residuals.png,
                 followup_scatter.png
      HTML:      sample_light, sample_dark, sample_enhanced, sample_notebook,
                 sample_nograph, sample_email, sample_filtered, sample_drop,
                 sample_annotated, run_output, sample_both, sample_append,
                 sample_diff, sample_replay, sample_session, sample_config
      Batch:     batch/sample_analysis.html, batch/sample_followup.html
      Markdown:  sample.md, sample.qmd, sample_both.md
      Other:     sample.tex, sample.docx (Stata 17+), sample_pdf.pdf (wkhtmltopdf)
      Console:   console_output.smcl

    Run from the repository root:
      stata-mp -b do logdoc/demo/demo_logdoc.do
*/

version 16.0
set more off
set varabbrev off
set linesize 255
capture log close _all

**# Paths
local repo_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir "logdoc/demo"
local batch_dir "`pkg_dir'/batch"
capture mkdir "`pkg_dir'"
capture mkdir "`batch_dir'"

log using "`pkg_dir'/demo_logdoc.log", replace text name(runlog) nomsg

local old_plus "`c(sysdir_plus)'"
local old_personal "`c(sysdir_personal)'"
local tmp_root = regexr("`c(tmpdir)'", "/+$", "")
local plus_dir "`tmp_root'/logdoc_demo_plus"
local personal_dir "`tmp_root'/logdoc_demo_personal"
capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"

**# Graph scheme
capture set scheme plotplainblind
if _rc {
    set scheme s2color
}

**# Install command from the worktree
capture ado uninstall logdoc
quietly net install logdoc, from("`repo_dir'/logdoc") replace
capture program drop _demo_contains

program define _demo_contains
    args file pattern resultvar
    tempfile pyout
    shell python3 -c "import re,sys; t=open(sys.argv[1],encoding='utf-8',errors='replace').read(); print(1 if re.search(sys.argv[2], t) else 0)" "`file'" "`pattern'" > "`pyout'" 2>/dev/null
    tempname fh
    file open `fh' using "`pyout'", read text
    file read `fh' line
    file close `fh'
    local found = real(strtrim("`line'"))
    if missing(`found') local found = 0
    c_local `resultvar' = (`found' > 0)
end

**# Clean stale inputs and retired outputs
foreach f in sample_analysis.smcl sample_followup.smcl annotations.txt demo_custom.css ///
    run_example.do run_example.smcl run_example.log sample_pdf.pdf ///
    sample_graphsize.html sample_nodots.html sample_preformatted.html ///
    sample_custom_css.html sample_toc.html {
    capture erase "`pkg_dir'/`f'"
}
foreach f in sample_analysis.html sample_followup.html sample_analysis.md sample_followup.md {
    capture erase "`batch_dir'/`f'"
}
capture erase "run_example.log"
capture erase "run_example.smcl"

**# Create rich source logs
sysuse auto, clear

log using "`pkg_dir'/sample_analysis.smcl", replace smcl name(analysis) nomsg

* # Data Overview
summarize price mpg weight length, separator(0)
tabstat price mpg weight, by(foreign) statistics(n mean sd median min max) columns(statistics)

* # Regression Analysis
regress price mpg weight length i.foreign
estimates store base

* ## Margins
margins foreign, atmeans

* # Tabulations
tabulate foreign rep78, row

* # Diagnostics
quietly regress price mpg weight
predict double resid, residuals
histogram resid, normal ///
    title("Residual Distribution") ///
    xtitle("Residuals") ytitle("Density")
graph export "logdoc/demo/residuals.png", replace width(900)
capture graph close _all
drop resid

log close analysis

sysuse auto, clear

log using "`pkg_dir'/sample_followup.smcl", replace smcl name(followup) nomsg

* # Follow-up Model
generate double weight_tons = weight / 2000
label variable weight_tons "Weight in tons"
regress price c.mpg##i.foreign weight_tons
estimates store interaction

* # Follow-up Graph
twoway ///
    (scatter price mpg if foreign == 0, mcolor(navy%65)) ///
    (scatter price mpg if foreign == 1, mcolor(maroon%65)) ///
    (lfit price mpg if foreign == 0, lcolor(navy)) ///
    (lfit price mpg if foreign == 1, lcolor(maroon)), ///
    legend(order(1 "Domestic" 2 "Foreign") pos(6) rows(1)) ///
    title("Price and Mileage by Origin") ///
    xtitle("Mileage (mpg)") ytitle("Price")
graph export "logdoc/demo/followup_scatter.png", replace width(900)
capture graph close _all

log close followup

**# Create support files
tempname fh
file open `fh' using "`pkg_dir'/run_example.do", write text replace
file write `fh' "version 16.0" _n
file write `fh' "set more off" _n
file write `fh' "capture log close _all" _n
file write `fh' `"log using "logdoc/demo/run_example.smcl", replace smcl name(runexample) nomsg"' _n
file write `fh' "sysuse auto, clear" _n
file write `fh' "summarize price mpg weight" _n
file write `fh' "regress price mpg weight" _n
file write `fh' "log close runexample" _n
file close `fh'

tempname ann
file open `ann' using "`pkg_dir'/annotations.txt", write text replace
file write `ann' `"@block 2: The main regression is rendered as a structured output block."' _n
file write `ann' `"@command "graph export": Exported graph files are embedded directly in self-contained HTML."' _n
file close `ann'

tempname css
file open `css' using "`pkg_dir'/demo_custom.css", write text replace
file write `css' ".logdoc-header { border-bottom: 4px solid #2f6f4e; }" _n
file write `css' ".stata-log { border-left: 4px solid #2f6f4e; padding-left: .75rem; }" _n
file write `css' ".logdoc-footer::before { content: 'Demo custom CSS'; display: block; }" _n
file close `css'

**# Convert examples
log using "`pkg_dir'/console_output.smcl", replace smcl name(console) nomsg

* Light theme: title, date, footer, stamp
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_light.html") ///
    title("Auto Dataset Analysis") date("28 April 2026") ///
    footer("Demo generated from logdoc/demo/demo_logdoc.do") stamp replace
assert "`r(format)'" == "html"
assert "`r(theme)'" == "light"

* Dark theme: graphwidth, graphheight, quiet
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_dark.html") ///
    title("Auto Dataset Analysis") ///
    theme(dark) graphwidth(520) graphheight(320) quiet replace
assert "`r(theme)'" == "dark"

* Enhanced HTML: legacy (fold+highlight+tables+copy+download), toc, linenumbers, generated
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_enhanced.html") ///
    title("Enhanced Analysis Output") legacy toc linenumbers generated replace

* Notebook layout: nodots
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_notebook.html") ///
    title("Notebook Mode Example") date("28 April 2026") notebook nodots replace

* No-graph: preformatted, nofold
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_nograph.html") ///
    title("No Graph Example") nograph preformatted nofold replace

* Email-safe inline CSS: verbose
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_email.html") ///
    title("Email-Safe Output") email verbose replace

* Markdown
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample.md") ///
    title("Auto Dataset Analysis") date("28 April 2026") replace
assert "`r(format)'" == "md"

* Quarto Markdown
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample.qmd") ///
    title("Auto Dataset Analysis") date("28 April 2026") replace
assert "`r(format)'" == "qmd"

* Dual HTML + Markdown
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_both.html") ///
    title("Auto Dataset Analysis") date("28 April 2026") ///
    format(both) replace
assert "`r(secondary)'" == "`pkg_dir'/sample_both.md"

* Keep filter: nodots
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_filtered.html") ///
    title("Regression Results Only") keep("regress|margins") nodots replace

* Drop filter
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_drop.html") ///
    title("Dropped Setup and Tabulation Output") drop("tabulate|histogram") replace

* Annotate + custom CSS
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_annotated.html") ///
    title("Annotated Output") ///
    annotate("`pkg_dir'/annotations.txt") css("`pkg_dir'/demo_custom.css") replace

* Run option: execute .do file then convert
noisily logdoc using "`pkg_dir'/run_example.do", ///
    output("`pkg_dir'/run_output.html") ///
    title("Run Option Example") run replace

* LaTeX
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample.tex") ///
    title("LaTeX Export Example") date("28 April 2026") replace

* Word document (Stata 17+)
if c(stata_version) >= 17 {
    noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
        output("`pkg_dir'/sample.docx") ///
        title("Word Export Example") date("28 April 2026") replace
}
else {
    display as text "SKIP: sample.docx requires Stata 17 or newer"
}

* Append: initial + follow-up
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_append.html") ///
    title("Append Example") replace
noisily logdoc using "`pkg_dir'/sample_followup.smcl", ///
    output("`pkg_dir'/sample_append.html") append

* Diff
noisily logdoc diff using "`pkg_dir'/sample_analysis.smcl", ///
    compare("`pkg_dir'/sample_followup.smcl") ///
    output("`pkg_dir'/sample_diff.html") replace

* Batch
noisily logdoc batch, input("`pkg_dir'/sample_*.smcl") ///
    outdir("`batch_dir'") replace

* Replay: convert then replay with theme override
noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_replay.html") ///
    title("Replay Example") date("28 April 2026") ///
    footer("Replay footer") replace
noisily logdoc replay, theme(dark)

* Live session
logdoc start, output("`pkg_dir'/sample_session.html") ///
    title("Live Session Example") annotate("`pkg_dir'/annotations.txt") ///
    notebook replace
sysuse auto, clear
summarize price mpg
regress price mpg weight
logdoc stop

* Project config (.logdocrc)
capture confirm file ".logdocrc"
local had_logdocrc = (_rc == 0)
if `had_logdocrc' {
    tempfile saved_logdocrc
    copy ".logdocrc" "`saved_logdocrc'", replace
}
tempname rcfile
file open `rcfile' using ".logdocrc", write text replace
file write `rcfile' "theme=dark" _n
file close `rcfile'
capture noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_config.html") ///
    title("Project Config Example") replace
local config_rc = _rc
if `had_logdocrc' {
    copy "`saved_logdocrc'" ".logdocrc", replace
}
else {
    capture erase ".logdocrc"
}
if `config_rc' exit `config_rc'

* PDF dependency check
capture noisily logdoc using "`pkg_dir'/sample_analysis.smcl", ///
    output("`pkg_dir'/sample_pdf.pdf") ///
    title("PDF Dependency Check") format(pdf) replace
local pdf_rc = _rc
if `pdf_rc' == 0 {
    display as result "PDF check: sample_pdf.pdf generated"
}
else if inlist(`pdf_rc', 198, 601) {
    display as text "PDF check: wkhtmltopdf dependency was cleanly reported"
}
else {
    exit `pdf_rc'
}

**# Validate generated content
confirm file "`pkg_dir'/console_output.smcl"
confirm file "`pkg_dir'/sample_analysis.smcl"
confirm file "`pkg_dir'/sample_followup.smcl"
confirm file "`pkg_dir'/residuals.png"
confirm file "`pkg_dir'/followup_scatter.png"
confirm file "`pkg_dir'/sample_light.html"
confirm file "`pkg_dir'/sample_dark.html"
confirm file "`pkg_dir'/sample_enhanced.html"
confirm file "`pkg_dir'/sample_notebook.html"
confirm file "`pkg_dir'/sample_nograph.html"
confirm file "`pkg_dir'/sample.md"
confirm file "`pkg_dir'/sample.qmd"
confirm file "`pkg_dir'/sample_both.html"
confirm file "`pkg_dir'/sample_both.md"
confirm file "`pkg_dir'/run_output.html"
confirm file "`pkg_dir'/sample.tex"
confirm file "`pkg_dir'/sample_filtered.html"
confirm file "`pkg_dir'/sample_drop.html"
confirm file "`pkg_dir'/sample_email.html"
confirm file "`pkg_dir'/sample_annotated.html"
confirm file "`pkg_dir'/sample_append.html"
confirm file "`pkg_dir'/sample_diff.html"
confirm file "`pkg_dir'/sample_replay.html"
confirm file "`pkg_dir'/sample_session.html"
confirm file "`pkg_dir'/sample_config.html"
confirm file "`batch_dir'/sample_analysis.html"
confirm file "`batch_dir'/sample_followup.html"
if c(stata_version) >= 17 {
    confirm file "`pkg_dir'/sample.docx"
}

_demo_contains "`pkg_dir'/sample_light.html" "data:image/png" has_graph
assert `has_graph' == 1
_demo_contains "`pkg_dir'/sample_light.html" "Graph file not found" has_missing_graph
assert `has_missing_graph' == 0
_demo_contains "`pkg_dir'/sample_dark.html" "#191a1f" has_dark
assert `has_dark' == 1
_demo_contains "`pkg_dir'/sample_dark.html" "width:520px" has_graph_width
assert `has_graph_width' == 1
_demo_contains "`pkg_dir'/sample_nograph.html" "data:image/png" has_nograph_figure
assert `has_nograph_figure' == 0
_demo_contains "`pkg_dir'/sample_enhanced.html" "logdoc-toc" has_toc
assert `has_toc' == 1
_demo_contains "`pkg_dir'/sample_enhanced.html" "line-num" has_line_numbers
assert `has_line_numbers' == 1
_demo_contains "`pkg_dir'/sample_enhanced.html" "<details" has_fold
assert `has_fold' == 1
_demo_contains "`pkg_dir'/sample_enhanced.html" "Generated 20" has_generated
assert `has_generated' == 1
_demo_contains "`pkg_dir'/sample_dark.html" "<footer" has_default_footer
assert `has_default_footer' == 0
_demo_contains "`pkg_dir'/sample_notebook.html" "notebook-cell" has_notebook
assert `has_notebook' == 1
_demo_contains "`pkg_dir'/sample_email.html" "<style>" has_style_block
assert `has_style_block' == 0
_demo_contains "`pkg_dir'/sample_email.html" "style=" has_inline_style
assert `has_inline_style' == 1
_demo_contains "`pkg_dir'/sample_annotated.html" "annotation" has_annotation
assert `has_annotation' == 1
_demo_contains "`pkg_dir'/sample_annotated.html" "Demo custom CSS" has_custom_css
assert `has_custom_css' == 1
_demo_contains "`pkg_dir'/sample.qmd" "^---" has_qmd_yaml
assert `has_qmd_yaml' == 1
_demo_contains "`pkg_dir'/sample_append.html" "Follow-up Model" has_append
assert `has_append' == 1
_demo_contains "`pkg_dir'/sample_diff.html" "diff-removed|diff-added" has_diff
assert `has_diff' == 1
_demo_contains "`pkg_dir'/sample_replay.html" "#191a1f" has_replay_dark
assert `has_replay_dark' == 1
_demo_contains "`pkg_dir'/sample_config.html" "#191a1f" has_config_dark
assert `has_config_dark' == 1

display as result "Demo validation passed: all outputs generated and key features verified"

log close console

**# Cleanup
capture erase "`pkg_dir'/run_example.do"
capture erase "`pkg_dir'/run_example.smcl"
capture erase "`pkg_dir'/run_example.log"
capture erase "run_example.log"
capture erase "run_example.smcl"
if !`had_logdocrc' {
    capture erase ".logdocrc"
}
sysdir set PLUS "`old_plus'"
sysdir set PERSONAL "`old_personal'"
if "`c(os)'" != "Windows" {
    shell rm -rf "`plus_dir'" "`personal_dir'" > /dev/null 2>&1
}
clear
log close runlog
capture log close _all

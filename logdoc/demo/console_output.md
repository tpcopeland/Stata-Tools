---
title: "console_output"
---

<!-- * Light theme: title, date, footer, stamp -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_light.html")
title("Auto Dataset Analysis") date("28 April 2026")
footer("Demo generated from logdoc/demo/demo_logdoc.do") stamp replace
```

```
Generating document...

Output: logdoc/demo/sample_light.html

```

```stata
assert "`r(format)'" == "html"
```

```stata
assert "`r(theme)'" == "light"
```

<!-- * Dark theme: graphwidth, graphheight, quiet -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_dark.html")
title("Auto Dataset Analysis")
theme(dark) graphwidth(520) graphheight(320) quiet replace
```

```stata
assert "`r(theme)'" == "dark"
```

<!-- * Enhanced HTML: legacy (fold+highlight+tables+copy+download), toc, linenumbers, generated -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_enhanced.html")
title("Enhanced Analysis Output") legacy toc linenumbers generated replace
```

```
Generating document...

Output: logdoc/demo/sample_enhanced.html

```

<!-- * Notebook layout: nodots -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_notebook.html")
title("Notebook Mode Example") date("28 April 2026") notebook nodots replace
```

```
Generating document...

Output: logdoc/demo/sample_notebook.html

```

<!-- * No-graph: preformatted, nofold -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_nograph.html")
title("No Graph Example") nograph preformatted nofold replace
```

```
Generating document...

Output: logdoc/demo/sample_nograph.html

```

<!-- * Email-safe inline CSS: verbose -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_email.html")
title("Email-Safe Output") email verbose replace
```

```
Generating document...

Output: logdoc/demo/sample_email.html

```

<!-- * Markdown -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample.md")
title("Auto Dataset Analysis") date("28 April 2026") replace
```

```
Generating document...

Output: logdoc/demo/sample.md

```

```stata
assert "`r(format)'" == "md"
```

<!-- * Quarto Markdown -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample.qmd")
title("Auto Dataset Analysis") date("28 April 2026") replace
```

```
Generating document...

Output: logdoc/demo/sample.qmd

```

```stata
assert "`r(format)'" == "qmd"
```

<!-- * Dual HTML + Markdown -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_both.html")
title("Auto Dataset Analysis") date("28 April 2026")
format(both) replace
```

```
Generating document...

Output: logdoc/demo/sample_both.html
Output: logdoc/demo/sample_both.md

```

```stata
assert "`r(secondary)'" == "`pkg_dir'/sample_both.md"
```

<!-- * Keep filter: nodots -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_filtered.html")
title("Regression Results Only") keep("regress|margins") nodots replace
```

```
Generating document...

Output: logdoc/demo/sample_filtered.html

```

<!-- * Drop filter -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_drop.html")
title("Dropped Setup and Tabulation Output") drop("tabulate|histogram") replace
```

```
Generating document...

Output: logdoc/demo/sample_drop.html

```

<!-- * Annotate + custom CSS -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_annotated.html")
title("Annotated Output")
annotate("`pkg_dir'/annotations.txt") css("`pkg_dir'/demo_custom.css") replace
```

```
Generating document...

Output: logdoc/demo/sample_annotated.html

```

<!-- * Run option: execute .do file then convert -->

```stata
noisily logdoc using "`pkg_dir'/run_example.do",
output("`pkg_dir'/run_output.html")
title("Run Option Example") run replace
```

```
Running: logdoc/demo/run_example.do

(file
/tmp/St329578_000001.do
not found)


Log captured: logdoc/demo/run_example.smcl

Generating document...

Output: logdoc/demo/run_output.html

```

<!-- * LaTeX -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample.tex")
title("LaTeX Export Example") date("28 April 2026") replace
```

```
Generating document...

Output: logdoc/demo/sample.tex

```

<!-- * Word document (Stata 17+) -->

```stata
if c(stata_version) >= 17
```

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample.docx")
title("Word Export Example") date("28 April 2026") replace
```

```
Generating document...

Converting HTML to Word document...
successfully converted
Output: logdoc/demo/sample.docx
```

```stata

```

```stata
else
```

```stata
display as text "SKIP: sample.docx requires Stata 17 or newer"
```

<!-- * Append: initial + follow-up -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_append.html")
title("Append Example") replace
```

```
Generating document...

Output: logdoc/demo/sample_append.html

```

```stata
noisily logdoc using "`pkg_dir'/sample_followup.smcl",
output("`pkg_dir'/sample_append.html") append
```

```
Generating document...

Output: logdoc/demo/sample_append.html

```

<!-- * Diff -->

```stata
noisily logdoc diff using "`pkg_dir'/sample_analysis.smcl",
compare("`pkg_dir'/sample_followup.smcl")
output("`pkg_dir'/sample_diff.html") replace
```

```
Generating diff document...

Output: logdoc/demo/sample_diff.html

```

<!-- * Batch -->

```stata
noisily logdoc batch, input("`pkg_dir'/sample_*.smcl")
outdir("`batch_dir'") replace
```

```
[1] logdoc/demo/sample_analysis.smcl -> logdoc/demo/batch/sample_analysis.html

Generating document...

Output: logdoc/demo/batch/sample_analysis.html
[2] logdoc/demo/sample_followup.smcl -> logdoc/demo/batch/sample_followup.html

Generating document...

Output: logdoc/demo/batch/sample_followup.html
2 files processed, 0 failed

```

<!-- * Replay: convert then replay with theme override -->

```stata
noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_replay.html")
title("Replay Example") date("28 April 2026")
footer("Replay footer") replace
```

```
Generating document...

Output: logdoc/demo/sample_replay.html

```

```stata
noisily logdoc replay, theme(dark)
```

```
Generating document...

Output: logdoc/demo/sample_replay.html

```

<!-- * Live session -->

```stata
logdoc start, output("`pkg_dir'/sample_session.html")
title("Live Session Example") annotate("`pkg_dir'/annotations.txt")
notebook replace
```

```

(file
/tmp/logdoc_session_232541_348871704.smcl
not found)


      name:  _logdoc
       log:  /tmp/logdoc_session_232541_348871704.smcl
  log type:  smcl
 opened on:  28 Apr 2026, 23:25:41
logdoc session started
Output will be saved to: logdoc/demo/sample_session.html
Use **logdoc stop** to end and convert

```

```stata
sysuse auto, clear
```

```
(1978 automobile data)

```

```stata
summarize price mpg
```

```
    Variable │        Obs        Mean    Std. dev.       Min        Max
─────────────┼─────────────────────────────────────────────────────────
       price │         74    6165.257    2949.496       3291      15906
         mpg │         74     21.2973    5.785503         12         41

```

```stata
regress price mpg weight
```

```
      Source │       SS           df       MS      Number of obs   =        74
─────────────┼──────────────────────────────────   F(2, 71)        =     14.74
       Model │   186321280         2  93160639.9   Prob > F        =    0.0000
    Residual │   448744116        71  6320339.67   R-squared       =    0.2934
─────────────┼──────────────────────────────────   Adj R-squared   =    0.2735
       Total │   635065396        73  8699525.97   Root MSE        =      2514

```

```
─────────────┬──────────────────────────────────────────────────────────────────────
        price │ Coefficient   Std. err.       t    P>|t|      [95% con f. interval]
─────────────┼──────────────────────────────────────────────────────────────────────
         mpg │   -49.51222    86.15604     -0.57    0.567     -221.3025      122.278
      weight │    1.746559    .6413538      2.72    0.008       .467736     3.025382
       _cons │    1946.069     3597.05      0.54    0.590     -5226.245     9118.382
─────────────┴──────────────────────────────────────────────────────────────────────
```

```stata
logdoc stop
```

```
Generating document...

Output: logdoc/demo/sample_session.html

```

<!-- * Project config (.logdocrc) -->

```stata
capture confirm file ".logdocrc"
```

```stata
local had_logdocrc = (_rc == 0)
```

```stata
if `had_logdocrc'
```

```stata
tempfile saved_logdocrc
```

```stata
copy ".logdocrc" "`saved_logdocrc'", replace
```

```stata
tempname rcfile
```

```stata
file open `rcfile' using ".logdocrc", write text replace
```

```

(file
.logdocrc
not found)


```

```stata
file write `rcfile' "theme=dark" _n
```

```stata
file close `rcfile'
```

```stata
capture noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_config.html")
title("Project Config Example") replace
```

```
Generating document...

Output: logdoc/demo/sample_config.html

```

```stata
local config_rc = _rc
```

```stata
if `had_logdocrc'
```

```stata
copy "`saved_logdocrc'" ".logdocrc", replace
```

```stata
else
```

```stata
capture erase ".logdocrc"
```

```stata
if `config_rc' exit `config_rc'
```

<!-- * PDF dependency check -->

```stata
capture noisily logdoc using "`pkg_dir'/sample_analysis.smcl",
output("`pkg_dir'/sample_pdf.pdf")
title("PDF Dependency Check") format(pdf) replace
```

```
Generating document...


Converting HTML to PDF via wkhtmltopdf...

Output: logdoc/demo/sample_pdf.pdf

```

```stata
local pdf_rc = _rc
```

```stata
if `pdf_rc' == 0
```

```stata
display as result "PDF check: sample_pdf.pdf generated"
```

```
PDF check: sample_pdf.pdf generated
```

```stata

```

```stata
else if inlist(`pdf_rc', 198, 601)
```

```stata
display as text "PDF check: wkhtmltopdf dependency was cleanly reported"
```

```stata
else
```

```stata
exit `pdf_rc'
```

<!-- **# Validate generated content -->

```stata
confirm file "`pkg_dir'/console_output.smcl"
```

```stata
confirm file "`pkg_dir'/sample_analysis.smcl"
```

```stata
confirm file "`pkg_dir'/sample_followup.smcl"
```

```stata
confirm file "`pkg_dir'/residuals.png"
```

```stata
confirm file "`pkg_dir'/followup_scatter.png"
```

```stata
confirm file "`pkg_dir'/sample_light.html"
```

```stata
confirm file "`pkg_dir'/sample_dark.html"
```

```stata
confirm file "`pkg_dir'/sample_enhanced.html"
```

```stata
confirm file "`pkg_dir'/sample_notebook.html"
```

```stata
confirm file "`pkg_dir'/sample_nograph.html"
```

```stata
confirm file "`pkg_dir'/sample.md"
```

```stata
confirm file "`pkg_dir'/sample.qmd"
```

```stata
confirm file "`pkg_dir'/sample_both.html"
```

```stata
confirm file "`pkg_dir'/sample_both.md"
```

```stata
confirm file "`pkg_dir'/run_output.html"
```

```stata
confirm file "`pkg_dir'/sample.tex"
```

```stata
confirm file "`pkg_dir'/sample_filtered.html"
```

```stata
confirm file "`pkg_dir'/sample_drop.html"
```

```stata
confirm file "`pkg_dir'/sample_email.html"
```

```stata
confirm file "`pkg_dir'/sample_annotated.html"
```

```stata
confirm file "`pkg_dir'/sample_append.html"
```

```stata
confirm file "`pkg_dir'/sample_diff.html"
```

```stata
confirm file "`pkg_dir'/sample_replay.html"
```

```stata
confirm file "`pkg_dir'/sample_session.html"
```

```stata
confirm file "`pkg_dir'/sample_config.html"
```

```stata
confirm file "`batch_dir'/sample_analysis.html"
```

```stata
confirm file "`batch_dir'/sample_followup.html"
```

```stata
if c(stata_version) >= 17
```

```stata
confirm file "`pkg_dir'/sample.docx"
```

```stata
_demo_contains "`pkg_dir'/sample_light.html" "data:image/png" has_graph
```

```stata
assert `has_graph' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_light.html" "Graph file not found" has_missing_graph
```

```stata
assert `has_missing_graph' == 0
```

```stata
_demo_contains "`pkg_dir'/sample_dark.html" "#191a1f" has_dark
```

```stata
assert `has_dark' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_dark.html" "width:520px" has_graph_width
```

```stata
assert `has_graph_width' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_nograph.html" "data:image/png" has_nograph_figure
```

```stata
assert `has_nograph_figure' == 0
```

```stata
_demo_contains "`pkg_dir'/sample_enhanced.html" "logdoc-toc" has_toc
```

```stata
assert `has_toc' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_enhanced.html" "line-num" has_line_numbers
```

```stata
assert `has_line_numbers' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_enhanced.html" "<details" has_fold
```

```stata
assert `has_fold' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_enhanced.html" "Generated 20" has_generated
```

```stata
assert `has_generated' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_dark.html" "<footer" has_default_footer
```

```stata
assert `has_default_footer' == 0
```

```stata
_demo_contains "`pkg_dir'/sample_notebook.html" "notebook-cell" has_notebook
```

```stata
assert `has_notebook' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_email.html" "<style>" has_style_block
```

```stata
assert `has_style_block' == 0
```

```stata
_demo_contains "`pkg_dir'/sample_email.html" "style=" has_inline_style
```

```stata
assert `has_inline_style' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_annotated.html" "annotation" has_annotation
```

```stata
assert `has_annotation' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_annotated.html" "Demo custom CSS" has_custom_css
```

```stata
assert `has_custom_css' == 1
```

```stata
_demo_contains "`pkg_dir'/sample.qmd" "^---" has_qmd_yaml
```

```stata
assert `has_qmd_yaml' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_append.html" "Follow-up Model" has_append
```

```stata
assert `has_append' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_diff.html" "diff-removed|diff-added" has_diff
```

```stata
assert `has_diff' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_replay.html" "#191a1f" has_replay_dark
```

```stata
assert `has_replay_dark' == 1
```

```stata
_demo_contains "`pkg_dir'/sample_config.html" "#191a1f" has_config_dark
```

```stata
assert `has_config_dark' == 1
```

```stata
display as result "Demo validation passed: all outputs generated and key features verified"
```

```
Demo validation passed: all outputs generated and key features verified

```

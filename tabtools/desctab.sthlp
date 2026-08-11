{smcl}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "table" "help table"}{...}
{vieweralsosee "collect" "help collect"}{...}
{viewerjumpto "Syntax" "desctab##syntax"}{...}
{viewerjumpto "Description" "desctab##description"}{...}
{viewerjumpto "Options" "desctab##options"}{...}
{viewerjumpto "Examples" "desctab##examples"}{...}
{viewerjumpto "Stored results" "desctab##stored"}{...}
{viewerjumpto "Author" "desctab##author"}{...}

{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:desctab} {hline 2}}Format descriptive {cmd:table} collections with per-statistic formats{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 4 8 2}
{cmd:desctab} [{cmd:,} {opt xlsx(filename)} {opt excel(filename)}
{opt sheet(string)} {opt title(string)} {opt foot:note(string)}
{opt compose(string)} {opt nformats(string)} {opt digits(#)}
{opt pctdigits(#)} {opt nintegerfmt(string)} {opt pctscale(string)}
{opt pctsign} {opt rowtotals} {opt coltotals} {opt nototals}
{opt keep(string)} {opt drop(string)} {opt statorder(string)}
{opt statlabels(string)} {opt nomis:sing} {opt zebra}
{opt headers:hade} {opt headerc:olor(string)}
{opt zebrac:olor(string)} {opt border:style(string)}
{opt the:me(string)} {opt open} {opt csv(string)} {opt markdown(filename)} {opt mdappend}
{opt fra:me(name)} {opt high:light(#)}
{opt hls:tat(string)} {opt smallc:ells(#)}]{p_end}

{pstd}
Prerequisite: an active {helpb collect} created by {helpb table}. {cmd:desctab}
always displays the completed table in the Results window, and can also export
the same table to Excel, CSV, or a Stata frame.

{marker description}{...}
{title:Description}

{pstd}
{cmd:desctab} is a formatter. It does not compute descriptive statistics and it
does not wrap {cmd:table}. Run your own {cmd:collect: table ...}, then call
{cmd:desctab} to apply statistic-specific number formats, optionally collapse
multiple statistics into one display cell, and export a polished worksheet.

{pstd}
The main use case is a {cmd:table} collection containing statistics such as
{cmd:sum}, {cmd:count}, and {cmd:mean}, where each statistic needs a different
format. For example, {cmd:desctab, compose(events_n_pct)} renders cells such as
{cmd:7 / 142 (4.9%)}.

{marker options}{...}
{title:Options}

{synoptset 28 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(filename)}}write an Excel workbook{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx()}{p_end}
{synopt:{opt sheet(string)}}worksheet name. Default is {cmd:Descriptive}{p_end}
{synopt:{opt title(string)}}title written to cell A1 and used in console display{p_end}
{synopt:{opt foot:note(string)}}footnote written below the Excel table{p_end}
{synopt:{opt compose(string)}}combine statistics with a cell template{p_end}
{synopt:{opt nformats(string)}}set display formats by statistic{p_end}
{synopt:{opt digits(#)}}digits for continuous statistics{p_end}
{synopt:{opt pctdigits(#)}}digits for displayed percents in composite cells{p_end}
{synopt:{opt nintegerfmt(string)}}format for counts and integer totals{p_end}
{synopt:{opt pctscale(string)}}choose proportion or percentage scale{p_end}
{synopt:{opt pctsign}}append percent signs{p_end}
{synopt:{opt rowtotals}}keep row totals when {opt nototals} is also specified{p_end}
{synopt:{opt coltotals}}keep column totals when {opt nototals} is also specified{p_end}
{synopt:{opt nototals}}drop row and column totals labeled {cmd:Total}{p_end}
{synopt:{opt keep(string)}}retain rows matching displayed labels{p_end}
{synopt:{opt drop(string)}}omit rows matching displayed labels{p_end}
{synopt:{opt statorder(string)}}set the statistic display order{p_end}
{synopt:{opt statlabels(string)}}set custom statistic labels{p_end}
{synopt:{opt nomis:sing}}drop rows labeled missing, {cmd:.}, or {cmd:.m}{p_end}
{synopt:{opt zebra}}apply alternating row shading in Excel{p_end}
{synopt:{opt headers:hade}}shade header rows in Excel{p_end}
{synopt:{opt headerc:olor(string)}}set the header fill color{p_end}
{synopt:{opt zebrac:olor(string)}}set alternating-row fill color{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt the:me(string)}}apply a journal formatting theme; see {helpb tabtools##themes:tabtools}{p_end}
{synopt:{opt open}}open the workbook after export{p_end}
{synopt:{opt csv(string)}}also export the display table as CSV{p_end}
{synopt:{opt markdown(filename)}}export GitHub-Flavored Markdown{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file{p_end}
{synopt:{opt fra:me(name)}}store the display table in a Stata frame{p_end}
{synopt:{opt high:light(#)}}highlight rows where {opt hls:tat()} is below the threshold{p_end}
{synopt:{opt hls:tat(string)}}statistic used for {opt high:light()}. Default is {cmd:mean}{p_end}
{synopt:{opt smallc:ells(#)}}protect recognized count layouts{p_end}
{synoptline}

{pstd}
{opt compose()} presets: {cmd:events_n_pct}, {cmd:events_n}, {cmd:n_pct},
{cmd:mean_sd}, {cmd:mean_semean}, {cmd:median_iqr}, {cmd:median_range}, and
{cmd:mean_ci}. Custom templates such as {cmd:"{c -(}total{c )-} / {c -(}count{c )-} ({c -(}mean{c )-})"} are also allowed.



{pstd}
{it:Detailed option contracts}{p_end}

{phang}
{opt border:style(string)} border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}

{phang}
{opt coltotals} keep column totals when {opt nototals} is also specified{p_end}

{phang}
{opt csv(string)} also export the display table as CSV. The CSV mirrors the
workbook with {opt title()} written as the first row and {opt footnote()} as
the last row, both in the first column and the table body between them.{p_end}

{phang}
{opt digits(#)} digits for continuous statistics. Default is 2, or the session default set by
{cmd:tabtools set digits}{p_end}

{phang}
{opt drop(string)} drop rows whose displayed row label matches a listed token. Cannot be combined
with {opt keep()}{p_end}

{phang}
{opt excel(filename)} synonym for {opt xlsx()}{p_end}

{phang}
{opt foot:note(string)} footnote written below the Excel table{p_end}

{phang}
{opt fra:me(name)} store the display table in a Stata frame. Use {cmd:frame(name, replace)} to
replace an existing frame{p_end}

{phang}
{opt headerc:olor(string)} header fill color as a supported Stata color name or RGB triplet{p_end}

{phang}
{opt headers:hade} shade header rows in Excel. Header shading is off by default{p_end}

{phang}
{opt high:light(#)} highlight rows where {opt hls:tat()} is below the threshold{p_end}

{phang}
{opt hls:tat(string)} statistic used for {opt high:light()}. Default is {cmd:mean}{p_end}

{phang}
{opt keep(string)} keep only rows whose displayed row label matches a listed token{p_end}

{phang}
{opt markdown(filename)} export the rendered table as GitHub-Flavored Markdown; may be combined with
Excel, CSV, and frame exports{p_end}

{phang}
{opt mdappend} append the Markdown table to an existing file; requires {opt markdown()}{p_end}

{phang}
{opt nformats(string)} override statistic formats using pairs such as {cmd:"count %4.0f mean %5.2f"}{p_end}

{phang}
{opt nintegerfmt(string)} format for counts and integer totals. Default is {cmd:%12.0fc}{p_end}

{phang}
{opt nomis:sing} drop rows labeled missing, {cmd:.}, or {cmd:.m}{p_end}

{phang}
{opt nototals} drop row and column totals labeled {cmd:Total}{p_end}

{phang}
{opt open} open the workbook after export. Requires {opt xlsx()} or {opt excel()}{p_end}

{phang}
{opt pctdigits(#)} digits for displayed percents in composite cells. Default is 1{p_end}

{phang}
{opt pctscale(string)} percent scale for proportions: {cmd:auto} (default), {cmd:0to1}, or
{cmd:0to100}{p_end}

{phang}
{opt pctsign} append a percent sign to percent/proportion display values. Compose mode enables this
by default{p_end}

{phang}
{opt rowtotals} keep row totals when {opt nototals} is also specified{p_end}

{phang}
{opt sheet(string)} worksheet name. Default is {cmd:Descriptive}{p_end}

{phang}
{opt smallc:ells(#)} protect exact counts below {it:#}; {it:#} must be an
integer of at least 3.{p_end}

{phang}
{opt statlabels(string)} custom statistic labels, for example {cmd:"count=N \ mean=Mean"}{p_end}

{phang}
{opt statorder(string)} display statistics in the specified order, appending any remaining collected
statistics afterward{p_end}

{phang}
{opt the:me(string)} journal-style font and border theme shared across tabtools; use
{opt headershade}/ {opt zebra} for shaded fills{p_end}

{phang}
{opt title(string)} title written to cell A1 and used in console display{p_end}

{phang}
{opt xlsx(filename)} write an Excel workbook. The filename must end in {cmd:.xlsx}{p_end}

{phang}
{opt zebra} apply alternating row shading in Excel. Shading is off by default{p_end}

{phang}
{opt zebrac:olor(string)} zebra fill color as a supported Stata color name or RGB triplet{p_end}

{marker smallcells}{title:Small-cell disclosure control}

{pstd}
{opt smallcells(#)} is available only when the active collection can be mapped
by exact dimension and result identifiers. Initial support covers a single
{cmd:count}, {cmd:frequency}, or {cmd:fvfrequency} result, and the named
{cmd:compose(n_pct)} preset with exactly one count and one percentage result
in a shape with one non-{cmd:var} row dimension, at most one non-{cmd:var} column
dimension, and at most one source-variable level in a {cmd:var} dimension.{p_end}

{pstd}
Positive counts below {it:#} are shown as {cmd:<#}; additional cells or margins
are shown as {cmd:≥#} when needed to prevent exact reconstruction. Structural
zeros remain visible. With {cmd:compose(n_pct)}, percentages in a protected
logical block are withheld and the safe count marker remains. The console,
Excel, CSV, Markdown, and frame sinks all reuse the same redacted table.{p_end}

{pstd}
After safety is certified, individually redundant complementary markers are
removed in a deterministic pass. Each remaining {cmd:≥#} is necessary in the
final protected table because revealing it would make at least one primary
count exact. The resulting set is irredundant, but not guaranteed globally
minimum.{p_end}

{pstd}
Custom {opt compose()} templates, other statistics, multiple source-variable
levels, unsupported compound layouts, and combinations with {opt keep()},
{opt drop()}, {opt nomissing}, or {opt highlight()} fail before any sink is
written. The command also fails closed if count additivity or reconstruction
protection cannot be proved. The standard small-cell footnote is appended
automatically. Protection covers one invocation and does not account for
linkage across separate releases.{p_end}

{marker examples}{...}
{title:Examples}

{pstd}Events / N (%) from a binary indicator:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: table rep78, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)}{p_end}
{phang2}{cmd:. desctab, compose(events_n_pct) pctdigits(1)}{p_end}

{pstd}Mean (SD) by group:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: table (var) (foreign), statistic(mean mpg weight) statistic(sd mpg weight)}{p_end}
{phang2}{cmd:. desctab, compose(mean_sd) digits(1)}{p_end}

{pstd}Export a formatted table with separate statistic columns:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)}{p_end}
{phang2}{cmd:. desctab, xlsx(desc.xlsx) sheet("Descriptive") title("Price by repair record and origin") digits(1)}{p_end}

{pstd}Opt in to shaded fills when desired:{p_end}
{phang2}{cmd:. desctab, xlsx(desc.xlsx) sheet("Styled") title("Styled descriptive table") headershade zebra}{p_end}

{pstd}Protect a recognized count table:{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input byte row byte col int frequency}{p_end}
{phang2}{cmd:. 1 1 2}{p_end}
{phang2}{cmd:. 1 2 8}{p_end}
{phang2}{cmd:. 2 1 6}{p_end}
{phang2}{cmd:. 2 2 4}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. expand frequency}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: table row col, statistic(frequency)}{p_end}
{phang2}{cmd:. desctab, smallcells(5) frame(desctab_safe, replace)}{p_end}

{marker stored}{...}
{title:Stored results}

{pstd}{cmd:desctab} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_cells)}}non-empty body cells written{p_end}
{synopt:{cmd:r(N_rows)}}rows in the display table, excluding the title row{p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(smallcells)}}requested threshold when {opt smallcells()} is used{p_end}
{synopt:{cmd:r(N_primary_suppressed)}}primary values hidden{p_end}
{synopt:{cmd:r(N_secondary_suppressed)}}complementary values hidden{p_end}
{synopt:{cmd:r(N_derived_suppressed)}}dependent non-count cells hidden{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(version)}}command version{p_end}
{synopt:{cmd:r(rowvar)}}row dimension inferred from the active collect{p_end}
{synopt:{cmd:r(colvar)}}column dimension inferred from the active collect, if any{p_end}
{synopt:{cmd:r(stats)}}statistics displayed or used for composition{p_end}
{synopt:{cmd:r(compose)}}resolved compose mode or custom template{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename, if exported{p_end}
{synopt:{cmd:r(sheet)}}sheet name, if exported{p_end}
{synopt:{cmd:r(frame)}}frame name, if {opt frame()} was specified{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(methods)}}short methods sentence{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}numeric display matrix with suppression markers{p_end}
{synopt:{cmd:r(suppression)}}display-cell suppression codes{p_end}

{pstd}
{cmd:r(suppression)} uses 0 for visible, 1 for primary, 2 for complementary,
and 3 for derived display cells.{p_end}

{pstd}
A requested frame carries characteristics {cmd:tabtools_smallcells},
{cmd:tabtools_suppression_codes}, and
{cmd:tabtools_suppression_scope}.{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}

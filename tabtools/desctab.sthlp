{smcl}
{* *! version 1.5.1  06jun2026}{...}
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
{opt relab:el} {opt valuelabels} {opt factorl:abel}
{opt keep(string)} {opt drop(string)} {opt statorder(string)}
{opt statlabels(string)} {opt nomis:sing} {opt zebra}
{opt headers:hade} {opt headerc:olor(string)}
{opt zebrac:olor(string)} {opt borders:tyle(string)}
{opt the:me(string)} {opt open} {opt csv(string)} {opt markdown(filename)} {opt mdappend}
{opt fra:me(name)} {opt dis:play} {opt high:light(#)}
{opt highs:tat(string)}]{p_end}

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
{synopt:{opt xlsx(filename)}}write an Excel workbook. The filename must end in {cmd:.xlsx}.{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx()}.{p_end}
{synopt:{opt sheet(string)}}worksheet name. Default is {cmd:Descriptive}.{p_end}
{synopt:{opt title(string)}}title written to cell A1 and used in console display.{p_end}
{synopt:{opt foot:note(string)}}footnote written below the Excel table.{p_end}
{synopt:{opt compose(string)}}collapse multiple statistics into one cell. Presets include {cmd:events_n_pct}, {cmd:events_n}, {cmd:n_pct}, {cmd:mean_sd}, {cmd:mean_semean}, {cmd:median_iqr}, {cmd:median_range}, and {cmd:mean_ci}. Custom templates such as {cmd:"{total} / {count} ({mean})"} are also allowed.{p_end}
{synopt:{opt nformats(string)}}override statistic formats using pairs such as {cmd:"count %4.0f mean %5.2f"}.{p_end}
{synopt:{opt digits(#)}}digits for continuous statistics. Default is 2, or the session default set by {cmd:tabtools set digits}.{p_end}
{synopt:{opt pctdigits(#)}}digits for displayed percents in composite cells. Default is 1.{p_end}
{synopt:{opt nintegerfmt(string)}}format for counts and integer totals. Default is {cmd:%12.0fc}.{p_end}
{synopt:{opt pctscale(string)}}percent scale for proportion-like statistics: {cmd:auto}, {cmd:0to1}, or {cmd:0to100}. In percentage composite modes, {cmd:auto} behaves as {cmd:0to100}; otherwise it preserves the native scale.{p_end}
{synopt:{opt pctsign}}append a percent sign to percent/proportion display values. Compose mode enables this by default.{p_end}
{synopt:{opt rowtotals}}keep row totals when {opt nototals} is also specified.{p_end}
{synopt:{opt coltotals}}keep column totals when {opt nototals} is also specified.{p_end}
{synopt:{opt nototals}}drop row and column totals labeled {cmd:Total}.{p_end}
{synopt:{opt relab:el}}accepted for suite consistency; labels already present in the active collection are preserved.{p_end}
{synopt:{opt valuelabels}}accepted for suite consistency; value labels already present in the active collection are preserved.{p_end}
{synopt:{opt factorl:abel}}accepted for suite consistency; factor labels already present in the active collection are preserved.{p_end}
{synopt:{opt keep(string)}}keep only rows whose displayed row label matches a listed token.{p_end}
{synopt:{opt drop(string)}}drop rows whose displayed row label matches a listed token. Cannot be combined with {opt keep()}.{p_end}
{synopt:{opt statorder(string)}}display statistics in the specified order, appending any remaining collected statistics afterward.{p_end}
{synopt:{opt statlabels(string)}}custom statistic labels, for example {cmd:"count=N \ mean=Mean"}.{p_end}
{synopt:{opt nomis:sing}}drop rows labeled missing, {cmd:.}, or {cmd:.m}.{p_end}
{synopt:{opt zebra}}apply alternating row shading in Excel. Shading is off by default.{p_end}
{synopt:{opt headers:hade}}shade header rows in Excel. Header shading is off by default.{p_end}
{synopt:{opt headerc:olor(string)}}header fill color as a named color or RGB triplet.{p_end}
{synopt:{opt zebrac:olor(string)}}zebra fill color as a named color or RGB triplet.{p_end}
{synopt:{opt borders:tyle(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}.{p_end}
{synopt:{opt the:me(string)}}journal-style font and border theme shared with other tabtools commands; use {opt headershade} and {opt zebra} explicitly when shaded fills are desired.{p_end}
{synopt:{opt open}}open the workbook after export. Requires {opt xlsx()} or {opt excel()}.{p_end}
{synopt:{opt csv(string)} {opt markdown(filename)} {opt mdappend}}also export the display table as CSV.{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{opt fra:me(name)}}store the display table in a Stata frame. Use {cmd:frame(name, replace)} to replace an existing frame.{p_end}
{synopt:{opt dis:play}}accepted for compatibility; the completed table is displayed automatically.{p_end}
{synopt:{opt high:light(#)}}highlight rows where {opt highlightstat()} is below the threshold.{p_end}
{synopt:{opt highs:tat(string)}}statistic used for {opt highlight()}. Default is {cmd:mean}.{p_end}
{synoptline}

{marker examples}{...}
{title:Examples}

{pstd}Events / N (%) from a binary indicator:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: table rep78, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)}{p_end}
{phang2}{cmd:. desctab, compose(events_n_pct) display pctdigits(1)}{p_end}

{pstd}Mean (SD) by group:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: table (var) (foreign), statistic(mean mpg weight) statistic(sd mpg weight)}{p_end}
{phang2}{cmd:. desctab, compose(mean_sd) digits(1) display}{p_end}

{pstd}Export a formatted table with separate statistic columns:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)}{p_end}
{phang2}{cmd:. desctab, xlsx(desc.xlsx) sheet("Descriptive") title("Price by repair record and origin") digits(1)}{p_end}

{pstd}Opt in to shaded fills when desired:{p_end}
{phang2}{cmd:. desctab, xlsx(desc.xlsx) sheet("Styled") title("Styled descriptive table") headershade zebra}{p_end}

{marker stored}{...}
{title:Stored results}

{pstd}{cmd:desctab} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_cells)}}non-empty body cells written{p_end}
{synopt:{cmd:r(N_rows)}}rows in the display table, excluding the title row{p_end}

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
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(methods)}}short methods sentence{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}numeric matrix parsed from displayed cells where possible; text composite cells are missing in this matrix{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.5.1{p_end}

{hline}

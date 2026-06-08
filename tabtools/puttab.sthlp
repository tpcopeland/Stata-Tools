{smcl}
{* *! version 1.6.2  08jun2026}{...}
{viewerjumpto "Package overview" "puttab##package"}{...}
{viewerjumpto "Syntax" "puttab##syntax"}{...}
{viewerjumpto "Description" "puttab##description"}{...}
{viewerjumpto "Options" "puttab##options"}{...}
{viewerjumpto "Examples" "puttab##examples"}{...}
{viewerjumpto "Stored results" "puttab##stored"}{...}
{viewerjumpto "Also see" "puttab##alsosee"}{...}
{viewerjumpto "Author" "puttab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "stacktab" "help stacktab"}{...}
{vieweralsosee "desctab" "help desctab"}{...}
{vieweralsosee "export excel" "help export_excel"}{...}
{title:Title}

{phang}
{bf:puttab} {hline 2} Style an in-memory table (dataset, frame, or matrix) as one Excel sheet

{marker package}{...}
{title:Package}

{pstd}{cmd:puttab} is part of the {helpb tabtools} suite. It is the first-mile
styled-block producer: it takes a table that already lives in memory and writes
it as one house-styled Excel sheet. Use {helpb desctab} when you have an active
{helpb collect} table, and {helpb stacktab} to assemble several exported
sheets into one composite. The natural pipeline is to emit styled blocks with
{cmd:puttab} and then stack them with {cmd:stacktab}.{p_end}

{hline}

{marker syntax}{...}
{title:Syntax}

{p 4 8 2}{cmd:puttab} [{varlist}] [{it:if}] [{it:in}] {cmd:using} {it:filename}{cmd:.xlsx}{cmd:,}
{opt sh:eet(string)}
[{opt fra:me(name)} {opt m:atrix(name)}
{opt ti:tle(string)} {opt foot:note(string)}
{opt the:me(string)} {opt border:style(string)}
{opt headerc:olor(string)} {opt zebrac:olor(string)}
{opt zeb:ra} {opt headers:hade}
{opt dig:its(#)} {opt varl:abels} {opt noh:eader}
{opt csv(filename)} {opt markdown(filename)} {opt mdappend} {opt open}]{p_end}

{pstd}The table source is exactly one of: a {it:varlist} of the current dataset
(required when no {opt frame()} or {opt matrix()} is given), a named
{opt frame()}, or a {opt matrix()}. A {it:varlist} may also subset a
{opt frame()}; it is not allowed with {opt matrix()}. {it:if} and {it:in}
restrict rows for the current-data or {opt frame()} source and are not allowed
with {opt matrix()}.{p_end}

{marker description}{...}
{title:Description}

{pstd}{cmd:puttab} writes a single, publication-styled Excel sheet from a table
that is already in memory: the current dataset, a named {helpb frames:frame}, or
a Stata {it:matrix} such as {cmd:e(b)}, {cmd:r(table)}, or the result of a
{helpb collapse} or {helpb tabulate}. It closes the gap between raw in-memory
results and a formatted sheet, replacing ad hoc
{cmd:export excel ..., firstrow()} dumps and hand-built {helpb putexcel} blocks
with the shared tabtools geometry: a merged title row, a header rule, optional
header shading and zebra striping, automatic column widths, borders, and an
italic footnote.{p_end}

{pstd}For a {opt matrix()} source, the matrix row names become the first
(label) column and the column names become the header row; equation names are
shown as {it:eqname:name}. For a dataset or {opt frame()} source, the variable
names form the header row (or the variable labels, with {opt varlabels}), and
numeric columns are formatted to {opt digits()} decimals. Integer-valued numeric
columns are written without decimals, and value labels are honored when
present.{p_end}

{pstd}The named {opt sheet()} is created if it does not exist and replaced if it
does, so repeated calls to the same workbook build up a multi-sheet file that
{helpb stacktab} can then assemble. The current data, frames, and matrices in
memory are left unchanged.{p_end}

{marker options}{...}
{title:Options}

{dlgtab:Source}

{synoptset 26 tabbed}{...}
{synoptline}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}use the named frame as the source instead of the current dataset{p_end}
{synopt:{cmdab:m:atrix(}{it:name}{cmd:)}}use the named Stata matrix as the source; row/column names become labels/headers{p_end}
{synopt:{opt varl:abels}}use variable labels (not names) for the header row of a dataset or frame source{p_end}
{synopt:{opt noh:eader}}omit the header row entirely{p_end}
{synopt:{opt dig:its(#)}}decimal places for numeric columns; default 2, range 0-6; also respects {cmd:tabtools set digits}{p_end}
{synoptline}

{dlgtab:Output}

{synoptset 26 tabbed}{...}
{synopt:{cmd:using} {it:filename}}target workbook; must end in {cmd:.xlsx}; the {opt sheet()} is created or replaced{p_end}
{synopt:{opt sh:eet(string)}}Excel sheet name (required){p_end}
{synopt:{opt csv(filename)} {opt markdown(filename)} {opt mdappend}}also write the assembled table to a CSV file{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{opt open}}open the Excel file after export{p_end}
{synoptline}

{dlgtab:Formatting}

{synoptset 26 tabbed}{...}
{synopt:{opt ti:tle(string)}}title written to the first row and merged across the table{p_end}
{synopt:{cmdab:foot:note(}{it:string}{cmd:)}}footnote below the table in smaller italic font{p_end}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}journal-style theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{cmdab:border:style(}{it:string}{cmd:)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{cmdab:headers:hade}}apply background fill to the header row{p_end}
{synopt:{cmdab:headerc:olor(}{it:string}{cmd:)}}custom header color as a named Excel color or RGB triplet (e.g., {cmd:"200 220 240"}){p_end}
{synopt:{cmdab:zebrac:olor(}{it:string}{cmd:)}}custom zebra stripe color as a named Excel color or RGB triplet{p_end}
{synopt:{opt zeb:ra}}alternating row shading over data rows{p_end}
{synoptline}

{marker examples}{...}
{title:Examples}

{pstd}{bf:Example 1: A collapse result, current data}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{cmd:. collapse (mean) price mpg (count) n=price, by(foreign)}{p_end}
{phang2}{cmd:. puttab foreign price mpg n using table.xlsx, sheet("ByOrigin") ///}{p_end}
{phang3}{cmd:title("Mean price and mpg by origin") theme(nejm) zebra varlabels digits(1)}{p_end}

{pstd}{bf:Example 2: A named frame}{p_end}
{phang2}{cmd:. frame put make mpg price in 1/10, into(top)}{p_end}
{phang2}{cmd:. puttab using table.xlsx, sheet("Top10") frame(top) ///}{p_end}
{phang3}{cmd:title("Ten cars") headershade borderstyle(academic)}{p_end}

{pstd}{bf:Example 3: A coefficient matrix}{p_end}
{phang2}{cmd:. regress price mpg weight foreign}{p_end}
{phang2}{cmd:. matrix T = r(table)'}{p_end}
{phang2}{cmd:. puttab using table.xlsx, sheet("Coefs") matrix(T) ///}{p_end}
{phang3}{cmd:title("OLS coefficients") digits(3)}{p_end}

{pstd}{bf:Example 4: Emit blocks, then assemble with stacktab}{p_end}
{phang2}{cmd:. puttab using parts.xlsx, sheet("A") matrix(MA) title("Model A")}{p_end}
{phang2}{cmd:. puttab using parts.xlsx, sheet("B") matrix(MB) title("Model B")}{p_end}
{phang2}{cmd:. stacktab using final.xlsx, sheet("Table 2") ///}{p_end}
{phang3}{cmd:blocks(sheet("A") \ sheet("B"))}{p_end}

{marker stored}{...}
{title:Stored results}

{pstd}{cmd:puttab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(n_rows)}}total rows written to the sheet (title + header + data + footnote){p_end}
{synopt:{cmd:r(n_cols)}}number of columns written{p_end}
{synopt:{cmd:r(n_datarows)}}number of data rows (excluding title, header, footnote){p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(source)}}source type: {cmd:data}, {cmd:frame}, or {cmd:matrix}{p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(file)}}Excel filename{p_end}
{synopt:{cmd:r(csv)}}CSV filename (if written){p_end}

{marker alsosee}{...}
{title:Also see}

{psee}
{helpb tabtools}, {helpb stacktab}, {helpb desctab}, {helpb regtab},
{helpb tabtools_cheatsheet}, {helpb export_excel:export excel}, {helpb putexcel}
{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.6.2{p_end}

{hline}

{smcl}
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

{p 4 8 2}{cmd:puttab} [{varlist}] [{it:if}] [{it:in}] [{cmd:using} {it:filename}{cmd:.xlsx}]{cmd:,}
[{opt sh:eet(string)}
{opt fra:me(name)} {opt m:atrix(matname)}
{opt ti:tle(string)} {opt foot:note(string)}
{opt font(string)} {opt fontsize(#)} {opt border:style(string)}
{opt headerc:olor(string)} {opt zebrac:olor(string)}
{opt zeb:ra} {opt headers:hade} {opt noheaders:hade}
{opt dig:its(#)} {opt nf:ormat(%fmt)} {opt varl:abels} {opt noh:eader} {opt noemb:edheader}
{opt hl:ines(numlist)} {opt vl:ines(numlist)} {opt bold:rows(numlist)}
{opt pan:el(varname)} {opt panelh:eader(spec)} {opt paneli:nline} {opt noind:ent} {opt span:header(spec)}
{opt block:header}
{opt csv(filename)} {opt mark:down(filename)} {opt mdapp:end} {opt open}]{p_end}

{pstd}The table source is exactly one of: a {it:varlist} of the current dataset
(required when no {opt frame()} or {opt matrix()} is given), a named
{opt frame()}, or a {opt matrix()}. A {it:varlist} may also subset a
{opt frame()}; it is not allowed with {opt matrix()}. {it:if} and {it:in}
restrict rows for the current-data or {opt frame()} source and are not allowed
with {opt matrix()}. With {opt frame()}, {it:if} and {it:in} are evaluated in
that frame, so they may name its variables and observation numbers whatever
the current frame holds.{p_end}

{pstd}A {it:key column}, a variable whose characteristic
{cmd:char} {it:var}{cmd:[tabtools_key]} is {cmd:1} (the row keys a table
producer adds for the caller's merges, such as {helpb regtab}'s
{cmd:frame(}{it:name}{cmd:, flat keys)}), is not exported unless the
{it:varlist} names it literally. Without a {it:varlist} (a {opt frame()}
source), or matched only by a wildcard or range such as {cmd:*} or
{cmd:rowlabel-c6}, it is left out of every sink and of {opt blockheader}, and
a note lists it. Key columns may still be used in {it:if} and to compute the
rows given to {opt hlines()} and {opt boldrows()}, which count the exported
data rows. Variables without the characteristic are unaffected.{p_end}

{pstd}Specify either {cmd:using} {it:filename}{cmd:.xlsx} for Excel output or
{opt markdown(filename)} for Markdown-only output. {opt open} requires an
Excel workbook target. After {cmd:tabtools set workbook} or
{cmd:tabtools set markdown}, either may be omitted; see
{it:Session destinations} below.{p_end}

{marker description}{...}
{title:Description}

{pstd}{cmd:puttab} renders a single, publication-styled table from data already in
memory: the current dataset, a named {helpb frames:frame}, or a Stata {it:matrix} such as {cmd:e(b)},
{cmd:r(table)}, or the result of a {helpb collapse} or {helpb tabulate}. With an Excel target, it
closes the gap between raw in-memory results and a formatted sheet, replacing
ad hoc {cmd:export excel ..., firstrow()} dumps and hand-built {helpb putexcel} blocks with
the shared tabtools geometry: a left-justified title in cell A1, a thin spacer
column A so the table body is always anchored at cell B2, a header rule,
optional header shading and zebra striping, automatic column widths, borders,
and an italic footnote.{p_end}

{pstd}For a {opt matrix()} source, the matrix row names become the first
(label) column and the column names become the header row, whose label-column
cell is blank in the workbook, CSV, and Markdown alike; equation names are
shown as {it:eqname:name}. For a dataset or {opt frame()} source, the variable
names form the header row (or the variable labels, with {opt varlabels}), and
numeric columns are formatted to {opt digits()} decimals. Integer-valued numeric
columns are written without decimals, and value labels are honored when
present. A column with a date or time display format ({cmd:%td}, {cmd:%tc},
{cmd:%tm}, and the other {cmd:%t} formats) is written through that format, for
example {cmd:01jan2020}, because {opt digits()} cannot describe a date. A column
whose display format ends in {cmd:fc} (for example {cmd:%12.0fc}) keeps
its thousands separators, with {opt digits()} still setting the decimals, so
{cmd:1234567} is written as {cmd:1,234,567}. Other display formats are not
used. {opt nformat()} sets the format of every integer-valued column at once. A value
that rounds to zero is written without a minus sign.{p_end}

{pstd}When an Excel workbook is written, the named {opt sheet()} is created if it does not
exist and replaced if it does (sheet names match regardless of case, and the
workbook's existing spelling is kept), so repeated calls to the same workbook build up
a multi-sheet file that {helpb stacktab} can then assemble. The current data, frames,
and matrices in memory are left unchanged.{p_end}

{marker options}{...}
{title:Options}

{dlgtab:Source}

{synoptset 26 tabbed}{...}
{synoptline}
{synopt:{opt fra:me(name)}}use a named frame as the source{p_end}
{synopt:{opt m:atrix(matname)}}use a matrix, {cmd:r()}, or {cmd:e()} matrix{p_end}
{synopt:{opt varl:abels}}use variable labels in the header row{p_end}
{synopt:{opt noh:eader}}omit the header row entirely{p_end}
{synopt:{opt noemb:edheader}}export a label-shaped first row as data{p_end}
{synopt:{opt dig:its(#)}}decimal places for numeric columns{p_end}
{synopt:{opt nf:ormat(%fmt)}}format for integer-valued columns{p_end}
{synoptline}

{dlgtab:Output}

{synoptset 26 tabbed}{...}
{synopt:{cmd:using} {it:filename}}optional Excel target workbook{p_end}
{synopt:{opt sh:eet(string)}}Excel sheet name; default is {cmd:Table}{p_end}
{synopt:{opt csv(filename)}}also write the assembled table to a CSV file{p_end}
{synopt:{opt markdown(filename)}}export as GitHub-Flavored Markdown{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file{p_end}
{synopt:{opt open}}open Excel output after export{p_end}
{synoptline}

{dlgtab:Formatting}

{synoptset 26 tabbed}{...}
{synopt:{opt ti:tle(string)}}set the table title in cell A1{p_end}
{synopt:{opt foot:note(string)}}add italic footnote text{p_end}
{synopt:{opt border:style(string)}}set the table border style{p_end}
{synopt:{opt font(string)}}set the Excel font family{p_end}
{synopt:{opt fontsize(#)}}set the Excel font size in points{p_end}
{synopt:{opt headers:hade}}shade the header row{p_end}
{synopt:{opt noheaders:hade}}no shading, even after {cmd:tabtools set}{p_end}
{synopt:{opt headerc:olor(string)}}set the header fill color{p_end}
{synopt:{opt zebrac:olor(string)}}set alternating-row fill color{p_end}
{synopt:{opt zeb:ra}}alternating row shading over data rows{p_end}
{synopt:{opt hl:ines(numlist)}}rule above the listed data rows{p_end}
{synopt:{opt vl:ines(numlist)}}rule right of the listed columns{p_end}
{synopt:{opt bold:rows(numlist)}}bold each listed data row{p_end}
{synopt:{opt pan:el(varname)}}heading row wherever {it:varname} changes{p_end}
{synopt:{opt panelh:eader(spec)}}header row repeated under each heading{p_end}
{synopt:{opt paneli:nline}}heading and panel header share one row{p_end}
{synopt:{opt noind:ent}}do not indent the row labels of a panel{p_end}
{synopt:{opt span:header(spec)}}spanning column labels above the header{p_end}
{synopt:{opt block:header}}model names of a flat frame above its header{p_end}
{synoptline}


{pstd}
{it:Detailed option contracts}{p_end}

{phang}
{opt csv(filename)} also write the assembled table to a CSV file. The CSV
mirrors the workbook with {opt title()} written as the first row and
{opt footnote()} as the last row, both in the first column and the table body
between them.{p_end}

{phang}
{opt dig:its(#)} decimal places for numeric columns; default 2, range 0-6; also respects
{cmd:tabtools set digits}{p_end}

{phang}
{opt nf:ormat(%fmt)} display format for integer-valued numeric columns, named
to match the {opt nformat()} option of {helpb desctab}; for example
{cmd:nformat(%12.0fc)} writes counts with thousands separators. It must be a
{cmd:%f} or {cmd:%g} format, optionally ending in {cmd:c}. The width is ignored,
so a large count never overflows to scientific notation. It applies to every
integer-valued column without a value label or a date format, a year or ID
column included; to add separators to some columns only, give those columns a
{cmd:%fc} display format instead. Columns with decimals still use
{opt digits()}. {opt nformat()} also applies to the columns of a {opt matrix()}
source.{p_end}

{phang}
{opt headers:hade} apply background fill to the header row{p_end}

{phang}
{opt noheaders:hade} leave the header row unshaded for this call even after
{cmd:tabtools set headershade on}; may not be combined with {opt headershade}.{p_end}

{phang}
{opt markdown(filename)} export the rendered table as GitHub-Flavored Markdown; may be combined with
Excel and CSV exports. Leading spaces of string cells in the first column are written as
{cmd:&nbsp;} so indented row labels keep their indentation; other cells are trimmed{p_end}

{phang}
{opt mdappend} append the Markdown table to an existing file; requires {opt markdown()}{p_end}

{phang}
{opt noh:eader} omit the header row entirely. A Markdown (GFM) table cannot omit its
header row, so in Markdown the first {opt panel()} row takes the header's place
when the table starts with one (a panel heading, a panel header, or a
{opt panelinline} row, which the workbook rules and bolds like a header); without
one the Markdown header row is left blank, so data never become a
header. {cmd:r(markdown_rows)} then counts the body below it. The workbook and
the CSV carry no header row.{p_end}

{phang}
{opt open} open the Excel file after export; requires {cmd:using}{p_end}

{phang}
{opt sh:eet(string)} Excel sheet name; default is {cmd:Table}{p_end}

{phang}
{opt ti:tle(string)} title written to cell A1, left-justified and merged across the table{p_end}

{phang}
{opt varl:abels} use variable labels (not names) for the header row of a dataset or frame
source. When the source is a tabtools table, such as the table {helpb desctab} or
{helpb table1_tc} returns through {cmd:clear} or {cmd:frame()}, its first observation repeats
those same variable labels as an embedded header. {cmd:puttab} recognizes that observation
by content and consumes it as the header row rather than writing the text twice: every
exported column must be a string variable, and every cell of the first observation must
equal its column's variable label, except that the first column may be blank. Any other
first observation, including one with a numeric column, is data. The observation is kept
when {opt noheader} is specified, or when {opt varlabels} is not, because nothing else then
carries the group labels. {it:if} and {it:in} refer to the source's own observation
numbers, before any embedded header is consumed, and the first observation is examined
only when it is inside the {it:if}/{it:in} selection; {cmd:in 1} therefore never exports
observation 2.{p_end}

{phang}
{opt noemb:edheader} turn off the embedded-header recognition described under
{opt varlabels}: the first observation is exported as a data row even when every cell
equals its column's variable label, and the header row is still built from the variable
labels. Use it for raw data whose first observation happens to match the labels.{p_end}

{phang}
{opt zeb:ra} alternating row shading over data rows{p_end}


{phang}
{opt border:style(string)} border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or
{cmd:academic}. {cmd:default}, {cmd:thin}, and {cmd:medium} draw a full box around the
table body (header row and data rows), rules above and below the header row, and a rule
right of the first (row-label) column, so the column headers and the row labels each sit
in their own box. {cmd:academic} draws horizontal rules only.{p_end}

{phang}
{opt hl:ines(numlist)} draws a horizontal rule above each listed data row. Data rows are
numbered 1, 2, ... in the order they are written below the header, after {it:if}/{it:in}
and after any embedded header row is consumed. Use it to separate a second table stacked
below the first in the same source. A row outside the table is an error. Excel output
only.{p_end}

{phang}
{opt vl:ines(numlist)} draws a vertical rule right of each listed column, from the header
row to the last data row. Columns are numbered as exported, with the row-label (first)
column as 1. A column outside the table is an error. Excel output only.{p_end}

{phang}
{opt bold:rows(numlist)} bolds each listed data row, numbered as for {opt hlines()}; for
example, the sub-header row of a second stacked table. A row outside the table is an
error. Excel output only.{p_end}

{pstd}
{opt hlines()} and {opt vlines()} use the table's border weight (medium under
{cmd:borderstyle(medium)}, otherwise thin) and apply under every border style, including
{cmd:academic}.{p_end}

{phang}
{opt font(string)} sets the Excel font family, and {opt fontsize(#)} sets its
point size from 1 through 72. The defaults are {cmd:Arial} and {cmd:10}.{p_end}

{phang}
{opt foot:note(string)} footnote below the table in smaller italic font. The literal
token {cmd:\}, with a space on each side, separates paragraphs: each
paragraph is its own wrapped, merged row in the workbook, its own row in the CSV, and its
own italic paragraph in Markdown. A footnote without the token is one row, as before. Empty
paragraphs are dropped. The same rule applies to {opt footnote()} in every tabtools
command.{p_end}

{phang}
{opt pan:el(varname)} splits the table into panels. Wherever {it:varname} changes from
one observation to the next (in the order the rows are exported), a heading row is
inserted that holds the panel's value label, or its value when it has none (a string
{it:varname} gives its text). In the workbook the heading row is bold and ruled above, its
text in the row-label column, which is widened to fit it, and the other cells blank (not
merged); the row labels of the panel's rows are indented by three spaces
(written as {cmd:&nbsp;} in Markdown, where the heading is bold). A panel whose value is
missing or blank gets no heading and no indent; {opt noindent} drops the indent for every
panel. {it:varname} is never exported, even if it
is also in {it:varlist}. Not allowed with {opt matrix()}. Heading rows count as data rows
for {opt hlines()}, {opt boldrows()}, {opt zebra}, and {cmd:r(n_datarows)}.{p_end}

{phang}
{opt panelh:eader(spec)} gives the header row of each panel. {it:spec} is either a
{it:varlist} or literal text. A literal {it:spec}, recognized by its opening quote, gives one
quoted string per exported column, for example
{cmd:panelheader("" "Events" "Person-years")}. It writes the same header row under every
panel heading, and the strings may contain quotes when compound-quoted. A {it:varlist}
names one string variable per exported column. At the first
row of each panel, their values form a header row written under the panel heading, in
bold with a rule below (shaded with {opt headershade}); a panel whose values are all blank
gets none. Use it when panels have different column meanings, such as counts and
person-years in one panel and scans and percentages in the next. The variables are never
exported. Requires {opt panel()}.{p_end}

{phang}
{opt paneli:nline} writes each panel heading and that panel's {opt panelheader()} row as
one row: the heading text takes the first cell of the panel header row, and the other
cells keep their header text, as in {cmd:Panel A | Events | Person-years}. The first cell
of the panel header (the row-label column) must therefore be blank for every panel that
has a heading; text there is an error (198), never overwritten. The shared row is bold,
ruled above (as a heading) and below (as a header), shaded with {opt headershade}, and not
merged across the table. CSV and Markdown get the same single row (bold in Markdown). A
panel with a heading but an all-blank header keeps its separate heading row; a panel
without a heading keeps its separate header row. The row labels under a heading are still
indented unless {opt noindent} is given. Shared rows count in {cmd:r(n_panels)} and as
data rows. Requires {opt panelheader()}.{p_end}

{phang}
{opt noind:ent} leaves the row labels under a panel heading unindented in every
sink. Requires {opt panel()}.{p_end}

{phang}
{opt span:header(spec)} adds a row of spanning labels above the header
row. {it:spec} is {cmd:"}{it:label}{cmd:"} {it:first}[{cmd:/}{it:last}] [{cmd:\}
{cmd:"}{it:label}{cmd:"} {it:first}[{cmd:/}{it:last}] ...],
where columns are numbered as exported with the row-label column as 1; for example
{cmd:spanheader("Narcolepsy" 2/3 \ "Risk ratio (95% CI)" 4/5)}. In the workbook each label
is merged across its columns, centred, bold, and ruled below, and the table's top rule
moves above the span row. The CSV carries the span row with each label in its first
column. Markdown tables have a single header row, so there each spanned column's header
reads {it:label}{cmd:, }{it:header}. Columns outside the table (r(125)), overlapping spans,
a range that ends before it starts, an unquoted or empty label, and {opt noheader} are
errors.{p_end}

{phang}
{opt blockheader} writes the block (model) names of a flat frame from
{helpb regtab} ({cmd:frame(}{it:name}{cmd:, flat)}) as a spanning row above the
header row of statistic labels, so each model's name sits over its own
columns. (Under {cmd:transpose}, and in an {helpb effecttab} flat frame, each
column's label already holds its full header and there are no block names.) The names come from each exported column's
{cmd:char c}{it:#}{cmd:[tabtools_block]}, and the columns of one block are found
from {cmd:char c}{it:#}{cmd:[tabtools_block_id]}, which identifies the block
(never from equal names, so two models that share a name stay apart). The
header row is the variable labels, so {opt blockheader} implies
{opt varlabels}. It reuses {opt spanheader()}'s layout in every sink: in the
workbook each name is merged across its block's columns, centred, bold, and
ruled below; the CSV carries the name row with each name in its block's first
column; and Markdown, which has one header row, reads {it:model}{cmd:, }{it:statistic}
in each header cell, the full header the frame keeps in
{cmd:char c}{it:#}{cmd:[tabtools_header]}. A column without the characteristic
(the row-label column, or a column added to the frame) has a blank cell in the
name row; a named column without a block identifier is a block of its own; and
when no exported column has a name, no row is added (a note says so). Not
allowed with {opt noheader}, {opt spanheader()}, or {opt matrix()}. A
two-row header is used rather than the joined header as one row because the
model name is then written once per model, as {cmd:regtab} prints it, and
Markdown still receives the joined form.{p_end}

{phang}
{opt fra:me(name)} use the named frame as the source instead of the current dataset{p_end}

{phang}
{opt headerc:olor(string)} custom header color as a supported Stata color name or RGB
triplet (e.g., {cmd:"200 220 240"}){p_end}

{phang}
{opt m:atrix(matname)} use a Stata matrix as the source; row/column names become
labels/headers. {it:matname} is a matrix name, {cmd:r(}{it:name}{cmd:)}, or
{cmd:e(}{it:name}{cmd:)}, for example {cmd:matrix(r(table))} or
{cmd:matrix(e(b))}, and a returned matrix must exist when {cmd:puttab} is called{p_end}

{phang}
{opt zebrac:olor(string)} custom zebra stripe color as a supported Stata color name
or RGB triplet{p_end}

{pstd}
{it:Session destinations}{p_end}

{pstd}After {cmd:tabtools set workbook "}{it:file}{cmd:.xlsx"}, {cmd:puttab} writes to that
workbook whenever {cmd:using} is omitted; after {cmd:tabtools set markdown "}{it:file}{cmd:.md"},
it writes Markdown there whenever {opt markdown()} is omitted; after
{cmd:tabtools set headershade on}, it shades the header row. Each call that uses a session
setting says so in the log, e.g. {cmd:(tabtools: using session workbook "out.xlsx")}. An
explicit {cmd:using}, {opt markdown()}, {opt headershade}, or {opt noheadershade} always wins
for that call; the session headershade is honoured by {cmd:puttab} only. Session paths are
stored absolute ({cmd:.} and {cmd:..} resolved; symbolic links and letter case are not), so
a later {cmd:cd} does not move them. The
first write to a session workbook after {cmd:tabtools set workbook} erases the file and
starts it over; later writes add or replace sheets. The first write to a session Markdown
file overwrites it; later writes append, as does an explicit {opt mdappend}. A table any
tabtools command writes to the session file with an explicit {cmd:using}, {opt xlsx()}, or
{opt markdown()} (the same file, however its path is spelled) counts as that first write,
so a later session write never erases it. Setting a different file with
{cmd:tabtools set workbook} or {cmd:tabtools set markdown} re-arms the replace; setting the
current file again changes nothing; and a file any tabtools command already wrote in this
Stata session is never replaced, so switching A, then B, then back to A keeps A's tables. See
{helpb tabtools} for {cmd:tabtools set} and {cmd:tabtools query}.{p_end}

{marker examples}{...}
{title:Examples}

{pstd}{bf:Example 1: A collapse result, current data}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. collapse (mean) price mpg (count) n=price, by(foreign)}{p_end}
{phang2}{cmd:. puttab foreign price mpg n using table.xlsx, sheet("ByOrigin") ///}{p_end}
{phang3}{cmd:title("Mean price and mpg by origin") zebra varlabels digits(1)}{p_end}

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
{phang2}{cmd:. matrix MA = (1.23, 1.05, 1.44)}{p_end}
{phang2}{cmd:. matrix colnames MA = HR LL UL}{p_end}
{phang2}{cmd:. matrix MB = (1.67, 1.30, 2.15)}{p_end}
{phang2}{cmd:. matrix colnames MB = HR LL UL}{p_end}
{phang2}{cmd:. puttab using parts.xlsx, sheet("A") matrix(MA) title("Model A")}{p_end}
{phang2}{cmd:. puttab using parts.xlsx, sheet("B") matrix(MB) title("Model B")}{p_end}
{phang2}{cmd:. stacktab using parts.xlsx, sheet("Table 2") ///}{p_end}
{phang3}{cmd:blocks(sheet("A") \ sheet("B"))}{p_end}

{pstd}{bf:Example 5: Two tables stacked in one source}{p_end}
{pstd}Data row 3 is the second table's own header: rule it off above and below and set it
in bold. Use {helpb stacktab} instead when the parts are already separate sheets.{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str12 group str6 n str8 price}{p_end}
{phang2}{cmd:. "Domestic" "52" "6,072"}{p_end}
{phang2}{cmd:. "Foreign" "22" "6,385"}{p_end}
{phang2}{cmd:. "Repair" "N" "Price"}{p_end}
{phang2}{cmd:. "Good (4-5)" "29" "6,013"}{p_end}
{phang2}{cmd:. "Poor (1-3)" "40" "6,118"}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. puttab group n price using table.xlsx, sheet("Stacked") ///}{p_end}
{phang3}{cmd:title("Price by origin and repair") hlines(3 4) boldrows(3)}{p_end}

{pstd}{bf:Example 6: Panels with their own column headers, a spanning header, and a two-paragraph note}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str16 row str6(c1 c2) byte blk str12(h0 h1 h2)}{p_end}
{phang2}{cmd:. "Under 55" "12" "310" 1 "" "Relapses" "Person-years"}{p_end}
{phang2}{cmd:. "55 and over" "9" "280" 1 "" "Relapses" "Person-years"}{p_end}
{phang2}{cmd:. "Repleted" "40" "18" 2 "" "Scans" "Percent"}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. label define blk 1 "A. Relapses" 2 "B. New MRI activity"}{p_end}
{phang2}{cmd:. label values blk blk}{p_end}
{phang2}{cmd:. puttab row c1 c2 using table.xlsx, sheet("Panels") noheader ///}{p_end}
{phang3}{cmd:panel(blk) panelheader(h0 h1 h2) title("Table 3") ///}{p_end}
{phang3}{cmd:footnote("Counts are crude. \ Ratios are adjusted.")}{p_end}
{phang2}{cmd:. puttab row c1 c2 using table.xlsx, sheet("Inline") noheader ///}{p_end}
{phang3}{cmd:panel(blk) panelheader(h0 h1 h2) panelinline title("Table 3")}{p_end}
{phang2}{cmd:. label variable c1 "Events"}{p_end}
{phang2}{cmd:. label variable c2 "Exposure"}{p_end}
{phang2}{cmd:. puttab row c1 c2 using table.xlsx, sheet("Spans") varlabels ///}{p_end}
{phang3}{cmd:spanheader("Counts" 2/3)}{p_end}

{pstd}{bf:Example 7: Session destinations}{p_end}
{phang2}{cmd:. tabtools set workbook "tables.xlsx"}{p_end}
{phang2}{cmd:. tabtools set markdown "tables.md"}{p_end}
{phang2}{cmd:. tabtools set headershade on}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. puttab make price in 1/5, sheet("Prices") title("Five cars")}{p_end}
{phang2}{cmd:. puttab make mpg in 1/5, sheet("Mileage") title("Five cars")}{p_end}
{phang2}{cmd:. tabtools set clear}{p_end}

{pstd}{bf:Example 8: Thousands separators}{p_end}
{pstd}{opt nformat()} formats every integer-valued column; a {cmd:%fc} display
format adds separators to one column only, and {opt digits()} still sets its
decimals.{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. collapse (sum) price weight (mean) mpg, by(foreign)}{p_end}
{phang2}{cmd:. puttab foreign price weight mpg using table.xlsx, sheet("Totals") ///}{p_end}
{phang3}{cmd:nformat(%12.0fc) digits(1)}{p_end}
{phang2}{cmd:. format weight %12.0fc}{p_end}
{phang2}{cmd:. puttab foreign price weight mpg using table.xlsx, sheet("Weight")}{p_end}

{pstd}{bf:Example 9: Model names over a regtab flat frame}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: logit foreign mpg}{p_end}
{phang2}{cmd:. collect: logit foreign mpg weight}{p_end}
{phang2}{cmd:. regtab, frame(models, replace flat) models("Crude" \ "Adjusted")}{p_end}
{phang2}{cmd:. frame models: puttab rowlabel c* using table.xlsx, sheet("Models") ///}{p_end}
{phang3}{cmd:blockheader markdown(models.md)}{p_end}

{marker stored}{...}
{title:Stored results}

{pstd}{cmd:puttab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(n_rows)}}assembled rows, including title/header/footnote{p_end}
{synopt:{cmd:r(n_cols)}}content columns, excluding the layout spacer column A{p_end}
{synopt:{cmd:r(n_datarows)}}data rows, incl. {opt panel()} rows{p_end}
{synopt:{cmd:r(n_panels)}}number of {opt panel()} heading rows, incl. shared rows{p_end}
{synopt:{cmd:r(n_spans)}}spans of {opt spanheader()} or {opt blockheader} (0 without){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(source)}}source type: {cmd:data}, {cmd:frame}, or {cmd:matrix}{p_end}
{synopt:{cmd:r(sheet)}}sheet name as spelled in the workbook{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(file)}}Excel filename, when an Excel workbook was written{p_end}
{synopt:{cmd:r(csv)}}CSV filename (if written){p_end}

{marker alsosee}{...}
{title:Also see}

{psee}
{helpb tabtools}, {helpb stacktab}, {helpb desctab}, {helpb regtab},
{helpb tabtools_tips}, {helpb export_excel:export excel}, {helpb putexcel}
{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}

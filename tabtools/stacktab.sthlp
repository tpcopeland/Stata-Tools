{smcl}
{* *! version 1.6.1  08jun2026}{...}
{viewerjumpto "Package overview" "stacktab##package"}{...}
{viewerjumpto "Syntax" "stacktab##syntax"}{...}
{viewerjumpto "Description" "stacktab##description"}{...}
{viewerjumpto "Examples" "stacktab##examples"}{...}
{viewerjumpto "Stored results" "stacktab##stored"}{...}
{viewerjumpto "Also see" "stacktab##alsosee"}{...}
{viewerjumpto "Author" "stacktab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "comptab" "help comptab"}{...}
{hline}
Help for {hi:stacktab}{right:(tabtools)}
{hline}

{title:Title}

{p 4 4 2}
{bf:stacktab} {hline 2} Assemble multi-sheet composite Excel tables from source blocks

{marker package}{...}
{title:Package}

{p 4 4 2}
{cmd:stacktab} is part of the {helpb tabtools} suite. It is the assembly end of
the styled-export pipeline: emit one styled block per sheet with {helpb puttab}
(from a dataset, frame, or matrix), then stack or place those sheets side by side
into one composite sheet with {cmd:stacktab}. {cmd:stacktab} was previously
distributed as the standalone command {cmd:xlsxcompose}; that name is retained as
a deprecated alias.

{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:stacktab} {cmd:using} {it:outbook.xlsx}{cmd:,}
  {opt bl:ocks(blockspec)}
  {opt sheet:(sheetname)}
  [{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt bl:ocks(blockspec)}}backslash-separated block definitions{p_end}
{synopt:{opt sheet:(string)}}output sheet name in the workbook{p_end}

{syntab:Content}
{synopt:{opt lay:out(string)}}vstack (default) or hstack{p_end}
{synopt:{opt ti:tle(string)}}title written to cell {cmd:A1}; the table starts at {cmd:B2}{p_end}
{synopt:{opt no:te(string)}}note row written below the table in the first table column{p_end}
{synopt:{opt foot:note(string)}}tabtools-style alias for {opt note()}{p_end}
{synopt:{opt col:umnmerge(mergespec)}}concatenate column pairs with header label{p_end}
{synopt:{opt sp:acing(#)}}blank rows inserted between vertically stacked blocks; default is 0{p_end}

{syntab:Formatting}
{synopt:{opt style:(stylespec)}}row heights and table-relative column widths via Mata {cmd:xl()}{p_end}
{synopt:{opt borders:(borderspec)}}border specifications via Mata {cmd:xl()}{p_end}

{syntab:Additional outputs}
{synopt:{opt fra:me(framespec)}}store the composed table in a Stata frame; use {cmd:frame("name, replace")} to replace{p_end}
{synopt:{opt csv(filename)} {opt markdown(filename)} {opt mdappend}}export the composed table to CSV{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{opt dis:play}}list the composed table in the Results window before writing{p_end}
{synopt:{opt app:end}}append rows below an existing output sheet{p_end}
{synopt:{opt sheet:replace}}replace the output sheet if it exists{p_end}
{synoptline}

{marker description}{...}
{title:Description}

{p 4 4 2}
{cmd:stacktab} imports row/column blocks from named sheets in {it:outbook.xlsx},
stacks them (vstack) or places them side-by-side (hstack), applies column-merge
transforms, and exports the composite to a new sheet in the same workbook using
the tabtools Excel layout. The title is written to {cmd:A1}, and the main table
starts at {cmd:B2}.

{title:Block specification}

{p 4 4 2}
{opt blocks()} takes backslash-separated block definitions. Each block can contain:

{p 8 8 2}
{it:sheet(SheetName)} — source sheet name (required per block){break}
{it:rows(lo/hi)} — row range to import, e.g. {it:rows(1/3)}{break}
{it:cols(A-D)} — column range, e.g. {it:cols(B-D)}{break}
{it:label(text)} — overwrite the first-row first-column cell with this text{break}
{it:skip(N)} — drop the Nth row within the imported block{break}
{it:postfix(text)} — append text to all cells in the first column

{p 4 4 2}
Block text containing spaces can be supplied without inner double quotes, for
example {cmd:label(Binary HRT)}. Use doubled parentheses for literal
parentheses, for example {cmd:postfix((vs none))}.

{p 4 4 2}
{opt rows()} and {opt cols()} may be used together or separately. With
{opt cols()} alone, {cmd:stacktab} imports the full source sheet and keeps
only the selected Excel columns.

{p 8 8 2}
Example:

{p 12 16 2}
{cmd:blocks(} {break}
{cmd:    sheet(Table S3) rows(1/3) cols(B-D) label(Binary HRT) \} {break}
{cmd:    sheet(Table S4) rows(3/7) cols(B-D) skip(2) label(Dose categories))}

{title:Column merge specification}

{p 4 4 2}
{opt columnmerge()} concatenates pairs of columns separated by {it:+} with a header
label. Columns can be Excel letters, such as {cmd:B+C}, or internal names, such
as {cmd:_xcol2+_xcol3}. Merge rules are separated by {it:\}.
Malformed merge rules exit with an error instead of silently passing through.

{p 8 8 2}Example:{p_end}
{p 12 16 2}
{cmd:columnmerge(B+C as "aHR (95% CI)" \ F+G as "aHR (95% CI)")}

{title:Append and replace behavior}

{p 4 4 2}
If the output sheet already exists, specify either {opt append} or
{opt sheetreplace}. Without either option, {cmd:stacktab} refuses to
overwrite existing cells. {opt append} writes below the existing used worksheet
rows using the same table column offset, and {opt sheetreplace} recreates the
sheet from row 1.

{title:Style specification}

{p 4 4 2}
{opt style()} accepts any combination of:
{it:titlerowheight(#)}, {it:noterowheight(#)}, and
{it:colwidth(letter # \ ...)}. Column letters in {opt colwidth()} are relative
to the composed table, so {cmd:colwidth(A 24)} changes Excel column {cmd:B}.
The border specification currently supports {cmd:outer(all)},
{cmd:top(row 1)}, and {cmd:bottom(last)}.

{title:Frame and CSV output}

{p 4 4 2}
{opt frame()} stores the composed table before Excel and Markdown export. Title and note
cells are Excel-only formatting elements and are not added to the frame or CSV.
Specify
{cmd:frame("myframe, replace")} to replace an existing frame. {opt csv()}
writes the same composed table to a delimited file and requires a {cmd:.csv}
extension.

{marker examples}{...}
{title:Examples}

{p 4 4 2}
Use {helpb puttab} to write each styled source block to its own sheet, then
{cmd:stacktab} to assemble those sheets:

{p 8 12 2}
{cmd:. puttab using parts.xlsx, sheet("A") matrix(MA) title("Model A")}{break}
{cmd:. puttab using parts.xlsx, sheet("B") matrix(MB) title("Model B")}{break}
{cmd:. stacktab using final.xlsx, sheet("Table 2") blocks(sheet(A) \ sheet(B))}

{marker stored}{...}
{title:Stored results}

{synoptset 22}{...}
{synopt:{cmd:r(blocks_loaded)}}number of blocks imported{p_end}
{synopt:{cmd:r(rows_written)}}rows written by the current call{p_end}
{synopt:{cmd:r(rows_out)}}last worksheet row occupied by the written table, excluding note row{p_end}
{synopt:{cmd:r(cols_out)}}columns in the composed table{p_end}
{synopt:{cmd:r(append_start)}}first Excel row of the table body written by the current call{p_end}
{synopt:{cmd:r(note_row)}}Excel row of the note/footnote, when specified{p_end}
{synopt:{cmd:r(layout)}}layout used: {cmd:vstack} or {cmd:hstack}{p_end}
{synopt:{cmd:r(sheet)}}output sheet name{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(book)}}workbook path{p_end}
{synopt:{cmd:r(table_start)}}top-left Excel cell of the composed table, usually {cmd:B2}{p_end}
{synopt:{cmd:r(title_cell)}}title cell, when {opt title()} is specified{p_end}
{synopt:{cmd:r(frame)}}frame name, when {opt frame()} is specified{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(csv)}}CSV path, when {opt csv()} is specified{p_end}

{marker alsosee}{...}
{title:Also see}

{psee}
{helpb tabtools}, {helpb puttab}, {helpb comptab}, {helpb hrcomptab},
{helpb tabtools_cheatsheet}
{p_end}

{marker author}{...}
{title:Author}

{p 4 4 2}
Timothy P Copeland, Karolinska Institutet{break}
{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{break}
Version 1.6.1
{p 4 4 2}
{hline}

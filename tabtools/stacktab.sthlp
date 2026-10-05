{smcl}
{viewerjumpto "Package overview" "stacktab##package"}{...}
{viewerjumpto "Syntax" "stacktab##syntax"}{...}
{viewerjumpto "Options" "stacktab##options"}{...}
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
{cmd:stacktab} is part of the {helpb tabtools} suite. It is the assembly end of the
styled-export pipeline: emit one styled block per sheet with {helpb puttab} (from a
dataset, frame, or matrix), then stack or place those sheets side by side into
one composite sheet with {cmd:stacktab}.

{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:stacktab} [{cmd:using} {it:outbook.xlsx}]{cmd:,}
  {opt bl:ocks(blockspec)}
  {opt sh:eet(sheetname)}
  [{it:options}]

{pstd}Stack in-memory frames as labelled panels:{p_end}

{p 8 16 2}
{cmd:stacktab} [{cmd:using} {it:outbook.xlsx}]{cmd:,}
  {opt frames(name ["label"] [\ name ["label"] ...])}
  {opt sh:eet(sheetname)}
  [{opt ti:tle()} {opt no:te()}|{opt foot:note()} {opt csv()} {opt mark:down()} {opt mdapp:end}
  {opt headers:hade} {opt border:style()} {opt font()} {opt fontsize()} {opt zeb:ra} {opt dig:its()} {opt open}]

{marker options}{...}
{title:Options}

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt bl:ocks(blockspec)}}backslash-separated block definitions{p_end}
{synopt:{opt sh:eet(string)}}output sheet name in the workbook{p_end}

{syntab:Content}
{synopt:{opt lay:out(string)}}vstack (default) or hstack{p_end}
{synopt:{opt ti:tle(string)}}title written to cell {cmd:A1}; the table starts at {cmd:B2}{p_end}
{synopt:{opt no:te(string)}}note row below the table{p_end}
{synopt:{opt foot:note(string)}}tabtools-style alias for {opt note()}{p_end}
{synopt:{opt col:umnmerge(mergespec)}}concatenate column pairs with header label{p_end}
{synopt:{opt sp:acing(#)}}blank rows between vertical blocks{p_end}

{syntab:Formatting}
{synopt:{opt st:yle(stylespec)}}row heights and table-relative widths{p_end}
{synopt:{opt bo:rders(borderspec)}}border specifications via Mata {cmd:xl()}{p_end}

{syntab:Additional outputs}
{synopt:{opt fra:me(framespec)}}store the composed table in a Stata frame{p_end}
{synopt:{opt csv(filename)}}export the composed table to CSV{p_end}
{synopt:{opt mark:down(filename)}}export as GitHub-Flavored Markdown{p_end}
{synopt:{opt mdapp:end}}append the Markdown table to an existing file{p_end}
{synopt:{opt dis:play}}list the composed table in Results{p_end}
{synopt:{opt app:end}}append rows below an existing output sheet{p_end}
{synopt:{opt she:etreplace}}replace the output sheet if it exists{p_end}
{synoptline}


{pstd}
{it:Detailed option contracts}{p_end}

{phang}
{opt app:end} append rows below an existing output sheet{p_end}

{phang}
{opt bl:ocks(blockspec)} backslash-separated block definitions{p_end}

{phang}
{opt bo:rders(borderspec)} border specifications via Mata {cmd:xl()}{p_end}

{phang}
{opt col:umnmerge(mergespec)} concatenate column pairs with header label{p_end}

{phang}
{opt csv(filename)} export the composed table to CSV. The CSV mirrors the
workbook with {opt title()} written as the first row and {opt footnote()} as
the last row, both in the first column and the table body between them.{p_end}

{phang}
{opt dis:play} list the composed table in the Results window before writing{p_end}

{phang}
{opt foot:note(string)} tabtools-style alias for {opt note()}. In {opt note()} and
{opt footnote()} the literal token {cmd:\}, with a space on each side, separates
paragraphs: one note row per paragraph in the workbook and CSV, one italic paragraph each
in Markdown.{p_end}

{phang}
{opt frames(name ["label"] [\ ...])} stacks frames that are already in memory, such as
the {opt frame()} output of {helpb table1_tc} or {helpb desctab} for two units of analysis,
without exporting them to sheets first. Each frame is one panel, in the order listed; its
label becomes a bold heading row with a rule above, and the row labels under it are
indented, exactly as {helpb puttab:puttab, panel()} draws them (a frame given no label, or
{cmd:""}, gets no heading). Columns are stacked by position, so every frame must have the
same number of columns; the header row comes from the first frame's variable labels
(variable names where a label is empty). A first observation that only repeats the
variable labels -- the embedded header of a {cmd:clear} or {cmd:frame()} table -- is dropped
from each frame. Numeric columns are written through their value labels or display
formats. {cmd:using} names the output workbook (it need not exist) and may be omitted after
{cmd:tabtools set workbook}. A frame that does not exist (r(111)), a frame listed twice,
frames with different column counts, and {opt blocks()}, {opt layout()},
{opt columnmerge()}, {opt style()}, {opt borders()}, {opt spacing()}, {opt frame()},
{opt display}, {opt append}, or {opt sheetreplace} in the same call are errors. The sheet is
created or replaced. Results are those of {helpb puttab} plus {cmd:r(n_frames)} and
{cmd:r(frames)}.{p_end}

{phang}
{opt fra:me(framespec)} store the composed table in a Stata frame; use {cmd:frame("name, replace")}
to replace{p_end}

{phang}
{opt lay:out(string)} vstack (default) or hstack{p_end}

{phang}
{opt markdown(filename)} export the rendered table as GitHub-Flavored Markdown; may be combined with
Excel, CSV, and frame exports{p_end}

{phang}
{opt mdappend} append the Markdown table to an existing file; requires {opt markdown()}{p_end}

{phang}
{opt no:te(string)} note row written below the table in the first table column{p_end}

{phang}
{opt sh:eet(string)} output sheet name in the workbook{p_end}

{phang}
{opt she:etreplace} replace the output sheet if it exists{p_end}

{phang}
{opt sp:acing(#)} blank rows inserted between vertically stacked blocks; default is 0{p_end}

{phang}
{opt st:yle(stylespec)} row heights and table-relative column widths via Mata {cmd:xl()}{p_end}

{phang}
{opt ti:tle(string)} title written to cell {cmd:A1}; the table starts at {cmd:B2}{p_end}

{marker description}{...}
{title:Description}

{p 4 4 2}
{cmd:stacktab} imports row/column blocks from named sheets in {it:outbook.xlsx},
stacks them (vstack) or places them side-by-side (hstack), applies column-merge
transforms, and exports the composite to a new sheet in the same workbook using
the tabtools Excel layout. The title is written to {cmd:A1}, and the main table
starts at {cmd:B2}. After {cmd:tabtools set workbook}, {cmd:using} may be omitted:
the session workbook is then both the source of the blocks and the target sheet,
and the first-write replace of a session workbook never applies, because
{cmd:stacktab} reads the book it writes. Without {cmd:using} and without a session
workbook, {cmd:stacktab} exits with r(100).

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
A value may instead be enclosed in double quotes, which are removed, for example
{cmd:label("Binary HRT")} or {cmd:sheet("Table S3")}; quoted text may contain
parentheses and backslashes, which are then taken literally. Suboptions are
recognized only at the top level of a block, so text inside another suboption,
such as {cmd:label(rows(3/3))}, is never read as a row selection. Each suboption
may appear at most once per block, and any other text, including an unknown
suboption such as {cmd:rowz()}, is an error (r(198)).

{p 4 4 2}
{opt rows()} and {opt cols()} may be used together or separately. Both count
in sheet coordinates: {cmd:rows(2/3)} means Excel rows 2 and 3 and
{cmd:cols(B-D)} Excel columns B to D, whether or not the other option is
given, and whether or not the sheet's content starts in row 1. With
{opt cols()} alone, {cmd:stacktab} imports the full source sheet and keeps
only the selected Excel columns; with {opt rows()} alone, it keeps only the
selected Excel rows.

{p 4 4 2}
In vertically stacked Excel output, the first row of each imported block is
treated as a section/header row: it is bolded and receives thin top and bottom
borders. This keeps multi-block tables visually separated after {opt label()},
{opt postfix()}, or {opt columnmerge()} reshape the block headers.

{p 8 8 2}
Example:

{p 12 16 2}
{cmd:blocks(} {break}
{cmd:    sheet(Table S3) rows(1/3) cols(B-D) label(Binary HRT) \} {break}
{cmd:    sheet(Table S4) rows(3/7) cols(B-D) skip(2) label(Dose categories))}

{title:Column merge specification}

{p 4 4 2}
{opt columnmerge()} concatenates pairs of columns separated by {it:+} with a header
label. Columns can be Excel letters, such as {cmd:B+C}, or internal names, such as
{cmd:_xcol2+_xcol3}. Merge rules are separated by {it:\}; a {it:\} inside the quoted
header is part of the header. The header is written exactly as typed, including
backticks, dollar signs, and quotes. Malformed merge rules exit with an error instead of
silently passing through.

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
{opt style()} accepts any combination of: {it:titlerowheight(#)}, {it:noterowheight(#)}, and
{it:colwidth(letter # \ ...)}, each at most once; list several columns inside one
{it:colwidth()}. Any other text, or a repeated group, is an error, and nothing is
written. Column letters in {opt colwidth()} are relative to the
composed table, so {cmd:colwidth(A 24)} changes Excel column {cmd:B}. Option
names inside {opt style()} and {opt borders()} are not case-sensitive. The border
specification supports {cmd:outer(all)}, {cmd:top(row 1)}, {cmd:bottom(last)},
and {cmd:bottom(row} {it:#}{cmd:)}, which draws a thin rule under row {it:#} of
the composed table (row 1 is its first row; repeat the token for several
rows). A {it:#} outside the table is an error, and nothing is written.

{title:Frame and CSV output}

{p 4 4 2}
{opt frame()} stores the composed table without the title and note, which are
Excel formatting elements there. Specify {cmd:frame("myframe, replace")} to
replace an existing frame. {opt csv()} writes the same composed table to a
delimited file, with {opt title()} as its first row and {opt note()} as its
last row (both in the first column), and requires a {cmd:.csv} extension. All requested destinations are staged and committed together, so a
failed export leaves existing frames and files unchanged. An existing
{opt markdown()} file is replaced; specify {opt mdappend} to append to it
instead. The workbook, {opt csv()} and {opt markdown()} must name different
files.

{marker examples}{...}
{title:Examples}

{p 4 4 2}
Use {helpb puttab} to write each styled source block to its own sheet, then
{cmd:stacktab} to assemble those sheets:

{p 8 12 2}
{cmd:. matrix MA = (1.23, 1.05, 1.44)}{break}
{cmd:. matrix colnames MA = HR LL UL}{break}
{cmd:. matrix MB = (1.67, 1.30, 2.15)}{break}
{cmd:. matrix colnames MB = HR LL UL}{break}
{cmd:. puttab using parts.xlsx, sheet("A") matrix(MA) title("Model A")}{break}
{cmd:. puttab using parts.xlsx, sheet("B") matrix(MB) title("Model B")}{break}
{cmd:. stacktab using parts.xlsx, sheet("Table 2") blocks(sheet(A) \ sheet(B))}

{p 4 4 2}
Stack two {cmd:table1_tc} frames, one per unit of analysis, as panels:

{p 8 12 2}
{cmd:. sysuse auto, clear}{break}
{cmd:. table1_tc, by(foreign) vars(mpg contn \ rep78 cat) frame(t_all, replace)}{break}
{cmd:. table1_tc if price > 5000, by(foreign) vars(mpg contn \ rep78 cat) frame(t_exp, replace)}{break}
{cmd:. stacktab using parts.xlsx, sheet("Table 1") title("Table 1") ///}{break}
{cmd:      frames(t_all "All cars" \ t_exp "Cars over 5,000 dollars")}

{marker stored}{...}
{title:Stored results}

{synoptset 22}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(blocks_loaded)}}number of blocks imported{p_end}
{synopt:{cmd:r(rows_written)}}rows written by the current call{p_end}
{synopt:{cmd:r(rows_out)}}last worksheet row written{p_end}
{synopt:{cmd:r(cols_out)}}columns in the composed table{p_end}
{synopt:{cmd:r(append_start)}}first row of the appended table body{p_end}
{synopt:{cmd:r(note_row)}}Excel row of the note/footnote, when specified{p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(layout)}}layout used: {cmd:vstack} or {cmd:hstack}{p_end}
{synopt:{cmd:r(sheet)}}output sheet name{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(book)}}workbook path{p_end}
{synopt:{cmd:r(table_start)}}top-left cell of the composed table{p_end}
{synopt:{cmd:r(title_cell)}}title cell, when {opt title()} is specified{p_end}
{synopt:{cmd:r(frame)}}frame name, when {opt frame()} is specified{p_end}
{synopt:{cmd:r(csv)}}CSV path, when {opt csv()} is specified{p_end}

{pstd}With {opt frames()}, {cmd:stacktab} returns the results of {helpb puttab}
({cmd:r(n_rows)}, {cmd:r(n_cols)}, {cmd:r(n_datarows)}, {cmd:r(n_panels)}, {cmd:r(sheet)},
{cmd:r(file)}, ...) plus {cmd:r(n_frames)} and {cmd:r(frames)}.{p_end}

{marker alsosee}{...}
{title:Also see}

{psee}
{helpb tabtools}, {helpb puttab}, {helpb comptab}, {helpb hrcomptab},
{helpb tabtools_tips}
{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{hline}

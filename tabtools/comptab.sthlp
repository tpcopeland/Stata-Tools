{smcl}
{* *! version 1.8.5  24jun2026}{...}
{viewerjumpto "Syntax" "comptab##syntax"}{...}
{viewerjumpto "Description" "comptab##description"}{...}
{viewerjumpto "Options" "comptab##options"}{...}
{viewerjumpto "Examples" "comptab##examples"}{...}
{viewerjumpto "Stored results" "comptab##stored"}{...}
{viewerjumpto "Also see" "comptab##alsosee"}{...}
{viewerjumpto "Author" "comptab##author"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{title:Title}

{phang}
{bf:comptab} {hline 2} Compose publication tables from regtab/effecttab output frames


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:comptab}
{it:framelist}
{cmd:,}
{cmd:rows(}{it:string}{cmd:)}
[{it:options}]

{p 8 17 2}
{cmd:comptab}
{it:framelist}
{cmd:,}
{cmdab:rown:ames(}{it:string}{cmd:)}
[{it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt rows(string)}}backslash-separated row specifications, one per frame; exactly one of {opt rows()} or {opt rownames()} is required{p_end}
{synopt:{cmdab:rown:ames(}{it:string}{cmd:)}}alternative to {opt rows()}: select rows by rendered row-label substring{p_end}

{syntab:Output}
{synopt:{opt xlsx(filename)}}Excel workbook; filename must end in {cmd:.xlsx}{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx()}{p_end}
{synopt:{opt sheet(string)}}Excel sheet name (default: "Composite"){p_end}
{synopt:{opt csv(filename)}}export the composite table to a CSV file{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}save composite to a named Stata frame; specify {cmd:frame(name, replace)} to replace an existing frame{p_end}
{synopt:{opt eplotf:rame(name[, replace])}}save a graph-ready composite companion frame for {helpb eplot}; source frames must have been created by {cmd:regtab} or {cmd:effecttab} with {opt eplotframe()}{p_end}
{synopt:{opt forest}}draw an {helpb eplot} forest plot from the composite companion frame; requires the separate {cmd:eplot} package{p_end}
{synopt:{opt eploto:ptions(string asis)}}pass additional options to {cmd:eplot} when {opt forest} is specified, for example {cmd:eplotoptions(name(myplot, replace) scheme(plotplainblind))}{p_end}
{synopt:{opt dis:play}}accepted for compatibility; the completed table is displayed automatically{p_end}
{synopt:{opt open}}open Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}

{syntab:Content}
{synopt:{opt title(string)}}table title for cell A1{p_end}
{synopt:{opt foot:note(string)}}footnote text below the table{p_end}
{synopt:{cmdab:comp:act}}merge estimate and CI into one column per model{p_end}
{synopt:{cmdab:sec:tion(}{it:string}{cmd:)}}backslash-separated section labels, one per frame{p_end}
{synopt:{cmdab:rela:bel(}{it:string}{cmd:)}}rename rows: pairs of row_number "new label"{p_end}
{synopt:{cmdab:sep:arator(}{it:numlist}{cmd:)}}add horizontal borders above specified data rows{p_end}

{syntab:Formatting}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}journal theme: {it:lancet}, {it:nejm}, {it:bmj}, {it:apa}, {it:jama}, {it:plos}, {it:nature}, {it:cell}, {it:annals}, or {it:custom}{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt labelw:idth(#)}}maximum width (characters) of the label (first) column (default 45); labels longer than the cap wrap onto extra lines{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt bold:p(#)}}bold p-values below threshold{p_end}
{synopt:{cmdab:high:light(}{it:#}{cmd:)}}highlight rows where p < threshold{p_end}
{synopt:{opt headers:hade}}apply background fill to the header row{p_end}
{synopt:{opt headerc:olor(string)}}supported Stata color name or RGB triplet for header rows{p_end}
{synopt:{opt zebrac:olor(string)}}supported Stata color name or RGB triplet for zebra shading{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:comptab} assembles composite publication tables by selecting rows from
multiple {helpb regtab} or {helpb effecttab} output frames and combining them
into a single formatted Excel table. This eliminates the manual
import/export/format workflow for composite tables that combine results from
different analyses.

{pstd}
Common use cases:

{p 8 12 2}
{bf:1.} Binary + dose-response exposure in one table{break}
{bf:2.} Multiple sensitivity analyses side by side{break}
{bf:3.} Primary + secondary outcomes summary table{break}
{bf:4.} Cherry-picked rows from supplementary tables into a main table

{pstd}
Source frames are created by running {cmd:regtab} or {cmd:effecttab} with
the {opt frame()} option. All source frames must have the same column structure
(same layout and number of model blocks). Standard frames
({it:estimate} | {it:CI} | {it:p}) and compact frames
({it:estimate+CI} | {it:p}) are both supported, but all source frames in one
call must use the same layout.

{pstd}
For plot-ready composites, create each source table with both {opt frame()} and
{opt eplotframe()}. {cmd:comptab, eplotframe()} then carries forward the
selected estimate/CI rows into one graph-ready frame. {cmd:comptab, forest}
uses that frame with {helpb eplot} and leaves the active graph scheme in effect
unless you pass a {opt scheme()} option through {opt eplotoptions()}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt rows(string)} specifies which data rows to extract from each source frame.
Specifications are separated by backslashes ({cmd:\}), one per frame in
{it:framelist}. Each specification is a {help numlist} of row numbers where
row 1 is the first data row after the column headers.

{pmore}
Example with 3 frames: {cmd:rows(1 2 \ 1 3/5 \ 1)} extracts rows 1-2 from
the first frame, rows 1 and 3 through 5 from the second, and row 1 from the third.

{phang}
{cmdab:rown:ames(}{it:string}{cmd:)} is an alternative to {opt rows()} that selects rows
by rendered row-label pattern instead of row number. Specifications are separated
by backslashes, one per frame. Each specification is a space-separated list of
case-insensitive substrings matched against the first column ({cmd:A}) in the
source frame. This matches the displayed row labels, not the original source
variable names.

{pmore}
Example: {cmd:rownames(origin weight \ origin length)} extracts rows whose displayed
labels contain those substrings. Only one of {opt rows()} or {opt rownames()} may
be specified.

{dlgtab:Content}

{phang}
{opt compact} merges the estimate and CI into a single column per model,
changing the layout from ({it:Est} | {it:CI} | {it:p}) to
({it:Est (CI)} | {it:p}). This produces a more compact table, common in
publication composite tables. When source frames are already compact, the output
stays compact and {opt compact} is redundant.

{phang}
{opt section(string)} inserts bold section header rows before each
frame's data block. Labels are separated by backslashes, one per frame.
Borders are automatically drawn above each section header.

{pmore}
Example: {cmd:section("Binary HRT" \ "Dose Categories" \ "Duration")}

{phang}
{opt relabel(string)} renames rows in the composite table. Specified as pairs
of {it:row_number} {it:"new label"}. Row numbers are 1-based from the first
data row (after headers), including any section header rows.

{pmore}
Example: {cmd:relabel(4 "Low dose (vs. none)" 6 "High dose")}

{phang}
{opt separator(numlist)} adds thin horizontal borders above the specified
composite data row numbers. Use this for visual grouping when sections are
not needed.

{dlgtab:Formatting}

{phang}
{opt theme(string)} applies a journal-inspired formatting preset. Valid themes:
{cmd:lancet} (Arial 9pt, academic borders),
{cmd:nejm} (Arial 10pt, academic borders, zebra),
{cmd:bmj} (Arial 10pt, academic borders),
{cmd:apa} (Times New Roman 12pt, academic borders),
{cmd:jama} (Arial 10pt, academic borders),
{cmd:plos} (Arial 10pt, thin borders),
{cmd:nature} (Arial 7pt, academic borders),
{cmd:cell} (Arial 10pt, academic borders),
{cmd:annals} (Arial 10pt, academic borders, zebra),
and {cmd:custom}.
Theme settings can be overridden by explicit options.

{phang}
{opt boldp(#)} bolds p-values smaller than the specified threshold.
Example: {cmd:boldp(0.05)}

{phang}
{opt highlight(#)} applies yellow background to rows where any p-value is
smaller than the specified threshold.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup: Create source frames from separate analyses}

{phang2}{cmd:. sysuse auto, clear}{p_end}

{phang2}{cmd:. * Model 1: binary foreign}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: regress price foreign mpg weight}{p_end}
{phang2}{cmd:. regtab, xlsx(composite_demo.xlsx) sheet("Full 1") frame(f1) noint}{p_end}

{phang2}{cmd:. * Model 2: with interaction}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: regress price i.foreign##c.mpg weight}{p_end}
{phang2}{cmd:. regtab, xlsx(composite_demo.xlsx) sheet("Full 2") frame(f2) noint}{p_end}

{pstd}
{bf:Example 1: Basic composite}

{phang2}{cmd:. comptab f1 f2, rows(1 \ 1 2) xlsx(composite_demo.xlsx) sheet("Table 3") title("Table 3. Selected Results")}{p_end}

{pstd}
{bf:Example 2: With sections and footnote}

{phang2}{cmd:. comptab f1 f2, rows(1 \ 1 2) xlsx(composite_demo.xlsx) sheet("Table 4") section("Main Effect" \ "Interaction") title("Table 4. Summary") footnote("Note: All models adjusted for weight.")}{p_end}

{pstd}
{bf:Example 3: Compact mode}

{phang2}{cmd:. comptab f1 f2, rows(1 \ 1 2) compact xlsx(composite_demo.xlsx) sheet("Table 5") title("Table 5. Compact")}{p_end}

{pstd}
{bf:Example 4: Console preview only}

{phang2}{cmd:. comptab f1 f2, rows(1 \ 1 2) display}{p_end}

{pstd}
{bf:Example 5: Typical epidemiology workflow (HRT example)}

{pstd}This example is a workflow sketch: it assumes Cox-model frames {cmd:s1},
{cmd:s2}, and {cmd:s3} have already been created by {helpb regtab} (see the
{cmd:f1}/{cmd:f2} setup above for the pattern). Substitute your own model frames.
For a runnable public-data workflow, see {help tabtools_tips:tabtools_tips}.{p_end}

{phang2}{cmd:. * Each regtab call creates a frame with Cox model results}{p_end}
{phang2}{cmd:. * Frame s1: binary HRT (any vs none)}{p_end}
{phang2}{cmd:. * Frame s2: HRT dose categories (low/medium/high vs none)}{p_end}
{phang2}{cmd:. * Frame s3: HRT duration (per year)}{p_end}
{phang2}{cmd:. comptab s1 s2 s3, rows(1 \ 1 3/5 \ 1) compact ///}{p_end}
{phang2}{cmd:    xlsx(manuscript.xlsx) sheet("Table 3") ///}{p_end}
{phang2}{cmd:    section("Binary Exposure" \ "Dose Categories" \ "Duration") ///}{p_end}
{phang2}{cmd:    relabel(3 "Low dose (vs. none)") ///}{p_end}
{phang2}{cmd:    title("Table 3. HRT and MS Outcomes") ///}{p_end}
{phang2}{cmd:    footnote("aHR, adjusted hazard ratio; CI, confidence interval.") ///}{p_end}
{phang2}{cmd:    theme(lancet)}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:comptab} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in output{p_end}
{synopt:{cmd:r(N_cols)}}number of columns in output{p_end}
{synopt:{cmd:r(N_models)}}number of models (from source frames){p_end}
{synopt:{cmd:r(N_frames)}}number of source frames{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel file path (if exported){p_end}
{synopt:{cmd:r(sheet)}}Excel sheet name (if exported){p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(eplotframe)}}graph-ready composite companion frame name (if {cmd:eplotframe()} specified){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(methods)}}methods paragraph{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.8.5{p_end}


{marker alsosee}{...}
{title:Also see}

{psee}
{helpb regtab}, {helpb effecttab}, {helpb tabtools}, {helpb tabtools_tips}
{p_end}

{hline}

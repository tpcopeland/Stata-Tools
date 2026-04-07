{smcl}
{* *! version 1.0.0  08apr2026}{...}
{viewerjumpto "Syntax" "comptab##syntax"}{...}
{viewerjumpto "Description" "comptab##description"}{...}
{viewerjumpto "Options" "comptab##options"}{...}
{viewerjumpto "Examples" "comptab##examples"}{...}
{viewerjumpto "Stored results" "comptab##results"}{...}
{viewerjumpto "Also see" "comptab##alsosee"}{...}
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


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt rows(string)}}backslash-separated row specifications, one per frame{p_end}
{synopt:{cmdab:rown:ames(}{it:string}{cmd:)}}alternative to {opt rows()}: select rows by name/label pattern{p_end}

{syntab:Output}
{synopt:{opt xlsx(filename)}}Excel output file (.xlsx){p_end}
{synopt:{opt sheet(string)}}Excel sheet name (default: "Composite"){p_end}
{synopt:{opt csv(filename)}}export to CSV file{p_end}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}save composite to a named Stata frame; specify {cmd:frame(name, replace)} to replace an existing frame{p_end}
{synopt:{cmdab:dis:play}}show console preview{p_end}
{synopt:{opt open}}open Excel file after export{p_end}

{syntab:Content}
{synopt:{opt title(string)}}table title for cell A1{p_end}
{synopt:{opt sub:title(string)}}subtitle text displayed below the title{p_end}
{synopt:{cmdab:foot:note(}{it:string}{cmd:)}}footnote text below the table{p_end}
{synopt:{cmdab:comp:act}}merge estimate and CI into one column per model{p_end}
{synopt:{cmdab:sec:tion(}{it:string}{cmd:)}}backslash-separated section labels, one per frame{p_end}
{synopt:{cmdab:rela:bel(}{it:string}{cmd:)}}rename rows: pairs of row_number "new label"{p_end}
{synopt:{cmdab:sep:arator(}{it:numlist}{cmd:)}}add horizontal borders above specified data rows{p_end}

{syntab:Formatting}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}journal theme: {it:lancet}, {it:nejm}, {it:bmj}, {it:apa}{p_end}
{synopt:{cmdab:borders:tyle(}{it:string}{cmd:)}}border style: {it:thin}, {it:medium}, {it:academic}{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt boldp(#)}}bold p-values below threshold{p_end}
{synopt:{cmdab:high:light(}{it:#}{cmd:)}}highlight rows where p < threshold{p_end}
{synopt:{cmdab:headerc:olor(}{it:string}{cmd:)}}RGB color for header rows{p_end}
{synopt:{cmdab:zebrac:olor(}{it:string}{cmd:)}}RGB color for zebra shading{p_end}
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
(same number of models).


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
by name or label pattern instead of row number. Specifications are separated by
backslashes, one per frame. Each specification is a space-separated list of patterns
matched against the first column (row labels) in the source frame.

{pmore}
Example: {cmd:rownames(age sex \ age education income)} extracts rows labeled "age"
and "sex" from the first frame, and rows "age", "education", and "income" from the second.
Only one of {opt rows()} or {opt rownames()} may be specified.

{dlgtab:Content}

{phang}
{opt compact} merges the estimate and CI into a single column per model,
changing the layout from ({it:Est} | {it:CI} | {it:p}) to
({it:Est (CI)} | {it:p}). This produces a more compact table, common in
publication composite tables.

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
{opt theme(string)} applies a journal-style formatting preset. Valid themes:
{cmd:lancet} (Arial 9pt, academic borders),
{cmd:nejm} (Arial 10pt, shaded headers),
{cmd:bmj} (Arial 10pt, academic borders),
{cmd:apa} (Times New Roman 12pt, academic borders).
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


{marker results}{...}
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
{synopt:{cmd:r(sheet)}}Excel sheet name{p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.0{p_end}


{marker alsosee}{...}
{title:Also see}

{psee}
{helpb regtab}, {helpb effecttab}, {helpb tabtools}, {helpb tabtools_cheatsheet}
{p_end}

{hline}

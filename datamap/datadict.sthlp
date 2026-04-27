{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "[D] describe" "help describe"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[D] labelbook" "help labelbook"}{...}
{vieweralsosee "datamap" "help datamap"}{...}
{viewerjumpto "Syntax" "datadict##syntax"}{...}
{viewerjumpto "Description" "datadict##description"}{...}
{viewerjumpto "Options" "datadict##options"}{...}
{viewerjumpto "Remarks" "datadict##remarks"}{...}
{viewerjumpto "Examples" "datadict##examples"}{...}
{viewerjumpto "Stored results" "datadict##results"}{...}
{viewerjumpto "Author" "datadict##author"}{...}

{title:Title}

{phang}
{bf:datadict} {hline 2} Generate Markdown data dictionaries from Stata datasets


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datadict}
[{cmd:,}
{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input {it:(choose at most one; default is data in memory)}}
{synopt:{opt si:ngle(filename)}}document one {opt .dta} file{p_end}
{synopt:{opt dir:ectory(path)}}document every {opt .dta} file in {it:path}{p_end}
{synopt:{opt file:list(names)}}space-separated dataset names to document{p_end}
{synopt:{opt rec:ursive}}with {opt directory()}, also scan subdirectories{p_end}

{syntab:Output}
{synopt:{opt ou:tput(filename)}}output Markdown file; default is {bf:data_dictionary.md}{p_end}
{synopt:{opt sep:arate}}write a separate file per dataset{p_end}

{syntab:Document metadata}
{synopt:{opt ti:tle(string)}}document title; default is {bf:Data Dictionary}{p_end}
{synopt:{opt sub:title(string)}}subtitle or description line{p_end}
{synopt:{opt ver:sion(string)}}version number shown in header and footer{p_end}
{synopt:{opt auth:or(string)}}author name for the footer{p_end}
{synopt:{opt date(string)}}date string; default is the current date{p_end}

{syntab:Content}
{synopt:{opt note:s(string)}}notes text, or path to a text file containing notes{p_end}
{synopt:{opt change:log(string)}}changelog text, or path to a text file{p_end}
{synopt:{opt miss:ing}}add a Missing column with count and percent{p_end}
{synopt:{opt st:ats}}add descriptive statistics to the Values column{p_end}
{synopt:{opt maxc:at(#)}}max unique values to treat as categorical; default {bf:25}{p_end}
{synopt:{opt maxf:req(#)}}max unique values to show individually; default {bf:25}{p_end}
{synopt:{opt datef:ormat(string)}}date display format; default {bf:%tdCCYY/NN/DD}{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
The {opt .dta} extension is optional everywhere and is added automatically when
omitted.


{marker description}{...}
{title:Description}

{pstd}
{cmd:datadict} generates professional Markdown data dictionaries from one or
more Stata datasets.  Each dictionary includes a table of contents, dataset
metadata, and a variable table with columns for Variable, Label, Type, and
Values/Notes.  When {opt missing} or {opt stats} is specified, additional
columns are added.

{pstd}
The command automatically extracts variable labels, classifies variables
(Numeric, String, Date), and formats value labels for categorical variables.
For variables with more than {opt maxfreq()} unique values it displays a count
rather than listing every value.

{pstd}
The generated Markdown files are valid CommonMark and render in GitHub, GitLab,
MkDocs, Sphinx, and any standard Markdown viewer.  They can be converted to
PDF, Word, or HTML with Pandoc:

{phang2}{cmd:pandoc data_dictionary.md -o data_dictionary.pdf}{p_end}
{phang2}{cmd:pandoc data_dictionary.md -o data_dictionary.docx}{p_end}

{pstd}
The current dataset in memory is preserved and restored after processing.

{pstd}
For a companion command that produces plain-text documentation optimized for
LLM context windows, with privacy controls, detection features, and quality
checks, see {help datamap}.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{pstd}
If no input option is specified and data is loaded in memory, {cmd:datadict}
documents the current dataset directly.  This is the simplest usage: load or
prepare your data, then run {cmd:datadict}.

{phang}
{opt si:ngle(filename)} documents one Stata dataset file.  If the file is not
in the current directory, include the full or relative path.

{phang}
{opt dir:ectory(path)} scans a directory for every {opt .dta} file and
documents all of them in a single output file (unless {opt separate} is also
specified).  If {it:path} is omitted, the current working directory is used.

{phang}
{opt file:list(names)} documents a specific set of datasets given as a
space-separated list.  For example, {cmd:filelist(patients hrt dmt)} documents
{it:patients.dta}, {it:hrt.dta}, and {it:dmt.dta}.

{phang}
{opt rec:ursive} makes {opt directory()} also descend into subdirectories.
Hidden directories (names beginning with {cmd:.}) and {cmd:__pycache__} are
always skipped.

{pstd}
Only one of {opt single()}, {opt directory()}, or {opt filelist()} may be
specified.  Specifying more than one is an error.

{dlgtab:Output}

{phang}
{opt ou:tput(filename)} names the output Markdown file.  The default is
{bf:data_dictionary.md}.  When {opt separate} is specified this option is
ignored; instead each dataset produces a file named
{it:datasetname}{cmd:_dictionary.md} in the same directory as the source
dataset.

{phang}
{opt sep:arate} writes a separate Markdown file for each dataset instead of
combining them into one document.

{dlgtab:Document metadata}

{pstd}
These options add structured headers and footers to the Markdown output.  None
of them affect the variable table itself.

{phang}
{opt ti:tle(string)} sets the document title (the top-level Markdown heading).
Default is "Data Dictionary".

{phang}
{opt sub:title(string)} adds an optional subtitle line below the title.

{phang}
{opt ver:sion(string)} adds a version number that appears in the header and
footer.

{phang}
{opt auth:or(string)} adds an author line to the footer.  Markdown formatting
(e.g., links) is preserved.

{phang}
{opt date(string)} sets the "Last Updated" date string.  Default is the
current date from Stata's clock.

{dlgtab:Content}

{phang}
{opt note:s(string)} specifies notes to include in the "Notes" section at the
end of the document.  This can be either an inline text string or the path to a
plain-text file.  If the value resolves to an existing file, its contents are
read; otherwise the string itself is written.  If omitted, a default note
about date formats and missing values is included.

{phang}
{opt change:log(string)} specifies changelog entries for the "Change Log"
section.  Like {opt notes()}, this can be an inline string or a path to a
plain-text file.

{phang}
{opt miss:ing} adds a "Missing" column to the variable table showing the count
and percentage of missing values for each variable.

{phang}
{opt st:ats} adds descriptive statistics to the Values/Notes column.  The
type of statistics depends on variable classification:

{phang2}{bf:Categorical:} unique count plus value frequencies and percentages
(e.g., "1 Male (120; 60.0%)")
{p_end}
{phang2}{bf:Continuous:} N, median, IQR, mean, SD, and range
(e.g., "N=200; Median=42.5; IQR=30{hline 1}55; Mean=45.2 (SD=12.3); Range=18{hline 1}89")
{p_end}
{phang2}{bf:Date:} date range (e.g., "Range: 2020/01/01 to 2023/12/31")
{p_end}
{phang2}{bf:String:} count of non-missing observations and unique values
{p_end}

{phang}
{opt maxc:at(#)} sets the cutoff that separates categorical from continuous.
Numeric variables with value labels or with {it:#} or fewer unique values are
treated as categorical.  Default is {bf:25}.  Must be positive.

{phang}
{opt maxf:req(#)} sets the maximum number of unique values to list
individually.  Categorical variables with more values than this show only a
count.  Default is {bf:25}.  Must be positive.

{phang}
{opt datef:ormat(string)} sets the Stata date format used to display all dates.
The default is {bf:%tdCCYY/NN/DD} (ISO 8601).  For datetime variables
({cmd:%tc}/{cmd:%tC}), the prefix is automatically adapted.  Weekly, monthly,
quarterly, and other non-daily types retain their native format regardless of
this setting.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to use datadict vs. datamap}

{pstd}
Use {cmd:datadict} when you need a polished Markdown document: for GitHub
repositories, report appendices, IRB submissions, or conversion to other
formats via Pandoc.  Use {help datamap} when you need a plain-text file for
LLM context, internal handoff, or automated pipelines.  Both commands accept
the same input modes (data in memory, single file, directory, or file list)
and preserve the dataset in memory.

{pstd}
{bf:Variable classification}

{pstd}
Variable classification follows the same hierarchy as {help datamap}:

{phang2}1. String variables ({cmd:str}{it:#} or {cmd:strL}) are "String".{p_end}
{phang2}2. Variables with date formats ({cmd:%t*} or {cmd:%d*}) are "Date".{p_end}
{phang2}3. Numeric variables with value labels, or with {opt maxcat()} or fewer unique values, are "Numeric" (treated as categorical in the Values column).{p_end}
{phang2}4. All other numeric variables are "Numeric" (treated as continuous).{p_end}

{pstd}
{bf:Notes and changelog}

{pstd}
The {opt notes()} and {opt changelog()} options accept either a literal string
or a file path.  If the argument is a path to an existing file, the file's
contents are read and inserted verbatim; otherwise the string itself is used.
This lets you maintain notes in a separate file and reference it across
multiple dictionaries.


{marker examples}{...}
{title:Examples}

    {title:Getting started}

{pstd}
The simplest way to use {cmd:datadict} is to load a dataset and run the
command with no options.  The output is written to {bf:data_dictionary.md} in
the current directory.{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datadict}{p_end}

{pstd}
Add a title and author for context:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datadict, title("Auto Dataset") author("Timothy P Copeland, Karolinska Institutet")}{p_end}

    {title:Adding statistics and missingness}

{pstd}
The {opt stats} option fills the Values column with summary statistics, and
{opt missing} adds a dedicated missing-value column.{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datadict, missing stats output(auto_dict.md)}{p_end}

    {title:Full metadata}

{pstd}
Add title, subtitle, version, author, and statistics:{p_end}

{phang2}{cmd:. datadict, single(patients) missing stats ///}{p_end}
{phang2}{cmd:     title("Patient Registry") ///}{p_end}
{phang2}{cmd:     subtitle("Source: EMR export 2025-Q4") ///}{p_end}
{phang2}{cmd:     version("2.0") ///}{p_end}
{phang2}{cmd:     author("Research Team")}{p_end}

    {title:Multiple datasets}

{pstd}
Document several named datasets into one file:{p_end}

{phang2}{cmd:. datadict, filelist(patients labs visits) output(study_dictionary.md)}{p_end}

{pstd}
Document every dataset in a directory, one file each:{p_end}

{phang2}{cmd:. datadict, directory(data) recursive separate}{p_end}

    {title:Notes and changelog from files}

{pstd}
Point {opt notes()} and {opt changelog()} at text files to keep metadata
outside of the command line:{p_end}

{phang2}{cmd:. datadict, single(patients) ///}{p_end}
{phang2}{cmd:     notes(data_notes.txt) ///}{p_end}
{phang2}{cmd:     changelog(data_changelog.txt) ///}{p_end}
{phang2}{cmd:     output(patients_dictionary.md)}{p_end}

{pstd}
Or pass a short note inline:{p_end}

{phang2}{cmd:. datadict, single(patients) notes("All dates are admission dates")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datadict} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(nfiles)}}number of datasets documented{p_end}
{synoptline}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(output)}}output filename{p_end}
{synoptline}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.0.0 {hline 2} 08apr2026{p_end}


{title:Also see}

{psee}
{help datamap}, {manlink D describe}, {manlink D codebook}, {manlink D labelbook}
{p_end}

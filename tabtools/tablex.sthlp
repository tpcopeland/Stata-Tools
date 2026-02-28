{smcl}
{* *! version 1.0.2  25feb2026}{...}
{viewerjumpto "Syntax" "tablex##syntax"}{...}
{viewerjumpto "Description" "tablex##description"}{...}
{viewerjumpto "Options" "tablex##options"}{...}
{viewerjumpto "Examples" "tablex##examples"}{...}
{viewerjumpto "Stored results" "tablex##results"}{...}
{viewerjumpto "Author" "tablex##author"}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:tablex} {hline 2}}Export Stata tables to formatted Excel{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tablex} {cmd:using} {it:filename}{cmd:.xlsx}{cmd:,} {opt sheet(name)} [{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opt sheet(name)}}Excel sheet name{p_end}
{synopt:{opt title(string)}}table title for cell A1{p_end}
{synopt:{opt replace}}replace existing sheet{p_end}
{synopt:{opt font(name)}}font name; default is {cmd:Arial}{p_end}
{synopt:{opt fontsize(#)}}font size in points; default is {cmd:10}{p_end}
{synopt:{opt borderstyle(style)}}border style: {cmd:thin} or {cmd:medium}; default is {cmd:thin}{p_end}
{synopt:{opt headerrows(#)}}number of header rows; default is auto-detect{p_end}
{synoptline}
{p 4 6 2}* {opt sheet()} is required.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tablex} exports the active {cmd:collect} table to Excel with professional
formatting. It works with Stata 17+ {cmd:table} command and the {cmd:collect}
infrastructure.

{pstd}
The command applies consistent formatting including:

{p 8 12 2}- Automatic column width calculation based on content{p_end}
{p 8 12 2}- Clean borders around the table{p_end}
{p 8 12 2}- Bold headers with bottom border{p_end}
{p 8 12 2}- Merged title row (if specified){p_end}
{p 8 12 2}- Consistent font throughout{p_end}

{pstd}
{cmd:tablex} is part of the {cmd:tabtools} suite of table export commands. See
{helpb table1_tc}, {helpb regtab}, {helpb effecttab}, {helpb gformtab}, and
{helpb stratetab} for specialized table types.


{marker options}{...}
{title:Options}

{phang}
{opt sheet(name)} specifies the Excel sheet name. This is required.

{phang}
{opt title(string)} adds a title in the first row of the Excel file. The title
is merged across all columns and formatted in bold.

{phang}
{opt replace} replaces an existing sheet with the same name. If not specified
and the sheet exists, the command will fail.

{phang}
{opt font(name)} specifies the font name to use throughout the table.
Default is {cmd:Arial}. Common alternatives include {cmd:Calibri},
{cmd:Times New Roman}, and {cmd:Helvetica}.

{phang}
{opt fontsize(#)} specifies the font size in points. Default is {cmd:10}.
Must be between 6 and 72.

{phang}
{opt borderstyle(style)} specifies the border thickness. Options are
{cmd:thin} (default) or {cmd:medium}.

{phang}
{opt headerrows(#)} specifies the number of header rows to format with bold
text and bottom border. Default is auto-detection based on content analysis.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/_examples/cohort.dta", clear"':. use _examples/cohort.dta, clear}{p_end}
{phang2}{stata `"merge 1:1 id using "https://raw.githubusercontent.com/tpcopeland/Stata-Dev/main/_examples/treatment.dta", nogen keep(match)"':. merge 1:1 id using _examples/treatment.dta, nogen keep(match)}{p_end}

{pstd}Education by treatment group{p_end}
{phang2}{stata "table (education) (treated)":. table (education) (treated)}{p_end}
{phang2}{stata `"tablex using tabtools/examples/summary.xlsx, sheet("Summary") title("Education by Treatment Group")"':. tablex using tabtools/examples/summary.xlsx, sheet("Summary") ///}{p_end}
{phang3}{cmd:title("Education by Treatment Group")}{p_end}

{pstd}Summary statistics by treatment{p_end}
{phang2}{stata "table (treated), statistic(mean index_age) statistic(sd index_age)":. table (treated), statistic(mean index_age) statistic(sd index_age)}{p_end}
{phang2}{stata `"tablex using tabtools/examples/summary.xlsx, sheet("Age") title("Age by Antidepressant Class")"':. tablex using tabtools/examples/summary.xlsx, sheet("Age") ///}{p_end}
{phang3}{cmd:title("Age by Antidepressant Class")}{p_end}

{pstd}Custom formatting{p_end}
{phang2}{stata "table (education), statistic(mean index_age) statistic(count index_age)":. table (education), statistic(mean index_age) statistic(count index_age)}{p_end}
{phang2}{stata `"tablex using tabtools/examples/summary.xlsx, sheet("ByEduc") title("Age by Education") font(Calibri) fontsize(11) borderstyle(medium)"':. tablex using tabtools/examples/summary.xlsx, sheet("ByEduc") ///}{p_end}
{phang3}{cmd:title("Age by Education") font(Calibri) fontsize(11) borderstyle(medium)}{p_end}

{pstd}Cross-tabulation{p_end}
{phang2}{stata "table (education) (treated), statistic(frequency) statistic(percent)":. table (education) (treated), statistic(frequency) statistic(percent)}{p_end}
{phang2}{stata `"tablex using tabtools/examples/summary.xlsx, sheet("CrossTab") title("Education x Treatment Group")"':. tablex using tabtools/examples/summary.xlsx, sheet("CrossTab") ///}{p_end}
{phang3}{cmd:title("Education x Treatment Group")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tablex} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in exported table{p_end}
{synopt:{cmd:r(N_cols)}}number of columns in exported table{p_end}
{synopt:{cmd:r(header_rows)}}number of header rows detected/used{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(using)}}Excel filename{p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}


{title:Also see}

{psee}
{space 2}Help:  {helpb table1_tc}, {helpb regtab}, {helpb effecttab},
{helpb gformtab}, {helpb stratetab}, {helpb table}, {helpb collect}
{p_end}

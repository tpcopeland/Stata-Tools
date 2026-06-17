{smcl}
{* *! version 1.8.1  17jun2026}{...}
{viewerjumpto "Package overview" "corrtab##package"}{...}
{viewerjumpto "Syntax" "corrtab##syntax"}{...}
{viewerjumpto "Description" "corrtab##description"}{...}
{viewerjumpto "Options" "corrtab##options"}{...}
{viewerjumpto "Examples" "corrtab##examples"}{...}
{viewerjumpto "Stored results" "corrtab##stored"}{...}
{viewerjumpto "Also see" "corrtab##alsosee"}{...}
{viewerjumpto "Author" "corrtab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "crosstab" "help crosstab"}{...}
{vieweralsosee "diagtab" "help diagtab"}{...}
{vieweralsosee "pwcorr" "help pwcorr"}{...}
{vieweralsosee "spearman" "help spearman"}{...}
{title:Title}

{phang}
{bf:corrtab} {hline 2} Correlation matrix table with significance indicators

{marker package}{...}
{title:Package}

{pstd}{cmd:corrtab} is part of the {helpb tabtools} suite. See {helpb crosstab}
for categorical association tables and {helpb diagtab} for diagnostic-accuracy
output from binary classification data.{p_end}

{hline}

{marker syntax}{...}
{title:Syntax}

{p 4 8 2}{cmd:corrtab} {varlist} [{it:if}] [{it:in}],
[{opt xlsx(filename)} {opt excel(filename)} {opt spe:arman} {opt low:er}
{opt upp:er} {opt full} {opt star(numlist)} {opt pval:ues}
{opt dig:its(#)} {opt sheet(string)}
{opt title(string)} {opt foot:note(string)}
{opt the:me(string)} {opt border:style(string)} {opt headerc:olor(string)}
{opt zebrac:olor(string)} {opt zebra} {opt headers:hade}
{opt csv(filename)} {opt markdown(filename)} {opt mdappend} {opt fra:me(name)} {opt dis:play} {opt open}]{p_end}

{pstd}{it:varlist} must contain at least two numeric variables.{p_end}

{marker description}{...}
{title:Description}

{pstd}{cmd:corrtab} generates a formatted correlation matrix with
significance stars or p-values. It supports Pearson product-moment
correlations (the default) and Spearman rank correlations, and can display
the lower triangle (default), upper triangle, or the full symmetric matrix.{p_end}

{pstd}Output is displayed automatically in the Results window and may also be exported to a
professionally formatted Excel workbook, saved as CSV for use in other
software, or stored in a Stata {helpb frames:frame} for programmatic access.
When exported to Excel, the table includes a title row, formatted headers,
significance footnotes, and optional zebra striping or header shading.{p_end}

{pstd}Pairwise complete observations are used: each cell reports the
correlation computed from all observations with non-missing values on both
variables. The pairwise observation count matrix is stored in
{cmd:r(N)}.{p_end}

{marker options}{...}
{title:Options}

{dlgtab:Correlation}

{synoptset 24 tabbed}{...}
{synoptline}
{synopt:{opt spe:arman}}Compute Spearman rank correlations instead of Pearson (for ordinal, skewed, or nonlinear monotonic data).{p_end}
{synopt:{opt low:er}}display the lower triangle only (default); only one of {opt lower}, {opt upper}, or {opt full} may be specified{p_end}
{synopt:{opt upp:er}}display the upper triangle only{p_end}
{synopt:{opt full}}display the full symmetric matrix{p_end}
{synopt:{opt star(numlist)}}Significance thresholds for stars; up to 3 unique values in (0,1); default {cmd:0.001 0.01 0.05}. Not with {opt pvalues}.{p_end}
{synopt:{opt pval:ues}}show p-values in parentheses instead of stars; cannot be combined with {opt star()}{p_end}
{synopt:{opt dig:its(#)}}decimal places for correlation coefficients; default 2, range 0-6; also respects {cmd:tabtools set digits}{p_end}
{synoptline}

{dlgtab:Output}

{synoptset 24 tabbed}{...}
{synopt:{opt xlsx(filename)}}export to Excel; filename must end in {cmd:.xlsx}; if the file exists, only the named sheet is replaced{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx()}{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default is {cmd:"Correlation"}{p_end}
{synopt:{opt csv(filename)} {opt markdown(filename)} {opt mdappend}}also export the output dataset as CSV{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}store output in a named Stata frame; specify {cmd:frame(name, replace)} to replace an existing frame{p_end}
{synopt:{opt dis:play}}accepted for compatibility; the completed table is displayed automatically{p_end}
{synopt:{opt open}}open the Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}
{synoptline}

{dlgtab:Formatting}

{synoptset 24 tabbed}{...}
{synopt:{opt title(string)}}table title written to cell A1{p_end}
{synopt:{cmdab:foot:note(}{it:string}{cmd:)}}footnote text below the table in smaller italic font{p_end}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}journal-style theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{cmdab:border:style(}{it:string}{cmd:)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{cmdab:headers:hade}}apply background fill to the header row{p_end}
{synopt:{cmdab:headerc:olor(}{it:string}{cmd:)}}custom header color as a supported Stata color name or RGB triplet (e.g., {cmd:"200 220 240"}){p_end}
{synopt:{cmdab:zebrac:olor(}{it:string}{cmd:)}}custom zebra stripe color as a supported Stata color name or RGB triplet{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synoptline}

{marker examples}{...}
{title:Examples}

{pstd}{bf:Example 1: Lower triangle with default stars}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{cmd:. corrtab price mpg weight length, ///}{p_end}
{phang3}{cmd:xlsx(corr.xlsx) title("Correlation Matrix") lower}{p_end}

{pstd}{bf:Example 2: Spearman with p-values (console)}{p_end}
{phang2}{cmd:. corrtab price mpg weight, spearman pvalues display}{p_end}

{pstd}{bf:Example 3: Full matrix with custom star thresholds}{p_end}
{phang2}{cmd:. corrtab price mpg weight length, full ///}{p_end}
{phang3}{cmd:star(0.1 0.05 0.01) digits(3) ///}{p_end}
{phang3}{cmd:xlsx(corr.xlsx) sheet("Full") ///}{p_end}
{phang3}{cmd:footnote("* p<0.10, ** p<0.05, *** p<0.01") ///}{p_end}
{phang3}{cmd:theme(lancet)}{p_end}

{pstd}{bf:Example 4: Store in frame for downstream use}{p_end}
{phang2}{cmd:. corrtab price mpg weight, frame(corr_results, replace)}{p_end}
{phang2}{cmd:. frame corr_results: list}{p_end}

{marker stored}{...}
{title:Stored results}

{pstd}{cmd:corrtab} stores the following in {cmd:r()}:{p_end}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(C)}}correlation matrix{p_end}
{synopt:{cmd:r(P)}}p-value matrix{p_end}
{synopt:{cmd:r(N)}}pairwise observation count matrix{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(methods)}}methods paragraph for manuscript text{p_end}

{marker alsosee}{...}
{title:Also see}

{psee}
{helpb tabtools}, {helpb crosstab}, {helpb diagtab},
{helpb tabtools_tips}, {helpb pwcorr}, {helpb spearman}
{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.8.1{p_end}

{hline}

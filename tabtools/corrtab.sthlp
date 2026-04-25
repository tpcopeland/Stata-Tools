{smcl}
{* *! version 1.0.9  23apr2026}{...}
{viewerjumpto "Package overview" "corrtab##package"}{...}
{viewerjumpto "Syntax" "corrtab##syntax"}{...}
{viewerjumpto "Description" "corrtab##description"}{...}
{viewerjumpto "Options" "corrtab##options"}{...}
{viewerjumpto "Examples" "corrtab##examples"}{...}
{viewerjumpto "Stored results" "corrtab##stored"}{...}
{viewerjumpto "Author" "corrtab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "crosstab" "help crosstab"}{...}
{vieweralsosee "diagtab" "help diagtab"}{...}
{vieweralsosee "pwcorr" "help pwcorr"}{...}
{vieweralsosee "spearman" "help spearman"}{...}
{title:corrtab}

{pstd}Correlation matrix table with significance indicators.{p_end}

{marker package}{title:Package}

{pstd}{cmd:corrtab} is part of the {helpb tabtools} suite. See {helpb crosstab}
for categorical association tables and {helpb diagtab} for diagnostic-accuracy
output from binary classification data.{p_end}

{hline}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:corrtab} {varlist} [{it:if}] [{it:in}],
[{opt xlsx(filename)} {opt excel(filename)} {opt spe:arman} {opt low:er}
{opt upp:er} {opt full} {opt star(numlist)} {opt pval:ues}
{opt dig:its(#)} {opt sheet(string)}
{opt title(string)} {opt foot:note(string)}
{opt the:me(string)} {opt border:style(string)} {opt headerc:olor(string)}
{opt zebrac:olor(string)} {opt zebra} {opt headers:hade}
{opt csv(filename)} {opt fra:me(name)} {opt dis:play} {opt open}]{p_end}

{marker description}{title:Description}

{pstd}{cmd:corrtab} generates a formatted correlation matrix with
significance stars or p-values. Supports Pearson (default) and Spearman
rank correlations. Can display lower triangle (default), upper triangle,
or the full matrix. Output may be displayed in the Results window, exported
to Excel or CSV, or stored in a Stata frame.{p_end}

{marker options}{title:Options}

{synoptset 24 tabbed}{...}
{synoptline}
{syntab:Correlation}
{synopt:{opt spe:arman}}compute Spearman rank correlations instead of Pearson{p_end}
{synopt:{opt lower}}display the lower triangle only; this is the default if no shape option is specified{p_end}
{synopt:{opt upper}}display the upper triangle only{p_end}
{synopt:{opt full}}display the full correlation matrix{p_end}
{synopt:{opt star(numlist)}}strictly increasing significance thresholds in (0,1); cannot be combined with {opt pvalues}. Default thresholds yield *, **, *** at {it:p}<0.05, {it:p}<0.01, and {it:p}<0.001{p_end}
{synopt:{opt pval:ues}}show p-values in parentheses instead of stars{p_end}
{synopt:{opt digits(#)}}decimal places for correlation coefficients; default 2, range 0-6{p_end}
{syntab:Output}
{synopt:{opt xlsx(filename)}}export to Excel; filename must end in {cmd:.xlsx}{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx(filename)}{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default is {cmd:"Correlation"}{p_end}
{synopt:{opt csv(filename)}}also export the output dataset as CSV{p_end}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}store the output dataset in a named Stata frame; specify {cmd:frame(name, replace)} to replace an existing frame{p_end}
{synopt:{opt display}}show console output in addition to any file export{p_end}
{synopt:{opt open}}open the Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}
{syntab:Formatting}
{synopt:{opt title(string)}}table title{p_end}
{synopt:{opt footnote(string)}}footnote text below the table{p_end}
{synopt:{opt theme(string)}}journal-style formatting theme such as {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt headershade}}apply background fill to the header rows{p_end}
{synopt:{opt headercolor(string)}}custom RGB header color (for example, {cmd:"200 220 240"}){p_end}
{synopt:{opt zebracolor(string)}}custom RGB zebra stripe color{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synoptline}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Lower triangle with stars}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{cmd:. corrtab price mpg weight length, ///}{p_end}
{phang3}{cmd:xlsx(corr.xlsx) title("Correlation Matrix") lower}{p_end}

{pstd}{bf:Example 2: Spearman with p-values}{p_end}
{phang2}{cmd:. corrtab price mpg weight, spearman pvalues display}{p_end}

{marker stored}{title:Stored results}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(C)}}correlation matrix{p_end}
{synopt:{cmd:r(P)}}p-value matrix{p_end}
{synopt:{cmd:r(N)}}pairwise observation count matrix{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(methods)}}methods paragraph{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.9{p_end}

{hline}

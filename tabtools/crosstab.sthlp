{smcl}
{* *! version 1.0.7  18apr2026}{...}
{viewerjumpto "Syntax" "crosstab##syntax"}{...}
{viewerjumpto "Description" "crosstab##description"}{...}
{viewerjumpto "Options" "crosstab##options"}{...}
{viewerjumpto "Examples" "crosstab##examples"}{...}
{viewerjumpto "Stored results" "crosstab##stored"}{...}
{viewerjumpto "Author" "crosstab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "corrtab" "help corrtab"}{...}
{vieweralsosee "diagtab" "help diagtab"}{...}
{vieweralsosee "tabulate twoway" "help tabulate twoway"}{...}
{title:crosstab}

{pstd}Cross-tabulation table with association measures for Excel export.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:crosstab} {it:rowvar} {it:colvar} [{it:if}] [{it:in}] [{it:weight}],
[{opt xlsx(filename)} {opt col:pct} {opt row:pct} {opt total:pct}
{opt or} {opt rr} {opt rd} {opt tr:end} {opt ex:act} {opt fi:sher}
{opt lab:el} {opt mis:sing} {opt dig:its(#)}
{opt sheet(string)} {opt title(string)} {opt foot:note(string)}
{opt the:me(string)} {opt borders:tyle(string)} {opt boldp(#)} {opt zebra}
{opt csv(filename)} {opt fra:me(name)} {opt dis:play} {opt open}]{p_end}

{marker description}{title:Description}

{pstd}{cmd:crosstab} generates a formatted cross-tabulation table with
frequencies, percentages, and association measures (OR, RR, RD). Supports
Chi-squared test, Fisher's exact test (auto-selected when expected cells < 5),
and a Spearman rank-correlation trend test.{p_end}

{marker options}{title:Options}

{synoptset 20 tabbed}{...}
{synopt:{opt col:pct}}column percentages (default){p_end}
{synopt:{opt row:pct}}row percentages{p_end}
{synopt:{opt total:pct}}total percentages{p_end}
{synopt:{opt or}}odds ratio with 95% CI (2x2 tables){p_end}
{synopt:{opt rr}}risk ratio with 95% CI (2x2 tables){p_end}
{synopt:{opt rd}}risk difference with 95% CI (2x2 tables){p_end}
{synopt:{opt tr:end}}test for trend using Spearman rank correlation{p_end}
{synopt:{opt ex:act}}force Fisher's exact test{p_end}
{synopt:{opt fi:sher}}force Fisher's exact test (synonym for {opt exact}){p_end}
{synopt:{opt lab:el}}use value labels for headers{p_end}
{synopt:{opt mis:sing}}include missing values{p_end}
{synopt:{opt dig:its(#)}}decimal places for percentages and association measures (default 1, range 0-6){p_end}
{synopt:{opt boldp(#)}}bold test and trend rows when p-values fall below the threshold; must be between 0 and 1{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Basic 2x2 table with OR}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "gen byte expensive = (price > 6000)":. gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:. crosstab expensive foreign, or label ///}{p_end}
{phang3}{cmd:xlsx(crosstab.xlsx) title("Price by Origin")}{p_end}

{pstd}{bf:Example 2: Console preview}{p_end}
{phang2}{cmd:. crosstab rep78 foreign, label display}{p_end}

{marker stored}{title:Stored results}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total observations{p_end}
{synopt:{cmd:r(chi2)}}chi-squared statistic{p_end}
{synopt:{cmd:r(p)}}p-value{p_end}
{synopt:{cmd:r(or)}}odds ratio (2x2){p_end}
{synopt:{cmd:r(rr)}}risk ratio (2x2){p_end}
{synopt:{cmd:r(rd)}}risk difference (2x2){p_end}
{synopt:{cmd:r(p_trend)}}trend p-value{p_end}

{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}frequency matrix{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(methods)}}methods paragraph for manuscript text{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if specified){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if specified){p_end}
{synopt:{cmd:r(frame)}}frame name (if specified){p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.7{p_end}

{hline}

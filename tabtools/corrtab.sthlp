{smcl}
{* *! version 1.0.0  08apr2026}{...}
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

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:corrtab} {varlist} [{it:if}] [{it:in}],
[{opt xlsx(filename)} {opt spe:arman} {opt low:er} {opt upp:er} {opt full}
{opt star(numlist)} {opt pval:ues} {opt dig:its(#)}
{opt sheet(string)} {opt title(string)} {opt sub:title(string)}
{opt foot:note(string)} {opt the:me(string)} {opt borders:tyle(string)}
{opt csv(filename)} {opt fra:me(name)} {opt dis:play} {opt open}]{p_end}

{marker description}{title:Description}

{pstd}{cmd:corrtab} generates a formatted correlation matrix with
significance stars or p-values. Supports Pearson (default) and Spearman
rank correlations. Can display lower triangle (default), upper triangle,
or the full matrix.{p_end}

{marker options}{title:Options}

{dlgtab:Correlation}

{phang}{opt spe:arman} compute Spearman rank correlations instead of Pearson (default).{p_end}

{phang}{opt low:er} display lower triangle only (this is the default).{p_end}

{phang}{opt upp:er} display upper triangle only.{p_end}

{phang}{opt full} display the full correlation matrix.{p_end}

{phang}{opt star(numlist)} significance thresholds for star indicators.
Default is {cmd:star(0.05 0.01 0.001)} giving *, **, ***.{p_end}

{phang}{opt pval:ues} show p-values in parentheses instead of stars.{p_end}

{phang}{opt dig:its(#)} decimal places for correlation coefficients. Default is 2.{p_end}

{phang}{opt sub:title(string)} subtitle text displayed below the title.{p_end}

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
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(methods)}}methods paragraph{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.0{p_end}

{hline}

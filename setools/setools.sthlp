{smcl}
{* *! version 1.0.0  07jan2026}{...}
{viewerjumpto "Description" "setools##description"}{...}
{viewerjumpto "Commands" "setools##commands"}{...}
{viewerjumpto "Installation" "setools##installation"}{...}
{viewerjumpto "Author" "setools##author"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:setools} {hline 2}}Swedish Registry Toolkit for Epidemiological Cohort Studies{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:setools} provides utilities for working with Swedish health registries and
conducting epidemiological cohort studies. The package includes tools for ICD-10
code expansion, procedure code matching, date parsing, migration processing,
and MS disability progression endpoints (EDSS, CDP, PIRA).


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Registry Code Utilities}

{synoptset 16}{...}
{synopt:{helpb icdexpand}}ICD-10 code utilities for Swedish registry research{p_end}
{synopt:{helpb procmatch}}Procedure code matching for Swedish registry research{p_end}

{pstd}
{bf:Date and Covariate Utilities}

{synopt:{helpb dateparse}}Date utilities for Swedish registry cohort studies{p_end}
{synopt:{helpb covarclose}}Extract covariate values closest to index date{p_end}
{synopt:{helpb tvage}}Generate time-varying age intervals for survival analysis{p_end}

{pstd}
{bf:Migration Registry}

{synopt:{helpb migrations}}Process Swedish migration registry data for cohort studies{p_end}

{pstd}
{bf:MS Disability Progression}

{synopt:{helpb sustainedss}}Compute sustained EDSS progression date{p_end}
{synopt:{helpb cdp}}Confirmed Disability Progression from baseline EDSS{p_end}
{synopt:{helpb pira}}Progression Independent of Relapse Activity{p_end}


{marker installation}{...}
{title:Installation}

{pstd}
To install or update setools:

{phang2}{cmd:. net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden
{p_end}

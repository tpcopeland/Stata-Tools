{smcl}
{* *! version 1.0.0  08jan2026}{...}
{viewerjumpto "Description" "tabtools##description"}{...}
{viewerjumpto "Commands" "tabtools##commands"}{...}
{viewerjumpto "Installation" "tabtools##installation"}{...}
{viewerjumpto "Author" "tabtools##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tabtools} {hline 2}}Suite of table export commands for publication-ready Excel output{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tabtools} is a comprehensive suite of Stata commands for exporting tables to
professionally formatted Excel files. The package includes tools for descriptive
statistics (Table 1), regression results, treatment effects, mediation analysis,
incidence rates, and general-purpose table export.

{pstd}
All commands apply consistent Excel formatting: column widths, borders, fonts,
merged headers, and professional styling suitable for journal submissions.


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Descriptive Statistics}

{synoptset 16}{...}
{synopt:{helpb table1_tc}}Table 1 with automatic statistical tests{p_end}

{pstd}
{bf:Model Results}

{synopt:{helpb regtab}}Regression results from any estimation command{p_end}
{synopt:{helpb effecttab}}Treatment effects and margins results{p_end}
{synopt:{helpb gformtab}}G-formula mediation analysis results{p_end}

{pstd}
{bf:Incidence Rates}

{synopt:{helpb stratetab}}Incidence rates from strate output{p_end}

{pstd}
{bf:General Purpose}

{synopt:{helpb tablex}}Flexible table export wrapper{p_end}


{marker installation}{...}
{title:Installation}

{pstd}
To install or update tabtools:

{phang2}{cmd:. net install tabtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tabtools") replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden
{p_end}

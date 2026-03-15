{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "drest" "help drest"}{...}
{vieweralsosee "drest_estimate" "help drest_estimate"}{...}
{viewerjumpto "Syntax" "drest_report##syntax"}{...}
{viewerjumpto "Description" "drest_report##description"}{...}
{viewerjumpto "Options" "drest_report##options"}{...}
{viewerjumpto "Examples" "drest_report##examples"}{...}
{viewerjumpto "Author" "drest_report##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:drest_report} {hline 2}}Summary tables for AIPW results{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:drest_report}
[{cmd:,}
{opt ex:cel(filename)}
{opt replace}
{opt d:etail}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:drest_report} displays a formatted summary of AIPW estimation results
and optionally exports to Excel.


{marker options}{...}
{title:Options}

{phang}{opt excel(filename)} exports results to the specified Excel file.{p_end}
{phang}{opt replace} allows overwriting an existing Excel file.{p_end}
{phang}{opt detail} includes propensity score and influence function summaries.{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. drest_estimate weight length, outcome(price) treatment(foreign)}{p_end}
{phang2}{cmd:. drest_report}{p_end}
{phang2}{cmd:. drest_report, excel(drest_results.xlsx) replace detail}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}

{hline}

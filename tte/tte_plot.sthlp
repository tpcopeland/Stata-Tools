{smcl}
{* *! version 1.0.2  28feb2026}{...}
{viewerjumpto "Syntax" "tte_plot##syntax"}{...}
{viewerjumpto "Description" "tte_plot##description"}{...}
{viewerjumpto "Examples" "tte_plot##examples"}{...}
{viewerjumpto "Author" "tte_plot##author"}{...}

{title:Title}

{phang}
{bf:tte_plot} {hline 2} Visualization for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_plot}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth type(string)}}km, cumhaz, weights, or balance{p_end}
{synopt:{opth by(varname)}}stratify plots{p_end}
{synopt:{opt ci}}show confidence intervals{p_end}
{synopt:{opth scheme(string)}}graph scheme; default is {cmd:plotplainblind}{p_end}
{synopt:{opth title(string)}}graph title{p_end}
{synopt:{opth export(filename)}}export graph to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_plot} produces diagnostic and results visualizations.
Plot types: {cmd:km} (Kaplan-Meier curves), {cmd:cumhaz} (cumulative
incidence from {helpb tte_predict}), {cmd:weights} (weight distributions),
{cmd:balance} (Love plot from {helpb tte_diagnose}).


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_plot, type(km)}{p_end}
{phang2}{cmd:. tte_plot, type(weights) export(weights.png) replace}{p_end}
{phang2}{cmd:. tte_plot, type(cumhaz) ci}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet

{smcl}
{* *! version 1.0.2  01mar2026}{...}
{viewerjumpto "Syntax" "tte_protocol##syntax"}{...}
{viewerjumpto "Description" "tte_protocol##description"}{...}
{viewerjumpto "Examples" "tte_protocol##examples"}{...}
{viewerjumpto "Author" "tte_protocol##author"}{...}

{title:Title}

{phang}
{bf:tte_protocol} {hline 2} Target trial protocol table (Hernan 7-component)


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_protocol}
{cmd:,} {opth elig:ibility(string)} {opth treat:ment(string)}
{opth ass:ignment(string)} {opth fol:lowup_start(string)}
{opth out:come(string)} {opth caus:al_contrast(string)}
{opth anal:ysis(string)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required (7 components)}
{synopt:{opth elig:ibility(string)}}eligibility criteria{p_end}
{synopt:{opth treat:ment(string)}}treatment strategies{p_end}
{synopt:{opth ass:ignment(string)}}treatment assignment procedure{p_end}
{synopt:{opth fol:lowup_start(string)}}start of follow-up / time zero{p_end}
{synopt:{opth out:come(string)}}outcome of interest{p_end}
{synopt:{opth caus:al_contrast(string)}}causal contrast (ITT/PP){p_end}
{synopt:{opth anal:ysis(string)}}statistical analysis plan{p_end}

{syntab:Export}
{synopt:{opth export(filename)}}export to file{p_end}
{synopt:{opth for:mat(string)}}display (default), csv, excel, or latex{p_end}
{synopt:{opth title(string)}}custom title{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_protocol} generates a formatted target trial protocol
specification table following the Hernan & Robins (2016) 7-component
framework. This is unique to the {cmd:tte} package; the R
{cmd:TrialEmulation} package does not provide this feature.

{pstd}
The protocol table is a key element of the methods section when
reporting target trial emulation studies.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. tte_protocol, eligibility("Age >= 18, no prior outcome") treatment("Initiate drug vs no drug") assignment("At each eligible period") followup_start("Start of eligible period") outcome("All-cause mortality") causal_contrast("Per-protocol effect") analysis("Pooled logistic with IPCW")}{p_end}

{phang2}{cmd:. tte_protocol, eligibility("Adults with condition X") treatment("Drug A vs no treatment") assignment("Sequential") followup_start("Treatment eligibility") outcome("Composite endpoint") causal_contrast("ITT") analysis("Cox MSM") export(protocol.tex) format(latex)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

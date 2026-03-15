{smcl}
{* *! version 1.1.0  15mar2026}{...}
{viewerjumpto "Syntax" "tte_protocol##syntax"}{...}
{viewerjumpto "Description" "tte_protocol##description"}{...}
{viewerjumpto "Examples" "tte_protocol##examples"}{...}
{viewerjumpto "Stored results" "tte_protocol##results"}{...}
{viewerjumpto "Author" "tte_protocol##author"}{...}

{title:Title}

{phang}
{bf:tte_protocol} {hline 2} Target trial protocol table (Hernán 7-component)


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_protocol}
{cmd:,} {opt auto}
[{it:component_options} {it:export_options}]

{p 8 17 2}
{cmdab:tte_protocol}
{cmd:,} {opth elig:ibility(string)} {opth treat:ment(string)}
{opth ass:ignment(string)} {opth fol:lowup_start(string)}
{opth out:come(string)} {opth caus:al_contrast(string)}
{opth anal:ysis(string)}
[{it:export_options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Auto-fill}
{synopt:{opt auto}}generate defaults from dataset metadata{p_end}

{syntab:7 components (required without {opt auto})}
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
specification table following the Hernán & Robins (2016) 7-component
framework.

{pstd}
The protocol table is a key element of the methods section when
reporting target trial emulation studies.

{pstd}
With {opt auto}, the command reads dataset characteristics stored by
{cmd:tte_prepare} and {cmd:tte_fit} to generate default text for each
protocol component. User-supplied text overrides auto-generated defaults.
This requires data that has been through at least {cmd:tte_prepare}.


{marker examples}{...}
{title:Examples}

{pstd}Auto-generate protocol from metadata{p_end}
{phang2}{cmd:. tte_protocol, auto}{p_end}

{pstd}Auto-generate with custom eligibility text{p_end}
{phang2}{cmd:. tte_protocol, auto eligibility("Age >= 18, no prior outcome, enrolled in registry")}{p_end}

{pstd}Fully manual specification{p_end}
{phang2}{cmd:. tte_protocol, eligibility("Age >= 18, no prior outcome") treatment("Initiate drug vs no drug") assignment("At each eligible period") followup_start("Start of eligible period") outcome("All-cause mortality") causal_contrast("Per-protocol effect") analysis("Pooled logistic with IPCW")}{p_end}

{phang2}{cmd:. tte_protocol, auto export(protocol.xlsx) format(excel) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_protocol} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(eligibility)}}eligibility criteria text{p_end}
{synopt:{cmd:r(treatment)}}treatment strategies text{p_end}
{synopt:{cmd:r(assignment)}}treatment assignment text{p_end}
{synopt:{cmd:r(followup_start)}}start of follow-up text{p_end}
{synopt:{cmd:r(outcome)}}outcome definition text{p_end}
{synopt:{cmd:r(causal_contrast)}}causal contrast text{p_end}
{synopt:{cmd:r(analysis)}}statistical analysis text{p_end}
{synopt:{cmd:r(format)}}export format used{p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

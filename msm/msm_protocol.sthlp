{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_protocol##syntax"}{...}
{viewerjumpto "Description" "msm_protocol##description"}{...}
{viewerjumpto "Examples" "msm_protocol##examples"}{...}
{viewerjumpto "Author" "msm_protocol##author"}{...}

{title:Title}

{phang}
{bf:msm_protocol} {hline 2} MSM study protocol specification


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_protocol}
{cmd:,} {opt pop:ulation(string)} {opt treat:ment(string)}
{opt con:founders(string)} {opt out:come(string)}
{opt caus:al_contrast(string)} {opt weight_spec(string)}
{opt ana:lysis(string)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required (7 components)}
{synopt:{opt pop:ulation(string)}}target population definition{p_end}
{synopt:{opt treat:ment(string)}}treatment strategies compared{p_end}
{synopt:{opt con:founders(string)}}confounders measured{p_end}
{synopt:{opt out:come(string)}}outcome definition{p_end}
{synopt:{opt caus:al_contrast(string)}}causal contrast{p_end}
{synopt:{opt weight_spec(string)}}weight specification{p_end}
{synopt:{opt ana:lysis(string)}}statistical analysis plan{p_end}

{syntab:Export}
{synopt:{opt exp:ort(string)}}file path{p_end}
{synopt:{opt for:mat(string)}}display (default), csv, excel, or latex{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_protocol} documents the MSM study protocol using 7 components
adapted from the Hernan framework for MSM/IPTW analyses. All 7 components
are required to ensure complete study documentation.


{marker options}{...}
{title:Options}

{dlgtab:Required (7 components)}

{phang}
{opt population(string)} describes the target population.

{phang}
{opt treatment(string)} describes the treatment strategies being compared.

{phang}
{opt confounders(string)} lists the measured confounders. Mark time-varying
confounders with "(TV)".

{phang}
{opt outcome(string)} defines the outcome of interest.

{phang}
{opt causal_contrast(string)} specifies the causal contrast (e.g., "always
treated vs never treated").

{phang}
{opt weight_spec(string)} documents the weight specification (e.g.,
"stabilized IPTW, 1/99 truncation").

{phang}
{opt analysis(string)} describes the statistical analysis plan.

{dlgtab:Export}

{phang}
{opt export(string)} specifies the file path for export.

{phang}
{opt format(string)} specifies output format: {cmd:display} (default),
{cmd:csv}, {cmd:excel}, or {cmd:latex}.

{phang}
{opt replace} allows overwriting an existing file.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults with chronic condition")}{p_end}
{phang2}{cmd:    treatment("Drug A initiation vs no initiation")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("All-cause mortality")}{p_end}
{phang2}{cmd:    causal_contrast("Always treated vs never treated")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE")}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

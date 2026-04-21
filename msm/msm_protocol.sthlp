{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_prepare" "help msm_prepare"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{viewerjumpto "Syntax" "msm_protocol##syntax"}{...}
{viewerjumpto "Description" "msm_protocol##description"}{...}
{viewerjumpto "Options" "msm_protocol##options"}{...}
{viewerjumpto "Stored results" "msm_protocol##results"}{...}
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
{opt caus:al_contrast(string)} {opt weight:_spec(string)}
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
{synopt:{opt weight:_spec(string)}}weight specification{p_end}
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

{pstd}
Use this command to make the target trial explicit before weighting and
estimation. In the current {cmd:msm} workflow, the downstream prediction
examples are built around static strategies such as always treated versus
never treated rather than dynamic intervention rules.


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
{opt weight:_spec(string)} documents the weight specification (e.g.,
"stabilized IPTW, 1/99 truncation").

{phang}
{opt analysis(string)} describes the statistical analysis plan.

{dlgtab:Export}

{phang}
{opt export(string)} specifies the file path for export.

{phang}
{opt format(string)} specifies output format: {cmd:display} (default),
{cmd:csv}, {cmd:excel}, or {cmd:latex}. Use {cmd:export()} with all
non-display formats.

{phang}
{opt replace} allows overwriting an existing file.


{marker examples}{...}
{title:Examples}

{pstd}Display a target-trial style protocol in the Results window{p_end}
{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults with chronic condition")}{p_end}
{phang2}{cmd:    treatment("Drug A initiation vs no initiation")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("All-cause mortality")}{p_end}
{phang2}{cmd:    causal_contrast("Always treated vs never treated")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE")}{p_end}

{pstd}Export the same protocol to CSV for supplement material{p_end}
{phang2}{cmd:. local proto_csv "`c(tmpdir)'/msm_protocol.csv"}{p_end}
{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults with chronic condition")}{p_end}
{phang2}{cmd:    treatment("Drug A initiation vs no initiation")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("All-cause mortality")}{p_end}
{phang2}{cmd:    causal_contrast("Always treated vs never treated")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE")}{p_end}
{phang2}{cmd:    export("`proto_csv'") format(csv) replace}{p_end}

{pstd}Export to Excel for a study file or protocol appendix{p_end}
{phang2}{cmd:. local proto_xlsx "`c(tmpdir)'/msm_protocol.xlsx"}{p_end}
{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults with chronic condition")}{p_end}
{phang2}{cmd:    treatment("Drug A initiation vs no initiation")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("All-cause mortality")}{p_end}
{phang2}{cmd:    causal_contrast("Always treated vs never treated")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE")}{p_end}
{phang2}{cmd:    export("`proto_xlsx'") format(excel) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_protocol} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(population)}}target population definition{p_end}
{synopt:{cmd:r(treatment)}}treatment strategies compared{p_end}
{synopt:{cmd:r(confounders)}}confounders measured{p_end}
{synopt:{cmd:r(outcome)}}outcome definition{p_end}
{synopt:{cmd:r(causal_contrast)}}causal contrast{p_end}
{synopt:{cmd:r(weight_spec)}}weight specification{p_end}
{synopt:{cmd:r(analysis)}}statistical analysis plan{p_end}
{synopt:{cmd:r(format)}}output format{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}

{smcl}
{* *! version 1.0.2  06may2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_prepare" "help msm_prepare"}{...}
{vieweralsosee "msm_report" "help msm_report"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{viewerjumpto "Syntax" "msm_protocol##syntax"}{...}
{viewerjumpto "Description" "msm_protocol##description"}{...}
{viewerjumpto "The 7 components" "msm_protocol##components"}{...}
{viewerjumpto "Options" "msm_protocol##options"}{...}
{viewerjumpto "Examples" "msm_protocol##examples"}{...}
{viewerjumpto "Stored results" "msm_protocol##results"}{...}
{viewerjumpto "References" "msm_protocol##references"}{...}
{viewerjumpto "Author" "msm_protocol##author"}{...}

{title:Title}

{phang}
{bf:msm_protocol} {hline 2} MSM study protocol specification


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_protocol}
{cmd:,} {opt pop:ulation(string)} {opt treat:ment(string)}
{opt conf:ounders(string)} {opt out:come(string)}
{opt caus:al_contrast(string)} {opt weight:_spec(string)}
{opt ana:lysis(string)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required (7 components)}
{synopt:{opt pop:ulation(string)}}target population definition{p_end}
{synopt:{opt treat:ment(string)}}treatment strategies compared{p_end}
{synopt:{opt conf:ounders(string)}}confounders measured{p_end}
{synopt:{opt out:come(string)}}outcome definition{p_end}
{synopt:{opt caus:al_contrast(string)}}causal contrast{p_end}
{synopt:{opt weight:_spec(string)}}weight specification{p_end}
{synopt:{opt ana:lysis(string)}}statistical analysis plan{p_end}

{syntab:Export}
{synopt:{opt exp:ort(string)}}file path for export{p_end}
{synopt:{opt for:mat(string)}}{cmd:display} (default), {cmd:csv}, {cmd:excel}, or {cmd:latex}{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_protocol} documents the study protocol for an MSM analysis using a
7-component framework adapted from the target trial emulation approach of
Hernan, Robins, and colleagues.  The idea is to make the causal question
explicit {it:before} running any statistical code, just as a clinical trial
protocol is written before enrollment begins.

{pstd}
All 7 components are required.  The command displays the protocol in the
Results window by default, or exports it to CSV, Excel, or LaTeX for
inclusion in manuscripts, supplementary materials, or study documentation.

{pstd}
{cmd:msm_protocol} does not modify the dataset or affect downstream commands.
It is purely a documentation tool.  We recommend running it as the first step
in every analysis script.


{marker components}{...}
{title:The 7 components}

{phang2}1. {bf:Population} {hline 2} Who is in the study?  Specify inclusion
and exclusion criteria (e.g., "Adults aged 18-65 with condition X").{p_end}

{phang2}2. {bf:Treatment strategies} {hline 2} What treatment regimes are being
compared?  The {cmd:msm} package currently supports static strategies such as
"always treated vs. never treated".{p_end}

{phang2}3. {bf:Confounders} {hline 2} Which time-varying and baseline
confounders are measured?  Mark time-varying confounders with "(TV)" (e.g.,
"Biomarker (TV), comorbidity (TV), age, sex").{p_end}

{phang2}4. {bf:Outcome} {hline 2} What is the outcome of interest?  Be
specific about the definition and coding (e.g., "All-cause mortality within
follow-up").{p_end}

{phang2}5. {bf:Causal contrast} {hline 2} What parameter is being estimated?
(e.g., "Average treatment effect: always treated vs. never treated").{p_end}

{phang2}6. {bf:Weight specification} {hline 2} How are the inverse probability
weights constructed?  Document stabilization, truncation, and any censoring
weights (e.g., "Stabilized IPTW, truncated at 1st/99th percentile").{p_end}

{phang2}7. {bf:Statistical analysis} {hline 2} What outcome model and estimation
approach?  (e.g., "Pooled logistic regression with robust SE clustered by
ID").{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required (7 components)}

{phang}
{opt pop:ulation(string)} describes the target population.

{phang}
{opt treat:ment(string)} describes the treatment strategies being compared.

{phang}
{opt conf:ounders(string)} lists the measured confounders.

{phang}
{opt out:come(string)} defines the outcome of interest.

{phang}
{opt caus:al_contrast(string)} specifies the causal contrast.

{phang}
{opt weight:_spec(string)} documents the weight specification.

{phang}
{opt ana:lysis(string)} describes the statistical analysis plan.

{dlgtab:Export}

{phang}
{opt exp:ort(string)} specifies the file path for export.

{phang}
{opt for:mat(string)} specifies the output format.  {cmd:display} (default)
prints to the Results window.  {cmd:csv} writes a comma-separated file.
{cmd:excel} writes an Excel workbook.  {cmd:latex} writes a LaTeX table
using {cmd:booktabs} formatting.

{phang}
{opt replace} allows overwriting an existing file.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Display a protocol in the Results window:}{p_end}

{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults aged 18-65 with condition X")}{p_end}
{phang2}{cmd:    treatment("Always treat vs. never treat")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("Binary clinical endpoint")}{p_end}
{phang2}{cmd:    causal_contrast("ATE: always treat vs. never treat")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE clustered by ID")}{p_end}

{pstd}
{bf:Export to CSV for supplement material:}{p_end}

{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults with chronic condition")}{p_end}
{phang2}{cmd:    treatment("Drug A initiation vs no initiation")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("All-cause mortality")}{p_end}
{phang2}{cmd:    causal_contrast("Always treated vs never treated")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE")}{p_end}
{phang2}{cmd:    export("protocol.csv") format(csv) replace}{p_end}

{pstd}
{bf:Export to LaTeX for a manuscript methods section:}{p_end}

{phang2}{cmd:. msm_protocol,}{p_end}
{phang2}{cmd:    population("Adults with chronic condition")}{p_end}
{phang2}{cmd:    treatment("Drug A initiation vs no initiation")}{p_end}
{phang2}{cmd:    confounders("Biomarker (TV), comorbidity (TV), age, sex")}{p_end}
{phang2}{cmd:    outcome("All-cause mortality")}{p_end}
{phang2}{cmd:    causal_contrast("Always treated vs never treated")}{p_end}
{phang2}{cmd:    weight_spec("Stabilized IPTW, 1/99 truncation")}{p_end}
{phang2}{cmd:    analysis("Pooled logistic with robust SE")}{p_end}
{phang2}{cmd:    export("protocol.tex") format(latex) replace}{p_end}


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
{synopt:{cmd:r(format)}}output format used{p_end}


{marker references}{...}
{title:References}

{phang}
Robins JM, Hernan MA, Brumback B. Marginal structural models and causal
inference in epidemiology. {it:Epidemiology}. 2000;11(5):550-560.

{phang}
Hernan MA, Robins JM. {it:Causal Inference: What If}. Boca Raton: Chapman &
Hall/CRC, 2020.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}

{smcl}
{* *! version 1.0.3  28feb2026}{...}
{viewerjumpto "Syntax" "nma##syntax"}{...}
{viewerjumpto "Description" "nma##description"}{...}
{viewerjumpto "Commands" "nma##commands"}{...}
{viewerjumpto "Workflow" "nma##workflow"}{...}
{viewerjumpto "Examples" "nma##examples"}{...}
{viewerjumpto "References" "nma##references"}{...}
{viewerjumpto "Author" "nma##author"}{...}

{title:Title}

{phang}
{bf:nma} {hline 2} Network Meta-Analysis suite for Stata


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt list}}display commands as simple list{p_end}
{synopt:{opt detail}}show detailed command descriptions{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma} is a comprehensive suite for network meta-analysis (mixed treatment
comparisons) in Stata. It provides a complete workflow from data setup through
model fitting, visualization, inconsistency testing, and reporting.

{pstd}
Key features:

{phang2}{bf:Zero external dependencies.} All statistical computation is built-in
using Mata, including the multivariate REML engine. No SSC packages required.

{phang2}{bf:Automatic outcome detection.} Handles binary (events/totals),
continuous (mean/sd/n), and rate (events/person-time) outcomes, plus
pre-computed effect sizes.

{phang2}{bf:Smart defaults.} Auto-selects the most connected treatment as
reference, detects multi-arm studies, applies zero-cell corrections
transparently.

{phang2}{bf:Evidence classification.} Every comparison is classified as direct,
indirect, or mixed evidence, displayed throughout the analysis.

{phang2}{bf:Network validation.} Checks connectivity, reports disconnected
components, validates input data before analysis.


{marker commands}{...}
{title:Commands}

{dlgtab:Data Setup}

{phang}
{helpb nma_setup} {hline 2} Import arm-level summary data

{phang}
{helpb nma_import} {hline 2} Import pre-computed effect sizes

{dlgtab:Model Fitting}

{phang}
{helpb nma_fit} {hline 2} Fit consistency model (REML/ML)

{dlgtab:Post-Estimation}

{phang}
{helpb nma_rank} {hline 2} Treatment rankings and SUCRA scores

{phang}
{helpb nma_forest} {hline 2} Forest plot of treatment effects

{phang}
{helpb nma_map} {hline 2} Network geometry visualization

{phang}
{helpb nma_compare} {hline 2} League table of all pairwise comparisons

{dlgtab:Diagnostics & Reporting}

{phang}
{helpb nma_inconsistency} {hline 2} Global test and node-splitting

{phang}
{helpb nma_report} {hline 2} Publication-quality export


{marker workflow}{...}
{title:Typical Workflow}

{phang}1. {cmd:nma_setup} or {cmd:nma_import} {hline 2} Prepare data{p_end}
{phang}2. {cmd:nma_map} {hline 2} Visualize network structure{p_end}
{phang}3. {cmd:nma_fit} {hline 2} Fit consistency model{p_end}
{phang}4. {cmd:nma_forest} {hline 2} Forest plot{p_end}
{phang}5. {cmd:nma_rank} {hline 2} Treatment rankings{p_end}
{phang}6. {cmd:nma_inconsistency} {hline 2} Check consistency assumption{p_end}
{phang}7. {cmd:nma_compare} {hline 2} Full league table{p_end}
{phang}8. {cmd:nma_report} {hline 2} Export for publication{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Overview of available commands{p_end}
{phang2}{cmd:. nma}{p_end}

{pstd}Detailed command descriptions{p_end}
{phang2}{cmd:. nma, detail}{p_end}

{pstd}Full workflow with binary outcome data{p_end}
{phang2}{cmd:. use smoking_nma, clear}{p_end}
{phang2}{cmd:. nma_setup d n, studyvar(study) trtvar(treatment)}{p_end}
{phang2}{cmd:. nma_map}{p_end}
{phang2}{cmd:. nma_fit}{p_end}
{phang2}{cmd:. nma_forest, eform}{p_end}
{phang2}{cmd:. nma_rank, plot cumulative}{p_end}
{phang2}{cmd:. nma_inconsistency}{p_end}
{phang2}{cmd:. nma_compare, eform}{p_end}


{marker references}{...}
{title:References}

{phang}
Salanti G, Higgins J, Ades A, Ioannidis J. 2008. Evaluation of networks
of randomized trials. {it:Statistical Methods in Medical Research} 17: 279-301.

{phang}
Lu G, Ades A. 2004. Combination of direct and indirect evidence in mixed
treatment comparisons. {it:Statistics in Medicine} 23: 3105-3124.

{phang}
Dias S, Welton N, Sutton A, Ades A. 2013. Evidence synthesis for decision
making 2: A generalized linear modeling framework for pairwise and network
meta-analysis. {it:Medical Decision Making} 33: 607-617.

{phang}
Rücker G, Schwarzer G. 2015. Ranking treatments in frequentist network
meta-analysis works without resampling methods.
{it:BMC Medical Research Methodology} 15: 58.


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}

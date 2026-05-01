{smcl}
{* *! version 1.0.1  30apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{viewerjumpto "Syntax" "msm_plot##syntax"}{...}
{viewerjumpto "Description" "msm_plot##description"}{...}
{viewerjumpto "Plot types" "msm_plot##types"}{...}
{viewerjumpto "Options" "msm_plot##options"}{...}
{viewerjumpto "Examples" "msm_plot##examples"}{...}
{viewerjumpto "Stored results" "msm_plot##results"}{...}
{viewerjumpto "Author" "msm_plot##author"}{...}

{title:Title}

{phang}
{bf:msm_plot} {hline 2} Visualization for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_plot}
{cmd:,} {opt type(string)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt type(string)}}plot type (see below){p_end}

{syntab:Balance plot options}
{synopt:{opt cov:ariates(varlist)}}covariates for the Love plot{p_end}
{synopt:{opt thr:eshold(#)}}SMD reference line; default {cmd:0.1}{p_end}

{syntab:Survival plot options}
{synopt:{opt times(numlist)}}time periods for survival curves{p_end}
{synopt:{opt sam:ples(#)}}MC samples for CI bands; default {cmd:50}{p_end}
{synopt:{opt seed(#)}}random seed for survival curves{p_end}

{syntab:Trajectory plot options}
{synopt:{opt n_sample(#)}}individuals to display; default {cmd:50}{p_end}

{syntab:General}
{synopt:{opt title(string)}}custom graph title{p_end}
{synopt:{opt saving(string)}}save graph to file{p_end}
{synopt:{opt replace}}replace existing saved file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_plot} produces diagnostic and results plots for the MSM pipeline.
It uses the current Stata graph scheme by default.  Five plot types are
available, each designed to help assess a specific aspect of the analysis.


{marker types}{...}
{title:Plot types}

{phang}
{bf:weights} {hline 2} Kernel density plots of the IP weight distribution,
separately for treated and untreated observations.  Requires {helpb msm_weight}
to have been run.  Use this to visually assess weight overlap and identify
extreme values.  Well-behaved weights produce roughly symmetric, overlapping
distributions centered near 1.

{phang}
{bf:balance} {hline 2} Love plot showing absolute standardized mean differences
(SMD) before and after weighting.  Requires {helpb msm_weight}.  Each covariate
appears as a row with two markers: one for the unweighted SMD and one for the
weighted SMD.  A vertical dashed line marks the {opt threshold()} value
(default 0.1).  Ideally, all weighted markers should fall to the left of the
threshold line.

{phang}
{bf:survival} {hline 2} Counterfactual cumulative incidence curves with
confidence bands for always-treated and never-treated strategies.  Requires
{helpb msm_fit} with {cmd:model(logistic)}.  The command internally runs
{helpb msm_predict} to generate the curves (using {opt samples()} MC draws),
then restores any prior prediction state so the plot is non-destructive.

{phang}
{bf:trajectory} {hline 2} Spaghetti plot of treatment status over time for a
random sample of individuals.  Requires only {helpb msm_prepare}.  Useful for
visualizing treatment switching patterns and whether treatment is truly
time-varying.  Each individual's treatment trajectory is shown as a separate
line panel.

{phang}
{bf:positivity} {hline 2} Treatment probability (proportion treated) plotted
by period.  Requires only {helpb msm_prepare}.  A horizontal reference line at
0.5 is included.  Use this to identify periods where treatment is nearly
universal or nearly absent, which indicates positivity concerns.


{marker options}{...}
{title:Options}

{phang}
{opt type(string)} specifies the plot type.  Required.  Must be one of
{cmd:weights}, {cmd:balance}, {cmd:survival}, {cmd:trajectory}, or
{cmd:positivity}.

{dlgtab:Balance plot}

{phang}
{opth cov:ariates(varlist)} specifies which covariates to include in the Love
plot.  Defaults to all covariates from {helpb msm_prepare}.

{phang}
{opt thr:eshold(#)} sets the position of the vertical reference line on the
Love plot.  Default is 0.1.

{dlgtab:Survival plot}

{phang}
{opth times(numlist)} specifies time periods for the survival/cumulative
incidence curves.  Required when {cmd:type(survival)} is specified.

{phang}
{opt sam:ples(#)} specifies MC draws for the confidence bands.  Default is
50 (lower than the {helpb msm_predict} default because plotting needs fewer
draws for smooth bands).

{phang}
{opt seed(#)} sets the random seed for the internal {helpb msm_predict} call.

{dlgtab:Trajectory plot}

{phang}
{opt n_sample(#)} specifies the number of randomly sampled individuals to
display.  Default is 50.

{dlgtab:General}

{phang}
{opt title(string)} specifies a custom title for the graph.  Default titles
are provided for each plot type.

{phang}
{opt saving(string)} saves the graph to the specified file path.

{phang}
{opt replace} allows {opt saving()} to overwrite an existing file.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Weight distribution after weighting:}{p_end}

{phang2}{cmd:. msm_plot, type(weights)}{p_end}

{pstd}
{bf:Love plot for covariate balance:}{p_end}

{phang2}{cmd:. msm_plot, type(balance) threshold(0.1)}{p_end}

{pstd}
{bf:Treatment probability by period (positivity check):}{p_end}

{phang2}{cmd:. msm_plot, type(positivity)}{p_end}

{pstd}
{bf:Treatment trajectory spaghetti plot:}{p_end}

{phang2}{cmd:. msm_plot, type(trajectory) n_sample(30) seed(42)}{p_end}

{pstd}
{bf:Counterfactual survival curves after fitting:}{p_end}

{phang2}{cmd:. msm_plot, type(survival) times(1 3 5 7 9) seed(12345)}{p_end}

{pstd}
{bf:Saving a plot to file:}{p_end}

{phang2}{cmd:. msm_plot, type(weights) saving(weight_density.gph) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_plot} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(plot_type)}}plot type produced{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}

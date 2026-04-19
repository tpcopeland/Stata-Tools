{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_predict" "help msm_predict"}{...}
{viewerjumpto "Syntax" "msm_plot##syntax"}{...}
{viewerjumpto "Description" "msm_plot##description"}{...}
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
{synopt:{opt type(string)}}weights, balance, survival, trajectory, or positivity{p_end}
{synopt:{opt cov:ariates(varlist)}}for balance plot{p_end}
{synopt:{opt thr:eshold(#)}}SMD threshold for balance; default 0.1{p_end}
{synopt:{opt times(numlist)}}for survival plot{p_end}
{synopt:{opt sam:ples(#)}}MC samples for survival; default 50{p_end}
{synopt:{opt seed(#)}}random number seed for survival curves{p_end}
{synopt:{opt n_sample(#)}}individuals for trajectory; default 50{p_end}
{synopt:{opt title(string)}}custom title{p_end}
{synopt:{opt saving(string)}}save graph to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_plot} produces diagnostic and results plots:

{phang2}{cmd:weights} - IP weight distribution (kdensity by treatment group){p_end}
{phang2}{cmd:balance} - Love plot (SMD before/after weighting){p_end}
{phang2}{cmd:survival} - Cumulative incidence curves from msm_predict{p_end}
{phang2}{cmd:trajectory} - Treatment spaghetti plot{p_end}
{phang2}{cmd:positivity} - Treatment probability by period{p_end}

{pstd}
{cmd:msm_plot} uses the current Stata scheme by default.


{marker options}{...}
{title:Options}

{phang}
{opt type(string)} specifies the plot type. Required. Options are
{cmd:weights}, {cmd:balance}, {cmd:survival}, {cmd:trajectory}, or
{cmd:positivity}.

{phang}
{opth covariates(varlist)} specifies covariates for the balance (Love)
plot. Defaults to all covariates mapped in {cmd:msm_prepare}.

{phang}
{opt threshold(#)} sets the SMD threshold displayed as a reference line
on the balance plot. Default is 0.1.

{phang}
{opth times(numlist)} specifies time periods for the survival plot.
Required when {cmd:type(survival)} is specified.

{phang}
{opt samples(#)} specifies Monte Carlo samples for survival curve
confidence bands. Default is 50.

{phang}
{opt seed(#)} sets the random number seed for survival curves.

{phang}
{opt n_sample(#)} specifies the number of randomly sampled individuals
to display on the trajectory plot. Default is 50.

{phang}
{opt title(string)} specifies a custom graph title.

{phang}
{opt saving(string)} saves the graph to the specified file.

{phang}
{opt replace} allows {opt saving()} to overwrite an existing file.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_plot, type(weights)}{p_end}
{phang2}{cmd:. msm_plot, type(balance) threshold(0.1)}{p_end}
{phang2}{cmd:. msm_plot, type(positivity)}{p_end}
{phang2}{cmd:. msm_plot, type(survival) times(1 3 5 7 9) seed(42)}{p_end}


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
Timothy P Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

{hline}

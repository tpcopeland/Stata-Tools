{smcl}
{* *! version 1.0.1  14mar2026}{...}
{viewerjumpto "Syntax" "msm_plot##syntax"}{...}
{viewerjumpto "Description" "msm_plot##description"}{...}
{viewerjumpto "Examples" "msm_plot##examples"}{...}
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
{synopt:{opth cov:ariates(varlist)}}for balance plot{p_end}
{synopt:{opt thr:eshold(#)}}SMD threshold for balance; default 0.1{p_end}
{synopt:{opth times(numlist)}}for survival plot{p_end}
{synopt:{opt sam:ples(#)}}MC samples for survival; default 50{p_end}
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


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. msm_plot, type(weights)}{p_end}
{phang2}{cmd:. msm_plot, type(balance) threshold(0.1)}{p_end}
{phang2}{cmd:. msm_plot, type(positivity)}{p_end}
{phang2}{cmd:. msm_plot, type(survival) times(1 3 5 7 9) seed(42)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland, Karolinska Institutet{break}
timothy.copeland@ki.se
{p_end}

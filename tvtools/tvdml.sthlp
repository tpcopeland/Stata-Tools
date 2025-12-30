{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{vieweralsosee "tvestimate" "help tvestimate"}{...}
{viewerjumpto "Syntax" "tvdml##syntax"}{...}
{viewerjumpto "Description" "tvdml##description"}{...}
{viewerjumpto "Options" "tvdml##options"}{...}
{viewerjumpto "Examples" "tvdml##examples"}{...}
{viewerjumpto "Stored results" "tvdml##results"}{...}
{viewerjumpto "Author" "tvdml##author"}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:tvdml} {hline 2}}Double/Debiased Machine Learning for causal inference{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 14 2}
{cmd:tvdml}
{depvar} {it:treatment}
{ifin}{cmd:,}
{opt cov:ariates(varlist)}
[{it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt cov:ariates(varlist)}}high-dimensional covariates{p_end}

{syntab:Model}
{synopt:{opt method(string)}}ML method: {bf:lasso}, ridge, elasticnet{p_end}
{synopt:{opt crossfit(#)}}cross-fitting folds; default is 5{p_end}

{syntab:Reporting}
{synopt:{opt seed(#)}}random seed{p_end}
{synopt:{opt level(#)}}confidence level; default is 95{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvdml} implements double/debiased machine learning (DML) for estimating
causal effects when there are many potential confounders. It uses cross-fitting
with LASSO (or other ML methods) to estimate nuisance functions while maintaining
valid inference.


{marker options}{...}
{title:Options}

{phang}
{opt covariates(varlist)} specifies the high-dimensional confounders.

{phang}
{opt method(string)} specifies the ML method for nuisance estimation.

{phang}
{opt crossfit(#)} specifies the number of cross-fitting folds. Default is 5.


{marker examples}{...}
{title:Examples}

{pstd}Basic DML estimation{p_end}
{phang2}{cmd:. tvdml outcome treatment, covariates(x1-x50) crossfit(5)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvdml} stores results in {cmd:e()}.

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(psi)}}causal effect estimate{p_end}
{synopt:{cmd:e(se_psi)}}standard error{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet

{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{vieweralsosee "mlearn_cv" "help mlearn_cv"}{...}
{vieweralsosee "[R] estimates" "help estimates"}{...}
{viewerjumpto "Syntax" "mlearn_compare##syntax"}{...}
{viewerjumpto "Description" "mlearn_compare##description"}{...}
{viewerjumpto "Options" "mlearn_compare##options"}{...}
{viewerjumpto "Remarks" "mlearn_compare##remarks"}{...}
{viewerjumpto "Examples" "mlearn_compare##examples"}{...}
{viewerjumpto "Stored results" "mlearn_compare##results"}{...}
{viewerjumpto "Author" "mlearn_compare##author"}{...}
{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:mlearn compare} {hline 2}}Compare stored mlearn models{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mlearn compare}
[{it:namelist}]

{pstd}
where {it:namelist} is a list of names previously stored via
{cmd:estimates store} after {cmd:mlearn train} or {cmd:mlearn cv}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn compare} displays a side-by-side comparison table of
performance metrics from two or more stored model estimates. It uses
{cmd:estimates table} internally to show metrics (accuracy, AUC, F1,
RMSE, MAE, R-squared) alongside sample sizes and model metadata (method,
task type).

{pstd}
If no {it:namelist} is specified, all stored estimates are compared.
At least two stored estimates are required.


{marker options}{...}
{title:Options}

{pstd}
{cmd:mlearn compare} has no options. Model names are specified as positional
arguments.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Workflow}

{pstd}
Train multiple models, store each with {cmd:estimates store}, then compare:

{phang2}{cmd:. mlearn y x1 x2, method(forest) seed(42)}{p_end}
{phang2}{cmd:. estimates store rf}{p_end}
{phang2}{cmd:. mlearn y x1 x2, method(xgboost) seed(42)}{p_end}
{phang2}{cmd:. estimates store xgb}{p_end}
{phang2}{cmd:. mlearn compare rf xgb}{p_end}

{pstd}
{bf:Comparing train vs. CV}

{pstd}
You can compare models from {cmd:mlearn train} and {cmd:mlearn cv} in the
same table. CV models will have {cmd:e(folds)} populated, while train models
will have {cmd:e(n_train)} and {cmd:e(n_test)}.

{pstd}
{bf:Note}

{pstd}
{cmd:mlearn compare} restores each estimate to read its metadata. The last
restored estimate will be active after the command completes.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Compare two classifiers}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. estimates store rf}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(xgboost) seed(42)}{p_end}
{phang2}{cmd:. estimates store xgb}{p_end}
{phang2}{cmd:. mlearn compare rf xgb}{p_end}

{pstd}
{bf:Example 2: Compare CV results across methods}

{phang2}{cmd:. mlearn cv foreign weight length mpg, method(forest) folds(5) seed(42)}{p_end}
{phang2}{cmd:. estimates store rf_cv}{p_end}
{phang2}{cmd:. mlearn cv foreign weight length mpg, method(boost) folds(5) seed(42)}{p_end}
{phang2}{cmd:. estimates store gb_cv}{p_end}
{phang2}{cmd:. mlearn cv foreign weight length mpg, method(elasticnet) folds(5) seed(42)}{p_end}
{phang2}{cmd:. estimates store en_cv}{p_end}
{phang2}{cmd:. mlearn compare rf_cv gb_cv en_cv}{p_end}

{pstd}
{bf:Example 3: Compare all stored estimates}

{phang2}{cmd:. mlearn compare}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn compare} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_models)}}number of models compared{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(models)}}names of compared models{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_train}, {helpb mlearn_cv},
{helpb estimates}

{hline}

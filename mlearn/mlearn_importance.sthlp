{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{vieweralsosee "mlearn_shap" "help mlearn_shap"}{...}
{viewerjumpto "Syntax" "mlearn_importance##syntax"}{...}
{viewerjumpto "Description" "mlearn_importance##description"}{...}
{viewerjumpto "Options" "mlearn_importance##options"}{...}
{viewerjumpto "Remarks" "mlearn_importance##remarks"}{...}
{viewerjumpto "Examples" "mlearn_importance##examples"}{...}
{viewerjumpto "Stored results" "mlearn_importance##results"}{...}
{viewerjumpto "Author" "mlearn_importance##author"}{...}
{title:Title}

{p2colset 5 28 30 2}{...}
{p2col:{cmd:mlearn importance} {hline 2}}Feature importance from a trained model{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mlearn importance}
{cmd:,}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt plot}}display a horizontal bar chart of feature importances{p_end}
{synopt:{opt nolog}}suppress the tabular display{p_end}
{synopt:{opt using(filename)}}load model from a saved file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn importance} extracts and displays feature importance scores
from a previously trained machine learning model. The model is located via
dataset characteristics set by {helpb mlearn_train}, or loaded from a file
specified with {opt using()}.

{pstd}
For tree-based models (forest, boost, xgboost, lightgbm), this uses
impurity-based (Gini / variance reduction) importance. For linear models
(elasticnet), it uses absolute coefficient values. For other models (svm,
nnet), permutation importance is used.


{marker options}{...}
{title:Options}

{phang}
{opt plot} generates a horizontal bar chart of feature importances sorted
from most to least important. The plot uses {cmd:scheme(plotplainblind)}.

{phang}
{opt nolog} suppresses the tabular display of feature importances.

{phang}
{opt using(filename)} loads the model from a previously saved file instead
of looking up the model path from dataset characteristics.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Importance types}

{pstd}
Impurity-based importance measures how much each feature contributes to
reducing prediction error across tree splits. It is fast to compute but
can be biased toward high-cardinality features. For more robust
feature-level explanations, consider {helpb mlearn_shap}.

{pstd}
{bf:Plotting}

{pstd}
The {opt plot} option creates a temporary dataset in memory (using
{cmd:preserve}/{cmd:restore}) to build the bar chart. The original data
are restored after plotting.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Display feature importance table}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. mlearn importance}{p_end}

{pstd}
{bf:Example 2: Feature importance with bar chart}

{phang2}{cmd:. mlearn importance, plot}{p_end}

{pstd}
{bf:Example 3: Using a saved model}

{phang2}{cmd:. mlearn importance, using(mymodel.pkl)}{p_end}

{pstd}
{bf:Example 4: Suppress table, show plot only}

{phang2}{cmd:. mlearn importance, plot nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn importance} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(n_features)}}number of features{p_end}
{synopt:{cmd:r(imp_{it:varname})}}importance score for each feature variable{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(method)}}ML method of the trained model{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_train}, {helpb mlearn_shap},
{helpb mlearn_predict}

{hline}

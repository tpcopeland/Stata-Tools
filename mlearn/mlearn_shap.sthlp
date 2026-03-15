{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{vieweralsosee "mlearn_importance" "help mlearn_importance"}{...}
{viewerjumpto "Syntax" "mlearn_shap##syntax"}{...}
{viewerjumpto "Description" "mlearn_shap##description"}{...}
{viewerjumpto "Options" "mlearn_shap##options"}{...}
{viewerjumpto "Remarks" "mlearn_shap##remarks"}{...}
{viewerjumpto "Examples" "mlearn_shap##examples"}{...}
{viewerjumpto "Stored results" "mlearn_shap##results"}{...}
{viewerjumpto "Author" "mlearn_shap##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:mlearn shap} {hline 2}}SHAP values for model interpretation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mlearn shap}
{cmd:,}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt plot}}generate a SHAP summary plot via Python's shap library{p_end}
{synopt:{opt maxs:amples(#)}}maximum number of observations for SHAP computation; default {cmd:500}{p_end}
{synopt:{opt nolog}}suppress the tabular display{p_end}
{synopt:{opt using(filename)}}load model from a saved file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn shap} computes SHAP (SHapley Additive exPlanations) values for
a previously trained machine learning model. SHAP values provide a
theoretically grounded, per-observation measure of each feature's
contribution to the prediction.

{pstd}
The command displays mean absolute SHAP values for each feature, which
summarize each feature's average impact on model output magnitude. Features
with larger mean |SHAP| values are more influential.

{pstd}
Requires the Python {cmd:shap} package. Install it with
{cmd:mlearn setup, install(shap)}.


{marker options}{...}
{title:Options}

{phang}
{opt plot} generates a SHAP summary plot using Python's shap library. For
tree-based models, this produces a beeswarm plot showing the distribution
of SHAP values for each feature. Requires a graphical display.

{phang}
{opt maxsamples(#)} limits the number of observations used for SHAP
computation. The default is {cmd:500}. Reducing this speeds up computation
for large datasets. SHAP values are computed on a random sample of this
size when the dataset exceeds it.

{phang}
{opt nolog} suppresses the tabular display of mean absolute SHAP values.

{phang}
{opt using(filename)} loads the model from a previously saved file instead
of looking up the model path from dataset characteristics.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:SHAP explainer selection}

{pstd}
For tree-based models (forest, boost, xgboost, lightgbm), {cmd:mlearn shap}
uses the fast TreeExplainer. For other model types (svm, nnet, elasticnet),
it falls back to the slower KernelExplainer. KernelExplainer can be
significantly slower, so consider reducing {opt maxsamples()}.

{pstd}
{bf:SHAP vs. impurity importance}

{pstd}
SHAP values are more theoretically grounded than impurity-based feature
importance ({helpb mlearn_importance}). They are additive, consistent, and
account for feature interactions. However, they are more expensive to
compute. Use {cmd:mlearn importance} for a quick overview and
{cmd:mlearn shap} for detailed interpretation.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Display SHAP importance table}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. mlearn shap}{p_end}

{pstd}
{bf:Example 2: SHAP with summary plot}

{phang2}{cmd:. mlearn shap, plot}{p_end}

{pstd}
{bf:Example 3: Limit sample size for faster computation}

{phang2}{cmd:. mlearn shap, maxsamples(100)}{p_end}

{pstd}
{bf:Example 4: Using a saved model}

{phang2}{cmd:. mlearn shap, using(mymodel.pkl)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn shap} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(n_features)}}number of features{p_end}
{synopt:{cmd:r(n_samples)}}number of observations used for SHAP computation{p_end}
{synopt:{cmd:r(shap_{it:varname})}}mean |SHAP| value for each feature variable{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(method)}}ML method of the trained model{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_train}, {helpb mlearn_importance},
{helpb mlearn_predict}

{hline}

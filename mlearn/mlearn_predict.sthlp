{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{vieweralsosee "mlearn_cv" "help mlearn_cv"}{...}
{viewerjumpto "Syntax" "mlearn_predict##syntax"}{...}
{viewerjumpto "Description" "mlearn_predict##description"}{...}
{viewerjumpto "Options" "mlearn_predict##options"}{...}
{viewerjumpto "Remarks" "mlearn_predict##remarks"}{...}
{viewerjumpto "Examples" "mlearn_predict##examples"}{...}
{viewerjumpto "Stored results" "mlearn_predict##results"}{...}
{viewerjumpto "Author" "mlearn_predict##author"}{...}
{title:Title}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:mlearn predict} {hline 2}}Generate predictions from a trained model{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mlearn predict}
{ifin}
{cmd:,}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt gen:erate(name)}}name for prediction variable; default {cmd:_mlearn_pred}{p_end}
{synopt:{opt pr:obability}}predict probabilities instead of class labels (classification only){p_end}
{synopt:{opt cl:ass}}predict class labels; the default for classification{p_end}
{synopt:{opt replace}}replace existing prediction variable if it exists{p_end}
{synopt:{opt using(filename)}}load model from a saved file instead of dataset characteristics{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn predict} generates predictions from a previously trained
machine learning model. The model is located via dataset characteristics
set by {helpb mlearn_train}, or loaded from a file specified with
{opt using()}.

{pstd}
For classification tasks, {cmd:mlearn predict} produces predicted class
labels by default. Use {opt probability} to get predicted probabilities
instead.

{pstd}
For regression tasks, {cmd:mlearn predict} produces predicted values.

{pstd}
Feature variables are read from the dataset characteristics stored during
training. All feature variables must exist in the current dataset and have
no missing values in the prediction sample.


{marker options}{...}
{title:Options}

{phang}
{opt generate(name)} specifies the name of the new variable to hold
predictions. The default is {cmd:_mlearn_pred}. The variable is created as
{cmd:double}.

{phang}
{opt probability} requests predicted probabilities instead of class labels.
This option is valid only for classification tasks.

{phang}
{opt class} requests predicted class labels. This is the default for
classification tasks and is ignored for regression tasks.

{phang}
{opt replace} allows overwriting an existing variable with the same name
as the prediction variable. Without this option, the command will error if
the variable already exists.

{phang}
{opt using(filename)} loads the model from a previously saved file (created
with {cmd:mlearn train, saving()}) instead of looking up the model path from
dataset characteristics. Useful for cross-session prediction.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Model lookup}

{pstd}
{cmd:mlearn predict} first checks for a {opt using()} path. If none is
provided, it reads the model path from {cmd:_dta[_mlearn_model_path]}, which
was set by {helpb mlearn_train}. If neither exists, the command errors.

{pstd}
{bf:Missing values}

{pstd}
Observations with missing values on any feature variable are excluded from
prediction (marked missing in the output variable).


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic prediction after training}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. mlearn predict, generate(yhat)}{p_end}

{pstd}
{bf:Example 2: Predicted probabilities}

{phang2}{cmd:. mlearn predict, generate(phat) probability}{p_end}

{pstd}
{bf:Example 3: Replace existing predictions}

{phang2}{cmd:. mlearn predict, generate(yhat) replace}{p_end}

{pstd}
{bf:Example 4: Predict using a saved model}

{phang2}{cmd:. mlearn predict, generate(yhat) using(mymodel.pkl)}{p_end}

{pstd}
{bf:Example 5: Predict on a subset}

{phang2}{cmd:. mlearn predict if rep78 >= 3, generate(yhat_sub)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn predict} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations with predictions{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(predict_var)}}name of the prediction variable{p_end}
{synopt:{cmd:r(model_path)}}path to the model file used{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_train}, {helpb mlearn_importance},
{helpb mlearn_shap}

{hline}

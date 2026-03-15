{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{vieweralsosee "mlearn_tune" "help mlearn_tune"}{...}
{vieweralsosee "mlearn_compare" "help mlearn_compare"}{...}
{viewerjumpto "Syntax" "mlearn_cv##syntax"}{...}
{viewerjumpto "Description" "mlearn_cv##description"}{...}
{viewerjumpto "Options" "mlearn_cv##options"}{...}
{viewerjumpto "Remarks" "mlearn_cv##remarks"}{...}
{viewerjumpto "Examples" "mlearn_cv##examples"}{...}
{viewerjumpto "Stored results" "mlearn_cv##results"}{...}
{viewerjumpto "Author" "mlearn_cv##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:mlearn cv} {hline 2}}K-fold cross-validation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mlearn cv}
{it:outcome} {it:features}
{ifin}
{cmd:,}
{opt method(string)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt method(string)}}ML method: {cmd:forest}, {cmd:boost}, {cmd:xgboost}, {cmd:lightgbm}, {cmd:svm}, {cmd:nnet}, {cmd:elasticnet}{p_end}

{syntab:Cross-validation}
{synopt:{opt folds(#)}}number of CV folds; default {cmd:5}{p_end}

{syntab:Hyperparameters}
{synopt:{opt ntr:ees(#)}}number of trees; default {cmd:100}{p_end}
{synopt:{opt maxd:epth(#)}}maximum tree depth; default {cmd:6}{p_end}
{synopt:{opt lr:ate(#)}}learning rate; default {cmd:0.1}{p_end}
{synopt:{opt hparams(string)}}additional key=value hyperparameters{p_end}

{syntab:Options}
{synopt:{opt task(string)}}override auto-detection: {cmd:classification}, {cmd:regression}, {cmd:multiclass}{p_end}
{synopt:{opt seed(#)}}random seed for reproducibility{p_end}
{synopt:{opt nolog}}suppress output{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn cv} performs K-fold cross-validation to estimate the
out-of-sample predictive performance of a machine learning model.
The data are split into {it:K} folds; each fold is held out once as a
validation set while the remaining folds are used for training. Results
include the mean and standard deviation of each performance metric
across folds.

{pstd}
The first variable in the varlist is the outcome; remaining variables are
features. All variables must be numeric with no missing values.

{pstd}
Results are posted to {cmd:e()} so they can be used with
{cmd:estimates store} and {helpb mlearn_compare}.  The variance matrix
{cmd:e(V)} contains the squared standard deviations of the cross-validated
metrics, enabling {cmd:estimates table} comparisons.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt method(string)} specifies the machine learning method. See
{help mlearn##methods:mlearn Methods} for the full list.

{dlgtab:Cross-validation}

{phang}
{opt folds(#)} specifies the number of cross-validation folds. The default
is {cmd:5}. Must be between 2 and N (the number of observations).

{dlgtab:Hyperparameters}

{phang}
{opt ntrees(#)} specifies the number of trees for tree-based methods.
The default is {cmd:100}.

{phang}
{opt maxdepth(#)} specifies the maximum tree depth. The default is {cmd:6}.

{phang}
{opt lrate(#)} specifies the learning rate for boosting methods. The
default is {cmd:0.1}.

{phang}
{opt hparams(string)} passes additional hyperparameters as key=value pairs
to the underlying Python estimator.

{dlgtab:Options}

{phang}
{opt task(string)} overrides auto-detection of the task type. Valid values
are {cmd:classification}, {cmd:regression}, and {cmd:multiclass}.

{phang}
{opt seed(#)} sets the random seed for reproducibility of fold assignments.

{phang}
{opt nolog} suppresses the progress messages and results table.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Choosing the number of folds}

{pstd}
Common choices are 5-fold and 10-fold CV. More folds give less biased
estimates of performance but increase computation time. Leave-one-out CV
({it:K} = N) is the most expensive but can be useful for small datasets.

{pstd}
{bf:Classification metrics}

{pstd}
For classification tasks, the reported metrics are accuracy, F1 score, and
AUC (area under the ROC curve, binary classification only). For multiclass
tasks, AUC is not reported.

{pstd}
{bf:Regression metrics}

{pstd}
For regression tasks, the reported metrics are RMSE (root mean squared
error), MAE (mean absolute error), and R-squared.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: 5-fold CV with random forest}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn cv foreign weight length mpg, method(forest) seed(42)}{p_end}

{pstd}
{bf:Example 2: 10-fold CV with gradient boosting}

{phang2}{cmd:. mlearn cv price weight length mpg, method(boost) folds(10) seed(42)}{p_end}

{pstd}
{bf:Example 3: Compare methods via CV}

{phang2}{cmd:. mlearn cv foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. estimates store rf_cv}{p_end}
{phang2}{cmd:. mlearn cv foreign weight length mpg, method(xgboost) seed(42)}{p_end}
{phang2}{cmd:. estimates store xgb_cv}{p_end}
{phang2}{cmd:. mlearn compare rf_cv xgb_cv}{p_end}

{pstd}
{bf:Example 4: Custom hyperparameters}

{phang2}{cmd:. mlearn cv foreign weight length mpg, method(forest) ntrees(500) maxdepth(10) folds(5) seed(42)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn cv} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}
{synopt:{cmd:e(folds)}}number of folds{p_end}
{synopt:{cmd:e(n_features)}}number of feature variables{p_end}
{synopt:{cmd:e(seed)}}random seed used{p_end}
{synopt:{cmd:e(accuracy)}}mean accuracy (classification){p_end}
{synopt:{cmd:e(sd_accuracy)}}SD of accuracy across folds{p_end}
{synopt:{cmd:e(auc)}}mean AUC (binary classification){p_end}
{synopt:{cmd:e(sd_auc)}}SD of AUC across folds{p_end}
{synopt:{cmd:e(f1)}}mean F1 score (classification){p_end}
{synopt:{cmd:e(sd_f1)}}SD of F1 score across folds{p_end}
{synopt:{cmd:e(rmse)}}mean RMSE (regression){p_end}
{synopt:{cmd:e(sd_rmse)}}SD of RMSE across folds{p_end}
{synopt:{cmd:e(mae)}}mean MAE (regression){p_end}
{synopt:{cmd:e(sd_mae)}}SD of MAE across folds{p_end}
{synopt:{cmd:e(r2)}}mean R-squared (regression){p_end}
{synopt:{cmd:e(sd_r2)}}SD of R-squared across folds{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:mlearn}{p_end}
{synopt:{cmd:e(subcmd)}}{cmd:cv}{p_end}
{synopt:{cmd:e(method)}}ML method used{p_end}
{synopt:{cmd:e(task)}}task type (classification, regression, multiclass){p_end}
{synopt:{cmd:e(outcome)}}outcome variable{p_end}
{synopt:{cmd:e(features)}}feature variables{p_end}
{synopt:{cmd:e(depvar)}}outcome variable name{p_end}
{synopt:{cmd:e(title)}}title string{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}mean performance metrics vector{p_end}
{synopt:{cmd:e(V)}}variance matrix (squared SDs of metrics){p_end}

{p2col 5 20 24 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}estimation sample{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_train}, {helpb mlearn_tune},
{helpb mlearn_compare}

{hline}

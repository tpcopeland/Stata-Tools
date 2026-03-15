{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_predict" "help mlearn_predict"}{...}
{vieweralsosee "mlearn_cv" "help mlearn_cv"}{...}
{vieweralsosee "mlearn_tune" "help mlearn_tune"}{...}
{vieweralsosee "mlearn_importance" "help mlearn_importance"}{...}
{viewerjumpto "Syntax" "mlearn_train##syntax"}{...}
{viewerjumpto "Description" "mlearn_train##description"}{...}
{viewerjumpto "Options" "mlearn_train##options"}{...}
{viewerjumpto "Remarks" "mlearn_train##remarks"}{...}
{viewerjumpto "Examples" "mlearn_train##examples"}{...}
{viewerjumpto "Stored results" "mlearn_train##results"}{...}
{viewerjumpto "Author" "mlearn_train##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:mlearn train} {hline 2}}Train a machine learning model{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mlearn}
[{cmd:train}]
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

{syntab:Hyperparameters}
{synopt:{opt ntr:ees(#)}}number of trees; default {cmd:100}{p_end}
{synopt:{opt maxd:epth(#)}}maximum tree depth; default {cmd:6}{p_end}
{synopt:{opt lr:ate(#)}}learning rate; default {cmd:0.1}{p_end}
{synopt:{opt hparams(string)}}additional key=value hyperparameters{p_end}

{syntab:Options}
{synopt:{opt task(string)}}override auto-detection: {cmd:classification}, {cmd:regression}, {cmd:multiclass}{p_end}
{synopt:{opt seed(#)}}random seed for reproducibility{p_end}
{synopt:{opt sav:ing(filename)}}save model to file{p_end}
{synopt:{opt trainp:ct(#)}}train/test split ratio; default {cmd:1} (no split){p_end}
{synopt:{opt nolog}}suppress training output{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn train} (or simply {cmd:mlearn}) trains a machine learning model
using Python's scikit-learn, XGBoost, or LightGBM via Stata 16+'s
{cmd:python:} directive.

{pstd}
The first variable in the varlist is the outcome; remaining variables are
features. All variables must be numeric with no missing values in the
estimation sample.

{pstd}
The task type (classification vs. regression) is auto-detected from the
outcome variable: binary 0/1 triggers classification, continuous values
trigger regression. Use {opt task()} to override.

{pstd}
Results are posted to {cmd:e()} and the model is serialized to a temporary
file for use by {helpb mlearn_predict}, {helpb mlearn_importance}, and
{helpb mlearn_shap}. Use {opt saving()} to persist the model across sessions.
Dataset characteristics are stored so subsequent subcommands can locate the
model and feature variables automatically.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt method(string)} specifies the machine learning method. Supported values
are {cmd:forest} (Random Forest), {cmd:boost} (Gradient Boosting),
{cmd:xgboost} (XGBoost), {cmd:lightgbm} (LightGBM), {cmd:svm} (Support
Vector Machine), {cmd:nnet} (Neural Network / MLP), and {cmd:elasticnet}
(ElasticNet / Lasso).

{dlgtab:Hyperparameters}

{phang}
{opt ntrees(#)} specifies the number of trees for tree-based methods
(forest, boost, xgboost, lightgbm). The default is {cmd:100}. Must be >= 1.

{phang}
{opt maxdepth(#)} specifies the maximum tree depth for tree-based methods.
The default is {cmd:6}. Must be >= 1.

{phang}
{opt lrate(#)} specifies the learning rate for boosting methods (boost,
xgboost, lightgbm). The default is {cmd:0.1}. Must be > 0.

{phang}
{opt hparams(string)} passes additional hyperparameters as key=value pairs
directly to the underlying Python estimator. Example:
{cmd:hparams(min_samples_leaf=5 max_features=sqrt)}.

{dlgtab:Options}

{phang}
{opt task(string)} overrides the auto-detected task type. Valid values are
{cmd:classification}, {cmd:regression}, and {cmd:multiclass}.

{phang}
{opt seed(#)} sets the random seed for reproducibility. Default is {cmd:-1}
(no seed).

{phang}
{opt saving(filename)} saves the trained model to a file for use in future
Stata sessions via {cmd:mlearn predict, using()}.

{phang}
{opt trainpct(#)} specifies the proportion of observations used for
training, in the range (0, 1]. The remainder is held out as a test set and
performance metrics are computed on the test set. The default is {cmd:1}
(all observations, no holdout).

{phang}
{opt nolog} suppresses progress messages during training.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Task auto-detection}

{pstd}
When {opt task()} is not specified, {cmd:mlearn train} examines the outcome
variable. If it contains only values 0 and 1, the task is set to
{cmd:classification}. Otherwise the task is set to {cmd:regression}.

{pstd}
{bf:Dataset characteristics}

{pstd}
After training, the following dataset characteristics are stored for use by
other {cmd:mlearn} subcommands:

{p2colset 9 36 38 2}{...}
{p2col:{cmd:_dta[_mlearn_trained]}}training indicator{p_end}
{p2col:{cmd:_dta[_mlearn_method]}}method used{p_end}
{p2col:{cmd:_dta[_mlearn_task]}}task type{p_end}
{p2col:{cmd:_dta[_mlearn_outcome]}}outcome variable name{p_end}
{p2col:{cmd:_dta[_mlearn_features]}}feature variable names{p_end}
{p2col:{cmd:_dta[_mlearn_model_path]}}path to serialized model{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Train a random forest classifier}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn train foreign weight length mpg, method(forest) ntrees(500) seed(42)}{p_end}

{pstd}
{bf:Example 2: Implicit syntax (no "train" subcommand)}

{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}

{pstd}
{bf:Example 3: Regression with train/test split}

{phang2}{cmd:. mlearn price weight length mpg, method(boost) trainpct(0.7) seed(42)}{p_end}

{pstd}
{bf:Example 4: XGBoost with custom hyperparameters}

{phang2}{cmd:. mlearn foreign weight length mpg, method(xgboost) ntrees(200) maxdepth(4) lrate(0.05) seed(42)}{p_end}

{pstd}
{bf:Example 5: Save model to file}

{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42) saving(mymodel.pkl)}{p_end}

{pstd}
{bf:Example 6: Store estimates for later comparison}

{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. estimates store rf}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(xgboost) seed(42)}{p_end}
{phang2}{cmd:. estimates store xgb}{p_end}
{phang2}{cmd:. estimates table rf xgb}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn train} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}
{synopt:{cmd:e(n_train)}}training set size{p_end}
{synopt:{cmd:e(n_test)}}test set size (0 if no split){p_end}
{synopt:{cmd:e(n_features)}}number of feature variables{p_end}
{synopt:{cmd:e(seed)}}random seed used{p_end}
{synopt:{cmd:e(trainpct)}}train/test split ratio{p_end}
{synopt:{cmd:e(accuracy)}}accuracy (classification){p_end}
{synopt:{cmd:e(auc)}}area under ROC curve (binary classification){p_end}
{synopt:{cmd:e(f1)}}F1 score (classification){p_end}
{synopt:{cmd:e(rmse)}}root mean squared error (regression){p_end}
{synopt:{cmd:e(mae)}}mean absolute error (regression){p_end}
{synopt:{cmd:e(r2)}}R-squared (regression){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:mlearn}{p_end}
{synopt:{cmd:e(subcmd)}}{cmd:train}{p_end}
{synopt:{cmd:e(method)}}ML method used{p_end}
{synopt:{cmd:e(task)}}task type (classification, regression, multiclass){p_end}
{synopt:{cmd:e(outcome)}}outcome variable{p_end}
{synopt:{cmd:e(features)}}feature variables{p_end}
{synopt:{cmd:e(model_path)}}path to serialized model{p_end}
{synopt:{cmd:e(hparams)}}hyperparameters used{p_end}
{synopt:{cmd:e(depvar)}}outcome variable name{p_end}
{synopt:{cmd:e(title)}}title string{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}performance metrics vector{p_end}
{synopt:{cmd:e(V)}}variance matrix (zeros for single train){p_end}

{p2col 5 20 24 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}estimation sample{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_predict}, {helpb mlearn_cv},
{helpb mlearn_tune}, {helpb mlearn_importance}

{hline}

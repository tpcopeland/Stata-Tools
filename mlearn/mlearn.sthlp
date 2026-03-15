{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{vieweralsosee "mlearn_predict" "help mlearn_predict"}{...}
{vieweralsosee "mlearn_cv" "help mlearn_cv"}{...}
{vieweralsosee "mlearn_tune" "help mlearn_tune"}{...}
{vieweralsosee "mlearn_importance" "help mlearn_importance"}{...}
{vieweralsosee "mlearn_shap" "help mlearn_shap"}{...}
{vieweralsosee "mlearn_compare" "help mlearn_compare"}{...}
{vieweralsosee "mlearn_setup" "help mlearn_setup"}{...}
{viewerjumpto "Syntax" "mlearn##syntax"}{...}
{viewerjumpto "Description" "mlearn##description"}{...}
{viewerjumpto "Methods" "mlearn##methods"}{...}
{viewerjumpto "Subcommands" "mlearn##subcommands"}{...}
{viewerjumpto "Options" "mlearn##options"}{...}
{viewerjumpto "Examples" "mlearn##examples"}{...}
{viewerjumpto "Stored results" "mlearn##results"}{...}
{viewerjumpto "Author" "mlearn##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:mlearn} {hline 2}}Machine learning for Stata{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Training (default when first token is not a subcommand)

{p 8 17 2}
{cmd:mlearn}
{it:outcome} {it:features}
{ifin}
{cmd:,}
{opt method(string)}
[{it:options}]

{pstd}
Explicit subcommand usage

{p 8 17 2}
{cmd:mlearn train} {it:outcome} {it:features} {ifin}{cmd:,} {opt method(string)} [{it:options}]{p_end}
{p 8 17 2}
{cmd:mlearn predict} {ifin}{cmd:,} [{opt gen:erate(name)} {opt pr:obability} {opt cl:ass} {opt replace} {opt using(filename)}]{p_end}
{p 8 17 2}
{cmd:mlearn cv} {it:outcome} {it:features} {ifin}{cmd:,} {opt method(string)} [{opt folds(#)} {it:options}]{p_end}
{p 8 17 2}
{cmd:mlearn tune} {it:outcome} {it:features} {ifin}{cmd:,} {opt method(string)} {opt grid(string)} [{it:options}]{p_end}
{p 8 17 2}
{cmd:mlearn importance}{cmd:,} [{opt plot} {opt nolog} {opt using(filename)}]{p_end}
{p 8 17 2}
{cmd:mlearn shap}{cmd:,} [{opt plot} {opt nolog} {opt using(filename)} {opt maxs:amples(#)}]{p_end}
{p 8 17 2}
{cmd:mlearn compare} [{it:namelist}]{p_end}
{p 8 17 2}
{cmd:mlearn setup}{cmd:,} {opt ch:eck} | {opt inst:all(string)}{p_end}

{synoptset 28 tabbed}{...}
{synopthdr:Training options}
{synoptline}
{syntab:Required}
{synopt:{opt method(string)}}ML method; see {help mlearn##methods:Methods}{p_end}

{syntab:Hyperparameters}
{synopt:{opt ntr:ees(#)}}number of trees; default {cmd:100}{p_end}
{synopt:{opt maxd:epth(#)}}maximum tree depth; default {cmd:6}{p_end}
{synopt:{opt lr:ate(#)}}learning rate; default {cmd:0.1}{p_end}
{synopt:{opt hparams(string)}}additional key=value hyperparameters{p_end}

{syntab:Options}
{synopt:{opt task(string)}}override auto-detection: {cmd:classification}, {cmd:regression}, {cmd:multiclass}{p_end}
{synopt:{opt seed(#)}}random seed for reproducibility{p_end}
{synopt:{opt sav:ing(filename)}}save model to file for cross-session use{p_end}
{synopt:{opt trainp:ct(#)}}train/test split ratio; default {cmd:1} (no split){p_end}
{synopt:{opt nolog}}suppress training output{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn} provides a unified machine learning interface for Stata, wrapping
Python's scikit-learn, XGBoost, and LightGBM libraries via Stata 16+'s
{cmd:python:} directive. It provides idiomatic Stata syntax with {cmd:ereturn},
{cmd:predict}, and {cmd:estimates store} integration.

{pstd}
When called without a subcommand, {cmd:mlearn} assumes the first token is
an outcome variable and dispatches to {helpb mlearn_train}. The first variable
in the varlist is the outcome; remaining variables are features.

{pstd}
The task type (classification vs. regression) is auto-detected from the
outcome variable: binary 0/1 triggers classification, continuous values
trigger regression. Override this with the {opt task()} option.


{marker methods}{...}
{title:Methods}

{p2colset 5 22 24 2}{...}
{p2col:{opt forest}}Random Forest (scikit-learn){p_end}
{p2col:{opt boost}}Gradient Boosting (scikit-learn){p_end}
{p2col:{opt xgboost}}XGBoost (requires xgboost package){p_end}
{p2col:{opt lightgbm}}LightGBM (requires lightgbm package){p_end}
{p2col:{opt svm}}Support Vector Machine (scikit-learn){p_end}
{p2col:{opt nnet}}Neural Network / MLP (scikit-learn){p_end}
{p2col:{opt elasticnet}}ElasticNet / Lasso (scikit-learn){p_end}
{p2colreset}{...}


{marker subcommands}{...}
{title:Subcommands}

{p2colset 5 28 30 2}{...}
{p2col:{helpb mlearn_train:train}}train a machine learning model{p_end}
{p2col:{helpb mlearn_predict:predict}}generate predictions from a trained model{p_end}
{p2col:{helpb mlearn_cv:cv}}K-fold cross-validation{p_end}
{p2col:{helpb mlearn_tune:tune}}hyperparameter tuning via grid or random search{p_end}
{p2col:{helpb mlearn_importance:importance}}feature importance from a trained model{p_end}
{p2col:{helpb mlearn_shap:shap}}SHAP values for model interpretation{p_end}
{p2col:{helpb mlearn_compare:compare}}compare stored model estimates{p_end}
{p2col:{helpb mlearn_setup:setup}}check and install Python dependencies{p_end}
{p2colreset}{...}


{marker options}{...}
{title:Options}

{pstd}
Options are specific to each subcommand. See the individual help files for
full documentation. The options listed in the synoptset above apply to
{cmd:mlearn train} (and its implicit form).

{dlgtab:Required}

{phang}
{opt method(string)} specifies the machine learning method. See
{help mlearn##methods:Methods} for the list of available methods.

{dlgtab:Hyperparameters}

{phang}
{opt ntrees(#)} specifies the number of trees for tree-based methods
(forest, boost, xgboost, lightgbm). The default is {cmd:100}.

{phang}
{opt maxdepth(#)} specifies the maximum tree depth for tree-based methods.
The default is {cmd:6}.

{phang}
{opt lrate(#)} specifies the learning rate for boosting methods (boost,
xgboost, lightgbm). The default is {cmd:0.1}.

{phang}
{opt hparams(string)} passes additional hyperparameters as key=value pairs
directly to the underlying Python estimator. Example:
{cmd:hparams(min_samples_leaf=5 max_features=sqrt)}.

{dlgtab:Options}

{phang}
{opt task(string)} overrides the auto-detected task type. Specify
{cmd:classification}, {cmd:regression}, or {cmd:multiclass}.

{phang}
{opt seed(#)} sets the random seed for reproducibility.

{phang}
{opt saving(filename)} saves the trained model to a file for use in future
sessions via {cmd:mlearn predict, using()}.

{phang}
{opt trainpct(#)} specifies the proportion of observations used for
training. The remainder is held out as a test set. The default is {cmd:1}
(all observations used for training, no test set).

{phang}
{opt nolog} suppresses progress messages during training.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Check Python dependencies}

{phang2}{cmd:. mlearn setup, check}{p_end}

{pstd}
{bf:Example 2: Train a random forest classifier}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) ntrees(500) seed(42)}{p_end}

{pstd}
{bf:Example 3: Generate predictions}

{phang2}{cmd:. mlearn predict, generate(yhat)}{p_end}

{pstd}
{bf:Example 4: Generate predicted probabilities}

{phang2}{cmd:. mlearn predict, generate(phat) probability}{p_end}

{pstd}
{bf:Example 5: Train with train/test split}

{phang2}{cmd:. mlearn price weight length mpg, method(elasticnet) trainpct(0.7) seed(42)}{p_end}

{pstd}
{bf:Example 6: Cross-validation}

{phang2}{cmd:. mlearn cv foreign weight length mpg, method(forest) folds(10) seed(42)}{p_end}

{pstd}
{bf:Example 7: Store and compare models}

{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. estimates store rf}{p_end}
{phang2}{cmd:. mlearn foreign weight length mpg, method(xgboost) seed(42)}{p_end}
{phang2}{cmd:. estimates store xgb}{p_end}
{phang2}{cmd:. mlearn compare rf xgb}{p_end}

{pstd}
{bf:Example 8: Feature importance and SHAP}

{phang2}{cmd:. mlearn foreign weight length mpg, method(forest) seed(42)}{p_end}
{phang2}{cmd:. mlearn importance, plot}{p_end}
{phang2}{cmd:. mlearn shap, plot}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn} (via {cmd:mlearn train}) stores the following in {cmd:e()}:

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
Online: {helpb mlearn_train}, {helpb mlearn_predict}, {helpb mlearn_cv},
{helpb mlearn_tune}, {helpb mlearn_importance}, {helpb mlearn_shap},
{helpb mlearn_compare}, {helpb mlearn_setup}

{hline}

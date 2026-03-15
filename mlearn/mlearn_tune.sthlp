{smcl}
{* *! version 1.0.0  15mar2026}{...}
{vieweralsosee "mlearn" "help mlearn"}{...}
{vieweralsosee "mlearn_train" "help mlearn_train"}{...}
{vieweralsosee "mlearn_cv" "help mlearn_cv"}{...}
{viewerjumpto "Syntax" "mlearn_tune##syntax"}{...}
{viewerjumpto "Description" "mlearn_tune##description"}{...}
{viewerjumpto "Options" "mlearn_tune##options"}{...}
{viewerjumpto "Remarks" "mlearn_tune##remarks"}{...}
{viewerjumpto "Examples" "mlearn_tune##examples"}{...}
{viewerjumpto "Stored results" "mlearn_tune##results"}{...}
{viewerjumpto "Author" "mlearn_tune##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{cmd:mlearn tune} {hline 2}}Hyperparameter tuning{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:mlearn tune}
{it:outcome} {it:features}
{ifin}
{cmd:,}
{opt method(string)}
{opt grid(string)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt method(string)}}ML method: {cmd:forest}, {cmd:boost}, {cmd:xgboost}, {cmd:lightgbm}, {cmd:svm}, {cmd:nnet}, {cmd:elasticnet}{p_end}
{synopt:{opt grid(string)}}parameter search space (see {help mlearn_tune##grid:grid format}){p_end}

{syntab:Search}
{synopt:{opt search(string)}}search strategy: {cmd:grid} (default) or {cmd:random}{p_end}
{synopt:{opt niter(#)}}number of random search iterations; default {cmd:20}{p_end}
{synopt:{opt folds(#)}}number of CV folds for evaluation; default {cmd:5}{p_end}
{synopt:{opt metric(string)}}optimization metric; see {help mlearn_tune##metrics:metrics}{p_end}

{syntab:Options}
{synopt:{opt task(string)}}override auto-detection: {cmd:classification}, {cmd:regression}, {cmd:multiclass}{p_end}
{synopt:{opt seed(#)}}random seed for reproducibility{p_end}
{synopt:{opt nolog}}suppress output{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:mlearn tune} performs hyperparameter tuning via grid search or random
search with cross-validation. It evaluates each candidate hyperparameter
configuration using K-fold CV and reports the best-performing configuration.

{pstd}
The first variable in the varlist is the outcome; remaining variables are
features. All variables must be numeric with no missing values.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt method(string)} specifies the machine learning method. See
{help mlearn##methods:mlearn Methods} for the full list.

{marker grid}{...}
{phang}
{opt grid(string)} specifies the hyperparameter search space. The format is
a space-separated list of {it:parameter}: {it:values} pairs. Each parameter
name is followed by a colon and one or more candidate values. For example:

{phang2}{cmd:grid("ntrees: 100 500 1000 maxdepth: 3 6 9 lrate: 0.01 0.1")}{p_end}

{dlgtab:Search}

{phang}
{opt search(string)} specifies the search strategy. {cmd:grid} (default)
evaluates all combinations of candidate values. {cmd:random} samples
configurations randomly.

{phang}
{opt niter(#)} specifies the number of random search iterations when
{cmd:search(random)} is used. The default is {cmd:20}. Ignored for grid
search.

{phang}
{opt folds(#)} specifies the number of cross-validation folds used to
evaluate each candidate configuration. The default is {cmd:5}.

{marker metrics}{...}
{phang}
{opt metric(string)} specifies the metric to optimize. For classification,
the default is {cmd:accuracy}; for regression, the default is {cmd:rmse}.
Other valid values include {cmd:auc}, {cmd:f1}, {cmd:mae}, and {cmd:r2}.

{dlgtab:Options}

{phang}
{opt task(string)} overrides auto-detection of the task type.

{phang}
{opt seed(#)} sets the random seed for reproducibility of fold assignments
and random search sampling.

{phang}
{opt nolog} suppresses progress messages and the results summary.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Grid search vs. random search}

{pstd}
Grid search exhaustively evaluates all combinations of candidate values. If
the grid has many parameters and values, this can be slow. Random search
samples a fixed number of configurations and can be more efficient for
large search spaces.

{pstd}
{bf:Using best parameters}

{pstd}
After tuning, use the returned best parameters to train a final model:

{phang2}{cmd:. mlearn tune y x1 x2, method(forest) grid("ntrees: 100 500 maxdepth: 3 6") seed(42)}{p_end}
{phang2}{cmd:. local bp = r(best_params)}{p_end}
{phang2}{cmd:. mlearn y x1 x2, method(forest) hparams(`bp') seed(42)}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Grid search for random forest}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. mlearn tune foreign weight length mpg, method(forest) grid("ntrees: 100 500 1000 maxdepth: 3 6 9") seed(42)}{p_end}

{pstd}
{bf:Example 2: Random search for XGBoost}

{phang2}{cmd:. mlearn tune foreign weight length mpg, method(xgboost) grid("ntrees: 100 500 1000 maxdepth: 3 6 9 lrate: 0.01 0.05 0.1") search(random) niter(10) seed(42)}{p_end}

{pstd}
{bf:Example 3: Optimize AUC with 10-fold CV}

{phang2}{cmd:. mlearn tune foreign weight length mpg, method(forest) grid("ntrees: 100 500 maxdepth: 3 6") metric(auc) folds(10) seed(42)}{p_end}

{pstd}
{bf:Example 4: Regression tuning}

{phang2}{cmd:. mlearn tune price weight length mpg, method(boost) grid("ntrees: 100 500 lrate: 0.01 0.1") seed(42)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:mlearn tune} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(best_score)}}best metric score from CV{p_end}
{synopt:{cmd:r(n_configs)}}number of configurations evaluated{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(best_params)}}best hyperparameter values{p_end}
{synopt:{cmd:r(method)}}ML method used{p_end}
{synopt:{cmd:r(metric)}}optimization metric{p_end}
{synopt:{cmd:r(search)}}search strategy (grid or random){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-15{p_end}


{title:Also see}

{psee}
Online: {helpb mlearn}, {helpb mlearn_train}, {helpb mlearn_cv}

{hline}

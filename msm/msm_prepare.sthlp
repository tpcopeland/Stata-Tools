{smcl}
{* *! version 1.0.0  26apr2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_validate" "help msm_validate"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{viewerjumpto "Syntax" "msm_prepare##syntax"}{...}
{viewerjumpto "Description" "msm_prepare##description"}{...}
{viewerjumpto "Options" "msm_prepare##options"}{...}
{viewerjumpto "What it stores" "msm_prepare##stored_metadata"}{...}
{viewerjumpto "Data requirements" "msm_prepare##data_requirements"}{...}
{viewerjumpto "Examples" "msm_prepare##examples"}{...}
{viewerjumpto "Stored results" "msm_prepare##results"}{...}
{viewerjumpto "Author" "msm_prepare##author"}{...}

{title:Title}

{phang}
{bf:msm_prepare} {hline 2} Data preparation and variable mapping for marginal structural models


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:msm_prepare}
{cmd:,} {opth id(varname)} {opth per:iod(varname)} {opth treat:ment(varname)}
{opth out:come(varname)}
[{it:options}]

{synoptset 35 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}individual identifier{p_end}
{synopt:{opt per:iod(varname)}}time period variable (integer){p_end}
{synopt:{opt treat:ment(varname)}}binary treatment indicator (0/1){p_end}
{synopt:{opt out:come(varname)}}binary outcome indicator (0/1){p_end}

{syntab:Optional}
{synopt:{opt cen:sor(varname)}}binary censoring indicator (0/1){p_end}
{synopt:{opt cov:ariates(varlist)}}time-varying covariates{p_end}
{synopt:{opt bas:eline_covariates(varlist)}}baseline-only covariates{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_prepare} is the entry point for every MSM analysis.  It tells the
package which variables in your dataset play which roles {hline 1} who is the
individual, what marks time, what is the treatment, and what is the outcome
{hline 1} and stores that mapping in the dataset as characteristics
({cmd:_dta[_msm_*]}).  All downstream commands read those stored settings
instead of requiring you to re-specify the same variable names at each step.

{pstd}
Before storing anything, {cmd:msm_prepare} validates the input data:

{phang2}(a) {cmd:period()} must be integer-valued.{p_end}
{phang2}(b) {cmd:treatment()} and {cmd:outcome()} must be binary 0/1.{p_end}
{phang2}(c) {cmd:censor()}, if specified, must also be binary 0/1.{p_end}
{phang2}(d) Each ({cmd:id}, {cmd:period}) combination must appear exactly once
(person-period format).{p_end}
{phang2}(e) Variables listed in {cmd:baseline_covariates()} must be constant
within each individual.{p_end}

{pstd}
Data must be in person-period (long) format with one row per individual per
time period.  All individuals must share the same baseline period, because
{helpb msm_weight} currently requires a common start.

{pstd}
Re-running {cmd:msm_prepare} overwrites the stored variable mapping and clears
all downstream {cmd:_msm_*} analysis artifacts from earlier weighting, fitting,
prediction, and diagnostic runs.  This makes it the correct restart point when
your analysis specification changes.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth id(varname)} specifies the variable that uniquely identifies each
individual in the study (e.g., patient ID, subject number).  Together with
{cmd:period()}, it defines the panel structure.  {cmd:id()} is used by
downstream commands for clustering standard errors and within-person
cumulative weight calculations.

{phang}
{opth per:iod(varname)} specifies the time period variable.  It must be
integer-valued (e.g., visit number, month, year) and defines the time axis for
the analysis.  Fractional or date values are not accepted.

{phang}
{opth treat:ment(varname)} specifies the binary treatment indicator, coded
0 = untreated and 1 = treated.  This is the exposure whose causal effect the
MSM estimates.  The variable can change over time within an individual
(time-varying treatment).

{phang}
{opth out:come(varname)} specifies the binary outcome indicator, coded
0 = no event and 1 = event.  Downstream commands treat the outcome as
terminal: once it occurs, subsequent observations for that individual are
excluded from the estimation sample.

{dlgtab:Optional}

{phang}
{opth cen:sor(varname)} specifies a binary indicator for informative
censoring, coded 0 = uncensored and 1 = censored.  When provided,
{helpb msm_weight} can calculate inverse probability of censoring weights
(IPCW) in addition to treatment weights.  Like the outcome, censoring is
treated as a terminal event.

{phang}
{opth cov:ariates(varlist)} specifies time-varying confounders.  These
variables may change over time within each individual (e.g., lab values,
disease activity, comorbidity status).  They are used as default predictors in
the treatment weight denominator model by {helpb msm_weight} and for covariate
balance assessment by {helpb msm_diagnose}.  All variables must be numeric.

{phang}
{opth bas:eline_covariates(varlist)} specifies covariates that are fixed at
baseline and do not change over time within an individual (e.g., sex, baseline
age, race).  {cmd:msm_prepare} verifies that these variables are truly constant
within person.  Baseline covariates are commonly included in both the weight
numerator and the outcome model.


{marker stored_metadata}{...}
{title:What it stores}

{pstd}
{cmd:msm_prepare} writes the following dataset characteristics, which
downstream commands read automatically:

{phang2}{cmd:_dta[_msm_prepared]} = "1"{p_end}
{phang2}{cmd:_dta[_msm_id]}, {cmd:_dta[_msm_period]}, {cmd:_dta[_msm_treatment]},
{cmd:_dta[_msm_outcome]}, {cmd:_dta[_msm_censor]} = variable names{p_end}
{phang2}{cmd:_dta[_msm_covariates]} = time-varying covariates{p_end}
{phang2}{cmd:_dta[_msm_bl_covariates]} = baseline covariates{p_end}

{pstd}
These characteristics travel with the dataset when you {cmd:save} and
{cmd:use} it, so you can resume an analysis across sessions.


{marker data_requirements}{...}
{title:Data requirements}

{phang2}1. One row per individual per time period.{p_end}
{phang2}2. {cmd:period()} is integer-valued (no gaps expected but
{helpb msm_validate} will check).{p_end}
{phang2}3. {cmd:treatment()} and {cmd:outcome()} are coded 0/1.{p_end}
{phang2}4. {cmd:censor()}, if used, is coded 0/1.{p_end}
{phang2}5. All individuals share a common first period.{p_end}
{phang2}6. {cmd:baseline_covariates()} are constant within person.{p_end}
{phang2}7. All specified variables must be numeric.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Minimal mapping.}  If you have no covariates yet and just want to map the
core variables:{p_end}

{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)}{p_end}

{pstd}
{bf:Full mapping with covariates and censoring.}  This is the typical setup
before an IPTW analysis:{p_end}

{phang2}{cmd:. findfile msm_example.dta}{p_end}
{phang2}{cmd:. use "`r(fn)'", clear}{p_end}
{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker comorbidity)}{p_end}
{phang2}{cmd:    censor(censored) baseline_covariates(age sex)}{p_end}
{phang2}{cmd:. return list}{p_end}

{pstd}
{bf:Restarting after changing covariates.}  Re-running {cmd:msm_prepare} clears
all prior downstream artifacts, so you must re-run {helpb msm_validate} and
{helpb msm_weight} afterward:{p_end}

{phang2}{cmd:. msm_prepare, id(id) period(period) treatment(treatment)}{p_end}
{phang2}{cmd:    outcome(outcome) covariates(biomarker)}{p_end}
{phang2}{cmd:    baseline_covariates(age sex)}{p_end}

{pstd}
{bf:Checking the stored mapping.}  After preparing, run {cmd:msm, status} to
see the current pipeline state:{p_end}

{phang2}{cmd:. msm, status}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:msm_prepare} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total number of observations in the dataset{p_end}
{synopt:{cmd:r(n_ids)}}number of unique individuals{p_end}
{synopt:{cmd:r(n_periods)}}number of distinct periods (max - min + 1){p_end}
{synopt:{cmd:r(n_events)}}number of observations where outcome = 1{p_end}
{synopt:{cmd:r(n_treated)}}number of observations where treatment = 1{p_end}
{synopt:{cmd:r(n_censored)}}number of censored observations (0 if no censor variable){p_end}

{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(id)}}name of the ID variable{p_end}
{synopt:{cmd:r(period)}}name of the period variable{p_end}
{synopt:{cmd:r(treatment)}}name of the treatment variable{p_end}
{synopt:{cmd:r(outcome)}}name of the outcome variable{p_end}
{synopt:{cmd:r(censor)}}name of the censoring variable (empty if not specified){p_end}
{synopt:{cmd:r(covariates)}}time-varying covariates{p_end}
{synopt:{cmd:r(baseline_covariates)}}baseline covariates{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience, Karolinska Institutet
{p_end}

{hline}

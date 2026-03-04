{smcl}
{* *! version 1.0.2  28feb2026}{...}
{viewerjumpto "Syntax" "tte_fit##syntax"}{...}
{viewerjumpto "Description" "tte_fit##description"}{...}
{viewerjumpto "Options" "tte_fit##options"}{...}
{viewerjumpto "Examples" "tte_fit##examples"}{...}
{viewerjumpto "Stored results" "tte_fit##results"}{...}
{viewerjumpto "Technical notes" "tte_fit##technical"}{...}
{viewerjumpto "Author" "tte_fit##author"}{...}

{title:Title}

{phang}
{bf:tte_fit} {hline 2} Outcome model fitting for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_fit}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth outcome_cov(varlist)}}covariates for outcome model{p_end}
{synopt:{opth mod:el(string)}}logistic (default) or cox{p_end}
{synopt:{opth model_var(string)}}treatment variable; default is assigned arm{p_end}
{synopt:{opth trial_period_spec(string)}}trial period: linear, quadratic, cubic, ns(#), none{p_end}
{synopt:{opth fol:lowup_spec(string)}}follow-up: linear, quadratic (default), cubic, ns(#), none{p_end}
{synopt:{opt rob:ust}}robust/sandwich SEs (on by default){p_end}
{synopt:{opth cl:uster(varname)}}cluster variable; default is patient ID{p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_fit} fits the marginal structural model for the target trial
emulation. It supports pooled logistic regression (default) and weighted
Cox proportional hazards.

{pstd}
For pooled logistic regression, the model is fitted via {cmd:glm} with
{cmd:family(binomial) link(logit)} and {cmd:vce(cluster)}. For Cox models,
{cmd:stcox} is used with inverse probability weights and clustered SEs.

{pstd}
Covariates specified in {opt outcome_cov()} should be baseline (trial-entry)
values. If data was expanded with {cmd:tte_expand}, covariates specified in
{cmd:tte_prepare} are automatically frozen at baseline.


{marker examples}{...}
{title:Examples}

{pstd}Pooled logistic with quadratic time{p_end}
{phang2}{cmd:. tte_fit, outcome_cov(age sex comorbidity) model(logistic) nolog}{p_end}

{pstd}Cox model{p_end}
{phang2}{cmd:. tte_fit, outcome_cov(age sex comorbidity) model(cox) nolog}{p_end}

{pstd}Natural spline for follow-up time{p_end}
{phang2}{cmd:. tte_fit, outcome_cov(age sex) followup_spec(ns(3)) nolog}{p_end}


{marker technical}{...}
{title:Technical notes}

{dlgtab:Pooled logistic regression}

{pstd}
The default model is fitted via:

{phang2}{cmd:glm outcome arm followup [time_terms] [covariates] [pw=weight], family(binomial) link(logit) vce(cluster id)}{p_end}

{pstd}
Robust standard errors use Stata's {cmd:vce(cluster)} sandwich estimator,
which applies a G/(G-1) finite-sample correction where G is the number of
clusters. This differs from R's {cmd:sandwich::vcovCL()}, which uses the HC1
correction (N-1)/(N-k). The two produce slightly different SEs but identical
point estimates. The difference is negligible in large samples.

{dlgtab:Cox proportional hazards}

{pstd}
When {cmd:model(cox)} is specified, the data is {cmd:stset} with
follow-up time as the time variable and the outcome as the failure event.
The model is fitted via {cmd:stcox} with {cmd:pweight}s and
{cmd:vce(cluster id)}.

{dlgtab:Natural splines}

{pstd}
When {opt followup_spec(ns(#))} or {opt trial_period_spec(ns(#))} is
specified, spline basis variables are constructed using the Harrell restricted
cubic spline (RCS) formulation with knots placed at equally spaced
quantiles of the time variable. This differs from R's {cmd:splines::ns()},
which places boundary knots at the data range and interior knots at
quantiles. The two formulations span the same function space but use
different basis representations, so individual coefficients are not
directly comparable. Marginal predictions (from {cmd:tte_predict}) are
comparable.

{dlgtab:Covariate handling}

{pstd}
After expansion by {cmd:tte_expand}, all covariates specified in
{cmd:tte_prepare} carry their trial-entry (baseline) values. The outcome
model therefore conditions on L{sub:0} only. Any additional variables
passed via {opt outcome_cov()} that were not registered in {cmd:tte_prepare}
retain their original values; users should ensure these are also
baseline quantities.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_fit} stores results in {cmd:e()} via the underlying {cmd:glm} or
{cmd:stcox} command, plus:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:e(tte_cmd)}}tte_fit{p_end}
{synopt:{cmd:e(tte_model)}}logistic or cox{p_end}
{synopt:{cmd:e(tte_estimand)}}ITT, PP, or AT{p_end}
{synopt:{cmd:e(tte_model_var)}}treatment variable name{p_end}
{synopt:{cmd:e(tte_followup_spec)}}follow-up time specification{p_end}
{synopt:{cmd:e(tte_trial_spec)}}trial period specification{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet

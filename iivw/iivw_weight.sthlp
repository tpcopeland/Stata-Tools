{smcl}
{* *! version 1.0.0  6mar2026}{...}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "[R] logit" "help logit"}{...}
{viewerjumpto "Syntax" "iivw_weight##syntax"}{...}
{viewerjumpto "Description" "iivw_weight##description"}{...}
{viewerjumpto "Options" "iivw_weight##options"}{...}
{viewerjumpto "Weight types" "iivw_weight##wtypes"}{...}
{viewerjumpto "Remarks" "iivw_weight##remarks"}{...}
{viewerjumpto "Examples" "iivw_weight##examples"}{...}
{viewerjumpto "Stored results" "iivw_weight##results"}{...}
{viewerjumpto "Author" "iivw_weight##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:iivw_weight} {hline 2}}Compute inverse intensity and treatment weights{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_weight}
{cmd:,}
{opt id(varname)}
{opt time(varname)}
{opt vis:it_cov(varlist)}
[{it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}subject identifier{p_end}
{synopt:{opt time(varname)}}visit time (continuous, numeric){p_end}
{synopt:{opt vis:it_cov(varlist)}}covariates for visit intensity Cox model{p_end}

{syntab:Treatment (IPTW)}
{synopt:{opt treat(varname)}}binary treatment indicator (0/1){p_end}
{synopt:{opt treat_cov(varlist)}}covariates for treatment logistic model{p_end}

{syntab:Weight specification}
{synopt:{opt wt:ype(string)}}weight type: {cmd:iivw}, {cmd:iptw}, or {cmd:fiptiw}{p_end}
{synopt:{opt stabcov(varlist)}}stabilization covariates for IIW numerator{p_end}

{syntab:Data options}
{synopt:{opt lagvars(varlist)}}time-varying covariates to lag by one visit{p_end}
{synopt:{opt en:try(varname)}}study entry time per subject (default: 0){p_end}

{syntab:Reporting}
{synopt:{opt trunc:ate(# #)}}percentile trimming (e.g., {cmd:truncate(1 99)}){p_end}
{synopt:{opt gen:erate(name)}}prefix for weight variables (default: {cmd:_iivw_}){p_end}
{synopt:{opt replace}}overwrite existing weight variables{p_end}
{synopt:{opt nolog}}suppress model iteration log{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_weight} computes weights to correct for informative visit processes
in longitudinal panel data.  Three types of weights are available:

{phang2}{bf:IIW} (inverse intensity weighting) corrects for outcome-dependent
visit frequency using an Andersen-Gill recurrent-event Cox model.{p_end}

{phang2}{bf:IPTW} (inverse probability of treatment weighting) corrects for
confounding by indication using a cross-sectional logistic model.{p_end}

{phang2}{bf:FIPTIW} (fully inverse probability of treatment and intensity
weighting) is the product IIW x IPTW, correcting for both sources of bias.{p_end}

{pstd}
The weight type is auto-detected: if {opt treat()} is specified, FIPTIW is
computed; otherwise, IIW only.  Override with {opt wtype()}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the subject identifier.  Data must be in long
panel format with multiple rows per subject.

{phang}
{opt time(varname)} specifies the visit time in continuous units (e.g., months
since baseline).  Must be numeric and uniquely identify visits within subjects.

{phang}
{opt visit_cov(varlist)} specifies covariates for the visit intensity
Andersen-Gill Cox model.  These should include factors that predict visit
frequency (e.g., disease severity, recent relapses).

{dlgtab:Treatment (IPTW)}

{phang}
{opt treat(varname)} specifies a binary (0/1) time-invariant treatment
indicator.  Required for IPTW or FIPTIW weights.

{phang}
{opt treat_cov(varlist)} specifies covariates for the treatment propensity
score model.  If omitted, {opt visit_cov()} is used as fallback.

{dlgtab:Weight specification}

{phang}
{opt wtype(string)} overrides automatic weight type detection.  Options are
{cmd:iivw}, {cmd:iptw}, or {cmd:fiptiw}.

{phang}
{opt stabcov(varlist)} specifies covariates for the IIW stabilization
numerator model.  When specified, a second Cox model is fit with only these
covariates, and the IIW weight becomes exp(xb_stab - xb_full).

{dlgtab:Data options}

{phang}
{opt lagvars(varlist)} creates lagged versions (lag-1) of the specified
time-varying covariates within each subject.  Lagged variables are named
{it:varname}_lag1 and are automatically included in the visit intensity model.

{phang}
{opt entry(varname)} specifies a subject-specific study entry time.  The
default is 0 for all subjects.  This affects the start time for the first
visit's counting process interval.

{dlgtab:Reporting}

{phang}
{opt truncate(# #)} truncates weights at the specified percentiles.  For
example, {cmd:truncate(1 99)} trims weights below the 1st and above the 99th
percentile to those boundary values.

{phang}
{opt generate(name)} specifies a prefix for generated weight variables.
Default is {cmd:_iivw_}.  Variables created include {it:prefix}iw,
{it:prefix}tw, and {it:prefix}weight.

{phang}
{opt replace} allows overwriting existing weight variables.

{phang}
{opt nolog} suppresses iteration logs from the Cox and logistic models.


{marker wtypes}{...}
{title:Weight types}

{pstd}
{bf:IIW (inverse intensity weighting)}

{pstd}
Visit intensity is modeled as an Andersen-Gill counting process where each
visit is a recurrent event.  The Cox model estimates the conditional hazard of
visiting given covariates.  The IIW weight for each observation is exp(-xb),
where xb is the linear predictor from the Cox model.  First observations per
subject receive weight 1.

{pstd}
{bf:IPTW (inverse probability of treatment weighting)}

{pstd}
A logistic regression estimates the propensity score P(treatment | covariates).
IPTW weights are always stabilized using the marginal treatment prevalence as
the numerator: P(treatment)/P(treatment | covariates) for treated
and (1-P(treatment))/(1-P(treatment | covariates)) for untreated.

{pstd}
{bf:FIPTIW}

{pstd}
The final weight is simply IIW x IPTW, applied to each observation.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Data requirements}

{pstd}
Data must be in long panel format with one row per subject-visit.  Each subject
must have at least 2 visits.  The {opt treat()} variable must be binary and
time-invariant within subjects.

{pstd}
{bf:Truncation}

{pstd}
Extreme weights can destabilize estimates.  The {opt truncate()} option
winsorizes weights at the specified percentiles.  A common choice is
{cmd:truncate(1 99)}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: IIW only}

{phang2}{cmd:. use relapses.dta, clear}{p_end}
{phang2}{cmd:. sort id edss_date}{p_end}
{phang2}{cmd:. gen double days = edss_date - dx_date}{p_end}
{phang2}{cmd:. gen byte relapse = !missing(relapse_date)}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) nolog}{p_end}
{phang2}{cmd:. summarize _iivw_weight, detail}{p_end}

{pstd}
{bf:Example 2: FIPTIW with truncation}

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) treat(treated) treat_cov(age sex edss_bl) truncate(1 99) nolog}{p_end}

{pstd}
{bf:Example 3: With lagged covariates}

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) lagvars(edss relapse) nolog}{p_end}

{pstd}
{bf:Example 4: Custom variable prefix}

{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss) generate(w_) replace nolog}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_weight} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_ids)}}number of subjects{p_end}
{synopt:{cmd:r(mean_weight)}}mean weight{p_end}
{synopt:{cmd:r(sd_weight)}}standard deviation of weights{p_end}
{synopt:{cmd:r(min_weight)}}minimum weight{p_end}
{synopt:{cmd:r(max_weight)}}maximum weight{p_end}
{synopt:{cmd:r(p1_weight)}}1st percentile weight{p_end}
{synopt:{cmd:r(p99_weight)}}99th percentile weight{p_end}
{synopt:{cmd:r(ess)}}effective sample size{p_end}
{synopt:{cmd:r(n_truncated)}}number of truncated observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(weighttype)}}weight type (iivw, iptw, or fiptiw){p_end}
{synopt:{cmd:r(weight_var)}}name of final weight variable{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-06{p_end}


{title:Also see}

{psee}
Online:  {helpb iivw}, {helpb iivw_fit}, {helpb stcox}, {helpb logit}

{hline}

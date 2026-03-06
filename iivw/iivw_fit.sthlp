{smcl}
{* *! version 1.0.0  5mar2026}{...}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "[XT] xtgee" "help xtgee"}{...}
{vieweralsosee "[ME] mixed" "help mixed"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{viewerjumpto "Syntax" "iivw_fit##syntax"}{...}
{viewerjumpto "Description" "iivw_fit##description"}{...}
{viewerjumpto "Options" "iivw_fit##options"}{...}
{viewerjumpto "Remarks" "iivw_fit##remarks"}{...}
{viewerjumpto "Examples" "iivw_fit##examples"}{...}
{viewerjumpto "Stored results" "iivw_fit##results"}{...}
{viewerjumpto "Author" "iivw_fit##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:iivw_fit} {hline 2}}Fit weighted outcome model for IIW analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_fit}
{depvar}
{indepvars}
{ifin}
[{cmd:,} {it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Model}
{synopt:{opt mod:el(string)}}estimation method: {cmd:gee} (default) or {cmd:mixed}{p_end}
{synopt:{opt fam:ily(string)}}GEE family (default: {cmd:gaussian}){p_end}
{synopt:{opt lin:k(string)}}GEE link function (default: canonical){p_end}
{synopt:{opt timespec(string)}}time specification: {cmd:linear} (default), {cmd:quadratic}, {cmd:cubic}, {cmd:ns(#)}, {cmd:none}{p_end}

{syntab:Standard errors}
{synopt:{opt cl:uster(varname)}}clustering variable (default: id from metadata){p_end}
{synopt:{opt boot:strap(#)}}bootstrap replicates (default: 0 = sandwich SE){p_end}

{syntab:Reporting}
{synopt:{opt l:evel(#)}}confidence level (default: 95){p_end}
{synopt:{opt nolog}}suppress iteration log{p_end}
{synopt:{opt geeopts(string)}}additional options passed to {cmd:glm}{p_end}
{synopt:{opt mixedopts(string)}}additional options passed to {cmd:mixed}{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_fit} fits a weighted outcome model using weights computed by
{helpb iivw_weight}.  It supports GEE-equivalent estimation via
{cmd:glm} with clustered standard errors, and mixed-effects models via {cmd:mixed}.

{pstd}
For GEE models, {cmd:glm} with {cmd:vce(cluster)} is used, which is equivalent
to GEE with independence working correlation and robust standard errors.  This
is required by IIW theory (Buzkova & Lumley 2007).

{pstd}
The command automatically retrieves metadata stored by {cmd:iivw_weight}
(panel ID, weight variable, weight type) from dataset characteristics.


{marker options}{...}
{title:Options}

{dlgtab:Model}

{phang}
{opt model(string)} specifies the estimation method.  {cmd:gee} (the default)
fits a GLM with clustered robust SEs via {cmd:glm}, equivalent to independence
working correlation GEE.  {cmd:mixed} fits a mixed-effects model via {cmd:mixed}
(requires Stata 17+).

{phang}
{opt family(string)} specifies the GEE family distribution.  Default is
{cmd:gaussian}.  Other options include {cmd:binomial}, {cmd:poisson}, etc.
Only used when {cmd:model(gee)} is specified.

{phang}
{opt link(string)} specifies the GEE link function.  If omitted, the canonical
link for the specified family is used.

{phang}
{opt timespec(string)} specifies how time enters the outcome model.
{cmd:linear} (default) includes the time variable linearly.
{cmd:quadratic} adds time and time-squared.
{cmd:cubic} adds time, time-squared, and time-cubed.
{cmd:ns(#)} uses a natural cubic spline with # degrees of freedom.
{cmd:none} excludes time from the model.

{dlgtab:Standard errors}

{phang}
{opt cluster(varname)} specifies the clustering variable for sandwich standard
errors.  Default is the panel ID variable from {cmd:iivw_weight} metadata.

{phang}
{opt bootstrap(#)} specifies the number of bootstrap replicates.  When
{cmd:bootstrap(0)} (the default), sandwich standard errors are used.  When
positive, the {cmd:bootstrap} prefix is applied with clustering at the
subject level.

{dlgtab:Reporting}

{phang}
{opt level(#)} specifies the confidence level for confidence intervals.
Default is 95.

{phang}
{opt nolog} suppresses the iteration log.

{phang}
{opt geeopts(string)} passes additional options to {cmd:glm}.

{phang}
{opt mixedopts(string)} passes additional options to {cmd:mixed}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Independence working correlation}

{pstd}
The GEE model uses {cmd:glm} with {cmd:vce(cluster)}, which is mathematically
equivalent to GEE with independence working correlation and robust standard
errors.  This structure is required by IIW theory.

{pstd}
{bf:Prerequisites}

{pstd}
{cmd:iivw_weight} must be run before {cmd:iivw_fit}.  The weight variable and
metadata are read from dataset characteristics set by {cmd:iivw_weight}.

{pstd}
{bf:Table export with collect and regtab}

{pstd}
{cmd:iivw_fit} is an {cmd:eclass} command and works with Stata's {cmd:collect}
framework.  Use the {cmd:collect:} prefix to accumulate results across models,
then export with {helpb regtab} (from {cmd:tabtools}).

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: iivw_fit score drug age severity_bl, model(gee)}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet(IIW) coef(Coef.) title(IIW Model)}{p_end}

{pstd}
To compare multiple weighting strategies side by side:

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(t) visit_cov(x1) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. collect: iivw_fit y treated age, model(gee) nolog}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(t) visit_cov(x1) treat(treated) treat_cov(age) truncate(1 99) replace nolog}{p_end}
{phang2}{cmd:. collect: iivw_fit y treated age, model(gee) nolog}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet(Compare) models(IIW \ FIPTIW) coef(Coef.) stats(n)}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic GEE model}

{phang2}{cmd:. iivw_fit edss treated edss_bl, model(gee) timespec(linear)}{p_end}

{pstd}
{bf:Example 2: Quadratic time specification}

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(quadratic)}{p_end}

{pstd}
{bf:Example 3: Natural spline for time}

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(ns(3))}{p_end}

{pstd}
{bf:Example 4: Bootstrap standard errors}

{phang2}{cmd:. iivw_fit edss treated edss_bl, bootstrap(500) nolog}{p_end}

{pstd}
{bf:Example 5: Binomial family for binary outcome}

{phang2}{cmd:. iivw_fit relapse treated edss_bl, family(binomial) link(logit)}{p_end}

{pstd}
{bf:Example 6: Export to Excel with regtab}

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: iivw_fit edss treated edss_bl, model(gee) nolog}{p_end}
{phang2}{cmd:. regtab, xlsx(iivw_results.xlsx) sheet(Results) coef(Coef.) title(IIW Analysis) stats(n)}{p_end}

{pstd}
{bf:Example 7: Compare IIW vs FIPTIW in one table}

{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) truncate(1 99) nolog}{p_end}
{phang2}{cmd:. collect: iivw_fit edss treated edss_bl, model(gee) nolog}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss relapse) treat(treated) treat_cov(age sex edss_bl) truncate(1 99) replace nolog}{p_end}
{phang2}{cmd:. collect: iivw_fit edss treated edss_bl, model(gee) nolog}{p_end}
{phang2}{cmd:. regtab, xlsx(iivw_results.xlsx) sheet(Comparison) models(IIW \ FIPTIW) coef(Coef.) title(IIW vs FIPTIW) stats(n) noint}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_fit} stores the results from the underlying {cmd:glm} or
{cmd:mixed} command in {cmd:e()}, plus the following:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:e(iivw_cmd)}}{cmd:iivw_fit}{p_end}
{synopt:{cmd:e(iivw_model)}}estimation method (gee or mixed){p_end}
{synopt:{cmd:e(iivw_weighttype)}}weight type (iivw, iptw, or fiptiw){p_end}
{synopt:{cmd:e(iivw_timespec)}}time specification used{p_end}
{synopt:{cmd:e(iivw_weight_var)}}weight variable name{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-05{p_end}


{title:Also see}

{psee}
Online:  {helpb iivw}, {helpb iivw_weight}, {helpb regtab}, {helpb glm}, {helpb xtgee}, {helpb mixed}

{hline}

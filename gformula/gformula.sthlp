{smcl}
{* *! version 1.1.1  28feb2026}{...}
{viewerjumpto "Syntax" "gformula##syntax"}{...}
{viewerjumpto "Description" "gformula##description"}{...}
{viewerjumpto "Options" "gformula##options"}{...}
{viewerjumpto "Examples" "gformula##examples"}{...}
{viewerjumpto "Stored results" "gformula##results"}{...}
{viewerjumpto "References" "gformula##references"}{...}
{viewerjumpto "Author" "gformula##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:gformula} {hline 2}}G-computation formula via Monte Carlo simulation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
{bf:Time-varying confounding:}

{p 8 17 2}
{cmd:gformula}
{varlist}
{ifin}
{cmd:,}
{opt out:come(varname)}
{opt com:mands(string)}
{opt eq:uations(string)}
{opt idvar(varname)}
{opt tvar(varname)}
{opt var:yingcovariates(varlist)}
{opt intvars(varlist)}
{opt interventions(string)}
[{it:options}]

{pstd}
{bf:Causal mediation:}

{p 8 17 2}
{cmd:gformula}
{varlist}
{ifin}
{cmd:,}
{opt out:come(varname)}
{opt com:mands(string)}
{opt eq:uations(string)}
{opt mediation}
{opt ex:posure(varlist)}
{opt mediator(varlist)}
{opt base_confs(varlist)}
{it:effect_type}
[{it:options}]

{pstd}
where {it:effect_type} is one of: {opt obe}, {opt oce}, {opt linexp}, {opt specific},
or {opt baseline(string)}.


{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required (both modes)}
{synopt:{opt out:come(varname)}}outcome variable{p_end}
{synopt:{opt com:mands(string)}}model type for each variable, e.g., {cmd:commands(m: logit, y: logit)}{p_end}
{synopt:{opt eq:uations(string)}}prediction equations, e.g., {cmd:equations(m: x c, y: m x c)}{p_end}

{syntab:Required (time-varying)}
{synopt:{opt idvar(varname)}}subject identifier variable{p_end}
{synopt:{opt tvar(varname)}}time variable{p_end}
{synopt:{opt var:yingcovariates(varlist)}}time-varying covariates{p_end}
{synopt:{opt intvars(varlist)}}intervention variables{p_end}
{synopt:{opt interventions(string)}}intervention specifications{p_end}

{syntab:Required (mediation)}
{synopt:{opt mediation}}mediation analysis mode{p_end}
{synopt:{opt ex:posure(varlist)}}exposure variable(s){p_end}
{synopt:{opt mediator(varlist)}}mediator variable(s){p_end}
{synopt:{opt base_confs(varlist)}}baseline confounders{p_end}

{syntab:Effect type (mediation)}
{synopt:{opt obe}}observed baseline exposure (binary exposure){p_end}
{synopt:{opt oce}}observed conditional exposure (categorical exposure){p_end}
{synopt:{opt linexp}}linear exposure effect{p_end}
{synopt:{opt specific}}specific exposure values{p_end}
{synopt:{opt baseline(string)}}baseline exposure level(s){p_end}
{synopt:{opt alternative(string)}}alternative exposure level(s){p_end}

{syntab:Time-varying options}
{synopt:{opt eofu}}outcome is end-of-follow-up{p_end}
{synopt:{opt pooled}}pooled logistic regression across visits{p_end}
{synopt:{opt monotreat}}monotone treatment assumption{p_end}
{synopt:{opt dynamic}}dynamic treatment regime{p_end}
{synopt:{opt death(varname)}}competing death variable{p_end}
{synopt:{opt msm(string)}}marginal structural model specification{p_end}
{synopt:{opt fix:edcovariates(varlist)}}time-invariant covariates{p_end}
{synopt:{opt lag:gedvars(varlist)}}variables with lagged effects{p_end}
{synopt:{opt lagrules(string)}}lag specification rules{p_end}
{synopt:{opt derived(varlist)}}deterministically derived variables{p_end}
{synopt:{opt derrules(string)}}derivation rules{p_end}

{syntab:Mediation options}
{synopt:{opt control(string)}}controlled direct effect level(s){p_end}
{synopt:{opt post_confs(varlist)}}post-treatment confounders{p_end}
{synopt:{opt boceam}}BOCE-AM estimation{p_end}
{synopt:{opt logOR}}report log odds ratio{p_end}
{synopt:{opt logRR}}report log risk ratio{p_end}

{syntab:Imputation}
{synopt:{opt impute(varlist)}}variables to impute missing values{p_end}
{synopt:{opt imp_eq(string)}}imputation equations{p_end}
{synopt:{opt imp_cmd(string)}}imputation model commands{p_end}
{synopt:{opt imp_cycles(#)}}number of imputation cycles; default is {cmd:10}{p_end}

{syntab:Simulation}
{synopt:{opt sim:ulations(#)}}Monte Carlo sample size; default is sample size{p_end}
{synopt:{opt sam:ples(#)}}number of bootstrap replications; default is {cmd:1000}{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt minsim}}use expected values instead of random draws{p_end}
{synopt:{opt moreMC}}allow MC sample size > N{p_end}

{syntab:Output}
{synopt:{opt all}}report all four CI types (normal, percentile, BC, BCa){p_end}
{synopt:{opt graph}}graph potential outcomes{p_end}
{synopt:{opt saving(filename)}}save bootstrap dataset{p_end}
{synopt:{opt replace}}overwrite existing saved file{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:gformula} implements Robins' parametric g-computation formula (Robins 1986)
using Monte Carlo simulation. It operates in two modes:

{pstd}
{bf:Time-varying confounding.} Estimates causal effects of time-varying
exposures on outcomes in the presence of time-varying confounders affected
by prior exposure. The method uses parametric models to simulate potential
outcomes under user-specified interventions and compares them to the
observational regime.

{pstd}
{bf:Causal mediation.} Estimates total causal effects (TCE), natural direct
effects (NDE), natural indirect effects (NIE), proportion mediated (PM), and
controlled direct effects (CDE) in the presence of exposure-induced
mediator-outcome confounding.

{pstd}
Bootstrap confidence intervals are obtained using Stata's {cmd:bootstrap}
prefix. Supported model types are {cmd:logit}, {cmd:regress}, {cmd:mlogit},
and {cmd:ologit}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt outcome(varname)} specifies the outcome variable.

{phang}
{opt commands(string)} specifies the model command for each simulated variable.
Syntax: {cmd:commands(}{it:var1}{cmd:: }{it:cmd1}{cmd:, }{it:var2}{cmd:: }{it:cmd2}{cmd:)}.
Supported commands: {cmd:logit}, {cmd:regress}, {cmd:mlogit}, {cmd:ologit}.

{phang}
{opt equations(string)} specifies the prediction equation for each simulated
variable. Syntax: {cmd:equations(}{it:var1}{cmd:: }{it:rhs1}{cmd:, }{it:var2}{cmd:: }{it:rhs2}{cmd:)}.

{dlgtab:Mediation effect types}

{phang}
{opt obe} specifies observed baseline exposure for binary exposure variables.
This computes effects comparing all-exposed vs. all-unexposed.

{phang}
{opt oce} specifies observed conditional exposure for categorical exposure
variables with more than two levels. If {opt baseline()} is not specified,
the minimum exposure level is used as the baseline.

{phang}
{opt linexp} specifies a linear exposure effect model.

{phang}
{opt specific} specifies user-defined exposure comparisons via
{opt baseline()} and {opt alternative()}.

{dlgtab:Simulation}

{phang}
{opt simulations(#)} sets the Monte Carlo sample size. Default is the
dataset sample size. If larger than the sample size, {opt moreMC} must
also be specified.

{phang}
{opt samples(#)} sets the number of bootstrap replications for inference.
Default is {cmd:1000}.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt minsim} uses expected values (predicted probabilities) instead of
random draws for binary outcomes. Reduces MC variability but may introduce
bias.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Mediation analysis with binary exposure (OBE)}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. set obs 500}{p_end}
{phang2}{cmd:. gen double y = rbinomial(1, 0.3)}{p_end}
{phang2}{cmd:. gen double m = rbinomial(1, 0.5)}{p_end}
{phang2}{cmd:. gen double x = rbinomial(1, 0.5)}{p_end}
{phang2}{cmd:. gen double c = rnormal()}{p_end}
{phang2}{cmd:. gformula y m x c, outcome(y) mediation obe ///}{p_end}
{phang2}{cmd:      exposure(x) mediator(m) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) ///}{p_end}
{phang2}{cmd:      equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      base_confs(c) sim(500) samples(200) seed(1)}{p_end}

{pstd}
{bf:Example 2: Mediation with categorical exposure (OCE)}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 54321}{p_end}
{phang2}{cmd:. set obs 500}{p_end}
{phang2}{cmd:. gen double y = rbinomial(1, 0.3)}{p_end}
{phang2}{cmd:. gen double m = rbinomial(1, 0.5)}{p_end}
{phang2}{cmd:. gen double x = floor(runiform() * 3)}{p_end}
{phang2}{cmd:. gen double c = rnormal()}{p_end}
{phang2}{cmd:. gformula y m x c, outcome(y) mediation oce ///}{p_end}
{phang2}{cmd:      exposure(x) mediator(m) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) ///}{p_end}
{phang2}{cmd:      equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      base_confs(c) sim(200) samples(100) seed(1)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:gformula} stores the following in {cmd:e()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of subjects{p_end}
{synopt:{cmd:e(MC_sims)}}Monte Carlo simulation size{p_end}
{synopt:{cmd:e(samples)}}number of bootstrap replications{p_end}

{pstd}
{bf:Matrices:}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector with named columns{p_end}
{synopt:{cmd:e(V)}}diagonal variance matrix (SE{c 178} on diagonal){p_end}
{synopt:{cmd:e(se)}}standard error vector{p_end}
{synopt:{cmd:e(ci_normal)}}normal-based confidence intervals{p_end}
{synopt:{cmd:e(ci_percentile)}}percentile confidence intervals (with {cmd:all}){p_end}
{synopt:{cmd:e(ci_bc)}}bias-corrected confidence intervals (with {cmd:all}){p_end}
{synopt:{cmd:e(ci_bca)}}bias-corrected accelerated confidence intervals (with {cmd:all}){p_end}

{pstd}
{bf:Macros:}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:gformula}{p_end}
{synopt:{cmd:e(analysis_type)}}{cmd:mediation} or {cmd:time_varying}{p_end}
{synopt:{cmd:e(outcome)}}outcome variable name{p_end}
{synopt:{cmd:e(exposure)}}exposure variable(s) (mediation){p_end}
{synopt:{cmd:e(mediator)}}mediator variable(s) (mediation){p_end}
{synopt:{cmd:e(mediation_type)}}effect type: {cmd:obe}, {cmd:oce}, {cmd:linexp}, or {cmd:specific}{p_end}
{synopt:{cmd:e(scale)}}scale: {cmd:RD}, {cmd:logOR}, or {cmd:logRR}{p_end}
{synopt:{cmd:e(msm)}}MSM specification (time-varying with MSM){p_end}

{pstd}
{bf:Convenience scalars} (mediation without {cmd:oce}):

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:e(tce)}}total causal effect{p_end}
{synopt:{cmd:e(nde)}}natural direct effect{p_end}
{synopt:{cmd:e(nie)}}natural indirect effect{p_end}
{synopt:{cmd:e(pm)}}proportion mediated{p_end}
{synopt:{cmd:e(cde)}}controlled direct effect (with {cmd:control()}){p_end}
{synopt:{cmd:e(se_tce)}}SE of total causal effect{p_end}
{synopt:{cmd:e(se_nde)}}SE of natural direct effect{p_end}
{synopt:{cmd:e(se_nie)}}SE of natural indirect effect{p_end}
{synopt:{cmd:e(se_pm)}}SE of proportion mediated{p_end}
{synopt:{cmd:e(se_cde)}}SE of controlled direct effect{p_end}

{pstd}
{bf:Convenience scalars} (mediation with {cmd:oce}, {it:j}=1,...,{it:K}-1):

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:e(tce_}{it:j}{cmd:)}}TCE for level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(nde_}{it:j}{cmd:)}}NDE for level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(nie_}{it:j}{cmd:)}}NIE for level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(pm_}{it:j}{cmd:)}}PM for level {it:j} vs. baseline{p_end}
{synopt:{cmd:e(cde_}{it:j}{cmd:)}}CDE for level {it:j} vs. baseline{p_end}

{pstd}
{bf:Time-varying mode:}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:e(obs_data)}}observed outcome in the data{p_end}


{marker references}{...}
{title:References}

{phang}
Robins JM (1986). A new approach to causal inference in mortality studies with
a sustained exposure period{it:. Mathematical Modelling} 7:1393-1512.

{phang}
Daniel RM, De Stavola BL, Cousens SN (2011). gformula: Estimating causal
effects in the presence of time-varying confounding or mediation using the
g-computation formula{it:. The Stata Journal} 11(4):479-517.


{marker author}{...}
{title:Author}

{pstd}Original author: Rhian Daniel, London School of Hygiene and Tropical Medicine{p_end}
{pstd}Fork maintainer: Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.1.0, 2026-02-27{p_end}

{pstd}
This is a maintained fork of SSC {cmd:gformula} v1.16 beta with bug fixes
and modernization. See the README for a full changelog.


{title:Also see}

{psee}
Online: {helpb bootstrap}, {helpb logit}, {helpb regress}, {helpb mlogit}

{hline}

{smcl}
{* *! version 1.1.0  15mar2026}{...}
{viewerjumpto "Syntax" "tte_prepare##syntax"}{...}
{viewerjumpto "Description" "tte_prepare##description"}{...}
{viewerjumpto "Options" "tte_prepare##options"}{...}
{viewerjumpto "Examples" "tte_prepare##examples"}{...}
{viewerjumpto "Stored results" "tte_prepare##results"}{...}
{viewerjumpto "Technical notes" "tte_prepare##technical"}{...}
{viewerjumpto "Author" "tte_prepare##author"}{...}

{title:Title}

{phang}
{bf:tte_prepare} {hline 2} Data preparation and variable mapping for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_prepare}
{cmd:,} {opth id(varname)} {opth per:iod(varname)} {opth treat:ment(varname)}
{opth out:come(varname)} {opth elig:ible(varname)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth id(varname)}}patient identifier{p_end}
{synopt:{opth per:iod(varname)}}time period variable (integer){p_end}
{synopt:{opth treat:ment(varname)}}binary treatment indicator (0/1){p_end}
{synopt:{opth out:come(varname)}}binary outcome indicator (0/1){p_end}
{synopt:{opth elig:ible(varname)}}binary eligibility indicator (0/1){p_end}

{syntab:Optional}
{synopt:{opth cen:sor(varname)}}binary censoring indicator (0/1){p_end}
{synopt:{opth cov:ariates(varlist)}}time-varying covariates{p_end}
{synopt:{opth bas:eline_covariates(varlist)}}baseline-only covariates{p_end}
{synopt:{opth est:imand(string)}}ITT, PP, or AT; default is {cmd:PP}{p_end}
{synopt:{opth gen:erate(string)}}variable prefix; default is {cmd:_tte_}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_prepare} is the entry point for the target trial emulation pipeline.
It validates the input data structure, maps user variable names to internal
names, and stores metadata as dataset characteristics for downstream commands.

{pstd}
Data must be in person-period (long) format with one row per individual per
time period. The command checks that required variables exist, are correctly
typed (binary 0/1 for treatment/outcome/eligible), and that the data has
no duplicate (id, period) combinations.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth id(varname)} specifies the patient/individual identifier variable.

{phang}
{opth period(varname)} specifies the time period variable. Must be integer-valued.

{phang}
{opth treatment(varname)} specifies the binary treatment indicator (0/1).

{phang}
{opth outcome(varname)} specifies the binary outcome indicator (0/1).

{phang}
{opth eligible(varname)} specifies the binary eligibility indicator (0/1).

{dlgtab:Optional}

{phang}
{opth censor(varname)} specifies a binary censoring indicator for informative
censoring weights.

{phang}
{opth covariates(varlist)} specifies time-varying covariates. During expansion
by {cmd:tte_expand}, these are frozen at their trial-entry (baseline) values
per the MSM framework (Hernán & Robins, 2020). IP weights computed by
{cmd:tte_weight} handle time-varying confounding.

{phang}
{opth baseline_covariates(varlist)} specifies baseline-only covariates.

{phang}
{opth estimand(string)} specifies the causal estimand: {cmd:ITT}
(intention-to-treat), {cmd:PP} (per-protocol, the default), or {cmd:AT}
(as-treated).

{phang}
{opth generate(string)} specifies the prefix for internally created variables.
Default is {cmd:_tte_}.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. use tte_example, clear}{p_end}

{pstd}Per-protocol analysis{p_end}
{phang2}{cmd:. tte_prepare, id(patid) period(period) treatment(treatment) outcome(outcome) eligible(eligible) covariates(age sex comorbidity biomarker) estimand(PP)}{p_end}

{pstd}ITT analysis with censoring{p_end}
{phang2}{cmd:. tte_prepare, id(patid) period(period) treatment(treatment) outcome(outcome) eligible(eligible) censor(censored) estimand(ITT)}{p_end}


{marker technical}{...}
{title:Technical notes}

{dlgtab:Covariate classification}

{pstd}
Variables listed in {opt covariates()} may be time-varying in the input
data (different values across periods for the same individual), but they
are frozen at trial-entry values during expansion by {cmd:tte_expand}.
The label "time-varying" refers to the input data structure, not to how
the variables appear in the expanded analysis dataset.

{pstd}
Variables listed in {opt baseline_covariates()} are expected to be
constant within each individual. They are also frozen during expansion
for consistency, but this has no practical effect if they are already
time-invariant.

{dlgtab:Metadata storage}

{pstd}
All variable mappings and settings are stored as dataset characteristics
({cmd:char _dta[_tte_*]}). Downstream commands ({cmd:tte_expand},
{cmd:tte_weight}, {cmd:tte_fit}) read these characteristics automatically.
This means the data in memory must not be replaced between pipeline steps
unless the characteristics are preserved.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_prepare} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_ids)}}number of unique individuals{p_end}
{synopt:{cmd:r(n_periods)}}number of distinct periods{p_end}
{synopt:{cmd:r(n_eligible)}}number of eligible observations{p_end}
{synopt:{cmd:r(n_events)}}number of outcome events{p_end}
{synopt:{cmd:r(n_censored)}}number of censored observations{p_end}
{synopt:{cmd:r(n_treated)}}number of treated observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(estimand)}}estimand (ITT, PP, or AT){p_end}
{synopt:{cmd:r(id)}}ID variable name{p_end}
{synopt:{cmd:r(period)}}period variable name{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(outcome)}}outcome variable name{p_end}
{synopt:{cmd:r(eligible)}}eligible variable name{p_end}
{synopt:{cmd:r(covariates)}}covariate variable names{p_end}

{pstd}
Additionally, metadata is stored as dataset characteristics ({cmd:char _dta[]})
for automatic detection by downstream commands.


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

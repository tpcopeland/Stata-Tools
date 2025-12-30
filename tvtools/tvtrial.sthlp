{smcl}
{* *! version 1.0.0  29dec2025}{...}
{vieweralsosee "[ST] stcox" "help stcox"}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{vieweralsosee "tvweight" "help tvweight"}{...}
{viewerjumpto "Syntax" "tvtrial##syntax"}{...}
{viewerjumpto "Description" "tvtrial##description"}{...}
{viewerjumpto "Options" "tvtrial##options"}{...}
{viewerjumpto "Examples" "tvtrial##examples"}{...}
{viewerjumpto "Stored results" "tvtrial##results"}{...}
{viewerjumpto "Methods" "tvtrial##methods"}{...}
{viewerjumpto "Author" "tvtrial##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tvtrial} {hline 2}}Target trial emulation for observational data{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:tvtrial}{cmd:,}
{opt id(varname)}
{opt entry(varname)}
{opt exit(varname)}
{opt treatstart(varname)}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier{p_end}
{synopt:{opt entry(varname)}}study entry date{p_end}
{synopt:{opt exit(varname)}}study exit date{p_end}
{synopt:{opt treatstart(varname)}}treatment initiation date{p_end}

{syntab:Eligibility}
{synopt:{opt eligstart(varname)}}eligibility start date (default: entry){p_end}
{synopt:{opt eligend(varname)}}eligibility end date (default: exit){p_end}

{syntab:Trial specification}
{synopt:{opt trials(#)}}number of sequential trials (default: automatic){p_end}
{synopt:{opt trialinterval(#)}}days between trial starts; default is 30{p_end}
{synopt:{opt graceperiod(#)}}grace period for treatment initiation; default is 0{p_end}
{synopt:{opt maxfollowup(#)}}maximum follow-up days per trial{p_end}

{syntab:Methods}
{synopt:{opt clone}}use clone-censor-weight approach{p_end}
{synopt:{opt ipcweight}}calculate inverse probability of censoring weights{p_end}

{syntab:Output}
{synopt:{opt generate(prefix)}}variable prefix; default is {bf:trial_}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvtrial} implements target trial emulation for observational data using
the sequential trial design. This approach allows estimation of causal effects
of treatment initiation versus no treatment using observational data by
emulating a sequence of randomized trials.

{pstd}
The method:

{phang2}1. At each trial start time, identifies eligible individuals who have
not yet initiated treatment{p_end}

{phang2}2. With the {opt clone} option, creates two copies of each eligible
individual - one assigned to "initiate treatment" and one to "do not initiate
treatment"{p_end}

{phang2}3. Censors individuals when they deviate from their assigned treatment
strategy{p_end}

{phang2}4. With {opt ipcweight}, calculates weights to adjust for artificial
censoring{p_end}

{pstd}
This produces a dataset suitable for survival analysis to estimate the causal
effect of treatment initiation on time-to-event outcomes.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the variable that uniquely identifies individuals.

{phang}
{opt entry(varname)} specifies the study entry date for each individual.

{phang}
{opt exit(varname)} specifies the study exit date (end of follow-up).

{phang}
{opt treatstart(varname)} specifies the date of treatment initiation. Missing
values indicate individuals who never initiated treatment.

{dlgtab:Eligibility}

{phang}
{opt eligstart(varname)} specifies when each individual becomes eligible for
the target trial. Defaults to {opt entry}.

{phang}
{opt eligend(varname)} specifies when eligibility ends. Defaults to {opt exit}.

{dlgtab:Trial specification}

{phang}
{opt trials(#)} specifies the number of sequential trials to create. By default,
this is calculated automatically based on the data range and trial interval.

{phang}
{opt trialinterval(#)} specifies the number of days between the start of each
sequential trial. The default is 30 days.

{phang}
{opt graceperiod(#)} specifies the number of days after trial start during which
treatment initiation is allowed while remaining in the "treatment" arm. The
default is 0 (treatment must start exactly at trial start).

{phang}
{opt maxfollowup(#)} limits follow-up time to the specified number of days from
trial start. By default, follow-up continues until the study exit date.

{dlgtab:Methods}

{phang}
{opt clone} specifies the clone-censor-weight approach. Each eligible individual
is cloned at trial start - one copy assigned to treatment, one to no treatment.
Clones are censored when they deviate from their assigned strategy.

{phang}
{opt ipcweight} calculates inverse probability of censoring weights to adjust
for artificial censoring due to the clone approach. This is a simplified
implementation; for proper IPCW, model censoring probabilities explicitly.

{dlgtab:Output}

{phang}
{opt generate(prefix)} specifies the prefix for generated variables. The default
is {bf:trial_}.


{marker examples}{...}
{title:Examples}

{pstd}Setup: Create example cohort{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. set obs 1000}{p_end}
{phang2}{cmd:. gen id = _n}{p_end}
{phang2}{cmd:. gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 30)}{p_end}
{phang2}{cmd:. gen study_exit = study_entry + 365 + floor(runiform() * 180)}{p_end}
{phang2}{cmd:. gen rx_start = .}{p_end}
{phang2}{cmd:. replace rx_start = study_entry + floor(runiform() * 200) if runiform() < 0.4}{p_end}
{phang2}{cmd:. format %td study_entry study_exit rx_start}{p_end}

{pstd}Basic target trial emulation{p_end}
{phang2}{cmd:. tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start)}{p_end}

{pstd}With grace period and monthly trials{p_end}
{phang2}{cmd:. tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) graceperiod(30) trials(12) trialinterval(30)}{p_end}

{pstd}Clone-censor-weight approach{p_end}
{phang2}{cmd:. tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) clone graceperiod(30)}{p_end}

{pstd}Full approach with IPCW{p_end}
{phang2}{cmd:. tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) clone ipcweight graceperiod(30)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvtrial} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_orig)}}original number of observations{p_end}
{synopt:{cmd:r(n_ids)}}number of unique individuals{p_end}
{synopt:{cmd:r(n_trials)}}number of trials with participants{p_end}
{synopt:{cmd:r(n_eligible)}}total eligible person-trial entries{p_end}
{synopt:{cmd:r(n_persontrials)}}total person-trial observations{p_end}
{synopt:{cmd:r(n_treat)}}observations in treatment arm{p_end}
{synopt:{cmd:r(n_control)}}observations in control arm{p_end}
{synopt:{cmd:r(mean_fu)}}mean follow-up time (days){p_end}
{synopt:{cmd:r(total_fu)}}total follow-up (person-days){p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(id)}}ID variable name{p_end}
{synopt:{cmd:r(entry)}}entry variable name{p_end}
{synopt:{cmd:r(exit)}}exit variable name{p_end}
{synopt:{cmd:r(treatstart)}}treatment start variable name{p_end}
{synopt:{cmd:r(prefix)}}variable prefix{p_end}


{marker methods}{...}
{title:Methods and formulas}

{pstd}
{cmd:tvtrial} implements target trial emulation using the sequential trial
design described by Hernan and Robins (2016).

{pstd}
{bf:Sequential trials}

{pstd}
At each trial start time t, individuals who are:

{phang2}1. Eligible (within eligibility window){p_end}
{phang2}2. At risk (not yet exited from study){p_end}
{phang2}3. Treatment-naive (not yet initiated treatment){p_end}

{pstd}
are enrolled into trial t. If an individual meets criteria at multiple time
points, they contribute to multiple trials.

{pstd}
{bf:Clone-censor-weight approach}

{pstd}
With the {opt clone} option, each eligible individual is duplicated at trial
start. One copy is assigned to the "initiate treatment" strategy; the other
to "do not initiate treatment."

{pstd}
Treatment arm clones are censored if they do not initiate treatment within the
grace period. Control arm clones are censored if they initiate treatment during
follow-up.

{pstd}
Inverse probability of censoring weights (IPCW) can adjust for this artificial
censoring to provide unbiased hazard ratio estimates.

{pstd}
{bf:References}

{phang}
Hernan MA, Robins JM. (2016). Using big data to emulate a target trial when
a randomized trial is not available. American Journal of Epidemiology.
183(8):758-764.

{phang}
Hernan MA, et al. (2008). Observational studies analyzed like randomized
experiments: an application to postmenopausal hormone therapy and coronary
heart disease. Epidemiology. 19(6):766-779.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden

{pstd}
Part of the {bf:tvtools} package for time-varying exposure analysis.

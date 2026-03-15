{smcl}
{* *! version 1.1.0  15mar2026}{...}
{viewerjumpto "Syntax" "tte_expand##syntax"}{...}
{viewerjumpto "Description" "tte_expand##description"}{...}
{viewerjumpto "Options" "tte_expand##options"}{...}
{viewerjumpto "Examples" "tte_expand##examples"}{...}
{viewerjumpto "Stored results" "tte_expand##results"}{...}
{viewerjumpto "Technical notes" "tte_expand##technical"}{...}
{viewerjumpto "Author" "tte_expand##author"}{...}

{title:Title}

{phang}
{bf:tte_expand} {hline 2} Sequential trial expansion for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_expand}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opth trial:s(numlist)}}trial periods to emulate{p_end}
{synopt:{opt maxf:ollowup(#)}}maximum follow-up periods; default is unlimited{p_end}
{synopt:{opt grace(#)}}grace period for non-adherence; default is {cmd:0}{p_end}
{synopt:{opth save(filename)}}save expanded data to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_expand} is the core algorithm of the target trial emulation pipeline.
It expands person-period data into a sequence of emulated trials using the
clone-censor-weight approach.

{pstd}
For each eligible trial period: (1) identify eligible individuals, (2) clone
each into treatment and control arms (for PP/AT), (3) follow forward through
subsequent periods, (4) apply artificial censoring when individuals deviate
from their assigned treatment strategy.

{pstd}
The expanded dataset replaces the original data in memory. Created variables
include trial identifier, arm assignment, follow-up time, censoring indicator,
and observed outcome.

{pstd}
Covariates specified in {cmd:tte_prepare} (both {opt covariates()} and
{opt baseline_covariates()}) are frozen at their trial-entry (baseline) values
during expansion. This ensures the marginal structural model conditions on L{sub:0}
only, consistent with Hernán & Robins (2020, Ch. 21). Time-varying confounding
is handled by inverse probability weights computed by {cmd:tte_weight}.


{marker options}{...}
{title:Options}

{phang}
{opth trials(numlist)} specifies which trial periods to emulate. Default is
all periods where at least one individual is eligible.

{phang}
{opt maxfollowup(#)} limits follow-up within each trial to {it:#} periods.
Default is unlimited (all available follow-up).

{phang}
{opt grace(#)} specifies a grace period of {it:#} time units before censoring
for non-adherence (PP/AT only). During the grace period, deviations from
assigned treatment do not trigger censoring.

{phang}
{opth save(filename)} saves the expanded dataset to disk.


{marker examples}{...}
{title:Examples}

{pstd}Basic expansion with max follow-up{p_end}
{phang2}{cmd:. tte_expand, maxfollowup(8)}{p_end}

{pstd}With grace period{p_end}
{phang2}{cmd:. tte_expand, maxfollowup(8) grace(1)}{p_end}

{pstd}Specific trial periods{p_end}
{phang2}{cmd:. tte_expand, trials(0 1 2 3 4) maxfollowup(5)}{p_end}


{marker technical}{...}
{title:Technical notes}

{dlgtab:Covariate freezing}

{pstd}
For each trial period {it:t}, after filtering to eligible individuals from
period {it:t} onward, every variable listed in {cmd:tte_prepare}'s
{opt covariates()} and {opt baseline_covariates()} is replaced with its
value at period {it:t} (the trial-entry observation). The mechanism is:

{phang2}{cmd:bysort id (period): replace var = var[1]}{p_end}

{pstd}
Because the data has already been filtered to {cmd:period >= t}, the first
observation within each individual ({cmd:[1]}) is the trial-entry value.

{pstd}
The {opt treatment()} variable is {bf:not} frozen. It retains its observed
time-varying values throughout follow-up, since it defines arm assignment
and censoring events.

{pstd}
This design follows the MSM
framework: the outcome model E[Y{sup:a} | L{sub:0}] conditions on baseline
covariates L{sub:0} only. Time-varying confounders L{sub:t} are handled by
inverse probability weights, not by regression adjustment. Conditioning on
post-baseline L{sub:t} in the outcome model would introduce collider bias
when L{sub:t} is affected by treatment (Hernán & Robins, 2020, Ch. 21).

{dlgtab:Artificial censoring (PP/AT)}

{pstd}
For PP and AT estimands, each individual is cloned into treatment (arm=1)
and control (arm=0) copies. Censoring is applied when observed treatment
deviates from the assigned arm after any grace period:

{phang2}Treatment arm: censored when {cmd:treatment == 0} and {cmd:followup >= grace}{p_end}
{phang2}Control arm: censored when {cmd:treatment == 1} and {cmd:followup >= grace}{p_end}

{pstd}
Rows after the censoring event are dropped. For ITT, no cloning or
artificial censoring is applied; each individual appears once with their
observed treatment assignment at baseline.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_expand} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_trials)}}number of emulated trials{p_end}
{synopt:{cmd:r(n_expanded)}}total expanded observations{p_end}
{synopt:{cmd:r(n_treat)}}treatment arm observations{p_end}
{synopt:{cmd:r(n_control)}}control arm observations{p_end}
{synopt:{cmd:r(n_censored)}}censored observations{p_end}
{synopt:{cmd:r(n_events)}}outcome events{p_end}
{synopt:{cmd:r(expansion_ratio)}}expansion ratio (expanded/original){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(method)}}processing method (memory or chunked){p_end}
{synopt:{cmd:r(estimand)}}estimand (ITT, PP, or AT){p_end}


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

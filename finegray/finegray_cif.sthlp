{smcl}
{vieweralsosee "finegray" "help finegray"}{...}
{vieweralsosee "finegray_predict" "help finegray_predict"}{...}
{vieweralsosee "stcurve" "help stcurve"}{...}
{viewerjumpto "Syntax" "finegray_cif##syntax"}{...}
{viewerjumpto "Description" "finegray_cif##description"}{...}
{viewerjumpto "Options" "finegray_cif##options"}{...}
{viewerjumpto "Remarks" "finegray_cif##remarks"}{...}
{viewerjumpto "Examples" "finegray_cif##examples"}{...}
{viewerjumpto "Stored results" "finegray_cif##results"}{...}
{viewerjumpto "Author" "finegray_cif##author"}{...}
{title:Title}

{phang}
{bf:finegray_cif} {hline 2} Cumulative incidence curves and fixed-horizon
cumulative incidence after {help finegray}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:finegray_cif}
[{cmd:,} {it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt at(var=# ...)}}covariate profile for the curve; default is the
estimation-sample means{p_end}
{synopt :{opt att:ime(numlist)}}report a table of the CIF at the listed time
horizons instead of plotting a curve{p_end}
{synopt :{opt ti:mepoints(numlist)}}evaluate the curve at these times instead of
the event-time grid{p_end}
{synopt :{opt ci}}add pointwise confidence limits (influence-function SE){p_end}
{synopt :{opt boot:strap(#)}}compute a subject- or cluster-bootstrap confidence band{p_end}
{synopt :{opt seed(#)}}random-number seed for {opt bootstrap()}{p_end}
{synopt :{opt l:evel(#)}}set confidence level; default is {cmd:c(level)}{p_end}
{synopt :{opt sav:ing(filename[, replace])}}save the numeric estimates
({cmd:time cif se lci uci}) to a dataset{p_end}
{synopt :{opt nograph}}suppress the graph{p_end}
{synopt :{it:twoway_options}}any options documented in {help twoway_options}{p_end}
{synoptline}
{p 4 6 2}{cmd:finegray_cif} is for use after {helpb finegray}; see
{helpb finegray}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:finegray_cif} computes the predicted cumulative incidence function (CIF) for
a chosen covariate profile after {helpb finegray}, as

{p 8 8 2}
CIF(t | z) = 1 - exp( -H0(t) * exp(z'b) ),

{pstd}
where H0(t) is the baseline cumulative subdistribution hazard stored in
{cmd:e(basehaz)}. By default it plots the CIF over the event-time grid; with
{opt attime()} it instead reports the CIF at specific horizons (for example the
5-year cumulative incidence).

{pstd}
{cmd:finegray_cif} is the {helpb finegray} analogue of {helpb stcurve}{cmd:, cif}
after {helpb stcrreg}, with two additions: it can plot a pointwise confidence
{it:band} (which {cmd:stcurve} cannot), and it can {opt saving()} the numeric
estimates behind the curve.

{pstd}
The command requires the unchanged original {cmd:stset} estimation data in
memory. It verifies a signature of the estimation sample and the variables used
by the fit before reading {cmd:e(basehaz)} or reconstructing influence
functions. Re-run {cmd:finegray} after changing those data.


{marker options}{...}
{title:Options}

{phang}
{opt at(var=# ...)} sets the covariate profile at which the CIF is evaluated, for
example {cmd:at(age=60 male=1)}. Variables not listed are held at their
estimation-sample mean. The default profile is the estimation-sample means of all
model covariates. Factor variables may be named directly by their level, for
example {cmd:at(pelnode=1)} after {cmd:finegray i.pelnode ...}; the requested
level is mapped onto the internal indicator variables (the reference level sets
every indicator to 0). A factor variable that enters an interaction term must be
set through its internal {cmd:_fg_*} indicator names instead (see
{cmd:e(covariates)}).

{phang}
{opt attime(numlist)} requests a table of the CIF at the listed time horizons
(for example {cmd:attime(1 5 10)}) instead of a plotted curve. Combine with
{opt ci} to include confidence limits.

{phang}
{opt timepoints(numlist)} evaluates the curve at the specified times rather than
at the distinct cause-event times in {cmd:e(basehaz)}.

{phang}
{opt ci} adds pointwise confidence limits. The standard error of the CIF is an
influence-function (sandwich) standard error; limits are formed on the
complementary log-log scale so that they remain inside (0,1). The standard error
treats the inverse-probability-of-censoring weights as known; under heavy
censoring it is mildly anti-conservative, in which case {opt bootstrap()} gives a
bootstrap-based band that includes censoring-weight uncertainty.

{phang}
{opt bootstrap(#)} computes the confidence band by resampling subjects with
replacement and refitting the model. If the original fit specified
{opt cluster()}, whole clusters are resampled instead. The simulated band
therefore follows the fitted variance structure and includes uncertainty from
estimating the censoring weights. Nonconverged refits, and refits whose resample
loses a factor level (so the coefficient vector no longer matches the stored
covariate profile), are skipped and counted in {cmd:r(bootstrap_failed)}; at
least two successful replications are required. Point estimates are unchanged;
only the standard error and limits differ. The original estimation results and
{cmd:e(sample)} are preserved.

{phang}
{opt seed(#)} sets the random-number seed used by {opt bootstrap()} for
reproducibility.

{phang}
{opt level(#)} sets the confidence level; the default is {cmd:c(level)}, which
is initially 95 and can be changed by {helpb set level}.

{phang}
{opt saving(filename[, replace])} writes a dataset containing {cmd:time},
{cmd:cif}, {cmd:se}, {cmd:lci}, and {cmd:uci} (one row per evaluated time) - the
analogue of {cmd:outfile} after {cmd:stcurve}. Only the optional suboption
{cmd:replace} is accepted. Shell metacharacters and embedded quote characters
are rejected in {it:filename}.

{phang}
{opt nograph} suppresses the graph (useful with {opt saving()}).

{phang}
{it:twoway_options} are any of the options documented in {help twoway_options},
for example {cmd:title()}, {cmd:xtitle()}, or {cmd:scheme()}. These pass through
to the CIF plot and override the defaults. The legend defaults to a single row;
because repeated {cmd:legend()} options merge, you can adjust or suppress it from
here, for example {cmd:legend(off)}, {cmd:legend(pos(6))}, or
{cmd:legend(rows(2))}.


{marker remarks}{...}
{title:Remarks}

{pstd}
For a confidence interval on the cumulative incidence of {it:each subject} (or a
selected subset), see {helpb finegray_predict}{cmd:, cif ci}, which generates
per-observation CIF limits at each observation's own time or at a supplied
{opt timevar()}.

{pstd}
The confidence band is computed from the per-subject influence functions of the
CIF, propagating the uncertainty in both the coefficient vector {cmd:e(b)} and
the baseline cumulative subdistribution hazard. With {opt cluster()} in the
original {helpb finegray} fit, the analytic band uses the corresponding
cluster-robust variance and {opt bootstrap()} resamples whole clusters.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. webuse hypoxia, clear}{p_end}
{phang2}{cmd:. gen byte status = failtype}{p_end}
{phang2}{cmd:. stset dftime, failure(dfcens==1) id(stnum)}{p_end}
{phang2}{cmd:. finegray i.pelnode ifp tumsize, compete(status) cause(1)}{p_end}

{pstd}Plot the CIF curve at the covariate means, with a 95% band{p_end}
{phang2}{cmd:. finegray_cif, ci}{p_end}

{pstd}Curve for a specified covariate profile{p_end}
{phang2}{cmd:. finegray_cif, at(pelnode=1 ifp=20 tumsize=5) ci}{p_end}

{pstd}Fixed-horizon table: CIF at 1, 5, and 8 years with confidence limits{p_end}
{phang2}{cmd:. finegray_cif, attime(1 5 8) ci}{p_end}

{pstd}Curve evaluated on a custom time grid{p_end}
{phang2}{cmd:. finegray_cif, timepoints(1 2 3 4 5 6 7 8) ci}{p_end}

{pstd}Save the numeric estimates behind the curve{p_end}
{phang2}{cmd:. finegray_cif, ci nograph saving(cifcurve.dta,replace)}{p_end}

{pstd}Band by subject bootstrap{p_end}
{phang2}{cmd:. finegray_cif, attime(1 5 8) ci bootstrap(500) seed(12345)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:finegray_cif} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(level)}}confidence level{p_end}
{synopt:{cmd:r(cause)}}cause of interest{p_end}
{synopt:{cmd:r(bootstrap_requested)}}requested replications; with {cmd:bootstrap()}{p_end}
{synopt:{cmd:r(bootstrap_success)}}converged replications used; with {cmd:bootstrap()}{p_end}
{synopt:{cmd:r(bootstrap_failed)}}skipped replications; with {cmd:bootstrap()}{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(profile_vars)}}model covariates, in column order of {cmd:r(at)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}one row per evaluated time{p_end}
{synopt:{cmd:r(at)}}covariate profile used for the curve{p_end}

{pstd}
The columns of {cmd:r(table)} are {cmd:time}, {cmd:cif}, {cmd:se}, {cmd:lci}, and {cmd:uci}.

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb finegray}, {helpb finegray_predict}, {helpb finegray_phtest}, {helpb stcurve}, {helpb stcrreg}

{hline}

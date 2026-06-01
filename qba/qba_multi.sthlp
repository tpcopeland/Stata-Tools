{smcl}
{* *! version 1.0.0  02jun2026}{...}
{vieweralsosee "qba" "help qba"}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_plot" "help qba_plot"}{...}
{viewerjumpto "Syntax" "qba_multi##syntax"}{...}
{viewerjumpto "Description" "qba_multi##description"}{...}
{viewerjumpto "Options" "qba_multi##options"}{...}
{viewerjumpto "Remarks" "qba_multi##remarks"}{...}
{viewerjumpto "Examples" "qba_multi##examples"}{...}
{viewerjumpto "Stored results" "qba_multi##results"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:qba_multi} {hline 2}}Multi-bias analysis combining multiple bias corrections{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 18 2}
{cmd:qba_multi}
{cmd:,}
{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}
{opt reps(#)}
[{it:misclassification_options}]
[{it:selection_options}]
[{it:confounding_options}]
[{it:options}]


{synoptset 36 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt a(#)} {opt b(#)} {opt c(#)} {opt d(#)}}2x2 table cells (non-negative){p_end}
{synopt:{opt reps(#)}}Monte Carlo replications (minimum 100){p_end}

{syntab:Misclassification (requires both seca and spca)}
{synopt:{opt seca(#)}}sensitivity of classification; (0, 1]{p_end}
{synopt:{opt spca(#)}}specificity of classification; (0, 1]; Se + Sp > 1{p_end}
{synopt:{opt secb(#)}}sensitivity for second group (enables differential mode){p_end}
{synopt:{opt spcb(#)}}specificity for second group (enables differential mode){p_end}
{synopt:{opt mc:type(exposure|outcome)}}misclassification type; default {cmd:exposure}{p_end}
{synopt:{opt dist_se(distribution)}}distribution for Se; default constant at {cmd:seca()}{p_end}
{synopt:{opt dist_sp(distribution)}}distribution for Sp; default constant at {cmd:spca()}{p_end}
{synopt:{opt dist_se1(distribution)}}distribution for Se group B (differential only){p_end}
{synopt:{opt dist_sp1(distribution)}}distribution for Sp group B (differential only){p_end}

{syntab:Selection bias (requires all four sel options)}
{synopt:{opt sela(#)} {opt selb(#)}}selection probabilities for cases; (0, 1]{p_end}
{synopt:{opt selc(#)} {opt seld(#)}}selection probabilities for non-cases; (0, 1]{p_end}
{synopt:{opt dist_sela(distribution)}}through {opt dist_seld()} distributions{p_end}

{syntab:Unmeasured confounding (requires p1, p0, and rrcd or rrud)}
{synopt:{opt p1(#)}}P(confounder = 1 | exposed); [0, 1]{p_end}
{synopt:{opt p0(#)}}P(confounder = 1 | unexposed); [0, 1]{p_end}
{synopt:{opt rrcd(#)}}confounder-disease RR (Schneeweiss); > 0{p_end}
{synopt:{opt rrud(#)}}confounder-disease RR (Greenland); > 0; cannot combine with {opt rrcd()}{p_end}
{synopt:{opt dist_p1(distribution)}}through {opt dist_rr()} distributions{p_end}

{syntab:Control}
{synopt:{opt mea:sure(OR|RR)}}measure of association; default {cmd:OR}{p_end}
{synopt:{opt or:der(string)}}cell-level correction order; default {cmd:misclass selection}{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt level(#)}}confidence level for percentile interval; default {cmd:95}{p_end}
{synopt:{opt sa:ving(filename, ...)}}save Monte Carlo dataset{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba_multi} chains multiple bias corrections in a single Monte Carlo
simulation framework. At each replicate, bias parameters for all active
biases are drawn from their distributions, and corrections are applied
sequentially to propagate uncertainty through the full correction chain.

{pstd}
Only biases with complete parameter sets are activated. You can correct for
any combination of one, two, or all three bias types by specifying their
parameters. At least one bias type must be specified.

{pstd}
The default correction order follows Lash, Fox, and Fink (2021, Chapter 12):

{phang2}1. {bf:Misclassification} (cell-level correction){p_end}
{phang2}2. {bf:Selection bias} (cell-level correction){p_end}
{phang2}3. {bf:Unmeasured confounding} (measure-level correction, always applied last){p_end}

{pstd}
Misclassification and selection are cell-level corrections (they modify the
2x2 table counts). Confounding is a measure-level correction (it divides the
computed measure of association by the bias factor) and is always applied
after the cell-level corrections, regardless of the {opt order()} setting.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt a(#)}, {opt b(#)}, {opt c(#)}, {opt d(#)} specify the four cells of the
observed 2x2 table. All values must be non-negative.

{phang}
{opt reps(#)} specifies the number of Monte Carlo replications. Minimum is
100. Unlike the single-bias commands, {cmd:qba_multi} always operates in
probabilistic mode.

{dlgtab:Misclassification}

{phang}
{opt seca(#)} and {opt spca(#)} specify sensitivity and specificity of
classification. Both must be specified to activate misclassification
correction. Each must be in (0, 1] and their sum must exceed 1.

{phang}
{opt secb(#)} and {opt spcb(#)} specify Se and Sp for the second group,
enabling differential misclassification. If only one is specified, the other
defaults to its group-A counterpart. Each must be in (0, 1] and their sum
must exceed 1.

{phang}
{opt mctype(exposure|outcome)} specifies the misclassification type. Default
is {cmd:exposure}. See {helpb qba_misclass} for details.

{phang}
{opt dist_se(distribution)} and {opt dist_sp(distribution)} specify
distributions for Se and Sp draws. If omitted, constants at {opt seca()}
and {opt spca()} are used. See {helpb qba} for distribution syntax.

{phang}
{opt dist_se1(distribution)} and {opt dist_sp1(distribution)} specify
distributions for the second group in differential mode. If omitted,
constants at {opt secb()} and {opt spcb()} are used.

{dlgtab:Selection bias}

{phang}
{opt sela(#)}, {opt selb(#)}, {opt selc(#)}, {opt seld(#)} specify selection
probabilities for each cell. All four must be specified to activate selection
bias correction. Each must be in (0, 1].

{phang}
{opt dist_sela(distribution)} through {opt dist_seld(distribution)} specify
distributions for each selection probability. If omitted, constants at the
fixed values are used.

{dlgtab:Unmeasured confounding}

{phang}
{opt p1(#)}, {opt p0(#)}, and {opt rrcd(#)} or {opt rrud(#)} specify
confounding parameters. All three must be specified to activate confounding
correction. See {helpb qba_confound} for details on the two RR
parameterizations.

{phang}
{opt dist_p1(distribution)}, {opt dist_p0(distribution)}, and
{opt dist_rr(distribution)} specify distributions for confounding parameters.
If omitted, constants at the fixed values are used.

{dlgtab:Control}

{phang}
{opt measure(OR|RR)} specifies the measure of association. Default is
{cmd:OR}.

{phang}
{opt order(string)} specifies the order of cell-level bias corrections. Valid
entries are {cmd:misclass} and {cmd:selection}. {cmd:confound} cannot appear
in {opt order()} because confounding is always applied last at the measure
level. All active cell-level biases must appear. Default order is
{cmd:misclass selection} (following Lash, Fox, and Fink 2021).

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt level(#)} specifies the confidence level for the percentile interval.
Default is {cmd:95}.

{phang}
{opt saving(filename, replace)} saves the Monte Carlo dataset containing
corrected cell counts and corrected measures.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Which biases are active?} Each bias type is activated only when its
complete parameter set is specified. Partial parameter sets (e.g., specifying
{opt seca()} without {opt spca()}) produce an error. This design lets you run
any combination: misclass only, selection + confounding, all three, etc.

{pstd}
{bf:Correction order.} The default order (misclass -> selection -> confound)
follows Lash, Fox, and Fink's recommendation. However, you can reverse the
order of cell-level corrections using {opt order(selection misclass)} if the
study design suggests selection occurred before misclassification. The
confounding correction is always applied last because it operates on the
measure of association rather than the cell counts.

{pstd}
{bf:Invalid replicates.} Some draws may produce negative corrected cell
counts (from misclassification correction) or undefined measures. These
replicates are excluded. A warning is displayed when more than 20% of
replicates are invalid, suggesting the distributions may be too wide.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: All three biases with fixed parameters}

{phang2}{cmd:. qba_multi, a(136) b(297) c(1432) d(6738) reps(10000)} ///
{phang3}{cmd:seca(.85) spca(.95)} ///
{phang3}{cmd:sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:p1(.4) p0(.2) rrcd(2.0) seed(12345)}{p_end}

{pstd}
{bf:Example 2: Misclassification + confounding with distributions}

{phang2}{cmd:. qba_multi, a(136) b(297) c(1432) d(6738) reps(20000)} ///
{phang3}{cmd:seca(.85) spca(.95) dist_se("trapezoidal .75 .82 .88 .95")} ///
{phang3}{cmd:dist_sp("trapezoidal .90 .93 .97 1.0")} ///
{phang3}{cmd:p1(.4) p0(.2) rrcd(2.0) dist_rr("uniform 1.5 3.0")} ///
{phang3}{cmd:seed(54321) saving(multi_results, replace)}{p_end}

{pstd}
{bf:Example 3: Selection + confounding only}

{phang2}{cmd:. qba_multi, a(136) b(297) c(1432) d(6738) reps(10000)} ///
{phang3}{cmd:sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:p1(.3) p0(.1) rrud(2.0) seed(12345)}{p_end}

{pstd}
{bf:Example 4: Reverse correction order}

{phang2}{cmd:. qba_multi, a(136) b(297) c(1432) d(6738) reps(10000)} ///
{phang3}{cmd:seca(.85) spca(.95) sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:order(selection misclass) measure(RR) seed(12345)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:qba_multi} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(observed)}}observed measure of association{p_end}
{synopt:{cmd:r(corrected)}}median corrected measure{p_end}
{synopt:{cmd:r(mean)}}mean of corrected measures{p_end}
{synopt:{cmd:r(sd)}}standard deviation of corrected measures{p_end}
{synopt:{cmd:r(ci_lower)}}lower bound of percentile confidence interval{p_end}
{synopt:{cmd:r(ci_upper)}}upper bound of percentile confidence interval{p_end}
{synopt:{cmd:r(reps)}}number of replications requested{p_end}
{synopt:{cmd:r(n_valid)}}number of valid (non-missing) replications{p_end}
{synopt:{cmd:r(n_draw_invalid)}}number of draws with out-of-support parameters{p_end}
{synopt:{cmd:r(n_biases)}}number of bias types corrected (1, 2, or 3){p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(measure)}}measure of association ({cmd:OR} or {cmd:RR}){p_end}
{synopt:{cmd:r(method)}}{cmd:multi-bias}{p_end}
{synopt:{cmd:r(order)}}cell-level correction order used{p_end}


{title:References}

{phang}
Lash TL, Fox MP, Fink AK. {it:Applying Quantitative Bias Analysis to}
{it:Epidemiologic Data}. 2nd ed. New York: Springer; 2021. Chapter 12.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-06-02{p_end}

{hline}

{smcl}
{viewerjumpto "Syntax" "ratetab##syntax"}{...}
{viewerjumpto "Description" "ratetab##description"}{...}
{viewerjumpto "Options" "ratetab##options"}{...}
{viewerjumpto "Methods" "ratetab##methods"}{...}
{viewerjumpto "Examples" "ratetab##examples"}{...}
{viewerjumpto "Stored results" "ratetab##stored"}{...}
{viewerjumpto "References" "ratetab##references"}{...}
{viewerjumpto "Author" "ratetab##author"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "comptab" "help comptab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{title:Title}

{phang}
{bf:ratetab} {hline 2} Events, person-time, and incidence rates with confidence intervals by grouping variables


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:ratetab} {it:groupvars} {ifin}
[{cmd:,} {it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Data}
{synopt:{opt ev:ents(varlist)}}event counts per outcome; default {cmd:_d}{p_end}
{synopt:{opt exp:osure(varlist)}}person-time: one, or one per outcome{p_end}

{syntab:Rates}
{synopt:{opt per(#)}}rate per # person-time units; default {cmd:1000}{p_end}
{synopt:{opt pys:cale(#)}}divide person-time by #; default 1{p_end}
{synopt:{opt ci(method)}}{cmd:exact} (default), {cmd:poisson}, or {cmd:cluster(}{it:varname}{cmd:)}{p_end}
{synopt:{opt l:evel(#)}}confidence level; default {cmd:c(level)}{p_end}
{synopt:{opt small:cells(#)}}mask 1 to #-1 events as {cmd:<}#{p_end}
{synopt:{opt nosmall:cells}}ignore the session smallcells default{p_end}
{synopt:{opt mask:text(string)}}text of a masked event count; default {cmd:<}#{p_end}
{synopt:{opt excludem:asked}}keep masked levels out of the cluster fit{p_end}
{synopt:{opt zeroc:ells(dash|blank[, persontime])}}zero-event cells as {cmd:–} or empty{p_end}

{syntab:Format}
{synopt:{opt dig:its(#)}}decimal places of rates; default 1{p_end}
{synopt:{opt cf:ormat(%fmt)}}format of rate and limits{p_end}
{synopt:{opt sep(string)}}separator between the limits; default {cmd:", "}{p_end}
{synopt:{opt pyd:igits(#)}}decimal places of person-time; default 0{p_end}
{synopt:{opt outl:abels(string)}}outcome labels separated by {cmd:\}{p_end}
{synopt:{opt expl:abels(string)}}section labels separated by {cmd:\}{p_end}
{synopt:{opt unit:label(string)}}rate unit in the header{p_end}

{syntab:Output}
{synopt:{opt sav:ing(filename[, replace])}}save the numbers per level as a dataset{p_end}
{synopt:{it:stratetab_options}}output options of {helpb stratetab}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ratetab} counts events and person-time for each level of each grouping
variable and reports the incidence rate with its confidence interval, one
section per grouping variable and one column group per outcome. It reads
{helpb stset} data directly ({cmd:_d} and {cmd:_t - _t0} on {cmd:_st == 1}) or event and
person-time variables named in {opt events()} and {opt exposure()}.

{pstd}
The table is laid out and written by {helpb stratetab}, so its Excel, CSV,
Markdown, and {opt frame()} output have the {cmd:stratetab} layout, and the
frame can be given to {helpb comptab}{cmd:, rateframe()} to place model estimates
beside the rates. An observation with a missing value of a grouping variable
({cmd:.} or an extended missing value {cmd:.a}-{cmd:.z}, as {cmd:tabulate}
leaves them out) is left out of that variable's table only; the other grouping variables keep
it, as {cmd:strate} run one variable at a time would.


{marker options}{...}
{title:Options}

{dlgtab:Data}

{phang}
{opt events(varlist)} names nonnegative integer event counts (0/1 indicators or
counts), one variable per outcome; each becomes a column
group. {opt exposure(varlist)} names the person-time of each observation: one
variable used for every outcome, or one variable per outcome, paired in order
with {opt events()} ({cmd:events(e1 e2) exposure(py1 py2)}: {cmd:e1} over
{cmd:py1}, {cmd:e2} over {cmd:py2}), for outcomes whose follow-up ends at
different times. Any other number of variables is refused. Give both, or
neither for {cmd:stset} data. Negative person-time, non-integer counts, and
events without person-time (in the outcome's own variable) are refused. A
level with no person-time for an outcome (every observation of the level has
zero exposure for that outcome) has no computable rate: its events,
person-time, and rate cells for that outcome are left empty in every output
(console, Excel, CSV, Markdown, and frame), its {cmd:rate}, {cmd:lb}, and
{cmd:ub} are missing in {cmd:r(estimates)} and {opt saving()}, and it is
counted in {cmd:r(N_nopt)}, not in {cmd:r(N_zero)}. When no level has
person-time for any outcome, there is nothing to show and {cmd:ratetab} exits
with r(459). An
observation missing any of the {opt events()} or {opt exposure()} variables
is left out of every outcome, so all outcomes share one sample ({cmd:r(N)}).

{dlgtab:Rates}

{phang}
{opt per(#)} scales the rates; {cmd:per(1000)} gives rates per 1,000
person-years when person-time is in years.

{phang}
{opt pyscale(#)} divides person-time before display, rate computation and
{cmd:r(estimates)}, so the person-time column is in the scaled
unit; {cmd:pyscale(365.25)} turns days into years.

{phang}
{opt ci(method)} sets the interval. {cmd:exact} gives exact Poisson limits for
the event count. {cmd:poisson} gives {helpb strate}'s limits,
rate*exp(-/+z/sqrt(D)). {cmd:cluster(}{it:varname}{cmd:)} fits, for each grouping variable and
outcome, a Poisson model with an indicator per level, person-time as exposure,
and variance clustered on {it:varname}, as is appropriate for repeated
events in the same person; the number of clusters is displayed and stored in
{cmd:r(clusters)}, because the clustered variance is unreliable with few
clusters. A level whose events all come from one cluster has no clustered
interval and is printed without one. A level with no events shows the exact
limits (0, -ln(alpha/2)/Y) whatever the method.

{phang}
{opt level(#)} sets the confidence level of the rate intervals, from 10 to
99.99; the default is {cmd:c(level)}. It applies to every {opt ci()} method,
is shown in the rate header ("Per 1,000 PY (90% CI)"), and is stored in
{cmd:r(level)} and {cmd:r(ci_level)}.

{phang}
{opt smallcells(#)} prints an event count from 1 to #-1 as {cmd:<}# and
withholds that cell's person-time and rate ({cmd:–}). Zero is printed. It
governs printed output only; {cmd:r()} keeps the numbers. Masking is primary
only: with several grouping variables over one sample, a masked count can be
recovered from another variable's totals. Without it, a
session default set by {cmd:tabtools set smallcells #} applies and is echoed
in the log; {opt nosmallcells} ignores that default.

{phang}
{opt masktext(string)} is printed in place of a masked event count, for
example {cmd:masktext("–")}; the default is {cmd:<}#, as in {cmd:<5}. The
person-time and rate of a masked cell are withheld ({cmd:–}) either way. It
requires a small-cell threshold.

{phang}
{opt excludemasked}, with {cmd:ci(cluster(}{it:varname}{cmd:))} and a small-cell
threshold # of 2 or more, leaves the levels with 1 to #-1 events out of the
clustered Poisson fit, as levels with no events always are. Those levels
then have no interval in {cmd:r(estimates)} (they print masked anyway) and
are counted in {cmd:r(N_maskfit)}, not {cmd:r(N_noci)}. See {it:Methods} for
what this does and does not change.

{phang}
{opt zerocells(dash|blank[, persontime])} prints a level with no events with {cmd:–}
({cmd:dash}) or nothing ({cmd:blank}) in place of its count and its rate and
interval; its person-time is still shown unless the suboption
{cmd:persontime} is given, which withholds it the same way
({cmd:zerocells(dash, persontime)} prints {cmd:–} in all three cells). Without
it, the count 0 is printed with the rate 0 and the exact limits
(0, -ln(alpha/2)/Y). {cmd:r()} and {opt saving()} keep the numbers. With
{cmd:blank, persontime} a zero-event cell prints like a cell with no
person-time (all empty); use {cmd:dash} to tell them apart.

{dlgtab:Format}

{phang}
{opt digits(#)} sets the decimal places of the rate and its
limits. {opt cformat(%fmt)} instead applies any numeric display format (for example
{cmd:%9.1fc}); string and date formats are refused.

{phang}
{opt pydigits(#)} sets the decimal places of the person-time column, from 0 to
10; the default is 0, so 180.4 person-years print as {cmd:180}. It changes the
printed person-time only: {cmd:r(estimates)} and {opt saving()} keep the
numbers.

{phang}
{opt sep(string)} separates the two limits in every output (console, Excel,
CSV, Markdown, and frame), printed as typed; see {help tabtools##sep:interval separators}.

{phang}
{opt outlabels()}, {opt explabels()}, and {opt unitlabel()} label the outcome
column groups, the sections, and the rate header. The defaults are the
variable labels (or names) and {it:per()} printed as typed, with thousands
separators (for example, {cmd:per(0.5)} gives "0.5", {cmd:per(1500.5)} gives "1,500.5").

{dlgtab:Output}

{phang}
{opt saving(filename[, replace])} saves a numeric dataset with one row per
printed level: {cmd:outcome}, {cmd:outcome_var}, {cmd:outcome_label},
{cmd:group}, {cmd:groupvar}, {cmd:level}, {cmd:level_label}, {cmd:events},
{cmd:persontime} (in {opt pyscale()} units), {cmd:rate}, {cmd:lb}, and
{cmd:ub} (per {opt per()}), {cmd:masked} (1 when the printed cell is
masked), and {cmd:nopersontime} (1 when the level has no person-time for the
outcome, so {cmd:rate}, {cmd:lb}, and {cmd:ub} are missing). After these
columns comes each grouping variable under its own name, with its storage
type, display format, variable label, and value label: on the rows of that
grouping variable it holds the level's value, and on the rows of the other
grouping variables it is missing. So {cmd:ratetab drug} saves a numeric
{cmd:drug} with its value labels, and {cmd:use rates, clear} followed by
{cmd:list drug rate if groupvar == "drug"} shows the labelled levels. A
grouping variable listed twice has one column, filled on the rows of both
listings. A grouping variable that has the name of one of the fixed columns
(for example {cmd:group} or {cmd:level}) is saved as {cmd:g_}{it:name}
(or {cmd:g2_}{it:name}, {cmd:g3_}{it:name}, ... if that name is taken), so the
fixed columns keep their meaning; a note says so, the column's
characteristic {cmd:ratetab_groupvar} and the dataset characteristic
{cmd:ratetab_renamed} record the original name, and {cmd:groupvar} holds it
on every row. The numbers are the unmasked numbers of {cmd:r(estimates)}, so the
file is an analysis file, not a release table. The file is checked before
any work and written after the table.

{phang}
All other options are passed to {helpb stratetab}: {opt xlsx()},
{opt sheet()}, {opt title()}, {opt footnote()} (passed unchanged), {opt csv()},
{opt markdown()}, {opt mdappend}, {opt frame()}, {opt rateratio}, and its
formatting options.


{marker methods}{...}
{title:Methods}

{pstd}
For D events in person-time Y, the rate is D/Y times {opt per()}. The exact
limits solve Pr(K >= D | l1) = alpha/2 and Pr(K <= D | l2) = alpha/2 for a
Poisson count K, as {cmd:ci means, poisson} does ([R] ci); they are
{cmd:invpoissontail(}D, alpha/2{cmd:)}/Y and {cmd:invpoisson(}D, alpha/2{cmd:)}/Y. The
clustered limits are exp(b_j -/+ z se_j) from the saturated Poisson model, whose
estimate exp(b_j) equals D_j/Y_j; the fit starts at that closed-form estimate, so
b_j and se_j are evaluated at it exactly. Levels with no events are left out of that fit.

{pstd}
{it:What excludemasked changes.} The saturated model's information matrix is
diagonal, so each level's coefficient and its sandwich variance depend only on
that level's own events and person-time: Var(b_j) = G/(G-1) * sum_c u_cj^2 / D_j^2,
with u_cj = d_cj - Y_cj D_j/Y_j the score of cluster c for level j and G the
number of clusters in the fit. Leaving the masked levels out therefore does
not change the estimand or the estimate of any other level; it changes their
standard errors only through G, the clusters that contribute to the fit,
and so only through the small-sample factor G/(G-1). With many clusters the
change is negligible; with few it is not, and the cluster count reported is
that of the reduced fit. The masked levels themselves get no clustered
interval. This follows the closed form derived for the package (see the
literature notes on rate intervals); it is not a separate method.

{pstd}
With one {opt exposure()} variable per outcome, each outcome's rate, interval,
and clustered fit use that outcome's own person-time.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. webuse drugtr, clear}{p_end}
{phang2}{cmd:. generate id = _n}{p_end}
{phang2}{cmd:. ratetab drug}{p_end}
{phang2}{cmd:. ratetab drug, ci(poisson) per(100)}{p_end}
{phang2}{cmd:. ratetab drug, ci(cluster(id)) frame(rates, replace)}{p_end}
{phang2}{cmd:. ratetab drug, smallcells(15) cformat(%5.1f) sep(" to ")}{p_end}

{pstd}Event and person-time variables instead of {cmd:stset} data{p_end}

{phang2}{cmd:. generate double pt = _t - _t0}{p_end}
{phang2}{cmd:. ratetab drug, events(died) exposure(pt)}{p_end}

{pstd}Per-outcome person-time, masking, and a saved numeric file{p_end}

{phang2}{cmd:. generate byte died2 = died & _t < 20}{p_end}
{phang2}{cmd:. generate double pt2 = min(_t, 20) - _t0}{p_end}
{phang2}{cmd:. ratetab drug, events(died died2) exposure(pt pt2) smallcells(15) masktext("–") zerocells(dash) saving(rates, replace)}{p_end}
{phang2}{cmd:. ratetab drug, ci(cluster(id)) smallcells(15) excludemasked}{p_end}

{pstd}Withhold the person-time of zero-event levels too{p_end}

{phang2}{cmd:. ratetab drug, events(died died2) exposure(pt pt2) zerocells(dash, persontime)}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:ratetab} stores the results of {helpb stratetab} ({cmd:r(rates)}, {cmd:r(ci_level)},
{cmd:r(smallcells)}, {cmd:r(N_rows)}, output paths, and so on) and also:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations with any grouping value{p_end}
{synopt:{cmd:r(per)}}rate multiplier{p_end}
{synopt:{cmd:r(level)}}confidence level{p_end}
{synopt:{cmd:r(N_zero)}}cells with no events{p_end}
{synopt:{cmd:r(N_noci)}}cells without a clustered interval{p_end}
{synopt:{cmd:r(N_nopt)}}cells with no person-time (no rate; printed empty){p_end}
{synopt:{cmd:r(N_maskfit)}}masked cells left out of the clustered fit{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(ci_method)}}{cmd:exact}, {cmd:poisson}, or {cmd:cluster}{p_end}
{synopt:{cmd:r(cluster)}}cluster variable{p_end}
{synopt:{cmd:r(methods)}}methods sentence{p_end}
{synopt:{cmd:r(saving)}}file written by {opt saving()}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(estimates)}}one row per cell; see {it:Remarks} below{p_end}
{synopt:{cmd:r(clusters)}}clusters per fit (groups x outcomes){p_end}


{pstd}
{it:Remarks.} {cmd:r(estimates)} has one row per printed cell, in table order, with
columns {cmd:outcome}, {cmd:group}, {cmd:level}, {cmd:events}, {cmd:persontime}, {cmd:rate}, {cmd:lb},
and {cmd:ub} (rates per {opt per()}, unmasked).


{marker references}{...}
{title:References}

{phang}
StataCorp. Stata Base Reference Manual: ci (Methods and formulas, Poisson mean). College Station, TX: Stata Press.

{phang}
Ulm K. 1990. A simple method to calculate the confidence interval of a standardized mortality ratio
(SMR). American Journal of Epidemiology 131: 373-375.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{helpb stratetab}, {helpb comptab}, {helpb strate}, {helpb tabtools}
{p_end}

{hline}

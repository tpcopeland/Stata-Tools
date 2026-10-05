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
{synopt:{opt exp:osure(varname)}}person-time; default {cmd:_t - _t0} of {cmd:stset} data{p_end}

{syntab:Rates}
{synopt:{opt per(#)}}rate per # person-time units; default {cmd:1000}{p_end}
{synopt:{opt pys:cale(#)}}divide person-time by #; default 1{p_end}
{synopt:{opt ci(method)}}{cmd:exact} (default), {cmd:poisson}, or {cmd:cluster(}{it:varname}{cmd:)}{p_end}
{synopt:{opt l:evel(#)}}confidence level; default {cmd:c(level)}{p_end}
{synopt:{opt small:cells(#)}}mask 1 to #-1 events as {cmd:<}#{p_end}
{synopt:{opt nosmall:cells}}ignore the session smallcells default{p_end}

{syntab:Format}
{synopt:{opt dig:its(#)}}decimal places of rates; default 1{p_end}
{synopt:{opt cf:ormat(%fmt)}}format of rate and limits{p_end}
{synopt:{opt sep(string)}}separator between the limits; default {cmd:", "}{p_end}
{synopt:{opt pyd:igits(#)}}decimal places of person-time; default 0{p_end}
{synopt:{opt outl:abels(string)}}outcome labels separated by {cmd:\}{p_end}
{synopt:{opt expl:abels(string)}}section labels separated by {cmd:\}{p_end}
{synopt:{opt unit:label(string)}}rate unit in the header{p_end}

{syntab:Output}
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
is left out of that variable's table only; the other grouping variables keep
it, as {cmd:strate} run one variable at a time would.


{marker options}{...}
{title:Options}

{dlgtab:Data}

{phang}
{opt events(varlist)} names nonnegative integer event counts (0/1 indicators or
counts), one variable per outcome; each becomes a column group.
{opt exposure(varname)} names the person-time of each observation. Give both,
or neither for {cmd:stset} data. Negative person-time, non-integer counts,
and events without person-time are refused.

{dlgtab:Rates}

{phang}
{opt per(#)} scales the rates; {cmd:per(1000)} gives rates per 1,000
person-years when person-time is in years.

{phang}
{opt pyscale(#)} divides person-time before display, rate computation and
{cmd:r(estimates)}, so the person-time column is in the scaled unit;
{cmd:pyscale(365.25)} turns days into years.

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
{opt smallcells(#)} prints an event count from 1 to #-1 as {cmd:<}# and
withholds that cell's person-time and rate ({cmd:–}). Zero is printed. It
governs printed output only; {cmd:r()} keeps the numbers. Masking is primary
only: with several grouping variables over one sample, a masked count can be
recovered from another variable's totals. Without it, a
session default set by {cmd:tabtools set smallcells #} applies and is echoed
in the log; {opt nosmallcells} ignores that default.

{dlgtab:Format}

{phang}
{opt digits(#)} sets the decimal places of the rate and its limits.
{opt cformat(%fmt)} instead applies any numeric display format (for example
{cmd:%9.1fc}); string and date formats are refused.

{phang}
{opt sep(string)} separates the two limits in every output (console, Excel,
CSV, Markdown, and frame).

{phang}
{opt outlabels()}, {opt explabels()}, and {opt unitlabel()} label the outcome
column groups, the sections, and the rate header. The defaults are the
variable labels (or names) and {it:per()}.

{dlgtab:Output}

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


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:ratetab} stores the results of {helpb stratetab} ({cmd:r(rates)}, {cmd:r(ci_level)},
{cmd:r(smallcells)}, {cmd:r(N_rows)}, output paths, and so on) and also:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations used{p_end}
{synopt:{cmd:r(per)}}rate multiplier{p_end}
{synopt:{cmd:r(level)}}confidence level{p_end}
{synopt:{cmd:r(N_zero)}}cells with no events{p_end}
{synopt:{cmd:r(N_noci)}}cells without a clustered interval{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(ci_method)}}{cmd:exact}, {cmd:poisson}, or {cmd:cluster}{p_end}
{synopt:{cmd:r(cluster)}}cluster variable{p_end}
{synopt:{cmd:r(methods)}}methods sentence{p_end}

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
Ulm K. 1990. A simple method to calculate the confidence interval of a standardized mortality ratio (SMR). American Journal of Epidemiology 131: 373-375.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{helpb stratetab}, {helpb comptab}, {helpb strate}, {helpb tabtools}
{p_end}

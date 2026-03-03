{smcl}
{* *! version 1.0.5  04mar2026}{...}
{viewerjumpto "Syntax" "nma_forest##syntax"}{...}
{viewerjumpto "Description" "nma_forest##description"}{...}
{viewerjumpto "Options" "nma_forest##options"}{...}
{viewerjumpto "Display logic" "nma_forest##display"}{...}
{viewerjumpto "Examples" "nma_forest##examples"}{...}
{viewerjumpto "Stored results" "nma_forest##results"}{...}
{viewerjumpto "Author" "nma_forest##author"}{...}

{title:Title}

{phang}
{bf:nma_forest} {hline 2} Evidence decomposition forest plot for network meta-analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_forest}
[{cmd:,} {it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Evidence}
{synopt:{opt eform}}exponentiate estimates (OR, RR, HR scale){p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt comp:arisons(type)}}which pairs to show; {it:all} (default) or {it:mixed}{p_end}

{syntab:Display}
{synopt:{opt textcol}}show numeric estimates beside each row{p_end}
{synopt:{opt dp(#)}}decimal places for text column; default is {cmd:2}{p_end}
{synopt:{opt colors(colorlist)}}colors for direct, indirect, network{p_end}
{synopt:{opt diamond}}use diamond shape for network estimates{p_end}

{syntab:Graph}
{synopt:{opt xla:bel(numlist)}}custom x-axis tick values{p_end}
{synopt:{opt xti:tle(string)}}custom x-axis title{p_end}
{synopt:{opt ti:tle(string)}}custom graph title{p_end}
{synopt:{opt scheme(string)}}graph scheme; default is {cmd:plotplainblind}{p_end}
{synopt:{opt saving(filename)}}save graph to file{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt name(string)}}name the graph window{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_forest} creates an evidence decomposition forest plot showing
{bf:Direct}, {bf:Indirect}, and {bf:Network} estimates grouped by comparison
pair. Each group has a bold header identifying the two treatments, with
evidence rows indented below.

{pstd}
All evidence types are shown as circles with confidence interval spikes
(in different colors). The {opt diamond} option renders Network estimates
as diamond shapes instead. A dashed vertical line marks the null effect
(0 for differences, 1 for ratios).


{marker display}{...}
{title:Display logic}

{pstd}
The rows shown for each comparison depend on the evidence type:

{p2colset 8 28 30 2}{...}
{p2col:Evidence type}Rows displayed{p_end}
{p2line}
{p2col:Direct only}Direct + Network{p_end}
{p2col:Indirect only}Indirect{p_end}
{p2col:Mixed}Direct + Indirect + Network{p_end}
{p2line}

{pstd}
For indirect-only comparisons, the network estimate equals the indirect
estimate, so only one row is shown. For mixed-evidence comparisons, the
indirect estimate is back-calculated from the network and direct estimates
using inverse-variance weights.


{marker options}{...}
{title:Options}

{dlgtab:Evidence}

{phang}
{opt eform} displays results on the exponentiated scale. Appropriate when
the outcome measure is log OR, log RR, log IRR, or log HR. Point estimates
and confidence intervals are exponentiated; the null reference line is
drawn at 1 instead of 0.

{phang}
{opt level(#)} specifies the confidence level for intervals. Default is 95.

{phang}
{opt comparisons(type)} selects which comparison pairs to display.
{opt all} (the default) shows every pair with any evidence.
{opt mixed} shows only pairs with both direct and indirect evidence,
useful for focusing on pairs where decomposition is most informative.

{dlgtab:Display}

{phang}
{opt textcol} adds a text column to the right of each estimate showing
the numeric value and confidence interval, formatted as
"est (lo, hi)".

{phang}
{opt dp(#)} sets the number of decimal places in the text column.
Default is 2. Range: 0 to 6.

{phang}
{opt colors(colorlist)} specifies up to three Stata colors for direct,
indirect, and network estimates (in that order). Defaults are
{cmd:forest_green}, {cmd:dkorange}, and {cmd:navy}. Partial specification
is allowed; unspecified colors retain their defaults.

{phang}
{opt diamond} renders Network estimates as diamond shapes instead of circles
with CI spikes. By default, all evidence types use the same circle+spike
style, differentiated only by color.

{dlgtab:Graph}

{phang}
{opt xlabel(numlist)} specifies custom x-axis tick values. If omitted,
Stata chooses automatically.

{phang}
{opt xtitle(string)} specifies a custom x-axis title. If omitted, the
title is derived from the outcome measure (e.g., "Mean Difference",
"Odds Ratio").

{phang}
{opt title(string)} specifies a custom graph title. Default is
"Evidence Decomposition Forest Plot".

{phang}
{opt scheme(string)} specifies the graph scheme. Default is
{cmd:plotplainblind}.

{phang}
{opt saving(filename)} saves the graph to {it:filename}.

{phang}
{opt replace} allows {opt saving()} to overwrite an existing file.

{phang}
{opt name(string)} assigns a name to the graph window.


{marker examples}{...}
{title:Examples}

{pstd}Setup: fit a network meta-analysis first{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str12 study str15 treatment events total}{p_end}
{phang2}{cmd:. "S1" "A" 10 100}{p_end}
{phang2}{cmd:. "S1" "B" 15 100}{p_end}
{phang2}{cmd:. "S2" "A" 12 110}{p_end}
{phang2}{cmd:. "S2" "C" 20 105}{p_end}
{phang2}{cmd:. "S3" "B" 18 95}{p_end}
{phang2}{cmd:. "S3" "C" 22 100}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. nma_setup events total, studyvar(study) trtvar(treatment) ref(A)}{p_end}
{phang2}{cmd:. nma_fit, nolog}{p_end}

{pstd}Basic evidence decomposition forest plot{p_end}
{phang2}{cmd:. nma_forest}{p_end}

{pstd}With text column showing numeric estimates{p_end}
{phang2}{cmd:. nma_forest, textcol}{p_end}

{pstd}Show only mixed-evidence comparisons{p_end}
{phang2}{cmd:. nma_forest, comparisons(mixed)}{p_end}

{pstd}Custom colors and 3 decimal places{p_end}
{phang2}{cmd:. nma_forest, colors(cranberry teal black) textcol dp(3)}{p_end}

{pstd}Save to file{p_end}
{phang2}{cmd:. nma_forest, saving(forest.gph) replace}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:nma_forest} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(n_comparisons)}}number of comparison pairs displayed{p_end}
{synopt:{cmd:r(n_direct)}}pairs with direct evidence only{p_end}
{synopt:{cmd:r(n_indirect)}}pairs with indirect evidence only{p_end}
{synopt:{cmd:r(n_mixed)}}pairs with mixed evidence{p_end}

{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(ref)}}reference treatment{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}

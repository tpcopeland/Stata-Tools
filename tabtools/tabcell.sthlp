{smcl}
{viewerjumpto "Syntax" "tabcell##syntax"}{...}
{viewerjumpto "Description" "tabcell##description"}{...}
{viewerjumpto "Options" "tabcell##options"}{...}
{viewerjumpto "Remarks" "tabcell##remarks"}{...}
{viewerjumpto "Examples" "tabcell##examples"}{...}
{viewerjumpto "Stored results" "tabcell##stored"}{...}
{viewerjumpto "Author" "tabcell##author"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "outtab" "help outtab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{title:Title}

{phang}
{bf:tabcell} {hline 2} Format one publication cell: estimate (CI), p-value, count, n (%), e/n (%), or median (Q1, Q3)


{marker syntax}{...}
{title:Syntax}

{pstd}Estimate with its confidence interval{p_end}

{p 8 17 2}
{cmd:tabcell est} [{it:coef}]
[{cmd:,} {it:source} {opt eform} {opt scale(#)} {opt f:ormat(%fmt)} {opt sep(string)} {opt l:evel(#)} {opt miss:ing(text)}]

{pstd}where {it:source} is one of{p_end}

{p2colset 9 32 34 2}{...}
{p2col:{it:coef}}a coefficient of the active estimation results{p_end}
{p2col:{opt lin:com}}the results of the last {helpb lincom}{p_end}
{p2col:{opt nl:com}}the results of the last {helpb nlcom}; {it:coef} names the column{p_end}
{p2col:{opt mat:rix(M row)}}a row of a matrix, such as {cmd:matrix(r(table)' mpg)}{p_end}
{p2col:{opt b(#)} {opt ll(#)} {opt ul(#)}}explicit numbers{p_end}
{p2col:{opt b(#)} {opt se(#)}}an estimate and its standard error{p_end}
{p2colreset}{...}

{pstd}p-value, counts, and quartiles{p_end}

{p 8 17 2}
{cmd:tabcell p} {cmd:,} {opt p(#)} [{opt pdp(#)} {opt highpdp(#)} {opt psty:le(table|footnote)} {opt miss:ing(text)}]

{p 8 17 2}
{cmd:tabcell n} {cmd:,} {opt n(#)} [{opt min:cell(#)} {opt nf:ormat(%fmt)} {opt miss:ing(text)}]

{p 8 17 2}
{cmd:tabcell np} {cmd:,} {opt n(#)} {opt d(#)} [{opt min:cell(#)} {opt nf:ormat(%fmt)} {opt pf:ormat(%fmt)} {opt miss:ing(text)}]

{p 8 17 2}
{cmd:tabcell enp} {cmd:,} {opt e(#)} {opt n(#)} [{opt min:cell(#)} {opt nf:ormat(%fmt)} {opt pf:ormat(%fmt)} {opt miss:ing(text)}]

{p 8 17 2}
{cmd:tabcell iqr} {cmd:,} {opt med:ian(#)} {opt q1(#)} {opt q3(#)} [{opt f:ormat(%fmt)} {opt sep(string)} {opt miss:ing(text)}]

{pstd}Column form{p_end}

{p 8 17 2}
{cmd:tabcell} {it:form} {ifin} {cmd:,} {opt gen:erate(newvar)} {it:options}

{pstd}
With {opt generate()}, every numeric option ({opt b()}, {opt ll()}, {opt ul()},
{opt se()}, {opt p()}, {opt n()}, {opt d()}, {opt e()}, {opt median()},
{opt q1()}, {opt q3()}) is an expression in the data, evaluated row by row.


{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Source ({cmd:est})}
{synopt:{opt lin:com}}use the last {cmd:lincom}{p_end}
{synopt:{opt nl:com}}use the last {cmd:nlcom}{p_end}
{synopt:{opt mat:rix(M row)}}use a row of a matrix{p_end}
{synopt:{opt col:s(# # #)}}columns of the estimate and limits in {opt matrix()}{p_end}
{synopt:{opt b(#)}}estimate{p_end}
{synopt:{opt ll(#)}}lower limit{p_end}
{synopt:{opt ul(#)}}upper limit{p_end}
{synopt:{opt se(#)}}standard error, for a normal interval around {opt b()}{p_end}

{syntab:Numbers}
{synopt:{opt p(#)}}p-value ({cmd:p}){p_end}
{synopt:{opt n(#)}}count ({cmd:n}, {cmd:np}) or total ({cmd:enp}){p_end}
{synopt:{opt d(#)}}denominator ({cmd:np}){p_end}
{synopt:{opt e(#)}}events ({cmd:enp}){p_end}
{synopt:{opt med:ian(#)}}median ({cmd:iqr}){p_end}
{synopt:{opt q1(#)}}first quartile ({cmd:iqr}){p_end}
{synopt:{opt q3(#)}}third quartile ({cmd:iqr}){p_end}

{syntab:Format}
{synopt:{opt eform}}exponentiate the estimate and both limits{p_end}
{synopt:{opt scale(#)}}multiply estimate and limits by # ({cmd:est}){p_end}
{synopt:{opt f:ormat(%fmt)}}format of estimate and limits; default {cmd:%9.2f}{p_end}
{synopt:{opt cf:ormat(%fmt)}}synonym for {opt format()}{p_end}
{synopt:{opt sep(string)}}separator between the limits; default {cmd:", "}{p_end}
{synopt:{opt l:evel(#)}}confidence level{p_end}
{synopt:{opt pdp(#)}}decimal places for p < 0.10; default 3{p_end}
{synopt:{opt highpdp(#)}}decimal places for p >= 0.10; default 2{p_end}
{synopt:{opt psty:le(style)}}{cmd:table} (default, {cmd:0.012}) or {cmd:footnote} ({cmd:p = 0.012}){p_end}
{synopt:{opt nf:ormat(%fmt)}}format of counts; default {cmd:%12.0fc}{p_end}
{synopt:{opt pf:ormat(%fmt)}}format of percentages; default {cmd:%4.1f}{p_end}
{synopt:{opt min:cell(#)}}print counts from 1 to #-1 as {cmd:<}#{p_end}
{synopt:{opt miss:ing(text)}}text for a missing or non-finite value{p_end}
{synopt:{opt gen:erate(newvar)}}fill a new string variable{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tabcell} turns numbers into the text of one table cell and returns it in
{cmd:r(cell)}, for tables that are assembled by hand and finished with
{helpb puttab}. {cmd:tabcell est} prints {it:estimate} ({it:lower}{it:sep}{it:upper}),
for example {cmd:1.23 (1.01, 1.50)} or, with {cmd:sep(" to ")}, {cmd:1.23 (1.01 to 1.50)}.
{cmd:tabcell p} prints a p-value with exactly the text {helpb regtab} prints
for the same p-value, {opt pdp()}, and {opt highpdp()}, or, with
{cmd:pstyle(footnote)}, the same number in prose form ({cmd:p = 0.012}).
{cmd:tabcell n} prints a count with thousands separators ({cmd:12,345}),
{cmd:tabcell np} prints {it:n} ({it:%}), {cmd:tabcell enp} prints
{it:e}/{it:n} ({it:%}), and {cmd:tabcell iqr} prints {it:median} ({it:Q1}, {it:Q3}).

{pstd}
{cmd:tabcell} never changes the data in memory unless {opt generate()} is
given. With {opt generate()} it fills a new string variable from numeric
variables in one vectorised pass, so a column of cells needs no loop.

{pstd}
A cell whose number is missing or not finite is refused with error 459,
unless {opt missing()} names the text to print instead. A failed or
non-estimable fit therefore cannot appear in a table as {cmd:. (., .)}.


{marker options}{...}
{title:Options}

{dlgtab:Source}

{phang}
{it:coef} names a coefficient of the active estimation results, as in
{cmd:_b[}{it:coef}{cmd:]}. The interval is {cmd:_b} -/+ q {cmd:_se}, where q is the
t quantile with {cmd:e(df_r)} degrees of freedom when the model stores it and
the normal quantile otherwise, the same interval {cmd:r(table)} reports. An
omitted or base term (standard error 0) is not an estimate and is refused
unless {opt missing()} is given.

{phang}
{opt lincom} uses the results of the last {cmd:lincom}: {cmd:r(lb)} and
{cmd:r(ub)} when {opt level()} is not given or equals {cmd:r(level)}, otherwise
an interval from {cmd:r(estimate)} and {cmd:r(se)} with {cmd:r(df)} degrees of
freedom when {cmd:lincom} stored them. Run it immediately after
{cmd:lincom}. After a plain {cmd:lincom}, add {opt eform} here for a ratio.
{cmd:lincom, eform} (or {cmd:or}, {cmd:irr}, {cmd:hr}) stores the
exponentiated estimate and limits; they are printed as stored, an interval at
another {opt level()} is computed on the coefficient scale, and adding
{opt eform} is an error (it would exponentiate twice). Because
{cmd:tabcell} replaces {cmd:r()}, it hands {cmd:lincom}'s results back (see
{it:Stored results}), including the p-value in {cmd:r(p)}. Results left by an
earlier {cmd:tabcell} are refused (error 301) rather than read as
{cmd:lincom}'s.

{phang}
{opt nlcom} uses {cmd:r(b)} and {cmd:r(V)} of the last {cmd:nlcom}; {it:coef}
names the result (default: the first).

{phang}
{opt matrix(M row)} reads one row of a matrix or matrix expression; {it:row}
is a row name or number. The columns named {cmd:b}, {cmd:ll}, and {cmd:ul} are
used, as in {cmd:r(table)'}, unless {opt cols(# # #)} gives the column
numbers of the estimate, lower, and upper limit. The values are printed as
stored, so {opt level()} is not allowed.

{phang}
{opt b(#)}, {opt ll(#)}, and {opt ul(#)} give the numbers directly; {opt se(#)}
in place of {opt ll()} and {opt ul()} gives a normal interval at
{opt level()}. Without {opt generate()} each is a number or scalar expression;
naming a variable is refused, because a variable name would silently read the
first observation.

{dlgtab:Format}

{phang}
{opt eform} exponentiates the estimate and both limits before printing.

{phang}
{opt scale(#)} multiplies the estimate and both limits by #, a positive
number, after {opt eform}; {cmd:scale(1000)} prints a rate per person-year as a
rate per 1,000 person-years. It belongs to {cmd:tabcell est} only and is
refused by the other forms (a p-value, count, or percentage has no scale).
{cmd:r(estimate)}, {cmd:r(lb)}, and {cmd:r(ub)} are the scaled numbers, and
{cmd:r(scale)} records #. The interval is scaled, not recomputed, so
{opt level()} and {opt se()} work as without {opt scale()}.

{phang}
{opt format(%fmt)} is any Stata numeric display format, applied to the
estimate and both limits (or the median and quartiles); {cmd:%12.0fc} prints
thousands separators. String and date formats are refused. The printed
numbers are trimmed of padding. {opt cformat()} is a synonym.

{phang}
{opt sep(string)} separates the two limits; the default is {cmd:", "}.

{phang}
{opt level(#)} sets the confidence level; the default is {cmd:c(level)}, or
{cmd:r(level)} with {opt lincom}.

{phang}
{opt pdp(#)} and {opt highpdp(#)} set the decimal places of p-values below and
at or above 0.10, as in {helpb regtab}. p-values below 10^-{it:pdp} print as
{cmd:<0.001} (for {cmd:pdp(3)}), and values above 1-10^-{it:highpdp} and below
1 print as {cmd:>0.99}. A p-value outside [0, 1] is refused.

{phang}
{opt pstyle(style)} chooses how {cmd:tabcell p} writes the p-value.
{cmd:pstyle(table)}, the default, prints the bare table text ({cmd:0.012},
{cmd:<0.001}, {cmd:>0.99}). {cmd:pstyle(footnote)} prints it for running text
or a footnote: {cmd:p = 0.012}, {cmd:p < 0.001}, {cmd:p > 0.99}. The number
is the same in both styles, so {opt pdp()} and {opt highpdp()} apply to both.

{phang}
{opt nformat(%fmt)} and {opt pformat(%fmt)} format the counts and the
percentage of {cmd:np} and {cmd:enp}; {opt nformat()} also formats the count of
{cmd:tabcell n} (default {cmd:%12.0fc}, as in {helpb table1_tc}, so 12345 prints
as {cmd:12,345}). The percentage is omitted when the denominator is 0.
Negative counts and counts larger than their total are refused.

{phang}
{opt mincell(#)} prints a count from 1 to #-1 as {cmd:<}#, without its
percentage; {cmd:tabcell n} masks its count the same way. In {cmd:enp}, a masked event count keeps its total
({cmd:<5/40}), and a masked total masks the whole cell ({cmd:<5}). Zero is
printed. This masks printed counts only; it is not complementary
suppression.

{phang}
{opt missing(text)} prints {it:text} for a missing or non-finite number
instead of refusing it, for example {cmd:missing("did not converge")}.
{cmd:missing("")} gives an empty cell: {cmd:r(cell)} is empty and
{cmd:r(missing)} is 1, and with {opt generate()} those rows are left empty.

{phang}
{opt generate(newvar)} creates the string variable {it:newvar}; {ifin}
restricts the rows filled, and other rows are left empty.


{marker remarks}{...}
{title:Remarks}

{pstd}
Scalar and column forms use one renderer, so {cmd:r(cell)} and a
{opt generate()} column cannot disagree. {cmd:tabcell p} uses a copy of
{helpb regtab}'s p-value rule; the package QA compares the two over a grid of
p-values.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. logit foreign mpg weight}{p_end}
{phang2}{cmd:. tabcell est mpg, eform format(%4.2f) sep(" to ")}{p_end}
{phang2}{cmd:. lincom mpg + weight}{p_end}
{phang2}{cmd:. tabcell est, lincom eform}{p_end}
{phang2}{cmd:. quietly logit foreign mpg weight}{p_end}
{phang2}{cmd:. tabcell est, matrix(r(table)' weight) format(%6.4f)}{p_end}
{phang2}{cmd:. tabcell p, p(0.0499)}{p_end}
{phang2}{cmd:. tabcell p, p(0.0123) pstyle(footnote)}{p_end}
{phang2}{cmd:. tabcell n, n(12345)}{p_end}
{phang2}{cmd:. tabcell est, b(0.0213) ll(0.0110) ul(0.0372) scale(1000) format(%5.1f)}{p_end}
{phang2}{cmd:. tabcell np, n(3) d(40) mincell(5)}{p_end}
{phang2}{cmd:. tabcell enp, e(12) n(74)}{p_end}
{phang2}{cmd:. tabcell iqr, median(20) q1(18) q3(25) format(%4.0f)}{p_end}
{phang2}{cmd:. tabcell est, b(.) ll(.) ul(.) missing("did not converge")}{p_end}

{pstd}A column of cells from numeric variables{p_end}

{phang2}{cmd:. generate double lo = price * 0.9}{p_end}
{phang2}{cmd:. generate double hi = price * 1.1}{p_end}
{phang2}{cmd:. tabcell est, b(price) ll(lo) ul(hi) format(%12.0fc) generate(price_ci)}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
Without {opt generate()}, {cmd:tabcell} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(missing)}}1 if the cell printed the {opt missing()} text{p_end}
{synopt:{cmd:r(estimate)}}estimate as printed (after {opt eform} and {opt scale()}) ({cmd:est}){p_end}
{synopt:{cmd:r(lb)}}lower limit ({cmd:est}){p_end}
{synopt:{cmd:r(ub)}}upper limit ({cmd:est}){p_end}
{synopt:{cmd:r(level)}}confidence level ({cmd:est}; not {opt matrix()} or {opt ll()}/{opt ul()}){p_end}
{synopt:{cmd:r(scale)}}multiplier given in {opt scale()}{p_end}

{pstd}
With {opt lincom}, {cmd:lincom}'s own scalars are returned as well: those
whose names {cmd:tabcell} does not use under their {cmd:lincom} names
({cmd:r(p)}, {cmd:r(se)}, {cmd:r(df)}, and {cmd:r(t)} or {cmd:r(z)}), and
{cmd:lincom}'s {cmd:r(estimate)}, {cmd:r(lb)}, {cmd:r(ub)}, and {cmd:r(level)}
as {cmd:r(lincom_estimate)}, {cmd:r(lincom_lb)}, {cmd:r(lincom_ub)}, and
{cmd:r(lincom_level)}, because {cmd:tabcell}'s own {cmd:r(estimate)},
{cmd:r(lb)}, {cmd:r(ub)}, and {cmd:r(level)} are the numbers as printed (after
{opt eform}, {opt scale()}, or another {opt level()}).

{synoptset 20 tabbed}{...}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(cell)}}the cell text{p_end}
{synopt:{cmd:r(form)}}{cmd:est}, {cmd:p}, {cmd:n}, {cmd:np}, {cmd:enp}, or {cmd:iqr}{p_end}
{synopt:{cmd:r(source)}}{cmd:e()}, {cmd:lincom}, {cmd:nlcom}, {cmd:matrix}, or {cmd:numbers} ({cmd:est}){p_end}

{pstd}
With {opt generate()}, it stores {cmd:r(N)} (rows rendered), {cmd:r(N_missing)}
(rows given the {opt missing()} text), {cmd:r(varname)}, and {cmd:r(form)}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{helpb regtab}, {helpb outtab}, {helpb puttab}, {helpb tabtools}
{p_end}

{smcl}
{viewerjumpto "Syntax" "tabcell##syntax"}{...}
{viewerjumpto "Description" "tabcell##description"}{...}
{viewerjumpto "Options" "tabcell##options"}{...}
{viewerjumpto "Remarks" "tabcell##remarks"}{...}
{viewerjumpto "Examples" "tabcell##examples"}{...}
{viewerjumpto "Stored results" "tabcell##stored"}{...}
{viewerjumpto "References" "tabcell##references"}{...}
{viewerjumpto "Author" "tabcell##author"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "outtab" "help outtab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{title:Title}

{phang}
{bf:tabcell} {hline 2} Format one publication cell: estimate (CI), p-value, count, n (%), e/n (%), median (Q1, Q3), or rate (CI)


{marker syntax}{...}
{title:Syntax}

{pstd}Estimate with its confidence interval{p_end}

{p 8 17 2}
{cmd:tabcell est} [{it:coef}]
[{cmd:,} {it:source} {opt eform} {opt scale(#)} {opt f:ormat(%fmt)} {opt dig:its(#)}
{opt sep(string)} {opt l:evel(#)} {opt miss:ing(text)} {it:store}]

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
{cmd:tabcell p} {cmd:,} {opt p(#)} [{opt pdp(#)} {opt highpdp(#)}
{opt psty:le(table|footnote|Pfootnote)} {opt miss:ing(text)} {it:store}]

{p 8 17 2}
{cmd:tabcell n} {cmd:,} {opt n(#)} [{opt min:cell(#)} {opt nf:ormat(%fmt)} {opt miss:ing(text)} {it:store}]

{p 8 17 2}
{cmd:tabcell np} {cmd:,} {opt n(#)} {opt d(#)} [{opt ci(exact)} {opt l:evel(#)} {opt sep(string)}
{opt noc:ount} {opt min:cell(#)} {opt nf:ormat(%fmt)} {opt pf:ormat(%fmt)} {opt miss:ing(text)}
{it:store}]

{p 8 17 2}
{cmd:tabcell enp} {cmd:,} {opt e(#)} {opt n(#)} [{opt min:cell(#)} {opt nf:ormat(%fmt)}
{opt pf:ormat(%fmt)} {opt miss:ing(text)} {it:store}]

{p 8 17 2}
{cmd:tabcell iqr} {cmd:,} {opt med:ian(#)} {opt q1(#)} {opt q3(#)} [{opt f:ormat(%fmt)}
{opt dig:its(#)} {opt sep(string)} {opt miss:ing(text)} {it:store}]

{pstd}Incidence rate with its confidence interval{p_end}

{p 8 17 2}
{cmd:tabcell rate} {cmd:,} {opt e(#)} {opt pt(#)} {opt per(#)} [{opt ci(exact|poisson)}
{opt l:evel(#)} {opt f:ormat(%fmt)} {opt dig:its(#)} {opt sep(string)} {opt min:cell(#)}
{opt miss:ing(text)} {it:store}]

{pstd}where {it:store} is {opt loc:al(name)} and/or {opt glob:al(name)}{p_end}

{pstd}Column form{p_end}

{p 8 17 2}
{cmd:tabcell} {it:form} {ifin} {cmd:,} {opt gen:erate(newvar)} {it:options}

{pstd}
With {opt generate()}, every numeric option ({opt b()}, {opt ll()}, {opt ul()},
{opt se()}, {opt p()}, {opt n()}, {opt d()}, {opt e()}, {opt pt()},
{opt median()}, {opt q1()}, {opt q3()}) is an expression in the data,
evaluated row by row; {opt per()} stays a number.


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
{synopt:{opt e(#)}}events ({cmd:enp}, {cmd:rate}){p_end}
{synopt:{opt pt(#)}}person-time ({cmd:rate}){p_end}
{synopt:{opt per(#)}}rate per # units of person-time ({cmd:rate}){p_end}
{synopt:{opt med:ian(#)}}median ({cmd:iqr}){p_end}
{synopt:{opt q1(#)}}first quartile ({cmd:iqr}){p_end}
{synopt:{opt q3(#)}}third quartile ({cmd:iqr}){p_end}

{syntab:Format}
{synopt:{opt eform}}exponentiate the estimate and both limits{p_end}
{synopt:{opt scale(#)}}multiply estimate and limits by # ({cmd:est}){p_end}
{synopt:{opt f:ormat(%fmt)}}format of estimate and limits; see below{p_end}
{synopt:{opt cf:ormat(%fmt)}}synonym for {opt format()}{p_end}
{synopt:{opt dig:its(#)}}{opt format(%9.#f)}; # from 0 to 10{p_end}
{synopt:{opt sep(string)}}separator between the limits; default {cmd:", "}{p_end}
{synopt:{opt l:evel(#)}}confidence level ({cmd:est}, {cmd:rate}; {cmd:np} with {opt ci()}){p_end}
{synopt:{opt ci(exact)}}exact (Clopper-Pearson) interval ({cmd:np}){p_end}
{synopt:{opt ci(exact|poisson)}}rate interval; default {cmd:exact} ({cmd:rate}){p_end}
{synopt:{opt noc:ount}}the percentage without its count ({cmd:np}){p_end}
{synopt:{opt pdp(#)}}decimal places for p < 0.10; default 3{p_end}
{synopt:{opt highpdp(#)}}decimal places for p >= 0.10; default 2{p_end}
{synopt:{opt psty:le(style)}}{cmd:table}, {cmd:footnote}, or {cmd:Pfootnote}{p_end}
{synopt:{opt nf:ormat(%fmt)}}format of counts; default {cmd:%12.0fc}{p_end}
{synopt:{opt pf:ormat(%fmt)}}format of percentages; default {cmd:%4.1f}{p_end}
{synopt:{opt min:cell(#)}}withhold counts from 1 to #-1{p_end}
{synopt:{opt miss:ing(text)}}text for a missing or non-finite value{p_end}
{synopt:{opt gen:erate(newvar)}}fill a new string variable{p_end}

{syntab:Store}
{synopt:{opt loc:al(name)}}also store the cell text in local macro {it:name}{p_end}
{synopt:{opt glob:al(name)}}also store the cell text in global macro {it:name}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tabcell} turns numbers into the text of one table cell and returns it in
{cmd:r(cell)}, for tables that are assembled by hand and finished with
{helpb puttab}. {cmd:tabcell est} prints {it:estimate} ({it:lower}{it:sep}{it:upper}),
for example {cmd:1.23 (1.01, 1.50)} or, with {cmd:sep(" to ")}, {cmd:1.23 (1.01 to 1.50)}. {cmd:tabcell p}
prints a p-value with exactly the text {helpb regtab} prints
for the same p-value, {opt pdp()}, and {opt highpdp()}, or, with
{cmd:pstyle(footnote)}, the same number in prose form ({cmd:p = 0.012}). {cmd:tabcell n}
prints a count with thousands separators ({cmd:12,345}),
{cmd:tabcell np} prints {it:n} ({it:%}), {cmd:tabcell enp} prints
{it:e}/{it:n} ({it:%}), and {cmd:tabcell iqr} prints {it:median} ({it:Q1}, {it:Q3}). With
{cmd:ci(exact)}, {cmd:tabcell np} adds the exact binomial confidence interval of
the percentage: {it:n} ({it:%}; {it:lower}, {it:upper}), or, with {opt nocount},
{it:%} ({it:lower}, {it:upper}) alone. {cmd:tabcell rate} prints an incidence
rate with its confidence interval, {it:rate} ({it:lower}, {it:upper}), for
example {cmd:12.3 (6.4, 21.5)} for 12 events in 975.6 person-years per 1,000,
with the intervals {helpb ratetab} uses.

{pstd}
{opt local()} and {opt global()} store the cell text in a macro as well, so a
cell is produced and kept in one
line: {cmd:tabcell n, n(`=r(N)') local(c_n)}.

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
{cmd:lincom}. After a plain {cmd:lincom}, add {opt eform} here for a
ratio. {cmd:lincom, eform} (or {cmd:or}, {cmd:irr}, {cmd:hr}) stores the
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
{opt level()}. Without {opt generate()} each is a number or scalar expression; naming
a variable is refused, because a variable name would silently read the
first observation.

{dlgtab:Format}

{phang}
{opt eform} exponentiates the estimate and both limits before printing.

{phang}
{opt scale(#)} multiplies the estimate and both limits by #, a positive
number, after {opt eform}; {cmd:scale(1000)} prints a rate per person-year as a
rate per 1,000 person-years. It belongs to {cmd:tabcell est} only and is
refused by the other forms (a p-value, count, or percentage has no
scale). {cmd:r(estimate)}, {cmd:r(lb)}, and {cmd:r(ub)} are the scaled numbers, and
{cmd:r(scale)} records #. The interval is scaled, not recomputed, so
{opt level()} and {opt se()} work as without {opt scale()}.

{phang}
{opt format(%fmt)} is any Stata numeric display format, applied to the
estimate and both limits (or the median and quartiles, or the rate and its
limits); {cmd:%12.0fc} prints thousands separators. The default is
{cmd:%9.2f}, and {cmd:%9.1f} for {cmd:tabcell rate}. String and date formats are refused. The printed
numbers are trimmed of padding. {opt cformat()} is a synonym.

{phang}
{opt digits(#)} is shorthand for {cmd:format(%9.}{it:#}{cmd:f)}, # from 0 to 10,
for the forms that take {opt format()} ({cmd:est}, {cmd:iqr}, and
{cmd:rate}); it may not be combined with {opt format()}.

{phang}
{opt sep(string)} separates the two limits; the default is {cmd:", "}. It
applies to {cmd:est}, {cmd:iqr}, {cmd:rate}, and {cmd:np} with {opt ci()}, and
prints as typed in the cell, {cmd:r(cell)}, {opt local()}, {opt global()}, and
{opt generate()}; see {help tabtools##sep:interval separators}.

{phang}
{opt level(#)} sets the confidence level; the default is {cmd:c(level)}, or
{cmd:r(level)} with {opt lincom}. {cmd:tabcell np} takes {opt level()} only
with {opt ci()}.

{phang}
{opt ci(exact)} adds to {cmd:tabcell np} the exact binomial (Clopper-Pearson)
confidence interval of the percentage {it:n}/{it:d}, printed after a semicolon
in the format of the percentage
({opt pformat()}): {cmd:2 (10.0; 1.2, 31.7)}. The limits are the beta quantiles
B(a/2; n, d-n+1) and B(1-a/2; n+1, d-n), a = 1 - {opt level()}/100,
computed with {cmd:invibeta()} and {cmd:invibetatail()}; when n = 0 the lower
limit is 0, and when n = d the upper limit is 100, exactly as
{cmd:cii proportions} {it:d} {it:n}{cmd:, exact} computes them (it then labels
the interval one-sided at 1 - a/2; {cmd:tabcell} prints the same numbers). The
interval needs whole-number counts: a non-integer {opt n()} or {opt d()}
is refused (error 459), as is a cell whose interval cannot be computed. A cell
whose denominator is 0 prints no percentage and no interval, and a cell masked
by {opt mincell()} prints {cmd:<}# only; {cmd:r(lb)} and {cmd:r(ub)} are then
missing. The interval is conservative: its
coverage is at least the nominal level (see {helpb ci}).

{phang}
{opt nocount} prints the percentage of {cmd:tabcell np} without the count
in front of it: {cmd:10.0}, or with {cmd:ci(exact)} {cmd:10.0 (1.2, 31.7)}, the
interval separated by {opt sep()}. A cell whose denominator is 0 has nothing
to print and is refused (error 459) unless {opt missing()} gives its text. With
{opt mincell()}, a cell whose count is masked prints {cmd:–} (an en dash)
and no number: the percentage, and the interval limits, of a known
denominator give the count back. {cmd:r(pct)}, {cmd:r(lb)}, and {cmd:r(ub)}
are then missing. It works with {opt generate()}, {opt local()}, and
{opt global()} as the other forms do.

{phang}
{opt e(#)}, {opt pt(#)}, and {opt per(#)} give {cmd:tabcell rate} its events,
person-time, and the unit of the rate: the rate is {it:e}/{it:pt} x {it:per},
so {cmd:per(1000)} with person-time in years prints the rate per 1,000
person-years. {opt per()} is required and is a positive number, also with
{opt generate()}. Events and person-time must be nonnegative; events with no
person-time are an error (198), and a cell with neither events nor
person-time has no rate and is refused (459) unless {opt missing()} gives its
text. The default format is {cmd:%9.1f}, as {helpb ratetab} prints rates.

{phang}
{opt ci(exact|poisson)} chooses the interval of {cmd:tabcell rate}; the
limits are those of {helpb ratetab}. {cmd:ci(exact)}, the default, gives the
exact Poisson limits of the event count divided by the person-time,
{cmd:invpoissontail(}{it:e}{cmd:, a/2)} and {cmd:invpoisson(}{it:e}{cmd:, a/2)},
a = 1 - {opt level()}/100, the interval {cmd:cii means} {it:pt} {it:e}{cmd:, poisson}
reports ([R] ci, Methods and formulas, Poisson mean); it needs whole-number
events (error 459 otherwise). {cmd:ci(poisson)} gives {it:rate} x
exp(-/+ z/sqrt({it:e})), the quadratic approximation to the Poisson log
likelihood for the log rate that {helpb strate} uses by default. With no
events, the lower limit is 0 and the upper limit is -ln(a/2)/{it:pt} x
{it:per} under both choices, as {cmd:ci means, poisson} reports a zero count.

{phang}
{opt p(#)} is the p-value that {cmd:tabcell p} prints, a number or scalar
expression (an expression in the data with {opt generate()}), required with
{cmd:tabcell p}. It must lie in [0, 1], otherwise {cmd:tabcell} exits with
error 198; a missing p-value is refused (error 459) unless {opt missing()}
gives the text to print. {opt pdp()}, {opt highpdp()}, and {opt pstyle()} set
how it is written.

{phang}
{opt median(#)}, {opt q1(#)}, and {opt q3(#)} give {cmd:tabcell iqr} the median
and the first and third quartiles; all three are required and are printed as
{it:median} ({it:Q1}, {it:Q3}) in {opt format()} or {opt digits()} with
{opt sep()} between the quartiles. {cmd:tabcell} prints the numbers as given and
checks them: {opt q1()} may not exceed {opt q3()} and {opt median()} must lie
between them, inclusive, otherwise it exits with error 198. A missing number
is refused (error 459) unless {opt missing()} gives the text to print. With
{opt generate()} each is an expression in the data.

{phang}
{opt pdp(#)} and {opt highpdp(#)} set the decimal places of p-values below and
at or above 0.10, as in {helpb regtab}. p-values below 10^-{it:pdp} print as
{cmd:<0.001} (for {cmd:pdp(3)}), and values above 1-10^-{it:highpdp} and below
1 print as {cmd:>0.99}. A p-value outside [0, 1] is refused.

{phang}
{opt pstyle(style)} chooses how {cmd:tabcell p} writes the
p-value. {cmd:pstyle(table)}, the default, prints the bare table text ({cmd:0.012},
{cmd:<0.001}, {cmd:>0.99}). {cmd:pstyle(footnote)} prints it for running text
or a footnote: {cmd:p = 0.012}, {cmd:p < 0.001},
{cmd:p > 0.99}. {cmd:pstyle(Pfootnote)} is the footnote style with a capital P, as many
journals require: {cmd:P = 0.012}, {cmd:P < 0.001}, {cmd:P > 0.99}. Style
names are not case-sensitive. The number is the same in every style, so
{opt pdp()} and {opt highpdp()} apply to all three.

{phang}
{opt nformat(%fmt)} and {opt pformat(%fmt)} format the counts and the
percentage of {cmd:np} and {cmd:enp}; {opt nformat()} also formats the count of
{cmd:tabcell n} (default {cmd:%12.0fc}, as in {helpb table1_tc}, so 12345 prints
as {cmd:12,345}). The percentage is omitted when the denominator is
0. Negative counts and counts larger than their total are refused.

{phang}
{opt mincell(#)} prints a count from 1 to #-1 as {cmd:<}#, without its
percentage; {cmd:tabcell n} masks its count the same way. In {cmd:enp}, a masked event count keeps its total
({cmd:<5/40}), and a masked total masks the whole cell ({cmd:<5}). In
{cmd:tabcell rate}, a rate with 1 to #-1 events prints {cmd:–} (an en dash),
the text {helpb ratetab} prints for a withheld rate, because the rate and the
person-time give the event count back; {cmd:r(rate)}, {cmd:r(lb)}, and
{cmd:r(ub)} are then missing. {cmd:tabcell np, nocount} also prints {cmd:–}. Zero
is printed. This masks the one cell only; it is not complementary
suppression.

{phang}
{opt missing(text)} prints {it:text} for a missing or non-finite number
instead of refusing it, for example {cmd:missing("did not converge")}. {cmd:missing("")}
gives an empty cell: {cmd:r(cell)} is empty and
{cmd:r(missing)} is 1, and with {opt generate()} those rows are left empty.

{phang}
{opt generate(newvar)} creates the string variable {it:newvar}; {ifin}
restricts the rows filled, and other rows are left empty.

{dlgtab:Store}

{phang}
{opt local(name)} stores the cell text, exactly as in {cmd:r(cell)}, in the
local macro {it:name} of the do-file or program that called {cmd:tabcell}; {it:name}
has at most 31 characters. {opt global(name)} stores it in the
global macro {it:name} (at most 32 characters, not beginning with an
underscore). Both may be given. The text is stored as data, never
re-expanded, so quotes, backquotes, and dollar signs in a {opt missing()} text
survive. If
{cmd:tabcell} fails, including on a mistyped form or option, each
validly named macro is cleared, so a {cmd:capture}d failure cannot leave
the previous cell in it. The exception is an option list that cannot be
parsed at all, such as an unbalanced quote or parenthesis; then no macro
is cleared. The {cmd:r()} results are posted
as without these options. Not allowed with {opt generate()}.


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
{phang2}{cmd:. tabcell p, p(0.0004) pstyle(Pfootnote) local(pfoot)}{p_end}
{phang2}{cmd:. display "`pfoot'"}{p_end}
{phang2}{cmd:. tabcell np, n(2) d(20) ci(exact)}{p_end}
{phang2}{cmd:. tabcell np, n(0) d(20) ci(exact) level(90) sep(" to ") global(np0)}{p_end}
{phang2}{cmd:. tabcell n, n(12345)}{p_end}
{phang2}{cmd:. tabcell est, b(0.0213) ll(0.0110) ul(0.0372) scale(1000) format(%5.1f)}{p_end}
{phang2}{cmd:. tabcell np, n(3) d(40) mincell(5)}{p_end}
{phang2}{cmd:. tabcell enp, e(12) n(74)}{p_end}
{phang2}{cmd:. tabcell iqr, median(20) q1(18) q3(25) format(%4.0f)}{p_end}
{phang2}{cmd:. tabcell est, b(.) ll(.) ul(.) missing("did not converge")}{p_end}
{phang2}{cmd:. tabcell np, n(2) d(20) ci(exact) nocount}{p_end}
{phang2}{cmd:. tabcell rate, e(12) pt(975.6) per(1000)}{p_end}
{phang2}{cmd:. tabcell rate, e(12) pt(975.6) per(1000) ci(poisson) level(90) digits(2)}{p_end}
{phang2}{cmd:. tabcell rate, e(0) pt(975.6) per(1000) local(r0)}{p_end}
{phang2}{cmd:. tabcell rate, e(3) pt(975.6) per(1000) mincell(5)}{p_end}

{pstd}A column of cells from numeric variables{p_end}

{phang2}{cmd:. generate double lo = price * 0.9}{p_end}
{phang2}{cmd:. generate double hi = price * 1.1}{p_end}
{phang2}{cmd:. tabcell est, b(price) ll(lo) ul(hi) format(%12.0fc) generate(price_ci)}{p_end}
{phang2}{cmd:. generate double py = 1000 * weight}{p_end}
{phang2}{cmd:. tabcell rate, e(rep78) pt(py) per(100000) generate(rate_ci) missing("")}{p_end}


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
{synopt:{cmd:r(pct)}}percentage as computed ({cmd:np} with {opt ci()}){p_end}
{synopt:{cmd:r(lb)}, {cmd:r(ub)}}limits of the percentage ({cmd:np}, {opt ci()}){p_end}
{synopt:{cmd:r(level)}}confidence level ({cmd:np} with {opt ci()}){p_end}
{synopt:{cmd:r(rate)}}rate per {opt per()} as printed ({cmd:rate}){p_end}
{synopt:{cmd:r(lb)}, {cmd:r(ub)}}limits of the rate ({cmd:rate}){p_end}
{synopt:{cmd:r(level)}}confidence level ({cmd:rate}){p_end}
{synopt:{cmd:r(per)}}the unit given in {opt per()} ({cmd:rate}){p_end}
{synopt:{cmd:r(N)}}rows printed with a number ({opt generate()}){p_end}
{synopt:{cmd:r(N_missing)}}rows given {opt missing()} text ({opt generate()}){p_end}
{synopt:{cmd:r(lincom_}{it:name}{cmd:)}}{cmd:lincom}'s own {it:name}; see below{p_end}

{pstd}
{cmd:r(pct)}, {cmd:r(rate)}, {cmd:r(lb)}, and {cmd:r(ub)} are missing when the
cell prints no number: a masked cell, a {opt missing()} cell, or a zero
denominator.

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
{synopt:{cmd:r(form)}}{cmd:est}, {cmd:p}, {cmd:n}, {cmd:np}, {cmd:enp}, {cmd:iqr}, or {cmd:rate}{p_end}
{synopt:{cmd:r(source)}}{cmd:e()}, {cmd:lincom}, {cmd:nlcom}, {cmd:matrix}, or {cmd:numbers} ({cmd:est}){p_end}
{synopt:{cmd:r(citype)}}{cmd:exact} ({cmd:np} with {opt ci()}); {cmd:exact} or {cmd:poisson} ({cmd:rate}){p_end}
{synopt:{cmd:r(varname)}}the new variable ({opt generate()}){p_end}

{pstd}
With {opt generate()}, it stores {cmd:r(N)} (rows printed with a number), {cmd:r(N_missing)}
(rows given the {opt missing()} text), {cmd:r(varname)}, and {cmd:r(form)}.


{marker references}{...}
{title:References}

{phang}
Clopper, C. J., and E. S. Pearson. 1934. The use of confidence or fiducial
limits illustrated in the case of the binomial. {it:Biometrika}
26: 404-413. {browse "https://doi.org/10.1093/biomet/26.4.404"}.{p_end}

{phang}
Thulin, M. 2014. The cost of using exact confidence intervals for a binomial
proportion. {it:Electronic Journal of Statistics} 8: 817-840.{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{helpb regtab}, {helpb outtab}, {helpb puttab}, {helpb tabtools}
{p_end}

{hline}

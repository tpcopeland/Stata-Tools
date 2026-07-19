{smcl}
{* gcomptab is a secondary command of the gcomp package; the package version}{...}
{* is recorded only in the flagship gcomp.sthlp.}{...}
{vieweralsosee "[R] bootstrap" "help bootstrap"}{...}
{viewerjumpto "Syntax" "gcomptab##syntax"}{...}
{viewerjumpto "Description" "gcomptab##description"}{...}
{viewerjumpto "Options" "gcomptab##options"}{...}
{viewerjumpto "Remarks" "gcomptab##remarks"}{...}
{viewerjumpto "Examples" "gcomptab##examples"}{...}
{viewerjumpto "Output format" "gcomptab##output"}{...}
{viewerjumpto "Stored results" "gcomptab##stored"}{...}
{viewerjumpto "Author" "gcomptab##author"}{...}
{viewerjumpto "Also see" "gcomptab##seealso"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:gcomptab} {hline 2}}Format gcomp effect and component-model tables{p_end}
{p2colreset}{...}

{pstd}
Format results from {helpb gcomp} in three modes: named mediation effects,
time-varying dose-response strategies, or stored component-model refit
approximations. Excel is required for mediation/dose-response; models mode
accepts any of Excel, Markdown, CSV, or Results-window display.


{marker syntax}{...}
{title:Syntax}

{pstd}{bf:Mediation (default) or dose-response:}

{p 4 8 2}
{cmd:gcomptab}{cmd:,}
{opt xlsx(filename)}
{opt sheet(string)}
[{it:options}]

{pstd}{bf:Component models:}

{p 4 8 2}
{cmd:gcomptab}{cmd:,}
{opt models}
[{opt xlsx(filename)} {opt sheet(string)}]
[{opt markdown(filename)}]
[{opt csv(filename)}]
[{opt display}]
[{it:options}]

{synoptset 27 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Excel target (mediation/dose)}
{synopt:{opt xlsx(filename)}}output Excel filename (must end with {cmd:.xlsx}){p_end}
{synopt:{opt sheet(string)}}target sheet name{p_end}

{syntab:Companion text exports (all modes)}
{synopt:{opt markd:own(filename)}}write Markdown companion/output{p_end}
{synopt:{opt csv(filename)}}also write the table to a CSV file ({cmd:.csv}){p_end}

{syntab:Content}
{synopt:{opt ci(string)}}CI type: {cmd:normal} (default), {cmd:percentile}, {cmd:bc}, or {cmd:bca}{p_end}
{synopt:{opt effect(string)}}estimate-column label{p_end}
{synopt:{opt title(string)}}title text for cell A1{p_end}
{synopt:{opt labels(string)}}custom effect labels separated by backslash{p_end}
{synopt:{opt decimal(#)}}decimal places; default {cmd:3}, range 1-6{p_end}

{syntab:Formatting}
{synopt:{opt f:ont(string)}}font family; default is {cmd:"Arial"}{p_end}
{synopt:{opt fonts:ize(#)}}body font size; default {cmd:10}{p_end}
{synopt:{opt border:style(string)}}{cmd:thin}, {cmd:medium}, {cmd:academic}, or {cmd:none}{p_end}
{synopt:{opt the:me(string)}}journal-style formatting preset{p_end}
{synopt:{opt headers:hade}}shade header rows{p_end}
{synopt:{opt nosha:de}}suppress header shading from a theme{p_end}
{synopt:{opt headerc:olor(string)}}header fill color; default {cmd:"219 229 241"}{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt noze:bra}}suppress zebra shading from a theme{p_end}
{synopt:{opt zebrac:olor(string)}}zebra fill color; default {cmd:"237 242 249"}{p_end}
{synopt:{opt foot:note(string)}}footnote text below the table in smaller italic font{p_end}

{syntab:Emphasis}
{synopt:{opt bold:p(#)}}bold cells below Wald-p cutoff{p_end}
{synopt:{opt high:light(#)}}highlight rows below Wald-p cutoff{p_end}

{syntab:Dose-response (time-varying)}
{synopt:{opt dose:response}}force dose-response mode{p_end}
{synopt:{opt strategy:labels(string)}}strategy labels in PO# order{p_end}
{synopt:{opt expy:ears(numlist)}}exposure-years in PO# order{p_end}
{synopt:{opt ref:erence(#)}}reference PO index; default {cmd:1}{p_end}
{synopt:{opt nord}}suppress the risk-difference-vs-reference column{p_end}

{syntab:Component models (models mode)}
{synopt:{opt models}}enter component-model mode{p_end}
{synopt:{opt usemod:els(namelist)}}stored estimates to include; default {cmd:e(model_names)}{p_end}
{synopt:{opt modell:abels(string)}}column header per model, backslash-separated{p_end}
{synopt:{opt terml:abels(string)}}row (term) labels, backslash-separated{p_end}
{synopt:{opt disp:lay}}echo table to the Results window{p_end}
{synopt:{opt eform}}force exponentiation{p_end}
{synopt:{opt noeform}}suppress exponentiation{p_end}
{synopt:{opt raw}}report raw coefficients (alias of {opt noeform}){p_end}
{synopt:{opt coef(string)}}override the scale (estimate) column label{p_end}
{synopt:{opt se}}show standard errors instead of 95% CI{p_end}
{synopt:{opt comp:act}}merge estimate and CI/SE into one column per model{p_end}
{synopt:{opt nopv:alue}}drop the p-value column{p_end}
{synopt:{opt stars}}append significance stars{p_end}
{synopt:{opt starsl:evels(numlist)}}star thresholds; default {cmd:0.05 0.01 0.001}{p_end}
{synopt:{opt noint:ercept}}drop {cmd:_cons} and {cmd:ologit} cutpoints{p_end}
{synopt:{opt keepint:ercept}}keep {cmd:_cons} and cutpoints (default){p_end}
{synopt:{opt keep(string)}}keep only the listed terms{p_end}
{synopt:{opt drop(string)}}drop the listed terms{p_end}
{synopt:{opt dig:its(#)}}numeric precision (alias of {opt decimal()}){p_end}
{synopt:{opt stat:s(string)}}per-model footer statistics ({cmd:n} supported){p_end}

{syntab:Other}
{synopt:{opt open}}request a best-effort workbook open{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}
In dose-response mode {opt effect()}
defaults to the tabled quantity: {cmd:"Risk"} for a survival run (cumulative
incidence) or a binary {opt eofu} outcome, and {cmd:"Mean"} for a continuous
{opt eofu} outcome. Mediation-only options are rejected or excluded by the mode
contract.


{marker description}{...}
{title:Description}

{pstd}
{cmd:gcomptab} reads active {cmd:gcomp} results or stored component refits and
builds one of three table layouts.

{pstd}
{bf:Mediation mode (default)} formats a causal-mediation run. The exported
table includes one row for each mediation effect:

{p 8 12 2}{hline 3} Total Causal Effect (TCE){p_end}
{p 8 12 2}{hline 3} Natural Direct Effect (NDE){p_end}
{p 8 12 2}{hline 3} Natural Indirect Effect (NIE){p_end}
{p 8 12 2}{hline 3} Proportion Mediated (PM){p_end}
{p 8 12 2}{hline 3} Controlled Direct Effect (CDE) — only when the fitted {cmd:gcomp} model included
{opt control()}{p_end}

{pstd}
Effects are located by full column name, not by total vector width. Additional
mediation MSM parameters remain in {cmd:e(b)} but are deliberately omitted
from this named-effect table.

{pstd}
Each row shows the point estimate, 95% confidence interval, and standard
error. The table uses professional formatting: adjustable fonts, border
styles, optional zebra striping, footnotes, and conditional emphasis (bold or
highlight) for statistically significant effects.

{pstd}
{bf:Companion text exports.} In both mediation and dose-response mode,
{opt markdown(filename)} and {opt csv(filename)} write the same table to a
Markdown ({cmd:.md}/{cmd:.markdown}/{cmd:.qmd}/{cmd:.rmd}) and/or CSV ({cmd:.csv})
file alongside the Excel workbook — convenient for README inclusion or
machine-readable downstream use. The cells are identical to the Excel table; the
{opt title()} becomes a level-3 Markdown heading. {opt xlsx()} and {opt sheet()}
remain required (the Excel table is always written); the text files are written
in addition. {cmd:r(markdown)} and {cmd:r(csv)} report the paths written.

{pstd}
{bf:Mediation prerequisites.} Run {cmd:gcomp} with {opt mediation} before
calling {cmd:gcomptab} in mediation mode. The command checks that {cmd:e(cmd)}
is {cmd:"gcomp"} and {cmd:e(analysis_type)} is {cmd:"mediation"}. The {opt oce}
mediation type is not supported; use {opt obe}, {opt linexp}, {opt specific}, or
baseline-based mediation.

{pstd}
{bf:Dose-response mode} formats a time-varying intervention run
({cmd:gcomp ..., interventions(...)}). It emits one row per intervention with
the strategy label, the counterfactual outcome and its 95% CI, an optional
implied mean cumulative exposure-years column, and the difference versus a
chosen reference strategy. This mode is selected automatically when {cmd:e(b)}
contains {cmd:PO#} columns and no {cmd:tce} column, or explicitly with
{opt doseresponse}.

{pstd}
The tabled quantity is outcome-type aware. A {bf:survival} run (no {opt eofu})
carries both {cmd:PO#} average log incidence rates and {cmd:out#} cumulative
incidences; dose-response mode tables the {cmd:out#} cumulative incidences (a
risk on the 0-1 scale), {it:not} the log incidence rates. An {opt eofu} run has
only {cmd:PO#} columns: the counterfactual risk for a binary outcome, or the
mean potential outcome for a continuous outcome. The default column header and
footnote follow suit ({cmd:"Risk"}/cumulative incidence for survival, risk for
binary {opt eofu}, mean potential outcome for continuous {opt eofu}).

{pstd}
{bf:Component-model mode} formats one or more stored estimates, normally the
analytic-sample refit approximations named in {cmd:e(model_names)} after
{cmd:gcomp, savemodels}. Full Stata coefficient stripes remain the identity,
and display labels never merge distinct factor or interaction terms.

{pstd}
{cmd:gcomp} posts one {cmd:PO#} column per intervention {it:plus} a final column
for the simulated observed (natural-course) regime, so a run with {it:m}
interventions yields {it:k} = {it:m}+1 {cmd:PO#} columns. {opt strategylabels()}
and {opt expyears()} map onto these columns in order; any column you do not
label keeps the default name {cmd:PO#} and any column without a supplied
exposure-years value is left blank. Risk differences are reported as point
estimates (risk minus the reference strategy's risk); the reference row is
therefore {cmd:0}.


{marker options}{...}
{title:Options}

{dlgtab:Excel target (required in mediation/dose-response)}

{phang}
{opt xlsx(filename)} specifies the Excel workbook to create or update. The
filename must end with {cmd:.xlsx}. If the file already exists, only the named
sheet is replaced; other sheets are preserved. In models mode Excel is
optional because Markdown, CSV, or {opt display} can be the sole target.

{phang}
{opt sheet(string)} specifies the sheet name within the workbook. If the sheet
already exists it is overwritten; otherwise a new sheet is created. Sheet names
must be 31 characters or fewer and may not contain {cmd:: \ / ? * [ ]}. In
models mode the default is {cmd:Models} when {opt xlsx()} is supplied.

{dlgtab:Content}

{phang}
{opt ci(string)} selects which confidence interval type to display in the
table. Options are:{break}
{cmd:normal} {hline 2} normal approximation: mean +/- 1.96 * SE (default){break}
{cmd:percentile} {hline 2} percentile bootstrap CI{break}
{cmd:bc} {hline 2} bias-corrected bootstrap CI{break}
{cmd:bca} {hline 2} bias-corrected and accelerated bootstrap CI{break}
The corresponding CI matrix (e.g. {cmd:e(ci_percentile)}) must exist in the
{cmd:gcomp} results. Run {cmd:gcomp} with {opt all} to generate all four
types.

{phang}
{opt effect(string)} sets the column header for the effect estimate column. Default
is {cmd:"Estimate"}. Use this to label the column with the scale of your analysis,
for example {cmd:effect("Risk Difference")} or {cmd:effect("logOR")}.

{phang}
{opt title(string)} places a title in cell A1 of the sheet, merged across
all columns and set in a larger, bold font. Useful for table captions that
will appear in the Excel output, such as
{cmd:title("Table 2. Causal Mediation Analysis")}.

{phang}
{opt labels(string)} overrides the default row labels for the five effects. Separate
labels with backslashes. The default is:{break}
{cmd:"Total Causal Effect (TCE) \ Natural Direct Effect (NDE) \}{break}
{cmd: Natural Indirect Effect (NIE) \ Proportion Mediated (PM) \}{break}
{cmd: Controlled Direct Effect (CDE)"}{break}
If the {cmd:gcomp} results have only 4 effects (no CDE), the fifth label is
ignored. If you provide fewer labels than effects, the remaining rows use
default labels.

{phang}
{opt decimal(#)} sets the number of decimal places for point estimates,
confidence limits, and standard errors. Default is {cmd:3}. Range is 1 to 6.

{dlgtab:Formatting}

{phang}
{opt f:ont(string)} sets the font family for all text in the workbook. Default is
{cmd:"Arial"}. Any font installed on your system can be used.

{phang}
{opt fontsize(#)} sets the body text font size in points. The title row
(if specified) uses fontsize+2. Default is {cmd:10}. Range is 1 to 72.

{phang}
{opt borderstyle(string)} controls the table border style:{break}
{cmd:thin} {hline 2} thin boxed table (default){break}
{cmd:medium} {hline 2} medium-weight borders on all cells{break}
{cmd:academic} {hline 2} horizontal rules only{break}
{cmd:none} {hline 2} no explicit borders

{phang}
{opt theme(string)} applies a journal-style preset. Allowed values are
{cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos},
{cmd:nature}, {cmd:cell}, and {cmd:annals}.

{phang}
{opt headershade}, {opt noshade}, and {opt headercolor(string)} control header
fills. Header shading is off by default.

{phang}
{opt zebra} applies alternating row shading to data rows. {opt nozebra}
suppresses zebra shading requested by a theme. {opt zebracolor(string)} sets
the alternating-row fill color.

{phang}
{opt footnote(string)} places footnote text below the table. The text is
merged across the table width and displayed in a smaller italic font. Use
for model notes, data sources, or abbreviation definitions.

{dlgtab:Emphasis}

{phang}
{opt boldp(#)} applies bold formatting to the numeric cells (Estimate, CI, SE) in
any data row whose two-sided Wald p-value falls below the specified
cutoff. The p-value is computed as {cmd:2 * normal(-abs(estimate / se))}. Default is
{cmd:0}, which disables bolding. Specify a value between 0 and 1 (e.g. {cmd:boldp(0.05)}).

{phang}
{opt highlight(#)} applies yellow background shading to the entire data row
when the Wald p-value is below the cutoff. Works like {opt boldp()} but uses
color instead of (or in addition to) bold weight. Default is {cmd:0} (disabled).

{dlgtab:Dose-response (time-varying)}

{phang}
{opt doseresponse} forces the dose-response branch. This is normally
unnecessary — {cmd:gcomptab} auto-detects dose-response output whenever
{cmd:e(b)} has {cmd:PO#} columns and no {cmd:tce} column — but the option lets
you select it explicitly and produces a clear error if the active {cmd:e()} is
not a time-varying {cmd:gcomp} result.

{phang}
{opt strategylabels(string)} supplies the strategy labels shown in the first data
column, separated by backslashes, in the order of the {cmd:PO#} columns. Any column
you do not label is shown as {cmd:PO#}. For example,
{cmd:strategylabels("Never HE \ Always HE \ Observed regime")}.

{phang}
{opt expyears(numlist)} supplies the implied mean cumulative exposure-years for
each strategy, one value per {cmd:PO#} column, in column order. When supplied, a
{cmd:Mean exposure-years} column is added to the table; when omitted, the column
is not shown. Supplying more values than there are {cmd:PO#} columns is an error.

{phang}
{opt reference(#)} selects which {cmd:PO#} column is the reference for the
risk-difference column. Default is {cmd:1} (the first intervention). Must be
between 1 and the number of {cmd:PO#} columns.

{phang}
{opt nord} suppresses the {cmd:RD vs ref} column, leaving only the strategy,
optional exposure-years, and risk columns.

{dlgtab:Component-model mode (models)}

{phang}
{opt models} enters component-model mode: instead of formatting the {cmd:e(b)}
effect vector, {cmd:gcomptab} reads the parametric component models stored by
{cmd:gcomp} (run with {opt savemodels} or {opt showmodels}) and writes a
multi-model coefficient table. The flag is required to enter this mode; it never
auto-triggers, so mediation and dose-response detection are unaffected. It is
mutually exclusive with {opt doseresponse} and with the mediation-only options
{opt ci()}, {opt effect()}, and {opt labels()}. At least one output target
({opt xlsx()}, {opt markdown()}, {opt csv()}, or {opt display}) is required.

{phang}
{opt usemodels(namelist)} selects which stored estimates to include; the default
is {cmd:e(model_names)}.

{phang}
{opt modellabels(string)} sets the column header per model
(backslash-separated); default is the dependent variable. {opt termlabels(string)}
overrides the row (term) labels (backslash-separated).

{phang}
{opt eform}, {opt noeform}, {opt raw}, and {opt coef(string)} control the scale. By default the scale
is auto-detected per command ({cmd:logit}{c 174}OR, {cmd:mlogit}{c 174}RRR, {cmd:ologit}{c 174}OR,
{cmd:regress}{c 174}Coef.). {opt eform} forces exponentiation, {opt noeform}/{opt raw} suppress it, and
{opt coef()} overrides the scale label. When models mix scales, {cmd:r(coef_label)} is
{cmd:mixed}.

{phang}
{opt se} shows standard errors instead of the 95% CI. {opt nopvalue} drops the
p-value column. {opt compact} merges the estimate and CI/SE into one column per
model. {opt stars} appends significance stars at the thresholds in
{opt starslevels(numlist)} (default {cmd:0.05 0.01 0.001}).

{phang}
{opt nointercept} drops {cmd:_cons} and {cmd:ologit} cutpoints; {opt keepintercept}
keeps them (the default). {opt keep(string)} and {opt drop(string)} filter rows
by term name.

{phang}
{opt digits(#)} (or {opt decimal(#)}) sets numeric precision (default 3). {opt stats(string)}
adds a per-model footer; {cmd:n} (sample size) is supported.

{phang}
{opt markdown(filename)} and {opt csv(filename)} (shared with the mediation and
dose-response modes) write the table to Markdown and CSV files; in models mode
{opt display} also echoes it to the Results window, and any one of
{opt xlsx()}/{opt markdown()}/{opt csv()}/{opt display} is sufficient (xlsx is
not required). The {opt title()}, {opt footnote()}, {opt font()},
{opt fontsize()}, {opt borderstyle()}, {opt zebra}, {opt headershade},
{opt boldp()}, {opt highlight()}, and {opt open} options apply to the xlsx output
as in the other modes.

{pstd}
All text staging uses lossless long strings. Markdown escapes pipes,
backslashes, and line breaks. CSV uses a standards-aware serializer for
commas, quotes, Unicode, and line breaks; formula-leading nonnumeric text is
written as text rather than an executable spreadsheet formula.

{dlgtab:Other}

{phang}
{opt open} makes a best-effort request to open the completed Excel file. File
writing and analytical returns are established first. {cmd:r(open_rc)} reports
the request status; on headless Linux, a successful launcher call does not
prove that a visible desktop application opened.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Workflow}

{pstd}
The typical workflow is:

{phang2}1. Fit the mediation model with {cmd:gcomp} (see {helpb gcomp}).{p_end}
{phang2}2. Run {cmd:gcomptab} immediately after to export results.{p_end}
{phang2}3. Optionally run {cmd:gcomptab} again with a different {opt ci()} or
{opt sheet()} to create multiple tables in the same workbook.{p_end}

{pstd}
{bf:Multiple tables in one workbook}

{pstd}
Because {cmd:gcomptab} replaces only the named sheet, you can build a
multi-sheet workbook by calling {cmd:gcomptab} repeatedly with different
{opt sheet()} names:

{phang2}{cmd:. gcomptab, xlsx(results.xlsx) sheet("Normal CI") ci(normal)}{p_end}
{phang2}{cmd:. gcomptab, xlsx(results.xlsx) sheet("Percentile CI") ci(percentile)}{p_end}

{pstd}
{bf:Supported and unsupported mediation types}

{pstd}
{cmd:gcomptab} supports {opt obe}, {opt linexp}, {opt specific}, and
baseline-based mediation results. It does {bf:not} support {opt oce} results
because {opt oce} produces per-level contrast sets rather than the named
single TCE/NDE/NIE/PM rows. Mediation MSM coefficients do not cause rejection,
and they remain in {cmd:e(b)} while being omitted from this effects-only layout.

{pstd}
{bf:When to use gcomptab vs. effecttab}

{pstd}
Use {cmd:gcomptab} for mediation results from the user-written {cmd:gcomp}
command. Use {helpb effecttab} for causal-inference results from Stata's
built-in commands ({helpb teffects}, {helpb margins}).


{marker examples}{...}
{title:Examples}

{pstd}
The first block is complete and supplies the active mediation results used by
Examples 1-6:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. set obs 800}{p_end}
{phang2}{cmd:. generate double c = rnormal()}{p_end}
{phang2}{cmd:. generate byte x = rbinomial(1, invlogit(.2*c))}{p_end}
{phang2}{cmd:. generate byte m = rbinomial(1, invlogit(-.5+.7*x+.2*c))}{p_end}
{phang2}{cmd:. generate byte y = rbinomial(1, invlogit(-1+.5*x+.7*m+.2*c))}{p_end}
{phang2}{cmd:. gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      base_confs(c) sim(400) samples(50) seed(42) all savemodels}{p_end}

    {hline}
{pstd}
{bf:Example 1: Basic export}

{pstd}
Export the default results (normal CIs, 3 decimal places) to a new workbook:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Table 1") ///}{p_end}
{phang2}{cmd:      title("Causal Mediation: Treatment Effect via Adherence")}{p_end}

    {hline}
{pstd}
{bf:Example 2: Percentile bootstrap CIs}

{pstd}
Use percentile CIs instead of the normal approximation. Percentile and
bias-corrected CIs ({cmd:ci(percentile)}, {cmd:ci(bc)}) are computed by every
{cmd:gcomp} bootstrap run; only {cmd:ci(bca)} requires {opt all}:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Percentile CI") ///}{p_end}
{phang2}{cmd:      ci(percentile) title("Mediation Results (Percentile CI)")}{p_end}

    {hline}
{pstd}
{bf:Example 3: Custom labels and effect column header}

{pstd}
Relabel the effects and change the estimate column header:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Custom") ///}{p_end}
{phang2}{cmd:      labels("Total Effect \ Direct Effect \ Indirect Effect \ % Mediated \ CDE") ///}{p_end}
{phang2}{cmd:      effect("Risk Difference") title("Risk Difference Decomposition")}{p_end}

    {hline}
{pstd}
{bf:Example 4: Higher precision with footnote}

{pstd}
Show 4 decimal places and add a footnote with model details:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Precise") ///}{p_end}
{phang2}{cmd:      decimal(4) title("Mediation Analysis") ///}{p_end}
{phang2}{cmd:      footnote("Bootstrap: 1000 replications. CI: Normal approximation.")}{p_end}

    {hline}
{pstd}
{bf:Example 5: Bold significant effects and zebra striping}

{pstd}
Bold effects with p < 0.05 and apply alternating row shading:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Formatted") ///}{p_end}
{phang2}{cmd:      title("Mediation Analysis") boldp(0.05) zebra}{p_end}

    {hline}
{pstd}
{bf:Example 6: Full formatting with highlight}

{pstd}
Combine title, footnote, zebra, bold, and yellow highlighting:

{phang2}{cmd:. gcomptab, xlsx(mediation_results.xlsx) sheet("Full Format") ///}{p_end}
{phang2}{cmd:      title("Table 3. Causal Mediation Results") ///}{p_end}
{phang2}{cmd:      footnote("Bold: p < 0.05. Yellow: p < 0.01.") ///}{p_end}
{phang2}{cmd:      zebra boldp(0.05) highlight(0.01) font("Calibri") fontsize(11)}{p_end}

    {hline}
{pstd}
{bf:Example 7: Time-varying dose-response table}

{pstd}
Fit a self-contained time-varying g-formula, then format the three {cmd:PO#}
columns (two interventions plus simulated observed regime):

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 54321}{p_end}
{phang2}{cmd:. set obs 600}{p_end}
{phang2}{cmd:. generate long id = ceil(_n/3)}{p_end}
{phang2}{cmd:. bysort id: generate double time = 2*_n-1}{p_end}
{phang2}{cmd:. generate double L = rnormal()+.1*time}{p_end}
{phang2}{cmd:. generate byte A = rbinomial(1,invlogit(-.8+.2*L))}{p_end}
{phang2}{cmd:. generate byte Y = rbinomial(1,invlogit(-1+.4*A+.2*L))}{p_end}
{phang2}{cmd:. gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) ///}{p_end}
{phang2}{cmd:      varyingcovariates(L) intvars(A) interventions(A=1, A=0) ///}{p_end}
{phang2}{cmd:      commands(L: regress, A: logit, Y: logit) ///}{p_end}
{phang2}{cmd:      equations(L: time, A: L time, Y: A L time) ///}{p_end}
{phang2}{cmd:      eofu pooled sim(200) samples(50) seed(12345)}{p_end}
{phang2}{cmd:. gcomptab, doseresponse sheet("Table 5 DR") xlsx(table5.xlsx) ///}{p_end}
{phang2}{cmd:      strategylabels("Always HE \ Never HE \ Observed regime") ///}{p_end}
{phang2}{cmd:      expyears(5 0 2) reference(1) effect("Risk")}{p_end}

    {hline}
{pstd}
{bf:Example 8: Component-model table (models mode)}

{pstd}
Capture the fitted component models during a mediation run, then export them as
a multi-model coefficient table to Excel and Markdown:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 12345}{p_end}
{phang2}{cmd:. set obs 800}{p_end}
{phang2}{cmd:. generate double c = rnormal()}{p_end}
{phang2}{cmd:. generate byte x = rbinomial(1, invlogit(.2*c))}{p_end}
{phang2}{cmd:. generate byte m = rbinomial(1, invlogit(-.5+.7*x+.2*c))}{p_end}
{phang2}{cmd:. generate byte y = rbinomial(1, invlogit(-1+.5*x+.7*m+.2*c))}{p_end}
{phang2}{cmd:. gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) base_confs(c) ///}{p_end}
{phang2}{cmd:      commands(m: logit, y: logit) equations(m: x c, y: m x c) ///}{p_end}
{phang2}{cmd:      sim(400) samples(50) seed(42) savemodels}{p_end}
{phang2}{cmd:. gcomptab, models xlsx(models.xlsx) sheet("Component models") ///}{p_end}
{phang2}{cmd:      modellabels("Mediator \ Outcome") stats(n) stars title("Component models")}{p_end}
{phang2}{cmd:. gcomptab, models markdown(models.md) compact}{p_end}


{marker output}{...}
{title:Output format}

{pstd}
The Excel table has the following structure:

{p 8 12 2}{bf:Row 1}: Title (if specified), merged across the table width, bold, fontsize+2.{p_end}
{p 8 12 2}{bf:Row 2}: Column headers — Effect | Estimate | 95% CI | SE — bold,
centered, and optionally shaded with {opt headershade}.{p_end}
{p 8 12 2}{bf:Rows 3-6}: Data rows for TCE, NDE, NIE, and PM.{p_end}
{p 8 12 2}{bf:Row 7}: CDE data row (only when the fitted model included {opt control()}).{p_end}
{p 8 12 2}{bf:Next row}: Footnote (if specified), merged across the table width, italic,
smaller font.{p_end}

{pstd}
In {bf:dose-response} mode the columns are instead Strategy | Mean exposure-years
(when {opt expyears()} is supplied) | {it:effect} (95% CI) | difference vs ref
(unless {opt nord}; header {cmd:RD vs ref} for a risk, {cmd:Diff vs ref}
otherwise), with one data row per intervention.

{pstd}
Formatting details:

{p 8 12 2}{hline 3} Numeric cells are stored as Excel numbers, not text, so they can be used in
formulas.{p_end}
{p 8 12 2}{hline 3} Column widths are adjusted to content.{p_end}
{p 8 12 2}{hline 3} The default thin border style draws a boxed table; {cmd:academic} uses horizontal
rules only above and below the header row and below the last data row.{p_end}
{p 8 12 2}{hline 3} Zebra striping, bold, and highlighting are applied conditionally as described
in {it:Options}.{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:gcomptab} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_effects)}}named mediation effects exported{p_end}
{synopt:{cmd:r(has_cde)}}1 when CDE is present; otherwise 0{p_end}
{synopt:{cmd:r(tce)}}total causal effect{p_end}
{synopt:{cmd:r(nde)}}natural direct effect{p_end}
{synopt:{cmd:r(nie)}}natural indirect effect{p_end}
{synopt:{cmd:r(pm)}}proportion mediated{p_end}
{synopt:{cmd:r(cde)}}controlled direct effect, when present{p_end}
{synopt:{cmd:r(open_rc)}}best-effort opener status with {opt open}{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename used{p_end}
{synopt:{cmd:r(sheet)}}sheet name used{p_end}
{synopt:{cmd:r(ci)}}CI type displayed{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename written{p_end}
{synopt:{cmd:r(csv)}}CSV filename written{p_end}

{pstd}
In {bf:dose-response} mode {cmd:gcomptab} stores instead:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(k)}}number of strategies ({cmd:PO#} columns) exported{p_end}
{synopt:{cmd:r(reference)}}PO index used as the risk-difference reference{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename used{p_end}
{synopt:{cmd:r(sheet)}}sheet name used{p_end}
{synopt:{cmd:r(ci)}}CI type displayed{p_end}
{synopt:{cmd:r(ref_label)}}label of the reference strategy{p_end}
{synopt:{cmd:r(markdown)}}Markdown filename written{p_end}
{synopt:{cmd:r(csv)}}CSV filename written{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}strategy estimate/CI/exposure/RD matrix{p_end}

{pstd}
In {bf:models} mode {cmd:gcomptab} stores instead:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_models)}}number of model columns{p_end}
{synopt:{cmd:r(N_rows)}}number of body rows{p_end}
{synopt:{cmd:r(N_cols)}}number of table columns{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(coef_label)}}shared scale label, or {cmd:mixed}{p_end}
{synopt:{cmd:r(methods)}}auto methods sentence{p_end}
{synopt:{cmd:r(term_names)}}full coefficient identities in row order{p_end}
{synopt:{cmd:r(xlsx)} {cmd:r(sheet)} {cmd:r(markdown)} {cmd:r(csv)}}output targets written{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}matrix of displayed estimates (rows = terms, columns = models){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}


{marker seealso}{...}
{title:Also see}

{psee}
Online: {helpb gcomp}, {helpb regtab}, {helpb effecttab}

{hline}

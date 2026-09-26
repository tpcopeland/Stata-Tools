{smcl}
{vieweralsosee "effecttab" "help effecttab"}{...}
{viewerjumpto "Package overview" "regtab##package"}{...}
{viewerjumpto "Syntax" "regtab##syntax"}{...}
{viewerjumpto "Description" "regtab##description"}{...}
{viewerjumpto "Options" "regtab##options"}{...}
{viewerjumpto "Remarks" "regtab##remarks"}{...}
{viewerjumpto "Examples" "regtab##examples"}{...}
{viewerjumpto "Stored results" "regtab##stored"}{...}
{viewerjumpto "Also see" "regtab##seealso"}{...}
{viewerjumpto "Author" "regtab##author"}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:regtab} {hline 2}}Format collected regression results for publication-ready Excel tables{p_end}
{p2colreset}{...}


{marker package}{...}
{title:Package}

{pstd}
{cmd:regtab} is part of the {helpb tabtools} suite. See also {helpb effecttab}
for treatment effects and margins tables.

{hline}


{title:regtab}

{pstd}Format {helpb collect}ed regression results into a polished Excel table.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:regtab}, [{opt xlsx(filename)} {opt excel(filename)}
{opt sheet(string)} {opt sep(string asis)} {opt models(string)}
{opt coef(string)} {opt title(string)} {opt noint:ercept} {opt keepi:ntercept}
{opt nore:effects} {opt stats(string)} {opt relab:el} {opt digits(#)}
{opt l:evel(#)}
{opt foot:note(string)} {opt open} {opt zebra} {opt headers:hade}
{opt high:light(#)} {opt bold:p(#)} {opt border:style(string)}
{opt font(string)} {opt fontsize(#)} {opt headerc:olor(string)} {opt zebrac:olor(string)}
{opt csv(string)} {opt mark:down(filename)} {opt mdapp:end} {opt fra:me(name)}
{opt eplotf:rame(name[, replace])} {opt keep(varlist)}
{opt drop(varlist)} {opt labelm:atch} {opt dimnon:sig} {opt factorl:abel} {opt ref:cat(string)}
{opt omitl:abel(string)} {opt emptyl:abel(string)}
{opt cutl:abels(string)} {opt comp:act} {opt nop:value} {opt stars}
{opt starsl:evels(numlist)} {opt addr:ow(string asis)} {opt pdp(#)} {opt highpdp(#)} {opt cdisc} {opt labelw:idth(#)}]{p_end}

{pstd}Required: an active {helpb collect} with items {cmd:_r_b}, {cmd:_r_ci},
and {cmd:_r_p} and dimensions including {cmd:colname} and {cmd:cmdset}.{p_end}

{marker description}{title:Description}

{pstd}{cmd:regtab} reads the current {helpb collect} table and writes a clean Excel sheet with,
for each model (each {cmd:cmdset}), columns for the point estimate ({cmd:_r_b}), confidence interval
({cmd:_r_ci}), and p-value ({cmd:_r_p}). Use {opt nopvalue} to suppress the p-value column in
the rendered output. It preserves raw coefficient names while applying labels,
number formats, and row selection, optionally merges model headers, writes to
your target workbook/sheet, and styles borders, alignment, fonts, and column widths. Title
text can be written to cell {cmd:A1}; the main table begins at {cmd:B2}.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(string)}}output Excel filename (must end with .xlsx){p_end}
{synopt:{opt sheet(string)}}target sheet to create/replace in xlsx(){p_end}
{synopt:{opt sep(string asis)}}CI delimiter for {cmd:collect}; default {cmd:", "}{p_end}
{synopt:{opt models(string)}}set merged model labels{p_end}
{synopt:{opt coef(string)}}header for the estimate column{p_end}
{synopt:{opt title(string)}}title written to A1, merged across the table{p_end}
{synopt:{opt noint:ercept}}drop intercept, cutpoint, and ancillary rows{p_end}
{synopt:{opt keepi:ntercept}}retain the intercept row{p_end}
{synopt:{opt nore:effects}}omit random-effects rows{p_end}
{synopt:{opt stats(string)}}select model-fit statistics{p_end}
{synopt:{opt digits(#)}}set decimals for coefficients and CIs{p_end}
{synopt:{opt level(#)}}verify the collection's confidence level{p_end}
{synopt:{opt labelw:idth(#)}}cap the label-column width{p_end}
{synopt:{opt foot:note(string)}}add italic footnote text{p_end}
{synopt:{opt open}}open the Excel file after export{p_end}
{synopt:{opt zebra}}apply alternating light gray row shading{p_end}
{synopt:{opt high:light(#)}}yellow fill for rows where p-value < #{p_end}
{synopt:{opt bold:p(#)}}bold p-value cells below #{p_end}
{synopt:{opt headers:hade}}apply background fill to the header row{p_end}
{synopt:{opt font(string)}}set the Excel font family{p_end}
{synopt:{opt fontsize(#)}}set the Excel font size in points{p_end}
{synopt:{opt border:style(string)}}set the table border style{p_end}
{synopt:{opt cdisc}}apply CDISC labels and defaults{p_end}
{synopt:{opt relab:el}}relabel random effects{p_end}
{synopt:{opt stars}}add coefficient significance stars{p_end}
{synopt:{opt starsl:evels(numlist)}}custom p-value thresholds for stars{p_end}
{synopt:{opt headerc:olor(string)}}set the header fill color{p_end}
{synopt:{opt zebrac:olor(string)}}set alternating-row fill color{p_end}
{synopt:{opt csv(filename)}}also export the table as a CSV file{p_end}
{synopt:{opt markdown(filename)}}export the table as GitHub-Flavored Markdown{p_end}
{synopt:{opt mdappend}}append to an existing Markdown file{p_end}
{synopt:{opt fra:me(name)}}store output in a named frame{p_end}
{synopt:{opt eplotf:rame(name[, replace])}}save a graph-ready companion frame{p_end}
{synopt:{opt keep(varlist)}}keep exact variable or factor names{p_end}
{synopt:{opt drop(varlist)}}drop exact variable or factor names{p_end}
{synopt:{opt labelm:atch}}match label substrings with keep()/drop(){p_end}
{synopt:{opt dimnon:sig}}gray out non-significant rows (see Remarks){p_end}
{synopt:{opt factorl:abel}}render labels for factor-variable levels{p_end}
{synopt:{opt ref:cat(string)}}label for reference-category rows{p_end}
{synopt:{opt omitl:abel(string)}}label for coefficients the model dropped{p_end}
{synopt:{opt emptyl:abel(string)}}label for cells identifying no observations{p_end}
{synopt:{opt cutl:abels(string)}}relabel ordered-model cutpoints{p_end}
{synopt:{opt comp:act}}combine estimate and CI per model{p_end}
{synopt:{opt nop:value}}suppress p-value columns{p_end}
{synopt:{opt addr:ow(string asis)}}append custom label/value rows{p_end}
{synopt:{opt pdp(#)}}decimal places for p < 0.10{p_end}
{synopt:{opt highpdp(#)}}decimal places for p >= 0.10{p_end}
{synoptline}

{pstd}{bf:Automatic Median Odds Ratio / Median Hazard Ratio}{p_end}

{pstd}When the model type is {cmd:melogit}, {cmd:regtab} automatically converts the random
intercept variance to a {bf:Median Odds Ratio (MOR)} using the formula MOR =
exp(sqrt(2 * {it:sigma}^2) * invnormal(0.75)). For {cmd:mecloglog}, and for
{cmd:mestreg} in the log-hazard metric, the conversion produces a
{bf:Median Hazard Ratio (MHR)}. An {cmd:mestreg} fit in the time metric
({cmd:time}; TR header) keeps its random-intercept row as the variance it is,
labelled {cmd:var(_cons[}{it:group}{cmd:])} (or "Variance: {it:Group} (Intercept)"
under {opt relabel}): its random effect acts on log time, so a median hazard
ratio would misname it. The collected CI bounds are
transformed on the same scale. In multi-level models, each transformed
random-intercept row keeps its own grouping label, so the output reads, for
example, "Median Odds Ratio (District)" and "Median Odds Ratio
(School)". MOR/MHR values and other random effects (slopes, covariances,
residual) follow the requested {opt digits()} precision. When a transformed
bound cannot be represented (the MOR of a near-zero variance whose upper
bound is ~1e+29 overflows double precision), the CI cell is left blank; the
same applies to an exponentiated fixed-effect interval, so a cell never shows
the untransformed collect text. Use {opt nore} to suppress all
random-effects rows if desired.{p_end}


{pstd}
{it:Detailed option contracts}{p_end}

{phang}
{opt addr:ow(string asis)} append custom label/value rows below the table (see Remarks for syntax){p_end}

{phang}
{opt bold:p(#)} bold p-value cells below #{p_end}

{phang}
{opt border:style(string)} border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}
(default {cmd:thin}){p_end}

{phang}
{opt cdisc} CDISC mode: digits 4, coef label "Estimate", forces {cmd:stats(n)}{p_end}

{phang}
{opt coef(string)} header for the estimate column; auto-detected per model scale if omitted (see
Remarks){p_end}

{phang}
{opt comp:act} merge estimate and CI into one column per model{p_end}

{phang}
{opt csv(filename)} also export the table as a CSV file. {it:filename} must end in {cmd:.csv} and differ from the
Excel and Markdown targets. The CSV mirrors the
workbook with {opt title()} written as the first row and {opt footnote()} as
the last row, both in the first column and the table body between them.{p_end}

{phang}
{opt cutl:abels(string)} custom labels for ordered-model cutpoint rows, backslash-separated{p_end}

{phang}
{opt dimnon:sig} gray out non-significant rows (see Remarks){p_end}

{phang}
{opt drop(varlist)} drops rows by exact, case-sensitive variable or factor-component
name; not with {opt keep()}. See {opt keep()} for matching rules.{p_end}

{phang}
{opt eplotf:rame(name[, replace])} store a graph-ready companion frame for {helpb eplot} (see
Remarks){p_end}

{phang}
{opt factorl:abel} replace factor-variable prefixes (e.g., {it:3.rep78}) with value labels{p_end}

{phang}
{opt foot:note(string)} add a footnote row below the table in smaller italic font{p_end}

{phang}
{opt fra:me(name)} store output in a named frame; {cmd:frame(name, replace)} replaces an existing
frame{p_end}

{phang}
{opt headers:hade} apply background fill to the header row{p_end}

{phang}
{opt high:light(#)} yellow fill for rows where p-value < #{p_end}

{phang}
{opt highpdp(#)} max decimal places for large p-values (p >= 0.10); default 2{p_end}

{phang}
{opt keep(varlist)} shows only rows matching exact, case-sensitive raw
names; not with {opt drop()}. Labels do not affect name matching. For example,
{cmd:keep(age)} selects {cmd:age}, its factor levels, and interactions containing
it, but never {cmd:stage} or {cmd:Age}. {cmd:keep(2.arm)} selects that level and
interactions containing it, but not {cmd:20.arm}. Factor operators such as
{cmd:i.arm} and {cmd:c.age} are accepted; an interaction specification such as
{cmd:1.arm#c.age} selects that interaction exactly.{p_end}

{phang}
{opt labelm:atch} makes {opt keep()} or {opt drop()} match case-insensitive
substrings of displayed row labels instead of raw names. For example,
{cmd:keep(Fuel) labelmatch} selects a row labelled {it:Fuel efficiency}. Requires {opt keep()} or {opt drop()}.{p_end}

{phang}
{opt keepi:ntercept} force display of the intercept row even for exponentiated models{p_end}

{phang}
{opt labelw:idth(#)} maximum width of the label column in characters (default 45); longer labels
wrap{p_end}

{phang}
{opt level(#)} verifies confidence-level provenance. By default, {cmd:regtab}
uses the level stored in the active collection, and an explicit value must
match that stored level or the command fails before writing output. Not every
Stata version records the level in the collection: Stata 17 does, Stata 19 does
not. When it is absent and {opt level()} is omitted, {cmd:regtab} warns and uses
the current {helpb set level} for interval labels. Because that is the session
setting at render time rather than necessarily the model-time level, specify
{opt level()} whenever the collected models were fit at a different level. The
resolved level labels intervals in headers and methods text, is returned in
{cmd:r(ci_level)}, and is stored on display and eplot frames; it affects no
computed quantity.{p_end}

{phang}
{opt markdown(filename)} export the table as GitHub-Flavored Markdown. Factor-level rows keep
their indentation: each leading space of a row label is written as {cmd:&nbsp;}, which
survives Markdown cell trimming{p_end}

{phang}
{opt mdappend} append the Markdown table to an existing file; requires {opt markdown()}{p_end}

{phang}
{opt models(string)} labels merged above each model's columns, backslash-separated; auto-generated
if omitted{p_end}

{phang}
{opt noint:ercept} drop intercept, cutpoint, and ancillary rows; auto-enabled for all-ratio-scale
models. Rows are identified by the coefficient's equation and name in the
collection, never by its display label: {cmd:_cons} in any equation, {cmd:cut}{it:#} in
the ancillary ({cmd:/}) equation, and the ancillary parameters {cmd:lnalpha},
{cmd:alpha}, {cmd:ln_p}, {cmd:p}, and {cmd:1/p} of the {cmd:/} and derived
{cmd:_diparm} equations. Other ancillary parameters, such as a lognormal's
{cmd:lnsigma}/{cmd:sigma} or a loglogistic's {cmd:lngamma}/{cmd:gamma}, stay
visible. In the multi-equation layout the whole ancillary block and any
{cmd:lnsigma} scale equation are dropped. A covariate named or labelled
{cmd:p}, {cmd:alpha}, {cmd:constant}, {cmd:cut1}, {cmd:Intercept}, or
{cmd:/x} is an ordinary coefficient: it is kept and exponentiated with the
others. When one row holds one model's ancillary parameter and another model's
covariate of the same name, only the ancillary cell is blanked. A model whose
covariate shares its name with one of its own ancillary parameters or cutpoints
(a covariate named {cmd:alpha} in {cmd:nbreg}, {cmd:ln_p} in a Weibull {cmd:streg},
{cmd:lnsigma} in a lognormal one, {cmd:cut1} in {cmd:ologit}) shows both rows,
told apart by their equations: the covariate among the covariates, on the
model's scale, and the parameter, labelled with its own name and on its own
scale, among the ancillary rows. The collection itself is not changed.{p_end}

{phang}
{opt nop:value} suppress p-value columns; stars and highlighting still use p-values internally{p_end}

{phang}
{opt nore:effects} drop all random-effects rows (variances, covariances, SDs){p_end}

{phang}
{opt open} open the Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}

{phang}
{opt pdp(#)} max decimal places for small p-values (p < 0.10); default 3{p_end}

{phang}
{opt ref:cat(string)} label for reference-category rows. Default {cmd:"Reference"}{p_end}

{phang}
{opt omitl:abel(string)} label for a coefficient the model dropped, which Stata
reports as {cmd:(omitted)} -- most often a level or term dropped for
collinearity. Default {cmd:"Omitted"}{p_end}

{phang}
{opt emptyl:abel(string)} label for a factor cell that identifies no observations
in the estimation sample, which Stata reports as {cmd:(empty)}; default {cmd:"Empty"}{p_end}

{phang}
{opt relab:el} relabel random effects using variable labels and parameter types (see Remarks){p_end}

{phang}
{opt sep(string asis)} CI-endpoint delimiter for {cmd:collect}; default {cmd:", "}{p_end}

{phang}
{opt sheet(string)} target sheet to create/replace in {opt xlsx()}. Default {cmd:"Regression"}{p_end}

{phang}
{opt stars} add significance stars to coefficients (*, **, ***){p_end}

{phang}
{opt starsl:evels(numlist)} custom p-value thresholds for stars; exactly 3 values (default 0.05 0.01
0.001){p_end}

{phang}
{opt stats(string)} model-fit statistics rows: {cmd:n}, {cmd:events},
{cmd:groups}, {cmd:mi_m}, {cmd:aic}, {cmd:qic}, {cmd:bic}, {cmd:ll}, {cmd:icc},
{cmd:r2}, {cmd:r2_a}, {cmd:rmse}, {cmd:F}, {cmd:fmi}. The {cmd:qic} API name displays Pan's
fixed-penalty approximation as {cmd:QICu} for {cmd:xtgee} fits whose
dispersion is fixed at 1 (see Remarks). Rows always appear in that order,
whatever the order of the tokens: counts first (Observations or Subjects,
Events, Groups, Imputations), then likelihood criteria (AIC, QICu, BIC,
Log-likelihood), then ICC, R², and the linear-model rows (Adjusted
R², Root MSE, F statistic), with Largest FMI last. A row whose statistic no
collected model reports is omitted, and a model that does not report it has a
blank cell:{p_end}
{p2colset 9 24 26 2}{...}
{p2col:{cmd:events}}"Events", {cmd:e(N_fail)} (%12.0fc); survival models
({cmd:stcox}, {cmd:streg}, {cmd:stcrreg}) only{p_end}
{p2col:{cmd:r2_a}}"Adjusted R²", {cmd:e(r2_a)} (%5.3f); the {cmd:r2} token
still falls back to it when a model has neither {cmd:e(r2)} nor {cmd:e(r2_p)}{p_end}
{p2col:{cmd:rmse}}"Root MSE", {cmd:e(rmse)} (%9.3f), the N-k divisor Stata
reports; blank for models without it{p_end}
{p2col:{cmd:F}}"F statistic", {cmd:e(F)} (%9.2f) for linear-model F tests
({cmd:regress}, {cmd:anova}, {cmd:areg}, {cmd:xtreg}, {cmd:ivregress},
{cmd:cnsreg}); blank for every other model, including a {cmd:svy: logit} that
stores a design-based {cmd:e(F)}{p_end}
{p2col:{cmd:mi_m}}"Imputations", {cmd:e(M_mi)} (%12.0fc) after {cmd:mi estimate}{p_end}
{p2col:{cmd:fmi}}"Largest FMI", {cmd:e(fmi_max_mi)} (%6.4f), the largest
fraction of missing information across coefficients, as {cmd:mi estimate}
reports it{p_end}
{p2colreset}{...}

{phang}
{opt title(string)} title written to {cmd:A1}, merged across the table; blank if omitted{p_end}

{phang}
{opt xlsx(string)} output Excel filename (must end with {cmd:.xlsx}); {opt excel()} is a synonym{p_end}

{phang}
{opt zebra} apply alternating light gray row shading{p_end}


{phang}
{opt headerc:olor(string)} custom header color (Stata color name or RGB triplet; default
{cmd:"219 229 241"}){p_end}

{phang}

{phang}
{opt zebrac:olor(string)} custom zebra color (Stata color name or RGB triplet; default
{cmd:"237 242 249"}){p_end}

{marker remarks}{title:Remarks}

{pstd}Prerequisites and expectations{p_end}
{p 4 8 2}- Run your models inside {cmd:collect:} or otherwise ensure the
relevant results are in the active {helpb collect}. {cmd:regtab} does not run models.{p_end}
{p 4 8 2}- {cmd:regtab} expects dimensions including {cmd:colname} and {cmd:cmdset}, and result items
{cmd:_r_b}, {cmd:_r_ci}, {cmd:_r_p}. It applies cell styles: {cmd:_r_b} as %4.2fc, {cmd:_r_ci} as
{cmd:sformat("(%s")} with {cmd:cidelimiter()}, and {cmd:_r_p} as %5.4f.{p_end}
{p 4 8 2}- Because {cmd:regtab} works through the active {cmd:collect}, it
intentionally updates the labels of {cmd:_r_b}, {cmd:_r_ci}, and {cmd:_r_p},
the cell styles, and the layout before export. The labels of every other
result it reads (the command, command line, and {cmd:vce} metadata, and the
{opt stats()} results) are restored exactly as found. If you need the
original collection layout unchanged for later commands, save or rebuild that
collection before running {cmd:regtab}.{p_end}
{p 4 8 2}- The CI delimiter is controlled by {opt sep()}; default {cmd:", "}. Example
alternative: {cmd:sep("; ")}.{p_end}
{p 4 8 2}- If {opt coef()} is not provided, {cmd:regtab} detects the display
scale per collected model from the collected command metadata and fills the
estimate header automatically. When models use different scales, estimate
headers are set per model and {cmd:r(coef_label)} returns {cmd:mixed}.{p_end}
{p 4 8 2}- Multi-equation models such as {cmd:mlogit}, {cmd:zip}, {cmd:zinb},
and {cmd:churdle} use the equation/outcome dimension in the row labels, so rows
read like {it:Partial response: Age z-score} or
{it:Inflation equation: Prior events} instead of collapsing repeated covariate
names across equations. For labeled multinomial outcomes, value labels are used
when available. {cmd:mlogit} is displayed as relative risk ratios (RRR) by
default; zero-inflated and hurdle models remain on their native coefficient
scale unless {opt coef()} and collection styling are supplied by the user.
A factor covariate keeps its header row inside each equation block, as in the
single-equation layout: {it:4: Sex} above the indented level rows
{it:4:   Male} (Reference) and {it:4:   Female}.{p_end}
{p 4 8 2}- {cmd:r(methods)} describes each model from its collected metadata,
not from the estimate header: the estimates the model reports (Odds ratios,
Hazard ratios, Coefficients, ...; a {opt coef()} or {opt cdisc} relabel does
not change it), the model named from the command, the {cmd:glm}/{cmd:xtgee}
family and link, and the survival metric (probit regression, negative binomial
regression, complementary log-log regression, gamma regression with a log link,
zero-inflated Poisson regression, ordered logistic regression, linear
mixed-effects regression, mixed-effects logistic regression, generalized
estimating equation (GEE) logistic regression, Fine-Gray competing-risks
regression, heteroskedastic probit regression, quantile regression,
instrumental-variables regression, ...), and "univariable" (one predictor
variable) or "multivariable", counting a factor variable once and counting
the covariates of a variance equation (such as {cmd:hetprobit}'s
{cmd:het()}). Prefixes are named:
survey-weighted ..., ... with multiple imputation, ... with bootstrap (or
jackknife) standard errors. Several models list each distinct model once
("univariable and multivariable logistic regression across 2 models").
Collections mixing estimate scales keep the generic sentence "Collected
regression estimates with #% confidence intervals across # models.".{p_end}
{p 4 8 2}- Model header labels are auto-generated unless {opt models()} supplies
explicit names. {opt models()} values are split on the backslash character.{p_end}
{p 4 8 2}- {opt coef()}: if omitted, the estimate-column header and scale are
auto-detected per collected model: {cmd:logit}/{cmd:logistic} {it:->} OR,
{cmd:mlogit} {it:->} RRR, {cmd:stcox} {it:->} HR, {cmd:poisson}/{cmd:nbreg}
{it:->} IRR, {cmd:stcrreg} {it:->} SHR, {cmd:streg}/{cmd:mestreg} {it:->} HR in
the log-hazard metric and TR in the log-time metric, {cmd:regress}/{cmd:mixed}
{it:->} Coef. A ratio family is always shown on its ratio scale: a fit displayed
as coefficients ({cmd:logit} without {cmd:or}, {cmd:logistic} with
{cmd:coef}, {cmd:stcox} or {cmd:streg} with {cmd:nohr}, {cmd:stcrreg} with
{cmd:noshr}, or a log-time {cmd:streg} without {cmd:tr}) is exponentiated, and a fit Stata already
exponentiated is left as it is, so the header always names the numbers under
it. Display options are read only from the option list after the command's
comma, with the estimator's own abbreviations ({cmd:ir}, {cmd:rr}, {cmd:ti},
{cmd:tr}), so a covariate named {cmd:or} is never mistaken for the option.
Estimation prefixes are set aside, alone or nested: {cmd:svy:},
{cmd:bootstrap:} ({cmd:bs:}, {cmd:bstrap:}), {cmd:jackknife:} ({cmd:jknife:}),
and {cmd:mi estimate:}. {cmd:svy: logit}, {cmd:bootstrap: logit}, and
{cmd:jackknife: poisson} are classified like {cmd:logit} and {cmd:poisson}
(OR or IRR, intercept suppressed), and a prefix's own options, such as
{cmd:subpop()} or {cmd:reps()}, are never read as the command's display
options. An eform option given to {cmd:bootstrap} or {cmd:jackknife}
({cmd:bootstrap, eform: logit}) counts like the command's own {cmd:or}.
{cmd:mi estimate} reports the coefficient metric whatever the fitted command's
display options, unless {cmd:mi estimate} itself is given an eform option
({cmd:or}, {cmd:hr}, {cmd:irr}, ...; see {helpb mi estimate}), so
{cmd:regtab} reads that rule from {cmd:e(cmdline_mi)}: {cmd:mi estimate: logit}
and {cmd:mi estimate, or: logit} both show odds ratios, never exponentiated
twice. Intervals are the ones {cmd:mi estimate} computed, on a t reference
distribution with each coefficient's own degrees of freedom
({cmd:e(df_mi)}); {cmd:mi estimate} reports no log likelihood, so the
{cmd:ll}, {cmd:aic}, and {cmd:bic} rows stay blank. A {cmd:level()} given to
{cmd:mi estimate} or {cmd:bootstrap} counts as the model's level.{p_end}
{p 4 8 2}- {cmd:streg} and {cmd:mestreg} follow Stata's metric rules
(exponential and Weibull fit in the log-hazard metric, HR, unless {cmd:time} or
{cmd:tr} is given; Gompertz is log-hazard only; lognormal, loglogistic, and
generalized gamma are log-time only), and the log-time metric is shown as TR,
the exponentiated log-time coefficients.{p_end}
{p 4 8 2}- {cmd:glm} and {cmd:xtgee} are resolved from their
{opt family()} and {opt link()} rather than the command name, with glm's own
abbreviations ({cmd:f(b)}, {cmd:fam(bin)}, {cmd:l(logit)}, {cmd:ef}), so
{cmd:family(binomial)} or {cmd:family(bernoulli)} with the default or
{cmd:link(logit)} {it:->} OR, and {cmd:family(poisson)} with the default or
{cmd:link(log)} {it:->} IRR. Both are shown exponentiated and drop the
intercept row. Another family/link fitted with {cmd:eform} keeps glm's
exponentiated values under RR (binomial, log link), IRR (negative binomial,
log link), or exp(b); without {cmd:eform} it stays on the coefficient scale
with the {cmd:Coef.} header. {cmd:xtgee} takes the same options and defaults, so a
GEE fit gets the header, scale, and intercept rule that {cmd:glm} gets for the
same family and link. Supply {opt coef()} to label it yourself.{p_end}
{p 4 8 2}- All collected models must share one confidence level, because one
"#% CI" header labels every model. Models fitted with different {opt level()}
values (a model without {opt level()} counts as the current {cmd:set level})
are refused with an error.{p_end}
{p 4 8 2}- {opt relab:el}: relabels random effects using variable labels and explicit
parameter types. For single-level models {cmd:var(_cons)} becomes
{it:Variance: GroupLabel (Intercept)} and {cmd:cov(x,_cons)} becomes
{it:Covariance: GroupLabel (X label, Intercept)}; multi-level models label each
level separately. The {cmd:me}{it:*} estimators are labelled the same way:
{cmd:var(x[clinic])} becomes {it:Variance: Clinic label (X label)} and
{cmd:cov(x[clinic],_cons[clinic])} becomes
{it:Covariance: Clinic label (X label, Intercept)}. With differing grouping structures and no {opt relab:el},
the generic collection labels such as {cmd:var(_cons)} and {cmd:var(e)} are
retained rather than assigning a group label from another model. If {opt relab:el}
is requested with ambiguous random-effects metadata, {cmd:regtab} exits with
error 459 unless {opt nore:effects} suppresses random-effects rows.{p_end}
{p 4 8 2}- {opt eplotframe()}: stores a graph-ready companion frame for {helpb eplot} containing
{cmd:label}, {cmd:estimate}, {cmd:ll}, {cmd:ul}, {cmd:pvalue}, {cmd:model}, {cmd:model_label}, {cmd:rowtype}, and source-row
metadata. When {opt frame()} is also set, the display frame records the companion in
{cmd:_dta[tabtools_eplotframe]}.{p_end}
{p 4 8 2}- Frame provenance: requested display and eplot frames store the CI
level, ordered statistic IDs, model count, and per-model command identity,
outcome identity, effect scale, and display label as {cmd:_dta[tabtools_*]}
characteristics. {helpb comptab} uses these identities to align compatible
sources and rejects ambiguous or conflicting metadata.{p_end}
{p 4 8 2}- {opt addrow()}: appends custom label/value rows below the table body; separate
multiple rows with a backslash, e.g.,
{cmd:addrow("P trend" 0.032 0.041 \ "P interaction" 0.15 0.22)}.{p_end}
{p 4 8 2}- {opt labelwidth()}: caps the label-column width (in characters, default
45); labels longer than the cap wrap onto extra lines rather than being
clipped by the adjacent estimate cell.{p_end}
{p 4 8 2}- {opt dimnonsig}: dims rows whose every displayed fixed-effect CI
includes the null (1 for ratio scales, 0 for coefficients); reference, omitted,
and empty rows are always dimmed and category headers dim unless a level is
significant.{p_end}

{pstd}Notes on output shaping{p_end}
{p 4 8 2}- Constrained rows: a base category, a term dropped for collinearity,
and a factor cell identifying no observations all reach the table as a 0 (a 1
after {cmd:eform}) with an empty CI and an empty p-value. {cmd:regtab} tells
them apart from the constraint class the collection records for each
coefficient and substitutes {it:Reference}, {it:Omitted}, or {it:Empty} in the
estimate column, spanning that model's CI and p-value cells. The class is read
per model, so a level one model dropped keeps its estimate in the models that
retained it. Change the words with {opt refcat()}, {opt omitlabel()}, and
{opt emptylabel()}; the three must differ. Where the collection carries no
class, {cmd:regtab} labels a constrained factor level {it:Reference}. Stata 17's
{cmd:collect} records every constrained cell of some fits as empty --
{cmd:nbreg}, {cmd:zinb}, {cmd:intreg}, and {cmd:streg} with an ancillary
parameter -- although the model reports the level as {cmd:(base)}; a model whose
only recorded class is empty is treated as carrying no class. Such a collection
cannot separate a base cell from a genuinely empty or collinear one, so in an
interaction under these estimators every constrained cell reads
{it:Reference}. A
collection whose raw row identities cannot be read is rejected before output.{p_end}
{p 4 8 2}- Equations with nothing estimated: in a multi-equation model such as
{cmd:mlogit}, the base-outcome equation constrains every one of its
coefficients. It carries no information and is dropped whole, so its levels
cannot be misread as reference categories of the equations that were
estimated.{p_end}
{p 4 8 2}- Interaction rows: an interaction term heads a single parent row for
all of its level combinations, named for the interacted variables
({cmd:grp#sex}).{p_end}
{p 4 8 2}- Random-effects variance components ({cmd:var()}, {cmd:cov()},
{cmd:sd()}) from {cmd:mixed}, {cmd:melogit}, {cmd:mepoisson}, and similar
commands use the same {opt digits()} precision as the main coefficient
rows. Random-effects rows can be removed entirely with {opt nore}.{p_end}
{p 4 8 2}- Intercept, ordered cutpoint, and ancillary-only rows can be removed with
{opt noint}. Use {opt keepintercept} plus {opt cutlabels()} if you intentionally want
ordered-model cutpoints displayed with publication-friendly labels.{p_end}
{p 4 8 2}- P-value columns can be removed from the rendered table with
{opt nopvalue}. If {opt stars} is also specified, significance stars are still
computed from the collected p-values before the p-value columns are dropped.{p_end}
{p 4 8 2}- By default, fonts are set to Arial 10, but this can be overridden by
{opt font()}, {opt fontsize()}, or session defaults set with
{helpb tabtools:set font} / {helpb tabtools:set fontsize}. Borders
are drawn around the table and model blocks. Column widths and row heights are
adjusted heuristically to fit labels and contents: each model's estimate,
confidence-interval, and p-value columns are sized from that model's own cells,
so a model with wide estimates does not widen the others, and a model header
longer than its block wraps onto extra header lines.{p_end}
{p 4 8 2}- The command writes Excel and Markdown output through the shared tabtools
Mata {cmd:xl()} backend and then applies formatting in the same workbook session.{p_end}
{p 4 8 2}- Model statistics ({opt stats()}): For multi-model tables, N, AIC, BIC, QICu,
log-likelihood, and groups are extracted per model from the {helpb collect} framework
and placed in each model's column. If collection-based statistics extraction
fails, {cmd:regtab} exits with error 459 rather than substituting active
{cmd:e()} values. Statistics that are not defined for a model family remain
blank. For GEE models
({cmd:xtgee}), AIC is undefined because GEE uses quasi-likelihood rather than full
maximum likelihood. When dispersion is fixed at 1, a requested {cmd:aic} therefore
falls back to QICu ({cmd:deviance + 2p}); QICu can also be requested directly via
{cmd:stats(qic)}. Standard binomial and Poisson GEE fits use this fixed scale, and
continuous fits may request it explicitly with {cmd:scale(1)}. If {cmd:e(phi)}
is estimated or otherwise differs from 1, {cmd:regtab} leaves QICu unavailable
rather than divide each candidate model by a different scale. The {cmd:qic}
option and {cmd:r(qic_}{it:#}{cmd:)} names are retained for backward
compatibility. ICC is computed per model from variance components in the
collected results when that variance decomposition is defined. Latent-response
ICC uses the link-specific level-1 variance
(logit: {cmd:pi^2/3}; probit: 1; complementary log-log: {cmd:pi^2/6}). For
model families without a defined level-1 variance, ICC is left blank rather
than guessed. If the collection yields no usable ICC components for supported
models, {cmd:regtab} exits with error 459 rather than substituting active
{cmd:e(b)} values.{p_end}

{marker examples}{title:Examples}

{pstd}Logistic regression with odds ratios:{p_end}
{phang2}{cmd:. webuse nhanes2, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: logit diabetes age female i.race bmi highbp}{p_end}
{phang2}{cmd:. regtab, xlsx(regression.xlsx) sheet("Diabetes") ///}{p_end}
{phang3}{cmd:title("Odds Ratios for Diabetes") coef(OR)}{p_end}

{pstd}Multinomial logistic regression with outcome-specific RRR rows:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. xtile price_group = price, nq(3)}{p_end}
{phang2}{cmd:. label define price_group 1 "Low price" 2 "Middle price" 3 "High price"}{p_end}
{phang2}{cmd:. label values price_group price_group}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: mlogit price_group mpg weight, baseoutcome(1)}{p_end}
{phang2}{cmd:. regtab, xlsx(regression.xlsx) sheet("Multinomial") title("Price group model")}{p_end}

{pstd}
Rows are labeled by outcome and term (for example, {it:Middle price: Mileage (mpg)}),
and the estimate header is auto-detected as {cmd:RRR}.{p_end}

{pstd}Ordered logit with custom cutpoint labels:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. keep if !missing(rep78)}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: ologit rep78 mpg weight}{p_end}
{phang2}{cmd:. regtab, xlsx(regression.xlsx) sheet("Ordered") keepintercept ///}{p_end}
{phang3}{cmd:cutlabels("1 to 2 \ 2 to 3 \ 3 to 4 \ 4 to 5")}{p_end}

{pstd}
The number of labels may match however many cutpoints the ordered model
returns. Without {opt keepintercept}, {cmd:regtab} treats cutpoints like ancillary rows
and omits them from ratio-scale presentation tables.{p_end}

{pstd}Two models with merged headers, dropping the intercept row:{p_end}
{phang2}{cmd:. webuse nhanes2, clear}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: logit diabetes age female}{p_end}
{phang2}{cmd:. collect: logit diabetes age female i.race bmi highbp}{p_end}
{phang2}{cmd:. regtab, xlsx(regression.xlsx) sheet("Table 2") ///}{p_end}
{phang3}{cmd:models("Unadj \ Adj") coef("OR") title("Table 2. Odds ratios") noint}{p_end}

{pstd}The multilevel and survival examples below are workflow sketches: they assume
a fitted dataset in memory with the named outcome, exposure, and grouping
variables (for example {cmd:provider}, {cmd:district}, {cmd:school}). Substitute your own
model; for runnable public-data fits see the {helpb melogit}, {helpb mixed}, and {helpb stcox} manual
examples.{p_end}

{pstd}Mixed-effects logistic model with Median Odds Ratio and ICC:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: melogit outcome treated age female || provider:}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet("Mixed") title("Multilevel Model") ///}{p_end}
{phang3}{cmd:relabel stats(n icc groups)}{p_end}

{pstd}
This produces a table where the random intercept variance is automatically
converted to a Median Odds Ratio (MOR), {opt relabel} translates
{cmd:var(_cons[provider])} into a readable label using the variable label of
{cmd:provider}, and {opt stats()} appends N, ICC, and number of groups at the
bottom.{p_end}

{pstd}Multi-level linear mixed model with nested random effects:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: mixed outcome treatment age || district: || school:}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet("Nested") title("Table 3") relabel stats(n icc)}{p_end}

{pstd}
With {opt relabel}, each grouping level gets a separate label derived from its
variable label and the parameter type: {it:Variance: District (Intercept)},
{it:Variance: School (Intercept)}, {it:Residual Variance}. Without {opt relabel}, the raw
bracket notation is shown: {cmd:var(_cons[district])}, {cmd:var(_cons[school])},
{cmd:var(e)}. Random effects are sorted by level (outermost first) after fixed
effects. Models with random slopes and covariance terms (e.g.,
{cmd:|| school: treatment, cov(unstructured)}) produce additional rows such as
{it:Variance: School (Treatment)} and {it:Covariance: School (Treatment, Intercept)}.{p_end}

{pstd}Auto-detected coefficient labels and conditional formatting:{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: stcox treated age female i.education}{p_end}
{phang2}{cmd:. regtab, xlsx(results.xlsx) sheet("Cox") title("Cox Model") ///}{p_end}
{phang3}{cmd:noint boldp(0.05) highlight(0.05)}{p_end}

{pstd}
When {opt coef()} is omitted, {cmd:regtab} auto-detects the label from the model
type: {cmd:logit}/{cmd:logistic} {it:->} OR, {cmd:stcox} {it:->} HR,
{cmd:poisson}/{cmd:nbreg} {it:->} IRR, {cmd:stcrreg} {it:->} SHR, {cmd:mlogit} {it:->} RRR,
{cmd:zip}/{cmd:zinb}/{cmd:churdle} {it:->} Coef., {cmd:streg} (log-hazard metric) {it:->} HR,
{cmd:streg} (log-time metric) {it:->} TR, {cmd:regress}/{cmd:mixed} {it:->} Coef. The {opt boldp()}
option bolds p-value cells below the threshold, and {opt highlight()} applies yellow fill to entire
rows.{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:regtab} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in output table{p_end}
{synopt:{cmd:r(N_cols)}}number of columns in output table{p_end}
{synopt:{cmd:r(N_models)}}number of models{p_end}
{synopt:{cmd:r(ci_level)}}confidence level carried by the collected intervals{p_end}
{synopt:{cmd:r(aic_}{it:#}{cmd:)}}AIC for model {it:#} when requested{p_end}
{synopt:{cmd:r(bic_}{it:#}{cmd:)}}BIC for model {it:#} when requested{p_end}
{synopt:{cmd:r(qic_}{it:#}{cmd:)}}QICu for fixed-scale {cmd:xtgee} model {it:#}, when available{p_end}
{synopt:{cmd:r(icc_}{it:#}{cmd:)}}ICC for model #, when available{p_end}
{synopt:{cmd:r(ll_}{it:#}{cmd:)}}log-likelihood for model {it:#} (when {cmd:stats(ll)}){p_end}
{synopt:{cmd:r(n_}{it:#}{cmd:)}}sample size for model {it:#} (when {cmd:stats(n)}){p_end}
{synopt:{cmd:r(groups_}{it:#}{cmd:)}}number of groups for model {it:#} (when {cmd:stats(groups)}){p_end}
{synopt:{cmd:r(events_}{it:#}{cmd:)}}failures for model {it:#} (when {cmd:stats(events)}){p_end}
{synopt:{cmd:r(mi_m_}{it:#}{cmd:)}}imputations for model {it:#} (when {cmd:stats(mi_m)}){p_end}
{synopt:{cmd:r(r2_a_}{it:#}{cmd:)}}adjusted R² for model {it:#} (when {cmd:stats(r2_a)}){p_end}
{synopt:{cmd:r(rmse_}{it:#}{cmd:)}}root MSE for model {it:#} (when {cmd:stats(rmse)}){p_end}
{synopt:{cmd:r(F_}{it:#}{cmd:)}}linear-model F for model {it:#} (when {cmd:stats(F)}){p_end}
{synopt:{cmd:r(fmi_}{it:#}{cmd:)}}largest FMI for model {it:#} (when {cmd:stats(fmi)}){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(coef_label)}}shared or mixed coefficient label{p_end}
{synopt:{cmd:r(methods)}}auto-generated methods paragraph{p_end}
{synopt:{cmd:r(stars)}}stars option value{p_end}
{synopt:{cmd:r(frame)}}frame name (if {cmd:frame()} specified){p_end}
{synopt:{cmd:r(eplotframe)}}graph-ready companion frame name{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}numeric displayed-body coefficients{p_end}
{p2colreset}{...}

{pstd}{cmd:r(table)} excludes the title and any appended stats/addrows. Row names are
derived from each variable's display label with periods, spaces, commas, and
colons replaced by underscores or stripped, then truncated to 32 characters.
A name that Stata's matrix row-name rules reject or rewrite (a bracketed
random-effects key such as {cmd:var(x[clinic])}, or {cmd:cov(x_cons)}, which
Stata reads back as {cmd:var(x_cons)}) instead has every character other than
letters, digits, and underscores replaced by an underscore. Names are then
made unique in row order: when a name repeats an earlier one (two variables
labelled alike, labels differing only in punctuation, or labels sharing their
first 32 characters), it takes the first free suffix {cmd:_2}, {cmd:_3}, ...,
with the base shortened so the name stays within 32 characters. Row {it:j} of
{cmd:r(table)} is always row {it:j} of the displayed body.{p_end}

{pstd}The per-model statistic scalars ({cmd:r(aic_}{it:#}{cmd:)},
{cmd:r(bic_}{it:#}{cmd:)}, {cmd:r(qic_}{it:#}{cmd:)}, {cmd:r(icc_}{it:#}{cmd:)},
{cmd:r(ll_}{it:#}{cmd:)}, {cmd:r(n_}{it:#}{cmd:)}, {cmd:r(groups_}{it:#}{cmd:)})
carry the full-precision values; the corresponding rows in the displayed table
and {cmd:r(table)} are rounded for presentation. Only the scalars for the
statistics actually requested in {opt stats()} (and available for the model
family) are posted.{p_end}

{pstd}
{cmd:AIC} and {cmd:BIC} are recomputed from the log-likelihood, parameter count,
and N as {cmd:AIC = -2*ll + 2*k} and {cmd:BIC = -2*ll + k*ln(N)}, rather than
read from {cmd:e(aic)}/{cmd:e(bic)}, which {cmd:glm}/GEE backends store on an
incomparable per-observation or deviance scale. {cmd:k} is the number of
estimated free parameters, whatever the variance estimator. That is
{cmd:e(rank)}, under a robust-type {cmd:vce()} too: it leaves out base levels,
omitted levels and the base outcome equation of {cmd:mlogit}, nets out linear
constraints, and gives the values {helpb estat ic} reports. The one exception
is a robust-type {cmd:vce()} ({cmd:cluster}, {cmd:robust}, {cmd:bootstrap},
{cmd:jackknife}, {cmd:linearized}) over too few clusters, GEE panels, or
replications. The sandwich variance then has rank at most G-1 (G clusters or
panels) or R-1 (R replications); when that cap is below the number of
collected coefficients with a nonzero standard error (outside the derived
{cmd:_diparm} parameters; collect stores the standard error of a base or
omitted level, or of a coefficient fixed by a constraint, as 0), {cmd:k} is
that number. {bf:Divergence from estat ic:} in that capped case
{helpb estat ic} uses the capped {cmd:e(rank)} (for example df = 1 for a
{cmd:logit} with four coefficients and {cmd:vce(cluster)} on two clusters),
while {cmd:regtab} counts four, so its AIC and BIC equal those of the same
model fitted with the model-based variance. The likelihood itself does not
depend on {cmd:vce()}. The collection does not hold {cmd:e(Cns)}, so in the
capped case a constraint fixing a coefficient at a value is netted out (its
standard error is 0) but an equality constraint between coefficients is not:
{cmd:constraints()} with {cmd:mpg = weight} and {cmd:vce(cluster)} on two
clusters counts four, where the model-based fit has three. A robust variance
that is rank deficient for another reason while the cap is not below that
number keeps {cmd:e(rank)}, as {helpb estat ic} does.{p_end}

{pstd}
{cmd:QICu} is {it:not} a likelihood criterion and does not come from
{helpb estat ic}. GEE fits a quasi-likelihood, so no log-likelihood is
available. For an {cmd:xtgee} fit with {cmd:e(phi)=1}, {cmd:regtab} reports
{cmd:deviance + 2*k}, where {cmd:k} is the number of regression parameters,
counted as for AIC above (Pan's penalty is 2p, p the number of parameters, so
a robust {cmd:vce()} over few panels does not shrink it). This
is a deviance-scale representation of QICu; it can differ from another
implementation's absolute QICu by a data-only additive constant, while
within-data model differences agree. Values are on a different scale from AIC
and BIC and must not be compared with them.{p_end}

{pstd}
{bf:Which criterion this is.} {cmd:deviance + 2*k} is Pan's {bf:QICu}, the
fixed-penalty approximation to QIC, {it:not} QIC itself. Pan's QIC is
{cmd:-2Q(b,I) + 2*trace(Omega*Sigma)}, whose penalty is a trace of the
independence-model information times the robust sandwich variance; {cmd:QICu}
replaces that trace with {cmd:k}, and that difference carries a real
restriction: {bf:QICu} compares only models sharing a working correlation structure. Candidates
must use the same outcome observations, weights,
family, link, clustering, and working correlation and differ only in the mean
specification. QICu must {it:not} be used to choose a working correlation
structure; that is precisely the job the trace penalty does and this
approximation drops.{p_end}

{pstd}
{bf:Dispersion boundary.} When dispersion is unknown, Pan's definition uses
one common scale estimate for every candidate model (typically from the
largest mean model). Dividing each model's quasi-likelihood by its own
{cmd:e(phi)} would make the comparison invalid. Because {cmd:regtab} formats an
existing collection and cannot prove that a common external scale was used, it
computes QICu only when each candidate's stored scale is 1. This includes
standard binomial and Poisson GEE fits and continuous fits estimated with
{cmd:scale(1)}. Otherwise it prints a note and leaves the QICu row and
{cmd:r(qic_}{it:#}{cmd:)} absent. Use a dedicated QIC implementation with one
explicit common scale for estimated-dispersion comparisons. The stored result
keeps the name {cmd:r(qic_}{it:#}{cmd:)} for backward compatibility; read it as
QICu.{p_end}

{pstd}
See Pan W (2001), Akaike's information criterion in generalized estimating
equations, {it:Biometrics} 57:120-125; and Cui J (2007),
QIC program and model selection in GEE analyses, {it:Stata Journal}
7(2):209-220.{p_end}

{marker seealso}{...}
{title:Also see}

{pstd}{helpb effecttab} for treatment effects and margins tables{p_end}
{pstd}{helpb tabtools} for suite overview and persistent formatting defaults{p_end}
{pstd}{helpb collect} for the underlying collection framework{p_end}
{pstd}{helpb tabtools_tips} for quick reference{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}

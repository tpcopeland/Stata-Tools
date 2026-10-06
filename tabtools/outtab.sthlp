{smcl}
{viewerjumpto "Syntax" "outtab##syntax"}{...}
{viewerjumpto "Description" "outtab##description"}{...}
{viewerjumpto "Options" "outtab##options"}{...}
{viewerjumpto "Examples" "outtab##examples"}{...}
{viewerjumpto "Stored results" "outtab##stored"}{...}
{viewerjumpto "References" "outtab##references"}{...}
{viewerjumpto "Author" "outtab##author"}{...}
{vieweralsosee "tabcell" "help tabcell"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{title:Title}

{phang}
{bf:outtab} {hline 2} Binary outcomes by a binary exposure: events/N (%) per group and one ratio per model


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:outtab} {it:outcomes} {ifin}{cmd:,}
{opt exp:osure(varname)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Models}
{synopt:{opt mod:els(spec \ spec ...)}}covariates per model; {cmd:""} is crude{p_end}
{synopt:{opt modell:abels(lab \ lab ...)}}model labels for the column headers{p_end}
{synopt:{opt est:imator(cmd[, options])}}estimation command; see Options{p_end}
{synopt:{opt eform}}exponentiate estimate and limits{p_end}
{synopt:{opt mine:vents(#)}}fit only with # or more exposed events{p_end}
{synopt:{opt mint:ext(text)}}text when {opt minevents()} is not met; default {cmd:–}{p_end}
{synopt:{opt nonconv:text(text)}}text for a non-converged fit{p_end}
{synopt:{opt drop:text(text)}}text when the estimator drops rows{p_end}
{synopt:{opt fail:text(text)}}text for a failed fit{p_end}

{syntab:Rows and cells}
{synopt:{opt pan:els(varlist)}}0/1 sample indicators, one panel each{p_end}
{synopt:{opt obs:prefix(prefix)}}restrict outcome {it:y} to {it:prefix}{it:y}{cmd:==1}{p_end}
{synopt:{opt groupl:abels(exposed \ comparator)}}group labels; default value labels{p_end}
{synopt:{opt ratiol:abel(text)}}ratio name in the headers; default {cmd:RR}{p_end}
{synopt:{opt f:ormat(%fmt)}}format of ratios and limits; default {cmd:%4.2f}{p_end}
{synopt:{opt sep(string)}}separator between the limits; default {cmd:", "}{p_end}
{synopt:{opt small:cells(#)}}mask counts 1 to #-1 as {cmd:<}#{p_end}
{synopt:{opt nosmall:cells}}ignore the session default{p_end}

{syntab:Output}
{synopt:{opt xlsx(filename)}}Excel workbook (also {opt excel()}){p_end}
{synopt:{opt sh:eet(string)}}sheet name{p_end}
{synopt:{opt ti:tle(string)}}title{p_end}
{synopt:{opt foot:note(string)}}footnote, passed to {helpb puttab} unchanged{p_end}
{synopt:{opt csv(filename)}}CSV file{p_end}
{synopt:{opt mark:down(filename)}}Markdown file{p_end}
{synopt:{opt mdapp:end}}append to the Markdown file{p_end}
{synopt:{opt fra:me(name[, replace])}}save the table in a frame{p_end}
{synopt:{opt border:style()}, {opt headers:hade}, {opt font()}, {opt fontsize()}}passed to {helpb puttab}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:outtab} tabulates 0/1 outcomes by a 0/1 exposure. Each row is one
outcome (within each panel when {opt panels()} is given) and shows
events/N (%) in the exposed group (exposure = 1), then in the comparator group
(exposure = 0), then one ratio with its confidence interval per model
specification. Each model is fitted with {opt estimator()} on the row's
sample, as {it:cmd outcome exposure covariates} {cmd:if} {it:sample}{cmd:,} {it:options}, and
the exposure's estimate and limits are read from {cmd:r(table)} and formatted
with {helpb tabcell}. The table is written by {helpb puttab}, so the
Excel, CSV, and Markdown output and {opt frame()} share its layout: a
{cmd:rowlabel} variable and string columns whose variable labels are the headers.

{pstd}
A fit that fails, does not converge ({cmd:e(converged)} is 0), or cannot
estimate the exposure prints text instead of a number. The active estimation
results are held and restored, so {cmd:outtab} leaves {cmd:e()} as it found it.


{marker options}{...}
{title:Options}

{phang}
{opt exposure(varname)} is the 0/1 exposure. Other values are refused, as are
outcomes or panel indicators that are not 0/1. Observations with a missing
outcome are left out of that outcome's row.

{phang}
{opt models(spec \ spec ...)} lists the covariates of each model, separated by
{cmd:\}; {cmd:""} is the model with the exposure alone. The default is one crude
model. {opt modellabels()} names them in the headers ("Crude, RR (95% CI)").

{phang}
{opt estimator(cmd[, options])} is the estimation command and its options, for
example {cmd:estimator(poisson, irr vce(cluster id))} for risk ratios by
modified Poisson regression with variance clustered on the mother (Zou 2004). The
ratio is read from {cmd:r(table)} as the command reports it, so ask for
the ratio scale there ({cmd:irr}, {cmd:or}, {cmd:eform}) or give {opt eform}, not
both: {opt eform} with an estimator that already reports the ratio is an error. The
interval level is the estimator's ({cmd:level()} in its options, or
{cmd:c(level)}).

{phang}
{opt minevents(#)} fits the models of a row only when the exposed group has at
least # events; otherwise the model cells show {opt mintext()}.

{phang}
{opt nonconvtext()} and {opt failtext()} set the text of a non-converged or
failed fit; in {opt failtext()}, {cmd:#} becomes the return code. A fit whose
exposure coefficient is omitted or has no variance, or whose fitted sample has
no events in the exposed or the comparator group (a boundary estimate that
converges to a huge negative or positive coefficient), prints {cmd:not estimable}.

{phang}
Adjusted models are complete-case: each model is fitted on the analysis rows
with every covariate in its specification observed, while the events/N columns
are crude counts on all analysis rows (outcome and exposure observed, in the
panel and {opt obsprefix()} sample). {opt droptext(text)} is printed, instead
of a ratio, when the estimator itself drops rows of that complete-case sample
({cmd:e(N)} below it, as with perfect prediction in {cmd:logit}); default
{cmd:not estimable (sample reduced)}. Listwise loss from missing covariates
does not trigger it; compare {cmd:N} and {cmd:N_cc} with the counts in
{cmd:r(fits)}.

{phang}
{opt panels(varlist)} gives 0/1 sample indicators; each is one panel, headed by
its variable label, with all outcomes fitted on the observations where it is 1.

{phang}
{opt obsprefix(prefix)} restricts the row of outcome {it:y} to
observations with {it:prefix}{it:y} == 1, for outcomes evaluable only in part of
the sample. The variable must exist for every outcome.

{phang}
{opt format()}, {opt sep()}, and {opt ratiolabel()} format the ratio cells and
their headers, as in {helpb tabcell}; {opt sep()} prints as typed in every
output, see {help tabtools##sep:interval separators}.

{phang}
{opt smallcells(#)} prints events or totals from 1 to #-1 as {cmd:<}# (through
{cmd:tabcell enp, mincell()}) and withholds that row's ratios. It masks printed
counts only; {cmd:r(table)} keeps the numbers, and complementary suppression
across rows is not done. Without it, a session default set with
{cmd:tabtools set smallcells #} applies and is echoed; {opt nosmallcells}
ignores it.


{phang}
{opt groupl:abels(exposed \ comparator)} names the two groups in the column
headers, the exposed group (exposure = 1)
first: {cmd:grouplabels("Smokers" \ "Non-smokers")} gives the headers
"Smokers, events/N (%)" and "Non-smokers, events/N (%)". Exactly two labels
are required. The default is the value labels of 1 and 0 of the exposure
variable, or {it:exposure} = 1 and {it:exposure} = 0 when it has none.

{phang}
{opt xlsx(filename)} writes the table to an Excel workbook through
{helpb puttab}; the filename must end in {cmd:.xlsx}. The sheet is created, or
replaced if it exists, so repeated calls build a multi-sheet
workbook. {opt excel(filename)} is a synonym for {opt xlsx()}; when both are given,
{opt xlsx()} is used and {opt excel()} is ignored. {cmd:r(xlsx)} holds the
file. {opt sheet(string)} names the sheet; the default is {cmd:Table}.

{phang}
{opt title(string)} puts a title above the table: cell A1 of the sheet, the
first row of the CSV file, and a heading above the Markdown
table. {opt footnote(string)} adds a footnote below the table, passed to {helpb puttab}
unchanged: the token {cmd:\}, with a space on each side, separates paragraphs.

{phang}
{opt csv(filename)} also writes the table to a CSV file, which must end in
{cmd:.csv}. The CSV mirrors the workbook, with {opt title()} as the first row
and {opt footnote()} as the last.

{phang}
{opt mark:down(filename)} also writes the table as GitHub-Flavored Markdown,
replacing an existing file. {opt mdapp:end} adds the table to the end of the
existing file instead, after a blank line, so several tables can share one
file; it is ignored without {opt markdown()}.

{phang}
{opt fra:me(name[, replace])} also saves the table in the frame {it:name}: a
{cmd:rowlabel} variable and the string columns {cmd:c1}, {cmd:c2}, ..., whose
variable labels are the headers, ready for {helpb puttab}. An
existing frame is an error unless {cmd:replace} is given. {cmd:r(frame)}
holds the name.

{phang}
{opt border:style(string)}, {opt headers:hade}, {opt font(string)}, and
{opt fontsize(#)} style the Excel sheet and are passed to {helpb puttab}; see
{helpb puttab} for the details. {opt borderstyle()} is {cmd:default},
{cmd:thin}, {cmd:medium}, or {cmd:academic}; {cmd:default} and {cmd:thin} draw
a thin box around the table, {cmd:academic} draws horizontal rules
only. {opt headershade} fills the header row. {opt font()} is the font family and
{opt fontsize()} the size in points, 1 through 72. Without them the table
uses a thin border, no header fill, and 10-point Arial, or the session
defaults set by {cmd:tabtools set} ({helpb tabtools}), which an explicit option
overrides.

{pstd}
{opt sheet()}, {opt title()}, {opt footnote()}, and the styling options write
nothing by themselves: with none of {opt xlsx()}, {opt csv()}, and
{opt markdown()}, {cmd:outtab} only prints the table and fills
{opt frame()}. {opt sheet()}, {opt borderstyle()}, {opt headershade}, {opt font()}, and
{opt fontsize()} affect the workbook only.

{marker examples}{...}
{title:Examples}

{phang2}{cmd:. webuse lbw, clear}{p_end}
{phang2}{cmd:. generate byte light = bwt < 2000}{p_end}
{phang2}{cmd:. label variable light "Birth weight below 2,000 g"}{p_end}
{phang2}{cmd:. label variable low "Birth weight below 2,500 g"}{p_end}
{phang2}{cmd:. outtab low light, exposure(smoke) models("" \ "age lwt") modellabels("Crude" \ "Adjusted") estimator(poisson, irr vce(robust)) minevents(5)}{p_end}
{phang2}{cmd:. outtab low light, exposure(smoke) estimator(logit, or) ratiolabel("OR") frame(t2, replace)}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:outtab} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}rows of the table, panel headings included{p_end}
{synopt:{cmd:r(N_models)}}models{p_end}
{synopt:{cmd:r(N_outcomes)}}outcomes{p_end}
{synopt:{cmd:r(N_panels)}}panels (1 without {opt panels()}){p_end}
{synopt:{cmd:r(smallcells)}}small-cell threshold applied{p_end}
{synopt:{cmd:r(minevents)}}minimum exposed events{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(estimator)}}estimation command and options{p_end}
{synopt:{cmd:r(frame)}}frame name{p_end}
{synopt:{cmd:r(xlsx)}}Excel file{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}counts and ratios per row; see below{p_end}
{synopt:{cmd:r(fits)}}per-fit diagnostics; see below{p_end}


{pstd}
{cmd:r(table)} has one row per outcome row and the columns {cmd:n1 e1 n0 e0}, then
{cmd:b}#, {cmd:lb}#, {cmd:ub}#, {cmd:rc}# per model. {cmd:rc}# is 0 (fitted), 430 (did not converge),
459 (not estimable), -1 (below {opt minevents()}), -2 (the estimator dropped
complete-case rows; {opt droptext()}), or the return code of a failed fit.

{pstd}
{cmd:r(fits)} has one row per outcome row (in {cmd:r(table)} order) and model,
{cmd:row} and {cmd:model} identifying it, then the fit's {cmd:e(N)}, the
model's complete-case count {cmd:N_cc} (analysis rows with every covariate
observed; {cmd:N_cc} below {cmd:n1}+{cmd:n0} is listwise loss),
{cmd:e(N_clust)} (missing without clustering), {cmd:e(df_m)} and
{cmd:e(converged)}, and the code {cmd:rc} above. A model that was not fitted
(below {opt minevents()}, or a failed fit) has missing fit statistics.


{marker references}{...}
{title:References}

{phang}
Zou G. 2004. A modified Poisson regression approach to prospective studies with binary
data. American Journal of Epidemiology 159: 702-706.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
{helpb tabcell}, {helpb puttab}, {helpb ratetab}, {helpb tabtools}
{p_end}

{hline}

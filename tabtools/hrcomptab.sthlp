{smcl}
{* *! version 1.0.13  27apr2026}{...}
{viewerjumpto "Syntax" "hrcomptab##syntax"}{...}
{viewerjumpto "Description" "hrcomptab##description"}{...}
{viewerjumpto "Options" "hrcomptab##options"}{...}
{viewerjumpto "Examples" "hrcomptab##examples"}{...}
{viewerjumpto "Stored results" "hrcomptab##stored"}{...}
{viewerjumpto "Author" "hrcomptab##author"}{...}
{viewerjumpto "Also see" "hrcomptab##alsosee"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "comptab" "help comptab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{title:Title}

{phang}
{bf:hrcomptab} {hline 2} Compose a Table 2-style rate + hazard-ratio table from {cmd:stratetab} and {cmd:regtab} frames


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:hrcomptab}
{it:rateframe}
{cmd:,}
{opt modelframes(framelist)}
{cmd:rows(}{it:string}{cmd:)}
[{it:options}]

{p 8 17 2}
{cmd:hrcomptab}
{it:rateframe}
{cmd:,}
{opt modelframes(framelist)}
{cmdab:rown:ames(}{it:string}{cmd:)}
[{it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{it:rateframe}}frame created by {helpb stratetab} with {cmd:frame()}{p_end}
{synopt:{opt modelf:rames(framelist)}}space-separated list of frames created by {helpb regtab} with {cmd:frame()}{p_end}
{synopt:{opt rows(string)}}backslash-separated row specifications, one per model frame{p_end}
{synopt:{cmdab:rown:ames(}{it:string}{cmd:)}}alternative to {opt rows()}: select model rows by label pattern{p_end}

{syntab:Output}
{synopt:{opt xlsx(filename)}}Excel output file (.xlsx){p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx()}{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default {cmd:"Composite"}{p_end}
{synopt:{opt csv(filename)}}export to CSV file{p_end}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}save output in a named Stata frame; use {cmd:frame(name, replace)} to replace{p_end}
{synopt:{cmdab:dis:play}}show console preview; if no {opt xlsx()}, {opt csv()}, or {opt frame()} is supplied, preview is the default{p_end}
{synopt:{opt open}}open Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}

{syntab:Content}
{synopt:{opt title(string)}}table title for cell A1; defaults to the title stored in {it:rateframe}{p_end}
{synopt:{cmdab:foot:note(}{it:string}{cmd:)}}footnote text below the table{p_end}
{synopt:{opt eff:ect(string)}}header label for the effect column; default {cmd:aHR}{p_end}
{synopt:{opt refl:abel(string)}}text for inferred reference rows; default {cmd:Reference}{p_end}

{syntab:Formatting}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}journal theme: {it:lancet}, {it:nejm}, {it:bmj}, {it:apa}, {it:jama}, {it:plos}, {it:nature}, {it:cell}, {it:annals}, or {it:custom}{p_end}
{synopt:{cmdab:border:style(}{it:string}{cmd:)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt headers:hade}}shade the 2 header rows{p_end}
{synopt:{cmdab:headerc:olor(}{it:string}{cmd:)}}named Excel color or RGB triplet for header rows{p_end}
{synopt:{cmdab:zebrac:olor(}{it:string}{cmd:)}}named Excel color or RGB triplet for zebra shading{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:hrcomptab} is the missing second-stage command for workflows where
{helpb stratetab} already builds the descriptive incidence-rate scaffold and
separate {helpb regtab} calls already build adjusted Cox or competing-risk
models.

{pstd}
It keeps the row and outcome layout from the {cmd:stratetab} frame, adds two
columns per outcome ({it:effect} and {it:p-value}), and fills those columns
from selected rows of one or more {cmd:regtab} frames.

{pstd}
This is designed for the common manuscript workflow:

{p 8 12 2}
{bf:1.} run {cmd:stratetab, frame(...)} to create the events / person-years / rate table{p_end}
{p 8 12 2}
{bf:2.} run one or more {cmd:regtab, frame(...)} calls for adjusted models{p_end}
{p 8 12 2}
{bf:3.} run {cmd:hrcomptab} once to create the final Table 2-style sheet{p_end}

{pstd}
The command assumes the first indented category row within each {cmd:stratetab}
section is the reference category. Those rows receive {cmd:reflabel()} in every
effect column, and the selected {cmd:regtab} rows are mapped only to the
remaining non-reference rows.

{pstd}
The total number of selected model rows must therefore equal the number of
non-reference rows in the {cmd:stratetab} scaffold.

{pstd}
{cmd:hrcomptab} expects the rate frame to come from {cmd:stratetab} without
{cmd:rateratio}; the scaffold must contain one label column plus 3 columns per
outcome. Model frames must come from {cmd:regtab} and must contain exactly one
model block per outcome in the rate frame. Standard {cmd:regtab} frames
({it:estimate} | {it:CI} | {it:p}) and compact frames ({it:estimate+CI} | {it:p})
are both supported, but all model frames in one call must share the same layout.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{it:rateframe} is the frame created by {cmd:stratetab, frame(...)}. Its row
structure becomes the final table structure.

{phang}
{opt modelframes(framelist)} specifies the {cmd:regtab} source frames, in the
same logical order as the sections in {it:rateframe}. The selected rows are
stacked in frame order and injected into the non-reference rows of the scaffold.

{phang}
{opt rows(string)} specifies the rows to pull from each model frame. Use one
backslash-separated specification per frame. Row 1 is the first data row after
the 3 header rows in the {cmd:regtab} frame (blank title row, model-label row,
and column-header row).

{pmore}
Important: if a factor-variable block produces a heading row and a reference
row, those rows count in the numbering. For example, a frame with rows
{cmd:1 = "Dose category"}, {cmd:2 = "None"}, {cmd:3 = "Low"}, {cmd:4 = "High"}
would use {cmd:rows(... \ 3/4)} to select the two non-reference dose rows.

{phang}
{cmdab:rown:ames(}{it:string}{cmd:)} is an alternative to {opt rows()} that
matches case-insensitive substrings against the rendered labels in the first
column ({cmd:A}) of each model frame. Use one backslash-separated specification
per frame. Choose unambiguous tokens, or quote multi-word phrases, when labels
share common digits or prefixes.

{dlgtab:Content}

{phang}
{opt effect(string)} controls the header text for the injected effect column.
Default is {cmd:aHR}. Common alternatives are {cmd:HR}, {cmd:SHR}, or {cmd:IRR}.

{phang}
{opt reflabel(string)} controls the text shown in inferred reference rows.
Default is {cmd:Reference}.

{phang}
{opt display} prints a console preview. If no {opt xlsx()}, {opt csv()}, or
{opt frame()} target is supplied, {cmd:hrcomptab} defaults to preview mode.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Table 2 from existing stratetab/regtab frames}

{phang2}{cmd:. * Step 1: descriptive scaffold}{p_end}
{phang2}{cmd:. stratetab, using(edss4_tv edss6_tv recurring_tv ///}{p_end}
{phang3}{cmd:    edss4_dose edss6_dose recurring_dose) ///}{p_end}
{phang3}{cmd:    outcomes(3) frame(hrt_rates, replace) ///}{p_end}
{phang3}{cmd:    outlabels("Sustained EDSS 4" \ "Sustained EDSS 6" \ "Recurring Relapse") ///}{p_end}
{phang3}{cmd:    explabels("Binary HRT" \ "Estrogen Dose Category")}{p_end}

{phang2}{cmd:. * Step 2: adjusted binary model}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: stcox hrt_tv covars_for_edss4 ...}{p_end}
{phang2}{cmd:. collect: stcox hrt_tv covars_for_edss6 ...}{p_end}
{phang2}{cmd:. collect: stcox hrt_tv covars_for_relapse ...}{p_end}
{phang2}{cmd:. regtab, frame(hrt_bin, replace) noint coef("HR")}{p_end}

{phang2}{cmd:. * Step 3: adjusted dose-category model}{p_end}
{phang2}{cmd:. collect clear}{p_end}
{phang2}{cmd:. collect: stcox i.hrt_dosecat covars_for_edss4 ...}{p_end}
{phang2}{cmd:. collect: stcox i.hrt_dosecat covars_for_edss6 ...}{p_end}
{phang2}{cmd:. collect: stcox i.hrt_dosecat covars_for_relapse ...}{p_end}
{phang2}{cmd:. regtab, frame(hrt_dose, replace) noint coef("HR")}{p_end}

{phang2}{cmd:. * Step 4: final Table 2}{p_end}
{phang2}{cmd:. hrcomptab hrt_rates, modelframes(hrt_bin hrt_dose) ///}{p_end}
{phang3}{cmd:    rows(1 \ 3/5) effect("aHR") ///}{p_end}
{phang3}{cmd:    xlsx("HRT.xlsx") sheet("Table 2") ///}{p_end}
{phang3}{cmd:    title("Table 2. Hormone Replacement Therapy Events, Events per Person Year, and Adjusted Hazard Ratios") ///}{p_end}
{phang3}{cmd:    footnote("aHR, adjusted hazard ratio; CI, confidence interval.")}{p_end}

{pstd}
In this example, the {cmd:stratetab} frame contributes all section headers,
reference rows, events, person-years, and rate columns. The binary {cmd:regtab}
frame contributes 1 non-reference row, and the dose-category frame contributes
3 non-reference rows.

{pstd}
{bf:Example 2: Rowname matching instead of row numbers}

{phang2}{cmd:. hrcomptab hrt_rates, modelframes(hrt_bin hrt_dose) ///}{p_end}
{phang3}{cmd:    rownames("hrt" \ "low medium high") ///}{p_end}
{phang3}{cmd:    effect("aHR") display}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:hrcomptab} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in the output table{p_end}
{synopt:{cmd:r(N_outcomes)}}number of outcomes in the scaffold{p_end}
{synopt:{cmd:r(N_sections)}}number of scaffold sections{p_end}
{synopt:{cmd:r(N_modelrows)}}number of selected model rows injected{p_end}
{synopt:{cmd:r(N_modelframes)}}number of source model frames{p_end}

{p2col 5 22 28 2: Macros}{p_end}
{synopt:{cmd:r(rateframe)}}source stratetab frame name{p_end}
{synopt:{cmd:r(modelframes)}}source regtab frame names{p_end}
{synopt:{cmd:r(effect)}}effect header label used in the final table{p_end}
{synopt:{cmd:r(xlsx)}}Excel path, when exported{p_end}
{synopt:{cmd:r(sheet)}}Excel sheet name, when exported{p_end}
{synopt:{cmd:r(csv)}}CSV path, when exported{p_end}
{synopt:{cmd:r(frame)}}output frame name, when {cmd:frame()} specified{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.0.13{p_end}


{marker alsosee}{...}
{title:Also see}

{psee}
{helpb stratetab}, {helpb regtab}, {helpb comptab}, {helpb tabtools}
{p_end}

{hline}

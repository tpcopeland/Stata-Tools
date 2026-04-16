{smcl}
{* *! version 1.0.4  16apr2026}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "survtab" "help survtab"}{...}
{vieweralsosee "stcox" "help stcox"}{...}
{vieweralsosee "stcrreg" "help stcrreg"}{...}
{vieweralsosee "finegray" "help finegray"}{...}
{vieweralsosee "stptime" "help stptime"}{...}
{viewerjumpto "Package overview" "hrtab##package"}{...}
{viewerjumpto "Syntax" "hrtab##syntax"}{...}
{viewerjumpto "Description" "hrtab##description"}{...}
{viewerjumpto "Options" "hrtab##options"}{...}
{viewerjumpto "Remarks" "hrtab##remarks"}{...}
{viewerjumpto "Examples" "hrtab##examples"}{...}
{viewerjumpto "Stored results" "hrtab##stored"}{...}
{viewerjumpto "Author" "hrtab##author"}{...}
{title:Title}

{p2colset 5 14 16 2}{...}
{p2col:{cmd:hrtab} {hline 2}}Multi-panel hazard ratio table for publication{p_end}
{p2colreset}{...}


{marker package}{...}
{title:Package}

{pstd}
{cmd:hrtab} is part of the {helpb tabtools} suite. See also {helpb regtab} for general regression tables, {helpb stratetab} for incidence rate tables, and {helpb survtab} for Kaplan-Meier tables.

{hline}


{marker syntax}{...}
{title:Syntax}

{p 4 8 2}{cmd:hrtab} [{it:if}] [{it:in}]{cmd:,} {opt exp:osure(exp_spec [\ exp_spec ...])} {opt mod:el(string)} [{it:options}]{p_end}

{pstd}where {it:exp_spec} is a single factor-variable term:{p_end}

{p 8 12 2}{cmd:i.}{it:varname}{space 11}categorical (value labels used for row names){p_end}
{p 8 12 2}{cmd:ib}{it:#}{cmd:.}{it:varname}{space 7}categorical with explicit reference level{p_end}
{p 8 12 2}{cmd:c.}{it:varname}{space 11}continuous (single-row panel, per-unit effect){p_end}

{synoptset 32 tabbed}{...}
{synoptline}
{syntab:Required}
{synopt:{opt exp:osure(string)}}exposure variable(s), each becoming a row panel; multiple panels separated by backslash{p_end}
{synopt:{opt mod:el(string)}}estimation command: {cmd:stcox}, {cmd:stcrreg}, or {cmd:finegray}{p_end}

{syntab:Outcome specification}
{synopt:{opt out:come(varname [\...])}}failure indicator variable(s); each creates a column group{p_end}
{synopt:{opt time(varname [\...])}}analysis time variable(s); one per outcome or one shared{p_end}
{synopt:{opt failv:alue(# [\...])}}failure values for competing risks from a multi-level event variable{p_end}
{synopt:{opt censv:alue(#)}}value representing censoring in the outcome variable; default 0{p_end}
{synopt:{opt stsetopts(string)}}options passed to every {cmd:stset} call: {cmd:id()}, {cmd:origin()}, {cmd:enter()}, {cmd:scale()}, {cmd:exit()}{p_end}

{syntab:Model specification}
{synopt:{opt cov:ars(varlist [\...])}}covariate sets for adjusted models; each backslash-separated group adds one model column{p_end}
{synopt:{opt modelopts(string)}}options appended to every model call{p_end}
{synopt:{opt noun:adjusted}}suppress the unadjusted column; requires {cmd:covars()}{p_end}

{syntab:Content and display}
{synopt:{opt eff:ect(string)}}column header label for effect estimates; default {cmd:HR} for {cmd:stcox}, {cmd:SHR} for {cmd:stcrreg}/{cmd:finegray}{p_end}
{synopt:{opt nopy:time}}suppress the person-years column{p_end}
{synopt:{opt noev:ents}}suppress the events column{p_end}
{synopt:{opt pv:alue}}add a p-value column for each model{p_end}
{synopt:{opt dig:its(#)}}decimal places for effect estimates and CIs; default 2, range 1-4{p_end}
{synopt:{opt pyd:igits(#)}}decimal places for person-years; default 0{p_end}
{synopt:{opt pysc:ale(#)}}divide person-years by this factor for display; default 1{p_end}
{synopt:{opt level(#)}}confidence interval level; default 95{p_end}
{synopt:{opt nol:og}}suppress estimation command iteration logs{p_end}
{synopt:{opt dots}}display progress dots (one per model estimated){p_end}

{syntab:Labels}
{synopt:{opt outl:abels(string)}}column group headers, backslash-separated; must match number of outcome columns{p_end}
{synopt:{opt expl:abels(string)}}row panel headers, backslash-separated; must match number of exposure panels{p_end}
{synopt:{opt modell:abels(string)}}column labels for each model, backslash-separated{p_end}
{synopt:{opt refl:abel(string)}}text for the reference category; default {cmd:Ref.}{p_end}

{syntab:Excel and output}
{synopt:{opt xlsx(filename)}}Excel output file ({cmd:.xlsx}); existing sheets preserved{p_end}
{synopt:{opt sheet(string)}}sheet name; default {cmd:Results}{p_end}
{synopt:{opt title(string)}}title in cell A1, merged across table width{p_end}
{synopt:{opt sub:title(string)}}subtitle below title{p_end}
{synopt:{opt foot:note(string)}}footnote below table{p_end}
{synopt:{opt the:me(string)}}{cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{opt border:style(string)}}{cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt open}}open file after export{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt headers:hade}}header row shading{p_end}
{synopt:{opt headerc:olor(string)}}custom header RGB (e.g., {cmd:"219 229 241"}){p_end}
{synopt:{opt zebrac:olor(string)}}custom zebra RGB{p_end}
{synopt:{opt boldp(#)}}bold p-values below threshold; requires {cmd:pvalue}{p_end}
{synopt:{opt high:light(#)}}highlight rows where p < threshold{p_end}
{synopt:{opt csv(filename)}}also export as CSV{p_end}
{synopt:{opt fra:me(name)}}store in named Stata frame{p_end}
{synopt:{opt dis:play}}show formatted table in Results window{p_end}
{synopt:{cmdab:addr:ow(}{it:string asis}{cmd:)}}custom rows below table body{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:hrtab} automates the workflow of running multiple survival models across outcomes and exposure definitions, then assembling results into a single publication-ready table -- the standard "Table 2" in cohort studies.

{pstd}
For each outcome x exposure combination, {cmd:hrtab}:

{p 8 12 2}1. stsets the data (or uses existing stset for single-outcome mode){p_end}
{p 8 12 2}2. Computes person-years and events per exposure level via {helpb stptime}{p_end}
{p 8 12 2}3. Runs the unadjusted model (exposure only){p_end}
{p 8 12 2}4. Runs each adjusted model (exposure + covariate set){p_end}
{p 8 12 2}5. Extracts effect estimates, 95% CIs, and optionally p-values{p_end}

{pstd}
Results are arranged with outcomes as column groups and exposure definitions as row panels. Categorical exposures produce one row per level with a reference row; continuous exposures produce a single row.

{pstd}
Supported estimation commands: {helpb stcox}, {helpb stcrreg}, {helpb finegray}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt exp:osure(exp_spec [\ exp_spec ...])} specifies exposure variable(s), each becoming a row panel in the table. Accepts Stata factor-variable notation. Multiple panels are separated by backslash:

{phang3}{cmd:exposure(i.ht_ever)}{p_end}
{phang3}{cmd:exposure(i.ht_status \ i.ht_regimen \ ib0.ht_duration)}{p_end}
{phang3}{cmd:exposure(i.treatment \ c.cumulative_dose)}{p_end}

{pmore}
Categorical exposures ({cmd:i.} or {cmd:ib.}) produce rows for each level with person-years, events, and effect estimates. The base level displays "Ref." in effect columns.

{pmore}
Continuous exposures ({cmd:c.}) produce a single row showing the per-unit effect estimate. Person-years and events show the total across all observations (not stratified). Label the variable to control the row text (e.g., {cmd:label var dose_per10 "Dose, per 10 mg"}).

{phang}
{opt mod:el(stcox | stcrreg | finegray)} specifies the estimation command used for all models in the table.

{dlgtab:Outcome specification}

{phang}
{opt out:come(varname [\ varname ...])} specifies failure indicator variable(s). Two usage patterns:

{pmore}
Independent outcomes (separate binary indicators): {cmd:outcome(mi_event \ stroke_event)}. Each creates a column group. Requires matching {cmd:time()} entries.

{pmore}
Competing risks (single multi-level event variable): {cmd:outcome(event_type) failvalue(1 \ 2)}. Creates one column group per cause. Competing events are determined automatically.

{pmore}
If omitted, {cmd:hrtab} uses the existing stset (single-outcome mode, no column grouping header).

{phang}
{opt time(varname [\ varname ...])} specifies analysis time variable(s). One per outcome, or one shared across all outcomes. Required when {cmd:outcome()} is specified.

{phang}
{opt failv:alue(# [\ # ...])} specifies failure values for a multi-level event variable in competing risks analysis. Each value creates a column group. The command auto-generates {cmd:compete()} specifications. When {cmd:failvalue()} has >1 entry, {cmd:outlabels()} defaults to "Cause 1", "Cause 2", etc.

{phang}
{opt censv:alue(#)} specifies the value representing censoring in the outcome variable when using {cmd:failvalue()}. Default is 0. The command treats all values other than {cmd:censvalue} and the current {cmd:failvalue} as competing events.

{phang}
{opt stsetopts(string)} specifies options passed to every {cmd:stset} call: {cmd:id()}, {cmd:origin()}, {cmd:enter()}, {cmd:scale()}, {cmd:exit()}. {cmd:id()} is required for all models because person-time is computed via {cmd:stptime}.

{dlgtab:Model specification}

{phang}
{opt cov:ars(varlist [\ varlist ...])} specifies covariate sets for adjusted models. Accepts factor-variable notation. Each backslash-separated group adds one model column beyond the unadjusted.

{pmore}
{cmd:covars(age sex)} produces 2 columns: Unadjusted, Adjusted.{break}
{cmd:covars(age \ age sex i.comorbidity bmi)} produces 3 columns: Unadjusted, Model 2, Model 3.

{phang}
{opt modelopts(string)} specifies options appended after the comma in every model call (e.g., {cmd:modelopts(strata(center))} for stcox stratification, {cmd:modelopts(cluster(clinic_id))} for clustered SEs).

{phang}
{opt noun:adjusted} suppresses the unadjusted column, showing only adjusted model(s). Requires {cmd:covars()}.

{dlgtab:Content and display}

{phang}
{opt eff:ect(string)} specifies the column header label for effect estimates. Default: {cmd:HR} for {cmd:stcox}, {cmd:SHR} for {cmd:stcrreg}/{cmd:finegray}. Common alternatives: {cmd:aHR}, {cmd:IRR}.

{phang}
{opt nopy:time} suppresses the person-years column.

{phang}
{opt noev:ents} suppresses the events column.

{phang}
{opt pv:alue} adds a p-value column for each model. Off by default -- standard epi practice favors CIs over p-values in results tables.

{phang}
{opt dig:its(#)} specifies decimal places for effect estimates and CIs. Default 2. Range 0-6.

{phang}
{opt pyd:igits(#)} specifies decimal places for person-years. Default 0.

{phang}
{opt pysc:ale(#)} divides person-years by this factor for display. Default 1. Use {cmd:pyscale(1000)} to show thousands.

{phang}
{opt level(#)} specifies the confidence interval level. Default 95.

{phang}
{opt nol:og} suppresses estimation command iteration logs.

{phang}
{opt dots} displays progress dots (one per model estimated).

{dlgtab:Labels}

{phang}
{opt outl:abels(string)} specifies column group headers, backslash-separated. Must match number of outcome columns (e.g., {cmd:outlabels("MI" \ "Stroke")}).

{phang}
{opt expl:abels(string)} specifies row panel headers, backslash-separated. Must match number of exposure panels (e.g., {cmd:explabels("Exposure status" \ "Regimen")}).

{phang}
{opt modell:abels(string)} specifies column labels for each model, backslash-separated (e.g., {cmd:modellabels("Crude" \ "Adjusted")}).

{phang}
{opt refl:abel(string)} specifies text displayed in effect columns for the reference category. Default: {cmd:Ref.}

{dlgtab:Excel and output}

{phang}
{opt xlsx(filename)} specifies the Excel output file. Must end with {cmd:.xlsx}. If the file exists, only the named sheet is replaced.

{phang}
{opt sheet(string)} specifies the sheet name. Default {cmd:Results}.

{phang}
{opt title(string)} specifies a title in cell A1, merged across the table width.

{phang}
{opt sub:title(string)} specifies a subtitle below the title.

{phang}
{opt foot:note(string)} specifies a footnote below the table. Tip: use this to describe adjustment sets and stset specifications.

{phang}
{opt the:me(string)} specifies a formatting theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}.

{phang}
{opt border:style(string)} specifies border style: {cmd:thin}, {cmd:medium}, or {cmd:academic}.

{phang}
{opt open} opens the file in the default application after export.

{phang}
{opt zebra} applies alternating row shading.

{phang}
{opt headers:hade} applies header row shading.

{phang}
{opt headerc:olor(string)} specifies custom header color as "R G B".

{phang}
{opt zebrac:olor(string)} specifies custom zebra stripe color as "R G B".

{phang}
{opt boldp(#)} bolds p-value cells below threshold. Requires {cmd:pvalue}.

{phang}
{opt high:light(#)} highlights rows where any p-value < threshold.

{phang}
{opt csv(filename)} also exports as CSV.

{phang}
{opt fra:me(name)} stores output in a named Stata frame.

{phang}
{opt dis:play} shows formatted table in the Results window.

{phang}
{cmdab:addr:ow(}{it:string asis}{cmd:)} appends custom rows below the table body.


{marker remarks}{...}
{title:Remarks}

{dlgtab:How it works}

{pstd}
{cmd:hrtab} preserves the data at entry and restores it on exit -- your dataset and stset are never modified.

{pstd}
For each outcome, {cmd:hrtab} issues {cmd:stset} (unless in single-outcome mode with existing stset), then loops over exposure panels. Within each panel it runs {cmd:stptime} for descriptive columns, then estimates the unadjusted model followed by each adjusted model. All results are collected into locals, then formatted and exported.

{pstd}
The estimation call for each model looks like:

{phang3}{it:model} {it:exposure_term} {it:covars}{cmd:,} {it:modelopts}{p_end}

{pstd}
For example, with {cmd:model(stcox)} and {cmd:covars(age sex)}:

{phang3}Unadjusted: {cmd:stcox i.ht_status}{p_end}
{phang3}Adjusted: {cmd:stcox i.ht_status age sex}{p_end}

{pstd}
With {cmd:model(finegray)} and {cmd:failvalue(1)}:

{phang3}Unadjusted: {cmd:finegray i.ht_status, compete(event) cause(1)}{p_end}
{phang3}Adjusted: {cmd:finegray i.ht_status age sex, compete(event) cause(1)}{p_end}

{dlgtab:Competing risks automation}

{pstd}
When {cmd:failvalue()} is specified, {cmd:hrtab} builds the {cmd:compete()}/{cmd:cause()} options automatically. Given {cmd:outcome(event)} with {cmd:censvalue(0)} and levels {0, 1, 2, 3}:

{phang3}{cmd:failvalue(1)}: competing events = 2, 3{p_end}
{phang3}{cmd:failvalue(2)}: competing events = 1, 3{p_end}

{pstd}
For {cmd:stcrreg}, this becomes:

{phang3}{cmd:stset time, failure(event == 1)}{p_end}
{phang3}{cmd:stcrreg vars, compete(event == 2 3)}{p_end}

{pstd}
For {cmd:finegray}, this becomes:

{phang3}{cmd:finegray vars, compete(event) cause(1)}{p_end}

{dlgtab:Continuous exposures}

{pstd}
When an exposure panel uses {cmd:c.}{it:varname}, {cmd:hrtab} shows a single row (no reference category, no per-level breakdown), reports total person-years and total events (not stratified), and uses the variable label as the row label. Scale the variable before calling {cmd:hrtab} to control the "per-unit" interpretation.

{dlgtab:Observation counts}

{pstd}
Person-years and events are computed from the full stset sample via {cmd:stptime}. If an adjusted model drops observations due to missing covariates, {cmd:hrtab} displays a footnote: "N=### in adjusted model(s) due to missing covariates" and stores the model N in {cmd:r(N_adjusted)}.

{dlgtab:Limitations}

{pstd}
All models in the table use the same estimation command. To mix {cmd:stcox} and {cmd:finegray}, run {cmd:hrtab} twice with different sheets. {cmd:modelopts()} applies to all models uniformly. {cmd:if}/{cmd:in} restrictions apply to all models. Time-varying exposures are not supported.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Single outcome, existing stset}

{phang2}{cmd:. stset followup, failure(died) id(patient_id)}{p_end}
{phang2}{cmd:. hrtab, exposure(i.treatment) model(stcox) ///}{p_end}
{phang3}{cmd:covars(age sex i.stage) ///}{p_end}
{phang3}{cmd:xlsx("table2.xlsx") theme(lancet)}{p_end}

{pstd}
{bf:Example 2: Multiple outcomes, multiple exposures}

{phang2}{cmd:. hrtab, exposure(i.ht_status \ i.ht_regimen \ i.ht_duration) ///}{p_end}
{phang3}{cmd:model(stcox) ///}{p_end}
{phang3}{cmd:outcome(edss4 \ edss6) time(followup_edss4 \ followup_edss6) ///}{p_end}
{phang3}{cmd:stsetopts(id(patient_id)) ///}{p_end}
{phang3}{cmd:covars(age disease_dur education edss cal_year) ///}{p_end}
{phang3}{cmd:outlabels("EDSS 4" \ "EDSS 6") ///}{p_end}
{phang3}{cmd:explabels("Exposure status" \ "Regimen" \ "Duration") ///}{p_end}
{phang3}{cmd:modellabels("Crude" \ "Adjusted") ///}{p_end}
{phang3}{cmd:footnote("Adjusted for age, disease duration, education, EDSS, calendar year") ///}{p_end}
{phang3}{cmd:xlsx("table2.xlsx") title("Table 2") theme(lancet)}{p_end}

{pstd}
{bf:Example 3: Competing risks with stcrreg}

{phang2}{cmd:. hrtab, exposure(i.treatment) model(stcrreg) ///}{p_end}
{phang3}{cmd:outcome(event_type) time(followup) failvalue(1 \ 2) ///}{p_end}
{phang3}{cmd:stsetopts(id(patient_id)) ///}{p_end}
{phang3}{cmd:covars(age sex i.comorbidity) ///}{p_end}
{phang3}{cmd:outlabels("Cardiovascular" \ "Non-CV death") ///}{p_end}
{phang3}{cmd:effect("SHR") ///}{p_end}
{phang3}{cmd:xlsx("table2_cr.xlsx") theme(nejm)}{p_end}

{pstd}
{bf:Example 4: Competing risks with finegray}

{phang2}{cmd:. hrtab, exposure(i.drug_class) model(finegray) ///}{p_end}
{phang3}{cmd:outcome(event_type) time(followup) failvalue(1) ///}{p_end}
{phang3}{cmd:stsetopts(id(patient_id)) ///}{p_end}
{phang3}{cmd:covars(age sex) effect("SHR") ///}{p_end}
{phang3}{cmd:xlsx("table2_fg.xlsx")}{p_end}

{pstd}
{bf:Example 5: Three adjustment levels}

{phang2}{cmd:. hrtab, exposure(i.exposure) model(stcox) ///}{p_end}
{phang3}{cmd:covars(age sex \ age sex i.comorbidity bmi smoking) ///}{p_end}
{phang3}{cmd:modellabels("Crude" \ "Age-sex adjusted" \ "Fully adjusted") ///}{p_end}
{phang3}{cmd:xlsx("table2.xlsx") theme(bmj)}{p_end}

{pstd}
{bf:Example 6: Mixed categorical and continuous exposures}

{phang2}{cmd:. label var dose_per10 "Cumulative dose, per 10 mg"}{p_end}
{phang2}{cmd:. hrtab, exposure(i.ever_use \ i.duration_cat \ c.dose_per10) ///}{p_end}
{phang3}{cmd:model(stcox) outcome(event) time(followup) ///}{p_end}
{phang3}{cmd:covars(age sex bmi) ///}{p_end}
{phang3}{cmd:explabels("Ever-use" \ "Duration" \ "Dose-response") ///}{p_end}
{phang3}{cmd:xlsx("table2.xlsx")}{p_end}

{pstd}
{bf:Example 7: Suppressing unadjusted, adding p-values}

{phang2}{cmd:. hrtab, exposure(i.treatment) model(stcox) ///}{p_end}
{phang3}{cmd:covars(age sex i.stage) ///}{p_end}
{phang3}{cmd:nounadjusted pvalue ///}{p_end}
{phang3}{cmd:modellabels("Adjusted") ///}{p_end}
{phang3}{cmd:xlsx("table2_adj.xlsx")}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:hrtab} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(models)}}number of models estimated (total across all cells){p_end}
{synopt:{cmd:r(outcomes)}}number of outcome column groups{p_end}
{synopt:{cmd:r(panels)}}number of exposure panels{p_end}
{synopt:{cmd:r(N_unadjusted)}}observations in unadjusted models{p_end}
{synopt:{cmd:r(N_adjusted)}}observations in adjusted models (may differ if missing covars){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}path to Excel file (when {cmd:xlsx()} specified){p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(cmd)}}estimation command used{p_end}
{synopt:{cmd:r(stset_notes)}}description of stset specifications used{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden
{p_end}

{pstd}
{bf:Version} 1.0.4

{hline}

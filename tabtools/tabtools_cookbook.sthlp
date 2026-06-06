{smcl}
{* *! version 1.5.0  06jun2026}{...}
{viewerjumpto "Recipe 1" "tabtools_cookbook##r1"}{...}
{viewerjumpto "Recipe 2" "tabtools_cookbook##r2"}{...}
{viewerjumpto "Recipe 3" "tabtools_cookbook##r3"}{...}
{viewerjumpto "Recipe 4" "tabtools_cookbook##r4"}{...}
{viewerjumpto "Recipe 5" "tabtools_cookbook##r5"}{...}
{viewerjumpto "Recipe 6" "tabtools_cookbook##r6"}{...}
{viewerjumpto "Recipe 7" "tabtools_cookbook##r7"}{...}
{viewerjumpto "Recipe 8" "tabtools_cookbook##r8"}{...}
{viewerjumpto "Recipe 9" "tabtools_cookbook##r9"}{...}
{viewerjumpto "Recipe 10" "tabtools_cookbook##r10"}{...}
{viewerjumpto "Recipe 11" "tabtools_cookbook##r11"}{...}
{viewerjumpto "Recipe 12" "tabtools_cookbook##r12"}{...}
{viewerjumpto "Recipe 13" "tabtools_cookbook##r13"}{...}
{viewerjumpto "Recipe 14" "tabtools_cookbook##r14"}{...}
{viewerjumpto "Recipe 15" "tabtools_cookbook##r15"}{...}
{viewerjumpto "Recipe 16" "tabtools_cookbook##r16"}{...}
{viewerjumpto "Recipe 17" "tabtools_cookbook##r17"}{...}
{viewerjumpto "Recipe 18" "tabtools_cookbook##r18"}{...}
{viewerjumpto "Recipe 19" "tabtools_cookbook##r19"}{...}
{viewerjumpto "Recipe 20" "tabtools_cookbook##r20"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "tabtools cheatsheet" "help tabtools_cheatsheet"}{...}
{vieweralsosee "table1_tc" "help table1_tc"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "stacktab" "help stacktab"}{...}
{title:tabtools Cookbook}

{pstd}
Copy-paste recipes for common tabtools workflows. Runnable recipes use
{cmd:sysuse} or {cmd:webuse} datasets and write local example files. Recipes
marked illustrative show project-specific scaffolds and require your own files
or variables.
{p_end}

{pstd}See also: {helpb tabtools}, {helpb tabtools_cheatsheet}{p_end}

{hline}
{marker r1}{...}
{title:Recipe 1. Basic Table 1 with SMD}

{pstd}Descriptive statistics table comparing two groups, with standardized
mean differences and p-values.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:table1_tc, by(foreign) ///}{p_end}
{phang3}{cmd:vars(price contn \ mpg contn \ weight contn \ ///}{p_end}
{phang3}{cmd:     rep78 cat \ headroom conts) ///}{p_end}
{phang3}{cmd:xlsx(table1.xlsx) sheet("Table 1") ///}{p_end}
{phang3}{cmd:title("Table 1. Vehicle Characteristics by Origin") ///}{p_end}
{phang3}{cmd:smd boldp(0.05) zebra}{p_end}

{pstd}To retrieve the methods paragraph after running:{p_end}
{phang2}{cmd:local methods = r(methods)}{p_end}
{phang2}{cmd:display "`methods'"}{p_end}

{hline}
{marker r2}{...}
{title:Recipe 2. IPTW-weighted Table 1}

{pstd}Weighted descriptive statistics using inverse probability of treatment
weights, showing the effective sample size.{p_end}

{phang2}{cmd:webuse cattaneo2, clear}{p_end}
{phang2}{cmd:* Estimate propensity score and compute IPTW}{p_end}
{phang2}{cmd:logit mbsmoke mage medu mmarried fbaby}{p_end}
{phang2}{cmd:predict double ps, pr}{p_end}
{phang2}{cmd:gen double iptw = cond(mbsmoke==1, 1/ps, 1/(1-ps))}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Unweighted Table 1 (pre-weighting)}{p_end}
{phang2}{cmd:table1_tc, by(mbsmoke) ///}{p_end}
{phang3}{cmd:vars(mage contn \ medu contn \ mmarried bin \ fbaby bin) ///}{p_end}
{phang3}{cmd:xlsx(balance.xlsx) sheet("Unweighted") ///}{p_end}
{phang3}{cmd:title("Before IPTW") smd}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Weighted Table 1 (post-weighting) — note the wt() option}{p_end}
{phang2}{cmd:table1_tc, by(mbsmoke) ///}{p_end}
{phang3}{cmd:vars(mage contn \ medu contn \ mmarried bin \ fbaby bin) ///}{p_end}
{phang3}{cmd:wt(iptw) xlsx(balance.xlsx) sheet("IPTW Weighted") ///}{p_end}
{phang3}{cmd:title("After IPTW") smd}{p_end}

{pstd}When {cmd:wt()} is specified, p-values are suppressed and the effective
sample size (Kish's formula) is shown.{p_end}

{hline}
{marker r3}{...}
{title:Recipe 3. Logistic regression table}

{pstd}Export odds ratios with 95% CI from a logistic regression.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive mpg weight i.foreign}{p_end}
{phang2}{cmd:regtab, xlsx(regression.xlsx) sheet("Logistic") ///}{p_end}
{phang3}{cmd:title("Table 2. Predictors of High Price") ///}{p_end}
{phang3}{cmd:noint boldp(0.05) zebra}{p_end}

{pstd}The coefficient label ({cmd:OR}) is auto-detected from the estimation
command. Use {cmd:coef("aOR")} to override (e.g., for adjusted odds ratios).{p_end}

{hline}
{marker r4}{...}
{title:Recipe 4. Cox model with median odds ratio (MOR)}

{pstd}Mixed-effects Cox model with the median odds ratio for the random
intercept, useful for quantifying clustering.{p_end}

{phang2}{cmd:webuse catheter, clear}{p_end}
{phang2}{cmd:stset time, failure(infect)}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: mestreg age female, distribution(weibull) || patient:}{p_end}
{phang2}{cmd:regtab, xlsx(survival.xlsx) sheet("Cox MOR") ///}{p_end}
{phang3}{cmd:title("Table 3. Catheter Infection Model") ///}{p_end}
{phang3}{cmd:relabel noint}{p_end}

{pstd}The {cmd:relabel} option replaces technical row names like
{cmd:var(_cons)} with readable labels (e.g., "Patient (Intercept)").
The MOR is automatically computed for the random intercept.{p_end}

{hline}
{marker r5}{...}
{title:Recipe 5. Treatment effects with margins}

{phang2}{cmd:webuse cattaneo2, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: teffects ipw (bweight) ///}{p_end}
{phang3}{cmd:(mbsmoke mage medu mmarried fbaby), ate}{p_end}
{phang2}{cmd:effecttab, xlsx(effects.xlsx) sheet("ATE") ///}{p_end}
{phang3}{cmd:effect("ATE") title("Average Treatment Effect on Birthweight") ///}{p_end}
{phang3}{cmd:clean}{p_end}

{pstd}For marginal effects:{p_end}

{phang2}{cmd:webuse lbw, clear}{p_end}
{phang2}{cmd:logit low smoke age lwt i.race, nolog}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: margins, dydx(*)}{p_end}
{phang2}{cmd:effecttab, xlsx(effects.xlsx) sheet("AME") ///}{p_end}
{phang3}{cmd:effect("AME") title("Average Marginal Effects")}{p_end}

{hline}
{marker r6}{...}
{title:Recipe 6. Multi-model manuscript workflow}

{pstd}Build a multi-sheet Excel workbook for a manuscript, with Table 1,
a regression table, and treatment effects on separate sheets.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Set consistent formatting for the entire workbook}{p_end}
{phang2}{cmd:tabtools set font Calibri}{p_end}
{phang2}{cmd:tabtools set borderstyle academic}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Table 1}{p_end}
{phang2}{cmd:table1_tc, by(foreign) ///}{p_end}
{phang3}{cmd:vars(price contn \ mpg contn \ weight contn \ rep78 cat) ///}{p_end}
{phang3}{cmd:xlsx(manuscript.xlsx) sheet("Table 1") ///}{p_end}
{phang3}{cmd:title("Table 1. Baseline Characteristics") smd}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Regression table}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive mpg weight i.foreign}{p_end}
{phang2}{cmd:regtab, xlsx(manuscript.xlsx) sheet("Table 2") ///}{p_end}
{phang3}{cmd:title("Table 2. Predictors of High Price") noint}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Treatment effect}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: teffects ra (expensive mpg weight) (foreign), ate}{p_end}
{phang2}{cmd:effecttab, xlsx(manuscript.xlsx) sheet("Table 3") ///}{p_end}
{phang3}{cmd:effect("ATE") title("Table 3. Treatment Effects") clean}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Clear persistent formatting when done}{p_end}
{phang2}{cmd:tabtools set clear}{p_end}

{hline}
{marker r7}{...}
{title:Recipe 7. Composite table with comptab}

{pstd}Combine regression results from multiple models into a single
table with custom row ordering.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Model 1: Unadjusted}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive i.foreign}{p_end}
{phang2}{cmd:regtab, frame(m1) noint}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Model 2: Adjusted}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive i.foreign mpg weight}{p_end}
{phang2}{cmd:regtab, frame(m2) noint}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Combine into composite table}{p_end}
{phang2}{cmd:comptab m1 m2, rownames("foreign \ foreign") ///}{p_end}
{phang3}{cmd:xlsx(composite.xlsx) sheet("Models") ///}{p_end}
{phang3}{cmd:title("Table 4. Association with Price (OR, 95% CI)") ///}{p_end}
{phang3}{cmd:zebra}{p_end}

{pstd}{cmd:comptab} combines rows while the pieces are still tabtools
{it:frames}. If your blocks are instead {it:already exported} to sheets in a
workbook, assemble them with {helpb stacktab} (Recipe 20) rather than
{cmd:comptab}.{p_end}

{hline}
{marker r8}{...}
{title:Recipe 8. Incidence rates by exposure (stratetab)}

{pstd}Export stratified incidence rates from {cmd:strate} output.{p_end}

{phang2}{cmd:webuse diet, clear}{p_end}
{phang2}{cmd:stset dox, failure(fail) origin(time dob) enter(time doe) ///}{p_end}
{phang3}{cmd:scale(365.25) id(id)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Generate strate output files}{p_end}
{phang2}{cmd:strate hienergy, per(1000) output(rate_hienergy, replace)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Export to Excel}{p_end}
{phang2}{cmd:stratetab, using(rate_hienergy) xlsx(rates.xlsx) outcomes(1) ///}{p_end}
{phang3}{cmd:outlabels("CHD Death") explabels("Energy Intake") ///}{p_end}
{phang3}{cmd:title("Incidence Rates per 1,000 Person-Years") ///}{p_end}
{phang3}{cmd:zebra}{p_end}

{hline}
{marker r9}{...}
{title:Recipe 9. Illustrative Table 2 workflow with hrcomptab}

{pstd}Build a final Table 2-style worksheet by using {cmd:stratetab} as the
rates scaffold and injecting selected rows from one or more {cmd:regtab}
frames.{p_end}

{pstd}This recipe is illustrative. Replace the rate-file names, model variables,
and placeholder covariate lists with outputs and models from your analysis.{p_end}

{phang2}{cmd:* Step 1: build the incidence-rate scaffold}{p_end}
{phang2}{cmd:stratetab, using(edss4_tv edss6_tv recurring_tv ///}{p_end}
{phang3}{cmd:edss4_dose edss6_dose recurring_dose) ///}{p_end}
{phang3}{cmd:outcomes(3) frame(hrt_rates, replace) ///}{p_end}
{phang3}{cmd:outlabels("Sustained EDSS 4" \ "Sustained EDSS 6" \ "Recurring Relapse") ///}{p_end}
{phang3}{cmd:explabels("Binary HRT" \ "Estrogen Dose Category")}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Step 2: store adjusted models in regtab frames}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: stcox hrt_tv ...}{p_end}
{phang2}{cmd:collect: stcox hrt_tv ...}{p_end}
{phang2}{cmd:collect: stcox hrt_tv ...}{p_end}
{phang2}{cmd:regtab, frame(hrt_bin, replace) noint coef("HR")}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: stcox i.hrt_dosecat ...}{p_end}
{phang2}{cmd:collect: stcox i.hrt_dosecat ...}{p_end}
{phang2}{cmd:collect: stcox i.hrt_dosecat ...}{p_end}
{phang2}{cmd:regtab, frame(hrt_dose, replace) noint coef("HR")}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Step 3: compose the final sheet}{p_end}
{phang2}{cmd:hrcomptab hrt_rates, modelframes(hrt_bin hrt_dose) ///}{p_end}
{phang3}{cmd:rows(1 \ 3/5) effect("aHR") ///}{p_end}
{phang3}{cmd:xlsx(HRT.xlsx) sheet("Table 2") ///}{p_end}
{phang3}{cmd:title("Table 2. HRT Events, Rates, and Adjusted Hazard Ratios")}{p_end}

{pstd}Use {cmd:rows()} to pick the model rows that should be inserted for each
exposure block, or switch to {cmd:rownames()} when you prefer rendered-label
substring matching across model frames.{p_end}

{hline}
{marker r10}{...}
{title:Recipe 10. Console preview without Excel}

{pstd}All table-producing commands display the completed table directly in the
Results window. You can omit {cmd:xlsx()} when you only need the console
version.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* regtab console output}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: regress price mpg weight i.foreign}{p_end}
{phang2}{cmd:regtab, noint}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* table1_tc console output}{p_end}
{phang2}{cmd:table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* effecttab console output}{p_end}
{phang2}{cmd:logit foreign mpg weight}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: margins, dydx(mpg weight)}{p_end}
{phang2}{cmd:effecttab, effect("AME")}{p_end}

{hline}
{marker r11}{...}
{title:Recipe 11. CSV export for R/Python users}

{pstd}Export table data as CSV for downstream analysis in other languages.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic foreign mpg weight price}{p_end}
{phang2}{cmd:regtab, xlsx(models.xlsx) sheet("OR") ///}{p_end}
{phang3}{cmd:csv(models_for_R.csv) noint}{p_end}

{pstd}The {cmd:csv()} option writes a delimited file alongside the Excel
output. All tabtools commands that accept {cmd:xlsx()} also accept
{cmd:csv()}.{p_end}

{hline}
{marker r12}{...}
{title:Recipe 12. Frame output for downstream Stata analysis}

{pstd}Store table results in a Stata frame for further manipulation.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic foreign mpg weight price}{p_end}
{phang2}{cmd:regtab, xlsx(models.xlsx) sheet("OR") frame(results) noint}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Work with the frame}{p_end}
{phang2}{cmd:frame results: describe}{p_end}
{phang2}{cmd:frame results: list}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Or switch into it}{p_end}
{phang2}{cmd:frame change results}{p_end}
{phang2}{cmd:list A c1 c2 c3}{p_end}
{phang2}{cmd:frame change default}{p_end}

{pstd}The {cmd:frame()} option is available on {cmd:regtab}, {cmd:effecttab},
and {cmd:table1_tc}.{p_end}

{hline}
{marker r13}{...}
{title:Recipe 13. Custom theme setup}

{pstd}Set persistent formatting that applies to all tabtools commands in the
session.{p_end}

{phang2}{cmd:* Use a built-in journal theme}{p_end}
{phang2}{cmd:tabtools set theme lancet}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Or set individual options}{p_end}
{phang2}{cmd:tabtools set font "Times New Roman"}{p_end}
{phang2}{cmd:tabtools set fontsize 11}{p_end}
{phang2}{cmd:tabtools set borderstyle academic}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Or build a fully custom theme}{p_end}
{phang2}{cmd:tabtools set theme custom, font(Calibri) fontsize(9) ///}{p_end}
{phang3}{cmd:headercolor(200 220 240) zebracolor(240 245 250) ///}{p_end}
{phang3}{cmd:borderstyle(thin)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Check current settings}{p_end}
{phang2}{cmd:tabtools get}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Reset all to defaults}{p_end}
{phang2}{cmd:tabtools set clear}{p_end}

{pstd}Available built-in themes: {cmd:lancet}, {cmd:nejm}, {cmd:bmj},
{cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, and {cmd:annals}.
Use {cmd:custom} to define your own. These are journal-inspired presets, not
publisher-managed final-production templates.{p_end}

{pstd}Individual {cmd:set font}, {cmd:set fontsize}, and {cmd:set borderstyle}
commands can override a named theme.  The theme automatically transitions to
{cmd:custom} mode, preserving the original theme's other settings.{p_end}

{hline}
{marker r14}{...}
{title:Recipe 14. Dose-response pattern via regtab}

{pstd}Factor variables with ordered levels to show a dose-response pattern
in a regression table.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen byte price_cat = cond(price < 4000, 1, ///}{p_end}
{phang3}{cmd:cond(price < 6000, 2, cond(price < 10000, 3, 4)))}{p_end}
{phang2}{cmd:label define pcat 1 "<4000" 2 "4000-5999" 3 "6000-9999" 4 "10000+"}{p_end}
{phang2}{cmd:label values price_cat pcat}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: regress mpg ib1.price_cat weight foreign}{p_end}
{phang2}{cmd:regtab, xlsx(dose_response.xlsx) sheet("Dose") ///}{p_end}
{phang3}{cmd:title("MPG by Price Category (Reference: <4000)") ///}{p_end}
{phang3}{cmd:noint factorlabel}{p_end}

{pstd}The {cmd:factorlabel} option replaces labels like "2.price_cat" with
the value label "4000-5999".{p_end}

{hline}
{marker r15}{...}
{title:Recipe 15. Survival Summary Table}

{pstd}
Create a Kaplan-Meier survival table with median survival, risk set counts,
and between-group comparison.
{p_end}

{phang2}{cmd:. webuse drugtr, clear}{p_end}
{phang2}{cmd:. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. survtab, times(5 10 15 20) by(drug) ///}{p_end}
{phang3}{cmd:xlsx(survival.xlsx) sheet("Table 2") ///}{p_end}
{phang3}{cmd:title("Table 2. Survival Estimates by Treatment") ///}{p_end}
{phang3}{cmd:median riskset difference ///}{p_end}
{phang3}{cmd:footnote("KM estimates with 95% CI. P-value from log-rank test.") ///}{p_end}
{phang3}{cmd:theme(lancet)}{p_end}

{hline}
{marker r16}{...}
{title:Recipe 16. Diagnostic Accuracy Report}

{pstd}
Evaluate a diagnostic test against a gold standard with ROC analysis
and prevalence-adjusted predictive values.
{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. gen gold = (rep78 >= 4) if rep78 < .}{p_end}
{phang2}{cmd:. diagtab mpg gold, cutoff(25) auc optimal ///}{p_end}
{phang3}{cmd:xlsx(diagnostics.xlsx) sheet("Accuracy") ///}{p_end}
{phang3}{cmd:title("Table 3. Diagnostic Accuracy of MPG") ///}{p_end}
{phang3}{cmd:prevalence(0.3) display}{p_end}

{hline}
{marker r17}{...}
{title:Recipe 17. Correlation Matrix with Significance Stars}

{pstd}
Publication-ready correlation matrix with lower triangle,
significance stars, and Spearman method for non-normal data.
{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. corrtab price mpg weight length displacement, ///}{p_end}
{phang3}{cmd:spearman lower ///}{p_end}
{phang3}{cmd:xlsx(correlations.xlsx) sheet("Table 4") ///}{p_end}
{phang3}{cmd:title("Table 4. Spearman Correlations") ///}{p_end}
{phang3}{cmd:star(0.001 0.01 0.05) digits(2) ///}{p_end}
{phang3}{cmd:footnote("* p<0.05, ** p<0.01, *** p<0.001") ///}{p_end}
{phang3}{cmd:theme(nejm)}{p_end}

{hline}
{marker r18}{...}
{title:Recipe 18. Events / N (%) from a table collect}

{pstd}
Use {cmd:desctab} when a {cmd:table} collection contains multiple statistics
that need different formats in the same cell.

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: table rep78 foreign, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)}{p_end}
{phang2}{cmd:desctab, xlsx(desc_events.xlsx) sheet("Events") compose(events_n_pct) title("Events / N (%) by repair record and origin")}{p_end}

{hline}
{marker r19}{...}
{title:Recipe 19. Style a raw in-memory table with puttab}

{pstd}Use {cmd:puttab} when you have a table already in memory — the current
dataset, a {helpb frames:frame}, or a {it:matrix} — and no dedicated tabtools
command fits. It does no analysis; it just applies the house style to whatever
you hand it. Here the same workbook gets one sheet from each source type.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Matrix source: r(table) from a regression}{p_end}
{phang2}{cmd:regress price mpg weight i.foreign}{p_end}
{phang2}{cmd:matrix T = r(table)'}{p_end}
{phang2}{cmd:puttab using report.xlsx, sheet("Coefs") matrix(T) ///}{p_end}
{phang3}{cmd:title("OLS Coefficients") digits(3) headershade}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Frame source: a subset frame}{p_end}
{phang2}{cmd:frame put make mpg price in 1/10, into(top)}{p_end}
{phang2}{cmd:puttab using report.xlsx, sheet("Top10") frame(top) ///}{p_end}
{phang3}{cmd:title("First Ten Cars") varlabels theme(nejm) zebra}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Data source: a collapse result with value labels}{p_end}
{phang2}{cmd:collapse (mean) price mpg (count) n=price, by(foreign)}{p_end}
{phang2}{cmd:puttab foreign price mpg n using report.xlsx, sheet("ByOrigin") ///}{p_end}
{phang3}{cmd:title("Mean Price and Mileage by Origin") varlabels digits(1)}{p_end}

{pstd}A numeric column is written with {cmd:digits()} decimals, but integer-valued
columns (like the count {cmd:n}) stay integer, and value labels are resolved.{p_end}

{hline}
{marker r20}{...}
{title:Recipe 20. Emit-then-assemble pipeline (puttab + stacktab)}

{pstd}{cmd:puttab} and {cmd:stacktab} are two halves of one pipeline: {cmd:puttab}
writes each styled block to its own sheet, then {cmd:stacktab} assembles those
sheets into the final composite. Unlike {helpb comptab}, which combines tabtools
{it:frames}, {cmd:stacktab} works purely on sheets {it:already in the workbook}.{p_end}

{phang2}{cmd:* Step 1: emit two estimate/CI blocks as styled sheets}{p_end}
{phang2}{cmd:clear}{p_end}
{phang2}{cmd:input str22 term str10 ahr str16 ci}{p_end}
{phang2}{cmd:"Any HRT"        "0.82" "(0.69, 0.98)"}{p_end}
{phang2}{cmd:"Former smoker"  "1.14" "(0.97, 1.34)"}{p_end}
{phang2}{cmd:"Current smoker" "1.46" "(1.21, 1.77)"}{p_end}
{phang2}{cmd:end}{p_end}
{phang2}{cmd:label var term "Exposure"}{p_end}
{phang2}{cmd:label var ahr "aHR"}{p_end}
{phang2}{cmd:label var ci "95% CI"}{p_end}
{phang2}{cmd:puttab term ahr ci using parts.xlsx, sheet("Primary") varlabels}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:clear}{p_end}
{phang2}{cmd:input str22 term str10 ahr str16 ci}{p_end}
{phang2}{cmd:"Low dose"  "0.91" "(0.74, 1.12)"}{p_end}
{phang2}{cmd:"High dose" "0.73" "(0.58, 0.92)"}{p_end}
{phang2}{cmd:end}{p_end}
{phang2}{cmd:label var term "Exposure"}{p_end}
{phang2}{cmd:label var ahr "aHR"}{p_end}
{phang2}{cmd:label var ci "95% CI"}{p_end}
{phang2}{cmd:puttab term ahr ci using parts.xlsx, sheet("Dose") varlabels}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Step 2: assemble the blocks, merge estimate+CI, label sections}{p_end}
{phang2}{cmd:stacktab using parts.xlsx, sheet("Table 2") ///}{p_end}
{phang3}{cmd:blocks(sheet(Primary) rows(1/4) cols(A-C) label(Any HRT use) \ ///}{p_end}
{phang3}{cmd:       sheet(Dose) rows(1/3) cols(A-C) label(By estrogen dose)) ///}{p_end}
{phang3}{cmd:columnmerge(B+C as "aHR (95% CI)") spacing(1) ///}{p_end}
{phang3}{cmd:title("Table 2. Hormone Therapy and Recurrent Events") ///}{p_end}
{phang3}{cmd:note("aHR = adjusted hazard ratio; CI = confidence interval.")}{p_end}

{pstd}{cmd:layout(hstack)} places equal-height blocks side by side instead of
stacking them. The legacy command name {cmd:xlsxcompose} still works as a
deprecated alias for {cmd:stacktab}.{p_end}

{hline}

{title:Also see}

{pstd}{helpb tabtools} — overview and settings{p_end}
{pstd}{helpb tabtools_cheatsheet} — quick option reference{p_end}
{pstd}{helpb table1_tc}, {helpb regtab}, {helpb effecttab}, {helpb stratetab},
{helpb survtab}, {helpb crosstab}, {helpb diagtab},
{helpb corrtab}, {helpb comptab}, {helpb hrcomptab}, {helpb puttab},
{helpb stacktab} — individual command help{p_end}

{hline}

{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.5.0{p_end}

{hline}

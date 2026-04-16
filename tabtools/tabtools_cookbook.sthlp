{smcl}
{* *! version 1.0.4  16apr2026}{...}
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
{title:tabtools Cookbook}

{pstd}
Copy-paste recipes for common tabtools workflows. Each recipe is
self-contained and uses built-in Stata datasets.
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

{hline}
{marker r8}{...}
{title:Recipe 8. Incidence rates by exposure (stratetab)}

{pstd}Export stratified incidence rates from {cmd:strate} output.{p_end}

{phang2}{cmd:webuse diet, clear}{p_end}
{phang2}{cmd:stset dox, failure(fail) origin(time dob) enter(time doe) ///}{p_end}
{phang3}{cmd:scale(365.25) id(id)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Generate strate output files}{p_end}
{phang2}{cmd:strate hieng, per(1000) output(rate_hieng, replace)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Export to Excel}{p_end}
{phang2}{cmd:stratetab, using(rate_hieng) xlsx(rates.xlsx) outcomes(1) ///}{p_end}
{phang3}{cmd:outlabels("CHD Death") explabels("Energy Intake") ///}{p_end}
{phang3}{cmd:title("Incidence Rates per 1,000 Person-Years") ///}{p_end}
{phang3}{cmd:zebra}{p_end}

{hline}
{marker r9}{...}
{title:Recipe 9. General-purpose table with tablex}

{pstd}Export any Stata {cmd:table} or {cmd:collect} output to Excel using
{cmd:tablex} as a pass-through wrapper.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:table foreign, statistic(mean price mpg weight) ///}{p_end}
{phang3}{cmd:statistic(sd price mpg weight) nformat(%9.1f)}{p_end}
{phang2}{cmd:collect export summary.xlsx, sheet(temp) replace}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:tablex using summary.xlsx, sheet("Summary Stats") ///}{p_end}
{phang3}{cmd:title("Vehicle Summary by Origin") ///}{p_end}
{phang3}{cmd:replace zebra open}{p_end}

{hline}
{marker r10}{...}
{title:Recipe 10. Console preview without Excel}

{pstd}Preview any tabtools output directly in the Results window without
writing an Excel file. Works with {cmd:regtab}, {cmd:effecttab}, and
{cmd:table1_tc}.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* regtab console preview}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: regress price mpg weight i.foreign}{p_end}
{phang2}{cmd:regtab, display noint}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* table1_tc console preview (no xlsx option)}{p_end}
{phang2}{cmd:table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat)}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* effecttab console preview}{p_end}
{phang2}{cmd:logit foreign mpg weight}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: margins, dydx(mpg weight)}{p_end}
{phang2}{cmd:effecttab, display effect("AME")}{p_end}

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
{cmd:table1_tc}, and {cmd:tablex}.{p_end}

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
{cmd:apa}. Use {cmd:custom} to define your own.{p_end}

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
{title:Recipe 15. Sample flow table via tablex}

{pstd}Build a sample flow (CONSORT-style exclusion table) using {cmd:tablex}.{p_end}

{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:* Build a flow table using collect}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:count}{p_end}
{phang2}{cmd:local total = r(N)}{p_end}
{phang2}{cmd:collect get step = "Total records", n = `total'}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:drop if missing(rep78)}{p_end}
{phang2}{cmd:local n1 = _N}{p_end}
{phang2}{cmd:local exc1 = `total' - `n1'}{p_end}
{phang2}{cmd:collect get step = "  Excluded: missing rep78", n = -`exc1'}{p_end}
{phang2}{cmd:collect get step = "After exclusion 1", n = `n1'}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:drop if price > 15000}{p_end}
{phang2}{cmd:local n2 = _N}{p_end}
{phang2}{cmd:local exc2 = `n1' - `n2'}{p_end}
{phang2}{cmd:collect get step = "  Excluded: price > 15000", n = -`exc2'}{p_end}
{phang2}{cmd:collect get step = "Final analytic sample", n = `n2'}{p_end}
{phang2}{cmd:}{p_end}
{phang2}{cmd:collect export flow.xlsx, sheet(temp) replace}{p_end}
{phang2}{cmd:tablex using flow.xlsx, sheet("Sample Flow") ///}{p_end}
{phang3}{cmd:title("Figure 1. Sample Selection") replace}{p_end}

{hline}
{marker r16}{...}
{title:Recipe 16. Survival Summary Table}

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
{marker r17}{...}
{title:Recipe 17. Diagnostic Accuracy Report}

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
{marker r18}{...}
{title:Recipe 18. Correlation Matrix with Significance Stars}

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

{title:Also see}

{pstd}{helpb tabtools} — overview and settings{p_end}
{pstd}{helpb tabtools_cheatsheet} — quick option reference{p_end}
{pstd}{helpb table1_tc}, {helpb regtab}, {helpb effecttab}, {helpb stratetab},
{helpb survtab}, {helpb crosstab}, {helpb diagtab}, {helpb fittab},
{helpb corrtab}, {helpb comptab}, {helpb tablex} — individual command help{p_end}

{hline}

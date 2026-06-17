{smcl}
{* *! version 1.8.1  17jun2026}{...}
{viewerjumpto "Syntax" "tabtools_tips##syntax"}{...}
{viewerjumpto "Description" "tabtools_tips##description"}{...}
{viewerjumpto "Quick reference" "tabtools_tips##quick"}{...}
{viewerjumpto "Choosing commands" "tabtools_tips##choose"}{...}
{viewerjumpto "Examples" "tabtools_tips##examples"}{...}
{viewerjumpto "Author" "tabtools_tips##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "table1_tc" "help table1_tc"}{...}
{vieweralsosee "desctab" "help desctab"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "survtab" "help survtab"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "comptab" "help comptab"}{...}
{vieweralsosee "hrcomptab" "help hrcomptab"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "stacktab" "help stacktab"}{...}
{vieweralsosee "simtab" "help simtab"}{...}
{title:tabtools tips}

{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tabtools_tips} [{cmd:,} {opt open}]

{synoptset 18 tabbed}{...}
{synopt:{opt open}}open the tips help file directly instead of printing the compact command-line index{p_end}
{synoptline}

{marker description}{...}
{title:Description}

{pstd}
{cmd:tabtools_tips} is the quick-reference and worked-recipe guide for the
{helpb tabtools} suite. Type {cmd:tabtools_tips} for a compact index, or
{cmd:tabtools_tips, open} to open this help file from the command line.
{p_end}

{marker quick}{...}
{hline}
{title:Quick reference}

{pstd}
Common option combinations for each command.
{p_end}

{marker choose}{...}
{title:Choosing commands}

{pstd}{bf:Dedicated builders:} use {bf:table1_tc}, {bf:desctab},
{bf:crosstab}, {bf:corrtab}, {bf:survtab}, {bf:diagtab}, {bf:stratetab},
{bf:regtab}, {bf:effecttab}, and {bf:simtab} when the command owns the
analysis-to-table contract for your workflow.{p_end}

{pstd}{bf:Combining/styling tables:} use {bf:puttab} to style one raw
in-memory table (dataset/frame/matrix), {bf:comptab} to combine rows from
{bf:regtab}/{bf:effecttab} {it:frames}, {bf:hrcomptab} to attach model rows to a
{bf:stratetab} rates scaffold, and {bf:stacktab} to assemble sheets
{it:already exported} to a workbook. Pipeline: {cmd:puttab} emits styled blocks
{c -}> {cmd:stacktab} assembles them.{p_end}

{hline}
{title:table1_tc}

{phang2}{cmd:table1_tc, by(group) vars(age contn \ sex bin \ race cat) xlsx(t1.xlsx) sheet("Table 1") title("Baseline")}{p_end}
{phang2}{cmd:table1_tc, by(group) vars(...) xlsx(t1.xlsx) sheet("T1") title("T1") smd} {it:// add SMD column}{p_end}
{phang2}{cmd:table1_tc, by(group) vars(...) xlsx(t1.xlsx) sheet("T1") title("T1") boldp(0.05) highlight(0.05)} {it:// bold + highlight significant rows}{p_end}
{phang2}{cmd:table1_tc, by(group) vars(...) wt(iptw) xlsx(t1.xlsx) sheet("Weighted") title("IPTW-Weighted")} {it:// weighted statistics, unweighted N}{p_end}

{hline}
{title:desctab}

{phang2}{cmd:collect: table rep78 foreign, statistic(count price) statistic(mean price) statistic(sd price)}{p_end}
{phang2}{cmd:desctab, xlsx(desc.xlsx) sheet("Descriptive") digits(1)}{p_end}
{phang2}{cmd:collect: table rep78, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)}{p_end}
{phang2}{cmd:desctab, compose(events_n_pct) pctdigits(1) display} {it:// events / N (%)}{p_end}

{hline}
{title:regtab}

{phang2}{cmd:collect: logit outcome i.treatment age sex}{p_end}
{phang2}{cmd:regtab, xlsx(models.xlsx) sheet("Logistic") coef("OR") noint}{p_end}
{phang2}{cmd:regtab, xlsx(models.xlsx) sheet("Logistic") coef("OR") digits(3) footnote("OR = odds ratio") zebra}{p_end}
{phang2}{cmd:regtab, xlsx(models.xlsx) sheet("CDISC") cdisc} {it:// CDISC formatting: 4dp, Estimate, includes N}{p_end}

{hline}
{title:effecttab}

{phang2}{cmd:collect: margins treatment}{p_end}
{phang2}{cmd:effecttab, xlsx(effects.xlsx) sheet("Margins") type(margins) effect("Pr(Y)")}{p_end}
{phang2}{cmd:effecttab, xlsx(effects.xlsx) sheet("ATE") effect("ATE") clean footnote("ATE = average treatment effect")}{p_end}

{hline}
{title:stratetab}

{phang2}{cmd:stratetab, using(rate_ssri rate_snri) xlsx(rates.xlsx) outcomes(2) outlabels("Relapse \ EDSS 4") explabels("SSRI \ SNRI")}{p_end}
{phang2}{cmd:stratetab, ... rateratio ratiodigits(2)} {it:// add incidence rate ratios}{p_end}
{phang2}{cmd:stratetab, ... footnote("Rates per 1,000 PY") zebra}{p_end}

{hline}
{title:hrcomptab}

{phang2}{cmd:stratetab, using(edss4_tv edss6_tv recurring_tv edss4_dose edss6_dose recurring_dose) outcomes(3) frame(rates, replace)}{p_end}
{phang2}{cmd:regtab, frame(bin_models, replace) noint coef("HR")} {it:// after collect: stcox ... for binary exposure models}{p_end}
{phang2}{cmd:regtab, frame(dose_models, replace) noint coef("HR")} {it:// after collect: stcox ... for dose-category models}{p_end}
{phang2}{cmd:hrcomptab rates, modelframes(bin_models dose_models) rows(1 \ 3/5) xlsx(table2.xlsx) sheet("Table 2") effect("aHR")}{p_end}

{hline}
{title:survtab}

{phang2}{cmd:stset time, failure(event)}{p_end}
{phang2}{cmd:survtab, times(1 3 5) by(treatment) xlsx(surv.xlsx) title("Table 2. Survival")}{p_end}
{phang2}{cmd:survtab, times(1 3 5) by(treatment) median riskset difference} {it:// add median, n-at-risk, between-group difference}{p_end}
{phang2}{cmd:survtab, times(1 3 5) by(treatment) rmst(5) reverse} {it:// RMST + cumulative incidence}{p_end}

{hline}
{title:crosstab}

{phang2}{cmd:crosstab exposure outcome, or label xlsx(cross.xlsx) title("Exposure vs Outcome")}{p_end}
{phang2}{cmd:crosstab smoking cancer, rr rd trend display} {it:// risk ratio, risk diff, trend test}{p_end}
{phang2}{cmd:crosstab exposure outcome, exact or display} {it:// force Fisher's exact test}{p_end}

{hline}
{title:diagtab}

{phang2}{cmd:diagtab test_pos gold_std, xlsx(diag.xlsx) title("Diagnostic Accuracy")}{p_end}
{phang2}{cmd:diagtab score gold_std, cutoff(0.5) auc optimal display} {it:// continuous score with ROC}{p_end}
{phang2}{cmd:diagtab test gold, exact prevalence(0.05)} {it:// exact CIs, prevalence-adjusted PPV/NPV}{p_end}

{hline}
{title:corrtab}

{phang2}{cmd:corrtab age bmi sbp dbp, xlsx(corr.xlsx) title("Correlations") lower}{p_end}
{phang2}{cmd:corrtab age bmi sbp, spearman pvalues display} {it:// Spearman with p-values}{p_end}
{phang2}{cmd:corrtab age bmi sbp, full digits(3) star(0.1 0.05 0.01)} {it:// custom stars}{p_end}

{hline}
{title:comptab}

{phang2}{cmd:regtab, xlsx(comp.xlsx) sheet("S1") frame(f1)}{p_end}
{phang2}{cmd:regtab, xlsx(comp.xlsx) sheet("S2") frame(f2)}{p_end}
{phang2}{cmd:comptab f1 f2, rows(1 \ 1) xlsx(comp.xlsx) sheet("Combined")} {it:// combine rows from regtab frames}{p_end}

{hline}
{title:puttab}

{phang2}{cmd:collapse (mean) price mpg (count) n=price, by(foreign)}{p_end}
{phang2}{cmd:puttab foreign price mpg n using parts.xlsx, sheet("ByOrigin") varlabels digits(1) zebra} {it:// data source}{p_end}
{phang2}{cmd:regress price mpg weight}{p_end}
{phang2}{cmd:matrix T = r(table)'}{p_end}
{phang2}{cmd:puttab using parts.xlsx, sheet("Coefs") matrix(T) title("OLS") digits(3)} {it:// matrix source}{p_end}
{phang2}{cmd:puttab using parts.xlsx, sheet("Top10") frame(top) headershade} {it:// frame source}{p_end}

{hline}
{title:stacktab}

{phang2}{cmd:stacktab using parts.xlsx, sheet("Composite") blocks(sheet(Model A) \ sheet(Model B))} {it:// vstack two block sheets}{p_end}
{phang2}{cmd:stacktab using parts.xlsx, sheet("Table 2") blocks(sheet(Primary) rows(1/4) cols(A-C) \ sheet(Dose) rows(1/3) cols(A-C)) columnmerge(B+C as "aHR (95% CI)")} {it:// merge est + CI}{p_end}
{phang2}{cmd:stacktab using parts.xlsx, sheet("SideBySide") blocks(sheet(A) rows(2/3) cols(A-C) \ sheet(B) rows(2/3) cols(A-C)) layout(hstack)} {it:// side by side}{p_end}
{hline}
{title:simtab}

{phang2}{cmd:simtab estimator, estimate(b) se(se) true(theta) by(scenario) estimand(target) sim(rep) coverage(covered) display} {it:// compute mode}{p_end}
{phang2}{cmd:simtab estimator, estimate(b) se(se) true(theta) nsim(1000) metrics(mean bias empse meanse coverage n nonconv) xlsx("t2.xlsx") sheet("Table 2")} {it:// non-convergence + Excel}{p_end}
{phang2}{cmd:simsum b, true(theta) se(se) methodvar(estimator) id(rep) mcse clear} {it:// analysis by simsum ...}{p_end}
{phang2}{cmd:simtab, from(simsum) xlsx("t2.xlsx") sheet("Table 2") display} {it:// ... table by simtab}{p_end}

{hline}
{title:tabtools set/get}

{phang2}{cmd:tabtools set theme lancet} {it:// journal-inspired style preset}{p_end}
{phang2}{cmd:tabtools set font Calibri}{p_end}
{phang2}{cmd:tabtools set fontsize 11}{p_end}
{phang2}{cmd:tabtools set borderstyle thin}{p_end}
{phang2}{cmd:tabtools get} {it:// view current defaults}{p_end}
{phang2}{cmd:tabtools set clear} {it:// reset to command defaults}{p_end}

{marker examples}{...}
{marker recipes}{...}
{hline}
{title:Examples and Recipes}

{pstd}
These worked recipes are intentionally compact here:
the individual command help files carry full option tables and stored-result
contracts.
{p_end}

{title:1. Basic Table 1 with SMD}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:table1_tc, by(foreign) vars(price contn \ mpg contn \ weight contn \ rep78 cat \ headroom conts) xlsx(table1.xlsx) sheet("Table 1") title("Table 1. Vehicle Characteristics by Origin") smd boldp(0.05) zebra}{p_end}
{phang2}{cmd:local methods = r(methods)}{p_end}

{title:2. IPTW-weighted Table 1}
{phang2}{cmd:webuse cattaneo2, clear}{p_end}
{phang2}{cmd:logit mbsmoke mage medu mmarried fbaby}{p_end}
{phang2}{cmd:predict double ps, pr}{p_end}
{phang2}{cmd:gen double iptw = cond(mbsmoke==1, 1/ps, 1/(1-ps))}{p_end}
{phang2}{cmd:table1_tc, by(mbsmoke) vars(mage contn \ medu contn \ mmarried bin \ fbaby bin) wt(iptw) xlsx(balance.xlsx) sheet("IPTW Weighted") title("After IPTW") smd}{p_end}

{title:3. Logistic regression table}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive mpg weight i.foreign}{p_end}
{phang2}{cmd:regtab, xlsx(regression.xlsx) sheet("Logistic") title("Table 2. Predictors of High Price") noint boldp(0.05) zebra}{p_end}

{title:4. Cox model with median odds ratio}
{phang2}{cmd:webuse catheter, clear}{p_end}
{phang2}{cmd:stset time, failure(infect)}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: mestreg age female, distribution(weibull) || patient:}{p_end}
{phang2}{cmd:regtab, xlsx(survival.xlsx) sheet("Cox MOR") title("Table 3. Catheter Infection Model") relabel noint}{p_end}

{title:5. Treatment effects with margins}
{phang2}{cmd:webuse cattaneo2, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: teffects ipw (bweight) (mbsmoke mage medu mmarried fbaby), ate}{p_end}
{phang2}{cmd:effecttab, xlsx(effects.xlsx) sheet("ATE") effect("ATE") title("Average Treatment Effect on Birthweight") clean}{p_end}

{title:6. Multi-model manuscript workflow}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:tabtools set theme lancet}{p_end}
{phang2}{cmd:table1_tc, by(foreign) vars(price contn \ mpg contn \ weight contn \ rep78 cat) xlsx(manuscript.xlsx) sheet("Table 1") title("Table 1. Baseline Characteristics") smd}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive mpg weight i.foreign}{p_end}
{phang2}{cmd:regtab, xlsx(manuscript.xlsx) sheet("Table 2") title("Table 2. Predictors of High Price") noint}{p_end}
{phang2}{cmd:tabtools set clear}{p_end}

{title:7. Composite table with comptab}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive i.foreign}{p_end}
{phang2}{cmd:regtab, frame(m1) noint}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic expensive i.foreign mpg weight}{p_end}
{phang2}{cmd:regtab, frame(m2) noint}{p_end}
{phang2}{cmd:comptab m1 m2, rownames("foreign \ foreign") xlsx(composite.xlsx) sheet("Models") title("Table 4. Association with Price") zebra}{p_end}

{title:8. Incidence rates by exposure}
{phang2}{cmd:webuse diet, clear}{p_end}
{phang2}{cmd:stset dox, failure(fail) origin(time dob) enter(time doe) scale(365.25) id(id)}{p_end}
{phang2}{cmd:strate hienergy, per(1000) output(rate_hienergy, replace)}{p_end}
{phang2}{cmd:stratetab, using(rate_hienergy) xlsx(rates.xlsx) outcomes(1) outlabels("CHD Death") explabels("Energy Intake") title("Incidence Rates per 1,000 Person-Years") zebra}{p_end}

{title:9. Table 2 workflow with hrcomptab}
{phang2}{cmd:stratetab, using(edss4_tv edss6_tv recurring_tv edss4_dose edss6_dose recurring_dose) outcomes(3) frame(hrt_rates, replace)}{p_end}
{phang2}{cmd:regtab, frame(hrt_bin, replace) noint coef("HR")}{p_end}
{phang2}{cmd:regtab, frame(hrt_dose, replace) noint coef("HR")}{p_end}
{phang2}{cmd:hrcomptab hrt_rates, modelframes(hrt_bin hrt_dose) rows(1 \ 3/5) effect("aHR") xlsx(HRT.xlsx) sheet("Table 2")}{p_end}

{title:10. Console preview without Excel}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: regress price mpg weight i.foreign}{p_end}
{phang2}{cmd:regtab, noint}{p_end}
{phang2}{cmd:table1_tc, by(foreign) vars(price contn \ mpg conts \ rep78 cat)}{p_end}

{title:11. CSV export for R/Python users}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic foreign mpg weight price}{p_end}
{phang2}{cmd:regtab, xlsx(models.xlsx) sheet("OR") csv(models_for_R.csv) noint}{p_end}

{title:12. Frame output for downstream Stata analysis}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: logistic foreign mpg weight price}{p_end}
{phang2}{cmd:regtab, xlsx(models.xlsx) sheet("OR") frame(results) noint}{p_end}
{phang2}{cmd:frame results: list}{p_end}

{title:13. Custom theme setup}
{phang2}{cmd:tabtools set theme lancet}{p_end}
{phang2}{cmd:tabtools set theme custom, font(Calibri) fontsize(9) headercolor(200 220 240) zebracolor(240 245 250) borderstyle(thin)}{p_end}
{phang2}{cmd:tabtools get}{p_end}
{phang2}{cmd:tabtools set clear}{p_end}

{title:14. Dose-response pattern via regtab}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen byte price_cat = cond(price < 4000, 1, cond(price < 6000, 2, cond(price < 10000, 3, 4)))}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: regress mpg ib1.price_cat weight foreign}{p_end}
{phang2}{cmd:regtab, xlsx(dose_response.xlsx) sheet("Dose") title("MPG by Price Category") noint factorlabel}{p_end}

{title:15. Survival summary table}
{phang2}{cmd:webuse drugtr, clear}{p_end}
{phang2}{cmd:stset studytime, failure(died)}{p_end}
{phang2}{cmd:survtab, times(5 10 15 20) by(drug) xlsx(survival.xlsx) sheet("Table 2") title("Table 2. Survival Estimates by Treatment") median riskset difference theme(lancet)}{p_end}

{title:16. Diagnostic accuracy report}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:gen gold = (rep78 >= 4) if rep78 < .}{p_end}
{phang2}{cmd:diagtab mpg gold, cutoff(25) auc optimal xlsx(diagnostics.xlsx) sheet("Accuracy") title("Diagnostic Accuracy of MPG") prevalence(0.3) display}{p_end}

{title:17. Correlation matrix with significance stars}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:corrtab price mpg weight length displacement, spearman lower xlsx(correlations.xlsx) sheet("Table 4") title("Spearman Correlations") star(0.001 0.01 0.05) digits(2) theme(nejm)}{p_end}

{title:18. Events / N (%) from a table collect}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:collect clear}{p_end}
{phang2}{cmd:collect: table rep78 foreign, statistic(sum foreign) statistic(count foreign) statistic(mean foreign)}{p_end}
{phang2}{cmd:desctab, xlsx(desc_events.xlsx) sheet("Events") compose(events_n_pct) title("Events / N (%) by repair record and origin")}{p_end}

{title:19. Style a raw in-memory table with puttab}
{phang2}{cmd:sysuse auto, clear}{p_end}
{phang2}{cmd:regress price mpg weight i.foreign}{p_end}
{phang2}{cmd:matrix T = r(table)'}{p_end}
{phang2}{cmd:puttab using report.xlsx, sheet("Coefs") matrix(T) title("OLS Coefficients") digits(3) headershade}{p_end}
{phang2}{cmd:frame put make mpg price in 1/10, into(top)}{p_end}
{phang2}{cmd:puttab using report.xlsx, sheet("Top10") frame(top) title("First Ten Cars") varlabels theme(nejm) zebra}{p_end}

{title:20. Emit-then-assemble pipeline}
{phang2}{cmd:puttab term ahr ci using parts.xlsx, sheet("Primary") varlabels}{p_end}
{phang2}{cmd:puttab term ahr ci using parts.xlsx, sheet("Dose") varlabels}{p_end}
{phang2}{cmd:stacktab using parts.xlsx, sheet("Table 2") blocks(sheet(Primary) rows(1/4) cols(A-C) label(Any HRT use) \ sheet(Dose) rows(1/3) cols(A-C) label(By estrogen dose)) columnmerge(B+C as "aHR (95% CI)") spacing(1) title("Table 2. Hormone Therapy and Recurrent Events")}{p_end}

{title:21. Monte Carlo simulation performance table}
{phang2}{cmd:simtab estimator, estimate(estimate) se(se) true(true_value) by(scenario) estimand(estimand) sim(sim) coverage(covered) nsim(1000) metrics(mean bias empse meanse coverage n nonconv) xlsx("sim.xlsx") sheet("Table 2") borderstyle(academic) digits(3) plotframe(sim_plot, replace) display}{p_end}
{phang2}{cmd:simsum estimate, true(true_value) se(se) methodvar(estimator) id(sim) mcse clear}{p_end}
{phang2}{cmd:simtab, from(simsum) xlsx("sim.xlsx") sheet("Table 2") display}{p_end}

{hline}
{title:Also see}

{pstd}{helpb tabtools} - overview and settings{p_end}
{pstd}{helpb table1_tc}, {helpb desctab}, {helpb regtab}, {helpb effecttab},
{helpb stratetab}, {helpb survtab}, {helpb crosstab}, {helpb diagtab},
{helpb corrtab}, {helpb comptab}, {helpb hrcomptab}, {helpb puttab},
{helpb stacktab}, {helpb simtab} - command-specific help{p_end}

{marker author}{...}
{hline}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.8.0{p_end}

{hline}

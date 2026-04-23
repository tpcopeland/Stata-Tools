{smcl}
{* *! version 1.0.9  23apr2026}{...}
{title:tabtools Quick Reference (v1.0.9)}

{pstd}Common option combinations for each command.{p_end}

{hline}
{title:table1_tc}

{phang2}{cmd:table1_tc, by(group) vars(age contn \ sex bin \ race cat) xlsx(t1.xlsx) sheet("Table 1") title("Baseline")}{p_end}
{phang2}{cmd:table1_tc, by(group) vars(...) xlsx(t1.xlsx) sheet("T1") title("T1") smd} {it:// add SMD column}{p_end}
{phang2}{cmd:table1_tc, by(group) vars(...) xlsx(t1.xlsx) sheet("T1") title("T1") boldp(0.05) highlight(0.05)} {it:// bold + highlight significant rows}{p_end}
{phang2}{cmd:table1_tc, by(group) vars(...) xlsx(t1.xlsx) sheet("T1") title("T1") footnote("HR = hazard ratio") zebra}{p_end}
{phang2}{cmd:table1_tc, by(group) vars(...) wt(iptw) xlsx(t1.xlsx) sheet("Weighted") title("IPTW-Weighted")} {it:// weighted statistics, unweighted N}{p_end}

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
{phang2}{cmd:regtab, frame(bin_models, replace) noint coef("HR")} {it:// after collect: stcox ... for the binary exposure models}{p_end}
{phang2}{cmd:regtab, frame(dose_models, replace) noint coef("HR")} {it:// after collect: stcox ... for the dose-category models}{p_end}
{phang2}{cmd:hrcomptab rates, modelframes(bin_models dose_models) rows(1 \ 3/5) xlsx(table2.xlsx) sheet("Table 2") effect("aHR")}{p_end}

{hline}
{title:tabtools set/get}

{phang2}{cmd:tabtools set font Calibri} {it:// persist across all commands}{p_end}
{phang2}{cmd:tabtools set fontsize 11}{p_end}
{phang2}{cmd:tabtools set borderstyle thin}{p_end}
{phang2}{cmd:tabtools get} {it:// view current defaults}{p_end}
{phang2}{cmd:tabtools set clear} {it:// reset to command defaults}{p_end}

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
{phang2}{cmd:comptab f1 f2, rows(1 \ 1) xlsx(comp.xlsx) sheet("Combined")}{p_end}

{hline}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.9{p_end}

{hline}

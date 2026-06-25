{smcl}
{* *! version 1.8.6  25jun2026}{...}
{viewerjumpto "Syntax" "survtab##syntax"}{...}
{viewerjumpto "Description" "survtab##description"}{...}
{viewerjumpto "Options" "survtab##options"}{...}
{viewerjumpto "Examples" "survtab##examples"}{...}
{viewerjumpto "Stored results" "survtab##stored"}{...}
{viewerjumpto "Also see" "survtab##alsosee"}{...}
{viewerjumpto "Author" "survtab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "sts" "help sts"}{...}
{vieweralsosee "stci" "help stci"}{...}
{title:survtab}

{pstd}Survival summary table with Kaplan-Meier estimates, median survival,
and restricted mean survival time.{p_end}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:survtab}, {opt times(numlist)} [{opt by(varname)} {opt rmst(#)}
{opt med:ian} {opt risk:set} {opt timeu:nit(string)} {opt rev:erse} {opt diff:erence}
{opt ev:ents} {opt dig:its(#)}
{opt xlsx(filename)} {opt excel(filename)} {opt sheet(string)} {opt title(string)}
{opt foot:note(string)} {opt the:me(string)} {opt border:style(string)}
{opt headers:hade} {opt headerc:olor(string)} {opt bold:p(#)} {opt zebra} {opt zebrac:olor(string)} {opt high:light(#)} {opt pdp(#)} {opt highpdp(#)}
{opt csv(filename)} {opt markdown(filename)} {opt mdappend} {opt fra:me(name)} {opt dis:play} {opt open}
{opt addr:ow(string asis)}]{p_end}

{pstd}Data must be {helpb stset} before running {cmd:survtab}.{p_end}

{marker description}{title:Description}

{pstd}{cmd:survtab} generates a publication-ready survival summary table from
{helpb stset} data. It computes Kaplan-Meier survival probabilities (or
cumulative incidence when {opt reverse} is specified) at user-specified
timepoints and, optionally, median survival with 95% CI, the number at risk
at each timepoint, restricted mean survival time (RMST), and between-group
comparisons via the log-rank test.{p_end}

{pstd}A typical use case is constructing a Table 2 for a manuscript: two or
more treatment arms, survival at clinically meaningful timepoints, and a
log-rank p-value. Adding {opt median}, {opt riskset}, and {opt difference}
extends the table to the full set of survival summary measures often
requested by reviewers.{p_end}

{pstd}Output can be exported to a professionally formatted Excel workbook,
displayed automatically in the Results window, saved as CSV, or stored in a Stata
{helpb frames:frame} for programmatic access. All tabtools formatting
options — themes, borders, zebra striping, bold p-values, and custom
colors — are supported.{p_end}

{marker options}{title:Options}

{synoptset 27 tabbed}{...}
{synoptline}
{syntab:Required}
{synopt:{opt times(numlist)}}analysis timepoints for Kaplan-Meier estimates{p_end}

{syntab:Analysis}
{synopt:{opt by(varname)}}grouping variable for between-group comparison{p_end}
{synopt:{opt rmst(#)}}restricted mean survival time truncated at specified horizon{p_end}
{synopt:{opt med:ian}}include median survival with 95% CI{p_end}
{synopt:{opt risk:set}}add number-at-risk rows at each timepoint{p_end}
{synopt:{opt timeu:nit(string)}}time unit label: {cmd:years} (default), {cmd:months}, {cmd:days}, {cmd:weeks}{p_end}
{synopt:{opt rev:erse}}report cumulative incidence (1 minus survival){p_end}
{synopt:{opt diff:erence}}add between-group difference column; requires {cmd:by()} with exactly 2 groups{p_end}
{synopt:{opt ev:ents}}add aggregate Events / N row per group{p_end}

{syntab:Output}
{synopt:{opt xlsx(filename)}}Excel workbook; filename must end in {cmd:.xlsx}; {opt excel()} is a synonym{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default is {cmd:"Survival"}{p_end}
{synopt:{opt title(string)}}table title in row 1{p_end}
{synopt:{opt foot:note(string)}}footnote below the table{p_end}
{synopt:{opt dis:play}}accepted for compatibility; the completed table is displayed automatically{p_end}
{synopt:{opt csv(filename)}}export a CSV file{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{opt fra:me(name)}}store output in a named Stata frame; specify {cmd:frame(name, replace)} to replace{p_end}
{synopt:{opt open}}open the Excel file after export{p_end}

{syntab:Formatting}
{synopt:{opt the:me(string)}}journal-style theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt bold:p(#)}}bold log-rank p-value and summary row when p < threshold{p_end}
{synopt:{opt headers:hade}}shade header row background{p_end}
{synopt:{opt headerc:olor(string)}}custom header background color as {it:R G B} (e.g., {cmd:"219 229 241"}){p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt zebrac:olor(string)}}custom zebra stripe color as {it:R G B} (e.g., {cmd:"237 242 249"}){p_end}
{synopt:{opt high:light(#)}}highlight log-rank summary row when p < threshold{p_end}
{synopt:{opt dig:its(#)}}decimal places for survival estimates and CIs (default 1, range 0-6){p_end}
{synopt:{opt pdp(#)}}max decimal places for small p-values (p < 0.10); default 3{p_end}
{synopt:{opt highpdp(#)}}max decimal places for large p-values (p >= 0.10); default 2{p_end}
{synopt:{opt addr:ow(string asis)}}append custom rows below table body{p_end}
{synoptline}

{pstd}When {opt rmst()} is used, interpret RMST summaries relative to the requested truncation time. The estimate is restricted to the observed follow-up window up to that horizon and should not be read as a lifetime mean survival measure.{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Basic survival table}{p_end}
{phang2}{stata "webuse drugtr, clear":. webuse drugtr, clear}{p_end}
{phang2}{stata "stset studytime, failure(died)":. stset studytime, failure(died)}{p_end}
{phang2}{cmd:. survtab, times(10 20 30) by(drug) ///}{p_end}
{phang3}{cmd:xlsx(survival.xlsx) sheet("KM") ///}{p_end}
{phang3}{cmd:title("Survival by Treatment Group") ///}{p_end}
{phang3}{cmd:riskset difference zebra}{p_end}

{pstd}{bf:Example 2: Cumulative incidence with RMST}{p_end}
{phang2}{cmd:. survtab, times(10 20 30) by(drug) reverse rmst(30) ///}{p_end}
{phang3}{cmd:xlsx(survival.xlsx) sheet("CI") ///}{p_end}
{phang3}{cmd:title("Cumulative Incidence") timeunit(months)}{p_end}

{pstd}{bf:Example 3: Median survival only}{p_end}
{phang2}{cmd:. survtab, times(10 20 30) by(drug) median events ///}{p_end}
{phang3}{cmd:xlsx(survival.xlsx) sheet("Median") ///}{p_end}
{phang3}{cmd:title("Median Survival by Treatment Group") ///}{p_end}
{phang3}{cmd:footnote("P-value from log-rank test.") boldp(0.05)}{p_end}

{pstd}{bf:Example 4: Console preview}{p_end}
{phang2}{cmd:. survtab, times(10 20 30) by(drug) display}{p_end}

{marker stored}{title:Stored results}

{pstd}{cmd:survtab} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in output table{p_end}
{synopt:{cmd:r(logrank_p)}}log-rank test p-value (when {cmd:by()} specified){p_end}
{synopt:{cmd:r(logrank_chi2)}}log-rank test chi-squared statistic{p_end}
{synopt:{cmd:r(median_{it:#})}}median survival for group {it:#} (when {cmd:median}){p_end}
{synopt:{cmd:r(events_{it:#})}}event count for group {it:#} (when {cmd:events}){p_end}
{synopt:{cmd:r(atrisk_{it:#})}}group denominator for group {it:#} (when {cmd:events}){p_end}
{synopt:{cmd:r(rmst_diff)}}RMST difference (when {cmd:rmst()} and exactly 2 groups are compared){p_end}
{synopt:{cmd:r(rmst_{it:#})}}restricted mean survival time for group {it:#}{p_end}
{synopt:{cmd:r(rmst_se_{it:#})}}standard error of RMST for group {it:#}{p_end}
{synopt:{cmd:r(rmst_lb_{it:#})}}lower 95% CI bound of RMST for group {it:#}{p_end}
{synopt:{cmd:r(rmst_ub_{it:#})}}upper 95% CI bound of RMST for group {it:#}{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}
{synopt:{cmd:r(csv)}}CSV path, when exported{p_end}
{synopt:{cmd:r(methods)}}methods paragraph for manuscript text{p_end}
{synopt:{cmd:r(frame)}}frame name (when {cmd:frame()} specified){p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}survival estimates at each timepoint by group{p_end}

{marker alsosee}{title:Also see}

{psee}
{helpb tabtools}, {helpb stratetab}, {helpb effecttab},
{helpb tabtools_tips}, {helpb sts}, {helpb stci}
{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.8.6{p_end}

{hline}

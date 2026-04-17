{smcl}
{* *! version 1.0.5  17apr2026}{...}
{viewerjumpto "Package overview" "fittab##package"}{...}
{viewerjumpto "Syntax" "fittab##syntax"}{...}
{viewerjumpto "Description" "fittab##description"}{...}
{viewerjumpto "Options" "fittab##options"}{...}
{viewerjumpto "Examples" "fittab##examples"}{...}
{viewerjumpto "Stored results" "fittab##stored"}{...}
{viewerjumpto "Author" "fittab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "estimates stats" "help estimates stats"}{...}
{vieweralsosee "lrtest" "help lrtest"}{...}
{title:fittab}

{pstd}Model comparison table with fit statistics.{p_end}

{marker package}{title:Package}

{pstd}{cmd:fittab} is part of the {helpb tabtools} suite. Use {helpb estimates store}
to save models first, then compare them with {cmd:fittab}. See {helpb regtab}
and {helpb effecttab} for related table-formatting commands based on active
{helpb collect} results.{p_end}

{hline}

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:fittab} {it:namelist}, [{opt xlsx(filename)} {opt stats(string)}
{opt labels(string)} {opt lrtest(name)} {opt sheet(string)} {opt title(string)}
{opt footnote(string)} {opt theme(string)}
{opt borderstyle(string)} {opt zebra} {opt csv(filename)} {opt frame(name)}
{opt display} {opt open}]{p_end}

{pstd}{it:namelist} is a list of stored estimate names (from {helpb estimates store}).{p_end}

{marker description}{title:Description}

{pstd}{cmd:fittab} compares stored estimation results side-by-side. It
extracts fit statistics (N, AIC, BIC, log-likelihood, C-statistic, R-squared)
and exports them in a formatted table.{p_end}

{marker options}{title:Options}

{synoptset 22 tabbed}{...}
{synoptline}
{synopt:{opt xlsx(filename)}}export to Excel; if omitted, results are shown in the Results window only{p_end}
{synopt:{opt stats(string)}}statistics to report. Default: {cmd:n aic bic ll}.
Available: {cmd:n aic bic ll cstat r2 adjr2 rmse}{p_end}
{synopt:{opt labels(string)}}model labels separated by backslash ({cmd:\}); otherwise stored estimate names are used{p_end}
{synopt:{opt lrtest(name)}}likelihood-ratio test each model against this reference model{p_end}
{synopt:{opt sheet(string)}}Excel sheet name; default is {cmd:"Model Comparison"}{p_end}
{synopt:{opt title(string)}}table title written above the comparison matrix{p_end}
{synopt:{opt footnote(string)}}footnote text below the table{p_end}
{synopt:{opt theme(string)}}journal-style formatting theme such as {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, or {cmd:apa}{p_end}
{synopt:{opt borderstyle(string)}}border style: {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt csv(filename)}}also export the comparison table as CSV{p_end}
{synopt:{opt frame(name)}}store the output dataset in a named Stata frame{p_end}
{synopt:{opt display}}show the formatted table in the Results window{p_end}
{synopt:{opt open}}open the Excel file after export{p_end}
{synoptline}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Basic model comparison with labels and theme}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{cmd:. regress price mpg}{p_end}
{phang2}{cmd:. estimates store m1}{p_end}
{phang2}{cmd:. regress price mpg weight}{p_end}
{phang2}{cmd:. estimates store m2}{p_end}
{phang2}{cmd:. regress price mpg weight foreign}{p_end}
{phang2}{cmd:. estimates store m3}{p_end}
{phang2}{cmd:. fittab m1 m2 m3, stats(n aic bic r2 adjr2) ///}{p_end}
{phang3}{cmd:labels("Bivariate \ Adjusted \ Full") ///}{p_end}
{phang3}{cmd:xlsx(comparison.xlsx) title("Model Comparison") ///}{p_end}
{phang3}{cmd:theme(lancet) zebra}{p_end}

{pstd}{bf:Example 2: Likelihood ratio test against a base model}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{cmd:. regress price mpg}{p_end}
{phang2}{cmd:. estimates store base}{p_end}
{phang2}{cmd:. regress price mpg weight length}{p_end}
{phang2}{cmd:. estimates store extended}{p_end}
{phang2}{cmd:. fittab base extended, lrtest(base) ///}{p_end}
{phang3}{cmd:labels("Base \ Extended") ///}{p_end}
{phang3}{cmd:stats(n aic bic ll) display}{p_end}

{pstd}{bf:Example 3: Logistic regression comparison}{p_end}
{phang2}{stata "webuse lbw, clear":. webuse lbw, clear}{p_end}
{phang2}{cmd:. logit low age lwt smoke}{p_end}
{phang2}{cmd:. estimates store logit1}{p_end}
{phang2}{cmd:. logit low age lwt smoke ptl ht ui}{p_end}
{phang2}{cmd:. estimates store logit2}{p_end}
{phang2}{cmd:. fittab logit1 logit2, stats(n aic bic ll) ///}{p_end}
{phang3}{cmd:labels("Parsimonious \ Full") display}{p_end}

{marker stored}{title:Stored results}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N_models)}}number of models compared{p_end}
{synopt:{cmd:r(best_aic)}}lowest AIC value{p_end}
{synopt:{cmd:r(best_bic)}}lowest BIC value{p_end}

{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}statistics matrix (rows=stats, cols=models){p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}
{synopt:{cmd:r(frame)}}frame name (if saved){p_end}
{synopt:{cmd:r(methods)}}methods paragraph for manuscript text{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.5{p_end}

{hline}

{smcl}
{viewerjumpto "Syntax" "crosstab##syntax"}{...}
{viewerjumpto "Description" "crosstab##description"}{...}
{viewerjumpto "Options" "crosstab##options"}{...}
{viewerjumpto "Examples" "crosstab##examples"}{...}
{viewerjumpto "Stored results" "crosstab##stored"}{...}
{viewerjumpto "Also see" "crosstab##alsosee"}{...}
{viewerjumpto "Author" "crosstab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "corrtab" "help corrtab"}{...}
{vieweralsosee "diagtab" "help diagtab"}{...}
{vieweralsosee "tabulate twoway" "help tabulate twoway"}{...}
{title:Title}

{phang}
{bf:crosstab} {hline 2} Cross-tabulation table with association measures for Excel and Markdown export

{marker syntax}{title:Syntax}

{p 4 8 2}{cmd:crosstab} {it:rowvar} {it:colvar} [{it:if}] [{it:in}] [{it:fweight}],
[{opt xlsx(filename)} {opt excel(filename)} {opt col:pct} {opt row:pct} {opt total:pct}
{opt or} {opt rr} {opt rd} {opt tr:end} {opt coch:ran} {opt ex:act} {opt fi:sher}
{opt lab:el} {opt mis:sing} {opt dig:its(#)}
{opt sheet(string)} {opt title(string)} {opt foot:note(string)}
{opt the:me(string)} {opt border:style(string)} {opt bold:p(#)} {opt zebra}
{opt headers:hade} {opt headerc:olor(string)} {opt zebrac:olor(string)}
{opt csv(filename)} {opt markdown(filename)} {opt mdappend} {opt fra:me(name)} {opt open}]{p_end}

{marker description}{title:Description}

{pstd}{cmd:crosstab} generates a formatted cross-tabulation table with
frequencies, percentages, and association measures (OR, RR, RD). {it:rowvar}
and {it:colvar} must be numeric categorical variables. The command supports
Pearson's chi-squared test, Fisher's exact test (auto-selected when expected
cells are sparse), and a Spearman rank-correlation trend test.{p_end}

{marker options}{title:Options}

{synoptset 20 tabbed}{...}
{synoptline}
{syntab:Percentages}
{synopt:{opt col:pct}}column percentages (default); may not be combined with {opt rowpct} or {opt totalpct}{p_end}
{synopt:{opt row:pct}}row percentages; may not be combined with {opt colpct} or {opt totalpct}{p_end}
{synopt:{opt total:pct}}total percentages; may not be combined with {opt colpct} or {opt rowpct}{p_end}
{syntab:Association measures}
{synopt:{opt or}}odds ratio with 95% CI; requires a 2x2 table{p_end}
{synopt:{opt rr}}risk ratio with 95% CI; requires a 2x2 table{p_end}
{synopt:{opt rd}}risk difference with 95% CI; requires a 2x2 table{p_end}
{synopt:{opt tr:end}}Test for trend across ordered columns via Spearman rank correlation ({it:fweight}s honored).{p_end}
{synopt:{opt coch:ran}}Cochran-Armitage test for trend in the proportion of the higher row (outcome) level across ordered column scores; requires a binary {it:rowvar}. Mutually exclusive with {opt trend}. See {help crosstab##trendnote:Trend tests}.{p_end}
{syntab:Tests}
{synopt:{opt ex:act}}force Fisher's exact test{p_end}
{synopt:{opt fi:sher}}force Fisher's exact test (synonym for {opt exact}){p_end}
{syntab:Content}
{synopt:{opt lab:el}}use value labels for row and column headers{p_end}
{synopt:{opt mis:sing}}include observations with missing values as a separate category{p_end}
{synopt:{opt dig:its(#)}}decimal places for percentages and association measures (default 1, range 0-6){p_end}
{syntab:Output}
{synopt:{opt sheet(string)}}Excel sheet name (default {cmd:"Crosstab"}){p_end}
{synopt:{opt title(string)}}title row in the exported table{p_end}
{synopt:{cmdab:foot:note(}{it:string}{cmd:)}}footnote row below the table{p_end}
{syntab:Formatting}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}journal-style formatting theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt bold:p(#)}}bold test and trend rows when p-values fall below the threshold; must be between 0 and 1{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{cmdab:headers:hade}}apply background fill to the header row{p_end}
{synopt:{opt headerc:olor(string)}}custom header color as a supported Stata color name or RGB triplet{p_end}
{synopt:{opt zebrac:olor(string)}}custom zebra color as a supported Stata color name or RGB triplet{p_end}
{synoptline}
{synopt:{opt xlsx(filename)}}export to Excel; filename must end in {cmd:.xlsx}{p_end}
{synopt:{opt excel(filename)}}synonym for {opt xlsx(filename)}{p_end}
{synopt:{opt csv(filename)}}also export the output dataset as CSV{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}store the output dataset in a named Stata frame; specify {cmd:frame(name, replace)} to replace an existing frame{p_end}
{synopt:{opt open}}open the Excel file after export; requires {opt xlsx()} or {opt excel()}{p_end}

{pstd}{cmd:crosstab} supports {it:fweight}s only. When you request {opt or},
{opt rr}, or {opt rd}, the command internally recodes the first observed level
of {it:rowvar} and {it:colvar} to 0 and the second observed level to 1 before
calling Stata's {helpb cc} or {helpb cs}. The reported measures therefore
compare the second observed column level versus the first for the second
observed row level versus the first. Observed levels follow Stata's numeric
level order, not value-label display order; use the variable coding that
matches the direction you want to report. If a requested association measure is
undefined, for example because a required 2x2 cell count is zero, {cmd:crosstab}
exits with an error instead of silently omitting the measure.{p_end}

{marker trendnote}{title:Trend tests}

{pstd}{cmd:crosstab} offers two trend tests, and they answer different
questions. {opt trend} runs a {bf:Spearman rank-correlation} test — a general
ordinal-by-ordinal association across the ordered column levels — and is the
right default when both variables are ordinal. {opt cochran} runs the classic
{bf:Cochran-Armitage} test for a {bf:linear trend in a binary outcome across an
ordered exposure}: {it:rowvar} must be binary (the outcome), and the ordered
{it:colvar} supplies the column scores. Column scores are the numeric
{it:colvar} values, so recoding {it:colvar} (for example, to dose levels)
changes the assumed spacing. The two options are mutually exclusive; both store
their p-value in {cmd:r(p_trend)} and label the trend row accordingly.
{it:fweight}s are honored by both.{p_end}

{marker examples}{title:Examples}

{pstd}{bf:Example 1: Basic 2x2 table with OR}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "gen byte expensive = (price > 6000)":. gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:. crosstab expensive foreign, or label ///}{p_end}
{phang3}{cmd:xlsx(crosstab.xlsx) title("Price by Origin")}{p_end}

{pstd}{bf:Example 2: Risk ratios and trend test}{p_end}
{phang2}{cmd:. crosstab expensive foreign, rr rd trend label ///}{p_end}
{phang3}{cmd:xlsx(crosstab.xlsx) sheet("RR") ///}{p_end}
{phang3}{cmd:title("Risk Ratios and Trend Test")}{p_end}

{pstd}{bf:Example 3: Cochran-Armitage trend for a binary outcome across an ordered exposure}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "gen byte expensive = (price > 6000)":. gen byte expensive = (price > 6000)}{p_end}
{phang2}{cmd:. crosstab expensive rep78, cochran label}{p_end}

{pstd}{bf:Example 4: Console preview}{p_end}
{phang2}{cmd:. crosstab rep78 foreign, label}{p_end}

{pstd}{bf:Example 5: Row percentages with Fisher's exact test}{p_end}
{phang2}{cmd:. crosstab rep78 foreign, rowpct fisher label ///}{p_end}
{phang3}{cmd:xlsx(crosstab.xlsx) sheet("Fisher") ///}{p_end}
{phang3}{cmd:title("Repair Record by Origin") zebra}{p_end}

{marker stored}{title:Stored results}

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total observations{p_end}
{synopt:{cmd:r(chi2)}}chi-squared statistic when Pearson's chi-squared test is used{p_end}
{synopt:{cmd:r(p)}}p-value from the reported test{p_end}
{synopt:{cmd:r(or)}}odds ratio (2x2){p_end}
{synopt:{cmd:r(rr)}}risk ratio (2x2){p_end}
{synopt:{cmd:r(rd)}}risk difference (2x2){p_end}
{synopt:{cmd:r(p_trend)}}trend p-value (Spearman or Cochran-Armitage){p_end}
{synopt:{cmd:r(chi2_trend)}}Cochran-Armitage trend chi-squared statistic (1 df; when {opt cochran} is used){p_end}
{synopt:{cmd:r(z_trend)}}Cochran-Armitage trend z statistic (when {opt cochran} is used){p_end}

{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}frequency matrix{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(methods)}}methods paragraph for manuscript text{p_end}
{synopt:{cmd:r(trend_method)}}trend test used ({cmd:Spearman rank correlation} or {cmd:Cochran-Armitage}); returned when a trend test is requested{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename (if exported){p_end}
{synopt:{cmd:r(sheet)}}sheet name (if exported){p_end}
{synopt:{cmd:r(frame)}}frame name (if specified){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}

{marker alsosee}{title:Also see}

{psee}
{helpb tabtools}, {helpb corrtab}, {helpb diagtab},
{helpb tabtools_tips}, {helpb tabulate twoway}
{p_end}

{marker author}{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}

{hline}

{smcl}
{* *! version 1.5.2  06jun2026}{...}
{viewerjumpto "Syntax" "table1_tc##syntax"}{...}
{viewerjumpto "Description" "table1_tc##description"}{...}
{viewerjumpto "Examples" "table1_tc##examples"}{...}
{viewerjumpto "Stored results" "table1_tc##stored"}{...}
{viewerjumpto "Technical notes" "table1_tc##technical"}{...}
{viewerjumpto "Author" "table1_tc##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{hline}
help for {cmd:table1_tc}
{hline}

{title:Title}

{p2colset 5 15 21 2}{...}
{p2col: {bf:table1_tc}}{hline 2} Create "Table 1" of baseline characteristics for a manuscript

{marker syntax}{...}
{title:Syntax}

{pstd}{bf:Quick start (recommended):}{p_end}

{p 8 18 2}
{opt table1_tc} [{it:varlist}] {ifin} {weight} [{cmd:,} {opt by(varname)} {it:options}]

{pstd}When a {it:varlist} is provided without {opt vars()}, each variable's type is automatically
detected using the command's built-in type-classification heuristics. This is the simplest way to
use {cmd:table1_tc}.{p_end}

{pstd}{bf:Advanced (explicit types):}{p_end}

{p 8 18 2}
{opt table1_tc} {ifin} {weight}, {opt vars(var_spec)} [{it:options}]

{phang}{it:var_spec} = {it: varname vartype} [{it:{help fmt:%fmt1}} [{it:{help fmt:%fmt2}}]] [ \ {it:varname vartype} [{it:{help fmt:%fmt1}} [{it:{help fmt:%fmt2}}]] \ ...]

{phang}where {it: vartype} is one of:{p_end}
{tab}auto   - automatic type detection (default when vartype omitted)
{tab}contn  - continuous, normally distributed  (mean and SD will be reported)
{tab}contln - continuous, log normally distributed (geometric mean and GSD reported)
{tab}conts  - continuous, neither log normally or normally distributed (median, Q1 and Q3 reported)
{tab}cat    - categorical, groups compared using Pearson's chi-square test
{tab}cate   - categorical, groups compared using Fisher's exact test
{tab}bin    - binary (0/1), groups compared using Pearson's chi-square test
{tab}bine   - binary (0/1), groups compared using Fisher's exact test

{phang}{opt fweight}s are allowed; see {help weight}


{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Weighting}
{synopt:{opt wt(varname)}}importance/probability weight variable (e.g., IPTW); shows weighted statistics with unweighted N; categorical/binary variables default to percent-only display (override with {opt percent_n}); p-values are suppressed{p_end}

{syntab:Columns/Rows}
{synopt:{opt by(varname)}}group observations by {it:varname}{p_end}
{synopt:{opt total(before|after)}}include a total column before/after group columns{p_end}
{synopt:{opt mis:sing}}treat missing values as another category for categorical variables{p_end}
{synopt:{opt test}}include column describing the significance test used{p_end}
{synopt:{opt stat:istic}}include column describing the value of the test statistic{p_end}
{synopt:{opt headerp:erc}}add percentage of total to sample size row{p_end}
{synopt:{opt smd}}add standardized mean differences column (requires {opt by()}){p_end}
{synopt:{opt nop:value}}suppress the p-value column (and associated test/statistic columns){p_end}

{syntab:Contents of Cells}
{synopt:{opt f:ormat(%fmt)}}default display format for continuous variables{p_end}
{synopt:{opt percf:ormat(%fmt)}}default display format for percentages{p_end}
{synopt:{opt nf:ormat(%fmt)}}display format for n and N; default is %12.0fc{p_end}
{synopt:{opt varlabplus}}add data type description after variable labels{p_end}
{synopt:{opt iqrmiddle("string")}}symbol between Q1 and Q3; default is "-"{p_end}
{synopt:{opt sdleft("string")}}symbol before SD; default is " ("{p_end}
{synopt:{opt sdright("string")}}symbol after SD; default is ")"{p_end}
{synopt:{opt gsdleft("string")}}symbol before GSD; default is " (×/"{p_end}
{synopt:{opt gsdright("string")}}symbol after GSD; default is ")"{p_end}
{synopt:{opt percsign("string")}}percent sign; default is "%"{p_end}
{synopt:{opt nospace:lowpercent}}report (3%) instead of ( 3%){p_end}
{synopt:{opt extraspace}}helps alignment in .docx with non-monospaced fonts{p_end}
{synopt:{opt percent}}report % only (no N) for categorical/binary vars{p_end}
{synopt:{opt percent_n}}report % (n) rather than n (%){p_end}
{synopt:{opt slashN}}report n/N instead of n{p_end}
{synopt:{opt catrowperc}}report row % for categorical vars{p_end}
{synopt:{opt pdp(#)}}max decimal places for p < 0.10; default is 3{p_end}
{synopt:{opt highpdp(#)}}max decimal places for p >= 0.10; default is 2{p_end}

{syntab:Excel Output}
{synopt:{opt xlsx("filename")}}save table to Excel file; {opt excel()} is a synonym; target must end in {.xlsx}{p_end}
{synopt:{opt sheet("string")}}Excel sheet name; default is "Table 1"; available only with {opt xlsx()}/{opt excel()}{p_end}
{synopt:{opt title("string")}}title for the Excel table{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{opt the:me(string)}}journal-style formatting preset: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{opt bold:p(#)}}bold p-value cells below threshold{p_end}
{synopt:{opt foot:note(string)}}add footnote row below table{p_end}
{synopt:{opt open}}open the exported workbook; requires {opt xlsx()} or {opt excel()}{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{opt headers:hade}}apply shading to header rows{p_end}
{synopt:{opt high:light(#)}}highlight rows where p < threshold{p_end}
{synopt:{opt smdt:hreshold(#)}}SMD threshold for orange highlighting in Excel; default is 0.1; use -1 to disable{p_end}
{synopt:{opt headerc:olor(string)}}custom header background color; named Excel color or RGB triplet such as {cmd:"200 220 240"}{p_end}
{synopt:{opt zebrac:olor(string)}}custom zebra stripe color; named Excel color or RGB triplet such as {cmd:"240 245 250"}{p_end}
{synopt:{opt csv("filename")} {opt markdown(filename)} {opt mdappend}}also export as CSV file{p_end}
{synopt:{opt markdown(filename)}}export the rendered table as GitHub-Flavored Markdown; may be combined with Excel, CSV, and frame exports{p_end}
{synopt:{opt mdappend}}append the Markdown table to an existing file; requires {opt markdown()}{p_end}

{syntab:Frame & Pipeline}
{synopt:{opt fra:me(name[, replace])}}store output in a named Stata frame{p_end}

{syntab:Other}
{synopt:{opt clear}}replace dataset in memory with the table{p_end}
{synopt:{opt dots}}show progress dots while processing variables{p_end}
{synopt:{opt missings:ummary}}add missing data summary row per variable{p_end}
{synopt:{opt noi:sily}}display detailed processing output{p_end}
{synopt:{opt wtc:ompare}}show unweighted statistics alongside weighted (requires {opt wt()}){p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{opt table1_tc} generates a "Table 1" of characteristics for a manuscript. Such a table generally
includes a collection of baseline characteristics which may be either continuous or categorical. The
observations are often grouped, with a "p-value" column on the right comparing the characteristics
between groups.{p_end}

{pstd}{bf:Auto-type detection:} When you provide a varlist without {opt vars()}, or use the {cmd:auto}
type keyword, each variable's type is automatically classified:{p_end}

{p 8 8 2}1. String variables or variables with value labels (>2 levels) → {cmd:cat}{p_end}
{p 8 8 2}2. Variables with exactly 2 unique values → {cmd:bin}{p_end}
{p 8 8 2}3. Variables with ≤7 unique values → {cmd:cat}{p_end}
{p 8 8 2}4. Variables with >7 unique values → distributional classification via the shared helper:{p_end}
{p 12 12 2}p ≥ 0.05 → {cmd:contn} (normal){p_end}
{p 12 12 2}p < 0.05 → {cmd:conts} (skewed){p_end}

{pstd}This command is a fork of {cmd:table1_mc} version 3.5 by Mark Chatfield, with enhancements
including Excel and Markdown export, journal themes, auto-type detection, IPTW weighting, SMD, and a methods
paragraph generator.{p_end}

{pstd}{bf:Themes:} The {opt theme()} option applies journal-inspired formatting presets that
match the current {cmd:tabtools} theme defaults:{p_end}
{p 8 8 2}{cmd:lancet} - Arial 9pt, academic borders, no header shading{p_end}
{p 8 8 2}{cmd:nejm} - Arial 10pt, academic borders, zebra striping{p_end}
{p 8 8 2}{cmd:bmj} - Arial 10pt, academic borders, no header shading{p_end}
{p 8 8 2}{cmd:apa} - Times New Roman 12pt, academic borders{p_end}
{p 8 8 2}{cmd:jama} - Arial 10pt, academic borders, no header shading{p_end}
{p 8 8 2}{cmd:plos} - Arial 10pt, thin borders, no header shading{p_end}
{p 8 8 2}{cmd:nature} - Arial 7pt, academic borders, no header shading{p_end}
{p 8 8 2}{cmd:cell} - Arial 10pt, academic borders, no header shading{p_end}
{p 8 8 2}{cmd:annals} - Arial 10pt, academic borders, zebra striping{p_end}
{pstd}Publishers may restyle accepted tables during production, so treat these as built-in
Excel presets rather than exact house templates.{p_end}

{pstd}{bf:Frame output:} The {opt frame()} option stores the results table in a Stata frame
for programmatic access without replacing data in memory.{p_end}

{pstd}{bf:Pipeline:} After running {cmd:table1_tc}, use {cmd:r(varlist)} to pass the variable list
directly to a regression model:{p_end}
{p 8 8 2}{cmd:table1_tc age sex bmi, by(treated)}{p_end}
{p 8 8 2}{cmd:local myvars `r(varlist)'}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}{bf:Quick start — auto-detect all variable types:}{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. table1_tc rep78 foreign, by(foreign)}{p_end}

{pstd}{bf:With Excel and Markdown export and formatting:}{p_end}

{phang2}{cmd:. table1_tc price mpg weight rep78, by(foreign) ///}{p_end}
{phang3}{cmd:xlsx("table1.xlsx") title("Table 1") smd theme(lancet)}{p_end}

{pstd}{bf:Explicit variable types (advanced):}{p_end}

{phang2}{cmd:. table1_tc, by(foreign) ///}{p_end}
{phang3}{cmd:vars(price contn %8.0fc \ mpg contn %5.1f \ weight contn \ ///}{p_end}
{phang3}{cmd:     rep78 cat \ headroom conts) ///}{p_end}
{phang3}{cmd:xlsx("table1_detail.xlsx") sheet("Baseline") ///}{p_end}
{phang3}{cmd:title("Table 1. Baseline Characteristics") smd zebra}{p_end}

{pstd}{bf:IPTW-weighted Table 1:}{p_end}

{phang2}{cmd:. table1_tc, by(treated) wt(iptw) ///}{p_end}
{phang3}{cmd:vars(age contn \ female bin \ education cat \ bmi contn)}{p_end}

{pstd}{bf:Custom SMD threshold (0.2 instead of 0.1):}{p_end}

{phang2}{cmd:. table1_tc age sex bmi, by(treated) smd smdthreshold(0.2) ///}{p_end}
{phang3}{cmd:xlsx("table1_smd.xlsx")}{p_end}

{pstd}{bf:Store results in a frame:}{p_end}

{phang2}{cmd:. table1_tc age sex bmi, by(treated) frame(mytable, replace)}{p_end}
{phang2}{cmd:. frame mytable: list}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:table1_tc} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(Dapa)}}data-presentation description built from the resolved variable types; returned even with {opt varlabplus}{p_end}
{synopt:{cmd:r(methods)}}extended methods paragraph describing statistical tests used (when {opt by()} specified without {opt wt()}){p_end}
{synopt:{cmd:r(varlist)}}space-separated list of processed variables{p_end}
{synopt:{cmd:r(xlsx)}}path to exported Excel file (when {opt xlsx()} specified){p_end}
{synopt:{cmd:r(sheet)}}Excel sheet name (when {opt xlsx()} specified){p_end}
{synopt:{cmd:r(frame)}}frame name (if {cmd:frame()} specified){p_end}
{synopt:{cmd:r(markdown)}}Markdown filename (if exported){p_end}
{synopt:{cmd:r(markdown_rows)}}body rows written to Markdown{p_end}
{synopt:{cmd:r(markdown_cols)}}columns written to Markdown{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}numeric matrix of raw {cmd:p_value} and absolute {cmd:smd} for top-level variable rows; omitted when no such columns exist or when the table has more than 200 rows{p_end}


{marker technical}{...}
{title:Technical notes}

{pstd}{bf:SMD methodology:} Standardized mean differences are computed as follows:{p_end}
{p 8 8 2}Continuous variables: Cohen's d with pooled standard deviation (Austin, 2009){p_end}
{p 8 8 2}Binary variables: difference in proportions / pooled SD of proportions{p_end}
{p 8 8 2}Categorical variables: average absolute SMD across dummy-coded categories{p_end}

{pstd}When {opt wt()} is specified, SMDs use weighted means, weighted standard
deviations, and weighted proportions for the first two {opt by()} groups.{p_end}

{pstd}Values |SMD| > {opt smdthreshold()} (default 0.1) are highlighted in orange in Excel and Markdown output.
Specify {cmd:smdthreshold(-1)} to disable this formatting. The 0.1 convention follows Austin (2009).{p_end}

{pstd}When {opt by()} has more than 2 groups, SMD is computed for the first two groups only.
A note is displayed identifying which groups are compared.{p_end}

{pstd}{bf:Auto-type detection:} Variables with more than 7 unique values are classified by the
shared helper using normality/distributional heuristics; large-N paths may use a fallback heuristic
instead of direct Shapiro-Wilk testing. Users should verify classifications for publishable tables.{p_end}

{pstd}{bf:Reserved by() variable names:} The internal reshape pipeline produces wide columns
named {cmd:N_<level>}, {cmd:m_<level>}, {cmd:_columna_<level>}, and {cmd:_columnb_<level>}.
A {opt by()} variable whose own name starts with {cmd:N_}, {cmd:m_}, or {cmd:_column*} would
alias those reshape outputs and silently corrupt the resulting table, so {cmd:table1_tc} rejects
such names with rc=498. Reserved exact names are {cmd:N}, {cmd:m}, {cmd:_}, {cmd:_c},
{cmd:_co}, {cmd:_col}, {cmd:_colu}, {cmd:_colum}, {cmd:_column}, {cmd:_columna}, {cmd:_columnb};
reserved prefixes are {cmd:N_} and {cmd:m_}. If you hit this error, rename the variable
(for example, {cmd:rename N_age age_n}) before calling {cmd:table1_tc}.{p_end}


{title:References}

{phang}Austin PC. Balance diagnostics for comparing the distribution of baseline covariates between treatment groups in propensity-score matched samples. Statistics in Medicine 2009; 28: 3083-3107.{p_end}
{phang}Kirkwood TBL. Geometric means and measures of dispersion. Biometrics 1979; 35: 908-909.{p_end}
{phang}table1_mc - Mark Chatfield, The University of Queensland, Australia.{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.5.2{p_end}

{title:Also see}

{psee}
{space 2}Help:  {helpb tabtools}, {helpb regtab}, {helpb effecttab},
{helpb stratetab}, {helpb comptab}
{p_end}

{hline}

{smcl}
{* *! version 1.0.2  12apr2026}{...}
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
{opt table1_tc} [{it:varlist}] {ifin} {weight}, {opt by(varname)} [{it:options}]

{pstd}When a {it:varlist} is provided without {opt vars()}, each variable's type is automatically
detected using the Shapiro-Wilk test. This is the simplest way to use {cmd:table1_tc}.{p_end}

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

{syntab:Contents of Cells}
{synopt:{cmdab:f:ormat(}{it:{help fmt:%fmt}}{cmd:)}}default display format for continuous variables{p_end}
{synopt:{cmdab:percf:ormat(}{it:{help fmt:%fmt}}{cmd:)}}default display format for percentages{p_end}
{synopt:{cmdab:nf:ormat(}{it:{help fmt:%fmt}}{cmd:)}}display format for n and N; default is %12.0fc{p_end}
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
{synopt:{opt xlsx("filename")}}save table to Excel file (.xlsx){p_end}
{synopt:{opt sheet("string")}}Excel sheet name; default is "Table 1"{p_end}
{synopt:{opt title("string")}}title for the Excel table{p_end}
{synopt:{cmdab:borders:tyle(}{it:string}{cmd:)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{cmdab:the:me(}{it:string}{cmd:)}}journal-style formatting preset: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{opt boldp(#)}}bold p-value cells below threshold{p_end}
{synopt:{cmdab:foot:note(}{it:string}{cmd:)}}add footnote row below table{p_end}
{synopt:{opt open}}open Excel file after export{p_end}
{synopt:{opt zebra}}alternating row shading{p_end}
{synopt:{cmdab:headers:hade}}apply shading to header rows{p_end}
{synopt:{cmdab:high:light(}{it:#}{cmd:)}}highlight rows where p < threshold{p_end}
{synopt:{cmdab:smdt:hreshold(}{it:#}{cmd:)}}SMD threshold for orange highlighting; default is 0.1{p_end}
{synopt:{cmdab:headerc:olor(}{it:string}{cmd:)}}custom header background color (R G B){p_end}
{synopt:{cmdab:zebrac:olor(}{it:string}{cmd:)}}custom zebra stripe color (R G B){p_end}
{synopt:{opt csv("filename")}}also export as CSV file{p_end}

{syntab:Frame & Pipeline}
{synopt:{cmdab:fra:me(}{it:name}{cmd:)}}store output in a named Stata frame{p_end}

{syntab:Other}
{synopt:{opt clear}}replace dataset in memory with the table{p_end}
{synopt:{opt dots}}show progress dots while processing variables{p_end}
{synopt:{cmdab:missings:ummary}}add missing data summary row per variable{p_end}
{synopt:{cmdab:noi:sily}}display detailed processing output{p_end}
{synopt:{cmdab:wtc:ompare}}show unweighted statistics alongside weighted (requires {opt wt()}){p_end}
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
{p 8 8 2}4. Variables with >7 unique values → Shapiro-Wilk normality test:{p_end}
{p 12 12 2}p ≥ 0.05 → {cmd:contn} (normal){p_end}
{p 12 12 2}p < 0.05 → {cmd:conts} (skewed){p_end}

{pstd}This command is a fork of {cmd:table1_mc} version 3.5 by Mark Chatfield, with enhancements
including Excel export, journal themes, auto-type detection, IPTW weighting, SMD, and a methods
paragraph generator.{p_end}

{pstd}{bf:Themes:} The {opt theme()} option applies journal-specific formatting:{p_end}
{p 8 8 2}{cmd:lancet} - Arial 9pt, academic borders, no header shading{p_end}
{p 8 8 2}{cmd:nejm} - Arial 10pt, thin borders, blue header shading{p_end}
{p 8 8 2}{cmd:bmj} - Arial 10pt, academic borders, no header shading{p_end}
{p 8 8 2}{cmd:apa} - Times New Roman 12pt, academic borders{p_end}

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
{phang2}{cmd:. table1_tc price mpg weight rep78 foreign, by(foreign)}{p_end}

{pstd}{bf:With Excel export and formatting:}{p_end}

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

{phang2}{cmd:. table1_tc age sex bmi, by(treated) frame(mytable)}{p_end}
{phang2}{cmd:. frame mytable: list}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:table1_tc} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(Dapa)}}data presentation description (e.g., "Data are presented as mean (SD) or No. (%)."){p_end}
{synopt:{cmd:r(methods)}}extended methods paragraph describing statistical tests used (when {opt by()} specified without {opt wt()}){p_end}
{synopt:{cmd:r(varlist)}}space-separated list of processed variables{p_end}
{synopt:{cmd:r(xlsx)}}path to exported Excel file (when {opt xlsx()} specified){p_end}
{synopt:{cmd:r(sheet)}}Excel sheet name (when {opt xlsx()} specified){p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(table)}}table contents matrix (when {opt xlsx()} specified){p_end}


{marker technical}{...}
{title:Technical notes}

{pstd}{bf:SMD methodology:} Standardized mean differences are computed as follows:{p_end}
{p 8 8 2}Continuous variables: Cohen's d with pooled standard deviation (Austin, 2009){p_end}
{p 8 8 2}Binary variables: difference in proportions / pooled SD of proportions{p_end}
{p 8 8 2}Categorical variables: average absolute SMD across dummy-coded categories{p_end}

{pstd}Values |SMD| > {opt smdthreshold()} (default 0.1) are highlighted in orange in Excel output,
following the convention that |SMD| > 0.1 indicates meaningful imbalance (Austin, 2009).{p_end}

{pstd}When {opt by()} has more than 2 groups, SMD is computed for the first two groups only.
A note is displayed identifying which groups are compared.{p_end}

{pstd}{bf:Auto-type detection:} Uses Shapiro-Wilk test (p=0.05 threshold) on a random sample
of up to 2,000 observations with a fixed seed for reproducibility. Users should verify
classifications for publishable tables.{p_end}


{title:References}

{phang}Austin PC. Balance diagnostics for comparing the distribution of baseline covariates between treatment groups in propensity-score matched samples. Statistics in Medicine 2009; 28: 3083-3107.{p_end}
{phang}Kirkwood TBL. Geometric means and measures of dispersion. Biometrics 1979; 35: 908-909.{p_end}
{phang}table1_mc - Mark Chatfield, The University of Queensland, Australia.{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.2{p_end}

{title:Also see}

{psee}
{space 2}Help:  {helpb tabtools}, {helpb regtab}, {helpb effecttab},
{helpb stratetab}, {helpb tablex}
{p_end}

{hline}

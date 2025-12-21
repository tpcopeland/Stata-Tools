{smcl}
{* *! version 1.0.0  21dec2025}{...}
{vieweralsosee "[R] summarize" "help summarize"}{...}
{vieweralsosee "[R] regress postestimation" "help regress postestimation"}{...}
{viewerjumpto "Syntax" "outlier##syntax"}{...}
{viewerjumpto "Description" "outlier##description"}{...}
{viewerjumpto "Options" "outlier##options"}{...}
{viewerjumpto "Remarks" "outlier##remarks"}{...}
{viewerjumpto "Examples" "outlier##examples"}{...}
{viewerjumpto "Stored results" "outlier##results"}{...}
{viewerjumpto "Author" "outlier##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:outlier} {hline 2}}Outlier detection toolkit with multiple methods{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:outlier}
{varlist}
{ifin}
[{cmd:,} {it:options}]


{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Detection Method}
{synopt:{opt met:hod(string)}}detection method: iqr, sd, mahal, or influence{p_end}
{synopt:{opt mult:iplier(#)}}IQR/SD multiplier; default is 1.5 for IQR, 3 for SD{p_end}
{synopt:{opt maha_p(#)}}Mahalanobis p-value threshold; default is 0.001{p_end}

{syntab:Action}
{synopt:{opt act:ion(string)}}action: flag, winsorize, or exclude{p_end}
{synopt:{opt gen:erate(name)}}prefix for generated variables{p_end}
{synopt:{opt replace}}allow replacing existing variables{p_end}

{syntab:Grouping}
{synopt:{opt by(varname)}}detect outliers within groups{p_end}

{syntab:Output}
{synopt:{opt rep:ort}}display detailed report{p_end}
{synopt:{opt xlsx(filename)}}export report to Excel{p_end}
{synopt:{opt sheet(name)}}Excel sheet name; default is "Outliers"{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:outlier} is a comprehensive outlier detection toolkit supporting multiple
methods. It can flag, winsorize, or exclude outliers, with detailed reporting
and Excel export capabilities.

{pstd}
Available detection methods:

{phang2}{bf:iqr} - Interquartile Range method (default). Outliers are values
below Q1 - k*IQR or above Q3 + k*IQR, where k is the multiplier (default 1.5).

{phang2}{bf:sd} - Standard Deviation method. Outliers are values more than
k standard deviations from the mean (default k=3).

{phang2}{bf:mahal} - Mahalanobis Distance for multivariate outlier detection.
Identifies observations with unusually extreme combinations of values.

{phang2}{bf:influence} - Regression influence diagnostics. Identifies
influential observations using Cook's D, leverage, and studentized residuals.


{marker options}{...}
{title:Options}

{dlgtab:Detection Method}

{phang}
{opt method(string)} specifies the outlier detection method. Options are:

{p 12 16 2}{bf:iqr} - Interquartile range method (default){p_end}
{p 12 16 2}{bf:sd} - Standard deviation method{p_end}
{p 12 16 2}{bf:mahal} - Mahalanobis distance (requires 2+ variables){p_end}
{p 12 16 2}{bf:influence} - Regression influence (requires 2+ variables){p_end}

{phang}
{opt multiplier(#)} specifies the multiplier for IQR or SD methods.
Default is 1.5 for IQR and 3 for SD. Common alternatives include 2.5 or 3
for IQR (more conservative) or 2 for SD (more liberal).

{phang}
{opt maha_p(#)} specifies the p-value threshold for Mahalanobis distance.
Observations with chi-square p-value below this threshold are flagged.
Default is 0.001.

{dlgtab:Action}

{phang}
{opt action(string)} specifies what to do with detected outliers:

{p 12 16 2}{bf:flag} - Create indicator variables marking outliers (default){p_end}
{p 12 16 2}{bf:winsorize} - Replace outliers with boundary values{p_end}
{p 12 16 2}{bf:exclude} - Set outliers to missing{p_end}

{phang}
{opt generate(name)} specifies the prefix for generated variables.
Required for winsorize and exclude actions. For flag action, creates
variables named {it:prefix}_{it:varname}.

{phang}
{opt replace} allows overwriting existing variables.

{dlgtab:Grouping}

{phang}
{opt by(varname)} calculates outlier bounds separately within each group.
Useful when outliers should be defined relative to group-specific distributions.

{dlgtab:Output}

{phang}
{opt report} displays a detailed report including variable summaries
and outlier counts.

{phang}
{opt xlsx(filename)} exports the outlier report to an Excel file.

{phang}
{opt sheet(name)} specifies the Excel sheet name. Default is "Outliers".


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Choosing a Method}

{pstd}
{bf:IQR method} is robust to outliers themselves and works well for
skewed distributions. Use k=1.5 (default) for mild outliers or k=3 for
extreme outliers.

{pstd}
{bf:SD method} assumes approximate normality. It's sensitive to the
presence of outliers. Use k=2.5 or k=3 (default).

{pstd}
{bf:Mahalanobis distance} detects multivariate outliers that may appear
normal in each variable individually but are unusual in combination.

{pstd}
{bf:Influence diagnostics} identify observations that disproportionately
affect regression results.

{pstd}
{bf:Winsorizing vs Excluding}

{pstd}
Winsorizing replaces extreme values with less extreme ones, preserving
sample size. Excluding sets outliers to missing, reducing sample size
but avoiding arbitrary value replacement.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic IQR detection}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. outlier price mpg weight}{p_end}

{pstd}
{bf:Example 2: SD-based with custom threshold}

{phang2}{cmd:. outlier price, method(sd) multiplier(2.5)}{p_end}

{pstd}
{bf:Example 3: Flag outliers and generate indicator}

{phang2}{cmd:. outlier price mpg, generate(out_) action(flag)}{p_end}

{pstd}
{bf:Example 4: Winsorize outliers}

{phang2}{cmd:. outlier price, action(winsorize) generate(w_)}{p_end}

{pstd}
{bf:Example 5: Multivariate Mahalanobis}

{phang2}{cmd:. outlier price mpg weight, method(mahal) generate(maha_)}{p_end}

{pstd}
{bf:Example 6: Regression influence}

{phang2}{cmd:. outlier price mpg weight headroom, method(influence) generate(infl_)}{p_end}

{pstd}
{bf:Example 7: Detection within groups}

{phang2}{cmd:. outlier price, by(foreign) report}{p_end}

{pstd}
{bf:Example 8: Export to Excel}

{phang2}{cmd:. outlier price mpg weight, xlsx(outliers.xlsx)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:outlier} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(n_outliers)}}total outliers detected{p_end}
{synopt:{cmd:r(pct_outliers)}}percentage of outliers (for mahal/influence){p_end}
{synopt:{cmd:r(multiplier)}}multiplier used (for iqr/sd){p_end}
{synopt:{cmd:r(lower)}}lower bound (for single variable iqr/sd){p_end}
{synopt:{cmd:r(upper)}}upper bound (for single variable iqr/sd){p_end}
{synopt:{cmd:r(maha_p)}}p-value threshold (for mahal){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(method)}}detection method used{p_end}
{synopt:{cmd:r(action)}}action taken{p_end}
{synopt:{cmd:r(varlist)}}variables analyzed{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(results)}}matrix of results by variable (for iqr/sd){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2025-12-21{p_end}


{title:Also see}

{psee}
Manual:  {manlink R summarize}

{psee}
Online:  {helpb winsor2}, {helpb hadimvo}

{hline}

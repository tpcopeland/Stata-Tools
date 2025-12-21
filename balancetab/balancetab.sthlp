{smcl}
{* *! version 1.0.0  21dec2025}{...}
{vieweralsosee "[TE] teffects" "help teffects"}{...}
{vieweralsosee "[R] psmatch2" "help psmatch2"}{...}
{viewerjumpto "Syntax" "balancetab##syntax"}{...}
{viewerjumpto "Description" "balancetab##description"}{...}
{viewerjumpto "Options" "balancetab##options"}{...}
{viewerjumpto "Remarks" "balancetab##remarks"}{...}
{viewerjumpto "Examples" "balancetab##examples"}{...}
{viewerjumpto "Stored results" "balancetab##results"}{...}
{viewerjumpto "Author" "balancetab##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:balancetab} {hline 2}}Propensity score balance diagnostics with standardized mean differences{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:balancetab}
{varlist}
{ifin}{cmd:,}
{opt treat:ment(varname)}
[{it:options}]


{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt treat:ment(varname)}}binary treatment indicator (0/1){p_end}

{syntab:Adjustment}
{synopt:{opt wvar(varname)}}weight variable (e.g., IPTW weights){p_end}
{synopt:{opt strata(varname)}}strata variable for stratified analysis{p_end}
{synopt:{opt match:ed}}indicates data has been matched{p_end}

{syntab:Thresholds}
{synopt:{opt thr:eshold(#)}}SMD threshold for imbalance; default is 0.1{p_end}

{syntab:Export}
{synopt:{opt xlsx(filename)}}export balance table to Excel file{p_end}
{synopt:{opt sheet(name)}}Excel sheet name; default is "Balance"{p_end}

{syntab:Visualization}
{synopt:{opt loveplot}}generate Love plot{p_end}
{synopt:{opt saving(filename)}}save Love plot to file{p_end}

{syntab:Display}
{synopt:{opt format(fmt)}}display format for SMD; default is %6.3f{p_end}
{synopt:{opt title(string)}}title for output and plot{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:balancetab} calculates and displays covariate balance diagnostics for
propensity score analysis. It computes standardized mean differences (SMD)
before and after matching or weighting, generates Love plots for visualization,
and exports balance tables to Excel.

{pstd}
The command is designed to work with various propensity score methods:

{phang2}{bf:IPTW (Inverse Probability of Treatment Weighting):} Specify
weights using the {opt wvar()} option.

{phang2}{bf:Matching:} Use the {opt matched} option with matched data.

{phang2}{bf:Unadjusted:} Omit both options to assess raw balance.

{pstd}
Balance is assessed using the standardized mean difference (SMD), calculated as:

{p 8 8 2}
SMD = (Mean_treated - Mean_control) / sqrt((Var_treated + Var_control) / 2)

{pstd}
Covariates with |SMD| > threshold (default 0.1) are flagged as imbalanced.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt treatment(varname)} specifies the binary treatment indicator variable.
Must be coded as 0 (control) and 1 (treated).

{dlgtab:Adjustment}

{phang}
{opt wvar(varname)} specifies the weight variable for weighted balance
assessment. Typically used with IPTW weights from propensity score estimation.
Weights must be non-negative.

{phang}
{opt strata(varname)} specifies a stratification variable for stratified
balance assessment.

{phang}
{opt matched} indicates that the data has already been matched (e.g., using
{help psmatch2} or {help teffects psmatch}). When specified, balance is
assessed on the matched sample.

{dlgtab:Thresholds}

{phang}
{opt threshold(#)} specifies the absolute SMD threshold for determining
imbalance. Covariates with |SMD| > threshold are flagged. Default is 0.1,
which is commonly used in the literature.

{dlgtab:Export}

{phang}
{opt xlsx(filename)} exports the balance table to an Excel file. The filename
must end with .xlsx.

{phang}
{opt sheet(name)} specifies the Excel sheet name. Default is "Balance".

{dlgtab:Visualization}

{phang}
{opt loveplot} generates a Love plot showing SMD for all covariates.
Vertical lines mark the threshold bounds. If adjustment was applied,
both raw and adjusted SMD are shown.

{phang}
{opt saving(filename)} saves the Love plot to the specified file. Supports
.png, .pdf, .eps, and other formats recognized by {help graph export}.

{dlgtab:Display}

{phang}
{opt format(fmt)} specifies the display format for SMD values.
Default is %6.3f.

{phang}
{opt title(string)} specifies a title for the output table and Love plot.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Interpreting SMD}

{pstd}
The standardized mean difference is a measure of effect size that quantifies
the difference between treatment and control groups in standard deviation
units. Common thresholds include:

{p2colset 8 20 22 2}{...}
{p2col:|SMD| < 0.1}Good balance{p_end}
{p2col:|SMD| 0.1-0.25}Acceptable balance{p_end}
{p2col:|SMD| > 0.25}Poor balance{p_end}

{pstd}
{bf:Use with effecttab}

{pstd}
{cmd:balancetab} pairs naturally with {help effecttab} in causal inference
workflows. A typical workflow is:

{phang2}1. Estimate propensity scores and IPTW weights

{phang2}2. Check balance using {cmd:balancetab}

{phang2}3. Estimate treatment effects using {help teffects}

{phang2}4. Export results using {help effecttab}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Unadjusted balance check}

{phang2}{cmd:. webuse cattaneo2, clear}{p_end}
{phang2}{cmd:. balancetab mage medu fage, treatment(mbsmoke)}{p_end}

{pstd}
{bf:Example 2: Balance after IPTW}

{pstd}
First, estimate propensity scores and create weights:

{phang2}{cmd:. logit mbsmoke mage medu fage}{p_end}
{phang2}{cmd:. predict ps, pr}{p_end}
{phang2}{cmd:. gen ipw = cond(mbsmoke==1, 1/ps, 1/(1-ps))}{p_end}

{pstd}
Then check balance:

{phang2}{cmd:. balancetab mage medu fage, treatment(mbsmoke) wvar(ipw)}{p_end}

{pstd}
{bf:Example 3: With Love plot and Excel export}

{phang2}{cmd:. balancetab mage medu fage, treatment(mbsmoke) wvar(ipw) ///}{p_end}
{phang2}{cmd:     xlsx(balance.xlsx) loveplot saving(loveplot.png)}{p_end}

{pstd}
{bf:Example 4: With matched data}

{phang2}{cmd:. teffects psmatch (bweight) (mbsmoke mage medu), atet}{p_end}
{phang2}{cmd:. balancetab mage medu, treatment(mbsmoke) matched}{p_end}

{pstd}
{bf:Example 5: Custom threshold}

{phang2}{cmd:. balancetab mage medu fage, treatment(mbsmoke) threshold(0.25)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:balancetab} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}total number of observations{p_end}
{synopt:{cmd:r(N_treated)}}number in treatment group{p_end}
{synopt:{cmd:r(N_control)}}number in control group{p_end}
{synopt:{cmd:r(max_smd_raw)}}maximum absolute SMD before adjustment{p_end}
{synopt:{cmd:r(max_smd_adj)}}maximum absolute SMD after adjustment{p_end}
{synopt:{cmd:r(n_imbalanced)}}number of covariates exceeding threshold{p_end}
{synopt:{cmd:r(threshold)}}threshold used{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(treatment)}}treatment variable name{p_end}
{synopt:{cmd:r(varlist)}}covariates assessed{p_end}
{synopt:{cmd:r(wvar)}}weight variable (if specified){p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(balance)}}matrix of balance statistics{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2025-12-21{p_end}


{title:Also see}

{psee}
Manual:  {manlink TE teffects}

{psee}
Online:  {helpb effecttab}, {helpb iptw_diag}, {helpb psmatch2}

{hline}

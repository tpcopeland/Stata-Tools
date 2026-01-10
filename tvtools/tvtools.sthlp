{smcl}
{* *! version 1.4.0  26dec2025}{...}
{viewerjumpto "Description" "tvtools##description"}{...}
{viewerjumpto "Commands" "tvtools##commands"}{...}
{viewerjumpto "Workflow" "tvtools##workflow"}{...}
{viewerjumpto "Installation" "tvtools##installation"}{...}
{viewerjumpto "Author" "tvtools##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tvtools} {hline 2}}A suite of commands for time-varying exposure analysis{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvtools} provides a comprehensive set of commands for constructing,
diagnosing, and analyzing time-varying exposure data in survival analysis.
The package supports the full workflow from data preparation through
estimation and reporting, with special support for target trial emulation
and causal inference methods.


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Data Preparation}

{synoptset 16}{...}
{synopt:{helpb tvexpose}}Create time-varying exposure variables for survival analysis{p_end}
{synopt:{helpb tvmerge}}Merge multiple time-varying exposure datasets{p_end}
{synopt:{helpb tvevent}}Integrate events and competing risks into time-varying datasets{p_end}
{synopt:{helpb tvcalendar}}Merge calendar-time external factors (policy periods, seasons){p_end}

{pstd}
{bf:Diagnostics and Visualization}

{synopt:{helpb tvdiagnose}}Diagnostic tools for time-varying exposure datasets{p_end}
{synopt:{helpb tvplot}}Visualization tools for time-varying exposure data{p_end}
{synopt:{helpb tvbalance}}Balance diagnostics for time-varying exposure data{p_end}

{pstd}
{bf:Weighting and Estimation}

{synopt:{helpb tvweight}}Calculate inverse probability of treatment weights (IPTW){p_end}
{synopt:{helpb tvestimate}}G-estimation for structural nested models{p_end}
{synopt:{helpb tvdml}}Double/Debiased Machine Learning for causal inference{p_end}

{pstd}
{bf:Special Applications}

{synopt:{helpb tvtrial}}Target trial emulation for observational data{p_end}
{synopt:{helpb tvsensitivity}}Sensitivity analysis for unmeasured confounding{p_end}
{synopt:{helpb tvpass}}Post-authorization study (PASS/PAES) workflow support{p_end}

{pstd}
{bf:Reporting}

{synopt:{helpb tvtable}}Publication-ready summary tables for time-varying analyses{p_end}
{synopt:{helpb tvreport}}Automated analysis report generation{p_end}

{pstd}
{bf:Workflow}

{synopt:{helpb tvpipeline}}Complete workflow for time-varying exposure analysis{p_end}


{marker workflow}{...}
{title:Typical Workflow}

{pstd}
A typical time-varying exposure analysis follows these steps:

{p 4 8 2}1. {bf:Create exposure data}: Use {helpb tvexpose} to transform exposure records into time-varying format{p_end}
{p 4 8 2}2. {bf:Merge exposures}: Use {helpb tvmerge} to combine multiple exposure sources{p_end}
{p 4 8 2}3. {bf:Add events}: Use {helpb tvevent} to integrate outcomes and competing risks{p_end}
{p 4 8 2}4. {bf:Diagnose}: Use {helpb tvdiagnose} and {helpb tvplot} to verify data structure{p_end}
{p 4 8 2}5. {bf:Check balance}: Use {helpb tvbalance} to assess covariate balance{p_end}
{p 4 8 2}6. {bf:Compute weights}: Use {helpb tvweight} for IPTW estimation{p_end}
{p 4 8 2}7. {bf:Estimate effects}: Use Cox regression or {helpb tvestimate}/{helpb tvdml}{p_end}
{p 4 8 2}8. {bf:Sensitivity}: Use {helpb tvsensitivity} to assess robustness{p_end}
{p 4 8 2}9. {bf:Report}: Use {helpb tvtable} and {helpb tvreport} for output{p_end}

{pstd}
For a streamlined approach, {helpb tvpipeline} can automate much of this workflow.


{marker installation}{...}
{title:Installation}

{pstd}
To install or update tvtools:

{phang2}{cmd:. net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
Email: timothy.copeland@ki.se
{p_end}

{smcl}
{* *! version 1.0.0  08apr2026}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{vieweralsosee "tvweight" "help tvweight"}{...}
{vieweralsosee "tvage" "help tvage"}{...}
{viewerjumpto "Description" "tvtools##description"}{...}
{viewerjumpto "Syntax" "tvtools##syntax"}{...}
{viewerjumpto "Commands" "tvtools##commands"}{...}
{viewerjumpto "Workflow" "tvtools##workflow"}{...}
{viewerjumpto "Examples" "tvtools##examples"}{...}
{viewerjumpto "Installation" "tvtools##installation"}{...}
{viewerjumpto "Author" "tvtools##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tvtools} {hline 2}}A suite of commands for time-varying exposure analysis{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvtools} provides a set of commands for constructing,
diagnosing, and analyzing time-varying exposure data in survival analysis.
The package supports the workflow from data preparation through
weighting and estimation.


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvtools} [{cmd:,} {opt list} {opt detail} {opt cat:egory(string)}]

{synoptset 22 tabbed}{...}
{synopt:{opt list}}display commands as a simple list{p_end}
{synopt:{opt detail}}show detailed information with descriptions{p_end}
{synopt:{opt cat:egory(string)}}filter by category: {cmd:prep}, {cmd:diag}, {cmd:weight}, {cmd:all}{p_end}


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Data Preparation}

{synoptset 16}{...}
{synopt:{helpb tvexpose}}Create time-varying exposure variables for survival analysis{p_end}
{synopt:{helpb tvmerge}}Merge multiple time-varying exposure datasets{p_end}
{synopt:{helpb tvevent}}Integrate events and competing risks into time-varying datasets{p_end}
{synopt:{helpb tvage}}Add time-varying age to stset data{p_end}

{pstd}
{bf:Diagnostics}

{synopt:{helpb tvdiagnose}}Diagnostic tools for time-varying exposure datasets{p_end}

{pstd}
{bf:Weighting}

{synopt:{helpb tvweight}}Calculate inverse probability of treatment weights (IPTW){p_end}


{marker workflow}{...}
{title:Typical Workflow}

{pstd}
A typical time-varying exposure analysis follows these steps:

{p 4 8 2}1. {bf:Create exposure data}: Use {helpb tvexpose} to transform exposure records into time-varying format{p_end}
{p 4 8 2}2. {bf:Merge exposures}: Use {helpb tvmerge} to combine multiple exposure sources{p_end}
{p 4 8 2}3. {bf:Add events}: Use {helpb tvevent} to integrate outcomes and competing risks{p_end}
{p 4 8 2}4. {bf:Diagnose}: Use {helpb tvdiagnose} to verify data structure{p_end}
{p 4 8 2}5. {bf:Compute weights}: Use {helpb tvweight} for IPTW estimation{p_end}
{p 4 8 2}6. {bf:Estimate effects}: Use Cox regression or other models with weighted data{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Create time-varying exposure from prescription data}

{phang2}{cmd:. tvexpose using rx_episodes.dta, id(id) start(rx_start) stop(rx_stop)} ///
{phang3}{cmd:exposure(drug) reference(0) entry(study_entry) exit(study_exit)}{p_end}

{pstd}
{bf:Merge two exposure variables}

{phang2}{cmd:. tvmerge drug_a.dta drug_b.dta, id(id) start(start_a start_b) stop(stop_a stop_b) exposure(drug_a drug_b)}{p_end}

{pstd}
{bf:Add events and competing risks}

{phang2}{cmd:. tvevent using intervals.dta, id(id) date(event_date) compete(death_date)}{p_end}

{pstd}
{bf:Diagnose the constructed dataset}

{phang2}{cmd:. tvdiagnose, id(id) start(start) stop(stop) coverage gaps entry(study_entry) exit(study_exit)}{p_end}

{pstd}
{bf:Calculate IPTW weights}

{phang2}{cmd:. tvweight tv_exposure, covariates(age sex comorbidity)}{p_end}

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

{hline}

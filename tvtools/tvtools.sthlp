{smcl}
{* *! version 1.6.9  10jul2026}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{vieweralsosee "tvweight" "help tvweight"}{...}
{vieweralsosee "tvage" "help tvage"}{...}
{vieweralsosee "tvband" "help tvband"}{...}
{vieweralsosee "tvsplit" "help tvsplit"}{...}
{vieweralsosee "tvpanel" "help tvpanel"}{...}
{viewerjumpto "Description" "tvtools##description"}{...}
{viewerjumpto "Syntax" "tvtools##syntax"}{...}
{viewerjumpto "Commands" "tvtools##commands"}{...}
{viewerjumpto "Workflow" "tvtools##workflow"}{...}
{viewerjumpto "Examples" "tvtools##examples"}{...}
{viewerjumpto "Remarks" "tvtools##remarks"}{...}
{viewerjumpto "Stored results" "tvtools##results"}{...}
{viewerjumpto "Installation" "tvtools##installation"}{...}
{viewerjumpto "Author" "tvtools##author"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tvtools} {hline 2}}A suite of commands for time-varying exposure analysis{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvtools} provides a set of commands for constructing, diagnosing, and analyzing
time-varying exposure data in survival analysis. The package supports the
workflow from data preparation through weighting and estimation.


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:tvtools} [{cmd:,} {opt list} {opt detail} {opt cat:egory(string)}]

{synoptset 22 tabbed}{...}
{synopt:{opt list}}display commands as a simple list{p_end}
{synopt:{opt detail}}show detailed information with descriptions{p_end}
{synopt:{opt cat:egory(string)}}filter by category: {cmd:prep}, {cmd:diag}, {cmd:weight}, {cmd:all}{p_end}

{marker options}{...}
{title:Options}

{phang}
{opt list} displays only the selected command names.

{phang}
{opt detail} displays command descriptions.

{phang}
{opt category(string)} filters the index to {cmd:prep}, {cmd:diag},
{cmd:weight}, or {cmd:all} (the default).


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Data Preparation}

{synoptset 16}{...}
{synopt:{helpb tvexpose}}Create time-varying exposure variables for survival analysis{p_end}
{synopt:{helpb tvmerge}}Merge multiple time-varying exposure datasets{p_end}
{synopt:{helpb tvevent}}Integrate events and competing risks into time-varying datasets{p_end}
{synopt:{helpb tvage}}Add time-varying age to stset data{p_end}
{synopt:{helpb tvband}}Split intervals along one date-derived axis{p_end}
{synopt:{helpb tvsplit}}Multi-timescale (Lexis) splitting on several axes at once{p_end}
{synopt:{helpb tvpanel}}Build a fixed-width, entry-anchored person-period panel for MSMs{p_end}

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

{p 4 8 2}1. {bf:Create exposure data}: Use {helpb tvexpose} to transform exposure records into
time-varying format{p_end}
{p 4 8 2}2. {bf:Merge exposures}: Use {helpb tvmerge} to combine multiple exposure sources{p_end}
{p 4 8 2}3. {bf:Add events}: Use {helpb tvevent} to integrate outcomes and competing risks{p_end}
{p 4 8 2}4. {bf:Diagnose}: Use {helpb tvdiagnose} to verify data structure{p_end}
{p 4 8 2}5. {bf:Compute weights}: Use {helpb tvweight} for IPTW estimation{p_end}
{p 4 8 2}6. {bf:Estimate effects}: Use Cox regression or other models with weighted data{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Create time-varying exposure from prescription data}

{phang2}{cmd:. tvexpose using rx_episodes.dta, id(id) start(rx_start) stop(rx_stop)} ///{p_end}
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

{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to use tvtools}

{pstd}
Use {cmd:tvtools} whenever you have exposure data recorded as episodes or
prescriptions and need to build a person-period dataset for time-to-event
analysis. The package handles the mechanics of aligning exposure windows
with follow-up intervals, splitting at event dates, and diagnosing common
data quality problems.

{pstd}
{bf:Data assumptions}

{pstd}
All date variables must be Stata daily dates (integer days since
01jan1960). Datetime variables ({cmd:%tc}/{cmd:%tC}) are not supported and will be
rejected with a clear error message. Convert datetimes first with
{cmd:gen daily = dofc(datetime_var)}.

{pstd}
Intervals use a closed [start, stop] convention where both endpoints are
inclusive. A period [2020-01-01, 2020-01-31] covers 31 days.

{pstd}
{bf:Choosing exposure definitions}

{pstd}
{helpb tvexpose} supports several exposure definitions for different
research questions:

{p 8 12 2}{cmd:[default]} — Categorical time-varying exposure (e.g., which drug a patient is
currently on){p_end}
{p 8 12 2}{cmd:evertreated} — Binary ever/never, for immortal-time-bias correction{p_end}
{p 8 12 2}{cmd:currentformer} — Three-level never/current/former{p_end}
{p 8 12 2}{cmd:duration()} — Cumulative duration categories{p_end}
{p 8 12 2}{cmd:continuousunit()} — Continuous cumulative exposure{p_end}
{p 8 12 2}{cmd:recency()} — Time since last exposure{p_end}
{p 8 12 2}{cmd:dose} — Cumulative dose with proportional overlap allocation{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvtools} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of commands listed{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(commands)}}space-separated list of command names{p_end}
{synopt:{cmd:r(version)}}package version string{p_end}
{synopt:{cmd:r(categories)}}available categories (prep diag weight){p_end}


{marker installation}{...}
{title:Installation}

{pstd}
To install or update tvtools:

{phang2}{cmd:. capture ado uninstall tvtools}{p_end}
{phang2}{cmd:. net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools") replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}
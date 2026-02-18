{smcl}
{* *! version 1.0.1  18feb2026}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{vieweralsosee "tvbalance" "help tvbalance"}{...}
{vieweralsosee "tvplot" "help tvplot"}{...}
{viewerjumpto "Syntax" "tvpipeline##syntax"}{...}
{viewerjumpto "Description" "tvpipeline##description"}{...}
{viewerjumpto "Options" "tvpipeline##options"}{...}
{viewerjumpto "Examples" "tvpipeline##examples"}{...}
{viewerjumpto "Stored results" "tvpipeline##results"}{...}
{viewerjumpto "Workflow" "tvpipeline##workflow"}{...}
{viewerjumpto "Author" "tvpipeline##author"}{...}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:tvpipeline} {hline 2}}Complete workflow for time-varying exposure analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvpipeline}
{cmd:using} {it:exposure_data}
{cmd:,} {opt id(varname)} {opt start(varname)} {opt stop(varname)}
{opt exp:osure(varname)} {opt ent:ry(varname)} {opt exit(varname)}
[{it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required - Exposure data}
{synopt:{opt using} {it:filename}}exposure data file{p_end}
{synopt:{opt id(varname)}}person identifier (in both datasets){p_end}
{synopt:{opt start(varname)}}exposure start date (in exposure data){p_end}
{synopt:{opt stop(varname)}}exposure stop date (in exposure data){p_end}
{synopt:{opt exp:osure(varname)}}exposure variable (in exposure data){p_end}

{syntab:Required - Cohort data (current dataset)}
{synopt:{opt ent:ry(varname)}}follow-up entry date{p_end}
{synopt:{opt exit(varname)}}follow-up exit date{p_end}

{syntab:Exposure Options}
{synopt:{opt ref:erence(#)}}reference level for exposure; default is 0{p_end}

{syntab:Event Options}
{synopt:{opt event(varname)}}event date variable (runs tvevent){p_end}
{synopt:{opt com:pete(varname)}}competing event date variable{p_end}

{syntab:Diagnostic Options}
{synopt:{opt diag:nose}}run tvdiagnose after creation{p_end}
{synopt:{opt bal:ance(varlist)}}run tvbalance on specified covariates{p_end}
{synopt:{opt plot}}generate exposure swimlane plot{p_end}

{syntab:Output Options}
{synopt:{opt save:as(filename)}}save final dataset{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvpipeline} provides a complete workflow for creating time-varying exposure
datasets ready for survival analysis. It chains together multiple tvtools commands
in a single call:

{phang2}
1. {cmd:tvexpose} - Creates time-varying exposure dataset

{phang2}
2. {cmd:tvevent} - Adds event indicators (if event specified)

{phang2}
3. {cmd:tvdiagnose} - Runs diagnostics (if requested)

{phang2}
4. {cmd:tvbalance} - Checks covariate balance (if requested)

{phang2}
5. {cmd:tvplot} - Generates visualization (if requested)

{phang2}
6. Save - Saves analysis-ready dataset (if requested)

{pstd}
This workflow automates the typical process of preparing observational data
for time-varying exposure analysis, reducing the potential for errors and
ensuring consistent data processing.


{marker options}{...}
{title:Options}

{dlgtab:Required - Exposure data}

{phang}
{opt using} {it:filename} specifies the dataset containing exposure records.
This file should have one row per exposure episode with start/stop dates.

{phang}
{opt id(varname)} specifies the person identifier variable. This variable
must exist in both the current (cohort) dataset and the exposure data file.

{phang}
{opt start(varname)} specifies the variable in the exposure data containing
the start date of each exposure episode.

{phang}
{opt stop(varname)} specifies the variable in the exposure data containing
the stop date of each exposure episode.

{phang}
{opt exposure(varname)} specifies the variable in the exposure data containing
the exposure category or treatment indicator.

{dlgtab:Required - Cohort data}

{phang}
{opt entry(varname)} specifies the variable containing each person's study
entry date (start of follow-up).

{phang}
{opt exit(varname)} specifies the variable containing each person's study
exit date (end of follow-up).

{dlgtab:Exposure Options}

{phang}
{opt reference(#)} specifies the reference (unexposed) level for the exposure
variable. The default is 0. Periods not covered by any exposure record will
be assigned this reference value.

{dlgtab:Event Options}

{phang}
{opt event(varname)} specifies the variable containing the outcome event date.
When specified, {cmd:tvevent} is run to add event indicators to the dataset.
The variable {cmd:_event} is created with value 1 in intervals containing
the event.

{phang}
{opt compete(varname)} specifies the variable containing a competing event
date (e.g., death). Requires {opt event()} to also be specified. The variable
{cmd:_compete} is created.

{dlgtab:Diagnostic Options}

{phang}
{opt diagnose} requests that {cmd:tvdiagnose} be run after creating the
time-varying dataset. This provides coverage diagnostics, gap analysis,
and overlap detection.

{phang}
{opt balance(varlist)} specifies covariates for which to assess balance
between exposure groups using {cmd:tvbalance}. Standardized mean differences
are calculated and displayed.

{phang}
{opt plot} requests that {cmd:tvplot} generate a swimlane plot showing
exposure patterns for the first 20 individuals.

{dlgtab:Output Options}

{phang}
{opt saveas(filename)} specifies a filename to save the final analysis-ready
dataset. If not specified, the dataset remains in memory but is not saved.

{phang}
{opt replace} allows overwriting of an existing file when using {opt saveas()}.


{marker examples}{...}
{title:Examples}

{pstd}Setup: Load cohort data{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}

{pstd}Basic pipeline - create time-varying exposure dataset{p_end}
{phang2}{cmd:. tvpipeline using medications, id(id) start(rx_start) stop(rx_stop) exposure(drug) entry(study_entry) exit(study_exit)}{p_end}

{pstd}Add events to the pipeline{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvpipeline using medications, id(id) start(rx_start) stop(rx_stop) exposure(drug) entry(study_entry) exit(study_exit) event(outcome_date)}{p_end}

{pstd}Complete pipeline with all diagnostics and output{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvpipeline using medications, id(id) start(rx_start) stop(rx_stop) exposure(drug) reference(0) entry(study_entry) exit(study_exit) event(outcome_date) compete(death_date) diagnose balance(age sex comorbidity) plot saveas(analysis.dta) replace}{p_end}

{pstd}After running tvpipeline, analyze with Cox regression{p_end}
{phang2}{cmd:. stset stop, failure(_event) enter(start) id(id)}{p_end}
{phang2}{cmd:. stcox i.tv_exposure age sex}{p_end}


{marker workflow}{...}
{title:Workflow}

{pstd}
{cmd:tvpipeline} executes the following steps:

{p2colset 5 10 12 2}
{p2col:Step}Description{p_end}
{p2line}
{p2col:1}{cmd:tvexpose} - Creates split time intervals with time-varying exposure status{p_end}
{p2col:2}{cmd:tvevent} - Adds event indicators (if {opt event()} specified){p_end}
{p2col:3}{cmd:tvdiagnose} - Reports coverage, gaps, overlaps (if {opt diagnose} specified){p_end}
{p2col:4}{cmd:tvbalance} - Calculates SMD for confounders (if {opt balance()} specified){p_end}
{p2col:5}{cmd:tvplot} - Generates swimlane visualization (if {opt plot} specified){p_end}
{p2col:6}Save - Writes analysis-ready dataset (if {opt saveas()} specified){p_end}
{p2line}

{pstd}
The output dataset contains:

{p 8 12 2}
{cmd:start} - Start of each time interval{p_end}
{p 8 12 2}
{cmd:stop} - End of each time interval{p_end}
{p 8 12 2}
{cmd:tv_exposure} - Time-varying exposure status{p_end}
{p 8 12 2}
{cmd:_event} - Event indicator (if event specified){p_end}
{p 8 12 2}
{cmd:_compete} - Competing event indicator (if compete specified){p_end}
{p 8 12 2}
Plus all variables from original cohort data{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvpipeline} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_cohort)}}number of observations in input cohort{p_end}
{synopt:{cmd:r(n_ids)}}number of unique IDs in input cohort{p_end}
{synopt:{cmd:r(n_output)}}number of observations in output dataset{p_end}
{synopt:{cmd:r(n_ids_output)}}number of unique IDs in output dataset{p_end}
{synopt:{cmd:r(n_events)}}number of events (if event specified){p_end}
{synopt:{cmd:r(n_compete)}}number of competing events (if compete specified){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(id)}}ID variable name{p_end}
{synopt:{cmd:r(entry)}}entry variable name{p_end}
{synopt:{cmd:r(exit)}}exit variable name{p_end}
{synopt:{cmd:r(exposure)}}exposure variable name{p_end}
{synopt:{cmd:r(reference)}}reference level{p_end}
{synopt:{cmd:r(expfile)}}exposure data filename{p_end}
{synopt:{cmd:r(event)}}event variable name (if specified){p_end}
{synopt:{cmd:r(compete)}}competing event variable name (if specified){p_end}
{synopt:{cmd:r(saveas)}}output filename (if specified){p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}
Timothy Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}


{marker alsosee}{...}
{title:Also see}

{psee}
{help tvexpose}, {help tvevent}, {help tvmerge}, {help tvdiagnose},
{help tvbalance}, {help tvplot}, {help tvweight}
{p_end}

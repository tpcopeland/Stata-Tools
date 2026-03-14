{smcl}
{* *! version 1.1.0  18feb2026}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{vieweralsosee "[D] cross" "help cross"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{viewerjumpto "Syntax" "tvcalendar##syntax"}{...}
{viewerjumpto "Description" "tvcalendar##description"}{...}
{viewerjumpto "Options" "tvcalendar##options"}{...}
{viewerjumpto "Remarks" "tvcalendar##remarks"}{...}
{viewerjumpto "Examples" "tvcalendar##examples"}{...}
{viewerjumpto "Stored results" "tvcalendar##results"}{...}
{viewerjumpto "Author" "tvcalendar##author"}{...}

{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:tvcalendar} {hline 2}}Merge calendar-time external factors into time-varying data{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 20 2}
{cmd:tvcalendar}
{cmd:using} {it:filename}{cmd:,}
{opt date:var(varname)}
[{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt date:var(varname)}}date variable in master data for matching{p_end}

{syntab:Optional}
{synopt:{opt merge(varlist)}}variables to merge from external dataset{p_end}
{synopt:{opt start:var(name)}}period start variable in external data{p_end}
{synopt:{opt stop:var(name)}}period stop variable in external data{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvcalendar} merges calendar-time external factors (policy periods, seasonal
effects, environmental exposures, regulatory changes) into person-time data
based on date matching. It is designed to enrich time-varying exposure datasets
created by {helpb tvexpose} or {helpb tvmerge} with contextual information
that varies over calendar time rather than person time.

{pstd}
The command supports two merge strategies:

{phang2}
{bf:Point-in-time merge} (default): Performs a many-to-one merge on
{opt datevar()}, matching each master observation to the external record
with the same date. This is appropriate when the external dataset has one
row per date (e.g., daily pollution levels, market indices).

{phang2}
{bf:Range-based merge} (with {opt startvar()} and {opt stopvar()}): Matches
each master observation to the external period whose date range contains the
master date. This is appropriate when the external dataset defines periods
(e.g., policy windows, seasonal quarters, regulatory regimes).

{pstd}
For range-based merges, if a master observation falls within multiple
overlapping external periods, the earliest period is kept.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt datevar(varname)} specifies the date variable in the master data used for
matching. This must be a Stata date variable (numeric with {cmd:%td} or similar
format). For time-varying exposure data, this is typically the period start
date (e.g., {cmd:start}).

{dlgtab:Optional}

{phang}
{opt merge(varlist)} specifies the variables to merge from the external
dataset. If not specified, all numeric variables from the external dataset are
merged. Use this option to select specific variables and avoid unintended
additions.

{phang}
{opt startvar(name)} specifies the variable name in the external dataset that
contains the start date of each period. Must be used together with
{opt stopvar()}. When specified, a range-based merge is performed: master
observations are matched to the external period where {opt datevar()} falls
within [{opt startvar()}, {opt stopvar()}].

{phang}
{opt stopvar(name)} specifies the variable name in the external dataset that
contains the end date of each period. Must be used together with
{opt startvar()}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Preparing the external dataset}

{pstd}
For a point-in-time merge, the external dataset must contain a date variable
with the same name as {opt datevar()} in the master data. Each date should
appear at most once in the external data.

{pstd}
For a range-based merge, the external dataset must contain the variables
named in {opt startvar()} and {opt stopvar()}, plus the variables to be
merged. Periods should ideally be non-overlapping; if they overlap, the
earliest matching period is kept.

{pstd}
{bf:Memory considerations}

{pstd}
Range-based merges create a temporary cross join of master observations
with external periods. If the product of master observations and external
periods exceeds 10 million rows, the command exits with an error. Products
between 1 and 10 million produce a warning note.

{pstd}
{bf:Unmatched observations}

{pstd}
Master observations that do not match any external record are retained with
missing values for the merged variables. The command reports the number of
matched and unmatched observations.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Point-in-time merge: daily pollution data}

{phang2}{cmd:. use person_time_data, clear}{p_end}
{phang2}{cmd:. tvcalendar using daily_pollution.dta, datevar(start)}{p_end}

{pstd}
{bf:Point-in-time merge: selecting specific variables}

{phang2}{cmd:. tvcalendar using weather.dta, datevar(start) merge(temperature humidity)}{p_end}

{pstd}
{bf:Range-based merge: policy periods}

{pstd}
Suppose {cmd:policy_periods.dta} contains:

        {hline 50}
        {cmd:policy_start}   {cmd:policy_end}   {cmd:policy_active}
        {hline 50}
        01jan2020       30jun2020      0
        01jul2020       31dec2020      1
        01jan2021       30jun2021      1
        {hline 50}

{phang2}{cmd:. tvcalendar using policy_periods.dta, datevar(start) startvar(policy_start) stopvar(policy_end)}{p_end}

{pstd}
{bf:Enriching tvexpose output with seasonal data}

{phang2}{cmd:. tvexpose using rx_episodes.dta, id(id) start(rx_start) stop(rx_stop) exposure(drug) reference(0) entry(study_entry) exit(study_exit)}{p_end}
{phang2}{cmd:. tvcalendar using seasons.dta, datevar(start) startvar(season_start) stopvar(season_end) merge(season quarter)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvcalendar} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_master)}}number of master observations before merge{p_end}
{synopt:{cmd:r(n_merged)}}number of observations after merge{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(datevar)}}name of date variable used for matching{p_end}
{synopt:{cmd:r(merge)}}names of merged variables{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
Email: timothy.copeland@ki.se


{title:Also see}

{psee}
{space 2}Help:  {help tvexpose}, {help tvmerge}, {help tvtools}
{p_end}

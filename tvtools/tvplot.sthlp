{smcl}
{* *! version 1.0.0  27dec2025}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{viewerjumpto "Syntax" "tvplot##syntax"}{...}
{viewerjumpto "Description" "tvplot##description"}{...}
{viewerjumpto "Options" "tvplot##options"}{...}
{viewerjumpto "Examples" "tvplot##examples"}{...}
{viewerjumpto "Stored results" "tvplot##results"}{...}
{viewerjumpto "Author" "tvplot##author"}{...}

{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:tvplot} {hline 2}}Visualization tools for time-varying exposure datasets{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvplot}
{cmd:,} {opt id(varname)} {opt start(varname)} {opt stop(varname)}
[{it:options}]


{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier variable{p_end}
{synopt:{opt start(varname)}}period start date variable{p_end}
{synopt:{opt stop(varname)}}period stop date variable{p_end}

{syntab:Plot type}
{synopt:{opt swim:lane}}individual exposure timelines (default){p_end}
{synopt:{opt per:sontime}}stacked bar chart of person-time by exposure{p_end}

{syntab:Options}
{synopt:{opt exp:osure(varname)}}exposure variable for color coding{p_end}
{synopt:{opt sam:ple(#)}}number of individuals to plot; default is 30{p_end}
{synopt:{opt sort:by(spec)}}sort order: {opt entry}, {opt exit}, {opt persontime}, or {it:varname}{p_end}
{synopt:{opt title(string)}}graph title{p_end}
{synopt:{opt sav:ing(filename)}}save graph to file{p_end}
{synopt:{opt replace}}replace existing file{p_end}
{synopt:{opt col:ors(colorlist)}}custom color palette{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvplot} creates visualizations of time-varying exposure data, helping
researchers understand exposure patterns, identify data quality issues, and
communicate results. It is designed to work with datasets created by
{help tvexpose} but can be used with any time-varying dataset.

{pstd}
Two plot types are available:

{phang2}
{opt swimlane} displays individual-level exposure timelines as horizontal
bars, with one row per person and color-coding by exposure category.
This is useful for visualizing the complexity of exposure patterns and
identifying unusual sequences.

{phang2}
{opt persontime} creates a bar chart showing total person-time by exposure
category, useful for understanding the distribution of follow-up across
exposure groups.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the variable that identifies individuals.

{phang}
{opt start(varname)} specifies the variable containing the start date
of each exposure period.

{phang}
{opt stop(varname)} specifies the variable containing the stop date
of each exposure period.

{dlgtab:Plot type}

{phang}
{opt swimlane} creates a swimlane plot showing individual exposure
timelines. Each person is represented by a horizontal lane, with
colored bars indicating exposure periods. This is the default plot type.

{phang}
{opt persontime} creates a bar chart showing total person-time (in
person-years) by exposure category. Requires the {opt exposure()} option.

{dlgtab:Options}

{phang}
{opt exposure(varname)} specifies the exposure variable used for color
coding in swimlane plots and grouping in person-time plots. If not
specified, all periods are shown in the same color.

{phang}
{opt sample(#)} specifies the number of individuals to include in the
swimlane plot. The default is 30. Large values may produce cluttered
plots; values up to 200 are supported.

{phang}
{opt sortby(spec)} specifies how individuals are sorted for selection
and display in swimlane plots. Options include:

{p 12 16 2}
{opt entry} - sort by earliest start date (default){break}
{opt exit} - sort by latest stop date{break}
{opt persontime} - sort by total person-time{break}
{it:varname} - sort by the specified variable

{phang}
{opt title(string)} specifies a custom title for the graph.

{phang}
{opt saving(filename)} saves the graph to the specified file. The file
extension determines the format (e.g., .png, .pdf, .eps).

{phang}
{opt replace} allows an existing file to be overwritten when using
{opt saving()}.

{phang}
{opt colors(colorlist)} specifies a custom color palette for exposure
categories. Colors should be specified as Stata color names separated
by spaces. The default palette is:
{cmd:gs10 navy maroon forest_green dkorange purple teal cranberry}.


{marker examples}{...}
{title:Examples}

{pstd}Setup: Create time-varying exposure dataset{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using medications, id(id) start(rx_start) stop(rx_stop) exposure(drug) reference(0) entry(study_entry) exit(study_exit)}{p_end}

{pstd}Basic swimlane plot with default settings{p_end}
{phang2}{cmd:. tvplot, id(id) start(start) stop(stop) exposure(tv_exposure)}{p_end}

{pstd}Plot 50 individuals sorted by total person-time{p_end}
{phang2}{cmd:. tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) sample(50) sortby(persontime)}{p_end}

{pstd}Person-time bar chart{p_end}
{phang2}{cmd:. tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) persontime}{p_end}

{pstd}Save plot with custom title{p_end}
{phang2}{cmd:. tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) title("Treatment Patterns") saving(patterns.png) replace}{p_end}

{pstd}Custom color palette{p_end}
{phang2}{cmd:. tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) colors(blue red green orange)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvplot} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(plottype)}}type of plot created ({opt swimlane} or {opt persontime}){p_end}
{synopt:{cmd:r(id)}}name of ID variable{p_end}
{synopt:{cmd:r(start)}}name of start date variable{p_end}
{synopt:{cmd:r(stop)}}name of stop date variable{p_end}
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
{help tvexpose}, {help tvdiagnose}, {help tvevent}, {help tvmerge}
{p_end}

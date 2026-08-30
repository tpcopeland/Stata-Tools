{smcl}
{vieweralsosee "pygrid" "help pygrid"}{...}
{viewerjumpto "Syntax" "pyattach##syntax"}{...}
{viewerjumpto "Description" "pyattach##description"}{...}
{viewerjumpto "Options" "pyattach##options"}{...}
{viewerjumpto "Examples" "pyattach##examples"}{...}
{viewerjumpto "Stored results" "pyattach##results"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:pyattach} {hline 2}}Attach zero-filled event measures to a pygrid denominator{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 18 2}
{cmd:pyattach}
{cmd:using} {it:filename}
{cmd:,}
{opt id(varname)}
{opt date(varname)}
[{it:options}]

{synoptset 34 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}identifier in the using event data{p_end}
{synopt:{opt date(varname)}}daily event date{p_end}

{syntab:Measures}
{synopt:{opt count(name)}}event-row count{p_end}
{synopt:{opt sum(varname [name])}}sum of a numeric event variable{p_end}
{synopt:{opt any(name)}}one-or-more-event indicator{p_end}
{synopt:{opt max(varname [name])}}maximum of a numeric event variable{p_end}
{synopt:{opt if(expression)}}using-data row filter{p_end}
{synopt:{opt rate(name)}}{cmd:count()}/person-time{p_end}

{syntab:Behavior}
{synopt:{opt nozerofill}}leave no-event rows missing{p_end}
{synopt:{opt orphans(policy)}}orphan-event policy{p_end}
{synopt:{opt noi:sily}}display a compact attachment report{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:pyattach} reads event rows from a using dataset, assigns each eligible
event to the nonoverlapping period built by {help pygrid}, aggregates requested
measures, and adds the resulting columns to the grid in memory. Repeated calls
accumulate columns without changing earlier measures or the denominator
characteristics.

{pstd}
Grid rows receiving no event are zero-filled by default. Eligible event rows
outside every observed period are orphans and produce an error by default. Rows
with a missing identifier or date, or rows excluded by {cmd:if()}, are not
eligible and are not counted as orphans.

{pstd}
The grid is recognized through dataset characteristics and a structural data
signature written by {cmd:pygrid}. Reordering rows or adding event-measure
columns is allowed. Editing stamped metadata or structural values, removing
required structural variables, or using a grid created before integrity stamps
were introduced invalidates the contract; run {cmd:pygrid} again before
attachment.

{pstd}
Multiple nonoverlapping source episodes may share the same {cmd:id()} and
period; {cmd:pyattach} resolves those rows by their exact interval bounds. Overlapping
intervals within an identifier invalidate the grid contract.


{marker options}{...}
{title:Options}

{phang}
{opt id(varname)} and {opt date(varname)} identify the event key and integer
daily date in the using file. The identifier may have a different name from the
grid identifier but must have the same string or numeric type. String identifiers
must be fixed-width; {cmd:strL} identifiers and datetime values formatted
{cmd:%tc} are rejected.

{phang}
{opt count(name)} creates the number of attached event rows in each grid row.

{phang}
{opt sum(varname [name])} sums a numeric event variable. If the output name is
omitted, the source name is used. Under default zero filling, no events or
all-missing values produce zero; under {cmd:nozerofill}, they produce missing.

{phang}
{opt any(name)} creates one when at least one eligible event attaches and zero otherwise.

{phang}
{opt max(varname [name])} computes a maximum. If the output name is omitted,
the source name is used. Default zero filling replaces missing maxima by zero.

{phang}
{opt if(expression)} is evaluated only in the using event data. It filters the numerator and never changes the denominator grid.

{phang}
{opt rate(name)} divides {cmd:count()} by the person-time variable stamped by
{cmd:pygrid}. It requires {cmd:count()}. A row with zero person-time has a
missing rate.

{phang}
{opt nozerofill} leaves grid rows without events missing. It always displays a warning naming the affected output variables.

{phang}
{opt orphans(policy)} controls eligible events that match no observed grid
interval. {cmd:error} exits with {cmd:r(459)} and leaves the grid unchanged. {cmd:report}
continues and displays the total and the subset whose identifiers
are absent from the grid. {cmd:save(filename)} continues and writes the original
orphan rows to a new dataset.

{phang}
{opt noisily} displays eligible and attached rows, orphans, zero-event grid rows, and the overall event rate.


{marker examples}{...}
{title:Examples}

{pstd}
Build a grid, attach counts and costs, and retain the full denominator:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id str9 start str9 stop}{p_end}
{phang2}{cmd:. 1 "01jan2010" "31dec2010"}{p_end}
{phang2}{cmd:. 2 "01jan2010" "31dec2010"}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. generate double window_start = daily(start,"DMY")}{p_end}
{phang2}{cmd:. generate double window_end = daily(stop,"DMY")}{p_end}
{phang2}{cmd:. pygrid, id(id) start(window_start) end(window_end) axis(calendar)}{p_end}
{phang2}{cmd:. tempfile events}{p_end}
{phang2}{cmd:. preserve}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id str9 visit double cost}{p_end}
{phang2}{cmd:. 1 "01jan2010" 100}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. generate double visit_date = daily(visit,"DMY")}{p_end}
{phang2}{cmd:. save `events'}{p_end}
{phang2}{cmd:. restore}{p_end}
{phang2}{cmd:. pyattach using `events', id(id) date(visit_date)}
{cmd:count(visits) sum(cost total_cost) rate(visit_rate) orphans(report)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:pyattach} stores the following in {cmd:r()}:

{synoptset 27 tabbed}{...}
{p2col 5 27 31 2: Scalars}{p_end}
{synopt:{cmd:r(N_using)}}rows read from the using file{p_end}
{synopt:{cmd:r(N_eligible)}}rows passing {cmd:if()} with usable key and date{p_end}
{synopt:{cmd:r(N_attached)}}eligible rows assigned to a grid period{p_end}
{synopt:{cmd:r(N_orphan)}}eligible rows assigned to no observed period{p_end}
{synopt:{cmd:r(N_orphan_nokey)}}orphans whose identifiers are absent{p_end}
{synopt:{cmd:r(N_zerofilled)}}grid rows with no attached event{p_end}
{synopt:{cmd:r(events)}}total attached event rows{p_end}
{synopt:{cmd:r(rate_overall)}}{cmd:r(events)}/total grid person-time{p_end}


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Help: {helpb pygrid}, {helpb tvband}, {helpb tvsplit}

{hline}

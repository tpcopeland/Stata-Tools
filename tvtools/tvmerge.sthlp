{smcl}
{vieweralsosee "[D] merge" "help merge"}{...}
{viewerjumpto "Syntax" "tvmerge##syntax"}{...}
{viewerjumpto "Description" "tvmerge##description"}{...}
{viewerjumpto "Options" "tvmerge##options"}{...}
{viewerjumpto "Remarks" "tvmerge##remarks"}{...}
{viewerjumpto "Examples" "tvmerge##examples"}{...}
{viewerjumpto "Stored results" "tvmerge##results"}{...}
{viewerjumpto "Author" "tvmerge##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:tvmerge} {hline 2}}Merge multiple time-varying exposure datasets{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:tvmerge} [{it:dataset1} {it:dataset2} ...]{cmd:,}
{opt id(varname)}
{opt start(namelist)}
{opt stop(namelist)}
{opt exposure(namelist)}
[{it:options}]

{pstd}
Datasets may be given as file paths (the positional list) {it:or} as named
frames via {opt frames()} (see below); supply one or the other, not both.


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier variable present in all datasets{p_end}
{synopt:{opt start(namelist)}}start date variables (one per dataset, in order){p_end}
{synopt:{opt stop(namelist)}}stop date variables (one per dataset, in order){p_end}
{synopt:{opt exposure(namelist)}}exposure variables (one per dataset, in order){p_end}

{syntab:Input}
{synopt:{opt fr:ames(namelist)}}read inputs from named frames instead of files{p_end}

{syntab:Exposure types}
{synopt:{opt ra:te(namelist)}}rates; unchanged when intervals split{p_end}
{synopt:{opt tot:al(namelist)}}interval totals; apportioned by inclusive days{p_end}
{synopt:{opt cum:ulative(namelist)}}row-start cumulative histories; carried unchanged{p_end}
{synopt:{opt con:tinuous(namelist)}}deprecated alias for {cmd:total()}{p_end}

{syntab:Output naming}
{synopt:{opt gen:erate(namelist)}}new names for exposure variables (one per dataset){p_end}
{synopt:{opt pre:fix(string)}}prefix for all exposure variable names{p_end}
{synopt:{opt startname(string)}}name for output start date variable (default: start){p_end}
{synopt:{opt stopname(string)}}name for output stop date variable (default: stop){p_end}
{synopt:{opt dateformat(fmt)}}output date format{p_end}

{syntab:Data management}
{synopt:{opt saveas(filename)}}save merged dataset to file{p_end}
{synopt:{opt frameo:ut(name)}}place result in a frame; leave current data intact{p_end}
{synopt:{opt replace}}overwrite existing file or frame{p_end}
{synopt:{opt keep(varlist)}}additional source variables to retain{p_end}
{synopt:{opt dropi:nvalid}}explicitly remove malformed required rows{p_end}

{syntab:Diagnostics and validation}
{synopt:{opt check}}display coverage diagnostics{p_end}
{synopt:{opt validatecoverage}}check for person-time gaps{p_end}
{synopt:{opt validateoverlap}}verify overlapping periods make sense{p_end}
{synopt:{opt sum:marize}}display summary statistics of start/stop dates{p_end}
{synopt:{opt flow}}report persons/records in vs out and return {cmd:r(flow)}{p_end}
{synopt:{opt verbose}}show validation IDs and dates{p_end}

{syntab:ID matching}
{synopt:{opt force}}allow nonmatching IDs{p_end}

{syntab:Performance}
{synopt:{opt batch(#)}}deprecated; ignored{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvmerge} merges multiple time-varying exposure datasets created by {helpb tvexpose}. The
command is designed to work specifically with the output from {cmd:tvexpose},
combining multiple exposure variables into a single dataset with synchronized
time periods.

{pstd}
{bf:CRITICAL PREREQUISITE}: {cmd:tvmerge} requires that each input dataset has
already been processed by {cmd:tvexpose}. You cannot use {cmd:tvmerge} directly
on raw exposure files. The typical workflow is:

{phang2}
1. Load cohort data and run {cmd:tvexpose} on first exposure dataset, save result

{phang2}
2. Load cohort data and run {cmd:tvexpose} on second exposure dataset, save result

{phang2}
3. Run {cmd:tvmerge} on the saved {cmd:tvexpose} outputs

{pstd}
Unlike standard Stata {cmd:merge}, {cmd:tvmerge} performs time-interval matching rather
than simple key-based matching. It identifies temporal overlaps between the
{cmd:tvexpose} outputs and creates new time intervals representing the intersections
of exposure periods. The command creates all possible overlapping combinations
between datasets (cartesian product).

{pstd}
{bf:Exposure types}: {cmd:tvmerge} distinguishes categorical exposures and
three continuous-quantity algebras:

{phang}
{bf:Categorical exposures} (default): Creates cartesian product of all exposure
combinations. Each unique combination of exposure values across datasets becomes
a separate period.

{phang}
{bf:Rates}: amounts per day, unchanged when rows are split.

{phang}
{bf:Interval totals}: amounts attributable to one closed source row, apportioned
by inclusive overlap days so the pieces sum to the source total.

{phang}
{bf:Cumulative histories}: amounts known at row start, carried unchanged when
that row is split. See {help tvtools##contracts:data contracts}.

{pstd}
{bf:Important}: By default, {cmd:tvmerge} replaces the dataset currently in
memory with the merged result. {opt frameout()} instead places the result in a
named frame and leaves current data intact. {opt saveas()} additionally writes
the result to disk.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier variable that must exist in all
datasets with identical names. This variable links records across datasets. It
may be numeric or {cmd:str#}; {cmd:strL} identifiers are not allowed (recast to {cmd:str#}
first).

{phang}
{opt start(namelist)} specifies the start date variables for all datasets,
listed in the same order as the datasets in the command line.

{phang}
{opt stop(namelist)} specifies the stop date variables for all datasets, listed
in the same order as the datasets in the command line.

{phang}
{opt exposure(namelist)} specifies the exposure variables for all datasets,
listed in the same order as the datasets in the command line.

{pstd}
Within each positional source, the variables assigned to {opt id()},
{opt start()}, {opt stop()}, and its positional {opt exposure()} must be
distinct. Role conflicts are rejected before any source file is opened.


{dlgtab:Input}

{phang}
{opt frames(namelist)} reads the input datasets from named {help frame:frames} held in memory
instead of from files on disk, in the order listed. This removes the save/use
round-trip when each {cmd:tvexpose} output is already a frame. Supply either the
positional file list or {opt frames()}, not both. All other options ({opt start()},
{opt stop()}, {opt exposure()}, etc.) apply per input exactly as with file paths.


{dlgtab:Exposure types}

{phang}
{opt rate(namelist)} specifies rates. Values remain invariant under interval
slicing. Specify exposure variable names or positions (1, 2, 3, etc.).

{phang}
{opt total(namelist)} specifies interval totals. A total is multiplied by the
ratio of inclusive output days to inclusive source-row days whenever a merge
boundary splits its source row. Because overlapping rows can allocate the same
source total more than once, {cmd:tvmerge} rejects any input overlap when
{opt total()} (or its legacy alias) is declared; resolve source overlaps first.

{phang}
{opt cumulative(namelist)} specifies cumulative histories measured at row
start; values are carried unchanged when a merge boundary splits
the row. When a source variable carries {cmd:[tvtools_quantity]}, the matching
algebra option is required; omission, disagreement, or an unknown metadata
value is
rejected. Every cumulative source variable must also carry
{cmd:char varname[tvtools_history_point] "start"}; missing or different
history metadata is rejected.

{phang}
{opt continuous(namelist)} is a deprecated compatibility alias for
{opt total()}. It retains the released proportional-allocation behavior and
prints a migration warning. A variable may appear in only one algebra list.


{dlgtab:Output naming}

{phang}
{opt generate(namelist)} specifies new names for exposure variables in the output
dataset. Provide exactly one name per dataset, in the same order as the
datasets. This option is mutually exclusive with {opt prefix()}.

{pmore}
Names must be unique and cannot collide with {opt id()}, the output bounds, or
any retained {opt keep()} name after its {cmd:_ds#} suffix is applied. All
collisions are rejected before source data are loaded.

{pmore}
When {opt generate()} is {it:not} given and two or more inputs carry the same
exposure name, {cmd:tvmerge} automatically suffixes the colliding output names
by position (for example, {cmd:drug_1} and {cmd:drug_2}) and prints a note,
instead of erroring. To skip the rename entirely, give each {cmd:tvexpose} run
a distinct {opt generate()} name up front.

{phang}
{opt prefix(string)} adds a prefix to all exposure variable names in the output. For
example, exposures {cmd:drug_class} and {cmd:benzo} with {cmd:prefix(exp_)} become
{cmd:exp_drug_class} and {cmd:exp_benzo}. This option is mutually exclusive with
{opt generate()}.

{phang}
{opt startname(string)} specifies the name for the start date variable in the output
dataset. Default is "start".

{phang}
{opt stopname(string)} specifies the name for the stop date variable in the output
dataset. Default is "stop".

{phang}
{opt dateformat(fmt)} specifies the Stata date format to apply to the output start
and stop date variables. Default is %tdCCYY/NN/DD. Any valid Stata date format
may be used.


{dlgtab:Data management}

{phang}
{opt saveas(filename)} saves the merged dataset to the specified file. Include
the .dta extension. Use with {opt replace} to overwrite an existing file.

{phang}
{opt frameout(name)} places the merged result into a new frame named {it:name}
and leaves the data in the current frame unchanged, enabling a disk-free
pipeline ({cmd:tvexpose}{c -(} {cmd:tvmerge}{c -(} {cmd:tvevent}). Combine with
{cmd:frames()} to also read the inputs from frames. The frame name is returned
in {cmd:r(frameout)}. If the frame already exists, specify {cmd:replace}.

{phang}
{opt replace} allows {opt saveas()} to overwrite an existing file, or
{opt frameout()} to overwrite an existing frame.

{phang}
{opt keep(varlist)} specifies additional variables to keep from the source
datasets. These variables are included in the output dataset with _ds#
suffixes (where # is the dataset number) to distinguish variables from
different sources. For example, if you specify {cmd:keep(dose)}, the output will
contain dose_ds1, dose_ds2, and so on. The ID variable, start and stop date
variables, and exposure variables are always kept and do not receive
suffixes. Do not repeat any of those structural variables in
{opt keep()}. All derived {cmd:_ds#} names are validated before source data
are opened. Final duplicate removal compares the complete output row, including
every
retained payload; rows that differ in requested payload are preserved.

{phang}
{opt dropinvalid} explicitly removes source rows with a missing ID, missing or
fractional daily bound, reversed bounds, or missing required exposure. The
default is strict and returns error 498 without changing the caller's
data. After a successful {opt dropinvalid} run, exact aggregate and per-dataset counts
are stored in {cmd:r()}; strict runs exit before posting stored results.


{dlgtab:Diagnostics and validation}

{phang}
{opt check} displays coverage diagnostics including the number of persons,
average periods per person, maximum periods per person, and total merged
intervals.

{phang}
{opt validatecoverage} checks the running union of each person's intervals for
gaps. A start more than one day after the maximum prior stop is a gap. This
running-maximum rule remains correct for nested and crossing rows. The count is
returned in {cmd:r(n_gaps)}.

{phang}
{opt validateoverlap} evaluates every active prior interval within person and
flags each overlapping pair whose complete exposure vector is identical. It
therefore detects overlaps hidden behind nested rows. The pair count is returned
in {cmd:r(n_overlaps)}.

{phang}
{opt summarize} displays summary statistics (min, max, mean, percentiles) for the
start and stop date variables in the merged output dataset.

{phang}
{opt flow} reports an attrition table: the number of persons (union of distinct
ids across the inputs) and records entering versus leaving the merge, with the
difference. Persons can drop when {opt force} merges datasets with non-matching
ids. The table is returned in the matrix {cmd:r(flow)} (rows {cmd:persons} and
{cmd:records}; columns {cmd:in}, {cmd:out}, {cmd:dropped}) for STROBE/RECORD-PE
reporting. It is a pure side channel and does not change the output
dataset. The same matrix is returned automatically whenever {opt dropinvalid} or
{opt force} removes rows or IDs, even if {opt flow} was omitted.

{phang}
{opt verbose} displays individual IDs and dates when {cmd:validatecoverage}
or {cmd:validateoverlap} detect issues. Without {cmd:verbose}, only summary
counts are shown and a hint to use {cmd:verbose} is displayed.


{dlgtab:ID matching}

{phang}
{opt force} allows merging datasets where the set of IDs does not match exactly
across all datasets. By default, {cmd:tvmerge} errors if any IDs appear in some
datasets but not others, because {cmd:joinby} silently drops non-matching IDs. With
{opt force}, mismatched IDs are dropped with a warning showing which IDs were
affected and how many observations were removed. Only IDs present in ALL
datasets appear in the output. This is useful when merging exposure data that
covers a subset of a cohort.


{dlgtab:Performance}

{phang}
{opt batch(#)} is {bf:deprecated and ignored}. It is still accepted so that
existing scripts do not break, but it has no effect: the interval intersection
is now performed by a compiled Mata sweep that emits only the overlapping
interval pairs directly, so it never materializes the within-person Cartesian
product and no longer needs batched disk I/O. Passing {opt batch(#)} prints a
one-time note and is otherwise a no-op.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Understanding merge strategies}

{pstd}
The merge creates all possible combinations of overlapping periods (Cartesian
product). For example, if person 1 has two antidepressant periods that overlap
with three benzodiazepine periods, the merge will produce six output records
representing all combinations.

{pstd}
{bf:Time period validity}

{pstd}
All input datasets must have integer daily bounds with start <=
stop. Point-in-time observations (where start = stop) are valid; for example, lab
measurements or clinic visits that occur on a single day. Missing, fractional,
or reversed bounds cause error 498 by default. Specify {opt dropinvalid} to
remove those rows explicitly and receive exact attrition counts.


{pstd}
{bf:Missing values}

{pstd}
Missing IDs, bounds, or required exposure values cause error 498 by default and
leave the caller's data unchanged. Specify {opt dropinvalid} to remove malformed
rows explicitly; the command then returns aggregate and per-dataset counts and
the mandatory flow matrix.


{pstd}
{bf:Variable naming and suffixes}

{pstd}
When using {opt keep()}, additional variables from different source datasets receive
_ds# suffixes (where # is 1, 2, 3, etc., corresponding to the dataset
order). This prevents naming conflicts when the same variable name appears in
multiple datasets. The ID variable is not suffixed because it represents the
same entity across all datasets. The output start and stop date variables are
not suffixed because they represent the merged time intervals, not
source-specific values. Exposure variables are renamed according to
{opt generate()}, {opt prefix()}, or their original source names. Repeated
original names are automatically suffixed by input position.

{pstd}
{bf:Performance considerations}

{pstd}
Merging multiple datasets can produce large output, especially when individuals
have many overlapping exposure periods. The interval intersection runs in a
compiled Mata sweep that, within each person, emits only the overlapping
interval pairs through a binary search. It never builds the full within-person
Cartesian product before filtering, so it is substantially faster and lighter on
memory than the {help joinby} approach for registry-scale data. No tuning is
required; the older {opt batch(#)} option is deprecated and ignored.

{pstd}
Execution time varies from seconds for small datasets to under a minute for very
large datasets with complex exposure patterns. On very large merges (more than
100,000 master rows) a one-line matching-progress indicator is shown unless the
command is run quietly.


{marker examples}{...}
{title:Examples}

{pstd}
Build two small interval datasets entirely in temporary files:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(start_s stop_s) byte tv_drug}{p_end}
{phang3}{cmd:1 "01jan2020" "15jan2020" 0}{p_end}
{phang3}{cmd:1 "16jan2020" "31jan2020" 1}{p_end}
{phang3}{cmd:2 "01jan2020" "31jan2020" 2}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double rx_start = date(start_s, "DMY")}{p_end}
{phang2}{cmd:. generate double rx_stop = date(stop_s, "DMY")}{p_end}
{phang2}{cmd:. format rx_start rx_stop %td}{p_end}
{phang2}{cmd:. drop start_s stop_s}{p_end}
{phang2}{cmd:. tempfile drug benzo merged}{p_end}
{phang2}{cmd:. save `drug'}{p_end}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(start_s stop_s) byte tv_benzo}{p_end}
{phang3}{cmd:1 "01jan2020" "10jan2020" 0}{p_end}
{phang3}{cmd:1 "11jan2020" "31jan2020" 1}{p_end}
{phang3}{cmd:2 "01jan2020" "31jan2020" 0}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double bz_start = date(start_s, "DMY")}{p_end}
{phang2}{cmd:. generate double bz_stop = date(stop_s, "DMY")}{p_end}
{phang2}{cmd:. format bz_start bz_stop %td}{p_end}
{phang2}{cmd:. drop start_s stop_s}{p_end}
{phang2}{cmd:. save `benzo'}{p_end}

{pstd}{bf:Align two interval sources}{p_end}
{phang2}{cmd:. tvmerge `drug' `benzo', id(id) ///}{p_end}
{phang3}{cmd:start(rx_start bz_start) stop(rx_stop bz_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_drug tv_benzo) saveas(`merged') replace}{p_end}

{pstd}{bf:Prefix the original exposure names}{p_end}
{phang2}{cmd:. tvmerge `drug' `benzo', id(id) ///}{p_end}
{phang3}{cmd:start(rx_start bz_start) stop(rx_stop bz_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_drug tv_benzo) prefix(exp_)}{p_end}

{pstd}
The output names are {cmd:exp_tv_drug} and {cmd:exp_tv_benzo}: {opt prefix()}
prepends text to each original name; it does not replace names with positional
numbers.

{pstd}{bf:Frames-first merge}{p_end}
{phang2}{cmd:. capture frame drop f_drug}{p_end}
{phang2}{cmd:. capture frame drop f_benzo}{p_end}
{phang2}{cmd:. capture frame drop f_merged}{p_end}
{phang2}{cmd:. frame create f_drug}{p_end}
{phang2}{cmd:. frame f_drug: use `drug', clear}{p_end}
{phang2}{cmd:. frame create f_benzo}{p_end}
{phang2}{cmd:. frame f_benzo: use `benzo', clear}{p_end}
{phang2}{cmd:. tvmerge, frames(f_drug f_benzo) id(id) ///}{p_end}
{phang3}{cmd:start(rx_start bz_start) stop(rx_stop bz_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_drug tv_benzo) frameout(f_merged) check flow}{p_end}

{pstd}{bf:Scriptable gap and overlap validation}{p_end}
{phang2}{cmd:. tvmerge `drug' `benzo', id(id) ///}{p_end}
{phang3}{cmd:start(rx_start bz_start) stop(rx_stop bz_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_drug tv_benzo) validatecoverage validateoverlap verbose}{p_end}
{phang2}{cmd:. return list}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvmerge} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations in merged dataset{p_end}
{synopt:{cmd:r(N_persons)}}number of unique persons{p_end}
{synopt:{cmd:r(mean_periods)}}mean periods per person{p_end}
{synopt:{cmd:r(max_periods)}}maximum periods for any person{p_end}
{synopt:{cmd:r(N_datasets)}}number of datasets merged{p_end}
{synopt:{cmd:r(n_rate)}}number of rate variables{p_end}
{synopt:{cmd:r(n_total)}}number of interval-total variables{p_end}
{synopt:{cmd:r(n_cumulative)}}number of cumulative-history variables{p_end}
{synopt:{cmd:r(n_continuous)}}number of totals declared through legacy {cmd:continuous()}{p_end}
{synopt:{cmd:r(n_categorical)}}number of categorical exposures{p_end}
{synopt:{cmd:r(n_invalid)}}malformed source rows detected{p_end}
{synopt:{cmd:r(n_invalid_id)}}rows with missing IDs{p_end}
{synopt:{cmd:r(n_invalid_dates)}}rows with missing or fractional daily bounds{p_end}
{synopt:{cmd:r(n_invalid_order)}}rows with reversed bounds{p_end}
{synopt:{cmd:r(n_invalid_exposure)}}rows with missing required exposure values{p_end}
{synopt:{cmd:r(n_invalid_ds#)}}malformed rows in source dataset #{p_end}
{synopt:{cmd:r(n_input_overlaps)}}input rows overlapping a running prior maximum{p_end}
{synopt:{cmd:r(n_input_overlaps_ds#)}}input overlaps in source dataset #{p_end}
{synopt:{cmd:r(n_gaps)}}output coverage gaps (zero unless validation finds any){p_end}
{synopt:{cmd:r(n_overlaps)}}identical-vector output overlap pairs{p_end}
{synopt:{cmd:r(n_duplicates_dropped)}}full-row duplicates removed{p_end}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(datasets)}}list of datasets merged{p_end}
{synopt:{cmd:r(exposure_vars)}}names of exposure variables in output{p_end}
{synopt:{cmd:r(rate_vars)}}rate variable names{p_end}
{synopt:{cmd:r(total_vars)}}interval-total variable names{p_end}
{synopt:{cmd:r(cumulative_vars)}}cumulative-history variable names{p_end}
{synopt:{cmd:r(continuous_vars)}}legacy {cmd:continuous()} aliases (totals){p_end}
{synopt:{cmd:r(categorical_vars)}}names of categorical exposure variables{p_end}
{synopt:{cmd:r(startname)}}name of start date variable in output{p_end}
{synopt:{cmd:r(stopname)}}name of stop date variable in output{p_end}
{synopt:{cmd:r(dateformat)}}date format applied to output{p_end}
{synopt:{cmd:r(prefix)}}prefix used (if prefix option used){p_end}
{synopt:{cmd:r(generated_names)}}generated names (if generate option used){p_end}
{synopt:{cmd:r(output_file)}}output filename (if saveas option used){p_end}
{synopt:{cmd:r(frameout)}}name of the output frame (if frameout option used){p_end}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Matrices}{p_end}
{synopt:{cmd:r(flow)}}persons/records attrition table{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Manual: {manlink D merge}

{psee}
Online: {helpb tvexpose}, {helpb merge}, {helpb joinby}, {helpb append}

{hline}

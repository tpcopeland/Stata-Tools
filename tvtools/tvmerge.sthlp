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
{synopt:{opt con:tinuous(namelist)}}continuous exposure variables{p_end}

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
Unlike standard Stata {cmd:merge}, {cmd:tvmerge} performs time-interval matching rather than simple 
key-based matching. It identifies temporal overlaps between the {cmd:tvexpose} outputs and creates new time intervals 
representing the intersections of exposure periods. The command creates all possible overlapping 
combinations between datasets (cartesian product).

{pstd}
{bf:Exposure types}: {cmd:tvmerge} handles two types of exposures:

{phang}
{bf:Categorical exposures} (default): Creates cartesian product of all exposure
combinations. Each unique combination of exposure values across datasets becomes
a separate period.

{phang}
{bf:Continuous exposures}: Treats exposure as a rate per day. The exposure value
is prorated proportionally when intervals are split during merging.

{pstd}
{bf:Important}: {cmd:tvmerge} replaces the dataset currently in memory with the merged result. Use 
{opt saveas()} to save results to a file, or load your original data from a saved file before running 
if you need to preserve it.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier variable that must exist in all datasets with identical 
names. This variable links records across datasets. It may be numeric or
{cmd:str#}; {cmd:strL} identifiers are not allowed (recast to {cmd:str#} first).

{phang}
{opt start(namelist)} specifies the start date variables for all datasets,
listed in the same order as the datasets in the command line.

{phang}
{opt stop(namelist)} specifies the stop date variables for all datasets, listed
in the same order as the datasets in the command line.

{phang}
{opt exposure(namelist)} specifies the exposure variables for all datasets,
listed in the same order as the datasets in the command line.


{dlgtab:Input}

{phang}
{opt frames(namelist)} reads the input datasets from named {help frame:frames}
held in memory instead of from files on disk, in the order listed. This removes
the save/use round-trip when each {cmd:tvexpose} output is already a frame.{...}
Supply either the positional file list or {opt frames()}, not both. All other
options ({opt start()}, {opt stop()}, {opt exposure()}, etc.) apply per input
exactly as with file paths.


{dlgtab:Exposure types}

{phang}
{opt continuous(namelist)} specifies which exposures should be treated as
continuous (rates per day) rather than categorical. You can specify either
variable names or dataset positions (1, 2, 3, etc.). Continuous exposure values
are prorated proportionally when intervals are split during merging.


{dlgtab:Output naming}

{phang}
{opt generate(namelist)} specifies new names for exposure variables in the output dataset. Provide exactly
one name per dataset, in the same order as the datasets. This option is mutually exclusive with
{opt prefix()}.

{pmore}
When {opt generate()} is {it:not} given and two or more inputs carry the same
exposure name (the common case, since {cmd:tvexpose} defaults every output to
{cmd:tv_exposure}), {cmd:tvmerge} automatically suffixes the colliding output
names by position ({cmd:tv_exposure_1}, {cmd:tv_exposure_2}, ...) and prints a
note, instead of erroring. To skip the rename entirely, give each
{cmd:tvexpose} run a distinct {opt generate()} name up front.

{phang}
{opt prefix(string)} adds a prefix to all exposure variable names in the output. For example, 
{cmd:prefix(exp_)} would create variables named exp1, exp2, etc. This option is mutually exclusive with {opt generate()}.

{phang}
{opt startname(string)} specifies the name for the start date variable in the output dataset. Default is 
"start".

{phang}
{opt stopname(string)} specifies the name for the stop date variable in the output dataset. Default is 
"stop".

{phang}
{opt dateformat(fmt)} specifies the Stata date format to apply to the output start and stop date variables.{...}
Default is %tdCCYY/NN/DD. Any valid Stata date format may be used.


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
datasets. These variables are included in the output dataset with _ds# suffixes
(where # is the dataset number) to distinguish variables from different sources. For
example, if you specify {cmd:keep(dose)}, the output will contain dose_ds1,
dose_ds2, and so on. The ID variable, start and stop date variables, and
exposure variables are always kept and do not receive suffixes.


{dlgtab:Diagnostics and validation}

{phang}
{opt check} displays coverage diagnostics including the number of persons,
average periods per person, maximum periods per person, and total merged
intervals.

{phang}
{opt validatecoverage} checks for gaps in person-time coverage. Gaps larger than
1 day are reported. This is useful for ensuring that your merge has not
inadvertently created discontinuous exposure histories. Any gaps found are
listed showing the ID, start and stop dates, and gap size.

{phang}
{opt validateoverlap} checks for unexpected overlapping periods within the same
person. Overlaps occur when a period starts before the previous period ends. Any
overlaps found are listed showing the ID and the overlapping periods. This can
indicate data quality issues or unintended merge results.

{phang}
{opt summarize} displays summary statistics (min, max, mean, percentiles) for the start and stop date
variables in the merged output dataset.

{phang}
{opt flow} reports an attrition table: the number of persons (union of distinct
ids across the inputs) and records entering versus leaving the merge, with the
difference. Persons can drop when {opt force} merges datasets with non-matching
ids. The table is returned in the matrix {cmd:r(flow)} (rows {cmd:persons} and
{cmd:records}; columns {cmd:in}, {cmd:out}, {cmd:dropped}) for STROBE/RECORD-PE
reporting. It is a pure side channel and does not change the output dataset.

{phang}
{opt verbose} displays individual IDs and dates when {cmd:validatecoverage}
or {cmd:validateoverlap} detect issues. Without {cmd:verbose}, only summary
counts are shown and a hint to use {cmd:verbose} is displayed.


{dlgtab:ID matching}

{phang}
{opt force} allows merging datasets where the set of IDs does not match exactly
across all datasets. By default, {cmd:tvmerge} errors if any IDs appear in some
datasets but not others, because {cmd:joinby} silently drops non-matching IDs.{...}
With {opt force}, mismatched IDs are dropped with a warning showing which IDs
were affected and how many observations were removed. Only IDs present in ALL
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
The merge creates all possible combinations of overlapping periods (Cartesian product). For example, 
if person 1 has two antidepressant periods that overlap with three benzodiazepine periods, the merge will
produce six output records representing all combinations.

{pstd}
{bf:Time period validity}

{pstd}
All input datasets must have valid time periods where start <= stop. Records with invalid periods
(start > stop) are automatically excluded with a warning message. Point-in-time observations (where
start = stop) are valid; for example, lab measurements or clinic visits that occur on a single day.


{pstd}
{bf:Missing values}

{pstd}
Missing exposure values are retained by default and appear in the output dataset. Missing date values 
will cause records to be excluded (they cannot define valid time periods).


{pstd}
{bf:Variable naming and suffixes}

{pstd}
When using {opt keep()}, additional variables from different source datasets receive _ds# suffixes 
(where # is 1, 2, 3, etc., corresponding to the dataset order). This prevents naming conflicts when 
the same variable name appears in multiple datasets. The ID variable is not suffixed because it 
represents the same entity across all datasets. The output start and stop date variables are not 
suffixed because they represent the merged time intervals, not source-specific values. Exposure 
variables are renamed according to {opt generate()}, {opt prefix()}, or default names (exp1, exp2, etc.).

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
{bf:IMPORTANT}: All examples below assume you have first created time-varying datasets
using {helpb tvexpose}. The examples use synthetic datasets from {bf:_data/} modeling
an SSRI vs SNRI antidepressant study.

{pstd}
The standard workflow is:

{phang2}
Step 1: Create time-varying antidepressant dataset using {cmd:tvexpose}, rename exposure

{phang2}
Step 2: Create time-varying benzodiazepine dataset using {cmd:tvexpose}, rename exposure

{phang2}
Step 3: Merge the two time-varying datasets using {cmd:tvmerge}


{pstd}
{bf:Example 1: Basic two-dataset merge}

{pstd}
First, create time-varying datasets from the exposure episode files:

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}

{phang2}{cmd:. tvexpose using _data/tv_antidep_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(_data/tv_antidep.dta) replace}{p_end}

{phang2}{cmd:. * Rename exposure (tvmerge requires unique names per dataset)}{p_end}
{phang2}{stata "use _data/tv_antidep.dta, clear":. use _data/tv_antidep.dta, clear}{p_end}
{phang2}{stata "rename tv_exposure drug_class":. rename tv_exposure drug_class}{p_end}
{phang2}{stata "save _data/tv_antidep.dta, replace":. save _data/tv_antidep.dta, replace}{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}

{phang2}{cmd:. tvexpose using _data/tv_benzo_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(benzo_use) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(_data/tv_benzo.dta) replace}{p_end}

{phang2}{stata "use _data/tv_benzo.dta, clear":. use _data/tv_benzo.dta, clear}{p_end}
{phang2}{stata "rename tv_exposure benzo":. rename tv_exposure benzo}{p_end}
{phang2}{stata "save _data/tv_benzo.dta, replace":. save _data/tv_benzo.dta, replace}{p_end}

{pstd}
Now merge the two time-varying datasets created by tvexpose:

{phang2}{stata "tvmerge _data/tv_antidep _data/tv_benzo, id(id) start(rx_start rx_start) stop(rx_stop rx_stop) exposure(drug_class benzo)":. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo)}{p_end}

{pstd}
The output dataset contains one row for each unique combination of overlapping antidepressant and benzodiazepine periods.


{pstd}
{bf:Example 2: Merge with custom variable names}

{pstd}
Same workflow as Example 1, but specify custom names for output variables:

{phang2}{cmd:. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo) ///}{p_end}
{phang3}{cmd:generate(antidep_class concomitant_benzo) ///}{p_end}
{phang3}{cmd:startname(period_start) stopname(period_end)}{p_end}

{pstd}
Output variables are named antidep_class, concomitant_benzo, period_start, and period_end instead of the defaults.


{pstd}
{bf:Example 3: Keep additional covariates from tvexpose outputs}

{pstd}
When running tvexpose, use keepvars() to bring covariates into the time-varying datasets:

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvexpose using _data/tv_antidep_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(index_age female) saveas(_data/tv_antidep.dta) replace}{p_end}

{phang2}{stata "use _data/tv_antidep.dta, clear":. use _data/tv_antidep.dta, clear}{p_end}
{phang2}{stata "rename tv_exposure drug_class":. rename tv_exposure drug_class}{p_end}
{phang2}{stata "save _data/tv_antidep.dta, replace":. save _data/tv_antidep.dta, replace}{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvexpose using _data/tv_benzo_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(benzo_use) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(education) saveas(_data/tv_benzo.dta) replace}{p_end}

{phang2}{stata "use _data/tv_benzo.dta, clear":. use _data/tv_benzo.dta, clear}{p_end}
{phang2}{stata "rename tv_exposure benzo":. rename tv_exposure benzo}{p_end}
{phang2}{stata "save _data/tv_benzo.dta, replace":. save _data/tv_benzo.dta, replace}{p_end}

{pstd}
Now merge and keep the covariates from both datasets:

{phang2}{cmd:. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo) ///}{p_end}
{phang3}{cmd:keep(index_age female education)}{p_end}

{pstd}
The output includes index_age_ds1, female_ds1 (from antidepressant tvexpose),
education_ds2 (from benzodiazepine tvexpose), plus id, start, stop, drug_class,
and benzo.


{pstd}
{bf:Example 4: Diagnostics and validation}

{pstd}
Check the merge results for coverage issues (assume tv_antidep.dta and tv_benzo.dta already created):

{phang2}{cmd:. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo) ///}{p_end}
{phang3}{cmd:check validatecoverage validateoverlap summarize}{p_end}

{pstd}
The {cmd:check} option displays how many persons were merged, average periods
per person, and maximum periods. {cmd:validatecoverage} identifies any gaps in
the merged timeline. {cmd:validateoverlap} flags unexpected overlapping periods. {cmd:summarize}
shows date range statistics.


{pstd}
{bf:Example 5: Save output to file}

{pstd}
Merge and save the result for later analysis:

{phang2}{cmd:. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo) ///}{p_end}
{phang3}{cmd:saveas(_data/tv_merged.dta) replace}{p_end}

{pstd}
This saves the merged dataset to _data/tv_merged.dta.


{pstd}
{bf:Example 6: Merge with different exposure definitions}

{pstd}
Create one tvexpose output with evertreated and another with currentformer:

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvexpose using _data/tv_antidep_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:evertreated generate(ever_antidep) ///}{p_end}
{phang3}{cmd:saveas(_data/tv_antidep_ever.dta) replace}{p_end}

{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvexpose using _data/tv_benzo_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(benzo_use) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:currentformer generate(benzo_cf) ///}{p_end}
{phang3}{cmd:saveas(_data/tv_benzo_cf.dta) replace}{p_end}

{phang2}{cmd:. tvmerge _data/tv_antidep_ever _data/tv_benzo_cf, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(ever_antidep benzo_cf) ///}{p_end}
{phang3}{cmd:generate(antidep_ever benzo_status)}{p_end}

{pstd}
This combines an ever-treated antidepressant variable with a current/former benzodiazepine variable in a single dataset.


{pstd}
{bf:Example 7: Prefix for systematic naming}

{pstd}
Use a prefix instead of custom names (assume tv_antidep.dta and tv_benzo.dta already created):

{phang2}{stata "tvmerge _data/tv_antidep _data/tv_benzo, id(id) start(rx_start rx_start) stop(rx_stop rx_stop) exposure(drug_class benzo) prefix(exp_)":. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo) ///}{p_end}
{phang3}{cmd:prefix(exp_)}{p_end}

{pstd}
This creates variables named exp_1 (antidepressant class) and exp_2 (benzodiazepine) in the output.


{pstd}
{bf:Example 8: Integration with cohort data}

{pstd}
After merging tvexpose outputs, merge with the cohort file for additional baseline characteristics:

{phang2}{stata "tvmerge _data/tv_antidep _data/tv_benzo, id(id) start(rx_start rx_start) stop(rx_stop rx_stop) exposure(drug_class benzo)":. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo)}{p_end}

{phang2}{cmd:. merge m:1 id using _data/cohort.dta, keepusing(index_age female education) keep(match) nogen}{p_end}

{pstd}
This brings baseline demographic variables into the merged exposure dataset for regression analysis.


{pstd}
{bf:Example 9: Comprehensive workflow with validation}

{pstd}
Complete workflow from tvexpose through tvmerge, validation, and survival analysis:

{phang2}{cmd:. * Step 1: Create time-varying antidepressant dataset}{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvexpose using _data/tv_antidep_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(index_age female) saveas(_data/tv_antidep.dta) replace}{p_end}

{phang2}{stata "use _data/tv_antidep.dta, clear":. use _data/tv_antidep.dta, clear}{p_end}
{phang2}{stata "rename tv_exposure drug_class":. rename tv_exposure drug_class}{p_end}
{phang2}{stata "save _data/tv_antidep.dta, replace":. save _data/tv_antidep.dta, replace}{p_end}

{phang2}{cmd:. * Step 2: Create time-varying benzodiazepine dataset}{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta", clear"':. use _data/cohort.dta, clear}{p_end}
{phang2}{cmd:. tvexpose using _data/tv_benzo_episodes.dta, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(benzo_use) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(education) saveas(_data/tv_benzo.dta) replace}{p_end}

{phang2}{stata "use _data/tv_benzo.dta, clear":. use _data/tv_benzo.dta, clear}{p_end}
{phang2}{stata "rename tv_exposure benzo":. rename tv_exposure benzo}{p_end}
{phang2}{stata "save _data/tv_benzo.dta, replace":. save _data/tv_benzo.dta, replace}{p_end}

{phang2}{cmd:. * Step 3: Merge and validate}{p_end}
{phang2}{cmd:. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo) ///}{p_end}
{phang3}{cmd:keep(index_age female education) ///}{p_end}
{phang3}{cmd:check validatecoverage summarize ///}{p_end}
{phang3}{cmd:saveas(_data/tv_merged.dta) replace}{p_end}

{phang2}{cmd:. * Step 4: Cross-tabulation}{p_end}
{phang2}{stata "tab drug_class benzo, mi":. tab drug_class benzo, mi}{p_end}

{phang2}{stata "list id start stop drug_class benzo index_age_ds1 female_ds1 in 1/20, sepby(id)":. list id start stop drug_class benzo index_age_ds1 female_ds1 in 1/20, sepby(id)}{p_end}


{pstd}
{bf:Example 10: Continuous exposure merging}

{pstd}
Merge a categorical antidepressant variable with continuous DDD rates:

{phang2}{cmd:. * Assume tv_antidep.dta has categorical drug_class}{p_end}
{phang2}{cmd:. * and tv_ddd.dta has continuous DDD rates per day}{p_end}

{phang2}{stata "tvmerge _data/tv_antidep _data/tv_ddd, id(id) start(rx_start rx_start) stop(rx_stop rx_stop) exposure(drug_class ddd_rate) continuous(ddd_rate)":. tvmerge _data/tv_antidep _data/tv_ddd, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class ddd_rate) ///}{p_end}
{phang3}{cmd:continuous(ddd_rate)}{p_end}

{pstd}
This creates variables: drug_class (categorical) and ddd_rate (rate per day, prorated to each time slice).


{pstd}
{bf:Example 11: Large datasets}

{pstd}
No performance tuning is needed for large datasets. The compiled Mata sweep
intersects intervals per person without building the Cartesian product, so the
same call scales to registry-sized inputs:

{phang2}{stata "tvmerge _data/tv_antidep _data/tv_benzo, id(id) start(rx_start rx_start) stop(rx_stop rx_stop) exposure(drug_class benzo)":. tvmerge _data/tv_antidep _data/tv_benzo, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start rx_start) stop(rx_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(drug_class benzo)}{p_end}

{pstd}
On very large merges a one-line matching-progress indicator is shown (unless the
command is run quietly). The former {opt batch(#)} option is deprecated and
ignored.


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
{synopt:{cmd:r(n_continuous)}}number of continuous exposures (if continuous() used){p_end}
{synopt:{cmd:r(n_categorical)}}number of categorical exposures{p_end}

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(datasets)}}list of datasets merged{p_end}
{synopt:{cmd:r(exposure_vars)}}names of exposure variables in output{p_end}
{synopt:{cmd:r(continuous_vars)}}continuous exposure variable names{p_end}
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
Manual:  {manlink D merge}

{psee}
Online:  {helpb tvexpose}, {helpb merge}, {helpb joinby}, {helpb append}

{hline}

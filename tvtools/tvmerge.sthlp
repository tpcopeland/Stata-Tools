{smcl}
{* *! version 1.0.4  2025/12/14}{...}
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
{cmd:tvmerge} {it:dataset1} {it:dataset2} [{it:dataset3} ...]{cmd:,}
{opt id(varname)}
{opt start(namelist)}
{opt stop(namelist)}
{opt exposure(namelist)}
[{it:options}]


{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier variable present in all datasets{p_end}
{synopt:{opt start(namelist)}}start date variables (one per dataset, in order){p_end}
{synopt:{opt stop(namelist)}}stop date variables (one per dataset, in order){p_end}
{synopt:{opt exposure(namelist)}}exposure variables (one per dataset, in order){p_end}

{syntab:Exposure types}
{synopt:{opt con:tinuous(namelist)}}specify which exposures are continuous (rates per day){p_end}

{syntab:Output naming}
{synopt:{opt gen:erate(namelist)}}new names for exposure variables (one per dataset){p_end}
{synopt:{opt pre:fix(string)}}prefix for all exposure variable names{p_end}
{synopt:{opt startname(string)}}name for output start date variable (default: start){p_end}
{synopt:{opt stopname(string)}}name for output stop date variable (default: stop){p_end}
{synopt:{opt dateformat(fmt)}}Stata date format for output (default: %tdCCYY/NN/DD){p_end}

{syntab:Data management}
{synopt:{opt saveas(filename)}}save merged dataset to file{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synopt:{opt keep(varlist)}}additional variables to keep from source datasets (suffixed with _ds#){p_end}

{syntab:Diagnostics and validation}
{synopt:{opt check}}display coverage diagnostics{p_end}
{synopt:{opt validatecoverage}}verify all person-time accounted for (check for gaps){p_end}
{synopt:{opt validateoverlap}}verify overlapping periods make sense{p_end}
{synopt:{opt sum:marize}}display summary statistics of start/stop dates{p_end}

{syntab:Performance}
{synopt:{opt batch(#)}}process IDs in batches (default: 20 = 20% per batch; range: 1-100){p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvmerge} merges multiple time-varying exposure datasets created by {helpb tvexpose}. The command is designed to work specifically with the output from {cmd:tvexpose}, combining multiple exposure variables into a single dataset with synchronized time periods.

{pstd}
{bf:CRITICAL PREREQUISITE}: {cmd:tvmerge} requires that each input dataset has already been processed by {cmd:tvexpose}. You cannot use {cmd:tvmerge} directly on raw exposure files. The typical workflow is:

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
{bf:Categorical exposures} (default): Creates cartesian product of all exposure combinations. Each unique combination of exposure values across datasets becomes a separate period.

{phang}
{bf:Continuous exposures}: Treats exposure as a rate per day and calculates period-specific exposure. For continuous exposures, two variables are created: one for the rate and one for the period-specific exposure amount.

{pstd}
{bf:Important}: {cmd:tvmerge} replaces the dataset currently in memory with the merged result. Use 
{opt saveas()} to save results to a file, or load your original data from a saved file before running 
if you need to preserve it.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the person identifier variable that must exist in all datasets with identical 
names. This variable links records across datasets.

{phang}
{opt start(namelist)} specifies the start date variables for all datasets, listed in the same order as the datasets in the command line.

{phang}
{opt stop(namelist)} specifies the stop date variables for all datasets, listed in the same order as the datasets in the command line.

{phang}
{opt exposure(namelist)} specifies the exposure variables for all datasets, listed in the same order as the datasets in the command line.


{dlgtab:Exposure types}

{phang}
{opt continuous(namelist)} specifies which exposures should be treated as continuous (rates per day) rather than categorical. You can specify either variable names or dataset positions (1, 2, 3, etc.). For continuous exposures, two variables are created: {it:varname} containing the rate per day and {it:varname}_period containing the exposure amount for that specific time period.


{dlgtab:Output naming}

{phang}
{opt generate(namelist)} specifies new names for exposure variables in the output dataset. Provide exactly 
one name per dataset, in the same order as the datasets. This option is mutually exclusive with 
{opt prefix()}.

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
{opt dateformat(fmt)} specifies the Stata date format to apply to the output start and stop date variables. 
Default is %tdCCYY/NN/DD. Any valid Stata date format may be used.


{dlgtab:Data management}

{phang}
{opt saveas(filename)} saves the merged dataset to the specified file. Include the .dta extension. Use with {opt replace} to overwrite an existing file.

{phang}
{opt replace} allows {opt saveas()} to overwrite an existing file.

{phang}
{opt keep(varlist)} specifies additional variables to keep from the source datasets. These variables are included in the output dataset with _ds# suffixes (where # is the dataset number) to distinguish variables from different sources. For example, if you specify {cmd:keep(dose)}, the output will contain dose_ds1, dose_ds2, and so on. The ID variable, start and stop date variables, and exposure variables are always kept and do not receive suffixes.


{dlgtab:Diagnostics and validation}

{phang}
{opt check} displays coverage diagnostics including the number of persons, average periods per person, maximum periods per person, and total merged intervals.

{phang}
{opt validatecoverage} checks for gaps in person-time coverage. Gaps larger than 1 day are reported. This is useful for ensuring that your merge has not inadvertently created discontinuous exposure histories. Any gaps found are listed showing the ID, start and stop dates, and gap size.

{phang}
{opt validateoverlap} checks for unexpected overlapping periods within the same person. Overlaps occur when a period starts before the previous period ends. Any overlaps found are listed showing the ID and the overlapping periods. This can indicate data quality issues or unintended merge results.

{phang}
{opt summarize} displays summary statistics (min, max, mean, percentiles) for the start and stop date
variables in the merged output dataset.


{dlgtab:Performance}

{phang}
{opt batch(#)} controls how many IDs are processed together in each batch during the merge operation. The value represents the percentage of total unique IDs to process per batch (range: 1-100, default: 20).

{pmore}
Batch processing significantly improves performance for datasets with many unique IDs by reducing disk I/O operations. Instead of processing one ID at a time (which requires loading the entire dataset for each ID), the command processes groups of IDs together.

{pmore}
{bf:Choosing a batch size:}

{pmore2}
{bf:Larger batches} (e.g., {cmd:batch(50)} = 50%): Faster but uses more memory. Recommended for datasets with moderate numbers of IDs (< 10,000) and when you have sufficient RAM.

{pmore2}
{bf:Smaller batches} (e.g., {cmd:batch(10)} = 10%): Slower but uses less memory. Recommended for very large datasets (> 50,000 IDs) or when memory is limited.

{pmore2}
{bf:Default} ({cmd:batch(20)} = 20%): Good balance for most use cases. A dataset with 10,000 IDs will be processed in 5 batches of 2,000 IDs each.

{pmore}
{bf:Performance impact:} For a dataset with 10,000 unique IDs, batch processing reduces I/O operations from 10,000 (one-at-a-time) to 5 (with default batch(20)), resulting in 10-50x faster execution depending on dataset complexity.

{pmore}
The batch option works transparently with all other options and produces identical results to one-at-a-time processing. Progress messages display batch status during execution.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Understanding merge strategies}

{pstd}
The merge creates all possible combinations of overlapping periods (Cartesian product). For example, 
if person 1 has two HRT periods that overlap with three DMT periods, the merge will 
produce six output records representing all combinations.

{pstd}
{bf:Time period validity}

{pstd}
All input datasets must have valid time periods where start < stop. Records with invalid periods 
(start >= stop) are automatically excluded with a warning message. Point-in-time observations (where 
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
Cartesian merges with multiple datasets can produce very large output datasets, especially when individuals have many overlapping exposure periods. The command uses batch processing to optimize performance: instead of processing one ID at a time, it processes groups of IDs together, dramatically reducing disk I/O operations.

{pstd}
The default {cmd:batch(20)} setting processes 20% of unique IDs per batch, providing good performance for most datasets. For large datasets with tens of thousands of unique IDs, you can adjust the batch size using the {opt batch(#)} option. Larger batch sizes are faster but use more memory; smaller batch sizes use less memory but are slower. See the {opt batch(#)} option documentation for details.

{pstd}
Execution time varies from seconds for small datasets to several minutes for very large datasets with complex exposure patterns. Progress messages indicate batch processing status during execution.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:IMPORTANT}: All examples below assume you have first created time-varying datasets using {helpb tvexpose}. The examples use synthetic datasets generated by {bf:generate_test_data.do}:

{phang2}
{bf:cohort.dta}: 1,000 persons with study entry/exit dates and outcomes

{phang2}
{bf:hrt.dta}: Raw hormone replacement therapy exposure periods

{phang2}
{bf:dmt.dta}: Raw disease-modifying therapy exposure periods

{pstd}
The standard workflow for all examples is:

{phang2}
Step 1: Create time-varying HRT dataset using {cmd:tvexpose}

{phang2}
Step 2: Create time-varying DMT dataset using {cmd:tvexpose}

{phang2}
Step 3: Merge the two time-varying datasets using {cmd:tvmerge}


{pstd}
{bf:Example 1: Basic two-dataset merge}

{pstd}
First, create time-varying datasets from the raw exposure files:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(tv_hrt.dta) replace}{p_end}

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(tv_dmt.dta) replace}{p_end}

{pstd}
Now merge the two time-varying datasets created by tvexpose:

{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure)}{p_end}

{pstd}
The output dataset contains one row for each unique combination of overlapping HRT and DMT periods. Variables exp1 (HRT type) and exp2 (DMT type) show the exposure status during each time interval.


{pstd}
{bf:Example 2: Merge with custom variable names}

{pstd}
Same workflow as Example 1, but specify custom names for output variables:

{phang2}{cmd:. * First create time-varying datasets (same as Example 1)}{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) saveas(tv_hrt.dta) replace}{p_end}

{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) saveas(tv_dmt.dta) replace}{p_end}

{pstd}
Now merge with meaningful variable names:

{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type) ///}{p_end}
{phang3}{cmd:startname(period_start) stopname(period_end)}{p_end}

{pstd}
Output variables are now named hrt, dmt_type, period_start, and period_end instead of the defaults.


{pstd}
{bf:Example 3: Keep additional covariates from tvexpose outputs}

{pstd}
When running tvexpose, use keepvars() to bring covariates into the time-varying datasets:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(age female) saveas(tv_hrt.dta) replace}{p_end}

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(mstype edss_baseline) saveas(tv_dmt.dta) replace}{p_end}

{pstd}
Now merge and keep the covariates from both datasets:

{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:keep(age female mstype edss_baseline) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type)}{p_end}

{pstd}
The output includes age_ds1, female_ds1 (from HRT tvexpose), mstype_ds2, edss_baseline_ds2 (from DMT tvexpose), plus the standard id, start, stop, hrt, and dmt_type variables.


{pstd}
{bf:Example 4: Diagnostics and validation}

{pstd}
Check the merge results for coverage issues (assume tv_hrt.dta and tv_dmt.dta already created as in Example 1):

{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:check validatecoverage validateoverlap summarize}{p_end}

{pstd}
The {cmd:check} option displays how many persons were merged, average periods per person, and maximum periods. {cmd:validatecoverage} identifies any gaps in the merged timeline. {cmd:validateoverlap} flags unexpected overlapping periods. {cmd:summarize} shows date range statistics.


{pstd}
{bf:Example 5: Save output to file}

{pstd}
Merge and save the result for later analysis (assume tv_hrt.dta and tv_dmt.dta already created):

{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type) ///}{p_end}
{phang3}{cmd:saveas(merged_exposures.dta) replace}{p_end}

{pstd}
This saves the merged dataset to merged_exposures.dta, replacing any existing file with that name.


{pstd}
{bf:Example 6: Three-dataset merge}

{pstd}
Merge three tvexpose outputs (assume tv_hrt.dta and tv_dmt.dta already created):

{phang2}{cmd:. * Create third dataset}{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:saveas(tv_hrt2.dta) replace}{p_end}

{phang2}{cmd:. tvmerge tv_hrt tv_dmt tv_hrt2, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start rx_start) ///}{p_end}
{phang3}{cmd:stop(rx_stop dmt_stop rx_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type hrt2)}{p_end}

{pstd}
This merges three datasets and creates three exposure variables (hrt, dmt_type, hrt2).


{pstd}
{bf:Example 7: Merge with different exposure definitions}

{pstd}
Create one tvexpose output with evertreated and another with currentformer:

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:evertreated generate(ever_hrt) ///}{p_end}
{phang3}{cmd:saveas(tv_hrt_ever.dta) replace}{p_end}

{phang2}{cmd:. use cohort, clear}{p_end}

{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:currentformer generate(dmt_cf) ///}{p_end}
{phang3}{cmd:saveas(tv_dmt_cf.dta) replace}{p_end}

{phang2}{cmd:. tvmerge tv_hrt_ever tv_dmt_cf, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(ever_hrt dmt_cf) ///}{p_end}
{phang3}{cmd:generate(hrt_ever dmt_status)}{p_end}

{pstd}
This combines an ever-treated HRT variable with a current/former DMT variable in a single dataset.


{pstd}
{bf:Example 8: Prefix for systematic naming}

{pstd}
Use a prefix instead of custom names for each variable (assume tv_hrt.dta and tv_dmt.dta already created):

{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:prefix(exp_)}{p_end}

{pstd}
This creates variables named exp_1 (HRT) and exp_2 (DMT) in the output.


{pstd}
{bf:Example 9: Integration with cohort data}

{pstd}
After merging tvexpose outputs, merge with the cohort file to bring in additional baseline characteristics:

{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type)}{p_end}

{phang2}{cmd:. merge m:1 id using cohort, keepusing(age female mstype edss_baseline) keep(match) nogen}{p_end}

{pstd}
This brings baseline demographic and clinical variables into the merged exposure dataset for regression analysis.


{pstd}
{bf:Example 10: Comprehensive workflow with validation}

{pstd}
Complete workflow showing tvexpose, tvmerge, validation, and preparation for survival analysis:

{phang2}{cmd:. * Step 1: Create time-varying HRT dataset}{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using hrt, id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(hrt_type) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(age female) saveas(tv_hrt.dta) replace}{p_end}

{phang2}{cmd:. * Step 2: Create time-varying DMT dataset}{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. tvexpose using dmt, id(id) start(dmt_start) stop(dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(dmt) reference(0) ///}{p_end}
{phang3}{cmd:entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:keepvars(mstype edss_baseline) saveas(tv_dmt.dta) replace}{p_end}

{phang2}{cmd:. * Step 3: Merge the two time-varying datasets}{p_end}
{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type) ///}{p_end}
{phang3}{cmd:keep(age female mstype edss_baseline) ///}{p_end}
{phang3}{cmd:check validatecoverage summarize ///}{p_end}
{phang3}{cmd:saveas(merged_exposures.dta) replace}{p_end}

{phang2}{cmd:. * Step 4: Merge additional cohort characteristics}{p_end}
{phang2}{cmd:. merge m:1 id using cohort, keep(match) nogen}{p_end}

{phang2}{cmd:. * Step 5: Display cross-tabulation and sample rows}{p_end}
{phang2}{cmd:. tab hrt dmt_type, mi}{p_end}

{phang2}{cmd:. list id start stop hrt dmt_type age_ds1 female_ds1 in 1/20, sepby(id)}{p_end}

{pstd}
This workflow demonstrates the complete process from raw exposure files through tvexpose, tvmerge, validation, and merging with cohort characteristics.


{pstd}
{bf:Example 11: Continuous exposure merging}

{pstd}
Merge continuous exposures (like dosage rates) using the continuous() option:

{phang2}{cmd:. * Assume tv_hrt.dta has categorical HRT types}{p_end}
{phang2}{cmd:. * and tv_dose.dta has continuous dosage rates per day}{p_end}

{phang2}{cmd:. tvmerge tv_hrt tv_dose, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure dosage_rate) ///}{p_end}
{phang3}{cmd:continuous(dosage_rate) ///}{p_end}
{phang3}{cmd:generate(hrt_type dose)}{p_end}

{pstd}
This creates variables: hrt_type (categorical), dose (rate per day), and dose_period (total dose in each time slice).


{pstd}
{bf:Example 12: Multiple continuous exposures}

{pstd}
Merge multiple continuous exposures:

{phang2}{cmd:. tvmerge tv_drug1 tv_drug2 tv_drug3, id(id) ///}{p_end}
{phang3}{cmd:start(start start start) stop(stop stop stop) ///}{p_end}
{phang3}{cmd:exposure(rate1 rate2 rate3) ///}{p_end}
{phang3}{cmd:continuous(1 2 3) ///}{p_end}
{phang3}{cmd:generate(d1 d2 d3)}{p_end}

{pstd}
Each continuous exposure generates two variables: d1, d1_period, d2, d2_period, d3, d3_period.


{pstd}
{bf:Example 13: Performance optimization with batch processing}

{pstd}
For large datasets with many unique IDs, use the batch() option to control performance and memory usage:

{phang2}{cmd:. * Default batch processing (20% per batch)}{p_end}
{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type)}{p_end}

{phang2}{cmd:. * Larger batches for faster processing (50% per batch)}{p_end}
{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type) batch(50)}{p_end}

{phang2}{cmd:. * Smaller batches for memory-constrained systems (10% per batch)}{p_end}
{phang2}{cmd:. tvmerge tv_hrt tv_dmt, id(id) ///}{p_end}
{phang3}{cmd:start(rx_start dmt_start) stop(rx_stop dmt_stop) ///}{p_end}
{phang3}{cmd:exposure(tv_exposure tv_exposure) ///}{p_end}
{phang3}{cmd:generate(hrt dmt_type) batch(10)}{p_end}

{pstd}
Progress messages show batch processing status. For a dataset with 10,000 unique IDs: batch(20) processes 5 batches of 2,000 IDs each; batch(50) processes 2 batches of 5,000 IDs each; batch(10) processes 10 batches of 1,000 IDs each.


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
{synopt:{cmd:r(continuous_vars)}}names of continuous exposure variables (if continuous() used){p_end}
{synopt:{cmd:r(categorical_vars)}}names of categorical exposure variables{p_end}
{synopt:{cmd:r(startname)}}name of start date variable in output{p_end}
{synopt:{cmd:r(stopname)}}name of stop date variable in output{p_end}
{synopt:{cmd:r(dateformat)}}date format applied to output{p_end}
{synopt:{cmd:r(prefix)}}prefix used (if prefix option used){p_end}
{synopt:{cmd:r(generated_names)}}generated names (if generate option used){p_end}
{synopt:{cmd:r(output_file)}}output filename (if saveas option used){p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.4, 2025-12-14{p_end}


{title:Also see}

{psee}
Manual:  {manlink D merge}

{psee}
Online:  {helpb tvexpose}, {helpb merge}, {helpb joinby}, {helpb append}

{hline}

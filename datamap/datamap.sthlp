{smcl}
{* *{* *! version 1.0.0  2025/12/02}{...}
{vieweralsosee "[D] describe" "help describe"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[R] summarize" "help summarize"}{...}
{viewerjumpto "Syntax" "datamap##syntax"}{...}
{viewerjumpto "Description" "datamap##description"}{...}
{viewerjumpto "Options" "datamap##options"}{...}
{viewerjumpto "Remarks" "datamap##remarks"}{...}
{viewerjumpto "Examples" "datamap##examples"}{...}
{viewerjumpto "Stored results" "datamap##results"}{...}
{viewerjumpto "Author" "datamap##author"}{...}
{title:Title}

{phang}
{bf:datamap} {hline 2} Generate privacy-safe dataset documentation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datamap}
{cmd:,}
{it:input_option}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input (choose one)}
{synopt:{opt single(dataset)}}document a single Stata dataset{p_end}
{synopt:{opt dir:ectory(path)}}document all .dta files in a directory{p_end}
{synopt:{opt filelist(datasets)}}space-separated list of dataset names to process{p_end}

{syntab:Output}
{synopt:{opt output(filename)}}name of output file; default is {bf:datamap.txt}{p_end}
{synopt:{opt format(format)}}output format; only {bf:text} is currently supported{p_end}
{synopt:{opt sep:arate}}create separate output file for each dataset{p_end}
{synopt:{opt app:end}}append to existing output file{p_end}

{syntab:Privacy controls}
{synopt:{opt exclude(varlist)}}exclude specified variables from documentation{p_end}
{synopt:{opt datesafe}}show only date ranges, not exact dates{p_end}

{syntab:Content controls}
{synopt:{opt nostats}}suppress summary statistics for continuous variables{p_end}
{synopt:{opt nofreq}}suppress frequency tables for categorical variables{p_end}
{synopt:{opt nolabels}}suppress value label definitions{p_end}
{synopt:{opt nonotes}}suppress dataset notes{p_end}

{syntab:Parameters}
{synopt:{opt maxfreq(#)}}maximum unique values to show frequencies for; default is {bf:25}{p_end}
{synopt:{opt maxcat(#)}}maximum unique values to classify as categorical; default is {bf:25}{p_end}

{syntab:Detection features}
{synopt:{opt detect(options)}}enable specific detection features{p_end}
{synopt:{opt autodetect}}enable all detection features{p_end}
{synopt:{opt panelid(varname)}}specify panel ID variable for panel detection{p_end}
{synopt:{opt survivalvars(varlist)}}specify survival analysis variables{p_end}

{syntab:Data quality}
{synopt:{opt quality}}enable basic data quality checks{p_end}
{synopt:{opt quality2(strict)}}enable strict data quality checks{p_end}
{synopt:{opt missing(option)}}missing data analysis; {it:detail} or {it:pattern}{p_end}

{syntab:Sample data}
{synopt:{opt samples(#)}}include # sample observations in output{p_end}

{syntab:Advanced}
{synopt:{opt rec:ursive}}scan subdirectories recursively (with {cmd:directory()}){p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:datamap} generates comprehensive, privacy-safe documentation for Stata datasets.
It is designed for researchers who need to share dataset descriptions without revealing
sensitive information. The command automatically classifies variables as categorical,
continuous, date, string, or excluded, and generates appropriate documentation for each type.

{pstd}
The {opt .dta} extension is optional and assumed if not specified.

{pstd}
Key features include:

{phang2}1. Automatic variable classification based on type, format, and cardinality{p_end}
{phang2}2. Privacy controls to exclude sensitive variables or limit date precision{p_end}
{phang2}3. Flexible output options (single combined file or separate files per dataset){p_end}
{phang2}4. Support for multiple input modes (single file, directory scan, or dataset list){p_end}
{phang2}5. Comprehensive documentation including variable types, labels, missing values, and summary statistics{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{opt single(dataset)} documents a single Stata dataset file. The {opt .dta} 
extension is optional and will be added automatically if not specified.

{phang}
{opt directory(path)} scans a directory for all .dta files and documents them.
By default, only the specified directory is scanned. Use with {cmd:recursive} to scan subdirectories.

{phang}
{opt filelist(datasets)} specifies a space-separated list of dataset names to 
process. The {opt .dta} extension is optional for each dataset name.

{pmore}
Example: {cmd:filelist(patients hrt dmt)} will process {it:patients.dta}, 
{it:hrt.dta}, and {it:dmt.dta}.

{dlgtab:Output}

{phang}
{opt output(filename)} specifies the name of the output file. Default is {bf:datamap.txt}.
The file extension should match the format (currently only .txt is supported).

{phang}
{opt format(format)} specifies the output format. Currently only {bf:text} is supported.
Future versions may support markdown and JSON formats.

{phang}
{opt separate} creates a separate output file for each dataset instead of combining
all documentation into a single file. Output files are named {it:datasetname}_map.txt.

{phang}
{opt append} appends documentation to an existing output file instead of replacing it.
Useful for incrementally building documentation.

{dlgtab:Privacy controls}

{phang}
{opt exclude(varlist)} excludes the specified variables from all documentation.
Use this to protect personally identifiable information (PII) such as names, IDs,
or other sensitive variables. Excluded variables appear in the variable summary
with classification "excluded" but no statistics or frequencies are shown.

{phang}
{opt datesafe} restricts date variable documentation to show only the range
(minimum and maximum) instead of individual values or frequencies. This helps
prevent date-based reidentification.

{dlgtab:Content controls}

{phang}
{opt nostats} suppresses summary statistics (mean, SD, min, max, percentiles)
for continuous variables. The variables are still listed with their basic properties.

{phang}
{opt nofreq} suppresses frequency tables for categorical variables.
The variables are still listed and classified, but individual value frequencies are omitted.

{phang}
{opt nolabels} suppresses the value label definitions section.
Value labels are still shown attached to individual variables, but the detailed
label mappings are not included.

{phang}
{opt nonotes} suppresses dataset notes from the documentation.

{dlgtab:Parameters}

{phang}
{opt maxfreq(#)} specifies the maximum number of unique values for which
frequency tables will be shown. If a categorical variable has more than this
many unique values, frequencies are suppressed. Default is {bf:25}. Must be positive.

{phang}
{opt maxcat(#)} specifies the threshold for classifying numeric variables
as categorical versus continuous. Numeric variables with {it:#} or fewer unique values
(or with value labels) are classified as categorical. Default is {bf:25}. Must be positive.

{dlgtab:Advanced}

{phang}
{opt recursive} scans subdirectories recursively when using {cmd:directory()}.
Without this option, only .dta files in the specified directory are documented.

{dlgtab:Detection features}

{phang}
{opt detect(options)} enables specific detection features. Multiple options can be
specified separated by spaces. Valid options are:

{phang2}{bf:panel} - detect panel/longitudinal data structure{p_end}
{phang2}{bf:binary} - identify binary (0/1) variables as potential outcomes{p_end}
{phang2}{bf:survival} - detect survival/time-to-event variables{p_end}
{phang2}{bf:survey} - detect survey design elements (weights, strata, clusters){p_end}
{phang2}{bf:common} - detect common variable patterns (IDs, dates, demographics){p_end}

{pmore}
Example: {cmd:detect(panel survival)} enables panel and survival detection.

{phang}
{opt autodetect} enables all detection features (equivalent to specifying all 
options in {cmd:detect()}).

{phang}
{opt panelid(varname)} specifies the panel identifier variable when using panel 
detection. If not specified, the command attempts to auto-detect ID variables 
based on common naming patterns.

{phang}
{opt survivalvars(varlist)} specifies variables to consider for survival analysis 
detection. If not specified, the command searches for common time-to-event 
variable naming patterns.

{dlgtab:Data quality}

{phang}
{opt quality} enables basic data quality checks. The command flags potential 
issues such as negative ages, out-of-range percentages, and negative counts.

{phang}
{opt quality2(strict)} enables strict data quality checks with more conservative 
thresholds (e.g., flagging ages over 100 instead of 120).

{phang}
{opt missing(option)} provides detailed missing data analysis. Valid options are:

{phang2}{bf:detail} - show count of variables with >50% and >10% missing, 
plus count of complete cases{p_end}
{phang2}{bf:pattern} - includes detail plus missing data pattern analysis{p_end}

{dlgtab:Sample data}

{phang}
{opt samples(#)} includes the first {it:#} observations in the output as sample 
data. Excluded variables are masked in the output. This helps LLMs understand 
the data structure while protecting individual observations. Use with caution 
as sample data may contain identifiable information.


{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:datamap} is designed for researchers who need to document datasets for sharing,
archiving, or IRB compliance while protecting participant privacy. The command
automatically classifies variables and generates appropriate documentation for each type:

{phang2}{bf:Categorical variables:} Shown with frequency tables and value labels{p_end}
{phang2}{bf:Continuous variables:} Shown with summary statistics (mean, SD, percentiles){p_end}
{phang2}{bf:Date variables:} Shown with date ranges{p_end}
{phang2}{bf:String variables:} Shown with unique value count (values suppressed){p_end}
{phang2}{bf:Excluded variables:} Listed but no values or statistics shown{p_end}

{pstd}
Variable classification is automatic and based on:

{phang2}1. Variables in the {cmd:exclude()} list are classified as "excluded"{p_end}
{phang2}2. String variables (str#) are classified as "string"{p_end}
{phang2}3. Variables with date formats (%t*) are classified as "date"{p_end}
{phang2}4. Numeric variables with value labels or {ul:<} maxcat unique values are "categorical"{p_end}
{phang2}5. All other numeric variables are "continuous"{p_end}

{pstd}
{bf:Detection features:}

{pstd}
The {cmd:detect()} and {cmd:autodetect} options enable automatic detection of 
common data structures:

{phang2}• {bf:Panel data:} Detects repeated observations per unit and reports panel structure{p_end}
{phang2}• {bf:Survival data:} Identifies time-to-event and censoring variables{p_end}
{phang2}• {bf:Survey data:} Detects sampling weights, strata, and cluster variables{p_end}
{phang2}• {bf:Binary outcomes:} Flags variables with exactly 2 unique values{p_end}
{phang2}• {bf:Common patterns:} Identifies IDs, dates, demographics, exposures, and outcomes{p_end}

{pstd}
{bf:Data quality checks:}

{pstd}
The {cmd:quality} option flags potential data quality issues based on variable 
names and values, such as negative ages, out-of-range percentages, or negative 
counts. Use {cmd:quality2(strict)} for more conservative thresholds.

{pstd}
{bf:Multiple input modes:}

{pstd}
You can document datasets in three ways:

{phang2}1. {bf:Single file mode:} Use {cmd:single()} to document one dataset{p_end}
{phang2}2. {bf:Directory mode:} Use {cmd:directory()} to document all .dta files in a folder{p_end}
{phang2}3. {bf:Dataset list mode:} Use {cmd:filelist()} to document a specific list of datasets{p_end}

{pstd}
{bf:Privacy best practices:}

{phang2}• Always use {cmd:exclude()} for direct identifiers (names, IDs, addresses, etc.){p_end}
{phang2}• Use {cmd:datesafe} when documenting datasets with dates of birth or other potentially identifying dates{p_end}
{phang2}• Consider using {cmd:maxfreq()} to limit detail in high-cardinality categorical variables{p_end}
{phang2}• Use {cmd:samples()} with caution and always combine with {cmd:exclude()}{p_end}
{phang2}• Review generated documentation before sharing to ensure no PII is exposed{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Basic usage - document a single dataset{p_end}
{phang2}{cmd:. datamap, single(patients)}{p_end}

{pstd}Document with custom output name{p_end}
{phang2}{cmd:. datamap, single(patients) output(patient_codebook.txt)}{p_end}

{pstd}Document multiple datasets from a list{p_end}
{phang2}{cmd:. datamap, filelist(patients hrt dmt) output(combined.txt)}{p_end}

{pstd}Exclude sensitive variables{p_end}
{phang2}{cmd:. datamap, single(patients) exclude(patient_id patient_name ssn)}{p_end}

{pstd}Use date-safe mode for datasets with dates of birth{p_end}
{phang2}{cmd:. datamap, single(patients) exclude(patient_id patient_name) datesafe}{p_end}

{pstd}Document all datasets in current directory{p_end}
{phang2}{cmd:. datamap, directory(.)}{p_end}

{pstd}Create separate documentation files for each dataset{p_end}
{phang2}{cmd:. datamap, directory(.) separate}{p_end}

{pstd}Suppress statistics and frequencies for minimal documentation{p_end}
{phang2}{cmd:. datamap, single(patients) nostats nofreq}{p_end}

{pstd}Customize categorical threshold{p_end}
{phang2}{cmd:. datamap, single(survey) maxcat(10) maxfreq(10)}{p_end}

{pstd}Combined privacy settings{p_end}
{phang2}{cmd:. datamap, single(patients) exclude(id name dob ssn) datesafe nostats output(safe_docs.txt)}{p_end}

{pstd}Enable panel and survival detection{p_end}
{phang2}{cmd:. datamap, single(cohort) detect(panel survival)}{p_end}

{pstd}Enable all detection features{p_end}
{phang2}{cmd:. datamap, single(survey_data) autodetect}{p_end}

{pstd}Specify panel ID variable{p_end}
{phang2}{cmd:. datamap, single(longitudinal) detect(panel) panelid(patient_id)}{p_end}

{pstd}Enable data quality checks{p_end}
{phang2}{cmd:. datamap, single(clinical) quality}{p_end}

{pstd}Include missing data analysis{p_end}
{phang2}{cmd:. datamap, single(survey) missing(pattern)}{p_end}

{pstd}Include sample observations (use with caution){p_end}
{phang2}{cmd:. datamap, single(demo_data) samples(5) exclude(id name)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datamap} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(nfiles)}}number of datasets documented{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(format)}}output format used (text){p_end}
{synopt:{cmd:r(output)}}name of output file created{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.0.0 - 2025-12-02{p_end}


{title:Also see}

{psee}
{manlink D describe}, {manlink D codebook}, {manlink R summarize}
{p_end}

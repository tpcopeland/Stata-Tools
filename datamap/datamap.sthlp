{smcl}
{* *! version 2.0.0  16nov2025}{...}
{viewerjumpto "Syntax" "datamap##syntax"}{...}
{viewerjumpto "Description" "datamap##description"}{...}
{viewerjumpto "Options" "datamap##options"}{...}
{viewerjumpto "Remarks" "datamap##remarks"}{...}
{viewerjumpto "Examples" "datamap##examples"}{...}
{viewerjumpto "Stored results" "datamap##results"}{...}
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
{synopt:{opt single(filename)}}document a single Stata dataset{p_end}
{synopt:{opt dir:ectory(path)}}document all .dta files in a directory{p_end}
{synopt:{opt filelist(filename)}}document datasets listed in a text file{p_end}

{syntab:Output}
{synopt:{opt output(filename)}}name of output file; default is {bf:datamap.txt}{p_end}
{synopt:{opt format(format)}}output format; only {bf:text} is currently supported{p_end}
{synopt:{opt sep:arate}}create separate output file for each dataset{p_end}
{synopt:{opt app:end}}append to existing output file{p_end}

{syntab:Privacy controls}
{synopt:{opt exclude(varlist)}}exclude specified variables from documentation{p_end}
{synopt:{opt datesafe}}show only date ranges, not individual values{p_end}

{syntab:Content controls}
{synopt:{opt nostats}}suppress summary statistics for continuous variables{p_end}
{synopt:{opt nofreq}}suppress frequency tables for categorical variables{p_end}
{synopt:{opt nolabels}}suppress value label definitions{p_end}
{synopt:{opt nonotes}}suppress dataset notes{p_end}

{syntab:Parameters}
{synopt:{opt maxfreq(#)}}maximum unique values to show frequencies for; default is {bf:25}{p_end}
{synopt:{opt maxcat(#)}}maximum unique values to classify as categorical; default is {bf:25}{p_end}

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
Key features include:

{phang2}1. Automatic variable classification based on type, format, and cardinality{p_end}
{phang2}2. Privacy controls to exclude sensitive variables or limit date precision{p_end}
{phang2}3. Flexible output options (single combined file or separate files per dataset){p_end}
{phang2}4. Support for multiple input modes (single file, directory scan, or file list){p_end}
{phang2}5. Comprehensive documentation including variable types, labels, missing values, and summary statistics{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{opt single(filename)} documents a single Stata dataset file. Specify the path to a .dta file.

{phang}
{opt directory(path)} scans a directory for all .dta files and documents them.
By default, only the specified directory is scanned. Use with {cmd:recursive} to scan subdirectories.

{phang}
{opt filelist(filename)} reads a list of dataset paths from a text file, one per line.
Lines starting with * are treated as comments and ignored. Blank lines are also ignored.

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


{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:datamap} is designed for researchers who need to document datasets for sharing,
archiving, or IRB compliance while protecting participant privacy. The command
automatically classifies variables and generates appropriate documentation for each type:

{phang2}{bf:Categorical variables:} Shown with frequency tables and value labels{p_end}
{phang2}{bf:Continuous variables:} Shown with summary statistics (mean, SD, percentiles){p_end}
{phang2}{bf:Date variables:} Shown with date ranges{p_end}
{phang2}{bf:String variables:} Shown with unique value count and examples (if not excluded){p_end}
{phang2}{bf:Excluded variables:} Listed but no values or statistics shown{p_end}

{pstd}
Variable classification is automatic and based on:

{phang2}1. Variables in the {cmd:exclude()} list are classified as "excluded"{p_end}
{phang2}2. String variables (str#) are classified as "string"{p_end}
{phang2}3. Variables with date formats (%t*) are classified as "date"{p_end}
{phang2}4. Numeric variables with value labels or {ul:<} maxcat unique values are "categorical"{p_end}
{phang2}5. All other numeric variables are "continuous"{p_end}

{pstd}
{bf:Multiple input modes:}

{pstd}
You can document datasets in three ways:

{phang2}1. {bf:Single file mode:} Use {cmd:single()} to document one dataset{p_end}
{phang2}2. {bf:Directory mode:} Use {cmd:directory()} to document all .dta files in a folder{p_end}
{phang2}3. {bf:File list mode:} Use {cmd:filelist()} to document a specific list of datasets{p_end}

{pstd}
{bf:Privacy best practices:}

{phang2}• Always use {cmd:exclude()} for direct identifiers (names, IDs, addresses, etc.){p_end}
{phang2}• Use {cmd:datesafe} when documenting datasets with dates of birth or other potentially identifying dates{p_end}
{phang2}• Consider using {cmd:maxfreq()} to limit detail in high-cardinality categorical variables{p_end}
{phang2}• Review generated documentation before sharing to ensure no PII is exposed{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Basic usage - document a single dataset{p_end}
{phang2}{cmd:. datamap, single(patients.dta)}{p_end}

{pstd}Document with custom output name{p_end}
{phang2}{cmd:. datamap, single(patients.dta) output(patient_codebook.txt)}{p_end}

{pstd}Exclude sensitive variables{p_end}
{phang2}{cmd:. datamap, single(patients.dta) exclude(patient_id patient_name ssn)}{p_end}

{pstd}Use date-safe mode for datasets with dates of birth{p_end}
{phang2}{cmd:. datamap, single(patients.dta) exclude(patient_id patient_name) datesafe}{p_end}

{pstd}Document all datasets in current directory{p_end}
{phang2}{cmd:. datamap, directory(.)}{p_end}

{pstd}Create separate documentation files for each dataset{p_end}
{phang2}{cmd:. datamap, directory(.) separate}{p_end}

{pstd}Document datasets listed in a file{p_end}
{phang2}{cmd:. datamap, filelist(datasets.txt)}{p_end}

{pstd}Suppress statistics and frequencies for minimal documentation{p_end}
{phang2}{cmd:. datamap, single(patients.dta) nostats nofreq}{p_end}

{pstd}Customize categorical threshold{p_end}
{phang2}{cmd:. datamap, single(survey.dta) maxcat(10) maxfreq(10)}{p_end}

{pstd}Combined privacy settings{p_end}
{phang2}{cmd:. datamap, single(patients.dta) exclude(id name dob ssn) datesafe nostats output(safe_docs.txt)}{p_end}


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

{pstd}Version 2.0.0 - 16 November 2025{p_end}


{title:Also see}

{psee}
Manual: {manlink D describe}, {manlink D codebook}, {manlink R summarize}
{p_end}

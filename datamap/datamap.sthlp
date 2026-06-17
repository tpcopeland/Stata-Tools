{smcl}
{* *! version 1.3.0  17jun2026}{...}
{vieweralsosee "[D] describe" "help describe"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[R] summarize" "help summarize"}{...}
{vieweralsosee "datadict" "help datadict"}{...}
{viewerjumpto "Syntax" "datamap##syntax"}{...}
{viewerjumpto "Description" "datamap##description"}{...}
{viewerjumpto "Options" "datamap##options"}{...}
{viewerjumpto "Variable classification" "datamap##classification"}{...}
{viewerjumpto "Remarks" "datamap##remarks"}{...}
{viewerjumpto "Examples" "datamap##examples"}{...}
{viewerjumpto "Stored results" "datamap##results"}{...}
{viewerjumpto "Author" "datamap##author"}{...}

{title:Title}

{phang}
{bf:datamap} {hline 2} Generate privacy-safe dataset documentation for LLM-assisted coding


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datamap}
[{cmd:,}
{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input {it:(choose at most one; default is data in memory)}}
{synopt:{opt single(filename)}}document one {opt .dta} file{p_end}
{synopt:{opt dir:ectory(path)}}document every {opt .dta} file in {it:path}{p_end}
{synopt:{opt file:list(names)}}space-separated dataset names to document{p_end}
{synopt:{opt rec:ursive}}with {opt directory()}, also scan subdirectories{p_end}

{syntab:Output}
{synopt:{opt o:utput(filename)}}output file name; default is {bf:datamap.txt} or {bf:datamap.json}{p_end}
{synopt:{opt f:ormat(string)}}output format: {bf:text} or {bf:json}{p_end}
{synopt:{opt sep:arate}}write a separate file per dataset{p_end}
{synopt:{opt app:end}}append to an existing output file{p_end}

{syntab:Content control}
{synopt:{opt nost:ats}}suppress summary statistics for continuous variables{p_end}
{synopt:{opt nofr:eq}}suppress frequency tables for categorical variables{p_end}
{synopt:{opt nola:bels}}suppress the value-label definitions section{p_end}
{synopt:{opt maxf:req(#)}}max unique values to tabulate; default {bf:25}{p_end}
{synopt:{opt maxc:at(#)}}max unique values to treat as categorical; default {bf:25}{p_end}
{synopt:{opt minc:ell(#)}}suppress frequency cells smaller than {it:#}; default {bf:5}; {bf:0} disables{p_end}
{synopt:{opt nog:uidance}}suppress ANALYSIS GUIDANCE prose{p_end}
{synopt:{opt com:pact}}write a token-compact map; implies {opt noguidance}{p_end}

{syntab:Privacy}
{synopt:{opt exc:lude(varlist)}}variables to document structure only (no values/stats){p_end}
{synopt:{opt dates:afe}}show date-range span only, not exact dates{p_end}
{synopt:{opt datef:ormat(string)}}date display format; default {bf:%tdCCYY/NN/DD}{p_end}

{syntab:Detection}
{synopt:{opt det:ect(options)}}enable specific structure detectors{p_end}
{synopt:{opt autodet:ect}}enable all detectors at once{p_end}
{synopt:{opt panel:id(varname)}}specify the panel identifier for panel detection{p_end}
{synopt:{opt survival:vars(varlist)}}specify survival-analysis variables{p_end}

{syntab:Data quality}
{synopt:{opt qu:ality}}flag basic data quality issues{p_end}
{synopt:{opt qu:ality2(strict)}}flag quality issues with stricter thresholds{p_end}
{synopt:{opt miss:ing(option)}}missing-data summary; {bf:detail} or {bf:pattern}{p_end}

{syntab:Sample data}
{synopt:{opt sam:ples(#)}}include the first {it:#} observations in the output{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
The {opt .dta} extension is optional everywhere and is added automatically when
omitted.


{marker description}{...}
{title:Description}

{pstd}
{cmd:datamap} writes a structured description of one or more Stata datasets in
plain text or JSON.  Text output is designed to be pasted into an LLM prompt
window.  JSON output is designed for automated pipelines and programmatic
metadata checks.

{pstd}
The command automatically classifies every variable as categorical, continuous,
date, string, or excluded, and then writes the section that fits: frequency
tables for categorical variables, summary statistics for continuous variables,
date ranges for date variables, and a length/uniqueness note for strings.
Variables listed in {opt exclude()} appear in the output with their type and
missingness but no values or statistics.

{pstd}
Default output is aggregate-level.  Frequency cells smaller than {opt mincell()}
are suppressed by default.  No cross-variable combinations or individual
observations are exported unless you explicitly request sample rows with
{opt samples()}.

{pstd}
The current dataset in memory is preserved and restored after processing.

{pstd}
For a companion command that produces Markdown data dictionaries suitable for
GitHub, documentation sites, or conversion to PDF/Word via Pandoc, see
{help datadict}.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{pstd}
If no input option is specified, {cmd:datamap} documents the data currently in
memory.  This is the simplest way to use the command: load or prepare your data,
then type {cmd:datamap}.

{phang}
{opt single(filename)} documents one Stata dataset file.  If the file is not in
the current directory, include the full or relative path.

{phang}
{opt dir:ectory(path)} scans a directory for every {opt .dta} file and documents
all of them.  Only the specified directory is scanned unless {opt recursive} is
also specified.

{phang}
{opt file:list(names)} documents a specific set of datasets given as a
space-separated list.  For example, {cmd:filelist(patients hrt dmt)} documents
{it:patients.dta}, {it:hrt.dta}, and {it:dmt.dta}.

{phang}
{opt rec:ursive} makes {opt directory()} also descend into subdirectories.
Hidden directories (names beginning with {cmd:.}) and {cmd:__pycache__} are
always skipped.

{pstd}
Only one of {opt single()}, {opt directory()}, or {opt filelist()} may be
specified.  Specifying more than one is an error.

{dlgtab:Output}

{phang}
{opt o:utput(filename)} names the output file.  The default is {bf:datamap.txt}
for text output and {bf:datamap.json} for JSON output.

{phang}
{opt f:ormat(string)} selects the output format.  Valid values are {bf:text}
and {bf:json}.  JSON output includes dataset metadata, privacy settings, class
counts, per-variable metadata, continuous summaries, and suppressed frequency
arrays.  For Markdown output, use {help datadict} instead.

{phang}
{opt sep:arate} writes a separate output file for each dataset instead of
combining them into one file.  Output files are named
{it:datasetname}{cmd:_map.txt}.

{phang}
{opt app:end} appends to an existing output file rather than replacing it.
Useful for incrementally building documentation.  Note that no header is added
when appending.  {opt append} is not allowed with {cmd:format(json)}.

{dlgtab:Content control}

{phang}
{opt nost:ats} suppresses summary statistics (mean, SD, median, IQR, range) for
continuous variables.  The variables still appear with their basic properties.

{phang}
{opt nofr:eq} suppresses frequency tables for categorical variables.  Variables
are still listed and classified.

{phang}
{opt nola:bels} suppresses the "Value Label Definitions" section at the end of
each dataset.  Value labels attached to individual variables in the frequency
table are unaffected.

{phang}
{opt maxf:req(#)} sets the maximum number of unique values for which a frequency
table is printed.  Categorical variables with more unique values than this
threshold show only the unique count.  Default is {bf:25}.  Must be positive.

{phang}
{opt maxc:at(#)} sets the cutoff that separates categorical from continuous.
Numeric variables with value labels or with {it:#} or fewer unique values are
classified as categorical; the rest are continuous.  Default is {bf:25}.  Must
be positive.

{phang}
{opt minc:ell(#)} suppresses categorical and binary frequency cells with counts
smaller than {it:#}.  Suppressed text output shows {bf:suppressed (<#)}; JSON
sets the count and percent to {bf:null} and marks {bf:suppressed: true}.  The
default is {bf:5}.  Specify {cmd:mincell(0)} to show all cells.

{phang}
{opt nog:uidance} removes the ANALYSIS GUIDANCE and privacy-note prose while
leaving statistics, frequency tables, and metadata in place.

{phang}
{opt com:pact} writes a shorter text map containing dataset metadata,
disclosure-risk summary, description, and the quick-reference variable table.
It implies {opt noguidance}.  JSON output is already structured and ignores this
text-only shortening.

{dlgtab:Privacy}

{phang}
{opt exc:lude(varlist)} lists variables whose values should not appear in the
output.  They are documented with type and missingness only, classified as
"excluded".  Use this for personally identifiable information such as names,
national IDs, and addresses.  Variable names that do not exist in a given
dataset are silently ignored.  Wildcard expansion is not supported; list each
variable name explicitly.

{phang}
{opt dates:afe} prevents exact dates from appearing in the output.  Date
variables are documented with the number of time units spanned instead of the
earliest and latest values.  Use this when dates of birth or other potentially
identifying dates are present.

{phang}
{opt datef:ormat(string)} sets the Stata date format used to display all dates.
The default is {bf:%tdCCYY/NN/DD} (ISO 8601).  For datetime variables
({cmd:%tc}/{cmd:%tC}), the prefix is automatically adapted.  Weekly, monthly,
quarterly, and other non-daily types retain their native format regardless of
this setting.  The format must begin with {cmd:%t} or {cmd:%d}.

{dlgtab:Detection}

{phang}
{opt det:ect(options)} turns on specific automatic structure detectors.  Specify
one or more of the following, separated by spaces:

{phang2}{bf:panel} {hline 2} look for repeated observations per unit (longitudinal/panel data).{p_end}
{phang2}{bf:binary} {hline 2} flag variables with exactly two unique values as potential outcomes or indicators.{p_end}
{phang2}{bf:survival} {hline 2} search for time-to-event and censoring/event variables.{p_end}
{phang2}{bf:survey} {hline 2} search for sampling weights, strata, and cluster/PSU variables.{p_end}
{phang2}{bf:common} {hline 2} identify IDs, dates, demographics, exposures, and outcomes by name patterns.{p_end}

{pmore}
Example: {cmd:detect(panel survival)} enables panel and survival detection only.

{phang}
{opt autodet:ect} enables every detector at once (equivalent to specifying all
five keywords in {opt detect()}).

{phang}
{opt panel:id(varname)} tells the panel detector which variable identifies
units.  If omitted, the detector searches for variables whose names match common
ID patterns ({it:*id}, {it:patient*}, {it:subject*}, etc.).

{phang}
{opt survival:vars(varlist)} tells the survival detector which variables to
consider.  If omitted, the detector searches for common time-to-event naming
patterns ({it:time*}, {it:event*}, {it:death*}, etc.).

{dlgtab:Data quality}

{phang}
{opt qu:ality} enables basic data quality flags.  The command checks for
negative ages, negative counts, and percentages outside 0-100.  Flags are
printed in a "Data Quality Flags" section.

{phang}
{opt qu:ality2(strict)} enables stricter quality checks.  Thresholds are more
conservative; for example, ages above 100 are flagged (the basic mode flags ages
above 120).

{phang}
{opt miss:ing(option)} adds a missing-data summary section.  Valid values are:

{phang2}{bf:detail} {hline 2} report the number of variables with >50% and >10% missing, plus the number of complete-case observations.{p_end}
{phang2}{bf:pattern} {hline 2} everything in {bf:detail}, plus the same pattern analysis.{p_end}

{dlgtab:Sample data}

{phang}
{opt sam:ples(#)} appends a table of the first {it:#} observations.  Variables
in {opt exclude()} are shown as {bf:[MASKED]}.  When {opt datesafe} is also
specified, date variables in the sample table are shown as
{bf:[DATE SUPPRESSED]}.  Use with caution: even aggregate-safe documentation
becomes identifiable once raw rows are included.  Always combine with
{opt exclude()} when sample rows are enabled.


{marker classification}{...}
{title:Variable classification}

{pstd}
{cmd:datamap} classifies every variable using the following priority order:

{phang2}1. Variables listed in {opt exclude()} are classified as {bf:excluded}.{p_end}
{phang2}2. String variables ({cmd:str}{it:#} or {cmd:strL}) are classified as {bf:string}.{p_end}
{phang2}3. Variables whose display format starts with {cmd:%t} or {cmd:%d} are classified as {bf:date}.{p_end}
{phang2}4. Numeric variables with an attached value label, or with {opt maxcat()} or fewer unique values, are classified as {bf:categorical}.{p_end}
{phang2}5. All remaining numeric variables are classified as {bf:continuous}.{p_end}

{pstd}
Each class gets a dedicated output section:

{p2colset 5 28 30 2}{...}
{p2col:{bf:Categorical}}frequency table with counts and percentages; small cells suppressed by {opt mincell()} and tables suppressed by {opt nofreq}{p_end}
{p2col:{bf:Continuous}}mean, SD, median, IQR, range (suppressed by {opt nostats}){p_end}
{p2col:{bf:Date}}earliest/latest date and span (exact dates suppressed by {opt datesafe}){p_end}
{p2col:{bf:String}}maximum string length and unique-value count; values are always suppressed{p_end}
{p2col:{bf:Excluded}}type and missingness only; no values or statistics{p_end}
{p2colreset}{...}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to use datamap vs. datadict}

{pstd}
Use {cmd:datamap} when you need a plain-text file to paste into an LLM chat
window, attach to an internal data handoff, or feed into an automated pipeline.
Use {help datadict} when you need a polished Markdown document for a GitHub
repository, an appendix, or conversion to PDF/Word via Pandoc.  Both commands
accept the same input modes and preserve the dataset in memory.

{pstd}
{bf:Privacy best practices}

{phang2}{hline 2} Always use {opt exclude()} for direct identifiers: names, national IDs, addresses, phone numbers.{p_end}
{phang2}{hline 2} Add {opt datesafe} when the dataset contains dates of birth, death dates, or admission dates that could help re-identify individuals.{p_end}
{phang2}{hline 2} Keep the default {cmd:mincell(5)} unless you have reviewed the disclosure risk.{p_end}
{phang2}{hline 2} Use {opt samples()} sparingly and always combine it with {opt exclude()} and {opt datesafe} when date variables are sensitive.{p_end}
{phang2}{hline 2} Review the output file before sharing to confirm that no personally identifiable information leaked through.{p_end}

{pstd}
{cmd:datamap} also warns when variable names look like identifiers but are not
listed in {opt exclude()}.  The same count and suggested list appear in the
disclosure-risk summary and in JSON privacy metadata.

{pstd}
{bf:Input modes}

{pstd}
{cmd:datamap} supports four input modes:

{phang2}1. {bf:Data in memory} (default){hline 2} just run {cmd:datamap} after loading your data.{p_end}
{phang2}2. {bf:Single file}{hline 2} use {opt single(filename)} to document one {opt .dta} file without loading it first.{p_end}
{phang2}3. {bf:Directory scan}{hline 2} use {opt directory(path)} to document every {opt .dta} file in a folder. Add {opt recursive} to include subdirectories.{p_end}
{phang2}4. {bf:File list}{hline 2} use {opt filelist(names)} to document a hand-picked set of datasets.{p_end}


{marker examples}{...}
{title:Examples}

    {title:Getting started}

{pstd}
The simplest way to use {cmd:datamap} is to load a dataset and run the command
with no options.  The output is written to {bf:datamap.txt} in the current
directory.{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datamap}{p_end}

{pstd}
To give the output a different name:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datamap, output(auto_codebook.txt)}{p_end}

{pstd}
To write machine-readable JSON:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datamap, format(json) output(auto_map.json)}{p_end}

    {title:Privacy controls}

{pstd}
Exclude sensitive variables and suppress exact dates in one step:{p_end}

{phang2}{cmd:. datamap, single(patients) exclude(patient_id ssn patient_name) datesafe}{p_end}

{pstd}
For a minimal output that shows only structure and classification:{p_end}

{phang2}{cmd:. datamap, single(patients) exclude(patient_id ssn) compact}{p_end}

    {title:Detection and quality}

{pstd}
Turn on all automatic structure detectors:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datamap, autodetect output(auto_detected.txt)}{p_end}

{pstd}
Detect panel structure with an explicit ID variable:{p_end}

{phang2}{cmd:. datamap, single(longitudinal) detect(panel) panelid(patient_id)}{p_end}

{pstd}
Enable quality checks and missing-data pattern analysis:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datamap, quality missing(pattern) output(auto_quality.txt)}{p_end}

    {title:Multiple datasets}

{pstd}
Document every {opt .dta} file in a directory:{p_end}

{phang2}{cmd:. datamap, directory(.) output(project_map.txt)}{p_end}

{pstd}
Write a separate output file per dataset:{p_end}

{phang2}{cmd:. datamap, directory(.) separate}{p_end}

{pstd}
Document a specific set of files:{p_end}

{phang2}{cmd:. datamap, filelist(patients labs visits) output(combined.txt)}{p_end}

    {title:Tuning the output}

{pstd}
Change the categorical threshold so that only variables with 10 or fewer unique
values are treated as categorical:{p_end}

{phang2}{cmd:. datamap, single(survey) maxcat(10) maxfreq(10)}{p_end}

{pstd}
Disable small-cell suppression only after disclosure review:{p_end}

{phang2}{cmd:. datamap, single(survey) mincell(0)}{p_end}

{pstd}
Include sample observations (use with caution):{p_end}

{phang2}{cmd:. datamap, single(demo_data) samples(5) exclude(id name)}{p_end}

    {title:Full privacy-controlled workflow}

{pstd}
Combine multiple privacy and content options:{p_end}

{phang2}{cmd:. datamap, single(clinical_trial) ///}{p_end}
{phang2}{cmd:     exclude(patient_id birth_date death_date) ///}{p_end}
{phang2}{cmd:     datesafe nostats ///}{p_end}
{phang2}{cmd:     quality missing(detail) ///}{p_end}
{phang2}{cmd:     output(safe_documentation.txt)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datamap} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
	{synopt:{cmd:r(nfiles)}}number of datasets documented{p_end}
	{synopt:{cmd:r(nobs)}}number of observations (single-file and in-memory modes only){p_end}
	{synopt:{cmd:r(nvars)}}number of variables (single-file and in-memory modes only){p_end}
	{synopt:{cmd:r(mincell)}}small-cell threshold used{p_end}
	{synopt:{cmd:r(n_categorical)}}number of categorical variables documented{p_end}
	{synopt:{cmd:r(n_continuous)}}number of continuous variables documented{p_end}
	{synopt:{cmd:r(n_date)}}number of date variables documented{p_end}
	{synopt:{cmd:r(n_string)}}number of string variables documented{p_end}
	{synopt:{cmd:r(n_excluded)}}number of variables excluded by {opt exclude()}{p_end}
	{synopt:{cmd:r(n_suggested_exclude)}}number of likely identifier variables not excluded{p_end}
	{synoptline}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(format)}}output format used ({bf:text} or {bf:json}){p_end}
{synopt:{cmd:r(output)}}name of the output file created{p_end}
{synopt:{cmd:r(input_source)}}input mode: {bf:memory}, {bf:single}, {bf:directory}, or {bf:filelist}{p_end}
{synopt:{cmd:r(categorical_vars)}}categorical variable names{p_end}
{synopt:{cmd:r(continuous_vars)}}continuous variable names{p_end}
{synopt:{cmd:r(date_vars)}}date variable names{p_end}
{synopt:{cmd:r(string_vars)}}string variable names{p_end}
{synopt:{cmd:r(excluded_vars)}}excluded variable names{p_end}
{synopt:{cmd:r(suggested_exclude)}}likely identifier variables not listed in {opt exclude()}{p_end}
{synoptline}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.3.0 {hline 2} 17jun2026{p_end}


{title:Also see}

{psee}
{help datadict}, {manlink D describe}, {manlink D codebook}, {manlink R summarize}
{p_end}

{hline}

{smcl}
{* *! version 1.0.0  17nov2025}{...}
{viewerjumpto "Syntax" "datadict##syntax"}{...}
{viewerjumpto "Description" "datadict##description"}{...}
{viewerjumpto "Options" "datadict##options"}{...}
{viewerjumpto "Remarks" "datadict##remarks"}{...}
{viewerjumpto "Examples" "datadict##examples"}{...}
{viewerjumpto "Stored results" "datadict##results"}{...}
{title:Title}

{phang}
{bf:datadict} {hline 2} Generate professional Markdown data dictionaries


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datadict}
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
{synopt:{opt output(filename)}}name of output file; default is {bf:data_dictionary.md}{p_end}
{synopt:{opt sep:arate}}create separate output file for each dataset{p_end}
{synopt:{opt app:end}}append to existing output file{p_end}

{syntab:Documentation}
{synopt:{opt title(string)}}document title; default is {bf:"Data Dictionary"}{p_end}
{synopt:{opt ver:sion(string)}}version number for the documentation{p_end}
{synopt:{opt auth:ors(string)}}author names for the documentation{p_end}
{synopt:{opt toc}}include a table of contents with anchor links{p_end}

{syntab:Privacy controls}
{synopt:{opt exclude(varlist)}}exclude specified variables from detailed documentation{p_end}
{synopt:{opt datesafe}}show only date ranges, not individual values{p_end}

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
{cmd:datadict} generates professional, human-readable Markdown data dictionaries from Stata datasets.
The output is designed for documentation, version control, and sharing with collaborators. Markdown files
can be viewed in any text editor, rendered beautifully in GitHub/VSCode, and converted to HTML or DOCX
using Stata's {cmd:dyndoc} command.

{pstd}
Key features include:

{phang2}1. Clean Markdown formatting with tables and proper headers{p_end}
{phang2}2. Automatic variable grouping (identifiers, demographics, categorical, continuous, dates, strings){p_end}
{phang2}3. Frequency tables for categorical variables with value labels{p_end}
{phang2}4. Summary statistics tables for continuous variables{p_end}
{phang2}5. Value label definitions section{p_end}
{phang2}6. Data quality notes and missing data summary{p_end}
{phang2}7. Optional table of contents with anchor links{p_end}
{phang2}8. Privacy controls to exclude sensitive variables{p_end}

{pstd}
The generated Markdown files are perfect for:

{phang2}• Version control (Git-friendly text format){p_end}
{phang2}• IRB submissions and data sharing agreements{p_end}
{phang2}• Project documentation and codebooks{p_end}
{phang2}• Publication supplements{p_end}
{phang2}• Team collaboration (readable in GitHub/GitLab){p_end}


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
{opt output(filename)} specifies the name of the output Markdown file. Default is {bf:data_dictionary.md}.
The file should have a .md extension.

{phang}
{opt separate} creates a separate output file for each dataset instead of combining
all documentation into a single file. Output files are named {it:datasetname}_dictionary.md.

{phang}
{opt append} appends documentation to an existing output file instead of replacing it.
Useful for incrementally building documentation.

{dlgtab:Documentation}

{phang}
{opt title(string)} specifies the document title that appears at the top of the Markdown file.
Default is {bf:"Data Dictionary"}. This should be a descriptive title for your documentation.

{phang}
{opt version(string)} specifies a version number for the documentation (e.g., "1.0.0", "2023-Q4").
If specified, it appears in the document header.

{phang}
{opt authors(string)} specifies author names for the documentation (e.g., "John Doe, Jane Smith").
If specified, it appears in the document header.

{phang}
{opt toc} includes a table of contents section with anchor links to all major sections.
Highly recommended for long documents or multi-dataset documentation.

{dlgtab:Privacy controls}

{phang}
{opt exclude(varlist)} excludes the specified variables from detailed documentation.
Use this to protect personally identifiable information (PII) such as names, IDs,
or other sensitive variables. Excluded variables appear in the variable summary table
with classification "excluded" but are documented in a separate section with no statistics.

{phang}
{opt datesafe} restricts date variable documentation to show only the range
(minimum and maximum) instead of individual values. This helps prevent date-based reidentification.

{dlgtab:Parameters}

{phang}
{opt maxfreq(#)} specifies the maximum number of unique values for which
frequency tables will be shown. If a categorical variable has more than this
many unique values, frequencies are suppressed and a note is added. Default is {bf:25}. Must be positive.

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
{cmd:datadict} complements the {cmd:datamap} command by generating human-readable documentation
in Markdown format. While {cmd:datamap} creates LLM-optimized text output designed for AI context windows,
{cmd:datadict} creates professional documentation designed for humans.

{pstd}
{bf:Variable Classification and Grouping}

{pstd}
Variables are automatically classified and grouped into semantic categories:

{phang2}{bf:Identifiers:} Variables with "id" in the name (case-insensitive){p_end}
{phang2}{bf:Demographics:} Variables like age, sex, gender, race, ethnicity, etc.{p_end}
{phang2}{bf:Categorical:} Numeric variables with value labels or few unique values{p_end}
{phang2}{bf:Continuous:} Numeric variables with many unique values{p_end}
{phang2}{bf:Date:} Variables with date/time formats (%t*){p_end}
{phang2}{bf:String:} String variables (str#){p_end}
{phang2}{bf:Excluded:} Variables in the exclude() list{p_end}

{pstd}
{bf:Output Format}

{pstd}
The generated Markdown file includes:

{phang2}1. {bf:Document header} with title, version, authors, and date{p_end}
{phang2}2. {bf:Table of contents} (if requested){p_end}
{phang2}3. {bf:Dataset information table} with obs, variables, label, signature{p_end}
{phang2}4. {bf:Variable summary table} listing all variables{p_end}
{phang2}5. {bf:Detailed variable sections} grouped by category with:{p_end}
{phang3}• Frequency tables for categorical variables{p_end}
{phang3}• Summary statistics tables for continuous variables{p_end}
{phang3}• Date ranges for date variables{p_end}
{phang3}• Properties for string variables{p_end}
{phang2}6. {bf:Value label definitions} for all labeled variables{p_end}
{phang2}7. {bf:Data quality notes} with missing data summary{p_end}

{pstd}
{bf:Converting to HTML or DOCX}

{pstd}
Use Stata's {cmd:dyndoc} command (Stata 15+) to convert Markdown to other formats:

{phang2}Convert to HTML: {cmd:dyndoc dictionary.md, replace}{p_end}
{phang2}Convert to DOCX: {cmd:dyndoc dictionary.md, replace docx} (Stata 16+){p_end}

{pstd}
Alternatively, use external tools like Pandoc:

{phang2}{cmd:! pandoc dictionary.md -o dictionary.html}{p_end}
{phang2}{cmd:! pandoc dictionary.md -o dictionary.pdf}{p_end}

{pstd}
{bf:Version Control}

{pstd}
Markdown format is ideal for version control systems (Git):

{phang2}• Text-based format allows easy diff comparison{p_end}
{phang2}• Track changes to data structure over time{p_end}
{phang2}• Renders beautifully in GitHub, GitLab, Bitbucket{p_end}
{phang2}• Can be reviewed in pull requests{p_end}

{pstd}
{bf:Privacy Best Practices}

{phang2}• Always use {cmd:exclude()} for direct identifiers{p_end}
{phang2}• Use {cmd:datesafe} for datasets with dates of birth{p_end}
{phang2}• Review output before committing to public repositories{p_end}
{phang2}• Consider {cmd:maxfreq()} for high-cardinality variables{p_end}

{pstd}
{bf:Comparison with datamap}

{pstd}
{cmd:datadict} and {cmd:datamap} serve different purposes:

{phang2}{cmd:datamap}: LLM-optimized text output for AI consumption{p_end}
{phang2}{cmd:datadict}: Professional Markdown for human documentation{p_end}

{pstd}
Use both commands together for comprehensive documentation:

{phang2}{cmd:. datamap, single(data.dta) output(llm_context.txt)}{p_end}
{phang2}{cmd:. datadict, single(data.dta) output(dictionary.md) toc}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Basic usage - document a single dataset{p_end}
{phang2}{cmd:. datadict, single(patients.dta)}{p_end}

{pstd}Full documentation with metadata{p_end}
{phang2}{cmd:. datadict, single(patients.dta) output(patient_dict.md) title("Patient Registry Data Dictionary") version("2.0.0") authors("Research Team") toc}{p_end}

{pstd}Exclude sensitive variables{p_end}
{phang2}{cmd:. datadict, single(patients.dta) exclude(patient_id ssn name address)}{p_end}

{pstd}Privacy-safe documentation{p_end}
{phang2}{cmd:. datadict, single(patients.dta) exclude(patient_id ssn) datesafe}{p_end}

{pstd}Document all datasets in current directory{p_end}
{phang2}{cmd:. datadict, directory(.) toc}{p_end}

{pstd}Create separate files for each dataset{p_end}
{phang2}{cmd:. datadict, directory(.) separate toc}{p_end}

{pstd}Document datasets from a list{p_end}
{phang2}{cmd:. datadict, filelist(datasets.txt) output(complete_dict.md)}{p_end}

{pstd}Complete workflow with HTML conversion{p_end}
{phang2}{cmd:. datadict, single(study_data.dta) title("Study Data Dictionary v1.0") version("1.0") authors("PI Name") toc output(dictionary.md)}{p_end}
{phang2}{cmd:. dyndoc dictionary.md, replace}{p_end}

{pstd}For version control{p_end}
{phang2}{cmd:. datadict, single(data.dta) output(docs/dictionary.md) toc}{p_end}
{phang2}{cmd:. ! git add docs/dictionary.md}{p_end}
{phang2}{cmd:. ! git commit -m "Update data dictionary"}{p_end}

{pstd}Multi-dataset project{p_end}
{phang2}{cmd:. file open fh using datasets.txt, write text replace}{p_end}
{phang2}{cmd:. file write fh "data/baseline.dta" _n}{p_end}
{phang2}{cmd:. file write fh "data/followup.dta" _n}{p_end}
{phang2}{cmd:. file write fh "data/outcomes.dta" _n}{p_end}
{phang2}{cmd:. file close fh}{p_end}
{phang2}{cmd:. datadict, filelist(datasets.txt) output(project_dict.md) title("Study Project Data Dictionary") toc}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datadict} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(nfiles)}}number of datasets documented{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(output)}}name of output file created{p_end}


{title:Technical Notes}

{pstd}
{cmd:datadict} uses only Stata native capabilities:

{phang2}• {cmd:file write} for Markdown output{p_end}
{phang2}• {cmd:describe} for dataset metadata{p_end}
{phang2}• {cmd:summarize} for statistics{p_end}
{phang2}• {cmd:tabulate} for frequencies{p_end}
{phang2}• {cmd:datasignature} for checksums{p_end}
{phang2}• Extended macro functions{p_end}

{pstd}
No external dependencies are required. The command works with Stata 14.0 or higher.


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.0.0 - 14 November 2025{p_end}


{title:Also see}

{psee}
Help: {help datamap}, {help dyndoc}{break}
Manual: {manlink D describe}, {manlink D codebook}
{p_end}

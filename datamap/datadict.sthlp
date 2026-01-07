{smcl}
{* *! version 1.0.2  07jan2026}{...}
{vieweralsosee "[D] describe" "help describe"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[D] labelbook" "help labelbook"}{...}
{viewerjumpto "Syntax" "datadict##syntax"}{...}
{viewerjumpto "Description" "datadict##description"}{...}
{viewerjumpto "Options" "datadict##options"}{...}
{viewerjumpto "Examples" "datadict##examples"}{...}
{viewerjumpto "Stored results" "datadict##results"}{...}
{viewerjumpto "Author" "datadict##author"}{...}
{title:Title}

{phang}
{bf:datadict} {hline 2} Generate Markdown data dictionaries from Stata datasets


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:datadict}
{cmd:,}
{it:input_option}
[{it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input (choose one)}
{synopt:{opt single(dataset)}}document a single dataset{p_end}
{synopt:{opt dir:ectory(path)}}document all .dta files in directory{p_end}
{synopt:{opt filelist(datasets)}}space-separated list of dataset names to process{p_end}
{synopt:{opt rec:ursive}}scan subdirectories when using {opt directory()}{p_end}

{syntab:Output}
{synopt:{opt output(filename)}}output markdown file; default is {bf:data_dictionary.md}{p_end}
{synopt:{opt sep:arate}}create separate output file per dataset{p_end}

{syntab:Document metadata}
{synopt:{opt title(string)}}document title; default is {bf:Data Dictionary}{p_end}
{synopt:{opt sub:title(string)}}subtitle or description line{p_end}
{synopt:{opt ver:sion(string)}}version number for documentation{p_end}
{synopt:{opt auth:or(string)}}author name (can include markdown links){p_end}
{synopt:{opt date(string)}}date string; default is current date{p_end}

{syntab:Content}
{synopt:{opt notes(filename)}}path to text file with notes to append{p_end}
{synopt:{opt changelog(filename)}}path to text file with changelog to append{p_end}
{synopt:{opt miss:ing}}include missing n (%) column for each variable{p_end}
{synopt:{opt stats}}include descriptive statistics column for each variable{p_end}
{synopt:{opt maxcat(#)}}max unique values to classify as categorical; default is {bf:25}{p_end}
{synopt:{opt maxfreq(#)}}max unique values to show frequencies for; default is {bf:25}{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:datadict} generates professional Markdown data dictionaries from Stata 
datasets. The output includes a table of contents, dataset metadata, and 
variable tables showing Variable, Label, Type, and Values/Notes columns.

{pstd}
The command automatically extracts variable labels, identifies variable types 
(Numeric, String, Date), and formats value labels for categorical variables.
For variables with more than {opt maxfreq()} unique values, it displays a count 
rather than listing all values.

{pstd}
The {opt .dta} extension is optional and assumed if not specified.

{pstd}
The generated Markdown files are suitable for rendering in documentation 
systems, GitHub, or conversion to other formats via tools like Pandoc.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{opt single(dataset)} specifies a single dataset to document. The {opt .dta} 
extension is optional and will be added automatically if not specified. 
The file must exist and be a valid Stata dataset.

{phang}
{opt directory(path)} specifies a directory containing .dta files. All 
datasets in the directory will be documented in a single output file (unless 
{opt separate} is specified). If no path is given, the current working 
directory is used.

{phang}
{opt filelist(datasets)} specifies a space-separated list of dataset names 
to process. The {opt .dta} extension is optional for each dataset name.

{pmore}
Example: {cmd:filelist(patients hrt dmt)} will process {it:patients.dta}, 
{it:hrt.dta}, and {it:dmt.dta}.

{phang}
{opt recursive} causes {cmd:datadict} to scan subdirectories recursively when 
used with {opt directory()}. Hidden directories (beginning with .) and 
__pycache__ directories are skipped.

{dlgtab:Output}

{phang}
{opt output(filename)} specifies the name of the output markdown file. The 
default is {bf:data_dictionary.md}. When {opt separate} is specified, this 
option is ignored and each dataset produces its own file named 
{it:datasetname}_dictionary.md.

{phang}
{opt separate} creates a separate markdown file for each dataset instead of 
combining all datasets into a single document.

{dlgtab:Document metadata}

{phang}
{opt title(string)} specifies the document title appearing at the top of the 
output. The default is "Data Dictionary".

{phang}
{opt subtitle(string)} specifies an optional subtitle or description line 
appearing below the title.

{phang}
{opt version(string)} specifies a version number for the documentation, 
displayed in the header and footer.

{phang}
{opt author(string)} specifies the author name to appear in the footer. 
Markdown formatting (e.g., links) is preserved.

{phang}
{opt date(string)} specifies the date string. The default is the current date.

{dlgtab:Content}

{phang}
{opt notes(filename)} specifies a text file containing notes to include in 
the Notes section. If not specified, default notes about date formats and 
missing values are included.

{phang}
{opt changelog(filename)} specifies a text file containing changelog entries 
to include in the Change Log section.

{phang}
{opt missing} adds a "Missing" column to the variable table showing the count 
and percentage of missing values for each variable.

{phang}
{opt stats} adds descriptive statistics to the Values/Notes column. The type 
of statistics shown depends on the variable classification:

{pmore}
{bf:Categorical variables:} Value frequencies (e.g., "1=Male, 2=Female")

{pmore}
{bf:Continuous variables:} Mean, SD, and range (e.g., "Mean=45.2; SD=12.3; Range=18-89")

{pmore}
{bf:Date variables:} Date range (e.g., "Range: 01jan2020 to 31dec2023")

{pmore}
{bf:String variables:} Count of unique values

{phang}
{opt maxcat(#)} specifies the threshold for classifying numeric variables 
as categorical versus continuous. Numeric variables with {it:#} or fewer unique values 
(or with value labels) are classified as categorical. Default is {bf:25}. Must be positive.

{phang}
{opt maxfreq(#)} specifies the maximum number of unique values for which 
individual values will be shown. If a categorical variable has more than this 
many unique values, only a count is shown. Default is {bf:25}. Must be positive.


{marker examples}{...}
{title:Examples}

{pstd}Document a single dataset with default settings:{p_end}
{phang2}{cmd:. datadict, single(patients)}{p_end}

{pstd}Document a dataset with custom title and version:{p_end}
{phang2}{cmd:. datadict, single(patients) output(dict.md) title("Patient Registry") version("1.0")}{p_end}

{pstd}Document multiple datasets from a list:{p_end}
{phang2}{cmd:. datadict, filelist(patients hrt dmt) output(combined.md)}{p_end}

{pstd}Document all datasets in the current directory:{p_end}
{phang2}{cmd:. datadict, directory(.) output(combined.md) title("Project Data") author("Jane Doe")}{p_end}

{pstd}Document datasets recursively with separate files:{p_end}
{phang2}{cmd:. datadict, directory(data) recursive separate}{p_end}

{pstd}Include missing data and statistics in the output:{p_end}
{phang2}{cmd:. datadict, single(patients) missing stats}{p_end}

{pstd}Document with full metadata and statistics:{p_end}
{phang2}{cmd:. datadict, filelist(patients labs visits) missing stats title("Clinical Study Data") version("2.0") author("Research Team")}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datadict} stores the following in {cmd:r()}:

{synoptset 15 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(nfiles)}}number of datasets documented{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(output)}}output filename{p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}
Tim Copeland

{pstd}
For bug reports and feature requests, contact the author.
{p_end}

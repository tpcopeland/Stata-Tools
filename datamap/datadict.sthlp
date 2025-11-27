{smcl}
{* *! version 2.1.0  27nov2025}{...}
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
{synopt:{opt single(filename)}}document a single .dta file{p_end}
{synopt:{opt dir:ectory(path)}}document all .dta files in directory{p_end}
{synopt:{opt filelist(filename)}}text file listing .dta files to process{p_end}
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
For variables with more than 15 categories, it displays a count rather than 
listing all values.

{pstd}
The generated Markdown files are suitable for rendering in documentation 
systems, GitHub, or conversion to other formats via tools like Pandoc.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{opt single(filename)} specifies a single .dta file to document. The file 
must exist and be a valid Stata dataset.

{phang}
{opt directory(path)} specifies a directory containing .dta files. All 
datasets in the directory will be documented in a single output file (unless 
{opt separate} is specified). If no path is given, the current working 
directory is used.

{phang}
{opt filelist(filename)} specifies a text file containing paths to .dta files, 
one per line. Lines beginning with * are treated as comments and ignored.

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


{marker examples}{...}
{title:Examples}

{pstd}Document a single dataset with default settings:{p_end}
{phang2}{cmd:. datadict, single(patients.dta)}{p_end}

{pstd}Document a dataset with custom title and version:{p_end}
{phang2}{cmd:. datadict, single(patients.dta) output(dict.md) title("Patient Registry") version("1.0")}{p_end}

{pstd}Document all datasets in the current directory:{p_end}
{phang2}{cmd:. datadict, directory(.) output(combined.md) title("Project Data") author("Jane Doe")}{p_end}

{pstd}Document datasets recursively with separate files:{p_end}
{phang2}{cmd:. datadict, directory(data) recursive separate}{p_end}

{pstd}Document datasets from a list file:{p_end}
{phang2}{cmd:. datadict, filelist(myfiles.txt) output(documentation.md)}{p_end}


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

{smcl}
{* *! version 1.0.0  2025/12/02}{...}
{cmd:help massdesas}
{hline}

{title:Title}
{p 10}{bf:massdesas}{p_end}

{title:Syntax}
{p 10}
{cmd:massdesas}
[,
{cmdab:directory(directory_name)}
{cmdab:erase}
{cmdab:lower}
]
{p_end}

{title:Description}

{pstd}
{cmd:massdesas} recursively converts all SAS dataset files (.sas7bdat) to Stata format (.dta) within
a specified directory and all its subdirectories. This command is designed to streamline the process
of converting large collections of SAS files to Stata format, which would otherwise require
manual conversion of each file.
{p_end}

{pstd}
The command scans the specified directory tree, identifies all .sas7bdat files, and converts each
one to a .dta file in the same location with the same filename (but .dta extension). This preserves
the original directory structure while making all datasets accessible in Stata.
{p_end}

{pstd}
{bf:Warning:} When using the {opt erase} option, the original .sas7bdat files will be permanently
deleted after successful conversion. Ensure you have backups before using this option.
{p_end}

{title:Options}

{phang}
{opt directory(directory_name)} specifies the root directory containing the .sas7bdat files. The
command will search this directory and all its subdirectories for SAS dataset files to convert.
If not specified, the command uses the current working directory.
{p_end}

{phang}
{opt erase} specifies that the original .sas7bdat files should be deleted after successful conversion
to .dta format. Use this option with caution as the deletion is permanent. It is recommended to
test the conversion on a small sample first and verify the .dta files are readable before using
this option on your full dataset collection.
{p_end}

{phang}
{opt lower} specifies that all variable names in the converted .dta files should be converted to
lowercase. This is useful for ensuring consistency in variable naming conventions, as SAS variable
names can be case-sensitive while Stata variable names are typically lowercase by convention.
{p_end}

{marker examples}{...}
{title:Examples}

{pstd}Convert all SAS files in the current directory{p_end}
{phang2}{cmd:. massdesas}{p_end}

{pstd}Convert all SAS files in a specific directory{p_end}
{phang2}{cmd:. massdesas, directory("C:/Data/SAS_Files")}{p_end}

{pstd}Convert with lowercase variable names{p_end}
{phang2}{cmd:. massdesas, directory("C:/Data/SAS_Files") lower}{p_end}

{pstd}Convert and delete original SAS files (use with caution!){p_end}
{phang2}{cmd:. massdesas, directory("C:/Data/SAS_Files") erase}{p_end}

{pstd}Complete workflow: convert with lowercase names and remove originals{p_end}
{phang2}{cmd:. * First, test on a backup copy}{p_end}
{phang2}{cmd:. massdesas, directory("C:/Data/SAS_Files_Backup") lower}{p_end}
{phang2}{cmd:. * Verify conversion was successful by opening some files}{p_end}
{phang2}{cmd:. use "C:/Data/SAS_Files_Backup/dataset1.dta", clear}{p_end}
{phang2}{cmd:. describe}{p_end}
{phang2}{cmd:. * If successful, run on actual data}{p_end}
{phang2}{cmd:. massdesas, directory("C:/Data/SAS_Files") lower erase}{p_end}

{pstd}Convert files in nested directory structure{p_end}
{phang2}{cmd:. * Directory structure:}{p_end}
{phang2}{cmd:. * C:/Project/}{p_end}
{phang2}{cmd:. *   ├── Raw/}{p_end}
{phang2}{cmd:. *   │   ├── baseline.sas7bdat}{p_end}
{phang2}{cmd:. *   │   └── followup.sas7bdat}{p_end}
{phang2}{cmd:. *   └── Derived/}{p_end}
{phang2}{cmd:. *       └── analysis.sas7bdat}{p_end}
{phang2}{cmd:. massdesas, directory("C:/Project") lower}{p_end}
{phang2}{cmd:. * Results in:}{p_end}
{phang2}{cmd:. * C:/Project/Raw/baseline.dta}{p_end}
{phang2}{cmd:. * C:/Project/Raw/followup.dta}{p_end}
{phang2}{cmd:. * C:/Project/Derived/analysis.dta}{p_end}

{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:massdesas} requires the {cmd:usesas} command to be installed, which in turn requires
the Java-based SAS data reader. Ensure both are properly installed and configured before
using {cmd:massdesas}.
{p_end}

{pstd}
The command processes files sequentially, so conversion of large directory trees with many
SAS files may take considerable time. Progress is displayed as each file is converted.
{p_end}

{pstd}
If a conversion fails for any file, {cmd:massdesas} will display an error message for that
file and continue processing remaining files. When using the {opt erase} option, files are
only deleted if conversion was successful.
{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:massdesas} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_converted)}}number of files successfully converted{p_end}
{synopt:{cmd:r(n_failed)}}number of files that failed to convert{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(directory)}}source directory path{p_end}
{p2colreset}{...}

{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 2025-12-02{p_end}

{title:Also see}

{psee}
Online: {stata ssc describe fs: ssc describe fs}
{p_end}

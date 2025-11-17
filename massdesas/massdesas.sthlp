{smcl}
{* 24july2020}{...}
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

{p}Converts all .sas7bdat files to .dta files within a given directory and all subdirectories within the given directory. Options available for (1) erasing original .sas7bdat after saving .dta, and (2) lowercase variables on export.{p_end}

{title:Options}

{p 4 8 2}{opt directory(directory_name)} is the directory containing the .sas7bdat files, including any .sas7bdat files within sub-directories{p_end}

{p 4 8 2}{opt erase} specifies that .sas7bdat files should be deleted after the .dta file is generated{p_end}

{p 4 8 2}{opt lower} specifies the variable names be in all lowercase{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.0 - 24 July 2020{p_end}

{title:Also see}

{psee}
Online: {stata ssc describe fs: ssc describe fs}
{p_end}

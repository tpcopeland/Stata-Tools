{smcl}
{* *! version 1.0.0  2025/12/02}{...}
{vieweralsosee "[D] compress" "help compress"}{...}
{vieweralsosee "[D] recast" "help recast"}{...}
{vieweralsosee "[D] memory" "help memory"}{...}
{viewerjumpto "Syntax" "compress_tc##syntax"}{...}
{viewerjumpto "Description" "compress_tc##description"}{...}
{viewerjumpto "Options" "compress_tc##options"}{...}
{viewerjumpto "Stored results" "compress_tc##results"}{...}
{viewerjumpto "Examples" "compress_tc##examples"}{...}
{viewerjumpto "Technical notes" "compress_tc##technical"}{...}
{viewerjumpto "Author" "compress_tc##author"}{...}
{title:Title}

{phang}
{bf:compress_tc} {hline 2} Maximally compress string variables via strL conversion


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:compress_tc}
[{varlist}]
[{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt nocomp:ress}}skip the {cmd:compress} step; perform strL conversion only{p_end}
{synopt:{opt nostrl}}skip strL conversion; perform standard {cmd:compress} only{p_end}

{syntab:Reporting}
{synopt:{opt norep:ort}}suppress {cmd:compress}'s per-variable output{p_end}
{synopt:{opt q:uietly}}suppress all output{p_end}
{synopt:{opt det:ail}}show per-variable type information before conversion{p_end}
{synopt:{opt vars:avings}}report per-variable summary after compression{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:compress_tc} performs two-stage compression of string variables:

{phang2}1. Converts fixed-length {cmd:str}{it:#} variables to variable-length {cmd:strL}{p_end}
{phang2}2. Runs {cmd:compress} to find optimal storage types{p_end}

{pstd}
The {cmd:strL} type stores strings in a compressed heap, which can dramatically
reduce memory for datasets with long strings, repeated values, or both. The
subsequent {cmd:compress} step reverts short unique strings to {cmd:str}{it:#}
format if that proves more efficient.

{pstd}
If {varlist} is not specified, {cmd:compress_tc} operates on all variables.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt nocompress} skips the {cmd:compress} step, performing only the strL
conversion. Use this to see the effect of strL conversion alone.

{phang}
{opt nostrl} skips the strL conversion, performing only standard {cmd:compress}.
Equivalent to running {cmd:compress} directly but with memory reporting.

{dlgtab:Reporting}

{phang}
{opt noreport} suppresses {cmd:compress}'s detailed per-variable output while
still showing the summary statistics.

{phang}
{opt quietly} suppresses all output. Results are still stored in {cmd:r()}.

{phang}
{opt detail} displays the original type of each string variable before
conversion.

{phang}
{opt varsavings} displays a per-variable summary after compression, showing
each processed variable with its final type and format. Useful for seeing
which variables were affected by the compression.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:compress_tc} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(bytes_saved)}}total bytes saved{p_end}
{synopt:{cmd:r(pct_saved)}}percentage reduction in string data{p_end}
{synopt:{cmd:r(bytes_initial)}}initial string data size in bytes{p_end}
{synopt:{cmd:r(bytes_final)}}final string data size in bytes{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}string variables actually processed{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Compress all string variables in the dataset{p_end}
{phang2}{cmd:. compress_tc}{p_end}

{pstd}Compress specific variables{p_end}
{phang2}{cmd:. compress_tc name address city}{p_end}

{pstd}Show detailed variable information{p_end}
{phang2}{cmd:. compress_tc, detail}{p_end}

{pstd}Suppress compress output, show only summary{p_end}
{phang2}{cmd:. compress_tc, noreport}{p_end}

{pstd}Standard compress only (no strL conversion){p_end}
{phang2}{cmd:. compress_tc, nostrl}{p_end}

{pstd}strL conversion only (no compress){p_end}
{phang2}{cmd:. compress_tc, nocompress}{p_end}

{pstd}Silent operation, access results programmatically{p_end}
{phang2}{cmd:. compress_tc, quietly}{p_end}
{phang2}{cmd:. display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"}{p_end}

{pstd}Show per-variable summary after compression{p_end}
{phang2}{cmd:. compress_tc, varsavings}{p_end}


{marker technical}{...}
{title:Technical notes}

{pstd}
{bf:How strL compression works:} Stata's {cmd:strL} type stores strings in a
separate heap with deduplication and compression. Identical strings are stored
only once, and long strings are compressed using zlib. This is particularly
effective for:

{phang2}- Datasets with many repeated string values (e.g., categorical data stored as strings){p_end}
{phang2}- Variables with long strings (e.g., addresses, descriptions, notes){p_end}
{phang2}- Variables with many missing/empty values{p_end}

{pstd}
{bf:Memory measurement:} The reported byte savings reflect total string data
in the dataset ({cmd:memory}'s {cmd:data_data_u} + {cmd:data_strl_u}), not
just the specified {it:varlist}. This is a limitation of Stata's memory
reporting.

{pstd}
{bf:When strL increases size:} For variables with short, unique strings,
{cmd:strL} may temporarily increase memory due to heap overhead. The
subsequent {cmd:compress} step detects this and reverts such variables to
{cmd:str}{it:#} format.

{pstd}
{bf:File format note:} Datasets with {cmd:strL} variables must be saved in
Stata 13+ format ({cmd:.dta} version 117 or later). They cannot be saved in
older formats.



{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}
Fork of strcompress by Luke Stein

{pstd}
This fork has additional options and error handling.

{title:Also see}

{psee}
Manual: {manlink D compress}, {manlink D recast}, {manlink D memory}

{psee}
{space 2}Help: {manhelp compress D}, {manhelp recast D}, {manhelp memory D}
{p_end}

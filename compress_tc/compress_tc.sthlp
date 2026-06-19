{smcl}
{* *! version 1.1.0  19jun2026}{...}
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
{synopt:{opt noc:ompress}}skip the {cmd:compress} step; perform strL conversion only{p_end}
{synopt:{opt nos:trl}}skip strL conversion; perform standard {cmd:compress} only{p_end}
{synopt:{opt low:mem}}convert and compress one variable at a time to cap peak memory{p_end}
{synopt:{opt dry:run}}report projected savings without modifying the data{p_end}
{synopt:{opt min:length(#)}}only convert {cmd:str}{it:#} variables at least {it:#} bytes wide to strL{p_end}

{syntab:Reporting}
{synopt:{opt nor:eport}}suppress {cmd:compress}'s per-variable output{p_end}
{synopt:{opt q:uietly}}suppress all output{p_end}
{synopt:{opt d:etail}}show per-variable type information before conversion{p_end}
{synopt:{opt vars:avings}}report per-variable before/after bytes and savings{p_end}
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

{phang}
{opt lowmem} recasts and compresses one variable at a time instead of recasting
the whole {varlist} to strL at once. Because only a single variable's strL heap
is live at any moment, peak memory is bounded by the largest individual variable
rather than the entire dataset. Use this on very large datasets where the
all-at-once path would spike memory. The peak is only reduced when {cmd:compress}
runs (that is, not in combination with {opt nocompress}). Because {cmd:lowmem}
governs only the strL-conversion stage, it has no effect when combined with
{opt nostrl} (there is nothing to convert incrementally). With {opt varsavings},
{cmd:lowmem} also yields {it:measured} per-variable savings (including strL heap
effects) rather than the storage-width estimate used in the default mode.

{phang}
{opt dryrun} reports the projected savings without permanently modifying the
data. The dataset is restored to its original storage types on completion, but
the stored results (see {help compress_tc##results:Stored results}) still reflect
what the compression {it:would} have achieved. Use this to decide whether to
commit before running on a large dataset.

{phang}
{opt minlength(#)} restricts the strL conversion to {cmd:str}{it:#} variables at
least {it:#} bytes wide. Short, fixed-length variables (e.g. ICD or ATC codes)
gain little from strL and are otherwise recast and reverted by {cmd:compress},
so skipping them avoids that wasted round trip. The default {cmd:minlength(0)}
converts every fixed-length string variable. Skipped variables are still passed
to {cmd:compress}.

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
{opt varsavings} displays a per-variable table showing each processed variable's
type transition and its memory use before and after compression, with the bytes
saved. Sizes are shown in the most readable unit (B, KB, MB, or GB). For
variables that end as {cmd:strL}, the per-variable bytes live in a shared heap
and cannot be attributed to a single variable, so they are shown as a dash unless
{opt lowmem} is also specified (which measures each variable's actual delta).


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:compress_tc} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(bytes_saved)}}total bytes saved{p_end}
{synopt:{cmd:r(pct_saved)}}percentage reduction in data size{p_end}
{synopt:{cmd:r(bytes_initial)}}initial data size in bytes{p_end}
{synopt:{cmd:r(bytes_final)}}final data size in bytes{p_end}
{synopt:{cmd:r(bytes_strl)}}bytes held in the strL heap after compression{p_end}
{synopt:{cmd:r(k_converted)}}number of variables recast to strL{p_end}
{synopt:{cmd:r(k_reverted)}}number of those that {cmd:compress} moved back to a fixed type{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(vars_strl)}}variables stored as strL after compression{p_end}
{synopt:{cmd:r(varlist)}}string variables actually processed{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Compress all string variables in the dataset{p_end}
{phang2}{stata "compress_tc":. compress_tc}{p_end}

{pstd}Compress specific variables{p_end}
{phang2}{stata "compress_tc name address city":. compress_tc name address city}{p_end}

{pstd}Show detailed variable information{p_end}
{phang2}{stata "compress_tc, detail":. compress_tc, detail}{p_end}

{pstd}Suppress compress output, show only summary{p_end}
{phang2}{stata "compress_tc, noreport":. compress_tc, noreport}{p_end}

{pstd}Standard compress only (no strL conversion){p_end}
{phang2}{stata "compress_tc, nostrl":. compress_tc, nostrl}{p_end}

{pstd}strL conversion only (no compress){p_end}
{phang2}{stata "compress_tc, nocompress":. compress_tc, nocompress}{p_end}

{pstd}Silent operation, access results programmatically{p_end}
{phang2}{stata "compress_tc, quietly":. compress_tc, quietly}{p_end}
{phang2}{stata `"display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)""':. display "Saved " r(bytes_saved) " bytes (" %4.1f r(pct_saved) "%)"}{p_end}

{pstd}Show per-variable before/after bytes and savings{p_end}
{phang2}{stata "compress_tc, varsavings":. compress_tc, varsavings}{p_end}

{pstd}Preview the projected savings without modifying the data{p_end}
{phang2}{stata "compress_tc, dryrun":. compress_tc, dryrun}{p_end}

{pstd}Cap peak memory on a large dataset (convert one variable at a time){p_end}
{phang2}{stata "compress_tc, lowmem":. compress_tc, lowmem}{p_end}

{pstd}Convert only string variables at least 20 bytes wide to strL{p_end}
{phang2}{stata "compress_tc, minlength(20)":. compress_tc, minlength(20)}{p_end}

{pstd}Compress prescription data{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/prescriptions.dta", clear"':. use _data/prescriptions.dta, clear}{p_end}
{phang2}{stata "compress_tc":. compress_tc}{p_end}

{pstd}Compress specific string variables with detail{p_end}
{phang2}{stata "compress_tc atc drug_name, detail":. compress_tc atc drug_name, detail}{p_end}

{pstd}Compress procedures data{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear"':. use _data/procedures.dta, clear}{p_end}
{phang2}{stata "compress_tc kva_code proc_description, detail":. compress_tc kva_code proc_description, detail}{p_end}


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
{bf:Memory measurement:} The reported byte savings reflect total data
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

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}

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

{hline}

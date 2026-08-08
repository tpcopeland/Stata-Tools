{smcl}
{* *! version 1.1.1  05aug2026}{...}
{vieweralsosee "Datetime values" "help datetime"}{...}
{vieweralsosee "Date functions" "help date()"}{...}
{cmd:help datefix}
{hline}

{title:Title}
{p 4 8 2}{bf:datefix} - Convert string date variables to numeric date formatted variables.{p_end}

{marker syntax}{...}
{title:Syntax}
{p 4 8 2}
{cmd:datefix} {varlist} [, {opt newvar(name)} {opt drop} {opt df(%fmt)}
{opt order(string)} {opt topyear(#)} {opt diag:nose}] {p_end}

{marker description}{...}
{title:Description}
{p 4 4 2}Given one or more string variables containing date information,
{cmd:datefix} converts them to numeric encoded variables with a date format.{p_end}

{p 4 4 2}If {opt newvar()} is used, only one variable can be specified.{p_end}

{p 4 4 2}If the variable is already numeric, {cmd:datefix} applies the date format directly
(or copies to {opt newvar()} if specified).{p_end}

{p 4 4 2}The program does not accommodate datetime values, only dates.{p_end}

{marker options}{...}
{title:Options}
{p 4 8 2}{opt newvar(name)} creates a new numeric date variable with the given
name. Only one variable can be used. The original variable is preserved unless
{opt drop} is also specified.{p_end}

{p 4 8 2}{opt drop} drops the original variable. Only applicable when
{opt newvar()} is used; otherwise it is redundant: string inputs are converted
in place, and numeric inputs are formatted in place.{p_end}

{p 4 8 2}{opt df(%fmt)} sets the {help datetime_display_formats:date display format}
for the date variable. The default is {bf:%tdCCYY/NN/DD} (YYYY/MM/DD).{p_end}

{p 4 8 2}{opt order(string)} specifies the ordering of month, day, and year in the input
string (MDY, DMY, or YMD). If omitted, the ordering that produces the fewest
missing values is automatically selected. MDY is preferred when tied for the
top count; if YMD and DMY tie above MDY, YMD is selected.{p_end}

{p 4 8 2}{opt topyear(#)} specifies the {it:topyear} argument for the {help date():date()} function. Required if
two-digit years are present. See {help date():date()} for details.{p_end}

{p 4 8 2}{opt diag:nose} reports the offending values when a conversion fails. If any
non-missing string cannot be parsed into a date (for example, a month or day
of {bf:00}, an out-of-range component such as {bf:2020/13/40}, or stray non-date text),
{cmd:datefix} prints a table of the distinct unconvertible values, their
frequencies, and the observation numbers where they occur, then stops with an
error so you can locate and fix the source data. Without {opt diagnose}, {cmd:datefix}
reports only the count of values that failed. Conversion is command-wide
all-or-nothing: if any value fails, every variable in {varlist} remains
unchanged, including values, storage types, formats, labels, and ordering.{p_end}

{marker examples}{...}
{title:Examples}

{p 4 4 2}Convert string date variables using auto-detected ordering:{p_end}
    {com}. datefix dob dod{reset}

{p 4 4 2}Convert to a new variable with MDY ordering and custom format:{p_end}
    {com}. datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY){reset}

{p 4 4 2}Handle two-digit years with topyear:{p_end}
    {com}. datefix city_founded, topyear(1900){reset}

{p 4 4 2}Create a new variable and drop the original:{p_end}
    {com}. datefix admission_date, newvar(admit_dt) drop df(%tdDD/NN/CCYY){reset}

{p 4 4 2}Report which values block the conversion instead of just the count:{p_end}
    {com}. datefix dob, diagnose{reset}

{title:Example Date Formats for df()}
{p2colset 5 30 32 2}{...}
{p2col:{cmd:%tdCCYY/NN/DD}}example: {cmd:"2020/01/10"} (default){p_end}
{p2col:{cmd:%tdMonth_DD,_CCYY}}example: {cmd:"January 10, 2020"}{p_end}
{p2col:{cmd:%tdDD_Mon._CCYY}}example: {cmd:"10 Jan. 2020"}{p_end}
{p2col:{cmd:%tdDD/NN/CCYY}}example: {cmd:"10/01/2020"}{p_end}
{p2colreset}{...}

{title:Stored results}

{pstd}{cmd:datefix} does not store results and clears incidental {cmd:r()} state
before returning.{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}

{pstd}Version 1.1.1 - 05aug2026{p_end}

{hline}

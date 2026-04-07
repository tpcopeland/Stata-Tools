{smcl}
{* *! version 1.0.0  08apr2026}{...}
{cmd:help datefix}
{hline}

{title:Title}
{p 4 8 2}{bf:datefix} - Convert string date variables to numeric date formatted variables.{p_end}

{title:Syntax}
{p 4 8 2}
{cmd:datefix} {varlist} [, {opt newvar(name)} {cmdab:drop} {cmdab:df(}{help datetime_display_formats:date %fmt}{cmd:)} {opt order(string)} {opt topyear(#)}] {p_end}

{title:Description}
{p 4 4 2}Given one or more string variables containing date information, {cmd:datefix} converts them to numeric encoded variables with a date format.{p_end}

{p 4 4 2}If {opt newvar()} is used, only one variable can be specified.{p_end}

{p 4 4 2}If the variable is already numeric, {cmd:datefix} applies the date format directly (or copies to {opt newvar()} if specified).{p_end}

{p 4 4 2}The program does not accommodate datetime values, only dates.{p_end}

{title:Options}
{p 4 8 2}{opt newvar(name)} creates a new numeric date variable with the given name. Only one variable can be used. The original variable is preserved unless {opt drop} is also specified.{p_end}

{p 4 8 2}{cmdab:drop} drops the original variable. Only applicable when {opt newvar()} is used; otherwise redundant since the original variable is replaced.{p_end}

{p 4 8 2}{cmdab:df(}{help datetime_display_formats:date %fmt}{cmd:)} display format for the date variable. Default is {bf:%tdCCYY/NN/DD} (YYYY/MM/DD).{p_end}

{p 4 8 2}{opt order(string)} specifies the ordering of month, day, and year in the input string (MDY, DMY, or YMD). If omitted, the ordering that produces the fewest missing values is automatically selected.{p_end}

{p 4 8 2}{opt topyear(#)} specifies the {it:topyear} argument for the {help date():date()} function. Required if two-digit years are present. See {help date():date()} for details.{p_end}

{title:Examples}

{p 4 4 2}Convert string date variables using auto-detected ordering:{p_end}
    {com}. datefix dob dod{reset}

{p 4 4 2}Convert to a new variable with MDY ordering and custom format:{p_end}
    {com}. datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY){reset}

{p 4 4 2}Handle two-digit years with topyear:{p_end}
    {com}. datefix city_founded, topyear(1900){reset}

{p 4 4 2}Create a new variable and drop the original:{p_end}
    {com}. datefix admission_date, newvar(admit_dt) drop df(%tdDD/NN/CCYY){reset}

{title:Example Date Formats for df()}
    %tdCCYY/NN/DD       ex: "2020/01/10" (default)
    %tdMonth_DD,_CCYY   ex: "January 10, 2020"
    %tdDD_Mon._CCYY     ex: "10 Jan. 2020"
    %tdDD/NN/CCYY       ex: "10/01/2020"

{title:Stored results}

{pstd}{cmd:datefix} does not store results.{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 08apr2026{p_end}

{hline}

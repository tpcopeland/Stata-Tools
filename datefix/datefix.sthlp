{smcl}
{* *! version 1.0.1  03dec2025}{...}
{cmd:help datefix}
{hline}

{title:Title}
{p 4 8 2}{bf:datefix} - Convert string date variable to numeric date formatted variable.{p_end}

{title:Syntax}
{p 4 8 2}
{cmd:datefix} {varlist} [, {opt newvar(string)} {cmdab:drop} {cmdab:df(}{help datetime_display_formats:date %fmt}{cmd:)} {opt order(string)} {opt topyear(integer)}] {p_end}

{title:Description}
{p 4 4 2}Given one or more string variables containing date information, datefix converts the variables to numeric encoded variables with a date format.  {p_end}

{p 4 4 2}If the newvar() option is used, only one variable can be used in the command. {p_end}

{p 4 4 2}The program does not accommodate datetime values, only dates. {p_end}

{title:Options}
{p 4 8 2}{opt newvar(string)} Creates a new numeric date variable with given name. Only one variable can be used.{p_end}

{p 4 8 2}{cmdab:drop} Drops original string variable. Only applicable when newvar() is used, otherwise is redundant. {p_end}

{p 4 8 2}{cmdab:df(}{help datetime_display_formats:date %fmt}{cmd:)} display format for date (default is YYYY/MM/DD; i.e., %tdCCYY/MM/DD).{p_end}

{p 4 8 2}{opt order(string)} allows you to specify ordering of month, day, and year (e.g., MDY, DMY, YMD; default is the ordering that produces the fewest missing values). {p_end}

{p 4 8 2}{opt topyear(integer)} specifies the topyear of the {help date():date()} function. Required if two digit years are present. See {help date():date()} for clarification regarding {opt topyear(integer)}. {p_end}

{title:Examples}
{p 4 4 2}Convert the string date variables dob and dod using the default date format and whichever ordering of day month and year produces the fewest missing values, replacing the original string variables.
{p_end}

    {com}. datefix dob dod

{p 4 4 2}Convert the variable visit_date into a new variable vdate using the MDY date format, preserving the original string variable visit_date, and using the format that produces a date in "Month DD, CCYY" format.
{p_end}

    {com}. datefix visit_date, newvar(vdate) order(MDY) df(%tdMonth_DD,_CCYY) 

{p 4 4 2}Convert the variable city_founded into a numeric date variable, dropping the original variables and indicating that the years listed with two digits are in the years closest to but not after 1900.
{p_end}

    {com}. datefix city_founded, topyear(1900)

{title:Example Date Formats for df()}
	%tdCCYY/MM/DD		ex: "2020/01/10" (default)
	%tdMonth_DD,_CCYY	ex: "January 10, 2020"
	%tdDD_Mon._CCYY		ex: "10 Jan. 2020"
	%tdDD/MM/CCYY		ex: "01/10/2020"
    
{title:Version history}
- {bf:2.0}  : Added newvar(), drop, and topyear(). Added error codes.
- {bf:1.0}  : First version.

{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 2025-12-02{p_end}

{hline}
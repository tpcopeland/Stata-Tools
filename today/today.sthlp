{smcl}
{* *{* *! version 1.0.0  2025/12/02}{...}
{cmd:help today}
{hline}

{title:Title}

{p 4 4 2}
{bf:today} {hline 2} Set global macros with today's date and current time, with customizable formatting.


{title:Syntax}

{p 8 12 2}
{cmd:today}
[{cmd:,}
{cmd:df(}{it:string}{cmd:)}
{cmd:tsep(}{it:string}{cmd:)}
{cmd:hm}
{cmd:from(}{it:string}{cmd:)}
{cmd:to(}{it:string}{cmd:)}]


{title:Description}

{p 4 4 2}
{cmd:today} is a command that sets two global macros: {bf:$today} and {bf:$today_time}.
{cmd:today} sets two global macros, {bf:$today} and {bf:$today_time}, containing the current date and time respectively. It offers flexible formatting options for both date and time components, making it convenient for incorporating the current date and time into Stata programs, logs, and output files.

{p 4 4 2}
By default, it uses the "ymd" format for the date (YYYY_MM_DD), a colon (":") as the time separator, and includes seconds in the time.

{title:Options}

{p 4 8 2}
{opt df:(string)} specifies the format for the date part of the output.
Valid values for {it:string} are:

{p 8 12 2}
{bf:ymd}: YYYY_MM_DD (e.g., 2024_12_19). This is the default.

{p 8 12 2}
{bf:dmony}: DD Mon YYYY (e.g., 19 Dec 2024).

{p 8 12 2}
{bf:dmy}: DD/MM/YYYY (e.g., 19/12/2024).

{p 8 12 2}
{bf:mdy}: MM/DD/YYYY (e.g., 12/19/2024).

{p 4 8 2}
{opt tsep:(string)} specifies the separator to be used between the hours, minutes, and seconds in the time component. The default is a period (":") (e.g., 14:30:45 for 2:30:45 PM).

{p 4 8 2}
{opt hm} specifies that only hours and minutes should be included in the time component, omitting seconds. By default, the time includes seconds (e.g., 14:30:45). When {opt hm} is specified, the time will be in the format HH.MM (e.g., 14:30).

{p 4 8 2}
{opt from(string)} specifies the source timezone in UTC format (e.g., UTC+7 or UTC-5). Default is current time zone. Must be specified with {opt to(string)}.

{p 4 8 2}
{opt to(string)} specifies the target timezone in UTC format (e.g., UTC+7 or UTC-5). Default is computer time zone. Must be specified with {opt from(string)}.

{title:Examples}

{p 4 4 2}
{cmd:. today}
{break}
Sets {bf:$today} to the current date in YYYY_MM_DD format (e.g., "2024_12_19") and {bf:$today_time} to the current date and time (e.g., "2024_12_19 14.30.45").

{p 4 4 2}
{cmd:. today, df(dmony)}
{break}
Sets {bf:$today} to "19 Dec 2024" and {bf:$today_time} to "19 Dec 2024 14:30:45" (assuming the current date is December 19, 2024 and the time is 2:30:45 PM).

{p 4 4 2}
{cmd:. today, df(mdy) tsep(.)}
{break}
Sets {bf:$today} to "12/19/2024" and {bf:$today_time} to "12/19/2024 14.30.45".

{p 4 4 2}
{cmd:. today, hm tsep(-)}
{break}
Sets {bf:$today} to "2024_12_19" and {bf:$today_time} to "2024_12_19 14-30".

{p 4 4 2}
{cmd:. di "$today"}
{break}
Displays the contents of the global macro {bf:$today} (e.g. 2024_12_19)

{p 4 4 2}
{cmd:. today, from(UTC+1) to(UTC-7)}
{break}
Assumes computer date and time is UTC+1 and converts to UTC-7 for the global macros. 

{title:Stored results}

{p 4 4 2}
{cmd:today} sets the following global macros:

{p 8 12 2}
{cmd:$today}: The current date, formatted according to the {opt df()} option.

{p 8 12 2}
{cmd:$today_time}: The current date and time, formatted according to the {opt df()} and {opt tsep()} options, and including or excluding seconds based on the {opt hm} option.

{p 4 4 2}

{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 2025-12-02{p_end}

{p 4 4 2}

{psee}
Also see: {help date}, {help timeofday}, {help format}
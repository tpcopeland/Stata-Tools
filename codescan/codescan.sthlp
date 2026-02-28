{smcl}
{* *! version 1.0.1  27feb2026}{...}
{vieweralsosee "[D] generate" "help generate"}{...}
{vieweralsosee "[D] collapse" "help collapse"}{...}
{vieweralsosee "[FN] String functions" "help string functions"}{...}
{viewerjumpto "Syntax" "codescan##syntax"}{...}
{viewerjumpto "Description" "codescan##description"}{...}
{viewerjumpto "Options" "codescan##options"}{...}
{viewerjumpto "Time windows" "codescan##windows"}{...}
{viewerjumpto "Remarks" "codescan##remarks"}{...}
{viewerjumpto "Examples" "codescan##examples"}{...}
{viewerjumpto "Stored results" "codescan##results"}{...}
{viewerjumpto "Author" "codescan##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:codescan} {hline 2}}Scan wide-format code variables for pattern matches{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:codescan}
{varlist}
{ifin}
{cmd:,}
{opt def:ine(string)}
[{it:options}]


{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt def:ine(string)}}name-pattern pairs: {cmd:define(dm2 "E11" | obesity "E66")}{p_end}

{syntab:Identifiers}
{synopt:{opt id(varname)}}patient/entity ID variable (required with {cmd:collapse}){p_end}
{synopt:{opt date(varname)}}row-level date variable{p_end}
{synopt:{opt refd:ate(varname)}}reference/index date for time windows{p_end}

{syntab:Time window}
{synopt:{opt lookb:ack(#)}}days before {cmd:refdate} to include{p_end}
{synopt:{opt lookf:orward(#)}}days after {cmd:refdate} to include{p_end}
{synopt:{opt inc:lusive}}include {cmd:refdate} in single-direction windows{p_end}

{syntab:Output}
{synopt:{opt col:lapse}}collapse to patient level (max indicators){p_end}
{synopt:{opt earliestd:ate}}create {it:name}_first variables (requires {cmd:date} + {cmd:collapse}){p_end}
{synopt:{opt latestd:ate}}create {it:name}_last variables (requires {cmd:date} + {cmd:collapse}){p_end}
{synopt:{opt countd:ate}}create {it:name}_count variables (requires {cmd:date} + {cmd:collapse}){p_end}

{syntab:Labels}
{synopt:{opt lab:el(string)}}variable labels: {cmd:label(dm2 "Type 2 Diabetes" \ obesity "Obesity")}{p_end}

{syntab:Settings}
{synopt:{opt mod:e(string)}}{cmd:regex} (default) or {cmd:prefix}{p_end}
{synopt:{opt replace}}allow overwriting existing variables{p_end}
{synopt:{opt noi:sily}}show per-variable scan progress{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:codescan} replaces the 50-150 lines of boilerplate code typically needed
to scan wide-format code variables (dx1-dx30, proc1-proc20, etc.) with
{cmd:regexm()} or {cmd:substr()} inside {cmd:forvalues} loops.

{pstd}
A single {cmd:codescan} call defines conditions as name-pattern pairs,
optionally applies time windows relative to an index date, and can collapse
to patient-level indicators with date summaries.

{pstd}
{cmd:codescan} works with any string code system: ICD, KVA, CPT, ATC, OPCS,
or any other classification.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt define(string)} specifies one or more name-pattern pairs separated by
{cmd:|}.  Each pair consists of a condition name followed by a quoted pattern.
For example: {cmd:define(dm2 "E11" | obesity "E66" | htn "I1[0-35]")}.

{pmore}
In {cmd:regex} mode (default), patterns are automatically anchored with {cmd:^()},
so {cmd:"E11"} becomes {cmd:^(E11)}.  Use standard regex syntax: {cmd:[0-5]}
for ranges, {cmd:|} for alternation within a pattern.

{pmore}
In {cmd:prefix} mode, patterns are matched against the beginning of each code
using {cmd:substr()}.  Multiple prefixes within a condition can be separated
with {cmd:|}: {cmd:define(mammo "XF001|XF002")}.

{pmore}
Condition names must be valid Stata names with at most 26 characters
(to allow room for {cmd:_first}/{cmd:_last}/{cmd:_count} suffixes).

{dlgtab:Identifiers}

{phang}
{opt id(varname)} specifies the patient or entity ID variable. Required when
{cmd:collapse} is specified.

{phang}
{opt date(varname)} specifies the row-level date variable for each observation.
Required for time windows and date summary options.

{phang}
{opt refdate(varname)} specifies the reference or index date for time windows.
Required when {cmd:lookback()} or {cmd:lookforward()} is specified.

{dlgtab:Time window}

{phang}
{opt lookback(#)} restricts matches to observations where {cmd:date} falls
within {it:#} days before {cmd:refdate}. By default, {cmd:refdate} itself is
excluded. See {help codescan##windows:Time windows} for details.

{phang}
{opt lookforward(#)} restricts matches to observations where {cmd:date} falls
within {it:#} days after {cmd:refdate}. By default, {cmd:refdate} itself is
excluded. See {help codescan##windows:Time windows} for details.

{phang}
{opt inclusive} forces the inclusion of the reference date in single-direction
windows. When both {cmd:lookback()} and {cmd:lookforward()} are specified,
{cmd:refdate} is automatically included regardless of this option.

{dlgtab:Output}

{phang}
{opt collapse} collapses the data to one row per {cmd:id()}, taking the
maximum of each indicator (so 1 if any row matched). Requires {cmd:id()}.

{phang}
{opt earliestdate} creates {it:name}_first variables containing the earliest
date for each condition per patient. Requires {cmd:date()} and {cmd:collapse}.

{phang}
{opt latestdate} creates {it:name}_last variables containing the latest
date for each condition per patient. Requires {cmd:date()} and {cmd:collapse}.

{phang}
{opt countdate} creates {it:name}_count variables containing the number of
unique dates for each condition per patient. Requires {cmd:date()} and
{cmd:collapse}.

{dlgtab:Labels}

{phang}
{opt label(string)} specifies variable labels for conditions.  Pairs are
separated by {cmd:\}:
{cmd:label(dm2 "Type 2 Diabetes" \ obesity "Obesity")}.
Labels are applied to the indicator and any date summary variables.

{dlgtab:Settings}

{phang}
{opt mode(string)} specifies the matching mode: {cmd:regex} (default) uses
{cmd:regexm()} with auto-anchoring; {cmd:prefix} uses {cmd:substr()} for
simple prefix matching.

{phang}
{opt replace} allows {cmd:codescan} to overwrite existing variables.

{phang}
{opt noisily} displays progress information showing matches per variable.


{marker windows}{...}
{title:Time windows}

{pstd}
Time windows control which observations are eligible for matching based on
the relationship between {cmd:date()} and {cmd:refdate()}:

{phang2}{cmd:lookback(#)} only: date in [{cmd:refdate} - #, {cmd:refdate}) {hline 2} excludes refdate{p_end}

{phang2}{cmd:lookforward(#)} only: date in ({cmd:refdate}, {cmd:refdate} + #] {hline 2} excludes refdate{p_end}

{phang2}Both together: date in [{cmd:refdate} - lookback, {cmd:refdate} + lookforward] {hline 2} refdate auto-included{p_end}

{phang2}{cmd:inclusive}: forces refdate inclusion with single-direction windows{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Regex anchoring}

{pstd}
In regex mode, patterns are automatically wrapped with {cmd:^()} to anchor
matching at the start of the code string.  This means {cmd:"E11"} matches
codes starting with "E11" (like "E110", "E119"), not codes containing "E11"
anywhere. To match a code containing "E11" at any position, use
{cmd:".*E11"}.

{pstd}
{bf:Performance}

{pstd}
For large datasets, {cmd:prefix} mode is faster than {cmd:regex} mode because
{cmd:substr()} is less expensive than {cmd:regexm()}.  Use prefix mode when
exact prefix matching suffices.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic row-level indicators}

{phang2}{cmd:. codescan dx1-dx30, define(dm2 "E11" | obesity "E66")}{p_end}

{pstd}
{bf:Example 2: Full collapse with time window and date summaries}

{phang2}{cmd:. codescan dx1-dx30, id(lopnr) date(visit_dt) refdate(index_date) ///{p_end}
{phang2}{cmd:    define(dm2 "E11" | htn "I1[0-35]" | cvd "I2[0-5]|I6[0-9]") ///{p_end}
{phang2}{cmd:    lookback(1825) collapse earliestdate latestdate countdate ///{p_end}
{phang2}{cmd:    label(dm2 "Type 2 Diabetes" \ htn "Hypertension" \ cvd "CVD")}{p_end}

{pstd}
{bf:Example 3: Bidirectional window (refdate auto-included)}

{phang2}{cmd:. codescan dx1-dx30, id(lopnr) date(visit_dt) refdate(index_date) ///{p_end}
{phang2}{cmd:    define(dm2 "E11" | htn "I1[0-35]") ///{p_end}
{phang2}{cmd:    lookback(365) lookforward(365) collapse}{p_end}

{pstd}
{bf:Example 4: Single direction with inclusive refdate}

{phang2}{cmd:. codescan dx1-dx30, id(lopnr) date(visit_dt) refdate(index_date) ///{p_end}
{phang2}{cmd:    define(dm2 "E11") lookback(1825) inclusive collapse}{p_end}

{pstd}
{bf:Example 5: Prefix mode for procedure codes}

{phang2}{cmd:. codescan proc1-proc20, id(lopnr) date(proc_dt) refdate(index_date) ///{p_end}
{phang2}{cmd:    define(mammo "XF001|XF002" | colectomy "JFB|JFH") ///{p_end}
{phang2}{cmd:    mode(prefix) lookback(1825) inclusive collapse}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:codescan} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations (post-collapse if collapsed){p_end}
{synopt:{cmd:r(n_conditions)}}number of conditions defined{p_end}
{synopt:{cmd:r(lookback)}}lookback days (if specified){p_end}
{synopt:{cmd:r(lookforward)}}lookforward days (if specified){p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(conditions)}}space-separated condition names{p_end}
{synopt:{cmd:r(varlist)}}variables scanned{p_end}
{synopt:{cmd:r(mode)}}matching mode (regex or prefix){p_end}
{synopt:{cmd:r(refdate)}}reference date variable (if time window used){p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(summary)}}matrix with rows=conditions, columns=count and prevalence{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.1, 2026-02-27{p_end}


{title:Also see}

{psee}
Online:  {helpb generate}, {helpb collapse}, {helpb regexm()}

{hline}

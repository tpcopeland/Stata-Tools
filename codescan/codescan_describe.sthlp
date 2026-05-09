{smcl}
{* *! version 1.1.0  24apr2026}{...}
{vieweralsosee "codescan" "help codescan"}{...}
{vieweralsosee "[D] contract" "help contract"}{...}
{vieweralsosee "[D] tostring" "help tostring"}{...}
{viewerjumpto "Syntax" "codescan_describe##syntax"}{...}
{viewerjumpto "Description" "codescan_describe##description"}{...}
{viewerjumpto "Options" "codescan_describe##options"}{...}
{viewerjumpto "Remarks" "codescan_describe##remarks"}{...}
{viewerjumpto "Examples" "codescan_describe##examples"}{...}
{viewerjumpto "Stored results" "codescan_describe##results"}{...}
{viewerjumpto "Author" "codescan_describe##author"}{...}

{title:Title}

{p2colset 5 28 30 2}{...}
{p2col:{cmd:codescan_describe} {hline 2}}Describe the code inventory in wide-format variables{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 27 2}
{cmd:codescan_describe}
{varlist}
{ifin}
[{cmd:,} {it:options}]


{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt top(#)}}report the top {it:#} codes; default is {cmd:top(20)}{p_end}
{synopt:{opt nod:ots}}strip dots before tabulating{p_end}
{synopt:{opt tostr:ing}}convert numeric code variables to string before tabulating{p_end}
{synopt:{opt save(filename)}}write a draft chapter-level codefile CSV{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:codescan_describe} is the exploratory companion to {helpb codescan}.  It
answers a basic but important question before you write any scan rules:
{it:What codes are actually present in these variables?}

{pstd}
The command pools nonempty values across all specified wide-format code
variables (for example {cmd:dx1} through {cmd:dx30}), counts how often each
unique code appears, and then summarizes the inventory by the first character
of each code.  The output has two panels:

{phang2}1. A {bf:top-code table} showing the most common codes ranked by
frequency, with percent and cumulative percent columns.{p_end}

{phang2}2. A {bf:chapter summary} grouping all codes by their first character
(for ICD-10 these correspond roughly to diagnosis chapters), with code count
and entry count per group.{p_end}

{pstd}
This quickly shows whether your data are dominated by diagnosis chapters,
procedure prefixes, medication classes, or some other coding scheme — and
which prefixes deserve attention when you write {helpb codescan} rules.

{pstd}
Because it accumulates frequencies variable by variable using a Mata hash
map, {cmd:codescan_describe} avoids the memory blow-up that often comes with
reshaping very wide code data to long form just for reconnaissance.


{marker options}{...}
{title:Options}

{phang}
{opt top(#)} specifies how many codes to display in the ranked table.  The
value must be a positive integer.  The default is {cmd:top(20)}.  Use a large
value such as {cmd:top(100)} if you want to inspect rare codes as well.

{phang}
{opt nodots} strips periods from each code value before tabulating.  This is
useful when dotted and undotted forms should be treated as the same code — for
example, {cmd:E11.0} and {cmd:E110} would be counted together.  The original
data are never modified.

{phang}
{opt tostring} converts numeric variables in {varlist} to string before
tabulating.  Use this when code variables were inadvertently imported as
numeric rather than text.  The original numeric variables are restored
afterward.

{phang}
{opt save(filename)} writes a draft CSV codefile based on the chapter summary.
The file contains the columns {cmd:name}, {cmd:pattern}, {cmd:exclusion}, and
{cmd:label}.  Each row is a first-character chapter such as {cmd:chapter_E},
which you can open in a spreadsheet and refine into real scan rules before
using with {helpb codescan:codescan, codefile()}.  The filename must end in
{cmd:.csv}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:When to use this command.}  Run {cmd:codescan_describe} as the very
first step in a comorbidity or code-scanning workflow.  It tells you which
code families dominate, how many unique codes exist, and how the entry volume
is distributed across chapters — all without requiring any rule definitions.

{pstd}
{bf:Interpreting the output.}  The top-code table shows the most common
individual codes, so a single code appearing in many rows will rank high.
The chapter summary shows volume by first character, which is useful for
deciding which character-level groups to target in {cmd:define()} or
{cmd:codefile()} rules.

{pstd}
{bf:Building a starter codefile.}  The {cmd:save()} option creates a draft
codefile with one row per chapter (first character).  This is a starting
point, not a finished definition file: open it in a spreadsheet, rename the
conditions, refine the patterns, and add exclusion patterns as needed before
passing it to {helpb codescan:codescan, codefile()}.

{pstd}
{bf:Programmatic use.}  The same information printed to the Results window is
also returned in matrices.  {cmd:r(top_codes)} uses code values as row names and
has columns {cmd:frequency}, {cmd:percent}, and {cmd:cumul_pct}.  {cmd:r(chapters)}
uses first characters as row names and has columns {cmd:codes} and
{cmd:entries}.  This makes it possible to audit a new dataset automatically
before deciding whether an existing code dictionary is still appropriate.

{pstd}
{bf:Edge cases.}  If {cmd:if} or {cmd:in} removes every observation, the
command exits with error {cmd:r(2000)}.  If observations remain but every
scanned code slot is empty, the command succeeds and reports zero unique
codes.  In that case {cmd:r(top_codes)} and {cmd:r(chapters)} are still
returned as single-row zero-filled matrices, so downstream code does not need
special-case handling.


{marker examples}{...}
{title:Examples}

{pstd}
The following setup is copy-paste runnable after {cmd:net install}:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str6 dx1 str6 dx2}{p_end}
{phang2}{cmd:      "E110" "I10"}{p_end}
{phang2}{cmd:      "E119" "Z00"}{p_end}
{phang2}{cmd:      "I50"  ""}{p_end}
{phang2}{cmd:      ""     ""}{p_end}
{phang2}{cmd:. end}{p_end}

{pstd}
{bf:Example 1: Inspect the code inventory}

{pstd}
See which codes appear across both diagnosis slots and how they rank by
frequency:

{phang2}{cmd:. codescan_describe dx1 dx2}{p_end}

{pstd}
The output shows one table of the top codes (ranked by frequency, with percent
and cumulative percent) and a second table grouping all codes by their first
character.

{pstd}
Technical users can inspect the returned matrix directly:
{cmd:. matrix list r(top_codes)}.  The table is stored in
{cmd:r(top_codes)}.

{pstd}
{bf:Example 2: Show more codes and ignore dots}

{pstd}
Increase the number of ranked codes shown and merge dotted and undotted forms:

{phang2}{cmd:. codescan_describe dx1 dx2, top(10) nodots}{p_end}

{pstd}
{bf:Example 3: Draft a starter codefile from the chapter summary}

{pstd}
Write a CSV template you can open in a spreadsheet, refine, and later pass
to {helpb codescan:codescan, codefile()}:

{phang2}{cmd:. codescan_describe dx1 dx2, save(chapter_rules.csv)}{p_end}

{pstd}
{bf:Example 4: Restrict to a subset of observations}

{pstd}
Use {cmd:if} or {cmd:in} to inspect codes for a subset of patients or
encounters:

{phang2}{cmd:. codescan_describe dx1 dx2 if dx1 != ""}{p_end}

{pstd}
{bf:Example 5: Convert numeric codes before tabulating}

{pstd}
If your code variables were imported as numeric rather than string, add
{cmd:tostring} so that {cmd:codescan_describe} can inspect them:

{phang2}{cmd:. codescan_describe dx1 dx2, tostring}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:codescan_describe} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(n_unique)}}number of unique nonempty codes found{p_end}
{synopt:{cmd:r(n_entries)}}total nonempty code entries across all scanned variables{p_end}
{synopt:{cmd:r(n_vars)}}number of variables scanned{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}scanned variables{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(top_codes)}}displayed top codes; row names are codes and columns are {cmd:frequency}, {cmd:percent}, and {cmd:cumul_pct}{p_end}
{synopt:{cmd:r(chapters)}}first-character summary; row names are characters and columns are {cmd:codes} and {cmd:entries}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb codescan}

{hline}

{smcl}
{* *! version 1.0.3  23apr2026}{...}
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
The command pools nonempty values across wide-format code slots, tabulates the
most common codes, and then summarizes the inventory by first character.  This
quickly shows whether your data are dominated by diagnosis chapters, procedure
prefixes, medication classes, or some other coding scheme.

{pstd}
Because it accumulates frequencies variable by variable, {cmd:codescan_describe}
avoids the memory blow-up that often comes with reshaping very wide code data to
long form just for reconnaissance.


{marker options}{...}
{title:Options}

{phang}
{opt top(#)} specifies how many codes to display in the ranked table.  The value
must be a positive integer.  The default is {cmd:top(20)}.

{phang}
{opt nodots} strips periods before tabulating.  This is useful when dotted and
undotted forms should be treated as the same code, for example {cmd:E11.0} and
{cmd:E110}.

{phang}
{opt tostring} converts numeric variables in {varlist} to string before
tabulating.

{phang}
{opt save(filename)} writes a draft CSV codefile based on the chapter summary.
The file contains the columns {cmd:name}, {cmd:pattern}, {cmd:exclusion}, and
{cmd:label}.  Each row is a first-character chapter such as {cmd:chapter_E},
which you can refine into real scan rules before using with {helpb codescan}.
The filename must end in {cmd:.csv}.


{marker remarks}{...}
{title:Remarks}

{pstd}
If {cmd:if} or {cmd:in} removes every observation, the command exits with
{cmd:r(2000)}.

{pstd}
If observations remain but all scanned code slots are empty, the command succeeds
and reports zero unique codes.  In that case {cmd:r(top_codes)} and
{cmd:r(chapters)} are still returned as zero-filled matrices so downstream QA code
does not need special-case handling.

{pstd}
The chapter summary is deliberately simple.  It is a reconnaissance aid, not a
clinical grouping algorithm.


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

{phang2}{cmd:. codescan_describe dx1 dx2}{p_end}

{pstd}
{bf:Example 2: Increase the ranked output and ignore dots}

{phang2}{cmd:. codescan_describe dx1 dx2, top(10) nodots}{p_end}

{pstd}
{bf:Example 3: Draft a starter codefile from the chapter summary}

{phang2}{cmd:. codescan_describe dx1 dx2, save(chapter_rules.csv)}{p_end}


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
{synopt:{cmd:r(top_codes)}}frequency, percent, and cumulative percent for the displayed top codes{p_end}
{synopt:{cmd:r(chapters)}}chapter summary with columns {cmd:codes} and {cmd:entries}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb codescan}

{hline}

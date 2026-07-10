{smcl}
{* *! version 1.4.1  03jul2026}{...}
{vieweralsosee "cci_se" "help cci_se"}{...}
{vieweralsosee "cdp" "help cdp"}{...}
{vieweralsosee "migrations" "help migrations"}{...}
{vieweralsosee "pira" "help pira"}{...}
{vieweralsosee "sustainedss" "help sustainedss"}{...}
{viewerjumpto "Syntax" "setools##syntax"}{...}
{viewerjumpto "Description" "setools##description"}{...}
{viewerjumpto "Options" "setools##options"}{...}
{viewerjumpto "Commands" "setools##commands"}{...}
{viewerjumpto "Examples" "setools##examples"}{...}
{viewerjumpto "Stored results" "setools##results"}{...}
{viewerjumpto "Installation" "setools##installation"}{...}
{viewerjumpto "Author" "setools##author"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:setools} {hline 2}}Swedish Registry Toolkit for Epidemiological Cohort Studies{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:setools}
[{cmd:,} {opt list} {opt detail} {opt c:ategory(category)}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt list}}display only command names for the selected category{p_end}
{synopt:{opt detail}}display grouped command descriptions; may not be combined with {opt list}{p_end}
{synopt:{opt c:ategory(category)}}filter to {cmd:all}, {cmd:codes}, {cmd:migration}, or {cmd:ms}; default is {cmd:all}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:setools} is a toolkit for Swedish register-based epidemiological research. It
provides practical building blocks for cohort definition, comorbidity scoring,
migration-based exclusions, and disability-progression endpoints built from
repeated EDSS measurements.

{pstd}
Running {cmd:setools} by itself displays a grouped overview of all commands. Use
{opt list} for a compact command list, {opt detail} for longer descriptions, and
{opt category()} to restrict the display to one command group. {opt list} and
{opt detail} are mutually exclusive.

{pstd}
{bf:Choosing the right command:}

{p2colset 5 28 30 2}{...}
{p2col:If you need to...}Use{p_end}
{p2line}
{p2col:Score comorbidities from ICD codes}{helpb cci_se}{p_end}
{p2col:Exclude non-residents and derive emigration censoring}{helpb migrations}{p_end}
{p2col:Find the first sustained EDSS threshold crossing}{helpb sustainedss}{p_end}
{p2col:Define confirmed disability progression (CDP)}{helpb cdp}{p_end}
{p2col:Classify CDP as PIRA vs relapse-associated}{helpb pira}{p_end}
{p2line}
{p2colreset}{...}


{marker options}{...}
{title:Options}

{phang}
{opt list} displays only the command names for the selected category.

{phang}
{opt detail} displays grouped command descriptions. It may not be combined with
{opt list}.

{phang}
{opt category(category)} filters the displayed and returned commands. Valid
values are {cmd:all}, {cmd:codes}, {cmd:migration}, and {cmd:ms}. The default
is {cmd:all}.


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Registry Code Utilities}

{synoptset 16}{...}
{synopt:{helpb cci_se}}Swedish Charlson Comorbidity Index (ICD-7 through ICD-10){p_end}

{pstd}
{bf:Migration Registry}

{synopt:{helpb migrations}}Process Swedish migration registry data for cohort studies{p_end}

{pstd}
{bf:MS Disability Progression}

{synopt:{helpb sustainedss}}Compute the first sustained EDSS threshold date{p_end}
{synopt:{helpb cdp}}Confirmed Disability Progression from baseline EDSS{p_end}
{synopt:{helpb pira}}Progression Independent of Relapse Activity{p_end}


{marker installation}{...}
{title:Installation}

{pstd}
To install or update setools:

{phang2}{cmd:. net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Show the default grouped overview{p_end}
{phang2}{cmd:. setools}{p_end}

{pstd}List only MS-related commands{p_end}
{phang2}{cmd:. setools, list category(ms)}{p_end}

{pstd}Show detailed descriptions for registry-code commands{p_end}
{phang2}{cmd:. setools, detail category(codes)}{p_end}

{pstd}Inspect the returned metadata{p_end}
{phang2}{cmd:. setools, category(migration)}{p_end}
{phang2}{cmd:. return list}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:setools} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of commands in the selected category{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(commands)}}space-separated command list for the selected category{p_end}
{synopt:{cmd:r(version)}}package version{p_end}
{synopt:{cmd:r(categories)}}allowed values for {opt category()}: {cmd:all codes migration ms}{p_end}
{synopt:{cmd:r(category)}}selected category filter{p_end}
{synopt:{cmd:r(display)}}display mode used: {cmd:grouped}, {cmd:list}, or {cmd:detail}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet
{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

{hline}

{smcl}
{* *! version 1.8.7  30jun2026}{...}
{viewerjumpto "Description" "tabtools##description"}{...}
{viewerjumpto "Commands" "tabtools##commands"}{...}
{viewerjumpto "Choosing puttab, comptab, or stacktab" "tabtools##assembly"}{...}
{viewerjumpto "Syntax" "tabtools##syntax"}{...}
{viewerjumpto "Persistent defaults" "tabtools##defaults"}{...}
{viewerjumpto "Examples" "tabtools##examples"}{...}
{viewerjumpto "Stored results" "tabtools##stored"}{...}
{viewerjumpto "Author" "tabtools##author"}{...}
{vieweralsosee "table1_tc" "help table1_tc"}{...}
{vieweralsosee "desctab" "help desctab"}{...}
{vieweralsosee "crosstab" "help crosstab"}{...}
{vieweralsosee "corrtab" "help corrtab"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "comptab" "help comptab"}{...}
{vieweralsosee "hrcomptab" "help hrcomptab"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "stacktab" "help stacktab"}{...}
{vieweralsosee "simtab" "help simtab"}{...}
{vieweralsosee "survtab" "help survtab"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "diagtab" "help diagtab"}{...}
{vieweralsosee "tabtools tips" "help tabtools_tips"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tabtools} {hline 2}}Suite of table export commands for publication-ready Excel and Markdown output{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tabtools} is a suite of Stata commands for exporting tables to professionally
formatted Excel and Markdown files. It covers descriptive statistics, regression results,
treatment effects, survival analysis, diagnostic accuracy, incidence rates,
and composite manuscript tables.

{pstd}
All commands apply consistent Excel and Markdown formatting: column widths, borders, fonts,
merged headers, and professional styling suitable for journal submissions. Use
{cmd:tabtools set} to configure session-wide formatting defaults that every
command respects.

{pstd}
Most commands require Stata 17. The suite controller {cmd:tabtools},
{helpb tabtools_tips}, {helpb table1_tc}, {helpb stacktab}, and {helpb simtab}
also support Stata 16.

{pstd}
See {helpb tabtools_tips:tabtools tips} for the quick-reference option
guide and end-to-end worked recipes.


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Descriptive}

{synoptset 16}{...}
{synopt:{helpb table1_tc}}Table 1 with automatic statistical tests and SMDs{p_end}
{synopt:{helpb desctab}}Per-statistic formatted descriptive tables from {cmd:table} collects{p_end}
{synopt:{helpb crosstab}}Cross-tabulation with association measures{p_end}
{synopt:{helpb corrtab}}Correlation matrix with significance stars{p_end}

{pstd}
{bf:Models}

{synopt:{helpb regtab}}Regression results from any estimation command{p_end}
{synopt:{helpb effecttab}}Treatment effects and margins results{p_end}

{pstd}
{bf:Composite and assembly}

{synopt:{helpb comptab}}Combine selected rows from regtab/effecttab frames into one table{p_end}
{synopt:{helpb hrcomptab}}Combine a stratetab frame with regtab rows into a Table 2-style sheet{p_end}
{synopt:{helpb stacktab}}Assemble already-exported Excel sheets/blocks into one composite sheet{p_end}

{pstd}
{bf:Styled in-memory export}

{synopt:{helpb puttab}}Style one in-memory table (dataset, frame, or matrix) as a single sheet{p_end}

{pstd}
{bf:Rates And Clinical}

{synopt:{helpb survtab}}Kaplan-Meier estimates, medians, and RMST{p_end}
{synopt:{helpb stratetab}}Incidence rates from strate output{p_end}
{synopt:{helpb diagtab}}Sensitivity, specificity, PPV, NPV, ROC{p_end}

{pstd}
{bf:Simulation studies}

{synopt:{helpb simtab}}Monte Carlo simulation performance table (pairs with simsum/siman){p_end}

{pstd}
{bf:Utility}

{synopt:{helpb tabtools}}Suite controller and persistent defaults manager{p_end}
{synopt:{helpb tabtools_tips}}Quick reference and worked recipes{p_end}
{synoptline}


{marker assembly}{...}
{title:Choosing puttab, comptab, or stacktab}

{pstd}
Three commands build a single combined or styled sheet, but they differ by
{it:what they read}:

{pstd}
{bf:{helpb puttab}} reads {it:one table already in memory} — the current
dataset, a {helpb frames:frame}, or a {it:matrix} such as {cmd:e(b)},
{cmd:r(table)}, or a {cmd:collapse}/{cmd:tabulate} result — and writes it as one
styled sheet. It does no analysis: it is the generic styler for raw tables that
have no dedicated tabtools command. Broad on input, single sheet on output.

{pstd}
{bf:{helpb comptab}} reads tabtools {helpb regtab} / {helpb effecttab} {it:frames}
(live estimation results stored with the {cmd:frame()} option) and cherry-picks
selected rows into one composite sheet. Assembly happens at the
{it:estimation} level, so rows can be reordered, relabeled, and grouped before
export. {helpb hrcomptab} is the related builder that attaches {helpb regtab}
rows to a {helpb stratetab} rates scaffold for a Table 2-style sheet.

{pstd}
{bf:{helpb stacktab}} reads sheets that have {it:already been exported} to an
{cmd:.xlsx} workbook and stacks them vertically or side by side, optionally
merging columns. Assembly happens at the {it:spreadsheet} level: it works on
cells and is agnostic to whatever produced them.

{pstd}
{bf:Workflow.} {helpb puttab} and {helpb stacktab} form an emit-then-assemble
pipeline — use {cmd:puttab} to write each styled block to its own sheet, then
{cmd:stacktab} to combine those sheets into the final table. {helpb comptab}
(and {helpb hrcomptab}) is the frame-based sibling of {cmd:stacktab}: reach for
it when the pieces are still tabtools frames rather than exported sheets.

{pstd}
In short: to style one raw table, use {helpb puttab}; to combine estimation
results still in frames, use {helpb comptab} or {helpb hrcomptab}; to combine
sheets already written to a workbook, use {helpb stacktab}.


{marker syntax}{...}
{title:Syntax}

{pstd}
Display available commands

{p 8 17 2}
{cmd:tabtools} [{cmd:,} {opt list} {opt detail} {opt c:ategory(string)}]

{pstd}
Set a formatting default

{p 8 17 2}
{cmd:tabtools set} {it:key} {it:value} [{cmd:,} {opt perm:anent} {opt prof:ile(filename)}]

{pstd}
Clear all formatting defaults

{p 8 17 2}
{cmd:tabtools set clear} [{cmd:,} {opt perm:anent} {opt prof:ile(filename)}]

{pstd}
Display current formatting defaults

{p 8 17 2}
{cmd:tabtools get}

{pstd}
Load formatting defaults from a saved tabtools profile

{p 8 17 2}
{cmd:tabtools use} [{cmd:using} {it:filename}]

{pstd}
{opt list}, {opt detail}, and {opt category()} are display-mode options only.
They are not accepted with {cmd:tabtools set}, {cmd:tabtools get}, or
{cmd:tabtools use}.


{dlgtab:Display options}

{synoptset 22 tabbed}{...}
{synopt:{opt list}}display commands as a simple list{p_end}
{synopt:{opt detail}}show detailed information with descriptions{p_end}
{synopt:{opt c:ategory(string)}}filter by category: {cmd:descriptive}, {cmd:models}, {cmd:rates}, {cmd:survival}, {cmd:diagnostics}, {cmd:composite}, {cmd:export}, {cmd:simulation}, {cmd:general}, {cmd:all}{p_end}
{synoptline}

{dlgtab:Settings keys}

{synoptset 22 tabbed}{...}
{synopt:{cmd:font} {it:name}}font family applied to all cells (e.g., {cmd:Calibri}, {cmd:Times New Roman}){p_end}
{synopt:{cmd:fontsize} {it:#}}font size in points; integer between 6 and 72{p_end}
{synopt:{cmd:borderstyle} {it:name}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{cmd:theme} {it:name}}journal-inspired theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}{p_end}
{synopt:{cmd:digits} {it:#}}decimal digits for numeric output; integer between 0 and 6{p_end}
{synopt:{cmd:boldp} {it:#}}p-value threshold for bold formatting; number between 0 and 1{p_end}
{synopt:{cmd:clear}}remove all persistent defaults{p_end}
{synoptline}

{dlgtab:Profile options}

{synoptset 22 tabbed}{...}
{synopt:{opt perm:anent}}after applying {cmd:tabtools set}, write the current defaults to a disk profile{p_end}
{synopt:{opt prof:ile(filename)}}write or read an alternate profile file; default is {cmd:tabtools_profile.do} in Stata's PERSONAL ado directory{p_end}
{synoptline}

{pstd}
The {cmd:academic} border style uses horizontal rules only (top, header bottom,
table bottom) with no vertical borders, following journal conventions.

{pstd}
A {cmd:custom} theme accepts additional options on the same line:

{p 8 17 2}
{cmd:tabtools set theme custom, font(}{it:name}{cmd:)}
{cmd:fontsize(}{it:#}{cmd:) headercolor(}{it:color}{cmd:) zebracolor(}{it:color}{cmd:)}
{cmd:borderstyle(}{it:name}{cmd:)}

{synoptset 22 tabbed}{...}
{synopthdr:custom-theme option}
{synoptline}
{synopt:{opt font(string)}}font family for the custom theme{p_end}
{synopt:{opt fontsize(#)}}font size in points for the custom theme{p_end}
{synopt:{opt headerc:olor(string)}}header fill: supported Stata color name or RGB triplet{p_end}
{synopt:{opt zebrac:olor(string)}}zebra fill: supported Stata color name or RGB triplet{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synoptline}

{pstd}
{it:color} may be either a supported Stata color name such as {cmd:navy} or an RGB
triplet such as {cmd:"200 220 240"}. Omitted custom-theme suboptions reset
that component to the command default the next time {cmd:tabtools set theme custom}
is run.

{pstd}
The builder-style options {cmd:font()}, {cmd:fontsize()}, {cmd:headercolor()},
{cmd:zebracolor()}, and {cmd:borderstyle()} are only valid with
{cmd:tabtools set theme custom}. If a named non-{cmd:custom} theme is active,
direct {cmd:tabtools set font}, {cmd:set fontsize}, and
{cmd:set borderstyle} first resolve that named theme to {cmd:custom}, then
apply the requested override.


{marker defaults}{...}
{title:Persistent defaults}

{pstd}
{cmd:tabtools set} stores formatting defaults in Stata global macros for the
current session. Every tabtools command checks these globals before applying
its own defaults, so you can configure formatting once and have it apply
everywhere.

{pstd}
Add {opt permanent} to save the current defaults as a runnable Stata profile.
By default, {cmd:tabtools set ..., permanent} writes
{cmd:tabtools_profile.do} in Stata's PERSONAL ado directory. Use
{cmd:profile(filename)} to save a project-specific house style somewhere else.
The saved profile contains ordinary {cmd:tabtools set} commands, so it can be
read, version controlled, and run as a do-file.

{pstd}
{cmd:tabtools get} reports the effective values that commands will use. Under a
named theme such as {cmd:lancet}, this means the resolved theme values rather
than any stale raw globals left over from earlier custom settings.

{pstd}
{cmd:tabtools use} loads a saved profile into the current session. With no
{cmd:using} file, it reads the default PERSONAL profile; with {cmd:using}, it
reads the named project profile.

{pstd}
After {cmd:tabtools set clear} or in a fresh session, the baseline resolved
defaults reported by {cmd:tabtools get} are {cmd:Arial}, {cmd:10}, and
{cmd:thin}.

{pstd}
Defaults remain session globals while Stata is running. The disk profile is
only read when you run {cmd:tabtools use} or source it from your own
{cmd:profile.do}.

{phang2}{cmd:. tabtools set font Calibri}{p_end}
{phang2}{cmd:. tabtools set fontsize 11}{p_end}
{phang2}{cmd:. tabtools set borderstyle academic}{p_end}
{phang2}{cmd:. tabtools set theme lancet, permanent}{p_end}
{phang2}{cmd:. tabtools use}{p_end}
{phang2}{cmd:. tabtools set theme custom, font(Arial) fontsize(9) permanent profile("project_tabtools.do")}{p_end}
{phang2}{cmd:. tabtools use using "project_tabtools.do"}{p_end}
{phang2}{cmd:. tabtools get}{p_end}
{phang2}{cmd:. tabtools set clear}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Set defaults for a manuscript}

{phang2}{cmd:. tabtools set font "Times New Roman"}{p_end}
{phang2}{cmd:. tabtools set fontsize 10}{p_end}
{phang2}{cmd:. tabtools set borderstyle academic}{p_end}

{pstd}
{bf:View current defaults}

{phang2}{cmd:. tabtools get}{p_end}

{pstd}
{bf:Apply a journal theme}

{phang2}{cmd:. tabtools set theme lancet, permanent}{p_end}
{phang2}{cmd:. tabtools use}{p_end}

{pstd}
{bf:Custom theme with specific colors}

{phang2}{cmd:. tabtools set theme custom, font(Arial) fontsize(9) headercolor("200 220 240") borderstyle(thin)}{p_end}

{pstd}
{bf:Project-specific profile}

{phang2}{cmd:. tabtools set theme custom, font(Arial) fontsize(9) headercolor("200 220 240") borderstyle(thin) permanent profile("tabtools_project.do")}{p_end}
{phang2}{cmd:. tabtools set clear}{p_end}
{phang2}{cmd:. tabtools use using "tabtools_project.do"}{p_end}

{pstd}
{bf:Reset to command defaults}

{phang2}{cmd:. tabtools set clear}{p_end}

{pstd}
{bf:Browse available commands}

{phang2}{cmd:. tabtools}{p_end}
{phang2}{cmd:. tabtools, list}{p_end}
{phang2}{cmd:. tabtools, detail}{p_end}
{phang2}{cmd:. tabtools, category(descriptive)}{p_end}
{phang2}{cmd:. tabtools, category(export)}{p_end}


{marker stored}{...}
{title:Stored results}

{pstd}
{cmd:tabtools} (display mode) stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(n_commands)}}number of commands in the suite{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(commands)}}space-separated list of command names{p_end}
{synopt:{cmd:r(version)}}package version{p_end}
{synopt:{cmd:r(categories)}}space-separated list of categories{p_end}

{pstd}
{cmd:tabtools set} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(fontsize)}}font size (when setting fontsize){p_end}
{synopt:{cmd:r(digits)}}digits (when setting digits){p_end}
{synopt:{cmd:r(boldp)}}boldp threshold (when setting boldp){p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(font)}}font name (when setting font){p_end}
{synopt:{cmd:r(borderstyle)}}border style (when setting borderstyle){p_end}
{synopt:{cmd:r(theme)}}theme name (when setting theme){p_end}
{synopt:{cmd:r(action)}}{cmd:"cleared"} (when using {cmd:set clear}){p_end}
{synopt:{cmd:r(permanent)}}{cmd:"permanent"} (when saving a disk profile){p_end}
{synopt:{cmd:r(profile)}}profile path written by {cmd:permanent}{p_end}

{pstd}
{cmd:tabtools get} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(font)}}effective current font name{p_end}
{synopt:{cmd:r(fontsize)}}effective current font size{p_end}
{synopt:{cmd:r(borderstyle)}}effective current border style{p_end}
{synopt:{cmd:r(theme)}}current theme name{p_end}
{synopt:{cmd:r(headercolor)}}effective current header color setting{p_end}
{synopt:{cmd:r(zebracolor)}}effective current zebra stripe color setting{p_end}
{synopt:{cmd:r(digits)}}current digits setting{p_end}
{synopt:{cmd:r(boldp)}}current boldp setting{p_end}

{pstd}
{cmd:tabtools use} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(action)}}{cmd:"loaded"}{p_end}
{synopt:{cmd:r(profile)}}profile path loaded{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.8.7{p_end}

{hline}

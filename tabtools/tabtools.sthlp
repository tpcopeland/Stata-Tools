{smcl}
{* *! version 1.5.0  06jun2026}{...}
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
{vieweralsosee "survtab" "help survtab"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "diagtab" "help diagtab"}{...}
{vieweralsosee "tabtools cheatsheet" "help tabtools_cheatsheet"}{...}
{vieweralsosee "tabtools cookbook" "help tabtools_cookbook"}{...}
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
Most commands require Stata 17. The suite controller {cmd:tabtools} and
{helpb table1_tc} also support Stata 16.

{pstd}
See {helpb tabtools_cheatsheet:tabtools cheatsheet} for a quick-reference
option guide and {helpb tabtools_cookbook:tabtools cookbook} for end-to-end
worked examples.


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
{bf:Utility}

{synopt:{helpb tabtools}}Suite controller and persistent defaults manager{p_end}
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
{bf:{helpb comptab}} reads tabtools {helpb regtab}/{helpb effecttab} {it:frames}
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
{cmd:tabtools set} {it:key} {it:value}

{pstd}
Clear all formatting defaults

{p 8 17 2}
{cmd:tabtools set clear}

{pstd}
Display current formatting defaults

{p 8 17 2}
{cmd:tabtools get}

{pstd}
{opt list}, {opt detail}, and {opt category()} are display-mode options only.
They are not accepted with {cmd:tabtools set} or {cmd:tabtools get}.


{dlgtab:Display options}

{synoptset 22 tabbed}{...}
{synopt:{opt list}}display commands as a simple list{p_end}
{synopt:{opt detail}}show detailed information with descriptions{p_end}
{synopt:{opt c:ategory(string)}}filter by category: {cmd:descriptive}, {cmd:models}, {cmd:rates}, {cmd:survival}, {cmd:diagnostics}, {cmd:composite}, {cmd:export}, {cmd:general}, {cmd:all}{p_end}
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

{pstd}
The {cmd:academic} border style uses horizontal rules only (top, header bottom,
table bottom) with no vertical borders, following journal conventions.

{pstd}
A {cmd:custom} theme accepts additional options on the same line:

{p 8 17 2}
{cmd:tabtools set theme custom, font(}{it:name}{cmd:) fontsize(}{it:#}{cmd:) headercolor(}{it:color}{cmd:) zebracolor(}{it:color}{cmd:) borderstyle(}{it:name}{cmd:)}

{synoptset 22 tabbed}{...}
{synopthdr:custom-theme option}
{synoptline}
{synopt:{opt font(string)}}font family for the custom theme{p_end}
{synopt:{opt fontsize(#)}}font size in points for the custom theme{p_end}
{synopt:{opt headerc:olor(string)}}header fill: named Excel color or RGB triplet{p_end}
{synopt:{opt zebrac:olor(string)}}zebra fill: named Excel color or RGB triplet{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synoptline}

{pstd}
{it:color} may be either a named Excel color such as {cmd:navy} or an RGB
triplet such as {cmd:"200 220 240"}. Omitted custom-theme suboptions reset
that component to the command default the next time {cmd:tabtools set theme custom}
is run.

{pstd}
The builder-style options {cmd:font()}, {cmd:fontsize()}, {cmd:headercolor()},
{cmd:zebracolor()}, and {cmd:borderstyle()} are only valid with
{cmd:tabtools set theme custom}. If a named non-{cmd:custom} theme is active,
direct {cmd:tabtools set font}, {cmd:set fontsize}, and
{cmd:set borderstyle} are rejected so they cannot silently do nothing.


{marker defaults}{...}
{title:Persistent defaults}

{pstd}
{cmd:tabtools set} stores formatting defaults in Stata global macros for the
current session. Every tabtools command checks these globals before applying
its own defaults, so you can configure formatting once and have it apply
everywhere.

{pstd}
{cmd:tabtools get} reports the effective values that commands will use. Under a
named theme such as {cmd:lancet}, this means the resolved theme values rather
than any stale raw globals left over from earlier custom settings.

{pstd}
After {cmd:tabtools set clear} or in a fresh session, the baseline resolved
defaults reported by {cmd:tabtools get} are {cmd:Arial}, {cmd:10}, and
{cmd:thin}.

{pstd}
Defaults are session-only: they are lost when Stata is closed or restarted.
Add {cmd:tabtools set} commands to your {cmd:profile.do} for persistence
across sessions.

{phang2}{cmd:. tabtools set font Calibri}{p_end}
{phang2}{cmd:. tabtools set fontsize 11}{p_end}
{phang2}{cmd:. tabtools set borderstyle academic}{p_end}
{phang2}{cmd:. tabtools set theme lancet}{p_end}
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

{phang2}{cmd:. tabtools set theme lancet}{p_end}

{pstd}
{bf:Custom theme with specific colors}

{phang2}{cmd:. tabtools set theme custom, font(Arial) fontsize(9) headercolor("200 220 240") borderstyle(thin)}{p_end}

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


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{p_end}
{pstd}{bf:Version} 1.5.0{p_end}

{hline}

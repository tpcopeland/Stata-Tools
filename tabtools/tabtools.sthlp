{smcl}
{* *! version 1.0.0  08apr2026}{...}
{viewerjumpto "Description" "tabtools##description"}{...}
{viewerjumpto "Commands" "tabtools##commands"}{...}
{viewerjumpto "Syntax" "tabtools##syntax"}{...}
{viewerjumpto "Persistent defaults" "tabtools##defaults"}{...}
{viewerjumpto "Examples" "tabtools##examples"}{...}
{viewerjumpto "Stored results" "tabtools##stored"}{...}
{viewerjumpto "Author" "tabtools##author"}{...}
{vieweralsosee "table1_tc" "help table1_tc"}{...}
{vieweralsosee "crosstab" "help crosstab"}{...}
{vieweralsosee "corrtab" "help corrtab"}{...}
{vieweralsosee "regtab" "help regtab"}{...}
{vieweralsosee "effecttab" "help effecttab"}{...}
{vieweralsosee "comptab" "help comptab"}{...}
{vieweralsosee "survtab" "help survtab"}{...}
{vieweralsosee "stratetab" "help stratetab"}{...}
{vieweralsosee "diagtab" "help diagtab"}{...}
{vieweralsosee "fittab" "help fittab"}{...}
{vieweralsosee "hrtab" "help hrtab"}{...}
{vieweralsosee "tablex" "help tablex"}{...}
{vieweralsosee "tabtools cheatsheet" "help tabtools_cheatsheet"}{...}
{vieweralsosee "tabtools cookbook" "help tabtools_cookbook"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tabtools} {hline 2}}Suite of table export commands for publication-ready Excel output{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tabtools} is a suite of Stata commands for exporting tables to professionally
formatted Excel files. It covers descriptive statistics, regression results,
treatment effects, survival analysis, diagnostic accuracy, incidence rates,
model comparison, and general-purpose table export.

{pstd}
All commands apply consistent Excel formatting: column widths, borders, fonts,
merged headers, and professional styling suitable for journal submissions. Use
{cmd:tabtools set} to configure session-wide formatting defaults that every
command respects.

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
{synopt:{helpb crosstab}}Cross-tabulation with association measures{p_end}
{synopt:{helpb corrtab}}Correlation matrix with significance stars{p_end}

{pstd}
{bf:Regression}

{synopt:{helpb regtab}}Regression results from any estimation command{p_end}
{synopt:{helpb effecttab}}Treatment effects and margins results{p_end}
{synopt:{helpb comptab}}Combine regtab/effecttab frames into one table{p_end}

{pstd}
{bf:Clinical}

{synopt:{helpb survtab}}Kaplan-Meier estimates, medians, and RMST{p_end}
{synopt:{helpb hrtab}}Multi-panel hazard ratio table (stcox/stcrreg/finegray){p_end}
{synopt:{helpb stratetab}}Incidence rates from strate output{p_end}
{synopt:{helpb diagtab}}Sensitivity, specificity, PPV, NPV, ROC{p_end}
{synopt:{helpb fittab}}Model comparison table (AIC, BIC, C-statistic){p_end}

{pstd}
{bf:Utility}

{synopt:{helpb tablex}}Flexible table export wrapper{p_end}
{synoptline}


{marker syntax}{...}
{title:Syntax}

{pstd}
Display available commands

{p 8 17 2}
{cmd:tabtools} [{cmd:,} {opt list} {opt detail} {opt cat:egory(string)}]

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


{dlgtab:Display options}

{synoptset 22 tabbed}{...}
{synopt:{opt list}}display commands as a simple list{p_end}
{synopt:{opt detail}}show detailed information with descriptions{p_end}
{synopt:{opt cat:egory(string)}}filter by category: {cmd:descriptive}, {cmd:models}, {cmd:rates}, {cmd:survival}, {cmd:diagnostics}, {cmd:composite}, {cmd:general}, {cmd:all}{p_end}
{synoptline}

{dlgtab:Settings keys}

{synoptset 22 tabbed}{...}
{synopt:{cmd:font} {it:name}}font family applied to all cells (e.g., {cmd:Calibri}, {cmd:Times New Roman}){p_end}
{synopt:{cmd:fontsize} {it:#}}font size in points; integer between 6 and 72{p_end}
{synopt:{cmd:borderstyle} {it:name}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{cmd:theme} {it:name}}journal theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, or {cmd:custom}{p_end}
{synopt:{cmd:clear}}remove all persistent defaults{p_end}
{synoptline}

{pstd}
The {cmd:academic} border style uses horizontal rules only (top, header bottom,
table bottom) with no vertical borders, following journal conventions.

{pstd}
A {cmd:custom} theme accepts additional options on the same line:

{p 8 17 2}
{cmd:tabtools set theme custom, font(}{it:name}{cmd:) fontsize(}{it:#}{cmd:) headercolor(}{it:color}{cmd:) zebracolor(}{it:color}{cmd:) borderstyle(}{it:name}{cmd:)}


{marker defaults}{...}
{title:Persistent defaults}

{pstd}
{cmd:tabtools set} stores formatting defaults in Stata global macros for the
current session. Every tabtools command checks these globals before applying
its own defaults, so you can configure formatting once and have it apply
everywhere.

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

{phang2}{cmd:. tabtools set theme custom, font(Arial) fontsize(9) headercolor(navy) borderstyle(thin)}{p_end}

{pstd}
{bf:Reset to command defaults}

{phang2}{cmd:. tabtools set clear}{p_end}

{pstd}
{bf:Browse available commands}

{phang2}{cmd:. tabtools}{p_end}
{phang2}{cmd:. tabtools, list}{p_end}
{phang2}{cmd:. tabtools, detail}{p_end}
{phang2}{cmd:. tabtools, category(descriptive)}{p_end}


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

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(font)}}font name (when setting font){p_end}
{synopt:{cmd:r(borderstyle)}}border style (when setting borderstyle){p_end}
{synopt:{cmd:r(theme)}}theme name (when setting theme){p_end}
{synopt:{cmd:r(action)}}{cmd:"cleared"} (when using {cmd:set clear}){p_end}

{pstd}
{cmd:tabtools get} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(font)}}current font name{p_end}
{synopt:{cmd:r(fontsize)}}current font size{p_end}
{synopt:{cmd:r(borderstyle)}}current border style{p_end}
{synopt:{cmd:r(theme)}}current theme name{p_end}
{synopt:{cmd:r(headercolor)}}current header color setting{p_end}
{synopt:{cmd:r(zebracolor)}}current zebra stripe color setting{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}
{p_end}

{pstd}
{bf:Version} 1.0.0

{hline}

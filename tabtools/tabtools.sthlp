{smcl}
{* *! version 2.5.6  07oct2026}{...}
{viewerjumpto "Description" "tabtools##description"}{...}
{viewerjumpto "Commands" "tabtools##commands"}{...}
{viewerjumpto "Choosing puttab, comptab, or stacktab" "tabtools##assembly"}{...}
{viewerjumpto "Syntax" "tabtools##syntax"}{...}
{viewerjumpto "Options" "tabtools##options"}{...}
{viewerjumpto "Persistent defaults" "tabtools##defaults"}{...}
{viewerjumpto "Interval separators" "tabtools##sep"}{...}
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
{vieweralsosee "ratetab" "help ratetab"}{...}
{vieweralsosee "tabcell" "help tabcell"}{...}
{vieweralsosee "outtab" "help outtab"}{...}
{vieweralsosee "tabtools tips" "help tabtools_tips"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:tabtools} {hline 2}}Suite of table export commands for publication-ready Excel and Markdown output{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tabtools} is a suite of Stata commands for exporting tables to professionally
formatted Excel and Markdown files. It covers descriptive statistics,
regression results, treatment effects, survival analysis, incidence rates, and
composite manuscript tables.

{pstd}
All commands apply consistent Excel and Markdown formatting: column widths,
borders, fonts, merged headers, and professional styling suitable for journal
submissions. Use {cmd:tabtools set} to configure session-wide formatting defaults
that every command respects.

{pstd}
Every exported workbook cell is written as text, including cells that look
numeric. Published table cells are frequently composite or annotated strings
({cmd:5,351 (60)}, {cmd:0.82 (0.69, 0.98)}, {cmd:<0.001}, {cmd:Reference}), and
each cell is rendered to its final string before any sink runs; re-deriving a
numeric type by reparsing that string would have to guess. Excel will therefore
not sum, chart, or numerically sort an exported column without a conversion
step. For a numeric payload use {cmd:frame()}, the returned matrices such as
{cmd:r(table)}, or {cmd:eplotframe()}.

{pstd}
File outputs follow one contract in every command. {opt csv()} must name a
{cmd:.csv} file, and the workbook ({opt xlsx()}, {opt excel()}, or
{cmd:using}), {opt csv()}, and {opt markdown()} must name different files: paths
are compared after resolving them against the working directory and
ignoring case, and a collision is refused before anything is written. An
existing {opt markdown()} file is replaced; {opt mdappend} appends to it
instead. Markdown text is written literally: it is never macro-expanded, and
{cmd:\ | * _} backtick {cmd:< > & [ ] ~} are backslash-escaped so that data
render as the text they contain rather than as emphasis, HTML, entities,
links, strikethrough, or code. Line breaks become {cmd:<br>} and first-column indentation
becomes {cmd:&nbsp;}.

{pstd}
Output filenames may contain spaces and Unicode. Filename validation rejects
either quote character, dollar signs, backticks, semicolons, ampersands, pipes,
and angle brackets.

{pstd}
{opt title()}, {opt footnote()}, and {cmd:stacktab}'s {opt note()} text reaches
the console, workbook, CSV, and Markdown output as typed: a quoted local-macro
reference, a {cmd:$}{it:name}, or a lone backtick inside it is kept as text and
never expanded by the command. Stata itself expands macros on the command line
before the command runs, so to pass such text, build it in a local macro and
give it as {cmd:title(`"`macval(}{it:mac}{cmd:)'"')}. One limit comes from Stata's
parser, not from these commands: text that ends in a backtick cannot be given
inside compound quotes (the backtick joins the closing quote), and the call
stops with r(198) "unmatched quote" before anything is written; end the text
with another character.

{pstd}
{helpb table1_tc}, {helpb desctab}, and {helpb crosstab} accept
{opt smallcells(#)} for strict disclosure control. They replace protected
positive counts with {cmd:<#}, use {cmd:≥#} for complementary suppression, and
withhold dependent results before console, Excel, CSV, Markdown, frame, or
stored-result output is built. See each command's help for its supported
layouts and fail-closed limits. A deterministic final pass removes every
individually redundant complementary marker; the retained set is irredundant
but not guaranteed globally minimum.

{pstd}
All commands require Stata 17 or newer.

{pstd}
See {helpb tabtools_tips:tabtools tips} for the quick-reference option
guide and end-to-end worked recipes.


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Descriptive}

{synoptset 16}{...}
{synopt:{helpb table1_tc}}Table 1 with automatic statistical tests and SMDs{p_end}
{synopt:{helpb desctab}}Consolidated descriptive engine used by {cmd:table1_tc}{p_end}
{synopt:{helpb crosstab}}Cross-tabulation with association measures{p_end}
{synopt:{helpb corrtab}}Correlation matrix with significance stars{p_end}

{pstd}
{bf:Models}

{synopt:{helpb regtab}}Regression results from any estimation command{p_end}
{synopt:{helpb effecttab}}Treatment effects and margins results{p_end}
{synopt:{helpb tabcell}}One estimate (CI), p-value, n (%), or median (IQR) cell{p_end}
{synopt:{helpb outtab}}Binary outcomes by exposure with model ratios{p_end}

{pstd}
{bf:Composite and assembly}

{synopt:{helpb comptab}}Combine model rows vertically or with a rate scaffold{p_end}
{synopt:{helpb hrcomptab}}Compatibility wrapper for comptab rate mode{p_end}
{synopt:{helpb stacktab}}Assemble exported Excel blocks{p_end}

{pstd}
{bf:Styled in-memory export}

{synopt:{helpb puttab}}Style one in-memory table{p_end}

{pstd}
{bf:Rates And Clinical}

{synopt:{helpb survtab}}Kaplan-Meier estimates, medians, and RMST{p_end}
{synopt:{helpb stratetab}}Incidence rates from strate output{p_end}
{synopt:{helpb ratetab}}Events, person-time, and rates with exact or robust CIs{p_end}

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
selected rows into one composite sheet. With {cmd:rateframe()}, it instead
attaches {helpb regtab} rows to a {helpb stratetab} rates scaffold for a
Table 2-style sheet. {helpb hrcomptab} is the specialized compatibility
wrapper for that mode.

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
{cmd:tabtools} [{cmd:,} {opt l:ist} {opt d:etail} {opt c:ategory(string)}]

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
Set or clear a session destination or masking default

{p 8 17 2}
{cmd:tabtools set} {c -(}{cmd:workbook}|{cmd:markdown}{c )-} {it:filename}

{p 8 17 2}
{cmd:tabtools set headershade} {c -(}{cmd:on}|{cmd:off}{c )-}

{p 8 17 2}
{cmd:tabtools set smallcells} {it:#} [{cmd:primary}]

{p 8 17 2}
{cmd:tabtools set} {it:sessionkey} {cmd:clear}

{pstd}
Display the session destinations and masking default

{p 8 17 2}
{cmd:tabtools query}

{pstd}
Store fit-time counts for {helpb regtab} right after a {cmd:collect:} fit

{p 8 17 2}
{cmd:tabtools fitcount}{cmd:,} {opt events(varname)} [{opt people(varname)}
{opt exposure(varname)} {opt terms} {opt name(collection)}]

{pstd}
Load formatting defaults from a saved tabtools profile

{p 8 17 2}
{cmd:tabtools use} [{cmd:using} {it:filename}]

{pstd}
{opt list}, {opt detail}, and {opt category()} are display-mode options only. They are not
accepted with {cmd:tabtools set}, {cmd:tabtools get}, or {cmd:tabtools use}.


{marker options}{...}
{title:Options}

{dlgtab:Display options}

{synoptset 22 tabbed}{...}
{synopt:{opt list}}display commands as a simple list{p_end}
{synopt:{opt detail}}show detailed information with descriptions{p_end}
{synopt:{opt c:ategory(string)}}filter the command list by category{p_end}
{synoptline}

{dlgtab:Settings keys}

{synoptset 22 tabbed}{...}
{synopt:{cmd:font} {it:name}}set the default font family{p_end}
{synopt:{cmd:fontsize} {it:#}}font size in points; integer between 6 and 72{p_end}
{synopt:{cmd:borderstyle} {it:name}}border style: {cmd:default}, {cmd:thin}, {cmd:medium}, or {cmd:academic}{p_end}
{synopt:{cmd:headercolor} {it:color}}default header fill color{p_end}
{synopt:{cmd:zebracolor} {it:color}}default zebra fill color{p_end}
{synopt:{cmd:digits} {it:#}}numeric display digits; integer from 0 to 6{p_end}
{synopt:{cmd:boldp} {it:#}}p-value threshold for bold formatting{p_end}
{synopt:{cmd:clear}}clear all persistent defaults and session keys{p_end}
{synoptline}

{dlgtab:Session keys}

{synoptset 22 tabbed}{...}
{synopt:{cmd:workbook} {it:filename}}default {cmd:.xlsx} target for {helpb puttab}{p_end}
{synopt:{cmd:markdown} {it:filename}}default Markdown target for {helpb puttab}{p_end}
{synopt:{cmd:headershade} {it:on|off}}header shading default ({helpb puttab} only){p_end}
{synopt:{cmd:smallcells} {it:#} [{cmd:primary}]}default small-cell masking{p_end}
{synopt:{cmd:borderstyle} {it:name}|{cmd:clear}}border style of every command with {opt borderstyle()}{p_end}
{synoptline}

{pstd}
Session keys live for the Stata session only; {opt permanent} is refused for
them. An explicit option in a call always wins over a session key. Paths are stored
absolute ({cmd:.} and {cmd:..} resolved; symbolic links and letter case are
not), so a later {cmd:cd} does not move them. The first write to a session
workbook or Markdown file replaces it, and later writes add sheets or append. A
table any tabtools command writes to that file with an explicit {cmd:using},
{opt xlsx()}, or {opt markdown()} counts as that first write. Setting a
different file re-arms the replace; setting the current file again changes
nothing; and a file already written as a session target in this Stata session
is never replaced, even after {cmd:tabtools set clear}, so switching from A to B
and back to A keeps A's tables. Every command that
uses a session key echoes the resolved value in the log. {helpb desctab},
{helpb table1_tc}, {helpb crosstab}, {helpb corrtab}, {helpb regtab},
{helpb effecttab}, {helpb comptab}, {helpb hrcomptab}, {helpb survtab}, and
{helpb stratetab} use a session workbook or Markdown file only when {opt sheet()}
is given. When {opt sheet()} is given and there is neither {opt xlsx()} nor a
session workbook, {cmd:desctab} and {cmd:table1_tc} exit with r(498), and the
others print {cmd:(tabtools: sheet() ignored; no xlsx() and no session workbook)}. {helpb puttab}
and {helpb stacktab} use the session workbook whenever
{cmd:using} is omitted. {cmd:smallcells} is honoured by
{helpb desctab}, {helpb table1_tc}, {helpb crosstab}, {helpb stratetab},
{helpb ratetab}, and {helpb outtab}; {opt nosmallcells} turns it off for one
call. {cmd:borderstyle} is both a settings key and a session key: it takes the
values the {opt borderstyle()} option takes ({cmd:default}, {cmd:thin},
{cmd:medium}, {cmd:academic}, in lower case), every command with a
{opt borderstyle()} option uses it when that option is not given (an explicit
{opt borderstyle()} wins), {cmd:tabtools query} reports it,
{cmd:tabtools set borderstyle clear} removes it, and, unlike the other session
keys, {opt permanent} saves it to a
profile. {it:Session destinations} in {helpb puttab} has the details.

{pstd}
{cmd:tabtools fitcount} counts events, people (distinct values of {opt people()}),
and person-time ({opt exposure()}) on {cmd:e(sample)} of the active fit and,
with {opt terms}, events per factor level, and stores them with the collected
model so that {helpb regtab} {cmd:stats(events people exposure)} and
{cmd:mincount()} can use them. With {opt people()} it also counts the people with
an event (distinct {opt people()} values with {opt events()} > 0), stored as
{cmd:tt_people_ev} for {helpb regtab}
{cmd:stats(e(tt_people_ev)="People with an event")}. Run it immediately after the
{cmd:collect:} fit. The
active fit must be the collected one: its {cmd:e(cmdline)}, {cmd:e(N)}, and
{cmd:e(b)} must match the collected model, or the command exits with error
459. {opt name()} names the collection when the fit used {cmd:collect, name():}. Counts
are unweighted; {cmd:fweight}s and {cmd:iweight}s and {cmd:svy, subpop()}
fits are refused. See {help regtab:regtab} ("Fit-time counts").

{dlgtab:Profile options}

{synoptset 22 tabbed}{...}
{synopt:{opt perm:anent}}persist current defaults to disk{p_end}
{synopt:{opt prof:ile(filename)}}write or read an alternate profile file{p_end}
{synoptline}

{pstd}
The {cmd:academic} border style uses horizontal rules only (top, header bottom,
table bottom) with no vertical borders, following journal conventions.

{dlgtab:Detailed option contracts}

{phang}
{cmd:borderstyle} {it:name} sets the persistent border style to {cmd:default},
{cmd:thin}, {cmd:medium}, or {cmd:academic}.{p_end}

{phang}
{opt c:ategory(string)} filter by category: {cmd:descriptive}, {cmd:models}, {cmd:rates},
{cmd:survival}, {cmd:composite}, {cmd:export}, {cmd:general},
{cmd:all}{p_end}

{phang}
{opt detail} show detailed information with descriptions{p_end}

{phang}
{cmd:font} {it:name} sets the persistent font family.{p_end}

{phang}
{cmd:fontsize} {it:#} sets the persistent font size to an integer from 6 through 72.{p_end}

{phang}
{cmd:headercolor} {it:color} sets the persistent header fill to a supported
Stata color name or RGB triplet.{p_end}

{phang}
{opt list} display commands as a simple list{p_end}

{phang}
{opt perm:anent} after applying {cmd:tabtools set}, write the current defaults to a disk profile{p_end}

{phang}
{opt prof:ile(filename)} write or read an alternate profile file; default is
{cmd:tabtools_profile.do} in Stata's PERSONAL ado directory{p_end}

{phang}
{cmd:zebracolor} {it:color} sets the persistent zebra fill to a supported
Stata color name or RGB triplet.{p_end}

{marker defaults}{...}
{title:Persistent defaults}

{pstd}
{cmd:tabtools set} stores formatting defaults in Stata global macros for the
current session. Every tabtools command checks these globals before applying
its own defaults, so you can configure formatting once and have it apply
everywhere.

{pstd}
Add {opt permanent} to save the current defaults as a runnable Stata profile. By
default, {cmd:tabtools set ..., permanent} writes {cmd:tabtools_profile.do} in Stata's
PERSONAL ado directory. Use {cmd:profile(filename)} to save a project-specific house
style somewhere else. The saved profile contains ordinary {cmd:tabtools set}
commands, so it can be read, version controlled, and run as a do-file.

{pstd}
{cmd:tabtools get} reports the effective values that commands will use.

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
{phang2}{cmd:. tabtools use}{p_end}
{phang2}{cmd:. tabtools use using "project_tabtools.do"}{p_end}
{phang2}{cmd:. tabtools get}{p_end}
{phang2}{cmd:. tabtools set clear}{p_end}


{marker sep}{...}
{title:Interval separators}

{pstd}
{helpb regtab}, {helpb effecttab}, {helpb ratetab}, {helpb stratetab},
{helpb outtab}, and {helpb tabcell} take {opt sep(string)}, and
{helpb comptab} and {helpb hrcomptab} take {opt cisep(string)}: the text
printed between the two limits of a confidence interval, {cmd:(1.02, 1.31)}
by default. One contract holds in all of them.

{phang}
1. Every command reads the option as Stata reads any string option. Text in
simple or compound double quotes is kept exactly, blanks included, and the
quotes are removed: {cmd:sep(" to ")} and {cmd:sep( " to " )} both print
{cmd:(1.02 to 1.31)}. Blanks outside quotes are dropped, and two or more
pieces are joined by a single blank: {cmd:sep( - )} prints {cmd:(1.02-1.31)},
{cmd:sep(a  b)} and {cmd:sep("a" "b")} print {cmd:(1.02a b1.31)}. Quote a
separator whose blanks matter. An omitted or empty separator, {cmd:sep("")},
is the default {cmd:", "}.{p_end}

{phang}
2. The text is data and prints byte for byte, as typed. Nothing in it is
expanded or changed: a dollar sign, a backquote, {cmd:%}, a parenthesis, a
comma, Unicode such as the en dash, and a double quote (typed inside compound
quotes, {cmd:sep(`"a"b"')}) all print as they are. A {cmd:$}{it:name} that
reaches the option (typed {cmd:\$}{it:name} in a do-file) prints as those
characters, never as the global's contents.{p_end}

{phang}
3. It reaches every output unchanged: the console, Excel, CSV (quoted as CSV
requires), Markdown (escaped so that it displays as typed), {opt frame()} with
or without {cmd:flat}, and a stored cell ({cmd:tabcell}'s {cmd:r(cell)},
{opt local()}, {opt global()}, and {opt generate()}). {helpb comptab} and
{helpb hrcomptab} keep the separator their source frames hold, except where
{opt cformat()} rebuilds an interval from its numbers: that interval takes
{opt cisep()}, or {cmd:", "} without it.{p_end}

{phang}
4. The limits are never read back from the printed text: {cmd:r(table)},
{opt eplotframe()}, and the other numeric results hold them as numbers, so a
separator that looks like a minus sign ({cmd:sep("-")}) or a thousands
separator ({cmd:sep(",")}) cannot change them.{p_end}

{phang}
5. A separator that contains a comma (the default included) beside limits in
a decimal-comma format such as {cmd:%9,2f} makes the two limits hard to tell
apart. {helpb regtab} and {helpb effecttab} refuse it with r(198); the other
commands print the table as before and show a one-line
warning. {opt cisep()} without {opt cformat()} on an interval that is not in the
default {cmd:(}{it:a}{cmd:, }{it:b}{cmd:)} form is an error, because that text
is rewritten rather than rebuilt from numbers.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Set defaults for a manuscript}

{phang2}{cmd:. tabtools set font "Times New Roman"}{p_end}
{phang2}{cmd:. tabtools set fontsize 10}{p_end}
{phang2}{cmd:. tabtools set borderstyle academic}{p_end}

{pstd}
{bf:A session border style, overridden for one table}

{phang2}{cmd:. tabtools set borderstyle academic}{p_end}
{phang2}{cmd:. tabtools query}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. crosstab rep78 foreign, xlsx(tables.xlsx) sheet("Academic")}{p_end}
{phang2}{cmd:. crosstab rep78 foreign, xlsx(tables.xlsx) sheet("Boxed") borderstyle(thin)}{p_end}
{phang2}{cmd:. tabtools set borderstyle clear}{p_end}

{pstd}
{bf:View current defaults}

{phang2}{cmd:. tabtools get}{p_end}

{pstd}
{bf:Project-specific profile}

{phang2}{cmd:. tabtools set font Arial, permanent profile("tabtools_project.do")}{p_end}
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
{synopt:{cmd:r(headercolor)}}header color (when setting headercolor){p_end}
{synopt:{cmd:r(zebracolor)}}zebra color (when setting zebracolor){p_end}
{synopt:{cmd:r(action)}}{cmd:"cleared"} (when using {cmd:set clear} or {cmd:set} {it:key} {cmd:clear}){p_end}
{synopt:{cmd:r(key)}}the key removed by {cmd:set} {it:key} {cmd:clear}{p_end}
{synopt:{cmd:r(permanent)}}{cmd:"permanent"} (when saving a disk profile){p_end}
{synopt:{cmd:r(profile)}}profile path written by {cmd:permanent}{p_end}

{pstd}
{cmd:tabtools get} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(font)}}effective current font name{p_end}
{synopt:{cmd:r(fontsize)}}effective current font size{p_end}
{synopt:{cmd:r(borderstyle)}}effective current border style{p_end}
{synopt:{cmd:r(headercolor)}}effective current header color setting{p_end}
{synopt:{cmd:r(zebracolor)}}effective current zebra stripe color setting{p_end}
{synopt:{cmd:r(digits)}}current digits setting{p_end}
{synopt:{cmd:r(boldp)}}current boldp setting{p_end}

{pstd}
{cmd:tabtools query} stores the following in {cmd:r()}:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(workbook)}}session workbook, if set{p_end}
{synopt:{cmd:r(markdown)}}session Markdown file, if set{p_end}
{synopt:{cmd:r(headershade)}}session header shading, if set{p_end}
{synopt:{cmd:r(smallcells)}}session small-cell threshold, if set{p_end}
{synopt:{cmd:r(smallcells_mode)}}{cmd:full} or {cmd:primary}, if set{p_end}
{synopt:{cmd:r(borderstyle)}}session border style, if set{p_end}
{synopt:{cmd:r(workbook_fresh)}}{cmd:1} if the next write replaces the workbook{p_end}
{synopt:{cmd:r(markdown_fresh)}}{cmd:1} if the next write replaces the Markdown file{p_end}

{pstd}
{cmd:tabtools fitcount} stores the following in {cmd:r()}:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations in {cmd:e(sample)}{p_end}
{synopt:{cmd:r(events)}}events{p_end}
{synopt:{cmd:r(people)}}distinct {opt people()} values, if given{p_end}
{synopt:{cmd:r(people_ev)}}people with an event, if {opt people()} given{p_end}
{synopt:{cmd:r(exposure)}}total person-time, if given{p_end}
{synopt:{cmd:r(cmdset)}}collected model the counts are stored under{p_end}
{synopt:{cmd:r(n_terms)}}number of factor levels counted, with {opt terms}{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(terms)}}factor levels counted, with {opt terms}{p_end}
{synopt:{cmd:r(collection)}}collection the counts were written to{p_end}

{pstd}
{cmd:tabtools use} stores the following in {cmd:r()}:{p_end}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(action)}}{cmd:"loaded"}{p_end}
{synopt:{cmd:r(profile)}}profile path loaded{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}{bf:Version} 2.5.6{p_end}

{hline}

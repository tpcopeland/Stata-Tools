{smcl}
{* *! version 2.0.0  10nov2026}{...}
{vieweralsosee "[D] describe" "help describe"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[R] summarize" "help summarize"}{...}
{vieweralsosee "dataprobe" "help dataprobe"}{...}
{vieweralsosee "dataqa" "help dataqa"}{...}
{vieweralsosee "datamvp" "help datamvp"}{...}
{viewerjumpto "Package commands" "datamap##commands"}{...}
{viewerjumpto "Syntax" "datamap##syntax"}{...}
{viewerjumpto "Description" "datamap##description"}{...}
{viewerjumpto "Options" "datamap##options"}{...}
{viewerjumpto "Output layout" "datamap##layout"}{...}
{viewerjumpto "saving() columns" "datamap##saving"}{...}
{viewerjumpto "Variable classification" "datamap##classification"}{...}
{viewerjumpto "Safe output" "datamap##safe"}{...}
{viewerjumpto "Remarks" "datamap##remarks"}{...}
{viewerjumpto "Migrating from 1.x" "datamap##migrating"}{...}
{viewerjumpto "Examples" "datamap##examples"}{...}
{viewerjumpto "Stored results" "datamap##results"}{...}
{viewerjumpto "Author" "datamap##author"}{...}

{title:Title}

{phang}
{bf:datamap} {hline 2} Privacy-safe Markdown documentation of Stata datasets


{marker commands}{...}
{title:Package commands}

{pstd}
{cmd:datamap} is the flagship command of the {bf:datamap} package, which also
installs:

{p2colset 5 18 20 2}{...}
{p2col:{helpb dataprobe}}console QC profiling, expectation gates, snapshot and diff{p_end}
{p2col:{helpb dataqa}}session defaults and a QA ledger over {cmd:dataprobe}{p_end}
{p2col:{helpb datamvp}}missing-value pattern analysis{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datamap}
[{varlist}]
[{cmd:,}
{it:options}]

{synoptset 32 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input {it:(at most one; default is the data in memory)}}
{synopt:{opt single(filename)}}one {opt .dta} file{p_end}
{synopt:{opt dir:ectory(path)}}every {opt .dta} file in {it:path}{p_end}
{synopt:{opt file:list(names)}}the datasets named{p_end}
{synopt:{opt man:ifest(filename)}}datasets named in a text file{p_end}
{synopt:{opt rec:ursive}}with {opt directory()}, include subfolders{p_end}

{syntab:Output}
{synopt:{opt o:utput(filename)}}the document; default {bf:datamap.md}{p_end}
{synopt:{opt sep:arate}}one document per dataset{p_end}
{synopt:{opt outd:ir(path)}}folder for the separate documents{p_end}
{synopt:{opt suf:fix(string)}}separate name suffix; default {bf:_map}{p_end}
{synopt:{opt app:end}}add dataset sections to {opt output()}{p_end}
{synopt:{opt sav:ing(name[, replace csv])}}write the variable-level table{p_end}
{synopt:{opt conf:ig(filename)}}{cmd:key = value} defaults{p_end}

{syntab:Document {it:(each is written only when given)}}
{synopt:{opt ti:tle(string)}}document title{p_end}
{synopt:{opt subt:itle(string)}}subtitle{p_end}
{synopt:{opt ver:sion(string)}}document version{p_end}
{synopt:{opt auth:or(string)}}author line{p_end}
{synopt:{opt docd:ate(string)}}Last Updated date; default today{p_end}
{synopt:{opt note:s(string)}}Notes section: text or a file{p_end}
{synopt:{opt change:log(string)}}Change Log section: text or a file{p_end}

{syntab:Content}
{synopt:{opt col:umns(fields)}}choose and order the table columns{p_end}
{synopt:{opt com:pact}}short preset without value cells{p_end}
{synopt:{opt nost:ats}}no continuous summaries{p_end}
{synopt:{opt nofr:eq}}no frequency tables or missing codes{p_end}
{synopt:{opt nola:bels}}no value labels beside values{p_end}
{synopt:{opt maxf:req(#)}}most levels listed; default {bf:25}{p_end}
{synopt:{opt maxc:at(#)}}categorical cutoff; default {bf:25}{p_end}
{synopt:{opt uniqc:ap(#)}}exact-count cap; default {bf:1000}{p_end}
{synopt:{opt minc:ell(#)}}suppress counts below {it:#}; default {bf:5}{p_end}

{syntab:Privacy}
{synopt:{opt exc:lude(varlist|auto)}}withhold values of these variables{p_end}
{synopt:{opt dates:afe}}withhold exact dates{p_end}
{synopt:{opt datef:ormat(fmt)}}date display; default {bf:%tdCCYY/NN/DD}{p_end}
{synopt:{opt safe}}the agent-safe preset{p_end}

{syntab:Classification}
{synopt:{opt cont:inuous(varlist)}}force continuous{p_end}
{synopt:{opt cat:egorical(varlist)}}force categorical{p_end}
{synopt:{opt date(varlist)}}force date{p_end}

{syntab:Structure}
{synopt:{opt det:ect(list)}}run named structure detectors{p_end}
{synopt:{opt autodet:ect}}run every detector except binary{p_end}
{synopt:{opt panel:id(varname)}}panel identifier for the detector{p_end}
{synopt:{opt survival:vars(varlist)}}survival variables for the detector{p_end}

{syntab:Quality}
{synopt:{opt qu:ality}}flag issues; list candidates{p_end}
{synopt:{opt quality2(strict)}}stricter quality thresholds{p_end}
{synopt:{opt place:holders(numlist)}}declared placeholder values{p_end}
{synopt:{opt miss:ing(detail|pattern)}}add a Missingness section{p_end}
{synopt:{opt sam:ples(#)}}add the first {it:#} rows{p_end}

{syntab:Removed {it:(stop with a message, r(198))}}
{synopt:{opt f:ormat(string)}}removed; the document is Markdown{p_end}
{synopt:{opt datev:ars(string)}}removed; use {opt date()}{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{it:varlist} is allowed only with the data in memory or {opt single()}. The
{opt .dta} extension is optional everywhere. Markdown is the only file format. 2.0.0
removed {cmd:datadict} and several options; see
{help datamap##migrating:Migrating from 1.x}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:datamap} writes one Markdown document that describes one or more Stata
datasets without publishing their contents. Each dataset gets a state header
and a variable table with one row per variable: its type, label, missing
count, and values or statistics. Variables are classified automatically as
categorical, continuous, date, string, or excluded, and the cell for each
class follows the class. Counts below {opt mincell()} are suppressed, listed
identifiers can be excluded, exact dates can be withheld, and {opt safe} sets
all of that for output that goes to an agent or a collaborator. Several
datasets in one document also get a Linkage section.

{pstd}
The document and {opt saving()} read the same collected facts, so the file and
the variable-level metadata table cannot disagree. {opt saving()} writes that
table as a Stata dataset, and optionally as a CSV file.

{pstd}
Your data in memory is unchanged by a successful run. When {cmd:datamap}
documents a file ({opt single()}, {opt directory()}, {opt filelist()},
{opt manifest()}) it loads that file and restores your original data
afterwards. When it documents the data in memory it does not copy them: it
reads them in place, writes its lookup tables to temporary frames, and so
{cmd:c(changed)}, {cmd:c(filename)}, and the sort order are left as they were. That
matters on large data, where {helpb preserve} would be a second copy in
memory. The trade-off is that a run that fails partway (a full disk, a bad
{opt output()} path, a break) is not rolled back.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{pstd}
With no input option, {cmd:datamap} documents the data in memory. The source
reads {bf:data in memory}, and {opt separate} writes {bf:memory_map.md} in the
current directory. At most one of {opt single()}, {opt directory()},
{opt filelist()}, and {opt manifest()} may be given.

{phang}
{opt single(filename)} documents one Stata dataset file. Include the path when
the file is not in the current directory.

{phang}
{opt dir:ectory(path)} documents every {opt .dta} file in {it:path}; only that
folder is scanned unless {opt recursive} is given. Files are documented in name
order; with {opt recursive}, a folder's files come first, then its subfolders
in name order.

{phang}
{opt file:list(names)} documents the datasets in a space-separated list, such
as {cmd:filelist(patients hrt dmt)}. Enclose a name that contains spaces in
double quotes: {cmd:filelist("my data/patients" hrt)}. A quoted string that is
not itself a file is read as a list when every word looks like a whole name; give
the extension or a path ({cmd:filelist("./my file")}) to make a name with
spaces unambiguous.

{phang}
{opt man:ifest(filename)} documents the datasets named in a text file, one path
per line. A blank line, a line starting with {cmd:#}, and a leading byte-order
mark are skipped, and a path without {opt .dta} gets it. Each path must exist.

{phang}
{opt rec:ursive} makes {opt directory()} descend into subfolders. Hidden
folders and {cmd:__pycache__} are skipped. {opt recursive} without
{opt directory()} is r(198). A path holding {cmd:$}, a backtick, or a double
quote cannot be read; the command stops with r(198) naming it before any
output is written.

{dlgtab:Output}

{phang}
{opt o:utput(filename)} names the document; the default is {bf:datamap.md}. The
document is built in a temporary file and copied over {opt output()} only when
it is complete, so a failed run leaves the previous file in place. With
{opt separate}, {opt output()} is ignored.

{phang}
{opt sep:arate} writes one document per dataset instead of one combined
document. Each is named {it:dataset}{opt suffix()}{cmd:.md} and written beside
its dataset, or in {opt outdir()}; the data in memory is named
{bf:memory}. Two datasets that would write the same file are refused with
r(198). Every file is staged before the first is copied, so a failure writes
no file. There is no Contents list and no Linkage section, and
{cmd:r(output)} is not set (see {cmd:r(outputs)}). {opt separate} cannot be
combined with {opt append}.

{phang}
{opt outd:ir(path)} puts the separate documents in {it:path}. It is ignored
without {opt separate}.

{phang}
{opt suf:fix(string)} replaces {bf:_map} in the separate file names. It is
ignored without {opt separate}.

{phang}
{opt app:end} adds the dataset sections to an existing {opt output()} file
instead of replacing it. Section numbers continue from the file's last
{bf:## }{it:n}{bf:.} heading. {opt append} writes dataset sections only: no
title block, Contents, Linkage, or footer, so it cannot be combined with the
document options or with {opt separate}.

{phang}
{opt sav:ing(name[, replace csv])} writes the variable-level metadata table as
a Stata dataset with one row per documented variable. A name with no extension
gets {bf:.dta}. Without {cmd:replace}, an existing file is r(602) and is
detected before any output is written. {cmd:csv} also writes the same table as
{it:name}{bf:.csv}: every string quoted, numbers at full precision, a plain
missing value as an empty cell and an extended missing value (such as {bf:.s})
as its code, which {helpb import delimited} reads back. Any other suboption is
r(198). The columns are listed under
{help datamap##saving:saving() columns}.

{phang}
{opt conf:ig(filename)} reads reusable defaults from a text file of
{cmd:key = value} or {cmd:key: value} lines; {cmd:#}, {cmd:*}, and {cmd://}
start a comment and a byte-order mark is ignored. Keys are
{cmd:output}, {cmd:outdir}, {cmd:suffix}, {cmd:columns}, {cmd:title},
{cmd:subtitle}, {cmd:version}, {cmd:author}, {cmd:docdate}, {cmd:notes},
{cmd:changelog}, {cmd:exclude}, {cmd:continuous}, {cmd:categorical},
{cmd:datevars} (read as {opt date()}), {cmd:detect}, {cmd:panelid},
{cmd:survivalvars}, {cmd:missing} ({bf:detail} or {bf:pattern}),
{cmd:dateformat}, {cmd:maxfreq}, {cmd:maxcat}, {cmd:mincell}, {cmd:uniqcap},
{cmd:samples}, {cmd:datesafe}, {cmd:nostats}, {cmd:nofreq}, {cmd:nolabels},
{cmd:compact}, and {cmd:autodetect}. A command-line option overrides the file,
and the numeric keys must be integers (r(198) otherwise). Two keys stop with a
named message: {cmd:format} (removed) and {cmd:missing} set to
{cmd:yes}, {cmd:no}, or another switch value (datadict's Missing-column switch,
removed). There is no {cmd:safe} key, and the {cmd:date} key is not read (it
was datadict's document date; use {cmd:docdate}). A note names, and the run
ignores, a key that neither {cmd:datamap} nor {helpb dataprobe} reads (the 1.x
keys {cmd:stats}, {cmd:detail}, {cmd:datasignature}, and {cmd:noguidance}
among them), a line with no {cmd:=} or {cmd::}, and a switch key whose value is
not {cmd:1}, {cmd:yes}, {cmd:true}, or {cmd:on} (switch on) or {cmd:0},
{cmd:no}, {cmd:false}, or {cmd:off}; keys that only {cmd:dataprobe} reads are
ignored without a note, so one file can serve both commands.

{dlgtab:Document}

{pstd}
These options write the title block, a Contents list, and a footer around the
dataset sections. With none of them a document is just the dataset sections
(and a Contents list when there are two or more datasets). Their text may hold
{cmd:$} and backticks, which are never expanded; embedded double quotes are
removed.

{phang}
{opt ti:tle(string)} sets the first heading; under {opt separate} each file's
heading reads {it:title}{bf::} {it:file}. {opt subt:itle(string)} adds a line
below it. {opt ver:sion(string)} adds a {bf:Version} line and the footer's
{bf:Document Version}. {opt auth:or(string)} adds the footer's {bf:Author}.

{phang}
{opt docd:ate(string)} sets the footer's {bf:Last Updated} date. The default is
today's date, and it is written only when another document option is given. This
is the old {cmd:datadict} {cmd:date()}.

{phang}
{opt note:s(string)} adds a Notes section and {opt change:log(string)} a Change
Log section. Each is either text or the name of an existing text file, whose
lines are written; Markdown special characters are escaped.

{dlgtab:Content}

{phang}
{opt col:umns(fields)} chooses the table's columns, each once, in the order
given. The default is {bf:variable label type missing values}. Fields are
{bf:variable}, {bf:label}, {bf:type}, {bf:class}, {bf:format},
{bf:vallabel}, {bf:missing}, {bf:values}, {bf:notes}, {bf:chars},
{bf:unique}, and {bf:position}; {bf:name}, {bf:var}, {bf:storage},
{bf:stats}, {bf:displayformat}, {bf:valuelabel}, {bf:varnotes},
{bf:characteristics}, {bf:distinct}, and {bf:pos} are accepted as aliases. Separate
fields with spaces, commas, or {cmd:|}. Another field is r(198).

{phang}
{opt com:pact} is the preset {bf:variable type label missing unique}: a shorter
document with no value or statistics cells. It cannot be combined with
{opt columns()}.

{phang}
{opt nost:ats} leaves out the summary statistics of continuous variables (N,
mean, SD, median, IQR, range). The variables still appear with their type and
missing count.

{phang}
{opt nofr:eq} lists no frequency tables, no string values, and no per-code
missing breakdown in the document. {cmd:saving()}'s {bf:missing_codes} is not
changed by it.

{phang}
{opt nola:bels} drops the value-label text beside each value and each missing
code. The labels are inline in the document; there is no separate value-label
section.

{phang}
{opt maxf:req(#)} is the most distinct values for which a categorical variable
lists its frequencies; more show only the distinct count. The default is
{bf:25}. {opt maxc:at(#)} is the cutoff between categorical and continuous: a
numeric variable with a value label, or with {it:#} or fewer distinct values,
is categorical. The default is {bf:25}. Both must be positive.

{phang}
{opt uniqc:ap(#)} caps how far distinct values are counted. A variable with
more than {it:#} distinct values is reported as {bf:>}{it:#} rather than an
exact count, and {cmd:saving()} sets {bf:unique_capped} to 1 with {bf:unique}
a lower bound. The cap is always raised to at least {opt maxcat()} and
{opt maxfreq()}, so it never changes a class or hides a table. The default is
{bf:1000}; {cmd:uniqcap(0)} counts exactly at any cardinality, at the cost of a
sort per variable.

{phang}
{opt minc:ell(#)} suppresses any printed count from 1 to {it:#}{bf:-1}: a level
count, a missing count, the nonmissing {bf:N=}, a missing code, a candidate
count, a pattern count. The default is {bf:5}; {cmd:mincell(0)} shows every
count. A suppressed cell reads {bf:suppressed (<}{it:#}{bf:)}.

{pmore}
Suppression is complementary. Because the observation count is printed, one
suppressed cell could be recovered by subtraction, so the smallest remaining
cell is also withheld until the withheld cells number at least two and hold at
least {it:#} observations; such a cell reads {bf:suppressed (complementary)}. The
Missing count and the nonmissing {bf:N=} are each other's complement: when
either is below {it:#}, both are withheld. The same rule covers the missing
codes of a variable, the placeholder candidates, and the patterns of
{cmd:missing(pattern)}. Percentages are shares of all N, missing values
included, rounded half up to one decimal. The mean and SD of a continuous
variable with two or three distinct values are withheld, because they return
the cell counts.

{dlgtab:Privacy}

{phang}
{opt exc:lude(varlist|auto)} withholds the values and statistics of the named
variables. They keep a row with their type and missing count (the count
obeys {opt mincell()}), read {bf:excluded (structure only)}, get no per-code
missing breakdown, and count in the Disclosure line. Wildcards and ranges are expanded against each
dataset ({cmd:exclude(ssn*)}, {cmd:exclude(name1-name3)}), and a name that
matches no variable in a given dataset is ignored there, so one list can
serve several files; a note names a token that matches no variable in any
dataset. A range must resolve in every dataset (error 111 otherwise, before any
output) and is positional, so for several files list the names or use a
wildcard. Abbreviations are not expanded.

{pmore}
The token {cmd:auto} excludes every variable whose name looks like an
identifier, the variables {cmd:r(suggested_exclude)} would list, and may stand
beside other names: {cmd:exclude(auto income)}. The rule is a pattern on the
name: it ends in {it:id} or {it:_id}, starts with {it:id_}, or contains
{it:patient}, {it:subject}, {it:person}, {it:lopnr}, or {it:identifier}. It
over-excludes names such as {it:paid} and misses an identifier under another
name such as {it:pnr}. A variable literally named {it:auto} is excluded too. Variables
in {opt exclude()} are named but never summarized by the detectors,
the quality flags, or {opt saving()}.

{phang}
{opt dates:afe} withholds exact dates. A date variable reads
{bf:N=}{it:n}{bf:; span }{it:k}{bf: days (exact dates withheld)}, with the unit
of its family, instead of its range; a date-formatted variable forced into
{opt categorical()} lists no frequencies, one forced into {opt continuous()}
shows only its N, and {opt samples()} prints {bf:[DATE SUPPRESSED]}. In
{opt saving()}, date rows have no mean, SD, quantiles, minimum, or maximum. Under
{opt datesafe}, the listed values of a text variable are withheld when
any of them contains a digit or when its values read as dates, and a date
variable that has a placeholder candidate reads
{bf:candidates withheld (datesafe)}.

{phang}
{opt datef:ormat(fmt)} sets the format used to print dates; the default is
{bf:%tdCCYY/NN/DD}. {cmd:%tc} and {cmd:%tC} values adapt the prefix; weekly,
monthly, quarterly, half-yearly, yearly, and other non-daily dates keep their
own format. The format must begin with {cmd:%t} or {cmd:%d}.

{phang}
{opt safe} is the agent-safe preset: {opt mincell(5)} or more (a larger value
wins, and a smaller one is raised with a note), {opt datesafe},
{cmd:exclude(auto)}, and no listed values for text with more than
{opt maxcat()} distinct values or with a digit in a value. Typed
{opt samples()} is r(198) with {opt safe}, and a {opt config()} {cmd:samples}
key is ignored with a note. {cmd:dataqa set agent} turns {opt safe} on for the
session. What {opt safe} does not cover is stated under
{help datamap##safe:Safe output}.

{dlgtab:Classification}

{phang}
{opt cont:inuous(varlist)}, {opt cat:egorical(varlist)}, and {opt date(varlist)}
force the named variables into that class after {opt exclude()} is applied. A
variable may be in one list only. A string variable in {opt categorical()} gets
a frequency table of its nonempty values in double quotes, subject to
{opt maxfreq()} and {opt mincell()}; a string variable in {opt continuous()} or
{opt date()} is r(109). Each token must match a variable in at least one
dataset (r(111) otherwise, before any output). A token in {opt date()} that
matches no variable is r(198) with a pointer to {opt docdate()}, because
{cmd:date()} named a document date in {cmd:datadict}.

{dlgtab:Structure}

{phang}
{opt det:ect(list)} runs detectors, each a keyword. The findings print under
{bf:Structure (inferred)}, labelled inferred because they come from names and
values; a setting you declared ({cmd:xtset}, {cmd:stset}, {cmd:svyset},
{cmd:mi set}) prints as declared in the header. Keywords are
{bf:panel} (repeated observations per unit), {bf:binary} (a one-line list of
two-valued variables; a date-formatted variable is never listed),
{bf:survival} (time and event variables), {bf:survey} (weights, strata,
clusters; the mean of a categorical weight is withheld under {opt mincell()}),
and {bf:common} (identifiers, dates, demographics, exposures, and outcomes by
name pattern).

{phang}
{opt autodet:ect} runs every detector except {bf:binary}, which {opt detect(binary)}
adds.

{phang}
{opt panel:id(varname)} names the unit variable for the panel detector; otherwise
names such as {it:*id} and {it:patient*} are used. A missing
identifier counts toward no unit and is reported separately. {opt survival:vars(varlist)}
names the variables the survival detector
considers; a listed variable matching no naming pattern is an event indicator
when it takes at most two values and a time otherwise. An event rate prints for
a 0/1 indicator, as the share of nonmissing values, and is withheld when
either cell is below {opt mincell()}. Both options may name any variable in
the dataset, including one outside {it:varlist}. A detector never summarizes an
excluded variable.

{dlgtab:Quality}

{phang}
{opt qu:ality} adds a {bf:Flags} section and a
{bf:Candidates (not applied)} section; {opt quality2(strict)} uses stricter
thresholds. Flags are decided by variable name: a numeric variable named
{it:age} (or {it:*_age}) with a negative value or a value above 120 (above 100
under {opt quality2(strict)}), a count variable ({it:count}, {it:*_count},
{it:n_*}, {it:number}) with a negative value, and a percentage variable
({it:percent}, {it:pct}, {it:proportion}, and their suffix forms) outside
0-100; the section reads {bf:No quality flags.} when there is none. Candidates
are values that may
stand in for a missing or unknown value: the placeholder dates
{bf:01jan1900}, {bf:01jan1960} (Stata's date 0), and {bf:31dec9999} in a
daily or datetime variable; dates after the run date in any variable with a
date family other than business-daily or generic; and the values you declare
in {opt placeholders()}. Each prints as {it:value}{bf:: }{it:n}{bf: rows} with
{opt mincell()} applied. Nothing is recoded or excluded because a value is a
candidate.

{pmore}
The built-in date rules are heuristic: no published convention supports them,
and a real value can match a candidate (a person born on 1 January 1960). Numeric
placeholders are therefore never guessed; a numeric candidate appears
only through {opt placeholders()}.

{phang}
{opt place:holders(numlist)} declares numeric values to list as candidates in
every numeric variable that is not a date, such as {cmd:placeholders(9 99 999)}. It
requires {opt quality} (r(198) otherwise) and does not apply to dates.

{phang}
{opt miss:ing(detail|pattern)} adds a {bf:Missingness} section. {bf:detail}
reports the variables with more than 50% and more than 10%
missing and the complete rows; {bf:pattern} adds the joint missing-value
patterns across the variables with any missing value: the distinct patterns
and the ten most frequent, with {bf:+} observed and {bf:.} missing. Pattern
counts below {opt mincell()} are suppressed, and the complete-row count reads
{bf:suppressed (complementary)} when a withheld pattern would give it back.

{phang}
{opt sam:ples(#)} adds a {bf:Sample rows} section with the first {it:#}
observations. Excluded variables print {bf:[MASKED]}, and under
{opt datesafe} date variables print {bf:[DATE SUPPRESSED]}. Rows are
row-level data: use {opt samples()} with {opt exclude()} and {opt datesafe},
and not with {opt safe}, which refuses it.


{dlgtab:Removed}

{phang}
{opt f:ormat(string)} and {opt datev:ars(string)} remain in the syntax only to
stop with a message. {cmd:format()} (any value, including an empty one) exits
r(198) and the message "format() was removed in 2.0.0: datamap writes
Markdown; use saving() for a machine-readable table". {cmd:datevars()} exits r(198) with a
pointer to {opt date()}. The other removed options are not in the syntax and
stop with Stata's own message; see
{help datamap##migrating:Migrating from 1.x}.


{marker layout}{...}
{title:Output layout}

{pstd}
The document has up to four parts. The title block, Contents list, Notes, Change
Log, and footer appear only when a document option is given; the Contents list
also appears for two or more datasets in one combined document (not under
{opt separate} or {opt append}).

{phang2}1. {bf:Per dataset}, headed {bf:## }{it:n}{bf:. }{it:name}: the state
header, a disclosure line, the {bf:Variables} table, a {bf:Flags} and a
{bf:Candidates (not applied)} section under {opt quality}, then, when asked
for, {bf:Structure (inferred)}, {bf:Missingness}, and {bf:Sample rows}.{p_end}
{phang2}2. {bf:Linkage}, for two or more datasets in one document (not under
{opt separate} or {opt append}).{p_end}

{pstd}
{bf:State header.} Bullets for the source; for data in memory, the file in
{cmd:c(filename)} and whether it changed since it was last used or saved (or
{bf:none}); the label, observations, and variables (with the documented count
when a {it:varlist} is given); the sort order; the settings the dataset
declares, printed as declared: {bf:Declared xtset}, {bf:Declared tsset},
{bf:Declared stset} (time, id, failure, origin, exit, scale),
{bf:Declared svyset}, {bf:Declared mi set}; the dataset notes; the data
signature, always printed; and a {bf:Disclosure} line (variables excluded,
cell suppression, date-safe, likely identifiers not excluded). A line is
absent when the dataset does not declare the setting. A declared {cmd:stset}
failure code or expression that names an excluded variable is withheld.

{pstd}
{bf:Variables table.} The default columns are {bf:Variable}, {bf:Label},
{bf:Type}, {bf:Missing}, and {bf:Values/Statistics}.

{p2colset 5 24 26 2}{...}
{p2col:{bf:Type}}the storage type: {cmd:long}, {cmd:str12}, {cmd:strL}. A date
variable adds its format and family: {cmd:double %td daily}, {cmd:%tc datetime},
{cmd:%tC datetime (leap seconds)}, {cmd:%tw weekly}, {cmd:%tm monthly},
{cmd:%tq quarterly}, {cmd:%th half-yearly}, {cmd:%ty yearly}, {cmd:%tb business daily},
{cmd:%tg generic}{p_end}
{p2col:{bf:Missing}}{it:n} ({it:p}%), the count and the share of all N. For a
numeric variable that holds extended missing values the cell lists each code,
as in {cmd:276 (9.2%): . 51, .a Refused 145, .b Not asked 80},
with the value-label
text when it has one. Each code count obeys {opt mincell()} and is withheld
when the total is. Only {cmd:.} present gives no breakdown{p_end}
{p2col:{bf:Values/Statistics}}by class, below{p_end}
{p2colreset}{...}

{p2colset 5 24 26 2}{...}
{p2col:{bf:Categorical}}one line per level, {it:value label}{bf:: }{it:n}
({it:p}%), strings in double quotes, suppressed cells marked; or the distinct
count when there are more than {opt maxfreq()} levels{p_end}
{p2col:{bf:Continuous}}{bf:N=}, {bf:mean=}, {bf:SD=}, {bf:median=}, {bf:IQR=},
{bf:range=}. Median, IQR, and range print as computed{p_end}
{p2col:{bf:Date}}{bf:N=} and {bf:range }{it:a}{bf: to }{it:b}, or the span under
{opt datesafe}{p_end}
{p2col:{bf:String}}{bf:N=}, the distinct count, the maximum length, and the
string profile below{p_end}
{p2col:{bf:Excluded}}{bf:excluded (structure only)}{p_end}
{p2colreset}{...}

{pstd}
{bf:String profile.} For text, after the maximum length: the share of values
that {cmd:real()} reads as numbers ({bf:numeric text 2859 (95.3%)}) and the
nonnumeric tokens among them, top five with counts ({bf:non-numeric "NA" 124}); the
count of values with leading or trailing blanks; {bf:date-like text (YMD)} when
at least 95% of the nonblank values parse with a {cmd:date()} mask (YMD, DMY, or
MDY); and the top five values with counts for text with at most {opt maxcat()}
distinct values, with the rest pooled as {bf:others}. A value held by fewer than
{opt mincell()} rows is never listed. Text with more distinct values lists no
value. An excluded variable gets no profile, and {opt nofreq} lists no values.

{pstd}
{bf:Linkage.} For the variable names two or more datasets share: the datasets
that hold the name, its storage type in each, whether its values are unique in
each (missing values counted as values, as {helpb merge} counts them), the merge
type that a merge on that name alone would imply, and flags. A type conflict
is a numeric variable in one dataset and a string in another (string
widths are not a conflict; {helpb merge} would stop with r(106)). Below the
table, value labels with the same name and different definitions are listed. The
merge type is given per pair for two to four datasets and as a summary for
five or more. A shared variable that is excluded in any dataset shows
{bf:withheld (excluded)} for uniqueness and merge type, and a value label held
only by excluded variables is not compared. Datasets are named by file; when
two share a name each reads as its source path, and a file listed twice in
{opt filelist()} reads {it:path} {bf:(section }{it:n}{bf:)}.


{marker saving}{...}
{title:saving() columns}

{pstd}
{opt saving()} writes 37 columns, one row per documented variable. The 27
columns of 1.10.6 keep their names, order, and types: {bf:source_command},
{bf:source}, {bf:output}, {bf:dataset},
{bf:dataset_label}, {bf:variable}, {bf:storage_type}, {bf:display_format},
{bf:value_label}, {bf:class}, {bf:N}, {bf:nvars}, {bf:missing},
{bf:missing_pct}, {bf:unique}, {bf:variable_label}, {bf:notes},
{bf:characteristics}, {bf:mean}, {bf:sd}, {bf:p50}, {bf:p25}, {bf:p75},
{bf:min}, {bf:max}, {bf:datasignature}, and {bf:unique_capped}. Their text
columns have fixed widths: {bf:source_command} {cmd:str16}; {bf:variable},
{bf:display_format}, and {bf:value_label} {cmd:str32}; {bf:storage_type} and
{bf:class} {cmd:str20}; the other eight {cmd:str2045} (notes and
characteristics are cut at 2,045 bytes). The mean and
SD of a categorical variable are missing while {opt mincell()} is above 0, and
the statistics follow the document: filled for continuous variables (not under
{opt nostats}) and for dates (not under {opt datesafe}), and missing for
excluded variables. {bf:unique} counts distinct nonmissing values; the empty
string is not counted.

{pstd}
The new columns follow, in this order:

{p2colset 5 20 22 2}{...}
{p2col:{bf:missing_codes}}({it:strL}) the Missing cell's per-code breakdown as
printed, {cmd:. 51, .a Refused 145}; empty when only {cmd:.} occurs or the
variable is excluded{p_end}
{p2col:{bf:position}}({it:long}) the variable's place in its dataset{p_end}
{p2col:{bf:date_family}}({it:str32}) {cmd:%td daily} and the like; empty for a
variable with no date format{p_end}
{p2col:{bf:numeric_n}}({it:double}) text variables: the nonblank values
{cmd:real()} reads as numbers{p_end}
{p2col:{bf:numeric_pct}}({it:double}) the share of N that is, to one decimal{p_end}
{p2col:{bf:padded_n}}({it:double}) values with a leading or trailing blank{p_end}
{p2col:{bf:date_mask}}({it:str20}) {cmd:YMD}, {cmd:DMY}, {cmd:MDY}, or
{cmd:YMD or DMY} when 95% or more of the values parse{p_end}
{p2col:{bf:is_strl}}({it:byte}) 1 for a {cmd:strL} variable{p_end}
{p2col:{bf:key}}({it:byte}) 1 when the values identify the observations (missing
values counted as values), 0 when they do not, {cmd:.} when not determined: a
capped variable that is neither a shared name nor a likely identifier is not
decided unless {cmd:uniqcap(0)}{p_end}
{p2col:{bf:candidates}}({it:strL}) the placeholder candidates as the document
lists them, under {opt quality}{p_end}
{p2colreset}{...}

{pstd}
A new count that the document withholds is {bf:.s} in {opt saving()}
({bf:numeric_n}, {bf:numeric_pct}, {bf:padded_n}). The 1.10.6 count columns keep
exact values, except under {opt safe}, where {bf:missing} and {bf:missing_pct}
are {bf:.s} wherever the document withholds the Missing count. {opt saving()}
does not mask the other statistics under {opt safe}: unique counts, minima,
maxima, and quartiles are written as computed.


{marker classification}{...}
{title:Variable classification}

{pstd}
{cmd:datamap} classifies each variable in priority order:

{phang2}1. Variables in {opt exclude()} are {bf:excluded}.{p_end}
{phang2}2. Variables in {opt continuous()}, {opt categorical()}, or {opt date()} take that class.{p_end}
{phang2}3. String variables ({cmd:str}{it:#} or {cmd:strL}) are {bf:string}.{p_end}
{phang2}4. Variables with a display format that starts with {cmd:%t} or {cmd:%d} are {bf:date}.{p_end}
{phang2}5. Numeric variables with a value label, or with {opt maxcat()} or
fewer distinct values, are {bf:categorical}.{p_end}
{phang2}6. All other numeric variables are {bf:continuous}.{p_end}

{pstd}
{cmd:datamap} warns when a variable name looks like an identifier and is not
excluded. The count and the names are in the Disclosure line and
{cmd:r(suggested_exclude)}.


{marker safe}{...}
{title:Safe output}

{pstd}
{opt safe} is a preset, not a guarantee. It is meant for output that leaves the
machine that holds the data, such as a log or a file an agent reads. State of
the guarantee:

{phang2}{hline 2} It covers {bf:printed output and written files only}: the
document and {opt saving()} (and the matching output of {cmd:dataprobe} and
{cmd:datamvp}). Stored results ({cmd:r()}), a {cmd:dataprobe} {opt snapshot()}
frame, and anything you display yourself are not masked.{p_end}
{phang2}{hline 2} It does not cover {bf:cross-output differencing}. Two
outputs can each be safe and together give a count back: {cmd:datamap} and
{cmd:dataprobe} choose different complementary cells for the same table, so
read together they can return a rare count.{p_end}
{phang2}{hline 2} Identifiers are recognized by {bf:variable name only}. An
identifier under another name (such as {it:pnr}) is not excluded.{p_end}
{phang2}{hline 2} An integer date such as {cmd:20200115} with no date format is not
recognized as a date and prints as a number.{p_end}
{phang2}{hline 2} {opt saving()} under {opt safe} masks the {bf:missing counts only}; unique
counts, minima, maxima, and quartiles are written as computed.{p_end}
{phang2}{hline 2} Median, IQR, and range print as computed; they are values, not
counts.{p_end}
{phang2}{hline 2} A listed level held by fewer than {opt mincell()} rows is not
named: the Values cell ends with {bf:other values: suppressed (<}{it:#}{bf: each)},
{it:#} the {opt mincell()} value (or reads {bf:all values: ...}), as {cmd:dataprobe} prints {bf:[suppressed]} under
{opt maskrare}. Without {opt safe} such a level is named and only its count is
suppressed.{p_end}
{phang2}{hline 2} {bf:Free-text metadata prints as written}: the data label,
dataset notes (the header), variable labels, value labels, and, when asked for
with {opt columns()} or written by {opt saving()}, variable notes and
characteristics. {opt datesafe} does not scan them. Only an excluded variable's
notes, characteristics, and value-label name are withheld. Read them, or drop
notes ({help notes:notes drop}) before sharing.{p_end}
{phang2}{hline 2} No sample rows: {opt samples()} is refused, because rows are
row-level data.{p_end}
{phang2}{hline 2} {opt datesafe} withholds the listed values of text that contains a
digit, which also hides codes such as {it:A1}; digit-free text with {opt mincell()} or
more rows per value is still listed.{p_end}

{pstd}
Review the file before sharing it. {cmd:r(safe)} is 1 when the run was safe.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Input modes.} Memory (the default), a single file, a directory, a file list,
or a manifest. {it:varlist} limits the variables documented (memory or
{opt single()} only); the state header then reads
{bf:Variables: 12 (3 documented)}. {opt panelid()} and {opt survivalvars()} may still name any
variable, and {cmd:r(nvars)} counts the dataset's variables.

{pstd}
{bf:Privacy practice.} Exclude direct identifiers (names, national numbers,
addresses), add {opt datesafe} when dates of birth or admission are present, keep
{cmd:mincell(5)} unless you have reviewed the risk, and use {opt samples()}
sparingly. Review the output before sharing it.

{pstd}
{bf:Using datamap with a coding agent.} Before writing code, {cmd:datamap, safe}
gives the agent the structure. After each data step, {helpb dataprobe}
{opt snapshot()} and {opt diff()} show what changed; before a merge,
{cmd:dataprobe, keyset()} checks the keys; when a result looks wrong,
{cmd:dataprobe, brief} is a one-line-per-variable view.

{marker migrating}{...}
{title:Migrating from 1.x}

{pstd}
Upgrade by removing the old package first: {cmd:ado uninstall datamap}, then
{cmd:net install datamap, replace}. Installing over 1.x with {cmd:replace}
alone leaves a working but stale {cmd:datadict.ado} in your PLUS directory and a
second package entry, and then {cmd:ado uninstall datamap} stops with "criterion
matches more than one package". If that happened, run {cmd:ado dir}, uninstall
the entries of the package by number, highest number first, then install again.

{pstd}
{cmd:datadict} is removed: its Markdown is {cmd:datamap}'s only output, and
{cmd:datadict} is unrecognized (r(199)) after a clean install. The options below
stop with r(198).

{p2colset 5 30 32 2}{...}
{p2col:{bf:1.x}}{bf:2.0.0}{p_end}
{p2col:{cmd:datadict}}{cmd:datamap} (same Markdown; the default file is
{bf:datamap.md}){p_end}
{p2col:{cmd:format(text)}, {cmd:format(json)}}removed, with a message. Use the
.md document and {opt saving()}, with {cmd:csv} for a delimited copy{p_end}
{p2col:{cmd:noguidance}}removed; the guidance prose is gone{p_end}
{p2col:{cmd:datevars()}}removed, with a message; use {opt date()}{p_end}
{p2col:{cmd:datadict} {cmd:date(}{it:text}{cmd:)}}{opt docdate()}; {opt date()} now
names variables to classify as dates{p_end}
{p2col:{cmd:datadict} bare {cmd:missing}}removed: the Missing column is always
printed and {opt columns()} leaves it out. {cmd:missing()} now adds the
Missingness section{p_end}
{p2col:{cmd:stats}, {cmd:detail}}removed; the Values/Statistics column is the
default, and {opt columns()} chooses columns. {cmd:det} now abbreviates
{opt detect()}{p_end}
{p2col:{cmd:datasignature}}removed; the data signature is always printed{p_end}
{p2colreset}{...}

{pstd}
Other changes. The document drops the guidance prose, the per-variable block
that repeated the quick reference, the binary-variables section, the separate
value-label section, the per-variable privacy note, and the generated
description; value labels are inline. A document gets a title block only when a
document option is given. {opt separate} files end {bf:_map.md} (datadict used
{bf:_dictionary.md}); excluded variables stay in the table as structure-only rows. Percentages
in the document are shares of all N, missing values included.

{pstd}
Stored results. {cmd:r(format)} is gone. {cmd:r(nobs_total)} and
{cmd:r(nvars_total)} are gone; {cmd:r(nobs)} and {cmd:r(nvars)} exist for a
memory or {opt single()} run only. With {opt separate}, {cmd:r(output)} is unset
and the files are in {cmd:r(outputs)}. Config files: the {cmd:format} key and a
{cmd:missing} switch value stop with a named message; the {cmd:stats},
{cmd:detail}, {cmd:datasignature}, and {cmd:noguidance} keys are ignored with a
note, as are a key no command reads, a line with no {cmd:=} or {cmd::}, and a
switch whose value is not {cmd:1}/{cmd:yes}/{cmd:true}/{cmd:on} or
{cmd:0}/{cmd:no}/{cmd:false}/{cmd:off}; the {cmd:datevars} key still sets
{opt date()}; {opt saving()} rejects any suboption but {cmd:replace} and
{cmd:csv}.


{marker examples}{...}
{title:Examples}

    {title:Getting started}

{pstd}
Load a dataset and run the command with no options. The document is written to
{bf:datamap.md} in the current directory:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datamap}{p_end}

{pstd}
Name the output, and write the variable-level table beside it:{p_end}

{phang2}{cmd:. datamap, output(auto_codebook.md)}{p_end}
{phang2}{cmd:. datamap, output(auto_map.md) saving(auto_map.dta, replace csv)}{p_end}

{pstd}
Add a title block and a footer, or choose the columns:{p_end}

{phang2}{cmd:. datamap, title("Auto Dataset") author("Timothy P Copeland, Karolinska Institutet") output(auto_titled.md)}{p_end}
{phang2}{cmd:. datamap, output(auto_dict.md) columns(variable label type format vallabel missing values)}{p_end}

{pstd}
A shorter document, or only some variables:{p_end}

{phang2}{cmd:. datamap, compact output(auto_compact.md)}{p_end}
{phang2}{cmd:. datamap price mpg foreign, output(auto_three.md)}{p_end}

    {title:Privacy controls}

{pstd}
Exclude identifiers by name or by the name rule, and withhold exact dates:{p_end}

{phang2}{cmd:. datamap, exclude(make) datesafe output(auto_private.md)}{p_end}
{phang2}{cmd:. datamap, exclude(auto) datesafe output(auto_private.md)}{p_end}

{pstd}
The agent-safe preset, with its metadata table:{p_end}

{phang2}{cmd:. datamap, safe output(auto_safe.md) saving(auto_safe.dta, replace)}{p_end}

    {title:Quality, structure, and missingness}

{pstd}
Flag quality issues and list placeholder candidates, including a value you
declare:{p_end}

{phang2}{cmd:. datamap, quality placeholders(999) output(auto_quality.md)}{p_end}

{pstd}
Run every structure detector, and add the missing-value patterns:{p_end}

{phang2}{cmd:. datamap, autodetect missing(pattern) output(auto_detected.md)}{p_end}

    {title:Several datasets}

{pstd}
Save two datasets, then document both in one file with a Linkage section, or in
one file each:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. keep make price mpg}{p_end}
{phang2}{cmd:. save auto_a, replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. keep make weight foreign}{p_end}
{phang2}{cmd:. save auto_b, replace}{p_end}
{phang2}{cmd:. datamap, filelist(auto_a auto_b) output(auto_both.md)}{p_end}
{phang2}{cmd:. datamap, filelist(auto_a auto_b) separate}{p_end}
{phang2}{cmd:. datamap, directory(.) output(project_map.md)}{p_end}

    {title:Tuning the output}

{pstd}
Force classes and keep the metadata table:{p_end}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datamap, continuous(rep78) categorical(trunk) maxcat(10) saving(auto_meta.dta, replace)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datamap} stores the following in {cmd:r()}. Stored results are not masked
by {opt safe}.

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(nfiles)}}number of datasets documented{p_end}
{synopt:{cmd:r(nobs)}}observations (memory, {opt single()}){p_end}
{synopt:{cmd:r(nvars)}}variables in the dataset (memory, {opt single()}){p_end}
{synopt:{cmd:r(mincell)}}small-cell threshold used{p_end}
{synopt:{cmd:r(safe)}}1 when {opt safe} was in effect{p_end}
{synopt:{cmd:r(n_categorical)}}categorical variables documented{p_end}
{synopt:{cmd:r(n_continuous)}}continuous variables documented{p_end}
{synopt:{cmd:r(n_date)}}date variables documented{p_end}
{synopt:{cmd:r(n_string)}}string variables documented{p_end}
{synopt:{cmd:r(n_excluded)}}variables excluded{p_end}
{synopt:{cmd:r(n_suggested_exclude)}}likely identifiers not excluded{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(output)}}the document (not set with {opt separate}){p_end}
{synopt:{cmd:r(outputs)}}the file or files written, {cmd:;}-separated{p_end}
{synopt:{cmd:r(files)}}the datasets read, {cmd:;}-separated; {bf:memory}{p_end}
{synopt:{cmd:r(mode)}}how the input was given; see below{p_end}
{synopt:{cmd:r(input_source)}}the input kind; see below{p_end}
{synopt:{cmd:r(metadata)}}the {opt saving()} dataset{p_end}
{synopt:{cmd:r(metadata_csv)}}the {opt saving(, csv)} file{p_end}
{synopt:{cmd:r(categorical_vars)}}categorical variable names{p_end}
{synopt:{cmd:r(continuous_vars)}}continuous variable names{p_end}
{synopt:{cmd:r(date_vars)}}date variable names{p_end}
{synopt:{cmd:r(string_vars)}}string variable names{p_end}
{synopt:{cmd:r(excluded_vars)}}excluded variable names{p_end}
{synopt:{cmd:r(suggested_exclude)}}likely identifiers not excluded{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{cmd:r(mode)} is {bf:memory}, {bf:single}, {bf:filelist}, {bf:manifest},
{bf:directory}, or {bf:directory_recursive}. {cmd:r(input_source)} is the same
without the {bf:_recursive} form: {bf:memory}, {bf:single}, {bf:filelist},
{bf:manifest}, or {bf:directory}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 2.0.0, 2026-11-10{p_end}

{pstd}Report bugs and suggestions at{break}
{browse "https://github.com/tpcopeland/Stata-Tools":https://github.com/tpcopeland/Stata-Tools}{p_end}

{pstd}Check GitHub for the most up-to-date release; it may be newer than the version installed here.{p_end}


{title:Also see}

{psee}
{help dataprobe}, {help dataqa}, {help datamvp},
{manlink D describe}, {manlink D codebook}, {manlink R summarize}
{p_end}

{hline}

{smcl}
{* *! version 3.0.0  17jul2026}{...}
{vieweralsosee "codescan_describe" "help codescan_describe"}{...}
{vieweralsosee "[D] collapse" "help collapse"}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{vieweralsosee "[D] tostring" "help tostring"}{...}
{viewerjumpto "Syntax" "codescan##syntax"}{...}
{viewerjumpto "Description" "codescan##description"}{...}
{viewerjumpto "Typical workflow" "codescan##workflow"}{...}
{viewerjumpto "Regex and variable lists" "codescan##patterns"}{...}
{viewerjumpto "Options" "codescan##options"}{...}
{viewerjumpto "Time windows" "codescan##windows"}{...}
{viewerjumpto "Remarks" "codescan##remarks"}{...}
{viewerjumpto "Examples" "codescan##examples"}{...}
{viewerjumpto "Stored results" "codescan##results"}{...}
{viewerjumpto "Author" "codescan##author"}{...}


{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:codescan} {hline 2}}Scan wide-format code variables with regex or prefix rules{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:codescan}
{varlist}
{ifin}
{cmd:,}
{opt def:ine(string asis)} | {opt codef:ile(string)}
[{it:options}]


{synoptset 34 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Definition source}
{synopt:{opt def:ine(string asis)}}inline condition definitions{p_end}
{synopt:{opt codef:ile(string)}}CSV or {cmd:.dta} code dictionary{p_end}
{synopt:{opt lab:el(string asis)}}condition labels specified inline{p_end}
{synopt:{opt save(filename [, replace])}}write parsed rules to a CSV codefile{p_end}

{syntab:Identifiers and windows}
{synopt:{opt id(varname)}}patient or entity identifier{p_end}
{synopt:{opt date(varname)}}row-level event date{p_end}
{synopt:{opt refd:ate(varname)}}reference date for windowing{p_end}
{synopt:{opt lookb:ack(#|numlist)}}days before {cmd:refdate}; {it:numlist} allowed{p_end}
{synopt:{opt lookf:orward(#)}}days after {cmd:refdate}{p_end}
{synopt:{opt incl:usive}}include {cmd:refdate} in single-direction windows{p_end}

{syntab:Result dataset}
{synopt:{opt coll:apse}}reduce to one row per {cmd:id()}{p_end}
{synopt:{opt mer:ge}}attach patient-level results to row-level data{p_end}
{synopt:{opt earliest:date}}create {it:name}_first variables{p_end}
{synopt:{opt latest:date}}create {it:name}_last variables{p_end}
{synopt:{opt count:date}}create {it:name}_count variables (unique dates){p_end}
{synopt:{opt countr:ows}}create {it:name}_nrows variables (row counts){p_end}
{synopt:{opt alld:ates}}shorthand for all three date-summary options{p_end}
{synopt:{opt pre:serve}}restore the original data afterward{p_end}
{synopt:{opt frame(name)}}store the result dataset in a named frame{p_end}
{synopt:{opt sav:ing(filename [, replace])}}save the final result dataset to disk{p_end}

{syntab:Diagnostics and reporting}
{synopt:{opt det:ail}}return per-variable match counts{p_end}
{synopt:{opt alls:lots}}with {cmd:detail}, count every matching slot{p_end}
{synopt:{opt cooc:currence}}return pairwise co-occurrence counts{p_end}
{synopt:{opt unm:atched(name)}}row-level flag for rows that matched nothing{p_end}
{synopt:{opt match:ed_code(name)}}row-level first surviving code value{p_end}
{synopt:{opt gr:aph}}draw a prevalence bar chart{p_end}
{synopt:{opt exp:ort(filename [, replace])}}export the summary table{p_end}
{synopt:{opt for:mat(%fmt)}}format for prevalence and CI columns{p_end}

{syntab:Matching behavior and naming}
{synopt:{opt mod:e(string)}}{cmd:regex} (default) or {cmd:prefix}{p_end}
{synopt:{opt lev:el(#)}}prefix token length in {cmd:mode(prefix)}{p_end}
{synopt:{opt noc:ase}}case-insensitive matching{p_end}
{synopt:{opt nod:ots}}strip dots during matching{p_end}
{synopt:{opt tostr:ing}}convert numeric code variables to string{p_end}
{synopt:{opt countm:ode}}store counts rather than binary indicators{p_end}
{synopt:{opt gen:erate(prefix)}}prefix all created variable names{p_end}
{synopt:{opt rep:lace}}allow overwriting existing outputs{p_end}
{synopt:{opt noi:sily}}display per-condition progress notes{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:codescan} scans wide-format code slots — such as {cmd:dx1} through
{cmd:dx30} or {cmd:proc1} through {cmd:proc20} — and creates condition
indicators (or counts) from a single declarative rule set. It is designed for
administrative data, registry data, claims data, and other datasets where each
observation stores multiple code fields side by side. It works with any
string code system: ICD-10, ICD-9, KVÅ, CPT, ATC, OPCS, or proprietary
codes.

{pstd}
{bf:In plain language:} You tell {cmd:codescan} which code patterns to look
for and what to name each condition. The command scans every code slot on
every row, marks which conditions are present, and returns a summary with
prevalence and confidence intervals. You can stay at the row level (one
indicator per encounter), collapse to one row per patient, or merge
patient-level summaries back onto the original data.

{pstd}
Rules can be supplied inline through {cmd:define()} or read from a reusable
CSV/{cmd:.dta} code dictionary via {cmd:codefile()}. Matching is anchored at
the start of each code value — for example, the pattern {cmd:"E11"} matches
{cmd:E110}, {cmd:E119}, and any other code that starts with {cmd:E11}, but
does not match {cmd:AE11}. The default {cmd:regex} mode supports character
classes and alternation (for example {cmd:"I1[0-35]"} matches {cmd:I10},
{cmd:I11}, {cmd:I12}, {cmd:I13}, and {cmd:I15}); {cmd:prefix} mode uses
simple starts-with comparisons and is faster when regex features are not
needed.

{pstd}
Optional time windows, date summaries, and co-occurrence counts support common
clinical and health-services research workflows — all without leaving Stata or
reshaping the data.

{pstd}
Use {helpb codescan_describe} first when you need to inspect the raw code
distribution before writing scan rules.


{marker workflow}{...}
{title:Typical workflow}

{pstd}
Most users will learn {cmd:codescan} fastest by treating it as a four-step
workflow rather than as a menu of unrelated options:

{phang2}1. {bf:Inspect the code inventory.} Start with
{helpb codescan_describe} to see which codes and chapter prefixes actually
occur in your data. This tells you what patterns to target and which chapters
to focus on.{p_end}

{phang2}2. {bf:Draft and test simple rules.} Write an initial
{cmd:define()} specification and check the row-level results before adding
windows or date summaries. At this stage, the created variables appear
alongside the original data so you can eyeball whether each match is
correct.{p_end}

{phang2}3. {bf:Choose the output shape.} Stay row-level for auditing, use
{cmd:collapse} for one row per {cmd:id()}, or use {cmd:merge} when you need
patient-level results attached back to the original encounters. Most analytic
pipelines want {cmd:collapse}.{p_end}

{phang2}4. {bf:Add advanced features last.} Once the basic matches look
right, layer on {cmd:lookback()}/{cmd:lookforward()}, date summaries, and
export/save options. Each feature is additive and does not change the meaning
of earlier options.{p_end}

{pstd}
In practice, a common sequence is:

{phang2}{cmd:codescan_describe} (reconnaissance) {hline 1}>{p_end}
{phang2}{cmd:codescan, define(...)} at the row level (draft rules) {hline 1}>{p_end}
{phang2}{cmd:codescan, collapse} or {cmd:merge} (patient-level) {hline 1}>{p_end}
{phang2}{cmd:export()} or {cmd:saving()} (final deliverable){p_end}

{pstd}
Choose the output shape based on the question you are answering:

{phang2}{bf:Audit the rules:} omit {cmd:collapse} and {cmd:merge}; the original
rows remain in memory with one new condition variable per rule.{p_end}

{phang2}{bf:Build an analysis dataset:} use {cmd:id()} with {cmd:collapse}; the
active data become one row per patient or entity.{p_end}

{phang2}{bf:Keep encounter rows:} use {cmd:id()} with {cmd:merge}; patient-level
flags are attached back to the original row structure.{p_end}

{phang2}{bf:Avoid changing the active data:} add {cmd:frame(name)} for a named
result frame, or {cmd:preserve} when you only need returned results and console
output.{p_end}

{phang2}{bf:Save deliverables:} use {cmd:export()} for the prevalence table and
{cmd:saving()} for the transformed dataset. Do not confuse these with
{cmd:save()}, which writes reusable scan definitions.{p_end}


{marker patterns}{...}
{title:Regex and variable lists in plain language}

{pstd}
The words after {cmd:codescan} and before the comma are a normal Stata
{it:varlist}: they tell {cmd:codescan} which variables contain codes. The
rules in {cmd:define()} or {cmd:codefile()} are applied to every variable in
that varlist.

{phang2}{cmd:. codescan dx1 dx2 dx3, define(dm2 "E11")}{p_end}
{phang2}{cmd:. codescan dx1-dx30, define(dm2 "E11")}{p_end}
{phang2}{cmd:. codescan dx*, define(dm2 "E11")}{p_end}
{phang2}{cmd:. codescan dx1-dx30 proc1-proc20, define(dm2 "E11" | proc "XF001")}{p_end}

{pstd}
Use explicit names when there are only a few code variables. Use a range such
as {cmd:dx1-dx30} when those variables sit next to each other in the dataset
order. Use a wildcard such as {cmd:dx*} when every variable with that prefix
should be scanned. A variable may appear only once in {varlist}; a repeat —
directly or through overlapping ranges such as {cmd:dx1-dx5 dx3-dx8} — is
rejected, because the repeated column would be counted twice under
{cmd:countmode}, {cmd:countrows}, or {cmd:detail}. If diagnosis, procedure, and
medication codes need different dictionaries, run separate scans and add
{cmd:generate()} prefixes so the output names do not collide.

{phang2}{cmd:. codescan dx1-dx30, define(dm2 "E11" | htn "I1[0-35]") generate(dx_)}{p_end}
{phang2}{cmd:. codescan proc1-proc20, define(mammo "XF001|XF002" | colectomy "JFB|JFH") ///}{p_end}
{phang2}{cmd:    mode(prefix) generate(proc_)}{p_end}

{pstd}
In the default {cmd:mode(regex)}, {cmd:codescan} uses Stata's {cmd:ustrregexm()}
function and automatically adds a start-of-string anchor. The rule
{cmd:define(dm2 "E11")} is checked like {cmd:ustrregexm(code, "^(E11)")}: the code
must start with {cmd:E11}.

{phang2}{cmd:"E11"} matches {cmd:E110}, {cmd:E119}, and {cmd:E11.9}; it does
not match {cmd:AE11}.{p_end}

{phang2}{cmd:"I1[0-35]"} matches {cmd:I10}, {cmd:I11}, {cmd:I12}, {cmd:I13},
and {cmd:I15}. The brackets mean "one character from this set"; {cmd:[0-35]}
means {cmd:0}, {cmd:1}, {cmd:2}, {cmd:3}, or {cmd:5}.{p_end}

{phang2}{cmd:"E1[01]"} matches {cmd:E10} and {cmd:E11}.{p_end}

{phang2}{cmd:"C7[7-9]|C80"} matches {cmd:C77}, {cmd:C78}, {cmd:C79}, or
{cmd:C80}. A {cmd:|} inside a quoted regex pattern means "or".{p_end}

{pstd}
The unquoted {cmd:|} in {cmd:define()} has a different job: it separates named
conditions. Thus {cmd:define(dm2 "E11" | htn "I1[0-35]")} defines two
conditions, while {cmd:define(metastatic "C7[7-9]|C80")} defines one condition
with two regex alternatives.

{pstd}
Use {cmd:~} for exclusions: {cmd:define(dm2 "E11" ~ "E116")} matches codes
that start with {cmd:E11}, except codes that start with {cmd:E116}. In
{cmd:mode(prefix)}, regex characters are not special; {cmd:"XF001|XF002"} means
"starts with {cmd:XF001} or starts with {cmd:XF002}".

{pstd}
{cmd:codescan} rejects any inclusion or exclusion pattern that can match an
empty string, because anchoring makes such a pattern
match {it:every} code: an inclusion of that shape flags the whole dataset and an exclusion of that
shape empties it, both silently. Rejected shapes include the empty pattern,
{cmd:()}, {cmd:(())}, a trailing empty alternative such as {cmd:(E11|)}, and
quantifiers that permit zero characters such as {cmd:A*}, {cmd:A?}, and
{cmd:A{c -(}0{c )-}}. To match any nonempty code deliberately, use the pattern
{cmd:.} — one arbitrary character — rather than {cmd:.*}.

{pstd}
For troubleshooting, add {cmd:detail} to see how many matches came from each
scanned variable. Use {helpb codescan_describe} to inventory the code values
before writing rules; it pools the nonempty codes across the listed variables.


{marker options}{...}
{title:Options}

{dlgtab:Definition source}

{phang}
{opt define(string)} specifies one or more condition definitions separated by
{cmd:|}. Each definition has the form
{cmd:name "pattern" [~ "exclusion" [~ "exclusion2" ...]]}.{p_end}

{pmore}
Example: {cmd:define(dm2 "E11" | htn "I1[0-35]" | dm_comp "E10[2-7]")}.{p_end}

{pmore}
In {cmd:regex} mode, each inclusion and exclusion pattern is automatically
anchored at the start of the code value. For example, {cmd:"E11"} is treated
as {cmd:^(E11)}.

{pmore}
An unquoted {cmd:|} separates definitions in {cmd:define()}; a {cmd:|} inside a
quoted pattern remains part of that regex or prefix list. For example,
{cmd:define(metastatic "C7[7-9]|C80")} is one condition, while
{cmd:define(dm2 "E11" | htn "I1[0-35]")} is two conditions.

{pmore}
In {cmd:prefix} mode, pipe-separated tokens are treated as alternative
prefixes: {cmd:define(mammo "XF001|XF002" | colectomy "JFB|JFH")}.

{pmore}
Exclusions are checked inline for each code value. An excluded value is
ignored, but it does {it:not} cancel a valid match found in another variable on the
same observation. In {cmd:countmode}, excluded values simply contribute zero to the
count.

{pmore}
Condition names must be valid Stata names, unique, and no longer than 26
characters so that {cmd:_first}, {cmd:_last}, {cmd:_count}, and {cmd:_nrows} suffixes still
fit inside Stata's 32-character variable-name limit.

{phang}
{opt codefile(string)} reads definitions from a CSV or {cmd:.dta} dataset. The
file must contain string variables {bf:name} and {bf:pattern}. Optional columns
are {bf:label} and {bf:exclusion}. Column names are matched case-insensitively.

{pmore}
The {bf:name} column must contain valid, unique Stata names no longer than 26
characters. The {bf:pattern} column supplies the inclusion rule. The {bf:exclusion}
column supplies one or more exclusions separated by {cmd:|}. The {bf:label} column is
used for variable labels and displayed/exported condition labels.

{pmore}
Use a codefile when definitions should be version-controlled, reused across
projects, or shared with collaborators.

{pmore}
The codefile uses the same matching rules as {cmd:define()}. Each row is one
condition. The definitions are applied to all variables in {varlist}; use
separate {cmd:codescan} calls with {cmd:generate()} prefixes when different
variable groups need different dictionaries.

{phang}
{opt label(string)} assigns labels to named conditions. Entries are separated by
{cmd:\}, not {cmd:|}. For example
{cmd:label(dm2 "Type 2 diabetes" \ htn "Hypertension")} labels two conditions. If
labels were supplied
in {cmd:codefile()}, {cmd:label()} overrides them. Conditions without an explicit
label fall back to the condition name. When {cmd:generate()} is used, label names
may be written with bare condition names; the generate-prefix fallback is applied
automatically.

{pmore}
A label is used everywhere the result is {it:presented}: the variable label of
the indicator/count variable and any date-summary variables, the {cmd:Condition}
column of the displayed table, the {cmd:detail} table, the bar labels of
{cmd:graph}, and a dedicated {cmd:label} column in {cmd:export()}. A label longer
than the console column is truncated there with a trailing {cmd:~}; it reaches
the export whole.

{pmore}
Labels never become identifiers. {cmd:r(conditions)}, the row names of every
returned matrix, and the {cmd:condition} column of {cmd:export()} always carry
the condition {it:name}, so relabeling a condition cannot break a do-file that
reads the results.

{pmore}
Label text may not contain a double quote. The most common way to trip this is
writing {cmd:define()}'s separator by mistake: with {cmd:|} the whole option is
read as a single entry whose label text runs on past the closing quote, which
would label one condition with nonsense and leave the rest unlabelled. That is
rejected with {cmd:r(198)} rather than applied.

{phang}
{opt save(filename [, replace])} writes the parsed {cmd:define()} rules to a CSV
with columns {cmd:name}, {cmd:pattern}, {cmd:exclusion}, and {cmd:label}. The
filename must end in {cmd:.csv}. This option is not allowed with
{cmd:codefile()} because a file-based definition source already exists. An
existing file is never overwritten unless the {cmd:replace} suboption is given.

{dlgtab:Identifiers and windows}

{phang}
{opt id(varname)} specifies the patient or entity identifier. It is required
with {cmd:collapse} and {cmd:merge}. Observations with missing {cmd:id()} are
excluded from patient-level outputs.

{phang}
{opt date(varname)} specifies the row-level event date. It must be numeric and
stored on Stata's daily date scale. It is required for windowing and for
{cmd:earliestdate}, {cmd:latestdate}, and {cmd:countdate}.

{phang}
{opt refdate(varname)} specifies the reference date used by
{cmd:lookback()} and {cmd:lookforward()}. It must also be a numeric daily date.

{phang}
{opt lookback(#|numlist)} limits matches to observations within a backward window
relative to {cmd:refdate}. Every value must be a nonnegative integer. A single
value such as {cmd:lookback(365)} scans one window. A
numlist such as {cmd:lookback(90 365 1825)} or {cmd:lookback(30(30)90)} performs a
multi-window sensitivity analysis and returns {cmd:r(sensitivity)} together with
its denominators in {cmd:r(sensitivity_n)}. Multi-window use
requires {cmd:collapse} or {cmd:merge}.

{phang}
{opt lookforward(#)} limits matches to observations within a forward window
relative to {cmd:refdate}. The argument must be a nonnegative integer.

{phang}
{opt inclusive} includes {cmd:refdate} in a single-direction window. When both
{cmd:lookback()} and {cmd:lookforward()} are specified, {cmd:refdate} is always
included and {cmd:inclusive} is unnecessary.

{pmore}
Rows with missing {cmd:date()} or {cmd:refdate()} are excluded whenever
windowing is used.

{dlgtab:Result dataset}

{phang}
{opt collapse} reduces the data to one row per {cmd:id()}. By default the
condition variables are collapsed with {cmd:(max)} so that any qualifying row
sets the patient-level indicator to 1. With {cmd:countmode}, condition variables
are collapsed with {cmd:(sum)} instead.

{phang}
{opt merge} computes patient-level results exactly as {cmd:collapse} would, then
merges them back onto the original row structure. Every row for a given
{cmd:id()} receives the same patient-level values.

{phang}
{opt earliestdate}, {opt latestdate}, and {opt countdate} create {it:name}_first, {it:name}_last, and
{it:name}_count variables, respectively. These require {cmd:date()} plus either {cmd:collapse}
or {cmd:merge}. {cmd:countdate} counts unique dates with at least one qualifying match.

{phang}
{opt countrows} creates {it:name}_nrows variables containing the number of rows
(observations) with a qualifying match for each condition. Unlike {cmd:countdate},
which counts unique dates, {cmd:countrows} counts raw rows. This requires {cmd:collapse}
or {cmd:merge} but does not require {cmd:date()}. With {cmd:countmode}, {cmd:_nrows} sums the per-row
match counts rather than simply counting rows with any match.

{phang}
{opt alldates} is shorthand for specifying {cmd:earliestdate latestdate countdate}. It
does not include {cmd:countrows}.

{phang}
{opt preserve} wraps the destructive part of {cmd:collapse} or {cmd:merge} in
{cmd:preserve}/{cmd:restore}. Summary output and returned results remain available, but
the created variables are not left in the active dataset. On that path,
{cmd:r(newvars)} is empty because nothing remains in memory.

{phang}
{opt frame(name)} stores the final result dataset in a named frame and implies
{cmd:preserve}. With {cmd:collapse}, the frame receives the collapsed
patient-level dataset. With {cmd:merge}, the frame receives the merged row-level result. If the
frame already exists, add {cmd:replace}.

{phang}
{opt saving(filename [, replace])} saves the final result dataset to disk after
{cmd:collapse} or {cmd:merge}. The only supported suboption is {cmd:replace}, and
without it an existing file is never overwritten.

{dlgtab:Diagnostics and reporting}

{phang}
{opt detail} displays and returns a per-variable contribution table in
{cmd:r(varcounts)}. Counts reflect effective matches after exclusions.

{pmore}
By default the table is {bf:order-dependent}. Binary matching stops examining a
condition once it has matched an observation, so each row is counted once per
condition and attributed to the {bf:first} matching variable in {varlist}
order. If an observation carries the same condition in {cmd:dx1} and {cmd:dx2}, the
match is credited to {cmd:dx1} alone; scanning {cmd:dx2 dx1} instead credits
{cmd:dx2}. The cohort, the prevalence, and {cmd:r(summary)} are identical either
way -- only the attribution moves. Row totals therefore equal the number of
matching observations, not the number of matching code slots.

{pmore}
{opt allslots} counts every matching slot instead, so an observation with the
condition in two variables adds one to each. The table then does not depend on
{varlist} order and its row totals equal the slot-hit totals reported by
{cmd:countmode}. The indicator variables stay 0/1 -- {cmd:allslots} changes only
the {cmd:detail} tally, never the cohort. It requires {cmd:detail} and is
redundant with {cmd:countmode}, which already counts every slot. The scalar
{cmd:r(detail_allslots)} records which rule produced {cmd:r(varcounts)}.

{phang}
{opt cooccurrence} computes and returns {cmd:r(cooccurrence)}, a symmetric matrix
of pairwise counts. In row-level mode it counts observations. After
{cmd:collapse} or {cmd:merge}, it counts unique {cmd:id()} values.

{phang}
{opt unmatched(name)} creates a row-level flag with three states: 1 when an
analyzed observation matched no condition, 0 when an analyzed observation
matched at least one, and missing ({cmd:.}) when the row was not analyzed at
all. Rows fall outside the analysis sample when they are excluded by {cmd:if} or
{cmd:in}, by a missing {cmd:id()} under {cmd:collapse}/{cmd:merge}, or by a time
window. It is not retained after {cmd:collapse}, but it is retained in
row-level or {cmd:merge} output.

{pmore}
Counting unanalyzed rows as matched-nothing would inflate any denominator built
from the flag, so {cmd:count if `name' == 1} counts genuine non-matches and
{cmd:count if !missing(`name')} reproduces {cmd:r(N)} at the row level.

{phang}
{opt matched_code(name)} creates a row-level {cmd:str244} variable containing the first
code value that survived inclusion and exclusion checks for any condition. It
is empty when nothing matched. Like {cmd:unmatched()}, it is not retained after
{cmd:collapse}.

{phang}
{opt graph} draws a horizontal bar chart of condition prevalence.

{phang}
{opt export(filename [, replace])} writes the summary table to {cmd:.csv} or
{cmd:.xlsx}. An existing file is never overwritten unless the {cmd:replace}
suboption is given. Exported columns are {cmd:condition}, {cmd:label},
{cmd:matches}, {cmd:total_hits}, {cmd:positive_units}, {cmd:prevalence},
{cmd:ci_low}, {cmd:ci_high}, {cmd:pattern}, and {cmd:exclusion}.

{pmore}
{cmd:condition} is the machine name and {cmd:label} the display text from
{cmd:label()}, falling back to the name. {cmd:matches} is retained for
compatibility and mirrors {cmd:r(summary)}'s {cmd:count} column, while
{cmd:total_hits} and {cmd:positive_units} name the two quantities explicitly and
are the ones to read. When both {cmd:cooccurrence} and {cmd:export(.xlsx)} are used, the workbook
receives a second sheet named {cmd:cooccurrence} with a {cmd:condition} column and one
column per condition containing the pairwise count.

{phang}
{opt format(%fmt)} controls the displayed and exported format of prevalence and
confidence-interval columns. The default prevalence format is {cmd:%9.1f}.

{dlgtab:Matching behavior and naming}

{phang}
{opt mode(string)} chooses the matching engine. {cmd:regex} is the default and
anchors each pattern at the start of the code. {cmd:prefix} compares simple
pipe-separated prefixes and is usually faster on large datasets.

{phang}
{opt level(#)} truncates each prefix token to {it:#} characters before scanning. It is
meaningful only in {cmd:mode(prefix)} and must be between 1 and 10.

{phang}
{opt nocase} makes matching case-insensitive. Prefix mode uses unicode case
folding; regex mode uses the ICU case-insensitive flag without rewriting the
pattern, so escapes such as {cmd:\d} retain their meaning.

{phang}
{opt nodots} strips periods from each code value during matching. The original
data are unchanged.

{phang}
{opt tostring} converts numeric variables in {varlist} to temporary strings for scanning,
leaving the original numeric variables unchanged. This is helpful when code
variables were imported as numeric rather than text. Scan variables must be
fixed-width strings ({cmd:str#}); {cmd:strL} variables are rejected — convert them first
with {helpb compress} or {helpb recast}.

{phang}
{opt countmode} stores integer counts rather than 0/1 indicators. At the row
level, each count is the number of code slots in {varlist} that matched the
condition. Under {cmd:collapse} or {cmd:merge}, patient-level counts are sums
across qualifying rows.

{pmore}
{cmd:countmode} makes two different quantities available, and they are reported
separately because confusing them overstates a cohort:

{p2colset 9 28 30 2}{...}
{p2col:{cmd:total_hits}}the number of matching code slots -- a patient with the
same condition in two slots contributes 2{p_end}
{p2col:{cmd:positive_units}}the number of observations, or of {cmd:id()} values
under {cmd:collapse}/{cmd:merge}, with a count greater than zero{p_end}
{p2colreset}{...}

{pmore}
Prevalence and its confidence interval are built from {cmd:positive_units}, so
prevalence means the same thing with and without {cmd:countmode}. Both quantities
appear in the displayed table (as {cmd:Hits} and {cmd:Units>0}), in
{cmd:r(summary)}, in {cmd:r(codelist)}, and in {cmd:export()}. Without
{cmd:countmode} there is no hit total to report -- binary matching never counts
repeat hits -- so {cmd:total_hits} is missing rather than a copy of
{cmd:positive_units}.

{phang}
{opt generate(prefix)} prefixes all created variable names, including date-summary
variables. This is useful when diagnosis, procedure, and
medication scans should coexist in the same dataset.

{phang}
{opt replace} allows overwriting existing output variables and existing frames
named in {cmd:frame()}, but scan variables named in {varlist} are never valid
output targets. It governs variables and frames only; overwriting a {it:file}
requires the {cmd:replace} suboption of {cmd:export()}, {cmd:save()}, or
{cmd:saving()}.

{phang}
{opt noisily} prints progress notes during execution, including per-condition
match totals.


{marker windows}{...}
{title:Time windows}

{pstd}
The window rules implemented by {cmd:codescan} are:

{phang2}{cmd:lookback(#)} only: date in [{cmd:refdate} - #, {cmd:refdate}){p_end}

{phang2}{cmd:lookback(#)} with {cmd:inclusive}: date in [{cmd:refdate} - #, {cmd:refdate}]{p_end}

{phang2}{cmd:lookforward(#)} only: date in ({cmd:refdate}, {cmd:refdate} + #]{p_end}

{phang2}{cmd:lookforward(#)} with {cmd:inclusive}: date in [{cmd:refdate}, {cmd:refdate} + #]{p_end}

{phang2}{cmd:lookback(#)} plus {cmd:lookforward(#)}: date in
[{cmd:refdate} - lookback, {cmd:refdate} + lookforward]{p_end}

{pstd}
When a window is active, {cmd:r(N)} refers to the analyzed sample after {cmd:if},
{cmd:in}, missing-date filtering, and window restrictions. After
{cmd:collapse}/{cmd:merge}, {cmd:r(N)} instead reports the number of unique
patient IDs represented in the final summary.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Interpreting prevalence.} The reported prevalence is the prevalence of the
{it:code definition} you supplied — the share of analyzed observations (at the row
level) or persons (after {cmd:collapse} or {cmd:merge}) whose codes match the rule — not
the prevalence of the underlying disease. The two differ by the validity of
the codes in your data: a code's positive predictive value and sensitivity
govern how far coded prevalence sits from true prevalence. The row-level
console header labels the denominator as {cmd:observations} (encounters), and the
person-level header labels it as {cmd:id()} values, so the analysis unit is never
ambiguous. The Wilson confidence interval reflects sampling error only; it
does {it:not} account for coding error, misclassification, or incomplete
capture. Treat {cmd:codescan} output as the prevalence of a code-based case
definition and validate that definition against the relevant
register-validation literature before reading it as disease frequency.

{pstd}
{bf:Diagnosis position.} Rules are applied uniformly to every variable in
{varlist}, and a match in any slot sets the row indicator. In many registers
the main (first-listed) diagnosis carries higher validity than contributory
positions, so when position matters, scan the positions separately — for example
{cmd:codescan dx1, ...} for a main-diagnosis-only definition, or run the primary
and secondary slots as separate calls with {cmd:generate()} prefixes. Use
{cmd:detail} to see each slot's contribution to a condition -- with
{cmd:allslots} if you want each slot's contribution counted independently rather
than each row credited to its first matching slot.

{pstd}
{bf:Pattern choice.} Use {cmd:regex} when you need character classes,
alternation, or more complicated anchored expressions. Use {cmd:prefix} when the
rule is a simple startswith comparison and performance matters.

{pstd}
{bf:Regex engine and unicode.} {cmd:regex} patterns are matched with Stata's
unicode-aware {help strregex:ustrregexm()} engine and are case-sensitive unless
{cmd:nocase} is given; {cmd:nocase} matches case-insensitively across unicode,
so a pattern such
as {cmd:"Å"} matches both {cmd:å} and {cmd:Å} (useful for Nordic
register codes). A structurally invalid {cmd:regex} pattern (for example an
unbalanced bracket, an empty group, or a malformed quantifier like
{cmd:a{c -(}2,1{c )-}}) is {it:rejected} with an error rather than silently
matching nothing, so a typo cannot quietly produce an all-zero cohort. An empty
alternation branch — a stray leading, trailing, or doubled {cmd:|} such as
{cmd:"E11|"} or {cmd:"E11||E12"} — is likewise rejected, because its empty branch
would otherwise match {it:every} code and silently produce a match-everything
cohort (or, in an exclusion, drop every row). Empty alternatives are rejected
in {cmd:prefix} mode as well, where silently dropping one would hide a malformed
code list.

{pstd}
{bf:File paths.} For safety, {cmd:codefile()}, {cmd:save()}, {cmd:export()},
and {cmd:saving()} reject quotes, shell metacharacters, and control characters
inside filenames. Use ordinary quoted paths with spaces or hyphens.

{pstd}
{bf:Reusable workflows.} Many projects start with
{helpb codescan_describe}, then write a first pass with {cmd:define()}, and
finally freeze those rules with {cmd:save()} for future runs through
{cmd:codefile()}.

{pstd}
{bf:Codefiles for teams.} A codefile is usually the most transparent way to
review and reuse definitions. Keep one row per condition, put the main
inclusion rule in {cmd:pattern}, put exception rules in {cmd:exclusion}, and
use {cmd:label} for clinical or project-facing wording.

{pstd}
{bf:countmode and countrows.} Without {cmd:countmode}, {cmd:_nrows} counts the
number of rows with at least one qualifying match. With {cmd:countmode},
{cmd:_nrows} sums the per-row match counts (total code-slot hits across all rows
for that patient).

{pstd}
{bf:Frames and restore behavior.} If you need a non-destructive workflow,
{cmd:preserve} keeps the active dataset untouched and {cmd:frame()} gives you a
named copy of the finished result dataset. That is the recommended pattern when
you want both the original encounter-level data and a patient-level summary in
the same session.

{pstd}
{bf:Engine.} {cmd:codescan} applies the whole rule set in a single Mata pass over the
code variables, so you express a multi-condition definition once instead of
writing one {cmd:generate}/{cmd:replace} per condition per variable. Its value is
correctness and conciseness — per-cell exclusions, patient-level collapse with
date statistics, time windows, and prevalence CIs in one command — rather than
raw speed against a hand-written loop.


{marker examples}{...}
{title:Examples}

{pstd}
The following setup block creates a small toy dataset that is copy-paste
runnable after {cmd:net install}. Rerun it before any example that changes
the data in memory. The dataset represents five encounters for three patients,
each with up to two diagnosis codes, one procedure code, a visit date, and an
index date.

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long pid str6 dx1 str6 dx2 str6 proc1 double visit_dt double index_dt}{p_end}
{phang2}{cmd:      1 "E110" "I10"  "XF001" 21914 21915}{p_end}
{phang2}{cmd:      1 "Z00"  "E119" ""      21880 21915}{p_end}
{phang2}{cmd:      2 "I50"  ""     "JFB10" 21900 21915}{p_end}
{phang2}{cmd:      2 "E102" ""     ""      22020 21915}{p_end}
{phang2}{cmd:      3 "Z00"  ""     ""      21910 21915}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. format visit_dt index_dt %td}{p_end}

{pstd}
{bf:Example 1: Row-level indicators}

{pstd}
The simplest use case. Scan {cmd:dx1} and {cmd:dx2} for two conditions. Each
row gets a 0/1 variable for each condition. The console output shows
prevalence and Wilson confidence intervals.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]")}{p_end}

{pstd}
After this command, {cmd:dm2} is 1 on any row where {cmd:dx1} or {cmd:dx2}
starts with {cmd:E11}, and {cmd:htn} is 1 where either slot starts with
{cmd:I10}, {cmd:I11}, {cmd:I12}, {cmd:I13}, or {cmd:I15}.

{pstd}
{bf:Example 2: Patient-level collapse with a lookback window and date summaries}

{pstd}
Collapse to one row per patient, restricting to encounters within 365 days
before {cmd:index_dt} (inclusive). {cmd:alldates} creates {cmd:_first},
{cmd:_last}, and {cmd:_count} date-summary variables for each condition.

{phang2}{cmd:. codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///}{p_end}
{phang2}{cmd:    define(dm2 "E11" | htn "I1[0-35]" | chf "I50") ///}{p_end}
{phang2}{cmd:    lookback(365) inclusive collapse alldates}{p_end}

{pstd}
Patient 2's second encounter (E102, 2020-04-15) falls {it:after} the index
date, so it is excluded by the lookback window.

{pstd}
{bf:Example 3: Prefix matching for procedure codes}

{pstd}
Switch to {cmd:mode(prefix)} when patterns are simple starts-with strings
rather than regex expressions. Pipe-separated tokens are alternative
prefixes:

{phang2}{cmd:. codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)}{p_end}

{pstd}
{bf:Example 4: Exclusion patterns}

{pstd}
Use {cmd:~} to exclude specific codes that would otherwise be caught by the
inclusion pattern. Here {cmd:dm2} matches all {cmd:E11*} codes except
{cmd:E116} (unspecified hypoglycaemia):

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I1[0-35]")}{p_end}

{pstd}
{bf:Example 5: Save an inline rule set, then reuse it as a codefile}

{pstd}
During development, iterate with {cmd:define()}. Once the rules look right,
freeze them to a CSV with {cmd:save()}, then switch future runs to
{cmd:codefile()}.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)}{p_end}
{phang2}{cmd:. codescan dx1 dx2, codefile(dm_rules.csv) replace}{p_end}

{pstd}
The first run leaves the {cmd:dm2} and {cmd:htn} indicators in memory, so the
codefile re-run adds {cmd:replace} to overwrite them. In a fresh session that
loads only the saved rules, {cmd:replace} is unnecessary.

{pstd}
{bf:Example 6: Multi-window sensitivity analysis}

{pstd}
Supply several lookback values to compare how prevalence changes across
windows. {cmd:r(sensitivity)} returns a matrix of prevalences by condition and
window.

{phang2}{cmd:. codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///}{p_end}
{phang2}{cmd:    define(dm2 "E11" | htn "I1[0-35]") ///}{p_end}
{phang2}{cmd:    lookback(90 365) inclusive collapse}{p_end}

{pstd}
{bf:Example 7: Non-destructive workflow with frames}

{pstd}
{cmd:frame()} stores the collapsed result in a named frame, leaving the
original data untouched. This is the recommended pattern when you need both
the encounter-level data and a patient-level summary in the same session.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///}{p_end}
{phang2}{cmd:    frame(results) replace}{p_end}
{phang2}{cmd:. frame results: list}{p_end}

{pstd}
{bf:Example 8: Export a formatted summary and save the final dataset}

{pstd}
{cmd:export()} writes the prevalence table to {cmd:.csv} or {cmd:.xlsx}. {cmd:saving()} saves the
transformed dataset that {cmd:codescan} leaves in memory after {cmd:collapse} or {cmd:merge}.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///}{p_end}
{phang2}{cmd:    export(codescan_results.xlsx) saving(codescan_results.dta, replace) format(%9.2f)}{p_end}

{pstd}
{bf:Example 9: Merge results back to original rows}

{pstd}
{cmd:merge} computes patient-level summaries and joins them back, so every row
for a given patient gets the same values. This is useful when you need both
the encounter detail and the condition flags in one dataset.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) merge}{p_end}

{pstd}
{bf:Example 10: Tell hits apart from cases, and see which slot they came from}

{pstd}
A patient coded {cmd:E110} in {cmd:dx1} and {cmd:E119} in {cmd:dx2} on the same
encounter is {it:one} case carrying {it:two} hits. Both are reported by
{cmd:countmode}: the displayed {cmd:Hits} column and {cmd:r(summary)}'s {cmd:total_hits} count
slots, while {cmd:Units>0} and {cmd:positive_units} count patients, which is what
prevalence uses.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11") id(pid) collapse countmode}{p_end}
{phang2}{cmd:. matrix list r(summary)}{p_end}

{pstd}
{cmd:detail} attributes that patient's row to {cmd:dx1} alone, because binary
matching stops at the first slot that matches; scanning {cmd:dx2 dx1} would
credit {cmd:dx2} instead. Add {cmd:allslots} when you want each slot counted on
its own, which makes the table independent of {varlist} order.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11") detail}{p_end}
{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11") detail allslots}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:codescan} stores the following in {cmd:r()}:

{synoptset 26 tabbed}{...}
{p2col 5 26 30 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}analyzed observations, or unique {cmd:id()} values{p_end}
{synopt:{cmd:r(n_conditions)}}number of conditions defined{p_end}
{synopt:{cmd:r(collapsed)}}1 if {cmd:collapse} was used, otherwise 0{p_end}
{synopt:{cmd:r(merged)}}1 if {cmd:merge} was used, otherwise 0{p_end}
{synopt:{cmd:r(mode_count)}}1 if {cmd:countmode} was used, otherwise 0{p_end}
{synopt:{cmd:r(detail_allslots)}}1 if {cmd:detail} counted every slot{p_end}
{synopt:{cmd:r(lookback)}}the single lookback window, if only one{p_end}
{synopt:{cmd:r(lookforward)}}lookforward window when specified{p_end}
{synopt:{cmd:r(n_excluded_missingdate)}}rows dropped for a missing date{p_end}
{synopt:{cmd:r(ci_level)}}confidence level used for Wilson intervals{p_end}

{p2col 5 26 30 2: Macros}{p_end}
{synopt:{cmd:r(conditions)}}condition names in output order{p_end}
{synopt:{cmd:r(newvars)}}variables left in memory on exit{p_end}
{synopt:{cmd:r(varlist)}}scanned variables{p_end}
{synopt:{cmd:r(mode)}}matching mode, {cmd:regex} or {cmd:prefix}{p_end}
{synopt:{cmd:r(nocase)}}{cmd:nocase} when case-insensitive matching was used{p_end}
{synopt:{cmd:r(generate)}}prefix supplied in {cmd:generate()}{p_end}
{synopt:{cmd:r(define)}}full {cmd:define()} string when used{p_end}
{synopt:{cmd:r(codefile)}}codefile path when used{p_end}
{synopt:{cmd:r(id)}}identifier variable when specified{p_end}
{synopt:{cmd:r(date)}}event-date variable when {cmd:date()} was specified{p_end}
{synopt:{cmd:r(refdate)}}reference-date variable when windowing was used{p_end}
{synopt:{cmd:r(frame)}}frame name when {cmd:frame()} was used{p_end}
{synopt:{cmd:r(lookback)}}the lookback values, if more than one{p_end}

{p2col 5 26 30 2: Matrices}{p_end}
{synopt:{cmd:r(summary)}}counts, prevalence, and Wilson interval{p_end}
{synopt:{cmd:r(codelist)}}the count columns of {cmd:r(summary)}{p_end}
{synopt:{cmd:r(varcounts)}}per-variable counts, with {cmd:detail}{p_end}
{synopt:{cmd:r(cooccurrence)}}pairwise co-occurrence counts{p_end}
{synopt:{cmd:r(sensitivity)}}prevalence by lookback window{p_end}
{synopt:{cmd:r(sensitivity_n)}}denominators for {cmd:r(sensitivity)}{p_end}

{pstd}
{cmd:r(N)} counts analyzed observations at the row level and unique {cmd:id()}
values after {cmd:collapse} or {cmd:merge}. {cmd:r(newvars)} lists the variables
left in memory on exit; it is empty after {cmd:preserve} or {cmd:frame()},
because nothing was left behind. {cmd:r(n_excluded_missingdate)} is returned
only when a window was requested, and counts the rows dropped for a missing
{cmd:date()} or {cmd:refdate()}.

{pstd}
{cmd:r(summary)} has one row per condition, named for the condition, and six
columns: {cmd:count}, {cmd:prevalence}, {cmd:ci_low}, {cmd:ci_high},
{cmd:total_hits}, and {cmd:positive_units}. {cmd:count} is the historical
column and keeps its historical meaning -- {cmd:total_hits} under
{cmd:countmode}, {cmd:positive_units} otherwise -- so code written against
earlier versions still reads what it read before. New code should prefer the two
named columns, which never change meaning. {cmd:total_hits} is missing without
{cmd:countmode}. The same count columns repeat in {cmd:r(codelist)} as
{cmd:count}, {cmd:prevalence}, {cmd:total_hits}, {cmd:positive_units}.

{pstd}
{cmd:r(lookback)} is returned as a {it:scalar} when one window was requested and
as a {it:macro} of space-separated values when several were. Test for the
multi-window case with {cmd:if "`r(lookback)'" != ""} rather than assuming
either type.

{pstd}
{cmd:r(varcounts)} is returned with {cmd:detail}, {cmd:r(cooccurrence)} with
{cmd:cooccurrence}, and {cmd:r(sensitivity)} plus {cmd:r(sensitivity_n)} when
{cmd:lookback()} named more than one window. {cmd:r(sensitivity)} holds
prevalence per condition (rows) by window (columns); {cmd:r(sensitivity_n)} is
the matching single-row matrix of denominators, since each window analyzes a
different number of observations or patients. Read the two together — a
prevalence that moves across windows may reflect a changing denominator rather
than a changing numerator.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb codescan_describe}, {helpb collapse}, {helpb merge}, {helpb tostring}

{hline}

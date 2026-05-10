{smcl}
{* *! version 1.1.0  24apr2026}{...}
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
{viewerjumpto "References" "codescan##references"}{...}
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
{synopt:{opt save(filename)}}write parsed {cmd:define()} rules to a CSV codefile{p_end}

{syntab:Identifiers and windows}
{synopt:{opt id(varname)}}patient or entity identifier; required with {cmd:collapse} or {cmd:merge}{p_end}
{synopt:{opt date(varname)}}row-level event date; required for windowing and date summaries{p_end}
{synopt:{opt refd:ate(varname)}}reference date for windowing{p_end}
{synopt:{opt lookb:ack(#|numlist)}}days before {cmd:refdate}; multiple values return sensitivity results{p_end}
{synopt:{opt lookf:orward(#)}}days after {cmd:refdate}{p_end}
{synopt:{opt incl:usive}}include {cmd:refdate} in single-direction windows{p_end}

{syntab:Result dataset}
{synopt:{opt coll:apse}}reduce to one row per {cmd:id()}{p_end}
{synopt:{opt mer:ge}}attach patient-level results back to row-level data{p_end}
{synopt:{opt earliest:date}}create {it:name}_first variables{p_end}
{synopt:{opt latest:date}}create {it:name}_last variables{p_end}
{synopt:{opt countd:ate}}create {it:name}_count variables (unique dates){p_end}
{synopt:{opt countr:ows}}create {it:name}_nrows variables (row counts){p_end}
{synopt:{opt alld:ates}}shorthand for all three date-summary options{p_end}
{synopt:{opt pre:serve}}restore the original data after producing results{p_end}
{synopt:{opt frame(name)}}store the final result dataset in a named frame{p_end}
{synopt:{opt sav:ing(filename [, replace])}}save the final result dataset to disk{p_end}

{syntab:Scoring, diagnostics, and reporting}
{synopt:{opt det:ail}}return per-variable match counts{p_end}
{synopt:{opt cooc:currence}}return pairwise co-occurrence counts{p_end}
{synopt:{opt score(string)}}Charlson, Elixhauser, or custom weighted score{p_end}
{synopt:{opt hier:archy(string)}}apply superior > inferior condition rules before scoring{p_end}
{synopt:{opt unm:atched(name)}}row-level flag for observations with no matches{p_end}
{synopt:{opt match:ed_code(name)}}row-level variable holding the first code that survived matching{p_end}
{synopt:{opt gr:aph}}draw a prevalence bar chart{p_end}
{synopt:{opt exp:ort(filename)}}export the summary table to {cmd:.csv} or {cmd:.xlsx}{p_end}
{synopt:{opt for:mat(%fmt)}}display and export format for prevalence and CI columns{p_end}

{syntab:Matching behavior and naming}
{synopt:{opt mod:e(string)}}{cmd:regex} (default) or {cmd:prefix}{p_end}
{synopt:{opt lev:el(#)}}truncate each prefix token to {it:#} characters in prefix mode{p_end}
{synopt:{opt noc:ase}}case-insensitive matching{p_end}
{synopt:{opt nod:ots}}strip dots during matching{p_end}
{synopt:{opt tostr:ing}}convert numeric code variables to string before scanning{p_end}
{synopt:{opt countm:ode}}store counts rather than binary indicators{p_end}
{synopt:{opt gen:erate(prefix)}}prefix all created variable names, including the score variable{p_end}
{synopt:{opt rep:lace}}allow overwriting existing output variables or frames{p_end}
{synopt:{opt noi:sily}}display per-condition progress notes{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:codescan} scans wide-format code slots — such as {cmd:dx1} through
{cmd:dx30} or {cmd:proc1} through {cmd:proc20} — and creates condition
indicators (or counts) from a single declarative rule set.  It is designed for
administrative data, registry data, claims data, and other datasets where each
observation stores multiple code fields side by side.  It works with any
string code system: ICD-10, ICD-9, KVÅ, CPT, ATC, OPCS, or proprietary
codes.

{pstd}
{bf:In plain language:}  You tell {cmd:codescan} which code patterns to look
for and what to name each condition.  The command scans every code slot on
every row, marks which conditions are present, and returns a summary with
prevalence and confidence intervals.  You can stay at the row level (one
indicator per encounter), collapse to one row per patient, or merge
patient-level summaries back onto the original data.

{pstd}
Rules can be supplied inline through {cmd:define()} or read from a reusable
CSV/{cmd:.dta} code dictionary via {cmd:codefile()}.  Matching is anchored at
the start of each code value — for example, the pattern {cmd:"E11"} matches
{cmd:E110}, {cmd:E119}, and any other code that starts with {cmd:E11}, but
does not match {cmd:AE11}.  The default {cmd:regex} mode supports character
classes and alternation (for example {cmd:"I1[0-35]"} matches {cmd:I10},
{cmd:I11}, {cmd:I12}, {cmd:I13}, and {cmd:I15}); {cmd:prefix} mode uses
simple starts-with comparisons and is faster when regex features are not
needed.

{pstd}
Optional time windows, date summaries, co-occurrence counts, hierarchy rules,
and Charlson/Elixhauser/custom scores support common clinical and
health-services research workflows — all without leaving Stata or reshaping
the data.

{pstd}
Use {helpb codescan_describe} first when you need to inspect the raw code
distribution before writing scan rules.


{marker workflow}{...}
{title:Typical workflow}

{pstd}
Most users will learn {cmd:codescan} fastest by treating it as a four-step
workflow rather than as a menu of unrelated options:

{phang2}1. {bf:Inspect the code inventory.}  Start with
{helpb codescan_describe} to see which codes and chapter prefixes actually
occur in your data.  This tells you what patterns to target and which chapters
to focus on.{p_end}

{phang2}2. {bf:Draft and test simple rules.}  Write an initial
{cmd:define()} specification and check the row-level results before adding
windows, dates, or scores.  At this stage, the created variables appear
alongside the original data so you can eyeball whether each match is
correct.{p_end}

{phang2}3. {bf:Choose the output shape.}  Stay row-level for auditing, use
{cmd:collapse} for one row per {cmd:id()}, or use {cmd:merge} when you need
patient-level results attached back to the original encounters.  Most analytic
pipelines want {cmd:collapse}.{p_end}

{phang2}4. {bf:Add advanced features last.}  Once the basic matches look
right, layer on {cmd:lookback()}/{cmd:lookforward()}, date summaries,
{cmd:hierarchy()}, scoring, and export/save options.  Each feature is additive
and does not change the meaning of earlier options.{p_end}

{pstd}
In practice, a common sequence is:

{phang2}{cmd:codescan_describe} (reconnaissance) {hline 1}>{p_end}
{phang2}{cmd:codescan, define(...)} at the row level (draft rules) {hline 1}>{p_end}
{phang2}{cmd:codescan, collapse} or {cmd:merge} (patient-level) {hline 1}>{p_end}
{phang2}{cmd:score()}, {cmd:export()}, or {cmd:saving()} (final deliverable){p_end}

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
{cmd:saving()} for the transformed dataset.  Do not confuse these with
{cmd:save()}, which writes reusable scan definitions.{p_end}


{marker patterns}{...}
{title:Regex and variable lists in plain language}

{pstd}
The words after {cmd:codescan} and before the comma are a normal Stata
{it:varlist}: they tell {cmd:codescan} which variables contain codes.  The
rules in {cmd:define()} or {cmd:codefile()} are applied to every variable in
that varlist.

{phang2}{cmd:. codescan dx1 dx2 dx3, define(dm2 "E11")}{p_end}
{phang2}{cmd:. codescan dx1-dx30, define(dm2 "E11")}{p_end}
{phang2}{cmd:. codescan dx*, define(dm2 "E11")}{p_end}
{phang2}{cmd:. codescan dx1-dx30 proc1-proc20, define(dm2 "E11" | proc "XF001")}{p_end}

{pstd}
Use explicit names when there are only a few code variables.  Use a range such
as {cmd:dx1-dx30} when those variables sit next to each other in the dataset
order.  Use a wildcard such as {cmd:dx*} when every variable with that prefix
should be scanned.  If diagnosis, procedure, and medication codes need
different dictionaries, run separate scans and add {cmd:generate()} prefixes so
the output names do not collide.

{phang2}{cmd:. codescan dx1-dx30, define(dm2 "E11" | htn "I1[0-35]") generate(dx_)}{p_end}
{phang2}{cmd:. codescan proc1-proc20, define(mammo "XF001|XF002" | colectomy "JFB|JFH") ///}{p_end}
{phang2}{cmd:    mode(prefix) generate(proc_)}{p_end}

{pstd}
In the default {cmd:mode(regex)}, {cmd:codescan} uses Stata's {cmd:regexm()}
function and automatically adds a start-of-string anchor.  The rule
{cmd:define(dm2 "E11")} is checked like {cmd:regexm(code, "^(E11)")}: the code
must start with {cmd:E11}.

{phang2}{cmd:"E11"} matches {cmd:E110}, {cmd:E119}, and {cmd:E11.9}; it does
not match {cmd:AE11}.{p_end}

{phang2}{cmd:"I1[0-35]"} matches {cmd:I10}, {cmd:I11}, {cmd:I12}, {cmd:I13},
and {cmd:I15}.  The brackets mean "one character from this set"; {cmd:[0-35]}
means {cmd:0}, {cmd:1}, {cmd:2}, {cmd:3}, or {cmd:5}.{p_end}

{phang2}{cmd:"E1[01]"} matches {cmd:E10} and {cmd:E11}.{p_end}

{phang2}{cmd:"C7[7-9]|C80"} matches {cmd:C77}, {cmd:C78}, {cmd:C79}, or
{cmd:C80}.  A {cmd:|} inside a quoted regex pattern means "or".{p_end}

{pstd}
The unquoted {cmd:|} in {cmd:define()} has a different job: it separates named
conditions.  Thus {cmd:define(dm2 "E11" | htn "I1[0-35]")} defines two
conditions, while {cmd:define(metastatic "C7[7-9]|C80")} defines one condition
with two regex alternatives.

{pstd}
Use {cmd:~} for exclusions: {cmd:define(dm2 "E11" ~ "E116")} matches codes
that start with {cmd:E11}, except codes that start with {cmd:E116}.  In
{cmd:mode(prefix)}, regex characters are not special; {cmd:"XF001|XF002"} means
"starts with {cmd:XF001} or starts with {cmd:XF002}".

{pstd}
For troubleshooting, add {cmd:detail} to see how many matches came from each
scanned variable.  Use {helpb codescan_describe} to inventory the code values
before writing rules; it pools the nonempty codes across the listed variables.


{marker options}{...}
{title:Options}

{dlgtab:Definition source}

{phang}
{opt define(string)} specifies one or more condition definitions separated by
{cmd:|}.  Each definition has the form
{cmd:name "pattern" [~ "exclusion" [~ "exclusion2" ...]]}.  Example:
{cmd:define(dm2 "E11" | htn "I1[0-35]" | dm_comp "E10[2-7]")}.

{pmore}
In {cmd:regex} mode, each inclusion and exclusion pattern is automatically
anchored at the start of the code value.  For example, {cmd:"E11"} is treated
as {cmd:^(E11)}.

{pmore}
An unquoted {cmd:|} separates definitions in {cmd:define()}; a {cmd:|} inside a
quoted pattern remains part of that regex or prefix list.  For example,
{cmd:define(metastatic "C7[7-9]|C80")} is one condition, while
{cmd:define(dm2 "E11" | htn "I1[0-35]")} is two conditions.

{pmore}
In {cmd:prefix} mode, pipe-separated tokens are treated as alternative prefixes:
{cmd:define(mammo "XF001|XF002" | colectomy "JFB|JFH")}.

{pmore}
Exclusions are checked inline for each code value.  An excluded value is ignored,
but it does {it:not} cancel a valid match found in another variable on the same
observation.  In {cmd:countmode}, excluded values simply contribute zero to the
count.

{pmore}
Condition names must be valid Stata names, unique, and no longer than 26
characters so that {cmd:_first}, {cmd:_last}, {cmd:_count}, and {cmd:_nrows} suffixes still
fit inside Stata's 32-character variable-name limit.

{phang}
{opt codefile(string)} reads definitions from a CSV or {cmd:.dta} dataset.  The
file must contain string variables {bf:name} and {bf:pattern}.  Optional columns
are {bf:label}, {bf:exclusion}, and {bf:weight}.  Column names are matched
case-insensitively.

{pmore}
The {bf:name} column must contain valid, unique Stata names no longer than 26
characters.  The {bf:pattern} column supplies the inclusion rule.  The
{bf:exclusion} column supplies one or more exclusions separated by {cmd:|}.
The {bf:label} column is used for variable labels and displayed/exported
condition labels.  The {bf:weight} column is required for {cmd:score(custom)}
and ignored by built-in Charlson or Elixhauser scoring.

{pmore}
Two bundled example codefiles are shipped with the package and can be requested
directly by basename:
{cmd:codefile(charlson_icd10_example.csv)} and
{cmd:codefile(elixhauser_icd10_example.csv)}.

{pmore}
Use a codefile when definitions should be version-controlled, reused across
projects, or shared with collaborators.

{pmore}
The codefile uses the same matching rules as {cmd:define()}.  Each row is one
condition.  The definitions are applied to all variables in {varlist}; use
separate {cmd:codescan} calls with {cmd:generate()} prefixes when different
variable groups need different dictionaries.

{phang}
{opt label(string)} assigns labels to named conditions.  Entries are separated by
{cmd:\}.  Example:
{cmd:label(dm2 "Type 2 diabetes" \ htn "Hypertension")}.
Labels apply to the main indicator/count variable and any date-summary variables.
If labels were supplied in {cmd:codefile()}, {cmd:label()} overrides them.
Conditions without an explicit label use the condition name as the default label
in displayed and exported output.
When {cmd:generate()} is used, label names may be written with bare condition
names; the generate-prefix fallback is applied automatically.

{phang}
{opt save(filename)} writes the parsed {cmd:define()} rules to a CSV with columns
{cmd:name}, {cmd:pattern}, {cmd:exclusion}, and {cmd:label}.  The filename must
end in {cmd:.csv}.  This option is not allowed with {cmd:codefile()} because a
file-based definition source already exists.

{dlgtab:Identifiers and windows}

{phang}
{opt id(varname)} specifies the patient or entity identifier.  It is required
with {cmd:collapse} and {cmd:merge}.  Observations with missing {cmd:id()} are
excluded from patient-level outputs.

{phang}
{opt date(varname)} specifies the row-level event date.  It must be numeric and
stored on Stata's daily date scale.  It is required for windowing and for
{cmd:earliestdate}, {cmd:latestdate}, and {cmd:countdate}.

{phang}
{opt refdate(varname)} specifies the reference date used by
{cmd:lookback()} and {cmd:lookforward()}.  It must also be a numeric daily date.

{phang}
{opt lookback(#|numlist)} limits matches to observations within a backward window
relative to {cmd:refdate}.  A single value such as {cmd:lookback(365)} scans one
window.  A numlist such as {cmd:lookback(90 365 1825)} or {cmd:lookback(30(30)90)}
performs a multi-window sensitivity analysis and returns {cmd:r(sensitivity)}.
Multi-window use requires {cmd:collapse} or {cmd:merge}.

{phang}
{opt lookforward(#)} limits matches to observations within a forward window
relative to {cmd:refdate}.  The argument must be a nonnegative integer.

{phang}
{opt inclusive} includes {cmd:refdate} in a single-direction window.  When both
{cmd:lookback()} and {cmd:lookforward()} are specified, {cmd:refdate} is always
included and {cmd:inclusive} is unnecessary.

{pmore}
Rows with missing {cmd:date()} or {cmd:refdate()} are excluded whenever
windowing is used.

{dlgtab:Result dataset}

{phang}
{opt collapse} reduces the data to one row per {cmd:id()}.  By default the
condition variables are collapsed with {cmd:(max)} so that any qualifying row
sets the patient-level indicator to 1.  With {cmd:countmode}, condition variables
are collapsed with {cmd:(sum)} instead.

{phang}
{opt merge} computes patient-level results exactly as {cmd:collapse} would, then
merges them back onto the original row structure.  Every row for a given
{cmd:id()} receives the same patient-level values.

{phang}
{opt earliestdate}, {opt latestdate}, and {opt countdate} create
{it:name}_first, {it:name}_last, and {it:name}_count variables, respectively.
These require {cmd:date()} plus either {cmd:collapse} or {cmd:merge}.
{cmd:countdate} counts unique dates with at least one qualifying match.

{phang}
{opt countrows} creates {it:name}_nrows variables containing the number of
rows (observations) with a qualifying match for each condition.  Unlike
{cmd:countdate}, which counts unique dates, {cmd:countrows} counts raw rows.
This requires {cmd:collapse} or {cmd:merge} but does not require {cmd:date()}.
With {cmd:countmode}, {cmd:_nrows} sums the per-row match counts rather than
simply counting rows with any match.

{phang}
{opt alldates} is shorthand for specifying {cmd:earliestdate latestdate countdate}.
It does not include {cmd:countrows}.

{phang}
{opt preserve} wraps the destructive part of {cmd:collapse} or {cmd:merge} in
{cmd:preserve}/{cmd:restore}.  Summary output and returned results remain
available, but the created variables are not left in the active dataset.  On that
path, {cmd:r(newvars)} is empty because nothing remains in memory.

{phang}
{opt frame(name)} stores the final result dataset in a named frame and implies
{cmd:preserve}.  With {cmd:collapse}, the frame receives the collapsed patient-
level dataset.  With {cmd:merge}, the frame receives the merged row-level result.
If the frame already exists, add {cmd:replace}.

{phang}
{opt saving(filename [, replace])} saves the final result dataset to disk after
{cmd:collapse} or {cmd:merge}.  The only supported suboption is {cmd:replace}.

{dlgtab:Scoring, diagnostics, and reporting}

{phang}
{opt detail} displays and returns a per-variable contribution table in
{cmd:r(varcounts)}.  Counts reflect effective matches after exclusions and after
binary short-circuiting.

{phang}
{opt cooccurrence} computes and returns {cmd:r(cooccurrence)}, a symmetric matrix
of pairwise counts.  In row-level mode it counts observations.  After
{cmd:collapse} or {cmd:merge}, it counts unique {cmd:id()} values.

{phang}
{opt score(string)} creates a weighted score variable named {cmd:_score}, or
{cmd:{it:prefix}_score} when {cmd:generate()} is used.

{pmore}
{cmd:score(charlson)} applies Quan et al. (2011) updated Charlson weights.
Recognized condition aliases and their weights:{break}
Weight 1: {cmd:mi}, {cmd:chf}, {cmd:pvd}, {cmd:dementia}, {cmd:copd},
{cmd:cvd}, {cmd:stroke}, {cmd:cerebrovascular},
{cmd:rheumatic}, {cmd:rheumatoid}, {cmd:connective},
{cmd:peptic}, {cmd:ulcer}, {cmd:pud},
{cmd:liver_mild}, {cmd:mild_liver},
{cmd:dm}, {cmd:dm1}, {cmd:dm2}, {cmd:dm_uncomp}, {cmd:diabetes}.{break}
Weight 2: {cmd:dm_comp}, {cmd:dm_complicated}, {cmd:diabetes_comp},
{cmd:hemiplegia}, {cmd:paraplegia}, {cmd:paralysis},
{cmd:renal}, {cmd:ckd}, {cmd:kidney},
{cmd:cancer}, {cmd:malignancy}, {cmd:tumor}.{break}
Weight 3: {cmd:liver_severe}, {cmd:severe_liver}.{break}
Weight 6: {cmd:metastatic}, {cmd:mets}, {cmd:hiv}, {cmd:aids}.{break}
Unrecognized names receive weight 0 and generate a note.

{pmore}
{cmd:score(elixhauser)} applies van Walraven et al. (2009) weights, not the
original Elixhauser (1998) weights.  Recognized condition aliases and their
weights:{break}
Weight 12: {cmd:metastatic}, {cmd:metastatic_cancer}.{break}
Weight 11: {cmd:liver}, {cmd:liver_disease}.{break}
Weight 9: {cmd:lymphoma}.{break}
Weight 7: {cmd:chf}, {cmd:heart_failure}, {cmd:paralysis}.{break}
Weight 6: {cmd:neuro_other}, {cmd:other_neurological},
{cmd:weight_loss}.{break}
Weight 5: {cmd:arrhythmia}, {cmd:cardiac_arrhythmia},
{cmd:renal}, {cmd:renal_failure},
{cmd:fluid_electrolyte}, {cmd:fluid_electrolytes}.{break}
Weight 4: {cmd:pulmonary_circ}, {cmd:pulmonary_circulation},
{cmd:solid_tumor}, {cmd:solid_tumour}.{break}
Weight 3: {cmd:copd}, {cmd:chronic_pulmonary},
{cmd:coagulopathy}.{break}
Weight 2: {cmd:pvd}, {cmd:peripheral_vascular}.{break}
Weight 0: {cmd:htn_uncomp}, {cmd:hypertension_uncomp},
{cmd:htn_comp}, {cmd:hypertension_comp},
{cmd:dm_uncomp}, {cmd:diabetes_uncomp},
{cmd:dm_comp}, {cmd:diabetes_comp},
{cmd:hypothyroid}, {cmd:hypothyroidism},
{cmd:pud}, {cmd:peptic_ulcer},
{cmd:hiv}, {cmd:aids},
{cmd:rheumatoid}, {cmd:rheumatoid_arthritis}, {cmd:collagen},
{cmd:alcohol}, {cmd:alcohol_abuse},
{cmd:psychoses}, {cmd:psychosis}.{break}
Weight {hline 1}1: {cmd:valvular}, {cmd:valvular_disease}.{break}
Weight {hline 1}2: {cmd:blood_loss_anemia}, {cmd:blood_loss},
{cmd:deficiency_anemia}, {cmd:anemia}.{break}
Weight {hline 1}3: {cmd:depression}.{break}
Weight {hline 1}4: {cmd:obesity}.{break}
Weight {hline 1}7: {cmd:drug}, {cmd:drug_abuse}.{break}
Unrecognized names receive weight 0 and generate a note.

{pmore}
{cmd:score(custom)} reads weights from the {bf:weight} column in {cmd:codefile()}.

{pmore}
For {cmd:charlson} and {cmd:elixhauser}, scoring uses binary presence even when
{cmd:countmode} is specified.  Use {cmd:hierarchy()} when the score should respect
superior/inferior condition pairs.

{phang}
{opt hierarchy(string)} applies condition supersession rules after patient-level
aggregation and before scoring.  Rules are written as
{cmd:superior > inferior} and separated by {cmd:\}.  Example:
{cmd:hierarchy(dm_comp > dm_uncomp \ metastatic > cancer)}.
This option requires {cmd:collapse} or {cmd:merge}.

{pmore}
If {cmd:generate()} is used, hierarchy rules may be written with bare condition
names or with their generated names.  Bare names are resolved against the
defined condition list before the generate-prefix fallback is applied.

{phang}
{opt unmatched(name)} creates a row-level 0/1 flag equal to 1 when an observation
matched no condition.  Rows excluded by {cmd:if}, {cmd:in}, or missing
{cmd:id()} under {cmd:collapse}/{cmd:merge} are assigned 0, not missing — the
flag is strict 0/1 over all rows.  It is not retained after {cmd:collapse}, but
it is retained in row-level or {cmd:merge} output.

{phang}
{opt matched_code(name)} creates a row-level {cmd:str244} variable containing the
first code value that survived inclusion and exclusion checks for any condition.
It is empty when nothing matched.  Like {cmd:unmatched()}, it is not retained
after {cmd:collapse}.

{phang}
{opt graph} draws a horizontal bar chart of condition prevalence.

{phang}
{opt export(filename)} writes the summary table to {cmd:.csv} or {cmd:.xlsx}.
Exported columns are {cmd:condition}, {cmd:matches}, {cmd:prevalence},
{cmd:ci_low}, {cmd:ci_high}, {cmd:pattern}, and {cmd:exclusion}.  When both
{cmd:cooccurrence} and {cmd:export(.xlsx)} are used, the workbook receives a
second sheet named {cmd:cooccurrence} with a {cmd:condition} column and one
column per condition containing the pairwise count.

{phang}
{opt format(%fmt)} controls the displayed and exported format of prevalence and
confidence-interval columns.  The default prevalence format is {cmd:%9.1f}.

{dlgtab:Matching behavior and naming}

{phang}
{opt mode(string)} chooses the matching engine.  {cmd:regex} is the default and
anchors each pattern at the start of the code.  {cmd:prefix} compares simple
pipe-separated prefixes and is usually faster on large datasets.

{phang}
{opt level(#)} truncates each prefix token to {it:#} characters before scanning.
It is meaningful only in {cmd:mode(prefix)} and must be between 1 and 10.

{phang}
{opt nocase} uppercases both patterns and code values internally so matching is
case-insensitive.

{phang}
{opt nodots} strips periods from each code value during matching.  The original
data are unchanged.

{phang}
{opt tostring} converts numeric variables in {varlist} to string before scanning.
This is helpful when code variables were imported as numeric rather than text.

{phang}
{opt countmode} stores integer counts rather than 0/1 indicators.  At the row
level, each count is the number of code slots in {varlist} that matched the
condition.  Under {cmd:collapse} or {cmd:merge}, patient-level counts are sums
across qualifying rows.  Prevalence is still based on the proportion of
observations or patients with a count greater than zero.

{phang}
{opt generate(prefix)} prefixes all created variable names, including date-summary
variables and the score variable.  This is useful when diagnosis, procedure, and
medication scans should coexist in the same dataset.

{phang}
{opt replace} allows overwriting existing output variables and existing frames
named in {cmd:frame()}, but scan variables named in {varlist} are never valid
output targets.

{phang}
{opt noisily} prints progress notes during execution, including per-condition
match totals and hierarchy notes.


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
{cmd:in}, missing-date filtering, and window restrictions.  After
{cmd:collapse}/{cmd:merge}, {cmd:r(N)} instead reports the number of unique
patient IDs represented in the final summary.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Pattern choice.}  Use {cmd:regex} when you need character classes,
alternation, or more complicated anchored expressions.  Use {cmd:prefix} when the
rule is a simple startswith comparison and performance matters.

{pstd}
{bf:Reusable workflows.}  Many projects start with
{helpb codescan_describe}, then write a first pass with {cmd:define()}, and
finally freeze those rules with {cmd:save()} for future runs through
{cmd:codefile()}.

{pstd}
{bf:Codefiles for teams.}  A codefile is usually the most transparent way to
review and reuse definitions.  Keep one row per condition, put the main
inclusion rule in {cmd:pattern}, put exception rules in {cmd:exclusion}, and
use {cmd:label} for clinical or project-facing wording.  When a custom score is
needed, add a numeric {cmd:weight} column and call {cmd:score(custom)}.

{pstd}
{bf:Scores and hierarchy.}  Charlson and Elixhauser scoring are most defensible
after aggregation to the patient level.  In practice that means using either
{cmd:collapse} or {cmd:merge}, plus {cmd:hierarchy()} where severe conditions
should supersede milder variants.

{pstd}
{bf:countmode and countrows.}  Without {cmd:countmode}, {cmd:_nrows} counts the
number of rows with at least one qualifying match.  With {cmd:countmode},
{cmd:_nrows} sums the per-row match counts (total code-slot hits across all rows
for that patient).

{pstd}
{bf:Frames and restore behavior.}  If you need a non-destructive workflow,
{cmd:preserve} keeps the active dataset untouched and {cmd:frame()} gives you a
named copy of the finished result dataset.  That is the recommended pattern when
you want both the original encounter-level data and a patient-level summary in
the same session.

{pstd}
{bf:Performance.}  {cmd:codescan} uses a Mata scanning engine.  The payoff is most
visible when scanning many variables, when using {cmd:detail}, or when repeatedly
applying the same rule set to large administrative datasets.


{marker examples}{...}
{title:Examples}

{pstd}
The following setup block creates a small toy dataset that is copy-paste
runnable after {cmd:net install}.  Rerun it before any example that changes
the data in memory.  The dataset represents five encounters for three patients,
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
The simplest use case.  Scan {cmd:dx1} and {cmd:dx2} for two conditions.  Each
row gets a 0/1 variable for each condition.  The console output shows
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
before {cmd:index_dt} (inclusive).  {cmd:alldates} creates {cmd:_first},
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
rather than regex expressions.  Pipe-separated tokens are alternative
prefixes:

{phang2}{cmd:. codescan proc1, define(mammo "XF001|XF002" | colectomy "JFB|JFH") mode(prefix)}{p_end}

{pstd}
{bf:Example 4: Exclusion patterns}

{pstd}
Use {cmd:~} to exclude specific codes that would otherwise be caught by the
inclusion pattern.  Here {cmd:dm2} matches all {cmd:E11*} codes except
{cmd:E116} (unspecified hypoglycaemia):

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" ~ "E116" | htn "I1[0-35]")}{p_end}

{pstd}
{bf:Example 5: Save an inline rule set, then reuse it as a codefile}

{pstd}
During development, iterate with {cmd:define()}.  Once the rules look right,
freeze them to a CSV with {cmd:save()}, then switch future runs to
{cmd:codefile()}.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") save(dm_rules.csv)}{p_end}
{phang2}{cmd:. codescan dx1 dx2, codefile(dm_rules.csv)}{p_end}

{pstd}
{bf:Example 6: Charlson scoring with the bundled codefile}

{pstd}
{cmd:codescan} ships two bundled CSV files that can be used directly by basename.
{cmd:hierarchy()} zeroes out the less-severe condition when both members of a
pair are present.

{phang2}{cmd:. codescan dx1 dx2, codefile(charlson_icd10_example.csv) id(pid) collapse ///}{p_end}
{phang2}{cmd:    score(charlson) hierarchy(dm_comp > dm_uncomp \ liver_severe > liver_mild \ metastatic > cancer)}{p_end}

{pstd}
After this command, each patient has a {cmd:_score} variable containing the
weighted Charlson comorbidity index.

{pstd}
{bf:Example 7: Multi-window sensitivity analysis}

{pstd}
Supply several lookback values to compare how prevalence changes across
windows.  {cmd:r(sensitivity)} returns a matrix of prevalences by condition and
window.

{phang2}{cmd:. codescan dx1 dx2, id(pid) date(visit_dt) refdate(index_dt) ///}{p_end}
{phang2}{cmd:    define(dm2 "E11" | htn "I1[0-35]") ///}{p_end}
{phang2}{cmd:    lookback(90 365) inclusive collapse}{p_end}

{pstd}
{bf:Example 8: Non-destructive workflow with frames}

{pstd}
{cmd:frame()} stores the collapsed result in a named frame, leaving the
original data untouched.  This is the recommended pattern when you need both
the encounter-level data and a patient-level summary in the same session.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///}{p_end}
{phang2}{cmd:    frame(results) replace}{p_end}
{phang2}{cmd:. frame results: list}{p_end}

{pstd}
{bf:Example 9: Export a formatted summary and save the final dataset}

{pstd}
{cmd:export()} writes the prevalence table to {cmd:.csv} or {cmd:.xlsx}.
{cmd:saving()} saves the transformed dataset that {cmd:codescan} leaves in
memory after {cmd:collapse} or {cmd:merge}.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) collapse ///}{p_end}
{phang2}{cmd:    export(codescan_results.xlsx) saving(codescan_results.dta, replace) format(%9.2f)}{p_end}

{pstd}
{bf:Example 10: Merge results back to original rows}

{pstd}
{cmd:merge} computes patient-level summaries and joins them back, so every row
for a given patient gets the same values.  This is useful when you need both
the encounter detail and the comorbidity flags in one dataset.

{phang2}{cmd:. codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") id(pid) merge}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:codescan} stores the following in {cmd:r()}:

{synoptset 26 tabbed}{...}
{p2col 5 26 30 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}analyzed observations, or unique {cmd:id()} values after {cmd:collapse}/{cmd:merge}{p_end}
{synopt:{cmd:r(n_conditions)}}number of conditions defined{p_end}
{synopt:{cmd:r(collapsed)}}1 if {cmd:collapse} was used, otherwise 0{p_end}
{synopt:{cmd:r(merged)}}1 if {cmd:merge} was used, otherwise 0{p_end}
{synopt:{cmd:r(mode_count)}}1 if {cmd:countmode} was used, otherwise 0{p_end}
{synopt:{cmd:r(lookback)}}single lookback window when only one value was requested{p_end}
{synopt:{cmd:r(lookforward)}}lookforward window when specified{p_end}
{synopt:{cmd:r(ci_level)}}confidence level used for Wilson intervals{p_end}

{p2col 5 26 30 2: Macros}{p_end}
{synopt:{cmd:r(conditions)}}space-separated condition names in output order{p_end}
{synopt:{cmd:r(newvars)}}variables left in memory on exit; empty after {cmd:preserve}/{cmd:restore}{p_end}
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
{synopt:{cmd:r(score)}}score type when {cmd:score()} was used{p_end}
{synopt:{cmd:r(lookback)}}space-separated lookback values when multiple windows were requested{p_end}

{p2col 5 26 30 2: Matrices}{p_end}
{synopt:{cmd:r(summary)}}count, prevalence, ci_low, ci_high by condition{p_end}
{synopt:{cmd:r(codelist)}}two-column subset of {cmd:r(summary)} with count and prevalence{p_end}
{synopt:{cmd:r(varcounts)}}per-variable contribution counts when {cmd:detail} was used{p_end}
{synopt:{cmd:r(cooccurrence)}}pairwise co-occurrence matrix when {cmd:cooccurrence} was used{p_end}
{synopt:{cmd:r(sensitivity)}}multi-window prevalence matrix when multiple lookbacks were requested{p_end}


{marker references}{...}
{title:References}

{pstd}
Quan H, Sundararajan V, Halfon P, et al. (2005). ICD-9-CM and ICD-10 coding
algorithms for defining comorbidities in administrative data.

{pstd}
Quan H, Li B, Couris CM, et al. (2011). Updated Charlson comorbidity weights for
risk adjustment.

{pstd}
van Walraven C, Austin PC, Jennings A, Quan H, Forster AJ. (2009). A point-system
adaptation of the Elixhauser comorbidity measure for hospital mortality.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}


{title:Also see}

{psee}
Online: {helpb codescan_describe}, {helpb collapse}, {helpb merge}, {helpb tostring}

{hline}

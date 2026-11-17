{smcl}
{* *! dataprobe (version recorded in datamap.sthlp)}{...}
{vieweralsosee "datamap" "help datamap"}{...}
{vieweralsosee "dataqa" "help dataqa"}{...}
{vieweralsosee "datamvp" "help datamvp"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{vieweralsosee "[D] isid" "help isid"}{...}
{vieweralsosee "[D] duplicates" "help duplicates"}{...}
{viewerjumpto "Syntax" "dataprobe##syntax"}{...}
{viewerjumpto "Description" "dataprobe##description"}{...}
{viewerjumpto "Options" "dataprobe##options"}{...}
{viewerjumpto "Gate mode" "dataprobe##gate"}{...}
{viewerjumpto "Snapshot and diff" "dataprobe##snapdiff"}{...}
{viewerjumpto "Keyset preflight" "dataprobe##keyset"}{...}
{viewerjumpto "Invariants, bands, and review items" "dataprobe##kinds"}{...}
{viewerjumpto "Idiom map" "dataprobe##idioms"}{...}
{viewerjumpto "Masking" "dataprobe##masking"}{...}
{viewerjumpto "Examples" "dataprobe##examples"}{...}
{viewerjumpto "Stored results" "dataprobe##results"}{...}
{viewerjumpto "References" "dataprobe##references"}{...}
{viewerjumpto "Author" "dataprobe##author"}{...}

{title:Title}

{phang}
{bf:dataprobe} {hline 2} Console QC profiling and expectation gates for a dataset


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:dataprobe}
[{varlist}]
[{cmd:if}]
[{cmd:in}]
[{cmd:,}
{it:options}]

{p 8 17 2}
{cmd:dataprobe}{cmd:,} {opt minver:sion(#)}

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input}
{synopt:{opt sing:le(filename)}}profile a saved {opt .dta}; preserve memory{p_end}
{synopt:{opt conf:ig(filename)}}load key-value defaults{p_end}
{synopt:{opt name(string)}}dataset name in the verdict and ledger{p_end}

{syntab:Classification}
{synopt:{opt maxc:at(#)}}categorical cutoff; default {bf:25}{p_end}
{synopt:{opt exc:lude(varlist)}}skip these variables entirely{p_end}
{synopt:{opt cont:inuous(varlist)}}force continuous classification{p_end}
{synopt:{opt cat:egorical(varlist)}}force categorical classification{p_end}
{synopt:{opt date(varlist)}}force date classification{p_end}
{synopt:{opt id(keyspec)}}identifier keys; {cmd:\}-separate several{p_end}

{syntab:Detail}
{synopt:{opt d:etail}}add continuous percentiles{p_end}
{synopt:{opt maxf:req(#)}}levels shown per variable; default {bf:20}{p_end}
{synopt:{opt topv:alues(spec)}}level counts, rare levels pooled{p_end}
{synopt:{opt rare(#)}}flag levels with count below {it:#}{p_end}
{synopt:{opt min:cell(#)}}suppress tabulated cells below {it:#}{p_end}
{synopt:{opt mask:rare}}mask counts below the threshold{p_end}
{synopt:{opt out:liers(#)}}flag values beyond {it:#} IQRs{p_end}

{syntab:Missingness}
{synopt:{opt nomiss:ing}}suppress the missingness summary block{p_end}
{synopt:{opt patterns}}add the {help datamvp} pattern table{p_end}
{synopt:{opt byfreq}}frequency tables within each {opt by()} group{p_end}

{syntab:Invariant gates {it:(any gate option turns on gate mode)}}
{synopt:{opt gates:only}}run validation gates only{p_end}
{synopt:{opt expectn(numlist)}}require exact {cmd:_N} or a range{p_end}
{synopt:{opt isid(keyspec)}}assert unique by a key; {cmd:\}-separate keys{p_end}
{synopt:{opt nodups}}assert no duplicated rows{p_end}
{synopt:{opt req:uire(varlist)}}assert these variables exist{p_end}
{synopt:{opt notmiss:ing(varlist)}}require complete values{p_end}
{synopt:{opt inrange(spec)}}require ranges; {cmd:\}-separate{p_end}
{synopt:{opt all:owed(spec)}}restrict to allowed values{p_end}
{synopt:{opt for:bid(spec)}}reject forbidden values{p_end}
{synopt:{opt regex(spec)}}require strings to match regexes{p_end}
{synopt:{opt notv:alues(spec)}}reject sentinel or disallowed values{p_end}
{synopt:{opt rule(spec)}}require labelled row-level rules to hold{p_end}
{synopt:{opt byrule(spec)}}row-level rules under {cmd:by} semantics{p_end}
{synopt:{opt stat(spec)}}require a statistic inside a band{p_end}
{synopt:{opt bin:ary(varlist)}}require 0/1 flags with both levels{p_end}
{synopt:{opt events(spec)}}require events at every covariate level{p_end}
{synopt:{opt intervals(spec)}}check interval-file structure{p_end}
{synopt:{opt keyset(spec)}}require the keys of a saved dataset{p_end}
{synopt:{opt recon:cile(spec)}}check rows, ids, totals against a file{p_end}
{synopt:{opt constant(spec)}}require time-fixed values within a key{p_end}
{synopt:{opt sets(spec)}}check matched-set structure{p_end}
{synopt:{opt small:cells(spec)}}small-cell gate on a table or microdata{p_end}

{syntab:Sanity bands}
{synopt:{opt bands(gates)}}declare the call's sanity bands{p_end}
{synopt:{opt bandwarn}}report failing bands as warnings{p_end}
{synopt:{opt coverage(spec)}}check delivered-file date coverage{p_end}

{syntab:Review items {it:(print, never halt)}}
{synopt:{opt review(spec)}}count rows where a condition holds{p_end}
{synopt:{opt heaping(spec)}}placeholder-date heaping{p_end}
{synopt:{opt groupstat(spec)}}a statistic by group, and pooled{p_end}
{synopt:{opt complete(spec)}}complete cases over a varlist{p_end}
{synopt:{opt jumps(spec)}}jumps between repeated measures{p_end}

{syntab:Gate control}
{synopt:{opt by(varlist)}}evaluate gates/missingness within groups{p_end}
{synopt:{opt over(varname)}}single-variable synonym for {opt by()}{p_end}
{synopt:{opt check:s(filename)}}read checks from file{p_end}
{synopt:{opt makes:pec(name[, replace])}}write starter checks: .dta or .do{p_end}
{synopt:{opt comp:are(name)}}compare with a baseline frame or file{p_end}
{synopt:{opt warn}}report every gate failure as a warning{p_end}
{synopt:{opt minver:sion(#)}}require at least this datamap version{p_end}

{syntab:Output}
{synopt:{opt sav:ing(name[, replace])}}save profile to a frame or {opt .dta}{p_end}
{synopt:{opt snap:shot(frame[, replace])}}store the profile in a frame{p_end}
{synopt:{opt diff(name)}}print changes against a baseline{p_end}
{synopt:{opt tol(# [#])}}change thresholds for {opt diff()}{p_end}
{synopt:{opt brief}}one line per variable, flagged first{p_end}
{synopt:{opt safe}}the agent-safe preset{p_end}
{synopt:{opt only:flagged}}show only flagged variables/groups{p_end}
{synopt:{opt show(flagged)}}same as {opt onlyflagged}{p_end}
{synopt:{opt viol:ations(name[, replace])}}save violations to {opt .dta}/frame{p_end}
{synopt:{opt ledger(filename[, run()])}}append every gate result to a ledger{p_end}
{synopt:{opt phase(name)}}phase that tags this call's ledger rows{p_end}
{synopt:{opt soft:collect}}record a failed call and continue{p_end}
{synopt:{opt sig:nature}}record the dataset's {help datasignature}{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:dataprobe} interrogates a dataset in the console and optionally gates on
declared expectations. It is the interactive sibling of {help datamap} (which
{it:documents} a dataset to a Markdown file). The two commands share one
classification engine, so a variable is classified the same way no matter
which command looks at it, and the same {opt saving()} column schema.

{pstd}
With no options, {cmd:dataprobe} auto-classifies every variable and prints a
quick-reference table, a per-class profile (distributions for continuous,
frequency tables for categorical and string, ranges for date), a missingness
summary, and {hline 1} when an identifier-like variable is detected {hline 1} a key-structure
report. No gate runs unless a gate option is given.

{pstd}
With one or more gate options, {cmd:dataprobe} evaluates {it:every} gate, accumulates all
violations, prints them as a single block, and only then exits. On any
violation it exits with return code {bf:9} (Stata's assertion code), so a do-file
stops exactly as a bare {help assert} would. See {help dataprobe##gate:Gate mode}.

{pstd}
Every gate entry, passed or failed, and every review item is one record. The
console verdict, {opt violations()}, the stored results, and the
{opt ledger()} are all read from those records, so they cannot disagree. {help dataqa}
reads the ledger to draft the QA register, assert that every
expected dataset was checked, compare runs, and export a release copy.

{pstd}
The data in memory is always preserved and restored; {cmd:dataprobe} never
modifies the user's data.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{opt sing:le(filename)} profiles a saved {opt .dta} file instead of the data in
memory. The in-memory data is preserved and restored. The {opt .dta}
extension is optional; a {it:filename} that ends in {opt .dta} is read as
given, never as {it:filename}{cmd:.dta}.

{phang}
{opt conf:ig(filename)} reads reusable defaults from a text file containing
{cmd:key = value} or {cmd:key: value} lines. Supported keys include
{cmd:exclude}, {cmd:continuous}, {cmd:categorical}, {cmd:datevars},
{cmd:maxcat}, {cmd:maxfreq}, {cmd:rare}, {cmd:mincell}, {cmd:outliers},
{cmd:maskrare}, {cmd:nomissing}, {cmd:patterns}, {cmd:gatesonly},
{cmd:onlyflagged}, and {cmd:show}. A note names, and the run ignores, a key
that neither {cmd:dataprobe} nor {helpb datamap} reads, a line with no {cmd:=}
or {cmd::}, and a switch key whose value is not {cmd:1}, {cmd:yes}, {cmd:true},
or {cmd:on} or {cmd:0}, {cmd:no}, {cmd:false}, or {cmd:off}; keys that only
{cmd:datamap} reads are ignored without a note. Command-line options override session
defaults set by {help dataqa:dataqa set}, which override config-file defaults.

{phang}
{opt name(string)} names the dataset in the verdict and the ledger. By default
the name is the basename of {cmd:c(filename)}, followed by {bf:(modified)} when
the data changed since they were last saved; data never saved have no name. Use
{opt name()} for a dataset restricted after loading, for example
{cmd:name(repop_intervals, repletion sample)}. The name is used as typed: a
{cmd:$} or backtick in it is never expanded, and braces print literally.

{dlgtab:Classification}

{phang}
{opt maxc:at(#)} sets the cutoff, passed to the classifier, below which a numeric
variable is treated as categorical rather than continuous. The default is 25. It
is also the most levels a covariate in {opt events()} may have.

{phang}
{opt exc:lude(varlist)} skips the named variables entirely. As with {help datamap},
excluded variables are listed by name but their distributions, cardinality, and
value-label coding are never shown. They are never flagged and never appear in
{cmd:r(flagged_vars)}, {cmd:r(missing_vars)}, the MISSINGNESS section, or the
{opt patterns} table; the quick-reference table prints {bf:[excluded]} for
their missing share. A gate on an excluded variable reports its verdict and
counts, never a value of the variable: an {opt inrange()} violation reports the
count only, never the offending minimum and maximum; {opt stat()} and a
{opt groupstat()} cell print {bf:[excluded]} ({bf:[excl.]} in a multi-statistic
table); {opt coverage()} prints
{bf:[excluded]} for the first and last dates and counts the empty years
without naming them; and an {opt events()} covariate's level is named by its
rank, {cmd:rep78 = [excluded] level 3}. A {opt by()} variable still labels its
groups by value.

{phang}
{opt cont:inuous(varlist)}, {opt cat:egorical(varlist)}, and {opt date(varlist)} force the named
variables into the given group, overriding auto-classification.

{phang}
{opt id(keyspec)} declares the identifier key(s) for the uniqueness
report. {cmd:\}-separate several keys ({cmd:id(lopnr \ tx_id)}); a key may be composite
({cmd:id(lopnr visitdt)}). When omitted, the report defaults to the classifier's
inferred identifier-like names.

{dlgtab:Detail}

{phang}
{opt d:etail} adds the full percentile set (1, 5, 10, 90, 95, 99) to the
quartiles already shown for continuous variables.

{phang}
{opt maxf:req(#)} caps the number of categorical or string levels listed; the
default is 20.

{phang}
{opt topv:alues(spec)} lists the most frequent levels of a variable and never prints
the value of a rare one, in place of {cmd:tabulate} or {cmd:levelsof} on a text or code
variable whose log may be shared. Each {cmd:\}-separated entry is {varlist} [{cmd:,} {opt mincell(#)}
{opt max(#)} {opt id(varname)}], one block per variable under the heading {bf:TOP VALUES}. A
level is a distinct value, and a missing value ({cmd:.}, {cmd:.a}, a blank string) is a
level too, so the levels add up to the rows of the call's {cmd:if}/{cmd:in} sample. Levels
are listed most frequent first, ties in value order, with their rows and
percentage and, with {opt id()}, their distinct values of {it:varname} ({bf:ids}; a missing id
counts as one value). A level is listed when it has at least {it:m} rows (and, with
{opt id()}, at least {it:m} ids) and is among the first {opt max(#)} levels; {opt max()} defaults to
{opt maxfreq()}. {it:m} is the entry's {opt mincell(#)}, otherwise the call's masking threshold
({opt mincell()} or the {cmd:dataqa set} default, then {opt rare()} under {opt maskrare}), otherwise
5; below 2 it is r(198). {opt topvalues()} masks at {it:m} whether or not {opt maskrare} is
given. Under {opt maskrare}, and so under {opt safe} and {cmd:dataqa set agent}, the call's
masking threshold is a floor: an entry's {opt mincell()} below it is raised to it,
with a note such as {bf:note: safe raises topvalues() mincell(2) to 5}
({bf:maskrare raises} ... without {opt safe}), so an entry never lists a level the call's
mask withholds. Without {opt maskrare} the entry's {opt mincell()} is used as given.

{pmore}
Every other level is pooled in one line, {bf:[}{it:k} {bf:levels suppressed]}, with the
pooled rows (and ids); the value of a pooled level is never printed, and the
levels past {opt max()} are pooled with the rare ones. The pool follows the rule of
the {opt maskrare} frequency tables: a pool holding a level below {it:m} needs two levels
and {it:m} rows, else the smallest listed level joins it. With {opt id()} the smallest
listed level also joins while the pool has 1 to {it:m}-1 ids. When every level is
pooled and the pool is still 1 to {it:m}-1 rows or ids, its counts and the total
are withheld together ({bf:[suppressed]}), since the total minus the listed counts
would give them back. {it:k} prints only when the pool has at least 2{it:k} rows and
more than {it:k} ids: every pooled level holds a row or more, so fewer than 2{it:k} rows
in {it:k} levels would say that some pooled level is a single row. The number of
levels prints only when {it:k} prints or nothing is pooled. The total ids print
only when the total minus each listed level's ids, and minus the pool's, is 0
or at least {it:m}, as persons can hold several levels and ids need not add
up. These pooling rules for the remainder are datamap's own: Hundepool et
al. (2026, sec. 4.3.3 and 5.3) recommend grouping rare categories as table
redesign, and the pooled line is a cell that must itself pass the threshold
(sec. 4.2.1).

{pmore}
With no {it:varlist} the call profiles nothing else, as under {opt gatesonly}, so the
view never comes with an unmasked profile of every variable; give a {it:varlist}
for the profile as well. Declared gates run as usual; {opt topvalues()} itself
records no gate and writes no ledger row, and it ignores {opt by()}. The values of a
variable in {opt exclude()} (under {opt safe}, the likely identifiers) are not listed
(r(198)), and under {opt safe} neither are those of a date-formatted variable or of
text holding a digit. A numeric level prints in its display format with its
value label, a blank string as {bf:(blank)}, and quotes, braces, dollar signs,
backticks and control characters print as the literal characters ({cmd:\n},
{cmd:\t}). {cmd:r(topvalues)} holds what was printed.

{phang}
{opt rare(#)} flags categorical levels whose count falls below {it:#}.

{phang}
{opt min:cell(#)} suppresses tabulated frequency cells with a count below
{it:#} and sets the masking threshold for {opt maskrare}.

{phang}
{opt mask:rare} masks small counts everywhere the command prints one. The
threshold {it:m} is {opt mincell(#)} when specified; otherwise {opt rare(#)}; otherwise
5. See {help dataprobe##masking:Masking}. An explicit
{cmd:nomaskrare} overrides a session default {opt maskrare} and prints a note
saying so.

{phang}
{opt safe} is the agent-safe preset: {opt maskrare} with {opt mincell(5)} (a
larger {opt mincell()} wins); the likely identifiers (variables whose names
match the pattern {cmd:datamap} uses for {cmd:r(suggested_exclude)}) are
excluded as {opt exclude()} excludes them; no date is printed (a date's p1
and p99 print as {bf:[withheld]}, its span still prints); and no levels are
listed for text with more than {opt maxcat()} distinct values, for text
holding a digit, or for a date-formatted variable. {opt saving()} writes the
same masks ({bf:.s}). {opt makespec()}, {cmd:nomaskrare}, and a {opt by()} or
{opt over()} variable that is an identifier, a date, or text holding a digit
are refused. {cmd:dataqa set agent} turns {opt safe} on for the session. {opt safe}
covers printed output and written files only: {cmd:r()}, a
{opt snapshot()} frame, and differencing across outputs are not masked (a
{cmd:dataprobe} and a {cmd:datamap} output can each be safe and together give
back a rare count). In {opt stat()} and {opt groupstat()} the mean or a
percentile (the median included) of a date-formatted variable prints as
{bf:[withheld]}. The
identifier rule reads names, so an identifier under another name (such as
{it:pnr}) is not excluded, and digit-free text (names) with {it:m} or more rows
per value is still listed; integer dates such as 20200115 with no date format
are not recognized as dates.

{phang}
{opt brief} prints one line per variable in place of the profile sections: name,
class, type, missing share, distinct values, and flag, flagged
variables first; a categorical variable adds its five most frequent levels
(a level held by one row, or by fewer than the mask, is not listed); text
whose values are all distinct reads {bf:all distinct, maxlen} {it:#}. The
stored results are those of the full profile. {opt brief} cannot be combined
with {opt gatesonly}, {opt patterns}, or {opt byfreq}, and {opt brief} with
{opt topvalues()} and no {it:varlist} is r(198).

{phang}
{opt out:liers(#)} flags continuous values lying more than {it:#} interquartile
ranges beyond the first or third quartile. The default of 0 disables the check.

{dlgtab:Missingness}

{phang}
{opt nomiss:ing} suppresses the missingness summary block.

{phang}
{opt patterns} adds the missing-value pattern table from {help datamvp}. Under
{opt maskrare} the table is masked as well: {cmd:dataprobe} passes
{opt maskrare} and {opt mincell()} to {cmd:datamvp}, which pools patterns
below the threshold.

{dlgtab:Invariant gates}

{phang}
{opt gates:only} suppresses the descriptive profile and runs only the
requested gates and review items. Without {opt compare()}, {opt saving()}, or
{opt makespec()}, {cmd:dataprobe} then skips classification and the profile
entirely and keeps only the columns the gates name, so a gate call on a wide
file costs about what the gates themselves cost. The profile stored results
({cmd:r(n_continuous)}, {cmd:r(singlelevel_vars)}, {cmd:r(complete_cases)}, and
the rest of that family) are not set in that case, and
{cmd:r(group_missing_vars)} and {cmd:r(n_group_missing_vars)} are not set under
any {opt gatesonly}.

{phang}
{opt expectn(numlist)} asserts the number of observations. One number is an
exact expectation ({cmd:expectn(282252)}); two numbers are an inclusive range
({cmd:expectn(1000 1200)}). Each {cmd:expectn} row of {opt checks()} adds an
entry beside {opt expectn()}; it never replaces it.

{phang}
{opt isid(keyspec)} asserts that the dataset is unique by the named key. A
row with a missing key value counts as a duplicate. {cmd:\}-separate several
keys, each checked on its own ({cmd:isid(lopnr \ tx_id)}); each {cmd:isid} row
of {opt checks()} adds a key beside {opt isid()}.

{phang}
{opt nodups} asserts that no fully duplicated rows exist. With a
{it:varlist}, rows are compared on the {it:varlist} together with the
variables named in other options (such as {opt id()}, {opt inrange()}, or
{opt exclude()}), not on every variable in the data: {cmd:dataprobe x, nodups}
fails when two rows share {cmd:x} even if another variable tells them apart. Omit
the {it:varlist} to compare every variable.

{phang}
{opt req:uire(varlist)} asserts that the named variables exist in the dataset. When
{opt require()} reports a variable missing, the entries of
{opt isid()}, {opt notmissing()}, {opt binary()}, {opt inrange()},
{opt allowed()}, {opt forbid()}, {opt notvalues()}, and {opt regex()} that
name it are not run, a note says so
({cmd:note: gates on} {it:vars} {cmd:not run (require() reports the variable missing)}),
and {opt require()} fails (exit 9). A variable that is missing and not in
{opt require()} stops the call with its own error (r(111)).

{phang}
{opt notmiss:ing(varlist)} asserts that the named variables have no missing
values.

{phang}
{opt inrange(spec)} asserts that variables fall within declared ranges. Each
{cmd:\}-separated entry is {it:var} [{it:var ...}] {it:lo hi}: every token but the last two is a
variable, so one bound pair can cover several variables, as in
{cmd:inrange(dob entry exit td(01jan1900) td(31dec2025) \ age 18 110)}. Bounds may
be numbers, date literals such as {cmd:td(01jan2010)}, or date strings such as
{cmd:01jan2010} or {cmd:2010-01-01}, read in the variable's own date unit; for a date
variable a date string is never evaluated as arithmetic, and a bound naming a
variable is an error. A bound written {cmd:.} is
open: {cmd:inrange(exit_date . td(31dec2025))} has no lower bound. Missing values
are never outside a range. Bounds are compared at full double precision, so a
{opt makespec()} spec passes {opt checks()} on the data it was written from. A failing
entry with both bounds also prints how many of the rows outside lie below {it:lo}
and how many above {it:hi}, as in {cmd:13 obs outside [15, 30] (8 below, 5 above)}, so
one entry replaces two half-open {opt rule()} gates. Each side is masked as the
count is; beside a masked or withheld count a side prints only {cmd:0} or {cmd:<}{it:m}, and
when one side is masked the other is withheld, since the count minus the shown
side would give it back. {cmd:r(inrange_n_below)} and {cmd:r(inrange_n_above)} hold the
sides summed over every entry and {opt by()} group.

{phang}
{opt all:owed(spec)} asserts that variables contain only declared values. The
specification is {cmd:\}-separated entries of the form
{it:var values}: {cmd:allowed(sex 0 1 \ arm "usual" "active")}. Typing the
option removes the quotes around a value, so a level that contains a space
({cmd:"usual care"}) is read as separate levels; list such a level in a
{opt checks()} file, where it is read as written.

{phang}
{opt for:bid(spec)} asserts that variables do not contain declared forbidden
values. Missing values are not checked by {opt allowed()}, {opt forbid()}, or
{opt notvalues()}, except that an explicit missing code in {opt forbid()} or
{opt notvalues()}, such as {cmd:notvalues(consent .a)}, matches that code.

{phang}
{opt regex(spec)} asserts that string variables match regular expressions. Each
{cmd:\}-separated entry is {it:var pattern}. A pattern cannot contain a backslash,
because {cmd:\} separates entries: write {cmd:[.]} for a literal period rather than {cmd:\.}, as
in {cmd:regex(x ^-?[0-9][.][0-9]+$)}. A numeric variable is matched on its value as
text: an integer in full ({cmd:1234567890}, not {cmd:1.23e+09}), other values in {cmd:%16.0g}
({cmd:%9.0g} for a float).

{phang}
{opt notv:alues(spec)} asserts that variables do not contain sentinel or
placeholder values such as {cmd:-9}, {cmd:999}, or {cmd:"UNKNOWN"}.

{phang}
{opt rule(spec)} asserts row-level rules. Each {cmd:\}-separated entry is
{it:label}{cmd::} {it:expression}, for example
{cmd:rule("timeline": dob < dx_date & dx_date <= entry \ "entry_exit": entry < exit)}. A
rule holds for a row where the expression is true under Stata's {cmd:if} semantics,
so add {cmd:!missing()} terms where missing values matter. Rules are evaluated once,
on the {cmd:if}/{cmd:in} subset, in the data's current sort order and before {cmd:dataprobe}
sorts anything, so subscripted expressions such as
{cmd:id != id[_n-1] | start >= stop[_n-1]} see the rows as arranged; sort the data
first, or use {opt intervals()}, which sorts its own copy. An expression cannot
contain a backslash. An expression that cannot be evaluated is an error, not a
violation. When an expression uses a subscript, {cmd:_n} or {cmd:_N} and the data had no
sort order at entry ({cmd:: sortedby} was empty), or were sorted by none of the
variables it subscripts, {cmd:dataprobe} prints a note naming the rule and pointing
to {opt byrule()}; the note never changes a verdict. {opt review()} gets the same note. As
in {opt byrule()}, the expression reaches Stata exactly as written: a {cmd:$} or backtick
inside it, such as {cmd:s != "a$b"} given through a compound-quoted local, is never
expanded. A {opt rule()} or {opt review()} label cannot hold {cmd:$} (r(198)).

{phang}
{opt byrule(spec)} asserts row-level rules under Stata's own
{cmd:by} {it:byvars} {cmd:(}{it:sortvars}{cmd:):} semantics, so {cmd:_n}, {cmd:_N},
and {cmd:x[_n}{it:+-k}{cmd:]} refer to positions within a group. Each
{cmd:\}-separated entry is {it:byspec}{cmd::} {it:label}{cmd::} {it:expression},
where {it:byspec} is {it:byvars} {cmd:(}{it:sortvars}{cmd:)}, {it:byvars} alone,
or {cmd:(}{it:sortvars}{cmd:)} alone, for no groups, exactly as in
{help bysort}. Examples: {cmd:byrule(id (dose_date): "seq": dose_num == _n)},
{cmd:byrule(id (dose_date): "last": _n == _N | next_dose == dose_date[_n+1])}, and
{cmd:byrule((step): "monotone": _n == 1 | value >= value[_n-1])}. The rows are
sorted with {cmd:sort} {it:byvars sortvars}{cmd:, stable} on {cmd:dataprobe}'s own
copy, so the data and their order are unchanged after the call, and rows tied on
({it:byvars sortvars}) keep the data's order; when the expression uses {cmd:_n},
{cmd:_N} or a subscript and the ties exist, a note names the rule (without a
count). With no {it:sortvars} the order within a group is the data's own. The
rule runs on the {cmd:if}/{cmd:in} subset, so {cmd:_n} counts in-scope rows
within the group. A missing {it:byvars} value forms its own group. A rule holds
where the expression is true; one that cannot be evaluated is an error. A
{opt byrule()} entry is an invariant, counted as {cmd:byrule} among the gate
families, written to {opt ledger()}, {opt violations()}, and {opt checks()} (a
{cmd:byrule} row takes the label in {cmd:var}, the by spec in {cmd:values}, and the
expression in {cmd:pattern}), masked under {opt maskrare}, and tallied by
{opt by()} groups exactly as {opt rule()} is. {opt makespec()} does not write
{opt rule()} or {opt byrule()} rows. The expression reaches Stata exactly as
written: a {cmd:$} or backtick inside it, such as {cmd:s != "a$b"} given through
a compound-quoted local, is never expanded. The {it:byspec} and the label cannot
hold {cmd:$} (r(198)).

{pmore}
{bf:Group aggregates.} The expression may state a rule per group with {cmd:total(}{it:exp}{cmd:)},
the sum of {it:exp} over the group's rows; {cmd:mean(}{it:exp}{cmd:)}; {cmd:gmin(}{it:exp}{cmd:)} and
{cmd:gmax(}{it:exp}{cmd:)}, its smallest and largest value; {cmd:spread(}{it:exp}{cmd:)}, {cmd:gmax()} minus
{cmd:gmin()}; and {cmd:count(}{it:exp}{cmd:)}, the number of the group's rows where {it:exp} is nonmissing
({cmd:count(1)} is the group's size). Each is taken over the in-scope rows of the
{it:byvars} group (all the rows without {it:byvars}) and holds the same value on every
row of the group: {cmd:byrule(id: "wsum": abs(total(w) - 1) <= 1e-6)} asserts that
the weights of each {cmd:id} sum to one, and {cmd:byrule(id: "flat": spread(height) <= 2)}
that each person's heights lie within 2 units. They mix with row terms,
{cmd:byrule(id (t): "first": _n > 1 | t == gmin(t))}. {cmd:min()} and {cmd:max()} keep their
meaning as Stata's row functions, and none of the six names is a Stata
function, so no expression that ran before reads differently. {it:exp} follows the
missing-value rule of a {opt stat()} expression: a row where a variable it names is
missing is left out of the aggregate, and {cmd:missing()}, missing literals, {cmd:_n}, {cmd:_N},
subscripts, and an aggregate inside another are errors (r(198)). A group with
no nonmissing value of {it:exp} has no {cmd:total()}, {cmd:mean()}, {cmd:gmin()}, {cmd:gmax()}, or {cmd:spread()}
(not 0), and fails the rule whatever the comparison, since a missing value
would satisfy {cmd:total(w) > 0.5}; {cmd:count()} is 0 for it. {p_end}

{pmore}
{bf:Precision.} An aggregate is computed in double precision from the stored
values, and {cmd:==} compares exactly. Float weights that sum to one on paper rarely
sum to exactly 1 (ten float weights of 0.1 total 1.0000000149), so
{cmd:total(w) == 1} fails for them; state the tolerance,
{cmd:abs(total(w) - 1) <= 1e-6}. Storing a weight as a float changes it by at most
6e-8 of its value, so the total of float weights whose exact values sum to one
is within 6e-8 of 1 however many there are, and 1e-6 leaves room to
spare; weights held as doubles meet 1e-12. {p_end}

{pmore}
A rule with an aggregate is reported by its failing groups, not rows: a group
fails when the rule is false on any of its in-scope rows, and the message reads
{cmd:byrule(wsum): 3 groups fail abs(total(w) - 1) <= 1e-6}. As for every
{opt byrule()} rule, the aggregates are computed once over the call's
{cmd:if}/{cmd:in} rows; with {opt by()}, each {opt by()} group counts the failing
groups that have rows in it. The count is
masked under {opt maskrare} as a row count is ({bf:<}{it:m} for 1 to
{it:m}-1 groups, {bf:all but <}{it:m} when the groups that pass number 1 to
{it:m}-1), the ledger's {cmd:observed_num} holds it, and a group is never
named by its values. {opt violations()} holds one row for the failed rule, as for
every gate: no data rows and no group.

{phang}
{opt stat(spec)} asserts that a statistic falls within a declared inclusive
band. Each {cmd:\}-separated entry is {it:statistic var lo hi} [{cmd:if} {it:exp}] or {cmd:ratio}
{it:num den lo hi} [{cmd:if} {it:exp}]. The statistics are {cmd:mean}, {cmd:sd}, {cmd:median}, and the
percentiles {help summarize:summarize, detail} reports, {cmd:p1} {cmd:p5} {cmd:p10} {cmd:p25} {cmd:p50} {cmd:p75}
{cmd:p90} {cmd:p95} {cmd:p99} (no other percentile, such as {cmd:p2} or {cmd:p37}, is accepted); {cmd:sum}; {cmd:n}, the
nonmissing count; {cmd:distinct}, the number of distinct nonmissing values; {cmd:pmiss},
the share missing over all rows in scope; {cmd:ess}, the Kish effective sample size
(sum w)^2/sum(w^2) of a weight variable (Kish 1965), whose weights must be
nonnegative (a negative weight in scope is r(459)); and {cmd:ratio}, sum {it:num} / sum
{it:den} over rows where both are nonmissing. The optional {cmd:if} {it:exp} restricts that
entry only and combines with the call's own
{cmd:if}: {cmd:stat(sum _d 412 412 \ ratio ev py 0.018 0.025 if at_risk)}. Commas are read
as spaces in the band, before the {cmd:if}, so a band stored as {it:lo, hi} can be
reused. A statistic with no value in scope (a mean of no observations, {cmd:pmiss}
of no rows) is a violation; {cmd:sum}, {cmd:n}, and {cmd:distinct} of no rows are 0. An upper
bound written {cmd:.} is open, for a date as for any other variable; a lower bound
of {cmd:.} is an error (r(198)). A percentile of a float variable is compared with
the bounds at float precision, but a mean, sd, or sum is compared exactly, in
double precision: a float variable holding 0.2 in every row has mean
0.20000000298 and fails {cmd:stat(mean x 0 0.2)}. Set such a band a little wider
than float resolution, as in {cmd:stat(mean x 0 0.2000001)}. Band bounds are
compared at full double precision. Without the mask, a failing mean or
percentile of a date variable whose date does not show it exactly (a fraction
of a day, milliseconds under a {cmd:%tc} format that shows seconds) prints its value
at full precision with the date beside it, {cmd:874.5125 (24may1962)} ({cmd:%21.0g} for a
{cmd:%tc} value), since the date alone can read as the bound it failed; under
{opt maskrare} it prints at month precision. A failing {opt inrange()} on a date prints
its minimum and maximum the same way.

{pmore}
Where {opt stat()} expects a variable ({it:var}, or {it:num} and {it:den} of {cmd:ratio}), a
parenthesised expression may stand instead: {cmd:stat(mean (dx == 1) 0.10 0.30)}
asserts that the share of rows with {cmd:dx} equal to 1 lies in [0.10, 0.30], and
{cmd:stat(sum (age >= 18 & sex == "F") 100 . \ ratio (los * w) w 2 9)} uses one in a
count and a ratio. A variable slot that begins with {cmd:(} is an expression and
runs to its matching {cmd:)} (a parenthesis inside a {cmd:"}{it:...}{cmd:"} string does not count),
so it may hold commas, spaces and {cmd:if}; a variable name never begins with {cmd:(}, so
no existing entry reads differently. The expression is evaluated on the call's
{cmd:if}/{cmd:in} rows into a double variable that exists only inside {cmd:dataprobe}, and the
output, {opt ledger()} label and variable, and {opt violations()} name it by its text,
printed as typed (no macro, quote, or SMCL character in it is interpreted). {p_end}

{pmore}
{bf:Missing values.} Stata evaluates {cmd:(x > 5)} as 1 and {cmd:(x == 1)} as 0 when {cmd:x} is
missing, because a missing value is larger than any number; {opt stat()} does
not. The expression is missing on every row where a variable it names is
missing ({cmd:""} for a string variable), whatever the expression would give, so
{cmd:mean (dx == 1)} is the share among the rows whose {cmd:dx} is known, {cmd:sum (dx == 1)}
counts known ones, {cmd:n} counts the rows whose variables are all known, and {cmd:pmiss}
the share where one is missing. To count missing values as 0 or 1, generate
the variable yourself. Since that rule leaves nothing for them to test, an
expression that uses {cmd:missing()} or {cmd:mi()}, a missing literal ({cmd:.}, {cmd:.a}-{cmd:.z}), {cmd:_n}, {cmd:_N},
or a subscript is an error (r(198)), as is an unclosed {cmd:(}; a string-valued
expression is r(109). Masking, the date display, and the band follow the
statistic as for a variable (a {cmd:mean} of a 0/1 expression is shown only when at
least {it:m} rows hold each value, its counts of ones and zeros); {opt exclude()} of any
variable the expression names withholds the value as for that variable, and
under {opt safe} the mean or a percentile of an expression that names a date
variable is withheld as a date's is. With {opt by()} and {opt maskrare}, a per-group count
of an expression whose rows are exactly a level of a profiled variable (a {cmd:sum}
of a 0/1 expression such as {cmd:(flag == 1)}) or exactly a profiled variable's
missing rows ({cmd:n} and {cmd:pmiss}, as of {cmd:(x + 0)}) is withheld in the same groups as
that variable's own count, so {cmd:stat(sum (flag == 1) ...)} prints what
{cmd:stat(sum flag ...)} prints and neither gives back a masked group by subtraction
from the pooled frequency table.

{phang}
{opt bin:ary(varlist)} asserts that each variable is a 0/1 flag: every
nonmissing value is 0 or 1, and both 0 and 1 occur.

{phang}
{opt events(spec)} asserts that every level of a model covariate carries an
event, the condition whose failure makes a Poisson or Cox fit diverge. Each
{cmd:\}-separated entry is {it:eventvar} [{cmd:if} {it:exp}]{cmd::} {it:varlist}
[{cmd:, min(}{it:#}{cmd:)}]. For each covariate and each of its
nonmissing levels in scope, the sum of {it:eventvar} (a 0/1 indicator or a
count) must be at least {cmd:min()}, which defaults to 1. The entry's
{cmd:if} restricts the event sum only, as in
{cmd:events(ev_pri if at_pri: ms_type edss_cat)}. Missing levels are skipped
because the model drops them; an explicit code such as 99 is a level and is
checked. A covariate with more than {opt maxcat()} levels is an error, so a
continuous variable passed by mistake stops the call. A covariate with no
nonmissing level in scope fails. The message names the
level and its value label: {cmd:events(_d): mstype = 3 (SPMS) has 0 events}.

{phang}
{opt intervals(spec)} checks an interval file. Each {cmd:\}-separated entry is {it:id} [{it:id ...}]
{it:start stop} [{cmd:,} {cmd:contiguous} {cmd:event(}{it:varname}{cmd:)} {cmd:tol(}{it:#}{cmd:)}]. The checks are named
separately: {bf:intervals(missing)} (id, start, and stop nonmissing; such rows are
left out of the other interval checks), {bf:intervals(order)} (start < stop),
{bf:intervals(overlap)} (within id, sorted by start, start >= the latest earlier
stop - tol), {bf:intervals(gap)} (with {cmd:contiguous}, no start after the latest
earlier stop + tol), and {bf:intervals(event_last)} (with {cmd:event()}, the event is
nonzero only on the id's last interval). {cmd:dataprobe} sorts its own copy, so the
user's sort order does not matter. {cmd:tol()} defaults to 0; use it for time scales
in days divided by 30.4375 or 365.25. Omit {cmd:event()} for a recurrent
outcome. {opt intervals()} runs once on the {cmd:if}/{cmd:in} sample, ignoring {opt by()}.

{phang}
{opt keyset(spec)} asserts that the distinct keys in memory match those of a
saved dataset. Each {cmd:\}-separated entry is {it:varlist} {cmd:using}
{it:filename} [{cmd:,} {cmd:equal}|{cmd:subset}|{cmd:superset}]. With
{cmd:subset}, every key in memory exists in the file; with {cmd:superset},
every key in the file exists in memory; {cmd:equal} (the default) requires
both. A {it:filename} that ends in {opt .dta} is read as given, and one without
it as {it:filename} or {it:filename}{cmd:.dta}; a missing file is r(601). Equal
counts with different members, such as one person lost and another
gained after a merge on the wrong key, fail. {opt keyset()} ignores
{opt by()}. Before the verdict, {opt keyset()} prints a preflight report; see
{help dataprobe##keyset:Keyset preflight}.

{pmore}
For a link by key and date, an entry may add {cmd:asof(}{it:mdate udate}{cmd:)} (the latest
file row of the key dated on or before {it:mdate}) or {cmd:window(}{it:mstart mend udate}{cmd:)}
(the file rows of the key dated in [{it:mstart}, {it:mend}], what {helpb joinby} followed by
{cmd:keep if} would leave): {it:mdate}, {it:mstart} and {it:mend} are numeric variables in memory,
{it:udate} a numeric variable in the file. The entry then reports, per row in
memory, how many file rows link (none, one, more), and nothing is joined; see
{help dataprobe##kwindow:Date linkage}. {cmd:maxlag(}{it:#}{cmd:)} (with {cmd:asof()}) counts the rows whose latest file
date is more than {it:#} before {it:mdate}. The diagnostic is a review item unless a
threshold, a share from 0 to 1 of the rows in memory, makes it a
gate: {cmd:maxnone(}{it:#}{cmd:)} (rows with no link), {cmd:maxmulti(}{it:#}{cmd:)} (rows with more than one),
and with {cmd:asof()} {cmd:maxties(}{it:#}{cmd:)} (rows whose latest file date holds more than one
file row, so the as-of pick is arbitrary) and {cmd:maxstale(}{it:#}{cmd:)} (rows older than
{cmd:maxlag()}). With {cmd:asof()} or {cmd:window()} the key-set verdict runs only when {cmd:equal},
{cmd:subset} or {cmd:superset} is
named: {cmd:keyset(id using labs, asof(index labdate) maxlag(365) maxties(0))}.

{phang}
{opt recon:cile(spec)} compares the working sample with a saved checkpoint {cmd:.dta}, so
that rows, persons and totals are conserved across a step without {cmd:count} into a
local or {cmd:collapse} and {cmd:merge}. Each {cmd:\}-separated entry is {it:filename} [{cmd:,} {cmd:n}
{cmd:ids(}{it:varname}{cmd:)} {cmd:sum(}{it:varlist}{cmd:)} {cmd:by(}{it:varlist}{cmd:)}
{cmd:expect(eq}|{cmd:le}|{cmd:ge)} {cmd:tol(}{it:#}{cmd:)}]. {cmd:n} compares the row counts (the default when neither
{cmd:ids()} nor {cmd:sum()} is given), {cmd:ids()} the distinct nonmissing values of an id,
{cmd:sum()} the total of each variable (a missing value adds nothing). {cmd:expect()} is
the relation memory must have to the file: {cmd:eq} (the default), {cmd:le} (memory at
most the file, as after exclusions) or {cmd:ge}. Counts compare exactly; a total
compares within {cmd:tol()} times the file's absolute total (default 1e-9, for the
order of floating-point addition). With {cmd:by()} the same comparison runs in every
group too, a group present on one side only counting zero on the other; the
groups that fail print by their value labels. The file is read with a varlist
(the {cmd:ids()}, {cmd:sum()} and {cmd:by()} variables only; with {cmd:n} alone only its header) into
a temporary frame, from whatever frame is current, and the data in memory are
not changed. A {it:filename} that ends in {opt .dta} is read as given, and one
without it as {it:filename} or {it:filename}{cmd:.dta}. A missing file is r(601), a variable missing from the file
r(111), a {cmd:sum()} variable that is a string in the file r(109), and a {cmd:by()}
variable that is a string on one side only, or a {cmd:strL}, r(106). Each measure is
a gate record, and with {cmd:by()} one more per measure, failed when any group
fails. {opt reconcile()} ignores {opt by()} (the option of {cmd:dataprobe}), runs on the {cmd:if}/{cmd:in}
sample, and under {opt maskrare} masks as described in {help dataprobe##masking:Masking}.

{phang}
{opt constant(spec)} asserts that variables take one value within each key. Each
{cmd:\}-separated entry is {it:keyvars}{cmd::} {it:varlist}
[{cmd:, ignoremissing}]. A missing value next to a nonmissing one within a key
is a second value unless {cmd:ignoremissing} is given. String variables are
allowed. Use it on interval files for sex, birth date, and other baseline
values: {cmd:constant(id: sex dob first_dose)}.

{phang}
{opt sets(spec)} checks a matched cohort. Each entry is {it:set_id exposure}
[{cmd:,} {cmd:k(}{it:#}{cmd:)} {cmd:index(}{it:varname}{cmd:)}]: exposure is 0
or 1 on every row ({bf:sets(values)}), each set has one exposed row
({bf:sets(exposed)}) and {it:k} unexposed rows, or at least one without
{cmd:k()} ({bf:sets(unexposed)}), and with {cmd:index()} one index date per set
({bf:sets(index)}).

{phang}
{opt small:cells(spec)} is a publication gate for a results dataset, one row per
released table cell or row. It audits counts: it reports cells that would
disclose a small count and fails the call, but it never suppresses, rounds, or
changes a table, so a failing table must be fixed (cells suppressed, groups
merged) before release. For the complementary cells that let a withheld cell be
recovered from row and column totals, use the {opt margins} audit below; to
list the frequent levels of a variable without printing its rare values, use
{opt topvalues()}. Each {cmd:\}-separated entry is
{it:countexp} [{it:countexp} ...] [{cmd:if} {it:exp}]. On the rows in scope,
none of the {it:countexp} may lie in 1 to {it:m}-1; the scope is the entry's
{cmd:if} (typically the rows not marked as suppressed) within the call's
{cmd:if}/{cmd:in}, and without an entry {cmd:if} every row is in scope. A
{it:countexp} is a variable or an expression such as {cmd:n1-e1}, the
difference between two released counts. It must not contain spaces; an
expression wrapped in parentheses may, as in {cmd:(n1 - e1)}. Zero passes, a
value of {it:m} or more passes, and a missing value, including an extended
missing such as the {cmd:.p} that tabtools writes, is a suppressed cell and
passes. A negative or non-integer value fails, with the reason named in the
message. An expression that does not evaluate is an error, never a pass. The
entry {cmd:if} follows Stata's {cmd:if} semantics: a missing flag is true, so
{cmd:if !suppressed} leaves a row with a missing {cmd:suppressed} out of scope,
as {cmd:rule("x": ... | suppressed)} does, while {cmd:if suppressed != 1}
keeps it in.

{pmore}
{it:m} is the threshold the call resolves for masking: {opt mincell(#)} when given or set
by {cmd:dataqa set mincell(#)}; under {opt maskrare} otherwise {opt rare(#)}, otherwise 5. With
none of these the gate stops with {cmd:r(198)} and asks for {opt mincell()}, because
{opt mincell()} has no default. A threshold below 2, from {opt mincell()}, {opt rare()} under
{opt maskrare}, or the session default, stops the gate with {cmd:r(198)}: a check on
counts in 1..0 tests nothing. The threshold used is in the gate line and in
the ledger's {cmd:expected} column, {bf:no released count in 1..4 (m=5)}. A small
positive count is a primary suppression in tabtools {cmd:smallcells(}{it:#}{cmd:)} as well, and
zero is not, so a table written by tabtools with the same {it:#} passes this gate.

{pmore}
{opt smallcells()} is always an invariant, never a band, and fails with exit 9. The
message and the record carry no count value, only the number of table rows
that fail, with the {it:countexp} and reason that failed, as in
{bf:1 table rows fail, n1-e1 (1 small)}. The row count is
a count of table rows, not persons; under {opt maskrare} it prints as
{bf:<}{it:m} like every other gate count. {cmd:violations()} holds one row for
the failed gate, and no row identifier is printed. {opt smallcells()} ignores
the call's {opt by()} (an entry's own {cmd:by()}, below, sets its strata),
and {opt makespec()} does not write it.

{pmore}
{it:Microdata audit.} An entry may end in suboptions: {it:countexp} [{it:countexp} ...] [{cmd:if}
{it:exp}]{cmd:,} [{opt id(varname)} {opt by(varlist)} {opt margins}[{cmd:(strata}|{cmd:conditions)}]]. Any of them
makes the entry an audit of the rows in memory, before a table is made, rather
than of a results table. Each {it:countexp} is then a condition, 0 or 1 on every
row in scope, such as {cmd:dx==1}; a count column, or a flag with missing values, is
r(459) and is never counted. A cell is the rows in scope where its condition
is 1, within each {cmd:by()} stratum. A cell fails when its rows are 1 to {it:m}-1, and
with {opt id()} also when its distinct values of {it:varname} are (a missing id counts as
one value), checked in the same pass. The handbook's minimum frequency rule
counts a frequency table's contributors, respondents rather than records
(Hundepool et al. 2026, sec. 4.2.1 and 5.1); checking the rows as well is
datamap's own, conservative choice. {cmd:by()} sets the strata, one per distinct
value (or combination) of {it:varlist} with a missing value a stratum of its own
(the numbering of {cmd:egen group(}{it:varlist}{cmd:), missing}; a strL works), independent of
the call's {opt by()}. Without {cmd:by()} the whole scope is one stratum.

{pmore}
The gate line names each failing cell, up to eight, by its condition and
stratum, never by a count, as in
{bf:2 cells fail, rep78==1 in foreign=0 (rows), rep78==3 in foreign=1 (rows, ids)}. A
stratum is written as a {opt by()} group is ({it:var}{cmd:=}{it:value}, a string in square brackets
with {cmd:\x}{it:HH} escapes). Under {opt maskrare} a stratum whose rows or ids in scope are 1
to {it:m}-1, and every stratum when a {cmd:by()} variable is in {opt exclude()}, is named by
its number ({bf:group 3}). Under {opt safe} a {cmd:by()} variable that is an identifier, a
date, or text holding a digit is refused (r(198)). The number of failing cells
obeys the mask as every gate count does.

{pmore}
{opt margins} adds the margins audit, a second record labelled
{it:entry} {bf:[margins]}. A margin is a published total and its cells are
one relation: {cmd:margins(strata)} takes the cells of each stratum (its
conditions), {cmd:margins(conditions)} the cells of each condition across
the strata, and {opt margins} both, the handbook's standing assumption that
tables carry their margins and totals (sec. 4.2.2). A margin of one cell is
that cell, which the floor already checks. The small cells of a margin
(rows, or ids, 1 to {it:m}-1) are those a primary suppression would hide, and
each count is taken to add up to the margin, as in a table of persons in
exclusive categories. A margin is exposed by the first pattern that
applies:

{phang2}o  {bf:single}: one small cell; the total minus the shown cells gives
it back (sec. 4.1, Example 1a, and sec. 4.2.2).{p_end}
{phang2}o {bf:singletons}: two small cells, each a single unit (one id with {opt id()}, else one
row); each can subtract itself from the total (sec. 4.3.2, protection rule
PS2).{p_end}
{phang2}o  {bf:smallsum}: small cells whose sum, which the total gives back,
is 1 to {it:m}-1 in rows or ids (datamap's own rule).{p_end}
{phang2}o  {bf:pinned}: small cells whose sum is their number, or their number
times {it:m}-1; with each known to lie in 1 to {it:m}-1, as {bf:<}{it:m}
says, every one is fixed (datamap's own rule: the feasibility interval of
sec. 4.2.2 closed to a point).{p_end}
{phang2}o {bf:narrowed}: small cells whose sum {it:S}, with each known to lie in 1 to {it:m}-1,
leaves every one a range narrower than that, from the larger of 1 and
{it:S}-({it:k}-1)({it:m}-1) to the smaller of {it:m}-1 and {it:S}-({it:k}-1) for {it:k} small cells; with {it:m}=10,
cells of 9 and 8 rows beside a total that gives back 17 are each 8 or 9
(datamap's own rule: the feasibility interval of sec. 4.2.2 tighter than {bf:<}{it:m}).{p_end}

{pmore}
The record names up to eight exposed margins by stratum or condition, as in
{bf:foreign=0: smallsum (rep78==1, rep78==5); rep78==3: single (foreign=1)}, and
fails the gate (exit 9). Under {opt maskrare} (and {opt safe}) every pattern but {bf:single} is
named {bf:exposed}, as in {bf:g=0: exposed (dx==1, dy==1)}: {bf:singletons} would say that
each hidden cell is 1, {bf:pinned} that each is fixed, and {bf:smallsum} and {bf:narrowed}
what their total or range is, which the message and the record never
carry; {bf:single} says only that one cell of the margin is small, which the floor
record says already. Without the mask the specific name is printed. It is an
audit: it does not mask or rewrite a table. Each margin is checked on its own,
as the minimum standard PS1 considers the table equations separately
(sec. 4.3.2); the joint system of a table's margins, and tables linked across
outputs, are not checked. {cmd:margins(strata)} needs two or more conditions,
{cmd:margins(conditions)} needs {cmd:by()}, and {opt margins} needs one of them (r(198)
otherwise).

{dlgtab:Sanity bands}

{phang}
{opt bands(gates)} declares the call's sanity bands: expectations about what
the data should look like, as opposed to invariants, which describe what they
must be. Inside {opt bands()} write {opt expectn()}, {opt stat()},
{opt inrange()}, {opt coverage()}, {opt groupstat()} with {cmd:band()},
{opt heaping()} with {cmd:max()}, and {opt complete()} with {cmd:min()}, as
{cmd:bands(expectn(9000 11000) stat(mean outcome 0.03 0.08))}. Any other
option inside {opt bands()} is an error. See
{help dataprobe##kinds:Invariants, bands, and review items}.

{phang}
{opt bandwarn} reports failing bands as warnings under a {bf:BAND WARNINGS}
heading and leaves failing invariants halting. It is meant for a synthetic
run, where the bands are not calibrated, while production runs leave it off.

{phang}
{opt coverage(spec)} checks that a delivered file covers the period it should. Each
entry is {it:datevar lo hi}{cmd:,} {cmd:gap(}{it:#}|{cmd:none)}
[{cmd:tail(}{it:#}{cmd:)} {cmd:sides} {cmd:years} {cmd:dropoff(}{it:#}{cmd:)} {cmd:endq(}{it:#}{cmd:)}
{cmd:unit(date}|{cmd:year}|{cmd:yyyymmdd)}] for a daily date. Without {cmd:unit()} the variable must
carry a daily display format ({cmd:%td} or {cmd:%d}, in any variant such as
{cmd:%tdCCYY-NN-DD}); an unformatted day count is refused with r(198), and a
{cmd:%tc} datetime needs {cmd:dofc()} first. {cmd:gap()}, the
delivery lag in days, is required and has no default, so an unsourced coverage
expectation stops the call. The checks are {bf:coverage(outside)} (the share of
dates outside [lo, hi] is at most {cmd:tail()}, default 0),
{bf:coverage(late_end)} (the last date is at least hi - gap, which a truncated
delivery fails), {bf:coverage(early_start)} (the first date is at most lo +
gap), and with {cmd:years} {bf:coverage(year_gap)} (no calendar year between
the first and last date is empty). {opt coverage()} is always a band, whether
written inside {opt bands()} or not.

{pmore}
{cmd:endq(}{it:#}{cmd:)}, with {it:#} strictly between 0 and 0.5 (anything else
is r(198)), tests {bf:early_start} on the {it:#}-quantile of the date and
{bf:late_end} on the (1 - {it:#})-quantile, instead of the raw minimum and
maximum, so one stray record near {it:hi} cannot hide a truncated delivery. The
quantile is the default definition of {cmd:_pctile}. The printed line names the
quantile tested (for example {bf:p99}), and under {opt maskrare} it is shown
only when it passes the same suppression rule as any other printed
statistic. Without {cmd:endq()} the raw extremes are used, as before. Without
the mask, a failing {bf:early_start} or {bf:late_end} prints a date tested that
is not a whole day at full precision with the day beside it,
{cmd:first 738.5 (08jan1962)}.

{pmore}
{cmd:gap(none)} declares that the plan sources no delivery lag. {cmd:gap()}
is still required and has no default; {cmd:none} is a typed declaration, not a
default. The {bf:outside} check, {cmd:tail()} and {cmd:years} still run; {bf:late_end}
and {bf:early_start} are not tested, print as "not declared
(gap(none))", write no {opt ledger()} or {opt checks()} rows, and are not
counted as passes. {cmd:gap(none)} with {cmd:endq()} is r(198).

{pmore}
{cmd:sides} splits the {bf:outside} count into the dates before {it:lo} and
the dates after {it:hi}, in its message and {cmd:observed} text, as in
{cmd:12 dates (0.6%) outside (3 before 01jan2010, 9 after 31dec2023)}. The
verdict, {cmd:tail()}, and the share are those of the combined count. Each side
is masked against the outside count it adds up to, so under {opt maskrare} a
small side prints {bf:<}{it:m} and the other {bf:all but <}{it:m}; when the
outside count itself is masked, both sides print as {cmd:sides withheld}. No
date outside the window is printed. {cmd:r(coverage_outside_low)} and
{cmd:r(coverage_outside_high)} hold the raw counts, summed over the
{cmd:sides} entries; they are missing when the outside check of any
{cmd:sides} entry did not run (no nonmissing dates, or values not valid in
{cmd:unit()}), so a partial sum is never returned.

{pmore}
{cmd:dropoff(}{it:#}{cmd:)}, with 0 < {it:#} <= 100, adds the check {bf:coverage(dropoff)}: it fails each
calendar year whose dates inside [{it:lo}, {it:hi}] number fewer than {it:#}% of the median
of the up to 5 complete years immediately before it, which catches a register
whose recent years thin out (reporting lag, a coding change) while every year
still has rows. A year is complete when [{it:lo}, {it:hi}] holds all of it. Every year
with at least 3 complete years before it is tested, through the year of
{it:hi}; bounds that leave no such year are r(198). A partial final year ({it:hi} before
31 December) is prorated: its threshold is multiplied by the share of that
year's days inside the window, and {cmd:expected} names those days. {cmd:gap()} is not
applied, so a threshold below 100 leaves room for the delivery lag. A count at
exactly {it:#}% passes. A year whose reference median is 0 (no rows in the years
before it, as when a register starts after {it:lo}) has no threshold: it is not
tested, and the row names it as {cmd:not tested (reference median 0)}; the check
fails when no year is tested. The row names the years that fall short, never a
count; under {opt exclude()} it gives only how many.

{pmore}
{cmd:unit()} declares the unit the values are in, so a variable without a
daily format is checked as it is stored; its format and values are never
changed. {cmd:unit(date)} is a day count on Stata's daily scale (01jan0100 to
31dec9999). {cmd:unit(year)} is a whole calendar year from 100 to 9999, with
{it:lo}, {it:hi}, and {cmd:gap()} in years ({cmd:%ty} is the only date format
it accepts). {cmd:unit(yyyymmdd)} is an eight-digit number such as 20200131,
stored as {cmd:long} or {cmd:double} (a {cmd:float} cannot hold eight digits
and is r(198)); {it:lo} and {it:hi} are YYYYMMDD numbers or dates, and the
checks run on the calendar date. A format that contradicts the unit (a
{cmd:%td} variable with {cmd:unit(year)}) is r(198), as is a YYYYMMDD bound
that is not a calendar date. A nonmissing value that is not valid in the unit
(month 13, day 32, 30 February, year 1.5) fails every declared check, with
the masked count of such values and no value printed, and nothing else is
tested on that variable.

{pmore}
{bf:Registry delivery checks.} Which gate answers which question:

{p2colset 9 42 44 2}{...}
{p2col:Question}Gate{p_end}
{p2line}
{p2col:Dates outside the window}{cmd:inrange(}{it:d lo hi}{cmd:)}, as an
invariant or in a band{p_end}
{p2col:Truncated delivery}{cmd:coverage()} {bf:late_end}; add {cmd:endq()}
against stray records{p_end}
{p2col:A missing calendar year}{cmd:coverage(}...{cmd:, years)}{p_end}
{p2col:Share of dates inside the window}{cmd:coverage(}...{cmd:, tail())}{p_end}
{p2col:Dates before vs after the window}{cmd:coverage(}...{cmd:, sides)}{p_end}
{p2col:Recent years thinning out}{cmd:coverage(}...{cmd:, dropoff(50))}{p_end}
{p2col:A year or YYYYMMDD variable}{cmd:coverage(}...{cmd:, unit(year))}{p_end}
{p2col:No sourced lag}{cmd:gap(none)}, which drops the end checks{p_end}
{p2line}
{p2colreset}{...}

{pmore}
Only {cmd:coverage()} catches a truncated delivery. {cmd:inrange()} bounds do
not: a file that ends two years early still lies inside the window.

{dlgtab:Review items}

{phang}
{opt review(spec)} prints, for each {cmd:\}-separated entry {it:label}{cmd::} {it:expression}, the number
and share of rows in scope where the expression is true, masked under
{opt maskrare}. It is evaluated, like {opt rule()}, before any
sort. {cmd:review("day0": outcome == 1 & outcome_dt - entry < 1)}.

{phang}
{opt heaping(spec)} prints, for each daily date in {it:datevarlist}
[{cmd:,} {cmd:fold(}{it:#}{cmd:)} {cmd:max(}{it:# [# #]}{cmd:)}], the share of
dates on 1 January, on the 1st of any month, and on the 15th (each variable
must carry a daily display format, {cmd:%td} or {cmd:%d} in any variant; an
unformatted day count is refused with r(198), and a {cmd:%tc} datetime needs
{cmd:dofc()} first), next to the
shares expected by chance (1/365.25, 12/365.25, 12/365.25). A share above
{cmd:fold()} times its chance share (default 5) is marked. With {cmd:max()},
the 1 January share (and with two or three numbers the 1st and 15th shares)
must not exceed the given shares; that is a gate, a band inside
{opt bands()}. Under {opt maskrare}, 1 January is one of the 1sts, so the 1st
share prints as {bf:[masked]} when the 1sts of the other months number 1 to
{it:m}-1.

{phang}
{opt groupstat(spec)} prints a statistic by group next to its pooled value. Each
{cmd:\}-separated entry is {it:statistic varlist}{cmd:,} {cmd:by(}{it:groupvars}{cmd:)} [{cmd:min(}{it:#}{cmd:)}
{cmd:band(}{it:lo hi}{cmd:)} {cmd:relative}] [{cmd:if} {it:exp}], with the statistics of {opt stat()} other than
{cmd:ratio}. An {cmd:ess} with a negative weight in scope is r(459), as in
{opt stat()}. A row whose {it:groupvars} value is missing belongs to no group and is left
out of the groups and of the pooled value, so the pooled value always
describes the rows of the groups. Groups with fewer than {cmd:min()} rows
(default: the mask threshold, or 1 without masking) are pooled into one
line. Under masking, an explicit {cmd:min()} below the mask can list a group of 1 to
{it:m}-1 rows; its cells are masked and it is named by its number ({cmd:group 3}), never
by its value, which would be a rare level. With {cmd:band()}, every group's
statistic must lie in [lo, hi], including a group pooled away under the mask,
which fails as {cmd:[suppressed]}; only an explicit {cmd:min()} leaves the groups below it
out of the band. As in {opt stat()}, a mean of a float variable is compared with the
band exactly, so a group whose float values are all 0.2 fails {cmd:band(0 0.2)}; set
the band a little wider than float resolution. With {cmd:relative}, the band applies
to the ratio of the group's statistic to the pooled statistic, as in the
laboratory unit-switch check
{cmd:groupstat(median bcell, by(lab_site year) band(0.05 20) relative)}; the table
then prints each group's ratio, the value the band tests, and the pooled row
stays raw. Under the mask a withheld pooled value withholds the ratios as
well, and a withheld cell reads {bf:[suppr.]}. When the pooled statistic is 0 or
undefined, the ratio is undefined for every group: the band fails once with
"ratio to pooled undefined" and the pooled value, whatever the groups
hold. {cmd:pmiss} comes from the same computation as {help datamvp:datamvp, bytable()}. A band
entry whose scope has no rows, or whose {cmd:min()} leaves every group out,
fails. {opt groupstat()} ignores {opt by()}.

{pmore}
When a band fails, every failing group still has its own row, and each failing
message and ledger {cmd:observed} text also reports the direction: the groups above
the band and the groups below it, each with its count of groups and of
in-scope rows, for example
{cmd:3 groups above (rows 1,240), 1 group below (rows <5)}. Under {opt maskrare} the row
counts follow the rule for small counts ({bf:<}{it:m}, or {bf:all but <}{it:m} when the rest would
recover a small cell), both counts print {bf:[suppressed]} when the rows that pass
the band are a small cell, and a group count that would pin masked rows is
masked with them. A direction that holds a group with fewer than the mask of
rows, or a group withheld from the table, also prints its rows as
{bf:[suppressed]}, because the total of two such groups would give back their
sizes; a direction whose groups all reach the mask keeps its rows. A group
whose value is undefined is reported as undefined. A passing band and an entry
without a band read as before.

{pmore}
Under {opt maskrare}, a count cell ({cmd:n}, {cmd:sum}, {cmd:distinct}) reads {bf:[suppr.]} when the
group's rows, or its nonmissing rows, minus the count is between 1 and {it:m}-1,
and {bf:<}{it:m} when the count itself is in that range. A {cmd:sum} cell also reads {bf:[suppr.]}
when the group's nonmissing rows, its nonzero rows, or, for a variable with
two values in the group, the rows of either value number 1 to {it:m}-1: a sum is a
value of its rows. An {cmd:n} cell is withheld as well when N minus the shown {cmd:n}
cells is 1 to {it:m}-1, since that difference is the rows of the pooled-away groups
and the masked cells; N is the call's N, which the output always prints or
records (the profile header, a PASS line, a {opt review()} or {opt complete()} item, the
ledger's {cmd:n_scope}), and the cells' own total over the entry's rows (its {cmd:if}, a
nonmissing {cmd:by()} value), whose count another item may print. The same holds for
the rows of the groups not shown exactly minus that difference (a group
printed with a small complement), and in a profile for the profiled variable's
nonmissing count and, for the {cmd:sum} of a 0/1 categorical variable, its count of
ones. The smallest shown cell (for the complement, the cell with the smallest
complement) then reads {bf:[suppr.]}. A {cmd:pmiss} cell is masked when the group's
missing or nonmissing count is 1 to {it:m}-1. An {cmd:sd} cell is masked when the group
has fewer than {it:m} nonmissing rows or, for a variable with two or three values
in the group, fewer than {it:m} rows of any value; an {cmd:ess} cell when the group's
nonzero or zero weights number 1 to {it:m}-1. Two cells of one group can give back
a count neither shows: a {cmd:sum} and a {cmd:mean} of one variable give its nonmissing
count ({cmd:sum}/{cmd:mean}), an {cmd:n} and a {cmd:pmiss} its rows and missing count. When the call
prints the {cmd:mean} of a variable over the same groups (the same {cmd:by()} and {cmd:if}: this
entry, another {opt groupstat()} entry, or {opt stat()} with the call's {opt by()}), its {cmd:sum}
cell reads {bf:[suppr.]} in every group where its {cmd:n} cell would be withheld by the
rules above (a {cmd:sum} of 0 stays); when the call prints its {cmd:n} over the same
groups, so does its {cmd:pmiss} cell, which is also withheld in the group with the
fewest rows while the rows of the groups whose {cmd:pmiss} shows fall 1 to {it:m}-1 short
of the entry's rows or of N. The {cmd:mean} and the {cmd:n} stay. Statistics over another
{cmd:by()} or {cmd:if}, and a {opt stat()} expression set against a variable, are not
linked. The pooled value, {cmd:pmiss} included, is withheld when any group cell is
masked. The pooled row holds every group's rows whatever the {cmd:by()}, and the {cmd:sum}
cells of any entry over the same {cmd:if} add up to its pooled {cmd:sum}: when the call
prints a {cmd:sum} of a variable (any {opt groupstat()} entry over the same {cmd:if}, or
{opt stat()}), the pooled {cmd:mean} of that variable reads {bf:[suppr.]} whenever its pooled {cmd:n}
would be withheld by the rules above (a pooled {cmd:mean} of 0 stays), so {cmd:sum}/{cmd:mean}
never gives back the pooled nonmissing count. A failing group that the table
withholds is named by its number ({cmd:group #3}), never its values. The mean or a
percentile of a date prints as a date, at month precision under the mask, as
the pooled value does; a date format wider than the column prints as a {cmd:%td}
date. Every cell fits its column, and a withheld pooled value reads
{bf:[suppr.]}. Without the mask, a failing band on a date prints a value its date
does not show exactly at full precision with the date beside it,
{cmd:1865.5 (08feb1965)} ({cmd:%21.0g} for {cmd:%tc}), so a value just outside the band never
reads as the bound.

{pmore}
A colon after a list of statistics, {cmd:groupstat(}{it:statistic statistic}
...{cmd::} {it:var}{cmd:, by(}{it:groupvars}{cmd:)} [{cmd:min(}{it:#}{cmd:)}] [{cmd:if} {it:exp}]{cmd:)}, prints one
table with a column per statistic, for example
{cmd:groupstat(n mean p1 median p99: ipw, by(arm))}. Any number of statistics may be
listed: a table holds six columns, and the statistics after the sixth continue
in further blocks of up to six columns below it, each with its own column
header, group rows, and pooled row, so every line fits 80 columns; the
small-group line follows the last block. Several variables print one table
each, in the order given, as in
{cmd:groupstat(n mean sd p5 p25 median p75 p95: ipw bmi, by(arm))}. Each statistic
is computed once for all the variables and recorded exactly as its own
single-statistic entry would be, so {cmd:ledger()} gets one row per statistic and
variable, labelled {it:statistic var}, and {cmd:checks()} rows stay one statistic
each. Masking follows the rules above cell by cell, and {cmd:min()} and the entry's
{cmd:if} apply to every column. {cmd:band()} and {cmd:relative} are declared per statistic, so
an entry with two or more statistics takes neither and is a review item; write
a separate entry for each banded statistic. A statistic named twice ({cmd:median}
and {cmd:p50} are the same), a variable named twice, or an unknown statistic is an
error (r(198)). The colon form with one statistic, and the form without a
colon, behave as before.

{phang}
{opt complete(spec)} prints the masked complete-case count and share over
{it:varlist}, within each {opt by()} group. With
{cmd:complete(}{it:varlist}{cmd:, min(}{it:#}{cmd:))} the share must be at
least {it:#}.

{phang}
{opt jumps(spec)} counts, for {it:id time value} [{cmd:,}
{cmd:ratio(}{it:#}{cmd:)}], consecutive positive values within id (sorted by
time) where one exceeds {cmd:ratio()} times the other (default 10). Rows with a
missing time or value are left out of the sequence. Measures of one id at the
same time are ordered by value, so the count does not depend on the order of
the data; the message then counts the persons with such ties.

{dlgtab:Gate control}

{phang}
{opt by(varlist)} evaluates gates within groups defined by {it:varlist} and adds a
groupwise completeness and missingness profile. A group is labelled by its
values (a numeric variable by its value label if it has one); a blank string
is shown as {cmd:(blank)} and a numeric missing as its code ({cmd:.}, {cmd:.a}). The gate
messages and the ledger {cmd:grp} column name the group by its stored values,
{cmd:by(site year | site=3 year=2015)}: the variables, then {it:var}{cmd:=}{it:value} for each,
never a value label or a group number. A string is written in square brackets
({cmd:site=[abc]}, a blank string {cmd:[]}), with a backslash, double quote, apostrophe,
backtick, dollar sign, square bracket or brace, and tab, line feed and
carriage return, written as {cmd:\x}{it:HH} (two lowercase hex digits), so a value
holding spaces, {cmd:=}, {cmd:|} or quotes cannot be mistaken for a separator. A group
withheld under {opt maskrare} is named by its number ({cmd:by(site group 7)}), not its
values. {opt intervals()},

{opt keyset()}, {opt constant()}, {opt sets()}, {opt smallcells()}, {opt coverage()},
{opt heaping()}, {opt groupstat()}, and {opt jumps()} ignore {opt by()} and run
once on the {cmd:if}/{cmd:in} sample. {opt over(varname)} is a single-variable
synonym for {opt by(varlist)}.

{pmore}
{opt byfreq} adds a GROUPWISE FREQUENCIES block to the profile: for every
categorical and string variable, the same frequency table as the pooled one
(descending count, ties in level order, {opt maxfreq()} levels, {opt rare()} flags) within
each {opt by()} group, headed by the group label of the GROUPWISE SUMMARY. Under
{opt maskrare}, each cell and the pooled {bf:[suppressed]} lines follow the pooled
table's rules, and a group pooled away by the mask is not listed. The call's
{cmd:if}/{cmd:in} apply, string and numeric groups work, and {opt nomissing} leaves the tables
as they are. {opt byfreq} is an option because {opt by()} alone leaves the pooled tables
as before; {opt gatesonly} ignores it, and it needs {opt by()} or {opt over()} (r(198)
otherwise). Example: {cmd:dataprobe mc if cx, by(arm) byfreq maxfreq(15) maskrare}.

{phang}
{opt check:s(filename)} reads gate specifications from {it:filename} (a name
that ends in {opt .dta} is read as given, one without it as {it:filename} or
{it:filename}{cmd:.dta}). A row
whose text holds a backtick, or a {cmd:$} followed by a letter, underscore or
{cmd:{c -(}}, is refused with r(198) naming the row and column, because the text
would otherwise be expanded as a macro; write such a character as
{cmd:char(96)} or {cmd:char(36)} inside an expression. A {cmd:$} that does not
start a name, as at the end of a {cmd:regex} pattern, is accepted. Each row
names its gate in string variable {cmd:gate} (or {cmd:check}) and its arguments
in {cmd:var}, {cmd:arg1}, {cmd:arg2}, {cmd:values}, and {cmd:pattern}; an
optional string variable {cmd:kind} set to {cmd:band} places the row inside
{opt bands()}. A {cmd:rule} or {cmd:review} row takes the label in {cmd:var} and
the expression in {cmd:pattern}; a {cmd:stat} row takes the variable in
{cmd:var}, the statistic in {cmd:values}, the band in {cmd:arg1} and
{cmd:arg2}, and an optional condition in {cmd:pattern}; an {cmd:events} row
takes the covariates in {cmd:var}, the event variable in {cmd:values},
{cmd:min()} in {cmd:arg1}, and a condition in {cmd:pattern}; a {cmd:keyset} row
takes the keys in {cmd:var}, the file in {cmd:values}, and the mode in
{cmd:arg1}; a {cmd:constant} row takes the variables in {cmd:var}, the keys in
{cmd:values}, and {cmd:ignoremissing} in {cmd:arg1}; a {cmd:groupstat} row
takes the variables in {cmd:var}, the statistic in {cmd:values}, the
{cmd:by()} variables in {cmd:arg1}, its suboptions in {cmd:arg2}, and a
condition in {cmd:pattern}; a {cmd:coverage} row takes the date in {cmd:var},
lo and hi in {cmd:arg1} and {cmd:arg2}, and {cmd:gap()} and the other
suboptions in {cmd:values}; {cmd:intervals}, {cmd:sets}, {cmd:jumps}, and
{cmd:heaping} rows take the spec before the comma in {cmd:var} and the
suboptions in {cmd:values}; a {cmd:complete} row takes the variables in
{cmd:var} and {cmd:min()} in {cmd:arg1}; a {cmd:smallcells} row takes the
{it:countexp}s in {cmd:var} and the entry condition in {cmd:pattern}.

{phang}
{opt makes:pec(name[, replace])} writes a starter checks file from the current
dataset: the observed row count, required variables, observed ranges or
allowed values, and a candidate {cmd:isid} key. A name ending in {cmd:.do} writes the same
gates as one {cmd:dataprobe, gatesonly} command in a do-file, so they can be read,
edited, and compared in a diff; any other name follows the frame-or-file rule
of {opt saving()} and writes the {opt checks()} spec. Run on the data it was made from,
the do-file passes, and a gate that fails exits 9. A row whose text holds a
line break, a backtick, {cmd:$}, or a comment opener, and the {opt allowed()} entry of a
string variable with a level that holds a space, are left out with a comment
saying so. The header comment names the dataset and the datamap version. If
the data later lose a gated variable, the do-file's {opt require()} fails (exit 9)
and the gates on that variable are skipped with a note (see {opt require()}). It
describes the data as they are; review it before treating it as a gate
contract, and never use it as a source of bands. Numeric bounds and levels are
written at full precision and string levels in double quotes, so {opt checks()}
reads the file back as a passing spec on the same data; bounds are compared at
full double precision. A string variable with a level containing a double
quote, a backtick, a dollar sign, or a backslash gets no {cmd:allowed} row.

{phang}
{opt comp:are(name)} compares the current profile with a baseline: a frame, or
a Stata dataset ({it:name} or {it:name}{cmd:.dta}). The baseline may be a saved
profile ({opt saving()} from {cmd:dataprobe} or {cmd:datamap}, or a
{opt snapshot()} frame) or any other dataset, whose variable names and
storage types alone are compared. The call prints the block described under
{help dataprobe##snapdiff:Snapshot and diff}, under {opt gatesonly} too. An
added or dropped variable, a changed storage type or class, and a changed
observation count are reported as a {cmd:compare} violation; a changed
missing count, distinct count, mean, or range is printed and never fails. A
baseline variable is dropped when it is no longer in the data; one left out
of {it:varlist} is not. The target is checked before any output (see
{opt saving()}).

{phang}
{opt warn} downgrades every gate, invariant and band alike, from a halt to a
warning. It is for diagnosing a do-file interactively; a committed gate call
should use {opt bandwarn} instead, so that invariants still halt.

{phang}
{opt minver:sion(#)} exits with r(198) unless the installed datamap version is at
least {it:#}. Alone, {cmd:dataprobe, minversion(1.8.0)} needs no data in memory and
returns {cmd:r(version)}; an older copy also exits r(198), because it does not know
the option, so a do-file can reinstall on a nonzero return code.

{dlgtab:Output}

{phang}
{opt sav:ing(name[, replace])} saves the per-variable profile, the 27 columns
of {help datamap##saving:datamap's saving()} table plus {cmd:varname} and
{cmd:dc_class}. The target follows one rule in {opt saving()}, {opt compare()},
{opt diff()}, {opt snapshot()}, and {opt makespec()}: a name that ends in
{opt .dta} (or {cmd:.do}, for {opt makespec()}) or holds a {cmd:/} or {cmd:\}
is a file, and any other name is a frame. {opt compare()} and {opt diff()} read
the frame of that name when one exists, and otherwise the file ({it:name} or
{it:name}{cmd:.dta}; a {it:name} that ends in {opt .dta} is read as
given); {opt snapshot()} takes a frame only. The target is
checked right after the options are parsed, before any profile output: an
existing frame (r(110)) or file (r(602)) without {cmd:replace}, a folder that
does not exist (r(603)), a file that cannot be found (r(601)), and the current
frame (r(198)) stop the call. {opt saving()} and {opt snapshot()} cannot name
the same frame, and a suboption other than {cmd:replace} is r(198). The
{cmd:datasignature} column holds the {help datasignature} of the dataset as
loaded, before {cmd:if}/{cmd:in}, the value {opt signature} returns.

{phang}
{opt snap:shot(frame[, replace])} stores the profile of the data in a frame
named {it:frame}: the rows {opt saving()} writes, and the key and row count the
snapshot was taken with. It runs after {opt diff()}, so
{cmd:diff(before) snapshot(before, replace)} compares with the last snapshot and
then replaces it. A {cmd:strL} variable is never chosen as the key, since
{helpb merge} cannot use one; when one would otherwise have qualified, a note
names it. See {help dataprobe##snapdiff:Snapshot and diff}.

{phang}
{opt diff(name)} prints what changed since a baseline, a frame or a file named
as for {opt compare()}, and never halts. {opt tol(# [#])} sets what counts as a
change: the first number is the relative tolerance for a mean, minimum, or
maximum (default {bf:1e-8}), the second the absolute tolerance for counts
(default {bf:0}). {opt tol()} requires {opt diff()} or {opt compare()}.

{phang}
{opt only:flagged} filters console output to flagged variables and groups. It
cannot be combined with {opt gatesonly}.

{phang}
{opt show(flagged)} is equivalent to {opt onlyflagged}; {cmd:flagged} is the
only value it accepts.

{phang}
{opt viol:ations(name[, replace])} saves one row per failed or warned gate
entry with variables {cmd:check}, {cmd:gate}, {cmd:variable}, {cmd:label},
{cmd:group}, {cmd:observed} (masked as printed), {cmd:expected},
{cmd:severity}, {cmd:kind}, and {cmd:message}. The only suboption is
{cmd:replace}; any other word is r(198) before any work. A {it:name} that ends
in {opt .dta} or holds a {cmd:/} or {cmd:\} is a file, quoted when it holds a
space ({cmd:violations("my vio.dta", replace)}); any other name is a frame.

{phang}
{opt ledger(filename[, run(string)])} appends one row per gate entry, passed or
failed, and one per review item, to a Stata dataset, creating it when
absent; {opt .dta} is added to a filename without an extension. Quote the filename
when it contains spaces; embedded double quotes, backticks and shell
metacharacters in the actual filename are refused. The ledger is normally set
once for a do-file with {help dataqa:dataqa set ledger() run()}. Its columns are {cmd:run}, {cmd:stamp},
{cmd:seq} (call number within the run), {cmd:dataset}, {cmd:scope} (the call's and the entry's
{cmd:if}), {cmd:family}, {cmd:label}, {cmd:variable}, {cmd:grp}, {cmd:kind} (invariant, band, or review), {cmd:status}
(pass, fail, warn, review, or error), {cmd:observed} (masked, as printed),
{cmd:observed_num} (missing whenever {cmd:observed} is masked), {cmd:expected}, {cmd:n_scope} (missing
below the mask threshold), {cmd:version}, {cmd:signature}, {cmd:masked} (1 when the call ran
under {opt maskrare} with a threshold of at least 5), {cmd:mincell}, {cmd:minshown} (the
smallest positive count printed unmasked), {cmd:obs_masked}, {cmd:message}, and {cmd:phase} (see
{opt phase()}). In a session set with {help dataqa:dataqa set worker()} the rows go to that job's
shard of the ledger, with one more column, {cmd:worker}, and {help dataqa:dataqa merge} folds the
shards into the ledger; {cmd:r(ledger)} still names the ledger. The working ledger
belongs on the server with the data; {help dataqa:dataqa export} writes the release copy. A
call that exits for any reason other than a gate failure (exit 9) or Break,
such as a parse error or a missing variable, appends one row with {cmd:family} {cmd:call}
and {cmd:status} {cmd:error} before exiting with its own return code, and {help dataqa:dataqa assert}
halts on it. Under {help dataqa:dataqa set collect} a failed gate also writes its rows and
the call returns 0, leaving the halt to {cmd:dataqa assert}.

{phang}
{opt phase(name)} tags this call's ledger rows with a phase, such as
{cmd:analysis}, in the ledger column {cmd:phase}; it overrides the session
phase of {help dataqa:dataqa set phase()}, and without either the column is
empty. It requires a ledger, from {opt ledger()} or {cmd:dataqa set}
(r(198) otherwise), and must be a valid Stata name. {help dataqa:dataqa}
{cmd:report}, {cmd:assert}, {cmd:export}, and {cmd:compare} read chosen phases
with {opt phase()}, and {cmd:dataqa assert} {opt pending()} lets datasets of a
later phase be absent. A ledger written before the column existed takes new
rows as usual; its old rows read as phase empty. The error row of a call that
fails is tagged with the call's own {opt phase()} when it is a valid name, else
with the session phase. In a {help dataqa:dataqa set worker()} session the
error row, like every other row, goes to that worker's shard.

{phang}
{opt soft:collect} lets a do-file continue past a {cmd:dataprobe} call that
fails to run. It requires a ledger, from {opt ledger()} or {cmd:dataqa set}
(r(198) otherwise). When the call fails with a data or specification error
(return codes 100-199, such as a missing variable (111), a misspelled option or
a gate spec that does not parse (198), or a type mismatch (109); 400-499; 601,
a file such as a {opt checks()} spec not found; and 2000-2999, such as an
{cmd:if}/{cmd:in} sample with no observations (2000)), the call writes its
error row exactly as without the option, prints one line naming the return
code, and returns 0 with {cmd:r(softfail)} = 1 and {cmd:r(softfail_rc)} set to
the return code; every other {cmd:r()} result is cleared. The error row is a
halting row: {help dataqa:dataqa assert} exits 9 on it and {cmd:dataqa report}
lists it as a call error, so {opt softcollect} never turns a broken check into
a pass. Any other error still halts with its own return code: Break, an error
writing the ledger (the row could not be written, so nothing records the
failure), I/O errors on other files (602, 603, 610), memory and system limits
(900-999, 1000 and above, such as r(1000)), and Mata errors. A call that runs
returns {cmd:r(softfail)} = 0. {opt softcollect} does not change gate
failures, which exit 9 unless {help dataqa:dataqa set collect} is on.

{phang}
{opt sig:nature} records the {help datasignature} of the dataset, as loaded
and before {cmd:if}/{cmd:in}, in {cmd:r(signature)} and the ledger.


{marker gate}{...}
{title:Gate mode}

{pstd}
Any gate option turns on gate mode. {cmd:dataprobe} does not stop at the first
failure: it evaluates every gate, accumulates all violations, and prints them as
a single block headed by the dataset name and the active masking. Each line
starts with the gate's family and label, such as {cmd:events(_d)},
{cmd:intervals(overlap)}, or {cmd:keyset(id)}:

{pmore}{cmd:. dataprobe, gatesonly expectn(282252) isid(lopnr) inrange(age 18 110) maskrare}{p_end}

{pmore}{err:EXPECTATION VIOLATIONS (3): cohort [masked <5]}{p_end}
{pmore}{err: expectn: expected N = 282252, observed 311920}{p_end}
{pmore}{err: isid(lopnr): not unique — 29668 duplicated rows}{p_end}
{pmore}{err: inrange(age): <5 obs outside [18, 110] (0 below, <5 above)  (p1 19, p99 97)}{p_end}

{pstd}
When every gate passes, {cmd:dataprobe} prints one line naming the dataset and the
gate families that ran, for example
{cmd:PASS: dose_intervals, 3 gate(s) (isid rule binary), N = 12,000, 0 violations [masked <5]},
so a clean log is distinguishable from one where the gates were
skipped. {opt gatesonly} with no gate declared prints a note saying nothing was
checked.

{pstd}
On any failing invariant, or any failing band without {opt bandwarn},
{cmd:dataprobe} exits with return code {bf:9}. Warnings print first, under
{bf:BAND WARNINGS} (or {bf:WARNINGS} with {opt warn}), then the
{bf:EXPECTATION VIOLATIONS}. Because Stata batch ({cmd:-b}) mode does not
propagate the return code to the shell exit status, automated harnesses detect
a gate failure by scanning the log for {cmd:r(9)}, not by the process exit code.


{marker kinds}{...}
{title:Invariants, bands, and review items}

{pstd}
Every gate record has a kind, fixed where the gate is declared, and the kind
travels unchanged into the console, the ledger's {cmd:kind} column, and the
register draft {help dataqa:dataqa report} writes.

{phang2}
{bf:Invariants} are the gates outside {opt bands()}: a failure is an
impossibility, fixed in the code or accepted with the PI, and the expectation
is never widened. They always halt, unless bare {opt warn} is given.

{phang2}
{bf:Bands} are the gates inside {opt bands()}, and {opt coverage()}: a failure
may be a synthetic quirk or a miscalibrated expectation that the register may
revise. They halt in production and warn under {opt bandwarn}.

{phang2}
{bf:Review items} ({opt review()}, {opt jumps()}, and {opt heaping()},
{opt groupstat()}, and {opt complete()} without a threshold) print and never
halt. With a threshold ({opt heaping()} with {cmd:max()}, {opt groupstat()}
with {cmd:band()}, {opt complete()} with {cmd:min()}) the entry still prints its
table or line, which is recorded as a review item, and its threshold is
recorded as a gate: such an entry is one review item in {cmd:r(n_reviews)} and
one gate in {cmd:r(n_checks)}, and it writes two {opt ledger()} rows, one of
{cmd:kind} review and one of kind invariant or band.

{pstd}
One gate call per dataset can therefore hold every invariant and every band,
with {cmd:global qa_calib bandwarn} set only under the synthetic switch.


{marker idioms}{...}
{title:Idiom map}

{pstd}
A hand-written check often has a gate of its own, with a clearer message and a
ledger row. Each pair below gives the same pass or fail verdict on the same
data.

{p2colset 5 52 54 2}{...}
{p2col:Hand-written pattern}Gate{p_end}
{p2line}
{p2col:{cmd:rule("flow": _N == 74)}}{cmd:expectn(74)}{p_end}
{p2col:{cmd:stat(mean outside 0 0.1)} on a flag}{cmd:coverage(dt lo hi, gap(none) tail(0.1))}{p_end}
{p2col:{cmd:bysort g: egen} median, {cmd:review()}}{cmd:groupstat(median x, by(g) band(lo hi) relative)}{p_end}
{p2col:{cmd:rule()} with {cmd:id[_n-1]} or {cmd:_n}}{cmd:byrule(id (time): ...)}{p_end}
{p2col:one {cmd:stat() if} per group label}{cmd:stat()} with {cmd:by(a b)}{p_end}
{p2line}
{p2colreset}{...}


{marker snapdiff}{...}
{title:Snapshot and diff}

{pstd}
After a data step, {cmd:dataprobe, snapshot(before)} keeps the profile in a
frame, and after the next step {cmd:dataprobe, diff(before)} prints what
changed. {opt compare()} prints the same block against a frame or a file, and
fails on a schema change; {opt diff()} never halts. Under {opt gatesonly} the
block still prints.

{phang2}{cmd:. dataprobe, gatesonly snapshot(before)}{p_end}
{phang2}{cmd:. drop if rep78 == .}{p_end}
{phang2}{cmd:. dataprobe, gatesonly diff(before) snapshot(before, replace)}{p_end}

{pstd}
The block is headed {bf:DIFF} (or {bf:SCHEMA COMPARE} under {opt compare()}),
names the baseline, and then prints:

{p2colset 5 24 26 2}{...}
{p2col:{bf:N}}{cmd:N: current 60, baseline 74, delta -14}{p_end}
{p2col:{bf:key}}when a key is known, {cmd:key make: unique before and after},
or {cmd:key make: unique before, not unique after (3 surplus rows)}{p_end}
{p2col:{bf:variables}}one line per variable that changed, in baseline order, with
the parts that changed, such as {cmd:type int -> str1}, {cmd:class categorical -> string},
{cmd:missing 5 -> 0 (-5)}, {cmd:distinct 21 -> 19 (-2)},
{cmd:mean 6165.26 -> 6292.68}, and {cmd:range 12 to 41 -> 12 to 35}. Then
{cmd:v: dropped (float)} for a variable no longer there and
{cmd:v: added (byte, categorical)} for a new one{p_end}
{p2col:{bf:none}}{cmd:no changes} when nothing moved{p_end}
{p2colreset}{...}

{pstd}
A count changes when it moves by more than the second number of {opt tol()}
(default 0). A mean, minimum, or maximum changes when it moves by more than
the first number (default 1e-8) times the larger magnitude. A variable with
a missing statistic on either side is not compared on it.

{pstd}
The baseline is a saved profile ({opt saving()}, {opt snapshot()}) or any
dataset. A dataset that is not a profile gives schema-only lines: N, added,
dropped, and storage type ({cmd:r(diff_schema_only)} is 1), with no missing,
distinct, or mean line. An excluded variable (on either side) is compared on
type, class, and missing count only. The key is the call's {opt id()} or
{opt isid()} key, otherwise the key a {opt snapshot()} recorded, otherwise the
first baseline variable with no missing value and as many distinct values as
rows. A {opt saving()} frame or file records no key, so with one the key before
is {cmd:unknown} when it has more than 1,000 distinct values (the profile
counts distinct values only up to {cmd:max(1000, maxcat())}); a {opt snapshot()}
always knows it. A key that is in the data but outside {it:varlist} reads
{cmd:key K: unique before, not checked after (not in the varlist)}, and a key
dropped from the data reads {cmd:dropped}.

{pstd}
Under {opt maskrare} every count from 1 to {it:m}-1 prints as {bf:<}{it:m} and a count that would
give one back is withheld; a minimum or maximum is never printed (the line
says {cmd:range changed}); and a mean prints only when both sides have at least {it:m}
nonmissing values and the variable is neither categorical nor two- or
three-valued on either side (else the line says {cmd:mean changed}), because such a
mean is a share that gives a count back. {opt mincell()} alone does not mask the
block. The stored results {cmd:r(diff_*)} are not masked.

{pstd}
{opt diff()} or {opt compare()} naming the current frame is r(198); naming a
frame or file that does not exist is r(601). {opt snapshot()}
refuses an existing frame without {cmd:replace} (r(110)). A path with a space
is given in quotes, {cmd:diff("my dir/before.dta")}, as in {opt saving()}; an
unquoted name with a space is r(198).

{pstd}
Empty data. When no observations remain (or none satisfy {cmd:if}/{cmd:in}), a
call with {opt diff()}, {opt compare()}, or {opt snapshot()} skips the profile
with a note, runs the declared gates, and reports the empty data: the N line
(for example {cmd:N: current 0, baseline 74, delta -74}) and each variable's
missing and distinct counts falling to 0. A class change is not reported
against an empty side, since every empty variable would classify as
categorical. Any other call on empty data stops with r(2000), as before.

{pstd}
Changes from 1.x. {opt compare()} prints one line per variable ({cmd:v: added},
{cmd:v: dropped}, {cmd:v: type a -> b}) and {cmd:no changes} in place of the
{cmd:added:} lists and {cmd:no schema drift detected}; its N line is as before. A
{opt saving()} target that cannot be written (a folder that does not exist is
r(603)) now stops the call before any output, where 1.x printed a note at the
end and returned 0. A {opt keyset()} key that is numeric on one side and string
on the other is a failed entry (a warning under {opt warn}), where 1.x stopped
with an error. {cmd:compare(}{it:name}{cmd:)} reads a frame of that name before a
file. {opt compare()} on empty data reports it, where 1.x stopped with r(2000),
and reads a quoted path that holds a space, where 1.x stopped with r(198).


{marker keyset}{...}
{title:Keyset preflight}

{pstd}
Before the verdict, {opt keyset()} prints a report on the merge the two
datasets would make, under {opt gatesonly} too:

{phang2}{cmd:KEYSET PREFLIGHT: make using ids}{p_end}
{phang2}{cmd:  types: make str18 in memory, str18 in ids}{p_end}
{phang2}{cmd:  unique: memory yes, ids yes; merge 1:1}{p_end}
{phang2}{cmd:  keys: 69 matched, 5 memory only, 5 ids only}{p_end}
{phang2}{cmd:  merge 1:1 would report: 69 matched, 5 master only, 5 using only}{p_end}
{phang2}{cmd:  shared non-key variables: price}{p_end}

{pstd}
The key types come first. A key that is numeric in memory and string in the
file (or the reverse) is a failed entry, reported before any count (exit 9, or
a warning under {opt warn}); {helpb merge} itself stops with r(106). Differing
string widths or numeric storage types are not a conflict. Uniqueness counts
missing values as values, as {cmd:merge} does, and decides the merge type
({cmd:1:1}, {cmd:1:m}, {cmd:m:1}, {cmd:m:m}). The row counts are those {cmd:merge}
reports for that type. Under {opt maskrare} each count obeys the mask, and one
whose complement is small prints {bf:all but <}{it:m}, as in
{cmd:keys: all but <5 matched, <5 memory only, 0 ids only}. In an {cmd:m:m}
merge with unequal rows per key, the matched-row count prints as computed. The
stored results are not masked.

{pstd}
A {cmd:strL} key variable, in memory or in the file, is also a failed entry reported
before any count ({cmd:strL key}), since {helpb merge} refuses a {cmd:strL} key with r(106) on
either side. The message names the variable; {cmd:recast str}{it:#} or {helpb compress} on that
side makes it a valid key. An empty sample or an empty file is compared as an
empty key set: every key on the other side is unmatched.

{marker kwindow}{...}
{pstd}
{bf:Date linkage: asof() and window().} With {cmd:asof()} or {cmd:window()} the
preflight goes on to the link by key and date:

{phang2}{cmd:  asof(index labdate): 1000 rows in memory}{p_end}
{phang2}{cmd:    labs rows with labdate on or before index: none 52 (5.2%), one 301 (30.1%), more 647 (64.7%)}{p_end}
{phang2}{cmd:    latest labdate tied: 12 (1.2%); latest older than 365: 40 (4.0%)}{p_end}
{phang2}{cmd:  window(start stop dispdate): 1000 rows in memory}{p_end}
{phang2}{cmd:    rx rows with dispdate in [start, stop]: none 50 (5.0%), one 300 (30.0%), more 650 (65.0%)}{p_end}
{phang2}{cmd:    joinby id would create 1,234,567 pairs; 2,345 inside the window}{p_end}

{pstd}
For each row in memory, {bf:none}, {bf:one} and {bf:more} count the file rows of its key
dated on or before {it:mdate} ({cmd:asof()}), or in [{it:mstart}, {it:mend}] ({cmd:window()}); they add
up to the rows in memory. Under {cmd:asof()}, {bf:more} is a history, and the as-of pick
takes the latest; {bf:tied} counts the rows whose latest date holds two or more
file rows, where the pick among them is arbitrary. Under {cmd:window()}, the first
count of pairs is what {helpb joinby} on the key makes before any date condition
(every row of a key in memory times every row of that key in the file), the
second what {cmd:keep if} the window leaves, so a cartesian blow-up shows before it
is run. A row in memory with a missing date (or start or stop) links nothing
and counts as none; a file row with a missing date is never a candidate; an
inverted window ({it:mstart} > {it:mend}) is empty. Both lines are printed when either
count is not zero. Missing key values are keys, as in {helpb merge} and {helpb joinby}. No
date is printed.

{pstd}
Nothing is joined: the keys and dates of memory are stacked once with the
file's, and one sort by key, date and row type counts the file rows before
each date ({it:O}(({it:N}+{it:M}) log({it:N}+{it:M}))). With one million rows on each
side and 200,000 keys, {cmd:asof()} added about 3 seconds and {cmd:window()}
about 4 seconds to a 2-second preflight, on one processor. A type conflict or
a {cmd:strL} key stops the entry before the link, as before.

{pstd}
The entry posts one review record ({cmd:none ...; one ...; more ...}) and one
gate record per threshold, each failing when its share of the rows in memory
exceeds the threshold; on an empty sample a threshold fails. Under
{opt maskrare} every count follows the mask; since none, one and more add up
to the rows in memory, a single withheld count withholds the smallest other
nonzero one ({bf:[suppressed]}); {bf:tied} and {bf:older than} are also tested
against their parent counts; a share prints only beside a count that is
shown; and the pair counts print as {bf:[suppressed]} when any other count of
the entry, the preflight's included, is withheld.


{marker masking}{...}
{title:Masking}

{pstd}
Under {opt maskrare} with threshold {it:m}, no count from 1 to {it:m}-1 is
printed, nor a percentage or a complement from which one could be recovered,
nor an order statistic held by fewer than {it:m} observations:

{phang2}o every count in a gate message and in {cmd:observed} prints as
{bf:<}{it:m}: {cmd:rule(entry_exit): <5 obs fail}. {opt isid()} reports only the masked number of
duplicated rows, never the row and distinct-key counts, whose difference would
be the small cell. A gate count whose complement in its scope is small prints
as {bf:all but <}{it:m}, as do the {opt stat()} values {cmd:n}, {cmd:distinct}, and {cmd:sum} and the
{bf:sets(values)} count; {opt stat()} {cmd:pmiss} prints as {bf:.} when either the missing or the
nonmissing count is small. A {opt stat()} {cmd:sum}, which is a value of its rows and not
only a count, prints as {bf:[suppressed]} when its nonmissing rows, its nonzero
rows, or, for a variable with two values, the rows of either value number 1 to
{it:m}-1. In a {opt by()} group whose size is withheld, every count of {it:m} or more prints
as {bf:[suppressed]} too, since it bounds the group's size. {cmd:r(n_violations)} counts
gates, not persons, and is not masked.{p_end}
{phang2}o the MISSINGNESS and GROUPWISE blocks print a small missing count as {bf:<}{it:m} and
its percentage as {bf:[masked]}; a count whose complement is small prints as
{bf:all but <}{it:m}, while a zero count prints as {bf:0}; a {opt by()} group smaller than {it:m} is not
shown and is counted in one line,
{cmd:groups pooled (each <5 rows, or pooled with them): 2}. The counts a {opt by()}
profile prints per group are protected together; see
{it:Linked counts in a by() profile} below. The {bf:Unique} column, a string's {bf:unique=}
and a categorical variable's level count print as {bf:[masked]} when N, or the
nonmissing N, minus that count is 1 to {it:m}-1.{p_end}
{phang2}o  a {opt stat()} {cmd:sum} prints as {bf:[suppressed]} when the call
also prints the {cmd:mean} of the same variable (or expression text) over the
same scope (the same {cmd:if}, and with {opt by()} the same group, also from a
{opt groupstat()} {cmd:mean} over the call's {opt by()}) and the scope's
missing count is 1 to {it:m}-1, since {cmd:sum}/{cmd:mean} would give back
the nonmissing count that {cmd:stat(n)} withholds; a {cmd:sum} of 0 stays; in a
{opt by()} group whose size is withheld it follows the rule for {cmd:n}. Without
{opt by()}, a {opt stat()} {cmd:mean} prints as {bf:[suppressed]} when the call
also prints a {opt groupstat()} {cmd:sum} of the same variable over the same
{cmd:if} (its groups add up to the sum) and the missing count is 1 to
{it:m}-1; a {cmd:mean} of 0 stays.{p_end}
{phang2}o  no minimum or maximum is printed. The continuous and date profiles and
{opt inrange()} messages show p1 and p99, dates at month precision, and any
percentile, mean, or {opt stat()} value is shown only when at least {it:m}
nonmissing observations lie at or below it and at or above it; otherwise it
prints as {bf:[suppressed]}. An {cmd:sd} is shown only with at least {it:m}
nonmissing observations and, for a variable with two or three values, at least {it:m}
of each (an {cmd:sd} beside N gives back the share of a 0/1 flag, and with
the mean the three counts of a three-valued variable); a
{cmd:ratio} only when at least {it:m} rows of {it:var}/{it:den} lie at or below
it and at or above it; an {cmd:ess} only with at least {it:m} contributing rows
and when the nonzero and the zero weights each number 0 or at least {it:m} (the
{cmd:ess} of a 0/1 weight is the count of ones). The median records per key in
KEY STRUCTURE follows the same rule over the keys.{p_end}
{phang2}o  the {opt patterns} table is masked by {help datamvp}.{p_end}

{pstd}
{opt diff()}, {opt compare()}, and the {opt keyset()} preflight follow the same
rule; see {help dataprobe##snapdiff:Snapshot and diff} and
{help dataprobe##keyset:Keyset preflight}.

{pstd}
{opt reconcile()} prints a count, the file's count and their difference as one
triple: when any of them is 1 to {it:m}-1, every nonzero member prints as {bf:<}{it:m} or
{bf:[suppressed]} and the difference as its direction only
({cmd:rows: memory [suppressed], ck [suppressed]; fewer in memory}). A total of
{cmd:sum()} is a value of its rows, so under the mask the totals are not printed,
only their relative difference (the ledger's {cmd:observed_num} for that row is
missing), which prints as {bf:[suppressed]} when the row or id difference, or
either side's row count, is 1 to {it:m}-1. A {cmd:by()} group with 1 to {it:m}-1 rows on
either side is not named but counted in one line. Under the mask a count of
failing groups is masked as a {opt byrule()} count is, and when the count of
unnamed groups is masked the count of failing groups is withheld with it,
since the named lines give back their difference. When any group's
difference in a measure is withheld, every group line prints that measure's
direction only, since the group differences add up to the overall one. When a
{cmd:by()} variable is in {opt exclude()}, and under {opt safe}, a failing group is named by its
number ({bf:group 3}), as {opt smallcells()} names a stratum.

{pstd}
{bf:Linked counts in a by() profile.} A profile with {opt by()} prints many
counts per group that are tied to one another and to totals printed
elsewhere, so a count withheld in one place could be recalculated from the
others (Hundepool et al. 2026, sec. 4.2.2 and 5.3: secondary suppression for
linked tables). The relations an attacker can use within one output are: group
sizes sum to N; a quantity's group counts and the pooled groups' count
sum to its total (a variable's missing count in MISSINGNESS, Miss% and the
continuous N; complete cases in the header; a level's count in the pooled
frequency table; the rows outside a date window in DATE); a group's levels
and missing values sum to its size ({opt byfreq}); its complete count is N
minus its incomplete rows, which lie between its largest missing count and
their sum, equal one variable's missing count when MissVars is 1, and are 0
when it is 0 (an absent GROUPWISE MISSINGNESS row is a zero); a value-domain,
{opt binary()} or 0/1 {cmd:sum} count is a sum of level counts; the per-group
gate counts of {opt notmissing()}, {opt complete()}, {opt stat()} {cmd:n},
{cmd:pmiss} and {cmd:sum}, {opt binary()}, {opt inrange()} on a profiled date,
{opt allowed()}, {opt forbid()}, {opt notvalues()} and the {opt groupstat()}
{cmd:n} and 0/1 {cmd:sum} cells with the call's {opt by()} repeat these
quantities; a {opt review()} condition's per-group counts sum to its total,
which the check takes as printed (it may equal a level's count); a frequency
table's row order bounds a withheld row by its neighbours; and a zero-test
gate's verdict says whether its count is 0.

{pstd}
Guarantee: no group count from 1 to {it:m}-1, and no group count whose
complement in its group is 1 to {it:m}-1, can be determined exactly from
these relations, and neither can the pooled groups' total of any of these
quantities. A count printed {bf:<}{it:m} or {bf:all but <}{it:m} therefore keeps
at least two possible values. {cmd:dataprobe} first withholds, as
{bf:[suppr.]} (a frequency-table row: {bf:[suppressed]}), the smallest exact
count whose total minus the exactly printed counts would be 1 to {it:m}-1, as
before. It then checks every such count against all the relations together: it
looks for another table of counts that prints the same output with that
count changed (one unit moved between two values in a group and taken back
elsewhere, a missing unit traded between two variables, an incomplete row
moved), and failing that computes the count's feasibility interval by linear
programming. A group with a count that keeps a single value joins the pooled
groups ({cmd:groups pooled (each <5 rows, or pooled with them)}): its size and
counts are no longer printed in any block or in {opt groupstat()} with the
call's {opt by()}, and the check is repeated. In a pooled group's gate lines a
linked count prints as {bf:0} or, when nonzero, {bf:[suppressed]}. {bf:[suppr.]}
stands for a count that would otherwise print exactly: 0, the group size, or
{it:m} to the group size minus {it:m}. Output without {opt maskrare} is
unchanged.

{pstd}
Not covered: a count read across two calls (differencing two outputs); the
verdict of a band gate ({opt stat()} bounds, {opt complete()} {cmd:min()}, {opt expectn()}), which
says whether a count lies in a band the user chose; counts of user expressions
({opt rule()}, {opt byrule()}, {opt regex()}, {opt events()}, {opt isid()}, {opt nodups}), and of {opt review()} beyond
its own total, set against other counts; statistics (means, SDs, percentiles,
sums of variables other than 0/1), which follow the rules above; the {opt patterns}
table's pattern totals; {opt groupstat()} over another {opt by()} or with its own
{cmd:if}; counts of rows missing two variables at once, which are not printed; the
pooled blocks' own totals, masked by their own rules; and inference from how
the withheld counts were chosen. The interval is computed for outputs with up
to 700 unknown counts and 40 programs per call; beyond that a count without
another table of counts is protected by pooling its group.

{pstd}
The search for another table of counts and the linear programs share one
budget per call, across every repeat of the check: 4,000,000 tries. Re-ranking
a frequency table of {it:L} levels counts {it:L}/512 tries more,
and each linear program counts the cube of its size (unknowns plus
constraints) over 6,000, about 800,000 tries for a program that takes 15
seconds. When the budget runs out before every count is shown safe, an
unresolved count may be a disclosure, and pooling only some groups could not
be checked again, so every group is pooled: no group's size or audited count
prints, a note under the header says so, and {cmd:r(linkaudit_capped)} is 1
(it is 0 when the check finishes, and posted only when the check runs: {opt by()}
and {opt maskrare} without {opt gatesonly}). This
happens on outputs with many small groups and many linked counts
(thousands of rows in 40 groups with {opt byfreq} and several gates), with
a {opt byfreq} variable whose levels are mostly single rows (an identifier
string such as {cmd:make} in {cmd:auto}), or with {opt byfreq} tables whose
small cells link a small group to large ones ({cmd:nlsw88} {cmd:by(race)}
{cmd:byfreq}, which 1.10.5 printed after more than three minutes); fewer
{opt byfreq} variables,
leaving identifiers and other high-cardinality strings out of {opt byfreq}, or
no {opt maskrare} avoid it. The budget counts work, not time, so the same data
and call always give the same output.

{pstd}
Every PASS line and violation heading ends with the active masking, such as
{bf:[masked <5]}. {cmd:r(masked)} is 1 when any printed count was masked,
a suppressed frequency-table cell included, and it has the same value under
{cmd:quietly}. {opt saving()} and {opt makespec()} still write observed
minima and maxima (under {opt safe}, {opt saving()} is masked and
{opt makespec()} is refused). Stored results are not masked: {cmd:r()} and a
{opt snapshot()} frame hold the exact values, and {cmd:r()} is not written to
the log unless displayed.


{marker examples}{...}
{title:Examples}

{pstd}Descriptive profile of the data in memory:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe}{p_end}

{pstd}Gate a dataset before an analysis (halts the do-file on any violation):{p_end}
{phang2}{cmd:. dataprobe, gatesonly expectn(74) isid(make) notmissing(price mpg) inrange(price weight 0 . \ mpg 10 50)}{p_end}

{pstd}A range gate that fails says how many rows lie below and above the range ({opt warn} reports it without halting):{p_end}
{phang2}{cmd:. dataprobe, gatesonly inrange(mpg 15 30) warn}{p_end}
{phang2}{cmd:. display r(inrange_n_below) " below, " r(inrange_n_above) " above"}{p_end}

{pstd}Invariants and sanity bands in one call; bands warn under {opt bandwarn}:{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) rule("heavy": weight > 1500) bands(expectn(70 80) stat(mean mpg 18 25 \ median price 4000 6000)) bandwarn maskrare}{p_end}

{pstd}Rates, sums, and distinct counts, each with its own condition:{p_end}
{phang2}{cmd:. dataprobe, gatesonly stat(sum foreign 22 22 \ distinct rep78 5 5 \ mean mpg 20 30 if foreign)}{p_end}

{pstd}The tail percentiles {cmd:p1}, {cmd:p5}, {cmd:p95} and {cmd:p99} (with
{cmd:p10} {cmd:p25} {cmd:p50} {cmd:p75} {cmd:p90}, the set {cmd:summarize, detail}
reports) work in {opt stat()} and {opt groupstat()}:{p_end}
{phang2}{cmd:. dataprobe, gatesonly stat(p5 price 3000 4000 \ p95 price 12000 15000)}{p_end}

{pstd}Rules within groups, with the data left in its order:{p_end}
{phang2}{cmd:. dataprobe, gatesonly byrule(make (price): "order": _n >= 1)}{p_end}

{pstd}Gate a results table before release: no count or difference of 1 to 4 on rows not suppressed:{p_end}
{phang2}{cmd:. preserve}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set obs 4}{p_end}
{phang2}{cmd:. generate n1 = 40 + 10*_n}{p_end}
{phang2}{cmd:. generate e1 = 12 + _n}{p_end}
{phang2}{cmd:. generate n0 = 50 + 10*_n}{p_end}
{phang2}{cmd:. generate e0 = 14 + _n}{p_end}
{phang2}{cmd:. generate byte suppressed = 0}{p_end}
{phang2}{cmd:. dataprobe, gatesonly mincell(5) smallcells(n1 e1 n1-e1 n0 e0 n0-e0 if !suppressed)}{p_end}
{phang2}{cmd:. restore}{p_end}

{pstd}Audit the cells of a planned table on the microdata, in rows and persons,
with its margins ({opt warn} reports without halting):{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. generate pid = ceil(_n/2)}{p_end}
{phang2}{cmd:. dataprobe, gatesonly mincell(5) smallcells(rep78==3 rep78==4 rep78==5, id(pid) by(foreign) margins) warn}{p_end}

{pstd}List the frequent levels of a variable in place of {cmd:tabulate} or
{cmd:levelsof}, which print every rare value as well:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, topvalues(rep78 \ make, max(10))}{p_end}
{phang2}{cmd:. generate pid = ceil(_n/2)}{p_end}
{phang2}{cmd:. dataprobe, topvalues(rep78, id(pid))}{p_end}
{phang2}{cmd:. matrix list r(topvalues)}{p_end}

{pstd}Review items that print and never halt:{p_end}
{phang2}{cmd:. dataprobe, gatesonly review("cheap": price < 4000) complete(rep78 mpg) groupstat(mean price mpg, by(foreign))}{p_end}
{phang2}{cmd:. dataprobe, gatesonly groupstat(n mean sd median: price, by(foreign))}{p_end}
{phang2}{cmd:. dataprobe, gatesonly groupstat(n mean sd p5 p25 median p75 p95: price mpg, by(foreign))}{p_end}
{phang2}{cmd:. dataprobe, gatesonly stat(mean (rep78 >= 4) 0.2 0.6 \ sum (price > 10000 & foreign == 0) 0 20)}{p_end}
{phang2}{cmd:. dataprobe, gatesonly byrule(foreign: "spread": spread(mpg) <= 30 \ foreign: "known": count(rep78) >= 10)}{p_end}

{pstd}Record the result in a ledger, with a stated dataset name:{p_end}
{phang2}{cmd:. tempfile ledger}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) name(auto_cars) ledger("`ledger'", run(demo))}{p_end}

{pstd}Tag a call's ledger rows with its phase:{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) name(auto_cars) ledger("`ledger'", run(demo)) phase(analysis)}{p_end}

{pstd}Continue past a call that fails to run; the error row makes {cmd:dataqa assert} halt later:{p_end}
{phang2}{cmd:. dataprobe, gatesonly notmissing(no_such_var) ledger("`ledger'", run(demo)) softcollect}{p_end}
{phang2}{cmd:. display r(softfail) " " r(softfail_rc)}{p_end}

{pstd}Require a minimum installed version; a nonzero return code means reinstall:{p_end}
{phang2}{cmd:. capture dataprobe, minversion(1.8.0)}{p_end}

{pstd}Keep the profile, change the data, and see what moved:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly snapshot(before) id(make)}{p_end}
{phang2}{cmd:. drop if rep78 == .}{p_end}
{phang2}{cmd:. dataprobe, gatesonly diff(before) tol(1e-6 2)}{p_end}

{pstd}Compare with a saved profile, a file or a frame:{p_end}
{phang2}{cmd:. dataprobe, gatesonly saving(auto_profile.dta, replace)}{p_end}
{phang2}{cmd:. dataprobe, gatesonly compare(auto_profile.dta)}{p_end}

{pstd}Delivered-file coverage of a YYYYMMDD number, split by side, with a drop-off check:{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set obs 3650}{p_end}
{phang2}{cmd:. generate double dt = mdy(1, 1, 2014) + _n - 1}{p_end}
{phang2}{cmd:. generate long ymd = real(string(dt, "%tdCCYYNNDD"))}{p_end}
{phang2}{cmd:. dataprobe, gatesonly coverage(ymd 20140101 20231231, gap(30) unit(yyyymmdd) sides years dropoff(50))}{p_end}

{pstd}Check the keys against a file before a merge:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. keep make price}{p_end}
{phang2}{cmd:. save auto_ids, replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. drop in 1/5}{p_end}
{phang2}{cmd:. dataprobe, gatesonly keyset(make using auto_ids) warn}{p_end}

{pstd}Link by key and date: the latest visit on or before an index date, and the visits inside a window:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. keep make}{p_end}
{phang2}{cmd:. expand 3}{p_end}
{phang2}{cmd:. bysort make: generate visit = mdy(1, 1, 2020) + 30 * _n}{p_end}
{phang2}{cmd:. save auto_visits, replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. generate index = mdy(2, 15, 2020)}{p_end}
{phang2}{cmd:. generate start = index - 45}{p_end}
{phang2}{cmd:. dataprobe, gatesonly keyset(make using auto_visits, asof(index visit) maxlag(60) maxties(0))}{p_end}
{phang2}{cmd:. dataprobe, gatesonly keyset(make using auto_visits, window(start index visit) maxmulti(0.5))}{p_end}

{pstd}Conserve rows, cars and a total across an exclusion step:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. save auto_ckpt, replace}{p_end}
{phang2}{cmd:. drop if missing(rep78)}{p_end}
{phang2}{cmd:. dataprobe, gatesonly reconcile(auto_ckpt, n ids(make) sum(price) by(foreign) expect(le))}{p_end}

{pstd}Write the starter gates as a do-file, then run it:{p_end}
{phang2}{cmd:. dataprobe, gatesonly makespec(auto_gates.do, replace)}{p_end}
{phang2}{cmd:. do auto_gates.do}{p_end}

{pstd}One line per variable, or the agent-safe preset:{p_end}
{phang2}{cmd:. dataprobe, brief}{p_end}
{phang2}{cmd:. dataprobe, safe brief}{p_end}

{pstd}Show only flagged variables and mask rare cells before sharing a log:{p_end}
{phang2}{cmd:. dataprobe, rare(5) mincell(5) maskrare show(flagged)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:dataprobe} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations after {cmd:if}/{cmd:in}{p_end}
{synopt:{cmd:r(complete_cases)}}complete observations (profile only){p_end}
{synopt:{cmd:r(complete_pct)}}percent complete (profile only){p_end}
{synopt:{cmd:r(n_checks)}}gate families evaluated (review items excluded){p_end}
{synopt:{cmd:r(n_passed)}}gate families without violations{p_end}
{synopt:{cmd:r(n_failed)}}gate families with a failure or warning{p_end}
{synopt:{cmd:r(n_violations)}}failed or warned gate entries{p_end}
{synopt:{cmd:r(n_errors)}}halting gate entries{p_end}
{synopt:{cmd:r(n_warnings)}}warned gate entries{p_end}
{synopt:{cmd:r(n_reviews)}}review items printed{p_end}
{synopt:{cmd:r(n_groups)}}number of {opt by()} or {opt over()} groups{p_end}
{synopt:{cmd:r(gatesonly)}}1 when {opt gatesonly} was specified{p_end}
{synopt:{cmd:r(onlyflagged)}}1 with {opt onlyflagged} or {cmd:show(flagged)}{p_end}
{synopt:{cmd:r(mincell)}}{opt mincell()} as given or defaulted{p_end}
{synopt:{cmd:r(maskrare)}}1 when {opt maskrare} was in effect{p_end}
{synopt:{cmd:r(safe)}}1 when {opt safe} was in effect{p_end}
{synopt:{cmd:r(masked)}}1 when any printed count was masked{p_end}
{synopt:{cmd:r(linkaudit_capped)}}1 if the linked-count check ran out of budget{p_end}
{synopt:{cmd:r(n_continuous)}}continuous variables (profile only){p_end}
{synopt:{cmd:r(n_categorical)}}categorical variables (profile only){p_end}
{synopt:{cmd:r(n_date)}}date variables (profile only){p_end}
{synopt:{cmd:r(n_string)}}string variables (profile only){p_end}
{synopt:{cmd:r(n_excluded)}}excluded variables (profile only){p_end}
{synopt:{cmd:r(n_flagged)}}flagged variables (profile only){p_end}
{synopt:{cmd:r(n_constant)}}constant variables (profile only){p_end}
{synopt:{cmd:r(n_highcard)}}high-cardinality variables (profile only){p_end}
{synopt:{cmd:r(n_missing_vars)}}variables with missing values (profile only){p_end}
{synopt:{cmd:r(n_outlier_vars)}}variables with outlier flags (profile only){p_end}
{synopt:{cmd:r(n_rare_vars)}}variables with rare-level flags (profile only){p_end}
{synopt:{cmd:r(n_singlelevel)}}vars with one nonmissing level (profile only){p_end}
{synopt:{cmd:r(n_group_missing_vars)}}vars missing in a group (not under {opt gatesonly}){p_end}
{synopt:{cmd:r(compare_added)}}variables added relative to {opt compare()}{p_end}
{synopt:{cmd:r(compare_dropped)}}variables dropped relative to {opt compare()}{p_end}
{synopt:{cmd:r(compare_type_changed)}}variables with changed storage type{p_end}
{synopt:{cmd:r(compare_class_changed)}}variables with changed classification{p_end}
{synopt:{cmd:r(compare_changed)}}schema-drift count, including any N delta{p_end}
{synopt:{cmd:r(keyset_only_master)}}keys in memory absent from the {opt keyset()} file{p_end}
{synopt:{cmd:r(keyset_only_using)}}keys of the {opt keyset()} file absent from memory{p_end}
{synopt:{cmd:r(keyset_matched)}}keys present on both sides{p_end}
{synopt:{cmd:r(keyset_link_none)}}{cmd:asof()}/{cmd:window()} rows with no file row{p_end}
{synopt:{cmd:r(keyset_link_one)}}rows with exactly one{p_end}
{synopt:{cmd:r(keyset_link_more)}}rows with more than one{p_end}
{synopt:{cmd:r(keyset_link_ties)}}{cmd:asof()} rows whose latest file date is tied{p_end}
{synopt:{cmd:r(keyset_link_stale)}}{cmd:asof()} rows older than {cmd:maxlag()}{p_end}
{synopt:{cmd:r(keyset_link_pairs)}}{cmd:window()} pairs inside the window{p_end}
{synopt:{cmd:r(keyset_link_joinby)}}pairs {helpb joinby} on the key would create{p_end}
{synopt:{cmd:r(reconcile_rows_delta)}}{opt reconcile()} rows, memory minus file{p_end}
{synopt:{cmd:r(reconcile_ids_delta)}}the same for distinct {cmd:ids()}{p_end}
{synopt:{cmd:r(inrange_n_below)}}{opt inrange()} rows below {it:lo}; missing if masked{p_end}
{synopt:{cmd:r(inrange_n_above)}}{opt inrange()} rows above {it:hi}; missing if masked{p_end}
{synopt:{cmd:r(coverage_outside_low)}}dates before {it:lo}; {opt coverage()} with {cmd:sides}{p_end}
{synopt:{cmd:r(coverage_outside_high)}}dates after {it:hi}; {opt coverage()} with {cmd:sides}{p_end}
{synopt:{cmd:r(diff_n_lines)}}variable lines the {opt diff()} block printed{p_end}
{synopt:{cmd:r(diff_base_N)}}observations of the baseline{p_end}
{synopt:{cmd:r(diff_n_delta)}}current N minus baseline N{p_end}
{synopt:{cmd:r(diff_key_before)}}key unique before: 1, 0, or missing{p_end}
{synopt:{cmd:r(diff_key_after)}}the same after (missing if not checked){p_end}
{synopt:{cmd:r(diff_key_surplus)}}rows beyond one per key after{p_end}
{synopt:{cmd:r(diff_schema_only)}}1 when the baseline held no profile statistics{p_end}
{synopt:{cmd:r(diff_added)}}variables added{p_end}
{synopt:{cmd:r(diff_dropped)}}variables dropped{p_end}
{synopt:{cmd:r(diff_type_changed)}}variables with a changed storage type{p_end}
{synopt:{cmd:r(diff_changed)}}variables with any change{p_end}
{synopt:{cmd:r(diff_tol)}}the relative tolerance used{p_end}
{synopt:{cmd:r(diff_ctol)}}the absolute count tolerance used{p_end}
{synopt:{cmd:r(ledger_seq)}}call number within the run, with {opt ledger()}{p_end}
{synopt:{cmd:r(softfail)}}{opt softcollect}: 1 if the call failed, else 0{p_end}
{synopt:{cmd:r(softfail_rc)}}{opt softcollect}: rc of the failed call{p_end}
{synopt:{cmd:r(n_dup_}{it:key}{cmd:)}}keys with >1 record per {opt id()} key (profile only){p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(version)}}installed datamap version{p_end}
{synopt:{cmd:r(dataset)}}dataset name used in the verdict{p_end}
{synopt:{cmd:r(checks_run)}}gate families evaluated{p_end}
{synopt:{cmd:r(violations)}}family of each failed or warned entry{p_end}
{synopt:{cmd:r(failed_checks)}}unique families with a failure or warning{p_end}
{synopt:{cmd:r(signature)}}{help datasignature}, with {opt signature}{p_end}
{synopt:{cmd:r(ledger)}}ledger file, with {opt ledger()}{p_end}
{synopt:{cmd:r(continuous_vars)}}continuous variables (profile only){p_end}
{synopt:{cmd:r(categorical_vars)}}categorical variables (profile only){p_end}
{synopt:{cmd:r(date_vars)}}date variables (profile only){p_end}
{synopt:{cmd:r(string_vars)}}string variables (profile only){p_end}
{synopt:{cmd:r(excluded_vars)}}excluded variables (profile only){p_end}
{synopt:{cmd:r(flagged_vars)}}flagged variables (profile only){p_end}
{synopt:{cmd:r(constant_vars)}}constant variables (profile only){p_end}
{synopt:{cmd:r(singlelevel_vars)}}vars with one nonmissing value (profile only){p_end}
{synopt:{cmd:r(highcard_vars)}}high-cardinality variables (profile only){p_end}
{synopt:{cmd:r(missing_vars)}}variables with missing values (profile only){p_end}
{synopt:{cmd:r(outlier_vars)}}variables with outlier flags (profile only){p_end}
{synopt:{cmd:r(rare_vars)}}variables with rare-level flags (profile only){p_end}
{synopt:{cmd:r(group_missing_vars)}}vars missing in a group (not under {opt gatesonly}){p_end}
{synopt:{cmd:r(compare_added_vars)}}variables added relative to {opt compare()}{p_end}
{synopt:{cmd:r(compare_dropped_vars)}}variables dropped relative to {opt compare()}{p_end}
{synopt:{cmd:r(compare_type_changed_vars)}}variables whose storage type changed{p_end}
{synopt:{cmd:r(compare_class_changed_vars)}}variables whose class changed{p_end}
{synopt:{cmd:r(keyset_merge)}}merge type the {opt keyset()} preflight implies{p_end}
{synopt:{cmd:r(snapshot)}}the frame {opt snapshot()} wrote{p_end}
{synopt:{cmd:r(snapshot_key)}}the key the snapshot recorded{p_end}
{synopt:{cmd:r(diff_baseline)}}the baseline {opt diff()} read{p_end}
{synopt:{cmd:r(diff_key)}}the key {opt diff()} used{p_end}
{synopt:{cmd:r(diff_added_vars)}}variables added since the baseline{p_end}
{synopt:{cmd:r(diff_dropped_vars)}}variables dropped since the baseline{p_end}
{synopt:{cmd:r(diff_type_changed_vars)}}variables whose storage type changed{p_end}
{synopt:{cmd:r(diff_class_changed_vars)}}variables whose class changed{p_end}
{synopt:{cmd:r(diff_missing_changed_vars)}}variables whose missing count changed{p_end}
{synopt:{cmd:r(diff_unique_changed_vars)}}variables whose distinct count changed{p_end}
{synopt:{cmd:r(diff_stat_changed_vars)}}variables whose mean or range changed{p_end}
{synopt:{cmd:r(diff_changed_vars)}}every variable with a change{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(topvalues)}}what {opt topvalues()} printed, a row per variable{p_end}
{p2colreset}{...}

{pstd}
{cmd:r(topvalues)} has one row per {opt topvalues()} variable, named by the
variable, and the columns {cmd:N} (rows), {cmd:N_id} (ids, with {opt id()}),
{cmd:levels}, {cmd:shown} (levels listed), {cmd:suppressed} ({it:k}),
{cmd:resid} and {cmd:resid_id} (the pooled line's rows and ids). Each holds
the number printed, and is missing where the block withheld it or does not
apply, so no count the block withholds is stored.

{pstd}
"Profile only" results are not set on the {opt gatesonly} fast path, which
does no classification. Use {opt warn} or {opt bandwarn} when execution must
continue after violations so that later code can read the results.


{marker references}{...}
{title:References}

{phang}
Hundepool, A., J. Domingo-Ferrer, L. Franconi, S. Giessing, R. Lenz,
J. Naylor, E. Schulte Nordholt, G. Seri, P.-P. de Wolf, R. Tent, A. Młodak,
J. Gussenbauer, and
K. Wilak. 2026. {it:Handbook on Statistical Disclosure Control}. 2nd ed. Center of
Excellence SDC. {p_end}

{phang}
Kish, L. 1965. {it:Survey Sampling}. New York: Wiley. {p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}


{title:Also see}

{psee}
{help dataqa}, {help datamap}, {help datamvp}, {manlink D codebook}, {manlink D assert}
{p_end}

{hline}

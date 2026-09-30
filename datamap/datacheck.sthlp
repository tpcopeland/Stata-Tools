{smcl}
{* *! datacheck (version recorded in datamap.sthlp)}{...}
{vieweralsosee "datamap" "help datamap"}{...}
{vieweralsosee "dataqa" "help dataqa"}{...}
{vieweralsosee "datadict" "help datadict"}{...}
{vieweralsosee "datamvp" "help datamvp"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{vieweralsosee "[D] isid" "help isid"}{...}
{vieweralsosee "[D] duplicates" "help duplicates"}{...}
{viewerjumpto "Syntax" "datacheck##syntax"}{...}
{viewerjumpto "Description" "datacheck##description"}{...}
{viewerjumpto "Options" "datacheck##options"}{...}
{viewerjumpto "Gate mode" "datacheck##gate"}{...}
{viewerjumpto "Invariants, bands, and review items" "datacheck##kinds"}{...}
{viewerjumpto "Masking" "datacheck##masking"}{...}
{viewerjumpto "Examples" "datacheck##examples"}{...}
{viewerjumpto "Stored results" "datacheck##results"}{...}
{viewerjumpto "References" "datacheck##references"}{...}
{viewerjumpto "Author" "datacheck##author"}{...}

{title:Title}

{phang}
{bf:datacheck} {hline 2} Console QC profiling and expectation gates for a dataset


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datacheck}
[{varlist}]
[{cmd:if}]
[{cmd:in}]
[{cmd:,}
{it:options}]

{p 8 17 2}
{cmd:datacheck}{cmd:,} {opt minver:sion(#)}

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
{synopt:{opt rare(#)}}flag levels with count below {it:#}{p_end}
{synopt:{opt min:cell(#)}}flag tabulated cells below {it:#}{p_end}
{synopt:{opt mask:rare}}mask counts below the threshold{p_end}
{synopt:{opt out:liers(#)}}flag values beyond {it:#} IQRs{p_end}

{syntab:Missingness}
{synopt:{opt nomiss:ing}}suppress the missingness summary block{p_end}
{synopt:{opt patterns}}add the {help datamvp} pattern table{p_end}

{syntab:Invariant gates {it:(any gate option turns on gate mode)}}
{synopt:{opt gates:only}}run validation gates only{p_end}
{synopt:{opt expectn(numlist)}}require exact {cmd:_N} or a range{p_end}
{synopt:{opt isid(varlist)}}assert the dataset is unique by this key{p_end}
{synopt:{opt nodups}}assert no fully duplicated rows{p_end}
{synopt:{opt req:uire(varlist)}}assert these variables exist{p_end}
{synopt:{opt notmiss:ing(varlist)}}require complete values{p_end}
{synopt:{opt inrange(spec)}}require ranges; {cmd:\}-separate{p_end}
{synopt:{opt all:owed(spec)}}restrict to allowed values{p_end}
{synopt:{opt for:bid(spec)}}reject forbidden values{p_end}
{synopt:{opt regex(spec)}}require strings to match regexes{p_end}
{synopt:{opt notv:alues(spec)}}reject sentinel or disallowed values{p_end}
{synopt:{opt rule(spec)}}require labelled row-level rules to hold{p_end}
{synopt:{opt stat(spec)}}require a statistic inside a band{p_end}
{synopt:{opt bin:ary(varlist)}}require 0/1 flags with both levels{p_end}
{synopt:{opt events(spec)}}require events at every covariate level{p_end}
{synopt:{opt intervals(spec)}}check interval-file structure{p_end}
{synopt:{opt keyset(spec)}}require the keys of a saved dataset{p_end}
{synopt:{opt constant(spec)}}require time-fixed values within a key{p_end}
{synopt:{opt sets(spec)}}check matched-set structure{p_end}

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
{synopt:{opt makes:pec(filename[, replace])}}write a starter checks file{p_end}
{synopt:{opt comp:are(filename)}}compare with a saved schema{p_end}
{synopt:{opt warn}}report every gate failure as a warning{p_end}
{synopt:{opt minver:sion(#)}}require at least this datamap version{p_end}

{syntab:Output}
{synopt:{opt sav:ing(name[, replace])}}save profile to {opt .dta}/frame{p_end}
{synopt:{opt only:flagged}}show only flagged variables/groups{p_end}
{synopt:{opt show(flagged)}}same as {opt onlyflagged}{p_end}
{synopt:{opt viol:ations(name[, replace])}}save violations to {opt .dta}/frame{p_end}
{synopt:{opt ledger(filename[, run()])}}append every gate result to a ledger{p_end}
{synopt:{opt sig:nature}}record the dataset's {help datasignature}{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:datacheck} interrogates a dataset in the console and optionally gates on
declared expectations. It is the interactive sibling of {help datamap} (which
{it:documents} a dataset to a file) and {help datadict} (which {it:publishes} a
Markdown dictionary). All three commands share one classification engine, so a
variable is classified the same way no matter which command looks at it.

{pstd}
With no options, {cmd:datacheck} auto-classifies every variable and prints a
quick-reference table, a per-class profile (distributions for continuous,
frequency tables for categorical and string, ranges for date), a missingness
summary, and {hline 1} when an identifier-like variable is detected {hline 1} a key-structure
report. No gate runs unless a gate option is given.

{pstd}
With one or more gate options, {cmd:datacheck} evaluates {it:every} gate, accumulates all
violations, prints them as a single block, and only then exits. On any
violation it exits with return code {bf:9} (Stata's assertion code), so a do-file
stops exactly as a bare {help assert} would. See {help datacheck##gate:Gate mode}.

{pstd}
Every gate entry, passed or failed, and every review item is one record. The
console verdict, {opt violations()}, the stored results, and the
{opt ledger()} are all read from those records, so they cannot disagree. {help dataqa}
reads the ledger to draft the QA register, assert that every
expected dataset was checked, compare runs, and export a release copy.

{pstd}
The data in memory is always preserved and restored; {cmd:datacheck} never
modifies the user's data.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{opt sing:le(filename)} profiles a saved {opt .dta} file instead of the data in
memory. The in-memory data is preserved and restored. The {opt .dta}
extension is optional.

{phang}
{opt conf:ig(filename)} reads reusable defaults from a text file containing
{cmd:key = value} or {cmd:key: value} lines. Supported keys include
{cmd:exclude}, {cmd:continuous}, {cmd:categorical}, {cmd:datevars},
{cmd:maxcat}, {cmd:maxfreq}, {cmd:rare}, {cmd:mincell}, {cmd:outliers},
{cmd:maskrare}, {cmd:nomissing}, {cmd:patterns}, {cmd:gatesonly},
{cmd:onlyflagged}, and {cmd:show}. Command-line options override session
defaults set by {help dataqa:dataqa set}, which override config-file defaults.

{phang}
{opt name(string)} names the dataset in the verdict and the ledger. By default
the name is the basename of {cmd:c(filename)}, followed by {bf:(modified)} when
the data changed since they were last saved; data never saved have no name. Use
{opt name()} for a dataset restricted after loading, for example
{cmd:name(repop_intervals, repletion sample)}.

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
{opt patterns} table.

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
{opt rare(#)} flags categorical levels whose count falls below {it:#}.

{phang}
{opt min:cell(#)} suppresses tabulated frequency cells with a count below
{it:#} and sets the masking threshold for {opt maskrare}.

{phang}
{opt mask:rare} masks small counts everywhere the command prints one. The
threshold {it:m} is {opt mincell(#)} when specified; otherwise {opt rare(#)}; otherwise
5. See {help datacheck##masking:Masking}. An explicit
{cmd:nomaskrare} overrides a session default {opt maskrare} and prints a note
saying so.

{phang}
{opt out:liers(#)} flags continuous values lying more than {it:#} interquartile
ranges beyond the first or third quartile. The default of 0 disables the check.

{dlgtab:Missingness}

{phang}
{opt nomiss:ing} suppresses the missingness summary block.

{phang}
{opt patterns} adds the missing-value pattern table from {help datamvp}. Under
{opt maskrare} the table is masked as well: {cmd:datacheck} passes
{opt maskrare} and {opt mincell()} to {cmd:datamvp}, which pools patterns
below the threshold.

{dlgtab:Invariant gates}

{phang}
{opt gates:only} suppresses the descriptive profile and runs only the
requested gates and review items. Without {opt compare()}, {opt saving()}, or
{opt makespec()}, {cmd:datacheck} then skips classification and the profile
entirely and keeps only the columns the gates name, so a gate call on a wide
file costs about what the gates themselves cost. The profile stored results
({cmd:r(n_continuous)}, {cmd:r(singlelevel_vars)}, {cmd:r(complete_cases)}, and
the rest of that family) are not set in that case, and
{cmd:r(group_missing_vars)} and {cmd:r(n_group_missing_vars)} are not set under
any {opt gatesonly}.

{phang}
{opt expectn(numlist)} asserts the number of observations. One number is an
exact expectation ({cmd:expectn(282252)}); two numbers are an inclusive range
({cmd:expectn(1000 1200)}).

{phang}
{opt isid(varlist)} asserts that the dataset is unique by the named key. A
row with a missing key value counts as a duplicate.

{phang}
{opt nodups} asserts that no fully duplicated rows exist.

{phang}
{opt req:uire(varlist)} asserts that the named variables exist in the dataset.

{phang}
{opt notmiss:ing(varlist)} asserts that the named variables have no missing
values.

{phang}
{opt inrange(spec)} asserts that variables fall within declared ranges. Each
{cmd:\}-separated entry is {it:var} [{it:var ...}] {it:lo hi}: every token but
the last two is a variable, so one bound pair can cover several variables, as
in {cmd:inrange(dob entry exit td(01jan1900) td(31dec2025) \ age 18 110)}. Bounds
may be numbers, date literals such as {cmd:td(01jan2010)}, or date
strings such as {cmd:01jan2010} or {cmd:2010-01-01}, read in the variable's own
date unit; for a date variable a date string is never evaluated as
arithmetic, and a bound naming a variable is an error. A bound written {cmd:.} is open: {cmd:inrange(exit_date . td(31dec2025))}
has no lower bound. Missing values are
never outside a range.

{phang}
{opt all:owed(spec)} asserts that variables contain only declared values. The
specification is {cmd:\}-separated entries of the form
{it:var values}: {cmd:allowed(sex 0 1 \ arm "usual" "active")}.

{phang}
{opt for:bid(spec)} asserts that variables do not contain declared forbidden
values.

{phang}
{opt regex(spec)} asserts that string variables match regular expressions. Each
{cmd:\}-separated entry is {it:var pattern}.

{phang}
{opt notv:alues(spec)} asserts that variables do not contain sentinel or
placeholder values such as {cmd:-9}, {cmd:999}, or {cmd:"UNKNOWN"}.

{phang}
{opt rule(spec)} asserts row-level rules. Each {cmd:\}-separated entry is
{it:label}{cmd::} {it:expression}, for example
{cmd:rule("timeline": dob < dx_date & dx_date <= entry \ "entry_exit": entry < exit)}. A
rule holds for a row where the expression is true under Stata's {cmd:if}
semantics, so add {cmd:!missing()} terms where missing values matter. Rules are
evaluated once, on the {cmd:if}/{cmd:in} subset, in the data's current sort
order and before {cmd:datacheck} sorts anything, so subscripted expressions
such as {cmd:id != id[_n-1] | start >= stop[_n-1]} see the rows as arranged; sort
the data first, or use {opt intervals()}, which sorts its own copy. An
expression cannot contain a backslash. An expression that cannot be evaluated
is an error, not a violation.

{phang}
{opt stat(spec)} asserts that a statistic falls within a declared inclusive
band. Each {cmd:\}-separated entry is {it:statistic var lo hi} [{cmd:if} {it:exp}]
or {cmd:ratio} {it:num den lo hi} [{cmd:if} {it:exp}]. The statistics are
{cmd:mean}, {cmd:sd}, {cmd:median}, and {cmd:p1} to {cmd:p99} (as by
{help summarize:summarize, detail}); {cmd:sum}; {cmd:n}, the nonmissing count; {cmd:distinct},
the number of distinct nonmissing values; {cmd:pmiss}, the
share missing over all rows in scope; {cmd:ess}, the Kish effective sample size
(sum w)^2/sum(w^2) of a weight variable (Kish 1965); and {cmd:ratio}, sum
{it:num} / sum {it:den} over rows where both are nonmissing. The optional
{cmd:if} {it:exp} restricts that entry only and combines with the call's own
{cmd:if}: {cmd:stat(sum _d 412 412 \ ratio ev py 0.018 0.025 if at_risk)}. Commas
are read as spaces in the band, before the {cmd:if}, so a band stored as
{it:lo, hi} can be reused. A statistic with no value in scope (a mean of no
observations, {cmd:pmiss} of no rows) is a violation; {cmd:sum}, {cmd:n}, and
{cmd:distinct} of no rows are 0.

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
continuous variable passed by mistake stops the call. The message names the
level and its value label: {cmd:events(_d): mstype = 3 (SPMS) has 0 events}.

{phang}
{opt intervals(spec)} checks an interval file. Each {cmd:\}-separated entry is
{it:id} [{it:id ...}] {it:start stop} [{cmd:,} {cmd:contiguous}
{cmd:event(}{it:varname}{cmd:)} {cmd:tol(}{it:#}{cmd:)}]. The checks are named
separately: {bf:intervals(missing)} (start and stop nonmissing),
{bf:intervals(order)} (start < stop), {bf:intervals(overlap)} (within id,
sorted by start, start >= the latest earlier stop - tol), {bf:intervals(gap)} (with
{cmd:contiguous}, no start after the latest earlier stop + tol), and
{bf:intervals(event_last)} (with {cmd:event()}, the event is nonzero only on
the id's last interval). {cmd:datacheck} sorts its own copy, so the user's sort
order does not matter. {cmd:tol()} defaults to 0; use it for time scales in
days divided by 30.4375 or 365.25. Omit {cmd:event()} for a recurrent outcome. {opt intervals()}
runs once on the {cmd:if}/{cmd:in} sample, ignoring
{opt by()}.

{phang}
{opt keyset(spec)} asserts that the distinct keys in memory match those of a
saved dataset. Each {cmd:\}-separated entry is {it:varlist} {cmd:using}
{it:filename} [{cmd:,} {cmd:equal}|{cmd:subset}|{cmd:superset}]. With
{cmd:subset}, every key in memory exists in the file; with {cmd:superset},
every key in the file exists in memory; {cmd:equal} (the default) requires
both. Equal counts with different members, such as one person lost and another
gained after a merge on the wrong key, fail. {opt keyset()} ignores
{opt by()}.

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

{dlgtab:Sanity bands}

{phang}
{opt bands(gates)} declares the call's sanity bands: expectations about what
the data should look like, as opposed to invariants, which describe what they
must be. Inside {opt bands()} write {opt expectn()}, {opt stat()},
{opt inrange()}, {opt coverage()}, {opt groupstat()} with {cmd:band()},
{opt heaping()} with {cmd:max()}, and {opt complete()} with {cmd:min()}, as
{cmd:bands(expectn(9000 11000) stat(mean outcome 0.03 0.08))}. Any other
option inside {opt bands()} is an error. See
{help datacheck##kinds:Invariants, bands, and review items}.

{phang}
{opt bandwarn} reports failing bands as warnings under a {bf:BAND WARNINGS}
heading and leaves failing invariants halting. It is meant for a synthetic
run, where the bands are not calibrated, while production runs leave it off.

{phang}
{opt coverage(spec)} checks that a delivered file covers the period it should. Each
entry is {it:datevar lo hi}{cmd:,} {cmd:gap(}{it:#}{cmd:)}
[{cmd:tail(}{it:#}{cmd:)} {cmd:years}] for a daily date. {cmd:gap()}, the
delivery lag in days, is required and has no default, so an unsourced coverage
expectation stops the call. The checks are {bf:coverage(outside)} (the share of
dates outside [lo, hi] is at most {cmd:tail()}, default 0),
{bf:coverage(late_end)} (the last date is at least hi - gap, which a truncated
delivery fails), {bf:coverage(early_start)} (the first date is at most lo +
gap), and with {cmd:years} {bf:coverage(year_gap)} (no calendar year between
the first and last date is empty). {opt coverage()} is always a band, whether
written inside {opt bands()} or not.

{dlgtab:Review items}

{phang}
{opt review(spec)} prints, for each {cmd:\}-separated entry
{it:label}{cmd::} {it:expression}, the number and share of rows in scope
where the expression is true, masked under {opt maskrare}. It is evaluated,
like {opt rule()}, before any sort. {cmd:review("day0": outcome == 1 & outcome_dt - entry < 1)}.

{phang}
{opt heaping(spec)} prints, for each daily date in {it:datevarlist}
[{cmd:,} {cmd:fold(}{it:#}{cmd:)} {cmd:max(}{it:# [# #]}{cmd:)}], the share of
dates on 1 January, on the 1st of any month, and on the 15th, next to the
shares expected by chance (1/365.25, 12/365.25, 12/365.25). A share above
{cmd:fold()} times its chance share (default 5) is marked. With {cmd:max()},
the 1 January share (and with two or three numbers the 1st and 15th shares)
must not exceed the given shares; that is a gate, a band inside
{opt bands()}.

{phang}
{opt groupstat(spec)} prints a statistic by group next to its pooled value. Each
{cmd:\}-separated entry is {it:statistic varlist}{cmd:,}
{cmd:by(}{it:groupvars}{cmd:)} [{cmd:min(}{it:#}{cmd:)} {cmd:band(}{it:lo hi}{cmd:)}
{cmd:relative}] [{cmd:if} {it:exp}], with the statistics of {opt stat()} other
than {cmd:ratio}. Groups with fewer than {cmd:min()} rows (default: the mask
threshold, or 1 without masking) are pooled into one line. With {cmd:band()},
every group's statistic must lie in [lo, hi], including a group pooled away
under the mask, which fails as {cmd:[suppressed]}; only an explicit
{cmd:min()} leaves the groups below it out of the band. With {cmd:relative}, the
band applies to the ratio of the group's statistic to the pooled statistic, as
in the laboratory unit-switch check
{cmd:groupstat(median bcell, by(lab_site year) band(0.05 20) relative)}. {cmd:pmiss}
comes from the same computation as
{help datamvp:datamvp, bytable()}. {opt groupstat()} ignores {opt by()}.

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
groupwise completeness and missingness profile. {opt intervals()},
{opt keyset()}, {opt constant()}, {opt sets()}, {opt coverage()},
{opt heaping()}, {opt groupstat()}, and {opt jumps()} ignore {opt by()} and run
once on the {cmd:if}/{cmd:in} sample. {opt over(varname)} is a single-variable
synonym for {opt by(varlist)}.

{phang}
{opt check:s(filename)} reads gate specifications from {it:filename}. Each row
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
{cmd:var} and {cmd:min()} in {cmd:arg1}.

{phang}
{opt makes:pec(filename[, replace])} writes a starter checks file from the
current dataset: the observed row count, required variables, observed ranges
or allowed values, and a candidate {cmd:isid} key. It describes the data as
they are; review it before treating it as a gate contract, and never use it
as a source of bands.

{phang}
{opt comp:are(filename)} compares the current profiled variables with a saved
baseline. Added, dropped, storage-type, class, and observation-count changes
are reported as a {cmd:compare} violation.

{phang}
{opt warn} downgrades every gate, invariant and band alike, from a halt to a
warning. It is for diagnosing a do-file interactively; a committed gate call
should use {opt bandwarn} instead, so that invariants still halt.

{phang}
{opt minver:sion(#)} exits with r(198) unless the installed datamap version is
at least {it:#}. Alone, {cmd:datacheck, minversion(1.8.0)} needs no data in
memory and returns {cmd:r(version)}; an older copy also exits r(198), because
it does not know the option, so a do-file can reinstall on a nonzero return code.

{dlgtab:Output}

{phang}
{opt sav:ing(name[, replace])} saves the per-variable profile. If {it:name}
ends in {opt .dta} or contains a path separator the profile is written to that
file; otherwise it is copied into a frame of that name.

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
{cmd:severity}, {cmd:kind}, and {cmd:message}.

{phang}
{opt ledger(filename[, run(string)])} appends one row per gate entry, passed or
failed, and one per review item, to a Stata dataset, creating it when absent; {opt .dta}
is added to a filename without an extension. The
ledger is normally set once for a do-file with
{help dataqa:dataqa set ledger() run()}. Its columns are {cmd:run},
{cmd:stamp}, {cmd:seq} (call number within the run), {cmd:dataset},
{cmd:scope} (the call's and the entry's {cmd:if}), {cmd:family}, {cmd:label},
{cmd:variable}, {cmd:grp}, {cmd:kind} (invariant, band, or review),
{cmd:status} (pass, fail, warn, or review), {cmd:observed} (masked, as
printed), {cmd:observed_num} (missing whenever {cmd:observed} is masked),
{cmd:expected}, {cmd:n_scope} (missing below the mask threshold),
{cmd:version}, {cmd:signature}, {cmd:masked} (1 when the call ran under
{opt maskrare} with a threshold of at least 5), {cmd:mincell},
{cmd:minshown} (the smallest positive count printed unmasked),
{cmd:obs_masked}, and {cmd:message}. The working ledger belongs on the server
with the data; {help dataqa:dataqa export} writes the release copy.

{phang}
{opt sig:nature} records the {help datasignature} of the dataset, as loaded
and before {cmd:if}/{cmd:in}, in {cmd:r(signature)} and the ledger.


{marker gate}{...}
{title:Gate mode}

{pstd}
Any gate option turns on gate mode. {cmd:datacheck} does not stop at the first
failure: it evaluates every gate, accumulates all violations, and prints them as
a single block headed by the dataset name and the active masking. Each line
starts with the gate's family and label, such as {cmd:events(_d)},
{cmd:intervals(overlap)}, or {cmd:keyset(id)}:

{pmore}{cmd:. datacheck, gatesonly expectn(282252) isid(lopnr) inrange(age 18 110) maskrare}{p_end}

{pmore}{err:EXPECTATION VIOLATIONS (3): cohort [masked <5]}{p_end}
{pmore}{err: expectn: expected N = 282252, observed 311920}{p_end}
{pmore}{err: isid(lopnr): not unique — 29668 duplicated rows}{p_end}
{pmore}{err: inrange(age): <5 obs outside [18, 110]  (p1 19, p99 97)}{p_end}

{pstd}
When every gate passes, {cmd:datacheck} prints one line naming the dataset and
the gate families that ran, for example
{cmd:PASS: dose_intervals, 3 gate(s) (isid rule binary), N = 12,000, 0 violations [masked <5]},
so a clean log is distinguishable from one where the gates were skipped. {opt gatesonly}
with no gate declared prints a note saying nothing was checked.

{pstd}
On any failing invariant, or any failing band without {opt bandwarn},
{cmd:datacheck} exits with return code {bf:9}. Warnings print first, under
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
halt.

{pstd}
One gate call per dataset can therefore hold every invariant and every band,
with {cmd:global qa_calib bandwarn} set only under the synthetic switch.


{marker masking}{...}
{title:Masking}

{pstd}
Under {opt maskrare} with threshold {it:m}, no count from 1 to {it:m}-1 is
printed, nor a percentage or a complement from which one could be recovered,
nor an order statistic held by fewer than {it:m} observations:

{phang2}o  every count in a gate message and in {cmd:observed} prints as
{bf:<}{it:m}: {cmd:rule(entry_exit): <5 obs fail}. {opt isid()}
reports only the masked number
of duplicated rows, never the row and distinct-key counts, whose difference
would be the small cell. {cmd:r(n_violations)} counts gates, not persons, and is
not masked.{p_end}
{phang2}o  the MISSINGNESS and GROUPWISE blocks print a small missing count as
{bf:<}{it:m} and its percentage as {bf:.}; a count whose complement is small prints as
{bf:all but <}{it:m}, while a zero count prints as {bf:0}; a {opt by()} group smaller than {it:m} is not shown and is counted
in one line, {cmd:groups with <5 rows: 2}.{p_end}
{phang2}o  no minimum or maximum is printed. The continuous and date profiles and
{opt inrange()} messages show p1 and p99, dates at month precision, and any
percentile, mean, or {opt stat()} value is shown only when at least {it:m}
nonmissing observations lie at or below it and at or above it; otherwise it
prints as {bf:[suppressed]}.{p_end}
{phang2}o  the {opt patterns} table is masked by {help datamvp}.{p_end}

{pstd}
Every PASS line and violation heading ends with the active masking, such as
{bf:[masked <5]}. {cmd:r(masked)} is 1 when any printed count was masked. {opt saving()}
and {opt makespec()} still write observed minima and maxima. Stored
results are not masked: {cmd:r()} is not written to the log unless
displayed.


{marker examples}{...}
{title:Examples}

{pstd}Descriptive profile of the data in memory:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datacheck}{p_end}

{pstd}Gate a dataset before an analysis (halts the do-file on any violation):{p_end}
{phang2}{cmd:. datacheck, gatesonly expectn(74) isid(make) notmissing(price mpg) inrange(price weight 0 . \ mpg 10 50)}{p_end}

{pstd}Invariants and sanity bands in one call; bands warn under {opt bandwarn}:{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(make) rule("heavy": weight > 1500) bands(expectn(70 80) stat(mean mpg 18 25 \ median price 4000 6000)) bandwarn maskrare}{p_end}

{pstd}Rates, sums, and distinct counts, each with its own condition:{p_end}
{phang2}{cmd:. datacheck, gatesonly stat(sum foreign 22 22 \ distinct rep78 5 5 \ mean mpg 20 30 if foreign)}{p_end}

{pstd}Review items that print and never halt:{p_end}
{phang2}{cmd:. datacheck, gatesonly review("cheap": price < 4000) complete(rep78 mpg) groupstat(mean price mpg, by(foreign))}{p_end}

{pstd}Record the result in a ledger, with a stated dataset name:{p_end}
{phang2}{cmd:. tempfile ledger}{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(make) name(auto_cars) ledger("`ledger'", run(demo))}{p_end}

{pstd}Require a minimum installed version; a nonzero return code means reinstall:{p_end}
{phang2}{cmd:. capture datacheck, minversion(1.8.0)}{p_end}

{pstd}Show only flagged variables and mask rare cells before sharing a log:{p_end}
{phang2}{cmd:. datacheck, rare(5) mincell(5) maskrare show(flagged)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datacheck} stores the following in {cmd:r()}:

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
{synopt:{cmd:r(masked)}}1 when any printed count was masked{p_end}
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
{synopt:{cmd:r(ledger_seq)}}call number within the run, with {opt ledger()}{p_end}
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
{p2colreset}{...}

{pstd}
"Profile only" results are not set on the {opt gatesonly} fast path, which
does no classification. Use {opt warn} or {opt bandwarn} when execution must
continue after violations so that later code can read the results.


{marker references}{...}
{title:References}

{phang}
Kish, L. 1965. {it:Survey Sampling}. New York: Wiley.
{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}


{title:Also see}

{psee}
{help dataqa}, {help datamap}, {help datadict}, {help datamvp}, {manlink D codebook}, {manlink D assert}
{p_end}

{hline}

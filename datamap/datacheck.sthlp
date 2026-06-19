{smcl}
{* *! version 1.4.1  19jun2026}{...}
{vieweralsosee "datamap" "help datamap"}{...}
{vieweralsosee "datadict" "help datadict"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{vieweralsosee "[D] inspect" "help inspect"}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{vieweralsosee "[D] isid" "help isid"}{...}
{vieweralsosee "[D] duplicates" "help duplicates"}{...}
{viewerjumpto "Syntax" "datacheck##syntax"}{...}
{viewerjumpto "Description" "datacheck##description"}{...}
{viewerjumpto "Options" "datacheck##options"}{...}
{viewerjumpto "Gate mode" "datacheck##gate"}{...}
{viewerjumpto "Examples" "datacheck##examples"}{...}
{viewerjumpto "Stored results" "datacheck##results"}{...}
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

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Input}
{synopt:{opt sing:le(filename)}}profile a saved {opt .dta} instead of data in memory; the in-memory data is preserved{p_end}

{syntab:Classification}
{synopt:{opt maxc:at(#)}}categorical-vs-continuous cutoff passed to the classifier; default {bf:25}{p_end}
{synopt:{opt exc:lude(varlist)}}skip these variables entirely (also passed to the classifier){p_end}
{synopt:{opt cont:inuous(varlist)}}force these variables into the continuous group{p_end}
{synopt:{opt cat:egorical(varlist)}}force these variables into the categorical group{p_end}
{synopt:{opt date(varlist)}}force these variables into the date group{p_end}
{synopt:{opt id(keyspec)}}identifier key(s) for the uniqueness report; {cmd:\}-separate several keys{p_end}

{syntab:Detail}
{synopt:{opt d:etail}}full per-variable output: percentiles for continuous variables{p_end}
{synopt:{opt maxf:req(#)}}cap categorical/string levels shown; default {bf:20}{p_end}
{synopt:{opt rare(#)}}flag categorical levels with a count below {it:#}{p_end}
{synopt:{opt min:cell(#)}}flag tabulated cells below {it:#}{p_end}
{synopt:{opt mask:rare}}mask low-count cells in console output using {opt mincell()} or {opt rare()}{p_end}
{synopt:{opt out:liers(#)}}flag continuous values beyond {it:#} IQRs from the quartiles{p_end}

{syntab:Missingness}
{synopt:{opt nomiss:ing}}suppress the missingness summary block{p_end}
{synopt:{opt patterns}}add the {help datamvp} missing-value pattern table{p_end}

{syntab:Gate {it:(any gate option turns on gate mode)}}
{synopt:{opt gates:only}}run gates without printing the descriptive profile{p_end}
{synopt:{opt expectn(numlist)}}assert {cmd:_N}; one number is exact, two are an inclusive range{p_end}
{synopt:{opt isid(varlist)}}assert the dataset is unique by this key{p_end}
{synopt:{opt nodups}}assert no fully duplicated rows{p_end}
{synopt:{opt req:uire(varlist)}}assert these variables exist{p_end}
{synopt:{opt notmiss:ing(varlist)}}assert zero missing values in these variables{p_end}
{synopt:{opt inrange(spec)}}assert variables fall in declared ranges; {cmd:\}-separate{p_end}
{synopt:{opt all:owed(spec)}}assert variables contain only allowed values{p_end}
{synopt:{opt for:bid(spec)}}assert variables do not contain forbidden values{p_end}
{synopt:{opt regex(spec)}}assert string variables match regular expressions{p_end}
{synopt:{opt notv:alues(spec)}}assert variables do not contain sentinel or disallowed values{p_end}
{synopt:{opt by(varlist)}}evaluate gates and missingness summaries within groups defined by {it:varlist}{p_end}
{synopt:{opt over(varname)}}single-variable synonym for {opt by()}{p_end}
{synopt:{opt check:s(filename)}}read gate specifications from a checks file{p_end}
{synopt:{opt makes:pec(filename[, replace])}}write a starter checks file from the current dataset{p_end}
{synopt:{opt warn}}downgrade every gate from halt to warning; report but do not stop{p_end}

{syntab:Output}
{synopt:{opt sav:ing(name[, replace])}}save the per-variable profile to a {opt .dta} or a frame{p_end}
{synopt:{opt only:flagged}}show only variables or groups with warnings or violations{p_end}
{synopt:{opt show(flagged)}}same display filter as {opt onlyflagged}{p_end}
{synopt:{opt viol:ations(name[, replace])}}save the violation-level results to a {opt .dta} or a frame{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:datacheck} interrogates a dataset in the console and optionally gates on
declared expectations.  It is the interactive sibling of {help datamap} (which
{it:documents} a dataset to a file) and {help datadict} (which {it:publishes} a
Markdown dictionary).  All three commands share one classification engine, so a
variable is classified the same way no matter which command looks at it.

{pstd}
With no options, {cmd:datacheck} auto-classifies every variable and prints a
quick-reference table, a per-class profile (distributions for continuous,
frequency tables for categorical and string, ranges for date), a missingness
summary, and — when an identifier-like variable is detected — a key-structure
report.  No gate runs unless a gate option is given.

{pstd}
With one or more gate options, {cmd:datacheck} evaluates {it:every} gate,
accumulates all violations, prints them as a single block, and only then exits.
On any violation it exits with return code {bf:9} (Stata's assertion code), so a
do-file stops exactly as a bare {help assert} would.  See {help datacheck##gate:Gate mode}.

{pstd}
The data in memory is always preserved and restored; {cmd:datacheck} never
modifies the user's data.


{marker options}{...}
{title:Options}

{dlgtab:Input}

{phang}
{opt sing:le(filename)} profiles a saved {opt .dta} file instead of the data in
memory.  The in-memory data is preserved and restored.  The {opt .dta}
extension is optional.

{dlgtab:Classification}

{phang}
{opt maxc:at(#)} sets the cutoff, passed to the classifier, below which a numeric
variable is treated as categorical rather than continuous.  The default is 25.

{phang}
{opt exc:lude(varlist)} skips the named variables entirely.  As with {help datamap},
excluded variables are listed by name but their distributions, cardinality, and
value-label coding are never shown.

{phang}
{opt cont:inuous(varlist)}, {opt cat:egorical(varlist)}, and {opt date(varlist)}
force the named variables into the given group, overriding auto-classification.
Forcing a variable into the wrong group is itself a check: declaring
{cmd:continuous(sex)} makes the continuous section reveal a near-zero spread,
surfacing the mismatch.

{phang}
{opt id(keyspec)} declares the identifier key(s) for the uniqueness report.
{cmd:\}-separate several keys ({cmd:id(lopnr \ tx_id)}); a key may be composite
({cmd:id(lopnr visitdt)}).  When omitted, the report defaults to the
classifier's inferred identifier-like names.

{dlgtab:Detail}

{phang}
{opt d:etail} adds the full percentile set (1, 5, 10, 90, 95, 99) to the
quartiles already shown for continuous variables.

{phang}
{opt maxf:req(#)} caps the number of categorical or string levels listed; the
default is 20.  Levels beyond the cap are summarized in a "more levels" line.

{phang}
{opt rare(#)} flags categorical levels whose count falls below {it:#}.

{phang}
{opt min:cell(#)} flags any tabulated cell with a count below {it:#}.  This is
useful for disclosure checks where a rare level is a warning even when the
variable itself is otherwise valid.

{phang}
{opt mask:rare} masks low-count cells in console output.  The threshold is
{opt mincell(#)} when specified; otherwise it uses {opt rare(#)}, and defaults
to 5 if neither threshold is given.  The underlying data are not changed.

{phang}
{opt out:liers(#)} flags continuous values lying more than {it:#} interquartile
ranges beyond the first or third quartile.  {cmd:outliers(3)} is a sensible
start.  The default of 0 disables the check.

{dlgtab:Missingness}

{phang}
{opt nomiss:ing} suppresses the missingness summary block.

{phang}
{opt patterns} adds the missing-value pattern table from {help datamvp} (shipped
with this package).  This option is independent of {opt nomissing}.

{dlgtab:Gate}

{phang}
{opt gates:only} suppresses the descriptive profile and runs only the requested
gates.  This keeps batch logs short when {cmd:datacheck} is being used as a
preflight check in a larger pipeline.

{phang}
{opt expectn(numlist)} asserts the number of observations.  One number is an
exact expectation ({cmd:expectn(282252)}); two numbers are an inclusive range
({cmd:expectn(1000 1200)}).

{phang}
{opt isid(varlist)} asserts that the dataset is unique by the named key.

{phang}
{opt nodups} asserts that no fully duplicated rows exist.

{phang}
{opt req:uire(varlist)} asserts that the named variables exist in the dataset.

{phang}
{opt notmiss:ing(varlist)} asserts that the named variables have no missing
values.

{phang}
{opt inrange(spec)} asserts that variables fall within declared ranges.  The
specification is {cmd:\}-separated triples of {it:var lo hi}:
{cmd:inrange(age 18 110 \ edss 0 10)}.  Bounds may be numeric values or Stata
date literals, such as {cmd:inrange(index_date td(01jan2010) td(31dec2025))}.

{phang}
{opt all:owed(spec)} asserts that variables contain only declared values.  The
specification is {cmd:\}-separated entries of the form {it:var values}:
{cmd:allowed(sex 0 1 \ arm "usual" "active")}.  String values may be quoted.

{phang}
{opt for:bid(spec)} asserts that variables do not contain declared forbidden
values.  Use it for values that are syntactically valid but impossible in a
clean analysis file, such as a withdrawn treatment code.

{phang}
{opt regex(spec)} asserts that string variables match regular expressions.  Each
{cmd:\}-separated entry is {it:var pattern}, for example
{cmd:regex(person_id "^[0-9]{12}$" \ center "^[A-Z]{2}[0-9]{3}$")}.

{phang}
{opt notv:alues(spec)} asserts that variables do not contain sentinel or
placeholder values such as {cmd:-9}, {cmd:999}, or {cmd:"UNKNOWN"}.  The syntax
matches {opt allowed()} and {opt forbid()}:
{cmd:notvalues(age -9 999 \ outcome "UNKNOWN")}.

{phang}
{opt by(varlist)} evaluates gates within groups defined by {it:varlist} and
adds a groupwise completeness and missingness profile to the console report.
Use this when a rule is meaningful within strata, for example checking duplicate
visit numbers within each site.  {opt over(varname)} is a single-variable
synonym for {opt by(varlist)}.

{phang}
{opt check:s(filename)} reads gate specifications from {it:filename}.  This is
intended for project-level QC specs that should be versioned and reused across
imports, refreshes, and batch runs.

{phang}
{opt makes:pec(filename[, replace])} writes a starter checks file from the
current dataset.  The generated file includes the observed row count, required
variables, observed ranges or allowed values, and the first unique nonmissing
variable as a candidate {cmd:isid} key when one is found.  Review the proposed
ranges, allowed values, and required variables before treating it as a gate
contract.

{phang}
{opt warn} downgrades every gate from a halt to a warning: violations are
reported and the stored results are still set, but execution continues.  Use
this to run the gates diagnostically while building a do-file.

{dlgtab:Output}

{phang}
{opt sav:ing(name[, replace])} saves the per-variable profile (the shared
classifier columns plus a {cmd:dc_class} column reflecting any manual group
overrides).  If {it:name} ends in {opt .dta} or contains a path separator the
profile is written to that file; otherwise it is copied into a frame of that
name.  A bad path is reported and skipped without aborting the report.

{phang}
{opt only:flagged} filters console output to variables, groups, or gates with a
warning or violation.  It is equivalent to {cmd:show(flagged)}.

{phang}
{opt show(flagged)} requests the flagged-only display.  Future display values
may expand this option; {cmd:flagged} is the privacy- and batch-oriented filter.

{phang}
{opt viol:ations(name[, replace])} saves one row per warning or violation.  If
{it:name} ends in {opt .dta} or contains a path separator the violation table is
written to that file; otherwise it is copied into a frame of that name.

{pstd}
Privacy-oriented logs should combine {opt show(flagged)} with {opt maskrare}
and {opt mincell()}.  Excluded variables are named but their contents are not
displayed, and low-frequency cells are suppressed when rare-cell masking is
enabled.


{marker gate}{...}
{title:Gate mode}

{pstd}
Any gate option turns on gate mode.  {cmd:datacheck} does not stop at the first
failure: it evaluates every gate, accumulates all violations, and prints them as
a single block so one run tells you everything that is wrong.  For example:

{pmore}{cmd:. datacheck, expectn(282252) isid(lopnr) inrange(age 18 110)}{p_end}

{pmore}{err:EXPECTATION VIOLATIONS (3)}{p_end}
{pmore}{err:  expectn: expected N = 282252, observed 311920}{p_end}
{pmore}{err:  isid(lopnr): not unique — 311920 rows, 282252 distinct}{p_end}
{pmore}{err:  inrange(age): 14 obs outside [18, 110]  (min 0, max 119)}{p_end}

{pstd}
On any violation {cmd:datacheck} exits with return code {bf:9}.  With {opt warn}
the same block prints under a {bf:WARNINGS} heading, the stored results are set,
and execution continues.  Because Stata batch ({cmd:-b}) mode does not propagate
the return code to the shell exit status, automated harnesses detect a gate
failure by scanning the log for {cmd:r(9)}, not by the process exit code.

{pstd}
For production pipelines, put the gate contract in a checks file and call
{cmd:datacheck} with {opt gatesonly}.  Save the violation table when downstream
steps need structured diagnostics rather than console text.


{marker examples}{...}
{title:Examples}

{pstd}Descriptive profile of the data in memory:{p_end}
{phang2}{cmd:. datacheck}{p_end}

{pstd}Profile with a declared identifier key:{p_end}
{phang2}{cmd:. datacheck, id(patient_id)}{p_end}

{pstd}Full detail with outlier and rare-level flags:{p_end}
{phang2}{cmd:. datacheck, detail outliers(3) rare(5)}{p_end}

{pstd}Gate a cohort before an analysis (halts the do-file on any violation):{p_end}
{phang2}{cmd:. datacheck, expectn(282252) isid(lopnr) notmissing(sex birth_date) inrange(age 18 110 \ edss 0 10)}{p_end}

{pstd}Run the same gates diagnostically, without halting:{p_end}
{phang2}{cmd:. datacheck, expectn(282252) isid(lopnr) warn}{p_end}

{pstd}Run a batch preflight from a versioned checks file and save violations:{p_end}
{phang2}{cmd:. datacheck, gatesonly checks("qc_checks.dta") violations("qc_violations.dta", replace)}{p_end}

{pstd}Show only flagged variables and mask rare cells before sharing a log:{p_end}
{phang2}{cmd:. datacheck, rare(5) mincell(5) maskrare show(flagged)}{p_end}

{pstd}Gate dates using Stata date literals:{p_end}
{phang2}{cmd:. datacheck, inrange(index_date td(01jan2010) td(31dec2025) \ birth_date td(01jan1900) td(31dec2025))}{p_end}

{pstd}Apply value and format rules within site:{p_end}
{phang2}{cmd:. datacheck, by(site) allowed(sex 0 1 \ arm "usual" "active") regex(person_id "^[0-9]{12}$") notvalues(age -9 999)}{p_end}

{pstd}Create a starter checks file to review and edit:{p_end}
{phang2}{cmd:. datacheck, makespec("qc_checks.dta", replace)}{p_end}

{pstd}Profile a saved file, leaving the data in memory untouched:{p_end}
{phang2}{cmd:. datacheck, single(cohort_final)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:datacheck} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations profiled{p_end}
{synopt:{cmd:r(complete_cases)}}observations with no missing in the profiled varlist (excluded variables do not count){p_end}
{synopt:{cmd:r(complete_pct)}}percent complete{p_end}
{synopt:{cmd:r(n_checks)}}number of checks evaluated{p_end}
{synopt:{cmd:r(n_passed)}}number of check families without violations{p_end}
{synopt:{cmd:r(n_failed)}}number of check families with at least one violation{p_end}
{synopt:{cmd:r(n_violations)}}number of failed gates (0 when no gate ran or all passed){p_end}
{synopt:{cmd:r(n_groups)}}number of groups evaluated by {opt by()} or {opt over()}{p_end}
{synopt:{cmd:r(gatesonly)}}1 when {opt gatesonly} was specified; otherwise 0{p_end}
{synopt:{cmd:r(onlyflagged)}}1 when {opt onlyflagged} or {cmd:show(flagged)} was specified; otherwise 0{p_end}
{synopt:{cmd:r(n_continuous)}}number of continuous variables{p_end}
{synopt:{cmd:r(n_categorical)}}number of categorical variables{p_end}
{synopt:{cmd:r(n_date)}}number of date variables{p_end}
{synopt:{cmd:r(n_string)}}number of string variables{p_end}
{synopt:{cmd:r(n_excluded)}}number of excluded variables{p_end}
{synopt:{cmd:r(n_flagged)}}number of flagged variables{p_end}
{synopt:{cmd:r(n_constant)}}number of constant variables{p_end}
{synopt:{cmd:r(n_highcard)}}number of high-cardinality variables{p_end}
{synopt:{cmd:r(n_missing_vars)}}number of variables with missing values{p_end}
{synopt:{cmd:r(n_outlier_vars)}}number of variables with outlier flags{p_end}
{synopt:{cmd:r(n_rare_vars)}}number of variables with rare-level flags{p_end}
{synopt:{cmd:r(n_group_missing_vars)}}number of variables with missing values in at least one {opt by()} or {opt over()} group{p_end}
{synopt:{cmd:r(mincell)}}small-cell threshold supplied through {opt mincell()}{p_end}
{synopt:{cmd:r(maskrare)}}1 when {opt maskrare} was specified; otherwise 0{p_end}
{synopt:{cmd:r(n_dup_}{it:key}{cmd:)}}duplicate-key count for each declared {opt id()} key{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(violations)}}space-separated list of failed gate names{p_end}
{synopt:{cmd:r(failed_checks)}}unique failed gate names{p_end}
{synopt:{cmd:r(continuous_vars)}}continuous variables (post-override){p_end}
{synopt:{cmd:r(categorical_vars)}}categorical variables (post-override){p_end}
{synopt:{cmd:r(date_vars)}}date variables (post-override){p_end}
{synopt:{cmd:r(string_vars)}}string variables{p_end}
{synopt:{cmd:r(excluded_vars)}}excluded variables{p_end}
{synopt:{cmd:r(flagged_vars)}}flagged variables{p_end}
{synopt:{cmd:r(constant_vars)}}constant variables{p_end}
{synopt:{cmd:r(highcard_vars)}}high-cardinality variables{p_end}
{synopt:{cmd:r(missing_vars)}}variables with missing values{p_end}
{synopt:{cmd:r(outlier_vars)}}variables with outlier flags{p_end}
{synopt:{cmd:r(rare_vars)}}variables with rare-level flags{p_end}
{synopt:{cmd:r(group_missing_vars)}}variables with missing values in at least one {opt by()} or {opt over()} group{p_end}
{p2colreset}{...}

{pstd}
The stored results let a wrapper script branch on {cmd:r(n_violations)} without
parsing console text.  Use {opt warn} when you need execution to continue after
violations so subsequent Stata code can inspect the results programmatically.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.4.1 {hline 2} 19jun2026{p_end}


{title:Also see}

{psee}
{help datamap}, {help datadict}, {manlink D codebook}, {manlink D inspect}, {manlink D assert}
{p_end}

{hline}

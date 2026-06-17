{smcl}
{* *! version 1.2.0  17jun2026}{...}
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
{synopt:{opt out:liers(#)}}flag continuous values beyond {it:#} IQRs from the quartiles{p_end}

{syntab:Missingness}
{synopt:{opt nomiss:ing}}suppress the missingness summary block{p_end}
{synopt:{opt patterns}}add the {help datamvp} missing-value pattern table{p_end}

{syntab:Gate {it:(any gate option turns on gate mode)}}
{synopt:{opt expectn(numlist)}}assert {cmd:_N}; one number is exact, two are an inclusive range{p_end}
{synopt:{opt isid(varlist)}}assert the dataset is unique by this key{p_end}
{synopt:{opt nodups}}assert no fully duplicated rows{p_end}
{synopt:{opt req:uire(varlist)}}assert these variables exist{p_end}
{synopt:{opt notmiss:ing(varlist)}}assert zero missing values in these variables{p_end}
{synopt:{opt inrange(spec)}}assert variables fall in declared ranges; {cmd:\}-separate{p_end}
{synopt:{opt warn}}downgrade every gate from halt to warning; report but do not stop{p_end}

{syntab:Output}
{synopt:{opt sav:ing(name[, replace])}}save the per-variable profile to a {opt .dta} or a frame{p_end}
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
{cmd:inrange(age 18 110 \ edss 0 10)}.

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
{synopt:{cmd:r(n_violations)}}number of failed gates (0 when no gate ran or all passed){p_end}
{synopt:{cmd:r(n_dup_}{it:key}{cmd:)}}duplicate-key count for each declared {opt id()} key{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(violations)}}space-separated list of failed gate names{p_end}
{synopt:{cmd:r(continuous_vars)}}continuous variables (post-override){p_end}
{synopt:{cmd:r(categorical_vars)}}categorical variables (post-override){p_end}
{synopt:{cmd:r(date_vars)}}date variables (post-override){p_end}
{synopt:{cmd:r(string_vars)}}string variables{p_end}
{synopt:{cmd:r(excluded_vars)}}excluded variables{p_end}
{p2colreset}{...}

{pstd}
The stored results let a wrapper script branch on {cmd:r(n_violations)} without
parsing console text.  Note that a halting gate failure exits with {cmd:r(9)}
before the results are committed; use {opt warn} when you need to inspect the
results programmatically.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 1.2.0 {hline 2} 17jun2026{p_end}


{title:Also see}

{psee}
{help datamap}, {help datadict}, {manlink D codebook}, {manlink D inspect}, {manlink D assert}
{p_end}

{hline}

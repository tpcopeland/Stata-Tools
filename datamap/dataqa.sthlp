{smcl}
{* *! dataqa (version recorded in datamap.sthlp)}{...}
{vieweralsosee "datacheck" "help datacheck"}{...}
{vieweralsosee "datamvp" "help datamvp"}{...}
{vieweralsosee "datamap" "help datamap"}{...}
{viewerjumpto "Syntax" "dataqa##syntax"}{...}
{viewerjumpto "Description" "dataqa##description"}{...}
{viewerjumpto "Subcommands" "dataqa##subcommands"}{...}
{viewerjumpto "Options" "dataqa##options"}{...}
{viewerjumpto "Dispositions" "dataqa##dispositions"}{...}
{viewerjumpto "Examples" "dataqa##examples"}{...}
{viewerjumpto "Stored results" "dataqa##results"}{...}
{viewerjumpto "Author" "dataqa##author"}{...}

{title:Title}

{phang}
{bf:dataqa} {hline 2} Session defaults and a structured QA ledger over {cmd:datacheck} gate calls


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:dataqa set} [{it:options} | {cmd:clear}]

{p 8 17 2}
{cmd:dataqa report} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt mark:down(filename)} {opt replace} {opt bands}]

{p 8 17 2}
{cmd:dataqa assert} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt exp:ect(names)}
{opt base:line(string)} {opt baseled:ger(filename)} {opt opt:ional(names)}]

{p 8 17 2}
{cmd:dataqa export} [{cmd:using} {it:ledger}]{cmd:,} {opt sav:ing(filename)} [{opt run(string)} {opt replace} {opt thr:eshold(#)}]

{p 8 17 2}
{cmd:dataqa compare} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt base:line(string)}
{opt baseled:ger(filename)} {opt ntol(#)} {opt stattol(#)}]

{synoptset 24 tabbed}{...}
{synopthdr:set options}
{synoptline}
{synopt:{opt mask:rare}}mask small cells in {cmd:datacheck} and {cmd:datamvp}{p_end}
{synopt:{opt min:cell(#)}}the mask threshold{p_end}
{synopt:{opt led:ger(filename)}}ledger every gate call appends to{p_end}
{synopt:{opt run(string)}}run label for ledger rows, such as the date{p_end}
{synopt:{opt base:line(string)}}baseline run for compare, assert{p_end}
{synopt:{opt baseled:ger(filename)}}ledger file of the baseline run{p_end}
{synopt:{opt bandwarn}}make sanity bands warn (synthetic runs){p_end}
{synopt:{opt sig:nature}}record each dataset's {help datasignature}{p_end}
{synopt:{opt coll:ect}}failed gates are recorded, not halted on{p_end}
{synopt:{opt replace}}clear the ledger's rows of {opt run()} first{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:dataqa} turns the log-reading QA review loop into a structured ledger. {help datacheck}
appends one row per gate entry, passed or failed, and one per
review item, to the ledger named by {cmd:dataqa set ledger()} (or by its own
{opt ledger()} option). {cmd:dataqa report} summarizes the ledger and drafts
register rows; {cmd:dataqa assert} halts when an invariant failed or an
expected dataset was never checked; {cmd:dataqa compare} flags drift against an
earlier run; and {cmd:dataqa export} writes the copy of one run that may leave
the server, after checking that it holds no small cell.

{pstd}
Every subcommand works in a temporary frame; the data in memory are never
touched. {cmd:using} {it:ledger} defaults to the ledger set by
{cmd:dataqa set}, and {opt run()} to its run label. The ledger's columns are
listed under {opt ledger()} in {help datacheck##options:datacheck}.


{marker subcommands}{...}
{title:Subcommands}

{dlgtab:dataqa set}

{pstd}
{cmd:dataqa set} {it:options} stores session defaults in the global
{cmd:DATAMAP_DQ}, read by {cmd:datacheck} and {cmd:datamvp}. The options may be
written with or without a leading comma, so a do-file can carry
{cmd:dataqa set maskrare mincell($mincell) ledger("$working/qa_ledger.dta") run($dt) $qa_calib}
with {cmd:global qa_calib bandwarn} under the synthetic switch. Each
{cmd:dataqa set} replaces the previous defaults. {cmd:dataqa set} alone lists
them and {cmd:dataqa set clear} removes them.

{pstd}
The ledger only ever appends, so a rerun under the same {opt run()} label
finds the rows of the earlier attempt. With {opt replace},
{cmd:dataqa set ... ledger() run() replace} removes the rows of that run
before any gate call of the session writes, and says how many; the rows of
other runs, such as the baseline {cmd:dataqa compare} reads, are kept. Put it
on the {cmd:dataqa set} line of a do-file that is rerun under the same
label. Without {opt replace}, {cmd:dataqa set} prints a note when the run already
has rows; they are then read with the session's own rows.

{pstd}
A {cmd:datacheck} call under a ledger that exits for any reason other than a
gate failure (exit 9) or Break, such as a parse error, a misspelled option, a
bad {opt rule()} expression, or a missing variable, appends one error row before
it exits with its own return code: {cmd:family} {cmd:call}, {cmd:status}
{cmd:error}, the dataset name, {cmd:observed_num} the return code, and the
command text in {cmd:message}. The ledger is read from {opt ledger()} on the
raw command line, else from the session default; {opt name()} likewise, and
a call whose dataset cannot be named writes the row with an empty name. The
{opt minversion()} probe writes no row. {cmd:dataqa assert} exits 9 on any error row of the
selected run and names the dataset and the return code. An error row is never
superseded by a later call, even a clean one of the same dataset, so a typo
cannot be hidden by a rerun; start the run afresh with
{cmd:dataqa set ... ledger() run() replace}. {cmd:dataqa report} lists the error
rows and counts them under {cmd:Failed}, the markdown draft carries them as
open rows, {cmd:dataqa compare} flags a call that errors now, and
{cmd:dataqa export} refuses a run that holds one (r(459)).

{pstd}
Precedence is: an option typed on the command line, then the session default,
then a {opt config()} file. An explicit {cmd:nomaskrare} overrides a session
{opt maskrare}, and {cmd:datacheck} prints a note when it does. Every PASS line
and violation heading ends with the active masking, such as {bf:[masked <5]},
so a log shows that masking was on.

{dlgtab:dataqa report}

{pstd}
{cmd:dataqa report} prints, per dataset, the number of calls, gate entries,
failures, warnings, and review items. Within a run, {cmd:report},
{cmd:assert}, and {cmd:export} read only the latest call of each gate, a
gate being matched as in {cmd:dataqa compare} (see below): a gate that
failed and then passed when the same call was rerun counts once, as
passed. A rerun with changed bounds is a new gate, so the earlier failure stays in
the count; widening an expectation cannot clear it. A call without a dataset name (no {opt name()} and no file in memory) is
never superseded, since it cannot be told apart from another unnamed
dataset. {opt markdown(filename)} writes draft
register rows in the column order Run | Dataset | Check | Observed |
Expectation and source | Disposition | Date | PI consulted. The Check cell
follows one grammar, {it:family}{cmd:(}{it:label}{cmd:):} {it:observed}
{cmd:against} {it:expected} [{it:group}], built from the ledger's columns. A
dataset whose gates all passed gets one row listing its families, the
register's clean-run row. Each failed, warned, or review row is left
{bf:open}, with its kind and the dispositions that kind allows; the source of
each expectation lives in the plan and is left for the analyst.

{pstd}
{opt bands} adds a table of every band and every {opt stat()} invariant in the
selected run, passing or failing: dataset, gate, status, declared range, and
observed value. The range and the observed value are the ledger's
{cmd:expected} and {cmd:observed} columns exactly as stored, so a value masked
under {cmd:maskrare} (for example {cmd:n <5}) prints masked, and {cmd:observed_num}
is never read. The table reports declared ranges only; it never proposes or
infers a band from the data. For a gate whose expectation is a sentence rather
than bounds ({opt coverage()}, for example), the sentence is the declared range. A
row with no recorded expectation shows {bf:(not recorded)}. A run with
no such rows prints a line saying so. With {opt markdown()} the table is
appended to the draft as its own section, {bf:Bands and stat() invariants},
after the register table; without {opt bands} the draft is unchanged.

{dlgtab:dataqa assert}

{pstd}
{cmd:dataqa assert} exits with return code 9 if any row of the run failed, if
an invariant was downgraded by bare {cmd:warn}, if the run has no rows, or if a
dataset named in {opt expect()} has no rows in the run. The last condition makes
the review-loop rule "a QA dataset line not followed by a verdict" mechanical: placed
last in the QA section, it catches a gate call deleted by mistake. A
name in {opt expect()} matches a dataset recorded under that name, with or
without {bf:(modified)}.

{pstd}
With {opt baseline()}, {cmd:dataqa assert} also exits with return code 9 when a
named dataset has rows in the baseline run but none in the run asserted,
unless the dataset is listed in {opt optional()}. It names every such dataset.
This replaces a hand-kept {opt expect()} list and covers datasets the list
omits. Without {opt baseline()} on the call, the session baseline of
{cmd:dataqa set baseline()} is used, with the same check. The baseline is resolved as in {cmd:dataqa compare}: the run
{opt baseline()} in the ledger given by {opt baseledger()}, else in the ledger
asserted. A baseline label with no rows is an error, r(2000), never a pass. A
dataset with rows now and none in the baseline is not an error.
{opt expect()} still works, alone or together with {opt baseline()}. Calls
without a dataset name cannot be matched and are not checked. {opt optional()}
and {opt baseledger()} without {opt baseline()} are r(198).
A dataset name with a space goes in compound quotes in {opt expect()} and
{opt optional()}, as in {cmd:optional(}{cmd:`"}{it:b c}{cmd:"'} {it:d}{cmd:)}.

{dlgtab:dataqa export}

{pstd}
{cmd:dataqa export} writes the release copy of one run to {opt saving()}. It
refuses with r(459) when any row comes from a call not run under
{opt maskrare} with a threshold of at least 5, when any row was masked below
{opt threshold()} (default 5), when any row prints a count between 1 and
{opt threshold()}-1, or when a masked row keeps {cmd:observed_num}. The copy
blanks {cmd:scope} expressions that contain a quoted string or a number of four
or more digits, which may be an identifier written in a hurry. The working
ledger stays on the server; only the exported copy leaves it, so the copy is
a different file: {opt saving()} naming the ledger being read is refused
with r(602), even with {opt replace}. The comparison resolves a relative
path against the working directory and folds {cmd:./} and
{cmd:dir/..} segments; on Windows it treats {cmd:\} as {cmd:/} and, as on macOS,
ignores case. It does not see through a symbolic link or a mapped drive.

{dlgtab:dataqa compare}

{pstd}
{cmd:dataqa compare} matches the rows of {opt run()} with those of
{opt baseline()} on dataset, family, label, variable, group, scope, and
expectation, in the same ledger or in {opt baseledger()}. A gate whose bounds
changed is therefore a different gate: its baseline row is flagged as
absent. A {cmd:by()} group is matched on its values ({cmd:site=3 year=2015}), so a level added
between extracts is reported as a new group ({cmd:new}) and every other group still pairs
with itself. A ledger written before 1.9.0, and a group withheld under {opt maskrare}, record
the group as its number within the call; two such runs still compare among themselves, but
a number can name a different level if the data change. When one run records a gate's groups by
number and the other by value, {cmd:compare} prints {cmd:mixed}, counts one item to review,
and pairs none of that gate's groups; re-run the baseline to compare them. It flags a change in rows in scope beyond
{opt ntol()} (a share, default 0.05), a change in a {opt stat()} value beyond
{opt stattol()} (a relative change, default 0.05), a changed
{help datasignature}, and a gate present in the baseline but absent now. A
count or {opt stat()} value withheld under the mask (or, for {opt stat()},
undefined) in one run and shown in the other is flagged without printing the
withheld number; against a baseline of 0 any change is flagged. The
output has review severity and never halts. With no {opt baseline()} on the call and none set by
{cmd:dataqa set baseline()}, it prints a note and exits 0, as on the first
run on an extract.


{marker options}{...}
{title:Options}

{dlgtab:Options for dataqa set}

{phang}
{opt mask:rare} turns on {opt maskrare} in every later {cmd:datacheck} and
{cmd:datamvp} call, so no small count is printed. A call that types
{cmd:nomaskrare} overrides it.

{phang}
{opt min:cell(#)} sets the mask threshold, a nonnegative integer, passed to
both commands as {opt mincell()}. Without it, the threshold under
{opt maskrare} is {opt rare()} or 5 in {cmd:datacheck} and 5 in {cmd:datamvp}.

{phang}
{opt led:ger(filename)} names the ledger every later {cmd:datacheck} call
appends to, as with its {opt ledger()} option. {opt .dta} is added to a
filename without a suffix, as {cmd:save} does; a name with any other suffix, such as
{cmd:qa.v2} or a {cmd:tempfile} path, is used as given. Every
{cmd:dataqa} subcommand and {cmd:datacheck} read and write the same
file under this rule.

{phang}
{opt run(string)} labels the ledger rows of this session, such as the date of
the run. It requires {opt ledger()} and may not contain parentheses, quotes,
backslashes, or the shell characters {cmd:; & | < > $} and the backtick.

{phang}
{opt base:line(string)} names the baseline run that {cmd:dataqa compare} and
{cmd:dataqa assert} hold the current run against when they are not given
{opt baseline()}, so a do-file need not retype it. An explicit
{opt baseline()} on the call wins. {cmd:dataqa set} replaces the whole
specification, so a call without {opt baseline()}, or with
{cmd:baseline("")}, leaves no baseline; this is how a synthetic run switches
it off. The same quoting limits as {opt run()} apply. With only a session
baseline, {cmd:dataqa assert} runs the baseline check described there, and
a baseline with no rows is r(2000) there, as with an explicit one.
{cmd:dataqa compare} says it has no rows and exits 0.

{phang}
{opt baseled:ger(filename)} is the ledger file that holds the baseline run;
without it the baseline is read from the ledger of the current run. It
requires {opt baseline()} (r(198) otherwise) and takes the same suffix rule as
{opt ledger()}. It goes with the session baseline: a call that types its own
{opt baseline()} but no {opt baseledger()} reads that baseline from the ledger of
the current run. An explicit {opt baseledger()} wins over the session one.

{phang}
{opt bandwarn} turns on {opt bandwarn} in every later {cmd:datacheck} call,
so failing sanity bands warn while invariants still halt. Set it only for a
synthetic run, where the bands are not calibrated.

{phang}
{opt sig:nature} turns on {opt signature} in every later {cmd:datacheck}
call, so the ledger records each dataset's {help datasignature}.

{phang}
{opt collect} makes a {cmd:datacheck} call under a ledger record a gate failure
instead of halting on it. The call still prints its violation block and writes
its rows, but it returns 0 with {cmd:r(n_failed)} and {cmd:r(n_errors)} set, and
prints one line saying the failures were recorded and that {cmd:dataqa assert}
will halt; {cmd:dataqa assert} stays the single halting point. Without a ledger
({cmd:dataqa set ledger()} or {opt ledger()} on the call) {opt collect} has no
effect and a failed gate exits 9, with a note. If the ledger append fails, the
call exits nonzero as before. An error that is not a gate failure always halts,
and leaves an error row (see below). Without {opt collect} a failed gate exits 9
everywhere. {cmd:dataqa set clear} removes it with the other defaults.

{phang}
{opt replace} removes the rows of {opt run()} from {opt ledger()} when the
defaults are set, so the run starts afresh; rows of other runs are kept. It
requires both {opt ledger()} and {opt run()}, acts once, and is not stored
with the defaults. A file that is not a datacheck ledger is refused with
r(610) and left untouched.

{dlgtab:Options for report, assert, export, and compare}

{phang}
{opt run(string)} selects the run to read. It defaults to the run set by
{cmd:dataqa set}. {cmd:dataqa report} reads every run when neither is given; {cmd:dataqa assert},
{cmd:dataqa export}, and {cmd:dataqa compare} require one.

{phang}
{opt mark:down(filename)} ({cmd:report}) writes the register draft to
{it:filename}. {opt replace} permits overwriting an existing file; without it
an existing file is an error, r(602).

{phang}
{opt exp:ect(names)} ({cmd:assert}) lists the datasets that must have rows in
the run.

{phang}
{opt bands} ({cmd:report}) prints, and with {opt markdown()} appends to the
draft, the table of bands and {opt stat()} invariants described above.

{phang}
{opt opt:ional(names)} ({cmd:assert}) lists datasets of the baseline run that may
be absent from the run asserted. It requires {opt baseline()}.

{phang}
{opt sav:ing(filename)} ({cmd:export}) is required and names the release copy,
a file other than the ledger being exported. {opt .dta}
is added to a filename without a suffix, and {opt replace}
permits overwriting an existing file.

{phang}
{opt thr:eshold(#)} ({cmd:export}) is the house mask threshold, a positive
integer; the default is 5.

{phang}
{opt base:line(string)} ({cmd:compare}, {cmd:assert}) is the run label of the baseline run.

{phang}
{opt baseled:ger(filename)} ({cmd:compare}, {cmd:assert}) names the ledger that holds the
baseline run; the default is the ledger being compared.

{phang}
{opt ntol(#)} and {opt stattol(#)} ({cmd:compare}) are the nonnegative
tolerances for a change in rows in scope and in a {opt stat()} value; both
default to 0.05.


{marker dispositions}{...}
{title:Dispositions}

{pstd}
The kind of a failed row, fixed where its gate was declared (see
{help datacheck##kinds:datacheck}), limits the dispositions the register may
record:

{phang2}{bf:invariant}: {it:code fixed}, or {it:accepted: <reason>} with the PI consulted.{p_end}
{phang2}{bf:band}: {it:code fixed}, {it:accepted: <reason>}, {it:expectation revised pre hoc},
or {it:expectation revised post hoc}.{p_end}
{phang2}{bf:review}: {it:accepted: <reason>} or {it:code fixed}.{p_end}

{pstd}
An agent drafting the register from {cmd:dataqa report} therefore cannot
propose widening an invariant.


{marker examples}{...}
{title:Examples}

{pstd}Set the session defaults once, then gate two datasets:{p_end}
{phang2}{cmd:. tempfile ledger}{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`ledger'") run(demo)}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)}{p_end}
{phang2}{cmd:. sysuse lifeexp, clear}{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(country) name(lifeexp)}{p_end}

{pstd}Summarize, draft the register, and assert that both datasets were checked:{p_end}
{phang2}{cmd:. dataqa report}{p_end}
{phang2}{cmd:. dataqa assert, expect(auto_cars lifeexp)}{p_end}
{phang2}{cmd:. dataqa report, bands}{p_end}

{pstd}Hold a later run against the first: a dataset that vanished halts, unless it is optional:{p_end}
{phang2}{cmd:. dataqa assert, run(rerun) baseline(demo) optional(lifeexp)}{p_end}

{pstd}Write the release copy of the run to its own file, never over the working ledger:{p_end}
{phang2}{cmd:. dataqa export, saving("qa_ledger_release_demo.dta") replace}{p_end}

{pstd}Clear the defaults:{p_end}
{phang2}{cmd:. dataqa set clear}{p_end}

{pstd}In a do-file rerun under the same run label, start the run afresh and name the release copy apart from the ledger:{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("$working/qa_ledger_$dt.dta") run($dt) replace}{p_end}
{phang2}{cmd:. dataqa export, saving("$output/qa_ledger_release_$dt.dta") replace}{p_end}

{pstd}A whole pipeline, in the form a study do-file takes. An earlier run stands
as the baseline; the session holds the baseline once, and a synthetic switch
blanks it:{p_end}
{phang2}{cmd:. tempfile ledger qalog md release}{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`ledger'") run(base) replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)}{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(idcode) bands(stat(mean age 38 41)) name(nlsw)}{p_end}
{phang2}{cmd:. capture datacheck, minversion(1.9.0)}{p_end}
{phang2}{cmd:. if _rc display as error "datamap 1.9.0 or later is needed"}{p_end}
{phang2}{cmd:. global qa_synth 0}{p_end}
{phang2}{cmd:. global qa_baseline = cond($qa_synth, "", "base")}{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`ledger'") run(now) collect baseline($qa_baseline) replace}{p_end}
{phang2}{cmd:. log using "`qalog'", name(qa) text replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)}{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. datacheck, gatesonly isid(idcode) bands(stat(mean age 38 41)) name(nlsw)}{p_end}
{phang2}{cmd:. log close qa}{p_end}
{phang2}{cmd:. dataqa compare}{p_end}
{phang2}{cmd:. dataqa report, markdown("`md'") replace bands}{p_end}
{phang2}{cmd:. dataqa export, saving("`release'") replace}{p_end}
{phang2}{cmd:. dataqa assert, expect(auto_cars nlsw)}{p_end}
{phang2}{cmd:. dataqa set clear}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:dataqa set} stores {cmd:r(defaults)}, the option string, and with
{opt replace} {cmd:r(n_removed)}, the rows removed. {cmd:dataqa report},
{cmd:dataqa assert}, and {cmd:dataqa export} store {cmd:r(n_superseded)}, the
rows left out because a later call of the same gate replaced
them. {cmd:dataqa report}
stores {cmd:r(N)} (rows read after that), {cmd:r(n_datasets)}, {cmd:r(n_failed)},
{cmd:r(n_warned)}, {cmd:r(ledger)}, {cmd:r(run)}, with {opt markdown()}
{cmd:r(markdown)} and {cmd:r(n_rows)}, and with {opt bands} {cmd:r(n_bands)}. {cmd:dataqa assert} stores {cmd:r(N)},
{cmd:r(n_failed)}, {cmd:r(n_errors)} (error rows, included in {cmd:r(n_failed)}), {cmd:r(missing)} (expected datasets without rows), and
{cmd:r(run)}, also when it halts with r(9). With {opt baseline()} it also stores
{cmd:r(baseline)}, {cmd:r(n_missing_base)} and {cmd:r(missing_base)} (baseline
datasets without rows now, each in compound quotes),
{cmd:r(n_optional_absent)} and {cmd:r(optional_absent)} (those waived by {opt optional()}); the baseline may come from {cmd:dataqa set baseline()}. {cmd:dataqa export} stores
{cmd:r(N)}, {cmd:r(n_scope_dropped)}, and {cmd:r(saving)}. {cmd:dataqa compare}
stores {cmd:r(n_flags)} and {cmd:r(baseline)}, and with {opt baseline()}
{cmd:r(run)}.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}


{title:Also see}

{psee}
{help datacheck}, {help datamvp}, {help datamap}
{p_end}

{hline}

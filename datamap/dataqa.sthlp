{smcl}
{* *! dataqa (version recorded in datamap.sthlp)}{...}
{vieweralsosee "dataprobe" "help dataprobe"}{...}
{vieweralsosee "datamvp" "help datamvp"}{...}
{vieweralsosee "datamap" "help datamap"}{...}
{viewerjumpto "Syntax" "dataqa##syntax"}{...}
{viewerjumpto "Description" "dataqa##description"}{...}
{viewerjumpto "Subcommands" "dataqa##subcommands"}{...}
{viewerjumpto "Options" "dataqa##options"}{...}
{viewerjumpto "Dispositions" "dataqa##dispositions"}{...}
{viewerjumpto "Examples" "dataqa##examples"}{...}
{viewerjumpto "Stored results" "dataqa##results"}{...}
{viewerjumpto "References" "dataqa##references"}{...}
{viewerjumpto "Author" "dataqa##author"}{...}

{title:Title}

{phang}
{bf:dataqa} {hline 2} Session defaults and a structured QA ledger over {cmd:dataprobe} gate calls


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:dataqa set} [{opt agent}] [{it:options} | {cmd:clear}]

{p 8 17 2}
{cmd:dataqa report} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt phase(names)} {opt mark:down(filename)} {opt replace} {opt bands}]

{p 8 17 2}
{cmd:dataqa assert} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt exp:ect(names)}
{opt base:line(string)} {opt baseled:ger(filename)} {opt opt:ional(names)} {opt pend:ing(names)} {opt phase(names)}]

{p 8 17 2}
{cmd:dataqa export} [{cmd:using} {it:ledger}]{cmd:,} {opt sav:ing(filename)} [{opt run(string)} {opt phase(names)} {opt replace} {opt thr:eshold(#)}]

{p 8 17 2}
{cmd:dataqa compare} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt base:line(string)}
{opt baseled:ger(filename)} {opt phase(names)} {opt ntol(#)} {opt stattol(#)}]

{p 8 17 2}
{cmd:dataqa flow step} {it:name} [{cmd:,} {opt led:ger(filename)} {opt run(string)} {opt flow(name)} {opt id(varname)} {opt lab:el(string)}]

{p 8 17 2}
{cmd:dataqa flow report} [{cmd:,} {opt led:ger(filename)} {opt run(string)} {opt flow(name)} {opt phase(name)} {opt min:cell(#)} {opt pool:small}
{opt count(ids|rows)} {opt exp:ort(filename)} {opt replace}]

{p 8 17 2}
{cmd:dataqa flow clear} [{cmd:,} {opt led:ger(filename)} {opt run(string)} {opt flow(name)} {opt all}]

{p 8 17 2}
{cmd:dataqa merge}{cmd:,} {opt into(ledger)} [{opt from(dir|pattern)} {opt run(string)} {opt replace}]

{synoptset 24 tabbed}{...}
{synopthdr:set options}
{synoptline}
{synopt:{opt agent}}the agent-safe preset for the session{p_end}
{synopt:{opt mask:rare}}mask small cells in {cmd:dataprobe} and {cmd:datamvp}{p_end}
{synopt:{opt min:cell(#)}}the mask threshold{p_end}
{synopt:{opt led:ger(filename)}}ledger every gate call appends to{p_end}
{synopt:{opt worker(id)}}this job writes its own shard of the ledger{p_end}
{synopt:{opt shard:dir(dir)}}directory of the worker's shard{p_end}
{synopt:{opt run(string)}}run label for ledger rows, such as the date{p_end}
{synopt:{opt phase(name)}}phase that tags ledger rows, such as {cmd:build}{p_end}
{synopt:{opt base:line(string)}}baseline run for compare, assert{p_end}
{synopt:{opt baseled:ger(filename)}}ledger file of the baseline run{p_end}
{synopt:{opt bandwarn}}make sanity bands warn (synthetic runs){p_end}
{synopt:{opt sig:nature}}record each dataset's {help datasignature}{p_end}
{synopt:{opt coll:ect}}failed gates are recorded, not halted on{p_end}
{synopt:{opt replace}}clear the rows and flow steps of {opt run()} first{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:dataqa} turns the log-reading QA review loop into a structured ledger. {help dataprobe}
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
listed under {opt ledger()} in {help dataprobe##options:dataprobe}. {cmd:report}, {cmd:assert}, {cmd:export}, and {cmd:compare}
refuse a ledger whose {cmd:status} is not a string variable, or has a row whose
status is not one of {bf:pass}, {bf:fail}, {bf:warn}, {bf:review}, or
{bf:error}, with error 610.

{pstd}
Ledger text (dataset names, labels, groups, expectations, messages, run
labels) is printed as text: a double or single quote, a dollar sign, a
backtick, a brace, or SMCL markup in it prints as stored and is never read
as a macro or as SMCL. The register draft and the release copy carry it as
stored.

{pstd}
A ledger row carries the phase of its call in the column {cmd:phase}: the
call's {opt phase()} in {cmd:dataprobe}, else the session's
{cmd:dataqa set phase()}, else empty. {opt phase(names)} on {cmd:report},
{cmd:assert}, {cmd:export}, and {cmd:compare} reads only the rows of those
phases (both runs in {cmd:compare} and in the baseline check of
{cmd:assert}), plus every call error row of the run, whatever its phase: a
call that failed may have named another phase, so its error is never
filtered away. A ledger written before the column existed reads as phase
empty throughout, so a {opt phase()} selection keeps none of its rows; every
other use of such a ledger is unchanged.

{pstd}
{cmd:dataqa flow} records a cohort's attrition step by step and prints it
as a flow (CONSORT) table under the mask; {cmd:dataqa merge} folds the
ledger shards of parallel jobs, set with {cmd:dataqa set worker()}, into
one ledger. Both are described below.


{marker subcommands}{...}
{title:Subcommands}

{dlgtab:dataqa set}

{pstd}
{cmd:dataqa set} {it:options} stores session defaults in the global
{cmd:DATAMAP_DQ}, read by {cmd:dataprobe} and {cmd:datamvp} (and by {cmd:datamap},
which reads only the {cmd:agent} setting). The options may be
written with or without a leading comma, so a do-file can carry
{cmd:dataqa set maskrare mincell($mincell) ledger("$working/qa_ledger.dta") run($dt) $qa_calib}
with {cmd:global qa_calib bandwarn} under the synthetic switch. Each
{cmd:dataqa set} replaces the previous defaults. {cmd:dataqa set} alone lists
them and {cmd:dataqa set clear} removes them.

{pstd}
{cmd:dataqa set agent} is the agent-safe preset for the session: until
{cmd:dataqa set clear}, {cmd:datamap}, {cmd:dataprobe}, and {cmd:datamvp} run as
if {opt safe} were typed (see each command's {opt safe}), and {cmd:nomaskrare}
cannot turn it off. Other options may follow it, as in
{cmd:dataqa set agent mincell(10) ledger("qa.dta") run(r1)}. The preset is
{opt safe}, with the limits stated under {help datamap##safe:datamap's Safe output}: it
covers printed output and written files only, and not the flow file of
{cmd:dataqa flow}, a working file of exact counts (see
{help dataqa##subcommands:dataqa flow}); stored results ({cmd:r()}), a
{cmd:dataprobe} {opt snapshot()} frame, and differencing across outputs are not
masked, identifiers are recognized by variable name only, and an integer date
with no date format prints as a number.

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
A {cmd:dataprobe} call under a ledger that exits for any reason other than a
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
{opt maskrare}, and {cmd:dataprobe} prints a note when it does. Every PASS line
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
the count; widening an expectation cannot clear it. So is the same check
declared as another kind (a failed {opt stat()} invariant rerun as a
{opt bands()} band). A rerun supersedes the earlier rows of its gate, so a
file fixed on disk, reloaded, and rerun ({cmd:duplicates drop}, {cmd:save},
{cmd:use}) clears its failure, with one exception: a rerun on data changed in
memory, recorded as {bf:(modified)}, never supersedes a row of the unmodified
data, so a rerun on a subset ({cmd:keep if ...}) leaves the full-data failure
standing; start the run afresh to drop it. A call's {cmd:if} or {cmd:in} is
part of its gate, so a rerun on {cmd:if} rows is a different gate. A call under
{opt name()} carries no {bf:(modified)} marker, so give a subset its own
{opt name()}. A call without a dataset name (no {opt name()} and no file in memory) is
never superseded, since it cannot be told apart from another unnamed
dataset. In a ledger merged from worker shards ({cmd:dataqa merge}) a
call supersedes only earlier rows of its own worker: when two workers ran
the same gate, both rows stand and a failure in either is counted. Ledger text (a dataset name, label, expectation, or observed value)
is printed as text in the console and the draft: no SMCL, quote, or macro
character in it is live. {opt markdown(filename)} writes draft
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
name in {opt expect()} matches a dataset recorded under exactly that name, with or
without {bf:(modified)}; {cmd:expect(cohort)} is not met by {bf:cohort (2019)}.

{pstd}
It also exits with return code 9 when worker shards of the ledger hold rows
of the run that the ledger does not, so a worker's failed gate or error row
cannot pass unseen before {cmd:dataqa merge}: the message names the number of
shards and their workers and says to run {cmd:dataqa merge}; see
{help dataqa##subcommands:dataqa merge}. {cmd:dataqa report} prints the same
finding as a {bf:WARNING} line and reads the ledger as it is;
{cmd:dataqa export} refuses with r(459).

{pstd}
With {opt baseline()}, {cmd:dataqa assert} also exits with return code 9 when a
named dataset has rows in the baseline run but none in the run asserted,
unless the dataset is listed in {opt optional()}. It names every such dataset. This
replaces a hand-kept {opt expect()} list and covers datasets the list
omits. Without {opt baseline()} on the call, the session baseline of
{cmd:dataqa set baseline()} is used, with the same check. The baseline is resolved as in {cmd:dataqa compare}: the run
{opt baseline()} in the ledger given by {opt baseledger()}, else in the ledger
asserted. A baseline label with no rows is an error, r(2000), never a pass. A
dataset with rows now and none in the baseline is not an error. {opt expect()}
still works, alone or together with {opt baseline()}. Calls
without a dataset name cannot be matched and are not checked. With no
baseline, from the call or the session, {opt optional()} is ignored with a
note, so a do-file may carry it before the first baseline run exists; {opt baseledger()}
without a baseline is r(198). A dataset name with a space goes in compound quotes in
{opt expect()} and {opt optional()}, as in {cmd:optional(}{cmd:`"}{it:b c}{cmd:"'}
{it:d}{cmd:)}.

{pstd}
{opt pending(names)} lists phases whose gates have not run yet, such as the
analysis phase of a study whose build phase is asserted first. A baseline
dataset with no rows in the run is reported as {bf:PENDING}, and does not
halt, when every one of its baseline rows carries a phase in
{opt pending()}; a dataset with a baseline row of any other phase is still
missing. A name in {opt expect()} with no rows is pending by the same rule
on its baseline rows. In a dataset that has rows in the run, a baseline gate
of a pending phase with no row yet is listed as {bf:PENDING}
({it:dataset}{cmd::} {it:family}{cmd:(}{it:label}{cmd:)}); a gate is matched on
dataset, family, label, variable, scope, and kind, so a by() group or a
changed declared range does not make it pending. Rows that are present are
held to the usual rules whatever their phase: a failed gate of a pending
phase still halts. This
replaces a hand-kept {opt optional()} list of later-phase datasets. Like
{opt optional()}, {opt pending()} needs a baseline and is ignored with a note
without one, and a baseline whose ledger has no {cmd:phase} column has no
pending dataset. A phase may not be both selected by {opt phase()} and listed
in {opt pending()} (r(198)).

{dlgtab:dataqa export}

{pstd}
{cmd:dataqa export} writes the release copy of one run to {opt saving()}. It
refuses with r(459) when any row comes from a call not run under
{opt maskrare} with a threshold of at least 5, when any row was masked below
{opt threshold()} (default 5), when any row prints a count between 1 and
{opt threshold()}-1, or when a masked row keeps {cmd:observed_num}. The copy
blanks {cmd:scope} expressions that contain a quoted string or a number of four
or more digits, which may be an identifier written in a hurry. The same test
blanks the {cmd:expected}, {cmd:label}, and {cmd:message} text of the gates
written as data values ({opt rule()}, {opt review()}, {opt byrule()},
{opt forbid()}, {opt notvalues()}, {opt allowed()}, {opt regex()},
{opt sets()}); the message, which repeats the expectation, goes with it. Bounds
gates ({opt inrange()}, {opt stat()}, and the like) keep their numbers. A
{cmd:signature} whose leading N (the dataset's row count) is between 1 and
{opt threshold()}-1 is blanked. The working
ledger stays on the server; only the exported copy leaves it, so the copy is
a different file: {opt saving()} naming the ledger being read, or the
session's {opt ledger()} or {opt baseledger()}, is refused
with r(602), even with {opt replace}. The comparison resolves a relative
path against the working directory and folds {cmd:./} and
{cmd:dir/..} segments; on Windows it treats {cmd:\} as {cmd:/} and, as on macOS,
ignores case. It does not see through a symbolic link or a mapped drive.

{dlgtab:dataqa flow}

{pstd}
{cmd:dataqa flow step} {it:name} records, where it is typed in the
do-file, the number of rows of the data in memory and, with {opt id()}, the
number of distinct ids, as the next step of the flow {opt flow()} (default
{cmd:main}) of the run. It prints that the step was recorded and no count.
A flow belongs to its run ({opt run()}, else the session run) and lives in
the flow file next to the ledger: {it:stem}{cmd:.flow.dta}, where
{it:stem} is the ledger's file name without {cmd:.dta}, so it survives
across do-files as the ledger does (in a {opt worker()} session, the
worker's own {it:stem}{cmd:.shard-}{it:id}{cmd:.flow.dta}). The flow file
holds the exact counts, small ones included, without masking, since the
report needs them to apply the rule below: it is a working file like the
data, not an output. {cmd:dataqa set agent} and {opt safe} do not cover it
(the first step of a flow under the preset prints a note saying so), so
keep it where the data may be kept: a ledger that is to be shared should be
exported with {cmd:dataqa export}, not copied with its directory.
Recording a step name the flow already has replaces that step and every
later one, so a rerun of the do-file rebuilds the flow rather than doubling
it; {cmd:dataqa flow clear} removes the flow ({opt all}: every flow of the
run), and {cmd:dataqa set ... ledger() run() replace}, which starts the run
afresh, removes every flow step of the run too. A step with more rows or ids
than the one before prints a note that the report will fail.

{pstd}
{cmd:dataqa flow report} prints each step's remaining count and the number
excluded since the step before, as ids when every step has {opt id()} and
as rows otherwise ({opt count()} chooses). It first checks that the steps
are whole (numbered in order, each stored exclusion equal to the previous
count less this one; r(610) otherwise) and that the remaining rows never
increase, nor the ids where two consecutive steps have {opt id()}. Both are
checked whatever {opt count()} prints, so a step that adds rows fails a
flow reported as ids. A step with more than the step before fails the flow: the
step is named, nothing of the flow is printed, and the call exits 9 (0
under {cmd:dataqa set collect}). Either way one gate row, family
{cmd:flow}, dataset {cmd:flow_}{it:name}, kind invariant, is written to
the ledger, so {cmd:dataqa assert} halts on a broken flow and a passing
rerun supersedes the failure.

{pstd}
{it:Disclosure.} A count is small when it is 1 to {opt mincell()}-1; zero
is printed. Each pair of consecutive remaining counts describes nested
populations, so the number excluded between them is a cell of its own, and
a small cell can also be disclosed by subtracting two printed numbers
(differencing; Hundepool et al. 2026, sections 4.2.1 and 5.2). Applying
this to attrition steps is datamap's own choice; the handbook does not
discuss flow charts. The rule:

{phang2}1. Let L be the last step with at least {opt mincell()} remaining.
The exclusions of steps 2 to L are pooled into blocks: a step that
excludes 0 or at least {opt mincell()} is a block of its own; a step that
excludes fewer is pooled with the {it:following} step(s) until the block
excludes at least {opt mincell()}; a run of small steps at the end that
cannot reach it is pooled with the block {it:before} it.{p_end}
{phang2}2. If steps 2 to L together exclude 1 to {opt mincell()}-1, steps 2
to the last form one block whose end count (unless it is 0) and exclusion
are withheld.{p_end}
{phang2}3. When the step after L leaves 1 to {opt mincell()}-1, the steps
from there to the last form one block; its end count is withheld unless it
is 0, and then its exclusion is withheld too. When it leaves 0, every later
step is printed.{p_end}
{phang2}4. When the first count is itself small, it is withheld and the
other steps form one block, withheld but for a final 0.{p_end}

{pstd}
With {opt poolsmall} each block prints as one row naming its steps
({cmd:a + b}) with the block's total exclusion. Without it every step has
its own row, and inside a block of two or more steps every exclusion and
every count but the block's end is withheld. Every printed number is
therefore 0 or at least {opt mincell()}, and so is the difference of any
two printed remaining counts; a withheld number cannot be computed from
the printed ones. Every withheld number prints as {cmd:suppressed}, whether
it is small or would reveal a small number: a mark meaning "below
{it:m}" would narrow the values a reader has to consider (two exclusions
marked <5 in a block that excludes 8 are both 4). {opt mincell(1)} and
{opt mincell(2)} are refused, since a count withheld as small is then
known to be 1.

{dlgtab:dataqa merge}

{pstd}
In a do-file run as several parallel Stata jobs, each job types
{cmd:dataqa set ledger(}{it:ledger}{cmd:) worker(}{it:id}{cmd:)} with its
own {it:id}. Every ledger write of that job ({cmd:dataprobe}, its error
rows, {cmd:dataqa flow report}) then goes to the job's shard
{it:stem}{cmd:.shard-}{it:id}{cmd:.dta} beside the ledger (or in
{opt sharddir()}), never to the shared file, and the rows carry the column
{cmd:worker}. In that job {cmd:report}, {cmd:assert}, {cmd:export},
{cmd:compare}, and {cmd:flow} read the shard when they are not given
{cmd:using}. After the workers finish, one job types
{cmd:dataqa merge, into(}{it:ledger}{cmd:)}.

{pstd}
{cmd:dataqa merge} reads the shards of {opt into()} from its directory, or
from {opt from(dir)}; any other {opt from()} is a file pattern ({cmd:*},
{cmd:?}) every match of which must be a shard. Every shard is checked
before anything is written: its variables must be the ledger columns plus
{cmd:worker}, of the ledger's types, with one valid id on every row, and
that id must be the one its file name carries,
{it:anything}{cmd:.shard-}{it:id}{cmd:.dta}, so a copied or renamed shard
cannot pass as another worker's (r(610) otherwise); no two shards may hold the same worker (r(459)); and
the ledger may not already hold rows of that worker in a run of the shard,
which means it was merged before (r(459); {opt replace} drops those rows
first). A column the ledger and the shards share must have the same type
(r(610)). The ledger's rows stay first; the shards follow in worker-id
order, sorted as text, each in the order its worker wrote it, and
{cmd:seq} is renumbered within each run to follow that order. A call
supersedes only earlier rows of its own worker, so when two workers ran the
same gate (or the same flow) both rows stand: {cmd:report} and
{cmd:assert} count a failure in either, and {cmd:compare} reads the worst
status. Each shard gets one line naming its worker and the runs it holds,
so a stale shard of an earlier run shows; {opt run()} folds in only that
run's rows, counts the others as left out, and skips a shard with none. The merged ledger is
built in a frame and written in one save; a failed check leaves
{opt into()} as it was. A shard with no rows (a worker whose run was
cleared with {opt replace} and not rewritten) is skipped with a note;
when every shard is empty the call is r(2000). A ledger written by datamap 2.0.0 can be the
target; its rows read as phase and worker empty. Shards are kept.

{pstd}
Until a shard is merged the ledger does not hold its rows. Outside a worker
session, {cmd:dataqa assert}, {cmd:report}, and {cmd:export} of a run look
for the shards of the ledger in its directory ({it:stem}{cmd:.shard-}{it:id}{cmd:.dta},
the files {cmd:merge} reads without {opt from()}) and compare each with the
ledger: a shard row of the run (of any phase) is merged when the ledger
holds a row of the same worker equal to it in every column but {cmd:seq},
which {cmd:merge} renumbers, one ledger row for each shard row. Shards are
not deleted or marked; the comparison is made every time, so a merged shard
is not counted again, and is counted again once its worker writes new rows
to it (a rerun, which {cmd:merge, replace} then folds in) or the ledger
loses them ({cmd:dataqa set ... replace} starts the run afresh: merge the
shards again, or delete the stale files). A file with a shard's name that
cannot be read as a shard counts as unmerged. With a shard unmerged,
{cmd:assert} exits 9 naming the shards, {cmd:report} warns, and {cmd:export}
refuses (r(459)); a shard holding rows of other runs only does not count.
Shards written to another directory with {opt sharddir()} are not found
this way: merge them with {opt from()} before asserting. Before the merge a
worker's failure therefore halts {cmd:assert} as an unmerged shard, and
after it as a failed row that no other worker's pass of the same gate
supersedes. A worker session's own {cmd:assert} reads its shard as
before.

{dlgtab:dataqa compare}

{pstd}
{cmd:dataqa compare} matches the rows of {opt run()} with those of
{opt baseline()} on dataset, family, label, variable, group, scope,
expectation, and kind, in the same ledger or in {opt baseledger()}. A gate whose bounds
changed is therefore a different gate: its baseline row is flagged as
absent. Each side contributes the row of the gate that stands, as {cmd:report}
and {cmd:assert} read it: when a rerun on {bf:(modified)} data could not
supersede a row of the unmodified data, both stand, and the row with the worst
status (error, fail, warn, review, pass) is compared, then the unmodified row,
then the later call. A {cmd:by()} group is matched on its values ({cmd:site=3 year=2015}), so a level added
between extracts is reported as a new group ({cmd:new}) and every other group still pairs
with itself. A ledger written before 1.9.0, and a group withheld under {opt maskrare}, record
the group as its number within the call; two such runs still compare among themselves, but
a number can name a different level if the data change. When one run records a gate's groups by
number and the other by value, {cmd:compare} prints {cmd:mixed}, counts one item to review,
and pairs none of that gate's groups; re-run the baseline to compare them. It flags a change in rows in scope beyond
{opt ntol()} (a share, default 0.05), a change in a {opt stat()} value beyond
{opt stattol()} (a relative change, default 0.05), a changed
{help datasignature}, and a gate present in the baseline but absent now; an
N or {opt stat()} flag of a {cmd:by()} call names its group in brackets. A
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
{opt agent} sets the agent-safe preset for the session: {cmd:datamap},
{cmd:dataprobe}, and {cmd:datamvp} run as if {opt safe} were typed until
{cmd:dataqa set clear}, and {cmd:nomaskrare} cannot turn it off. It may be
followed by other options. The limits of {opt safe} are stated under
{help dataqa##subcommands:dataqa set} and in {help datamap##safe:datamap}.

{phang}
{opt mask:rare} turns on {opt maskrare} in every later {cmd:dataprobe} and
{cmd:datamvp} call, so no small count is printed. A call that types
{cmd:nomaskrare} overrides it.

{phang}
{opt min:cell(#)} sets the mask threshold, a nonnegative integer, passed to
both commands as {opt mincell()}; a negative value is r(198) and leaves the
defaults as they were. Without it, the threshold under
{opt maskrare} is {opt rare()} or 5 in {cmd:dataprobe} and 5 in {cmd:datamvp}.

{phang}
{opt led:ger(filename)} names the ledger every later {cmd:dataprobe} call
appends to, as with its {opt ledger()} option. {opt .dta} is added to a
filename without a suffix, as {cmd:save} does; a name with any other suffix, such as
{cmd:qa.v2} or a {cmd:tempfile} path, is used as given. Every
{cmd:dataqa} subcommand and {cmd:dataprobe} read and write the same
file under this rule.

{phang}
{opt worker(id)} makes this Stata job one of several parallel workers: its
ledger writes go to its own shard of the ledger
({help dataqa##subcommands:dataqa merge}), so jobs never write one file at
the same time. {it:id} is 1 to 32 letters, digits, underscores, or
hyphens, different for every job (two jobs with one id share a shard). It
requires {opt ledger()}. {opt replace} then clears the run's rows from the
shard, not the ledger. {cmd:r(shard)} names the shard.

{phang}
{opt shard:dir(dir)} puts the shard in the existing directory {it:dir}
rather than beside the ledger. It requires {opt worker()}.

{phang}
{opt run(string)} labels the ledger rows of this session, such as the date of
the run. It requires {opt ledger()} and may not contain parentheses, quotes,
backslashes, or the shell characters {cmd:; & | < > $} and the backtick.

{phang}
{opt phase(name)} tags the ledger rows of this session's {cmd:dataprobe}
calls with a phase, such as {cmd:build} or {cmd:analysis}; a call's own
{opt phase()} overrides it. It requires {opt ledger()} and must be a valid
Stata name (r(198) otherwise).

{phang}
{opt base:line(string)} names the baseline run that {cmd:dataqa compare} and
{cmd:dataqa assert} hold the current run against when they are not given
{opt baseline()}, so a do-file need not retype it. An explicit
{opt baseline()} on the call wins. {cmd:dataqa set} replaces the whole
specification, so a call without {opt baseline()}, or with
{cmd:baseline("")}, leaves no baseline; this is how a synthetic run switches
it off. The same quoting limits as {opt run()} apply. With only a session
baseline, {cmd:dataqa assert} runs the baseline check described there, and
a baseline with no rows is r(2000) there, as with an explicit one. {cmd:dataqa compare}
says it has no rows and exits 0.

{phang}
{opt baseled:ger(filename)} is the ledger file that holds the baseline run; without
it the baseline is read from the ledger of the current run. It
requires {opt baseline()} (r(198) otherwise) and takes the same suffix rule as
{opt ledger()}. It goes with the session baseline: a call that types its own
{opt baseline()} but no {opt baseledger()} reads that baseline from the ledger of
the current run. An explicit {opt baseledger()} wins over the session one.

{phang}
{opt bandwarn} turns on {opt bandwarn} in every later {cmd:dataprobe} call,
so failing sanity bands warn while invariants still halt. Set it only for a
synthetic run, where the bands are not calibrated.

{phang}
{opt sig:nature} turns on {opt signature} in every later {cmd:dataprobe}
call, so the ledger records each dataset's {help datasignature}.

{phang}
{opt collect} makes a {cmd:dataprobe} call under a ledger record a gate failure
instead of halting on it. The call still prints its violation block and writes
its rows, but it returns 0 with {cmd:r(n_failed)} and {cmd:r(n_errors)} set, and
prints one line saying the failures were recorded and that {cmd:dataqa assert}
will halt; {cmd:dataqa assert} stays the single halting point. Without a ledger
({cmd:dataqa set ledger()} or {opt ledger()} on the call) {opt collect} has no
effect and a failed gate exits 9, with a note. If the ledger append fails, the
call exits nonzero as before. An error that is not a gate failure halts and
leaves an error row (see below), unless the call also gives {cmd:dataprobe}'s
{opt softcollect}, which records the error row and continues; {cmd:dataqa assert}
still fails on that row. Without {opt collect} a failed gate exits 9
everywhere. {cmd:dataqa set clear} removes it with the other defaults.

{phang}
{opt replace} removes the rows of {opt run()} from {opt ledger()} when the
defaults are set, so the run starts afresh; rows of other runs are kept. It
requires both {opt ledger()} and {opt run()}, acts once, and is not stored
with the defaults. A file that is not a dataprobe ledger is refused with
r(610) and left untouched. The run's {cmd:dataqa flow} steps, every flow,
are removed from the flow file too (the worker's own under {opt worker()}).

{dlgtab:Options for report, assert, export, and compare}

{phang}
{opt run(string)} selects the run to read. It defaults to the run set by
{cmd:dataqa set}. {cmd:dataqa report} reads every run when neither is given; {cmd:dataqa assert},
{cmd:dataqa export}, and {cmd:dataqa compare} require one.

{phang}
{opt phase(names)} reads only the rows of the listed phases, plus every
call error row of the run (see {help dataqa##description:Description}). In
{cmd:compare} it applies to both runs, and in {cmd:assert} to the baseline
check as well.

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
{opt pend:ing(names)} ({cmd:assert}) lists phases whose baseline datasets and
gates may have no rows yet; such a dataset or gate is reported as
{bf:PENDING} and does not halt. It requires {opt baseline()}.

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


{dlgtab:Options for flow}

{phang}
{opt led:ger(filename)} names the ledger whose flow file the steps go to
and whose rows the flow gate is written to; the default is the session
ledger. {opt run(string)} is the run, default the session run.

{phang}
{opt flow(name)} names the flow, default {cmd:main}; a run can hold several.

{phang}
{opt phase(name)} ({cmd:report}) is the phase of the flow gate row written
to the ledger, as {cmd:dataprobe}'s {opt phase()} is for its rows; without
it the row takes the session phase ({cmd:dataqa set phase()}), else none.
{cmd:dataqa flow step} takes no phase: the steps go to the flow file, not
the ledger.

{phang}
{opt all} ({cmd:clear}) clears every flow of the run; it cannot be combined
with {opt flow()}.

{phang}
{opt id(varname)} ({cmd:step}) counts distinct ids as well as rows. An id
missing in any row is r(416).

{phang}
{opt lab:el(string)} ({cmd:step}) is the step's description, printed and
exported as typed.

{phang}
{opt min:cell(#)} ({cmd:report}) is the threshold; the default is the
session {opt mincell()} when it is positive, else 5. It must be 0 (nothing withheld) or 3 or
more, and at least 5 under {cmd:dataqa set agent}.

{phang}
{opt pool:small} ({cmd:report}) prints each block of pooled steps as one
row instead of one row per step with the block withheld.

{phang}
{opt count(ids|rows)} ({cmd:report}) chooses the counts printed; {cmd:ids}
needs {opt id()} on every step.

{phang}
{opt exp:ort(filename)} ({cmd:report}) writes the printed table, withheld
numbers included as {cmd:suppressed}, to a {cmd:.md} or {cmd:.csv} file;
{opt replace} permits overwriting it.

{dlgtab:Options for merge}

{phang}
{opt into(ledger)} is the ledger the shards are folded into; it is created
when absent. {opt from(dir|pattern)} is where the shards are read (see
above). {opt run(string)} folds in only the rows of that run.
{opt replace} replaces rows of a worker already merged.


{marker dispositions}{...}
{title:Dispositions}

{pstd}
The kind of a failed row, fixed where its gate was declared (see
{help dataprobe##kinds:dataprobe}), limits the dispositions the register may
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
{phang2}{cmd:. dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)}{p_end}
{phang2}{cmd:. sysuse lifeexp, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(country) name(lifeexp)}{p_end}

{pstd}Summarize, draft the register, and assert that both datasets were checked:{p_end}
{phang2}{cmd:. dataqa report}{p_end}
{phang2}{cmd:. dataqa assert, expect(auto_cars lifeexp)}{p_end}
{phang2}{cmd:. dataqa report, bands}{p_end}

{pstd}Hold a later run against the first: a dataset that vanished halts, unless it is optional:{p_end}
{phang2}{cmd:. dataqa assert, run(rerun) baseline(demo) optional(lifeexp)}{p_end}

{pstd}Write the release copy of the run to its own file, never over the working ledger:{p_end}
{phang2}{cmd:. dataqa export, saving("qa_ledger_release_demo.dta") replace}{p_end}

{pstd}Two phases: a first run tags its build and analysis gates; the next
run asserts its build phase against it while the analysis datasets are still
pending, then the whole run once the analysis gates have run:{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`ledger'") run(p1) phase(build)}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) name(auto_cars)}{p_end}
{phang2}{cmd:. sysuse lifeexp, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(country) name(lifeexp) phase(analysis)}{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`ledger'") run(p2) phase(build)}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) name(auto_cars)}{p_end}
{phang2}{cmd:. dataqa assert, baseline(p1) pending(analysis)}{p_end}
{phang2}{cmd:. sysuse lifeexp, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(country) name(lifeexp) phase(analysis)}{p_end}
{phang2}{cmd:. dataqa report, phase(analysis)}{p_end}
{phang2}{cmd:. dataqa assert, baseline(p1)}{p_end}

{pstd}Clear the defaults:{p_end}
{phang2}{cmd:. dataqa set clear}{p_end}

{pstd}A cohort flow, recorded as the do-file narrows the data and printed
with any small steps pooled:{p_end}
{phang2}{cmd:. tempfile fl}{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`fl'") run(f1)}{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. dataqa flow step all, id(idcode) label("All women")}{p_end}
{phang2}{cmd:. drop if missing(wage, hours, tenure)}{p_end}
{phang2}{cmd:. dataqa flow step complete, id(idcode) label("Wage, hours and tenure known")}{p_end}
{phang2}{cmd:. drop if age > 44}{p_end}
{phang2}{cmd:. dataqa flow step age, id(idcode) label("Aged 44 or less")}{p_end}
{phang2}{cmd:. dataqa flow report, poolsmall}{p_end}
{phang2}{cmd:. dataqa assert, expect(flow_main)}{p_end}

{pstd}Parallel workers, each in its own Stata job, then one merge:{p_end}
{phang2}{cmd:. dataqa set ledger("qa_ledger.dta") run(r1) worker(w1)}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) name(auto_cars)}{p_end}
{phang2}{cmd:. * ... and in the job that runs after the workers:}{p_end}
{phang2}{cmd:. dataqa set ledger("qa_ledger.dta") run(r1)}{p_end}
{phang2}{cmd:. dataqa merge, into("qa_ledger.dta")}{p_end}
{phang2}{cmd:. dataqa assert, expect(auto_cars)}{p_end}

{pstd}In a do-file rerun under the same run label, start the run afresh and name the release copy apart from the ledger:{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("$working/qa_ledger_$dt.dta") run($dt) replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) name(auto_cars)}{p_end}
{phang2}{cmd:. dataqa export, saving("$output/qa_ledger_release_$dt.dta") replace}{p_end}

{pstd}A whole pipeline, in the form a study do-file takes. An earlier run stands
as the baseline; the session holds the baseline once, and a synthetic switch
blanks it:{p_end}
{phang2}{cmd:. tempfile ledger qalog md release}{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`ledger'") run(base) replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)}{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(idcode) bands(stat(mean age 38 41)) name(nlsw)}{p_end}
{phang2}{cmd:. capture dataprobe, minversion(1.9.0)}{p_end}
{phang2}{cmd:. if _rc display as error "datamap 1.9.0 or later is needed"}{p_end}
{phang2}{cmd:. global qa_synth 0}{p_end}
{phang2}{cmd:. global qa_baseline = cond($qa_synth, "", "base")}{p_end}
{phang2}{cmd:. dataqa set maskrare mincell(5) ledger("`ledger'") run(now) collect baseline($qa_baseline) replace}{p_end}
{phang2}{cmd:. log using "`qalog'", name(qa) text replace}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)}{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. dataprobe, gatesonly isid(idcode) bands(stat(mean age 38 41)) name(nlsw)}{p_end}
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
them. {cmd:dataqa report} and {cmd:dataqa assert} store {cmd:r(n_unmerged)},
the worker shards holding rows of the run that the ledger does not (0 in a
worker session). {cmd:dataqa report}
stores {cmd:r(N)} (rows read after that), {cmd:r(n_datasets)}, {cmd:r(n_failed)},
{cmd:r(n_warned)}, {cmd:r(ledger)}, {cmd:r(run)}, with {opt markdown()}
{cmd:r(markdown)} and {cmd:r(n_rows)}, and with {opt bands} {cmd:r(n_bands)}. {cmd:dataqa assert}
stores {cmd:r(N)}, {cmd:r(n_failed)}, {cmd:r(n_errors)} (error rows, included in
{cmd:r(n_failed)}),
{cmd:r(missing)} (expected datasets without rows), and
{cmd:r(run)}, also when it halts with r(9). With {opt baseline()} it also stores
{cmd:r(baseline)}, {cmd:r(n_missing_base)} and {cmd:r(missing_base)} (baseline
datasets without rows now, each in compound quotes),
{cmd:r(n_optional_absent)} and {cmd:r(optional_absent)} (those waived by
{opt optional()}); the baseline may come from {cmd:dataqa set baseline()}. With
{opt pending()} it stores {cmd:r(n_pending)} and {cmd:r(pending)} (datasets
reported as pending, each in compound quotes) and {cmd:r(n_pending_gates)}
(gates of a pending phase listed as pending in datasets that have rows). {cmd:dataqa report},
{cmd:dataqa assert}, {cmd:dataqa export}, and {cmd:dataqa compare} store
{cmd:r(phase)}, the phases read, when {opt phase()} is given. {cmd:dataqa export}
stores {cmd:r(N)}, {cmd:r(n_scope_dropped)}, {cmd:r(n_text_dropped)} (expected,
label, and message texts blanked), {cmd:r(n_sig_dropped)} (signatures blanked),
and {cmd:r(saving)}. {cmd:dataqa compare}
stores {cmd:r(n_flags)} and {cmd:r(baseline)}, and with {opt baseline()}
{cmd:r(run)}. With {opt worker()}, {cmd:dataqa set} also stores
{cmd:r(shard)}.

{pstd}
{cmd:dataqa flow step} stores {cmd:r(step)} (its number), {cmd:r(name)},
{cmd:r(flow)}, {cmd:r(run)}, and {cmd:r(flowfile)}; no count.
{cmd:dataqa flow report} stores {cmd:r(status)} ({cmd:pass} or
{cmd:fail}), {cmd:r(flow)}, {cmd:r(run)}, and {cmd:r(n_steps)}; on a
failure {cmd:r(bad_step)}, the step that adds rows or ids; on a pass
{cmd:r(count)} ({cmd:ids} or {cmd:rows}), {cmd:r(steps)} (the step names),
{cmd:r(n_rows)} (rows printed), {cmd:r(n_masked)} (numbers withheld),
{cmd:r(n_pooled)} (steps in a block of two or more), {cmd:r(mincell)},
with {opt export()} {cmd:r(export)}, and the matrix {cmd:r(table)}, one
row per printed row (named by its last step) with columns {cmd:first} and
{cmd:last} (the steps it covers), {cmd:remaining}, and {cmd:excluded}
(missing on the first row); a withheld number is {cmd:.m}, so the matrix
holds no more than the console. {cmd:dataqa flow clear} stores
{cmd:r(n_cleared)}, {cmd:r(found)} (1 when the flow file exists),
{cmd:r(flowfile)}, and, without {opt all}, {cmd:r(flow)}. {cmd:dataqa set}
with {opt replace} also stores {cmd:r(n_flow_removed)}, the flow steps of
the run removed, when the flow file exists.

{pstd}
{cmd:dataqa merge} stores {cmd:r(into)}, {cmd:r(workers)} (the worker ids
in merge order), {cmd:r(n_shards)} (shards merged), {cmd:r(n_skipped)} (shards
skipped as empty, or with no row of {opt run()}), {cmd:r(n_added)} (rows added),
{cmd:r(n_replaced)} (rows of earlier merges replaced), and {cmd:r(N)}
(rows in the merged ledger).


{marker references}{...}
{title:References}

{phang}
Hundepool A, Domingo-Ferrer J, Franconi L, Giessing S, Lenz R, Naylor J,
Schulte Nordholt E, Seri G, De Wolf P-P, Tent R, Mlodak A, Gussenbauer J,
Wilak K. 2026. {it:Handbook on Statistical Disclosure Control}. 2nd ed.
Centre of Excellence on Statistical Disclosure Control.
{browse "https://sdctools.github.io/HandbookSDC/"}{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}


{title:Also see}

{psee}
{help dataprobe}, {help datamvp}, {help datamap}
{p_end}

{hline}

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
{cmd:dataqa report} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt mark:down(filename)} {opt replace}]

{p 8 17 2}
{cmd:dataqa assert} [{cmd:using} {it:ledger}] [{cmd:,} {opt run(string)} {opt exp:ect(names)}]

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
{synopt:{opt bandwarn}}make sanity bands warn (synthetic runs){p_end}
{synopt:{opt sig:nature}}record each dataset's {help datasignature}{p_end}
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
Precedence is: an option typed on the command line, then the session default,
then a {opt config()} file. An explicit {cmd:nomaskrare} overrides a session
{opt maskrare}, and {cmd:datacheck} prints a note when it does. Every PASS line
and violation heading ends with the active masking, such as {bf:[masked <5]},
so a log shows that masking was on.

{dlgtab:dataqa report}

{pstd}
{cmd:dataqa report} prints, per dataset, the number of calls, gate entries,
failures, warnings, and review items. {opt markdown(filename)} writes draft
register rows in the column order Run | Dataset | Check | Observed |
Expectation and source | Disposition | Date | PI consulted. The Check cell
follows one grammar, {it:family}{cmd:(}{it:label}{cmd:):} {it:observed}
{cmd:against} {it:expected} [{it:group}], built from the ledger's columns. A
dataset whose gates all passed gets one row listing its families, the
register's clean-run row. Each failed, warned, or review row is left
{bf:open}, with its kind and the dispositions that kind allows; the source of
each expectation lives in the plan and is left for the analyst.

{dlgtab:dataqa assert}

{pstd}
{cmd:dataqa assert} exits with return code 9 if any row of the run failed, if
an invariant was downgraded by bare {cmd:warn}, if the run has no rows, or if a
dataset named in {opt expect()} has no rows in the run. The last condition makes
the review-loop rule "a QA dataset line not followed by a verdict" mechanical: placed
last in the QA section, it catches a gate call deleted by mistake. A
name in {opt expect()} matches a dataset recorded under that name, with or
without {bf:(modified)}.

{dlgtab:dataqa export}

{pstd}
{cmd:dataqa export} writes the release copy of one run to {opt saving()}. It
refuses with r(459) when any row comes from a call not run under
{opt maskrare} with a threshold of at least 5, when any row was masked below
{opt threshold()} (default 5), when any row prints a count between 1 and
{opt threshold()}-1, or when a masked row keeps {cmd:observed_num}. The copy
blanks {cmd:scope} expressions that contain a quoted string or a number of four
or more digits, which may be an identifier written in a hurry. The working
ledger stays on the server; only the exported copy leaves it.

{dlgtab:dataqa compare}

{pstd}
{cmd:dataqa compare} matches the rows of {opt run()} with those of
{opt baseline()} on dataset, family, label, variable, group, and scope, in the
same ledger or in {opt baseledger()}. It flags a change in rows in scope beyond
{opt ntol()} (a share, default 0.05), a change in a {opt stat()} value beyond
{opt stattol()} (a relative change, default 0.05), a changed
{help datasignature}, and a gate present in the baseline but absent now. A
count or {opt stat()} value withheld under the mask (or, for {opt stat()},
undefined) in one run and shown in the other is flagged without printing the
withheld number; against a baseline of 0 any change is flagged. The
output has review severity and never halts. With no {opt baseline()}, it prints
a note and exits 0, as on the first run on an extract.


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
filename without an extension.

{phang}
{opt run(string)} labels the ledger rows of this session, such as the date of
the run. It requires {opt ledger()} and may not contain parentheses, quotes,
backslashes, or the shell characters {cmd:; & | < > $} and the backtick.

{phang}
{opt bandwarn} turns on {opt bandwarn} in every later {cmd:datacheck} call,
so failing sanity bands warn while invariants still halt. Set it only for a
synthetic run, where the bands are not calibrated.

{phang}
{opt sig:nature} turns on {opt signature} in every later {cmd:datacheck}
call, so the ledger records each dataset's {help datasignature}.

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
{opt sav:ing(filename)} ({cmd:export}) is required and names the release copy. {opt .dta}
is added to a filename without an extension, and {opt replace}
permits overwriting an existing file.

{phang}
{opt thr:eshold(#)} ({cmd:export}) is the house mask threshold, a positive
integer; the default is 5.

{phang}
{opt base:line(string)} ({cmd:compare}) is the run label of the baseline run.

{phang}
{opt baseled:ger(filename)} ({cmd:compare}) names the ledger that holds the
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

{pstd}Clear the defaults:{p_end}
{phang2}{cmd:. dataqa set clear}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:dataqa set} stores {cmd:r(defaults)}, the option string. {cmd:dataqa report}
stores {cmd:r(N)} (rows read), {cmd:r(n_datasets)}, {cmd:r(n_failed)},
{cmd:r(n_warned)}, {cmd:r(ledger)}, {cmd:r(run)}, and with {opt markdown()}
{cmd:r(markdown)} and {cmd:r(n_rows)}. {cmd:dataqa assert} stores {cmd:r(N)},
{cmd:r(n_failed)}, {cmd:r(missing)} (expected datasets without rows), and
{cmd:r(run)}, also when it halts with r(9). {cmd:dataqa export} stores
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

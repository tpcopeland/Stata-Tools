{smcl}
{* Help for tvbuild. The package version lives in tvtools.sthlp only.}{...}
{vieweralsosee "tvspec" "help tvspec"}{...}
{vieweralsosee "tvexpose" "help tvexpose"}{...}
{vieweralsosee "tvmerge" "help tvmerge"}{...}
{vieweralsosee "tvevent" "help tvevent"}{...}
{vieweralsosee "tvdiagnose" "help tvdiagnose"}{...}
{vieweralsosee "tvweight" "help tvweight"}{...}
{vieweralsosee "tvtools" "help tvtools"}{...}
{viewerjumpto "Syntax" "tvbuild##syntax"}{...}
{viewerjumpto "Description" "tvbuild##description"}{...}
{viewerjumpto "Options" "tvbuild##options"}{...}
{viewerjumpto "Specification frame" "tvbuild##specframe"}{...}
{viewerjumpto "Dry run" "tvbuild##dryrun"}{...}
{viewerjumpto "Output" "tvbuild##output"}{...}
{viewerjumpto "Provenance" "tvbuild##provenance"}{...}
{viewerjumpto "Stored results" "tvbuild##results"}{...}
{viewerjumpto "Examples" "tvbuild##examples"}{...}

{title:Title}

{phang}
{bf:tvbuild} {hline 2} Build a committed, analysis-ready interval frame from a
cohort and one or more longitudinal sources


{marker syntax}{...}
{title:Syntax}

{pstd}Canonical multi-source form{p_end}

{p 8 17 2}
{cmd:tvbuild}{cmd:,}
{opt spec:frame(name)}
{opt id(varname)}
{opt ent:ry(varname)}
{opt exi:t(varname)}
{opt frameo:ut(name)}
[{it:options}]

{pstd}One-source categorical shortcut{p_end}

{p 8 17 2}
{cmd:tvbuild}{cmd:,}
{c -(}{opt sourcef:rame(name)}{cmd:|}{opt sourceu:sing(filename)}{c )-}
{opt id(varname)}
{opt ent:ry(varname)}
{opt exi:t(varname)}
{opt start(name)}
{opt stop(name)}
{opt expos:ure(name)}
{opt ref:erence(#)}
{opt gen:erate(name)}
{opt frameo:ut(name)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person identifier{p_end}
{synopt:{opt ent:ry(varname)}}study entry date in the master{p_end}
{synopt:{opt exi:t(varname)}}study exit date in the master{p_end}
{synopt:{opt frameo:ut(name)}}destination frame for the committed result{p_end}

{syntab:Multi-source form}
{synopt:{opt spec:frame(name)}}specification frame, one row per source{p_end}

{syntab:One-source inline form}
{synopt:{opt sourcef:rame(name)}}source frame holding raw episodes{p_end}
{synopt:{opt sourceu:sing(filename)}}source file holding raw episodes{p_end}
{synopt:{opt sourcen:ame(name)}}logical source name; defaults to {opt generate()}{p_end}
{synopt:{opt start(name)}}episode start variable in the source{p_end}
{synopt:{opt stop(name)}}episode stop variable in the source{p_end}
{synopt:{opt expos:ure(name)}}episode category variable in the source{p_end}
{synopt:{opt ref:erence(#)}}whole category code for uncovered time{p_end}
{synopt:{opt gen:erate(name)}}output exposure variable{p_end}
{synopt:{opt referencel:abel(string)}}value label for the reference category{p_end}
{synopt:{opt lab:el(string)}}variable label for the output exposure{p_end}

{syntab:Output naming}
{synopt:{opt startn:ame(name)}}output start variable; default {cmd:start}{p_end}
{synopt:{opt stopn:ame(name)}}output stop variable; default {cmd:stop}{p_end}
{synopt:{opt datef:ormat(fmt)}}output date format; default {cmd:%tdCCYY/NN/DD}{p_end}
{synopt:{opt keep:vars(varlist)}}extra master variables carried through{p_end}
{synopt:{opt dropd:ates}}omit {opt entry()} and {opt exit()} from the output{p_end}

{syntab:Coverage}
{synopt:{opt cov:erage(strict|allow)}}gap policy; default {cmd:strict}{p_end}

{syntab:Event stage}
{synopt:{opt eventd:ate(name)}}event date variable or recurring wide stub{p_end}
{synopt:{opt eventf:rame(name)}}frame holding the event data{p_end}
{synopt:{opt eventu:sing(filename)}}file holding the event data{p_end}
{synopt:{opt eventt:ype(single|recurring)}}event structure; default {cmd:single}{p_end}
{synopt:{opt com:pete(namelist)}}competing-risk date variables{p_end}
{synopt:{opt eventg:enerate(name)}}event indicator; default {cmd:_failure}{p_end}
{synopt:{opt eventl:abel(string)}}value label for the event indicator{p_end}
{synopt:{opt timeg:en(name)}}elapsed-time variable{p_end}
{synopt:{opt timeu:nit(days|months|years)}}unit for {opt timegen()}; default {cmd:days}{p_end}
{synopt:{opt enum(name)}}recurrent-event stratum{p_end}
{synopt:{opt gapt:ime}}produce gap-time bounds{p_end}
{synopt:{opt gapsta:rt(name)}}gap-time start; default {cmd:_t0}{p_end}
{synopt:{opt gapsto:p(name)}}gap-time stop; default {cmd:_t}{p_end}

{syntab:Transaction}
{synopt:{opt manifest:frame(name)}}manifest frame; default {it:frameout}{cmd:_manifest}{p_end}
{synopt:{opt noman:ifest}}do not build a provenance manifest{p_end}
{synopt:{opt dry:run}}validate and print the plan; change nothing{p_end}
{synopt:{opt rep:lace}}allow replacement of a destination frame{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tvbuild} turns a person-level cohort plus one or more longitudinal sources
into a committed interval frame. It composes exposure construction, interval
alignment, optional event integration, structural validation, and provenance.

{pstd}
The current frame is the person-level master, with one row per person. Select
a different master idiomatically with the {cmd:frame} {it:name}{cmd::} prefix; there is no
separate master-file parser. {opt frameout()} is required and {cmd:tvbuild} never replaces
the master.

{pstd}
{cmd:tvbuild} automates record construction, not scientific decisions. It does {it:not}
run {helpb tvdiagnose}, {helpb tvweight}, {helpb stset}, or an outcome model, and it does not choose
an overlap-resolution rule, weighting specification, truncation threshold,
time scale, estimand, or causal model. Those choices stay visible and
scriptable.

{pstd}
{cmd:tvbuild} is a coordinator over the shared {helpb tvexpose},
{helpb tvmerge}, and {helpb tvevent} engines, not a fourth implementation of
interval semantics. Raw categorical episodes are tiled by the shared
{cmd:tvexpose} constructor, several sources are aligned by the shared
{cmd:tvmerge} interval engine, and events are placed by the shared
{cmd:tvevent} engine, so a {cmd:tvbuild} result is what the equivalent sequence
of primitive calls produces.

{pstd}
Every stage runs in a scratch frame. The master, the specification frame, and
every source and event input frame are read and never written, and the output
and the optional manifest are committed as one transaction: on any failure,
every user-owned frame is left exactly as it was found.


{marker options}{...}
{title:Options}

{dlgtab:Input form}

{phang}
{opt specframe(name)} names a frame with one row per source, described under
{it:{help tvbuild##specframe:Specification frame}} below. Observation order is
semantic: it fixes generated-variable order, merge order, deterministic row
ties, displayed plan order, and manifest order. {cmd:tvbuild} never sorts it.

{phang}
{opt specframe()} is mutually exclusive with every inline-source
option: {opt sourceframe()}, {opt sourceusing()}, {opt sourcename()}, {opt start()}, {opt stop()},
{opt exposure()}, {opt reference()}, {opt generate()}, {opt referencelabel()}, and {opt label()}.

{phang}
The inline form requires exactly one of {opt sourceframe()} and
{opt sourceusing()} and always normalizes to one raw-episode source. A
ready-made interval source is declared through {opt specframe()}.

{phang}
{opt id(varname)} names the person identifier. It must exist under exactly
this name in the master, in every source, and in any separate event input, and
its storage class must agree everywhere; {cmd:tvbuild} never converts an
identifier. {cmd:strL} identifiers are refused.

{phang}
{opt entry(varname)} and {opt exit(varname)} name the study window in the master. Both are
whole nonmissing daily dates with {opt entry()} no later than {opt exit()}. They are
retained in the output by default, which makes the result auditable and
immediately usable by {helpb tvdiagnose}; {opt dropdates} omits them.

{phang}
{opt frameout(name)} names the destination frame and is required, in a dry run
as well as a real one, so destination ownership and collisions are checked
before any work begins. It may not name the master, the specification frame,
any input source or event frame, or {opt manifestframe()}.

{dlgtab:Output naming}

{phang}
{opt startname(name)} and {opt stopname(name)} name the output interval
bounds. Defaults are {cmd:start} and {cmd:stop}.

{phang}
{opt dateformat(fmt)} is the display format applied to the output bounds,
which are numeric doubles. The default is {cmd:%tdCCYY/NN/DD}, and any valid
Stata daily-date format may be used.

{phang}
{opt keepvars(varlist)} names additional master variables to carry into the
output. The master is one row per person, so these are constant by
construction. They are attached once, after construction, rather than copied
into every intermediate source.

{phang}
{opt dropdates} omits {opt entry()} and {opt exit()} from the output.

{dlgtab:Transaction}

{phang}
{opt manifestframe(name)} requests a provenance manifest with one row per
stage, in execution order. It is committed in the same transaction as the
output: neither is committed unless both verify.

{phang}
{opt dryrun} validates and prints the plan and changes nothing; see
{it:{help tvbuild##dryrun:Dry run}} below.

{phang}
{opt replace} authorizes replacing an existing {opt frameout()} and, when
specified, an existing {opt manifestframe()}. It never authorizes an
input/output alias or an output-name collision.

{phang}
{opt replace} authorizes replacing a destination you {it:named}. It does not
authorize replacing a frame whose name {cmd:tvbuild} derived. If
{opt manifestframe()} is omitted and a frame already sits at the derived name
{it:frameout}{cmd:_manifest}, {cmd:tvbuild} exits with {cmd:r(198)} on both
sides of {opt replace}, and names the two ways out: supply
{opt manifestframe()} yourself, or specify {opt nomanifest}. The one exception
is a frame {cmd:tvbuild} itself wrote there -- its own manifest from an earlier
run -- so a repeated call and a re-run after dropping only {opt frameout()}
both work as expected.

{phang}
That exception is recognized by two things together, and neither alone
qualifies a frame: the characteristic {cmd:_dta[tvtools_manifest]} reading
{cmd:tvbuild}, {it:and} the manifest column schema. A frame carrying the
manifest columns without the characteristic is a frame of yours that happens to
share the layout; a frame carrying the characteristic without the columns is a
frame of yours wearing the label, since a characteristic is something any
command or user can set. Both are refused.

{phang}
{opt manifestframe(name)} names the provenance manifest frame. When it is
omitted, {cmd:tvbuild} builds one at {it:frameout}{cmd:_manifest}; the
committed frame and its manifest are one transaction, so the record of what ran
arrives with the result rather than only when it is asked for. A Stata name
holds 32 characters and the suffix is 9 of them, so a {opt frameout()} longer
than 23 characters cannot carry the derived name: that is {cmd:r(198)} naming
the limit, never a truncated frame name.

{phang}
{opt nomanifest} builds no manifest and leaves {cmd:r(manifestframe)} empty. It
reproduces the pre-1.12.0 behavior exactly: the committed {opt frameout()}
frame is byte-identical with and without it. {opt nomanifest} may not be
combined with {opt manifestframe()}.

{dlgtab:Sources}

{phang}
A raw {cmd:episodes} source is the safe, common categorical definition: whole
numeric category codes, whole nonmissing daily bounds with start no later than
stop, no source row coded to {opt reference()} after clipping, and no within-person
overlap after clipping -- a shared closed endpoint included. Source ids absent
from the master are counted and ignored; master ids with no retained episode
receive one full-window reference interval.

{phang}
If a raw source needs point-time carry-forward, grace, lag, washout, duration,
dose, recency, overlap resolution, {cmd:bytype}, switching, state time,
noninteger categories, or another advanced {helpb tvexpose} mode,
{cmd:tvbuild} refuses during preflight and names the remedy: run
{cmd:tvexpose} explicitly into a frame, then declare that frame as
{cmd:source_kind=="intervals"}. It never silently chooses an engine or an
overlap policy for you.

{phang}
A ready {cmd:intervals} source must contain every master person, use whole
nonmissing closed daily bounds inside that person's window, carry nonmissing
values for every declared input variable, and satisfy the quantity metadata it
declares. {cmd:tvbuild} does not clip or reinterpret an already-constructed
source.

{dlgtab:Coverage}

{phang}
{opt coverage(strict)}, the default, requires every ready interval source to
cover every day of every person's window. {opt coverage(allow)} permits
positive gaps, but never fills, carries forward, or guesses a value; it warns,
records the gap counts, and marks the result so downstream code cannot mistake
the choice for the default.

{dlgtab:Event stage}

{phang}
{opt eventdate()} activates the event stage; every other event option requires
it. With neither {opt eventframe()} nor {opt eventusing()}, the event
variables are read from the master. {opt compete()} is allowed with
{opt eventtype(single)} only; {opt enum()}, {opt gaptime}, {opt gapstart()},
and {opt gapstop()} with {opt eventtype(recurring)} only.

{phang}
{opt eventframe(name)} and {opt eventusing(filename)} name a separate,
read-only event input and are mutually exclusive. A file is loaded once, and a
locator already loaded for a source role is reused rather than read again.

{phang}
{opt eventtype(single|recurring)} selects the event structure and defaults to
{cmd:single}. {opt eventdate()} names a numeric daily-date variable under
{cmd:single} and the contiguous wide stub under {cmd:recurring}.

{phang}
{opt eventgenerate(name)} names the event indicator. The default is
{cmd:_failure}.

{phang}
{opt eventlabel(string)} supplies the value label for the event indicator,
using the {helpb tvevent} label grammar.

{phang}
{opt timegen(name)} creates an elapsed-time variable and {opt timeunit()}
gives its unit, defaulting to {cmd:days}. {opt timeunit()} is invalid without
{opt timegen()}.

{phang}
{opt enum(name)}, {opt gaptime}, {opt gapstart(name)}, and {opt gapstop(name)}
carry the existing recurrent-event contracts. {opt gapstart()} and
{opt gapstop()} require {opt gaptime}; under it they default to {cmd:_t0} and
{cmd:_t}.


{marker specframe}{...}
{title:Specification frame}

{pstd}
The specification frame has one row per source. Nine columns are required even
when a cell is intentionally empty; six are optional. An unknown column is an
error, so a misspelling such as {cmd:total_var} cannot silently change the
quantity algebra.

{synoptset 20 tabbed}{...}
{synopthdr:column}
{synoptline}
{synopt:{cmd:source_name}}required; unique legal Stata name{p_end}
{synopt:{cmd:source_kind}}required; exactly {cmd:episodes} or {cmd:intervals}{p_end}
{synopt:{cmd:source_frame}}required frame locator; empty for {cmd:source_file}{p_end}
{synopt:{cmd:source_file}}required file locator; empty for {cmd:source_frame}{p_end}
{synopt:{cmd:start_var}}required; exact source start-variable name{p_end}
{synopt:{cmd:stop_var}}required; exact source stop-variable name{p_end}
{synopt:{cmd:input_vars}}required space-separated source variable names{p_end}
{synopt:{cmd:output_vars}}required; explicit output names, mapped by position{p_end}
{synopt:{cmd:reference}}required numeric; see below{p_end}
{synopt:{cmd:rate_vars}}optional; subset of {cmd:input_vars} carrying rates{p_end}
{synopt:{cmd:total_vars}}optional; subset carrying interval totals{p_end}
{synopt:{cmd:cumulative_vars}}optional; subset carrying row-start histories{p_end}
{synopt:{cmd:reference_label}}optional; {cmd:episodes} reference label{p_end}
{synopt:{cmd:variable_label}}optional; {cmd:episodes} output variable label{p_end}
{synopt:{cmd:description}}optional; provenance text with no analytical effect{p_end}
{synoptline}

{pstd}
The list cells are data, not command fragments. Each is tokenized on
whitespace and every token must be an explicit legal Stata variable
name; wildcards, hyphen ranges, factor and time-series operators, commas,
quotes, and command punctuation are all refused. No cell is ever evaluated as
code.

{pstd}
The specification version may be recorded as a dataset characteristic. An
absent characteristic means version 1; an unsupported nonempty value is an
error raised before any source is opened.

{phang2}{cmd:. frame build_spec: char _dta[tvbuild_spec_version] "1"}{p_end}


{marker dryrun}{...}
{title:Dry run}

{pstd}
{opt dryrun} is not a syntax-only approximation. It runs the same parser,
normalizer, name planner, data validators, eligibility predicates, and
destination preflight a real run uses, prints the resulting plan, and stops
before any construction or commit. It does not create, replace, or back up
{opt frameout()} or {opt manifestframe()}, and it leaves no scratch frame,
value label, variable, estimate, or changed setting behind. Its final line
states plainly that nothing changed.

{pstd}
A clean dry run is a statement about the plan as the data stand now. It is not
an authorization: a real run revalidates from scratch, and no characteristic
or cached state marks a plan as approved.


{marker output}{...}
{title:Output}

{pstd}
The committed variable order is{p_end}

{phang2}{cmd:id}{p_end}
{phang2}{cmd:entry exit} (unless {opt dropdates}){p_end}
{phang2}{cmd:start stop} (using {opt startname()} and {opt stopname()}){p_end}
{phang2}source output variables, in specification row and token order{p_end}
{phang2}master {opt keepvars()}, in command order{p_end}
{phang2}event indicator, elapsed time, event enum, gap start and stop, when requested{p_end}

{pstd}
The identifier keeps the master's storage type, format, and labels. Each
source payload keeps its storage type, format, variable label, value-label
assignment and definition, and characteristics, apart from the intentional
{cmd:input_vars} to {cmd:output_vars} rename. Output bounds are numeric doubles
carrying {opt dateformat()}.

{pstd}
Value labels created during the build are named by the engine that created
them, not by {cmd:tvbuild}: a categorical source output built by
{helpb tvexpose} carries {cmd:_tvlbl_}{it:varname}, and the event indicator
built by {helpb tvevent} carries {it:varname}{cmd:_lbl}. The two conventions
differ, and they are left alone deliberately. Each is the published output of
a command with its own users, and renaming either here would make a
{cmd:tvbuild} result differ from the same result built by calling those
commands directly -- which is the one property this coordinator exists to
preserve. Refer to a label through {cmd:r()} and the variable it is attached
to rather than by spelling its name.

{pstd}
There is no {cmd:saveas()} option. After a successful run,
{cmd:frame} {it:analysis}{cmd:: save} {it:filename} is explicit, and a failed
file export cannot make an analytically successful build look like a failure.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tvbuild} is {cmd:rclass}. It never forwards a helper's returns and never
claims a union of the {helpb tvexpose}, {helpb tvmerge}, or {helpb tvevent}
result surfaces.

{pstd}Always returned after a successful normal or dry run:{p_end}

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(dryrun)}}1 for read-only planning, otherwise 0{p_end}
{synopt:{cmd:r(spec_version)}}normalized specification version{p_end}
{synopt:{cmd:r(n_sources)}}number of normalized specification rows{p_end}
{synopt:{cmd:r(N_persons)}}validated master persons{p_end}
{synopt:{cmd:r(event_stage)}}1 when event integration is requested{p_end}
{synopt:{cmd:r(dates_kept)}}1 unless {opt dropdates} was specified{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(idvar)}}public id variable{p_end}
{synopt:{cmd:r(entryvar)}}master entry variable{p_end}
{synopt:{cmd:r(exitvar)}}master exit variable{p_end}
{synopt:{cmd:r(startvar)}}output start variable{p_end}
{synopt:{cmd:r(stopvar)}}output stop variable{p_end}
{synopt:{cmd:r(source_names)}}logical source names, in plan order{p_end}
{synopt:{cmd:r(payload_vars)}}all mapped source outputs, in plan order{p_end}
{synopt:{cmd:r(exposure_vars)}}unclassified categorical output variables{p_end}
{synopt:{cmd:r(rate_vars)}}mapped rate outputs; empty when none{p_end}
{synopt:{cmd:r(total_vars)}}mapped interval-total outputs; empty when none{p_end}
{synopt:{cmd:r(cumulative_vars)}}mapped row-start-history outputs, or empty{p_end}
{synopt:{cmd:r(specframe)}}specification frame, when used{p_end}
{synopt:{cmd:r(frameout)}}planned or committed output frame{p_end}
{synopt:{cmd:r(coverage)}}{cmd:strict} or {cmd:allow}{p_end}
{synopt:{cmd:r(manifestframe)}}manifest frame; empty only under {opt nomanifest}{p_end}
{synopt:{cmd:r(eventvar)}}event indicator, when requested{p_end}
{synopt:{cmd:r(timevar)}}elapsed-time variable, when requested{p_end}
{synopt:{cmd:r(enumvar)}}recurrent-event stratum, when requested{p_end}
{synopt:{cmd:r(gapstartvar)}}gap-time start, when requested{p_end}
{synopt:{cmd:r(gapstopvar)}}gap-time stop, when requested{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(source_counts)}}one row per source; see below{p_end}
{synoptline}

{pstd}Returned only after a successful normal run:{p_end}

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_periods)}}rows in the committed output{p_end}
{synopt:{cmd:r(n_gap_ids)}}persons with uncovered pre-event time{p_end}
{synopt:{cmd:r(uncovered_days)}}inclusive uncovered pre-event person-days{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(datasignature)}}verified signature of the committed data{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(stage_counts)}}one row per executed stage; see below{p_end}
{synoptline}

{pstd}
{cmd:r(stage_counts)} has rows {cmd:source1} through {cmd:sourceS}, then
{cmd:merge} when more than one source was aligned, then {cmd:event} when the
event stage ran, then {cmd:output}, in execution order. Its columns are
{cmd:N_in}, {cmd:N_out}, {cmd:N_persons_in}, {cmd:N_persons_out}, and
{cmd:uncovered_days}. For a source row {cmd:N_in} counts raw or ready source
rows and {cmd:N_out} counts normalized interval rows; for the merge row
{cmd:N_in} is the sum of the normalized source rows; for the event row
{cmd:N_in} is the pre-event interval count; for the output row {cmd:N_in} is
the finalized scratch count and {cmd:N_out} is the verified committed
count. {cmd:uncovered_days} is populated for the construction rows and missing
for the event and output rows, because event splitting and first-event
truncation are not coverage gaps.

{pstd}
{cmd:N_out} minus {cmd:N_in} is not a count of dropped rows: event splitting
increases rows and single-event truncation reduces them.

{pstd}
In {cmd:r(source_counts)}, {cmd:N_rows} and {cmd:N_persons} describe the validated source before
restriction to the master, {cmd:N_unmatched_ids} counts source ids absent from the
master, and {cmd:N_outside_window} counts raw episode rows wholly outside their
matched master window. {cmd:kind} is coded 1 for {cmd:episodes} and 2 for {cmd:intervals}; {cmd:input}
is coded 1 for a frame and 2 for a file. Row names are {cmd:source1}, {cmd:source2}, and
so on, because a matrix row name truncates at 32 characters; {cmd:r(source_names)}
carries the untruncated mapping.


{marker provenance}{...}
{title:Provenance}

{pstd}
After analytical success the committed frame carries informational
characteristics{p_end}

{phang2}{cmd:_dta[tvtools_tvbuild]} is {cmd:tvbuild}{p_end}
{phang2}{cmd:_dta[tvtools_tvbuild_schema]} is {cmd:1}{p_end}
{phang2}{cmd:_dta[tvtools_tvbuild_coverage]} is {cmd:strict} or {cmd:allow}{p_end}
{phang2}{cmd:_dta[tvtools_tvbuild_start]} records the {opt startname()} in force{p_end}
{phang2}{cmd:_dta[tvtools_tvbuild_stop]} records the {opt stopname()} in force{p_end}
{phang2}{cmd:_dta[tvtools_tvbuild_event]} records the event indicator, if any{p_end}
{phang2}{cmd:_dta[tvtools_tvbuild_committed]} is {cmd:1}{p_end}

{pstd}
These are provenance, not an authorization token: no command treats them as
proof that the data are unchanged. Stata stores an empty characteristic by
removing it, so {cmd:_dta[tvtools_tvbuild_event]} is absent when no event
stage ran.

{pstd}
The provenance manifest adds one row per executed stage -- {cmd:master}, one per
source, {cmd:merge} when applicable, {cmd:event} when applicable, and
{cmd:output} -- carrying the stage index, the logical source name and kind, the
input locator, the declared input and output variables, the quantity mapping,
the engine label, the stage counts, and, on the output row only, the data
signature. The manifest and the signature aid provenance; they do not replace
diagnostics or saved analysis code, and {cmd:datasignature} says nothing about
formats, labels, characteristics, or value-label definitions.


{marker examples}{...}
{title:Examples}

{pstd}
The setup below uses inline data and temporary files, so every example is
runnable after installation from any working directory.

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(entry_s exit_s) byte female double ev_s}{p_end}
{phang3}{cmd:1 "01jan2020" "31dec2020" 1 22000}{p_end}
{phang3}{cmd:2 "01jan2020" "31dec2020" 0 .}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double study_entry = date(entry_s, "DMY")}{p_end}
{phang2}{cmd:. generate double study_exit = date(exit_s, "DMY")}{p_end}
{phang2}{cmd:. generate double event_date = ev_s}{p_end}
{phang2}{cmd:. format study_entry study_exit event_date %td}{p_end}
{phang2}{cmd:. drop entry_s exit_s ev_s}{p_end}
{phang2}{cmd:. tempfile cohort episodes}{p_end}
{phang2}{cmd:. save `cohort'}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id str9(start_s stop_s) byte rx_class}{p_end}
{phang3}{cmd:1 "05jan2020" "20feb2020" 1}{p_end}
{phang3}{cmd:1 "01mar2020" "15apr2020" 2}{p_end}
{phang3}{cmd:2 "10jun2020" "31jul2020" 1}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. generate double rx_start = date(start_s, "DMY")}{p_end}
{phang2}{cmd:. generate double rx_stop = date(stop_s, "DMY")}{p_end}
{phang2}{cmd:. drop start_s stop_s}{p_end}
{phang2}{cmd:. save `episodes'}{p_end}

{pstd}{bf:1. Validate a one-source plan without changing anything}{p_end}

{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvbuild, sourceusing(`"`episodes'"') id(id) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///}{p_end}
{phang3}{cmd:generate(tv_drug) frameout(analysis) dryrun}{p_end}

{pstd}{bf:2. The corresponding committed run.} The same call without
{opt dryrun} builds the result and places it in {cmd:analysis}; the data in
memory are untouched.{p_end}

{phang2}{cmd:. tvbuild, sourceusing(`"`episodes'"') id(id) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///}{p_end}
{phang3}{cmd:generate(tv_drug) referencelabel("Unexposed") keepvars(female) ///}{p_end}
{phang3}{cmd:frameout(analysis) replace}{p_end}

{pstd}{bf:3. Two sources through a specification frame.} A second source is
built explicitly with {helpb tvexpose} and declared as ready intervals. Note
that the locators here are FRAME names: {cmd:input} does not expand macros in
its data lines, so a tempfile path written as a macro reference would be stored
literally, and {cmd:tvbuild} refuses a cell containing a backtick rather than
letting it expand to something else later.{p_end}

{phang2}{cmd:. capture frame drop rx_frame}{p_end}
{phang2}{cmd:. frame create rx_frame}{p_end}
{phang2}{cmd:. frame rx_frame: use `episodes', clear}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(rx_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:generate(tv_alt) frameout(alt_frame) replace}{p_end}
{phang2}{cmd:. frame alt_frame: rename (rx_start rx_stop) (start stop)}{p_end}
{phang2}{cmd:. capture frame drop build_spec}{p_end}
{phang2}{cmd:. frame create build_spec}{p_end}
{phang2}{cmd:. frame build_spec {c -(}}{p_end}
{phang3}{cmd:input str32 source_name str12 source_kind str32 source_frame strL source_file ///}{p_end}
{phang3}{cmd:    str32 start_var str32 stop_var strL input_vars strL output_vars double reference}{p_end}
{phang3}{cmd:"drug" "episodes" "rx_frame" "" "rx_start" "rx_stop" "rx_class" "tv_drug" 0}{p_end}
{phang3}{cmd:"alt" "intervals" "alt_frame" "" "start" "stop" "tv_alt" "tv_alt2" .}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. {c )-}}{p_end}
{phang2}{cmd:. frame build_spec: char _dta[tvbuild_spec_version] "1"}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvbuild, specframe(build_spec) id(id) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:frameout(analysis) manifestframe(provenance) replace}{p_end}
{phang2}{cmd:. frame provenance: list stage source_name n_input n_output, noobs}{p_end}

{pstd}{bf:4. An advanced exposure definition is a ready interval source.} Grace
periods, layering, dose, duration, recency, and the other {helpb tvexpose}
modes stay in the {cmd:tvexpose} call where they are visible, rather than
inside a configuration string.{p_end}

{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvexpose using `episodes', id(id) start(rx_start) stop(rx_stop) ///}{p_end}
{phang3}{cmd:exposure(rx_class) reference(0) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:generate(tv_drug) grace(30) layer frameout(drug_frame) replace}{p_end}

{pstd}{bf:5. A single event, taken from the master}{p_end}

{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvbuild, sourceusing(`"`episodes'"') id(id) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///}{p_end}
{phang3}{cmd:generate(tv_drug) frameout(analysis) replace ///}{p_end}
{phang3}{cmd:eventdate(event_date) eventgenerate(_failure) timegen(_elapsed)}{p_end}

{pstd}{bf:6. Recurring events from a separate frame}{p_end}

{phang2}{cmd:. capture frame drop ev_frame}{p_end}
{phang2}{cmd:. frame create ev_frame}{p_end}
{phang2}{cmd:. frame ev_frame {c -(}}{p_end}
{phang3}{cmd:input long id double ev1 double ev2}{p_end}
{phang3}{cmd:1 22000 22200}{p_end}
{phang3}{cmd:2 22100 .}{p_end}
{phang3}{cmd:end}{p_end}
{phang2}{cmd:. {c )-}}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. tvbuild, sourceusing(`"`episodes'"') id(id) entry(study_entry) exit(study_exit) ///}{p_end}
{phang3}{cmd:start(rx_start) stop(rx_stop) exposure(rx_class) reference(0) ///}{p_end}
{phang3}{cmd:generate(tv_drug) frameout(analysis) replace ///}{p_end}
{phang3}{cmd:eventframe(ev_frame) eventdate(ev) eventtype(recurring) enum(_enum) gaptime}{p_end}

{pstd}{bf:7. Hand off to diagnostics, weighting, and survival setup} using the
names {cmd:tvbuild} returns rather than names typed twice. Copy the returns into
locals first: each of these commands replaces {cmd:r()} with its own results.{p_end}

{phang2}{cmd:. local idv "`r(idvar)'"}{p_end}
{phang2}{cmd:. local sv "`r(startvar)'"}{p_end}
{phang2}{cmd:. local ev "`r(stopvar)'"}{p_end}
{phang2}{cmd:. local fv "`r(eventvar)'"}{p_end}
{phang2}{cmd:. frame change analysis}{p_end}
{phang2}{cmd:. tvdiagnose, id(`idv') start(`sv') stop(`ev') entry(study_entry) exit(study_exit) all}{p_end}
{phang2}{cmd:. generate double analysis_t0 = `sv' - 1}{p_end}
{phang2}{cmd:. stset `ev', id(`idv') failure(`fv' == 1) time0(analysis_t0)}{p_end}

{pstd}
{cmd:tvbuild} automates record construction, not scientific
decisions. {opt coverage(allow)} is a visible choice that may restrict the
person-time an analysis represents, and the manifest and data signature aid
provenance but do not replace {helpb tvdiagnose} or saved analysis code.


{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}

{smcl}
{* *! version 1.2.0  30jun2026}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{vieweralsosee "[D] joinby" "help joinby"}{...}
{vieweralsosee "[D] frames" "help frames"}{...}
{vieweralsosee "rangestat" "help rangestat"}{...}
{vieweralsosee "rangejoin" "help rangejoin"}{...}
{viewerjumpto "Syntax" "rangematch##syntax"}{...}
{viewerjumpto "Description" "rangematch##description"}{...}
{viewerjumpto "Options" "rangematch##options"}{...}
{viewerjumpto "Remarks" "rangematch##remarks"}{...}
{viewerjumpto "Examples" "rangematch##examples"}{...}
{viewerjumpto "Stored results" "rangematch##results"}{...}
{viewerjumpto "Author" "rangematch##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:rangematch} {hline 2}}Range join between master and using datasets{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}Point-in-interval mode (a using {it:keyvar} point falls in the master
[{it:low}, {it:high}] interval):{p_end}

{p 8 17 2}
{cmd:rangematch}
{it:keyvar}
{it:low}
{it:high}
{cmd:using}
{it:filename_or_framename}
{ifin}
{cmd:,}
[{it:options}]

{pstd}Interval-overlap mode (the master [{it:low}, {it:high}] interval overlaps
the using [{it:ulow}, {it:uhigh}] interval):{p_end}

{p 8 17 2}
{cmd:rangematch}
{it:low}
{it:high}
{cmd:using}
{it:filename_or_framename}
{ifin}
{cmd:,}
{opt overlap(ulow uhigh)}
[{it:options}]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Variables}
{synopt:{opt overlap(ulow uhigh)}}match where the master interval overlaps the using [{it:ulow}, {it:uhigh}] interval (interval-overlap mode){p_end}
{synopt:{opt by(varlist)}}restrict matches to groups with identical values{p_end}
{synopt:{opt keepu:sing(varlist)}}variables to carry from using dataset{p_end}

{syntab:Naming}
{synopt:{opt p:refix(string)}}prefix for renamed using variables{p_end}
{synopt:{opt s:uffix(string)}}suffix for renamed using variables{p_end}
{synopt:{opt all}}rename all using variables, not just conflicts{p_end}

{syntab:Matching}
{synopt:{opt unmatch:ed(master|none|using|both)}}handling of unmatched rows{p_end}
{synopt:{opt gen:erate(name)}}create match indicator variable{p_end}
{synopt:{opt dist:ance(name)}}create signed using-key minus master-key distance variable{p_end}
{synopt:{opt masterid(name)}}create original master row-number variable{p_end}
{synopt:{opt usingid(name)}}create original using row-number variable{p_end}
{synopt:{opt maxp:airs(#)}}abort if output rows exceed {it:#}; 0 = no guard{p_end}
{synopt:{opt closed(both|left|right|none)}}interval endpoint closure{p_end}
{synopt:{opt tol:erance(#)}}boundary-comparison tolerance for floating-point keys{p_end}
{synopt:{opt miss:ing(wildcard|drop|error)}}policy for master and using rows with missing bounds or key{p_end}
{synopt:{opt near:est(before|after|both)}}keep nearest match(es) within the interval{p_end}
{synopt:{opt ties(all|first|last)}}tie handling for {opt nearest()}{p_end}
{synopt:{opt as:sert(match|using)}}abort when required master or using matches are absent{p_end}

{syntab:Output}
{synopt:{opt frame(name)}}write output to named frame and leave current data unchanged{p_end}
{synopt:{opt replace}}replace existing target frame; allowed only with {opt frame()}{p_end}
{synopt:{opt sav:ing(filename[, replace])}}save output to a dataset on disk{p_end}
{synopt:{opt stats}}display match-density diagnostics{p_end}
{synopt:{opt nosort}}leave output in backend materialization order{p_end}
{synopt:{opt dryr:un}}report output counts without writing output{p_end}
{synopt:{opt count}}report output counts without writing output{p_end}
{synopt:{opt verbose}}display additional diagnostic information{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:rangematch} performs a range join between the dataset in memory (the master)
and a using dataset stored on disk or in a named frame. For each observation in
the master, it finds every observation in the using dataset whose {it:keyvar}
lies inside the master observation's interval.

{pstd}
In the standard variable-bound form,

{p 12 12 2}
using.{it:keyvar} is compared with [master.{it:low}, master.{it:high}]

{pstd}
where {it:low} and {it:high} are numeric variables in the master dataset.
The using dataset or frame must contain numeric {it:keyvar}.

{pstd}
In the scalar-offset form, {it:low} and {it:high} may instead be numeric
constants. In that case, {it:keyvar} must also exist as a numeric variable in
the master dataset, and the interval is computed as

{p 12 12 2}
[master.{it:keyvar} + {it:low}, master.{it:keyvar} + {it:high}]

{pstd}
For example, {cmd:rangematch event_date -30 30 using events.dta} matches using
events that occur from 30 days before through 30 days after each master
{cmd:event_date}. A literal {cmd:.} in either bound position means that endpoint
is open-ended.

{pstd}
By default, {cmd:rangematch} replaces the data in memory with all matched pairs,
plus unmatched master observations. With {opt frame()}, it writes the output to
a named frame and leaves the current data unchanged.

{pstd}
If you only need summary statistics over a range, {cmd:rangestat} is usually
more efficient. {cmd:rangematch} is for workflows that need the joined rows
themselves.


{marker options}{...}
{title:Options}

{dlgtab:Match mode}

{phang}
{opt overlap(ulow uhigh)} switches {cmd:rangematch} from point-in-interval
matching to {bf:interval-overlap} matching. {it:ulow} and {it:uhigh} name the
two numeric interval-bound variables in the using dataset or frame. In this mode
no point {it:keyvar} is given: the positional arguments are the master interval
{it:low} and {it:high}, and a master observation matches a using observation when
their intervals overlap. With {opt closed(both)} (the default) the overlap test
is master.{it:low} <= using.{it:uhigh} {bf:&} using.{it:ulow} <=
master.{it:high} (touching endpoints count); with {opt closed(none)} the
comparisons are strict (touching endpoints do not count). Under the default
{opt miss:ing(wildcard)} a missing master or using bound is treated as
open-ended on that side, so a fully missing interval matches everything in its
{opt by()} group; {opt miss:ing(drop)} and {opt miss:ing(error)} instead drop or
reject rows with a missing bound on either side (see {opt miss:ing()} below).
{opt tolerance()} shifts the comparison boundaries exactly as in point mode.

{pmore}
Each interval is assumed well-formed, with {it:low} <= {it:high} (and
{it:ulow} <= {it:uhigh}). A master interval with {it:low} > {it:high} is
treated as empty and matches nothing; a using interval with {it:ulow} >
{it:uhigh} is not screened and may produce matches that reflect the inverted
bounds rather than a genuine overlap, so validate using-side interval order
upstream if it is not already guaranteed.

{pmore}
Interval-overlap mode emits matched pairs directly through the same Mata backend,
so the full within-{opt by()} Cartesian product is never materialized -- a large
memory win over {helpb joinby} followed by a {cmd:keep if} overlap filter on
registry-scale interval data. {opt closed()} accepts only {bf:both} or {bf:none}
in this mode, and the point-only options {opt nearest()}, {opt ties()},
{opt distance()}, and scalar offset bounds are not allowed. All other options
({opt by()}, {opt unmatched()}, {opt keepusing()}, {opt frame()}, {opt saving()},
{opt stats}, {opt generate()}, {opt masterid()}, {opt usingid()},
{opt maxpairs()}, {opt missing()}, and {opt nosort}) behave as documented below.
{cmd:r(backend)} reports {cmd:overlap}.

{dlgtab:Variables}

{phang}
{opt by(varlist)} restricts matches to observations that share the same values
of {it:varlist} in both master and using datasets. By-variables must exist in
both datasets and have compatible types. Matches are only considered within
groups defined by {opt by()}.

{phang}
{opt keepu:sing(varlist)} specifies which variables to carry from the using
dataset. By default, all using variables are carried. The using key and
by-variables needed for matching are loaded automatically.

{dlgtab:Naming}

{phang}
{opt p:refix(string)} adds a prefix to renamed using variables. It may be
combined with {opt s:uffix()}.

{phang}
{opt s:uffix(string)} adds a suffix to renamed using variables. If neither
{opt p:refix()} nor {opt s:uffix()} is specified, conflicting using variables are
renamed with suffix {bf:_U}.

{phang}
{opt all} renames all using variables with the requested prefix and/or suffix,
not just variables that conflict with master variable names. By-variables still
appear once.

{dlgtab:Matching}

{phang}
{opt unmatch:ed(master|none|using|both)} controls handling of observations with
no matches. {opt unmatch:ed(master)} retains unmatched master observations in
the output with missing values for using variables. {opt unmatch:ed(using)}
retains unmatched using observations with missing values for master variables.
{opt unmatch:ed(both)} retains unmatched rows from both sides.
{opt unmatch:ed(none)} drops unmatched observations. The default is
{opt unmatch:ed(master)}.

{phang}
{opt gen:erate(name)} creates a byte variable indicating match status. Values
follow the {help merge} convention: {bf:1} = master only (unmatched),
{bf:2} = using only (unmatched), and {bf:3} = matched pair. The variable is
assigned a value label with these meanings.

{phang}
{opt dist:ance(name)} creates a double variable equal to using.{it:keyvar} minus
master.{it:keyvar} for matched pairs. The value is missing for unmatched master
or using rows. The master dataset must contain numeric {it:keyvar}.

{phang}
{opt masterid(name)} creates a long variable containing the original master
observation number for each output row. It is missing for using-only rows.

{phang}
{opt usingid(name)} creates a long variable containing the original using
observation number for each output row. It is missing for master-only rows.

{phang}
{opt maxp:airs(#)} specifies a safety limit. If the number of output rows
would exceed {it:#}, the command aborts before materializing output.
{cmd:maxpairs(0)} imposes no limit.

{phang}
{opt closed(both|left|right|none)} controls whether interval endpoints are
included. {opt closed(both)} uses [lo,hi]; {opt closed(left)} uses [lo,hi);
{opt closed(right)} uses (lo,hi]; and {opt closed(none)} uses (lo,hi).
The default is {opt closed(both)}.

{phang}
{opt tol:erance(#)} applies a nonnegative boundary-comparison tolerance to
floating-point keys. With tolerance {it:t}, lower-bound comparisons use
{it:low} - {it:t} and upper-bound comparisons use {it:high} + {it:t}, while
preserving the requested endpoint closure. This is intended for representation
noise such as decimal arithmetic, not as a statistical matching rule. The
default is {cmd:tolerance(0)}.

{pmore}
As a related safeguard, {cmd:rangematch} prints a non-fatal warning when a
matching variable (a master {it:low}/{it:high} bound, a using point {it:keyvar},
or a using {it:ulow}/{it:uhigh} bound) is stored as {cmd:float} with values
beyond float's exact-integer range (2{c 94}24). Such values -- most commonly
{cmd:%tc} datetime clocks -- can fail boundary equality after the internal
{cmd:double} cast. Recast the offending variable to {cmd:double}, or set a small
{opt tol:erance()}, to make boundary matches reliable. {cmd:%td} dates and
small-magnitude values are within float's exact range and are not flagged.

{phang}
{opt miss:ing(wildcard|drop|error)} controls handling of rows with missing
matching variables, applied symmetrically to both sides: on the master side a
missing {it:low} or {it:high} variable bound (point or overlap mode), and on the
using side a missing point {it:keyvar} (point mode) or a missing {it:ulow} or
{it:uhigh} interval bound (overlap mode).

{pmore}
{opt miss:ing(wildcard)}, the default, preserves the historical behavior exactly
and treats a missing {it:bound} as open-ended on that side, consistent with the
semantics of a literal {cmd:.} positional bound; such rows wildcard-match every
counterpart in the same {opt by()} group. A missing point {it:keyvar} has no
open-ended interpretation, so under {cmd:wildcard} a using row with a missing key
never matches (and surfaces only as an unmatched-using row under
{opt unmatch:ed(using)} or {opt unmatch:ed(both)}).

{pmore}
{opt miss:ing(drop)} drops the offending rows before matching, on whichever side
they occur, equivalent to {cmd:drop if missing(...)} upstream of the call;
dropped rows never appear in the output regardless of {opt unmatch:ed()}.
{opt miss:ing(error)} aborts with a clear message and the count of offending
rows. The option applies only to {it:variables}; a literal {cmd:.} positional
bound is the user's explicit open-ended token and is unaffected.

{pmore}
If {opt miss:ing(drop)} empties an entire {opt by()} group from one side, the
counterpart rows in that group still surface as unmatched under the relevant
{opt unmatch:ed()} setting and will trip the matching {opt as:sert()}. The count
of master rows with missing variable bounds is always posted in
{cmd:r(N_missing_bounds)} and the count of using rows with a missing key/bound in
{cmd:r(N_using_missing)}, under every policy. Under {opt miss:ing(drop)},
{cmd:r(N_master)} and {cmd:r(N_using)} are the post-drop counts, and adding back
the corresponding missing count recovers the post-{cmd:if}/{cmd:in}, pre-drop
total for that side.

{phang}
{opt near:est(before|after|both)} keeps only nearest using observations within
the interval. {opt near:est(before)} keeps the nearest using key at or before
the master key, {opt near:est(after)} keeps the nearest using key at or after
the master key, and {opt near:est(both)} keeps nearest matches on both sides.
The master dataset must contain numeric {it:keyvar}.

{phang}
{opt ties(all|first|last)} controls tie handling with {opt nearest()} when two
or more using rows are equally near the key. {opt ties(all)} keeps every equally
nearest row; {opt ties(first)} keeps the single tied row with the lowest
original using observation number; {opt ties(last)} keeps the one with the
highest. ("First" and "last" therefore refer to original using row order, not to
key value or distance, which are equal among ties.) The default is
{opt ties(all)}. {opt ties()} is only allowed with {opt nearest()}.

{phang}
{opt as:sert(match|using)} aborts when required matches are absent.
{opt as:sert(match)} requires every master observation under consideration to
match at least one using observation. {opt as:sert(using)} requires every using
observation to match at least one master observation. You may specify both
tokens, for example {cmd:assert(match using)}.

{dlgtab:Output}

{phang}
{opt frame(name)} writes the output to named frame {it:name} instead of
replacing the current dataset. The current data and current frame remain
unchanged. If {it:name} already exists, {opt replace} is required.

{phang}
{opt replace} permits replacement of an existing target frame. {opt replace}
is allowed only with {opt frame()}.

{phang}
{opt sav:ing(filename[, replace])} saves the output dataset to {it:filename}
instead of replacing the current dataset. Specify the {opt replace} suboption
inside {opt saving()} to overwrite an existing file. {opt saving()} may not be
combined with {opt frame()}, {opt dryrun}, or {opt count}.

{phang}
{opt stats} displays match-density diagnostics, including master observations,
using observations, matched pairs, unmatched rows, matched master observations,
unmatched master observations, unmatched using observations, maximum matches
per master observation, mean matches per master observation, p50, p90, and p99
matches per master observation, and groups with no using observations. Stored
match-density results are computed and posted only when {opt stats} is
specified; core count results are posted on successful runs without
{opt stats}. With {opt by()}, {cmd:rangematch} warns when more than half of
master by-groups have no using rows when {opt stats} is specified.

{phang}
By default, {cmd:rangematch} sorts output by original master row and original
using row before dropping internal row identifiers.

{phang}
{opt nosort} skips the final output sort and leaves rows in backend
materialization order. Matching still uses an internal sort of using keys for
binary search.

{phang}
{opt dryr:un} validates the request and reports the output counts without
replacing the current data or writing a frame. If {opt frame()} is also
specified, no frame is created or replaced. {opt dryr:un} and {opt count} are
aliases.

{phang}
{opt count} reports output counts without replacing the current data or writing
a frame. It is a synonym for {opt dryr:un}. If {opt frame()} is also specified,
no frame is created or replaced.

{phang}
{opt verbose} displays additional diagnostic information about loading,
grouping, matching, output handling, and elapsed seconds for the load, match,
and materialize phases. Very large joins also display matching progress.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Bounds}

{pstd}
{it:low} and {it:high} may be numeric variables in the master dataset. They may
also be numeric scalar offsets from the master {it:keyvar}, provided that
{it:keyvar} exists as a numeric variable in the master dataset. A literal
{cmd:.} bound is open-ended.

{pstd}
Under the default {opt miss:ing(wildcard)}, missing lower bounds are treated as
open-ended below and missing upper bounds as open-ended above; a using
observation with a missing key never matches. {opt miss:ing(drop)} and
{opt miss:ing(error)} instead drop or reject rows with a missing bound or key on
either side; see {opt miss:ing()} for the full symmetric policy.

{pstd}
If the computed lower bound is greater than the computed upper bound, no match
is possible for that master observation. It is retained only when
{opt unmatch:ed(master)} is active.

{pstd}
{bf:Frames}

{pstd}
Without {opt frame()}, successful output replaces the current data in memory.
With {opt frame(name)}, output is written to the named frame and the caller's
current data are left unchanged. Existing target frames are protected unless
{opt replace} is specified.

{pstd}
The token after {cmd:using} may name an existing frame. If a frame with that
name exists, {cmd:rangematch} copies it into an internal work frame and leaves
the source frame unchanged. Otherwise the token is treated as a filename; if
the file does not exist as written, {cmd:rangematch} appends {cmd:.dta} and
tries again (matching the behavior of {cmd:use}). The using frame must be
different from the current frame.

{pstd}
{bf:Migrating from rangejoin}

{pstd}
Most {cmd:rangejoin} calls translate directly:

{p 12 12 2}
{cmd:rangejoin key lo hi using file}

{pstd}
becomes

{p 12 12 2}
{cmd:rangematch key lo hi using file}

{pstd}
{cmd:rangematch} adds frame-safe output through {opt frame()}, scalar-offset
bounds such as {cmd:-30 30}, explicit unmatched-row control through
{opt unmatch:ed()}, nearest-match selection through {opt near:est()}, signed
distances through {opt dist:ance()}, and output saving through {opt sav:ing()}.
It also accepts an existing frame after {cmd:using}, avoiding temporary files in
frame-based workflows.

{pstd}
{bf:Migrating from joinby}

{pstd}
The common {cmd:joinby}+filter pattern

{p 12 12 2}
{cmd:joinby id using events.dta, unmatched(none)}
{p_end}
{p 12 12 2}
{cmd:keep if inrange(event_date, lo, hi)}

{pstd}
becomes

{p 12 12 2}
{cmd:rangematch event_date lo hi using events.dta, by(id) unmatched(none)}

{pstd}
Three things change when porting:

{phang}
o {bf:Master/using direction may flip.} {cmd:joinby} treats the in-memory
dataset as master regardless of which side carries the join key. With
{cmd:rangematch}, master holds the bounds and using holds the key. For a
typical "narrow registry rows to a wide cohort" pipeline, put the cohort
(with bounds) in memory and the registry on the using side.

{phang}
o {bf:{opt unmatch:ed()} defaults differ.} {cmd:joinby} drops unmatched rows;
{cmd:rangematch} defaults to {opt unmatch:ed(master)}. Specify
{opt unmatch:ed(none)} to reproduce {cmd:joinby} semantics.

{phang}
o {bf:Missing variable bounds are handled differently.} When a {cmd:joinby}
is followed by {cmd:keep if inrange(date, lo, hi)}, rows with missing
{cmd:lo} or {cmd:hi} are silently dropped because every comparison against
missing returns false. {cmd:rangematch} treats a missing bound as open-ended
on that side, consistent with the literal {cmd:.} positional bound, so those
rows wildcard-match every using row in the same {opt by()} group. If your
bound variables can be missing, either drop missing-bound rows upstream or
specify {opt miss:ing(drop)}; otherwise output may contain spurious matches.
{opt miss:ing(error)} makes {cmd:rangematch} refuse to run when missing-bound
rows are present.

{pstd}
{cmd:rangematch} also avoids the Cartesian blow-up of {cmd:joinby}+{cmd:keep if},
which materializes the full within-{opt by()} Cartesian product before
filtering. {cmd:rangematch} emits matched pairs directly through binary search
or sweep, which is a substantial memory and time win on registry-scale datasets
with selective intervals.

{pstd}
{bf:Endpoint closure}

{pstd}
The default closure, {opt closed(both)}, matches the usual inclusive range
join. Use {opt closed(left)} for half-open [lo,hi) intervals, {opt closed(right)}
for (lo,hi] intervals, and {opt closed(none)} for open (lo,hi) intervals.

{pstd}
{bf:Output order}

{pstd}
By default, output is sorted by original master row and then original using row;
master-only rows sort after matched rows for the same master observation, and
using-only rows sort after all master rows. Specify {opt nosort} to skip this
final sort when output order is not important.

{pstd}
{bf:Nearest matches}

{pstd}
{opt nearest()} changes the operation from all in-range matches to nearest
in-range matches relative to the master {it:keyvar}. The interval bounds still
apply; observations outside [lo,hi] are never considered nearest matches.

{pstd}
{bf:Performance}

{pstd}
The generic binary-search matching path scales approximately as O(M log U + K),
where M is the number of master rows considered, U is the number of using rows,
and K is the number of emitted output pairs. For compatible all-match
workloads, {cmd:rangematch} can use a sweep/two-pointer backend that
establishes a safe internal master-interval order before matching, reducing
the matching step toward O(M + U + K). This internal ordering is not an output
order promise: default output is still sorted by original master row and
original using row, while {opt nosort} leaves the backend materialization
order.

{pstd}
The backend is selected conservatively. Compatible
non-{opt near:est()} workloads can use the sweep backend while preserving
{opt stats}, {opt as:sert(using)}, and {opt unmatch:ed(using|both)}
bookkeeping. {opt near:est()} uses the generic path. Check {cmd:r(backend)}
after a run to see which backend generated the pairs. Total runtime also
includes loading the using data, grouping, carrying variables into the output,
and any final output sort. {opt by()} can improve speed and memory behavior
when it partitions the using keys into smaller relevant groups. Wide using
datasets are more expensive to materialize; specify {opt keepu:sing()} when
only selected using variables are needed.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Rolling date window with scalar offsets}

{pstd}
Create master events and using events, then match using events within 30 days
of each master event date:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str1 site int id double event_date}{p_end}
{phang2}{cmd:  "A" 1 21915}{p_end}
{phang2}{cmd:  "B" 2 21946}{p_end}
{phang2}{cmd:  end}{p_end}
{phang2}{cmd:. format event_date %td}{p_end}
{phang2}{cmd:. tempfile master events}{p_end}
{phang2}{cmd:. save `master'}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str1 site int eid double event_date}{p_end}
{phang2}{cmd:  "A" 101 21890}{p_end}
{phang2}{cmd:  "A" 102 21920}{p_end}
{phang2}{cmd:  "B" 103 21950}{p_end}
{phang2}{cmd:  "B" 104 21990}{p_end}
{phang2}{cmd:  end}{p_end}
{phang2}{cmd:. format event_date %td}{p_end}
{phang2}{cmd:. save `events'}{p_end}
{phang2}{cmd:. use `master', clear}{p_end}
{phang2}{stata "rangematch event_date -30 30 using `events', frame(matches) replace stats":. rangematch event_date -30 30 using `events', frame(matches) replace stats}{p_end}
{phang2}{cmd:. frame matches: list}{p_end}

{pstd}
{bf:Example 2: Variable bounds and endpoint closure}

{phang2}{cmd:. use `master', clear}{p_end}
{phang2}{cmd:. generate double lo = event_date - 14}{p_end}
{phang2}{cmd:. generate double hi = event_date + 14}{p_end}
{phang2}{cmd:. rangematch event_date lo hi using `events', closed(left)}{p_end}
{phang2}{cmd:. list}{p_end}

{pstd}
{bf:Example 3: Count output rows before materializing}

{phang2}{cmd:. use `master', clear}{p_end}
{phang2}{cmd:. rangematch event_date . 30 using `events', count}{p_end}
{phang2}{cmd:. return list}{p_end}

{pstd}
{bf:Example 4: Grouped matching}

{phang2}{cmd:. rangematch event_date -7 7 using `events', by(site) generate(_merge)}{p_end}

{pstd}
{bf:Example 5: Exposure windows and adverse events}

{pstd}
Match adverse events to patient-specific drug exposure windows:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input int patient_id str10 start_string byte exposure_days}{p_end}
{phang2}{cmd:  101 "2020-01-15" 30}{p_end}
{phang2}{cmd:  101 "2020-03-01" 14}{p_end}
{phang2}{cmd:  102 "2020-02-10" 21}{p_end}
{phang2}{cmd:  end}{p_end}
{phang2}{cmd:. generate double exposure_start = daily(start_string, "YMD")}{p_end}
{phang2}{cmd:. generate double exposure_end = exposure_start + exposure_days}{p_end}
{phang2}{cmd:. format exposure_start exposure_end %td}{p_end}
{phang2}{cmd:. drop start_string exposure_days}{p_end}
{phang2}{cmd:. tempfile exposures adverse_events}{p_end}
{phang2}{cmd:. save `exposures'}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input int patient_id str10 event_string str18 event_type}{p_end}
{phang2}{cmd:  101 "2020-01-20" "rash"}{p_end}
{phang2}{cmd:  101 "2020-02-20" "headache"}{p_end}
{phang2}{cmd:  101 "2020-03-10" "nausea"}{p_end}
{phang2}{cmd:  102 "2020-02-15" "dizziness"}{p_end}
{phang2}{cmd:  102 "2020-03-20" "fatigue"}{p_end}
{phang2}{cmd:  end}{p_end}
{phang2}{cmd:. generate double event_date = daily(event_string, "YMD")}{p_end}
{phang2}{cmd:. format event_date %td}{p_end}
{phang2}{cmd:. drop event_string}{p_end}
{phang2}{cmd:. save `adverse_events'}{p_end}
{phang2}{cmd:. use `exposures', clear}{p_end}
{phang2}{cmd:. rangematch event_date exposure_start exposure_end using `adverse_events', by(patient_id) keepusing(event_date event_type) generate(_merge) frame(exposure_events) replace stats}{p_end}
{phang2}{cmd:. frame exposure_events: list patient_id exposure_start exposure_end event_date event_type _merge, sepby(patient_id)}{p_end}

{pstd}
{bf:Example 6: Interval-overlap mode}

{pstd}
Match cohort follow-up windows to overlapping treatment episodes within patient,
writing the joined rows to a frame:

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input int id str10 entry_s str10 exit_s}{p_end}
{phang2}{cmd:  1 "2020-01-01" "2020-06-30"}{p_end}
{phang2}{cmd:  2 "2020-02-01" "2020-08-31"}{p_end}
{phang2}{cmd:  end}{p_end}
{phang2}{cmd:. generate double entry = daily(entry_s, "YMD")}{p_end}
{phang2}{cmd:. generate double exit  = daily(exit_s, "YMD")}{p_end}
{phang2}{cmd:. format entry exit %td}{p_end}
{phang2}{cmd:. drop entry_s exit_s}{p_end}
{phang2}{cmd:. tempfile cohort episodes}{p_end}
{phang2}{cmd:. save `cohort'}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input int id str10 start_s str10 stop_s str10 drug}{p_end}
{phang2}{cmd:  1 "2019-12-15" "2020-01-20" "drugA"}{p_end}
{phang2}{cmd:  1 "2020-03-01" "2020-03-31" "drugB"}{p_end}
{phang2}{cmd:  2 "2020-09-15" "2020-10-15" "drugA"}{p_end}
{phang2}{cmd:  end}{p_end}
{phang2}{cmd:. generate double rx_start = daily(start_s, "YMD")}{p_end}
{phang2}{cmd:. generate double rx_stop  = daily(stop_s, "YMD")}{p_end}
{phang2}{cmd:. format rx_start rx_stop %td}{p_end}
{phang2}{cmd:. drop start_s stop_s}{p_end}
{phang2}{cmd:. save `episodes'}{p_end}
{phang2}{cmd:. use `cohort', clear}{p_end}
{phang2}{cmd:. rangematch entry exit using `episodes', overlap(rx_start rx_stop) by(id) keepusing(rx_start rx_stop drug) frame(exposed) replace stats}{p_end}
{phang2}{cmd:. frame exposed: list id entry exit rx_start rx_stop drug, sepby(id)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:rangematch} stores core count results in {cmd:r()} after successful
runs, including {opt dryrun}, {opt count}, and runs without {opt stats}.
Match-density results are computed and posted only when {opt stats} is
specified.

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Core scalars}{p_end}
{synopt:{cmd:r(N_master)}}master observations considered{p_end}
{synopt:{cmd:r(N_using)}}using observations loaded{p_end}
{synopt:{cmd:r(N_pairs)}}total output rows, including unmatched rows{p_end}
{synopt:{cmd:r(N_unmatched)}}unmatched output rows{p_end}
{synopt:{cmd:r(N_matched_pairs)}}matched output rows{p_end}
{synopt:{cmd:r(N_missing_bounds)}}master rows with a missing variable bound for {it:low} or {it:high}{p_end}
{synopt:{cmd:r(N_using_missing)}}using rows with a missing point key or interval bound{p_end}
{synopt:{cmd:r(tolerance)}}boundary-comparison tolerance used{p_end}

{p2col 5 22 26 2: Match-density scalars, only with {opt stats}}{p_end}
{synopt:{cmd:r(N_matched_master)}}master observations with at least one match{p_end}
{synopt:{cmd:r(N_matched_using)}}using observations with at least one match{p_end}
{synopt:{cmd:r(N_unmatched_master)}}unmatched master observations{p_end}
{synopt:{cmd:r(N_unmatched_using)}}unmatched using observations{p_end}
{synopt:{cmd:r(max_matches)}}maximum matches for any one master observation{p_end}
{synopt:{cmd:r(mean_matches)}}mean matches per master observation{p_end}
{synopt:{cmd:r(median_matches)}}median matches per master observation{p_end}
{synopt:{cmd:r(p50_matches)}}p50 matches per master observation{p_end}
{synopt:{cmd:r(p90_matches)}}p90 matches per master observation{p_end}
{synopt:{cmd:r(p99_matches)}}p99 matches per master observation{p_end}
{synopt:{cmd:r(N_empty_groups)}}by-groups with no using observations{p_end}
{synopt:{cmd:r(N_master_groups)}}master by-groups considered{p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}{cmd:rangematch}{p_end}
{synopt:{cmd:r(cmdline)}}command as typed{p_end}
{synopt:{cmd:r(using)}}using filename or frame name{p_end}
{synopt:{cmd:r(using_source)}}{cmd:file} or {cmd:frame}{p_end}
{synopt:{cmd:r(key)}}parsed key variable{p_end}
{synopt:{cmd:r(low)}}parsed lower-bound variable or scalar{p_end}
{synopt:{cmd:r(high)}}parsed upper-bound variable or scalar{p_end}
{synopt:{cmd:r(overlap)}}using interval-bound variables, when {opt overlap()} is used{p_end}
{synopt:{cmd:r(by)}}parsed {opt by()} variables{p_end}
{synopt:{cmd:r(keepusing)}}parsed {opt keepu:sing()} variables{p_end}
{synopt:{cmd:r(prefix)}}parsed {opt p:refix()} string{p_end}
{synopt:{cmd:r(suffix)}}parsed {opt s:uffix()} string{p_end}
{synopt:{cmd:r(unmatched)}}parsed {opt unmatch:ed()} mode{p_end}
{synopt:{cmd:r(closed)}}parsed {opt closed()} mode{p_end}
{synopt:{cmd:r(missing)}}parsed {opt miss:ing()} mode{p_end}
{synopt:{cmd:r(frame)}}target frame name, when {opt frame()} is used{p_end}
{synopt:{cmd:r(saving)}}output filename, when {opt saving()} is used{p_end}
{synopt:{cmd:r(nearest)}}parsed {opt near:est()} mode{p_end}
{synopt:{cmd:r(ties)}}parsed {opt ties()} mode{p_end}
{synopt:{cmd:r(sort)}}{cmd:sort}, when final output sorting is active{p_end}
{synopt:{cmd:r(nosort)}}{cmd:nosort}, when specified{p_end}
{synopt:{cmd:r(assert)}}parsed {opt as:sert()} tokens{p_end}
{synopt:{cmd:r(generate)}}parsed {opt gen:erate()} variable{p_end}
{synopt:{cmd:r(distance)}}parsed {opt dist:ance()} variable{p_end}
{synopt:{cmd:r(masterid)}}parsed {opt masterid()} variable{p_end}
{synopt:{cmd:r(usingid)}}parsed {opt usingid()} variable{p_end}
{synopt:{cmd:r(maxpairs)}}parsed {opt maxp:airs()} limit{p_end}
{synopt:{cmd:r(all)}}{opt all}, when specified{p_end}
{synopt:{cmd:r(stats)}}{opt stats}, when specified{p_end}
{synopt:{cmd:r(dryrun)}}{opt dryr:un}, when specified{p_end}
{synopt:{cmd:r(count)}}{opt count}, when specified{p_end}
{synopt:{cmd:r(verbose)}}{opt verbose}, when specified{p_end}
{synopt:{cmd:r(backend)}}pair-generation backend selected: {cmd:sweep}, {cmd:binary}, or {cmd:overlap}{p_end}
{p2colreset}{...}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.2.0, 30jun2026{p_end}


{title:Also see}

{psee}
Online:  {helpb merge}, {helpb joinby}, {helpb frames}, {helpb rangestat}, {helpb rangejoin}

{hline}

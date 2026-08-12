{smcl}
{* *! version 0.1.0 29jun2026}{...}
{vieweralsosee "[G-2] graph twoway rbar" "help twoway rbar"}{...}
{vieweralsosee "[ST] stset" "help stset"}{...}
{viewerjumpto "Syntax" "swimlane##syntax"}{...}
{viewerjumpto "Description" "swimlane##description"}{...}
{viewerjumpto "Options" "swimlane##options"}{...}
{viewerjumpto "Examples" "swimlane##examples"}{...}
{viewerjumpto "Stored results" "swimlane##results"}{...}
{viewerjumpto "Author" "swimlane##author"}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:swimlane} {hline 2}}Swimmer and state swimlane plots{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:swimlane}
{ifin}
{cmd:,}
{opth id(varname)}
[{it:options}]

{synoptset 34 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Mode and input}
{synopt:{opth id(varname)}}subject identifier; required{p_end}
{synopt:{opth idl:abel(varname)}}display label separate from {opt id()}{p_end}
{synopt:{opt mode()}}{cmd:auto}, {cmd:swimmer}, or {cmd:state}; default is {cmd:auto}{p_end}
{synopt:{opth sta:rt(varname)}}interval start time for long input{p_end}
{synopt:{opth sto:p(varname)}}interval stop time for long input{p_end}
{synopt:{opth state(varname)}}state category; selects {cmd:mode(state)}{p_end}
{synopt:{opth dur:ation(varname)}}subject duration for wide swimmer input{p_end}
{synopt:{opth ev:ents(varlist)}}event-time variables for wide swimmer input{p_end}
{synopt:{opt eventl:abels()}}labels for {opt events()}, in order{p_end}
{synopt:{opth eventv:ar(varname)}}row-level event indicator for long input{p_end}
{synopt:{opt eventt:ime(name)}}event time in active data or {opt eventframe()}{p_end}
{synopt:{opt eventty:pe(name)}}event category in active data or event frame{p_end}
{synopt:{opt eventf:rame(name)}}read events from a separate frame{p_end}
{synopt:{opt eventid(name)}}ID variable in {opt eventframe()}{p_end}
{synopt:{opth intervalsta:rt(varname)}}start of an exact interval layer{p_end}
{synopt:{opth intervalsto:p(varname)}}stop of an exact interval layer{p_end}
{synopt:{opth intervalt:ype(varname)}}category for interval layers{p_end}
{synopt:{opt intervalc:heck(string)}}{cmd:warn}, {cmd:error}, or {cmd:off}{p_end}
{synopt:{opth ong:oing(varname)}}1/0 indicator for open-ended bars{p_end}
{synopt:{opth ori:gin(varname)}}subject-specific time origin{p_end}
{synopt:{opt nost:set}}disable automatic {cmd:stset} input detection{p_end}
{synopt:{opt eventsa:bsolute}}treat wide event times as absolute{p_end}
{synopt:{opt stateo:rder()}}explicit display order for {opt state()} categories{p_end}
{synopt:{opt cens:or}}mark censored {cmd:stset} subjects{p_end}

{syntab:Lane layout}
{synopt:{opt sort()}}lane ordering; see {it:Options}{p_end}
{synopt:{opt maxid:s(#|all)}}subject cap or all subjects; default 60{p_end}
{synopt:{opt dens:ity(string)}}{cmd:standard}, {cmd:dense}, or {cmd:auto}{p_end}
{synopt:{opt lanet:ype(string)}}{cmd:bar} or {cmd:line}; default {cmd:bar}{p_end}
{synopt:{opt laneh:eight(spec)}}physical points or logical pixels per lane{p_end}
{synopt:{opt barw:idth(#)}}bar thickness in y units; default 0.6{p_end}
{synopt:{opt barl:abel(spec)}}annotate bar tips; default {cmd:none}{p_end}
{synopt:{opt mark:ers(string)}}{cmd:auto}, {cmd:full}, {cmd:minimal}, or {cmd:none}{p_end}
{synopt:{opt cont:inuation(string)}}{cmd:auto}, {cmd:arrow}, {cmd:cap}, or {cmd:none}{p_end}
{synopt:{opt idlabels(string)}}{cmd:all}, {cmd:none}, {cmd:auto}, or {cmd:every #}{p_end}
{synopt:{opth labelif(varname)}}also label selected subjects{p_end}
{synopt:{opt noyl:abels}}suppress subject labels on the y axis{p_end}
{synopt:{opt nog:raph}}build table and results without a graph{p_end}
{synopt:{opt byl:ayout(string)}}{cmd:aligned} or {cmd:compact} facets{p_end}

{syntab:Grouping}
{synopt:{opth by(varname)}}draw faceted panels by a subject-level group{p_end}
{synopt:{opth blockb:y(varname)}}one-panel block headers and separators{p_end}
{synopt:{opth color:by(varname)}}color swimmer duration bars by a group{p_end}

{syntab:Styling}
{synopt:{opt refl:ine(numlist)}}vertical reference lines{p_end}
{synopt:{opt col:ors(colorlist)}}override the default color palette{p_end}
{synopt:{opt pal:ette(string)}}named accessible palette preset{p_end}
{synopt:{opt msym:bols(symbols)}}marker symbols for event series{p_end}
{synopt:{opt msiz:e(markersizestyle)}}event marker size{p_end}
{synopt:{opt ti:tle(string)}}graph title{p_end}
{synopt:{opt sub:title(string)}}graph subtitle{p_end}
{synopt:{opt note(string)}}graph note{p_end}
{synopt:{opt xti:tle(string)}}x-axis title; default {cmd:Time}{p_end}
{synopt:{opt yti:tle(string)}}y-axis title; default {cmd:Subject}{p_end}
{synopt:{opt leg:end(string)}}override the generated legend{p_end}
{synopt:{opt sch:eme(schemename)}}graph scheme; default is active scheme{p_end}
{synopt:{opt name(name[, replace])}}graph name; default {cmd:swimlane}{p_end}
{synopt:{opt sav:ing(filename[, ...])}}pass through to graph {opt saving()}{p_end}
{synopt:{opt addp:lot(plot)}}append canonical-data {cmd:twoway} layers{p_end}

{syntab:Export}
{synopt:{opt exp:ort(filename[, ...])}}export the graph with {cmd:graph export}{p_end}
{synopt:{opt save:data(filename)}}write the lane table as {cmd:.csv}, {cmd:.md}, or {cmd:.dta}{p_end}
{synopt:{opt fra:me(name[, replace])}}copy the lane table to a persistent frame{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Additional {help twoway_options} are passed to the underlying {cmd:twoway}
call.


{marker description}{...}
{title:Description}

{pstd}
{cmd:swimlane} draws one horizontal lane per subject, with time on the
x axis and subjects stacked on the y axis. In {cmd:mode(swimmer)}, each
subject has one duration bar and optional event markers. In
{cmd:mode(state)}, each subject can have multiple colored intervals for
states, treatments, or exposure categories.

{pstd}
Input can be wide, long, or already {cmd:stset}. Wide input uses one row
per subject with {opt duration()} and optional {opt events()}. Long input
uses {opt start()} and {opt stop()}, with {opt state()} for state-colored
segments and optional exact interval layers. Events may instead come from a
separate frame. If neither time source is specified and the data are
{cmd:stset}, {cmd:swimlane} uses {cmd:_t0}, {cmd:_t}, {cmd:_d}, and {cmd:_st}. Only
observations in the {cmd:_st==1} analysis sample contribute lanes,
group levels, or subject-level consistency checks.

{pstd}
All input shapes are resolved to a canonical lane table before plotting. The
table that {opt savedata()} writes and {opt frame()} copies contains
{cmd:lane}, {cmd:rank}, {cmd:panel}, {cmd:id}, {cmd:label}, {cmd:seg},
{cmd:rowtype}, {cmd:series}, {cmd:start}, {cmd:stop}, {cmd:xpoint},
{cmd:duration}, {cmd:ongoing}, {cmd:group}, {cmd:grouplab}, {cmd:series_k},
{cmd:sort_key}, {cmd:sort_direction}, {cmd:sort_missing}, {cmd:sort_value},
{cmd:label_selected}, {cmd:block}, {cmd:blocklab}, and {cmd:block_start}. {cmd:rank}
is the global sorted subject rank, {cmd:panel} identifies a
{opt by()} panel (or is 1 without facets), and {cmd:lane} is the plotted y
position. {cmd:label_selected} records {opt labelif()}; block columns record
contiguous {opt blockby()} runs. {cmd:rowtype} is {cmd:bar} (a duration/state span), {cmd:interval}
(an exact added span), {cmd:event} (a point at {cmd:xpoint}), or {cmd:censor}
(a censoring marker). {cmd:seg} numbers spans, and {cmd:series} names the state,
interval, or event category. A source {cmd:%t} format is applied to
{cmd:start}, {cmd:stop}, and {cmd:xpoint} so the table and x axis remain
calendar-aware.


{marker options}{...}
{title:Options}

{dlgtab:Mode and input}

{phang}
{opth id(varname)} specifies the subject identifier. It may be numeric or
string. {cmd:strL} identifiers are supported when every retained value fits
within Stata's 2,045-byte fixed-string limit; longer values return an error
rather than being truncated.

{phang}
{opth idlabel(varname)} specifies the subject label drawn on the y axis while
{opt id()} remains the analytic key. It may be numeric or string, must be
nonmissing, and must be constant within each subject.

{phang}
{opt mode()} selects the visual mode. {cmd:auto} uses {cmd:state} when
{opt state()} is specified and {cmd:swimmer} otherwise. {cmd:mode(state)}
requires {opt state()}.

{phang}
{opth start(varname)} and {opth stop(varname)} specify interval endpoints
for long input. In swimmer mode, intervals are collapsed to one span per
subject. In state mode, each interval is drawn as a segment. Long input cannot
be combined with the wide-input {opt duration()}, {opt events()}, or
{opt origin()} options. Every interval row must have {cmd:start<=stop}.

{phang}
{opth state(varname)} supplies the categorical state for segment colors. Value labels
are used when present.

{phang}
{opth duration(varname)} supplies the subject duration for wide swimmer
input.

{phang}
{opth events(varlist)} supplies event-time variables for wide swimmer input. Missing
event times are allowed and produce no marker for that subject.

{phang}
{opt eventlabels()} supplies event labels in the same order as
{opt events()}. If omitted, event variable names are used.

{phang}
{opth eventvar(varname)} marks event rows in long input. Each retained row
whose {opt eventvar()} value is nonzero produces an event marker. The
{opt start()} and {opt stop()} options are required, but an event-only row may
omit its {cmd:stop}; in state mode it may also omit {opt state()}. Such rows do
not become interval bars. This is the long-format counterpart to the wide
{opt events()} columns.

{phang}
{opt eventtime(name)} supplies the time of each event. With {opt eventvar()},
it names a numeric variable in the active data; if omitted there, the marker
is placed at row {cmd:stop} (or {cmd:start} when {cmd:stop} is missing). With
{opt eventframe()}, it names a required numeric variable in that frame.

{phang}
{opt eventtype(name)} categorizes events into marker series; value labels are
honored. It is read from the active data with {opt eventvar()} and from the
named frame with {opt eventframe()}. If omitted, all events share a single
{cmd:Event} series. Missing categories also use {cmd:Event}.

{phang}
{opt eventframe(name)} reads event rows from a separate Stata frame. The frame
is not modified. Each nonmissing {opt eventtime()} value is matched exactly to
the lane data through {opt eventid()}; an event ID absent from the lane data is
an error, event records for subjects excluded by {it:if} or {it:in} are ignored,
and {opt eventframe()} cannot be combined with {opt eventvar()}.

{phang}
{opt eventid(name)} names the analytic ID in {opt eventframe()}. By default,
the command looks for the same variable name supplied to {opt id()}.

{phang}
{opth intervalstart(varname)} and {opth intervalstop(varname)} specify exact
endpoints for an additional line layer. They require long {opt start()} and
{opt stop()} input, may be missing together on rows without a layer, and are
never filled, merged, clipped, or otherwise reinterpreted.

{phang}
{opth intervaltype(varname)} categorizes interval layers and supplies their
legend labels. Value labels are used when present. If omitted, all added
intervals use the {cmd:Interval} series.

{phang}
{opt intervalcheck(string)} audits state-mode intervals within each
subject. {cmd:warn} (the default in state mode) reports overlap and gap counts,
{cmd:error} rejects either condition, and {cmd:off} suppresses messages without
repairing coordinates. The counts are returned in {cmd:r()} under all three
settings.

{phang}
{opth ongoing(varname)} marks open-ended swimmer bars. Nonzero values draw
right-pointing arrow caps, and missing values are treated as zero. With
{cmd:stset} input, supplying {opt ongoing()} overrides the default based on
the final interval's failure status.

{phang}
{opth origin(varname)} sets each wide lane's start. The bar endpoint is the
origin plus {opt duration()}, and relative {opt events()} times are also added
to the origin. By default, origins are zero.

{phang}
{opt nostset} disables automatic use of recognized {cmd:stset} data.

{phang}
{opt eventsa:bsolute} treats {opt events()} values as absolute time rather
than adding {opt origin()}; it requires {opt events()}.

{phang}
{opt stateorder()} sets an explicit display order for {opt state()} categories, overriding
the default alphabetical/numeric order. Give the state labels (or values, when
unlabeled) in the desired order, e.g. {cmd:stateorder("High" "Medium" "Low")}. The
first listed category takes the first color and legend position. States not
listed follow the listed ones in natural order. Every listed category must map
to exactly one observed state; unknown, duplicate, or ambiguous labels return
an error. It requires {opt state()}.

{phang}
{opt censor} adds a distinct open-circle marker for {cmd:stset} subjects whose
final interval ends without the event ({cmd:_d==0}), distinguishing censoring
from the terminal {cmd:Event} marker. It requires {cmd:stset} data and leaves the
ongoing-arrow behavior unchanged.

{dlgtab:Lane layout}

{phang}
{opt sort()} controls subject order. Supported keys are {cmd:duration},
{cmd:start}, {cmd:id}, {cmd:none}, or a subject-level variable. One key retains
the legacy {cmd:sort(duration descending)} form. Multiple keys use an explicit
sign on every key, for example {cmd:sort(+arm -duration +id missing(last))},
and at most eight keys are allowed. Every custom key must be constant within
{opt id()}; repeated keys and combining {cmd:none} with another key are
errors. Missing values default to last at every key in both directions. A
final ascending analytic-ID tie-break makes repeated runs deterministic. The
first sorted subject appears at the top. Defaults are
{cmd:duration descending missing(last)} in swimmer mode and
{cmd:id ascending missing(last)} in state mode. The canonical table stores
all key names and directions; multi-key values use a length-prefixed encoding
in {cmd:sort_value} so string values remain unambiguous.

{phang}
{opt maxids(#|all)} limits the plot to the first {it:#} sorted subjects or,
with {cmd:all}, retains every subject. The default is 60. A numeric cap is
never interpreted as {cmd:all}; truncation is reported in {cmd:r(truncated)}.

{phang}
{opt density(string)} coordinates the renderer. {cmd:standard} is the default
and preserves {cmd:maxids(60)}, bars, full markers, arrows, and all labels. {cmd:dense}
instead implies {cmd:maxids(all)}, {cmd:lanetype(line)},
{cmd:laneheight(5pt)}, {cmd:markers(minimal)}, {cmd:continuation(cap)}, and
automatic labels. {cmd:auto} selects {cmd:dense} above 60 available subjects
and {cmd:standard} otherwise, and prints the choice. Explicit {opt maxids()},
{opt lanetype()}, {opt laneheight()} (or direct {cmd:ysize()}), {opt markers()},
{opt continuation()}, and {opt idlabels()} settings override the preset. The
resolved choices are returned and attached to persistent canonical output.

{phang}
{opt lanetype(string)} selects filled horizontal {cmd:bar} lanes or thin
{cmd:line} lanes. State and {opt colorby()} colors are preserved segment by
segment in either form. The default is {cmd:bar}.

{phang}
{opt laneheight(spec)} requests a physical height for every plotted lane, for
example {cmd:laneheight(5pt)} or {cmd:laneheight(8px)}. A value without a unit
is interpreted as printer points; logical pixels use 96 pixels per inch. The
command derives {cmd:ysize()} from the largest lane number and caps the graph
at Stata's 800-inch renderer limit. It cannot be combined with a direct
{cmd:ysize()} option. Faceted graphs use a deterministic square-root column
layout, and the derived height accounts for every vertical panel row. The
resolved height is returned even when a cap applies.

{phang}
{opt barwidth(#)} controls bar thickness in y-axis units.

{phang}
{opt barlabel(spec)} annotates each lane's bar tip. {cmd:barlabel(duration)}
prints the bar duration at its right end; {cmd:none} (the default) prints
nothing. It is supported in swimmer mode only.

{phang}
{opt markers(string)} controls event and censoring glyphs. {cmd:full} uses the
configured symbols and sizes, {cmd:minimal} uses tiny ticks, and {cmd:none}
suppresses glyphs without removing their canonical rows or stored counts. The
{cmd:auto} policy resolves to {cmd:full} under the standard renderer.

{phang}
{opt continuation(string)} controls the independent open-ended treatment mark; the
{cmd:arrow} policy draws a full arrow, {cmd:cap} draws a short terminal
tick, and
{cmd:none} suppresses it. {cmd:auto} resolves to {cmd:arrow} under the standard
renderer.

{phang}
{opt idlabels(string)} controls subject tick labels. {cmd:all} labels every
lane, {cmd:none} labels none, and {cmd:every #} labels ranks 1, 1+{it:#},
1+2{it:#}, and so on. {cmd:auto} labels all lanes only at a resolved height of
at least 10 points per lane; otherwise it labels only subjects selected by
{opt labelif()} or none when no selection is supplied. The standard preset
defaults to {cmd:all}; the dense preset defaults to {cmd:auto}.

{phang}
{opth labelif(varname)} is a numeric subject-level flag. Nonzero, nonmissing
values add that subject to {cmd:idlabels(every #)} and retain selected labels
when {cmd:idlabels(auto)} suppresses the full set. It must be constant within
{opt id()}; missing values mean not selected. It cannot be combined with
{cmd:idlabels(none)}.

{phang}
{opt noylabels} is an alias for {cmd:idlabels(none)} and cannot be combined
with {opt idlabels()}.

{phang}
{opt nograph} builds the canonical lane table and stored results without
drawing a graph. It pairs with {opt savedata()} and {opt frame()} for
pipeline use, and still returns {cmd:r(cmdline)} so the {cmd:twoway} command can
be inspected. It cannot be combined with {opt export()} or
{opt saving()}, and leaves {cmd:r(graphname)} empty.

{pstd}
The command projects physical lane height from the resolved graph
{cmd:ysize()} (4 inches by default). Below 1.25 points per lane it prints a
readability note without dropping subjects or suppressing detail. Use a taller
graph, vector export, or an explicit numeric subject cap when individual rows
must remain traceable.

{phang}
{opt bylayout(string)} controls the lane grid when {opt by()} is
specified. {cmd:aligned} (the default) preserves one common lane grid across
panels, while {cmd:compact} renumbers lanes inside each panel and uses
panel-specific y scales with labels drawn beside their own bars.

{dlgtab:Grouping and styling}

{phang}
{opth by(varname)} draws panels by group. A maximum of 12 groups is allowed,
and the group must be constant within each {opt id()}.

{phang}
{opth blockby(varname)} draws one-panel headers and separators at every
contiguous run of the subject-level block variable in global rank order. The
variable must be nonmissing and constant within {opt id()}. Put it first in a
multi-key {opt sort()} when each category should form exactly one block; a
noncontiguous category deliberately creates repeated headers. {opt blockby()}
can be paired with {opt colorby()} using a different variable, so headers
organize one dimension while lane color encodes another. It cannot be combined
with faceted {opt by()}.

{phang}
{opth colorby(varname)} colors duration bars in swimmer mode by a
subject-level group. The variable may differ from {opt blockby()}. It cannot be
combined with {opt by()} or {opt state()}, and it must be constant within each
{opt id()}.

{phang}
{opt refline(numlist)} adds dashed vertical reference lines.

{phang}
{opt colors(colorlist)} overrides the default color order
({cmd:navy cranberry forest_green dkorange purple teal maroon olive ...}). Colors
are consumed by bars, interval layers, and then event-marker series, so a
marker is never drawn in the same color as the bar it sits on. Bar fills,
marker palette, and the plot background otherwise follow the active graph
{help scheme}.

{phang}
{opt palette(string)} selects a named color preset. {cmd:default} uses the
legacy package palette, {cmd:colorblind} uses an accessible named-color order,
{cmd:mono} uses grayscale, and {cmd:scheme} leaves layer colors to the active
graph scheme. An explicit {opt colors()} list takes precedence.

{phang}
{opt msymbols()} and {opt msize()} control event marker symbols and size. Event markers
carry a thin white outline so they stay visible on top of the duration bars.

{phang}
{opt scheme()} honors the specified graph scheme. If omitted, the active
Stata scheme is used.

{phang}
{opt title(string)}, {opt subtitle(string)}, and {opt note(string)} set graph
text.

{phang}
{opt xtitle(string)} and {opt ytitle(string)} set axis titles. Their defaults
are {cmd:Time} and {cmd:Subject}, respectively.

{phang}
{opt legend(string)} customizes the generated legend. Positioning options are
merged with generated series labels; {cmd:off} or {cmd:order()} takes full
control.

{phang}
{opt addplot(plot)} appends one or more parenthesized {cmd:twoway} layers to
the generated plot list. The layer runs in the canonical frame and may use
{cmd:lane}, {cmd:id}, {cmd:label}, {cmd:rowtype}, {cmd:series}, {cmd:start},
{cmd:stop}, {cmd:xpoint}, and the other canonical columns.

{phang}
{opt name(name[, replace])} sets the graph name. The default graph is
{cmd:swimlane} and is replaced on repeated calls. For an explicitly named
graph that already exists, specify {cmd:replace}; otherwise the command exits
without overwriting it.

{phang}
{opt saving(filename[, ...])} passes the filename and trailing options to the
underlying graph {opt saving()} option.

{dlgtab:Export}

{phang}
{opt savedata(filename)} writes the resolved canonical lane table. Supported
extensions are {cmd:.csv}, {cmd:.md}, and {cmd:.dta}. The {cmd:.dta} output and
persistent canonical frames carry the dataset characteristic
{cmd:swimlane_schema_version}; all formats include the schema's rank and sort
metadata columns. Frames and {cmd:.dta} files also carry the resolved render
mode, lane type, label, marker, continuation, lane-height, graph-height, and
panel-count characteristics, plus the block count and {opt blockby()} name.

{phang}
{opt frame(name[, replace])} copies the resolved canonical lane table to a
persistent frame. The output name must differ from the active input frame and
from any frame named in {opt eventframe()}; protected source frames are never
replaced, even when {cmd:replace} is specified.

{phang}
{opt export(filename[, ...])} exports the graph using {cmd:graph export}.


{marker examples}{...}
{title:Examples}

{pstd}{bf:Wide swimmer input}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id duration response progression ongoing}{p_end}
{phang2}{cmd:1 140 30 120 1}{p_end}
{phang2}{cmd:2  60 20   . 0}{p_end}
{phang2}{cmd:3  30  . 25 0}{p_end}
{phang2}{cmd:4 200 80 150 1}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. swimlane, id(id) duration(duration) events(response progression) eventlabels("Response" "Progression") ongoing(ongoing)}{p_end}

{pstd}{bf:Long state input}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id start stop state}{p_end}
{phang2}{cmd:1 0 2 1}{p_end}
{phang2}{cmd:1 2 4 2}{p_end}
{phang2}{cmd:2 0 5 1}{p_end}
{phang2}{cmd:3 1 3 3}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. label define st 1 "Treatment A" 2 "Treatment B" 3 "Off treatment"}{p_end}
{phang2}{cmd:. label values state st}{p_end}
{phang2}{cmd:. swimlane, id(id) start(start) stop(stop) state(state)}{p_end}

{pstd}{bf:Long interval input with event markers}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id start stop evflag evtime evtype}{p_end}
{phang2}{cmd:1 0 100 1 40 1}{p_end}
{phang2}{cmd:1 100 200 0 . .}{p_end}
{phang2}{cmd:2 0 150 1 60 2}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. label define evt 1 "Response" 2 "Progression"}{p_end}
{phang2}{cmd:. label values evtype evt}{p_end}
{phang2}{cmd:. swimlane, id(id) start(start) stop(stop) eventvar(evflag) eventtime(evtime) eventtype(evtype)}{p_end}

{pstd}{bf:Exact response intervals and an arbitrary overlay}

{phang2}{cmd:. generate response_start = 20 if evflag}{p_end}
{phang2}{cmd:. generate response_stop = evtime if evflag}{p_end}
{phang2}{cmd:. generate str8 response_type = "Response" if evflag}{p_end}
{phang2}{cmd:. swimlane, id(id) start(start) stop(stop) intervalstart(response_start) intervalstop(response_stop) intervaltype(response_type) addplot((scatter lane stop if rowtype == "bar", msymbol(none)))}{p_end}

{pstd}{bf:Events stored in a separate frame}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id start stop}{p_end}
{phang2}{cmd:1 0 100}{p_end}
{phang2}{cmd:2 0 150}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. capture frame drop events}{p_end}
{phang2}{cmd:. frame create events}{p_end}
{phang2}{cmd:. frame change events}{p_end}
{phang2}{cmd:. input id evtime str12 evtype}{p_end}
{phang2}{cmd:1 40 "Response"}{p_end}
{phang2}{cmd:2 60 "Progression"}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. frame change default}{p_end}
{phang2}{cmd:. swimlane, id(id) start(start) stop(stop) eventframe(events) eventtime(evtime) eventtype(evtype)}{p_end}

{pstd}{bf:Data-only build (no graph) with the generated command}

{phang2}{cmd:. swimlane, id(id) start(start) stop(stop) eventframe(events) eventtime(evtime) eventtype(evtype) nograph frame(lanes, replace)}{p_end}
{phang2}{cmd:. display `"`r(cmdline)'"'}{p_end}

{pstd}{bf:stset input and canonical table export}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input id t d}{p_end}
{phang2}{cmd:1 5 0}{p_end}
{phang2}{cmd:2 8 1}{p_end}
{phang2}{cmd:3 3 0}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. stset t, failure(d) id(id)}{p_end}
{phang2}{cmd:. swimlane, id(id) savedata(swimlane_table.csv)}{p_end}

{pstd}{bf:High-density cookbook: 60, 250, and 1,000 subjects}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set obs 1000}{p_end}
{phang2}{cmd:. generate long id = _n}{p_end}
{phang2}{cmd:. generate double duration = 20 + mod(37 * id, 181)}{p_end}
{phang2}{cmd:. generate byte stage_group = 1 + mod(id - 1, 4)}{p_end}
{phang2}{cmd:. generate byte arm = 1 + mod(floor((id - 1) / 4), 3)}{p_end}
{phang2}{cmd:. label define stage_group 1 "Stage I" 2 "Stage II" 3 "Stage III" 4 "Stage IV"}{p_end}
{phang2}{cmd:. label values stage_group stage_group}{p_end}
{phang2}{cmd:. label define treatment 1 "Standard" 2 "Targeted" 3 "Combination"}{p_end}
{phang2}{cmd:. label values arm treatment}{p_end}
{phang2}{cmd:. generate byte highlight = mod(id, 97) == 0}{p_end}
{phang2}{cmd:. swimlane if id <= 60, id(id) duration(duration) density(standard)}{p_end}
{phang2}{cmd:. swimlane if id <= 250, id(id) duration(duration) density(dense) laneheight(5pt) idlabels(every 25) export(swimlane_250.pdf, replace)}{p_end}
{phang2}{cmd:. swimlane, id(id) duration(duration) density(dense) sort(+stage_group -duration +id) blockby(stage_group) colorby(arm) idlabels(every 100) labelif(highlight) export(swimlane_1000.pdf, replace)}{p_end}

{pstd}
The 60-subject call shows the backward-compatible standard graph. The 250-
and 1,000-subject calls use tall thin-line output with reproducible physical
lane heights. In the 1,000-subject call, disease stage defines blocks and
treatment arm defines colors within each block. PDF or SVG is preferable to
PNG when zooming or document scaling must preserve thin individual lanes; {cmd:maxids(all)}
or
{cmd:density(dense)} guarantees inclusion, not legibility after rasterization; inspect
{cmd:r(points_per_lane)} and {cmd:r(readability_warning)}.

{pstd}{bf:Wrap a ranked subset into compact panels}

{phang2}{cmd:. generate int page = ceil(id / 50)}{p_end}
{phang2}{cmd:. swimlane if id <= 250, id(id) duration(duration) density(dense) sort(+page -duration +id) by(page) bylayout(compact) idlabels(none) ysize(12)}{p_end}

{pstd}
This explicit five-panel recipe is useful for a one-page overview. It is not
automatic pagination: the source variable defines membership, and
{cmd:panel} in the canonical table records the resulting facet.

{pstd}{bf:Overview, inspect, drill down, and paginate}

{phang2}{cmd:. swimlane, id(id) duration(duration) density(dense) sort(+stage_group -duration +id) blockby(stage_group) colorby(arm) frame(all_lanes, replace)}{p_end}
{phang2}{cmd:. frame all_lanes: keep if rowtype == "bar" & seg == 1}{p_end}
{phang2}{cmd:. frame all_lanes: keep id rank}{p_end}
{phang2}{cmd:. frame all_lanes: isid id}{p_end}
{phang2}{cmd:. frlink 1:1 id, frame(all_lanes)}{p_end}
{phang2}{cmd:. frget rank, from(all_lanes)}{p_end}
{phang2}{cmd:. summarize duration if inrange(rank, 101, 125), detail}{p_end}
{phang2}{cmd:. swimlane if inrange(rank, 101, 125), id(id) duration(duration) sort(+rank +id missing(last)) maxids(all) idlabels(all) laneheight(12pt)}{p_end}
{phang2}{cmd:. forvalues p = 1/20 {c -(}}{p_end}
{phang2}{cmd:.     local lo = 50 * (`p' - 1) + 1}{p_end}
{phang2}{cmd:.     local hi = 50 * `p'}{p_end}
{phang2}{cmd:.     swimlane if inrange(rank, `lo', `hi'), id(id) duration(duration) sort(+rank +id missing(last)) maxids(all) idlabels(all) laneheight(12pt) export(swimlane_page_`p'.pdf, replace)}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}
The first call fixes one global rank contract. The linked rank supports exact
inspection, labelled drill-down, and full-resolution pages without silently
changing order. For long source data use {cmd:frlink m:1 id} instead.

{pstd}{bf:Sorting recipes}

{pstd}
Always state missing placement. Common one-key calls are
{cmd:sort(duration descending missing(last))},
{cmd:sort(start ascending missing(last))},
{cmd:sort(id ascending missing(last))}, and
{cmd:sort(site ascending missing(last))}. A wide event time is an ordinary
subject variable, for example
{cmd:sort(progression ascending missing(last))}. Arm-within-duration is
{cmd:sort(+arm -duration +id missing(last))}.

{pstd}
For a prespecified review sequence, create and validate a subject-level
numeric key, for example {cmd:assert !missing(review_order)} followed by
{cmd:sort(+review_order +id missing(last))}. For long data, prepare semantic
metrics explicitly before plotting: use
{cmd:bysort id: egen first_progression = min(cond(event == 1, event_time, .))}
for first event, or
{cmd:bysort id: egen time_in_state = total(cond(state == 2, stop-start, 0))}
for cumulative state time; then sort those subject-constant variables with an
explicit missing policy. {cmd:swimlane} never guesses an aggregation from an
event label.


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:swimlane} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N_subjects)}}subjects retained after {opt maxids()}{p_end}
{synopt:{cmd:r(N_subjects_total)}}subjects before {opt maxids()}{p_end}
{synopt:{cmd:r(N_segments)}}bar or segment rows in the canonical table{p_end}
{synopt:{cmd:r(N_events)}}event rows in the canonical table{p_end}
{synopt:{cmd:r(N_intervals)}}interval-layer rows in the canonical table{p_end}
{synopt:{cmd:r(N_ongoing)}}open-ended subject bars{p_end}
{synopt:{cmd:r(N_censored)}}censoring rows created by {opt censor}{p_end}
{synopt:{cmd:r(N_groups)}}group levels among retained subjects{p_end}
{synopt:{cmd:r(N_series)}}distinct rendered series labels{p_end}
{synopt:{cmd:r(N_events_outside)}}events outside their subject's observed span{p_end}
{synopt:{cmd:r(N_overlaps)}}overlapping state-interval starts{p_end}
{synopt:{cmd:r(N_gaps)}}gaps between state intervals{p_end}
{synopt:{cmd:r(truncated)}}1 when {opt maxids()} omitted subjects{p_end}
{synopt:{cmd:r(median_duration)}}median subject duration{p_end}
{synopt:{cmd:r(min_duration)}}minimum subject duration{p_end}
{synopt:{cmd:r(max_duration)}}maximum subject duration{p_end}
{synopt:{cmd:r(maxids)}}lane cap used{p_end}
{synopt:{cmd:r(graph_height)}}resolved graph height in inches{p_end}
{synopt:{cmd:r(points_per_lane)}}projected physical points per lane{p_end}
{synopt:{cmd:r(readability_warning)}}1 when projected lane height is below 1.25 points{p_end}
{synopt:{cmd:r(laneheight)}}resolved physical points per lane{p_end}
{synopt:{cmd:r(N_panels)}}number of graph panels{p_end}
{synopt:{cmd:r(N_blocks)}}number of contiguous {opt blockby()} runs{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(mode)}}{cmd:swimmer} or {cmd:state}{p_end}
{synopt:{cmd:r(shape)}}{cmd:wide}, {cmd:long}, or {cmd:stset}{p_end}
{synopt:{cmd:r(graphname)}}name of the graph produced; empty under {opt nograph}{p_end}
{synopt:{cmd:r(cmdline)}}the assembled {cmd:twoway} command string{p_end}
{synopt:{cmd:r(timefmt)}}date/time display format carried to the axis, if any{p_end}
{synopt:{cmd:r(schema_version)}}canonical table schema version{p_end}
{synopt:{cmd:r(maxids_spec)}}requested numeric cap or {cmd:all}{p_end}
{synopt:{cmd:r(sort_spec)}}resolved key, direction, and missing policy{p_end}
{synopt:{cmd:r(render_mode)}}resolved {cmd:standard} or {cmd:dense} preset{p_end}
{synopt:{cmd:r(lanetype)}}resolved {cmd:bar} or {cmd:line} lane primitive{p_end}
{synopt:{cmd:r(label_policy)}}resolved subject-label policy{p_end}
{synopt:{cmd:r(markers)}}resolved marker policy{p_end}
{synopt:{cmd:r(continuation)}}resolved continuation policy{p_end}
{synopt:{cmd:r(blockby)}}source variable used for block headers, if any{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(states)}}series key and count, when series exist{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 0.1.0, 2026-06-29{p_end}

{hline}

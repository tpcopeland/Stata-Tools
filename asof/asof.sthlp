{smcl}
{* *! version 0.1.0  12aug2026}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{vieweralsosee "[D] frames" "help frames intro"}{...}
{viewerjumpto "Syntax" "asof##syntax"}{...}
{viewerjumpto "Description" "asof##description"}{...}
{viewerjumpto "Options" "asof##options"}{...}
{viewerjumpto "Selection rules" "asof##rules"}{...}
{viewerjumpto "Examples" "asof##examples"}{...}
{viewerjumpto "Stored results" "asof##results"}{...}
{viewerjumpto "Author" "asof##author"}{...}

{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:asof} {hline 2}}Attach values selected relative to a reference date{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:asof} {it:varlist} {help using} {it:filename} {ifin}{cmd:,}
{opth id(varname)} {opth date(varname)} {opth anchor(varname)}
{opt dir:ection(rule)} {opt sel:ect(rule)} [{it:options}]

{pstd}
{it:rule} for {opt direction()} is {cmd:before}, {cmd:onorbefore},
{cmd:after}, {cmd:onorafter}, or {cmd:both}. {it:rule} for
{opt select()} is {cmd:nearest}, {cmd:first}, or {cmd:last}.

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opth id(varname)}}identifier in master and using data{p_end}
{synopt:{opth date(varname)}}measurement date in using data{p_end}
{synopt:{opth anchor(varname)}}reference date in master data{p_end}
{synopt:{opt dir:ection(rule)}}eligible side of the anchor{p_end}
{synopt:{opt sel:ect(rule)}}record-selection rule{p_end}

{syntab:Eligibility}
{synopt:{opt win:dow(# #)}}inclusive signed day offsets{p_end}
{synopt:{opth range(varlist)}}inclusive observability bounds{p_end}
{synopt:{opth req:uire(varlist)}}required nonmissing using variables{p_end}

{syntab:Output}
{synopt:{opt suf:fix(string)}}append text to carried names; default {cmd:_asof}{p_end}
{synopt:{opt pre:fix(string)}}prepend text to carried names{p_end}
{synopt:{opt gen:erate(namelist)}}explicit output names, one per carried variable{p_end}
{synopt:{opt daten:ame(name)}}matched measurement date{p_end}
{synopt:{opt gapn:ame(name)}}signed gap in days{p_end}
{synopt:{opt matchn:ame(name)}}matched-record indicator{p_end}
{synopt:{opt replace}}overwrite existing output variables{p_end}

{syntab:Behavior}
{synopt:{opt ties(rule)}}tie rule: {cmd:before}, {cmd:after}, {cmd:first}, {cmd:last}, or {cmd:error}{p_end}
{synopt:{opt frame(name)}}read the using data from a frame copied by {cmd:asof}{p_end}
{synopt:{opt nowarn}}suppress the unmatched-observation message{p_end}
{synopt:{opt noi:sily}}display full match coverage{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:asof} selects exactly one eligible record from a long using dataset for
each distinct {cmd:id()} and {cmd:anchor()} pair in memory, then attaches the
requested values without unloading or reordering the master data. Repeated
master identifiers are allowed.

{pstd}
The carried {it:varlist} and {cmd:require()} are resolved against the using
data, including wildcard and hyphen-range notation.

{pstd}
Eligibility is the intersection of {cmd:direction()}, {cmd:window()}, and
{cmd:range()}. Missing range bounds are open. Records with missing {cmd:id()},
{cmd:date()}, or any {cmd:require()} variable are ineligible. Master rows with
a missing identifier or anchor are not changed and are counted in
{cmd:r(N_nokey)}.

{pstd}
Daily dates may be unformatted or formatted {cmd:%td}. Clock datetimes must be
formatted {cmd:%tc} on both sides. Mixing daily dates and clock datetimes
produces error 109. Window offsets and reported gaps are always measured in
days.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opth id(varname)} identifies persons or other entities. It must exist in both
datasets and must be numeric in both or string in both.

{phang}
{opth date(varname)} names the numeric measurement date in the using data.

{phang}
{opth anchor(varname)} names the numeric reference date in the master data.

{phang}
{opt direction(rule)} restricts records to one side of the
anchor. {cmd:before} and {cmd:after} are strict; {cmd:onorbefore} and
{cmd:onorafter} include an exact-anchor record; {cmd:both} imposes no side
restriction.

{phang}
{opt select(rule)} selects the nearest, earliest, or latest eligible date.

{dlgtab:Eligibility}

{phang}
{opt window(# #)} specifies inclusive signed day offsets from the anchor. For
example, {cmd:window(-365 30)} allows records from 365 days before through 30
days after the anchor. Specify {cmd:.} for either open bound.

{phang}
{opth range(varlist)} specifies lower and upper observability-bound variables
in the master. Missing bounds are open. Bounds must not vary among duplicate
master rows with the same identifier and anchor.

{phang}
{opth require(varlist)} specifies using variables that must all be
nonmissing. The default is every carried variable. Specify the date variable alone, such
as {cmd:require(visit_date)}, to allow missing carried values to be selected.

{dlgtab:Output}

{phang}
{opt suffix(string)} appends {it:string} to each carried name. The default is
{cmd:_asof}. It may not be combined with {cmd:prefix()}.

{phang}
{opt prefix(string)} prepends {it:string} to each carried name. It may not be combined with {cmd:suffix()}.

{phang}
{opt generate(namelist)} gives explicit output names and overrides name
construction by prefix or suffix. It must contain exactly one name per carried
variable.

{phang}
{opt datename(name)}, {opt gapname(name)}, and {opt matchname(name)} store the
matched measurement date, signed day gap, and 0/1 match indicator. A valid
master key with no eligible record receives missing carried values and a zero
match indicator. A master row outside {it:if}/{it:in}, or with a missing key,
is left unchanged.

{phang}
{opt replace} permits existing output variables. Numeric outputs require
numeric destinations and string outputs require string destinations.

{dlgtab:Behavior}

{phang}
{opt ties(rule)} resolves multiple equally ranked records. For
{cmd:select(nearest)}, the default is {cmd:before}; {cmd:after} chooses the
later date, {cmd:first}/{cmd:last} use original using-file order, and
{cmd:error} exits 459. For {cmd:select(first)} or {cmd:select(last)}, omitted
{cmd:ties()} defaults to {cmd:first}; explicit {cmd:ties(first)},
{cmd:ties(last)}, and {cmd:ties(error)} control duplicate-date
records. {cmd:ties(before)} and {cmd:ties(after)} are invalid with those two selection
rules.

{phang}
{opt frame(name)} copies {it:name} as the using data rather than reading
{it:filename}; the required using token may conventionally repeat the frame
name. The source frame is not changed.

{phang}
{opt nowarn} suppresses the standard unmatched-observation message.

{phang}
{opt noisily} prints the full coverage report.


{marker rules}{...}
{title:Selection rules}

{pstd}
Suppose the anchor is day 100 and eligible visits occur on days 70, 90, 110,
and 140:

{p2colset 8 26 28 2}{...}
{p2col:{bf:Rule}}{bf:Selected day}{p_end}
{p2col:{cmd:before + nearest}}90{p_end}
{p2col:{cmd:onorbefore + first}}70{p_end}
{p2col:{cmd:after + last}}140{p_end}
{p2col:{cmd:both + nearest}}90 by the default {cmd:ties(before)} rule{p_end}
{p2colreset}{...}

{pstd}
The nearest calculation minimizes the absolute date difference after every
eligibility restriction is applied. {cmd:r(N_ties)} counts distinct master
keys for which more than one using record had the selected rank.


{marker examples}{...}
{title:Examples}

{pstd}
Create a self-contained event file and master cohort, then select the closest
score on either side of each index date:

{phang2}{cmd:. tempfile events}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id double visit_date score edss}{p_end}
{phang2}{cmd:. 1 90 4 2}{p_end}
{phang2}{cmd:. 1 110 6 2.5}{p_end}
{phang2}{cmd:. 1 140 8 3}{p_end}
{phang2}{cmd:. 2 190 5 1.5}{p_end}
{phang2}{cmd:. 2 230 9 2.5}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. format %td visit_date}{p_end}
{phang2}{cmd:. save `events'}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long id double(index_date study_start followup_date)}{p_end}
{phang2}{cmd:. 1 100 50 150}{p_end}
{phang2}{cmd:. 2 200 160 240}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. format %td index_date study_start followup_date}{p_end}
{phang2}{cmd:. asof score using `events', id(id) date(visit_date) anchor(index_date) direction(both) select(nearest) generate(score_index) datename(score_date) gapname(score_gap) matchname(score_found)}{p_end}

{pstd}
Select the latest record on or before the end of observable follow-up:

{phang2}{cmd:. asof edss using `events', id(id) date(visit_date) anchor(followup_date) range(study_start followup_date) direction(onorbefore) select(last) suffix(_last)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:asof} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2:Scalars}{p_end}
{synopt:{cmd:r(N_master)}}master rows selected by {it:if}/{it:in}{p_end}
{synopt:{cmd:r(N_keys)}}distinct nonmissing identifier-anchor keys{p_end}
{synopt:{cmd:r(N_matched)}}master rows receiving a match{p_end}
{synopt:{cmd:r(N_unmatched)}}valid-key master rows without a match{p_end}
{synopt:{cmd:r(N_nokey)}}selected master rows with a missing identifier or anchor{p_end}
{synopt:{cmd:r(N_using)}}using rows read before eligibility filtering{p_end}
{synopt:{cmd:r(N_eligible)}}distinct using rows eligible for at least one key{p_end}
{synopt:{cmd:r(N_ties)}}distinct keys whose selected rank was tied{p_end}
{synopt:{cmd:r(gap_min)}}minimum signed gap over matched master rows{p_end}
{synopt:{cmd:r(gap_max)}}maximum signed gap over matched master rows{p_end}
{synopt:{cmd:r(gap_mean)}}mean signed gap over matched master rows{p_end}
{synopt:{cmd:r(gap_p50)}}median signed gap over matched master rows{p_end}

{p2col 5 22 26 2:Macros}{p_end}
{synopt:{cmd:r(varlist)}}input carried variables{p_end}
{synopt:{cmd:r(generate)}}resolved output names{p_end}
{synopt:{cmd:r(direction)}}resolved direction rule{p_end}
{synopt:{cmd:r(select)}}resolved selection rule{p_end}
{synopt:{cmd:r(ties)}}resolved tie rule{p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet

{pstd}
Version 0.1.0, 2026-08-12

{hline}

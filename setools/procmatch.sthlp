{smcl}
{* *! version 2.0.3  28feb2026}{...}
{viewerjumpto "Syntax" "procmatch##syntax"}{...}
{viewerjumpto "Description" "procmatch##description"}{...}
{viewerjumpto "Options" "procmatch##options"}{...}
{viewerjumpto "Subcommands" "procmatch##subcommands"}{...}
{viewerjumpto "Examples" "procmatch##examples"}{...}
{viewerjumpto "Stored results" "procmatch##results"}{...}
{viewerjumpto "Author" "procmatch##author"}{...}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:procmatch} {hline 2}}Procedure code matching for Swedish registry research{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Match procedure codes in diagnosis variables

{p 8 16 2}
{cmd:procmatch match}{cmd:,} {opt codes(string)} {opt procvars(varlist)}
[{opt gen:erate(name)} {opt replace} {opt prefix} {opt noisily}]

{pstd}
Extract first occurrence date of matching procedures

{p 8 16 2}
{cmd:procmatch first}{cmd:,} {opt codes(string)} {opt procvars(varlist)}
{opt datevar(varname)} {opt idvar(varname)}
[{opt gen:erate(name)} {opt gendatevar(name)} {opt replace} {opt prefix} {opt noisily}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:procmatch} provides utilities for working with KVA (Klassifikation av vardatgarder)
procedure codes in Swedish health registries. It supports pattern matching against
multiple procedure variables and extraction of first occurrence dates.

{pstd}
Swedish registries typically store up to 30 procedure codes per visit (proc1-proc30).
{cmd:procmatch} searches all specified procedure variables efficiently.


{marker subcommands}{...}
{title:Subcommands}

{phang}
{cmd:match} generates a binary indicator variable equal to 1 if any of the specified
procedure codes are found in any of the procedure variables.

{phang}
{cmd:first} extracts the first (earliest) date on which any of the specified
procedure codes occurred, aggregating by person ID. The dataset structure is
preserved (no rows are dropped); each row receives the person-level first date.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt codes(string)} specifies the procedure codes to match. Multiple codes can be
separated by spaces or commas. Codes are matched case-insensitively.

{phang}
{opt procvars(varlist)} specifies the procedure variable(s) to search.
Typically proc1-proc30 for inpatient/outpatient data.

{phang}
{opt datevar(varname)} (first only) specifies the date variable associated with
procedure records.

{phang}
{opt idvar(varname)} (first only) specifies the person identifier variable.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name for the generated indicator variable.
Default is _proc_match for match and _proc_ever for first.

{phang}
{opt gendatevar(name)} (first only) specifies the name for the generated date
variable. Default is _proc_first_dt.

{phang}
{opt replace} allows overwriting existing variables.

{phang}
{opt prefix} matches codes as prefixes rather than exact matches. For example,
code "LAE" would match "LAE10", "LAE20", etc.

{phang}
{opt noisily} displays progress and summary information.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{stata `"use "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/procedures.dta", clear"':. use _data/procedures.dta, clear}{p_end}

{pstd}Match coronary angiography or PCI procedures{p_end}
{phang2}{stata `"procmatch match, codes("FNG02 FNG05") procvars(kva_code) generate(cardiac_proc) prefix noisily"':. procmatch match, codes("FNG02 FNG05") procvars(kva_code) generate(cardiac_proc) prefix noisily}{p_end}

{pstd}Match diabetes diagnostic workup{p_end}
{phang2}{stata `"procmatch match, codes("DA024") procvars(kva_code) generate(diab_workup) prefix"':. procmatch match, codes("DA024") procvars(kva_code) generate(diab_workup) prefix}{p_end}

{pstd}Find first cardiac procedure (coronary angiography or PCI){p_end}
{phang2}{stata `"procmatch first, codes("FNG02 FNG05") procvars(kva_code) datevar(proc_date) idvar(id) generate(cardiac_proc) gendatevar(cardiac_proc_dt) noisily"':. procmatch first, codes("FNG02 FNG05") procvars(kva_code) ///}{p_end}
{phang3}{cmd:datevar(proc_date) idvar(id) ///}{p_end}
{phang3}{cmd:generate(cardiac_proc) gendatevar(cardiac_proc_dt) noisily}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:procmatch match} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_codes)}}number of procedure codes searched{p_end}
{synopt:{cmd:r(n_matches)}}number of matching observations{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of generated variable{p_end}
{synopt:{cmd:r(codes)}}procedure codes searched (uppercase){p_end}

{pstd}
{cmd:procmatch first} additionally stores:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_persons)}}number of persons with procedure{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(datevarname)}}name of generated date variable{p_end}


{marker author}{...}
{title:Author}

{pstd}Tim Copeland{break}
Karolinska Institutet{break}
Stockholm, Sweden{p_end}

{pstd}Part of the {cmd:setools} package for Swedish registry epidemiology.{p_end}


{title:Also see}

{psee}
{space 2}Help:  {manhelp inlist FN}
{p_end}

{smcl}
{* *! version 1.0.2  28feb2026}{...}
{viewerjumpto "Syntax" "tte_validate##syntax"}{...}
{viewerjumpto "Description" "tte_validate##description"}{...}
{viewerjumpto "Options" "tte_validate##options"}{...}
{viewerjumpto "Examples" "tte_validate##examples"}{...}
{viewerjumpto "Stored results" "tte_validate##results"}{...}
{viewerjumpto "Author" "tte_validate##author"}{...}

{title:Title}

{phang}
{bf:tte_validate} {hline 2} Data quality checks for target trial emulation


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:tte_validate}
[{cmd:,} {it:options}]

{synoptset 15 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt str:ict}}treat warnings as errors{p_end}
{synopt:{opt ver:bose}}show detailed diagnostics{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:tte_validate} runs comprehensive data quality checks on data that
has been prepared with {helpb tte_prepare}. It verifies person-period
format, checks for gaps in sequences, validates treatment/outcome
consistency, assesses missing data, and checks positivity.

{pstd}
Ten checks are performed covering data structure, variable consistency,
missing data, eligibility, sufficient sample size, positivity, period
numbering, and event rates.


{marker options}{...}
{title:Options}

{phang}
{opt strict} causes warnings to be treated as errors. The command will exit
with error code 198 if any check fails.

{phang}
{opt verbose} displays additional detail for each check, including counts of
affected individuals and specific violations.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. use tte_example, clear}{p_end}
{phang2}{cmd:. tte_prepare, id(patid) period(period) treatment(treatment) outcome(outcome) eligible(eligible) estimand(PP)}{p_end}
{phang2}{cmd:. tte_validate}{p_end}
{phang2}{cmd:. tte_validate, strict verbose}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:tte_validate} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_checks)}}number of checks run{p_end}
{synopt:{cmd:r(n_errors)}}number of errors{p_end}
{synopt:{cmd:r(n_warnings)}}number of warnings{p_end}
{synopt:{cmd:r(n_events)}}number of outcome events{p_end}
{synopt:{cmd:r(event_rate)}}event rate (percentage){p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(validation)}}passed or failed{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Email: timothy.copeland@ki.se

{pstd}
Tania F Reza{break}
Department of Global Public Health{break}
Karolinska Institutet

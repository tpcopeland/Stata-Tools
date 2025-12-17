{smcl}
{* *{* *! version 1.0.0  2025/12/02}{...}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "sustainedss" "help sustainedss"}{...}
{viewerjumpto "Syntax" "migrations##syntax"}{...}
{viewerjumpto "Description" "migrations##description"}{...}
{viewerjumpto "Options" "migrations##options"}{...}
{viewerjumpto "Examples" "migrations##examples"}{...}
{viewerjumpto "Stored results" "migrations##results"}{...}
{viewerjumpto "Author" "migrations##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:migrations} {hline 2}}Process Swedish migration registry data for cohort studies{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:migrations}
{cmd:,} {opt mig:file(filename)} [{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt mig:file(filename)}}path to migrations_wide.dta file{p_end}

{syntab:Optional}
{synopt:{opt id:var(varname)}}ID variable; default is {cmd:id}{p_end}
{synopt:{opt start:var(varname)}}study start date variable; default is {cmd:study_start}{p_end}
{synopt:{opt savee:xclude(filename)}}save excluded observations to file{p_end}
{synopt:{opt savec:ensor(filename)}}save emigration censoring dates to file{p_end}
{synopt:{opt replace}}replace existing files{p_end}
{synopt:{opt verb:ose}}display processing messages{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:migrations} processes Swedish migration registry data to identify:

{phang2}1. {bf:Exclusions}: Individuals who should be excluded from the cohort because they were not residing in Sweden at their study start date.{p_end}

{phang2}2. {bf:Censoring dates}: The first emigration date after study start, which can be used to right-censor individuals in survival analyses.{p_end}

{pstd}
The command expects a master dataset in memory containing individual IDs and study start dates.
It then merges with the Swedish migration registry (migrations_wide.dta format) and applies
the following logic:

{pstd}
{bf:Exclusion criteria:}

{phang2}{bf:Type 1}: Last emigration occurred before study start AND last immigration occurred before 
last emigration (i.e., person left Sweden and never returned before their study start).{p_end}

{phang2}{bf:Type 2}: Only migration record is an immigration after study start (i.e., person was 
not in Sweden at their study start date).{p_end}

{pstd}
{bf:Censoring logic:}

{phang2}For individuals not excluded, the command identifies the first emigration date occurring 
after study start as the {it:migration_out_dt} variable, which represents when the person 
left Sweden and should be censored from follow-up.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt migfile(filename)} specifies the path to the migrations_wide.dta file. This file must 
contain the same ID variable as specified in {opt idvar()} (default: {cmd:id}), plus 
immigration date variables ({it:in_1}, {it:in_2}, ...) and emigration date variables 
({it:out_1}, {it:out_2}, ...) in wide format.

{dlgtab:Optional}

{phang}
{opt idvar(varname)} specifies the name of the individual identifier variable. Default is {cmd:id}.

{phang}
{opt startvar(varname)} specifies the name of the study start date variable in the master dataset.
Default is {cmd:study_start}. This variable must be a Stata date.

{phang}
{opt saveexclude(filename)} saves a dataset containing excluded individuals and their exclusion 
reason to the specified file.

{phang}
{opt savecensor(filename)} saves a dataset containing individuals with emigration censoring dates 
to the specified file.

{phang}
{opt replace} allows existing files specified in {cmd:saveexclude()} and {cmd:savecensor()} to 
be overwritten.

{phang}
{opt verbose} displays additional processing messages.


{marker examples}{...}
{title:Examples}

{pstd}
{it:Note: These examples require access to Swedish registry data (migrations_wide.dta).}

{pstd}Basic usage with default variable names:{p_end}
{phang2}{cmd:. use cohort_data, clear}{p_end}
{phang2}{cmd:. migrations, migfile("$source/migrations_wide.dta")}{p_end}

{pstd}With custom variable names and saving intermediate files:{p_end}
{phang2}{cmd:. use my_cohort, clear}{p_end}
{phang2}{cmd:. migrations, migfile("K:/data/migrations_wide.dta") ///}{p_end}
{phang2}{cmd:>    idvar(lopnr) startvar(baseline_date) ///}{p_end}
{phang2}{cmd:>    saveexclude(excluded_migrations) savecensor(emigration_dates) replace}{p_end}

{pstd}Typical workflow for a cohort study:{p_end}
{phang2}{cmd:. * Define cohort with study start dates}{p_end}
{phang2}{cmd:. use basdata, clear}{p_end}
{phang2}{cmd:. gen study_start = onset_date}{p_end}
{phang2}{cmd:. replace study_start = mdy(1,1,2006) if study_start < mdy(1,1,2006)}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Apply migration exclusions and get censoring dates}{p_end}
{phang2}{cmd:. migrations, migfile("$source/migrations_wide.dta") verbose}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Use migration_out_dt in survival analysis}{p_end}
{phang2}{cmd:. gen end_date = min(death_date, migration_out_dt, mdy(12,31,2023))}{p_end}
{phang2}{cmd:. stset end_date, failure(outcome) origin(study_start)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:migrations} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(N_excluded_emigrated)}}number excluded due to emigration before study start{p_end}
{synopt:{cmd:r(N_excluded_inmigration)}}number excluded due to immigration after study start{p_end}
{synopt:{cmd:r(N_excluded_total)}}total number excluded{p_end}
{synopt:{cmd:r(N_censored)}}number with emigration censoring dates{p_end}
{synopt:{cmd:r(N_final)}}final sample size after exclusions{p_end}


{marker author}{...}
{title:Author}

{pstd}
Tim Copeland{p_end}

{pstd}
For use with Swedish registry data (migrations_wide.dta format).{p_end}


{marker alsosee}{...}
{title:Also see}

{pstd}
{help sustainedss:sustainedss} - Compute sustained EDSS progression dates{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

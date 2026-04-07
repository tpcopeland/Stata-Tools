{smcl}
{* *! version 1.0.0  08apr2026}{...}
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
{synopt:{opt min:residence(#)}}minimum days of continuous residence before study start; default is {bf:0} (disabled){p_end}
{synopt:{opt savee:xclude(filename)}}save excluded observations to file{p_end}
{synopt:{opt savec:ensor(filename)}}save emigration censoring dates to file{p_end}
{synopt:{opt replace}}replace existing files{p_end}
{synopt:{opt verb:ose}}display processing messages{p_end}
{synopt:{opt keep:immigrants}}include (do not exclude) persons who immigrate after study start; generates {it:migration_in_dt}{p_end}
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
not in Sweden at their study start date). Excluded by default; see {opt keepimmigrants} to
include these individuals instead.{p_end}

{phang2}{bf:Type 3}: Person emigrated before study start and returned after study start (i.e.,
person was abroad at their study start date but later re-entered Sweden).{p_end}

{phang2}{bf:Type 4} (optional): Person's most recent immigration before study start was fewer
than {opt minresidence()} days before their study start date. This ensures a minimum
period of continuous Swedish residence for complete registry coverage (e.g., NPR lookback
windows for comorbidity scoring). Only applied when {opt minresidence()} is specified.
Persons with no immigration record (born in Sweden) are not affected.{p_end}

{pstd}
{bf:Censoring logic:}

{phang2}For individuals not excluded, the command identifies the first {it:permanent} emigration date
occurring after study start as the {it:migration_out_dt} variable, which represents when the
person left Sweden and should be censored from follow-up. Temporary emigrations (where the
person subsequently returned to Sweden) are ignored for censoring purposes. The variable
{it:migration_out_dt} must not already exist in the master data; drop or rename it before
re-running the command.{p_end}


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
{opt minresidence(#)} specifies the minimum number of days a person must have been
continuously resident in Sweden before their study start date. Persons whose most recent
immigration before study start occurred fewer than {it:#} days before study start are
excluded (Type 4). This is useful for ensuring complete NPR coverage for comorbidity
lookback windows. Default is {bf:0} (disabled). Persons with no immigration record
(presumed born in Sweden) always pass this check.

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

{phang}
{opt keepimmigrants} specifies that individuals whose only migration record is an immigration
after study start (Type 2) should be included rather than excluded. When specified,
the command generates a variable {it:migration_in_dt} containing the post-study-start
immigration date for these individuals. Use this when late immigrants should contribute
person-time from their arrival date rather than being dropped. Individuals who were in
Sweden at their study start date have {it:migration_in_dt} set to missing.


{marker examples}{...}
{title:Examples}

{pstd}
{it:Note: Click each link in order. The first two links download example data}
{it:from GitHub to your current directory.}

{pstd}Setup: download example data:{p_end}
{phang2}{stata `"copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta" "cohort_example.dta", replace"':. copy "https://.../cohort.dta" "cohort_example.dta", replace}{p_end}
{phang2}{stata `"copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/migrations_wide.dta" "migrations_wide.dta", replace"':. copy "https://.../migrations_wide.dta" "migrations_wide.dta", replace}{p_end}

{pstd}Basic usage:{p_end}
{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry)"':. migrations, migfile("migrations_wide.dta") startvar(study_entry)}{p_end}

{pstd}With saving intermediate files:{p_end}
{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry) saveexclude(excluded_migrations) savecensor(emigration_dates) replace"':. migrations, migfile("migrations_wide.dta") ///}{p_end}
{phang3}{cmd:startvar(study_entry) ///}{p_end}
{phang3}{cmd:saveexclude(excluded_migrations) savecensor(emigration_dates) replace}{p_end}

{pstd}Typical workflow for a cohort study:{p_end}
{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Apply migration exclusions and get censoring dates}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose"':. migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Use migration_out_dt in survival analysis}{p_end}
{phang2}{stata "gen double end_date = min(death_date, migration_out_dt, mdy(12,31,2023))":. gen double end_date = min(death_date, migration_out_dt, mdy(12,31,2023))}{p_end}
{phang2}{stata "stset end_date, failure(outcome) origin(study_entry)":. stset end_date, failure(outcome) origin(study_entry)}{p_end}

{pstd}Including late immigrants:{p_end}
{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry) keepimmigrants"':. migrations, migfile("migrations_wide.dta") startvar(study_entry) keepimmigrants}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Use immigration date as entry for late arrivals}{p_end}
{phang2}{stata "gen double effective_start = cond(!missing(migration_in_dt), migration_in_dt, study_entry)":. gen double effective_start = cond(!missing(migration_in_dt), migration_in_dt, study_entry)}{p_end}
{phang2}{stata "format effective_start %tdCCYY/NN/DD":. format effective_start %tdCCYY/NN/DD}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:migrations} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(N_excluded_emigrated)}}number excluded due to emigration before study start{p_end}
{synopt:{cmd:r(N_excluded_inmigration)}}number excluded due to immigration after study start{p_end}
{synopt:{cmd:r(N_excluded_abroad)}}number excluded due to being abroad at baseline{p_end}
{synopt:{cmd:r(N_excluded_minresidence)}}number excluded due to insufficient residence{p_end}
{synopt:{cmd:r(N_excluded_total)}}total number excluded{p_end}
{synopt:{cmd:r(N_censored)}}number with emigration censoring dates{p_end}
{synopt:{cmd:r(N_included_inmigration)}}number of post-start immigrants included (with {cmd:keepimmigrants}){p_end}
{synopt:{cmd:r(N_final)}}final sample size after exclusions{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden

{pstd}
For use with Swedish registry data (migrations_wide.dta format).{p_end}


{marker alsosee}{...}
{title:Also see}

{pstd}
{help setools:setools} - Swedish registry toolkit overview{p_end}
{pstd}
{help cci_se:cci_se} - Swedish Charlson Comorbidity Index{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

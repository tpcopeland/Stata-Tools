{smcl}
{vieweralsosee "[ST] stset" "help stset"}{...}
{vieweralsosee "cci_se" "help cci_se"}{...}
{vieweralsosee "setools" "help setools"}{...}
{viewerjumpto "Syntax" "migrations##syntax"}{...}
{viewerjumpto "Description" "migrations##description"}{...}
{viewerjumpto "Options" "migrations##options"}{...}
{viewerjumpto "Remarks" "migrations##remarks"}{...}
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

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt mig:file(filename)}}path to migration data file (wide or long format){p_end}

{syntab:Optional}
{synopt:{opt id:var(varname)}}ID variable; default is {cmd:id}{p_end}
{synopt:{opt start:var(varname)}}study start date variable; default is {cmd:study_start}; must be nonmissing{p_end}
{synopt:{opt min:residence(#)}}minimum days of continuous residence before study start; default is {cmd:0} (disabled){p_end}
{synopt:{opt savee:xclude(filename)}}save excluded observations to a dataset{p_end}
{synopt:{opt savec:ensor(filename)}}save nonmissing emigration censoring dates to a dataset{p_end}
{synopt:{opt replace}}allow overwriting files specified in {opt saveexclude()} and {opt savecensor()}{p_end}
{synopt:{opt verb:ose}}display processing messages{p_end}
{synopt:{opt keep:immigrants}}include (do not exclude) post-start immigrants; creates {it:migration_in_dt}{p_end}
{synopt:{opt flag}}flag excluded individuals in {it:mig_excluded}/{it:mig_exclude_reason} instead of dropping them{p_end}
{synopt:{opt intype(codes)}}long-format {cmd:event_type} values denoting immigration{p_end}
{synopt:{opt outtype(codes)}}long-format {cmd:event_type} values denoting emigration{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:migrations} processes Swedish migration registry data to apply two essential
steps for register-based cohort studies:

{phang2}1. {bf:Exclude non-residents.} People who were not living in Sweden at their
study start date are dropped from the cohort, because Swedish health registries
only capture care delivered in Sweden. Including non-residents introduces
informative censoring and misclassification.{p_end}

{phang2}2. {bf:Generate emigration censoring dates.} For people who were in Sweden at study
start but later emigrated permanently, the command creates a {cmd:migration_out_dt}
variable containing the first permanent emigration date. Use this as a
right-censoring date in {helpb stset} or equivalent time-to-event setup.{p_end}

{pstd}
{bf:What you need in memory:} A cohort dataset with one row per person, containing
a patient ID and a study start date. All study start dates must be nonmissing.

{pstd}
{bf:What you supply on disk:} A migration registry file via {opt migfile()}, in
either of two formats:

{phang2}{bf:Wide format:} One row per person with variables {it:in_1}, {it:out_1},
{it:in_2}, {it:out_2}, ... representing immigration and emigration dates. All date
variables must be Stata daily dates with {cmd:%td} formats.{p_end}

{phang2}{bf:Long format:} One row per migration event with variables {cmd:event_date} (Stata
daily date with {cmd:%td} format) and {cmd:event_type}. {cmd:event_type} may be a string or
labeled numeric; the command recognizes the Swedish register vocabulary
({cmd:Invandring}/{cmd:Utvandring}), English variants ({cmd:Immigration}/{cmd:Emigration}, {cmd:in}/{cmd:out}) and
the {cmd:Inv}/{cmd:Utv} abbreviations (all case-insensitive). Map any other coding with
{opt intype()} and {opt outtype()}. The command normalizes this into the wide layout
internally.{p_end}

{pstd}
{bf:Exclusion criteria applied (in order):}

{phang2}{bf:Type 1} {hline 2} Emigrated before study start and never returned.{p_end}

{phang2}{bf:Type 4} {hline 2} (Only when {opt minresidence()} > 0.) Most recent immigration before study
start was too recent — fewer than {opt minresidence()} days of continuous
residence. Persons with no immigration record (born in Sweden) always pass.{p_end}

{phang2}{bf:Type 3} {hline 2} Abroad at baseline: emigrated before study start and
returned after.{p_end}

{phang2}{bf:Type 2} {hline 2} No evidence of being in Sweden at study start: no
migration event before study start, and the first migration event after study
start is an immigration. A later emigration does not change this — the person
was still abroad at baseline. (Persons whose first post-start event is an
emigration are treated as resident at baseline, e.g. born in Sweden. With
{opt keepimmigrants}, Type 2 persons are retained instead of excluded.){p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt migfile(filename)} specifies the path to the migration data file. The file must
contain the same ID variable as {opt idvar()} and be in one of these
formats. Columns other than the ID and migration-date variables are ignored,
so a migration extract may safely carry extra fields (they never override
master-data values):

{phang2}{bf:Wide:} variables {it:in_1}, {it:out_1}, {it:in_2}, {it:out_2}, ... with
one row per person. All date variables must use Stata daily {cmd:%td} formats with
whole-number daily values.{p_end}

{phang2}{bf:Long:} variables {cmd:event_date} and {cmd:event_type}, with one row
per migration event. {cmd:event_date} must be a Stata daily {cmd:%td} date with
whole-number daily values. {cmd:event_type} is classified as immigration when it
begins with {cmd:inv} or {cmd:imm} or equals {cmd:in}/{cmd:i}, and as emigration
when it begins with {cmd:utv} or {cmd:emi} or equals {cmd:ut}/{cmd:out}/{cmd:u}/{cmd:e}
(all case-insensitive). This recognizes the Swedish register words
{cmd:Invandring}/{cmd:Utvandring} and the historical {cmd:Inv}/{cmd:Utv}
abbreviations. Use {opt intype()}/{opt outtype()} for any other coding, including
unlabeled numeric codes.{p_end}

{dlgtab:Optional}

{phang}
{opt idvar(varname)} specifies the patient identifier variable. Default is {cmd:id}. Must
uniquely identify observations in the master data.

{phang}
{opt startvar(varname)} specifies the study start date variable. Default is
{cmd:study_start}. Must be a Stata daily date with {cmd:%td} format, with
whole-number values and no missing values.

{phang}
{opt minresidence(#)} specifies the minimum number of days a person must have been
continuously resident in Sweden before their study start date. Default is {cmd:0}
(disabled). When set to a positive value (e.g., {cmd:minresidence(365)}), persons
whose most recent immigration occurred fewer than {it:#} days before study start
are excluded (Type 4). This is useful for ensuring complete NPR lookback for
comorbidity scoring via {helpb cci_se}. Persons born in Sweden (no immigration
record) always pass this check.

{phang}
{opt saveexclude(filename)} saves a dataset of excluded individuals with columns
{opt idvar()} and {cmd:exclude_reason} to the specified file. If no exclusions
occur, the file is still created (empty). Requires {opt replace} if the file
already exists.

{phang}
{opt savecensor(filename)} saves a dataset containing only {opt idvar()} and
{cmd:migration_out_dt} for individuals with nonmissing emigration censoring
dates. If no such individuals exist, the file is still created
(empty). Requires {opt replace} if the file already exists.

{phang}
{opt replace} allows overwriting existing files specified in {opt saveexclude()}
and {opt savecensor()}.

{phang}
{opt verbose} displays additional processing messages, including migration file
format detection and exclusion/censoring progress.

{phang}
{opt keepimmigrants} specifies that Type 2 individuals (whose first migration event
is a post-start immigration) should be included rather than excluded. The
command generates a variable {cmd:migration_in_dt} containing the post-start
immigration date for these individuals. Use this when late immigrants should
contribute person-time from their arrival date rather than being dropped
entirely. Individuals who were in Sweden at study start have {cmd:migration_in_dt}
set to missing. If an included immigrant later emigrates permanently, their
{cmd:migration_out_dt} is set as usual, so their person-time can be bounded on both
sides.

{phang}
{opt flag} retains every cohort member instead of dropping the excluded ones. Two
variables are added: {cmd:mig_excluded} (a 0/1 indicator, 1 for excluded persons)
and {cmd:mig_exclude_reason} (the exclusion reason string, empty for retained
persons). This matches the common {opt saveexclude()} + {cmd:merge ... keep(1)} workaround
and lets you build CONSORT diagrams or run sensitivity analyses on the
excluded group. {cmd:migration_out_dt} (and {cmd:migration_in_dt} under {opt keepimmigrants})
are still added.

{phang}
{opt intype(codes)} and {opt outtype(codes)} map custom long-format {cmd:event_type} values onto
immigration and emigration respectively. Each takes a space-separated list of
values (case-insensitive, matched exactly), and the two lists must be
disjoint. These overrides take precedence over the built-in recognition and
are the way to support unlabeled numeric codes (e.g. {cmd:intype(1) outtype(2)}) or
any registry-specific vocabulary. They are ignored for wide-format migration
files.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Why migration processing matters}

{pstd}
Swedish national registries (NPR, Cancer Register, Cause of Death Register)
only capture events occurring in Sweden. A person living abroad appears
healthy in the registry — not because they are, but because their care is
recorded elsewhere. Failing to account for migration introduces immortal time
bias and outcome misclassification.

{pstd}
{bf:Output variables}

{pstd}
After {cmd:migrations} completes, the master dataset has been modified:

{phang2}{hline 2} Excluded individuals have been dropped.{p_end}
{phang2}{hline 2} A new variable {cmd:migration_out_dt} (Stata daily date, {cmd:%td})
is added for every remaining person. It contains the first permanent emigration
date after study start, or missing if the person did not emigrate.{p_end}
{phang2}{hline 2} If {opt keepimmigrants} was specified, a variable
{cmd:migration_in_dt} is also added.{p_end}
{phang2}{hline 2} If {opt flag} was specified, excluded individuals are retained
(not dropped) and marked in {cmd:mig_excluded} (0/1) and
{cmd:mig_exclude_reason}.{p_end}

{pstd}
{bf:Typical workflow}

{pstd}
Run {cmd:migrations} early in your cohort-construction pipeline, after defining
the cohort and study start dates but before survival setup:

{phang2}1. Load cohort data (one row per person){p_end}
{phang2}2. Run {cmd:migrations} to drop non-residents and create censoring dates{p_end}
{phang2}3. Compute comorbidities with {helpb cci_se} (optionally using
{opt minresidence()} to ensure NPR lookback coverage){p_end}
{phang2}4. Define exit dates using {cmd:migration_out_dt}, death, and
administrative end{p_end}
{phang2}5. Run {helpb stset} for survival analysis{p_end}

{pstd}
{bf:Re-running the command}

{pstd}
{cmd:migration_out_dt} (and {cmd:migration_in_dt} when applicable) must not
already exist in the master data. Drop or rename them before re-running.


{marker examples}{...}
{title:Examples}

{pstd}
{it:Note: click each link in order. The first two links download example}
{it:data from GitHub to your current directory.}

{pstd}
{bf:Setup: download example data}

{phang2}{stata `"copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/cohort.dta" "cohort_example.dta", replace"':. copy "https://.../cohort.dta" "cohort_example.dta", replace}{p_end}
{phang2}{stata `"copy "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/_data/migrations_wide.dta" "migrations_wide.dta", replace"':. copy "https://.../migrations_wide.dta" "migrations_wide.dta", replace}{p_end}

{pstd}
{bf:Example 1: Basic migration processing}

{pstd}
Apply exclusions and generate emigration censoring dates. The summary table
shows how many people were excluded by each criterion.{p_end}

{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry)"':. migrations, migfile("migrations_wide.dta") startvar(study_entry)}{p_end}

{pstd}
{bf:Example 2: Save exclusion and censoring files}

{pstd}
Useful for auditing which individuals were excluded and why.{p_end}

{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry) saveexclude(excluded_migrations) savecensor(emigration_dates) replace"':. migrations, migfile("migrations_wide.dta") ///}{p_end}
{phang3}{cmd:startvar(study_entry) ///}{p_end}
{phang3}{cmd:saveexclude(excluded_migrations) savecensor(emigration_dates) replace}{p_end}

{pstd}
{bf:Example 3: Full cohort-construction workflow}

{pstd}
A typical pipeline: apply migration exclusions, then construct exit dates for
survival analysis.{p_end}

{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose"':. migrations, migfile("migrations_wide.dta") startvar(study_entry) verbose}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Construct exit date: earliest of death, emigration, or admin end}{p_end}
{phang2}{stata "gen double end_date = min(death_date, migration_out_dt, mdy(12,31,2023))":. gen double end_date = min(death_date, migration_out_dt, mdy(12,31,2023))}{p_end}
{phang2}{stata "format end_date %td":. format end_date %td}{p_end}
{phang2}{stata "stset end_date, failure(outcome) origin(study_entry)":. stset end_date, failure(outcome) origin(study_entry)}{p_end}

{pstd}
{bf:Example 4: Include late immigrants}

{pstd}
With {opt keepimmigrants}, people who immigrated after study start are retained. Use
{cmd:migration_in_dt} as their effective entry date.{p_end}

{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry) keepimmigrants"':. migrations, migfile("migrations_wide.dta") startvar(study_entry) keepimmigrants}{p_end}
{phang2}{stata "gen double effective_start = cond(!missing(migration_in_dt), migration_in_dt, study_entry)":. gen double effective_start = cond(!missing(migration_in_dt), migration_in_dt, study_entry)}{p_end}
{phang2}{stata "format effective_start %tdCCYY/NN/DD":. format effective_start %tdCCYY/NN/DD}{p_end}

{pstd}
{bf:Example 5: Minimum residence requirement}

{pstd}
Ensure at least 365 days of Swedish residence before study start, so the NPR
lookback for comorbidity scoring is complete.{p_end}

{phang2}{stata `"use "cohort_example.dta", clear"':. use cohort_example.dta, clear}{p_end}
{phang2}{stata `"migrations, migfile("migrations_wide.dta") startvar(study_entry) minresidence(365)"':. migrations, migfile("migrations_wide.dta") startvar(study_entry) minresidence(365)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:migrations} stores the following in {cmd:r()}:

{synoptset 28 tabbed}{...}
{p2col 5 28 32 2: Scalars}{p_end}
{synopt:{cmd:r(N_excluded_emigrated)}}Type 1: emigrated before study start, never returned{p_end}
{synopt:{cmd:r(N_excluded_inmigration)}}Type 2: immigration after study start only{p_end}
{synopt:{cmd:r(N_excluded_abroad)}}Type 3: abroad at baseline, returned after study start{p_end}
{synopt:{cmd:r(N_excluded_minresidence)}}Type 4: insufficient continuous residence{p_end}
{synopt:{cmd:r(N_excluded_total)}}total number excluded across all types{p_end}
{synopt:{cmd:r(N_censored)}}number of individuals with emigration censoring dates{p_end}
{synopt:{cmd:r(N_included_inmigration)}}post-start immigrants included (with {opt keepimmigrants}){p_end}
{synopt:{cmd:r(N_final)}}final sample size after exclusions{p_end}

{p2col 5 28 32 2: Matrices}{p_end}
{synopt:{cmd:r(flow)}}CONSORT-style exclusion-flow column vector (named rows){p_end}

{pstd}
{cmd:r(flow)} carries one row per flow step {hline 1} starting cohort, each
exclusion type, total excluded, censored, and final cohort {hline 1} ready to
tabulate or feed into {cmd:consort_step}.


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet

{pstd}
Part of the {help setools:setools} package for Swedish registry research.{p_end}


{title:Also see}

{pstd}
{help setools:setools} {hline 2} Swedish registry toolkit overview{p_end}
{pstd}
{help cci_se:cci_se} {hline 2} Swedish Charlson Comorbidity Index{p_end}
{psee}
Manual: {manlink ST stset}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

{hline}

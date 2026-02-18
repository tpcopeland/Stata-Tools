{smcl}
{* *! version 1.0.0  18feb2026}{...}
{vieweralsosee "[D] generate" "help generate"}{...}
{vieweralsosee "icdexpand" "help icdexpand"}{...}
{vieweralsosee "migrations" "help migrations"}{...}
{viewerjumpto "Syntax" "cci_se##syntax"}{...}
{viewerjumpto "Description" "cci_se##description"}{...}
{viewerjumpto "Options" "cci_se##options"}{...}
{viewerjumpto "Comorbidities" "cci_se##comorbidities"}{...}
{viewerjumpto "Hierarchy rules" "cci_se##hierarchy"}{...}
{viewerjumpto "ICD code formats" "cci_se##formats"}{...}
{viewerjumpto "Examples" "cci_se##examples"}{...}
{viewerjumpto "Stored results" "cci_se##results"}{...}
{viewerjumpto "References" "cci_se##references"}{...}
{viewerjumpto "Author" "cci_se##author"}{...}
{title:Title}

{p2colset 5 15 17 2}{...}
{p2col:{cmd:cci_se} {hline 2}}Swedish Charlson Comorbidity Index using ICD-7 through ICD-10{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:cci_se}
{ifin}{cmd:,}
{opt id(varname)}
{opt icd(varname)}
{opt date(varname)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}patient identifier variable{p_end}
{synopt:{opt icd(varname)}}string variable containing ICD diagnosis codes{p_end}
{synopt:{opt date(varname)}}date variable (Stata date, YYYYMMDD, or string){p_end}

{syntab:Optional}
{synopt:{opt gen:erate(name)}}name for Charlson score variable; default is {cmd:charlson}{p_end}
{synopt:{opt comp:onents}}generate binary indicator variables for each comorbidity{p_end}
{synopt:{opt prefix(string)}}prefix for component variable names; default is {cmd:cci_}{p_end}
{synopt:{opt datef:ormat(string)}}date format: {cmd:stata}, {cmd:yyyymmdd}, or {cmd:ymd}{p_end}
{synopt:{opt noi:sily}}display summary of results{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:cci_se} computes the Swedish adaptation of the Charlson Comorbidity Index (CCI)
from diagnosis-level registry data. It implements the algorithm described in
Ludvigsson et al. (2021), which maps comorbidity definitions across all four ICD
revisions used in Swedish national health registries: ICD-7 (before 1969),
ICD-8 (1969{c -}1986), ICD-9 (1987{c -}1997), and ICD-10 (1997+).

{pstd}
The command takes long-format data (one or more rows per patient, each containing an
ICD code and a date) and collapses it to one row per patient with the weighted CCI
score. The date determines which ICD version is used for code matching.

{pstd}
{bf:Important:} This command replaces the data in memory with patient-level results.
Use {cmd:preserve}/{cmd:restore} if you need to keep the original data, or save the
CCI results to a temporary file for merging.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the patient identifier variable. Each unique value of
this variable is treated as one patient. The output dataset will have one row per
unique value.

{phang}
{opt icd(varname)} specifies the string variable containing ICD diagnosis codes.
Codes may be stored with or without dots (e.g., both {cmd:"I252"} and {cmd:"I25.2"}
are recognized). The variable may also contain multiple space-separated codes per
cell. See {help cci_se##formats:ICD code formats} below.

{phang}
{opt date(varname)} specifies the date variable used to determine which ICD version
applies. The variable can be numeric (Stata date or YYYYMMDD integer) or string.
Use the {opt dateformat()} option to specify the format if auto-detection is
insufficient. See {it:Date formats} below.

{dlgtab:Optional}

{phang}
{opt generate(name)} specifies the name for the generated Charlson score variable.
The default is {cmd:charlson}.

{phang}
{opt components} requests that binary (0/1) indicator variables be generated for each
of the 18 comorbidity components in addition to the composite score. Variables are
named {cmd:{it:prefix}mi}, {cmd:{it:prefix}chf}, etc. See
{help cci_se##comorbidities:Comorbidities} for the full list.

{phang}
{opt prefix(string)} specifies the prefix for component variable names when
{opt components} is specified. The default is {cmd:cci_}.

{phang}
{opt dateformat(string)} specifies the format of the date variable:

{phang2}{cmd:stata} {hline 2} Stata date (numeric, days since 01jan1960). This is the
default for numeric date variables.{p_end}

{phang2}{cmd:yyyymmdd} {hline 2} YYYYMMDD integer or string (e.g., 20200115 or "20200115").
This is the default for string date variables. Also handles dates with dashes or
slashes (e.g., "2020-01-15", "2020/01/15") by stripping separators first.{p_end}

{phang2}{cmd:ymd} {hline 2} YYYY-MM-DD string format. Extracts the four-digit year
directly from the string.{p_end}

{phang}
{opt noisily} displays a summary table including patient counts, mean CCI, and
(when {opt components} is specified) component prevalence.


{marker comorbidities}{...}
{title:Comorbidities}

{pstd}
The following 18 comorbidity components are assessed, with Charlson weights in parentheses:

{p2colset 5 30 32 2}{...}
{p2col:Variable}Description (weight){p_end}
{p2line}
{p2col:{cmd:cci_mi}}Myocardial infarction (1){p_end}
{p2col:{cmd:cci_chf}}Congestive heart failure (1){p_end}
{p2col:{cmd:cci_pvd}}Peripheral vascular disease (1){p_end}
{p2col:{cmd:cci_cevd}}Cerebrovascular disease (1){p_end}
{p2col:{cmd:cci_copd}}COPD (1){p_end}
{p2col:{cmd:cci_pulm}}Other chronic pulmonary disease (1){p_end}
{p2col:{cmd:cci_rheum}}Rheumatic disease (1){p_end}
{p2col:{cmd:cci_dem}}Dementia (1){p_end}
{p2col:{cmd:cci_plegia}}Hemiplegia/paraplegia (2){p_end}
{p2col:{cmd:cci_diab}}Diabetes without complications (1){p_end}
{p2col:{cmd:cci_diabcomp}}Diabetes with complications (2){p_end}
{p2col:{cmd:cci_renal}}Renal disease (2){p_end}
{p2col:{cmd:cci_livmild}}Mild liver disease (1){p_end}
{p2col:{cmd:cci_livsev}}Moderate/severe liver disease (3){p_end}
{p2col:{cmd:cci_pud}}Peptic ulcer disease (1){p_end}
{p2col:{cmd:cci_cancer}}Cancer, non-metastatic (2){p_end}
{p2col:{cmd:cci_mets}}Metastatic cancer (6){p_end}
{p2col:{cmd:cci_aids}}AIDS/HIV (6){p_end}
{p2line}
{p2colreset}{...}

{pstd}
The maximum possible weighted CCI is 30 (all 18 conditions present with hierarchy
rules applied). Variable names use the specified {opt prefix()} (default {cmd:cci_}).


{marker hierarchy}{...}
{title:Hierarchy rules}

{pstd}
Three hierarchy rules are applied after individual comorbidities are identified:

{phang2}1. {bf:Liver disease:} If a patient has both mild liver disease {it:and}
ascites (R18/789F/785,3), the condition is upgraded to moderate/severe liver
disease. Mild liver disease is then cleared to avoid double-counting.{p_end}

{phang2}2. {bf:Diabetes:} If a patient has diabetes with complications,
uncomplicated diabetes is cleared (the higher-weighted condition takes
precedence).{p_end}

{phang2}3. {bf:Cancer:} If a patient has metastatic cancer, non-metastatic cancer
is cleared (the higher-weighted condition takes precedence).{p_end}


{marker formats}{...}
{title:ICD code formats}

{pstd}
{cmd:cci_se} automatically handles the following ICD code formats:

{phang2}{bf:With dots:} {cmd:"I25.2"}, {cmd:"E11.5"}, {cmd:"G35.0"}{p_end}
{phang2}{bf:Without dots:} {cmd:"I252"}, {cmd:"E115"}, {cmd:"G350"}{p_end}
{phang2}{bf:ICD-9 Swedish:} {cmd:"250A"}, {cmd:"410"}, {cmd:"714"}{p_end}
{phang2}{bf:ICD-7/8 with commas:} {cmd:"420,1"}, {cmd:"250,00"}{p_end}

{pstd}
Dots are stripped internally before matching, so codes in your data may use either
format. Commas in ICD-7/8 codes are preserved as they are part of the code
structure.

{pstd}
The ICD variable may contain a single code per cell (most common in long-format
registry data) or multiple space-separated codes per cell. Both formats are handled
correctly.

{pstd}
All matching is case-insensitive. Leading and trailing whitespace is trimmed
automatically.

{pstd}
{bf:Date formats:}

{pstd}
The date variable can be numeric or string. The command uses {opt dateformat()} to
determine how to parse it. If not specified:

{phang2}- Numeric variables default to Stata date format{p_end}
{phang2}- String variables default to YYYYMMDD format (dashes and slashes are stripped
automatically){p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic usage with Stata dates}

{phang2}{cmd:. use npr_diagnoses, clear}{p_end}
{phang2}{cmd:. cci_se, id(lopnr) icd(diagnos) date(utdatum) noisily}{p_end}
{phang2}{cmd:. summarize charlson}{p_end}

{pstd}
{bf:Example 2: With YYYYMMDD dates and component indicators}

{phang2}{cmd:. use patient_diagnoses, clear}{p_end}
{phang2}{cmd:. cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components noisily}{p_end}
{phang2}{cmd:. tab cci_mi}{p_end}
{phang2}{cmd:. tab cci_mets}{p_end}

{pstd}
{bf:Example 3: With string dates (YYYY-MM-DD)}

{phang2}{cmd:. cci_se, id(lopnr) icd(diagnos) date(date_str) dateformat(ymd) components}{p_end}

{pstd}
{bf:Example 4: Custom variable names}

{phang2}{cmd:. cci_se, id(patient_id) icd(icd_code) date(visit_date) generate(cci_score) prefix(ch_)}{p_end}

{pstd}
{bf:Example 5: Merge CCI back into analysis cohort}

{phang2}{cmd:. * Load diagnosis data and compute CCI}{p_end}
{phang2}{cmd:. use npr_long, clear}{p_end}
{phang2}{cmd:. cci_se, id(lopnr) icd(diagnos) date(utdatum)}{p_end}
{phang2}{cmd:. tempfile cci}{p_end}
{phang2}{cmd:. save `cci'}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Merge into analysis cohort}{p_end}
{phang2}{cmd:. use cohort, clear}{p_end}
{phang2}{cmd:. merge m:1 lopnr using `cci', nogenerate keep(master match)}{p_end}
{phang2}{cmd:. replace charlson = 0 if missing(charlson)}{p_end}

{pstd}
{bf:Example 6: Restrict to diagnoses within a lookback window}

{phang2}{cmd:. use npr_long, clear}{p_end}
{phang2}{cmd:. merge m:1 lopnr using index_dates, nogenerate keep(match)}{p_end}
{phang2}{cmd:. cci_se if utdatum >= index_date - 365 & utdatum < index_date, ///}{p_end}
{phang2}{cmd:      id(lopnr) icd(diagnos) date(utdatum) noisily}{p_end}

{pstd}
{bf:Example 7: CCI categories for regression}

{phang2}{cmd:. cci_se, id(lopnr) icd(diagnos) date(utdatum)}{p_end}
{phang2}{cmd:. gen byte cci_cat = cond(charlson == 0, 0, cond(charlson <= 2, 1, cond(charlson <= 4, 2, 3)))}{p_end}
{phang2}{cmd:. label define cci_cat 0 "0" 1 "1-2" 2 "3-4" 3 "5+"}{p_end}
{phang2}{cmd:. label values cci_cat cci_cat}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:cci_se} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_input)}}number of input observations used{p_end}
{synopt:{cmd:r(N_patients)}}number of unique patients in output{p_end}
{synopt:{cmd:r(N_any)}}number of patients with CCI > 0{p_end}
{synopt:{cmd:r(mean_cci)}}mean Charlson score{p_end}
{synopt:{cmd:r(max_cci)}}maximum Charlson score{p_end}


{marker references}{...}
{title:References}

{phang}
Ludvigsson JF, Appelros P, Askling J, Byberg L, Carrero JJ,
Ekstr{c o:}m AM, Ekstr{c o:}m M, Smedby KE, Hagstr{c o:}m H,
James S, J{c a:}rvholm B, Mich{c a:}elsson K, Pedersen NL,
Sundelin H, Sundquist K, Sundstr{c o:}m J.
Adaptation of the Charlson comorbidity index for register-based
research in Sweden.
{it:Clinical Epidemiology}. 2021;13:21{c -}41.
doi:10.2147/CLEP.S282475
{p_end}

{phang}
Charlson ME, Pompei P, Ales KL, MacKenzie CR.
A new method of classifying prognostic comorbidity in longitudinal
studies: development and validation.
{it:Journal of Chronic Diseases}. 1987;40(5):373{c -}383.
{p_end}


{marker author}{...}
{title:Author}

{pstd}
Tim Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden

{pstd}
ICD code mappings from scripts by Bj{c o:}rn Roelstraete and Jonas
S{c o:}derling, as published in Ludvigsson et al. (2021).

{pstd}
Part of the {help setools:setools} package for Swedish registry research.{p_end}


{marker alsosee}{...}
{title:Also see}

{pstd}
{help icdexpand:icdexpand} - ICD-10 code expansion and matching utilities{p_end}
{pstd}
{help migrations:migrations} - Process Swedish migration registry data{p_end}
{pstd}
{help dateparse:dateparse} - Date utilities for cohort studies{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Swedish-Cohorts":Swedish-Cohorts on GitHub}{p_end}

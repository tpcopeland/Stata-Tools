{smcl}
{* *! version 1.0.1  30aug2026}{...}
{vieweralsosee "codescan" "help codescan"}{...}
{viewerjumpto "Syntax" "comorbidity##syntax"}{...}
{viewerjumpto "Description" "comorbidity##description"}{...}
{viewerjumpto "Options" "comorbidity##options"}{...}
{viewerjumpto "Schemes" "comorbidity##schemes"}{...}
{viewerjumpto "Stored results" "comorbidity##results"}{...}
{viewerjumpto "Examples" "comorbidity##examples"}{...}
{viewerjumpto "References" "comorbidity##references"}{...}
{viewerjumpto "Author" "comorbidity##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:comorbidity} {hline 2}}Charlson and Elixhauser comorbidity indices from wide-format ICD code fields{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:comorbidity} {varlist} {ifin}{cmd:,} {opt id(varname)}
{cmdab:charl:son(}{it:scheme}{cmd:)}
[{it:options}]

{p 8 17 2}
{cmd:comorbidity} {varlist} {ifin}{cmd:,} {opt id(varname)}
{cmdab:elix:hauser(}{it:scheme}{cmd:)}
[{it:options}]

{p 8 17 2}
{cmd:comorbidity} {varlist} {ifin}{cmd:,} {opt id(varname)}
{cmdab:cust:om(}{it:filename}{cmd:)}
[{it:options}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Index}
{synopt:{opt id(varname)}}patient identifier{p_end}
{synopt:{opt charl:son(scheme)}}Charlson score; {cmd:original} or {cmd:quan2011}{p_end}
{synopt:{opt elix:hauser(scheme)}}Elixhauser score; use {cmd:vanwalraven}{p_end}
{synopt:{opt cust:om(filename)}}custom code file ({cmd:.csv} or {cmd:.dta}){p_end}

{syntab:Shape and windows}
{synopt:{opt coll:apse}}collapse to one row per {cmd:id()}; default{p_end}
{synopt:{opt mer:ge}}merge scores back to encounter rows{p_end}
{synopt:{opt date(varname)}}encounter date passed to {cmd:codescan}{p_end}
{synopt:{opt refd:ate(varname)}}reference date passed to {cmd:codescan}{p_end}
{synopt:{opt lookb:ack(#)}}lower window in days from {cmd:refdate()}{p_end}
{synopt:{opt lookf:orward(#)}}upper window in days from {cmd:refdate()}{p_end}
{synopt:{opt incl:usive}}include the reference date in the window{p_end}

{syntab:Output}
{synopt:{opt gen:erate(prefix)}}prefix indicators; create {it:prefix}{cmd:score}{p_end}
{synopt:{opt rep:lace}}overwrite nonstructural outputs{p_end}
{synopt:{opt nohier:archy}}skip package supersession rules{p_end}
{synopt:{opt band}}return patient-level score bands{p_end}
{synopt:{opt noi:sily}}pass verbose progress to {cmd:codescan}{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:comorbidity} builds ICD-10 condition dictionaries, delegates code matching
to {cmd:codescan}, applies package-defined hierarchy rules, and computes a weighted
patient-level comorbidity score.

{pstd}
The {cmd:codescan} dependency must be installed separately. If it is missing,
{cmd:comorbidity} exits with {cmd:r(199)} and prints the exact Stata-Tools
installation command.

{pstd}
The command currently implements the Charlson original and Quan 2011 weight
schemes and the classic Elixhauser van Walraven scheme. AHRQ mortality and
readmission schemes are reserved but intentionally return {cmd:r(198)} until
the AHRQ value sets and weights are transcribed from source documentation.

{marker options}{...}
{title:Options}

{phang}
{opt id(varname)} identifies patients or analytic units. This option is required.

{phang}
Exactly one of {opt charl:son(scheme)}, {opt elix:hauser(scheme)}, and
{opt cust:om(filename)} is required.

{phang}
{opt charl:son(scheme)} selects the Charlson index; the implemented schemes are
{cmd:charlson(original)} and {cmd:charlson(quan2011)}.

{phang}
{opt elix:hauser(scheme)} selects the Elixhauser index; the implemented scheme
is {cmd:elixhauser(vanwalraven)}, while
{cmd:elixhauser(ahrq_mortality)} and
{cmd:elixhauser(ahrq_readmission)} are reserved and return an error in this
release.

{phang}
{opt cust:om(filename)} uses a user-supplied {cmd:.csv} or {cmd:.dta}
code file. The file must contain {cmd:name}, {cmd:pattern}, and {cmd:weight}
columns. {cmd:name} is the condition variable name, {cmd:pattern} is the
ICD-10 pattern passed to {cmd:codescan}, and {cmd:weight} is the numeric
score weight. The schema, weights, and generated names are validated before
the caller's data are scanned. The sum of the absolute weights must fit within
Stata's numeric range.

{phang}
{opt collapse} and {opt merge} control the output shape. {cmd:collapse}
returns one row per {cmd:id()} and is the default when neither shape option is
specified. {cmd:merge} merges patient-level condition indicators and the score
back to the encounter-level data.

{phang}
{opt date(varname)} and {opt refdate(varname)} pass encounter and reference
date variables to {cmd:codescan}. Use them with {opt lookb:ack(#)} and
{opt lookf:orward(#)} to restrict codes to a time window around the reference
date. The default for both look-window options is {cmd:-1}, meaning no bound is
passed. {opt incl:usive} includes the reference date in the time window.

{phang}
{opt gen:erate(prefix)} passes the prefix to {cmd:codescan} for component
indicators and names the score variable {it:prefix}{cmd:score}. Without
{cmd:generate()}, the score variable is named {cmd:charlson},
{cmd:elixhauser}, or {cmd:custom}.

{phang}
{opt replace} allows {cmd:comorbidity} to overwrite existing condition and score
variables. It never permits the score or a custom condition indicator to
overwrite {cmd:id()}, a diagnosis variable, {cmd:date()},
or {cmd:refdate()}. Without {cmd:replace}, the command exits with {cmd:r(110)}
if the score variable already exists.

{phang}
{opt nohierarchy} disables supersession rules. By default, Charlson applies
{cmd:dm_comp > dm_uncomp}, {cmd:liver_severe > liver_mild}, and
{cmd:metastatic > cancer}. Elixhauser applies {cmd:htn_comp > htn_uncomp},
{cmd:metastatic > solid_tumor}, and {cmd:dm_comp > dm_uncomp}.

{phang}
{opt band} returns patient-level counts and percentages in {cmd:r(bands)} for
negative scores, score 0, scores greater than 0 and less than 3, scores from 3
to less than 5, and scores 5 or greater. The row names are
{cmd:score_negative}, {cmd:score0}, {cmd:score1_2}, {cmd:score3_4}, and
{cmd:score5plus}. The categories are exhaustive for nonmissing scores, including
fractional custom scores, and {cmd:merge} counts each {cmd:id()} once. The 0,
1-2, 3-4, and 5+ cutpoints reproduce Charlson et al. (1987); for
Elixhauser and custom scores they are descriptive categories, not validated
risk strata.

{phang}
{opt noisily} passes verbose output through to {cmd:codescan}.

{marker schemes}{...}
{title:Schemes}

{pstd}
Charlson {cmd:original} uses the original Charlson weights with the Quan ICD-10
dictionary. Charlson {cmd:quan2011} uses Quan et al. updated weights. Elixhauser
{cmd:vanwalraven} uses van Walraven et al. weights.

{pstd}
The built-in Charlson and Elixhauser ICD-10 definitions follow Tables 1 and 2
of Quan et al. (2005). Scores are computed as the sum of each binary condition
indicator multiplied by its scheme weight after hierarchy is applied.

{pstd}
For {cmd:charlson(original)}, the Quan ICD-10 dictionary combines solid tumors,
leukemia, and lymphoma into one {cmd:cancer} indicator. The command therefore
reproduces Charlson's weights but cannot separately add those three original
conditions when more than one is present. The supersession hierarchy described
under {cmd:nohierarchy} is a package convention rather than a rule established
by the cited scoring papers.

{pstd}
The {cmd:quan2011} vector is cross-validated against R {cmd:comorbidity}
1.1.0. That parity check is not an independent audit of the primary paper's exact
condition-level weight table.

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:comorbidity} stores the following in {cmd:r()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}patient-level observations from {cmd:codescan}{p_end}
{synopt:{cmd:r(hierarchy)}}1 if hierarchy applied; 0 otherwise{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(index)}}resolved index name{p_end}
{synopt:{cmd:r(scheme)}}resolved weighting scheme{p_end}
{synopt:{cmd:r(scorevar)}}score variable created{p_end}
{synopt:{cmd:r(conditions)}}condition indicator variables in score order{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:r(weights)}}per-condition weights in score order{p_end}
{synopt:{cmd:r(summary)}}post-hierarchy condition summary{p_end}
{synopt:{cmd:r(bands)}}patient-level score-band summary{p_end}

{marker examples}{...}
{title:Examples}

{pstd}Charlson original score{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long pid str6 dx1 str6 dx2}{p_end}
{phang2}{cmd:. 1 "I21" "I50"}{p_end}
{phang2}{cmd:. 1 "E119" ""}{p_end}
{phang2}{cmd:. 2 "C780" ""}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. comorbidity dx1 dx2, id(pid) charlson(original) collapse band}{p_end}
{phang2}{cmd:. matrix list r(bands)}{p_end}

{pstd}Elixhauser van Walraven score with generated names and score bands{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long pid str6 dx1 str6 dx2 str6 dx3}{p_end}
{phang2}{cmd:. 1 "I50" "C780" "F11"}{p_end}
{phang2}{cmd:. 2 "E66" "F32" ""}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. comorbidity dx1 dx2 dx3, id(pid) elixhauser(vanwalraven) collapse generate(elx_) band}{p_end}
{phang2}{cmd:. matrix list r(bands)}{p_end}

{pstd}Merge patient-level scores back to encounter rows{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long pid str6 dx1 str6 dx2}{p_end}
{phang2}{cmd:. 1 "I21" "I50"}{p_end}
{phang2}{cmd:. 1 "E119" ""}{p_end}
{phang2}{cmd:. 2 "C780" ""}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. comorbidity dx1 dx2, id(pid) charlson(quan2011) merge generate(cmb_)}{p_end}

{pstd}Restrict codes to an inclusive lookback/lookforward window{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long pid str6 dx1 int dxdate int refdate}{p_end}
{phang2}{cmd:. 1 "I50" 21910 21915}{p_end}
{phang2}{cmd:. 1 "I21" 21885 21915}{p_end}
{phang2}{cmd:. 2 "I50" 21550 21915}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. format dxdate refdate %td}{p_end}
{phang2}{cmd:. comorbidity dx1, id(pid) charlson(original) collapse date(dxdate) refdate(refdate) lookback(30) lookforward(10) inclusive}{p_end}

{pstd}Use a custom weighted code file{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input long pid str6 dx1 str6 dx2}{p_end}
{phang2}{cmd:. 1 "I21" "I50"}{p_end}
{phang2}{cmd:. 2 "E119" ""}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. tempfile custom_codes}{p_end}
{phang2}{cmd:. preserve}{p_end}
{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. input str12 name str20 pattern double weight}{p_end}
{phang2}{cmd:. "mi" "I21|I22" 10}{p_end}
{phang2}{cmd:. "chf" "I50" 2}{p_end}
{phang2}{cmd:. "dm" "E11" 4}{p_end}
{phang2}{cmd:. end}{p_end}
{phang2}{cmd:. save "`custom_codes'.dta", replace}{p_end}
{phang2}{cmd:. restore}{p_end}
{phang2}{cmd:. comorbidity dx1 dx2, id(pid) custom("`custom_codes'.dta") collapse}{p_end}

{marker references}{...}
{title:References}

{phang}
Charlson, M. E., P. Pompei, K. L. Ales, and C. R. MacKenzie. 1987. A new method of classifying prognostic comorbidity in longitudinal studies: Development and validation. {it:Journal of Chronic Diseases} 40: 373-383. {browse "https://doi.org/10.1016/0021-9681(87)90171-8"}.{p_end}

{phang}
Quan, H., V. Sundararajan, P. Halfon, et al. 2005. Coding algorithms for defining comorbidities in ICD-9-CM and ICD-10 administrative data. {it:Medical Care} 43: 1130-1139. {browse "https://doi.org/10.1097/01.mlr.0000182534.19832.83"}.{p_end}

{phang}
Quan, H., B. Li, C. M. Couris, et al. 2011. Updating and validating the Charlson comorbidity index and score for risk adjustment in hospital discharge abstracts using data from 6 countries. {it:American Journal of Epidemiology} 173: 676-682. {browse "https://doi.org/10.1093/aje/kwq433"}.{p_end}

{phang}
van Walraven, C., P. C. Austin, A. Jennings, H. Quan, and A. J. Forster. 2009. A modification of the Elixhauser comorbidity measures into a point system for hospital death using administrative data. {it:Medical Care} 47: 626-633. {browse "https://doi.org/10.1097/MLR.0b013e31819432e5"}.{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.0.1, 2026-08-30{p_end}

{title:Also see}

{psee}{helpb codescan}{p_end}

{hline}

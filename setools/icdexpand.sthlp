{smcl}
{* *! version 1.0.1  31dec2025}{...}
{vieweralsosee "[D] generate" "help generate"}{...}
{vieweralsosee "migrations" "help migrations"}{...}
{vieweralsosee "sustainedss" "help sustainedss"}{...}
{viewerjumpto "Syntax" "icdexpand##syntax"}{...}
{viewerjumpto "Description" "icdexpand##description"}{...}
{viewerjumpto "Subcommands" "icdexpand##subcommands"}{...}
{viewerjumpto "Options" "icdexpand##options"}{...}
{viewerjumpto "Examples" "icdexpand##examples"}{...}
{viewerjumpto "Stored results" "icdexpand##results"}{...}
{viewerjumpto "Author" "icdexpand##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:icdexpand} {hline 2}}ICD-10 code utilities for Swedish registry research{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Expand ICD code patterns to full code list:

{p 8 17 2}
{cmd:icdexpand expand}
{cmd:,} {opt pat:tern(string)} [{it:expand_options}]

{pstd}
Validate ICD-10 code format:

{p 8 17 2}
{cmd:icdexpand validate}
{cmd:,} {opt pat:tern(string)} [{opt noi:sily}]

{pstd}
Create matching indicator variable:

{p 8 17 2}
{cmd:icdexpand match}
{cmd:,} {opt codes(string)} {opt dxvars(varlist)} [{it:match_options}]


{synoptset 24 tabbed}{...}
{synopthdr:expand_options}
{synoptline}
{syntab:Required}
{synopt:{opt pat:tern(string)}}ICD code pattern to expand (e.g., "I63*", "E10-E14"){p_end}

{syntab:Optional}
{synopt:{opt max:codes(#)}}maximum number of codes to expand; default is {cmd:1000}{p_end}
{synopt:{opt noi:sily}}display expansion summary{p_end}
{synoptline}

{synoptset 24 tabbed}{...}
{synopthdr:match_options}
{synoptline}
{syntab:Required}
{synopt:{opt codes(string)}}ICD code pattern to match{p_end}
{synopt:{opt dxvars(varlist)}}diagnosis variables to search (e.g., dx1-dx30){p_end}

{syntab:Optional}
{synopt:{opt gen:erate(name)}}name for generated indicator variable; default is {cmd:_icd_match}{p_end}
{synopt:{opt replace}}replace existing variable if it exists{p_end}
{synopt:{opt case:sensitive}}perform case-sensitive matching{p_end}
{synopt:{opt noi:sily}}display matching summary{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:icdexpand} provides utilities for working with ICD-10 diagnosis codes in Swedish health
registries. It supports three main operations:

{phang2}1. {bf:expand}: Expand wildcard patterns (e.g., "I63*") and ranges (e.g., "E10-E14")
into complete code lists including all subcategory variations.{p_end}

{phang2}2. {bf:validate}: Check that ICD code patterns are syntactically valid.{p_end}

{phang2}3. {bf:match}: Search diagnosis variables (dx1-dx30) for specified ICD codes and
create a binary indicator variable.{p_end}

{pstd}
{bf:Swedish registry considerations:}

{pstd}
Swedish health registries may record ICD-10 codes in different formats:

{phang2}- With decimal point: {cmd:I63.4}{p_end}
{phang2}- Without decimal point: {cmd:I634}{p_end}
{phang2}- At different specificity levels: {cmd:I63}, {cmd:I63.4}, {cmd:I63.41}{p_end}

{pstd}
The wildcard expansion accounts for all these variations to ensure complete capture.


{marker subcommands}{...}
{title:Subcommands}

{dlgtab:expand}

{pstd}
Expands ICD code patterns into complete code lists.

{pstd}
{bf:Wildcard expansion} ({cmd:*}): The pattern "I63*" expands to:

{phang2}- Base code: I63{p_end}
{phang2}- Single-digit with decimal: I63.0, I63.1, ..., I63.9{p_end}
{phang2}- Single-digit without decimal: I630, I631, ..., I639{p_end}
{phang2}- Two-digit with decimal: I63.00, I63.01, ..., I63.99{p_end}

{pstd}
{bf:Range expansion} ({cmd:-}): The pattern "E10-E14" expands to all codes E10, E11, E12,
E13, E14 and their subcategories.

{pstd}
{bf:Multiple patterns}: Separate with spaces or commas: "I63* I64*, G35"

{dlgtab:validate}

{pstd}
Validates ICD-10 code syntax. Valid codes must:

{phang2}- Start with a letter (A-Z){p_end}
{phang2}- Contain only letters, digits, decimal points, hyphens, and asterisks{p_end}

{dlgtab:match}

{pstd}
Searches diagnosis variables for ICD codes and creates a binary indicator. This is useful
for identifying hospitalizations or visits with specific diagnoses.

{pstd}
By default, matching is case-insensitive (recommended for Swedish registries where case
may vary).


{marker options}{...}
{title:Options}

{dlgtab:expand}

{phang}
{opt pattern(string)} specifies the ICD code pattern to expand. Supports wildcards (*),
ranges (-), and comma/space-separated lists. Required.

{phang}
{opt maxcodes(#)} specifies the maximum number of codes allowed after expansion.
This is a safety limit to prevent accidental expansion of very broad patterns.
Default is 1000.

{phang}
{opt noisily} displays a summary of the expansion.

{dlgtab:validate}

{phang}
{opt pattern(string)} specifies the ICD code pattern(s) to validate. Required.

{phang}
{opt noisily} displays validation results.

{dlgtab:match}

{phang}
{opt codes(string)} specifies the ICD code pattern to search for. Supports wildcards,
ranges, and lists (same as {opt pattern()} in expand). Required.

{phang}
{opt dxvars(varlist)} specifies the diagnosis variables to search. For Swedish
inpatient/outpatient registries, this is typically {cmd:dx1-dx30}. Required.

{phang}
{opt generate(name)} specifies the name for the generated indicator variable.
Default is {cmd:_icd_match}.

{phang}
{opt replace} allows an existing variable with the same name to be replaced.

{phang}
{opt casesensitive} performs case-sensitive matching. By default, matching is
case-insensitive (both codes and diagnosis variables are converted to uppercase).

{phang}
{opt noisily} displays a summary of matching results.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Expand a wildcard pattern}

{phang2}{cmd:. icdexpand expand, pattern("I63*") noisily}{p_end}
{phang2}{cmd:. return list}{p_end}
{phang2}{cmd:. display r(n_codes)}{p_end}

{pstd}
{bf:Example 2: Expand a range of diabetes codes}

{phang2}{cmd:. icdexpand expand, pattern("E10-E14")}{p_end}
{phang2}{cmd:. local diabetes_codes "`r(codes)'"}{p_end}

{pstd}
{bf:Example 3: Expand multiple patterns}

{phang2}{cmd:. icdexpand expand, pattern("I63* I64* G45*")}{p_end}
{phang2}{cmd:. local stroke_codes "`r(codes)'"}{p_end}

{pstd}
{bf:Example 4: Validate ICD codes}

{phang2}{cmd:. icdexpand validate, pattern("I63.4, E11.2, ZZZ99") noisily}{p_end}
{phang2}{cmd:. if r(valid) == 0 display "Invalid codes: `r(invalid_codes)'"}{p_end}

{pstd}
{bf:Example 5: Create stroke indicator from inpatient data}

{phang2}{cmd:. use inpatient, clear}{p_end}
{phang2}{cmd:. icdexpand match, codes("I63* I64*") dxvars(dx1-dx10) generate(stroke) noisily}{p_end}
{phang2}{cmd:. tab stroke}{p_end}

{pstd}
{bf:Example 6: Find MS diagnoses in outpatient data}

{phang2}{cmd:. use out_2020, clear}{p_end}
{phang2}{cmd:. icdexpand match, codes("G35") dxvars(dx1-dx30) generate(ms_dx) replace}{p_end}
{phang2}{cmd:. keep if ms_dx == 1}{p_end}

{pstd}
{bf:Example 7: Create cancer indicator (excluding non-melanoma skin cancer)}

{phang2}{cmd:. * First create comprehensive cancer indicator}{p_end}
{phang2}{cmd:. icdexpand match, codes("C00-C43* C45-C97*") dxvars(dx1-dx30) generate(cancer)}{p_end}

{pstd}
{bf:Example 8: Typical workflow for cohort study}

{phang2}{cmd:. * Load inpatient data}{p_end}
{phang2}{cmd:. use inpatient, clear}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Identify stroke hospitalizations}{p_end}
{phang2}{cmd:. icdexpand match, codes("I63* I64*") dxvars(dx1-dx30) generate(stroke)}{p_end}
{phang2}{cmd:. }{p_end}
{phang2}{cmd:. * Keep first stroke per person}{p_end}
{phang2}{cmd:. keep if stroke == 1}{p_end}
{phang2}{cmd:. bysort id (admitdt): keep if _n == 1}{p_end}
{phang2}{cmd:. rename admitdt stroke_date}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:icdexpand expand} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(codes)}}space-separated list of expanded codes{p_end}

{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_codes)}}number of codes after expansion{p_end}


{pstd}
{cmd:icdexpand validate} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(valid)}}1 if all codes valid, 0 otherwise{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(invalid_codes)}}list of invalid codes (if any){p_end}


{pstd}
{cmd:icdexpand match} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varname)}}name of generated indicator variable{p_end}
{synopt:{cmd:r(codes)}}space-separated list of expanded codes searched{p_end}

{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_codes)}}number of codes searched{p_end}
{synopt:{cmd:r(n_matches)}}number of observations matching{p_end}


{marker author}{...}
{title:Author}

{pstd}
Tim Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet{break}
Stockholm, Sweden

{pstd}
Part of the setools package for Swedish registry research.{p_end}


{marker alsosee}{...}
{title:Also see}

{pstd}
{help migrations:migrations} - Process Swedish migration registry data{p_end}
{pstd}
{help sustainedss:sustainedss} - Compute sustained EDSS progression dates{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Swedish-Cohorts":Swedish-Cohorts on GitHub}{p_end}

{smcl}
{* *! version 1.0.0  21dec2025}{...}
{vieweralsosee "[D] assert" "help assert"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{viewerjumpto "Syntax" "validate##syntax"}{...}
{viewerjumpto "Description" "validate##description"}{...}
{viewerjumpto "Options" "validate##options"}{...}
{viewerjumpto "Remarks" "validate##remarks"}{...}
{viewerjumpto "Examples" "validate##examples"}{...}
{viewerjumpto "Stored results" "validate##results"}{...}
{viewerjumpto "Author" "validate##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:validate} {hline 2}}Data validation rules - define and run validation suites{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:validate}
{varlist}
{ifin}
[{cmd:,} {it:options}]


{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Validation Rules}
{synopt:{opt range(# #)}}expected numeric range (min max){p_end}
{synopt:{opt val:ues(list)}}expected values (numeric or string){p_end}
{synopt:{opt pat:tern(regex)}}expected regex pattern for strings{p_end}
{synopt:{opt type(string)}}expected type: numeric, string, date{p_end}
{synopt:{opt nomiss}}no missing values allowed{p_end}
{synopt:{opt unique}}all values must be unique{p_end}
{synopt:{opt cross(condition)}}cross-variable validation expression{p_end}

{syntab:Behavior}
{synopt:{opt assert}}stop execution on validation failure{p_end}
{synopt:{opt gen:erate(name)}}generate indicator for valid observations{p_end}
{synopt:{opt replace}}allow replacing existing variable{p_end}

{syntab:Output}
{synopt:{opt rep:ort}}display detailed report{p_end}
{synopt:{opt xlsx(filename)}}export validation report to Excel{p_end}
{synopt:{opt sheet(name)}}Excel sheet name; default is "Validation"{p_end}
{synopt:{opt title(string)}}report title{p_end}

{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:validate} defines and runs data validation rules to check data quality
and integrity. It supports range checks, value checks, pattern matching,
missing value detection, uniqueness constraints, and cross-variable conditions.

{pstd}
The command is designed for registry data QC and ensuring data integrity
before analysis. It generates detailed reports and can export results to Excel.

{pstd}
Validation types include:

{phang2}{bf:Range checks:} Verify numeric values fall within expected bounds.

{phang2}{bf:Value checks:} Verify values match an expected set (categorical).

{phang2}{bf:Pattern checks:} Verify strings match a regex pattern.

{phang2}{bf:Missing checks:} Verify no missing values exist.

{phang2}{bf:Uniqueness:} Verify all values are unique (e.g., IDs).

{phang2}{bf:Cross-variable:} Verify relationships between variables.


{marker options}{...}
{title:Options}

{dlgtab:Validation Rules}

{phang}
{opt range(# #)} specifies the expected numeric range as minimum and maximum
values. Values outside this range are flagged as invalid.

{phang}
{opt values(list)} specifies a list of expected values. For numeric variables,
provide space-separated numbers. For string variables, provide space-separated
strings.

{phang}
{opt pattern(regex)} specifies a regular expression pattern that string
values must match. Uses Stata's {help regexm()} function.

{phang}
{opt type(string)} checks that variables are of the expected type.
Valid options are {bf:numeric}, {bf:string}, or {bf:date}.

{phang}
{opt nomiss} specifies that no missing values are allowed. Any observation
with a missing value fails validation.

{phang}
{opt unique} specifies that all values must be unique. Duplicate values
fail validation. Useful for ID variables.

{phang}
{opt cross(condition)} specifies a cross-variable validation expression
that must be true for all observations. For example, {cmd:cross(start <= end)}
checks that start dates precede end dates.

{dlgtab:Behavior}

{phang}
{opt assert} causes the command to stop with an error if any validation
rule fails. Useful in do-files to halt execution on data quality issues.

{phang}
{opt generate(name)} creates a binary indicator variable that equals 1
for observations passing all validation rules and 0 for failures.

{phang}
{opt replace} allows overwriting an existing variable when using {opt generate()}.

{dlgtab:Output}

{phang}
{opt report} displays a detailed validation report.

{phang}
{opt xlsx(filename)} exports the validation report to an Excel file.

{phang}
{opt sheet(name)} specifies the Excel sheet name. Default is "Validation".

{phang}
{opt title(string)} specifies a title for the validation report.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Using validate in workflows}

{pstd}
{cmd:validate} is designed to be run early in analysis workflows to catch
data quality issues before they cause problems downstream.

{pstd}
A typical workflow might be:

{phang2}1. Load data

{phang2}2. Run {cmd:validate} with expected rules

{phang2}3. Review any failures

{phang2}4. Fix issues or document exceptions

{phang2}5. Proceed with analysis

{pstd}
{bf:Regular expressions}

{pstd}
The {opt pattern()} option uses Stata's regular expressions. Common patterns:

{p2colset 8 25 27 2}{...}
{p2col:^[A-Z]{3}$}Exactly 3 uppercase letters{p_end}
{p2col:^[0-9]+$}One or more digits{p_end}
{p2col:^P[0-9]{6}$}P followed by 6 digits{p_end}
{p2col:[0-9]{4}-[0-9]{2}-[0-9]{2}}Date format YYYY-MM-DD{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Check age is in valid range}

{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. validate mpg, range(10 50) nomiss}{p_end}

{pstd}
{bf:Example 2: Check categorical values}

{phang2}{cmd:. validate foreign, values(0 1)}{p_end}

{pstd}
{bf:Example 3: Check multiple variables}

{phang2}{cmd:. validate price mpg weight, nomiss}{p_end}

{pstd}
{bf:Example 4: Check uniqueness}

{phang2}{cmd:. webuse nlswork, clear}{p_end}
{phang2}{cmd:. validate idcode, unique}{p_end}

{pstd}
{bf:Example 5: Cross-variable validation}

{phang2}{cmd:. validate price mpg, cross(price > 0 & mpg > 0)}{p_end}

{pstd}
{bf:Example 6: Generate validation indicator}

{phang2}{cmd:. validate price mpg, range(0 50000) generate(valid)}{p_end}
{phang2}{cmd:. tab valid}{p_end}

{pstd}
{bf:Example 7: Assert on failure (stop execution)}

{phang2}{cmd:. validate foreign, values(0 1) assert}{p_end}

{pstd}
{bf:Example 8: Export to Excel}

{phang2}{cmd:. validate price mpg weight, nomiss xlsx(validation.xlsx)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:validate} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations checked{p_end}
{synopt:{cmd:r(n_rules)}}total number of rules evaluated{p_end}
{synopt:{cmd:r(rules_passed)}}number of rules that passed{p_end}
{synopt:{cmd:r(rules_failed)}}number of rules that failed{p_end}
{synopt:{cmd:r(pct_passed)}}percentage of rules passed{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}variables validated{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(results)}}matrix of validation results{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2025-12-21{p_end}


{title:Also see}

{psee}
Manual:  {manlink D assert}, {manlink D codebook}

{psee}
Online:  {helpb assert}, {helpb codebook}, {helpb describe}

{hline}

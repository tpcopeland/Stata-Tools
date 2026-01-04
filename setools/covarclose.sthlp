{smcl}
{* *! version 1.0.0  16dec2025}{...}
{viewerjumpto "Syntax" "covarclose##syntax"}{...}
{viewerjumpto "Description" "covarclose##description"}{...}
{viewerjumpto "Options" "covarclose##options"}{...}
{viewerjumpto "Examples" "covarclose##examples"}{...}
{viewerjumpto "Stored results" "covarclose##results"}{...}
{viewerjumpto "Author" "covarclose##author"}{...}

{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:covarclose} {hline 2}}Extract covariate values closest to index date{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:covarclose} {cmd:using} {it:filename}{cmd:,}
{opt idvar(varname)}
{opt indexdate(varname)}
{opt datevar(string)}
{opt vars(varlist)}
[{opt yearformat}
{opt impute}
{opt prefer(string)}
{opt missing(numlist)}
{opt noisily}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:covarclose} extracts covariate values from longitudinal/panel data at the
observation closest to an index date. This is commonly needed when working with
Swedish registries like LISA (longitudinal integration database for health
insurance and labor market studies), RTB (total population register), or
smoking history from disease registries.

{pstd}
The command merges the extracted values back to the master data in memory,
adding one observation per person with their closest covariate values.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{cmd:using} {it:filename} specifies the covariate file to extract values from.

{phang}
{opt idvar(varname)} specifies the person identifier variable. Must exist in
both the master data and the using file.

{phang}
{opt indexdate(varname)} specifies the index date variable in the master data.
Covariates are extracted closest to this date.

{phang}
{opt datevar(string)} specifies the date or year variable in the using file.
If {opt yearformat} is specified, this is interpreted as a year variable;
otherwise it should be a Stata date variable.

{phang}
{opt vars(varlist)} specifies the covariate variables to extract from the
using file.

{dlgtab:Optional}

{phang}
{opt yearformat} indicates that {opt datevar()} contains year values (e.g., 2015)
rather than Stata dates. The year is converted to mid-year (July 1) for
distance calculations. Use this for LISA and RTB data.

{phang}
{opt impute} enables imputation of missing values. Missing values (including those
specified in {opt missing()}) are filled forward and backward within person
from adjacent observations.

{phang}
{opt prefer(string)} specifies which observations to prefer when multiple
observations are equidistant from the index date. Options are:
{break}{cmd:closest} - prefer observation closest to index (default)
{break}{cmd:before} - prefer observations before or at index date
{break}{cmd:after} - prefer observations after or at index date

{phang}
{opt missing(numlist)} specifies numeric values to treat as missing (e.g., 99, 999).
These are converted to system missing before imputation or selection.

{phang}
{opt noisily} displays progress and summary information including the number
of non-missing values extracted for each variable.


{marker examples}{...}
{title:Examples}

{pstd}Setup with cohort data{p_end}
{phang2}{cmd:. use study_start, clear}{p_end}
{phang2}{cmd:. rename study_start indexdate}{p_end}

{pstd}Extract education from LISA (year-based file){p_end}
{phang2}{cmd:. covarclose using lisa, idvar(id) indexdate(indexdate) datevar(year) vars(educ_lev_old) yearformat impute missing(99) prefer(closest) noisily}{p_end}

{pstd}Extract region from RTB{p_end}
{phang2}{cmd:. covarclose using rtb, idvar(id) indexdate(indexdate) datevar(yr) vars(city) yearformat prefer(closest) noisily}{p_end}

{pstd}Extract smoking status from MS Registry (date-based file){p_end}
{phang2}{cmd:. covarclose using msreg_smoking, idvar(id) indexdate(indexdate) datevar(assessment_date) vars(smoking_status) prefer(before) noisily}{p_end}

{pstd}Extract multiple covariates at once{p_end}
{phang2}{cmd:. covarclose using lisa, idvar(id) indexdate(indexdate) datevar(year) vars(educ_lev_old income dispink) yearformat impute missing(99 .) noisily}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:covarclose} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(n_total)}}number of observations in master data{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(vars)}}variables extracted{p_end}
{synopt:{cmd:r(prefer)}}preference method used{p_end}


{marker author}{...}
{title:Author}

{pstd}Tim Copeland{break}
Karolinska Institutet{break}
Stockholm, Sweden{p_end}

{pstd}Part of the {cmd:setools} package for Swedish registry epidemiology.{p_end}


{title:Also see}

{psee}
{space 2}Help:  {help merge}, {help joinby}
{p_end}

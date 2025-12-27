{smcl}
{* *! version 1.3.0  27dec2025}{...}
{viewerjumpto "Syntax" "synthdata##syntax"}{...}
{viewerjumpto "Description" "synthdata##description"}{...}
{viewerjumpto "Options" "synthdata##options"}{...}
{viewerjumpto "Methods" "synthdata##methods"}{...}
{viewerjumpto "Examples" "synthdata##examples"}{...}
{viewerjumpto "Stored results" "synthdata##results"}{...}
{viewerjumpto "Author" "synthdata##author"}{...}
{title:Title}

{phang}
{bf:synthdata} {hline 2} Generate realistic synthetic datasets preserving statistical properties


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:synthdata}
[{varlist}]
{ifin}
{cmd:,} [{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Output}
{synopt:{opt n(#)}}number of synthetic observations; default is same as original{p_end}
{synopt:{opt sav:ing(filename)}}save synthetic data to file{p_end}
{synopt:{opt replace}}replace current data with synthetic version{p_end}
{synopt:{opt clear}}clear current data and load synthetic{p_end}
{synopt:{opt pre:fix(string)}}prefix for synthetic variable names{p_end}
{synopt:{opt mul:tiple(#)}}generate # synthetic datasets{p_end}

{syntab:Synthesis Method}
{synopt:{opt smart}}adaptive synthesis with automatic optimizations (recommended){p_end}
{synopt:{opt para:metric}}parametric synthesis via Cholesky decomposition (default){p_end}
{synopt:{opt seq:uential}}sequential regression synthesis{p_end}
{synopt:{opt boot:strap}}bootstrap with perturbation{p_end}
{synopt:{opt perm:ute}}independent permutation (null/baseline){p_end}

{syntab:Method Modifiers}
{synopt:{opt emp:irical}}use empirical quantiles for marginals{p_end}
{synopt:{opt autoemp:irical}}auto-detect non-normal distributions{p_end}
{synopt:{opt noise(#)}}perturbation SD as fraction of variable SD; default 0.1{p_end}
{synopt:{opt smooth}}kernel density estimation for continuous variables{p_end}

{syntab:Variable Type}
{synopt:{opt cat:egorical(varlist)}}force treatment as categorical{p_end}
{synopt:{opt cont:inuous(varlist)}}force treatment as continuous{p_end}
{synopt:{opt int:eger(varlist)}}force treatment as integer (whole numbers){p_end}
{synopt:{opt skip(varlist)}}exclude from synthesis{p_end}
{synopt:{opt id(varlist)}}ID variables; generate new sequential IDs{p_end}
{synopt:{opt dat:es(varlist)}}ensure date constraints{p_end}

{syntab:Relationship Preservation}
{synopt:{opt corr:elations}}preserve correlation matrix structure{p_end}
{synopt:{opt cond:itional}}preserve conditional distributions for categoricals{p_end}
{synopt:{opt const:raints(string)}}user-specified constraints{p_end}
{synopt:{opt autocons:traints}}auto-detect logical constraints{p_end}
{synopt:{opt autorel:ate}}auto-detect derived variables (sums, ratios){p_end}
{synopt:{opt cond:itionalcat}}preserve categorical associations{p_end}

{syntab:Panel/Longitudinal}
{synopt:{opt panel(id time)}}preserve panel structure{p_end}
{synopt:{opt preservevar(varlist)}}variables constant within panel unit{p_end}
{synopt:{opt autocorr(#)}}preserve autocorrelation up to # lags{p_end}

{syntab:Privacy/Disclosure Control}
{synopt:{opt mincell(#)}}rare category protection; default 5{p_end}
{synopt:{opt trim(#)}}trim extreme values at #th percentile{p_end}
{synopt:{opt bounds(spec)}}enforce min/max bounds{p_end}
{synopt:{opt noext:reme}}prevent values outside observed range{p_end}

{syntab:Validation/Diagnostics}
{synopt:{opt com:pare}}produce comparison report{p_end}
{synopt:{opt val:idate(filename)}}save validation statistics{p_end}
{synopt:{opt util:ity}}compute utility metrics{p_end}
{synopt:{opt graph}}produce overlay density plots{p_end}

{syntab:Technical}
{synopt:{opt seed(#)}}random seed for reproducibility{p_end}
{synopt:{opt iter:ate(#)}}max iterations for constraints; default 100{p_end}
{synopt:{opt tol:erance(#)}}convergence tolerance; default 1e-6{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:synthdata} generates synthetic datasets that preserve the statistical
properties and variable relationships of the original data without containing
real observations. This is useful for:

{phang2}- Working with sensitive data in unsecured environments{p_end}
{phang2}- Sharing data for collaboration while protecting privacy{p_end}
{phang2}- Developing and testing code before accessing restricted data{p_end}
{phang2}- Creating teaching datasets{p_end}
{phang2}- Augmenting small samples for model development{p_end}

{pstd}
If {varlist} is omitted, all variables are synthesized.

{pstd}
{bf:Automatic preservation features:}

{pstd}
{cmd:synthdata} automatically preserves key properties from the original data:

{phang2}{bf:Variable labels} - All variable labels from the original data are
applied to the synthetic variables.{p_end}

{phang2}{bf:Value labels} - Value label attachments for categorical variables
are preserved.{p_end}

{phang2}{bf:Variable order} - Variables in the synthetic data are ordered to
match the original data.{p_end}

{phang2}{bf:Missingness rates} - The proportion of missing values for each
variable is preserved. If a variable has 10% missing values in the original
data, approximately 10% of values will be randomly set to missing in the
synthetic data.{p_end}

{phang2}{bf:Integer detection} - Continuous variables that contain only whole
numbers (integers) are automatically detected and synthesized values are
rounded to integers.{p_end}

{phang2}{bf:String variables} - String variables are automatically treated as
categorical variables. Synthetic values are drawn from the observed
frequency distribution of the original string values.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Output}

{phang}
{opt n(#)} specifies the number of observations in the synthetic dataset.
The default is the same as the original.

{phang}
{opt saving(filename)} saves the synthetic data to {it:filename}.dta.

{phang}
{opt replace} replaces the current data in memory with the synthetic version.

{phang}
{opt clear} clears the current data and loads the synthetic version (same as
{opt replace}).

{phang}
{opt prefix(string)} adds {it:string} as a prefix to all synthetic variable
names, keeping originals for comparison.

{phang}
{opt multiple(#)} generates # synthetic datasets, saved as 
{it:filename}_1.dta, {it:filename}_2.dta, etc. Requires {opt saving()}.

{dlgtab:Synthesis Method}

{phang}
{opt smart} is the recommended method for realistic synthesis. It automatically:
{p_end}
{pmore}(1) Detects non-normal distributions and uses empirical quantiles for them{p_end}
{pmore}(2) Detects derived variables (sums, ratios) and reconstructs them{p_end}
{pmore}(3) Detects strongly associated categorical variables and synthesizes jointly{p_end}
{pmore}(4) Auto-detects logical constraints (non-negative values, etc.){p_end}
{pmore}This method produces the most realistic synthetic data with minimal configuration.

{phang}
{opt parametric} (the default if smart is not specified) fits parametric
distributions to continuous variables and preserves the correlation matrix
via Cholesky decomposition. Categorical variables are drawn from observed
frequencies.

{phang}
{opt sequential} models each variable conditional on previous variables using
regression, then draws from the predictive distribution. Handles mixed types
naturally and can capture complex dependencies.

{phang}
{opt bootstrap} resamples rows with replacement and adds random noise to
continuous variables. Simple and fast but may not preserve all relationships.

{phang}
{opt permute} permutes each variable independently, breaking all relationships.
Useful as a null/baseline comparison.

{dlgtab:Method Modifiers}

{phang}
{opt empirical} uses empirical quantile mapping instead of normal distribution for
continuous variables. This approach:
{p_end}
{pmore}(1) Guarantees synthetic values stay within original [min, max] bounds{p_end}
{pmore}(2) Preserves the exact original distribution shape (skewness, kurtosis, etc.){p_end}
{pmore}(3) Uses a Gaussian copula to maintain correlations between variables{p_end}
{pmore}Recommended when distribution shape and bounds are important, or when the original
data is not normally distributed.

{phang}
{opt autoempirical} automatically detects non-normal distributions and uses
empirical quantile synthesis for them, while using parametric synthesis for
normally-distributed variables. This is the best of both worlds: parametric
efficiency where appropriate, and empirical accuracy for non-normal data.
Non-normality is detected using skewness (|skewness| > 1) and kurtosis
(|kurtosis - 3| > 2) thresholds.

{phang}
{opt noise(#)} specifies the standard deviation of random noise added to
continuous variables, as a fraction of each variable's standard deviation.
Default is 0.1 for the bootstrap method.

{phang}
{opt smooth} uses kernel density estimation instead of normal assumption for
continuous variables.

{dlgtab:Variable Type}

{phang}
{opt categorical(varlist)} forces specified numeric variables to be treated as
categorical, overriding automatic detection. String variables are always
treated as categorical automatically and do not need to be specified here;
if a string variable is included in this option, it will be handled correctly
as a string categorical variable.

{phang}
{opt continuous(varlist)} forces specified variables to be treated as
continuous, overriding automatic detection.

{phang}
{opt integer(varlist)} forces specified variables to be treated as
integer (whole number) continuous variables. These are synthesized as
continuous variables but rounded to whole numbers after synthesis. Integer
variables are also automatically detected: any numeric variable with more
than 20 unique values where all non-missing values are whole numbers is
treated as integer.

{phang}
{opt skip(varlist)} excludes specified variables from synthesis. They are
set to missing in the synthetic data.

{phang}
{opt id(varlist)} specifies ID variables. Instead of synthesizing, new
sequential IDs (1, 2, 3, ...) are generated.

{phang}
{opt dates(varlist)} specifies date variables to ensure proper handling of
date formats and constraints.

{dlgtab:Relationship Preservation}

{phang}
{opt correlations} strictly preserves the correlation matrix structure. This
is the default for the parametric method.

{phang}
{opt conditional} preserves conditional distributions for categorical
variables given continuous variables.

{phang}
{opt constraints(string)} specifies user constraints as quoted expressions,
e.g., {cmd:constraints("age>=18" "start_date<end_date")}.

{phang}
{opt autoconstraints} automatically detects logical constraints such as
non-negative values and applies them.

{phang}
{opt autorelate} automatically detects derived variables that are perfect or
near-perfect functions of other variables (R² > 0.999). Examples include:
{p_end}
{pmore}- Sums: total = a + b + c{p_end}
{pmore}- Differences: duration = end_date - start_date{p_end}
{pmore}- Perfect linear combinations{p_end}
{pmore}Detected derived variables are excluded from synthesis and reconstructed
from their base variables afterward, perfectly preserving the relationship.

{phang}
{opt conditionalcat} detects strongly associated categorical variables using
Cramér's V (V > 0.5) and synthesizes them jointly to preserve their association.
This is useful for preserving relationships like region-country,
diagnosis-treatment, or department-job_title.

{dlgtab:Panel/Longitudinal}

{phang}
{opt panel(id time)} specifies panel structure with {it:id} as the panel
identifier and {it:time} as the time variable. Preserves the number of
observations per unit and within-unit correlation.

{phang}
{opt preservevar(varlist)} specifies variables that should remain constant
within panel units (e.g., sex, birth date).

{phang}
{opt autocorr(#)} preserves autocorrelation structure up to # lags.

{dlgtab:Privacy/Disclosure Control}

{phang}
{opt mincell(#)} provides rare category protection. Categories with fewer
than # observations are pooled or suppressed. Default is 5.

{phang}
{opt trim(#)} trims extreme values at the #th and (100-#)th percentiles
before synthesis.

{phang}
{opt bounds(spec)} enforces minimum and maximum bounds on output. Specify
as {it:varname min max}, e.g., {cmd:bounds("age 0 120")}.

{phang}
{opt noextreme} prevents synthetic values from falling outside the observed
range in the original data.

{dlgtab:Validation/Diagnostics}

{phang}
{opt compare} produces a comparison report showing means, standard deviations,
and correlations for original versus synthetic data.

{phang}
{opt validate(filename)} saves detailed validation statistics to {it:filename}.

{phang}
{opt utility} computes utility metrics such as pMSE (propensity score mean
squared error).

{phang}
{opt graph} produces overlay density plots comparing original and synthetic
distributions for continuous variables.

{dlgtab:Technical}

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt iterate(#)} specifies the maximum number of iterations for constraint
satisfaction. Default is 100.

{phang}
{opt tolerance(#)} specifies the convergence tolerance for iterative
procedures. Default is 1e-6.


{marker methods}{...}
{title:Methods and Formulas}

{pstd}
{bf:Parametric method}

{pstd}
The parametric method proceeds as follows:

{phang2}1. Classify variables as continuous, categorical, or date.{p_end}
{phang2}2. Estimate the mean vector and covariance matrix for continuous variables.{p_end}
{phang2}3. Generate multivariate normal draws using Cholesky decomposition.{p_end}
{phang2}4. Optionally transform marginals to match empirical distributions.{p_end}
{phang2}5. Draw categorical values from observed frequencies.{p_end}
{phang2}6. Apply constraints via rejection sampling or adjustment.{p_end}

{pstd}
{bf:Sequential method}

{pstd}
The sequential method:

{phang2}1. Order variables (by missingness or user specification).{p_end}
{phang2}2. For each variable, fit a regression on preceding variables.{p_end}
{phang2}3. Draw from the predictive distribution (point estimate + random residual).{p_end}

{pstd}
{bf:Bootstrap method}

{pstd}
The bootstrap method:

{phang2}1. Sample rows with replacement.{p_end}
{phang2}2. Add Gaussian noise to continuous variables.{p_end}
{phang2}3. Optionally perturb categorical values with small probability.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Smart synthesis (recommended for most realistic output){p_end}
{phang2}{cmd:. synthdata, smart saving(synthetic_patients)}{p_end}

{pstd}Basic usage: synthesize current dataset and save{p_end}
{phang2}{cmd:. synthdata, saving(synthetic_patients)}{p_end}

{pstd}Generate 10,000 synthetic observations, replacing current data{p_end}
{phang2}{cmd:. synthdata, n(10000) replace}{p_end}

{pstd}Parametric with auto-detection of non-normal distributions{p_end}
{phang2}{cmd:. synthdata, autoempirical saving(synth_adaptive)}{p_end}

{pstd}Preserve derived variables and categorical associations{p_end}
{phang2}{cmd:. synthdata, autorelate conditionalcat saving(synth_relations)}{p_end}

{pstd}Sequential method with panel structure{p_end}
{phang2}{cmd:. synthdata, sequential panel(patient_id visit_num) saving(synth_panel)}{p_end}

{pstd}Synthesize with ID handling and auto-detected constraints{p_end}
{phang2}{cmd:. synthdata, id(patient_id) autoconstraints saving(synth_safe)}{p_end}

{pstd}Generate 5 synthetic datasets for multiple imputation-style analysis{p_end}
{phang2}{cmd:. synthdata, multiple(5) saving(synth_m)}{p_end}

{pstd}Bootstrap with perturbation and comparison to original{p_end}
{phang2}{cmd:. synthdata, bootstrap noise(0.15) compare}{p_end}

{pstd}Selective synthesis of sensitive financial variables only{p_end}
{phang2}{cmd:. synthdata income assets debt, saving(synth_financial)}{p_end}

{pstd}Synthesis with explicit constraints{p_end}
{phang2}{cmd:. synthdata, constraints("age>=0" "age<=120" "hire_date<=term_date") saving(synth_hr)}{p_end}

{pstd}Reproducible synthesis with seed{p_end}
{phang2}{cmd:. synthdata, n(5000) seed(12345) saving(synth_reproducible)}{p_end}

{pstd}Synthesize with validation output{p_end}
{phang2}{cmd:. synthdata, saving(synth) validate(synth_validation) compare}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:synthdata} does not store results in {cmd:r()} or {cmd:e()}.


{marker limitations}{...}
{title:Limitations}

{pstd}
Users should be aware of the following limitations:

{phang2}- High-dimensional categorical interactions are difficult to preserve perfectly.{p_end}
{phang2}- Rare combinations may not appear in synthetic data.{p_end}
{phang2}- Complex nonlinear relationships may be attenuated.{p_end}
{phang2}- Synthetic data is {bf:not} a disclosure-proof guarantee; there is always
a utility/privacy tradeoff.{p_end}
{phang2}- The sequential method may be slow for datasets with many variables.{p_end}
{phang2}- Panel structure preservation is simplified in this version.{p_end}


{marker author}{...}
{title:Author}

{pstd}
Synthetic data generation command for Stata.
{p_end}

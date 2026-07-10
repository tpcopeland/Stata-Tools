{smcl}
{* *! version 1.2.0  30jun2026}{...}
{vieweralsosee "[R] fvvarlist" "help fvvarlist"}{...}
{vieweralsosee "[R] regress" "help regress"}{...}
{vieweralsosee "[D] label" "help label"}{...}
{viewerjumpto "Syntax" "fvgen##syntax"}{...}
{viewerjumpto "Description" "fvgen##description"}{...}
{viewerjumpto "Options" "fvgen##options"}{...}
{viewerjumpto "Remarks" "fvgen##remarks"}{...}
{viewerjumpto "Examples" "fvgen##examples"}{...}
{viewerjumpto "Stored results" "fvgen##results"}{...}
{viewerjumpto "Author" "fvgen##author"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:fvgen} {hline 2}}Flatten factor-variable interactions into labeled main and product variables{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:fvgen}
{it:fvvarlist}
{ifin}
{weight}
[{cmd:,}
{it:options}]

{pstd}
{it:fvvarlist} is a {help fvvarlist:factor-variable varlist} using the usual
{cmd:i.}, {cmd:c.}, {cmd:#}, and {cmd:##} operators, for example
{cmd:i.group##c.age} or {cmd:i.arm##i.sex}. By design {cmd:fvgen} targets the
common case — main effects and up to two-way interactions; higher-order
(three-way and beyond) terms are deliberately out of scope and are rejected with
a clear message rather than silently flattened.

{pstd}
Remove every variable a previous run generated:

{p 8 16 2}
{cmd:fvgen}{cmd:,} {opt drop}

{pstd}
Rebuild the active flattened estimation result with native factor-variable
syntax for {helpb margins}:

{p 8 16 2}
{cmd:fvgen}{cmd:,} {opt margins} [{opt stor:e(name)} {opt replace}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt all:levels}}materialize every level, base included{p_end}
{synopt:{opt center}}mean-center continuous terms before forming products{p_end}
{synopt:{opt ref(spec)}}set the reference (base) level per factor{p_end}
{synopt:{opt simp:le(varname)}}per-group slopes within levels of {it:varname}{p_end}
{synopt:{opt vsr:ef(string)}}append the reference level to main-effect labels{p_end}
{synopt:{opt pre:fix(name)}}prefix for generated variable names; default is {cmd:_}{p_end}
{synopt:{opt replace}}overwrite generated variables that already exist{p_end}
{synopt:{opt xsym:bol(string)}}symbol joining interaction labels; default is {cmd:×}{p_end}
{synopt:{opt drop}}drop every fvgen-generated variable in the dataset{p_end}
{syntab:Postestimation}
{synopt:{opt margins}}refit with native factor syntax for {cmd:margins}{p_end}
{synopt:{opt stor:e(name)}}with {opt margins}, store the clone as {it:name}{p_end}
{synoptline}
{p2colreset}{...}

{p 4 6 2}
{cmd:aweight}s, {cmd:fweight}s, {cmd:pweight}s, and {cmd:iweight}s are allowed
and are used only by {opt center} (the centering mean is weighted); see
{help weight}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:fvgen} expands a factor-variable interaction specification into ordinary
variables: an indicator variable for each categorical level (the base level is
dropped by default) and a product variable for each interaction term. Value
labels become variable labels, so a level coded {cmd:2} with value label
{cmd:"Female"} produces a variable labeled {cmd:Female}, and the interaction of
{cmd:Female} with {cmd:age} produces a variable labeled {cmd:Female × Age}.

{pstd}
The motivation is friendlier export. Estimating with native factor-variable
notation ({cmd:regress y i.sex##c.age}) makes table commands emit extra
factor-variable header rows for each interaction. Running the same model on the
flattened variables produced by {cmd:fvgen} yields one clean, self-labeled
row per coefficient. The reparameterization is exact: a regression on the
flattened variables reproduces the native model's coefficients and fit.

{pstd}
Why not just relabel the coefficients inside an export tool? Tools such as
{helpb estout:esttab}'s {cmd:varlabels()} or {helpb collect}/{helpb etable}'s
relabeling let you rename rows, but you must spell out a label for each
interaction term, and the renaming is local to that one tool. {cmd:fvgen} works
at the {it:variable} level instead: it reads each factor's value labels and
builds the row labels automatically (level {cmd:2 "Female"} interacted with
{cmd:age} becomes {cmd:Female × Age}), and because the result is ordinary
labeled variables those labels flow through {it:any} downstream consumer —
{helpb collect}, {helpb estout:esttab}, {helpb putexcel}, the
{help tabtools:tabtools} family, or a hand-built table — with no per-tool
relabeling.

{pstd}
The generated variable names and a combined varlist ready for an estimation
command are returned in {cmd:r()}. A typical workflow is:

{phang2}{cmd:. fvgen i.sex##c.age}{p_end}
{phang2}{cmd:. regress wage `r(allvars)'}{p_end}

{pstd}
Indicator and product variables are stored in {cmd:double} precision and are set
to missing wherever any source variable is missing. The {cmd:if}/{cmd:in}
qualifier restricts which categorical levels and interaction cells are
materialized (empty cells in the restricted sample are skipped, matching what
the corresponding model would estimate); the generated variables themselves are
filled for all observations so they can be reused.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt alllevels} materializes an indicator for every categorical level, including
the base level. By default the base level is dropped, mirroring factor-variable
behavior and avoiding collinearity in a subsequent regression. {cmd:alllevels}
applies to main-effect indicators; interaction terms always use the estimable
(non-base, non-empty) cells.

{phang}
{opt center} mean-centers each continuous term over the {cmd:if}/{cmd:in} sample
before it enters main effects and products, which keeps lower-order coefficients
interpretable at the mean. A centered copy named {it:prefix}{it:var}{cmd:_c} is
created and reused across terms. When a {help weight:weight} is supplied the
centering mean is weighted (a {cmd:pweight} is treated as an {cmd:aweight} for
the mean, which is numerically identical). Centering shifts where the
lower-order coefficients are anchored but leaves the interaction coefficient and
the model fit unchanged, so the exact-reparameterization guarantee holds for any
centering constant.

{phang}
{opt ref(spec)} sets the reference (base) level for one or more factor variables,
given as variable/level pairs with optional commas: {cmd:ref(sex 2, race 3)} makes
{cmd:sex==2} and {cmd:race==3} the base levels, so those levels are dropped and every
other level (and its interactions) is expressed relative to them. A level may
be given as an integer code or as a {it:value-label string} in quotes, so
{cmd:ref(foreign "Domestic")} and {cmd:ref(foreign 0)} are equivalent when {cmd:0} is labeled
{cmd:"Domestic"}. Each named variable must appear as a factor in the specification,
and each level must be observed in the {cmd:if}/{cmd:in} sample. This is equivalent to
writing {cmd:ibN.} operators in the varlist ({cmd:ib2.sex##ib3.race}); the option is a
convenience for setting bases without rewriting the specification, and it does
not alter any {help fvset:fvset} settings on your data.

{phang}
{opt simple(varname)} reports the effect of each continuous term that interacts
with {it:varname} as a separate {it:per-group} slope within every level of
{it:varname}, combining the main effect and the interaction into one standalone
coefficient per group, rather than a reference slope plus a difference. For
{cmd:fvgen i.sex##c.age, simple(sex)} the result is one age slope per sex
level (labeled {cmd:Age (Male)}, {cmd:Age (Female)}, ...), the plain {cmd:age}
main effect is dropped, and the {cmd:sex} indicators remain as the group
intercepts. This is the nested {cmd:i.sex i.sex#c.age} parameterization; a
regression on the result reproduces the model fit and yields each group's slope
directly. {it:varname} must be a factor that interacts with at least one
continuous term; for categorical-by-categorical simple effects use
{helpb margins} or {helpb contrast}.

{phang}
{opt vsref(string)} appends the reference (base) level to the label of each
categorical {it:main-effect} indicator, so an exported coefficient table shows
what each level is contrasted against. The argument is a template in which the
{cmd:@} character is replaced by the base level's label: {cmd:vsref("(vs. @)")}
labels the {cmd:foreign} indicator {cmd:Foreign (vs. Domestic)}, while
{cmd:vsref("versus @")} yields {cmd:Foreign versus Domestic}. The template must
contain {cmd:@}. The suffix is added to main-effect indicators only — interaction
and continuous-slope labels are left unchanged, and under {opt alllevels} the
base level's own indicator is not suffixed. The reference shown honors any
{opt ref()} base.

{phang}
{opt prefix(name)} sets the prefix for generated variable names. The default is
a single underscore ({cmd:_}). Names that would exceed Stata's 32-character
limit raise an error; choose a shorter prefix or rename the source variables.

{phang}
{opt replace} permits {cmd:fvgen} to overwrite previously generated variables
of the same name. Without it, a name collision is an error. With
{cmd:fvgen, margins store(name)}, {opt replace} first drops an existing stored
estimate named {it:name}, then stores the refreshed margins-ready clone.

{phang}
{opt xsymbol(string)} sets the symbol placed between the two sides of an
interaction label. The default is the multiplication sign {cmd:×}; specify
{cmd:xsymbol(x)} for a plain ASCII label such as {cmd:Female x Age}. A
continuous self-interaction ({cmd:c.age##c.age}) is always labeled with a
superscript two ({cmd:Age²}) regardless of {opt xsymbol()}.

{phang}
{opt drop} removes every variable a previous {cmd:fvgen} run generated. It is used alone —
{cmd:fvgen, drop} — and takes no {it:fvvarlist}. Generated variables are recognized by
their {cmd:fvgen_role} characteristic (see {it:Remarks}), so pass-through originals are
left untouched. The number and names of the dropped variables are returned in
{cmd:r(k_dropped)} and {cmd:r(dropped)}. This completes the create-use-drop loop: run
{cmd:fvgen}, estimate, export, then {cmd:fvgen, drop} before the next model.

{phang}
{opt margins} is a post-estimation bridge used after estimating a flattened
model on the exact varlist returned by {cmd:fvgen}. It reconstructs the native
factor-variable command from {cmd:fvgen}'s provenance and reruns the estimator,
so the estimator itself supplies the hidden factor-variable metadata that
{helpb margins} expects. The active estimate is changed so {helpb margins} can
operate on the original factor variables.

{phang}
{opt store(name)} is used with {opt margins}. Instead of leaving the native
clone active, {cmd:fvgen} stores the margins-ready clone as {it:name} and
restores the active flattened result. This is the safest workflow when the same
model will be exported by {help tabtools:regtab}: run {cmd:regtab} from the
flattened estimate, then {cmd:estimates restore} the stored clone before running
{cmd:margins}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Variable naming.} Indicator variables are named {it:prefix}{it:var}{cmd:_}{it:level}
(for example {cmd:_sex_2}). Interaction variables are named
{it:prefix}{it:var1}{cmd:X}{it:var2} followed by an underscore and the level of
each categorical side (for example {cmd:_sexXrace_2_3}); continuous sides
contribute no level suffix.

{pstd}
{bf:Exact reparameterization.} Because the flattened variables span the same
column space as the native factor-variable design (over the estimation sample),
{cmd:regress y `r(allvars)'} returns the same coefficients, standard errors, and
R-squared as the corresponding {cmd:regress y} model in factor-variable
notation. Centering a continuous term shifts the lower-order coefficients but
leaves the interaction coefficient and the model fit unchanged.

{pstd}
{bf:Postestimation for margins.} The flattened model has no factor-variable
structure by default: to Stata {cmd:_foreign_1} and {cmd:_foreignXmpg_1} are
ordinary continuous regressors, not {cmd:i.foreign} and its interaction. After a
flattened model, {cmd:fvgen, margins} rebuilds the estimator command with the
original {cmd:i.}/{cmd:c.} specification and reruns it quietly. This lets
{helpb margins} use the estimator's own factor-variable metadata, including
base levels in {cmd:at()}. The QA suite checks both margins estimates and their
variance matrices across linear, GLM, binary, count, censored, ordered,
multinomial, panel, and survey estimators. Use
{cmd:fvgen, margins store(name)} to store a margins-ready
clone while restoring the active flattened result for clean
{help tabtools:regtab} or other table export. The active model must have been
fit with the exact varlist returned by {cmd:fvgen}; if you reorder or hand-edit
that varlist, rerun the model first. The bridge is not available after
{opt center}, and any estimator that cannot be rerun from its saved command
line, or that does not support factor variables with {cmd:margins}, should be
fit natively. Other factor-aware tools such as {helpb contrast} and
{helpb pwcompare} should use the native {cmd:i.}/{cmd:c.} model directly. Only
up to two-way interactions are supported (see {help fvgen##syntax:Syntax}).

{pstd}
{bf:Provenance characteristics.} Every generated variable carries two
characteristics so downstream tools can recognize and group
it: {cmd:char }{it:var}{cmd:[fvgen_role]} is {cmd:main}, {cmd:interaction}, or {cmd:centered}, and
{cmd:char }{it:var}{cmd:[fvgen_term]} records the factor-variable term it came from (for
example {cmd:1.foreign#c.mpg}). {cmd:fvgen, drop} uses {cmd:fvgen_role} to identify exactly the
variables it created.

{pstd}
{bf:No-base factors.} A no-base specification ({cmd:ibn.}{it:var}) materializes
an indicator for every level of {it:var}, equivalent to requesting
{opt alllevels} for that factor. The explicit {help fvvarlist:omit} operator
({cmd:o.}, {cmd:}{it:#}{cmd:o.}) is not supported and is rejected with a clear
message; restrict the sample with {cmd:if}/{cmd:in} or set a base with
{opt ref()} instead.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup}{p_end}
{phang2}{stata "sysuse auto, clear":. sysuse auto, clear}{p_end}
{phang2}{stata "label define rl 1 \"Poor\" 2 \"Fair\" 3 \"Avg\" 4 \"Good\" 5 \"Best\"":. label define rl 1 "Poor" 2 "Fair" 3 "Avg" 4 "Good" 5 "Best"}{p_end}
{phang2}{stata "label values rep78 rl":. label values rep78 rl}{p_end}

{pstd}
{bf:Example 1: Categorical-by-continuous interaction}{p_end}
{phang2}{stata "fvgen i.foreign##c.mpg":. fvgen i.foreign##c.mpg}{p_end}
{phang2}{stata "regress price `r(allvars)'":. regress price `r(allvars)'}{p_end}

{pstd}
{bf:Example 2: Categorical-by-categorical interaction}{p_end}
{phang2}{stata "fvgen i.foreign##i.rep78, replace":. fvgen i.foreign##i.rep78, replace}{p_end}
{phang2}{stata "regress price `r(allvars)'":. regress price `r(allvars)'}{p_end}

{pstd}
{bf:Example 3: Continuous-by-continuous interaction, centered}{p_end}
{phang2}{stata "fvgen c.mpg##c.weight, center replace":. fvgen c.mpg##c.weight, center replace}{p_end}
{phang2}{stata "regress price `r(allvars)'":. regress price `r(allvars)'}{p_end}

{pstd}
{bf:Example 4: Keep all levels, ASCII interaction symbol}{p_end}
{phang2}{stata "fvgen i.foreign##i.rep78, alllevels xsymbol(x) replace":. fvgen i.foreign##i.rep78, alllevels xsymbol(x) replace}{p_end}

{pstd}
{bf:Example 5: Choose a different reference level per factor}{p_end}
{phang2}{stata "fvgen i.foreign##i.rep78, ref(rep78 3) replace":. fvgen i.foreign##i.rep78, ref(rep78 3) replace}{p_end}
{phang2}{stata "regress price `r(allvars)'":. regress price `r(allvars)'}{p_end}

{pstd}
{bf:Example 6: Per-group slopes (simple effects)}{p_end}
{phang2}{stata "fvgen i.foreign##c.mpg, simple(foreign) replace":. fvgen i.foreign##c.mpg, simple(foreign) replace}{p_end}
{phang2}{stata "regress price `r(allvars)'":. regress price `r(allvars)'}{p_end}

{pstd}
{bf:Example 7: Reference level by value-label string, then tear down}{p_end}
{phang2}{stata "fvgen i.foreign##c.mpg, ref(foreign \"Domestic\") replace":. fvgen i.foreign##c.mpg, ref(foreign "Domestic") replace}{p_end}
{phang2}{stata "fvgen, drop":. fvgen, drop}{p_end}

{pstd}
{bf:Example 8: Show the reference level in main-effect labels}{p_end}
{phang2}{stata "fvgen i.foreign##i.rep78, vsref(\"(vs. @)\") replace":. fvgen i.foreign##i.rep78, vsref("(vs. @)") replace}{p_end}
{phang2}{stata "regress price `r(allvars)'":. regress price `r(allvars)'}{p_end}

{pstd}
{bf:Example 9: Margins after a flattened regression}{p_end}
{phang2}{stata "fvgen i.foreign##c.mpg, replace":. fvgen i.foreign##c.mpg, replace}{p_end}
{phang2}{stata "regress price `r(allvars)'":. regress price `r(allvars)'}{p_end}
{phang2}{stata "fvgen, margins store(m_price)":. fvgen, margins store(m_price)}{p_end}
{phang2}{stata "estimates restore m_price":. estimates restore m_price}{p_end}
{phang2}{stata "margins, dydx(mpg) at(foreign=(0 1))":. margins, dydx(mpg) at(foreign=(0 1))}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:fvgen} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(k_all)}}number of variables in {cmd:r(allvars)}{p_end}
{synopt:{cmd:r(k_main)}}number of main-effect variables{p_end}
{synopt:{cmd:r(k_int)}}number of interaction variables{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(spec)}}expanded factor-variable specification, with {opt ref()} bases{p_end}
{synopt:{cmd:r(allvars)}}all model variables, ordered for estimation{p_end}
{synopt:{cmd:r(mainvars)}}main-effect variables only{p_end}
{synopt:{cmd:r(intvars)}}interaction variables only{p_end}
{synopt:{cmd:r(genvars)}}newly created variables (excludes pass-through originals){p_end}

{pstd}
With {opt drop}, {cmd:fvgen} instead stores:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(k_dropped)}}number of variables dropped{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(dropped)}}names of the dropped variables{p_end}

{pstd}
With {opt margins}, {cmd:fvgen} stores:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(margins)}}{cmd:active} if estimates were rebuilt, else {cmd:stored}{p_end}
{synopt:{cmd:r(stored)}}stored estimate name, when {opt store()} was used{p_end}

{pstd}
The margins-ready estimation result is also marked internally as an
{cmd:fvgen} margins clone and records the flattened and native command lines.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}
{pstd}Version 1.2.0, 2026-06-30{p_end}


{title:Also see}

{psee}
Manual: {manlink R fvvarlist}, {manlink R regress}, {manlink D label}

{psee}
Online: {helpb fvvarlist}, {helpb regress}, {helpb label}

{hline}

{smcl}
{* *! version 1.3.5  28feb2026}{...}
{viewerjumpto "Syntax" "treescan##syntax"}{...}
{viewerjumpto "Description" "treescan##description"}{...}
{viewerjumpto "Options" "treescan##options"}{...}
{viewerjumpto "Remarks" "treescan##remarks"}{...}
{viewerjumpto "Examples" "treescan##examples"}{...}
{viewerjumpto "Stored results" "treescan##results"}{...}
{viewerjumpto "References" "treescan##references"}{...}
{viewerjumpto "Author" "treescan##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:treescan} {hline 2}}Tree-based scan statistic for signal detection{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{pstd}
Using a built-in tree:

{p 8 17 2}
{cmd:treescan}
{it:diagvar}
{cmd:,}
{opt id(varname)}
{opt exp:osed(varname)}
{opt icdv:ersion(cm|se|atc)}
[{it:options}]

{pstd}
Using a custom tree:

{p 8 17 2}
{cmd:treescan}
{it:diagvar}
{opt using} {it:treefile.dta}
{cmd:,}
{opt id(varname)}
{opt exp:osed(varname)}
[{it:options}]


{synoptset 34 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person/unit identifier{p_end}
{synopt:{opt exp:osed(varname)}}binary exposure/case variable (0/1){p_end}
{synopt:{opt icdv:ersion(cm|se|atc)}}built-in tree: {bf:cm} (ICD-10-CM), {bf:se} (ICD-10-SE), or {bf:atc} (ATC drug codes){p_end}

{syntab:Model}
{synopt:{opt mod:el(string)}}statistical model: {bf:bernoulli} (default) or {bf:poisson}{p_end}
{synopt:{opt persont:ime(varname)}}person-time variable; required with {cmd:model(poisson)}{p_end}
{synopt:{opt cond:itional}}use conditional (permutation) test instead of unconditional (resampling){p_end}

{syntab:Temporal scan window}
{synopt:{opt eventd:ate(varname)}}date of diagnosis event{p_end}
{synopt:{opt expd:ate(varname)}}date of exposure onset{p_end}
{synopt:{opt wind:ow(# #)}}risk window bounds in days (lower upper){p_end}
{synopt:{opt windows:cope(string)}}apply window filter to {bf:exposed} (default) or {bf:all} individuals{p_end}

{syntab:Optional}
{synopt:{opt nsim(#)}}number of Monte Carlo simulations; default is {cmd:nsim(999)}{p_end}
{synopt:{opt alph:a(#)}}significance level for display; default is {cmd:alpha(0.05)}{p_end}
{synopt:{opt seed(#)}}random number seed for reproducibility{p_end}
{synopt:{opt noi:sily}}display progress during simulation{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
Either {opt icdversion()} or {opt using} must be specified, but not both.


{marker description}{...}
{title:Description}

{pstd}
{cmd:treescan} implements the tree-based scan statistic (Kulldorff et al., 2003)
for detecting excess risk across nodes in a hierarchical tree structure.
It simultaneously evaluates all nodes in the tree, adjusting for multiple
comparisons via Monte Carlo simulation.

{pstd}
The method is widely used in pharmacovigilance and vaccine safety surveillance
to detect unexpected adverse events among exposed individuals. Given a dataset
of individuals with diagnosis codes and a binary exposure, {cmd:treescan}
identifies diagnosis codes (and their ancestor groups) where exposed individuals
have significantly higher rates than expected.

{pstd}
Four model variants are available:

{phang2}{bf:Bernoulli unconditional} (default): Each individual is classified
as exposed or unexposed. Under the null, exposure labels are resampled with
probability p = N_exposed/N_total. The total number of exposed may vary across
simulations.

{phang2}{bf:Bernoulli conditional}: Same LLR formula as unconditional, but
under the null, exactly N_exposed labels are randomly permuted among all
individuals. The total exposed is fixed in every simulation.

{phang2}{bf:Poisson unconditional}: Each individual has binary case status
and person-time. Under the null, case labels are resampled with probability
C/N. The total number of cases may vary.

{phang2}{bf:Poisson conditional}: Same LLR formula, but exactly C case labels
are permuted among all individuals. The total cases are fixed.

{pstd}
The algorithm:

{phang2}1. Maps each diagnosis code to all of its ancestor nodes in the tree
(e.g., A000 maps to A000, A00, A00-A09, Chapter 01, and the root).

{phang2}2. Computes the log-likelihood ratio (LLR) at each node, measuring
excess risk.

{phang2}3. Runs Monte Carlo simulations under the null hypothesis to obtain the
distribution of the maximum LLR.

{phang2}4. Computes p-values by comparing each node's observed LLR to the
distribution of simulated maximum LLRs.

{pstd}
{cmd:treescan} ships with built-in ICD-10-CM (US), ICD-10-SE (Swedish), and
ATC (WHO drug classification) tree hierarchies, or you can supply a custom
tree via {opt using}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt id(varname)} specifies the variable identifying individuals. Each
individual may have multiple observations (one per diagnosis code).

{phang}
{opt exposed(varname)} specifies a binary (0/1) variable indicating exposure
status (Bernoulli model) or case status (Poisson model).
Should be constant within each individual. If exposure varies within
an individual, the maximum is used (ever exposed = exposed) and a
note is displayed.

{phang}
{opt icdversion(cm|se|atc)} specifies which built-in tree to use.
{bf:cm} uses the ICD-10-CM (Clinical Modification, US) tree based on FY2025
codes from CDC/CMS. {bf:se} uses the ICD-10-SE (Swedish) tree from
Socialstyrelsen. {bf:atc} uses the WHO ATC (Anatomical Therapeutic Chemical)
drug classification tree. Not required if {opt using} is specified.

{dlgtab:Model}

{phang}
{opt model(string)} specifies the statistical model. {bf:bernoulli} (default)
uses the Bernoulli model where exposed() indicates exposure
status. {bf:poisson} uses the Poisson model where exposed()
indicates case status and {opt persontime()} provides follow-up time.

{phang}
{opt persontime(varname)} specifies the person-time variable for the Poisson
model. Required when {cmd:model(poisson)} is specified. Must be a positive
numeric variable. Person-time is summed within each individual (if multiple
records exist) before analysis.

{phang}
{opt conditional} specifies that the conditional (permutation-based) test
should be used instead of the unconditional (resampling-based) test.
Under the conditional null, the total number of exposed individuals
(Bernoulli) or cases (Poisson) is held fixed at the observed value in
every simulation. This can provide better type I error control when the
number of exposed/cases is small.

{dlgtab:Temporal scan window}

{phang}
{opt eventdate(varname)} specifies a numeric (date) variable containing the
date of each diagnosis event. Required with {opt expdate()} and {opt window()}.

{phang}
{opt expdate(varname)} specifies a numeric (date) variable containing the date
of exposure onset. Required with {opt eventdate()} and {opt window()}.

{phang}
{opt window(# #)} specifies the risk window as two numbers: the lower and upper
bounds in days relative to exposure onset. For example, {cmd:window(0 30)}
restricts analysis to events occurring 0 to 30 days after exposure.
Negative values allow pre-exposure events (e.g., {cmd:window(-7 30)}).

{phang}
{opt windowscope(string)} specifies whether the temporal window filter applies
to {bf:exposed} individuals only (default) or to {bf:all} individuals.
When {cmd:windowscope(exposed)}, unexposed individuals' events are kept
regardless of timing. When {cmd:windowscope(all)}, all events outside the
window are dropped.

{dlgtab:Optional}

{phang}
{opt nsim(#)} specifies the number of Monte Carlo simulations for p-value
computation. Default is {cmd:999}. More simulations give more precise p-values
but take longer. Use {cmd:nsim(9999)} for publication-quality results.

{phang}
{opt alpha(#)} specifies the significance level for determining which nodes
to display in the results table. Default is {cmd:0.05}. Nodes with p-value
less than {opt alpha} are shown.

{phang}
{opt seed(#)} sets the random number seed before simulation, ensuring
reproducibility.

{phang}
{opt noisily} displays progress messages during the Monte Carlo simulation,
showing the current iteration number every 100 iterations.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Conditional vs. unconditional models}

{pstd}
The unconditional model resamples exposure (or case) labels independently for
each individual under the null hypothesis. This means the total number of
exposed individuals varies across simulations. The conditional model instead
permutes the labels, so the total exposed count is always exactly equal to
the observed value.

{pstd}
Both models use the same LLR formula. The difference is only in the null
distribution used to compute p-values. The conditional test is generally
preferred when:

{phang2}- The number of exposed individuals (or cases) is small{p_end}
{phang2}- You want to condition on the observed marginal totals{p_end}
{phang2}- The exposure proportion is very low or very high{p_end}

{pstd}
{bf:Temporal scan windows}

{pstd}
When {opt eventdate()}, {opt expdate()}, and {opt window()} are specified,
only events occurring within the risk window are included. This is standard
in pharmacovigilance for detecting acute adverse events following exposure.

{pstd}
The window is defined as days from exposure: event_date - exposure_date.
Events outside the range [{it:lower}, {it:upper}] are dropped before analysis.

{pstd}
With {cmd:windowscope(exposed)} (the default), only exposed individuals'
events are filtered; unexposed events are retained regardless. With
{cmd:windowscope(all)}, events outside the window are dropped for everyone.

{pstd}
{bf:Custom trees}

{pstd}
A custom tree file must be a Stata dataset (.dta) containing at minimum
the variables:

{p2colset 8 20 22 2}{...}
{p2col:{bf:node}}string variable with the node identifier{p_end}
{p2col:{bf:parent}}string variable with the parent node identifier (empty for root){p_end}
{p2col:{bf:level}}numeric variable indicating hierarchy depth (0 = root){p_end}

{pstd}
{bf:Performance}

{pstd}
Runtime scales linearly with {opt nsim()} and with the number of unique
(individual, node) pairs after tree cutting. For large ICD-10-CM trees
(~98,000 nodes) with thousands of individuals and {cmd:nsim(999)}, expect
runtime of several minutes. Use {opt noisily} to monitor progress.

{pstd}
{bf:Subsetting data}

{pstd}
{cmd:treescan} does not accept {opt if} or {opt in} qualifiers. To restrict
analysis to a subset of observations, subset your data before calling
{cmd:treescan} (e.g., {cmd:keep if age >= 18}).

{pstd}
{bf:Bernoulli unconditional model}

{pstd}
Under the Bernoulli unconditional model, the null hypothesis is that the
probability of exposure is the same (p = n_exposed/n_total) for all
individuals regardless of their diagnoses. The test statistic is the
log-likelihood ratio:

{pmore}
LLR = n1*ln(q1) + n0*ln(1-q1) - n1*ln(p) - n0*ln(1-p)

{pstd}
where n1 and n0 are the exposed and unexposed counts at a node, q1 = n1/(n0+n1)
is the observed exposure proportion at the node, and p is the global exposure
proportion. The LLR is set to zero when q1 <= p (no excess risk).

{pstd}
{bf:Poisson unconditional model}

{pstd}
Under the Poisson unconditional model, each individual has binary case status
(exposed() = 1 for cases) and person-time of follow-up. The global rate is
lambda = C / T_total (total cases divided by total person-time). At each node:

{pmore}
LLR = c*ln(c/E) + (C-c)*ln((C-c)/(C-E))

{pstd}
where c is the observed number of cases at the node, E = T_node * (C/T_total)
is the expected number of cases based on person-time, C is the total number
of cases, and T_node is the total person-time at the node. The LLR is set to
zero when c <= E (no excess risk).

{pstd}
Monte Carlo simulation under the Poisson null randomly assigns case status
to individuals with probability C/N, then recomputes the maximum LLR.

{pstd}
{bf:ATC drug classification}

{pstd}
The WHO ATC (Anatomical Therapeutic Chemical) classification organizes drugs
into a 5-level hierarchy based on their therapeutic use and chemical properties.
The built-in ATC tree contains ~6,800 nodes:

{p2colset 8 25 27 2}{...}
{p2col:{bf:Level 1 (1 char)}}Anatomical main group (e.g., A = Alimentary tract){p_end}
{p2col:{bf:Level 2 (3 chars)}}Therapeutic subgroup (e.g., A01 = Stomatological){p_end}
{p2col:{bf:Level 3 (4 chars)}}Pharmacological subgroup (e.g., A01A){p_end}
{p2col:{bf:Level 4 (5 chars)}}Chemical subgroup (e.g., A01AA){p_end}
{p2col:{bf:Level 5 (7 chars)}}Chemical substance (e.g., A01AA01 = sodium fluoride){p_end}

{pstd}
Use {cmd:icdversion(atc)} to scan across drug classes for adverse event signals.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Bernoulli unconditional (default)}

{phang2}{stata "treescan diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm)":. treescan diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm)}{p_end}

{pstd}
{bf:Example 2: Bernoulli conditional}

{phang2}{stata "treescan diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm) conditional":. treescan diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm) conditional}{p_end}

{pstd}
{bf:Example 3: With seed and more simulations}

{phang2}{stata "treescan diagcode, id(patient_id) exposed(vaccinated) icdversion(cm) nsim(9999) seed(12345)":. treescan diagcode, id(patient_id) exposed(vaccinated) icdversion(cm) nsim(9999) seed(12345)}{p_end}

{pstd}
{bf:Example 4: ICD-10-SE tree}

{phang2}{stata "treescan diagnos, id(lopnr) exposed(treated) icdversion(se) nsim(999) seed(42)":. treescan diagnos, id(lopnr) exposed(treated) icdversion(se) nsim(999) seed(42)}{p_end}

{pstd}
{bf:Example 5: Custom tree}

{phang2}{stata "treescan atc_code using my_drug_tree.dta, id(patient_id) exposed(case)":. treescan atc_code using my_drug_tree.dta, id(patient_id) exposed(case)}{p_end}

{pstd}
{bf:Example 6: ATC drug classification tree}

{phang2}{stata "treescan atc_code, id(patient_id) exposed(case) icdversion(atc) nsim(999) seed(42)":. treescan atc_code, id(patient_id) exposed(case) icdversion(atc) nsim(999) seed(42)}{p_end}

{pstd}
{bf:Example 7: Poisson model with person-time}

{phang2}{stata "treescan diagcode, id(patient_id) exposed(case) persontime(pyears) model(poisson) icdversion(cm) seed(42)":. treescan diagcode, id(patient_id) exposed(case) persontime(pyears) model(poisson) icdversion(cm) seed(42)}{p_end}

{pstd}
{bf:Example 8: Poisson conditional model}

{phang2}{cmd:. treescan diagcode, id(patient_id) exposed(case) persontime(pyears) model(poisson) conditional icdversion(cm) seed(42)}{p_end}

{pstd}
{bf:Example 9: Temporal scan window — events within 30 days of exposure}

{phang2}{cmd:. treescan diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm) eventdate(diag_date) expdate(rx_date) window(0 30)}{p_end}

{pstd}
{bf:Example 10: Temporal window applied to all individuals}

{phang2}{cmd:. treescan diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm) eventdate(diag_date) expdate(rx_date) window(-7 90) windowscope(all)}{p_end}

{pstd}
{bf:Example 11: Monitor progress}

{phang2}{stata "treescan diagcode, id(pid) exposed(exposed) icdversion(cm) nsim(999) seed(42) noisily":. treescan diagcode, id(pid) exposed(exposed) icdversion(cm) nsim(999) seed(42) noisily}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:treescan} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(max_llr)}}maximum observed log-likelihood ratio{p_end}
{synopt:{cmd:r(p_value)}}Monte Carlo p-value for the maximum LLR{p_end}
{synopt:{cmd:r(n_nodes)}}number of tree nodes evaluated{p_end}
{synopt:{cmd:r(n_obs)}}number of observations used{p_end}
{synopt:{cmd:r(n_exposed)}}number of exposed individuals (Bernoulli) or cases (Poisson){p_end}
{synopt:{cmd:r(n_unexposed)}}number of unexposed individuals (Bernoulli) or non-cases (Poisson){p_end}
{synopt:{cmd:r(nsim)}}number of simulations performed{p_end}
{synopt:{cmd:r(alpha)}}significance level used{p_end}
{synopt:{cmd:r(total_persontime)}}total person-time (Poisson only){p_end}
{synopt:{cmd:r(total_cases)}}total cases (Poisson only){p_end}
{synopt:{cmd:r(window_lo)}}temporal window lower bound (when specified){p_end}
{synopt:{cmd:r(window_hi)}}temporal window upper bound (when specified){p_end}

{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(model)}}model used: {bf:bernoulli} or {bf:poisson}{p_end}
{synopt:{cmd:r(conditional)}}contains {bf:conditional} if conditional test used{p_end}
{synopt:{cmd:r(windowscope)}}window scope: {bf:exposed} or {bf:all} (when specified){p_end}

{p2col 5 25 29 2: Matrices}{p_end}
{synopt:{cmd:r(results)}}matrix of significant nodes (only when significant nodes exist); Bernoulli: (n0, n1, LLR, pvalue); Poisson: (cases, persontime, LLR, pvalue){p_end}


{marker references}{...}
{title:References}

{phang}
Kulldorff M, Fang Z, Walsh SJ. A tree-based scan statistic for database
disease surveillance. {it:Biometrics}. 2003;59(2):323-331.
{browse "https://doi.org/10.1111/1541-0420.00039"}

{phang}
Kulldorff M, Dashevsky I, Avery TR, et al. Drug safety data mining with a
tree-based scan statistic. {it:Pharmacoepidemiology and Drug Safety}.
2013;22(5):517-523.

{phang}
Benjaminsson C, Salomaa S. TreeMineR: Tree-Based Scan Statistics in R.
{browse "https://CRAN.R-project.org/package=TreeMineR"}


{marker author}{...}
{title:Author}

{pstd}Tim Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet, Stockholm{p_end}
{pstd}Version 1.3.5, 2026-02-28{p_end}


{title:Also see}

{psee}
{help treescan_power:treescan_power} — power evaluation for tree-based scan statistic

{psee}
Online: {browse "https://www.treescan.org/":TreeScan software}

{hline}

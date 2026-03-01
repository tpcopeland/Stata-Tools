{smcl}
{* *! version 1.4.0  01mar2026}{...}
{viewerjumpto "Syntax" "treescan_power##syntax"}{...}
{viewerjumpto "Description" "treescan_power##description"}{...}
{viewerjumpto "Options" "treescan_power##options"}{...}
{viewerjumpto "Remarks" "treescan_power##remarks"}{...}
{viewerjumpto "Examples" "treescan_power##examples"}{...}
{viewerjumpto "Stored results" "treescan_power##results"}{...}
{viewerjumpto "Author" "treescan_power##author"}{...}
{title:Title}

{p2colset 5 25 27 2}{...}
{p2col:{cmd:treescan_power} {hline 2}}Power evaluation for tree-based scan statistic{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:treescan_power}
{it:diagvar}
[{opt using} {it:treefile.dta}]
{cmd:,}
{opt id(varname)}
{opt exp:osed(varname)}
{opt tar:get(string)}
{opt rr(#)}
[{it:options}]


{synoptset 34 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt id(varname)}}person/unit identifier{p_end}
{synopt:{opt exp:osed(varname)}}binary exposure/case variable (0/1){p_end}
{synopt:{opt tar:get(string)}}node code where signal is injected{p_end}
{synopt:{opt rr(#)}}relative risk to simulate at target node; must be > 1{p_end}
{synopt:{opt icdv:ersion(cm|se|atc)}}built-in tree (alternative to {opt using}){p_end}

{syntab:Model}
{synopt:{opt mod:el(string)}}statistical model: {bf:bernoulli} (default) or {bf:poisson}{p_end}
{synopt:{opt persont:ime(varname)}}person-time variable; required with {cmd:model(poisson)}{p_end}
{synopt:{opt cond:itional}}use conditional (permutation) test{p_end}

{syntab:Simulation}
{synopt:{opt nsim(#)}}number of null simulations per treescan run; default is {cmd:nsim(999)}{p_end}
{synopt:{opt nsimpow:er(#)}}number of power iterations (outer loop); default is {cmd:nsimpower(500)}{p_end}
{synopt:{opt alph:a(#)}}significance level; default is {cmd:alpha(0.05)}{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt noi:sily}}display progress{p_end}

{syntab:Export}
{synopt:{opt xlsx(filename)}}export results to Excel .xlsx file{p_end}
{synopt:{opt sheet(name)}}sheet name; default {cmd:"Results"}{p_end}
{synopt:{opt title(string)}}title for first row of spreadsheet{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:treescan_power} estimates the statistical power of the tree-based scan
statistic to detect a signal of specified strength (relative risk) at a
target node.

{pstd}
The command uses a simulation-based approach:

{phang2}1. Runs Monte Carlo simulations under the null hypothesis to establish
the critical value (the (1-alpha) quantile of the null max LLR distribution).

{phang2}2. Repeatedly generates data with an injected signal at the target node
(inflating exposure probability by the specified relative risk) and computes
the tree scan statistic.

{phang2}3. Estimates power as the fraction of iterations where the maximum LLR
exceeds the critical value.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt target(string)} specifies the node code in the tree where the signal is
injected. This should be a valid node code (leaf or internal). The code is
matched case-insensitively and dots are stripped (e.g., "A00.0" matches "A000").

{phang}
{opt rr(#)} specifies the relative risk to simulate at the target node. Must
be greater than 1. For the Bernoulli model, individuals with diagnoses at the
target node have their exposure probability multiplied by this factor. For the
Poisson model, the case probability is similarly inflated.

{dlgtab:Model}

{phang}
{opt model(string)} specifies the statistical model. Default is {bf:bernoulli}.
See {help treescan} for model details.

{phang}
{opt persontime(varname)} specifies person-time for the Poisson model.

{phang}
{opt conditional} uses conditional (permutation) test. See {help treescan}.

{dlgtab:Simulation}

{phang}
{opt nsim(#)} specifies the number of Monte Carlo simulations for the null
distribution and critical value calculation. Default is {cmd:999}.

{phang}
{opt nsimpower(#)} specifies the number of power evaluation iterations (outer
loop). Default is {cmd:500}. More iterations give more precise power estimates.

{phang}
{opt alpha(#)} specifies the significance level. Default is {cmd:0.05}.

{phang}
{opt seed(#)} sets the random number seed.

{phang}
{opt noisily} displays progress messages during simulation.

{dlgtab:Export}

{phang}
{opt xlsx(filename)} exports the power evaluation results to an Excel
spreadsheet. The {cmd:.xlsx} extension is appended automatically if omitted.

{phang}
{opt sheet(name)} specifies the worksheet name. Default is {cmd:"Results"}.

{phang}
{opt title(string)} specifies the title placed in the first row. Default is
{cmd:"Tree-Based Scan Power Evaluation"}.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Interpreting results}

{pstd}
Power near 1.0 indicates the scan statistic will reliably detect a signal
of the specified strength at the target node. Power near alpha indicates
the signal is too weak to distinguish from the null.

{pstd}
The 95% confidence interval for power is based on the normal approximation
to the binomial. For extreme power values (near 0 or 1), increase
{opt nsimpower()} for tighter estimates.

{pstd}
{bf:Choosing RR}

{pstd}
Start with a clinically meaningful relative risk. Common choices:

{phang2}- RR = 2: doubling of risk (moderate signal){p_end}
{phang2}- RR = 3-5: strong signal, should be detectable with moderate samples{p_end}
{phang2}- RR = 1.5: small effect, typically requires large samples{p_end}

{pstd}
{bf:Runtime}

{pstd}
Total iterations = nsim (for null distribution) + nsimpower (for power loop).
Each iteration involves resampling and computing LLR across all tree nodes.
For large trees, this can take substantial time. Start with small values
(e.g., {cmd:nsim(99) nsimpower(100)}) to get a rough estimate, then increase
for publication.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic power evaluation}

{phang2}{stata "treescan_power diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm) target(A000) rr(3) seed(42)":. treescan_power diagcode, id(patient_id) exposed(drug_exposed) icdversion(cm) target(A000) rr(3) seed(42)}{p_end}

{pstd}
{bf:Example 2: Custom tree with more iterations}

{phang2}{cmd:. treescan_power diagcode using my_tree.dta, id(pid) exposed(exp) target(A1) rr(5) nsim(999) nsimpower(1000) seed(42)}{p_end}

{pstd}
{bf:Example 3: Poisson conditional model}

{phang2}{cmd:. treescan_power diagcode, id(pid) exposed(case) persontime(pyears) model(poisson) conditional icdversion(cm) target(I21) rr(2) seed(42)}{p_end}

{pstd}
{bf:Example 4: Export power results to Excel}

{phang2}{cmd:. treescan_power diagcode, id(pid) exposed(exp) icdversion(cm) target(A000) rr(3) seed(42) xlsx(power_results)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:treescan_power} stores the following in {cmd:r()}:

{synoptset 25 tabbed}{...}
{p2col 5 25 29 2: Scalars}{p_end}
{synopt:{cmd:r(power)}}estimated power{p_end}
{synopt:{cmd:r(power_ci_lo)}}lower 95% CI for power{p_end}
{synopt:{cmd:r(power_ci_hi)}}upper 95% CI for power{p_end}
{synopt:{cmd:r(crit_val)}}critical LLR value at alpha{p_end}
{synopt:{cmd:r(rr)}}relative risk used{p_end}
{synopt:{cmd:r(nsim)}}number of null simulations{p_end}
{synopt:{cmd:r(nsim_power)}}number of power iterations{p_end}
{synopt:{cmd:r(alpha)}}significance level{p_end}
{synopt:{cmd:r(n_reject)}}number of rejections{p_end}
{synopt:{cmd:r(n_individuals)}}number of unique individuals{p_end}
{synopt:{cmd:r(n_nodes)}}number of tree nodes evaluated{p_end}

{p2col 5 25 29 2: Macros}{p_end}
{synopt:{cmd:r(target)}}target node{p_end}
{synopt:{cmd:r(model)}}model used{p_end}
{synopt:{cmd:r(conditional)}}contains {bf:conditional} if conditional test used{p_end}


{marker author}{...}
{title:Author}

{pstd}Tim Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet, Stockholm{p_end}
{pstd}Version 1.4.0, 2026-03-01{p_end}


{title:Also see}

{psee}
{help treescan:treescan} — tree-based scan statistic for signal detection

{hline}

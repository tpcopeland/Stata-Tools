{smcl}
{viewerjumpto "Package" "simtab##package"}{...}
{viewerjumpto "Syntax" "simtab##syntax"}{...}
{viewerjumpto "Description" "simtab##description"}{...}
{viewerjumpto "Positioning" "simtab##positioning"}{...}
{viewerjumpto "Options" "simtab##options"}{...}
{viewerjumpto "Metrics" "simtab##metrics"}{...}
{viewerjumpto "Ingest mode" "simtab##ingest"}{...}
{viewerjumpto "Output frames" "simtab##frames"}{...}
{viewerjumpto "Examples" "simtab##examples"}{...}
{viewerjumpto "Stored results" "simtab##stored"}{...}
{viewerjumpto "References" "simtab##refs"}{...}
{viewerjumpto "Also see" "simtab##alsosee"}{...}
{viewerjumpto "Author" "simtab##author"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "comptab" "help comptab"}{...}
{title:Title}

{phang}
{bf:simtab} {hline 2} Render and export a publication-ready Monte Carlo simulation performance table

{marker package}{...}
{title:Package}

{pstd}{cmd:simtab} is part of the {helpb tabtools} suite. It owns the last mile
of a simulation study: turning replication-level results -- or an already-computed
summary -- into a styled, exportable, publication-ready performance table with
merged multi-estimand group headers, scenario row grouping, themes, and one-call
Excel / Markdown / CSV / frame output.{p_end}

{pstd}{cmd:simtab} is {bf:not} a Monte Carlo analysis engine. For full performance
analysis, Monte Carlo error theory, and diagnostic graphs (zipper, lollipop,
nested-loop), use {bf:simsum} (White 2010) or {bf:siman} (UCL). {cmd:simtab} can
read their output directly (see {help simtab##ingest:from()}), or compute
table-grade measures itself from replication-level data.{p_end}

{marker syntax}{...}
{title:Syntax}

{pstd}{bf:Compute mode} (default) -- summarize long replication-level results:{p_end}

{p 8 17 2}
{cmd:simtab}
{it:estimator}
{ifin}{cmd:,}
{cmd:est:imate(}{it:varname}{cmd:)}
{cmd:se(}{it:varname}{cmd:)}
{cmd:true(}{it:#}|{it:varname}{cmd:)}
[{it:options}]

{pstd}{bf:Ingest mode} -- render a pre-computed summary already in memory:{p_end}

{p 8 17 2}
{cmd:simtab}{cmd:,}
{cmd:from(}{it:spec}{cmd:)}
[{it:options}]

{marker options}{...}
{synoptset 28 tabbed}{...}
{synopthdr:input (compute mode)}
{synoptline}
{synopt:{opt est:imate(varname)}}replication-level point estimate (required){p_end}
{synopt:{opt se(varname)}}replication-level model-based SE (required){p_end}
{synopt:{opt true(#|varname)}}true parameter value: literal or variable (required){p_end}
{synopt:{opt by(varname)}}scenario / data-generating process (row groups){p_end}
{synopt:{opt estim:and(varname)}}target parameter (column groups){p_end}
{synopt:{opt sim(varname)}}replication identifier (enables duplicate check){p_end}
{synopt:{opt cov:erage(varname)}}pre-computed 0/1 coverage indicator{p_end}
{synopt:{opt lc:i(varname)}}lower CI limit (for coverage){p_end}
{synopt:{opt uc:i(varname)}}upper CI limit (for coverage){p_end}
{synopt:{opt pv:alue(varname)}}replication-level p-value (for power){p_end}
{synopt:{opt rej:ect(varname)}}pre-computed 0/1 rejection indicator (for power){p_end}
{synopt:{opt nsim(#)}}intended replication count per cell (enables non-convergence){p_end}
{synoptline}

{synopthdr:input (ingest mode)}
{synoptline}
{synopt:{opt from(spec)}}{cmd:simsum}, {cmd:siman}, or {cmd:summary}{p_end}
{synopt:{opt byv:ar(name)}}scenario column ({cmd:from(summary)}){p_end}
{synopt:{opt estimatorv:ar(name)}}method column ({cmd:from(summary)}){p_end}
{synopt:{opt estimandv:ar(name)}}target column ({cmd:from(summary)}){p_end}
{synopt:{opt meas:ures(map)}}column mapping, e.g. {cmd:measures(mean=m bias=b n=nr)}{p_end}
{synoptline}

{synopthdr:metrics and computation}
{synoptline}
{synopt:{opt met:rics(tokens)}}metrics to display; default {cmd:mean bias empse meanse coverage n}{p_end}
{synopt:{opt lev:el(#)}}nominal CI level for Wald coverage; default {cmd:95}{p_end}
{synopt:{opt alp:ha(#)}}rejection threshold for power; default {cmd:0.05}{p_end}
{synopt:{opt min:reps(#)}}minimum usable replications per cell; default {cmd:2}{p_end}
{synopt:{opt warn:reps(#)}}low-precision warning threshold; default {cmd:100}{p_end}
{synopt:{opt order(data|sort)}}level ordering; default {cmd:data} (first occurrence){p_end}
{synoptline}

{synopthdr:formatting and output}
{synoptline}
{synopt:{opt dig:its(#)}}decimals for estimate-scale metrics; default 2{p_end}
{synopt:{opt sedig:its(#)}}decimals for SE-scale metrics; default = {cmd:digits()}{p_end}
{synopt:{opt pctdig:its(#)}}decimals for percent metrics; default 0{p_end}
{synopt:{opt nosig:n}}suppress leading + on signed metrics{p_end}
{synopt:{opt xlsx(file)}}Excel workbook (.xlsx); {opt excel()} is a synonym{p_end}
{synopt:{opt sh:eet(name)}}Excel sheet name; default {cmd:Simulation}{p_end}
{synopt:{opt csv(file)}}CSV export (.csv){p_end}
{synopt:{opt mark:down(file)}}Markdown export (.md/.markdown/.qmd/.rmd){p_end}
{synopt:{opt mdapp:end}}append to an existing Markdown file; requires {opt markdown()}{p_end}
{synopt:{opt fra:me(name[, replace])}}store the rendered table as a frame{p_end}
{synopt:{opt plotf:rame(name[, replace])}}store the numeric companion frame{p_end}
{synopt:{opt ti:tle(string)}}table title{p_end}
{synopt:{opt foot:note(string)}}table footnote{p_end}
{synopt:{opt the:me(name)}}journal theme (lancet, nejm, bmj, ...){p_end}
{synopt:{opt border:style(name)}}default, thin, medium, academic{p_end}
{synopt:{opt headerc:olor(c)}}header fill color{p_end}
{synopt:{opt zebrac:olor(c)}}zebra stripe color{p_end}
{synopt:{opt headers:hade}}shade the header row{p_end}
{synopt:{opt zebra}}alternate-row shading{p_end}
{synopt:{opt dis:play}}display the table in the Results window{p_end}
{synopt:{opt open}}open the Excel workbook after export{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}At least one output target ({opt xlsx()}, {opt csv()}, {opt markdown()},
{opt frame()}, {opt plotframe()}, or {opt display}) is required.{p_end}

{marker description}{...}
{title:Description}

{pstd}{cmd:simtab} starts where a simulation loop has posted one row per
successful replication (compute mode), or where {cmd:simsum} / {cmd:siman} has
already summarized them (ingest mode). It does not run simulations or fit models.{p_end}

{pstd}In {bf:compute mode}, the input is long: one row = one replication x
estimator x estimand x scenario. {cmd:simtab} computes the table-grade measures
below, plus cheap closed-form Monte Carlo standard errors used to flag
off-nominal coverage, and renders the table. A leading {it:estimator} variable,
{opt estimate()}, {opt se()}, and {opt true()} are required.{p_end}

{pstd}In {bf:ingest mode} ({opt from()}), the current data in memory {bf:is} the
summary. {cmd:simtab} maps its columns onto the internal cell model and renders
without recomputation.{p_end}

{marker positioning}{...}
{title:Positioning and prior art}

{pstd}{cmd:simtab} lives in an ecosystem that already solves the statistics:
{cmd:simsum} and {cmd:siman analyse} produce validated performance measures and
Monte Carlo errors; {cmd:siman}'s graph suite makes zipper, lollipop, and
nested-loop plots; {cmd:siman_table} shows a multi-factor table on screen. What
none of them export is a {bf:styled, publication-ready table} with merged group
headers and Excel/Markdown/CSV output. That gap is {cmd:simtab}'s job.{p_end}

{pstd}{cmd:simtab} installs and runs with neither {cmd:simsum} nor {cmd:siman}
present -- compute mode is fully self-contained. The dependency is purposeful
(first-class {opt from()} ingest) but never blocks installation or the core
workflow.{p_end}

{marker metrics}{...}
{title:Metrics}

{pstd}Valid {opt metrics()} tokens (let theta-hat be the estimate, theta the
true value, n the usable replications in a cell):{p_end}

{p2colset 9 22 24 2}{...}
{p2col:{cmd:mean}}mean(theta-hat){p_end}
{p2col:{cmd:bias}}mean(theta-hat) - theta{p_end}
{p2col:{cmd:pctbias}}100 * bias / theta{p_end}
{p2col:{cmd:empse}}sd(theta-hat){p_end}
{p2col:{cmd:meanse}}mean(se){p_end}
{p2col:{cmd:relerr}}100 * (meanse/empse - 1){p_end}
{p2col:{cmd:mse}}mean((theta-hat - theta)^2){p_end}
{p2col:{cmd:rmse}}sqrt(mse){p_end}
{p2col:{cmd:coverage}}mean(covered){p_end}
{p2col:{cmd:power}}mean(rejected){p_end}
{p2col:{cmd:n}}usable replications{p_end}
{p2col:{cmd:nonconv}}nsim - n (requires {opt nsim()}){p_end}
{p2colreset}{...}

{pstd}{bf:Coverage source priority}: {opt coverage()} -> {opt lci()}/{opt uci()}
-> Wald interval from {opt estimate()} + {opt se()} at {opt level()}.
{bf:Power source priority}: {opt reject()} -> {opt pvalue()} < {opt alpha()}.{p_end}

{pstd}{bf:Monte Carlo SEs} (stored in {opt plotframe()}, used to flag coverage):
mcse_mean = mcse_bias = empse/sqrt(n); mcse_empse = empse/sqrt(2*(n-1));
mcse_coverage = sqrt(cover*(1-cover)/n); mcse_power = sqrt(power*(1-power)/n);
mcse_mse = sd((theta-hat - theta)^2)/sqrt(n); mcse_rmse = mcse_mse/(2*rmse).
When a cell's coverage deviates from the nominal level by more than
2*mcse_coverage, the cell is marked with an asterisk and a note names it.{p_end}

{pstd}{bf:Scale note}: all measures are computed on the scale supplied. For
ratio estimands (HR, OR, RR), pass estimates on the scale you want summarized
(e.g. log-HR) so bias and coverage are meaningful. When the truth is the null,
{cmd:power} is the Type-I error rate (size).{p_end}

{marker ingest}{...}
{title:Ingest mode}

{pstd}{opt from(simsum)} reads the dataset left in memory by
{cmd:simsum ..., clear} (measure-by-row, method-by-column; codes such as
{cmd:bias}, {cmd:empse}, {cmd:cover}). Run {cmd:simsum} with its {cmd:mcse}
option to carry Monte Carlo SEs. {cmd:cover}/{cmd:power} percentages are stored
internally as proportions.{p_end}

{pstd}{opt from(siman)} reads {cmd:siman analyse} performance output
(best-effort adapter).{p_end}

{pstd}{opt from(summary)} is the stable, dependency-free escape hatch for any
pre-summarized per-cell data. Map columns explicitly, e.g.{p_end}

{p 8 8 2}{cmd:simtab, from(summary) byvar(scenario) estimatorvar(method)}
{cmd:estimandvar(target) measures(mean=m bias=b coverage=cov n=nrep)}{p_end}

{p 4 6 2}In {cmd:from(summary)}, {cmd:coverage}/{cmd:power} columns are
interpreted as proportions (0-1).{p_end}

{pstd}{opt from(simsum)}/{opt from(siman)} do not require the package to be
{it:installed} -- they parse its {it:output}, which is already in memory -- but
{cmd:simtab} validates the shape and emits a usage hint on mismatch.{p_end}

{marker frames}{...}
{title:Output frames}

{pstd}{opt frame(name)} stores the rendered string table ({cmd:c1}..{cmd:cK},
flattened headers). {opt plotframe(name)} stores the numeric companion -- one
row per by x estimator x estimand, with raw measures, Monte Carlo SEs,
{cmd:nfail}/{cmd:pctfail}, and provenance characteristics -- the intended source
for figures.{p_end}

{pstd}{bf:Limitation}: {opt plotframe()} is cell-level and therefore cannot drive
a zipper plot or per-replication bias plot, which need replication-level CIs. Use
{cmd:siman}'s {cmd:siman_zipplot}/{cmd:siman_lollyplot} for those.{p_end}

{marker examples}{...}
{title:Examples}

{pstd}The examples below are workflow sketches. They assume a simulation has posted
one row per replication in memory (compute mode), or that {helpb simsum}/{cmd:siman}
output is loaded (ingest mode); {cmd:sim_results_long.dta} stands in for your own
posted simulation results.{p_end}

{pstd}Compute mode, multiple estimands, full export:{p_end}
{p 8 8 2}{cmd:. simtab estimator, estimate(estimate) se(se) true(true_value) ///}{p_end}
{p 12 12 2}{cmd:by(scenario) estimand(estimand) sim(sim) coverage(covered) nsim(1000) ///}{p_end}
{p 12 12 2}{cmd:metrics(mean bias empse meanse coverage n nonconv) ///}{p_end}
{p 12 12 2}{cmd:xlsx("sim.xlsx") sheet("Table 2") title("Simulation results") ///}{p_end}
{p 12 12 2}{cmd:borderstyle(academic) digits(3) plotframe(sim_plot, replace) display}{p_end}

{pstd}Ingest mode, analysis by simsum, table by simtab:{p_end}
{p 8 8 2}{cmd:. use sim_results_long.dta, clear}{p_end}
{p 8 8 2}{cmd:. simsum estimate, true(true_value) se(se) methodvar(estimator) id(sim) mcse clear}{p_end}
{p 8 8 2}{cmd:. simtab, from(simsum) xlsx("sim.xlsx") sheet("Table 2") display}{p_end}

{pstd}Wide IIVW postfile to long (compute mode), then simtab:{p_end}
{p 8 8 2}{cmd:. rename (b_mrg se_mrg cov_mrg) (estimate_marginal se_marginal covered_marginal)}{p_end}
{p 8 8 2}{cmd:. rename (b_slp se_slp cov_slp) (estimate_contrast se_contrast covered_contrast)}{p_end}
{p 8 8 2}{cmd:. reshape long estimate_ se_ covered_, i(sim scenario estimator) j(estimand) string}{p_end}
{p 8 8 2}{cmd:. rename (estimate_ se_ covered_) (estimate se covered)}{p_end}
{p 8 8 2}{cmd:. gen true_value = cond(estimand=="marginal", 0.10, 0.50)}{p_end}
{p 8 8 2}{cmd:. simtab estimator, estimate(estimate) se(se) true(true_value) by(scenario) estimand(estimand) sim(sim) coverage(covered) display}{p_end}

{marker stored}{...}
{title:Stored results}

{pstd}{cmd:simtab} stores metadata in {cmd:r()}:{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_cells)}}number of by x estimator x estimand cells{p_end}
{synopt:{cmd:r(n_by)}}number of by groups{p_end}
{synopt:{cmd:r(n_estimators)}}number of estimator levels{p_end}
{synopt:{cmd:r(n_estimands)}}number of estimand levels{p_end}
{synopt:{cmd:r(n_reps_min)}}minimum usable replications (compute mode){p_end}
{synopt:{cmd:r(n_reps_max)}}maximum usable replications (compute mode){p_end}
{synopt:{cmd:r(n_fail_max)}}maximum non-convergence count, if {opt nsim()} set{p_end}
{synopt:{cmd:r(level)}}coverage level{p_end}
{synopt:{cmd:r(alpha)}}power/rejection alpha{p_end}
{synopt:{cmd:r(markdown_rows)}}Markdown row count, if exported{p_end}
{synopt:{cmd:r(markdown_cols)}}Markdown column count, if exported{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(mode)}}{cmd:compute} or {cmd:ingest}{p_end}
{synopt:{cmd:r(source)}}{cmd:compute} | {cmd:simsum} | {cmd:siman} | {cmd:summary}{p_end}
{synopt:{cmd:r(metrics)}}metric tokens displayed{p_end}
{synopt:{cmd:r(methods)}}plain-language summary{p_end}
{synopt:{cmd:r(frame)}}rendered table frame, if created{p_end}
{synopt:{cmd:r(plotframe)}}numeric companion frame, if created{p_end}
{synopt:{cmd:r(xlsx)}}Excel workbook, if exported{p_end}
{synopt:{cmd:r(sheet)}}Excel sheet, if exported{p_end}
{synopt:{cmd:r(csv)}}CSV file, if exported{p_end}
{synopt:{cmd:r(markdown)}}Markdown file, if exported{p_end}
{p2colreset}{...}

{marker refs}{...}
{title:References}

{pstd}Morris TP, White IR, Crowther MJ. Using simulation studies to evaluate
statistical methods. {it:Stat Med}. 2019;38(11):2074-2102.{p_end}

{pstd}White IR. simsum: Analyses of simulation studies including Monte Carlo
error. {it:Stata Journal}. 2010;10(3):369-385.{p_end}

{pstd}siman (UCL): the analysis-and-graph suite for simulation studies,
{browse "https://github.com/UCL/siman":github.com/UCL/siman}.{p_end}

{marker alsosee}{...}
{title:Also see}

{psee}Manual: {bf:[R] simulate}{p_end}
{psee}Online: {helpb tabtools}, {helpb puttab}, {helpb comptab}, {helpb stacktab}{p_end}

{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}

{smcl}
{* *! iivw_bspool *}{...}
{vieweralsosee "iivw" "help iivw"}{...}
{vieweralsosee "iivw_fit" "help iivw_fit"}{...}
{vieweralsosee "iivw_weight" "help iivw_weight"}{...}
{vieweralsosee "[R] bootstrap" "help bootstrap"}{...}
{vieweralsosee "[R] bstat" "help bstat"}{...}
{viewerjumpto "Syntax" "iivw_bspool##syntax"}{...}
{viewerjumpto "Description" "iivw_bspool##description"}{...}
{viewerjumpto "Options" "iivw_bspool##options"}{...}
{viewerjumpto "Remarks" "iivw_bspool##remarks"}{...}
{viewerjumpto "Refusals" "iivw_bspool##refusals"}{...}
{viewerjumpto "Inference status" "iivw_bspool##status"}{...}
{viewerjumpto "Limitations" "iivw_bspool##limits"}{...}
{viewerjumpto "Examples" "iivw_bspool##examples"}{...}
{viewerjumpto "Stored results" "iivw_bspool##results"}{...}
{viewerjumpto "Author" "iivw_bspool##author"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:iivw_bspool} {hline 2}}Pool sharded {cmd:iivw_fit} bootstrap replicates into one result{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:iivw_bspool}
{cmd:using} {cmd:"}{it:file1} [{it:file2} ...]{cmd:"}
[{cmd:,} {it:options}]

{p 4 4 2}
The file list is one quoted, space-separated string. File paths must not
contain spaces.


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt cit:ype(string)}}interval: {cmd:wald}, {cmd:percentile}, or {cmd:basic}{p_end}
{synopt:{opt l:evel(#)}}confidence level; default is the shards'{p_end}
{synopt:{opt reps(#)}}assert the pooled requested-draw total{p_end}
{synopt:{opt sav:ing(spec)}}write the appended replicate file{p_end}
{synopt:{opt allowfailedr:eps}}accept failed replicates{p_end}
{synopt:{opt notab:le}}suppress the coefficient table{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:iivw_bspool} pools the bootstrap replicate files written by K
{helpb iivw_fit} shards into a single estimation result. A 999-draw refit
bootstrap runs as one serial process; with {cmd:saving()} and
{cmd:rngstream()}, the same 999 draws can be produced by K concurrent Stata
processes, each drawing an independent and reproducible subset, and pooled
here.

{pstd}
Nothing about the estimator changes. The draws already existed; before 4.2.0
the package discarded them instead of making them addressable.

{pstd}
{cmd:iivw_bspool} operates on the {cmd:iivw_fit} results currently in
{cmd:e()}. Those results are the {it:anchor}: they supply the coefficient
vector and every {cmd:e()} field the draws do not determine. The files supply
the draws. {bf:The anchor's own replicate file must be in the using list.}

{pstd}
The pooled variance, percentile limits and replicate counts are computed by
Stata's own {helpb bstat}, the engine the {helpb bootstrap} prefix uses. That
is deliberate: pooling is not a reimplementation of the bootstrap arithmetic,
so the pooled numbers are identical to an unsharded run's by construction
rather than by agreement to some tolerance. Splitting one run's replicate file
into K pieces and pooling them back reproduces that run to the last bit
({cmd:qa/test_iivw_v420_shard.do}, case T1).


{marker options}{...}
{title:Options}

{phang}
{opt citype(string)} selects the interval formed from the pooled draws: {cmd:wald},
{cmd:percentile}, or {cmd:basic}. The default is whatever the
shards themselves reported. {cmd:bca} is not poolable; see
{help iivw_bspool##limits:Limitations}.

{phang}
{opt level(#)} sets the confidence level. The default is the shards' own
level. Unlike {cmd:iivw_fit} replay, a different level is accepted here,
because the pooled endpoints are recomputed from the draws rather than read
back from a stored matrix.

{phang}
{opt reps(#)} asserts what the pooled requested-draw total should be. If the
shards together requested a different number, {cmd:iivw_bspool} errors. The
likeliest operational failure in a K-process driver is one process dying and
the driver pooling K-1 files; this is how you say that 999 was the design.

{phang}
{opt saving(spec)} writes the appended replicate file to disk, for audit or for
re-pooling later. {it:spec} is a filename optionally followed by
{cmd:, replace}.

{pmore}
The saved file is stamped with the {it:pooled} totals rather than inheriting
the first shard's, so it describes itself and can be re-pooled on its own. An
existing target with no {cmd:replace} is caught before any shard is read, so
the mistake costs nothing rather than a nine-shard run's work; a write that
fails after pooling succeeded leaves the pooled results in {cmd:e()} untouched.

{phang}
{opt allowfailedreps} accepts a pooled result in which some replicates failed. Without
it, any failure across any shard is an error; see
{help iivw_bspool##refusals:Refusals}.

{phang}
{opt notable} suppresses the coefficient table. The stored results are
unaffected.


{marker remarks}{...}
{title:Remarks}

{dlgtab:Producing the shards}

{pstd}
Each shard is an ordinary {cmd:iivw_fit} bootstrap that writes its draws and
names its substream:

{pin}
{cmd:. iivw_fit y a z1, timespec(linear) citype(percentile) ///}{break}
{cmd:      vce(bootstrap, reps(111) seed(20260915)) rngstream(3) ///}{break}
{cmd:      saving(shard3, replace)}

{pstd}
All shards share one {cmd:seed()} and differ only in {cmd:rngstream()}. Handing
K shards K unrelated seeds gives streams that are very probably disjoint, which
is not the same as a guarantee; {cmd:set rngstream} is the mechanism Stata
provides for exactly this, and it lets the whole run be described by one seed
plus a stream index.

{pstd}
Run the shards in separate working directories with {cmd:set processors 1} in a
local {cmd:profile.do}. Batch mode writes {it:dofile}{cmd:.log} into the
current directory, so concurrent jobs sharing one directory collide on that
name; and each process otherwise spawns one thread per licensed core, so K jobs
put far more runnable threads on the machine than it has cores. A worked driver
is in {cmd:demo/shard_driver.do}.

{dlgtab:Pooling}

{pstd}
Load one shard's estimation results, then pool every shard file including that
one:

{pin}
{cmd:. estimates use shard1.ster}{break}
{cmd:. iivw_bspool using "shard1.dta shard2.dta shard3.dta", reps(333)}

{pstd}
The data need not be in memory. If it is, its weight contract must be the one
the anchor was fit on.

{dlgtab:What pooling is and is not}

{pstd}
Pooling earns the {it:replicate count} and nothing else. Nine shards of 111
each honestly carry {cmd:uncleared-low-reps}, and the 999-draw pooled result
does not; every other stamp a shard carries describes the estimator rather than
the draw count and survives pooling untouched.


{marker refusals}{...}
{title:Refusals}

{pstd}
Two replicate files with matching column names can come from different weights,
a different weight type, a different outcome specification, or a different
build. Averaging their draws produces a number that is the variance of no
estimator in particular, at {cmd:rc 0}, with nothing in the output to say so. {cmd:iivw_bspool}
therefore errors, never warns, when shards disagree on:

{p2colset 8 44 46 2}{...}
{p2col:{cmd:e(iivw_wsig)}}the weight contract{p_end}
{p2col:{cmd:e(iivw_model)}}gee or mixed{p_end}
{p2col:{cmd:e(iivw_weighttype)}}iivw, iptw, or fiptiw{p_end}
{p2col:{cmd:e(iivw_refitweights)}}whether the draws refit the weights{p_end}
{p2col:{cmd:e(iivw_unweighted)}}weighted or not{p_end}
{p2col:{cmd:e(iivw_cluster)}}the resampling unit{p_end}
{p2col:{cmd:e(iivw_timespec)}}the time specification{p_end}
{p2col:{cmd:e(depvar)}}the dependent variable{p_end}
{p2col:{cmd:e(iivw_ci_type)}}the interval type{p_end}
{p2col:{cmd:e(level)}}the confidence level{p_end}
{p2col:coefficient names}the column stripes{p_end}
{p2col:observed estimates}compared as exact strings{p_end}
{p2col:package version}the build that wrote the shard{p_end}
{p2col:estimation sample size}{cmd:e(N)} at the fit{p_end}
{p2colreset}{...}

{pstd}
It also refuses:

{phang2}
{bf:the same RNG state twice.} Two shards launched with the same seed and no
{cmd:rngstream()} drew the {it:same} replicates. Pooling them counts one set of
draws twice and reports a Monte Carlo error the run did not earn. The test is
the exact pre-draw state each shard recorded, so it cannot be fooled by
coincidence.

{phang2}
{bf:the same file listed twice.}

{phang2}
{bf:a file that is not an iivw shard.} Replicate files written by a bare
{helpb bootstrap} prefix, or by {cmd:iivw_fit} before 4.2.0, carry no identity
and cannot be checked.

{phang2}
{bf:a truncated shard.} A file holding fewer rows than its own stamp says it
requested was cut short, usually by a process killed while {cmd:every()} was
flushing. Pooling it would produce an interval from a draw count nobody chose.

{phang2}
{bf:failed replicates,} unless {cmd:allowfailedreps} is given. The gate fires on
the {it:pooled} total. Applied per shard it would be no gate at all: nine shards
with three failures each would each pass a check that the same 27 failures in
one run would have stopped.


{marker status}{...}
{title:Inference status}

{pstd}
{cmd:e(iivw_inference_status)} is recomputed, not copied. Two stamps are keyed
to the draw count and are therefore recomputed from the pooled totals:

{phang2}
{cmd:uncleared-low-reps} is stamped when the pooled requested total is below
999. Each 111-draw shard trips it correctly and the pooled 999 does not.

{phang2}
{cmd:uncleared-failed-reps} is stamped when any replicate failed anywhere and
{cmd:allowfailedreps} was given.

{pstd}
Every other stamp present on any shard is inherited, and the weakest one wins. Pooling
improves the replicate count and nothing else, so it may not lift a
stamp it has not earned.


{marker limits}{...}
{title:Limitations}

{pstd}
{bf:BCa intervals cannot be pooled.} BCa has two corrections. The bias
correction pools from the replicate draws; the acceleration does not, because
it comes from a delete-one jackknife over clusters that each shard ran
separately. Reusing one shard's acceleration on 999 pooled draws would report a
skewness correction estimated from a fraction of the evidence, under a BCa
label. {cmd:iivw_bspool} errors on {cmd:citype(bca)} shards rather than doing
that. Use {cmd:citype(percentile)}, {cmd:citype(basic)} or {cmd:citype(wald)},
which pool exactly.

{pstd}
{bf:The equivalence claim is bounded by what has been measured.} Pooling one
run's own draws is exact. Pooling K shards drawn from K independent substreams
against a single run of the same total is agreement within Monte Carlo
tolerance, not identity, because the draws differ; {cmd:qa/} case T17 is the
check that establishes it.

{pstd}
{bf:{cmd:every()} is the user's risk.} {cmd:iivw_fit}'s {cmd:saving()} forwards
{cmd:every(#)} to Stata unchanged. A write cadence lets a killed shard leave
partial draws behind, which is attractive for multi-hour runs and is also a way
to pool an unintended number of draws. The truncation refusal above is what
catches it.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Setup: example data and weights}

{phang2}{cmd:. clear}{p_end}
{phang2}{cmd:. set seed 20260417}{p_end}
{phang2}{cmd:. set obs 320}{p_end}
{phang2}{cmd:. gen long id = ceil(_n/4)}{p_end}
{phang2}{cmd:. bysort id: gen byte visit = _n}{p_end}
{phang2}{cmd:. gen double days = (visit - 1) * 90 + runiform() * 20}{p_end}
{phang2}{cmd:. replace days = 0 if visit == 1}{p_end}
{phang2}{cmd:. gen double edss_bl = 2 + 3 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace edss_bl = edss_bl[1]}{p_end}
{phang2}{cmd:. gen double age = 35 + 15 * runiform()}{p_end}
{phang2}{cmd:. bysort id: replace age = age[1]}{p_end}
{phang2}{cmd:. gen byte sex = runiform() > 0.5}{p_end}
{phang2}{cmd:. bysort id: replace sex = sex[1]}{p_end}
{phang2}{cmd:. gen byte treated = (runiform() < invlogit(-0.8 + 0.5 * edss_bl))}{p_end}
{phang2}{cmd:. bysort id: replace treated = treated[1]}{p_end}
{phang2}{cmd:. gen double edss = edss_bl + 0.012 * days - 0.7 * treated + rnormal(0, 0.45)}{p_end}
{phang2}{cmd:. gen byte relapse = (runiform() < invlogit(-2 + 0.4 * edss))}{p_end}
{phang2}{cmd:. bysort id (days): egen double fu_end = max(days)}{p_end}
{phang2}{cmd:. replace fu_end = fu_end + 30}{p_end}
{phang2}{cmd:. iivw_weight, id(id) time(days) visit_cov(edss_bl age sex) lagvars(edss relapse) censor(fu_end) nolog}{p_end}

{pstd}
{bf:Three shards of one bootstrap}

{pstd}
Run sequentially here so the example is copy-pasteable. In use each shard is
its own process; see {cmd:demo/shard_driver.do}. The shards share one
{cmd:seed()} and differ only in {cmd:rngstream()}, and shard 1 also saves its
estimation results to serve as the pooling anchor.

{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(linear) citype(percentile) vce(bootstrap, reps(20) seed(20260915)) rngstream(1) saving(shard1, replace) nolog}{p_end}
{phang2}{cmd:. estimates save bsanchor, replace}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(linear) citype(percentile) vce(bootstrap, reps(20) seed(20260915)) rngstream(2) saving(shard2, replace) nolog}{p_end}
{phang2}{cmd:. iivw_fit edss treated edss_bl, timespec(linear) citype(percentile) vce(bootstrap, reps(20) seed(20260915)) rngstream(3) saving(shard3, replace) nolog}{p_end}

{pstd}
{bf:Pool them}

{pstd}
{cmd:reps()} states what the design called for, so a shard missing from the
list is an error rather than a quietly smaller bootstrap.

{phang2}{cmd:. estimates use bsanchor}{p_end}
{phang2}{cmd:. iivw_bspool using "shard1.dta shard2.dta shard3.dta", reps(60)}{p_end}

{pstd}
{bf:Pool at a different interval type and level}

{phang2}{cmd:. iivw_bspool using "shard1.dta shard2.dta shard3.dta", citype(basic) level(90)}{p_end}

{pstd}
{bf:Keep the appended replicate file}

{pstd}
The saved file is stamped with the pooled totals, so it is itself a valid
single shard and can be re-pooled on its own.

{phang2}{cmd:. iivw_bspool using "shard1.dta shard2.dta shard3.dta", saving(pooled, replace)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:iivw_bspool} reposts the anchor's results. Every {cmd:iivw_fit} stored
result survives; see {helpb iivw_fit##results:iivw_fit}. The following are
replaced or added.

{pstd}{cmd:iivw_bspool} replaces in {cmd:e()}:{p_end}
{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Matrices}{p_end}
{synopt:{cmd:e(V)}}pooled covariance{p_end}
{synopt:{cmd:e(iivw_ci)}}selected interval from the pooled draws{p_end}
{synopt:{cmd:e(iivw_ci_percentile)}}pooled percentile limits{p_end}
{synopt:{cmd:e(iivw_ci_basic)}}pooled basic limits{p_end}
{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:e(level)}}confidence level{p_end}
{synopt:{cmd:e(iivw_bs_reps_requested)}}pooled requested draws{p_end}
{synopt:{cmd:e(iivw_bs_reps_completed)}}pooled completed draws{p_end}
{synopt:{cmd:e(iivw_bs_reps_failed)}}pooled failed draws{p_end}
{synopt:{cmd:e(iivw_interval_available)}}always 1{p_end}
{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:e(iivw_ci_type)}}the pooled interval type{p_end}
{synopt:{cmd:e(iivw_inference_status)}}recomputed; see above{p_end}
{synopt:{cmd:e(iivw_allowfailedreps)}}1 if failures were accepted{p_end}
{p2colreset}{...}

{pstd}{cmd:iivw_bspool} adds to {cmd:e()}:{p_end}
{synoptset 30 tabbed}{...}
{p2col 5 30 34 2: Scalars}{p_end}
{synopt:{cmd:e(iivw_bs_shards)}}number of shards pooled{p_end}
{p2col 5 30 34 2: Macros}{p_end}
{synopt:{cmd:e(iivw_bs_pooled)}}{cmd:1}{p_end}
{synopt:{cmd:e(iivw_pooled_by)}}{cmd:iivw_bspool}{p_end}
{synopt:{cmd:e(iivw_bs_streams)}}contributing {cmd:rngstream()} values{p_end}
{synopt:{cmd:e(iivw_bs_seeds)}}contributing {cmd:seed()} values{p_end}
{synopt:{cmd:e(iivw_bs_shard_files)}}the using list{p_end}
{synopt:{cmd:e(iivw_bs_anchor_breldif)}}anchor-to-shard coefficient agreement{p_end}
{p2colreset}{...}

{pstd}
{cmd:e(cmd)} remains {cmd:iivw_fit}, so the pooled result replays and feeds the
other {cmd:iivw} post-estimation commands like any other fit. {cmd:e(iivw_bs_pooled)} is how a reader tells the two apart.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland, Karolinska Institutet{p_end}

{hline}

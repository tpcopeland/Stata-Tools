* shard_driver.do -- run one iivw_fit refit bootstrap as K concurrent processes
*
* A 999-draw refit bootstrap refits the visit-intensity model and the outcome
* model on every draw. That work is the same on every draw and depends on no
* other draw, so the only reason it takes one process's wall clock is that
* Stata's bootstrap prefix is serial.
*
* This driver runs the same 999 draws as K processes, each on its own RNG
* substream of one shared seed, and pools them with iivw_bspool. It is
* documentation of the intended usage, not package code: copy it and edit the
* CONFIGURATION block.
*
* MEASURED, on this machine, so the expectation is calibrated rather than
* asserted: the refit bootstrap is 99.9% per-draw work. On a 1200-subject /
* 7100-row panel, 25 draws took 4.22s and 50 took 8.24s -- a slope of 0.161s
* per draw against a fixed overhead of 0.19s, which is about one draw's worth.
* There is no invariant per-draw work left to hoist, so wall clock should fall
* close to linearly in K until K exceeds the physical core count.
*
* WHY EACH SHARD NEEDS ITS OWN DIRECTORY
* --------------------------------------
* Two reasons, both of which produce wrong results rather than errors:
*
*   1. Batch mode writes <dofile>.log into the current directory. K jobs
*      sharing one directory collide on that name and overwrite each other's
*      logs, so a failed shard can look like a successful one.
*   2. Each stata-mp process otherwise spawns one thread per licensed core and
*      spin-waits at barriers. K jobs then put 16K runnable threads on the
*      cores and throughput collapses. The profile.do written below sets
*      processors to 1 per job. Results are identical across processor counts.
*
* Match K to physical cores, not to the shard count you would like.

clear all
set varabbrev off
version 16.0

* ==========================================================================
* CONFIGURATION
* ==========================================================================

* Where the shards run and write their files. Must be writable and empty-ish.
local root "`c(pwd)'/shardrun"

* Total draws, and how many processes to split them across. NSHARD must divide
* REPS_TOTAL exactly: a remainder would silently change the total.
local reps_total 999
local nshard 9

* One seed for the whole run. The shards differ only in their substream.
local master_seed 20260915

* The analysis dataset, already carrying a committed iivw_weight contract.
local datafile "`c(pwd)'/shard_panel.dta"

* The fit, written once and reused by every shard. Do not put vce(), saving()
* or rngstream() here; the driver supplies those.
local depvar   "y"
local indepvar "a z1"
local fitopts  "timespec(linear) citype(percentile)"

* The weighting call, re-run inside each shard because a shard is a fresh
* process and the weight contract travels with the dataset, not the session.
* Leave empty if `datafile' already carries a committed contract.
local weightcall ""

local stata_bin "stata-mp"

* ==========================================================================
* CHECKS
* ==========================================================================

if mod(`reps_total', `nshard') != 0 {
    display as error "reps_total (`reps_total') is not divisible by nshard (`nshard')"
    display as error "  a remainder would change the total draw count silently"
    exit 198
}
local per_shard = `reps_total' / `nshard'
display as text "Sharding `reps_total' draws as `nshard' x `per_shard'"

capture confirm file "`datafile'"
if _rc {
    display as error "no dataset at `datafile'"
    display as error "  set datafile in the CONFIGURATION block above"
    exit 601
}

capture mkdir "`root'"

* ==========================================================================
* WRITE ONE DO-FILE PER SHARD
* ==========================================================================

forvalues s = 1/`nshard' {
    local sdir "`root'/shard`s'"
    capture mkdir "`sdir'"

    * processors 1, per the note at the top. profile.do is read by every Stata
    * started in this directory, so it cannot be forgotten on a rerun.
    tempname pf
    file open `pf' using "`sdir'/profile.do", write replace text
    file write `pf' "set processors 1" _n
    file close `pf'

    tempname df
    file open `df' using "`sdir'/shard.do", write replace text
    file write `df' "clear all" _n
    file write `df' "set varabbrev off" _n
    file write `df' "version 16.0" _n
    file write `df' "use " _char(34) "`datafile'" _char(34) ", clear" _n
    if "`weightcall'" != "" {
        file write `df' "quietly `weightcall'" _n
    }
    * Every shard shares the seed and differs only in rngstream(). Handing K
    * shards K unrelated seeds would give streams that are very probably
    * disjoint, which is not the same as a guarantee.
    file write `df' "iivw_fit `depvar' `indepvar', `fitopts' ///" _n
    file write `df' "    vce(bootstrap, reps(`per_shard') seed(`master_seed')) ///" _n
    file write `df' "    rngstream(`s') saving(" _char(34) "`sdir'/reps" _char(34) ", replace)" _n
    * Shard 1 additionally saves its estimation results. iivw_bspool pools into
    * an anchor fit, and the anchor is where every e() field the draws do not
    * determine comes from.
    if `s' == 1 {
        file write `df' "estimates save " _char(34) "`root'/anchor" _char(34) ", replace" _n
    }
    file write `df' "display " _char(34) "SHARD_`s'_OK" _char(34) _n
    file close `df'
}

* ==========================================================================
* LAUNCH
* ==========================================================================
* Backgrounded from one shell so the driver does not serialise them itself.
* Each cd is inside its own subshell, so the shards do not fight over the
* driver's working directory.

display as text "Launching `nshard' shards..."
local cmd ""
forvalues s = 1/`nshard' {
    local sdir "`root'/shard`s'"
    local cmd "`cmd' ( cd '`sdir'' && `stata_bin' -b do shard.do ) &"
}
local cmd "`cmd' wait"
shell `cmd'

* ==========================================================================
* VERIFY EVERY SHARD FINISHED
* ==========================================================================
* A shard that died leaves no file, or a short one. Pooling K-1 files would
* produce an interval from a draw count nobody chose, so check before pooling
* and let iivw_bspool's reps() assertion catch anything this misses.

local poollist ""
local missing ""
forvalues s = 1/`nshard' {
    local f "`root'/shard`s'/reps.dta"
    capture confirm file "`f'"
    if _rc local missing "`missing' `s'"
    else   local poollist "`poollist' `f'"
}
if "`missing'" != "" {
    display as error "shards that wrote no replicate file:`missing'"
    display as error "  read `root'/shard<n>/shard.log for the reason"
    exit 601
}

* ==========================================================================
* POOL
* ==========================================================================

estimates use "`root'/anchor"
iivw_bspool using "`poollist'", reps(`reps_total') saving("`root'/pooled", replace)

display as text ""
display as text "Pooled from " as result e(iivw_bs_shards) as text " shards on streams " ///
    as result "`e(iivw_bs_streams)'"
display as text "Replicates: " as result e(iivw_bs_reps_completed) ///
    as text " of " as result e(iivw_bs_reps_requested)
display as text "Inference status: " as result "`e(iivw_inference_status)'"

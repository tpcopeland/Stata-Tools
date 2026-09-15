*! iivw_bspool Version 4.2.0  2026/09/15
*! Pool sharded iivw_fit bootstrap replicate files into one estimation result
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass (reposts the current iivw_fit results)

/*
Basic syntax:
  iivw_bspool using "file1 file2 ... fileK" [, options]

Description:
  Pools the replicate files written by K iivw_fit bootstrap shards -- each run
  with saving() and its own rngstream() -- into a single estimation result
  whose variance, interval, replicate accounting and inference status are what
  one unsharded run of the same total draw count would have produced.

  Operates on the iivw_fit results currently in e(). That anchor supplies the
  coefficient vector and every e() field the draws do not determine; the files
  supply the draws. The anchor's own replicate file must be in the using list.

Options:
  citype(string)   - wald, percentile, or basic (default: the shards' own)
  level(#)         - Confidence level (default: the shards' own)
  reps(#)          - Assert the pooled requested-draw total; error if it differs
  saving(spec)     - Write the appended replicate file to disk
  allowfailedreps  - Accept a pooled result with failed replicates
  notable          - Suppress the coefficient table

See help iivw_bspool for complete documentation.
*/

program define iivw_bspool, eclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    * Cleanup flags, all initialized before the captured block so the cleanup
    * zone can roll back however early the error fires.
    local _frame_open = 0
    local _est_stored = 0
    local _completed  = 0
    tempname shardfr anchorest

    capture noisily {

    * Level(string), NOT Level(cilevel). syntax fills a cilevel option with
    * c(level) whenever it is omitted, so an omitted level() is indistinguishable
    * from a typed one -- and this command's documented default is the SHARDS'
    * level, not the session's. With cilevel, pooling shards fit at level(90)
    * silently produced a 95% interval whenever the session default was 95.
    syntax using/ [, CIType(string) Level(string) REPS(integer -1) ///
        SAVing(string asis) ALLOWFAILEDReps noTABle]

    if "`level'" != "" {
        capture confirm integer number `level'
        if _rc | `level' < 10 | `level' > 99 {
            display as error "iivw_bspool: level() must be an integer between 10 and 99"
            display as error "  got: `level'"
            error 198
        }
    }

    * =====================================================================
    * ANCHOR: the iivw_fit results being pooled into
    * =====================================================================
    * Post-estimation commands verify whose results they are about to consume.
    * Without this, iivw_bspool would happily repost a pooled iivw variance
    * onto whatever estimation command happened to run last.
    if "`e(iivw_cmd)'" != "iivw_fit" {
        display as error "iivw_bspool requires iivw_fit estimation results"
        display as error "  run one shard in this session, or load one with"
        display as error "    estimates use <shard.ster>"
        display as error "  before pooling"
        error 301
    }

    local anchor_reps = e(iivw_bs_reps_requested)
    if "`anchor_reps'" == "" | `anchor_reps' >= . local anchor_reps = 0
    if `anchor_reps' <= 0 {
        display as error "iivw_bspool: the results in e() are not a bootstrap fit"
        display as error "  e(iivw_bs_reps_requested) is `anchor_reps'; there are no"
        display as error "  draws for the pooled variance to be consistent with"
        error 198
    }

    local anchor_wsig     "`e(iivw_wsig)'"
    local anchor_model    "`e(iivw_model)'"
    local anchor_wtype    "`e(iivw_weighttype)'"
    local anchor_refit    "`e(iivw_refitweights)'"
    local anchor_unw      "`e(iivw_unweighted)'"
    local anchor_cluster  "`e(iivw_cluster)'"
    local anchor_timespec "`e(iivw_timespec)'"
    local anchor_citype   "`e(iivw_ci_type)'"
    local anchor_level    = e(level)
    local anchor_depvar   "`e(depvar)'"
    local anchor_status   "`e(iivw_inference_status)'"

    * The weight contract the anchor rests on must still be the one in memory.
    * A pooled variance is reposted onto the anchor's e(b), and e(sample) points
    * at the data in memory; pooling against a dataset that has since been
    * reweighted would attach honest draws to a coefficient vector that no
    * longer describes it.
    *
    * Data-free pooling is a legitimate driver pattern -- estimates use, then
    * pool, with no dataset loaded -- so the check is against a contract that is
    * PRESENT and different, never against one that is absent.
    if c(N) > 0 {
        local _wsig_now : char _dta[_iivw_wsig]
        if "`_wsig_now'" != "" & "`_wsig_now'" != "`anchor_wsig'" {
            display as error "iivw_bspool: the data in memory is not the data the anchor was fit on"
            display as error "  e(iivw_wsig) and the dataset's weight contract disagree"
            display as error "  reload the analysis data, or clear it and pool from"
            display as error "  estimates use alone"
            error 459
        }
    }

    * =====================================================================
    * FILE LIST
    * =====================================================================
    local nshards : word count `using'
    if `nshards' < 1 {
        display as error "iivw_bspool: no replicate files given"
        error 198
    }

    * Resolve each spelling to one path. bootstrap's saving() appends .dta when
    * the spec carries no suffix, so both spellings have to resolve or a driver
    * that wrote reps_3 and pooled "reps_3" would silently find nothing.
    local resolved ""
    forvalues i = 1/`nshards' {
        local raw : word `i' of `using'
        local path ""
        capture confirm file `"`raw'.dta"'
        if !_rc local path `"`raw'.dta"'
        else {
            capture confirm file `"`raw'"'
            if !_rc local path `"`raw'"'
        }
        if `"`path'"' == "" {
            display as error "iivw_bspool: no replicate file at `raw'"
            display as error "  (tried `raw'.dta and `raw')"
            display as error "  file paths in the using list must not contain spaces"
            error 601
        }
        * The same file twice is not two shards. Pooling it would count one set
        * of draws as two and halve the apparent Monte Carlo error.
        local dup : list posof "`path'" in resolved
        if `dup' {
            display as error "iivw_bspool: `path' appears twice in the using list"
            display as error "  the same draws cannot contribute to a pooled"
            display as error "  variance more than once"
            error 198
        }
        local resolved "`resolved' `path'"
        local path`i' `"`path'"'
    }

    * Resolve saving() here, not at the write. The common failure -- a target
    * that exists with no replace -- would otherwise surface after every shard
    * had been read, appended and pooled, which on a nine-shard run is minutes
    * of work thrown away over a missing word.
    local _svtarget ""
    local _svrepl ""
    if `"`saving'"' != "" {
        gettoken _svname _svrest : saving, parse(",")
        local _svname `_svname'
        if strpos(`"`_svrest'"', "replace") local _svrepl "replace"
        if `"`_svname'"' == "" {
            display as error "iivw_bspool: empty filename in saving()"
            error 198
        }
        local _svtarget `"`_svname'"'
        if strpos(`"`_svname'"', ".dta") == 0 local _svtarget `"`_svname'.dta"'
        if "`_svrepl'" == "" {
            capture confirm new file `"`_svtarget'"'
            if _rc {
                display as error "iivw_bspool: `_svtarget' already exists"
                display as error "  add replace to saving() to overwrite it"
                error 602
            }
        }
    }

    * =====================================================================
    * READ AND CROSS-CHECK EVERY SHARD
    * =====================================================================
    * This is the silent-corruption guard the whole design turns on. Two
    * replicate files with matching column names can come from different
    * weights, a different weight type, a different outcome specification or a
    * different build. Averaging their draws produces a number that is not the
    * variance of any estimator, at rc 0, with nothing in the output to say so.
    frame create `shardfr'
    local _frame_open = 1

    local sum_requested = 0
    local sum_completed = 0
    local sum_failed    = 0
    local pooled_rows   = 0
    local streams       ""
    local seeds         ""
    local statuses      ""
    local worst_rank    = 0

    forvalues i = 1/`nshards' {
        frame `shardfr' {
            capture use `"`path`i''"', clear
            if _rc {
                display as error "iivw_bspool: cannot read `path`i''"
                error 601
            }

            local marker : char _dta[_iivw_shard]
            if "`marker'" != "1" {
                display as error "iivw_bspool: `path`i'' is not an iivw shard file"
                display as error "  it carries no _iivw_shard characteristics"
                display as error "  replicate files written by a bare -bootstrap-"
                display as error "  prefix, or by iivw_fit before 4.2.0, do not record"
                display as error "  which fit produced them and cannot be identity-checked"
                error 459
            }

            local s_version`i'  : char _dta[_iivw_shard_version]
            local s_cmd`i'      : char _dta[_iivw_shard_cmd]
            local s_wsig`i'     : char _dta[_iivw_shard_wsig]
            local s_model`i'    : char _dta[_iivw_shard_model]
            local s_wtype`i'    : char _dta[_iivw_shard_weighttype]
            local s_refit`i'    : char _dta[_iivw_shard_refitweights]
            local s_unw`i'      : char _dta[_iivw_shard_unweighted]
            local s_cluster`i'  : char _dta[_iivw_shard_cluster]
            local s_timespec`i' : char _dta[_iivw_shard_timespec]
            local s_citype`i'   : char _dta[_iivw_shard_citype]
            local s_level`i'    : char _dta[_iivw_shard_level]
            local s_depvar`i'   : char _dta[_iivw_shard_depvar]
            local s_req`i'      : char _dta[_iivw_shard_reps_requested]
            local s_done`i'     : char _dta[_iivw_shard_reps_completed]
            local s_fail`i'     : char _dta[_iivw_shard_reps_failed]
            local s_status`i'   : char _dta[_iivw_shard_status]
            local s_stream`i'   : char _dta[_iivw_shard_rngstream]
            local s_seed`i'     : char _dta[_iivw_shard_seed]
            local s_rngstate`i' : char _dta[seed]
            local s_N`i'        : char _dta[N]
            local s_rows`i' = _N

            * Column identity from the stripes and the observed estimates, not
            * from the variable names. glm posts an equation name, so the saved
            * columns are <eq>_b_<term>; the stripe characteristics are what
            * bstat and ereturn actually rebuild the matrix from.
            quietly ds
            local s_vars`i' "`r(varlist)'"
            local s_stripe`i' ""
            local s_obs`i' ""
            foreach v of local s_vars`i' {
                local _eq : char `v'[coleq]
                local _cn : char `v'[colname]
                local _ob : char `v'[observed]
                local s_stripe`i' "`s_stripe`i'' `_eq':`_cn'"
                local s_obs`i' "`s_obs`i'' `_ob'"
            }
        }
    }

    * ---- agreement with the anchor, and with each other -------------------
    * Anything on this list, differing, means the shards did not fit the same
    * model to the same data. Error, never warn: a warning on a nine-shard
    * overnight run is a line nobody reads in a log nobody opens.
    forvalues i = 1/`nshards' {
        _iivw_bspool_agree, name("weight contract e(iivw_wsig)") ///
            file(`"`path`i''"') got("`s_wsig`i''")     want("`anchor_wsig'")
        _iivw_bspool_agree, name("command") ///
            file(`"`path`i''"') got("`s_cmd`i''")      want("iivw_fit")
        _iivw_bspool_agree, name("model") ///
            file(`"`path`i''"') got("`s_model`i''")    want("`anchor_model'")
        _iivw_bspool_agree, name("weight type") ///
            file(`"`path`i''"') got("`s_wtype`i''")    want("`anchor_wtype'")
        _iivw_bspool_agree, name("refitweights") ///
            file(`"`path`i''"') got("`s_refit`i''")    want("`anchor_refit'")
        _iivw_bspool_agree, name("unweighted") ///
            file(`"`path`i''"') got("`s_unw`i''")      want("`anchor_unw'")
        _iivw_bspool_agree, name("cluster") ///
            file(`"`path`i''"') got("`s_cluster`i''")  want("`anchor_cluster'")
        _iivw_bspool_agree, name("timespec") ///
            file(`"`path`i''"') got("`s_timespec`i''") want("`anchor_timespec'")
        _iivw_bspool_agree, name("dependent variable") ///
            file(`"`path`i''"') got("`s_depvar`i''")   want("`anchor_depvar'")
        * Interval type and level are compared across the SHARDS, not against
        * the anchor. Both are reporting choices the pooler recomputes from the
        * draws and citype()/level() can override outright, so binding them to
        * the anchor buys nothing -- and it refused the documented workflow of
        * re-pooling a saved pooled file, whose anchor carries the interval type
        * the previous pool selected rather than the one the shards were fit
        * with. Disagreement BETWEEN shards still means two different launch
        * commands, which is worth stopping for.
        _iivw_bspool_agree, name("interval type") ///
            file(`"`path`i''"') got("`s_citype`i''")   want("`s_citype1'")
        _iivw_bspool_agree, name("confidence level") ///
            file(`"`path`i''"') got("`s_level`i''")    want("`s_level1'")
        _iivw_bspool_agree, name("package version") ///
            file(`"`path`i''"') got("`s_version`i''")  want("`s_version1'")
        _iivw_bspool_agree, name("estimation sample size") ///
            file(`"`path`i''"') got("`s_N`i''")        want("`s_N1'")
        _iivw_bspool_agree, name("coefficient names") ///
            file(`"`path`i''"') got("`s_stripe`i''")   want("`s_stripe1'")
        _iivw_bspool_agree, name("saved variable names") ///
            file(`"`path`i''"') got("`s_vars`i''")     want("`s_vars1'")

        * The observed estimates are compared as the exact strings the shards
        * wrote. Every shard fitted the same model to the same data, so they are
        * identical by construction and any difference is a real one -- a
        * tolerance here would let a genuinely different fit through.
        _iivw_bspool_agree, name("observed estimates") ///
            file(`"`path`i''"') got("`s_obs`i''")      want("`s_obs1'")
    }

    * ---- BCa: a documented scope boundary, not a silent gap ---------------
    * BCa needs a bias correction, which pools from the draws, and an
    * acceleration, which comes from a jackknife over clusters and does not.
    * Pooling the draws while keeping one shard's acceleration would report an
    * interval whose skewness correction was estimated from a fraction of the
    * evidence, under a BCa label.
    forvalues i = 1/`nshards' {
        if "`s_citype`i''" == "bca" {
            display as error "iivw_bspool cannot pool BCa intervals"
            display as error ""
            display as text "  BCa has two corrections. The bias correction z0 pools from"
            display as text "  the replicate draws. The acceleration does not: it comes from"
            display as text "  a delete-one jackknife over clusters, which each shard ran"
            display as text "  separately. Reusing one shard's acceleration on 999 pooled"
            display as text "  draws would report a skewness correction estimated from that"
            display as text "  shard's evidence alone, under a BCa label."
            display as text ""
            display as text "  Refit the shards with citype(percentile), citype(basic) or"
            display as text "  citype(wald), which pool exactly."
            error 198
        }
    }

    * ---- two shards drawn from the same RNG state ------------------------
    * The exact state bootstrap consumed is the only sound duplicate test. Two
    * shards launched with the same seed and no rngstream(), or with the same
    * seed and the same stream, drew the SAME replicates -- pooling them counts
    * one set twice and reports a Monte Carlo error the run did not earn.
    forvalues i = 1/`nshards' {
        local jstart = `i' + 1
        forvalues j = `jstart'/`nshards' {
            if "`s_rngstate`i''" == "`s_rngstate`j''" {
                display as error "iivw_bspool: two shards drew from the same RNG state"
                display as error "  `path`i''"
                display as error "  `path`j''"
                display as error ""
                display as text "  These files hold the same replicates. Give each shard its own"
                display as text "  rngstream(#) under one shared seed(), which is the mechanism"
                display as text "  Stata provides for independent substreams."
                error 459
            }
        }
    }

    * ---- accumulate -------------------------------------------------------
    forvalues i = 1/`nshards' {
        local _r = `s_req`i''
        local _d = `s_done`i''
        local _f = `s_fail`i''
        if "`_r'" == "" | `_r' >= . local _r = 0
        if "`_d'" == "" | `_d' >= . local _d = 0
        if "`_f'" == "" | `_f' >= . local _f = 0
        local sum_requested = `sum_requested' + `_r'
        local sum_completed = `sum_completed' + `_d'
        local sum_failed    = `sum_failed'    + `_f'
        local pooled_rows   = `pooled_rows'   + `s_rows`i''

        if "`s_stream`i''" != "" local streams "`streams' `s_stream`i''"
        if "`s_seed`i''"   != "" local seeds   "`seeds' `s_seed`i''"
        local statuses "`statuses' `s_status`i''"
    }

    * A shard file holding fewer rows than the shard requested was truncated --
    * the usual cause is a killed process whose every() writes left a partial
    * file behind. Pooling it would quietly produce an interval from a draw
    * count nobody chose.
    if `pooled_rows' != `sum_requested' {
        display as error "iivw_bspool: the replicate files hold `pooled_rows' draws,"
        display as error "  but the shards together requested `sum_requested'"
        display as error ""
        display as text "  A shard file with fewer rows than its own requested count was"
        display as text "  truncated, usually by a process killed mid-run while every()"
        display as text "  was flushing. Rerun the short shard; do not pool a partial one."
        error 459
    }

    if `reps' != -1 {
        if `sum_requested' != `reps' {
            display as error "iivw_bspool: reps(`reps') was asserted, but the `nshards' shards"
            display as error "  given requested `sum_requested' draws in total"
            display as error ""
            display as text "  A shard file is missing from the using list, or a shard ran"
            display as text "  with a different reps(). Both produce an interval from fewer"
            display as text "  draws than the design called for."
            error 459
        }
    }

    * =====================================================================
    * POOL
    * =====================================================================
    * Append the shards and hand the result to Stata's own bstat, the engine
    * the bootstrap prefix itself uses to turn a replicate dataset into e(b),
    * e(V) and percentile limits. Reimplementing that arithmetic here would be
    * a second copy to keep in step with Stata's; delegating makes the pooled
    * numbers identical to the unsharded run's by construction rather than by
    * agreement to some tolerance.
    tempfile pooledfile
    frame `shardfr' {
        use `"`path1'"', clear
        forvalues i = 2/`nshards' {
            append using `"`path`i''"'
        }
        quietly save `"`pooledfile'"', replace
    }

    if "`citype'" == "" {
        * The shards' own interval type, for the same reason the agreement check
        * uses it: the anchor may be a previously pooled result.
        local citype "`s_citype1'"
        if "`citype'" == "" local citype "`anchor_citype'"
        if "`citype'" == "wald-normal" local citype "wald"
        * A citype(none) fit asked for point estimates and declined an interval.
        * Defaulting one in here would hand back, unasked, exactly the interval
        * the shards refused to report.
        if "`citype'" == "none" | "`citype'" == "" {
            display as error "iivw_bspool: the shards reported no interval (citype none)"
            display as error "  the pooled draws support one, but choosing it is yours:"
            display as error "  add citype(wald), citype(percentile) or citype(basic)"
            error 198
        }
    }
    if !inlist("`citype'", "wald", "percentile", "basic") {
        display as error "iivw_bspool: citype(`citype') is not poolable"
        display as error "  allowed: wald, percentile, basic"
        error 198
    }
    * Default to the level the shards were fit at, falling back to the anchor's.
    * Neither is c(level): the pooled interval belongs to the design that
    * produced the draws, not to whatever the pooling session happens to be set
    * to.
    if "`level'" == "" {
        local level = `anchor_level'
        capture confirm integer number `s_level1'
        if !_rc local level = `s_level1'
    }

    * bstat replaces e(). Park the anchor first so every failure path below can
    * put the user's estimation results back, and so the pooled variance is
    * reposted onto the real anchor surface rather than onto bstat's.
    estimates store `anchorest'
    local _est_stored = 1

    quietly bstat using `"`pooledfile'"', notable level(`level')

    tempname Vpool CIpct Bpool
    matrix `Vpool' = e(V)
    matrix `CIpct' = e(ci_percentile)
    matrix `Bpool' = e(b)
    local pooled_done = e(N_reps)
    local pooled_fail = e(N_misreps)
    if "`pooled_fail'" == "" | `pooled_fail' >= . local pooled_fail = 0
    if "`pooled_done'" == "" | `pooled_done' >= . local pooled_done = 0
    local pooled_req = `pooled_done' + `pooled_fail'
    local bstat_names : colnames e(b)
    local bstat_eqs   : coleq   e(b)

    estimates restore `anchorest'

    * The pooled matrices must line up with the anchor's coefficient vector by
    * NAME. A silent positional mismatch here would attach each term's variance
    * to its neighbour.
    local anchor_names : colnames e(b)
    local anchor_eqs   : coleq   e(b)
    if "`bstat_names'" != "`anchor_names'" | "`bstat_eqs'" != "`anchor_eqs'" {
        display as error "iivw_bspool: pooled and anchor coefficient vectors differ"
        display as error "  pooled: `bstat_eqs' / `bstat_names'"
        display as error "  anchor: `anchor_eqs' / `anchor_names'"
        error 459
    }

    * The shards wrote their observed estimates as text, so the vector bstat
    * rebuilt from those characteristics and the anchor's own e(b) differ in the
    * last bit or two by construction. That crossing is the one place a
    * tolerance belongs, and 1e-10 is far tighter than any genuinely different
    * fit could slip through while still absorbing the text round-trip.
    local _brel = mreldif(`Bpool', e(b))
    if `_brel' > 1e-10 {
        display as error "iivw_bspool: the shards' observed estimates are not the anchor's"
        display as error "  relative difference: `_brel'"
        display as error ""
        display as text "  The anchor's own replicate file is missing from the using list,"
        display as text "  or it was fit on different data. The pooled variance would be"
        display as text "  attached to a coefficient vector the draws do not belong to."
        error 459
    }

    * The shard-count arithmetic must agree with what bstat counted in the
    * appended file. A disagreement means a stamp and its own file disagree.
    if `pooled_req' != `sum_requested' {
        display as error "iivw_bspool: bstat counted `pooled_req' draws, the stamps say `sum_requested'"
        error 459
    }
    if `pooled_fail' != `sum_failed' | `pooled_done' != `sum_completed' {
        display as error "iivw_bspool: shard replicate stamps disagree with their own files"
        display as error "  stamped completed/failed: `sum_completed'/`sum_failed'"
        display as error "  counted in the files:     `pooled_done'/`pooled_fail'"
        display as error "  a stamp was edited, or a file was rewritten after iivw_fit wrote it"
        error 459
    }

    * =====================================================================
    * POOLED FAILURE GATE
    * =====================================================================
    * The error 430 in iivw_fit fires on a single run's failures. Applying it
    * per shard and not to the pooled total would convert a hard gate into a
    * silent one: nine shards with three failures each would each pass a
    * per-shard check that the same 27 failures in one run would have stopped.
    if `pooled_fail' > 0 {
        if "`allowfailedreps'" == "" {
            display as error ""
            display as error "`pooled_fail' of `pooled_req' pooled bootstrap replicates failed"
            display as error ""
            display as text "  The pooled standard errors would be computed from the"
            display as text "  `pooled_done' replicates that returned a number. That subset is not"
            display as text "  random with respect to what is being estimated: the draws that fail"
            display as text "  are the ones carrying the least information about the very terms"
            display as text "  whose standard error you are reading. The result is"
            display as text "  anti-conservative, and nothing in the table would say so."
            display as text ""
            display as text "  Either respecify, or add"
            display as text "    allowfailedreps"
            display as text "  to declare that an SE from `pooled_done'/`pooled_req' draws is what you intend."
            error 430
        }
        display as text ""
        display as text "note: `pooled_fail' of `pooled_req' pooled bootstrap replicates failed"
        display as text "  allowfailedreps was specified: the standard errors below come from"
        display as text "  the `pooled_done' replicates that completed, and are likely anti-conservative."
    }

    * =====================================================================
    * POOLED INFERENCE STATUS
    * =====================================================================
    * Two things have to happen here and they pull in opposite directions.
    *
    * Pooling EARNS the replicate count: nine shards of 111 each honestly carry
    * uncleared-low-reps, and the 999-draw pooled result must not. So the
    * low-reps and failed-reps stamps are recomputed from the pooled totals and
    * the shards' own versions of those two are discarded.
    *
    * Pooling earns NOTHING ELSE. Every other stamp a shard carries -- an
    * uncleared build, a FIPTIW interval, a fixed-weight bootstrap -- describes
    * the estimator, not the draw count, and survives pooling untouched. The
    * pooled result therefore inherits the weakest such stamp present.
    local pooled_status ""
    if "`anchor_unw'" == "1" {
        local pooled_status "not-applicable-unweighted"
    }
    else if `pooled_fail' > 0 & "`allowfailedreps'" != "" {
        local pooled_status "uncleared-failed-reps"
    }
    else if `pooled_req' < 999 {
        local pooled_status "uncleared-low-reps"
    }
    else if "`anchor_refit'" != "1" {
        local pooled_status "uncleared-fixedweights-bootstrap"
    }
    else if inlist("`anchor_wtype'", "iivw", "iptw") {
        local pooled_status "uncleared-current-build"
    }
    else if "`anchor_wtype'" == "fiptiw" {
        local pooled_status "uncleared-fiptiw-`citype'"
    }
    else {
        local pooled_status "candidate"
    }

    _iivw_bspool_rank, status("`pooled_status'")
    local worst_rank = r(rank)
    local worst_status "`pooled_status'"
    foreach st of local statuses {
        * The two stamps pooling recomputes are exactly the two it may lift.
        if !inlist("`st'", "uncleared-low-reps", "uncleared-failed-reps") {
            _iivw_bspool_rank, status("`st'")
            if r(rank) > `worst_rank' {
                local worst_rank = r(rank)
                local worst_status "`st'"
            }
        }
    }
    local pooled_status "`worst_status'"

    * =====================================================================
    * INTERVALS FROM THE POOLED DRAWS
    * =====================================================================
    tempname CIsel CIbas
    matrix `CIsel' = e(b) \ e(b)
    matrix `CIbas' = e(b) \ e(b)
    matrix rownames `CIsel' = ll ul
    matrix rownames `CIbas' = ll ul
    matrix rownames `CIpct' = ll ul
    local kcol = colsof(e(b))
    local zcrit = invnormal((100+`level')/200)

    forvalues j = 1/`kcol' {
        matrix `CIbas'[1,`j'] = 2*el(e(b),1,`j') - el(`CIpct',2,`j')
        matrix `CIbas'[2,`j'] = 2*el(e(b),1,`j') - el(`CIpct',1,`j')
    }
    forvalues j = 1/`kcol' {
        if "`citype'" == "wald" {
            local _b  = el(e(b),1,`j')
            local _se = sqrt(el(`Vpool',`j',`j'))
            matrix `CIsel'[1,`j'] = `_b' - `zcrit'*`_se'
            matrix `CIsel'[2,`j'] = `_b' + `zcrit'*`_se'
        }
        else if "`citype'" == "percentile" {
            matrix `CIsel'[1,`j'] = el(`CIpct',1,`j')
            matrix `CIsel'[2,`j'] = el(`CIpct',2,`j')
        }
        else {
            matrix `CIsel'[1,`j'] = el(`CIbas',1,`j')
            matrix `CIsel'[2,`j'] = el(`CIbas',2,`j')
        }
    }

    * =====================================================================
    * REPOST
    * =====================================================================
    * repost replaces the covariance and leaves every other field of the anchor
    * standing, which is what makes the pooled result a genuine iivw_fit result
    * rather than a reconstruction of one. e(b) is deliberately NOT reposted:
    * the observed estimates are identical in every shard by construction, and
    * the anchor holds them at full precision.
    ereturn repost V = `Vpool'

    local ci_label "`citype'"
    if "`citype'" == "wald" local ci_label "wald-normal"
    ereturn local iivw_ci_type "`ci_label'"
    ereturn scalar level = `level'
    ereturn scalar iivw_interval_available = 1
    ereturn matrix iivw_ci          = `CIsel'
    ereturn matrix iivw_ci_percentile = `CIpct'
    ereturn matrix iivw_ci_basic    = `CIbas'

    ereturn scalar iivw_bs_reps_requested = `pooled_req'
    ereturn scalar iivw_bs_reps_completed = `pooled_done'
    ereturn scalar iivw_bs_reps_failed    = `pooled_fail'
    ereturn local  iivw_allowfailedreps = ///
        cond(`pooled_fail' > 0 & "`allowfailedreps'" != "", "1", "0")
    ereturn local  iivw_inference_status "`pooled_status'"

    * Pooled provenance. Which streams and seeds contributed, and which files,
    * so a pooled interval can be traced back to the processes that produced it
    * without reading nine logs. retokenize strips the leading space the
    * accumulator loop leaves, so a consumer can compare the list literally.
    local streams : list retokenize streams
    local seeds   : list retokenize seeds
    ereturn local iivw_bs_pooled    "1"
    ereturn local iivw_pooled_by    "iivw_bspool"
    ereturn scalar iivw_bs_shards   = `nshards'
    ereturn local iivw_bs_streams   "`streams'"
    ereturn local iivw_bs_seeds     "`seeds'"
    ereturn local iivw_bs_shard_files `"`using'"'
    ereturn local iivw_bs_anchor_breldif "`_brel'"

    * The pooled result now exists in e(). Everything below is a side effect --
    * writing a file, printing a table -- and a failure in one of those must not
    * roll back to the anchor. Marking completion here is what keeps a pooled
    * variance the user waited minutes for from vanishing over an unwritable
    * output path.
    local _completed = 1

    * =====================================================================
    * OPTIONAL: KEEP THE APPENDED REPLICATE FILE
    * =====================================================================
    if `"`_svtarget'"' != "" {
        capture copy `"`pooledfile'"' `"`_svtarget'"', `_svrepl'
        if _rc {
            display as error "iivw_bspool: could not write `_svtarget'"
            display as error "  the pooled results are in e() and are unaffected"
            error 603
        }
        * Restamp it against the POOLED result. append kept shard 1's
        * characteristics, which claim shard 1's draw count -- so the saved file
        * said 111 draws while holding 999, and the truncation guard correctly
        * refused to re-pool it. Stamping the pooled totals makes the artifact
        * describe itself, which is what saving() is for. This runs after the
        * repost, so e() is the pooled result and the stamp reads pooled values.
        _iivw_bs_stamp, file(`"`_svtarget'"')
    }

    * =====================================================================
    * DISPLAY
    * =====================================================================
    if "`table'" == "" {
        local _lb = char(123)
        local _rb = char(125)
        display as text ""
        display as text "`_lb'hline 70`_rb'"
        display as result "iivw_bspool" as text " -- pooled bootstrap variance"
        display as text "`_lb'hline 70`_rb'"
        display as text "Shards pooled:    " as result "`nshards'"
        display as text "Replicates:       " as result "`pooled_done'" ///
            as text " completed of `pooled_req' requested (`pooled_fail' failed)"
        if "`streams'" != "" {
            display as text "RNG streams:      " as result "`streams'"
        }
        display as text "Interval:         " as result "`ci_label'" ///
            as text " at `level'%"
        display as text "Inference status: " as result "`pooled_status'"
        * Pass the pooled level explicitly. The endpoints were just recomputed
        * at it, so this is a statement of fact rather than a request to relabel
        * frozen limits, and it keeps the replay from falling back on c(level).
        _iivw_fit_replay, level(`level') ///
            title("iivw_bspool -- pooled `ci_label' interval")
    }

    }
    local rc = _rc

    * Cleanup zone. bstat replaced e() partway through; if anything after that
    * failed, the user's estimation results are still parked in the stored
    * estimate and putting them back is the difference between a failed pool
    * and a lost fit.
    if `rc' != 0 & `_est_stored' & !`_completed' {
        capture estimates restore `anchorest'
        * If even that failed, say so. A user whose fit has silently vanished
        * from e() will otherwise read the pooling error, fix the file list, and
        * rerun against whatever bstat left behind.
        if _rc {
            display as error ""
            display as error "iivw_bspool: could not restore the anchor estimation results"
            display as error "  e() no longer holds your iivw_fit; refit before retrying"
        }
    }
    if `_est_stored' capture estimates drop `anchorest'
    if `_frame_open' capture frame drop `shardfr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* ---------------------------------------------------------------------------
* Cross-shard agreement check.
* ---------------------------------------------------------------------------
* One field, one message. Factored out because there are sixteen of them and a
* hand-written if/display block per field is sixteen chances to name the wrong
* field in the error text.
capture program drop _iivw_bspool_agree
program define _iivw_bspool_agree
    version 16.0
    syntax , NAme(string) File(string) [ GOT(string) WANT(string) ]
    if `"`got'"' != `"`want'"' {
        display as error "iivw_bspool: shards disagree on `name'"
        display as error "  `file'"
        display as error "    has:      `got'"
        display as error "    expected: `want'"
        display as error ""
        display as text "  Shards that disagree on this did not fit the same model to the"
        display as text "  same data. Pooling their draws would report the variance of no"
        display as text "  estimator in particular."
        error 459
    }
end

* ---------------------------------------------------------------------------
* Inference-status severity rank. Higher is weaker.
* ---------------------------------------------------------------------------
* The pooled result takes the weakest stamp present, so the stamps need a total
* order. An unrecognized stamp ranks above every known one: a status this
* version has never seen is not one it may quietly discard.
capture program drop _iivw_bspool_rank
program define _iivw_bspool_rank, rclass
    version 16.0
    syntax , STATus(string)
    local r = 6
    if "`status'" == "candidate"                        local r = 0
    else if strpos("`status'", "uncleared-fiptiw-") == 1 local r = 1
    else if "`status'" == "uncleared-current-build"     local r = 2
    else if "`status'" == "uncleared-fixedweights-bootstrap" local r = 3
    else if "`status'" == "not-applicable-unweighted"   local r = 3
    else if "`status'" == "uncleared-low-reps"          local r = 4
    else if "`status'" == "uncleared-failed-reps"       local r = 5
    return scalar rank = `r'
end

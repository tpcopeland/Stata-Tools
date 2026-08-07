* benchmark_tvbuild.do
* Registered benchmark for the Section 12.15 tvbuild performance gate.
*
* Three implementations of the same construction, on byte-identical inputs:
*
*   legacy    the frozen 1.9.0-style file-backed primitive workflow:
*             tvexpose using <file> -> save -> tvmerge <file> <file> ->
*             tvevent using <file>. Every stage round-trips through disk.
*   native    the equivalent frame-native primitive calls:
*             tvexpose frameout() -> tvmerge frames() frameout() ->
*             tvevent frame(). No .dta round trip between stages.
*   nativev   `native' plus a benchmark-local replica of the POST-CONSTRUCTION
*             validation tvbuild performs and `native' does not: the coverage
*             decision, the master payload attach, the metadata re-assertion,
*             the two-directional schema check, the structural invariants, the
*             person-survival check, the provenance characteristics, the data
*             signature, and the verified commit.
*   tvbuild    one tvbuild call doing the same construction.
*   tvbuilddry the same tvbuild call with `dryrun': the preflight alone, for THIS
*             case rather than only for the one-source form.
*
* Section 12.15a is the registered gate. G1: tvbuild/legacy is REPORTED, never
* gated -- tvbuild does a superset of legacy's work and no implementation makes
* a superset finish first. G2 is the real gate, unchanged at 5% and 0.05 s but
* re-based:
*
*     orchestration overhead = tvbuild - nativev - tvbuilddry
*
* `native' alone is the wrong base because it performs none of the validation;
* subtracting only the dry run (as the first sweep did) charges the coverage,
* schema, metadata, and signature work to orchestration. `nativev' supplies
* that missing measurement and `tvbuilddry' supplies the preflight for the same
* case, so each half of the validation is subtracted exactly once.
*
* THE REPLICA IS A THREAT TO THE GATE IT SERVES. A replica that omits work
* makes tvbuild look worse; one that adds work makes it look better. It is
* therefore written to CALL the shipped helpers where they exist
* (_tvbuild_carry_meta, _tvtools_interval_union) rather than to reimplement
* them, and its remaining operations mirror _tvbuild_combine, _tvbuild_finalize,
* and _tvbuild_commit line for line. Two deliberate departures, both disclosed:
* the id->entry/exit crosswalk frame is built BEFORE the timer starts, because
* tvbuild builds it in the preflight and `tvbuilddry' already charges it once;
* and the replica reads its committed schema off the result with one extra
* `ds' instead of carrying it from a plan, which is a variable-list operation
* whose cost does not scale with rows.
*
* Cases (Section 12.15):
*   one       one raw source, no event stage
*   two       two raw sources
*   three     three raw sources
*   mixed     one raw source plus one ready interval source
*   repeat    two specification rows against ONE shared file locator
*   evmaster  one raw source, single event taken from the master
*   evfile    one raw source, single event from a file
*   evshared  one raw source, event input reusing a source file locator
*   evrec     one raw source, recurring event stub
*   wide      one raw source, string payload and wide keepvars()
*   manifest  one raw source plus the optional manifest commit
*   dryrun    the preflight alone, tvbuild only
*
* Manually invoked; deliberately NOT part of any correctness lane and not in
* qa/_tvtools_qa_manifest.do. It emits BENCH: lines, never a RESULT: line, and
* never a timing assertion.
*
* Usage (one fresh Stata process per invocation, run serially):
*   stata-mp -b do benchmark_tvbuild.do <case> <impl> <scale> <rep>
*     case   one|two|three|mixed|repeat|evmaster|evfile|evshared|evrec|
*            wide|manifest|dryrun
*     impl   legacy | native | nativev | tvbuild | tvbuilddry
*     scale  master persons to generate (default 20000)
*     rep    repetition index (default 1)
*
* Every BENCH line reports M (master persons), E (source episode rows), and
* Nout (committed output rows) beside elapsed time, because this workload is
* output-sensitive: the same episode count produces different row counts under
* different geometries, and elapsed time without Nout is uninterpretable. Nout
* is also compared ACROSS implementations by the driver below -- three
* implementations that disagree about how many rows the workload produces are
* not three timings of the same thing.
*
* Peak resident memory is not measured from inside Stata: wrap the process in
* /usr/bin/time -v, one implementation per process.
*
* Driver for a paired sweep (serial, fresh process per run; rep 0 discarded):
*   for c in one two three mixed repeat evmaster evfile evshared evrec wide manifest; do
*     for i in legacy native nativev tvbuild tvbuilddry; do
*       for r in $(seq 0 9); do
*         /usr/bin/time -v stata-mp -b do benchmark_tvbuild.do $c $i 20000 $r
*         grep '^BENCH:' benchmark_tvbuild.log
*       done
*     done
*   done
* Keep raw logs outside the package tree; they are not tracked.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244

local case  = cond("`1'" == "", "one",    "`1'")
local impl  = cond("`2'" == "", "tvbuild", "`2'")
local scale = cond("`3'" == "", 20000, real("`3'"))
local rep   = cond("`4'" == "",     1, real("`4'"))

local qadir "`c(pwd)'"
capture ado uninstall tvtools
while !_rc {
    capture ado uninstall tvtools
}
adopath ++ "`qadir'/.."

* The generators below draw no random numbers, so no measured result depends
* on either seed. They are set and reported for protocol compliance.
set seed 20260730
set sortseed 20260730

local workdir "`c(tmpdir)'/tvp_bench_`c(pid)'"
capture mkdir "`workdir'"

* Provenance. A paired sweep run from a directory whose parent holds no
* tvtools silently resolves the INSTALLED package for every arm and reports a
* ratio of 1.00 with no error anywhere. Refuse rather than measure the wrong
* tree.
capture findfile tvbuild.ado
if _rc {
    display as error "BENCHBAD: tvbuild.ado not found on the adopath"
    exit 111
}
local _ado "`r(fn)'"
display as text "BENCHADO: `_ado'"
mata: st_local("_abs", pathresolve("`qadir'/..", ""))
if strpos("`_ado'", "`_abs'") == 0 {
    display as error "BENCHBAD: resolved `_ado', expected a file under `_abs'"
    exit 111
}

display as text "BENCHINFO: stata=`c(stata_version)' flavor=`c(flavor)' " ///
    "edition=`c(edition_real)' processors=`c(processors)' os=`c(os)' " ///
    "machine=`c(machine_type)' case=`case' impl=`impl' scale=`scale' " ///
    "rep=`rep' seed=20260730 sortseed=20260730"

**# ---------------------------------------------------------------------
**# Generators
**# ---------------------------------------------------------------------
* Geometry is fixed so that scale moves the PERSON count, never the
* per-person shape. Calendar anchor: 21915 = 01jan2020; every window is
* [21915, 22120].

capture program drop _bp_master
program define _bp_master
    version 16.0
    args nids path wide
    clear
    quietly set obs `nids'
    quietly generate long pid = _n
    quietly generate int s_entry = 21915
    quietly generate int s_exit  = 22120
    quietly generate byte female = mod(_n, 2)
    quietly generate double age = 40 + mod(_n, 40)
    quietly generate double evdate = 21960 + mod(_n, 100)
    quietly generate double evdate1 = 21960 + mod(_n, 100)
    quietly generate double evdate2 = 22030 + mod(_n, 50)
    if `wide' {
        forvalues k = 1/20 {
            quietly generate double kv`k' = _n + `k'
        }
    }
    format s_entry s_exit evdate evdate1 evdate2 %tdCCYY/NN/DD
    quietly save "`path'", replace
end

* `per' episodes per person, each 30 days long, separated by 10-day gaps,
* strictly inside the window, codes alternating 1/2 and never the reference.
* `offset' shifts the whole block so two sources are not identical.
capture program drop _bp_episodes
program define _bp_episodes
    version 16.0
    args nids per path offset stub
    clear
    quietly set obs `=`nids' * `per''
    quietly generate long pid = 1 + floor((_n - 1) / `per')
    quietly generate long seq = 1 + mod(_n - 1, `per')
    quietly generate int `stub'_start = 21920 + `offset' + (seq - 1) * 40
    quietly generate int `stub'_stop  = `stub'_start + 29
    quietly generate byte `stub'_cat = 1 + mod(seq, 2)
    format `stub'_start `stub'_stop %tdCCYY/NN/DD
    quietly drop seq
    quietly save "`path'", replace
end

* A ready interval source: one row per person covering the whole window, with
* a string categorical payload.
capture program drop _bp_ready
program define _bp_ready
    version 16.0
    args nids path
    clear
    quietly set obs `nids'
    quietly generate long pid = _n
    quietly generate int start = 21915
    quietly generate int stop  = 22120
    quietly generate str8 region = cond(mod(_n, 3) == 0, "north", ///
        cond(mod(_n, 3) == 1, "south", "east"))
    format start stop %tdCCYY/NN/DD
    quietly save "`path'", replace
end

**# ---------------------------------------------------------------------
**# Workload definition
**# ---------------------------------------------------------------------
local nids = `scale'
local per  = 3
local mf   "`workdir'/master.dta"
local e1   "`workdir'/src1.dta"
local e2   "`workdir'/src2.dta"
local e3   "`workdir'/src3.dta"
local rd   "`workdir'/ready.dta"

local widemaster = ("`case'" == "wide")
_bp_master `nids' "`mf'" `widemaster'
_bp_episodes `nids' `per' "`e1'" 0 a
if inlist("`case'", "two", "three") _bp_episodes `nids' `per' "`e2'" 10 b
if "`case'" == "three" _bp_episodes `nids' `per' "`e3'" 20 c
if "`case'" == "mixed" _bp_ready `nids' "`rd'"

local nsrc = 1
if "`case'" == "two"    local nsrc = 2
if "`case'" == "three"  local nsrc = 3
if "`case'" == "mixed"  local nsrc = 2
if "`case'" == "repeat" local nsrc = 2

local evkind "none"
if "`case'" == "evmaster" local evkind "master"
if "`case'" == "evfile"   local evkind "file"
if "`case'" == "evshared" local evkind "shared"
if "`case'" == "evrec"    local evkind "recurring"

local keeplist ""
if `widemaster' {
    forvalues k = 1/20 {
        local keeplist "`keeplist' kv`k'"
    }
    local keeplist "`keeplist' female age"
}

local nepi = `nids' * `per' * cond("`case'" == "three", 3, ///
    cond(inlist("`case'", "two"), 2, 1))

* Which frame each committed payload column came from, for the nativev
* replica's per-source carry_meta visits. Positional, one entry per source.
* The payload a source actually contributes. `mixed' is the case this has to
* exist for: its second source is a READY interval table whose payload is the
* string variable `region', not a constructed tv_* exposure. The legacy and
* native arms asked tvmerge for `tv_b' regardless and failed with r(111), "No
* exposure variables found" -- which went unseen because Section 12.18 swept
* only one/two/evfile/manifest and never ran this case in any arm.
local exp2 "tv_b"
if "`case'" == "mixed" local exp2 "region"

local vpayframes "nf1"
local vpayvars   "tv_a"
if `nsrc' >= 2 {
    local vpayframes "`vpayframes' nf2"
    local vpayvars   "`vpayvars' `exp2'"
}
if `nsrc' >= 3 {
    local vpayframes "`vpayframes' nf3"
    local vpayvars   "`vpayvars' tv_c"
}

**# ---------------------------------------------------------------------
**# Implementations
**# ---------------------------------------------------------------------
timer clear 1
local nout = .

if "`impl'" == "legacy" {
    **# Frozen 1.9.0-style file-backed primitive workflow
    timer on 1
    use "`mf'", clear
    quietly tvexpose using "`e1'", id(pid) start(a_start) stop(a_stop) ///
        exposure(a_cat) reference(0) entry(s_entry) exit(s_exit) ///
        generate(tv_a)
    quietly rename (a_start a_stop) (s1 p1)
    quietly save "`workdir'/o1.dta", replace

    if `nsrc' >= 2 & "`case'" != "mixed" & "`case'" != "repeat" {
        use "`mf'", clear
        quietly tvexpose using "`e2'", id(pid) start(b_start) stop(b_stop) ///
            exposure(b_cat) reference(0) entry(s_entry) exit(s_exit) ///
            generate(tv_b)
        quietly rename (b_start b_stop) (s2 p2)
        quietly save "`workdir'/o2.dta", replace
    }
    if "`case'" == "three" {
        use "`mf'", clear
        quietly tvexpose using "`e3'", id(pid) start(c_start) stop(c_stop) ///
            exposure(c_cat) reference(0) entry(s_entry) exit(s_exit) ///
            generate(tv_c)
        quietly rename (c_start c_stop) (s3 p3)
        quietly save "`workdir'/o3.dta", replace
    }
    if "`case'" == "mixed" {
        use "`rd'", clear
        quietly rename (start stop) (s2 p2)
        quietly save "`workdir'/o2.dta", replace
    }
    if "`case'" == "repeat" {
        use "`mf'", clear
        quietly tvexpose using "`e1'", id(pid) start(a_start) stop(a_stop) ///
            exposure(a_cat) reference(0) entry(s_entry) exit(s_exit) ///
            generate(tv_b)
        quietly rename (a_start a_stop) (s2 p2)
        quietly save "`workdir'/o2.dta", replace
    }

    if `nsrc' == 1 {
        use "`workdir'/o1.dta", clear
        quietly rename (s1 p1) (start stop)
    }
    else if `nsrc' == 2 {
        clear
        quietly tvmerge "`workdir'/o1.dta" "`workdir'/o2.dta", id(pid) ///
            start(s1 s2) stop(p1 p2) exposure(tv_a `exp2') idname(pid) ///
            startname(start) stopname(stop)
    }
    else {
        clear
        quietly tvmerge "`workdir'/o1.dta" "`workdir'/o2.dta" ///
            "`workdir'/o3.dta", id(pid) start(s1 s2 s3) stop(p1 p2 p3) ///
            exposure(tv_a tv_b tv_c) idname(pid) startname(start) stopname(stop)
    }

    if "`evkind'" != "none" {
        quietly save "`workdir'/iv.dta", replace
        use "`mf'", clear
        if "`evkind'" == "recurring" {
            quietly tvevent using "`workdir'/iv.dta", id(pid) date(evdate) ///
                type(recurring) start(start) stop(stop) generate(_failure)
        }
        else {
            quietly tvevent using "`workdir'/iv.dta", id(pid) date(evdate) ///
                type(single) start(start) stop(stop) generate(_failure)
        }
    }
    local nout = _N
    timer off 1
}
else if inlist("`impl'", "native", "nativev") {
    **# Equivalent frame-native primitive calls
    * The crosswalk of person -> study window is built OUTSIDE the timer for
    * the nativev arm: tvbuild builds it in the preflight, which the tvbuilddry
    * arm charges once. Building it here too would subtract it twice and
    * flatter tvbuild.
    if "`impl'" == "nativev" {
        capture frame drop vxw
        frame create vxw
        frame vxw {
            quietly use pid s_entry s_exit using "`mf'", clear
            quietly rename (s_entry s_exit) (ventry vexit)
        }
        capture frame drop vmst
        frame create vmst
        frame vmst: quietly use "`mf'", clear
    }

    timer on 1
    use "`mf'", clear
    quietly tvexpose using "`e1'", id(pid) start(a_start) stop(a_stop) ///
        exposure(a_cat) reference(0) entry(s_entry) exit(s_exit) ///
        generate(tv_a) frameout(nf1) replace
    frame nf1: quietly rename (a_start a_stop) (s1 p1)

    if inlist("`case'", "two", "three") {
        use "`mf'", clear
        quietly tvexpose using "`e2'", id(pid) start(b_start) stop(b_stop) ///
            exposure(b_cat) reference(0) entry(s_entry) exit(s_exit) ///
            generate(tv_b) frameout(nf2) replace
        frame nf2: quietly rename (b_start b_stop) (s2 p2)
    }
    if "`case'" == "three" {
        use "`mf'", clear
        quietly tvexpose using "`e3'", id(pid) start(c_start) stop(c_stop) ///
            exposure(c_cat) reference(0) entry(s_entry) exit(s_exit) ///
            generate(tv_c) frameout(nf3) replace
        frame nf3: quietly rename (c_start c_stop) (s3 p3)
    }
    if "`case'" == "mixed" {
        capture frame drop nf2
        frame create nf2
        frame nf2: quietly use "`rd'", clear
        frame nf2: quietly rename (start stop) (s2 p2)
    }
    if "`case'" == "repeat" {
        use "`mf'", clear
        quietly tvexpose using "`e1'", id(pid) start(a_start) stop(a_stop) ///
            exposure(a_cat) reference(0) entry(s_entry) exit(s_exit) ///
            generate(tv_b) frameout(nf2) replace
        frame nf2: quietly rename (a_start a_stop) (s2 p2)
    }

    capture frame drop nvoid
    frame create nvoid
    if `nsrc' == 1 {
        frame copy nf1 nout, replace
        frame nout: quietly rename (s1 p1) (start stop)
    }
    else if `nsrc' == 2 {
        frame change nvoid
        quietly tvmerge, frames(nf1 nf2) id(pid) start(s1 s2) stop(p1 p2) ///
            exposure(tv_a `exp2') idname(pid) startname(start) stopname(stop) ///
            frameout(nout) replace
    }
    else {
        frame change nvoid
        quietly tvmerge, frames(nf1 nf2 nf3) id(pid) start(s1 s2 s3) ///
            stop(p1 p2 p3) exposure(tv_a tv_b tv_c) idname(pid) ///
            startname(start) stopname(stop) frameout(nout) replace
    }

    if "`evkind'" != "none" {
        frame change default
        use "`mf'", clear
        if "`evkind'" == "recurring" {
            quietly tvevent, frame(nout) id(pid) date(evdate) ///
                type(recurring) start(start) stop(stop) generate(_failure)
        }
        else {
            quietly tvevent, frame(nout) id(pid) date(evdate) ///
                type(single) start(start) stop(stop) generate(_failure)
        }
        local nout = _N
        local resf "`c(frame)'"
    }
    else {
        frame change nout
        local nout = _N
        local resf "nout"
    }

    if "`impl'" == "nativev" {
        **# --- Validation replica: _tvbuild_combine, coverage half ------------
        frame change `resf'
        quietly frlink m:1 pid, frame(vxw)
        quietly frget vent = ventry, from(vxw)
        quietly frget vexi = vexit,  from(vxw)
        capture drop vxw
        quietly count if missing(vent)
        local _orph = r(N)

        sort pid start stop
        tempvar vtag vovl vrt
        quietly by pid: generate byte `vovl' = ///
            (_n > 1) & (start <= stop[_n-1])
        quietly count if `vovl' == 1
        local _n_ovl = r(N)
        quietly by pid: generate byte `vtag' = (_n == 1)
        local _exact = 0
        if `_n_ovl' == 0 {
            quietly by pid: egen double `vrt' = total(stop - start + 1)
            quietly count if `vtag' & `vrt' != (vexi - vent + 1)
            if r(N) == 0 local _exact = 1
            drop `vrt'
        }
        if `_exact' {
            quietly count if `vtag'
            local _n_pers = r(N)
            drop `vtag' `vovl' vent vexi
        }
        else {
            drop `vtag' `vovl'
            quietly _tvtools_interval_union, id(pid) start(start) stop(stop) ///
                cliplow(vent) cliphigh(vexi) uniondays(vuni)
            tempvar vtag2 vshort
            quietly egen byte `vtag2' = tag(pid)
            quietly generate double `vshort' = ///
                (vexi - vent + 1) - vuni if `vtag2'
            quietly count if `vtag2' & `vshort' > 0 & !missing(`vshort')
            local _gap_ids = r(N)
            quietly summarize `vshort' if `vtag2' & `vshort' > 0, meanonly
            quietly count if `vtag2'
            local _n_pers = r(N)
            drop `vtag2' `vshort' vuni vent vexi
        }
        sort pid start stop

        **# --- Validation replica: _tvbuild_finalize -----------------------
        quietly frlink m:1 pid, frame(vxw)
        quietly frget ventry = ventry, from(vxw)
        quietly frget vexit  = vexit,  from(vxw)
        capture drop vxw
        quietly count if missing(ventry) | missing(vexit)
        quietly _tvbuild_carry_meta, srcframe(vxw) dstframe(`resf') ///
            vars(ventry vexit)

        quietly recast double start
        quietly recast double stop
        format start %tdCCYY/NN/DD
        format stop  %tdCCYY/NN/DD
        label variable start "Interval start"
        label variable stop  "Interval stop"
        quietly _tvbuild_carry_meta, srcframe(vxw) dstframe(`resf') vars(pid)
        * One carry_meta visit per normalised source, exactly as
        * _tvbuild_finalize performs, sourced from the frame the payload
        * actually came from.
        forvalues _k = 1/`nsrc' {
            local _pf : word `_k' of `vpayframes'
            local _pv : word `_k' of `vpayvars'
            quietly _tvbuild_carry_meta, srcframe(`_pf') dstframe(`resf') ///
                vars(`_pv')
        }

        * One extra `ds' stands in for tvbuild's planned schema. It is a
        * variable-list operation; its cost does not scale with rows.
        quietly ds
        local vschema "`r(varlist)'"
        order `vschema'
        quietly ds
        local vpresent "`r(varlist)'"
        local vextra   : list vpresent - vschema
        local vmissing : list vschema - vpresent

        quietly count if missing(start) | missing(stop)
        quietly count if start > stop
        local _n_out = _N
        tempvar vtag3
        quietly egen byte `vtag3' = tag(pid)
        quietly count if `vtag3'
        local _n_pers = r(N)
        drop `vtag3'
        frame change vmst
        local _n_master = _N
        local _dtalab : data label
        frame change `resf'
        if `_n_pers' != `_n_master' {
            display as error "BENCHBAD: nativev lost persons"
            exit 111
        }
        if `"`_dtalab'"' != "" label data `"`_dtalab'"'
        char _dta[tvtools_tvbuild]           "tvbuild"
        char _dta[tvtools_tvbuild_schema]    "1"
        char _dta[tvtools_tvbuild_coverage]  "strict"
        char _dta[tvtools_tvbuild_start]     "start"
        char _dta[tvtools_tvbuild_stop]      "stop"
        char _dta[tvtools_tvbuild_event]     ""
        char _dta[tvtools_tvbuild_committed] "1"
        sort pid start stop
        quietly datasignature
        local vsig "`r(datasignature)'"

        **# --- Validation replica: _tvbuild_commit -------------------------
        quietly frame copy `resf' vcommit, replace
        frame change vcommit
        local _n_committed = _N
        quietly ds
        local vpresent2 "`r(varlist)'"
        quietly datasignature
        local vsig2 "`r(datasignature)'"
        local vbuildchar : char _dta[tvtools_tvbuild]
        frame change `resf'
        local vextra2   : list vpresent2 - vschema
        local vmissing2 : list vschema - vpresent2
        if `_n_committed' != `_n_out' | "`vextra2'`vmissing2'" != "" | ///
           "`vsig2'" != "`vsig'" | "`vbuildchar'" != "tvbuild" {
            display as error "BENCHBAD: nativev commit verification failed"
            exit 111
        }
        local nout = `_n_out'
    }
    timer off 1
}
else {
    **# tvbuild
    * The specification frame is built before the timer starts. It describes
    * the work; building it is the user's, not the command's.
    if `nsrc' > 1 | "`case'" == "mixed" | "`case'" == "repeat" {
        capture frame drop pspec
        frame create pspec
        frame pspec {
            quietly set obs `nsrc'
            quietly generate str32 source_name  = "s" + string(_n)
            quietly generate str12 source_kind  = "episodes"
            quietly generate str32 source_frame = ""
            quietly generate strL  source_file  = ""
            quietly generate str32 start_var    = ""
            quietly generate str32 stop_var     = ""
            quietly generate strL  input_vars   = ""
            quietly generate strL  output_vars  = "tv_" + string(_n)
            quietly generate double reference   = 0
            quietly replace source_file = "`e1'" in 1
            quietly replace start_var = "a_start" in 1
            quietly replace stop_var  = "a_stop"  in 1
            quietly replace input_vars = "a_cat"  in 1
            if "`case'" == "two" | "`case'" == "three" {
                quietly replace source_file = "`e2'" in 2
                quietly replace start_var = "b_start" in 2
                quietly replace stop_var  = "b_stop"  in 2
                quietly replace input_vars = "b_cat"  in 2
            }
            if "`case'" == "three" {
                quietly replace source_file = "`e3'" in 3
                quietly replace start_var = "c_start" in 3
                quietly replace stop_var  = "c_stop"  in 3
                quietly replace input_vars = "c_cat"  in 3
            }
            if "`case'" == "mixed" {
                quietly replace source_kind = "intervals" in 2
                quietly replace source_file = "`rd'" in 2
                quietly replace start_var = "start" in 2
                quietly replace stop_var  = "stop"  in 2
                quietly replace input_vars = "region" in 2
                quietly replace reference = . in 2
            }
            if "`case'" == "repeat" {
                quietly replace source_file = "`e1'" in 2
                quietly replace start_var = "a_start" in 2
                quietly replace stop_var  = "a_stop"  in 2
                quietly replace input_vars = "a_cat"  in 2
            }
        }
    }

    local _ev ""
    if "`evkind'" == "master"    local _ev "eventdate(evdate)"
    if "`evkind'" == "file"      local _ev "eventusing(`mf') eventdate(evdate)"
    if "`evkind'" == "shared"    local _ev "eventusing(`mf') eventdate(evdate)"
    if "`evkind'" == "recurring" local _ev "eventdate(evdate) eventtype(recurring)"
    local _man ""
    if "`case'" == "manifest" local _man "manifestframe(pman)"
    local _keep ""
    if "`keeplist'" != "" local _keep "keepvars(`keeplist')"
    local _dry ""
    if "`case'" == "dryrun" | "`impl'" == "tvbuilddry" local _dry "dryrun"

    timer on 1
    use "`mf'", clear
    if `nsrc' > 1 | "`case'" == "mixed" | "`case'" == "repeat" {
        quietly tvbuild, specframe(pspec) id(pid) entry(s_entry) exit(s_exit) ///
            frameout(pout) replace `_ev' `_man' `_keep' `_dry'
    }
    else {
        quietly tvbuild, sourceusing("`e1'") id(pid) entry(s_entry) ///
            exit(s_exit) start(a_start) stop(a_stop) exposure(a_cat) ///
            reference(0) generate(tv_1) frameout(pout) replace ///
            `_ev' `_man' `_keep' `_dry'
    }
    local nout = cond("`_dry'" != "", 0, r(N_periods))
    timer off 1
}

quietly timer list 1
local elapsed = r(t1)

display as text "BENCH: case=`case' impl=`impl' scale=`scale' rep=`rep' " ///
    "M=`nids' E=`nepi' nsrc=`nsrc' event=`evkind' Nout=`nout' " ///
    "elapsed=" %9.4f `elapsed'

capture erase "`workdir'/o1.dta"
capture erase "`workdir'/o2.dta"
capture erase "`workdir'/o3.dta"
capture erase "`workdir'/iv.dta"
capture erase "`mf'"
capture erase "`e1'"
capture erase "`e2'"
capture erase "`e3'"
capture erase "`rd'"
capture rmdir "`workdir'"

*! test_rangematch_backend_diff.do
*! A1 differential harness: the sweep and binary backends must agree on the
*! exact pair set, every r() scalar, and every r() option macro, across the
*! full option cross-product.
*!
*! The header used to promise "every r() scalar" while the grid never passed
*! `stats' and the comparison covered three scalars: N_pairs, N_matched_pairs,
*! N_unmatched (RM-I21). The twelve stats-conditional scalars were not merely
*! unchecked -- they were never returned, so no number of cells could have
*! caught backend drift in them. Both runs now request `stats', all 22 scalars
*! and 15 option macros are compared, and a floor on the count of non-missing
*! comparisons stops the grid passing vacuously if that surface ever collapses.
*!
*! Point-in-interval semantics: keyvar is the USING-side point; low/high are
*! MASTER-side interval bounds. A using row matches a master row when the
*! using key falls inside the master [low, high] (per closed()/tolerance()).
*!
*! Backend selection levers (see rangematch.ado / _rangematch_mata.ado):
*!   - sweep : default point-in-interval call on a SORTABLE master
*!             (nearest_code==0 & !overlap & sweep can ready the master).
*!   - binary: nosort on a master NOT pre-sorted by (by, low) -> sweep cannot
*!             ready without sorting (sweepsort disallowed) -> binary path.
*! Each run asserts r(backend) so a broken lever fails loudly instead of
*! silently comparing sweep-to-sweep.

version 16.1
clear all
set more off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}

* -------------------------------------------------------------------
* Fixed, reproducible data exercising every branch: ties on the using
* key, open-ended master rows (missing var bounds), multiple by-groups
* (incl. a master group with no using rows: grp 4), and unmatched rows
* on both sides.
* -------------------------------------------------------------------
tempfile USING MASTER

* Using data: point variable is `key`
clear
set obs 60
set seed 9412
gen int    grp = 1 + mod(_n, 3)            // using groups 1,2,3
gen double key = floor(runiform()*40)      // integer points 0..39, many ties
gen long   uid = _n
gen str8   ulab = "u" + string(_n)
save "`USING'"

* Master A: VARIABLE-width intervals. After sort by (grp, lo), hi is not
* monotonic -> sweep uses sweep_mode 1 (binary right bound).
clear
set obs 40
set seed 2718
gen int    grp = 1 + mod(_n, 4)            // master groups 1..4 (4 absent in using)
gen double lo  = floor(runiform()*35)
gen double wid = floor(runiform()*6)
gen double hi  = lo + wid
drop wid
gen long   mid0 = _n
* Inject open-ended bounds (missing var -> wildcard side under missing(wildcard))
replace lo = . in 3
replace hi = . in 7
replace lo = . in 11
replace hi = . in 11                       // fully open row
save "`MASTER'"

* Master B: FIXED-width intervals (hi = lo + 5). After sort by (grp, lo), hi is
* monotonic -> sweep uses sweep_mode 2 (the monotonic right-pointer sweep).
tempfile MASTER2
clear
set obs 40
set seed 31415
gen int    grp = 1 + mod(_n, 4)
gen double lo  = floor(runiform()*35)
gen double hi  = lo + 5
gen long   mid0 = _n
replace lo = . in 5                         // one open-below row (still mostly monotonic)
save "`MASTER2'"

* -------------------------------------------------------------------
* Helper: run one cell with both backends and compare.
* -------------------------------------------------------------------
* The full documented return surface, split by kind. Backend-invariant by
* contract: whichever pair-generation backend runs, every one of these must
* agree. r(backend) is deliberately absent -- it is the one value the two runs
* are SUPPOSED to disagree on, and it is asserted separately.
global RM_DIFF_SCALARS ///
    N_master N_using N_pairs N_unmatched N_matched_pairs ///
    N_missing_bounds N_master_key_missing N_using_missing N_using_inverted ///
    N_matched_master N_matched_using N_unmatched_master N_unmatched_using ///
    max_matches mean_matches median_matches p50_matches p90_matches ///
    p99_matches N_empty_groups N_master_groups tolerance
global RM_DIFF_MACROS ///
    using_source key low high by keepusing prefix suffix unmatched ///
    closed missing nearest ties assert generate

* Snapshot the whole r() surface under a prefix, immediately after a rangematch
* call and before anything else touches r().
*
* NOTE: `local v = r(absent)' yields `.' at rc=0 -- a missing r() scalar is
* indistinguishable from one that exists and is missing. So a naive sw-vs-bin
* comparison over this list PASSES VACUOUSLY when neither side returned the
* scalar. The driver counts non-missing comparisons for exactly that reason.
capture program drop _rm_capture_returns
program define _rm_capture_returns, rclass
    args pfx
    foreach s of global RM_DIFF_SCALARS {
        local v = r(`s')
        return scalar `pfx'_`s' = `v'
    }
    foreach m of global RM_DIFF_MACROS {
        return local `pfx'_`m' `"`r(`m')'"'
    }
    return local `pfx'_backend `"`r(backend)'"'
end

capture program drop _rm_diff_cell
program define _rm_diff_cell, rclass
    args master using cl tol bystr unm openmode
    tempfile SW BIN

    if "`openmode'" == "vars"  local spec "key lo hi"
    if "`openmode'" == "litlo" local spec "key . hi"
    if "`openmode'" == "lithi" local spec "key lo ."

    * Compare on STABLE keys (mid0 master id carried as a master var; uid via
    * keepusing). masterid()/usingid() are in-memory positions and so differ
    * once the binary run shuffles the master -- not usable for comparison.

    * Both runs request `stats' (RM-I21). Without it, rangematch never returns
    * the twelve conditional statistics scalars at all, so a differential grid
    * that omits it cannot compare them no matter how many cells it runs -- and
    * this suite claimed to compare "every r() scalar" while doing exactly that.
    local rmopts `bystr' keepusing(uid ulab) closed(`cl') tolerance(`tol') ///
        unmatched(`unm') stats

    * ===== SWEEP run (default sort, sortable master) =====
    use "`master'", clear
    sort mid0
    quietly rangematch `spec' using "`using'", `rmopts'
    _rm_capture_returns sw
    return add
    keep mid0 uid
    gsort mid0 uid
    save "`SW'"

    * ===== BINARY run (nosort + shuffled, non-(by,low)-sorted master) =====
    use "`master'", clear
    set seed 13
    gen double _shuf = runiform()
    sort _shuf
    drop _shuf
    quietly rangematch `spec' using "`using'", `rmopts' nosort
    _rm_capture_returns bin
    return add
    keep mid0 uid
    gsort mid0 uid
    save "`BIN'"

    * Compare the saved pair sets row-for-row.
    *
    * `cf _all' compares only the MASTER's varlist, so it is blind to a
    * variable the other file lacks. Both files are reduced to exactly
    * (mid0, uid) above, and the row counts are compared explicitly below, so
    * that blindness cannot hide a difference here.
    use "`SW'", clear
    local sw_N = _N
    capture cf _all using "`BIN'"
    return scalar cf_rc = _rc
    use "`BIN'", clear
    return scalar n_sw  = `sw_N'
    return scalar n_bin = _N
end

* -------------------------------------------------------------------
* Drive the cross-product.
* -------------------------------------------------------------------
local nfail 0
local ncmp  0
local nskip 0
local nreal 0
local ncellfail 0
foreach mf in "`MASTER'" "`MASTER2'" {
foreach cl in both left right none {
  foreach tol in 0 0.4 {
    foreach by in "" "by(grp)" {
      foreach unm in master none using both {
        foreach om in vars litlo lithi {
            _rm_diff_cell "`mf'" "`USING'" "`cl'" "`tol'" "`by'" "`unm'" "`om'"

            local swb  = r(sw_backend)
            local binb = r(bin_backend)
            local cfrc = r(cf_rc)
            local tag  "closed(`cl') tol(`tol') `by' unm(`unm') open(`om')"

            * Sweep run must always be the sweep backend.
            if "`swb'" != "sweep" {
                di as error "LEVER FAIL [sweep] got backend=`swb' :: `tag'"
                local ++nfail
            }
            * The nosort lever forces binary only when low is non-constant
            * (litlo/lithi make low all-equal -> master trivially sorted ->
            * sweep stays ready). Compare only when binary actually engaged.
            if "`binb'" != "binary" {
                local ++nskip
            }
            else {
                local ++ncmp
                local cellfail 0

                * Every scalar in the documented surface, not a hand-picked
                * three. `nreal' counts comparisons where at least one side is
                * non-missing, so a grid that silently stopped returning the
                * stats scalars would show up as a collapse in nreal instead of
                * passing quietly on `.' == `.'.
                foreach s of global RM_DIFF_SCALARS {
                    local a = r(sw_`s')
                    local b = r(bin_`s')
                    if !missing(`a') | !missing(`b') local ++nreal
                    if `a' != `b' {
                        di as error "SCALAR MISMATCH r(`s') :: `tag'"
                        di as error "  sw=`a'  bin=`b'"
                        local ++nfail
                        local cellfail 1
                    }
                }

                * Return macros must be backend-invariant too: an option echoed
                * differently by one backend is a contract break even when the
                * pair set matches.
                foreach m of global RM_DIFF_MACROS {
                    local a `"`r(sw_`m')'"'
                    local b `"`r(bin_`m')'"'
                    if `"`a'"' != `"`b'"' {
                        di as error "MACRO MISMATCH r(`m') :: `tag'"
                        di as error `"  sw=[`a']  bin=[`b']"'
                        local ++nfail
                        local cellfail 1
                    }
                }

                * Row counts, compared explicitly because `cf _all' is blind to
                * a variable the comparison file does not have.
                if r(n_sw) != r(n_bin) {
                    di as error "PAIR-COUNT MISMATCH :: `tag' sw=" r(n_sw) " bin=" r(n_bin)
                    local ++nfail
                    local cellfail 1
                }
                if `cfrc' != 0 {
                    di as error "PAIR-SET MISMATCH (cf rc=`cfrc') :: `tag'"
                    local ++nfail
                    local cellfail 1
                }
                if `cellfail' local ++ncellfail
            }
        }
      }
    }
  }
}
}

di as txt "backend_diff compared: `ncmp'   skipped(lever n/a): `nskip'   failures: `nfail'"
di as txt "backend_diff scalar comparisons with a non-missing side: `nreal'"

* Anti-vacuity gate (RM-I21). Comparing `.' to `.' passes and proves nothing,
* so a regression that stopped rangematch returning the stats scalars would
* leave every comparison trivially equal and this grid green.
*
* The arithmetic matters, and the first draft of this gate got it wrong. All 22
* scalars are live per cell when both runs pass `stats' (measured: 7040 = 320 x
* 22). Drop `stats' and exactly 10 survive -- so a floor of 10 x ncmp sits ON
* the collapse value and `3200 < 3200' is false: the gate would have waved
* through the very regression it exists to catch. Put the floor between the two
* regimes instead.
local nreal_floor = 15 * `ncmp'
if `ncmp' > 0 & `nreal' < `nreal_floor' {
    di as error "test_rangematch_backend_diff: only `nreal' non-missing scalar comparisons"
    di as error "expected at least `nreal_floor' across `ncmp' cells -- the r() surface"
    di as error "collapsed, so the comparisons above were passing vacuously"
    exit 9
}
* Terminal sentinel (RM-I20). `ncmp' is the honest test count: cells where the
* binary backend actually engaged and a comparison was therefore made. Skipped
* cells are NOT counted as passes -- a skip is not a pass, and reporting them
* as tests would let this suite advertise coverage it did not perform.
* Sentinel counts CELLS, consistently. `nfail' counts individual mismatched
* comparisons and can exceed the cell count many times over (one broken
* backend produced 3840 across 320 cells), so using it as the fail field
* printed a NEGATIVE pass count. Report cells failed; keep the comparison
* detail on its own line.
display "RESULT: rangematch_backend_diff tests=`ncmp' pass=`=`ncmp' - `ncellfail'' fail=`ncellfail' skip=`nskip'"
di as txt "backend_diff mismatched comparisons: `nfail'"

if `ncmp' == 0 {
    di as error "test_rangematch_backend_diff: NO cells exercised the binary backend"
    exit 9
}
if `nfail' > 0 {
    di as error "test_rangematch_backend_diff: FAILED (`nfail' failures)"
    exit 9
}
di as result "test_rangematch_backend_diff: PASSED (`ncmp' cells, sweep==binary)"

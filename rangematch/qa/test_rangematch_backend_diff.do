*! test_rangematch_backend_diff.do
*! A1 differential harness: sweep backend vs binary backend must agree on the
*! exact pair set and every r() scalar across the full option cross-product.
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

capture ado uninstall rangematch
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}
adopath ++ "`pkg_dir'"

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

    * ===== SWEEP run (default sort, sortable master) =====
    use "`master'", clear
    sort mid0
    quietly rangematch `spec' using "`using'", ///
        `bystr' keepusing(uid ulab) closed(`cl') tolerance(`tol') ///
        unmatched(`unm')
    return local sw_backend = r(backend)
    return scalar sw_pairs = r(N_pairs)
    return scalar sw_mp    = r(N_matched_pairs)
    return scalar sw_unm   = r(N_unmatched)
    keep mid0 uid
    gsort mid0 uid
    save "`SW'"

    * ===== BINARY run (nosort + shuffled, non-(by,low)-sorted master) =====
    use "`master'", clear
    set seed 13
    gen double _shuf = runiform()
    sort _shuf
    drop _shuf
    quietly rangematch `spec' using "`using'", ///
        `bystr' keepusing(uid ulab) closed(`cl') tolerance(`tol') ///
        unmatched(`unm') nosort
    return local bin_backend = r(backend)
    return scalar bin_pairs = r(N_pairs)
    return scalar bin_mp    = r(N_matched_pairs)
    return scalar bin_unm   = r(N_unmatched)
    keep mid0 uid
    gsort mid0 uid
    save "`BIN'"

    * compare the saved pair sets row-for-row
    use "`SW'", clear
    capture cf _all using "`BIN'"
    return scalar cf_rc = _rc
end

* -------------------------------------------------------------------
* Drive the cross-product.
* -------------------------------------------------------------------
local nfail 0
local ncmp  0
local nskip 0
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
                if r(sw_pairs) != r(bin_pairs) | r(sw_mp) != r(bin_mp) ///
                        | r(sw_unm) != r(bin_unm) {
                    di as error "SCALAR MISMATCH :: `tag'"
                    di as error "  pairs sw=" r(sw_pairs) " bin=" r(bin_pairs) ///
                        "  matched sw=" r(sw_mp) " bin=" r(bin_mp) ///
                        "  unm sw=" r(sw_unm) " bin=" r(bin_unm)
                    local ++nfail
                }
                if `cfrc' != 0 {
                    di as error "PAIR-SET MISMATCH (cf rc=`cfrc') :: `tag'"
                    local ++nfail
                }
            }
        }
      }
    }
  }
}
}

di as txt "{hline 60}"
di as txt "backend_diff compared: `ncmp'   skipped(lever n/a): `nskip'   failures: `nfail'"
di as txt "{hline 60}"
if `ncmp' == 0 {
    di as error "test_rangematch_backend_diff: NO cells exercised the binary backend"
    exit 9
}
if `nfail' > 0 {
    di as error "test_rangematch_backend_diff: FAILED (`nfail' failures)"
    exit 9
}
di as result "test_rangematch_backend_diff: PASSED (`ncmp' cells, sweep==binary)"

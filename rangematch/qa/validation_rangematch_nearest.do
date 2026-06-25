* validation_rangematch_nearest.do — known-answer validation of nearest() mode
* against an independent brute-force joinby oracle.
*
* The point and overlap backends each have a randomized brute-force parity check
* (validation_rangematch_oracle.do, test_rangematch_overlap.do). The nearest
* backend previously had only fixed hand-computed known answers. This file adds
* the matching randomized oracle for nearest(), the trickiest backend (signed
* distance, directional selection, equidistant ties).
*
* Independent characterization of nearest() with ties(all), derived from first
* principles (NOT from rangematch). For each master row with key mkey and window
* [lo,hi], among the in-range using rows:
*   nearest(both)   -> rows minimizing |ukey - mkey|
*   nearest(before) -> rows at max{ukey : ukey <= mkey}  (closest at/below)
*   nearest(after)  -> rows at min{ukey : ukey >= mkey}  (closest at/above)
* All keys are integers here, so the min-distance comparisons are exact.
clear all
version 17.0
set varabbrev off

capture ado uninstall rangematch
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local qa_dir "`cwd'"
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
    local qa_dir "`pkg_dir'/qa"
}
quietly net install rangematch, from("`pkg_dir'") replace

local test_count = 0

**# 1. Fixed hand-computed nearest(both) known answer
* Master key 10 in window [5,15]; using keys 8,8,12,12,20.
* In range: 8,8,12,12 (20 excluded). Nearest to 10: 8 and 12, both |d|=2 ->
* all four rows match; signed delta = ukey-mkey = -2 (for 8) and +2 (for 12).
local ++test_count
tempfile fix_using
clear
input int uid double xkey
1  8
2  8
3 12
4 12
5 20
end
save "`fix_using'", replace

clear
input int mid double(xkey lo hi)
1 10 5 15
end
rangematch xkey lo hi using "`fix_using'", keepusing(uid) ///
    nearest(both) ties(all) unmatched(none) distance(delta)
sort mid uid
assert _N == 4
assert uid[1] == 1 & delta[1] == -2
assert uid[2] == 2 & delta[2] == -2
assert uid[3] == 3 & delta[3] ==  2
assert uid[4] == 4 & delta[4] ==  2
display as result "PASS: fixed nearest(both) ties(all) known answer"

**# 2. Randomized parity vs independent joinby oracle
* Sweep seeds x direction x closed mode; compare matched (mid,uid) pairs and
* verify the signed distance delta == ukey - mkey on every matched row.
tempfile m urm uorc rm_pairs ex_pairs

foreach seed in 11 4242 90210 {
    foreach dir in both before after {
        foreach cl in both none {
            local ++test_count

            * Master: 5 by-groups, integer key and window
            clear
            set seed `seed'
            set obs 60
            gen long id  = mod(_n, 5) + 1
            gen long mid = _n
            gen double xkey = floor(runiform() * 100)
            gen double lo = xkey - ceil(runiform() * 15)
            gen double hi = xkey + ceil(runiform() * 15)
            save "`m'", replace

            * Using: same 5 groups, integer key, duplicate keys injected to
            * exercise same-key ties; saved twice (rangematch needs key var
            * named like the master key; oracle uses a renamed copy `ukey').
            clear
            set seed `=`seed' + 7'
            set obs 90
            gen long id  = mod(_n, 5) + 1
            gen long uid = _n
            gen double xkey = floor(runiform() * 100)
            replace xkey = 50 if mod(_n, 11) == 0
            save "`urm'", replace
            rename xkey ukey
            save "`uorc'", replace

            * rangematch nearest run
            use "`m'", clear
            rangematch xkey lo hi using "`urm'", by(id) ///
                nearest(`dir') ties(all) closed(`cl') keepusing(uid) ///
                unmatched(none) distance(delta) frame(rm) replace nosort
            frame rm {
                keep mid uid xkey delta
                * delta sign/magnitude check against the using key
                merge m:1 uid using "`uorc'", keep(match) nogenerate ///
                    keepusing(ukey)
                assert reldif(delta, ukey - xkey) < 1e-10
                keep mid uid
                sort mid uid
                save "`rm_pairs'", replace
            }

            * Independent oracle: full within-group cross product, in-range
            * filter under the same closed() rule, then directional nearest.
            use "`m'", clear
            rename xkey mkey
            joinby id using "`uorc'"
            if "`cl'" == "both" keep if ukey < . & ukey >= lo & ukey <= hi
            else                keep if ukey < . & ukey >  lo & ukey <  hi
            if "`dir'" == "before" keep if ukey <= mkey
            if "`dir'" == "after"  keep if ukey >= mkey
            if "`dir'" == "before"     gen double dd = mkey - ukey
            else if "`dir'" == "after" gen double dd = ukey - mkey
            else                       gen double dd = abs(ukey - mkey)
            bysort mid (dd): gen byte _keep = dd == dd[1]
            keep if _keep
            keep mid uid
            sort mid uid
            save "`ex_pairs'", replace

            use "`ex_pairs'", clear
            cf _all using "`rm_pairs'"
        }
    }
}
display as result "PASS: randomized nearest() parity vs joinby oracle (18 grids)"

display as result "ALL RANGEMATCH NEAREST VALIDATION TESTS PASSED"
display "RESULT: validation_rangematch_nearest tests=`test_count' pass=`test_count' fail=0"

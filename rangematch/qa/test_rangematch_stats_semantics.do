*! test_rangematch_stats_semantics.do
*! v1.5.0: what the match-density diagnostics MEAN, not merely that they exist.
*!
*! Two defects motivated this suite, and both survived a 54-suite green lane
*! because every existing stats assertion probed a different axis.
*!
*!   RM-P1  r(p90_matches)/r(p99_matches) used a nearest-rank percentile,
*!          sorted[ceil(.90*n)], while r(p50_matches)/r(median_matches) used
*!          Stata's interpolated rule. One command reported a three-member
*!          percentile family under two different definitions and documented
*!          neither. Every prior assertion pinned p90/p99 at fixtures where all
*!          conventions coincide (counts 0,1,2,10 -> both rules give 10), so no
*!          number of additional cells of that shape could have caught it. The
*!          conventions differ EXACTLY when n*p/100 is an integer; n=10 and n=20
*!          below are chosen for that, and n=7 pins the non-integral branch so a
*!          future "simplification" back to nearest rank fails on both sides.
*!
*!   RM-P2  r(N_empty_groups) meant different things in the two match modes. The
*!          point backends built their group map AFTER dropping missing-key
*!          using rows, so a by-group that HELD using rows counted as empty;
*!          the overlap backend built its map from every using row, so the
*!          equivalent all-inverted group counted as non-empty. Documented as
*!          "by-groups with no using observations", which only overlap honoured.
*!          T5/T6 are the same logical shape run through both backends and must
*!          now agree; T7/T8 hold the genuinely-absent case at 2 in both, so an
*!          "alignment" that simply stops counting anything fails.
*!
*! ORACLE INDEPENDENCE. The expected percentiles come from Stata's own _pctile
*! run on a count vector built by hand, never from rangematch output: the
*! fixture gives master group k exactly k using rows, so the per-master match
*! counts are 1..n by construction. T0 asserts max/mean against that
*! construction first, so a fixture that silently stopped producing 1..n fails
*! loudly instead of making the percentile comparison vacuous.

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

local FAIL 0
local TESTS 0

* Build a using file in which by-group k holds exactly k rows, all on one key,
* and a master file with one row per group whose interval contains that key.
* Per-master match counts are therefore 1, 2, ..., n.
capture program drop _rm_build_counts
program define _rm_build_counts
    args n mfile ufile
    clear
    local total = `n' * (`n' + 1) / 2
    quietly set obs `total'
    quietly gen int mgrp = .
    local r = 0
    forvalues k = 1/`n' {
        forvalues j = 1/`k' {
            local ++r
            quietly replace mgrp = `k' in `r'
        }
    }
    quietly gen double ukey = 100 * mgrp
    quietly gen long uid = _n
    quietly save "`ufile'", replace

    clear
    quietly set obs `n'
    quietly gen int mgrp = _n
    quietly gen double lo = 100 * mgrp - 1
    quietly gen double hi = 100 * mgrp + 1
    quietly gen long mid = _n
    quietly save "`mfile'", replace
end

tempfile M U

**# T0-T4: the percentile family reproduces Stata's own definition
* n=10 and n=20 make n*90/100 integral -- the only case where nearest rank and
* Stata's rule diverge. n=7 makes none of the three integral.
foreach n in 7 10 20 {
    _rm_build_counts `n' "`M'" "`U'"
    use "`M'", clear
    quietly rangematch ukey lo hi using "`U'", by(mgrp) stats frame(_ss) replace
    local got_p50 = r(p50_matches)
    local got_p90 = r(p90_matches)
    local got_p99 = r(p99_matches)
    local got_med = r(median_matches)
    local got_max = r(max_matches)
    local got_mean = r(mean_matches)
    capture frame drop _ss

    * Fixture guard: counts really are 1..n, so the comparison below is not vacuous.
    local ++TESTS
    if `got_max' != `n' | reldif(`got_mean', (`n' + 1) / 2) > 1e-12 {
        di as error "T0 n=`n' fixture broken: max=`got_max' (want `n'), mean=`got_mean' (want `=(`n'+1)/2')"
        local ++FAIL
    }

    * Independent oracle: Stata's percentile of the same 1..n counts.
    clear
    quietly set obs `n'
    quietly gen double cnt = _n
    quietly _pctile cnt, p(50 90 99)
    local want_p50 = r(r1)
    local want_p90 = r(r2)
    local want_p99 = r(r3)

    foreach p in 50 90 99 {
        local ++TESTS
        if reldif(`got_p`p'', `want_p`p'') > 1e-12 {
            di as error "T`p' n=`n': r(p`p'_matches)=`got_p`p'' but _pctile p`p'=`want_p`p''"
            local ++FAIL
        }
    }

    * median and p50 are documented as the same number.
    local ++TESTS
    if reldif(`got_med', `got_p50') > 1e-12 {
        di as error "T4 n=`n': median=`got_med' != p50=`got_p50'"
        local ++FAIL
    }
}

**# T5: point mode -- a group whose using rows all have a MISSING KEY is not empty
tempfile MP UP
clear
input int g double ukey long uid
1 10 1
2  .  2
2  .  3
end
save "`UP'", replace
clear
input int g double lo double hi long mid
1 5 15 1
2 5 15 2
end
save "`MP'", replace

use "`MP'", clear
quietly rangematch ukey lo hi using "`UP'", by(g) stats frame(_ss) replace
local pt_empty = r(N_empty_groups)
local pt_groups = r(N_master_groups)
local pt_umiss = r(N_using_missing)
capture frame drop _ss
local ++TESTS
if `pt_empty' != 0 | `pt_groups' != 2 {
    di as error "T5 point, group holds 2 missing-key using rows: N_empty_groups=`pt_empty' (want 0), N_master_groups=`pt_groups' (want 2)"
    local ++FAIL
}
* The unmatchable rows are still reported -- by the diagnostic that owns them.
local ++TESTS
if `pt_umiss' != 2 {
    di as error "T5b r(N_using_missing)=`pt_umiss' (want 2)"
    local ++FAIL
}

**# T6: overlap mode -- a group whose using rows are all INVERTED is not empty
* Same logical shape as T5 through the other backend; the two must agree.
clear
input int g double ulo double uhi long uid
1 5 15 1
2 20 10 2
end
save "`UP'", replace
clear
input int g double mlo double mhi long mid
1 5 15 1
2 5 15 2
end
save "`MP'", replace

use "`MP'", clear
quietly rangematch mlo mhi using "`UP'", overlap(ulo uhi) by(g) stats ///
    frame(_ss) replace
local ov_empty = r(N_empty_groups)
local ov_groups = r(N_master_groups)
local ov_inv = r(N_using_inverted)
capture frame drop _ss
local ++TESTS
if `ov_empty' != 0 | `ov_groups' != 2 {
    di as error "T6 overlap, group holds 1 inverted using row: N_empty_groups=`ov_empty' (want 0), N_master_groups=`ov_groups' (want 2)"
    local ++FAIL
}
local ++TESTS
if `ov_inv' != 1 {
    di as error "T6b r(N_using_inverted)=`ov_inv' (want 1)"
    local ++FAIL
}
local ++TESTS
if `pt_empty' != `ov_empty' {
    di as error "T6c cross-mode drift: point N_empty_groups=`pt_empty', overlap=`ov_empty'"
    local ++FAIL
}

**# T7: point mode -- genuinely absent groups ARE still counted
clear
input int g double ukey long uid
1 10 1
end
save "`UP'", replace
clear
input int g double lo double hi long mid
1 5 15 1
2 5 15 2
3 5 15 3
end
save "`MP'", replace
use "`MP'", clear
quietly rangematch ukey lo hi using "`UP'", by(g) stats frame(_ss) replace
local pt_abs = r(N_empty_groups)
capture frame drop _ss
local ++TESTS
if `pt_abs' != 2 {
    di as error "T7 point, groups 2 and 3 hold NO using row: N_empty_groups=`pt_abs' (want 2)"
    local ++FAIL
}

**# T8: overlap mode -- genuinely absent groups ARE still counted
clear
input int g double ulo double uhi long uid
1 5 15 1
end
save "`UP'", replace
clear
input int g double mlo double mhi long mid
1 5 15 1
2 5 15 2
3 5 15 3
end
save "`MP'", replace
use "`MP'", clear
quietly rangematch mlo mhi using "`UP'", overlap(ulo uhi) by(g) stats ///
    frame(_ss) replace
local ov_abs = r(N_empty_groups)
capture frame drop _ss
local ++TESTS
if `ov_abs' != 2 {
    di as error "T8 overlap, groups 2 and 3 hold NO using row: N_empty_groups=`ov_abs' (want 2)"
    local ++FAIL
}

**# T9: the density table labels the row for what it now measures
* The stored result and the printed label drifted apart once before; assert the
* rendered console text, not just r().
tempfile lg
clear
input int g double ukey long uid
1 10 1
end
save "`UP'", replace
clear
input int g double lo double hi long mid
1 5 15 1
2 5 15 2
end
save "`MP'", replace
use "`MP'", clear
quietly log using "`lg'.txt", replace text name(_ssl)
rangematch ukey lo hi using "`UP'", by(g) stats frame(_ss) replace
quietly log close _ssl
capture frame drop _ss

local saw_new 0
local saw_old 0
tempname fh
file open `fh' using "`lg'.txt", read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`line'"', "Master groups with no using rows") local saw_new 1
    if strpos(`"`line'"', "Master groups with no using keys") local saw_old 1
    file read `fh' line
}
file close `fh'
local ++TESTS
if `saw_new' != 1 | `saw_old' != 0 {
    di as error "T9 density label: new=`saw_new' (want 1), old=`saw_old' (want 0)"
    local ++FAIL
}

**# T10: single master row -- percentiles are defined and equal the only count
clear
input int g double ukey long uid
1 10 1
1 12 2
end
save "`UP'", replace
clear
input int g double lo double hi long mid
1 5 15 1
end
save "`MP'", replace
use "`MP'", clear
quietly rangematch ukey lo hi using "`UP'", by(g) stats frame(_ss) replace
local one_p50 = r(p50_matches)
local one_p90 = r(p90_matches)
local one_p99 = r(p99_matches)
capture frame drop _ss
local ++TESTS
if `one_p50' != 2 | `one_p90' != 2 | `one_p99' != 2 {
    di as error "T10 n=1 master: p50=`one_p50' p90=`one_p90' p99=`one_p99' (want 2 2 2)"
    local ++FAIL
}

display "RESULT: test_rangematch_stats_semantics tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_stats_semantics: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_stats_semantics: PASSED"

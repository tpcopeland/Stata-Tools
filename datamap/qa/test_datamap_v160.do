clear all
set more off
version 16.0

* test_datamap_v160.do - Regression tests for datamap 1.6.0
*   The unique-value counter was rewritten (_datamap_nuniq): it now walks the
*   column in growing chunks and censors counts above a cap, instead of making
*   three full-length copies (st_data -> select -> uniqrows) per variable.
*   That cut peak memory from ~3.5x the dataset to a bounded chunk -- on a 6GB
*   file the old engine reached 14GB and drove Stata into swap.
*
*   1. exact counts below the cap are unchanged (binary/categorical/mid)
*   2. counts above the cap are censored: r(capped)=1 and r(n)=cap+1
*   3. a censored count renders as ">cap", never as the bare lower bound
*   4. classification is NOT changed by censoring (cap >= maxcat invariant)
*   5. cap < maxcat is refused (a censored count could misclassify)
*   6. cap(0) disables censoring -- panel unit counts must stay exact
*   7. missing-value contract preserved (. and .a-.z uncounted; "" per countempty)
*   8. the slack boundary: cardinality just above the cap is still flagged

local test_count = 0
local pass_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local tmp_dir "`qa_dir'/data"

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard

capture program drop _v160_record
program define _v160_record
    version 16.0
    args ok label
    if `ok' display as result "PASS: `label'"
    else    display as error  "FAIL: `label'"
end

**# fixture
clear
set seed 160
set obs 20000
gen byte  vbin   = runiformint(0, 1)                 // 2 distinct
gen int   vcat   = runiformint(1, 20)                // 20 distinct
gen int   vmid   = runiformint(1, 800)               // 800 distinct: under cap
gen long  vid    = _n                                // 20000 distinct: over cap
gen double vcont = rnormal()                         // ~20000 distinct: over cap
gen str8  vstr   = "s" + string(runiformint(1, 5000))  // 5000 distinct: over cap
gen byte  vmiss  = cond(_n <= 10000, ., runiformint(1, 3))  // 3 distinct + .
label define yn 0 "No" 1 "Yes"
label values vbin yn

**# 1. exact counts below the cap
foreach spec in "vbin 2" "vcat 20" "vmid 800" {
    local v : word 1 of `spec'
    local want : word 2 of `spec'
    local ++test_count
    _datamap_nuniq `v', cap(1000)
    local ok = (r(n) == `want' & r(capped) == 0)
    _v160_record `ok' "exact count below cap: `v' = `want' (got r(n)=`r(n)', capped=`r(capped)')"
    local pass_count = `pass_count' + `ok'
}

**# 2. counts above the cap are censored
foreach v in vid vcont vstr {
    local ++test_count
    _datamap_nuniq `v', cap(1000)
    local ok = (r(capped) == 1 & r(n) == 1001)
    _v160_record `ok' "censored above cap: `v' -> capped=1, n=1001 (got n=`r(n)', capped=`r(capped)')"
    local pass_count = `pass_count' + `ok'
}

**# 3. a censored count renders as ">cap", not as the bare lower bound
* This is the assertion that fails on the pre-1.6.0 engine, which reported the
* true count and had no notion of censoring.
local ++test_count
_datamap_fmt_uniq 1001 1
local ok = ("`r(s)'" == ">1000")
_v160_record `ok' "fmt: (n=1001, capped=1) renders '>1000' (got '`r(s)'')"
local pass_count = `pass_count' + `ok'

local ++test_count
_datamap_fmt_uniq 20 0
local ok = ("`r(s)'" == "20")
_v160_record `ok' "fmt: (n=20, capped=0) renders '20' (got '`r(s)'')"
local pass_count = `pass_count' + `ok'

* a missing capped flag must read as NOT censored (. is nonzero in Stata)
local ++test_count
_datamap_fmt_uniq 20 .
local ok = ("`r(s)'" == "20")
_v160_record `ok' "fmt: missing capped flag reads as not-censored (got '`r(s)'')"
local pass_count = `pass_count' + `ok'

**# 3b. the rendered report says ">1000", and never the bare bound "1001"
tempfile rpt
quietly datamap, output("`rpt'.txt")
local ok = 0
local sawbound = 0
tempname fh
file open `fh' using "`rpt'.txt", read text
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "Unique Values: >1000") > 0 local ok = 1
    if strpos(`"`macval(line)'"', "Unique Values: 1001") > 0  local sawbound = 1
    file read `fh' line
}
file close `fh'
local ++test_count
local ok2 = (`ok' == 1 & `sawbound' == 0)
_v160_record `ok2' "report renders '>1000' and never the bare bound '1001'"
local pass_count = `pass_count' + `ok2'

**# 4. censoring does not change classification
* vcont/vid are censored yet must still be continuous; vbin/vcat categorical.
quietly datamap, output("`rpt'2.txt")
local ++test_count
local ok = ("`r(continuous_vars)'" != "")
local c_ok = (strpos(" `r(continuous_vars)' ", " vcont ") > 0)
local i_ok = (strpos(" `r(continuous_vars)' ", " vid ") > 0)
local b_ok = (strpos(" `r(categorical_vars)' ", " vbin ") > 0)
local a_ok = (strpos(" `r(categorical_vars)' ", " vcat ") > 0)
local ok = (`c_ok' & `i_ok' & `b_ok' & `a_ok')
_v160_record `ok' "censoring preserves classification (vcont/vid continuous; vbin/vcat categorical)"
local pass_count = `pass_count' + `ok'

**# 5. cap < maxcat is refused
tempfile cls
local ++test_count
capture _datamap_classify using "memory", loaded saving("`cls'") maxcat(2000) cap(1000)
local ok = (_rc == 198)
_v160_record `ok' "cap(1000) < maxcat(2000) rejected with rc=198 (got rc=`=_rc')"
local pass_count = `pass_count' + `ok'

**# 6. cap(0) disables censoring: exact count at any cardinality
local ++test_count
_datamap_nuniq vid, cap(0)
local ok = (r(n) == 20000 & r(capped) == 0)
_v160_record `ok' "cap(0) gives exact count for 20000-distinct id (got n=`r(n)')"
local pass_count = `pass_count' + `ok'

* The exact-count (cap<=0) path reads the column through a VIEW (st_view /
* st_sview) so the initial full-length copy is never allocated.  A view aliases
* the live data, so any Mata op that wrote back through it would silently
* corrupt the caller's dataset at rc=0.  Assert the data is bit-identical after
* exact counts on a numeric AND a string column (both view paths), including the
* countempty branch that runs select() on the view's uniqrows result.
quietly datasignature
local ds_view "`r(datasignature)'"
_datamap_nuniq vid, cap(0)
_datamap_nuniq vstr, cap(0)
_datamap_nuniq vstr, cap(0) countempty
quietly datasignature
local ++test_count
local ok = ("`ds_view'" == "`r(datasignature)'")
_v160_record `ok' "exact-count view path leaves data bit-identical (no view write-back)"
local pass_count = `pass_count' + `ok'

* The panel unit count must NOT be censored.  It flows through
* _datamap_ndistinct, which passes cap(0) precisely so that a 5000-unit panel
* reports 5000 units and not the cap bound.  Had _datamap_ndistinct inherited
* the default cap, this would read "Unique Units: 1001".
clear
set seed 161
set obs 20000
gen long pid = ceil(_n / 4)          // 5000 units x 4 obs -- units > cap(1000)
gen byte  wave = mod(_n - 1, 4) + 1
gen double yv = rnormal()
tempfile prpt
quietly datamap, output("`prpt'.txt") detect(panel) panelid(pid)

local sawunits = 0
local sawcap = 0
tempname pfh
file open `pfh' using "`prpt'.txt", read text
file read `pfh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "Unique Units: 5000") > 0 local sawunits = 1
    if strpos(`"`macval(line)'"', "Unique Units: 1001") > 0 local sawcap = 1
    file read `pfh' line
}
file close `pfh'
local ++test_count
local ok = (`sawunits' == 1 & `sawcap' == 0)
_v160_record `ok' "panel unit count stays exact: 5000 units, not the cap bound 1001"
local pass_count = `pass_count' + `ok'

**# 7. missing-value contract
* numeric: . and .a-.z never counted
* (the panel fixture above replaced the data in memory -- rebuild vmiss)
clear
set seed 160
set obs 20000
gen byte vmiss = cond(_n <= 10000, ., runiformint(1, 3))   // 3 distinct + .
local ++test_count
_datamap_nuniq vmiss, cap(1000)
local ok = (r(n) == 3 & r(capped) == 0)
_v160_record `ok' "numeric missings uncounted: vmiss = 3 (got n=`r(n)')"
local pass_count = `pass_count' + `ok'

clear
set obs 6
gen x = .
replace x = 1 in 1
replace x = 2 in 2
replace x = .a in 3
replace x = .b in 4
local ++test_count
_datamap_nuniq x, cap(1000)
local ok = (r(n) == 2)
_v160_record `ok' "extended missings .a/.b uncounted: x = 2 (got n=`r(n)')"
local pass_count = `pass_count' + `ok'

* string: "" uncounted unless countempty
clear
set obs 5
gen str4 s = ""
replace s = "a" in 1
replace s = "b" in 2
local ++test_count
_datamap_nuniq s, cap(1000)
local ok = (r(n) == 2)
_v160_record `ok' "string: empty uncounted by default: s = 2 (got n=`r(n)')"
local pass_count = `pass_count' + `ok'

local ++test_count
_datamap_nuniq s, countempty cap(1000)
local ok = (r(n) == 3)
_v160_record `ok' "string: countempty counts '' : s = 3 (got n=`r(n)')"
local pass_count = `pass_count' + `ok'

**# 8. slack boundary -- cardinality just over the cap must still be flagged
* Missings ride along in the running distinct set, so the in-loop early exit
* carries 27 rows of headroom.  A variable landing between cap+1 and cap+slack
* never trips that test and is caught only by the post-loop check.  With no
* missings present, a var of exactly cap+1 distinct exercises that path.
clear
set obs 101
gen y = _n
local ++test_count
_datamap_nuniq y, cap(100)
local ok = (r(capped) == 1 & r(n) == 101)
_v160_record `ok' "slack boundary: 101 distinct with cap(100) is censored (got n=`r(n)', capped=`r(capped)')"
local pass_count = `pass_count' + `ok'

* exactly at the cap: exact, not censored
clear
set obs 100
gen y = _n
local ++test_count
_datamap_nuniq y, cap(100)
local ok = (r(capped) == 0 & r(n) == 100)
_v160_record `ok' "at the cap: 100 distinct with cap(100) is exact (got n=`r(n)', capped=`r(capped)')"
local pass_count = `pass_count' + `ok'

* and the same boundary WITH missings present, which consume the slack
clear
set obs 130
gen y = _n
replace y = .  in 102
replace y = .a in 103
replace y = .b in 104
local ++test_count
_datamap_nuniq y, cap(100)
local ok = (r(capped) == 1)
_v160_record `ok' "slack boundary with missings present: still censored (got capped=`r(capped)')"
local pass_count = `pass_count' + `ok'

**# 9. uniqcap() option: user-facing escape hatch
clear
set seed 162
set obs 20000
gen long vid = _n
gen byte vbin = runiformint(0, 1)
tempfile ucr

* default: censored at 1000
quietly datamap, output("`ucr'_d.txt")
local sawcap = 0
tempname f1
file open `f1' using "`ucr'_d.txt", read text
file read `f1' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "Unique Values: >1000") > 0 local sawcap = 1
    file read `f1' line
}
file close `f1'
local ++test_count
_v160_record `sawcap' "uniqcap default(1000): vid renders '>1000'"
local pass_count = `pass_count' + `sawcap'

* uniqcap(0): exact count restored
quietly datamap, output("`ucr'_0.txt") uniqcap(0)
local sawexact = 0
tempname f2
file open `f2' using "`ucr'_0.txt", read text
file read `f2' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "Unique Values: 20000") > 0 local sawexact = 1
    file read `f2' line
}
file close `f2'
local ++test_count
_v160_record `sawexact' "uniqcap(0): vid renders exact 20000"
local pass_count = `pass_count' + `sawexact'

* uniqcap(5000): raised cap -> still exact for 20000? no: 20000 > 5000 -> '>5000'
quietly datamap, output("`ucr'_5.txt") uniqcap(5000)
local saw5 = 0
tempname f3
file open `f3' using "`ucr'_5.txt", read text
file read `f3' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "Unique Values: >5000") > 0 local saw5 = 1
    file read `f3' line
}
file close `f3'
local ++test_count
_v160_record `saw5' "uniqcap(5000): vid renders '>5000'"
local pass_count = `pass_count' + `saw5'

* negative uniqcap rejected
local ++test_count
capture datamap, output("`ucr'_bad.txt") uniqcap(-1)
local ok = (_rc == 198)
_v160_record `ok' "uniqcap(-1) rejected with rc=198 (got rc=`=_rc')"
local pass_count = `pass_count' + `ok'

**# 10. the report writers must not disturb the data in memory
* The 11 classification reads moved from -preserve- to frames.  A frame leaves
* the main data alone, but only if every writer really uses one -- so assert the
* dataset is bit-identical after a full run, not merely the same size.
clear
set seed 163
set obs 5000
gen long id = _n
gen byte grp = runiformint(1, 4)
gen double y = rnormal()
gen str6 s = "t" + string(runiformint(1, 3000))
label define g4 1 "a" 2 "b" 3 "c" 4 "d"
label values grp g4
quietly datasignature
local ds_before "`r(datasignature)'"
local n_before = _N
local k_before = c(k)
local sort_before "`: sortedby'"

tempfile fr
quietly datamap, output("`fr'.txt") detect(panel binary) panelid(id) quality samples(3)

quietly datasignature
local ds_after "`r(datasignature)'"
local ++test_count
local ok = ("`ds_before'" == "`ds_after'")
_v160_record `ok' "datasignature unchanged after full datamap run (frames did not touch the data)"
local pass_count = `pass_count' + `ok'

local ++test_count
local ok = (`n_before' == _N & `k_before' == c(k))
_v160_record `ok' "obs and variable count unchanged (`n_before'/`k_before' -> `=_N'/`=c(k)')"
local pass_count = `pass_count' + `ok'

* no stray tempvars left behind by the classifier's string-length pass
local ++test_count
capture confirm variable __000000
local ok = (_rc != 0)
_v160_record `ok' "no stray tempvar left in the dataset"
local pass_count = `pass_count' + `ok'

* the JSON capped flag is emitted
tempfile js
quietly datamap, format(json) output("`js'.json")
local sawflag = 0
local sawtrue = 0
local q = char(34)
tempname fj
file open `fj' using "`js'.json", read text
file read `fj' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "unique_values_capped") > 0 local sawflag = 1
    if strpos(`"`macval(line)'"', `"unique_values_capped`q': true"') > 0 local sawtrue = 1
    file read `fj' line
}
file close `fj'
local ++test_count
local ok = (`sawflag' == 1 & `sawtrue' == 1)
_v160_record `ok' "JSON emits unique_values_capped, true for the censored string var"
local pass_count = `pass_count' + `ok'

**# 11. datadict shares the fast counter and the censoring contract
* datadict counted distinct values with -egen tag()-, which sorts the whole
* dataset once per variable: 347s vs datamap's 54s on the same 3M x 60 file.
* It now calls _datamap_nuniq like everything else, so it must honour the same
* cap and render ">1000" rather than a bare bound.
clear
set seed 164
set obs 20000
gen long vid = _n
gen byte vbin = runiformint(0, 1)
tempfile dd

* datadict's observable unique-count contract is its saving() metadata: the
* `unique' column travels with a `unique_capped' flag, so a downstream consumer
* cannot read a censored lower bound as an exact cardinality.
tempfile ddmeta
quietly datadict, output("`dd'_d.md") saving("`ddmeta'", replace)
preserve
quietly use "`ddmeta'", clear
quietly summarize unique if variable == "vid"
local u_vid = r(mean)
quietly summarize unique_capped if variable == "vid"
local c_vid = r(mean)
quietly summarize unique if variable == "vbin"
local u_bin = r(mean)
quietly summarize unique_capped if variable == "vbin"
local c_bin = r(mean)
restore
local ++test_count
local ok = (`u_vid' == 1001 & `c_vid' == 1 & `u_bin' == 2 & `c_bin' == 0)
_v160_record `ok' "datadict saving(): vid censored (1001, capped=1), vbin exact (2, capped=0)"
local pass_count = `pass_count' + `ok'

tempfile ddmeta0
quietly datadict, output("`dd'_0.md") uniqcap(0) saving("`ddmeta0'", replace)
preserve
quietly use "`ddmeta0'", clear
quietly summarize unique if variable == "vid"
local u0 = r(mean)
quietly summarize unique_capped if variable == "vid"
local c0 = r(mean)
restore
local ++test_count
local ok = (`u0' == 20000 & `c0' == 0)
_v160_record `ok' "datadict uniqcap(0): vid exact 20000, capped=0 (got `u0', `c0')"
local pass_count = `pass_count' + `ok'

local ++test_count
capture datadict, output("`dd'_bad.md") uniqcap(-1)
local ok = (_rc == 198)
_v160_record `ok' "datadict uniqcap(-1) rejected with rc=198 (got rc=`=_rc')"
local pass_count = `pass_count' + `ok'

* datadict must not disturb the data either
quietly datasignature
local ds_b "`r(datasignature)'"
quietly datadict, output("`dd'_s.md") stats missing
quietly datasignature
local ++test_count
local ok = ("`ds_b'" == "`r(datasignature)'")
_v160_record `ok' "datadict leaves the data in memory bit-identical"
local pass_count = `pass_count' + `ok'

**# 12. the in-memory path takes no -preserve-, so nothing may replace the data
* preserve costs a full in-memory copy (a 6GB dataset needs 6GB more).  The
* in-memory path no longer takes one, which means every would-be clobber has to
* be gone -- not just the report writers.  Two used to be load-bearing:
*   - saving() did -use metadata_tmp, clear-, i.e. it left the METADATA TABLE in
*     memory and relied on -restore- to put the user's data back;
*   - the saving() branch reloaded the source file over the top of it.
* Both now run in frames.  Assert on the datasignature, not on _N/c(k): a
* replaced dataset can easily have the same shape.
clear
set seed 900
set obs 5000
gen long id = _n
gen byte grp = runiformint(1, 4)
gen double y = rnormal()
gen str6 s = "t" + string(runiformint(1, 3000))
label define g4b 1 "a" 2 "b" 3 "c" 4 "d"
label values grp g4b
label data "my precious data"
sort grp id

quietly datasignature
local ds0 "`r(datasignature)'"
local sb0 "`: sortedby'"
local lab0 : data label

tempfile np
quietly datamap, output("`np'1.txt")
quietly datasignature
local ++test_count
local ok = ("`ds0'" == "`r(datasignature)'" & "`sb0'" == "`: sortedby'")
_v160_record `ok' "in-memory run leaves data bit-identical (datasignature + sort order)"
local pass_count = `pass_count' + `ok'

* saving() is the dangerous one: it used to leave the metadata table in memory
tempfile npmeta
quietly datamap, output("`np'2.txt") saving("`npmeta'", replace)
quietly datasignature
local lab1 : data label
local ++test_count
local ok = ("`ds0'" == "`r(datasignature)'" & `"`lab0'"' == `"`lab1'"')
_v160_record `ok' "saving() does not leave the metadata table in memory"
local pass_count = `pass_count' + `ok'

* ...and the metadata file is still written
preserve
quietly use "`npmeta'", clear
local mrows = _N
capture confirm variable unique_capped
local mok = (_rc == 0)
restore
local ++test_count
local ok = (`mrows' == 4 & `mok')
_v160_record `ok' "saving() still writes the metadata file (4 rows, unique_capped present)"
local pass_count = `pass_count' + `ok'

* detectors + json + samples must not disturb it either
quietly datamap, format(json) output("`np'3.json") detect(panel binary) panelid(id) quality samples(3)
quietly datasignature
local ++test_count
local ok = ("`ds0'" == "`r(datasignature)'")
_v160_record `ok' "json + detect + quality + samples leave data bit-identical"
local pass_count = `pass_count' + `ok'

* single() STILL preserves: it -use-s a file, so restoring is a correctness
* requirement, not a safety net.  Dropping preserve there would destroy the
* caller's data on a SUCCESSFUL run.
frame create _v160mk
frame _v160mk {
    set obs 3
    gen z = _n
    quietly save "`tmp_dir'/_v160_other.dta", replace
}
frame drop _v160mk
quietly datamap, single("`tmp_dir'/_v160_other.dta") output("`np'5.txt")
quietly datasignature
local ++test_count
local ok = ("`ds0'" == "`r(datasignature)'")
_v160_record `ok' "single() still restores the caller's data (preserve retained on file paths)"
local pass_count = `pass_count' + `ok'

**# 13. datadict took the same treatment -- same contract
* Its in-memory path reloads a tempfile copy of the data, so the round-trip must
* preserve everything a datasignature does NOT cover: labels, notes, chars, sort.
label variable y "outcome"
note: keep me
char id[role] "identifier"
quietly datasignature
local dds "`r(datasignature)'"
local dsb "`: sortedby'"
local dlab : data label
local dvlab : variable label y
local dchar : char id[role]
local dnote : char _dta[note1]

quietly datadict, output("`np'_dd1.md")
quietly datasignature
local ++test_count
local ok = ("`dds'" == "`r(datasignature)'" & "`dsb'" == "`: sortedby'" ///
    & `"`dlab'"' == `"`: data label'"' & `"`dvlab'"' == `"`: variable label y'"' ///
    & `"`dchar'"' == `"`: char id[role]'"' & `"`dnote'"' == `"`: char _dta[note1]'"')
_v160_record `ok' "datadict in-memory run preserves sig, sort, labels, notes, chars"
local pass_count = `pass_count' + `ok'

tempfile ddm2
quietly datadict, output("`np'_dd2.md") saving("`ddm2'", replace) stats missing
quietly datasignature
local ++test_count
local ok = ("`dds'" == "`r(datasignature)'" & `"`dlab'"' == `"`: data label'"')
_v160_record `ok' "datadict saving() does not leave the metadata table in memory"
local pass_count = `pass_count' + `ok'

quietly datadict, single("`tmp_dir'/_v160_other.dta") output("`np'_dd3.md")
quietly datasignature
local ++test_count
local ok = ("`dds'" == "`r(datasignature)'")
_v160_record `ok' "datadict single() still restores the caller's data"
local pass_count = `pass_count' + `ok'

capture erase "`tmp_dir'/_v160_other.dta"

**# summary
display as text "test_datamap_v160: `pass_count'/`test_count' passed"
local fail_count = `test_count' - `pass_count'
display "RESULT: test_datamap_v160 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `pass_count' < `test_count' {
    display as error "test_datamap_v160 FAILED"
    exit 9
}

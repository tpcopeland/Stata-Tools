*! test_audit_regressions.do  1.0.0  2026/07/13
*! Exact regressions for the 2026-07-12 comprehensive setools audit

version 16.0
clear all
set more off
set varabbrev off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar ar_tests = 0
scalar ar_pass = 0
scalar ar_fail = 0
capture program drop ar_check
program define ar_check
    args label ok
    scalar ar_tests = ar_tests + 1
    if `ok' {
        scalar ar_pass = ar_pass + 1
        display as result "  PASS: `label'"
    }
    else {
        scalar ar_fail = ar_fail + 1
        display as error "  FAIL: `label'"
    }
end

**# CCI mapping and output preflight

clear
input long id str8 code int year
1 "E108" 1998
2 "E118" 1998
3 "191"  1968
4 "175"  1986
5 "176"  1986
6 "177"  1986
7 "178"  1986
8 "179"  1986
9 "F024" 1998
end
gen long diagnosis_date = mdy(1, 1, year)
format diagnosis_date %td
cci_se, id(id) icd(code) date(diagnosis_date) generate(cci_score) ///
    components prefix(cci_)
capture {
    assert cci_score == 1 & cci_diab == 1 if inlist(id, 1, 2)
    assert cci_score == 0 & cci_cancer == 0 if inrange(id, 3, 8)
    assert cci_score == 7 & cci_dem == 1 & cci_aids == 1 if id == 9
}
ar_check "SET-C01 authoritative corrections and nested F024 prefixes" ///
    `=(_rc == 0)'

clear
input long id str8 code int year
1 "I21" 2000
end
gen long diagnosis_date = mdy(1, 1, year)
format diagnosis_date %td
capture noisily cci_se, id(id) icd(code) date(diagnosis_date) ///
    generate(cci_mi) components prefix(cci_)
ar_check "SET-M02 exact score/component name collision returns 198" ///
    `=(_rc == 198)'

clear
input long id str8 code int year
1 "I21" 2000
end
gen long diagnosis_date = mdy(1, 1, year)
format diagnosis_date %td
quietly datasignature
local cci_sig_before "`r(datasignature)'"
capture noisily cci_se, id(id) icd(code) date(diagnosis_date) ///
    generate(cci_score) dates prefix(cci_)
local cci_dates_rc = _rc
quietly datasignature
local cci_sig_after "`r(datasignature)'"
ar_check "SET-M02 dates implies components after identical preflight" ///
    `=(`cci_dates_rc' == 0 & cci_score[1] == 1 & cci_mi[1] == 1)'

**# CDP retry, roving baseline, event shape, and rollback

tempfile cdp_retry
clear
input long id double edss long visit_date long dx
1 2 0   0
1 3 10  0
1 2 190 0
1 3 400 0
1 3 580 0
2 2 0   0
2 3 20  0
2 3 200 0
3 2 0   0
4 2 0   0
4 3 10  0
4 2 190 0
end
format visit_date dx %td
save `cdp_retry', replace

foreach ctype in sustained visit {
    use `cdp_retry', clear
    cdp id edss visit_date, dxdate(dx) confirmdays(180) ///
        confirmtype(`ctype') keepall generate(std_`ctype') quietly
    quietly summarize std_`ctype' if id == 1, meanonly
    local std1 = r(mean)
    quietly summarize std_`ctype' if id == 2, meanonly
    local std2 = r(mean)
    quietly count if inlist(id, 3, 4) & !missing(std_`ctype')
    local std_none = r(N)

    use `cdp_retry', clear
    cdp id edss visit_date, dxdate(dx) confirmdays(180) ///
        confirmtype(`ctype') roving keepall generate(rov_`ctype') quietly
    quietly summarize rov_`ctype' if id == 1, meanonly
    local rov1 = r(mean)
    quietly summarize rov_`ctype' if id == 2, meanonly
    local rov2 = r(mean)
    quietly count if inlist(id, 3, 4) & !missing(rov_`ctype')
    local rov_none = r(N)
    ar_check "SET-C02 per-person retry and first-event equality (`ctype')" ///
        `=(`std1' == 400 & `std2' == 20 & `std_none' == 0 & ///
           `rov1' == `std1' & `rov2' == `std2' & `rov_none' == 0)'
}

clear
input long id double edss long visit_date long dx
1 2 0   0
1 3 10  0
1 2 20  0
1 3 190 0
1 4 400 0
1 4 580 0
end
format visit_date dx %td
cdp id edss visit_date, dxdate(dx) roving allevents confirmdays(180) ///
    eventnumvar(seq) baseedssvar(reference_edss) generate(event_date) quietly
sort seq
capture {
    assert _N == 2
    assert event_date[1] == 10 & reference_edss[1] == 2
    assert event_date[2] == 400 & reference_edss[2] == 3
    assert "`r(eventnumvar)'" == "seq"
    assert "`r(baseedssvar)'" == "reference_edss"
}
ar_check "SET-H01 roving resets at actual confirming assessment" `=(_rc == 0)'

clear
input long id double edss long visit_date long dx byte eligible str4 payload
1 9 900 0 0 "bad"
1 2   0 0 1 "base"
1 3  10 0 1 "cand"
1 3 190 0 1 "conf"
end
format visit_date dx %td
cdp id edss visit_date if eligible, dxdate(dx) roving allevents ///
    eventvar(event) keepall quietly
capture {
    assert _N == 1
    assert cdp_date == 10 & event == 1
    confirm new variable edss
    confirm new variable visit_date
    confirm new variable payload
    confirm new variable eligible
}
ar_check "SET-H02 if-qualified event rows exclude visit-level payload" `=(_rc == 0)'

tempfile cdp_collision
clear
input long id double edss long visit_date long dx
1 2 0 0
1 3 10 0
1 3 190 0
end
format visit_date dx %td
save `cdp_collision', replace
foreach collision in event_num baseline_edss_at_event {
    use `cdp_collision', clear
    gen double `collision' = 99
    quietly datasignature
    local sig_before "`r(datasignature)'"
    capture noisily cdp id edss visit_date, dxdate(dx) roving allevents quietly
    local collision_rc = _rc
    quietly datasignature
    local sig_after "`r(datasignature)'"
    ar_check "SET-C03 `collision' collision rejects without mutation" ///
        `=(`collision_rc' == 110 & "`sig_before'" == "`sig_after'")'
}

clear
input long id double edss long visit_date long dx long exit_date
1 2 0   0 100
1 3 10  1 200
1 3 190 0 100
end
format visit_date dx exit_date %td
quietly datasignature
local sig_before "`r(datasignature)'"
capture noisily cdp id edss visit_date, dxdate(dx) exit(exit_date) keepall
local cdp_person_rc = _rc
quietly datasignature
local sig_after "`r(datasignature)'"
ar_check "SET-H03/M06 cdp rejects varying person dates with rollback" ///
    `=(`cdp_person_rc' == 459 & "`sig_before'" == "`sig_after'")'

clear
input long id double edss long visit_date long dx
1 2 0 0
1 3 10 0
end
format visit_date dx %td
quietly datasignature
local sig_before "`r(datasignature)'"
capture noisily cdp id edss visit_date, dxdate(dx) allevents
local allevents_rc = _rc
quietly datasignature
local sig_after "`r(datasignature)'"
ar_check "SET-M01 allevents without roving returns 198 unchanged" ///
    `=(`allevents_rc' == 198 & "`sig_before'" == "`sig_after'")'

**# User-directed sustained-EDSS contract

tempfile sustained_base
clear
input long id double edss long visit_date
1 6 0
2 6 0
2 6 182
3 6 0
3 6 183
4 6 0
4 5 100
4 6 400
5 6 0
5 5 0
5 6 200
6 6 0
6 6 100
6 5 400
7 6 0
7 5.5 100
7 6 200
end
format visit_date %td
save `sustained_base', replace

use `sustained_base', clear
sustainedss id edss visit_date, threshold(6) keepall generate(default_dt) quietly
local default_mode "`r(confirmvisit)'"
capture {
    assert default_dt == 0 if inlist(id, 1, 2, 3)
    assert default_dt == 400 if id == 4
    assert default_dt == 200 if inlist(id, 5, 7)
    assert missing(default_dt) if id == 6
    assert "`default_mode'" == ""
}
ar_check "SET-M04 default needs no visit but rejects any later reversal" ///
    `=(_rc == 0)'

use `sustained_base', clear
sustainedss id edss visit_date, threshold(6) confirmvisit(window) ///
    confirmwindow(182) keepall generate(window_dt) quietly
local window_mode "`r(confirmvisit)'"
capture {
    assert window_dt == 0 if id == 2
    assert window_dt == 0 if id == 6
    assert missing(window_dt) if !inlist(id, 2, 6)
    assert "`window_mode'" == "window"
}
ar_check "SET-M04 bounded visit accepts exact day 182 and bounded follow-up" ///
    `=(_rc == 0)'

use `sustained_base', clear
sustainedss id edss visit_date, threshold(6) confirmvisit(unlimited) ///
    keepall generate(unlimited_dt) quietly
local unlimited_mode "`r(confirmvisit)'"
capture {
    assert unlimited_dt == 0 if inlist(id, 2, 3)
    assert missing(unlimited_dt) if !inlist(id, 2, 3)
    assert "`unlimited_mode'" == "unlimited"
}
ar_check "SET-M04 unlimited visit requires first later high and no reversal" ///
    `=(_rc == 0)'

clear
input long id double edss long visit_date
1 3.25 0
end
format visit_date %td
sustainedss id edss visit_date, threshold(3.25) keepall quietly
capture confirm variable sustained3_25_dt
ar_check "SET-M05 full-precision threshold name is canonical" `=(_rc == 0)'

clear
input long id double edss long visit_date long exit_date
1 6 0 100
1 6 182 200
end
format visit_date exit_date %td
quietly datasignature
local sig_before "`r(datasignature)'"
capture noisily sustainedss id edss visit_date, threshold(6) ///
    exit(exit_date) keepall
local ss_exit_rc = _rc
quietly datasignature
local sig_after "`r(datasignature)'"
ar_check "SET-H03 sustainedss rejects varying exit with rollback" ///
    `=(`ss_exit_rc' == 459 & "`sig_before'" == "`sig_after'")'

**# PIRA person-level dates, post-exit counts, and first-event scope

tempfile empty_relapses mixed_relapses
clear
set obs 0
gen long id = .
gen long relapse_date = .
format relapse_date %td
save `empty_relapses', replace emptyok

clear
input long id double edss long visit_date long dx long exit_date
1 2 0   0 5
1 3 10  0 5
1 3 190 0 5
end
format visit_date dx exit_date %td
pira id edss visit_date, dxdate(dx) relapses("`empty_relapses'") ///
    exit(exit_date) keepall quietly
capture {
    assert r(N_cdp_preexit) == 1
    assert r(N_cdp) == 0 & r(N_pira) == 0 & r(N_raw) == 0
    assert r(N_censored_exit) == 1
    assert "`r(event_scope)'" == "first_confirmed_cdp"
}
ar_check "SET-H05 PIRA post-exit counts are recomputed exactly" `=(_rc == 0)'

clear
input long id long relapse_date
1 10
1 10
end
format relapse_date %td
save `mixed_relapses', replace
clear
input long id double edss long visit_date long dx
1 2 0   0
1 3 10  0
1 3 190 0
1 4 400 0
1 4 580 0
end
format visit_date dx %td
pira id edss visit_date, dxdate(dx) relapses("`mixed_relapses'") ///
    keepall quietly
capture {
    assert raw_date == 10
    assert missing(pira_date)
    assert r(N_cdp) == 1 & r(N_raw) == 1 & r(N_pira) == 0
    assert "`r(event_scope)'" == "first_confirmed_cdp"
}
ar_check "SET-H06 PIRA explicitly classifies only first confirmed CDP" ///
    `=(_rc == 0)'

clear
input long id double edss long visit_date long dx long exit_date
1 2 0   0 100
1 3 10  1 200
1 3 190 0 100
end
format visit_date dx exit_date %td
quietly datasignature
local sig_before "`r(datasignature)'"
capture noisily pira id edss visit_date, dxdate(dx) ///
    relapses("`empty_relapses'") exit(exit_date) keepall
local pira_person_rc = _rc
quietly datasignature
local sig_after "`r(datasignature)'"
ar_check "SET-H03/M06 pira rejects varying person dates with rollback" ///
    `=(`pira_person_rc' == 459 & "`sig_before'" == "`sig_after'")'

**# Migration path safety, extended missings, transactions, and flow counts

local stem "`c(tmpdir)'/setools_audit_`c(processid)'"
local migfile "`stem'_mig.dta"
local pairfile "`stem'_pair.dta"
local linkfile "`stem'_link.dta"
local sentinel "`stem'_sentinel.dta"
local missing_dir "`stem'_missing"
foreach file in `migfile' `pairfile' `linkfile' `sentinel' {
    capture erase "`file'"
}
shell /bin/rm -rf -- "`missing_dir'"

clear
input long id long in_1 long out_1
1 . .
end
format in_1 out_1 %td
save "`migfile'", replace

clear
input long id long study_start
1 0
end
format study_start %td
quietly datasignature
local mig_sig_before "`r(datasignature)'"
tempfile hash_before hash_after
shell /usr/bin/sha256sum "`migfile'" > "`hash_before'"
tempname hash_handle
file open `hash_handle' using "`hash_before'", read text
file read `hash_handle' hash_line_before
file close `hash_handle'
local mig_hash_before : word 1 of `hash_line_before'
local mig_without_suffix = substr("`migfile'", 1, strlen("`migfile'") - 4)
capture noisily migrations, migfile("`migfile'") ///
    saveexclude("`mig_without_suffix'") replace
local alias_rc = _rc
quietly datasignature
local mig_sig_after "`r(datasignature)'"
shell /usr/bin/sha256sum "`migfile'" > "`hash_after'"
file open `hash_handle' using "`hash_after'", read text
file read `hash_handle' hash_line_after
file close `hash_handle'
local mig_hash_after : word 1 of `hash_line_after'
ar_check "SET-C04 omitted-extension alias rejects without data/file mutation" ///
    `=(`alias_rc' == 198 & "`mig_sig_before'" == "`mig_sig_after'" & ///
       "`mig_hash_before'" == "`mig_hash_after'")'

clear
input long id long study_start
1 0
end
format study_start %td
local pair_without_suffix = substr("`pairfile'", 1, strlen("`pairfile'") - 4)
capture noisily migrations, migfile("`migfile'") ///
    saveexclude("`pair_without_suffix'") savecensor("`pairfile'") replace
ar_check "SET-C04 saveexclude/savecensor canonical alias returns 198" ///
    `=(_rc == 198)'

shell /bin/ln -sf -- "`migfile'" "`linkfile'"
clear
input long id long study_start
1 0
end
format study_start %td
capture noisily migrations, migfile("`migfile'") savecensor("`linkfile'") replace
ar_check "SET-C04 symlink alias to migfile returns 198" `=(_rc == 198)'

clear
set obs 26
gen long id = _n
gen double in_1 = .
gen double out_1 = .
forvalues j = 1/26 {
    local miss = char(96 + `j')
    quietly replace out_1 = .`miss' in `j'
}
format in_1 out_1 %td
save "`pairfile'", replace
clear
set obs 26
gen long id = _n
gen long study_start = 0
format study_start %td
quietly migrations, migfile("`pairfile'")
capture {
    assert r(N_censored) == 0
    assert missing(migration_out_dt)
}
ar_check "SET-H04 all .a-.z wide dates normalize to missing" `=(_rc == 0)'

clear
set obs 26
gen long id = _n
gen double event_date = .
gen str3 event_type = "Utv"
forvalues j = 1/26 {
    local miss = char(96 + `j')
    quietly replace event_date = .`miss' in `j'
}
format event_date %td
save "`pairfile'", replace
clear
set obs 26
gen long id = _n
gen long study_start = 0
format study_start %td
quietly datasignature
local sig_before "`r(datasignature)'"
capture noisily migrations, migfile("`pairfile'")
local long_missing_rc = _rc
quietly datasignature
local sig_after "`r(datasignature)'"
ar_check "SET-H04 all .a-.z long dates reject with rollback" ///
    `=(`long_missing_rc' == 198 & "`sig_before'" == "`sig_after'")'

clear
input long id byte sentinel_value
99 7
end
save "`sentinel'", replace
tempfile sentinel_hash_before sentinel_hash_after ///
    sentinel_stat_before sentinel_stat_after
shell /usr/bin/sha256sum "`sentinel'" > "`sentinel_hash_before'"
shell /usr/bin/stat -c "%y|%z|%s|%i" "`sentinel'" > "`sentinel_stat_before'"
file open `hash_handle' using "`sentinel_hash_before'", read text
file read `hash_handle' sentinel_line_before
file close `hash_handle'
local sentinel_before : word 1 of `sentinel_line_before'
file open `hash_handle' using "`sentinel_stat_before'", read text
file read `hash_handle' sentinel_stat_line_before
file close `hash_handle'

clear
input long id long in_1 long out_1
1 . .
end
format in_1 out_1 %td
save "`migfile'", replace
clear
input long id long study_start str4 marker
1 0 "keep"
end
format study_start %td
quietly datasignature
local transaction_sig_before "`r(datasignature)'"
capture noisily migrations, migfile("`migfile'") ///
    saveexclude("`sentinel'") ///
    savecensor("`missing_dir'/late_failure.dta") replace
local transaction_rc = _rc
quietly datasignature
local transaction_sig_after "`r(datasignature)'"
shell /usr/bin/sha256sum "`sentinel'" > "`sentinel_hash_after'"
shell /usr/bin/stat -c "%y|%z|%s|%i" "`sentinel'" > "`sentinel_stat_after'"
file open `hash_handle' using "`sentinel_hash_after'", read text
file read `hash_handle' sentinel_line_after
file close `hash_handle'
local sentinel_after : word 1 of `sentinel_line_after'
file open `hash_handle' using "`sentinel_stat_after'", read text
file read `hash_handle' sentinel_stat_line_after
file close `hash_handle'
local sentinel_was_touched = ///
    (`"`sentinel_stat_line_before'"' != `"`sentinel_stat_line_after'"')
capture confirm file "`missing_dir'/late_failure.dta"
local late_file_absent = (_rc != 0)
ar_check "SET-C04 late second-export failure rolls back data and first file" ///
    `=(`transaction_rc' != 0 & ///
       "`transaction_sig_before'" == "`transaction_sig_after'" & ///
       "`sentinel_before'" == "`sentinel_after'" & ///
       `sentinel_was_touched' & `late_file_absent')'

clear
input long id long in_1 long out_1
1 . -10
end
format in_1 out_1 %td
save "`migfile'", replace
clear
input long id long study_start
1 0
2 0
end
format study_start %td
quietly migrations, migfile("`migfile'") flag
matrix flow = r(flow)
capture {
    assert r(N_final) == 1
    assert r(N_analytic) == 1
    assert r(N_returned) == 2
    assert rowsof(flow) == 8
    assert flow[7, 1] == 1
    assert flow[8, 1] == 2
}
ar_check "SET-M03 flag separates analytic and returned populations" ///
    `=(_rc == 0)'

foreach file in `migfile' `pairfile' `linkfile' `sentinel' {
    capture erase "`file'"
}
shell /bin/rm -rf -- "`missing_dir'"

display as result "Results: " ar_pass "/" ar_tests " passed, " ///
    ar_fail " failed"
display "RESULT: test_audit_regressions tests=" ar_tests ///
    " pass=" ar_pass " fail=" ar_fail
if ar_fail > 0 exit 9

do "`qa_dir'/_setools_qa_common.do" teardown

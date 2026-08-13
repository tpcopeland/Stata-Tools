*! test_tvtools_v1141.do
*! Regression coverage for the tvtools 1.14.1 artifact/display fixes.
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "test_tvtools_v1141.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global K3_TESTS = 0
global K3_PASS = 0
global K3_FAIL = 0
global K3_FAILED ""

capture program drop _k3_record
program define _k3_record
    args ok code detail
    global K3_TESTS = $K3_TESTS + 1
    if `ok' {
        global K3_PASS = $K3_PASS + 1
        display as result "  PASS: `code'"
    }
    else {
        global K3_FAIL = $K3_FAIL + 1
        global K3_FAILED "$K3_FAILED `code'"
        display as error "  FAIL: `code' (`detail')"
    }
end

capture program drop _k3_make_panel
program define _k3_make_panel
    version 16.0
    clear
    set seed 20260807
    quietly set obs 80
    quietly generate long pid = _n
    quietly generate double frailty = rnormal()
    quietly expand 5
    quietly bysort pid: generate int period = _n
    quietly generate double age = 45 + 4 * frailty + period
    quietly generate byte sex = mod(pid, 2)
    quietly generate double xb = -0.4 + 0.3 * frailty + 0.08 * period
    quietly generate byte treat = runiform() < invlogit(xb)
    quietly drop xb
end

display as result "tvtools QA: 1.14.1 regressions -- $S_DATE $S_TIME"

**# tvbuild guidance and manifest provenance
quietly {
    clear
    input long id double(entry exit)
        1 21915 21930
        2 21915 21930
    end
    format entry exit %td
    tempfile cohort source events
    save `cohort'

    clear
    input long id double(rx_start rx_stop) byte drug
        1 21918 21922 1
        2 21920 21924 2
    end
    format rx_start rx_stop %td
    save `source'

    clear
    input long id double(event_date)
        1 21921
        2 .
    end
    format event_date %td
    save `events'
}

local build_log "$TVTOOLS_QA_RUN_DIR/k3_tvbuild.log"
capture noisily {
    quietly log using "`build_log'", replace text nomsg name(k3build)
    use `cohort', clear
    noisily tvbuild, sourceusing(`"`source'"') id(id) entry(entry) exit(exit) ///
        start(rx_start) stop(rx_stop) exposure(drug) reference(0) ///
        generate(tv_drug) sourcename(drug_source) label("Drug exposure") ///
        frameout(k3_result) ///
        eventusing(`"`events'"') eventdate(event_date) ///
        eventgenerate(outcome) manifestframe(k3_manifest) replace
    local build_entryvar "`r(entryvar)'"
    local build_exitvar "`r(exitvar)'"
    quietly log close k3build
}
local build_rc = _rc
capture log close k3build
local build_content ""
if `build_rc' == 0 local build_content = fileread("`build_log'")

local ok = `build_rc' == 0 & ///
    strpos(`"`build_content'"', "time0(start - 1)") > 0 & ///
    strpos(`"`build_content'"', "time0(start)") == 0
_k3_record `ok' C1_tvbuild_time0 "rc=`build_rc'"

local event_locator ""
local event_vars ""
local source_description ""
local source_name ""
local exposure_label ""
if `build_rc' == 0 {
    frame k3_manifest: quietly levelsof input_locator if stage == "event", ///
        local(event_locator) clean
    frame k3_manifest: quietly levelsof input_vars if stage == "event", ///
        local(event_vars) clean
    frame k3_manifest: quietly levelsof description if stage == "source", ///
        local(source_description) clean
    frame k3_manifest: quietly levelsof source_name if stage == "source", ///
        local(source_name) clean
    frame k3_result: local exposure_label : variable label tv_drug
}
local ok = `build_rc' == 0 & `"`event_locator'"' == `"`events'"' & ///
    strpos("`event_vars'", "event_date") > 0
_k3_record `ok' C4_event_provenance "locator=`event_locator' vars=`event_vars'"

local ok = `build_rc' == 0 & `"`source_description'"' != "inline source" & ///
    "`source_name'" == "drug_source" & "`exposure_label'" == "Drug exposure" & ///
    "`build_entryvar'" == "entry" & "`build_exitvar'" == "exit"
_k3_record `ok' M8_source_description ///
    "description=`source_description' source=`source_name' label=`exposure_label'"

**# tvdiagnose verbose headers
local diagnose_log "$TVTOOLS_QA_RUN_DIR/k3_tvdiagnose.log"
capture noisily {
    quietly log using "`diagnose_log'", replace text nomsg name(k3diag)
    clear
    input long id double(start stop entry exit) byte exposure
        1 1 3 1 10 0
        1 6 10 1 10 1
        2 1 10 1 10 0
    end
    noisily tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) ///
        entry(entry) exit(exit) coverage gaps verbose
    quietly log close k3diag
}
local diagnose_rc = _rc
capture log close k3diag
local diagnose_content ""
if `diagnose_rc' == 0 local diagnose_content = fileread("`diagnose_log'")
local ok = `diagnose_rc' == 0 & ///
    strpos(`"`diagnose_content'"', "pct_covered") > 0 & ///
    strpos(`"`diagnose_content'"', "gap_start") > 0 & ///
    strpos(`"`diagnose_content'"', "__000") == 0
_k3_record `ok' C2_verbose_headers "rc=`diagnose_rc'"

**# tvweight analysis-weight and graph output
local weight_log "$TVTOOLS_QA_RUN_DIR/k3_tvweight.log"
capture noisily {
    quietly log using "`weight_log'", replace text nomsg name(k3weight)
    _k3_make_panel
    quietly scatter treat period, name(tvw_histogram, replace)
    noisily tvweight treat, covariates(age sex) id(pid) time(period) ///
        generate(iptw) cumulative cumgenerate(cumw) histogram ///
        truncate(1 99) estname(k3_ps)
    local got_w_mean = r(w_mean)
    local got_ess = r(ess)
    local got_histogram_graph `"`r(histogram_graph)'"'
    quietly summarize cumw, meanonly
    local want_w_mean = r(mean)
    quietly generate double k3_w2 = cumw^2
    quietly summarize cumw, meanonly
    local k3_sw = r(sum)
    quietly summarize k3_w2, meanonly
    local want_ess = (`k3_sw'^2) / r(sum)
    noisily estimates dir k3_ps
    quietly log close k3weight
}
local weight_rc = _rc
capture log close k3weight
local weight_content ""
if `weight_rc' == 0 local weight_content = fileread("`weight_log'")

local ok = `weight_rc' == 0 & strpos(`"`weight_content'"', "(bin=") == 0
_k3_record `ok' C3_histogram_echo "rc=`weight_rc'"

local ok = `weight_rc' == 0 & ///
    reldif(`got_w_mean', `want_w_mean') < 1e-12 & ///
    reldif(`got_ess', `want_ess') < 1e-12 & ///
    strpos(`"`weight_content'"', "Analysis weight cumw") > 0
_k3_record `ok' C6_cumulative_diagnostics "mean=`got_w_mean'/`want_w_mean'"

local ok = `weight_rc' == 0 & ///
    strpos(`"`weight_content'"', "1st and 99th") > 0 & ///
    strpos(`"`weight_content'"', "1th") == 0
_k3_record `ok' M1_ordinal_suffix "rc=`weight_rc'"

local ok = `weight_rc' == 0 & ///
    strpos(`"`weight_content'"', "tvweight propensity model") > 0
_k3_record `ok' M9_estimate_title "rc=`weight_rc'"

local ok = `weight_rc' == 0 & `"`got_histogram_graph'"' != "" & ///
    `"`got_histogram_graph'"' != "tvw_histogram"
_k3_record `ok' M5_graph_name "name=`got_histogram_graph'"

**# saveas messages and save echo
local save_log "$TVTOOLS_QA_RUN_DIR/k3_saveas.log"
capture noisily {
    quietly log using "`save_log'", replace text nomsg name(k3save)
    clear
    input long id double(dob entry exit)
        1 10000 21915 22280
        2 11000 21915 22280
    end
    noisily tvage, id(id) dob(dob) entry(entry) exit(exit) ///
        saveas("$TVTOOLS_QA_RUN_DIR/age_out.dta") replace noisily

    clear
    input long id double(start stop)
        1 21915 22280
        2 21915 22280
    end
    noisily tvband, id(id) start(start) stop(stop) type(calendar) ///
        saveas("$TVTOOLS_QA_RUN_DIR/band_out.dta") replace noisily

    clear
    input long id double(start stop) byte drug
        1 21920 22000 1
    end
    tempfile panel_source
    save `panel_source'
    clear
    input long id double(entry exit)
        1 21915 22280
        2 21915 22280
    end
    noisily tvpanel using `panel_source', id(id) entry(entry) exit(exit) ///
        exposure(drug) saveas("$TVTOOLS_QA_RUN_DIR/panel_out.dta") ///
        replace noisily
    quietly log close k3save
}
local save_rc = _rc
capture log close k3save
local save_content ""
if `save_rc' == 0 local save_content = fileread("`save_log'")
foreach cmd in age band panel {
    local ok = `save_rc' == 0 & ///
        strpos(`"`save_content'"', "`cmd'_out.dta.dta") == 0 & ///
        strpos(`"`save_content'"', "file $TVTOOLS_QA_RUN_DIR/`cmd'_out.dta saved") == 0 & ///
        strpos(`"`save_content'"', "`cmd'_out.dta") > 0
    _k3_record `ok' I1_I2_`cmd'_save_message "rc=`save_rc'"
}

**# tvevent validation alignment and flow-note relevance
local event_log "$TVTOOLS_QA_RUN_DIR/k3_tvevent.log"
capture noisily {
    quietly log using "`event_log'", replace text nomsg name(k3event)
    clear
    input long id double(start stop)
        1 100 200
        2 100 200
    end
    tempfile intervals
    save `intervals'
    clear
    input long id double(event_date)
        1 150
        2 .
    end
    noisily tvevent using `intervals', id(id) date(event_date) ///
        generate(outcome) validate flow replace
    quietly log close k3event
}
local event_rc = _rc
capture log close k3event
local event_content ""
if `event_rc' == 0 local event_content = fileread("`event_log'")
local ok = `event_rc' == 0 & ///
    strpos(`"`event_content'"', "events outside bounds") > 0 & ///
    strpos(`"`event_content'"', "events outside interval bounds") == 0
_k3_record `ok' I3_validation_alignment "rc=`event_rc'"

local ok = `event_rc' == 0 & ///
    strpos(`"`event_content'"', "A negative records-dropped count") == 0
_k3_record `ok' I4_tvevent_flow_note "rc=`event_rc'"

**# tvexpose label, bytype map, and flow-note relevance
local expose_log "$TVTOOLS_QA_RUN_DIR/k3_tvexpose.log"
capture noisily {
    quietly log using "`expose_log'", replace text nomsg name(k3expose)
    clear
    input long id double(rx_start rx_stop) byte drug
        1 100 200 1
        2 100 200 2
    end
    tempfile expose_source
    save `expose_source'
    clear
    input long id double(entry exit)
        1 100 200
        2 100 200
    end
    label data "Original cohort"
    noisily tvexpose using `expose_source', id(id) start(rx_start) ///
        stop(rx_stop) exposure(drug) reference(0) entry(entry) exit(exit) ///
        evertreated bytype generate(bt) flow ///
        saveas("$TVTOOLS_QA_RUN_DIR/expose_out.dta") replace
    local bytype_map `"`r(bytype_map)'"'
    local memory_label : data label
    quietly describe using "$TVTOOLS_QA_RUN_DIR/expose_out.dta"
    quietly use "$TVTOOLS_QA_RUN_DIR/expose_out.dta", clear
    local file_label : data label
    quietly log close k3expose
}
local expose_rc = _rc
capture log close k3expose
local expose_content ""
if `expose_rc' == 0 local expose_content = fileread("`expose_log'")
local ok = `expose_rc' == 0 & ///
    strpos(`"`memory_label'"', "/") == 0 & ///
    strpos(`"`file_label'"', "/") == 0 & ///
    `"`memory_label'"' == `"`file_label'"'
_k3_record `ok' C5_semantic_data_label "memory=`memory_label' file=`file_label'"

local ok = `expose_rc' == 0 & `"`bytype_map'"' != "" & ///
    strpos(`"`expose_content'"', `"`bytype_map'"') > 0
_k3_record `ok' I6_bytype_display "map=`bytype_map'"

local ok = `expose_rc' == 0 & ///
    strpos(`"`expose_content'"', "A negative records-dropped count") == 0
_k3_record `ok' I4_tvexpose_flow_note "rc=`expose_rc'"

**# tvspec runnable hint
local spec_log "$TVTOOLS_QA_RUN_DIR/k3_tvspec.log"
capture noisily {
    quietly log using "`spec_log'", replace text nomsg name(k3spec)
    frame change default
    capture frame drop k3spec
    tvspec create k3spec, replace
    tvspec add k3spec, name(drug) using(`"`source'"') start(rx_start) ///
        stop(rx_stop) exposure(drug) generate(tv_drug) reference(0)
    * The public dispatcher exercises its internal tvspec_list program here.
    noisily tvspec list k3spec
    quietly log close k3spec
}
local spec_rc = _rc
capture log close k3spec
local spec_content ""
if `spec_rc' == 0 local spec_content = fileread("`spec_log'")
local ok = `spec_rc' == 0 & ///
    strpos(`"`spec_content'"', "id(idvar)") > 0 & ///
    strpos(`"`spec_content'"', "id()") == 0
_k3_record `ok' I5_tvspec_hint "rc=`spec_rc'"

**# tvtools catalog framing and Unicode row width
local catalog_log "$TVTOOLS_QA_RUN_DIR/k3_catalog.log"
local catalog_version ""
capture noisily {
    quietly log using "`catalog_log'", replace text nomsg name(k3catalog)
    noisily tvtools, list
    * Read r() before closing the log; a log command clears it.
    local catalog_version "`r(version)'"
    quietly log close k3catalog
}
local catalog_rc = _rc
capture log close k3catalog
local catalog_content ""
if `catalog_rc' == 0 local catalog_content = fileread("`catalog_log'")
local rule68 "--------------------------------------------------------------------"
local first_rule = strpos(`"`catalog_content'"', "`rule68'")
local second_rule = 0
if `first_rule' > 0 {
    local rest = substr(`"`catalog_content'"', `first_rule' + 1, .)
    local second_rule = strpos(`"`rest'"', "`rule68'")
}
* The banner version is compared against r(version) rather than a literal. A
* hardcoded version here has to be edited on every release and silently turns
* the framing check red when it is not -- and the invariant that actually
* matters is that the rendered banner and the stored result agree, which a
* literal cannot express. Package-wide version consistency is gated separately
* by `check version tvtools`.
local ok = `catalog_rc' == 0 & "`catalog_version'" != "" & ///
    strpos(`"`catalog_content'"', "Version `catalog_version'") > 0 & ///
    `second_rule' > 0
_k3_record `ok' M2_catalog_frame ///
    "rc=`catalog_rc' version=`catalog_version'"

local unicode_log "$TVTOOLS_QA_RUN_DIR/k3_unicode.log"
capture noisily {
    quietly log using "`unicode_log'", replace text nomsg name(k3unicode)
    noisily _tvtools_row "x", value("1") pad(1) indent(0)
    noisily _tvtools_row "å", value("1") pad(1) indent(0)
    quietly log close k3unicode
}
local unicode_rc = _rc
capture log close k3unicode
local unicode_content ""
if `unicode_rc' == 0 local unicode_content = fileread("`unicode_log'")
local ascii_pos = strpos(`"`unicode_content'"', "x : 1")
local unicode_pos = strpos(`"`unicode_content'"', "å : 1")
local ok = `unicode_rc' == 0 & `ascii_pos' > 0 & `unicode_pos' > 0
_k3_record `ok' M7_unicode_width "ascii=`ascii_pos' unicode=`unicode_pos'"

**# Summary
display as result "tvtools 1.14.1 regressions: $K3_PASS/$K3_TESTS passed"
display "RESULT: test_tvtools_v1141 tests=$K3_TESTS pass=$K3_PASS fail=$K3_FAIL"
if $K3_FAIL > 0 {
    display as error "Failed tests:$K3_FAILED"
    capture log close _all
    exit 1
}
capture log close _all

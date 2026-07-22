* test_deep_audit_core.do - fail-first regressions for the 2026-07 deep audit

clear all
set more off
set varabbrev off
version 16.0

capture log close _deepcore
log using "test_deep_audit_core.log", replace text name(_deepcore) nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`c(tmpdir)'/`c(pid)'_tabtools_deep_audit"
capture mkdir "`output_dir'"
local workbook_tool "`qa_dir'/tools/make_deep_audit_workbook.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

capture findfile _tabtools_common.ado
if _rc == 0 run "`r(fn)'"

**# C01, M15, M16: workbook extent and side-effect preflight

local ++test_count
local dense "`output_dir'/dense.xlsx"
local dense_sig "`output_dir'/dense.original.json"
capture erase "`dense'"
capture erase "`dense_sig'"
quietly shell python3 "`workbook_tool'" "`dense'" dense
quietly shell python3 "`workbook_tool'" "`dense'" dense --snapshot "`dense_sig'"
capture noisily {
    stacktab using "`dense'", blocks(sheet(Source) rows(1/2) cols(A-B)) ///
        sheet(Target) append
    assert r(append_start) == 20006
    shell python3 "`workbook_tool'" "`dense'" dense --verify "`dense_sig'"
    preserve
    import excel "`dense'", sheet(Target) cellrange(A20001:C20007) ///
        allstring clear
    assert A[1] == "original-20001"
    assert B[1] == "sentinel-20001"
    assert A[5] == "original-20005"
    assert C[5] == "sentinel-20005"
    assert A[6] == ""
    assert B[6] == "label"
    restore
}
if _rc == 0 {
    display as result "  PASS C01a: dense used range appends after row 20,005"
    local ++pass_count
}
else {
    display as error "  FAIL C01a: dense used range (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
foreach mode in sparse far-right formatted-tail numeric {
    local key = subinstr("`mode'", "-", "_", .)
    local wb "`output_dir'/`mode'.xlsx"
    local sig "`output_dir'/`mode'.original.json"
    capture erase "`wb'"
    capture erase "`sig'"
    quietly shell python3 "`workbook_tool'" "`wb'" `mode'
    quietly shell python3 "`workbook_tool'" "`wb'" `mode' --snapshot "`sig'"
    capture noisily stacktab using "`wb'", ///
        blocks(sheet(Source) rows(1/2) cols(A-B)) sheet(Target) append
    local rc_`key' = _rc
    local start_`key' = cond(_rc == 0, r(append_start), .)
    capture noisily shell python3 "`workbook_tool'" "`wb'" `mode' --verify "`sig'"
    local hash_`key'_rc = _rc
}
capture noisily {
    assert `rc_sparse' == 0
    assert `start_sparse' == 514
    assert `hash_sparse_rc' == 0
    assert `rc_far_right' == 0
    assert `start_far_right' == 701
    assert `hash_far_right_rc' == 0
    assert `rc_formatted_tail' == 0
    assert `start_formatted_tail' == 901
    assert `hash_formatted_tail_rc' == 0
    assert `rc_numeric' == 0
    assert `start_numeric' == 778
    assert `hash_numeric_rc' == 0
}
if _rc == 0 {
    display as result "  PASS C01b: sparse, XFD, formatted-tail, and numeric ranges preserve original hashes"
    local ++pass_count
}
else {
    display as error "  FAIL C01b: sparse/XFD/formatted ranges (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
local collision "`output_dir'/collision.xlsx"
local collision_csv "`output_dir'/collision.csv"
local collision_md "`output_dir'/collision.md"
capture erase "`collision'"
capture erase "`collision_csv'"
capture erase "`collision_md'"
quietly shell python3 "`workbook_tool'" "`collision'" case
capture frame drop collision_sink
frame create collision_sink
frame collision_sink: set obs 1
frame collision_sink: generate str20 sentinel = "frame-unchanged"
capture noisily stacktab using "`collision'", ///
    blocks(sheet(Source) rows(1/2) cols(A-B)) sheet(Target) ///
    frame(collision_sink, replace) csv("`collision_csv'") ///
    markdown("`collision_md'")
local collision_rc = _rc
capture confirm file "`collision_csv'"
local collision_csv_exists = (_rc == 0)
capture confirm file "`collision_md'"
local collision_md_exists = (_rc == 0)
capture noisily {
    assert `collision_rc' == 602
    frame collision_sink: confirm variable sentinel
    frame collision_sink: assert sentinel[1] == "frame-unchanged"
    assert !`collision_csv_exists'
    assert !`collision_md_exists'
}
if _rc == 0 {
    display as result "  PASS M15: known sheet collision leaves every sink unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL M15: collision preflight atomicity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
local late_csv "`output_dir'/late-failure.csv"
local late_md "`output_dir'/late-failure.md"
capture erase "`late_csv'"
capture erase "`late_md'"
tempname late_csv_fh late_md_fh
file open `late_csv_fh' using "`late_csv'", write text replace
file write `late_csv_fh' "sentinel-csv" _n
file close `late_csv_fh'
file open `late_md_fh' using "`late_md'", write text replace
file write `late_md_fh' "sentinel-md" _n
file close `late_md_fh'
capture frame drop late_failure_sink
frame create late_failure_sink
frame late_failure_sink: set obs 1
frame late_failure_sink: generate str20 sentinel = "frame-unchanged"
capture noisily stacktab using "`collision'", ///
    blocks(sheet(Source) rows(1/2) cols(A-B)) sheet(LateTarget) ///
    frame(late_failure_sink, replace) csv("`late_csv'") ///
    markdown("`late_md'")
local late_failure_rc = _rc
file open `late_csv_fh' using "`late_csv'", read text
file read `late_csv_fh' late_csv_first
file close `late_csv_fh'
file open `late_md_fh' using "`late_md'", read text
file read `late_md_fh' late_md_first
file close `late_md_fh'
quietly import excel using "`collision'", describe
local late_sheet_exists = 0
forvalues late_s = 1/`r(N_worksheet)' {
    if lower(`"`r(worksheet_`late_s')'"') == "latetarget" ///
        local late_sheet_exists = 1
}
capture noisily {
    assert `late_failure_rc' == 602
    assert `"`late_csv_first'"' == "sentinel-csv"
    assert `"`late_md_first'"' == "sentinel-md"
    assert !`late_sheet_exists'
    frame late_failure_sink: confirm variable sentinel
    frame late_failure_sink: assert sentinel[1] == "frame-unchanged"
}
if _rc == 0 {
    display as result "  PASS M15b: late Markdown collision is rejected before frame, CSV, or workbook mutation"
    local ++pass_count
}
else {
    display as error "  FAIL M15b: late-sink preflight atomicity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily stacktab using "`collision'", ///
    blocks(sheet(Source) rows(1/2) cols(A-B)) sheet(target)
local case_default_rc = _rc
capture noisily stacktab using "`collision'", ///
    blocks(sheet(Source) rows(1/2) cols(A-B)) sheet(tArGeT) append
local case_append_rc = _rc
local case_sheet "`r(sheet)'"
capture noisily {
    assert `case_default_rc' == 602
    assert `case_append_rc' == 0
    assert "`case_sheet'" == "Target"
}
if _rc == 0 {
    display as result "  PASS M16: worksheet names resolve case-insensitively"
    local ++pass_count
}
else {
    display as error "  FAIL M16: worksheet case contract (rc=`=_rc')"
    local ++fail_count
}

**# C02-C05: frames, composites, and GLM scale

local ++test_count
sysuse auto, clear
collect clear
collect: regress price foreign mpg weight
capture frame drop alias_source
capture frame drop alias_plot
regtab, frame(alias_source, replace) eplotframe(alias_plot, replace) noint
frame alias_source: local alias_before = A[4]
capture noisily comptab alias_source, rows(1) ///
    eplotframe(alias_source, replace)
local source_alias_rc = _rc
capture noisily {
    assert `source_alias_rc' == 198
    frame alias_source: confirm variable A
    frame alias_source: assert A[4] == `"`alias_before'"'
}
if _rc == 0 {
    display as result "  PASS C02a: source=eplot alias rejected before mutation"
    local ++pass_count
}
else {
    display as error "  FAIL C02a: source=eplot alias safety (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture frame drop alias_source
regtab, frame(alias_source, replace) noint
capture frame drop alias_both
capture noisily comptab alias_source, rows(1) ///
    frame(alias_both, replace) eplotframe(alias_both, replace)
local output_alias_rc = _rc
capture noisily assert `output_alias_rc' == 198
if _rc == 0 {
    display as result "  PASS C02b: display=eplot alias rejected"
    local ++pass_count
}
else {
    display as error "  FAIL C02b: display=eplot alias (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture frame drop alias_source
capture frame drop alias_plot
regtab, frame(alias_source, replace) eplotframe(alias_plot, replace) noint
frame alias_source: quietly datasignature
local alias_source_sig `"`r(datasignature)'"'
frame alias_plot: quietly datasignature
local alias_plot_sig `"`r(datasignature)'"'
capture noisily comptab alias_source, rows(1) frame(alias_source, replace)
local source_display_rc = _rc
capture noisily comptab alias_source, rows(1) eplotframe(alias_plot, replace)
local companion_alias_rc = _rc
capture frame drop alias_current
frame create alias_current
frame alias_current: set obs 1
frame alias_current: generate str20 sentinel = "current-unchanged"
frame change alias_current
capture noisily comptab alias_source, rows(1) frame(alias_current, replace)
local current_dest_rc = _rc
frame change default
capture noisily {
    assert `source_display_rc' == 198
    assert `companion_alias_rc' == 198
    assert `current_dest_rc' == 198
    frame alias_source: quietly datasignature
    assert `"`r(datasignature)'"' == `"`alias_source_sig'"'
    frame alias_plot: quietly datasignature
    assert `"`r(datasignature)'"' == `"`alias_plot_sig'"'
    frame alias_current: assert sentinel[1] == "current-unchanged"
}
if _rc == 0 {
    display as result "  PASS C02c: complete source/companion/current alias graph is non-destructive"
    local ++pass_count
}
else {
    display as error "  FAIL C02c: complete frame-name graph (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture frame drop tx_display
capture frame drop tx_plot
frame create tx_display
frame tx_display: set obs 1
frame tx_display: generate str20 sentinel = "display-old"
frame create tx_plot
frame tx_plot: set obs 1
frame tx_plot: generate str20 sentinel = "plot-old"
global TABTOOLS_QA_REG_STAGE_FAIL 1
capture noisily regtab, frame(tx_display, replace) eplotframe(tx_plot, replace) noint
local tx_reg_rc = _rc
global TABTOOLS_QA_REG_STAGE_FAIL
capture noisily {
    assert `tx_reg_rc' == 459
    frame tx_display: assert sentinel[1] == "display-old"
    frame tx_plot: assert sentinel[1] == "plot-old"
}

matrix TXE = (1.2, .9, 1.6, .2)
matrix rownames TXE = Effect
global TABTOOLS_QA_EFFECT_STAGE_FAIL 1
capture noisily effecttab, from(TXE) frame(tx_display, replace) eplotframe(tx_plot, replace)
local tx_effect_rc = _rc
global TABTOOLS_QA_EFFECT_STAGE_FAIL
capture noisily {
    assert `tx_effect_rc' == 459
    frame tx_display: assert sentinel[1] == "display-old"
    frame tx_plot: assert sentinel[1] == "plot-old"
}

global TABTOOLS_QA_COMP_STAGE_FAIL 1
capture noisily comptab alias_source, rows(1) ///
    frame(tx_display, replace) eplotframe(tx_plot, replace)
local tx_comp_rc = _rc
global TABTOOLS_QA_COMP_STAGE_FAIL
capture noisily {
    assert `tx_comp_rc' == 459
    frame tx_display: assert sentinel[1] == "display-old"
    frame tx_plot: assert sentinel[1] == "plot-old"
    frame alias_source: quietly datasignature
    assert `"`r(datasignature)'"' == `"`alias_source_sig'"'
}
if _rc == 0 {
    display as result "  PASS C02d: injected post-stage failures preserve all frame destinations and sources"
    local ++pass_count
}
else {
    display as error "  FAIL C02d: post-stage transaction rollback (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
collect clear
collect: regress price foreign mpg weight
capture frame drop current_source
regtab, frame(current_source, replace) noint
capture frame drop current_reference
comptab current_source, rows(1) frame(current_reference, replace)
frame current_reference: local ref_N = _N
frame current_reference: local ref_A = A[4]
frame current_reference: local ref_c1 = c1[4]
frame change current_source
capture frame drop current_result
capture noisily comptab current_source, rows(1) frame(current_result, replace)
local current_source_rc = _rc
frame change default
capture noisily {
    assert `current_source_rc' == 0
    frame current_result: assert _N == `ref_N'
    frame current_result: assert A[4] == `"`ref_A'"'
    frame current_result: assert c1[4] == `"`ref_c1'"'
}
if _rc == 0 {
    display as result "  PASS C03: current source equals unrelated-current control"
    local ++pass_count
}
else {
    display as error "  FAIL C03: current-source composite (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
sysuse auto, clear
collect clear
collect: regress price mpg
collect: regress weight mpg
capture frame drop semantic_a
regtab, frame(semantic_a, replace) noint ///
    models("Price outcome \ Weight outcome")
collect clear
collect: regress weight mpg
collect: regress price mpg
capture frame drop semantic_b
regtab, frame(semantic_b, replace) noint ///
    models("Weight outcome \ Price outcome")
capture frame drop semantic_out
capture noisily comptab semantic_a semantic_b, rows(1 \ 1) ///
    frame(semantic_out, replace)
local semantic_rc = _rc
capture noisily {
    assert `semantic_rc' == 0
    frame semantic_out: assert c1[4] == "-238.89"
    frame semantic_out: assert c4[4] == "-108.43"
    frame semantic_out: assert c1[5] == "-238.89"
    frame semantic_out: assert c4[5] == "-108.43"
}
if _rc == 0 {
    display as result "  PASS C04: reversed model order is aligned by identity"
    local ++pass_count
}
else {
    display as error "  FAIL C04: semantic model alignment (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture frame drop semantic_bad_outcome
capture frame drop semantic_label_ref
capture frame drop semantic_bad_labels
capture frame drop semantic_bad_stats
capture frame drop semantic_bad_scale
frame copy semantic_b semantic_bad_outcome
frame copy semantic_a semantic_label_ref
frame copy semantic_b semantic_bad_labels
frame copy semantic_b semantic_bad_stats
frame copy semantic_b semantic_bad_scale
frame semantic_bad_outcome: char _dta[tabtools_outcome_id_1] "not_an_outcome"
frame semantic_bad_outcome: char _dta[tabtools_outcome_id_2] "not_an_outcome"
frame semantic_bad_labels: char _dta[tabtools_outcome_id_1] ""
frame semantic_bad_labels: char _dta[tabtools_outcome_id_2] ""
frame semantic_label_ref: char _dta[tabtools_outcome_id_1] ""
frame semantic_label_ref: char _dta[tabtools_outcome_id_2] ""
frame semantic_bad_labels: char _dta[tabtools_model_label_1] "Duplicate"
frame semantic_bad_labels: char _dta[tabtools_model_label_2] "Duplicate"
frame semantic_bad_stats: char _dta[tabtools_statistic_ids] "ci estimate pvalue"
frame semantic_bad_scale: char _dta[tabtools_effect_scale_1] "OR"
frame semantic_a: quietly datasignature
local semantic_a_sig `"`r(datasignature)'"'
frame semantic_b: quietly datasignature
local semantic_b_sig `"`r(datasignature)'"'
capture noisily comptab semantic_a semantic_bad_outcome, rows(1 \ 1)
local bad_outcome_rc = _rc
capture noisily comptab semantic_label_ref semantic_bad_labels, rows(1 \ 1)
local bad_labels_rc = _rc
capture noisily comptab semantic_a semantic_bad_stats, rows(1 \ 1)
local bad_stats_rc = _rc
capture noisily comptab semantic_a semantic_bad_scale, rows(1 \ 1)
local bad_scale_rc = _rc
capture noisily {
    assert `bad_outcome_rc' == 198
    assert `bad_labels_rc' == 198
    assert `bad_stats_rc' == 198
    assert `bad_scale_rc' == 198
    frame semantic_a: quietly datasignature
    assert `"`r(datasignature)'"' == `"`semantic_a_sig'"'
    frame semantic_b: quietly datasignature
    assert `"`r(datasignature)'"' == `"`semantic_b_sig'"'
    frame semantic_out: local out_id_1 : char _dta[tabtools_outcome_id_1]
    frame semantic_out: local out_id_2 : char _dta[tabtools_outcome_id_2]
    frame semantic_out: local out_scale_1 : char _dta[tabtools_effect_scale_1]
    frame semantic_out: local out_stats : char _dta[tabtools_statistic_ids]
    assert "`out_id_1'" == "price"
    assert "`out_id_2'" == "weight"
    assert "`out_scale_1'" == "Coef."
    assert "`out_stats'" == "estimate ci pvalue"
}
if _rc == 0 {
    display as result "  PASS C04b: mismatched/duplicate identities, statistic order, and scale cannot false-green"
    local ++pass_count
}
else {
    display as error "  FAIL C04b: semantic provenance adversaries (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
sysuse auto, clear
collect clear
collect: glm foreign mpg, family(binomial) link(logit)
local want_or = exp(_b[mpg])
capture frame drop glm_logit
regtab, frame(glm_logit, replace) noint
local glm_logit_label "`r(coef_label)'"
frame glm_logit: local got_or = real(c1[4])
collect clear
collect: glm foreign mpg, family(binomial) link(probit)
local want_probit = _b[mpg]
capture frame drop glm_probit
regtab, frame(glm_probit, replace) noint
local glm_probit_label "`r(coef_label)'"
frame glm_probit: local got_probit = real(c1[4])
capture noisily {
    assert "`glm_logit_label'" == "OR"
    assert reldif(`got_or', `want_or') < .01
    assert "`glm_probit_label'" == "Coef."
    assert reldif(`got_probit', `want_probit') < .01
}
if _rc == 0 {
    display as result "  PASS C05: GLM family/link determines transformation and label"
    local ++pass_count
}
else {
    display as error "  FAIL C05: GLM scale contract (rc=`=_rc')"
    local ++fail_count
}

**# M01-M05: Table 1 sample, coding, and weights

local ++test_count
clear
input byte keep byte x
1 0
1 1
0 2
end
_tabtools_detect_vartype x if keep
local if_type "`result'"
_tabtools_detect_vartype x in 1/2
local in_type "`result'"
capture noisily {
    assert "`if_type'" == "bin"
    assert "`in_type'" == "bin"
}
if _rc == 0 {
    display as result "  PASS M01: automatic type detection honors if/in"
    local ++pass_count
}
else {
    display as error "  FAIL M01: sample-aware type detection (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input byte x
1
2
1
2
end
_tabtools_detect_vartype x
capture noisily assert "`result'" == "cat"
if _rc == 0 {
    display as result "  PASS M02: non-0/1 dichotomies classify as categorical"
    local ++pass_count
}
else {
    display as error "  FAIL M02: two-level coding contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input byte g double x double w
0 1 1
0 2 2
1 3 1
1 4 2
end
generate double fw2 = 2*w
capture frame drop fw_control
capture frame drop fw_expression
table1_tc x [fw=fw2], by(g) vars(x contn) nopvalue ///
    frame(fw_control, replace)
capture noisily table1_tc x [fw=2*w], by(g) vars(x contn) nopvalue ///
    frame(fw_expression, replace)
local fw_expr_rc = _rc
capture noisily {
    assert `fw_expr_rc' == 0
    frame fw_control: local fw_c0 = g_0[3]
    frame fw_control: local fw_c1 = g_1[3]
    frame fw_expression: assert g_0[3] == `"`fw_c0'"'
    frame fw_expression: assert g_1[3] == `"`fw_c1'"'
}
if _rc == 0 {
    display as result "  PASS M03: compound fweight expressions equal materialized weights"
    local ++pass_count
}
else {
    display as error "  FAIL M03: fweight expression materialization (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input byte g double x double w
1 0 1
1 2 1
2 10 1
2 12 1
end
capture frame drop wt_base
table1_tc x, by(g) vars(x contn) wt(w) format(%9.3f) ///
    frame(wt_base, replace)
frame wt_base: local wt_base_1 = g_1[4]
frame wt_base: local wt_base_2 = g_2[4]
set obs 5
replace g = 1 in 5
replace x = 100 in 5
replace w = 0 in 5
capture frame drop wt_zero
table1_tc x, by(g) vars(x contn) wt(w) format(%9.3f) ///
    frame(wt_zero, replace)
capture noisily {
    frame wt_zero: assert g_1[4] == `"`wt_base_1'"'
    frame wt_zero: assert g_2[4] == `"`wt_base_2'"'
}
if _rc == 0 {
    display as result "  PASS M04: zero wt() rows leave weighted statistics invariant"
    local ++pass_count
}
else {
    display as error "  FAIL M04: zero-weight invariance (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
sysuse auto, clear
generate byte __hp = foreign
capture frame drop hp_collision
capture noisily table1_tc mpg, by(__hp) vars(mpg contn) headerperc ///
    frame(hp_collision, replace)
local hp_rc = _rc
capture noisily {
    assert `hp_rc' == 0
    frame hp_collision: confirm variable __hp_0
    frame hp_collision: confirm variable __hp_1
}
if _rc == 0 {
    display as result "  PASS M05: headerperc scratch variables cannot collide"
    local ++pass_count
}
else {
    display as error "  FAIL M05: headerperc collision (rc=`=_rc')"
    local ++fail_count
}

**# M06-M09: simulation identities, samples, and ingest

local ++test_count
clear
input byte estimator double estimate double se byte coverage
1 1 .1 1
1 2 .1 1
1 3 .1 .
1 4 .1 .
end
capture frame drop sim_missing
simtab estimator, estimate(estimate) se(se) true(0) coverage(coverage) ///
    metrics(mean coverage n) plotframe(sim_missing, replace)
frame sim_missing: local sim_n = n[1]
frame sim_missing: local sim_mean = mean[1]
capture noisily {
    assert `sim_n' == 4
    assert `sim_mean' == 2.5
    frame sim_missing: assert coverage[1] == 1
}
if _rc == 0 {
    display as result "  PASS M06: optional coverage missingness is metric-specific"
    local ++pass_count
}
else {
    display as error "  FAIL M06: metric-specific simulation samples (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
set obs 4
generate byte estimator = cond(_n <= 2, 1, 2)
label define duplicate_label 1 "Same" 2 "Same"
label values estimator duplicate_label
generate double estimate = cond(estimator == 1, 1, 10)
generate double se = .1
capture frame drop sim_labels
simtab estimator, estimate(estimate) se(se) true(0) metrics(mean n) ///
    plotframe(sim_labels, replace)
local sim_estimators = r(n_estimators)
capture noisily {
    assert `sim_estimators' == 2
    frame sim_labels: assert _N == 2
    frame sim_labels: assert mean[1] != mean[2]
    frame sim_labels: assert estimator_label[1] != estimator_label[2]
}
if _rc == 0 {
    display as result "  PASS M07: raw codes remain distinct from display labels"
    local ++pass_count
}
else {
    display as error "  FAIL M07: raw simulation identity (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input str1 estimator double mean_value
"A" 1
"A" 2
end
capture noisily simtab, from(summary) estimatorvar(estimator) ///
    measures(mean=mean_value) metrics(mean) display
local duplicate_cell_rc = _rc
capture noisily assert `duplicate_cell_rc' == 459
if _rc == 0 {
    display as result "  PASS M08: duplicate standardized cells fail r(459)"
    local ++pass_count
}
else {
    display as error "  FAIL M08: duplicate-cell rejection (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input str1 estimator byte group double mean_value str4 estlab
"B" 2 2 "user"
"A" 1 1 "user"
end
capture noisily simtab, from(summary) estimatorvar(estimator) by(group) ///
    measures(mean=mean_value) display
local ignored_by_rc = _rc
capture frame drop sim_order
capture noisily simtab, from(summary) estimatorvar(estimator) ///
    measures(mean=mean_value) order(data) frame(sim_order, replace)
local order_rc = _rc
capture noisily {
    assert `ignored_by_rc' == 198
    assert `order_rc' == 0
    frame sim_order: assert c1[2] == "B"
    frame sim_order: assert c1[3] == "A"
}
if _rc == 0 {
    display as result "  PASS M09: ingest rejects compute options and honors data order"
    local ++pass_count
}
else {
    display as error "  FAIL M09: ingest option/order contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
clear
input str1 estimator byte scenario str1 target double m_mean ///
    str4 bylab str4 estlab str4 emdlab double n long _obs
"B" 2 "X" 2 "user" "user" "user" 99 7
"A" 1 "X" 1 "user" "user" "user" 99 8
"B" 2 "Y" 3 "user" "user" "user" 99 9
end
capture frame drop sim_hostile
capture frame drop sim_hostile_plot
capture noisily simtab, from(summary) estimatorvar(estimator) ///
    byvar(scenario) estimandvar(target) measures(mean=m_mean) ///
    order(data) frame(sim_hostile, replace) plotframe(sim_hostile_plot, replace)
local hostile_rc = _rc
local hostile_cells = cond(`hostile_rc' == 0, r(N_cells), .)
capture noisily {
    assert `hostile_rc' == 0
    assert `hostile_cells' == 3
    frame sim_hostile_plot: assert _N == 3
    frame sim_hostile_plot: assert estimator_label[1] == "B"
    frame sim_hostile_plot: assert by_label[1] == "2"
    frame sim_hostile_plot: assert estimand_label[1] == "X"
}
if _rc == 0 {
    display as result "  PASS M08/M09b: incomplete grids and hostile legal names preserve raw cell identity"
    local ++pass_count
}
else {
    display as error "  FAIL M08/M09b: ingest false-green identity/grid contract (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display as text ""
display as text "RESULT: test_deep_audit_core tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _deepcore

capture frame change default
capture frame drop alias_source
capture frame drop alias_plot
capture frame drop alias_both
capture frame drop current_source
capture frame drop current_reference
capture frame drop current_result
capture frame drop semantic_a
capture frame drop semantic_b
capture frame drop semantic_out
capture frame drop semantic_bad_outcome
capture frame drop semantic_label_ref
capture frame drop semantic_bad_labels
capture frame drop semantic_bad_stats
capture frame drop semantic_bad_scale
capture frame drop sim_hostile
capture frame drop sim_hostile_plot
capture frame drop collision_sink
capture frame drop late_failure_sink

if `fail_count' > 0 exit 9
exit 0

* test_audit_remediation.do - durable regressions for the comprehensive audit
clear all
set more off
version 16.0

local qa_dir "`c(pwd)'"
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local ++test_count
capture noisily do "`qa_dir'/audit/validation_monotreat_risk.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: validation_monotreat_risk"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' validation_monotreat_risk"
    display as error "  FAIL: validation_monotreat_risk (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/validation_joint_mediator.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: validation_joint_mediator"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' validation_joint_mediator"
    display as error "  FAIL: validation_joint_mediator (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/validation_boceam.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: validation_boceam"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' validation_boceam"
    display as error "  FAIL: validation_boceam (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/validation_factor_msm.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: validation_factor_msm"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' validation_factor_msm"
    display as error "  FAIL: validation_factor_msm (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_imputation_no_donor.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_imputation_no_donor"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_imputation_no_donor"
    display as error "  FAIL: test_imputation_no_donor (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_extended_missing.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_extended_missing"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_extended_missing"
    display as error "  FAIL: test_extended_missing (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_multicontrol.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_multicontrol"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_multicontrol"
    display as error "  FAIL: test_multicontrol (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_saved_match.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_saved_match"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_saved_match"
    display as error "  FAIL: test_saved_match (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_saving_schema.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_saving_schema"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_saving_schema"
    display as error "  FAIL: test_saving_schema (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_caller_state.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_caller_state"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_caller_state"
    display as error "  FAIL: test_caller_state (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_alias_fv.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_alias_fv"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_alias_fv"
    display as error "  FAIL: test_alias_fv (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_scratch_collision.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_scratch_collision"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_scratch_collision"
    display as error "  FAIL: test_scratch_collision (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_option_contract.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_option_contract"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_option_contract"
    display as error "  FAIL: test_option_contract (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_structural_contract.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_structural_contract"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_structural_contract"
    display as error "  FAIL: test_structural_contract (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_rules_imputation.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_rules_imputation"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_rules_imputation"
    display as error "  FAIL: test_rules_imputation (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_model_metadata.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_model_metadata"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_model_metadata"
    display as error "  FAIL: test_model_metadata (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_gcomptab_remediation.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_gcomptab_remediation"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_gcomptab_remediation"
    display as error "  FAIL: test_gcomptab_remediation (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_gcomptab_text_adversarial.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_gcomptab_text_adversarial"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_gcomptab_text_adversarial"
    display as error "  FAIL: test_gcomptab_text_adversarial (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_gcomptab_option_style.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_gcomptab_option_style"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_gcomptab_option_style"
    display as error "  FAIL: test_gcomptab_option_style (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_gcomptab_msm_effect.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_gcomptab_msm_effect"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_gcomptab_msm_effect"
    display as error "  FAIL: test_gcomptab_msm_effect (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_late_error_state.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_late_error_state"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_late_error_state"
    display as error "  FAIL: test_late_error_state (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_msm_command_collision.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_msm_command_collision"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_msm_command_collision"
    display as error "  FAIL: test_msm_command_collision (rc=`=_rc')"
}

local ++test_count
capture noisily do "`qa_dir'/audit/test_fv_prefix_collision.do"
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: test_fv_prefix_collision"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' test_fv_prefix_collision"
    display as error "  FAIL: test_fv_prefix_collision (rc=`=_rc')"
}

if `fail_count' > 0 {
    display as error "Failed audit probes:`failed_tests'"
    display "RESULT: test_audit_remediation tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display "RESULT: test_audit_remediation tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"

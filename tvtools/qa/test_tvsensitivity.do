/*******************************************************************************
* test_tvsensitivity.do
*
* Purpose: Functional tests for tvsensitivity command
*          Tests E-value calculation, bias analysis, protective effects
*
* Run: stata-mp -b do test_tvsensitivity.do
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

local root_dir "`c(pwd)'"
capture net uninstall tvtools
quietly net install tvtools, from("`root_dir'/tvtools") replace

local pass_count = 0
local fail_count = 0

display as text _newline _dup(70) "="
display as text "tvsensitivity Functional Tests"
display as text _dup(70) "="

* ============================================================================
* TEST 1: E-value for RR=2.0
* ============================================================================
display as text _newline "TEST 1: E-value for RR=2.0"
display as text _dup(70) "-"

tvsensitivity, rr(2.0)
local evalue = r(evalue)

* Formula: E = RR + sqrt(RR * (RR - 1)) = 2 + sqrt(2*1) = 2 + 1.4142 = 3.4142
local expected = 2.0 + sqrt(2.0 * 1.0)
local diff = abs(`evalue' - `expected')

if `diff' < 0.0001 {
    display as result "PASS: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' ")"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 2: E-value for RR=3.0
* ============================================================================
display as text _newline "TEST 2: E-value for RR=3.0"
display as text _dup(70) "-"

tvsensitivity, rr(3.0)
local evalue = r(evalue)
local expected = 3.0 + sqrt(3.0 * 2.0)
local diff = abs(`evalue' - `expected')

if `diff' < 0.0001 {
    display as result "PASS: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' ")"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 3: E-value for RR=1.5
* ============================================================================
display as text _newline "TEST 3: E-value for RR=1.5"
display as text _dup(70) "-"

tvsensitivity, rr(1.5)
local evalue = r(evalue)
local expected = 1.5 + sqrt(1.5 * 0.5)
local diff = abs(`evalue' - `expected')

if `diff' < 0.0001 {
    display as result "PASS: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' ")"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 4: E-value for null effect (RR=1.0)
* ============================================================================
display as text _newline "TEST 4: E-value for RR=1.0 (null)"
display as text _dup(70) "-"

tvsensitivity, rr(1.0)
local evalue = r(evalue)

* E-value for null should be 1.0
if abs(`evalue' - 1.0) < 0.0001 {
    display as result "PASS: E-value = " %8.4f `evalue' " (expected 1.0)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: E-value = " %8.4f `evalue' " (expected 1.0)"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 5: E-value for protective effect (RR=0.5)
* ============================================================================
display as text _newline "TEST 5: E-value for protective effect (RR=0.5)"
display as text _dup(70) "-"

tvsensitivity, rr(0.5)
local evalue = r(evalue)

* For protective: invert RR first, then apply formula
* 1/0.5 = 2.0, so E-value should be same as RR=2.0
local expected = 2.0 + sqrt(2.0 * 1.0)
local diff = abs(`evalue' - `expected')

if `diff' < 0.0001 {
    display as result "PASS: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' " for inverted RR)"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: E-value = " %8.4f `evalue' " (expected " %8.4f `expected' ")"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* TEST 6: Return values
* ============================================================================
display as text _newline "TEST 6: Return values present"
display as text _dup(70) "-"

tvsensitivity, rr(2.0)

capture assert r(evalue) != .
if _rc == 0 {
    display as result "PASS: r(evalue) exists"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL: r(evalue) not returned"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* SUMMARY
* ============================================================================

display as text _newline _dup(70) "="
display as text "SUMMARY: " as result `pass_count' " passed, " `fail_count' " failed"
display as text _dup(70) "="

if `fail_count' > 0 {
    exit 9
}

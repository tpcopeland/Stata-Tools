clear all
set more off
version 16.0

* run_all.do - Run datamap package QA suite

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local failures 0

capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace

capture noisily include "`qa_dir'/test_datamap.do"
local rc = _rc
if `rc' {
    display as error "test_datamap.do failed with rc `rc'"
    local ++failures
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture noisily include "`qa_dir'/test_datamap_bugfixes.do"
local rc = _rc
if `rc' {
    display as error "test_datamap_bugfixes.do failed with rc `rc'"
    local ++failures
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture noisily include "`qa_dir'/test_datamap_v2.do"
local rc = _rc
if `rc' {
    display as error "test_datamap_v2.do failed with rc `rc'"
    local ++failures
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture noisily include "`qa_dir'/test_datamap_v11.do"
local rc = _rc
if `rc' {
    display as error "test_datamap_v11.do failed with rc `rc'"
    local ++failures
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture noisily include "`qa_dir'/test_datamap_privacy.do"
local rc = _rc
if `rc' {
    display as error "test_datamap_privacy.do failed with rc `rc'"
    local ++failures
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture noisily include "`qa_dir'/validation_datamap.do"
local rc = _rc
if `rc' {
    display as error "validation_datamap.do failed with rc `rc'"
    local ++failures
}

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture noisily include "`qa_dir'/test_datamap_golden.do"
local rc = _rc
if `rc' {
    display as error "test_datamap_golden.do failed with rc `rc'"
    local ++failures
}

if `failures' {
    display as error "`failures' datamap QA file(s) failed."
    exit 1
}

display as result "All datamap QA files completed."

* _install_msm_isolated.do
* Install msm into temporary sysdir locations for QA.

version 16.0

local pkg_dir `"`1'"'
if `"`pkg_dir'"' == "" {
    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."
}

local plus_dir "${msm_qa_plus_dir}"
local personal_dir "${msm_qa_personal_dir}"

* A master runner supplies process-unique directories through globals (globals
* survive child do-files' clear all). Standalone suites mint their own unique
* directories from Stata tempfile names, so two simultaneous runs never share
* an install target.
if "`plus_dir'" == "" | "`personal_dir'" == "" {
    tempfile plus_anchor personal_anchor
    local plus_dir "`plus_anchor'_plus"
    local personal_dir "`personal_anchor'_personal"
}

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"

sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
capture adopath - "`pkg_dir'"
capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace

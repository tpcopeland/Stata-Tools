* _install_msm_isolated.do
* Install msm into temporary sysdir locations for QA.

version 16.0

local pkg_dir `"`1'"'
if `"`pkg_dir'"' == "" {
    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."
}

local plus_dir "`c(tmpdir)'/msm_qa_plus"
local personal_dir "`c(tmpdir)'/msm_qa_personal"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"

sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
capture adopath - "`pkg_dir'"
capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace

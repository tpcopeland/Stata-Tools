/*  demo_msm_pipeline.do - Legacy alias for demo_msm.do

    Preserves the old entry point while delegating to the canonical
    repository demo.
*/

version 16.0
set more off
set varabbrev off
set linesize 250

local repo_root "`c(pwd)'"
capture confirm file "`repo_root'/msm/demo/demo_msm.do"

if _rc == 0 {
    do "`repo_root'/msm/demo/demo_msm.do"
}
else {
    do "demo_msm.do"
}

/*  demo_gcomptab.do - Compatibility entry point for the gcomp table demo

    The canonical workbook is generated only by demo_gcomp.do. This wrapper
    resolves the package root from any documented launch directory and invokes
    that one deterministic generator.

    Author: Timothy P Copeland, Karolinska Institutet
*/

version 16.0
set varabbrev off
set linesize 120

**# Relocatable package root

local launch_dir "`c(pwd)'"
local pkg_dir "`launch_dir'/gcomp"
capture confirm file "`pkg_dir'/gcomp.pkg"
if _rc {
    local pkg_dir "`launch_dir'"
    capture confirm file "`pkg_dir'/gcomp.pkg"
}
if _rc {
    local pkg_dir "`launch_dir'/.."
    capture confirm file "`pkg_dir'/gcomp.pkg"
}
if _rc {
    display as error "Run this demo from the Stata-Tools root, gcomp/, or gcomp/demo/."
    exit 601
}

do "`pkg_dir'/demo/demo_gcomp.do"
display "RESULT: demo_gcomptab wrapper status=PASS"

* _qa_bootstrap.do - Resolve gcomp from the package source without installation
version 16.0

local _qa_dir "`c(pwd)'"
local _pkg_dir = subinstr("`_qa_dir'", "/qa", "", 1)

* Put the development source ahead of any installed copy.  Every suite also
* verifies the resolved file so a stale PERSONAL/PLUS installation cannot pass.
adopath ++ "`_pkg_dir'"
discard

quietly findfile gcomp.ado
local _resolved = subinstr("`r(fn)'", "\\", "/", .)
local _expected = subinstr("`_pkg_dir'/gcomp.ado", "\\", "/", .)
if "`_resolved'" != "`_expected'" {
    display as error "QA source-resolution failure"
    display as error "  expected: `_expected'"
    display as error "  resolved: `_resolved'"
    exit 601
}

quietly findfile gcomptab.ado
local _resolved_tab = subinstr("`r(fn)'", "\\", "/", .)
local _expected_tab = subinstr("`_pkg_dir'/gcomptab.ado", "\\", "/", .)
if "`_resolved_tab'" != "`_expected_tab'" {
    display as error "QA source-resolution failure for gcomptab"
    display as error "  expected: `_expected_tab'"
    display as error "  resolved: `_resolved_tab'"
    exit 601
}

display as text "QA_SOURCE: `_expected'"

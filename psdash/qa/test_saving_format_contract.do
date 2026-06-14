* test_saving_format_contract.do
* Locks the v1.2.1 saving() contract: graphs are exported via `graph export`,
* so the output format is set by the filename extension (.png/.pdf/...), and a
* .gph extension errors predictably (users must use `graph save` for .gph).
* Also asserts the help documents this boundary so the wording cannot regress.
* Usage: cd psdash/qa && stata-mp -b do test_saving_format_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_saving_format_contract.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

capture program drop _sf_result
program define _sf_result
    args test_id rc
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global SF_PASS_COUNT = $SF_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global SF_FAIL_COUNT = $SF_FAIL_COUNT + 1
        global SF_FAILED_TESTS "$SF_FAILED_TESTS `test_id'"
    }
end

global SF_PASS_COUNT = 0
global SF_FAIL_COUNT = 0
global SF_FAILED_TESTS ""

capture program drop _sf_binary_data
program define _sf_binary_data
    clear
    set obs 20
    gen byte treat = (_n > 10)
    gen double ps = cond(treat, .35 + .025 * (_n - 10), .15 + .025 * _n)
    gen double x1 = cond(treat, 2, 1) + _n / 100
    gen double x2 = cond(treat, _n / 10, _n / 20)
    gen double wt = cond(treat, 1 / ps, 1 / (1 - ps))
end

local outdir "`_qa_sysroot'/saving"
capture mkdir "`outdir'"

**# Format-by-extension: a valid .pdf saving() target produces a PDF file

* Each graphing subcommand exercises its own _psdash_graph_export call site,
* so the contract is asserted per subcommand rather than just once.

capture noisily {
    _sf_binary_data
    capture erase "`outdir'/overlap.pdf"
    psdash overlap treat ps, saving("`outdir'/overlap.pdf")
    confirm file "`outdir'/overlap.pdf"
}
_sf_result "overlap_saving_pdf_creates_file" `=_rc'

capture noisily {
    _sf_binary_data
    capture erase "`outdir'/support.pdf"
    psdash support treat ps, saving("`outdir'/support.pdf")
    confirm file "`outdir'/support.pdf"
}
_sf_result "support_saving_pdf_creates_file" `=_rc'

capture noisily {
    _sf_binary_data
    capture erase "`outdir'/balance.pdf"
    psdash balance treat ps, covariates(x1 x2) wvar(wt) loveplot ///
        saving("`outdir'/balance.pdf")
    confirm file "`outdir'/balance.pdf"
}
_sf_result "balance_loveplot_saving_pdf_creates_file" `=_rc'

capture noisily {
    _sf_binary_data
    capture erase "`outdir'/weights.pdf"
    psdash weights treat ps, wvar(wt) graph saving("`outdir'/weights.pdf")
    confirm file "`outdir'/weights.pdf"
}
_sf_result "weights_graph_saving_pdf_creates_file" `=_rc'

capture noisily {
    _sf_binary_data
    capture erase "`outdir'/combined.pdf"
    psdash combined treat ps, covariates(x1 x2) wvar(wt) ///
        saving("`outdir'/combined.pdf")
    confirm file "`outdir'/combined.pdf"
}
_sf_result "combined_saving_pdf_creates_file" `=_rc'

**# Documented boundary: a .gph extension errors predictably (use graph save)

* `graph export` rejects a .gph target (rc 198); psdash must surface that as a
* nonzero command rc while preserving the analytical r() payload (failure
* contract). No .gph file should be left behind.

capture noisily {
    _sf_binary_data
    capture erase "`outdir'/overlap.gph"
    capture noisily psdash overlap treat ps, saving("`outdir'/overlap.gph")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    assert r(N) == 20
    assert r(N_treated) == 10
    assert "`r(psvar)'" == "ps"
    capture confirm file "`outdir'/overlap.gph"
    assert _rc != 0
}
_sf_result "overlap_saving_gph_errors_and_preserves_returns" `=_rc'

capture noisily {
    _sf_binary_data
    capture erase "`outdir'/balance.gph"
    capture noisily psdash balance treat ps, covariates(x1 x2) wvar(wt) ///
        loveplot saving("`outdir'/balance.gph")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    matrix B = r(balance)
    assert rowsof(B) == 2
    assert r(N) == 20
    confirm scalar r(max_smd_raw)
    capture confirm file "`outdir'/balance.gph"
    assert _rc != 0
}
_sf_result "balance_saving_gph_errors_and_preserves_returns" `=_rc'

**# Doc-contract: help text documents the saving() format boundary (v1.2.1)

capture noisily {
    local sthlp = fileread("`pkg_dir'/psdash.sthlp")
    * saving() is described as an image export keyed to the extension ...
    assert strpos(`"`sthlp'"', "image file") > 0
    * ... and points users to `graph save` for a .gph file.
    assert strpos(`"`sthlp'"', "graph save") > 0
    * Per-subcommand graph defaults are documented (nograph vs loveplot/graph).
    assert strpos(`"`sthlp'"', "draw a graph automatically") > 0
}
_sf_result "sthlp_documents_saving_format_boundary" `=_rc'

**# Summary

display as text _n "=== saving() format contract summary: " ///
    as result $SF_PASS_COUNT as text " passed, " ///
    as error $SF_FAIL_COUNT as text " failed ==="

local sf_total = $SF_PASS_COUNT + $SF_FAIL_COUNT
display "RESULT: test_saving_format_contract tests=`sf_total' pass=$SF_PASS_COUNT fail=$SF_FAIL_COUNT"

capture ado uninstall psdash
sysdir set PLUS "`_qa_plus_orig'"
sysdir set PERSONAL "`_qa_personal_orig'"
capture shell rm -rf "`_qa_sysroot'"
capture log close _all

if $SF_FAIL_COUNT > 0 {
    display as error "Failed tests: $SF_FAILED_TESTS"
    exit 9
}

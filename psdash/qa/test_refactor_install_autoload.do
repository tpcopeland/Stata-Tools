* test_refactor_install_autoload.do
* Installed-user autoload smoke tests for psdash public commands
* Usage: cd psdash/qa && stata-mp -b do test_refactor_install_autoload.do

clear all
version 16.0
set more off

capture log close _all
log using "test_refactor_install_autoload.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

local test_count = 0
global PSDASH_AUTOLOAD_PASS_COUNT = 0
global PSDASH_AUTOLOAD_FAIL_COUNT = 0
global PSDASH_AUTOLOAD_FAILED_TESTS ""

capture program drop _autoload_result
program define _autoload_result
    args test_id rc
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global PSDASH_AUTOLOAD_PASS_COUNT = $PSDASH_AUTOLOAD_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global PSDASH_AUTOLOAD_FAIL_COUNT = $PSDASH_AUTOLOAD_FAIL_COUNT + 1
        global PSDASH_AUTOLOAD_FAILED_TESTS "$PSDASH_AUTOLOAD_FAILED_TESTS `test_id'"
    }
end

capture program drop _autoload_data
program define _autoload_data
    clear
    set obs 12
    gen byte treat = (_n > 6)
    gen double ps = .
    replace ps = .20 in 1
    replace ps = .25 in 2
    replace ps = .35 in 3
    replace ps = .45 in 4
    replace ps = .55 in 5
    replace ps = .65 in 6
    replace ps = .35 in 7
    replace ps = .45 in 8
    replace ps = .55 in 9
    replace ps = .65 in 10
    replace ps = .75 in 11
    replace ps = .80 in 12
    gen double x1 = _n / 10
    gen double x2 = cond(treat, 1, 0) + _n / 100
    gen double wt = cond(treat, 1 / ps, 1 / (1 - ps))
end

local ++test_count
capture noisily {
    local manifest_ados ""
    tempname pkgfh
    file open `pkgfh' using "`pkg_dir'/psdash.pkg", read text
    file read `pkgfh' line
    while r(eof) == 0 {
        tokenize `"`line'"'
        if "`1'" == "f" & regexm("`2'", "[.]ado$") {
            local manifest_ados "`manifest_ados' `2'"
        }
        file read `pkgfh' line
    }
    file close `pkgfh'

    local root_ados : dir "`pkg_dir'" files "*.ado", respectcase
    local n_manifest : word count `manifest_ados'
    local n_root : word count `root_ados'
    assert `n_manifest' == `n_root'
    foreach f of local root_ados {
        local listed : list f in manifest_ados
        assert `listed'
    }
    foreach f of local manifest_ados {
        confirm file "`pkg_dir'/`f'"
        local stem = regexr("`f'", "[.]ado$", "")
        which `stem'
    }
}
_autoload_result installed_files_are_discoverable `=_rc'

local ++test_count
capture noisily {
    _autoload_data
    psdash overlap treat ps, nograph
    assert r(N) == 12
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
}
_autoload_result dispatcher_overlap_autoloads `=_rc'

local ++test_count
capture noisily {
    _autoload_data
    psdash_overlap treat ps, nograph
    assert r(N) == 12
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
}
_autoload_result direct_overlap_autoloads `=_rc'

local ++test_count
capture noisily {
    _autoload_data
    psdash_support treat ps, nograph
    assert r(N) == 12
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
    confirm scalar r(n_outside)
}
_autoload_result direct_support_autoloads `=_rc'

local ++test_count
capture noisily {
    _autoload_data
    psdash_balance treat ps, covariates(x1 x2) wvar(wt) nowvar
    assert r(N) == 12
    matrix B = r(balance)
    assert rowsof(B) == 2
}
_autoload_result direct_balance_autoloads `=_rc'

local ++test_count
capture noisily {
    _autoload_data
    psdash_weights treat ps, wvar(wt)
    assert r(N) == 12
    assert "`r(wvar)'" == "wt"
    confirm scalar r(ess)
}
_autoload_result direct_weights_autoloads `=_rc'

local ++test_count
capture noisily {
    _autoload_data
    * Autoload proof: if psdash_combined resolves and runs, it reaches the
    * RB-01 zero-panel guard and errors r(198); an unresolved program would
    * error r(199)/r(111) instead. So r(198) proves the autoload.
    capture psdash_combined treat ps, covariates(x1 x2) wvar(wt) ///
        nooverlap nobalance noweights nosupport
    assert _rc == 198
}
_autoload_result direct_combined_autoloads `=_rc'

display as text _n "=== Installed-user autoload summary: " ///
    as result $PSDASH_AUTOLOAD_PASS_COUNT as text " passed, " ///
    as error $PSDASH_AUTOLOAD_FAIL_COUNT as text " failed ==="
display as text "RESULT: test_refactor_install_autoload tests=`test_count' pass=$PSDASH_AUTOLOAD_PASS_COUNT fail=$PSDASH_AUTOLOAD_FAIL_COUNT skip=0"

_psdash_qa_cleanup
capture log close _all

if $PSDASH_AUTOLOAD_FAIL_COUNT > 0 {
    display as error "Failed tests: $PSDASH_AUTOLOAD_FAILED_TESTS"
    exit 9
}

global PSDASH_AUTOLOAD_PASS_COUNT
global PSDASH_AUTOLOAD_FAIL_COUNT
global PSDASH_AUTOLOAD_FAILED_TESTS

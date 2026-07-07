* _qba_qa_common.do -- shared QA bootstrap and assertion helpers for qba
* Usage: do _qba_qa_common.do from qba/qa, or do qa/_qba_qa_common.do from qba/

version 16.0

capture program drop _qba_qa_root
program define _qba_qa_root, rclass
    version 16.0

    local cwd "`c(pwd)'"
    local pkg_dir "`cwd'/.."
    capture confirm file "`pkg_dir'/qba.pkg"
    if _rc {
        local pkg_dir "`cwd'"
        capture confirm file "`pkg_dir'/qba.pkg"
        if _rc {
            display as error "could not locate qba package root from `c(pwd)'"
            exit 601
        }
    }

    local qa_dir "`pkg_dir'/qa"
    capture confirm file "`qa_dir'/run_all.do"
    if _rc {
        display as error "could not locate qba QA directory from `pkg_dir'"
        exit 601
    }

    return local pkg_dir `"`pkg_dir'"'
    return local qa_dir `"`qa_dir'"'
end

capture program drop _qba_qa_isolate
program define _qba_qa_isolate, rclass
    version 16.0

    local orig_plus "`c(sysdir_plus)'"
    local orig_personal "`c(sysdir_personal)'"
    local home : environment HOME
    if substr("`orig_plus'", 1, 2) == "~/" {
        local orig_plus_tail = substr("`orig_plus'", 3, .)
        local orig_plus "`home'/`orig_plus_tail'"
    }
    if substr("`orig_personal'", 1, 2) == "~/" {
        local orig_personal_tail = substr("`orig_personal'", 3, .)
        local orig_personal "`home'/`orig_personal_tail'"
    }
    tempfile qba_isolate
    local attempt = 0
    while 1 {
        if `attempt' == 0 {
            local suffix ""
        }
        else {
            local suffix "_`attempt'"
        }
        local plusdir "`qba_isolate'_plus`suffix'"
        local personaldir "`qba_isolate'_personal`suffix'"
        capture mkdir "`plusdir'"
        local rc_plus = _rc
        if !`rc_plus' {
            capture mkdir "`personaldir'"
            local rc_personal = _rc
            if !`rc_personal' {
                continue, break
            }
            capture shell rm -rf "`plusdir'"
        }
        local ++attempt
        if `attempt' > 100 {
            display as error "could not create unique qba QA isolation directories"
            exit 693
        }
    }

    sysdir set PLUS "`plusdir'"
    sysdir set PERSONAL "`personaldir'"

    return local orig_plus `"`orig_plus'"'
    return local orig_personal `"`orig_personal'"'
    return local plusdir `"`plusdir'"'
    return local personaldir `"`personaldir'"'
end

capture program drop _qba_qa_restore_isolation
program define _qba_qa_restore_isolation
    version 16.0
    syntax , ORIGPLUS(string) ORIGPERSONAL(string) ///
        [PLUSDIR(string) PERSONALDIR(string) UNINSTALL]

    if "`uninstall'" != "" {
        capture ado uninstall qba
    }
    capture sysdir set PLUS "`origplus'"
    capture sysdir set PERSONAL "`origpersonal'"
    if `"`plusdir'"' != "" | `"`personaldir'"' != "" {
        capture shell rm -rf "`plusdir'" "`personaldir'"
    }
end

capture program drop _qba_qa_bootstrap
program define _qba_qa_bootstrap, rclass
    version 16.0
    syntax [, ISOLated]

    _qba_qa_root
    local qa_dir `"`r(qa_dir)'"'
    local pkg_dir `"`r(pkg_dir)'"'

    if "`isolated'" != "" {
        _qba_qa_isolate
        local orig_plus `"`r(orig_plus)'"'
        local orig_personal `"`r(orig_personal)'"'
        local plusdir `"`r(plusdir)'"'
        local personaldir `"`r(personaldir)'"'
    }

    capture ado uninstall qba
    quietly net install qba, from("`pkg_dir'") replace

    return local qa_dir `"`qa_dir'"'
    return local pkg_dir `"`pkg_dir'"'
    if "`isolated'" != "" {
        return local orig_plus `"`orig_plus'"'
        return local orig_personal `"`orig_personal'"'
        return local plusdir `"`plusdir'"'
        return local personaldir `"`personaldir'"'
    }
end

capture program drop _qba_qa_assert_close
program define _qba_qa_assert_close
    version 16.0
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001

    if missing(`actual') | missing(`expected') {
        assert missing(`actual') & missing(`expected')
        exit
    }

    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

capture program drop _assert_close
program define _assert_close
    version 16.0
    args actual expected tolerance
    _qba_qa_assert_close `actual' `expected' `tolerance'
end

capture program drop _qba_qa_assert_file_contains
program define _qba_qa_assert_file_contains
    version 16.0
    syntax using/ , Pattern(string)

    tempname fh
    local found = 0
    file open `fh' using "`using'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`pattern'"') local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
end

capture program drop _qba_qa_assert_file_not_contains
program define _qba_qa_assert_file_not_contains
    version 16.0
    syntax using/ , Pattern(string)

    tempname fh
    local found = 0
    file open `fh' using "`using'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', `"`pattern'"') local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 0
end

capture program drop _qba_qa_assert_file_equals
program define _qba_qa_assert_file_equals
    version 16.0
    syntax using/ , Text(string)

    tempname fh
    file open `fh' using "`using'", read text
    file read `fh' line
    file close `fh'
    assert `"`line'"' == `"`text'"'
end

capture program drop _assert_text_file_contains
program define _assert_text_file_contains
    version 16.0
    args path pattern
    _qba_qa_assert_file_contains using "`path'", pattern(`"`pattern'"')
end

capture program drop _assert_text_file_not_contains
program define _assert_text_file_not_contains
    version 16.0
    args path pattern
    _qba_qa_assert_file_not_contains using "`path'", pattern(`"`pattern'"')
end

capture program drop _assert_file_contains
program define _assert_file_contains
    version 16.0
    args path pattern
    _qba_qa_assert_file_contains using "`path'", pattern(`"`pattern'"')
end

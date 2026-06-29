* _finegray_qa_common.do - shared QA bootstrap for finegray

version 16.0
set more off
set varabbrev off

capture program drop _finegray_qa_bootstrap
program define _finegray_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
    capture confirm file "`pkg_dir'/finegray.pkg"
    if _rc {
        display as error "run_all.do must be run from the finegray/qa directory"
        exit 601
    }

    local orig_plus "`c(sysdir_plus)'"
    local orig_personal "`c(sysdir_personal)'"
    tempname install_id
    local install_tag = subinstr("`install_id'", "__", "", .)
    local plus_dir "`c(tmpdir)'/finegray_plus_`install_tag'"
    local personal_dir "`c(tmpdir)'/finegray_personal_`install_tag'"

    capture mkdir "`plus_dir'"
    capture mkdir "`personal_dir'"
    sysdir set PLUS "`plus_dir'"
    sysdir set PERSONAL "`personal_dir'"
    discard

    capture ado uninstall finegray
    capture noisily net install finegray, from("`pkg_dir'") replace
    local install_rc = _rc
    if `install_rc' {
        sysdir set PLUS "`orig_plus'"
        sysdir set PERSONAL "`orig_personal'"
        discard
        capture shell rm -rf "`plus_dir'" "`personal_dir'"
        exit `install_rc'
    }

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
    return local orig_plus "`orig_plus'"
    return local orig_personal "`orig_personal'"
    return local plus_dir "`plus_dir'"
    return local personal_dir "`personal_dir'"
end

version 16.0
* Shared QA scaffold for eplot.
* This package tracks no .dta input fixtures: every suite builds its own
* data via sysuse/seeded synthetic generators. Any transient dataset must
* use tempfile/c(tmpdir); never commit .dta under qa/.
capture program drop _eplot_qa_bootstrap
program define _eplot_qa_bootstrap, rclass
    version 16.0
    local qa_dir "`c(pwd)'"
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
    * Sandbox PLUS/PERSONAL under c(tmpdir) so the real ado tree is untouched.
    if "$EPLOT_QA_ISOLATED" == "" {
        tempfile _eplot_qa_base
        local plus_dir "`_eplot_qa_base'_plus"
        local personal_dir "`_eplot_qa_base'_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global EPLOT_QA_PLUS "`plus_dir'"
        global EPLOT_QA_PERSONAL "`personal_dir'"
        global EPLOT_QA_ISOLATED "1"
    }
    sysdir set PLUS "$EPLOT_QA_PLUS"
    sysdir set PERSONAL "$EPLOT_QA_PERSONAL"
    capture ado uninstall eplot
    quietly net install eplot, from("`pkg_dir'") replace
    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
end

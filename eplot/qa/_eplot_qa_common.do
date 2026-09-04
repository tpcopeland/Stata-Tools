version 16.0
* Shared QA scaffold for eplot.
* This package tracks no .dta input fixtures: every suite builds its own
* data via sysuse/seeded synthetic generators. Any transient dataset must
* use tempfile/c(tmpdir); never commit .dta under qa/.
capture program drop _eplot_qa_bootstrap
program define _eplot_qa_bootstrap, rclass
    version 16.0
    * Optional argument: the package directory. Suites that discover the
    * package directory themselves pass it so the sandbox install does not
    * depend on the process working directory.
    args pkgdir_arg
    local qa_dir "`c(pwd)'"
    if `"`pkgdir_arg'"' != "" {
        local pkg_dir `"`pkgdir_arg'"'
    }
    else {
        local pkg_dir = regexr("`qa_dir'", "/qa$", "")
    }
    * Sandbox PLUS/PERSONAL under c(tmpdir) so the real ado tree is untouched.
    * Every suite calls this before touching adopath or installing, so a
    * standalone run cannot write into the user's own ado tree either.
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

capture program drop _eplot_qa_result
program define _eplot_qa_result
    version 16.0
    * Emit the canonical RESULT sentinel and record it on disk where
    * run_all.do reconciles it. A suite that exits zero without a consistent
    * sentinel must not be able to pass the lane, so the arithmetic is
    * checked here and the file is the runner's evidence that it ran.
    syntax anything(name=_suite id="suite name"), ///
        TESTS(integer) PASS(integer) FAIL(integer) [SKIP(integer 0)]

    if `tests' < 0 | `pass' < 0 | `fail' < 0 | `skip' < 0 {
        display as error "_eplot_qa_result counts must be nonnegative"
        exit 198
    }
    if `tests' != `pass' + `fail' + `skip' {
        display as error ///
            "RESULT sentinel inconsistent for `_suite': tests=`tests' but pass+fail+skip=`=`pass'+`fail'+`skip''"
        exit 459
    }
    local _line "RESULT: `_suite' tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
    display "`_line'"
    tempname _fh
    quietly {
        capture file close `_fh'
        capture erase "`c(pwd)'/.eplot_qa_sentinel_`_suite'.txt"
        file open `_fh' using "`c(pwd)'/.eplot_qa_sentinel_`_suite'.txt", write text replace
        file write `_fh' "`_line'" _n
        file close `_fh'
    }
end

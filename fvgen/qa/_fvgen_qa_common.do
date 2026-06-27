version 16.0

* Shared QA scaffold for fvgen.
* - _fvgen_qa_bootstrap: sandbox PLUS/PERSONAL under c(tmpdir) and install
*   the local source so an installed/SSC copy cannot shadow it.
* - _fvgen_make_data: seeded synthetic dataset exercising the bug paths
*   (labeled categorical with an empty interaction cell, missing values,
*   a value label containing a double quote).
* No .dta fixtures are tracked; every suite builds its own data.

capture program drop _fvgen_qa_bootstrap
program define _fvgen_qa_bootstrap, rclass
    version 16.0

    local qa_dir "`c(pwd)'"
    local _qa_len = strlen("`qa_dir'")
    local pkg_dir = substr("`qa_dir'", 1, `_qa_len' - 3)

    if "$FLATINT_QA_ISOLATED" == "" {
        tempfile _fvgen_qa_base
        local plus_dir "`_fvgen_qa_base'_plus"
        local personal_dir "`_fvgen_qa_base'_personal"
        capture mkdir "`plus_dir'"
        capture mkdir "`personal_dir'"
        global FLATINT_QA_PLUS "`plus_dir'"
        global FLATINT_QA_PERSONAL "`personal_dir'"
        global FLATINT_QA_ISOLATED "1"
    }

    sysdir set PLUS "$FLATINT_QA_PLUS"
    sysdir set PERSONAL "$FLATINT_QA_PERSONAL"

    capture ado uninstall fvgen
    quietly net install fvgen, from("`pkg_dir'") replace

    return local qa_dir "`qa_dir'"
    return local pkg_dir "`pkg_dir'"
end

capture program drop _fvgen_make_data
program define _fvgen_make_data
    version 16.0
    args nobs seed_value
    if "`nobs'" == "" local nobs 400
    if "`seed_value'" == "" local seed_value 12345

    clear
    set seed `seed_value'
    set obs `nobs'

    * Three-level categorical with friendly labels.
    generate byte grp = 1 + int(3 * runiform())
    label define grpl 1 `"Low"' 2 `"Mid"' 3 `"High"'
    label values grp grpl

    * Binary arm with a value label that contains a double quote and an
    * ampersand, to exercise quote-safe label handling.
    generate byte arm = (runiform() > 0.5)
    label define arml 0 `"6" rim"' 1 `"large & wide"'
    label values arm arml

    * Continuous predictors.
    generate double age = 40 + 10 * rnormal()
    generate double bmi = 25 + 4 * rnormal()

    * Force an empty interaction cell: grp==3 never co-occurs with arm==1.
    replace arm = 0 if grp == 3

    * Inject missing values into one categorical and one continuous var.
    replace grp = . in 1/5
    replace age = . in 6/10

    * Outcome.
    generate double y = 2*age + 3*bmi + 5*arm + rnormal()
end

* test_console_display_contracts.do - automatic boxed console display contracts
* Date: 2026-05-23

clear all
set more off
set varabbrev off
version 17.0

capture log close _console_display
log using "test_console_display_contracts.log", replace text name(_console_display)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
quietly tabtools set clear

capture program drop _make_console_strate
program define _make_console_strate
    syntax , BASENAME(string)
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 18)
    gen double _Y = cond(_n == 1, 1000, 1200)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _console_exp 0 "None" 1 "Current", replace
    label values exposure _console_exp
    save "`basename'.dta", replace
end

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    local capture_log "`output_dir'/test_console_display_contracts_capture.log"
    capture erase "`capture_log'"
    capture log close _console_capture
    log using "`capture_log'", replace text name(_console_capture)

    sysuse auto, clear
    gen byte highrep = rep78 >= 4 if !missing(rep78)
    capture erase "`output_dir'/_console_contract_table1.xlsx"
    table1_tc price mpg foreign, vars(price contn \ mpg contn \ foreign bin) ///
        by(highrep) xlsx("`output_dir'/_console_contract_table1.xlsx") ///
        sheet("Table1") title("Console_Table1")
    confirm file "`output_dir'/_console_contract_table1.xlsx"

    sysuse auto, clear
    capture erase "`output_dir'/_console_contract_corrtab.xlsx"
    corrtab price mpg weight, pvalues xlsx("`output_dir'/_console_contract_corrtab.xlsx") ///
        sheet("Corr") title("Console_Corrtab")
    confirm file "`output_dir'/_console_contract_corrtab.xlsx"

    sysuse auto, clear
    capture erase "`output_dir'/_console_contract_crosstab.xlsx"
    crosstab rep78 foreign, xlsx("`output_dir'/_console_contract_crosstab.xlsx") ///
        sheet("Cross") title("Console_Crosstab")
    confirm file "`output_dir'/_console_contract_crosstab.xlsx"

    clear
    input byte(test gold)
    1 1
    1 1
    1 0
    0 0
    0 1
    0 0
    end
    capture erase "`output_dir'/_console_contract_diagtab.xlsx"
    diagtab test gold, xlsx("`output_dir'/_console_contract_diagtab.xlsx") ///
        sheet("Diag") title("Console_Diagtab")
    confirm file "`output_dir'/_console_contract_diagtab.xlsx"

    webuse drugtr, clear
    stset studytime, failure(died)
    capture erase "`output_dir'/_console_contract_survtab.xlsx"
    survtab, times(10 20) by(drug) xlsx("`output_dir'/_console_contract_survtab.xlsx") ///
        sheet("Surv") title("Console_Survtab")
    confirm file "`output_dir'/_console_contract_survtab.xlsx"

    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    capture erase "`output_dir'/_console_contract_regtab.xlsx"
    capture frame drop _console_reg
    regtab, xlsx("`output_dir'/_console_contract_regtab.xlsx") sheet("Reg") ///
        title("Console_Regtab") frame(_console_reg) noint
    confirm file "`output_dir'/_console_contract_regtab.xlsx"

    sysuse auto, clear
    collect clear
    collect: table foreign, statistic(mean price) statistic(sd price) statistic(count price)
    capture erase "`output_dir'/_console_contract_desctab.xlsx"
    desctab, xlsx("`output_dir'/_console_contract_desctab.xlsx") sheet("Desc") ///
        title("Console_Desctab")
    confirm file "`output_dir'/_console_contract_desctab.xlsx"

    matrix _console_eff = (1.50, 0.80, 2.20, 0.04 \ 2.30, 1.10, 3.50, 0.001)
    matrix rownames _console_eff = Age Sex
    capture erase "`output_dir'/_console_contract_effecttab.xlsx"
    effecttab, from(_console_eff) xlsx("`output_dir'/_console_contract_effecttab.xlsx") ///
        sheet("Effects") title("Console_Effecttab") effect("OR")
    confirm file "`output_dir'/_console_contract_effecttab.xlsx"

    tempfile rate1
    _make_console_strate, basename("`rate1'")
    capture erase "`output_dir'/_console_contract_stratetab.xlsx"
    capture frame drop _console_rates
    stratetab, using("`rate1'") outcomes(1) ///
        xlsx("`output_dir'/_console_contract_stratetab.xlsx") sheet("Rates") ///
        title("Console_Stratetab") frame(_console_rates, replace)
    confirm file "`output_dir'/_console_contract_stratetab.xlsx"

    sysuse auto, clear
    collect clear
    gen byte treated = foreign
    collect: regress price treated mpg weight
    capture frame drop _console_model
    regtab, frame(_console_model) noint title("Console_Source_Regtab")

    capture erase "`output_dir'/_console_contract_comptab.xlsx"
    comptab _console_model, rows(1) xlsx("`output_dir'/_console_contract_comptab.xlsx") ///
        sheet("Comp") title("Console_Comptab")
    confirm file "`output_dir'/_console_contract_comptab.xlsx"

    capture erase "`output_dir'/_console_contract_hrcomptab.xlsx"
    hrcomptab _console_rates, modelframes(_console_model) rows(1) ///
        xlsx("`output_dir'/_console_contract_hrcomptab.xlsx") sheet("HR") ///
        title("Console_Hrcomptab")
    confirm file "`output_dir'/_console_contract_hrcomptab.xlsx"

    log close _console_capture

    local expected_titles ///
        Console_Table1 Console_Corrtab Console_Crosstab Console_Diagtab ///
        Console_Survtab Console_Regtab Console_Desctab Console_Effecttab ///
        Console_Stratetab Console_Comptab Console_Hrcomptab

    tempname fh
    local border_lines = 0
    local title_index = 0
    foreach title of local expected_titles {
        local ++title_index
        local found_`title_index' = 0
    }

    file open `fh' using "`capture_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "+") > 0 & strpos(`"`line'"', "---") > 0 {
            local ++border_lines
        }
        local title_index = 0
        foreach title of local expected_titles {
            local ++title_index
            if strpos(`"`line'"', "`title'") > 0 {
                local found_`title_index' = 1
            }
        }
        file read `fh' line
    }
    file close `fh'

    assert `border_lines' >= 22
    local title_index = 0
    foreach title of local expected_titles {
        local ++title_index
        assert `found_`title_index'' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: all public table commands auto-display boxed completed tables"
    local ++pass_count
}
else {
    capture log close _console_capture
    display as error "  FAIL: automatic console display contract (rc=`=_rc')"
    local ++fail_count
}

capture frame drop _console_reg
capture frame drop _console_model
capture frame drop _console_rates
quietly tabtools set clear

display as result "Console display contract QA: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _console_display
    exit 1
}

display as result "ALL CONSOLE DISPLAY CONTRACT TESTS PASSED"
log close _console_display

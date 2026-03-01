*! _tte_check_prepared Version 1.0.3  2026/03/01
*! Verify data has been through tte_prepare
*! Author: Timothy P Copeland

program define _tte_check_prepared
    version 16.0
    set varabbrev off
    set more off

    local prepared : char _dta[_tte_prepared]
    if "`prepared'" != "1" {
        display as error "data has not been prepared"
        display as error ""
        display as error "Run {bf:tte_prepare} to map your variables and set the estimand."
        display as error "Example:"
        display as error "  {cmd:tte_prepare, id(patid) period(period) treatment(treatment)}"
        display as error "  {cmd:  outcome(outcome) eligible(eligible) estimand(ITT)}"
        exit 198
    }
end

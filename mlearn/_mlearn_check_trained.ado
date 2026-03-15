*! _mlearn_check_trained Version 1.0.0  2026/03/15
*! Verify that mlearn train has been run
*! Author: Timothy P Copeland

program define _mlearn_check_trained
    version 16.0
    set varabbrev off
    set more off

    local trained : char _dta[_mlearn_trained]
    if "`trained'" != "1" {
        display as error "no mlearn model has been trained on this dataset"
        display as error ""
        display as error "Run {bf:mlearn} first to train a model."
        display as error "Example:"
        display as error "  {cmd:mlearn y x1 x2, method(forest) seed(42)}"
        exit 198
    }
end

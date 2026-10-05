*! _datacheck_ledger Version 1.9.2  2026/10/05
*! Append one datacheck call's gate records to a QA ledger dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// The ledger holds one row per gate entry, passed or failed, and one per
// review item.  Columns: run stamp seq dataset scope family label variable
// grp kind status observed observed_num expected n_scope version signature
// masked mincell minshown obs_masked message.
//
// observed and observed_num come from the record frame, where observed_num
// is already missing whenever observed was masked.  n_scope is set to
// missing below the mask threshold here.  masked is 1 when the call ran
// under maskrare with a threshold of at least 5; minshown is the smallest
// positive count printed unmasked in observed, so dataqa export can refuse a
// row that shows a small cell.  The file is created when absent; seq is the
// call number within run().
program define _datacheck_ledger, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _lf_made = 0
    local _ef_made = 0
    local nrows = 0
    local seq = 1
    tempname lf ef
    tempfile newrows
    capture noisily {
        syntax , RF(name) FILE(string) [RUN(string) DATASET(string) ///
            CALLSCOPE(string) VERSION(string) SIGNATURE(string) ///
            MASKRARE(integer 0) MINCELL(integer 0) MASK(integer 0)]
        frame copy `rf' `lf'
        local _lf_made = 1
        // file is final here: datacheck adds .dta before the call, so the
        // probe and the save below name the same path
        capture confirm file `"`file'"'
        local exists = (_rc == 0)
        if `exists' {
            frame create `ef'
            local _ef_made = 1
            frame `ef' {
                quietly use `"`file'"', clear
                foreach v in run seq dataset family label status observed observed_num kind {
                    capture confirm variable `v'
                    if _rc {
                        display as error `"ledger(): `file' is not a datacheck ledger (no variable `v')"'
                        exit 610
                    }
                }
                quietly summarize seq if run == `"`run'"', meanonly
                if r(N) > 0 local seq = r(max) + 1
            }
        }
        local stamp = string(clock(c(current_date) + " " + c(current_time), "DMYhms"), ///
            "%tcCCYY-NN-DD_HH:MM:SS")
        frame `lf' {
            local nrows = _N
            quietly {
                generate strL run = `"`run'"'
                generate str19 stamp = "`stamp'"
                generate long seq = `seq'
                generate strL dataset = `"`dataset'"'
                replace scope = cond(`"`callscope'"' != "" & scope != "", ///
                    `"`callscope'"' + " & " + scope, cond(scope != "", scope, `"`callscope'"'))
                replace nscope = . if `mask' > 0 & nscope < `mask' & nscope > 0
                generate str12 version = "`version'"
                generate strL signature = `"`signature'"'
                generate byte masked = (`maskrare' & `mask' >= 5)
                generate int mincell = `mask'
                rename fam family
                rename obsnum observed_num
                rename nscope n_scope
                rename omasked obs_masked
                rename msg message
                drop ok
                order run stamp seq dataset scope family label variable grp kind status ///
                    observed observed_num expected n_scope version signature masked ///
                    mincell minshown obs_masked message
            }
            quietly save `"`newrows'"'
        }
        if `exists' {
            frame `ef' {
                quietly append using `"`newrows'"'
                quietly save `"`file'"', replace
            }
        }
        else {
            frame `lf': quietly save `"`file'"'
        }
    }
    local rc = _rc
    if `_ef_made' capture frame drop `ef'
    if `_lf_made' capture frame drop `lf'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar rows = `nrows'
    return scalar seq = `seq'
end

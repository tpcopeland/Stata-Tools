*! _dataprobe_ledger Version 2.0.0  2026/11/10
*! Append one dataprobe call's gate records to a QA ledger dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// The ledger holds one row per gate entry, passed or failed, and one per
// review item.  Columns: run stamp seq dataset scope family label variable
// grp kind status observed observed_num expected n_scope version signature
// masked mincell minshown obs_masked message phase.  phase (2.1.0, U6) is
// the call's phase(), else the dataqa set phase() session default, else
// empty; a ledger written before 2.1.0 has no phase column, and its rows
// read as phase "" when new rows are appended.  A worker shard (2.1.0,
// F12; see the redirect below) has one more column, worker.
//
// observed and observed_num come from the record frame, where observed_num
// is already missing whenever observed was masked.  n_scope is set to
// missing below the mask threshold here.  masked is 1 when the call ran
// under maskrare with a threshold of at least 5; minshown is the smallest
// positive count printed unmasked in observed, so dataqa export can refuse a
// row that shows a small cell.  The file is created when absent; seq is the
// call number within run().
program define _dataprobe_ledger, rclass
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
            MASKRARE(integer 0) MINCELL(integer 0) MASK(integer 0) PHASE(string)]
        // the session phase when the caller gives none (an error row of a
        // call that failed to parse comes through _dataprobe_errrow)
        if "`phase'" == "" & `"$DATAMAP_DQ"' != "" {
            capture _datamap_dqdefaults
            if !_rc local phase "`r(phase)'"
        }
        if "`phase'" != "" confirm name `phase'
        // worker shards (2.1.0, F12): in a session set with dataqa set
        // worker(), every ledger write goes to that ledger's per-worker
        // shard, whose rows carry the worker id; dataqa merge folds the
        // shards into the ledger.  Without worker() nothing changes.
        local worker ""
        if `"$DATAMAP_DQ"' != "" {
            capture _datamap_dqdefaults
            if !_rc & "`r(worker)'" != "" {
                local worker "`r(worker)'"
                local _sdir `"`r(sharddir)'"'
                _dataqa_shardpath `"`file'"', worker(`worker') sharddir(`"`_sdir'"')
                local file `"`r(file)'"'
            }
        }
        frame copy `rf' `lf'
        local _lf_made = 1
        // file is final here: dataprobe adds .dta before the call, so the
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
                        display as error `"ledger(): `file' is not a dataprobe ledger (no variable `v')"'
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
                // run, dataset, scope and signature are stored from Mata:
                // the text is written as given, never re-expanded as macro
                // syntax (R1)
                generate strL run = ""
                mata: st_sstore(., "run", J(st_nobs(), 1, st_local("run")))
                generate str19 stamp = "`stamp'"
                generate long seq = `seq'
                generate strL dataset = ""
                mata: st_sstore(., "dataset", J(st_nobs(), 1, st_local("dataset")))
                recast strL scope
                mata: _dataprobe_ledger_scope(st_local("callscope"))
                replace nscope = . if `mask' > 0 & nscope < `mask' & nscope > 0
                generate str12 version = "`version'"
                generate strL signature = ""
                mata: st_sstore(., "signature", J(st_nobs(), 1, st_local("signature")))
                generate byte masked = (`maskrare' & `mask' >= 5)
                generate int mincell = `mask'
                rename fam family
                rename obsnum observed_num
                rename nscope n_scope
                rename omasked obs_masked
                rename msg message
                drop ok
                generate str32 phase = "`phase'"
                order run stamp seq dataset scope family label variable grp kind status ///
                    observed observed_num expected n_scope version signature masked ///
                    mincell minshown obs_masked message phase
                if "`worker'" != "" generate str32 worker = "`worker'"
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
    if "`worker'" != "" return local shard `"`file'"'
end

// The call's if/in scope joined to each row's own scope, as
// "callscope & scope"; stored from Mata, never re-expanded (R1).
capture mata: mata drop _dataprobe_ledger_scope()
mata:
void _dataprobe_ledger_scope(string scalar cs)
{
	string colvector sc
	real scalar i
	if (cs == "") return
	sc = st_sdata(., "scope")
	for (i = 1; i <= rows(sc); i++) sc[i] = (sc[i] != "" ? cs + " & " + sc[i] : cs)
	st_sstore(., "scope", sc)
}
end

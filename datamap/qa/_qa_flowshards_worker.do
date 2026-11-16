* _qa_flowshards_worker.do - one parallel worker of test_datamap_v210_flowshards.do (F12)
*
* Arguments: plus (the PLUS directory the suite installed datamap into),
* ledger, worker id, barrier directory, number of workers, number of calls.
* The worker waits until every worker is ready, then writes its ledger rows
* through dataqa set worker() at the same time as the others; halfway it
* waits again until every worker has written half its calls.  It writes
* <bar>/done_<id>.txt: "rc t_start t_end" (clock ms), whatever happens.
args plus ledger wid bar nw ncall
version 16.0
clear all
set processors 1
set more off
sysdir set PLUS "`plus'"
capture mkdir "`bar'/personal_`wid'"
sysdir set PERSONAL "`bar'/personal_`wid'"
discard
macro drop DATAMAP_DQ
local t0 = .
local t1 = .
capture noisily {
    tempname fh
    file open `fh' using "`bar'/ready_`wid'.txt", write text replace
    file write `fh' "ready" _n
    file close `fh'
    * the barrier: every worker ready (at most 180 s)
    local waited = 0
    local all = 0
    while !`all' & `waited' < 1800 {
        local all = 1
        forvalues k = 1/`nw' {
            capture confirm file "`bar'/ready_w`k'.txt"
            if _rc local all = 0
        }
        if !`all' {
            sleep 100
            local ++waited
        }
    }
    if !`all' {
        display as error "barrier timed out"
        exit 459
    }
    local t0 = clock(c(current_date) + " " + c(current_time), "DMYhms")
    dataqa set ledger("`ledger'") run(par) collect worker(`wid')
    local mid = ceil(`ncall' / 2)
    forvalues k = 1/`ncall' {
        * the second barrier: after half its calls each worker waits until
        * every worker has written half, so the shards are written in
        * overlapping periods, not one after another
        if `k' == `mid' + 1 {
            file open `fh' using "`bar'/mid_`wid'.txt", write text replace
            file write `fh' "mid" _n
            file close `fh'
            local waited = 0
            local all = 0
            while !`all' & `waited' < 1800 {
                local all = 1
                forvalues j = 1/`nw' {
                    capture confirm file "`bar'/mid_w`j'.txt"
                    if _rc local all = 0
                }
                if !`all' {
                    sleep 100
                    local ++waited
                }
            }
            if !`all' {
                display as error "mid barrier timed out"
                exit 459
            }
        }
        sysuse auto, clear
        * a passing invariant, a band that fails on every third call
        local hi = cond(mod(`k', 3) == 0, 19, 25)
        dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 `hi')) name(`wid'_d`k')
    }
    local t1 = clock(c(current_date) + " " + c(current_time), "DMYhms")
}
local rc = _rc
tempname dh
file open `dh' using "`bar'/done_`wid'.txt", write text replace
file write `dh' "`rc' " %21.0f (`t0') " " %21.0f (`t1') _n
file close `dh'
macro drop DATAMAP_DQ
exit, clear

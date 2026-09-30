*! _datacheck_intervals Version 1.8.0  2026/09/30
*! datacheck intervals(): interval-file structure checked on its own sort
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: id [id ...] start stop [, contiguous event(varname) tol(#)]
//
// Named checks, each posted as its own record (label = check name):
//   missing     start and stop nonmissing
//   order       start < stop
//   overlap     within id, sorted by start, start >= latest earlier stop - tol
//   gap         (contiguous) within id, start <= latest earlier stop + tol
//   event_last  (event()) the event is nonzero only on the id's last interval
//
// The helper sorts datacheck's working copy itself, so the caller's sort
// order does not matter.  Rows with a missing start or stop fail
// intervals(missing) and are left out of the ordering checks.  parseonly
// validates the spec and returns r(vars) without touching the data.
program define _datacheck_intervals, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local vars ""
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0)]
        local head `"`spec'"'
        local opts ""
        local cp = strpos(`"`spec'"', ",")
        if `cp' {
            local head = substr(`"`spec'"', 1, `cp' - 1)
            local opts = substr(`"`spec'"', `cp' + 1, .)
        }
        unab head : `head'
        local nw : word count `head'
        if `nw' < 3 {
            display as error `"intervals() spec must be "id start stop [, options]": `spec'"'
            exit 198
        }
        local start : word `=`nw' - 1' of `head'
        local stop : word `nw' of `head'
        local ids ""
        forvalues j = 1/`=`nw' - 2' {
            local ids "`ids' `: word `j' of `head''"
        }
        local ids = strtrim("`ids'")
        foreach tv in start stop {
            capture confirm numeric variable ``tv''
            if _rc {
                display as error "intervals(): ``tv'' is not numeric"
                exit 109
            }
        }
        local 0 `", `opts'"'
        syntax [, CONTiguous EVent(varname numeric) TOL(real 0)]
        if `tol' < 0 | missing(`tol') {
            display as error "intervals(): tol() must be non-negative"
            exit 198
        }
        local vars "`ids' `start' `stop' `event'"
        if "`parseonly'" == "" {

        local ttxt = strtrim(string(`tol', "%12.0g"))
        local ivars "`ids' `start' `stop'"
        tempvar nm prev last tg fail
        quietly generate byte `nm' = !missing(`start') & !missing(`stop')
        // prev is the latest stop so far within the id, so an interval nested
        // inside an earlier long one neither hides an overlap nor makes a gap
        tempvar runmax
        quietly bysort `nm' `ids' (`start' `stop'): generate double `runmax' = `stop' if `nm'
        quietly by `nm' `ids': replace `runmax' = max(`stop', `runmax'[_n-1]) if `nm' & _n > 1
        quietly by `nm' `ids': generate double `prev' = `runmax'[_n-1] if `nm' & _n > 1
        quietly by `nm' `ids': generate byte `last' = (_n == _N) & `nm'

        local checks "missing order overlap"
        if "`contiguous'" != "" local checks "`checks' gap"
        if "`event'" != "" local checks "`checks' event_last"
        foreach ck of local checks {
            capture drop `fail'
            capture drop `tg'
            if "`ck'" == "missing" {
                quietly generate byte `fail' = !`nm'
                local what "have a missing start or stop"
                local exp "start and stop nonmissing"
            }
            else if "`ck'" == "order" {
                quietly generate byte `fail' = `nm' & !(`start' < `stop')
                local what "have start >= stop"
                local exp "start < stop"
            }
            else if "`ck'" == "overlap" {
                quietly generate byte `fail' = `nm' & !missing(`prev') & `start' < `prev' - `tol'
                local what "overlap the previous interval"
                local exp "start >= latest earlier stop - `ttxt'"
            }
            else if "`ck'" == "gap" {
                quietly generate byte `fail' = `nm' & !missing(`prev') & `start' > `prev' + `tol'
                local what "start after the previous stop (gap)"
                local exp "start = latest earlier stop within `ttxt'"
            }
            else {
                quietly generate byte `fail' = !missing(`event') & `event' != 0 & !`last'
                local what "carry `event' on an interval other than the last"
                local exp "`event' nonzero only on the last interval"
            }
            quietly count if `fail'
            local nr = r(N)
            quietly egen byte `tg' = tag(`ids') if `fail'
            quietly count if `tg' == 1
            local np = r(N)
            _datacheck_mcount `nr' `mask' `nscope'
            local nrs "`r(s)'"
            local nrnum = r(num)
            local m1 = r(masked)
            _datacheck_mcount `np' `mask'
            local nps "`r(s)'"
            local m2 = r(masked)
            local om = (`m1' | `m2')
            if `om' local anymask = 1
            local mins = .
            if !`m1' & `nr' >= 1 local mins = `nr'
            if !`m2' & `np' >= 1 local mins = min(`mins', `np')
            local obs "`nrs' intervals in `nps' persons"
            local ok = (`nr' == 0)
            if `ok' local msg `"`pfx'intervals(`ck'): 0 intervals `what'"'
            else {
                local msg `"`pfx'intervals(`ck'): `obs' `what'"'
                local ++nfail
            }
            frame post `rf' ("intervals") ("`kind'") (`ok') ("`ck'") ("`ivars'") ///
                (`"`macval(grp)'"') ("`obs'") (`nrnum') (`"`exp'"') ///
                (`nscope') ("") (`"`macval(msg)'"') (`mins') (`om')
        }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
end

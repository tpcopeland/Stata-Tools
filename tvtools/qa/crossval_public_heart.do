*! crossval_public_heart.do -- tvsplit parity on Stanford heart data
*!
*! Oracle: survival::survSplit applied at runtime to survival::heart, the
*! public Stanford heart-transplant data described by Crowley and Hu (1977).
*! R uses half-open (start, stop] survival intervals. The Stata side maps each
*! source row to a closed daily interval [start, stop-1] before tvsplit, then
*! compares every resulting boundary for 30-day and 365-day elapsed grids.
*! Two source rows use half-days; both implementations exclude exactly those
*! rows because tvtools' public contract is whole daily dates.
*!
*! This is independent implementation parity on real delayed-entry data.

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "crossval_public_heart.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

display as result "tvtools crossval: public Stanford heart data -- $S_DATE $S_TIME"

**# Generate public data and R reference grids
_tvtools_qa_probe_rscript
local has_rscript = r(available)

if `has_rscript' {
    local raw "$TVTOOLS_QA_RUN_DIR/_xv_heart_raw.csv"
    local ref30 "$TVTOOLS_QA_RUN_DIR/_xv_heart_ref30.csv"
    local ref365 "$TVTOOLS_QA_RUN_DIR/_xv_heart_ref365.csv"
    local script "$TVTOOLS_QA_RUN_DIR/_xv_heart.R"
    local rlog "$TVTOOLS_QA_RUN_DIR/_xv_heart_r.log"

    capture file close _rf
    tempname _rf
    file open _rf using "`script'", write replace
    file write _rf "args <- commandArgs(trailingOnly=TRUE)" _n
    file write _rf "suppressPackageStartupMessages(library(survival))" _n
    file write _rf "h0 <- transform(heart, rowid=seq_len(nrow(heart)))" _n
    file write _rf "stopifnot(sum(h0\$start != floor(h0\$start) | h0\$stop != floor(h0\$stop)) == 2)" _n
    file write _rf "h <- subset(h0, start == floor(start) & stop == floor(stop))" _n
    file write _rf "raw <- h[,c('rowid','id','start','stop','transplant')]" _n
    file write _rf "names(raw) <- c('rowid','pid','rawstart','rawstop','transplant')" _n
    file write _rf "write.csv(raw, args[1], row.names=FALSE)" _n
    file write _rf "make_ref <- function(width, path) {" _n
    file write _rf "  cuts <- seq(width, max(h\$stop)-1, by=width)" _n
    file write _rf "  z <- survSplit(Surv(start,stop,event)~., data=h, cut=cuts)" _n
    file write _rf "  z <- z[order(z\$rowid,z\$start,z\$stop),]" _n
    file write _rf "  out <- z[,c('rowid','start','stop','transplant')]" _n
    file write _rf "  write.csv(out, path, row.names=FALSE)" _n
    file write _rf "}" _n
    file write _rf "make_ref(30, args[2])" _n
    file write _rf "make_ref(365, args[3])" _n
    file close _rf

    shell Rscript "`script'" "`raw'" "`ref30'" "`ref365'" > "`rlog'" 2>&1
    capture confirm file "`raw'"
    local setup_rc = _rc
    foreach f in "`ref30'" "`ref365'" {
        capture confirm file "`f'"
        if _rc local setup_rc = _rc
    }

    if `setup_rc' == 0 {
        **# Exact boundary parity across grid widths
        foreach width in 30 365 {
            local ++test_count
            if `width' == 30 local ref "`ref30'"
            else local ref "`ref365'"
            capture noisily {
                import delimited using "`raw'", clear varnames(1)
                assert _N == 170
                quietly count if rawstart > 0
                assert !missing(r(N))
                assert r(N) > 0
                quietly count if transplant == 1
                assert !missing(r(N))
                assert r(N) > 0

                generate double origin = mdy(1, 1, 1960)
                generate double enter = origin + rawstart
                generate double exit = origin + rawstop - 1
                format origin enter exit %td
                tvsplit, id(rowid) start(enter) stop(exit) ///
                    elapsed(origin, width(`width') unit(day) generate(fu))
                generate double start = enter - origin
                generate double stop = exit - origin
                keep rowid start stop transplant
                rename transplant transplant_tv
                sort rowid start stop
                isid rowid start stop
                tempfile got
                save `got'

                import delimited using "`ref'", clear varnames(1)
                replace stop = stop - 1
                sort rowid start stop
                isid rowid start stop
                merge 1:1 rowid start stop using `got', assert(match) nogenerate
                assert transplant == transplant_tv
            }
            if _rc == 0 {
                display as result "  PASS [H`width']: exact boundary parity vs survival::survSplit"
                local ++pass_count
            }
            else {
                display as error "  FAIL [H`width']: survSplit parity (rc `=_rc')"
                local ++fail_count
                local failed_tests "`failed_tests' H`width'"
            }
        }
    }
    else {
        display as error "  FAIL: R did not produce the Stanford heart references; see `rlog'"
        local fail_count = 2
        local failed_tests "H30 H365"
    }

    capture erase "`raw'"
    capture erase "`ref30'"
    capture erase "`ref365'"
    capture erase "`script'"
    capture erase "`rlog'"
}
else {
    display as text "  SKIP: Rscript is required for survival::heart parity"
    local skip_count = 2
}

**# Summary
local test_count = `pass_count' + `fail_count' + `skip_count'
display as result "Stanford heart cross-validation: `pass_count'/`test_count' passed"
display "RESULT: crossval_public_heart tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
    exit 1
}

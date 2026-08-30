*! crossval_public_pbc.do -- tvtools parity on the Mayo PBC example
*!
*! Oracle: the public survival::pbc and survival::pbcseq datasets and the
*! survival::tmerge worked example. R constructs last-value-carried-forward
*! bilirubin and prothrombin histories. Stata independently constructs the
*! same histories through tvexpose, combines them with tvmerge, and places
*! deaths with tvevent. Canonical rows and Cox coefficients must agree.
*!
*! The official survival time-dependent-covariate vignette prints coefficients
*! 1.241214 for log(bili) and 3.983400 for log(protime); the final check pins
*! the tvtools-built analysis data to that published worked example.

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "crossval_public_pbc.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

display as result "tvtools crossval: public Mayo PBC data -- $S_DATE $S_TIME"

**# Generate public inputs and the R tmerge oracle
_tvtools_qa_probe_rscript
local has_rscript = r(available)

if `has_rscript' {
    local basecsv "$TVTOOLS_QA_RUN_DIR/_xv_pbc_base.csv"
    local seqcsv "$TVTOOLS_QA_RUN_DIR/_xv_pbc_seq.csv"
    local refcsv "$TVTOOLS_QA_RUN_DIR/_xv_pbc_ref.csv"
    local coefcsv "$TVTOOLS_QA_RUN_DIR/_xv_pbc_coef.csv"
    local script "$TVTOOLS_QA_RUN_DIR/_xv_pbc.R"
    local rlog "$TVTOOLS_QA_RUN_DIR/_xv_pbc_r.log"

    capture file close _rf
    tempname _rf
    file open _rf using "`script'", write replace
    file write _rf "args <- commandArgs(trailingOnly=TRUE)" _n
    file write _rf "suppressPackageStartupMessages(library(survival))" _n
    file write _rf "base <- subset(pbc, id <= 312, select=c(id,time,status))" _n
    file write _rf "seqd <- pbcseq[,c('id','day','bili','protime')]" _n
    file write _rf "write.csv(base, args[1], row.names=FALSE)" _n
    file write _rf "write.csv(seqd, args[2], row.names=FALSE, na='')" _n
    file write _rf "p2 <- tmerge(base, base, id=id, endpt=event(time,status))" _n
    file write _rf "p2 <- tmerge(p2, seqd, id=id, bili=tdc(day,bili), protime=tdc(day,protime))" _n
    file write _rf "p2 <- p2[order(p2\$id,p2\$tstart,p2\$tstop),]" _n
    file write _rf "p2\$bili10 <- as.integer(round(10*p2\$bili))" _n
    file write _rf "p2\$protime10 <- as.integer(round(10*p2\$protime))" _n
    file write _rf "p2\$death <- as.integer(p2\$endpt == 2)" _n
    file write _rf "n <- nrow(p2)" _n
    file write _rf "new <- c(TRUE, p2\$id[-1] != p2\$id[-n] | p2\$tstart[-1] != p2\$tstop[-n] | p2\$bili10[-1] != p2\$bili10[-n] | p2\$protime10[-1] != p2\$protime10[-n])" _n
    file write _rf "p2\$grp <- cumsum(new)" _n
    file write _rf "pieces <- split(p2,p2\$grp)" _n
    file write _rf "canon <- do.call(rbind,lapply(pieces,function(g) data.frame(id=g\$id[1],start=min(g\$tstart),stop=max(g\$tstop),bili10=g\$bili10[1],protime10=g\$protime10[1],death=max(g\$death))))" _n
    file write _rf "rownames(canon) <- NULL" _n
    file write _rf "write.csv(canon,args[3],row.names=FALSE)" _n
    file write _rf "fit <- coxph(Surv(tstart,tstop,endpt==2) ~ log(bili)+log(protime), data=p2, ties='efron')" _n
    file write _rf "co <- coef(fit)" _n
    file write _rf "write.csv(data.frame(beta_bili=unname(co[1]),beta_protime=unname(co[2])),args[4],row.names=FALSE)" _n
    file close _rf

    shell Rscript "`script'" "`basecsv'" "`seqcsv'" "`refcsv'" "`coefcsv'" > "`rlog'" 2>&1
    local setup_rc = 0
    foreach f in "`basecsv'" "`seqcsv'" "`refcsv'" "`coefcsv'" {
        capture confirm file "`f'"
        if _rc local setup_rc = _rc
    }

    if `setup_rc' == 0 {
        **# Build the tvtools analysis data independently
        capture noisily {
            import delimited using "`basecsv'", clear varnames(1)
            assert _N == 312
            generate double origin = mdy(1, 1, 1960)
            generate double entry = origin
            generate double exit = origin + time - 1
            format origin entry exit %td
            tempfile cohort base seq bili_ep protime_ep bili_tv protime_tv merged got
            save `cohort'
            keep id time status origin
            save `base'

            import delimited using "`seqcsv'", clear varnames(1)
            merge m:1 id using `base', assert(match) nogenerate
            save `seq'

            keep id day bili time origin
            drop if missing(bili) | day >= time
            generate int bili_state = round(10*bili)
            sort id day
            by id (day): generate double stop = origin + day[_n + 1] - 1
            by id: replace stop = origin + time - 1 if missing(stop) | stop > origin + time - 1
            generate double start = origin + day
            drop if start > stop
            keep id start stop bili_state
            format start stop %td
            save `bili_ep'

            use `seq', clear
            keep id day protime time origin
            drop if missing(protime) | day >= time
            generate int protime_state = round(10*protime)
            sort id day
            by id (day): generate double stop = origin + day[_n + 1] - 1
            by id: replace stop = origin + time - 1 if missing(stop) | stop > origin + time - 1
            generate double start = origin + day
            drop if start > stop
            keep id start stop protime_state
            format start stop %td
            save `protime_ep'

            use `cohort', clear
            tvexpose using `bili_ep', id(id) start(start) stop(stop) ///
                exposure(bili_state) reference(0) entry(entry) exit(exit) ///
                generate(bili10)
            keep id start stop bili10
            save `bili_tv'

            use `cohort', clear
            tvexpose using `protime_ep', id(id) start(start) stop(stop) ///
                exposure(protime_state) reference(0) entry(entry) exit(exit) ///
                generate(protime10)
            keep id start stop protime10
            save `protime_tv'

            tvmerge `bili_tv' `protime_tv', id(id) ///
                start(start start) stop(stop stop) exposure(bili10 protime10)
            save `merged'

            use `cohort', clear
            keep if status == 2
            generate double death_date = origin + time - 1
            keep id death_date
            tvevent using `merged', id(id) date(death_date) ///
                generate(death) type(single) replace
            generate double start0 = start - mdy(1, 1, 1960)
            generate double stop0 = stop - mdy(1, 1, 1960)
            keep id start0 stop0 bili10 protime10 death
            rename (start0 stop0) (start stop)
            sort id start stop
            isid id start stop
            save `got'
        }
        local build_rc = _rc

        **## Canonical interval and value parity
        local ++test_count
        if `build_rc' == 0 {
            capture noisily {
                import delimited using "`refcsv'", clear varnames(1)
                replace stop = stop - 1
                rename (bili10 protime10 death) ///
                    (bili10_r protime10_r death_r)
                sort id start stop
                isid id start stop
                merge 1:1 id start stop using `got', assert(match) nogenerate
                assert bili10 == bili10_r
                assert protime10 == protime10_r
                assert death == death_r
            }
        }
        else capture noisily error `build_rc'
        if _rc == 0 {
            display as result "  PASS [P1]: tvtools rows match survival::tmerge exactly"
            local ++pass_count
        }
        else {
            display as error "  FAIL [P1]: tmerge row parity (rc `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' P1"
        }

        **## Cox coefficient parity on the constructed data
        local ++test_count
        capture noisily {
            use `got', clear
            generate double t0 = start
            generate double t = stop + 1
            generate double logbili = log(bili10/10)
            generate double logprotime = log(protime10/10)
            stset t, id(id) enter(time t0) failure(death)
            quietly stcox logbili logprotime, efron nohr
            local stata_bili = _b[logbili]
            local stata_protime = _b[logprotime]

            import delimited using "`coefcsv'", clear varnames(1)
            local r_bili = beta_bili[1]
            local r_protime = beta_protime[1]
            display as text "  log(bili): Stata=" %10.7f `stata_bili' " R=" %10.7f `r_bili'
            display as text "  log(protime): Stata=" %10.7f `stata_protime' " R=" %10.7f `r_protime'
            assert abs(`stata_bili' - `r_bili') < 1e-5
            assert abs(`stata_protime' - `r_protime') < 1e-5
        }
        if _rc == 0 {
            display as result "  PASS [P2]: Cox coefficients match R on the public workflow"
            local ++pass_count
        }
        else {
            display as error "  FAIL [P2]: Cox coefficient parity (rc `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' P2"
        }

        **## Published vignette coefficient pair
        local ++test_count
        capture noisily {
            assert !missing(`stata_bili', `stata_protime')
            assert abs(`stata_bili' - 1.241214) < 1e-5
            assert abs(`stata_protime' - 3.983400) < 1e-5
        }
        if _rc == 0 {
            display as result "  PASS [P3]: tvtools-built data reproduce the published PBC example"
            local ++pass_count
        }
        else {
            display as error "  FAIL [P3]: published PBC coefficients (rc `=_rc')"
            local ++fail_count
            local failed_tests "`failed_tests' P3"
        }
    }
    else {
        display as error "  FAIL: R did not produce the Mayo PBC references; see `rlog'"
        local fail_count = 3
        local failed_tests "P1 P2 P3"
    }

    capture erase "`basecsv'"
    capture erase "`seqcsv'"
    capture erase "`refcsv'"
    capture erase "`coefcsv'"
    capture erase "`script'"
    capture erase "`rlog'"
}
else {
    display as text "  SKIP: Rscript is required for survival::pbc parity"
    local skip_count = 3
}

**# Summary
local test_count = `pass_count' + `fail_count' + `skip_count'
display as result "Mayo PBC cross-validation: `pass_count'/`test_count' passed"
display "RESULT: crossval_public_pbc tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
    exit 1
}

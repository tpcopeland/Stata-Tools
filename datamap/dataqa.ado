*! dataqa Version 1.8.1  2026/09/30
*! Session defaults and a structured QA ledger over datacheck gate calls
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Subcommands:
//   dataqa set [options | clear]            session defaults in global DATAMAP_DQ
//   dataqa report [using ledger] [, run() markdown() replace]
//   dataqa assert [using ledger] [, run() expect()]
//   dataqa export [using ledger], run() saving() [replace threshold()]
//   dataqa compare [using ledger], run() baseline() [baseledger() ntol() stattol()]
//
// The ledger is the dataset datacheck ledger() appends to: one row per gate
// entry, passed or failed, and one per review item.  Every subcommand works
// in a temporary frame; the data in memory are never touched.
program define dataqa, rclass
    version 16.0
    local _orig_matastrict = c(matastrict)
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken sub 0 : 0, parse(" ,")
        local sub = lower(strtrim(`"`sub'"'))
        if !inlist(`"`sub'"', "set", "report", "assert", "export", "compare") {
            if `"`sub'"' == "" display as error "dataqa requires a subcommand: set, report, assert, export, or compare"
            else display as error `"dataqa: unknown subcommand `sub'; use set, report, assert, export, or compare"'
            exit 198
        }
        _dataqa_`sub' `macval(0)'
    }
    local rc = _rc
    capture mata: mata set matastrict `_orig_matastrict'
    return add
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// ---------------------------------------------------------------------------
// Subcommands (private to this file)
// ---------------------------------------------------------------------------

capture program drop _dataqa_set
program define _dataqa_set, rclass
    version 16.0
    local rest = strtrim(`"`macval(0)'"')
    if substr(`"`rest'"', 1, 1) == "," local rest = strtrim(substr(`"`rest'"', 2, .))
    if lower(`"`rest'"') == "clear" {
        macro drop DATAMAP_DQ
        display as text "dataqa: session defaults cleared"
        return local defaults ""
        exit
    }
    if `"`rest'"' == "" {
        if `"$DATAMAP_DQ"' == "" display as text "dataqa: no session defaults are set"
        else display as text "dataqa session defaults: " as result `"$DATAMAP_DQ"'
        return local defaults `"$DATAMAP_DQ"'
        exit
    }
    local 0 `", `rest'"'
    syntax [, MASKrare MINcell(integer -1) LEDger(string) RUN(string) BANDWARN SIGnature REPLACE]
    if `mincell' < -1 {
        display as error "dataqa set: mincell() must be non-negative"
        exit 198
    }
    local ledger = subinstr(`"`ledger'"', char(34), "", .)
    local run = subinstr(`"`run'"', char(34), "", .)
    // datacheck's ledger(file, run()) form: here run() is its own option
    if regexm(`"`ledger'"', "^(.*[^ ])[ ]*,[ ]*run\((.*)\)$") {
        local _lf = regexs(1)
        local _lr = regexs(2)
        display as error `"dataqa set: run() is its own option here; type dataqa set ledger("`_lf'") run(`_lr')"'
        exit 198
    }
    if `"`ledger'"' != "" {
        _datamap_validate_path `"`ledger'"', option(ledger())
        mata: st_local("_ext", pathsuffix(st_local("ledger")))
        if `"`_ext'"' == "" local ledger `"`ledger'.dta"'
    }
    local badrun = 0
    foreach c in ";" "&" "|" "<" ">" "$" "(" ")" {
        if strpos(`"`run'"', "`c'") local badrun = 1
    }
    if strpos(`"`run'"', char(96)) | strpos(`"`run'"', char(34)) | ///
        strpos(`"`run'"', char(92)) local badrun = 1
    if `badrun' {
        display as error "dataqa set: run() must not contain parentheses, quotes, or shell characters"
        exit 198
    }
    if `"`run'"' != "" & `"`ledger'"' == "" {
        display as error "dataqa set: run() labels ledger rows; give ledger() as well"
        exit 198
    }
    if "`replace'" != "" & (`"`ledger'"' == "" | `"`run'"' == "") {
        display as error "dataqa set: replace removes the rows of run() from ledger(); give both"
        exit 198
    }
    // Rows the ledger already holds under run().  replace is a one-shot
    // action here, not a stored default: it removes them before any gate
    // call of this session appends.  Without replace they are kept and read
    // with this session's rows, and a note says so.
    local n_prior = 0
    local n_removed = 0
    if `"`ledger'"' != "" & `"`run'"' != "" {
        capture confirm file `"`ledger'"'
        if !_rc {
            tempname sf
            frame create `sf'
            capture noisily {
                frame `sf' {
                    if "`replace'" == "" {
                        // a file that is not a ledger is refused by datacheck
                        capture quietly use run using `"`ledger'"', clear
                        if !_rc {
                            capture confirm string variable run
                            if !_rc {
                                quietly count if run == `"`run'"'
                                local n_prior = r(N)
                            }
                        }
                    }
                    else {
                        quietly use `"`ledger'"', clear
                        foreach v in run seq dataset family label status kind observed observed_num {
                            capture confirm variable `v'
                            if _rc {
                                display as error `"dataqa set: `ledger' is not a datacheck ledger (no variable `v'); replace left it untouched"'
                                exit 610
                            }
                        }
                        quietly count if run == `"`run'"'
                        local n_removed = r(N)
                        if `n_removed' > 0 {
                            quietly drop if run == `"`run'"'
                            quietly save `"`ledger'"', replace
                        }
                    }
                }
            }
            local rc = _rc
            capture frame drop `sf'
            if `rc' exit `rc'
        }
    }
    local spec ""
    if "`maskrare'" != "" local spec "maskrare"
    if `mincell' >= 0 local spec "`spec' mincell(`mincell')"
    if `"`ledger'"' != "" local spec `"`spec' ledger("`ledger'")"'
    if `"`run'"' != "" local spec `"`spec' run(`run')"'
    if "`bandwarn'" != "" local spec "`spec' bandwarn"
    if "`signature'" != "" local spec "`spec' signature"
    local spec = strtrim(`"`spec'"')
    global DATAMAP_DQ `"`spec'"'
    display as text "dataqa session defaults: " as result `"`spec'"'
    if "`replace'" != "" {
        display as text "dataqa set: " as result "`n_removed'" as text " row(s) of run " ///
            as result `"`run'"' as text " removed from " as result `"`ledger'"'
        return scalar n_removed = `n_removed'
    }
    else if `n_prior' > 0 {
        display as text "note: ledger already holds " as result "`n_prior'" as text ///
            " row(s) of run " as result `"`run'"' as text "; they are read with this" ///
            " session's rows; add replace to start the run afresh"
    }
    return local defaults `"`spec'"'
end

// Load the ledger into frame fr, restricted to run (all rows when run is
// empty).  Returns r(file), r(run), r(N).
capture program drop _dataqa_load
program define _dataqa_load, rclass
    version 16.0
    syntax name(name=fr) [, FILE(string) RUN(string) NEEDRUN WHO(string)]
    if `"`file'"' == "" | `"`run'"' == "" {
        _datamap_dqdefaults
        if `"`file'"' == "" local file `"`r(ledger)'"'
        if `"`run'"' == "" local run `"`r(run)'"'
    }
    if `"`file'"' == "" {
        display as error "dataqa `who': no ledger; give using filename or set one with dataqa set ledger()"
        exit 198
    }
    if "`needrun'" != "" & `"`run'"' == "" {
        display as error "dataqa `who': run() is required"
        exit 198
    }
    _datamap_validate_path `"`file'"', option(using)
    capture confirm file `"`file'"'
    if _rc {
        capture confirm file `"`file'.dta"'
        if _rc {
            display as error `"dataqa `who': ledger `file' not found"'
            exit 601
        }
        local file `"`file'.dta"'
    }
    frame `fr' {
        quietly use `"`file'"', clear
        foreach v in run seq dataset family label status kind observed observed_num {
            capture confirm variable `v'
            if _rc {
                display as error `"dataqa `who': `file' is not a datacheck ledger (no variable `v')"'
                exit 610
            }
        }
        if `"`run'"' != "" quietly keep if run == `"`run'"'
        local N = _N
    }
    return local file `"`file'"'
    return local run `"`run'"'
    return scalar N = `N'
end

// Reduce the ledger rows in memory to the latest call of each gate within
// its run.  The keys are defined here only, for report, assert, export and
// compare alike.  A gate is dataset without (modified), family, label,
// variable, scope, expectation, and the variables of a datacheck by() call.
// The expectation is part of it, so a rerun with changed bounds is a new
// gate and cannot hide the old failure (that would widen an invariant in
// code).  The level part of grp is not: events() and a groupstat() band
// write one failed row per level or group ("lv = 2", "by(g) = 2"), a passing
// rerun writes one row without it, and each must supersede the other.
// Every row of the gate's latest call is kept.  A row with no dataset name
// is never superseded: an unnamed call cannot be told apart from another
// unnamed dataset.  grp is the group's number within its call, so a group
// can map to another level if the data change between calls.  With one,
// each _key (the gate plus the whole grp) then keeps a single row, so
// compare links the runs 1:1 group by group, and _key is left in place.
// Row order is kept.  Returns r(n_superseded).
capture program drop _dataqa_latest
program define _dataqa_latest, rclass
    version 16.0
    syntax [, ONE]
    foreach v in variable grp scope expected {
        capture confirm variable `v'
        if _rc {
            display as error "dataqa: the ledger has no variable `v'; it predates the gate key"
            exit 610
        }
    }
    tempvar ord mx gate
    quietly generate long `ord' = _n
    // the by() variables of a datacheck by() call, "by(foreign group 1)"
    // -> "by(foreign)"; a helper's own level ("lv = 2", "by(g) = 2") drops
    quietly generate strL `gate' = ""
    quietly replace `gate' = "by(" + regexs(1) + ")" if regexm(grp, "^by\(([^()]*) group [0-9]+\)")
    quietly replace `gate' = regexr(dataset, " \(modified\)$", "") + char(9) + ///
        family + char(9) + label + char(9) + variable + char(9) + scope + ///
        char(9) + expected + char(9) + `gate'
    local N0 = _N
    // a run with no rows: by would run nothing and create no variable
    if `N0' == 0 {
        if "`one'" != "" quietly generate strL _key = ""
        return scalar n_superseded = 0
        exit
    }
    quietly bysort run `gate' (seq): generate double `mx' = seq[_N]
    quietly drop if seq < `mx' & regexr(dataset, " \(modified\)$", "") != ""
    local nsup = `N0' - _N
    if "`one'" != "" {
        quietly generate strL _key = `gate' + char(9) + grp
        quietly bysort run _key (seq `ord'): keep if _n == _N
    }
    sort `ord'
    return scalar n_superseded = `nsup'
end

// Resolve a file name for comparison: relative to c(pwd), "." segments
// removed and "dir/.." folded.  On Windows "\" is a separator (elsewhere
// it is a character of the name).  On Windows and macOS, whose file systems
// ignore case by default, the result is lower-cased.  It does not see
// through a symbolic link or a mapped drive.  Returns r(path).
capture program drop _dataqa_canon
program define _dataqa_canon, rclass
    version 16.0
    gettoken p : 0
    local win = (c(os) == "Windows")
    local pwd `"`c(pwd)'"'
    if `win' {
        local p = subinstr(`"`p'"', char(92), "/", .)
        local pwd = subinstr(`"`pwd'"', char(92), "/", .)
    }
    else if `"`p'"' == "~" | substr(`"`p'"', 1, 2) == "~/" {
        local home : env HOME
        local p = `"`home'"' + substr(`"`p'"', 2, .)
    }
    local isabs = (substr(`"`p'"', 1, 1) == "/") | regexm(`"`p'"', "^[A-Za-z]:/")
    if !`isabs' local p `"`pwd'/`p'"'
    local pre ""
    if regexm(`"`p'"', "^[A-Za-z]:/") {
        local pre = substr(`"`p'"', 1, 3)
        local p = substr(`"`p'"', 4, .)
    }
    else if `win' & substr(`"`p'"', 1, 2) == "//" {
        local pre "//"
        local p = substr(`"`p'"', 3, .)
    }
    else if substr(`"`p'"', 1, 1) == "/" {
        // on Windows a leading / is the root of the current drive
        local pre "/"
        if `win' & regexm(`"`pwd'"', "^[A-Za-z]:") local pre = substr(`"`pwd'"', 1, 2) + "/"
        local p = substr(`"`p'"', 2, .)
    }
    local n = 0
    while `"`p'"' != "" {
        local k = strpos(`"`p'"', "/")
        if `k' == 0 {
            local seg `"`p'"'
            local p ""
        }
        else {
            local seg = substr(`"`p'"', 1, `k' - 1)
            local p = substr(`"`p'"', `k' + 1, .)
        }
        if `"`seg'"' == "" | `"`seg'"' == "." continue
        if `"`seg'"' == ".." {
            if `n' > 0 local --n
            continue
        }
        local ++n
        local s`n' `"`seg'"'
    }
    local out `"`pre'"'
    forvalues i = 1/`n' {
        if `i' > 1 local out `"`out'/"'
        local out `"`out'`s`i''"'
    }
    if `win' | c(os) == "MacOSX" local out = ustrlower(`"`out'"')
    return local path `"`out'"'
end

// Allowed dispositions per kind: the register may never widen an invariant.
capture program drop _dataqa_allowed
program define _dataqa_allowed, rclass
    version 16.0
    args kind
    if "`kind'" == "invariant" return local s "code fixed; accepted: <reason> (PI consulted)"
    else if "`kind'" == "band" return local s "code fixed; accepted: <reason>; expectation revised pre hoc; expectation revised post hoc"
    else return local s "accepted: <reason>; code fixed"
end

capture program drop _dataqa_report
program define _dataqa_report, rclass
    version 16.0
    local _lf_made = 0
    local _fh_open = 0
    tempname lf fh
    capture noisily {
        syntax [using/] [, RUN(string) MARKdown(string) REPLACE]
        frame create `lf'
        local _lf_made = 1
        _dataqa_load `lf', file(`"`using'"') run(`"`run'"') who(report)
        local file `"`r(file)'"'
        local run `"`r(run)'"'
        frame `lf': _dataqa_latest
        local nsup = r(n_superseded)
        frame `lf': local N = _N
        local runtxt = cond(`"`run'"' == "", "all runs", `"run `run'"')
        display ""
        display as text "dataqa report: " as result `"`file'"' as text ", `runtxt'"
        if `N' == 0 {
            display as text "  no ledger rows"
        }
        if `nsup' > 0 display as text "  `nsup' row(s) superseded by a later call of the same gate"
        frame `lf' {
            quietly generate strL _ds = dataset
            quietly replace _ds = "(unnamed)" if _ds == ""
            quietly levelsof _ds, local(dslist)
            display as text "  " %-32s "Dataset" %7s "Calls" %7s "Gates" %8s "Failed" ///
                %8s "Warned" %8s "Review"
            local tot_f = 0
            local tot_w = 0
            foreach ds of local dslist {
                quietly count if _ds == `"`ds'"' & kind != "review"
                local ng = r(N)
                quietly count if _ds == `"`ds'"' & status == "fail"
                local nf = r(N)
                quietly count if _ds == `"`ds'"' & status == "warn"
                local nw = r(N)
                quietly count if _ds == `"`ds'"' & status == "review"
                local nr = r(N)
                tempvar tg
                quietly egen byte `tg' = tag(run seq) if _ds == `"`ds'"'
                quietly count if `tg' == 1
                local nc = r(N)
                quietly drop `tg'
                local tot_f = `tot_f' + `nf'
                local tot_w = `tot_w' + `nw'
                local dshow = substr(`"`ds'"', 1, 31)
                display as text "  " as result %-32s `"`dshow'"' %7.0f `nc' %7.0f `ng' ///
                    %8.0f `nf' %8.0f `nw' %8.0f `nr'
            }
            local nds : word count `dslist'
        }

        if `"`markdown'"' != "" {
            local mfile = subinstr(`"`markdown'"', char(34), "", .)
            _datamap_validate_path `"`mfile'"', option(markdown())
            capture confirm file `"`mfile'"'
            if !_rc & "`replace'" == "" {
                display as error `"dataqa report: `mfile' exists; specify replace"'
                exit 602
            }
            quietly file open `fh' using `"`mfile'"', write text replace
            local _fh_open = 1
            file write `fh' "| Run | Dataset | Check | Observed | Expectation and source | Disposition | Date | PI consulted |" _n
            file write `fh' "|---|---|---|---|---|---|---|---|" _n
            local nrows = 0
            frame `lf' {
                foreach ds of local dslist {
                    quietly count if _ds == `"`ds'"' & inlist(status, "fail", "warn", "review")
                    local nopen = r(N)
                    quietly count if _ds == `"`ds'"' & inlist(status, "fail", "warn")
                    local nbad = r(N)
                    // the runs this dataset's rows come from
                    quietly levelsof run if _ds == `"`ds'"', local(rl)
                    local rr ""
                    foreach r of local rl {
                        if `"`rr'"' == "" local rr `"`r'"'
                        else local rr `"`rr', `r'"'
                    }
                    // clean-run row: every gate of the dataset passed
                    if `nbad' == 0 {
                        local fams ""
                        quietly levelsof family if _ds == `"`ds'"' & kind != "review", local(fl) clean
                        local fams "`fl'"
                        quietly count if _ds == `"`ds'"' & kind != "review"
                        local ng = r(N)
                        if `ng' > 0 {
                            quietly summarize seq if _ds == `"`ds'"', meanonly
                            quietly levelsof stamp if _ds == `"`ds'"', local(st) clean
                            local dt = substr(word(`"`st'"', 1), 1, 10)
                            local cell_ds = subinstr(`"`ds'"', "|", "\|", .)
                            local cell_rr = subinstr(`"`rr'"', "|", "\|", .)
                            file write `fh' `"| `cell_rr' | `cell_ds' | all gates passed: `fams' | 0 violations in `ng' gate entries | as declared | clean | `dt' |  |"' _n
                            local ++nrows
                        }
                    }
                    forvalues j = 1/`=_N' {
                        if _ds[`j'] != `"`ds'"' continue
                        if !inlist(status[`j'], "fail", "warn", "review") continue
                        local fam = family[`j']
                        local lab = label[`j']
                        local obs = observed[`j']
                        local exp = expected[`j']
                        local grp = grp[`j']
                        local knd = kind[`j']
                        local sts = status[`j']
                        local rr = run[`j']
                        local dt = substr(stamp[`j'], 1, 10)
                        local check `"`fam'(`lab'): `obs' against `exp'"'
                        if `"`grp'"' != "" local check `"`check' [`grp']"'
                        _dataqa_allowed `knd'
                        local allow `"`r(s)'"'
                        if "`knd'" == "review" local disp `"open (review item; allowed: `allow')"'
                        else {
                            local stv = cond("`sts'" == "fail", "failed", "warned")
                            local disp `"open (`knd' `stv'; allowed: `allow')"'
                        }
                        local pic = cond("`knd'" == "invariant", "required if accepted", "")
                        foreach c in check obs exp disp ds rr {
                            local cell_`c' = subinstr(`"``c''"', "|", "\|", .)
                            local cell_`c' = subinstr(`"`cell_`c''"', char(10), " ", .)
                        }
                        file write `fh' `"| `cell_rr' | `cell_ds' | `cell_check' | `cell_obs' | `cell_exp'; source: | `cell_disp' | `dt' | `pic' |"' _n
                        local ++nrows
                    }
                }
            }
            file close `fh'
            local _fh_open = 0
            display as text "  register draft: " as result "`nrows'" as text " row(s) written to " ///
                as result `"`mfile'"'
            return local markdown `"`mfile'"'
            return scalar n_rows = `nrows'
        }
        return local ledger `"`file'"'
        return local run `"`run'"'
        return scalar N = `N'
        return scalar n_superseded = `nsup'
        return scalar n_datasets = `nds'
        return scalar n_failed = `tot_f'
        return scalar n_warned = `tot_w'
    }
    local rc = _rc
    if `_fh_open' capture file close `fh'
    if `_lf_made' capture frame drop `lf'
    if `rc' exit `rc'
end

capture program drop _dataqa_assert
program define _dataqa_assert, rclass
    version 16.0
    local _lf_made = 0
    local _halt = 0
    tempname lf
    capture noisily {
        syntax [using/] [, RUN(string) EXPect(string)]
        frame create `lf'
        local _lf_made = 1
        _dataqa_load `lf', file(`"`using'"') run(`"`run'"') needrun who(assert)
        local file `"`r(file)'"'
        local run `"`r(run)'"'
        frame `lf': _dataqa_latest
        local nsup = r(n_superseded)
        frame `lf': local N = _N
        display ""
        display as text "dataqa assert: " as result `"`file'"' as text ", run " as result `"`run'"'
        if `nsup' > 0 display as text "  `nsup' row(s) superseded by a later call of the same gate"
        local nbad = 0
        local missing ""
        if `N' == 0 {
            display as error "  no ledger rows for run `run'"
            local _halt = 1
        }
        frame `lf' {
            // a halting row: any failed row, or an invariant that failed
            // under bare warn
            quietly generate byte _bad = status == "fail" | (kind == "invariant" & status == "warn")
            quietly count if _bad
            local nbad = r(N)
            if `nbad' > 0 {
                display as error "  `nbad' invariant or halting row(s) failed:"
                forvalues j = 1/`=_N' {
                    if !_bad[`j'] continue
                    local m = message[`j']
                    local d = dataset[`j']
                    display as error `"    `d': `macval(m)'"'
                }
                local _halt = 1
            }
            foreach e of local expect {
                quietly count if dataset == `"`e'"' | strpos(dataset, `"`e' ("') == 1 | ///
                    strpos(dataset, `"`e',"') == 1
                if r(N) == 0 local missing "`missing' `e'"
            }
        }
        local missing = strtrim("`missing'")
        if "`missing'" != "" {
            display as error "  no ledger rows in run `run' for: `missing' (a gate call did not run or was deleted)"
            local _halt = 1
        }
        if !`_halt' {
            display as text "  " as result "`N'" as text " row(s); every invariant passed" ///
                cond("`expect'" != "", "; every expected dataset has rows", "")
        }
        return scalar N = `N'
        return scalar n_superseded = `nsup'
        return scalar n_failed = `nbad'
        return local missing "`missing'"
        return local run `"`run'"'
    }
    local rc = _rc
    if `_lf_made' capture frame drop `lf'
    if `rc' exit `rc'
    if `_halt' exit 9
end

capture program drop _dataqa_export
program define _dataqa_export, rclass
    version 16.0
    local _lf_made = 0
    tempname lf
    capture noisily {
        syntax [using/] , SAVing(string) [RUN(string) REPLACE THReshold(integer 5)]
        if `threshold' < 1 {
            display as error "dataqa export: threshold() must be positive"
            exit 198
        }
        local sfile = subinstr(`"`saving'"', char(34), "", .)
        _datamap_validate_path `"`sfile'"', option(saving())
        mata: st_local("_ext", pathsuffix(st_local("sfile")))
        if `"`_ext'"' == "" local sfile `"`sfile'.dta"'
        frame create `lf'
        local _lf_made = 1
        _dataqa_load `lf', file(`"`using'"') run(`"`run'"') needrun who(export)
        local file `"`r(file)'"'
        local run `"`r(run)'"'
        // the release copy may never be written over the ledger it is read
        // from: that would drop every other run and blank scope expressions
        _dataqa_canon `"`file'"'
        local cfile `"`r(path)'"'
        _dataqa_canon `"`sfile'"'
        if `"`r(path)'"' == `"`cfile'"' {
            display as error "dataqa export: saving() names the ledger being exported; the release copy needs its own file"
            exit 602
        }
        frame `lf': _dataqa_latest
        local nsup = r(n_superseded)
        frame `lf': local N = _N
        if `N' == 0 {
            display as error "dataqa export: no ledger rows for run `run'"
            exit 2000
        }
        frame `lf' {
            foreach v in masked mincell minshown obs_masked scope {
                capture confirm variable `v'
                if _rc {
                    display as error `"dataqa export: `file' lacks column `v'; it predates the masking record"'
                    exit 459
                }
            }
            quietly count if masked != 1
            local n_unmasked = r(N)
            quietly count if masked == 1 & mincell < `threshold'
            local n_lowmask = r(N)
            quietly count if minshown >= 1 & minshown < `threshold'
            local n_small = r(N)
            quietly count if obs_masked == 1 & !missing(observed_num)
            local n_leak = r(N)
            local refuse = (`n_unmasked' | `n_lowmask' | `n_small' | `n_leak')
            if `refuse' {
                display as error "dataqa export: refused; the release copy must not carry a small cell"
                if `n_unmasked' display as error "  `n_unmasked' row(s) come from calls not run under maskrare with a mask of at least 5"
                if `n_lowmask' display as error "  `n_lowmask' row(s) were masked below the house threshold of `threshold'"
                if `n_small' display as error "  `n_small' row(s) print a count below `threshold'"
                if `n_leak' display as error "  `n_leak' row(s) hold observed_num for a masked observation"
                exit 459
            }
            // A scope written with a literal value (an id, a quoted string)
            // stays on the server.
            quietly generate byte _lit = regexm(scope, "[0-9][0-9][0-9][0-9]") | strpos(scope, char(34)) > 0
            quietly count if _lit
            local n_scope_dropped = r(N)
            quietly replace scope = "" if _lit
            quietly drop _lit
            capture confirm file `"`sfile'"'
            if !_rc & "`replace'" == "" {
                display as error `"dataqa export: `sfile' exists; specify replace"'
                exit 602
            }
            quietly save `"`sfile'"', replace
        }
        display as text "dataqa export: " as result "`N'" as text " row(s) of run " as result `"`run'"' ///
            as text " written to " as result `"`sfile'"'
        if `n_scope_dropped' display as text "  `n_scope_dropped' scope expression(s) with literal values blanked"
        return scalar N = `N'
        return scalar n_superseded = `nsup'
        return scalar n_scope_dropped = `n_scope_dropped'
        return local saving `"`sfile'"'
    }
    local rc = _rc
    if `_lf_made' capture frame drop `lf'
    if `rc' exit `rc'
end

capture program drop _dataqa_compare
program define _dataqa_compare, rclass
    version 16.0
    local _lf_made = 0
    local _bf_made = 0
    tempname lf bf
    capture noisily {
        syntax [using/] [, RUN(string) BASEline(string) BASELEDger(string) ///
            NTOL(real 0.05) STATTOL(real 0.05)]
        if `ntol' < 0 | `stattol' < 0 {
            display as error "dataqa compare: ntol() and stattol() must be non-negative"
            exit 198
        }
        local baseline = strtrim(`"`baseline'"')
        local nflag = 0
        display ""
        if `"`baseline'"' == "" {
            display as text "dataqa compare: no baseline run given; nothing to compare (first run on this extract)"
        }
        else {
        frame create `lf'
        local _lf_made = 1
        _dataqa_load `lf', file(`"`using'"') run(`"`run'"') needrun who(compare)
        local file `"`r(file)'"'
        local run `"`r(run)'"'
        local bfile `"`file'"'
        if `"`baseledger'"' != "" local bfile = subinstr(`"`baseledger'"', char(34), "", .)
        frame create `bf'
        local _bf_made = 1
        _dataqa_load `bf', file(`"`bfile'"') run(`"`baseline'"') who(compare)
        local NB = r(N)
        display as text "dataqa compare: run " as result `"`run'"' as text " against baseline " ///
            as result `"`baseline'"'
        if `NB' == 0 {
            display as text "  baseline run `baseline' has no rows; nothing to compare"
        }
        else {
        // one row per gate key (_dataqa_latest); (modified) is not part of
        // the name
        foreach f in `lf' `bf' {
            frame `f' {
                _dataqa_latest, one
                quietly replace dataset = regexr(dataset, " \(modified\)$", "")
            }
        }
        tempvar lk
        frame `lf' {
            quietly frlink 1:1 _key, frame(`bf') generate(`lk')
            quietly frget _bn = n_scope _bo = observed_num _bom = obs_masked ///
                _bsig = signature, from(`lk')
            // N changes beyond ntol().  A missing n_scope was withheld under
            // the mask; withheld on one side only is a change to review, and
            // is shown without the number.  A zero baseline is compared
            // absolutely, as stat() is.
            forvalues j = 1/`=_N' {
                if missing(`lk'[`j']) continue
                local a = n_scope[`j']
                local b = _bn[`j']
                if missing(`a') & missing(`b') continue
                local ds = dataset[`j']
                local fl = family[`j'] + "(" + label[`j'] + ")"
                if missing(`a') | missing(`b') {
                    local bs = cond(missing(`b'), "withheld", "`b'")
                    local as = cond(missing(`a'), "withheld", "`a'")
                    display as text "  N  " as result `"`ds'"' as text " `fl': " ///
                        as result "`bs'" as text " -> " as result "`as'" ///
                        as text " (withheld under the mask in one run)"
                    local ++nflag
                    continue
                }
                if `b' == 0 {
                    if `a' != 0 {
                        display as text "  N  " as result `"`ds'"' as text " `fl': " ///
                            as result "0" as text " -> " as result "`a'" as text " (baseline 0)"
                        local ++nflag
                    }
                    continue
                }
                local rel = (`a' - `b') / `b'
                if abs(`rel') > `ntol' {
                    local pc = strtrim(string(100 * `rel', "%9.1f"))
                    display as text "  N  " as result `"`ds'"' as text " `fl': " ///
                        as result "`b'" as text " -> " as result "`a'" as text " (`pc'%)"
                    local ++nflag
                }
            }
            // stat() values beyond stattol()
            forvalues j = 1/`=_N' {
                if family[`j'] != "stat" | missing(`lk'[`j']) continue
                if missing(observed_num[`j']) & missing(_bo[`j']) continue
                // a value on one side only: masked or undefined in the other
                if missing(observed_num[`j']) | missing(_bo[`j']) {
                    local ds = dataset[`j']
                    local fl = "stat(" + label[`j'] + ")"
                    local bs = cond(_bom[`j'] == 1, "masked", "undefined")
                    if !missing(_bo[`j']) local bs = strtrim(string(_bo[`j'], "%10.4g"))
                    local as = cond(obs_masked[`j'] == 1, "masked", "undefined")
                    if !missing(observed_num[`j']) local as = strtrim(string(observed_num[`j'], "%10.4g"))
                    display as text "  stat  " as result `"`ds'"' as text " `fl': " ///
                        as result "`bs'" as text " -> " as result "`as'"
                    local ++nflag
                    continue
                }
                local a = observed_num[`j']
                local b = _bo[`j']
                local rel = cond(`b' != 0, (`a' - `b') / abs(`b'), `a' - `b')
                if abs(`rel') > `stattol' {
                    local ds = dataset[`j']
                    local fl = "stat(" + label[`j'] + ")"
                    display as text "  stat  " as result `"`ds'"' as text " `fl': " ///
                        as result %10.4g `b' as text " -> " as result %10.4g `a'
                    local ++nflag
                }
            }
            // changed signatures, once per dataset
            quietly levelsof dataset if !missing(`lk') & signature != "" & _bsig != "" & ///
                signature != _bsig, local(sigds)
            foreach ds of local sigds {
                display as text "  signature  " as result `"`ds'"' as text ": the data changed since the baseline"
                local ++nflag
            }
            quietly drop _bn _bo _bom _bsig
        }
        // gates present in the baseline but absent now
        tempvar bl
        frame `bf' {
            quietly frlink 1:1 _key, frame(`lf') generate(`bl')
            forvalues j = 1/`=_N' {
                if !missing(`bl'[`j']) continue
                local ds = dataset[`j']
                local fl = family[`j'] + "(" + label[`j'] + ")"
                local g = grp[`j']
                if `"`g'"' != "" local fl `"`fl' [`g']"'
                local e = expected[`j']
                if `"`e'"' != "" local fl `"`fl', expected `e'"'
                display as text "  absent  " as result `"`ds'"' as text " `fl': in the baseline, not in this run"
                local ++nflag
            }
        }
        if `nflag' == 0 display as text "  no change beyond ntol(`ntol') and stattol(`stattol')"
        else display as text "  " as result "`nflag'" as text " item(s) to review (review severity; nothing halts)"
        }
        return local run `"`run'"'
        }
        return scalar n_flags = `nflag'
        return local baseline `"`baseline'"'
    }
    local rc = _rc
    if `_bf_made' capture frame drop `bf'
    if `_lf_made' capture frame drop `lf'
    if `rc' exit `rc'
end

*! dataqa Version 1.10.6  2026/10/21
*! Session defaults and a structured QA ledger over dataprobe gate calls
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Subcommands:
//   dataqa set [options | clear]            session defaults in global DATAMAP_DQ (collect: gate failures do not halt a call; baseline() baseledger(): the run compare and assert hold the current run against)
//   dataqa report [using ledger] [, run() markdown() replace bands]
//   dataqa assert [using ledger] [, run() expect() baseline() baseledger() optional()]
//   dataqa export [using ledger], run() saving() [replace threshold()]
//   dataqa compare [using ledger], run() baseline() [baseledger() ntol() stattol()]
//
// The ledger is the dataset dataprobe ledger() appends to: one row per gate
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
    local mrc = _rc
    if `mrc' {
        display as error "dataqa: could not restore matastrict `_orig_matastrict' (rc `mrc')"
        if !`rc' local rc = `mrc'
    }
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
    // the not-given sentinel is out of any typed range: with -1, a typed
    // mincell(-1) passed as "not given" and the call wiped the defaults
    syntax [, MASKrare MINcell(integer -999999999) LEDger(string) RUN(string) BANDWARN SIGnature COLLect REPLACE ///
        BASEline(string) BASELEDger(string)]
    if `mincell' < 0 & `mincell' != -999999999 {
        display as error "dataqa set: mincell() must be non-negative"
        exit 198
    }
    local ledger = subinstr(`"`ledger'"', char(34), "", .)
    local run = subinstr(`"`run'"', char(34), "", .)
    local baseline = strtrim(subinstr(`"`baseline'"', char(34), "", .))
    local baseledger = strtrim(subinstr(`"`baseledger'"', char(34), "", .))
    // dataprobe's ledger(file, run()) form: here run() is its own option
    if regexm(`"`ledger'"', "^(.*[^ ])[ ]*,[ ]*run\((.*)\)$") {
        local _lf = regexs(1)
        local _lr = regexs(2)
        display as error `"dataqa set: run() is its own option here; type dataqa set ledger("`_lf'") run(`_lr')"'
        exit 198
    }
    if `"`ledger'"' != "" {
        _datamap_validate_path `"`ledger'"', option(ledger())
        // the ledger path rule, the one Stata's save uses: .dta is added
        // to a basename without a suffix; any suffix is kept as given
        mata: st_local("_ext", pathsuffix(st_local("ledger")))
        if `"`_ext'"' == "" local ledger `"`ledger'.dta"'
    }
    if `"`baseledger'"' != "" {
        _datamap_validate_path `"`baseledger'"', option(baseledger())
        mata: st_local("_ext", pathsuffix(st_local("baseledger")))
        if `"`_ext'"' == "" local baseledger `"`baseledger'.dta"'
    }
    foreach o in run baseline {
        local badrun = 0
        foreach c in ";" "&" "|" "<" ">" "$" "(" ")" {
            if strpos(`"``o''"', "`c'") local badrun = 1
        }
        if strpos(`"``o''"', char(96)) | strpos(`"``o''"', char(34)) | ///
            strpos(`"``o''"', char(92)) local badrun = 1
        if `badrun' {
            display as error "dataqa set: `o'() must not contain parentheses, quotes, or shell characters"
            exit 198
        }
    }
    if `"`baseledger'"' != "" & `"`baseline'"' == "" {
        display as error "dataqa set: baseledger() names the file of the baseline run; give baseline() as well"
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
                        // a file that is not a ledger is refused by dataprobe
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
                                display as error `"dataqa set: `ledger' is not a dataprobe ledger (no variable `v'); replace left it untouched"'
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
    if `"`baseline'"' != "" local spec `"`spec' baseline(`baseline')"'
    if `"`baseledger'"' != "" local spec `"`spec' baseledger("`baseledger'")"'
    if "`bandwarn'" != "" local spec "`spec' bandwarn"
    if "`signature'" != "" local spec "`spec' signature"
    if "`collect'" != "" local spec "`spec' collect"
    local spec = strtrim(`"`spec'"')
    global DATAMAP_DQ `"`spec'"'
    display as text "dataqa session defaults: " as result `"`spec'"'
    if "`collect'" != "" {
        display as text "  collect: a dataprobe call whose gates fail records its rows and returns rc 0;" ///
            " dataqa assert is the halting point"
        if `"`ledger'"' == "" display as text "  note: collect needs a ledger; a call without ledger() still exits 9"
    }
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
    // the writers' path rule (dataprobe ledger(), dataqa set): .dta is
    // added to a basename without a suffix, any suffix is kept as given
    mata: st_local("_ext", pathsuffix(st_local("file")))
    if `"`_ext'"' == "" local file `"`file'.dta"'
    capture confirm file `"`file'"'
    if _rc {
        display as error `"dataqa `who': ledger `file' not found"'
        exit 601
    }
    frame `fr' {
        quietly use `"`file'"', clear
        foreach v in run seq dataset family label status kind observed observed_num {
            capture confirm variable `v'
            if _rc {
                display as error `"dataqa `who': `file' is not a dataprobe ledger (no variable `v')"'
                exit 610
            }
        }
        if `"`run'"' != "" quietly keep if run == `"`run'"'
        // the writers (dataprobe, _dataprobe_errrow) give every row one of
        // these statuses; any other value would read as neither pass nor
        // failure, and an edited or damaged ledger would pass assert
        capture confirm string variable status
        if _rc {
            display as error `"dataqa `who': `file' is not a dataprobe ledger (status is not a string variable)"'
            exit 610
        }
        quietly count if !inlist(status, "pass", "fail", "warn", "review", "error")
        if r(N) > 0 {
            display as error `"dataqa `who': `file' has `r(N)' row(s) with a status other than pass, fail, warn, review, or error; the ledger is damaged or was edited"'
            exit 610
        }
        local N = _N
    }
    return local file `"`file'"'
    return local run `"`run'"'
    return scalar N = `N'
end

// Reduce the ledger rows in memory to the latest call of each gate within
// its run.  The keys are defined here only, for report, assert, export and
// compare alike.  A gate is dataset without (modified), family, label,
// variable, scope, expectation, and the variables of a dataprobe by() call.
// The expectation is part of it, so a rerun with changed bounds is a new
// gate and cannot hide the old failure (that would widen an invariant in
// code).  The level part of grp is not: events() and a groupstat() band
// write one failed row per level or group ("lv = 2", "by(g) = 2"), a passing
// rerun writes one row without it, and each must supersede the other.
// Every row of the gate's latest call is kept.  A row with no dataset name
// is never superseded: an unnamed call cannot be told apart from another
// unnamed dataset.  grp names a dataprobe by() group by its VALUES,
// "by(site year | site=3 year=2015)", so the group is the same group when a
// level is added between runs; strings are written in brackets with every
// quote, macro, bracket and SMCL character as \xHH (see _dataprobe_gtext).
// A group withheld under maskrare, and every ledger written before 1.9.0,
// carries its number, "by(site year group 7)", which can name another level
// if the data change; compare detects a value/number mix (_dataqa_gforms).
// With one, each _key (the gate plus the whole grp) keeps a single row, so
// compare links the runs 1:1 group by group; _key and _gkey (the gate alone)
// are left in place.
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
    // the by() variables of a dataprobe by() call, "by(foreign group 1)" or
    // "by(foreign | foreign=1)" -> "by(foreign)"; a helper's own level ("lv = 2", "by(g) = 2") drops
    quietly generate strL `gate' = ""
    quietly replace `gate' = "by(" + regexs(1) + ")" if regexm(grp, "^by\(([^()]*) group [0-9]+\)")
    quietly replace `gate' = "by(" + ustrregexs(1) + ")" if ustrregexm(grp, "^by\(([^()|]*) \| ")
    // kind is part of the gate: a failed stat() invariant rerun as a
    // bands() band (a warning under bandwarn) is a downgrade, not a rerun
    tempvar knd
    capture confirm variable kind
    if _rc quietly generate str1 `knd' = ""
    else quietly generate strL `knd' = kind
    quietly replace `gate' = regexr(dataset, " \(modified\)$", "") + char(9) + ///
        family + char(9) + label + char(9) + variable + char(9) + scope + ///
        char(9) + expected + char(9) + `knd' + char(9) + `gate'
    local N0 = _N
    // a run with no rows: by would run nothing and create no variable
    if `N0' == 0 {
        if "`one'" != "" quietly generate strL _key = ""
        return scalar n_superseded = 0
        exit
    }
    quietly bysort run `gate' (seq): generate double `mx' = seq[_N]
    // The latest call supersedes an earlier row of its gate, as a fixed
    // file reloaded and rerun clears its failure (duplicates drop, save,
    // use).  The exception: a latest call on data changed in memory, a
    // "(modified)" dataset, never supersedes a row of the unmodified data,
    // so a rerun on a subset (keep if ..., N 74 -> 12) cannot clear a
    // full-data failure.  A call's if/in is its scope, part of the gate.
    tempvar lastc dmod lmod
    quietly generate byte `lastc' = (seq == `mx')
    quietly generate byte `dmod' = regexm(dataset, " \(modified\)$")
    quietly bysort run `gate': egen byte `lmod' = max(`lastc' & `dmod')
    // an error row (a call that failed to run) is never superseded
    quietly drop if seq < `mx' & regexr(dataset, " \(modified\)$", "") != "" & status != "error" & ///
        !(`lmod' == 1 & `dmod' == 0)
    local nsup = `N0' - _N
    if "`one'" != "" {
        quietly generate strL _key = `gate' + char(9) + grp
        quietly generate strL _gkey = `gate'
        // the by() part of grp alone, without a helper's level text
        quietly generate strL _gbase = ""
        quietly replace _gbase = ustrregexs(0) if ///
            ustrregexm(grp, "^by\([^()|]* \| ([^\[\])]|\[[^\[\]]*\])*\)")
        // one row per key.  When a "(modified)" call could not supersede
        // a row of the unmodified data (above), both stand, and report and
        // assert count a failure in either; compare reads the worst status
        // (error, fail, warn, review, pass), then the unmodified row, then
        // the latest call
        tempvar unmod srank mix
        quietly generate byte `unmod' = !`dmod'
        quietly bysort run _key: egen float `mix' = sd(`dmod')
        quietly generate byte `srank' = 0
        quietly replace `srank' = 5 * (status == "error") + 4 * (status == "fail") + ///
            3 * (status == "warn") + 2 * (status == "review") + (status == "pass") ///
            if `mix' > 0 & !missing(`mix')
        quietly bysort run _key (`srank' `unmod' seq `ord'): keep if _n == _N
    }
    sort `ord'
    return scalar n_superseded = `nsup'
end

// Which by() groups a ledger names by number and which by value, per set of
// by() variables, in the frame in memory.  Returns r(nonly), the by() variable
// lists with number groups and no value group, and r(vany), those with a value
// group, each as a compound-quoted list.  A call with groups withheld under
// maskrare writes both forms, so it is in vany only.
capture program drop _dataqa_gforms
program define _dataqa_gforms, rclass
    version 16.0
    tempvar bv
    quietly generate str2000 `bv' = ""
    quietly replace `bv' = regexs(1) if regexm(grp, "^by\(([^()]*) group [0-9]+\)")
    quietly levelsof `bv' if `bv' != "", local(nlev)
    quietly replace `bv' = ""
    quietly replace `bv' = ustrregexs(1) if ustrregexm(grp, "^by\(([^()|]*) \| ")
    quietly levelsof `bv' if `bv' != "", local(vany)
    local nonly : list nlev - vany
    return local nonly `"`nonly'"'
    return local vany `"`vany'"'
end

// Load the baseline run into frame bf: the baseline label from the
// baseline ledger (baseledger(), else the ledger file of the current run).
// Shared by compare and assert.  bf must exist.  Returns r(N), r(file).
capture program drop _dataqa_loadbase
program define _dataqa_loadbase, rclass
    version 16.0
    syntax name(name=bf) , FILE(string) BASEline(string) [BASELEDger(string) WHO(string)]
    local bfile `"`file'"'
    if `"`baseledger'"' != "" local bfile = subinstr(`"`baseledger'"', char(34), "", .)
    _dataqa_load `bf', file(`"`bfile'"') run(`"`baseline'"') who(`who')
    return scalar N = r(N)
    return local file `"`r(file)'"'
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
        syntax [using/] [, RUN(string) MARKdown(string) REPLACE BANDS]
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
            quietly count if status == "error"
            local n_callerr = r(N)
        }
        if `n_callerr' > 0 {
            display as error "  `n_callerr' call error row(s): a dataprobe call exited with an error and ran no gates (dataqa assert halts):"
            frame `lf' {
                forvalues j = 1/`=_N' {
                    if status[`j'] != "error" continue
                    // ledger text is shown as text: no SMCL, quote or macro
                    // character in a dataset or run name is live
                    mata: st_local("d", _dataqa_show(st_sdata(`j', "dataset")))
                    if `"`macval(d)'"' == "" local d "(unnamed)"
                    mata: st_local("rn", _dataqa_show(st_sdata(`j', "run")))
                    display as error `"    `macval(d)': rc `=observed_num[`j']', run `macval(rn)', call `=seq[`j']'"'
                }
            }
        }
        frame `lf' {
            quietly generate strL _ds = dataset
            quietly replace _ds = "(unnamed)" if _ds == ""
            quietly levelsof _ds, local(dslist)
            // every dataset's counts in one pass: _dsi numbers the datasets
            // in dslist's order (both sort _ds), _f1 marks the first row of
            // each call (run, seq) as egen tag() does (a missing run or seq
            // is not a call), and _dataqa_dscounts tallies them; row order
            // is kept for the rows the markdown table lists
            tempvar _o1 _dsi _f1
            tempname _dqc
            quietly generate long `_o1' = _n
            quietly egen long `_dsi' = group(_ds)
            quietly bysort `_dsi' run seq (`_o1'): generate byte `_f1' = ///
                (_n == 1) & !missing(run) & !missing(seq)
            quietly sort `_o1'
            mata: _dataqa_dscounts(st_local("_dsi"), st_local("_f1"), st_local("_dqc"))
            display as text "  " %-32s "Dataset" %7s "Calls" %7s "Gates" %8s "Failed" ///
                %8s "Warned" %8s "Review"
            local tot_f = 0
            local tot_w = 0
            local k = 0
            foreach ds of local dslist {
                local ++k
                local ng = `_dqc'[`k', 1]
                local nf = `_dqc'[`k', 2]
                local nw = `_dqc'[`k', 3]
                local nr = `_dqc'[`k', 4]
                local nc = `_dqc'[`k', 6]
                local nf = `nf' + `_dqc'[`k', 5]
                local tot_f = `tot_f' + `nf'
                local tot_w = `tot_w' + `nw'
                mata: st_local("dshow", _dataqa_show(usubstr(st_local("ds"), 1, 31) + ///
                    (32 - ustrlen(usubstr(st_local("ds"), 1, 31))) * " "))
                display as text "  " as result `"`macval(dshow)'"' %7.0f `nc' %7.0f `ng' ///
                    %8.0f `nf' %8.0f `nw' %8.0f `nr'
            }
            local nds : word count `dslist'
        }

        // bands: one row per band and per stat() invariant, passing or
        // failing, as the ledger stores it.  The range is the ledger's
        // expected column (the declared bounds, as written by the gate); the
        // observed value is the ledger's observed text, masked as stored.
        // observed_num is never read.  Nothing is inferred from the data.
        local nbands = 0
        if "`bands'" != "" {
            frame `lf' {
                quietly generate byte _bd = (kind == "band" | family == "stat") & kind != "review" & status != "review"
                quietly count if _bd
                local nbands = r(N)
            }
            display ""
            if `nbands' == 0 {
                display as text "  bands: no bands or stat() invariants in the selected run"
            }
            else {
                display as text "  bands: " as result "`nbands'" as text " band(s) and stat() invariant(s)"
                display as text "  " %-16s "Dataset" %-22s "Gate" %-7s "Status" %-18s "Declared range" "Observed"
                frame `lf' {
                    forvalues j = 1/`=_N' {
                        if !_bd[`j'] continue
                        // read and padded in Mata, shown as text
                        // (_dataqa_show): no SMCL, quote or macro
                        // character in the ledger is live
                        mata: _dataqa_bandcells(`j')
                        display as text "  " as result `"`macval(_c1)'"' as text `"`macval(_c2)'"' ///
                            as result %-7s status[`j'] as text `"`macval(_c3)'"' as result `"`macval(_c4)'"'
                    }
                }
            }
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
                local k = 0
                foreach ds of local dslist {
                    local ++k
                    local nbad = `_dqc'[`k', 2] + `_dqc'[`k', 3] + `_dqc'[`k', 5]
                    // the runs this dataset's rows come from
                    quietly levelsof run if _ds == `"`macval(ds)'"', local(rl)
                    local rr ""
                    foreach r of local rl {
                        if `"`macval(rr)'"' == "" local rr `"`macval(r)'"'
                        else local rr `"`macval(rr)', `macval(r)'"'
                    }
                    // clean-run row: every gate of the dataset passed
                    if `nbad' == 0 {
                        local fams ""
                        quietly levelsof family if _ds == `"`macval(ds)'"' & kind != "review", local(fl) clean
                        local fams "`fl'"
                        quietly count if _ds == `"`macval(ds)'"' & kind != "review"
                        local ng = r(N)
                        if `ng' > 0 {
                            quietly summarize seq if _ds == `"`macval(ds)'"', meanonly
                            quietly levelsof stamp if _ds == `"`macval(ds)'"', local(st) clean
                            local dt = substr(word(`"`st'"', 1), 1, 10)
                            mata: st_local("cell_ds", subinstr(st_local("ds"), "|", "\|"))
                            mata: st_local("cell_rr", subinstr(st_local("rr"), "|", "\|"))
                            file write `fh' `"| `macval(cell_rr)' | `macval(cell_ds)' | all gates passed: `fams' | 0 violations in `ng' gate entries | as declared | clean | `dt' |  |"' _n
                            local ++nrows
                        }
                    }
                    // the dataset's open rows, in row order
                    mata: st_local("_jl", _dataqa_openrows(st_local("_dsi"), `k'))
                    foreach j of local _jl {
                        // ledger text is data: read in Mata and joined
                        // with macval(), never re-read as macro syntax
                        foreach c in family label observed expected grp kind status run {
                            mata: st_local("_t_`c'", st_sdata(`j', "`c'"))
                        }
                        local fam : copy local _t_family
                        local lab : copy local _t_label
                        local obs : copy local _t_observed
                        local exp : copy local _t_expected
                        local grp : copy local _t_grp
                        local knd : copy local _t_kind
                        local sts : copy local _t_status
                        local rr : copy local _t_run
                        local dt = substr(stamp[`j'], 1, 10)
                        local check `"`macval(fam)'(`macval(lab)'): `macval(obs)' against `macval(exp)'"'
                        if `"`macval(grp)'"' != "" local check `"`macval(check)' [`macval(grp)']"'
                        _dataqa_allowed `knd'
                        local allow `"`r(s)'"'
                        if "`knd'" == "review" local disp `"open (review item; allowed: `allow')"'
                        else {
                            local stv = cond("`sts'" == "fail", "failed", "warned")
                            local disp `"open (`knd' `stv'; allowed: `allow')"'
                            if "`sts'" == "error" local disp "open (call error, rc `=observed_num[`j']'; the call ran no gates; allowed: code fixed)"
                        }
                        local pic = cond("`knd'" == "invariant", "required if accepted", "")
                        foreach c in check obs exp disp ds rr {
                            mata: st_local("cell_`c'", subinstr(subinstr(st_local("`c'"), "|", "\|"), char(10), " "))
                        }
                        file write `fh' `"| `macval(cell_rr)' | `macval(cell_ds)' | `macval(cell_check)' | `macval(cell_obs)' | `macval(cell_exp)'; source: | `macval(cell_disp)' | `dt' | `pic' |"' _n
                        local ++nrows
                    }
                }
            }
            if "`bands'" != "" {
                file write `fh' _n "## Bands and stat() invariants" _n _n
                if `nbands' == 0 {
                    file write `fh' "No bands or stat() invariants in the selected run." _n
                }
                else {
                    file write `fh' "| Run | Dataset | Gate | Status | Declared range | Observed |" _n
                    file write `fh' "|---|---|---|---|---|---|" _n
                    frame `lf' {
                        forvalues j = 1/`=_N' {
                            if !_bd[`j'] continue
                            mata: _dataqa_bandmd(`j')
                            file write `fh' `"| `macval(cell_brun)' | `macval(cell_bds)' | `macval(cell_bg)' | `macval(cell_bst)' | `macval(cell_bex)' | `macval(cell_bob)' |"' _n
                        }
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
        if "`bands'" != "" return scalar n_bands = `nbands'
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
    local _bf_made = 0
    local _halt = 0
    tempname lf bf
    capture noisily {
        syntax [using/] [, RUN(string) EXPect(string asis) BASEline(string) ///
            BASELEDger(string) OPTional(string asis)]
        // expect() and optional() are lists of dataset names; a name with a
        // space is given in compound quotes, expect(`"b c"' d)
        local _expl ""
        local _r `"`expect'"'
        while `"`_r'"' != "" {
            gettoken _t _r : _r
            local _expl `"`_expl' `"`_t'"'"'
        }
        local _optl ""
        local _r `"`optional'"'
        while `"`_r'"' != "" {
            gettoken _t _r : _r
            local _optl `"`_optl' `"`_t'"'"'
        }
        local baseline = strtrim(`"`baseline'"')
        // the session baseline (dataqa set baseline()) when none is given;
        // its baseledger() goes with it, an explicit baseledger() wins
        if `"`baseline'"' == "" {
            _datamap_dqdefaults
            local baseline `"`r(baseline)'"'
            if `"`baseledger'"' == "" local baseledger `"`r(baseledger)'"'
        }
        if `"`baseline'"' == "" & `"`baseledger'"' != "" {
            display as error "dataqa assert: baseledger() needs baseline() (or dataqa set baseline())"
            exit 198
        }
        // optional() only waives baseline datasets; with no baseline it is
        // ignored with a note, so a study do-file may carry it before the
        // first baseline run exists
        local _optign = `"`baseline'"' == "" & `"`optional'"' != ""
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
        if `_optign' display as text "  note: optional() ignored; no baseline set (baseline() or dataqa set baseline())"
        local nbad = 0
        local missing ""
        local bmissing ""
        local bopt ""
        local nbmissing = 0
        local nbopt = 0
        if `"`baseline'"' != "" {
            frame create `bf'
            local _bf_made = 1
            _dataqa_loadbase `bf', file(`"`file'"') baseline(`"`baseline'"') ///
                baseledger(`"`baseledger'"') who(assert)
            if r(N) == 0 {
                display as error `"dataqa assert: baseline run `baseline' has no rows in `r(file)'; nothing to hold the run against"'
                exit 2000
            }
            // named datasets with rows in the baseline run but none now
            frame `lf' {
                quietly generate strL _dn = regexr(dataset, " \(modified\)$", "")
                quietly levelsof _dn if _dn != "", local(nowds)
                quietly drop _dn
            }
            frame `bf' {
                quietly generate strL _dn = regexr(dataset, " \(modified\)$", "")
                quietly levelsof _dn if _dn != "", local(baseds)
            }
            foreach ds of local baseds {
                // posof, not -list in-: a name with spaces is one element
                if `: list posof `"`ds'"' in nowds' continue
                local isopt = 0
                foreach o of local _optl {
                    if `"`o'"' == `"`ds'"' local isopt = 1
                }
                if `isopt' {
                    local bopt `"`bopt' `"`ds'"'"'
                    local ++nbopt
                }
                else {
                    local bmissing `"`bmissing' `"`ds'"'"'
                    local ++nbmissing
                }
            }
            local bmissing = strtrim(`"`bmissing'"')
            local bopt = strtrim(`"`bopt'"')
        }
        if `N' == 0 {
            display as error "  no ledger rows for run `run'"
            local _halt = 1
        }
        frame `lf' {
            // a halting row: any failed row, or an invariant that failed
            // under bare warn
            quietly generate byte _bad = status == "fail" | status == "error" | ///
                (kind == "invariant" & status == "warn")
            quietly count if _bad
            local nbad = r(N)
            quietly count if status == "error"
            local nerr = r(N)
            if `nbad' > 0 {
                display as error "  `nbad' invariant or halting row(s) failed:"
                forvalues j = 1/`=_N' {
                    if !_bad[`j'] continue
                    // as text: no quote, macro or SMCL character in a label or
                    // value is live, as dataprobe prints it
                    mata: st_local("m", _dataqa_show(st_sdata(`j', "message")))
                    mata: st_local("d", _dataqa_show(st_sdata(`j', "dataset")))
                    if `"`macval(d)'"' == "" local d "(unnamed)"
                    if status[`j'] == "error" {
                        display as error `"    `macval(d)': call error, rc `=observed_num[`j']' (the call did not run its gates): `macval(m)'"'
                    }
                    else display as error `"    `macval(d)': `macval(m)'"'
                }
                local _halt = 1
            }
            foreach e of local _expl {
                // the name, with or without (modified): a prefix match let
                // expect(cohort) be met by "cohort (2019)"
                quietly count if dataset == `"`e'"' | dataset == `"`e' (modified)"'
                if r(N) == 0 {
                    if strpos(`"`e'"', " ") local missing `"`missing' `"`e'"'"'
                    else local missing `"`missing' `e'"'
                }
            }
        }
        local missing = strtrim(`"`missing'"')
        if `"`missing'"' != "" {
            display as error `"  no ledger rows in run `run' for: `missing' (a gate call did not run or was deleted)"'
            local _halt = 1
        }
        if `nbmissing' > 0 {
            display as error `"  `nbmissing' dataset(s) in baseline run `baseline' have no rows in run `run':"'
            foreach ds of local bmissing {
                display as error `"    `ds'"'
            }
            display as error "  (a gate call did not run or was deleted; list a dataset in optional() if it may be absent)"
            local _halt = 1
        }
        if `nbopt' > 0 {
            display as text `"  note: `nbopt' optional dataset(s) absent from run `run':"'
            foreach ds of local bopt {
                display as text `"    `ds'"'
            }
        }
        if !`_halt' {
            display as text "  " as result "`N'" as text " row(s); every invariant passed" ///
                cond(`"`expect'"' != "", "; every expected dataset has rows", "") ///
                cond(`"`baseline'"' != "", "; every baseline dataset has rows", "")
        }
        return scalar N = `N'
        return scalar n_superseded = `nsup'
        return scalar n_failed = `nbad'
        return scalar n_errors = `nerr'
        return local missing `"`missing'"'
        return local run `"`run'"'
        return local baseline `"`baseline'"'
        return scalar n_missing_base = `nbmissing'
        return local missing_base `"`bmissing'"'
        return scalar n_optional_absent = `nbopt'
        return local optional_absent `"`bopt'"'
    }
    local rc = _rc
    if `_bf_made' capture frame drop `bf'
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
        local csfile `"`r(path)'"'
        if `"`csfile'"' == `"`cfile'"' {
            display as error "dataqa export: saving() names the ledger being exported; the release copy needs its own file"
            exit 602
        }
        // nor over the session's ledger or baseline ledger when another
        // ledger is exported with using
        _datamap_dqdefaults
        local _sl `"`r(ledger)'"'
        local _sb `"`r(baseledger)'"'
        foreach _L in _sl _sb {
            if `"``_L''"' == "" continue
            mata: st_local("_lx", pathsuffix(st_local("`_L'")))
            if `"`_lx'"' == "" local `_L' `"``_L''.dta"'
            _dataqa_canon `"``_L''"'
            if `"`r(path)'"' == `"`csfile'"' {
                display as error "dataqa export: saving() names the session's " ///
                    cond("`_L'" == "_sl", "ledger", "baseline ledger") "; the release copy needs its own file"
                exit 602
            }
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
            quietly count if status == "error"
            if r(N) > 0 {
                display as error "dataqa export: refused; run `run' holds " r(N) " error row(s) (calls that exited with an error); fix the calls and rerun"
                exit 459
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
            // The same test on the text of the gates that are written as
            // data values (a rule expression, a forbidden or allowed value
            // list): pnr != "198001010009" and "none of 198001010011" sat in
            // expected and message beside a masked count.  The message
            // echoes the expectation, so it goes with it.  Bounds gates
            // (inrange, stat, ...) keep their numbers.
            local _vfam `""rule", "review", "byrule", "forbid", "notvalues", "allowed", "regex", "sets", "values""'
            local n_text_dropped = 0
            foreach v in expected label message {
                quietly generate byte _lit_`v' = inlist(family, `_vfam') & ///
                    (regexm(`v', "[0-9][0-9][0-9][0-9]") | strpos(`v', char(34)) > 0)
            }
            quietly replace _lit_message = 1 if _lit_expected | _lit_label
            foreach v in expected label message {
                quietly count if _lit_`v'
                local n_text_dropped = `n_text_dropped' + r(N)
                quietly replace `v' = "" if _lit_`v'
                quietly drop _lit_`v'
            }
            // signature leads with the dataset's N ("3:12(...)"): blank it
            // when that N is a small count the row's masking withholds
            local n_sig_dropped = 0
            capture confirm string variable signature
            if !_rc {
                quietly generate double _sgn = real(regexs(1)) if regexm(signature, "^([0-9]+):")
                quietly count if _sgn >= 1 & _sgn < `threshold'
                local n_sig_dropped = r(N)
                quietly replace signature = "" if _sgn >= 1 & _sgn < `threshold'
                quietly drop _sgn
            }
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
        if `n_text_dropped' display as text "  `n_text_dropped' expectation, label, or message text(s) with literal values blanked"
        if `n_sig_dropped' display as text "  `n_sig_dropped' signature(s) of a dataset with fewer than `threshold' rows blanked"
        return scalar n_text_dropped = `n_text_dropped'
        return scalar n_sig_dropped = `n_sig_dropped'
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
        if `"`baseline'"' == "" {
            _datamap_dqdefaults
            local baseline `"`r(baseline)'"'
            if `"`baseledger'"' == "" local baseledger `"`r(baseledger)'"'
        }
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
        frame create `bf'
        local _bf_made = 1
        _dataqa_loadbase `bf', file(`"`file'"') baseline(`"`baseline'"') ///
            baseledger(`"`baseledger'"') who(compare)
        local NB = r(N)
        display as text "dataqa compare: run " as result `"`run'"' as text " against baseline " ///
            as result `"`baseline'"'
        if `NB' == 0 {
            display as text "  baseline run `baseline' has no rows; nothing to compare"
        }
        else {
        // a call that errors now: reported whatever the baseline held
        frame `lf' {
            forvalues j = 1/`=_N' {
                if status[`j'] != "error" continue
                mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                if `"`ds'"' == "" local ds "(unnamed)"
                display as text "  error  " as result `"`macval(ds)'"' as text ": the call exited with rc " ///
                    as result `=observed_num[`j']' as text " and ran no gates"
                local ++nflag
            }
        }
        // one row per gate key (_dataqa_latest); (modified) is not part of
        // the name
        foreach f in `lf' `bf' {
            frame `f' {
                _dataqa_latest, one
                quietly replace dataset = regexr(dataset, " \(modified\)$", "")
                // a ledger written before signature() had no column; the
                // frget below stopped at r(111)
                capture confirm variable signature
                if _rc quietly generate strL signature = ""
            }
        }
        // A by() group named by number in one run and by value in the other
        // cannot be paired: group 3 and site=3 are not the same statement.
        // Flag the gate, and leave its groups out of the pairing.
        frame `lf': _dataqa_gforms
        local lN `"`r(nonly)'"'
        local lV `"`r(vany)'"'
        frame `bf': _dataqa_gforms
        local bN `"`r(nonly)'"'
        local bV `"`r(vany)'"'
        local mixed : list bN & lV
        local mixed2 : list lN & bV
        local mixed : list mixed | mixed2
        foreach m of local mixed {
            display as text "  mixed  " as result `"by(`m')"' as text ": one run records its groups by number " ///
                "(a ledger written before 1.9.0, or a withheld group), the other by value; " ///
                "the groups cannot be paired, so none is compared (re-run the baseline to compare)"
            local ++nflag
            local mt = char(9) + "by(`m')"
            local ml = strlen("`mt'")
            foreach f in `lf' `bf' {
                frame `f': quietly drop if strlen(_gkey) >= `ml' & substr(_gkey, strlen(_gkey) - `ml' + 1, `ml') == "`mt'"
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
                mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                local fl = subinstr(family[`j'] + "(" + label[`j'] + ")", "{", "{c -(}", .)
                // the by() group: without it two groups' flags read alike
                mata: st_local("_g", _dataqa_show(st_sdata(`j', "grp")))
                if `"`macval(_g)'"' != "" local fl `"`fl' [`macval(_g)']"'
                if missing(`a') | missing(`b') {
                    local bs = cond(missing(`b'), "withheld", "`b'")
                    local as = cond(missing(`a'), "withheld", "`a'")
                    display as text "  N  " as result `"`macval(ds)'"' as text " `fl': " ///
                        as result "`bs'" as text " -> " as result "`as'" ///
                        as text " (withheld under the mask in one run)"
                    local ++nflag
                    continue
                }
                if `b' == 0 {
                    if `a' != 0 {
                        display as text "  N  " as result `"`macval(ds)'"' as text " `fl': " ///
                            as result "0" as text " -> " as result "`a'" as text " (baseline 0)"
                        local ++nflag
                    }
                    continue
                }
                local rel = (`a' - `b') / `b'
                if abs(`rel') > `ntol' {
                    local pc = strtrim(string(100 * `rel', "%9.1f"))
                    display as text "  N  " as result `"`macval(ds)'"' as text " `fl': " ///
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
                    mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                    local fl = subinstr("stat(" + label[`j'] + ")", "{", "{c -(}", .)
                    mata: st_local("_g", _dataqa_show(st_sdata(`j', "grp")))
                    if `"`macval(_g)'"' != "" local fl `"`fl' [`macval(_g)']"'
                    local bs = cond(_bom[`j'] == 1, "masked", "undefined")
                    if !missing(_bo[`j']) local bs = strtrim(string(_bo[`j'], "%10.4g"))
                    local as = cond(obs_masked[`j'] == 1, "masked", "undefined")
                    if !missing(observed_num[`j']) local as = strtrim(string(observed_num[`j'], "%10.4g"))
                    display as text "  stat  " as result `"`macval(ds)'"' as text " `fl': " ///
                        as result "`bs'" as text " -> " as result "`as'"
                    local ++nflag
                    continue
                }
                local a = regexr(string(observed_num[`j'], "%21x"), "^[+]", "")
                local b = regexr(string(_bo[`j'], "%21x"), "^[+]", "")
                local rel = regexr(string(cond(`b' != 0, (`a' - `b') / abs(`b'), `a' - `b'), "%21x"), "^[+]", "")
                if abs(`rel') > `stattol' {
                    mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                    local fl = subinstr("stat(" + label[`j'] + ")", "{", "{c -(}", .)
                    mata: st_local("_g", _dataqa_show(st_sdata(`j', "grp")))
                    if `"`macval(_g)'"' != "" local fl `"`fl' [`macval(_g)']"'
                    display as text "  stat  " as result `"`macval(ds)'"' as text " `macval(fl)': " ///
                        as result %10.4g `b' as text " -> " as result %10.4g `a'
                    local ++nflag
                }
            }
            // changed signatures, once per dataset
            quietly levelsof dataset if !missing(`lk') & signature != "" & _bsig != "" & ///
                signature != _bsig, local(sigds)
            foreach ds of local sigds {
                mata: st_local("ds", _dataqa_show(st_local("ds")))
                display as text "  signature  " as result `"`macval(ds)'"' as text ": the data changed since the baseline"
                local ++nflag
            }
            quietly drop _bn _bo _bom _bsig
        }
        // a by() group of a gate the baseline also has, but not that group:
        // a new level of the by() variables
        frame `bf': mata: _dq_A = asarray_create(); _dq_b = st_sdata(., "_gkey"); for (_dq_i = 1; _dq_i <= rows(_dq_b); _dq_i++) asarray(_dq_A, _dq_b[_dq_i], 1)
        tempvar newg
        frame `lf' {
            quietly generate byte `newg' = 0
            mata: _dq_l = st_sdata(., "_gkey"); _dq_r = J(rows(_dq_l), 1, 0); for (_dq_i = 1; _dq_i <= rows(_dq_l); _dq_i++) _dq_r[_dq_i] = asarray_contains(_dq_A, _dq_l[_dq_i]); st_store(., st_varindex("`newg'"), _dq_r)
            forvalues j = 1/`=_N' {
                if missing(`lk'[`j']) & `newg'[`j'] & _gbase[`j'] != "" & grp[`j'] == _gbase[`j'] {
                    mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                    local fl = subinstr(family[`j'] + "(" + label[`j'] + ")", "{", "{c -(}", .)
                    display as text "  new  " as result `"`macval(ds)'"' as text `" `fl' [`=grp[`j']']: a group not in the baseline"'
                    local ++nflag
                }
            }
        }
        capture mata: mata drop _dq_A _dq_b _dq_l _dq_r _dq_i
        // gates present in the baseline but absent now
        tempvar bl
        frame `bf' {
            quietly frlink 1:1 _key, frame(`lf') generate(`bl')
            forvalues j = 1/`=_N' {
                if !missing(`bl'[`j']) continue
                mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                local fl = subinstr(family[`j'] + "(" + label[`j'] + ")", "{", "{c -(}", .)
                local g = grp[`j']
                if `"`g'"' != "" local fl `"`fl' [`g']"'
                local e = expected[`j']
                if `"`e'"' != "" local fl `"`fl', expected `e'"'
                display as text "  absent  " as result `"`macval(ds)'"' as text " `fl': in the baseline, not in this run"
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
    // the pairing's Mata globals, also when the comparison stopped midway
    capture mata: mata drop _dq_A _dq_b _dq_l _dq_r _dq_i
    if `_bf_made' capture frame drop `bf'
    if `_lf_made' capture frame drop `lf'
    if `rc' exit `rc'
end

// Display text for a stored ledger message, as dataprobe prints it: a line
// break, tab or other control character as \n, \r, \t or \xHH, a brace as
// {c -(}, and a backtick, double quote and dollar sign as {char N}.
capture mata: mata drop _dataqa_show()
capture mata: mata drop _dataqa_dscounts()
capture mata: mata drop _dataqa_openrows()
capture mata: mata drop _dataqa_bandtext()
capture mata: mata drop _dataqa_bandcells()
capture mata: mata drop _dataqa_bandmd()
mata:
string scalar _dataqa_show(string scalar s)
{
	real scalar i
	string scalar out
	out = subinstr(s, char(10), char(92) + "n")
	out = subinstr(out, char(13), char(92) + "r")
	out = subinstr(out, char(9), char(92) + "t")
	for (i = 1; i <= 31; i++) {
		if (i == 9 | i == 10 | i == 13) continue
		out = subinstr(out, char(i), char(92) + "x" + substr("0123456789abcdef", floor(i / 16) + 1, 1) + substr("0123456789abcdef", mod(i, 16) + 1, 1))
	}
	out = subinstr(out, "{", "{c -(}")
	out = subinstr(out, char(96), "{char 96}")
	out = subinstr(out, char(34), "{char 34}")
	out = subinstr(out, char(36), "{char 36}")
	return(out)
}

// One bands-table row's text fields from ledger row j: dataset, gate
// (family(label) [grp]), declared range, observed.
string rowvector _dataqa_bandtext(real scalar j)
{
	string scalar ds, g, gr, ex
	ds = st_sdata(j, "dataset")
	if (ds == "") ds = "(unnamed)"
	g = st_sdata(j, "family") + "(" + st_sdata(j, "label") + ")"
	gr = st_sdata(j, "grp")
	if (gr != "") g = g + " [" + gr + "]"
	ex = st_sdata(j, "expected")
	if (ex == "") ex = "(not recorded)"
	return((ds, g, ex, st_sdata(j, "observed")))
}

// Console cells _c1.._c4 for row j: cut and padded as the old %-16s, %-22s
// and %-18s columns, then shown as text (_dataqa_show).
void _dataqa_bandcells(real scalar j)
{
	string rowvector t
	real rowvector w
	real scalar k
	string scalar c
	t = _dataqa_bandtext(j)
	w = (16, 22, 18)
	for (k = 1; k <= 3; k++) {
		c = abbrev(t[k], w[k] - 1)
		c = c + (w[k] - ustrlen(c)) * " "
		st_local("_c" + strofreal(k), _dataqa_show(c))
	}
	st_local("_c4", _dataqa_show(t[4]))
}

// Markdown cells cell_brun, cell_bds, cell_bg, cell_bst, cell_bex,
// cell_bob for row j, a pipe escaped and a line break as a space.
void _dataqa_bandmd(real scalar j)
{
	string rowvector t, v, n
	real scalar k
	t = _dataqa_bandtext(j)
	v = (st_sdata(j, "run"), t[1], t[2], st_sdata(j, "status"), t[3], t[4])
	n = ("brun", "bds", "bg", "bst", "bex", "bob")
	for (k = 1; k <= 6; k++) {
		st_local("cell_" + n[k], subinstr(subinstr(v[k], "|", char(92) + "|"), char(10), " "))
	}
}

// Per dataset (rows numbered 1..D by dsi): gates (kind not review), fail,
// warn, review, error rows, and calls (rows flagged f1), into matrix mn
// (D x 6).
void _dataqa_dscounts(string scalar dsi, string scalar f1, string scalar mn)
{
	real colvector d, f
	string colvector st, kd
	real matrix C
	real scalar i, D
	d = st_data(., dsi)
	f = st_data(., f1)
	st = st_sdata(., "status")
	kd = st_sdata(., "kind")
	D = (rows(d) ? max(d) : 0)
	C = J(max((D, 1)), 6, 0)
	for (i = 1; i <= rows(d); i++) {
		C[d[i], 1] = C[d[i], 1] + (kd[i] != "review")
		C[d[i], 2] = C[d[i], 2] + (st[i] == "fail")
		C[d[i], 3] = C[d[i], 3] + (st[i] == "warn")
		C[d[i], 4] = C[d[i], 4] + (st[i] == "review")
		C[d[i], 5] = C[d[i], 5] + (st[i] == "error")
		C[d[i], 6] = C[d[i], 6] + (f[i] == 1)
	}
	st_matrix(mn, C)
}

// The rows of dataset k (dsi == k) with status fail, warn, review or
// error, as a list of row numbers in row order.
string scalar _dataqa_openrows(string scalar dsi, real scalar k)
{
	real colvector d, j
	string colvector st
	d = st_data(., dsi)
	st = st_sdata(., "status")
	j = selectindex((d :== k) :& ((st :== "fail") :| (st :== "warn") :|
		(st :== "review") :| (st :== "error")))
	if (length(j) == 0) return("")
	return(invtokens(strofreal(j', "%12.0f")))
}
end

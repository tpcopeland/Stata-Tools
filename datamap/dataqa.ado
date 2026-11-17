*! dataqa Version 2.1.0  2026/11/16
*! Session defaults and a structured QA ledger over dataprobe gate calls
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Subcommands:
//   dataqa set [agent] [options | clear]    session defaults in global DATAMAP_DQ (collect: gate failures do not halt a call; baseline() baseledger(): the run compare and assert hold the current run against)
//   dataqa report [using ledger] [, run() markdown() replace bands]
//   dataqa assert [using ledger] [, run() expect() baseline() baseledger() optional()]
//   dataqa export [using ledger], run() saving() [replace threshold()]
//   dataqa compare [using ledger], run() baseline() [baseledger() ntol() stattol()]
//   dataqa flow step|report|clear ...      cohort attrition flow (_dataqa_flow.ado)
//   dataqa merge, into() [from() replace]  fold worker shards into a ledger (_dataqa_merge.ado)
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
        // flow (2.1.0, F10, _dataqa_flow.ado) and merge (2.1.0, F12,
        // _dataqa_merge.ado) live in their own files
        if !inlist(`"`sub'"', "set", "report", "assert", "export", "compare", "flow", "merge") {
            if `"`sub'"' == "" display as error "dataqa requires a subcommand: set, report, assert, export, compare, flow, or merge"
            else display as error `"dataqa: unknown subcommand `sub'; use set, report, assert, export, compare, flow, or merge"'
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
    if substr(`"`macval(rest)'"', 1, 1) == "," local rest = strtrim(substr(`"`macval(rest)'"', 2, .))
    if lower(`"`macval(rest)'"') == "clear" {
        macro drop DATAMAP_DQ
        display as text "dataqa: session defaults cleared"
        return local defaults ""
        exit
    }
    if `"`macval(rest)'"' == "" {
        mata: st_local("_specshow", _dataqa_show(st_global("DATAMAP_DQ")))
        if `"$DATAMAP_DQ"' == "" display as text "dataqa: no session defaults are set"
        else display as text "dataqa session defaults: " as result `"`macval(_specshow)'"'
        return local defaults `"$DATAMAP_DQ"'
        exit
    }
    local 0 `", `macval(rest)'"'
    // the not-given sentinel is out of any typed range: with -1, a typed
    // mincell(-1) passed as "not given" and the call wiped the defaults
    // agent (2.0.0, U2): the safe preset for the session; dataqa set agent
    // reads as dataqa set, agent
    syntax [, MASKrare MINcell(integer -999999999) LEDger(string) WORKER(string) SHARDdir(string) RUN(string) PHASE(name) BANDWARN SIGnature COLLect REPLACE ///
        BASEline(string) BASELEDger(string) AGENT]
    if `mincell' < 0 & `mincell' != -999999999 {
        display as error "dataqa set: mincell() must be non-negative"
        exit 198
    }
    // quotes removed in Mata: the text as typed is never re-expanded, so a
    // backtick or dollar sign stays one for the checks below (R1)
    mata: st_local("ledger", subinstr(st_local("ledger"), char(34), ""))
    mata: st_local("run", subinstr(st_local("run"), char(34), ""))
    mata: st_local("baseline", strtrim(subinstr(st_local("baseline"), char(34), "")))
    mata: st_local("baseledger", strtrim(subinstr(st_local("baseledger"), char(34), "")))
    // dataprobe's ledger(file, run()) form: here run() is its own option
    mata: _dataqa_lrsplit(st_local("ledger"))
    if `_lrm' {
        display as error `"dataqa set: run() is its own option here; type dataqa set ledger("`macval(_lf)'") run(`macval(_lr)')"'
        exit 198
    }
    if `"`ledger'"' != "" {
        _datamap_validate_path `"`ledger'"', option(ledger())
        // the ledger path rule, the one Stata's save uses: .dta is added
        // to a basename without a suffix; any suffix is kept as given
        mata: st_local("_ext", pathsuffix(st_local("ledger")))
        if `"`_ext'"' == "" local ledger `"`ledger'.dta"'
    }
    // worker() and sharddir() (2.1.0, F12): this job writes its own shard
    // of the ledger (_dataqa_shardpath), never the shared file
    mata: st_local("sharddir", strtrim(subinstr(st_local("sharddir"), char(34), "")))
    mata: st_local("worker", strtrim(subinstr(st_local("worker"), char(34), "")))
    // both are tested in Mata before either is expanded (R1): the id is a
    // file-name token, the directory holds no backtick or dollar sign
    mata: st_local("_wok", strofreal(st_local("worker") == "" | (strlen(st_local("worker")) <= 32 & regexm(st_local("worker"), "^[A-Za-z0-9_-]+$")))); ///
        st_local("_sdok", strofreal(!strpos(st_local("sharddir"), char(96)) & !strpos(st_local("sharddir"), char(36)))); ///
        st_local("_wgiven", strofreal(st_local("worker") != "")); st_local("_sgiven", strofreal(st_local("sharddir") != ""))
    if !`_wok' {
        display as error "dataqa set: worker() must be 1 to 32 letters, digits, underscores or hyphens"
        exit 198
    }
    if !`_sdok' {
        display as error "illegal characters in sharddir() path"
        exit 198
    }
    local _shard ""
    if `_wgiven' | `_sgiven' {
        if !`_wgiven' {
            display as error "dataqa set: sharddir() is where worker() shards go; give worker() as well"
            exit 198
        }
        if `"`ledger'"' == "" {
            display as error "dataqa set: worker() writes a shard of ledger(); give ledger() as well"
            exit 198
        }
        if `"`sharddir'"' != "" {
            _datamap_validate_path `"`sharddir'"', option(sharddir())
            mata: st_local("_sdok", strofreal(direxists(st_local("sharddir"))))
            if !`_sdok' {
                display as error "dataqa set: sharddir() is not an existing directory"
                exit 601
            }
        }
        _dataqa_shardpath `"`ledger'"', worker(`worker') sharddir(`"`sharddir'"')
        local _shard `"`r(file)'"'
    }
    if `"`baseledger'"' != "" {
        _datamap_validate_path `"`baseledger'"', option(baseledger())
        mata: st_local("_ext", pathsuffix(st_local("baseledger")))
        if `"`_ext'"' == "" local baseledger `"`baseledger'.dta"'
    }
    foreach o in run baseline {
        // tested in Mata on the text as typed: expanded in quotes, a
        // backtick pair was read as a macro and passed the test (R1)
        mata: st_local("badrun", strofreal(_dataqa_badrun(st_local("`o'"))))
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
    if "`phase'" != "" & `"`ledger'"' == "" {
        display as error "dataqa set: phase() tags ledger rows; give ledger() as well"
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
    // under worker() the rows of run() this job reads and replace removes
    // are the shard's; the shared ledger is never opened here
    local _ledger_given `"`ledger'"'
    if `"`_shard'"' != "" local ledger `"`_shard'"'
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
                                mata: st_local("_lshow", _dataqa_show(st_local("ledger")))
                                display as error `"dataqa set: `macval(_lshow)' is not a dataprobe ledger (no variable `v'); replace left it untouched"'
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
    // replace starts the run's flow steps afresh too (2.1.0, F10,
    // _dataqa_flow.ado): every flow of run() in the flow file of the file
    // written, the shard in a worker session
    local n_flow_removed = .
    if "`replace'" != "" & `"`ledger'"' != "" & `"`run'"' != "" {
        _dataqa_flow clear, efile(`"`ledger'"') run(`"`run'"')
        if r(found) {
            local n_flow_removed = r(n_cleared)
            local _ffile `"`r(flowfile)'"'
        }
    }
    local ledger `"`_ledger_given'"'
    local spec ""
    if "`agent'" != "" local spec "safe"
    if "`maskrare'" != "" local spec "`spec' maskrare"
    if `mincell' >= 0 local spec "`spec' mincell(`mincell')"
    if `"`ledger'"' != "" local spec `"`spec' ledger("`ledger'")"'
    if `"`worker'"' != "" local spec `"`spec' worker(`worker')"'
    if `"`sharddir'"' != "" local spec `"`spec' sharddir("`sharddir'")"'
    if `"`run'"' != "" local spec `"`spec' run(`run')"'
    if "`phase'" != "" local spec `"`spec' phase(`phase')"'
    if `"`baseline'"' != "" local spec `"`spec' baseline(`baseline')"'
    if `"`baseledger'"' != "" local spec `"`spec' baseledger("`baseledger'")"'
    if "`bandwarn'" != "" local spec "`spec' bandwarn"
    if "`signature'" != "" local spec "`spec' signature"
    if "`collect'" != "" local spec "`spec' collect"
    local spec = strtrim(`"`spec'"')
    global DATAMAP_DQ `"`spec'"'
    mata: st_local("_specshow", _dataqa_show(st_local("spec")))
    display as text "dataqa session defaults: " as result `"`macval(_specshow)'"'
    if "`agent'" != "" {
        display as text "  safe: datamap, dataprobe and datamvp print and write under their safe preset" ///
            " (maskrare, mincell(5) or more, datesafe, likely identifiers excluded); stored results are not masked"
    }
    if "`collect'" != "" {
        display as text "  collect: a dataprobe call whose gates fail records its rows and returns rc 0;" ///
            " dataqa assert is the halting point"
        if `"`ledger'"' == "" display as text "  note: collect needs a ledger; a call without ledger() still exits 9"
    }
    if `"`_shard'"' != "" {
        mata: st_local("_shshow", _dataqa_show(st_local("_shard")))
        display as text "  worker `worker': ledger rows of this job go to the shard " as result `"`macval(_shshow)'"' ///
            as text "; fold the shards in with dataqa merge"
        local ledger `"`_shard'"'
    }
    mata: st_local("_rshow", _dataqa_show(st_local("run"))); st_local("_lshow", _dataqa_show(st_local("ledger")))
    if "`replace'" != "" {
        display as text "dataqa set: " as result "`n_removed'" as text " row(s) of run " ///
            as result `"`macval(_rshow)'"' as text " removed from " as result `"`macval(_lshow)'"'
        return scalar n_removed = `n_removed'
        if !missing(`n_flow_removed') {
            mata: st_local("_fshow", _dataqa_show(st_local("_ffile")))
            display as text "dataqa set: " as result "`n_flow_removed'" as text " flow step(s) of run " ///
                as result `"`macval(_rshow)'"' as text " removed from " as result `"`macval(_fshow)'"'
            return scalar n_flow_removed = `n_flow_removed'
        }
    }
    else if `n_prior' > 0 {
        display as text "note: ledger already holds " as result "`n_prior'" as text ///
            " row(s) of run " as result `"`macval(_rshow)'"' as text "; they are read with this" ///
            " session's rows; add replace to start the run afresh"
    }
    if `"`_shard'"' != "" return local shard `"`_shard'"'
    return local defaults `"`spec'"'
end

// Load the ledger into frame fr, restricted to run (all rows when run is
// empty) and, with phase() (2.1.0, U6), to the rows of those phases plus
// every call error row (a call that failed may have named another phase;
// it is never filtered away).  A ledger written before 2.1.0 has no phase
// column: its rows read as phase "", so a phase() selection keeps none of
// them.  Returns r(file), r(run), r(N).
capture program drop _dataqa_load
program define _dataqa_load, rclass
    version 16.0
    syntax name(name=fr) [, FILE(string) RUN(string) NEEDRUN WHO(string) PHASE(namelist)]
    if `"`file'"' == "" | `"`macval(run)'"' == "" {
        _datamap_dqdefaults
        // in a worker session (2.1.0, F12) the session ledger reads as
        // this job's shard; a using file is read as given
        local _wk "`r(worker)'"
        local _sd `"`r(sharddir)'"'
        if `"`macval(run)'"' == "" mata: st_local("run", st_global("r(run)"))
        if `"`file'"' == "" {
            local file `"`r(ledger)'"'
            if "`_wk'" != "" & `"`file'"' != "" {
                _dataqa_shardpath `"`file'"', worker(`_wk') sharddir(`"`_sd'"')
                local file `"`r(file)'"'
            }
        }
    }
    if `"`file'"' == "" {
        display as error "dataqa `who': no ledger; give using filename or set one with dataqa set ledger()"
        exit 198
    }
    if "`needrun'" != "" & `"`macval(run)'"' == "" {
        display as error "dataqa `who': run() is required"
        exit 198
    }
    _datamap_validate_path `"`file'"', option(using)
    // the writers' path rule (dataprobe ledger(), dataqa set): .dta is
    // added to a basename without a suffix, any suffix is kept as given
    mata: st_local("_ext", pathsuffix(st_local("file")))
    if `"`_ext'"' == "" local file `"`file'.dta"'
    mata: st_local("_fshow", _dataqa_show(st_local("file")))
    capture confirm file `"`file'"'
    if _rc {
        display as error `"dataqa `who': ledger `macval(_fshow)' not found"'
        exit 601
    }
    frame `fr' {
        quietly use `"`file'"', clear
        foreach v in run seq dataset family label status kind observed observed_num {
            capture confirm variable `v'
            if _rc {
                display as error `"dataqa `who': `macval(_fshow)' is not a dataprobe ledger (no variable `v')"'
                exit 610
            }
        }
        // the run compared in Mata: a quote or macro character in run()
        // is matched as typed, never expanded (R1)
        if `"`macval(run)'"' != "" {
            tempvar _ok
            quietly generate byte `_ok' = 0
            mata: st_store(., st_local("_ok"), st_sdata(., "run") :== st_local("run"))
            quietly keep if `_ok'
            quietly drop `_ok'
        }
        // the writers (dataprobe, _dataprobe_errrow) give every row one of
        // these statuses; any other value would read as neither pass nor
        // failure, and an edited or damaged ledger would pass assert
        capture confirm string variable status
        if _rc {
            display as error `"dataqa `who': `macval(_fshow)' is not a dataprobe ledger (status is not a string variable)"'
            exit 610
        }
        quietly count if !inlist(status, "pass", "fail", "warn", "review", "error")
        if r(N) > 0 {
            display as error `"dataqa `who': `macval(_fshow)' has `r(N)' row(s) with a status other than pass, fail, warn, review, or error; the ledger is damaged or was edited"'
            exit 610
        }
        if "`phase'" != "" {
            capture confirm variable phase
            if _rc quietly generate str1 phase = ""
            capture confirm string variable phase
            if _rc {
                display as error `"dataqa `who': `macval(_fshow)' is not a dataprobe ledger (phase is not a string variable)"'
                exit 610
            }
            tempvar _ph
            quietly generate byte `_ph' = status == "error"
            foreach p of local phase {
                quietly replace `_ph' = 1 if phase == "`p'"
            }
            quietly keep if `_ph'
            quietly drop `_ph'
        }
        local N = _N
    }
    return local file `"`file'"'
    return local run `"`macval(run)'"'
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
    // worker (2.1.0, F12): the rows of a merged ledger carry the worker
    // that wrote them, and a call supersedes only earlier rows of its own
    // worker, so one worker's passing call cannot hide another worker's
    // failure of the same gate (both rows stand).  Ledgers with no worker
    // column read as one worker.
    tempvar sgate wmix
    capture confirm string variable worker, exact
    local _hasw = !_rc
    if `_hasw' quietly generate strL `sgate' = `gate' + char(9) + worker
    else quietly generate strL `sgate' = `gate'
    quietly bysort run `sgate' (seq): generate double `mx' = seq[_N]
    // The latest call supersedes an earlier row of its gate, as a fixed
    // file reloaded and rerun clears its failure (duplicates drop, save,
    // use).  The exception: a latest call on data changed in memory, a
    // "(modified)" dataset, never supersedes a row of the unmodified data,
    // so a rerun on a subset (keep if ..., N 74 -> 12) cannot clear a
    // full-data failure.  A call's if/in is its scope, part of the gate.
    tempvar lastc dmod lmod
    quietly generate byte `lastc' = (seq == `mx')
    quietly generate byte `dmod' = regexm(dataset, " \(modified\)$")
    quietly bysort run `sgate': egen byte `lmod' = max(`lastc' & `dmod')
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
        // the latest call; likewise when two workers' rows stand (wmix)
        tempvar unmod srank mix
        quietly generate byte `unmod' = !`dmod'
        quietly bysort run _key: egen float `mix' = sd(`dmod')
        if `_hasw' quietly bysort run _key (worker): generate byte `wmix' = (worker[1] != worker[_N])
        else quietly generate byte `wmix' = 0
        quietly generate byte `srank' = 0
        quietly replace `srank' = 5 * (status == "error") + 4 * (status == "fail") + ///
            3 * (status == "warn") + 2 * (status == "review") + (status == "pass") ///
            if (`mix' > 0 & !missing(`mix')) | `wmix'
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
    syntax name(name=bf) , FILE(string) BASEline(string) [BASELEDger(string) WHO(string) ///
        PHASE(namelist)]
    local bfile `"`file'"'
    if `"`baseledger'"' != "" local bfile = subinstr(`"`baseledger'"', char(34), "", .)
    local _pho = cond("`phase'" != "", "phase(`phase')", "")
    _dataqa_load `bf', file(`"`bfile'"') run(`"`macval(baseline)'"') who(`who') `_pho'
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
        syntax [using/] [, RUN(string) PHASE(namelist) MARKdown(string) REPLACE BANDS]
        frame create `lf'
        local _lf_made = 1
        local _pho = cond("`phase'" != "", "phase(`phase')", "")
        _dataqa_load `lf', file(`"`using'"') run(`"`macval(run)'"') who(report) `_pho'
        local file `"`r(file)'"'
        mata: st_local("run", st_global("r(run)"))
        // unmerged worker shards (final review M2): reported, not refused
        _dataqa_unmerged, file(`"`file'"') run(`"`macval(run)'"')
        local _ush = r(n_shards)
        local _usr = r(n_rows)
        local _usw "`r(workers)'"
        frame `lf': _dataqa_latest
        local nsup = r(n_superseded)
        frame `lf': local N = _N
        // the run and file name as text (_dataqa_show): no SMCL, quote or
        // macro character in either is live (R1)
        mata: st_local("_runshow", _dataqa_show(st_local("run")))
        mata: st_local("_fileshow", _dataqa_show(st_local("file")))
        local runtxt = cond(`"`macval(run)'"' == "", "all runs", `"run `macval(_runshow)'"')
        display ""
        display as text "dataqa report: " as result `"`macval(_fileshow)'"' as text `", `macval(runtxt)'"'
        if "`phase'" != "" display as text "  phase(s): " as result "`phase'" as text " (call error rows of any phase are kept)"
        if `_ush' > 0 {
            display as error `"  WARNING: `_ush' worker shard(s) (worker(s) `_usw') hold `_usr' row(s) of `macval(runtxt)' not merged into the ledger; this report leaves them out (dataqa merge, into() folds them in)"'
        }
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
                // the error rows only, listed in Mata: a loop over every
                // ledger row cost interpreter time per row (P2)
                tempvar _er
                quietly generate byte `_er' = status == "error"
                local _jfrom 0
                while `_jfrom' >= 0 {
                    mata: st_local("_jl", _dataqa_rowlist(st_local("_er"), `_jfrom'))
                    foreach j of local _jl {
                        // ledger text is shown as text: no SMCL, quote or macro
                        // character in a dataset or run name is live
                        mata: st_local("d", _dataqa_show(st_sdata(`j', "dataset")))
                        if `"`macval(d)'"' == "" local d "(unnamed)"
                        mata: st_local("rn", _dataqa_show(st_sdata(`j', "run")))
                        display as error `"    `macval(d)': rc `=observed_num[`j']', run `macval(rn)', call `=seq[`j']'"'
                    }
                }
                quietly drop `_er'
            }
        }
        frame `lf' {
            quietly generate strL _ds = dataset
            quietly replace _ds = "(unnamed)" if _ds == ""
            // every dataset's counts in one pass: _dsi numbers the datasets
            // in sorted order (egen group), _f1 marks the first row of
            // each call (run, seq) as egen tag() does (a missing run or seq
            // is not a call), and _dataqa_dscounts tallies them; row order
            // is kept for the rows the markdown table lists
            tempvar _o1 _dsi _f1
            tempname _dqc
            quietly generate long `_o1' = _n
            // a run with no rows: by would run nothing and create no
            // variable, and the tally stopped at r(3598)
            if _N == 0 {
                quietly generate long `_dsi' = .
                quietly generate byte `_f1' = 0
            }
            else {
                quietly egen long `_dsi' = group(_ds)
                quietly bysort `_dsi' run seq (`_o1'): generate byte `_f1' = ///
                    (_n == 1) & !missing(run) & !missing(seq)
            }
            quietly sort `_o1'
            mata: _dataqa_dscounts(st_local("_dsi"), st_local("_f1"), st_local("_dqc"))
            display as text "  " %-32s "Dataset" %7s "Calls" %7s "Gates" %8s "Failed" ///
                %8s "Warned" %8s "Review"
            local tot_f = 0
            local tot_w = 0
            // the datasets by number, each name read in Mata from its rows
            // (never iterated as a macro list, R1)
            mata: st_local("nds", strofreal(st_nobs() ? max(st_data(., st_local("_dsi"))) : 0))
            forvalues k = 1/`nds' {
                mata: st_local("ds", _dataqa_dsname(st_local("_dsi"), `k'))
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
                    local _jfrom 0
                    while `_jfrom' >= 0 {
                        mata: st_local("_jl", _dataqa_rowlist("_bd", `_jfrom'))
                        foreach j of local _jl {
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
        }

        if `"`markdown'"' != "" {
            local mfile = subinstr(`"`markdown'"', char(34), "", .)
            _datamap_validate_path `"`mfile'"', option(markdown())
            mata: st_local("_mshow", _dataqa_show(st_local("mfile")))
            capture confirm file `"`mfile'"'
            if !_rc & "`replace'" == "" {
                display as error `"dataqa report: `macval(_mshow)' exists; specify replace"'
                exit 602
            }
            quietly file open `fh' using `"`mfile'"', write text replace
            local _fh_open = 1
            file write `fh' "| Run | Dataset | Check | Observed | Expectation and source | Disposition | Date | PI consulted |" _n
            file write `fh' "|---|---|---|---|---|---|---|---|" _n
            local nrows = 0
            // each register line is built in Mata and written from a
            // string scalar: ledger text is written as stored and is never
            // re-read as macro or quote syntax (R1); one pass per dataset
            // instead of five levelsof/count scans (P2)
            tempname _ln
            foreach _kd in invariant band other {
                _dataqa_allowed `_kd'
                local _al_`_kd' `"`r(s)'"'
            }
            frame `lf' {
                forvalues k = 1/`nds' {
                    local nbad = `_dqc'[`k', 2] + `_dqc'[`k', 3] + `_dqc'[`k', 5]
                    // clean-run row: every gate of the dataset passed
                    if `nbad' == 0 {
                        mata: _dataqa_cleanrow(st_local("_dsi"), `k')
                        if `ng' > 0 {
                            mata: st_strscalar(st_local("_ln"), st_local("_line"))
                            file write `fh' (scalar(`_ln')) _n
                            local ++nrows
                        }
                    }
                    // the dataset's open rows, in row order
                    local _jfrom 0
                    while `_jfrom' >= 0 {
                        mata: st_local("_jl", _dataqa_openrows(st_local("_dsi"), `k', `_jfrom'))
                        if `"`_jl'"' != "" mata: st_local("ds", _dataqa_dsname(st_local("_dsi"), `k'))
                        foreach j of local _jl {
                            mata: _dataqa_openrow(`j', st_local("ds"))
                            mata: st_strscalar(st_local("_ln"), st_local("_line"))
                            file write `fh' (scalar(`_ln')) _n
                            local ++nrows
                        }
                    }
                }
            }
            capture scalar drop `_ln'
            if "`bands'" != "" {
                file write `fh' _n "## Bands and stat() invariants" _n _n
                if `nbands' == 0 {
                    file write `fh' "No bands or stat() invariants in the selected run." _n
                }
                else {
                    file write `fh' "| Run | Dataset | Gate | Status | Declared range | Observed |" _n
                    file write `fh' "|---|---|---|---|---|---|" _n
                    frame `lf' {
                        local _jfrom 0
                        while `_jfrom' >= 0 {
                            mata: st_local("_jl", _dataqa_rowlist("_bd", `_jfrom'))
                            tempname _bln
                            foreach j of local _jl {
                                mata: _dataqa_bandmd(`j')
                                mata: st_strscalar(st_local("_bln"), "| " + st_local("cell_brun") + " | " + ///
                                    st_local("cell_bds") + " | " + st_local("cell_bg") + " | " + ///
                                    st_local("cell_bst") + " | " + st_local("cell_bex") + " | " + ///
                                    st_local("cell_bob") + " |")
                                file write `fh' (scalar(`_bln')) _n
                            }
                        }
                        capture scalar drop `_bln'
                    }
                }
            }
            file close `fh'
            local _fh_open = 0
            display as text "  register draft: " as result "`nrows'" as text " row(s) written to " ///
                as result `"`macval(_mshow)'"'
            return local markdown `"`mfile'"'
            return scalar n_rows = `nrows'
        }
        return local ledger `"`file'"'
        return local run `"`macval(run)'"'
        if "`phase'" != "" return local phase "`phase'"
        return scalar N = `N'
        return scalar n_superseded = `nsup'
        return scalar n_unmerged = `_ush'
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
            BASELEDger(string) OPTional(string asis) PENDing(namelist) PHASE(namelist)]
        // expect() and optional() are lists of dataset names; a name with a
        // space is given in compound quotes, expect(`"b c"' d).  Each name
        // is kept in its own local (_exp1.., _opt1..) and compared in Mata,
        // never re-read as macro syntax (R1)
        foreach _L in exp opt {
            local _r = cond("`_L'" == "exp", "expect", "optional")
            local _r : copy local `_r'
            local _`_L'_n = 0
            mata: st_local("_more", strofreal(strtrim(st_local("_r")) != ""))
            while `_more' {
                gettoken _t _r : _r
                mata: st_local("_more", strofreal(strtrim(st_local("_r")) != ""))
                mata: st_local("_skip", strofreal(st_local("_t") == ""))
                if `_skip' continue
                local ++_`_L'_n
                local _`_L'`_`_L'_n' : copy local _t
            }
        }
        mata: st_local("baseline", strtrim(st_local("baseline")))
        // the session baseline (dataqa set baseline()) when none is given;
        // its baseledger() goes with it, an explicit baseledger() wins
        if `"`macval(baseline)'"' == "" {
            _datamap_dqdefaults
            local baseline `"`r(baseline)'"'
            if `"`baseledger'"' == "" local baseledger `"`r(baseledger)'"'
        }
        if `"`macval(baseline)'"' == "" & `"`baseledger'"' != "" {
            display as error "dataqa assert: baseledger() needs baseline() (or dataqa set baseline())"
            exit 198
        }
        // pending() (2.1.0, U6): the phases whose datasets may have no rows
        // yet; a phase cannot be both selected by phase() and pending
        local _pph : list pending & phase
        if "`_pph'" != "" {
            display as error "dataqa assert: phase `_pph' is both selected by phase() and listed in pending()"
            exit 198
        }
        // optional() and pending() only waive baseline datasets; with no
        // baseline they are ignored with a note, so a study do-file may
        // carry them before the first baseline run exists
        local _optign = `"`macval(baseline)'"' == "" & `_opt_n' > 0
        local _pendign = `"`macval(baseline)'"' == "" & "`pending'" != ""
        frame create `lf'
        local _lf_made = 1
        local _pho = cond("`phase'" != "", "phase(`phase')", "")
        _dataqa_load `lf', file(`"`using'"') run(`"`macval(run)'"') needrun who(assert) `_pho'
        local file `"`r(file)'"'
        mata: st_local("run", st_global("r(run)"))
        // worker shards of the ledger holding rows of the run that the
        // ledger does not (final review M2): the run is not all here, and
        // a worker's failure must not pass unseen (any phase counts)
        _dataqa_unmerged, file(`"`file'"') run(`"`macval(run)'"')
        local _ush = r(n_shards)
        local _usr = r(n_rows)
        local _usw "`r(workers)'"
        frame `lf': _dataqa_latest
        local nsup = r(n_superseded)
        frame `lf': local N = _N
        // run, baseline and file names as text (R1)
        foreach _v in file run baseline {
            mata: st_local("_`_v'show", _dataqa_show(st_local("`_v'")))
        }
        display ""
        display as text "dataqa assert: " as result `"`macval(_fileshow)'"' as text ", run " as result `"`macval(_runshow)'"'
        if "`phase'" != "" display as text "  phase(s): " as result "`phase'" as text " (call error rows of any phase are kept)"
        if `_ush' > 0 {
            display as error `"  `_ush' worker shard(s) (worker(s) `_usw') hold `_usr' row(s) of run `macval(_runshow)' not merged into the ledger; fold them in with dataqa merge, into() and assert again"'
            local _halt = 1
        }
        if `nsup' > 0 display as text "  `nsup' row(s) superseded by a later call of the same gate"
        if `_optign' display as text "  note: optional() ignored; no baseline set (baseline() or dataqa set baseline())"
        if `_pendign' display as text "  note: pending() ignored; no baseline set (baseline() or dataqa set baseline())"
        local nbad = 0
        local missing ""
        local bmissing ""
        local bopt ""
        local bpend ""
        local nbmissing = 0
        local nbopt = 0
        local nbpend = 0
        local _pg_n = 0
        local _xm_n = 0
        if `"`macval(baseline)'"' != "" {
            frame create `bf'
            local _bf_made = 1
            _dataqa_loadbase `bf', file(`"`file'"') baseline(`"`macval(baseline)'"') ///
                baseledger(`"`baseledger'"') who(assert) `_pho'
            if r(N) == 0 {
                mata: st_local("_bfshow", _dataqa_show(st_global("r(file)")))
                display as error `"dataqa assert: baseline run `macval(_baselineshow)' has no rows in `macval(_bfshow)'; nothing to hold the run against"'
                exit 2000
            }
        }
        // named datasets with rows in the baseline run but none now, split
        // into optional(), pending() (every baseline row of the dataset is
        // of a pending phase) and missing; and the expect() names with no
        // rows now.  Computed in Mata over both frames.
        mata: _dataqa_assertsets(st_local("lf"), (st_local("_bf_made") == "1" ? st_local("bf") : ""), ///
            st_local("pending"))
        if `N' == 0 {
            if "`phase'" != "" display as error `"  no ledger rows for run `macval(_runshow)' in phase(s) `phase'"'
            else display as error `"  no ledger rows for run `macval(_runshow)'"'
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
                local _jfrom 0
                while `_jfrom' >= 0 {
                    mata: st_local("_jl", _dataqa_rowlist("_bad", `_jfrom'))
                    foreach j of local _jl {
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
                }
                local _halt = 1
            }
        }
        if `_xm_n' > 0 {
            mata: st_local("_xmshow", _dataqa_show(st_local("missing")))
            display as error `"  no ledger rows in run `macval(_runshow)' for: `macval(_xmshow)' (a gate call did not run or was deleted)"'
            local _halt = 1
        }
        if `nbmissing' > 0 {
            display as error `"  `nbmissing' dataset(s) in baseline run `macval(_baselineshow)' have no rows in run `macval(_runshow)':"'
            forvalues i = 1/`nbmissing' {
                display as error `"    `macval(_bm`i')'"'
            }
            display as error "  (a gate call did not run or was deleted; list a dataset in optional() if it may be absent)"
            local _halt = 1
        }
        if `nbopt' > 0 {
            display as text `"  note: `nbopt' optional dataset(s) absent from run `macval(_runshow)':"'
            forvalues i = 1/`nbopt' {
                display as text `"    `macval(_bo`i')'"'
            }
        }
        if `nbpend' > 0 {
            display as text `"  pending: `nbpend' dataset(s) of phase(s) `pending' have no rows in run `macval(_runshow)' yet:"'
            forvalues i = 1/`nbpend' {
                display as text `"    PENDING `macval(_bp`i')'"'
            }
        }
        // baseline gates of a pending phase not run yet in a dataset that
        // has rows (_dataqa_pendgates): listed, never halting
        if `_pg_n' > 0 {
            display as text `"  pending: `_pg_n' gate(s) of phase(s) `pending' have no rows in run `macval(_runshow)' yet:"'
            forvalues i = 1/`_pg_n' {
                display as text `"    PENDING `macval(_pg`i')'"'
            }
        }
        if !`_halt' {
            display as text "  " as result "`N'" as text " row(s); every invariant passed" ///
                cond(`_exp_n' > 0, "; every expected dataset has rows", "") ///
                cond(`"`macval(baseline)'"' != "", "; every baseline dataset has rows", "") ///
                cond(`nbpend' > 0, "; `nbpend' pending", "") ///
                cond(`_pg_n' > 0, "; `_pg_n' gate(s) pending", "")
        }
        return scalar N = `N'
        return scalar n_superseded = `nsup'
        return scalar n_failed = `nbad'
        return scalar n_errors = `nerr'
        return scalar n_unmerged = `_ush'
        return local missing `"`macval(missing)'"'
        return local run `"`macval(run)'"'
        return local baseline `"`macval(baseline)'"'
        return scalar n_missing_base = `nbmissing'
        return local missing_base `"`macval(bmissing)'"'
        return scalar n_optional_absent = `nbopt'
        return local optional_absent `"`macval(bopt)'"'
        if "`pending'" != "" {
            return scalar n_pending = `nbpend'
            return local pending `"`macval(bpend)'"'
            return scalar n_pending_gates = `_pg_n'
        }
        if "`phase'" != "" return local phase "`phase'"
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
        syntax [using/] , SAVing(string) [RUN(string) PHASE(namelist) REPLACE THReshold(integer 5)]
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
        local _pho = cond("`phase'" != "", "phase(`phase')", "")
        _dataqa_load `lf', file(`"`using'"') run(`"`macval(run)'"') needrun who(export) `_pho'
        local file `"`r(file)'"'
        mata: st_local("run", st_global("r(run)"))
        // names as text in every message (R1)
        foreach _v in run sfile {
            mata: st_local("_`_v'show", _dataqa_show(st_local("`_v'")))
        }
        // the release copy of a run whose worker shards are not merged
        // would leave their rows out (final review M2): refused
        _dataqa_unmerged, file(`"`file'"') run(`"`macval(run)'"')
        if r(n_shards) > 0 {
            display as error `"dataqa export: refused; "' r(n_shards) `" worker shard(s) (worker(s) `r(workers)') hold "' r(n_rows) `" row(s) of run `macval(_runshow)' not merged into the ledger; fold them in with dataqa merge, into() first"'
            exit 459
        }
        local _phtxt = cond("`phase'" != "", " in phase(s) `phase'", "")
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
            display as error `"dataqa export: no ledger rows for run `macval(_runshow)'`_phtxt'"'
            exit 2000
        }
        frame `lf' {
            foreach v in masked mincell minshown obs_masked scope {
                capture confirm variable `v'
                if _rc {
                    mata: st_local("_fshow", _dataqa_show(st_local("file")))
                    display as error `"dataqa export: `macval(_fshow)' lacks column `v'; it predates the masking record"'
                    exit 459
                }
            }
            quietly count if status == "error"
            if r(N) > 0 {
                display as error `"dataqa export: refused; run `macval(_runshow)' holds "' r(N) " error row(s) (calls that exited with an error); fix the calls and rerun"
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
                // smallcells() cells are expressions too (id==12345):
                // inlist() takes at most nine strings beside family
                quietly generate byte _lit_`v' = (inlist(family, `_vfam') | family == "smallcells") & ///
                    (regexm(`v', "[0-9][0-9][0-9][0-9]") | strpos(`v', char(34)) > 0)
            }
            quietly replace _lit_message = 1 if _lit_expected | _lit_label
            // a smallcells() row repeats its cell expressions in variable:
            // that copy goes with the label
            quietly replace variable = "" if family == "smallcells" & ///
                (_lit_label | regexm(variable, "[0-9][0-9][0-9][0-9]") | strpos(variable, char(34)) > 0)
            foreach v in expected label message {
                quietly count if _lit_`v'
                local n_text_dropped = `n_text_dropped' + r(N)
                quietly replace `v' = "" if _lit_`v'
                quietly drop _lit_`v'
            }
            // a gate's own if is echoed at the end of its message
            // ("expected [0, 1] (if id==12345)"): a literal there is a
            // literal of the scope blanked above, so the message goes too
            quietly generate long _ifp = strpos(message, " (if ")
            quietly generate byte _lit_if = _ifp > 0 & ///
                (regexm(substr(message, _ifp, .), "[0-9][0-9][0-9][0-9]") | strpos(substr(message, _ifp, .), char(34)) > 0)
            quietly count if _lit_if
            local n_text_dropped = `n_text_dropped' + r(N)
            quietly replace message = "" if _lit_if
            quietly drop _ifp _lit_if
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
                display as error `"dataqa export: `macval(_sfileshow)' exists; specify replace"'
                exit 602
            }
            quietly save `"`sfile'"', replace
        }
        display as text "dataqa export: " as result "`N'" as text " row(s) of run " as result `"`macval(_runshow)'"' ///
            as text "`_phtxt' written to " as result `"`macval(_sfileshow)'"'
        if `n_scope_dropped' display as text "  `n_scope_dropped' scope expression(s) with literal values blanked"
        if `n_text_dropped' display as text "  `n_text_dropped' expectation, label, or message text(s) with literal values blanked"
        if `n_sig_dropped' display as text "  `n_sig_dropped' signature(s) of a dataset with fewer than `threshold' rows blanked"
        return scalar n_text_dropped = `n_text_dropped'
        return scalar n_sig_dropped = `n_sig_dropped'
        return scalar N = `N'
        return scalar n_superseded = `nsup'
        return scalar n_scope_dropped = `n_scope_dropped'
        return local saving `"`sfile'"'
        if "`phase'" != "" return local phase "`phase'"
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
        syntax [using/] [, RUN(string) BASEline(string) BASELEDger(string) PHASE(namelist) ///
            NTOL(real 0.05) STATTOL(real 0.05)]
        if `ntol' < 0 | `stattol' < 0 {
            display as error "dataqa compare: ntol() and stattol() must be non-negative"
            exit 198
        }
        mata: st_local("baseline", strtrim(st_local("baseline")))
        if `"`macval(baseline)'"' == "" {
            _datamap_dqdefaults
            local baseline `"`r(baseline)'"'
            if `"`baseledger'"' == "" local baseledger `"`r(baseledger)'"'
        }
        local nflag = 0
        local _pho = cond("`phase'" != "", "phase(`phase')", "")
        display ""
        if `"`macval(baseline)'"' == "" {
            display as text "dataqa compare: no baseline run given; nothing to compare (first run on this extract)"
        }
        else {
        frame create `lf'
        local _lf_made = 1
        _dataqa_load `lf', file(`"`using'"') run(`"`macval(run)'"') needrun who(compare) `_pho'
        local file `"`r(file)'"'
        mata: st_local("run", st_global("r(run)"))
        frame create `bf'
        local _bf_made = 1
        _dataqa_loadbase `bf', file(`"`file'"') baseline(`"`macval(baseline)'"') ///
            baseledger(`"`baseledger'"') who(compare) `_pho'
        local NB = r(N)
        // run and baseline names as text (R1)
        foreach _v in run baseline {
            mata: st_local("_`_v'show", _dataqa_show(st_local("`_v'")))
        }
        display as text "dataqa compare: run " as result `"`macval(_runshow)'"' as text " against baseline " ///
            as result `"`macval(_baselineshow)'"'
        if "`phase'" != "" display as text "  phase(s): " as result "`phase'" as text " (call error rows of any phase are kept)"
        if `NB' == 0 {
            display as text `"  baseline run `macval(_baselineshow)' has no rows; nothing to compare"'
        }
        else {
        // a call that errors now: reported whatever the baseline held
        frame `lf' {
            tempvar _er
            quietly generate byte `_er' = status == "error"
            local _jfrom 0
            while `_jfrom' >= 0 {
                mata: st_local("_jl", _dataqa_rowlist(st_local("_er"), `_jfrom'))
                foreach j of local _jl {
                    mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                    if `"`ds'"' == "" local ds "(unnamed)"
                    display as text "  error  " as result `"`macval(ds)'"' as text ": the call exited with rc " ///
                        as result `=observed_num[`j']' as text " and ran no gates"
                    local ++nflag
                }
            }
            quietly drop `_er'
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
            // the rows that can print, selected in one vectorized pass;
            // the loop body still decides.  The body reads the counts
            // through macros, which do not keep every bit of a double, so
            // the selection is a superset: ntol() less one part in a million
            // (P2)
            tempvar _fN _fS
            quietly generate byte `_fN' = !missing(`lk') & !(missing(n_scope) & missing(_bn)) & ///
                (missing(n_scope) | missing(_bn) | _bn == 0 | ///
                abs((n_scope - _bn) / _bn) > `ntol' * (1 - 1e-6))
            local _jfrom 0
            while `_jfrom' >= 0 {
                mata: st_local("_jl", _dataqa_rowlist(st_local("_fN"), `_jfrom'))
                foreach j of local _jl {
                    if missing(`lk'[`j']) continue
                    local a = n_scope[`j']
                    local b = _bn[`j']
                    if missing(`a') & missing(`b') continue
                    mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                    // family(label) [grp] as text (_dataqa_show): a quote,
                    // macro character or brace in a label, group or expected
                    // value prints as typed (R1); the by() group, without it
                    // two groups' flags read alike
                    mata: st_local("fl", _dataqa_gatetxt(`j', 0))
                    if missing(`a') | missing(`b') {
                        local bs = cond(missing(`b'), "withheld", "`b'")
                        local as = cond(missing(`a'), "withheld", "`a'")
                        display as text "  N  " as result `"`macval(ds)'"' as text `" `macval(fl)': "' ///
                            as result "`bs'" as text " -> " as result "`as'" ///
                            as text " (withheld under the mask in one run)"
                        local ++nflag
                        continue
                    }
                    if `b' == 0 {
                        if `a' != 0 {
                            display as text "  N  " as result `"`macval(ds)'"' as text `" `macval(fl)': "' ///
                                as result "0" as text " -> " as result "`a'" as text " (baseline 0)"
                            local ++nflag
                        }
                        continue
                    }
                    local rel = (`a' - `b') / `b'
                    if abs(`rel') > `ntol' {
                        local pc = strtrim(string(100 * `rel', "%9.1f"))
                        display as text "  N  " as result `"`macval(ds)'"' as text `" `macval(fl)': "' ///
                            as result "`b'" as text " -> " as result "`a'" as text " (`pc'%)"
                        local ++nflag
                    }
                }
            }
            // stat() values beyond stattol()
            quietly generate byte `_fS' = family == "stat" & !missing(`lk') & ///
                !(missing(observed_num) & missing(_bo)) & (missing(observed_num) | missing(_bo) | ///
                abs(cond(_bo != 0, (observed_num - _bo) / abs(_bo), observed_num - _bo)) > `stattol')
            local _jfrom 0
            while `_jfrom' >= 0 {
                mata: st_local("_jl", _dataqa_rowlist(st_local("_fS"), `_jfrom'))
                foreach j of local _jl {
                    if family[`j'] != "stat" | missing(`lk'[`j']) continue
                    if missing(observed_num[`j']) & missing(_bo[`j']) continue
                    // a value on one side only: masked or undefined in the other
                    if missing(observed_num[`j']) | missing(_bo[`j']) {
                        mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                        mata: st_local("fl", _dataqa_gatetxt(`j', 0))
                        local bs = cond(_bom[`j'] == 1, "masked", "undefined")
                        if !missing(_bo[`j']) local bs = strtrim(string(_bo[`j'], "%10.4g"))
                        local as = cond(obs_masked[`j'] == 1, "masked", "undefined")
                        if !missing(observed_num[`j']) local as = strtrim(string(observed_num[`j'], "%10.4g"))
                        display as text "  stat  " as result `"`macval(ds)'"' as text `" `macval(fl)': "' ///
                            as result "`bs'" as text " -> " as result "`as'"
                        local ++nflag
                        continue
                    }
                    local a = regexr(string(observed_num[`j'], "%21x"), "^[+]", "")
                    local b = regexr(string(_bo[`j'], "%21x"), "^[+]", "")
                    local rel = regexr(string(cond(`b' != 0, (`a' - `b') / abs(`b'), `a' - `b'), "%21x"), "^[+]", "")
                    if abs(`rel') > `stattol' {
                        mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                        mata: st_local("fl", _dataqa_gatetxt(`j', 0))
                        display as text "  stat  " as result `"`macval(ds)'"' as text `" `macval(fl)': "' ///
                            as result %10.4g `b' as text " -> " as result %10.4g `a'
                        local ++nflag
                    }
                }
            }
            quietly drop `_fN' `_fS'
            // changed signatures, once per dataset, in sorted order; the
            // names are read and shown in Mata, never as a macro list
            tempvar _sg
            quietly generate byte `_sg' = !missing(`lk') & signature != "" & _bsig != "" & ///
                signature != _bsig
            mata: _dataqa_levels("dataset", st_local("_sg"), "_sigd")
            quietly drop `_sg'
            forvalues i = 1/`_sigd_n' {
                display as text "  signature  " as result `"`macval(_sigd`i')'"' as text ": the data changed since the baseline"
                local ++nflag
            }
            quietly drop _bn _bo _bom _bsig
        }
        // a by() group of a gate the baseline also has, but not that group:
        // a new level of the by() variables
        frame `bf': mata: _dq_A = asarray_create(); _dq_b = st_sdata(., "_gkey"); for (_dq_i = 1; _dq_i <= rows(_dq_b); _dq_i++) asarray(_dq_A, _dq_b[_dq_i], 1)
        tempvar newg _fG
        frame `lf' {
            quietly generate byte `newg' = 0
            mata: _dq_l = st_sdata(., "_gkey"); _dq_r = J(rows(_dq_l), 1, 0); for (_dq_i = 1; _dq_i <= rows(_dq_l); _dq_i++) _dq_r[_dq_i] = asarray_contains(_dq_A, _dq_l[_dq_i]); st_store(., st_varindex("`newg'"), _dq_r)
            quietly generate byte `_fG' = missing(`lk') & `newg' & _gbase != "" & grp == _gbase
            local _jfrom 0
            while `_jfrom' >= 0 {
                mata: st_local("_jl", _dataqa_rowlist(st_local("_fG"), `_jfrom'))
                foreach j of local _jl {
                    mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                    mata: st_local("fl", _dataqa_gatetxt(`j', 0))
                    display as text "  new  " as result `"`macval(ds)'"' as text `" `macval(fl)': a group not in the baseline"'
                    local ++nflag
                }
            }
        }
        capture mata: mata drop _dq_A _dq_b _dq_l _dq_r _dq_i
        // gates present in the baseline but absent now
        tempvar bl _fA
        frame `bf' {
            quietly frlink 1:1 _key, frame(`lf') generate(`bl')
            quietly generate byte `_fA' = missing(`bl')
            local _jfrom 0
            while `_jfrom' >= 0 {
                mata: st_local("_jl", _dataqa_rowlist(st_local("_fA"), `_jfrom'))
                foreach j of local _jl {
                    mata: st_local("ds", _dataqa_show(st_sdata(`j', "dataset")))
                    mata: st_local("fl", _dataqa_gatetxt(`j', 1))
                    display as text "  absent  " as result `"`macval(ds)'"' as text `" `macval(fl)': in the baseline, not in this run"'
                    local ++nflag
                }
            }
        }
        if `nflag' == 0 display as text "  no change beyond ntol(`ntol') and stattol(`stattol')"
        else display as text "  " as result "`nflag'" as text " item(s) to review (review severity; nothing halts)"
        }
        return local run `"`macval(run)'"'
        }
        return scalar n_flags = `nflag'
        return local baseline `"`macval(baseline)'"'
        if "`phase'" != "" return local phase "`phase'"
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
capture mata: mata drop _dataqa_rowlist()
capture mata: mata drop _dataqa_rowchunk()
capture mata: mata drop _dataqa_gatetxt()
capture mata: mata drop _dataqa_levels()
capture mata: mata drop _dataqa_dsname()
capture mata: mata drop _dataqa_cleanrow()
capture mata: mata drop _dataqa_openrow()
capture mata: mata drop _dataqa_mdcell()
capture mata: mata drop _dataqa_unmod()
capture mata: mata drop _dataqa_allpend()
capture mata: mata drop _dataqa_cqlist()
capture mata: mata drop _dataqa_shownum()
capture mata: mata drop _dataqa_assertsets()
capture mata: mata drop _dataqa_pendgates()
capture mata: mata drop _dataqa_gatekey()
capture mata: mata drop _dataqa_badrun()
capture mata: mata drop _dataqa_lrsplit()
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
// error after row from, as a list of row numbers in row order, in chunks
// (_dataqa_rowchunk).
string scalar _dataqa_openrows(string scalar dsi, real scalar k, real scalar from)
{
	real colvector d, j
	string colvector st
	d = st_data(., dsi)
	st = st_sdata(., "status")
	j = selectindex((d :== k) :& ((st :== "fail") :| (st :== "warn") :|
		(st :== "review") :| (st :== "error")))
	return(_dataqa_rowchunk(j, from))
}
// The rows where numeric variable v is nonzero and not missing, after row
// from, as a list of row numbers in row order, in chunks (P2: a loop over
// every ledger row in ado-code cost interpreter time on each one).
string scalar _dataqa_rowlist(string scalar v, real scalar from)
{
	real colvector x, j
	x = st_data(., v)
	j = selectindex((x :!= 0) :& (x :< .))
	return(_dataqa_rowchunk(j, from))
}
// At most 5,000 of the row numbers j after row from, as a list, and local
// _jfrom set to the last one listed, or to -1 when none is left.  A whole
// selection in one list would pass c(macrolen) at about 90,000 rows and be
// cut short without an error; the callers loop while _jfrom >= 0.
string scalar _dataqa_rowchunk(real matrix j0, real scalar from)
{
	real colvector j
	// selectindex() of an empty frame is 1 x 0
	if (length(j0) == 0) j = J(0, 1, .)
	else j = colshape(j0, 1)
	if (length(j) & from > 0) j = select(j, j :> from)
	if (length(j) == 0) {
		st_local("_jfrom", "-1")
		return("")
	}
	if (rows(j) > 5000) {
		j = j[|1 \ 5000|]
		st_local("_jfrom", strofreal(j[5000], "%12.0f"))
	}
	else st_local("_jfrom", "-1")
	return(invtokens(strofreal(j', "%12.0f")))
}

// compare's gate text for ledger row j, shown as text (_dataqa_show):
// family(label), then [grp] when there is one, then ", expected <text>"
// when withexp is set and one is recorded.
string scalar _dataqa_gatetxt(real scalar j, real scalar withexp)
{
	string scalar s, g, e
	s = _dataqa_show(st_sdata(j, "family") + "(" + st_sdata(j, "label") + ")")
	g = st_sdata(j, "grp")
	if (g != "") s = s + " [" + _dataqa_show(g) + "]"
	if (withexp) {
		e = st_sdata(j, "expected")
		if (e != "") s = s + ", expected " + _dataqa_show(e)
	}
	return(s)
}

// The distinct nonempty values of string variable v on rows where flag is
// nonzero, sorted as levelsof sorts them, shown as text: locals p_n and
// p1..pn.
void _dataqa_levels(string scalar v, string scalar flag, string scalar p)
{
	string colvector u
	real colvector j
	real scalar i
	j = selectindex(st_data(., flag) :!= 0)
	u = (length(j) ? st_sdata(j, v) : J(0, 1, ""))
	if (length(u)) u = uniqrows(select(u, u :!= ""))
	st_local(p + "_n", strofreal(length(u)))
	for (i = 1; i <= length(u); i++) st_local(p + strofreal(i), _dataqa_show(u[i]))
}

// The dataset name (_ds) of the datasets numbered k by dsi.
string scalar _dataqa_dsname(string scalar dsi, real scalar k)
{
	real colvector j
	j = selectindex(st_data(., dsi) :== k)
	return(length(j) ? st_sdata(j[1], "_ds") : "")
}

// A markdown cell: a pipe escaped; with nl, a line break as a space.
string scalar _dataqa_mdcell(string scalar s, real scalar nl)
{
	string scalar out
	out = subinstr(s, "|", char(92) + "|")
	if (nl) out = subinstr(out, char(10), " ")
	return(out)
}

// The register's clean-run row for dataset k (dsi == k), into local _line,
// and the number of its gate entries (kind not review) into local ng: the
// runs of its rows, its gate families, the date of its earliest stamp, each
// as levelsof lists them (sorted, nonempty, distinct).  Read in Mata, never
// re-read as macro syntax (R1).
void _dataqa_cleanrow(string scalar dsi, real scalar k)
{
	real colvector j
	string colvector r, f, kd, st
	string scalar rr, fams, dt
	real scalar ng
	j = selectindex(st_data(., dsi) :== k)
	r = st_sdata(j, "run")
	f = st_sdata(j, "family")
	kd = st_sdata(j, "kind")
	st = st_sdata(j, "stamp")
	r = select(r, r :!= "")
	rr = (length(r) ? invtokens(uniqrows(r)', ", ") : "")
	f = select(f, (kd :!= "review") :& (f :!= ""))
	fams = (length(f) ? invtokens(uniqrows(f)', " ") : "")
	ng = sum(kd :!= "review")
	st = select(st, st :!= "")
	dt = ""
	if (length(st)) {
		dt = uniqrows(st)[1]
		if (strpos(dt, " ")) dt = substr(dt, 1, strpos(dt, " ") - 1)
		dt = substr(dt, 1, 10)
	}
	st_local("ng", strofreal(ng, "%12.0f"))
	st_local("_line", "| " + _dataqa_mdcell(rr, 0) + " | " +
		_dataqa_mdcell(st_sdata(j[1], "_ds"), 0) + " | all gates passed: " + fams +
		" | 0 violations in " + strofreal(ng, "%12.0f") +
		" gate entries | as declared | clean | " + dt + " |  |")
}

// The register's open row for ledger row j of dataset ds, into local
// _line: check, observed, expectation, disposition, date, PI consulted.
// The allowed dispositions per kind come from _dataqa_allowed (locals
// _al_invariant, _al_band, _al_other).  Read in Mata, never re-read as
// macro syntax (R1).
void _dataqa_openrow(real scalar j, string scalar ds)
{
	string scalar fam, lab, obs, ex, grp, knd, sts, rr, chk, allow, disp, pic
	fam = st_sdata(j, "family")
	lab = st_sdata(j, "label")
	obs = st_sdata(j, "observed")
	ex = st_sdata(j, "expected")
	grp = st_sdata(j, "grp")
	knd = st_sdata(j, "kind")
	sts = st_sdata(j, "status")
	rr = st_sdata(j, "run")
	chk = fam + "(" + lab + "): " + obs + " against " + ex
	if (grp != "") chk = chk + " [" + grp + "]"
	allow = (knd == "invariant" ? st_local("_al_invariant") :
		(knd == "band" ? st_local("_al_band") : st_local("_al_other")))
	if (knd == "review") disp = "open (review item; allowed: " + allow + ")"
	else {
		disp = "open (" + knd + " " + (sts == "fail" ? "failed" : "warned") +
			"; allowed: " + allow + ")"
		if (sts == "error") disp = "open (call error, rc " +
			strofreal(st_data(j, "observed_num"), "%12.0g") +
			"; the call ran no gates; allowed: code fixed)"
	}
	pic = (knd == "invariant" ? "required if accepted" : "")
	st_local("_line", "| " + _dataqa_mdcell(rr, 1) + " | " + _dataqa_mdcell(ds, 1) +
		" | " + _dataqa_mdcell(chk, 1) + " | " + _dataqa_mdcell(obs, 1) + " | " +
		_dataqa_mdcell(ex, 1) + "; source: | " + _dataqa_mdcell(disp, 1) + " | " +
		substr(st_sdata(j, "stamp"), 1, 10) + " | " + pic + " |")
}
// Dataset names without a trailing " (modified)", as regexr() strips it.
string colvector _dataqa_unmod(string colvector d)
{
	string colvector out
	real scalar i, L
	out = d
	for (i = 1; i <= rows(d); i++) {
		L = strlen(d[i])
		if (L >= 11) {
			if (substr(d[i], L - 10, 11) == " (modified)") out[i] = substr(d[i], 1, L - 11)
		}
	}
	return(out)
}

// 1 when there is at least one phase in ph and every one is listed in pp.
real scalar _dataqa_allpend(string colvector ph, string rowvector pp)
{
	real scalar i
	if (length(ph) == 0 | length(pp) == 0) return(0)
	for (i = 1; i <= rows(ph); i++) {
		if (!anyof(pp, ph[i])) return(0)
	}
	return(1)
}

// A list of names, each in compound quotes (all = 1) or only those with
// a space (all = 0), separated by single spaces.
string scalar _dataqa_cqlist(string colvector v, real scalar all)
{
	real scalar i
	string scalar out, e
	out = ""
	for (i = 1; i <= rows(v); i++) {
		e = v[i]
		if (all | strpos(e, " ")) e = char(96) + char(34) + e + char(34) + char(39)
		out = out + (i > 1 ? " " : "") + e
	}
	return(out)
}

// Locals n<p> and <p>1..<p>n: the names of v shown as text.
void _dataqa_shownum(string colvector v, string scalar p, string scalar n)
{
	real scalar i
	st_local(n, strofreal(rows(v)))
	for (i = 1; i <= rows(v); i++) st_local(p + strofreal(i), _dataqa_show(v[i]))
}

// dataqa assert's dataset sets.  lf is the frame of the run, bf the frame
// of the baseline run ("" when there is none), pend the pending() phases.
// A named dataset (without " (modified)") with rows in the baseline but none
// in the run is optional when optional() lists it (locals _opt_n, _opt1..),
// else pending when every baseline row of it carries a phase listed in
// pend, else missing.  An expect() name (locals _exp_n, _exp1..) with no row
// named it or it " (modified)" is missing, or pending by the same baseline
// rule.  Sets missing and _xm_n; bmissing, nbmissing, _bm1..; bopt, nbopt,
// _bo1..; bpend, nbpend, _bp1...
void _dataqa_assertsets(string scalar lf, string scalar bf, string scalar pend)
{
	string scalar cur, nm
	string colvector nowraw, nowd, bdn, bph, u, bm, bo, bp, xm
	string rowvector pp
	real scalar i, k, nopt, isopt
	cur = st_framecurrent()
	st_framecurrent(lf)
	nowraw = st_sdata(., "dataset")
	st_framecurrent(cur)
	nowd = _dataqa_unmod(nowraw)
	pp = tokens(pend)
	bm = bo = bp = xm = J(0, 1, "")
	bdn = bph = J(0, 1, "")
	nopt = strtoreal(st_local("_opt_n"))
	if (bf != "") {
		st_framecurrent(bf)
		bdn = _dataqa_unmod(st_sdata(., "dataset"))
		if (_st_varindex("phase") < .) bph = st_sdata(., "phase")
		else bph = J(rows(bdn), 1, "")
		st_framecurrent(cur)
		u = select(bdn, bdn :!= "")
		if (length(u)) u = uniqrows(u)
		for (i = 1; i <= rows(u); i++) {
			if (length(nowd)) {
				if (anyof(nowd, u[i])) continue
			}
			isopt = 0
			for (k = 1; k <= nopt; k++) {
				if (st_local("_opt" + strofreal(k)) == u[i]) isopt = 1
			}
			if (isopt) bo = bo \ u[i]
			else if (_dataqa_allpend(bph[selectindex(bdn :== u[i])], pp)) bp = bp \ u[i]
			else bm = bm \ u[i]
		}
	}
	for (k = 1; k <= strtoreal(st_local("_exp_n")); k++) {
		nm = st_local("_exp" + strofreal(k))
		if (length(nowraw)) {
			if (anyof(nowraw, nm) | anyof(nowraw, nm + " (modified)")) continue
		}
		if (length(bdn) & length(pp)) {
			if (length(selectindex(bdn :== nm)) == 0) {
				xm = xm \ nm
				continue
			}
			if (_dataqa_allpend(bph[selectindex(bdn :== nm)], pp)) {
				if (length(bp) == 0) bp = nm
				else if (!anyof(bp, nm)) bp = bp \ nm
				continue
			}
		}
		xm = xm \ nm
	}
	_dataqa_pendgates(lf, bf, pp, nowd, bdn, bph)
	st_local("missing", _dataqa_cqlist(xm, 0))
	st_local("_xm_n", strofreal(rows(xm)))
	st_local("bmissing", _dataqa_cqlist(bm, 1))
	st_local("bopt", _dataqa_cqlist(bo, 1))
	st_local("bpend", _dataqa_cqlist(bp, 1))
	_dataqa_shownum(bm, "_bm", "nbmissing")
	_dataqa_shownum(bo, "_bo", "nbopt")
	_dataqa_shownum(bp, "_bp", "nbpend")
}
// dataqa assert's pending gates: in a named dataset that has rows in the
// run, a baseline gate whose phase is listed in pp (pending()) and that has
// no row in the run yet.  A gate is the dataset without " (modified)",
// family, label, variable, scope and kind; the by() group and the declared
// range aside, so a gate rerun with changed bounds is not pending.
// Sets _pg_n and _pg1.., each "dataset: family(label)" shown as text; the
// dataset-level sets above are not changed and nothing here halts.
void _dataqa_pendgates(string scalar lf, string scalar bf, string rowvector pp,
	string colvector nowd, string colvector bdn, string colvector bph)
{
	string scalar cur
	string colvector nk, bk, bshow, out
	real colvector sel
	real scalar i
	transmorphic A
	out = J(0, 1, "")
	if (bf != "" & length(pp) & length(nowd) & length(bdn)) {
		cur = st_framecurrent()
		st_framecurrent(lf)
		nk = _dataqa_gatekey(nowd)
		st_framecurrent(bf)
		bk = _dataqa_gatekey(bdn)
		bshow = st_sdata(., "family") :+ "(" :+ st_sdata(., "label") :+ ")"
		st_framecurrent(cur)
		A = asarray_create()
		for (i = 1; i <= rows(nk); i++) asarray(A, nk[i], 1)
		// the datasets present now
		for (i = 1; i <= rows(nowd); i++) asarray(A, char(10) + nowd[i], 1)
		sel = J(rows(bdn), 1, 0)
		for (i = 1; i <= rows(bdn); i++) {
			if (bdn[i] == "") continue
			if (!anyof(pp, bph[i])) continue
			if (!asarray_contains(A, char(10) + bdn[i])) continue
			if (asarray_contains(A, bk[i])) continue
			sel[i] = 1
			// once per gate
			asarray(A, bk[i], 1)
		}
		sel = selectindex(sel)
		if (length(sel)) out = bdn[sel] :+ ": " :+ bshow[sel]
	}
	_dataqa_shownum(out, "_pg", "_pg_n")
}
// The gate key of every row in the frame in memory, d the dataset names
// without " (modified)" (_dataqa_pendgates).
string colvector _dataqa_gatekey(string colvector d)
{
	string colvector k
	string scalar v
	real scalar i
	string rowvector vn
	k = d
	vn = ("family", "label", "variable", "scope", "kind")
	for (i = 1; i <= cols(vn); i++) {
		v = vn[i]
		if (_st_varindex(v) < .) k = k :+ char(9) :+ st_sdata(., v)
		else k = k :+ char(9)
	}
	return(k)
}
// 1 when a run() or baseline() label holds a parenthesis, quote, backslash
// or shell character: ; & | < > $ ( ) ` " \
real scalar _dataqa_badrun(string scalar s)
{
	real scalar i
	string rowvector c
	c = (";", "&", "|", "<", ">", char(36), "(", ")", char(96), char(34), char(92))
	for (i = 1; i <= cols(c); i++) {
		if (strpos(s, c[i])) return(1)
	}
	return(0)
}
// dataprobe's ledger(file, run()) form typed into dataqa set ledger():
// local _lrm 1 and the parts, shown as text, in _lf and _lr.
void _dataqa_lrsplit(string scalar s)
{
	st_local("_lrm", "0")
	if (regexm(s, "^(.*[^ ])[ ]*,[ ]*run\((.*)\)$")) {
		st_local("_lrm", "1")
		st_local("_lf", _dataqa_show(regexs(1)))
		st_local("_lr", _dataqa_show(regexs(2)))
	}
}
end

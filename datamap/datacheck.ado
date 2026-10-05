*! datacheck Version 1.9.2  2026/10/05
*! Console QC and expectation-gate command for the datamap package
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! stat(ess): Kish effective sample size (sum w)^2 / sum w^2 (Kish 1965, Survey Sampling)

// Gate records.  Every gate entry, passed or failed, and every review item
// posts one row to a record frame, in this column order:
//   fam kind ok label variable grp observed obsnum expected nscope scope msg
//   minshown omasked
// ok is 1 (pass), 0 (fail) or 2 (review); kind is invariant, band or review.
// observed is the text as printed (masked under maskrare), obsnum its value
// or missing when masked, minshown the smallest positive count printed
// unmasked.  The console verdict, violations(), r() and the ledger are all
// read from that frame, so they cannot disagree.  The family helpers
// (_datacheck_events.ado and siblings) post the same columns.

program define datacheck, rclass
    version 16.0
    // ---- minversion() probe: answered before the session is touched ----
    if regexm(strtrim(`"`macval(0)'"'), "^,[ ]*minver(s|si|sio|sion)?[ ]*\(([^)]*)\)[ ]*$") {
        local _req = strtrim(regexs(2))
        _datamap_version datacheck, atleast(`"`_req'"')
        if !r(ok) {
            display as error "datacheck: datamap `r(version)' is installed; version `r(required)' or later is required"
            exit 198
        }
        return local version "`r(version)'"
        exit
    }

    // the raw command line, kept for the error row of a call that fails to parse
    local _raw0 `"`macval(0)'"'
    local _collect     = 0
    local _ledfile     ""
    local _dsname      ""
    local _legacy_globals : all globals
    foreach g in S_1 S_FN S_FNDATE {
        local _had_`g' : list g in _legacy_globals
        mata: st_local("_old_" + st_local("g"), st_global(st_local("g")))
        // in Mata: a saved value ending in an unmatched ` (S_FNDATE keeps
        // only 17 characters) opened a compound quote here, r(132)
        mata: st_local("_had_" + st_local("g"), strofreal(st_local("_had_" + st_local("g")) == "1" | st_local("_old_" + st_local("g")) != ""))
    }

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved   = 0
    local _pframe_made = 0
    local _cframe_made = 0
    local _vframe_made = 0
    local _sframe_made = 0
    local _bframe_made = 0
    local _rframe_made = 0
    local _gframe_made = 0
    local _pframe      = ""
    local _cframe      = ""
    local _vframe      = ""
    local _sframe      = ""
    local _bframe      = ""
    local _rframe      = ""
    local _gframe      = ""
    local _exit9       = 0
    local _ledger_rc   = 0
    // syntax reads an explicit nomaskrare as the absence of maskrare, so it
    // is detected here, where it can still override a session default.
    local _nomask_explicit = regexm(" " + lower(`"`macval(0)'"') + " ", "[ ,]nomask(r|ra|rar|rare)?[ ,]")
    capture noisily {

        syntax [anything(name=varlistspec)] [if] [in] , [ ///
            SINGle(string) ///
            MAXCat(integer -999999999) EXClude(string) ///
            CONTinuous(string) CATegorical(string) date(string) ///
            ID(string) ///
            Detail MAXFreq(integer -999999999) RARE(integer -999999999) ///
            OUTliers(real -999999999) ///
            GATESonly ONLYflagged SHOW(string) MINcell(integer -999999999) MASKrare ///
            NOMISSing PATTERNS ///
            BYFREQ ///
            EXPECTN(numlist integer max=2) ISID(string) NODUPS ///
            REQuire(string) NOTMISSing(string) INRANGE(string) WARN ///
            ALLowed(string) FORbid(string) REGEX(string) NOTValues(string) ///
            RULE(string asis) STAT(string asis) BINary(string) ///
            BYRULE(string asis) ///
            EVENTS(string asis) INTERVALS(string) KEYSET(string asis) CONSTANT(string) ///
            SETS(string) JUMPS(string) ///
            BANDS(string asis) BANDWARN ///
            REVIEW(string asis) HEAPING(string) GROUPSTAT(string asis) ///
            COVERAGE(string) COMPLETE(string) ///
            SMALLcells(string asis) ///
            BY(string) OVER(string) ///
            CHECKs(string) MAKESpec(string) VIOLations(string) ///
            SAVing(string) CONFig(string) COMPare(string) ///
            LEDGER(string asis) NAME(string) MINVERsion(string) SIGnature ]

        // ---- ledger(filename [, run(string)]) ----
        local _ledfile ""
        local _ledrun ""
        if `"`ledger'"' != "" {
            local _lraw = strtrim(`"`ledger'"')
            local _lrest ""
            local _lq = substr(`"`_lraw'"', 1, 1) == char(34) | ///
                substr(`"`_lraw'"', 1, 2) == char(96) + char(34)
            if `_lq' {
                // a quoted filename is one token, so a comma inside the
                // quotes is part of the path
                gettoken _ledfile _lrest : _lraw
                local _lrest = strtrim(`"`_lrest'"')
                if `"`_lrest'"' == "" & regexm(`"`_ledfile'"', "^(.*[^ ])[ ]*,[ ]*(run\(.*\))$") {
                    local _lf = regexs(1)
                    local _lr = regexs(2)
                    display as error `"ledger(): run() belongs outside the quoted filename; type ledger("`_lf'", `_lr')"'
                    exit 198
                }
                if `"`_lrest'"' != "" {
                    if substr(`"`_lrest'"', 1, 1) != "," {
                        display as error `"ledger(): expected [, run(string)] after the filename; got `_lrest'"'
                        exit 198
                    }
                    local _lrest = strtrim(substr(`"`_lrest'"', 2, .))
                }
            }
            else {
                local _lcp = strpos(`"`_lraw'"', ",")
                if `_lcp' {
                    local _ledfile = strtrim(substr(`"`_lraw'"', 1, `_lcp' - 1))
                    local _lrest = strtrim(substr(`"`_lraw'"', `_lcp' + 1, .))
                }
                else local _ledfile `"`_lraw'"'
            }
            if `"`_lrest'"' != "" {
                if regexm(`"`_lrest'"', "^run\((.*)\)$") local _ledrun = strtrim(regexs(1))
                else {
                    display as error `"ledger(): the only suboption is run(string); got `_lrest'"'
                    exit 198
                }
            }
            // run() as typed, plain or compound-quoted, without its quotes; a
            // backtick left behind would be read as a macro by the writer
            mata: st_local("_ledrun", subinstr(_datacheck_unwrap(st_local("_ledrun")), char(34), ""))
        }

        // ---- session defaults (dataqa set): explicit > session > config ----
        local _sessnote = 0
        if `"$DATAMAP_DQ"' != "" {
            _datamap_dqdefaults
            if r(maskrare) {
                if `_nomask_explicit' local _sessnote = 1
                else if "`maskrare'" == "" local maskrare "maskrare"
            }
            if `mincell' == -999999999 & r(mincell) >= 0 local mincell = r(mincell)
            if `"`_ledfile'"' == "" local _ledfile `"`r(ledger)'"'
            if `"`_ledrun'"' == "" local _ledrun `"`r(run)'"'
            if "`bandwarn'" == "" & r(bandwarn) local bandwarn "bandwarn"
            if "`signature'" == "" & r(signature) local signature "signature"
            local _collect = r(collect)
        }

        if `"`config'"' != "" {
            _datacheck_pathok `"`config'"'
            confirm file `"`config'"'
            _datamap_load_config, config(`"`config'"')
            foreach opt in exclude continuous categorical show {
                local cfgval `"`r(`opt')'"'
                if `"``opt''"' == "" & `"`cfgval'"' != "" {
                    local `opt' `"`cfgval'"'
                }
            }
            if `"`date'"' == "" & `"`r(datevars)'"' != "" local date `"`r(datevars)'"'
            if `"`date'"' == "" & `"`r(date)'"' != "" local date `"`r(date)'"'
            foreach opt in maxcat maxfreq rare mincell outliers {
                if ``opt'' == -999999999 & `"`r(`opt')'"' != "" {
                    local `opt' = real(`"`r(`opt')'"')
                }
            }
            foreach opt in maskrare nomissing patterns gatesonly onlyflagged {
                if "`opt'" == "maskrare" & `_nomask_explicit' continue
                if "``opt''" == "" & "`r(`opt')'" != "" local `opt' "`opt'"
            }
        }
        if `maxcat' == -999999999 local maxcat = 25
        if `maxfreq' == -999999999 local maxfreq = 20
        if `rare' == -999999999 local rare = 0
        if `outliers' == -999999999 local outliers = 0
        if `mincell' == -999999999 local mincell = 0
        if `maxcat' <= 0 | missing(`maxcat') {
            display as error "maxcat() must be positive"
            exit 198
        }
        if `maxfreq' <= 0 | missing(`maxfreq') {
            display as error "maxfreq() must be positive"
            exit 198
        }
        if `rare' < 0 | missing(`rare') {
            display as error "rare() must be non-negative"
            exit 198
        }
        if `outliers' < 0 | missing(`outliers') {
            display as error "outliers() must be non-negative"
            exit 198
        }
        if `mincell' < 0 | missing(`mincell') {
            display as error "mincell() must be non-negative"
            exit 198
        }

        local _maskcell = `mincell'
        if "`maskrare'" != "" & `_maskcell' == 0 local _maskcell = `rare'
        if "`maskrare'" != "" & `_maskcell' == 0 local _maskcell = 5
        // Under maskrare an extreme (min/max) is never printed: p1/p99 take
        // its place, and any order statistic with fewer than the mask count
        // of observations at or beyond it is suppressed.  Every printed
        // count from 1 to mask - 1 prints as <mask.
        local _xmask = 0
        if "`maskrare'" != "" local _xmask = `_maskcell'
        local _gm = `_xmask'
        // Profile emphasis: red when output is on, but plain text under
        // quietly, because as-error text prints even inside quietly.
        local _em = cond(c(noisily), "error", "text")
        local show = lower(trim(`"`show'"'))
        local showflagged = 0
        if "`onlyflagged'" != "" local showflagged = 1
        if `"`show'"' != "" {
            if `"`show'"' == "flagged" local showflagged = 1
            else {
                display as error `"show() must be "flagged""'
                exit 198
            }
        }
        if "`gatesonly'" != "" & `showflagged' {
            display as error "cannot specify both gatesonly and onlyflagged/show(flagged)"
            exit 198
        }
        if `"`by'"' != "" & `"`over'"' != "" {
            display as error "cannot specify both by() and over()"
            exit 198
        }
        local byvars `"`by'"'
        if `"`over'"' != "" local byvars `"`over'"'
        if "`byfreq'" != "" & "`byvars'" == "" {
            display as error "byfreq requires by()"
            exit 198
        }

        if `"`_ledfile'"' != "" {
            _datamap_validate_path `"`_ledfile'"', option(ledger())
            // .dta is added only to a path without an extension, so a
            // tempfile path is used exactly as Stata issued it
            mata: st_local("_ledext", pathsuffix(st_local("_ledfile")))
            if `"`_ledext'"' == "" local _ledfile `"`_ledfile'.dta"'
        }

        // ---- package version (r(version), minversion(), the ledger) ----
        if `"`minversion'"' != "" {
            _datamap_version datacheck, atleast(`"`minversion'"')
            if !r(ok) {
                display as error "datacheck: datamap `r(version)' is installed; version `r(required)' or later is required"
                exit 198
            }
        }
        else _datamap_version datacheck
        local _pkgver "`r(version)'"

        // ---- preserve the user's data; everything below runs on a copy ----
        preserve
        local _preserved = 1

        // ---- single(): load a saved file in place of memory ----
        if `"`single'"' != "" {
            _datacheck_pathok `"`single'"'
            capture confirm file `"`single'"'
            if _rc {
                capture confirm file `"`single'.dta"'
                if _rc {
                    display as error `"file `single' not found"'
                    exit 601
                }
                local single `"`single'.dta"'
            }
            quietly use `"`single'"', clear
        }

        if c(N) == 0 {
            display as error "no observations"
            exit 2000
        }
        if c(k) == 0 {
            display as error "no variables"
            exit 102
        }

        // ---- dataset name for the verdict and the ledger ----
        // Taken before anything modifies the copy: the basename of
        // c(filename), marked (modified) when the data changed since the
        // last save; name() overrides it.
        local _dsname ""
        if `"`name'"' != "" local _dsname = strtrim(`"`name'"')
        else if `"`c(filename)'"' != "" {
            mata: st_local("_dsname", pathrmsuffix(pathbasename(st_global("c(filename)"))))
            if c(changed) local _dsname "`_dsname' (modified)"
        }
        local _dsig ""
        if "`signature'" != "" {
            quietly datasignature
            local _dsig "`r(datasignature)'"
        }

        // ---- checks(): read reusable gate specs from a Stata dataset ----
        foreach o in expectn stat inrange coverage groupstat heaping complete {
            local b_`o'_ck ""
        }
        if `"`checks'"' != "" {
            gettoken cfile crest : checks, parse(" ,")
            if trim(`"`crest'"') != "" {
                display as error "checks() accepts one Stata dataset filename"
                exit 198
            }
            _datacheck_pathok `"`cfile'"'
            capture confirm file `"`cfile'"'
            if _rc {
                capture confirm file `"`cfile'.dta"'
                if _rc {
                    display as error `"checks() file `cfile' not found"'
                    exit 601
                }
                local cfile `"`cfile'.dta"'
            }
            tempname cframe
            local _cframe "`cframe'"
            frame create `cframe'
            local _cframe_made = 1
            frame `cframe' {
                quietly use `"`cfile'"', clear
                capture confirm variable gate
                if _rc {
                    capture confirm variable check
                    if _rc {
                        display as error "checks() spec must contain string variable check or gate"
                        exit 198
                    }
                    rename check gate
                }
                capture confirm string variable gate
                if _rc {
                    display as error "checks() variable check/gate must be string"
                    exit 198
                }
                capture confirm variable var
                if _rc {
                    capture confirm variable variable
                    if !_rc rename variable var
                }
                local has_var = 0
                local has_arg1 = 0
                local has_arg2 = 0
                local has_values = 0
                local has_pattern = 0
                local has_kind = 0
                capture confirm string variable var
                if !_rc local has_var = 1
                capture confirm string variable arg1
                if !_rc local has_arg1 = 1
                capture confirm string variable arg2
                if !_rc local has_arg2 = 1
                capture confirm string variable values
                if !_rc local has_values = 1
                capture confirm string variable pattern
                if !_rc local has_pattern = 1
                capture confirm string variable kind
                if !_rc local has_kind = 1
                quietly count
                local C = r(N)
                forvalues ci = 1/`C' {
                    local cg = lower(strtrim(gate[`ci']))
                    local cv ""
                    local carg1 ""
                    local carg2 ""
                    local cvalues ""
                    local cpattern ""
                    local craw_values ""
                    local craw_pattern ""
                    local ckind ""
                    if `has_var'     local cv = strtrim(var[`ci'])
                    if `has_arg1'    local carg1 = strtrim(arg1[`ci'])
                    if `has_arg2'    local carg2 = strtrim(arg2[`ci'])
                    if `has_values'  local cvalues = strtrim(values[`ci'])
                    if `has_pattern' local cpattern = strtrim(pattern[`ci'])
                    if `has_kind'    local ckind = lower(strtrim(kind[`ci']))
                    local craw_values `"`cvalues'"'
                    local craw_pattern `"`cpattern'"'
                    if `"`cvalues'"' == "" local cvalues `"`carg1'"'
                    if `"`cpattern'"' == "" local cpattern `"`carg1'"'
                    if "`cg'" == "" continue
                    if !inlist("`ckind'", "", "invariant", "band") {
                        display as error "checks(): kind must be invariant or band (a review item is its own gate: review, heaping, groupstat, complete, jumps); got `ckind'"
                        exit 198
                    }
                    if "`ckind'" == "band" & !inlist("`cg'", "expectn", "stat", "inrange", ///
                        "coverage", "groupstat", "heaping", "complete") {
                        display as error "checks(): a `cg' row cannot be a band; bands are expectn, stat, inrange, coverage, groupstat, heaping, and complete"
                        exit 198
                    }
                    // text of the entry, and the option it joins
                    local ctxt ""
                    local ctgt ""
                    if "`cg'" == "expectn" {
                        if `"`carg1'"' == "" {
                            display as error "checks(): expectn row requires arg1"
                            exit 198
                        }
                        local ctxt = trim("`carg1' `carg2'")
                        // each row adds an entry; it never replaces
                        // expectn() or an earlier row
                        if "`ckind'" == "band" {
                            if "`b_expectn_ck'" == "" local b_expectn_ck "`ctxt'"
                            else local b_expectn_ck "`b_expectn_ck' \ `ctxt'"
                        }
                        else {
                            if "`expectn'" == "" local expectn "`ctxt'"
                            else local expectn "`expectn' \ `ctxt'"
                        }
                        continue
                    }
                    else if "`cg'" == "isid" | "`cg'" == "id" {
                        if "`cv'" == "" local cv `"`cvalues'"'
                        if "`cv'" == "" {
                            display as error "checks(): isid row requires var or values"
                            exit 198
                        }
                        // each row adds a key; it never replaces isid()
                        if "`isid'" == "" local isid "`cv'"
                        else local isid "`isid' \ `cv'"
                        continue
                    }
                    else if "`cg'" == "nodups" {
                        local nodups "nodups"
                        continue
                    }
                    else if "`cg'" == "require" {
                        if "`cv'" == "" local cv `"`cvalues'"'
                        if "`cv'" == "" {
                            display as error "checks(): require row requires var or values"
                            exit 198
                        }
                        local require "`require' `cv'"
                        continue
                    }
                    else if "`cg'" == "notmissing" {
                        if "`cv'" == "" local cv `"`cvalues'"'
                        if "`cv'" == "" {
                            display as error "checks(): notmissing row requires var or values"
                            exit 198
                        }
                        local notmissing "`notmissing' `cv'"
                        continue
                    }
                    else if "`cg'" == "binary" {
                        if "`cv'" == "" local cv `"`cvalues'"'
                        if "`cv'" == "" {
                            display as error "checks(): binary row requires var or values"
                            exit 198
                        }
                        local binary "`binary' `cv'"
                        continue
                    }
                    else if "`cg'" == "inrange" {
                        if "`cv'" == "" | `"`carg1'"' == "" | `"`carg2'"' == "" {
                            display as error "checks(): inrange row requires var, arg1, and arg2"
                            exit 198
                        }
                        local ctxt `"`cv' `carg1' `carg2'"'
                        local ctgt "inrange"
                    }
                    else if "`cg'" == "allowed" {
                        if "`cv'" == "" | `"`cvalues'"' == "" {
                            display as error "checks(): allowed row requires var and values"
                            exit 198
                        }
                        local ctxt `"`cv' `cvalues'"'
                        local ctgt "allowed"
                    }
                    else if "`cg'" == "forbid" | "`cg'" == "forbidden" {
                        if "`cv'" == "" | `"`cvalues'"' == "" {
                            display as error "checks(): forbid row requires var and values"
                            exit 198
                        }
                        local ctxt `"`cv' `cvalues'"'
                        local ctgt "forbid"
                    }
                    else if "`cg'" == "notvalues" | "`cg'" == "sentinel" {
                        if "`cv'" == "" | `"`cvalues'"' == "" {
                            display as error "checks(): notvalues row requires var and values"
                            exit 198
                        }
                        local ctxt `"`cv' `cvalues'"'
                        local ctgt "notvalues"
                    }
                    else if "`cg'" == "regex" {
                        if "`cv'" == "" | `"`cpattern'"' == "" {
                            display as error "checks(): regex row requires var and pattern"
                            exit 198
                        }
                        local ctxt `"`cv' `cpattern'"'
                        local ctgt "regex"
                    }
                    else if "`cg'" == "stat" {
                        if "`cv'" == "" | `"`craw_values'"' == "" | `"`carg1'"' == "" | `"`carg2'"' == "" {
                            display as error "checks(): stat row requires var, values (the statistic), arg1, and arg2"
                            exit 198
                        }
                        local ctxt `"`craw_values' `cv' `carg1' `carg2'"'
                        if `"`craw_pattern'"' != "" local ctxt `"`ctxt' if `craw_pattern'"'
                        local ctgt "stat"
                    }
                    else if "`cg'" == "rule" | "`cg'" == "review" {
                        local rexpr `"`craw_pattern'"'
                        if `"`rexpr'"' == "" local rexpr `"`craw_values'"'
                        if "`cv'" == "" | `"`rexpr'"' == "" {
                            display as error "checks(): `cg' row requires var (the label) and pattern (the expression)"
                            exit 198
                        }
                        local ctxt `""`cv'": `rexpr'"'
                        local ctgt "`cg'"
                    }
                    else if "`cg'" == "byrule" {
                        // var = label, values = byspec (byvars (sortvars)), pattern = expression
                        local rexpr `"`craw_pattern'"'
                        if `"`rexpr'"' == "" local rexpr `"`carg1'"'
                        if "`cv'" == "" | `"`rexpr'"' == "" | `"`craw_values'"' == "" {
                            display as error "checks(): byrule row requires var (the label), values (the by spec) and pattern (the expression)"
                            exit 198
                        }
                        local ctxt `"`craw_values': "`cv'": `rexpr'"'
                        local ctgt "byrule"
                    }
                    else if "`cg'" == "events" {
                        if "`cv'" == "" | `"`craw_values'"' == "" {
                            display as error "checks(): events row requires var (the covariates) and values (the event variable)"
                            exit 198
                        }
                        local ctxt `"`craw_values'"'
                        if `"`craw_pattern'"' != "" local ctxt `"`ctxt' if `craw_pattern'"'
                        local ctxt `"`ctxt': `cv'"'
                        if `"`carg1'"' != "" local ctxt `"`ctxt', min(`carg1')"'
                        local ctgt "events"
                    }
                    else if inlist("`cg'", "intervals", "sets", "jumps", "heaping") {
                        if "`cv'" == "" {
                            display as error "checks(): `cg' row requires var"
                            exit 198
                        }
                        local ctxt `"`cv'"'
                        if `"`craw_values'"' != "" local ctxt `"`ctxt', `craw_values'"'
                        local ctgt "`cg'"
                    }
                    else if "`cg'" == "keyset" {
                        if "`cv'" == "" | `"`craw_values'"' == "" {
                            display as error "checks(): keyset row requires var (the keys) and values (the file)"
                            exit 198
                        }
                        // the file is quoted, so a comma or space in its
                        // path is part of the filename
                        local _kf `"`craw_values'"'
                        if substr(`"`_kf'"', 1, 1) != char(34) local _kf `""`_kf'""'
                        local ctxt `"`cv' using `_kf'"'
                        if `"`carg1'"' != "" local ctxt `"`ctxt', `carg1'"'
                        local ctgt "keyset"
                    }
                    else if "`cg'" == "constant" {
                        if "`cv'" == "" | `"`craw_values'"' == "" {
                            display as error "checks(): constant row requires var (the variables) and values (the keys)"
                            exit 198
                        }
                        local ctxt `"`craw_values': `cv'"'
                        if `"`carg1'"' != "" local ctxt `"`ctxt', `carg1'"'
                        local ctgt "constant"
                    }
                    else if "`cg'" == "groupstat" {
                        if "`cv'" == "" | `"`craw_values'"' == "" | `"`carg1'"' == "" {
                            display as error "checks(): groupstat row requires var, values (the statistic), and arg1 (the by() variables)"
                            exit 198
                        }
                        local ctxt `"`craw_values' `cv', by(`carg1') `carg2'"'
                        if `"`craw_pattern'"' != "" local ctxt `"`ctxt' if `craw_pattern'"'
                        local ctgt "groupstat"
                    }
                    else if "`cg'" == "coverage" {
                        if "`cv'" == "" | `"`carg1'"' == "" | `"`carg2'"' == "" | `"`craw_values'"' == "" {
                            display as error "checks(): coverage row requires var, arg1, arg2, and values (gap() and options)"
                            exit 198
                        }
                        local ctxt `"`cv' `carg1' `carg2', `craw_values'"'
                        local ctgt "coverage"
                    }
                    else if "`cg'" == "complete" {
                        if "`cv'" == "" {
                            display as error "checks(): complete row requires var"
                            exit 198
                        }
                        local ctxt `"`cv'"'
                        if `"`carg1'"' != "" local ctxt `"`ctxt', min(`carg1')"'
                        local ctgt "complete"
                    }
                    else if "`cg'" == "smallcells" {
                        if "`cv'" == "" {
                            display as error "checks(): smallcells row requires var (the countexps) and optionally pattern (the if condition)"
                            exit 198
                        }
                        local ctxt `"`cv'"'
                        if `"`craw_pattern'"' != "" local ctxt `"`ctxt' if `craw_pattern'"'
                        local ctgt "smallcells"
                    }
                    else {
                        display as error "checks(): unsupported gate `cg'"
                        exit 198
                    }
                    if "`ckind'" == "band" local ctgt "b_`ctgt'_ck"
                    if `"``ctgt''"' == "" local `ctgt' `"`ctxt'"'
                    else local `ctgt' `"``ctgt'' \ `ctxt'"'
                }
            }
        }

        // ---- bands(): the call's sanity bands, kept apart from invariants ----
        foreach o in expectn stat inrange coverage groupstat heaping complete {
            local b_`o' ""
        }
        if `"`bands'"' != "" {
            _datacheck_bandsparse `macval(bands)'
            local b_expectn "`r(expectn)'"
            foreach o in stat inrange coverage groupstat heaping complete {
                local b_`o' `"`r(`o')'"'
            }
        }
        if "`b_expectn_ck'" != "" {
            if "`b_expectn'" == "" local b_expectn "`b_expectn_ck'"
            else local b_expectn "`b_expectn' \ `b_expectn_ck'"
        }
        foreach o in stat inrange coverage groupstat heaping complete {
            if `"`b_`o'_ck'"' != "" {
                if `"`b_`o''"' == "" local b_`o' `"`b_`o'_ck'"'
                else local b_`o' `"`b_`o'' \ `b_`o'_ck'"'
            }
        }

        // ---- resolve the profile varlist against the (now correct) data ----
        if `"`varlistspec'"' != "" {
            unab profilevars : `varlistspec'
        }
        else {
            quietly ds
            local profilevars `r(varlist)'
        }

        // ---- row subset from if/in ----
        tempvar touse
        marksample touse, novarlist
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations satisfy if/in"
            exit 2000
        }
        local _callscope = strtrim(regexr(`"`if'"', "^if ", ""))
        if `"`in'"' != "" local _callscope = strtrim(`"`_callscope' `in'"')

        // ---- require() gate is checked against existence, before any drop ----
        local req_missing ""
        foreach v of local require {
            capture confirm variable `v', exact
            if _rc local req_missing "`req_missing' `v'"
        }

        quietly keep if `touse'
        // touse is now constant (all rows kept); drop it so it never reaches
        // the classifier as a phantom variable in r() lists or saving().
        quietly drop `touse'
        // The user's columns, before any datacheck tempvar exists: nodups
        // compares these only, so a rule() indicator built from subscripts
        // cannot make two identical rows look distinct.
        quietly ds
        local _datavars `r(varlist)'

        // sort order at entry, for the note on subscripted rule()/review()
        local _sortedby_entry : sortedby

        // ---- rule() and review(): "label: expression" specs ----
        // Each is evaluated here, on the if/in subset in the caller's row
        // order and before any sort, so subscripted expressions
        // (stop[_n-1]) see the data as the user arranged it.  A rule holds
        // where the expression is true under Stata's if-qualifier semantics;
        // a review item counts the rows where its expression is true.
        local n_rule = 0
        local n_review = 0
        local rulevars ""
        foreach _fam in rule review {
            if `"``_fam''"' == "" continue
            local rest `"``_fam''"'
            // a value written in compound quotes, `"..."', is unwrapped
            mata: st_local("rest", _datacheck_unwrap(st_local("rest")))
            while `"`rest'"' != "" {
                local bs = strpos(`"`rest'"', "\")
                if `bs' {
                    local part = substr(`"`rest'"', 1, `bs' - 1)
                    local rest = substr(`"`rest'"', `bs' + 1, .)
                }
                else {
                    local part `"`rest'"'
                    local rest ""
                }
                mata: st_local("part", _datacheck_unwrap(st_local("part")))
                if `"`part'"' == "" continue
                if substr(`"`part'"', 1, 1) == char(34) {
                    local qe = strpos(substr(`"`part'"', 2, .), char(34))
                    local rlab = substr(`"`part'"', 2, `qe' - 1)
                    local rexp = strtrim(substr(`"`part'"', `qe' + 2, .))
                    if `qe' == 0 | substr(`"`rexp'"', 1, 1) != ":" {
                        display as error `"`_fam'() spec must be "label: expression": `part'"'
                        exit 198
                    }
                    local rexp = strtrim(substr(`"`rexp'"', 2, .))
                }
                else {
                    local cp = strpos(`"`part'"', ":")
                    if `cp' == 0 {
                        display as error `"`_fam'() spec must be "label: expression": `part'"'
                        exit 198
                    }
                    local rlab = strtrim(substr(`"`part'"', 1, `cp' - 1))
                    local rexp = strtrim(substr(`"`part'"', `cp' + 1, .))
                }
                local rlab = strtrim(`"`rlab'"')
                if `"`rlab'"' == "" | `"`rexp'"' == "" {
                    display as error `"`_fam'() spec must be "label: expression": `part'"'
                    exit 198
                }
                if strpos(`"`rlab'"', char(34)) | strpos(`"`rlab'"', char(96)) {
                    display as error "`_fam'() label must not contain quotes or backticks"
                    exit 198
                }
                local ++n_`_fam'
                local _k = `n_`_fam''
                tempvar `_fam'ind`_k'
                quietly gen byte ``_fam'ind`_k'' = 0
                if "`_fam'" == "rule" capture replace ``_fam'ind`_k'' = 1 if !(`rexp')
                else capture replace ``_fam'ind`_k'' = 1 if (`rexp')
                if _rc {
                    local _rrc = _rc
                    display as error `"`_fam'(`rlab'): cannot evaluate expression `rexp'"'
                    exit `_rrc'
                }
                local `_fam'_lab`_k' `"`rlab'"'
                local `_fam'_exp`_k' `"`rexp'"'
                local rulevars "`rulevars' ``_fam'ind`_k''"
                // a note, never a verdict: subscripts read the rows as arranged
                if ustrregexm(`"`rexp'"', "(\w\[|\b_n\b|\b_N\b)") {
                    local _sv ""
                    local _rest `"`rexp'"'
                    while ustrregexm(`"`_rest'"', "([A-Za-z_][A-Za-z0-9_]*)\[") {
                        local _sv "`_sv' `=ustrregexs(1)'"
                        local _rest = subinstr(`"`_rest'"', ustrregexs(0), " ", 1)
                    }
                    local _shared : list _sortedby_entry & _sv
                    if "`_sortedby_entry'" == "" | ("`_sv'" != "" & "`_shared'" == "") {
                        local _sbtxt = cond("`_sortedby_entry'" == "", "had no sort order", "was sorted by `_sortedby_entry'")
                        display as text `"  note: `_fam'(`rlab') uses subscripts or _n/_N and the data `_sbtxt' at entry, so the result depends on row order; byrule() sorts within groups"'
                    }
                }
            }
        }

        // ---- byrule(): "byvars (sortvars): label: expression" under by semantics ----
        local n_byrule = 0
        if `"`byrule'"' != "" {
            local rest `"`byrule'"'
            mata: st_local("rest", _datacheck_unwrap(st_local("rest")))
            while `"`rest'"' != "" {
                local bs = strpos(`"`rest'"', "\")
                if `bs' {
                    local part = substr(`"`rest'"', 1, `bs' - 1)
                    local rest = substr(`"`rest'"', `bs' + 1, .)
                }
                else {
                    local part `"`rest'"'
                    local rest ""
                }
                mata: st_local("part", _datacheck_unwrap(st_local("part")))
                if `"`part'"' == "" continue
                local ++n_byrule
                local _k = `n_byrule'
                tempvar byruleind`_k'
                quietly gen byte `byruleind`_k'' = 0
                _datacheck_byrule, spec(`"`part'"') ind(`byruleind`_k'')
                local byrule_lab`_k' `"`r(lab)'"'
                local byrule_exp`_k' `"`r(exp)'"'
                local rulevars "`rulevars' `byruleind`_k''"
            }
        }

        // ---- validate option varlists against the loaded data ----
        if "`exclude'"     != "" unab exclude     : `exclude'
        if "`continuous'"  != "" unab continuous  : `continuous'
        if "`categorical'" != "" unab categorical : `categorical'
        if "`date'"        != "" unab date        : `date'
        // isid(): one key, or several \-separated (checks() rows add keys)
        local n_isid = 0
        local isidvars ""
        if "`isid'" != "" {
            local rest "`isid'"
            while "`rest'" != "" {
                gettoken part rest : rest, parse("\")
                if "`part'" == "\" continue
                local part = strtrim("`part'")
                if "`part'" == "" continue
                unab part : `part'
                local ++n_isid
                local isid_key`n_isid' "`part'"
                local isidvars : list isidvars | part
            }
        }
        if "`notmissing'"  != "" unab notmissing  : `notmissing'
        if "`byvars'" != "" {
            unab byvars : `byvars'
            local byvars : list uniq byvars
            if "`over'" != "" {
                local nby : word count `byvars'
                if `nby' != 1 {
                    display as error "over() requires one variable"
                    exit 198
                }
            }
        }
        if "`binary'"      != "" {
            unab binary : `binary'
            local binary : list uniq binary
            foreach v of local binary {
                capture confirm numeric variable `v'
                if _rc {
                    display as error "binary(): `v' is not numeric"
                    exit 109
                }
            }
        }

        // ---- expectn(): an invariant, and optionally a band in bands() ----
        local n_expn = 0
        // Each source may hold several \-separated entries: expectn() and
        // every checks() expectn row are invariants, bands() and checks()
        // band rows are bands.
        foreach _src in main band {
            local rest = cond("`_src'" == "main", "`expectn'", "`b_expectn'")
            while "`rest'" != "" {
                gettoken _e rest : rest, parse("\")
                if "`_e'" == "\" continue
                local _e = strtrim("`_e'")
                if "`_e'" == "" continue
                local _nw : word count `_e'
                local _e1 : word 1 of `_e'
                local _e2 : word 2 of `_e'
                if "`_e2'" == "" local _e2 "`_e1'"
                if `_nw' > 2 | missing(real("`_e1'")) | missing(real("`_e2'")) | ///
                    real("`_e1'") != int(real("`_e1'")) | real("`_e2'") != int(real("`_e2'")) {
                    display as error "expectn: expected one or two integers; got `_e'"
                    exit 198
                }
                local ++n_expn
                local expn_lo`n_expn' "`_e1'"
                local expn_hi`n_expn' "`_e2'"
                local expn_kind`n_expn' = cond("`_src'" == "main", "invariant", "band")
                local expn_nw`n_expn' = `_nw'
            }
        }

        // ---- per-entry "if exp": evaluated now, before any sort or drop ----
        // Each entry condition becomes a 0/1 indicator (missing counts as
        // true, as under Stata's if), so its variables need not be kept.
        local n_eif = 0
        local eifvars ""

        // ---- parse stat(): "statistic var lo hi [if exp]" entries ----
        // Commas are read as spaces in the band only (before " if "), so a
        // band held as "lo, hi" can be reused and an expression such as
        // inrange(x, a, b) in the condition survives.
        local n_stat = 0
        local statvars ""
        foreach _src in main band {
            if "`_src'" == "main" local _spec `"`stat'"'
            else local _spec `"`b_stat'"'
            if `"`_spec'"' == "" continue
            local rest `"`_spec'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = strtrim(`"`part'"')
                if `"`part'"' == "" continue
                local eif ""
                local ip = strpos(`"`part'"', " if ")
                if `ip' {
                    local eif = strtrim(substr(`"`part'"', `ip' + 4, .))
                    local bpart = strtrim(substr(`"`part'"', 1, `ip' - 1))
                }
                else local bpart `"`part'"'
                local bpart = subinstr(`"`bpart'"', ",", " ", .)
                local sst = lower("`: word 1 of `bpart''")
                if "`sst'" == "median" local sst "p50"
                local isorder = inlist("`sst'", "p1", "p5", "p10", "p25", "p50") | ///
                    inlist("`sst'", "p75", "p90", "p95", "p99")
                if !`isorder' & !inlist("`sst'", "mean", "sd", "sum", "n", "distinct", "pmiss", "ess", "ratio") {
                    display as error "stat(): statistic must be mean, sd, median, p1 p5 p10 p25 p50 p75 p90 p95 p99, sum, n, distinct, pmiss, ess, or ratio; got `sst'"
                    exit 198
                }
                local need = cond("`sst'" == "ratio", 5, 4)
                local nw : word count `bpart'
                if `nw' != `need' {
                    if "`sst'" == "ratio" display as error `"stat() ratio spec must be "ratio num den lo hi [if exp]": `part'"'
                    else display as error `"stat() spec must be "statistic var lo hi [if exp]": `part'"'
                    exit 198
                }
                local sv : word 2 of `bpart'
                unab sv : `sv', max(1)
                local sden ""
                if "`sst'" == "ratio" {
                    local sden : word 3 of `bpart'
                    unab sden : `sden', max(1)
                }
                local lo : word `=`need' - 1' of `bpart'
                local hi : word `need' of `bpart'
                foreach _cv in `sv' `sden' {
                    if inlist("`sst'", "n", "distinct", "pmiss") continue
                    capture confirm numeric variable `_cv'
                    if _rc {
                        display as error "stat(): `_cv' is not numeric"
                        exit 109
                    }
                }
                _datacheck_bound `sv' `"`lo'"'
                local lo_num = r(value)
                _datacheck_bound `sv' `"`hi'"'
                local hi_num = r(value)
                if `lo_num' > `hi_num' {
                    display as error `"stat() lower bound exceeds upper bound: `part'"'
                    exit 198
                }
                local scond "1"
                if `"`eif'"' != "" {
                    local ++n_eif
                    tempvar eif`n_eif'
                    capture quietly generate byte `eif`n_eif'' = ((`eif') != 0)
                    if _rc {
                        local _erc = _rc
                        display as error `"stat(): cannot evaluate condition if `eif'"'
                        exit `_erc'
                    }
                    local scond "`eif`n_eif''"
                    local eifvars "`eifvars' `eif`n_eif''"
                }
                local ++n_stat
                local stat_st`n_stat' "`sst'"
                local stat_var`n_stat' "`sv'"
                local stat_den`n_stat' "`sden'"
                local stat_lo`n_stat' "`lo_num'"
                local stat_hi`n_stat' "`hi_num'"
                local stat_lolab`n_stat' `"`lo'"'
                local stat_hilab`n_stat' `"`hi'"'
                local stat_kind`n_stat' = cond("`_src'" == "main", "invariant", "band")
                local stat_cond`n_stat' "`scond'"
                local stat_if`n_stat' `"`eif'"'
                local statvars "`statvars' `sv' `sden'"
            }
        }

        // ---- parse inrange(): "var [var ...] lo hi" entries ----
        // Every token but the last two is a variable; a bound written "."
        // is open and is handled here, not by Stata's inrange() function.
        local n_inr = 0
        local inrvars ""
        foreach _src in main band {
            if "`_src'" == "main" local _spec `"`inrange'"'
            else local _spec `"`b_inrange'"'
            if `"`_spec'"' == "" continue
            local rest `"`_spec'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                local nw : word count `part'
                if `nw' < 3 {
                    display as error `"inrange() spec must be "var [var ...] lo hi": `part'"'
                    exit 198
                }
                local lo : word `=`nw' - 1' of `part'
                local hi : word `nw' of `part'
                local vtoks ""
                forvalues j = 1/`=`nw' - 2' {
                    local vtoks "`vtoks' `: word `j' of `part''"
                }
                unab vtoks : `vtoks'
                foreach iv of local vtoks {
                    local lo_open = (`"`lo'"' == ".")
                    local hi_open = (`"`hi'"' == ".")
                    if `lo_open' & `hi_open' {
                        display as error `"inrange(): both bounds are open: `part'"'
                        exit 198
                    }
                    local lo_num = .
                    local hi_num = .
                    if !`lo_open' {
                        _datacheck_bound `iv' `"`lo'"'
                        local lo_num = r(value)
                    }
                    if !`hi_open' {
                        _datacheck_bound `iv' `"`hi'"'
                        local hi_num = r(value)
                    }
                    if !`lo_open' & !`hi_open' & `lo_num' > `hi_num' {
                        display as error `"inrange() lower bound exceeds upper bound: `part'"'
                        exit 198
                    }
                    local ++n_inr
                    local inr_var`n_inr' "`iv'"
                    local inr_lo`n_inr'  "`lo_num'"
                    local inr_hi`n_inr'  "`hi_num'"
                    local inr_loopen`n_inr' = `lo_open'
                    local inr_hiopen`n_inr' = `hi_open'
                    local inr_lolab`n_inr' `"`lo'"'
                    local inr_hilab`n_inr' `"`hi'"'
                    local inr_kind`n_inr' = cond("`_src'" == "main", "invariant", "band")
                    local inrvars "`inrvars' `iv'"
                }
            }
        }

        // ---- parse value-domain gates: "var value [value ...]" specs ----
        local n_allowed = 0
        local n_forbid = 0
        local n_notvalues = 0
        local n_regex = 0
        local value_gatevars ""
        if `"`allowed'"' != "" {
            local rest `"`allowed'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken vv vals : part, quotes
                local vals = trim(`"`vals'"')
                if `"`vv'"' == "" | `"`vals'"' == "" {
                    display as error `"allowed() spec must be "var value [value ...]": `part'"'
                    exit 198
                }
                unab vv : `vv'
                local ++n_allowed
                local allowed_var`n_allowed' "`vv'"
                local allowed_vals`n_allowed' `"`vals'"'
                local value_gatevars "`value_gatevars' `vv'"
            }
        }
        if `"`forbid'"' != "" {
            local rest `"`forbid'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken vv vals : part, quotes
                local vals = trim(`"`vals'"')
                if `"`vv'"' == "" | `"`vals'"' == "" {
                    display as error `"forbid() spec must be "var value [value ...]": `part'"'
                    exit 198
                }
                unab vv : `vv'
                local ++n_forbid
                local forbid_var`n_forbid' "`vv'"
                local forbid_vals`n_forbid' `"`vals'"'
                local value_gatevars "`value_gatevars' `vv'"
            }
        }
        if `"`notvalues'"' != "" {
            local rest `"`notvalues'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken vv vals : part, quotes
                local vals = trim(`"`vals'"')
                if `"`vv'"' == "" | `"`vals'"' == "" {
                    display as error `"notvalues() spec must be "var value [value ...]": `part'"'
                    exit 198
                }
                unab vv : `vv'
                local ++n_notvalues
                local notvalues_var`n_notvalues' "`vv'"
                local notvalues_vals`n_notvalues' `"`vals'"'
                local value_gatevars "`value_gatevars' `vv'"
            }
        }
        if `"`regex'"' != "" {
            local rest `"`regex'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                gettoken rv rpat : part, quotes
                local rpat = trim(`"`rpat'"')
                if `"`rv'"' == "" | `"`rpat'"' == "" {
                    display as error `"regex() spec must be "var pattern": `part'"'
                    exit 198
                }
                unab rv : `rv'
                local ++n_regex
                local regex_var`n_regex' "`rv'"
                local regex_pat`n_regex' `"`rpat'"'
                local value_gatevars "`value_gatevars' `rv'"
            }
        }

        // ---- parse events(): "eventvar [if exp]: varlist [, min(#)]" ----
        local n_ev = 0
        local evvars ""
        if `"`events'"' != "" {
            local rest `"`events'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = strtrim(`"`part'"')
                if `"`part'"' == "" continue
                local cp = strpos(`"`part'"', ":")
                if `cp' == 0 {
                    display as error `"events() spec must be "eventvar [if exp]: varlist [, min(#)]": `part'"'
                    exit 198
                }
                local left = strtrim(substr(`"`part'"', 1, `cp' - 1))
                local right = strtrim(substr(`"`part'"', `cp' + 1, .))
                gettoken evv left : left
                local left = strtrim(`"`left'"')
                local eif ""
                if `"`left'"' != "" {
                    if substr(`"`left'"', 1, 3) != "if " {
                        display as error `"events() spec must be "eventvar [if exp]: varlist [, min(#)]": `part'"'
                        exit 198
                    }
                    local eif = strtrim(substr(`"`left'"', 4, .))
                }
                unab evv : `evv', max(1)
                capture confirm numeric variable `evv'
                if _rc {
                    display as error "events(): `evv' is not numeric"
                    exit 109
                }
                local eopts ""
                local cc = strpos(`"`right'"', ",")
                if `cc' {
                    local eopts = strtrim(substr(`"`right'"', `cc' + 1, .))
                    local right = strtrim(substr(`"`right'"', 1, `cc' - 1))
                }
                unab ecovs : `right'
                local emin = 1
                if `"`eopts'"' != "" {
                    if regexm(`"`eopts'"', "^min\(([^)]*)\)$") local emin = real(strtrim(regexs(1)))
                    else {
                        display as error `"events(): the only suboption is min(#): `part'"'
                        exit 198
                    }
                    if missing(`emin') | `emin' < 0 {
                        display as error "events(): min() must be a non-negative number"
                        exit 198
                    }
                }
                foreach v of local ecovs {
                    tempvar _lt
                    quietly egen byte `_lt' = tag(`v') if !missing(`v')
                    quietly count if `_lt' == 1
                    local _nl = r(N)
                    quietly drop `_lt'
                    if `_nl' > `maxcat' {
                        local _nls = strtrim(string(`_nl', "%20.0fc"))
                        display as error "events(): `v' has `_nls' levels; list categorical covariates (maxcat(`maxcat'))"
                        exit 198
                    }
                }
                local econd "1"
                if `"`eif'"' != "" {
                    local ++n_eif
                    tempvar eif`n_eif'
                    capture quietly generate byte `eif`n_eif'' = ((`eif') != 0)
                    if _rc {
                        local _erc = _rc
                        display as error `"events(): cannot evaluate condition if `eif'"'
                        exit `_erc'
                    }
                    local econd "`eif`n_eif''"
                    local eifvars "`eifvars' `eif`n_eif''"
                }
                local ++n_ev
                local ev_var`n_ev' "`evv'"
                local ev_cond`n_ev' "`econd'"
                local ev_if`n_ev' `"`eif'"'
                local ev_covs`n_ev' "`ecovs'"
                local ev_min`n_ev' = `emin'
                local evvars "`evvars' `evv' `ecovs'"
            }
        }

        // ---- whole-sample families: each helper validates its own spec ----
        local famvars ""
        foreach _f in intervals keyset constant sets jumps {
            local nf_`_f' = 0
            if `"``_f''"' == "" continue
            local rest `"``_f''"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = strtrim(`"`part'"')
                if `"`part'"' == "" continue
                _datacheck_`_f', spec(`"`part'"') parseonly
                local famvars "`famvars' `r(vars)'"
                local ++nf_`_f'
                local _k = `nf_`_f''
                local `_f'_spec`_k' `"`part'"'
            }
        }
        // smallcells(): a publication invariant (never a band); the mask
        // threshold is the one the call resolved
        local nf_smallcells = 0
        if `"`smallcells'"' != "" {
            local rest `"`smallcells'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = strtrim(`"`part'"')
                if `"`part'"' == "" continue
                _datacheck_smallcells, spec(`"`part'"') mcell(`_maskcell') parseonly
                local famvars "`famvars' `r(vars)'"
                local ++nf_smallcells
                local _k = `nf_smallcells'
                local smallcells_spec`_k' `"`part'"'
            }
        }
        // band-capable families: kind from the declaration (coverage is
        // always a band); an entry with no threshold is a review item
        foreach _f in coverage heaping complete groupstat {
            local nf_`_f' = 0
            foreach _src in main band {
                if "`_src'" == "main" local _spec `"``_f''"'
                else local _spec `"`b_`_f''"'
                if `"`_spec'"' == "" continue
                local rest `"`_spec'"'
                while `"`rest'"' != "" {
                    gettoken part rest : rest, parse("\") quotes
                    if `"`part'"' == "\" continue
                    local part = strtrim(`"`part'"')
                    if `"`part'"' == "" continue
                    local eif ""
                    local gcond "1"
                    if "`_f'" == "groupstat" {
                        local ip = strpos(`"`part'"', " if ")
                        if `ip' {
                            local eif = strtrim(substr(`"`part'"', `ip' + 4, .))
                            local part = strtrim(substr(`"`part'"', 1, `ip' - 1))
                            local ++n_eif
                            tempvar eif`n_eif'
                            capture quietly generate byte `eif`n_eif'' = ((`eif') != 0)
                            if _rc {
                                local _erc = _rc
                                display as error `"groupstat(): cannot evaluate condition if `eif'"'
                                exit `_erc'
                            }
                            local gcond "`eif`n_eif''"
                            local eifvars "`eifvars' `eif`n_eif''"
                        }
                    }
                    _datacheck_`_f', spec(`"`part'"') parseonly
                    local famvars "`famvars' `r(vars)'"
                    local _isg = 1
                    if "`_f'" != "coverage" local _isg = r(isgate)
                    if "`_src'" == "band" & !`_isg' {
                        local _need = cond("`_f'" == "heaping", "max()", cond("`_f'" == "complete", "min()", "band()"))
                        display as error "`_f'() inside bands() needs `_need'; without it the entry is a review item"
                        exit 198
                    }
                    local ++nf_`_f'
                    local _k = `nf_`_f''
                    local `_f'_spec`_k' `"`part'"'
                    local `_f'_cond`_k' "`gcond'"
                    local `_f'_if`_k' `"`eif'"'
                    if "`_f'" == "coverage" | "`_src'" == "band" local `_f'_kind`_k' "band"
                    else local `_f'_kind`_k' "invariant"
                }
            }
        }

        // ---- parse id(): backslash-separated keys (each key = space-sep vars) ----
        local n_key = 0
        local keyvars_all ""
        local id_inferred = 0
        if `"`id'"' != "" {
            local rest `"`id'"'
            while `"`rest'"' != "" {
                gettoken part rest : rest, parse("\") quotes
                if `"`part'"' == "\" continue
                local part = trim(`"`part'"')
                if `"`part'"' == "" continue
                unab part : `part'
                local ++n_key
                local key`n_key' "`part'"
                local keyvars_all "`keyvars_all' `part'"
            }
        }

        // ---- restrict columns to the union we actually need ----
        // Fast path: gatesonly without compare(), saving() or makespec()
        // needs no classification and no profile, so only the gate columns
        // are kept, whether or not a varlist was given.  nodups compares
        // every user column, so without a varlist it keeps them all.
        local gatevars ""
        foreach L in isidvars notmissing inrvars value_gatevars byvars binary ///
            statvars rulevars eifvars evvars famvars {
            local gatevars : list gatevars | `L'
        }
        local _fast = ("`gatesonly'" != "" & `"`compare'"' == "" & ///
            `"`saving'"' == "" & `"`makespec'"' == "")
        if `_fast' {
            local unionvars `gatevars'
            // with a varlist, nodups compares the same columns as the
            // profile path (and 1.7.1): the varlist and every option varlist
            if `"`varlistspec'"' != "" {
                foreach L in profilevars exclude continuous categorical date keyvars_all {
                    local unionvars : list unionvars | `L'
                }
            }
            if "`nodups'" != "" & `"`varlistspec'"' == "" {
                // keep everything: nodups needs every column
            }
            else {
                if "`unionvars'" == "" local unionvars : word 1 of `_datavars'
                quietly keep `unionvars'
            }
        }
        else {
            local unionvars : list profilevars | exclude
            local unionvars : list unionvars | continuous
            local unionvars : list unionvars | categorical
            local unionvars : list unionvars | date
            local unionvars : list unionvars | keyvars_all
            local unionvars : list unionvars | gatevars
            if `"`varlistspec'"' != "" {
                quietly keep `unionvars'
            }
        }
        local nobs = c(N)

        local _pmasked = 0
        tempvar dc_group
        local has_groups = 0
        local group_levels ""
        if "`byvars'" != "" {
            quietly egen long `dc_group' = group(`byvars'), missing
            quietly levelsof `dc_group', local(group_levels)
            local has_groups = 1
            // each group's values (ledger form) and display label, from its
            // first row.  A blank string is (blank) on screen and [] in the
            // ledger; a numeric missing is its code (. or .a).  Never the
            // group number.
            quietly _datacheck_gtext `byvars', group(`dc_group')
            foreach gg of local group_levels {
                local group_led`gg' `"`r(led`gg')'"'
                local group_label`gg' `"`r(disp`gg')'"'
            }
        }
        // ---- by() groups whose size is withheld under maskrare ----
        // A group smaller than the mask is withheld.  A pool of one group,
        // or of fewer than the mask of rows, would be recovered as N minus
        // the shown groups, so the smallest shown group joins it until
        // neither holds.  The profile, every gate message, and the ledger's
        // n_scope all read this one set.
        local _hideg ""
        if `has_groups' & `_xmask' {
            foreach gg of local group_levels {
                quietly count if `dc_group' == `gg'
                local _gn`gg' = r(N)
                if r(N) < `_xmask' local _hideg "`_hideg' `gg'"
            }
            local _np : word count `_hideg'
            while `_np' > 0 {
                local _ps = 0
                foreach gg of local _hideg {
                    local _ps = `_ps' + `_gn`gg''
                }
                if `_np' >= 2 & `_ps' >= `_xmask' continue, break
                local _min = .
                local _add ""
                foreach gg of local group_levels {
                    if `: list gg in _hideg' continue
                    if `_gn`gg'' < `_min' {
                        local _min = `_gn`gg''
                        local _add "`gg'"
                    }
                }
                if "`_add'" == "" continue, break
                local _hideg "`_hideg' `_add'"
                local _np : word count `_hideg'
            }
        }

        if !`_fast' {
        // ---- classify via the shared engine ----
        tempfile proff
	        // `using' is required by the classifier syntax but ignored under `loaded'.
	        // cap must clear maxcat, or a censored count could misclassify.
	        local nuniq_cap = max(1000, `maxcat')
	        quietly _datamap_classify using "memory", loaded saving(`"`proff'"') ///
	            maxcat(`maxcat') exclude("`exclude'") continuous("`continuous'") ///
	            categorical("`categorical'") date("`date'") detect_binary(1) ///
	            capacity(`nuniq_cap')
        local all_vars       "`r(all_vars)'"
        local cls_continuous "`r(continuous_vars)'"
        local cls_categorical "`r(categorical_vars)'"
        local cls_date       "`r(date_vars)'"
        local cls_string     "`r(string_vars)'"
        local cls_excluded   "`r(excluded_vars)'"
        local sugg_exclude   "`r(suggested_exclude)'"

        // ---- read per-variable metadata into parallel locals ----
        // All per-variable locals are index-keyed (`m_class3', `FC3'), never
        // name-keyed (`idx_<varname>'): prefix+varname exceeds Stata's
        // 31-character macro-name limit for long variable names and errors
        // r(198).  Row index i comes from `: list posof' against `pvars'.
        tempname pframe
        frame create `pframe'
        local _pframe "`pframe'"
        local _pframe_made = 1
        local pvars ""
        frame `pframe' {
            quietly use `"`proff'"', clear
            quietly count
            local P = r(N)
            forvalues i = 1/`P' {
                local vn = varname[`i']
                local pvars "`pvars' `vn'"
                local m_class`i' = classification[`i']
                local m_type`i'  = vartype[`i']
                local m_mn`i'    = missing_n[`i']
                local m_mp`i'    = missing_pct[`i']
                local m_uv`i'    = unique_vals[`i']
                local m_uc`i'    = unique_capped[`i']
                local m_ml`i'    = max_length[`i']
                local m_qf`i'    = quality_flag[`i']
            }
        }

        // ---- final class assignment (auto classifier + manual overrides) ----
        // `FC<j>' is keyed by the variable's position j in `profilevars'.
        local f_continuous ""
        local f_categorical ""
        local f_date ""
        local f_string ""
        local f_excluded ""
        local pj = 0
        foreach v of local profilevars {
            local ++pj
            local vv "`v'"
	            local i : list posof "`v'" in pvars
	            local fc "`m_class`i''"
	            if "`fc'" != "excluded" {
	                if `: list vv in continuous'       local fc "continuous"
	                else if `: list vv in categorical' local fc "categorical"
	                else if `: list vv in date'        local fc "date"
	            }
            local f_`fc' "`f_`fc'' `v'"
            local FC`pj' "`fc'"
        }

        // ---- N and complete-case accounting on the analytical varlist ----
        // Excluded variables are withheld from the profile, so they do not
        // drive the completeness denominator.
        local nobs = c(N)
        tempvar cc
        quietly gen byte `cc' = 1
        local pj = 0
        foreach v of local profilevars {
            local ++pj
            if "`FC`pj''" == "excluded" continue
            quietly replace `cc' = 0 if missing(`v')
        }
        quietly count if `cc'
        local n_complete = r(N)
        local pct_complete = 0
        if `nobs' > 0 local pct_complete = round(100 * `n_complete' / `nobs', 0.1)

        // ---- cache issue flags and continuous summaries once ----
        local flagged_vars ""
        local constant_vars ""
        local highcard_vars ""
        local missing_vars ""
        local outlier_vars ""
        local rare_vars ""
        local pj = 0
        foreach v of local profilevars {
            local ++pj
            local fc "`FC`pj''"
            local flg ""
            local i : list posof "`v'" in pvars
            // exclude() withholds a variable from the profile: it is never
            // flagged or listed in r(missing_vars), matching MISSINGNESS.
            if "`fc'" == "excluded" {
                local flag`pj' ""
                continue
            }
            if `m_mn`i'' > 0 & `m_mn`i'' < . {
                local missing_vars "`missing_vars' `v'"
            }
            if "`fc'" == "continuous" {
                quietly summarize `v', detail
                local cN`pj' = r(N)
                local cmean`pj' = r(mean)
                local csd`pj' = r(sd)
                local cmin`pj' = r(min)
                local cp1_`pj' = r(p1)
                local cp5_`pj' = r(p5)
                local cp10_`pj' = r(p10)
                local cp25_`pj' = r(p25)
                local cp50_`pj' = r(p50)
                local cp75_`pj' = r(p75)
                local cp90_`pj' = r(p90)
                local cp95_`pj' = r(p95)
                local cp99_`pj' = r(p99)
                local cmax`pj' = r(max)
                local cvar`pj' = r(Var)
                local cnout`pj' = 0
                if r(N) > 0 & r(Var) == 0 {
                    local flg "constant"
                    local constant_vars "`constant_vars' `v'"
                }
                else if r(N) > 0 & `outliers' > 0 {
                    // Fences stay in scalars: a decimal-macro round trip can
                    // move a value sitting on a fence to the other side.
                    tempname _lof _hif
                    scalar `_lof' = r(p25) - `outliers' * (r(p75) - r(p25))
                    scalar `_hif' = r(p75) + `outliers' * (r(p75) - r(p25))
                    quietly count if (`v' < `_lof' | `v' > `_hif') & !missing(`v')
                    local cnout`pj' = r(N)
                    if r(N) > 0 {
                        local flg "outliers"
                        local outlier_vars "`outlier_vars' `v'"
                    }
                }
            }
            else if "`fc'" == "categorical" {
                _datacheck_flag `v' "`fc'" `maxcat' `rare' `outliers'
                local flg "`r(flag)'"
                if "`flg'" == "constant" local constant_vars "`constant_vars' `v'"
                else if "`flg'" == "hi-card" local highcard_vars "`highcard_vars' `v'"
                else if "`flg'" == "rare" local rare_vars "`rare_vars' `v'"
            }
            else if "`fc'" == "string" {
                if `m_uv`i'' > `maxcat' & `m_uv`i'' < . {
                    local flg "hi-card"
                    local highcard_vars "`highcard_vars' `v'"
                }
            }
            if "`flg'" == "" & `m_mn`i'' > 0 & `m_mn`i'' < . local flg "missing"
            if "`flg'" != "" local flagged_vars "`flagged_vars' `v'"
            local flag`pj' "`flg'"
        }
        // ---- one observed nonmissing level: the 1/missing flag trap ----
        // Missing values are not a level here, so a 0/1 flag delivered as
        // 1/missing is caught even though its constant flag is not set.
        local singlelevel_vars ""
        local pj = 0
        foreach v of local profilevars {
            local ++pj
            if "`FC`pj''" == "excluded" continue
            capture confirm numeric variable `v'
            if !_rc {
                quietly summarize `v', meanonly
                if r(N) > 0 & r(min) == r(max) local singlelevel_vars "`singlelevel_vars' `v'"
            }
            else {
                tempvar _sl
                quietly gen long `_sl' = _n if !missing(`v')
                quietly summarize `_sl', meanonly
                if r(N) > 0 {
                    quietly count if !missing(`v') & `v' != `v'[`r(min)']
                    if r(N) == 0 local singlelevel_vars "`singlelevel_vars' `v'"
                }
                quietly drop `_sl'
            }
        }
        local singlelevel_vars : list uniq singlelevel_vars
        local n_singlelevel : word count `singlelevel_vars'
        local flagged_vars : list uniq flagged_vars
        local constant_vars : list uniq constant_vars
        local highcard_vars : list uniq highcard_vars
        local missing_vars : list uniq missing_vars
        local outlier_vars : list uniq outlier_vars
        local rare_vars : list uniq rare_vars
        local n_flagged : word count `flagged_vars'
        local n_constant : word count `constant_vars'
        local n_highcard : word count `highcard_vars'
        local n_missing_vars : word count `missing_vars'
        local n_outlier_vars : word count `outlier_vars'
        local n_rare_vars : word count `rare_vars'

        // ---- groupwise profile summaries ----
        // Every group count below comes from one pass (_datacheck_groupmiss):
        // frame `_gframe' row gg holds n, c (complete cases) and m<j>, the
        // rows missing the j-th variable of `_gvars'.
        local group_missing_vars ""
        local _gvars ""
        if `has_groups' & "`gatesonly'" == "" {
            local pj = 0
            foreach v of local profilevars {
                local ++pj
                if "`FC`pj''" != "excluded" local _gvars "`_gvars' `v'"
            }
            local _gvars : list uniq _gvars
            tempname _gfr
            local _gframe "`_gfr'"
            // an empty `_gvars' (all excluded) still yields the n and c columns
            quietly _datacheck_groupmiss `_gvars', group(`dc_group') ///
                complete(`cc') frame(`_gframe')
            local group_missing_vars "`r(missvars)'"
            local _gframe_made = 1
        }
        local group_missing_vars : list uniq group_missing_vars
        local n_group_missing_vars : word count `group_missing_vars'

        // ===================== DISPLAY =====================
        local nv : word count `profilevars'
        if "`gatesonly'" == "" {
            _datacheck_mshare `n_complete' `nobs' `_xmask'
            local _ccs "`r(cnt)'"
            local _ccp "`r(pcttxt)'"
            if r(masked) local _pmasked = 1
            _datacheck_mcount `nobs' `_xmask'
            local _nobs_s "`r(s)'"
            if r(masked) local _pmasked = 1
            display ""
            display as text "datacheck: " as result "`_nobs_s'" as text " obs, " ///
                as result "`nv'" as text " variables profiled" ///
                as text "  (complete cases: " as result "`_ccs'" ///
                as text " = " as result "`_ccp'" as text ")"
        }

        // ---- QUICK REFERENCE ----
        if "`gatesonly'" == "" {
            display ""
            if `showflagged' display as text "QUICK REFERENCE (FLAGGED)"
            else display as text "QUICK REFERENCE"
            display as text "  " %-22s "Variable" %-12s "Class" %-9s "Type" ///
                %11s "Miss%" %9s "Unique" "  " %-10s "Flag"
            local n_shown = 0
            local pj = 0
            foreach v of local profilevars {
                local ++pj
                local flg "`flag`pj''"
                if `showflagged' & "`flg'" == "" continue
                local ++n_shown
                local i : list posof "`v'" in pvars
                local fc "`FC`pj''"
                local vt "`m_type`i''"
                local mp = `m_mp`i''
                if missing(`mp') local mp = 0
                local mps = strtrim(string(`mp', "%6.1f")) + "%"
                // an excluded variable's missingness is contents, withheld
                // as in MISSINGNESS
                if "`fc'" == "excluded" local mps "[excluded]"
                if `_xmask' {
                    // a share of a published N recovers a small count
                    local _mn = `m_mn`i''
                    if missing(`_mn') local _mn = 0
                    _datacheck_mshare `_mn' `nobs' `_xmask'
                    if r(masked) & "`fc'" != "excluded" {
                        local mps "[masked]"
                        local _pmasked = 1
                    }
                }
                _datamap_fmt_uniq `m_uv`i'' `m_uc`i''
                local uq "`r(s)'"
                local vshow = substr("`v'", 1, 21)
                display as text "  " as result %-22s "`vshow'" %-12s "`fc'" ///
                    %-9s "`vt'" %11s "`mps'" ///
                    as result %9s "`uq'" "  " %-10s "`flg'"
            }
            if `showflagged' & `n_shown' == 0 {
                display as text "  no flagged variables"
            }
        }

        // ---- CONTINUOUS ----
        if "`gatesonly'" == "" & "`f_continuous'" != "" {
            display ""
            display as text "CONTINUOUS"
            foreach v of local f_continuous {
                local pj : list posof "`v'" in profilevars
                if `showflagged' & "`flag`pj''" == "" continue
                local n = `cN`pj''
                if `n' == 0 {
                    display as text "  " as result "`v'" as text ": all missing"
                    continue
                }
                if !`_xmask' {
                    display as text "  " as result "`v'" as text ":  N=" ///
                        as result `cN`pj'' as text "  mean=" as result %10.4g `cmean`pj'' ///
                        as text "  sd=" as result %10.4g `csd`pj''
                    display as text "    min=" as result %10.4g `cmin`pj'' ///
                        as text "  p25=" as result %10.4g `cp25_`pj'' ///
                        as text "  p50=" as result %10.4g `cp50_`pj'' ///
                        as text "  p75=" as result %10.4g `cp75_`pj'' ///
                        as text "  max=" as result %10.4g `cmax`pj''
                    if "`detail'" != "" {
                        display as text "    p1=" as result %10.4g `cp1_`pj'' ///
                            as text "  p5=" as result %10.4g `cp5_`pj'' ///
                            as text "  p10=" as result %10.4g `cp10_`pj'' ///
                            as text "  p90=" as result %10.4g `cp90_`pj'' ///
                            as text "  p95=" as result %10.4g `cp95_`pj'' ///
                            as text "  p99=" as result %10.4g `cp99_`pj''
                    }
                }
                else {
                    // maskrare: p1/p99 replace min/max; each statistic is
                    // shown only when enough observations lie on both sides.
                    quietly summarize `v', detail
                    foreach _st in mean sd p1 p5 p10 p25 p50 p75 p90 p95 p99 {
                        tempname _q`_st'
                        if "`_st'" == "mean" scalar `_q`_st'' = r(mean)
                        else if "`_st'" == "sd" scalar `_q`_st'' = r(sd)
                        else scalar `_q`_st'' = r(`_st')
                    }
                    foreach _st in mean sd p1 p5 p10 p25 p50 p75 p90 p95 p99 {
                        _datacheck_qshow `v', value(`_q`_st'') mask(`_xmask') stat(`_st')
                        local _qs`_st' `"`r(s)'"'
                    }
                    _datacheck_mshare `cN`pj'' `nobs' `_xmask'
                    local _cns "`r(cnt)'"
                    if r(masked) local _pmasked = 1
                    display as text "  " as result "`v'" as text ":  N=" ///
                        as result "`_cns'" as text "  mean=" as result %10s "`_qsmean'" ///
                        as text "  sd=" as result %10s "`_qssd'"
                    display as text "    p1=" as result %10s "`_qsp1'" ///
                        as text "  p25=" as result %10s "`_qsp25'" ///
                        as text "  p50=" as result %10s "`_qsp50'" ///
                        as text "  p75=" as result %10s "`_qsp75'" ///
                        as text "  p99=" as result %10s "`_qsp99'"
                    if "`detail'" != "" {
                        display as text "    p5=" as result %10s "`_qsp5'" ///
                            as text "  p10=" as result %10s "`_qsp10'" ///
                            as text "  p90=" as result %10s "`_qsp90'" ///
                            as text "  p95=" as result %10s "`_qsp95'"
                    }
                }
                if `cvar`pj'' == 0 {
                    display as text "    " as `_em' "zero variance (constant)"
                }
                if `outliers' > 0 {
                    local nout = `cnout`pj''
                    if `nout' > 0 {
                        _datacheck_mshare `nout' `n' `_xmask'
                        local _nos "`r(cnt)'"
                        local _nop "`r(pcttxt)'"
                        local _nom = r(masked)
                        if `_nom' local _pmasked = 1
                        // a masked share is left out rather than printed
                        if `_nom' display as text "    " as `_em' "`_nos' outlier(s)" ///
                            as text " beyond " as result `outliers' as text " IQR"
                        else display as text "    " as `_em' "`_nos' outlier(s)" ///
                            as text " (" as result "`_nop'" as text ") beyond " ///
                            as result `outliers' as text " IQR"
                    }
                }
            }
        }

        // ---- CATEGORICAL ----
        if "`gatesonly'" == "" & "`f_categorical'" != "" {
            display ""
            display as text "CATEGORICAL"
            foreach v of local f_categorical {
                local pj : list posof "`v'" in profilevars
                if `showflagged' & "`flag`pj''" == "" continue
                local i : list posof "`v'" in pvars
                local nlev = `m_uv`i''
                display as text "  " as result "`v'" as text ":  " ///
                    as result `nlev' as text " levels"
                if `nlev' == 1 {
                    display as text "    " as `_em' "single level (constant)"
                }
                if `nlev' > `maxcat' {
                    display as text "    " as `_em' "level count exceeds maxcat(" ///
                        "`maxcat')" as text " — possible free-text/misclassification"
                }
                _datacheck_freq `v' `maxfreq' `rare' `_maskcell'
            }
        }

        // ---- DATE ----
        if "`gatesonly'" == "" & "`f_date'" != "" {
            display ""
            display as text "DATE"
            foreach v of local f_date {
                local pj : list posof "`v'" in profilevars
                if `showflagged' & "`flag`pj''" == "" continue
                local i : list posof "`v'" in pvars
                local vfmt : format `v'
                quietly summarize `v'
                local n = r(N)
                if `n' == 0 {
                    display as text "  " as result "`v'" as text ": all missing"
                    continue
                }
                local dmin : display `vfmt' r(min)
                local dmax : display `vfmt' r(max)
                local span = r(max) - r(min)
                // The span is in the variable's own time unit, which is days
                // only for %td; a %tm span of 19 is 19 months.
                local _vf = subinstr("`vfmt'", "%-", "%", 1)
                local span_unit "days"
                if strpos("`_vf'", "%tc") | strpos("`_vf'", "%tC") local span_unit "milliseconds"
                else if strpos("`_vf'", "%tw") local span_unit "weeks"
                else if strpos("`_vf'", "%tm") local span_unit "months"
                else if strpos("`_vf'", "%tq") local span_unit "quarters"
                else if strpos("`_vf'", "%th") local span_unit "half-years"
                else if strpos("`_vf'", "%ty") local span_unit "years"
                else if strpos("`_vf'", "%tb") local span_unit "business days"
                else if !(strpos("`_vf'", "%td") | strpos("`_vf'", "%d")) local span_unit "units"
                if !`_xmask' {
                    display as text "  " as result "`v'" as text ":  min=" ///
                        as result "`dmin'" as text "  max=" as result "`dmax'" ///
                        as text "  span=" as result `span' as text " `span_unit'  missing=" ///
                        as result `m_mn`i''
                }
                else {
                    // maskrare: p1/p99 at month precision instead of min/max
                    quietly summarize `v', detail
                    tempname _dq1 _dq99
                    scalar `_dq1' = r(p1)
                    scalar `_dq99' = r(p99)
                    _datacheck_qshow `v', value(`_dq1') mask(`_xmask') stat(p1)
                    local _dp1 `"`r(s)'"'
                    local _dok1 = r(shown)
                    _datacheck_qshow `v', value(`_dq99') mask(`_xmask') stat(p99)
                    local _dp99 `"`r(s)'"'
                    local _dspan "[suppressed]"
                    if `_dok1' & r(shown) local _dspan = strtrim(string(`_dq99' - `_dq1', "%12.0g")) + " `span_unit'"
                    _datacheck_mshare `m_mn`i'' `nobs' `_xmask'
                    local _dms "`r(cnt)'"
                    if r(masked) local _pmasked = 1
                    display as text "  " as result "`v'" as text ":  p1=" ///
                        as result "`_dp1'" as text "  p99=" as result "`_dp99'" ///
                        as text "  p1-p99 span=" as result "`_dspan'" as text "  missing=" ///
                        as result "`_dms'"
                }
                forvalues k = 1/`n_inr' {
                    if "`inr_var`k''" == "`v'" {
                        local _dlo "`inr_lo`k''"
                        local _dhi "`inr_hi`k''"
                        if "`: type `v''" == "float" {
                            local _dlo "cond(missing(float(`_dlo')), `_dlo', float(`_dlo'))"
                            local _dhi "cond(missing(float(`_dhi')), `_dhi', float(`_dhi'))"
                        }
                        local _doc ""
                        if !`inr_loopen`k'' local _doc "`v' < `_dlo'"
                        if !`inr_hiopen`k'' {
                            if "`_doc'" == "" local _doc "`v' > `_dhi'"
                            else local _doc "`_doc' | `v' > `_dhi'"
                        }
                        quietly count if (`_doc') & !missing(`v')
                        // beside the printed missing count, the rows inside
                        // the window are the complement of this count
                        _datacheck_mcount `r(N)' `_xmask' `n'
                        local _dws "`r(s)'"
                        if r(masked) local _pmasked = 1
                        display as text "    " as result "`_dws'" ///
                            as text " obs outside declared window"
                    }
                }
            }
        }

        // ---- STRING ----
        if "`gatesonly'" == "" & "`f_string'" != "" {
            display ""
            display as text "STRING"
            foreach v of local f_string {
                local pj : list posof "`v'" in profilevars
                if `showflagged' & "`flag`pj''" == "" continue
                local i : list posof "`v'" in pvars
                quietly count if `v' == ""
                local nblank = r(N)
                local ml "."
                if `m_ml`i'' < . local ml = string(`m_ml`i'', "%9.0f")
                local ml = strtrim("`ml'")
                _datamap_fmt_uniq `m_uv`i'' `m_uc`i''
                local uq "`r(s)'"
                _datacheck_mshare `nblank' `nobs' `_xmask'
                local _nbs "`r(cnt)'"
                if r(masked) local _pmasked = 1
                display as text "  " as result "`v'" as text ":  unique=" ///
                    as result "`uq'" as text "  blank=" as result "`_nbs'" ///
                    as text "  maxlen=" as result "`ml'"
                _datacheck_freq `v' `maxfreq' `rare' `_maskcell'
            }
        }

        // ---- EXCLUDED ----
        if "`gatesonly'" == "" & "`f_excluded'" != "" & !`showflagged' {
            display ""
            display as text "EXCLUDED (listed, contents withheld)"
            display as text "  " as result "`f_excluded'"
        }

        // ---- MISSINGNESS ----
        if "`gatesonly'" == "" & "`nomissing'" == "" & !`showflagged' {
            display ""
            display as text "MISSINGNESS"
            local any_miss = 0
            local pj = 0
            foreach v of local profilevars {
                local ++pj
                local i : list posof "`v'" in pvars
                if "`FC`pj''" == "excluded" continue
                if `m_mn`i'' > 0 & `m_mn`i'' < . {
                    local any_miss = 1
                    _datacheck_mshare `m_mn`i'' `nobs' `_xmask'
                    local _mms "`r(cnt)'"
                    local _mmp = cond(r(masked), "[masked]", strtrim(string(`m_mp`i'', "%4.1f")) + "%")
                    if r(masked) local _pmasked = 1
                    display as text "  " as result %-22s "`v'" as text "  " ///
                        as result "`_mms'" as text " missing  (" ///
                        as result "`_mmp'" as text ")"
                }
            }
            if !`any_miss' {
                display as text "  no missing values in profiled variables"
            }
        }

        // ---- MISSING-VALUE PATTERNS (independent of nomissing) ----
        if "`gatesonly'" == "" & "`patterns'" != "" & !`showflagged' {
            capture which datamvp
            if _rc {
                display ""
                display as text "  " as `_em' ///
                    "patterns: datamvp unavailable — skipping pattern table"
            }
            else {
                display ""
                display as text "MISSING-VALUE PATTERNS (datamvp)"
                // Excluded variables stay out of the pattern table, as they
                // stay out of MISSINGNESS.
                local _mvpvars : list profilevars - f_excluded
                // An empty varlist would make datamvp profile every variable.
                if "`_mvpvars'" == "" {
                    display as text "  (no non-excluded variables to pattern)"
                }
                else if `_xmask' capture noisily datamvp `_mvpvars', maskrare mincell(`_xmask')
                else capture noisily datamvp `_mvpvars'
                if "`_mvpvars'" != "" & _rc {
                    display as text "  " as `_em' ///
                        "patterns: datamvp could not render a table for these variables"
                }
            }
        }

        // ---- groups pooled under maskrare: the set built after by() ----
        local _pooledg ""
        if "`gatesonly'" == "" & `has_groups' & `_xmask' local _pooledg "`_hideg'"
        local _npooledg : word count `_pooledg'

        // ---- GROUPWISE SUMMARY ----
        if "`gatesonly'" == "" & `has_groups' & (!`showflagged' | `n_group_missing_vars' > 0) {
            display ""
            display as text "GROUPWISE SUMMARY"
            display as text "  by: " as result "`byvars'"
            display as text "  " %-20s "Group" %9s "N" %12s "Complete" ///
                %10s "Complete%" %9s "MissVars"
            // Under maskrare a group smaller than the mask is not shown: its
            // N, completeness and missing-variable count would describe
            // fewer than the mask of persons.  Such groups are pooled into
            // one line.
            foreach gg of local group_levels {
                local gn = _frval(`_gframe', n, `gg')
                if `: list gg in _pooledg' continue
                local gc = _frval(`_gframe', c, `gg')
                _datacheck_mshare `gc' `gn' `_xmask'
                local gcs "`r(cnt)'"
                local gpcts "`r(pcttxt)'"
                if r(masked) local _pmasked = 1
                local gmissvars ""
                local gj = 0
                foreach v of local _gvars {
                    local ++gj
                    if _frval(`_gframe', m`gj', `gg') > 0 local gmissvars "`gmissvars' `v'"
                }
                local gmissvars : list uniq gmissvars
                local gmissct : word count `gmissvars'
                if `showflagged' & `gmissct' == 0 continue
                mata: st_local("gshow", _datacheck_dshow(usubstr(st_local("group_label`gg'"), 1, 20), 20))
                display as text "  " as result `"`macval(gshow)'"' ///
                    as result %9.0f `gn' %12s "`gcs'" %10s "`gpcts'" ///
                    as result %9.0f `gmissct'
            }
            if `_npooledg' > 0 {
                display as text "  groups pooled (each <`_xmask' rows, or pooled with them): " ///
                    as result `_npooledg'
                local _pmasked = 1
            }
        }

        if "`gatesonly'" == "" & `has_groups' & `n_group_missing_vars' > 0 {
            display ""
            display as text "GROUPWISE MISSINGNESS"
            display as text "  " %-20s "Group" %-22s "Variable" ///
                %9s "Missing" %10s "Missing%"
            foreach gg of local group_levels {
                local gn = _frval(`_gframe', n, `gg')
                if `: list gg in _pooledg' continue
                foreach v of local group_missing_vars {
                    local gj : list posof "`v'" in _gvars
                    local gm = _frval(`_gframe', m`gj', `gg')
                    if `gm' == 0 continue
                    _datacheck_mshare `gm' `gn' `_xmask'
                    local gms "`r(cnt)'"
                    local gmpcts "`r(pcttxt)'"
                    if r(masked) local _pmasked = 1
                    mata: st_local("gshow", _datacheck_dshow(usubstr(st_local("group_label`gg'"), 1, 20), 20))
                    display as text "  " as result `"`macval(gshow)'"' ///
                        as result %-22s "`v'" %9s "`gms'" %10s "`gmpcts'"
                }
            }
            if `_npooledg' > 0 {
                display as text "  groups pooled (each <`_xmask' rows, or pooled with them): " ///
                    as result `_npooledg'
            }
        }

        // ---- GROUPWISE FREQUENCIES (byfreq): the CATEGORICAL and STRING tables within each by() group ----
        if "`gatesonly'" == "" & "`byfreq'" != "" & `has_groups' & !`showflagged' & ///
            `"`f_categorical' `f_string'"' != " " {
            display ""
            display as text "GROUPWISE FREQUENCIES"
            display as text "  by: " as result "`byvars'"
            foreach v in `f_categorical' `f_string' {
                display as text "  " as result "`v'" as text ":"
                foreach gg of local group_levels {
                    if `: list gg in _pooledg' continue
                    mata: st_local("_gl", _datacheck_dshow(st_local("group_label`gg'"), 0))
                    display as text "    by group " as result `"`macval(_gl)'"' as text ":"
                    _datacheck_freq `v' `maxfreq' `rare' `_maskcell' `"`dc_group' == `gg'"' "      "
                }
            }
            if `_npooledg' > 0 {
                display as text "  groups pooled (each <`_xmask' rows, or pooled with them): " ///
                    as result `_npooledg'
                local _pmasked = 1
            }
        }

        // ---- KEY STRUCTURE / UNIQUENESS ----
        if `n_key' == 0 & `"`sugg_exclude'"' != "" {
            // default to inferred identifier-like keys, one per variable
            local id_inferred = 1
            foreach v of local sugg_exclude {
                local ++n_key
                local key`n_key' "`v'"
            }
        }
        if "`gatesonly'" == "" & `n_key' > 0 & !`showflagged' {
            display ""
            display as text "KEY STRUCTURE"
            if `id_inferred' {
                display as text "  (id() not given; inferred from identifier-like names)"
            }
            local _dup_return_names ""
            forvalues k = 1/`n_key' {
                local kv "`key`k''"
                tempvar kn ktag
                quietly bysort `kv' : gen long `kn' = _N
                quietly by `kv' : gen byte `ktag' = (_n == 1)
                quietly count if `ktag'
                local ndist = r(N)
                quietly summarize `kn' if `ktag', detail
                local kmin = r(min)
                local kmed = r(p50)
                local kmax = r(max)
                quietly count if `ktag' & `kn' > 1
                local nmulti = r(N)
                // r() scalar names are capped at 32 characters; truncate the
                // key portion so long/multi-variable keys cannot error r(198).
                local kvbase = subinstr("`kv'", " ", "_", .)
                local kvkey = substr("`kvbase'", 1, 26)
                local suffix_index = 1
                while `: list kvkey in _dup_return_names' {
                    local ++suffix_index
                    local suffix "_`suffix_index'"
                    local kvkey = substr("`kvbase'", 1, 26 - length("`suffix'")) + "`suffix'"
                }
                local _dup_return_names "`_dup_return_names' `kvkey'"
                return scalar n_dup_`kvkey' = `nmulti'
                if !`_xmask' {
                    display as text "  key (" as result "`kv'" as text "):  " ///
                        as result `nobs' as text " obs, " as result `ndist' ///
                        as text " distinct, records/key min/median/max = " ///
                        as result `kmin' "/" `kmed' "/" `kmax' as text ", " ///
                        as result `nmulti' as text " key(s) with >1 record"
                }
                else {
                    // maskrare: no obs/distinct pair (their difference can be
                    // a small cell); the records-per-key maximum is shown
                    // only when at least the mask of keys share it.
                    _datacheck_mshare `ndist' `nobs' `_xmask'
                    local _kds "`r(cnt)'"
                    if r(masked) local _pmasked = 1
                    // the keys with one record are the complement of nmulti
                    // among the distinct keys printed beside it
                    _datacheck_mcount `nmulti' `_xmask' `ndist'
                    local _kms "`r(s)'"
                    if r(masked) local _pmasked = 1
                    quietly count if `ktag' & `kn' == `kmax'
                    local _kmx "`kmax'"
                    if r(N) < `_xmask' {
                        local _kmx "[suppressed]"
                        local _pmasked = 1
                    }
                    display as text "  key (" as result "`kv'" as text "):  " ///
                        as result "`_kds'" as text " distinct keys, records/key median/max = " ///
                        as result `kmed' "/" "`_kmx'" as text ", " ///
                        as result "`_kms'" as text " key(s) with >1 record"
                }
                quietly drop `kn' `ktag'
            }
        }
        }

        // ===================== GATES =====================
        // Every gate entry posts a record, passed or failed; see the column
        // list at the top of this file.
        tempname rframe
        frame create `rframe' str32 fam str10 kind byte ok strL label strL variable ///
            strL grp strL observed double obsnum strL expected double nscope ///
            strL scope strL msg double minshown byte omasked
        local _rframe "`rframe'"
        local _rframe_made = 1
        local RF "`rframe'"
        local _ks_om = 0
        local _ks_ou = 0
        local _rev_hdr = 0

        // require
        if "`require'" != "" {
            local req_missing = trim("`req_missing'")
            local rq = trim("`require'")
            local ok = ("`req_missing'" == "")
            if `ok' {
                local rl "`rq'"
                local obs "all present"
                local msg "require: `rq' present"
            }
            else {
                local rl "`req_missing'"
                local obs "missing"
                local msg "require: missing variable(s) `req_missing'"
            }
            frame post `RF' ("require") ("invariant") (`ok') ("`rl'") ("`rl'") ("") ///
                ("`obs'") (.) ("present") (`nobs') ("") ("`msg'") (.) (0)
        }

        local n_scope = 1
        local scope_if1 "1"
        local scope_lab1 ""
        if `has_groups' {
            local n_scope : word count `group_levels'
            local si = 0
            foreach gg of local group_levels {
                local ++si
                local scope_if`si' "`dc_group' == `gg'"
                // a group withheld under maskrare keeps its number: its
                // values would name a group of fewer than the mask of rows
                if `: list gg in _hideg' local scope_lab`si' "by(`byvars' group `gg')"
                else local scope_lab`si' `"by(`byvars' | `macval(group_led`gg')')"'
                local scope_hide`si' : list gg in _hideg
            }
        }

        // One sort per call for the key-based gates (F3): tag the first row
        // of each key (isid) and of each distinct row (nodups) within the
        // by() group, then count tags per scope.  Tagging per group with
        // egen re-sorted the whole file once per group.  egen tag() leaves
        // rows with a missing key untagged, so they count as duplicates, as
        // before.
        forvalues k = 1/`n_isid' {
            tempvar _istag`k'
            if `has_groups' quietly egen byte `_istag`k'' = tag(`dc_group' `isid_key`k'')
            else quietly egen byte `_istag`k'' = tag(`isid_key`k'')
        }
        if "`nodups'" != "" {
            local _dupvars `_datavars'
            if `"`varlistspec'"' != "" local _dupvars : list _datavars & unionvars
            tempvar _dfirst
            if `has_groups' quietly bysort `dc_group' `_dupvars': generate byte `_dfirst' = (_n == 1)
            else quietly bysort `_dupvars': generate byte `_dfirst' = (_n == 1)
        }

        forvalues si = 1/`n_scope' {
            local IF "`scope_if`si''"
            local GP "`scope_lab`si''"
            local PFX ""
            if "`GP'" != "" local PFX "`GP': "
            quietly count if `IF'
            local scope_n = r(N)
            _datacheck_mcount `scope_n' `_gm'
            local scope_ns "`r(s)'"
            local scope_nm = r(masked)
            local scope_nnum = r(num)
            // a withheld group's N is never printed or stored
            local scope_npost = `scope_n'
            if "`scope_hide`si''" == "1" {
                if `scope_n' >= `_gm' local scope_ns "[suppressed]"
                local scope_nm = 1
                local scope_nnum = .
                local scope_npost = .
            }

            // expectn
            forvalues k = 1/`n_expn' {
                local elo "`expn_lo`k''"
                local ehi "`expn_hi`k''"
                local ok = (`scope_n' >= `elo' & `scope_n' <= `ehi')
                if `expn_nw`k'' == 1 {
                    local exp "`elo'"
                    local msg "`PFX'expectn: expected N = `elo', observed `scope_ns'"
                }
                else {
                    local exp "[`elo', `ehi']"
                    local msg "`PFX'expectn: expected N in [`elo', `ehi'], observed `scope_ns'"
                }
                local mins = cond(`scope_nm' | `scope_n' < 1, ., `scope_n')
                frame post `RF' ("expectn") ("`expn_kind`k''") (`ok') ("") ("") (`"`GP'"') ///
                    ("`scope_ns'") (`scope_nnum') ("`exp'") (`scope_npost') ("") ("`msg'") ///
                    (`mins') (`scope_nm')
            }

            // isid.  Under maskrare the violation reports only the number
            // of duplicated rows (masked): the difference of two published
            // counts would itself be a small cell.
            forvalues k = 1/`n_isid' {
                local isid "`isid_key`k''"
                quietly count if `IF' & `_istag`k''
                local idist = r(N)
                local ndup = `scope_n' - `idist'
                local ok = (`ndup' == 0)
                _datacheck_mcount `ndup' `_gm' `scope_n'
                local nds "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = .
                if `ok' {
                    local obs "unique"
                    local msg "`PFX'isid(`isid'): unique"
                }
                else if `_gm' {
                    local obs "`nds' duplicated rows"
                    local msg "`PFX'isid(`isid'): not unique — `nds' duplicated rows"
                    if !`om' local mins = `ndup'
                }
                else {
                    local obs "`scope_n' rows, `idist' distinct"
                    local msg "`PFX'isid(`isid'): not unique — `scope_n' rows, `idist' distinct"
                    local mins = min(`ndup', `idist')
                    if `idist' < 1 local mins = `ndup'
                }
                frame post `RF' ("isid") ("invariant") (`ok') ("`isid'") ("`isid'") (`"`GP'"') ///
                    ("`obs'") (`onum') ("unique") (`scope_npost') ("") ("`msg'") (`mins') (`om')
            }

            // nodups
            if "`nodups'" != "" {
                quietly count if `IF' & `_dfirst'
                local ndup = `scope_n' - r(N)
                local ok = (`ndup' == 0)
                _datacheck_mcount `ndup' `_gm' `scope_n'
                local nds "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `ndup' < 1, ., `ndup')
                local msg "`PFX'nodups: `nds' duplicated row(s)"
                frame post `RF' ("nodups") ("invariant") (`ok') ("") ("") (`"`GP'"') ///
                    ("`nds'") (`onum') ("0 duplicated rows") (`scope_npost') ("") ("`msg'") ///
                    (`mins') (`om')
            }

            // notmissing
            foreach v of local notmissing {
                quietly count if `IF' & missing(`v')
                local nmiss = r(N)
                local ok = (`nmiss' == 0)
                _datacheck_mcount `nmiss' `_gm' `scope_n'
                local nms "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `nmiss' < 1, ., `nmiss')
                local msg "`PFX'notmissing: `v' has `nms' missing value(s)"
                frame post `RF' ("notmissing") ("invariant") (`ok') ("`v'") ("`v'") (`"`GP'"') ///
                    ("`nms' missing") (`onum') ("0 missing") (`scope_npost') ("") ("`msg'") ///
                    (`mins') (`om')
            }

            // inrange
            forvalues k = 1/`n_inr' {
                local iv "`inr_var`k''"
                local lo "`inr_lo`k''"
                local hi "`inr_hi`k''"
                // Float variables compare against the float-rounded bound;
                // a bound beyond float range stays as given (float() of it
                // is missing, which would flag every row).
                if "`: type `iv''" == "float" {
                    local lo "cond(missing(float(`lo')), `lo', float(`lo'))"
                    local hi "cond(missing(float(`hi')), `hi', float(`hi'))"
                }
                local oc ""
                if !`inr_loopen`k'' local oc "`iv' < `lo'"
                if !`inr_hiopen`k'' {
                    if "`oc'" == "" local oc "`iv' > `hi'"
                    else local oc "`oc' | `iv' > `hi'"
                }
                quietly count if `IF' & (`oc') & !missing(`iv')
                local noutr = r(N)
                local ok = (`noutr' == 0)
                local exp "[`inr_lolab`k'', `inr_hilab`k'']"
                _datacheck_mcount `noutr' `_gm' `scope_n'
                local nos "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `noutr' < 1, ., `noutr')
                if `ok' {
                    local obs "0 outside"
                    local msg "`PFX'inrange(`iv'): 0 obs outside `exp'"
                }
                else {
                    local xlo "min"
                    local xhi "max"
                    if `: list iv in exclude' {
                        // exclude() withholds contents: an extreme of an
                        // excluded identifier would print one person's value
                        local obs "`nos' outside"
                        local msg "`PFX'inrange(`iv'): `nos' obs outside `exp'  (extremes withheld: excluded)"
                    }
                    else if !`_xmask' {
                        // a date prints in its own format, as the bounds do
                        local _ivf : format `iv'
                        local _ivf = subinstr("`_ivf'", "%-", "%", 1)
                        if !(substr("`_ivf'", 1, 2) == "%t" | substr("`_ivf'", 1, 2) == "%d") local _ivf "%14.0g"
                        quietly summarize `iv' if `IF'
                        local omin = strtrim(string(r(min), "`_ivf'"))
                        local omax = strtrim(string(r(max), "`_ivf'"))
                    }
                    else {
                        // maskrare: the offending extremes are single
                        // persons; report guarded p1/p99 instead.
                        local xlo "p1"
                        local xhi "p99"
                        quietly summarize `iv' if `IF', detail
                        tempname _iq1 _iq99
                        scalar `_iq1' = r(p1)
                        scalar `_iq99' = r(p99)
                        _datacheck_qshow `iv', value(`_iq1') mask(`_xmask') ///
                            cond(`"`IF'"') stat(p1) fmt(%14.0g)
                        local omin `"`r(s)'"'
                        _datacheck_qshow `iv', value(`_iq99') mask(`_xmask') ///
                            cond(`"`IF'"') stat(p99) fmt(%14.0g)
                        local omax `"`r(s)'"'
                    }
                    if !`: list iv in exclude' {
                        local obs "`nos' outside; `xlo' `omin', `xhi' `omax'"
                        local msg "`PFX'inrange(`iv'): `nos' obs outside `exp'  (`xlo' `omin', `xhi' `omax')"
                    }
                }
                frame post `RF' ("inrange") ("`inr_kind`k''") (`ok') ("`iv'") ("`iv'") (`"`GP'"') ///
                    (`"`obs'"') (`onum') (`"`exp'"') (`scope_npost') ("") (`"`msg'"') (`mins') (`om')
            }

            // value domains: allowed, forbid, notvalues
            foreach _vg in allowed forbid notvalues {
                forvalues k = 1/`n_`_vg'' {
                    local av "``_vg'_var`k''"
                    local vals `"``_vg'_vals`k''"'
                    tempvar hit
                    quietly gen byte `hit' = 0 if `IF' & !missing(`av')
                    capture confirm numeric variable `av'
                    if !_rc {
                        // A float variable never equals the double literal
                        // 0.1; compare at the variable's own precision.
                        local _fcast = cond("`: type `av''" == "float", "float", "")
                        foreach val of local vals {
                            // an explicit missing code (. or .a-.z) in
                            // forbid() or notvalues() matches that code
                            if "`_vg'" != "allowed" & regexm(`"`val'"', "^\.[a-z]?$") {
                                quietly replace `hit' = 1 if `IF' & `av' == `val'
                            }
                            else quietly replace `hit' = 1 if `IF' & `av' == `_fcast'(`val') & !missing(`av')
                        }
                    }
                    else {
                        foreach val of local vals {
                            local sval = subinstr(`"`val'"', char(34), "", .)
                            quietly replace `hit' = 1 if `IF' & `av' == `"`sval'"' & !missing(`av')
                        }
                    }
                    if "`_vg'" == "allowed" quietly count if `IF' & !missing(`av') & `hit' == 0
                    else quietly count if `IF' & `hit' == 1
                    local nbad = r(N)
                    quietly drop `hit'
                    local ok = (`nbad' == 0)
                    _datacheck_mcount `nbad' `_gm' `scope_n'
                    local nbs "`r(s)'"
                    local onum = r(num)
                    local om = r(masked)
                    local mins = cond(`om' | `nbad' < 1, ., `nbad')
                    if "`_vg'" == "allowed" {
                        local obs "`nbs' disallowed"
                        local exp `"`vals'"'
                        local msg `"`PFX'allowed(`av'): `nbs' obs outside allowed values {`vals'}"'
                    }
                    else if "`_vg'" == "forbid" {
                        local obs "`nbs' forbidden"
                        local exp `"none of `vals'"'
                        local msg `"`PFX'forbid(`av'): `nbs' obs contain forbidden values {`vals'}"'
                    }
                    else {
                        local obs "`nbs' sentinel"
                        local exp `"none of `vals'"'
                        local msg `"`PFX'notvalues(`av'): `nbs' obs contain sentinel values {`vals'}"'
                    }
                    frame post `RF' ("`_vg'") ("invariant") (`ok') ("`av'") ("`av'") (`"`GP'"') ///
                        ("`obs'") (`onum') (`"`macval(exp)'"') (`scope_npost') ("") ///
                        (`"`macval(msg)'"') (`mins') (`om')
                }
            }

            // regex
            forvalues k = 1/`n_regex' {
                local rv "`regex_var`k''"
                local pat `"`regex_pat`k''"'
                capture confirm string variable `rv'
                if !_rc {
                    quietly count if `IF' & !missing(`rv') & !regexm(`rv', `"`pat'"')
                }
                else {
                    // a numeric value is matched as written in full: an
                    // integer in fixed notation (string() would give
                    // 1.23e+09 for a 10-digit id), otherwise at the
                    // variable's precision
                    local _rgf = cond("`: type `rv''" == "float", "%9.0g", "%16.0g")
                    quietly count if `IF' & !missing(`rv') & ///
                        !regexm(cond(`rv' == int(`rv'), string(`rv', "%21.0f"), ///
                        string(`rv', "`_rgf'")), `"`pat'"')
                }
                local nbad = r(N)
                local ok = (`nbad' == 0)
                _datacheck_mcount `nbad' `_gm' `scope_n'
                local nbs "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `nbad' < 1, ., `nbad')
                local msg `"`PFX'regex(`rv'): `nbs' obs do not match `pat'"'
                frame post `RF' ("regex") ("invariant") (`ok') ("`rv'") ("`rv'") (`"`GP'"') ///
                    ("`nbs' nonmatching") (`onum') (`"`macval(pat)'"') (`scope_npost') ("") ///
                    (`"`macval(msg)'"') (`mins') (`om')
            }

            // rule: indicators were evaluated at parse time
            forvalues k = 1/`n_rule' {
                quietly count if `IF' & `ruleind`k''
                local nbad = r(N)
                local ok = (`nbad' == 0)
                _datacheck_mcount `nbad' `_gm' `scope_n'
                local nbs "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `nbad' < 1, ., `nbad')
                local msg `"`PFX'rule(`rule_lab`k''): `nbs' obs fail `rule_exp`k''"'
                frame post `RF' ("rule") ("invariant") (`ok') (`"`rule_lab`k''"') ///
                    (`"`rule_lab`k''"') (`"`GP'"') ("`nbs' fail") (`onum') ///
                    (`"`macval(rule_exp`k')'"') (`scope_npost') ("") (`"`macval(msg)'"') (`mins') (`om')
            }

            // byrule: indicators were evaluated at parse time, under by semantics
            forvalues k = 1/`n_byrule' {
                quietly count if `IF' & `byruleind`k''
                local nbad = r(N)
                local ok = (`nbad' == 0)
                _datacheck_mcount `nbad' `_gm' `scope_n'
                local nbs "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `nbad' < 1, ., `nbad')
                local msg `"`PFX'byrule(`byrule_lab`k''): `nbs' obs fail `byrule_exp`k''"'
                frame post `RF' ("byrule") ("invariant") (`ok') (`"`byrule_lab`k''"') ///
                    (`"`byrule_lab`k''"') (`"`GP'"') ("`nbs' fail") (`onum') ///
                    (`"`macval(byrule_exp`k')'"') (`scope_npost') ("") (`"`macval(msg)'"') (`mins') (`om')
            }

            // stat: a summary statistic must fall inside a declared band
            forvalues k = 1/`n_stat' {
                local sv "`stat_var`k''"
                local sden "`stat_den`k''"
                local sst "`stat_st`k''"
                local lo "`stat_lo`k''"
                local hi "`stat_hi`k''"
                local cnd "`IF'"
                if "`stat_cond`k''" != "1" local cnd "(`IF') & `stat_cond`k''"
                _datacheck_statval `sst' `sv' `sden', cond(`"`cnd'"') mask(`_gm')
                local sn = r(n)
                local sdef = r(defined)
                local sshown = r(shown)
                local siscount = r(iscount)
                local sshow `"`r(s)'"'
                tempname sval
                scalar `sval' = r(value)
                local isorder = inlist("`sst'", "p1", "p5", "p10", "p25", "p50") | ///
                    inlist("`sst'", "p75", "p90", "p95", "p99")
                // Percentiles of a float variable are float values; compare
                // them against the float-rounded bound, as inrange() does.
                if "`: type `sv''" == "float" & `isorder' {
                    local lo "cond(missing(float(`lo')), `lo', float(`lo'))"
                    local hi "cond(missing(float(`hi')), `hi', float(`hi'))"
                }
                local iscnt = inlist("`sst'", "sum", "n", "distinct")
                if `iscnt' local ok = !(missing(`sval') | `sval' < `lo' | `sval' > `hi')
                else local ok = !(!`sdef' | missing(`sval') | `sval' < `lo' | `sval' > `hi')
                if !`sdef' {
                    if "`sst'" == "pmiss" local sshow "no rows in scope"
                    else local sshow "no nonmissing values"
                }
                local sname = cond("`sst'" == "p50", "median", "`sst'")
                local slab "`sname' `sv'"
                if "`sst'" == "ratio" local slab "ratio `sv'/`sden'"
                local onum = regexr(string(cond(`sshown' & `sdef', `sval', .), "%21x"), "^[+]", "")
                local om = !`sshown'
                local mins = .
                if `siscount' & `sshown' & `sval' >= 1 local mins = `sval'
                local iftxt ""
                if `"`stat_if`k''"' != "" local iftxt `" (if `stat_if`k'')"'
                local msg `"`PFX'stat(`slab'): `sshow', expected [`stat_lolab`k'', `stat_hilab`k'']`iftxt'"'
                frame post `RF' ("stat") ("`stat_kind`k''") (`ok') ("`slab'") ("`sv' `sden'") ///
                    (`"`GP'"') (`"`sname' `sshow'"') (`onum') ///
                    (`"[`stat_lolab`k'', `stat_hilab`k'']"') (`scope_npost') (`"`macval(stat_if`k')'"') ///
                    (`"`macval(msg)'"') (`mins') (`om')
            }

            // binary: only 0 and 1, and both observed
            foreach bv of local binary {
                quietly count if `IF' & !missing(`bv') & !inlist(`bv', 0, 1)
                local nnot = r(N)
                quietly count if `IF' & `bv' == 0
                local n0 = r(N)
                quietly count if `IF' & `bv' == 1
                local n1 = r(N)
                quietly count if `IF' & missing(`bv')
                local nmv = r(N)
                _datacheck_mcount `nnot' `_gm' `scope_n'
                local nnots "`r(s)'"
                local om1 = r(masked)
                _datacheck_mcount `nmv' `_gm' `scope_n'
                local nmvs "`r(s)'"
                local om2 = r(masked)
                local om = (`om1' | `om2')
                local bobs ""
                if `nnot' > 0 local bobs "`nnots' obs not 0/1"
                if `n0' == 0 & `n1' == 0 {
                    local bobs = trim("`bobs'" + cond("`bobs'" != "", "; ", "") + "neither 0 nor 1 observed")
                }
                else if `n0' == 0 | `n1' == 0 {
                    local _only = cond(`n0' == 0, 1, 0)
                    local bobs = trim("`bobs'" + cond("`bobs'" != "", "; ", "") + "only `_only' observed")
                }
                local ok = ("`bobs'" == "")
                local mins = .
                if !`om1' & `nnot' >= 1 local mins = `nnot'
                if !`om2' & `nmv' >= 1 local mins = min(`mins', `nmv')
                if `ok' local bobs "0 and 1 observed (`nmvs' missing)"
                else local bobs "`bobs' (`nmvs' missing)"
                local msg "`PFX'binary(`bv'): `bobs'"
                frame post `RF' ("binary") ("invariant") (`ok') ("`bv'") ("`bv'") (`"`GP'"') ///
                    ("`bobs'") (.) ("both 0 and 1, nothing else") (`scope_npost') ("") ("`msg'") ///
                    (`mins') (`om')
            }

            // events: every level of each covariate carries enough events
            forvalues k = 1/`n_ev' {
                _datacheck_events, rf(`RF') ev(`ev_var`k'') evcond(`ev_cond`k'') ///
                    vars(`ev_covs`k'') min(`ev_min`k'') cond(`IF') kind(invariant) ///
                    grp(`"`GP'"') scope(`"`ev_if`k''"') pfx(`"`PFX'"') mask(`_gm') ///
                    nscope(`scope_npost')
            }

            // review(): counted conditions, printed and never halting
            forvalues k = 1/`n_review' {
                quietly count if `IF' & `reviewind`k''
                local nr = r(N)
                _datacheck_mshare `nr' `scope_n' `_gm'
                local rc_ "`r(cnt)'"
                local rp_ "`r(pct)'"
                if "`scope_hide`si''" == "1" local rp_ "."
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `nr' < 1, ., `nr')
                if !`_rev_hdr' {
                    display ""
                    display as text "REVIEW"
                    local _rev_hdr = 1
                }
                // a masked or withheld share is left out rather than printed
                local rsh ""
                if !`om' & "`scope_hide`si''" != "1" local rsh " (`rp_'%)"
                local msg `"`PFX'review(`review_lab`k''): `rc_' of `scope_ns' rows`rsh'"'
                mata: st_local("msg", _datacheck_dshow(st_local("msg"), 0))
                display as text "  " as result `"`macval(msg)'"'
                frame post `RF' ("review") ("review") (2) (`"`review_lab`k''"') ///
                    (`"`review_lab`k''"') (`"`GP'"') ("`rc_' rows`rsh'") (`onum') ///
                    (`"`macval(review_exp`k')'"') (`scope_npost') ("") (`"`macval(msg)'"') ///
                    (`mins') (`om')
            }

            // complete(): complete cases, a review item unless min() is given
            forvalues k = 1/`nf_complete' {
                if !`_rev_hdr' {
                    display ""
                    display as text "REVIEW"
                    local _rev_hdr = 1
                }
                _datacheck_complete, spec(`"`complete_spec`k''"') rf(`RF') ///
                    kind(`complete_kind`k'') grp(`"`GP'"') pfx(`"`PFX'"') mask(`_gm') ///
                    nscope(`scope_npost') cond(`IF')
            }
        }

        // ---- whole-sample families: evaluated once on the if/in sample ----
        forvalues k = 1/`nf_intervals' {
            _datacheck_intervals, spec(`"`intervals_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_keyset' {
            _datacheck_keyset, spec(`"`keyset_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
            local _ks_om = `_ks_om' + r(only_master)
            local _ks_ou = `_ks_ou' + r(only_using)
        }
        forvalues k = 1/`nf_constant' {
            _datacheck_constant, spec(`"`constant_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_sets' {
            _datacheck_sets, spec(`"`sets_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_coverage' {
            _datacheck_coverage, spec(`"`coverage_spec`k''"') rf(`RF') kind(band) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_jumps' {
            if !`_rev_hdr' {
                display ""
                display as text "REVIEW"
                local _rev_hdr = 1
            }
            _datacheck_jumps, spec(`"`jumps_spec`k''"') rf(`RF') kind(review) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_heaping' {
            _datacheck_heaping, spec(`"`heaping_spec`k''"') rf(`RF') ///
                kind(`heaping_kind`k'') mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_groupstat' {
            _datacheck_groupstat, spec(`"`groupstat_spec`k''"') rf(`RF') ///
                kind(`groupstat_kind`k'') mask(`_gm') nscope(`nobs') ///
                cond(`groupstat_cond`k'') scope(`"`groupstat_if`k''"')
        }

        forvalues k = 1/`nf_smallcells' {
            _datacheck_smallcells, spec(`"`smallcells_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') mcell(`_maskcell') nscope(`nobs')
        }

        local compare_added ""
        local compare_dropped ""
        local compare_type_changed ""
        local compare_class_changed ""
        local compare_n_added = 0
        local compare_n_dropped = 0
        local compare_n_type_changed = 0
        local compare_n_class_changed = 0
        local compare_n_changed = 0
	        if `"`compare'"' != "" {
	            gettoken compfile comprest : compare, parse(" ,")
	            local compfile = strtrim(`"`compfile'"')
	            local compfile = subinstr(`"`compfile'"', char(34), "", .)
	            local comprest = subinstr(`"`comprest'"', char(34), "", .)
	            if trim(`"`comprest'"') != "" {
	                display as error "compare() accepts one Stata dataset filename"
	                exit 198
	            }
	            _datacheck_pathok `"`compfile'"'
	            capture confirm file `"`compfile'"'
	            if _rc {
	                capture confirm file `"`compfile'.dta"'
	                if _rc {
	                    display as error `"compare() file `compfile' not found"'
	                    exit 601
	                }
	                local compfile `"`compfile'.dta"'
	            }
	            tempname bframe
	            local _bframe "`bframe'"
	            frame create `bframe'
	            local _bframe_made = 1
	            local basevars ""
	            local base_N = .
	            frame `bframe' {
	                quietly use `"`compfile'"', clear
	                capture confirm variable variable
	                if _rc {
	                    capture confirm variable varname
	                    if !_rc rename varname variable
	                }
	                capture confirm variable variable
	                if !_rc {
	                    capture confirm variable storage_type
	                    if _rc {
	                        capture confirm variable vartype
	                        if !_rc rename vartype storage_type
	                    }
	                    capture confirm variable storage_type
	                    local has_storage = (_rc == 0)
	                    capture confirm variable class
	                    if _rc {
	                        capture confirm variable classification
	                        if !_rc rename classification class
	                    }
	                    capture confirm variable class
	                    if _rc {
	                        capture confirm variable dc_class
	                        if !_rc rename dc_class class
	                    }
	                    capture confirm variable class
	                    local has_class = (_rc == 0)
	                    capture confirm variable N
	                    local has_N = (_rc == 0)
	                    quietly count
	                    local B = r(N)
	                    if `has_N' & `B' > 0 local base_N = N[1]
	                    // `bt<k>'/`bc<k>' are keyed by position in `basevars'
	                    // (name-keyed locals overflow the 31-char macro-name
	                    // limit); duplicates are skipped on insert so positions
	                    // stay aligned.
	                    local nb = 0
	                    forvalues bi = 1/`B' {
	                        local bv = variable[`bi']
	                        if "`bv'" == "" continue
	                        if `: list bv in basevars' continue
	                        local basevars "`basevars' `bv'"
	                        local ++nb
	                        if `has_storage' local bt`nb' = storage_type[`bi']
	                        else local bt`nb' ""
	                        if `has_class' local bc`nb' = class[`bi']
	                        else local bc`nb' ""
	                    }
	                }
	                else {
	                    local base_N = _N
	                    quietly ds
	                    local basevars `r(varlist)'
	                    local nb = 0
	                    foreach bv of local basevars {
	                        local ++nb
	                        local _bt : type `bv'
	                        local bt`nb' "`_bt'"
	                        local bc`nb' ""
	                    }
	                }
	            }
	            local pj = 0
	            foreach v of local profilevars {
	                local ++pj
	                local bx : list posof "`v'" in basevars
	                if `bx' == 0 {
	                    local compare_added "`compare_added' `v'"
	                }
	                else {
	                    local i : list posof "`v'" in pvars
	                    local cur_type "`m_type`i''"
	                    local cur_class "`FC`pj''"
	                    if "`bt`bx''" != "" & "`cur_type'" != "`bt`bx''" {
	                        local compare_type_changed "`compare_type_changed' `v'"
	                    }
	                    if "`bc`bx''" != "" & "`cur_class'" != "`bc`bx''" {
	                        local compare_class_changed "`compare_class_changed' `v'"
	                    }
	                }
	            }
	            foreach bv of local basevars {
	                if !`: list bv in profilevars' {
	                    local compare_dropped "`compare_dropped' `bv'"
	                }
	            }
	            local compare_added : list uniq compare_added
	            local compare_dropped : list uniq compare_dropped
	            local compare_type_changed : list uniq compare_type_changed
	            local compare_class_changed : list uniq compare_class_changed
	            local compare_n_added : word count `compare_added'
	            local compare_n_dropped : word count `compare_dropped'
	            local compare_n_type_changed : word count `compare_type_changed'
	            local compare_n_class_changed : word count `compare_class_changed'
	            local compare_n_changed = `compare_n_added' + `compare_n_dropped' + ///
	                `compare_n_type_changed' + `compare_n_class_changed'
	            local compare_n_delta = .
	            if `base_N' < . local compare_n_delta = `nobs' - `base_N'
	            if `base_N' < . & `compare_n_delta' != 0 local compare_n_changed = `compare_n_changed' + 1

	            if "`gatesonly'" == "" {
	                display ""
	                display as text "SCHEMA COMPARE"
	                display as text "  baseline: " as result `"`compfile'"'
                if `base_N' < . {
                    // the delta of two published counts can be a small cell
                    // Any two of current N, baseline N and delta give the
                    // third, so when one is a small cell only one other is
                    // printed as a number.
                    local _cds = `compare_n_delta'
                    local _cns = `nobs'
                    local _cbs = `base_N'
                    if `_xmask' {
                        local _sd = (abs(`compare_n_delta') >= 1 & abs(`compare_n_delta') < `_xmask')
                        local _sc = (`nobs' >= 1 & `nobs' < `_xmask')
                        local _sb = (`base_N' >= 1 & `base_N' < `_xmask')
                        if `_sc' {
                            local _cns "<`_xmask'"
                            local _cds "[suppressed]"
                        }
                        if `_sb' {
                            local _cbs "<`_xmask'"
                            local _cds "[suppressed]"
                        }
                        if `_sd' {
                            local _cds "<`_xmask' (masked)"
                            if !`_sc' local _cbs "[suppressed]"
                        }
                        if `_sc' & !`_sb' & !`_sd' local _cbs "[suppressed]"
                        if `_sc' | `_sb' | `_sd' local _pmasked = 1
                    }
                    display as text "  N: current " as result "`_cns'" ///
                        as text ", baseline " as result "`_cbs'" ///
                        as text ", delta " as result "`_cds'"
                }
	                if `compare_n_added' display as text "  added: " as result "`compare_added'"
	                if `compare_n_dropped' display as text "  dropped: " as result "`compare_dropped'"
	                if `compare_n_type_changed' display as text "  type changes: " as result "`compare_type_changed'"
	                if `compare_n_class_changed' display as text "  class changes: " as result "`compare_class_changed'"
	                if `compare_n_changed' == 0 display as text "  no schema drift detected"
	            }
            local _cok = (`compare_n_changed' == 0)
            local _cobs "added `compare_n_added'; dropped `compare_n_dropped'; type `compare_n_type_changed'; class `compare_n_class_changed'"
            local _cmsg = cond(`_cok', "compare: no schema drift", "compare: schema drift detected")
            frame post `RF' ("compare") ("invariant") (`_cok') ("") ("") ("") ///
                ("`_cobs'") (`compare_n_changed') ("no schema drift") (`nobs') ("") ///
                ("`_cmsg'") (.) (0)
        }

        // ---- status of every record ----
        // A failed invariant halts unless bare warn downgrades the call; a
        // failed band halts unless warn or bandwarn is given; a review item
        // never halts.
        local _bw = ("`bandwarn'" != "")
        local _ww = ("`warn'" != "")
        frame `RF' {
            // a masked observation never keeps its number
            quietly replace obsnum = . if omasked == 1
            quietly generate str8 status = cond(ok == 2, "review", cond(ok == 1, "pass", ///
                cond(`_ww' | (kind == "band" & `_bw'), "warn", "fail")))
            quietly count if status == "fail"
            local n_err = r(N)
            quietly count if status == "warn"
            local n_warn = r(N)
            quietly count if status == "review"
            local n_rev = r(N)
            quietly count if omasked == 1
            local _anymasked = (r(N) > 0)
            local n_rec = _N
            local viol_names ""
            forvalues j = 1/`n_rec' {
                if inlist(status[`j'], "fail", "warn") local viol_names "`viol_names' `=fam[`j']'"
            }
            // gate families that ran (review items excluded), in a fixed order
            local checks_run ""
            local failed_checks ""
            foreach f in expectn isid nodups require notmissing inrange allowed forbid ///
                regex notvalues rule byrule stat binary events intervals keyset constant sets ///
                coverage heaping groupstat complete smallcells compare {
                quietly count if fam == "`f'" & kind != "review"
                if r(N) > 0 local checks_run "`checks_run' `f'"
                quietly count if fam == "`f'" & inlist(status, "fail", "warn")
                if r(N) > 0 local failed_checks "`failed_checks' `f'"
            }
        }
        local n_viol = `n_err' + `n_warn'
        local viol_names = trim("`viol_names'")
        local checks_run = trim("`checks_run'")
        local failed_checks = trim("`failed_checks'")
        local n_failed : word count `failed_checks'
        local n_checks : word count `checks_run'
        local n_passed = `n_checks' - `n_failed'
        if `n_passed' < 0 local n_passed = 0
        local n_groups = 0
        if `has_groups' local n_groups : word count `group_levels'

        // ---- violations(): structured one-row-per-failed-gate artifact ----
        if `"`violations'"' != "" {
            gettoken vdest vrest : violations, parse(" ,")
            local vreplace = 0
            if regexm(`"`vrest'"', "replace") local vreplace = 1
            tempname vframe
            local _vframe "`vframe'"
            frame copy `RF' `vframe'
            local _vframe_made = 1
            frame `vframe' {
                quietly keep if inlist(status, "fail", "warn")
                quietly {
                    generate str32 check = fam
                    generate str32 gate = fam
                    // variable keeps its 1.7 meaning: the gated variable, or
                    // the rule label; label is the family(label) label
                    replace variable = label if variable == ""
                    rename grp group
                    generate str12 severity = cond(status == "warn", "warning", "error")
                    rename msg message
                    keep check gate variable label group observed expected severity kind message
                    order check gate variable label group observed expected severity kind message
                }
            }
            local _isfile = 0
            if substr(`"`vdest'"', -4, 4) == ".dta" local _isfile = 1
            else if strpos(`"`vdest'"', "/") | strpos(`"`vdest'"', "\") local _isfile = 1
            if `_isfile' {
                _datacheck_pathok `"`vdest'"'
                if `vreplace' frame `vframe': quietly save `"`vdest'"', replace
                else          frame `vframe': quietly save `"`vdest'"'
            }
            else {
                capture confirm name `vdest'
                if _rc {
                    display as error "violations() frame name is invalid"
                    exit 198
                }
                capture frame `vdest': describe
                local _vexists = (_rc == 0)
                if `_vexists' & !`vreplace' {
                    display as error "violations() frame `vdest' already exists; specify replace"
                    exit 110
                }
                // replace on a frame that does not exist yet simply creates it
                if `_vexists' {
                    capture frame drop `vdest'
                    if _rc {
                        local _vdrc = _rc
                        display as error "violations() could not replace frame `vdest'"
                        exit `_vdrc'
                    }
                }
                frame copy `vframe' `vdest'
            }
        }

        // ---- makespec(): starter reusable check spec from observed data ----
        if `"`makespec'"' != "" {
            gettoken sdest srest : makespec, parse(" ,")
            local sreplace = 0
            if regexm(`"`srest'"', "replace") local sreplace = 1
            tempname sframe
            local _sframe "`sframe'"
            frame create `sframe'
            local _sframe_made = 1
            frame `sframe' {
                clear
                quietly generate str16 check = ""
                quietly generate str16 gate = ""
                quietly generate str80 variable = ""
                quietly generate str80 var = ""
                quietly generate str80 arg1 = ""
                quietly generate str80 arg2 = ""
                quietly generate str2045 values = ""
                quietly generate str244 pattern = ""
                quietly generate str244 note = ""
            }
            local srow = 0
            local ++srow
            frame `sframe': quietly set obs `srow'
            frame `sframe': quietly replace check = "expectn" in `srow'
            frame `sframe': quietly replace gate = "expectn" in `srow'
            frame `sframe': quietly replace arg1 = "`nobs'" in `srow'
            frame `sframe': quietly replace arg2 = "`nobs'" in `srow'
            frame `sframe': quietly replace note = "observed N" in `srow'
            local spec_key ""
            foreach v of local profilevars {
                quietly count if missing(`v')
                if r(N) > 0 continue
                capture isid `v'
                if !_rc {
                    local spec_key "`v'"
                    continue, break
                }
            }
            if "`spec_key'" != "" {
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "isid" in `srow'
                frame `sframe': quietly replace gate = "isid" in `srow'
                frame `sframe': quietly replace variable = "`spec_key'" in `srow'
                frame `sframe': quietly replace var = "`spec_key'" in `srow'
                frame `sframe': quietly replace values = "`spec_key'" in `srow'
                frame `sframe': quietly replace note = "candidate key: unique nonmissing" in `srow'
            }
            local ++srow
            frame `sframe': quietly set obs `srow'
            frame `sframe': quietly replace check = "require" in `srow'
            frame `sframe': quietly replace gate = "require" in `srow'
            frame `sframe': quietly replace values = "`profilevars'" in `srow'
            frame `sframe': quietly replace note = "profiled variables" in `srow'
            foreach v of local f_continuous {
                local pj : list posof "`v'" in profilevars
                if `cN`pj'' == 0 continue
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "inrange" in `srow'
                frame `sframe': quietly replace gate = "inrange" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                // bounds written at full precision: a rounded bound can
                // sit inside the observed range and fail the spec's own data
                quietly summarize `v'
                tempname _smn _smx
                scalar `_smn' = r(min)
                scalar `_smx' = r(max)
                local _isf = ("`: type `v''" == "float")
                _datacheck_numstr `_smn' `_isf'
                local _amin "`r(s)'"
                _datacheck_numstr `_smx' `_isf'
                local _amax "`r(s)'"
                frame `sframe': quietly replace arg1 = "`_amin'" in `srow'
                frame `sframe': quietly replace arg2 = "`_amax'" in `srow'
                frame `sframe': quietly replace note = "observed continuous range" in `srow'
            }
            foreach v of local f_date {
                quietly summarize `v'
                if r(N) == 0 continue
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "inrange" in `srow'
                frame `sframe': quietly replace gate = "inrange" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                tempname _smn _smx
                scalar `_smn' = r(min)
                scalar `_smx' = r(max)
                local _isf = ("`: type `v''" == "float")
                _datacheck_numstr `_smn' `_isf'
                local _amin "`r(s)'"
                _datacheck_numstr `_smx' `_isf'
                local _amax "`r(s)'"
                frame `sframe': quietly replace arg1 = "`_amin'" in `srow'
                frame `sframe': quietly replace arg2 = "`_amax'" in `srow'
                frame `sframe': quietly replace note = "observed date range" in `srow'
            }
            foreach v of local f_categorical {
                local i : list posof "`v'" in pvars
                if `m_uv`i'' > `maxcat' continue
                _datacheck_speclevels `v'
                if !r(ok) continue
                local _levels `"`r(levels)'"'
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "allowed" in `srow'
                frame `sframe': quietly replace gate = "allowed" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                frame `sframe': quietly replace values = `"`macval(_levels)'"' in `srow'
                frame `sframe': quietly replace note = "observed levels" in `srow'
            }
            foreach v of local f_string {
                local i : list posof "`v'" in pvars
                if `m_uv`i'' > `maxcat' continue
                _datacheck_speclevels `v'
                if !r(ok) continue
                local _levels `"`r(levels)'"'
                local ++srow
                frame `sframe': quietly set obs `srow'
                frame `sframe': quietly replace check = "allowed" in `srow'
                frame `sframe': quietly replace gate = "allowed" in `srow'
                frame `sframe': quietly replace variable = "`v'" in `srow'
                frame `sframe': quietly replace var = "`v'" in `srow'
                frame `sframe': quietly replace values = `"`macval(_levels)'"' in `srow'
                frame `sframe': quietly replace note = "observed levels" in `srow'
            }
            local _isfile = 0
            if substr(`"`sdest'"', -4, 4) == ".dta" local _isfile = 1
            else if strpos(`"`sdest'"', "/") | strpos(`"`sdest'"', "\") local _isfile = 1
            if `_isfile' {
                _datacheck_pathok `"`sdest'"'
                if `sreplace' frame `sframe': quietly save `"`sdest'"', replace
                else          frame `sframe': quietly save `"`sdest'"'
            }
            else {
                capture confirm name `sdest'
                if _rc {
                    display as error "makespec() frame name is invalid"
                    exit 198
                }
                capture frame `sdest': describe
                local _sexists = (_rc == 0)
                if `_sexists' & !`sreplace' {
                    display as error "makespec() frame `sdest' already exists; specify replace"
                    exit 110
                }
                if `_sexists' {
                    capture frame drop `sdest'
                    if _rc {
                        local _sdrc = _rc
                        display as error "makespec() could not replace frame `sdest'"
                        exit `_sdrc'
                    }
                }
                frame copy `sframe' `sdest'
            }
        }

        // ---- return surface (posted after all work succeeds) ----
        // Profile results are unset on the gatesonly fast path, which does
        // no classification; the groupwise missingness pair is unset under
        // any gatesonly.
        return scalar N              = `nobs'
        return scalar n_violations   = `n_viol'
        return scalar n_errors       = `n_err'
        return scalar n_warnings     = `n_warn'
        return scalar n_reviews      = `n_rev'
        return scalar n_checks       = `n_checks'
        return scalar n_passed       = `n_passed'
        return scalar n_failed       = `n_failed'
        return scalar n_groups       = `n_groups'
        return scalar gatesonly      = ("`gatesonly'" != "")
        return scalar onlyflagged    = (`showflagged')
        return scalar mincell        = `mincell'
        return scalar maskrare       = ("`maskrare'" != "")
        return scalar masked         = (`_anymasked' | `_pmasked')
        if !`_fast' {
            return scalar complete_cases = `n_complete'
            return scalar complete_pct   = `pct_complete'
            return scalar n_continuous   = `: word count `f_continuous''
            return scalar n_categorical  = `: word count `f_categorical''
            return scalar n_date         = `: word count `f_date''
            return scalar n_string       = `: word count `f_string''
            return scalar n_excluded     = `: word count `f_excluded''
            return scalar n_flagged      = `n_flagged'
            return scalar n_constant     = `n_constant'
            return scalar n_highcard     = `n_highcard'
            return scalar n_missing_vars = `n_missing_vars'
            return scalar n_outlier_vars = `n_outlier_vars'
            return scalar n_rare_vars    = `n_rare_vars'
            return scalar n_singlelevel  = `n_singlelevel'
            if "`gatesonly'" == "" return scalar n_group_missing_vars = `n_group_missing_vars'
            return local  continuous_vars "`f_continuous'"
            return local  categorical_vars "`f_categorical'"
            return local  date_vars      "`f_date'"
            return local  string_vars    "`f_string'"
            return local  excluded_vars  "`f_excluded'"
            return local  flagged_vars   "`flagged_vars'"
            return local  constant_vars  "`constant_vars'"
            return local  singlelevel_vars "`singlelevel_vars'"
            return local  highcard_vars  "`highcard_vars'"
            return local  missing_vars   "`missing_vars'"
            return local  outlier_vars   "`outlier_vars'"
            return local  rare_vars      "`rare_vars'"
            if "`gatesonly'" == "" return local group_missing_vars "`group_missing_vars'"
        }
        return scalar compare_added = `compare_n_added'
        return scalar compare_dropped = `compare_n_dropped'
        return scalar compare_type_changed = `compare_n_type_changed'
        return scalar compare_class_changed = `compare_n_class_changed'
        return scalar compare_changed = `compare_n_changed'
        if `nf_keyset' > 0 {
            return scalar keyset_only_master = `_ks_om'
            return scalar keyset_only_using = `_ks_ou'
        }
        return local  violations     "`viol_names'"
        return local  failed_checks  "`failed_checks'"
        return local  checks_run     "`checks_run'"
        return local  compare_added_vars "`compare_added'"
        return local  compare_dropped_vars "`compare_dropped'"
        return local  compare_type_changed_vars "`compare_type_changed'"
        return local  compare_class_changed_vars "`compare_class_changed'"
        return local  version        "`_pkgver'"
        return local  dataset        `"`_dsname'"'
        if "`signature'" != "" return local signature "`_dsig'"

        // ---- optional saving() of the per-variable profile ----
        // Non-fatal: a bad saving() path must not strand the console report or
        // the gate verdict; warn and continue instead of aborting.
	        if `"`saving'"' != "" {
	            local sspec = subinstr(`"`macval(saving)'"', char(34), "", .)
	            local scpos = strpos(`"`macval(sspec)'"', ",")
	            if `scpos' > 0 {
	                local sfile = strtrim(substr(`"`macval(sspec)'"', 1, `scpos' - 1))
	                local srest = strtrim(substr(`"`macval(sspec)'"', `scpos' + 1, .))
	            }
	            else {
	                local sfile = strtrim(`"`macval(sspec)'"')
	                local srest ""
	            }
	            local sreplace = 0
	            if regexm(lower(`"`macval(srest)'"'), "replace") local sreplace = 1
            local _bad = 0
            foreach _c in ";" "&" "|" ">" "<" "$" {
                if strpos(`"`sfile'"', "`_c'") local _bad = 1
            }
            if strpos(`"`sfile'"', char(96)) | strpos(`"`sfile'"', char(34)) local _bad = 1
            if `_bad' {
                display as text "  " as error "saving: illegal characters in path — skipped"
	            }
	            else {
	                tempfile dcmeta_tmp
	                tempname dcmeta_post
	                quietly postfile `dcmeta_post' ///
	                    str16 source_command str2045 source str2045 output ///
	                    str80 dataset str2045 dataset_label str32 variable ///
	                    str20 storage_type str32 display_format str32 value_label ///
	                    str20 class double N long nvars long missing ///
	                    double missing_pct long unique str2045 variable_label ///
	                    str2045 notes str2045 characteristics double mean double sd ///
	                    double p50 double p25 double p75 double min double max ///
	                    str2045 datasignature byte unique_capped ///
	                    using `"`dcmeta_tmp'"', replace
	                local _dcsource "memory"
	                if `"`single'"' != "" local _dcsource `"`single'"'
	                local _dclabel : data label
	                local _dcdsig ""
	                quietly capture datasignature
	                if _rc == 0 local _dcdsig `"`r(datasignature)'"'
	                _datamap_post_metadata_rows, postname(`dcmeta_post') ///
	                    classifications(`"`proff'"') sourcecommand("datacheck") ///
	                    source(`"`_dcsource'"') output("") dsname("current") ///
						nvars(`: word count `profilevars'') ///
	                    varlist(`"`profilevars'"') datasignature(`"`_dcdsig'"')
	                postclose `dcmeta_post'
	                local _isfile = 0
	                if substr(`"`sfile'"', -4, 4) == ".dta" local _isfile = 1
	                else if strpos(`"`sfile'"', "/") | strpos(`"`sfile'"', "\") local _isfile = 1
	                if `_isfile' {
	                    tempname dcsaveframe
	                    frame create `dcsaveframe'
	                    capture noisily {
	                        frame `dcsaveframe' {
	                            quietly use `"`dcmeta_tmp'"', clear
	                            quietly generate str32 varname = variable
	                            quietly generate str20 dc_class = class
	                            if `sreplace' quietly save `"`sfile'"', replace
	                            else          quietly save `"`sfile'"'
	                        }
	                    }
	                    local _dcsave_rc = _rc
		                    capture frame drop `dcsaveframe'
		                    local _dcsave_drop_rc = _rc
		                    if !inlist(`_dcsave_drop_rc', 0, 111) & !`_dcsave_rc' {
		                        local _dcsave_rc = `_dcsave_drop_rc'
		                    }
		                    if `_dcsave_rc' {
		                        display as text "  " as error "saving: could not write `sfile' — skipped"
		                    }
	                }
	                else {
	                    capture frame `sfile': describe
	                    local _sframe_exists = (_rc == 0)
	                    if `_sframe_exists' & !`sreplace' {
	                        display as text "  " as error ///
	                            "saving: frame `sfile' already exists; specify replace — skipped"
	                    }
	                    else {
	                        local _sframe_rc = 0
	                        if `sreplace' {
	                            capture frame drop `sfile'
	                            local _sframe_drop_rc = _rc
	                            if !inlist(`_sframe_drop_rc', 0, 111) local _sframe_rc = `_sframe_drop_rc'
	                        }
	                        if !`_sframe_rc' {
	                            capture frame create `sfile'
	                            local _sframe_rc = _rc
	                        }
	                        if !`_sframe_rc' {
	                            capture noisily {
	                                frame `sfile' {
	                                    quietly use `"`dcmeta_tmp'"', clear
	                                    quietly generate str32 varname = variable
	                                    quietly generate str20 dc_class = class
	                                }
	                            }
	                            local _sframe_rc = _rc
	                        }
	                        if `_sframe_rc' {
	                            display as text "  " as error "saving: could not write `sfile' — skipped"
	                        }
	                    }
	                }
            }
        }

        // ---- ledger(): one row per gate entry, appended before the verdict ----
        // A ledger failure is reported and returned after the verdict, so
        // it never hides a gate failure and never passes silently.
        if `"`_ledfile'"' != "" & `n_rec' > 0 {
            capture noisily _datacheck_ledger, rf(`RF') file(`"`_ledfile'"') ///
                run(`"`_ledrun'"') dataset(`"`_dsname'"') callscope(`"`_callscope'"') ///
                version(`_pkgver') signature(`"`_dsig'"') ///
                maskrare(`=("`maskrare'" != "")') mask(`_xmask')
            local _ledger_rc = _rc
            if !`_ledger_rc' {
                return local ledger `"`_ledfile'"'
                return scalar ledger_seq = r(seq)
            }
            else display as error `"ledger(): could not append to `_ledfile' (rc `_ledger_rc')"'
        }

        // ---- gate verdict ----
        // A passing gate run prints one PASS line naming the dataset, so a
        // clean log is distinguishable from one where the gates never ran;
        // every verdict line ends with the active masking.
        local _masktag ""
        if `_xmask' local _masktag " [masked <`_xmask']"
        local _dstag ""
        if `"`_dsname'"' != "" local _dstag `"`_dsname', "'
        local _dshead ""
        if `"`_dsname'"' != "" local _dshead `": `_dsname'"'
        if `_sessnote' display as text "note: nomaskrare overrides the session default maskrare"
        if `n_err' == 0 & `n_warn' == 0 & `n_checks' > 0 {
            _datacheck_mcount `nobs' `_xmask'
            local _Ns "`r(s)'"
            if !r(masked) local _Ns = strtrim(string(`nobs', "%20.0fc"))
            display ""
            display as text "PASS: " as result `"`_dstag'"' as result "`n_checks'" ///
                as text " gate(s) (" as result "`checks_run'" as text "), N = " ///
                as result "`_Ns'" as text ", 0 violations`_masktag'"
        }
        else if `n_checks' == 0 & `n_rev' == 0 & "`gatesonly'" != "" {
            display as text "datacheck: gatesonly with no gates declared; nothing was checked"
        }
        if `n_warn' > 0 {
            display ""
            if `_ww' display as text `"WARNINGS (`n_warn')`_dshead'`_masktag'"'
            else display as text `"BAND WARNINGS (`n_warn')`_dshead'`_masktag'"'
            frame `RF' {
                forvalues j = 1/`n_rec' {
                    if status[`j'] != "warn" continue
                    local _m = msg[`j']
                    mata: st_local("_m", _datacheck_dshow(st_local("_m"), 0))
                    display as text "  " as result `"`macval(_m)'"'
                }
            }
        }
        if `n_err' > 0 {
            display ""
            display as error `"EXPECTATION VIOLATIONS (`n_err')`_dshead'`_masktag'"'
            frame `RF' {
                forvalues j = 1/`n_rec' {
                    if status[`j'] != "fail" continue
                    local _m = msg[`j']
                    mata: st_local("_m", _datacheck_dshow(st_local("_m"), 0))
                    display as error `"  `macval(_m)'"'
                }
            }
            local _exit9 = 1
        }
    }
    local rc = _rc
    local cleanup_rc = 0
    if `_gframe_made' {
        capture frame drop `_gframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_rframe_made' {
        capture frame drop `_rframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_sframe_made' {
        capture frame drop `_sframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_vframe_made' {
        capture frame drop `_vframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_bframe_made' {
        capture frame drop `_bframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_cframe_made' {
        capture frame drop `_cframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_pframe_made' {
        capture frame drop `_pframe'
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    if `_preserved' {
        capture restore
        if _rc & !`cleanup_rc' local cleanup_rc = _rc
    }
    foreach g in S_1 S_FN S_FNDATE {
        // Mata, not -global-: a one-line -if- expands its command a second
        // time, so a saved value holding $name or `name' came back rewritten
        if `_had_`g'' mata: st_global(st_local("g"), st_local("_old_" + st_local("g")))
        else macro drop `g'
    }
    set varabbrev `_orig_varabbrev'
    if `rc' {
        // R4: a call that exits for any reason other than a gate failure
        // (rc 9) or Break (rc 1) leaves one error row in the ledger, so
        // dataqa assert cannot pass over it
        if `rc' != 9 & `rc' != 1 {
            capture noisily _datacheck_errrow `rc' `"`_dsname'"' `"`_ledfile'"' `"`_ledrun'"' `macval(_raw0)'
        }
        exit `rc'
    }
    if `_exit9' {
        // W3: under dataqa set collect with a ledger that took the rows, a
        // failed gate does not halt; dataqa assert is the halting point
        if `_collect' & `"`_ledfile'"' != "" & !`_ledger_rc' & !`cleanup_rc' {
            display as text "datacheck: " as result "`n_err'" as text " gate failure(s) recorded in the ledger; " ///
                "collect is on, so this call does not halt - dataqa assert will halt"
            exit
        }
        if `_collect' & `"`_ledfile'"' == "" {
            display as text "note: dataqa set collect has no effect without a ledger; exiting 9"
        }
        exit 9
    }
    if `_ledger_rc' exit `_ledger_rc'
    if `cleanup_rc' exit `cleanup_rc'
end

// ---------------------------------------------------------------------------
// Helpers (bundled; loaded with datacheck.ado)
// ---------------------------------------------------------------------------

capture program drop _datacheck_pathok
local _drop_pathok_rc = _rc
program define _datacheck_pathok, nclass
    // Reject shell metacharacters / quotes in user-supplied file paths.
    // char(96) = backtick, char(34) = double quote — built via char() so the
    // source string itself never contains a backtick (which would macro-expand).
    gettoken p 0 : 0
    local bad = 0
    foreach c in ";" "&" "|" ">" "<" "$" {
        if strpos(`"`p'"', "`c'") local bad = 1
    }
    if strpos(`"`p'"', char(96)) | strpos(`"`p'"', char(34)) local bad = 1
    if `bad' {
        display as error "illegal characters in path"
        exit 198
    }
end

capture program drop _datacheck_flag
local _drop_flag_rc = _rc
program define _datacheck_flag, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname fr
    local _frame_open = 0
    capture noisily {
        // Compact one-word flag for the QUICK REFERENCE table.
        args v fc maxcat rare outliers
        local flag ""
        if "`fc'" == "continuous" {
            quietly summarize `v', detail
            if r(N) > 0 & r(Var) == 0 local flag "constant"
            else if `outliers' > 0 {
                local iqr = r(p75) - r(p25)
                quietly count if (`v' < r(p25) - `outliers'*`iqr' | ///
                    `v' > r(p75) + `outliers'*`iqr') & !missing(`v')
                if r(N) > 0 local flag "outliers"
            }
        }
        else if "`fc'" == "categorical" {
            quietly levelsof `v', missing
            local nlev = r(r)
            if `nlev' == 1 local flag "constant"
            else if `nlev' > `maxcat' local flag "hi-card"
            else if `rare' > 0 {
                tempvar freq
                frame put `v', into(`fr')
                local _frame_open = 1
                frame `fr' {
                    quietly contract `v', freq(`freq')
                    quietly count if `freq' < `rare'
                    if r(N) > 0 local flag "rare"
                }
                frame drop `fr'
                local _frame_open = 0
            }
        }
        return local flag "`flag'"
    }
    local rc = _rc
    if `_frame_open' capture frame drop `fr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'

end

// Display text for a data value or value label: neutralizes everything that
// could run as a directive or break a display line.  A backtick, double
// quote and dollar sign become {char N}, a brace becomes {c -(}, and a
// control character (line feed, tab, ...) is written as \n, \t or \xHH, so
// the text prints as the literal characters.  w > 0 right-pads to w display
// columns (measured before the substitution, as %-ws would have).
capture mata: mata drop _datacheck_dshow()
capture mata: mata drop _datacheck_unwrap()
mata:
// One spec entry, trimmed, without a compound quote that wraps all of it:
// `"a": x > 0"' is "a": x > 0.  The wrapper is removed only when the `" at
// the start is closed by the "' at the end, so `"a"' \ `"b"' is kept.
string scalar _datacheck_unwrap(string scalar s0)
{
	real scalar k, L, cq
	string scalar s
	s = strtrim(s0)
	L = strlen(s)
	if (L < 4 | substr(s, 1, 2) != char(96) + char(34) | substr(s, -2, 2) != char(34) + char(39)) return(s)
	cq = 1
	k = 3
	while (k <= L & cq > 0) {
		if (substr(s, k, 2) == char(96) + char(34)) {
			cq++
			k = k + 2
		}
		else if (substr(s, k, 2) == char(34) + char(39)) {
			cq--
			k = k + 2
		}
		else k++
	}
	if (cq == 0 & k == L + 1) return(strtrim(substr(s, 3, L - 4)))
	return(s)
}

string scalar _datacheck_dshow(string scalar s, real scalar w)
{
	real scalar i, n
	string scalar out
	out = subinstr(s, char(10), char(92) + "n")
	out = subinstr(out, char(13), char(92) + "r")
	out = subinstr(out, char(9), char(92) + "t")
	for (i = 1; i <= 31; i++) {
		if (i == 9 | i == 10 | i == 13) continue
		out = subinstr(out, char(i), char(92) + "x" + substr("0123456789abcdef", floor(i / 16) + 1, 1) + substr("0123456789abcdef", mod(i, 16) + 1, 1))
	}
	n = ustrlen(out)
	out = subinstr(out, "{", "{c -(}")
	out = subinstr(out, char(96), "{char 96}")
	out = subinstr(out, char(34), "{char 34}")
	out = subinstr(out, char(36), "{char 36}")
	if (w > n) out = out + (w - n) * " "
	return(out)
}
end

capture program drop _datacheck_freq
local _drop_freq_rc = _rc
program define _datacheck_freq, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname fr
    local _frame_open = 0
    local _display = c(noisily)
    capture noisily {
        // Frequency table sorted by descending count, capped at maxfreq.
        // cond: a within-group table (rows where cond holds), printed at
        // indent ind; both empty for the pooled table
        args v maxfreq rare maskcell cond ind
        if "`maskcell'" == "" local maskcell = 0
        if `"`ind'"' == "" local ind "    "
        // Display-only: under quietly, as-error segments would still print.
        if !`_display' {
            set varabbrev `_orig_varabbrev'
            exit
        }
        tempvar freq
        if `"`cond'"' == "" frame put `v', into(`fr')
        else frame put `v' if `cond', into(`fr')
        local _frame_open = 1
        frame `fr' {
            quietly contract `v', freq(`freq')
            quietly count
            local nlev = r(N)
            quietly summarize `freq'
            local tot = r(sum)
            // ties in level order: without a tie key, equal counts came out
            // in arbitrary order, which also moved levels across the
            // maxfreq cut and the masked pool from run to run
            gsort -`freq' `v'
            local lblname : value label `v'
            local show = min(`nlev', `maxfreq')
            // Secondary suppression: the suppressed cells and the levels
            // hidden by maxfreq form a pool whose total is N minus the shown
            // cells.  When the pool holds a small cell but has one member or
            // fewer than maskcell rows, that total would recover it, so the
            // smallest shown cell joins the pool until neither holds.
            tempvar sup
            quietly generate byte `sup' = (`maskcell' > 0 & `freq' < `maskcell')
            if `maskcell' > 0 {
                quietly count if `sup'
                local _nsup = r(N)
                while `_nsup' > 0 {
                    quietly count if `sup' | _n > `show'
                    local _pn = r(N)
                    quietly summarize `freq' if `sup' | _n > `show', meanonly
                    local _ps = r(sum)
                    if `_pn' >= 2 & `_ps' >= `maskcell' continue, break
                    local _next = 0
                    forvalues r = `show'(-1)1 {
                        if !`sup'[`r'] {
                            local _next = `r'
                            continue, break
                        }
                    }
                    if `_next' == 0 continue, break
                    quietly replace `sup' = 1 in `_next'
                }
            }
            forvalues r = 1/`show' {
                local lv = `v'[`r']
                local ct = `freq'[`r']
                local pc = 100 * `ct' / `tot'
                // macval(): a string level holding a backtick or $ is data, not
                // macro syntax; re-expanding it corrupted the display line.
                local disp : copy local lv
                // A float level widened to double prints IEEE noise
                // (.1000000014901161); show it at float precision.
                if "`: type `v''" == "float" & !missing(`v'[`r']) {
                    local disp = strtrim(string(`v'[`r'], "%9.0g"))
                }
                if "`lblname'" != "" {
                    local lab : label `lblname' `lv'
                    // Mata joins the label: one holding a backtick or a quote
                    // cannot be re-read as quote syntax
                    mata: st_local("disp", st_local("disp") + (st_local("lab") != "" & st_local("lab") != st_local("lv") ? " " + st_local("lab") : ""))
                }
                local rflag ""
                if `rare' > 0 & `ct' < `rare' local rflag "  <rare"
                if `sup'[`r'] {
                    local _why = cond(`ct' < `maskcell', "suppressed (<`maskcell')", ///
                        "suppressed (complement)")
                    display as text `"`ind'"' as result %-28s "[suppressed]" ///
                        as text "  `_why'" as error "`rflag'"
                }
                else {
                    mata: st_local("disp", _datacheck_dshow(st_local("disp"), 28))
                    display as text `"`ind'"' as result `"`macval(disp)'"' ///
                        as result %9.0f `ct' as text "  (" as result %4.1f `pc' ///
                        as text "%)" as error "`rflag'"
                }
            }
            if `nlev' > `maxfreq' {
                display as text `"`ind'... "' as result `=`nlev'-`maxfreq'' ///
                    as text " more level(s) not shown (maxfreq)"
            }
        }
        frame drop `fr'
        local _frame_open = 0
    }
    local rc = _rc
    if `_frame_open' capture frame drop `fr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'

end

capture program drop _datacheck_numstr
local _drop_numstr_rc = _rc
program define _datacheck_numstr, rclass
    // The shortest %g text that reads back as the value in scalar `sc':
    // exactly for a double, at float precision for a float variable, as
    // the gates compare a float variable with float() of a bound.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args sc isfloat
        local s = strtrim(string(scalar(`sc'), "%24.17g"))
        forvalues d = 6/17 {
            local t = strtrim(string(scalar(`sc'), "%24.`d'g"))
            if `isfloat' local hit = (float(real("`t'")) == float(scalar(`sc')))
            else local hit = (real("`t'") == scalar(`sc'))
            if `hit' {
                local s "`t'"
                continue, break
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local s "`s'"
end

capture program drop _datacheck_speclevels
local _drop_speclevels_rc = _rc
program define _datacheck_speclevels, rclass
    // The nonmissing levels of one variable as an allowed() value list that
    // checks() reads back to the same set: numbers at full precision, each
    // string level in double quotes.  r(ok) is 0 when a string level holds
    // a character the list cannot carry (a double quote, a backtick, a
    // dollar sign, which the gate's macro handling would expand, or the
    // entry separator \), and the variable then gets no row.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname lf lv
    local _lf_made = 0
    local ok = 1
    local levels ""
    capture noisily {
        args v
        local isstr = (substr("`: type `v''", 1, 3) == "str")
        local isf = ("`: type `v''" == "float")
        frame put `v' if !missing(`v'), into(`lf')
        local _lf_made = 1
        frame `lf' {
            quietly duplicates drop
            quietly sort `v'
            forvalues r = 1/`=_N' {
                if `isstr' {
                    local x = `v'[`r']
                    // Mata reads the level: a level holding a backtick or quote
                    // cannot be written back inside compound quotes to test it
                    mata: st_local("_hostile", strofreal(strpos(st_local("x"), char(34)) | strpos(st_local("x"), char(96)) | strpos(st_local("x"), char(92)) | strpos(st_local("x"), char(36))))
                    if `_hostile' {
                        local ok = 0
                        continue, break
                    }
                    local levels `"`macval(levels)' "`macval(x)'""'
                }
                else {
                    scalar `lv' = `v'[`r']
                    _datacheck_numstr `lv' `isf'
                    local levels `"`macval(levels)' `r(s)'"'
                }
            }
        }
    }
    local rc = _rc
    if `_lf_made' capture frame drop `lf'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    local levels = strtrim(`"`macval(levels)'"')
    return local levels `"`macval(levels)'"'
    return scalar ok = `ok'
end

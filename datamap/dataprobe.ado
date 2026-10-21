*! dataprobe Version 1.10.6  2026/10/21
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
// (_dataprobe_events.ado and siblings) post the same columns.

program define dataprobe, rclass
    version 16.0
    // ---- minversion() probe: answered before the session is touched ----
    if regexm(strtrim(`"`macval(0)'"'), "^,[ ]*minver(s|si|sio|sion)?[ ]*\(([^)]*)\)[ ]*$") {
        local _req = strtrim(regexs(2))
        _datamap_version dataprobe, atleast(`"`_req'"')
        if !r(ok) {
            display as error "dataprobe: datamap `r(version)' is installed; version `r(required)' or later is required"
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
    mata: st_local("_nomask_explicit", strofreal(_datamap_nomask_explicit(st_local("0"))))
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
            mata: st_local("_ledrun", subinstr(_dataprobe_unwrap(st_local("_ledrun")), char(34), ""))
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
            _dataprobe_pathok `"`config'"'
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
            _datamap_version dataprobe, atleast(`"`minversion'"')
            if !r(ok) {
                display as error "dataprobe: datamap `r(version)' is installed; version `r(required)' or later is required"
                exit 198
            }
        }
        else _datamap_version dataprobe
        local _pkgver "`r(version)'"

        // ---- preserve the user's data; everything below runs on a copy ----
        preserve
        local _preserved = 1

        // ---- single(): load a saved file in place of memory ----
        if `"`single'"' != "" {
            _dataprobe_pathok `"`single'"'
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
        // the user's data as it stands: saving() writes this signature too,
        // not one of the working copy (if/in rows, kept variables, tempvars)
        local _dsig ""
        if "`signature'" != "" {
            quietly datasignature
            local _dsig "`r(datasignature)'"
        }
        else if `"`saving'"' != "" {
            quietly capture datasignature
            if _rc == 0 local _dsig "`r(datasignature)'"
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
            _dataprobe_pathok `"`cfile'"'
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
            _dataprobe_bandsparse `macval(bands)'
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
        // The user's columns, before any dataprobe tempvar exists: nodups
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
            mata: st_local("rest", _dataprobe_unwrap(st_local("rest")))
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
                mata: st_local("part", _dataprobe_unwrap(st_local("part")))
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
            mata: st_local("rest", _dataprobe_unwrap(st_local("rest")))
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
                mata: st_local("part", _dataprobe_unwrap(st_local("part")))
                if `"`part'"' == "" continue
                local ++n_byrule
                local _k = `n_byrule'
                tempvar byruleind`_k'
                quietly gen byte `byruleind`_k'' = 0
                _dataprobe_byrule, spec(`"`part'"') ind(`byruleind`_k'')
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
                if real("`_e1'") > real("`_e2'") {
                    display as error "expectn: lower bound exceeds upper bound; got `_e'"
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
                _dataprobe_bound `sv' `"`lo'"'
                local lo_num = regexr(strofreal(r(value), "%21x"), "^[+]", "")
                _dataprobe_bound `sv' `"`hi'"'
                local hi_num = regexr(strofreal(r(value), "%21x"), "^[+]", "")
                // a lower bound of . is not open in stat(): it used to be
                // reported as exceeding the upper bound
                if missing(`lo_num') {
                    display as error `"stat() lower bound is missing; give a number: `part'"'
                    exit 198
                }
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
                        _dataprobe_bound `iv' `"`lo'"'
                        local lo_num = regexr(strofreal(r(value), "%21x"), "^[+]", "")
                    }
                    if !`hi_open' {
                        _dataprobe_bound `iv' `"`hi'"'
                        local hi_num = regexr(strofreal(r(value), "%21x"), "^[+]", "")
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
                _dataprobe_`_f', spec(`"`part'"') parseonly
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
                _dataprobe_smallcells, spec(`"`part'"') mcell(`_maskcell') parseonly
                local famvars "`famvars' `r(vars)'"
                local ++nf_smallcells
                local _k = `nf_smallcells'
                local smallcells_spec`_k' `"`part'"'
            }
        }
        // band-capable families: kind from the declaration (coverage is
        // always a band); an entry with no threshold is a review item
        local _gsv ""
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
                    _dataprobe_`_f', spec(`"`part'"') parseonly
                    local famvars "`famvars' `r(vars)'"
                    // the variables of a groupstat() entry (the linked-count
                    // audit reads its n and 0/1 sum cells)
                    if "`_f'" == "groupstat" local _gsv "`_gsv' `r(vars)'"
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
            quietly _dataprobe_gtext `byvars', group(`dc_group')
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
            _dataprobe_poolfill `dc_group', mask(`_xmask')
            local _hideg "`r(pooled)'"
        }

        // ---- value-domain hits over all rows ----
        // allowed()/forbid()/notvalues() rows, marked once: the scope loop
        // counts them per group, and the pooled-remainder test below needs
        // the same rows over the whole call.
        foreach _vg in allowed forbid notvalues {
            forvalues k = 1/`n_`_vg'' {
                local av "``_vg'_var`k''"
                local vals `"``_vg'_vals`k''"'
                tempvar _vh
                local _vhit_`_vg'`k' "`_vh'"
                quietly gen byte `_vh' = 0 if !missing(`av')
                capture confirm numeric variable `av'
                if !_rc {
                    // A float variable never equals the double literal
                    // 0.1; compare at the variable's own precision.
                    local _fcast = cond("`: type `av''" == "float", "float", "")
                    foreach val of local vals {
                        // an explicit missing code (. or .a-.z) in
                        // forbid() or notvalues() matches that code
                        if "`_vg'" != "allowed" & regexm(`"`val'"', "^\.[a-z]?$") {
                            quietly replace `_vh' = 1 if `av' == `val'
                        }
                        else quietly replace `_vh' = 1 if `av' == `_fcast'(`val') & !missing(`av')
                    }
                }
                else {
                    // only a wrapping pair of quotes is dropped: removing
                    // every quote made a value such as x"y unmatchable.
                    // The value travels as a string scalar, never as
                    // quoted text in the expression.
                    tempname _sval
                    foreach val of local vals {
                        mata: _dataprobe_valscalar("val", "`_sval'")
                        quietly replace `_vh' = 1 if `av' == scalar(`_sval') & !missing(`av')
                    }
                    capture scalar drop `_sval'
                }
                // the rows the gate counts
                if "`_vg'" == "allowed" quietly replace `_vh' = (!missing(`av') & `_vh' == 0)
                else quietly replace `_vh' = (`_vh' == 1)
            }
        }

        // set below, in profile mode with by() under maskrare
        local _pfon = 0

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
                tempname _cs`pj'
                matrix `_cs`pj'' = (r(mean), r(sd), r(p1), r(p5), r(p10), r(p25), r(p50), r(p75), r(p90), r(p95), r(p99))
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
                _dataprobe_flag `v' "`fc'" `maxcat' `rare' `outliers'
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
        // Every group count below comes from one pass (_dataprobe_groupmiss):
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
            quietly _dataprobe_groupmiss `_gvars', group(`dc_group') ///
                complete(`cc') frame(`_gframe')
            local group_missing_vars "`r(missvars)'"
            local _gframe_made = 1
        }
        local group_missing_vars : list uniq group_missing_vars
        local n_group_missing_vars : word count `group_missing_vars'

        // ---- pooled remainder across the whole output ----
        // Under maskrare with by(), a count printed per group (a GROUPWISE
        // cell, a byfreq cell, or a per-group gate count) has a total printed
        // elsewhere: a variable's missing count (QUICK REFERENCE,
        // MISSINGNESS), the complete cases (header), a level's count (the
        // pooled frequency table), a date's rows outside its window (DATE).
        // The total minus the counts printed exactly is the pooled-away
        // groups' and the masked cells' share; 1 to m-1 of it gives a small
        // cell back.  One test per counted quantity (_dataprobe_premask)
        // names the group to withhold, and every place that prints that
        // quantity per group reads the same list _hX: the group
        // withheld by the test, and the groups whose byfreq cell for those
        // rows is suppressed (the same count, printed in another block).
        // Each pass proposes the withheld counts below, then audits them
        // together (_dataprobe_linkaudit); a group the audit names joins
        // the pooled groups and the pass is repeated.
        local _pfon = ("`gatesonly'" == "" & `has_groups' & `_xmask' > 0)
        local _aud_go = `_pfon'
        local _revlk ""
        if `_pfon' & `n_review' > 0 {
            local _rvi ""
            forvalues k = 1/`n_review' {
                local _rvi "`_rvi' `reviewind`k''"
            }
            _dataprobe_revlinks "`_rvi'" "`f_categorical' `f_string'" "`profilevars'"
        }
        local _aud_cap = 0
        local _aud_bud ""
        // the rows in group order, for the per-group counts of the pass
        if `_pfon' {
            tempvar _gord
            mata: st_store(., st_addvar("long", st_local("_gord")), order(st_data(., st_local("dc_group")), 1))
        }
        local _aud_tv ""
        while `_aud_go' {
            tempvar _pind
            quietly generate byte `_pind' = 0
            local _aud_tv "`_aud_tv' `_pind'"
            // per-group displays that print a variable's missing count or
            // its complement (stat n/pmiss, complete() of one variable,
            // groupstat() cells) and the ones a gate prints for pooled groups
            local _pmv ""
            local _gmv "`notmissing' `binary'"
            // missing, per profiled variable (index i in pvars)
            foreach v of local profilevars {
                local i : list posof "`v'" in pvars
                local pj : list posof "`v'" in profilevars
                if "`FC`pj''" == "excluded" continue
                quietly replace `_pind' = missing(`v')
                _dataprobe_premask `dc_group' `_pind' `_xmask' "`_hideg'" `_gord'
                local _hm`i' "`r(force)'"
            }
            // incomplete rows over the profile (the header's complete cases)
            quietly replace `_pind' = !`cc'
            _dataprobe_premask `dc_group' `_pind' `_xmask' "`_hideg'" `_gord'
            local _hc "`r(force)'"
            // inrange() on a profiled date: the DATE block prints the rows
            // outside the window
            forvalues k = 1/`n_inr' {
                local _hi`k' ""
                local _iw`k' ""
                local iv "`inr_var`k''"
                if !`: list iv in f_date' continue
                local _dlo "`inr_lo`k''"
                local _dhi "`inr_hi`k''"
                if "`: type `iv''" == "float" {
                    local _dlo "cond(missing(float(`_dlo')), `_dlo', float(`_dlo'))"
                    local _dhi "cond(missing(float(`_dhi')), `_dhi', float(`_dhi'))"
                }
                local _doc "0"
                if !`inr_loopen`k'' local _doc "`iv' < `_dlo'"
                if !`inr_hiopen`k'' local _doc "(`_doc') | `iv' > `_dhi'"
                tempvar _iw`k'
                quietly generate byte `_iw`k'' = (`_doc') & !missing(`iv')
                local _aud_tv "`_aud_tv' `_iw`k''"
                _dataprobe_premask `dc_group' `_iw`k'' `_xmask' "`_hideg'" `_gord'
                local _hi`k' "`r(force)'"
            }
            // review() conditions whose total prints elsewhere
            foreach k of local _revlk {
                _dataprobe_premask `dc_group' `reviewind`k'' `_xmask' "`_hideg'" `_gord'
                local _hr`k' "`r(force)'"
            }
            // value domains and binary() of a variable with a frequency
            // table: a level's count, or a sum of them
            foreach _vg in allowed forbid notvalues {
                forvalues k = 1/`n_`_vg'' {
                    local _hv_`_vg'`k' ""
                    local _hvon_`_vg'`k' = 0
                    local av "``_vg'_var`k''"
                    if !`: list av in f_categorical' & !`: list av in f_string' continue
                    local _hvon_`_vg'`k' = 1
                    _dataprobe_premask `dc_group' `_vhit_`_vg'`k'' `_xmask' "`_hideg'" `_gord'
                    local _hv_`_vg'`k' "`r(force)'"
                }
            }
            local j = 0
            foreach bv of local binary {
                local ++j
                local _hb`j' ""
                if !`: list bv in f_categorical' continue
                quietly replace `_pind' = !missing(`bv') & !inlist(`bv', 0, 1)
                _dataprobe_premask `dc_group' `_pind' `_xmask' "`_hideg'" `_gord'
                local _hb`j' "`r(force)'"
            }
            // stat(sum) of a 0/1 variable is the count of its ones
            forvalues k = 1/`n_stat' {
                local _hs`k' ""
                local _hss`k' = 0
                local sv "`stat_var`k''"
                if "`stat_st`k''" != "sum" | "`stat_cond`k''" != "1" continue
                if !`: list sv in f_categorical' continue
                quietly count if !missing(`sv') & !inlist(`sv', 0, 1)
                if r(N) > 0 continue
                local _hss`k' = 1
                quietly replace `_pind' = (`sv' == 1)
                _dataprobe_premask `dc_group' `_pind' `_xmask' "`_hideg'" `_gord'
                local _hs`k' "`r(force)'"
            }

            // byfreq: each table starts from the withheld groups above (the
            // missing level, the value-domain and binary rows), and each
            // list then takes in the groups whose byfreq cell for its rows
            // is suppressed, so a count withheld in one block is never
            // printed in another
            if "`byfreq'" != "" & `_maskcell' > 0 {
                tempvar _bx
                local _aud_tv "`_aud_tv' `_bx'"
                foreach v in `f_categorical' `f_string' {
                    local i : list posof "`v'" in pvars
                    capture drop `_bx'
                    quietly generate byte `_bx' = 0
                    foreach gg of local _hm`i' {
                        quietly replace `_bx' = 1 if missing(`v') & `dc_group' == `gg'
                    }
                    foreach _vg in allowed forbid notvalues {
                        forvalues k = 1/`n_`_vg'' {
                            if "``_vg'_var`k''" != "`v'" | "`_hv_`_vg'`k''" == "" continue
                            foreach gg of local _hv_`_vg'`k' {
                                quietly replace `_bx' = 1 if `_vhit_`_vg'`k'' == 1 & `dc_group' == `gg'
                            }
                        }
                    }
                    local j = 0
                    foreach bv of local binary {
                        local ++j
                        if "`bv'" != "`v'" | "`_hb`j''" == "" continue
                        foreach gg of local _hb`j' {
                            quietly replace `_bx' = 1 if !missing(`bv') & !inlist(`bv', 0, 1) & `dc_group' == `gg'
                        }
                    }
                    forvalues k = 1/`n_stat' {
                        if "`stat_var`k''" != "`v'" | "`_hs`k''" == "" continue
                        foreach gg of local _hs`k' {
                            quietly replace `_bx' = 1 if `v' == 1 & `dc_group' == `gg'
                        }
                    }
                    tempvar _bff
                    local _bffv`i' "`_bff'"
                    local _aud_tv "`_aud_tv' `_bff'"
                    _dataprobe_bfforce `v' `dc_group' `maxfreq' `_maskcell' ///
                        `"`_hideg'"' `_bff' `_bx'
                    // the byfreq groups of each list's rows
                    quietly levelsof `dc_group' if missing(`v') & `_bff' == 1, local(_gl)
                    local _hm`i' : list _hm`i' | _gl
                    foreach _vg in allowed forbid notvalues {
                        forvalues k = 1/`n_`_vg'' {
                            if "``_vg'_var`k''" != "`v'" continue
                            quietly levelsof `dc_group' if `_vhit_`_vg'`k'' == 1 & `_bff' == 1, local(_gl)
                            local _hv_`_vg'`k' : list _hv_`_vg'`k' | _gl
                        }
                    }
                    local j = 0
                    foreach bv of local binary {
                        local ++j
                        if "`bv'" != "`v'" continue
                        quietly levelsof `dc_group' if !missing(`bv') & !inlist(`bv', 0, 1) & `_bff' == 1, local(_gl)
                        local _hb`j' : list _hb`j' | _gl
                    }
                    forvalues k = 1/`n_stat' {
                        if "`stat_var`k''" != "`v'" | "`stat_st`k''" != "sum" | "`stat_cond`k''" != "1" continue
                        quietly levelsof `dc_group' if `v' == 1 & `_bff' == 1, local(_gl)
                        local _hs`k' : list _hs`k' | _gl
                    }
                }
            }
            // a one-variable profile: its complete count is N minus its
            // missing count
            if `: word count `_gvars'' == 1 {
                local i : list posof "`_gvars'" in pvars
                local _hc : list _hc | _hm`i'
            }
            // complete() and stat(n)/stat(pmiss) per group: complete over the
            // profile is the header's quantity; over one variable, and n and
            // pmiss of one, it is that variable's missing count
            forvalues k = 1/`nf_complete' {
                local _hcc`k' ""
                local _ccv`k' ""
                local _cs `"`complete_spec`k''"'
                local _cp = strpos(`"`_cs'"', ",")
                if `_cp' local _cs = substr(`"`_cs'"', 1, `_cp' - 1)
                capture unab _cv : `_cs'
                if _rc continue
                local _cv : list uniq _cv
                local _ccv`k' "`_cv'"
                if `: word count `_cv'' == 1 {
                    local i : list posof "`_cv'" in pvars
                    if `i' > 0 local _hcc`k' "`_hm`i''"
                }
                else if `: list _cv === _gvars' local _hcc`k' "`_hc'"
            }
            forvalues k = 1/`n_stat' {
                if !inlist("`stat_st`k''", "n", "pmiss") | "`stat_cond`k''" != "1" continue
                local i : list posof "`stat_var`k''" in pvars
                if `i' > 0 local _hs`k' "`_hm`i''"
                local _pmv "`_pmv' `stat_var`k''"
                local _gmv "`_gmv' `stat_var`k''"
            }
            // groupstat() with the call's by(): its n and pmiss cells give
            // back the missing count beside the GROUPWISE N, and a sum of a
            // 0/1 variable the count of ones, so the rows of the withheld
            // groups are flagged for it
            local _gsmh ""
            local _gsfh ""
            foreach v of local profilevars {
                local i : list posof "`v'" in pvars
                if "`_hm`i''" != "" {
                    tempvar _mf
                    quietly generate byte `_mf' = 0
                    local _aud_tv "`_aud_tv' `_mf'"
                    foreach gg of local _hm`i' {
                        quietly replace `_mf' = 1 if `dc_group' == `gg'
                    }
                    local _gsmh "`_gsmh' `v' `_mf'"
                }
                if "`_bffv`i''" != "" local _gsfh "`_gsfh' `v' `_bffv`i''"
            }

            // ---- the joint audit of every count above ----
            // records kind|vars|indicator|flags|forced groups (see
            // _dataprobe_linkaudit); groupstat() variables (_gsv) print
            // n cells (the missing count's complement) and, for a 0/1
            // variable, the count of ones
            local _pmv "`_pmv' `_gsv'"
            local _asp ""
            foreach v of local _gvars {
                local i : list posof "`v'" in pvars
                local _afl "c"
                if `: list v in _pmv' local _afl "cp"
                if `: list v in _gmv' local _afl "`_afl'g"
                local _asp "`_asp';M|`v'||`_afl'|`_hm`i''"
                if `: list v in _gsv' & `: list v in f_categorical' {
                    quietly count if !missing(`v') & !inlist(`v', 0, 1)
                    local _n01 = r(N)
                    // groupstat() withholds the ones byfreq withholds
                    local _gl ""
                    if `_n01' == 0 & "`_bffv`i''" != "" {
                        quietly levelsof `dc_group' if `v' == 1 & `_bffv`i'' == 1, local(_gl)
                    }
                    if `_n01' == 0 local _asp "`_asp';V1|`v'||c|`_gl'"
                }
            }
            local _asp "`_asp';I|`_gvars'||ph|`_hc'"
            forvalues k = 1/`nf_complete' {
                if "`_ccv`k''" != "" local _asp "`_asp';I|`_ccv`k''||pg|`_hcc`k''"
            }
            forvalues k = 1/`n_inr' {
                if "`_iw`k''" != "" local _asp "`_asp';C|`inr_var`k''|`_iw`k''|cgw|`_hi`k''"
            }
            foreach k of local _revlk {
                local _asp "`_asp';C|`reviewind`k''|`reviewind`k''|cgw|`_hr`k''"
            }
            foreach _vg in allowed forbid notvalues {
                forvalues k = 1/`n_`_vg'' {
                    if `_hvon_`_vg'`k'' local _asp "`_asp';C|``_vg'_var`k''|`_vhit_`_vg'`k''|cg|`_hv_`_vg'`k''"
                }
            }
            local j = 0
            foreach bv of local binary {
                local ++j
                if `: list bv in f_categorical' local _asp "`_asp';N|`bv'||cg|`_hb`j'';V0|`bv'||zg|;V1|`bv'||zg|"
            }
            forvalues k = 1/`n_stat' {
                if `_hss`k'' local _asp "`_asp';V1|`stat_var`k''||cg|`_hs`k''"
            }
            if "`byfreq'" != "" & `_maskcell' > 0 {
                foreach v in `f_categorical' `f_string' {
                    local i : list posof "`v'" in pvars
                    local _asp "`_asp';F|`v'|`_bffv`i''||"
                }
            }
            // a capped audit pooled every group: this pass rebuilt the
            // withheld lists for that set, and nothing is left to audit
            if `_aud_cap' local _aud_go = 0
            else _dataprobe_audpass `dc_group', mask(`_xmask') cell(`_maskcell') ///
                rare(`rare') maxfreq(`maxfreq') pooled(`_hideg') spec(`"`_asp'"') ///
                budget(`_aud_bud') `patterns'
            if `_aud_go' {
                capture drop `_aud_tv'
                local _aud_tv ""
            }
        }

        // ===================== DISPLAY =====================
        local nv : word count `profilevars'
        if "`gatesonly'" == "" {
            _dataprobe_mshare `n_complete' `nobs' `_xmask'
            local _ccs "`r(cnt)'"
            local _ccp "`r(pcttxt)'"
            if r(masked) local _pmasked = 1
            _dataprobe_mcount `nobs' `_xmask'
            local _nobs_s "`r(s)'"
            if r(masked) local _pmasked = 1
            display ""
            display as text "dataprobe: " as result "`_nobs_s'" as text " obs, " ///
                as result "`nv'" as text " variables profiled" ///
                as text "  (complete cases: " as result "`_ccs'" ///
                as text " = " as result "`_ccp'" as text ")"
            if `_aud_cap' _dataprobe_capnote, `byfreq'
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
                    _dataprobe_mshare `_mn' `nobs' `_xmask'
                    if r(masked) & "`fc'" != "excluded" {
                        local mps "[masked]"
                        local _pmasked = 1
                    }
                }
                _dataprobe_uqmask `m_uv`i'' `m_uc`i'' `nobs' `m_mn`i'' `_xmask'
                local uq "`r(s)'"
                if r(masked) local _pmasked = 1
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
                    mata: st_local("_qsh", _dataprobe_qshowv(st_local("v"), `_xmask', st_matrix(st_local("_cs`pj'"))))
                    local _c = 0
                    foreach _st in mean sd p1 p5 p10 p25 p50 p75 p90 p95 p99 {
                        local ++_c
                        tempname _q`_st'
                        scalar `_q`_st'' = `_cs`pj''[1, `_c']
                        _dataprobe_qshow `v', value(`_q`_st'') mask(`_xmask') stat(`_st') known(`: word `_c' of `_qsh'')
                        local _qs`_st' `"`r(s)'"'
                    }
                    _dataprobe_mshare `cN`pj'' `nobs' `_xmask'
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
                        _dataprobe_mshare `nout' `n' `_xmask'
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
                _dataprobe_uqmask `m_uv`i'' `m_uc`i'' `nobs' `m_mn`i'' `_xmask'
                local _nlevs "`r(s)'"
                if r(masked) local _pmasked = 1
                display as text "  " as result "`v'" as text ":  " ///
                    as result "`_nlevs'" as text " levels"
                if `nlev' == 1 {
                    display as text "    " as `_em' "single level (constant)"
                }
                if `nlev' > `maxcat' {
                    display as text "    " as `_em' "level count exceeds maxcat(" ///
                        "`maxcat')" as text " — possible free-text/misclassification"
                }
                local _fqmask 0
                _dataprobe_freq `v' `maxfreq' `rare' `_maskcell'
                if "`_fqmask'" == "1" local _pmasked = 1
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
                    _dataprobe_qshow `v', value(`_dq1') mask(`_xmask') stat(p1)
                    local _dp1 `"`r(s)'"'
                    local _dok1 = r(shown)
                    _dataprobe_qshow `v', value(`_dq99') mask(`_xmask') stat(p99)
                    local _dp99 `"`r(s)'"'
                    local _dspan "[suppressed]"
                    if `_dok1' & r(shown) local _dspan = strtrim(string(`_dq99' - `_dq1', "%12.0g")) + " `span_unit'"
                    _dataprobe_mshare `m_mn`i'' `nobs' `_xmask'
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
                        _dataprobe_mcount `r(N)' `_xmask' `n'
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
                _dataprobe_uqmask `m_uv`i'' `m_uc`i'' `nobs' `m_mn`i'' `_xmask'
                local uq "`r(s)'"
                if r(masked) local _pmasked = 1
                _dataprobe_mshare `nblank' `nobs' `_xmask'
                local _nbs "`r(cnt)'"
                if r(masked) local _pmasked = 1
                display as text "  " as result "`v'" as text ":  unique=" ///
                    as result "`uq'" as text "  blank=" as result "`_nbs'" ///
                    as text "  maxlen=" as result "`ml'"
                local _fqmask 0
                _dataprobe_freq `v' `maxfreq' `rare' `_maskcell'
                if "`_fqmask'" == "1" local _pmasked = 1
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
                    _dataprobe_mshare `m_mn`i'' `nobs' `_xmask'
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
        local _pgtxt "groups pooled (each <`_xmask' rows, or pooled with them): "
        if `_aud_cap' local _pgtxt "groups pooled (the linked-count check ran out of budget): "

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
            // the pooled-remainder test (see above) names the groups whose
            // complete count is withheld
            foreach gg of local group_levels {
                local gn = _frval(`_gframe', n, `gg')
                if `: list gg in _pooledg' continue
                local gc = _frval(`_gframe', c, `gg')
                _dataprobe_mshare `gc' `gn' `_xmask'
                local gcs "`r(cnt)'"
                local gpcts "`r(pcttxt)'"
                local _gmk = r(masked)
                if `_gmk' local _pmasked = 1
                // a count already printed <m or all but <m keeps that text:
                // [suppr.] stands for an exact count of the mask or more
                if `_pfon' & `: list gg in _hc' & !`_gmk' {
                    local gcs "[suppr.]"
                    local gpcts "[masked]"
                    local _pmasked = 1
                }
                local gmissvars ""
                local gj = 0
                foreach v of local _gvars {
                    local ++gj
                    if _frval(`_gframe', m`gj', `gg') > 0 local gmissvars "`gmissvars' `v'"
                }
                local gmissvars : list uniq gmissvars
                local gmissct : word count `gmissvars'
                if `showflagged' & `gmissct' == 0 continue
                mata: st_local("gshow", _dataprobe_dshow(usubstr(st_local("group_label`gg'"), 1, 20), 20))
                display as text "  " as result `"`macval(gshow)'"' ///
                    as result %9.0f `gn' %12s "`gcs'" %10s "`gpcts'" ///
                    as result %9.0f `gmissct'
            }
            if `_npooledg' > 0 {
                display as text "  `_pgtxt'" as result `_npooledg'
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
                    _dataprobe_mshare `gm' `gn' `_xmask'
                    local gms "`r(cnt)'"
                    local gmpcts "`r(pcttxt)'"
                    local _gmk = r(masked)
                    if `_gmk' local _pmasked = 1
                    local i : list posof "`v'" in pvars
                    if `_pfon' & `: list gg in _hm`i'' & !`_gmk' {
                        local gms "[suppr.]"
                        local gmpcts "[masked]"
                        local _pmasked = 1
                    }
                    mata: st_local("gshow", _dataprobe_dshow(usubstr(st_local("group_label`gg'"), 1, 20), 20))
                    display as text "  " as result `"`macval(gshow)'"' ///
                        as result %-22s "`v'" %9s "`gms'" %10s "`gmpcts'"
                }
            }
            if `_npooledg' > 0 {
                display as text "  `_pgtxt'" as result `_npooledg'
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
                // Pooled remainder, per level: the pooled table's count
                // minus the shown groups' exact cells is the pooled-away
                // groups' and the suppressed cells' total; 1 to mask-1 of
                // them gives a small cell back, so the level's smallest
                // shown cell is withheld (and the group's table pools it)
                local _bff ""
                local i : list posof "`v'" in pvars
                if `_pfon' local _bff "`_bffv`i''"
                else if `_maskcell' > 0 {
                    tempvar _bff
                    _dataprobe_bfforce `v' `dc_group' `maxfreq' `_maskcell' ///
                        `"`_pooledg'"' `_bff'
                }
                tempname _bfq
                _dataprobe_freqprep `v' `dc_group' `_bfq' `_bff'
                foreach gg of local group_levels {
                    if `: list gg in _pooledg' continue
                    mata: st_local("_gl", _dataprobe_dshow(st_local("group_label`gg'"), 0))
                    display as text "    by group " as result `"`macval(_gl)'"' as text ":"
                    local _fqmask 0
                    _dataprobe_freq `v' `maxfreq' `rare' `_maskcell' "" "      " "`_bff'" "`_bfq' `_bfqf' `_bfl`gg'' `_bfh`gg''"
                    if "`_fqmask'" == "1" local _pmasked = 1
                }
                capture frame drop `_bfq'
                if "`_bff'" != "" & !`_pfon' capture drop `_bff'
            }
            if `_npooledg' > 0 {
                display as text "  `_pgtxt'" as result `_npooledg'
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
                    _dataprobe_mshare `ndist' `nobs' `_xmask'
                    local _kds "`r(cnt)'"
                    if r(masked) local _pmasked = 1
                    // the keys with one record are the complement of nmulti
                    // among the distinct keys printed beside it
                    _dataprobe_mcount `nmulti' `_xmask' `ndist'
                    local _kms "`r(s)'"
                    if r(masked) local _pmasked = 1
                    quietly count if `ktag' & `kn' == `kmax'
                    local _kmx "`kmax'"
                    if r(N) < `_xmask' {
                        local _kmx "[suppressed]"
                        local _pmasked = 1
                    }
                    // the median follows the order-statistic rule: at least
                    // the mask of keys at or below it and at or above it
                    // (ids 1, 2x2, 3x9 printed median 2, held by one key)
                    tempname _kmedv
                    scalar `_kmedv' = `kmed'
                    _dataprobe_qshow `kn', value(`_kmedv') mask(`_xmask') ///
                        cond(`ktag' == 1) stat(p50)
                    local _kmd `"`r(s)'"'
                    if !r(shown) local _pmasked = 1
                    display as text "  key (" as result "`kv'" as text "):  " ///
                        as result "`_kds'" as text " distinct keys, records/key median/max = " ///
                        as result "`_kmd'" "/" "`_kmx'" as text ", " ///
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
            _dataprobe_mcount `scope_n' `_gm'
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
            // In a withheld group every count of the mask or more is
            // withheld too: it bounds the group's size, and N minus the
            // shown groups minus it gives back the other withheld groups
            // (110 - 100 - 7 = 3).  _hz is the flag the count helpers take.
            local _hz = ("`scope_hide`si''" == "1" & `_gm' > 0)
            local _hzopt = cond(`_hz', "hide", "")
            // the group, for the pooled-remainder lists (_hm, _hc, ...)
            local _sgg ""
            if `has_groups' local _sgg : word `si' of `group_levels'
            local _pfx = (`_pfon' & "`_sgg'" != "")

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
                _dataprobe_mcount `ndup' `_gm' `scope_n' `_hz'
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
                _dataprobe_mcount `ndup' `_gm' `scope_n' `_hz'
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
                _dataprobe_mcount `nmiss' `_gm' `scope_n' `_hz'
                local nms "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `nmiss' < 1, ., `nmiss')
                local i : list posof "`v'" in pvars
                if `_pfx' & `i' > 0 {
                    // a pooled group's linked count says only whether it
                    // is zero (the verdict says as much)
                    if (`: list _sgg in _hm`i'' & !`om') | (`_hz' & `nmiss' >= 1) {
                        local nms "[suppressed]"
                        local onum = .
                        local om = 1
                        local mins = .
                    }
                }
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
                _dataprobe_mcount `noutr' `_gm' `scope_n' `_hz'
                local nos "`r(s)'"
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `noutr' < 1, ., `noutr')
                if `_pfx' & "`_iw`k''" != "" {
                    if (`: list _sgg in _hi`k'' & !`om') | (`_hz' & `noutr' >= 1) {
                        local nos "[suppressed]"
                        local onum = .
                        local om = 1
                        local mins = .
                    }
                }
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
                        // a date at full precision beside it (a value just
                        // outside a bound can print as the bound's date)
                        if "`_ivf'" != "%14.0g" {
                            tempname _imn _imx
                            scalar `_imn' = r(min)
                            scalar `_imx' = r(max)
                            _dataprobe_datefull `=regexr(string(scalar(`_imn'), "%21x"), "^[+]", "")' `_ivf'
                            local omin `"`r(s)'"'
                            _dataprobe_datefull `=regexr(string(scalar(`_imx'), "%21x"), "^[+]", "")' `_ivf'
                            local omax `"`r(s)'"'
                        }
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
                        _dataprobe_qshow `iv', value(`_iq1') mask(`_xmask') ///
                            cond(`"`IF'"') stat(p1) fmt(%14.0g)
                        local omin `"`r(s)'"'
                        _dataprobe_qshow `iv', value(`_iq99') mask(`_xmask') ///
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
                    // the gate's rows were marked once over the call
                    quietly count if `IF' & `_vhit_`_vg'`k'' == 1
                    local nbad = r(N)
                    local ok = (`nbad' == 0)
                    _dataprobe_mcount `nbad' `_gm' `scope_n' `_hz'
                    local nbs "`r(s)'"
                    local onum = r(num)
                    local om = r(masked)
                    local mins = cond(`om' | `nbad' < 1, ., `nbad')
                    if `_pfx' & "`_hvon_`_vg'`k''" == "1" {
                        if (`: list _sgg in _hv_`_vg'`k'' & !`om') | (`_hz' & `nbad' >= 1) {
                            local nbs "[suppressed]"
                            local onum = .
                            local om = 1
                            local mins = .
                        }
                    }
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
                _dataprobe_mcount `nbad' `_gm' `scope_n' `_hz'
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
                _dataprobe_mcount `nbad' `_gm' `scope_n' `_hz'
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
                _dataprobe_mcount `nbad' `_gm' `scope_n' `_hz'
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
                _dataprobe_statval `sst' `sv' `sden', cond(`"`cnd'"') mask(`_gm') `_hzopt'
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
                // a failing date-formatted mean or percentile without the
                // mask: the value at full precision beside the date, which
                // alone can round onto the bound it failed
                if !`ok' & `_gm' == 0 & `sdef' & `sshown' & ("`sst'" == "mean" | `isorder') {
                    local _svf : format `sv'
                    local _svf = subinstr("`_svf'", "%-", "%", 1)
                    if substr("`_svf'", 1, 2) == "%t" | substr("`_svf'", 1, 2) == "%d" {
                        _dataprobe_datefull `=regexr(string(scalar(`sval'), "%21x"), "^[+]", "")' `_svf'
                        local sshow `"`r(s)'"'
                    }
                }
                // the pooled-remainder test withholds this group's count
                if `_pfx' & `sdef' & ("`_hs`k''" != "" | `_hz') {
                    local _slk = `_hss`k'' | (inlist("`sst'", "n", "pmiss") & "`stat_cond`k''" == "1" & ///
                        `: list sv in _gvars')
                    if (`: list _sgg in _hs`k'' & `sshown') | (`_hz' & `_slk' & scalar(`sval') != 0) {
                        local sshow "[suppressed]"
                        local sshown = 0
                    }
                }
                // exclude() withholds contents, as in inrange(): the verdict
                // of a statistic of an excluded variable, never its value
                local _sxc = 0
                local _sxm = !`sshown'
                foreach _sxv in `sv' `sden' {
                    if `: list _sxv in exclude' local _sxc = 1
                }
                if `_sxc' & `sdef' {
                    local sshow "[excluded]"
                    local sshown = 0
                }
                local sname = cond("`sst'" == "p50", "median", "`sst'")
                local slab "`sname' `sv'"
                if "`sst'" == "ratio" local slab "ratio `sv'/`sden'"
                local onum = regexr(string(cond(`sshown' & `sdef', `sval', .), "%21x"), "^[+]", "")
                local om = cond(`_sxc', `_sxm', !`sshown')
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
            local _bj = 0
            foreach bv of local binary {
                local ++_bj
                quietly count if `IF' & !missing(`bv') & !inlist(`bv', 0, 1)
                local nnot = r(N)
                quietly count if `IF' & `bv' == 0
                local n0 = r(N)
                quietly count if `IF' & `bv' == 1
                local n1 = r(N)
                quietly count if `IF' & missing(`bv')
                local nmv = r(N)
                _dataprobe_mcount `nnot' `_gm' `scope_n' `_hz'
                local nnots "`r(s)'"
                local om1 = r(masked)
                _dataprobe_mcount `nmv' `_gm' `scope_n' `_hz'
                local nmvs "`r(s)'"
                local om2 = r(masked)
                if `_pfx' {
                    local i : list posof "`bv'" in pvars
                    if "`_hb`_bj''" != "" | `_hz' {
                        if (`: list _sgg in _hb`_bj'' & !`om1') | (`_hz' & `nnot' >= 1) {
                            local nnots "[suppressed]"
                            local om1 = 1
                        }
                    }
                    if `i' > 0 {
                        if "`_hm`i''" != "" | `_hz' {
                            if (`: list _sgg in _hm`i'' & !`om2') | (`_hz' & `nmv' >= 1) {
                                local nmvs "[suppressed]"
                                local om2 = 1
                            }
                        }
                    }
                }
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
                _dataprobe_events, rf(`RF') ev(`ev_var`k'') evcond(`ev_cond`k'') ///
                    vars(`ev_covs`k'') min(`ev_min`k'') cond(`IF') kind(invariant) ///
                    grp(`"`GP'"') scope(`"`ev_if`k''"') pfx(`"`PFX'"') mask(`_gm') ///
                    nscope(`scope_npost') excluded(`exclude')
            }

            // review(): counted conditions, printed and never halting
            forvalues k = 1/`n_review' {
                quietly count if `IF' & `reviewind`k''
                local nr = r(N)
                _dataprobe_mshare `nr' `scope_n' `_gm' `_hz'
                local rc_ "`r(cnt)'"
                local rp_ "`r(pct)'"
                if "`scope_hide`si''" == "1" local rp_ "."
                local onum = r(num)
                local om = r(masked)
                local mins = cond(`om' | `nr' < 1, ., `nr')
                // as inrange(): a count the linked-count check withholds,
                // and any nonzero count of a pooled group
                if `_pfx' & `: list k in _revlk' & ((`: list _sgg in _hr`k'' & !`om') | (`_hz' & `nr' >= 1)) {
                    local rc_ "[suppressed]"
                    local onum = .
                    local om = 1
                    local mins = .
                }
                if !`_rev_hdr' {
                    display ""
                    display as text "REVIEW"
                    local _rev_hdr = 1
                }
                // a masked or withheld share is left out rather than printed
                local rsh ""
                if !`om' & "`scope_hide`si''" != "1" local rsh " (`rp_'%)"
                local msg `"`PFX'review(`review_lab`k''): `rc_' of `scope_ns' rows`rsh'"'
                mata: st_local("msg", _dataprobe_dshow(st_local("msg"), 0))
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
                local _cf = 0
                if `_pfx' & "`_hcc`k''" != "" {
                    if `: list _sgg in _hcc`k'' local _cf = 1
                }
                // a pooled group: only whether the count is zero
                if `_pfx' & `_hz' local _cf = 2
                _dataprobe_complete, spec(`"`complete_spec`k''"') rf(`RF') ///
                    kind(`complete_kind`k'') grp(`"`GP'"') pfx(`"`PFX'"') mask(`_gm') ///
                    nscope(`scope_npost') cond(`IF') force(`_cf')
            }
        }

        // ---- whole-sample families: evaluated once on the if/in sample ----
        forvalues k = 1/`nf_intervals' {
            _dataprobe_intervals, spec(`"`intervals_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_keyset' {
            _dataprobe_keyset, spec(`"`keyset_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
            local _ks_om = `_ks_om' + r(only_master)
            local _ks_ou = `_ks_ou' + r(only_using)
        }
        forvalues k = 1/`nf_constant' {
            _dataprobe_constant, spec(`"`constant_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_sets' {
            _dataprobe_sets, spec(`"`sets_spec`k''"') rf(`RF') kind(invariant) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_coverage' {
            // exclude(): the dates of an excluded variable are withheld
            local _cvx ""
            local _cvv : word 1 of `coverage_spec`k''
            capture unab _cvv : `_cvv'
            // an unresolvable name is coverage()'s own error, raised below
            if _rc local _cvv ""
            if `: list _cvv in exclude' local _cvx "excluded"
            _dataprobe_coverage, spec(`"`coverage_spec`k''"') rf(`RF') kind(band) ///
                mask(`_gm') nscope(`nobs') `_cvx'
        }
        forvalues k = 1/`nf_jumps' {
            if !`_rev_hdr' {
                display ""
                display as text "REVIEW"
                local _rev_hdr = 1
            }
            _dataprobe_jumps, spec(`"`jumps_spec`k''"') rf(`RF') kind(review) ///
                mask(`_gm') nscope(`nobs')
        }
        forvalues k = 1/`nf_heaping' {
            _dataprobe_heaping, spec(`"`heaping_spec`k''"') rf(`RF') ///
                kind(`heaping_kind`k'') mask(`_gm') nscope(`nobs')
        }
        // The call's N is always printed or recorded (the profile header,
        // a PASS line, a review() or complete() item's "63 of 63", the
        // ledger's n_scope), so groupstat(n) cells are always tested
        // against it: N minus the shown cells would give back the
        // pooled-away rows.
        local _nprint = 1
        // profile totals a groupstat() cell can be set against: the
        // nonmissing count of a profiled variable, the ones of a 0/1
        // categorical one; with the call's by(), the rows of the groups
        // whose missing count or byfreq cell is withheld
        local _gsopt ""
        if "`gatesonly'" == "" & `_xmask' > 0 {
            local _gsprof : list profilevars - f_excluded
            local _gsopt `"profile(`_gsprof') pcat(`f_categorical')"'
            if `_pfon' {
                // the rows of the pooled groups (pooled in groupstat() too)
                tempvar _phv
                quietly generate byte `_phv' = 0
                foreach gg of local _hideg {
                    quietly replace `_phv' = 1 if `dc_group' == `gg'
                }
                local _gsopt `"`_gsopt' byvars(`byvars') mhide(`_gsmh') fhide(`_gsfh') phide(`_phv')"'
                if `_aud_cap' local _gsopt `"`_gsopt' capped"'
            }
        }
        forvalues k = 1/`nf_groupstat' {
            _dataprobe_groupstat, spec(`"`groupstat_spec`k''"') rf(`RF') nprint(`_nprint') ///
                kind(`groupstat_kind`k'') mask(`_gm') nscope(`nobs') ///
                cond(`groupstat_cond`k'') scope(`"`groupstat_if`k''"') ///
                excluded(`exclude') `_gsopt'
            // a printed <m or [suppr.] cell is a masked count (r(masked))
            if r(masked) local _pmasked = 1
        }

        forvalues k = 1/`nf_smallcells' {
            _dataprobe_smallcells, spec(`"`smallcells_spec`k''"') rf(`RF') kind(invariant) ///
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
	            _dataprobe_pathok `"`compfile'"'
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
	            // dropped: gone from the data, not merely outside the varlist
	            // (dataprobe price mpg, compare() listed every other baseline
	            // variable as dropped)
	            foreach bv of local basevars {
	                if !`: list bv in profilevars' & !`: list bv in _datavars' {
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
                _dataprobe_pathok `"`vdest'"'
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
                _dataprobe_numstr `_smn' `_isf'
                local _amin "`r(s)'"
                _dataprobe_numstr `_smx' `_isf'
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
                _dataprobe_numstr `_smn' `_isf'
                local _amin "`r(s)'"
                _dataprobe_numstr `_smx' `_isf'
                local _amax "`r(s)'"
                frame `sframe': quietly replace arg1 = "`_amin'" in `srow'
                frame `sframe': quietly replace arg2 = "`_amax'" in `srow'
                frame `sframe': quietly replace note = "observed date range" in `srow'
            }
            foreach v of local f_categorical {
                local i : list posof "`v'" in pvars
                if `m_uv`i'' > `maxcat' continue
                _dataprobe_speclevels `v'
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
                _dataprobe_speclevels `v'
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
                _dataprobe_pathok `"`sdest'"'
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
        if `_pfon' return scalar linkaudit_capped = `_aud_cap'
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
	                    str2045 dataset str2045 dataset_label str32 variable ///
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
	                local _dcdsig `"`_dsig'"'
	                _datamap_post_metadata_rows, postname(`dcmeta_post') ///
	                    classifications(`"`proff'"') sourcecommand("dataprobe") ///
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
            capture noisily _dataprobe_ledger, rf(`RF') file(`"`_ledfile'"') ///
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
            _dataprobe_mcount `nobs' `_xmask'
            local _Ns "`r(s)'"
            if !r(masked) local _Ns = strtrim(string(`nobs', "%20.0fc"))
            display ""
            display as text "PASS: " as result `"`_dstag'"' as result "`n_checks'" ///
                as text " gate(s) (" as result "`checks_run'" as text "), N = " ///
                as result "`_Ns'" as text ", 0 violations`_masktag'"
        }
        else if `n_checks' == 0 & `n_rev' == 0 & "`gatesonly'" != "" {
            display as text "dataprobe: gatesonly with no gates declared; nothing was checked"
        }
        if `n_warn' > 0 {
            display ""
            if `_ww' display as text `"WARNINGS (`n_warn')`_dshead'`_masktag'"'
            else display as text `"BAND WARNINGS (`n_warn')`_dshead'`_masktag'"'
            frame `RF' {
                forvalues j = 1/`n_rec' {
                    if status[`j'] != "warn" continue
                    local _m = msg[`j']
                    mata: st_local("_m", _dataprobe_dshow(st_local("_m"), 0))
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
                    mata: st_local("_m", _dataprobe_dshow(st_local("_m"), 0))
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
            capture noisily _dataprobe_errrow `rc' `"`_dsname'"' `"`_ledfile'"' `"`_ledrun'"' `macval(_raw0)'
            local errrow_rc = _rc
            if `errrow_rc' {
                // The call still exits with its own rc below; the ledger
                // just lacks the error row, so say so rather than stay quiet
                display as error "dataprobe: the error row could not be written to the ledger (rc `errrow_rc')"
            }
        }
        exit `rc'
    }
    if `_exit9' {
        // W3: under dataqa set collect with a ledger that took the rows, a
        // failed gate does not halt; dataqa assert is the halting point
        if `_collect' & `"`_ledfile'"' != "" & !`_ledger_rc' & !`cleanup_rc' {
            display as text "dataprobe: " as result "`n_err'" as text " gate failure(s) recorded in the ledger; " ///
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
// Helpers (bundled; loaded with dataprobe.ado)
// ---------------------------------------------------------------------------

capture program drop _dataprobe_pathok
local _drop_pathok_rc = _rc
program define _dataprobe_pathok, nclass
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

capture program drop _dataprobe_uqmask
local _drop_uqmask_rc = _rc
program define _dataprobe_uqmask, rclass
    // A variable's unique-value count for display.  Under a mask m > 0 the
    // count beside N is the number of repeated rows: N minus unique, or
    // nonmissing N minus unique, of 1 to m-1 gives back a small cell (74
    // rows, 73 unique: one duplicate, which KEY STRUCTURE masks), so the
    // count prints as [masked].  A censored count (>cap) is not exact.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args uv uc nobs nmiss m
        if "`uc'" == "" local uc 0
        if missing(`uc') local uc 0
        if "`nmiss'" == "" local nmiss 0
        if missing(`nmiss') local nmiss 0
        if "`m'" == "" local m 0
        _datamap_fmt_uniq `uv' `uc'
        local s "`r(s)'"
        local masked = 0
        if `m' > 0 & !`uc' & !missing(`uv') {
            local d1 = `nobs' - `uv'
            local d2 = `nobs' - `nmiss' - `uv'
            if (`d1' >= 1 & `d1' < `m') | (`d2' >= 1 & `d2' < `m') {
                local s "[masked]"
                local masked = 1
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local s "`s'"
    return scalar masked = `masked'
end

capture program drop _dataprobe_flag
local _drop_flag_rc = _rc
program define _dataprobe_flag, rclass
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
capture mata: mata drop _dataprobe_dshow()
capture mata: mata drop _dataprobe_unwrap()
capture mata: mata drop _datamap_nomask_explicit()
capture mata: mata drop _dataprobe_valscalar()
capture mata: mata drop _dataprobe_frng()
capture mata: mata drop _dataprobe_bfjoin()
capture mata: mata drop _dataprobe_revlink()
capture mata: mata drop _dataprobe_pmcount()
capture mata: mata drop _dataprobe_qshowv()
mata:
// _dataprobe_premask's per-group counts into new frame fr: group, rows
// with ind == 1 (k1), rows (one); local tot = all rows with ind == 1.
// ord is a permutation sorting grp; recomputed when it no longer does.
void _dataprobe_pmcount(string scalar grp, string scalar ind, string scalar ord,
	string scalar fr, string scalar k1, string scalar one)
{
	real colvector g, o, x
	real matrix info
	real scalar n
	string scalar cur
	g = st_data(., grp)
	n = rows(g)
	o = J(0, 1, .)
	if (ord != "") {
		o = st_data(., ord)
		if (max(o) > n | min(o) < 1) o = J(0, 1, .)
		else if (n > 1) {
			if (any(g[o[|2 \ n|], 1] :< g[o[|1 \ n - 1|], 1])) o = J(0, 1, .)
		}
	}
	if (rows(o) != n) o = order(g, 1)
	g = g[o, 1]
	x = (st_data(., ind) :== 1)[o, 1]
	info = panelsetup(g, 1)
	st_local("tot", strofreal(sum(x), "%20.0f"))
	cur = st_framecurrent()
	st_framecreate(fr)
	st_framecurrent(fr)
	st_addobs(rows(info))
	(void) st_addvar("double", (grp, k1, one))
	st_store(., (grp, k1, one), (g[info[., 1], 1], panelsum(x, info), info[., 2] - info[., 1] :+ 1))
	st_framecurrent(cur)
}

// _dataprobe_qshow's mask test for the values q of v (mean, sd, p1 ...
// p99 of the CONTINUOUS block), all rows: "1" shown, "0" suppressed
string scalar _dataprobe_qshowv(string scalar v, real scalar m, real rowvector q)
{
	real matrix x, y
	real rowvector sh
	real scalar k, n, lo, hi, nlo, nhi
	// length(), not rows(): select() on one row can give 1 x 0
	x = st_data(., v)
	x = select(x, x :< .)
	n = length(x)
	sh = J(1, cols(q), 1)
	if (m <= 0) return(invtokens(strofreal(sh)))
	for (k = 1; k <= cols(q); k++) {
		if (q[k] >= .) continue
		if (k == 2) {
			if (n < m) sh[k] = 0
			else {
				lo = min(x)
				hi = max(x)
				nlo = sum(x :== lo)
				nhi = sum(x :== hi)
				if (lo < hi & nlo + nhi == n & (nlo < m | nhi < m)) sh[k] = 0
				else if (lo < hi) {
					y = select(x, (x :> lo) :& (x :< hi))
					if (length(y) > 0) {
						if (min(y) == max(y) & nlo + nhi + length(y) == n &
							(nlo < m | nhi < m | length(y) < m)) sh[k] = 0
					}
				}
			}
		}
		else {
			if (sum(x :<= q[k]) < m) sh[k] = 0
			if (sum(x :>= q[k]) < m) sh[k] = 0
		}
	}
	return(invtokens(strofreal(sh)))
}

// _dataprobe_bfforce: newvar = the flag sv of the row's (v, g) cell in frame
// fr (one row per cell present in the data); local _bfj_ok 0 when the
// cells do not match the data's runs one to one (newvar not created)
void _dataprobe_bfjoin(string scalar v, string scalar g, string scalar fr,
	string scalar sv)
{
	real matrix X, C
	real colvector o, oc, sup, st, res, fi
	real scalar n
	string scalar cur
	X = st_data(., (v, g))
	n = rows(X)
	if (n == 0) return
	o = order(X, (1, 2))
	X = X[o, .]
	// the first row of each (v, g) run
	st = J(n, 1, 1)
	if (n > 1) st[|2 \ n|] = (rowsum(X[|2, 1 \ n, 2|] :!= X[|1, 1 \ n - 1, 2|]) :> 0)
	fi = selectindex(st)
	cur = st_framecurrent()
	st_framecurrent(fr)
	C = st_data(., (v, g))
	sup = st_data(., sv)
	st_framecurrent(cur)
	oc = order(C, (1, 2))
	C = C[oc, .]
	// two subscripts throughout: a 1 x 1 indexed by one column vector
	// comes back as a row (one cell, one row)
	sup = sup[oc, 1]
	if (length(fi) != rows(C)) return
	if (any(X[fi, .] :!= C)) return
	res = J(n, 1, .)
	res[o, 1] = sup[runningsum(st), 1]
	st_store(., st_addvar("byte", sv), res)
	st_local("_bfj_ok", "1")
}

// 1 when the rows where indicator ind is 1 are exactly the rows of one
// value of a variable in lv (a level of a frequency table, whose count
// prints) or exactly the missing rows of a variable in mv (its missing
// count prints); 0 otherwise (the count of ind prints nowhere else)
real scalar _dataprobe_revlink(string scalar ind, string scalar lv, string scalar mv)
{
	real colvector r, x, sel
	string colvector sx
	string rowvector L, Mv
	real scalar j, n
	r = st_data(., ind)
	sel = selectindex(r :== 1)
	n = length(sel)
	if (n == 0) return(0)
	sel = vec(sel)
	L = tokens(lv)
	for (j = 1; j <= cols(L); j++) {
		if (st_isstrvar(L[j])) {
			sx = st_sdata(., L[j])
			if (all(sx[sel, 1] :== sx[sel[1], 1])) {
				if (sum(sx :== sx[sel[1], 1]) == n) return(1)
			}
		}
		else {
			x = st_data(., L[j])
			if (all(x[sel, 1] :== x[sel[1], 1])) {
				if (sum(x :== x[sel[1], 1]) == n) return(1)
			}
		}
	}
	Mv = tokens(mv)
	for (j = 1; j <= cols(Mv); j++) {
		if (st_isstrvar(Mv[j])) {
			if (all((st_sdata(., Mv[j]) :== "") :== (r :== 1))) return(1)
		}
		else if (all((st_data(., Mv[j]) :>= .) :== (r :== 1))) return(1)
	}
	return(0)
}

// "g lo hi ..." for the runs of the (sorted) group variable g
string scalar _dataprobe_frng(string scalar g)
{
	real colvector x
	real matrix info
	x = st_data(., g)
	info = panelsetup(x, 1)
	return(invtokens(strofreal(vec((x[info[., 1], 1], info)'), "%12.0f")'))
}

// String scalar sc from the caller's local src with one wrapping pair of
// double quotes removed (a value written "a" inside a quoted list).
void _dataprobe_valscalar(string scalar src, string scalar sc)
{
	string scalar v
	v = st_local(src)
	if (strlen(v) >= 2 & substr(v, 1, 1) == char(34) & substr(v, strlen(v), 1) == char(34)) {
		v = substr(v, 2, strlen(v) - 2)
	}
	st_strscalar(sc, v)
}

// 1 when the options of command line s (the text after its first comma
// outside quotes and parentheses) name nomaskrare or an abbreviation of it
// as an option of their own.  Scanning the whole line read a variable
// named nomask, or nomask inside an if condition or a suboption's text, as
// the option, and switched a session's masking off (fail open).
real scalar _datamap_nomask_explicit(string scalar s)
{
	real scalar i, n, depth, inq, cq, seen
	string scalar ch, nx, top
	n = strlen(s)
	depth = 0
	inq = 0
	cq = 0
	seen = 0
	top = ""
	for (i = 1; i <= n; i++) {
		ch = substr(s, i, 1)
		nx = (i < n ? substr(s, i + 1, 1) : "")
		if (ch == char(96) & nx == char(34)) {
			cq++
			i++
			if (seen) top = top + "  "
			continue
		}
		if (cq > 0 & ch == char(34) & nx == char(39)) {
			cq--
			i++
			if (seen) top = top + "  "
			continue
		}
		if (cq == 0 & ch == char(34)) {
			inq = !inq
			if (seen) top = top + " "
			continue
		}
		if (cq > 0 | inq) {
			if (seen) top = top + " "
			continue
		}
		if (ch == "(") depth++
		else if (ch == ")" & depth > 0) depth--
		else if (ch == "," & depth == 0 & !seen) {
			seen = 1
			top = ","
			continue
		}
		if (seen) top = top + (depth > 0 | ch == "(" | ch == ")" ? " " : ch)
	}
	if (!seen) return(0)
	return(regexm(" " + strlower(top) + " ", "[ ,]nomask(r|ra|rar|rare)?[ ,]"))
}

// One spec entry, trimmed, without a compound quote that wraps all of it:
// `"a": x > 0"' is "a": x > 0.  The wrapper is removed only when the `" at
// the start is closed by the "' at the end, so `"a"' \ `"b"' is kept.
string scalar _dataprobe_unwrap(string scalar s0)
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

string scalar _dataprobe_dshow(string scalar s, real scalar w)
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

capture program drop _dataprobe_freq
local _drop_freq_rc = _rc
program define _dataprobe_freq, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname fr
    local _frame_open = 0
    local _display = c(noisily)
    capture noisily {
        // Frequency table sorted by descending count, capped at maxfreq.
        // cond: a within-group table (rows where cond holds), printed at
        // indent ind; both empty for the pooled table.  force: a 0/1
        // variable, constant within a level, marking cells withheld by the
        // caller (byfreq's pooled-remainder test).  The caller's local
        // _fqmask is set to 1 when a cell printed as [suppressed].
        args v maxfreq rare maskcell cond ind force src
        if "`maskcell'" == "" local maskcell = 0
        if `"`ind'"' == "" local ind "    "
        // Display-only: under quietly, as-error segments would still print.
        if !`_display' {
            set varabbrev `_orig_varabbrev'
            exit
        }
        tempvar freq sup grp rk
        if `"`src'"' != "" {
            // one group's rows of the grouped table (_dataprobe_freqprep)
            tokenize `"`src'"'
            frame `1': frame put `v' `force' `2' in `3'/`4', into(`fr')
        }
        else if `"`cond'"' == "" frame put `v' `force', into(`fr')
        else frame put `v' `force' if `cond', into(`fr')
        local _frame_open = 1
        local _anysup = 0
        frame `fr' {
            if `"`src'"' != "" rename `2' `freq'
            else quietly contract `v' `force', freq(`freq')
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
            quietly generate byte `grp' = 1
            quietly generate long `rk' = _n
            if "`force'" != "" quietly generate byte `sup' = (`force' == 1)
            else quietly generate byte `sup' = 0
            _dataprobe_freqsup `grp' `freq' `sup' `rk' `maxfreq' `maskcell'
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
                    local _anysup = 1
                    local _why = cond(`ct' < `maskcell', "suppressed (<`maskcell')", ///
                        "suppressed (complement)")
                    display as text `"`ind'"' as result %-28s "[suppressed]" ///
                        as text "  `_why'" as error "`rflag'"
                }
                else {
                    mata: st_local("disp", _dataprobe_dshow(st_local("disp"), 28))
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
        if `_anysup' c_local _fqmask 1
    }
    local rc = _rc
    if `_frame_open' capture frame drop `fr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'

end

capture program drop _dataprobe_freqprep
program define _dataprobe_freqprep
    // byfreq: the (level, group[, force]) frequencies of v in one contract,
    // sorted by group, count (descending) and level, into frame fr.  The
    // caller's locals _bfqf (the count variable) and _bfl<g>/_bfh<g> (the
    // first and last row of group g) address each group's table.  Display
    // only: nothing is built under quietly, where _dataprobe_freq exits.
    version 16.0
    args v grp fr force
    if !c(noisily) exit
    local f "_dpfreq"
    if "`v'" == "`f'" local f "_dpfreq2"
    frame put `v' `grp' `force', into(`fr')
    frame `fr' {
        quietly contract `v' `grp' `force', freq(`f')
        gsort `grp' -`f' `v'
        mata: st_local("_rng", _dataprobe_frng(st_local("grp")))
    }
    c_local _bfqf `f'
    while `"`_rng'"' != "" {
        gettoken g _rng : _rng
        gettoken lo _rng : _rng
        gettoken hi _rng : _rng
        c_local _bfl`g' `lo'
        c_local _bfh`g' `hi'
    }
end

capture program drop _dataprobe_freqsup
local _drop_freqsup_rc = _rc
program define _dataprobe_freqsup, nclass
    // Cell suppression of frequency tables held in the current frame, one
    // table per value of grp, each sorted by descending count (rk is the
    // rank within its table).  A cell below maskcell is suppressed, as is
    // a cell already flagged in sup.  Secondary suppression: the suppressed
    // cells and the levels hidden by maxfreq form a pool whose total is the
    // table's N minus its shown cells.  When the pool holds a suppressed
    // cell but has one member or fewer than maskcell rows, that total would
    // recover it, so the table's smallest shown cell joins the pool until
    // neither holds.  The pooled table and the byfreq tables share it.
    version 16.0
    args grp freq sup rk maxfreq maskcell
    if `maskcell' <= 0 exit
    quietly replace `sup' = 1 if `freq' < `maskcell'
    quietly levelsof `grp' if `sup', local(_gl)
    foreach g of local _gl {
        while 1 {
            quietly count if `grp' == `g' & (`sup' | `rk' > `maxfreq')
            local _pn = r(N)
            quietly summarize `freq' if `grp' == `g' & (`sup' | `rk' > `maxfreq'), meanonly
            local _ps = r(sum)
            if `_pn' >= 2 & `_ps' >= `maskcell' continue, break
            quietly summarize `rk' if `grp' == `g' & !`sup' & `rk' <= `maxfreq', meanonly
            if r(N) == 0 continue, break
            quietly replace `sup' = 1 if `grp' == `g' & `rk' == r(max)
        }
    }
end

capture program drop _dataprobe_premask
local _drop_premask_rc = _rc
program define _dataprobe_premask, rclass
    // The pooled-remainder test for a count printed per by() group beside
    // its total over all rows: ind (0/1) marks the rows counted.  A group's
    // count is exact when the group is shown (not in pooled) and the count
    // is 0, or neither it nor the group's rows minus it is 1 to m-1.  The
    // other groups (pooled away, or printed <m or all but <m) hold the
    // total minus the exact counts, rem, and, since every group's size is
    // printed or is N minus the shown sizes, their rows minus rem, crem.
    // Either of 1 to m-1 gives a masked cell back (one group printed
    // all but <m: rem is its count, crem its small complement), so a group
    // with an exact count is withheld as well: for rem the one with the
    // smallest positive count, for crem the one with the smallest positive
    // complement, the first group on ties, until neither is 1 to m-1.
    // Withholding a count of m or more leaves a remainder of m or more.
    // When rem is 0, crem is the pooled-away groups' size, printed anyway.
    // r(force) lists the groups withheld.
    version 16.0
    args grp ind m pooled ord
    tempname fr
    tempvar one k1
    local force ""
    capture noisily {
        // per-group counts of ind == 1 (k1) and rows (one), one row per
        // group in group order, built in Mata from the group permutation
        mata: _dataprobe_pmcount("`grp'", "`ind'", "`ord'", "`fr'", "`k1'", "`one'")
        frame `fr' {
            local exact ""
            local rem = `tot'
            local nm = 0
            forvalues r = 1/`=_N' {
                local gg = `grp'[`r']
                local k = `k1'[`r']
                local n = `one'[`r']
                local ex = 1
                if `: list gg in pooled' local ex = 0
                else if `k' >= 1 & `k' < `m' local ex = 0
                else if `n' - `k' >= 1 & `n' - `k' < `m' local ex = 0
                if `ex' {
                    local rem = `rem' - `k'
                    local exact "`exact' `r'"
                }
                else local nm = `nm' + `n'
            }
            while 1 {
                local crem = `nm' - `rem'
                local rbad = (`rem' >= 1 & `rem' < `m')
                local cbad = (`rem' >= 1 & `crem' >= 1 & `crem' < `m')
                if !`rbad' & !`cbad' continue, break
                // rem first: the smallest positive count; then the
                // smallest positive complement, among groups with a positive
                // count first (a withheld zero still reads as one where an
                // absent line or MissVars says so)
                local pick = 0
                local xmin = .
                forvalues pass = 1/2 {
                    if `pick' continue, break
                    foreach r of local exact {
                        local k = `k1'[`r']
                        local c = `one'[`r'] - `k'
                        local x = cond(`rbad', `k', `c')
                        if !`rbad' & `pass' == 1 & `k' == 0 continue
                        if `x' > 0 & `x' < `xmin' {
                            local xmin = `x'
                            local pick = `r'
                        }
                    }
                }
                if !`pick' continue, break
                local exact : list exact - pick
                local rem = `rem' + `k1'[`pick']
                local nm = `nm' + `one'[`pick']
                // the group's integer index (egen group), as text
                local gp = string(`grp'[`pick'], "%12.0f")
                local force "`force' `gp'"
            }
            // nothing left to withhold: rem and crem are then the total
            // and its complement, printed anyway
            local force : list retokenize force
        }
    }
    local rc = _rc
    capture frame drop `fr'
    if `rc' exit `rc'
    return local force "`force'"
end

capture program drop _dataprobe_bfforce
local _drop_bfforce_rc = _rc
program define _dataprobe_bfforce, nclass
    // byfreq: generate newvar = 1 on the rows of every (group, level) cell
    // that the pooled-remainder test withholds.  For each level, the pooled
    // count minus the cells the group tables print exactly (shown, not
    // suppressed, within maxfreq, in a group not pooled away) must be 0 or
    // at least maskcell; otherwise the level's smallest exact cell is
    // withheld.  Each group's table is then re-pooled by
    // _dataprobe_freqsup, which only withholds cells of maskcell or more,
    // so a remainder only grows by maskcell or more and the loop ends.
    version 16.0
    args v grp maxfreq maskcell pooledg newvar init
    // init: a 0/1 variable, constant within a cell, marking cells withheld
    // from the start (a group the remainder test withholds elsewhere)
    tempname bf
    tempvar f sup rk hid ex P E rem mn pick
    frame put `v' `grp' `init', into(`bf')
    capture noisily {
        frame `bf' {
            if "`init'" != "" {
                quietly bysort `v' `grp': egen byte `sup' = max(`init')
                quietly drop `init'
                quietly contract `v' `grp' `sup', freq(`f')
            }
            else {
                quietly contract `v' `grp', freq(`f')
                quietly generate byte `sup' = 0
            }
            quietly generate byte `hid' = 0
            foreach gg of local pooledg {
                quietly replace `hid' = 1 if `grp' == `gg'
            }
            gsort `grp' -`f' `v'
            quietly by `grp': generate long `rk' = _n
            _dataprobe_freqsup `grp' `f' `sup' `rk' `maxfreq' `maskcell'
            while 1 {
                capture drop `ex'
                capture drop `P'
                capture drop `E'
                capture drop `rem'
                capture drop `mn'
                capture drop `pick'
                quietly generate byte `ex' = (!`sup' & `rk' <= `maxfreq' & !`hid')
                quietly bysort `v': egen double `P' = total(`f')
                quietly by `v': egen double `E' = total(`f' * `ex')
                quietly generate double `rem' = `P' - `E'
                quietly by `v': egen double `mn' = min(cond(`ex' & `f' > 0, `f', .))
                // one cell per level: the smallest exact cell, the first
                // group on ties
                quietly generate byte `pick' = (`rem' >= 1 & `rem' < `maskcell' & ///
                    `ex' & `f' == `mn')
                quietly bysort `v' `pick' (`grp'): replace `pick' = 0 if `pick' & _n > 1
                quietly count if `pick'
                if r(N) == 0 continue, break
                quietly replace `sup' = 1 if `pick'
                gsort `grp' -`f' `v'
                _dataprobe_freqsup `grp' `f' `sup' `rk' `maxfreq' `maskcell'
            }
            quietly keep `v' `grp' `sup'
            // one row per (level, group) cell of the data: none only when
            // the data have no rows, which byfreq never reaches
            quietly count
            assert r(N) > 0 & r(N) < .
            quietly rename `sup' `newvar'
        }
        // the cells' flags onto their rows: a numeric level by sorting
        // the rows by (level, group) in Mata, run i being cell i of the
        // contracted table; a string level by frlink
        local _bfj_ok = 0
        capture confirm numeric variable `v'
        if !_rc mata: _dataprobe_bfjoin("`v'", "`grp'", "`bf'", "`newvar'")
        if !`_bfj_ok' {
            tempvar lk
            quietly frlink m:1 `v' `grp', frame(`bf') generate(`lk')
            quietly frget `newvar' = `newvar', from(`lk')
            quietly replace `newvar' = 0 if missing(`newvar')
            quietly drop `lk'
        }
    }
    local rc = _rc
    capture frame drop `bf'
    if `rc' exit `rc'
end

capture program drop _dataprobe_numstr
local _drop_numstr_rc = _rc
program define _dataprobe_numstr, rclass
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

capture program drop _dataprobe_speclevels
local _drop_speclevels_rc = _rc
program define _dataprobe_speclevels, rclass
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
                    _dataprobe_numstr `lv' `isf'
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

capture program drop _dataprobe_poolfill
local _drop_poolfill_rc = _rc
program define _dataprobe_poolfill, rclass
    // The by() groups whose size is withheld under maskrare: the groups
    // smaller than the mask, plus pooled() (groups the linked-count audit
    // pools).  A pool of one group, or of fewer than the mask of rows,
    // would be recovered as N minus the shown groups, so the smallest
    // shown group (the first on ties) joins it until neither holds.
    // grp holds the group numbers 1..G (egen group).
    version 16.0
    syntax varname, MASK(integer) [POOLED(string)]
    local _dpa_grp "`varlist'"
    local _dpa_m = `mask'
    local _dpa_pooled "`pooled'"
    mata: _dpa_poolfill()
    return local pooled "`_dpa_out'"
end

capture program drop _dataprobe_audpass
program define _dataprobe_audpass
    // One pass of the linked-count audit (_dataprobe_linkaudit) for the
    // dataprobe caller.  The twin search has one budget of tries per
    // dataprobe call, shared by every pass (a frequency table of L levels
    // re-ranked costs floor(L/512) tries more, a linear program the cube
    // of its size over 6,000): budget() is what is left
    // (empty: the first pass), and the caller's local _aud_bud gets the
    // rest back.  A group the audit names joins the pooled groups
    // (_dataprobe_poolfill, into the caller's local _hideg) and _aud_go
    // asks for another pass.  When the budget runs out before every count
    // is proven safe (r(capped)), an unproven count may be a leak and a
    // partial pooling cannot be re-checked without more budget, so every
    // group is pooled (_aud_cap = 1): no group's audited count prints.
    // Tries, not time: the output must not depend on the machine's load.
    version 16.0
    syntax varname, MASK(integer) SPEC(string) [CELL(integer 0) ///
        RARE(integer 0) MAXFREQ(integer 0) POOLED(string) BUDGET(string) PATterns]
    if "`budget'" == "" local budget = 4000000
    _dataprobe_linkaudit, grp(`varlist') mask(`mask') cell(`cell') rare(`rare') ///
        maxfreq(`maxfreq') pooled(`pooled') spec(`"`spec'"') budget(`budget') `patterns'
    local add "`r(add)'"
    local cap = r(capped)
    c_local _aud_bud = `budget' - r(used)
    if `cap' {
        // 1..G built in Mata: numlist stops with r(123) past ~2,500 groups
        quietly summarize `varlist', meanonly
        mata: st_local("add", invtokens(strofreal(1..`r(max)', "%12.0f")))
    }
    c_local _aud_cap = `cap'
    c_local _aud_go = ("`add'" != "")
    if "`add'" != "" {
        _dataprobe_poolfill `varlist', mask(`mask') pooled(`pooled' `add')
        c_local _hideg "`r(pooled)'"
    }
end

capture program drop _dataprobe_capnote
program define _dataprobe_capnote
    // the note for a capped linked-count audit (_dataprobe_audpass), with
    // the remedies the call's options allow
    version 16.0
    syntax [, BYFREQ]
    local how "fewer profiled variables or per-group gates, or no maskrare"
    if "`byfreq'" != "" local how "no byfreq (or no identifiers and other high-cardinality strings in the profile), fewer profiled variables, or no maskrare"
    display as text "  note: the linked-count audit ran out of budget, so every by() group is pooled;" ///
        " `how' avoid this"
end

capture program drop _dataprobe_revlinks
program define _dataprobe_revlinks
    // the review() conditions whose overall count prints elsewhere: the
    // rows of one level of a profiled categorical or string variable
    // (its frequency table), or the missing rows of a profiled variable;
    // only those join the linked-count check.  A condition whose count
    // prints nowhere else has per-group counts that bound nothing.
    // Caller's local _revlk: their indexes.
    version 16.0
    args inds lv mv
    local out ""
    local k = 0
    foreach ind of local inds {
        local ++k
        mata: st_local("_rl", strofreal(_dataprobe_revlink(st_local("ind"), st_local("lv"), st_local("mv"))))
        if `_rl' local out "`out' `k'"
    }
    c_local _revlk "`out'"
end

capture program drop _dataprobe_linkaudit
local _drop_linkaudit_rc = _rc
program define _dataprobe_linkaudit, rclass
    // Joint audit of the counts a by() profile prints under maskrare: the
    // check for secondary cell suppression in linked tables.  spec() lists
    // the counted quantities as records kind|vars|indicator|flags|forced,
    // separated by semicolons:
    //   M  the missing count of one variable
    //   I  the incomplete rows over a varlist (complete cases = N minus it)
    //   C  the rows where a 0/1 indicator variable is 1 (a value domain, or
    //      a date window, flag w), constant within each value
    //   N, V0, V1  the nonmissing rows of a numeric variable outside {0,1},
    //      at 0, at 1 (binary(), the sum of a 0/1 variable)
    //   F  a byfreq table of the variable; indicator is its withheld-cell
    //      flag (_dataprobe_bfforce), each level a counted quantity
    // flags: c the count prints per shown group, p its complement (n minus
    // it) prints, z only whether it is zero prints, g a gate prints it per
    // pooled group, h (an I record) the header prints its total.  forced
    // lists the groups whose count the pooled-remainder proposal
    // (_dataprobe_premask) withholds as [suppr.].
    //
    // An attacker holds the printed counts, the class of each withheld one
    // (<m is 1 to m-1, all but <m, [suppr.] m to n-m, a zero), the
    // frequency tables' row order, and the linear relations among them:
    // group sizes sum to N, a quantity's group counts sum to its printed
    // total, a group's levels and missing codes sum to its size, its
    // incomplete rows lie between its largest missing count and their sum.
    // A count of 1 to m-1 (or with a complement of 1 to m-1) is safe when
    // another table of counts satisfies all of that with the count changed
    // (protection level zero: the feasibility interval is not one value).
    // The audit searches for one: one unit moved between two values of a
    // variable within a group, matched by the reverse move in another
    // group or absorbed by a masked total; one incomplete row moved
    // between groups; or, between pooled groups (whose sizes are
    // withheld), one row moved.  The same holds for the pooled-away
    // groups' total.  r(add) names one shown group to pool when some count
    // has no such twin, or is empty.
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local add ""
    local nsens = 0
    local nfail = 0
    local resid = 0
    local fails ""
    local used = 0
    local capped = 0
    capture noisily {
        syntax , GRP(varname) MASK(integer) SPEC(string) [CELL(integer 0) ///
            RARE(integer 0) MAXFREQ(integer 0) POOLED(string) PATterns ///
            BUDGET(integer 4000000)]
        local _dpa_grp "`grp'"
        local _dpa_m = `mask'
        local _dpa_cell = `cell'
        local _dpa_rare = `rare'
        local _dpa_maxf = `maxfreq'
        local _dpa_budget = `budget'
        local _dpa_pooled "`pooled'"
        local _dpa_pat = ("`patterns'" != "")
        local _dpa_spec `"`spec'"'
        if strtrim(`"`spec'"') != "" {
            mata: _dpa_run()
            local add "`_dpa_add'"
            local nsens = `_dpa_nsens'
            local nfail = `_dpa_nfail'
            local resid = `_dpa_resid'
            local fails "`_dpa_fails'"
            local used = `_dpa_used'
            local capped = `_dpa_capped'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local add "`add'"
    return local fails "`fails'"
    return scalar nsens = `nsens'
    return scalar nfail = `nfail'
    return scalar resid = `resid'
    return scalar used = `used'
    return scalar capped = `capped'
end

capture mata: mata drop _dpa_run()
capture mata: mata drop _dpa_cnt()
capture mata: mata drop _dpa_okq()
capture mata: mata drop _dpa_okI()
capture mata: mata drop _dpa_inest()
capture mata: mata drop _dpa_rankok()
capture mata: mata drop _dpa_tabtext()
capture mata: mata drop _dpa_rankok1()
capture mata: mata drop _dpa_rankokp()
capture mata: mata drop _dpa_lpbuild()
capture mata: mata drop _dpa_lpexpr()
capture mata: mata drop _dpa_lp()
capture mata: mata drop _dpa_move()
capture mata: mata drop _dpa_moves()
capture mata: mata drop _dpa_maff()
capture mata: mata drop _dpa_try()
capture mata: mata drop _dpa_ishift()
capture mata: mata drop _dpa_wit()
capture mata: mata drop _dpa_witI()
capture mata: mata drop _dpa_movewit()
capture mata: mata drop _dpa_rowind()
capture mata: mata drop _dpa_poolfill()
mata:
struct _dpa_st {
	real scalar m, cell, rare, maxf, budget, used, G, n, nv, ns, nq, N, pat
	real colvector grp, nsz, ispool, gfirst, glast, rord
	pointer(real colvector) colvector code, missmap, vals
	real colvector L, hasF, lev
	pointer(real rowvector) colvector setsof, setvars, affq
	pointer(real matrix) colvector AQI, TCS, TTP
	pointer(real rowvector) matrix TTG
	real matrix rowmiss, MM, IS, NEST
	pointer(real matrix) colvector TCODE, POS, ORD, STAT, SUP
	pointer(real rowvector) colvector PCLO, PCHI
	real colvector qkind, qvar
	pointer(real colvector) colvector qmap
	pointer(real rowvector) colvector qofset
	real scalar lpn, lpcalls, lpcap, lpvcap, lpbuilt
	real matrix lpAE, lpAI, VI
	real colvector lpbE, lpbI, VZ
	real rowvector lplb, lpub
	pointer(real matrix) colvector VY
	real matrix K, LO, HI, TZ, TZC
	real rowvector T, PLO, PHI
}

// The class of a count k of n as dataprobe prints it in a shown group
// (_dataprobe_mcount, _dataprobe_mshare); forced: withheld by the
// pooled-remainder proposal.  A count of 0 or n is taken as printed: a
// verdict, MissVars, an absent row or the complete count can say so.
real rowvector _dpa_cnt(real scalar k, real scalar n, real scalar m, real scalar forced)
{
	if (k == 0) return((0, 0))
	if (k >= 1 & k < m) return((1, m - 1))
	if (n - k >= 1 & n - k < m) return((max((m, n - m + 1)), n - 1))
	if (forced & k != n) return((m, n - m))
	return((k, k))
}

// quantity q at a new count in group g still prints as before (a group's
// size is fixed under these moves)
real scalar _dpa_okq(struct _dpa_st scalar S, real scalar q, real scalar g, real scalar knew)
{
	real scalar ok, k, n
	n = S.nsz[g]
	if (knew < 0 | knew > n) return(0)
	// a level of a printed frequency table: its rows, compared as printed
	// (_dpa_rankok), are the whole constraint; a withheld row names no
	// level, so one level may vanish while another appears
	if (S.qkind[q] == 4 & !S.ispool[g]) return(1)
	if (!S.ispool[g]) return(knew >= S.LO[g, q] & knew <= S.HI[g, q])
	k = S.K[g, q]
	ok = 1
	if (S.TZ[g, q]) ok = ok & ((knew == 0) == (k == 0))
	if (S.TZC[g, q]) ok = ok & ((n - knew == 0) == (n - k == 0))
	return(ok)
}

// every I quantity over set s prints as before at a new count in group g
real scalar _dpa_okI(struct _dpa_st scalar S, real scalar s, real scalar g, real scalar inew)
{
	real scalar i
	real rowvector qs
	qs = *S.qofset[s]
	for (i = 1; i <= cols(qs); i++) {
		if (!_dpa_okq(S, qs[i], g, inew)) return(0)
	}
	return(1)
}

// nested sets keep their order: I(s) <= I(s') <= I(s) + missing of s'\s
real scalar _dpa_inest(struct _dpa_st scalar S, real scalar g, real rowvector I,
	real rowvector M)
{
	real scalar r, s, t, j, extra
	real rowvector vs, vt
	for (r = 1; r <= rows(S.NEST); r++) {
		s = S.NEST[r, 1]
		t = S.NEST[r, 2]
		if (I[s] > I[t]) return(0)
		vs = *S.setvars[s]
		vt = *S.setvars[t]
		extra = 0
		for (j = 1; j <= cols(vt); j++) {
			if (!anyof(vs, vt[j])) extra = extra + M[vt[j]]
		}
		if (I[t] > I[s] + extra) return(0)
	}
	return(1)
}

// The rows a frequency table prints (_dataprobe_freq) for counts cnt by
// code: ordered by count (descending) then value, as gsort -freq var; a
// cell below the cell size, or flagged in force, is withheld, and
// _dataprobe_freqsup pools the smallest shown cells into the withheld
// ones until they number 2 and hold the cell size; the first maxfreq rows
// print, an exact row as its value and count, a withheld row as
// [suppressed] with its reason (<cell or complement) and <rare flag; then
// the number of levels.  Two withheld rows of one reason and flag print
// alike, so their levels may trade places unseen.
real rowvector _dpa_tabtext(real rowvector cnt, real rowvector force, real scalar cell,
	real scalar rare, real scalar maxf)
{
	real scalar np, p, pn, ps, k
	real colvector w, o, sup, rk, pool, cand
	real rowvector txt
	// length(), not rows(): selectindex() of a 1 x 1 false is 1 x 0
	w = selectindex(cnt' :> 0)
	np = length(w)
	if (np == 0) return(0)
	w = vec(w)
	o = order((-cnt[w]', w), (1, 2))
	w = w[o]
	sup = (force[w]' :> 0)
	if (cell > 0) sup = sup :| (cnt[w]' :< cell)
	if (cell > 0 & any(sup)) {
		rk = (1::np)
		while (1) {
			pool = sup :| (rk :> maxf)
			pn = sum(pool)
			ps = sum(cnt[w]' :* pool)
			if (pn >= 2 & ps >= cell) break
			cand = selectindex((!sup) :& (rk :<= maxf))
			if (length(cand) == 0) break
			sup[cand[length(cand)]] = 1
		}
	}
	k = min((np, maxf))
	txt = J(1, k + 1, .)
	for (p = 1; p <= k; p++) {
		if (sup[p]) txt[p] = -(1 + 2 * (cnt[w[p]] < cell) + (rare > 0 & cnt[w[p]] < rare))
		else txt[p] = w[p] * 1e9 + cnt[w[p]]
	}
	txt[k + 1] = np
	return(txt)
}

// the frequency table of variable j in shown group g prints the same rows
// at counts cnt
real scalar _dpa_rankok(struct _dpa_st scalar S, real scalar j, real scalar g,
	real rowvector cnt)
{
	if (any(cnt :< 0)) return(0)
	// re-ranking a table costs about one try per 512 of its levels: the
	// budget then bounds the time of a wide (high-cardinality) table too
	S.used = S.used + floor(S.L[j] / 512)
	if (S.TTG[j, g] == NULL) S.TTG[j, g] = &(_dpa_tabtext((*S.TCODE[j])[g, .],
		(*S.SUP[j])[g, .], S.cell, S.rare, S.maxf))
	return(_dpa_rankok1(*S.TTG[j, g], cnt, (*S.SUP[j])[g, .], S))
}

// the same for the pooled table of variable j (no cell withheld)
real scalar _dpa_rankokp(struct _dpa_st scalar S, real scalar j, real rowvector cnt)
{
	if (any(cnt :< 0)) return(0)
	S.used = S.used + floor(S.L[j] / 512)
	if (S.TTP[j] == NULL) S.TTP[j] = &(_dpa_tabtext(*S.TCS[j], J(1, S.L[j], 0),
		S.cell, S.rare, S.maxf))
	return(_dpa_rankok1(*S.TTP[j], cnt, J(1, S.L[j], 0), S))
}

// a table whose printed rows are t0 prints the same rows at counts c1
real scalar _dpa_rankok1(real rowvector t0, real rowvector c1, real rowvector sup,
	struct _dpa_st scalar S)
{
	real rowvector t1
	t1 = _dpa_tabtext(c1, sup, S.cell, S.rare, S.maxf)
	if (cols(t0) != cols(t1)) return(0)
	return(all(t0 :== t1))
}

// the incomplete counts of group g once its missing counts become M: each
// set's count stays unless it leaves [largest missing count, their sum]
// (then it moves by one); 0 when a class or the nesting breaks.  dI
// returns the change per set.
real scalar _dpa_ishift(struct _dpa_st scalar S, real scalar g, real rowvector M,
	real rowvector dI)
{
	real scalar s, lo, hi, i0, j
	real rowvector I, vs
	I = S.IS[g, .]
	dI = J(1, S.ns, 0)
	for (s = 1; s <= S.ns; s++) {
		vs = *S.setvars[s]
		lo = 0
		hi = 0
		for (j = 1; j <= cols(vs); j++) {
			lo = max((lo, M[vs[j]]))
			hi = hi + M[vs[j]]
		}
		hi = min((hi, S.nsz[g]))
		i0 = I[s]
		if (i0 < lo) dI[s] = lo - i0
		else if (i0 > hi) dI[s] = hi - i0
		if (dI[s] != 0) {
			if (abs(dI[s]) > 1) return(0)
			if (!_dpa_okI(S, s, g, i0 + dI[s])) return(0)
			I[s] = i0 + dI[s]
		}
	}
	if (rows(S.NEST)) {
		if (!_dpa_inest(S, g, I, M)) return(0)
	}
	return(1)
}

// the positions in affq[j] of the quantities that count a code dc moves
// (ascending; the others have dc * qmap = 0), and nz, those codes.  The
// sums over nz equal dc * qmap exactly: whole numbers, the rest zeros.
real matrix _dpa_maff(struct _dpa_st scalar S, real scalar j, real rowvector dc,
	real matrix nz)
{
	real matrix QI
	real colvector sel
	real scalar u
	nz = selectindex(dc :!= 0)
	QI = *S.AQI[j]
	if (rows(QI) == 0 | length(nz) == 0) return(J(0, 1, .))
	sel = J(rows(QI), 1, 0)
	for (u = 1; u <= length(nz); u++) sel = sel :| (QI[., 1] :== nz[u])
	if (!any(sel)) return(J(0, 1, .))
	return(uniqrows(select(QI[., 2], sel)))
}

// unit moves between codes, one per row of MV (group, variable, from,
// to): 1 when every class each touched group prints, its tables' rows,
// its incomplete counts and every total over all rows hold.  A set's
// incomplete count moves when its bounds force it, and the target set's
// count in group a by iopt (0, -1 or 1) when its bounds allow; a total
// that would leave its printed class is matched by one incomplete row
// moved in some other group.  dq returns the change of quantity qs in
// group a, dqp its change summed over the pooled groups.
real scalar _dpa_moves(struct _dpa_st scalar S, real matrix MV, real scalar a,
	real scalar qs, real scalar iopt, real scalar dq, real scalar dqp)
{
	real scalar h, i, k, g, j, q, d, s, tot, c, cc, lo, hi, jj, ok, L, nh, hc, nt, ss, ia, iz
	real rowvector aq, M, I, dI, dIsum, dc, cnt, gs, js, vs, Mc, Ic
	real matrix af, nz
	real matrix GM, GI, TCo
	gs = uniqrows(MV[., 1])'
	js = uniqrows(MV[., 2])'
	nh = cols(gs)
	GM = J(nh, S.nv, 0)
	GI = J(nh, max((S.ns, 1)), 0)
	dIsum = J(1, S.ns, 0)
	dq = 0
	dqp = 0
	for (h = 1; h <= nh; h++) {
		g = gs[h]
		M = S.MM[g, .]
		I = S.IS[g, .]
		for (k = 1; k <= cols(js); k++) {
			j = js[k]
			L = S.L[j]
			TCo = *S.TCODE[j]
			dc = J(1, L, 0)
			nt = 0
			for (i = 1; i <= rows(MV); i++) {
				if (MV[i, 1] != g | MV[i, 2] != j) continue
				dc[MV[i, 3]] = dc[MV[i, 3]] - 1
				dc[MV[i, 4]] = dc[MV[i, 4]] + 1
				nt++
			}
			if (nt == 0) continue
			cnt = TCo[g, .] + dc
			if (any(cnt :< 0)) return(0)
			aq = *S.affq[j]
			af = _dpa_maff(S, j, dc, nz)
			for (ia = 1; ia <= rows(af); ia++) {
				i = af[ia]
				q = aq[i]
				d = 0
				for (iz = 1; iz <= length(nz); iz++) d = d + dc[nz[iz]] * (*S.qmap[q])[nz[iz]]
				if (d == 0) continue
				if (!_dpa_okq(S, q, g, S.K[g, q] + d)) return(0)
				if (q == qs) {
					if (g == a) dq = d
					if (S.ispool[g]) dqp = dqp + d
				}
			}
			if (S.hasF[j] & !S.ispool[g]) {
				if (!_dpa_rankok(S, j, g, cnt)) return(0)
			}
			M[j] = M[j] + dc * (*S.missmap[j])
		}
		if (S.ns > 0) {
			dI = J(1, S.ns, 0)
			if (any(M :!= S.MM[g, .])) {
				if (!_dpa_ishift(S, g, M, dI)) return(0)
			}
			// the target set's optional move in group a
			if (g == a & iopt != 0 & S.qkind[qs] == 3) {
				ss = S.qvar[qs]
				if (dI[ss] == 0) {
					vs = *S.setvars[ss]
					lo = 0
					hi = 0
					for (jj = 1; jj <= cols(vs); jj++) {
						lo = max((lo, M[vs[jj]]))
						hi = hi + M[vs[jj]]
					}
					hi = min((hi, S.nsz[g]))
					if (I[ss] + iopt < lo | I[ss] + iopt > hi) return(0)
					if (!_dpa_okI(S, ss, g, I[ss] + iopt)) return(0)
					dI[ss] = iopt
					if (rows(S.NEST)) {
						if (!_dpa_inest(S, g, I + dI, M)) return(0)
					}
				}
			}
			I = I + dI
			dIsum = dIsum + dI
			if (S.qkind[qs] == 3) {
				d = dI[S.qvar[qs]]
				if (g == a) dq = d
				if (S.ispool[g]) dqp = dqp + d
			}
			GI[h, .] = I
		}
		GM[h, .] = M
	}
	// totals over all rows within their printed class
	for (k = 1; k <= cols(js); k++) {
		j = js[k]
		L = S.L[j]
		TCo = *S.TCODE[j]
		dc = J(1, L, 0)
		for (i = 1; i <= rows(MV); i++) {
			if (MV[i, 2] != j) continue
			dc[MV[i, 3]] = dc[MV[i, 3]] - 1
			dc[MV[i, 4]] = dc[MV[i, 4]] + 1
		}
		if (all(dc :== 0)) continue
		aq = *S.affq[j]
		af = _dpa_maff(S, j, dc, nz)
		for (ia = 1; ia <= rows(af); ia++) {
			i = af[ia]
			q = aq[i]
			d = 0
			for (iz = 1; iz <= length(nz); iz++) d = d + dc[nz[iz]] * (*S.qmap[q])[nz[iz]]
			if (d == 0) continue
			tot = S.T[q] + d
			if (tot < S.PLO[q] | tot > S.PHI[q]) return(0)
		}
		// the pooled frequency table of a variable read by its levels
		if (S.lev[j]) {
			if (!_dpa_rankokp(S, j, *S.TCS[j] + dc)) return(0)
		}
	}
	for (s = 1; s <= S.ns; s++) {
		if (dIsum[s] == 0) continue
		q = (*S.qofset[s])[1]
		tot = S.T[q] + dIsum[s]
		if (tot >= S.PLO[q] & tot <= S.PHI[q]) continue
		// one incomplete row the other way in a group whose bounds and
		// class allow it
		vs = *S.setvars[s]
		ok = 0
		// group a last: there the row may undo the target's change
		for (cc = 1; cc <= S.G & !ok; cc++) {
			c = (cc < a ? cc : (cc < S.G ? cc + 1 : a))
			hc = 0
			for (h = 1; h <= nh; h++) {
				if (gs[h] == c) hc = h
			}
			if (hc) {
				Mc = GM[hc, .]
				Ic = GI[hc, .]
			}
			else {
				Mc = S.MM[c, .]
				Ic = S.IS[c, .]
			}
			lo = 0
			hi = 0
			for (jj = 1; jj <= cols(vs); jj++) {
				lo = max((lo, Mc[vs[jj]]))
				hi = hi + Mc[vs[jj]]
			}
			hi = min((hi, S.nsz[c]))
			if (Ic[s] - dIsum[s] < lo | Ic[s] - dIsum[s] > hi) continue
			if (!_dpa_okI(S, s, c, Ic[s] - dIsum[s])) continue
			Ic[s] = Ic[s] - dIsum[s]
			if (rows(S.NEST)) {
				if (!_dpa_inest(S, c, Ic, Mc)) continue
			}
			ok = 1
			// the target's own count may take the row back: what
			// counts is its net change
			if (S.qkind[qs] == 3 & S.qvar[qs] == s) {
				if (c == a) dq = dq - dIsum[s]
				if (S.ispool[c]) dqp = dqp - dIsum[s]
			}
		}
		if (!ok) return(0)
	}
	return(1)
}

// does a perturbation MV change the target? (mode 0: quantity qs in
// group a; mode 1: its total over the pooled groups)
real scalar _dpa_try(struct _dpa_st scalar S, real matrix MV, real scalar a,
	real scalar qs, real scalar iopt, real scalar mode)
{
	real scalar dq, dqp
	S.used = S.used + 1
	if (S.used > S.budget) return(0)
	dq = 0
	dqp = 0
	if (!_dpa_moves(S, MV, a, qs, iopt, dq, dqp)) return(0)
	return((mode == 0 & dq != 0) | (mode == 1 & dqp != 0))
}

// a change of quantity qs in group a (mode 0), or of its total over the
// pooled groups with a pooled group a (mode 1): one move in a, alone or
// with one move in another group b that takes back one of its two codes
// (a rectangle when b moves the same pair the other way); for a missing
// or incomplete count, also one variable's missing unit traded for
// another's in a and the reverse in b (the incomplete counts may then
// stay), and an incomplete count moved with its bounds
real scalar _dpa_wit(struct _dpa_st scalar S, real scalar qs, real scalar a, real scalar mode)
{
	real scalar ji, j, b, b2, c1, c2, c3, L, w, d1, d2, io, isI, dj, i1, i2, i3, lastv
	real rowvector js, ws
	real colvector mp, mw
	real matrix TCo, TCw, D1, D2
	pointer colvector NZ
	isI = (S.qkind[qs] == 3)
	if (isI) {
		if (_dpa_witI(S, qs, a, mode)) return(1)
		js = *S.setvars[S.qvar[qs]]
	}
	else js = S.qvar[qs]
	for (ji = 1; ji <= cols(js); ji++) {
		j = js[ji]
		TCo = *S.TCODE[j]
		L = S.L[j]
		mp = (isI ? *S.missmap[j] : *S.qmap[qs])
		// the codes each group holds, found once per group (the loops below
		// visit only the codes their own conditions can accept, in the
		// same order, so the tries and their count are unchanged)
		NZ = J(S.G, 1, NULL)
		for (c1 = 1; c1 <= L; c1++) {
			if (TCo[a, c1] < 1) continue
			for (c2 = 1; c2 <= L; c2++) {
				// a spent budget: every further _dpa_try() returns 0
				if (S.used > S.budget) return(0)
				if (c2 == c1 | mp[c1] == mp[c2]) continue
				for (io = (isI ? -1 : 0); io <= (isI ? 1 : 0); io++) {
					if (_dpa_try(S, (a, j, c1, c2), a, qs, io, mode)) return(1)
					for (b = 1; b <= S.G; b++) {
						if (S.used > S.budget) return(0)
						if (b == a) continue
						if (mode == 1 & S.ispool[b]) continue
						if (TCo[b, c2] >= 1) {
							for (c3 = 1; c3 <= L; c3++) {
								if (c3 != c1 & TCo[b, c3] >= 1) {
									if (_dpa_try(S, ((a, j, c1, c2) \ (b, j, c3, c1)), a, qs, io, mode)) return(1)
								}
								if (c3 != c2 & c3 != c1) {
									if (_dpa_try(S, ((a, j, c1, c2) \ (b, j, c2, c3)), a, qs, io, mode)) return(1)
								}
							}
						}
						else {
							// b holds no c2: only the codes b holds
							if (NZ[b] == NULL) NZ[b] = &(selectindex(TCo[b, .] :>= 1))
							for (i3 = 1; i3 <= length(*NZ[b]); i3++) {
								c3 = (*NZ[b])[i3]
								if (c3 != c1) {
									if (_dpa_try(S, ((a, j, c1, c2) \ (b, j, c3, c1)), a, qs, io, mode)) return(1)
								}
							}
						}
					}
				}
				// trade a missing unit with another variable w: in a, j
				// moves c1 -> c2 and w the other way; b reverses both
				if ((*S.missmap[j])[c1] == (*S.missmap[j])[c2]) continue
				dj = (*S.missmap[j])[c1] - (*S.missmap[j])[c2]
				for (w = 1; w <= S.nv; w++) {
					if (w == j | S.ns == 0) continue
					TCw = *S.TCODE[w]
					mw = *S.missmap[w]
					// d1: the codes a holds; d2: the codes whose missing
					// flag is d1's plus dj (dj is not 0, so d2 is not d1
					// and the flags differ)
					D1 = selectindex(TCw[a, .] :>= 1)
					lastv = .
					for (i1 = 1; i1 <= length(D1); i1++) {
						d1 = D1[i1]
						if (mw[d1] != lastv) {
							D2 = selectindex(mw :== mw[d1] + dj)
							lastv = mw[d1]
						}
						for (i2 = 1; i2 <= length(D2); i2++) {
							d2 = D2[i2]
							// j taken back in b, w in b2 (b2 = b: one group)
							for (b = 1; b <= S.G; b++) {
								if (b == a | TCo[b, c2] < 1) continue
								if (mode == 1 & S.ispool[b]) continue
								if (S.used > S.budget) return(0)
								for (b2 = 1; b2 <= S.G; b2++) {
									if (b2 == a | TCw[b2, d2] < 1) continue
									if (mode == 1 & S.ispool[b2]) continue
									if (_dpa_try(S, ((a, j, c1, c2) \ (a, w, d1, d2) \ (b, j, c2, c1) \ (b2, w, d2, d1)), a, qs, 0, mode)) return(1)
								}
							}
						}
					}
				}
			}
		}
	}
	return(0)
}

// an incomplete row moved: I quantity qs over set s up or down by one in
// group a, matched in another group b or absorbed by a masked total
real scalar _dpa_witI(struct _dpa_st scalar S, real scalar qs, real scalar a, real scalar mode)
{
	real scalar s, d, b, ok, q, tot, lo, hi, j, i
	real rowvector vs, I
	s = S.qvar[qs]
	vs = *S.setvars[s]
	q = (*S.qofset[s])[1]
	for (d = -1; d <= 1; d = d + 2) {
		// group a
		I = S.IS[a, .]
		lo = 0
		hi = 0
		for (j = 1; j <= cols(vs); j++) {
			lo = max((lo, S.MM[a, vs[j]]))
			hi = hi + S.MM[a, vs[j]]
		}
		hi = min((hi, S.nsz[a]))
		if (I[s] + d < lo | I[s] + d > hi) continue
		if (!_dpa_okI(S, s, a, I[s] + d)) continue
		I[s] = I[s] + d
		if (rows(S.NEST)) {
			if (!_dpa_inest(S, a, I, S.MM[a, .])) continue
		}
		// absorbed by a masked total (mode 0, or a pooled group a: the
		// pooled-away total moves with it)
		tot = S.T[q] + d
		if (tot >= S.PLO[q] & tot <= S.PHI[q]) return(1)
		for (b = 1; b <= S.G; b++) {
			if (b == a) continue
			if (mode == 1 & S.ispool[b]) continue
			S.used = S.used + 1
			if (S.used > S.budget) return(0)
			I = S.IS[b, .]
			lo = 0
			hi = 0
			for (j = 1; j <= cols(vs); j++) {
				lo = max((lo, S.MM[b, vs[j]]))
				hi = hi + S.MM[b, vs[j]]
			}
			hi = min((hi, S.nsz[b]))
			if (I[s] - d < lo | I[s] - d > hi) continue
			if (!_dpa_okI(S, s, b, I[s] - d)) continue
			I[s] = I[s] - d
			ok = 1
			if (rows(S.NEST)) ok = _dpa_inest(S, b, I, S.MM[b, .])
			if (ok) return(1)
		}
	}
	return(0)
}

// 0/1 row vector: the quantities that count row r
real rowvector _dpa_rowind(struct _dpa_st scalar S, real scalar r)
{
	real scalar q, j
	real rowvector v
	v = J(1, S.nq, 0)
	for (q = 1; q <= S.nq; q++) {
		if (S.qkind[q] == 3) v[q] = (S.rowmiss[r, S.qvar[q]] > 0)
		else {
			j = S.qvar[q]
			v[q] = (*S.qmap[q])[(*S.code[j])[r]]
		}
	}
	return(v)
}

// pooled groups' sizes are withheld: one row moved between two of them
// (want: 1 changes the count of qs, 0 its complement) that leaves every
// class they print, and each size's class (<m or not), in place
real scalar _dpa_movewit(struct _dpa_st scalar S, real scalar qs, real scalar a,
	real scalar want)
{
	real scalar b, dir, src, dst, r, q, ok, nr, k, n, kn, nn
	real rowvector v
	for (b = 1; b <= S.G; b++) {
		if (b == a | !S.ispool[b]) continue
		for (dir = 1; dir <= 2; dir++) {
			src = (dir == 1 ? b : a)
			dst = (dir == 1 ? a : b)
			if (S.nsz[src] <= 1) continue
			if ((S.nsz[src] - 1 < S.m) != (S.nsz[src] < S.m)) continue
			if ((S.nsz[dst] + 1 < S.m) != (S.nsz[dst] < S.m)) continue
			nr = 0
			for (r = S.gfirst[src]; r <= S.glast[src]; r++) {
				nr++
				if (nr > 2000) break
				S.used = S.used + 1
				if (S.used > S.budget) return(0)
				v = _dpa_rowind(S, S.rord[r])
				if (v[qs] != want) continue
				ok = 1
				for (q = 1; q <= S.nq & ok; q++) {
					// the zero classes of a pooled group, at its new size
					k = S.K[dst, q]
					n = S.nsz[dst]
					kn = k + v[q]
					nn = n + 1
					if (S.TZ[dst, q]) ok = ok & ((kn == 0) == (k == 0))
					if (S.TZC[dst, q]) ok = ok & ((nn - kn == 0) == (n - k == 0))
					k = S.K[src, q]
					n = S.nsz[src]
					kn = k - v[q]
					nn = n - 1
					if (S.TZ[src, q]) ok = ok & ((kn == 0) == (k == 0))
					if (S.TZC[src, q]) ok = ok & ((nn - kn == 0) == (n - k == 0))
				}
				if (ok) return(1)
			}
		}
	}
	return(0)
}

// ---- the exact check: the feasibility interval by linear programming ----
// (Hundepool et al., Handbook on Statistical Disclosure Control, 2nd ed.,
// 2025, sec. 4.2.2: the bounds a user can derive for a withheld cell from
// the linear relations of the table).  Unknowns: each group's count of
// each code of each variable, each group's incomplete count per set, and
// each pooled group's size.  Constraints: everything the output prints, as
// the classes above; a frequency table's withheld cell is held between
// the exact rows around its own row (its true row: an attacker who knows
// it can do no worse).  Built once per audit.
void _dpa_lpbuild(struct _dpa_st scalar S)
{
	real scalar j, g, c, q, s, t, k, n, nv, r, cu, cd, lo, hi, p, x, nP
	real matrix RE, RI, VYj, TCo, PO, OR, ST
	real colvector bE, bI, mp
	real rowvector row, vs, vt, txt, Tc, w0, sup, cnt, sm
	real colvector w, o
	S.lpbuilt = 1
	nv = 0
	S.VY = J(S.nv, 1, NULL)
	for (j = 1; j <= S.nv; j++) {
		VYj = J(S.G, S.L[j], 0)
		for (g = 1; g <= S.G; g++) {
			for (c = 1; c <= S.L[j]; c++) {
				nv++
				VYj[g, c] = nv
			}
		}
		S.VY[j] = &(VYj :+ 0)
	}
	S.VI = J(S.G, max((S.ns, 1)), 0)
	for (g = 1; g <= S.G; g++) {
		for (s = 1; s <= S.ns; s++) {
			nv++
			S.VI[g, s] = nv
		}
	}
	S.VZ = J(S.G, 1, 0)
	for (g = 1; g <= S.G; g++) {
		if (S.ispool[g]) {
			nv++
			S.VZ[g] = nv
		}
	}
	S.lpn = nv
	if (nv > S.lpvcap) return
	nP = sum(S.nsz :* S.ispool)
	S.lplb = J(1, nv, 0)
	S.lpub = J(1, nv, S.N)
	for (g = 1; g <= S.G; g++) {
		if (S.ispool[g]) {
			S.lplb[S.VZ[g]] = (S.nsz[g] < S.m ? 1 : S.m)
			S.lpub[S.VZ[g]] = (S.nsz[g] < S.m ? S.m - 1 : nP)
		}
	}
	RE = J(0, nv, 0)
	bE = J(0, 1, 0)
	RI = J(0, nv, 0)
	bI = J(0, 1, 0)
	// group sizes
	for (j = 1; j <= S.nv; j++) {
		for (g = 1; g <= S.G; g++) {
			row = J(1, nv, 0)
			row[(*S.VY[j])[g, .]] = J(1, S.L[j], 1)
			if (S.ispool[g]) {
				row[S.VZ[g]] = -1
				RE = RE \ row
				bE = bE \ 0
			}
			else {
				RE = RE \ row
				bE = bE \ S.nsz[g]
			}
		}
	}
	if (nP > 0) {
		row = J(1, nv, 0)
		for (g = 1; g <= S.G; g++) {
			if (S.ispool[g]) row[S.VZ[g]] = 1
		}
		RE = RE \ row
		bE = bE \ nP
	}
	// each quantity's class per group and over all rows
	for (q = 1; q <= S.nq; q++) {
		for (g = 1; g <= S.G; g++) {
			row = _dpa_lpexpr(S, q, g, nv)
			k = S.K[g, q]
			n = S.nsz[g]
			if (!S.ispool[g]) {
				RI = RI \ row \ -row
				bI = bI \ S.HI[g, q] \ -S.LO[g, q]
			}
			else {
				if (S.TZ[g, q]) {
					if (k == 0) {
						RI = RI \ row
						bI = bI \ 0
					}
					else {
						RI = RI \ -row
						bI = bI \ -1
					}
				}
				if (S.TZC[g, q]) {
					row[S.VZ[g]] = row[S.VZ[g]] - 1
					if (n - k == 0) {
						RI = RI \ -row
						bI = bI \ 0
					}
					else {
						RI = RI \ row
						bI = bI \ -1
					}
				}
			}
		}
		row = J(1, nv, 0)
		for (g = 1; g <= S.G; g++) row = row + _dpa_lpexpr(S, q, g, nv)
		RI = RI \ row \ -row
		bI = bI \ S.PHI[q] \ -S.PLO[q]
	}
	// frequency tables: a withheld or cut cell between the exact rows
	// around its row (ties: lower value first)
	for (j = 1; j <= S.nv; j++) {
		if (!S.lev[j]) continue
		TCo = *S.TCODE[j]
		for (g = 0; g <= S.G; g++) {
			if (g > 0) {
				if (S.ispool[g] | !S.hasF[j]) continue
				cnt = TCo[g, .]
				sup = (*S.SUP[j])[g, .]
			}
			else {
				cnt = colsum(TCo)
				sup = J(1, S.L[j], 0)
			}
			txt = _dpa_tabtext(cnt, sup, S.cell, S.rare, S.maxf)
			w = selectindex(cnt' :> 0)
			if (length(w) == 0) continue
			w = vec(w)
			o = order((-cnt[w]', w), (1, 2))
			w = w[o]
			for (p = 1; p <= rows(w); p++) {
				c = w[p]
				if (p <= S.maxf) {
					if (txt[p] >= 0) continue
				}
				// the exact rows around it
				cu = 0
				for (r = p - 1; r >= 1 & cu == 0; r--) {
					if (r <= S.maxf) {
						if (txt[r] >= 0) cu = w[r]
					}
				}
				cd = 0
				for (r = p + 1; r <= rows(w) & cd == 0; r++) {
					if (r <= S.maxf) {
						if (txt[r] >= 0) cd = w[r]
					}
				}
				row = J(1, nv, 0)
				if (g > 0) row[(*S.VY[j])[g, c]] = 1
				else row[(*S.VY[j])[., c]'] = J(1, S.G, 1)
				// the pooled table: the reason class too
				if (g == 0) {
					lo = 1
					hi = S.N
					if (p <= S.maxf) {
						if (cnt[c] < S.cell) hi = S.cell - 1
						else lo = S.cell
						if (S.rare > 0) {
							if (cnt[c] < S.rare) hi = min((hi, S.rare - 1))
							else lo = max((lo, S.rare))
						}
					}
					RI = RI \ row \ -row
					bI = bI \ hi \ -lo
				}
				if (cu) {
					RI = RI \ row
					bI = bI \ (cnt[cu] - (cu < c ? 0 : 1))
				}
				if (cd) {
					RI = RI \ -row
					bI = bI \ -(cnt[cd] + (c < cd ? 0 : 1))
				}
			}
			// the pooled table's exact rows
			if (g == 0) {
				for (p = 1; p <= rows(w) & p <= S.maxf; p++) {
					if (txt[p] < 0) continue
					c = w[p]
					row = J(1, nv, 0)
					row[(*S.VY[j])[., c]'] = J(1, S.G, 1)
					RE = RE \ row
					bE = bE \ cnt[c]
				}
			}
		}
	}
	// incomplete counts: between the largest missing count and their sum,
	// at most the group size; nested sets in order
	for (g = 1; g <= S.G; g++) {
		for (s = 1; s <= S.ns; s++) {
			vs = *S.setvars[s]
			row = J(1, nv, 0)
			row[S.VI[g, s]] = 1
			sm = J(1, nv, 0)
			for (t = 1; t <= cols(vs); t++) {
				j = vs[t]
				mp = *S.missmap[j]
				w0 = J(1, nv, 0)
				w0[(*S.VY[j])[g, .]] = mp'
				// a missing count is at most the incomplete count
				RI = RI \ (w0 - row)
				bI = bI \ 0
				sm = sm + w0
			}
			// the incomplete count is at most the missing counts' sum
			RI = RI \ (row - sm)
			bI = bI \ 0
			row = J(1, nv, 0)
			row[S.VI[g, s]] = 1
			if (S.ispool[g]) {
				row[S.VZ[g]] = -1
				RI = RI \ row
				bI = bI \ 0
			}
			else {
				RI = RI \ row
				bI = bI \ S.nsz[g]
			}
		}
		for (r = 1; r <= rows(S.NEST); r++) {
			s = S.NEST[r, 1]
			t = S.NEST[r, 2]
			row = J(1, nv, 0)
			row[S.VI[g, s]] = 1
			row[S.VI[g, t]] = -1
			RI = RI \ row
			bI = bI \ 0
			row = -row
			vs = *S.setvars[s]
			vt = *S.setvars[t]
			for (k = 1; k <= cols(vt); k++) {
				if (anyof(vs, vt[k])) continue
				j = vt[k]
				row[(*S.VY[j])[g, .]] = row[(*S.VY[j])[g, .]] - (*S.missmap[j])'
			}
			RI = RI \ row
			bI = bI \ 0
		}
	}
	S.lpAE = RE
	S.lpbE = bE
	S.lpAI = RI
	S.lpbI = bI
}

// quantity q of group g as a row of the unknowns
real rowvector _dpa_lpexpr(struct _dpa_st scalar S, real scalar q, real scalar g,
	real scalar nv)
{
	real rowvector row
	row = J(1, nv, 0)
	if (S.qkind[q] == 3) row[S.VI[g, S.qvar[q]]] = 1
	else row[(*S.VY[S.qvar[q]])[g, .]] = (*S.qmap[q])'
	return(row)
}

// 1 when the feasibility interval of the target spans two whole numbers:
// quantity qs in group a (mode 0), its total over the pooled groups (mode
// 1), or with cmp its complement in pooled group a
real scalar _dpa_lp(struct _dpa_st scalar S, real scalar qs, real scalar a,
	real scalar mode, real scalar cmp)
{
	class LinearProgram scalar P
	real scalar t, lo, hi, g
	real rowvector cf
	// a spent budget: nothing more is built or solved
	if (S.used > S.budget) return(0)
	if (!S.lpbuilt) _dpa_lpbuild(S)
	if (S.lpn > S.lpvcap) return(0)
	if (S.lpcalls >= S.lpcap) return(0)
	S.lpcalls = S.lpcalls + 1
	// two solves cost tries too, in proportion to the cube of the
	// program's size (unknowns plus constraint rows; 1,700 is about
	// 800,000 tries, some 15 seconds), so the budget bounds this stage as
	// well; a spent budget leaves the count unresolved
	S.used = S.used + ceil((S.lpn + rows(S.lpAE) + rows(S.lpAI))^3 / 6000)
	if (S.used > S.budget) return(0)
	if (mode == 1) {
		cf = J(1, S.lpn, 0)
		for (g = 1; g <= S.G; g++) {
			if (S.ispool[g]) cf = cf + _dpa_lpexpr(S, qs, g, S.lpn)
		}
	}
	else {
		cf = _dpa_lpexpr(S, qs, a, S.lpn)
		if (cmp) {
			cf = -cf
			cf[S.VZ[a]] = 1
		}
	}
	for (t = 1; t <= 2; t++) {
		P = LinearProgram()
		P.setCoefficients(cf)
		P.setMaxOrMin(t == 1 ? "min" : "max")
		if (rows(S.lpAE)) P.setEquality(S.lpAE, S.lpbE)
		if (rows(S.lpAI)) P.setInequality(S.lpAI, S.lpbI)
		P.setBounds(S.lplb, S.lpub)
		(void) P.optimize()
		if (P.errorcode()) return(0)
		if (t == 1) lo = P.value()
		else hi = P.value()
	}
	return(floor(hi + 1e-4) - ceil(lo - 1e-4) >= 1)
}

void _dpa_run()
{
	struct _dpa_st scalar S
	real scalar i, j, q, g, s, b, r, nq, nv, ns, n, k, ok, c, x, lo, hi, fi, t
	real scalar valsens, cmpsens, nP, R, best, bestn, nfail, nsens, resid, capped
	real scalar isstr, L, nw, need
	real colvector x0, miss, cc, o, pl, ind, vl, w, failE, qset
	real rowvector cp, fo, pool, idx, plo, phi, Tc, vs, vt
	real matrix TCo, PO, OR, ST, SUPm, failP, failV
	string colvector sv
	string rowvector recs, f, fld, vnames, rk, rv, ri, rf, rfo, QF, QFO
	string scalar fl, kd, rec, fails

	S.m = strtoreal(st_local("_dpa_m"))
	S.cell = strtoreal(st_local("_dpa_cell"))
	S.rare = strtoreal(st_local("_dpa_rare"))
	S.maxf = strtoreal(st_local("_dpa_maxf"))
	S.budget = strtoreal(st_local("_dpa_budget"))
	S.pat = strtoreal(st_local("_dpa_pat"))
	S.lpbuilt = 0
	S.lpcalls = 0
	S.lpcap = 40
	S.lpvcap = 700
	S.used = 0
	S.grp = st_data(., st_local("_dpa_grp"))
	S.n = rows(S.grp)
	S.N = S.n
	S.G = max(S.grp)
	n = S.n
	// rows ordered by group; first and last position of each group
	S.rord = order(S.grp, 1)
	S.gfirst = J(S.G, 1, 0)
	S.glast = J(S.G, 1, 0)
	S.nsz = J(S.G, 1, 0)
	for (r = 1; r <= n; r++) {
		g = S.grp[S.rord[r]]
		if (S.gfirst[g] == 0) S.gfirst[g] = r
		S.glast[g] = r
		S.nsz[g] = S.nsz[g] + 1
	}
	S.ispool = J(S.G, 1, 0)
	pool = strtoreal(tokens(st_local("_dpa_pooled")))
	for (i = 1; i <= cols(pool); i++) S.ispool[pool[i]] = 1

	// ---- records: kind|vars|indicator|flags|forced ----
	recs = tokens(st_local("_dpa_spec"), ";")
	vnames = J(1, 0, "")
	rk = J(1, 0, "")
	rv = J(1, 0, "")
	ri = J(1, 0, "")
	rf = J(1, 0, "")
	rfo = J(1, 0, "")
	for (i = 1; i <= cols(recs); i++) {
		rec = strtrim(recs[i])
		if (rec == ";" | rec == "") continue
		f = tokens(rec, "|")
		fld = J(1, 5, "")
		fi = 1
		for (j = 1; j <= cols(f); j++) {
			if (f[j] == "|") fi++
			else if (fi <= 5) fld[fi] = strtrim(f[j])
		}
		rk = rk, fld[1]
		rv = rv, fld[2]
		ri = ri, fld[3]
		rf = rf, fld[4]
		rfo = rfo, fld[5]
		f = tokens(fld[2])
		for (j = 1; j <= cols(f); j++) {
			if (!anyof(vnames, f[j])) vnames = vnames, f[j]
		}
	}
	nv = cols(vnames)
	nq = cols(rk)
	S.nv = nv
	// one code per value when a quantity reads a variable's levels
	S.lev = J(nv, 1, 0)
	for (q = 1; q <= nq; q++) {
		if (rk[q] == "F" | rk[q] == "N" | rk[q] == "V0" | rk[q] == "V1" |
			(rk[q] == "C" & !strpos(rf[q], "w"))) {
			S.lev[selectindex(vnames :== rv[q])] = 1
		}
	}
	// the sets of the I records
	ns = 0
	S.setsof = J(nv, 1, NULL)
	for (j = 1; j <= nv; j++) S.setsof[j] = &J(1, 0, .)
	S.setvars = J(0, 1, NULL)
	qset = J(nq, 1, 0)
	for (q = 1; q <= nq; q++) {
		if (rk[q] != "I") continue
		f = tokens(rv[q])
		idx = J(1, 0, .)
		for (j = 1; j <= cols(f); j++) {
			i = selectindex(vnames :== f[j])
			if (!anyof(idx, i)) idx = idx, i
		}
		idx = sort(idx', 1)'
		// one set per distinct varlist
		s = 0
		for (i = 1; i <= ns; i++) {
			if (cols(*S.setvars[i]) == cols(idx)) {
				if (*S.setvars[i] == idx) s = i
			}
		}
		if (s == 0) {
			ns++
			s = ns
			S.setvars = S.setvars \ &(idx :+ 0)
			for (j = 1; j <= cols(idx); j++) S.setsof[idx[j]] = &((*S.setsof[idx[j]]), s)
		}
		qset[q] = s
	}
	S.ns = ns
	// pairs of nested sets
	S.NEST = J(0, 2, .)
	for (s = 1; s <= ns; s++) {
		for (t = 1; t <= ns; t++) {
			if (s == t) continue
			vs = *S.setvars[s]
			vt = *S.setvars[t]
			ok = 1
			for (j = 1; j <= cols(vs); j++) {
				if (!anyof(vt, vs[j])) ok = 0
			}
			if (ok) S.NEST = S.NEST \ (s, t)
		}
	}
	// codes per variable
	S.code = J(nv, 1, NULL)
	S.missmap = J(nv, 1, NULL)
	S.vals = J(nv, 1, NULL)
	S.L = J(nv, 1, 0)
	S.hasF = J(nv, 1, 0)
	S.rowmiss = J(n, max((ns, 1)), 0)
	for (j = 1; j <= nv; j++) {
		isstr = st_isstrvar(vnames[j])
		if (isstr) {
			sv = st_sdata(., vnames[j])
			miss = (sv :== "")
		}
		else {
			x0 = st_data(., vnames[j])
			miss = (x0 :>= .)
		}
		for (b = 1; b <= cols(*S.setsof[j]); b++) {
			S.rowmiss[., (*S.setsof[j])[b]] = S.rowmiss[., (*S.setsof[j])[b]] + miss
		}
		if (S.lev[j]) {
			// one code per value, in sort order (numeric missing codes
			// last, a string's blank first), as gsort orders a table
			cc = J(n, 1, 0)
			if (isstr) o = order(sv, 1)
			else o = order(x0, 1)
			L = 1
			cc[o[1]] = 1
			for (r = 2; r <= n; r++) {
				if (isstr) {
					if (sv[o[r]] != sv[o[r - 1]]) L++
				}
				else {
					if (x0[o[r]] != x0[o[r - 1]]) L++
				}
				cc[o[r]] = L
			}
			vl = J(L, 1, .)
			pl = J(L, 1, 0)
			for (r = 1; r <= n; r++) {
				pl[cc[r]] = miss[r]
				if (!isstr) vl[cc[r]] = x0[r]
			}
		}
		else {
			// code 1 nonmissing, 2 missing, plus one bit per date window
			// of the variable (C records flagged w), in record order
			cc = 1 :+ miss
			L = 2
			for (q = 1; q <= nq; q++) {
				if (rk[q] == "C" & rv[q] == vnames[j]) {
					ind = st_data(., ri[q])
					cc = cc :+ L :* (ind :== 1)
					L = 2 * L
				}
			}
			pl = J(L, 1, 0)
			for (c = 1; c <= L; c++) pl[c] = mod(c - 1, 2)
			vl = J(L, 1, .)
		}
		S.code[j] = &(cc :+ 0)
		S.L[j] = L
		S.missmap[j] = &(pl :+ 0)
		S.vals[j] = &(vl :+ 0)
	}
	// counts per code and group; missing and incomplete counts
	S.TCODE = J(nv, 1, NULL)
	S.PCLO = J(nv, 1, NULL)
	S.PCHI = J(nv, 1, NULL)
	S.MM = J(S.G, nv, 0)
	for (j = 1; j <= nv; j++) {
		TCo = J(S.G, S.L[j], 0)
		cc = *S.code[j]
		for (r = 1; r <= n; r++) TCo[S.grp[r], cc[r]] = TCo[S.grp[r], cc[r]] + 1
		S.TCODE[j] = &(TCo :+ 0)
		S.MM[., j] = TCo * (*S.missmap[j])
		// the pooled frequency table's class of each level (a level
		// below the cell prints [suppressed] (<cell), flagged <rare)
		Tc = colsum(TCo)
		plo = Tc
		phi = Tc
		if (S.lev[j]) {
			for (c = 1; c <= S.L[j]; c++) {
				if (Tc[c] >= 1 & Tc[c] < S.cell) {
					plo[c] = 1
					phi[c] = S.cell - 1
					if (S.rare > 0) {
						if (Tc[c] < S.rare) phi[c] = min((phi[c], S.rare - 1))
						else plo[c] = max((plo[c], S.rare))
					}
				}
			}
		}
		S.PCLO[j] = &(plo :+ 0)
		S.PCHI[j] = &(phi :+ 0)
	}
	S.IS = J(S.G, max((ns, 1)), 0)
	for (s = 1; s <= ns; s++) {
		for (r = 1; r <= n; r++) {
			if (S.rowmiss[r, s] > 0) S.IS[S.grp[r], s] = S.IS[S.grp[r], s] + 1
		}
	}
	// quantities; a byfreq table gives one per level
	S.qkind = J(0, 1, .)
	S.qvar = J(0, 1, .)
	S.qmap = J(0, 1, NULL)
	QF = J(1, 0, "")
	QFO = J(1, 0, "")
	S.POS = J(nv, 1, NULL)
	S.ORD = J(nv, 1, NULL)
	S.STAT = J(nv, 1, NULL)
	S.SUP = J(nv, 1, NULL)
	for (q = 1; q <= nq; q++) {
		kd = rk[q]
		fl = rf[q]
		if (kd == "I") {
			S.qkind = S.qkind \ 3
			S.qvar = S.qvar \ qset[q]
			S.qmap = S.qmap \ NULL
			QF = QF, fl
			QFO = QFO, rfo[q]
			continue
		}
		j = selectindex(vnames :== rv[q])
		L = S.L[j]
		if (kd == "M") {
			S.qkind = S.qkind \ 1
			S.qvar = S.qvar \ j
			S.qmap = S.qmap \ &((*S.missmap[j]) :+ 0)
			QF = QF, fl
			QFO = QFO, rfo[q]
		}
		else if (kd == "C") {
			pl = J(L, 1, 0)
			if (S.lev[j]) {
				ind = st_data(., ri[q])
				cc = *S.code[j]
				for (r = 1; r <= n; r++) {
					if (ind[r] == 1) pl[cc[r]] = 1
				}
			}
			else {
				// this window's bit among the variable's windows
				nw = 0
				for (i = 1; i <= q; i++) {
					if (rk[i] == "C" & rv[i] == vnames[j]) nw++
				}
				for (c = 1; c <= L; c++) pl[c] = mod(floor((c - 1) / 2^nw), 2)
			}
			S.qkind = S.qkind \ 2
			S.qvar = S.qvar \ j
			S.qmap = S.qmap \ &(pl :+ 0)
			QF = QF, fl
			QFO = QFO, rfo[q]
		}
		else if (kd == "N" | kd == "V0" | kd == "V1") {
			vl = *S.vals[j]
			pl = J(L, 1, 0)
			for (c = 1; c <= L; c++) {
				if (kd == "N") pl[c] = (vl[c] < . & vl[c] != 0 & vl[c] != 1)
				else if (kd == "V0") pl[c] = (vl[c] == 0)
				else pl[c] = (vl[c] == 1)
			}
			S.qkind = S.qkind \ 2
			S.qvar = S.qvar \ j
			S.qmap = S.qmap \ &(pl :+ 0)
			QF = QF, fl
			QFO = QFO, rfo[q]
		}
		else if (kd == "F") {
			// the table of variable j in each group: rows by count
			// (descending) then value, withheld cells, the maxfreq cut
			S.hasF[j] = 1
			TCo = *S.TCODE[j]
			SUPm = J(S.G, L, 0)
			ind = st_data(., ri[q])
			cc = *S.code[j]
			for (r = 1; r <= n; r++) {
				if (ind[r] == 1) SUPm[S.grp[r], cc[r]] = 1
			}
			PO = J(S.G, L, 0)
			OR = J(S.G, L, 0)
			ST = J(S.G, L, 0)
			for (g = 1; g <= S.G; g++) {
				w = selectindex(TCo[g, .]' :> 0)
				if (length(w) == 0) continue
				w = vec(w)
				o = order((-TCo[g, w]', w), (1, 2))
				w = w[o]
				for (i = 1; i <= rows(w); i++) {
					PO[g, w[i]] = i
					OR[g, i] = w[i]
					if (i > S.maxf) ST[g, w[i]] = 2
					else if (SUPm[g, w[i]] | TCo[g, w[i]] < S.cell) ST[g, w[i]] = 1
				}
			}
			S.POS[j] = &(PO :+ 0)
			S.ORD[j] = &(OR :+ 0)
			S.STAT[j] = &(ST :+ 0)
			S.SUP[j] = &(SUPm :+ 0)
			for (c = 1; c <= L; c++) {
				pl = J(L, 1, 0)
				pl[c] = 1
				S.qkind = S.qkind \ 4
				S.qvar = S.qvar \ j
				S.qmap = S.qmap \ &(pl :+ 0)
				QF = QF, "r"
				QFO = QFO, ""
			}
		}
	}
	S.nq = rows(S.qkind)
	nq = S.nq
	// the non-I quantities each variable's values enter; the I quantities
	// of each set
	S.affq = J(nv, 1, NULL)
	for (j = 1; j <= nv; j++) {
		idx = J(1, 0, .)
		for (q = 1; q <= nq; q++) {
			if (S.qkind[q] != 3 & S.qvar[q] == j) idx = idx, q
		}
		S.affq[j] = &(idx :+ 0)
	}
	// per variable, which of its quantities (positions in affq) count
	// each code: rows (code, position), so a move of a few codes visits
	// only the quantities it can change (_dpa_maff); and the pooled
	// table's counts (_dpa_moves reads them on every try)
	S.AQI = J(nv, 1, NULL)
	S.TCS = J(nv, 1, NULL)
	for (j = 1; j <= nv; j++) {
		idx = *S.affq[j]
		x0 = J(0, 1, .)
		w = J(0, 1, .)
		for (i = 1; i <= cols(idx); i++) {
			o = selectindex((*S.qmap[idx[i]]) :!= 0)
			if (length(o) == 0) continue
			x0 = x0 \ vec(o)
			w = w \ J(length(o), 1, i)
		}
		S.AQI[j] = &((x0, w) :+ 0)
		S.TCS[j] = &(colsum(*S.TCODE[j]))
	}
	// each table's printed rows at the true counts, once (_dpa_rankok)
	S.TTP = J(nv, 1, NULL)
	S.TTG = J(nv, S.G, NULL)
	S.qofset = J(max((ns, 1)), 1, NULL)
	for (s = 1; s <= max((ns, 1)); s++) {
		idx = J(1, 0, .)
		for (q = 1; q <= nq; q++) {
			if (S.qkind[q] == 3 & S.qvar[q] == s) idx = idx, q
		}
		S.qofset[s] = &(idx :+ 0)
	}
	// counts per group and over all rows
	S.K = J(S.G, nq, 0)
	for (q = 1; q <= nq; q++) {
		if (S.qkind[q] == 3) S.K[., q] = S.IS[., S.qvar[q]]
		else S.K[., q] = (*S.TCODE[S.qvar[q]]) * (*S.qmap[q])
	}
	S.T = colsum(S.K)
	// the class of each total as the pooled blocks print it: a missing
	// count (MISSINGNESS; exact beside the patterns table), complete cases
	// in the header, the rows outside a date window (DATE); other totals
	// follow from the pooled frequency tables, checked per level
	S.PLO = J(1, nq, 0)
	S.PHI = J(1, nq, S.N)
	for (q = 1; q <= nq; q++) {
		fl = QF[q]
		if (S.qkind[q] == 1) {
			cp = (S.pat ? (S.T[q], S.T[q]) : _dpa_cnt(S.T[q], S.N, S.m, 0))
			S.PLO[q] = cp[1]
			S.PHI[q] = cp[2]
		}
		else if (S.qkind[q] == 3) {
			if (strpos(fl, "h")) {
				cp = _dpa_cnt(S.N - S.T[q], S.N, S.m, 0)
				S.PLO[q] = S.N - cp[2]
				S.PHI[q] = S.N - cp[1]
			}
		}
		else if (S.qkind[q] == 2 & strpos(fl, "w")) {
			cp = _dpa_cnt(S.T[q], S.N, S.m, 0)
			S.PLO[q] = cp[1]
			S.PHI[q] = cp[2]
		}
	}
	// every I quantity of a set shares its pooled class (the tightest)
	for (s = 1; s <= ns; s++) {
		idx = *S.qofset[s]
		lo = max(S.PLO[idx])
		hi = min(S.PHI[idx])
		S.PLO[idx] = J(1, cols(idx), lo)
		S.PHI[idx] = J(1, cols(idx), hi)
	}
	// what each shown group prints, as a class; a pooled group's gate says
	// only whether a count (or its complement) is zero
	S.LO = J(S.G, nq, 0)
	S.HI = J(S.G, nq, 0)
	for (g = 1; g <= S.G; g++) S.HI[g, .] = J(1, nq, S.nsz[g])
	S.TZ = J(S.G, nq, 0)
	S.TZC = J(S.G, nq, 0)
	for (q = 1; q <= nq; q++) {
		fl = QF[q]
		fo = strtoreal(tokens(QFO[q]))
		for (g = 1; g <= S.G; g++) {
			k = S.K[g, q]
			n = S.nsz[g]
			if (S.ispool[g]) {
				if (strpos(fl, "g")) {
					S.TZ[g, q] = 1
					if (!strpos(fl, "z")) S.TZC[g, q] = 1
				}
				continue
			}
			lo = 0
			hi = n
			if (strpos(fl, "c")) {
				cp = _dpa_cnt(k, n, S.m, anyof(fo, g))
				lo = max((lo, cp[1]))
				hi = min((hi, cp[2]))
			}
			if (strpos(fl, "p")) {
				cp = _dpa_cnt(n - k, n, S.m, anyof(fo, g))
				lo = max((lo, n - cp[2]))
				hi = min((hi, n - cp[1]))
			}
			if (strpos(fl, "z")) {
				if (k == 0) hi = 0
				else lo = max((lo, 1))
			}
			if (strpos(fl, "r")) {
				j = S.qvar[q]
				c = selectindex(*S.qmap[q])
				if (k == 0) hi = 0
				else if ((*S.STAT[j])[g, c] == 0) {
					lo = k
					hi = k
				}
				else if ((*S.STAT[j])[g, c] == 1) {
					lo = max((lo, 1))
					if (S.cell > 0) {
						if (k < S.cell) hi = min((hi, S.cell - 1))
						else lo = max((lo, S.cell))
					}
					if (S.rare > 0) {
						if (k < S.rare) hi = min((hi, S.rare - 1))
						else lo = max((lo, S.rare))
					}
				}
				else lo = max((lo, 1))
			}
			S.LO[g, q] = lo
			S.HI[g, q] = hi
		}
	}
	// the counts to protect, and a twin table for each
	nP = sum(S.nsz :* S.ispool)
	nsens = 0
	fails = ""
	failE = J(S.G, 1, 0)
	failP = J(0, 3, .)
	failV = J(0, 3, .)
	// capped: a count left unproven after the budget ran out (a twin may
	// exist beyond it); the audit stops there and the caller withholds
	// every group's audited counts
	capped = 0
	for (q = 1; q <= nq & !capped; q++) {
		for (g = 1; g <= S.G & !capped; g++) {
			k = S.K[g, q]
			n = S.nsz[g]
			valsens = (k >= 1 & k < S.m)
			cmpsens = (n - k >= 1 & n - k < S.m)
			// a count equal to the call's total (or a complement equal to
			// the call's complement) says no more than that total, which
			// the pooled blocks mask by their own rule
			if (valsens & k == S.T[q]) valsens = 0
			if (cmpsens & n - k == S.N - S.T[q]) cmpsens = 0
			if (!valsens & !cmpsens) continue
			if (!S.ispool[g] & S.LO[g, q] == S.HI[g, q]) continue
			nsens++
			if (S.ispool[g]) {
				ok = _dpa_wit(S, q, g, 0)
				if (!ok & valsens & !cmpsens) ok = _dpa_movewit(S, q, g, 1)
				if (!ok & cmpsens & !valsens) ok = _dpa_movewit(S, q, g, 0)
				if (!ok) {
					ok = 1
					if (valsens) ok = _dpa_lp(S, q, g, 0, 0)
					if (ok & cmpsens) ok = _dpa_lp(S, q, g, 0, 1)
				}
				if (!ok) {
					failP = failP \ (q, g, valsens)
					fails = fails + " " + strofreal(q) + ":" + strofreal(g) + "p"
					capped = (S.used > S.budget)
				}
			}
			else if (!_dpa_wit(S, q, g, 0) & !_dpa_lp(S, q, g, 0, 0)) {
				failE[g] = 1
				capped = (S.used > S.budget)
				fails = fails + " " + strofreal(q) + ":" + strofreal(g) + "[" + (S.qkind[q] == 3 ? "I" + strofreal(S.qvar[q]) : vnames[S.qvar[q]] + (S.qkind[q] == 4 ? "#" + strofreal(selectindex(*S.qmap[q])) : "") + "/" + strofreal(S.qkind[q])) + " k=" + strofreal(k) + " cls=" + strofreal(S.LO[g,q]) + "-" + strofreal(S.HI[g,q]) + "]"
			}
		}
		// the pooled-away groups' total
		if (nP > 0 & !capped) {
			R = sum(S.K[., q] :* S.ispool)
			valsens = (R >= 1 & R < S.m)
			cmpsens = (nP - R >= 1 & nP - R < S.m)
			if (valsens & R == S.T[q]) valsens = 0
			if (cmpsens & nP - R == S.N - S.T[q]) cmpsens = 0
			if (valsens | cmpsens) {
				nsens++
				ok = 0
				for (g = 1; g <= S.G & !ok; g++) {
					if (S.ispool[g]) ok = _dpa_wit(S, q, g, 1)
				}
				if (!ok) ok = _dpa_lp(S, q, 0, 1, 0)
				if (!ok) {
					failV = failV \ (q, 0, valsens)
					fails = fails + " " + strofreal(q) + ":pool"
					capped = (S.used > S.budget)
				}
			}
		}
	}
	nfail = sum(failE) + rows(failP) + rows(failV)
	// one shown group to pool: the smallest failing one; for a pooled
	// count, the shown group with the fewest rows of the kind it lacks
	best = 0
	bestn = .
	for (g = 1; g <= S.G; g++) {
		if (failE[g] & S.nsz[g] < bestn) {
			best = g
			bestn = S.nsz[g]
		}
	}
	if (best == 0 & (rows(failP) + rows(failV)) > 0) {
		if (rows(failV) > 0) {
			q = failV[1, 1]
			need = failV[1, 3]
		}
		else {
			q = failP[1, 1]
			need = failP[1, 3]
		}
		for (g = 1; g <= S.G; g++) {
			if (S.ispool[g]) continue
			x = (need ? S.K[g, q] : S.nsz[g] - S.K[g, q])
			if (x > 0 & x < bestn) {
				best = g
				bestn = x
			}
		}
		if (best == 0) {
			for (g = 1; g <= S.G; g++) {
				if (!S.ispool[g] & S.nsz[g] < bestn) {
					best = g
					bestn = S.nsz[g]
				}
			}
		}
	}
	resid = (best == 0 ? nfail : 0)
	st_local("_dpa_add", (best > 0 ? strofreal(best) : ""))
	st_local("_dpa_nsens", strofreal(nsens))
	st_local("_dpa_nfail", strofreal(nfail))
	st_local("_dpa_resid", strofreal(resid))
	st_local("_dpa_fails", strtrim(fails))
	st_local("_dpa_used", strofreal(S.used, "%20.0f"))
	st_local("_dpa_capped", strofreal(capped))
}

// the pooled groups (see _dataprobe_poolfill), as a list in the order the
// groups joined
void _dpa_poolfill()
{
	real colvector grp, nsz, isp
	real rowvector pool, out
	real scalar G, i, g, np, ps, best, bestn, m
	grp = st_data(., st_local("_dpa_grp"))
	m = strtoreal(st_local("_dpa_m"))
	G = max(grp)
	nsz = J(G, 1, 0)
	for (i = 1; i <= rows(grp); i++) nsz[grp[i]] = nsz[grp[i]] + 1
	isp = J(G, 1, 0)
	out = J(1, 0, .)
	for (g = 1; g <= G; g++) {
		if (nsz[g] > 0 & nsz[g] < m) {
			isp[g] = 1
			out = out, g
		}
	}
	pool = strtoreal(tokens(st_local("_dpa_pooled")))
	for (i = 1; i <= cols(pool); i++) {
		if (!isp[pool[i]]) {
			isp[pool[i]] = 1
			out = out, pool[i]
		}
	}
	while (1) {
		np = sum(isp)
		if (np == 0) break
		ps = sum(nsz :* isp)
		if (np >= 2 & ps >= m) break
		best = 0
		bestn = .
		for (g = 1; g <= G; g++) {
			if (!isp[g] & nsz[g] > 0 & nsz[g] < bestn) {
				best = g
				bestn = nsz[g]
			}
		}
		if (best == 0) break
		isp[best] = 1
		out = out, best
	}
	st_local("_dpa_out", invtokens(strofreal(out)))
}
end

*! _datacheck_keyset Version 1.8.2  2026/10/01
*! datacheck keyset(): the same distinct keys as a saved dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: varlist using filename [, equal | subset | superset]   (default equal)
//
// The distinct values of varlist in datacheck's working sample are compared
// with the distinct values in filename, read into a frame.  subset: every key
// in memory exists in the file.  superset: every key in the file exists in
// memory.  equal: both.  Equal counts with different members (a person lost
// and another gained) fail, which a count comparison cannot see.
//
// r(only_master) and r(only_using) are the raw counts; the console and the
// record carry them masked.  parseonly validates the spec and the file.
program define _datacheck_keyset, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local om_n = .
    local ou_n = .
    local vars ""
    local file ""
    local mode ""
    local _kf_made = 0
    local _mf_made = 0
    tempname kf mf
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0)]
        // an entry written as one quoted token, keyset("id using f.dta"),
        // is unwrapped: 1.8.0 read the option with its quotes stripped
        local _sw = strtrim(`"`spec'"')
        if substr(`"`_sw'"', 1, 1) == char(34) | substr(`"`_sw'"', 1, 2) == char(96) + char(34) {
            gettoken _tok _rem : _sw, qed(_wq)
            if `_wq' & strtrim(`"`_rem'"') == "" local spec `"`_tok'"'
        }
        local up = strpos(`"`spec'"', " using ")
        if `up' == 0 {
            display as error `"keyset() spec must be "varlist using filename [, equal|subset|superset]": `spec'"'
            exit 198
        }
        local vars = strtrim(substr(`"`spec'"', 1, `up' - 1))
        local rest = strtrim(substr(`"`spec'"', `up' + 7, .))
        local opts ""
        if substr(`"`rest'"', 1, 1) == char(34) | substr(`"`rest'"', 1, 2) == char(96) + char(34) {
            // a quoted filename may itself contain a comma
            gettoken file rest : rest, qed(_q)
            local rest = strtrim(`"`rest'"')
            if substr(`"`rest'"', 1, 1) == "," local opts = strtrim(substr(`"`rest'"', 2, .))
            else if `"`rest'"' != "" {
                display as error `"keyset() spec must be "varlist using filename [, equal|subset|superset]": `spec'"'
                exit 198
            }
        }
        else {
            local cp = strpos(`"`rest'"', ",")
            if `cp' {
                local opts = strtrim(substr(`"`rest'"', `cp' + 1, .))
                local rest = strtrim(substr(`"`rest'"', 1, `cp' - 1))
            }
            local file `"`rest'"'
        }
        local file = strtrim(subinstr(`"`file'"', char(34), "", .))
        unab vars : `vars'
        local mode = lower(`"`opts'"')
        if "`mode'" == "" local mode "equal"
        if !inlist("`mode'", "equal", "subset", "superset") {
            display as error "keyset(): option must be equal, subset, or superset; got `opts'"
            exit 198
        }
        _datamap_validate_path `"`file'"', option(keyset())
        capture confirm file `"`file'"'
        if _rc {
            capture confirm file `"`file'.dta"'
            if _rc {
                display as error `"keyset(): file `file' not found"'
                exit 601
            }
            local file `"`file'.dta"'
        }
        if "`parseonly'" == "" {
            mata: st_local("fbase", pathrmsuffix(pathbasename(st_local("file"))))
            frame create `kf'
            local _kf_made = 1
            frame `kf' {
                capture use `vars' using `"`file'"', clear
                if _rc {
                    local _urc = _rc
                    display as error `"keyset(): cannot read `vars' from `file'"'
                    exit `_urc'
                }
                quietly bysort `vars': keep if _n == 1
            }
            frame put `vars', into(`mf')
            local _mf_made = 1
            tempvar lk lm
            frame `mf' {
                quietly bysort `vars': keep if _n == 1
                capture frlink 1:1 `vars', frame(`kf') generate(`lk')
                if _rc {
                    local _lrc = _rc
                    display as error "keyset(): keys in memory and in `fbase' have incompatible types"
                    exit `_lrc'
                }
                quietly count if missing(`lk')
                local om_n = r(N)
            }
            frame `kf' {
                quietly frlink 1:1 `vars', frame(`mf') generate(`lm')
                quietly count if missing(`lm')
                local ou_n = r(N)
            }
            _datacheck_mcount `om_n' `mask'
            local oms "`r(s)'"
            local m1 = r(masked)
            _datacheck_mcount `ou_n' `mask'
            local ous "`r(s)'"
            local m2 = r(masked)
            local om = (`m1' | `m2')
            if `om' local anymask = 1
            local mins = .
            if !`m1' & `om_n' >= 1 local mins = `om_n'
            if !`m2' & `ou_n' >= 1 local mins = min(`mins', `ou_n')
            if "`mode'" == "equal" local ok = (`om_n' == 0 & `ou_n' == 0)
            else if "`mode'" == "subset" local ok = (`om_n' == 0)
            else local ok = (`ou_n' == 0)
            local obs "`oms' keys not in `fbase'; `ous' keys of `fbase' absent"
            local onum = .
            if "`mode'" == "subset" & !`m1' local onum = `om_n'
            else if "`mode'" == "superset" & !`m2' local onum = `ou_n'
            else if "`mode'" == "equal" & !`om' local onum = `om_n' + `ou_n'
            if !`ok' local ++nfail
            local msg `"`pfx'keyset(`vars'): `mode' — `obs'"'
            frame post `rf' ("keyset") ("`kind'") (`ok') ("`vars'") ("`vars'") ///
                (`"`macval(grp)'"') (`"`obs'"') (`onum') ("`mode' `fbase'") ///
                (`nscope') ("") (`"`macval(msg)'"') (`mins') (`om')
        }
    }
    local rc = _rc
    if `_mf_made' capture frame drop `mf'
    if `_kf_made' capture frame drop `kf'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    return local file `"`file'"'
    return local mode "`mode'"
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
    return scalar only_master = `om_n'
    return scalar only_using = `ou_n'
end

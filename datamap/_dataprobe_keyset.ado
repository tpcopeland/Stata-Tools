*! _dataprobe_keyset Version 2.0.0  2026/11/10
*! dataprobe keyset(): the same distinct keys as a saved dataset
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// Spec: varlist using filename [, equal | subset | superset]   (default equal)
//
// The distinct values of varlist in dataprobe's working sample are compared
// with the distinct values in filename, read into a frame.  subset: every key
// in memory exists in the file.  superset: every key in the file exists in
// memory.  equal: both.  Equal counts with different members (a person lost
// and another gained) fail, which a count comparison cannot see.
//
// r(only_master) and r(only_using) are the raw counts; the console and the
// record carry them masked.  parseonly validates the spec and the file.
//
// Preflight (2.0.0, W1), printed before the verdict, under gatesonly too:
//   KEYSET PREFLIGHT: id using ids
//     types: id long in memory, long in ids
//     unique: memory yes, ids no; merge 1:m
//     keys: 45 matched, 5 memory only, 5 ids only
//     merge 1:m would report: 45 matched, 5 master only, 5 using only
//     shared non-key variables: sex
// A key variable that is numeric on one side and string on the other is a
// failed entry, reported before any count ("type conflict"); -merge- would
// stop with r(106).  Widths and numeric types are not conflicts.  The row
// counts are the ones -merge- reports for the implied merge type (a matched
// key gives max(rows in memory, rows in the file) result rows).  Every
// count obeys mask() as the verdict's counts do; r() is unmasked.
program define _dataprobe_keyset, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local om_n = .
    local ou_n = .
    local mt_n = .
    local rmt = .
    local rmo = .
    local ruo = .
    local mtype ""
    local conflict = 0
    local vars ""
    local file ""
    local mode ""
    local _kf_made = 0
    local _mf_made = 0
    tempname kf mf
    capture noisily {
        syntax , SPEC(string) [PARSEonly RF(name) KIND(string) GRP(string) ///
            PFX(string) MASK(integer 0) NSCOPE(real 0) DATAvars(string)]
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
            }
            // ---- preflight: types first; a conflict is a failure, no count ----
            local tline ""
            local ctext ""
            foreach v of local vars {
                local tm : type `v'
                frame `kf': local tu : type `v'
                local tline "`tline'`=cond("`tline'" == "", "", "; ")'`v' `tm' in memory, `tu' in `fbase'"
                if (substr("`tm'", 1, 3) == "str") != (substr("`tu'", 1, 3) == "str") {
                    local conflict = 1
                    local ctext "`ctext'`=cond("`ctext'" == "", "", "; ")'`v' `tm' in memory, `tu' in `fbase'"
                }
            }
            display ""
            display as text "KEYSET PREFLIGHT: " as result `"`vars' using `fbase'"'
            display as text "  types: " as result "`tline'"
            if `conflict' {
                display as text "  " as error "type conflict (numeric and string): merge would stop with r(106)"
                local obs "type conflict: `ctext'"
                local msg `"`pfx'keyset(`vars'): `mode' — `obs'"'
                local ++nfail
                frame post `rf' ("keyset") ("`kind'") (0) ("`vars'") ("`vars'") ///
                    (`"`macval(grp)'"') (`"`obs'"') (.) ("`mode' `fbase'") ///
                    (`nscope') ("") (`"`macval(msg)'"') (.) (0)
            }
            else {
            tempvar nk lk lm nu
            frame `kf' {
                quietly bysort `vars': generate double `nu' = _N
                quietly by `vars': keep if _n == 1
                quietly count if `nu' > 1
                local uu = (r(N) == 0)
            }
            frame put `vars', into(`mf')
            local _mf_made = 1
            frame `mf' {
                quietly bysort `vars': generate double `nk' = _N
                quietly by `vars': keep if _n == 1
                quietly count if `nk' > 1
                local um = (r(N) == 0)
                capture frlink 1:1 `vars', frame(`kf') generate(`lk')
                if _rc {
                    local _lrc = _rc
                    display as error "keyset(): keys in memory and in `fbase' have incompatible types"
                    exit `_lrc'
                }
                quietly count if missing(`lk')
                local om_n = r(N)
                local mt_n = _N - `om_n'
                local tk_m = _N
                quietly summarize `nk', meanonly
                local tr_m = r(sum)
                quietly frget `nu' = `nu', from(`lk')
                // the rows -merge- reports: a matched key gives the larger
                // of its two row counts
                quietly summarize `nk' if missing(`lk'), meanonly
                local rmo = r(sum)
                quietly summarize `nk' if !missing(`lk'), meanonly
                local smk = r(sum)
                tempvar mx
                quietly generate double `mx' = max(`nk', `nu') if !missing(`lk')
                quietly summarize `mx', meanonly
                local rmt = r(sum)
            }
            frame `kf' {
                quietly frlink 1:1 `vars', frame(`mf') generate(`lm')
                quietly count if missing(`lm')
                local ou_n = r(N)
                local tk_u = _N
                quietly summarize `nu', meanonly
                local tr_u = r(sum)
                quietly summarize `nu' if missing(`lm'), meanonly
                local ruo = r(sum)
                local smu = `tr_u' - `ruo'
            }
            local mtype = cond(`um', "1", "m") + ":" + cond(`uu', "1", "m")
            // shared names outside the key: -merge- keeps memory's values
            quietly describe using `"`file'"', varlist
            local fvars `"`r(varlist)'"'
            local shared : list datavars & fvars
            local shared : list shared - vars
            display as text "  unique: " as result "memory " cond(`um', "yes", "no") ///
                ", `fbase' " cond(`uu', "yes", "no") as text "; merge " as result "`mtype'"
            // Each count is masked beside the total it adds up to, as the
            // other dataprobe tables are (2.0.0 review fix).  Keys: matched +
            // memory only = memory's distinct keys (KEY STRUCTURE prints
            // them) and matched + file only = the file's distinct keys, so a
            // small cell on either side withholds the matched count too
            // ("all but <m"), and a small matched count withholds both
            // one-sided counts.  Rows: master only + its matched rows =
            // memory's rows (the header's N) and using only + its matched
            // rows = the file's rows; the matched row count is tested
            // against a total only where it equals that side's matched rows
            // (always for 1:1, m:1 and 1:m), where the subtraction is exact.
            _dataprobe_mcount `mt_n' `mask' `tk_m'
            local _s_mt_n "`r(s)'"
            local _m_mt = r(masked)
            if !`_m_mt' {
                _dataprobe_mcount `mt_n' `mask' `tk_u'
                local _s_mt_n "`r(s)'"
                local _m_mt = r(masked)
            }
            _dataprobe_mcount `om_n' `mask' `tk_m'
            local oms "`r(s)'"
            local m1 = r(masked)
            _dataprobe_mcount `ou_n' `mask' `tk_u'
            local ous "`r(s)'"
            local m2 = r(masked)
            if `_m_mt' | `m1' | `m2' local anymask = 1
            display as text "  keys: " as result "`_s_mt_n'" as text " matched, " ///
                as result "`oms'" as text " memory only, " ///
                as result "`ous'" as text " `fbase' only"
            _dataprobe_mcount `rmo' `mask' `tr_m'
            local _s_rmo "`r(s)'"
            if r(masked) local anymask = 1
            _dataprobe_mcount `ruo' `mask' `tr_u'
            local _s_ruo "`r(s)'"
            if r(masked) local anymask = 1
            _dataprobe_mcount `rmt' `mask'
            local _s_rmt "`r(s)'"
            local _m_rmt = r(masked)
            if !`_m_rmt' & `rmt' == `smk' {
                _dataprobe_mcount `rmt' `mask' `tr_m'
                local _s_rmt "`r(s)'"
                local _m_rmt = r(masked)
            }
            if !`_m_rmt' & `rmt' == `smu' {
                _dataprobe_mcount `rmt' `mask' `tr_u'
                local _s_rmt "`r(s)'"
                local _m_rmt = r(masked)
            }
            if `_m_rmt' local anymask = 1
            display as text "  merge `mtype' would report: " as result "`_s_rmt'" as text " matched, " ///
                as result "`_s_rmo'" as text " master only, " ///
                as result "`_s_ruo'" as text " using only"
            if "`shared'" == "" display as text "  shared non-key variables: " as result "(none)"
            else display as text "  shared non-key variables: " as result "`shared'"
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
    return scalar matched = `mt_n'
    return scalar rows_matched = `rmt'
    return scalar rows_master = `rmo'
    return scalar rows_using = `ruo'
    return scalar conflict = `conflict'
    return local merge "`mtype'"
end

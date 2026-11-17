*! _dataprobe_keyset Version 2.1.0  2026/11/16
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
//
// 2.1.0 (R2): a strL key variable, in memory or in the file, is a failed
// entry reported the same way ("strL key"), since -merge- refuses a strL
// key with r(106) on either side (frlink, which keyset uses, would not);
// the message names the variable and suggests recast str# or compress.
// r(strl) is 1 then.
//
// 2.1.0 (F11): asof(mdate udate) or window(mstart mend udate) after the
// comma adds a linkage diagnostic by key and date (_dataprobe_kwindow):
// per master row, the using rows of its key on or before mdate (asof) or
// inside [mstart, mend] (window), counted 0, 1, more than 1, with as-of ties
// and maxlag() staleness, or the pairs a -joinby- would create.  The file
// is read once (key and using date); nothing is joined.  maxnone(),
// maxmulti(), maxties(), maxstale() (shares) add gate records; without them
// the diagnostic is a review record.  With asof()/window() the key-set
// verdict runs only when equal, subset or superset is named.
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
    local strl = 0
    local vars ""
    local file ""
    local mode ""
    local link ""
    local ldates ""
    local ludate ""
    local jpairs = 0
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
        if !inlist("`mode'", "equal", "subset", "superset") & strpos(`"`opts'"', "(") {
            // 2.1.0 (F11): asof()/window() and their thresholds
            local 0 `", `opts'"'
            local _u = -999999999
            capture syntax [, EQUAL SUBSET SUPERSET ASOF(string) WINDOW(string) MAXLag(real `_u') ///
                MAXNone(real `_u') MAXMulti(real `_u') MAXTies(real `_u') MAXStale(real `_u')]
            if _rc {
                display as error "keyset(): after the comma: equal|subset|superset, asof(), window(), maxlag(), maxnone(), maxmulti(), maxties(), maxstale(); got `opts'"
                exit 198
            }
            local mode = strtrim("`equal' `subset' `superset'")
            local link = cond(`"`asof'"' != "", "asof", cond(`"`window'"' != "", "window", ""))
            local _nw : word count `asof' `window'
            local _want = cond("`link'" == "asof", 2, 3)
            if `: word count `mode'' > 1 | "`link'" == "" | (`"`asof'"' != "" & `"`window'"' != "") | `_nw' != `_want' {
                display as error "keyset(): give asof(mdate udate) or window(mstart mend udate), and at most one of equal, subset, superset; got `opts'"
                exit 198
            }
            local _lw `asof' `window'
            local ludate : word `_want' of `_lw'
            // by position: the file's date may share a master date's name
            local ldates : word 1 of `_lw'
            if `_want' == 3 local ldates "`ldates' `: word 2 of `_lw''"
            unab ldates : `ldates'
            capture confirm numeric variable `ldates'
            if _rc {
                display as error "keyset(): `link'() needs numeric (date) variables in memory: `ldates'"
                exit 109
            }
            confirm name `ludate'
            local _dk : list ldates & vars
            if `: list ludate in vars' | "`_dk'" != "" {
                display as error "keyset(): a date in `link'() is also a key variable"
                exit 198
            }
            if "`link'" == "window" & (`maxlag' != `_u' | `maxties' != `_u' | `maxstale' != `_u') {
                display as error "keyset(): maxlag(), maxties() and maxstale() go with asof()"
                exit 198
            }
            if (`maxstale' != `_u' & `maxlag' == `_u') | (`maxlag' != `_u' & `maxlag' < 0) {
                display as error "keyset(): maxstale() needs maxlag(#), a lag of 0 or more"
                exit 198
            }
            foreach _t in maxnone maxmulti maxties maxstale {
                if ``_t'' != `_u' & (``_t'' < 0 | ``_t'' > 1) {
                    display as error "keyset(): `_t'() must be a share between 0 and 1"
                    exit 198
                }
            }
        }
        else if !inlist("`mode'", "equal", "subset", "superset") {
            display as error "keyset(): option must be equal, subset, or superset; got `opts'"
            exit 198
        }
        _datamap_validate_path `"`file'"', option(keyset())
        capture confirm file `"`file'"'
        if _rc {
            // a name that already ends in .dta is the file itself: it never
            // falls back to name.dta.dta (_rc stays the first confirm's)
            if lower(substr(`"`file'"', -4, 4)) != ".dta" capture confirm file `"`file'.dta"'
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
                capture use `vars' `ludate' using `"`file'"', clear
                if _rc {
                    local _urc = _rc
                    display as error `"keyset(): cannot read `vars' `ludate' from `file'"'
                    exit `_urc'
                }
                if "`ludate'" != "" {
                    capture confirm numeric variable `ludate'
                    if _rc {
                        display as error `"keyset(): `ludate' in `file' is not numeric; `link'() needs a date"'
                        exit 109
                    }
                }
            }
            // ---- preflight: types first; a conflict is a failure, no count ----
            local tline ""
            local ctext ""
            local ltext ""
            local lvars ""
            foreach v of local vars {
                local tm : type `v'
                frame `kf': local tu : type `v'
                local tline "`tline'`=cond("`tline'" == "", "", "; ")'`v' `tm' in memory, `tu' in `fbase'"
                if (substr("`tm'", 1, 3) == "str") != (substr("`tu'", 1, 3) == "str") {
                    local conflict = 1
                    local ctext "`ctext'`=cond("`ctext'" == "", "", "; ")'`v' `tm' in memory, `tu' in `fbase'"
                }
                if "`tm'" == "strL" | "`tu'" == "strL" {
                    local strl = 1
                    local lvars "`lvars' `v'"
                    local _side = cond("`tm'" == "strL" & "`tu'" == "strL", "in memory and in `fbase'", ///
                        cond("`tm'" == "strL", "in memory", "in `fbase'"))
                    local ltext "`ltext'`=cond("`ltext'" == "", "", "; ")'`v' strL `_side'"
                }
            }
            local lvars = strtrim("`lvars'")
            display ""
            display as text "KEYSET PREFLIGHT: " as result `"`vars' using `fbase'"'
            display as text "  types: " as result "`tline'"
            if `conflict' | `strl' {
                if `conflict' display as text "  " as error "type conflict (numeric and string): merge would stop with r(106)"
                if `strl' {
                    display as text "  " as error "strL key (`lvars'): merge would stop with r(106); recast str# `lvars' (or compress) on that side first"
                }
                local obs ""
                if `conflict' local obs "type conflict: `ctext'"
                if `strl' local obs "`obs'`=cond("`obs'" == "", "", "; ")'strL key: `ltext'; recast str# before merging"
                local _mt = cond("`mode'" == "", "`link'", "`mode'")
                if "`link'" != "" display as text "  `link'(): not run; the keys cannot be joined"
                local msg `"`pfx'keyset(`vars'): `_mt' — `obs'"'
                local ++nfail
                frame post `rf' ("keyset") ("`kind'") (0) ("`vars'") ("`vars'") ///
                    (`"`macval(grp)'"') (`"`obs'"') (.) ("`_mt' `fbase'") ///
                    (`nscope') ("") (`"`macval(msg)'"') (.) (0)
            }
            else {
            tempvar nk lk lm nu jp
            tempname KW
            // F11: the linkage counts need the file's rows, before the
            // preflight reduces them to one per key
            if "`link'" != "" {
                _dataprobe_kwindow, vars(`vars') link(`link') dates(`ldates') ///
                    udate(`ludate') uframe(`kf') res(`KW') maxlag(`maxlag')
            }
            // generate, then by-replace: on zero rows -by: generate- makes
            // no variable at all (2.1.0, R2: an empty sample or file was
            // r(111) here)
            frame `kf' {
                quietly generate double `nu' = .
                quietly bysort `vars': replace `nu' = _N
                quietly by `vars': keep if _n == 1
                quietly count if `nu' > 1
                local uu = (r(N) == 0)
            }
            frame put `vars', into(`mf')
            local _mf_made = 1
            frame `mf' {
                quietly generate double `nk' = .
                quietly bysort `vars': replace `nk' = _N
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
                // F11: the pairs -joinby- makes, before any date condition
                quietly generate double `jp' = `nk' * `nu' if !missing(`lk')
                quietly summarize `jp', meanonly
                local jpairs = r(sum)
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
            if "`link'" != "" {
                _dataprobe_kwindow, vars(`vars') link(`link') dates(`ldates') udate(`ludate') ///
                    res(`KW') show maxlag(`maxlag') maxnone(`maxnone') maxmulti(`maxmulti') ///
                    maxties(`maxties') maxstale(`maxstale') jpairs(`jpairs') pmask(`anymask') ///
                    rf(`rf') kind(`kind') grp(`"`macval(grp)'"') pfx(`"`pfx'"') mask(`mask') ///
                    nscope(`nscope') fbase(`fbase')
                local nfail = `nfail' + r(nfail)
                if r(masked) local anymask = 1
                return add
            }
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
            // with asof()/window() and no mode word, no key-set verdict
            if "`mode'" != "" {
                if !`ok' local ++nfail
                local msg `"`pfx'keyset(`vars'): `mode' — `obs'"'
                frame post `rf' ("keyset") ("`kind'") (`ok') ("`vars'") ("`vars'") ///
                    (`"`macval(grp)'"') (`"`obs'"') (`onum') ("`mode' `fbase'") ///
                    (`nscope') ("") (`"`macval(msg)'"') (`mins') (`om')
            }
            }
        }
    }
    local rc = _rc
    if `_mf_made' capture frame drop `mf'
    if `_kf_made' capture frame drop `kf'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    // parseonly: the master dates of asof()/window() are columns to keep
    if "`parseonly'" != "" local vars "`vars' `ldates'"
    return local vars "`vars'"
    return local file `"`file'"'
    return local mode "`mode'"
    return local link "`link'"
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
    return scalar only_master = `om_n'
    return scalar only_using = `ou_n'
    return scalar matched = `mt_n'
    return scalar rows_matched = `rmt'
    return scalar rows_master = `rmo'
    return scalar rows_using = `ruo'
    return scalar conflict = `conflict'
    return scalar strl = `strl'
    return local merge "`mtype'"
end

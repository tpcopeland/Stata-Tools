*! _dataprobe_kwindow Version 2.1.0  2026/11/16
*! dataprobe keyset() asof()/window(): linkage counts by key and date
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper)

// Called twice by _dataprobe_keyset for an entry with asof() or window().
//
// Compute (no show): the current frame holds dataprobe's working sample
// (the master rows); uframe() holds the file's rows of the key and the
// using date, read once by keyset.  The master rows' keys and dates are
// appended to uframe() as markers, one sort by key, date and marker type
// counts the using rows before each marker, and the markers are dropped
// again, so uframe() leaves with its own rows (in another order).  Nothing
// is joined: the cost is one sort of N + M rows (2N + M for window()) and,
// for window(), one sort of the 2N markers, O((N+M) log(N+M)).
//   asof(d u):      for master row i with key k and date d_i, c_i = the
//                   using rows of k with u <= d_i; L_i = the latest such u;
//                   t_i = the using rows of k dated L_i.  Using rows sort
//                   before a master marker of the same date (on or before).
//   window(s e u):  n_i = the using rows of k with s_i <= u <= e_i: the
//                   running count at an end marker (sorted after the using
//                   rows of its date) minus the count at a start marker
//                   (sorted before them); an inverted window counts 0.
// A missing master date (d, s or e) links nothing: the row counts as none
// and is reported as missing.  A using row with a missing u is never a
// candidate; it sorts after every marker of its key.  Missing key values
// are keys, as in -merge- and -joinby-.  res() receives the raw counts:
//   (N, nodate, none, one, more, ties, stale, udmiss, M, pairs)
// none + one + more = N; for asof, one/more count the candidates on or
// before the date and ties the rows whose latest candidate date holds more
// than one using row (an as-of pick among them is arbitrary); stale those
// whose latest candidate is more than maxlag() before the date.  For
// window, pairs = sum of n_i, the rows -joinby- then -keep if- the window
// would leave.
//
// Show: prints the lines under the KEYSET PREFLIGHT block, posts one review
// record (always) and one gate record per threshold given (maxnone(),
// maxmulti(), maxties(), maxstale(): shares of the master rows that may not
// be exceeded), and returns the raw counts as r(link_*).  Every count obeys
// mask(): none/one/more partition N, so a single withheld cell withholds
// the smallest other nonzero cell as well; ties and stale are tested
// against their parent counts and N; the pair counts are withheld whenever
// any other count of the entry (preflight included, pmask()) is.  A share
// prints only beside an unmasked count.  No date is ever printed.
program define _dataprobe_kwindow, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local nfail = 0
    local anymask = 0
    local _wf_made = 0
    local _uf_dirty = 0
    tempname wf
    tempvar dv d2 tp rw cum lst tie nw
    capture noisily {
        syntax , VARS(string) LINK(string) DATES(string) UDATE(name) RES(name) ///
            [UFRAME(name) SHOW MAXLag(real -1) MAXNone(real -1) MAXMulti(real -1) ///
            MAXTies(real -1) MAXStale(real -1) JPAIRS(real 0) PMASK(integer 0) ///
            RF(name) KIND(string) GRP(string) PFX(string) MASK(integer 0) ///
            NSCOPE(real 0) FBASE(string)]
        local asof = ("`link'" == "asof")
        if "`show'" == "" {
            // ---- compute ----
            local U = cond(`asof', 0, 1)
            local d1 : word 1 of `dates'
            local d2v : word 2 of `dates'
            // window(d d u), a one-day window, names one variable twice
            local udates : list uniq dates
            frame put `vars' `udates', into(`wf')
            local _wf_made = 1
            frame `wf' {
                local N = _N
                quietly generate double `dv' = `d1'
                if `asof' {
                    quietly count if missing(`dv')
                    local nod = r(N)
                    quietly drop if missing(`dv')
                    quietly generate byte `tp' = 1
                }
                else {
                    quietly generate double `d2' = `d2v'
                    quietly count if missing(`dv') | missing(`d2')
                    local nod = r(N)
                    quietly drop if missing(`dv') | missing(`d2')
                    quietly generate long `rw' = _n
                    quietly expand 2
                    // generate, then by-replace: on zero rows -by:
                    // generate- makes no variable at all
                    quietly generate byte `tp' = .
                    quietly bysort `rw': replace `tp' = cond(_n == 1, 0, 2)
                    quietly replace `dv' = `d2' if `tp' == 2
                    quietly drop `d2'
                }
                quietly drop `udates'
                tempfile mk
                quietly save `"`mk'"'
            }
            frame `uframe' {
                local M = _N
                quietly count if missing(`udate')
                local mud = r(N)
                local _uf_dirty = 1
                quietly generate double `dv' = `udate'
                quietly generate byte `tp' = `U'
                if !`asof' quietly generate long `rw' = .
                quietly append using `"`mk'"'
                sort `vars' `dv' `tp'
                quietly generate double `cum' = .
                quietly by `vars': replace `cum' = sum(`tp' == `U' & !missing(`dv'))
                if `asof' {
                    // the latest candidate date and its rows, carried forward
                    // to each master marker by sequential replace
                    quietly generate double `lst' = `dv' if `tp' == 0
                    quietly generate double `tie' = .
                    quietly by `vars' `dv': replace `tie' = sum(`tp' == 0)
                    quietly by `vars': replace `lst' = `lst'[_n - 1] if `tp' == 1 & _n > 1
                    quietly by `vars': replace `tie' = `tie'[_n - 1] if `tp' == 1 & _n > 1
                    quietly count if `tp' == 1 & `cum' == 0
                    local none = r(N) + `nod'
                    quietly count if `tp' == 1 & `cum' == 1
                    local one = r(N)
                    quietly count if `tp' == 1 & `cum' > 1
                    local more = r(N)
                    quietly count if `tp' == 1 & `cum' >= 1 & `tie' > 1
                    local ties = r(N)
                    local stale = .
                    if `maxlag' >= 0 {
                        quietly count if `tp' == 1 & `cum' >= 1 & (`dv' - `lst') > `maxlag'
                        local stale = r(N)
                    }
                    local pairs = .
                }
                else {
                    // start (0) and end (2) markers of a row are adjacent
                    // after this sort; the using rows (rw missing) sort last
                    sort `rw' `tp'
                    quietly generate double `nw' = .
                    quietly by `rw': replace `nw' = max(0, `cum'[2] - `cum'[1]) ///
                        if _n == 2 & !missing(`rw')
                    quietly count if !missing(`nw') & `nw' == 0
                    local none = r(N) + `nod'
                    quietly count if `nw' == 1
                    local one = r(N)
                    quietly count if `nw' > 1 & !missing(`nw')
                    local more = r(N)
                    quietly summarize `nw', meanonly
                    local pairs = r(sum)
                    local ties = .
                    local stale = .
                }
                quietly drop if `tp' != `U'
                quietly drop `dv' `tp' `cum'
                capture drop `rw'
                capture drop `lst'
                capture drop `tie'
                capture drop `nw'
                local _uf_dirty = 0
            }
            matrix `res' = (`N', `nod', `none', `one', `more', `ties', `stale', `mud', `M', `pairs')
        }
        else {
            // ---- show ----
            local m = `mask'
            local _j = 0
            foreach s in N nod none one more ties stale mud M pairs {
                local _j = `_j' + 1
                local `s' = `res'[1, `_j']
            }
            local d1 : word 1 of `dates'
            local d2v : word 2 of `dates'
            // none / one / more: one partition of N
            local mins = .
            foreach s in none one more {
                _dataprobe_mshare ``s'' `N' `m'
                local c_`s' "`r(cnt)'"
                local p_`s' "`r(pcttxt)'"
                local k_`s' = r(masked)
            }
            if `k_none' + `k_one' + `k_more' == 1 {
                // a lone withheld cell is N minus the other two: withhold
                // the smallest nonzero shown cell beside it
                local _sv ""
                foreach s in none one more {
                    if !`k_`s'' & ``s'' > 0 {
                        if "`_sv'" == "" local _sv "`s'"
                        else if ``s'' < ``_sv'' local _sv "`s'"
                    }
                }
                if "`_sv'" != "" {
                    local c_`_sv' "[suppressed]"
                    local p_`_sv' "[masked]"
                    local k_`_sv' = 1
                }
            }
            if `k_none' | `k_one' | `k_more' local anymask = 1
            foreach s in none one more {
                if !`k_`s'' & ``s'' >= 1 local mins = min(`mins', ``s'')
            }
            // a count inside a parent: masked against the parent and N
            if `asof' {
                _dataprobe_kwsub `ties' `m' `more' `N' `k_more'
                local c_ties "`r(cnt)'"
                local k_ties = r(masked)
                local p_ties = cond(`k_ties', "[masked]", cond(`N' > 0, strtrim(string(100 * `ties' / `N', "%9.1f")) + "%", "n/a"))
                if `k_ties' local anymask = 1
                else if `ties' >= 1 local mins = min(`mins', `ties')
                if `stale' < . {
                    _dataprobe_kwsub `stale' `m' `=`N' - `none'' `N' `k_none'
                    local c_stale "`r(cnt)'"
                    local k_stale = r(masked)
                    local p_stale = cond(`k_stale', "[masked]", cond(`N' > 0, strtrim(string(100 * `stale' / `N', "%9.1f")) + "%", "n/a"))
                    if `k_stale' local anymask = 1
                    else if `stale' >= 1 local mins = min(`mins', `stale')
                }
            }
            _dataprobe_kwsub `nod' `m' `none' `N' `k_none'
            local c_nod "`r(cnt)'"
            if r(masked) local anymask = 1
            else if `nod' >= 1 local mins = min(`mins', `nod')
            _dataprobe_mcount `mud' `m' `M'
            local c_mud "`r(s)'"
            if r(masked) local anymask = 1
            else if `mud' >= 1 local mins = min(`mins', `mud')
            _dataprobe_mcount `N' `m'
            local c_N "`r(s)'"
            if r(masked) local anymask = 1
            else if `N' >= 1 local mins = min(`mins', `N')
            if `asof' {
                local head "asof(`d1' `udate')"
                local what "`fbase' rows with `udate' on or before `d1'"
            }
            else {
                local head "window(`d1' `d2v' `udate')"
                local what "`fbase' rows with `udate' in [`d1', `d2v']"
            }
            display as text "  `head': " as result "`c_N'" as text " rows in memory"
            display as text "    `what': none " as result "`c_none'" as text " (`p_none'), one " ///
                as result "`c_one'" as text " (`p_one'), more " as result "`c_more'" as text " (`p_more')"
            if `asof' {
                local tl "    latest `udate' tied: `c_ties' (`p_ties')"
                if `stale' < . local tl "`tl'; latest older than `maxlag': `c_stale' (`p_stale')"
                display as text "`tl'"
            }
            else {
                // pairs: withheld beside any withheld count of the entry
                local _hp = (`pmask' | `anymask')
                foreach s in jpairs pairs {
                    local _v = cond("`s'" == "jpairs", `jpairs', `pairs')
                    _dataprobe_mcount `_v' `m'
                    local c_`s' "`r(s)'"
                    if r(masked) local anymask = 1
                    else if `_hp' & `_v' >= 1 & `m' > 0 {
                        local c_`s' "[suppressed]"
                        local anymask = 1
                    }
                    else if `_v' < . {
                        local c_`s' = strtrim(string(`_v', "%20.0fc"))
                        if `_v' >= 1 local mins = min(`mins', `_v')
                    }
                }
                display as text "    joinby `vars' would create " as result "`c_jpairs'" ///
                    as text " pairs; " as result "`c_pairs'" as text " inside the window"
            }
            if `nod' > 0 | `mud' > 0 {
                local mt = cond(`asof', "`d1'", "`d1' or `d2v'")
                display as text "    missing `mt': " as result "`c_nod'" as text " rows (none); missing `udate' in `fbase': " ///
                    as result "`c_mud'" as text " rows (never linked)"
            }
            // ---- records ----
            local obs "none `c_none' (`p_none'); one `c_one' (`p_one'); more `c_more' (`p_more')"
            if `asof' {
                local obs "`obs'; ties `c_ties' (`p_ties')"
                if `stale' < . local obs "`obs'; older than `maxlag' `c_stale' (`p_stale')"
            }
            else local obs "`obs'; pairs `c_pairs' of `c_jpairs'"
            local lab "`vars' `head'"
            local vlist "`vars' `dates'"
            local msg `"`pfx'keyset(`vars'): `head' `fbase' — `obs'"'
            frame post `rf' ("keyset") ("review") (2) ("`lab'") ("`vlist'") ///
                (`"`macval(grp)'"') ("`obs'") (`=cond(`N' > 0, `none' / `N', .)') ("`link' `fbase'") ///
                (`nscope') ("") (`"`macval(msg)'"') (`mins') (`anymask')
            foreach g in none more ties stale {
                local thr = cond("`g'" == "none", `maxnone', cond("`g'" == "more", `maxmulti', ///
                    cond("`g'" == "ties", `maxties', `maxstale')))
                if `thr' < 0 continue
                local gname = cond("`g'" == "more", "multi", "`g'")
                local sh = cond(`N' > 0, ``g'' / `N', .)
                local ok = (`N' > 0 & `sh' <= `thr')
                if !`ok' local ++nfail
                local ttxt = strtrim(string(100 * `thr', "%9.3g"))
                local gob = cond(`N' > 0, "`g' `c_`g'' (`p_`g'') of `c_N' rows", "no rows in memory")
                local gmsg `"`pfx'keyset(`vars'): `head' `fbase' — `gob', expected <= `ttxt'%"'
                frame post `rf' ("keyset") ("`kind'") (`ok') ("`lab' max`gname'") ("`vlist'") ///
                    (`"`macval(grp)'"') ("`gob'") (`sh') ("<= `ttxt'%") ///
                    (`nscope') ("") (`"`macval(gmsg)'"') (`mins') (`anymask')
            }
        }
    }
    local rc = _rc
    if `_uf_dirty' {
        // an error inside uframe(): drop the markers so keyset's frame is
        // never left holding them
        // stata-dev-ignore: capture-rc, capture_rc — error-path cleanup; the error's rc is kept in rc
        capture frame `uframe': drop if `tp' != `U'
    }
    if `_wf_made' capture frame drop `wf'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return scalar nfail = `nfail'
    return scalar masked = `anymask'
    if "`show'" != "" {
        foreach s in none one more ties stale pairs {
            return scalar link_`s' = ``s''
        }
        return scalar link_joinby = `jpairs'
        return scalar link_nodate = `nod'
        return scalar link_rows = `N'
    }
end

// a count k inside a parent count p (k <= p <= n): masked as a count, then
// against the parent and n as a complement; a parent already withheld
// (pm = 1) leaves k as a lower bound only, so only k's own tests apply
capture program drop _dataprobe_kwsub
program define _dataprobe_kwsub, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args k m p n pm
        _dataprobe_mshare `k' `n' `m'
        local cnt "`r(cnt)'"
        local masked = r(masked)
        if !`masked' & !`pm' {
            _dataprobe_mshare `k' `p' `m'
            if r(masked) {
                local cnt "`r(cnt)'"
                local masked = 1
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local cnt "`cnt'"
    return scalar masked = `masked'
end

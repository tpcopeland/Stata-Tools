*! _dataprobe_topvalues
*! dataprobe topvalues(): a disclosure-safe frequency view of a variable
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper)

// Syntax: _dataprobe_topvalues, spec(varlist [, mincell(#) max(#) id(varname)])
//             mcell(#) maxfreq(#) [safe(0|1) excluded(varlist) parseonly header]
//
// For each variable: its levels (every distinct value; a missing value, ".",
// ".a" or "", is a level too, so the levels add up to the rows), most
// frequent first, ties in value order.  m is mincell(#), else the call's
// threshold (mcell(): mincell(), the dataqa set default or the maskrare
// default), else 5; max(#) defaults to the call's maxfreq().
//
// A level is listed when its rows, and with id() its distinct ids (a missing
// id is one value), are m or more, and it is among the first max() levels.
// Every other level joins one residual line, [k levels suppressed]; no value
// of a residual level is ever printed.  The rows rule is the one dataprobe's
// maskrare frequency tables use (_dataprobe_freqsup; a subprogram of
// dataprobe.ado is private to that file, so the rule is restated in Mata
// here, and test_datamap_v210_disclosure pins the parity with the
// profile's tables): the residual of a table holding a suppressed level
// needs two levels and m rows, else the smallest listed level joins it.  Then, datamap's own rule for
// id(): while the residual's distinct ids are 1 to m-1 the smallest listed
// level joins it.  When no listed level is left and the residual is still 1
// to m-1 rows or ids, its counts and the totals are withheld together (the
// total minus the listed counts would give them back), and so is k.
//
// Printed, each in its own rule: the total rows (withheld only as above);
// the total distinct ids, withheld also when the total minus a listed
// level's ids, or minus the residual's, is 1 to m-1 (ids need not add up
// across levels); k, only when the residual has at least 2k rows (and
// more ids than k), since fewer than 2k rows in k levels force some pooled
// level to be a single row (each level holds 1 row or more); the number of
// levels, only beside k.  r(topvalues) holds what was printed,
// one row per variable (missing where withheld): N N_id levels shown
// suppressed resid resid_id.

capture mata: mata drop _dptv_codes()
capture mata: mata drop _dptv_text()
capture mata: mata drop _dptv_show()
capture mata: mata drop _dptv_run()
mata:
// dataprobe's _dataprobe_dshow (file-private to dataprobe.ado), restated:
// a backtick, double quote and dollar sign become {char N}, a brace
// {c -(}, a control character \n, \r, \t or \xHH, so a value prints as
// its literal characters; w > 0 right-pads to w columns, measured before
// the substitution
string scalar _dptv_show(string scalar s, real scalar w)
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

// codes 1..K of one variable's values in sorted order (each missing value
// a value of its own); p gets the sort order
real colvector _dptv_codes(string scalar v, real colvector p)
{
	real colvector c, x
	string colvector s
	real scalar n, i, k
	n = st_nobs()
	c = J(n, 1, .)
	p = J(0, 1, .)
	if (n == 0) return(c)
	if (st_isstrvar(v)) {
		s = st_sdata(., v)
		p = order(s, 1)
		k = 1
		c[p[1]] = 1
		for (i = 2; i <= n; i++) {
			if (s[p[i]] != s[p[i - 1]]) k++
			c[p[i]] = k
		}
	}
	else {
		x = st_data(., v)
		p = order(x, 1)
		k = 1
		c[p[1]] = 1
		for (i = 2; i <= n; i++) {
			if (x[p[i]] != x[p[i - 1]]) k++
			c[p[i]] = k
		}
	}
	return(c)
}

// the display text of the value of v at row r: a numeric value in its
// display format, then its value label; a blank string is (blank).  The
// caller escapes it for SMCL (_dptv_show).
string scalar _dptv_text(string scalar v, real scalar r)
{
	string scalar s, lbl, fmt
	real scalar x
	if (st_isstrvar(v)) {
		s = st_sdata(r, v)
		if (s == "") return("(blank)")
		return(s)
	}
	x = st_data(r, v)
	fmt = st_varformat(v)
	if (missing(x)) s = strtrim(strofreal(x))
	else s = strtrim(strofreal(x, fmt))
	if (s == "" | s == "." & !missing(x)) s = strtrim(strofreal(x, "%21.15g"))
	lbl = st_varvaluelabel(v)
	if (lbl != "") {
		if (st_vlexists(lbl)) {
			if (st_vlmap(lbl, x) != "") s = s + " " + st_vlmap(lbl, x)
		}
	}
	return(s)
}

// the levels of v and what prints, into locals.  Levels in rank order
// (rows descending, value order on ties).  A level is suppressed when its
// rows (or ids) are below m; the rows rule of dataprobe's maskrare tables
// (_dataprobe_freqsup, private to dataprobe.ado and restated here) then
// moves the smallest listed level into the residual (suppressed levels and
// those ranked past mx) while it holds a suppressed level and has one
// level or fewer than m rows; datamap's id() rule then does the same while
// the residual's distinct ids are 1 to m-1
void _dptv_run(string scalar v, string scalar iv, real scalar m, real scalar mx)
{
	real colvector lc, ic, p, q, f, d, first, rk, sup, res, pos, inr, sh, cmp, pp, cand
	real scalar n, L, i, hasid, N, NID, RR, RD, ok, k, s, pN, pNID, pK, pL, bad
	string scalar sfx
	n = st_nobs()
	hasid = (iv != "")
	p = J(0, 1, .)
	lc = _dptv_codes(v, p)
	L = max(lc)
	f = J(L, 1, 0)
	first = J(L, 1, .)
	for (i = 1; i <= n; i++) {
		f[lc[i]] = f[lc[i]] + 1
		if (first[lc[i]] >= .) first[lc[i]] = i
	}
	d = J(L, 1, .)
	if (hasid) {
		q = J(0, 1, .)
		ic = _dptv_codes(iv, q)
		d = J(L, 1, 0)
		pp = order((lc, ic), (1, 2))
		d[lc[pp[1]]] = 1
		for (i = 2; i <= n; i++) {
			if (lc[pp[i]] != lc[pp[i - 1]] | ic[pp[i]] != ic[pp[i - 1]]) d[lc[pp[i]]] = d[lc[pp[i]]] + 1
		}
	}
	// rank order: rk[i] is the value code of the level ranked i
	rk = order((-f, (1::L)), (1, 2))
	f = f[rk]
	d = d[rk]
	first = first[rk]
	pos = J(L, 1, .)
	pos[rk] = (1::L)
	// primary suppression, then the rows rule of _dataprobe_freqsup
	sup = (f :< m)
	if (hasid) sup = sup :| (d :< m)
	if (any(sup)) {
		while (1) {
			res = sup :| ((1::L) :> mx)
			if (sum(res) >= 2 & sum(f :* res) >= m) break
			// length(): a 1x1 input gives a 1x0 result, whose rows() is 1
			cand = selectindex(!sup :& ((1::L) :<= mx))
			if (length(cand) == 0) break
			sup[cand[length(cand)]] = 1
		}
	}
	res = sup :| ((1::L) :> mx)
	// datamap's id() rule, and a residual that cannot reach m
	ok = 1
	while (1) {
		RR = sum(f :* res)
		RD = .
		if (hasid) {
			inr = res[pos[lc]]
			RD = (any(inr) ? rows(uniqrows(select(ic, inr))) : 0)
		}
		bad = (RR >= 1 & RR < m)
		if (hasid) bad = bad | (RD >= 1 & RD < m)
		if (!bad) break
		sh = selectindex(!res)
		if (length(sh) == 0) {
			ok = 0
			break
		}
		res[sh[length(sh)]] = 1
	}
	N = sum(f)
	NID = (hasid ? rows(uniqrows(ic)) : .)
	k = sum(res)
	sh = selectindex(!res)
	s = length(sh)
	if (s) sh = vec(sh)
	pN = (k == 0 | ok)
	pNID = 0
	if (hasid & pN) {
		pNID = (NID == 0 | NID >= m)
		if (s) {
			cmp = NID :- d[sh]
			if (any(cmp :>= 1 :& cmp :< m)) pNID = 0
		}
		if (k) {
			if (NID - RD >= 1 & NID - RD < m) pNID = 0
		}
	}
	// RR < 2k rows in k levels force a pooled level of exactly 1 row
	pK = (k > 0 & ok & RR >= 2 * k)
	if (hasid & pK) pK = (RD > k)
	pL = (k == 0 | pK)
	st_local("_tv_N", strofreal(pN ? N : ., "%20.0f"))
	st_local("_tv_NID", strofreal(pNID ? NID : ., "%20.0f"))
	st_local("_tv_L", strofreal(pL ? L : ., "%20.0f"))
	st_local("_tv_s", strofreal(s))
	st_local("_tv_k", strofreal(k, "%20.0f"))
	st_local("_tv_pk", strofreal(pK))
	st_local("_tv_RR", strofreal(k & ok ? RR : ., "%20.0f"))
	st_local("_tv_RD", strofreal(k & ok & hasid ? RD : ., "%20.0f"))
	for (i = 1; i <= s; i++) {
		sfx = strofreal(i)
		st_local("_tv_t" + sfx, _dptv_show(_dptv_text(v, first[sh[i]]), 28))
		st_local("_tv_n" + sfx, strofreal(f[sh[i]], "%20.0f"))
		st_local("_tv_d" + sfx, strofreal(hasid ? d[sh[i]] : ., "%20.0f"))
	}
}
end

program define _dataprobe_topvalues, rclass
    // every topvalues() entry, \-separated: parsed (parseonly) or run, so the
    // loops stay out of dataprobe's main program (Stata's per-program limit)
    version 16.0
    syntax , SPECS(string) MCELL(integer) MAXFREQ(integer) [SAFE(integer 0) ///
        EXCLuded(string) PARSEonly]
    local vars ""
    local n = 0
    tempname TV
    local rest `"`specs'"'
    while `"`rest'"' != "" {
        gettoken part rest : rest, parse("\") quotes
        if `"`part'"' == "\" continue
        local part = strtrim(`"`part'"')
        if `"`part'"' == "" continue
        local ++n
        local hdr ""
        if "`parseonly'" == "" & `n' == 1 local hdr "header"
        _dataprobe_topvalues_one, spec(`"`part'"') mcell(`mcell') maxfreq(`maxfreq') ///
            safe(`safe') excluded(`excluded') `parseonly' `hdr'
        local vars "`vars' `r(vars)'"
        if "`parseonly'" == "" matrix `TV' = nullmat(`TV') \ r(topvalues)
    }
    return scalar n = `n'
    return local vars "`vars'"
    if "`parseonly'" == "" & `n' > 0 return matrix topvalues = `TV'
end

program define _dataprobe_topvalues_one, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local vars ""
    tempname TV
    capture noisily {
        syntax , SPEC(string) MCELL(integer) MAXFREQ(integer) [SAFE(integer 0) ///
            EXCLuded(string) PARSEonly HEADer]
        local 0 `"`spec'"'
        capture noisily syntax varlist [, MINcell(integer -1) MAX(integer -1) ID(varname)]
        if _rc {
            local _erc = _rc
            display as error "topvalues(): each entry is varlist [, mincell(#) max(#) id(varname)]"
            exit `_erc'
        }
        local varlist : list uniq varlist
        local m = `mcell'
        if `mincell' != -1 local m = `mincell'
        else if `m' <= 0 local m = 5
        if `m' < 2 | missing(`m') {
            display as error "topvalues() needs a threshold of 2 or more (m is `m'): a level of 1 row would be listed"
            exit 198
        }
        local mx = `maxfreq'
        if `max' != -1 local mx = `max'
        if `mx' < 1 | missing(`mx') {
            display as error "topvalues(): max() must be 1 or more"
            exit 198
        }
        // exclude() withholds a variable's values (safe adds the likely
        // identifiers to it); safe withholds the values of a date and of
        // text holding a digit, as it does for by() labels
        local _ex : list varlist & excluded
        if "`_ex'" != "" {
            display as error "topvalues(): the values of `_ex' are withheld (exclude(), or safe's likely identifiers)"
            exit 198
        }
        if `safe' {
            local _bad ""
            foreach v of local varlist {
                local _vf : format `v'
                capture confirm string variable `v'
                if !_rc {
                    quietly count if ustrregexm(`v', "\p{Nd}")
                    if r(N) local _bad "`_bad' `v'"
                }
                else if regexm("`_vf'", "^%-?(t|d)") local _bad "`_bad' `v'"
            }
            if "`_bad'" != "" {
                display as error "safe: topvalues() would print the values of`_bad' (a date, or text holding a digit)"
                exit 198
            }
        }
        local vars "`varlist' `id'"
        local vars : list uniq vars
        if "`parseonly'" == "" {
            local hasid = ("`id'" != "")
            if "`header'" != "" {
                display ""
                display as text "TOP VALUES"
            }
            local _iu = cond(`hasid', " and ids", "")
            foreach v of local varlist {
                if c(N) == 0 {
                    display as text "  " as result "`v'" as text ":  0 rows"
                    matrix `TV' = nullmat(`TV') \ (0, cond(`hasid', 0, .), 0, 0, 0, ., .)
                    continue
                }
                mata: _dptv_run("`v'", "`id'", `m', `mx')
                // the header line: rows, ids, levels, withheld as decided
                local hN = cond(`_tv_N' < ., strtrim(string(`_tv_N', "%20.0fc")), "[suppressed]")
                local hd = "`hN' row" + cond(`_tv_N' == 1, "", "s")
                if `hasid' {
                    local hI = cond(`_tv_NID' < ., strtrim(string(`_tv_NID', "%20.0fc")), "[suppressed]")
                    local hd = "`hd', `hI' id" + cond(`_tv_NID' == 1, "", "s")
                }
                if `_tv_L' < . local hd = "`hd', " + strtrim(string(`_tv_L', "%20.0fc")) + " level" + cond(`_tv_L' == 1, "", "s")
                display as text "  " as result "`v'" as text ":  `hd'; listed: `m' or more rows`_iu', at most `mx'"
                forvalues i = 1/`_tv_s' {
                    local disp `"`_tv_t`i''"'
                    local pc = 100 * `_tv_n`i'' / `_tv_N'
                    local idt ""
                    if `hasid' local idt "  ids `=strtrim(string(`_tv_d`i'', "%20.0f"))'"
                    display as text "    " as result `"`macval(disp)'"' as result %9.0f `_tv_n`i'' ///
                        as text "  (" as result %4.1f `pc' as text "%)" as text "`idt'"
                }
                if `_tv_k' > 0 {
                    if `_tv_pk' local rl = "[`_tv_k' level" + cond(`_tv_k' == 1, "", "s") + " suppressed]"
                    else local rl "[levels suppressed]"
                    local rl : display %-28s "`rl'"
                    if `_tv_RR' < . {
                        local pc = 100 * `_tv_RR' / `_tv_N'
                        local idt ""
                        if `hasid' local idt "  ids `=strtrim(string(`_tv_RD', "%20.0f"))'"
                        display as text "    " as result "`rl'" as result %9.0f `_tv_RR' ///
                            as text "  (" as result %4.1f `pc' as text "%)" as text "`idt'"
                    }
                    else display as text "    " as result "`rl'" as text ///
                        "   [suppressed] (with every level pooled, fewer than `m' rows`=cond(`hasid', " or ids", "")')"
                }
                matrix `TV' = nullmat(`TV') \ (`_tv_N', `_tv_NID', `_tv_L', `_tv_s', ///
                    cond(`_tv_pk' | `_tv_k' == 0, `_tv_k', .), `_tv_RR', `_tv_RD')
            }
            matrix colnames `TV' = N N_id levels shown suppressed resid resid_id
            matrix rownames `TV' = `varlist'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local vars "`vars'"
    if "`parseonly'" == "" return matrix topvalues = `TV'
end

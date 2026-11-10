*! _dataprobe_diff Version 2.0.0  2026/11/10
*! dataprobe compare() and diff(): the profile against a baseline, line by line
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// 2.0.0 (U3, F6).  The baseline is a frame or a Stata dataset already
// resolved by _dataprobe_target: a saved profile (dataprobe or datamap
// saving(), dataprobe snapshot(): one row per variable with variable,
// storage_type, class, N, missing, unique, unique_capped, mean, min, max and
// display_format; the 1.x aliases varname, vartype, classification and
// dc_class are read too) or any other dataset, whose variables and types
// alone are the baseline (r(schema_only) 1).  The current side is the frame
// of the same rows for the data in memory (_datamap_post_metadata_rows,
// plain), so a profile compared with itself has no line to print.
//
// Printed, under a heading (SCHEMA COMPARE or DIFF) and the baseline's name:
//   N: current #, baseline #, delta #          (as 1.x compare() printed it)
//   key K: unique before, not unique after (# surplus rows)
//   v: added (type, class) | v: dropped (type)
//   v: type a -> b; class a -> b; missing a -> b (+d); distinct a -> b (+d);
//      mean a -> b; range a to b -> c to d
//   no changes
// A count changes when it moves by more than ctol() (default 0); a mean, a
// minimum or a maximum when it moves by more than tol() (default 1e-8)
// times the larger magnitude.  A variable with a missing statistic on either
// side is not compared on it, and an excluded variable (class excluded on
// either side) only on its type, class and missing count.  Under mask(m) > 0 (maskrare) every count from
// 1 to m-1 prints as <m, and a count that would give one back is withheld
// (the 1.x rule of the N line); a minimum or maximum is never printed (the
// line says the range changed), and a mean only when both sides have m or
// more nonmissing values and the variable is neither categorical nor two-
// or three-valued on either side (else "mean changed").  Stored results are
// unmasked.
//
// Key: key() (the call's id() or isid()), else the baseline's
// _dta[dataprobe_key] (snapshot()), else the first baseline variable with
// no missing value and as many distinct values as rows.  After: the rows of
// the data in memory less its distinct key values (missing counted as a
// value).  A key outside the call's varlist but still in the data prints
// "not checked after (not in the varlist)", r(key_after) missing.
program define _dataprobe_diff, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _nb_made = 0
    tempname nb
    capture noisily {
        syntax, BASE(string) KIND(name) CUR(name) HEADer(string) ///
            NOBS(integer) [PROFilevars(string) DATAvars(string) MASK(integer 0) ///
            TOL(real 1e-8) CTOL(real 0) KEY(string)]
        // ---- the baseline, one row per variable, in a frame of our own ----
        // flagged first: a failed load may already have made the frame
        local _nb_made = 1
        _dataprobe_dbase, base(`"`base'"') kind(`kind') into(`nb')
        local schema_only = r(schema_only)
        local base_N = r(base_N)
        local bkey `"`r(key)'"'
        local bkeyu = r(keyuniq)
        local bshow `"`r(show)'"'

        // ---- key: the call's, the snapshot's, or the baseline's unique one ----
        local K ""
        local kb = .
        if "`key'" != "" {
            local K "`key'"
            if "`K'" == "`bkey'" local kb = `bkeyu'
            else if `: word count `K'' == 1 & !`schema_only' {
                frame `nb' {
                    quietly count if variable == "`K'"
                    if r(N) {
                        quietly summarize _row if variable == "`K'", meanonly
                        local _r = r(min)
                        if unique_capped[`_r'] != 1 & !missing(unique[`_r'], missing[`_r'], N[`_r']) {
                            local kb = (unique[`_r'] == N[`_r'] & missing[`_r'] == 0)
                        }
                    }
                }
            }
        }
        else if "`bkey'" != "" {
            local K "`bkey'"
            local kb = `bkeyu'
        }
        else if !`schema_only' & `base_N' > 1 & `base_N' < . {
            frame `nb' {
                quietly count if unique == N & missing == 0 & unique_capped != 1
                if r(N) {
                    quietly summarize _row if unique == N & missing == 0 & unique_capped != 1, meanonly
                    local K = variable[r(min)]
                    local kb = 1
                }
            }
        }
        local ka = .
        local ksur = .
        local kgone = 0
        local kout = 0
        if "`K'" != "" {
            // dropped means gone from the data (datavars), as a variable line
            // does; a key that is only outside the call's varlist is not in
            // the working copy, so its uniqueness after is not checked
            foreach kv of local K {
                if `"`datavars'"' != "" {
                    if !`: list kv in datavars' local kgone = 1
                    else {
                        capture confirm variable `kv', exact
                        if _rc local kout = 1
                    }
                }
                else {
                    capture confirm variable `kv', exact
                    if _rc local kgone = 1
                }
            }
            if !`kgone' & !`kout' {
                // the data's row order is put back: nothing after this may
                // see the key's sort
                tempvar kt ko
                quietly generate double `ko' = _n
                capture {
                    bysort `K': generate byte `kt' = (_n == 1)
                    count if `kt'
                }
                if !_rc {
                    local ksur = `nobs' - r(N)
                    local ka = (`ksur' == 0)
                }
                sort `ko'
                capture drop `kt'
                drop `ko'
            }
        }

        // ---- per-variable lines (Mata), after the N and key lines ----
        local _dpd_pv "`profilevars'"
        local _dpd_dv "`datavars'"
        mata: _dpd_calc("`nb'", "`cur'", `mask', `tol', `ctol')

        // ---- print ----
        display ""
        display as text `"`header'"'
        display as text "  baseline: " as result `"`bshow'"'
        local _pmasked = 0
        local n_delta = .
        if `base_N' < . local n_delta = `nobs' - `base_N'
        if `base_N' < . {
            // the delta of two published counts can be a small cell.  Any
            // two of current N, baseline N and delta give the third, so when
            // one is a small cell only one other is printed as a number.
            local _cds = `n_delta'
            local _cns = `nobs'
            local _cbs = `base_N'
            if `mask' {
                local _sd = (abs(`n_delta') >= 1 & abs(`n_delta') < `mask')
                local _sc = (`nobs' >= 1 & `nobs' < `mask')
                local _sb = (`base_N' >= 1 & `base_N' < `mask')
                if `_sc' {
                    local _cns "<`mask'"
                    local _cds "[suppressed]"
                }
                if `_sb' {
                    local _cbs "<`mask'"
                    local _cds "[suppressed]"
                }
                if `_sd' {
                    local _cds "<`mask' (masked)"
                    if !`_sc' local _cbs "[suppressed]"
                }
                if `_sc' & !`_sb' & !`_sd' local _cbs "[suppressed]"
                if `_sc' | `_sb' | `_sd' local _pmasked = 1
            }
            display as text "  N: current " as result "`_cns'" ///
                as text ", baseline " as result "`_cbs'" ///
                as text ", delta " as result "`_cds'"
        }
        if "`K'" != "" {
            local _kw = cond(`: word count `K'' > 1, "keys", "key")
            if `kgone' display as text "  `_kw' `K': " as result "dropped"
            else {
                local _b = cond(`kb' == 1, "unique", cond(`kb' == 0, "not unique", "unknown"))
                local _a = cond(`ka' == 1, "unique", cond(`ka' == 0, "not unique", "unknown"))
                if `kout' local _t "`_b' before, not checked after (not in the varlist)"
                else if "`_b'" == "`_a'" local _t "`_b' before and after"
                else local _t "`_b' before, `_a' after"
                if `ksur' > 0 & `ksur' < . {
                    _dataprobe_mcount `ksur' `mask' `nobs'
                    if r(masked) local _pmasked = 1
                    local _t "`_t' (`r(s)' surplus rows)"
                }
                display as text "  `_kw' `K': " as result "`_t'"
            }
        }
        forvalues j = 1/`_dpd_nl' {
            display as text "  `_dpd_v`j'': " as result `"`_dpd_t`j''"'
        }
        // a key line is a change when the key went or its uniqueness moved
        local _keyline = ("`K'" != "" & (`kgone' | (`kb' < . & `ka' < . & `kb' != `ka')))
        local _nline = (`base_N' < . & `n_delta' != 0)
        if `_dpd_nl' == 0 & !`_keyline' & !`_nline' display as text "  no changes"
        if `_dpd_masked' local _pmasked = 1
    }
    local rc = _rc
    if `_nb_made' capture frame drop `nb'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local added "`_dpd_added'"
    return local dropped "`_dpd_dropped'"
    return local type_changed "`_dpd_type'"
    return local class_changed "`_dpd_class'"
    return local missing_changed "`_dpd_miss'"
    return local unique_changed "`_dpd_uniq'"
    return local stat_changed "`_dpd_stat'"
    return local changed "`_dpd_changed'"
    return local key "`K'"
    return local baseline `"`bshow'"'
    return scalar n_lines = `_dpd_nl'
    return scalar base_N = `base_N'
    return scalar n_delta = `n_delta'
    return scalar key_before = `kb'
    return scalar key_after = `ka'
    return scalar key_surplus = `ksur'
    return scalar schema_only = `schema_only'
    return scalar masked = `_pmasked'
end

// The baseline as rows: variable storage_type class display_format (str)
// N missing unique unique_capped mean min max (double) _row, one row per
// variable (the first when a name repeats), in frame `into'.
capture program drop _dataprobe_dbase
program define _dataprobe_dbase, rclass
    syntax, BASE(string) KIND(name) INTO(name)
    local schema_only = 0
    local base_N = .
    local key ""
    local keyuniq = .
    if "`kind'" == "frame" {
        local show "frame `base'"
        frame copy `base' `into'
    }
    else {
        local show `"`base'"'
        frame create `into'
        frame `into': quietly use `"`base'"', clear
    }
    frame `into' {
        local key : char _dta[dataprobe_key]
        local _ku : char _dta[dataprobe_keyuniq]
        if "`key'" != "" & "`_ku'" != "" local keyuniq = real("`_ku'")
        capture confirm variable variable, exact
        if _rc {
            capture confirm variable varname, exact
            if !_rc rename varname variable
        }
        capture confirm variable variable, exact
        if !_rc {
            capture confirm string variable variable, exact
            if _rc local schema_only = 1
        }
        else local schema_only = 1
        if `schema_only' {
            // any other dataset: its variables, types and N
            local base_N = _N
            quietly describe, replace clear
            keep name type format
            rename name variable
            rename type storage_type
            rename format display_format
            quietly generate str1 class = ""
            foreach c in N missing unique unique_capped mean min max {
                quietly generate double `c' = .
            }
            quietly replace N = `base_N'
            local key ""
            local keyuniq = .
        }
        else {
            foreach p in "storage_type vartype" "class classification" "class dc_class" {
                gettoken a b : p
                local b = strtrim("`b'")
                capture confirm variable `a', exact
                if _rc {
                    capture confirm variable `b', exact
                    if !_rc rename `b' `a'
                }
            }
            foreach c in storage_type class display_format {
                capture confirm string variable `c', exact
                if _rc {
                    capture drop `c'
                    quietly generate str1 `c' = ""
                }
            }
            foreach c in N missing unique unique_capped mean min max {
                capture confirm numeric variable `c', exact
                if _rc {
                    capture drop `c'
                    quietly generate double `c' = .
                }
            }
            if _N > 0 local base_N = N[1]
            keep variable storage_type class display_format N missing unique ///
                unique_capped mean min max
            quietly drop if variable == ""
            // a name that repeats (several datasets in one datamap file):
            // the first row
            quietly generate long _row0 = _n
            quietly bysort variable (_row0): keep if _n == 1
            sort _row0
            drop _row0
        }
        quietly generate long _row = _n
    }
    return scalar schema_only = `schema_only'
    return scalar base_N = `base_N'
    return local key "`key'"
    return scalar keyuniq = `keyuniq'
    return local show `"`show'"'
end

capture mata: mata drop _dpd_calc()
capture mata: mata drop _dpd_num()
capture mata: mata drop _dpd_cnt()
capture mata: mata drop _dpd_moved()
capture mata: mata drop _dpd_isdate()
mata:
// a number for a diff line: in a date display format when it has one,
// else the fewest %g digits (6 to 17) that tell a from b apart
void _dpd_num(real scalar a, real scalar b, string scalar fmt,
	string scalar sa, string scalar sb)
{
	real scalar d
	if (_dpd_isdate(fmt)) {
		sa = strtrim(strofreal(a, fmt))
		sb = strtrim(strofreal(b, fmt))
		if (sa != sb | a == b) return
	}
	for (d = 6; d <= 17; d++) {
		sa = strtrim(strofreal(a, "%24." + strofreal(d) + "g"))
		sb = strtrim(strofreal(b, "%24." + strofreal(d) + "g"))
		if (sa != sb | a == b) return
	}
}
real scalar _dpd_isdate(string scalar fmt)
{
	return(regexm(fmt, "^%-?(t[cCdwmqhyb]|d)"))
}
// a count pair as printed: "a -> b (+d)", every count from 1 to m-1 shown
// as <m (a delta as +<m or -<m) and a count that would give one back
// withheld as [suppressed] (the N rule); na, nb: the rows each count is
// taken from, so n - k between 1 and m-1 is withheld too
string scalar _dpd_cnt(real scalar a, real scalar b, real scalar m,
	real scalar na, real scalar nb, real scalar masked)
{
	string scalar sa, sb, sd
	real scalar d, ma, mb, md
	d = b - a
	sa = strofreal(a, "%20.0f")
	sb = strofreal(b, "%20.0f")
	sd = (d > 0 ? "+" : "") + strofreal(d, "%20.0f")
	if (m > 0) {
		ma = (a >= 1 & a < m) | (na - a >= 1 & na - a < m)
		mb = (b >= 1 & b < m) | (nb - b >= 1 & nb - b < m)
		md = (abs(d) >= 1 & abs(d) < m)
		if (ma) {
			sa = (a >= 1 & a < m ? "<" + strofreal(m) : "[suppressed]")
			sd = "[suppressed]"
		}
		if (mb) {
			sb = (b >= 1 & b < m ? "<" + strofreal(m) : "[suppressed]")
			sd = "[suppressed]"
		}
		if (md) {
			sd = (d > 0 ? "+" : "-") + "<" + strofreal(m)
			if (!mb) sa = "[suppressed]"
		}
		if (mb & !ma & !md) sa = "[suppressed]"
		if (ma | mb | md) masked = 1
	}
	return(sa + " -> " + sb + " (" + sd + ")")
}
real scalar _dpd_moved(real scalar a, real scalar b, real scalar tol)
{
	if (missing(a) | missing(b)) return(0)
	if (a == b) return(0)
	return(abs(b - a) > tol * max((abs(a), abs(b))))
}
void _dpd_calc(string scalar bf, string scalar cf, real scalar m,
	real scalar tol, real scalar ctol)
{
	string scalar cur, t, ln, sa, sb, sc, sd, fmt
	string colvector BV, BT, BC, BF, CV, CT, CC, CF
	string rowvector pv, dv
	real matrix BX, CX
	real scalar i, j, nl, masked, n0, n1, mc, uc, ca, cb, ex, mh
	string rowvector added, dropped, ty, cl, mi, un, st, ch
	real colvector seen, sel

	cur = st_framecurrent()
	st_framecurrent(bf)
	BV = st_sdata(., "variable")
	BT = st_sdata(., "storage_type")
	BC = st_sdata(., "class")
	BF = st_sdata(., "display_format")
	BX = st_data(., ("N", "missing", "unique", "unique_capped", "mean", "min", "max"))
	st_framecurrent(cf)
	CV = st_sdata(., "variable")
	CT = st_sdata(., "storage_type")
	CC = st_sdata(., "class")
	CF = st_sdata(., "display_format")
	CX = st_data(., ("N", "missing", "unique", "unique_capped", "mean", "min", "max"))
	st_framecurrent(cur)
	pv = tokens(st_local("_dpd_pv"))
	dv = tokens(st_local("_dpd_dv"))
	added = dropped = ty = cl = mi = un = st = ch = J(1, 0, "")
	nl = 0
	masked = 0
	seen = J(rows(CV), 1, 0)
	// baseline order: changed and dropped variables
	for (i = 1; i <= rows(BV); i++) {
		j = 0
		if (rows(CV)) {
			sel = selectindex(CV :== BV[i])
			if (length(sel)) j = sel[1]
		}
		if (j == 0) {
			// dropped: gone from the data, not merely outside the varlist
			if (!anyof(pv, BV[i]) & !anyof(dv, BV[i])) {
				dropped = dropped, BV[i]
				ln = "dropped" + (BT[i] != "" ? " (" + BT[i] + ")" : "")
				nl++
				st_local("_dpd_v" + strofreal(nl), BV[i])
				st_local("_dpd_t" + strofreal(nl), ln)
				ch = ch, BV[i]
			}
			continue
		}
		seen[j] = 1
		ln = ""
		if (BT[i] != "" & CT[j] != BT[i]) {
			ty = ty, BV[i]
			ln = ln + (ln != "" ? "; " : "") + "type " + BT[i] + " -> " + CT[j]
		}
		// no class against an empty side (every empty variable classifies
		// as categorical), unless either side excluded it
		if (BC[i] != "" & CC[j] != BC[i] & ((BX[i, 1] != 0 & CX[j, 1] != 0) |
			BC[i] == "excluded" | CC[j] == "excluded")) {
			cl = cl, BV[i]
			ln = ln + (ln != "" ? "; " : "") + "class " + BC[i] + " -> " + CC[j]
		}
		// nonmissing rows each side, for the complement of a missing count
		n0 = BX[i, 1] - BX[i, 2]
		n1 = CX[j, 1] - CX[j, 2]
		if (!missing(BX[i, 2]) & !missing(CX[j, 2]) & abs(CX[j, 2] - BX[i, 2]) > ctol) {
			mi = mi, BV[i]
			ln = ln + (ln != "" ? "; " : "") + "missing " +
				_dpd_cnt(BX[i, 2], CX[j, 2], m, BX[i, 1], CX[j, 1], masked)
		}
		// distinct: a censored count (unique_capped) is a lower bound, so it
		// changed only when the exact count on the other side is below it
		// an excluded variable (either side) is structure only: its type,
		// class and missing count, never its distinct values or statistics
		ex = (CC[j] == "excluded" | BC[i] == "excluded")
		if (!ex & !missing(BX[i, 3]) & !missing(CX[j, 3])) {
			cb = (BX[i, 4] == 1)
			ca = (CX[j, 4] == 1)
			uc = 0
			if (!cb & !ca) uc = (abs(CX[j, 3] - BX[i, 3]) > ctol)
			else if (cb & !ca) uc = (CX[j, 3] < BX[i, 3])
			else if (!cb & ca) uc = (BX[i, 3] < CX[j, 3])
			if (uc) {
				un = un, BV[i]
				if (cb | ca) {
					sa = (cb ? ">" + strofreal(BX[i, 3] - 1, "%20.0f") : strofreal(BX[i, 3], "%20.0f"))
					sb = (ca ? ">" + strofreal(CX[j, 3] - 1, "%20.0f") : strofreal(CX[j, 3], "%20.0f"))
					if (m > 0) {
						if (!cb & ((BX[i, 3] >= 1 & BX[i, 3] < m) | (n0 - BX[i, 3] >= 1 & n0 - BX[i, 3] < m))) {
							sa = "[masked]"
							masked = 1
						}
						if (!ca & ((CX[j, 3] >= 1 & CX[j, 3] < m) | (n1 - CX[j, 3] >= 1 & n1 - CX[j, 3] < m))) {
							sb = "[masked]"
							masked = 1
						}
					}
					t = sa + " -> " + sb
				}
				else t = _dpd_cnt(BX[i, 3], CX[j, 3], m, n0, n1, masked)
				ln = ln + (ln != "" ? "; " : "") + "distinct " + t
			}
		}
		fmt = CF[j]
		if (fmt == "") fmt = BF[i]
		mc = 0
		// a mean of a date is not a fact anyone reads
		// under the mask a mean of a categorical variable, or of one with
		// two or three distinct values on either side, is the share in a
		// cell and gives its count back: withheld, as datamap's
		// _datamap_sumpolicy (cathide, momhide) withholds it (2.0.0)
		mh = (m > 0 & (CC[j] == "categorical" | BC[i] == "categorical" |
			(BX[i, 4] != 1 & BX[i, 3] >= 2 & BX[i, 3] <= 3) |
			(CX[j, 4] != 1 & CX[j, 3] >= 2 & CX[j, 3] <= 3)))
		if (!ex & !_dpd_isdate(fmt) & CC[j] != "date" & _dpd_moved(BX[i, 5], CX[j, 5], tol)) {
			if (!mh & (m == 0 | (n0 >= m & n1 >= m))) {
				_dpd_num(BX[i, 5], CX[j, 5], "", sa, sb)
				ln = ln + (ln != "" ? "; " : "") + "mean " + sa + " -> " + sb
			}
			else {
				ln = ln + (ln != "" ? "; " : "") + "mean changed"
				masked = 1
			}
			mc = 1
		}
		if (!ex & (_dpd_moved(BX[i, 6], CX[j, 6], tol) | _dpd_moved(BX[i, 7], CX[j, 7], tol))) {
			if (m == 0) {
				_dpd_num(BX[i, 6], CX[j, 6], fmt, sa, sb)
				_dpd_num(BX[i, 7], CX[j, 7], fmt, sc, sd)
				ln = ln + (ln != "" ? "; " : "") + "range " + sa + " to " + sc +
					" -> " + sb + " to " + sd
			}
			else {
				// an extreme is never printed under maskrare
				ln = ln + (ln != "" ? "; " : "") + "range changed"
				masked = 1
			}
			mc = 1
		}
		if (mc) st = st, BV[i]
		if (ln != "") {
			nl++
			st_local("_dpd_v" + strofreal(nl), BV[i])
			st_local("_dpd_t" + strofreal(nl), ln)
			ch = ch, BV[i]
		}
	}
	// current order: added variables
	for (j = 1; j <= rows(CV); j++) {
		if (seen[j]) continue
		added = added, CV[j]
		ln = "added (" + CT[j] + (CC[j] != "" ? ", " + CC[j] : "") + ")"
		nl++
		st_local("_dpd_v" + strofreal(nl), CV[j])
		st_local("_dpd_t" + strofreal(nl), ln)
		ch = ch, CV[j]
	}
	st_local("_dpd_nl", strofreal(nl))
	st_local("_dpd_masked", strofreal(masked))
	st_local("_dpd_added", invtokens(added))
	st_local("_dpd_dropped", invtokens(dropped))
	st_local("_dpd_type", invtokens(ty))
	st_local("_dpd_class", invtokens(cl))
	st_local("_dpd_miss", invtokens(mi))
	st_local("_dpd_uniq", invtokens(un))
	st_local("_dpd_stat", invtokens(st))
	st_local("_dpd_changed", invtokens(ch))
}
end

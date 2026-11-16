*! _dataprobe_byagg
*! Group aggregates inside a dataprobe byrule() expression
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper; scan and rewrite answer by c_local)

// A byrule() expression may hold group aggregates, each computed over the
// rows of its by group (the call's if/in sample, a missing byvars value its
// own group, as in by):
//
//   total(exp)   sum of exp over the group's rows where it is nonmissing
//   mean(exp)    mean of exp over those rows
//   gmin(exp)    smallest value; gmax(exp) largest value
//   spread(exp)  gmax(exp) - gmin(exp)
//   count(exp)   number of the group's rows where exp is nonmissing
//
// exp is an expression argument (_dataprobe_exprarg gen): missing on a row
// where a variable it names is missing, with missing(), missing literals,
// _n, _N and subscripts refused.  total, mean, gmin, gmax and spread of a
// group with no nonmissing value are missing, and such a group fails the
// rule whatever the comparison (a missing value compares as larger than
// any number, so total(w) > 0.5 would otherwise hold).  min() and max()
// keep their meaning as Stata's row functions.  None of these names is a
// Stata expression function, so no expression that ran before 2.1.0 holds
// one.  An aggregate inside an aggregate's argument is an error (rc 198).
//
//   scan "expression"
//       c_local _ag_n (number of aggregates), _ag_k# (kind), _ag_a#
//       (argument text, without the outer parentheses).
//   rewrite "expression", names(newvars)
//       c_local _ag_exp: the expression with the #th aggregate call
//       replaced by the #th name.
//   make kind newvar "argument", [by(varlist)]
//       newvar (double) holds the aggregate on every row of its group.
//   post "rule" gid ind, cond(exp) [scopein(in a/b)] rf(frame) mask(#)
//          nscope(#) [hz(#) pfx(str) grp(str) lab(str)]
//       The gate record of a byrule() entry with an aggregate: the failing
//       groups (distinct gid with an in-scope row whose ind is 1; a group
//       fails when the rule is false on any of its rows), masked by
//       _dataprobe_mcount against the groups with a row in scope as a row
//       count is against N.  The rows are not sorted, so scopein()'s
//       by() block stays valid.  r(nbad), r(ntot).

capture mata: mata drop _dataprobe_ag_idc()
capture mata: mata drop _dataprobe_ag_close()
capture mata: mata drop _dataprobe_ag_walk()
mata:
// 1 when c (one byte) can be part of a name: an ASCII letter, digit or _,
// or a byte of a Unicode character; 0 for "" (past the end)
real scalar _dataprobe_ag_idc(string scalar c)
{
	if (c == "") return(0)
	if (regexm(c, "[A-Za-z0-9_]")) return(1)
	return(ascii(c)[1] >= 128)
}

// position of the ")" closing the "(" at p, 0 when it is not closed (the
// rule of _dataprobe_exprarg: Mata in an autoloaded ado is file-private)
real scalar _dataprobe_ag_close(string scalar s, real scalar p)
{
	real scalar i, j, n, depth
	string scalar c
	n = strlen(s)
	depth = 0
	for (i = p; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == char(96) & substr(s, i + 1, 1) == char(34)) {
			j = strpos(substr(s, i + 2, .), char(34) + char(39))
			if (j == 0) return(0)
			i = i + j + 2
			continue
		}
		if (c == char(34)) {
			j = strpos(substr(s, i + 1, .), char(34))
			if (j == 0) return(0)
			i = i + j
			continue
		}
		if (c == "(") depth++
		else if (c == ")") {
			depth--
			if (depth == 0) return(i)
		}
	}
	return(0)
}

// walk the expression in local expr; mode 0 scans (locals _ag_n, _ag_k#,
// _ag_a#), mode 1 rewrites with the names in local names (local _ag_exp).
// _ag_err: "" or "nest" (an aggregate in an argument) or "open"
void _dataprobe_ag_walk(real scalar mode)
{
	string scalar s, c, nm, out, nx
	string rowvector kinds, names
	real scalar i, j, n, e, k, p
	s = st_local("expr")
	n = strlen(s)
	kinds = ("total", "mean", "gmin", "gmax", "spread", "count")
	if (mode) names = tokens(st_local("names"))
	st_local("_ag_err", "")
	out = ""
	k = 0
	i = 1
	while (i <= n) {
		c = substr(s, i, 1)
		if (c == char(96) & substr(s, i + 1, 1) == char(34)) {
			j = strpos(substr(s, i + 2, .), char(34) + char(39))
			if (j == 0) j = n - i - 1
			out = out + substr(s, i, j + 3)
			i = i + j + 3
			continue
		}
		if (c == char(34)) {
			j = strpos(substr(s, i + 1, .), char(34))
			if (j == 0) j = n - i
			out = out + substr(s, i, j + 1)
			i = i + j + 1
			continue
		}
		if (_dataprobe_ag_idc(c) & !strpos("0123456789", c)) {
			// a name preceded by a name character or a digit is part of it
			j = i
			while (_dataprobe_ag_idc(substr(s, j, 1))) j++
			nm = substr(s, i, j - i)
			p = j
			while (p <= n & substr(s, p, 1) == " ") p++
			nx = substr(s, p, 1)
			if (nx == "(" & anyof(kinds, nm)) {
				e = _dataprobe_ag_close(s, p)
				if (e == 0) {
					st_local("_ag_err", "open")
					return
				}
				k++
				if (!mode) {
					st_local("_ag_k" + strofreal(k), nm)
					st_local("_ag_a" + strofreal(k), substr(s, p + 1, e - p - 1))
				}
				else out = out + names[k]
				i = e + 1
				continue
			}
			out = out + nm
			i = j
			continue
		}
		if (strpos("0123456789", c)) {
			j = i
			while (_dataprobe_ag_idc(substr(s, j, 1)) | substr(s, j, 1) == ".") j++
			out = out + substr(s, i, j - i)
			i = j
			continue
		}
		out = out + c
		i++
	}
	if (!mode) st_local("_ag_n", strofreal(k))
	else st_local("_ag_exp", out)
}
end

program define _dataprobe_byagg, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken sub 0 : 0
        if "`sub'" == "scan" {
            gettoken expr 0 : 0
            mata: _dataprobe_ag_walk(0)
            if "`_ag_err'" == "open" {
                display as error "byrule(): an aggregate's ( is not closed"
                exit 198
            }
            local N = `_ag_n'
            forvalues i = 1/`N' {
                local K`i' `_ag_k`i''
                local A`i' `"`macval(_ag_a`i')'"'
            }
            // an aggregate inside an aggregate
            forvalues i = 1/`N' {
                local expr `"`macval(A`i')'"'
                mata: _dataprobe_ag_walk(0)
                if `_ag_n' > 0 {
                    display as error "byrule(): an aggregate cannot hold another aggregate"
                    exit 198
                }
            }
            c_local _ag_n `N'
            forvalues i = 1/`N' {
                c_local _ag_k`i' `K`i''
                c_local _ag_a`i' `"`macval(A`i')'"'
            }
        }
        else if "`sub'" == "rewrite" {
            gettoken expr 0 : 0
            syntax , NAMes(string)
            mata: _dataprobe_ag_walk(1)
            c_local _ag_exp `"`macval(_ag_exp)'"'
        }
        else if "`sub'" == "make" {
            gettoken kind 0 : 0
            gettoken newvar 0 : 0
            gettoken arg 0 : 0
            syntax , [BY(varlist)]
            confirm new variable `newvar'
            tempvar x nn
            _dataprobe_exprarg gen `x' `"(`macval(arg)')"', ctx(byrule)
            local bp ""
            if "`by'" != "" local bp "bysort `by':"
            if "`kind'" == "count" {
                quietly `bp' egen double `newvar' = count(`x')
            }
            else {
                local fn = cond("`kind'" == "gmin", "min", cond("`kind'" == "gmax", "max", "`kind'"))
                if "`kind'" == "spread" {
                    tempvar lo
                    quietly `bp' egen double `lo' = min(`x')
                    quietly `bp' egen double `newvar' = max(`x')
                    quietly replace `newvar' = `newvar' - `lo'
                }
                else quietly `bp' egen double `newvar' = `fn'(`x')
                // no nonmissing value: missing, never total()'s 0
                quietly `bp' egen long `nn' = count(`x')
                quietly replace `newvar' = . if `nn' == 0
            }
        }
        else if "`sub'" == "post" {
            gettoken rule 0 : 0
            syntax varlist(min=2 max=2 numeric), COND(string) RF(name) MASK(integer) ///
                NSCOPE(real) [HZ(string) SCOPEIN(string) PFX(string) GRP(string) LAB(string)]
            gettoken gid ind : varlist
            local ind = strtrim("`ind'")
            local ra = 1
            local rb = _N
            if `"`scopein'"' != "" {
                local _r = substr(`"`scopein'"', 4, .)
                local ra : word 1 of `=subinstr("`_r'", "/", " ", 1)'
                local rb : word 2 of `=subinstr("`_r'", "/", " ", 1)'
            }
            tempvar t
            local nbad = 0
            local ntot = 0
            if _N > 0 {
                quietly generate byte `t' = 0
                quietly replace `t' = 1 if (`cond') & `ind' == 1 `scopein'
                _dataprobe_byhits distinct `gid', touse(`t') range(`ra'/`rb')
                local nbad = r(n)
                quietly replace `t' = 0
                quietly replace `t' = 1 if (`cond') `scopein'
                _dataprobe_byhits distinct `gid', touse(`t') range(`ra'/`rb')
                local ntot = r(n)
            }
            local ok = (`nbad' == 0)
            _dataprobe_mcount `nbad' `mask' `ntot' `hz'
            local nbs "`r(s)'"
            local onum = r(num)
            local om = r(masked)
            local mins = cond(`om' | `nbad' < 1, ., `nbad')
            local gnoun = cond("`nbs'" == "1", "group fails", "groups fail")
            local msg `"`pfx'byrule(`lab'): `nbs' `gnoun' `macval(rule)'"'
            frame post `rf' ("byrule") ("invariant") (`ok') (`"`lab'"') ///
                (`"`lab'"') (`"`macval(grp)'"') ("`nbs' `gnoun'") (`onum') ///
                (`"`macval(rule)'"') (`nscope') ("") (`"`macval(msg)'"') (`mins') (`om')
            return scalar nbad = `nbad'
            return scalar ntot = `ntot'
        }
        else {
            display as error "_dataprobe_byagg: unknown subcommand `sub'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

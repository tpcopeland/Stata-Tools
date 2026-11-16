*! _dataprobe_exprarg
*! Expression arguments for dataprobe stat() and byrule() aggregates
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass (internal helper; results by c_local)

// An expression argument is a parenthesised expression written where a
// variable is expected: stat(mean (dx == 1) 0.1 0.3), or the argument of a
// byrule() aggregate such as total(w * (arm == 1)).  The text is never
// macro-expanded here: it is read with macval() and Mata st_local().
//
//   split "spec", v1(newvar) v2(newvar) k(#)
//       spec is one stat() entry.  The variable slot (word 2, and word 3
//       after "ratio") is an expression when it starts with "(": the text
//       up to the matching ")" (parentheses inside "..." or `"..."' string
//       literals do not count) is evaluated into v1() (v2() for ratio's
//       den) by gen below, and the name replaces the text.  An unbalanced
//       "(" is an error (rc 198).  c_local in the caller (dataprobe):
//       part (the rewritten entry, unchanged without an expression), and
//       for stat() entry k: stat_xlab# (the label, "mean (dx == 1)", or ""
//       without an expression), stat_xvar# (the variable text, "(dx == 1)"),
//       stat_xops# (the variables the expressions name) and stat_xd# (1
//       when one of them has a date format: under safe its mean may be a
//       date).
//
//   gen newvar "expression", ctx(string)
//       generate double newvar = (expression), then missing on every row
//       where a variable the expression names is missing (missing(), so ""
//       for a string variable).  Stata itself evaluates (x > 5) as 1 and
//       (x == 1) as 0 when x is missing; here such a row is missing, so a
//       mean is the share among the rows whose operands are all known and
//       pmiss counts the others.  Because that rule leaves missing() and
//       missing literals (., .a-.z) nothing to test, they are refused, as
//       are _n, _N and subscripts (the expression is read one row at a
//       time): rc 198.  A string-valued expression is rc 109; one that
//       cannot be evaluated returns Stata's rc.  c_local _xa_ops: the
//       variables the expression names.  ctx() names the option in
//       messages (stat, byrule).
//
//   link isx stat var newvar, lv(varlist) mv(varlist)
//       The per-group count of a stat() expression under by() and
//       maskrare.  isx is 1 for an expression entry without its own if.
//       For sum of a 0/1 expression var, newvar = (var == 1); for n and
//       pmiss, newvar = missing(var).  When newvar's rows are exactly the
//       rows of one value of a variable in lv() (a frequency-table level)
//       or exactly the missing rows of one in mv(), c_local _xa_link names
//       that variable and newvar is kept (byte 0/1); otherwise _xa_link is
//       "" and newvar is not left behind.  dataprobe then withholds the
//       count in the groups where it withholds that variable's own.
//
//   fix frame "stat(templabel)" "label" "variable"
//       With a label (an expression entry), the last row of dataprobe's
//       record frame, posted with the tempvar's name, gets label and
//       variable as given, and its message the label in place of the first
//       "stat(templabel)".  frame post expands a macro inside its arguments
//       once more and stops at a backtick, so the text is written in Mata.

capture mata: mata drop _dataprobe_xa_idc()
capture mata: mata drop _dataprobe_xa_close()
capture mata: mata drop _dataprobe_xa_split()
capture mata: mata drop _dataprobe_xa_scan()
capture mata: mata drop _dataprobe_xa_show()
capture mata: mata drop _dataprobe_xa_fix()
capture mata: mata drop _dataprobe_xa_link()
mata:
// 1 when c (one byte) can be part of a name: an ASCII letter, digit or _,
// or a byte of a Unicode character; 0 for "" (past the end)
real scalar _dataprobe_xa_idc(string scalar c)
{
	if (c == "") return(0)
	if (regexm(c, "[A-Za-z0-9_]")) return(1)
	return(ascii(c)[1] >= 128)
}

// position of the ")" closing the "(" at p, 0 when it is not closed
real scalar _dataprobe_xa_close(string scalar s, real scalar p)
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

// stat() entry in local spec -> locals _xa_spec _xa_s1 _xa_s2 _xa_e1 _xa_e2
// _xa_w1 _xa_w2 (the slots as written) _xa_err (1: an unbalanced
// parenthesis); an expression slot becomes the name in local v1 (v2)
void _dataprobe_xa_split()
{
	string scalar s, out, w, c
	real scalar i, n, st, nsl, k, e, any
	s = st_local("spec")
	st_local("_xa_w1", "")
	st_local("_xa_w2", "")
	n = strlen(s)
	st_local("_xa_err", "0")
	st_local("_xa_s1", "0")
	st_local("_xa_s2", "0")
	st_local("_xa_e1", "")
	st_local("_xa_e2", "")
	i = 1
	while (i <= n & substr(s, i, 1) == " ") i++
	st = i
	while (i <= n & substr(s, i, 1) != " " & substr(s, i, 1) != "(") i++
	w = substr(s, st, i - st)
	out = substr(s, 1, i - 1)
	nsl = (strlower(w) == "ratio" ? 2 : 1)
	any = 0
	for (k = 1; k <= nsl; k++) {
		while (i <= n) {
			c = substr(s, i, 1)
			if (c != " " & c != ",") break
			out = out + c
			i++
		}
		if (i > n) break
		if (substr(s, i, 1) == "(") {
			e = _dataprobe_xa_close(s, i)
			if (e == 0) {
				st_local("_xa_err", "1")
				return
			}
			st_local("_xa_e" + strofreal(k), substr(s, i, e - i + 1))
			st_local("_xa_w" + strofreal(k), substr(s, i, e - i + 1))
			st_local("_xa_s" + strofreal(k), "1")
			// the name stands apart from what follows
			out = out + (k == 1 & substr(out, strlen(out), 1) != " " ? " " : "") + st_local("v" + strofreal(k)) + " "
			i = e + 1
			any = 1
		}
		else {
			st = i
			while (i <= n) {
				c = substr(s, i, 1)
				if (c == " " | c == ",") break
				i++
			}
			out = out + substr(s, st, i - st)
			st_local("_xa_w" + strofreal(k), substr(s, st, i - st))
		}
	}
	w = strlower(w)
	if (w == "p50") w = "median"
	if (nsl == 2) {
		st_local("_xa_lab", "ratio " + st_local("_xa_w1") + "/" + st_local("_xa_w2"))
		st_local("_xa_var", st_local("_xa_w1") + " " + st_local("_xa_w2"))
	}
	else {
		st_local("_xa_lab", w + " " + st_local("_xa_w1"))
		st_local("_xa_var", st_local("_xa_w1"))
	}
	out = out + substr(s, i, .)
	st_local("_xa_spec", (any ? out : s))
}

// scan the expression in local expr: the variables it names in _xa_ops, and
// in _xa_bad what is refused ("" when nothing): missing, literal, subscript
void _dataprobe_xa_scan()
{
	string scalar s, c, nm, ops, nx
	real scalar i, j, n
	s = st_local("expr")
	n = strlen(s)
	ops = ""
	st_local("_xa_bad", "")
	i = 1
	while (i <= n) {
		c = substr(s, i, 1)
		// string literals: skipped whole
		if (c == char(96) & substr(s, i + 1, 1) == char(34)) {
			j = strpos(substr(s, i + 2, .), char(34) + char(39))
			if (j == 0) break
			i = i + j + 3
			continue
		}
		if (c == char(34)) {
			j = strpos(substr(s, i + 1, .), char(34))
			if (j == 0) break
			i = i + j + 1
			continue
		}
		// numbers, including 1e-5 and .5
		if (strpos("0123456789", c) | (c == "." & strpos("0123456789", substr(s, i + 1, 1)) & substr(s, i + 1, 1) != "")) {
			while (i <= n & strpos("0123456789.", substr(s, i, 1))) i++
			if (i <= n & strpos("eE", substr(s, i, 1))) {
				nx = substr(s, i + 1, 1)
				if (strpos("+-", nx) & nx != "") {
					if (strpos("0123456789", substr(s, i + 2, 1)) & substr(s, i + 2, 1) != "") i = i + 2
				}
				else if (strpos("0123456789", nx) & nx != "") i = i + 1
				while (i <= n & strpos("0123456789", substr(s, i, 1))) i++
			}
			continue
		}
		// a missing literal: . or .a-.z
		if (c == ".") {
			st_local("_xa_bad", "literal")
			return
		}
		// a name: ASCII letters, digits, _ and the bytes of a Unicode letter
		if (_dataprobe_xa_idc(c) & !strpos("0123456789", c)) {
			j = i
			while (_dataprobe_xa_idc(substr(s, j, 1))) j++
			nm = substr(s, i, j - i)
			i = j
			while (j <= n & substr(s, j, 1) == " ") j++
			nx = substr(s, j, 1)
			if (nx == "(") {
				if (nm == "missing" | nm == "mi") {
					st_local("_xa_bad", "missing")
					return
				}
				continue
			}
			if (nx == "[" | nm == "_n" | nm == "_N") {
				st_local("_xa_bad", "subscript")
				return
			}
			if (_st_varindex(nm, 0) < .) {
				if (!anyof(tokens(ops), nm)) ops = ops + " " + nm
			}
			continue
		}
		i++
	}
	st_local("_xa_ops", strtrim(ops))
}

// the last row of the current frame: label, variable and msg from locals
// lab, var and was (the posted "stat(label)")
void _dataprobe_xa_fix()
{
	real scalar n, p
	string scalar m, w
	n = st_nobs()
	st_sstore(n, "label", st_local("lab"))
	st_sstore(n, "variable", st_local("var"))
	m = st_sdata(n, "msg")
	w = st_local("was")
	p = strpos(m, w)
	if (p) m = substr(m, 1, p - 1) + "stat(" + st_local("lab") + ")" + substr(m, p + strlen(w), .)
	st_sstore(n, "msg", m)
}

// the first variable of lv (mv) one of whose values (whose missing rows)
// covers exactly the rows where 0/1 variable ind is 1; "" when none
string scalar _dataprobe_xa_link(string scalar ind, string scalar lv, string scalar mv)
{
	real colvector r, sel, x
	string colvector sx
	string rowvector L
	real scalar j, n
	r = st_data(., ind)
	sel = selectindex(r :== 1)
	n = length(sel)
	if (n == 0) return("")
	sel = vec(sel)
	L = tokens(lv)
	for (j = 1; j <= cols(L); j++) {
		if (st_isstrvar(L[j])) {
			sx = st_sdata(., L[j])
			if (all(sx[sel, 1] :== sx[sel[1], 1])) {
				if (sum(sx :== sx[sel[1], 1]) == n) return(L[j])
			}
		}
		else {
			x = st_data(., L[j])
			if (all(x[sel, 1] :== x[sel[1], 1])) {
				if (sum(x :== x[sel[1], 1]) == n) return(L[j])
			}
		}
	}
	L = tokens(mv)
	for (j = 1; j <= cols(L); j++) {
		if (st_isstrvar(L[j])) {
			if (all((st_sdata(., L[j]) :== "") :== (r :== 1))) return(L[j])
		}
		else if (all((st_data(., L[j]) :>= .) :== (r :== 1))) return(L[j])
	}
	return("")
}

// the expression as the console shows it: no SMCL, quote or macro character live
string scalar _dataprobe_xa_show(string scalar s)
{
	string scalar out
	out = subinstr(s, "{", "{c -(}")
	out = subinstr(out, char(96), "{char 96}")
	out = subinstr(out, char(34), "{char 34}")
	out = subinstr(out, char(36), "{char 36}")
	return(out)
}
end

program define _dataprobe_exprarg
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken sub 0 : 0
        if "`sub'" == "split" {
            gettoken spec 0 : 0
            syntax , V1(name) V2(name) K(integer)
            mata: _dataprobe_xa_split()
            if `_xa_err' {
                mata: st_local("_xs", _dataprobe_xa_show(st_local("spec")))
                display as error `"stat(): an expression's "(" is not closed: `macval(_xs)'"'
                exit 198
            }
            local ops ""
            local isd = 0
            foreach j in 1 2 {
                if !`_xa_s`j'' continue
                _dataprobe_exprarg gen `v`j'' `"`macval(_xa_e`j')'"', ctx(stat)
                local ops "`ops' `_xa_ops'"
            }
            local ops : list uniq ops
            foreach v of local ops {
                if regexm("`: format `v''", "^%-?(t|d)") local isd = 1
            }
            if !`_xa_s1' & !`_xa_s2' {
                local _xa_lab ""
                local _xa_var ""
            }
            c_local part `"`macval(_xa_spec)'"'
            c_local stat_xlab`k' `"`macval(_xa_lab)'"'
            c_local stat_xvar`k' `"`macval(_xa_var)'"'
            c_local stat_xops`k' "`ops'"
            c_local stat_xd`k' `isd'
        }
        else if "`sub'" == "gen" {
            gettoken newvar 0 : 0
            gettoken expr 0 : 0
            syntax , CTX(string)
            confirm new variable `newvar'
            local _xa_ops ""
            mata: _dataprobe_xa_scan()
            mata: st_local("_xs", _dataprobe_xa_show(st_local("expr")))
            local _h1 "count missing values with pmiss"
            local _h2 "use rule() or byrule()"
            if "`ctx'" == "byrule" {
                local _h1 "count() counts the nonmissing values"
                local _h2 "keep the subscript outside the aggregate"
            }
            if "`_xa_bad'" == "missing" {
                display as error `"`ctx'(): expression `macval(_xs)' uses missing(); a row where a variable of the expression is missing is missing, so missing() has nothing to test (`_h1', or generate the variable yourself)"'
                exit 198
            }
            if "`_xa_bad'" == "literal" {
                display as error `"`ctx'(): expression `macval(_xs)' holds a missing value (. or .a-.z); a row where a variable of the expression is missing is missing, so a comparison with . has nothing to test"'
                exit 198
            }
            if "`_xa_bad'" == "subscript" {
                display as error `"`ctx'(): expression `macval(_xs)' uses _n, _N or a subscript; an expression argument is read one row at a time (`_h2', or generate the variable yourself)"'
                exit 198
            }
            capture quietly generate double `newvar' = `macval(expr)'
            if _rc {
                local _erc = _rc
                if `_erc' == 109 display as error `"`ctx'(): expression `macval(_xs)' is not numeric"'
                else display as error `"`ctx'(): cannot evaluate expression `macval(_xs)'"'
                exit `_erc'
            }
            if "`_xa_ops'" != "" {
                local _mc ""
                foreach _v of local _xa_ops {
                    local _mc = cond("`_mc'" == "", "missing(`_v')", "`_mc' | missing(`_v')")
                }
                quietly replace `newvar' = . if `_mc'
            }
            c_local _xa_ops "`_xa_ops'"
        }
        else if "`sub'" == "link" {
            c_local _xa_link ""
            gettoken isx 0 : 0
            gettoken st 0 : 0
            gettoken var 0 : 0
            gettoken newvar 0 : 0, parse(" ,")
            syntax [, LV(string) MV(string)]
            local ok = `isx' & inlist("`st'", "sum", "n", "pmiss")
            if `ok' & "`st'" == "sum" {
                quietly count if !missing(`var') & !inlist(`var', 0, 1)
                local ok = (r(N) == 0)
                local mv ""
            }
            else local lv ""
            if `ok' {
                if "`st'" == "sum" quietly generate byte `newvar' = (`var' == 1)
                else quietly generate byte `newvar' = missing(`var')
                mata: st_local("_lk", _dataprobe_xa_link(st_local("newvar"), st_local("lv"), st_local("mv")))
                if "`_lk'" == "" drop `newvar'
                c_local _xa_link "`_lk'"
            }
        }
        else if "`sub'" == "fix" {
            gettoken rf 0 : 0
            gettoken was 0 : 0
            gettoken lab 0 : 0
            gettoken var 0 : 0
            mata: st_local("_hl", strofreal(st_local("lab") != ""))
            if `_hl' {
                frame `rf' {
                    mata: _dataprobe_xa_fix()
                }
            }
        }
        else {
            display as error "_dataprobe_exprarg: unknown subcommand `sub'"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

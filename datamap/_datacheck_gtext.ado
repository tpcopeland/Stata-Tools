*! _datacheck_gtext Version 1.9.2  2026/10/05
*! Group-value text for a by() group or one row: the ledger form and the display form
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (internal helper)

// Syntax: _datacheck_gtext varlist, group(varname) | row(#)
//
// The ledger records a datacheck by() group by its VALUES, not its number
// within the call: "lab_site=3 lab_year=2015".  A number names a different
// level when a site is added between extracts; a value does not.  The value
// is the stored value, never its value label, so a relabelled level is the
// same group.  The form of one value:
//   numeric          the number as written ("3", "2015", "-1.5"); a value that
//                    "%21.15g" would not return exactly (a float such as 0.1) is
//                    written as the shortest decimal text that reads back to
//                    the stored value, and in %21x only if none does
//   extended missing "." ".a" ... ".z" as written
//   string           in square brackets, "[abc]"; a blank string is "[]".  Any of
//                    \ " ' ` $ [ ] { } and tab, line feed, carriage return is
//                    written as \xHH (two lowercase hex digits), so a value
//                    holding spaces, "=", "|", parentheses or quotes cannot be
//                    mistaken for a separator, and no quote, macro or SMCL
//                    character is live in the stored text.
// The display form is the label the output prints: a numeric value's value
// label if it has one, else the value; a blank string is (blank); a string
// as written (escaped as above).  Several variables are joined by one space.
//
// group(): r(G), and r(led#) / r(disp#) for group number 1..G (the first row
// of each group in memory order).  row(#): r(led), r(disp), and r(val), the
// ledger form of the first variable's value alone.

capture mata: mata drop _datacheck_gtext_esc()
capture mata: mata drop _datacheck_gtext_num()
capture mata: mata drop _datacheck_gtext_one()
capture mata: mata drop _datacheck_gtext_engine()
mata:
string scalar _datacheck_gtext_esc(string scalar s)
{
	real scalar i
	string scalar out, c
	real rowvector bad
	bad = (92, 34, 39, 96, 36, 91, 93, 123, 125, 9, 10, 13)
	out = ""
	for (i = 1; i <= strlen(s); i++) {
		c = substr(s, i, 1)
		if (any(bad :== ascii(c))) out = out + char(92) + "x" + substr("0123456789abcdef", floor(ascii(c) / 16) + 1, 1) + substr("0123456789abcdef", mod(ascii(c), 16) + 1, 1)
		else out = out + c
	}
	return(out)
}

// the ledger text of one number: "%21.15g" when that returns it exactly (so an
// integer or a short double keeps its text), else the fewest significant digits
// ("%21.<d>g", d = 1..9 for a float, 16..17 for a double) that read back to the
// stored value (a float is compared after float()), else "%21x"
string scalar _datacheck_gtext_num(real scalar x, string scalar typ)
{
	string scalar s
	real scalar d, lo, hi
	if (missing(x)) return(strtrim(strofreal(x, "%21.15g")))
	s = strtrim(strofreal(x, "%21.15g"))
	if (strtoreal(s) == x) return(s)
	lo = (typ == "float" ? 1 : 16)
	hi = (typ == "float" ? 9 : 17)
	for (d = lo; d <= hi; d++) {
		s = strtrim(strofreal(x, "%21." + strofreal(d) + "g"))
		if ((typ == "float" ? floatround(strtoreal(s)) : strtoreal(s)) == x) return(s)
	}
	return(strtrim(strofreal(x, "%21x")))
}

// one value of variable v at row r: ledger form, display form
void _datacheck_gtext_one(string scalar v, real scalar r, string scalar led, ///
	string scalar disp)
{
	string scalar s, lbl
	real scalar x
	if (st_isstrvar(v)) {
		s = _datacheck_gtext_esc(st_sdata(r, v))
		led = "[" + s + "]"
		disp = (s == "" ? "(blank)" : s)
	}
	else {
		x = st_data(r, v)
		led = _datacheck_gtext_num(x, st_vartype(v))
		disp = led
		lbl = st_varvaluelabel(v)
		if (lbl != "") {
			s = st_vlmap(lbl, x)
			if (s != "") disp = _datacheck_gtext_esc(s)
		}
	}
}

void _datacheck_gtext_engine(string scalar vlist, string scalar gname, ///
	real scalar row)
{
	string rowvector vars
	string scalar led, disp, l1, d1
	real colvector g, first
	real scalar j, k, G, i
	vars = tokens(vlist)
	if (gname == "") {
		led = ""
		disp = ""
		for (j = 1; j <= cols(vars); j++) {
			_datacheck_gtext_one(vars[j], row, l1, d1)
			if (j == 1) st_local("_val", l1)
			led = led + (j > 1 ? " " : "") + vars[j] + "=" + l1
			disp = disp + (j > 1 ? " " : "") + d1
		}
		st_local("_led", led)
		st_local("_disp", disp)
		return
	}
	g = st_data(., gname)
	G = max(g)
	if (G >= .) G = 0
	first = J(G, 1, .)
	for (i = 1; i <= rows(g); i++) {
		if (g[i] < . & first[g[i]] >= .) first[g[i]] = i
	}
	st_local("_G", strofreal(G))
	for (k = 1; k <= G; k++) {
		led = ""
		disp = ""
		for (j = 1; j <= cols(vars); j++) {
			_datacheck_gtext_one(vars[j], first[k], l1, d1)
			led = led + (j > 1 ? " " : "") + vars[j] + "=" + l1
			disp = disp + (j > 1 ? " " : "") + d1
		}
		st_local("_led" + strofreal(k), led)
		st_local("_disp" + strofreal(k), disp)
	}
}
end

capture program drop _datacheck_gtext
local _drop_rc = _rc
if !inlist(`_drop_rc', 0, 111) exit `_drop_rc'
program define _datacheck_gtext, rclass
	version 16.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		syntax varlist, [GROUP(varname numeric) ROW(integer 0)]
		if ("`group'" == "") == (`row' == 0) {
			display as error "_datacheck_gtext: specify one of group() and row()"
			exit 198
		}
		local _G = 0
		local _led ""
		local _disp ""
		local _val ""
		mata: _datacheck_gtext_engine("`varlist'", "`group'", `row')
		if "`group'" != "" {
			return scalar G = `_G'
			forvalues k = 1/`_G' {
				return local led`k' `"`macval(_led`k')'"'
				return local disp`k' `"`macval(_disp`k')'"'
			}
		}
		else {
			return local led `"`macval(_led)'"'
			return local disp `"`macval(_disp)'"'
			return local val `"`macval(_val)'"'
		}
	}
	local rc = _rc
	set varabbrev `_orig_varabbrev'
	if `rc' exit `rc'
end

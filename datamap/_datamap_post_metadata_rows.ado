*! _datamap_post_metadata_rows Version 1.10.5  2026/10/21
*! Post common variable-metadata rows from a loaded dataset
*! Author: Timothy P Copeland, Karolinska Institutet

// Builds the caller's local `dst' as a Stata string expression that evaluates
// to the caller's local `src' verbatim: runs of ordinary characters in plain
// quotes joined with char() calls for each double quote, backtick and dollar
// sign, so a label holding any of them cannot be read as quote or macro syntax
// when the expression is spliced into a -post- line.
capture mata: mata drop _datamap_strexpr()
capture mata: mata drop _datamap_ucut()
mata:
// Prefix of s at most nb bytes long that never splits a UTF-8 character:
// steps back over continuation bytes (0x80-0xBF) at the cut.  substr() cuts
// bytes, and a str# column or name cut mid-character holds invalid UTF-8.
string scalar _datamap_ucut(string scalar s, real scalar nb)
{
	real scalar i, a
	if (strlen(s) <= nb) return(s)
	i = nb
	while (i > 0) {
		a = ascii(substr(s, i + 1, 1))
		if (a < 128 | a >= 192) break
		i--
	}
	return(substr(s, 1, i))
}
void _datamap_strexpr(string scalar src, string scalar dst)
{
	string scalar s, out, run, ch
	real scalar i, a
	s = st_local(src)
	out = ""
	run = ""
	for (i = 1; i <= strlen(s); i++) {
		ch = substr(s, i, 1)
		a = ascii(ch)
		if (a == 34 | a == 96 | a == 36) {
			if (run != "") out = out + (out == "" ? "" : "+") + char(34) + run + char(34)
			run = ""
			out = out + (out == "" ? "" : "+") + "char(" + strofreal(a) + ")"
		}
		else run = run + ch
	}
	if (run != "" | out == "") out = out + (out == "" ? "" : "+") + char(34) + run + char(34)
	st_local(dst, "(" + out + ")")
}
end

program define _datamap_post_metadata_rows, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _frame_open = 0
    tempname _cfr
    capture noisily {
        syntax, POSTName(name) CLASSifications(string) SOURCECommand(string) ///
            SOURCE(string) DSName(string) NVARS(integer) ///
            [OUtput(string) DSLabel(string) VARLIST(string) DATASIGnature(string) DATESAFE ///
            NOSTATS MINCell(integer 0)]

        mata: st_local("source", _datamap_ucut(st_local("source"), 2045))
        mata: st_local("output", _datamap_ucut(st_local("output"), 2045))
        // the data label is read here, not passed on the command line: a
        // label with a backtick or quote cannot be carried through syntax
        local dslabel : data label
        mata: st_local("dslabel", _datamap_ucut(st_local("dslabel"), 2045))

        // Frame, not -preserve-: preserve costs a full in-memory copy of the
        // dataset (see _datamap_nuniq.ado), and this only reads a small lookup.
        frame create `_cfr'
        local _frame_open = 1
        frame `_cfr' {
        quietly use `"`classifications'"', clear
        quietly count
        local C = r(N)
        // Index-keyed metadata locals: locals keyed by variable name
        // (meta_class_<varname>) exceed Stata's 31-character macro-name
        // limit for long variable names and error r(198).
        local classvars ""
        forvalues i = 1/`C' {
            local vn = varname[`i']
            local classvars "`classvars' `vn'"
            local m_class`i' = classification[`i']
            local m_mn`i' = missing_n[`i']
            local m_mp`i' = missing_pct[`i']
            local m_uv`i' = unique_vals[`i']
            local m_uc`i' = unique_capped[`i']
        }
        }
        frame drop `_cfr'
        local _frame_open = 0

        if `"`varlist'"' == "" local varlist "`classvars'"
        local obs = c(N)

        foreach vname of local varlist {
            capture confirm variable `vname', exact
            if _rc continue

            local vtype : type `vname'
            local vfmt : format `vname'
            local vlab : variable label `vname'
            local vallabname : value label `vname'
            local ix : list posof "`vname'" in classvars
            local varclass "unknown"
            local nmiss = .
            local pctmiss = .
            local nuniq = .
            // unique_capped=1 means `nuniq' is a LOWER BOUND (the classifier's
            // cap + 1), not an exact count.  It travels with the count so a
            // consumer of the saved metadata cannot mistake one for the other.
            local ncapped = 0
            if `ix' > 0 {
                local varclass "`m_class`ix''"
                if "`varclass'" == "" local varclass "unknown"
                local nmiss = `m_mn`ix''
                local pctmiss = `m_mp`ix''
                local nuniq = `m_uv`ix''
                local ncapped = `m_uc`ix''
                if missing(`ncapped') local ncapped = 0
            }
            if missing(`nmiss') {
                quietly count if missing(`vname')
                local nmiss = r(N)
            }
            if missing(`pctmiss') {
                local pctmiss = 0
                if `obs' > 0 local pctmiss = round(100 * `nmiss' / `obs', 0.1)
            }
            local mean = .
            local sd = .
            local p50 = .
            local p25 = .
            local p75 = .
            local vmin = .
            local vmax = .

            capture confirm numeric variable `vname'
            local is_numeric = (_rc == 0)
            // datamap's report prints summaries only for continuous
            // variables, and none under nostats; a categorical variable is
            // a frequency table subject to mincell(), and its mean (the
            // share of a 0/1 flag) would give a suppressed cell back.  The
            // saved rows follow the report.
            // The same rule as the report (_datamap_sumpolicy): under
            // datesafe nothing for a date or a date-formatted variable in
            // any class; under mincell() no mean or sd for a two- or three-valued
            // continuous variable.
            _datamap_sumpolicy, class(`varclass') vfmt("`vfmt'") `datesafe' ///
                mincell(`mincell') nuniq(`=cond(missing(`nuniq'), -1, `nuniq')')
            local _dhide = r(datehide)
            local _mhide = r(momhide)
            local _nosum = ("`nostats'" != "" & inlist("`varclass'", "continuous", "categorical")) | ///
                r(cathide)
            if `is_numeric' & "`varclass'" != "excluded" & !`_nosum' & !`_dhide' {
                quietly summarize `vname', detail
                if r(N) > 0 {
                    if !`_mhide' local mean = regexr(string(r(mean), "%21x"), "^[+]", "")
                    if !`_mhide' local sd = regexr(string(r(sd), "%21x"), "^[+]", "")
                    local p50 = regexr(string(r(p50), "%21x"), "^[+]", "")
                    local p25 = regexr(string(r(p25), "%21x"), "^[+]", "")
                    local p75 = regexr(string(r(p75), "%21x"), "^[+]", "")
                    local vmin = regexr(string(r(min), "%21x"), "^[+]", "")
                    local vmax = regexr(string(r(max), "%21x"), "^[+]", "")
                }
            }

            local notes ""
            local note0 : char `vname'[note0]
            if "`note0'" == "" local note0 0
            forvalues ni = 1/`note0' {
                local notei : char `vname'[note`ni']
                // Mata joins the text: a note holding a backtick or a quote
                // cannot be re-read as quote syntax
                if `: length local notei' > 0 {
                    if `: length local notes' == 0 local notes : copy local notei
                    else mata: st_local("notes", st_local("notes") + "<br>" + st_local("notei"))
                }
            }
            local chars ""
            local allchars : char `vname'[]
            foreach cname of local allchars {
                if !regexm("`cname'", "^note[0-9]+$") {
                    local cval : char `vname'[`cname']
                    if `: length local chars' == 0 {
                        mata: st_local("chars", st_local("cname") + "=" + st_local("cval"))
                    }
                    else mata: st_local("chars", st_local("chars") + "<br>" + st_local("cname") + "=" + st_local("cval"))
                }
            }

            // Excluded means sensitive: match the classifier, which blanks an
            // excluded variable's value label, and withhold its notes and
            // characteristics too -- both are free text that can carry values.
            if "`varclass'" == "excluded" {
                local vallabname ""
                local notes ""
                local chars ""
            }

            mata: st_local("post_vlab", _datamap_ucut(st_local("vlab"), 2045))
            mata: st_local("post_notes", _datamap_ucut(st_local("notes"), 2045))
            mata: st_local("post_chars", _datamap_ucut(st_local("chars"), 2045))
            mata: _datamap_strexpr("post_vlab", "_dmx_vlab")
            mata: _datamap_strexpr("post_notes", "_dmx_notes")
            mata: _datamap_strexpr("post_chars", "_dmx_chars")
            mata: _datamap_strexpr("dslabel", "_dmx_dslabel")
            mata: st_local("post_dsig", _datamap_ucut(st_local("datasignature"), 2045))

            post `postname' (`"`sourcecommand'"') (`"`macval(source)'"') ///
                (`"`macval(output)'"') (`"`dsname'"') (`_dmx_dslabel') ///
                (`"`vname'"') (`"`vtype'"') (`"`vfmt'"') (`"`vallabname'"') ///
                (`"`varclass'"') (`obs') (`nvars') (`nmiss') (`pctmiss') ///
                (`nuniq') (`_dmx_vlab') (`_dmx_notes') ///
                (`_dmx_chars') (`mean') (`sd') (`p50') (`p25') ///
                (`p75') (`vmin') (`vmax') (`"`macval(post_dsig)'"') (`ncapped')
        }
    }
    local rc = _rc
    if `_frame_open' capture frame drop `_cfr'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

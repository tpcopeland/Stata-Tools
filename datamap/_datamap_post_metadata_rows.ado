*! _datamap_post_metadata_rows Version 2.0.0  2026/11/10
*! Post common variable-metadata rows from a loaded dataset
*! Author: Timothy P Copeland, Karolinska Institutet

capture mata: mata drop _datamap_ucut()
capture mata: mata drop _datamap_vrow_store()
capture mata: mata drop _datamap_cut_cols()
capture mata: mata drop _datamap_cls_read()
mata:
// classtext(): the classifier's textsave() file, nine lines per variable
// (varname, classification, quality_flag, then six numbers as the macro text
// the classifier posted) into the caller's locals: classvars, _ct_C, and per
// variable i m_class<i>, m_qf<i> (text) and _ct_<f><i> for f in mn mp uv uc
// pos ml (number texts, re-evaluated by the caller).  _ct_bad is 1 when the
// line count is not a multiple of nine.
void _datamap_cls_read(string scalar fn)
{
	string colvector L
	string rowvector nm
	real scalar C, i, b
	string scalar k

	L = cat(fn)
	if (mod(rows(L), 9)) {
		st_local("_ct_bad", "1")
		return
	}
	st_local("_ct_bad", "0")
	C = rows(L) / 9
	st_local("_ct_C", strofreal(C))
	nm = J(1, C, "")
	for (i = 1; i <= C; i++) {
		b = (i - 1) * 9
		k = strofreal(i)
		nm[i] = L[b + 1]
		st_local("m_class" + k, L[b + 2])
		st_local("m_qf" + k, L[b + 3])
		st_local("_ct_mn" + k, L[b + 4])
		st_local("_ct_mp" + k, L[b + 5])
		st_local("_ct_uv" + k, L[b + 6])
		st_local("_ct_uc" + k, L[b + 7])
		st_local("_ct_pos" + k, L[b + 8])
		st_local("_ct_ml" + k, L[b + 9])
	}
	st_local("classvars", C ? invtokens(nm) : "")
}
// One new row of the current frame (the variables frame), from the caller's
// locals.  Numeric cell ncols[j] gets local nlocs[j] read as a number (a
// decimal, a %21x hex literal or a missing code, read as -frame post- read
// it; anything else is an error, never a silent missing).  Text cell
// scols[j] gets local slocs[j] verbatim, cut to at most 2045 bytes without
// splitting a UTF-8 character (the saving() width; a narrower str# column
// truncates as -post- does), except the columns named in whole, which keep
// their full text (2026-11-10: notes and characteristics, which the Markdown
// document prints in full; save cuts them, _datamap_cut_cols).  Stored, not
// spliced into a -frame post-
// expression: a cell of many quotes, backticks or dollar signs written as a
// char()-joined expression exceeded the expression limit (rc 130), and a
// -frame post- of 29 columns cost about 30 times a -post- per row.
void _datamap_vrow_store(string rowvector ncols, string rowvector nlocs,
	string rowvector scols, string rowvector slocs, | string rowvector whole)
{
	real scalar j, r, w
	real rowvector x
	string scalar s, sc

	x = J(1, cols(nlocs), .)
	sc = ""
	for (j = 1; j <= cols(nlocs); j++) {
		s = strtrim(st_local(nlocs[j]))
		x[j] = strtoreal(s)
		// what strtoreal() does not read -- the %21x form of a missing
		// value, 1.0000000000000X+3ff for r(sd) of one observation -- is
		// read by Stata's expression parser, as -frame post- read it
		if (missing(x[j]) & !regexm(s, "^[.][a-z]?$")) {
			if (sc == "") sc = st_tempname()
			if (!regexm(s, "^-?[0-9a-f][.][0-9a-f]+X[-+][0-9a-f]+$") |
				_stata("scalar " + sc + " = " + s, 1)) {
				errprintf("_datamap_post_metadata_rows: %s is not a number: %s\n", nlocs[j], s)
				exit(198)
			}
			x[j] = st_numscalar(sc)
		}
	}
	if (sc != "") st_numscalar(sc, J(0, 0, .))
	st_addobs(1)
	r = st_nobs()
	st_store(r, ncols, x)
	for (j = 1; j <= cols(scols); j++) {
		w = 0
		if (args() >= 5) w = (sum(whole :== scols[j]) > 0)
		if (w) st_sstore(r, scols[j], st_local(slocs[j]))
		else st_sstore(r, scols[j], _datamap_ucut(st_local(slocs[j]), 2045))
	}
}
// Every cell of the current frame's columns cs cut to at most nb bytes on a
// UTF-8 character boundary (_datamap_ucut): the save step's cut of the text
// the frame keeps whole.
void _datamap_cut_cols(string rowvector cs, real scalar nb)
{
	real scalar j, i
	string colvector S
	for (j = 1; j <= cols(cs); j++) {
		S = st_sdata(., cs[j])
		for (i = 1; i <= rows(S); i++) {
			if (strlen(S[i]) > nb) st_sstore(i, cs[j], _datamap_ucut(S[i], nb))
		}
	}
}
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
end

// The variables frame of the datamap collector -- one row per dataset x
// variable -- and the 27-column saving() table it carries.  Three modes:
//
//   create  _datamap_post_metadata_rows, create frame(f)
//           makes frame f: ds_index (the dataset's row in the datasets frame,
//           _datamap_collect_dataset), position (the variable's place in its
//           dataset), then the 27 saving() columns in saving() order and type,
//           except that the str2045 columns are strL in the frame: a str2045
//           cell holds 2045 bytes whatever its text, about 16 KB per row
//           over eight columns, on every run with or without saving().
//           save recasts them to str2045 in its copy.  notes and
//           characteristics hold their whole text in the frame (the
//           document prints it); save cuts them to 2045 bytes, as saving()
//           always did.  After the 27, missing_codes (2026-11-10, F3; a
//           28th saving() column, strL there, whole): the per-code missing
//           breakdown as the document prints it, ". 51, .a Refused 145",
//           with mincell() applied, "" when only . occurs or the variable is
//           excluded; filled by _datamap_collect_levels, profile.  The other
//           columns are the frame's own, read by datamap's Markdown renderer
//           and never saved: maxlen (a string variable's longest value, in
//           characters), span (a date-class variable's max - min, kept under
//           datesafe, which withholds min and max), quality_flag (the
//           classifier's quality() flag), date_family (U4: "%td daily" for a
//           date display format, _datamap_datefamily), and, filled by
//           _datamap_collect_levels, profile: missing_state and n_state (the
//           row's two margins, Missing and the nonmissing N=, each 0 shown,
//           1 below mincell(), 2 withheld as the other's complement) and the
//           string profile of a string-class variable (F4): numeric_n
//           (nonblank values real() reads), numeric_state, padded_n (values
//           with a leading or trailing space), padded_state, date_mask
//           (YMD, DMY, MDY: the masks date() reads in 95% or more of the
//           nonblank values, joined by " or "), is_strl, tokens_hidden (1
//           when the non-numeric values are withheld under datesafe), and
//           key and candidates (I2/F5, 2026-11-10; see save).
//   post    _datamap_post_metadata_rows, frame(f) dsindex(#) classifications() ...
//           one row per variable of the data in memory into frame f
//           (reportonly: the summaries datamap's document prints, read back
//           from the frame -- every one for a continuous variable, min and
//           max for a date-class one (no sort), none for the rest; without
//           it, every summary saving() writes); or
//           plain (with create and with post; dataprobe's saving(), compare(),
//           diff() and snapshot()): frame f holds the 27 saving() columns
//           only, in saving() order and type (str2045, not strL), and rows
//           are stored by Mata (_datamap_vrow_store) with notes and
//           characteristics cut to 2045 bytes, as 1.10.6's -postfile- wrote
//           them; nopctiles leaves p50, p25 and p75 missing (no sort per
//           variable).  2026-11-10 (2.0.0 Phase 4): replaces postname(), which
//           spliced each string cell into the -post- line as a char()-joined
//           expression and failed r(130) at about 700 quotes, backticks or
//           dollar signs in one cell.
//   save    _datamap_post_metadata_rows, frame(f) savefile(file) [replace csv]
//           writes the saving() file from frame f, so the file is what was
//           collected, never a second computation: the 27 columns, then
//           missing_codes, then (I2, 2026-11-10) position, date_family
//           (str32), numeric_n, numeric_pct (the document's share of N,
//           half up to 0.1), padded_n, date_mask (str20), is_strl, key and
//           candidates (strL, whole, as missing_codes; 2026-11-10: a str2045
//           cut lost text with no mark).  The new counts carry the document's
//           mask: one the document withholds (below mincell(), a
//           complement, or with the N= term withheld) is .s.  key (filled
//           by _datamap_collect_link): 1 when the values identify the
//           observations, missing values counted as values, 0 when not, .
//           when not determined; candidates (_datamap_collect_cands, under
//           quality): the placeholder candidates as the document lists them.
//           csv: the same table as comma-separated text (-export delimited-,
//           every string quoted, numbers unformatted; . is an empty cell
//           and an extended missing value such as .s is written as .s,
//           which -import delimited- reads back) in place of the .dta.
//           safe (2.0.0, U2): missing and missing_pct are .s where the
//           document withholds the Missing count (missing_state or n_state
//           not 0).
//
// The saving() schema is written once, below; create and save read it.
program define _datamap_post_metadata_rows, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _frame_open = 0
    local _save_open = 0
    tempname _cfr _svf
    capture noisily {
        syntax, [CREATE SAVEfile(string) REPLACE FRame(name) DSINDEX(integer 0) ///
            PLAIN CLASSifications(string) SOURCECommand(string) ///
            SOURCE(string) DSName(string) NVARS(integer -1) ///
            OUtput(string) DSLabel(string) VARLIST(string) DATASIGnature(string) DATESAFE ///
            NOSTATS MINCell(integer 0) REPORTonly CLASSText(string) CSV NOPCTiles ///
            SAFE]

        local _schema str16 source_command str2045 source str2045 output ///
            str2045 dataset str2045 dataset_label str32 variable ///
            str20 storage_type str32 display_format str32 value_label ///
            str20 class double N long nvars long missing ///
            double missing_pct long unique str2045 variable_label ///
            str2045 notes str2045 characteristics double mean double sd ///
            double p50 double p25 double p75 double min double max ///
            str2045 datasignature byte unique_capped
        // the frame's schema: the str2045 columns as strL (see create above)
        local _fschema : subinstr local _schema "str2045 " "strL ", all
        // the frame's own columns, after the 27 (never saved)
        // missing_codes: saved after the 27 (strL there; see create)
        local _fsave strL missing_codes
        local _fextra double maxlen double span strL quality_flag ///
            strL date_family byte missing_state byte n_state ///
            double numeric_n byte numeric_state double padded_n ///
            byte padded_state strL date_mask byte is_strl byte tokens_hidden ///
            byte key strL candidates
        // the frame's own columns that saving() leaves out; the others of
        // _fextra are saved after missing_codes (I2, see save below)
        local _fextranames maxlen span quality_flag ///
            missing_state n_state numeric_state ///
            padded_state tokens_hidden
        // I2 (2026-11-10): the columns saving() writes after missing_codes,
        // in this order
        local _i2cols position date_family numeric_n numeric_pct padded_n ///
            date_mask is_strl key candidates
        local _longcols ""
        local _sw : word count `_schema'
        forvalues _si = 1(2)`_sw' {
            if "`: word `_si' of `_schema''" == "str2045" {
                local _longcols "`_longcols' `: word `=`_si'+1' of `_schema''"
            }
        }

        local _mode "post"
        if "`create'" != "" local _mode "create"
        if `"`savefile'"' != "" local _mode "save"
        if "`create'" != "" & `"`savefile'"' != "" {
            noisily display as error "_datamap_post_metadata_rows: create and savefile() are exclusive"
            exit 198
        }
        if inlist("`_mode'", "create", "save") & "`frame'" == "" {
            noisily display as error "_datamap_post_metadata_rows: `_mode' requires frame()"
            exit 198
        }
        if "`_mode'" == "post" & "`frame'" == "" {
            noisily display as error "_datamap_post_metadata_rows: post requires frame()"
            exit 198
        }
        if "`plain'" != "" & "`_mode'" == "save" {
            noisily display as error "_datamap_post_metadata_rows: plain is for create and post"
            exit 198
        }
        if "`_mode'" == "post" & ((`"`classifications'"' == "") == (`"`classtext'"' == "") | ///
            `"`sourcecommand'"' == "" | `nvars' < 0) {
            noisily display as error "_datamap_post_metadata_rows: one of classifications() or classtext(), and sourcecommand() and nvars(), are required"
            exit 198
        }

        if "`_mode'" == "create" & "`plain'" != "" {
            frame create `frame' `_schema'
        }
        else if "`_mode'" == "create" {
            frame create `frame' long ds_index long position `_fschema' `_fsave' `_fextra'
        }
        else if "`_mode'" == "save" {
            // a copy: the collector frame keeps its keys for any later reader
            frame copy `frame' `_svf'
            local _save_open = 1
            frame `_svf' {
                quietly drop ds_index
                // I2 (2026-11-10): the new facts carry the document's mask,
                // so no count in 1..mincell()-1 the document withholds is
                // written: a withheld count is .s (numeric text and padded
                // values; the N= term withheld withholds both).  The 1.10.6
                // columns keep their exact counts (missing, unique).
                capture confirm variable numeric_n, exact
                if _rc == 0 {
                    quietly replace numeric_n = .s if numeric_n > 0 & numeric_n < . & ///
                        ((n_state != 0 & n_state < .) | (numeric_state != 0 & numeric_state < .))
                    quietly replace padded_n = .s if padded_n > 0 & padded_n < . & ///
                        ((n_state != 0 & n_state < .) | (padded_state != 0 & padded_state < .))
                    // the document's share: 100 * numeric_n / N (every row),
                    // half up to 0.1 in integer arithmetic (_dmv_pctc)
                    quietly generate double numeric_pct = ///
                        floor((2000 * numeric_n + N) / (2 * N)) / 10 if numeric_n < . & N > 0
                    quietly replace numeric_pct = .s if numeric_n == .s
                }
                // safe (datamap, 2.0.0 U2): the Missing count the document
                // withholds -- below mincell(), or the complement of a
                // nonmissing count below it -- is .s here too, with its share
                if "`safe'" != "" {
                    capture confirm variable missing_state, exact
                    if _rc == 0 {
                        quietly replace missing = .s if (missing_state != 0 & missing_state < .) | ///
                            (n_state != 0 & n_state < .)
                        quietly replace missing_pct = .s if missing == .s
                    }
                }
                // the frame's own columns, when the frame has them
                foreach _x of local _fextranames {
                    capture confirm variable `_x', exact
                    if _rc == 0 quietly drop `_x'
                }
                // the saving() types: cells were cut to 2045 bytes on entry,
                // except notes and characteristics, kept whole in the frame
                // for the document (2026-11-10) and cut here, as before
                // missing_codes and candidates (2.0.0) stay strL, whole
                // (2026-11-10): a str2045 cut lost the end of a long
                // per-code breakdown with no mark while the document
                // printed it whole
                local _lc2 "`_longcols'"
                mata: _datamap_cut_cols(tokens("`_lc2'"), 2045)
                quietly recast str2045 `_lc2'
                // the I2 columns after missing_codes, in _i2cols order; the
                // short text columns at their widest possible value
                local _i2have ""
                foreach _x of local _i2cols {
                    capture confirm variable `_x', exact
                    if _rc == 0 local _i2have "`_i2have' `_x'"
                }
                if "`_i2have'" != "" order `_i2have', last
                capture confirm variable date_family, exact
                if _rc == 0 quietly recast str32 date_family
                capture confirm variable date_mask, exact
                if _rc == 0 quietly recast str20 date_mask
                if "`csv'" != "" {
                    // every string quoted (a cell may hold a comma, a quote
                    // or a line break); numbers unformatted
                    quietly export delimited using `"`savefile'"', quote `replace'
                }
                else if "`replace'" != "" quietly save `"`savefile'"', replace
                else quietly save `"`savefile'"'
            }
            frame drop `_svf'
            local _save_open = 0
        }
        else {
        mata: st_local("source", _datamap_ucut(st_local("source"), 2045))
        mata: st_local("output", _datamap_ucut(st_local("output"), 2045))
        // the data label is read here, not passed on the command line: a
        // label with a backtick or quote cannot be carried through syntax
        local dslabel : data label
        mata: st_local("dslabel", _datamap_ucut(st_local("dslabel"), 2045))

        // classtext(): the classifier's text copy, read without a frame
        // (datamap).  Each number is re-evaluated from the text the
        // classifier posted, so the locals equal the ones read back from
        // the classifications() file below.
        if `"`classtext'"' != "" {
        local classvars ""
        mata: _datamap_cls_read(st_local("classtext"))
        if `_ct_bad' {
            noisily display as error "_datamap_post_metadata_rows: classtext() file is malformed"
            exit 198
        }
        forvalues i = 1/`_ct_C' {
            local m_mn`i' = `_ct_mn`i''
            local m_mp`i' = `_ct_mp`i''
            local m_uv`i' = `_ct_uv`i''
            local m_uc`i' = `_ct_uc`i''
            local m_pos`i' = `_ct_pos`i''
            local m_ml`i' = `_ct_ml`i''
        }
        }
        else {
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
            local m_pos`i' = orig_position[`i']
            local m_ml`i' = max_length[`i']
            local m_qf`i' = quality_flag[`i']
        }
        }
        frame drop `_cfr'
        local _frame_open = 0
        }

        if `"`varlist'"' == "" local varlist "`classvars'"
        local obs = c(N)
        // Mata stores the row (_datamap_vrow_store), so no cell is ever an
        // expression.  The column lists follow the schema above; plain
        // stores the 27 saving() columns only.
        local _numcols ds_index position N nvars missing missing_pct unique ///
            mean sd p50 p25 p75 min max unique_capped
        local _numlocs dsindex vpos obs nvars nmiss pctmiss nuniq ///
            mean sd p50 p25 p75 vmin vmax ncapped
        local _plainout ds_index position
        local _plainloc dsindex vpos
        local _txtcols source_command source output dataset dataset_label ///
            variable storage_type display_format value_label class ///
            variable_label notes characteristics datasignature
        local _txtlocs sourcecommand source output dsname dslabel vname ///
            vtype vfmt vallabname varclass post_vlab post_notes post_chars post_dsig
        // the frame's own columns (see create above)
        if "`plain'" == "" {
            local _numcols `_numcols' maxlen span
            local _numlocs `_numlocs' vmaxlen vspan
            local _txtcols `_txtcols' quality_flag date_family
            local _txtlocs `_txtlocs' vqflag vdfam
        }
        else {
            local _numcols : list _numcols - _plainout
            local _numlocs : list _numlocs - _plainloc
        }

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
            local vpos = .
            local vmaxlen = .
            local vspan = .
            local vqflag ""
            local vdfam ""
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
                local vpos = `m_pos`ix''
                local vmaxlen = `m_ml`ix''
                local vqflag "`m_qf`ix''"
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
            // the date family of a date display format (U4), for the
            // frame; r(datefmt) is the same date-format test
            if r(datefmt) & "`frame'" != "" {
                _datamap_datefamily, format("`vfmt'")
                local vdfam "`r(family)'"
            }
            // reportonly: only the summaries the document prints (continuous);
            // the rest are computed for saving() alone
            local _rponly = ("`reportonly'" != "" & "`varclass'" != "continuous")
            if `is_numeric' & "`varclass'" != "excluded" & !`_nosum' & !`_dhide' & !`_rponly' {
                // nopctiles (dataprobe compare() and diff() without saving()
                // or snapshot()): no sort for the quartiles, which those
                // never read; p50, p25 and p75 stay missing
                if "`nopctiles'" != "" quietly summarize `vname'
                else quietly summarize `vname', detail
                if r(N) > 0 {
                    if !`_mhide' local mean = regexr(string(r(mean), "%21x"), "^[+]", "")
                    if !`_mhide' local sd = regexr(string(r(sd), "%21x"), "^[+]", "")
                    if "`nopctiles'" == "" {
                        local p50 = regexr(string(r(p50), "%21x"), "^[+]", "")
                        local p25 = regexr(string(r(p25), "%21x"), "^[+]", "")
                        local p75 = regexr(string(r(p75), "%21x"), "^[+]", "")
                    }
                    local vmin = regexr(string(r(min), "%21x"), "^[+]", "")
                    local vmax = regexr(string(r(max), "%21x"), "^[+]", "")
                    if "`varclass'" == "date" local vspan = r(max) - r(min)
                }
            }
            // a date-class variable's span, also under datesafe (min and
            // max withheld) and reportonly: frame only, never saved; under
            // reportonly, also its min and max (what the document prints),
            // without the sort -summarize, detail- costs
            if "`frame'" != "" & `is_numeric' & "`varclass'" == "date" & missing(`vspan') {
                quietly summarize `vname', meanonly
                if r(N) > 0 {
                    local vspan = r(max) - r(min)
                    if `_rponly' & !`_dhide' {
                        local vmin = regexr(string(r(min), "%21x"), "^[+]", "")
                        local vmax = regexr(string(r(max), "%21x"), "^[+]", "")
                    }
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
            mata: st_local("post_dsig", _datamap_ucut(st_local("datasignature"), 2045))
            if "`plain'" == "" {
                // notes and characteristics whole (2026-11-10): the document
                // printed them cut at 2045 bytes with no mark; save cuts them
                mata: st_local("post_notes", st_local("notes"))
                mata: st_local("post_chars", st_local("chars"))
                frame `frame': mata: _datamap_vrow_store(tokens("`_numcols'"), ///
                    tokens("`_numlocs'"), tokens("`_txtcols'"), tokens("`_txtlocs'"), ///
                    ("notes", "characteristics"))
            }
            else {
                // the 27 saving() columns; every text cell cut to 2045 bytes
                mata: st_local("post_notes", st_local("notes"))
                mata: st_local("post_chars", st_local("chars"))
                frame `frame': mata: _datamap_vrow_store(tokens("`_numcols'"), ///
                    tokens("`_numlocs'"), tokens("`_txtcols'"), tokens("`_txtlocs'"))
            }
        }
        }
    }
    local rc = _rc
    if `_frame_open' capture frame drop `_cfr'
    if `_save_open' capture frame drop `_svf'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

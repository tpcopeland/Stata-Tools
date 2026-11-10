*! _datamap_collect_dataset Version 2.0.0  2026/11/10
*! The datasets frame of the datamap collector: one row per input dataset
*! Author: Timothy P Copeland, Karolinska Institutet

// Two modes:
//
//   create  _datamap_collect_dataset, create frame(f)
//   post    _datamap_collect_dataset, frame(f) sourcecommand() source() dsname()
//               [output() signature(soft|strict) changed(#)]
//           one row from the dataset in the current frame; r(ds_index) is the
//           new row's number, the key the variables and levels frames carry.
//
// Columns of frame f:
//   ds_index        row number, 1, 2, ... in the order datasets are documented
//   source_command  datamap (datadict, removed in 2.0.0, wrote datadict)
//   dataset         the dataset's name as the saving() table writes it
//   source          the file path, or "memory"
//   output          the file the dataset is documented in
//   filename        c(filename) when the row was collected
//   label           the data label
//   N, nvars        observations and variables in the dataset
//   sortlist        the sort order (-: sortedby-)
//   datasignature   -datasignature- (signature(soft): "" when it fails;
//                   strict: its error stops the run; neither: not computed)
//   changed         c(changed), or changed(#) when the caller read it before
//                   its own work touched the data
// and, filled after the dataset's variables and levels rows are posted
// (update mode, and _datamap_md_sections):
//   nvars_doc       variables documented (a varlist can choose fewer)
//   vfirst, vlast   the dataset's rows in the variables frame (0 0: none)
//   lfirst, llast   the dataset's rows in the levels frame (0 0: none)
//   suggested       likely identifiers not in exclude() (names)
//   excluded_all    every excluded variable of the dataset (names), also
//                   outside a varlist; the state header withholds a declared
//                   setting's values that name one (update mode)
//   structure, missingness, samples
//                   Markdown fragments that need the data (detected
//                   structure, missingness summary, sample rows), written by
//                   _datamap_md_sections during collection; "" when not asked
//
// and the declared state (F2, 2026-11-10), read from the dataset's _dta[]
// characteristics when the row is posted, verbatim ("" when not set):
//   ts_panel ts_time ts_delta   xtset/tsset: _dta[_TSpanel], _dta[_TStvar],
//                   and _dta[_TSdelta] read as a number (%20.0g; it is
//                   stored as %21x).  Not in the manuals: these are the names
//                   Stata's own tsset.ado writes and reads.
//   ts_fmt          the time variable's date family (_datamap_datefamily:
//                   "%ty yearly"), else its display format
//   st_id st_t0 st_time st_fail st_failval st_origin st_enter st_exit
//   st_scale st_if st_weight
//                   stset, when _dta[_dta] is "st" ([ST] st_is, "Definitions
//                   of characteristics"): st_id, st_bt0, st_bt, st_bd, st_ev,
//                   st_orig, st_enter, st_exit, st_bs, st_ifexp/st_if
//                   (joined by " & "), st_w
//   svy_settings    svyset: r(settings) of -svyset- (of -mi svyset- on mi
//                   data), a query that changes nothing, run only when
//                   _dta[_svy_version] is set ([SVY] svyset, Stored results)
//   mi_style mi_m mi_ivars mi_pvars
//                   mi set, when _dta[_mi_marker] is "_mi_ds_1" ([MI]
//                   technical, "Definition of styles"): _mi_style, _mi_M,
//                   _mi_ivars, _mi_pvars
//   dta_notes       the dataset's notes (_dta[note1] ... _dta[note<note0>]),
//                   joined by char(10)
//
// and, for the linkage block of two or more datasets (F1, 2026-11-10;
// _datamap_collect_link, labels; "" otherwise):
//   vl_names        the dataset's value labels (names), except one carried
//                   only by excluded variables
//   vl_defs         their definitions, joined by char(29) in vl_names' order
//
//   update  _datamap_collect_dataset, update frame(f) dsindex(#)
//               [nvarsdoc(#) vfirst(#) vlast(#) lfirst(#) llast(#)
//               suggested(names) excluded(names)]
//
// Reading a row back: Mata in an autoloaded .ado is private to that file, so
// each consumer file carries its own reader (datamap.ado: _datamap_ds_read),
// run as frame f: mata: reader(#, "stub").
capture mata: mata drop _datamap_ds_post()
capture mata: mata drop _datamap_ds_statecols()
capture mata: mata drop _datamap_ds_state()
mata:
// Runs with the datasets frame current; every text field comes from a local,
// so a label holding quotes, backticks or dollar signs is stored verbatim.
real scalar _datamap_ds_post()
{
	real scalar r, k
	string rowvector sc
	st_addobs(1)
	r = st_nobs()
	st_store(r, ("ds_index", "N", "nvars", "changed"),
		(r, strtoreal(st_local("_dsN")), strtoreal(st_local("_dsk")),
		strtoreal(st_local("_dschg"))))
	st_sstore(r, ("source_command", "dataset", "source", "output",
		"filename", "label", "sortlist", "datasignature"),
		(st_local("sourcecommand"), st_local("dsname"), st_local("source"),
		st_local("output"), st_local("_dsfile"), st_local("_dslab"),
		st_local("_dssort"), st_local("_dssig")))
	sc = _datamap_ds_statecols()
	for (k = 1; k <= cols(sc); k++) st_sstore(r, sc[k], st_local("_dsst_" + sc[k]))
	return(r)
}
// the declared-state columns (see the header), in the order they are created
string rowvector _datamap_ds_statecols()
{
	return(("ts_panel", "ts_time", "ts_delta", "ts_fmt", "st_id", "st_t0",
		"st_time", "st_fail", "st_failval", "st_origin", "st_enter", "st_exit",
		"st_scale", "st_if", "st_weight", "svy_settings", "mi_style", "mi_m",
		"mi_ivars", "mi_pvars", "dta_notes"))
}
// The declared state of the data in the current frame into the caller's
// locals _dsst_<column>, read with st_global(): a characteristic is data, and
// a note holding a backtick or $ is never read as macro syntax.
void _datamap_ds_state()
{
	string scalar d, t
	real scalar k, n
	string rowvector c
	c = _datamap_ds_statecols()
	for (k = 1; k <= cols(c); k++) st_local("_dsst_" + c[k], "")
	st_local("_dsst_ts_panel", st_global("_dta[_TSpanel]"))
	t = st_global("_dta[_TStvar]")
	st_local("_dsst_ts_time", t)
	if (t != "") {
		d = st_global("_dta[_TSdelta]")
		st_local("_dsst_ts_delta_raw", d)
		if (_st_varindex(t) < .) st_local("_dsst_ts_fmt", st_varformat(t))
	}
	if (st_global("_dta[_dta]") == "st") {
		st_local("_dsst_st_id", st_global("_dta[st_id]"))
		st_local("_dsst_st_t0", st_global("_dta[st_bt0]"))
		st_local("_dsst_st_time", st_global("_dta[st_bt]"))
		st_local("_dsst_st_fail", st_global("_dta[st_bd]"))
		st_local("_dsst_st_failval", st_global("_dta[st_ev]"))
		st_local("_dsst_st_origin", st_global("_dta[st_orig]"))
		st_local("_dsst_st_enter", st_global("_dta[st_enter]"))
		st_local("_dsst_st_exit", st_global("_dta[st_exit]"))
		st_local("_dsst_st_scale", st_global("_dta[st_bs]"))
		d = st_global("_dta[st_ifexp]")
		t = st_global("_dta[st_if]")
		if (d != "" & t != "") d = "(" + d + ") & (" + t + ")"
		else if (t != "") d = t
		st_local("_dsst_st_if", d)
		st_local("_dsst_st_weight", st_global("_dta[st_w]"))
	}
	st_local("_dsst_mi", "0")
	if (st_global("_dta[_mi_marker]") == "_mi_ds_1") {
		st_local("_dsst_mi", "1")
		st_local("_dsst_mi_style", st_global("_dta[_mi_style]"))
		st_local("_dsst_mi_m", st_global("_dta[_mi_M]"))
		st_local("_dsst_mi_ivars", st_global("_dta[_mi_ivars]"))
		st_local("_dsst_mi_pvars", st_global("_dta[_mi_pvars]"))
	}
	st_local("_dsst_svy", strofreal(st_global("_dta[_svy_version]") != ""))
	n = strtoreal(st_global("_dta[note0]"))
	d = ""
	if (!missing(n)) {
		for (k = 1; k <= n; k++) {
			t = st_global("_dta[note" + strofreal(k) + "]")
			if (t != "") d = d + (d == "" ? "" : char(10)) + t
		}
	}
	st_local("_dsst_dta_notes", d)
}
end

program define _datamap_collect_dataset, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax, FRame(name) [CREATE UPDATE SOURCECommand(string) SOURCE(string) ///
            DSName(string) OUtput(string) SIGnature(string) CHANGED(integer -1) ///
            DSINDEX(integer 0) NVARSDOC(integer -1) VFIRST(integer -1) ///
            VLAST(integer -1) LFIRST(integer -1) LLAST(integer -1) ///
            SUGGested(string) EXCLuded(string)]

        if "`create'" != "" {
            frame create `frame' long ds_index str16 source_command ///
                strL dataset strL source strL output strL filename ///
                strL label double N long nvars strL sortlist ///
                strL datasignature byte changed ///
                long nvars_doc long vfirst long vlast long lfirst long llast ///
                strL suggested strL structure strL missingness strL samples ///
                strL excluded_all ///
                strL ts_panel strL ts_time strL ts_delta strL ts_fmt ///
                strL st_id strL st_t0 strL st_time strL st_fail strL st_failval ///
                strL st_origin strL st_enter strL st_exit strL st_scale ///
                strL st_if strL st_weight strL svy_settings strL mi_style ///
                strL mi_m strL mi_ivars strL mi_pvars strL dta_notes ///
                strL vl_names strL vl_defs
        }
        else if "`update'" != "" {
            frame `frame' {
                if `dsindex' < 1 | `dsindex' > _N {
                    noisily display as error "_datamap_collect_dataset: dsindex() is not a row of the datasets frame"
                    exit 198
                }
                foreach _c in nvarsdoc vfirst vlast lfirst llast {
                    local _col = cond("`_c'" == "nvarsdoc", "nvars_doc", "`_c'")
                    if ``_c'' >= 0 quietly replace `_col' = ``_c'' in `dsindex'
                }
                // Mata, not -replace-: a long list as a string expression
                // can pass the expression limit (rc 130)
                mata: st_sstore(`dsindex', "suggested", strtrim(st_local("suggested")))
                mata: st_sstore(`dsindex', "excluded_all", strtrim(st_local("excluded")))
            }
        }
        else {
            if !inlist("`signature'", "", "soft", "strict") {
                noisily display as error "_datamap_collect_dataset: signature() must be soft or strict"
                exit 198
            }
            local _dssig ""
            if "`signature'" == "strict" {
                quietly datasignature
                local _dssig `"`r(datasignature)'"'
            }
            else if "`signature'" == "soft" {
                capture quietly datasignature
                if _rc == 0 local _dssig `"`r(datasignature)'"'
            }
            local _dslab : data label
            local _dssort : sortedby
            local _dsfile `"`c(filename)'"'
            local _dschg = c(changed)
            if `changed' >= 0 local _dschg = `changed'
            local _dsN = c(N)
            local _dsk = c(k)
            // the declared state (F2): characteristics, read in Mata
            mata: _datamap_ds_state()
            if `"`_dsst_ts_delta_raw'"' != "" {
                // stored as %21x (+1.0000000000000X+000): read as a number
                capture local _dsst_ts_delta = strtrim(string(`_dsst_ts_delta_raw', "%20.0g"))
                if _rc local _dsst_ts_delta ""
            }
            if `"`_dsst_ts_fmt'"' != "" {
                _datamap_datefamily, format(`"`_dsst_ts_fmt'"')
                if `"`r(family)'"' != "" local _dsst_ts_fmt `"`r(family)'"'
            }
            // svyset: its own query, which reads the settings and changes
            // nothing (on mi data -svyset- refuses, rc 119: -mi svyset-)
            if `_dsst_svy' {
                if `_dsst_mi' capture quietly mi svyset
                else capture quietly svyset
                if _rc == 0 mata: st_local("_dsst_svy_settings", st_global("r(settings)"))
                else local _dsst_svy_settings "(settings could not be read)"
            }
            local _dsx = 0
            frame `frame': mata: st_local("_dsx", strofreal(_datamap_ds_post()))
            return scalar ds_index = `_dsx'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

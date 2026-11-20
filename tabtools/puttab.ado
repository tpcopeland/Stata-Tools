*! puttab Version 1.2.0  2026/11/19
*! Style an in-memory table (current data, a frame, or a matrix) as one Excel sheet
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    puttab is the first-mile styled-block producer for the tabtools suite. It
    takes a table that already lives in memory -- the current dataset, a named
    frame, or a Stata matrix (e(b), r(table), a collapse/tabulate result) -- and
    writes it as one house-styled Excel sheet with the shared tabtools geometry:
    a left-justified title in cell A1, a thin spacer column A so the table body
    is anchored at B2, a header rule, optional header shading and zebra striping,
    column widths, borders, and an italic footnote.

    It complements the rest of the suite at the raw-input end: desctab needs a
    collect: table, stacktab needs blocks already exported as sheets. puttab
    styles a raw frame/matrix/dataset, so the natural pipeline is

        emit styled blocks with puttab  ->  assemble them with stacktab

SOURCE (exactly one):
    varlist        columns of the current dataset (explicit; required for the
                   current-data source)
    frame(name)    a named frame (optionally subset by varlist)
    matrix(name)   a Stata matrix (row/column names become labels/headers)
*/

program define puttab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    local _book_open = 0
    local _xlsx_written = 0
    local _return_ready = 0
    tempname _xlsx_book
    local _ret_rows .
    local _ret_cols .
    local _ret_data .
    local _ret_sheet ""
    local _ret_file ""
    local _ret_source ""
    local _ret_csv ""
    local _ret_markdown ""
    local _ret_markdown_rows .
    local _ret_markdown_cols .
    local _ret_latex ""
    local _ret_latex_rows .
    local _ret_latex_cols .
    local _ret_sc 0
    local _ret_sc_k 0
    local _ret_sc_np 0
    local _ret_sc_nc 0
    local _sink ""
    capture noisily {

        * Parse first, before anything that can post r(): matrix(r(table))
        * must be copied while r(table) still exists. When frame() names the
        * source, parse inside that frame so if/in address the source rows;
        * parsing in the current frame range-checked "in" against, and
        * resolved "if" variables in, the wrong dataset.
        * copy local and macval(): the command line is re-parsed as typed,
        * so title() or footnote() text is never macro-expanded here.
        local _pt_cmdline : copy local 0
        local _pt_srcframe ""
        _parse comma _pt_lhs _pt_rhs : 0
        local 0 `"`macval(_pt_rhs)'"'
        capture syntax [, FRAme(string) *]
        if _rc == 0 {
            local _pt_srcframe = strtrim(subinstr(`"`frame'"', char(34), "", .))
        }
        local frame ""
        local options ""
        local 0 : copy local _pt_cmdline
        if `"`_pt_srcframe'"' != "" {
            confirm name `_pt_srcframe'
            capture confirm frame `_pt_srcframe'
            if _rc {
                noisily display as error "frame `_pt_srcframe' not found"
                exit 111
            }
            * The two syntax statements are identical; only the frame differs.
            frame `_pt_srcframe': syntax [anything(name=vlist)] [if] [in] [using/] , ///
                [ FRAme(string) Matrix(string) ///
                  SHeet(string) ///
                  TItle(string) FOOTnote(string) ///
                  FONT(string) FONTSIZE(string) BORDERstyle(string) ///
                  HEADERColor(string) ZEBRAColor(string) ZEBra NOHEADERShade HEADERShade ///
                  DIGits(string) NFormat(string) VARLabels NOHeader NOEMBedheader ///
                  HLines(numlist >0 integer sort) VLines(numlist >0 integer sort) ///
                  BOLDrows(numlist >0 integer sort) ///
                  CSV(string) MARKdown(string) MDAPPend LATEX(string) TEXAPPend texdocument texopts(string asis) open ///
                  PANel(string) PANELHeader(string asis) PANELInline NOINDent SPANheader(string asis) ///
                  BLOCKheader ///
                  SMALLCells(string asis) NOSMALLCells COUNTs(string) WITHhold(string) ///
                  FRACtion(string) ROWTotal(string) TOTALrow(string asis) ]
        }
        else {
            syntax [anything(name=vlist)] [if] [in] [using/] , ///
                [ FRAme(string) Matrix(string) ///
                  SHeet(string) ///
                  TItle(string) FOOTnote(string) ///
                  FONT(string) FONTSIZE(string) BORDERstyle(string) ///
                  HEADERColor(string) ZEBRAColor(string) ZEBra NOHEADERShade HEADERShade ///
                  DIGits(string) NFormat(string) VARLabels NOHeader NOEMBedheader ///
                  HLines(numlist >0 integer sort) VLines(numlist >0 integer sort) ///
                  BOLDrows(numlist >0 integer sort) ///
                  CSV(string) MARKdown(string) MDAPPend LATEX(string) TEXAPPend texdocument texopts(string asis) open ///
                  PANel(string) PANELHeader(string asis) PANELInline NOINDent SPANheader(string asis) ///
                  BLOCKheader ///
                  SMALLCells(string asis) NOSMALLCells COUNTs(string) WITHhold(string) ///
                  FRACtion(string) ROWTotal(string) TOTALrow(string asis) ]
        }

        * digits() is read as text so that an option not given
        * (-1 below) cannot collide with a typed value: with -1 defaults, a
        * typed -1 was taken as no option at rc 0. Every typed value is
        * range-checked below.
        foreach _nopt in digits {
            local _nval = strtrim(`"``_nopt''"')
            if `"`_nval'"' == "" {
                local `_nopt' -1
                continue
            }
            capture confirm number `_nval'
            if _rc {
                noisily display as error "option `_nopt'() incorrectly specified"
                exit 198
            }
            if `_nval' == -1 {
                local _nmsg "between 0 and 6"
                noisily display as error "`_nopt'() must be `_nmsg'"
                exit 198
            }
            * an integer typed with a decimal point (2.0, 1e0) is accepted, as
            * the integer syntax type did
            if `_nval' != int(`_nval') {
                noisily display as error "`_nopt'() must be an integer"
                exit 198
            }
            local `_nopt' = `_nval'
        }

        * matrix(): a matrix name, r(name), or e(name); copy it now.
        local _matrix_label ""
        if `"`matrix'"' != "" {
            local matrix = strtrim(`"`matrix'"')
            if !regexm(`"`matrix'"', "^([A-Za-z_][A-Za-z0-9_]*|[re][(][A-Za-z_][A-Za-z0-9_]*[)])$") {
                noisily display as error "matrix() must name a matrix, r(name), or e(name)"
                exit 198
            }
            local _matrix_label `"`matrix'"'
            * "matrix M = r(nosuch)" succeeds with a 1x1 missing, so an
            * r()/e() source must be listed among the posted matrices.
            local _mat_ok = 1
            if regexm(`"`matrix'"', "^([re])[(]([A-Za-z_][A-Za-z0-9_]*)[)]$") {
                local _mat_class = regexs(1)
                local _mat_inner = regexs(2)
                local _mat_posted : `_mat_class'(matrices)
                local _mat_ok : list _mat_inner in _mat_posted
            }
            else {
                capture confirm matrix `matrix'
                if _rc local _mat_ok = 0
            }
            tempname _srcmat
            if `_mat_ok' capture matrix `_srcmat' = `matrix'
            if !`_mat_ok' | _rc {
                noisily display as error "matrix `matrix' not found"
                exit 111
            }
            local matrix `"`_srcmat'"'
        }

        capture putexcel close

        * Auto-load shared helper programs
        capture _tabtools_helpers_ready
        if !_rc capture mata: assert(findexternal("_tt_sep_parse()") != NULL)
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
                capture _tabtools_helpers_ready
                if _rc {
                    display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                    exit 111
                }
            }
            else {
                display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }
        _tabtools_require_helpers

        * ----- session destinations (tabtools set workbook/markdown/
        * headershade): an explicit option wins; a session target is echoed.
        _tabtools_set_sinks resolve, xlsx(`"`using'"') markdown(`"`markdown'"') `mdappend' ///
            latex(`"`latex'"') `texappend'
        local using `"`_ss_xlsx'"'
        local markdown `"`_ss_md'"'
        local mdappend "`_ss_mdappend'"
        local _sess_xlsx = `_ss_xlsx_sess'
        local _sess_md = `_ss_md_sess'
        local latex `"`_ss_tex'"'
        local texappend "`_ss_texappend'"
        local _sess_tex = `_ss_tex_sess'
        * noheadershade: no shading for this call, whatever the session says.
        * NOHEADERShade is declared before HEADERShade on purpose: declared
        * after it, syntax swallows "noheadershade" as the negation of
        * HEADERShade and leaves both locals empty.
        if "`headershade'" != "" & "`noheadershade'" != "" {
            noisily display as error "headershade and noheadershade may not be combined"
            exit 198
        }
        if "`headershade'" == "" & "`noheadershade'" == "" & ///
            "$TABTOOLS_set_headershade" == "on" {
            local headershade "headershade"
            display as text "(tabtools: using session headershade)"
        }

        * ----- output file validation -----
        local _has_using = `"`using'"' != ""
        local _has_markdown = `"`markdown'"' != ""
        local _has_latex = `"`latex'"' != ""
        * before the "specify a sink" refusal, so a lone mdappend or texappend (outtab
        * passes it through to resolve the session file) names its own error
        if "`mdappend'" != "" & !`_has_markdown' {
            noisily display as error "mdappend requires markdown()"
            exit 198
        }
        if "`texappend'" != "" & !`_has_latex' {
            noisily display as error "texappend requires latex()"
            exit 198
        }
        if "`texdocument'" != "" & !`_has_latex' {
            noisily display as error "texdocument requires latex()"
            exit 198
        }
        if `"`macval(texopts)'"' != "" & !`_has_latex' {
            noisily display as error "texopts() requires latex()"
            exit 198
        }
        * csv() is a sink of its own, as it is for regtab and outtab
        if !`_has_using' & !`_has_markdown' & !`_has_latex' & `"`csv'"' == "" {
            noisily display as error "specify using, csv(), markdown(), or latex()"
            exit 198
        }
        if "`open'" != "" & !`_has_using' {
            noisily display as error "open requires using"
            exit 198
        }
        if `_has_using' {
            if !strmatch(lower(`"`using'"'), "*.xlsx") {
                noisily display as error "using file must have a .xlsx extension"
                exit 198
            }
            _tabtools_validate_path `"`using'"' "using"
        }
        * F10 (codex audit 2026-09-27): compound quotes, so a sheet name that
        * contains a double quote (valid in Excel) is not re-parsed.
        if `"`macval(sheet)'"' == "" local sheet "Table"
        if `_has_using' _tabtools_validate_sheet `"`macval(sheet)'"' "sheet()"

        local csv = strtrim(`"`csv'"')
        if `"`csv'"' != "" {
            if !strmatch(lower(`"`csv'"'), "*.csv") {
                noisily display as error "csv() must have a .csv extension"
                exit 198
            }
            _tabtools_validate_path `"`csv'"' "csv()"
        }
        if `_has_latex' {
            if !strmatch(lower(`"`latex'"'), "*.tex") {
                noisily display as error "latex() must specify a .tex file"
                exit 198
            }
            _tabtools_validate_path `"`latex'"' "latex()"
        }
        if `_has_markdown' {
            _tabtools_validate_path `"`markdown'"' "markdown()"
            local _md_lower = lower(`"`markdown'"')
            if !(strmatch(`"`_md_lower'"', "*.md") | ///
                 strmatch(`"`_md_lower'"', "*.markdown") | ///
                 strmatch(`"`_md_lower'"', "*.qmd") | ///
                 strmatch(`"`_md_lower'"', "*.rmd")) {
                noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
                exit 198
            }
        }
        _tabtools_check_sinks, xlsx(`"`using'"') csv(`"`csv'"') ///
            markdown(`"`markdown'"') latex(`"`latex'"') `texappend' `texdocument' texopts(`macval(texopts)') xlsxname("using")

        * ----- digits -----
        if `digits' == -1 {
            if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
            else local digits = 2
        }
        if `digits' < 0 | `digits' > 6 {
            noisily display as error "digits() must be between 0 and 6"
            exit 198
        }

        * ----- nformat(): display format for integer-valued columns -----
        * The width is rewritten to 32 because a narrow width overflows to
        * scientific notation (1234567890 under %6.0fc is 1.2e+09), and a
        * %9.0gc drops its commas; cells are trimmed after formatting, so
        * width never pads the output.
        local nformat = strtrim(`"`nformat'"')
        if `"`nformat'"' != "" {
            if !regexm(`"`nformat'"', "^%(-?)0?[0-9]*[.]([0-9]+)([fg]c?)$") {
                noisily display as error "nformat() must be a %f or %g numeric format such as %12.0fc"
                exit 198
            }
            local nformat "%`=regexs(1)'32.`=regexs(2)'`=regexs(3)'"
        }

        * ----- shared formatting / colors -----
        _tabtools_resolve_format, font(`"`font'"') fontsize(`fontsize') fsexplicit borderstyle(`borderstyle') ///
            headershade(`headershade') zebra(`zebra')
        _tabtools_resolve_colors, headercolor(`"`headercolor'"') ///
            zebracolor(`"`zebracolor'"')

        * ----- resolve source (validate BEFORE preserve) -----
        local _nsrc = 0
        if `"`matrix'"' != "" local ++_nsrc
        if `"`frame'"'  != "" local ++_nsrc
        if `_nsrc' > 1 {
            noisily display as error "matrix() and frame() may not be combined"
            exit 198
        }

        local _hasifin = (`"`if'"' != "" | `"`in'"' != "")

        local _src ""
        local _framename ""
        if `"`matrix'"' != "" {
            if `"`vlist'"' != "" {
                noisily display as error "a varlist is not allowed with matrix(); the matrix is the source"
                exit 198
            }
            if `_hasifin' {
                noisily display as error "if/in is not allowed with a matrix() source"
                exit 198
            }
            confirm matrix `matrix'
            if rowsof(`matrix') < 1 | colsof(`matrix') < 1 {
                noisily display as error "matrix(`_matrix_label') is empty"
                exit 198
            }
            local _src "matrix"
        }
        else if `"`frame'"' != "" {
            local _framename = strtrim(subinstr(`"`frame'"', char(34), "", .))
            confirm name `_framename'
            capture confirm frame `_framename'
            if _rc {
                noisily display as error "frame `_framename' not found"
                exit 111
            }
            local _src "frame"
        }
        else {
            if `"`vlist'"' == "" {
                noisily display as error "specify a varlist, frame(), or matrix() as the table source"
                exit 198
            }
            * Validate the requested varlist against the current data now,
            * before preserve, so a typo fails without a restore.
            unab _keepvars : `vlist'
            local _src "data"
        }

        * An empty smallcells() reads as absent to syntax; refuse it (r(198))
        * rather than fall through to no masking or the session default.
        if `"`smallcells'"' == "" {
            _tabtools_smallcells_opt __empty `macval(0)'
        }
        * ----- smallcells() disclosure control (counts() columns only) -----
        * puttab cannot tell which columns are person counts, so masking
        * applies only to the columns counts() names; the threshold comes
        * from smallcells(), nosmallcells, or the session default.
        local counts = strtrim(`"`counts'"')
        local _sc_on = (`"`counts'"' != "")
        local _sc_k ""
        local _sc_mode ""
        foreach _o in withhold fraction rowtotal totalrow {
            if strtrim(`"``_o''"') != "" & !`_sc_on' {
                noisily display as error "`_o'() requires counts()"
                exit 198
            }
        }
        if `_sc_on' {
            if "`_src'" == "matrix" {
                noisily display as error "counts() is not allowed with a matrix() source; it names variables"
                exit 198
            }
            _tabtools_smallcells_opt, smallcells(`smallcells') `nosmallcells'
            * counts() without a threshold would print every count raw at
            * rc 0; raw counts must be asked for with nosmallcells
            if "`_sc_k'" == "" & "`nosmallcells'" == "" {
                noisily display as error "counts() requires smallcells(#) or a session default (tabtools set smallcells #); specify nosmallcells to print the counts unmasked"
                exit 198
            }
            if "`_sc_k'" != "" & "`_sc_mode'" == "full" & ///
                strtrim(`"`rowtotal'"') == "" & strtrim(`"`totalrow'"') == "" {
                noisily display as text "(puttab: smallcells(`_sc_k'): no rowtotal() or totalrow() declared; a printed total that is not declared is not protected)"
            }
            local _ret_sc 1
            local _ret_sc_k = cond("`_sc_k'" == "", 0, 0`_sc_k')
        }
        else if strtrim(`"`smallcells'"') != "" {
            noisily display as error "smallcells() requires counts(): name the columns that hold counts of persons"
            exit 198
        }
        else if "`nosmallcells'" == "" & `"$TABTOOLS_set_smallcells"' != "" {
            noisily display as text "(puttab: session smallcells($TABTOOLS_set_smallcells) not applied: puttab masks only the columns named in counts())"
        }

        * ----- panel()/panelheader()/spanheader() (O2, O3) -----
        * blockheader: a spanning row of block (model) names over the header
        * row of statistic labels, read from char c#[tabtools_block] that
        * regtab puts on a flat frame's columns. The header row is the
        * variable labels, so blockheader implies varlabels.
        if "`blockheader'" != "" {
            if "`noheader'" != "" {
                noisily display as error "blockheader requires a header row; remove noheader"
                exit 198
            }
            if strtrim(`"`macval(spanheader)'"') != "" {
                noisily display as error "blockheader and spanheader() may not be combined: both write the spanning row"
                exit 198
            }
            if "`_src'" == "matrix" {
                noisily display as error "blockheader reads variable characteristics; it is not allowed with matrix()"
                exit 198
            }
            local varlabels "varlabels"
        }
        local panel = strtrim(`"`panel'"')
        local _has_panel = (`"`panel'"' != "")
        local _has_phdr = (strtrim(`"`panelheader'"') != "")
        if `_has_phdr' & !`_has_panel' {
            noisily display as error "panelheader() requires panel()"
            exit 198
        }
        if "`noindent'" != "" & !`_has_panel' {
            noisily display as error "noindent requires panel()"
            exit 198
        }
        * Read by _puttab_panelize: 1 = leave panel row labels unindented.
        local _pt_noindent = ("`noindent'" != "")
        * panelinline: the panel heading and that panel's header row share
        * one row (the heading takes the header's first cell, which must be
        * blank). Read by _puttab_panelize.
        if "`panelinline'" != "" & !`_has_phdr' {
            noisily display as error "panelinline requires panelheader(): the heading shares the panel header row"
            exit 198
        }
        local _pt_inline = ("`panelinline'" != "")
        local _pt_inl_err ""
        local _pt_ihrows ""
        * panelheader() is a varlist of string variables (per-panel text),
        * or, when it starts with a quote, literal text: one string per
        * exported column, repeated under every panel heading.
        local _ph_lit 0
        local _ph_n 0
        if `_has_phdr' {
            local _ph_first = substr(strtrim(`"`macval(panelheader)'"'), 1, 1)
            if `"`_ph_first'"' == char(34) | `"`_ph_first'"' == char(96) {
                local _ph_lit 1
                local _ph_n : word count `macval(panelheader)'
                forvalues _i = 1/`_ph_n' {
                    local _ph_t`_i' : word `_i' of `macval(panelheader)'
                }
            }
        }
        if `_has_panel' & "`_src'" == "matrix" {
            noisily display as error "panel() is not allowed with a matrix() source"
            exit 198
        }
        if `_has_panel' & `: word count `panel'' != 1 {
            noisily display as error "panel() takes one variable"
            exit 198
        }
        local _pt_pvars ""
        local _pt_phvars ""
        local _pt_hrows ""
        local _pt_phrows ""
        local _pt_npanels 0
        local _nspan 0

        * ===== build the in-memory string table (c1..cK) =====
        preserve
        local _restore_needed = 1

        local _titlerows = (`"`macval(title)'"' != "")
        local _headerrows = ("`noheader'" == "")
        local _uselbl = ("`varlabels'" != "")

        if "`_src'" == "matrix" {
            clear
            mata: _puttab_matrix_table("`matrix'", `digits', `_titlerows', `_headerrows', "`nformat'")
        }
        else {
            if "`_src'" == "frame" {
                tempfile _srcdata
                quietly frame `_framename': save `"`_srcdata'"', replace
                * quietly: -use- echoes the frame's dataset label, e.g.
                * "(1978 automobile data)", ahead of puttab's own lines.
                quietly use `"`_srcdata'"', clear
            }
            * panel(): the variable whose changes start a panel, and the
            * panelheader() text variables; neither is ever exported.
            if `_has_panel' {
                capture confirm variable `panel', exact
                if _rc {
                    noisily display as error "panel(): variable `panel' not found in the source"
                    exit 111
                }
                local _pt_pvars "`panel'"
                if `_has_phdr' & !`_ph_lit' {
                    capture unab _pt_phvars : `panelheader'
                    if _rc {
                        noisily display as error "panelheader(): `panelheader' not found in the source"
                        exit 111
                    }
                    foreach _v of local _pt_phvars {
                        capture confirm string variable `_v'
                        if _rc {
                            noisily display as error "panelheader(): `_v' is not a string variable"
                            exit 109
                        }
                    }
                    if `: list panel in _pt_phvars' {
                        noisily display as error "panelheader() may not include the panel() variable"
                        exit 198
                    }
                    local _pt_pvars "`_pt_pvars' `_pt_phvars'"
                }
            }
            * Key columns: a variable marked char <var>[tabtools_key] 1 (the
            * row keys regtab adds with frame(name, flat keys)) is for the
            * caller's own merges and rules, not the table. It is exported
            * only when the varlist names it literally; without a varlist,
            * or matched by a wildcard or range, it is left out of every
            * sink. Variables without the characteristic are unaffected.
            * A wildcard or range token never equals a variable name, so a
            * key is named literally exactly when it is one of the tokens.
            * With a varlist, only keys it selects are candidates: a key it
            * never matched is dropped by -keep- and is not named in the note.
            local _pt_keys ""
            local _pt_vtok : copy local vlist
            local _pt_vsel ""
            * an unresolvable varlist leaves no selected keys here; the -keep-
            * that applies the varlist reports the bad name
            if `"`vlist'"' != "" {
                capture unab _pt_vsel : `vlist'
                if _rc local _pt_vsel ""
            }
            quietly ds
            foreach _v in `r(varlist)' {
                mata: st_local("_kc", strtrim(st_global("`_v'[tabtools_key]")))
                if "`_kc'" == "1" {
                    local _lit : list _v in _pt_vtok
                    local _sel 1
                    if `"`vlist'"' != "" local _sel : list _v in _pt_vsel
                    if !`_lit' & `_sel' local _pt_keys "`_pt_keys' `_v'"
                }
            }
            local _pt_keys : list _pt_keys - _pt_pvars
            local _pt_keys = strtrim("`_pt_keys'")
            if "`_pt_keys'" != "" {
                noisily display as text "(puttab: key column(s) `_pt_keys' not exported; name them in the varlist to export them)"
            }
            * Row subset (if/in) is marked on the caller's observations as
            * they are numbered in the source, before anything is dropped, so
            * -in 1- means observation 1 of the data the user sees. The mark
            * precedes the column subset, so the if/in condition may reference
            * columns that the varlist drops. C4 (codex audit 2026-09-26): the
            * embedded-header row used to be dropped first, which shifted every
            * observation number -- -in 1- exported observation 2.
            if `_hasifin' {
                marksample _touse, novarlist
            }
            * A tabtools table producer (desctab/table1_tc ..., clear or
            * frame()) returns its table header-shaped: observation 1 repeats
            * each column's variable label.  When we are about to draw the
            * header from those same labels, that observation IS the header,
            * not data -- consume it here instead of emitting the text twice.
            * Detection is by content (see _puttab_is_headerrow), so a caller
            * who already dropped the row is unaffected.  It considers
            * observation 1 only when that observation is inside the if/in
            * selection, and is scoped to the columns that will actually be
            * exported. noembedheader turns the detection off: observation 1
            * is then data even when it matches the labels.
            if `_headerrows' & `_uselbl' & "`noembedheader'" == "" {
                local _hdrvars ""
                local _hdr_dup 0
                local _hdr_in_sel 1
                if `_hasifin' local _hdr_in_sel = (`_touse'[1] == 1)
                if `"`vlist'"' != "" {
                    capture unab _hdrvars : `vlist'
                    if _rc local _hdrvars ""
                }
                else {
                    quietly ds
                    local _hdrvars `r(varlist)'
                    if `_hasifin' local _hdrvars : list _hdrvars - _touse
                }
                local _hdrvars : list _hdrvars - _pt_pvars
                local _hdrvars : list _hdrvars - _pt_keys
                if `"`_hdrvars'"' != "" & `_hdr_in_sel' {
                    mata: st_local("_hdr_dup", ///
                        strofreal(_puttab_is_headerrow("`_hdrvars'")))
                    if `_hdr_dup' == 1 quietly drop in 1
                }
            }
            if `_hasifin' {
                quietly keep if `_touse'
                quietly drop `_touse'
            }
            * smallcells(): resolve the counts(), fraction(), withhold() and
            * rowtotal() names and mark the totalrow() rows now, while every
            * source variable is in memory (the expression may use a column
            * the varlist does not export).
            local _sc_trvar ""
            if `_sc_on' {
                _puttab_sc_parse, counts(`counts') fraction(`fraction') ///
                    withhold(`withhold') rowtotal(`rowtotal')
                if strtrim(`"`macval(totalrow)'"') != "" {
                    tempvar _sc_trvar
                    quietly gen byte `_sc_trvar' = 0
                    capture noisily quietly replace `_sc_trvar' = 1 if (`totalrow')
                    if _rc {
                        local _sc_rc = _rc
                        noisily display as error "totalrow() must be an expression true for the total rows"
                        exit `_sc_rc'
                    }
                }
            }
            if `"`vlist'"' != "" {
                unab _keepvars : `vlist'
                local _keepvars : list _keepvars - _pt_pvars
                local _keepvars : list _keepvars - _pt_keys
                if "`_keepvars'" == "" {
                    noisily display as error "source contains no variables to export"
                    exit 111
                }
                keep `_keepvars' `_pt_pvars' `_sc_trvar'
                order `_keepvars'
            }
            quietly ds
            local _srcvars `r(varlist)'
            local _srcvars : list _srcvars - _pt_pvars
            local _srcvars : list _srcvars - _pt_keys
            local _srcvars : list _srcvars - _sc_trvar
            if "`_srcvars'" == "" {
                noisily display as error "source contains no variables to export"
                exit 111
            }
            * smallcells(): masks from the _tabtools_smallcells engine, then
            * one rendered text column per count, fraction and withheld
            * column (_sc_ovr pairs "column textvar"); a fraction()
            * denominator is printed inside its fraction, not on its own.
            local _sc_ovr ""
            if `_sc_on' {
                quietly count
                if r(N) > 0 {
                    local _sc_pv ""
                    if `_has_panel' local _sc_pv "`panel'"
                    * names for the rendered text variables, owned here so
                    * they live until the table is built
                    local _sc_pool ""
                    foreach _v of local _srcvars {
                        tempvar _sc_t
                        local _sc_pool `_sc_pool' `_sc_t'
                    }
                    _puttab_sc_apply, srcvars(`_srcvars') k(`_sc_k') ///
                        mode(`_sc_mode') panelvar(`_sc_pv') ///
                        trvar(`_sc_trvar') digits(`digits') nformat(`nformat') ///
                        counts(`_sc_counts') fnum(`_sc_fnum') fden(`_sc_fden') ///
                        rttot(`_sc_rttot') rtadd(`_sc_rtadd') withhold(`_sc_w') ///
                        pool(`_sc_pool')
                    local _srcvars : list _srcvars - _sc_consumed
                    local _ret_sc_np = `_sc_np'
                    local _ret_sc_nc = `_sc_nc'
                }
            }
            * blockheader: spans from the exported columns' characteristics,
            * read now, while the source variables still exist
            if "`blockheader'" != "" {
                mata: _puttab_block_spans("`_srcvars'")
                if `_nspan' == 0 {
                    noisily display as text "(puttab: no exported column has char c#[tabtools_block]; blockheader adds no row)"
                }
            }
            quietly count
            if r(N) == 0 {
                noisily display as error "source contains no observations to export"
                exit 2000
            }
            local _pt_headvar ""
            local _pt_newvar ""
            if `_has_panel' {
                if `_ph_lit' {
                    if `_ph_n' != `: word count `_srcvars'' {
                        noisily display as error "panelheader() must give one string per exported column (`: word count `_srcvars'')"
                        exit 198
                    }
                    * Literal text: one tempvar per column, the same on
                    * every observation; created after _srcvars is fixed,
                    * so it is never exported as a column.
                    forvalues _i = 1/`_ph_n' {
                        tempvar _ph_v`_i'
                        quietly gen strL `_ph_v`_i'' = ""
                        mata: st_sstore(., "`_ph_v`_i''", J(st_nobs(), 1, st_local("_ph_t`_i'")))
                        local _pt_phvars "`_pt_phvars' `_ph_v`_i''"
                    }
                }
                if `_has_phdr' & `: word count `_pt_phvars'' != `: word count `_srcvars'' {
                    noisily display as error "panelheader() must name one string variable per exported column (`: word count `_srcvars'')"
                    exit 198
                }
                * Heading text: the value label, else the value as displayed;
                * a panel whose value is missing or blank has no heading.
                tempvar _pt_head _pt_new
                capture confirm string variable `panel'
                if !_rc quietly gen strL `_pt_head' = `panel'
                else {
                    quietly gen strL `_pt_head' = ""
                    mata: st_sstore(., "`_pt_head'", _puttab_fmt_num( ///
                        st_data(., "`panel'"), `digits', ///
                        st_varvaluelabel("`panel'"), st_varformat("`panel'"), ""))
                }
                quietly gen byte `_pt_new' = (_n == 1) | (`panel' != `panel'[_n - 1])
                local _pt_headvar "`_pt_head'"
                local _pt_newvar "`_pt_new'"
            }
            mata: _puttab_data_table("`_srcvars'", `digits', `_titlerows', ///
                `_headerrows', `_uselbl', "`_pt_headvar'", "`_pt_newvar'", ///
                "`_pt_phvars'", "`nformat'", "`_sc_ovr'")
            if `"`macval(_pt_inl_err)'"' != "" {
                noisily display as error `"panelinline: panel "`macval(_pt_inl_err)'" has text in the first cell of its panel header, where the heading goes; blank that cell or drop panelinline"'
                exit 198
            }
        }

        local K = c(k)
        if `K' < 1 {
            noisily display as error "no columns produced for export"
            exit 198
        }

        * Title text into the (blank) first row, first column
        if `_titlerows' {
            quietly replace c1 = `"`macval(title)'"' in 1
        }

        * spanheader("label" #/# [\ ...]) (O3): a row of spanning labels
        * above the header row; columns number the exported columns 1..K.
        if strtrim(`"`macval(spanheader)'"') != "" {
            if !`_headerrows' {
                noisily display as error "spanheader() requires a header row; remove noheader"
                exit 198
            }
            mata: _puttab_span_parse(st_local("spanheader"), `K')
            if `_sp_rc' {
                noisily display as error `"spanheader(): `macval(_sp_err)'"'
                exit `_sp_rc'
            }
        }
        * the span row, from spanheader() or blockheader; labels are data,
        * written from the locals by Mata, never re-expanded
        if `_nspan' > 0 {
            local _span_at = `_titlerows' + 1
            quietly insobs 1, before(`_span_at')
            forvalues _i = 1/`_nspan' {
                mata: _puttab_put(`_span_at', "c`_sp_c1`_i''", st_local("_sp_lab`_i'"))
            }
        }
        local _span_rows = (`_nspan' > 0)
        local _span_row = cond(`_span_rows', `_titlerows' + 1, 0)
        local _header_row = cond(`_headerrows', `_titlerows' + `_span_rows' + 1, 0)
        local _data_start = `_titlerows' + `_span_rows' + `_headerrows' + 1
        local _last_data_row = _N
        if `_last_data_row' < `_data_start' {
            noisily display as error "source produced no data rows"
            exit 2000
        }
        local _ndatarows = `_last_data_row' - `_data_start' + 1

        * hlines()/boldrows() number the exported data rows 1.._ndatarows and
        * vlines() the exported columns 1..K. A number outside the table has
        * no cell to style, so it is an error rather than silently dropped.
        foreach _lopt in hlines boldrows {
            foreach _r of local `_lopt' {
                if `_r' > `_ndatarows' {
                    noisily display as error "`_lopt'(): row `_r' is outside the table (data rows 1 to `_ndatarows')"
                    exit 125
                }
            }
        }
        foreach _c of local vlines {
            if `_c' > `K' {
                noisily display as error "vlines(): column `_c' is outside the table (columns 1 to `K')"
                exit 125
            }
        }

        * Footnote as trailing row(s): one per paragraph (" \ " separates
        * paragraphs, O4); a footnote without the token is one row as typed.
        local _foot_row = 0
        local _n_foot = 0
        if `"`macval(footnote)'"' != "" {
            mata: _puttab_fn_locals(st_local("footnote"))
            local _foot_row = _N + 1
            quietly set obs `=_N + `_n_foot''
            forvalues _j = 1/`_n_foot' {
                quietly replace c1 = `"`macval(_fn_p`_j')'"' in `=`_foot_row' + `_j' - 1'
            }
        }
        local _total_rows = _N

        * The analytical payload is complete before optional file side effects.
        * Stash it now so a failed CSV/Markdown/Excel write cannot erase it.
        local _ret_rows    = `_total_rows'
        local _ret_cols    = `K'
        local _ret_data    = `_ndatarows'
        local _ret_source  `"`_src'"'
        local _ret_npanels = `_pt_npanels'
        local _ret_nspan   = `_nspan'
        local _return_ready = 1

        * ----- optional CSV mirror of the assembled table -----
        if `"`csv'"' != "" {
            local _sink "csv"
            _tabtools_csv_write using `"`csv'"'
            capture confirm file `"`csv'"'
            if _rc {
                noisily display as error "CSV export completed but file was not created"
                exit 601
            }
            local _ret_csv `"`csv'"'
        }

        if `_has_markdown' {
            local _mdappend_opt ""
            if "`mdappend'" != "" local _mdappend_opt "append"
            local _md_novarnames ""
            local _md_hs = `_header_row'
            local _md_ds = `_data_start'
            if "`noheader'" != "" local _md_novarnames "novarnames"
            * The header row puttab built is the intended header, blanks
            * included: a matrix() table leaves the row-label column's header
            * empty in the workbook and CSV. Without strictheaders the writer
            * filled a blank header cell from the variable name, so the
            * Markdown header read "c1".
            else local _md_novarnames "strictheaders"
            * A GFM table cannot omit its header row. Under noheader with
            * panel(), the first body row is a panel heading, a panel header
            * or (panelinline) both in one: in the workbook it is ruled and
            * bold like a header, so in Markdown it takes the header slot
            * instead of an empty "|  |  |" line above it. Without such a
            * row the header line stays blank: data never becomes a header.
            if "`noheader'" != "" & `_ndatarows' > 1 {
                local _md_lead `_pt_hrows' `_pt_phrows' `_pt_ihrows'
                local _md_lead : list posof "1" in _md_lead
                if `_md_lead' {
                    local _md_hs = `_data_start'
                    local _md_ds = `_data_start' + 1
                    local _md_novarnames "strictheaders"
                }
            }
            local _sink "markdown"
            * keepblank: every exported observation is data, so one that is
            * missing in every column stays a Markdown body row, as it does in
            * the workbook and the CSV (C3, codex audit 2026-09-26).
            * Panel heading and panel header rows are bold in Markdown.
            local _md_bold ""
            foreach _r in `_pt_hrows' `_pt_phrows' `_pt_ihrows' {
                local _md_bold "`_md_bold' `=`_data_start' + `_r' - 1'"
            }
            local _md_boldopt ""
            if "`_md_bold'" != "" local _md_boldopt "boldrows(`_md_bold')"
            * GFM tables have one header row, so a spanning label is folded
            * into the header of each column it spans: "Span, Column".
            if `_span_rows' {
                tempfile _pt_pre_md
                quietly save `"`_pt_pre_md'"'
                forvalues _i = 1/`_nspan' {
                    forvalues _c = `_sp_c1`_i''/`_sp_c2`_i'' {
                        quietly replace c`_c' = cond(strtrim(c`_c'[`_header_row']) == "", ///
                            c`_sp_c1`_i''[`_span_row'], ///
                            c`_sp_c1`_i''[`_span_row'] + ", " + c`_c'[`_header_row']) ///
                            in `_header_row'
                    }
                }
            }
            capture noisily _tabtools_markdown_write using `"`markdown'"', ///
                `_mdappend_opt' headerstart(`_md_hs') datastart(`_md_ds') ///
                dataend(`_last_data_row') keepblank `_md_boldopt' ///
                title(`"`macval(title)'"') footnote(`"`macval(footnote)'"') `_md_novarnames'
            local _md_rc = _rc
            if `_span_rows' quietly use `"`_pt_pre_md'"', clear
            if `_md_rc' {
                noisily display as error "Failed to export Markdown to `markdown'"
                exit `_md_rc'
            }
            if `_sess_md' _tabtools_set_sinks mddone
            local _ret_markdown `"`markdown'"'
            local _ret_markdown_rows = r(n_rows)
            local _ret_markdown_cols = r(n_cols)
            noisily display as text "Markdown exported to `markdown'"
        }

        * LaTeX: the real header rows, never the Markdown-flattened "Span,
        * Column" row (the dataset was restored above). The header block is
        * every observation from the span row (when spanheader()/blockheader
        * built one) or the header row to the row before the data; spans()
        * declares each span from the layout puttab itself built.
        if `_has_latex' {
            local _texdocument_opt ""
            if "`texdocument'" != "" local _texdocument_opt "document"
            local _tex_appendopt ""
            if "`texappend'" != "" local _tex_appendopt "append"
            local _tex_novarnames "strictheaders"
            local _tex_hs = cond(`_span_rows', `_span_row', `_header_row')
            local _tex_ds = `_data_start'
            if "`noheader'" != "" {
                local _tex_novarnames "novarnames"
                local _tex_hs = `_data_start'
            }
            * noheader: no header block. A GFM table must have a header line,
            * so Markdown promotes a leading panel row into it; LaTeX has no
            * such need, so that row stays a bold body row like every other
            * panel heading, and r(latex_rows) is then r(markdown_rows) + 1.
            local _tex_bold ""
            foreach _r in `_pt_hrows' `_pt_phrows' `_pt_ihrows' {
                local _tex_bold "`_tex_bold' `=`_data_start' + `_r' - 1'"
            }
            foreach _r of local boldrows {
                local _tex_bold "`_tex_bold' `=`_data_start' + `_r' - 1'"
            }
            local _tex_boldopt ""
            if "`_tex_bold'" != "" local _tex_boldopt "boldrows(`_tex_bold')"
            local _tex_spans ""
            if `_span_rows' & "`noheader'" == "" {
                forvalues _i = 1/`_nspan' {
                    local _tex_spans "`_tex_spans' `_span_row' `_sp_c1`_i'' `_sp_c2`_i''"
                }
            }
            local _tex_spanopt ""
            if "`_tex_spans'" != "" local _tex_spanopt "spans(`_tex_spans')"
            local _sink "latex"
            capture noisily _tabtools_latex_write using `"`latex'"', ///
                `_tex_appendopt' `_texdocument_opt' texopts(`macval(texopts)') headerstart(`_tex_hs') datastart(`_tex_ds') ///
                dataend(`_last_data_row') keepblank `_tex_boldopt' `_tex_spanopt' ///
                title(`"`macval(title)'"') footnote(`"`macval(footnote)'"') `_tex_novarnames'
            local _tex_rc = _rc
            if `_tex_rc' {
                noisily display as error "Failed to export LaTeX to `latex'"
                exit `_tex_rc'
            }
            if `_sess_tex' _tabtools_set_sinks texdone
            local _ret_latex `"`latex'"'
            local _ret_latex_rows = r(n_rows)
            local _ret_latex_cols = r(n_cols)
            noisily display as text "LaTeX exported to `latex'"
        }

        * ===== Excel sheet geometry (shared house style with regtab/table1_tc) =====
        * The CSV/Markdown mirrors above use the compact in-memory table as built.
        * The Excel sheet adds the shared layout: a thin spacer column A, the title
        * spanning row 1 (cell A1, left-justified), and the table body anchored at
        * B2. Apply it to the (already-CSV/Markdown-exported) data; the dataset is
        * discarded by the restore at the end either way.
        if `_has_using' {

            tempvar _spacer _roworder

            * Reserve a blank title row when no title was supplied, so the body
            * always begins on row 2 (table top-left cell = B2).
            if !`_titlerows' {
                quietly gen long `_roworder' = _n
                quietly set obs `=_N + 1'
                quietly replace `_roworder' = 0 in L
                sort `_roworder'
                drop `_roworder'
            }
            * Prepend the spacer column (Excel column A) and carry the title text,
            * if any, into A1 so it shows from the left of the merged title row.
            local _c1type : type c1
            quietly gen `_c1type' `_spacer' = ""
            quietly replace `_spacer' = c1 in 1
            quietly replace c1 = "" in 1
            order `_spacer', first

            * Excel coordinates: content column j -> Excel column j+1; the title
            * occupies row 1, and the body shifts down by one when a title row was
            * inserted above (`_x_roff' = 1 when no title was supplied).
            local _xK = `K' + 1
            local _x_roff = 1 - `_titlerows'
            local _x_header_row = cond(`_headerrows', `_header_row' + `_x_roff', 0)
            local _x_data_start = `_data_start' + `_x_roff'
            local _x_last_data  = `_last_data_row' + `_x_roff'
            local _x_total_rows = `_total_rows' + `_x_roff'
            local _x_foot_row   = cond(`_foot_row' > 0, `_foot_row' + `_x_roff', 0)
            local _x_span_row   = cond(`_span_rows', `_span_row' + `_x_roff', 0)

            * The span row's labels are merged across their columns, so they
            * do not set a column's width. Panel headings are not merged:
            * their text sits in the row-label column and sets its width.
            tempvar _nowid
            quietly gen byte `_nowid' = 0
            if `_span_rows' quietly replace `_nowid' = 1 in `_x_span_row'

            * ===== border code (thin=1, medium=2, thick=3, none=4) =====
            local _hbc = 1
            if "`_hborder'" == "medium" local _hbc = 2
            if "`_hborder'" == "thick"  local _hbc = 3
            if "`_hborder'" == "none"   local _hbc = 4

            * ===== spacer column width + content widths (header + data rows) =====
            tempname _rules
            matrix `_rules' = (13, 1, 1, 1, 1, 1, 0, 0, 0)
            forvalues j = 1/`K' {
                tempvar _len
                quietly gen long `_len' = length(c`j')
                quietly summarize `_len' ///
                    if c`j' != "" & inrange(_n, 2, `_x_last_data') & !`_nowid', meanonly
                local _w = cond(r(N) > 0, ceil(r(max) * 0.95) + 2, 10)
                if `j' == 1 {
                    if `_w' < 12 local _w = 12
                    if `_w' > 50 local _w = 50
                }
                else {
                    if `_w' < 8  local _w = 8
                    if `_w' > 32 local _w = 32
                }
                drop `_len'
                local _xcol = `j' + 1
                matrix `_rules' = `_rules' \ (13, 1, 1, `_xcol', `_xcol', `_w', 0, 0, 0)
            }
            drop `_nowid'

            * ===== base font, wrap, vertical centering, left alignment =====
            matrix `_rules' = `_rules' \ ///
                (1, 1, `_x_total_rows', 1, `_xK', `_fontsize', 1, 0, 0) \ ///
                (4, 1, `_x_total_rows', 1, `_xK', 0, 1, 0, 0) \ ///
                (6, 1, `_x_total_rows', 1, `_xK', 0, 2, 0, 0) \ ///
                (5, 1, `_x_total_rows', 1, `_xK', 0, 1, 0, 0)

            * ===== title row (row 1, merged A1 across the width, left-justified) =====
            matrix `_rules' = `_rules' \ ///
                (12, 1, 1, 1, 1, 30, 0, 0, 0) \ ///
                (14, 1, 1, 1, `_xK', 0, 0, 0, 0) \ ///
                (1, 1, 1, 1, `_xK', `=`_fontsize' + 2', 1, 0, 0) \ ///
                (2, 1, 1, 1, `_xK', 0, 1, 0, 0) \ ///
                (4, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                (5, 1, 1, 1, `_xK', 0, 1, 0, 0) \ ///
                (6, 1, 1, 1, 1, 0, 2, 0, 0)

            * ===== header row (or top rule above first data row); columns B onward =====
            if `_headerrows' {
                matrix `_rules' = `_rules' \ ///
                    (2, `_x_header_row', `_x_header_row', 2, `_xK', 0, 1, 0, 0) \ ///
                    (5, `_x_header_row', `_x_header_row', 2, `_xK', 0, 2, 0, 0) \ ///
                    (9, `_x_header_row', `_x_header_row', 2, `_xK', 0, `_hbc', 0, 0)
                * The table's top rule sits above the span row when there is one.
                local _x_top_rule = cond(`_span_rows', `_x_span_row', `_x_header_row')
                matrix `_rules' = `_rules' \ ///
                    (8, `_x_top_rule', `_x_top_rule', 2, `_xK', 0, `_hbc', 0, 0)
                if "`headershade'" != "" {
                    matrix `_rules' = `_rules' \ ///
                        (7, `_x_header_row', `_x_header_row', 2, `_xK', 0, -1, 0, 0)
                }
                * spanheader(): bold, centred, each span merged and ruled below.
                if `_span_rows' {
                    matrix `_rules' = `_rules' \ ///
                        (2, `_x_span_row', `_x_span_row', 2, `_xK', 0, 1, 0, 0) \ ///
                        (5, `_x_span_row', `_x_span_row', 2, `_xK', 0, 2, 0, 0)
                    if "`headershade'" != "" {
                        matrix `_rules' = `_rules' \ ///
                            (7, `_x_span_row', `_x_span_row', 2, `_xK', 0, -1, 0, 0)
                    }
                    forvalues _i = 1/`_nspan' {
                        local _xc1 = `_sp_c1`_i'' + 1
                        local _xc2 = `_sp_c2`_i'' + 1
                        if `_xc2' > `_xc1' {
                            matrix `_rules' = `_rules' \ ///
                                (14, `_x_span_row', `_x_span_row', `_xc1', `_xc2', 0, 0, 0, 0)
                        }
                        matrix `_rules' = `_rules' \ ///
                            (9, `_x_span_row', `_x_span_row', `_xc1', `_xc2', 0, 1, 0, 0)
                    }
                }
            }
            else {
                matrix `_rules' = `_rules' \ ///
                    (8, `_x_data_start', `_x_data_start', 2, `_xK', 0, `_hbc', 0, 0)
            }

            * ===== center data columns; the first (label) column stays left =====
            if `K' >= 2 {
                matrix `_rules' = `_rules' \ ///
                    (5, `_x_data_start', `_x_last_data', 3, `_xK', 0, 2, 0, 0)
            }

            * ===== bottom rule below the last data row =====
            matrix `_rules' = `_rules' \ ///
                (9, `_x_last_data', `_x_last_data', 2, `_xK', 0, `_hbc', 0, 0)

            * ===== vertical rules: outer box and row-label column =====
            * Non-academic styles box the table body (header + data rows) and
            * close the row-label column, so with the header rules above the
            * header row and the row labels each sit in their own box, as in
            * regtab/desctab/stratetab. academic keeps horizontal rules only.
            local _vbc = cond("`borderstyle'" == "medium", 2, 1)
            local _x_box_top = cond(`_headerrows', `_x_header_row', `_x_data_start')
            if `_span_rows' local _x_box_top = `_x_span_row'
            if "`borderstyle'" != "academic" {
                matrix `_rules' = `_rules' \ ///
                    (10, `_x_box_top', `_x_last_data', 2, 2, 0, `_vbc', 0, 0) \ ///
                    (11, `_x_box_top', `_x_last_data', `_xK', `_xK', 0, `_vbc', 0, 0)
                if `K' >= 2 {
                    matrix `_rules' = `_rules' \ ///
                        (11, `_x_box_top', `_x_last_data', 2, 2, 0, `_vbc', 0, 0)
                }
            }

            * ===== user rules: hlines() above data row #, vlines() right of
            * column #, boldrows() bold data row # (all styles) =====
            foreach _r of local hlines {
                local _xr = `_x_data_start' + `_r' - 1
                matrix `_rules' = `_rules' \ ///
                    (8, `_xr', `_xr', 2, `_xK', 0, `_vbc', 0, 0)
            }
            foreach _c of local vlines {
                local _xc = `_c' + 1
                matrix `_rules' = `_rules' \ ///
                    (11, `_x_box_top', `_x_last_data', `_xc', `_xc', 0, `_vbc', 0, 0)
            }
            foreach _r of local boldrows {
                local _xr = `_x_data_start' + `_r' - 1
                matrix `_rules' = `_rules' \ ///
                    (2, `_xr', `_xr', 2, `_xK', 0, 1, 0, 0)
            }

            * ===== panel() heading rows: bold and ruled above, not merged
            * (the heading sits in the row-label column, the other cells stay
            * blank); panelheader() rows: bold with a rule below (shaded with
            * headershade) =====
            foreach _r of local _pt_hrows {
                local _xr = `_x_data_start' + `_r' - 1
                matrix `_rules' = `_rules' \ ///
                    (2, `_xr', `_xr', 2, `_xK', 0, 1, 0, 0) \ ///
                    (8, `_xr', `_xr', 2, `_xK', 0, `_vbc', 0, 0)
            }
            foreach _r of local _pt_phrows {
                local _xr = `_x_data_start' + `_r' - 1
                matrix `_rules' = `_rules' \ ///
                    (2, `_xr', `_xr', 2, `_xK', 0, 1, 0, 0) \ ///
                    (9, `_xr', `_xr', 2, `_xK', 0, `_vbc', 0, 0)
                if "`headershade'" != "" {
                    matrix `_rules' = `_rules' \ ///
                        (7, `_xr', `_xr', 2, `_xK', 0, -1, 0, 0)
                }
            }
            * panelinline rows: heading and header in one row -- bold, the
            * heading's rule above and the header's rule below, not merged
            * (every cell holds text)
            foreach _r of local _pt_ihrows {
                local _xr = `_x_data_start' + `_r' - 1
                matrix `_rules' = `_rules' \ ///
                    (2, `_xr', `_xr', 2, `_xK', 0, 1, 0, 0) \ ///
                    (8, `_xr', `_xr', 2, `_xK', 0, `_vbc', 0, 0) \ ///
                    (9, `_xr', `_xr', 2, `_xK', 0, `_vbc', 0, 0)
                if "`headershade'" != "" {
                    matrix `_rules' = `_rules' \ ///
                        (7, `_xr', `_xr', 2, `_xK', 0, -1, 0, 0)
                }
            }

            * ===== zebra striping over data rows =====
            * Built in one step: appending a row per stripe is quadratic in
            * the number of data rows.
            if "`zebra'" != "" & `=`_x_data_start' + 1' <= `_x_last_data' {
                mata: _tt_zr = `=`_x_data_start' + 1' :+ 2 :* (0::floor((`_x_last_data' - `=`_x_data_start' + 1') / 2))
                mata: st_matrix("`_rules'", st_matrix("`_rules'") \ ///
                    (J(rows(_tt_zr), 1, 7), _tt_zr, _tt_zr, J(rows(_tt_zr), 1, 2), ///
                    J(rows(_tt_zr), 1, `_xK'), J(rows(_tt_zr), 1, 0), ///
                    J(rows(_tt_zr), 1, -2), J(rows(_tt_zr), 2, 0)))
                mata: mata drop _tt_zr
            }

            * ===== footnote row (column B onward, smaller italic) =====
            * The merge (rule 14) spans columns B.._xK. A one-column table
            * has _xK = 2, where it merged B#:B# with itself: a single-cell
            * range that merges nothing and that some consumers flag.
            if `_x_foot_row' > 0 {
                local _fn_size = max(`_fontsize' - 2, 6)
                forvalues _j = 1/`_n_foot' {
                    local _xfr = `_x_foot_row' + `_j' - 1
                    if `_xK' > 2 {
                        matrix `_rules' = `_rules' \ ///
                            (14, `_xfr', `_xfr', 2, `_xK', 0, 0, 0, 0)
                    }
                    matrix `_rules' = `_rules' \ ///
                        (1, `_xfr', `_xfr', 2, `_xK', `_fn_size', 1, 0, 0) \ ///
                        (3, `_xfr', `_xfr', 2, `_xK', 0, 1, 0, 0) \ ///
                        (5, `_xfr', `_xfr', 2, `_xK', 0, 1, 0, 0)
                }
            }

            * ===== write the sheet and apply the styling =====
            local _sink "xlsx"
            * Session workbook: the first write since tabtools set starts it over.
            if `_sess_xlsx' _tabtools_set_sinks xlsxstart
            _tabtools_xlsx_write using `"`using'"', sheet(`"`macval(sheet)'"') book(`_xlsx_book')
            local _book_open = 1
            local _xlsx_written = 1
            * Excel matches an existing sheet case-insensitively; style, report,
            * and return the spelling actually in the workbook.
            mata: st_local("sheet", st_global("r(sheet)"))

            _tabtools_xlsx_apply_styles, defer book(`_xlsx_book') sheet(`"`macval(sheet)'"') ///
                rules(`_rules') font("`_font'") ///
                color1("`_headercolor'") color2("`_zebracolor'")

            mata: `_xlsx_book'.close_book()
            local _book_open = 0

            * xl() appends a style record for every styled cell instead of
            * reusing one per distinct format, so collapse the pools here;
            * a workbook that keeps growing would otherwise reach Stata's
            * 65,536-record ceiling and fail with r(16147).
            _tabtools_xlsx_compact_styles using "`using'"
            capture mata: mata drop `_xlsx_book'

            capture confirm file `"`using'"'
            if _rc {
                noisily display as error "export command succeeded but file `using' was not found"
                exit 601
            }
            local _ret_sheet `"`macval(sheet)'"'
            local _ret_file  `"`using'"'
        }

        if `_has_using' {
            noisily _tabtools_export_done using `"`using'"', sheet(`"`macval(sheet)'"')
        }
    }
    local rc = _rc
    if `_book_open' {
        * stata-dev-ignore: capture-rc — cleanup after local rc = _rc; a failed close must not mask the export status, which is returned through rc below
        capture mata: `_xlsx_book'.close_book()
    }
    capture mata: mata drop `_xlsx_book'
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `_return_ready' {
        return scalar n_rows    = `_ret_rows'
        return scalar n_cols    = `_ret_cols'
        return scalar n_datarows = `_ret_data'
        return local  source    "`_ret_source'"
        return scalar n_panels  = `_ret_npanels'
        return scalar n_spans   = `_ret_nspan'
        if `_ret_sc' {
            return scalar smallcells      = `_ret_sc_k'
            return scalar n_primary       = `_ret_sc_np'
            return scalar n_complementary = `_ret_sc_nc'
        }
        if `"`_ret_file'"' != "" {
            return local  sheet     `"`macval(_ret_sheet)'"'
            return local  file      `"`_ret_file'"'
        }
        if `"`_ret_csv'"' != "" return local csv `"`_ret_csv'"'
        if `"`_ret_markdown'"' != "" {
            return local markdown `"`_ret_markdown'"'
            return scalar markdown_rows = `_ret_markdown_rows'
            return scalar markdown_cols = `_ret_markdown_cols'
        }
        if `"`_ret_latex'"' != "" {
            return local latex `"`_ret_latex'"'
            return scalar latex_rows = `_ret_latex_rows'
            return scalar latex_cols = `_ret_latex_cols'
        }
    }
    if `rc' {
        if inlist(`rc', 603, 608, 610, 16106) {
            * a failed sheet write printed its hint in _tabtools_xlsx_write;
            * a failure after it (styling, closing the book) needs its own
            if "`_sink'" == "xlsx" & `_xlsx_written' {
                capture noisily _tabtools_export_hint `"`using'"'
            }
            else if "`_sink'" == "markdown" {
                noisily display as error "Hint: check that the Markdown file's directory exists and the file is writable"
            }
            else if "`_sink'" == "latex" {
                noisily display as error "Hint: check that the LaTeX file's directory exists and the file is writable"
            }
            else if "`_sink'" == "csv" {
                noisily display as error "Hint: check that the CSV file's directory exists and the file is not open in another application"
            }
        }
        exit `rc'
    }

    if "`open'" != "" & `"`_ret_file'"' != "" _tabtools_open_file `"`_ret_file'"'
end


* ============================================================================
* smallcells(): option parsing and masking (private to puttab)
* ============================================================================

* Resolve the counts(), fraction(), rowtotal() and withhold() names against
* the source (every variable still in memory) and check how they combine.
* Sets in the caller: _sc_counts, _sc_fnum, _sc_fden (paired lists),
* _sc_rttot (the rowtotal() totals), _sc_rtadd (the addends of each total,
* separated by ";"), and _sc_w (normalized "\ key: vars \ key: vars").
capture program drop _puttab_sc_parse
program define _puttab_sc_parse, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _c ""
    local _fn ""
    local _fd ""
    local _rt ""
    local _ra ""
    local _w ""
    capture noisily {
        syntax , COUNTs(string) [FRACtion(string) WITHhold(string) ROWTotal(string)]

        capture unab _c : `counts'
        if _rc {
            display as error "counts(): `counts' does not name variables of the source"
            exit 111
        }
        local _dup : list dups _c
        if "`_dup'" != "" {
            display as error "counts(): `_dup' is listed more than once"
            exit 198
        }

        * fraction(num/denom ...): both are counts() columns
        foreach _t of local fraction {
            if !regexm(`"`_t'"', "^([^/]+)/([^/]+)$") {
                display as error `"fraction(): `_t' is not num/denom; write each pair without spaces, e.g. e1/n1"'
                exit 198
            }
            local _a = regexs(1)
            local _b = regexs(2)
            foreach _s in a b {
                capture unab _u : `_`_s''
                if _rc | `: word count `_u'' != 1 {
                    display as error "fraction(): `_`_s'' does not name one variable of the source"
                    exit 111
                }
                if !`: list _u in _c' {
                    display as error "fraction(): `_u' must also be named in counts()"
                    exit 198
                }
                local _`_s' `_u'
            }
            if "`_a'" == "`_b'" {
                display as error "fraction(): `_a'/`_b' divides a column by itself"
                exit 198
            }
            local _fn `_fn' `_a'
            local _fd `_fd' `_b'
        }
        local _fall `_fn' `_fd'
        local _dup : list dups _fall
        if "`_dup'" != "" {
            display as error "fraction(): `_dup' is in more than one fraction"
            exit 198
        }

        * rowtotal(totvar [: addends] [\ totvar: addends ...]): in every
        * row the addends add up to totvar; one specification without
        * ": addends" means every other counts() column. Several sums are
        * disjoint groups (_rt lists the totals, _ra the addends of each
        * total separated by ";").
        local _rtspecs : copy local rowtotal
        local _nrt 0
        local _rtall ""
        local _rtadds ""
        while strtrim(`"`_rtspecs'"') != "" {
            gettoken _spec _rtspecs : _rtspecs, parse("\")
            local _spec = strtrim(`"`_spec'"')
            if `"`_spec'"' == "\" | `"`_spec'"' == "" continue
            local ++_nrt
            local _rtspec`_nrt' `"`_spec'"'
        }
        forvalues _i = 1/`_nrt' {
            local _spec `"`_rtspec`_i''"'
            gettoken _rtv _rest : _spec, parse(":")
            capture unab _t : `_rtv'
            if _rc | `: word count `_t'' != 1 {
                display as error "rowtotal(): `_rtv' does not name one variable of the source"
                exit 111
            }
            if !`: list _t in _c' {
                display as error "rowtotal(): `_t' must also be named in counts()"
                exit 198
            }
            local _a ""
            local _rest = strtrim(`"`_rest'"')
            if `"`_rest'"' != "" {
                local _rest = strtrim(substr(`"`_rest'"', 2, .))
                capture unab _a : `_rest'
                if _rc | `"`_rest'"' == "" {
                    display as error "rowtotal(): `_rest' does not name variables of the source"
                    exit 111
                }
                foreach _v of local _a {
                    if !`: list _v in _c' {
                        display as error "rowtotal(): addend `_v' must also be named in counts()"
                        exit 198
                    }
                }
            }
            else {
                if `_nrt' > 1 {
                    display as error "rowtotal(): name the addends of every sum when you declare more than one, as in rowtotal(etot: e1 e0 \ ntot: n1 n0)"
                    exit 198
                }
                local _a : list _c - _t
                local _clash : list _a & _fall
                if "`_clash'" != "" {
                    display as error "rowtotal(): `_clash' is in a fraction(); name the addends, as in rowtotal(`_t': varlist)"
                    exit 198
                }
            }
            if `: list _t in _a' {
                display as error "rowtotal(): `_t' cannot be one of its own addends"
                exit 198
            }
            if "`_a'" == "" {
                display as error "rowtotal(): no counts() column adds up to `_t'"
                exit 198
            }
            local _dup : list dups _a
            if "`_dup'" != "" {
                display as error "rowtotal(): `_dup' is listed more than once"
                exit 198
            }
            local _rall `_t' `_a'
            local _clash : list _rall & _fall
            if "`_clash'" != "" {
                display as error "rowtotal() and fraction() may not share a column (`_clash')"
                exit 198
            }
            local _clash : list _rall & _rtall
            if "`_clash'" != "" {
                display as error "rowtotal(): `_clash' is in more than one sum; the sums must not share a column"
                exit 198
            }
            local _rtall `_rtall' `_rall'
            local _rt `_rt' `_t'
            local _ra = cond(`"`_ra'"' == "", "`_a'", "`_ra' ; `_a'")
        }

        * withhold(countvar: varlist [\ countvar: varlist ...])
        local _rest : copy local withhold
        while strtrim(`"`_rest'"') != "" {
            gettoken _spec _rest : _rest, parse("\")
            local _spec = strtrim(`"`_spec'"')
            if `"`_spec'"' == "\" | `"`_spec'"' == "" continue
            gettoken _key _cols : _spec, parse(":")
            local _cols = strtrim(`"`_cols'"')
            if substr(`"`_cols'"', 1, 1) != ":" {
                display as error `"withhold(): `_spec' is not countvar: varlist; separate specifications with \"'
                exit 198
            }
            local _cols = strtrim(substr(`"`_cols'"', 2, .))
            capture unab _k : `_key'
            if _rc | `: word count `_k'' != 1 {
                display as error "withhold(): `_key' does not name one variable of the source"
                exit 111
            }
            if !`: list _k in _c' {
                display as error "withhold(): `_k' must be named in counts()"
                exit 198
            }
            capture unab _wc : `_cols'
            if _rc | `"`_cols'"' == "" {
                display as error "withhold(): `_cols' does not name variables of the source"
                exit 111
            }
            local _w `"`_w' \ `_k': `_wc'"'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    c_local _sc_counts "`_c'"
    c_local _sc_fnum "`_fn'"
    c_local _sc_fden "`_fd'"
    c_local _sc_rttot "`_rt'"
    c_local _sc_rtadd "`_ra'"
    c_local _sc_w `"`_w'"'
end

* Check the parsed names against the exported columns, mask through the
* _tabtools_smallcells engine (Mata _puttab_sc_run), and add one rendered
* text variable per count, fraction and withheld column. Sets in the caller:
* _sc_ovr ("column textvar" pairs), _sc_consumed (the fraction()
* denominators, printed inside their fraction), _sc_np and _sc_nc.
capture program drop _puttab_sc_apply
program define _puttab_sc_apply, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _sc_ovr ""
    local _sc_np 0
    local _sc_nc 0
    capture noisily {
        syntax , SRCvars(string) COUNTs(string) [K(string) MODE(string) ///
            PANELvar(string) TRvar(string) DIGits(integer 2) NFormat(string) ///
            FNUM(string) FDEN(string) RTTOT(string) RTADD(string) WITHhold(string) ///
            POOL(string)]

        foreach _v of local counts {
            if !`: list _v in srcvars' {
                display as error "counts(): `_v' is not an exported column of the table"
                exit 198
            }
            capture confirm numeric variable `_v', exact
            if _rc {
                display as error "counts(): `_v' is not numeric"
                exit 109
            }
        }
        * withheld columns: exported, and not a denominator printed inside
        * its fraction (withhold the numerator column to blank the fraction)
        local _rest : copy local withhold
        while strtrim(`"`_rest'"') != "" {
            gettoken _spec _rest : _rest, parse("\")
            local _spec = strtrim(`"`_spec'"')
            if `"`_spec'"' == "\" | `"`_spec'"' == "" continue
            gettoken _key _cols : _spec, parse(":")
            local _cols = substr(strtrim(`"`_cols'"'), 2, .)
            foreach _v of local _cols {
                if !`: list _v in srcvars' {
                    display as error "withhold(): `_v' is not an exported column of the table"
                    exit 198
                }
                if `: list _v in fden' {
                    display as error "withhold(): `_v' is printed inside its fraction(); withhold the numerator column instead"
                    exit 198
                }
            }
        }

        local _lt ""
        local _ge ""
        local _k = 0
        if "`k'" != "" {
            local _k = `k'
            _tabtools_smallcells_render, value(1) mask(1) smallcells(`_k')
            local _lt `"`r(display)'"'
            _tabtools_smallcells_render, value(`_k') mask(2) smallcells(`_k')
            local _ge `"`r(display)'"'
        }
        local _prim = ("`mode'" == "primary")
        local _printed : list srcvars - fden
        tempname _t1 _t2 _t3 _t4 _t5 _t6 _t7
        local _sc_rc 0
        local _sc_err ""
        mata: _puttab_sc_run("`counts'", "`fnum'", "`fden'", "`rttot'", ///
            "`rtadd'", st_local("withhold"), "`trvar'", "`panelvar'", ///
            "`_printed'", `_k', `_prim', st_local("_lt"), st_local("_ge"), ///
            `digits', "`nformat'", "`_t1' `_t2' `_t3' `_t4' `_t5' `_t6' `_t7'", ///
            "`pool'")
        if `_sc_rc' {
            if `"`_sc_err'"' != "" display as error `"`_sc_err'"'
            exit `_sc_rc'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    c_local _sc_ovr "`_sc_ovr'"
    c_local _sc_consumed "`fden'"
    c_local _sc_np = `_sc_np'
    c_local _sc_nc = `_sc_nc'
end



* ============================================================================
* Mata: build the c1..cK string table from a dataset or a matrix
* ============================================================================
version 17.0
capture mata: mata drop _puttab_data_table()
capture mata: mata drop _puttab_matrix_table()
capture mata: mata drop _puttab_fmt_num()
capture mata: mata drop _puttab_stripe_names()
capture mata: mata drop _puttab_emit_table()
capture mata: mata drop _puttab_is_headerrow()
capture mata: mata drop _puttab_panelize()
capture mata: mata drop _puttab_span_parse()
capture mata: mata drop _puttab_fn_locals()
capture mata: mata drop _puttab_span_err()
capture mata: mata drop _puttab_block_spans()
capture mata: mata drop _puttab_put()
capture mata: mata drop _puttab_sc_run()
capture mata: mata drop _puttab_sc_fail()
capture mata: mata drop _puttab_sc_engine()
capture mata: mata drop _puttab_sc_text()
capture mata: mata drop _puttab_sc_undeclared()
capture mata: mata drop _puttab_sc_lonetotal()
capture mata: mata drop _puttab_sc_copies()

* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// Format a numeric column to strings, honouring value labels first, then a
// date/time display format (%t...), then integer-vs-fractional display at the
// requested number of digits. digits() cannot describe a date, so a %t column
// is always written through its own format; every other numeric column uses
// digits(). An all-integer column uses nfmt (nformat(), already widened)
// when given. A column whose own format ends in fc keeps its comma
// grouping, with digits() still setting the decimals (gc is not followed:
// stock data such as auto carry %8.0gc without asking for separators). A value that rounds
// to zero is written without a minus sign.
string colvector _puttab_fmt_num(
    real colvector v,
    real scalar digits,
    string scalar vlabel,
    string scalar vfmt,
    string scalar nfmt)
{
    string colvector out, mapped
    real scalar i, n, allint, isdate
    string scalar ifmt, ffmt, grp

    n = rows(v)
    out = J(n, 1, "")

    mapped = J(n, 1, "")
    if (vlabel != "") {
        if (st_vlexists(vlabel)) {
            mapped = st_vlmap(vlabel, v)
        }
    }

    isdate = regexm(vfmt, "^%-?t")
    if (isdate) {
        for (i = 1; i <= n; i++) {
            if (mapped[i] != "") out[i] = mapped[i]
            else if (v[i] < .) out[i] = strtrim(ustrregexra(strofreal(v[i], vfmt), "-(?=[0.,]+\z)", ""))
        }
        return(out)
    }

    allint = 1
    for (i = 1; i <= n; i++) {
        if (v[i] < . & v[i] != floor(v[i])) {
            allint = 0
            break
        }
    }
    grp = (regexm(vfmt, "^%-?0?[0-9]+[.][0-9]+fc$") ? "c" : "")
    ifmt = (nfmt != "" ? nfmt : "%32.0f" + grp)
    ffmt = "%32." + ustrregexra(strofreal(digits, "%9.0f"), "-(?=[0.,]+\z)", "") + "f" + grp

    for (i = 1; i <= n; i++) {
        if (mapped[i] != "") {
            out[i] = mapped[i]
        }
        else if (v[i] < .) {
            out[i] = strtrim(ustrregexra(strofreal(v[i], allint ? ifmt : ffmt), "-(?=[0.,]+\z)", ""))
            if (regexm(out[i], "^-0([.]0+)?$")) out[i] = substr(out[i], 2, .)
        }
    }
    return(out)
}

// Combine a matrix stripe (eqname, name) into display labels.
string colvector _puttab_stripe_names(string matrix stripe)
{
    string colvector out
    real scalar i, n
    string scalar eq

    n = rows(stripe)
    out = J(n, 1, "")
    for (i = 1; i <= n; i++) {
        eq = stripe[i, 1]
        if (eq != "" & eq != "_") {
            out[i] = eq + ":" + stripe[i, 2]
        }
        else {
            out[i] = stripe[i, 2]
        }
    }
    return(out)
}

// Replace the current (empty) dataset with string variables c1..cK holding the
// assembled table `out'. Row `header_at' (0 = none) is the header row.
void _puttab_emit_table(string matrix out)
{
    real scalar j, i, K, N, maxlen
    string scalar vname, vtype

    N = rows(out)
    K = cols(out)

    stata("quietly drop _all")
    for (j = 1; j <= K; j++) {
        maxlen = 0
        for (i = 1; i <= N; i++) {
            if (strlen(out[i, j]) > maxlen) maxlen = strlen(out[i, j])
        }
        if (maxlen < 1) maxlen = 1
        if (maxlen <= 2045) vtype = "str" + ustrregexra(strofreal(maxlen, "%9.0f"), "-(?=[0.,]+\z)", "")
        else vtype = "strL"
        vname = "c" + ustrregexra(strofreal(j, "%9.0f"), "-(?=[0.,]+\z)", "")
        (void) st_addvar(vtype, vname)
    }
    st_addobs(N)
    for (j = 1; j <= K; j++) {
        st_sstore(., "c" + ustrregexra(strofreal(j, "%9.0f"), "-(?=[0.,]+\z)", ""), out[, j])
    }
}

// Is observation 1 a header row that merely repeats the variable labels?
//
// tabtools table producers (desctab/table1_tc with clear or frame()) hand back
// a header-shaped dataset: observation 1 carries each column's variable label
// so a bare -list- reads as a table.  A consumer that draws its own header
// from those same labels would print the text twice.  The test is on content
// only -- no marker, no characteristic -- so it stays correct for a caller who
// has already removed the row, and it cannot fire on a table that never had
// one.
//
// Observation 1 qualifies only when ALL of these hold:
//   - there are at least 2 observations (a lone row is data, never a header);
//   - every exported column is a string variable: a rendered tabtools table
//     is all-string, so any numeric column means raw data;
//   - every cell in observation 1 equals its own column's (non-empty) variable
//     label after trimming, except that the FIRST column -- the producers'
//     row-label stub -- may be blank;
//   - at least one cell actually repeats its label.
// The earlier rule also accepted missing numeric cells and blanks anywhere,
// so a genuine first data row (a "Group" label with a missing count) was
// silently consumed as a header.
real scalar _puttab_is_headerrow(string scalar varlist)
{
    string rowvector vars
    real scalar j, K, matched
    string scalar cell, lbl

    vars = tokens(varlist)
    K = cols(vars)
    if (K < 1 | st_nobs() < 2) return(0)

    matched = 0
    for (j = 1; j <= K; j++) {
        if (!st_isstrvar(vars[j])) return(0)
        cell = strtrim(st_sdata(1, vars[j]))
        if (cell == "") {
            if (j == 1) continue
            return(0)
        }
        lbl = strtrim(st_varlabel(vars[j]))
        if (lbl == "" | cell != lbl) return(0)
        matched++
    }
    return(matched > 0)
}

// Build the table from the current dataset's variables. headvar/newvar
// (panel(); "" = none) name a string variable holding each observation's
// panel heading text and a 0/1 variable marking the first observation of a
// panel; phvars names the panelheader() text variables.
void _puttab_data_table(
    string scalar varlist,
    real scalar digits,
    real scalar titlerows,
    real scalar headerrows,
    real scalar usevarlabels,
    string scalar headvar,
    string scalar newvar,
    string scalar phvars,
    string scalar nfmt,
    | string scalar ovr)
{
    string rowvector vars, ov
    string matrix out
    string colvector scol
    real colvector ncol
    real scalar i, j, K, N, total, hdr, datatop, o
    string scalar lbl, hdrtext

    // ovr: "column textvar ..." pairs (smallcells()); a listed column is
    // printed from its rendered text variable instead of its own values
    ov = tokens(ovr)
    vars = tokens(varlist)
    K = cols(vars)
    N = st_nobs()
    total = titlerows + headerrows + N
    out = J(total, K, "")

    hdr = titlerows + 1            // header row index (if headerrows)
    datatop = titlerows + headerrows + 1

    for (j = 1; j <= K; j++) {
        // header text
        if (headerrows) {
            hdrtext = vars[j]
            if (usevarlabels) {
                lbl = st_varlabel(vars[j])
                if (lbl != "") hdrtext = lbl
            }
            out[hdr, j] = hdrtext
        }
        // body
        o = 0
        for (i = 1; i < cols(ov); i = i + 2) {
            if (ov[i] == vars[j]) {
                o = i
                break
            }
        }
        if (o) {
            scol = st_sdata(., ov[o + 1])
        }
        else if (st_isstrvar(vars[j])) {
            scol = st_sdata(., vars[j])
        }
        else {
            ncol = st_data(., vars[j])
            scol = _puttab_fmt_num(ncol, digits, st_varvaluelabel(vars[j]),
                st_varformat(vars[j]), nfmt)
        }
        out[(datatop..total), j] = scol
    }

    if (headvar != "") out = _puttab_panelize(out, datatop, headvar, newvar, phvars)
    _puttab_emit_table(out)
}

// panel(): insert a heading row where a panel starts (its text in column 1,
// the rest blank), then -- with panelheader() -- that panel's header row
// when any of its cells is non-blank, and indent the row labels of a panel
// that has a heading by three spaces (none when the caller's local
// _pt_noindent is 1, from noindent). A panel whose heading text is blank
// (missing or empty panel value) gets no heading and no indent. Posts the
// body positions (1 = first body row) of the heading rows in _pt_hrows and
// of the panel header rows in _pt_phrows, and the count in _pt_npanels.
// With panelinline (_pt_inline = 1) a headed panel whose header row is not
// blank gets ONE row: the header with the heading text in its first cell,
// posted in _pt_ihrows; a non-blank first header cell there sets
// _pt_inl_err to the heading text (the caller errors) instead of being
// overwritten.
string matrix _puttab_panelize(
    string matrix out,
    real scalar datatop,
    string scalar headvar,
    string scalar newvar,
    string scalar phvars)
{
    string colvector head
    real colvector isnew
    string matrix ph, body, nb
    string rowvector row
    real colvector hrows, phrows, ihrows
    real scalar i, n, K, headed, r, npan, indent, inl, hasph

    indent = (st_local("_pt_noindent") != "1")
    inl = (st_local("_pt_inline") == "1")
    head = st_sdata(., headvar)
    isnew = st_data(., newvar)
    n = rows(head)
    K = cols(out)
    ph = (phvars != "" ? st_sdata(., tokens(phvars)) : J(n, 0, ""))
    body = out[(datatop..rows(out)), .]
    nb = J(n * (2 + (cols(ph) > 0)), K, "")
    hrows = J(0, 1, .)
    phrows = J(0, 1, .)
    ihrows = J(0, 1, .)
    headed = 0
    npan = 0
    r = 0
    for (i = 1; i <= n; i++) {
        if (isnew[i]) {
            headed = (strtrim(head[i]) != "")
            hasph = 0
            if (cols(ph) > 0) hasph = any(strtrim(ph[i, .]) :!= "")
            if (inl & headed & hasph) {
                if (strtrim(ph[i, 1]) != "") {
                    st_local("_pt_inl_err", strtrim(head[i]))
                    return(out)
                }
                r++
                nb[r, .] = ph[i, .]
                nb[r, 1] = strtrim(head[i])
                ihrows = ihrows \ r
                npan++
            }
            else if (headed) {
                r++
                nb[r, 1] = strtrim(head[i])
                hrows = hrows \ r
                npan++
            }
            if (cols(ph) > 0 & !(inl & headed & hasph)) {
                if (hasph) {
                    r++
                    nb[r, .] = ph[i, .]
                    phrows = phrows \ r
                }
            }
        }
        row = body[i, .]
        if (indent & headed & row[1] != "") row[1] = "   " + row[1]
        r++
        nb[r, .] = row
    }
    st_local("_pt_hrows", rows(hrows) ? invtokens(strofreal(hrows')) : "")
    st_local("_pt_phrows", rows(phrows) ? invtokens(strofreal(phrows')) : "")
    st_local("_pt_ihrows", rows(ihrows) ? invtokens(strofreal(ihrows')) : "")
    st_local("_pt_npanels", strofreal(npan))
    if (datatop > 1) return(out[(1..datatop - 1), .] \ nb[(1..r), .])
    return(nb[(1..r), .])
}

void _puttab_span_err(real scalar rc, string scalar msg)
{
    st_local("_sp_rc", strofreal(rc))
    st_local("_sp_err", msg)
    st_local("_nspan", "0")
}

// spanheader("label" #[/#] [\ "label" #[/#] ...]): parse into locals
// _nspan, _sp_lab#, _sp_c1#, _sp_c2#; on a bad specification set _sp_rc
// (198 syntax or overlap, 125 a column outside 1..K) and _sp_err.
void _puttab_span_parse(string scalar spec, real scalar K)
{
    real scalar pos, L, n, c1, c2, j, close
    string scalar ch, lab, rng
    real matrix used

    st_local("_sp_rc", "0")
    st_local("_sp_err", "")
    L = strlen(spec)
    pos = 1
    n = 0
    used = J(1, K, 0)
    while (1) {
        while (pos <= L & substr(spec, pos, 1) == " ") pos++
        if (pos > L) break
        // label: plain or compound double quotes
        ch = substr(spec, pos, 1)
        if (ch == char(34)) {
            close = strpos(substr(spec, pos + 1, .), char(34))
            if (!close) {
                _puttab_span_err(198, "unmatched quote")
                return
            }
            lab = substr(spec, pos + 1, close - 1)
            pos = pos + close + 1
        }
        else if (ch == char(96) & substr(spec, pos + 1, 1) == char(34)) {
            close = strpos(substr(spec, pos + 2, .), char(34) + char(39))
            if (!close) {
                _puttab_span_err(198, "unmatched compound quote")
                return
            }
            lab = substr(spec, pos + 2, close - 1)
            pos = pos + close + 3
        }
        else {
            _puttab_span_err(198, "each span starts with a quoted label")
            return
        }
        if (strtrim(lab) == "") {
            _puttab_span_err(198, "a span label is empty")
            return
        }
        while (pos <= L & substr(spec, pos, 1) == " ") pos++
        rng = ""
        while (pos <= L & substr(spec, pos, 1) != " " & substr(spec, pos, 1) != char(92)) {
            rng = rng + substr(spec, pos, 1)
            pos++
        }
        if (!regexm(rng, "^([0-9]+)(/([0-9]+))?$")) {
            _puttab_span_err(198, "after each label give a column or first/last columns, e.g. 2/3")
            return
        }
        // regexs() of the unmatched "/last" group prints an error line,
        // so split on "/" instead of asking for it.
        c1 = strtoreal(regexs(1))
        c2 = (strpos(rng, "/") ? strtoreal(substr(rng, strpos(rng, "/") + 1, .)) : c1)
        if (c2 < c1) {
            _puttab_span_err(198, "span " + rng + " ends before it starts")
            return
        }
        if (c1 < 1 | c2 > K) {
            _puttab_span_err(125, "span " + rng + " is outside the table (columns 1 to " + strofreal(K) + ")")
            return
        }
        for (j = c1; j <= c2; j++) {
            if (used[j]) {
                _puttab_span_err(198, "spans overlap at column " + strofreal(j))
                return
            }
            used[j] = 1
        }
        n++
        st_local("_sp_lab" + strofreal(n), lab)
        st_local("_sp_c1" + strofreal(n), strofreal(c1))
        st_local("_sp_c2" + strofreal(n), strofreal(c2))
        while (pos <= L & substr(spec, pos, 1) == " ") pos++
        if (pos > L) break
        if (substr(spec, pos, 1) != char(92)) {
            _puttab_span_err(198, "separate spans with " + char(92))
            return
        }
        pos++
    }
    if (n == 0) {
        _puttab_span_err(198, "no span given")
        return
    }
    st_local("_nspan", strofreal(n))
}

// Store text in one cell of a string variable, widening a str# variable
// first (st_sstore() truncates to the storage width; -replace- would widen).
void _puttab_put(real scalar i, string scalar v, string scalar s)
{
    string scalar t
    real scalar w

    t = st_vartype(v)
    if (t != "strL") {
        w = strtoreal(substr(t, 4, .))
        if (strlen(s) > w) {
            if (strlen(s) <= 2045) stata("quietly recast str" + strofreal(strlen(s)) + " " + v)
            else stata("quietly recast strL " + v)
        }
    }
    st_sstore(i, v, s)
}

// blockheader: spans from char c#[tabtools_block] (the block name) and
// c#[tabtools_block_id] (its identity) of the exported columns, in export
// order, posted as spanheader() posts them: _nspan, _sp_lab#, _sp_c1#,
// _sp_c2#. A span is a run of adjacent columns with the same non-empty id
// and the same name; a column whose name is blank (the row-label column, a
// column the caller added) has no span; a named column without an id is a
// span of its own, since equal names are not evidence of one block.
void _puttab_block_spans(string scalar varlist)
{
    string rowvector vars
    string scalar nm, id
    real scalar j, K, n, c1

    vars = tokens(varlist)
    K = cols(vars)
    n = 0
    j = 1
    while (j <= K) {
        nm = strtrim(st_global(vars[j] + "[tabtools_block]"))
        id = st_global(vars[j] + "[tabtools_block_id]")
        if (nm == "") {
            j++
            continue
        }
        c1 = j
        if (id != "") {
            while (j < K) {
                if (st_global(vars[j + 1] + "[tabtools_block_id]") != id) break
                if (strtrim(st_global(vars[j + 1] + "[tabtools_block]")) != nm) break
                j++
            }
        }
        n++
        st_local("_sp_lab" + strofreal(n), nm)
        st_local("_sp_c1" + strofreal(n), strofreal(c1))
        st_local("_sp_c2" + strofreal(n), strofreal(j))
        j++
    }
    st_local("_nspan", strofreal(n))
}

// Footnote paragraphs into locals _n_foot, _fn_p1, ...: the literal token
// " \ " separates paragraphs; text without it is one paragraph as typed.
void _puttab_fn_locals(string scalar s)
{
    string colvector out
    string scalar rest, piece
    real scalar pos, j

    if (!strpos(s, " " + char(92) + " ")) out = s
    else {
        out = J(0, 1, "")
        rest = s
        while ((pos = strpos(rest, " " + char(92) + " ")) > 0) {
            piece = strtrim(substr(rest, 1, pos - 1))
            if (piece != "") out = out \ piece
            rest = substr(rest, pos + 3, .)
        }
        piece = strtrim(rest)
        if (piece != "") out = out \ piece
        if (rows(out) == 0) out = ""
    }
    for (j = 1; j <= rows(out); j++) st_local("_fn_p" + strofreal(j), out[j])
    st_local("_n_foot", strofreal(rows(out)))
}

// Build the table from a Stata matrix (row/col names -> labels/header).
void _puttab_matrix_table(
    string scalar matname,
    real scalar digits,
    real scalar titlerows,
    real scalar headerrows,
    string scalar nfmt)
{
    real matrix M
    string matrix out
    string colvector rnames
    string colvector cnames
    real scalar i, j, R, C, Kout, total, hdr, datatop

    M = st_matrix(matname)
    R = rows(M)
    C = cols(M)
    rnames = _puttab_stripe_names(st_matrixrowstripe(matname))
    cnames = _puttab_stripe_names(st_matrixcolstripe(matname))

    Kout = C + 1
    total = titlerows + headerrows + R
    out = J(total, Kout, "")

    hdr = titlerows + 1
    datatop = titlerows + headerrows + 1

    if (headerrows) {
        for (j = 1; j <= C; j++) {
            out[hdr, j + 1] = cnames[j]
        }
    }
    for (i = 1; i <= R; i++) {
        out[datatop + i - 1, 1] = rnames[i]
    }
    // Format column by column so decimals are consistent within each column.
    for (j = 1; j <= C; j++) {
        out[(datatop..(datatop + R - 1)), j + 1] =
            _puttab_fmt_num(M[., j], digits, "", "", nfmt)
    }

    _puttab_emit_table(out)
}

// smallcells(): an error for the caller to print (rc, message).
void _puttab_sc_fail(real scalar rc, string scalar msg)
{
    st_local("_sc_rc", strofreal(rc))
    st_local("_sc_err", msg)
}

// One call of the _tabtools_smallcells engine on count block X. The flags
// say what is printed: cells (E), row margins (re), column margins (ce),
// the grand total (ge); every count is tested (sensitive), and so is each
// column total when the block has a total row (hast). pm = 1 runs the
// engine's primary mode. Returns the rc; the masks come back in mk (cells),
// rmk (rows), cmk (columns), tmk (grand), with the engine's counts added to
// np and nc.
real scalar _puttab_sc_engine(
    real matrix X,
    real matrix E,
    real scalar re,
    real rowvector ce,
    real scalar ge,
    real scalar hast,
    real scalar k,
    real scalar pm,
    string rowvector tn,
    real matrix mk,
    real colvector rmk,
    real rowvector cmk,
    real scalar tmk,
    real scalar np,
    real scalar nc)
{
    real scalar nr, rc
    string scalar cmd

    nr = rows(X)
    st_matrix(tn[1], X)
    st_matrix(tn[2], E)
    st_matrix(tn[3], J(nr, cols(X), 1))
    st_matrix(tn[4], J(nr, 1, re))
    st_matrix(tn[5], (ce :!= 0))
    st_matrix(tn[6], J(1, cols(X), hast))
    cmd = "_tabtools_smallcells, counts(" + tn[1] + ") exact(" + tn[2] +
        ") sensitive(" + tn[3] + ") rowexact(" + tn[4] + ") rowsensitive(" +
        tn[4] + ") colexact(" + tn[5] + ") colsensitive(" + tn[6] +
        ") grandexact(" + strofreal(ge) + ") grandsensitive(" + strofreal(ge) +
        ") smallcells(" + strofreal(k) + ")" + (pm ? " primary" : "")
    rc = _stata(cmd)
    if (rc) return(rc)
    mk = st_matrix("r(mask)")
    rmk = st_matrix("r(rowmask)")
    cmk = st_matrix("r(colmask)")
    tmk = st_numscalar("r(totalmask)")
    np = np + st_numscalar("r(N_primary_suppressed)")
    nc = nc + st_numscalar("r(N_secondary_suppressed)")
    return(0)
}

// smallcells(): a counts() column -- a single count, a fraction()'s
// numerator or denominator, or a rowtotal() total -- that equals the row
// sum of two or more other columns in every exported row where all are
// nonmissing, and is printed in a row where one of those addends is
// unknown, gives the masked addend back. The addends are the other
// counts() columns and each fraction()'s denom-num (unknown where num,
// denom or it is masked). A declared group wholly among the addends (a
// fraction's num and denom-num, a rowtotal()'s addends) adds up to its
// printed total, so it is unknown only where that total is masked, and the
// declared identity itself (denom = num + denom-num, total = its addends)
// is skipped, as is one that reduces to a single column (a copy). Returns
// the error message, or "" when there is none. Subsets
// are enumerated in full for up to 12 other columns, else pairs and
// triples.
string scalar _puttab_sc_undeclared(
    real matrix C,
    real matrix M,
    real matrix Q,
    string rowvector cv,
    string rowvector fn,
    string rowvector fd,
    string rowvector ra,
    string rowvector rtt,
    real rowvector gtype,
    real matrix gcell,
    real rowvector gnc,
    real rowvector gmarg)
{
    real scalar m, nf, mm, g, c, mo, smax, s, i, q, r, f, jn, jd, h, ngr
    real scalar triv, single
    real rowvector oth, ix, S, inS, mem, gt, used
    real colvector ok, leak, unk
    real matrix X, U, Gm
    string rowvector nm
    string scalar inner, msg, fallback, what

    m = cols(cv)
    nf = cols(fn)
    mm = m + nf
    X = C
    U = (M :> 0)
    nm = cv
    Gm = J(0, mm, 0)
    gt = J(1, 0, .)
    for (f = 1; f <= nf; f++) {
        jn = selectindex(cv :== fn[f])[1]
        jd = selectindex(cv :== fd[f])[1]
        X = X, C[., jd] - C[., jn]
        U = U, ((Q[., f] :+ M[., jn] :+ M[., jd]) :> 0)
        nm = nm, fd[f] + " - " + fn[f]
        Gm = Gm \ J(1, mm, 0)
        Gm[rows(Gm), jn] = 1
        Gm[rows(Gm), m + f] = 1
        gt = gt, jd
    }
    for (g = 1; g <= cols(gtype); g++) {
        if (gtype[g] != 2) continue
        Gm = Gm \ J(1, mm, 0)
        Gm[rows(Gm), gcell[g, (1..gnc[g])]] = J(1, gnc[g], 1)
        gt = gt, gmarg[g]
    }
    ngr = rows(Gm)
    fallback = ""
    for (c = 1; c <= m; c++) {
        oth = select(1..mm, (1..mm) :!= c)
        mo = cols(oth)
        if (mo < 2) continue
        smax = (mo <= 12 ? mo : 3)
        for (s = 2; s <= smax; s++) {
            ix = 1..s
            while (1) {
                S = oth[ix]
                ok = (X[., c] :< .) :& (rowmissing(X[., S]) :== 0)
                if (any(ok)) {
                    if (!any(ok :& (X[., c] :!= rowsum(X[., S])))) {
                        inS = J(1, mm, 0)
                        inS[S] = J(1, s, 1)
                        mem = J(1, mm, 0)
                        used = J(1, 0, .)
                        unk = J(rows(X), 1, 0)
                        triv = 0
                        for (h = 1; h <= ngr; h++) {
                            if (any(Gm[h, .] :& !inS)) continue
                            if (any(Gm[h, .] :& mem)) continue
                            if (gt[h] == c & sum(Gm[h, .]) == s) triv = 1
                            mem = mem :| Gm[h, .]
                            used = used, h
                            unk = unk :| U[., gt[h]]
                        }
                        // terms after the collapse: one left means c equals
                        // a single column, a copy relation, which
                        // _puttab_sc_copies judges (equal fraction()
                        // denominators are allowed there by design)
                        if (!triv & cols(used) + sum(!mem[S]) < 2) triv = 1
                        if (!triv) {
                            for (i = 1; i <= s; i++) {
                                if (!mem[S[i]]) unk = unk :| U[., S[i]]
                            }
                            leak = ok :& (U[., c] :== 0) :& unk
                            if (any(leak)) {
                                r = selectindex(leak)[1]
                                what = ""
                                for (i = 1; i <= s; i++) {
                                    if (!mem[S[i]] & U[r, S[i]]) {
                                        what = nm[S[i]]
                                        break
                                    }
                                }
                                if (what == "") {
                                    for (q = 1; q <= cols(used); q++) {
                                        if (U[r, gt[used[q]]]) {
                                            what = nm[gt[used[q]]]
                                            break
                                        }
                                    }
                                }
                                inner = ""
                                for (i = 1; i <= s; i++) {
                                    if (S[i] > m) inner = nm[S[i]]
                                    else if (anyof(fn, cv[S[i]]) | anyof(fd, cv[S[i]]) |
                                        anyof(ra, cv[S[i]]) | anyof(rtt, cv[S[i]])) inner = cv[S[i]]
                                    if (inner != "") break
                                }
                                single = !(anyof(fn, cv[c]) | anyof(fd, cv[c]) |
                                    anyof(ra, cv[c]) | anyof(rtt, cv[c]))
                                msg = "counts(): " + cv[c] + " equals " +
                                    invtokens(nm[S], " + ") + " in every exported row, " +
                                    "so it gives back the masked " + what +
                                    " in exported row " + strofreal(r) + "; "
                                // a sum that can be declared is reported first
                                if (single & inner == "") return(msg +
                                    "declare the sum in rowtotal() as " + cv[c] +
                                    ": " + invtokens(cv[S]))
                                if (fallback == "") {
                                    if (!single) fallback = msg + cv[c] +
                                        " is already in a fraction() or rowtotal(), " +
                                        "so this sum cannot be declared; leave " +
                                        "an addend out of the table"
                                    else fallback = msg + inner +
                                        " is in a fraction() or another sum, so this " +
                                        "total cannot be declared; leave " + cv[c] +
                                        " out of the table"
                                }
                            }
                        }
                    }
                }
                // next combination of s indices out of mo
                i = s
                while (i >= 1) {
                    if (ix[i] < mo - s + i) break
                    i--
                }
                if (i < 1) break
                ix[i] = ix[i] + 1
                for (q = i + 1; q <= s; q++) ix[q] = ix[q - 1] + 1
            }
        }
    }
    return(fallback)
}

// smallcells(): a totalrow() row alone in its panel (an overall total
// after the panels) is protected as a count of its own, panel by panel.
// When, in some counts() column (or a fraction()'s denom-num), it equals
// the sum over the other panels -- all of them, those before it, or those
// after it, other lone total rows left out -- of each panel's total row
// (or, without one, its rows), and one of those terms is masked, it gives
// a masked count back. Returns the error message, or "" when there is none.
string scalar _puttab_sc_lonetotal(
    real matrix C,
    real matrix M,
    real matrix Q,
    string rowvector cv,
    string rowvector fn,
    string rowvector fd,
    real colvector tr,
    real colvector pid,
    real scalar npan)
{
    real scalar m, nf, f, jn, jd, j, p, q, t, set, tot, any1, n1
    real colvector lone, tpos, idx, tix, dix, val, msk, sel
    real matrix X, U
    string rowvector nm

    m = cols(cv)
    nf = cols(fn)
    X = C
    U = (M :> 0)
    nm = cv
    for (f = 1; f <= nf; f++) {
        jn = selectindex(cv :== fn[f])[1]
        jd = selectindex(cv :== fd[f])[1]
        X = X, C[., jd] - C[., jn]
        U = U, ((Q[., f] :+ M[., jn] :+ M[., jd]) :> 0)
        nm = nm, fd[f] + " - " + fn[f]
    }
    tpos = J(npan, 1, 0)
    for (p = 1; p <= npan; p++) {
        idx = selectindex(pid :== p)
        tix = select(idx, tr[idx])
        if (length(tix)) tpos[p] = tix[1]
    }
    for (j = 1; j <= cols(X); j++) {
        // a panel is lone in column j when its total row is its only row
        // with a value there
        lone = J(npan, 1, 0)
        val = J(npan, 1, 0)
        msk = J(npan, 1, 0)
        for (p = 1; p <= npan; p++) {
            idx = selectindex(pid :== p)
            dix = select(idx, (!tr[idx]) :& (X[idx, j] :< .))
            t = tpos[p]
            if (t) {
                if (X[t, j] >= .) t = 0
            }
            if (t & !length(dix)) lone[p] = 1
            if (t) {
                val[p] = X[t, j]
                msk[p] = U[t, j]
            }
            else if (length(dix)) {
                val[p] = sum(X[dix, j])
                msk[p] = any(U[dix, j])
            }
        }
        for (p = 1; p <= npan; p++) {
            if (!lone[p]) continue
            for (set = 1; set <= 3; set++) {
                sel = (!lone) :& ((1::npan) :!= p)
                if (set == 2) sel = sel :& ((1::npan) :< p)
                if (set == 3) sel = sel :& ((1::npan) :> p)
                n1 = sum(sel)
                if (n1 < 1) continue
                tot = sum(select(val, sel))
                any1 = any(select(msk, sel))
                if (tot == val[p] & any1) {
                    return("totalrow(): the total row in exported row " +
                        strofreal(tpos[p]) + " is alone in its panel and equals " +
                        "the sum of the other panels' " + nm[j] + ", one of which " +
                        "is masked, so it gives a masked count back; puttab " +
                        "protects each panel on its own and cannot certify masks " +
                        "across panels: leave that row out of the table")
                }
            }
        }
    }
    return("")
}

// smallcells(): a counts() column outside fraction() that equals another
// counts() column, or a fraction()'s denom-num, in every exported row
// where both are nonmissing is a copy of it: printed in a row where the
// other is masked,
// it gives the masked count back (a copy is a separate count to the
// engine, so its own mask does not follow the original's). Returns the
// error message, or "" when there is none. Q holds the denom-num masks;
// a copy of denom-num counts as masked where num, denom or it is masked.
string scalar _puttab_sc_copies(
    real matrix C,
    real matrix M,
    real matrix Q,
    string rowvector cv,
    string rowvector fn,
    string rowvector fd)
{
    real scalar m, nf, c, d, r, jn, jd
    real colvector ok, leak, dv, dm
    string scalar dname

    m = cols(cv)
    nf = cols(fn)
    for (c = 1; c <= m; c++) {
        // a fraction() member is not taken for a copy: two denominators
        // (or numerators) may agree in every row by design
        if (anyof(fn, cv[c]) | anyof(fd, cv[c])) continue
        for (d = 1; d <= m + nf; d++) {
            if (d == c) continue
            if (d <= m) {
                dv = C[., d]
                dm = M[., d]
                dname = cv[d]
            }
            else {
                jn = selectindex(cv :== fn[d - m])[1]
                jd = selectindex(cv :== fd[d - m])[1]
                dv = C[., jd] - C[., jn]
                // denom-num is never printed, so the engine treats it as
                // unknown: printing it gives back a masked num or denom
                dm = Q[., d - m] :+ M[., jn] :+ M[., jd]
                dname = fd[d - m] + " - " + fn[d - m]
            }
            ok = (C[., c] :< .) :& (dv :< .)
            if (!any(ok)) continue
            if (any(ok :& (C[., c] :!= dv))) continue
            leak = ok :& (M[., c] :== 0) :& (dm :> 0)
            if (!any(leak)) continue
            r = selectindex(leak)[1]
            return("counts(): " + cv[c] + " equals " + dname +
                " in every exported row, so it gives back the masked " +
                (d <= m ? dname : fn[d - m] + "/" + fd[d - m]) +
                " in exported row " + strofreal(r) +
                "; a copy of a count is masked as a count of its own, not " +
                "with the original, so leave " + cv[c] + " out of the table")
        }
    }
    return("")
}

// smallcells() for puttab. The counts() columns form disjoint groups:
//   fraction(num/den)      cells num and den-num, row margin den (printed
//                          as num/den in the numerator's column; den-num is
//                          never printed but follows from the two)
//   rowtotal(tot: adds)    cells adds, row margin tot (one group per sum)
//   any other count        a single cell per row
// Within a panel (panel(), else the whole table) a totalrow() row gives the
// column margins and, for the first two kinds, the grand total. A group's
// row is in the block when all its values are nonmissing; partly missing
// is an error, and so is any identity that the declared margins do not
// satisfy. Without column margins rows are independent, so each row is
// its own block (a single-cell group: one primary-mode call, which is exact
// when nothing is margined). Masks are 0 printed, 1 small, 2 complementary.
// Posts _sc_ovr (column / rendered text variable pairs), _sc_np, _sc_nc,
// or _sc_rc and _sc_err.
void _puttab_sc_run(
    string scalar cvars,
    string scalar fnums,
    string scalar fdens,
    string scalar rttot,
    string scalar rtadds,
    string scalar wspec,
    string scalar trvar,
    string scalar pvar,
    string scalar printed,
    real scalar k,
    real scalar prim,
    string scalar lt,
    string scalar ge,
    real scalar digits,
    string scalar nfmt,
    string scalar tnames,
    string scalar pool)
{
    string rowvector cv, fn, fd, ra, rtt, rap, pr, tn, wc, pieces, gv, pl
    string colvector ps, s, s2, txt
    string scalar ovr, nm, piece, v
    real matrix C, M, Q, V, X, E, mk, gcell
    real colvector tr, pid, pres, nm2, idx, tix, bix, B, rmk, trig, pc, bad
    real rowvector cmk, cells, ce, gtype, gmarg, gfr, gnc
    real scalar n, m, nf, ng, g, j, jj, f, p, npan, t, r, rc, np, nc
    real scalar tmk, hast, ty, jn, jd, jt, w, nw, pos, isnum, i, re, gE, pm
    real scalar lim, ff
    string scalar umsg

    st_local("_sc_rc", "0")
    st_local("_sc_err", "")
    cv = tokens(cvars)
    fn = tokens(fnums)
    fd = tokens(fdens)
    rtt = tokens(rttot)
    ra = tokens(subinstr(rtadds, ";", " "))
    rap = J(1, 0, "")
    pieces = tokens(rtadds, ";")
    for (i = 1; i <= cols(pieces); i++) {
        if (pieces[i] != ";") rap = rap, pieces[i]
    }
    pr = tokens(printed)
    tn = tokens(tnames)
    pl = tokens(pool)
    m = cols(cv)
    nf = cols(fn)
    n = st_nobs()
    C = st_data(., cv)
    np = 0
    nc = 0

    for (j = 1; j <= m; j++) {
        bad = selectindex((C[., j] :< .) :& ((C[., j] :< 0) :| (C[., j] :!= floor(C[., j]))))
        if (length(bad)) {
            _puttab_sc_fail(459, "counts(): " + cv[j] + " is " +
                strofreal(C[bad[1], j]) + " in exported row " + strofreal(bad[1]) +
                "; counts must be nonnegative integers")
            return
        }
    }

    // panels and total rows
    tr = (trvar != "" ? (st_data(., trvar) :!= 0) : J(n, 1, 0))
    if (trvar != "" & !any(tr)) {
        _puttab_sc_fail(459, "totalrow(): no exported row is a total row")
        return
    }
    pid = J(n, 1, 1)
    if (pvar != "") {
        if (st_isstrvar(pvar)) {
            ps = st_sdata(., pvar)
            for (i = 2; i <= n; i++) pid[i] = pid[i - 1] + (ps[i] != ps[i - 1])
        }
        else {
            pc = st_data(., pvar)
            for (i = 2; i <= n; i++) pid[i] = pid[i - 1] + (pc[i] != pc[i - 1])
        }
    }
    npan = pid[n]
    for (p = 1; p <= npan; p++) {
        if (sum(tr :& (pid :== p)) > 1) {
            idx = selectindex(pid :== p)
            _puttab_sc_fail(459, "totalrow(): the panel that starts at exported row " +
                strofreal(idx[1]) + " has more than one total row")
            return
        }
    }

    // groups: gtype 1 fraction, 2 rowtotal, 3 single count
    gtype = J(1, 0, .)
    gmarg = J(1, 0, .)
    gfr = J(1, 0, .)
    gnc = J(1, 0, .)
    gcell = J(0, m, 0)
    for (f = 1; f <= nf; f++) {
        gtype = gtype, 1
        gcell = gcell \ (selectindex(cv :== fn[f])[1], J(1, m - 1, 0))
        gnc = gnc, 1
        gmarg = gmarg, selectindex(cv :== fd[f])[1]
        gfr = gfr, f
    }
    for (r = 1; r <= cols(rtt); r++) {
        gtype = gtype, 2
        wc = tokens(rap[r])
        cells = J(1, m, 0)
        for (j = 1; j <= cols(wc); j++) cells[j] = selectindex(cv :== wc[j])[1]
        gcell = gcell \ cells
        gnc = gnc, cols(wc)
        gmarg = gmarg, selectindex(cv :== rtt[r])[1]
        gfr = gfr, 0
    }
    for (j = 1; j <= m; j++) {
        if (anyof(fn, cv[j]) | anyof(fd, cv[j]) | anyof(ra, cv[j]) | anyof(rtt, cv[j])) continue
        gtype = gtype, 3
        gcell = gcell \ (j, J(1, m - 1, 0))
        gnc = gnc, 1
        gmarg = gmarg, 0
        gfr = gfr, 0
    }
    ng = cols(gtype)

    M = J(n, m, 0)
    Q = J(n, max((nf, 1)), 0)
    for (g = 1; g <= ng; g++) {
        ty = gtype[g]
        cells = gcell[g, (1..gnc[g])]
        jn = cells[1]
        jd = gmarg[g]
        f = gfr[g]
        gv = cv[cells]
        if (jd) gv = gv, cv[jd]
        V = C[., cells]
        if (jd) V = V, C[., jd]
        nm2 = rowmissing(V)
        bad = selectindex((nm2 :> 0) :& (nm2 :< cols(V)))
        if (length(bad)) {
            _puttab_sc_fail(416, "counts(): in exported row " + strofreal(bad[1]) +
                " some but not all of " + invtokens(gv) + " are missing")
            return
        }
        pres = (nm2 :== 0)
        if (ty == 1) {
            bad = selectindex(pres :& (C[., jn] :> C[., jd]))
            if (length(bad)) {
                _puttab_sc_fail(459, "fraction(): " + cv[jn] + " exceeds " +
                    cv[jd] + " in exported row " + strofreal(bad[1]))
                return
            }
            X = C[., jn], C[., jd] - C[., jn]
        }
        else X = C[., cells]
        if (ty == 2) {
            bad = selectindex(pres :& (rowsum(X) :!= C[., jd]))
            if (length(bad)) {
                _puttab_sc_fail(459, "rowtotal(): in exported row " + strofreal(bad[1]) +
                    " " + invtokens(cv[cells], " + ") + " does not equal " + cv[jd])
                return
            }
        }
        for (p = 1; p <= npan; p++) {
            idx = selectindex(pid :== p)
            tix = select(idx, tr[idx])
            bix = select(idx, (!tr[idx]) :& pres[idx])
            t = 0
            if (length(tix)) {
                if (pres[tix[1]]) t = tix[1]
            }
            if (t & !length(bix)) {
                bix = t
                t = 0
            }
            if (t) {
                bad = selectindex(colsum(V[bix, .]) :!= V[t, .])
                if (length(bad)) {
                    _puttab_sc_fail(459, "totalrow(): in the panel that starts at exported row " +
                        strofreal(idx[1]) + " the rows do not add up to the total row in " +
                        gv[bad[1]])
                    return
                }
            }
            if (!k | !length(bix)) continue
            hast = (t > 0)
            // blocks: the panel when it has column margins; else each row
            // (or, for a single count, all rows at once)
            nw = (hast | ty == 3 ? 1 : length(bix))
            for (w = 1; w <= nw; w++) {
                B = (nw == 1 ? bix : bix[w])
                if (!any((X[B, .] :> 0) :& (X[B, .] :< k))) continue
                E = J(rows(B), cols(X), 1)
                ce = J(1, cols(X), hast)
                if (ty == 1 & !prim) {
                    // den-num is never printed: the engine derives it from
                    // num and den (still testing it), and its column total
                    // from the total row's num and den
                    E[., 2] = J(rows(B), 1, 0)
                    ce[2] = 0
                }
                re = (ty != 3)
                gE = (hast & ty != 3)
                pm = prim | (ty == 3 & !hast)
                // the exact check behind complementary masking with a total
                // row grows steeply with the block (measured: rowtotal()
                // with 3 addends, 20 rows 9 s, 30 rows 72 s; one count, 100
                // rows 8-14 s, 200 rows 160 s), so refuse a block that
                // would appear to hang
                lim = (ty == 2 ? rows(B) * cols(X) : rows(B))
                if (hast & !pm & lim > 60) {
                    _puttab_sc_fail(459, "smallcells(): the panel that starts at exported row " +
                        strofreal(idx[1]) + " has " + strofreal(rows(B)) +
                        " rows above its total row" + (ty == 2 ? " and " +
                        strofreal(cols(X)) + " rowtotal() addends" : "") +
                        "; complementary masking with a total row is limited to " +
                        (ty == 2 ? "60 cells (rows times addends) for each rowtotal() sum" :
                        "60 rows") + " in a panel; split the table into panels with " +
                        "panel(), each with its own total row")
                    return
                }
                mk = J(0, 0, .)
                rmk = J(0, 1, .)
                cmk = J(1, 0, .)
                tmk = 0
                rc = _puttab_sc_engine(X[B, .], E, re, ce, gE, hast, k, pm, tn,
                    mk, rmk, cmk, tmk, np, nc)
                if (rc) {
                    st_local("_sc_rc", strofreal(rc))
                    return
                }
                for (r = 1; r <= rows(B); r++) {
                    for (jj = 1; jj <= gnc[g]; jj++) {
                        if (ty == 1) {
                            M[B[r], jn] = mk[r, 1]
                            Q[B[r], f] = mk[r, 2]
                        }
                        else M[B[r], cells[jj]] = mk[r, jj]
                    }
                    if (jd) M[B[r], jd] = rmk[r]
                }
                if (hast) {
                    if (ty == 1) {
                        M[t, jn] = cmk[1]
                        Q[t, f] = cmk[2]
                    }
                    else {
                        for (jj = 1; jj <= gnc[g]; jj++) M[t, cells[jj]] = cmk[jj]
                    }
                    if (jd) M[t, jd] = tmk
                }
            }
        }
    }

    // primary mode: a small den-num with num and den printed would be
    // given back by the fraction, so num is shown as >=k (it is k or more,
    // since den is printed and den-num is below k). Full mode never leaves
    // this case; the rule is a guard there.
    for (f = 1; f <= nf; f++) {
        jn = selectindex(cv :== fn[f])[1]
        jd = selectindex(cv :== fd[f])[1]
        bad = selectindex((M[., jn] :== 0) :& (Q[., f] :> 0) :& (M[., jd] :== 0))
        if (length(bad)) M[bad, jn] = J(length(bad), 1, 2)
    }

    // a printed count that copies a masked count (or a fraction's
    // denom-num), or is an undeclared exact sum of other counts, gives a
    // masked count back: refuse it (full mode only; primary mode protects
    // printed counts alone, by request)
    if (k & !prim) {
        if (trvar != "" & npan > 1) {
            umsg = _puttab_sc_lonetotal(C, M, Q, cv, fn, fd, tr, pid, npan)
            if (umsg != "") {
                _puttab_sc_fail(459, umsg)
                return
            }
        }
        umsg = _puttab_sc_copies(C, M, Q, cv, fn, fd)
        if (umsg != "") {
            _puttab_sc_fail(459, umsg)
            return
        }
        umsg = _puttab_sc_undeclared(C, M, Q, cv, fn, fd, ra, rtt, gtype,
            gcell, gnc, gmarg)
        if (umsg != "") {
            _puttab_sc_fail(459, umsg)
            return
        }
    }

    // rendered text: every printed count, fraction and withheld column
    ovr = ""
    for (i = 1; i <= cols(pr); i++) {
        v = pr[i]
        j = (anyof(cv, v) ? selectindex(cv :== v)[1] : 0)
        f = (anyof(fn, v) ? selectindex(fn :== v)[1] : 0)
        // the withhold() keys that list this column
        trig = J(n, 1, 0)
        isnum = 0
        pieces = tokens(wspec, char(92))
        for (w = 1; w <= cols(pieces); w++) {
            piece = strtrim(pieces[w])
            if (piece == char(92) | piece == "") continue
            pos = strpos(piece, ":")
            nm = strtrim(substr(piece, 1, pos - 1))
            wc = tokens(substr(piece, pos + 1, .))
            if (!anyof(wc, v)) continue
            isnum = 1
            jj = selectindex(cv :== nm)[1]
            trig = trig :| (M[., jj] :> 0)
            // a fraction()'s numerator or denominator key covers the whole
            // fraction: num, denom-num and denom
            ff = (anyof(fn, nm) ? selectindex(fn :== nm)[1] :
                (anyof(fd, nm) ? selectindex(fd :== nm)[1] : 0))
            if (ff) trig = trig :| (Q[., ff] :> 0) :|
                (M[., selectindex(cv :== fn[ff])[1]] :> 0) :|
                (M[., selectindex(cv :== fd[ff])[1]] :> 0)
        }
        if (!j & !isnum) continue
        if (f) {
            jd = selectindex(cv :== fd[f])[1]
            s = _puttab_sc_text(C[., j], M[., j], v, digits, nfmt, lt, ge)
            s2 = _puttab_sc_text(C[., jd], M[., jd], fd[f], digits, nfmt, lt, ge)
            txt = J(n, 1, "")
            for (r = 1; r <= n; r++) {
                if (C[r, j] < . & C[r, jd] < .) txt[r] = s[r] + "/" + s2[r]
            }
        }
        else if (j) txt = _puttab_sc_text(C[., j], M[., j], v, digits, nfmt, lt, ge)
        else if (st_isstrvar(v)) txt = st_sdata(., v)
        else txt = _puttab_fmt_num(st_data(., v), digits, st_varvaluelabel(v),
            st_varformat(v), nfmt)
        if (any(trig)) txt[selectindex(trig)] = J(sum(trig), 1, "")
        nm = pl[i]
        (void) st_addvar("strL", nm)
        st_sstore(., nm, txt)
        ovr = ovr + " " + v + " " + nm
    }
    st_local("_sc_ovr", strtrim(ovr))
    st_local("_sc_np", strofreal(np))
    st_local("_sc_nc", strofreal(nc))
}

// A count column as printed: formatted as puttab formats any numeric
// column, with a masked cell shown as <k (1) or >=k (2).
string colvector _puttab_sc_text(
    real colvector x,
    real colvector mk,
    string scalar v,
    real scalar digits,
    string scalar nfmt,
    string scalar lt,
    string scalar ge)
{
    string colvector out

    out = _puttab_fmt_num(x, digits, st_varvaluelabel(v), st_varformat(v), nfmt)
    if (any(mk :== 1)) out[selectindex(mk :== 1)] = J(sum(mk :== 1), 1, lt)
    if (any(mk :== 2)) out[selectindex(mk :== 2)] = J(sum(mk :== 2), 1, ge)
    return(out)
}

end
mata: mata set matastrict `_tt_ms0'

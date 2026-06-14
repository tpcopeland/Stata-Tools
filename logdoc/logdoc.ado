*! logdoc Version 1.1.0  2026/06/14
*! Convert Stata SMCL/log files to faithful HTML, Markdown, Word, LaTeX, Quarto, or PDF documents
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Syntax:
  logdoc using filename, output(string) [format(string) theme(string)
      title(string) date(string) run preformatted nofold nodots
      fold highlight tables copy download legacy generated
      python(string) css(string) accent(string) open replace quiet verbose
      footer(string) stamp nograph graphwidth(string) graphheight(string)]

  logdoc start, output(string) [format(string) theme(string) ...]
  logdoc stop
  logdoc combine using file1 file2 ..., output(string) [format(string) ...]

Description:
  Converts Stata .smcl, .log, or .do files into self-contained HTML
  or Markdown documents with faithful Stata rendering, opt-in
  enhancements, and embedded graphs.

See help logdoc for complete documentation
*/


* ---------------------------------------------------------------------------
* Main dispatcher: route subcommands or default to convert
* ---------------------------------------------------------------------------

capture program drop logdoc
program define logdoc, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    gettoken subcmd rest : 0, parse(" ,")

    if inlist("`subcmd'", "start", "stop", "diff", "batch", "replay", "combine") {
        _logdoc_`subcmd' `rest'
    }
    else {
        _logdoc_convert `0'
    }

    local _r_scalars : r(scalars)
    local _r_macros : r(macros)
    foreach _r_name of local _r_scalars {
        local _r_scalar_`_r_name' = r(`_r_name')
    }
    foreach _r_name of local _r_macros {
        local _r_macro_`_r_name' `"`r(`_r_name')'"'
    }

    return add

    if strpos(" `_r_scalars' ", " nblocks ") {
        return scalar nblocks = `_r_scalar_nblocks'
    }
    if strpos(" `_r_scalars' ", " filesize ") {
        return scalar filesize = `_r_scalar_filesize'
    }
    if strpos(" `_r_scalars' ", " ngraphs ") {
        return scalar ngraphs = `_r_scalar_ngraphs'
    }
    if strpos(" `_r_scalars' ", " ntables ") {
        return scalar ntables = `_r_scalar_ntables'
    }
    if strpos(" `_r_scalars' ", " nwarnings ") {
        return scalar nwarnings = `_r_scalar_nwarnings'
    }
    if strpos(" `_r_scalars' ", " n_sources ") {
        return scalar n_sources = `_r_scalar_n_sources'
    }
    if strpos(" `_r_scalars' ", " n_files ") {
        return scalar n_files = `_r_scalar_n_files'
    }
    if strpos(" `_r_scalars' ", " n_failed ") {
        return scalar n_failed = `_r_scalar_n_failed'
    }

    if strpos(" `_r_macros' ", " output ") {
        return local output `"`_r_macro_output'"'
    }
    if strpos(" `_r_macros' ", " input ") {
        return local input `"`_r_macro_input'"'
    }
    if strpos(" `_r_macros' ", " format ") {
        return local format `"`_r_macro_format'"'
    }
    if strpos(" `_r_macros' ", " theme ") {
        return local theme `"`_r_macro_theme'"'
    }
    if strpos(" `_r_macros' ", " accent ") {
        return local accent `"`_r_macro_accent'"'
    }
    if strpos(" `_r_macros' ", " secondary ") {
        return local secondary `"`_r_macro_secondary'"'
    }
    if strpos(" `_r_macros' ", " compare ") {
        return local compare `"`_r_macro_compare'"'
    }

    } // end capture noisily

    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* _logdoc_convert: the existing conversion logic (was the logdoc body)
* ---------------------------------------------------------------------------

capture program drop _logdoc_convert
program define _logdoc_convert, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax using/ , OUTput(string) [Format(string) THeme(string) ///
        TItle(string) DATe(string) RUN PREformatted NOFold NODots ///
        PYthon(string) CSS(string) OPEN REPlace Quiet Verbose ///
        FOOTer(string) STamp NOGraph GRAPHWidth(string) GRAPHHeight(string) ///
        LINEnumbers TOC KEEP(string) DROP(string) ///
        APPend NOTEbook EMAil ANNotate(string) STATAexe(string) ///
        ACCent(string) FOLD HIGHlight TABles COPY DOWNload LEGacy GENerated]

    * --- U3: quiet/verbose mutual exclusion ---
    if "`quiet'" != "" & "`verbose'" != "" {
        display as error "quiet and verbose are mutually exclusive"
        exit 198
    }

    * --- W4: Read global and project .logdocrc config files ---
    local _config_keys "format theme title date python css footer stamp"
    local _config_keys "`_config_keys' nograph graphwidth graphheight"
    local _config_keys "`_config_keys' linenumbers toc keep drop append"
    local _config_keys "`_config_keys' notebook email annotate accent"
    local _config_keys "`_config_keys' preformatted nofold nodots run"
    local _config_keys "`_config_keys' open replace quiet verbose fold"
    local _config_keys "`_config_keys' highlight tables copy download"
    local _config_keys "`_config_keys' legacy generated stataexe"
    foreach _cfgkey of local _config_keys {
        local _user_`_cfgkey' `"``_cfgkey''"'
    }

    local _config_python ""
    local _config_files ""
    local _home : environment HOME
    if `"`_home'"' != "" {
        capture confirm file `"`_home'/.logdocrc"'
        if !_rc {
            local _config_files `"`_config_files' `"`_home'/.logdocrc"'"'
        }
    }
    capture confirm file ".logdocrc"
    if !_rc {
        local _config_files `"`_config_files' `".logdocrc"'"'
    }
    foreach _config_file of local _config_files {
        tempname rcfh
        file open `rcfh' using `"`_config_file'"', read text
        file read `rcfh' _rcline
        while r(eof) == 0 {
            local _rcline_trim = strtrim(`"`_rcline'"')
            if regexm(`"`_rcline_trim'"', "^([A-Za-z][A-Za-z0-9_]*)=(.*)$") {
                local _rckey = lower(regexs(1))
                local _rcval = regexs(2)
                local _user_value `"`_user_`_rckey''"'
                if `"`_user_value'"' == "" {
                    if "`_rckey'" == "python" {
                        local _config_python `"`_rcval'"'
                    }
                    else {
                        local `_rckey' `"`_rcval'"'
                    }
                }
            }
            file read `rcfh' _rcline
        }
        file close `rcfh'
    }

    * --- U1: Auto-detect format from output file extension ---
    if "`format'" == "" {
        local _outext = lower(substr("`output'", -3, .))
        local _outext4 = lower(substr("`output'", -4, .))
        local _outext5 = lower(substr("`output'", -5, .))
        if "`_outext'" == ".md" local format "md"
        if "`_outext4'" == ".tex" local format "tex"
        if "`_outext4'" == ".pdf" local format "pdf"
        if "`_outext4'" == ".qmd" local format "qmd"
        if "`_outext5'" == ".docx" local format "docx"
    }
    * Default format if not specified and not auto-detected
    if "`format'" == "" local format "html"
    if "`theme'" == "" local theme "light"

    * Validate format
    if !inlist("`format'", "html", "md", "both", "docx", "pdf", "tex", "qmd") {
        display as error "format() must be html, md, both, docx, pdf, tex, or qmd"
        exit 198
    }

    if "`append'" != "" & inlist("`format'", "docx", "pdf") {
        display as error "append is not supported with format(docx) or format(pdf)"
        exit 198
    }

    * --- F2: format(docx) requires Stata 17+ ---
    if "`format'" == "docx" {
        if c(stata_version) < 17 {
            display as error "format(docx) requires Stata 17+"
            exit 198
        }
    }

    * Validate theme
    if !inlist("`theme'", "light", "dark") {
        display as error "theme() must be light or dark"
        exit 198
    }

    if "`accent'" != "" {
        if !regexm("`accent'", ///
            "^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") {
            display as error "accent() must be a #RRGGBB color"
            exit 198
        }
    }

    if "`graphwidth'" != "" {
        local _graphwidth_num = real("`graphwidth'")
        if missing(`_graphwidth_num') | `_graphwidth_num' <= 0 | ///
            `_graphwidth_num' != floor(`_graphwidth_num') {
            display as error "graphwidth() must be a positive integer"
            exit 198
        }
    }
    if "`graphheight'" != "" {
        local _graphheight_num = real("`graphheight'")
        if missing(`_graphheight_num') | `_graphheight_num' <= 0 | ///
            `_graphheight_num' != floor(`_graphheight_num') {
            display as error "graphheight() must be a positive integer"
            exit 198
        }
    }

    * --- C7: Validate annotation file ---
    if "`annotate'" != "" {
        capture confirm file "`annotate'"
        if _rc {
            display as error `"annotation file "`annotate'" not found"'
            exit 601
        }
    }

    * --- F8: Validate custom CSS file ---
    if "`css'" != "" {
        capture confirm file "`css'"
        if _rc {
            display as error `"CSS file "`css'" not found"'
            exit 601
        }
    }

    * Check input file
    local input_file "`using'"
    local _runwrapper_was_input 0

    * Handle .do files with run option
    if "`run'" != "" {
        * --- U6: Auto-replace when run is specified ---
        local replace "replace"

        * Verify input is a .do file
        local ext = lower(substr("`input_file'", -3, .))
        if "`ext'" != ".do" {
            display as error "run option requires a .do file as input"
            exit 198
        }
        capture confirm file "`input_file'"
        if _rc {
            display as error `"file "`input_file'" not found"'
            exit 601
        }

        * Execute the .do file in batch mode.  Stata writes output using the
        * child session's linesize, so inject the maximum before the do-file.
        if "`quiet'" == "" {
            display as text "Running: `input_file'"
        }
        tempfile _runwrapper
        tempname _runfh
        local _runwrapslash = strrpos("`_runwrapper'", "/")
        if `_runwrapslash' == 0 {
            local _runwrapslash = strrpos("`_runwrapper'", "\")
        }
        if `_runwrapslash' > 0 {
            local _runwrapdir = substr("`_runwrapper'", 1, `_runwrapslash')
            local _runwrapname = substr("`_runwrapper'", `_runwrapslash' + 1, .)
            local _runwrapname = subinstr("`_runwrapname'", ".", "_", .)
            local _runwrapper_base "`_runwrapdir'`_runwrapname'"
        }
        else {
            local _runwrapper_base = subinstr("`_runwrapper'", ".", "_", .)
        }
        local _runwrapper_path "`_runwrapper_base'.do"
        local _runlog_path "`_runwrapper_base'.smcl"
        file open `_runfh' using "`_runwrapper_path'", write text replace
        file write `_runfh' "version 16.0" _n
        file write `_runfh' "capture log close _logdoc_run" _n
        file write `_runfh' `"log using "`_runlog_path'", replace smcl name(_logdoc_run) nomsg"' _n
        file write `_runfh' "quietly set linesize 255" _n
        file write `_runfh' `"do "`input_file'""' _n
        file write `_runfh' "capture log close _logdoc_run" _n
        file close `_runfh'

        * Derive the batch Stata executable for the child session.  A
        * hardcoded "stata-mp" excludes SE/BE and Windows users; pick the
        * binary that matches the running flavor and OS.  stataexe() lets a
        * user with a nonstandard install name or off-PATH binary override.
        if `"`stataexe'"' != "" {
            * Allowlist legal executable-name/path characters (letters,
            * digits, dot, underscore, hyphen, slash, backslash, colon,
            * space).  Anything else -- shell metacharacters, quotes --
            * is rejected before the value reaches `shell'.
            if regexm(`"`stataexe'"', "[^A-Za-z0-9._/\: -]") {
                display as error "stataexe() contains illegal characters"
                exit 198
            }
            local _stataexe `"`stataexe'"'
        }
        else if "`c(os)'" == "Windows" {
            if c(MP)       local _stataexe "StataMP-64"
            else if c(SE)  local _stataexe "StataSE-64"
            else           local _stataexe "Stata-64"
        }
        else {
            if c(MP)       local _stataexe "stata-mp"
            else if c(SE)  local _stataexe "stata-se"
            else           local _stataexe "stata"
        }
        shell `_stataexe' -b do "`_runwrapper_path'"
        capture erase "`_runwrapper_path'"

        capture confirm file "`_runlog_path'"
        if _rc {
            display as error "no log file produced from running `using'"
            display as error "expected wrapper log: `_runlog_path'"
            exit 601
        }
        local input_file "`_runlog_path'"
        local _runwrapper_was_input 1
        if "`quiet'" == "" {
            display as text "Log captured: `input_file'"
        }
    }
    else {
        * Check input exists
        capture confirm file "`input_file'"
        if _rc {
            display as error `"file "`input_file'" not found"'
            exit 601
        }
    }

    * Check replace / output exists
    * append() is allowed to target an existing file without replace.
    if "`append'" == "" & "`replace'" == "" {
        capture confirm file "`output'"
        if !_rc {
            display as error `"file "`output'" already exists; use replace option"'
            exit 602
        }
        * Also check secondary file for format(both)
        if "`format'" == "both" {
            local _primary ""
            local _secondary ""
            _logdoc_both_paths, output("`output'") ///
                primary(_primary) secondary(_secondary)
            capture confirm file "`_primary'"
            if !_rc {
                display as error `"file "`_primary'" already exists; use replace option"'
                exit 602
            }
            capture confirm file "`_secondary'"
            if !_rc {
                display as error `"file "`_secondary'" already exists; use replace option"'
                exit 602
            }
        }
    }

    * Find Python executable
    if "`python'" == "" {
        _logdoc_resolve_python, result(python) configpython(`"`_config_python'"')
    }

    * --- R4 + R6: Validate Python installation and version ---
    _logdoc_check_python "`python'"

    * Find logdoc_render.py
    local scriptpath ""
    _logdoc_find_script, result(scriptpath)
    if "`scriptpath'" == "" {
        display as error "logdoc_render.py not found"
        display as error "ensure logdoc is properly installed"
        exit 601
    }

    * Find CSS files (expand ~ like _logdoc_find_script does)
    local light_css ""
    local dark_css ""
    _logdoc_find_css, light(light_css) dark(dark_css)

    * Build command (quote python path for paths with spaces)
    local cmd `""`python'" "`scriptpath'" "`input_file'" "`output'""'
    local cmd `"`cmd' --format `format'"'
    local cmd `"`cmd' --theme `theme'"'

    if "`title'" != "" {
        * Write title to tempfile to avoid shell quoting issues
        tempfile titlefile
        _logdoc_write_argfile, path("`titlefile'") text(`"`title'"')
        local cmd `"`cmd' --title-file "`titlefile'""'
    }

    if "`preformatted'" != "" {
        local cmd `"`cmd' --preformatted"'
    }

    if "`nofold'" != "" {
        local cmd `"`cmd' --nofold"'
    }

    if "`nodots'" != "" {
        local cmd `"`cmd' --nodots"'
    }

    if "`fold'" != "" {
        local cmd `"`cmd' --fold"'
    }
    if "`highlight'" != "" {
        local cmd `"`cmd' --highlight"'
    }
    if "`tables'" != "" {
        local cmd `"`cmd' --tables"'
    }
    if "`copy'" != "" {
        local cmd `"`cmd' --copy"'
    }
    if "`download'" != "" {
        local cmd `"`cmd' --download"'
    }
    if "`legacy'" != "" {
        local cmd `"`cmd' --legacy"'
    }

    if "`date'" != "" {
        * Write date to tempfile to avoid shell quoting issues
        tempfile datefile
        _logdoc_write_argfile, path("`datefile'") text(`"`date'"')
        local cmd `"`cmd' --date-file "`datefile'""'
    }

    * --- F8: Custom CSS passthrough ---
    if "`css'" != "" {
        local cmd `"`cmd' --css "`css'""'
    }
    else {
        if "`light_css'" != "" {
            local cmd `"`cmd' --light-css "`light_css'""'
        }
        if "`dark_css'" != "" {
            local cmd `"`cmd' --dark-css "`dark_css'""'
        }
    }
    if "`accent'" != "" {
        local cmd `"`cmd' --accent "`accent'""'
    }

    * --- U3: Verbose flag ---
    if "`verbose'" != "" {
        local cmd `"`cmd' --verbose"'
    }

    * --- O8: Footer ---
    if `"`footer'"' != "" {
        tempfile footerfile
        _logdoc_write_argfile, path("`footerfile'") text(`"`footer'"')
        local cmd `"`cmd' --footer-file "`footerfile'""'
    }
    if "`generated'" != "" {
        local cmd `"`cmd' --generated"'
    }

    * --- C4: Stamp ---
    if "`stamp'" != "" {
        local _stamp_str ///
            "Stata `c(stata_version)' `c(edition_real)' | `c(current_date)' `c(current_time)'"
        if `"`c(filename)'"' != "" {
            local _stamp_str `"`_stamp_str' | `c(filename)'"'
        }
        tempfile stampfile
        _logdoc_write_argfile, path("`stampfile'") text(`"`_stamp_str'"')
        local cmd `"`cmd' --stamp-file "`stampfile'""'
    }

    * --- P1: Nograph ---
    if "`nograph'" != "" {
        local cmd `"`cmd' --nograph"'
    }

    * --- O4: Graph dimensions ---
    if "`graphwidth'" != "" {
        local cmd `"`cmd' --graphwidth `graphwidth'"'
    }
    if "`graphheight'" != "" {
        local cmd `"`cmd' --graphheight `graphheight'"'
    }

    * --- O2: Line numbers ---
    if "`linenumbers'" != "" {
        local cmd `"`cmd' --linenumbers"'
    }

    * --- F3: Table of contents ---
    if "`toc'" != "" {
        local cmd `"`cmd' --toc"'
    }

    * --- F6: Keep/drop patterns ---
    if `"`keep'"' != "" {
        tempfile keepfile
        _logdoc_write_argfile, path("`keepfile'") text(`"`keep'"')
        local cmd `"`cmd' --keep-file "`keepfile'""'
    }
    if `"`drop'"' != "" {
        tempfile dropfile
        _logdoc_write_argfile, path("`dropfile'") text(`"`drop'"')
        local cmd `"`cmd' --drop-file "`dropfile'""'
    }

    * --- I4: Append mode ---
    if "`append'" != "" {
        local cmd `"`cmd' --append"'
    }

    * --- C1: Notebook mode ---
    if "`notebook'" != "" {
        local cmd `"`cmd' --notebook"'
    }

    * --- C3: Email-safe HTML ---
    if "`email'" != "" {
        local cmd `"`cmd' --email"'
    }

    * --- C7: Annotation file ---
    if "`annotate'" != "" {
        local cmd `"`cmd' --annotate "`annotate'""'
    }

    * --- R3: Windows path normalization for Python args ---
    if "`c(os)'" == "Windows" {
        local cmd = subinstr(`"`cmd'"', "\", "/", .)
    }

    * --- F2/F1/F7: Handle docx/pdf via HTML intermediary ---
    * For docx/pdf: redirect Python output to a tempfile, convert after
    local _actual_format "`format'"
    local _temphtml_path ""
    if inlist("`format'", "docx", "pdf") {
        tempfile _temphtml
        local _temphtml_path "`_temphtml'.html"
        * Rewrite the command to produce HTML to the temp path
        * Replace the output path and format in the command
        local cmd = subinstr(`"`cmd'"', `""`output'""', ///
            `""`_temphtml_path'""', 1)
        local cmd = subinstr(`"`cmd'"', "--format docx", "--format html", 1)
        local cmd = subinstr(`"`cmd'"', "--format pdf", "--format html", 1)
    }

    * Execute (capture stdout for I1 metadata)
    if "`quiet'" == "" {
        display as text "Generating document..."
    }
    tempfile _pyout
    shell `cmd' > "`_pyout'" 2>&1
    if `_runwrapper_was_input' {
        capture erase "`input_file'"
    }

    * --- I1: Parse LOGDOC_META from Python stdout ---
    _logdoc_parse_pyout using "`_pyout'"
    local _nblocks = r(nblocks)
    local _filesize = r(filesize)
    local _ngraphs = r(ngraphs)
    local _ntables = r(ntables)
    local _nwarnings = r(nwarnings)
    local _py_lastmsg `"`r(lastmsg)'"'

    * --- F2/F1: Post-process for docx/pdf formats ---
    if "`_actual_format'" == "docx" {
        * Verify intermediate HTML was created
        capture confirm file "`_temphtml_path'"
        if _rc {
            display as error "failed to generate intermediate HTML for docx conversion"
            if `"`_py_lastmsg'"' != "" {
                display as error `"`_py_lastmsg'"'
            }
            display as error "command attempted:"
            display as error `"`cmd'"'
            exit 601
        }
        * Convert HTML to docx using Stata's html2docx
        if "`quiet'" == "" {
            display as text "Converting HTML to Word document..."
        }
        capture noisily html2docx "`_temphtml_path'", saving("`output'") replace
        local _h2d_rc = _rc
        capture erase "`_temphtml_path'"
        if `_h2d_rc' exit `_h2d_rc'
    }
    else if "`_actual_format'" == "pdf" {
        * Verify intermediate HTML was created
        capture confirm file "`_temphtml_path'"
        if _rc {
            display as error "failed to generate intermediate HTML for PDF conversion"
            if `"`_py_lastmsg'"' != "" {
                display as error `"`_py_lastmsg'"'
            }
            display as error "command attempted:"
            display as error `"`cmd'"'
            exit 601
        }
        * Try xhtml2pdf (via Python) first, then fall back to wkhtmltopdf
        local _pdf_done = 0
        if "`quiet'" == "" {
            display as text "Converting HTML to PDF..."
        }
        tempfile _xh2p_out
        shell "`python'" "`scriptpath'" "__dummy__" "`output'" ///
            --html-to-pdf "`_temphtml_path'" > "`_xh2p_out'" 2>&1
        capture confirm file "`output'"
        if !_rc {
            local _pdf_done = 1
            if "`quiet'" == "" {
                display as text "(via xhtml2pdf)"
            }
        }
        if !`_pdf_done' {
            * Fall back to wkhtmltopdf
            tempfile _wkcheck
            shell command -v wkhtmltopdf > "`_wkcheck'" 2>&1
            local _has_wkhtmltopdf = 0
            capture {
                tempname _wkfh
                file open `_wkfh' using "`_wkcheck'", read text
                file read `_wkfh' _wkline
                file close `_wkfh'
                if regexm("`_wkline'", "wkhtmltopdf") {
                    local _has_wkhtmltopdf = 1
                }
            }
            if `_has_wkhtmltopdf' {
                if "`quiet'" == "" {
                    display as text "(via wkhtmltopdf)"
                }
                tempfile _wk_stderr
                shell wkhtmltopdf "`_temphtml_path'" "`output'" ///
                    > /dev/null 2>"`_wk_stderr'"
                capture confirm file "`output'"
                if _rc {
                    display as error "wkhtmltopdf failed to produce output"
                    capture {
                        tempname _wkefh
                        file open `_wkefh' using "`_wk_stderr'", read text
                        file read `_wkefh' _wkeline
                        while r(eof) == 0 {
                            if strtrim("`_wkeline'") != "" {
                                display as error "`_wkeline'"
                            }
                            file read `_wkefh' _wkeline
                        }
                        file close `_wkefh'
                    }
                    capture erase "`_temphtml_path'"
                    exit 601
                }
            }
            else {
                capture erase "`_temphtml_path'"
                display as error "no PDF converter found"
                display as error "install xhtml2pdf: logdoc_py, install(xhtml2pdf)"
                display as error "or install wkhtmltopdf as a system package"
                exit 601
            }
        }
        * Clean up temp HTML
        capture erase "`_temphtml_path'"
    }

    * Verify output
    * For format(both), Python creates .html/.md variants; the raw output
    * path may not exist if it has no extension, so compute expected paths.
    local _secondary_path ""
    if "`format'" == "both" {
        local primary_file ""
        local secondary ""
        _logdoc_both_paths, output("`output'") ///
            primary(primary_file) secondary(secondary)
        capture confirm file "`primary_file'"
        if _rc {
            display as error "failed to generate output document"
            if `"`_py_lastmsg'"' != "" {
                display as error `"`_py_lastmsg'"'
            }
            else {
                display as error "ensure Python 3 is installed and accessible"
            }
            display as error "command attempted:"
            display as error `"`cmd'"'
            exit 601
        }
        if "`quiet'" == "" {
            display as result "Output: `primary_file'"
        }
        capture confirm file "`secondary'"
        if _rc {
            display as error "primary output created but secondary file failed"
            display as error "expected: `secondary'"
            exit 601
        }
        if "`quiet'" == "" {
            display as result "Output: `secondary'"
        }
        * --- I5: Store secondary path for return ---
        local _secondary_path "`secondary'"
    }
    else {
        capture confirm file "`output'"
        if _rc {
            display as error "failed to generate output document"
            if `"`_py_lastmsg'"' != "" {
                display as error `"`_py_lastmsg'"'
            }
            else {
                display as error "ensure Python 3 is installed and accessible"
            }
            display as error "command attempted:"
            display as error `"`cmd'"'
            exit 601
        }
        if "`quiet'" == "" {
            display as result "Output: `output'"
        }
    }

    * --- U2: Open output in browser ---
    if "`open'" != "" {
        local _openfile "`output'"
        if "`format'" == "both" local _openfile "`primary_file'"
        if "`c(os)'" == "MacOSX" {
            shell open "`_openfile'" > /dev/null 2>&1 &
        }
        else if "`c(os)'" == "Windows" {
            shell start "" "`_openfile'"
        }
        else {
            shell xdg-open "`_openfile'" > /dev/null 2>&1 &
        }
    }

    global LOGDOC_LAST_INPUT `"`using'"'
    global LOGDOC_LAST_OUTPUT `"`output'"'
    global LOGDOC_LAST_FORMAT `"`format'"'
    global LOGDOC_LAST_THEME `"`theme'"'
    global LOGDOC_LAST_TITLE `"`title'"'
    global LOGDOC_LAST_DATE `"`date'"'
    global LOGDOC_LAST_PREFORMATTED "`preformatted'"
    global LOGDOC_LAST_NOFOLD "`nofold'"
    global LOGDOC_LAST_NODOTS "`nodots'"
    global LOGDOC_LAST_PYTHON `"`python'"'
    global LOGDOC_LAST_CSS `"`css'"'
    global LOGDOC_LAST_ACCENT `"`accent'"'
    global LOGDOC_LAST_QUIET "`quiet'"
    global LOGDOC_LAST_VERBOSE "`verbose'"
    global LOGDOC_LAST_FOOTER `"`footer'"'
    global LOGDOC_LAST_STAMP "`stamp'"
    global LOGDOC_LAST_NOGRAPH "`nograph'"
    global LOGDOC_LAST_GRAPHWIDTH `"`graphwidth'"'
    global LOGDOC_LAST_GRAPHHEIGHT `"`graphheight'"'
    global LOGDOC_LAST_LINENUMBERS "`linenumbers'"
    global LOGDOC_LAST_TOC "`toc'"
    global LOGDOC_LAST_FOLD "`fold'"
    global LOGDOC_LAST_HIGHLIGHT "`highlight'"
    global LOGDOC_LAST_TABLES "`tables'"
    global LOGDOC_LAST_COPY "`copy'"
    global LOGDOC_LAST_DOWNLOAD "`download'"
    global LOGDOC_LAST_LEGACY "`legacy'"
    global LOGDOC_LAST_KEEP `"`keep'"'
    global LOGDOC_LAST_DROP `"`drop'"'
    global LOGDOC_LAST_APPEND "`append'"
    global LOGDOC_LAST_NOTEBOOK "`notebook'"
    global LOGDOC_LAST_EMAIL "`email'"
    global LOGDOC_LAST_ANNOTATE `"`annotate'"'
    global LOGDOC_LAST_GENERATED "`generated'"

    * Return values
    return local output "`output'"
    return local input "`input_file'"
    return local format "`_actual_format'"
    return local theme "`theme'"
    return local accent "`accent'"
    * --- I5: Return secondary path ---
    if "`_secondary_path'" != "" {
        return local secondary "`_secondary_path'"
    }
    * --- I1: Return metadata ---
    return scalar nblocks = `_nblocks'
    return scalar filesize = `_filesize'
    return scalar ngraphs = `_ngraphs'
    return scalar ntables = `_ntables'
    return scalar nwarnings = `_nwarnings'

    } // end capture noisily

    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* _logdoc_start: begin an interactive logging session
* ---------------------------------------------------------------------------

capture program drop _logdoc_start
program define _logdoc_start
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _orig_linesize = c(linesize)
    local _started_new_session = 0
    set varabbrev off
    capture noisily {

    syntax , OUTput(string) [Format(string) THeme(string) ///
        TItle(string) DATe(string) PREformatted NOFold NODots ///
        PYthon(string) CSS(string) OPEN REPlace Quiet Verbose ///
        FOOTer(string) STamp NOGraph GRAPHWidth(string) GRAPHHeight(string) ///
        LINEnumbers TOC KEEP(string) DROP(string) ///
        APPend NOTEbook EMAil ANNotate(string) ///
        ACCent(string) FOLD HIGHlight TABles COPY DOWNload LEGacy GENerated]

    * Check if session already active
    if `"$LOGDOC_ACTIVE"' == "1" {
        display as error "logdoc session already active; use {bf:logdoc stop} first"
        exit 198
    }

    if "`quiet'" != "" & "`verbose'" != "" {
        display as error "quiet and verbose are mutually exclusive"
        exit 198
    }

    if "`format'" != "" {
        if !inlist("`format'", "html", "md", "both", "docx", "pdf", "tex", "qmd") {
            display as error "format() must be html, md, both, docx, pdf, tex, or qmd"
            exit 198
        }
        if "`append'" != "" & inlist("`format'", "docx", "pdf") {
            display as error "append is not supported with format(docx) or format(pdf)"
            exit 198
        }
    }

    if "`theme'" != "" & !inlist("`theme'", "light", "dark") {
        display as error "theme() must be light or dark"
        exit 198
    }
    if "`accent'" != "" {
        if !regexm("`accent'", ///
            "^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") {
            display as error "accent() must be a #RRGGBB color"
            exit 198
        }
    }

    if "`graphwidth'" != "" {
        local _graphwidth_num = real("`graphwidth'")
        if missing(`_graphwidth_num') | `_graphwidth_num' <= 0 | ///
            `_graphwidth_num' != floor(`_graphwidth_num') {
            display as error "graphwidth() must be a positive integer"
            exit 198
        }
    }
    if "`graphheight'" != "" {
        local _graphheight_num = real("`graphheight'")
        if missing(`_graphheight_num') | `_graphheight_num' <= 0 | ///
            `_graphheight_num' != floor(`_graphheight_num') {
            display as error "graphheight() must be a positive integer"
            exit 198
        }
    }

    set linesize 255

    * Store all options in globals for _logdoc_stop to retrieve
    global LOGDOC_ACTIVE "1"
    local _started_new_session = 1
    global LOGDOC_OUTPUT `"`output'"'
    global LOGDOC_FORMAT `"`format'"'
    global LOGDOC_THEME `"`theme'"'
    global LOGDOC_TITLE `"`title'"'
    global LOGDOC_DATE `"`date'"'
    global LOGDOC_PREFORMATTED "`preformatted'"
    global LOGDOC_NOFOLD "`nofold'"
    global LOGDOC_NODOTS "`nodots'"
    global LOGDOC_PYTHON `"`python'"'
    global LOGDOC_CSS `"`css'"'
    global LOGDOC_ACCENT `"`accent'"'
    global LOGDOC_OPEN "`open'"
    global LOGDOC_REPLACE "`replace'"
    global LOGDOC_APPEND "`append'"
    global LOGDOC_QUIET "`quiet'"
    global LOGDOC_VERBOSE "`verbose'"
    global LOGDOC_FOOTER `"`footer'"'
    global LOGDOC_STAMP "`stamp'"
    global LOGDOC_NOGRAPH "`nograph'"
    global LOGDOC_GRAPHWIDTH `"`graphwidth'"'
    global LOGDOC_GRAPHHEIGHT `"`graphheight'"'
    global LOGDOC_LINENUMBERS "`linenumbers'"
    global LOGDOC_TOC "`toc'"
    global LOGDOC_FOLD "`fold'"
    global LOGDOC_HIGHLIGHT "`highlight'"
    global LOGDOC_TABLES "`tables'"
    global LOGDOC_COPY "`copy'"
    global LOGDOC_DOWNLOAD "`download'"
    global LOGDOC_KEEP `"`keep'"'
    global LOGDOC_DROP `"`drop'"'
    global LOGDOC_NOTEBOOK "`notebook'"
    global LOGDOC_EMAIL "`email'"
    global LOGDOC_ANNOTATE `"`annotate'"'
    global LOGDOC_LEGACY "`legacy'"
    global LOGDOC_GENERATED "`generated'"
    global LOGDOC_ORIG_LINESIZE "`_orig_linesize'"

    * Open SMCL log to temp file (use time-based unique name since c(pid)
    * is not available in Stata 17).  The uniqueness draw uses runiform(),
    * which would otherwise advance the caller's RNG state and silently
    * perturb a seeded session (bootstrap/simulate); preserve and restore
    * c(rngstate) so `logdoc start` is reproducibility-neutral.
    local _ts = subinstr(c(current_time), ":", "", .)
    local _rngstate = c(rngstate)
    local _rand = string(floor(runiform() * 1000000000), "%09.0f")
    set rngstate `_rngstate'
    local _tmplog "`c(tmpdir)'/logdoc_session_`_ts'_`_rand'.smcl"
    global LOGDOC_TMPLOG "`_tmplog'"

    capture log close _logdoc
    log using "`_tmplog'", replace name(_logdoc)

    if "`quiet'" == "" {
        display as text "logdoc session started"
        display as text "Output will be saved to: `output'"
        display as text "Use {bf:logdoc stop} to end and convert"
    }

    }
    local rc = _rc
    if `rc' {
        capture set linesize `_orig_linesize'
        if `_started_new_session' {
            capture log close _logdoc
            capture erase "`_tmplog'"
            capture macro drop LOGDOC_ACTIVE LOGDOC_OUTPUT LOGDOC_FORMAT LOGDOC_THEME ///
                LOGDOC_TITLE LOGDOC_DATE LOGDOC_PREFORMATTED LOGDOC_NOFOLD ///
                LOGDOC_NODOTS LOGDOC_PYTHON LOGDOC_CSS LOGDOC_OPEN ///
                LOGDOC_ACCENT LOGDOC_REPLACE LOGDOC_APPEND LOGDOC_QUIET LOGDOC_VERBOSE LOGDOC_FOOTER ///
                LOGDOC_STAMP LOGDOC_NOGRAPH LOGDOC_GRAPHWIDTH LOGDOC_GRAPHHEIGHT ///
                LOGDOC_LINENUMBERS LOGDOC_TOC LOGDOC_FOLD LOGDOC_HIGHLIGHT ///
                LOGDOC_TABLES LOGDOC_COPY LOGDOC_DOWNLOAD LOGDOC_KEEP LOGDOC_DROP ///
                LOGDOC_NOTEBOOK LOGDOC_EMAIL LOGDOC_ANNOTATE LOGDOC_LEGACY ///
                LOGDOC_GENERATED LOGDOC_ORIG_LINESIZE LOGDOC_TMPLOG
        }
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* _logdoc_stop: end session and convert the captured log
* ---------------------------------------------------------------------------

capture program drop _logdoc_stop
program define _logdoc_stop, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _stop_orig_linesize `"$LOGDOC_ORIG_LINESIZE"'
    set varabbrev off
    capture noisily {

    * Check if session is active
    if `"$LOGDOC_ACTIVE"' != "1" {
        display as error "no logdoc session is active; use {bf:logdoc start} first"
        exit 198
    }

    * Close the log
    capture log close _logdoc

    * Retrieve stored options
    local _tmplog `"$LOGDOC_TMPLOG"'
    local _orig_linesize `"$LOGDOC_ORIG_LINESIZE"'

    * Build option string from globals
    local _opts `"output("$LOGDOC_OUTPUT")"'

    if `"$LOGDOC_FORMAT"' != "" {
        local _opts `"`_opts' format("$LOGDOC_FORMAT")"'
    }
    if `"$LOGDOC_THEME"' != "" {
        local _opts `"`_opts' theme("$LOGDOC_THEME")"'
    }
    if `"$LOGDOC_TITLE"' != "" {
        local _opts `"`_opts' title("$LOGDOC_TITLE")"'
    }
    if `"$LOGDOC_DATE"' != "" {
        local _opts `"`_opts' date("$LOGDOC_DATE")"'
    }
    if "$LOGDOC_PREFORMATTED" != "" {
        local _opts `"`_opts' preformatted"'
    }
    if "$LOGDOC_NOFOLD" != "" {
        local _opts `"`_opts' nofold"'
    }
    if "$LOGDOC_NODOTS" != "" {
        local _opts `"`_opts' nodots"'
    }
    if `"$LOGDOC_PYTHON"' != "" {
        local _opts `"`_opts' python("$LOGDOC_PYTHON")"'
    }
    if `"$LOGDOC_CSS"' != "" {
        local _opts `"`_opts' css("$LOGDOC_CSS")"'
    }
    if `"$LOGDOC_ACCENT"' != "" {
        local _opts `"`_opts' accent("$LOGDOC_ACCENT")"'
    }
    if "$LOGDOC_OPEN" != "" {
        local _opts `"`_opts' open"'
    }
    if "$LOGDOC_REPLACE" != "" {
        local _opts `"`_opts' replace"'
    }
    if "$LOGDOC_APPEND" != "" {
        local _opts `"`_opts' append"'
    }
    if "$LOGDOC_QUIET" != "" {
        local _opts `"`_opts' quiet"'
    }
    if "$LOGDOC_VERBOSE" != "" {
        local _opts `"`_opts' verbose"'
    }
    if `"$LOGDOC_FOOTER"' != "" {
        local _opts `"`_opts' footer("$LOGDOC_FOOTER")"'
    }
    if "$LOGDOC_STAMP" != "" {
        local _opts `"`_opts' stamp"'
    }
    if "$LOGDOC_NOGRAPH" != "" {
        local _opts `"`_opts' nograph"'
    }
    if `"$LOGDOC_GRAPHWIDTH"' != "" {
        local _opts `"`_opts' graphwidth("$LOGDOC_GRAPHWIDTH")"'
    }
    if `"$LOGDOC_GRAPHHEIGHT"' != "" {
        local _opts `"`_opts' graphheight("$LOGDOC_GRAPHHEIGHT")"'
    }
    if "$LOGDOC_LINENUMBERS" != "" {
        local _opts `"`_opts' linenumbers"'
    }
    if "$LOGDOC_TOC" != "" {
        local _opts `"`_opts' toc"'
    }
    if "$LOGDOC_FOLD" != "" {
        local _opts `"`_opts' fold"'
    }
    if "$LOGDOC_HIGHLIGHT" != "" {
        local _opts `"`_opts' highlight"'
    }
    if "$LOGDOC_TABLES" != "" {
        local _opts `"`_opts' tables"'
    }
    if "$LOGDOC_COPY" != "" {
        local _opts `"`_opts' copy"'
    }
    if "$LOGDOC_DOWNLOAD" != "" {
        local _opts `"`_opts' download"'
    }
    if `"$LOGDOC_KEEP"' != "" {
        local _opts `"`_opts' keep("$LOGDOC_KEEP")"'
    }
    if `"$LOGDOC_DROP"' != "" {
        local _opts `"`_opts' drop("$LOGDOC_DROP")"'
    }
    if "$LOGDOC_NOTEBOOK" != "" {
        local _opts `"`_opts' notebook"'
    }
    if "$LOGDOC_EMAIL" != "" {
        local _opts `"`_opts' email"'
    }
    if `"$LOGDOC_ANNOTATE"' != "" {
        local _opts `"`_opts' annotate("$LOGDOC_ANNOTATE")"'
    }
    if "$LOGDOC_LEGACY" != "" {
        local _opts `"`_opts' legacy"'
    }
    if "$LOGDOC_GENERATED" != "" {
        local _opts `"`_opts' generated"'
    }

    * Convert the captured log
    capture noisily _logdoc_convert using "`_tmplog'", `_opts'
    local _convert_rc = _rc

    * Always clean up globals and temp file, even on error
    capture erase "`_tmplog'"
    capture macro drop LOGDOC_ACTIVE LOGDOC_OUTPUT LOGDOC_FORMAT LOGDOC_THEME ///
        LOGDOC_TITLE LOGDOC_DATE LOGDOC_PREFORMATTED LOGDOC_NOFOLD ///
        LOGDOC_NODOTS LOGDOC_PYTHON LOGDOC_CSS LOGDOC_OPEN ///
        LOGDOC_ACCENT LOGDOC_REPLACE LOGDOC_APPEND LOGDOC_QUIET LOGDOC_VERBOSE LOGDOC_FOOTER ///
        LOGDOC_STAMP LOGDOC_NOGRAPH LOGDOC_GRAPHWIDTH LOGDOC_GRAPHHEIGHT ///
        LOGDOC_LINENUMBERS LOGDOC_TOC LOGDOC_FOLD LOGDOC_HIGHLIGHT ///
        LOGDOC_TABLES LOGDOC_COPY LOGDOC_DOWNLOAD LOGDOC_KEEP LOGDOC_DROP ///
        LOGDOC_NOTEBOOK LOGDOC_EMAIL LOGDOC_ANNOTATE LOGDOC_LEGACY ///
        LOGDOC_GENERATED LOGDOC_ORIG_LINESIZE LOGDOC_TMPLOG
    if "`_orig_linesize'" != "" {
        capture set linesize `_orig_linesize'
    }

    if `_convert_rc' == 0 {
        return add
    }
    else {
        exit `_convert_rc'
    }

    }
    local rc = _rc
    if `rc' & "`_stop_orig_linesize'" != "" {
        capture set linesize `_stop_orig_linesize'
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* _logdoc_combine: combine multiple log files into one document
* ---------------------------------------------------------------------------

capture program drop _logdoc_combine
program define _logdoc_combine, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    local _cmdline `"`0'"'
    local _comma_pos = strpos(`"`_cmdline'"', ",")
    if `_comma_pos' == 0 {
        display as error "syntax is: logdoc combine using file1 file2 ..., output(filename)"
        exit 198
    }
    local sources = strtrim(substr(`"`_cmdline'"', 1, `_comma_pos' - 1))
    local _opts = substr(`"`_cmdline'"', `_comma_pos' + 1, .)
    local 0 `", `_opts'"'

    syntax , OUTput(string) ///
        [Format(string) THeme(string) TItle(string) DATe(string) ///
        PREformatted NOFold NODots PYthon(string) CSS(string) ACCent(string) ///
        OPEN REPlace Quiet Verbose FOOTer(string) STamp NOGraph ///
        GRAPHWidth(string) GRAPHHeight(string) LINEnumbers TOC ///
        KEEP(string) DROP(string) APPend NOTEbook EMAil ANNotate(string) ///
        FOLD HIGHlight TABles COPY DOWNload LEGacy GENerated]

    if "`quiet'" != "" & "`verbose'" != "" {
        display as error "quiet and verbose are mutually exclusive"
        exit 198
    }

    * Read global defaults first; project .logdocrc overrides them.
    local _config_keys "format theme title date python css footer stamp"
    local _config_keys "`_config_keys' nograph graphwidth graphheight"
    local _config_keys "`_config_keys' linenumbers toc keep drop append"
    local _config_keys "`_config_keys' notebook email annotate accent"
    local _config_keys "`_config_keys' preformatted nofold nodots open"
    local _config_keys "`_config_keys' replace quiet verbose fold"
    local _config_keys "`_config_keys' highlight tables copy download"
    local _config_keys "`_config_keys' legacy generated"
    foreach _cfgkey of local _config_keys {
        local _user_`_cfgkey' `"``_cfgkey''"'
    }
    local _config_python ""
    local _config_files ""
    local _home : environment HOME
    if `"`_home'"' != "" {
        capture confirm file `"`_home'/.logdocrc"'
        if !_rc {
            local _config_files `"`_config_files' `"`_home'/.logdocrc"'"'
        }
    }
    capture confirm file ".logdocrc"
    if !_rc {
        local _config_files `"`_config_files' `".logdocrc"'"'
    }
    foreach _config_file of local _config_files {
        tempname rcfh
        file open `rcfh' using `"`_config_file'"', read text
        file read `rcfh' _rcline
        while r(eof) == 0 {
            local _rcline_trim = strtrim(`"`_rcline'"')
            if regexm(`"`_rcline_trim'"', "^([A-Za-z][A-Za-z0-9_]*)=(.*)$") {
                local _rckey = lower(regexs(1))
                local _rcval = regexs(2)
                local _user_value `"`_user_`_rckey''"'
                if `"`_user_value'"' == "" {
                    if "`_rckey'" == "python" {
                        local _config_python `"`_rcval'"'
                    }
                    else {
                        local `_rckey' `"`_rcval'"'
                    }
                }
            }
            file read `rcfh' _rcline
        }
        file close `rcfh'
    }

    gettoken _using sources : sources, bind
    if lower("`_using'") != "using" {
        display as error "syntax is: logdoc combine using file1 file2 ..., output(filename)"
        exit 198
    }

    tempfile _manifest
    tempname _mfh
    file open `_mfh' using "`_manifest'", write text replace
    local _source_count = 0
    local _first_source ""
    local _source_list ""
    while `"`sources'"' != "" {
        gettoken _src sources : sources, bind
        if `"`_src'"' != "" {
            capture confirm file `"`_src'"'
            if _rc {
                display as error `"file "`_src'" not found"'
                file close `_mfh'
                exit 601
            }
            local _source_count = `_source_count' + 1
            if `_source_count' == 1 local _first_source `"`_src'"'
            local _source_list `"`_source_list' `"`_src'"'"'
            file write `_mfh' `"`_src'"' _n
        }
    }
    file close `_mfh'
    if `_source_count' < 2 {
        display as error "combine requires at least two source files"
        exit 198
    }

    if "`format'" == "" {
        local _outext = lower(substr("`output'", -3, .))
        local _outext4 = lower(substr("`output'", -4, .))
        if "`_outext'" == ".md" local format "md"
        if "`_outext4'" == ".tex" local format "tex"
        if "`_outext4'" == ".qmd" local format "qmd"
    }
    if "`format'" == "" local format "html"
    if "`theme'" == "" local theme "light"

    if !inlist("`format'", "html", "md", "both", "tex", "qmd") {
        display as error "combine supports format(html), format(md), format(qmd), format(tex), or format(both)"
        exit 198
    }
    if !inlist("`theme'", "light", "dark") {
        display as error "theme() must be light or dark"
        exit 198
    }
    if "`accent'" != "" {
        if !regexm("`accent'", ///
            "^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") {
            display as error "accent() must be a #RRGGBB color"
            exit 198
        }
    }
    if "`graphwidth'" != "" {
        local _graphwidth_num = real("`graphwidth'")
        if missing(`_graphwidth_num') | `_graphwidth_num' <= 0 | ///
            `_graphwidth_num' != floor(`_graphwidth_num') {
            display as error "graphwidth() must be a positive integer"
            exit 198
        }
    }
    if "`graphheight'" != "" {
        local _graphheight_num = real("`graphheight'")
        if missing(`_graphheight_num') | `_graphheight_num' <= 0 | ///
            `_graphheight_num' != floor(`_graphheight_num') {
            display as error "graphheight() must be a positive integer"
            exit 198
        }
    }
    if "`annotate'" != "" {
        capture confirm file "`annotate'"
        if _rc {
            display as error `"annotation file "`annotate'" not found"'
            exit 601
        }
    }
    if "`css'" != "" {
        capture confirm file "`css'"
        if _rc {
            display as error `"CSS file "`css'" not found"'
            exit 601
        }
    }

    if "`append'" == "" & "`replace'" == "" {
        capture confirm file "`output'"
        if !_rc {
            display as error `"file "`output'" already exists; use replace option"'
            exit 602
        }
        if "`format'" == "both" {
            local _primary ""
            local _secondary ""
            _logdoc_both_paths, output("`output'") ///
                primary(_primary) secondary(_secondary)
            capture confirm file "`_primary'"
            if !_rc {
                display as error `"file "`_primary'" already exists; use replace option"'
                exit 602
            }
            capture confirm file "`_secondary'"
            if !_rc {
                display as error `"file "`_secondary'" already exists; use replace option"'
                exit 602
            }
        }
    }

    if "`python'" == "" {
        _logdoc_resolve_python, result(python) configpython(`"`_config_python'"')
    }
    _logdoc_check_python "`python'"

    local scriptpath ""
    _logdoc_find_script, result(scriptpath)
    if "`scriptpath'" == "" {
        display as error "logdoc_render.py not found"
        display as error "ensure logdoc is properly installed"
        exit 601
    }

    local light_css ""
    local dark_css ""
    _logdoc_find_css, light(light_css) dark(dark_css)

    local cmd `""`python'" "`scriptpath'" "`_first_source'" "`output'""'
    local cmd `"`cmd' --format `format' --theme `theme'"'
    local cmd `"`cmd' --combine-file "`_manifest'""'

    if "`title'" != "" {
        tempfile titlefile
        _logdoc_write_argfile, path("`titlefile'") text(`"`title'"')
        local cmd `"`cmd' --title-file "`titlefile'""'
    }
    if "`date'" != "" {
        tempfile datefile
        _logdoc_write_argfile, path("`datefile'") text(`"`date'"')
        local cmd `"`cmd' --date-file "`datefile'""'
    }
    if "`preformatted'" != "" local cmd `"`cmd' --preformatted"'
    if "`nofold'" != "" local cmd `"`cmd' --nofold"'
    if "`nodots'" != "" local cmd `"`cmd' --nodots"'
    if "`fold'" != "" local cmd `"`cmd' --fold"'
    if "`highlight'" != "" local cmd `"`cmd' --highlight"'
    if "`tables'" != "" local cmd `"`cmd' --tables"'
    if "`copy'" != "" local cmd `"`cmd' --copy"'
    if "`download'" != "" local cmd `"`cmd' --download"'
    if "`legacy'" != "" local cmd `"`cmd' --legacy"'

    if "`css'" != "" {
        local cmd `"`cmd' --css "`css'""'
    }
    else {
        if "`light_css'" != "" {
            local cmd `"`cmd' --light-css "`light_css'""'
        }
        if "`dark_css'" != "" {
            local cmd `"`cmd' --dark-css "`dark_css'""'
        }
    }
    if "`accent'" != "" local cmd `"`cmd' --accent "`accent'""'
    if "`verbose'" != "" local cmd `"`cmd' --verbose"'
    if `"`footer'"' != "" {
        tempfile footerfile
        _logdoc_write_argfile, path("`footerfile'") text(`"`footer'"')
        local cmd `"`cmd' --footer-file "`footerfile'""'
    }
    if "`generated'" != "" local cmd `"`cmd' --generated"'
    if "`stamp'" != "" {
        local _stamp_str ///
            "Stata `c(stata_version)' `c(edition_real)' | `c(current_date)' `c(current_time)'"
        if `"`c(filename)'"' != "" {
            local _stamp_str `"`_stamp_str' | `c(filename)'"'
        }
        tempfile stampfile
        _logdoc_write_argfile, path("`stampfile'") text(`"`_stamp_str'"')
        local cmd `"`cmd' --stamp-file "`stampfile'""'
    }
    if "`nograph'" != "" local cmd `"`cmd' --nograph"'
    if "`graphwidth'" != "" local cmd `"`cmd' --graphwidth `graphwidth'"'
    if "`graphheight'" != "" local cmd `"`cmd' --graphheight `graphheight'"'
    if "`linenumbers'" != "" local cmd `"`cmd' --linenumbers"'
    if "`toc'" != "" local cmd `"`cmd' --toc"'
    if `"`keep'"' != "" {
        tempfile keepfile
        _logdoc_write_argfile, path("`keepfile'") text(`"`keep'"')
        local cmd `"`cmd' --keep-file "`keepfile'""'
    }
    if `"`drop'"' != "" {
        tempfile dropfile
        _logdoc_write_argfile, path("`dropfile'") text(`"`drop'"')
        local cmd `"`cmd' --drop-file "`dropfile'""'
    }
    if "`append'" != "" local cmd `"`cmd' --append"'
    if "`notebook'" != "" local cmd `"`cmd' --notebook"'
    if "`email'" != "" local cmd `"`cmd' --email"'
    if "`annotate'" != "" local cmd `"`cmd' --annotate "`annotate'""'

    if "`c(os)'" == "Windows" {
        local cmd = subinstr(`"`cmd'"', "\", "/", .)
    }

    if "`quiet'" == "" {
        display as text "Combining `_source_count' files..."
    }
    tempfile _pyout
    shell `cmd' > "`_pyout'" 2>&1

    _logdoc_parse_pyout using "`_pyout'"
    local _nblocks = r(nblocks)
    local _filesize = r(filesize)
    local _ngraphs = r(ngraphs)
    local _ntables = r(ntables)
    local _nwarnings = r(nwarnings)
    local _py_lastmsg `"`r(lastmsg)'"'

    local _secondary_path ""
    if "`format'" == "both" {
        local primary_file ""
        local secondary ""
        _logdoc_both_paths, output("`output'") ///
            primary(primary_file) secondary(secondary)
        capture confirm file "`primary_file'"
        if _rc {
            display as error "failed to generate combined output document"
            if `"`_py_lastmsg'"' != "" display as error `"`_py_lastmsg'"'
            exit 601
        }
        capture confirm file "`secondary'"
        if _rc {
            display as error "primary output created but secondary file failed"
            display as error "expected: `secondary'"
            exit 601
        }
        local _secondary_path "`secondary'"
        if "`quiet'" == "" {
            display as result "Output: `primary_file'"
            display as result "Output: `secondary'"
        }
    }
    else {
        capture confirm file "`output'"
        if _rc {
            display as error "failed to generate combined output document"
            if `"`_py_lastmsg'"' != "" display as error `"`_py_lastmsg'"'
            exit 601
        }
        if "`quiet'" == "" {
            display as result "Output: `output'"
        }
    }

    if "`open'" != "" {
        local _openfile "`output'"
        if "`format'" == "both" local _openfile "`primary_file'"
        if "`c(os)'" == "MacOSX" {
            shell open "`_openfile'" > /dev/null 2>&1 &
        }
        else if "`c(os)'" == "Windows" {
            shell start "" "`_openfile'"
        }
        else {
            shell xdg-open "`_openfile'" > /dev/null 2>&1 &
        }
    }

    return local output "`output'"
    return local input `"`_source_list'"'
    return local format "`format'"
    return local theme "`theme'"
    return local accent "`accent'"
    if "`_secondary_path'" != "" {
        return local secondary "`_secondary_path'"
    }
    return scalar n_sources = `_source_count'
    return scalar nblocks = `_nblocks'
    return scalar filesize = `_filesize'
    return scalar ngraphs = `_ngraphs'
    return scalar ntables = `_ntables'
    return scalar nwarnings = `_nwarnings'

    }
    local rc = _rc
    capture file close `_mfh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* _logdoc_batch: batch convert multiple log files
* ---------------------------------------------------------------------------

capture program drop _logdoc_batch
program define _logdoc_batch, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , INput(string) OUTdir(string) [Format(string) THeme(string) ///
        TItle(string) DATe(string) PREformatted NOFold NODots ///
        Quiet Verbose REPlace OPEN STamp NOGraph ///
        CSS(string) PYthon(string) FOOTer(string) ///
        GRAPHWidth(string) GRAPHHeight(string) ///
        KEEP(string) DROP(string) ANNotate(string) APPend ACCent(string) ///
        NOTEbook EMAil LINEnumbers TOC ///
        FOLD HIGHlight TABles COPY DOWNload LEGacy GENerated]

    * Parse input pattern — split into directory and file pattern
    local _slashpos = strrpos("`input'", "/")
    if `_slashpos' == 0 {
        local _slashpos = strrpos("`input'", "\")
    }
    if `_slashpos' > 0 {
        local _dir = substr("`input'", 1, `_slashpos')
        local _pattern = substr("`input'", `_slashpos' + 1, .)
    }
    else {
        local _dir "."
        local _pattern "`input'"
    }

    * Enumerate matching files
    local files: dir "`_dir'" files "`_pattern'"
    if `"`files'"' == "" {
        display as error "no files matching `input'"
        exit 601
    }

    * Create output directory
    capture mkdir "`outdir'"

    * Build common option string
    local _opts ""
    if "`format'" == "" local format "html"
    local _opts `"`_opts' format(`format')"'
    if "`theme'" != "" local _opts `"`_opts' theme(`theme')"'
    if "`preformatted'" != "" local _opts `"`_opts' preformatted"'
    if "`nofold'" != "" local _opts `"`_opts' nofold"'
    if "`nodots'" != "" local _opts `"`_opts' nodots"'
    if "`quiet'" != "" local _opts `"`_opts' quiet"'
    if "`replace'" != "" local _opts `"`_opts' replace"'
    if "`notebook'" != "" local _opts `"`_opts' notebook"'
    if "`email'" != "" local _opts `"`_opts' email"'
    if "`linenumbers'" != "" local _opts `"`_opts' linenumbers"'
    if "`toc'" != "" local _opts `"`_opts' toc"'
    if "`fold'" != "" local _opts `"`_opts' fold"'
    if "`highlight'" != "" local _opts `"`_opts' highlight"'
    if "`tables'" != "" local _opts `"`_opts' tables"'
    if "`copy'" != "" local _opts `"`_opts' copy"'
    if "`download'" != "" local _opts `"`_opts' download"'
    if "`legacy'" != "" local _opts `"`_opts' legacy"'
    if "`generated'" != "" local _opts `"`_opts' generated"'
    if "`verbose'" != "" local _opts `"`_opts' verbose"'
    if "`open'" != "" local _opts `"`_opts' open"'
    if "`stamp'" != "" local _opts `"`_opts' stamp"'
    if "`nograph'" != "" local _opts `"`_opts' nograph"'
    if `"`title'"' != "" local _opts `"`_opts' title("`title'")"'
    if `"`date'"' != "" local _opts `"`_opts' date("`date'")"'
    if `"`css'"' != "" local _opts `"`_opts' css("`css'")"'
    if `"`accent'"' != "" local _opts `"`_opts' accent("`accent'")"'
    if `"`python'"' != "" local _opts `"`_opts' python("`python'")"'
    if `"`footer'"' != "" local _opts `"`_opts' footer("`footer'")"'
    if "`graphwidth'" != "" local _opts `"`_opts' graphwidth(`graphwidth')"'
    if "`graphheight'" != "" local _opts `"`_opts' graphheight(`graphheight')"'
    if `"`keep'"' != "" local _opts `"`_opts' keep("`keep'")"'
    if `"`drop'"' != "" local _opts `"`_opts' drop("`drop'")"'
    if `"`annotate'"' != "" local _opts `"`_opts' annotate("`annotate'")"'
    if "`append'" != "" local _opts `"`_opts' append"'

    * Determine file extension for output
    local _outext ""
    _logdoc_format_ext, format("`format'") ext(_outext)

    * Loop over files
    local _count = 0
    local _failed = 0
    foreach f of local files {
        local _count = `_count' + 1
        * Build input path
        if "`_dir'" != "." {
            local _inpath "`_dir'`f'"
        }
        else {
            local _inpath "`f'"
        }
        * Build output path (change extension only when one exists)
        local _dotpos = strrpos("`f'", ".")
        if `_dotpos' > 0 {
            local _base = substr("`f'", 1, `_dotpos' - 1)
        }
        else {
            local _base "`f'"
        }
        local _outpath "`outdir'/`_base'`_outext'"
        if "`quiet'" == "" {
            display as text "[`_count'] `_inpath' -> `_outpath'"
        }
        capture noisily _logdoc_convert using "`_inpath'", ///
            output("`_outpath'") `_opts'
        if _rc {
            local _failed = `_failed' + 1
        }
    }
    if "`quiet'" == "" {
        display as result "`_count' files processed, `_failed' failed"
    }

    return scalar n_files = `_count'
    return scalar n_failed = `_failed'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* _logdoc_diff: compare two log files side by side
* ---------------------------------------------------------------------------

capture program drop _logdoc_diff
program define _logdoc_diff, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax using/ , COMPare(string) OUTput(string) ///
        [REPlace THeme(string) PYthon(string) CSS(string) ACCent(string) Quiet]

    * Validate both files exist
    capture confirm file "`using'"
    if _rc {
        display as error `"file "`using'" not found"'
        exit 601
    }
    capture confirm file "`compare'"
    if _rc {
        display as error `"file "`compare'" not found"'
        exit 601
    }

    * Check replace / output exists
    if "`replace'" == "" {
        capture confirm file "`output'"
        if !_rc {
            display as error `"file "`output'" already exists; use replace option"'
            exit 602
        }
    }

    if "`theme'" == "" local theme "light"
    if !inlist("`theme'", "light", "dark") {
        display as error "theme() must be light or dark"
        exit 198
    }
    if "`accent'" != "" {
        if !regexm("`accent'", ///
            "^#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") {
            display as error "accent() must be a #RRGGBB color"
            exit 198
        }
    }
    if "`python'" == "" {
        _logdoc_resolve_python, result(python)
    }

    _logdoc_check_python "`python'"

    local scriptpath ""
    _logdoc_find_script, result(scriptpath)
    if "`scriptpath'" == "" {
        display as error "logdoc_render.py not found"
        exit 601
    }

    * Find CSS files
    local light_css ""
    local dark_css ""
    _logdoc_find_css, light(light_css) dark(dark_css)

    * Build command
    local cmd `""`python'" "`scriptpath'" "`using'" "`output'""'
    local cmd `"`cmd' --format html --theme `theme'"'
    local cmd `"`cmd' --compare "`compare'""'

    if "`css'" != "" {
        local cmd `"`cmd' --css "`css'""'
    }
    else {
        if "`light_css'" != "" {
            local cmd `"`cmd' --light-css "`light_css'""'
        }
        if "`dark_css'" != "" {
            local cmd `"`cmd' --dark-css "`dark_css'""'
        }
    }
    if "`accent'" != "" {
        local cmd `"`cmd' --accent "`accent'""'
    }

    if "`quiet'" == "" {
        display as text "Generating diff document..."
    }
    tempfile _pyout
    shell `cmd' > "`_pyout'" 2>&1

    _logdoc_parse_pyout using "`_pyout'"
    local _py_lastmsg `"`r(lastmsg)'"'

    capture confirm file "`output'"
    if _rc {
        display as error "failed to generate diff document"
        if `"`_py_lastmsg'"' != "" {
            display as error `"`_py_lastmsg'"'
        }
        exit 601
    }
    if "`quiet'" == "" {
        display as result "Output: `output'"
    }

    return local output "`output'"
    return local input "`using'"
    return local compare "`compare'"

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* _logdoc_replay: re-run last conversion with optional overrides
* ---------------------------------------------------------------------------

capture program drop _logdoc_replay
program define _logdoc_replay, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax [, THeme(string) Format(string) OPEN]

    if `"$LOGDOC_LAST_INPUT"' == "" {
        display as error "no previous logdoc call to replay"
        exit 198
    }

    * Rebuild the last resolved call and apply requested overrides.
    local _replay_format `"$LOGDOC_LAST_FORMAT"'
    local _replay_theme `"$LOGDOC_LAST_THEME"'
    if "`format'" != "" local _replay_format "`format'"
    if "`theme'" != "" local _replay_theme "`theme'"

    local _replay_args `"using "$LOGDOC_LAST_INPUT", output("$LOGDOC_LAST_OUTPUT") format(`_replay_format') theme(`_replay_theme')"'
    if `"$LOGDOC_LAST_TITLE"' != "" {
        local _replay_args `"`_replay_args' title("$LOGDOC_LAST_TITLE")"'
    }
    if `"$LOGDOC_LAST_DATE"' != "" {
        local _replay_args `"`_replay_args' date("$LOGDOC_LAST_DATE")"'
    }
    if "$LOGDOC_LAST_PREFORMATTED" != "" {
        local _replay_args `"`_replay_args' preformatted"'
    }
    if "$LOGDOC_LAST_NOFOLD" != "" {
        local _replay_args `"`_replay_args' nofold"'
    }
    if "$LOGDOC_LAST_NODOTS" != "" {
        local _replay_args `"`_replay_args' nodots"'
    }
    if `"$LOGDOC_LAST_PYTHON"' != "" {
        local _replay_args `"`_replay_args' python("$LOGDOC_LAST_PYTHON")"'
    }
    if `"$LOGDOC_LAST_CSS"' != "" {
        local _replay_args `"`_replay_args' css("$LOGDOC_LAST_CSS")"'
    }
    if `"$LOGDOC_LAST_ACCENT"' != "" {
        local _replay_args `"`_replay_args' accent("$LOGDOC_LAST_ACCENT")"'
    }
    if "$LOGDOC_LAST_QUIET" != "" {
        local _replay_args `"`_replay_args' quiet"'
    }
    if "$LOGDOC_LAST_VERBOSE" != "" {
        local _replay_args `"`_replay_args' verbose"'
    }
    if `"$LOGDOC_LAST_FOOTER"' != "" {
        local _replay_args `"`_replay_args' footer("$LOGDOC_LAST_FOOTER")"'
    }
    if "$LOGDOC_LAST_STAMP" != "" {
        local _replay_args `"`_replay_args' stamp"'
    }
    if "$LOGDOC_LAST_NOGRAPH" != "" {
        local _replay_args `"`_replay_args' nograph"'
    }
    if `"$LOGDOC_LAST_GRAPHWIDTH"' != "" {
        local _replay_args `"`_replay_args' graphwidth("$LOGDOC_LAST_GRAPHWIDTH")"'
    }
    if `"$LOGDOC_LAST_GRAPHHEIGHT"' != "" {
        local _replay_args `"`_replay_args' graphheight("$LOGDOC_LAST_GRAPHHEIGHT")"'
    }
    if "$LOGDOC_LAST_LINENUMBERS" != "" {
        local _replay_args `"`_replay_args' linenumbers"'
    }
    if "$LOGDOC_LAST_TOC" != "" {
        local _replay_args `"`_replay_args' toc"'
    }
    if "$LOGDOC_LAST_FOLD" != "" {
        local _replay_args `"`_replay_args' fold"'
    }
    if "$LOGDOC_LAST_HIGHLIGHT" != "" {
        local _replay_args `"`_replay_args' highlight"'
    }
    if "$LOGDOC_LAST_TABLES" != "" {
        local _replay_args `"`_replay_args' tables"'
    }
    if "$LOGDOC_LAST_COPY" != "" {
        local _replay_args `"`_replay_args' copy"'
    }
    if "$LOGDOC_LAST_DOWNLOAD" != "" {
        local _replay_args `"`_replay_args' download"'
    }
    if `"$LOGDOC_LAST_KEEP"' != "" {
        local _replay_args `"`_replay_args' keep("$LOGDOC_LAST_KEEP")"'
    }
    if `"$LOGDOC_LAST_DROP"' != "" {
        local _replay_args `"`_replay_args' drop("$LOGDOC_LAST_DROP")"'
    }
    if "$LOGDOC_LAST_APPEND" != "" {
        local _replay_args `"`_replay_args' append"'
    }
    else {
        local _replay_args `"`_replay_args' replace"'
    }
    if "$LOGDOC_LAST_NOTEBOOK" != "" {
        local _replay_args `"`_replay_args' notebook"'
    }
    if "$LOGDOC_LAST_EMAIL" != "" {
        local _replay_args `"`_replay_args' email"'
    }
    if `"$LOGDOC_LAST_ANNOTATE"' != "" {
        local _replay_args `"`_replay_args' annotate("$LOGDOC_LAST_ANNOTATE")"'
    }
    if "$LOGDOC_LAST_LEGACY" != "" {
        local _replay_args `"`_replay_args' legacy"'
    }
    if "$LOGDOC_LAST_GENERATED" != "" {
        local _replay_args `"`_replay_args' generated"'
    }
    if "`open'" != "" {
        local _replay_args `"`_replay_args' open"'
    }

    _logdoc_convert `_replay_args'
    return add

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* Helper: parse renderer stdout
* ---------------------------------------------------------------------------

capture program drop _logdoc_parse_pyout
program define _logdoc_parse_pyout, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax using/

    local _nblocks = 0
    local _filesize = 0
    local _ngraphs = 0
    local _ntables = 0
    local _nwarnings = 0
    local _lastmsg ""

    capture confirm file "`using'"
    if !_rc {
        capture {
            tempname _pyofh
            file open `_pyofh' using "`using'", read text
            file read `_pyofh' _pyoline
            while r(eof) == 0 {
                if regexm(`"`_pyoline'"', "LOGDOC_META: blocks=([0-9]+) filesize=([0-9]+)") {
                    local _nblocks = real(regexs(1))
                    local _filesize = real(regexs(2))
                    if regexm(`"`_pyoline'"', "graphs=([0-9]+)") {
                        local _ngraphs = real(regexs(1))
                    }
                    if regexm(`"`_pyoline'"', "tables=([0-9]+)") {
                        local _ntables = real(regexs(1))
                    }
                    if regexm(`"`_pyoline'"', "warnings=([0-9]+)") {
                        local _nwarnings = real(regexs(1))
                    }
                }
                else if strtrim(`"`_pyoline'"') != "" {
                    local _trimline = strtrim(`"`_pyoline'"')
                    if !regexm(`"`_trimline'"', "^(Generated:|logdoc: processing )") {
                        local _lastmsg `"`_trimline'"'
                    }
                }
                file read `_pyofh' _pyoline
            }
            file close `_pyofh'
        }
        capture file close `_pyofh'
    }

    return scalar nblocks = `_nblocks'
    return scalar filesize = `_filesize'
    return scalar ngraphs = `_ngraphs'
    return scalar ntables = `_ntables'
    return scalar nwarnings = `_nwarnings'
    return local lastmsg `"`_lastmsg'"'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* Helper: find default CSS files
* ---------------------------------------------------------------------------

capture program drop _logdoc_find_css
program define _logdoc_find_css
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , light(name) dark(name)

    local _light_css ""
    local _dark_css ""

    capture findfile logdoc_light.css
    if _rc == 0 {
        local _light_css "`r(fn)'"
        if substr("`_light_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`_light_css'", 2, .)
            local _light_css "`homedir'`rest'"
        }
    }

    capture findfile logdoc_dark.css
    if _rc == 0 {
        local _dark_css "`r(fn)'"
        if substr("`_dark_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`_dark_css'", 2, .)
            local _dark_css "`homedir'`rest'"
        }
    }

    c_local `light' "`_light_css'"
    c_local `dark' "`_dark_css'"

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* Helper: write a caller-owned tempfile argument
* ---------------------------------------------------------------------------

capture program drop _logdoc_write_argfile
program define _logdoc_write_argfile
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , path(string) text(string)

    tempname _argfh
    file open `_argfh' using "`path'", write text replace
    file write `_argfh' `"`text'"'
    file close `_argfh'

    }
    local rc = _rc
    capture file close `_argfh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* Helpers: output path calculation
* ---------------------------------------------------------------------------

capture program drop _logdoc_format_ext
program define _logdoc_format_ext
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , Format(string) ext(name)

    local _ext ".html"
    if "`format'" == "md" local _ext ".md"
    else if "`format'" == "qmd" local _ext ".qmd"
    else if "`format'" == "tex" local _ext ".tex"
    else if "`format'" == "docx" local _ext ".docx"
    else if "`format'" == "pdf" local _ext ".pdf"

    c_local `ext' "`_ext'"

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_both_paths
program define _logdoc_both_paths
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , OUTput(string) primary(name) secondary(name)

    local _dotpos = strrpos("`output'", ".")
    if `_dotpos' > 0 {
        local _base = substr("`output'", 1, `_dotpos' - 1)
        local _ext = substr("`output'", `_dotpos', .)
    }
    else {
        local _base "`output'"
        local _ext ""
    }

    if "`_ext'" == ".md" {
        local _primary "`_base'.md"
        local _secondary "`_base'.html"
    }
    else if "`_ext'" == ".html" {
        local _primary "`_base'.html"
        local _secondary "`_base'.md"
    }
    else {
        local _primary "`_base'.html"
        local _secondary "`_base'.md"
    }

    c_local `primary' "`_primary'"
    c_local `secondary' "`_secondary'"

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* Helper: find logdoc_render.py
* ---------------------------------------------------------------------------

capture program drop _logdoc_find_script
program define _logdoc_find_script
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , result(name)

    * 1. Try local package paths first when running from the repo/worktree
    capture confirm file "logdoc_render.py"
    if !_rc {
        c_local `result' "logdoc_render.py"
        exit 0
    }
    capture confirm file "../logdoc_render.py"
    if !_rc {
        c_local `result' "../logdoc_render.py"
        exit 0
    }
    capture confirm file "logdoc/logdoc_render.py"
    if !_rc {
        c_local `result' "logdoc/logdoc_render.py"
        exit 0
    }

    * 2. Try findfile (searches adopath)
    capture findfile logdoc_render.py
    if _rc == 0 {
        local path "`r(fn)'"
        * Expand ~ if present
        if substr("`path'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`path'", 2, .)
            local path "`homedir'`rest'"
        }
        capture confirm file "`path'"
        if !_rc {
            c_local `result' "`path'"
            exit 0
        }
    }

    * 3. Try alongside the located logdoc.ado file
    capture findfile logdoc.ado
    if _rc == 0 {
        local adopath "`r(fn)'"
        if substr("`adopath'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`adopath'", 2, .)
            local adopath "`homedir'`rest'"
        }
        local _slashpos = strrpos("`adopath'", "/")
        if `_slashpos' == 0 {
            local _slashpos = strrpos("`adopath'", "\")
        }
        if `_slashpos' > 0 {
            local adodir = substr("`adopath'", 1, `_slashpos' - 1)
            capture confirm file "`adodir'/logdoc_render.py"
            if !_rc {
                c_local `result' "`adodir'/logdoc_render.py"
                exit 0
            }
        }
    }

    * Not found
    c_local `result' ""

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* Helper: resolve Python executable using Stata's configured Python first
* ---------------------------------------------------------------------------

capture program drop _logdoc_resolve_python
program define _logdoc_resolve_python
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , result(name) [configpython(string)]

    local _stata_pyexec ""
    capture quietly python: from sfi import Macro; import sys; Macro.setLocal("_stata_pyexec", sys.executable)
    local _stata_rc = _rc
    if `_stata_rc' == 0 & `"`_stata_pyexec'"' != "" {
        c_local `result' `"`_stata_pyexec'"'
        exit 0
    }

    if `"$LOGDOC_PYTHON"' != "" {
        c_local `result' `"$LOGDOC_PYTHON"'
        exit 0
    }

    if `"`configpython'"' != "" {
        c_local `result' `"`configpython'"'
        exit 0
    }

    if "`c(os)'" == "Windows" {
        c_local `result' "python"
    }
    else {
        c_local `result' "python3"
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* Helper: validate Python installation and version (R4 + R6)
* ---------------------------------------------------------------------------

capture program drop _logdoc_check_python
program define _logdoc_check_python
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    args python_exe

    tempfile pycheck
    shell "`python_exe'" --version > "`pycheck'" 2>&1

    * Check if Python responded
    capture confirm file "`pycheck'"
    if _rc {
        display as error "Python 3 not found"
        display as error "logdoc requires Python 3.6+ to be installed and on your PATH"
        display as error "tried: `python_exe'"
        exit 601
    }

    * Read version output
    tempname _pyfh
    file open `_pyfh' using "`pycheck'", read text
    file read `_pyfh' _pyline
    file close `_pyfh'

    if !regexm("`_pyline'", "Python") {
        display as error "Python 3 not found"
        display as error "logdoc requires Python 3.6+ to be installed and on your PATH"
        display as error "tried: `python_exe'"
        exit 601
    }

    * Parse version number (format: "Python 3.x.y")
    if regexm("`_pyline'", "([0-9]+)\.([0-9]+)") {
        local _pymajor = real(regexs(1))
        local _pyminor = real(regexs(2))
        if `_pymajor' < 3 | (`_pymajor' == 3 & `_pyminor' < 6) {
            display as error "Python `_pymajor'.`_pyminor' found but logdoc requires Python 3.6+"
            display as error "upgrade Python or specify a different path with python() option"
            exit 601
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

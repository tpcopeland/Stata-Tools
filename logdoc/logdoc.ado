*! logdoc Version 1.0.0  2026/04/28
*! Convert Stata SMCL/log files to faithful HTML, Markdown, Word, LaTeX, Quarto, or PDF documents
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Syntax:
  logdoc using filename, output(string) [format(string) theme(string)
      title(string) date(string) run preformatted nofold nodots
      fold highlight tables copy download legacy generated
      python(string) css(string) open replace quiet verbose
      footer(string) stamp nograph graphwidth(string) graphheight(string)]

  logdoc start, output(string) [format(string) theme(string) ...]
  logdoc stop

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

    if inlist("`subcmd'", "start", "stop", "diff", "batch", "replay") {
        _logdoc_`subcmd' `rest'
        return add
    }
    else {
        _logdoc_convert `0'
        return add
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
        APPend NOTEbook EMAil ANNotate(string) ///
        FOLD HIGHlight TABles COPY DOWNload LEGacy GENerated]

    * --- U3: quiet/verbose mutual exclusion ---
    if "`quiet'" != "" & "`verbose'" != "" {
        display as error "quiet and verbose are mutually exclusive"
        exit 198
    }

    * --- W4: Read .logdocrc project config file ---
    local _config_python ""
    capture confirm file ".logdocrc"
    if !_rc {
        tempname rcfh
        file open `rcfh' using ".logdocrc", read text
        file read `rcfh' _rcline
        while r(eof) == 0 {
            if regexm(`"`_rcline'"', "^([a-z]+)=(.+)$") {
                local _rckey = regexs(1)
                local _rcval = regexs(2)
                if "`_rckey'" == "python" {
                    if `"`python'"' == "" local _config_python `"`_rcval'"'
                }
                else {
                    if "``_rckey''" == "" local `_rckey' "`_rcval'"
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
        file open `_runfh' using "`_runwrapper_path'", write text replace
        file write `_runfh' "version 16.0" _n
        file write `_runfh' "quietly set linesize 255" _n
        file write `_runfh' `"do "`input_file'""' _n
        file close `_runfh'
        shell stata-mp -b do "`_runwrapper_path'"

        * Find the resulting .smcl log
        * Check both in the .do file's directory and in CWD
        * (stata-mp -b creates log in CWD, not in the .do file's dir)
        local dobase = substr("`input_file'", 1, length("`input_file'") - 3)
        * Extract just the filename without directory for CWD check
        local _fname = "`input_file'"
        local _slashpos = strrpos("`_fname'", "/")
        if `_slashpos' == 0 {
            local _slashpos = strrpos("`_fname'", "\")
        }
        if `_slashpos' > 0 {
            local _cwdbase = substr("`_fname'", `_slashpos' + 1, .)
            local _cwdbase = substr("`_cwdbase'", 1, length("`_cwdbase'") - 3)
        }
        else {
            local _cwdbase "`dobase'"
        }
        local _runbase = substr("`_runwrapper_path'", 1, ///
            length("`_runwrapper_path'") - 3)
        local _runfname "`_runwrapper_path'"
        local _runslashpos = strrpos("`_runfname'", "/")
        if `_runslashpos' == 0 {
            local _runslashpos = strrpos("`_runfname'", "\")
        }
        if `_runslashpos' > 0 {
            local _runcwdbase = substr("`_runfname'", `_runslashpos' + 1, .)
            local _runcwdbase = substr("`_runcwdbase'", 1, ///
                length("`_runcwdbase'") - 3)
        }
        else {
            local _runcwdbase "`_runbase'"
        }

        local smcl_file "`dobase'.smcl"
        local input_file ""

        * Try .do file's directory first
        capture confirm file "`smcl_file'"
        if !_rc {
            local input_file "`smcl_file'"
        }
        * Try CWD if different
        if "`input_file'" == "" & "`_cwdbase'" != "`dobase'" {
            capture confirm file "`_cwdbase'.smcl"
            if !_rc {
                local input_file "`_cwdbase'.smcl"
            }
        }
        * Try .log in do file's directory
        if "`input_file'" == "" {
            capture confirm file "`dobase'.log"
            if !_rc {
                local input_file "`dobase'.log"
            }
        }
        * Try .log in CWD
        if "`input_file'" == "" & "`_cwdbase'" != "`dobase'" {
            capture confirm file "`_cwdbase'.log"
            if !_rc {
                local input_file "`_cwdbase'.log"
            }
        }
        * Try wrapper batch log when the source do-file did not open a log.
        if "`input_file'" == "" {
            capture confirm file "`_runbase'.smcl"
            if !_rc {
                local input_file "`_runbase'.smcl"
                local _runwrapper_was_input 1
            }
        }
        if "`input_file'" == "" & "`_runcwdbase'" != "`_runbase'" {
            capture confirm file "`_runcwdbase'.smcl"
            if !_rc {
                local input_file "`_runcwdbase'.smcl"
                local _runwrapper_was_input 1
            }
        }
        if "`input_file'" == "" {
            capture confirm file "`_runbase'.log"
            if !_rc {
                local input_file "`_runbase'.log"
                local _runwrapper_was_input 1
            }
        }
        if "`input_file'" == "" & "`_runcwdbase'" != "`_runbase'" {
            capture confirm file "`_runcwdbase'.log"
            if !_rc {
                local input_file "`_runcwdbase'.log"
                local _runwrapper_was_input 1
            }
        }
        if "`input_file'" == "" {
            display as error "no log file produced from running `using'"
            display as error "looked for: `smcl_file', `_cwdbase'.smcl, `_runcwdbase'.log"
            exit 601
        }
        if !`_runwrapper_was_input' {
            capture erase "`_runbase'.smcl"
            capture erase "`_runcwdbase'.smcl"
            capture erase "`_runbase'.log"
            capture erase "`_runcwdbase'.log"
        }
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
            local _dotpos = strrpos("`output'", ".")
            if `_dotpos' > 0 {
                local _base = substr("`output'", 1, `_dotpos' - 1)
                local _ext = substr("`output'", `_dotpos', .)
            }
            else {
                local _base "`output'"
                local _ext ""
            }
            * Check both possible secondary files
            if "`_ext'" == ".md" {
                local _secondary "`_base'.html"
            }
            else if "`_ext'" == ".html" {
                local _secondary "`_base'.md"
            }
            else {
                * No extension: Python creates .html and .md variants
                local _secondary "`_base'.html"
                capture confirm file "`_secondary'"
                if !_rc {
                    display as error `"file "`_secondary'" already exists; use replace option"'
                    exit 602
                }
                local _secondary "`_base'.md"
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

    capture findfile logdoc_light.css
    if _rc == 0 {
        local light_css "`r(fn)'"
        if substr("`light_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`light_css'", 2, .)
            local light_css "`homedir'`rest'"
        }
    }

    capture findfile logdoc_dark.css
    if _rc == 0 {
        local dark_css "`r(fn)'"
        if substr("`dark_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`dark_css'", 2, .)
            local dark_css "`homedir'`rest'"
        }
    }

    * Build command (quote python path for paths with spaces)
    local cmd `""`python'" "`scriptpath'" "`input_file'" "`output'""'
    local cmd `"`cmd' --format `format'"'
    local cmd `"`cmd' --theme `theme'"'

    if "`title'" != "" {
        * Write title to tempfile to avoid shell quoting issues
        tempfile titlefile
        tempname fh
        file open `fh' using "`titlefile'", write text
        file write `fh' `"`title'"'
        file close `fh'
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
        tempname fh2
        file open `fh2' using "`datefile'", write text
        file write `fh2' `"`date'"'
        file close `fh2'
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

    * --- U3: Verbose flag ---
    if "`verbose'" != "" {
        local cmd `"`cmd' --verbose"'
    }

    * --- O8: Footer ---
    if `"`footer'"' != "" {
        tempfile footerfile
        tempname fh3
        file open `fh3' using "`footerfile'", write text
        file write `fh3' `"`footer'"'
        file close `fh3'
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
        tempname fh4
        file open `fh4' using "`stampfile'", write text
        file write `fh4' `"`_stamp_str'"'
        file close `fh4'
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
        tempname fh5
        file open `fh5' using "`keepfile'", write text
        file write `fh5' `"`keep'"'
        file close `fh5'
        local cmd `"`cmd' --keep-file "`keepfile'""'
    }
    if `"`drop'"' != "" {
        tempfile dropfile
        tempname fh6
        file open `fh6' using "`dropfile'", write text
        file write `fh6' `"`drop'"'
        file close `fh6'
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
    local _nblocks = 0
    local _filesize = 0
    local _py_lastmsg ""
    capture {
        tempname _pyofh
        file open `_pyofh' using "`_pyout'", read text
        file read `_pyofh' _pyoline
        while r(eof) == 0 {
            if regexm(`"`_pyoline'"', "LOGDOC_META: blocks=([0-9]+) filesize=([0-9]+)") {
                local _nblocks = real(regexs(1))
                local _filesize = real(regexs(2))
            }
            else if strtrim(`"`_pyoline'"') != "" {
                local _trimline = strtrim(`"`_pyoline'"')
                if !regexm(`"`_trimline'"', "^(Generated:|logdoc: processing )") {
                    local _py_lastmsg `"`_trimline'"'
                }
            }
            file read `_pyofh' _pyoline
        }
        file close `_pyofh'
    }

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
        * Try wkhtmltopdf first
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
                display as text "Converting HTML to PDF via wkhtmltopdf..."
            }
            tempfile _wk_stderr
            shell wkhtmltopdf "`_temphtml_path'" "`output'" > /dev/null 2>"`_wk_stderr'"
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
            display as error "wkhtmltopdf is not installed on this system"
            display as error "format(pdf) requires wkhtmltopdf to be on your PATH"
            display as error "use format(html) and print from a browser, or install wkhtmltopdf"
            exit 601
        }
        * Clean up temp HTML
        capture erase "`_temphtml_path'"
    }

    * Verify output
    * For format(both), Python creates .html/.md variants; the raw output
    * path may not exist if it has no extension, so compute expected paths.
    local _secondary_path ""
    if "`format'" == "both" {
        local dotpos = strrpos("`output'", ".")
        if `dotpos' > 0 {
            local outbase = substr("`output'", 1, `dotpos' - 1)
            local primary_ext = substr("`output'", `dotpos', .)
        }
        else {
            local outbase "`output'"
            local primary_ext ""
        }
        if "`primary_ext'" == ".md" {
            local primary_file "`outbase'.md"
            local secondary "`outbase'.html"
        }
        else if "`primary_ext'" == ".html" {
            local primary_file "`outbase'.html"
            local secondary "`outbase'.md"
        }
        else {
            * No extension: Python creates .html and .md
            local primary_file "`outbase'.html"
            local secondary "`outbase'.md"
        }
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

    * --- W3: Store normalized args for replay (only on success) ---
    local _replay_args `"using "`using'", output("`output'") format(`format') theme(`theme')"'
    if `"`title'"' != "" {
        local _replay_args `"`_replay_args' title("`title'")"'
    }
    if `"`date'"' != "" {
        local _replay_args `"`_replay_args' date("`date'")"'
    }
    if "`preformatted'" != "" {
        local _replay_args `"`_replay_args' preformatted"'
    }
    if "`nofold'" != "" {
        local _replay_args `"`_replay_args' nofold"'
    }
    if "`nodots'" != "" {
        local _replay_args `"`_replay_args' nodots"'
    }
    if `"`python'"' != "" {
        local _replay_args `"`_replay_args' python("`python'")"'
    }
    if `"`css'"' != "" {
        local _replay_args `"`_replay_args' css("`css'")"'
    }
    if "`quiet'" != "" {
        local _replay_args `"`_replay_args' quiet"'
    }
    if "`verbose'" != "" {
        local _replay_args `"`_replay_args' verbose"'
    }
    if "`replace'" != "" {
        local _replay_args `"`_replay_args' replace"'
    }
    if `"`footer'"' != "" {
        local _replay_args `"`_replay_args' footer("`footer'")"'
    }
    if "`stamp'" != "" {
        local _replay_args `"`_replay_args' stamp"'
    }
    if "`nograph'" != "" {
        local _replay_args `"`_replay_args' nograph"'
    }
    if `"`graphwidth'"' != "" {
        local _replay_args `"`_replay_args' graphwidth("`graphwidth'")"'
    }
    if `"`graphheight'"' != "" {
        local _replay_args `"`_replay_args' graphheight("`graphheight'")"'
    }
    if "`linenumbers'" != "" {
        local _replay_args `"`_replay_args' linenumbers"'
    }
    if "`toc'" != "" {
        local _replay_args `"`_replay_args' toc"'
    }
    if "`fold'" != "" {
        local _replay_args `"`_replay_args' fold"'
    }
    if "`highlight'" != "" {
        local _replay_args `"`_replay_args' highlight"'
    }
    if "`tables'" != "" {
        local _replay_args `"`_replay_args' tables"'
    }
    if "`copy'" != "" {
        local _replay_args `"`_replay_args' copy"'
    }
    if "`download'" != "" {
        local _replay_args `"`_replay_args' download"'
    }
    if "`legacy'" != "" {
        local _replay_args `"`_replay_args' legacy"'
    }
    if `"`keep'"' != "" {
        local _replay_args `"`_replay_args' keep("`keep'")"'
    }
    if `"`drop'"' != "" {
        local _replay_args `"`_replay_args' drop("`drop'")"'
    }
    if "`append'" != "" {
        local _replay_args `"`_replay_args' append"'
    }
    if "`notebook'" != "" {
        local _replay_args `"`_replay_args' notebook"'
    }
    if "`email'" != "" {
        local _replay_args `"`_replay_args' email"'
    }
    if `"`annotate'"' != "" {
        local _replay_args `"`_replay_args' annotate("`annotate'")"'
    }
    if "`generated'" != "" {
        local _replay_args `"`_replay_args' generated"'
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
    * --- I5: Return secondary path ---
    if "`_secondary_path'" != "" {
        return local secondary "`_secondary_path'"
    }
    * --- I1: Return metadata ---
    return scalar nblocks = `_nblocks'
    return scalar filesize = `_filesize'

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
        FOLD HIGHlight TABles COPY DOWNload LEGacy GENerated]

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
    * is not available in Stata 17)
    local _ts = subinstr(c(current_time), ":", "", .)
    local _rand = string(floor(runiform() * 1000000000), "%09.0f")
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
                LOGDOC_REPLACE LOGDOC_APPEND LOGDOC_QUIET LOGDOC_VERBOSE LOGDOC_FOOTER ///
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
        LOGDOC_REPLACE LOGDOC_APPEND LOGDOC_QUIET LOGDOC_VERBOSE LOGDOC_FOOTER ///
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
        KEEP(string) DROP(string) ANNotate(string) APPend ///
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
    if `"`python'"' != "" local _opts `"`_opts' python("`python'")"'
    if `"`footer'"' != "" local _opts `"`_opts' footer("`footer'")"'
    if "`graphwidth'" != "" local _opts `"`_opts' graphwidth(`graphwidth')"'
    if "`graphheight'" != "" local _opts `"`_opts' graphheight(`graphheight')"'
    if `"`keep'"' != "" local _opts `"`_opts' keep("`keep'")"'
    if `"`drop'"' != "" local _opts `"`_opts' drop("`drop'")"'
    if `"`annotate'"' != "" local _opts `"`_opts' annotate("`annotate'")"'
    if "`append'" != "" local _opts `"`_opts' append"'

    * Determine file extension for output
    local _outext ".html"
    if "`format'" == "md" local _outext ".md"
    else if "`format'" == "qmd" local _outext ".qmd"
    else if "`format'" == "tex" local _outext ".tex"
    else if "`format'" == "docx" local _outext ".docx"
    else if "`format'" == "pdf" local _outext ".pdf"

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
        [REPlace THeme(string) PYthon(string) CSS(string) Quiet]

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
    capture findfile logdoc_light.css
    if _rc == 0 {
        local light_css "`r(fn)'"
        if substr("`light_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`light_css'", 2, .)
            local light_css "`homedir'`rest'"
        }
    }
    capture findfile logdoc_dark.css
    if _rc == 0 {
        local dark_css "`r(fn)'"
        if substr("`dark_css'", 1, 1) == "~" {
            local homedir : environment HOME
            local rest = substr("`dark_css'", 2, .)
            local dark_css "`homedir'`rest'"
        }
    }

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

    if "`quiet'" == "" {
        display as text "Generating diff document..."
    }
    tempfile _pyout
    shell `cmd' > "`_pyout'" 2>&1

    local _py_lastmsg ""
    capture {
        tempname _pyofh
        file open `_pyofh' using "`_pyout'", read text
        file read `_pyofh' _pyoline
        while r(eof) == 0 {
            if strtrim(`"`_pyoline'"') != "" {
                local _trimline = strtrim(`"`_pyoline'"')
                if !regexm(`"`_trimline'"', "^(Generated:|logdoc: processing )") {
                    local _py_lastmsg `"`_trimline'"'
                }
            }
            file read `_pyofh' _pyoline
        }
        file close `_pyofh'
    }

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

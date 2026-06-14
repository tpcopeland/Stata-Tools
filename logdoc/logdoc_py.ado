*! logdoc_py Version 1.0.2  2026/06/14
*! Find, check, and save Python configuration for logdoc
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define logdoc_py, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax [, CHeck SET SAVE INSTall(string) PYthon(string) PDF ///
        REPlace DRYrun Quiet Verbose]

    if "`quiet'" != "" & "`verbose'" != "" {
        display as error "quiet and verbose are mutually exclusive"
        exit 198
    }

    local _nactions = ("`check'" != "") + ("`set'" != "") + ///
        ("`save'" != "") + (`"`install'"' != "")
    if `_nactions' > 1 {
        display as error "only one of check, set, save, and install() may be specified"
        exit 198
    }
    if `_nactions' == 0 local check "check"

    if "`replace'" != "" & "`save'" == "" {
        display as error "replace may only be specified with save"
        exit 198
    }
    if "`dryrun'" != "" & `"`install'"' == "" {
        display as error "dryrun may only be specified with install()"
        exit 198
    }

    local action "check"
    if "`set'" != "" local action "set"
    if "`save'" != "" local action "save"
    if `"`install'"' != "" local action "install"

    _logdoc_py_select, python(`"`python'"') ///
        selected(_selected) version(_version) source(_source) ///
        renderer(_renderer) config(_config_path) configread(_config_read) ///
        `verbose'

    if `"`_selected'"' == "" {
        display as error "Python 3.6+ not found"
        display as error "run logdoc_py, verbose to see candidate checks"
        exit 601
    }

    local _pdf_ok .
    local _xhtml2pdf ""
    local _wkhtmltopdf ""
    if "`pdf'" != "" {
        _logdoc_py_check_xhtml2pdf, python(`"`_selected'"') `verbose'
        local _xhtml2pdf = r(ok)
        _logdoc_py_check_pdf, path(_wkhtmltopdf) `verbose'
        local _wk_ok = r(ok)
        if `_xhtml2pdf' == 1 | `_wk_ok' == 1 {
            local _pdf_ok = 1
        }
        else {
            local _pdf_ok = 0
            display as error "no PDF converter found"
            display as error "install xhtml2pdf: logdoc_py, install(xhtml2pdf)"
            display as error "or install wkhtmltopdf as a system package"
            exit 601
        }
    }

    local _installed .
    local _required ""
    local _optional ""
    local _missing ""
    local _install_cmd ""
    if "`action'" == "set" {
        global LOGDOC_PYTHON `"`_selected'"'
        if "`quiet'" == "" {
            display as result `"LOGDOC_PYTHON set to: `_selected'"'
        }
    }
    else if "`action'" == "save" {
        _logdoc_py_save_config, python(`"`_selected'"') `replace'
        local _config_path "`r(config)'"
        local _config_read 1
        if "`quiet'" == "" {
            display as result `"saved Python path to `_config_path'"'
        }
    }
    else if "`action'" == "install" {
        _logdoc_py_install, python(`"`_selected'"') install(`"`install'"') ///
            source("`_source'") `dryrun' `quiet' `verbose'
        local _installed = r(installed)
        local _required "`r(required)'"
        local _optional "`r(optional)'"
        local _missing "`r(missing)'"
        local _install_cmd `"`r(install_cmd)'"'
    }

    if "`quiet'" == "" & "`action'" != "install" {
        display as result "logdoc Python check passed"
        display as text   `"  Python:  `_selected'"'
        display as text   `"  Version: `_version'"'
        display as text   `"  Source:  `_source'"'
        display as text   `"  Renderer: `_renderer'"'
        if "`pdf'" != "" {
            if `_xhtml2pdf' == 1 {
                display as text "  xhtml2pdf:   installed (preferred)"
            }
            else {
                display as text "  xhtml2pdf:   not installed"
            }
            if `"`_wkhtmltopdf'"' != "" {
                display as text `"  wkhtmltopdf: `_wkhtmltopdf'"'
            }
            else {
                display as text "  wkhtmltopdf: not found"
            }
        }
    }

    return scalar ok = 1
    return scalar python_ok = 1
    return scalar renderer_ok = ("`_renderer'" != "")
    if "`pdf'" != "" return scalar pdf_ok = `_pdf_ok'
    if "`action'" == "install" return scalar installed = `_installed'

    return local python `"`_selected'"'
    return local python_version `"`_version'"'
    return local python_source "`_source'"
    return local renderer `"`_renderer'"'
    if `_config_read' == 1 | `"`_config_path'"' != "" {
        return local config `"`_config_path'"'
    }
    if "`pdf'" != "" {
        if `_xhtml2pdf' == 1 return local xhtml2pdf "installed"
        if `"`_wkhtmltopdf'"' != "" {
            return local wkhtmltopdf `"`_wkhtmltopdf'"'
        }
    }
    return local required "`_required'"
    return local optional "`_optional'"
    return local missing "`_missing'"
    if `"`_install_cmd'"' != "" {
        return local install_cmd `"`_install_cmd'"'
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_select
program define _logdoc_py_select
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , selected(name) version(name) source(name) renderer(name) ///
        config(name) configread(name) [PYthon(string) Verbose]

    local scriptpath ""
    _logdoc_py_find_script, result(scriptpath)
    if "`scriptpath'" == "" {
        display as error "logdoc_render.py not found"
        display as error "ensure logdoc is properly installed"
        exit 601
    }

    local config_python ""
    local config_path ""
    local read_config 0
    _logdoc_py_read_config, result(config_python) path(config_path) ///
        read(read_config)

    local n = 0
    if `"`python'"' != "" {
        local ++n
        local cand`n' `"`python'"'
        local src`n' "option"
    }
    else {
        local ++n
        local cand`n' "Stata python:"
        local src`n' "stata"
        if `"$LOGDOC_PYTHON"' != "" {
            local ++n
            local cand`n' `"$LOGDOC_PYTHON"'
            local src`n' "global"
        }
        if `"`config_python'"' != "" {
            local ++n
            local cand`n' `"`config_python'"'
            local src`n' "config"
        }
        if "`c(os)'" == "Windows" {
            foreach default in "py -3" "python" "python3" {
                local ++n
                local cand`n' `"`default'"'
                local src`n' "path"
            }
        }
        else {
            foreach default in "python3" "python" {
                local ++n
                local cand`n' `"`default'"'
                local src`n' "path"
            }
        }
    }

    local chosen ""
    local chosen_version ""
    local chosen_source ""
    forvalues i = 1/`n' {
        local _cand_i `"`cand`i''"'
        local _src_i "`src`i''"
        if "`verbose'" != "" {
            display as text `"checking Python candidate (`_src_i'): `_cand_i'"'
        }
        if "`_src_i'" == "stata" {
            capture noisily _logdoc_py_check_stata, ///
                renderer(`"`scriptpath'"') `verbose'
        }
        else {
            capture noisily _logdoc_py_check_candidate, ///
                python(`"`_cand_i'"') ///
                source("`_src_i'") renderer(`"`scriptpath'"') `verbose'
        }
        if _rc == 0 & r(ok) == 1 {
            local chosen `"`r(python)'"'
            local chosen_version `"`r(version)'"'
            local chosen_source "`r(source)'"
            continue, break
        }
    }

    c_local `selected' `"`chosen'"'
    c_local `version' `"`chosen_version'"'
    c_local `source' "`chosen_source'"
    c_local `renderer' `"`scriptpath'"'
    c_local `config' `"`config_path'"'
    c_local `configread' `read_config'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_check_stata
program define _logdoc_py_check_stata, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , renderer(string) [Verbose]

    local _stata_pyexec ""
    local _stata_pyversion ""
    local _renderer_rc "1"
    local _renderer_usage "0"
    local _renderer_lastmsg ""

    tempfile pyscript
    local pyscript_path "`pyscript'.py"
    tempname pfh
    quietly file open `pfh' using "`pyscript_path'", write text replace
    file write `pfh' "from sfi import Macro" _n
    file write `pfh' "import argparse, base64, datetime, difflib, html, mimetypes, os, re, subprocess, sys" _n
    file write `pfh' "Macro.setLocal('_stata_pyexec', sys.executable)" _n
    file write `pfh' `"Macro.setLocal('_stata_pyversion', 'Python ' + sys.version.split()[0])"' _n
    file write `pfh' "renderer = Macro.getLocal('renderer')" _n
    file write `pfh' "try:" _n
    file write `pfh' "    completed = subprocess.run([sys.executable, renderer, '--help'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)" _n
    file write `pfh' "    Macro.setLocal('_renderer_rc', str(completed.returncode))" _n
    file write `pfh' `"    Macro.setLocal('_renderer_usage', '1' if 'usage:' in completed.stdout else '0')"' _n
    file write `pfh' `"    Macro.setLocal('_renderer_lastmsg', completed.stdout.strip().splitlines()[-1] if completed.stdout.strip() else '')"' _n
    file write `pfh' "except Exception as exc:" _n
    file write `pfh' "    Macro.setLocal('_renderer_rc', '1')" _n
    file write `pfh' "    Macro.setLocal('_renderer_usage', '0')" _n
    file write `pfh' "    Macro.setLocal('_renderer_lastmsg', str(exc))" _n
    file close `pfh'

    capture quietly python script "`pyscript_path'"
    local stata_rc = _rc
    capture erase "`pyscript_path'"
    if `stata_rc' {
        if "`verbose'" != "" {
            display as text "  rejected: Stata python: is not configured or failed to initialize"
        }
        return scalar ok = 0
        exit 0
    }

    if `"`_stata_pyexec'"' == "" {
        if "`verbose'" != "" {
            display as text "  rejected: Stata python: did not report sys.executable"
        }
        return scalar ok = 0
        exit 0
    }

    if !regexm(`"`_stata_pyversion'"', "Python[ ]+([0-9]+)\.([0-9]+)(\.([0-9]+))?") {
        if "`verbose'" != "" {
            display as text `"  rejected: did not report a Python version (`_stata_pyversion')"'
        }
        return scalar ok = 0
        exit 0
    }

    local major = real(regexs(1))
    local minor = real(regexs(2))
    if `major' < 3 | (`major' == 3 & `minor' < 6) {
        if "`verbose'" != "" {
            display as text `"  rejected: Python `major'.`minor' is older than 3.6"'
        }
        return scalar ok = 0
        exit 0
    }

    if "`_renderer_rc'" != "0" | "`_renderer_usage'" != "1" {
        if "`verbose'" != "" {
            display as text "  rejected: renderer smoke check failed through Stata python:"
            if `"`_renderer_lastmsg'"' != "" {
                display as text `"    `_renderer_lastmsg'"'
            }
        }
        return scalar ok = 0
        exit 0
    }

    if "`verbose'" != "" {
        display as text `"  accepted: `_stata_pyversion' (`_stata_pyexec')"'
    }
    return scalar ok = 1
    return local python `"`_stata_pyexec'"'
    return local source "stata"
    return local version `"`_stata_pyversion'"'

    }
    local rc = _rc
    capture file close `pfh'
    capture erase "`pyscript_path'"
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_check_candidate
program define _logdoc_py_check_candidate, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , PYthon(string) source(string) renderer(string) [Verbose]

    local cmdprefix `""`python'""'
    if `"`python'"' == "py -3" local cmdprefix "py -3"
    if `"`python'"' == "py -3" & "`c(os)'" != "Windows" {
        if "`verbose'" != "" {
            display as text "  rejected: py -3 is only checked on Windows"
        }
        return scalar ok = 0
        exit 0
    }

    tempfile pyver pyimport pysmoke
    local pathlike = strpos(`"`python'"', "/") > 0 | ///
        strpos(`"`python'"', "\") > 0 | inlist(substr(`"`python'"', 1, 1), ".", "~")
    if `pathlike' {
        local checkpath `"`python'"'
        _logdoc_py_expand_tilde, path(`"`checkpath'"') result(checkpath)
        capture confirm file "`checkpath'"
        if _rc {
            if "`verbose'" != "" {
                display as text `"  rejected: executable not found (`python')"'
            }
            return scalar ok = 0
            exit 0
        }
    }
    else if `"`python'"' != "py -3" {
        tempfile cmdcheck
        if "`c(os)'" == "Windows" {
            quietly shell where "`python'" > "`cmdcheck'" 2>&1
        }
        else {
            quietly shell command -v "`python'" > "`cmdcheck'" 2>&1
        }
        _logdoc_py_first_line using "`cmdcheck'"
        if `"`r(line)'"' == "" | regexm(lower(`"`r(line)'"'), "not found") {
            if "`verbose'" != "" {
                display as text `"  rejected: command not found (`python')"'
            }
            return scalar ok = 0
            exit 0
        }
    }

    quietly shell `cmdprefix' --version > "`pyver'" 2>&1
    _logdoc_py_first_line using "`pyver'"
    local version_line `"`r(line)'"'

    if !regexm(`"`version_line'"', "Python[ ]+([0-9]+)\.([0-9]+)(\.([0-9]+))?") {
        if "`verbose'" != "" {
            display as text `"  rejected: did not report a Python version (`version_line')"'
        }
        return scalar ok = 0
        exit 0
    }

    local major = real(regexs(1))
    local minor = real(regexs(2))
    if `major' < 3 | (`major' == 3 & `minor' < 6) {
        if "`verbose'" != "" {
            display as text `"  rejected: Python `major'.`minor' is older than 3.6"'
        }
        return scalar ok = 0
        exit 0
    }

    quietly shell `cmdprefix' -c "import argparse,base64,datetime,difflib,html,mimetypes,os,re,sys; print('ok')" > "`pyimport'" 2>&1
    _logdoc_py_first_line using "`pyimport'"
    if `"`r(line)'"' != "ok" {
        if "`verbose'" != "" {
            display as text "  rejected: required standard-library imports failed"
        }
        return scalar ok = 0
        exit 0
    }

    quietly shell `cmdprefix' "`renderer'" --help > "`pysmoke'" 2>&1
    _logdoc_py_file_contains using "`pysmoke'", pattern("usage:")
    if r(found) != 1 {
        if "`verbose'" != "" {
            display as text "  rejected: renderer smoke check failed"
        }
        return scalar ok = 0
        exit 0
    }

    if "`verbose'" != "" {
        display as text `"  accepted: `version_line'"'
    }
    return scalar ok = 1
    return local python `"`python'"'
    return local source "`source'"
    return local version `"`version_line'"'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_find_script
program define _logdoc_py_find_script
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , result(name)

    capture findfile logdoc_render.py
    if _rc == 0 {
        local path "`r(fn)'"
        _logdoc_py_expand_tilde, path(`"`path'"') result(path)
        capture confirm file "`path'"
        if !_rc {
            c_local `result' `"`path'"'
            exit 0
        }
    }

    foreach ado in logdoc_py.ado logdoc.ado {
        capture findfile `ado'
        if _rc == 0 {
            local adopath "`r(fn)'"
            _logdoc_py_expand_tilde, path(`"`adopath'"') result(adopath)
            _logdoc_py_dirname, path(`"`adopath'"') result(adodir)
            if "`adodir'" != "" {
                capture confirm file "`adodir'/logdoc_render.py"
                if !_rc {
                    c_local `result' `"`adodir'/logdoc_render.py"'
                    exit 0
                }
            }
        }
    }

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

    c_local `result' ""

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_read_config
program define _logdoc_py_read_config
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , result(name) path(name) read(name)

    local cfg ".logdocrc"
    local value ""
    local read_file 0
    capture confirm file "`cfg'"
    if !_rc {
        local read_file 1
        tempname fh
        file open `fh' using "`cfg'", read text
        file read `fh' line
        while r(eof) == 0 {
            if regexm(`"`line'"', "^[ 	]*python[ 	]*=(.*)$") {
                local value = strtrim(regexs(1))
            }
            file read `fh' line
        }
        file close `fh'
    }

    c_local `result' `"`value'"'
    if `read_file' == 1 {
        c_local `path' "`cfg'"
    }
    else {
        c_local `path' ""
    }
    c_local `read' `read_file'

    }
    local rc = _rc
    capture file close `fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_save_config
program define _logdoc_py_save_config, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , PYthon(string) [REPlace]

    local cfg ".logdocrc"
    local exists 0
    capture confirm file "`cfg'"
    if !_rc local exists 1

    tempfile cfgnew
    tempname infh outfh
    local saw_python 0
    local wrote_python 0

    quietly file open `outfh' using "`cfgnew'", write text replace
    if `exists' == 1 {
        file open `infh' using "`cfg'", read text
        file read `infh' line
        while r(eof) == 0 {
            if regexm(`"`line'"', "^[ 	]*python[ 	]*=") {
                local saw_python 1
                if "`replace'" == "" {
                    display as error ".logdocrc already contains python=; specify replace to update it"
                    exit 602
                }
                if `wrote_python' == 0 {
                    file write `outfh' `"python=`python'"' _n
                    local wrote_python 1
                }
            }
            else {
                file write `outfh' `"`line'"' _n
            }
            file read `infh' line
        }
        file close `infh'
    }
    if `saw_python' == 0 {
        file write `outfh' `"python=`python'"' _n
    }
    file close `outfh'

    quietly copy "`cfgnew'" "`cfg'", replace
    confirm file "`cfg'"

    return local config "`cfg'"

    }
    local rc = _rc
    capture file close `infh'
    capture file close `outfh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_check_xhtml2pdf
program define _logdoc_py_check_xhtml2pdf, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , python(string) [Verbose]

    tempfile _xh2p_out
    quietly shell "`python'" -c "from xhtml2pdf import pisa; print('OK')" ///
        > "`_xh2p_out'" 2>&1
    _logdoc_py_first_line using "`_xh2p_out'"
    local found `"`r(line)'"'

    if `"`found'"' == "OK" {
        return scalar ok = 1
        if "`verbose'" != "" {
            display as text "xhtml2pdf: installed"
        }
    }
    else {
        return scalar ok = 0
        if "`verbose'" != "" {
            display as text "xhtml2pdf: not installed"
        }
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_check_pdf
program define _logdoc_py_check_pdf, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , path(name) [Verbose]

    tempfile wkout
    if "`c(os)'" == "Windows" {
        quietly shell where wkhtmltopdf > "`wkout'" 2>&1
    }
    else {
        quietly shell command -v wkhtmltopdf > "`wkout'" 2>&1
    }
    _logdoc_py_first_line using "`wkout'"
    local found `"`r(line)'"'

    if `"`found'"' == "" | regexm(lower(`"`found'"'), "not found") {
        c_local `path' ""
        return scalar ok = 0
        exit 0
    }

    c_local `path' `"`found'"'
    return scalar ok = 1
    return local wkhtmltopdf `"`found'"'
    if "`verbose'" != "" {
        display as text `"wkhtmltopdf found: `found'"'
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_install
program define _logdoc_py_install, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , PYthon(string) INSTall(string) [source(string) DRYrun Quiet Verbose]

    local required ""
    local optional ""
    local missing ""
    local install_l = lower(strtrim(`"`install'"'))
    local packages `"`install'"'
    if inlist("`install_l'", "required", "optional", "all") {
        local packages ""
    }

    local cmdprefix `""`python'""'
    if `"`python'"' == "py -3" local cmdprefix "py -3"

    if `"`packages'"' == "" {
        if "`quiet'" == "" {
            display as result "logdoc has no Python packages to install"
        }
        return scalar installed = 0
        return local required "`required'"
        return local optional "`optional'"
        return local missing "`missing'"
        return local install_cmd ""
        exit 0
    }

    if "`source'" == "stata" {
        local install_cmd `"`python' -m pip install `packages' (via Stata python:)"'
    }
    else {
        local install_cmd `"`cmdprefix' -m pip install `packages'"'
    }
    if "`dryrun'" != "" {
        if "`quiet'" == "" {
            display as text `"would run: `install_cmd'"'
        }
        return scalar installed = .
        return local required "`required'"
        return local optional "`optional'"
        return local missing "`missing'"
        return local install_cmd `"`install_cmd'"'
        exit 0
    }

    if "`source'" == "stata" {
        local _pip_status "1"
        local _pip_last ""
        tempfile pyscript
        local pyscript_path "`pyscript'.py"
        tempname pfh
        quietly file open `pfh' using "`pyscript_path'", write text replace
        file write `pfh' "from sfi import Macro" _n
        file write `pfh' "import subprocess, sys" _n
        file write `pfh' "packages = Macro.getLocal('packages').split()" _n
        file write `pfh' "completed = subprocess.run([sys.executable, '-m', 'pip', 'install'] + packages, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)" _n
        file write `pfh' "Macro.setLocal('_pip_status', str(completed.returncode))" _n
        file write `pfh' `"Macro.setLocal('_pip_last', completed.stdout.strip().splitlines()[-1] if completed.stdout.strip() else '')"' _n
        file close `pfh'

        if "`quiet'" == "" {
            display as text `"running through Stata python:: `python' -m pip install `packages'"'
        }
        capture quietly python script "`pyscript_path'"
        local stata_rc = _rc
        capture erase "`pyscript_path'"
        if `stata_rc' | "`_pip_status'" != "0" {
            display as error "pip install failed"
            if `"`_pip_last'"' != "" {
                display as error `"`_pip_last'"'
            }
            exit 601
        }
    }
    else {
        tempfile pipout pipstatus
        if "`quiet'" == "" {
            display as text `"running: `install_cmd'"'
        }
        quietly shell `install_cmd' > "`pipout'" 2>&1 && echo 0 > "`pipstatus'" || echo 1 > "`pipstatus'"
        _logdoc_py_first_line using "`pipstatus'"
        local status "`r(line)'"
        if "`status'" != "0" {
            display as error "pip install failed"
            _logdoc_py_last_line using "`pipout'"
            if `"`r(line)'"' != "" {
                display as error `"`r(line)'"'
            }
            exit 601
        }
    }

    if "`quiet'" == "" {
        display as result "pip install completed"
    }
    return scalar installed = 1
    return local required "`required'"
    return local optional "`optional'"
    return local missing "`missing'"
    return local install_cmd `"`install_cmd'"'

    }
    local rc = _rc
    capture file close `pfh'
    capture erase "`pyscript_path'"
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_first_line
program define _logdoc_py_first_line, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax using/

    local first ""
    capture confirm file "`using'"
    if !_rc {
        tempname fh
        file open `fh' using "`using'", read text
        file read `fh' line
        while r(eof) == 0 {
            local candidate = strtrim(`"`line'"')
            if `"`candidate'"' != "" {
                local first `"`candidate'"'
                continue, break
            }
            file read `fh' line
        }
        file close `fh'
    }

    return local line `"`first'"'

    }
    local rc = _rc
    capture file close `fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_last_line
program define _logdoc_py_last_line, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax using/

    local last ""
    capture confirm file "`using'"
    if !_rc {
        tempname fh
        file open `fh' using "`using'", read text
        file read `fh' line
        while r(eof) == 0 {
            local candidate = strtrim(`"`line'"')
            if `"`candidate'"' != "" local last `"`candidate'"'
            file read `fh' line
        }
        file close `fh'
    }

    return local line `"`last'"'

    }
    local rc = _rc
    capture file close `fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_file_contains
program define _logdoc_py_file_contains, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax using/ , pattern(string)

    local found 0
    capture confirm file "`using'"
    if !_rc {
        tempname fh
        file open `fh' using "`using'", read text
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`line'"', `"`pattern'"') > 0 {
                local found 1
                continue, break
            }
            file read `fh' line
        }
        file close `fh'
    }

    return scalar found = `found'

    }
    local rc = _rc
    capture file close `fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_expand_tilde
program define _logdoc_py_expand_tilde
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , path(string) result(name)

    local expanded `"`path'"'
    if substr(`"`expanded'"', 1, 1) == "~" {
        local homedir : environment HOME
        local rest = substr(`"`expanded'"', 2, .)
        local expanded `"`homedir'`rest'"'
    }
    c_local `result' `"`expanded'"'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


capture program drop _logdoc_py_dirname
program define _logdoc_py_dirname
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax , path(string) result(name)

    local slash = strrpos(`"`path'"', "/")
    if `slash' == 0 {
        local slash = strrpos(`"`path'"', "\")
    }
    if `slash' > 0 {
        local dir = substr(`"`path'"', 1, `slash' - 1)
    }
    else {
        local dir ""
    }
    c_local `result' `"`dir'"'

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

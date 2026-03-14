*! _tabtools_common Version 1.0.4  2026/03/14
*! Shared utility programs for tabtools package
*! Author: Timothy P Copeland

/*
DESCRIPTION:
    Common utility programs shared across the tabtools suite of table export
    commands. These utilities handle Excel column letter conversion, path
    validation, and p-value formatting.

PROGRAMS INCLUDED:
    _tabtools_col_letter     - Convert column number to Excel letter (A, B, ..., Z, AA, AB, ...)
    _tabtools_validate_path  - Validate file path for dangerous characters

USAGE:
    These programs are called internally by tabtools commands (table1_tc, regtab,
    effecttab, gcomptab, stratetab, tablex). They are not intended for direct use.
*/

* =============================================================================
* _tabtools_col_letter: Convert column number to Excel letter reference
* =============================================================================
* Converts 1 -> A, 2 -> B, ..., 26 -> Z, 27 -> AA, 28 -> AB, etc.
* Returns result in c_local variable 'result'
*
* Usage: _tabtools_col_letter 3
*        local my_letter = "`result'"   // my_letter = "C"

program _tabtools_col_letter
    version 16.0
    set varabbrev off
    set more off
    args col_num

    local col_letter = ""
    local temp_num = `col_num'

    while `temp_num' > 0 {
        local remainder = mod(`temp_num' - 1, 26)
        local col_letter = char(`remainder' + 65) + "`col_letter'"
        local temp_num = floor((`temp_num' - 1) / 26)
    }

    c_local result "`col_letter'"
end

* =============================================================================
* _tabtools_validate_path: Validate file path for security
* =============================================================================
* Checks for dangerous characters that could enable command injection.
* Returns error code 198 if invalid characters found.
*
* Usage: _tabtools_validate_path "`filepath'" "xlsx()"
*        (exits with error if invalid)

program _tabtools_validate_path
    version 16.0
    set varabbrev off
    set more off
    args filepath option_name

    * Check for shell metacharacters and command injection vectors
    if regexm("`filepath'", "[;&|><\$\`]") {
        display as error "`option_name' contains invalid characters"
        exit 198
    }
end

* =============================================================================
* _tabtools_build_col_letters: Build list of Excel column letters for N columns
* =============================================================================
* Creates a space-separated list of column letters for columns 1 to N.
* Returns result in c_local variable 'result'
*
* Usage: _tabtools_build_col_letters 30
*        local letters = "`result'"   // letters = "A B C ... AA AB AC AD"

program _tabtools_build_col_letters
    version 16.0
    set varabbrev off
    set more off
    args num_cols

    local col_letters ""

    forvalues i = 1/`num_cols' {
        _tabtools_col_letter `i'
        local col_letters = "`col_letters' `result'"
    }

    * Trim leading space
    local col_letters = strtrim("`col_letters'")

    c_local result "`col_letters'"
end

* =============================================================================
* _tabtools_sparkline: Generate a sparkline PNG for a variable
* =============================================================================
* Creates a small distribution plot (kdensity, histogram, or bar chart)
* saved as a PNG file for embedding in Excel via putexcel picture().
*
* Usage: _tabtools_sparkline varname [if], type(contn) savepath("path.png")
*        [width(120) height(35) sparktype(kdensity)]

program _tabtools_sparkline
    version 16.0
    set varabbrev off
    set more off

    syntax varname [if], type(string) savepath(string) ///
        [width(integer 40) height(integer 12) sparktype(string)]

    if "`sparktype'" == "" local sparktype "kdensity"

    * preserve/restore wraps all data modifications; the outer capture block
    * ensures restore always runs even if graph generation fails
    preserve

    if `"`if'"' != "" qui keep `if'
    qui drop if missing(`varlist')

    qui count
    if r(N) < 2 {
        restore
        exit
    }

    capture {
        if inlist("`type'", "contn", "contln", "conts") {
            if "`type'" == "contln" {
                qui replace `varlist' = ln(`varlist')
                qui drop if missing(`varlist')
            }

            if "`sparktype'" == "histogram" {
                twoway histogram `varlist', ///
                    color(navy%60) lcolor(navy%80) lwidth(vthin) ///
                    scheme(plotplainblind) ///
                    xscale(off noline) yscale(off noline) ///
                    xlabel(none) ylabel(none) ///
                    legend(off) ///
                    graphregion(margin(zero) color(white)) ///
                    plotregion(margin(zero) style(none)) ///
                    title("") subtitle("") note("") caption("")
            }
            else {
                twoway kdensity `varlist', ///
                    color(navy%60) lcolor(navy) lwidth(medthin) ///
                    recast(area) ///
                    scheme(plotplainblind) ///
                    xscale(off noline) yscale(off noline) ///
                    xlabel(none) ylabel(none) ///
                    legend(off) ///
                    graphregion(margin(zero) color(white)) ///
                    plotregion(margin(zero) style(none)) ///
                    title("") subtitle("") note("") caption("")
            }
        }
        else if inlist("`type'", "cat", "cate") {
            tempvar catvar
            capture confirm numeric variable `varlist'
            if !_rc qui clonevar `catvar' = `varlist'
            else qui encode `varlist', gen(`catvar')

            contract `catvar'
            qui egen _total = total(_freq)
            qui gen _prop = _freq / _total

            twoway bar _prop `catvar', ///
                color(navy%60) lcolor(navy%80) lwidth(vthin) ///
                barwidth(0.7) ///
                scheme(plotplainblind) ///
                xscale(off noline) yscale(off noline) ///
                xlabel(none) ylabel(none) ///
                legend(off) ///
                graphregion(margin(zero) color(white)) ///
                plotregion(margin(zero) style(none)) ///
                title("") subtitle("") note("") caption("")
        }
        else if inlist("`type'", "bin", "bine") {
            contract `varlist'
            qui egen _total = total(_freq)
            qui gen _prop = _freq / _total

            twoway bar _prop `varlist', ///
                color(navy%60) lcolor(navy%80) lwidth(vthin) ///
                barwidth(0.7) ///
                scheme(plotplainblind) ///
                xscale(off noline) yscale(off noline) ///
                xlabel(none) ylabel(none) ///
                legend(off) ///
                graphregion(margin(zero) color(white)) ///
                plotregion(margin(zero) style(none)) ///
                title("") subtitle("") note("") caption("")
        }

        qui graph export "`savepath'", width(`width') height(`height') replace
        capture graph drop _all
    }

    restore
end

* =============================================================================
* _tabtools_center_sparklines: Center sparkline images within their cells
* =============================================================================
* Post-processes an Excel file to add horizontal and vertical offsets to
* sparkline images so they appear centered in their cells rather than
* anchored at the top-left corner.
*
* Uses Python (stdlib only: zipfile, xml.etree) to modify the drawing XML
* inside the xlsx archive. Requires Python 3 on PATH.
*
* Usage: _tabtools_center_sparklines "filepath.xlsx" col_width_chars row_height_pts

program _tabtools_center_sparklines
    version 16.0
    set varabbrev off
    set more off
    args filepath col_width row_height

    * Build Python script as a temp file
    tempfile pyscript
    tempname fh

    file open `fh' using "`pyscript'", write text replace
    file write `fh' `"import zipfile, shutil, os, sys"' _newline
    file write `fh' `"from xml.etree import ElementTree as ET"' _newline
    file write `fh' `"xlsx = sys.argv[1]"' _newline
    file write `fh' `"col_w = float(sys.argv[2])"' _newline
    file write `fh' `"row_h = float(sys.argv[3])"' _newline
    file write `fh' `"col_emu = col_w * 7.5 * 9525"' _newline
    file write `fh' `"row_emu = row_h * 12700"' _newline
    file write `fh' `"ns = {'xdr': 'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing'}"' _newline
    file write `fh' `"ET.register_namespace('', ns['xdr'])"' _newline
    file write `fh' `"ET.register_namespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')"' _newline
    file write `fh' `"ET.register_namespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')"' _newline
    file write `fh' `"tmp = xlsx + '.tmp'"' _newline
    file write `fh' `"with zipfile.ZipFile(xlsx, 'r') as zin, zipfile.ZipFile(tmp, 'w') as zout:"' _newline
    file write `fh' `"    for item in zin.infolist():"' _newline
    file write `fh' `"        data = zin.read(item.filename)"' _newline
    file write `fh' `"        if item.filename.startswith('xl/drawings/drawing') and item.filename.endswith('.xml'):"' _newline
    file write `fh' `"            root = ET.fromstring(data)"' _newline
    file write `fh' `"            for anchor in root.findall('.//xdr:twoCellAnchor', ns):"' _newline
    file write `fh' `"                fr = anchor.find('xdr:from', ns)"' _newline
    file write `fh' `"                to = anchor.find('xdr:to', ns)"' _newline
    file write `fh' `"                if fr is None or to is None: continue"' _newline
    file write `fh' `"                f_coff = int(fr.find('xdr:colOff', ns).text)"' _newline
    file write `fh' `"                f_roff = int(fr.find('xdr:rowOff', ns).text)"' _newline
    file write `fh' `"                t_coff = int(to.find('xdr:colOff', ns).text)"' _newline
    file write `fh' `"                t_roff = int(to.find('xdr:rowOff', ns).text)"' _newline
    file write `fh' `"                img_w = t_coff - f_coff"' _newline
    file write `fh' `"                img_h = t_roff - f_roff"' _newline
    file write `fh' `"                dx = max(0, int((col_emu - img_w) / 2))"' _newline
    file write `fh' `"                dy = max(0, int((row_emu - img_h) / 2))"' _newline
    file write `fh' `"                fr.find('xdr:colOff', ns).text = str(f_coff + dx)"' _newline
    file write `fh' `"                fr.find('xdr:rowOff', ns).text = str(f_roff + dy)"' _newline
    file write `fh' `"                to.find('xdr:colOff', ns).text = str(t_coff + dx)"' _newline
    file write `fh' `"                to.find('xdr:rowOff', ns).text = str(t_roff + dy)"' _newline
    file write `fh' `"            data = ET.tostring(root, xml_declaration=True, encoding='UTF-8')"' _newline
    file write `fh' `"        zout.writestr(item, data)"' _newline
    file write `fh' `"shutil.move(tmp, xlsx)"' _newline
    file close `fh'

    shell python3 "`pyscript'" "`filepath'" `col_width' `row_height'
end

* End of file

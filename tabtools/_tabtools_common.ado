*! _tabtools_common Version 1.6.4  2026/06/10
*! Shared utility programs for tabtools package
*! Author: Timothy P Copeland, Karolinska Institutet

/*
DESCRIPTION:
    Common utility programs shared across the tabtools suite of table export
    commands. These utilities handle Excel column letter conversion, path
    validation, footnotes, file opening, variable type detection,
    format resolution, and sheet validation.

PROGRAMS INCLUDED:
    _tabtools_col_letter        - Convert column number to Excel letter (A, B, ..., Z, AA, AB, ...)
    _tabtools_validate_path     - Validate file path for dangerous characters
    _tabtools_validate_color    - Validate named/RGB color tokens for Excel formatting
    _tabtools_build_col_letters - Build list of Excel column letters for N columns
    _tabtools_open_file         - Open an xlsx file in the OS default application
    _tabtools_detect_vartype    - Auto-classify a variable as contn/conts/cat/bin
    _tabtools_validate_sheet    - Validate Excel sheet name (length, forbidden chars)
    _tabtools_apply_theme       - Apply journal-style formatting presets
    _tabtools_resolve_format    - Resolve font/fontsize/borderstyle from options, globals, and themes
    _tabtools_resolve_colors    - Resolve header/zebra colors from options and globals
    _tabtools_classify_stat      - Classify collect table statistics for formatting
    _tabtools_resolve_stat_format - Resolve per-statistic display formats
    _tabtools_frame_put         - Store output in a named frame with optional replace
    _tabtools_helpers_ready     - Verify the helper bundle is fully loaded
    _tabtools_require_helpers   - Exit with package reinstall message if helpers are incomplete
USAGE:
    These programs are called internally by tabtools commands (table1_tc, regtab,
    effecttab, stratetab, hrcomptab, and others). They are not intended for direct use.
    Callers manage variable-abbreviation state; helpers do not set it independently.
*/

* =============================================================================
* _tabtools_col_letter: Convert column number to Excel letter reference
* =============================================================================
* Converts 1 -> A, 2 -> B, ..., 26 -> Z, 27 -> AA, 28 -> AB, etc.
* Returns result in c_local variable 'result'
*
* Usage: _tabtools_col_letter 3
*        local my_letter = "`result'"   // my_letter = "C"

capture program drop _tabtools_col_letter
program _tabtools_col_letter
    version 16.0
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

capture program drop _tabtools_validate_path
program _tabtools_validate_path
    version 16.0
    args filepath option_name

    * Check for shell metacharacters and command injection vectors
    * Reject: ; & | > < $ ` "
    * Note: the regex character class below matches literal $ and backtick via
    * \$/\`. Double-quote (") is checked separately via char(34) to avoid
    * quoting headaches in the pattern itself. Apostrophes are valid path
    * characters.
    local _has_bad = regexm(`"`filepath'"', "[;&|><\$\`]")
    if !`_has_bad' {
        local _has_bad = strpos(`"`filepath'"', char(34)) > 0
    }
    if `_has_bad' {
        noisily display as error "`option_name' contains invalid characters"
        exit 198
    }
end

* =============================================================================
* _tabtools_validate_color: Validate Excel color tokens
* =============================================================================
* Accepts supported Stata color names (e.g. navy) or RGB triplets (e.g. 200 220 240).
*
* Usage: _tabtools_validate_color "`color'" "headercolor()"

capture program drop _tabtools_validate_color
program _tabtools_validate_color
    version 16.0
    args color option_name

    local color = strtrim(`"`color'"')
    if `"`color'"' == "" exit

    if regexm(`"`color'"', "^[A-Za-z][A-Za-z0-9_]*$") {
        local _named = lower(`"`color'"')
        local _valid_named "black blue bluishgray brown cranberry cyan dimgray"
        local _valid_named "`_valid_named' dkgreen dknavy dkorange ebblue eggshell eltblue"
        local _valid_named "`_valid_named' emerald forest_green gold gray green khaki lavender"
        local _valid_named "`_valid_named' lime ltblue ltbluishgray ltkhaki magenta maroon"
        local _valid_named "`_valid_named' midblue midgreen mint navy olive orange orange_red"
        local _valid_named "`_valid_named' pink purple red sand sienna stone teal white yellow"
        local _valid_named "`_valid_named' gs0 gs1 gs2 gs3 gs4 gs5 gs6 gs7 gs8"
        local _valid_named "`_valid_named' gs9 gs10 gs11 gs12 gs13 gs14 gs15 gs16"
        if strpos(" `_valid_named' ", " `_named' ") exit
        noisily display as error "`option_name' is not a supported Stata color name;"
        noisily display as error "use a supported name such as navy or an RGB triplet like 200 220 240"
        exit 198
    }

    if regexm(`"`color'"', "^[0-9]+[ ]+[0-9]+[ ]+[0-9]+$") {
        tokenize `"`color'"'
        foreach _channel in `1' `2' `3' {
            if real("`_channel'") < 0 | real("`_channel'") > 255 {
                noisily display as error "`option_name' RGB values must be between 0 and 255"
                exit 198
            }
        }
        exit
    }

    noisily display as error "`option_name' must be a supported Stata color name or an RGB triplet like 200 220 240"
    exit 198
end

* =============================================================================
* _tabtools_build_col_letters: Build list of Excel column letters for N columns
* =============================================================================
* Creates a space-separated list of column letters for columns 1 to N.
* Returns result in c_local variable 'result'
*
* Usage: _tabtools_build_col_letters 30
*        local letters = "`result'"   // letters = "A B C ... AA AB AC AD"

capture program drop _tabtools_build_col_letters
program _tabtools_build_col_letters
    version 16.0
    args num_cols

    local col_letters ""

    forvalues i = 1/`num_cols' {
        * Inline base-26 conversion (avoids program call overhead per column)
        local _letter = ""
        local _n = `i'
        while `_n' > 0 {
            local _r = mod(`_n' - 1, 26)
            local _letter = char(`_r' + 65) + "`_letter'"
            local _n = floor((`_n' - 1) / 26)
        }
        local col_letters "`col_letters' `_letter'"
    }

    c_local result "`=strtrim("`col_letters'")'"
end

* =============================================================================
* _tabtools_open_file: Open an xlsx file in the OS default application
* =============================================================================
* Detects the operating system via c(os) and launches the appropriate shell
* command to open the file.
*
* Usage: _tabtools_open_file "`filepath'"

capture program drop _tabtools_open_file
program _tabtools_open_file
    version 16.0
    args filepath

    if "`filepath'" == "" exit

    if "`c(os)'" == "MacOSX" {
        shell open "`filepath'" &
    }
    else if "`c(os)'" == "Windows" {
        shell start "" "`filepath'"
    }
    else {
        * Unix/Linux
        shell xdg-open "`filepath'" &
    }
end

* =============================================================================
* _tabtools_detect_vartype: Auto-classify a variable for table1_tc
* =============================================================================
* Classifies a variable as one of: contn, conts, cat, bin
* Auto-classify a variable for descriptive statistics tables.
* Returns result in c_local variable 'result'.
*
* Logic:
*   1. String variable -> cat
*   2. Has value labels -> cat
*   3. Numeric, exactly 2 unique non-missing values -> bin
*   4. Numeric, <= 7 unique non-missing values -> cat
*   5. Numeric, > 7 unique values -> Shapiro-Wilk normality test:
*      - p >= 0.05 -> contn (normally distributed)
*      - p < 0.05  -> conts (skewed)
*
* Usage: _tabtools_detect_vartype myvar
*        local type "`result'"

capture program drop _tabtools_detect_vartype
program _tabtools_detect_vartype
    version 16.0
    args varname

    tempvar _uniqtag
    quietly egen byte `_uniqtag' = tag(`varname') if !missing(`varname')
    quietly count if `_uniqtag'
    local _nuniq = r(N)

    * Check if string
    capture confirm string variable `varname'
    if !_rc {
        c_local result "cat"
        c_local result_nuniq "`_nuniq'"
        exit
    }

    * All-missing numeric -> contn
    if `_nuniq' == 0 {
        c_local result "contn"
        c_local result_nuniq "0"
        exit
    }

    * Exactly 2 unique values -> bin (regardless of value labels)
    if `_nuniq' == 2 {
        c_local result "bin"
        c_local result_nuniq "`_nuniq'"
        exit
    }

    * Has value labels with >2 levels -> cat
    local vallabel : value label `varname'
    if "`vallabel'" != "" {
        c_local result "cat"
        c_local result_nuniq "`_nuniq'"
        exit
    }

    * <= 7 unique values -> cat
    if `_nuniq' <= 7 {
        c_local result "cat"
        c_local result_nuniq "`_nuniq'"
        exit
    }

    * > 7 unique values: test normality
    quietly count if !missing(`varname')
    local _nobs = r(N)

    if `_nobs' < 4 {
        * Too few observations for normality test — default to contn
        c_local result "contn"
        c_local result_nuniq "`_nuniq'"
        exit
    }

    * For large N (>5000), use skewness/kurtosis heuristic instead of Shapiro-Wilk
    * Shapiro-Wilk rejects normality for essentially all large samples
    if `_nobs' > 5000 {
        quietly summarize `varname', detail
        local _skew = abs(r(skewness))
        local _kurt = r(kurtosis)
        if `_skew' > 1 | abs(`_kurt' - 3) > 2 {
            c_local result "conts"
        }
        else {
            c_local result "contn"
        }
        c_local result_nuniq "`_nuniq'"
        exit
    }

    * For smaller N, use Shapiro-Wilk
    * Use a sample of up to 2000 obs for speed (swilk max is 2000 in some versions)
    preserve
    tempvar _sw_use _sw_tie
    if `_nobs' > 2000 {
        local _rng_state = c(rngstate)
        set seed 12345
        quietly gen `_sw_use' = runiform() if !missing(`varname')
        set rngstate `_rng_state'
        quietly gen `_sw_tie' = _n
        quietly sort `_sw_use' `_sw_tie'
        capture quietly swilk `varname' in 1/2000
    }
    else {
        capture quietly swilk `varname'
    }
    local _sw_rc = _rc
    local _sw_p = .
    if !`_sw_rc' local _sw_p = r(p)
    restore

    if `_sw_rc' {
        * If swilk fails for any reason, default to contn
        c_local result "contn"
        c_local result_nuniq "`_nuniq'"
        exit
    }

    * Classify based on Shapiro-Wilk p-value
    if `_sw_p' >= 0.05 {
        c_local result "contn"
    }
    else {
        c_local result "conts"
    }
    c_local result_nuniq "`_nuniq'"
end

* =============================================================================
* _tabtools_validate_sheet: Validate Excel sheet name
* =============================================================================
* Checks that sheet name does not exceed 31 characters and does not contain
* characters forbidden by Excel (\ / ? * [ ] :).
*
* Usage: _tabtools_validate_sheet "`sheet'" "sheet()"

capture program drop _tabtools_validate_sheet
program _tabtools_validate_sheet
    version 16.0
    args sheet option_name
    if strlen("`sheet'") > 31 {
        display as error "`option_name': sheet name '`sheet'' exceeds Excel's 31-character limit"
        exit 198
    }
    if regexm("`sheet'", "[][/\\?*:]" ) {
        display as error "`option_name': sheet name contains characters not allowed by Excel (\ / ? * [ ] :)"
        exit 198
    }
end

* =============================================================================
* _tabtools_apply_theme: Apply journal-style formatting presets (O1)
* =============================================================================
* Sets formatting locals in the caller's scope based on theme name.
* Themes: lancet, nejm, bmj, apa, jama, plos, nature, cell, annals
*
* Usage: _tabtools_apply_theme lancet
*        (sets c_local variables: _theme_font, _theme_fontsize, _theme_border,
*         _theme_headershade, _theme_headercolor, _theme_zebra)

capture program drop _tabtools_apply_theme
program _tabtools_apply_theme
    version 16.0
    args theme

    local theme = lower("`theme'")

    if "`theme'" == "lancet" {
        c_local _theme_font "Arial"
        c_local _theme_fontsize "9"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "nejm" {
        * 9pt matches NEJM manuscript table conventions (10pt was too large).
        * zebra=1: NEJM uses light row alternation. The theme system does not
        * support per-theme zebra colors, so the global default (237 242 249,
        * blue-tinted) is used. For exact NEJM neutral-gray shading, override:
        *   zebracolor("242 242 242")
        c_local _theme_font "Arial"
        c_local _theme_fontsize "9"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "1"
    }
    else if "`theme'" == "bmj" {
        c_local _theme_font "Arial"
        c_local _theme_fontsize "10"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "apa" {
        c_local _theme_font "Times New Roman"
        c_local _theme_fontsize "12"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "jama" {
        c_local _theme_font "Arial"
        c_local _theme_fontsize "10"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "plos" {
        c_local _theme_font "Arial"
        c_local _theme_fontsize "10"
        c_local _theme_border "thin"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "nature" {
        c_local _theme_font "Arial"
        c_local _theme_fontsize "7"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "cell" {
        * 8pt matches Cell Press table conventions (10pt was too large).
        c_local _theme_font "Arial"
        c_local _theme_fontsize "8"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "annals" {
        * Annals of Internal Medicine uses a clean three-rule format (no row
        * alternation). zebra was incorrectly set to 1.
        c_local _theme_font "Arial"
        c_local _theme_fontsize "10"
        c_local _theme_border "academic"
        c_local _theme_headershade "0"
        c_local _theme_headercolor ""
        c_local _theme_zebra "0"
    }
    else if "`theme'" == "custom" {
        * Custom theme reads from globals set by tabtools set theme custom
        c_local _theme_font = cond("$TABTOOLS_FONT" != "", "$TABTOOLS_FONT", "Arial")
        c_local _theme_fontsize = cond("$TABTOOLS_FONTSIZE" != "", "$TABTOOLS_FONTSIZE", "10")
        c_local _theme_border = cond("$TABTOOLS_BORDER" != "", "$TABTOOLS_BORDER", "thin")
        c_local _theme_headershade = cond("$TABTOOLS_HEADERCOLOR" != "", "1", "0")
        c_local _theme_headercolor "$TABTOOLS_HEADERCOLOR"
        c_local _theme_zebra = cond("$TABTOOLS_ZEBRACOLOR" != "", "1", "0")
    }
    else {
        display as error "Unknown theme: `theme'. Valid themes: lancet, nejm, bmj, apa, jama, plos, nature, cell, annals, custom"
        exit 198
    }
end

* =============================================================================
* _tabtools_resolve_format: Resolve font/fontsize/borderstyle from options,
*   globals, and themes
* =============================================================================
* Centralizes the format resolution logic shared across all tabtools commands.
* Resolves: user option -> theme -> $TABTOOLS_* global -> default.
*
* Sets c_local variables in the caller's scope:
*   _font, _fontsize, borderstyle, _hborder, headershade, zebra
*
* Usage: _tabtools_resolve_format, [theme(string) borderstyle(string)
*            headershade(string) zebra(string)]

capture program drop _tabtools_resolve_format
program _tabtools_resolve_format
    version 16.0
    syntax , [THEme(string) BORDERstyle(string) HEADERShade(string) ZEBra(string)]

    * Font defaults: global -> default
    local _font "Arial"
    local _fontsize 10
    if "$TABTOOLS_FONT" != "" local _font "$TABTOOLS_FONT"
    if "$TABTOOLS_FONTSIZE" != "" local _fontsize $TABTOOLS_FONTSIZE

    * Apply theme: explicit option overrides global
    if "`theme'" == "" & "$TABTOOLS_THEME" != "" local theme "$TABTOOLS_THEME"
    if "`theme'" != "" {
        _tabtools_apply_theme "`theme'"
        local _font "`_theme_font'"
        local _fontsize `_theme_fontsize'
        if "`borderstyle'" == "" local borderstyle "`_theme_border'"
        if "`_theme_headershade'" == "1" & "`headershade'" == "" local headershade "headershade"
        if "`_theme_zebra'" == "1" & "`zebra'" == "" local zebra "zebra"
    }

    * Resolve borderstyle: global -> default
    if "`borderstyle'" == "" & "$TABTOOLS_BORDER" != "" local borderstyle "$TABTOOLS_BORDER"
    if "`borderstyle'" == "" local borderstyle "thin"
    if !inlist("`borderstyle'", "default", "thin", "medium", "academic") {
        display as error "borderstyle must be: default, thin, medium, or academic"
        exit 198
    }
    if "`borderstyle'" == "default" local borderstyle "thin"
    local _hborder = cond("`borderstyle'" == "academic", "medium", "`borderstyle'")

    * Return via c_local to caller's scope
    c_local _font "`_font'"
    c_local _fontsize `_fontsize'
    c_local borderstyle "`borderstyle'"
    c_local _hborder "`_hborder'"
    if "`headershade'" != "" c_local headershade "`headershade'"
    if "`zebra'" != "" c_local zebra "`zebra'"
end

* =============================================================================
* _tabtools_resolve_colors: Resolve header/zebra colors from options and globals
* =============================================================================
* Sets c_local variables in the caller's scope:
*   _headercolor, _zebracolor
*
* Usage: _tabtools_resolve_colors, [headercolor(string) zebracolor(string)]

capture program drop _tabtools_resolve_colors
program _tabtools_resolve_colors
    version 16.0
    syntax , [HEADERColor(string) ZEBRAColor(string)]

    local headercolor = strtrim(subinstr(`"`headercolor'"', char(34), "", .))
    local zebracolor = strtrim(subinstr(`"`zebracolor'"', char(34), "", .))

    local _headercolor "219 229 241"
    local _zebracolor "237 242 249"
    if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
    if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
    if `"`headercolor'"' != "" local _headercolor `"`headercolor'"'
    if `"`zebracolor'"' != "" local _zebracolor `"`zebracolor'"'

    _tabtools_validate_color "`_headercolor'" "headercolor()"
    _tabtools_validate_color "`_zebracolor'" "zebracolor()"

    c_local _headercolor `"`_headercolor'"'
    c_local _zebracolor `"`_zebracolor'"'
end

* =============================================================================
* _tabtools_classify_stat: Classify collect table statistics for formatting
* =============================================================================

capture program drop _tabtools_classify_stat
program _tabtools_classify_stat, rclass
    version 16.0
    syntax anything(name=stat)
    local stat = lower("`stat'")
    local class "unknown"
    if inlist("`stat'", "frequency", "fvfrequency", "count", "sum", "sum_w", "total") {
        local class "integer"
    }
    else if inlist("`stat'", "percent", "fvpercent") {
        local class "percent"
    }
    else if inlist("`stat'", "prop", "propc", "propr") {
        local class "proportion"
    }
    else if inlist("`stat'", "mean", "sd", "variance", "semean", "min", "max", "range") {
        local class "continuous"
    }
    else if inlist("`stat'", "median", "iqr", "q", "skewness", "kurtosis") {
        local class "continuous"
    }
    else if regexm("`stat'", "^p[0-9][0-9]?$") {
        local class "continuous"
    }
    return local class "`class'"
end

* =============================================================================
* _tabtools_resolve_stat_format: Resolve per-statistic display formats
* =============================================================================

capture program drop _tabtools_resolve_stat_format
program _tabtools_resolve_stat_format, rclass
    version 16.0
    syntax anything(name=stat) [, DIGits(integer 2) PCTDIGits(integer 1) ///
        NINTEGERfmt(string)]
    if "`nintegerfmt'" == "" local nintegerfmt "%12.0fc"
    _tabtools_classify_stat `stat'
    local class "`r(class)'"
    if "`class'" == "integer" {
        local fmt "`nintegerfmt'"
    }
    else if "`class'" == "percent" {
        local fmt "%5.`pctdigits'f"
    }
    else if "`class'" == "proportion" {
        local fmt "%4.3f"
    }
    else {
        local fmt "%5.`digits'f"
    }
    return local class "`class'"
    return local fmt "`fmt'"
end

* =============================================================================
* _tabtools_console_display: Format and display a table dataset with proper
*   column widths
* =============================================================================
* Displays the current dataset as a formatted console table. Assumes the
* dataset has string columns c1..cN (and optionally a label variable), with
* row 1 as title, rows 2..datastart-1 as headers, and rows datastart+ as data.
* Rendering uses Stata's list, table style so console previews share the same
* boxed-table look as table1_tc.
*
* Usage:
*   _tabtools_console_display `num_cols' `"`title'"'
*   _tabtools_console_display `num_cols' `"`title'"', labelvar(A) datastart(4) headerstart(3)
*
* Options:
*   labelvar(varname)  — separate label column (e.g. A in regtab/effecttab/comptab)
*   datastart(#)       — first data row (default 3; use 4 for comptab)
*   headerstart(#)     — first header row to display (default 2)

capture program drop _tabtools_console_display
program _tabtools_console_display
    version 16.0
    syntax anything(name=args) [, LABELvar(string) DATAstart(integer 3) HEADERstart(integer 2)]

    gettoken num_cols title : args
    * Resolve compound-quoted title passed via `"`macro'"'
    local title `title'

    if `"`title'"' != "" {
        display as text ""
        display as result `"`title'"'
    }

    local total_rows = _N
    if `total_rows' < `headerstart' {
        display as text ""
        exit
    }

    local _display_vars ""
    if "`labelvar'" != "" {
        capture confirm variable `labelvar'
        if !_rc local _display_vars "`labelvar'"
    }

    forvalues c = 1/`num_cols' {
        capture confirm variable c`c'
        if !_rc local _display_vars "`_display_vars' c`c'"
    }

    if "`_display_vars'" == "" {
        display as text ""
        exit
    }

    list `_display_vars' in `headerstart'/`total_rows', noobs noheader table
    display as text ""
end

* =============================================================================
* _tabtools_helpers_ready: Verify helper bundle completeness
* =============================================================================
* Returns rc=0 when all requested helpers are loaded; rc=111 otherwise.
*
* Usage: capture _tabtools_helpers_ready

capture program drop _tabtools_helpers_ready
program _tabtools_helpers_ready
    version 16.0
    args required

    if `"`required'"' == "" {
        local required "_tabtools_col_letter _tabtools_validate_path _tabtools_validate_color _tabtools_build_col_letters _tabtools_open_file _tabtools_detect_vartype _tabtools_validate_sheet _tabtools_apply_theme _tabtools_resolve_format _tabtools_resolve_colors _tabtools_classify_stat _tabtools_resolve_stat_format _tabtools_console_display _tabtools_frame_put _tabtools_require_helpers"
    }

    foreach _prog of local required {
        capture program list `_prog'
        if _rc exit 111
    }
end

* =============================================================================
* _tabtools_require_helpers: Require helper bundle completeness
* =============================================================================
* Displays the caller-compatible reinstall message and exits rc=111 when helpers
* are not loaded completely.
*
* Usage: _tabtools_require_helpers [, required(string) failmessage(string)]

capture program drop _tabtools_require_helpers
program _tabtools_require_helpers
    version 16.0
    syntax [, REQUIRED(string asis) FAILMessage(string asis)]

    if `"`failmessage'"' == "" {
        local failmessage "_tabtools_common.ado failed to load fully; reinstall tabtools"
    }

    capture _tabtools_helpers_ready `"`required'"'
    if _rc {
        noisily display as error `"`failmessage'"'
        exit 111
    }
end

* =============================================================================
* _tabtools_frame_put: Store output in a named frame with optional replace
* =============================================================================
* Parses frame specification that may include ", replace" sub-option.
* Drops existing frame if replace is specified, otherwise errors if exists.
* Creates the frame via frame put *, into().
* Returns parsed frame name in c_local _frame_name.
*
* Usage: _tabtools_frame_put `"`frame'"'
*        local frame "`_frame_name'"

capture program drop _tabtools_frame_put
program _tabtools_frame_put
    version 16.0
    args frame_spec

    * Parse frame name and optional replace sub-option
    gettoken _fr_name _fr_opts : frame_spec, parse(",")
    local _fr_name = strtrim("`_fr_name'")
    local _fr_opts : subinstr local _fr_opts "," "", all
    local _fr_opts = strtrim(lower("`_fr_opts'"))

    if "`_fr_opts'" != "" & "`_fr_opts'" != "replace" {
        display as error "frame(): unknown sub-option `_fr_opts'"
        exit 198
    }

    * Validate frame name
    capture confirm name `_fr_name'
    if _rc {
        display as error "frame(): invalid frame name `_fr_name'"
        exit 198
    }

    capture confirm frame `_fr_name'
    if !_rc {
        if "`_fr_opts'" == "replace" {
            if "`_fr_name'" == "`c(frame)'" {
                display as error "frame(): cannot replace the current frame (`_fr_name')"
                exit 198
            }
            frame drop `_fr_name'
        }
        else {
            display as error "frame `_fr_name' already exists"
            exit 110
        }
    }
    frame put *, into(`_fr_name')

    c_local _frame_name "`_fr_name'"
end

* End of file

*! _tabtools_common Version 1.2.1  2026/11/20
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
    _tabtools_resolve_format    - Resolve font/fontsize/borderstyle from options and globals
    _tabtools_resolve_colors    - Resolve header/zebra colors from options and globals
    _tabtools_classify_stat      - Classify collect table statistics for formatting
    _tabtools_resolve_stat_format - Resolve per-statistic display formats
    _tabtools_collect_ci_level  - Read the CI level stored in an active collection
    _tabtools_strip_outer_quotes - Remove one balanced outer quote layer
    _tabtools_format_p          - Apply the package p-value display policy
    _tabtools_frame_put         - Store output in a named frame with optional replace
    _tabtools_frame_preflight   - Validate a frame spec without mutating anything
    _tabtools_resolve_ci_level  - Resolve the CI level to label intervals with
    _tabtools_companion_id      - Allocate an opaque identity for paired output frames
    _tabtools_helpers_ready     - Verify the helper bundle is fully loaded
    _tabtools_require_helpers   - Exit with package reinstall message if helpers are incomplete
USAGE:
    These programs are called internally by tabtools commands (table1_tc, regtab,
    effecttab, stratetab, hrcomptab, and others). They are not intended for direct use.
    Each helper independently restores the caller's variable-abbreviation state.
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
program _tabtools_col_letter, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args col_num

    local col_letter = ""
    local temp_num = `col_num'

    while `temp_num' > 0 {
        local remainder = mod(`temp_num' - 1, 26)
        local col_letter = char(`remainder' + 65) + "`col_letter'"
        local temp_num = floor((`temp_num' - 1) / 26)
    }

    c_local result "`col_letter'"
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
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
program _tabtools_validate_path, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args filepath option_name

    * Check for shell metacharacters and command injection vectors
    * Reject: ; & | > < $ ` " '
    * Note: the regex character class below matches literal $ and backtick via
    * \$/\`. Double-quote (") is checked separately via char(34) to avoid
    * quoting headaches in the pattern itself. Both quote characters are
    * rejected because callers interpolate validated paths into commands.
    local _has_bad = regexm(`"`macval(filepath)'"', "[;&|><\$\`]")
    if !`_has_bad' {
        local _has_bad = strpos(`"`macval(filepath)'"', char(34)) > 0
    }
    if !`_has_bad' {
        local _has_bad = strpos(`"`macval(filepath)'"', char(39)) > 0
    }
    if `_has_bad' {
        noisily display as error "`option_name' contains invalid characters"
        exit 198
    }
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_validate_color: Validate Excel color tokens
* =============================================================================
* Accepts supported Stata color names (e.g. navy) or RGB triplets (e.g. 200 220 240).
*
* Usage: _tabtools_validate_color "`color'" "headercolor()"

capture program drop _tabtools_validate_color
program _tabtools_validate_color, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args color option_name

    local color = strtrim(`"`color'"')
    if `"`color'"' == "" {
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

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
        if strpos(" `_valid_named' ", " `_named' ") {
            quietly version
            set varabbrev `_orig_varabbrev'
            exit
        }
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
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    noisily display as error "`option_name' must be a supported Stata color name or an RGB triplet like 200 220 240"
    exit 198
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
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
program _tabtools_build_col_letters, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
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
        local col_letters `"`col_letters' `_letter'"'
    }

    c_local result "`=strtrim("`col_letters'")'"
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_open_file: Open an xlsx file in the OS default application
* =============================================================================
* Detects the operating system via c(os) and launches the appropriate shell
* command to open the file.
*
* Usage: _tabtools_open_file "`filepath'"

capture program drop _tabtools_open_file
program _tabtools_open_file, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args filepath

    if "`filepath'" == "" {
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

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
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
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
*   3. Numeric, exactly the values 0 and 1 -> bin
*   4. Numeric, <= 7 unique non-missing values -> cat
*   5. Numeric, > 7 unique values -> Shapiro-Wilk normality test:
*      - p >= 0.05 -> contn (normally distributed)
*      - p < 0.05  -> conts (skewed)
*      (over 5,000 values: |skewness| > 1 or |kurtosis - 3| > 2 -> conts).
*      Both tests use the values divided by a power of two, so the type does
*      not depend on the scale of the variable.
*
* Usage: _tabtools_detect_vartype myvar [if] [in]
*        local type "`result'"

capture program drop _tabtools_detect_vartype
program _tabtools_detect_vartype, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    local _rng_restore_needed = 0
    local _rng_state ""
    capture noisily {
    syntax varlist(min=1 max=1) [if] [in]
    local varname `"`varlist'"'

    marksample touse, novarlist

    tempvar _uniqtag
    quietly egen byte `_uniqtag' = tag(`varname') if `touse' & !missing(`varname')
    quietly count if `_uniqtag'
    local _nuniq = r(N)

    * Check if string
    capture confirm string variable `varname'
    if !_rc {
        c_local result "cat"
        c_local result_nuniq "`_nuniq'"
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    * All-missing numeric -> contn
    if `_nuniq' == 0 {
        c_local result "contn"
        c_local result_nuniq "0"
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    * Only literal 0/1 coding is binary. Other two-level codings remain
    * categorical so the collector does not later reject its own auto choice.
    if `_nuniq' == 2 {
        quietly summarize `varname' if `touse', meanonly
        if r(min) == 0 & r(max) == 1 c_local result "bin"
        else c_local result "cat"
        c_local result_nuniq "`_nuniq'"
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    * Has value labels with >2 levels -> cat
    local vallabel : value label `varname'
    if "`vallabel'" != "" {
        c_local result "cat"
        c_local result_nuniq "`_nuniq'"
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    * <= 7 unique values -> cat
    if `_nuniq' <= 7 {
        c_local result "cat"
        c_local result_nuniq "`_nuniq'"
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    * > 7 unique values: test normality
    quietly count if `touse' & !missing(`varname')
    local _nobs = r(N)

    if `_nobs' < 4 {
        * Too few observations for normality test — default to contn
        c_local result "contn"
        c_local result_nuniq "`_nuniq'"
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    * Skewness, kurtosis and the Shapiro-Wilk W do not depend on the scale of
    * the values, but summarize and swilk take powers of the raw values, which
    * overflow near 1e100 (or underflow near 1e-100) and come back missing:
    * a missing skewness read as > 1 (conts), and swilk used no observations,
    * whose missing p read as >= 0.05 (contn). Both tests therefore see a copy
    * divided by a power of two near the largest magnitude. The division is
    * exact, so ordinary data give the same moments and p-value.
    quietly summarize `varname' if `touse', meanonly
    local _scale_k = ceil(ln(max(abs(r(min)), abs(r(max)))) / ln(2))
    local _scale_k = min(max(`_scale_k', -1021), 1022)
    tempvar _scaled
    quietly gen double `_scaled' = `varname' / 2^`_scale_k' if `touse'

    * For large N (>5000), use skewness/kurtosis heuristic instead of Shapiro-Wilk
    * Shapiro-Wilk rejects normality for essentially all large samples
    if `_nobs' > 5000 {
        quietly summarize `_scaled' if `touse', detail
        local _skew = abs(r(skewness))
        local _kurt = r(kurtosis)
        if `_skew' > 1 | abs(`_kurt' - 3) > 2 {
            c_local result "conts"
        }
        else {
            c_local result "contn"
        }
        c_local result_nuniq "`_nuniq'"
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    * For smaller N, use Shapiro-Wilk
    * Use a sample of up to 2000 obs for speed (swilk max is 2000 in some versions)
    preserve
    local _restore_needed = 1
    tempvar _sw_use _sw_tie
    if `_nobs' > 2000 {
        local _rng_state = c(rngstate)
        local _rng_restore_needed = 1
        set seed 12345
        quietly keep if `touse' & !missing(`varname')
        quietly gen `_sw_use' = runiform()
        set rngstate `_rng_state'
        local _rng_restore_needed = 0
        quietly gen `_sw_tie' = _n
        quietly sort `_sw_use' `_sw_tie'
        capture quietly swilk `_scaled' in 1/2000
    }
    else {
        capture quietly swilk `_scaled' if `touse'
    }
    local _sw_rc = _rc
    local _sw_p = .
    if !`_sw_rc' local _sw_p = r(p)
    restore
    local _restore_needed = 0

    if `_sw_rc' {
        * If swilk fails for any reason, default to contn
        c_local result "contn"
        c_local result_nuniq "`_nuniq'"
        quietly version
        set varabbrev `_orig_varabbrev'
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
    }
    local _rc_outer = _rc
    if `_rng_restore_needed' capture set rngstate `_rng_state'
    if `_restore_needed' capture restore
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_validate_sheet: Validate Excel sheet name
* =============================================================================
* Checks Excel's worksheet-name contract: nonblank, at most 31 characters,
* no forbidden characters (\ / ? * [ ] :), no leading/trailing apostrophe,
* and not the reserved name History.
*
* Usage: _tabtools_validate_sheet "`sheet'" "sheet()"

capture program drop _tabtools_validate_sheet
program _tabtools_validate_sheet, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args sheet option_name
    if ustrlen(`"`macval(sheet)'"') == 0 {
        display as error "`option_name': sheet name may not be blank"
        exit 198
    }
    if ustrlen(`"`macval(sheet)'"') > 31 {
        display as error `"`option_name': sheet name '`macval(sheet)'' exceeds Excel's 31-character limit"'
        exit 198
    }
    if regexm(`"`macval(sheet)'"', "[][/\\?*:]" ) {
        display as error "`option_name': sheet name contains characters not allowed by Excel (\ / ? * [ ] :)"
        exit 198
    }
    if substr(`"`macval(sheet)'"', 1, 1) == char(39) | ///
            substr(`"`macval(sheet)'"', -1, 1) == char(39) {
        display as error "`option_name': sheet name may not begin or end with an apostrophe"
        exit 198
    }
    if lower(`"`macval(sheet)'"') == "history" {
        display as error "`option_name': History is reserved by Excel and cannot be used as a sheet name"
        exit 198
    }
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_resolve_format: Resolve font/fontsize/borderstyle from options
* =============================================================================
* Centralizes the format resolution logic shared across all tabtools commands.
* Resolves: user option -> $TABTOOLS_* global -> default.
*
* Sets c_local variables in the caller's scope:
*   _font, _fontsize, borderstyle, _hborder, headershade, zebra
*
* Usage: _tabtools_resolve_format, [font(string) fontsize(string) fsexplicit
*            borderstyle(string) headershade(string) zebra(string)]
*
* fontsize(): empty = not given. A caller that declares FONTSIZE(integer -1)
* passes -1 when the option was not given, so without fsexplicit "-1" also
* means not given. A caller that declares FONTSIZE(string) passes the user's
* own text with fsexplicit; then -1 is a typed value and is range-checked
* like any other (fontsize(-1) used to be taken as no option at rc 0).

capture program drop _tabtools_resolve_format
program _tabtools_resolve_format, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax , [FONT(string) FONTSIZE(string) FSEXPlicit BORDERstyle(string) HEADERShade(string) ZEBra(string)]

    * Font defaults: global -> default
    local _font "Arial"
    local _fontsize 10
    if "$TABTOOLS_FONT" != "" local _font "$TABTOOLS_FONT"
    if "$TABTOOLS_FONTSIZE" != "" local _fontsize $TABTOOLS_FONTSIZE
    if `"`font'"' != "" local _font `"`font'"'
    local fontsize = strtrim(`"`fontsize'"')
    local _fs_given = (`"`fontsize'"' != "")
    if `_fs_given' & "`fsexplicit'" == "" & `"`fontsize'"' == "-1" local _fs_given 0
    if `_fs_given' {
        capture confirm integer number `fontsize'
        if _rc {
            display as error "option fontsize() incorrectly specified"
            exit 198
        }
        local _fontsize `fontsize'
    }
    capture confirm integer number `_fontsize'
    if _rc {
        display as error "fontsize() must be between 1 and 72"
        exit 198
    }
    if `_fontsize' < 1 | `_fontsize' > 72 {
        display as error "fontsize() must be between 1 and 72"
        exit 198
    }

    * Resolve borderstyle: global -> default
    * An explicit borderstyle() wins over the session value
    * (tabtools set borderstyle); a session value is validated as an
    * option is, and named as the session's if it is not valid.
    local _bs_session 0
    * stata-dev-ignore: ambient-fallback — borderstyle is a syntax option string, empty exactly when the caller did not give it; the documented session key (tabtools set borderstyle) then applies and an explicit option wins
    if "`borderstyle'" == "" & `"$TABTOOLS_BORDER"' != "" {
        local borderstyle `"$TABTOOLS_BORDER"'
        local _bs_session 1
    }
    if "`borderstyle'" == "" local borderstyle "thin"
    if !inlist(`"`borderstyle'"', "default", "thin", "medium", "academic") {
        if `_bs_session' display as error `"session borderstyle "`borderstyle'" is not valid; borderstyle must be: default, thin, medium, or academic"'
        else display as error "borderstyle must be: default, thin, medium, or academic"
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
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_resolve_colors: Resolve header/zebra colors from options and globals
* =============================================================================
* Sets c_local variables in the caller's scope:
*   _headercolor, _zebracolor
*
* Usage: _tabtools_resolve_colors, [headercolor(string) zebracolor(string)]

capture program drop _tabtools_resolve_colors
program _tabtools_resolve_colors, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
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
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_classify_stat: Classify collect table statistics for formatting
* =============================================================================

capture program drop _tabtools_classify_stat
program _tabtools_classify_stat, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
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
    }
    local _rc_outer = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_resolve_stat_format: Resolve per-statistic display formats
* =============================================================================

capture program drop _tabtools_resolve_stat_format
program _tabtools_resolve_stat_format, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax anything(name=stat) [, DIGits(integer 2) PCTDIGits(integer 1) ///
        NINTEGERfmt(string)]
    if "`nintegerfmt'" == "" local nintegerfmt "%12.0fc"
    _tabtools_classify_stat `stat'
    local class `"`r(class)'"'
    if "`class'" == "integer" {
        local fmt `"`nintegerfmt'"'
    }
    else if "`class'" == "percent" {
        local fmt "%21.`pctdigits'f"
    }
    else if "`class'" == "proportion" {
        local fmt "%21.3f"
    }
    else {
        local fmt "%21.`digits'f"
    }
    return local class "`class'"
    return local fmt "`fmt'"
    }
    local _rc_outer = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_collect_ci_level: Read CI provenance from collect's saved JSON
*
* The "ci-level" key is an undocumented collect internal. Stata 17 writes it;
* Stata 19 does not write it at all and nothing replaced it. Absence is
* therefore an expected outcome, not an error: report it via r(found) and let
* callers fall back. Erroring here broke regtab/effecttab outright on Stata 19.
* =============================================================================

capture program drop _tabtools_collect_ci_level
program _tabtools_collect_ci_level, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    tempfile _collect_level
    local _json "`_collect_level'.stjson"
    local _level = .

    capture noisily {
        quietly collect save "`_json'", replace
        * C1 (codex audit 2026-09-26): the saved collection holds every
        * label as typed, so it is scanned in Mata. Reading each line into a
        * local and expanding it stopped with r(132) on a label containing a
        * backtick, and expanded a $word inside one.
        mata: st_local("_level", strofreal(_tt_collect_ci_level_json(st_local("_json"))))
    }
    local rc = _rc
    capture erase "`_json'"
    if `rc' exit `rc'
    return scalar found = !missing(`_level')
    return scalar level = `_level'
    }
    local _rc_outer = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_resolve_ci_level: decide the confidence level to LABEL intervals with
* =============================================================================
* Single source of truth for regtab and effecttab, which previously carried
* byte-identical copies of this decision and could drift apart.
*
* Rules, in order:
*   1. collection records the level  -> use it; a conflicting level() is an error
*   2. no provenance, level() given  -> use level()
*   3. no provenance, no level()     -> warn and use current c(level)
*
* Case 3 is needed on Stata versions that omit the collection metadata. The
* fallback cannot prove the model-time level, so it emits a visible warning and
* tells the user to specify level() when c(level) is not the correct value.
*
* Usage: _tabtools_resolve_ci_level `level'      // -1 when level() not given
*        local _ci_level = r(level)

capture program drop _tabtools_resolve_ci_level
program define _tabtools_resolve_ci_level, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args level_opt

    if "`level_opt'" == "" local level_opt = -1

    _tabtools_collect_ci_level
    local _found = r(found)
    local _stored = r(level)

    if `_found' {
        local _lvl = `_stored'
        if `level_opt' != -1 {
            if abs(`level_opt' - `_stored') > 1e-8 {
                display as error "level(`level_opt') conflicts with the active collection's `_stored'% intervals"
                exit 198
            }
            local _lvl = `level_opt'
        }
    }
    else if `level_opt' != -1 {
        local _lvl = `level_opt'
    }
    else {
        local _lvl = c(level)
        display as text "warning: this Stata version does not record confidence-level provenance in the collection"
        display as text "assuming the current {bf:set level} (`_lvl') for interval labels; specify level(#) if the"
        display as text "collected models were fit at a different confidence level"
    }

    return scalar level = `_lvl'
    return scalar found = `_found'
    }
    local _rc_outer = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_strip_outer_quotes: Remove one balanced outer quoting layer only
* =============================================================================

capture program drop _tabtools_strip_outer_quotes
program _tabtools_strip_outer_quotes, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax , TEXT(string asis)
    mata: st_local("_out", _tt_strip_outer_quotes(st_local("text")))
    return local text `"`_out'"'
    }
    local _rc_outer = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_format_p: one p-value as text, by the package display rule
* =============================================================================
* The rule of regtab.ado and _tabtools_fmt_p.ado (which documents it), for a
* single value: "<0.001" below 10^-pdp, pdp decimals below 0.10, highpdp
* decimals from 0.10, and ">0.99" above 1 - 10^-highpdp. r(value) is the cell
* text; r(phrase) is the same value in a sentence ("p < 0.001", "p = 0.012"),
* since "p = <0.001" is not one. A missing p returns both empty.

capture program drop _tabtools_format_p
program _tabtools_format_p, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax , PVALUE(real) [PDP(integer 3) HIGHPDP(integer 2)]
    if `pdp' < 1 | `highpdp' < 1 exit 198
    local _out ""
    local _phrase ""
    if !missing(`pvalue') {
        local _pmin = 10^(-`pdp')
        local _pmax = 1 - 10^(-`highpdp')
        if `pvalue' < `_pmin' {
            local _num = strtrim(ustrregexra(string(`_pmin', "%21.`pdp'f"), "-(?=[0.,]+\z)", ""))
            local _out "<`_num'"
            local _phrase "p < `_num'"
        }
        else if `pvalue' > `_pmax' & `pvalue' < 1 {
            local _num = strtrim(ustrregexra(string(`_pmax', "%21.`highpdp'f"), "-(?=[0.,]+\z)", ""))
            local _out ">`_num'"
            local _phrase "p > `_num'"
        }
        else {
            if `pvalue' < 0.10 local _out = strtrim(ustrregexra(string(`pvalue', "%21.`pdp'f"), "-(?=[0.,]+\z)", ""))
            else local _out = strtrim(ustrregexra(string(`pvalue', "%21.`highpdp'f"), "-(?=[0.,]+\z)", ""))
            if substr("`_out'", 1, 1) == "." local _out "0`_out'"
            local _phrase "p = `_out'"
        }
    }
    return local value `"`_out'"'
    return local phrase `"`_phrase'"'
    }
    local _rc_outer = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
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
program _tabtools_console_display, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax anything(name=args) [, LABELvar(string) DATAstart(integer 3) HEADERstart(integer 2)]

    gettoken num_cols title : args
    * Peel the compound quotes of a title passed as `"`macro'"'. gettoken
    * and macval() never expand the text: a local-macro reference or a
    * $word in a title is shown as typed.
    gettoken _tt_t1 _tt_t2 : title
    if `"`macval(_tt_t2)'"' == "" local title : copy local _tt_t1

    if `"`macval(title)'"' != "" {
        display as text ""
        display as result `"`macval(title)'"'
    }

    local _display_vars ""
    if "`labelvar'" != "" {
        capture confirm variable `labelvar'
        if _rc {
            display as error "labelvar(): variable `labelvar' not found"
            exit 111
        }
        local _display_vars "`labelvar'"
    }

    local total_rows = _N
    if `total_rows' < `headerstart' {
        display as text ""
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    forvalues c = 1/`num_cols' {
        capture confirm variable c`c'
        if !_rc local _display_vars "`_display_vars' c`c'"
    }

    if "`_display_vars'" == "" {
        display as text ""
        quietly version
        set varabbrev `_orig_varabbrev'
        exit
    }

    list `_display_vars' in `headerstart'/`total_rows', noobs noheader table separator(0)
    display as text ""
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_helpers_ready: Verify helper bundle completeness
* =============================================================================
* Returns rc=0 when all requested helpers are loaded; rc=111 otherwise.
*
* Usage: capture _tabtools_helpers_ready

capture program drop _tabtools_helpers_ready
program _tabtools_helpers_ready, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args required

    if `"`required'"' == "" {
        * the full bundle includes its Mata: a session holding the programs
        * from an older copy of this file must load it again
        mata: st_local("_sep_ready", strofreal(findexternal("_tt_sep_parse()") != NULL))
        if !`_sep_ready' exit 111
        local required "_tabtools_col_letter _tabtools_validate_path _tabtools_validate_color _tabtools_build_col_letters _tabtools_open_file _tabtools_detect_vartype _tabtools_validate_sheet _tabtools_resolve_format _tabtools_resolve_colors _tabtools_classify_stat _tabtools_resolve_stat_format _tabtools_collect_ci_level _tabtools_resolve_ci_level _tabtools_strip_outer_quotes _tabtools_format_p _tabtools_console_display _tabtools_frame_put _tabtools_frame_preflight _tabtools_companion_id _tabtools_require_helpers _tabtools_export_done _regtab_bnotes _tabtools_colwidth _tabtools_export_hint _tabtools_fmt_pct _tabtools_smallcells_opt _tabtools_smallcells_render _tabtools_st_timescale _tabtools_texopts _tabtools_visible_vars"
    }

    local _pair_helper "_tabtools_companion_id"
    local _pair_required : list _pair_helper in required
    if `_pair_required' {
        mata: st_local("_pair_ready", strofreal(findexternal("_tt_companion_id()") != NULL))
        if !`_pair_ready' exit 111
    }

    foreach _prog of local required {
        capture program list `_prog'
        if _rc exit 111
    }
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* =============================================================================
* _tabtools_require_helpers: Require helper bundle completeness
* =============================================================================
* Displays the caller-compatible reinstall message and exits rc=111 when helpers
* are not loaded completely.
*
* Usage: _tabtools_require_helpers [, required(string) failmessage(string)]

capture program drop _tabtools_require_helpers
program _tabtools_require_helpers, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    syntax [, REQUIRED(string asis) FAILMessage(string asis)]

    if `"`failmessage'"' == "" {
        local failmessage "_tabtools_common.ado failed to load fully; reinstall tabtools"
    }

    capture _tabtools_helpers_ready `"`required'"'
    if _rc {
        noisily display as error `"`failmessage'"'
        exit 111
    }
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
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

* =============================================================================
* _tabtools_frame_preflight: validate a frame specification WITHOUT mutating
* =============================================================================
* Parses and fully validates a frame spec (name plus optional ", replace") but
* creates, drops, and renames nothing. This lets a command that writes more than
* one frame validate every destination before it commits any of them, so a bad
* second destination cannot leave a half-written first one behind.
*
* Usage: _tabtools_frame_preflight `"`spec'"' "plotframe()"
*        local nm = r(name)
*        local rp = r(replace)
*
* Returns: r(name)    parsed frame name
*          r(replace) 1 if the replace sub-option was given, else 0
*          r(exists)  1 if a frame of that name exists right now, else 0

* =============================================================================
* _tabtools_export_done: the completion line of an xlsx export
* =============================================================================
* Every table command reports a finished workbook the same way:
*   Exported <r> rows × <c> cols to <file>, sheet <sheet>
* where <r> x <c> is the sheet's final used range as Excel sees it (title,
* header, body, notes and footnotes included), read back from the file after
* the workbook is closed. The caller's r() is held and restored.
*
* Usage: _tabtools_export_done using `"`file'"', sheet(`"`macval(sheet)'"')

capture program drop _tabtools_export_done
program _tabtools_export_done, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _ed_hold
    local _ed_held = 0
    capture noisily {
    syntax using/ , SHEET(string)
    _return hold `_ed_hold'
    local _ed_held = 1
    capture quietly import excel using `"`using'"', describe
    local _ed_rc = _rc
    local _ed_nr .
    local _ed_nc .
    if !`_ed_rc' mata: _tt_export_dims(st_local("sheet"))
    _return restore `_ed_hold'
    local _ed_held = 0
    if `_ed_rc' exit `_ed_rc'
    if missing(`_ed_nr') | missing(`_ed_nc') {
        display as error `"sheet "`macval(sheet)'" not found in `using' after export"'
        exit 601
    }
    display as text "Exported " as result "`_ed_nr'" as text " rows × " ///
        as result "`_ed_nc'" as text " cols to " as result `"`using'"' ///
        as text ", sheet " as result `"`macval(sheet)'"'
    }
    local _rc_outer = _rc
    if `_ed_held' {
        // Reached only on an error path: put the caller's r() back, and say
        // so if that fails rather than leave r() silently replaced
        capture _return restore `_ed_hold'
        local _rc_restore = _rc
        if `_rc_restore' {
            display as error "could not restore r() after the export (rc `_rc_restore')"
            if !`_rc_outer' local _rc_outer = `_rc_restore'
        }
    }
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

capture program drop _tabtools_frame_preflight
program _tabtools_frame_preflight, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
    args frame_spec label

    if `"`label'"' == "" local label "frame()"

    gettoken _pfl_name _pfl_opts : frame_spec, parse(",")
    local _pfl_name = strtrim(`"`_pfl_name'"')
    local _pfl_opts : subinstr local _pfl_opts "," "", all
    local _pfl_opts = strtrim(lower(`"`_pfl_opts'"'))

    if "`_pfl_opts'" != "" & "`_pfl_opts'" != "replace" {
        display as error "`label': unknown sub-option `_pfl_opts'"
        exit 198
    }

    * confirm name reads only the first word, so "res replace" (comma
    * forgotten) used to pass as frame res with replace ignored.
    capture confirm name `_pfl_name'
    if _rc | wordcount(`"`_pfl_name'"') != 1 {
        display as error `"`label': invalid frame name `_pfl_name'"'
        if wordcount(`"`_pfl_name'"') > 1 & lower(word(`"`_pfl_name'"', -1)) == "replace" ///
            display as error `"  did you mean `=subinstr("`label'", "()", "", 1)'(`=word(`"`_pfl_name'"', 1)', replace)?"'
        exit 198
    }

    local _pfl_repl = ("`_pfl_opts'" == "replace")

    capture confirm frame `_pfl_name'
    local _pfl_exists = (_rc == 0)

    if `_pfl_exists' & !`_pfl_repl' {
        display as error "frame `_pfl_name' already exists; use `label' with the replace sub-option"
        exit 110
    }
    if `_pfl_exists' & `_pfl_repl' & "`_pfl_name'" == "`c(frame)'" {
        display as error "`label': cannot replace the current frame (`_pfl_name')"
        exit 198
    }
    * The default frame holds the user's data too (regtab refuses it the same way)
    if `_pfl_exists' & `_pfl_repl' & "`_pfl_name'" == "default" {
        display as error "`label': output frames cannot replace the default frame"
        exit 198
    }

    return local name "`_pfl_name'"
    return scalar replace = `_pfl_repl'
    return scalar exists = `_pfl_exists'
    }
    local _rc_outer = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

capture program drop _tabtools_frame_put
program _tabtools_frame_put, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _fr_stage _fr_backup
    local _fr_stage_created = 0
    local _fr_backup_created = 0
    capture noisily {
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

    * Validate frame name: one word (confirm name reads only the first,
    * so "res replace" used to create frame res with replace ignored).
    capture confirm name `_fr_name'
    if _rc | wordcount(`"`_fr_name'"') != 1 {
        display as error `"frame(): invalid frame name `_fr_name'"'
        if wordcount(`"`_fr_name'"') > 1 & lower(word(`"`_fr_name'"', -1)) == "replace" ///
            display as error `"  did you mean frame(`=word(`"`_fr_name'"', 1)', replace)?"'
        exit 198
    }

    capture confirm frame `_fr_name'
    local _fr_exists = (_rc == 0)
    if `_fr_exists' {
        if "`_fr_opts'" == "replace" {
            if "`_fr_name'" == "`c(frame)'" {
                display as error "frame(): cannot replace the current frame (`_fr_name')"
                exit 198
            }
            if "`_fr_name'" == "default" {
                display as error "frame(): output frames cannot replace the default frame"
                exit 198
            }
        }
        else {
            display as error "frame `_fr_name' already exists"
            exit 110
        }
    }

    * Materialize the replacement before touching an existing destination.
    frame put *, into(`_fr_stage')
    local _fr_stage_created = 1
    if "$TABTOOLS_QA_FRAME_STAGE_FAIL" == "1" exit 459

    if `_fr_exists' {
        frame rename `_fr_name' `_fr_backup'
        local _fr_backup_created = 1
    }
    frame rename `_fr_stage' `_fr_name'
    local _fr_stage_created = 0
    if `_fr_backup_created' {
        frame drop `_fr_backup'
        local _fr_backup_created = 0
    }

    quietly version
    c_local _frame_name "`_fr_name'"
    }
    local _rc_outer = _rc
    if `_fr_stage_created' capture frame drop `_fr_stage'
    if `_fr_backup_created' {
        capture confirm frame `_fr_name'
        if _rc {
            capture frame rename `_fr_backup' `_fr_name'
            local _fr_restore_rc = _rc
        }
        else {
            capture frame drop `_fr_backup'
            local _fr_cleanup_rc = _rc
        }
    }
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

version 17.0
capture mata: mata drop _tt_strip_outer_quotes()
* Allocate without altering caller returns, RNG, globals, or current frame.
capture program drop _tabtools_companion_id
program _tabtools_companion_id, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        tempfile _pair_file
        mata: st_local("_pair_id", _tt_companion_id(st_local("_pair_file")))
        c_local _companion_id `"`macval(_pair_id)'"'
    }
    local _rc_outer = _rc
    quietly version
    set varabbrev `_orig_varabbrev'
    if `_rc_outer' exit `_rc_outer'
end

* Moved from _regtab_bnotes.ado (tabtools 1.2.1; see changelog)
* _regtab_bnotes Version 1.2.0  2026/11/19
* the fit's own constraint notes for every coefficient of the active e(b)
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

* =============================================================================
* _regtab_bnotes: base, empty, omitted, and constrained coefficients of e(b)
* =============================================================================
* Usage: _regtab_bnotes
* Reads the active estimation results. Stata keeps, in the column stripe of
* e(b), what each coefficient is: _ms_element_info returns "(base)",
* "(empty)", or "(omitted)", the notes the estimator's own table prints, for
* main effects and interaction cells alike. A coefficient that the stripe does
* not mark, whose variance is zero, and that a row of e(Cns) fixes on its own
* (constraint define, then constraints()) is constrained: Stata prints its
* value with "(constrained)". Returns, in the caller, _bn_notes: one
* key=code token per such coefficient, separated by spaces, code b (base), e
* (empty), o (omitted), or c (constrained); the key is the coefficient name as
* the collection keys it (1b.x -> 1.x, 1b.g#co.z -> 1.g#z). A key that two
* equations mark differently (or one marks and another does not) is left
* out. "-" when nothing is marked, and ""
* when there is no e(b).
* tabtools fitcount stores the string with each model (tt_cns), so regtab can
* read the fit's own notes for a model that is no longer the active fit;
* regtab computes it directly (via _regtab_activeb) when the model is.
capture program drop _regtab_bnotes
program define _regtab_bnotes, nclass
	version 17.0
	local _orig_varabbrev = c(varabbrev)
	set varabbrev off
	capture noisily {
		local _out ""
		capture confirm matrix e(b)
		local _hasb = !_rc
		if `_hasb' {
			tempname _V _C
			capture matrix `_V' = e(V)
			local _hasV = !_rc
			capture matrix `_C' = e(Cns)
			local _hasC = !_rc
			local _names : colnames e(b)
			local _ncb : word count `_names'
			quietly _ms_eq_info, matrix(e(b))
			local _keq = r(k_eq)
			forvalues _e = 1/`_keq' {
				local _ke_`_e' = r(k`_e')
			}
			local _keys ""
			local _bad ""
			local _j = 0
			forvalues _e = 1/`_keq' {
				forvalues _i = 1/`_ke_`_e'' {
					local ++_j
					quietly _ms_element_info, element(`_i') equation(#`_e') matrix(e(b))
					local _note `"`r(note)'"'
					local _code ""
					if `"`_note'"' == "(base)" local _code "b"
					else if `"`_note'"' == "(empty)" local _code "e"
					else if `"`_note'"' == "(omitted)" local _code "o"
					else if `_hasV' & `_hasC' {
						* fixed by a constraint of its own: zero variance and a
						* row of e(Cns) with this coefficient alone
						if `_V'[`_j', `_j'] == 0 {
							forvalues _r = 1/`=rowsof(`_C')' {
								if `_C'[`_r', `_j'] == 0 continue
								local _alone = 1
								forvalues _q = 1/`_ncb' {
									if `_q' != `_j' & `_C'[`_r', `_q'] != 0 local _alone = 0
								}
								if `_alone' local _code "c"
							}
						}
					}
					* every coefficient is recorded, marked or not, so a key one
					* equation marks and another estimates is ambiguous too
					local _nm : word `_j' of `_names'
					local _key = ustrregexra(ustrregexra(`"`_nm'"', ///
						"(^|#)([0-9]+)[a-z]+\.", "$1$2."), "(^|#)co?\.", "$1")
					local _pos : list posof `"`_key'"' in _keys
					if `_pos' > 0 {
						if "`_code'" != "`_code_`_pos''" local _bad : list _bad | _key
						continue
					}
					local _keys `"`_keys' `_key'"'
					local _pos : word count `_keys'
					local _code_`_pos' "`_code'"
				}
			}
			local _n : word count `_keys'
			forvalues _p = 1/`_n' {
				local _key : word `_p' of `_keys'
				local _isbad : list _key in _bad
				if !`_isbad' & "`_code_`_p''" != "" local _out `"`_out' `_key'=`_code_`_p''"'
			}
			local _out = strtrim(`"`_out'"')
			if `"`_out'"' == "" local _out "-"
		}
		c_local _bn_notes `"`_out'"'
	}
	local _rc = _rc
	set varabbrev `_orig_varabbrev'
	if `_rc' exit `_rc'
end

* Moved from _tabtools_colwidth.ado (tabtools 1.2.1; see changelog)
* _tabtools_colwidth Version 1.2.0  2026/11/19
* Size one exported table column from its own rendered cells
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: rclass
*
* One place for the xlsx column-width heuristic every tabtools engine used to
* carry inline. A column is measured on its OWN cells, never on a maximum
* shared with sibling columns, so one wide column or one verbose header cannot
* pad the rest of the table out to match it.
*
*   _tabtools_colwidth varname [, options]
*     firstrow(#)     first data row measured (default 3: rows 1-2 are the
*                     title and merged/group header rows)
*     exclude(...)    quoted cell texts that never set the width, e.g. the
*                     reference-category label that may overflow safely
*     scale(#) pad(#) width = ceil(maxlen * scale) + pad   (0.85, 2)
*     minwidth(#) maxwidth(#)  bounds; 0 = unbounded
*     headerrow(#)    row holding this column's own wrapped label (0 = none)
*     headerfloor(#)  with headerrow(): raise the width to
*                     min(ceil(hlen / 2) + 1, headerfloor) so the label wraps
*                     to about two lines rather than many
*     headerscale(#)  label length damping before the wrap test (0.9)
*     maxlines(#)     cap on r(hlines) (5)
*
*   _tabtools_colwidth , hlength(#) blockwidth(#)
*     no variable: only r(hlines) for a header of display width hlength()
*     merged across a block of columns blockwidth() wide
*
* Lengths are Unicode display widths (udstrlen), not byte counts, so a
* "±" or "≥" in a cell counts as one character.
*
* Returns: r(width) r(maxlen) r(hlen) r(hlines)

capture program drop _tabtools_colwidth
program define _tabtools_colwidth, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [varname(default=none)] [, FIRSTrow(integer 3) ///
            EXCLude(string asis) SCALE(real 0.85) PAD(real 2) ///
            MINwidth(real 0) MAXwidth(real 0) ///
            HEADERrow(integer 0) HEADERscale(real 0.9) HEADERfloor(real 0) ///
            MAXLines(integer 5) HLENgth(real 0) BLOCKwidth(real 0)]

        if `maxlines' < 1 {
            noisily display as error "maxlines() must be at least 1"
            exit 198
        }

        local _maxlen = 0
        local _width = 0
        local _hlen = `hlength'
        if "`varlist'" != "" {
            local _var `varlist'
            capture confirm string variable `_var'
            if !_rc {
                local _cell `"`_var'"'
                local _hcell `"`_var'[`headerrow']"'
            }
            else {
                local _fmt : format `_var'
                local _cell `"ustrregexra(string(`_var', "`_fmt'"), "-(?=[0.,]+\z)", "")"'
                local _hcell `"ustrregexra(string(`_var'[`headerrow'], "`_fmt'"), "-(?=[0.,]+\z)", "")"'
            }

            local _cond "_n >= `firstrow'"
            local _ex `"`exclude'"'
            while `"`_ex'"' != "" {
                gettoken _tok _ex : _ex
                if `"`_tok'"' != "" local _cond `"`_cond' & `_cell' != `"`_tok'"'"'
            }
            tempvar _len
            quietly generate long `_len' = udstrlen(`_cell') if `_cond'
            quietly summarize `_len', meanonly
            local _maxlen = cond(r(N) > 0, r(max), 0)
            local _width = ceil(`_maxlen' * `scale') + `pad'

            if `headerrow' > 0 & `headerrow' <= _N {
                local _hlen = udstrlen(`_hcell')
            }
            if `headerfloor' > 0 & `_hlen' > 0 {
                local _floor = min(ceil(`_hlen' / 2) + 1, `headerfloor')
                if `_floor' > `_width' local _width = `_floor'
            }
            if `minwidth' > 0 & `_width' < `minwidth' local _width = `minwidth'
            if `maxwidth' > 0 & `_width' > `maxwidth' local _width = `maxwidth'
        }
        else if `blockwidth' <= 0 {
            noisily display as error "_tabtools_colwidth: a variable or blockwidth() is required"
            exit 198
        }

        * Lines the header needs once wrapped inside its own column, or inside
        * the merged block when blockwidth() is given.
        local _wrap = cond(`blockwidth' > 0, `blockwidth', `_width')
        local _hlines = 1
        if `_wrap' > 0 & `_hlen' * `headerscale' > `_wrap' {
            local _hlines = min(ceil(`_hlen' * `headerscale' / `_wrap'), `maxlines')
        }

        return scalar width = `_width'
        return scalar maxlen = `_maxlen'
        return scalar hlen = `_hlen'
        return scalar hlines = `_hlines'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* Moved from _tabtools_export_hint.ado (tabtools 1.2.1; see changelog)
* _tabtools_export_hint Version 1.2.0  2026/11/19
* the hint printed after a failed file export: a missing directory, or a file held open
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

/*
A failed xlsx write (rc 603/608/610/16106, ...) has two common causes: the
target directory does not exist, or the workbook is open in another
application. This program tells them apart so the hint names the right one.

Usage: _tabtools_export_hint `"filename"' [, kind(xlsx)]
Prints one "Hint:" line as an error; returns nothing.
*/

capture program drop _tabtools_export_hint
program define _tabtools_export_hint, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=fname id="filename") [, KIND(string)]
        if `"`kind'"' == "" local kind "xlsx"
        gettoken fname : fname
        * directory part: everything up to the last / or \ (none = cwd)
        local _dir = ustrregexra(`"`fname'"', "[^/\\\\]*$", "")
        local _dir_ok 1
        if `"`_dir'"' != "" & substr(`"`_dir'"', 1, 1) != "~" {
            mata: st_local("_dir_ok", strofreal(direxists(st_local("_dir"))))
        }
        if !`_dir_ok' {
            noisily display as error `"Hint: the directory `_dir' does not exist"'
        }
        else {
            noisily display as error "Hint: ensure the `kind' file is not open in another application and the directory is writable"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end


* Moved from _tabtools_fmt_pct.ado (tabtools 1.2.1; see changelog)
* _tabtools_fmt_pct Version 1.2.0  2026/11/19
* The package's percentage display rule: a share that is neither none nor all never prints as 0 or 100
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: rclass

/*
Every command that prints a percentage formats it through this program, so
the rule lives in one place.

For a value v with 0 < v < 100 and a fixed format %w.df or %w.dfc (or the
decimal-comma %w,df / %w,dfc, which keeps its comma in the escalated text):

    1. format at d decimals, exactly as ustrregexra(string(v, fmt), "-(?=[0.,]+\z)", "") always did
    2. if that text reads 0 or 100, add one decimal at a time, up to
       max(d, 2) decimals ("0" -> "0.3", "0.0" -> "0.04", "100" -> "99.6")
    3. if it still reads 0 or 100 at max(d, 2) decimals, print
       "<0.01" or ">99.99" (that many decimals)

Everything else -- v <= 0, v >= 100, missing, or a %g/%e/other format -- is
ustrregexra(string(v, fmt), "-(?=[0.,]+\z)", "") unchanged, so a true zero count still prints 0 and a whole
group still prints 100. Values within 1e-9 of 0 or 100 count as 0 or 100:
a weighted share whose numerator and denominator are the same sum taken in
a different order lands one ulp off 100, and that is not "not all".

Escalated text is trimmed; the unescalated text is not, so callers keep the
alignment they had.

Scalar mode:  _tabtools_fmt_pct, value(exp) format(%fmt)
              value() is an expression, evaluated into a double scalar here:
              a number passed through a macro is stored as %18.0g text and
              reparses to a different double (100*7/20000 is
              0.034999999999999996 but `=...' gives .035), which moves a
              near-tie to the other side. desctab still hands in its
              percentage as a macro (it always formatted that macro), so a
              share on such a near-tie can print one unit apart in desctab
              and crosstab/tabcell; changing that would move ordinary desctab
              ties, which this rule leaves alone.
              r(text)      the display text
              r(decimals)  decimals used when escalated or capped, else .

Variable mode: _tabtools_fmt_pct pctvar [if] [in], format(%fmt) ///
                   generate(newstrvar) [decimals(newvar)]
              decimals() is filled where the text was escalated or capped,
              missing elsewhere, so a caller can print interval limits at
              the same precision as the estimate. Rows outside the sample
              are "" (and missing).
*/

capture program drop _tabtools_fmt_pct
program define _tabtools_fmt_pct, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [varlist(numeric max=1 default=none)] [if] [in], ///
            Format(string) [VALue(string) GENerate(name) DECimals(name)]

        local _scalar = "`varlist'" == ""
        if `_scalar' {
            if `"`value'"' == "" | "`generate'`decimals'" != "" {
                display as error "_tabtools_fmt_pct: give value() alone, or a variable with generate()"
                exit 198
            }
            if `"`if'`in'"' != "" {
                display as error "_tabtools_fmt_pct: if and in need a variable"
                exit 198
            }
            tempname _sv
            scalar `_sv' = `value'
        }
        else {
            if "`generate'" == "" | `"`value'"' != "" {
                display as error "_tabtools_fmt_pct: give value() alone, or a variable with generate()"
                exit 198
            }
            confirm new variable `generate' `decimals'
        }

        * Decimals of a fixed format; anything else passes through unchanged
        local _fixed = regexm(`"`format'"', "^%-?0?[0-9]+([.,])([0-9]+)(fc|f)$")
        if `_fixed' {
            local _sep = regexs(1)
            local _d = real(regexs(2))
            local _fc = regexs(3)
            local _cap = max(`_d', 2)
            local _lo = "<" + strtrim(ustrregexra(string(10^(-`_cap'), "%21`_sep'`_cap'f"), "-(?=[0.,]+\z)", ""))
            local _hi = ">" + strtrim(ustrregexra(string(100 - 10^(-`_cap'), "%21`_sep'`_cap'f"), "-(?=[0.,]+\z)", ""))
        }
        local _tol = 1e-9

        if `_scalar' {
            local _text = ustrregexra(string(`_sv', `"`format'"'), "-(?=[0.,]+\z)", "")
            local _dec = .
            if `_fixed' & `_sv' > `_tol' & `_sv' < 100 - `_tol' {
                forvalues _k = `=`_d' + 1'/`_cap' {
                    if inlist(real(subinstr("`_text'", ",", ".", .)), 0, 100) {
                        local _text = strtrim(ustrregexra(string(`_sv', "%21`_sep'`_k'`_fc'"), "-(?=[0.,]+\z)", ""))
                        local _dec = `_k'
                    }
                }
                if inlist(real(subinstr("`_text'", ",", ".", .)), 0, 100) {
                    local _text = cond(real(subinstr("`_text'", ",", ".", .)) == 0, "`_lo'", "`_hi'")
                    local _dec = `_cap'
                }
            }
            return local text `"`_text'"'
            return scalar decimals = `_dec'
        }
        else {
            marksample touse, novarlist
            local v `varlist'
            tempvar _esc
            quietly {
                gen str32 `generate' = ustrregexra(string(`v', `"`format'"'), "-(?=[0.,]+\z)", "") if `touse'
                gen byte `_esc' = 0
                if `_fixed' {
                    replace `_esc' = 1 if `touse' & `v' > `_tol' & `v' < 100 - `_tol'
                }
                if "`decimals'" != "" gen byte `decimals' = .
                if `_fixed' {
                    forvalues _k = `=`_d' + 1'/`_cap' {
                        local _need "`_esc' & inlist(real(subinstr(`generate', ",", ".", .)), 0, 100)"
                        if "`decimals'" != "" replace `decimals' = `_k' if `_need'
                        replace `generate' = strtrim(ustrregexra(string(`v', "%21`_sep'`_k'`_fc'"), "-(?=[0.,]+\z)", "")) if `_need'
                    }
                    local _need "`_esc' & inlist(real(subinstr(`generate', ",", ".", .)), 0, 100)"
                    if "`decimals'" != "" replace `decimals' = `_cap' if `_need'
                    replace `generate' = cond(real(subinstr(`generate', ",", ".", .)) == 0, "`_lo'", "`_hi'") if `_need'
                }
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* Moved from _tabtools_smallcells_opt.ado (tabtools 1.2.1; see changelog)
* _tabtools_smallcells_opt Version 1.2.0  2026/11/19
* Resolve smallcells(# [, primary]), nosmallcells, and the session default
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

/*
    _tabtools_smallcells_opt , [smallcells(string) nosmallcells]

    Resolves the disclosure threshold for one call of desctab, table1_tc or
    crosstab. Precedence: an explicit smallcells() > nosmallcells (no
    masking) > the session default set by -tabtools set smallcells #
    [primary]- > none.

    Sets in the caller (every exit path assigns both):
        _sc_k      the threshold, or empty when no masking applies
        _sc_mode   "full" (complementary cells, the default) or "primary"

    When the session default is used, one line naming it is printed, so the
    hidden state is visible in the log.

    _tabtools_smallcells_opt __empty <the caller's own `0'>

    A string option cannot tell smallcells() from an absent option, so an
    empty smallcells() (for example smallcells(`k') with k undefined) would
    fall through to the session default or to no masking at rc 0. A caller
    whose smallcells is empty after -syntax- passes its own command line
    here; an option token smallc[ells]() holding only blanks is refused with
    r(198). Tokens are read with gettoken bind, so text inside another
    option (title("... smallcells() ...")) is never matched. This mode sets
    nothing in the caller.
*/

capture program drop _tabtools_smallcells_opt
program define _tabtools_smallcells_opt, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _k ""
    local _mode ""
    local _chkmode 0
    gettoken _first _chkrest : 0, parse(" ,")
    mata: st_local("_chkmode", strofreal(st_local("_first") == "__empty"))
    capture noisily {
      if `_chkmode' {
        * The caller's line may hold any text (a backquote before a double
        * quote opens a compound quote), so it is never expanded inside
        * quotes here: the loop tests its length and Mata reads the token.
        while `: length local _chkrest' {
            gettoken _tok _chkrest : _chkrest, parse(" ,") bind quotes
            local _onm ""
            mata: st_local("_onm", regexm(st_local("_tok"), "^([a-z]+)[(][ ]*[)]$") ? regexs(1) : "")
            if "`_onm'" != "" {
                if strlen("`_onm'") >= 6 & strpos("smallcells", "`_onm'") == 1 {
                    display as error "smallcells() is empty; it must hold an integer of 3 or more (smallcells(#) or smallcells(#, primary)); use nosmallcells for no masking"
                    exit 198
                }
            }
        }
      }
      else {
        syntax , [SMALLCells(string asis) NOSMALLCells]

        local _raw = strtrim(`"`smallcells'"')
        if `"`_raw'"' != "" & "`nosmallcells'" != "" {
            display as error "smallcells() and nosmallcells may not be combined"
            exit 198
        }
        if `"`_raw'"' != "" {
            * "#" or "#, primary": peel the number, then parse the suboption.
            gettoken _num _rest : _raw, parse(",")
            local _num = strtrim(`"`_num'"')
            local _rest = strtrim(`"`_rest'"')
            local _sub ""
            if `"`_rest'"' != "" {
                if substr(`"`_rest'"', 1, 1) != "," {
                    display as error "smallcells() must be # or #, primary"
                    exit 198
                }
                local _sub = strtrim(substr(`"`_rest'"', 2, .))
                if lower(`"`_sub'"') != "primary" {
                    display as error `"smallcells(): unknown suboption `_sub'; the only suboption is primary"'
                    exit 198
                }
            }
            capture confirm integer number `_num'
            if _rc {
                display as error "smallcells() must be an integer greater than or equal to 3"
                exit 198
            }
            if `_num' < 3 {
                display as error "smallcells() must be an integer greater than or equal to 3"
                exit 198
            }
            local _k = `_num'
            local _mode = cond(`"`_sub'"' != "", "primary", "full")
        }
        else if "`nosmallcells'" == "" & `"$TABTOOLS_set_smallcells"' != "" {
            local _k `"$TABTOOLS_set_smallcells"'
            capture confirm integer number `_k'
            if _rc | `"`_k'"' == "" {
                display as error "session smallcells default is not an integer; reset it with tabtools set smallcells #"
                exit 198
            }
            if `_k' < 3 {
                display as error "session smallcells default must be 3 or more; reset it with tabtools set smallcells #"
                exit 198
            }
            * the number, not its spelling: a global written directly as +5
            * or 05 still prints <5
            local _k = `_k'
            local _mode = cond(`"$TABTOOLS_set_smallcells_mode"' == "primary", "primary", "full")
            local _echo "smallcells(`_k')"
            if "`_mode'" == "primary" local _echo "smallcells(`_k', primary)"
            display as text "(tabtools: using session `_echo')"
        }
      }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_chkmode' {
        if `rc' exit `rc'
        exit
    }
    if `rc' {
        c_local _sc_k ""
        c_local _sc_mode ""
        exit `rc'
    }
    c_local _sc_k `"`_k'"'
    c_local _sc_mode `"`_mode'"'
end

* Moved from _tabtools_smallcells_render.ado (tabtools 1.2.1; see changelog)
* _tabtools_smallcells_render Version 1.2.0  2026/11/19
* Render safe disclosure-control strings and numeric extended missings
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: rclass

capture program drop _tabtools_smallcells_render
program define _tabtools_smallcells_render, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax, VALUE(real) MASK(integer) SMALLCells(integer) [Format(string)]

        if `smallcells' < 3 {
            display as error "smallcells() must be an integer greater than or equal to 3"
            exit 198
        }
        if !inlist(`mask', 0, 1, 2, 3) {
            display as error "mask() must be 0, 1, 2, or 3"
            exit 198
        }
        if "`format'" == "" local format "%12.0fc"

        if `mask' == 0 {
            local rendered = ustrregexra(string(`value', "`format'"), "-(?=[0.,]+\z)", "")
            return local display "`rendered'"
            return scalar value = `value'
        }
        else if `mask' == 1 {
            return local display "<`smallcells'"
            return scalar value = .p
        }
        else if `mask' == 2 {
            return local display "≥`smallcells'"
            return scalar value = .s
        }
        else {
            return local display "Suppressed"
            return scalar value = .d
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* Moved from _tabtools_st_timescale.ado (tabtools 1.2.1; see changelog)
* _tabtools_st_timescale Version 1.2.0  2026/11/19
* the calendar unit of stset analysis time, when the data say it
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

/*
stset keeps the time variable (_dta[st_bt]) and its scale (_dta[st_bs]).
When that variable carries a date format and no scale() was given, analysis
time is in days (%td, %d) or milliseconds (%tc, %tC). Commands that label
person-time as years by default use this to say so, rather than print a
person-years header over person-days.

Usage: _tabtools_st_timescale
Returns in the caller: _st_unit ("days", "milliseconds", or "" when the data
do not say), and _st_timevar (the stset time variable).
*/

capture program drop _tabtools_st_timescale
program define _tabtools_st_timescale, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    c_local _st_unit ""
    c_local _st_timevar ""
    capture noisily {
        local _bt : char _dta[st_bt]
        local _bs : char _dta[st_bs]
        if "`_bs'" == "" local _bs 1
        capture confirm numeric variable `_bt', exact
        if !_rc & real("`_bs'") == 1 {
            local _fmt : format `_bt'
            local _fmt = subinstr("`_fmt'", "-", "", 1)
            local _unit ""
            if regexm("`_fmt'", "^%(td|d)") local _unit "days"
            else if regexm("`_fmt'", "^%t[cC]") local _unit "milliseconds"
            c_local _st_unit "`_unit'"
            c_local _st_timevar "`_bt'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* Moved from _tabtools_texopts.ado (tabtools 1.2.1; see changelog)
* _tabtools_texopts Version 1.2.0  2026/11/19
* Parse and validate texopts(), the LaTeX layout sub-options
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: rclass

/*
    _tabtools_texopts `"<texopts() contents>"' [, session]

    Sub-options (all optional):
        none                 the default layout (alone); lets one command
                             set aside a session value
        captionleft          flush-left caption       (needs caption)
        captionbelow         caption under the table
        nocentering          no \centering
        placement(spec)      float placement, letters h t b p and !, or H
                             alone (H needs float); default htbp
        size(name)           tiny scriptsize footnotesize small normalsize
                             large: type size of the tabular
        fit                  shrink a table wider than the line to the line
                             width (needs graphicx); never enlarges
        landscape            the float on its own rotated page (needs
                             pdflscape)
        label(key)           \label key instead of tab:<file stem>
        preamble("line" ...) extra preamble lines, used when texdocument
                             creates the document
        docclass(class [opt ...])  \documentclass[opt,...]{class} for a
                             document texdocument creates; default article

    session refuses label(): one key on every table of a session is a
    multiply-defined label.

    Returns r(captionleft) r(captionbelow) r(nocentering) r(fit)
    r(landscape) (each 1 or 0), r(placement), r(size), r(label),
    r(npreamble) and r(preamble1)... (one line each), r(docclass),
    r(classopts) (comma-separated), r(packages) (packages the layout
    needs besides booktabs, space-separated).
*/

capture program drop _tabtools_texopts
program define _tabtools_texopts, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken _spec 0 : 0
        syntax [, SESSION]
        local _valid "none captionleft captionbelow nocentering placement() size() fit landscape label() preamble() docclass()"
        local 0 `", `macval(_spec)'"'
        capture syntax [, none captionleft captionbelow nocentering ///
            placement(string) size(string) fit landscape label(string) ///
            preamble(string asis) docclass(string)]
        local _src = _rc
        * syntax files a no-prefixed option under its bare name (nocentering
        * in local centering, none in local ne) and also accepts that bare
        * name, recording nothing: read both words from the text instead.
        local _bad = ustrregexm(`"`macval(_spec)'"', "(^|[ ,])(centering|ne)([ ,]|$)")
        local none = cond(ustrregexm(`"`macval(_spec)'"', "(^|[ ,])none([ ,]|$)"), "none", "")
        if `_src' | `_bad' {
            noisily display as error `"texopts(): unknown or malformed sub-option in "`macval(_spec)'""'
            noisily display as error "valid sub-options: `_valid'"
            exit 198
        }
        * none: the default layout, for one command under a session value
        if "`none'" != "" & strtrim(`"`macval(_spec)'"') != "none" {
            noisily display as error "texopts(none) cannot be combined with other sub-options"
            exit 198
        }
        if "`none'" != "" & "`session'" != "" {
            noisily display as error "tabtools set texopts: use tabtools set texopts clear to remove the session layout"
            exit 198
        }

        local _packages ""
        if "`captionleft'" != "" local _packages "`_packages' caption"

        local placement = strtrim(`"`placement'"')
        if `"`placement'"' == "" local placement "htbp"
        * LaTeX takes the ! anywhere in the specifier (h!t), at most once
        if !ustrregexm(`"`placement'"', "^(H|[htbp!]*[htbp][htbp!]*)$") | ///
            strlen(`"`placement'"') - strlen(subinstr(`"`placement'"', "!", "", .)) > 1 {
            noisily display as error `"texopts(placement()): "`placement'" is not a float placement; use letters from h t b p with an optional !, or H alone"'
            exit 198
        }
        if "`placement'" == "H" local _packages "`_packages' float"

        local size = strtrim(`"`size'"')
        if `"`size'"' != "" & !inlist(`"`size'"', "tiny", "scriptsize", ///
            "footnotesize", "small", "normalsize", "large") {
            noisily display as error `"texopts(size()): "`size'" is not one of tiny, scriptsize, footnotesize, small, normalsize, large"'
            exit 198
        }

        if "`fit'" != "" local _packages "`_packages' graphicx"
        if "`landscape'" != "" local _packages "`_packages' pdflscape"

        local label = strtrim(`"`label'"')
        if `"`label'"' != "" {
            if "`session'" != "" {
                noisily display as error "tabtools set texopts: label() names one table; give it in that command's texopts() instead"
                exit 198
            }
            if !ustrregexm(`"`label'"', "^[A-Za-z0-9_:.-]+$") {
                noisily display as error `"texopts(label()): "`label'" may contain only letters, digits, _ : . and -"'
                exit 198
            }
        }

        * preamble(): each quoted string is one line, written as given. A
        * line may not start or end the document; that frame is tabtools'.
        local _np = 0
        local _rest `"`macval(preamble)'"'
        while `"`macval(_rest)'"' != "" {
            gettoken _line _rest : _rest
            local _line = strtrim(`"`macval(_line)'"')
            if `"`macval(_line)'"' == "" continue
            if strpos(`"`macval(_line)'"', "documentclass") | ///
                strpos(`"`macval(_line)'"', "{document}") {
                noisily display as error "texopts(preamble()): a line may not contain \documentclass, \begin{document} or \end{document}; tabtools writes those"
                exit 198
            }
            local ++_np
            local _pre`_np' `"`macval(_line)'"'
        }

        local _class "article"
        local _copts ""
        local docclass = strtrim(`"`docclass'"')
        if `"`docclass'"' != "" {
            gettoken _class _co : docclass
            if !ustrregexm(`"`_class'"', "^[A-Za-z][A-Za-z0-9-]*$") {
                noisily display as error `"texopts(docclass()): "`_class'" is not a document class name"'
                exit 198
            }
            foreach _o of local _co {
                if !ustrregexm(`"`_o'"', "^[A-Za-z0-9.=-]+$") {
                    noisily display as error `"texopts(docclass()): class option "`_o'" may contain only letters, digits, . = and -"'
                    exit 198
                }
                local _copts = cond("`_copts'" == "", "`_o'", "`_copts',`_o'")
            }
        }

        return local packages = strtrim("`_packages'")
        return local classopts "`_copts'"
        return local docclass "`_class'"
        return scalar npreamble = `_np'
        forvalues _i = 1/`_np' {
            return local preamble`_i' `"`macval(_pre`_i')'"'
        }
        return local label `"`label'"'
        return local size `"`size'"'
        return local placement `"`placement'"'
        * syntax files a no-prefixed option under the bare name: nocentering
        * arrives in local centering, never in local nocentering.
        return scalar nocentering = ("`centering'" == "nocentering")
        foreach _f in captionleft captionbelow fit landscape {
            return scalar `_f' = ("``_f''" != "")
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* Moved from _tabtools_visible_vars.ado (tabtools 1.2.1; see changelog)
* _tabtools_visible_vars Version 1.2.0  2026/11/19
* Resolve visible table variables for CSV and Markdown exports
* Author: Timothy P Copeland, Karolinska Institutet
* Program class: nclass

capture program drop _tabtools_visible_vars
program define _tabtools_visible_vars, nclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, LABELVar(name)]

        quietly ds
        local _allvars `r(varlist)'
        if "`_allvars'" == "" {
            noisily display as error "No variables available for export"
            exit 111
        }

        local _vars ""
        if `"`labelvar'"' != "" {
            capture confirm variable `labelvar'
            if !_rc local _vars "`labelvar'"
        }

        local _cvars ""
        foreach _v of local _allvars {
            if regexm("`_v'", "^c[0-9]+$") local _cvars "`_cvars' `_v'"
        }

        if `"`_cvars'"' != "" {
            local _vars `"`_vars' `_cvars'"'
        }
        else {
            foreach _v of local _allvars {
                if regexm("`_v'", "(_length|_max)$") continue
                if regexm("`_v'", "^ref[0-9]+$") continue
                local _vars `"`_vars' `_v'"'
            }
        }

        local _vars : list uniq _vars
        local _vars : list _vars & _allvars
        local _vars : list clean _vars
        if "`_vars'" == "" {
            noisily display as error "No visible output columns available for export"
            exit 111
        }

        c_local _tabtools_visible_vars "`_vars'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _tt_companion_id()
capture mata: mata drop _tt_collect_ci_level_json()
capture mata: mata drop _tt_sep_parse()
capture mata: mata drop _tt_sep_optarg()
capture mata: mata drop _tt_export_dims()
capture mata: mata drop _tt_bundle_build()
* matastrict is a session setting: save the caller's value here and
* restore it after the block, so loading this file never leaks it.
local _tt_ms0 = c(matastrict)
mata:
mata set matastrict on

// Used range of the worksheet named sheet (Excel matches names without
// regard to case) from the r() of -import excel, describe-: "A1:H6" is
// 6 rows x 8 columns. Sets locals _ed_nr and _ed_nc; leaves them missing
// when the sheet is absent.
void _tt_export_dims(string scalar sheet)
{
    real scalar i, n, k, nc, nr
    string scalar rng, cell, col

    n = st_numscalar("r(N_worksheet)")
    for (i = 1; i <= n; i++) {
        if (ustrlower(st_global("r(worksheet_" + strofreal(i) + ")")) != ustrlower(sheet)) continue
        rng = st_global("r(range_" + strofreal(i) + ")")
        k = strpos(rng, ":")
        cell = (k ? substr(rng, k + 1, .) : rng)
        col = ustrregexra(cell, "[0-9]", "")
        nr = strtoreal(ustrregexra(cell, "[A-Za-z]", ""))
        nc = 0
        for (k = 1; k <= strlen(col); k++) {
            nc = nc * 26 + strpos("ABCDEFGHIJKLMNOPQRSTUVWXYZ", substr(strupper(col), k, 1))
        }
        st_local("_ed_nr", strofreal(nr))
        st_local("_ed_nc", strofreal(nc))
        return
    }
}

// tempfile names are reusable after program return. A persistent invocation
// sequence distinguishes calls; a live-frame scan also protects mata clear.
string scalar _tt_companion_id(string scalar filetoken)
{
    pointer() scalar sequence
    string scalar candidate, current
    string vector frames
    real scalar i, collision

    sequence = findexternal("_tabtools_companion_seq")
    if (sequence == NULL) {
        sequence = crexternal("_tabtools_companion_seq")
        *sequence = 0
    }
    if (eltype(*sequence) != "real") _error(3498)
    if (rows(*sequence) != 1 | cols(*sequence) != 1) _error(3498)
    if (missing(*sequence) | *sequence < 0 | *sequence != floor(*sequence)) _error(3498)
    current = st_framecurrent()
    frames = st_framedir()
    do {
        if (*sequence >= 9007199254740991) _error(3498)
        *sequence = *sequence + 1
        candidate = filetoken + ":" + strtrim(ustrregexra(strofreal(*sequence, "%21.0f"), "-(?=[0.,]+\z)", ""))
        collision = 0
        // st_framedir() is a column vector: every frame, not the first
        for (i = 1; i <= length(frames); i++) {
            st_framecurrent(frames[i])
            if (st_global("_dta[tabtools_companion_id]") == candidate) collision = 1
        }
        st_framecurrent(current)
    } while (collision)
    return(candidate)
}

// First usable "ci-level" value (0 < level < 100) in a collect save .stjson
// file, or missing. Mirrors the line scan it replaced: the text after the
// colon that follows the key, with commas and closing braces removed.
real scalar _tt_collect_ci_level_json(string scalar path)
{
    string colvector lines
    string scalar needle, tail
    real scalar i, pos, colon, cand

    needle = char(34) + "ci-level" + char(34)
    lines = cat(path)
    for (i = 1; i <= rows(lines); i++) {
        pos = strpos(lines[i], needle)
        if (pos == 0) continue
        colon = strpos(substr(lines[i], pos, .), ":")
        if (colon == 0) continue
        tail = substr(lines[i], pos + colon, .)
        tail = subinstr(subinstr(tail, ",", ""), "}", "")
        cand = strtoreal(strtrim(tail))
        if (cand < . & cand > 0 & cand < 100) return(cand)
    }
    return(.)
}

string scalar _tt_strip_outer_quotes(string scalar x)
{
    real scalar n
    string scalar compound_open, compound_close

    compound_open = char(96) + char(34)
    compound_close = char(34) + char(39)
    n = strlen(x)
    if (n >= 4 & substr(x, 1, 2) == compound_open &
        substr(x, n - 1, 2) == compound_close) {
        x = substr(x, 3, n - 4)
        n = strlen(x)
    }
    if (n >= 2 & substr(x, 1, 1) == char(34) &
        substr(x, n, 1) == char(34)) {
        x = substr(x, 2, n - 2)
    }
    return(x)
}

// The interval separator, sep() or cisep(), is data (help tabtools##sep).
// Every command declares it a plain string option, so syntax reads it by
// Stata's rule (one quote layer removed, blanks outside quotes dropped);
// empty means the default ", ". It is read and written only through
// st_local(), so no macro in it is ever expanded.
string scalar _tt_sep_parse(string scalar raw)
{
    return(raw == "" ? ", " : raw)
}

// name(text) that hands a separator to another command's string option
// unchanged: simple quotes, or compound quotes when the text holds a double
// quote (text a user could type there is balanced in them). The result is
// spliced into a command line with macval(), never re-expanded.
string scalar _tt_sep_optarg(string scalar name, string scalar s)
{
    if (strpos(s, char(34))) {
        return(name + "(" + char(96) + char(34) + s + char(34) + char(39) + ")")
    }
    return(name + "(" + char(34) + s + char(34) + ")")
}

// Release sentinel. Every loader block asserts it equals that file's own
// release, so a session holding an older copy of this file (whose programs
// and Mata pass the other checks) loads this one again.
string scalar _tt_bundle_build()
{
    return("1.2.1")
}

end
mata: mata set matastrict `_tt_ms0'

* End of file

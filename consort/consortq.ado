*! consortq Version 1.0.1  09dec2025
*! Author: Timothy P Copeland
*! CONSORT-style cohort flow diagram for observational/retrospective studies

program define consortq, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax , ///
        /// Box 1 (required - starting population)
        N1(integer)                     /// Starting N
        [Label1(string)]                /// Label for box 1
        ///
        /// Exclusion 1 -> Box 2
        [EXC1(integer 0)]               /// Number excluded
        [EXC1_reasons(string asis)]     /// Exclusion reasons
        [N2(integer -1)]                /// N after exclusion 1
        [Label2(string)]                /// Label for box 2
        ///
        /// Exclusion 2 -> Box 3
        [EXC2(integer 0)]               /// Number excluded
        [EXC2_reasons(string asis)]     /// Exclusion reasons
        [N3(integer -1)]                /// N after exclusion 2
        [Label3(string)]                /// Label for box 3
        ///
        /// Exclusion 3 -> Box 4
        [EXC3(integer 0)]               /// Number excluded
        [EXC3_reasons(string asis)]     /// Exclusion reasons
        [N4(integer -1)]                /// N after exclusion 3
        [Label4(string)]                /// Label for box 4
        ///
        /// Exclusion 4 -> Box 5
        [EXC4(integer 0)]               /// Number excluded
        [EXC4_reasons(string asis)]     /// Exclusion reasons
        [N5(integer -1)]                /// N after exclusion 4
        [Label5(string)]                /// Label for box 5
        ///
        /// Exclusion 5 -> Box 6
        [EXC5(integer 0)]               /// Number excluded
        [EXC5_reasons(string asis)]     /// Exclusion reasons
        [N6(integer -1)]                /// N after exclusion 5
        [Label6(string)]                /// Label for box 6
        ///
        /// Exclusion 6 -> Box 7
        [EXC6(integer 0)]               /// Number excluded
        [EXC6_reasons(string asis)]     /// Exclusion reasons
        [N7(integer -1)]                /// N after exclusion 6
        [Label7(string)]                /// Label for box 7
        ///
        /// Exclusion 7 -> Box 8
        [EXC7(integer 0)]               /// Number excluded
        [EXC7_reasons(string asis)]     /// Exclusion reasons
        [N8(integer -1)]                /// N after exclusion 7
        [Label8(string)]                /// Label for box 8
        ///
        /// Exclusion 8 -> Box 9
        [EXC8(integer 0)]               /// Number excluded
        [EXC8_reasons(string asis)]     /// Exclusion reasons
        [N9(integer -1)]                /// N after exclusion 8
        [Label9(string)]                /// Label for box 9
        ///
        /// Exclusion 9 -> Box 10
        [EXC9(integer 0)]               /// Number excluded
        [EXC9_reasons(string asis)]     /// Exclusion reasons
        [N10(integer -1)]               /// N after exclusion 9
        [Label10(string)]               /// Label for box 10
        ///
        /// Graph options
        [TItle(string asis)]            /// Graph title
        [SUBtitle(string asis)]         /// Graph subtitle
        [NAME(string)]                  /// Graph name in memory
        [SAVing(string asis)]           /// Save graph to file
        [REPLACE]                       /// Replace existing graph
        [SCHeme(string)]                /// Graph scheme
        [noDRAW]                        /// Don't display graph
        ///
        /// Appearance options
        [BOXColor(string)]              /// Box fill color (default: white)
        [BOXBorder(string)]             /// Box border color (default: black)
        [EXCColor(string)]              /// Exclusion box color (default: gs14)
        [ARRowColor(string)]            /// Arrow color (default: black)
        [TEXTSize(string)]              /// Text size (default: small)
        [EXCTextSize(string)]           /// Exclusion text size (default: vsmall)
        [WIDth(real 6)]                 /// Graph width in inches
        [HEight(real 9)]                /// Graph height in inches
        ]

    * =========================================================================
    * VALIDATION AND SETUP
    * =========================================================================

    * Validate n1
    if `n1' <= 0 {
        display as error "n1() must be positive"
        exit 198
    }

    * Set defaults
    if "`boxcolor'" == "" local boxcolor "white"
    if "`boxborder'" == "" local boxborder "black"
    if "`exccolor'" == "" local exccolor "gs14"
    if "`arrowcolor'" == "" local arrowcolor "black"
    if "`textsize'" == "" local textsize "small"
    if "`exctextsize'" == "" local exctextsize "vsmall"

    * Default labels
    if "`label1'" == "" local label1 "Initial population"

    * Count number of boxes and validate
    * First pass: detect how many boxes are specified (find highest used index)
    local nboxes = 1
    forvalues i = 1/9 {
        local next = `i' + 1
        if `n`next'' >= 0 | `exc`i'' > 0 | "`label`next''" != "" {
            local nboxes = `next'
        }
    }

    * Second pass: validate sequential specification and calculate missing n values
    local prev_n = `n1'
    forvalues i = 2/`nboxes' {
        local prev = `i' - 1

        * Check that intermediate boxes have proper specification
        * (either explicit n, or an exclusion from previous step, or a label)
        if `i' < `nboxes' {
            if `n`i'' < 0 & `exc`prev'' == 0 & "`label`i''" == "" {
                display as error "Gap in flow specification: box `i' is undefined"
                display as error "Specify n`i'(), exc`prev'(), or label`i'() to define box `i'"
                exit 198
            }
        }

        * Auto-calculate n if not provided but exclusion exists
        if `n`i'' < 0 & `exc`prev'' > 0 {
            local n`i' = `prev_n' - `exc`prev''
        }
        else if `n`i'' < 0 {
            * No exclusion and no explicit n - carry forward previous n
            local n`i' = `prev_n'
        }

        * Validate
        if `n`i'' < 0 {
            display as error "n`i'() cannot be negative"
            exit 198
        }
        if `exc`prev'' > `prev_n' {
            display as error "exc`prev'() cannot exceed previous n (`prev_n')"
            exit 198
        }

        local prev_n = `n`i''
    }

    * Set default labels (after counting boxes so we know which is last)
    forvalues i = 2/`nboxes' {
        if "`label`i''" == "" {
            if `i' == `nboxes' {
                local label`i' "Final cohort"
            }
            else {
                local prev = `i' - 1
                local label`i' "After exclusion `prev'"
            }
        }
    }

    * =========================================================================
    * COORDINATE SYSTEM SETUP
    * =========================================================================
    * Y-axis: 0 (bottom) to 100 (top)
    * X-axis: 0 (left) to 100 (right)
    *
    * Main boxes on the left (x=30)
    * Exclusion boxes on the right (x=75)

    local x_main = 30
    local x_exc = 75

    * Calculate vertical spacing
    local y_top = 95
    local y_bottom = 8
    local y_range = `y_top' - `y_bottom'

    * Space between boxes depends on number of boxes
    * Each box takes some space, arrows between them
    local box_height = 6
    local total_box_height = `nboxes' * `box_height'
    local remaining = `y_range' - `total_box_height'
    if `nboxes' > 1 {
        local spacing = `remaining' / (`nboxes' - 0.5)
    }
    else {
        local spacing = 0
    }

    * =========================================================================
    * BUILD GRAPH
    * =========================================================================

    preserve
    clear
    quietly set obs 1
    generate x = .
    generate y = .

    * Start building the twoway command
    local graph_cmd "twoway"

    * Add invisible scatter for coordinate system
    local graph_cmd "`graph_cmd' (scatteri 0 0 100 100, msymbol(none))"

    * Arrow and line options
    local arrow_opts "lcolor(`arrowcolor') mcolor(`arrowcolor') mlwidth(medthick)"
    local line_opts "lcolor(`arrowcolor') lwidth(medthick)"

    * Text box options
    local box_opts "size(`textsize') placement(c) box fcolor(`boxcolor') lcolor(`boxborder') margin(small) justification(center)"
    local exc_opts "size(`exctextsize') placement(c) box fcolor(`exccolor') lcolor(`boxborder') margin(small) justification(left)"

    * Build text content
    local text_content ""

    * Calculate y positions for each box
    local y_pos = `y_top'

    forvalues i = 1/`nboxes' {
        * Store y position for this box
        local y`i' = `y_pos'

        * Main box text
        local txt`i' "`label`i''" "(n=`n`i'')"
        local text_content `"`text_content' text(`y`i'' `x_main' `txt`i'', `box_opts')"'

        * Arrow down and exclusion box (if not last box)
        if `i' < `nboxes' {
            local exc_idx = `i'

            * Calculate positions for arrow and exclusion
            local y_arrow_start = `y`i'' - 3
            local y_arrow_mid = `y`i'' - `spacing'/2 - 1.5
            local y_next = `y`i'' - `spacing' - `box_height'

            * Vertical arrow segment down
            local graph_cmd "`graph_cmd' (pci `y_arrow_start' `x_main' `y_arrow_mid' `x_main', `line_opts')"

            * If there's an exclusion, add horizontal line and exclusion box
            if `exc`exc_idx'' > 0 {
                * Horizontal line to exclusion
                local graph_cmd "`graph_cmd' (pci `y_arrow_mid' `x_main' `y_arrow_mid' `=`x_exc'-10', `line_opts')"
                local graph_cmd "`graph_cmd' (pcarrowi `y_arrow_mid' `=`x_exc'-10' `y_arrow_mid' `=`x_exc'-5', `arrow_opts')"

                * Exclusion box text
                local exc_txt "Excluded (n=`exc`exc_idx'')"
                if `"`exc`exc_idx'_reasons'"' != "" {
                    local exc_reasons_clean = subinstr(`"`exc`exc_idx'_reasons'"', ";;", char(10), .)
                    local exc_txt "`exc_txt'" "`exc_reasons_clean'"
                }
                local text_content `"`text_content' text(`y_arrow_mid' `x_exc' `exc_txt', `exc_opts')"'
            }

            * Continue arrow down to next box
            local graph_cmd "`graph_cmd' (pcarrowi `y_arrow_mid' `x_main' `=`y_next'+3' `x_main', `arrow_opts')"

            * Update y position for next box
            local y_pos = `y_next'
        }
    }

    * Build final graph options
    local graph_options "xscale(off range(-5 105)) yscale(off range(-5 105))"
    local graph_options "`graph_options' plotregion(margin(zero) lcolor(white))"
    local graph_options "`graph_options' graphregion(color(white) margin(small))"
    local graph_options "`graph_options' legend(off)"
    local graph_options "`graph_options' aspectratio(`=`height'/`width'')"

    * Add title if specified
    if `"`title'"' != "" {
        local graph_options `"`graph_options' title(`title')"'
    }
    if `"`subtitle'"' != "" {
        local graph_options `"`graph_options' subtitle(`subtitle')"'
    }

    * Add scheme if specified
    if "`scheme'" != "" {
        local graph_options "`graph_options' scheme(`scheme')"
    }

    * Add name if specified
    if "`name'" != "" {
        local graph_options "`graph_options' name(`name', replace)"
    }

    * Add nodraw if specified
    if "`draw'" == "nodraw" {
        local graph_options "`graph_options' nodraw"
    }

    * =========================================================================
    * EXECUTE GRAPH COMMAND
    * =========================================================================

    * Build and execute the complete command
    local full_cmd `"`graph_cmd', `text_content' `graph_options'"'
    `full_cmd'

    * Save if requested
    if `"`saving'"' != "" {
        if "`replace'" != "" {
            graph export `saving', replace
        }
        else {
            graph export `saving'
        }
    }

    restore

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar nboxes = `nboxes'
    forvalues i = 1/`nboxes' {
        return scalar n`i' = `n`i''
        return local label`i' "`label`i''"
    }
    forvalues i = 1/9 {
        if `exc`i'' > 0 {
            return scalar exc`i' = `exc`i''
        }
    }

    * Display summary
    display as text ""
    display as text "Cohort flow diagram generated successfully"
    display as text "  Boxes: `nboxes'"
    forvalues i = 1/`nboxes' {
        display as text "    Box `i': `label`i'' (n=`n`i'')"
        if `i' < `nboxes' {
            local exc_idx = `i'
            if `exc`exc_idx'' > 0 {
                display as text "      -> Excluded: `exc`exc_idx''"
            }
        }
    }
    if `"`saving'"' != "" {
        display as text "  Graph saved to: `saving'"
    }

end

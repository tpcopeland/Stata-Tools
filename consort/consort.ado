*! consort Version 1.0.0  03dec2025
*! Author: Timothy P Copeland
*! CONSORT flow diagram generator for clinical trials

program define consort, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax , ///
        /// Enrollment stage
        ASSessed(integer)               /// Total assessed for eligibility
        EXCluded(integer)               /// Total excluded
        RANdomized(integer)             /// Total randomized
        [EXCReasons(string asis)]       /// Exclusion reasons (multiline with ;;)
        ///
        /// Arm 1 - Allocation
        ARM1_label(string)              /// Label for arm 1
        ARM1_allocated(integer)         /// Allocated to arm 1
        [ARM1_received(integer -1)]     /// Received intervention (-1 = not shown)
        [ARM1_notrec(integer 0)]        /// Did not receive
        [ARM1_notrec_reasons(string asis)] /// Reasons for not receiving
        ///
        /// Arm 1 - Follow-up
        [ARM1_lost(integer 0)]          /// Lost to follow-up
        [ARM1_lost_reasons(string asis)] /// Reasons for loss
        [ARM1_discontinued(integer 0)]  /// Discontinued intervention
        [ARM1_disc_reasons(string asis)] /// Reasons for discontinuation
        ///
        /// Arm 1 - Analysis
        ARM1_analyzed(integer)          /// Analyzed
        [ARM1_analysis_excluded(integer 0)] /// Excluded from analysis
        [ARM1_analysis_exc_reasons(string asis)] /// Reasons for exclusion
        ///
        /// Arm 2 - Allocation
        ARM2_label(string)              /// Label for arm 2
        ARM2_allocated(integer)         /// Allocated to arm 2
        [ARM2_received(integer -1)]     /// Received intervention (-1 = not shown)
        [ARM2_notrec(integer 0)]        /// Did not receive
        [ARM2_notrec_reasons(string asis)] /// Reasons for not receiving
        ///
        /// Arm 2 - Follow-up
        [ARM2_lost(integer 0)]          /// Lost to follow-up
        [ARM2_lost_reasons(string asis)] /// Reasons for loss
        [ARM2_discontinued(integer 0)]  /// Discontinued intervention
        [ARM2_disc_reasons(string asis)] /// Reasons for discontinuation
        ///
        /// Arm 2 - Analysis
        ARM2_analyzed(integer)          /// Analyzed
        [ARM2_analysis_excluded(integer 0)] /// Excluded from analysis
        [ARM2_analysis_exc_reasons(string asis)] /// Reasons for exclusion
        ///
        /// Optional Arm 3
        [ARM3_label(string)]            /// Label for arm 3
        [ARM3_allocated(integer -1)]    /// Allocated to arm 3
        [ARM3_received(integer -1)]     /// Received intervention
        [ARM3_notrec(integer 0)]        /// Did not receive
        [ARM3_notrec_reasons(string asis)] ///
        [ARM3_lost(integer 0)]          ///
        [ARM3_lost_reasons(string asis)] ///
        [ARM3_discontinued(integer 0)]  ///
        [ARM3_disc_reasons(string asis)] ///
        [ARM3_analyzed(integer -1)]     ///
        [ARM3_analysis_excluded(integer 0)] ///
        [ARM3_analysis_exc_reasons(string asis)] ///
        ///
        /// Optional Arm 4
        [ARM4_label(string)]            /// Label for arm 4
        [ARM4_allocated(integer -1)]    /// Allocated to arm 4
        [ARM4_received(integer -1)]     /// Received intervention
        [ARM4_notrec(integer 0)]        /// Did not receive
        [ARM4_notrec_reasons(string asis)] ///
        [ARM4_lost(integer 0)]          ///
        [ARM4_lost_reasons(string asis)] ///
        [ARM4_discontinued(integer 0)]  ///
        [ARM4_disc_reasons(string asis)] ///
        [ARM4_analyzed(integer -1)]     ///
        [ARM4_analysis_excluded(integer 0)] ///
        [ARM4_analysis_exc_reasons(string asis)] ///
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
        [ARRowColor(string)]            /// Arrow color (default: black)
        [TEXTSize(string)]              /// Text size (default: vsmall)
        [LABelSize(string)]             /// Stage label size (default: small)
        [WIDth(real 7)]                 /// Graph width in inches
        [HEight(real 10)]               /// Graph height in inches
        ]

    * =========================================================================
    * VALIDATION
    * =========================================================================

    * Validate enrollment numbers
    if `assessed' < 0 {
        display as error "assessed() must be non-negative"
        exit 198
    }
    if `excluded' < 0 {
        display as error "excluded() must be non-negative"
        exit 198
    }
    if `randomized' < 0 {
        display as error "randomized() must be non-negative"
        exit 198
    }
    if `assessed' < `excluded' + `randomized' {
        display as error "assessed() must be >= excluded() + randomized()"
        exit 198
    }

    * Validate arm 1 numbers
    if `arm1_allocated' < 0 {
        display as error "arm1_allocated() must be non-negative"
        exit 198
    }
    if `arm1_analyzed' < 0 {
        display as error "arm1_analyzed() must be non-negative"
        exit 198
    }

    * Validate arm 2 numbers
    if `arm2_allocated' < 0 {
        display as error "arm2_allocated() must be non-negative"
        exit 198
    }
    if `arm2_analyzed' < 0 {
        display as error "arm2_analyzed() must be non-negative"
        exit 198
    }

    * Count number of arms
    local narms = 2
    if `arm3_allocated' >= 0 & "`arm3_label'" != "" {
        if `arm3_analyzed' < 0 {
            display as error "arm3_analyzed() required when arm3 is specified"
            exit 198
        }
        local narms = 3
    }
    if `arm4_allocated' >= 0 & "`arm4_label'" != "" {
        if `arm4_analyzed' < 0 {
            display as error "arm4_analyzed() required when arm4 is specified"
            exit 198
        }
        if `narms' != 3 {
            display as error "arm3 must be specified before arm4"
            exit 198
        }
        local narms = 4
    }

    * Set defaults
    if "`boxcolor'" == "" local boxcolor "white"
    if "`boxborder'" == "" local boxborder "black"
    if "`arrowcolor'" == "" local arrowcolor "black"
    if "`textsize'" == "" local textsize "vsmall"
    if "`labelsize'" == "" local labelsize "small"

    * =========================================================================
    * COORDINATE SYSTEM SETUP
    * =========================================================================
    * Y-axis: 0 (bottom) to 100 (top)
    * X-axis: 0 (left) to 100 (right)
    *
    * Layout (top to bottom):
    *   y=95: Title area
    *   y=88: Enrollment - Assessed box
    *   y=78: Enrollment - Excluded box (side) + Randomized box (center)
    *   y=68: Allocation - Arm boxes
    *   y=58: Allocation - Received boxes (if shown)
    *   y=45: Follow-up - Lost/Discontinued boxes
    *   y=25: Analysis - Analyzed boxes

    * Calculate x positions based on number of arms
    if `narms' == 2 {
        local x1 = 25    // Arm 1 center
        local x2 = 75    // Arm 2 center
        local xcenter = 50
    }
    else if `narms' == 3 {
        local x1 = 17    // Arm 1 center
        local x2 = 50    // Arm 2 center
        local x3 = 83    // Arm 3 center
        local xcenter = 50
    }
    else if `narms' == 4 {
        local x1 = 12.5  // Arm 1 center
        local x2 = 37.5  // Arm 2 center
        local x3 = 62.5  // Arm 3 center
        local x4 = 87.5  // Arm 4 center
        local xcenter = 50
    }

    * Y positions for stages
    local y_assessed = 92
    local y_excluded = 83
    local y_randomized = 75
    local y_allocation = 62
    local y_received = 52
    local y_followup = 38
    local y_analysis = 18

    * X position for excluded box (side)
    local x_excluded = 85

    * =========================================================================
    * BUILD TEXT CONTENT FOR BOXES
    * =========================================================================

    * Enrollment boxes
    local txt_assessed "Assessed for eligibility" "(n=`assessed')"
    local txt_excluded "Excluded (n=`excluded')"

    * Add exclusion reasons if provided
    if `"`excreasons'"' != "" {
        * Parse reasons separated by ;;
        local excreasons_clean = subinstr(`"`excreasons'"', ";;", char(10), .)
        local txt_excluded "`txt_excluded'" "`excreasons_clean'"
    }

    local txt_randomized "Randomized" "(n=`randomized')"

    * Arm 1 boxes
    local txt_arm1_alloc "Allocated to `arm1_label'" "(n=`arm1_allocated')"
    if `arm1_received' >= 0 {
        local txt_arm1_recv "Received intervention" "(n=`arm1_received')"
        if `arm1_notrec' > 0 {
            local txt_arm1_recv "`txt_arm1_recv'" "Did not receive (n=`arm1_notrec')"
            if `"`arm1_notrec_reasons'"' != "" {
                local arm1_notrec_clean = subinstr(`"`arm1_notrec_reasons'"', ";;", char(10), .)
                local txt_arm1_recv "`txt_arm1_recv'" "`arm1_notrec_clean'"
            }
        }
    }

    * Arm 1 follow-up
    local txt_arm1_fu ""
    if `arm1_lost' > 0 | `arm1_discontinued' > 0 {
        if `arm1_lost' > 0 {
            local txt_arm1_fu "Lost to follow-up (n=`arm1_lost')"
            if `"`arm1_lost_reasons'"' != "" {
                local arm1_lost_clean = subinstr(`"`arm1_lost_reasons'"', ";;", char(10), .)
                local txt_arm1_fu "`txt_arm1_fu'" "`arm1_lost_clean'"
            }
        }
        if `arm1_discontinued' > 0 {
            if "`txt_arm1_fu'" != "" local txt_arm1_fu "`txt_arm1_fu'" " "
            local txt_arm1_fu "`txt_arm1_fu'" "Discontinued (n=`arm1_discontinued')"
            if `"`arm1_disc_reasons'"' != "" {
                local arm1_disc_clean = subinstr(`"`arm1_disc_reasons'"', ";;", char(10), .)
                local txt_arm1_fu "`txt_arm1_fu'" "`arm1_disc_clean'"
            }
        }
    }

    * Arm 1 analysis
    local txt_arm1_ana "Analysed (n=`arm1_analyzed')"
    if `arm1_analysis_excluded' > 0 {
        local txt_arm1_ana "`txt_arm1_ana'" "Excluded from analysis" "(n=`arm1_analysis_excluded')"
        if `"`arm1_analysis_exc_reasons'"' != "" {
            local arm1_exc_clean = subinstr(`"`arm1_analysis_exc_reasons'"', ";;", char(10), .)
            local txt_arm1_ana "`txt_arm1_ana'" "`arm1_exc_clean'"
        }
    }

    * Arm 2 boxes (similar structure)
    local txt_arm2_alloc "Allocated to `arm2_label'" "(n=`arm2_allocated')"
    if `arm2_received' >= 0 {
        local txt_arm2_recv "Received intervention" "(n=`arm2_received')"
        if `arm2_notrec' > 0 {
            local txt_arm2_recv "`txt_arm2_recv'" "Did not receive (n=`arm2_notrec')"
            if `"`arm2_notrec_reasons'"' != "" {
                local arm2_notrec_clean = subinstr(`"`arm2_notrec_reasons'"', ";;", char(10), .)
                local txt_arm2_recv "`txt_arm2_recv'" "`arm2_notrec_clean'"
            }
        }
    }

    local txt_arm2_fu ""
    if `arm2_lost' > 0 | `arm2_discontinued' > 0 {
        if `arm2_lost' > 0 {
            local txt_arm2_fu "Lost to follow-up (n=`arm2_lost')"
            if `"`arm2_lost_reasons'"' != "" {
                local arm2_lost_clean = subinstr(`"`arm2_lost_reasons'"', ";;", char(10), .)
                local txt_arm2_fu "`txt_arm2_fu'" "`arm2_lost_clean'"
            }
        }
        if `arm2_discontinued' > 0 {
            if "`txt_arm2_fu'" != "" local txt_arm2_fu "`txt_arm2_fu'" " "
            local txt_arm2_fu "`txt_arm2_fu'" "Discontinued (n=`arm2_discontinued')"
            if `"`arm2_disc_reasons'"' != "" {
                local arm2_disc_clean = subinstr(`"`arm2_disc_reasons'"', ";;", char(10), .)
                local txt_arm2_fu "`txt_arm2_fu'" "`arm2_disc_clean'"
            }
        }
    }

    local txt_arm2_ana "Analysed (n=`arm2_analyzed')"
    if `arm2_analysis_excluded' > 0 {
        local txt_arm2_ana "`txt_arm2_ana'" "Excluded from analysis" "(n=`arm2_analysis_excluded')"
        if `"`arm2_analysis_exc_reasons'"' != "" {
            local arm2_exc_clean = subinstr(`"`arm2_analysis_exc_reasons'"', ";;", char(10), .)
            local txt_arm2_ana "`txt_arm2_ana'" "`arm2_exc_clean'"
        }
    }

    * Arm 3 boxes (if applicable)
    if `narms' >= 3 {
        local txt_arm3_alloc "Allocated to `arm3_label'" "(n=`arm3_allocated')"
        if `arm3_received' >= 0 {
            local txt_arm3_recv "Received intervention" "(n=`arm3_received')"
            if `arm3_notrec' > 0 {
                local txt_arm3_recv "`txt_arm3_recv'" "Did not receive (n=`arm3_notrec')"
            }
        }

        local txt_arm3_fu ""
        if `arm3_lost' > 0 | `arm3_discontinued' > 0 {
            if `arm3_lost' > 0 {
                local txt_arm3_fu "Lost to follow-up (n=`arm3_lost')"
            }
            if `arm3_discontinued' > 0 {
                if "`txt_arm3_fu'" != "" local txt_arm3_fu "`txt_arm3_fu'" " "
                local txt_arm3_fu "`txt_arm3_fu'" "Discontinued (n=`arm3_discontinued')"
            }
        }

        local txt_arm3_ana "Analysed (n=`arm3_analyzed')"
        if `arm3_analysis_excluded' > 0 {
            local txt_arm3_ana "`txt_arm3_ana'" "Excluded (n=`arm3_analysis_excluded')"
        }
    }

    * Arm 4 boxes (if applicable)
    if `narms' >= 4 {
        local txt_arm4_alloc "Allocated to `arm4_label'" "(n=`arm4_allocated')"
        if `arm4_received' >= 0 {
            local txt_arm4_recv "Received intervention" "(n=`arm4_received')"
            if `arm4_notrec' > 0 {
                local txt_arm4_recv "`txt_arm4_recv'" "Did not receive (n=`arm4_notrec')"
            }
        }

        local txt_arm4_fu ""
        if `arm4_lost' > 0 | `arm4_discontinued' > 0 {
            if `arm4_lost' > 0 {
                local txt_arm4_fu "Lost to follow-up (n=`arm4_lost')"
            }
            if `arm4_discontinued' > 0 {
                if "`txt_arm4_fu'" != "" local txt_arm4_fu "`txt_arm4_fu'" " "
                local txt_arm4_fu "`txt_arm4_fu'" "Discontinued (n=`arm4_discontinued')"
            }
        }

        local txt_arm4_ana "Analysed (n=`arm4_analyzed')"
        if `arm4_analysis_excluded' > 0 {
            local txt_arm4_ana "`txt_arm4_ana'" "Excluded (n=`arm4_analysis_excluded')"
        }
    }

    * =========================================================================
    * PRESERVE AND CREATE TEMPORARY DATA FOR GRAPH
    * =========================================================================

    preserve
    clear
    quietly set obs 1
    generate x = .
    generate y = .

    * =========================================================================
    * BUILD GRAPH COMMAND
    * =========================================================================

    * Start building the twoway command
    local graph_cmd "twoway"

    * Add invisible scatter for coordinate system
    local graph_cmd "`graph_cmd' (scatteri 0 0 100 100, msymbol(none))"

    * ----- ARROWS -----
    * Arrow options
    local arrow_opts "lcolor(`arrowcolor') mcolor(`arrowcolor') mlwidth(medthick)"
    local line_opts "lcolor(`arrowcolor') lwidth(medthick)"

    * Enrollment: Assessed -> Randomized (vertical arrow down)
    local graph_cmd "`graph_cmd' (pcarrowi `y_assessed' `xcenter' `=`y_randomized'+3' `xcenter', `arrow_opts')"

    * Enrollment: Assessed -> Excluded (horizontal line to right, then down)
    local graph_cmd "`graph_cmd' (pci `y_assessed' `xcenter' `y_assessed' `=`x_excluded'-5', `line_opts')"
    local graph_cmd "`graph_cmd' (pcarrowi `y_assessed' `=`x_excluded'-5' `=`y_excluded'+2' `=`x_excluded'-5', `arrow_opts')"

    * Randomized -> Allocation split
    * Vertical line down from randomized
    local graph_cmd "`graph_cmd' (pci `=`y_randomized'-3' `xcenter' `=`y_allocation'+10' `xcenter', `line_opts')"

    * Horizontal line across for allocation
    if `narms' == 2 {
        local graph_cmd "`graph_cmd' (pci `=`y_allocation'+10' `x1' `=`y_allocation'+10' `x2', `line_opts')"
    }
    else if `narms' == 3 {
        local graph_cmd "`graph_cmd' (pci `=`y_allocation'+10' `x1' `=`y_allocation'+10' `x3', `line_opts')"
    }
    else if `narms' == 4 {
        local graph_cmd "`graph_cmd' (pci `=`y_allocation'+10' `x1' `=`y_allocation'+10' `x4', `line_opts')"
    }

    * Vertical arrows down to each allocation box
    forvalues a = 1/`narms' {
        local graph_cmd "`graph_cmd' (pcarrowi `=`y_allocation'+10' `x`a'' `=`y_allocation'+3' `x`a'', `arrow_opts')"
    }

    * Allocation -> Follow-up arrows
    forvalues a = 1/`narms' {
        local graph_cmd "`graph_cmd' (pcarrowi `=`y_allocation'-5' `x`a'' `=`y_followup'+5' `x`a'', `arrow_opts')"
    }

    * Follow-up -> Analysis arrows
    forvalues a = 1/`narms' {
        local graph_cmd "`graph_cmd' (pcarrowi `=`y_followup'-5' `x`a'' `=`y_analysis'+5' `x`a'', `arrow_opts')"
    }

    * ----- TEXT BOXES -----
    * Text box options
    local box_opts "size(`textsize') placement(c) box fcolor(`boxcolor') lcolor(`boxborder') margin(small) justification(center)"
    local sidebox_opts "size(`textsize') placement(c) box fcolor(`boxcolor') lcolor(`boxborder') margin(small) justification(left)"

    * Stage label options (left side)
    local stage_opts "size(`labelsize') placement(e) color(black)"

    * Add text boxes
    local text_content ""

    * Enrollment - Assessed
    local text_content `"`text_content' text(`y_assessed' `xcenter' `txt_assessed', `box_opts')"'

    * Enrollment - Excluded
    local text_content `"`text_content' text(`y_excluded' `x_excluded' `txt_excluded', `sidebox_opts')"'

    * Enrollment - Randomized
    local text_content `"`text_content' text(`y_randomized' `xcenter' `txt_randomized', `box_opts')"'

    * Allocation boxes for each arm
    local text_content `"`text_content' text(`y_allocation' `x1' `txt_arm1_alloc', `box_opts')"'
    local text_content `"`text_content' text(`y_allocation' `x2' `txt_arm2_alloc', `box_opts')"'
    if `narms' >= 3 {
        local text_content `"`text_content' text(`y_allocation' `x3' `txt_arm3_alloc', `box_opts')"'
    }
    if `narms' >= 4 {
        local text_content `"`text_content' text(`y_allocation' `x4' `txt_arm4_alloc', `box_opts')"'
    }

    * Follow-up boxes for each arm
    if "`txt_arm1_fu'" != "" {
        local text_content `"`text_content' text(`y_followup' `x1' `txt_arm1_fu', `sidebox_opts')"'
    }
    else {
        local text_content `"`text_content' text(`y_followup' `x1' "No losses", `box_opts')"'
    }
    if "`txt_arm2_fu'" != "" {
        local text_content `"`text_content' text(`y_followup' `x2' `txt_arm2_fu', `sidebox_opts')"'
    }
    else {
        local text_content `"`text_content' text(`y_followup' `x2' "No losses", `box_opts')"'
    }
    if `narms' >= 3 {
        if "`txt_arm3_fu'" != "" {
            local text_content `"`text_content' text(`y_followup' `x3' `txt_arm3_fu', `sidebox_opts')"'
        }
        else {
            local text_content `"`text_content' text(`y_followup' `x3' "No losses", `box_opts')"'
        }
    }
    if `narms' >= 4 {
        if "`txt_arm4_fu'" != "" {
            local text_content `"`text_content' text(`y_followup' `x4' `txt_arm4_fu', `sidebox_opts')"'
        }
        else {
            local text_content `"`text_content' text(`y_followup' `x4' "No losses", `box_opts')"'
        }
    }

    * Analysis boxes for each arm
    local text_content `"`text_content' text(`y_analysis' `x1' `txt_arm1_ana', `box_opts')"'
    local text_content `"`text_content' text(`y_analysis' `x2' `txt_arm2_ana', `box_opts')"'
    if `narms' >= 3 {
        local text_content `"`text_content' text(`y_analysis' `x3' `txt_arm3_ana', `box_opts')"'
    }
    if `narms' >= 4 {
        local text_content `"`text_content' text(`y_analysis' `x4' `txt_arm4_ana', `box_opts')"'
    }

    * Stage labels (left margin)
    local text_content `"`text_content' text(`y_assessed' 3 "Enrollment", `stage_opts')"'
    local text_content `"`text_content' text(`y_allocation' 3 "Allocation", `stage_opts')"'
    local text_content `"`text_content' text(`y_followup' 3 "Follow-up", `stage_opts')"'
    local text_content `"`text_content' text(`y_analysis' 3 "Analysis", `stage_opts')"'

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

    return scalar assessed = `assessed'
    return scalar excluded = `excluded'
    return scalar randomized = `randomized'
    return scalar narms = `narms'
    return scalar arm1_allocated = `arm1_allocated'
    return scalar arm1_analyzed = `arm1_analyzed'
    return scalar arm2_allocated = `arm2_allocated'
    return scalar arm2_analyzed = `arm2_analyzed'
    if `narms' >= 3 {
        return scalar arm3_allocated = `arm3_allocated'
        return scalar arm3_analyzed = `arm3_analyzed'
    }
    if `narms' >= 4 {
        return scalar arm4_allocated = `arm4_allocated'
        return scalar arm4_analyzed = `arm4_analyzed'
    }

    return local arm1_label "`arm1_label'"
    return local arm2_label "`arm2_label'"
    if `narms' >= 3 {
        return local arm3_label "`arm3_label'"
    }
    if `narms' >= 4 {
        return local arm4_label "`arm4_label'"
    }

    display as text ""
    display as text "CONSORT flow diagram generated successfully"
    display as text "  Enrollment: `assessed' assessed, `excluded' excluded, `randomized' randomized"
    display as text "  Arms: `narms'"
    forvalues a = 1/`narms' {
        display as text "    Arm `a' (`arm`a'_label'): `arm`a'_allocated' allocated, `arm`a'_analyzed' analyzed"
    }
    if `"`saving'"' != "" {
        display as text "  Graph saved to: `saving'"
    }

end

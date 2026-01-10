*! tc_schemes Version 1.0.0  2025/01/11
*! Consolidated Stata graph schemes from blindschemes and schemepack
*! Author: Timothy P Copeland (consolidation)
*! Original Authors: Daniel Bischof (blindschemes), Asjad Naqvi (schemepack), Mead Over (blindschemes_fix)
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tc_schemes [, source(string) list detail]

Optional options:
  source(string)  - Filter by source: blindschemes, schemepack, or all (default: all)
  list            - Display schemes as a simple list
  detail          - Show detailed information including descriptions

Returns:
  r(schemes)      - List of all scheme names
  r(n_schemes)    - Number of schemes
  r(sources)      - List of source packages

See help tc_schemes for complete documentation and scheme previews
*/

program define tc_schemes, rclass
    version 16.0
    set varabbrev off

    syntax [, Source(string) List Detail]

    // Default source is all
    if "`source'" == "" local source "all"

    // Validate source option
    local source = lower("`source'")
    if !inlist("`source'", "all", "blindschemes", "schemepack") {
        display as error "source() must be: all, blindschemes, or schemepack"
        exit 198
    }

    // Define blindschemes schemes (with fixes from blindschemes_fix)
    local blindschemes_list "plotplain plotplainblind plottig plottigblind"

    // Define schemepack schemes - organized by series
    local schemepack_tableau "white_tableau black_tableau gg_tableau"
    local schemepack_cividis "white_cividis black_cividis gg_cividis"
    local schemepack_viridis "white_viridis black_viridis gg_viridis"
    local schemepack_hue "white_hue black_hue gg_hue"
    local schemepack_brbg "white_brbg black_brbg gg_brbg"
    local schemepack_piyg "white_piyg black_piyg gg_piyg"
    local schemepack_ptol "white_ptol black_ptol gg_ptol"
    local schemepack_jet "white_jet black_jet gg_jet"
    local schemepack_w3d "white_w3d black_w3d gg_w3d"
    local schemepack_standalone "tab1 tab2 tab3 cblind1 ukraine swift_red neon rainbow"

    local schemepack_list "`schemepack_tableau' `schemepack_cividis' `schemepack_viridis' `schemepack_hue' `schemepack_brbg' `schemepack_piyg' `schemepack_ptol' `schemepack_jet' `schemepack_w3d' `schemepack_standalone'"

    // Build selected list based on source
    if "`source'" == "blindschemes" {
        local selected_schemes "`blindschemes_list'"
    }
    else if "`source'" == "schemepack" {
        local selected_schemes "`schemepack_list'"
    }
    else {
        local selected_schemes "`blindschemes_list' `schemepack_list'"
    }

    // Count schemes
    local n_schemes: word count `selected_schemes'

    // Display header
    display as text ""
    display as text "{hline 70}"
    display as result "tc_schemes" as text " - Consolidated Stata Graph Schemes"
    display as text "{hline 70}"
    display as text ""

    // Display based on options
    if "`detail'" != "" {
        // Detailed view with descriptions
        _tc_schemes_detail, source(`source')
    }
    else if "`list'" != "" {
        // Simple list view
        display as text "Available schemes (`source'):"
        display as text ""
        foreach scheme of local selected_schemes {
            display as result "  `scheme'"
        }
    }
    else {
        // Default: organized view
        if inlist("`source'", "all", "blindschemes") {
            display as text "{bf:BLINDSCHEMES}" as text " (Daniel Bischof, with fixes by Mead Over)"
            display as text "  Colorblind-friendly schemes with clean aesthetics"
            display as result "    plotplain plotplainblind plottig plottigblind"
            display as text ""
        }

        if inlist("`source'", "all", "schemepack") {
            display as text "{bf:SCHEMEPACK}" as text " (Asjad Naqvi)"
            display as text "  Series schemes (white_*, black_*, gg_* backgrounds):"
            display as result "    tableau, cividis, viridis, hue, brbg, piyg, ptol, jet, w3d"
            display as text "  Standalone schemes:"
            display as result "    tab1 tab2 tab3 cblind1 ukraine swift_red neon rainbow"
            display as text ""
        }

        display as text "{hline 70}"
        display as text "Total schemes: " as result "`n_schemes'"
        display as text ""
        display as text "Usage: " as result "set scheme <scheme_name>" as text " or " as result "graph ..., scheme(<scheme_name>)"
        display as text "Help:  " as result "help tc_schemes" as text " for scheme previews and details"
    }

    // Return results
    return local schemes "`selected_schemes'"
    return scalar n_schemes = `n_schemes'
    return local sources "blindschemes schemepack"
    return local version "1.0.0"
end

// Subroutine for detailed display
program define _tc_schemes_detail
    syntax , Source(string)

    if inlist("`source'", "all", "blindschemes") {
        display as text "{bf:BLINDSCHEMES} - Daniel Bischof (University of Zurich)"
        display as text "  With fixes from Mead Over (Center for Global Development)"
        display as text "  {hline 60}"
        display as text ""
        display as result "  plotplain" as text "      - Clean, minimal scheme for publications"
        display as result "  plotplainblind" as text " - plotplain with colorblind-friendly palette"
        display as result "  plottig" as text "        - ggplot2-inspired scheme with gray background"
        display as result "  plottigblind" as text "   - plottig with colorblind-friendly palette"
        display as text ""
        display as text "  Custom colors: vermillion, sky, turquoise, reddish, sea,"
        display as text "                 orangebrown, ananas, plus 14 additional tones"
        display as text ""
    }

    if inlist("`source'", "all", "schemepack") {
        display as text "{bf:SCHEMEPACK} - Asjad Naqvi (Vienna University of Economics)"
        display as text "  {hline 60}"
        display as text ""
        display as text "  {it:Series Schemes} (prefix: white_/black_/gg_ for background)"
        display as result "    tableau"  as text "  - Tableau-inspired color palette"
        display as result "    cividis"  as text "  - Perceptually uniform, colorblind-safe"
        display as result "    viridis"  as text "  - Perceptually uniform (matplotlib)"
        display as result "    hue"      as text "  - ggplot2 default hue colors"
        display as result "    brbg"     as text "  - Brown-blue-green diverging"
        display as result "    piyg"     as text "  - Pink-yellow-green diverging"
        display as result "    ptol"     as text "  - Paul Tol's colorblind-safe palette"
        display as result "    jet"      as text "  - Classic jet rainbow (use cautiously)"
        display as result "    w3d"      as text "  - Web 3D inspired colors"
        display as text ""
        display as text "  {it:Standalone Schemes}"
        display as result "    tab1/tab2/tab3" as text " - Qualitative color schemes"
        display as result "    cblind1"   as text "        - Colorblind-friendly option"
        display as result "    ukraine"   as text "        - Ukraine flag colors"
        display as result "    swift_red" as text "       - Taylor Swift Red album"
        display as result "    neon"      as text "          - High-contrast neon styling"
        display as result "    rainbow"   as text "       - Vibrant multicolor"
        display as text ""
    }
end

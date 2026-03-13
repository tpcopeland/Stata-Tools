*! nma_map Version 1.0.5  2026/03/13
*! Network geometry visualization for network meta-analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  nma_map [, nodesize(studies|patients) edgesize(studies|precision)
      labels scheme(string) saving(filename) replace]

Description:
  Draws a network geometry plot showing treatments as nodes and direct
  comparisons as edges. Node sizes reflect the number of studies or
  patients, edge widths reflect the number of studies.

See help nma_map for complete documentation
*/

program define nma_map, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    set varabbrev off

    syntax [, NODESize(string) EDGESize(string) ///
        noLABels SCHeme(string) SAVing(string) REPLACE ///
        TItle(string)]

    * =======================================================================
    * CHECK PREREQUISITES
    * =======================================================================

    _nma_check_setup
    _nma_get_settings

    local treatments  "`_nma_treatments'"
    local n_treatments = `_nma_n_treatments'
    local k = `n_treatments'

    if "`scheme'" == "" local scheme "white_tableau"
    if "`nodesize'" == "" local nodesize "studies"
    if "`edgesize'" == "" local edgesize "studies"
    if "`title'" == "" local title ""

    if "`nodesize'" != "studies" {
        display as error "nodesize() must be studies"
        exit 198
    }
    if "`edgesize'" != "studies" {
        display as error "edgesize() must be studies"
        exit 198
    }

    _nma_display_header, command("nma_map") ///
        description("Network geometry plot")

    * =======================================================================
    * COMPUTE LAYOUT
    * =======================================================================

    * Get adjacency matrix (stored by nma_setup)
    capture confirm matrix _nma_adj
    if _rc != 0 {
        display as error "adjacency matrix not found; run nma_setup first"
        exit 198
    }

    _nma_circular_layout, k(`k')
    _nma_node_sizes, k(`k') adj_matrix("_nma_adj") sizeby("`nodesize'")
    _nma_edge_weights, k(`k') adj_matrix("_nma_adj") weightby("`edgesize'")

    * =======================================================================
    * BUILD PLOT DATA
    * =======================================================================

    * Save labels before preserve (clear wipes _dta chars)
    forvalues _t = 1/`k' {
        local _trtlbl_`_t' : char _dta[_nma_trt_`_t']
    }

    preserve

    * Create edge dataset: one row per edge
    local n_edges = 0
    forvalues i = 1/`k' {
        forvalues j = `=`i'+1'/`k' {
            if _nma_adj[`i', `j'] > 0 local ++n_edges
        }
    }

    local total_rows = `k' + `n_edges'
    quietly {
        clear
        set obs `total_rows'
        gen double _node_x = .
        gen double _node_y = .
        gen double _edge_x1 = .
        gen double _edge_y1 = .
        gen double _edge_x2 = .
        gen double _edge_y2 = .
        gen double _node_size = .
        gen double _edge_width = .
        gen str80 _node_label = ""
        gen byte _is_node = 0
    }

    * Fill node positions
    forvalues i = 1/`k' {
        quietly replace _node_x = _nma_node_x[`i', 1] in `i'
        quietly replace _node_y = _nma_node_y[`i', 1] in `i'
        quietly replace _node_size = _nma_node_sizes[`i', 1] in `i'
        local lbl "`_trtlbl_`i''"
        quietly replace _node_label = "`lbl'" in `i'
        quietly replace _is_node = 1 in `i'
    }

    * Fill edge data
    local row = `k'
    forvalues i = 1/`k' {
        forvalues j = `=`i'+1'/`k' {
            if _nma_adj[`i', `j'] > 0 {
                local ++row
                quietly replace _edge_x1 = _nma_node_x[`i', 1] in `row'
                quietly replace _edge_y1 = _nma_node_y[`i', 1] in `row'
                quietly replace _edge_x2 = _nma_node_x[`j', 1] in `row'
                quietly replace _edge_y2 = _nma_node_y[`j', 1] in `row'
                quietly replace _edge_width = _nma_edge_weights[`i', `j'] in `row'
            }
        }
    }

    * =======================================================================
    * DRAW NETWORK
    * =======================================================================

    * Build edge plot commands
    local edge_plots ""
    local row = `k'
    forvalues i = 1/`k' {
        forvalues j = `=`i'+1'/`k' {
            if _nma_adj[`i', `j'] > 0 {
                local ++row
                local w = _nma_edge_weights[`i', `j']
                local ww : display %4.1f `w'
                local edge_plots "`edge_plots' (pcspike _edge_y1 _edge_x1 _edge_y2 _edge_x2 in `row', lwidth(`ww') lcolor(gs11%40))"
            }
        }
    }

    * Build node plot commands (scatter with varying marker size)
    local node_plots ""
    forvalues i = 1/`k' {
        local sz = _nma_node_sizes[`i', 1]
        local msz : display %4.1f `sz'
        local node_plots "`node_plots' (scatter _node_y _node_x in `i', msymbol(O) msize(`msz') mcolor(navy%80))"
    }

    * Build label plot if requested
    local label_plot ""
    if "`labels'" != "nolabels" {
        forvalues i = 1/`k' {
            local lbl "`_trtlbl_`i''"
            local nx = _nma_node_x[`i', 1]
            local ny = _nma_node_y[`i', 1]
            local sz = _nma_node_sizes[`i', 1]

            * Map angle to clock position (1-12) for fine-grained placement
            local angle = atan2(`ny', `nx') * 180 / _pi
            if `angle' < 0 local angle = `angle' + 360
            local clock = 3 - round(`angle' / 30)
            if `clock' <= 0 local clock = `clock' + 12
            local labpos = `clock'

            * Gap proportional to node size to clear marker
            local gap_pct : display %4.1f (1.2 + 0.5 * `sz')

            local label_plot "`label_plot' (scatter _node_y _node_x in `i', msymbol(none) mlabel(_node_label) mlabsize(small) mlabposition(`labpos') mlabgap(`gap_pct') mlabcolor(black))"
        }
    }

    * Construct saving() option for twoway
    local save_opt ""
    if "`saving'" != "" {
        local save_opt `"saving("`saving'", `replace')"'
    }

    * Combine
    twoway `edge_plots' `node_plots' `label_plot', ///
        legend(off) ///
        xscale(range(-1.4 1.4) off) yscale(range(-1.4 1.4) off) ///
        aspectratio(1) ///
        xtitle("") ytitle("") ///
        xlabel(none) ylabel(none) ///
        plotregion(margin(zero)) ///
        title("`title'") ///
        scheme(`scheme') ///
        `save_opt'

    restore

    display as text "Network map created: `k' treatments, `n_edges' direct comparisons"

    return scalar n_treatments = `k'
    return scalar n_edges = `n_edges'

    set varabbrev `_varabbrev'
end

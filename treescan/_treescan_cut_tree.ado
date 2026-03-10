*! _treescan_cut_tree Version 1.4.0  2026/03/01
*! Shared tree-cutting subroutine for treescan package
*! Maps leaf diagnosis codes to all ancestor nodes in the tree hierarchy
*! Author: Tim Copeland, Karolinska Institutet

program define _treescan_cut_tree, nclass
    version 16.0
    set varabbrev off
    set more off
    syntax , INPUTdata(string) TREEfile(string) DIAGvar(string) ///
        ID(string) EXPosed(string) MODel(string) ///
        INDividuals(string) [PERSONTime(string)]

    quietly {
        * =================================================================
        * LOAD TREE AND BUILD LOOKUP
        * =================================================================
        use `"`treefile'"', clear

        capture confirm variable node parent level
        if _rc {
            noisily display as error ///
                "tree file must contain variables: node, parent, level"
            exit 198
        }
        capture confirm string variable node parent
        if _rc {
            noisily display as error ///
                "tree file variables node and parent must be string"
            exit 198
        }
        capture confirm numeric variable level
        if _rc {
            noisily display as error ///
                "tree file variable level must be numeric"
            exit 198
        }

        * Store tree
        tempfile tree parentlookup validnodes
        save `tree'

        * Create node->parent lookup (for walking up the tree)
        * Apply same cleaning as user data (uppercase, strip dots)
        keep node parent
        drop if parent == "" | missing(parent)
        replace node = upper(trim(node))
        replace node = subinstr(node, ".", "", .)
        replace parent = upper(trim(parent))
        replace parent = subinstr(parent, ".", "", .)
        rename node _child
        rename parent _parent
        duplicates drop
        save `parentlookup'

        * Create list of all valid tree nodes (for matching leaf codes)
        * Apply same cleaning as user data (uppercase, strip dots)
        use `tree', clear
        keep node
        rename node `diagvar'
        replace `diagvar' = upper(trim(`diagvar'))
        replace `diagvar' = subinstr(`diagvar', ".", "", .)
        duplicates drop
        save `validnodes'

        * =================================================================
        * MATCH LEAF CODES AND EXPAND TO ANCESTORS
        * =================================================================
        use `"`inputdata'"', clear

        * Uppercase codes for matching
        replace `diagvar' = upper(trim(`diagvar'))
        * Strip dots (ICD codes may have dots)
        replace `diagvar' = subinstr(`diagvar', ".", "", .)

        * Match leaf codes to tree nodes
        local _pre_merge = _N
        merge m:1 `diagvar' using `validnodes', keep(match) nogenerate

        count
        if r(N) == 0 {
            noisily display as error "no diagnosis codes matched tree nodes"
            exit 2000
        }
        local _n_matched = r(N)
        local _n_dropped = `_pre_merge' - `_n_matched'
        if `_n_dropped' > 0 {
            noisily display as text ///
                "Note: `_n_dropped' observations had codes not found in tree"
        }

        * Pass matched count back to caller
        c_local _treescan_n_matched `_n_matched'

        * Rename to generic "node" for the expansion
        * Note: callers validate that id/exposed/persontime != "node"
        rename `diagvar' node

        if "`model'" == "poisson" {
            keep `id' node `exposed' `persontime'
        }
        else {
            keep `id' node `exposed'
        }

        * Save current level and iteratively add parent nodes
        tempfile expanded parentrows
        save `expanded'

        local done = 0
        local iter = 0
        while !`done' {
            local ++iter

            * Look up parent for each current node
            rename node _child
            merge m:1 _child using `parentlookup', keep(match) nogenerate
            rename _child node

            * If we got parents, add them
            count
            if r(N) == 0 {
                local done = 1
            }
            else {
                * Create parent-level rows
                if "`model'" == "poisson" {
                    keep `id' _parent `exposed' `persontime'
                }
                else {
                    keep `id' _parent `exposed'
                }
                rename _parent node

                save `parentrows', replace

                * Append to expanded data
                use `expanded', clear
                append using `parentrows'
                save `expanded', replace

                * Continue walking up from the parent nodes
                use `parentrows', clear
            }

            if `iter' > 20 {
                noisily display as error ///
                    "tree depth exceeds 20 levels; check tree structure"
                exit 198
            }
        }

        * =================================================================
        * DEDUPLICATE AND MERGE INDIVIDUAL-LEVEL DATA
        * =================================================================
        use `expanded', clear
        duplicates drop `id' node, force

        * Use individual-level exposure (not observation-level)
        drop `exposed'
        if "`model'" == "poisson" {
            capture drop `persontime'
        }
        merge m:1 `id' using `"`individuals'"', keep(match) nogenerate
    }
end

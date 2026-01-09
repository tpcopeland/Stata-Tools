*! forestpy Version 1.0.0  2026/01/09
*! Stata wrapper for Python forestplot package - publication-ready forest plots
*! Author: Timothy Copeland (Karolinska Institutet)
*! Program class: rclass

/*
Syntax:
  forestpy varlist [if] [in], estimate(varname) varlabel(varname) [options]

Required:
  estimate(varname)   - Variable containing point estimates
  varlabel(varname)   - Variable containing row labels

Optional CI:
  ll(varname)         - Lower confidence limit variable
  hl(varname)         - Upper confidence limit variable

Grouping and sorting:
  groupvar(varname)   - Variable for grouping rows
  grouporder(string)  - Order of groups (space-separated)
  sort                - Sort by estimate value
  sortby(varname)     - Variable to sort by

Display options:
  logscale            - Use log scale for x-axis
  xlabel(string)      - X-axis label
  ylabel(string)      - Y-axis label
  decimal(integer)    - Decimal precision (default: 2)
  figsize(numlist)    - Figure size as width height
  color_alt_rows      - Shade alternate rows
  table               - Display as table format

Annotations:
  annote(varlist)     - Variables for left annotations
  annotehead(string)  - Headers for left annotations
  rightannote(varlist)- Variables for right annotations
  righthead(string)   - Headers for right annotations
  pval(varname)       - P-value variable
  nostarpval          - Don't star significant p-values

Output:
  saving(filename)    - Save plot to file
  replace             - Replace existing file

See help forestpy for complete documentation
*/

program define forestpy, rclass
    version 16.0
    set varabbrev off

    // Check Python availability
    capture python query
    if _rc {
        display as error "Python integration not available"
        display as error "forestpy requires Stata 16+ with Python integration"
        exit 198
    }

    // Parse syntax
    syntax [if] [in], ///
        ESTimate(varname numeric) ///
        VARLabel(varname string) ///
        [ ///
        /// Confidence interval variables
        LL(varname numeric) ///
        HL(varname numeric) ///
        /// Grouping and sorting
        GROUPVar(varname) ///
        GROUPOrder(string asis) ///
        SORT ///
        SORTBy(varname) ///
        /// Display options
        LOGscale ///
        XLAbel(string asis) ///
        YLAbel(string asis) ///
        DECimal(integer 2) ///
        FIGSize(numlist min=2 max=2) ///
        COLOR_alt_rows ///
        TABLE ///
        FLUSH ///
        CAPitalize(string) ///
        /// Annotations
        ANNote(varlist) ///
        ANNOTEHead(string asis) ///
        RIGHTAnnote(varlist) ///
        RIGHTHead(string asis) ///
        PVAL(varname numeric) ///
        NOSTARpval ///
        /// Plot customization
        XTicks(numlist) ///
        XLine(real 999) ///
        MARKer(string) ///
        MARKERSize(real 40) ///
        MARKERColor(string) ///
        LINEColor(string) ///
        LINEWidth(real 1.4) ///
        /// Output
        SAVing(string asis) ///
        REPLACE ///
        /// Multi-model options
        MODELCol(varname) ///
        MODELLabels(string asis) ///
        /// Advanced
        NOPreprocess ///
        DEBUG ///
        ]

    // Mark sample
    marksample touse
    markout `touse' `estimate' `varlabel', strok
    if "`ll'" != "" {
        markout `touse' `ll'
    }
    if "`hl'" != "" {
        markout `touse' `hl'
    }
    if "`groupvar'" != "" {
        markout `touse' `groupvar', strok
    }
    if "`pval'" != "" {
        markout `touse' `pval'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    // Validate CI variables (both or neither)
    if ("`ll'" != "" & "`hl'" == "") | ("`ll'" == "" & "`hl'" != "") {
        display as error "must specify both ll() and hl() or neither"
        exit 198
    }

    // Set defaults
    if "`figsize'" == "" {
        local figsize "4 8"
    }
    if `xline' == 999 {
        if "`logscale'" != "" {
            local xline = 1
        }
        else {
            local xline = 0
        }
    }
    if "`marker'" == "" {
        local marker "s"
    }
    if "`markercolor'" == "" {
        local markercolor "darkslategray"
    }
    if "`linecolor'" == "" {
        local linecolor ".6"
    }

    // Parse figsize
    tokenize `figsize'
    local fig_width `1'
    local fig_height `2'

    // Strip quotes from string options that may have been quoted
    foreach opt in xlabel ylabel grouporder annotehead righthead modellabels capitalize {
        if `"``opt''"' != "" {
            // Remove leading/trailing quotes
            local `opt' = subinstr(`"``opt''"', `"""', "", .)
        }
    }

    // Check for and install Python dependencies
    _forestpy_check_deps
    if r(failed) {
        exit 198
    }

    // Determine output file
    local save_plot 0
    local outfile ""
    if `"`saving'"' != "" {
        local save_plot 1
        // Parse saving() option
        _parse_saving `saving'
        local outfile "`s(filename)'"
        local savingopts "`s(options)'"

        // Check if file exists and replace not specified
        if "`replace'" == "" {
            capture confirm file "`outfile'"
            if _rc == 0 {
                display as error `"file `outfile' already exists"'
                display as error "use replace option to overwrite"
                exit 602
            }
        }
    }
    else {
        // Default to tempfile for display
        tempfile outfile
        local outfile "`outfile'.png"
        local save_plot 1
    }

    // Build variable lists for Python
    local varlist_to_python "`estimate' `varlabel'"
    if "`ll'" != "" {
        local varlist_to_python "`varlist_to_python' `ll' `hl'"
    }
    if "`groupvar'" != "" {
        local varlist_to_python "`varlist_to_python' `groupvar'"
    }
    if "`pval'" != "" {
        local varlist_to_python "`varlist_to_python' `pval'"
    }
    if "`annote'" != "" {
        local varlist_to_python "`varlist_to_python' `annote'"
    }
    if "`rightannote'" != "" {
        local varlist_to_python "`varlist_to_python' `rightannote'"
    }
    if "`sortby'" != "" {
        local varlist_to_python "`varlist_to_python' `sortby'"
    }
    if "`modelcol'" != "" {
        local varlist_to_python "`varlist_to_python' `modelcol'"
    }

    // Remove duplicates from varlist
    local varlist_clean ""
    foreach v of local varlist_to_python {
        local is_dup 0
        foreach existing of local varlist_clean {
            if "`v'" == "`existing'" {
                local is_dup 1
                continue, break
            }
        }
        if !`is_dup' {
            local varlist_clean "`varlist_clean' `v'"
        }
    }
    local varlist_to_python "`varlist_clean'"

    // Create Python code
    preserve
    quietly keep if `touse'
    quietly keep `varlist_to_python'

    // Debug output
    if "`debug'" != "" {
        display as text "Variables being passed to Python: `varlist_to_python'"
        display as text "N = `N'"
        display as text "Output file: `outfile'"
    }

    // Execute Python - use simple quotes for all string arguments
    python: _forestpy_execute( ///
        "`estimate'", ///
        "`varlabel'", ///
        "`ll'", ///
        "`hl'", ///
        "`groupvar'", ///
        "`grouporder'", ///
        "`sort'", ///
        "`sortby'", ///
        "`logscale'", ///
        "`xlabel'", ///
        "`ylabel'", ///
        `decimal', ///
        `fig_width', ///
        `fig_height', ///
        "`color_alt_rows'", ///
        "`table'", ///
        "`flush'", ///
        "`capitalize'", ///
        "`annote'", ///
        "`annotehead'", ///
        "`rightannote'", ///
        "`righthead'", ///
        "`pval'", ///
        "`nostarpval'", ///
        "`xticks'", ///
        `xline', ///
        "`marker'", ///
        `markersize', ///
        "`markercolor'", ///
        "`linecolor'", ///
        `linewidth', ///
        "`outfile'", ///
        "`modelcol'", ///
        "`modellabels'", ///
        "`nopreprocess'", ///
        "`debug'" ///
    )

    restore

    // Display the plot if saving was not specified (show temp file)
    if `"`saving'"' == "" {
        display as text "Forest plot created"
        display as text "To save: forestpy ..., saving(filename.png)"
    }
    else {
        display as text `"Forest plot saved to: `outfile'"'
    }

    // Return results
    return scalar N = `N'
    return local estimate "`estimate'"
    return local varlabel "`varlabel'"
    if "`ll'" != "" {
        return local ll "`ll'"
        return local hl "`hl'"
    }
    if "`outfile'" != "" {
        return local filename "`outfile'"
    }
end

// =============================================================================
// Check Python dependencies
// =============================================================================

program define _forestpy_check_deps, rclass

    return scalar failed = 0

    // Check for required core packages (pandas, numpy, matplotlib)
    capture python: import pandas
    if _rc {
        display as error "pandas not found"
        display as error "Please install: pip install pandas"
        display as error "Or on Debian/Ubuntu: apt install python3-pandas"
        return scalar failed = 1
        exit
    }

    capture python: import numpy
    if _rc {
        display as error "numpy not found"
        display as error "Please install: pip install numpy"
        display as error "Or on Debian/Ubuntu: apt install python3-numpy"
        return scalar failed = 1
        exit
    }

    capture python: import matplotlib
    if _rc {
        display as error "matplotlib not found"
        display as error "Please install: pip install matplotlib"
        display as error "Or on Debian/Ubuntu: apt install python3-matplotlib"
        return scalar failed = 1
        exit
    }

    // Set matplotlib backend for non-interactive use
    quietly python: import matplotlib; matplotlib.use('Agg')
end

// =============================================================================
// Parse saving() option
// =============================================================================

program define _parse_saving, sclass
    syntax anything(name=filename) [, *]

    // Remove quotes if present
    local filename = subinstr(`"`filename'"', `"""', "", .)

    // Add extension if not present
    if !regexm("`filename'", "\.(png|pdf|svg|jpg|jpeg|eps|tiff?)$") {
        local filename "`filename'.png"
    }

    sreturn local filename "`filename'"
    sreturn local options "`options'"
end

// =============================================================================
// Python execution code
// =============================================================================

python:
def _forestpy_execute(estimate, varlabel, ll, hl, groupvar, grouporder,
                       do_sort, sortby, logscale, xlabel, ylabel,
                       decimal, fig_width, fig_height, color_alt_rows,
                       table, flush, capitalize, annote, annotehead,
                       rightannote, righthead, pval, nostarpval, xticks,
                       xline, marker, markersize, markercolor, linecolor,
                       linewidth, outfile, modelcol, modellabels,
                       nopreprocess, debug):
    """Execute Python forestplot from Stata data."""

    import sys
    import os
    import pandas as pd
    import numpy as np
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from sfi import Data, Macro

    # Try to import forestplot, fall back to bundled version
    try:
        import forestplot as fp
    except ImportError:
        # Add bundled forestplot to path
        # Check common locations for the bundled package
        cwd = os.getcwd()
        possible_paths = [
            os.path.join(cwd, 'forestpy', 'forestplot-0.4.1'),
            os.path.join(cwd, 'forestplot-0.4.1'),
        ]

        bundled_path = None
        for candidate in possible_paths:
            if os.path.exists(candidate) and os.path.isdir(candidate):
                bundled_path = candidate
                break

        if bundled_path and bundled_path not in sys.path:
            sys.path.insert(0, bundled_path)
            if debug:
                print(f"Added bundled forestplot to path: {bundled_path}")

        try:
            import forestplot as fp
        except ImportError:
            raise ImportError(
                f"forestplot package not found. Please install with: pip install forestplot\n"
                f"Searched in: {possible_paths}"
            )

    # Get data from Stata using Stata 17+ API
    nvar = Data.getVarCount()
    var_names = [Data.getVarName(i) for i in range(nvar)]
    if debug:
        print(f"Variables from Stata: {var_names}")

    # Build dataframe from Stata data
    data_dict = {}
    for var in var_names:
        if Data.isVarTypeStr(var) or Data.isVarTypeStrL(var):
            # String variable - get as list of strings
            nobs = Data.getObsTotal()
            data_dict[var] = [Data.getAt(var, i) for i in range(nobs)]
        else:
            # Numeric variable
            data_dict[var] = Data.get(var=var)

    df = pd.DataFrame(data_dict)

    if debug:
        print(f"DataFrame shape: {df.shape}")
        print(f"DataFrame columns: {df.columns.tolist()}")
        print(df.head())

    # Convert numeric columns
    for col in [estimate]:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')

    if ll and ll in df.columns:
        df[ll] = pd.to_numeric(df[ll], errors='coerce')
    if hl and hl in df.columns:
        df[hl] = pd.to_numeric(df[hl], errors='coerce')
    if pval and pval in df.columns:
        df[pval] = pd.to_numeric(df[pval], errors='coerce')

    # Build forestplot arguments
    kwargs = {
        'dataframe': df,
        'estimate': estimate,
        'varlabel': varlabel,
        'decimal_precision': int(decimal),
        'figsize': (float(fig_width), float(fig_height)),
        'preprocess': nopreprocess == '',
    }

    # Confidence intervals
    if ll and hl:
        kwargs['ll'] = ll
        kwargs['hl'] = hl

    # Grouping
    if groupvar:
        kwargs['groupvar'] = groupvar

    if grouporder:
        # Parse space-separated group order
        kwargs['group_order'] = grouporder.split()

    # Sorting
    if do_sort:
        kwargs['sort'] = True
    if sortby:
        kwargs['sortby'] = sortby

    # Display options
    if logscale:
        kwargs['logscale'] = True

    if xlabel:
        kwargs['xlabel'] = xlabel
    if ylabel:
        kwargs['ylabel'] = ylabel

    if color_alt_rows:
        kwargs['color_alt_rows'] = True

    if table:
        kwargs['table'] = True

    if flush:
        kwargs['flush'] = True
    else:
        kwargs['flush'] = True  # Default to True

    if capitalize:
        kwargs['capitalize'] = capitalize

    # Annotations
    if annote:
        annote_list = annote.split()
        kwargs['annote'] = annote_list
        if annotehead:
            kwargs['annoteheaders'] = annotehead.split()

    if rightannote:
        rightannote_list = rightannote.split()
        kwargs['rightannote'] = rightannote_list
        if righthead:
            kwargs['right_annoteheaders'] = righthead.split()

    # P-values
    if pval:
        kwargs['pval'] = pval
        kwargs['starpval'] = nostarpval == ''

    # X-axis
    if xticks:
        kwargs['xticks'] = [float(x) for x in xticks.split()]

    kwargs['xline'] = float(xline)

    # Marker customization
    kwargs['marker'] = marker
    kwargs['markersize'] = float(markersize)
    kwargs['markercolor'] = markercolor
    kwargs['lw'] = float(linewidth)
    kwargs['linecolor'] = linecolor

    if debug:
        print(f"forestplot kwargs: {kwargs}")

    # Determine if multi-model plot
    if modelcol:
        # Use mforestplot for multi-model
        kwargs['model_col'] = modelcol
        if modellabels:
            kwargs['modellabels'] = modellabels.split()
        ax = fp.mforestplot(**kwargs)
    else:
        # Standard single-model forestplot
        ax = fp.forestplot(**kwargs)

    # Save figure
    plt.tight_layout()
    plt.savefig(outfile, dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()

    if debug:
        print(f"Plot saved to: {outfile}")

end

// End of forestpy.ado

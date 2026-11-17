*! _qba_plot_validate_cells Version 1.2.1  2026/11/17
*! Internal helper: validate qba_plot 2x2 cell options
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

capture program drop _qba_plot_validate_cells
program define _qba_plot_validate_cells
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , PLOT(string) A(real) B(real) C(real) D(real)

        * Presence of a()-d() is checked by qba_plot from the raw options;
        * every value reaching here was typed by the caller.
        foreach _cell in a b c d {
            if missing(``_cell'') {
                display as error "`_cell'() must be nonmissing"
                exit 198
            }
            if ``_cell'' < 0 {
                display as error "cell counts must be non-negative"
                exit 198
            }
        }
        if `a' + `b' + `c' + `d' == 0 {
            display as error "cell counts must include at least one observation"
            exit 2000
        }

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end

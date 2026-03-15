*! _tte_expand_factors Version 1.2.0  2026/03/15
*! Factor variable expansion for tte_fit
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet

/*
Description:
  Parses a mixed token string, detects factor variable notation,
  and creates named dummy variables. Returns expanded variable names
  via c_local.

  Supports: i.var, ib#.var, ibn.var, i(list).var

  Algorithm per factor token:
    1. Parse notation with regexm()
    2. levelsof var → get all levels
    3. Determine base level
    4. For each non-base level, create _tte_fv_VARNAME_LEVEL
    5. Return expanded list via c_local
*/

program define _tte_expand_factors
    version 16.0
    * Note: varabbrev is managed by the caller (tte_fit)

    syntax , input(string) expanded(string)

    local result ""

    * Process each token
    foreach tok of local input {

        * Check for factor variable notation
        local is_factor = 0
        local base_type ""
        local base_val ""
        local varname ""
        local selected_levels ""

        * i.var — default base (lowest level)
        if regexm("`tok'", "^i\.(.+)$") {
            local is_factor = 1
            local base_type "lowest"
            local varname = regexs(1)
        }
        * ib#.var — explicit base at level #
        else if regexm("`tok'", "^ib([0-9]+)\.(.+)$") {
            local is_factor = 1
            local base_type "explicit"
            local base_val = regexs(1)
            local varname = regexs(2)
        }
        * ibn.var — no base (all levels get dummies)
        else if regexm("`tok'", "^ibn\.(.+)$") {
            local is_factor = 1
            local base_type "none"
            local varname = regexs(1)
        }
        * i(list).var — only listed levels
        else if regexm("`tok'", "^i\(([0-9, -]+)\)\.(.+)$") {
            local is_factor = 1
            local base_type "selected"
            local selected_levels = regexs(1)
            local varname = regexs(2)
            * Clean up commas to spaces
            local selected_levels : subinstr local selected_levels "," " ", all
        }

        if `is_factor' {
            * Validate variable exists and is numeric
            capture confirm numeric variable `varname'
            if _rc != 0 {
                display as error "factor variable `varname' not found or not numeric"
                exit 111
            }

            * Get all levels
            quietly levelsof `varname', local(all_levels)

            * Guard against continuous variables
            local n_levels : word count `all_levels'
            if `n_levels' > 20 {
                display as error "factor variable `varname' has `n_levels' levels"
                display as error "factor notation is intended for categorical variables"
                exit 134
            }

            * Determine base level
            local base_level ""
            if "`base_type'" == "lowest" {
                local base_level : word 1 of `all_levels'
            }
            else if "`base_type'" == "explicit" {
                local base_level "`base_val'"
                * Validate base level exists
                local found_base = 0
                foreach lev of local all_levels {
                    if `lev' == `base_level' local found_base = 1
                }
                if !`found_base' {
                    display as error "base level `base_level' not found in `varname'"
                    exit 198
                }
            }
            * base_type "none" and "selected" have no base to exclude

            * Get value label if attached
            local vallbl : value label `varname'

            * Determine which levels to create dummies for
            local levels_to_expand ""
            if "`base_type'" == "selected" {
                local levels_to_expand "`selected_levels'"
            }
            else {
                local levels_to_expand "`all_levels'"
            }

            * Create dummies for each non-base level
            foreach lev of local levels_to_expand {
                * Skip base level (unless base_type is "none" or "selected")
                if "`base_type'" != "none" & "`base_type'" != "selected" {
                    if `lev' == `base_level' continue
                }

                * Construct variable name: _tte_fv_VARNAME_LEVEL
                * Truncate varname if needed to fit 32-char limit
                local vn_short = substr("`varname'", 1, 20)
                local dummyname "_tte_fv_`vn_short'_`lev'"
                * Ensure within 32 chars
                local dummyname = substr("`dummyname'", 1, 32)

                * Create if doesn't already exist
                capture confirm variable `dummyname'
                if _rc != 0 {
                    quietly gen byte `dummyname' = (`varname' == `lev')

                    * Build variable label (truncate to 80-char limit)
                    local _varlbl ""
                    if "`vallbl'" != "" {
                        local lev_label : label `vallbl' `lev'
                        if "`base_level'" != "" {
                            local base_label : label `vallbl' `base_level'
                            local _varlbl "`varname': `lev_label' (vs `base_label')"
                        }
                        else {
                            local _varlbl "`varname': `lev_label'"
                        }
                    }
                    else {
                        if "`base_level'" != "" {
                            local _varlbl "`varname' == `lev' (vs `base_level')"
                        }
                        else {
                            local _varlbl "`varname' == `lev'"
                        }
                    }
                    local _varlbl = substr("`_varlbl'", 1, 80)
                    label variable `dummyname' "`_varlbl'"
                }

                local result "`result' `dummyname'"
            }
        }
        else {
            * Not a factor variable — pass through as-is
            local result "`result' `tok'"
        }
    }

    * Return expanded list
    local result = strtrim("`result'")
    c_local `expanded' "`result'"
end

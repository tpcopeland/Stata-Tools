*! qba_plot Version 1.0.1  2026/06/19
*! Visualization for quantitative bias analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Creates visualizations for QBA results:
  - tornado: Tornado plot showing parameter sensitivity
  - distribution: Histogram/density of Monte Carlo corrected estimates
  - tipping: Tipping point contour plot

References:
  Lash TL, Fox MP, Fink AK. Applying Quantitative Bias Analysis to
    Epidemiologic Data. 2nd ed. Springer; 2021.
*/

capture program drop qba_plot
program define qba_plot, rclass
    version 16.0
    local _saved_varabbrev = c(varabbrev)
    local _raw_syntax `"`0'"'
    set varabbrev off
    capture noisily {

    _qba_require_distributions

    syntax , [TORnado DISTribution TIPping ///
        A(real -1) B(real -1) C(real -1) D(real -1) ///
        MEAsure(string) TYpe(string) ///
        PARAM1(string) RANGE1(numlist min=2 max=2) ///
        PARAM2(string) RANGE2(numlist min=2 max=2) ///
        PARAM3(string) RANGE3(numlist min=2 max=2) ///
        Steps(integer 20) ///
        BASE_se(real 0.9) BASE_sp(real 0.9) ///
        BASE_sela(real 1) BASE_selb(real 1) BASE_selc(real 1) BASE_seld(real 1) ///
        BASE_p1(real 0.3) BASE_p0(real 0.1) BASE_rrcd(real 2) BASE_rrud(real -1) ///
        USing(string) OBServed(real -999) NUll(real -999) ///
        SCHeme(string) TItle(string) SAving(string) ///
        name(string) replace ///
        *]

    * Must specify exactly one plot type
    local n_types = ("`tornado'" != "") + ("`distribution'" != "") + ("`tipping'" != "")
    if `n_types' != 1 {
        display as error "specify exactly one of: tornado, distribution, tipping"
        exit 198
    }

	    if `steps' < 2 {
	        display as error "steps() must be at least 2"
	        exit 198
	    }
	    if missing(`steps') {
	        display as error "steps() must be a nonmissing integer"
	        exit 198
	    }

    if "`scheme'" == "" local scheme "`c(scheme)'"
    local measure_user = ("`measure'" != "")
	    if "`measure'" == "" local measure "OR"
	    local measure = strupper("`measure'")
	    if "`type'" == "" local type "exposure"
	    local type = strlower("`type'")

    * Accept graph-style name(foo, replace) without treating it as file replace.
    local _raw_lower = lower(`"`_raw_syntax'"')
    local _name_had_replace = regexm(`"`_raw_lower'"', "name\([^)]*,[ ]*replace[ ]*\)")
    local _raw_without_name = regexr(`"`_raw_lower'"', "name\([^)]*\)", "")
    local _standalone_replace = regexm(`"`_raw_without_name'"', "(^|[ ,])replace([ ,]|$)")
    if `_name_had_replace' {
        local name_replace "replace"
        if !`_standalone_replace' local replace ""
    }

    * Also accept name() content left unsplit by syntax in unusual quoting cases.
    if `"`name'"' != "" {
        gettoken _graph_name _graph_name_opts : name, parse(",")
        local _graph_name = strtrim(`"`_graph_name'"')
        local _graph_name_opts = subinstr(`"`_graph_name_opts'"', ",", "", 1)
        local _graph_name_opts = strtrim(`"`_graph_name_opts'"')
        if `"`_graph_name_opts'"' != "" {
            if lower(`"`_graph_name_opts'"') == "replace" {
                local name_replace "replace"
            }
            else {
                display as error "name() supports only the replace suboption"
                exit 198
            }
        }
        local name `"`_graph_name'"'
    }
    local graph_replace "`replace'"
    if "`name_replace'" != "" local graph_replace "replace"

    if !inlist("`measure'", "OR", "RR", "COEFFICIENT") {
        display as error "measure() must be OR, RR, or coefficient"
        exit 198
    }
    if "`measure'" == "COEFFICIENT" & "`distribution'" == "" {
        display as error "measure(coefficient) is only supported with distribution plots"
        exit 198
    }
    if !inlist("`type'", "exposure", "outcome") {
        display as error "type() must be exposure or outcome"
        exit 198
    }
    if ("`tornado'" != "" | "`tipping'" != "") & `null' == -999 {
        local null 1
    }

    local measure_label "`measure'"
    if "`measure'" == "COEFFICIENT" local measure_label "Coefficient"

    * Ensure param/range options are paired before using them.
	    forvalues _i = 1/3 {
	        if "`param`_i''" != "" & "`range`_i''" == "" {
	            display as error "param`_i'() requires range`_i'()"
            exit 198
        }
        if "`param`_i''" == "" & "`range`_i''" != "" {
            display as error "range`_i'() requires param`_i'()"
            exit 198
        }
    }
	    if "`tipping'" != "" & "`param3'" != "" {
	        display as error "param3() is only supported with tornado plots"
	        exit 198
	    }
	    foreach _p in param1 param2 param3 {
	        if "``_p''" != "" {
	            local `_p' = strlower("``_p''")
	        }
	    }

    * Validate parameter names
    local valid_params "se seca sp spca secb spcb sela selb selc seld p1 p0 rrcd rrud"
    foreach _p in param1 param2 param3 {
        if "``_p''" != "" {
            local _found = 0
            foreach _vp of local valid_params {
                if "``_p''" == "`_vp'" local _found = 1
            }
            if !`_found' {
                display as error "`_p'(``_p'') is not a recognized bias parameter"
                display as error "valid: `valid_params'"
                exit 198
            }
        }
    }

    * Reject secb/spcb as sweep parameters (not implemented for differential)
    if "`tornado'" != "" | "`tipping'" != "" {
        foreach _p in param1 param2 param3 {
            if inlist("``_p''", "secb", "spcb") {
                display as error "``_p'' is not supported for tornado/tipping plots"
                display as error "use seca/spca for nondifferential sensitivity analysis"
                exit 198
            }
        }
    }

    * Normalize aliases and check for duplicates
    local _norm_params ""
    foreach _p in param1 param2 param3 {
        if "``_p''" != "" {
            local _np = "``_p''"
            if "`_np'" == "se" local _np "seca"
            if "`_np'" == "sp" local _np "spca"
            if strpos("`_norm_params'", "`_np'") > 0 {
                display as error "duplicate parameter: ``_p'' maps to same parameter as another"
                exit 198
            }
            local _norm_params "`_norm_params' `_np'"
        }
    }

    * Map short parameter names to readable labels
    foreach _p in param1 param2 param3 {
        local _lab ""
        if "``_p''" == "se" | "``_p''" == "seca"  local _lab "Sensitivity"
        if "``_p''" == "sp" | "``_p''" == "spca"  local _lab "Specificity"
        if "``_p''" == "secb"  local _lab "Sensitivity (group B)"
        if "``_p''" == "spcb"  local _lab "Specificity (group B)"
        if "``_p''" == "sela"  local _lab "Sel: exposed cases"
        if "``_p''" == "selb"  local _lab "Sel: unexposed cases"
        if "``_p''" == "selc"  local _lab "Sel: exposed non-cases"
        if "``_p''" == "seld"  local _lab "Sel: unexposed non-cases"
        if "``_p''" == "p1"    local _lab "P(confounder|exposed)"
        if "``_p''" == "p0"    local _lab "P(confounder|unexposed)"
        if "``_p''" == "rrcd"  local _lab "RR(confounder-disease)"
        if "``_p''" == "rrud"  local _lab "RR(confounder-disease)"
        if "`_lab'" == "" local _lab "``_p''"
        local `_p'_label "`_lab'"
    }

    * Classify parameter type
    * Returns: "misclass", "selection", or "confound"
    foreach _p in param1 param2 param3 {
        local _ptype ""
        if inlist("``_p''", "se", "seca", "sp", "spca", "secb", "spcb") {
            local _ptype "misclass"
        }
        else if inlist("``_p''", "sela", "selb", "selc", "seld") {
            local _ptype "selection"
        }
        else if inlist("``_p''", "p1", "p0", "rrcd", "rrud") {
            local _ptype "confound"
        }
        local `_p'_type "`_ptype'"
    }

    * Validate sweep ranges and baselines against parameter support.
    if "`tornado'" != "" | "`tipping'" != "" {
        local _needs_misclass = (strpos(" `_norm_params' ", " seca ") > 0 | ///
            strpos(" `_norm_params' ", " spca ") > 0)
        local _needs_selection = (strpos(" `_norm_params' ", " sela ") > 0 | ///
            strpos(" `_norm_params' ", " selb ") > 0 | ///
            strpos(" `_norm_params' ", " selc ") > 0 | ///
            strpos(" `_norm_params' ", " seld ") > 0)
        local _needs_confound = (strpos(" `_norm_params' ", " p1 ") > 0 | ///
            strpos(" `_norm_params' ", " p0 ") > 0 | ///
            strpos(" `_norm_params' ", " rrcd ") > 0 | ///
            strpos(" `_norm_params' ", " rrud ") > 0)

        forvalues _i = 1/3 {
            if "`param`_i''" != "" {
                local _np "`param`_i''"
                if "`_np'" == "se" local _np "seca"
                if "`_np'" == "sp" local _np "spca"
	                local _lo : word 1 of `range`_i''
	                local _hi : word 2 of `range`_i''
	                if missing(`_lo') | missing(`_hi') {
	                    display as error "range`_i'() values must be nonmissing"
	                    exit 198
	                }
	                if `_lo' > `_hi' {
	                    display as error "range`_i'() lower bound must be <= upper bound"
	                    exit 198
	                }
	                foreach _val in `_lo' `_hi' {
                    if "`param`_i'_type'" == "misclass" {
                        if `_val' <= 0 | `_val' > 1 {
                            display as error "range`_i'() values for `param`_i'' must be in (0,1]"
                            exit 198
                        }
                    }
                    else if "`param`_i'_type'" == "selection" {
                        if `_val' <= 0 | `_val' > 1 {
                            display as error "range`_i'() values for `param`_i'' must be in (0,1]"
                            exit 198
                        }
                    }
                    else if "`param`_i'_type'" == "confound" {
                        if inlist("`_np'", "p1", "p0") {
                            if `_val' < 0 | `_val' > 1 {
                                display as error "range`_i'() values for `param`_i'' must be in [0,1]"
                                exit 198
                            }
                        }
                        else if inlist("`_np'", "rrcd", "rrud") {
                            if `_val' <= 0 {
                                display as error "range`_i'() values for `param`_i'' must be > 0"
                                exit 198
                            }
                        }
                    }
                }
            }
        }

        if `_needs_misclass' {
            if `base_se' <= 0 | `base_se' > 1 {
                display as error "base_se() must be in (0,1]"
                exit 198
            }
            if `base_sp' <= 0 | `base_sp' > 1 {
                display as error "base_sp() must be in (0,1]"
                exit 198
            }
        }
        if `_needs_selection' {
            foreach _base in base_sela base_selb base_selc base_seld {
                if ``_base'' <= 0 | ``_base'' > 1 {
                    display as error "`_base'() must be in (0,1]"
                    exit 198
                }
            }
        }
        if `_needs_confound' {
            if `base_p1' < 0 | `base_p1' > 1 {
                display as error "base_p1() must be in [0,1]"
                exit 198
            }
            if `base_p0' < 0 | `base_p0' > 1 {
                display as error "base_p0() must be in [0,1]"
                exit 198
            }
	            if missing(`base_rrcd') | `base_rrcd' <= 0 {
	                display as error "base_rrcd() must be > 0"
	                exit 198
	            }
	            if `base_rrud' != -1 & (missing(`base_rrud') | `base_rrud' <= 0) {
	                display as error "base_rrud() must be > 0"
	                exit 198
            }
        }
    }

	    local base_conf_rr = `base_rrcd'
	    local base_conf_formula "rrcd"
	    if `base_rrud' != -1 {
	        local base_conf_rr = `base_rrud'
	        local base_conf_formula "rrud"
	    }
	    local graph_rc = 0
    local n_missing ""
    local measure_branch "`measure'"

    local _plot_title ""
    if `"`title'"' != "" local _plot_title `"title(`"`title'"')"'
    local _plot_saving ""
    if `"`saving'"' != "" local _plot_saving `"saving(`"`saving'"')"'
    local _plot_name ""
    if `"`name'"' != "" local _plot_name `"name(`"`name'"')"'
    local _plot_export_replace ""
    if "`replace'" != "" local _plot_export_replace "export_replace(`replace')"
    local _plot_graph_replace ""
    if "`graph_replace'" != "" local _plot_graph_replace "graph_replace(`graph_replace')"
    local _plotopts ""
    if `"`options'"' != "" {
        tempfile _plotopts_file
        tempname _plotopts_fh
        file open `_plotopts_fh' using "`_plotopts_file'", write text replace
        file write `_plotopts_fh' `"`options'"' _n
        file close `_plotopts_fh'
        local _plotopts `"plotoptsfile(`"`_plotopts_file'"')"'
    }

    if "`tornado'" != "" {
        local _plot_param2 ""
        if "`param2'" != "" {
            local _plot_param2 `"param2(`"`param2'"') range2(`range2') "'
            local _plot_param2 `"`_plot_param2'p2type(`"`param2_type'"') p2label(`"`param2_label'"')"'
        }
        local _plot_param3 ""
        if "`param3'" != "" {
            local _plot_param3 `"param3(`"`param3'"') range3(`range3') "'
            local _plot_param3 `"`_plot_param3'p3type(`"`param3_type'"') p3label(`"`param3_label'"')"'
        }
        _qba_plot_tornado, a(`a') b(`b') c(`c') d(`d') ///
            measure("`measure'") type("`type'") ///
            param1("`param1'") range1(`range1') ///
            p1type("`param1_type'") p1label(`"`param1_label'"') ///
            `_plot_param2' `_plot_param3' ///
            steps(`steps') ///
            base_se(`base_se') base_sp(`base_sp') ///
            base_sela(`base_sela') base_selb(`base_selb') ///
            base_selc(`base_selc') base_seld(`base_seld') ///
            base_p1(`base_p1') base_p0(`base_p0') ///
            base_conf_rr(`base_conf_rr') base_conf_formula("`base_conf_formula'") ///
            null(`null') scheme("`scheme'") measurelabel(`"`measure_label'"') ///
            `_plot_title' `_plot_saving' `_plot_name' ///
            `_plot_export_replace' `_plot_graph_replace' `_plotopts'
        local graph_rc = r(graph_rc)
        local n_missing = r(n_missing)
    }

    if "`distribution'" != "" {
        _qba_plot_distribution, using(`"`using'"') observed(`observed') ///
            null(`null') measure("`measure'") measureuser(`measure_user') ///
            scheme("`scheme'") `_plot_title' `_plot_saving' `_plot_name' ///
            `_plot_export_replace' `_plot_graph_replace' `_plotopts'
        local graph_rc = r(graph_rc)
        local measure_branch "`r(measure)'"
    }

    if "`tipping'" != "" {
        _qba_plot_tipping, a(`a') b(`b') c(`c') d(`d') ///
            measure("`measure'") type("`type'") ///
            param1("`param1'") range1(`range1') ///
            param2("`param2'") range2(`range2') ///
            p1type("`param1_type'") p2type("`param2_type'") ///
            p1label(`"`param1_label'"') p2label(`"`param2_label'"') ///
            steps(`steps') base_se(`base_se') base_sp(`base_sp') ///
            base_p1(`base_p1') base_p0(`base_p0') ///
            base_conf_rr(`base_conf_rr') base_conf_formula("`base_conf_formula'") ///
            null(`null') scheme("`scheme'") measurelabel(`"`measure_label'"') ///
            `_plot_title' `_plot_saving' `_plot_name' ///
            `_plot_export_replace' `_plot_graph_replace' `_plotopts'
        local graph_rc = r(graph_rc)
        local n_missing = r(n_missing)
    }

    return clear
    return local plot_type "`tornado'`distribution'`tipping'"
    return local scheme "`scheme'"
    local measure_return "`measure_branch'"
    if "`measure_branch'" == "COEFFICIENT" local measure_return "coefficient"
    return local measure "`measure_return'"
	    if "`n_missing'" != "" {
	        return scalar n_missing = `n_missing'
	    }
	    if `graph_rc' {
	        display as error "graph export or rename failed; plot metadata are posted in r()"
	        exit `graph_rc'
	    }

    }
    local rc = _rc
    set varabbrev `_saved_varabbrev'
    if `rc' exit `rc'
end

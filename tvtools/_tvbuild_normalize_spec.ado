*! _tvbuild_normalize_spec Version 1.17.1  2026/08/30
*! Normalise either tvbuild input form into one internal plan frame
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* tvbuild accepts two public input forms -- a one-source inline shortcut and a
* canonical specframe() with one typed row per source -- and both must reach
* the engines through exactly one internal representation. That representation
* is the plan frame of Section 12.6 of the single-pass plan: one row per
* source, tempnamed, immutable after preflight, and handed to every consumer
* by name rather than through a global or a dataset characteristic.
*
* Two forms sharing one normaliser is the point, and it is also the trap. If a
* mapping bug lives in the shared normaliser, a test that only compares the
* two forms against each other passes while both are wrong. The QA suite
* therefore compares each form against a fixed expected plan as well.
*
* The specification frame is DATA, never command text. Every list cell is
* tokenised on whitespace and each token must satisfy `confirm name' -- which
* is the whitelist: it accepts exactly the legal Stata variable names and
* rejects wildcards, hyphen ranges, factor and time-series operators, commas,
* quotes, and command punctuation, because none of those is a legal name.
* Nothing here is passed to `run', `do', `stata()', or macro indirection.
*
* An unknown specification column is an error rather than something ignored,
* so a misspelling such as total_var cannot silently change quantity algebra
* at rc=0.
*
* The caller creates and owns the plan frame; this program only fills it.
*
* Returns:
*   r(n_sources)     rows written to the plan frame
*   r(spec_version)  normalised public specification version
*   r(source_names)  logical source names in specification order
*   r(output_vars)   every mapped output name in row/token order

capture program drop _tvbuild_normalize_spec
program define _tvbuild_normalize_spec, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , PLANframe(name) [SPECframe(name) ///
        SOURCEFrame(name) SOURCEUsing(string) SOURCEName(name) ///
        START(name) STOP(name) EXPOSure(name) ///
        REFerence(string) GENerate(name) ///
        REFERENCELabel(string) LABel(string)]

    * ---- the allowed public specification columns -------------------------
    local _req_cols source_name source_kind source_frame source_file ///
        start_var stop_var input_vars output_vars reference
    local _opt_cols rate_vars total_vars cumulative_vars ///
        reference_label variable_label description
    local _all_cols "`_req_cols' `_opt_cols'"
    * reference is the only numeric column; every other one is a string.
    local _numeric_cols reference

    * ---- create the internal plan schema ----------------------------------
    frame change `planframe'
    quietly {
        generate long   source_index     = .
        generate str32  source_name      = ""
        generate str12  source_kind      = ""
        generate str8   input_kind       = ""
        generate str32  source_frame     = ""
        generate strL   resolved_file    = ""
        generate str32  start_var        = ""
        generate str32  stop_var         = ""
        generate strL   input_vars       = ""
        generate strL   output_vars      = ""
        generate double reference        = .
        generate strL   rate_vars        = ""
        generate strL   total_vars       = ""
        generate strL   cumulative_vars  = ""
        generate strL   reference_label  = ""
        generate strL   variable_label   = ""
        generate strL   description      = ""
        generate str32  engine           = ""
        generate double N_input          = .
        generate double N_persons        = .
        generate double N_unmatched_ids  = .
        generate double N_outside_window = .
        generate double N_gap_ids        = .
        generate double N_uncovered      = .
    }
    frame change `_caller_frame'

    local spec_version 1

    if "`specframe'" != "" {
        **# Canonical specification-frame form

        frame change `specframe'
        local _v : char _dta[tvbuild_spec_version]
        quietly ds
        local _cols "`r(varlist)'"
        local _nrows = _N
        frame change `_caller_frame'

        * Schema version. An absent characteristic means version 1; an
        * unsupported nonempty one errors before a source is opened.
        *
        * The characteristic is DATA, so the test may never place it where
        * Stata would resolve it as a name. Stata's `&' does not short-circuit,
        * which is what defeated the obvious form:
        *
        *     capture confirm integer number `_v'
        *     if _rc == 0 & `_v' == 1 ...
        *
        * The numeric comparison is evaluated even when `confirm' has already
        * failed, so a characteristic reading `two' is looked up as a VARIABLE
        * -- r(111) "two not found" -- from the one line whose entire purpose
        * is to report r(198) with the message below. Nesting the comparison
        * inside the rc test fixes that case and still breaks on a two-token
        * value, because `confirm integer number 1 2' accepts a LIST and
        * `if 1 2 == 1' is then a syntax error.
        *
        * real() closes both: it cannot be read as a name, and it returns
        * missing for anything non-numeric or multi-token. One evaluation,
        * no second interpretation.
        if `"`_v'"' != "" {
            local _vnum = real(`"`_v'"')
            if missing(`_vnum') | `_vnum' != 1 {
                noisily display as error ///
                    `"specframe(`specframe') declares specification version '`_v''"'
                noisily display as error ///
                    "this tvbuild supports version 1"
                exit 198
            }
        }

        if `_nrows' < 1 {
            noisily display as error ///
                "specframe(`specframe') has no observations; one row per source is required"
            exit 2000
        }

        * Required columns present, unknown columns refused.
        foreach c of local _req_cols {
            local _has : list c in _cols
            if !`_has' {
                noisily display as error ///
                    "specframe(`specframe') is missing the required column '`c''"
                exit 111
            }
        }
        foreach c of local _cols {
            local _known : list c in _all_cols
            if !`_known' {
                noisily display as error ///
                    "specframe(`specframe') carries the unknown column '`c''"
                noisily display as error ///
                    "unknown columns are refused so a misspelling cannot change the mapping at rc=0"
                exit 198
            }
        }

        * Declared storage class. A numeric column supplied as a string, or the
        * reverse, changes what every downstream read of it means.
        frame change `specframe'
        local _classerr ""
        foreach c of local _cols {
            local _t : type `c'
            local _is_str = (substr("`_t'", 1, 3) == "str")
            local _want_num : list c in _numeric_cols
            if `_want_num' & `_is_str' local _classerr "`c' must be numeric; it is `_t'"
            if !`_want_num' & !`_is_str' & "`_classerr'" == "" ///
                local _classerr "`c' must be a string variable; it is `_t'"
        }
        frame change `_caller_frame'
        if "`_classerr'" != "" {
            noisily display as error "specframe(`specframe') column `_classerr'"
            exit 109
        }

        * A cell is data, and every cell is read into a local on its way to the
        * plan frame. Stata re-scans substituted text, so a cell containing a
        * backtick, a dollar sign, or a double quote would be EXPANDED at that
        * point: a source_file holding the six characters `f' silently becomes
        * whatever a local named f happens to hold in this program, which is
        * usually nothing. That is macro indirection, which Section 12.3 forbids
        * -- and the symptom is not an error but a cell that quietly reads as
        * empty. Refuse the characters instead, tested with char() so this test
        * cannot be undone by its own quoting.
        frame change `specframe'
        local _badcells ""
        foreach c of local _cols {
            if "`c'" == "reference" continue
            quietly count if strpos(`c', char(96)) | strpos(`c', char(36)) | ///
                strpos(`c', char(34))
            if r(N) > 0 local _badcells "`_badcells' `c'"
        }
        frame change `_caller_frame'
        if "`_badcells'" != "" {
            noisily display as error ///
                "specframe(`specframe'): these column(s) contain a backtick, dollar sign, or double quote:`_badcells'"
            noisily display as error ///
                "specification cells are data; those characters would be expanded as macro references"
            noisily display as error ///
                "resolve the macro before storing it: -replace source_file = char(34) + <macro> + char(34)- style assignment, or -replace- with the expanded value"
            exit 198
        }

        forvalues i = 1/`_nrows' {
            foreach c of local _all_cols {
                local _c_`c' ""
            }
            frame change `specframe'
            foreach c of local _cols {
                if "`c'" == "reference" {
                    local _c_reference "."
                    if !missing(reference[`i']) local _c_reference = reference[`i']
                }
                else local _c_`c' = `c'[`i']
            }
            frame change `_caller_frame'

            _tvbuild_write_plan_row, planframe(`planframe') index(`i') ///
                sname(`"`_c_source_name'"') skind(`"`_c_source_kind'"') ///
                sframe(`"`_c_source_frame'"') sfile(`"`_c_source_file'"') ///
                svar(`"`_c_start_var'"') pvar(`"`_c_stop_var'"') ///
                ivars(`"`_c_input_vars'"') ovars(`"`_c_output_vars'"') ///
                ref(`"`_c_reference'"') ///
                rvars(`"`_c_rate_vars'"') tvars(`"`_c_total_vars'"') ///
                cvars(`"`_c_cumulative_vars'"') ///
                rlab(`"`_c_reference_label'"') vlab(`"`_c_variable_label'"') ///
                desc(`"`_c_description'"')
        }
        local n_sources = `_nrows'
    }
    else {
        **# One-source inline form
        * Always normalises to exactly one `episodes' row. A ready-interval
        * source uses specframe(): the inline options name a single categorical
        * episode column and cannot describe a multi-payload interval table.
        local _sname "`sourcename'"
        if "`_sname'" == "" local _sname "`generate'"

        _tvbuild_write_plan_row, planframe(`planframe') index(1) ///
            sname(`"`_sname'"') skind("episodes") ///
            sframe(`"`sourceframe'"') sfile(`"`sourceusing'"') ///
            svar(`"`start'"') pvar(`"`stop'"') ///
            ivars(`"`exposure'"') ovars(`"`generate'"') ///
            ref(`"`reference'"') ///
            rvars("") tvars("") cvars("") ///
            rlab(`"`referencelabel'"') vlab(`"`label'"') ///
            desc("one-source shortcut")
        local n_sources = 1
    }

    **# Row-level rules, applied to the normalised plan
    frame change `planframe'

    local all_source_names ""
    local all_output_vars ""

    forvalues i = 1/`n_sources' {
        local sn      = source_name[`i']
        local kind    = source_kind[`i']
        local sfr     = source_frame[`i']
        local sfi     = resolved_file[`i']
        local sv      = start_var[`i']
        local pv      = stop_var[`i']
        local iv      = input_vars[`i']
        local ov      = output_vars[`i']
        local rv      = rate_vars[`i']
        local tv      = total_vars[`i']
        local cv      = cumulative_vars[`i']
        local rlab    = reference_label[`i']
        local vlab    = variable_label[`i']
        local ref_mis = missing(reference[`i'])
        local ref_val = reference[`i']
        local _where "source `i'"
        if "`sn'" != "" local _where "source `i' (`sn')"

        * source_name: present, legal, unique
        if "`sn'" == "" {
            noisily display as error "`_where': source_name is empty"
            exit 198
        }
        capture confirm name `sn'
        if _rc | strlen("`sn'") > 32 {
            noisily display as error "`_where': source_name is not a legal Stata name"
            exit 198
        }
        local _dup : list sn in all_source_names
        if `_dup' {
            noisily display as error "`_where': source_name '`sn'' is used more than once"
            exit 198
        }
        local all_source_names "`all_source_names' `sn'"

        * source_kind
        if !inlist("`kind'", "episodes", "intervals") {
            noisily display as error ///
                "`_where': source_kind must be episodes or intervals, not '`kind''"
            exit 198
        }

        * exactly one locator
        local _has_fr = ("`sfr'" != "")
        local _has_fi = (`"`sfi'"' != "")
        if `_has_fr' + `_has_fi' != 1 {
            noisily display as error ///
                "`_where': specify exactly one of source_frame and source_file"
            exit 198
        }
        quietly replace input_kind = cond(`_has_fr', "frame", "file") in `i'

        * bounds and payload names
        if "`sv'" == "" {
            noisily display as error "`_where': start_var is empty"
            exit 198
        }
        if "`pv'" == "" {
            noisily display as error "`_where': stop_var is empty"
            exit 198
        }
        * The interval bounds are single columns, and `one' says so here rather
        * than letting a two-token cell reach _tvbuild_load_source and surface as
        * "option startvar(): too many names specified" -- an r(103) from an
        * internal option, naming neither the offending row nor the column the
        * caller has to edit.
        _tvbuild_check_namelist, list(`"`sv'"') role(start_var) where("`_where'") one
        _tvbuild_check_namelist, list(`"`pv'"') role(stop_var) where("`_where'") one
        _tvbuild_check_namelist, list(`"`iv'"') role(input_vars) where("`_where'")
        _tvbuild_check_namelist, list(`"`ov'"') role(output_vars) where("`_where'")

        local _n_in : word count `iv'
        local _n_out : word count `ov'
        if `_n_in' != `_n_out' {
            noisily display as error ///
                "`_where': input_vars has `_n_in' name(s), output_vars has `_n_out'"
            noisily display as error ///
                "they are mapped position by position and must have the same count"
            exit 198
        }

        * start_var, stop_var, and every input name mutually distinct
        local _roles "`sv' `pv' `iv'"
        local _roledups : list dups _roles
        if "`_roledups'" != "" {
            noisily display as error ///
                "`_where': start_var, stop_var, and input_vars overlap on:`_roledups'"
            exit 198
        }

        * output names globally unique
        local _outdups : list dups ov
        if "`_outdups'" != "" {
            noisily display as error "`_where': output_vars repeats:`_outdups'"
            exit 198
        }
        foreach o of local ov {
            local _clash : list o in all_output_vars
            if `_clash' {
                noisily display as error ///
                    "`_where': output name '`o'' is already produced by an earlier source"
                exit 198
            }
        }
        local all_output_vars "`all_output_vars' `ov'"

        * quantity lists: legal names, subsets of input_vars, pairwise disjoint
        if "`rv'" != "" {
            _tvbuild_check_namelist, list(`"`rv'"') role(rate_vars) where("`_where'")
            local _notin : list rv - iv
            if "`_notin'" != "" {
                noisily display as error ///
                    "`_where': rate_vars names variables absent from input_vars:`_notin'"
                exit 198
            }
        }
        if "`tv'" != "" {
            _tvbuild_check_namelist, list(`"`tv'"') role(total_vars) where("`_where'")
            local _notin : list tv - iv
            if "`_notin'" != "" {
                noisily display as error ///
                    "`_where': total_vars names variables absent from input_vars:`_notin'"
                exit 198
            }
        }
        if "`cv'" != "" {
            _tvbuild_check_namelist, list(`"`cv'"') role(cumulative_vars) where("`_where'")
            local _notin : list cv - iv
            if "`_notin'" != "" {
                noisily display as error ///
                    "`_where': cumulative_vars names variables absent from input_vars:`_notin'"
                exit 198
            }
        }
        * strtrim, because `"`rv' `tv' `cv'"' with three empty lists is two
        * spaces, not the empty string, and "is any quantity declared?" would
        * answer yes for every source.
        local _qall = strtrim(stritrim("`rv' `tv' `cv'"))
        local _qdups : list dups _qall
        if "`_qdups'" != "" {
            noisily display as error ///
                "`_where': rate_vars, total_vars, and cumulative_vars overlap on:`_qdups'"
            exit 198
        }

        * kind-specific rules
        if "`kind'" == "episodes" {
            if `_n_in' != 1 {
                noisily display as error ///
                    "`_where': an episodes source declares exactly one input variable, not `_n_in'"
                noisily display as error ///
                    "build a multi-payload source with tvexpose and declare it as intervals"
                exit 198
            }
            if "`_qall'" != "" {
                noisily display as error ///
                    "`_where': an episodes source carries no quantity variables"
                exit 198
            }
            if `ref_mis' {
                noisily display as error ///
                    "`_where': an episodes source requires a whole nonmissing reference code"
                exit 198
            }
            if `ref_val' != floor(`ref_val') {
                noisily display as error ///
                    "`_where': reference must be whole; Stata cannot label the value `ref_val'"
                exit 198
            }
        }
        else {
            if !`ref_mis' {
                noisily display as error ///
                    "`_where': an intervals source takes no reference code; it is already constructed"
                exit 198
            }
            if `"`rlab'`vlab'"' != "" {
                noisily display as error ///
                    "`_where': reference_label and variable_label describe an episodes source only"
                exit 198
            }
        }
    }

    frame change `_caller_frame'

    return local output_vars  "`all_output_vars'"
    return local source_names "`all_source_names'"
    return scalar spec_version = `spec_version'
    return scalar n_sources = `n_sources'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end


* Append one normalised row. Both public input forms write through this one
* path; see the header note on why that matters and what it hides.
capture program drop _tvbuild_write_plan_row
program define _tvbuild_write_plan_row
    version 16.0
    syntax , PLANframe(name) INDEX(integer) ///
        [SNAME(string) SKIND(string) SFRAME(string) SFILE(string) ///
         SVAR(string) PVAR(string) IVARS(string) OVARS(string) REF(string) ///
         RVARS(string) TVARS(string) CVARS(string) ///
         RLAB(string) VLAB(string) DESC(string)]

    local _here "`c(frame)'"

    * reference is validated before the frame switch so a bad value cannot
    * leave the caller sitting in the plan frame.
    local _refval "."
    if `"`ref'"' != "" & `"`ref'"' != "." {
        capture confirm number `ref'
        if _rc {
            noisily display as error ///
                "source `index': reference '`ref'' is not a number"
            exit 198
        }
        local _refval "`ref'"
    }

    frame change `planframe'
    quietly {
        set obs `index'
        replace source_index    = `index'                       in `index'
        replace source_name     = strtrim(`"`sname'"')          in `index'
        replace source_kind     = lower(strtrim(`"`skind'"'))   in `index'
        replace source_frame    = strtrim(`"`sframe'"')         in `index'
        replace resolved_file   = strtrim(`"`sfile'"')          in `index'
        replace start_var       = strtrim(`"`svar'"')           in `index'
        replace stop_var        = strtrim(`"`pvar'"')           in `index'
        replace input_vars      = strtrim(stritrim(`"`ivars'"')) in `index'
        replace output_vars     = strtrim(stritrim(`"`ovars'"')) in `index'
        replace rate_vars       = strtrim(stritrim(`"`rvars'"')) in `index'
        replace total_vars      = strtrim(stritrim(`"`tvars'"')) in `index'
        replace cumulative_vars = strtrim(stritrim(`"`cvars'"')) in `index'
        replace reference_label = `"`rlab'"'                    in `index'
        replace variable_label  = `"`vlab'"'                    in `index'
        replace description     = `"`desc'"'                    in `index'
        replace reference       = `_refval'                     in `index'
    }
    frame change `_here'
end


* A specification list cell is data. `confirm name' is the whitelist: it
* accepts exactly the legal Stata variable names, so wildcards, hyphen ranges,
* factor and time-series operators, commas, quotes, and command punctuation
* are all refused by construction rather than by a blacklist that has to stay
* complete. A cell that could name a SET of variables could silently change
* which column carries which algebra.
capture program drop _tvbuild_check_namelist
program define _tvbuild_check_namelist
    version 16.0
    syntax , LIST(string) ROLE(string) WHERE(string) [ONE]

    local _n : word count `list'
    if `_n' == 0 {
        noisily display as error "`where': `role' is empty"
        exit 198
    }
    if "`one'" != "" & `_n' > 1 {
        noisily display as error ///
            "`where': `role' names `_n' variables; it takes exactly one"
        noisily display as error ///
            "an interval bound is a single column; map several payloads through input_vars"
        exit 198
    }
    foreach tok of local list {
        capture confirm name `tok'
        if _rc | strlen("`tok'") > 32 {
            noisily display as error ///
                "`where': `role' contains '`tok'', which is not a legal Stata variable name"
            noisily display as error ///
                "list cells are data: give full names only, with no wildcards, ranges, or operators"
            exit 198
        }
    }
end

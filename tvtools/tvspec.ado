*! tvspec Version 1.14.1  2026/08/07
*! Build a tvbuild specification frame one source at a time
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
tvspec writes the multi-source specification frame that tvbuild's specframe()
consumes. Describing two sources by hand takes twelve `generate' statements
across nine required columns plus a dataset characteristic; the same thing here
is one `create' and two `add' calls.

  tvspec create framename [, replace]
  tvspec add    framename , name() {frame()|using()} start() stop()
                            exposure() generate() [reference() kind() ...]
  tvspec list   framename

What tvspec does NOT do is change the specification schema. It writes the same
typed columns, in the same order, with the same characteristic, so a frame it
builds and a frame built by hand are indistinguishable to tvbuild -- and the
hand-built form stays fully supported. tvspec is a convenience over the data
format, never a second definition of it.

It also does not validate the plan. `_tvbuild_normalize_spec' owns every
cross-row rule (name uniqueness, output collisions, quantity subsets, the
episodes/intervals asymmetries) and tvbuild runs it on the frame however the
frame was built. tvspec checks only what it can check about the row in front of
it: that the cell it is about to write is legal, and that the column it writes
into can hold it exactly. Duplicating the plan rules here would create a second
place for them to drift.

The specification frame is DATA, never command text. tvspec writes typed cells
through `replace' with the value already resolved; nothing it writes is passed
to run, do, or macro indirection, and the characters that would make a cell
expand as a macro reference are refused before the write.

Returns (add):
  r(n_sources)   rows in the frame after the append
  r(source_name) the name appended
Returns (list):
  r(n_sources)   rows in the frame
  r(source_names) source names in row order

See help tvspec for complete documentation
*/

capture program drop tvspec
program define tvspec, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    * parse(" ,") so a comma is its own token. With gettoken's default the
    * split is on whitespace alone, so `tvspec create myspec, replace' hands
    * back the seven characters `myspec,' -- comma attached -- and the frame
    * name fails `confirm name' on punctuation the user never typed as part of
    * it. Every gettoken in this file needs it for the same reason.
    gettoken sub 0 : 0, parse(" ,")
    local sub = lower(strtrim("`sub'"))
    if !inlist("`sub'", "create", "add", "list") {
        noisily display as error ///
            "tvspec takes a subcommand: create, add, or list"
        exit 198
    }

    capture noisily tvspec_`sub' `0'
    local _sub_rc = _rc
    return add
    if `_sub_rc' exit `_sub_rc'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end


* ---------------------------------------------------------------------------
* create: the empty frame with the exact typed schema
* ---------------------------------------------------------------------------
* The storage types are the contract. _tvbuild_normalize_spec checks the
* storage CLASS of every column (string vs numeric) and refuses a mismatch with
* r(109), and it reads each cell into a local -- so a str32 column that was
* declared str8 would truncate a legal name to a shorter one that is still a
* legal name, and the plan would be built from it at rc=0. Declaring the widths
* here once, and checking every value against them in `add', is what keeps that
* from being possible.
capture program drop tvspec_create
program define tvspec_create, rclass
    version 16.0
    gettoken specframe 0 : 0, parse(" ,")
    local specframe = strtrim("`specframe'")
    if "`specframe'" == "" {
        noisily display as error "tvspec create requires a frame name"
        exit 198
    }
    confirm name `specframe'
    syntax [, REPlace]

    local _here "`c(frame)'"

    capture confirm frame `specframe'
    if _rc == 0 {
        if "`replace'" == "" {
            noisily display as error ///
                "frame `specframe' already exists; specify replace to overwrite it"
            exit 110
        }
        if "`specframe'" == "`_here'" {
            noisily display as error ///
                "`specframe' is the current frame; tvspec will not replace the frame it is running in"
            exit 198
        }
        frame drop `specframe'
    }

    frame create `specframe'
    frame change `specframe'
    quietly {
        generate str32  source_name     = ""
        generate str12  source_kind     = ""
        generate str32  source_frame    = ""
        generate strL   source_file     = ""
        generate str32  start_var       = ""
        generate str32  stop_var        = ""
        generate strL   input_vars      = ""
        generate strL   output_vars     = ""
        generate double reference       = .
        generate strL   rate_vars       = ""
        generate strL   total_vars      = ""
        generate strL   cumulative_vars = ""
        generate strL   reference_label = ""
        generate strL   variable_label  = ""
        generate strL   description     = ""
    }
    char _dta[tvbuild_spec_version] "1"
    frame change `_here'

    return scalar n_sources = 0
    return local specframe "`specframe'"
end


* ---------------------------------------------------------------------------
* add: append exactly one source row
* ---------------------------------------------------------------------------
capture program drop tvspec_add
program define tvspec_add, rclass
    version 16.0
    gettoken specframe 0 : 0, parse(" ,")
    local specframe = strtrim("`specframe'")
    if "`specframe'" == "" {
        noisily display as error "tvspec add requires a frame name"
        exit 198
    }
    confirm name `specframe'

    syntax , NAMe(name) START(name) STOP(name) ///
        EXPOSure(namelist) GENerate(namelist) ///
        [FRame(name) USing(string asis) REFerence(numlist max=1) ///
         KIND(string) REFERENCELabel(string asis) LABel(string asis) ///
         DESCription(string asis) ///
         RATE(namelist) TOTal(namelist) CUMulative(namelist)]

    * Strip one level of quoting from every asis option exactly once, here, the
    * same way tvbuild does: from this line on each value is a literal.
    local using           `using'
    local referencelabel  `referencelabel'
    local label           `label'
    local description     `description'

    local _here "`c(frame)'"

    **# The frame must already be a specification frame
    capture confirm frame `specframe'
    if _rc {
        noisily display as error "frame `specframe' not found; run tvspec create first"
        exit 111
    }
    frame change `specframe'
    local _schemachar : char _dta[tvbuild_spec_version]
    quietly ds
    local _cols "`r(varlist)'"
    local _nrows = _N
    frame change `_here'

    * Never auto-create. A frame the caller believed already held rows, quietly
    * replaced by an empty one, loses their work with no error to point at --
    * and `add' is the one subcommand whose whole job is to not lose rows.
    if "`_schemachar'" == "" {
        noisily display as error ///
            "frame `specframe' is not a tvbuild specification frame"
        noisily display as error ///
            "run -tvspec create `specframe'- first; tvspec add never creates one"
        exit 198
    }

    * The characteristic says the frame was stamped once. It does not say the
    * frame still has the columns to hold a row. A frame that kept the stamp and
    * lost a column used to fail at the first -replace- below with a bare
    * r(111) naming an internal column the caller never wrote -- an error about
    * tvspec's implementation rather than about their frame. Name the missing
    * columns instead, and say how to get them back.
    *
    * This is checked, not left to the read-back guard further down: that guard
    * only fires when every write SUCCEEDS and a value comes back altered, so a
    * missing column never reaches it.
    local _missing ""
    foreach _c in source_name source_kind source_frame source_file ///
        start_var stop_var input_vars output_vars reference ///
        rate_vars total_vars cumulative_vars reference_label ///
        variable_label description {
        local _has : list posof "`_c'" in _cols
        if `_has' == 0 local _missing "`_missing' `_c'"
    }
    if "`_missing'" != "" {
        noisily display as error ///
            "frame `specframe' carries the specification stamp but is missing column(s):`_missing'"
        noisily display as error ///
            "rebuild it with -tvspec create `specframe', replace-"
        exit 198
    }

    **# Locator: exactly one
    local _n_loc = ("`frame'" != "") + (`"`using'"' != "")
    if `_n_loc' != 1 {
        noisily display as error ///
            "specify exactly one of frame() and using()"
        exit 198
    }

    **# kind
    if "`kind'" == "" local kind "episodes"
    local kind = lower(strtrim("`kind'"))
    * Validated against the same vocabulary _tvbuild_normalize_spec accepts, so
    * a typo is caught here naming the option the user typed rather than later
    * naming a specification row and a column they never wrote.
    if !inlist("`kind'", "episodes", "intervals") {
        noisily display as error ///
            "kind() accepts episodes or intervals, not '`kind''"
        exit 198
    }

    **# The position-by-position mapping
    local _n_in : word count `exposure'
    local _n_out : word count `generate'
    if `_n_in' != `_n_out' {
        noisily display as error ///
            "exposure() names `_n_in' variable(s) and generate() names `_n_out'"
        noisily display as error ///
            "they are mapped position by position and must have the same count"
        exit 198
    }

    **# Cells are data: refuse what would expand as a macro reference
    * char() rather than a literal, so the test cannot be undone by its own
    * quoting. Same reasoning as _tvbuild_normalize_spec's cell screen -- this
    * one just catches it a step earlier, at the call rather than at the build.
    foreach _o in name using referencelabel label description exposure generate ///
        start stop rate total cumulative frame {
        if strpos(`"``_o''"', char(96)) | strpos(`"``_o''"', char(36)) | ///
           strpos(`"``_o''"', char(34)) {
            noisily display as error ///
                "`_o'() contains a backtick, dollar sign, or double quote"
            noisily display as error ///
                "specification cells are data; those characters would be expanded as macro references"
            exit 198
        }
    }

    **# reference() and kind() must agree
    * _tvbuild_normalize_spec is the authority on this rule and applies it to
    * the frame however the frame was built; this is a deliberate early copy of
    * the two most common mistakes, worded against the option the caller typed
    * rather than against a row and a column they never wrote. It is the only
    * plan rule duplicated here, and it is row-local -- no cross-row rule is.
    if "`kind'" == "episodes" & "`reference'" == "" {
        noisily display as error ///
            "an episodes source requires reference(); it is the category that fills uncovered time"
        exit 198
    }
    if "`kind'" == "intervals" & "`reference'" != "" {
        noisily display as error ///
            "an intervals source takes no reference(); it is already constructed"
        exit 198
    }
    if "`kind'" == "intervals" & `"`referencelabel'`label'"' != "" {
        noisily display as error ///
            "referencelabel() and label() describe an episodes source only"
        exit 198
    }

    **# Every value must fit its column exactly
    * A cell that cannot be stored exactly is an error, never a truncation. A
    * truncated source_name is still a legal Stata name, so the build would
    * succeed against a source the caller never described.
    local _toolong ""
    if strlen("`name'")   > 32 local _toolong "`_toolong' name()"
    if strlen("`kind'")   > 12 local _toolong "`_toolong' kind()"
    if strlen("`frame'")  > 32 local _toolong "`_toolong' frame()"
    if strlen("`start'")  > 32 local _toolong "`_toolong' start()"
    if strlen("`stop'")   > 32 local _toolong "`_toolong' stop()"
    if "`_toolong'" != "" {
        noisily display as error ///
            "these value(s) are too long for the specification column that holds them:`_toolong'"
        noisily display as error ///
            "source_name, source_frame, start_var and stop_var hold 32 characters; source_kind holds 12"
        exit 198
    }

    **# Append
    frame change `specframe'
    local _row = `_nrows' + 1
    * Row order is semantic: it fixes generated-variable order, merge order,
    * plan display order, and manifest order. add appends and never reorders.
    quietly {
        set obs `_row'
        replace source_name     = "`name'"                             in `_row'
        replace source_kind     = "`kind'"                             in `_row'
        replace source_frame    = "`frame'"                            in `_row'
        replace source_file     = `"`using'"'                          in `_row'
        replace start_var       = "`start'"                            in `_row'
        replace stop_var        = "`stop'"                             in `_row'
        replace input_vars      = strtrim(stritrim("`exposure'"))      in `_row'
        replace output_vars     = strtrim(stritrim("`generate'"))      in `_row'
        replace rate_vars       = strtrim(stritrim("`rate'"))          in `_row'
        replace total_vars      = strtrim(stritrim("`total'"))         in `_row'
        replace cumulative_vars = strtrim(stritrim("`cumulative'"))    in `_row'
        replace reference_label = `"`referencelabel'"'                 in `_row'
        replace variable_label  = `"`label'"'                          in `_row'
        replace description     = `"`description'"'                    in `_row'
        if "`reference'" != "" replace reference = `reference' in `_row'
    }

    **# Verify the cell survived the write
    * The width checks above say the value fits; this says it landed. A column
    * declared narrower than intended, or a value altered by the storage type,
    * fails here rather than at build time against a source nobody described.
    local _stored_name = source_name[`_row']
    local _stored_start = start_var[`_row']
    local _stored_stop = stop_var[`_row']
    local _stored_in = input_vars[`_row']
    local _stored_out = output_vars[`_row']
    frame change `_here'

    if "`_stored_name'" != "`name'" | "`_stored_start'" != "`start'" | ///
       "`_stored_stop'" != "`stop'" | ///
       "`_stored_in'" != "`=strtrim(stritrim("`exposure'"))'" | ///
       "`_stored_out'" != "`=strtrim(stritrim("`generate'"))'" {
        noisily display as error ///
            "tvspec: the appended row does not read back as it was written"
        noisily display as error ///
            "frame `specframe' may not have the specification schema tvspec create declares"
        exit 459
    }

    return scalar n_sources = `_row'
    return local source_name "`name'"
    return local specframe "`specframe'"
end


* ---------------------------------------------------------------------------
* list: render the frame readably
* ---------------------------------------------------------------------------
capture program drop tvspec_list
program define tvspec_list, rclass
    version 16.0
    gettoken specframe 0 : 0, parse(" ,")
    local specframe = strtrim("`specframe'")
    if "`specframe'" == "" {
        noisily display as error "tvspec list requires a frame name"
        exit 198
    }
    confirm name `specframe'
    syntax

    local _here "`c(frame)'"

    capture confirm frame `specframe'
    if _rc {
        noisily display as error "frame `specframe' not found"
        exit 111
    }
    frame change `specframe'
    local _schemachar : char _dta[tvbuild_spec_version]
    local _nrows = _N
    frame change `_here'

    if "`_schemachar'" == "" {
        noisily display as error ///
            "frame `specframe' is not a tvbuild specification frame"
        exit 198
    }

    noisily display as text ""
    noisily display as text "{bf:tvbuild specification: `specframe'}"
    noisily _tvtools_rule
    if `_nrows' == 0 {
        noisily display as text "  (no sources yet; add one with tvspec add)"
        noisily _tvtools_rule
        return scalar n_sources = 0
        return local source_names ""
        return local specframe "`specframe'"
        exit
    }

    local _names ""
    forvalues i = 1/`_nrows' {
        frame change `specframe'
        local _nm   = source_name[`i']
        local _kd   = source_kind[`i']
        local _fr   = source_frame[`i']
        local _fi   = source_file[`i']
        local _sv   = start_var[`i']
        local _pv   = stop_var[`i']
        local _iv   = input_vars[`i']
        local _ov   = output_vars[`i']
        local _rf   = reference[`i']
        local _rl   = reference_label[`i']
        local _vl   = variable_label[`i']
        local _de   = description[`i']
        local _rv   = rate_vars[`i']
        local _tv   = total_vars[`i']
        local _cv   = cumulative_vars[`i']
        local _rmis = missing(reference[`i'])
        frame change `_here'

        local _loc "`_fr'"
        local _lockind "frame"
        if "`_fr'" == "" {
            local _loc `"`_fi'"'
            local _lockind "file"
        }

        noisily _tvtools_row "source `i'", value(`"`_nm'"') note("(`_kd', `_lockind')")
        noisily _tvtools_row "locator", value(`"`_loc'"')
        noisily _tvtools_row "interval bounds", value(`"`_sv' `_pv'"')
        noisily _tvtools_row "mapping", value(`"`_iv' -> `_ov'"')
        if !`_rmis' {
            noisily _tvtools_row "reference", num(`_rf') fmt(%14.0g)
        }
        if `"`_rl'"' != "" {
            noisily _tvtools_row "reference label", value(`"`_rl'"')
        }
        if `"`_vl'"' != "" {
            noisily _tvtools_row "variable label", value(`"`_vl'"')
        }
        if "`_rv'" != "" {
            noisily _tvtools_row "rate vars", value(`"`_rv'"')
        }
        if "`_tv'" != "" {
            noisily _tvtools_row "total vars", value(`"`_tv'"')
        }
        if "`_cv'" != "" {
            noisily _tvtools_row "cumulative vars", value(`"`_cv'"')
        }
        if `"`_de'"' != "" {
            noisily _tvtools_row "description", value(`"`_de'"')
        }
        noisily _tvtools_rule
        local _names "`_names' `_nm'"
    }

    noisily display as text "  Build it with:"
    noisily display as text "    . " as result ///
        "tvbuild, specframe(`specframe') id(idvar) entry(entryvar) exit(exitvar) frameout(result)"

    return scalar n_sources = `_nrows'
    return local source_names = strtrim(stritrim("`_names'"))
    return local specframe "`specframe'"
end

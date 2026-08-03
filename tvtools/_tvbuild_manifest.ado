*! _tvbuild_manifest Version 1.13.0  2026/08/02
*! Build tvbuild's deterministic per-stage provenance manifest
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* One row per executed stage, in execution order: the master, each source, the
* merge when there was one, the event stage when there was one, and the output.
* The manifest is a record of what ran, not a second copy of the plan -- every
* count in it comes from the stage that produced it, and it is built only after
* the result has been finalised and signed.
*
* `options' is provenance text. It is a canonical rendering of the settings
* each stage ran under so a reader can reconstruct the call; it is never
* evaluated as code, and nothing downstream parses it back into options.
*
* A failed manifest is never committed. The manifest frame is built in scratch
* alongside the result and the two are committed as one transaction, so a user
* cannot end up with a result whose provenance describes a different run.
*
* Returns:
*   r(n_stages)  rows written

capture program drop _tvbuild_manifest
program define _tvbuild_manifest, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , MANframe(name) PLANframe(name) ///
        NPERSons(string) NMASTERrows(string) ///
        NOUT(string) NOUTPERSons(string) SIGnature(string) ///
        COVerage(string) UNCOVEREDdays(string) ///
        SRCOUTRows(string) MERGEIn(string) MERGEOut(string) ///
        [EVENTIn(string) EVENTOut(string) EVENTName(string) ///
         EVENTKind(string) QMAP(string) MERGED(integer 0) EVENTStage(integer 0)]

    capture frame drop `manframe'
    frame create `manframe'
    frame change `manframe'
    quietly {
        generate long   stage_index     = .
        generate str12  stage           = ""
        generate long   source_index    = .
        generate str32  source_name     = ""
        generate str12  source_kind     = ""
        generate str8   input_kind      = ""
        generate strL   input_locator   = ""
        generate strL   input_vars      = ""
        generate strL   output_vars     = ""
        generate strL   quantity_map    = ""
        generate strL   options         = ""
        generate str32  engine          = ""
        generate double n_input         = .
        generate double n_output        = .
        generate double n_persons       = .
        generate double n_unmatched_ids = .
        generate double n_outside_window = .
        generate double uncovered_days  = .
        generate str8   status          = ""
        generate strL   data_signature  = ""
        generate strL   description     = ""
    }
    * The mark that makes this frame identifiable as tvbuild's own manifest.
    * It exists so that _tvbuild_check_dest can tell a manifest tvbuild wrote
    * from a frame the caller happens to own at the same name: a name tvbuild
    * DERIVED may be replaced when it holds tvbuild's own prior manifest, and
    * may never be touched otherwise. Without the mark those two are
    * indistinguishable and the safe rule has to refuse both, which makes every
    * repeat run of the same call fail.
    char _dta[tvtools_manifest] "tvbuild"
    frame change `_caller_frame'

    frame change `planframe'
    local _nsrc = _N
    frame change `_caller_frame'

    local _row = 0

    **# master
    local ++_row
    _tvbuild_manifest_put, manframe(`manframe') row(`_row') ///
        stage(master) inputkind(internal) engine(tvbuild_master) ///
        ninput(`nmasterrows') noutput(`nmasterrows') npersons(`npersons') ///
        options("coverage(`coverage')") ///
        description("Person-level master validated and crosswalked")

    **# one row per source
    forvalues i = 1/`_nsrc' {
        frame change `planframe'
        local _nm = source_name[`i']
        local _kd = source_kind[`i']
        local _ik = input_kind[`i']
        local _lo = source_frame[`i']
        if "`_ik'" == "file" local _lo = resolved_file[`i']
        local _iv = input_vars[`i']
        local _ov = output_vars[`i']
        local _en = engine[`i']
        local _ni = N_input[`i']
        local _np = N_persons[`i']
        local _nu = N_unmatched_ids[`i']
        local _no = N_outside_window[`i']
        local _rv = rate_vars[`i']
        local _tv = total_vars[`i']
        local _cv = cumulative_vars[`i']
        local _ref = reference[`i']
        local _de = description[`i']
        frame change `_caller_frame'

        local _qm ""
        if "`_rv'" != "" local _qm "`_qm' rate(`_rv')"
        if "`_tv'" != "" local _qm "`_qm' total(`_tv')"
        if "`_cv'" != "" local _qm "`_qm' cumulative(`_cv')"
        local _op ""
        if "`_kd'" == "episodes" local _op "reference(`_ref')"

        local _srows : word `i' of `srcoutrows'
        local ++_row
        _tvbuild_manifest_put, manframe(`manframe') row(`_row') ///
            stage(source) sourceindex(`i') sourcename(`"`_nm'"') ///
            sourcekind(`_kd') inputkind(`_ik') locator(`"`_lo'"') ///
            inputvars(`"`_iv'"') outputvars(`"`_ov'"') ///
            quantitymap(`"`_qm'"') options(`"`_op'"') engine(`_en') ///
            ninput(`_ni') noutput(`_srows') npersons(`_np') ///
            nunmatched(`_nu') noutside(`_no') ///
            description(`"`_de'"')
    }

    **# merge
    if `merged' {
        local ++_row
        _tvbuild_manifest_put, manframe(`manframe') row(`_row') ///
            stage(merge) inputkind(internal) engine(tvmerge_intervals) ///
            ninput(`mergein') noutput(`mergeout') npersons(`noutpersons') ///
            uncovered(`uncovereddays') options("coverage(`coverage')") ///
            quantitymap(`"`qmap'"') ///
            description("Sequential interval alignment in specification order")
    }

    **# event
    if `eventstage' {
        local ++_row
        _tvbuild_manifest_put, manframe(`manframe') row(`_row') ///
            stage(event) inputkind(`eventkind') engine(tvevent_segments) ///
            ninput(`eventin') noutput(`eventout') npersons(`noutpersons') ///
            outputvars(`"`eventname'"') quantitymap(`"`qmap'"') ///
            description("Event integration into the constructed intervals")
    }

    **# output
    local ++_row
    _tvbuild_manifest_put, manframe(`manframe') row(`_row') ///
        stage(output) inputkind(internal) engine(tvbuild_commit) ///
        ninput(`nout') noutput(`nout') npersons(`noutpersons') ///
        signature(`"`signature'"') options("coverage(`coverage')") ///
        description("Finalised, signed, and committed result")

    return scalar n_stages = `_row'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end


* Write one manifest row. Everything arrives as an explicit option so a stage
* that has no source index, no locator, or no signature leaves those cells
* missing rather than inheriting the previous row's.
capture program drop _tvbuild_manifest_put
program define _tvbuild_manifest_put
    version 16.0
    syntax , MANframe(name) ROW(integer) STAGE(string) ///
        [SOURCEIndex(string) SOURCEName(string) SOURCEKind(string) ///
         INPUTKind(string) LOCator(string) INPUTVars(string) ///
         OUTPUTVars(string) QUANTITYmap(string) OPTions(string) ///
         ENGine(string) NINput(string) NOUTput(string) NPERSons(string) ///
         NUNmatched(string) NOUTSide(string) UNCOVered(string) ///
         SIGnature(string) DESCription(string)]

    local _here "`c(frame)'"
    foreach n in sourceindex ninput noutput npersons nunmatched noutside uncovered {
        if "``n''" == "" local `n' "."
    }

    frame change `manframe'
    quietly {
        set obs `row'
        replace stage_index      = `row'                          in `row'
        replace stage            = "`stage'"                      in `row'
        replace source_index     = `sourceindex'                  in `row'
        replace source_name      = `"`sourcename'"'               in `row'
        replace source_kind      = "`sourcekind'"                 in `row'
        replace input_kind       = "`inputkind'"                  in `row'
        replace input_locator    = `"`locator'"'                  in `row'
        replace input_vars       = strtrim(stritrim(`"`inputvars'"'))   in `row'
        replace output_vars      = strtrim(stritrim(`"`outputvars'"'))  in `row'
        replace quantity_map     = strtrim(stritrim(`"`quantitymap'"')) in `row'
        replace options          = strtrim(stritrim(`"`options'"'))     in `row'
        replace engine           = "`engine'"                     in `row'
        replace n_input          = `ninput'                       in `row'
        replace n_output         = `noutput'                      in `row'
        replace n_persons        = `npersons'                     in `row'
        replace n_unmatched_ids  = `nunmatched'                   in `row'
        replace n_outside_window = `noutside'                     in `row'
        replace uncovered_days   = `uncovered'                    in `row'
        replace status           = "ok"                           in `row'
        replace data_signature   = `"`signature'"'                in `row'
        replace description      = `"`description'"'              in `row'
    }
    frame change `_here'
end

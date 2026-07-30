*! tvpipe Version 1.10.1  2026/07/30
*! Build a committed, analysis-ready interval frame from a cohort and sources
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
tvpipe is the front door for turning a person-level cohort plus one or more
longitudinal sources into a committed interval frame. It composes exposure
construction, interval alignment, optional event integration, structural
validation, and provenance.

It is a coordinator, not a fourth implementation of interval semantics. It
does NOT run tvdiagnose, tvweight, stset, or an outcome model, and it does not
choose an overlap-resolution rule, weighting specification, truncation
threshold, time scale, estimand, or causal model. Those stay visible and
scriptable.

Canonical multi-source form:
  tvpipe, specframe(pipe_spec) id(id) entry(study_entry) exit(study_exit) ///
      frameout(analysis) [options]

One-source categorical shortcut:
  tvpipe, {sourceframe(name)|sourceusing(filename)} id(id) ///
      entry(study_entry) exit(study_exit) ///
      start(ep_start) stop(ep_stop) exposure(ep_class) reference(#) ///
      generate(tv_exposure) frameout(analysis) [options]

The current frame is the person-level master. Select another one idiomatically
with the `frame master:' prefix; there is no separate master-file parser.

Architecture. tvpipe owns the public contract, the normalised plan, the
read-only preflight, the committed schema, the transaction, and the return
surface. It owns none of the interval semantics: raw categorical episodes are
tiled by the shared tvexpose constructor, several sources are aligned by the
shared tvmerge interval engine, and events are placed by the shared tvevent
engine. Every stage runs in a scratch frame, so the caller's data, the
specification frame, and every input frame are read and never written.
*/

capture program drop tvpipe
program define tvpipe, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    * Cleanup state is initialised before the captured block so that a failure
    * anywhere inside it -- including one that strands Stata in a scratch frame
    * -- still finds a complete list of what to drop. Scratch frame names are
    * appended to _tvp_frames BEFORE the frame is created, never after: a name
    * recorded after creation is a name lost to the error between the two.
    tempname _plan _xwalk _work _evscratch
    tempname _void _mw _acc _evout _man
    local _tvp_frames ""

    capture noisily {

    **# ---------------------------------------------------------------------
    **# Public syntax
    **# ---------------------------------------------------------------------
    syntax , ID(varname) ENTry(varname) EXIt(varname) FRAMEOut(name) ///
        [SPECframe(name) ///
         SOURCEFrame(name) SOURCEUsing(string asis) SOURCEName(name) ///
         START(name) STOP(name) EXPOSure(name) ///
         REFerence(numlist max=1) GENerate(name) ///
         REFERENCELabel(string asis) LABel(string asis) ///
         STARTName(name) STOPName(name) DATEFormat(string) ///
         KEEPvars(varlist) DROPdates COVerage(string) ///
         EVENTFrame(name) EVENTUsing(string asis) ///
         EVENTDate(name) EVENTType(string) COMpete(namelist) ///
         EVENTGenerate(name) EVENTLabel(string asis) ///
         TIMEGen(name) TIMEUnit(string) ///
         ENUM(name) GAPTime GAPSTArt(name) GAPSTOp(name) ///
         MANIFESTframe(name) DRYrun REPlace]

    * The five asis options are parsed asis so a value containing spaces or
    * quotes survives the public parser exactly as typed. Strip that quoting
    * ONCE, here: `local x `x'' removes one level if there is one and leaves a
    * bare value alone. From this line on every internal value is a literal,
    * and every helper option that receives one is declared plain `string' --
    * which strips the compound quotes the value is forwarded in. Mixing the
    * two conventions is how an absent option arrives as the two-character
    * string `""' and a present one arrives with its own quotes still attached.
    local sourceusing    `sourceusing'
    local eventusing     `eventusing'
    local referencelabel `referencelabel'
    local label          `label'
    local eventlabel     `eventlabel'

    **# ---------------------------------------------------------------------
    **# Mode selection and mutual exclusions
    **# ---------------------------------------------------------------------
    local _inline_opts sourceframe sourceusing sourcename start stop ///
        exposure reference generate referencelabel label
    local _inline_used ""
    foreach o of local _inline_opts {
        if `"``o''"' != "" local _inline_used "`_inline_used' `o'"
    }

    if "`specframe'" != "" & "`_inline_used'" != "" {
        noisily display as error ///
            "specframe() describes every source; it may not be combined with the inline source options"
        noisily display as error "conflicting option(s):`_inline_used'"
        exit 198
    }
    if "`specframe'" == "" & "`_inline_used'" == "" {
        noisily display as error ///
            "specify either specframe() or the inline one-source options"
        exit 198
    }

    if "`specframe'" != "" {
        capture confirm frame `specframe'
        if _rc {
            noisily display as error "specframe(`specframe') not found"
            exit 111
        }
    }
    else {
        local _n_loc = ("`sourceframe'" != "") + (`"`sourceusing'"' != "")
        if `_n_loc' != 1 {
            noisily display as error ///
                "the inline form requires exactly one of sourceframe() and sourceusing()"
            exit 198
        }
        foreach o in start stop exposure generate {
            if "``o''" == "" {
                noisily display as error ///
                    "the inline form requires `o'(); it describes one categorical episode source"
                exit 198
            }
        }
        if "`reference'" == "" {
            noisily display as error ///
                "the inline form requires reference(); it is the category that fills uncovered time"
            exit 198
        }
    }

    **# ---------------------------------------------------------------------
    **# Option defaults and validation
    **# ---------------------------------------------------------------------
    if "`startname'" == "" local startname "start"
    if "`stopname'"  == "" local stopname  "stop"
    if "`coverage'"  == "" local coverage  "strict"
    if "`eventtype'" == "" & "`eventdate'" != "" local eventtype "single"
    if "`timeunit'"  == "" & "`timegen'"   != "" local timeunit "days"
    if "`dateformat'" == "" local dateformat "%tdCCYY/NN/DD"

    if !inlist("`coverage'", "strict", "allow") {
        noisily display as error ///
            "coverage() accepts strict or allow, not '`coverage''"
        exit 198
    }


    **# Event-option dependencies
    if "`eventdate'" == "" {
        local _evopts eventframe eventusing eventtype compete ///
            eventgenerate eventlabel timegen timeunit enum gaptime ///
            gapstart gapstop
        local _evused ""
        foreach o of local _evopts {
            if `"``o''"' != "" local _evused "`_evused' `o'"
        }
        if "`_evused'" != "" {
            noisily display as error ///
                "eventdate() activates the event stage; these options require it:`_evused'"
            exit 198
        }
    }
    else {
        if "`eventframe'" != "" & `"`eventusing'"' != "" {
            noisily display as error ///
                "eventframe() and eventusing() are mutually exclusive"
            exit 198
        }
        if !inlist("`eventtype'", "single", "recurring") {
            noisily display as error ///
                "eventtype() accepts single or recurring, not '`eventtype''"
            exit 198
        }
        if "`eventgenerate'" == "" local eventgenerate "_failure"
        if "`eventtype'" == "single" {
            local _recopts enum gaptime gapstart gapstop
            local _recused ""
            foreach o of local _recopts {
                if "``o''" != "" local _recused "`_recused' `o'"
            }
            if "`_recused'" != "" {
                noisily display as error ///
                    "these options describe eventtype(recurring):`_recused'"
                exit 198
            }
        }
        else if "`compete'" != "" {
            noisily display as error ///
                "compete() is allowed with eventtype(single) only"
            exit 198
        }
        if "`timeunit'" != "" & "`timegen'" == "" {
            noisily display as error "timeunit() requires timegen()"
            exit 198
        }
        if "`timegen'" != "" & !inlist("`timeunit'", "days", "months", "years") {
            noisily display as error ///
                "timeunit() accepts days, months, or years, not '`timeunit''"
            exit 198
        }
        if ("`gapstart'" != "" | "`gapstop'" != "") & "`gaptime'" == "" {
            noisily display as error "gapstart() and gapstop() require gaptime"
            exit 198
        }
        if "`gaptime'" != "" {
            if "`gapstart'" == "" local gapstart "_t0"
            if "`gapstop'"  == "" local gapstop  "_t"
        }
    }

    **# ---------------------------------------------------------------------
    **# Normalise both input forms into one internal plan frame
    **# ---------------------------------------------------------------------
    local _tvp_frames "`_tvp_frames' `_plan'"
    capture frame drop `_plan'
    frame create `_plan'

    * dateformat() is probed inside the plan frame, not the caller's. The
    * obvious `tempvar' probe would create and drop a variable in the master --
    * momentary, invisible, and still a write to a frame this command promises
    * never to touch.
    frame change `_plan'
    quietly set obs 1
    quietly generate double _tvp_fmtprobe = 22000
    capture format _tvp_fmtprobe `dateformat'
    local _fmtrc = _rc
    * `clear' empties the current frame only. Dropping the probe variable and
    * then the observation does not work: removing the last variable already
    * takes the observations with it, and the `drop in 1' that follows is out
    * of range.
    quietly clear
    frame change `_caller_frame'
    if `_fmtrc' {
        noisily display as error ///
            "dateformat(`dateformat') is not a valid Stata date format"
        exit 198
    }

    * Options whose argument class is `name' cannot be passed empty -- an
    * empty name(...) is a syntax error, not an absent option -- so the
    * present ones are assembled into one macro instead.
    local _nsopts ""
    foreach o in specframe sourceframe sourcename start stop exposure generate {
        if "``o''" != "" local _nsopts `"`_nsopts' `o'(``o'')"'
    }
    _tvpipe_normalize_spec, planframe(`_plan') `_nsopts' ///
        sourceusing(`"`sourceusing'"') reference(`reference') ///
        referencelabel(`"`referencelabel'"') label(`"`label'"')

    local n_sources    = r(n_sources)
    local spec_version = r(spec_version)
    local source_names "`r(source_names)'"
    local payload_vars "`r(output_vars)'"

    **# ---------------------------------------------------------------------
    **# Resolve the complete public output-name set before any source is read
    **# ---------------------------------------------------------------------
    * Order is the committed order of Section 12.4. Resolving it here, before
    * a source is opened, is what makes a name collision a preflight refusal
    * rather than a half-built result.
    local _out_names "`id'"
    if "`dropdates'" == "" local _out_names "`_out_names' `entry' `exit'"
    local _out_names "`_out_names' `startname' `stopname'"
    local _out_names "`_out_names' `payload_vars'"
    local _out_names "`_out_names' `keepvars'"
    if "`eventdate'" != "" {
        local _out_names "`_out_names' `eventgenerate'"
        if "`timegen'"  != "" local _out_names "`_out_names' `timegen'"
        if "`enum'"     != "" local _out_names "`_out_names' `enum'"
        if "`gaptime'"  != "" local _out_names "`_out_names' `gapstart' `gapstop'"
    }

    foreach n of local _out_names {
        capture confirm name `n'
        if _rc | strlen("`n'") > 32 {
            noisily display as error ///
                "'`n'' is not a legal Stata variable name for the output schema"
            exit 198
        }
    }
    local _dups : list dups _out_names
    if "`_dups'" != "" {
        noisily display as error ///
            "the output schema would need the same name twice:`_dups'"
        noisily display as error ///
            "rename the colliding source output, keepvar, or event variable"
        exit 198
    }

    * Input roles are protected. An event date, a competing-risk date, or a
    * recurring stub member is an input, and reusing its name for an output
    * would overwrite the value the event stage still has to read. replace
    * authorises replacing a destination frame; it never waives this.
    local _protected ""
    if "`eventdate'" != "" {
        local _protected "`eventdate' `compete'"
        local _clash : list _out_names & _protected
        if "`_clash'" != "" {
            noisily display as error ///
                "these output names would overwrite an event input role:`_clash'"
            exit 198
        }
    }

    * Count the planned schema before building anything. Propagating Stata's
    * own no-room error is the contract; tvpipe never changes set maxvar.
    local _n_planned : word count `_out_names'
    if `_n_planned' > c(maxvar) {
        noisily display as error ///
            "the planned output has `_n_planned' variables; this Stata allows c(maxvar)=`c(maxvar)'"
        noisily display as error ///
            "raise it yourself with -set maxvar-; tvpipe does not change your session limits"
        exit 901
    }

    **# ---------------------------------------------------------------------
    **# Destination ownership
    **# ---------------------------------------------------------------------
    local _destopts ""
    foreach o in manifestframe specframe eventframe {
        if "``o''" != "" local _destopts "`_destopts' `o'(``o'')"
    }
    _tvpipe_check_dest, frameout(`frameout') callerframe(`_caller_frame') ///
        planframe(`_plan') `_destopts' `replace'
    local frameout_exists = r(frameout_exists)
    local manifest_exists = r(manifest_exists)
    **# ---------------------------------------------------------------------
    **# Internal name stub
    **# ---------------------------------------------------------------------
    * Several internal columns have to exist alongside the user's own: one
    * start/stop pair per normalised source, and the study bounds the coverage
    * union is measured against. They are chosen so that NO planned public name
    * begins with the stub, which makes a collision impossible rather than
    * unlikely -- a user may legally name a variable _tvp_s1, and a stub picked
    * by hope would then be renamed on top of their data.
    local _protected_all "`_out_names' `id' `entry' `exit' `eventdate' `compete'"
    local _stub "_tvp_"
    local _k = 0
    local _clash = 1
    while `_clash' {
        local _clash = 0
        local _sl = strlen("`_stub'")
        foreach n of local _protected_all {
            if substr("`n'", 1, `_sl') == "`_stub'" local _clash = 1
        }
        if `_clash' {
            local ++_k
            local _stub "_tvp`_k'_"
        }
    }

    **# ---------------------------------------------------------------------
    **# Preflight
    **# ---------------------------------------------------------------------
    * One scratch frame name per source, recorded before any of them is
    * created, plus the crosswalk, the reusable work frame, and the event
    * scratch. The preflight never invents a name of its own.
    local _srcframes ""
    local _normframes ""
    forvalues i = 1/`n_sources' {
        tempname _sf`i' _nf`i'
        local _tvp_frames "`_tvp_frames' `_sf`i'' `_nf`i''"
        local _srcframes "`_srcframes' `_sf`i''"
        local _normframes "`_normframes' `_nf`i''"
    }
    local _tvp_frames "`_tvp_frames' `_xwalk' `_work' `_evscratch'"
    local _tvp_frames "`_tvp_frames' `_void' `_mw' `_acc' `_evout' `_man'"

    local _pfevopts ""
    foreach o in eventframe eventdate {
        if "``o''" != "" local _pfevopts "`_pfevopts' `o'(``o'')"
    }
    _tvpipe_preflight, planframe(`_plan') masterframe(`_caller_frame') ///
        xwalkframe(`_xwalk') workframe(`_work') srcframes(`_srcframes') ///
        id(`id') entry(`entry') exit(`exit') keepvars(`keepvars') ///
        coverage(`coverage') `_pfevopts' ///
        eventusing(`"`eventusing'"') eventscratch(`_evscratch') ///
        eventtype(`eventtype') compete(`compete')

    local N_persons     = r(N_persons)
    local n_files       = r(n_files)
    local event_input   "`r(event_input)'"
    local event_frame   "`r(event_frame)'"
    local n_gap_ids     = r(n_gap_ids)
    local uncovered_days = r(uncovered_days)
    local masteridtype  "`r(masteridtype)'"

    **# ---------------------------------------------------------------------
    **# Payload classification
    **# ---------------------------------------------------------------------
    * An output is a quantity when its specification row declared it one, and
    * categorical otherwise; the three quantity locals and exposure_out
    * partition payload_vars exactly. The classification is needed by the merge
    * and event engines, not only by the return surface, so it happens before
    * either of them runs.
    local rate_out ""
    local total_out ""
    local cum_out ""
    local _srcvargroups ""
    frame change `_plan'
    forvalues i = 1/`n_sources' {
        local _iv = input_vars[`i']
        local _ov = output_vars[`i']
        local _rv = rate_vars[`i']
        local _tv = total_vars[`i']
        local _cv = cumulative_vars[`i']
        local _p = 0
        foreach v of local _iv {
            local ++_p
            local _o : word `_p' of `_ov'
            local _is : list v in _rv
            if `_is' local rate_out "`rate_out' `_o'"
            local _is : list v in _tv
            if `_is' local total_out "`total_out' `_o'"
            local _is : list v in _cv
            if `_is' local cum_out "`cum_out' `_o'"
        }
        if `i' > 1 local _srcvargroups `"`_srcvargroups',"'
        local _srcvargroups `"`_srcvargroups' `_ov'"'
    }
    frame change `_caller_frame'
    local _quant "`rate_out' `total_out' `cum_out'"
    local exposure_out : list payload_vars - _quant

    **# ---------------------------------------------------------------------
    **# Plan display
    **# ---------------------------------------------------------------------
    local _showopts ""
    foreach o in eventgenerate manifestframe {
        if "``o''" != "" local _showopts "`_showopts' `o'(``o'')"
    }
    local _dropdates01 = ("`dropdates'" != "")
    _tvpipe_show_plan, planframe(`_plan') ///
        id(`id') entry(`entry') exit(`exit') ///
        startname(`startname') stopname(`stopname') ///
        frameout(`frameout') coverage(`coverage') ///
        npersons(`N_persons') nfiles(`n_files') ///
        eventinput(`event_input') `_showopts' ///
        frameoutexists(`frameout_exists') manifestexists(`manifest_exists') ///
        keepvars(`keepvars') dropdates(`_dropdates01') ///
        `dryrun'

    **# ---------------------------------------------------------------------
    **# Source counts matrix (both modes)
    **# ---------------------------------------------------------------------
    * kind is 1 for episodes and 2 for intervals; input is 1 for frame and 2
    * for file. Row names are source1..sourceS because a matrix row name
    * truncates at 32 characters and would silently mangle a long logical
    * name; r(source_names) carries the untruncated mapping.
    tempname _srccounts
    matrix `_srccounts' = J(`n_sources', 6, .)
    local _rownames ""
    frame change `_plan'
    forvalues i = 1/`n_sources' {
        matrix `_srccounts'[`i', 1] = N_input[`i']
        matrix `_srccounts'[`i', 2] = N_persons[`i']
        matrix `_srccounts'[`i', 3] = N_unmatched_ids[`i']
        matrix `_srccounts'[`i', 4] = N_outside_window[`i']
        matrix `_srccounts'[`i', 5] = cond(source_kind[`i'] == "episodes", 1, 2)
        matrix `_srccounts'[`i', 6] = cond(input_kind[`i'] == "frame", 1, 2)
    }
    frame change `_caller_frame'
    forvalues i = 1/`n_sources' {
        local _rownames "`_rownames' source`i'"
    }
    matrix colnames `_srccounts' = N_rows N_persons N_unmatched_ids ///
        N_outside_window kind input
    matrix rownames `_srccounts' = `_rownames'

    **# ---------------------------------------------------------------------
    **# Construction, merge, events, and commit
    **# ---------------------------------------------------------------------
    if "`dryrun'" == "" {

        * The master-window table. It is built once per run and shared by every
        * episodes source: the shared constructor takes its per-person study
        * bounds as a file, and re-deriving them per source would be the same
        * work repeated.
        frame change `_plan'
        quietly count if source_kind == "episodes"
        local _n_epi_src = r(N)
        frame change `_caller_frame'
        tempfile _mwfile
        if `_n_epi_src' > 0 {
            capture frame drop `_mw'
            frame `_xwalk': frame put `id' `entry' `exit', into(`_mw')
            frame change `_mw'
            * Two-step rename: a one-step rename breaks whenever a caller's own
            * name is one of the three names being created (entry() called id,
            * id() called study_entry, and so on).
            quietly rename (`id' `entry' `exit') ///
                (`_stub'mid `_stub'men `_stub'mex)
            quietly rename (`_stub'mid `_stub'men `_stub'mex) ///
                (id study_entry study_exit)
            quietly save `"`_mwfile'"', replace
            frame change `_caller_frame'
        }

        **# One normalised interval frame per source
        local _snames ""
        local _enames ""
        local _srcoutrows ""
        local _srcoutpers ""
        local _srcuncov ""
        forvalues i = 1/`n_sources' {
            local _nfi : word `i' of `_normframes'
            local _sn "`_stub's`i'"
            local _en "`_stub'e`i'"
            local _snames "`_snames' `_sn'"
            local _enames "`_enames' `_en'"
            _tvpipe_build_source, planframe(`_plan') index(`i') ///
                outframe(`_nfi') xwalkframe(`_xwalk') ///
                id(`id') entry(`entry') exit(`exit') ///
                startname(`_sn') stopname(`_en') ///
                idisstr(`=substr("`masteridtype'", 1, 3) == "str"') ///
                masteridtype(`masteridtype') masterwindows(`"`_mwfile'"')
            local _srcoutrows "`_srcoutrows' `=r(N_out)'"
            local _srcoutpers "`_srcoutpers' `=r(N_persons)'"
            frame change `_plan'
            local _srcuncov "`_srcuncov' `=N_uncovered[`i']'"
            frame change `_caller_frame'
        }

        **# Align them
        capture frame drop `_void'
        frame create `_void'
        _tvpipe_combine, srcframes(`_normframes') outframe(`_acc') ///
            voidframe(`_void') xwalkframe(`_xwalk') ///
            id(`id') entry(`entry') exit(`exit') ///
            startname(`startname') stopname(`stopname') ///
            dateformat(`dateformat') stub(`_stub') coverage(`coverage') ///
            snames(`_snames') enames(`_enames') expvars(`payload_vars') ///
            ratevars(`rate_out') totalvars(`total_out') cumvars(`cum_out')
        local merge_in      = r(N_in)
        local merge_out     = r(N_out)
        local merge_persons = r(N_persons)
        local merged        = r(merged)
        local n_gap_ids     = r(n_gap_ids)
        local uncovered_days = r(uncovered_days)

        if "`coverage'" == "allow" & `n_gap_ids' > 0 {
            noisily display as text ""
            noisily display as text ///
                "Warning: coverage(allow) accepted `n_gap_ids' person(s) with " ///
                "`uncovered_days' uncovered day(s)."
            noisily display as text ///
                "         The result does not represent that person-time; " ///
                "analyses on it are restricted accordingly."
        }

        **# Events
        local _resframe "`_acc'"
        local _dropvars ""
        local event_in = .
        local event_out = .
        if "`eventdate'" != "" {
            _tvpipe_event, accframe(`_acc') evsrcframe(`event_frame') ///
                outframe(`_evout') id(`id') eventdate(`eventdate') ///
                startname(`startname') stopname(`stopname') ///
                eventtype(`eventtype') eventgenerate(`eventgenerate') ///
                eventlabel(`"`eventlabel'"') compete(`compete') ///
                timegen(`timegen') timeunit(`timeunit') ///
                enum(`enum') `gaptime' gapstart(`gapstart') gapstop(`gapstop') ///
                ratevars(`rate_out') totalvars(`total_out') cumvars(`cum_out')
            local event_in  = r(N_in)
            local event_out = r(N_out)
            local _dropvars "`r(dropvars)'"
            local _resframe "`_evout'"
        }

        **# Finalise into the committed schema
        _tvpipe_finalize, resframe(`_resframe') xwalkframe(`_xwalk') ///
            masterframe(`_caller_frame') id(`id') entry(`entry') exit(`exit') ///
            startname(`startname') stopname(`stopname') ///
            dateformat(`dateformat') masteridtype(`masteridtype') ///
            schema(`_out_names') coverage(`coverage') ///
            keepvars(`keepvars') dropdates(`_dropdates01') ///
            srcframes(`_normframes') srcvars(`"`_srcvargroups'"') ///
            dropvars(`_dropvars') eventvar(`eventgenerate') ///
            timevar(`timegen') enumvar(`enum') ///
            gapstartvar(`gapstart') gapstopvar(`gapstop')
        local N_periods   = r(N_periods)
        local out_persons = r(N_persons)
        local datasig     "`r(datasignature)'"

        **# Provenance
        if "`manifestframe'" != "" {
            local _mopts ""
            if `"`_quant'"' != "" {
                local _qm ""
                if "`rate_out'"  != "" local _qm "`_qm' rate(`rate_out')"
                if "`total_out'" != "" local _qm "`_qm' total(`total_out')"
                if "`cum_out'"   != "" local _qm "`_qm' cumulative(`cum_out')"
                local _mopts `"qmap(`"`_qm'"')"'
            }
            local _evopts2 ""
            if "`eventdate'" != "" {
                local _evopts2 `"eventin(`event_in') eventout(`event_out') eventname(`eventgenerate') eventkind(`event_input')"'
            }
            _tvpipe_manifest, manframe(`_man') planframe(`_plan') ///
                npersons(`N_persons') nmasterrows(`N_persons') ///
                nout(`N_periods') noutpersons(`out_persons') ///
                signature(`"`datasig'"') coverage(`coverage') ///
                uncovereddays(`uncovered_days') ///
                srcoutrows(`_srcoutrows') mergein(`merge_in') ///
                mergeout(`merge_out') merged(`merged') ///
                eventstage(`=("`eventdate'" != "")') ///
                `_mopts' `_evopts2'
        }

        **# Commit
        local _cmopts ""
        if "`manifestframe'" != "" ///
            local _cmopts "manframe(`_man') manifestframe(`manifestframe')"
        _tvpipe_commit, resframe(`_resframe') frameout(`frameout') ///
            schema(`_out_names') nrows(`N_periods') ///
            signature(`"`datasig'"') `_cmopts' ///
            frameoutexists(`frameout_exists') manifestexists(`manifest_exists')
        local datasig "`r(datasignature)'"

        **# Stage counts
        local _nstage = `n_sources' + `merged' + ("`eventdate'" != "") + 1
        tempname _stagecounts
        matrix `_stagecounts' = J(`_nstage', 5, .)
        local _stagenames ""
        local _r = 0
        frame change `_plan'
        forvalues i = 1/`n_sources' {
            local _ni = N_input[`i']
            local _np = N_persons[`i']
            frame change `_caller_frame'
            local ++_r
            matrix `_stagecounts'[`_r', 1] = `_ni'
            matrix `_stagecounts'[`_r', 2] = `=word("`_srcoutrows'", `i')'
            matrix `_stagecounts'[`_r', 3] = `_np'
            matrix `_stagecounts'[`_r', 4] = `=word("`_srcoutpers'", `i')'
            matrix `_stagecounts'[`_r', 5] = `=word("`_srcuncov'", `i')'
            local _stagenames "`_stagenames' source`i'"
            frame change `_plan'
        }
        frame change `_caller_frame'
        if `merged' {
            local ++_r
            matrix `_stagecounts'[`_r', 1] = `merge_in'
            matrix `_stagecounts'[`_r', 2] = `merge_out'
            matrix `_stagecounts'[`_r', 3] = `N_persons'
            matrix `_stagecounts'[`_r', 4] = `merge_persons'
            matrix `_stagecounts'[`_r', 5] = `uncovered_days'
            local _stagenames "`_stagenames' merge"
        }
        if "`eventdate'" != "" {
            local ++_r
            matrix `_stagecounts'[`_r', 1] = `event_in'
            matrix `_stagecounts'[`_r', 2] = `event_out'
            matrix `_stagecounts'[`_r', 3] = `merge_persons'
            matrix `_stagecounts'[`_r', 4] = `out_persons'
            local _stagenames "`_stagenames' event"
        }
        local ++_r
        matrix `_stagecounts'[`_r', 1] = `N_periods'
        matrix `_stagecounts'[`_r', 2] = `N_periods'
        matrix `_stagecounts'[`_r', 3] = `out_persons'
        matrix `_stagecounts'[`_r', 4] = `out_persons'
        local _stagenames "`_stagenames' output"
        matrix colnames `_stagecounts' = N_in N_out N_persons_in ///
            N_persons_out uncovered_days
        matrix rownames `_stagecounts' = `_stagenames'

        **# Success display
        _tvpipe_show_result, frameout(`frameout') id(`id') ///
            npersons(`out_persons') nperiods(`N_periods') ///
            startname(`startname') stopname(`stopname') ///
            coverage(`coverage') payload(`payload_vars') ///
            ngapids(`n_gap_ids') uncovered(`uncovered_days') ///
            eventvar(`eventgenerate') manifestframe(`manifestframe') ///
            entryvar(`entry') exitvar(`exit') dropdates(`_dropdates01')
    }

    **# ---------------------------------------------------------------------
    **# Returns
    **# ---------------------------------------------------------------------
    * Posted last, after every stage and the commit verification have
    * succeeded. r(source_counts) is issued before r(stage_counts) so that the
    * matrix each one moves is out of tvpipe's hands only after its final use.
    if "`dryrun'" == "" {
        return matrix stage_counts = `_stagecounts'
    }
    return matrix source_counts = `_srccounts'
    if "`dryrun'" == "" {
        return local datasignature "`datasig'"
        return scalar uncovered_days = `uncovered_days'
        return scalar n_gap_ids = `n_gap_ids'
        return scalar N_periods = `N_periods'
    }
    if "`manifestframe'" != "" return local manifestframe "`manifestframe'"
    if "`eventdate'" != "" {
        return local eventvar "`eventgenerate'"
        if "`timegen'"  != "" return local timevar "`timegen'"
        if "`enum'"     != "" return local enumvar "`enum'"
        if "`gaptime'"  != "" {
            return local gapstartvar "`gapstart'"
            return local gapstopvar  "`gapstop'"
        }
    }
    return local coverage "`coverage'"
    return local frameout "`frameout'"
    if "`specframe'" != "" return local specframe "`specframe'"
    foreach _l in cum_out total_out rate_out exposure_out payload_vars source_names {
        local `_l' = strtrim(stritrim("``_l''"))
    }
    return local cumulative_vars "`cum_out'"
    return local total_vars      "`total_out'"
    return local rate_vars       "`rate_out'"
    return local exposure_vars   "`exposure_out'"
    return local payload_vars    "`payload_vars'"
    return local source_names    "`source_names'"
    return local stopvar  "`stopname'"
    return local startvar "`startname'"
    return local exitvar  "`exit'"
    return local entryvar "`entry'"
    return local idvar    "`id'"
    return scalar dates_kept = ("`dropdates'" == "")
    return scalar event_stage = ("`eventdate'" != "")
    return scalar N_persons = `N_persons'
    return scalar n_sources = `n_sources'
    return scalar spec_version = `spec_version'
    return scalar dryrun = ("`dryrun'" != "")
    }
    local rc = _rc

    * Cleanup. The caller frame is restored first: a failure inside a Mata
    * kernel or a frame-switched helper can leave Stata sitting in a scratch
    * frame, and dropping the current frame is an error of its own.
    local _cleanup_rc = 0
    capture frame change `_caller_frame'
    local _step_rc = _rc
    if `_step_rc' & !`_cleanup_rc' local _cleanup_rc = `_step_rc'

    foreach _f of local _tvp_frames {
        capture frame drop `_f'
    }

    capture set varabbrev `_orig_varabbrev'
    local _step_rc = _rc
    if `_step_rc' & !`_cleanup_rc' local _cleanup_rc = `_step_rc'

    if !`rc' & `_cleanup_rc' local rc = `_cleanup_rc'
    if `rc' exit `rc'
end


* Destination ownership. frameout() and manifestframe() must be distinct from
* the caller, the specification frame, every user input frame, each other, and
* every scratch name. replace authorises replacing a destination; it never
* makes an alias legal, because an alias is not a replacement -- it is the
* command reading and writing the same object.
capture program drop _tvpipe_check_dest
program define _tvpipe_check_dest, rclass
    version 16.0
    syntax , FRAMEOut(name) CALLERframe(name) PLANframe(name) ///
        [MANIFESTframe(name) SPECframe(name) EVENTFrame(name) REPlace]

    local _here "`c(frame)'"

    * Every user-owned frame the command reads, plus the source locators the
    * plan recorded. A destination that aliases any of them would be written
    * while it is still being read.
    local _inputs "`callerframe' `specframe' `eventframe'"
    frame change `planframe'
    forvalues i = 1/`=_N' {
        if input_kind[`i'] == "frame" {
            local _f = source_frame[`i']
            local _inputs "`_inputs' `_f'"
        }
    }
    frame change `_here'
    local _inputs : list uniq _inputs

    foreach d in frameout manifestframe {
        if "``d''" == "" continue
        * `: list X in Y' takes two macro NAMES. Writing `list ``d'' in _inputs'
        * would look up a macro named after the destination FRAME.
        local _dest "``d''"
        local _clash : list _dest in _inputs
        if `_clash' {
            noisily display as error ///
                "`d'(``d'') is also an input to this call; choose a different destination"
            exit 198
        }
    }
    if "`manifestframe'" != "" & "`manifestframe'" == "`frameout'" {
        noisily display as error ///
            "frameout() and manifestframe() must be different frames"
        exit 198
    }

    local _fo_exists = 0
    capture confirm frame `frameout'
    if _rc == 0 local _fo_exists = 1
    local _mf_exists = 0
    if "`manifestframe'" != "" {
        capture confirm frame `manifestframe'
        if _rc == 0 local _mf_exists = 1
    }

    if "`replace'" == "" {
        if `_fo_exists' {
            noisily display as error ///
                "frame `frameout' already exists; specify replace to overwrite it"
            exit 110
        }
        if `_mf_exists' {
            noisily display as error ///
                "frame `manifestframe' already exists; specify replace to overwrite it"
            exit 110
        }
    }

    return scalar manifest_exists = `_mf_exists'
    return scalar frameout_exists = `_fo_exists'
end



* The plan display. It reports what was validated and what would be built, and
* its closing line states plainly whether anything changed -- a dry run whose
* output could be mistaken for a completed build is worse than no dry run.
capture program drop _tvpipe_show_plan
program define _tvpipe_show_plan
    version 16.0
    syntax , PLANframe(name) ID(name) ENTry(name) EXIt(name) ///
        STARTName(name) STOPName(name) FRAMEOut(name) COVerage(string) ///
        NPERSons(integer) NFILes(integer) EVENTINput(string) ///
        FRAMEOUTExists(integer) MANIFESTExists(integer) DROPDates(integer) ///
        [EVENTGenerate(name) MANIFESTframe(name) KEEPvars(string) DRYrun]

    local _here "`c(frame)'"

    noisily display as text ""
    if "`dryrun'" != "" {
        noisily display as text "{bf:tvpipe plan (dry run)}"
    }
    else {
        noisily display as text "{bf:tvpipe plan}"
    }
    noisily display as text "{hline 68}"
    noisily display as text "  master frame      : " as result "`_here'"
    noisily display as text "  persons           : " as result %12.0fc `npersons'
    noisily display as text "  id / entry / exit : " as result "`id' `entry' `exit'"
    noisily display as text "  output bounds     : " as result "`startname' `stopname'"
    noisily display as text "  coverage policy   : " as result "`coverage'"
    noisily display as text "  files loaded      : " as result `nfiles'

    frame change `planframe'
    local _n = _N
    forvalues i = 1/`_n' {
        local _nm  = source_name[`i']
        local _kd  = source_kind[`i']
        local _ik  = input_kind[`i']
        local _loc = source_frame[`i']
        if "`_ik'" == "file" local _loc = resolved_file[`i']
        local _iv  = input_vars[`i']
        local _ov  = output_vars[`i']
        local _en  = engine[`i']
        local _ni  = N_input[`i']
        local _np  = N_persons[`i']
        local _nu  = N_unmatched_ids[`i']
        local _no  = N_outside_window[`i']
        frame change `_here'
        noisily display as text "{hline 68}"
        noisily display as text "  source `i'          : " as result "`_nm'" ///
            as text "  (`_kd', `_ik')"
        noisily display as text "  locator           : " as result "`_loc'"
        noisily display as text "  rows / persons    : " as result ///
            %12.0fc `_ni' as text " / " as result %8.0fc `_np'
        if `_nu' > 0 {
            noisily display as text "  ids not in master : " as result %8.0fc `_nu' ///
                as text "  (reported and ignored)"
        }
        if `_no' > 0 {
            noisily display as text "  rows outside win. : " as result %8.0fc `_no' ///
                as text "  (reported and ignored)"
        }
        noisily display as text "  mapping           : " as result "`_iv'" ///
            as text " -> " as result "`_ov'"
        noisily display as text "  engine            : " as result "`_en'"
        frame change `planframe'
    }
    frame change `_here'

    noisily display as text "{hline 68}"
    if "`keepvars'" != "" {
        noisily display as text "  master keepvars   : " as result "`keepvars'"
    }
    if `dropdates' {
        noisily display as text "  entry/exit        : " as result "dropped (dropdates)"
    }
    else {
        noisily display as text "  entry/exit        : " as result "retained"
    }
    if "`eventinput'" == "none" {
        noisily display as text "  event stage       : " as result "none"
    }
    else {
        noisily display as text "  event stage       : " as result ///
            "`eventgenerate'" as text "  (event data from the `eventinput')"
    }
    local _disp = cond(`frameoutexists', "replace existing", "create")
    noisily display as text "  frameout()        : " as result "`frameout'" ///
        as text "  (`_disp')"
    if "`manifestframe'" != "" {
        local _mdisp = cond(`manifestexists', "replace existing", "create")
        noisily display as text "  manifestframe()   : " as result ///
            "`manifestframe'" as text "  (`_mdisp')"
    }
    noisily display as text "{hline 68}"
    if "`dryrun'" != "" {
        noisily display as text ///
            "  Dry run: no frame, variable, value label, or file was created or changed."
    }
end


* The success display. It reports what was committed and hands the user the
* exact next commands, using the names tvpipe returns rather than the names the
* examples in the help file happen to use. It never executes them: the point of
* keeping tvdiagnose, tvweight, and stset outside this command is that those
* are scientific decisions, and a coordinator that ran them would be making
* them on the user's behalf.
capture program drop _tvpipe_show_result
program define _tvpipe_show_result
    version 16.0
    syntax , FRAMEOut(name) ID(name) NPERSons(integer) NPERIods(integer) ///
        STARTName(name) STOPName(name) COVerage(string) PAYload(string) ///
        NGAPIds(string) UNCOVered(string) DROPDates(integer) ///
        ENTRYVar(name) EXITVar(name) ///
        [EVENTVar(name) MANIFESTframe(name)]

    noisily display as text ""
    noisily display as text "{bf:tvpipe result}"
    noisily display as text "{hline 68}"
    noisily display as text "  frameout()        : " as result "`frameout'"
    noisily display as text "  persons           : " as result %12.0fc `npersons'
    noisily display as text "  periods           : " as result %12.0fc `nperiods'
    noisily display as text "  key / bounds      : " as result ///
        "`id' `startname' `stopname'"
    if !`dropdates' {
        noisily display as text "  study window      : " as result ///
            "`entryvar' `exitvar'"
    }
    noisily display as text "  output variables  : " as result ///
        "`=strtrim(stritrim("`payload'"))'"
    if "`eventvar'" != "" {
        noisily display as text "  event variable    : " as result "`eventvar'"
    }
    if "`manifestframe'" != "" {
        noisily display as text "  manifestframe()   : " as result "`manifestframe'"
    }
    if "`coverage'" == "allow" & `ngapids' > 0 {
        noisily display as text "  coverage          : " as result ///
            "allow" as text "  (`ngapids' person(s), `uncovered' uncovered day(s))"
    }
    else {
        noisily display as text "  coverage          : " as result "`coverage'" ///
            as text "  (every master day is represented)"
    }
    noisily display as text "{hline 68}"
    noisily display as text "  Next steps (not run by tvpipe):"
    noisily display as text "    . frame change `frameout'"
    * tvdiagnose's coverage report needs the study window, so the suggested
    * call names it when the window was retained and asks for the checks that
    * do not need it when dropdates removed it. A next step that errors when
    * pasted is worse than no next step.
    if !`dropdates' {
        noisily display as text ///
            "    . tvdiagnose, id(`id') start(`startname') stop(`stopname') entry(`entryvar') exit(`exitvar') all"
    }
    else {
        noisily display as text ///
            "    . tvdiagnose, id(`id') start(`startname') stop(`stopname') overlaps summarize"
    }
    if "`eventvar'" != "" {
        noisily display as text ///
            "    . stset `stopname', id(`id') failure(`eventvar' == 1) time0(`startname')"
    }
    else {
        noisily display as text ///
            "    . stset `stopname', id(`id') time0(`startname')"
    }
end

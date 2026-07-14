*! iivw_weight Version 3.0.0  2026/07/14
*! Compute inverse intensity of visit weights (IIW/IPTW/FIPTIW)
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  iivw_weight , id(varname) time(varname) visit_cov(varlist) [options]

Description:
  Computes inverse intensity of visit weights (IIW) to correct for
  informative visit processes in longitudinal clinic-based data.
  Optionally computes IPTW for confounding by indication and their
  product (FIPTIW).

  Visit intensity is modeled via an Andersen-Gill recurrent-event Cox
  model on the counting process of visits. Weights are the inverse of
  the estimated conditional intensity ratio (Buzkova & Lumley 2007).

Options:
  id(varname)          - Subject identifier (required)
  time(varname)        - Visit time in continuous units (required)
  visit_cov(varlist)   - Covariates for visit intensity model (required)
  treat(varname)       - Binary treatment for IPTW component
  treat_cov(varlist)   - Covariates for treatment model
  wtype(string)        - Weight type: iivw, iptw, or fiptiw (auto-detect)
  stabcov(varlist)     - Stabilization covariates for IIW numerator
  lagvars(varlist)     - Time-varying covariates to lag by one visit
  entry(varname)       - Study entry time per subject (default: 0)
  truncate(# #)        - Percentile trimming bounds
  generate(name)       - Prefix for weight variables (default: _iivw_)
  replace              - Overwrite existing weight variables
  nolog                - Suppress model iteration log

See help iivw_weight for complete documentation
*/

program define iivw_weight, rclass sortpreserve
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)
    tempname __iivw_visit_est __iivw_logit_est __iivw_bmat
    local __iivw_visit_hold_ok = 0
    local __iivw_logit_hold_ok = 0

    * Name-transaction state. Initialized before the captured block so the
    * cleanup zone can always roll back, however early an error fires.
    local __iivw_created_vars ""
    local __iivw_bk_names ""
    local __iivw_bk_temps ""
    local __iivw_nonconv = 0

    capture noisily {

    * No sample marker: IIW requires full panel, no [if] [in] by design

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , ID(varname) TIME(varname numeric) ///
        [VISit_cov(varlist numeric) ///
         TREAT(varname numeric) TREAT_cov(varlist numeric) ///
         WType(string) ///
         STABcov(varlist numeric) ///
         LAGvars(varlist numeric) ///
         ENTry(varname numeric) ///
         CENSor(varname numeric) MAXfu(numlist max=1) ENDATLASTvisit ///
         TRUNCate(numlist min=2 max=2) ///
         BASEline(string) ///
         GENerate(name) REPLACE noLOG EFRon ///
         ALLOWNONCONVerged ALLOWMISSINGWeights]

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`generate'" == "" local generate "_iivw_"
    local prefix "`generate'"

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    local efron_opt ""
    if "`efron'" != "" local efron_opt "efron"

    * Baseline handling. Since 2.0.0 the first visit per subject is study ENTRY
    * (risk onset), not a modeled recurrent event: the old default let baseline
    * covariates predict the occurrence of the very visit at which they were
    * measured. baseline(event) restores the legacy contract for designs where
    * the baseline visit really is an event of the same recurrent process.
    *
    * This is a value option rather than a pair of flags because Stata cannot
    * express the pair: `syntax [, noBASEevent]' leaves the macro EMPTY both when
    * the user types the positive form and when they omit the option, so an
    * explicit `baseevent' would be silently indistinguishable from saying
    * nothing -- and declaring `BASEevent NOBASEevent' as two flags does not help,
    * because Stata auto-negates the positive flag and swallows `nobaseevent'
    * before the second declaration ever sees it. The 1.x option name is gone:
    * `nobaseevent' now fails loudly rather than becoming a silent no-op.
    if "`baseline'" == "" local baseline "entry"
    if !inlist("`baseline'", "entry", "event") {
        display as error "baseline() must be entry or event"
        display as error "  entry (default): the first visit per subject is study entry"
        display as error "  event:           the first visit is a modeled visit-intensity event"
        display as error "                   (the pre-2.0.0 behavior; see nobaseevent in the"
        display as error "                   migration notes)"
        error 198
    }
    local exclude_base = ("`baseline'" == "entry")

    local __iivw_created_vars ""

    if strlen("`prefix'") > 23 {
        display as error "generate() prefix must be 23 characters or fewer"
        display as error "longer prefixes can make downstream iivw_fit variable names invalid"
        error 198
    }

    foreach candidate in `prefix'iw `prefix'tw `prefix'ps `prefix'weight ///
        `prefix'time_sq `prefix'time_cu `prefix'tns1 ///
        `prefix'tcat_1 `prefix'cat_x `prefix'ix_x_time {
        capture confirm name `candidate'
        if _rc {
            display as error "generate() prefix creates invalid variable name: `candidate'"
            error 198
        }
    }

    * =========================================================================
    * DETERMINE WEIGHT TYPE
    * =========================================================================

    if "`wtype'" == "" {
        * Auto-detect: treat() specified -> fiptiw, otherwise -> iivw
        if "`treat'" != "" {
            local wtype "fiptiw"
        }
        else {
            local wtype "iivw"
        }
    }

    * Validate wtype
    if !inlist("`wtype'", "iivw", "iptw", "fiptiw") {
        display as error "wtype() must be iivw, iptw, or fiptiw"
        error 198
    }

    * Validate options for weight type
    if inlist("`wtype'", "iptw", "fiptiw") & "`treat'" == "" {
        display as error "`wtype' requires treat() option"
        error 198
    }
    * The visit-intensity model needs at least one covariate, but it does not
    * care which option it arrives through: a model whose only predictor is a
    * lagged covariate is specified entirely by lagvars(). Requiring visit_cov()
    * to be nonempty forced a spurious contemporaneous term into exactly that
    * model, which is the one the reference implementation fits on Phenobarb.
    if inlist("`wtype'", "iivw", "fiptiw") & "`visit_cov'" == "" & "`lagvars'" == "" {
        display as error "`wtype' requires visit_cov() or lagvars()"
        display as error "  the visit-intensity model needs at least one covariate"
        error 198
    }
    if inlist("`wtype'", "iptw", "fiptiw") & "`treat_cov'" == "" {
        display as error "`wtype' requires treat_cov() option"
        error 198
    }

    * Note when visit_cov is supplied but ignored for IPTW-only
    if "`wtype'" == "iptw" {
        if "`visit_cov'" != "" {
            display as text "note: visit_cov() is ignored for wtype(iptw); " ///
                "only the treatment model is fitted"
            local visit_cov ""
        }
        if "`stabcov'" != "" {
            display as error "stabcov() is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits only the treatment model"
            error 198
        }
        if "`lagvars'" != "" {
            display as error "lagvars() is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) has no visit intensity model for lagged covariates"
            error 198
        }
        if "`entry'" != "" {
            display as error "entry() is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits no visit intensity counting-process model"
            error 198
        }
        if "`efron'" != "" {
            display as error "efron is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits no Cox visit intensity model"
            error 198
        }
        if "`baseline'" != "entry" {
            display as error "baseline() is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits no visit intensity model"
            error 198
        }
        if "`censor'" != "" | "`maxfu'" != "" | "`endatlastvisit'" != "" {
            display as error "censor(), maxfu() and endatlastvisit are only allowed with"
            display as error "  IIW or FIPTIW weights"
            display as error "wtype(iptw) fits no visit-intensity counting-process model,"
            display as error "  so there is no risk set for an end of follow-up to extend"
            error 198
        }
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * Check for observations
    if _N == 0 {
        display as error "no observations"
        error 2000
    }

    * Confirm panel structure
    confirm variable `id'
    confirm numeric variable `time'

    quietly count if missing(`id')
    if r(N) > 0 {
        display as error "id() contains missing values"
        display as error "each observation must have a nonmissing subject identifier"
        error 198
    }

    quietly count if missing(`time')
    if r(N) > 0 {
        display as error "time() contains missing values"
        display as error "each observation must have a nonmissing visit time"
        error 198
    }

    * The counting process is at risk from time 0: stset silently drops any
    * interval ending at or before 0, so negative visit times would remove
    * events from the Cox model while weights are still produced for them.
    if inlist("`wtype'", "iivw", "fiptiw") {
        quietly count if `time' < 0
        if r(N) > 0 {
            display as error "time() contains negative values"
            display as error "the visit-intensity model is at risk from time 0, so visits at negative"
            display as error "times would be silently excluded from the Cox model"
            display as error "shift or rescale time() so all visit times are nonnegative"
            error 198
        }

        * A first visit at exactly time 0 spans a zero-length interval, so
        * stset excludes it from the visit-intensity risk sets. The row still
        * gets the conventional baseline weight of 1; only the intensity model
        * loses it as an event. Say so rather than leaving the exclusion
        * buried in the stset table. (Under baseline(entry) those rows are
        * dropped by design, so no note is needed.)
        if !`exclude_base' {
            tempvar _first_t0
            quietly bysort `id' (`time'): gen byte `_first_t0' = ///
                (_n == 1 & `time' == 0)
            quietly count if `_first_t0'
            if r(N) > 0 {
                display as text "note: " as result r(N) as text ///
                    " subjects have their first visit at time 0"
                display as text "  these baseline rows span no risk time and are excluded from the"
                display as text "  visit-intensity model; they keep the conventional weight of 1"
            }
            drop `_first_t0'
        }
    }

    if "`entry'" != "" & !`exclude_base' {
        quietly count if missing(`entry')
        if r(N) > 0 {
            display as error "entry() contains missing values"
            display as error "each observation must have a nonmissing study entry time"
            error 198
        }

        quietly count if `entry' < 0
        if r(N) > 0 {
            display as text "note: entry() contains negative values; risk time before 0 is"
            display as text "  not counted by the visit-intensity model (risk starts at time 0)"
        }

        tempvar _entry_min _entry_max _first_time
        quietly bysort `id': egen double `_entry_min' = min(`entry')
        quietly bysort `id': egen double `_entry_max' = max(`entry')
        quietly count if `_entry_min' != `_entry_max'
        if r(N) > 0 {
            display as error "entry() must be constant within each id()"
            error 198
        }

        quietly bysort `id' (`time'): gen double `_first_time' = `time'[1]
        quietly count if `_entry_min' >= `_first_time'
        if r(N) > 0 {
            display as error "entry() must be strictly less than the first visit time within each id()"
            error 198
        }
        drop `_entry_min' `_entry_max' `_first_time'
    }

    * =========================================================================
    * END-OF-FOLLOW-UP CONTRACT
    * =========================================================================
    * The Andersen-Gill risk set is the set of subjects still under observation:
    * Buzkova & Lumley (2007) write the at-risk process as xi_i(t) = I(C_i > t)
    * with C_i the drop-out time or end of follow-up (p.7; it enters the risk-set
    * denominator at their eq. 8, p.8), and Tompkins et al. (2025) write the same
    * denominator with I(C_j >= t) (p.5).
    *
    * Before 2.0.0 this package built intervals only between observed visits, so
    * every subject silently left the risk set at their own last visit -- making
    * risk-set membership a function of the visit process being modeled. Measured
    * on a known-truth DGP (gamma = 0.5, C_i ~ U(tau/2, tau)), that attenuated the
    * visit-intensity coefficient by about a quarter (0.371 vs 0.500, bias 99
    * MCSEs). The weights are exp(-xb), so it propagated into every downstream
    * estimate. There is no safe default here, and the old one was not safe, so
    * 2.0.0 requires the user to state the design.
    local __iivw_cens_mode ""
    if inlist("`wtype'", "iivw", "fiptiw") {
        local __iivw_n_cens_opts = 0
        if "`censor'" != ""         local ++__iivw_n_cens_opts
        if "`maxfu'" != ""          local ++__iivw_n_cens_opts
        if "`endatlastvisit'" != "" local ++__iivw_n_cens_opts

        if `__iivw_n_cens_opts' > 1 {
            display as error "specify only one of censor(), maxfu() and endatlastvisit"
            display as error "  they are three ways of stating the same thing: when each"
            display as error "  subject stops being at risk of a visit"
            error 198
        }
        if `__iivw_n_cens_opts' == 0 {
            display as error "end of follow-up is not specified"
            display as error ""
            display as error "The visit-intensity model needs each subject's observation window,"
            display as error "not just the intervals between their visits. Specify exactly one of:"
            display as error ""
            display as error "  censor(varname)  subject-specific end of follow-up (administrative"
            display as error "                   censoring, death, loss to follow-up); must be"
            display as error "                   constant within id() and >= the subject's last visit"
            display as error "  maxfu(#)         a common end of follow-up shared by all subjects"
            display as error "  endatlastvisit   follow-up genuinely ends at each subject's last"
            display as error "                   visit (the pre-2.0.0 behavior)"
            display as error ""
            display as error "endatlastvisit is rarely the right description of a registry or EHR"
            display as error "cohort: it makes a subject leave the risk set because they stopped"
            display as error "visiting, which is the very process being modeled. It attenuated the"
            display as error "visit-intensity coefficient by ~26% in a known-truth check."
            error 198
        }

        if "`endatlastvisit'" != "" {
            local __iivw_cens_mode "lastvisit"
        }
        else if "`maxfu'" != "" {
            local __iivw_cens_mode "maxfu"

            * A visit after the stated end of follow-up is a data error, not a
            * modeling choice: the subject was demonstrably still at risk.
            quietly summarize `time', meanonly
            if r(max) > `maxfu' {
                quietly count if `time' > `maxfu'
                display as error "`=r(N)' visits occur after maxfu(`maxfu')"
                display as error "  the maximum visit time is " %12.0g `=r(max)'
                display as error "  use censor() for subject-specific follow-up"
                error 198
            }
        }
        else {
            local __iivw_cens_mode "censor"

            quietly count if missing(`censor')
            if r(N) > 0 {
                display as error "censor() contains missing values"
                display as error "each subject must have a nonmissing end of follow-up"
                error 198
            }

            tempvar _cmin _cmax _lastvis
            quietly bysort `id': egen double `_cmin' = min(`censor')
            quietly bysort `id': egen double `_cmax' = max(`censor')
            quietly count if `_cmin' != `_cmax'
            if r(N) > 0 {
                display as error "censor() must be constant within each id()"
                display as error "  end of follow-up is a property of the subject, not of the visit"
                error 198
            }

            quietly bysort `id': egen double `_lastvis' = max(`time')
            quietly count if `censor' < `_lastvis'
            if r(N) > 0 {
                display as error "censor() is earlier than the last observed visit for some subjects"
                display as error "  a subject cannot have stopped being at risk at a time when they"
                display as error "  were observably still visiting; check the censoring variable"
                error 198
            }
            drop `_cmin' `_cmax' `_lastvis'
        }
    }

    * A covariate whose value over an interval depends on the PREVIOUS visit must
    * be declared in lagvars(), not pre-computed and passed through visit_cov().
    *
    * The censoring interval (last visit, C] is built by copying the subject's
    * last visit row, so a covariate carries forward the value in effect when
    * they were last seen -- right for a contemporaneous covariate. A covariate
    * that is ALREADY a lag carries forward the value from the visit before that,
    * which is off by one, and the package has no way to tell the two apart from
    * the data alone. Declared via lagvars(), the lag is rebuilt on the censoring
    * row from its source variable and is exact (this is also what IrregLong does:
    * it lags after appending, never before).
    *
    * Warn on the name, which is the only signal available. A warning, not an
    * error: a variable may legitimately be called "lagoon".
    if inlist("`wtype'", "iivw", "fiptiw") & "`__iivw_cens_mode'" != "lastvisit" {
        local __iivw_suspect ""
        foreach v of local visit_cov {
            if regexm(lower("`v'"), "(^|_)lag") {
                local __iivw_suspect "`__iivw_suspect' `v'"
            }
        }
        if "`__iivw_suspect'" != "" & "`lagvars'" == "" {
            display as text "note: visit_cov() contains what looks like a pre-computed lag:" ///
                as result "`__iivw_suspect'"
            display as text "  on the censoring interval after each subject's last visit, a"
            display as text "  pre-computed lag carries the value from one visit too far back."
            display as text "  Declare the SOURCE variable in lagvars() instead, and the lag is"
            display as text "  rebuilt correctly on that interval."
        }
    }

    * Check for sufficient observations per subject when fitting visit intensity
    if inlist("`wtype'", "iivw", "fiptiw") {
        tempvar _nvis
        quietly bysort `id' (`time'): gen long `_nvis' = _N
        if `exclude_base' {
            * Under baseline(entry) the baseline visit is study entry, not a modeled
            * event, so single-visit subjects contribute only a baseline row
            * (weight 1) and need not be dropped. The model still requires at
            * least one subject with a follow-up visit to have any events to fit.
            quietly summarize `_nvis'
            if r(max) < 2 {
                display as error "baseline(entry) requires at least one subject with 2 or more visits"
                display as error "with no follow-up visits the intensity model has no events to fit"
                error 198
            }
        }
        else if "`__iivw_cens_mode'" == "lastvisit" {
            * baseline(event) with no end of follow-up: a single-visit subject
            * would contribute the single interval (entry, t1] and then vanish,
            * with no at-risk time at all beyond their one visit. Refuse, as
            * before.
            *
            * With a real end of follow-up this restriction is gone: such a
            * subject contributes (entry, t1] with an event and (t1, C] without
            * one, which is a complete and perfectly ordinary risk history.
            * Dropping them because they visited only once was the same defect
            * as ending the risk set at the last visit -- excluding subjects on
            * the basis of the visit process being modeled. IrregLong keeps them.
            quietly summarize `_nvis'
            if r(min) < 2 {
                quietly count if `_nvis' < 2
                local n_single = r(N)
                display as error "`n_single' observations belong to subjects with only 1 visit"
                display as error "`wtype' requires at least 2 visits per subject under"
                display as error "  baseline(event) with endatlastvisit"
                display as text  "  to retain single-visit subjects, either specify an end of"
                display as text  "  follow-up -- censor() or maxfu() -- so they contribute a"
                display as text  "  censored interval after their visit, or use baseline(entry),"
                display as text  "  which treats the baseline visit as study entry"
                error 198
            }
        }
        drop `_nvis'
    }

    * Check for duplicate id-time combinations
    tempvar _dup
    quietly duplicates tag `id' `time', gen(`_dup')
    quietly count if `_dup' > 0
    if r(N) > 0 {
        display as error "duplicate id-time combinations found"
        display as error "each subject-visit must be uniquely identified by id() and time()"
        error 198
    }
    drop `_dup'

    * Validate treatment is binary (if specified)
    if "`treat'" != "" {
        quietly count if missing(`treat')
        if r(N) > 0 {
            display as error "treat() contains missing values"
            display as error "treat() must be observed for every row used in IPTW/FIPTIW"
            error 198
        }

        capture assert inlist(`treat', 0, 1) if !missing(`treat')
        if _rc {
            display as error "treat() must be binary (0/1)"
            error 198
        }

        * Disallow partially-missing treatment within subject
        tempvar _treat_anymiss _treat_anynonmiss
        quietly bysort `id': egen byte `_treat_anymiss' = max(missing(`treat'))
        quietly bysort `id': egen byte `_treat_anynonmiss' = max(!missing(`treat'))
        quietly count if `_treat_anymiss' & `_treat_anynonmiss'
        if r(N) > 0 {
            display as error "treat() has partially missing values within subjects"
            display as error "ensure treat() is either fully observed or fully missing within each id()"
            error 198
        }
        drop `_treat_anymiss' `_treat_anynonmiss'

        * Check treatment is time-invariant within subject
        tempvar _treat_sd
        quietly bysort `id': egen double `_treat_sd' = sd(`treat')
        quietly summarize `_treat_sd'
        if r(N) > 0 & r(max) > 0 {
            display as error "treat() must be time-invariant within subjects"
            display as error "for time-varying treatments, consider marginal structural models (MSMs)"
            error 198
        }
        drop `_treat_sd'

        * Check both treatment groups present
        quietly count if `treat' == 1
        local n_treat = r(N)
        quietly count if `treat' == 0
        local n_ctrl = r(N)
        if `n_treat' == 0 | `n_ctrl' == 0 {
            display as error "treat() must have observations in both groups"
            error 198
        }
    }

    * Validate truncation
    if "`truncate'" != "" {
        local trunc_lo: word 1 of `truncate'
        local trunc_hi: word 2 of `truncate'
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            error 198
        }
        if `trunc_lo' <= 0 | `trunc_hi' >= 100 {
            display as error "truncate() values must be strictly between 0 and 100"
            error 198
        }
    }

    * =========================================================================
    * NAME TRANSACTION
    * =========================================================================
    * Build the complete inventory of names this call will create, and every
    * name the user supplied as a scientific input, BEFORE touching the data.
    * A generated name that collides with an input is rejected outright:
    * replace authorizes overwriting a prior iivw output, never destroying an
    * analysis input.

    * The package OWNS all four output names under this prefix, whatever weight
    * type is being computed now. A rerun must invalidate the previous run's
    * outputs too: switching FIPTIW -> IIW-only has to clear the stale _ps/_tw
    * variables, or the data keeps treatment outputs that no contract describes.
    * So the owned set is the full four -- names not recreated by this wtype are
    * backed up, never restored on success, and thus cleared atomically.
    local __iivw_gen_names ///
        "`prefix'iw `prefix'tw `prefix'ps `prefix'weight"

    * Ownership tokens, parallel to the generated names. `replace' may overwrite
    * a name only if the variable already in the data carries exactly the token
    * this call is about to stamp on it. A user column that merely happens to
    * sit under the selected prefix carries no token, so it is refused instead
    * of being backed up and discarded. See _iivw_own.ado.
    local __iivw_gen_tokens ""
    foreach __iivw_r in iw tw ps weight {
        _iivw_own token, role(`__iivw_r') prefix(`prefix')
        local __iivw_gen_tokens "`__iivw_gen_tokens' `r(token)'"
    }
    _iivw_own token, role(lag)
    local __iivw_lag_token "`r(token)'"

    local __iivw_lag_names ""
    foreach v of local lagvars {
        local lagname "`v'_lag1"
        if strlen("`lagname'") > 32 {
            display as error "lagged variable name `lagname' exceeds 32 characters"
            display as error "rename `v' to a shorter name before using lagvars()"
            error 198
        }
        local __iivw_lag_names "`__iivw_lag_names' `lagname'"
        local __iivw_gen_tokens "`__iivw_gen_tokens' `__iivw_lag_token'"
    }
    local __iivw_gen_names "`__iivw_gen_names' `__iivw_lag_names'"
    local __iivw_gen_names = strtrim("`__iivw_gen_names'")
    local __iivw_gen_tokens = strtrim("`__iivw_gen_tokens'")

    * Every variable the user handed us as science, in any role.
    local __iivw_protected ///
        "`id' `time' `entry' `censor' `treat' `visit_cov' `treat_cov' `stabcov' `lagvars'"
    local __iivw_protected : list uniq __iivw_protected

    _iivw_reserve_names, generated(`__iivw_gen_names') ///
        owntokens(`__iivw_gen_tokens') ///
        protected(`__iivw_protected') `replace' context(iivw_weight)

    * Back up -- do not drop -- any prior iivw output we are about to replace,
    * so a failure anywhere below restores the user's previous valid weights
    * exactly. Renaming to a tempvar name means a successful run auto-drops the
    * backup at program exit; the cleanup zone renames them back on error.
    local __iivw_bk_names ""
    local __iivw_bk_temps ""
    foreach g of local __iivw_gen_names {
        capture confirm variable `g'
        if _rc == 0 {
            tempvar __iivw_bk
            quietly rename `g' `__iivw_bk'
            local __iivw_bk_names "`__iivw_bk_names' `g'"
            local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
        }
    }

    * =========================================================================
    * SORT DATA (sortpreserve restores original order on exit)
    * =========================================================================

    sort `id' `time'

    * Stable row identifier for preserve/merge workflows
    tempvar _obsno
    quietly gen long `_obsno' = _n

    * =========================================================================
    * LAG VARIABLES (if requested)
    * =========================================================================

    * Stored weighting/fitting state is NOT invalidated here. Under the name
    * transaction above nothing the user owns has been mutated yet, and every
    * prior output is backed up rather than dropped -- so an error below leaves
    * the previous weights intact, and the previous contract still describes
    * them truthfully. State is cleared and rewritten atomically at the commit
    * point, once every model has actually succeeded.

    local lag_created ""
    if "`lagvars'" != "" {
        * Names were validated and any prior copies backed up in the name
        * transaction; just build the values.
        local lag_index = 0
        foreach v of local lagvars {
            local ++lag_index
            local lagname : word `lag_index' of `__iivw_lag_names'
            quietly bysort `id' (`time'): gen double `lagname' = `v'[_n-1]
            local lag_created "`lag_created' `lagname'"
            local __iivw_created_vars "`__iivw_created_vars' `lagname'"
        }
    }

    * Build full covariate list for visit model (original + lagged).
    * itrim: lag_created accumulates with a leading space, so the concatenation
    * used to produce "L1 L2  edss_lag1" -- a DOUBLE space. stcox does not care,
    * but this string is stored on the contract and string-compared by consumers
    * and by QA, and an invisible extra space is exactly the kind of thing that
    * makes an equality test fail for a reason nobody can see.
    local visit_covars "`visit_cov'"
    if "`lag_created'" != "" {
        local visit_covars "`visit_covars' `lag_created'"
    }
    local visit_covars = strtrim(itrim("`visit_covars'"))

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    local wtype_display = upper("`wtype'")
    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw_weight" as text " - `wtype_display' Weight Computation"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text ""
    display as text "ID variable:      " as result "`id'"
    display as text "Time variable:    " as result "`time'"
    if inlist("`wtype'", "iivw", "fiptiw") {
        display as text "Visit covariates: " as result "`visit_covars'"
    }
    if "`treat'" != "" {
        display as text "Treatment:        " as result "`treat'"
    }
    if "`treat_cov'" != "" {
        display as text "Treatment covars: " as result "`treat_cov'"
    }
    display as text "Weight type:      " as result "`wtype_display'"
    if "`truncate'" != "" {
        display as text "Truncation:       " as result "`trunc_lo'th - `trunc_hi'th percentile"
    }
    if `exclude_base' & inlist("`wtype'", "iivw", "fiptiw") {
        display as text "Baseline visit:   " as result ///
            "study entry (not modeled as a visit-intensity event)"
        if "`entry'" != "" {
            display as text "note: entry() is ignored under baseline(entry); the first" ///
                " visit per subject defines risk onset"
        }
    }
    display as text ""

    * Count subjects
    tempvar _first
    quietly bysort `id' (`time'): gen byte `_first' = (_n == 1)
    quietly count if `_first' == 1
    local n_ids = r(N)
    local N = _N
    drop `_first'

    * =========================================================================
    * IIW COMPONENT: Visit intensity model
    * =========================================================================

    if inlist("`wtype'", "iivw", "fiptiw") {

        display as text "Fitting visit intensity model (Andersen-Gill Cox)..."
        display as text "  Visit model: stcox `visit_covars'"

        tempfile __iivw_iwfile
        local __iivw_visit_converged = 1
        local __iivw_stab_converged = 1
        local __iivw_iw_rc = 0
        local __iivw_visit_N = 0
        local __iivw_visit_Nsub = 0
        local __iivw_stab_N = 0
        local __iivw_n_cens_rows = 0
        local __iivw_visit_hold_ok = 0
        capture _estimates hold `__iivw_visit_est', nullok
        if _rc == 0 {
            local __iivw_visit_hold_ok = 1
        }
        else {
            local __iivw_hold_rc = _rc
            display as error "could not preserve active estimation results"
            exit `__iivw_hold_rc'
        }

        preserve
        capture noisily {
            * ---------------------------------------------------------------
            * Step 1: Counting process setup
            * Each visit is a recurrent event. Transform to (start, stop).
            * ---------------------------------------------------------------

            * Entry time: user-specified or 0
            if "`entry'" != "" {
                tempvar _entry_val
                bysort `id' (`time'): gen double `_entry_val' = `entry'[1]
            }

            tempvar _start _stop _event _censrow _isfirst

            * Start time: previous visit time (or entry time for first visit)
            if "`entry'" != "" {
                bysort `id' (`time'): gen double `_start' = ///
                    cond(_n == 1, `_entry_val', `time'[_n-1])
            }
            else {
                bysort `id' (`time'): gen double `_start' = ///
                    cond(_n == 1, 0, `time'[_n-1])
            }

            gen double `_stop' = `time'
            gen byte `_event' = 1
            gen byte `_censrow' = 0
            bysort `id' (`time'): gen byte `_isfirst' = (_n == 1)

            * ---------------------------------------------------------------
            * Step 1b: Administrative-censoring rows
            *
            * (last visit, end of follow-up] with no event, so the subject stays
            * in the risk set for as long as they were actually under observation
            * rather than leaving it at their own last visit. This is Buzkova &
            * Lumley's xi_i(t) = I(C_i > t), and it is what IrregLong's
            * addcensoredrows() builds before it ever calls coxph.
            *
            * Each censoring row is a copy of the subject's LAST VISIT row, so
            * every covariate carries forward the value in effect when the
            * subject was last seen. For a subject-constant covariate that is
            * exactly IrregLong's behavior (it copies those columns). For a
            * lagged covariate it is too, once the lag is rebuilt below: the
            * value lagged by one visit across (last visit, C] is the value AT
            * the last visit, which the copied row already carries in the source
            * variable itself.
            *
            * An UNLAGGED time-varying covariate is the one place we deliberately
            * differ: IrregLong leaves it missing, which makes coxph drop the
            * censoring row and quietly reintroduces the omission this whole
            * construction exists to fix. Carrying it forward keeps the subject
            * in the risk set. The help file states this.
            * ---------------------------------------------------------------
            if "`__iivw_cens_mode'" != "lastvisit" {
                tempvar _cens_t _lastrow _newrow

                if "`__iivw_cens_mode'" == "maxfu" {
                    gen double `_cens_t' = `maxfu'
                }
                else {
                    bysort `id' (`time'): gen double `_cens_t' = `censor'[1]
                }
                bysort `id' (`time'): gen byte `_lastrow' = (_n == _N)

                * A subject last seen exactly at their end of follow-up needs no
                * extra row: the interval would have zero length, and stset drops
                * it anyway. (IrregLong calls this case `alreadythere'.)
                expand 2 if `_lastrow' & `_cens_t' > `_stop' & ///
                    !missing(`_cens_t'), gen(`_newrow')
                quietly count if `_newrow'
                local __iivw_n_cens_rows = r(N)

                replace `_start'   = `_stop'   if `_newrow'
                replace `_stop'    = `_cens_t' if `_newrow'
                replace `_event'   = 0         if `_newrow'
                replace `_censrow' = 1         if `_newrow'
                replace `_isfirst' = 0         if `_newrow'
                replace `time'     = `_cens_t' if `_newrow'

                * A censoring row is not a user observation and must never merge
                * back as one. Blanking the row id is what guarantees that.
                replace `_obsno' = . if `_newrow'

                local __iivw_lag_ix = 0
                foreach v of local lagvars {
                    local ++__iivw_lag_ix
                    local lagname : word `__iivw_lag_ix' of `__iivw_lag_names'
                    replace `lagname' = `v' if `_newrow'
                }
            }

            * Under the default contract the baseline visit is study entry, not
            * an event. Drop the (entry, t1] interval so the subject enters the
            * visit-intensity risk set at the first visit and the modeled events
            * are the follow-up visits (t1,t2], (t2,t3], .... This removes the
            * circularity of the baseline visit predicting its own occurrence.
            * Censoring rows are NOT baseline rows and survive this: that is what
            * puts a subject with no follow-up visit into the risk set for their
            * whole observation window, which the old construction could not do.
            * Dropped baseline rows are reinstated with weight 1 after restore.
            if `exclude_base' {
                drop if `_isfirst'
            }

            * ---------------------------------------------------------------
            * Step 2: Fit Andersen-Gill Cox model
            * ---------------------------------------------------------------
            * One common risk set for BOTH models. The stabilized weight is an
            * intensity ratio, so its numerator and denominator have to be
            * evaluated over the same risk set; refitting the numerator on its
            * own complete cases let rows that can never receive a weight (they
            * are missing a denominator covariate) still shape the numerator's
            * coefficients and the risk sets of the rows that do. Marking the
            * common sample up front also means a row missing ANY input to either
            * model gets no weight, rather than a weight built from a numerator
            * that learned from it.
            tempvar _cox_ok
            gen byte `_cox_ok' = 1
            markout `_cox_ok' `visit_covars' `stabcov'

            * stset for counting process (AG recurrent events)
            * exit(time .) allows multiple events per subject
            stset `_stop', enter(time `_start') failure(`_event') ///
                id(`id') exit(time .)

            stcox `visit_covars' if `_cox_ok', `log_opt' `efron_opt'
            local __iivw_visit_converged = e(converged)
            local __iivw_visit_N = e(N)
            local __iivw_visit_Nsub = e(N_sub)
            matrix `__iivw_bmat' = e(b)

            * Get linear predictor
            tempvar _xb_full
            predict double `_xb_full', xb

            * ---------------------------------------------------------------
            * Step 3: Compute IIW weights
            * Stabilized weight: w = exp(-xb_full) for unstabilized
            * With stabcov: w = exp(xb_stab - xb_full)
            * ---------------------------------------------------------------

            if "`stabcov'" != "" {
                noisily display as text "  Stabilization model: stcox `stabcov'"
                noisily stcox `stabcov' if `_cox_ok', `log_opt' `efron_opt'
                local __iivw_stab_converged = e(converged)
                local __iivw_stab_N = e(N)

                tempvar _xb_stab
                predict double `_xb_stab', xb
                gen double `prefix'iw = exp(`_xb_stab' - `_xb_full')
            }
            else {
                gen double `prefix'iw = exp(-`_xb_full')
                local __iivw_stab_N = `__iivw_visit_N'
            }

            * The censoring rows have done their work: they held the subject in
            * the risk set while the models were fitted. They are not visits, so
            * they carry no weight and must not travel back to the user's data.
            drop if `_censrow'

            * In default mode the preserved data still holds the baseline rows.
            * Under baseline(entry) those rows were dropped before fitting; their
            * weight (1) is reinstated after restore in the full data, so the
            * first-visit handling below is skipped to avoid mislabeling the
            * first follow-up visit as the baseline.
            if !`exclude_base' {
                * Warn if first observations have missing covariates
                * (predict xb gives missing when covariates are missing)
                tempvar _first_visit
                bysort `id' (`time'): gen byte `_first_visit' = (_n == 1)
                quietly count if `_first_visit' & missing(`_xb_full')
                if r(N) > 0 {
                    local n_miss_first = r(N)
                    noisily display as text "note: `n_miss_first' subjects have " ///
                        "missing visit model covariates at first observation"
                    noisily display as text "  weight set to 1 by convention; " ///
                        "check covariate completeness"
                }

                * First observation per subject: set weight = 1
                bysort `id' (`time'): replace `prefix'iw = 1 if _n == 1
            }

            keep `_obsno' `prefix'iw
            save `__iivw_iwfile', replace
        }
        local __iivw_iw_rc = _rc
        local __iivw_unhold_rc = 0
        restore
        if `__iivw_visit_hold_ok' {
            capture _estimates unhold `__iivw_visit_est'
            local __iivw_unhold_rc = _rc
            local __iivw_visit_hold_ok = 0
            if `__iivw_unhold_rc' != 0 & `__iivw_iw_rc' == 0 {
                local __iivw_iw_rc = `__iivw_unhold_rc'
            }
        }

        if `__iivw_iw_rc' != 0 {
            foreach v of local lag_created {
                capture drop `v'
                local __iivw_drop_rc = _rc
            }
            if `__iivw_unhold_rc' != 0 {
                display as error "could not restore active estimation results"
            }
            else {
                display as error "visit intensity model failed; no weights created"
            }
            exit `__iivw_iw_rc'
        }

        * Convergence gate BEFORE the weights are merged into the user's data.
        * A nonconverged Cox model's xb is not a fitted linear predictor, so
        * exp(-xb) is not a weight -- it must not reach the dataset, and must
        * certainly not be stamped as a valid weighting contract.
        if `__iivw_visit_converged' == 0 {
            _iivw_require_converged, model(visit-intensity Cox) ///
                `allownonconverged'
            local __iivw_nonconv = 1
        }
        if "`stabcov'" != "" & `__iivw_stab_converged' == 0 {
            _iivw_require_converged, model(IIW stabilization Cox) ///
                `allownonconverged'
            local __iivw_nonconv = 1
        }

        if `exclude_base' {
            * Baseline rows were dropped before fitting, so they are master-only
            * here; reinstate their IIW weight to 1 (study-entry convention).
            merge 1:1 `_obsno' using `__iivw_iwfile', nogen assert(match master)
            bysort `id' (`time'): replace `prefix'iw = 1 if _n == 1
        }
        else {
            merge 1:1 `_obsno' using `__iivw_iwfile', nogen assert(match)
        }
        local __iivw_created_vars "`__iivw_created_vars' `prefix'iw"

        * Normalize the IIW component to mean 1 over the estimating sample.
        * exp(-xb) has an arbitrary scale: the Cox model carries no intercept and
        * predict, xb is uncentered, so the raw mean of exp(-xb) is a function of
        * covariate location, not of model fit. Rescaling to mean 1 is invariant
        * for the weighted point estimates AND the cluster-robust (sandwich) SE --
        * a constant weight factor cancels in the estimating equation and both the
        * bread and meat of the sandwich -- but it makes the reported mean, ESS,
        * and max-weight diagnostics interpretable rather than scale-dependent.
        quietly summarize `prefix'iw if !missing(`prefix'iw), meanonly
        if r(N) > 0 & r(mean) > 0 & r(mean) < . {
            quietly replace `prefix'iw = `prefix'iw / r(mean)
        }

        label variable `prefix'iw "Inverse intensity weight"
    }

    * =========================================================================
    * IPTW COMPONENT: Treatment model
    * =========================================================================

    if inlist("`wtype'", "iptw", "fiptiw") {

        display as text "Fitting treatment model (logistic)..."

        local treat_covars "`treat_cov'"
        local n_ps_lo = 0
        local n_ps_hi = 0
        local n_ps_extreme = 0

        * Fit propensity score model on cross-sectional data (one row per subject)
        * Using full panel would over-represent subjects with more visits.
        * Merge the subject-level PS back to the full panel to keep PS time-invariant.
        display as text "  Treatment model: logit `treat' `treat_covars'"

        quietly {
            tempvar _first_obs
            bysort `id' (`time'): gen byte `_first_obs' = (_n == 1)
        }

        * treat() and treat_cov() are documented as BASELINE characteristics,
        * and the propensity model below is fitted on each subject's earliest
        * retained row. Nothing used to enforce that. A time-varying variable
        * was silently reduced to "whatever value happened to sit on the
        * earliest row that survived the sample restrictions" -- which is not a
        * baseline value, is not what the help promises, and shifts if the user
        * changes an if/in. Detect within-subject variation and refuse it: the
        * user must build an explicit baseline variable, so the choice of which
        * row counts as baseline is theirs and is visible.
        * min/max, NOT sd. egen's sd() over a run of identical doubles returns
        * roundoff (~1e-15), not 0, so an sd()>0 test flags almost every genuinely
        * constant covariate -- a guard that rejects the valid case is worse than
        * no guard. min and max involve no arithmetic and are exact.
        *
        * They also both ignore missing, which is what we want: a baseline
        * covariate recorded once and missing at later visits is a normal
        * registry layout, and only the baseline row feeds the model anyway. The
        * contract is that the NONMISSING values within a subject agree.
        tempvar __iivw_wmn __iivw_wmx
        local __iivw_tvary ""
        foreach __iivw_v in `treat' `treat_covars' {
            capture drop `__iivw_wmn'
            capture drop `__iivw_wmx'
            quietly bysort `id': egen double `__iivw_wmn' = min(`__iivw_v')
            quietly bysort `id': egen double `__iivw_wmx' = max(`__iivw_v')
            quietly count if `__iivw_wmn' != `__iivw_wmx' & ///
                !missing(`__iivw_wmn', `__iivw_wmx')
            if r(N) > 0 local __iivw_tvary "`__iivw_tvary' `__iivw_v'"
        }
        capture drop `__iivw_wmn'
        capture drop `__iivw_wmx'
        if "`__iivw_tvary'" != "" {
            display as error "treatment-model variables vary within subject:`__iivw_tvary'"
            display as error ""
            display as text "  The propensity model is a BASELINE model: it is fitted on one row"
            display as text "  per subject, the earliest retained visit. A variable that changes"
            display as text "  over follow-up therefore enters as whatever value happened to land"
            display as text "  on that row -- not as a baseline value."
            display as text ""
            display as text "  Construct the baseline value explicitly, e.g."
            display as text "    bysort `id' (`time'): generate double base_x = x[1]"
            display as text "  and pass base_x. Then the row that defines baseline is your choice,"
            display as text "  not an accident of the sort order."
            exit 459
        }

        tempfile __iivw_psfile
        local logit_rc = 0
        local __iivw_logit_hold_ok = 0
        capture _estimates hold `__iivw_logit_est', nullok
        if _rc == 0 {
            local __iivw_logit_hold_ok = 1
        }
        else {
            local __iivw_hold_rc = _rc
            display as error "could not preserve active estimation results"
            exit `__iivw_hold_rc'
        }
        local __iivw_logit_converged = 1
        local __iivw_ps_N = 0
        local __iivw_p_treat = .
        preserve
        capture noisily {
            quietly keep if `_first_obs'
            logit `treat' `treat_covars', `log_opt'
            local __iivw_logit_converged = e(converged)
            local __iivw_ps_N = e(N)

            * The stabilization numerator is the treatment prevalence in the
            * population the propensity model actually describes -- its own
            * e(sample). Recomputing it over every first row instead pulls in
            * subjects the model could not fit (missing a treatment covariate),
            * and when that missingness is differential by arm the numerator is
            * simply the wrong number: with treatment covariates missing for five
            * of ten treated subjects, prevalence over the 15 analyzable subjects
            * is 5/15 = 0.3333 while every-first-row prevalence is 0.5, scaling
            * treated weights by 1.5 and control weights by 0.75.
            quietly summarize `treat' if e(sample), meanonly
            local __iivw_p_treat = r(mean)

            tempvar _ps_tmp
            predict double `_ps_tmp', pr
            keep `id' `_ps_tmp'
            save `__iivw_psfile', replace
        }
        local logit_rc = _rc
        local __iivw_unhold_rc = 0
        restore
        if `__iivw_logit_hold_ok' {
            capture _estimates unhold `__iivw_logit_est'
            local __iivw_unhold_rc = _rc
            local __iivw_logit_hold_ok = 0
            if `__iivw_unhold_rc' != 0 & `logit_rc' == 0 {
                local logit_rc = `__iivw_unhold_rc'
            }
        }

        if `logit_rc' != 0 {
            * Clean up IIW variables if they were created before IPTW failed
            if inlist("`wtype'", "fiptiw") {
                capture drop `prefix'iw
                local __iivw_drop_rc = _rc
            }
            foreach v of local lag_created {
                capture drop `v'
                local __iivw_drop_rc = _rc
            }
            if `__iivw_unhold_rc' != 0 {
                display as error "could not restore active estimation results"
            }
            else {
                display as error "treatment model failed; no weights created"
            }
            exit `logit_rc'
        }

        * The treatment model had no convergence guard at all: a nonconverged
        * logit yields propensity scores that are not fitted probabilities, and
        * every IPTW/FIPTIW weight is built by dividing by them.
        if `__iivw_logit_converged' == 0 {
            _iivw_require_converged, model(treatment logit) ///
                `allownonconverged'
            local __iivw_nonconv = 1
        }

        quietly {
            merge m:1 `id' using `__iivw_psfile', nogen assert(match)

            * Warn about extreme propensity scores
            gen double `prefix'ps = `_ps_tmp'
            label variable `prefix'ps "Treatment propensity score"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'ps"

            summarize `prefix'ps, meanonly
            local ps_min = r(min)
            local ps_max = r(max)

            count if `prefix'ps < 0.01 & !missing(`prefix'ps)
            local n_ps_lo = r(N)
            count if `prefix'ps > 0.99 & !missing(`prefix'ps)
            local n_ps_hi = r(N)
            if `n_ps_lo' > 0 | `n_ps_hi' > 0 {
                local n_ps_extreme = `n_ps_lo' + `n_ps_hi'
                noisily display as text "note: `n_ps_extreme' observations have " ///
                    "extreme propensity scores (<0.01 or >0.99)"
                noisily display as text "  consider using truncate() to stabilize weights"
            }

            * Stabilized IPTW: prevalence over the propensity model's own sample
            * (computed inside the logit block above, where e(sample) is live).
            local p_treat = `__iivw_p_treat'

            gen double `prefix'tw = .
            replace `prefix'tw = `p_treat' / `prefix'ps ///
                if `treat' == 1 & !missing(`treat', `prefix'ps)
            replace `prefix'tw = (1 - `p_treat') / (1 - `prefix'ps) ///
                if `treat' == 0 & !missing(`treat', `prefix'ps)

            drop `_ps_tmp'
            label variable `prefix'tw "Inverse probability of treatment weight"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'tw"
        }
    }

    * =========================================================================
    * COMBINE WEIGHTS
    * =========================================================================

    quietly {
        if "`wtype'" == "fiptiw" {
            gen double `prefix'weight = `prefix'iw * `prefix'tw
            label variable `prefix'weight "FIPTIW weight (IIW x IPTW)"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'weight"
        }
        else if "`wtype'" == "iivw" {
            gen double `prefix'weight = `prefix'iw
            label variable `prefix'weight "IIW weight"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'weight"
        }
        else if "`wtype'" == "iptw" {
            gen double `prefix'weight = `prefix'tw
            label variable `prefix'weight "IPTW weight"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'weight"
        }
    }

    * =========================================================================
    * SAMPLE-LOSS CONTRACT
    * =========================================================================
    * A row with no final weight is a row that will be dropped from the outcome
    * fit. Until now that was a `Note:' in a long log, and iivw_fit then marked
    * those rows out without a word: the analysis silently became complete-case,
    * and if the missingness was differential by arm, the estimand silently
    * became a different one. rc 0, wrong population.
    *
    * So sample loss is now a decision the user makes, not one the package makes
    * for them. Missing weights are an ERROR by default. allowmissingweights is
    * the acknowledgment that a complete-case analysis is intended -- and even
    * then the loss, and its differential-by-arm component, is reported.

    quietly count if missing(`prefix'weight)
    local n_miss = r(N)
    local n_miss_ids = 0
    local arm_loss_msg ""

    if `n_miss' > 0 {
        tempvar _misstag
        quietly egen byte `_misstag' = tag(`id') if missing(`prefix'weight)
        quietly count if `_misstag' == 1
        local n_miss_ids = r(N)
        drop `_misstag'

        * Differential loss by treatment arm is the failure that changes the
        * estimand rather than merely shrinking the sample, so it is measured
        * and printed separately whenever an arm exists to measure it.
        if "`treat'" != "" {
            quietly count if `treat' == 1 & !missing(`treat')
            local n_arm1 = r(N)
            quietly count if `treat' == 0 & !missing(`treat')
            local n_arm0 = r(N)
            quietly count if `treat' == 1 & !missing(`treat') & missing(`prefix'weight)
            local n_lost1 = r(N)
            quietly count if `treat' == 0 & !missing(`treat') & missing(`prefix'weight)
            local n_lost0 = r(N)
            local pct1 = cond(`n_arm1' > 0, 100 * `n_lost1' / `n_arm1', 0)
            local pct0 = cond(`n_arm0' > 0, 100 * `n_lost0' / `n_arm0', 0)
            local arm_loss_msg ///
                "treated `n_lost1'/`n_arm1' (`=string(`pct1',"%4.1f")'%), untreated `n_lost0'/`n_arm0' (`=string(`pct0',"%4.1f")'%)"
        }

        if "`allowmissingweights'" == "" {
            display as error ""
            display as error "`n_miss' of `N' observations have no weight (`n_miss_ids' subjects affected)"
            if "`arm_loss_msg'" != "" {
                display as error "  loss by arm: `arm_loss_msg'"
            }
            display as error ""
            display as text "  A row with no weight is dropped from the outcome fit. The analysis"
            display as text "  would silently become complete-case, and if the loss is differential"
            display as text "  by arm it would silently target a different population than the one"
            display as text "  you asked about."
            display as text ""
            display as text "  A weight is missing when a row lacks an input the weight is built"
            display as text "  from: a visit-model covariate, a lag source at the first visit of a"
            display as text "  subject whose baseline is modeled as an event, a treatment-model"
            display as text "  covariate, or the treatment itself."
            display as text ""
            display as text "  Either complete or drop those rows, or add"
            display as text "    allowmissingweights"
            display as text "  to declare that a complete-case analysis is what you intend."
            exit 416
        }

        display as text ""
        display as text "note: `n_miss' of `N' observations have no weight (`n_miss_ids' subjects affected)"
        if "`arm_loss_msg'" != "" {
            display as text "  loss by arm: `arm_loss_msg'"
        }
        display as text "  allowmissingweights was specified: these rows will be dropped from the"
        display as text "  outcome fit and the analysis is complete-case."
    }

    * =========================================================================
    * TRUNCATION
    * =========================================================================

    local n_truncated = 0
    if "`truncate'" != "" {
        display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

        quietly {
            _pctile `prefix'weight if !missing(`prefix'weight), ///
                percentiles(`trunc_lo' `trunc_hi')
            local lo_val = r(r1)
            local hi_val = r(r2)

            count if `prefix'weight < `lo_val' & !missing(`prefix'weight)
            local n_lo = r(N)
            count if `prefix'weight > `hi_val' & !missing(`prefix'weight)
            local n_hi = r(N)
            local n_truncated = `n_lo' + `n_hi'

            replace `prefix'weight = `lo_val' ///
                if `prefix'weight < `lo_val' & !missing(`prefix'weight)
            replace `prefix'weight = `hi_val' ///
                if `prefix'weight > `hi_val' & !missing(`prefix'weight)
        }

        display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
    }

    * =========================================================================
    * DIAGNOSTICS
    * =========================================================================

    quietly summarize `prefix'weight, detail
    local w_mean = r(mean)
    local w_sd   = r(sd)
    local w_min  = r(min)
    local w_max  = r(max)
    local w_p1   = r(p1)
    local w_p50  = r(p50)
    local w_p99  = r(p99)

    * Effective sample size: (sum w)^2 / (sum w^2), Kish (1965).
    *
    * The ESS measures concentration among the rows that ACTUALLY CARRY A
    * WEIGHT. Rows whose weight is missing (an incomplete covariate, a missing
    * propensity score) contribute to neither sum, so dividing the ESS by the
    * total row count conflates two unrelated losses: variability among the
    * weighted rows, and rows that were never weighted at all. With 20 rows,
    * 4 missing propensity scores and all 16 usable weights exactly 1, the old
    * code reported "ESS 16.0 (of 20)" -- which reads as 20% concentration loss
    * when the true concentration loss is zero.
    *
    * So: report the missingness loss and the concentration loss separately,
    * and take the ESS ratio against the weighted rows, which is the only
    * denominator for which ESS/N == 1 means "no weight variability".
    quietly {
        summarize `prefix'weight
        local sum_w = r(sum)
        local n_weighted = r(N)
        tempvar _w2
        gen double `_w2' = `prefix'weight^2
        summarize `_w2'
        local sum_w2 = r(sum)
        drop `_w2'
    }
    local ess = (`sum_w'^2) / `sum_w2'

    local ess_ratio = .
    if `n_weighted' > 0 local ess_ratio = `ess' / `n_weighted'

    tempvar _wtag
    quietly egen byte `_wtag' = tag(`id') if !missing(`prefix'weight)
    quietly count if `_wtag' == 1
    local n_ids_weighted = r(N)
    drop `_wtag'

    local n_unweighted = `N' - `n_weighted'

    * =========================================================================
    * COMMIT: STORE METADATA
    * =========================================================================
    * Every model has succeeded and every output variable exists. Only now is
    * the prior contract cleared and rewritten. Downstream fit/diagnostic state
    * is invalidated at the same instant, because new weights make an old fit
    * meaningless -- a stale _iivw_fitted must never survive a reweight.

    * Clear the ENTIRE _iivw_ characteristic namespace, discovered from the data
    * rather than from a hand-maintained list. A list has to be edited every time
    * a field is added, and the one that was not edited is the one that leaks: an
    * omitted name keeps its value from the PREVIOUS contract and is then read
    * back by a consumer as if it described the weights just committed.
    local __iivw_allchars : char _dta[]
    foreach ch of local __iivw_allchars {
        if substr("`ch'", 1, 6) == "_iivw_" {
            char _dta[`ch'] ""
        }
    }

    char _dta[_iivw_weighted] "1"
    * Stamp a deliberately-accepted nonconverged nuisance model so downstream
    * commands can refuse these weights rather than treat them as clean.
    if `__iivw_nonconv' {
        char _dta[_iivw_nonconverged] "1"
    }
    char _dta[_iivw_id] "`id'"
    char _dta[_iivw_time] "`time'"
    char _dta[_iivw_weighttype] "`wtype'"
    char _dta[_iivw_weight_var] "`prefix'weight"
    char _dta[_iivw_prefix] "`prefix'"
    char _dta[_iivw_contract_version] "2"
    if inlist("`wtype'", "iivw", "fiptiw") {
        char _dta[_iivw_iw_var] "`prefix'iw"
        char _dta[_iivw_visit_covars] "`visit_covars'"
        char _dta[_iivw_baseevent] "`exclude_base'"

        * The RAW visit-model covariates and the GENERATED lag columns, stored
        * apart. visit_covars above is their union -- the design actually handed
        * to stcox -- and it is what a reporting consumer wants. A REPLAY wants
        * these two: it must pass the raw list to visit_cov() and the lag SOURCES
        * (below) to lagvars(), so each resampled subject rebuilds its own lags
        * from its own history. Handing it the union means handing it precomputed
        * *_lag1 columns as though they were raw inputs, which is the defect this
        * separation exists to make impossible.
        char _dta[_iivw_visit_cov_raw] "`visit_cov'"
        char _dta[_iivw_lag_names] "`=strtrim("`__iivw_lag_names'")'"

        * The risk-set specification travels with the weights. Every consumer
        * that refits the visit-intensity model -- the bootstrap replay, the
        * agrefit balance check, the exogeneity test -- must rebuild the SAME
        * risk set, or it silently reports on a different estimator than the one
        * that produced the weights.
        char _dta[_iivw_censor_mode] "`__iivw_cens_mode'"
        char _dta[_iivw_censor_var] "`censor'"
        char _dta[_iivw_maxfu] "`maxfu'"

        * The SOURCE variables behind any generated lag columns. A consumer that
        * rebuilds the censoring row cannot get its covariates right without
        * these: on the interval (last visit, C] the lagged covariate takes the
        * value AT the last visit, i.e. the source variable's own value on that
        * row -- NOT the lag column's value, which refers to the visit before it.
        char _dta[_iivw_lagvars] "`lagvars'"
    }
    else {
        char _dta[_iivw_iw_var] ""
        char _dta[_iivw_visit_covars] ""
        char _dta[_iivw_visit_cov_raw] ""
        char _dta[_iivw_lag_names] ""
    }
    if inlist("`wtype'", "iptw", "fiptiw") {
        char _dta[_iivw_tw_var] "`prefix'tw"
        char _dta[_iivw_ps_var] "`prefix'ps"
        char _dta[_iivw_treat] "`treat'"
        char _dta[_iivw_treat_covars] "`treat_covars'"
        char _dta[_iivw_ps_estimand] "ate"
    }
    else {
        char _dta[_iivw_tw_var] ""
        char _dta[_iivw_ps_var] ""
        char _dta[_iivw_treat] ""
        char _dta[_iivw_treat_covars] ""
        char _dta[_iivw_ps_estimand] ""
    }

    * Weight-construction replay spec: lets iivw_fit, refitweights reconstruct
    * the full weight computation inside each bootstrap replicate. Stored as the
    * exact option values so a resampled panel reproduces the same weighting.
    char _dta[_iivw_stabcov]  "`stabcov'"
    char _dta[_iivw_truncate] "`truncate'"
    char _dta[_iivw_efron]    "`efron_opt'"
    char _dta[_iivw_entry]    "`entry'"

    * Rows deliberately left without a weight. Recorded on the contract, not
    * just printed, so a consumer can say the analysis is complete-case rather
    * than discovering it by counting rows it silently marked out.
    if `n_miss' > 0 & "`allowmissingweights'" != "" {
        char _dta[_iivw_allowmissingweights] "1"
    }

    * ---------------------------------------------------------------------
    * Variable-level ownership. From here on, `replace' can prove what it is
    * allowed to overwrite instead of inferring it from a name.
    * ---------------------------------------------------------------------
    local __iivw_owned ""
    foreach __iivw_r in iw tw ps weight {
        capture confirm variable `prefix'`__iivw_r'
        if _rc == 0 {
            _iivw_own stamp `prefix'`__iivw_r', role(`__iivw_r') prefix(`prefix')
            local __iivw_owned "`__iivw_owned' `prefix'`__iivw_r'"
        }
    }
    foreach __iivw_l of local __iivw_lag_names {
        capture confirm variable `__iivw_l'
        if _rc == 0 {
            _iivw_own stamp `__iivw_l', role(lag)
            local __iivw_owned "`__iivw_owned' `__iivw_l'"
        }
    }
    char _dta[_iivw_owned] "`=strtrim("`__iivw_owned'")'"

    * Fingerprint the data these weights actually describe, so a consumer can
    * tell whether it is still looking at them. Stamped last, after every other
    * characteristic, because it binds the specification as well as the columns.
    * See _iivw_weight_signature.ado for what it does and does not guarantee.
    _iivw_weight_signature
    char _dta[_iivw_wsig] "`r(signature)'"

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================

    display as text ""
    display as text "Weight distribution:"
    display as text "  Mean:     " as result %9.4f `w_mean'
    display as text "  SD:       " as result %9.4f `w_sd'
    display as text "  Min:      " as result %9.4f `w_min'
    display as text "  Median:   " as result %9.4f `w_p50'
    display as text "  Max:      " as result %9.4f `w_max'
    display as text "  P1:       " as result %9.4f `w_p1'
    display as text "  P99:      " as result %9.4f `w_p99'
    display as text ""
    display as text "Observations:          " as result %9.0f `N' ///
        as text "  (weighted: " as result `n_weighted' as text ")"
    display as text "Subjects:              " as result %9.0f `n_ids' ///
        as text "  (weighted: " as result `n_ids_weighted' as text ")"
    display as text "Effective sample size: " as result %9.1f `ess' ///
        as text " (of " as result `n_weighted' as text " weighted rows)"
    if `ess_ratio' < . {
        display as text "  ESS / weighted rows: " as result %9.3f `ess_ratio' ///
            as text "  (1.0 = no weight variability)"
    }
    if `n_unweighted' > 0 {
        display as text ""
        display as text "Note: " as result `n_unweighted' as text " row(s) carry no weight (missing model inputs)."
        display as text "  That is a missing-data loss, not weight concentration; the two are"
        display as text "  reported separately. The ESS above describes only the weighted rows."
    }

    * Note the mean-1 normalization of the visit-intensity component
    if inlist("`wtype'", "iivw", "fiptiw") {
        display as text ""
        display as text "Note: IIW component normalized to mean 1"
        display as text "  (weighted point estimates and cluster-robust SEs are unchanged;"
        display as text "  the rescaling only makes the mean/ESS/max diagnostics interpretable)"
    }

    * Report the final mean descriptively. It is NOT a specification diagnostic:
    *
    *   - untruncated IIW is normalized to mean 1 above, so the check would be
    *     passed by construction and carries no information about model fit;
    *   - after truncate(), a departure from 1 is a mechanical consequence of
    *     clipping the tails, not evidence of a bad model;
    *   - for FIPTIW the mean is E[IIW x IPTW], which departs from 1 whenever the
    *     two components covary -- even when both models are correctly specified.
    *
    * The old text ("Consider checking model specification") drew a specification
    * conclusion from a quantity that cannot support one, in the one case
    * (truncation) where the cause was already known.
    if abs(`w_mean' - 1) > 0.2 {
        display as text ""
        display as text "Note: final weight mean is " as result %5.3f `w_mean' as text " (not 1)."
        if `n_truncated' > 0 {
            display as text "  truncate() clipped `n_truncated' weight(s); a mean away from 1 is the"
            display as text "  arithmetic consequence of that clipping."
        }
        else if "`wtype'" == "fiptiw" {
            display as text "  For FIPTIW the mean is E[IIW x IPTW], which departs from 1 whenever the"
            display as text "  visit and treatment weights covary. This is expected and is not by"
            display as text "  itself evidence of misspecification in either component."
        }
        else if "`wtype'" == "iptw" {
            display as text "  Stabilized IPTW has mean 1 only in expectation; sampling variation and"
            display as text "  positivity violations both move it. Inspect max_weight and the ESS."
        }
        display as text "  This is descriptive. Judge the visit model with `__iivw_smcl_lb'cmd:iivw_balance`__iivw_smcl_rb' and the"
        display as text "  treatment model with its own balance diagnostics; the weight mean tests neither."
    }

    * Nudge toward stabilized weights when the visit model is unstabilized.
    * Buzkova & Lumley (2007) recommend a stabilization numerator: it leaves the
    * estimand unchanged but typically lowers weight variance and ESS loss.
    if inlist("`wtype'", "iivw", "fiptiw") & "`stabcov'" == "" {
        display as text ""
        display as text "Note: visit weights are unstabilized (no stabcov() supplied)"
        display as text "  stabilized weights usually have lower variance and higher ESS;"
        display as text "  see stabcov() in `__iivw_smcl_lb'help iivw_weight`__iivw_smcl_rb'"
    }

    * List created variables
    local created_vars "`prefix'weight"
    if inlist("`wtype'", "iivw", "fiptiw") {
        local created_vars "`prefix'iw `created_vars'"
    }
    if inlist("`wtype'", "iptw", "fiptiw") {
        local created_vars "`prefix'ps `prefix'tw `created_vars'"
    }

    display as text ""
    display as text "Variables created: " as result "`created_vars'"
    display as text "Next step: `__iivw_smcl_lb'cmd:iivw_fit`__iivw_smcl_rb' to fit weighted outcome model"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar N = `N'
    return scalar n_ids = `n_ids'
    return scalar mean_weight = `w_mean'
    return scalar sd_weight = `w_sd'
    return scalar min_weight = `w_min'
    return scalar max_weight = `w_max'
    return scalar p1_weight = `w_p1'
    return scalar median_weight = `w_p50'
    return scalar p99_weight = `w_p99'
    return scalar ess = `ess'

    * ESS bookkeeping (H6). N/n_ids are totals; the *_weighted pair counts only
    * the rows that carry a weight, and ess_ratio is taken against those -- so
    * ess_ratio == 1 means "no weight variability" and nothing else. Rows lost to
    * missing model inputs are reported as n_unweighted, never folded into the ESS.
    return scalar N_total = `N'
    return scalar N_weighted = `n_weighted'
    return scalar n_unweighted = `n_unweighted'
    return scalar n_ids_total = `n_ids'
    return scalar n_ids_weighted = `n_ids_weighted'
    return scalar ess_ratio = `ess_ratio'

    * Sample-loss contract. n_unweighted above is the row count; these say WHO
    * was lost and whether the loss was differential by arm, which is the part
    * that changes the estimand rather than merely the precision.
    return scalar n_missing_weight = `n_miss'
    return scalar n_ids_missing_weight = `n_miss_ids'
    if "`treat'" != "" & `n_miss' > 0 {
        return scalar n_lost_treated = `n_lost1'
        return scalar n_lost_untreated = `n_lost0'
        return scalar pct_lost_treated = `pct1'
        return scalar pct_lost_untreated = `pct0'
    }
    return local allowmissingweights = ///
        cond(`n_miss' > 0 & "`allowmissingweights'" != "", "1", "0")

    return scalar n_truncated = `n_truncated'
    return scalar nobaseevent = `exclude_base'

    return local weighttype "`wtype'"
    return local weight_var "`prefix'weight"
    return local visit_covars "`visit_covars'"
    return local visit_cov_raw "`visit_cov'"
    return local lag_names "`=strtrim("`__iivw_lag_names'")'"
    return local lagvars "`lagvars'"
    return local owned "`=strtrim("`__iivw_owned'")'"
    if inlist("`wtype'", "iivw", "fiptiw") {
        return local iw_var "`prefix'iw"

        * The risk set is now an auditable part of the contract, not something
        * the user has to infer from a stset table that scrolled past.
        return local censor_mode "`__iivw_cens_mode'"
        if "`__iivw_cens_mode'" == "censor" return local censor_var "`censor'"
        if "`__iivw_cens_mode'" == "maxfu"  return scalar maxfu = `maxfu'
        return scalar n_censor_rows = `__iivw_n_cens_rows'
        return scalar visit_N = `__iivw_visit_N'
        return scalar visit_N_sub = `__iivw_visit_Nsub'
        return scalar stab_N = `__iivw_stab_N'
        return matrix visit_b = `__iivw_bmat'
    }
    if inlist("`wtype'", "iptw", "fiptiw") {
        return scalar ps_min = `ps_min'
        return scalar ps_max = `ps_max'
        return scalar n_ps_extreme = `n_ps_extreme'
        return scalar ps_N = `__iivw_ps_N'
        return scalar ps_prevalence = `__iivw_p_treat'
        return local ps_var "`prefix'ps"
        return local tw_var "`prefix'tw"
        return local treat_covars "`treat_covars'"
        return local ps_estimand "ate"
    }
    return local contract_version "2"

    }
    local rc = _rc
    * Defensive outer cleanup: normally each component unholds immediately,
    * but an unexpected preserve/restore failure must not strand the caller's
    * active estimation results.
    if `__iivw_visit_hold_ok' {
        capture _estimates unhold `__iivw_visit_est'
        local __iivw_unhold_rc = _rc
        if `rc' == 0 & `__iivw_unhold_rc' != 0 local rc = `__iivw_unhold_rc'
    }
    if `__iivw_logit_hold_ok' {
        capture _estimates unhold `__iivw_logit_est'
        local __iivw_unhold_rc = _rc
        if `rc' == 0 & `__iivw_unhold_rc' != 0 local rc = `__iivw_unhold_rc'
    }
    if `rc' != 0 {
        * Roll the name transaction back: drop everything this call created,
        * then rename the backups of the user's prior outputs into place. The
        * contract was never touched (it is rewritten only at the commit point),
        * so the pre-call weighting state is restored exactly.
        *
        * A rollback that itself fails leaves the data in a state that matches
        * NO contract -- the previous weights half-restored under names the
        * stored specification still claims. That is strictly worse than the
        * error that caused it, and it used to be invisible: the rename's return
        * code was captured into a local nobody read. It is now reported. The
        * PRIMARY return code is still the one that propagates -- the user needs
        * to know why the command failed, not merely that cleaning up after it
        * also failed -- but they are told, loudly, that the data is not intact.
        local __iivw_rollback_failed ""
        foreach v of local __iivw_created_vars {
            capture drop `v'
            if _rc local __iivw_rollback_failed "`__iivw_rollback_failed' `v'(not dropped)"
        }
        local __iivw_bi = 0
        foreach g of local __iivw_bk_names {
            local ++__iivw_bi
            local __iivw_bt : word `__iivw_bi' of `__iivw_bk_temps'
            capture drop `g'
            capture rename `__iivw_bt' `g'
            if _rc local __iivw_rollback_failed "`__iivw_rollback_failed' `g'(not restored)"
        }
        if "`__iivw_rollback_failed'" != "" {
            display as error ""
            display as error "iivw_weight: ROLLBACK FAILED -- the data in memory is not intact"
            display as error "  could not restore:`__iivw_rollback_failed'"
            display as error ""
            display as error "  Do not analyze this dataset. Reload it from disk."
            display as error "  (The command's own failure, reported above, is the return code.)"
        }
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end

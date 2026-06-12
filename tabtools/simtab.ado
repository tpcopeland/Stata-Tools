*! simtab Version 1.7.0  2026/06/13
*! Render and export a publication-ready Monte Carlo simulation performance table
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
DESCRIPTION:
    simtab renders and exports a publication-ready simulation performance
    table: scenario row groups, one row per estimator, one column group per
    estimand, with table-grade Monte Carlo performance measures. It owns the
    last mile -- merged multi-estimand group headers, scenario row grouping,
    themes, and one-call Excel / Markdown / CSV / frame output.

    simtab has two input modes:

      compute (default)  long replication-level results -> simtab computes
                         table-grade measures + cheap Monte Carlo SEs itself.
      ingest  (from())   a simsum / siman analyse / generic summary already in
                         memory -> simtab renders it as-is, no recomputation.

    simtab is NOT a full Monte Carlo analysis engine. For full performance
    analysis, Monte Carlo error theory, and diagnostic graphs (zipper,
    lollipop, nested-loop), use simsum (White, Stata Journal 2010) or siman
    (UCL). See help simtab for the scope statement and citations.
*/

program define simtab, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    local _book_open = 0
    capture noisily {

        capture putexcel close

        * ----- auto-load shared tabtools helper bundle -----
        capture _tabtools_helpers_ready
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
                capture _tabtools_helpers_ready
                if _rc {
                    display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                    exit 111
                }
            }
            else {
                display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }
        _tabtools_require_helpers

        syntax [anything(name=estimator)] [if] [in] , [           ///
            FROM(string)                                          ///
            ESTimate(varname numeric) SE(varname numeric) TRUE(string) ///
            BY(varname) ESTIMand(varname) SIM(varname)            ///
            METrics(string)                                       ///
            COVerage(varname numeric) LCi(varname numeric) UCi(varname numeric) ///
            PValue(varname numeric) REJect(varname numeric)       ///
            NSIM(integer -1)                                      ///
            LEVel(real 95) ALPha(real 0.05)                       ///
            MINreps(integer 2) WARNreps(integer 100)              ///
            ORDER(string)                                         ///
            DIGits(integer -1) PCTDIGits(integer 0) SEDIGits(integer -1) ///
            NOSIGn                                                ///
            XLSX(string) EXCEL(string) SHeet(string)              ///
            TItle(string) FOOTnote(string)                        ///
            FRAme(string) PLOTFrame(string)                       ///
            CSV(string) MARKdown(string) MDAPPend                 ///
            THEme(string) BORDERstyle(string)                     ///
            HEADERColor(string) ZEBRAColor(string)                ///
            HEADERShade ZEBRA                                     ///
            DISplay OPEN                                          ///
            BYVar(name) ESTIMATORVar(name) ESTIMANDVar(name) MEASures(string) ]

        * =====================================================================
        * Mode selection
        * =====================================================================
        local _from = strtrim(lower(`"`from'"'))
        local _ingest = (`"`_from'"' != "")
        if `_ingest' {
            if !inlist("`_from'", "simsum", "siman", "summary") {
                display as error `"from() must be one of: simsum, siman, summary"'
                exit 198
            }
            * Mode-conflict guard: compute-only options with from()
            local _conflict ""
            if `"`estimator'"' != "" local _conflict "`_conflict' a leading estimator"
            if `"`estimate'"'  != "" local _conflict "`_conflict' estimate()"
            if `"`se'"'        != "" local _conflict "`_conflict' se()"
            if `"`true'"'      != "" local _conflict "`_conflict' true()"
            if `"`coverage'"'  != "" local _conflict "`_conflict' coverage()"
            if `"`lci'"'       != "" local _conflict "`_conflict' lci()"
            if `"`uci'"'       != "" local _conflict "`_conflict' uci()"
            if `"`pvalue'"'    != "" local _conflict "`_conflict' pvalue()"
            if `"`reject'"'    != "" local _conflict "`_conflict' reject()"
            if `"`_conflict'"' != "" {
                display as error "compute-mode options ignored in ingest mode (from()):`_conflict'"
                display as error "drop these options, or remove from() to use compute mode"
                exit 198
            }
        }

        * =====================================================================
        * Output targets: require at least one
        * =====================================================================
        if `"`excel'"' != "" & `"`xlsx'"' == "" local xlsx `"`excel'"'
        local _has_xlsx = (`"`xlsx'"' != "")
        local _has_csv  = (`"`csv'"'  != "")
        local _has_md   = (`"`markdown'"' != "")
        local _has_frame = (`"`frame'"' != "")
        local _has_pframe = (`"`plotframe'"' != "")
        local _has_disp = ("`display'" != "")
        if !`_has_xlsx' & !`_has_csv' & !`_has_md' & !`_has_frame' & !`_has_pframe' & !`_has_disp' {
            display as error "specify at least one output target: xlsx(), csv(), markdown(), frame(), plotframe(), or display"
            exit 198
        }
        if "`open'" != "" & !`_has_xlsx' {
            display as error "open requires xlsx()/excel()"
            exit 198
        }
        if "`mdappend'" != "" & !`_has_md' {
            display as error "mdappend requires markdown()"
            exit 198
        }

        * ----- validate file extensions / paths / sheet -----
        if `_has_xlsx' {
            if !strmatch(lower(`"`xlsx'"'), "*.xlsx") {
                display as error "xlsx()/excel() file must have a .xlsx extension"
                exit 198
            }
            _tabtools_validate_path `"`xlsx'"' "xlsx()"
        }
        if "`sheet'" == "" local sheet "Simulation"
        if `_has_xlsx' _tabtools_validate_sheet "`sheet'" "sheet()"
        if `_has_csv' {
            if !strmatch(lower(`"`csv'"'), "*.csv") {
                display as error "csv() must have a .csv extension"
                exit 198
            }
            _tabtools_validate_path `"`csv'"' "csv()"
        }
        if `_has_md' {
            _tabtools_validate_path `"`markdown'"' "markdown()"
            local _md_lower = lower(`"`markdown'"')
            if !(strmatch(`"`_md_lower'"', "*.md") | strmatch(`"`_md_lower'"', "*.markdown") | ///
                 strmatch(`"`_md_lower'"', "*.qmd") | strmatch(`"`_md_lower'"', "*.rmd")) {
                display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
                exit 198
            }
        }

        * =====================================================================
        * Resolve digits / styling
        * =====================================================================
        if `digits' == -1 {
            if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
            else local digits = 2
        }
        if `digits' < 0 | `digits' > 6 {
            display as error "digits() must be between 0 and 6"
            exit 198
        }
        if `sedigits' == -1 local sedigits = `digits'
        if `sedigits' < 0 | `sedigits' > 6 {
            display as error "sedigits() must be between 0 and 6"
            exit 198
        }
        if `pctdigits' < 0 | `pctdigits' > 6 {
            display as error "pctdigits() must be between 0 and 6"
            exit 198
        }

        _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
            headershade(`headershade') zebra(`zebra')
        _tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

        * ----- order mode -----
        local order = strtrim(lower("`order'"))
        if "`order'" == "" local order "data"
        if !inlist("`order'", "data", "sort") {
            display as error "order() must be data or sort"
            exit 198
        }

        * =====================================================================
        * Validate level/alpha/reps
        * =====================================================================
        if `level' <= 0 | `level' >= 100 {
            display as error "level() must be strictly between 0 and 100"
            exit 198
        }
        if `alpha' <= 0 | `alpha' >= 1 {
            display as error "alpha() must be strictly between 0 and 1"
            exit 198
        }
        if `minreps' < 2 {
            display as error "minreps() must be at least 2 (empirical SE needs >= 2 replications)"
            exit 198
        }

        * =====================================================================
        * Resolve which metrics will be displayed
        * =====================================================================
        local _valid_tokens "mean bias pctbias empse meanse relerr mse rmse coverage power n nonconv"
        local metrics = strtrim(lower("`metrics'"))
        if "`metrics'" != "" {
            foreach _t of local metrics {
                if !`: list _t in _valid_tokens' {
                    display as error "invalid metrics() token: `_t'"
                    display as error "valid tokens: `_valid_tokens'"
                    exit 198
                }
            }
            local disp_metrics : list uniq metrics
        }
        * default filled below per mode (compute fixed default, ingest = available)

        if `: list posof "nonconv" in disp_metrics' & `nsim' < 0 {
            display as error "the nonconv metric requires nsim() to be set"
            exit 198
        }

        * =====================================================================
        * Build the per-cell summary (frame-agnostic schema) in memory
        *   summary columns produced by either branch:
        *     byord bylab estord estlab emdord emdlab n truev
        *     m_mean m_bias m_pctbias m_empse m_meanse m_relerr m_mse m_rmse
        *     m_coverage m_power m_nfail m_pctfail
        *     mc_mean mc_bias mc_pctbias mc_empse mc_mse mc_rmse mc_coverage mc_power
        *   plus locals: _has_by _has_emd _bylab_hdr _estlab_hdr _source
        * =====================================================================
        preserve
        local _restore_needed = 1

        if `_ingest' {
            * --------------------------------------------------------------
            * INGEST MODE  (delegate to the isolated adapter helper)
            * --------------------------------------------------------------
            capture _tabtools_simtab_ingest_ready
            if _rc {
                capture findfile _tabtools_simtab_ingest.ado
                if _rc == 0 {
                    run "`r(fn)'"
                }
                else {
                    display as error "_tabtools_simtab_ingest.ado not found; reinstall tabtools"
                    exit 111
                }
            }
            _tabtools_simtab_ingest, source("`_from'") byvar(`byvar') ///
                estimatorvar(`estimatorvar') estimandvar(`estimandvar') ///
                measures(`measures')
            local _source   "`r(source)'"
            local _has_by   = `r(has_by)'
            local _has_emd  = `r(has_emd)'
            local _avail    "`r(measures)'"
            local _bylab_hdr "`r(by_header)'"
            local _estlab_hdr "`r(est_header)'"
            * default metrics in ingest = available display tokens, in canonical order
            if "`disp_metrics'" == "" {
                local disp_metrics ""
                foreach _t of local _valid_tokens {
                    if `: list _t in _avail' local disp_metrics "`disp_metrics' `_t'"
                }
                local disp_metrics = strtrim("`disp_metrics'")
            }
            * warn for requested-but-unavailable metrics
            foreach _t of local disp_metrics {
                if !`: list _t in _avail' & "`_t'" != "n" {
                    display as text "note: metric `_t' is not available in the ingested summary; cells will be blank"
                }
            }
        }
        else {
            * --------------------------------------------------------------
            * COMPUTE MODE
            * --------------------------------------------------------------
            local _source "compute"
            if "`disp_metrics'" == "" local disp_metrics "mean bias empse meanse coverage n"

            * ----- required compute inputs -----
            if `"`estimator'"' == "" {
                display as error "compute mode requires a leading estimator variable"
                exit 198
            }
            confirm variable `estimator'
            local _n_est_words : word count `estimator'
            if `_n_est_words' > 1 {
                display as error "specify exactly one estimator variable"
                exit 198
            }
            if `"`estimate'"' == "" {
                display as error "compute mode requires estimate()"
                exit 198
            }
            if `"`se'"' == "" {
                display as error "compute mode requires se()"
                exit 198
            }
            if `"`true'"' == "" {
                display as error "compute mode requires true()"
                exit 198
            }

            local _has_by  = (`"`by'"' != "")
            local _has_emd = (`"`estimand'"' != "")

            * ----- header labels -----
            local _estlab_hdr : variable label `estimator'
            if `"`_estlab_hdr'"' == "" local _estlab_hdr "`estimator'"
            if `_has_by' {
                local _bylab_hdr : variable label `by'
                if `"`_bylab_hdr'"' == "" local _bylab_hdr "`by'"
            }
            else local _bylab_hdr ""

            * ----- which metrics need which sources -----
            local _need_cov  = `: list posof "coverage" in disp_metrics'
            local _need_pow  = `: list posof "power" in disp_metrics'

            * ----- resolve true() literal vs varname -----
            local _truenum = real("`true'")
            local _true_isvar = 0
            if regexm(`"`true'"', "[a-zA-Z_]") {
                local _true_isvar = 1
            }
            if `_true_isvar' {
                confirm variable `true'
                local _truevar "`true'"
            }
            else {
                if "`_truenum'" == "." {
                    display as error "true() must be a number or a variable name"
                    exit 198
                }
            }

            * ----- mark usable rows -----
            marksample touse, novarlist
            markout `touse' `estimator' `estimate' `se'
            if `_true_isvar' markout `touse' `_truevar'
            if `_has_by'  markout `touse' `by'
            if `_has_emd' markout `touse' `estimand'
            if `_need_cov' & `"`coverage'"' != "" markout `touse' `coverage'
            if `_need_cov' & `"`coverage'"' == "" & `"`lci'"' != "" & `"`uci'"' != "" {
                markout `touse' `lci' `uci'
            }

            quietly count if `touse'
            if r(N) == 0 {
                display as error "no usable observations after applying if/in and dropping missing required values"
                exit 2000
            }
            quietly keep if `touse'

            * ----- negative SE guard -----
            quietly count if `se' < 0
            if r(N) > 0 {
                display as error "se() contains `r(N)' negative value(s); standard errors must be nonnegative"
                exit 198
            }

            * ----- true-value variable -----
            tempvar truev
            if `_true_isvar' {
                quietly gen double `truev' = `_truevar'
            }
            else {
                quietly gen double `truev' = `_truenum'
            }

            * ----- grouping ord/label variables -----
            tempvar _seq
            quietly gen long `_seq' = _n

            * by
            tempvar byord
            quietly gen str244 bylab = ""
            if `_has_by' {
                _simtab_levels `by' `byord' bylab `_seq' "`order'"
            }
            else {
                quietly gen byte `byord' = 1
            }
            * estimator
            tempvar estord
            quietly gen str244 estlab = ""
            _simtab_levels `estimator' `estord' estlab `_seq' "`order'"
            * estimand
            tempvar emdord
            quietly gen str244 emdlab = ""
            if `_has_emd' {
                _simtab_levels `estimand' `emdord' emdlab `_seq' "`order'"
            }
            else {
                quietly gen byte `emdord' = 1
            }

            * ----- duplicate check (sim) -----
            if `"`sim'"' != "" {
                tempvar _ndup
                quietly bysort `byord' `estord' `emdord' `sim' : gen long `_ndup' = _N
                quietly count if `_ndup' > 1
                if r(N) > 0 {
                    display as error "duplicate rows found for sim() x by() x estimator x estimand(); each replication-cell must be unique"
                    exit 459
                }
            }

            * ----- true-value invariance within by x estimand -----
            tempvar _tmin _tmax
            quietly egen double `_tmin' = min(`truev'), by(`byord' `emdord')
            quietly egen double `_tmax' = max(`truev'), by(`byord' `emdord')
            quietly count if reldif(`_tmin', `_tmax') > 1e-9 & !missing(`_tmin', `_tmax')
            if r(N) > 0 {
                display as error "true value varies within a by() x estimand() cell; the target must be constant across estimators and replications in each cell"
                exit 459
            }

            * ----- coverage indicator -----
            tempvar covered
            quietly gen byte `covered' = .
            if `"`coverage'"' != "" {
                quietly replace `covered' = (`coverage' != 0) if !missing(`coverage')
            }
            else if `"`lci'"' != "" & `"`uci'"' != "" {
                quietly replace `covered' = (`lci' <= `truev' & `truev' <= `uci') if !missing(`lci', `uci', `truev')
            }
            else {
                local _zc = invnormal(1 - (1 - `level'/100)/2)
                quietly replace `covered' = (`estimate' - `_zc'*`se' <= `truev' & `truev' <= `estimate' + `_zc'*`se') if !missing(`estimate', `se', `truev')
            }
            if `_need_cov' {
                quietly count if !missing(`covered')
                if r(N) == 0 {
                    display as error "coverage requested but no valid coverage source (coverage(), lci()/uci(), or estimate()+se()) available"
                    exit 198
                }
            }

            * ----- rejection indicator (power) -----
            tempvar rejected
            quietly gen byte `rejected' = .
            if `_need_pow' {
                if `"`reject'"' != "" {
                    quietly replace `rejected' = (`reject' != 0) if !missing(`reject')
                }
                else if `"`pvalue'"' != "" {
                    quietly replace `rejected' = (`pvalue' < `alpha') if !missing(`pvalue')
                }
                else {
                    display as error "power requested but neither reject() nor pvalue() was supplied"
                    exit 198
                }
            }

            * ----- squared deviation for MSE -----
            tempvar sqdev
            quietly gen double `sqdev' = (`estimate' - `truev')^2

            * ----- collapse to cell level -----
            collapse (count) n=`estimate' (mean) m_mean=`estimate' m_meanse=`se' ///
                truev=`truev' m_coverage=`covered' m_power=`rejected' m_mse=`sqdev' ///
                (sd) m_empse=`estimate' _sd_sqdev=`sqdev', ///
                by(`byord' bylab `estord' estlab `emdord' emdlab)

            rename `byord' byord
            rename `estord' estord
            rename `emdord' emdord

            * ----- derived metrics -----
            quietly gen double m_bias    = m_mean - truev
            quietly gen double m_pctbias = 100*m_bias/truev
            quietly gen double m_rmse    = sqrt(m_mse)
            quietly gen double m_relerr  = 100*(m_meanse/m_empse - 1)
            quietly gen double m_nfail   = .
            quietly gen double m_pctfail = .
            if `nsim' >= 0 {
                quietly summarize n, meanonly
                if r(max) > `nsim' {
                    display as error "nsim() (`nsim') is less than the usable replications in a cell (`=r(max)'); nsim() must be at least the per-cell replication count"
                    exit 198
                }
                quietly replace m_nfail   = `nsim' - n
                quietly replace m_pctfail = 100*m_nfail/`nsim'
            }

            * ----- Monte Carlo SEs -----
            quietly gen double mc_mean     = m_empse/sqrt(n)
            quietly gen double mc_bias     = mc_mean
            quietly gen double mc_empse    = m_empse/sqrt(2*(n-1))
            quietly gen double mc_pctbias  = 100*mc_bias/abs(truev)
            quietly gen double mc_mse      = _sd_sqdev/sqrt(n)
            quietly gen double mc_rmse     = .
            quietly replace    mc_rmse     = mc_mse/(2*m_rmse) if m_rmse > 0 & !missing(m_rmse)
            quietly gen double mc_coverage = sqrt(m_coverage*(1-m_coverage)/n)
            quietly gen double mc_power    = sqrt(m_power*(1-m_power)/n)
            quietly drop _sd_sqdev

            * ----- validation against requested metrics -----
            quietly summarize n, meanonly
            local _nmin = r(min)
            local _nmax = r(max)
            if `_nmin' < `minreps' {
                display as error "a cell has only `_nmin' usable replication(s) (minreps = `minreps'); empirical SE is undefined"
                exit 2001
            }
            if `: list posof "pctbias" in disp_metrics' {
                quietly count if truev == 0
                if r(N) > 0 {
                    display as error "pctbias requested but the true value is zero in `r(N)' cell(s); percent bias is undefined"
                    exit 198
                }
            }
            if `: list posof "relerr" in disp_metrics' {
                quietly count if m_empse == 0
                if r(N) > 0 {
                    display as error "relerr requested but empirical SE is zero in `r(N)' cell(s); relative SE error is undefined"
                    exit 198
                }
            }

            local _avail "mean bias pctbias empse meanse relerr mse rmse coverage power n"
            if `nsim' >= 0 local _avail "`_avail' nonconv"
        }

        * =====================================================================
        * COMMON: validation, warnings, formatting, layout, export
        * =====================================================================
        * ----- level dimensions -----
        quietly summarize byord, meanonly
        local _Nby = r(max)
        quietly summarize estord, meanonly
        local _Nest = r(max)
        quietly summarize emdord, meanonly
        local _Nemd = r(max)
        local _D : word count `disp_metrics'
        local _lead = cond(`_has_by', 2, 1)
        local _Kcols = `_lead' + `_D'*`_Nemd'

        * ----- low-precision warning (compute mode) -----
        if !`_ingest' {
            quietly count if n < `warnreps'
            if r(N) > 0 {
                display as text "note: `r(N)' cell(s) have fewer than `warnreps' replications; Monte Carlo precision is low"
            }
        }

        * ----- coverage off-nominal flag -----
        local _has_covflag = 0
        if `: list posof "coverage" in disp_metrics' {
            capture confirm variable m_coverage
            if !_rc {
                capture confirm variable mc_coverage
                if !_rc {
                    quietly gen byte covflag = abs(m_coverage - `level'/100) > 2*mc_coverage ///
                        & !missing(m_coverage, mc_coverage)
                    quietly count if covflag
                    if r(N) > 0 {
                        local _has_covflag = 1
                        * warn naming each flagged cell
                        quietly count
                        local _NN = r(N)
                        forvalues _ci = 1/`_NN' {
                            if covflag[`_ci'] == 1 {
                                local _cb = bylab[`_ci']
                                local _ce = estlab[`_ci']
                                local _cm = emdlab[`_ci']
                                local _cv = string(m_coverage[`_ci']*100, "%4.1f")
                                local _cell "estimator `_ce'"
                                if `_has_by'  local _cell "`_cell', scenario `_cb'"
                                if `_Nemd' > 1 local _cell "`_cell', estimand `_cm'"
                                display as text "note: coverage `_cv'% is off-nominal (`_cell')"
                            }
                        }
                    }
                }
            }
        }

        * =====================================================================
        * Build plotframe (numeric companion) BEFORE formatting strings
        * =====================================================================
        if `_has_pframe' {
            _simtab_plotframe, spec(`"`plotframe'"') nemd(`_Nemd') level(`level') ///
                alpha(`alpha') nsim(`nsim') metrics(`"`disp_metrics'"') source(`_source')
            local _pframe_name "`r(plotframe)'"
        }

        * =====================================================================
        * Format display strings f1..fD for each displayed metric
        * =====================================================================
        local _mi = 0
        foreach tok of local disp_metrics {
            local ++_mi
            local _sf 1
            local _suf ""
            local _sgn 0
            local _dec `digits'
            local _vv ""
            local _lbl ""
            if "`tok'" == "mean"     local _vv m_mean
            if "`tok'" == "bias"     local _vv m_bias
            if "`tok'" == "pctbias"  local _vv m_pctbias
            if "`tok'" == "empse"    local _vv m_empse
            if "`tok'" == "meanse"   local _vv m_meanse
            if "`tok'" == "relerr"   local _vv m_relerr
            if "`tok'" == "mse"      local _vv m_mse
            if "`tok'" == "rmse"     local _vv m_rmse
            if "`tok'" == "coverage" local _vv m_coverage
            if "`tok'" == "power"    local _vv m_power
            if "`tok'" == "n"        local _vv n
            if "`tok'" == "nonconv"  local _vv m_nfail

            if "`tok'" == "mean"     local _lbl "Mean"
            if "`tok'" == "bias"     local _lbl "Bias"
            if "`tok'" == "pctbias"  local _lbl "% Bias"
            if "`tok'" == "empse"    local _lbl "Emp. SE"
            if "`tok'" == "meanse"   local _lbl "Mean SE"
            if "`tok'" == "relerr"   local _lbl "Rel. SE error"
            if "`tok'" == "mse"      local _lbl "MSE"
            if "`tok'" == "rmse"     local _lbl "RMSE"
            if "`tok'" == "coverage" local _lbl "Coverage"
            if "`tok'" == "power"    local _lbl "Power"
            if "`tok'" == "n"        local _lbl "N"
            if "`tok'" == "nonconv"  local _lbl "Non-conv."

            if inlist("`tok'", "bias", "pctbias", "relerr") local _sgn 1
            if inlist("`tok'", "pctbias", "relerr", "coverage", "power") local _suf "%"
            if inlist("`tok'", "coverage", "power") local _sf 100
            if inlist("`tok'", "empse", "meanse", "rmse") local _dec `sedigits'
            if inlist("`tok'", "pctbias", "relerr", "coverage", "power") local _dec `pctdigits'
            if inlist("`tok'", "n", "nonconv") local _dec 0

            local metriclbl`_mi' "`_lbl'"
            capture confirm variable `_vv'
            if _rc {
                * metric value not present (ingest gap) -> blank column
                quietly gen str1 f`_mi' = ""
                continue
            }
            local _fmt "%20.`_dec'f"
            quietly gen str244 f`_mi' = ""
            quietly replace f`_mi' = strtrim(string(`_vv'*`_sf', "`_fmt'")) if !missing(`_vv')
            if `_sgn' quietly replace f`_mi' = "+" + f`_mi' if `_vv' > 0 & !missing(`_vv')
            if "`_suf'" != "" quietly replace f`_mi' = f`_mi' + "`_suf'" if f`_mi' != ""
            if "`tok'" == "coverage" & `_has_covflag' {
                quietly replace f`_mi' = f`_mi' + "*" if covflag == 1 & f`_mi' != ""
            }
        }

        * ----- keep only what the renderer needs; save to tempfile -----
        keep byord bylab estord estlab emdord emdlab f1-f`_D'
        tempfile _summ
        quietly save `"`_summ'"', replace

        * ----- pass layout parameters to Mata via locals -----
        local _leadhdr_by  `"`_bylab_hdr'"'
        local _leadhdr_est `"`_estlab_hdr'"'
        if `"`_leadhdr_est'"' == "" local _leadhdr_est "Estimator"
        if `_has_by' & `"`_leadhdr_by'"' == "" local _leadhdr_by "Group"
        local _has_title = (`"`title'"' != "")
        local _has_foot  = (`"`footnote'"' != "")

        local _fvars ""
        forvalues j = 1/`_D' {
            local _fvars "`_fvars' f`j'"
        }

        * =====================================================================
        * FLAT outputs (console / csv / frame / markdown)
        * =====================================================================
        local _need_flat = `_has_csv' | `_has_md' | `_has_frame' | `_has_disp'
        local _ret_md ""
        local _ret_md_rows .
        local _ret_md_cols .
        if `_need_flat' {
            use `"`_summ'"', clear
            mata: _simtab_build(1, `_lead', `_Nby', `_Nest', `_Nemd', `_D', ///
                `_has_title', `_has_foot')

            * flat layout row indices
            local _ft_hdr  = `_has_title' + 1
            local _ft_data = `_ft_hdr' + 1

            * ----- CSV (full table, incl. footnote row) -----
            if `_has_csv' {
                export delimited using `"`csv'"', replace novarnames
                capture confirm file `"`csv'"'
                if _rc {
                    display as error "CSV export completed but file was not created"
                    exit 601
                }
            }
            * ----- frame (full table, incl. footnote row) -----
            if `_has_frame' {
                _tabtools_frame_put `"`frame'"'
                local _frame_out "`_frame_name'"
                frame `_frame_out': char _dta[tabtools_source] "simtab"
                frame `_frame_out': char _dta[tabtools_kind] "rendered_table"
                frame `_frame_out': char _dta[tabtools_metrics] "`disp_metrics'"
            }
            * ----- console display -----
            * drop the footnote row first: in `list, table' a long footnote in
            * c1 would otherwise inflate the whole first column's width.
            if `_has_disp' {
                if `_has_foot' quietly drop in L
                noisily _tabtools_console_display `_Kcols' `"`title'"', ///
                    datastart(`_ft_data') headerstart(`_ft_hdr')
                if `"`footnote'"' != "" noisily display as text `"`footnote'"'
            }
            * ----- markdown (last: drops remaining title/footnote rows) -----
            if `_has_md' {
                if `_has_foot' & !`_has_disp' quietly drop in L
                if `_has_title' quietly drop in 1
                local _mdappend_opt ""
                if "`mdappend'" != "" local _mdappend_opt "append"
                capture noisily _tabtools_markdown_write using `"`markdown'"', ///
                    `_mdappend_opt' headerstart(1) datastart(2) ///
                    title(`"`title'"') footnote(`"`footnote'"')
                if _rc {
                    local _md_rc = _rc
                    display as error "Failed to export Markdown to `markdown'"
                    exit `_md_rc'
                }
                local _ret_md `"`markdown'"'
                local _ret_md_rows = r(n_rows)
                local _ret_md_cols = r(n_cols)
                display as text "Markdown exported to `markdown'"
            }
        }

        * =====================================================================
        * EXCEL output (merged group headers)
        * =====================================================================
        local _ret_xlsx ""
        if `_has_xlsx' {
            use `"`_summ'"', clear
            mata: _simtab_build(2, `_lead', `_Nby', `_Nest', `_Nemd', `_D', ///
                `_has_title', `_has_foot')

            * excel layout row indices
            local _xl_grp  = cond(`_Nemd' > 1, `_has_title' + 1, 0)
            local _xl_hdr  = `_has_title' + cond(`_Nemd' > 1, 1, 0) + 1
            local _xl_data = `_xl_hdr' + 1
            local _xl_dbot = _N - `_has_foot'
            local _xl_foot = cond(`_has_foot', _N, 0)
            local _xl_rows = _N
            local _xl_ctot = `_Kcols' + 1

            * ----- column widths -----
            local _xlsx_widths ""
            forvalues j = 2/`_xl_ctot' {
                tempvar _len
                quietly gen long `_len' = length(c`j')
                quietly summarize `_len' if c`j' != "" & inrange(_n, `_xl_hdr', `_xl_dbot'), meanonly
                local _w = cond(r(N) > 0, ceil(r(max) * 0.95) + 2, 10)
                if `j' - 1 <= `_lead' {
                    if `_w' < 12 local _w = 12
                    if `_w' > 50 local _w = 50
                }
                else {
                    if `_w' < 8  local _w = 8
                    if `_w' > 28 local _w = 28
                }
                quietly drop `_len'
                local _xlsx_widths "`_xlsx_widths' `_w'"
            }

            * ----- border codes -----
            local _hbc = 1
            if "`_hborder'" == "medium" local _hbc = 2
            if "`_hborder'" == "thick"  local _hbc = 3
            if "`_hborder'" == "none"   local _hbc = 4

            * ----- write the sheet -----
            _tabtools_xlsx_write using `"`xlsx'"', sheet(`"`sheet'"') book(b)
            local _book_open = 1

            * ----- build style rules -----
            tempname _rules
            * spacer column A (width 1)
            local _spec "13 1 1 1 1 1 0 0 0"
            * content column widths starting at col 2
            local _wcol = 2
            foreach _w of local _xlsx_widths {
                local _spec `"`_spec' | 13 1 1 `_wcol' `_wcol' `_w' 0 0 0"'
                local ++_wcol
            }
            * base font + valign center over all
            local _spec `"`_spec' | 1 1 `_xl_rows' 1 `_xl_ctot' `_fontsize' 1 0 0 | 6 1 `_xl_rows' 1 `_xl_ctot' 0 2 0 0"'
            * data alignment: lead left, metric right
            local _spec `"`_spec' | 5 `_xl_data' `_xl_dbot' 2 `=`_lead'+1' 0 1 0 0"'
            if `_Kcols' > `_lead' {
                local _spec `"`_spec' | 5 `_xl_data' `_xl_dbot' `=`_lead'+2' `_xl_ctot' 0 3 0 0"'
            }
            * title row
            if `_has_title' {
                local _spec `"`_spec' | 14 1 1 1 `_xl_ctot' 0 0 0 0 | 1 1 1 1 `_xl_ctot' `=`_fontsize'+2' 1 0 0 | 2 1 1 1 `_xl_ctot' 0 1 0 0 | 5 1 1 1 `_xl_ctot' 0 1 0 0"'
            }
            * group header row (merge each estimand block)
            if `_xl_grp' > 0 {
                forvalues e = 1/`_Nemd' {
                    local _gc1 = 1 + `_lead' + (`e'-1)*`_D' + 1
                    local _gc2 = 1 + `_lead' + `e'*`_D'
                    local _spec `"`_spec' | 14 `_xl_grp' `_xl_grp' `_gc1' `_gc2' 0 0 0 0 | 2 `_xl_grp' `_xl_grp' `_gc1' `_gc1' 0 1 0 0 | 5 `_xl_grp' `_xl_grp' `_gc1' `_gc1' 0 2 0 0"'
                }
                local _spec `"`_spec' | 9 `_xl_grp' `_xl_grp' 2 `_xl_ctot' 0 `_hbc' 0 0"'
            }
            * metric header row: bold; lead headers left, metric headers center
            local _spec `"`_spec' | 2 `_xl_hdr' `_xl_hdr' 2 `_xl_ctot' 0 1 0 0 | 5 `_xl_hdr' `_xl_hdr' 2 `=`_lead'+1' 0 1 0 0"'
            if `_Kcols' > `_lead' {
                local _spec `"`_spec' | 5 `_xl_hdr' `_xl_hdr' `=`_lead'+2' `_xl_ctot' 0 2 0 0"'
            }
            * header shading
            if "`headershade'" != "" {
                local _hs_top = cond(`_xl_grp' > 0, `_xl_grp', `_xl_hdr')
                local _spec `"`_spec' | 7 `_hs_top' `_xl_hdr' 2 `_xl_ctot' 0 -1 0 0"'
            }
            * horizontal rules
            local _hdr_top = cond(`_xl_grp' > 0, `_xl_grp', `_xl_hdr')
            local _spec `"`_spec' | 8 `_hdr_top' `_hdr_top' 2 `_xl_ctot' 0 `_hbc' 0 0 | 9 `_xl_hdr' `_xl_hdr' 2 `_xl_ctot' 0 `_hbc' 0 0 | 9 `_xl_dbot' `_xl_dbot' 2 `_xl_ctot' 0 `_hbc' 0 0"'
            * vertical separators
            if `_has_by' {
                local _spec `"`_spec' | 11 `_hdr_top' `_xl_dbot' 2 2 0 `_hbc' 0 0"'
            }
            local _spec `"`_spec' | 11 `_hdr_top' `_xl_dbot' `=`_lead'+1' `=`_lead'+1' 0 `_hbc' 0 0"'
            if `_Nemd' > 1 {
                forvalues e = 1/`=`_Nemd'-1' {
                    local _emd_rc = 1 + `_lead' + `e'*`_D'
                    local _spec `"`_spec' | 11 `_hdr_top' `_xl_dbot' `_emd_rc' `_emd_rc' 0 `_hbc' 0 0"'
                }
            }
            * outside box borders
            local _spec `"`_spec' | 10 `_hdr_top' `_xl_dbot' 2 2 0 `_hbc' 0 0 | 11 `_hdr_top' `_xl_dbot' `_xl_ctot' `_xl_ctot' 0 `_hbc' 0 0"'
            * scenario group separators
            if `_has_by' & `_Nby' > 1 {
                forvalues b = 2/`_Nby' {
                    local _gr = `_xl_data' + (`b'-1)*`_Nest'
                    local _spec `"`_spec' | 8 `_gr' `_gr' 2 `_xl_ctot' 0 1 0 0"'
                }
            }
            * zebra striping over data rows
            if "`zebra'" != "" {
                forvalues _zr = `=`_xl_data'+1'(2)`_xl_dbot' {
                    local _spec `"`_spec' | 7 `_zr' `_zr' 2 `_xl_ctot' 0 -2 0 0"'
                }
            }
            * footnote row (aligned with the table box left border, column 2)
            if `_xl_foot' > 0 {
                local _fnsz = max(`_fontsize' - 2, 6)
                local _spec `"`_spec' | 14 `_xl_foot' `_xl_foot' 2 `_xl_ctot' 0 0 0 0 | 1 `_xl_foot' `_xl_foot' 2 `_xl_ctot' `_fnsz' 1 0 0 | 3 `_xl_foot' `_xl_foot' 2 `_xl_ctot' 0 1 0 0 | 5 `_xl_foot' `_xl_foot' 2 `_xl_ctot' 0 1 0 0"'
            }

            _tabtools_xlsx_build_styles, matrix(`_rules') rules(`"`_spec'"') cols(9)
            _tabtools_xlsx_apply_styles, book(b) sheet(`"`sheet'"') ///
                rules(`_rules') font("`_font'") ///
                color1("`_headercolor'") color2("`_zebracolor'")

            mata: b.close_book()
            local _book_open = 0
            capture mata: mata drop b

            capture confirm file `"`xlsx'"'
            if _rc {
                display as error "export command succeeded but file `xlsx' was not found"
                exit 601
            }
            local _ret_xlsx `"`xlsx'"'
            display as text "simtab: wrote " as result "`=`_xl_dbot'-`_xl_data'+1'" ///
                as text " data rows x " as result "`_Kcols'" as text " cols to sheet " ///
                as result `"`sheet'"' as text " in " as result `"`xlsx'"'
        }

        * ----- stash returns to post after cleanup -----
        local _ret_mode    = cond(`_ingest', "ingest", "compute")
        local _ret_source  "`_source'"
        local _ret_ncells  = `_Nby'*`_Nest'*`_Nemd'
        local _ret_nby     = `_Nby'
        local _ret_nest    = `_Nest'
        local _ret_nemd    = `_Nemd'
        local _ret_metrics "`disp_metrics'"
        local _ret_level   = `level'
        local _ret_alpha   = `alpha'
        local _ret_frame   "`_frame_out'"
        local _ret_pframe  "`_pframe_name'"
        local _ret_csv     `"`csv'"'
        local _ret_sheet   `"`sheet'"'
        if !`_ingest' {
            local _ret_nmin = `_nmin'
            local _ret_nmax = `_nmax'
        }
        local _ret_nfailmax .
        if !`_ingest' & `nsim' >= 0 local _ret_nfailmax = `nsim' - `_nmin'
        local _ret_methods "simtab `_ret_mode' mode (source: `_source'); metrics: `disp_metrics'; coverage level `level'%."
    }
    local rc = _rc
    if `_book_open' {
        capture mata: b.close_book()
    }
    capture mata: mata drop b
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' {
        if `rc' == 603 | `rc' == 608 | `rc' == 610 {
            noisily display as error "Hint: ensure the xlsx file is not open in another application"
        }
        exit `rc'
    }

    * =====================================================================
    * Post returns
    * =====================================================================
    return local mode    "`_ret_mode'"
    return local source  "`_ret_source'"
    return local methods "`_ret_methods'"
    return local metrics "`_ret_metrics'"
    return scalar n_estimands = `_ret_nemd'
    return scalar n_estimators = `_ret_nest'
    return scalar n_by = `_ret_nby'
    return scalar N_cells = `_ret_ncells'
    return scalar level = `_ret_level'
    return scalar alpha = `_ret_alpha'
    if "`_ret_mode'" == "compute" {
        return scalar n_reps_min = `_ret_nmin'
        return scalar n_reps_max = `_ret_nmax'
        if `_ret_nfailmax' < . return scalar n_fail_max = `_ret_nfailmax'
    }
    if `"`_ret_frame'"' != ""  return local frame "`_ret_frame'"
    if `"`_ret_pframe'"' != "" return local plotframe "`_ret_pframe'"
    if `"`_ret_xlsx'"' != "" {
        return local xlsx `"`_ret_xlsx'"'
        return local sheet `"`_ret_sheet'"'
    }
    if `"`_ret_csv'"' != "" return local csv `"`_ret_csv'"'
    if `"`_ret_md'"' != "" {
        return local markdown `"`_ret_md'"'
        return scalar markdown_rows = `_ret_md_rows'
        return scalar markdown_cols = `_ret_md_cols'
    }

    if "`open'" != "" & `"`_ret_xlsx'"' != "" _tabtools_open_file `"`_ret_xlsx'"'
end


* ============================================================================
* _simtab_levels: assign 1..L ordering ids + string labels for a grouping var
*   order(data) -> first-occurrence order ; order(sort) -> sorted
* ============================================================================
capture program drop _simtab_levels
program _simtab_levels
    version 16.0
    args var ordvar labvar seq mode

    * build a string label column
    capture confirm string variable `var'
    if !_rc {
        quietly replace `labvar' = `var'
    }
    else {
        local _vl : value label `var'
        if "`_vl'" != "" {
            quietly replace `labvar' = strtrim(string(`var'))
            * map through value label where it exists
            tempvar _maplab
            quietly decode `var', generate(`_maplab')
            quietly replace `labvar' = `_maplab' if !missing(`_maplab')
            quietly drop `_maplab'
        }
        else {
            quietly replace `labvar' = strtrim(string(`var', "%14.0g"))
        }
    }

    if "`mode'" == "sort" {
        capture confirm string variable `var'
        if !_rc {
            quietly egen long `ordvar' = group(`var')
        }
        else {
            quietly egen long `ordvar' = group(`var')
        }
    }
    else {
        * first-occurrence order: rank labels by min original sequence
        tempvar _gmin
        quietly egen long `_gmin' = min(`seq'), by(`labvar')
        quietly egen long `ordvar' = group(`_gmin')
        quietly drop `_gmin'
    }
end


* ============================================================================
* _simtab_plotframe: build the numeric companion frame from the in-memory
*   per-cell summary (current data). Adds provenance characteristics.
* ============================================================================
capture program drop _simtab_plotframe
program _simtab_plotframe, rclass
    version 16.0
    syntax , SPEC(string) NEMD(integer) LEVel(real) ALPha(real) ///
        NSIM(integer) METrics(string) SOURCE(string)

    gettoken _pf_name _pf_opts : spec, parse(",")
    local _pf_name = strtrim(`"`_pf_name'"')
    local _pf_opts : subinstr local _pf_opts "," "", all
    local _pf_opts = strtrim(lower("`_pf_opts'"))
    if "`_pf_opts'" != "" & "`_pf_opts'" != "replace" {
        display as error "plotframe(): unknown sub-option `_pf_opts'"
        exit 198
    }
    capture confirm name `_pf_name'
    if _rc {
        display as error "plotframe(): invalid frame name `_pf_name'"
        exit 198
    }
    capture confirm frame `_pf_name'
    if !_rc {
        if "`_pf_opts'" == "replace" {
            if "`_pf_name'" == "`c(frame)'" {
                display as error "plotframe(): cannot replace the current frame"
                exit 198
            }
            frame drop `_pf_name'
        }
        else {
            display as error "frame `_pf_name' already exists; use plotframe(`_pf_name', replace)"
            exit 110
        }
    }

    * assemble the companion columns from the summary in memory
    preserve
        keep byord bylab estord estlab emdord emdlab truev n ///
            m_mean m_bias m_pctbias m_empse m_meanse m_relerr m_mse m_rmse ///
            m_coverage m_power m_nfail m_pctfail ///
            mc_mean mc_bias mc_empse mc_pctbias mc_mse mc_rmse mc_coverage mc_power
        rename byord by_value
        rename bylab by_label
        rename estord estimator_value
        rename estlab estimator_label
        rename emdord estimand_value
        rename emdlab estimand_label
        rename truev true
        rename m_mean mean
        rename m_bias bias
        rename m_pctbias pctbias
        rename m_empse empse
        rename m_meanse meanse
        rename m_relerr relerr
        rename m_mse mse
        rename m_rmse rmse
        rename m_coverage coverage
        rename m_power power
        rename m_nfail nfail
        rename m_pctfail pctfail
        rename mc_mean mcse_mean
        rename mc_bias mcse_bias
        rename mc_empse mcse_empse
        rename mc_pctbias mcse_pctbias
        rename mc_mse mcse_mse
        rename mc_rmse mcse_rmse
        rename mc_coverage mcse_coverage
        rename mc_power mcse_power
        order by_value by_label estimator_value estimator_label ///
            estimand_value estimand_label true n
        frame put *, into(`_pf_name')
    restore

    frame `_pf_name': char _dta[tabtools_source] "simtab"
    frame `_pf_name': char _dta[tabtools_kind] "simulation_summary"
    frame `_pf_name': char _dta[tabtools_metrics] `"`metrics'"'
    frame `_pf_name': char _dta[tabtools_level] "`level'"
    frame `_pf_name': char _dta[tabtools_alpha] "`alpha'"
    frame `_pf_name': char _dta[tabtools_nsim] "`nsim'"
    frame `_pf_name': char _dta[tabtools_ingest] "`source'"
    frame `_pf_name': char _dta[tabtools_command] "simtab"

    return local plotframe "`_pf_name'"
end


* ============================================================================
* Mata: lay out the rendered c1..cK string table from the per-cell summary
*   mode 1 = flat (single combined header) ; mode 2 = excel (group + metric)
* ============================================================================
version 16.0
capture mata: mata drop _simtab_build()
capture mata: mata drop _simtab_emit()

mata:
mata set matastrict on

void _simtab_emit(string matrix out)
{
    real scalar j, i, K, N, maxlen
    string scalar vtype

    N = rows(out)
    K = cols(out)
    stata("quietly drop _all")
    for (j = 1; j <= K; j++) {
        maxlen = 1
        for (i = 1; i <= N; i++) {
            if (strlen(out[i, j]) > maxlen) maxlen = strlen(out[i, j])
        }
        if (maxlen <= 2045) vtype = "str" + strofreal(maxlen, "%9.0f")
        else vtype = "strL"
        (void) st_addvar(vtype, "c" + strofreal(j, "%9.0f"))
    }
    st_addobs(N)
    for (j = 1; j <= K; j++) {
        st_sstore(., "c" + strofreal(j, "%9.0f"), out[, j])
    }
}

void _simtab_build(
    real scalar mode,
    real scalar lead,
    real scalar Nby,
    real scalar Nest,
    real scalar Nemd,
    real scalar D,
    real scalar hastitle,
    real scalar hasfoot)
{
    real colvector byord, estord, emdord
    string colvector bylab, estlab, emdlab
    string matrix F, B, OUT
    string colvector bymap, estmap, emdmap
    string rowvector fvars
    real scalar Nsumm, R, K, i, b, e, m, r, base, j
    real scalar ri, total, grp, hdr
    string scalar title, foot, leadby, leadest, lbl
    string colvector mlab

    byord = st_data(., "byord")
    estord = st_data(., "estord")
    emdord = st_data(., "emdord")
    bylab = st_sdata(., "bylab")
    estlab = st_sdata(., "estlab")
    emdlab = st_sdata(., "emdlab")

    fvars = J(1, D, "")
    for (j = 1; j <= D; j++) fvars[j] = "f" + strofreal(j, "%9.0f")
    F = st_sdata(., fvars)

    Nsumm = rows(byord)
    R = Nby * Nest
    K = lead + D * Nemd

    bymap = J(Nby, 1, "")
    estmap = J(Nest, 1, "")
    emdmap = J(Nemd, 1, "")
    for (i = 1; i <= Nsumm; i++) {
        bymap[byord[i]] = bylab[i]
        estmap[estord[i]] = estlab[i]
        emdmap[emdord[i]] = emdlab[i]
    }

    // body
    B = J(R, K, "")
    for (b = 1; b <= Nby; b++) {
        for (e = 1; e <= Nest; e++) {
            r = (b - 1) * Nest + e
            if (lead == 2) {
                if (e == 1) B[r, 1] = bymap[b]
                B[r, 2] = estmap[e]
            }
            else {
                B[r, 1] = estmap[e]
            }
        }
    }
    for (i = 1; i <= Nsumm; i++) {
        r = (byord[i] - 1) * Nest + estord[i]
        base = lead + (emdord[i] - 1) * D
        for (m = 1; m <= D; m++) B[r, base + m] = F[i, m]
    }

    // metric labels from Stata locals
    mlab = J(D, 1, "")
    for (m = 1; m <= D; m++) mlab[m] = st_local("metriclbl" + strofreal(m, "%9.0f"))
    leadby = st_local("_leadhdr_by")
    leadest = st_local("_leadhdr_est")
    title = st_local("title")
    foot = st_local("footnote")

    if (mode == 1) {
        // flat: title? + 1 header + body + foot?
        total = hastitle + 1 + R + hasfoot
        OUT = J(total, K, "")
        ri = 0
        if (hastitle) {
            ri = ri + 1
            OUT[ri, 1] = title
        }
        ri = ri + 1
        if (lead == 2) {
            OUT[ri, 1] = leadby
            OUT[ri, 2] = leadest
        }
        else {
            OUT[ri, 1] = leadest
        }
        for (e = 1; e <= Nemd; e++) {
            for (m = 1; m <= D; m++) {
                lbl = mlab[m]
                if (Nemd > 1) lbl = emdmap[e] + ": " + mlab[m]
                OUT[ri, lead + (e - 1) * D + m] = lbl
            }
        }
        for (r = 1; r <= R; r++) {
            OUT[ri + r, .] = B[r, .]
        }
        ri = ri + R
        if (hasfoot) OUT[ri + 1, 1] = foot
    }
    else {
        // excel: title? + group(if Nemd>1) + metric header + body + foot?
        // Column 1 is a narrow spacer (A); content starts at column 2 (B)
        total = hastitle + (Nemd > 1) + 1 + R + hasfoot
        OUT = J(total, K + 1, "")
        ri = 0
        if (hastitle) {
            ri = ri + 1
            OUT[ri, 1] = title
        }
        if (Nemd > 1) {
            ri = ri + 1
            grp = ri
            for (e = 1; e <= Nemd; e++) {
                OUT[grp, 1 + lead + (e - 1) * D + 1] = emdmap[e]
            }
        }
        ri = ri + 1
        hdr = ri
        if (lead == 2) {
            OUT[hdr, 2] = leadby
            OUT[hdr, 3] = leadest
        }
        else {
            OUT[hdr, 2] = leadest
        }
        for (e = 1; e <= Nemd; e++) {
            for (m = 1; m <= D; m++) {
                OUT[hdr, 1 + lead + (e - 1) * D + m] = mlab[m]
            }
        }
        for (r = 1; r <= R; r++) {
            OUT[hdr + r, 2..K+1] = B[r, .]
        }
        ri = hdr + R
        // footnote aligns with the table box left border (column B)
        if (hasfoot) OUT[ri + 1, 2] = foot
    }

    _simtab_emit(OUT)
}

end

*! qa-lib _qa_fx_a2 1.0.0 sha256:bb0ca5dd51acfdcda070f0d9d6c66da2e69b122c261ab1518fd66d2e3aa125f8
* _qa_fx_a2.do -- A2 single-record survival / competing-risk fixtures
*
* Load: do "`qa_dir'/_qa_fx_a2.do"
* API (both rclass, clear required)
*   qa_fx_a2_lifetable , clear [tier(micro|unit|recovery|scale) n(#)
*       seed(#) perturb(oplist) names(old=new ...)]
*   qa_fx_a2_pwexp , clear [tier(micro|unit|recovery|scale) n(#)
*       model(cs|finegray|weibull) censoring seed(#) perturb(oplist)
*       names(old=new ...)]
*
* Canonical schema: id t0 t d cause x1 x2 xcat stratum w cl.
* x1 is the binary arm; d means ANY event; cause=0 censor, 1 primary,
* 2 competing. No stset is performed. Rows are sorted by id unless unsorted.
* Covariates and times are numeric, times and weights are double.
*
* LIFETABLE: 24-row deterministic design, 12 per arm, each row replicated
* n/24 times. Defaults micro=24, unit=240, recovery=2400, scale=120000;
* n must be a positive multiple of 24. There is no MC recovery claim:
* replication preserves every KM/NA/AJ estimate exactly (log-rank variance
* follows the replicated integer risk sets, including the tie correction).
* In arm 0, primary/competing/censor counts at t=1,2,3,4:
*   (2,1,1), (1,1,1), (1,0,1), (1,1,1).
* In arm 1: (1,1,1), (2,0,1), (1,1,1), (1,1,1).
* r(truth_table): rows arm x times 0..4, columns x1 time risk d1 d2
*   cens S H cif1 cif2 S1 H1. S/H are all-cause KM/NA; S1/H1 censor
*   competing causes and describe the primary-cause net survival/hazard.
* AJ uses the all-cause survival just BEFORE each jump. Events precede
* censoring at a tie; entry t0==t is excluded: risk={t0<t<=exit}.
* r(truth_logrank): 2 x 3 (all-cause, primary), columns U V chi2,
*   U=sum(d_arm1-Y_arm1*d/Y), V=sum(Y0*Y1*d*(Y-d)/(Y^2*(Y-1))).
* These are rational quantities from integer counts, represented in double;
* no decimal-as-exact or textual rational claim is made.
*
* PWEXP: balanced x1 x x2 with xcat balanced over blocks of 12. Defaults
* micro=24, unit=240, recovery=20016, scale=100008; n must be a multiple
* of 12, >=12. Micro/unit are schema/hostility tiers, NOT guaranteed
* coefficient recovery tiers. Recovery uses estimator SE or MC SE;
* scale is performance-only. absorb requires n divisible by 24 for exact
* half-cause counts in each covariate cell. Each row consumes FIVE uniforms.
* Uniforms 1..4 generate event/censor/entry, 5 supplies unsorted order:
* F and U with the same seed have identical unaffected rows.
* Administrative censoring is at 8; censoring adds independent Exp(.04).
*
* model(cs), default: independent cause clocks with piecewise-constant
* cause-specific hazards on (0,2], (2,5], (5,infinity):
*   lambda1=(.12,.06,.18)*exp(-.4*x1+.3*x2)
*   lambda2=(.05,.09,.03)*exp( .2*x1-.1*x2).
* S and CIFs are closed-form sums of interval-specific exponential integrals.
* r(truth_b_cs1), r(truth_b_cs2), r(truth_hr_cs1|cs2) are 1x2 matrices
* named x1 x2; r(truth_hazards) has x1 x2 start stop lambda1 lambda2.
* There is NO constant Fine-Gray HR truth on this route.
*
* model(finegray): Fine & Gray (1999), section 6, printed p.502, mixture
* CIF F1(t|x)=1-[1-p+p*exp(-H0(t))]^q, p=.5, q=exp(-.5*x1+.35*x2).
* H0 has interval slopes (.20,.10,.30) at breaks 2,5. Cause membership
* P(cause1)=1-(1-p)^q. Invert the conditional cause1 CIF using a fresh
* uniform; other subjects have cause2 time Exp(.15*exp(.2*x1-.1*x2)).
* This is a proper joint competing-risk distribution, with proportional
* SUBDISTRIBUTION hazards and r(truth_b_fg)=(-.5,.35), truth_hr_fg=exp(b).
* Its CAUSE-SPECIFIC hazards are not piecewise constant or proportional:
* truth_b_cs* and truth_hr_cs* are missing, rather than fake constants.
*
* model(weibull): single cause, shape p=1.5,
*   T=exp(1+.4*x1-.25*x2)*[-log(U)]^(1/p).
* r(truth_b_aft)=(.4,-.25,1), columns x1 x2 _cons;
* r(truth_shape)=1.5; cause-specific log-HR=(-.6,.375).
* Fine-Gray truth equals cause-specific truth because there is no competitor.
* Formula/parameterization: official Stata streg manual, Table 1 pp.7-9.
*
* PWEXP r(truth_curve): 36x7, four covariate cells x horizons 0..8,
* columns x1 x2 time S H cif1 cif2; H=-log(S), NOT Nelson-Aalen.
* Truth is the latent population BEFORE censoring/entry selection, not an
* estimate from this draw. r(truth_scope) names that population.
* Fine & Gray (1999), sec.2 pp.497-498 grounds the subdistribution identity;
* Aalen & Johansen (1978), pp.147-148 grounds the product-integral recursion;
* official Stata sts/sts test manuals ground KM, NA and tie-corrected logrank.
*
* Both: r(N), r(seed), r(tier), r(model), r(perturb), r(perturb_applied),
* r(expect_class) for exactly one operator, r(perturb_n_<op>) (>0).
* perturb_n counts rows witnessing each property (or boundary requests),
* not necessarily the distinct number of values changed. H=-log(S) is
* missing at S=0 because Stata has no finite representation of infinity.
* r(truth_boundaries) is a rowvector of requested times (LIFETABLE 0 1 4 5;
* PWEXP 0 2 8 9). r(truth_boundary_curve) has the same columns as
* truth_table/curve, with unsupported time 5/9 values MISSING. The boundary
* operator leaves the data intact and declares/exercises those requests.
* names() adapts coefficient/HR/AFT matrix stripes and their char colnames
* to the actual renamed x1/x2 variables; _cons is reserved for the AFT
* intercept and refused as their target. Curve/table/hazard-grid columns
* retain CANONICAL ROLE names (x1, x2, time, etc.), not data variable names.
* seed() is restricted to 0..2147483647 before any clear/RNG mutation.
* Stamps: _dta[qa_fx_generator|version|seed|perturb|tier|model|truth_scope].
* Every numerical truth matrix travels as _dta[qa_<matrix>_rows|cols] and
* _dta[qa_<matrix>_r#_c#] (%21x); truth_shape is also a %21x char.
*
* Operators available on both:
*   ties           LIFETABLE merges t=2 into t=1; PWEXP rounds times UP to
*                  integer jumps. All-cause, primary, competing and censor
*                  ties are re-proved (Weibull has no competing ties).
*   noevent        arm 1 has NO event of either cause (all exits censored).
*   empty_stratum  arm 1 is declared stratum 2 and has no events.
*   absorb         arm 1 all fail at t=2, equally split causes 1 and 2;
*                  S=0 and CIF1=CIF2=.5 from 2 through design horizon.
*   late_entry     LIFETABLE some later exits enter at 1.5;
*                  PWEXP independent entry Uniform(0,.5), removes exits
*                  <=entry; truth stays pre-selection, r(N_dropped) states it.
*   boundary_values  requests exactly at a jump/design boundary, zero, and
*                  beyond support. r(perturb_n_boundary_values)=4 requests.
*   unsorted       permutes rows (fixed uniform block on PWEXP).
*   codes_multidigit  xcat 1 2 3 -> 1 11 111, truth unchanged.
* ties/noevent/empty_stratum/absorb are measurement/intervention operators:
* PWEXP coefficients are withheld (all missing) because the original
* continuous proportional models no longer apply. Its curve truth follows
* the modified event distribution at the INTEGER grid points.
* Conflicting noevent/empty_stratum/absorb are refused; ties+absorb and
* ties+late_entry are refused. PWEXP absorb+late_entry is refused.
* time_hostile and other primitives are REFUSED rc198 with explicit pointer
* to qa_hostile_times/missing/codes/names/strings or qa_shift_invariance.
* To test time precision, use qa_hostile_times after a lifetable, keeping
* its %21x literals/scalars intact; do not fork the primitive here.
* Stochastic hostility can fail rc9 at small N or unlucky seeds (e.g. no
* same-time primary/competing/censor triple); availability is not a guarantee
* that every small draw realizes it. The default unit variants are self-tested.
* Errors: rc198 invalid arguments (before clear, preserves caller r()),
* rc9 hostility not achieved. Success replaces data/provenance, r() and RNG.
* NOT provided: concordance truth, stochastic small-tier recovery promises,
* formal analytic variance/MC tolerances, fractional-text rational arithmetic.

capture program drop _qa_fxa2_parse
program define _qa_fxa2_parse, sclass
    version 16.0
    syntax , WHO(string) [PERTurb(string) NAMES(string) MODEL(string)]
    local known ties noevent absorb empty_stratum late_entry boundary_values ///
        unsorted codes_multidigit
    local wrapped miss_extended:qa_hostile_missing codes_negative:qa_hostile_codes ///
        codes_big:qa_hostile_codes long_names:qa_hostile_names ///
        string_hostile:qa_hostile_strings time_hostile:qa_hostile_times ///
        scale_shift:qa_shift_invariance
    local ops ""
    foreach op of local perturb {
        foreach p of local wrapped {
            gettoken primitive helper : p, parse(":")
            if "`op'" == "`primitive'" {
                display as error "`who': `op' is a primitive operator; call `=substr("`helper'",2,.)' directly"
                exit 198
            }
        }
        if !`: list op in known' {
            display as error "`who': unknown operator `op' (provides: `known')"
            exit 198
        }
        local ops `ops' `op'
    }
    local ops : list uniq ops
    local ops = strtrim("`ops'")
    foreach op of local known {
        local p_`op' = `: list op in ops'
    }
    if `p_noevent'+`p_absorb'+`p_empty_stratum' > 1 | ///
        (`p_ties' & (`p_absorb' | `p_late_entry')) | ///
        ("`model'" != "lifetable" & `p_absorb' & `p_late_entry') {
        display as error "`who': conflicting event, tie or entry operators"
        exit 198
    }
    * Validate every rename before clear, including collisions and swaps.
    local canonical id t0 t d cause x1 x2 xcat stratum w cl
    local from ""
    local to ""
    foreach pair of local names {
        gettoken old new : pair, parse("=")
        local new = substr("`new'",2,.)
        capture confirm name `new'
        if _rc | "`new'" == "" | !`: list old in canonical' | ///
            `: list old in from' | `: list new in to' {
            display as error "`who': names() requires unique valid old=new pairs over the canonical schema"
            exit 198
        }
        if "`model'"!="lifetable" & inlist("`old'","x1","x2") & "`new'"=="_cons" {
            display as error "`who': names() target _cons is reserved for the AFT intercept"
            exit 198
        }
        local from `from' `old'
        local to `to' `new'
    }
    local untouched : list canonical - from
    local clash : list untouched & to
    if "`clash'" != "" {
        display as error "`who': names() collides with unchanged variable(s): `clash'"
        exit 198
    }
    sreturn local ops "`ops'"
end

capture program drop _qa_fxa2_rename
program define _qa_fxa2_rename
    version 16.0
    args names
    local mids ""
    local targets ""
    foreach pair of local names {
        gettoken old new : pair, parse("=")
        local new = substr("`new'",2,.)
        tempvar mid
        rename `old' `mid'
        local mids `mids' `mid'
        local targets `targets' `new'
    }
    local j = 0
    foreach mid of local mids {
        local ++j
        local new : word `j' of `targets'
        rename `mid' `new'
    }
end

capture program drop _qa_fxa2_stamp
program define _qa_fxa2_stamp
    version 16.0
    args M stem
    char _dta[qa_`stem'_rows] "`=rowsof(`M')'"
    char _dta[qa_`stem'_cols] "`=colsof(`M')'"
    local cn : colnames `M'
    char _dta[qa_`stem'_colnames] "`cn'"
    forvalues i = 1/`=rowsof(`M')' {
        forvalues j = 1/`=colsof(`M')' {
            char _dta[qa_`stem'_r`i'_c`j'] "`: display %21x `M'[`i',`j']'"
        }
    }
end

capture program drop _qa_fxa2_properties
program define _qa_fxa2_properties, rclass
    version 16.0
    args who ops model
    local changed = 0
    foreach op of local ops {
        local nchanged = 0
        if "`op'" == "ties" {
            tempvar p c z
            quietly bysort t: egen long `p' = total(cause==1)
            quietly bysort t: egen long `c' = total(cause==2)
            quietly bysort t: egen long `z' = total(cause==0)
            quietly count if `p'>0 & `z'>0 & (`c'>0 | "`model'"=="weibull")
            local nchanged = r(N)
            drop `p' `c' `z'
        }
        if inlist("`op'", "noevent", "empty_stratum", "absorb") {
            quietly count if x1==1
            local nchanged = r(N)
            if "`op'" == "absorb" {
                quietly count if x1==1 & (t!=2 | cause==0 | d!=1)
                if r(N)>0 local nchanged = 0
                quietly count if x1==1 & cause==1
                if 2*r(N)!=`nchanged' local nchanged = 0
            }
            else {
                quietly count if x1==1 & (cause!=0 | d!=0)
                if r(N)>0 local nchanged = 0
                if "`op'"=="empty_stratum" {
                    quietly count if x1==1 & stratum!=2
                    if r(N)>0 local nchanged = 0
                }
            }
            quietly count if x1==0 & d==1
            if r(N)==0 local nchanged = 0
        }
        if "`op'" == "late_entry" {
            quietly count if t0>0 & t0<t
            local nchanged = r(N)
        }
        if "`op'" == "boundary_values" local nchanged = 4
        if "`op'" == "codes_multidigit" {
            quietly count if xcat==111
            local nchanged = r(N)
            quietly count if !inlist(xcat,1,11,111)
            if r(N)>0 local nchanged = 0
        }
        if "`op'" == "unsorted" {
            tempvar ord
            quietly generate long `ord' = _n
            sort id
            quietly count if `ord'!=_n
            local nchanged = r(N)
            sort `ord'
            drop `ord'
        }
        if `nchanged'<=0 {
            display as error "`who': `op' lost its claimed property"
            exit 9
        }
        return scalar perturb_n_`op' = `nchanged'
        local changed = `changed' + `nchanged'
    }
    return scalar perturb_n = `changed'
end

capture program drop qa_fx_a2_lifetable
program define qa_fx_a2_lifetable, rclass
    version 16.0
    * Preserve caller r() on early refusal; clear this pending return set
    * only after every argument has passed validation.
    return add
    syntax , CLEAR [TIER(string) N(integer 0) SEED(integer 20260929) ///
        PERTurb(string) NAMES(string)]
    if "`tier'"=="" local tier unit
    if !inlist("`tier'","micro","unit","recovery","scale") {
        display as error "qa_fx_a2_lifetable: invalid tier()"
        exit 198
    }
    if `n'==0 local n = cond("`tier'"=="micro",24,cond("`tier'"=="unit",240,cond("`tier'"=="recovery",2400,120000)))
    if `n'<24 | mod(`n',24)!=0 {
        display as error "qa_fx_a2_lifetable: n() must be a positive multiple of 24"
        exit 198
    }
    if `seed'<0 | `seed'>2147483647 {
        display as error "qa_fx_a2_lifetable: seed() must be in 0..2147483647"
        exit 198
    }
    _qa_fxa2_parse, who(qa_fx_a2_lifetable) perturb(`perturb') names(`names') model(lifetable)
    local ops `s(ops)'
    return clear
    clear
    set seed `seed'
    tempname D T L BC
    * Columns x1 time cause, fixed canonical row order.
    matrix `D' = (0,1,1 \ 0,1,1 \ 0,1,2 \ 0,1,0 \ ///
        0,2,1 \ 0,2,2 \ 0,2,0 \ 0,3,1 \ 0,3,0 \ ///
        0,4,1 \ 0,4,2 \ 0,4,0 \ ///
        1,1,1 \ 1,1,2 \ 1,1,0 \ 1,2,1 \ 1,2,1 \ 1,2,0 \ ///
        1,3,1 \ 1,3,2 \ 1,3,0 \ 1,4,1 \ 1,4,2 \ 1,4,0)
    quietly {
        set obs `n'
        generate long id = _n
        generate byte x1 = `D'[mod(id-1,24)+1,1]
        generate double t = `D'[mod(id-1,24)+1,2]
        generate byte cause = `D'[mod(id-1,24)+1,3]
        generate byte x2 = mod(id-1,2)
        generate byte xcat = mod(id-1,3)+1
        generate double t0 = 0
        generate byte stratum = 1
        generate double w = 1
        generate long cl = ceil(id/4)
        if `: list posof "ties" in ops' replace t = 1 if t==2
        if `: list posof "late_entry" in ops' replace t0 = 1.5 if t>=3 & mod(id,2)==0
        if `: list posof "noevent" in ops' replace cause = 0 if x1==1
        if `: list posof "empty_stratum" in ops' {
            replace stratum = 2 if x1==1
            replace cause = 0 if x1==1
        }
        if `: list posof "absorb" in ops' {
            replace t = 2 if x1==1
            replace cause = 1+mod(id,2) if x1==1
        }
        generate byte d = cause>0
        if `: list posof "codes_multidigit" in ops' replace xcat = cond(xcat==1,1,cond(xcat==2,11,111))
        if `: list posof "unsorted" in ops' {
            tempvar u
            generate double `u' = runiform()
            sort `u' id
            drop `u'
        }
        order id t0 t d cause x1 x2 xcat stratum w cl
    }
    _qa_fxa2_properties qa_fx_a2_lifetable "`ops'" lifetable
    foreach op of local ops {
        local pn_`op' = r(perturb_n_`op')
    }
    local pn = r(perturb_n)
    mata: _qa_fxa2_life_truth("`T'","`L'","`BC'")
    matrix colnames `T' = x1 time risk d1 d2 cens S H cif1 cif2 S1 H1
    matrix colnames `L' = U V chi2
    matrix rownames `L' = allcause primary
    matrix colnames `BC' = x1 time risk d1 d2 cens S H cif1 cif2 S1 H1
    if `: list posof "boundary_values" in ops' {
        if `BC'[2,2]!=1 | `BC'[3,2]!=4 | `BC'[4,2]!=5 | ///
            (!missing(`BC'[4,7]) | !missing(`BC'[4,9])) {
            display as error "qa_fx_a2_lifetable: boundary_values lost its support property"
            exit 9
        }
    }
    _qa_fxa2_stamp `T' truth_table
    _qa_fxa2_stamp `L' truth_logrank
    _qa_fxa2_stamp `BC' truth_boundary_curve
    tempname boundaries
    matrix `boundaries' = (0,1,4,5)
    _qa_fxa2_stamp `boundaries' truth_boundaries
    _qa_fxa2_rename "`names'"
    char _dta[qa_fx_generator] "_qa_fx_a2 qa_fx_a2_lifetable"
    char _dta[qa_fx_version] "1.0.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_perturb] "`ops'"
    char _dta[qa_fx_tier] "`tier'"
    char _dta[qa_fx_model] "lifetable"
    char _dta[qa_fx_truth_scope] "empirical_integer_design"
    return matrix truth_table = `T'
    return matrix truth_logrank = `L'
    return matrix truth_boundary_curve = `BC'
    return matrix truth_boundaries = `boundaries'
    return scalar N = `n'
    return scalar seed = `seed'
    return scalar perturb_n = `pn'
    foreach op of local ops {
        return scalar perturb_n_`op' = `pn_`op''
    }
    return local tier "`tier'"
    return local model "lifetable"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local truth_scope "empirical_integer_design"
    local expect ""
    if `: word count `ops''==1 {
        local expect = cond(inlist("`ops'","noevent","empty_stratum"),"REFUSED",cond(inlist("`ops'","unsorted","codes_multidigit"),"INVARIANT","EXACT"))
        if "`ops'"=="empty_stratum" local expect EXACT
    }
    return local expect_class "`expect'"
end

capture program drop qa_fx_a2_pwexp
program define qa_fx_a2_pwexp, rclass
    version 16.0
    * Preserve caller r() on early refusal; clear this pending return set
    * only after every argument has passed validation.
    return add
    syntax , CLEAR [TIER(string) N(integer 0) MODEL(string) CENSoring ///
        SEED(integer 20260929) PERTurb(string) NAMES(string)]
    if "`tier'"=="" local tier unit
    if "`model'"=="" local model cs
    if !inlist("`tier'","micro","unit","recovery","scale") | ///
        !inlist("`model'","cs","finegray","weibull") {
        display as error "qa_fx_a2_pwexp: invalid tier() or model()"
        exit 198
    }
    if `n'==0 local n = cond("`tier'"=="micro",24,cond("`tier'"=="unit",240,cond("`tier'"=="recovery",20016,100008)))
    if `n'<12 | mod(`n',12)!=0 {
        display as error "qa_fx_a2_pwexp: n() must be a multiple of 12, at least 12"
        exit 198
    }
    if `seed'<0 | `seed'>2147483647 {
        display as error "qa_fx_a2_pwexp: seed() must be in 0..2147483647"
        exit 198
    }
    _qa_fxa2_parse, who(qa_fx_a2_pwexp) perturb(`perturb') names(`names') model(`model')
    local ops `s(ops)'
    if `: list posof "absorb" in ops' & mod(`n',24)!=0 {
        display as error "qa_fx_a2_pwexp: absorb requires n() a multiple of 24 for exact per-cell halves"
        exit 198
    }
    return clear
    clear
    set seed `seed'
    tempname T BC H B1 B2 BF BA HR1 HR2 HRF boundaries
    tempvar shuffle
    mata: _qa_fxa2_pw_gen(`n', "`model'", "`censoring'"!="", "`shuffle'")
    local ndrop = 0
    quietly {
        if `: list posof "late_entry" in ops' {
            replace t0 = .5*t0
            count if t<=t0
            local ndrop = r(N)
            drop if t<=t0
        }
        else replace t0 = 0
        if `: list posof "ties" in ops' replace t = ceil(t)
        if `: list posof "noevent" in ops' replace cause = 0 if x1==1
        if `: list posof "empty_stratum" in ops' {
            replace stratum = 2 if x1==1
            replace cause = 0 if x1==1
        }
        if `: list posof "absorb" in ops' {
            replace t = 2 if x1==1
            replace cause = 1+mod(floor((id-1)/4),2) if x1==1
        }
        replace d = cause>0
        if `: list posof "codes_multidigit" in ops' replace xcat = cond(xcat==1,1,cond(xcat==2,11,111))
        if `: list posof "unsorted" in ops' sort `shuffle' id
        drop `shuffle'
        order id t0 t d cause x1 x2 xcat stratum w cl
    }
    _qa_fxa2_properties qa_fx_a2_pwexp "`ops'" `model'
    foreach op of local ops {
        local pn_`op' = r(perturb_n_`op')
    }
    local pn = r(perturb_n)
    local changed = `: list posof "noevent" in ops'+`: list posof "absorb" in ops'+`: list posof "empty_stratum" in ops'+`: list posof "ties" in ops'
    local nop = `: list posof "noevent" in ops'+`: list posof "empty_stratum" in ops'
    local absorbed = `: list posof "absorb" in ops'
    mata: _qa_fxa2_pw_truth("`model'",`nop',`absorbed',"`T'","`BC'","`H'")
    matrix colnames `T' = x1 x2 time S H cif1 cif2
    matrix colnames `BC' = x1 x2 time S H cif1 cif2
    if `: list posof "boundary_values" in ops' {
        if `BC'[2,3]!=2 | `BC'[3,3]!=8 | `BC'[4,3]!=9 | ///
            (!missing(`BC'[4,4]) | !missing(`BC'[4,6])) {
            display as error "qa_fx_a2_pwexp: boundary_values lost its support property"
            exit 9
        }
    }
    matrix colnames `H' = x1 x2 start stop lambda1 lambda2
    matrix `B1' = (.,.)
    matrix `B2' = (.,.)
    matrix `BF' = (.,.)
    matrix `BA' = (.,.,.)
    local shape = .
    if "`model'"=="cs" & !`changed' {
        matrix `B1' = (-.4,.3)
        matrix `B2' = (.2,-.1)
    }
    if "`model'"=="finegray" & !`changed' matrix `BF' = (-.5,.35)
    if "`model'"=="weibull" & !`changed' {
        matrix `BA' = (.4,-.25,1)
        matrix `B1' = (-.6,.375)
        matrix `BF' = `B1'
        local shape = 1.5
    }
    local name1 x1
    local name2 x2
    foreach pair of local names {
        gettoken old new : pair, parse("=")
        local new = substr("`new'",2,.)
        if "`old'"=="x1" local name1 "`new'"
        if "`old'"=="x2" local name2 "`new'"
    }
    matrix colnames `B1' = `name1' `name2'
    matrix colnames `B2' = `name1' `name2'
    matrix colnames `BF' = `name1' `name2'
    matrix colnames `BA' = `name1' `name2' _cons
    mata: st_matrix("`HR1'",exp(st_matrix("`B1'"))); st_matrix("`HR2'",exp(st_matrix("`B2'"))); st_matrix("`HRF'",exp(st_matrix("`BF'")))
    matrix colnames `HR1' = `name1' `name2'
    matrix colnames `HR2' = `name1' `name2'
    matrix colnames `HRF' = `name1' `name2'
    matrix `boundaries' = (0,2,8,9)
    if `changed' matrix `H' = J(12,6,.)
    local mapping curve:`T' boundary_curve:`BC' hazards:`H' b_cs1:`B1' ///
        b_cs2:`B2' b_fg:`BF' b_aft:`BA' hr_cs1:`HR1' hr_cs2:`HR2' ///
        hr_fg:`HRF' boundaries:`boundaries'
    foreach item of local mapping {
        gettoken stem M : item, parse(":")
        local M = substr("`M'",2,.)
        _qa_fxa2_stamp `M' truth_`stem'
    }
    _qa_fxa2_rename "`names'"
    quietly count
    local nrows = r(N)
    char _dta[qa_fx_generator] "_qa_fx_a2 qa_fx_a2_pwexp"
    char _dta[qa_fx_version] "1.0.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_perturb] "`ops'"
    char _dta[qa_fx_tier] "`tier'"
    char _dta[qa_fx_model] "`model'"
    char _dta[qa_fx_truth_scope] "latent_population_before_censoring_and_entry"
    char _dta[qa_truth_shape] "`: display %21x `shape''"
    return matrix truth_curve = `T'
    return matrix truth_boundary_curve = `BC'
    return matrix truth_hazards = `H'
    return matrix truth_b_cs1 = `B1'
    return matrix truth_b_cs2 = `B2'
    return matrix truth_b_fg = `BF'
    return matrix truth_b_aft = `BA'
    return matrix truth_hr_cs1 = `HR1'
    return matrix truth_hr_cs2 = `HR2'
    return matrix truth_hr_fg = `HRF'
    return matrix truth_boundaries = `boundaries'
    return scalar truth_shape = `shape'
    return scalar N = `nrows'
    return scalar N_generated = `n'
    return scalar N_dropped = `ndrop'
    return scalar seed = `seed'
    return scalar perturb_n = `pn'
    foreach op of local ops {
        return scalar perturb_n_`op' = `pn_`op''
    }
    return local tier "`tier'"
    return local model "`model'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local truth_scope "latent_population_before_censoring_and_entry"
    local expect ""
    if `: word count `ops''==1 {
        local expect = cond("`ops'"=="noevent","REFUSED",cond(inlist("`ops'","unsorted","codes_multidigit"),"INVARIANT","EXACT"))
    }
    return local expect_class "`expect'"
end

capture mata: mata drop _qa_fxa2_inverse()
capture mata: mata drop _qa_fxa2_life_truth()
capture mata: mata drop _qa_fxa2_pw_gen()
capture mata: mata drop _qa_fxa2_pw_value()
capture mata: mata drop _qa_fxa2_pw_truth()
mata:
real scalar _qa_fxa2_inverse(real scalar e, real rowvector h)
{
    if (e<=2*h[1]) return(e/h[1])
    if (e<=2*h[1]+3*h[2]) return(2+(e-2*h[1])/h[2])
    return(5+(e-2*h[1]-3*h[2])/h[3])
}

void _qa_fxa2_life_truth(string scalar tab, string scalar lr, string scalar bc)
{
    real matrix D, T, L, B
    real scalar arm, j, r, n, a, b, c, s, h, f1, f2, sn, hn
    real scalar y0, y1, d0, d1, y, d, u, v, kind

    D=st_data(.,("x1","t0","t","cause"))
    T=J(10,12,0)
    for (arm=0;arm<=1;arm++) {
        s=sn=1
        h=f1=f2=hn=0
        for (j=0;j<=4;j++) {
            r=arm*5+j+1
            n=sum((D[,1]:==arm):&(D[,2]:<j):&(D[,3]:>=j))
            a=sum((D[,1]:==arm):&(D[,3]:==j):&(D[,4]:==1))
            b=sum((D[,1]:==arm):&(D[,3]:==j):&(D[,4]:==2))
            c=sum((D[,1]:==arm):&(D[,3]:==j):&(D[,4]:==0))
            if (n>0) {
                f1=f1+s*a/n
                f2=f2+s*b/n
                s=s*(1-(a+b)/n)
                h=h+(a+b)/n
                sn=sn*(1-a/n)
                hn=hn+a/n
            }
            T[r,]=(arm,j,n,a,b,c,s,h,f1,f2,sn,hn)
        }
    }
    L=J(2,3,.)
    for (kind=1;kind<=2;kind++) {
        u=v=0
        for (j=1;j<=4;j++) {
            y0=T[j+1,3]; y1=T[j+6,3]
            d0=T[j+1,4]; d1=T[j+6,4]
            if (kind==1) {
                d0=d0+T[j+1,5]
                d1=d1+T[j+6,5]
            }
            y=y0+y1; d=d0+d1
            if (y>0) u=u+d1-y1*d/y
            if (y>1) v=v+y0*y1*d*(y-d)/(y^2*(y-1))
        }
        L[kind,]=(u,v,(v>0 ? u^2/v : .))
    }
    B=J(8,12,.)
    for (arm=0;arm<=1;arm++) {
        B[arm*4+1,]=T[arm*5+1,]
        B[arm*4+2,]=T[arm*5+2,]
        B[arm*4+3,]=T[arm*5+5,]
        B[arm*4+4,1..2]=(arm,5)
    }
    st_matrix(tab,T); st_matrix(lr,L); st_matrix(bc,B)
}

void _qa_fxa2_pw_gen(real scalar n, string scalar model, real scalar cens,
    string scalar shuffle)
{
    real matrix D, U
    real scalar i, a, x, z1, z2, tt, cc, c, q, p1, v, h
    real rowvector h1,h2

    D=J(n,12,.)
    for (i=1;i<=n;i++) {
        // A fixed contiguous block per row, including unused uniforms.
        U=runiform(1,5)
        a=mod(floor((i-1)/2),2); x=mod(i-1,2)
        if (model=="cs") {
            h1=(.12,.06,.18)*exp(-.4*a+.3*x)
            h2=(.05,.09,.03)*exp(.2*a-.1*x)
            z1=_qa_fxa2_inverse(-ln(U[1]),h1)
            z2=_qa_fxa2_inverse(-ln(U[2]),h2)
            tt=min((z1,z2)); c=z1<=z2 ? 1 : 2
        }
        else if (model=="finegray") {
            q=exp(-.5*a+.35*x)
            p1=1-.5^q
            if (U[1]<p1) {
                v=U[2]*p1
                h=-ln(((1-v)^(1/q)-.5)/.5)
                tt=_qa_fxa2_inverse(h,(.20,.10,.30))
                c=1
            }
            else {
                tt=-ln(U[2])/(.15*exp(.2*a-.1*x))
                c=2
            }
        }
        else {
            tt=exp(1+.4*a-.25*x)*(-ln(U[1]))^(1/1.5)
            c=1
        }
        cc=8
        if (cens) cc=min((cc,-ln(U[3])/.04))
        if (tt>cc) {
            tt=cc
            c=0
        }
        D[i,]=(i,U[4],tt,c>0,c,a,x,mod(floor((i-1)/4),3)+1,1,1,ceil(i/10),U[5])
    }
    (void) st_addvar(("long","double","double","byte","byte","byte","byte",
        "byte","byte","double","long","double"),
        ("id","t0","t","d","cause","x1","x2","xcat","stratum","w","cl",shuffle))
    st_addobs(n); st_store(.,.,D)
}

real rowvector _qa_fxa2_pw_value(string scalar model, real scalar a,
    real scalar x, real scalar t)
{
    real scalar j, dt, s, f1, f2, r1, r2, rt, q, h
    real rowvector ends,h1,h2
    s=1; f1=f2=0
    if (model=="cs") {
        ends=(0,2,5,.)
        h1=(.12,.06,.18)*exp(-.4*a+.3*x)
        h2=(.05,.09,.03)*exp(.2*a-.1*x)
        for (j=1;j<=3;j++) {
            dt=max((0,min((t,ends[j+1]))-ends[j]))
            r1=h1[j]; r2=h2[j]; rt=r1+r2
            f1=f1+s*r1/rt*(1-exp(-rt*dt))
            f2=f2+s*r2/rt*(1-exp(-rt*dt))
            s=s*exp(-rt*dt)
        }
    }
    else if (model=="finegray") {
        h=.2*min((t,2))+.1*max((0,min((t,5))-2))+.3*max((0,t-5))
        q=exp(-.5*a+.35*x)
        f1=1-(.5+.5*exp(-h))^q
        f2=.5^q*(1-exp(-.15*exp(.2*a-.1*x)*t))
        s=1-f1-f2
    }
    else {
        s=exp(-(t/exp(1+.4*a-.25*x))^1.5)
        f1=1-s
    }
    return((s,-ln(s),f1,f2))
}

void _qa_fxa2_pw_truth(string scalar model, real scalar noev,
    real scalar absorb, string scalar tab, string scalar bc, string scalar haz)
{
    real matrix T,B,H
    real rowvector value,ends,h1,h2
    real scalar a,x,t,r,j,cell
    T=J(36,7,.); B=J(16,7,.); H=J(12,6,.)
    ends=(0,2,5,.)
    for (a=0;a<=1;a++) {
        for (x=0;x<=1;x++) {
            cell=2*a+x
            for (t=0;t<=8;t++) {
                value=_qa_fxa2_pw_value(model,a,x,t)
                if (a==1 & noev) value=(1,0,0,0)
                if (a==1 & absorb) value=t<2 ? (1,0,0,0) : (0,.,.5,.5)
                r=cell*9+t+1
                T[r,]=(a,x,t,value)
            }
            B[cell*4+1,]=T[cell*9+1,]
            B[cell*4+2,]=T[cell*9+3,]
            B[cell*4+3,]=T[cell*9+9,]
            B[cell*4+4,1..3]=(a,x,9)
            if (model=="cs" & !noev & !absorb) {
                h1=(.12,.06,.18)*exp(-.4*a+.3*x)
                h2=(.05,.09,.03)*exp(.2*a-.1*x)
                for (j=1;j<=3;j++) H[cell*3+j,]=(a,x,ends[j],ends[j+1],h1[j],h2[j])
            }
        }
    }
    st_matrix(tab,T); st_matrix(bc,B); st_matrix(haz,H)
}
end

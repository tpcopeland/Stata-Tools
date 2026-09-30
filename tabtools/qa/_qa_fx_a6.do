*! qa-lib _qa_fx_a6 1.0.0 sha256:30be01f7bed706803b095fe4388d513ef392ab9fbde748c64eec728cde81fc88
* _qa_fx_a6.do -- A6 deterministic aggregate / contrast fixtures
* Timothy P Copeland, Karolinska Institutet
*
* qa_fx_a6_network, clear [tier(micro|unit) seed(#) perturb(op)]
* Arm schema rowid study trt n events mean sd; means 0,1,2,3, odds 1,2,4,8,
* SD=2; n=900 (micro), 900000 (unit). Exact EXPECTED counts, not random draws.
* r(truth_contrasts): study from to md logor; every within-study pair.
* r(truth_multiarm_cov): study1 mean-contrast covariance B-A,C-A (diag8/n,
* offdiag4/n). Undefined for disconnected/duplicate keys: missing matrix and
* truth_multiarm_defined=0. Exact pooled consistent effects follow because each contrast
* equals its population effect. No recovery/MC tier; unsupported tier ->198.
* Operators disconnected_network, zero_cells, single_study,
* reversed_contrasts, dup_study_id, multi_arm_correlation, inconsistency,
* boundary_values, unsorted. zero_cells/boundary_values use +.5 in ALL four
* cells of each affected pair, explicitly declared. inconsistency changes
* study4 D to mean4, odds9. Truth_contrasts follows every changed design.
*
* qa_fx_a6_estmat, clear [tier(micro|unit) seed(#) perturb(op) post]
* Schema rowid term b se ll ul p omitted base ci_unbounded.
* r(truth_table)/r(table): b se ll ul p rows, coefficient-stripe columns.
* r(b),r(V): native matrix surfaces; post deliberately overwrites e() with
* e(b),e(V),e(N)=100,e(cmd),e(ci_unbounded). Missing SE+post refuses pre-mutation.
* Operators omitted, base_rows, missing_se, infinite_ci, positional_mismatch,
* long_row_names (32-byte last-character twins), factor_names, boundary_values.
* Unbounded CI is represented by .a(-infinity)/.b(+infinity), with explicit flag;
* Stata cannot store IEEE infinities. Positional mismatch permutes table
* columns+stripes, leaving e(b)/r(b) in dataset order. Do not match by position.
* Normal CI/p definition: https://www.stata.com/manuals/m-5normal.pdf
* fetched 2026-09-30; z=invnormal(.975), p=2*normal(-abs(b/se)).
*
* qa_fx_a6_bias, clear [tier(micro|unit) seed(#) perturb(boundary_values)]
* Schema exposure outcome true_n observed_n selection_n selection_prob se sp
* rr_uy p_u1 p_u0. True cells E1Y1/E1Y0/E0Y1/E0Y0=40/60/20/80; outcome
* Se=.8,Sp=.9 -> observed38/62/24/76. Corrected RR2,OR8/3,RD1/5.
* SEPARATE confounding analysis: RR_UY3,P(U|E1)=.5,P(U|E0)=1/6 -> factor3/2,
* observed RR2 -> corrected4/3. SEPARATE selection: probabilities .5/1/1/1 ->
* selected20/60/20/80,OR4/3 -> corrected8/3. Not a joint/sequential correction.
* boundary_values: Se=Sp=1. Truth from cell enumeration/forward probabilities.
* Fox et al. IJE2023 doi:10.1093/ije/dyad053, Table1/confounding methods:
* https://pmc.ncbi.nlm.nih.gov/articles/PMC10555728/ fetched 2026-09-30.
*
* One named operator per call. Primitives refused with existing helper pointer.
* r(perturb_n_<op>) and _dta[qa_fx_perturb_n] count affected/witness units
* (arms/contrast rows, coefficient rows, labelled rows or workbook sheets).
* All publish r(N/seed/tier/perturb/perturb_applied/expect_class) and
* _dta[qa_fx_generator/version/seed/tier/perturb/schema]. Matrix truth persists
* as qa_truth_<key>_rows/cols/rownames/colnames and qa_t_<key>_<i>_<j> (%21x).
* Scalar truth persists as qa_truth_<key> (%21x). clear is required.

capture program drop _qa_fxa6_args
program define _qa_fxa6_args
    version 16.0
    args who tier op known
    if !inlist("`tier'", "micro", "unit") {
        di as error "`who': deterministic micro/unit only; no recovery MC DGP"
        exit 198
    }
    foreach pair in miss_extended:qa_hostile_missing codes_negative:qa_hostile_codes ///
        codes_big:qa_hostile_codes long_names:qa_hostile_names ///
        string_hostile:qa_hostile_strings time_hostile:qa_hostile_times {
        gettoken primitive helper : pair, parse(":")
        if "`op'"=="`primitive'" {
            di as error "`who': primitive `op'; use `=substr("`helper'",2,.)' in _qa_hostile.do"
            exit 198
        }
    }
    if "`op'"!="" & !`: list op in known' {
        di as error "`who': exactly one supported operator required: `known'"
        exit 198
    }
end

capture program drop _qa_fxa6_meta
program define _qa_fxa6_meta
    version 16.0
    args generator seed tier op schema
    char _dta[qa_fx_generator] "_qa_fx_a6 `generator'"
    char _dta[qa_fx_version] "1.0.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_tier] "`tier'"
    char _dta[qa_fx_perturb] "`op'"
    char _dta[qa_fx_schema] "`schema'"
end

capture program drop _qa_fxa6_mchar
program define _qa_fxa6_mchar
    version 16.0
    args key mat
    char _dta[qa_truth_`key'_rows] "`=rowsof(`mat')'"
    char _dta[qa_truth_`key'_cols] "`=colsof(`mat')'"
    char _dta[qa_truth_`key'_rownames] "`: rownames `mat''"
    char _dta[qa_truth_`key'_colnames] "`: colnames `mat''"
    forvalues i=1/`=rowsof(`mat')' {
        forvalues j=1/`=colsof(`mat')' {
            char _dta[qa_t_`key'_`i'_`j'] "`: display %21x `mat'[`i',`j']'"
        }
    }
end

capture program drop qa_fx_a6_network
program define qa_fx_a6_network, rclass
    version 16.0
    syntax , CLEAR [TIER(string) SEED(integer 20260930) PERTurb(string)]
    if "`tier'"=="" local tier unit
    local known disconnected_network zero_cells single_study reversed_contrasts ///
        dup_study_id multi_arm_correlation inconsistency boundary_values unsorted
    _qa_fxa6_args qa_fx_a6_network "`tier'" "`perturb'" "`known'"
    local size=cond("`tier'"=="micro",900,900000)
    clear
    tempname D
    matrix `D'=(1,1\1,2\1,3\2,2\2,4\3,3\3,4\4,1\4,4)
    matrix colnames `D'=study trt
    quietly svmat byte `D', names(col)
    if inlist("`perturb'","single_study","multi_arm_correlation") quietly keep if study==1
    if "`perturb'"=="disconnected_network" {
        quietly keep if (study==1 & trt<=2) | study==3
        assert (study==1 & trt<=2) | (study==3 & trt>=3)
        assert _N==4
    }
    if "`perturb'"=="dup_study_id" {
        quietly expand 2 if study==1 & trt==1
        capture isid study trt
        if !_rc exit 9
    }
    quietly {
        gen long rowid=_n
        gen double n=`size'
        gen double mean=trt-1
        gen double sd=2
        gen double events=n*2^(trt-1)/(1+2^(trt-1))
    }
    if "`perturb'"=="inconsistency" {
        quietly replace mean=4 if study==4 & trt==4
        quietly replace events=n*9/10 if study==4 & trt==4
        assert mean==4 & events==n*9/10 if study==4 & trt==4
    }
    if "`perturb'"=="zero_cells" quietly replace events=0 if study==1 & trt==1
    if "`perturb'"=="boundary_values" quietly replace events=n if study==1 & trt==1
    assert events==floor(events) & inrange(events,0,n)
    if "`perturb'"=="zero_cells" assert events==0 if study==1 & trt==1
    if "`perturb'"=="boundary_values" assert events==n if study==1 & trt==1
    tempname C V
    matrix `C'=J(1,5,.)
    local k=0
    forvalues i=1/`=_N' {
        forvalues j=1/`=_N' {
            if `j'>`i' & study[`i']==study[`j'] & trt[`i']!=trt[`j'] {
                local ++k
                if `k'>1 matrix `C'=`C'\J(1,5,.)
                local cc=events[`i']==0 | events[`i']==n[`i'] | events[`j']==0 | events[`j']==n[`j']
                matrix `C'[`k',1]=study[`i']
                matrix `C'[`k',2]=trt[`i']
                matrix `C'[`k',3]=trt[`j']
                matrix `C'[`k',4]=mean[`j']-mean[`i']
                matrix `C'[`k',5]=ln((events[`j']+.5*`cc')/(n[`j']-events[`j']+.5*`cc')) - ///
                    ln((events[`i']+.5*`cc')/(n[`i']-events[`i']+.5*`cc'))
            }
        }
    }
    if "`perturb'"=="reversed_contrasts" {
        forvalues i=1/`k' {
            local old=`C'[`i',2]
            matrix `C'[`i',2]=`C'[`i',3]
            matrix `C'[`i',3]=`old'
            matrix `C'[`i',4]=-`C'[`i',4]
            matrix `C'[`i',5]=-`C'[`i',5]
        }
        assert `C'[1,2]==2 & `C'[1,3]==1 & `C'[1,4]==-1
    }
    matrix colnames `C'=study from to md logor
    matrix `V'=(8/`size',4/`size'\4/`size',8/`size')
    local multidef=!inlist("`perturb'","disconnected_network","dup_study_id")
    if !`multidef' matrix `V'=J(2,2,.)
    matrix colnames `V'=B_A C_A
    matrix rownames `V'=B_A C_A
    if inlist("`perturb'","single_study","multi_arm_correlation") assert _N==3
    if "`perturb'"=="multi_arm_correlation" assert `V'[1,2]>0 & `V'[1,2]/`V'[1,1]==.5
    if "`perturb'"=="unsorted" {
        gsort -rowid
        assert rowid[1]>rowid[_N]
    }
    local affected=_N
    if inlist("`perturb'","zero_cells","boundary_values","inconsistency") local affected=1
    if "`perturb'"=="dup_study_id" local affected=2
    if "`perturb'"=="reversed_contrasts" local affected=rowsof(`C')
    _qa_fxa6_meta qa_fx_a6_network `seed' `tier' "`perturb'" "rowid study trt n events mean sd"
    _qa_fxa6_mchar contrasts `C'
    _qa_fxa6_mchar multiarm_cov `V'
    char _dta[qa_truth_multiarm_scope] "study1 mean contrasts B-A,C-A; undefined if disconnected or duplicate keys"
    char _dta[qa_truth_multiarm_defined] "`: display %21x `multidef''"
    char _dta[qa_truth_cc] "0.5 in all four cells of zero/full-event pairs; otherwise 0"
    local expect EXACT
    if inlist("`perturb'","dup_study_id","disconnected_network") local expect REFUSED
    if "`perturb'"=="unsorted" local expect INVARIANT
    if "`perturb'"=="reversed_contrasts" local expect SHIFTED
    if "`perturb'"=="" local expect ""
    return matrix truth_contrasts=`C'
    return matrix truth_multiarm_cov=`V'
    return scalar truth_multiarm_defined=`multidef'
    if "`perturb'"=="" local affected=0
    char _dta[qa_fx_perturb_n] "`: display %21x `affected''"
    if "`perturb'"!="" return scalar perturb_n_`perturb'=`affected'
    return scalar N=_N
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`perturb'"
    return local perturb_applied "`perturb'"
    return local expect_class "`expect'"
end

capture program drop _qa_fxa6_post
program define _qa_fxa6_post, eclass
    version 16.0
    args B V unbounded
    tempname BB VV
    matrix `BB'=`B'
    matrix `VV'=`V'
    ereturn post `BB' `VV', obs(100)
    ereturn scalar ci_unbounded=`unbounded'
    ereturn local cmd "qa_fx_a6_estmat"
end

capture program drop qa_fx_a6_estmat
program define qa_fx_a6_estmat, rclass
    version 16.0
    syntax , CLEAR [TIER(string) SEED(integer 20260930) PERTurb(string) POST]
    if "`tier'"=="" local tier unit
    local known omitted base_rows missing_se infinite_ci positional_mismatch ///
        long_row_names factor_names boundary_values
    _qa_fxa6_args qa_fx_a6_estmat "`tier'" "`perturb'" "`known'"
    if "`post'"!="" & "`perturb'"=="missing_se" {
        di as error "qa_fx_a6_estmat: missing_se cannot post valid e(V)"
        exit 198
    }
    clear
    tempname D
    matrix `D'=(.5,.25\-1,.5\2,1)
    matrix colnames `D'=b se
    quietly svmat double `D', names(col)
    quietly gen str32 term=cond(_n==1,"x",cond(_n==2,"2.group","_cons"))
    quietly {
        gen long rowid=_n
        gen byte omitted=0
        gen byte base=0
        gen byte ci_unbounded=0
    }
    if "`perturb'"=="omitted" {
        quietly replace term="o.x" in 1
        quietly replace b=0 in 1
        quietly replace se=0 in 1
        quietly replace omitted=1 in 1
        assert b==0 & se==0 & omitted==1 in 1
    }
    if "`perturb'"=="base_rows" {
        quietly replace term="1b.group" in 2
        quietly replace b=0 in 2
        quietly replace se=0 in 2
        quietly replace base=1 in 2
        assert b==0 & se==0 & base==1 in 2
    }
    if "`perturb'"=="missing_se" quietly replace se=. in 2
    if "`perturb'"=="factor_names" {
        quietly replace term="20.group" in 2
        assert term=="20.group" in 2
    }
    if "`perturb'"=="long_row_names" {
        quietly replace term="abcdefghijklmnopqrstuvwxyzabcdeA" in 1
        quietly replace term="abcdefghijklmnopqrstuvwxyzabcdeB" in 2
        assert strlen(term)==32 in 1/2
        assert substr(term[1],1,31)==substr(term[2],1,31) & term[1]!=term[2]
    }
    if "`perturb'"=="boundary_values" quietly replace b=0 in 3
    quietly {
        gen double ll=b-invnormal(.975)*se
        gen double ul=b+invnormal(.975)*se
        gen double p=cond(se>0 & !missing(se),2*normal(-abs(b/se)),.)
        replace ll=. if omitted | base
        replace ul=. if omitted | base
    }
    if "`perturb'"=="infinite_ci" {
        quietly replace ll=.a in 1
        quietly replace ul=.b in 1
        quietly replace ci_unbounded=1 in 1
        assert ll==.a & ul==.b & ci_unbounded==1 in 1
    }
    if "`perturb'"=="missing_se" assert missing(se,ll,ul,p) in 2
    if "`perturb'"=="boundary_values" assert b==0 & p==1 in 3
    tempname T B V
    quietly mkmat b se ll ul p, matrix(`T')
    matrix `T'=`T''
    matrix rownames `T'=b se ll ul p
    matrix `B'=`T'[1,1...]
    matrix `V'=J(3,3,0)
    local terms ""
    forvalues i=1/3 {
        local terms `terms' `=term[`i']'
        matrix `V'[`i',`i']=se[`i']^2
    }
    matrix colnames `T'=`terms'
    matrix colnames `B'=`terms'
    matrix rownames `V'=`terms'
    matrix colnames `V'=`terms'
    if "`perturb'"=="positional_mismatch" {
        matrix `T'=`T'[1...,3],`T'[1...,1],`T'[1...,2]
        assert `T'[1,1]==b[3] & `T'[1,2]==b[1]
    }
    _qa_fxa6_meta qa_fx_a6_estmat `seed' `tier' "`perturb'" "rowid term b se ll ul p omitted base ci_unbounded"
    _qa_fxa6_mchar table `T'
    _qa_fxa6_mchar b `B'
    _qa_fxa6_mchar V `V'
    local unbounded="`perturb'"=="infinite_ci"
    if "`post'"!="" _qa_fxa6_post `B' `V' `unbounded'
    char _dta[qa_truth_ci_unbounded] "`: display %21x `unbounded''"
    tempname TT
    matrix `TT'=`T'
    return matrix truth_table=`T'
    return matrix table=`TT'
    return matrix b=`B'
    return matrix V=`V'
    return scalar N=_N
    return scalar seed=`seed'
    local affected=cond("`perturb'"=="long_row_names",2,cond("`perturb'"=="positional_mismatch",3,1))
    if "`perturb'"=="" local affected=0
    char _dta[qa_fx_perturb_n] "`: display %21x `affected''"
    return scalar truth_ci_unbounded=`unbounded'
    if "`perturb'"!="" return scalar perturb_n_`perturb'=`affected'
    return local tier "`tier'"
    return local perturb "`perturb'"
    return local perturb_applied "`perturb'"
    return local expect_class=cond("`perturb'"=="","","EXACT")
end

capture program drop qa_fx_a6_bias
program define qa_fx_a6_bias, rclass
    version 16.0
    syntax , CLEAR [TIER(string) SEED(integer 20260930) PERTurb(string)]
    if "`tier'"=="" local tier unit
    _qa_fxa6_args qa_fx_a6_bias "`tier'" "`perturb'" "boundary_values"
    clear
    tempname D
    matrix `D'=(1,1,40,38,20,.5\1,0,60,62,60,1\0,1,20,24,20,1\0,0,80,76,80,1)
    matrix colnames `D'=exposure outcome true_n observed_n selection_n selection_prob
    quietly svmat double `D', names(col)
    quietly {
        gen double se=.8
        gen double sp=.9
        gen double rr_uy=3
        gen double p_u1=.5
        gen double p_u0=1/6
    }
    if "`perturb'"=="boundary_values" {
        quietly replace se=1
        quietly replace sp=1
        quietly replace observed_n=true_n
        assert se==1 & sp==1 & observed_n==true_n
    }
    assert selection_n==true_n*selection_prob
    tempname T
    matrix `T'=(40,60\20,80)
    matrix rownames `T'=exposed unexposed
    matrix colnames `T'=event nonevent
    _qa_fxa6_meta qa_fx_a6_bias `seed' `tier' "`perturb'" "exposure outcome true_n observed_n selection_n selection_prob se sp rr_uy p_u1 p_u0"
    _qa_fxa6_mchar corrected `T'
    foreach key in rr or rd confounding_factor confounding_rr selection_factor selection_or {
        local val=cond("`key'"=="rr",2,cond("`key'"=="or",8/3,cond("`key'"=="rd",1/5, ///
            cond("`key'"=="confounding_factor",3/2,cond("`key'"=="confounding_rr",4/3, ///
            cond("`key'"=="selection_factor",2,8/3))))))
        char _dta[qa_truth_`key'] "`: display %21x `val''"
        return scalar truth_`key'=`val'
    }
    return matrix truth_corrected=`T'
    local affected=cond("`perturb'"=="",0,4)
    char _dta[qa_fx_perturb_n] "`: display %21x `affected''"
    if "`perturb'"!="" return scalar perturb_n_`perturb'=4
    return scalar N=_N
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`perturb'"
    return local perturb_applied "`perturb'"
    return local expect_class=cond("`perturb'"=="","","EXACT")
end

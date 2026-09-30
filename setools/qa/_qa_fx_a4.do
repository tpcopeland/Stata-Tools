*! qa-lib _qa_fx_a4 1.0.0 sha256:e13ea21abbbe4a268ef5ec7232cc87f0615b51300dfb529de703520341d1b164
* _qa_fx_a4.do -- exact interval and nearest-date fixtures, Stata 16+
* Timothy P Copeland, Karolinska Institutet
*
* qa_fx_a4_spells, clear [tier(micro|unit|recovery) n(#) seed(#)
*   perturb(overlap abut zero_length open_end unsorted dup_key boundary_values)
*   names(old=new ...)]
* Schema: id spell_id start stop category dose. Half-open [start,stop),
* clipped to the eight-day truth_window. Missing stop means window_stop.
* truth_panel: id date category dose cumdose; category0=unexposed, -1=multiple
* categories. Dose sums active spells, cumulative dose includes current day.
* truth_time: id category days counts UNION within category, not duplicate rows.
*
* qa_fx_a4_asof, clear [tier(...) n(#) seed(#) window(integer 2)
*   perturb(ties boundary_values missing_anchor dup_key unsorted) names(...)]
* Schema: id role date anchor_id event_id value; role1=anchor, role2=event.
* truth_matches: id anchor_id date before_id after_id window_n window_sum.
* Inclusive nearest-before/after. Equal dates choose smallest event_id;
* window abs(eventdate-anchor)<=window. Missing anchors have missing match
* IDs and zero window counts/sums. Duplicate records count separately.
*
* Deterministic tiers repeat 2/8/32 ids; n() overrides 1..128. Recovery scales
* cardinality, not Monte Carlo accuracy. Seed affects permutation only.
* r(truth_*) matrices persist under qa_truth_<name>_{rows,cols,schema,row#},
* numeric row tokens in %21x; scalar truth likewise. Identifiers always refer
* to canonical values even after names(). Invalid options refused before clear.
* time_hostile/long_names/etc point to existing primitive helpers (rc198).
* Other errors: missing required clear rc198; lost hostile property rc9.

capture program drop _qa_fxa4_options
program define _qa_fxa4_options, sclass
    version 16.0
    syntax , WHO(string) VARS(string) KNOWN(string) [TIER(string) N(integer 0) PERTurb(string) NAMES(string)]
    if "`tier'"=="" local tier unit
    if !inlist("`tier'","micro","unit","recovery") {
        di as error "`who': tier() must be micro, unit or recovery"
        exit 198
    }
    if `n'==0 local n=cond("`tier'"=="micro",2,cond("`tier'"=="unit",8,32))
    if `n'<1 | `n'>128 {
        di as error "`who': n() must be 1..128"
        exit 198
    }
    local ops : list uniq perturb
    foreach op of local ops {
        local helper ""
        if "`op'"=="time_hostile" local helper qa_hostile_times
        if "`op'"=="long_names" local helper qa_hostile_names
        if "`op'"=="miss_extended" local helper qa_hostile_missing
        if inlist("`op'","codes_negative","codes_big") local helper qa_hostile_codes
        if "`op'"=="string_hostile" local helper qa_hostile_strings
        if "`helper'"!="" {
            di as error "`who': `op' is primitive; call `helper' directly"
            exit 198
        }
        if !`: list op in known' {
            di as error "`who': unknown perturb() operator `op'"
            exit 198
        }
    }
    local olds ""
    local news ""
    foreach pair of local names {
        if !regexm("`pair'","^([A-Za-z_][A-Za-z_0-9]*)=([A-Za-z_][A-Za-z_0-9]*)$") {
            di as error "`who': names() requires old=new pairs"
            exit 198
        }
        local old=regexs(1)
        local new=regexs(2)
        capture confirm names `new'
        if _rc | strlen("`new'")>32 | !`: list old in vars' | `: list old in olds' | `: list new in news' {
            di as error "`who': invalid or duplicate names() mapping `pair'"
            exit 198
        }
        if "`old'"!="`new'" & `: list new in vars' {
            di as error "`who': names() target `new' collides with schema"
            exit 198
        }
        local olds `olds' `old'
        local news `news' `new'
    }
    sreturn local ops "`ops'"
    sreturn local tier "`tier'"
    sreturn local n "`n'"
end

capture program drop _qa_fxa4_store
program define _qa_fxa4_store
    version 16.0
    args name M schema
    char _dta[qa_truth_`name'_rows] "`=rowsof(`M')'"
    char _dta[qa_truth_`name'_cols] "`=colsof(`M')'"
    char _dta[qa_truth_`name'_schema] "`schema'"
    forvalues i=1/`=rowsof(`M')' {
        local tokens ""
        forvalues j=1/`=colsof(`M')' {
            local tokens `tokens' `: display %21x `M'[`i',`j']'
        }
        char _dta[qa_truth_`name'_row`i'] "`tokens'"
    }
end

capture program drop _qa_fxa4_finish
program define _qa_fxa4_finish
    version 16.0
    syntax , GENERATOR(string) TIER(string) SEED(integer) [OPS(string) NAMES(string)]
    foreach pair of local names {
        local eq=strpos("`pair'","=")
        local old=substr("`pair'",1,`eq'-1)
        local new=substr("`pair'",`eq'+1,.)
        if "`old'"!="`new'" rename `old' `new'
    }
    char _dta[qa_fx_generator] "_qa_fx_a4 `generator'"
    char _dta[qa_fx_version] "1.0.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_tier] "`tier'"
    char _dta[qa_fx_perturb] "`ops'"
    char _dta[qa_fx_names] "`names'"
end

capture program drop _qa_fxa4_shuffle
program define _qa_fxa4_shuffle, rclass
    version 16.0
    tempvar u ord
    gen long `ord'=_n
    gen double `u'=runiform()
    sort `u'
    count if `ord'!=_n
    local hits=r(N)
    drop `u' `ord'
    if `hits'==0 {
        di as error "qa_fx_a4: unsorted lost its property"
        exit 9
    }
    return scalar hits=`hits'
end

capture program drop qa_fx_a4_spells
program define qa_fx_a4_spells, rclass
    version 16.0
    syntax , CLEAR [TIER(string) N(integer 0) SEED(integer 20260930) PERTurb(string) NAMES(string)]
    if `seed'<0 | `seed'>2147483647 {
        di as error "qa_fx_a4_spells: seed() must be 0..2147483647"
        exit 198
    }
    local known overlap abut zero_length open_end unsorted dup_key boundary_values
    _qa_fxa4_options, who(qa_fx_a4_spells) vars(id spell_id start stop category dose) known(`known') tier(`tier') n(`n') perturb(`perturb') names(`names')
    local ops `s(ops)'
    local tier `s(tier)'
    local n `s(n)'
    foreach op of local known {
        local p_`op'=`: list op in ops'
    }
    if `p_overlap' & `p_abut' {
        di as error "qa_fx_a4_spells: overlap and abut conflict"
        exit 198
    }
    if `p_overlap' & `p_zero_length' {
        di as error "qa_fx_a4_spells: overlap and zero_length conflict"
        exit 198
    }
    clear
    set seed `seed'
    local base=cond(`p_boundary_values',mdy(12,29,2019),mdy(2,27,2020))
    quietly {
        set obs `=3*`n''
        gen long id=ceil(_n/3)
        gen long spell_id=_n
        gen double start=`base'+3*mod(_n-1,3)
        gen double stop=start+2
        gen byte category=cond(mod(_n-1,3)==1,2,1)
        gen double dose=cond(mod(_n-1,3)==0,2,cond(mod(_n-1,3)==1,3,1))
        if `p_overlap' replace start=`base'+1 if mod(spell_id,3)==2
        if `p_abut' replace start=`base'+2 if mod(spell_id,3)==2
        if `p_zero_length' replace stop=start if mod(spell_id,3)==2
        if `p_open_end' replace stop=. if mod(spell_id,3)==0
        if `p_boundary_values' {
            replace start=`base'-2 if mod(spell_id,3)==1
            replace stop=`base'+10 if mod(spell_id,3)==0 & !missing(stop)
        }
        if `p_dup_key' expand 2 if spell_id==1
        sort id start spell_id
    }
    foreach op of local ops {
        if "`op'"=="overlap" count if mod(spell_id,3)==2 & start<`base'+2 & stop>start
        if "`op'"=="abut" count if mod(spell_id,3)==2 & start==`base'+2
        if "`op'"=="zero_length" count if start==stop
        if "`op'"=="open_end" count if missing(stop)
        if "`op'"=="boundary_values" count if start<`base' | (stop>`base'+8 & !missing(stop))
        if "`op'"=="dup_key" count if spell_id==1
        if "`op'"!="unsorted" {
            if r(N)<1 | ("`op'"=="dup_key" & r(N)!=2) {
                di as error "qa_fx_a4_spells: `op' lost its property"
                exit 9
            }
            local hits_`op'=r(N)
        }
    }
    tempname P T
    mata: _qa_fxa4_days(`n',`base',"`P'","`T'")
    matrix colnames `P'=id date category dose cumdose
    matrix colnames `T'=id category days
    _qa_fxa4_store panel `P' "id date category dose cumdose"
    _qa_fxa4_store time `T' "id category days"
    if `p_unsorted' {
        _qa_fxa4_shuffle
        local hits_unsorted=r(hits)
    }
    format start stop %td
    _qa_fxa4_finish, generator(qa_fx_a4_spells) tier(`tier') seed(`seed') ops(`ops') names(`names')
    char _dta[qa_truth_window_start] "`: display %21x `base''"
    char _dta[qa_truth_window_stop] "`: display %21x `base'+8'"
    foreach op of local ops {
        char _dta[qa_perturb_n_`op'] "`hits_`op''"
        return scalar perturb_n_`op'=`hits_`op''
    }
    return matrix truth_panel=`P'
    return matrix truth_time=`T'
    return scalar truth_window_start=`base'
    return scalar truth_window_stop=`base'+8
    return scalar N=_N
    return scalar n_ids=`n'
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class = cond(`: word count `ops''==1,cond("`ops'"=="unsorted","INVARIANT","EXACT"),"")
end

capture program drop qa_fx_a4_asof
program define qa_fx_a4_asof, rclass
    version 16.0
    syntax , CLEAR [TIER(string) N(integer 0) SEED(integer 20260930) WINDOW(integer 2) PERTurb(string) NAMES(string)]
    if `window'<0 | `window'>30 | `seed'<0 | `seed'>2147483647 {
        di as error "qa_fx_a4_asof: window() must be 0..30"
        exit 198
    }
    local known ties boundary_values missing_anchor dup_key unsorted
    _qa_fxa4_options, who(qa_fx_a4_asof) vars(id role date anchor_id event_id value) known(`known') tier(`tier') n(`n') perturb(`perturb') names(`names')
    local ops `s(ops)'
    local tier `s(tier)'
    local n `s(n)'
    foreach op of local known {
        local p_`op'=`: list op in ops'
    }
    clear
    set seed `seed'
    local base=mdy(2,27,2020)
    quietly {
        set obs `=6*`n''
        gen long id=ceil(_n/6)
        gen byte role=cond(mod(_n-1,6)<3,1,2)
        gen double date=`base'+cond(role==1,1+3*mod(_n-1,3),cond(mod(_n-1,3)==0,0,cond(mod(_n-1,3)==1,2,6)))
        gen long anchor_id=cond(role==1,3*(id-1)+mod(_n-1,3)+1,.)
        gen long event_id=cond(role==2,3*(id-1)+mod(_n-1,3)+1,.)
        gen double value=cond(role==2,10*mod(_n-1,3)+10,.)
        if `p_missing_anchor' replace date=. if role==1 & mod(anchor_id,3)==2
        if `p_boundary_values' replace date=`base'+1+`window' if role==2 & mod(event_id,3)==2
        if `p_ties' {
            expand 2 if role==2 & event_id==1, gen(_copy)
            replace event_id=3*`n'+1 if _copy
            replace value=99 if _copy
            drop _copy
        }
        if `p_dup_key' expand 2 if role==2 & event_id==1
        sort id role date event_id
    }
    foreach op of local ops {
        if "`op'"=="ties" count if role==2 & id==1 & date==`base'
        if "`op'"=="dup_key" count if role==2 & event_id==1
        if "`op'"=="missing_anchor" count if role==1 & missing(date)
        if "`op'"=="boundary_values" count if role==2 & date==`base'+1+`window'
        if "`op'"!="unsorted" {
            if r(N)<1 | (inlist("`op'","ties","dup_key") & r(N)<2) {
                di as error "qa_fx_a4_asof: `op' lost its property"
                exit 9
            }
            local hits_`op'=r(N)
        }
    }
    tempname M
    mata: _qa_fxa4_matches(`window',"`M'")
    matrix colnames `M'=id anchor_id date before_id after_id window_n window_sum
    _qa_fxa4_store matches `M' "id anchor_id date before_id after_id window_n window_sum"
    if `p_unsorted' {
        _qa_fxa4_shuffle
        local hits_unsorted=r(hits)
    }
    format date %td
    _qa_fxa4_finish, generator(qa_fx_a4_asof) tier(`tier') seed(`seed') ops(`ops') names(`names')
    char _dta[qa_truth_window] "`: display %21x `window''"
    foreach op of local ops {
        char _dta[qa_perturb_n_`op'] "`hits_`op''"
        return scalar perturb_n_`op'=`hits_`op''
    }
    return matrix truth_matches=`M'
    return scalar truth_window=`window'
    return scalar N=_N
    return scalar n_ids=`n'
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class = cond(`: word count `ops''==1,cond("`ops'"=="unsorted","INVARIANT","EXACT"),"")
end

capture mata: mata drop _qa_fxa4_days()
capture mata: mata drop _qa_fxa4_matches()
mata:
void _qa_fxa4_days(real scalar n, real scalar base, string scalar pn, string scalar tn)
{
    real matrix S,P,T
    real scalar id,d,j,row,c,dose,cum
    real rowvector cats
    S=st_data(.,("id","start","stop","category","dose"))
    P=J(8*n,5,0); T=J(2*n,3,0); row=0
    for(id=1;id<=n;id++) {
        cum=0
        T[2*id-1,1..2]=(id,1); T[2*id,1..2]=(id,2)
        for(d=base;d<base+8;d++) {
            cats=J(1,2,0);dose=0
            for(j=1;j<=rows(S);j++) {
                if(S[j,1]==id & S[j,2]<=d & (S[j,3]>=. | d<S[j,3])) {
                    cats[S[j,4]]=1;dose=dose+S[j,5]
                }
            }
            c=0
            if(sum(cats)==1) c=selectindex(cats)[1]
            if(sum(cats)>1) c=-1
            cum=cum+dose;row++
            P[row,.]=(id,d,c,dose,cum)
            T[2*id-1,3]=T[2*id-1,3]+cats[1]
            T[2*id,3]=T[2*id,3]+cats[2]
        }
    }
    st_matrix(pn,P);st_matrix(tn,T)
}
void _qa_fxa4_matches(real scalar w, string scalar mn)
{
    real matrix D,A,E,M
    real scalar i,j,b,a,bd,ad,n,s,t
    D=st_data(.,("id","role","date","anchor_id","event_id","value"))
    A=select(D,D[.,2]:==1);E=select(D,D[.,2]:==2)
    A=sort(A,(1,4));M=J(rows(A),7,.)
    for(i=1;i<=rows(A);i++) {
        b=.;a=.;bd=-.;ad=.;n=0;s=0
        if(A[i,3]<.) for(j=1;j<=rows(E);j++) {
            if(E[j,1]!=A[i,1] | E[j,3]>=.) continue
            t=E[j,3]
            if(t<=A[i,3] & (b>=. | t>bd | (t==bd & E[j,5]<b))) {b=E[j,5];bd=t;}
            if(t>=A[i,3] & (a>=. | t<ad | (t==ad & E[j,5]<a))) {a=E[j,5];ad=t;}
            if(abs(t-A[i,3])<=w) {n++;s=s+E[j,6];}
        }
        M[i,.]=(A[i,1],A[i,4],A[i,3],b,a,n,s)
    }
    st_matrix(mn,M)
}
end

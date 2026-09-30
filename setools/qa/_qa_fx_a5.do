*! qa-lib _qa_fx_a5 1.0.0 sha256:d0c8aa3d8e78debcf60a87af414a2946398d292e5d2298398f043995d7b2cbd6
* _qa_fx_a5.do -- exact wide-code and conditional-Poisson tree fixtures
* Timothy P Copeland, Karolinska Institutet
*
* qa_fx_a5_wide, clear [tier(micro|unit|recovery) n(#) k(integer 4)
*   seed(#) perturb(codes_sparse prefix_ambiguous_codes
*   case_whitespace_variants empty_slots dates_out_of_window unsorted)
*   names(old=new ...)]
* Schema id date group dx1..dxK proc1 proc2. K4..30; deterministic four
* profiles, tier4/16/64 ids, n4..128 (multiple4). Date window is inclusive.
* Normalize uppercase/trim/remove dots, then LONGEST matching prefix in the
* explicit toy map: I210->specific MI(5), I21->MI(1), I2->broad code(6),
* E11->diabetes(2), N18->renal(3), C78->metastatic tumor(4).
* This map tests code scanning; it is NOT a complete ICD-to-CCI algorithm.
* Proc P01/Q01 exact normalized matches. truth_ids columns: id mi diabetes
* renal metastatic dx_n proc_n cci; truth_codes: id category slots (1..6).
* CCI presence weights MI1 diabetes1 renal2 metastatic6, no age component,
* no severity conflicts in these profiles. Source fetched 2026-09-30:
* Charlson et al.1987 DOI10.1016/0021-9681(87)90171-8 p377 Table3.
* truth_map: pattern_index category cci_weight. truth_patterns identifies rows.
* long_names/string_hostile primitives point to qa_hostile_names/strings.
* Use k(30) names(...) to supply 32-character slot names safely (no truncation).
*
* qa_fx_a5_tree, clear [tier(...) scenario(null|alternative) reps(integer 99)
*   seed(#) perturb(single_child zero_cases absent_code dup_edge unsorted)
*   names(old=new ...)]
* Schema node parent cases exposed; each node row holds DIRECT counts only.
* Root1, branches2/3, leaves4..7. Cases4 per leaf, exposure100. Alternative
* multiplies leaf4 cases by3 (injected RR3 vs other leaves); tier multipliers
* 1/10/100. Candidate cuts are each NONROOT node's full descendant subtree,
* conditional Poisson one-sided excess risk; NOT arbitrary child subsets.
* Truth recomputed by brute-force ancestor walks; duplicate edges are
* deduplicated in the oracle, absent node999 counts excluded and declared.
* r(truth_nodes): node cases exposed expected rr llr. Root rr missing.
* r(truth_cut) is the independently maximized node, smallest ID breaks ties;
* zero max => cut missing. r(truth_null_counts): fixed-total null multinomial
* samples per direct-count node (columns node<ID>); truth_null_max and
* truth_rank=1+sum(nullmax>=observed); truth_p=rank/(reps+1), conservative
* ties. Exact likelihood, Monte Carlo rank (not exact tail probability).
* TreeScan official User Guide2.1 pp10–11,13,52 fetched 2026-09-30.
* Tiers scale deterministic counts/cardinality, not parameter recovery.
*
* Short receipts (32-char limit): case_whitespace_variants -> case_whitespace;
* prefix_ambiguous_codes -> prefix_ambiguous, under perturb_n_<receipt>.
* All truth matrices persist as _dta[qa_truth_<name>_{rows,cols,schema,row#}]
* with %21x tokens. Scalar truths, seed, scenario, operators persist too.
* Options/names validated before clear; hostile properties rechecked rc9.

capture program drop _qa_fxa5_preflight
program define _qa_fxa5_preflight, sclass
    version 16.0
    syntax , WHO(string) VARS(string) KNOWN(string) [TIER(string) PERTurb(string) NAMES(string)]
    if "`tier'"=="" local tier unit
    if !inlist("`tier'","micro","unit","recovery") {
        di as error "`who': tier() must be micro, unit or recovery"
        exit 198
    }
    local ops : list uniq perturb
    foreach op of local ops {
        local helper ""
        if "`op'"=="long_names" local helper qa_hostile_names
        if "`op'"=="string_hostile" local helper qa_hostile_strings
        if "`op'"=="miss_extended" local helper qa_hostile_missing
        if inlist("`op'","codes_negative","codes_big") local helper qa_hostile_codes
        if "`op'"=="time_hostile" local helper qa_hostile_times
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
    sreturn local tier "`tier'"
    sreturn local ops "`ops'"
end

capture program drop _qa_fxa5_store
program define _qa_fxa5_store
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

capture program drop _qa_fxa5_finish
program define _qa_fxa5_finish, rclass
    version 16.0
    syntax , GENERATOR(string) TIER(string) SEED(integer) [OPS(string) NAMES(string)]
    foreach pair of local names {
        local eq=strpos("`pair'","=")
        local old=substr("`pair'",1,`eq'-1)
        local new=substr("`pair'",`eq'+1,.)
        if "`old'"!="`new'" rename `old' `new'
    }
    char _dta[qa_fx_generator] "_qa_fx_a5 `generator'"
    char _dta[qa_fx_version] "1.0.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_tier] "`tier'"
    char _dta[qa_fx_perturb] "`ops'"
    char _dta[qa_fx_names] "`names'"
end

capture program drop _qa_fxa5_shuffle
program define _qa_fxa5_shuffle, rclass
    version 16.0
    tempvar u ord
    gen long `ord'=_n
    gen double `u'=runiform()
    sort `u'
    count if `ord'!=_n
    local hits=r(N)
    drop `u' `ord'
    if `hits'==0 {
        di as error "qa_fx_a5: unsorted lost its property"
        exit 9
    }
    return scalar hits=`hits'
end

capture program drop qa_fx_a5_wide
program define qa_fx_a5_wide, rclass
    version 16.0
    syntax , CLEAR [TIER(string) N(integer 0) K(integer 4) SEED(integer 20260930) PERTurb(string) NAMES(string)]
    if `k'<4 | `k'>30 | `seed'<0 | `seed'>2147483647 {
        di as error "qa_fx_a5_wide: k() must be 4..30; seed() 0..2147483647"
        exit 198
    }
    local vars id date group proc1 proc2
    forvalues j=1/`k' {
        local vars `vars' dx`j'
    }
    local known codes_sparse prefix_ambiguous_codes case_whitespace_variants empty_slots dates_out_of_window unsorted
    _qa_fxa5_preflight, who(qa_fx_a5_wide) vars(`vars') known(`known') tier(`tier') perturb(`perturb') names(`names')
    local tier `s(tier)'
    local ops `s(ops)'
    if `n'==0 local n=cond("`tier'"=="micro",4,cond("`tier'"=="unit",16,64))
    if `n'<4 | `n'>128 | mod(`n',4)!=0 {
        di as error "qa_fx_a5_wide: n() must be 4..128, multiple of4"
        exit 198
    }
    foreach op of local known {
        local p_`op'=`: list op in ops'
    }
    clear
    set seed `seed'
    local base=mdy(1,1,2020)
    quietly {
        set obs `n'
        gen long id=_n
        gen double date=`base'+mod(_n-1,4)
        gen int group=mod(_n-1,4)+1
        forvalues j=1/`k' {
            gen str12 dx`j'=""
        }
        replace dx1=cond(group==1,"I21",cond(group==2,"I210",cond(group==3,"N183","Z999")))
        replace dx2=cond(group==1,"E119",cond(group==2,"I21",cond(group==3,"N184","")))
        replace dx3=cond(group==1,"N183",cond(group==2,"I21",""))
        replace dx4=cond(group==1,"C780",cond(group==2,"E119",cond(group==3,"C780","")))
        if `k'>4 replace dx`k'="N183" if group==4
        gen str12 proc1=cond(group<=2,"P01","")
        gen str12 proc2=cond(group==2,"Q01","")
        if `p_prefix_ambiguous_codes' replace dx2="I2" if group==4
        if `p_empty_slots' replace dx3="" if group<=2
        if `p_case_whitespace_variants' {
            forvalues j=1/`k' {
                replace dx`j'=" "+lower(substr(dx`j',1,3))+"."+lower(substr(dx`j',4,.))+" " if dx`j'!=""
            }
            replace proc1=" p01 " if proc1!=""
        }
        if `p_dates_out_of_window' replace date=`base'-1 if group==1
        if `p_codes_sparse' replace group=cond(group==1,1,cond(group==2,5,cond(group==3,17,101)))
    }
    foreach op of local ops {
        if "`op'"=="codes_sparse" count if inlist(group,5,17,101)
        if "`op'"=="prefix_ambiguous_codes" count if upper(strtrim(subinstr(dx2,".","",.)))=="I2"
        if "`op'"=="case_whitespace_variants" count if dx1!=strtrim(dx1) & dx1!=upper(dx1)
        if "`op'"=="empty_slots" count if dx3=="" & dx4!=""
        if "`op'"=="dates_out_of_window" count if date<`base' | date>`base'+3
        if "`op'"!="unsorted" {
            if r(N)<1 {
                di as error "qa_fx_a5_wide: `op' lost its property"
                exit 9
            }
            local hits_`op'=r(N)
        }
    }
    tempname I C M
    mata: _qa_fxa5_wide(`k',`base',"`I'","`C'")
    matrix `M'=(1,5,1\2,1,1\3,6,0\4,2,1\5,3,2\6,4,6)
    matrix colnames `I'=id mi diabetes renal metastatic dx_n proc_n cci
    matrix colnames `C'=id category slots
    matrix colnames `M'=pattern_index category cci_weight
    _qa_fxa5_store ids `I' "id mi diabetes renal metastatic dx_n proc_n cci"
    _qa_fxa5_store codes `C' "id category slots"
    _qa_fxa5_store map `M' "pattern_index category cci_weight"
    char _dta[qa_truth_patterns] "I210 I21 I2 E11 N18 C78"
    char _dta[qa_truth_window_start] "`: display %21x `base''"
    char _dta[qa_truth_window_stop] "`: display %21x `base'+3'"
    char _dta[qa_truth_k] "`k'"
    if `p_unsorted' {
        _qa_fxa5_shuffle
        local hits_unsorted=r(hits)
    }
    format date %td
    _qa_fxa5_finish, generator(qa_fx_a5_wide) tier(`tier') seed(`seed') ops(`ops') names(`names')
    foreach op of local ops {
        local receipt "`op'"
        if "`op'"=="case_whitespace_variants" local receipt case_whitespace
        if "`op'"=="prefix_ambiguous_codes" local receipt prefix_ambiguous
        char _dta[qa_perturb_n_`receipt'] "`hits_`op''"
        return scalar perturb_n_`receipt'=`hits_`op''
    }
    return matrix truth_ids=`I'
    return matrix truth_codes=`C'
    return matrix truth_map=`M'
    return local truth_patterns "I210 I21 I2 E11 N18 C78"
    return scalar truth_window_start=`base'
    return scalar truth_window_stop=`base'+3
    return scalar N=_N
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class = cond(`: word count `ops''==1,cond(inlist("`ops'","codes_sparse","case_whitespace_variants","unsorted"),"INVARIANT","EXACT"),"")
end

capture program drop qa_fx_a5_tree
program define qa_fx_a5_tree, rclass
    version 16.0
    syntax , CLEAR [TIER(string) SCENARIO(string) REPS(integer 99) SEED(integer 20260930) PERTurb(string) NAMES(string)]
    if "`scenario'"=="" local scenario alternative
    if !inlist("`scenario'","null","alternative") | `reps'<1 | `reps'>999 | `seed'<0 | `seed'>2147483647 {
        di as error "qa_fx_a5_tree: scenario(null|alternative), reps(1..999), seed(0..2147483647) required"
        exit 198
    }
    local known single_child zero_cases absent_code dup_edge unsorted
    _qa_fxa5_preflight, who(qa_fx_a5_tree) vars(node parent cases exposed) known(`known') tier(`tier') perturb(`perturb') names(`names')
    local tier `s(tier)'
    local ops `s(ops)'
    foreach op of local known {
        local p_`op'=`: list op in ops'
    }
    local mult=cond("`tier'"=="micro",1,cond("`tier'"=="unit",10,100))
    clear
    set seed `seed'
    quietly {
        set obs 7
        gen long node=_n
        gen long parent=cond(node==1,.,cond(node<=3,1,cond(node<=5,2,3)))
        gen long cases=cond(node>=4,4*`mult',0)
        gen double exposed=cond(node>=4,100*`mult',0)
        if "`scenario'"=="alternative" replace cases=12*`mult' if node==4
        if `p_zero_cases' replace cases=0 if node==7
        if `p_single_child' {
            set obs 8
            replace node=8 in 8
            replace parent=2 in 8
            replace cases=0 in 8
            replace exposed=0 in 8
            replace parent=8 if node==4
        }
        if `p_absent_code' {
            set obs `=_N+1'
            replace node=999 in L
            replace parent=. in L
            replace cases=3*`mult' in L
            replace exposed=10*`mult' in L
        }
        if `p_dup_edge' expand 2 if node==4
        sort node
    }
    foreach op of local ops {
        if "`op'"=="single_child" count if parent==8
        if "`op'"=="zero_cases" count if node==7 & cases==0
        if "`op'"=="absent_code" count if node==999 & missing(parent)
        if "`op'"=="dup_edge" count if node==4
        if "`op'"!="unsorted" {
            if r(N)<1 | ("`op'"=="dup_edge" & r(N)!=2) {
                di as error "qa_fx_a5_tree: `op' lost its property"
                exit 9
            }
            local hits_`op'=r(N)
        }
    }
    tempname T S X V
    mata: _qa_fxa5_tree(`reps',"`T'","`S'","`X'","`V'")
    matrix colnames `T'=node cases exposed expected rr llr
    matrix colnames `X'=max_llr
    matrix colnames `V'=cut max_llr rank p total_cases total_exposed excluded_cases
    local cn ""
    forvalues j=1/`=colsof(`S')' {
        local cn `cn' node`=`T'[`j',1]'
    }
    matrix colnames `S'=`cn'
    _qa_fxa5_store nodes `T' "node cases exposed expected rr llr"
    _qa_fxa5_store null_counts `S' "`cn'"
    _qa_fxa5_store null_max `X' "max_llr"
    local j=0
    foreach v in cut max_llr rank p total_cases total_exposed excluded_cases {
        local ++j
        char _dta[qa_truth_`v'] "`: display %21x `V'[1,`j']'"
    }
    char _dta[qa_truth_scenario] "`scenario'"
    char _dta[qa_truth_reps] "`reps'"
    char _dta[qa_truth_model] "conditional_poisson_subtrees_one_sided"
    if `p_unsorted' {
        _qa_fxa5_shuffle
        local hits_unsorted=r(hits)
    }
    _qa_fxa5_finish, generator(qa_fx_a5_tree) tier(`tier') seed(`seed') ops(`ops') names(`names')
    foreach op of local ops {
        local receipt "`op'"
        if "`op'"=="case_whitespace_variants" local receipt case_whitespace
        if "`op'"=="prefix_ambiguous_codes" local receipt prefix_ambiguous
        char _dta[qa_perturb_n_`receipt'] "`hits_`op''"
        return scalar perturb_n_`receipt'=`hits_`op''
    }
    local j=0
    foreach v in cut max_llr rank p total_cases total_exposed excluded_cases {
        local ++j
        return scalar truth_`v'=`V'[1,`j']
    }
    return matrix truth_nodes=`T'
    return matrix truth_null_counts=`S'
    return matrix truth_null_max=`X'
    return scalar truth_injected_node=cond("`scenario'"=="alternative",4,.)
    return scalar truth_injected_rr=cond("`scenario'"=="alternative",3,1)
    char _dta[qa_truth_injected_node] "`: display %21x cond("`scenario'"=="alternative",4,.)'"
    char _dta[qa_truth_injected_rr] "`: display %21x cond("`scenario'"=="alternative",3,1)'"
    return scalar N=_N
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`ops'"
    return local perturb_applied "`ops'"
    return local expect_class = cond(`: word count `ops''==1,cond(inlist("`ops'","single_child","unsorted"),"INVARIANT",cond(inlist("`ops'","absent_code","dup_edge"),"REFUSED","EXACT")),"")
end

capture mata: mata drop _qa_fxa5_wide()
capture mata: mata drop _qa_fxa5_llr()
capture mata: mata drop _qa_fxa5_tree()
mata:
void _qa_fxa5_wide(real scalar k, real scalar base, string scalar iname, string scalar cname)
{
    string matrix D,Q
    string rowvector patterns
    string scalar z
    real rowvector cat,weights,counts,flags
    real matrix I,C,R
    real scalar i,j,h,best,longest,n,proc
    patterns=("I210","I21","I2","E11","N18","C78")
    cat=(5,1,6,2,3,4);weights=(1,1,2,6)
    D=st_sdata(.,tokens(invtokens("dx":+strofreal(1..k))))
    Q=st_sdata(.,("proc1","proc2"));R=st_data(.,("id","date"))
    I=J(rows(R),8,0);C=J(rows(R)*6,3,0)
    for(i=1;i<=rows(R);i++) {
        counts=J(1,6,0);flags=J(1,4,0);proc=0
        if(R[i,2]>=base & R[i,2]<=base+3) {
            for(j=1;j<=k;j++) {
                z=strupper(strtrim(subinstr(D[i,j],".","")))
                best=0;longest=0
                for(h=1;h<=6;h++) if(substr(z,1,strlen(patterns[h]))==patterns[h] & strlen(patterns[h])>longest) {
                    best=h;longest=strlen(patterns[h])
                }
                if(best) counts[cat[best]]=counts[cat[best]]+1
            }
            for(j=1;j<=2;j++) {
                z=strupper(strtrim(subinstr(Q[i,j],".","")))
                proc=proc+(z=="P01" | z=="Q01")
            }
        }
        flags=(counts[1]+counts[5]>0,counts[2]>0,counts[3]>0,counts[4]>0)
        I[i,.]=(R[i,1],flags,sum(counts),proc,sum(flags:*weights))
        for(h=1;h<=6;h++) C[6*(i-1)+h,.]=(R[i,1],h,counts[h])
    }
    st_matrix(iname,I);st_matrix(cname,C)
}
real scalar _qa_fxa5_llr(real scalar c, real scalar n, real scalar C, real scalar N)
{
    real scalar e,v
    if(n<=0 | n>=N | C<=0) return(0)
    e=C*n/N
    if(c<=e) return(0)
    v=c*ln(c/e)
    if(C>c) v=v+(C-c)*ln((C-c)/(C-e))
    return(v)
}
void _qa_fxa5_tree(real scalar reps, string scalar tname, string scalar sname, string scalar xname, string scalar vname)
{
    real matrix D,A,T,S,X
    real colvector nodes,cases,expo,pool,cc,pp
    real scalar i,j,h,n,C,N,cur,idx,c,e,rr,best,cut,rank,excluded,u
    D=st_data(.,("node","parent","cases","exposed"))
    excluded=sum(select(D[.,3],D[.,1]:==999))
    D=select(D,D[.,1]:!=999);D=uniqrows(sort(D,1));n=rows(D)
    nodes=D[.,1];cases=D[.,3];expo=D[.,4];A=J(n,n,0)
    // Each direct-count row walks to every ancestor; no package aggregation.
    for(j=1;j<=n;j++) {
        cur=nodes[j]
        for(h=1;h<=n;h++) {
            pp=selectindex(nodes:==cur)
            if(!rows(pp)) _error(3498,"tree parent has no unique node")
            idx=pp[1];A[idx,j]=1;cur=D[idx,2]
            if(cur>=.) break
        }
        if(cur<.) _error(3498,"tree has a cycle")
    }
    C=sum(cases);N=sum(expo);T=J(n,6,0);best=0;cut=.
    for(i=1;i<=n;i++) {
        c=sum(A[i,.]:*cases');e=sum(A[i,.]:*expo')
        rr=.;if(e>0 & e<N & C>c) rr=(c/e)/((C-c)/(N-e))
        T[i,.]=(nodes[i],c,e,C*e/N,rr,_qa_fxa5_llr(c,e,C,N))
        if(T[i,6]>best) {best=T[i,6];cut=nodes[i];}
    }
    S=J(reps,n,0);X=J(reps,1,0);pool=runningsum(expo/N)
    for(h=1;h<=reps;h++) {
        cc=J(n,1,0)
        for(j=1;j<=C;j++) {
            u=runiform(1,1);idx=selectindex(pool:>u)[1];cc[idx]=cc[idx]+1
        }
        S[h,.]=cc'
        for(i=1;i<=n;i++) X[h]=max((X[h],_qa_fxa5_llr(sum(A[i,.]:*cc'),T[i,3],C,N)))
    }
    rank=1+sum(X:>=best)
    st_matrix(tname,T);st_matrix(sname,S);st_matrix(xname,X)
    st_matrix(vname,(cut,best,rank,rank/(reps+1),C,N,excluded))
}
end

*! _simtab_qa_prior_r.do -- genuine independent caller result contexts for cold refusal QA
* Timothy P Copeland, Karolinska Institutet
version 17.0
args context
capture program drop _simtab_qa_prior_r
program define _simtab_qa_prior_r,rclass
    version 17.0
    args context
    return clear
    if "`context'"=="full" {
        tempname M
        matrix `M'=(1/7,-17\.,4.123456789012345)
        matrix rownames `M'=first second
        matrix colnames `M'=risk uncertainty
        return scalar caller_scalar=1/7
        return local caller_macro "CALLER macro payload"
        return matrix caller_matrix=`M'
    }
end
_simtab_qa_prior_r `context'

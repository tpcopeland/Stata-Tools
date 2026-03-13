{smcl}
{* *! version 1.0.3  13mar2026}{...}
{viewerjumpto "Syntax" "nma_inconsistency##syntax"}{...}
{viewerjumpto "Description" "nma_inconsistency##description"}{...}
{viewerjumpto "Options" "nma_inconsistency##options"}{...}
{viewerjumpto "Examples" "nma_inconsistency##examples"}{...}
{viewerjumpto "Stored results" "nma_inconsistency##results"}{...}
{viewerjumpto "Author" "nma_inconsistency##author"}{...}

{title:Title}

{phang}
{bf:nma_inconsistency} {hline 2} Inconsistency testing for network meta-analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_inconsistency}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt met:hod(string)}}global, nodesplit, or both (default){p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_inconsistency} tests the consistency assumption of network
meta-analysis using two approaches:

{phang2}{bf:Global test:} Compares the consistency model against an
inconsistency model using an approximate chi-squared test. The
inconsistency model log-likelihood is approximated using fixed-effect
meta-analysis within each comparison pair. A significant result
suggests that the consistency assumption may be violated.{p_end}

{phang2}{bf:Node-splitting:} For each comparison with {bf:mixed evidence}
(both direct and indirect), separates the direct and indirect estimates
and tests whether they differ. Comparisons with only direct or only
indirect evidence are skipped.{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt method(string)} specifies which test to run. {opt global} runs only
the global test. {opt nodesplit} runs only node-splitting. {opt both}
(default) runs both.

{phang}
{opt level(#)} specifies the confidence level for node-splitting results.


{marker examples}{...}
{title:Examples}

{pstd}Both tests{p_end}
{phang2}{cmd:. nma_inconsistency}{p_end}

{pstd}Global test only{p_end}
{phang2}{cmd:. nma_inconsistency, method(global)}{p_end}

{pstd}Node-splitting only{p_end}
{phang2}{cmd:. nma_inconsistency, method(nodesplit)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:nma_inconsistency} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(chi2)}}global chi-squared statistic{p_end}
{synopt:{cmd:r(chi2_df)}}degrees of freedom{p_end}
{synopt:{cmd:r(chi2_p)}}p-value for global test{p_end}
{synopt:{cmd:r(n_nodesplit)}}number of node-split comparisons{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}

{smcl}
{* *! version 1.0.3  01mar2026}{...}
{viewerjumpto "Syntax" "nma_compare##syntax"}{...}
{viewerjumpto "Description" "nma_compare##description"}{...}
{viewerjumpto "Options" "nma_compare##options"}{...}
{viewerjumpto "Examples" "nma_compare##examples"}{...}
{viewerjumpto "Stored results" "nma_compare##results"}{...}
{viewerjumpto "Author" "nma_compare##author"}{...}

{title:Title}

{phang}
{bf:nma_compare} {hline 2} League table of all pairwise comparisons


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_compare}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt eform}}exponentiated scale{p_end}
{synopt:{opt dig:its(#)}}decimal places; default is {cmd:2}{p_end}
{synopt:{opt level(#)}}confidence level; default is {cmd:95}{p_end}
{synopt:{opt saving(filename)}}export league table{p_end}
{synopt:{opt for:mat(string)}}export format: excel (default) or csv{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_compare} produces a K x K league table showing estimated treatment
effects for all pairwise comparisons with confidence intervals. Cell (i,j)
shows the effect of treatment i versus treatment j. Indirect-only
comparisons are marked with *.


{marker examples}{...}
{title:Examples}

{pstd}Display league table{p_end}
{phang2}{cmd:. nma_compare}{p_end}

{pstd}Odds ratio scale with export{p_end}
{phang2}{cmd:. nma_compare, eform saving(league_table.xlsx) replace}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(k)}}number of treatments{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(treatments)}}treatment list{p_end}
{synopt:{cmd:r(ref)}}reference treatment{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(effects)}}k x k effect matrix{p_end}
{synopt:{cmd:r(se)}}k x k SE matrix{p_end}
{synopt:{cmd:r(ci_lo)}}k x k lower CI matrix{p_end}
{synopt:{cmd:r(ci_hi)}}k x k upper CI matrix{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}

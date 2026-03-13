{smcl}
{* *! version 1.0.2  13mar2026}{...}
{viewerjumpto "Syntax" "nma_rank##syntax"}{...}
{viewerjumpto "Description" "nma_rank##description"}{...}
{viewerjumpto "Options" "nma_rank##options"}{...}
{viewerjumpto "Examples" "nma_rank##examples"}{...}
{viewerjumpto "Stored results" "nma_rank##results"}{...}
{viewerjumpto "Author" "nma_rank##author"}{...}

{title:Title}

{phang}
{bf:nma_rank} {hline 2} Treatment rankings (SUCRA) for network meta-analysis


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:nma_rank}
[{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt best(string)}}min or max (default); which direction is better{p_end}
{synopt:{opt reps(#)}}Monte Carlo replications; default is {cmd:10000}{p_end}
{synopt:{opt seed(#)}}random number seed{p_end}
{synopt:{opt plot}}draw rankogram{p_end}
{synopt:{opt cumulative}}cumulative rankogram (requires {opt plot}){p_end}
{synopt:{opt scheme(string)}}graph scheme; default is {cmd:white_tableau}{p_end}
{synopt:{opt saving(filename)}}save graph{p_end}
{synopt:{opt replace}}overwrite existing file{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:nma_rank} computes treatment rankings via Monte Carlo simulation from
the joint posterior distribution of treatment effects. It draws {it:reps}
samples from the multivariate normal distribution N(b, V) and ranks
treatments in each draw.

{pstd}
The Surface Under the Cumulative RAnking curve (SUCRA) summarizes each
treatment's overall ranking probability. SUCRA = 100% means the treatment
is always ranked best; SUCRA = 0% means always ranked worst.


{marker options}{...}
{title:Options}

{phang}
{opt best(string)} specifies whether higher ({opt max}) or lower ({opt min})
effect values are better. Default is {opt max} (e.g., for efficacy).
Use {opt min} for outcomes where lower is better (e.g., adverse events).

{phang}
{opt reps(#)} specifies the number of Monte Carlo replications. Default
is 10,000.

{phang}
{opt seed(#)} sets the random number seed for reproducibility.

{phang}
{opt plot} draws a rankogram showing ranking probabilities.

{phang}
{opt cumulative} draws cumulative ranking curves (SUCRA curves) instead
of rank probability bars. Requires {opt plot}.


{marker examples}{...}
{title:Examples}

{pstd}Basic SUCRA table{p_end}
{phang2}{cmd:. nma_rank}{p_end}

{pstd}With cumulative rankogram{p_end}
{phang2}{cmd:. nma_rank, plot cumulative seed(12345)}{p_end}

{pstd}Lower is better (adverse events){p_end}
{phang2}{cmd:. nma_rank, best(min)}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(reps)}}number of replications{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(best)}}direction of benefit{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:r(sucra)}}k x 1 SUCRA values{p_end}
{synopt:{cmd:r(meanrank)}}k x 1 mean ranks{p_end}
{synopt:{cmd:r(rankprob)}}k x k rank probability matrix{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P. Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden{break}
timothy.copeland@ki.se
{p_end}

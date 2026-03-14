{smcl}
{* *! version 1.0.0  13mar2026}{...}
{vieweralsosee "qba_misclass" "help qba_misclass"}{...}
{vieweralsosee "qba_selection" "help qba_selection"}{...}
{vieweralsosee "qba_confound" "help qba_confound"}{...}
{vieweralsosee "qba_multi" "help qba_multi"}{...}
{vieweralsosee "qba_plot" "help qba_plot"}{...}
{viewerjumpto "Description" "qba##description"}{...}
{viewerjumpto "Commands" "qba##commands"}{...}
{viewerjumpto "Workflow" "qba##workflow"}{...}
{viewerjumpto "References" "qba##references"}{...}
{viewerjumpto "Author" "qba##author"}{...}
{title:Title}

{p2colset 5 12 14 2}{...}
{p2col:{cmd:qba} {hline 2}}Quantitative Bias Analysis for epidemiologic data{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:qba} is a suite of commands for quantitative bias analysis (QBA) in
epidemiologic studies. It implements simple and probabilistic bias analysis
for three major sources of systematic error:

{phang2}1. Misclassification of exposure or outcome{p_end}
{phang2}2. Selection bias{p_end}
{phang2}3. Unmeasured confounding{p_end}

{pstd}
All commands support both {bf:simple} (fixed parameter) and {bf:probabilistic}
(Monte Carlo simulation) modes. The multi-bias command chains corrections
in a single simulation framework.

{pstd}
Methods are based on {it:Applying Quantitative Bias Analysis to Epidemiologic}
{it:Data} (Lash, Fox, Fink; 2nd ed, Springer 2021).


{marker commands}{...}
{title:Commands}

{synoptset 22 tabbed}{...}
{synopt:{helpb qba_misclass}}misclassification bias analysis{p_end}
{synopt:{helpb qba_selection}}selection bias analysis{p_end}
{synopt:{helpb qba_confound}}unmeasured confounding analysis{p_end}
{synopt:{helpb qba_multi}}multi-bias analysis{p_end}
{synopt:{helpb qba_plot}}visualization (tornado, distribution, tipping){p_end}


{marker workflow}{...}
{title:Typical workflow}

{pstd}
{bf:Step 1: Single-bias analysis}

{pstd}
Start with individual bias analyses to understand each source of error:

{phang2}{cmd:. qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95)}{p_end}
{phang2}{cmd:. qba_selection, a(100) b(200) c(50) d(300) sela(.9) selb(.85) selc(.7) seld(.8)}{p_end}
{phang2}{cmd:. qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) evalue}{p_end}

{pstd}
{bf:Step 2: Probabilistic analysis}

{pstd}
Add uncertainty by specifying distributions for bias parameters:

{phang2}{cmd:. qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95)} ///
{phang3}{cmd:reps(10000) dist_se("trapezoidal .75 .82 .88 .95") dist_sp("trapezoidal .90 .93 .97 1.0")} ///
{phang3}{cmd:saving(mc_misclass, replace)}{p_end}

{pstd}
{bf:Step 3: Multi-bias analysis}

{pstd}
Combine all three biases in one simulation:

{phang2}{cmd:. qba_multi, a(100) b(200) c(50) d(300) reps(10000)} ///
{phang3}{cmd:seca(.85) spca(.95) dist_se("trapezoidal .75 .82 .88 .95")} ///
{phang3}{cmd:sela(.9) selb(.85) selc(.7) seld(.8)} ///
{phang3}{cmd:p1(.4) p0(.2) rrcd(2.0)}{p_end}

{pstd}
{bf:Step 4: Visualize}

{phang2}{cmd:. qba_plot, distribution using(mc_misclass) observed(1.5) scheme(plotplainblind)}{p_end}
{phang2}{cmd:. qba_plot, tornado a(100) b(200) c(50) d(300) param1(se) range1(.7 1) param2(sp) range2(.8 1)}{p_end}

{pstd}
{bf:Distributions} for probabilistic analysis:

{p2colset 9 35 37 2}{...}
{p2col:{cmd:trapezoidal} {it:min m1 m2 max}}trapezoidal (recommended){p_end}
{p2col:{cmd:triangular} {it:min mode max}}triangular{p_end}
{p2col:{cmd:uniform} {it:min max}}uniform{p_end}
{p2col:{cmd:beta} {it:a b}}Beta distribution{p_end}
{p2col:{cmd:logit-normal} {it:mean sd}}logit-normal{p_end}
{p2col:{cmd:constant} {it:value}}fixed value{p_end}


{marker references}{...}
{title:References}

{phang}
Lash TL, Fox MP, Fink AK. {it:Applying Quantitative Bias Analysis to}
{it:Epidemiologic Data}. 2nd ed. New York: Springer; 2021.

{phang}
VanderWeele TJ, Ding P. Sensitivity analysis in observational research:
introducing the E-value. {it:Ann Intern Med}. 2017;167(4):268-274.

{phang}
Schneeweiss S. Sensitivity analysis and external adjustment for unmeasured
confounders in epidemiologic database studies of therapeutics.
{it:Pharmacoepidemiol Drug Saf}. 2006;15(5):291-303.

{phang}
Fox MP, Lash TL, Greenland S. A method to automate probabilistic
sensitivity analyses of misclassified binary variables.
{it:Int J Epidemiol}. 2005;34(6):1370-1376.

{phang}
Greenland S. Basic methods for sensitivity analysis of biases.
{it:Int J Epidemiol}. 1996;25(6):1107-1116.


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Version 1.0.0, 2026-03-13{p_end}

{hline}

{smcl}
{* *! version 1.0.2  05dec2025}{...}
{viewerjumpto "Syntax" "stratetab##syntax"}{...}
{viewerjumpto "Description" "stratetab##description"}{...}
{viewerjumpto "Options" "stratetab##options"}{...}
{viewerjumpto "Examples" "stratetab##examples"}{...}
{viewerjumpto "Remarks" "stratetab##remarks"}{...}
{viewerjumpto "Author" "stratetab##author"}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:stratetab} {hline 2}}Combine strate output files and export to Excel with outcomes as columns{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stratetab}{cmd:,} {opt using(namelist)} {opt xlsx(string)} {opt outcomes(integer)} [{opt sheet(string)} {opt title(string)} {opt outlabels(string)} {opt explabels(string)} {opt digits(integer 1)} {opt eventdigits(integer 0)} {opt pydigits(integer 0)} {opt unitlabel(string)} {opt pyscale(real 1)} {opt ratescale(real 1000)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:stratetab} combines pre-computed {helpb strate} output files and exports them to Excel with outcomes as column groups and exposure variables as rows. Each outcome spans three columns: Events, Person-Years, and Rate (95% CI).

{pstd}
The command reads multiple .dta files produced by {helpb strate}, organized by exposure type. Files should be listed in order: all outcomes for exposure 1, then all outcomes for exposure 2, etc. For example, with 3 outcomes and 2 exposure types: {it:out1_exp1 out2_exp1 out3_exp1 out1_exp2 out2_exp2 out3_exp2}.

{pstd}
{cmd:stratetab} cannot be combined with {cmd:by:}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt using(namelist)} specifies the list of strate output files to combine. File names should be space-separated without the .dta extension. Files must be ordered: all outcomes for exposure 1, all outcomes for exposure 2, etc.

{phang}
{opt xlsx(string)} specifies the Excel output file name. Must include the .xlsx extension.

{phang}
{opt outcomes(integer)} specifies the number of distinct outcomes. The total number of files must be divisible by this number.

{dlgtab:Optional}

{phang}
{opt sheet(string)} specifies the Excel sheet name. Default is {bf:Results}.

{phang}
{opt title(string)} specifies title text that appears in row 1 of the output table.

{phang}
{opt outlabels(string)} specifies outcome labels separated by backslash ({bf:\}). The number of labels must match {opt outcomes()}. If not specified, outcomes are labeled as "Outcome 1", "Outcome 2", etc.

{phang}
{opt explabels(string)} specifies exposure group labels separated by backslash ({bf:\}). The number of labels must match the number of exposure groups (total files / outcomes). If not specified, exposures are labeled as "Exposure 1", "Exposure 2", etc.

{phang}
{opt digits(integer 1)} specifies the number of decimal places for rates and confidence intervals. Must be between 0 and 10. Default is 1.

{phang}
{opt eventdigits(integer 0)} specifies the number of decimal places for event counts. Must be between 0 and 10. Default is 0.

{phang}
{opt pydigits(integer 0)} specifies the number of decimal places for person-years. Must be between 0 and 10. Default is 0.

{phang}
{opt unitlabel(string)} specifies the unit label for the rate column header. Default is "1,000", producing "Per 1,000 PY (95% CI)".

{phang}
{opt pyscale(real 1)} divides person-years values by the specified factor. Default is 1 (no scaling).

{phang}
{opt ratescale(real 1000)} multiplies rate and confidence interval values by the specified factor. Default is 1000, displaying rates per 1000 person-years. Use when strate was run with {cmd:per(1)}.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Three outcomes, one exposure type}

{pstd}
Combine strate output for EDSS 4, EDSS 6, and Relapse outcomes by HRT exposure:

{phang2}{cmd:. stratetab, using(edss4_tv edss6_tv relapse_tv) ///}{p_end}
{phang2}{cmd:  xlsx(results.xlsx) outcomes(3) ///}{p_end}
{phang2}{cmd:  outlabels(Sustained EDSS 4 \ Sustained EDSS 6 \ First Relapse) ///}{p_end}
{phang2}{cmd:  explabels(Time-Varying HRT)}{p_end}

{pstd}
{bf:Example 2: Three outcomes, four exposure types (as in the HRT analysis)}

{pstd}
Full table with multiple exposure definitions:

{phang2}{cmd:. stratetab, using(edss4_tv edss6_tv relapse_tv ///}{p_end}
{phang2}{cmd:    edss4_dur edss6_dur relapse_dur ///}{p_end}
{phang2}{cmd:    edss4_dur1 edss6_dur1 relapse_dur1 ///}{p_end}
{phang2}{cmd:    edss4_dur2 edss6_dur2 relapse_dur2) ///}{p_end}
{phang2}{cmd:  xlsx(table2.xlsx) outcomes(3) sheet(Table 2) ///}{p_end}
{phang2}{cmd:  title(Table 2. Unadjusted rates of MS outcomes by HRT exposure) ///}{p_end}
{phang2}{cmd:  outlabels(Sustained EDSS 4 \ Sustained EDSS 6 \ First Relapse) ///}{p_end}
{phang2}{cmd:  explabels(Time-Varying HRT \ HRT Duration \ Estrogen Duration \ Combined Duration)}{p_end}

{pstd}
{bf:Example 3: Custom scaling}

{pstd}
Display rates per 100 person-years with person-years in 1000s:

{phang2}{cmd:. stratetab, using(out1_exp1 out2_exp1 out1_exp2 out2_exp2) ///}{p_end}
{phang2}{cmd:  xlsx(results.xlsx) outcomes(2) ///}{p_end}
{phang2}{cmd:  ratescale(100) unitlabel(100) pyscale(1000)}{p_end}

{pstd}
{bf:Example 4: Two decimal places for rates}

{phang2}{cmd:. stratetab, using(edss4_tv edss6_tv relapse_tv) ///}{p_end}
{phang2}{cmd:  xlsx(results.xlsx) outcomes(3) ///}{p_end}
{phang2}{cmd:  outlabels(EDSS 4 \ EDSS 6 \ Relapse) ///}{p_end}
{phang2}{cmd:  explabels(Time-Varying HRT) digits(2)}{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:File ordering}

{pstd}
Files must be listed with all outcomes for exposure 1 first, then all outcomes for exposure 2, etc. 
The order of outcomes within each exposure group determines the column order in the output.

{pstd}
For example, with 3 outcomes (O1, O2, O3) and 2 exposures (E1, E2), list files as:

{phang2}O1_E1 O2_E1 O3_E1 O1_E2 O2_E2 O3_E2{p_end}

{pstd}
{bf:Label validation}

{pstd}
If {opt outlabels()} is specified, the number of labels must exactly match {opt outcomes()}.
If {opt explabels()} is specified, the number of labels must match the number of exposure groups
(total files / outcomes).


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.2 - 2025-12-05{p_end}


{title:Also see}

{psee}
Online:  {helpb strate}

{hline}

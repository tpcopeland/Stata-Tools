{smcl}
{* *! version 1.0.2  12apr2026}{...}
{viewerjumpto "Syntax" "stratetab##syntax"}{...}
{viewerjumpto "Description" "stratetab##description"}{...}
{viewerjumpto "Options" "stratetab##options"}{...}
{viewerjumpto "Examples" "stratetab##examples"}{...}
{viewerjumpto "Remarks" "stratetab##remarks"}{...}
{viewerjumpto "Author" "stratetab##author"}{...}
{viewerjumpto "Stored results" "stratetab##results"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{vieweralsosee "strate" "help strate"}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:stratetab} {hline 2}}Combine strate output files and export to Excel with outcomes as columns{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stratetab}{cmd:,} {opt using(string asis)} {opt xlsx(string)} {opt outcomes(integer)} [{opt sheet(string)} {opt title(string)} {opt outlabels(string)} {opt explabels(string)} {opt digits(integer 1)} {opt eventdigits(integer 0)} {opt pydigits(integer 0)} {opt unitlabel(string)} {opt pyscale(real 1)} {opt ratescale(real 1000)} {opt rateratio} {opt ratio:digits(#)} {opt foot:note(string)} {opt open} {opt zebra} {opt borders:tyle(string)} {opt the:me(string)} {opt headers:hade} {opt headerc:olor(string)} {opt zebrac:olor(string)} {opt csv(string)}]


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
{opt xlsx(string)} specifies the Excel output file name. Must include the .xlsx extension. {opt excel()} is accepted as a synonym.

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

{phang2}{opt rateratio} adds an incidence rate ratio (IRR) column per outcome. Reference group is the first exposure group (displays "Ref."). 95% CI computed via log-normal method.{p_end}

{phang2}{opt ratio:digits(#)} decimal places for rate ratios (default 2).{p_end}

{phang2}{opt foot:note(string)} adds a footnote row below the table in smaller italic font.{p_end}

{phang2}{opt open} opens the Excel file in the default application after export.{p_end}

{phang2}{opt zebra} applies alternating light gray row shading for readability.{p_end}

{phang2}{opt borders:tyle(string)} specifies the border style: {cmd:thin} (default), {cmd:medium}, or {cmd:academic}.{p_end}

{phang2}{opt the:me(string)} applies a journal-style formatting theme: {cmd:lancet}, {cmd:nejm}, {cmd:bmj}, {cmd:apa}, {cmd:jama}, {cmd:plos}, {cmd:nature}, {cmd:cell}, {cmd:annals}, or {cmd:custom}.{p_end}

{phang2}{opt headers:hade} applies a background fill to the header rows.{p_end}

{phang2}{opt headerc:olor(string)} specifies a custom RGB header color (e.g., "200 220 240").{p_end}

{phang2}{opt zebrac:olor(string)} specifies a custom RGB zebra stripe color (e.g., "245 245 255").{p_end}

{phang2}{opt csv(string)} exports the table data as a CSV file in addition to the Excel output.{p_end}


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Two outcomes by antidepressant class}

{pstd}
Combine strate output for cardiovascular events and self-harm by SSRI/SNRI exposure:

{phang2}{stata `"stratetab, using(rate_ssri rate_snri) xlsx(rates.xlsx) outcomes(2) outlabels(CV Event \ Self-Harm) title("Incidence Rates per 1,000 Person-Years")"':. stratetab, using(rate_ssri rate_snri) ///}{p_end}
{phang3}{cmd:xlsx(rates.xlsx) outcomes(2) ///}{p_end}
{phang3}{cmd:outlabels(CV Event \ Self-Harm) ///}{p_end}
{phang3}{cmd:title("Incidence Rates per 1,000 Person-Years")}{p_end}

{pstd}
{bf:Example 2: Multiple exposure definitions}

{pstd}
Full table comparing time-varying and cumulative dose exposures:

{phang2}{cmd:. stratetab, using(cv_tv selfharm_tv ///}{p_end}
{phang3}{cmd:cv_dose selfharm_dose) ///}{p_end}
{phang3}{cmd:xlsx(rates.xlsx) outcomes(2) sheet(Rates) ///}{p_end}
{phang3}{cmd:title(Table 2. Unadjusted rates by antidepressant exposure) ///}{p_end}
{phang3}{cmd:outlabels(CV Event \ Self-Harm) ///}{p_end}
{phang3}{cmd:explabels(Time-Varying Class \ Cumulative Dose)}{p_end}

{pstd}
{bf:Example 3: Custom scaling}

{pstd}
Display rates per 100 person-years with person-years in 1000s:

{phang2}{stata "stratetab, using(rate_ssri rate_snri) xlsx(rates.xlsx) outcomes(2) ratescale(100) unitlabel(100) pyscale(1000)":. stratetab, using(rate_ssri rate_snri) ///}{p_end}
{phang3}{cmd:xlsx(rates.xlsx) outcomes(2) ///}{p_end}
{phang3}{cmd:ratescale(100) unitlabel(100) pyscale(1000)}{p_end}

{pstd}
{bf:Example 4: Two decimal places for rates}

{phang2}{stata "stratetab, using(rate_ssri rate_snri) xlsx(rates.xlsx) outcomes(2) outlabels(CV Event \ Self-Harm) digits(2)":. stratetab, using(rate_ssri rate_snri) ///}{p_end}
{phang3}{cmd:xlsx(rates.xlsx) outcomes(2) ///}{p_end}
{phang3}{cmd:outlabels(CV Event \ Self-Harm) digits(2)}{p_end}


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:File ordering}

{pstd}
Files must be listed with all outcomes for exposure 1 first, then all outcomes for exposure 2, etc. 
The order of outcomes within each exposure group determines the column order in the output.

{pstd}
Within each exposure group, all outcome files must have the same category labels. {cmd:stratetab}
aligns later outcomes to the category labels from the first outcome file for that exposure and
rejects files with missing, duplicated, or unmatched category labels.

{pstd}
When {opt rateratio} is specified, categories in exposures 2, 3, ... are matched to exposure 1
by category label before IRRs are computed. If the category sets do not match uniquely, the
command exits with an error rather than comparing rows by position.

{pstd}
For example, with 3 outcomes (O1, O2, O3) and 2 exposures (E1, E2), list files as:

{phang2}O1_E1 O2_E1 O3_E1 O1_E2 O2_E2 O3_E2{p_end}

{pstd}
{bf:Label validation}

{pstd}
If {opt outlabels()} is specified, the number of labels must exactly match {opt outcomes()}.
If {opt explabels()} is specified, the number of labels must match the number of exposure groups
(total files / outcomes).


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:stratetab} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}number of rows in the output table{p_end}
{synopt:{cmd:r(N_exposures)}}number of exposure groups{p_end}
{synopt:{cmd:r(N_outcomes)}}number of outcomes{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt:{cmd:r(rates)}}incidence rates matrix (rows=exposure levels, cols=outcomes){p_end}
{synopt:{cmd:r(ratios)}}incidence rate ratio matrix (rows=exposure levels, cols=outcomes; when {cmd:rateratio} specified){p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(xlsx)}}Excel filename{p_end}
{synopt:{cmd:r(sheet)}}sheet name{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P Copeland{p_end}
{pstd}Department of Clinical Neuroscience, Karolinska Institutet{p_end}
{pstd}timothy.copeland@ki.se{p_end}
{pstd}Version 1.0.2{p_end}

{title:Also see}

{psee}
Online:  {helpb strate}

{hline}

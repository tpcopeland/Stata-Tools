{smcl}
{* *! version 1.0.0  17nov2025}{...}
{viewerjumpto "Syntax" "stratetab##syntax"}{...}
{viewerjumpto "Description" "stratetab##description"}{...}
{viewerjumpto "Options" "stratetab##options"}{...}
{viewerjumpto "Examples" "stratetab##examples"}{...}
{viewerjumpto "Author" "stratetab##author"}{...}
{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{cmd:stratetab} {hline 2}}Combine strate output files and export to Excel{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:stratetab}{cmd:,} {opt using(namelist)} {opt xlsx(string)} [{opt sheet(string)} {opt title(string)} {opt labels(string)} {opt digits(integer 1)} {opt eventdigits(integer 0)} {opt pydigits(integer 0)} {opt unitlabel(string)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:stratetab} combines pre-computed {helpb strate} output files and exports them to Excel with outcome labels as headers and category labels indented in the first column. The command creates a formatted table with events, person-years, and rates with 95% confidence intervals.

{pstd}
The command reads multiple .dta files produced by {helpb strate}, extracts the categorical variable and rate statistics from each file, and arranges them in a single Excel table with customizable formatting. Each outcome appears as a header row followed by indented category rows showing the corresponding statistics.

{pstd}
{cmd:stratetab} cannot be combined with {cmd:by:}.


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt using(namelist)} specifies the list of strate output files to combine. File names should be space-separated without the .dta extension, which is added automatically. For example, {cmd:using(strate_edss4 strate_edss6 strate_relapse)}.

{phang}
{opt xlsx(string)} specifies the Excel output file name. Must include the .xlsx extension.

{dlgtab:Optional}

{phang}
{opt sheet(string)} specifies the Excel sheet name. Default is {bf:Results}.

{phang}
{opt title(string)} specifies title text that appears in row 1 of the output table.

{phang}
{opt labels(string)} specifies outcome labels separated by backslash ({bf:\}). The number of labels must match the number of files in {opt using()}. If not specified, outcomes are labeled as "Outcome 1", "Outcome 2", etc. Spaces around the backslash separator are trimmed automatically. For example, {cmd:labels(EDSS Progression \ EDSS 6 \ Relapse)}.

{phang}
{opt digits(integer 1)} specifies the number of decimal places for rates and confidence intervals. Must be between 0 and 10. Default is 1.

{phang}
{opt eventdigits(integer 0)} specifies the number of decimal places for event counts. Must be between 0 and 10. Default is 0.

{phang}
{opt pydigits(integer 0)} specifies the number of decimal places for person-years. Must be between 0 and 10. Default is 0.

{phang}
{opt unitlabel(string)} adds unit labels to the person-years and rate columns. For example, {cmd:unitlabel(1000)} produces column headers "Person-years (1000's)" and "Rate per 1000 person-years (95% CI)".


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Basic usage with three outcomes}

{pstd}
Combine three strate output files and export to Excel:

{phang2}{cmd:. stratetab, using(strate_edss4 strate_edss6 strate_relapse) xlsx(results.xlsx)}{p_end}

{pstd}
This creates results.xlsx with three outcomes labeled "Outcome 1", "Outcome 2", and "Outcome 3" in a sheet named "Results".

{pstd}
{bf:Example 2: Custom labels and title}

{pstd}
Add custom outcome labels and a table title:

{phang2}{cmd:. stratetab, using(strate_edss4 strate_edss6 strate_relapse) ///}{p_end}
{phang2}{cmd:  xlsx(results.xlsx) ///}{p_end}
{phang2}{cmd:  labels(EDSS Progression \ EDSS 6 \ Relapse) ///}{p_end}
{phang2}{cmd:  title(Unadjusted Event Rates)}{p_end}

{pstd}
The table now displays "EDSS Progression", "EDSS 6", and "Relapse" as outcome headers with "Unadjusted Event Rates" in row 1.

{pstd}
{bf:Example 3: Custom decimal places}

{pstd}
Specify 2 decimal places for rates and 1 for person-years:

{phang2}{cmd:. stratetab, using(strate_edss4 strate_edss6) ///}{p_end}
{phang2}{cmd:  xlsx(results.xlsx) ///}{p_end}
{phang2}{cmd:  labels(EDSS 4 \ EDSS 6) ///}{p_end}
{phang2}{cmd:  digits(2) pydigits(1)}{p_end}

{pstd}
Rates and confidence intervals display with 2 decimal places, person-years with 1 decimal place, and events with 0 decimal places (default).

{pstd}
{bf:Example 4: Custom sheet name and unit label}

{pstd}
Create output in a sheet named "Analysis1" with rates per 1000 person-years:

{phang2}{cmd:. stratetab, using(strate_outcome1 strate_outcome2) ///}{p_end}
{phang2}{cmd:  xlsx(results.xlsx) ///}{p_end}
{phang2}{cmd:  sheet(Analysis1) ///}{p_end}
{phang2}{cmd:  unitlabel(1000)}{p_end}

{pstd}
The output appears in the "Analysis1" sheet with column headers "Person-years (1000's)" and "Rate per 1000 person-years (95% CI)".

{pstd}
{bf:Example 5: Single outcome with formatting}

{pstd}
Export a single outcome with custom formatting:

{phang2}{cmd:. stratetab, using(strate_mortality) ///}{p_end}
{phang2}{cmd:  xlsx(mortality_table.xlsx) ///}{p_end}
{phang2}{cmd:  labels(All-cause Mortality) ///}{p_end}
{phang2}{cmd:  title(Mortality Rates by Age Group) ///}{p_end}
{phang2}{cmd:  digits(1) eventdigits(0) pydigits(0)}{p_end}

{pstd}
A single outcome table is created showing mortality rates with standard decimal formatting.

{pstd}
{bf:Example 6: Multiple outcomes with consistent formatting}

{pstd}
Create a comprehensive table with four outcomes:

{phang2}{cmd:. stratetab, using(strate_mi strate_stroke strate_death strate_composite) ///}{p_end}
{phang2}{cmd:  xlsx(cv_outcomes.xlsx) ///}{p_end}
{phang2}{cmd:  labels(Myocardial Infarction \ Stroke \ Death \ Composite Outcome) ///}{p_end}
{phang2}{cmd:  title(Cardiovascular Outcomes by Treatment Group) ///}{p_end}
{phang2}{cmd:  sheet(CVD_Analysis) ///}{p_end}
{phang2}{cmd:  digits(2) unitlabel(100)}{p_end}

{pstd}
This creates a comprehensive cardiovascular outcomes table with rates per 100 person-years.


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}
{pstd}Email: timothy.copeland@ki.se{p_end}

{pstd}Version 2.1 - 23 October 2025{p_end}


{title:Also see}

{psee}
Online:  {helpb strate}

{hline}

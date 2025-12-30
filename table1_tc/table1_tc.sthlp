{smcl}
{* *! version 1.0.3  05dec2025}{...}
{hline}
help for {cmd:table1_tc}
{hline}

{title:Title}

{p2colset 5 15 21 2}{...}
{p2col: {bf:table1_tc}}{hline 2} Create "Table 1" of baseline characteristics for a manuscript

{title:Syntax}

{p 8 18 2}
{opt table1_tc} {ifin} {weight}, {opt vars(var_spec)} [{it:options}]

{phang}{it:var_spec} = {it: varname vartype} [{it:{help fmt:%fmt1}} [{it:{help fmt:%fmt2}}]] [ \ {it:varname vartype} [{it:{help fmt:%fmt1}} [{it:{help fmt:%fmt2}}]] \ ...]

{phang}where {it: vartype} is one of:{p_end}
{tab}contn  - continuous, normally distributed  (mean and SD will be reported)
{tab}contln - continuous, log normally distributed (geometric mean and GSD reported)
{tab}conts  - continuous, neither log normally or normally distributed (median, Q1 and Q3 reported)
{tab}cat    - categorical, groups compared using Pearson's chi-square test
{tab}cate   - categorical, groups compared using Fisher's exact test
{tab}bin    - binary (0/1), groups compared using Pearson's chi-square test
{tab}bine   - binary (0/1), groups compared using Fisher's exact test

{phang}{opt fweight}s are allowed; see {help weight}


{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Columns/Rows}
{synopt:{opt by(varname)}}group observations by {it:varname}, which must be either (i) string, or (ii) numeric and contain only non-negative integers, whether or not a value label is attached{p_end}
{synopt:{opt total(before|after)}}include a total column before/after presenting by group{p_end}
{synopt:{opt one:col}}report categorical variable levels underneath variable name instead of in separate column{p_end}
{synopt:{opt mis:sing}}for categorical variables (cat and cate) treat missing values as another category{p_end}
{synopt:{opt test}}include column describing the significance test used{p_end}
{synopt:{opt stat:istic}}include column describing the value of the test statistic{p_end}
{synopt:{opt pairwise123}}report pairwise comparisons (unadjusted for multiple comparisons) between first 3 groups{p_end}
{synopt:{opt headerperc}}add percentage of total to sample size row{p_end}

{syntab:Contents of Cells}
{synopt:{cmdab:f:ormat(}{it:{help fmt:%fmt}}{cmd:)}}default display format for continuous variables{p_end}
{synopt:{cmdab:percf:ormat(}{it:{help fmt:%fmt}}{cmd:)}}default display format for percentages for categorical/binary variables{p_end}
{synopt:{cmdab:nf:ormat(}{it:{help fmt:%fmt}}{cmd:)}}display format for n and N; default is nformat(%12.0fc){p_end}
{synopt:{opt varlabplus}}adds ", median (IQR)" ", mean (SD)" ", No. (%)" etc. after variable label; default is to explain all this in one footnote{p_end}
{synopt:{opt iqrmiddle("string")}}allows for e.g. median (Q1, Q3) using iqrmiddle(", ") rather than median (Q1-Q3){p_end}
{synopt:{opt sdleft("string")}}allows for e.g. mean±sd using sdleft("±") rather than mean (SD){p_end}
{synopt:{opt sdright("string")}}allows for e.g. mean±sd using sdright("") rather than mean (SD){p_end}
{synopt:{opt gsdleft("string")}}allows for presentation other than: geometric_mean (×/geometric_SD){p_end}
{synopt:{opt gsdright("string")}}allows for presentation other than: geometric_mean (×/geometric_SD){p_end}
{synopt:{opt percsign("string")}}default is percsign("%"); consider percsign(""){p_end}
{synopt:{opt nospace:lowpercent}}report e.g. (3%) instead of the default ( 3%), [the default can look nice if output is right/left justified]{p_end}
{synopt:{opt extraspace}}helps alignment of p-values and ( 3%) in .docx file if non-monospaced datafont (e.g. Calibri - the default) used{p_end}
{synopt:{opt percent}}report % rather than n (%) for categorical/binary vars{p_end}
{synopt:{opt percent_n}}report % (n) rather than n (%) for categorical/binary vars{p_end}
{synopt:{opt slashN}}report n/N instead of n for categorical/binary vars {p_end}
{synopt:{opt catrowperc}}report row percentages rather than column percentages for categorical vars (but not binary vars) {p_end}
{synopt:{opt pdp(#)}}max number of decimal places in p-value when p-value < 0.10; default is pdp(3){p_end}
{synopt:{opt highpdp(#)}}max number of decimal places in p-value when p-value ≥ 0.10; default is highpdp(2){p_end}
{synopt:{opt gurmeet}}equivalent to specifying:  percformat(%5.1f) percent_n percsign("") iqrmiddle(",") sdleft(" [±") sdright("]") gsdleft(" [×/") gsdright("]") onecol extraspace{p_end}

{syntab:Excel Output}
{synopt:{opt excel("filename")}}save table to Excel file (requires sheet and title options), e.g., excel("file.xlsx") {p_end}
{synopt:{opt sheet("string")}}name of Excel sheet for output, e.g., sheet("Table 1") {p_end}
{synopt:{opt title("string")}}title for the Excel table, e.g., title("Table 1. Patient Characteristics"){p_end}
{synopt:{opt borders:tyle(default|thin)}}Excel border style; default creates mixed borders, thin creates uniform thin borders{p_end}

{syntab:Other Output}
{synopt:{opt clear}}replace the dataset in memory with the table{p_end}


{title:Description}

{pstd}
{opt table1_tc} generates a "Table 1" of characteristics for a manuscript. Such a table generally
includes a collection of baseline characteristics which may be either continuous or categorical. The
observations are often grouped, with a "p-value" column on the right comparing the characteristics
between groups.{p_end}

{pstd}This command is a fork of {cmd:table1_mc} version 3.5 (2024-12-19) by Mark Chatfield, with the following enhancements:{p_end}
{pstd}- Direct Excel export with automatic column width calculation{p_end}
{pstd}- Improved header row with description of data presentation{p_end}
{pstd}- Option to show percentage of total in the header row{p_end}
{pstd}- Customizable border styles for Excel output{p_end}
{pstd}- Enhanced formatting and alignment options{p_end}
{pstd}- Data presentation descriptions in upper left cell of excel tableTo save a resulting table directly to Excel{p_end}

{pstd}The {bf:vars} option is required and contains a list of the variable(s) to be included as
rows in the table. Each variable must also have a type specified ({it:contn}, {it:contln}, {it:conts}, {it:cat},
{it:cate}, {it:bin} or {it:bine} - see above). If the observations are grouped using {bf:by()}, a
significance test is performed to compare each characteristic between groups. {it:contln} and {it:contn} variables
are compared using ANOVA (with and without log transformation of positive values respectively) 
[equivalent to an independent t-test when 2 groups],
{it:conts} variables are compared using the Wilcoxon rank-sum (2 groups)
or Kruskal-Wallis (>2 groups) test (adjusted for ties), {it:cat} and {it:bin} variables are compared using Pearson's
chi-square test, and {it:cate} and {it:bine} variables are compared using Fisher's exact test.
Specifying the {bf:test} option adds a column to the table describing the test used.
And specifying the {bf:statistic} option adds a column to the table describing the value of the test statistic.
{bf:pairwise123} reports p-values from applying those same tests between 2 groups.{p_end}

{pstd}The display format of each variable in the table depends on the variable type. For a continuous
variable the default display format is the same as that variable's current display format. You can
change the table's default display format of summary statistics for continuous variables using the {bf:format()} option.
After each variable's type you may
optionally specify a display format to override the table's default by specifying {it:{help fmt:%fmt1}}.
Specification of {it:{help fmt:%fmt2}} also, will affect the display format of Q1,Q3/SD/geometric SD.
For categorical/binary variables the default is to
display the column percentage using either 0 or 1 decimal place depending on the total frequency. You
can change this default using the {bf:percformat()} option.{p_end}

{pstd}The default times-divide symbol for the geometric SD (Kirkwood 1979) 
is very similar to that proposed by Limpert & Stahel (2011).{p_end}

{pstd}Unlike the original {cmd:table1_mc}, this fork provides built-in Excel export functionality through the 
{bf:excel()}, {bf:sheet()}, and {bf:title()} options. The command automatically calculates appropriate 
column widths based on content and applies professional formatting with customizable border styles. 
The resulting Excel file can be used directly in reports or presentations without requiring further 
formatting.{p_end}

{pstd}The underlying results table can also be kept in memory, replacing the original dataset, using the 
{bf:clear} option.{p_end}


{title:Remarks}

{pstd}Stata's {help dtable:dtable} command, introduced in version 18, can do a lot of what {cmd:table1_tc} can do, and more. 
[If using {cmd:dtable}, the {help tables_intro:collect} suite of commands can help to report 
binary variables on one row, provide finer control of decimal places, and other things.]{p_end}

{pstd}While {cmd:table1_tc} does not report an effect size (e.g. differences in means, medians or proportions) & associated 95% CI for a variable when there are 2 (or more) groups, users might consider calculating and reporting these also.{p_end}

{pstd}{cmd:table1_tc} is a fork of {cmd:table1_mc} by Mark Chatfield, which itself is an extension and modification of Phil Clayton's {cmd:table1} command.{p_end}


{title:Examples}

{phang}{sf:. } sysuse auto, clear {p_end}
{phang}{sf:. } generate much_headroom = (headroom>=3) {p_end}

{pstd}{bf: To save a resulting table directly to Excel and add group percentages in the header row}{break}{break}
{sf:. } table1_tc, by(foreign) vars(weight contn \ price contln \ mpg conts \ rep78 cate \ much_headroom bin) onecol total(before) headerperc excel("Auto Tables.xlsx") sheet("Table 1") title("Table 1: Characteristics by Foreign") {break}

{title:References}

{phang}Kirkwood TBL. Geometric means and measures of dispersion. Biometrics 1979; 35: 908–909.{p_end} 
{phang}Limpert E, Stahel WA. Problems with Using the Normal Distribution – and Ways to Improve Quality and Efficiency of Data Analysis. PLoS ONE. 2011;6(7):e21403. doi:10.1371/journal.pone.0021403.{p_end} 
{phang}table1_mc - Mark Chatfield, The University of Queensland, Australia.{p_end}{break}
{phang}table1 - Phil Clayton, ANZDATA Registry, Australia.{p_end}


{marker author}{...}
{title:Author}

{pstd}Timothy P. Copeland{p_end}
{pstd}Department of Clinical Neuroscience{p_end}
{pstd}Karolinska Institutet{p_end}

{pstd}Version 1.0.0 - 2025-12-02{p_end}
{pstd}Fork of table1_mc by Mark Chatfield, The University of Queensland, Australia{p_end}
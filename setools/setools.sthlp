{smcl}
{* *! version 1.0.1  22apr2026}{...}
{viewerjumpto "Description" "setools##description"}{...}
{viewerjumpto "Commands" "setools##commands"}{...}
{viewerjumpto "Installation" "setools##installation"}{...}
{viewerjumpto "Author" "setools##author"}{...}
{title:Title}

{p2colset 5 16 18 2}{...}
{p2col:{cmd:setools} {hline 2}}Swedish Registry Toolkit for Epidemiological Cohort Studies{p_end}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
{cmd:setools} provides utilities for working with Swedish health registries and
conducting epidemiological cohort studies. The package includes tools for
procedure code matching, comorbidity scoring, migration processing,
and MS disability progression endpoints (EDSS, CDP, PIRA).


{marker commands}{...}
{title:Commands}

{pstd}
{bf:Registry Code Utilities}

{synoptset 16}{...}
{synopt:{helpb procmatch}}Procedure code matching for Swedish registry research{p_end}
{synopt:{helpb cci_se}}Swedish Charlson Comorbidity Index (ICD-7 through ICD-10){p_end}

{pstd}
{bf:Migration Registry}

{synopt:{helpb migrations}}Process Swedish migration registry data for cohort studies{p_end}

{pstd}
{bf:MS Disability Progression}

{synopt:{helpb sustainedss}}Compute sustained EDSS progression date{p_end}
{synopt:{helpb cdp}}Confirmed Disability Progression from baseline EDSS{p_end}
{synopt:{helpb pira}}Progression Independent of Relapse Activity{p_end}


{marker installation}{...}
{title:Installation}

{pstd}
To install or update setools:

{phang2}{cmd:. net install setools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/setools") replace}{p_end}


{marker examples}{...}
{title:Examples}

{pstd}Charlson Comorbidity Index from ICD codes{p_end}
{phang2}{cmd:. cci_se, id(lopnr) icd(dia) date(diagdate)}{p_end}

{pstd}Procedure code matching{p_end}
{phang2}{cmd:. procmatch match, codes("AA010 AA020") procvars(op1 op2 op3)}{p_end}

{pstd}Confirmed Disability Progression (MS){p_end}
{phang2}{cmd:. cdp lopnr edss visitdate, dxdate(ms_onset)}{p_end}

{pstd}PIRA detection{p_end}
{phang2}{cmd:. pira lopnr edss visitdate, dxdate(ms_onset) relapses(relapse_data.dta)}{p_end}

{pstd}Process migration registry data{p_end}
{phang2}{cmd:. migrations, migfile(migration_registry.dta)}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland{break}
Department of Clinical Neuroscience{break}
Karolinska Institutet, Stockholm, Sweden
{p_end}

{pstd}
Online: {browse "https://github.com/tpcopeland/Stata-Tools":Stata-Tools on GitHub}{p_end}

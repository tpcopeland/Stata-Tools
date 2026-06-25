{smcl}
{* *! version 1.2.1  25jun2026}{...}
{vieweralsosee "msm" "help msm"}{...}
{vieweralsosee "msm_diagnose" "help msm_diagnose"}{...}
{vieweralsosee "msm_table" "help msm_table"}{...}
{vieweralsosee "msm_weight" "help msm_weight"}{...}
{vieweralsosee "frames" "help frames"}{...}
{viewerjumpto "Syntax" "msm_diagtab##syntax"}{...}
{viewerjumpto "Description" "msm_diagtab##description"}{...}
{viewerjumpto "Options" "msm_diagtab##options"}{...}
{viewerjumpto "Frame schema" "msm_diagtab##schema"}{...}
{viewerjumpto "Examples" "msm_diagtab##examples"}{...}
{viewerjumpto "Author" "msm_diagtab##author"}{...}
{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:msm_diagtab} {hline 2}}Export an accumulated cross-contrast MSM weight-diagnostics frame to Excel{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:msm_diagtab}
{cmd:,}
{opt frame(name)}
{opt xlsx(filename)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{p2coldent:* {opt frame(name)}}frame accumulated by {helpb msm_diagnose} {cmd:accumulate()}{p_end}
{p2coldent:* {opt xlsx(filename)}}Excel output file (must end in {cmd:.xlsx}){p_end}
{synopt:{opt sheet(string)}}sheet name; default is {cmd:Weight Diagnostics}{p_end}
{synopt:{opt tit:le(string)}}title written to cell A1{p_end}
{synopt:{opt foot:note(string)}}merged footnote below the table{p_end}
{synopt:{opt dec:imals(#)}}decimal places for weights and {cmd:max_abs_smd}; default is {cmd:3}{p_end}
{synopt:{opt thr:eshold(#)}}imbalance threshold reported in the default footnote; default is {cmd:0.1}{p_end}
{synopt:{opt f:ont(string)}}font name; default is {cmd:Arial}{p_end}
{synopt:{opt fonts:ize(#)}}font size in points; default is {cmd:10}{p_end}
{synopt:{opt border:style(string)}}border style: {cmd:thin}, {cmd:medium}, or {cmd:academic}; default is {cmd:thin}{p_end}
{synopt:{opt zebra}}alternating row shading (light gray){p_end}
{synopt:{opt open}}auto-open the workbook after export{p_end}
{synopt:{opt replace}}replace the sheet in an existing workbook{p_end}
{synoptline}
{p 4 6 2}* {opt frame()} and {opt xlsx()} are required.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:msm_diagtab} writes a frame of accumulated weight diagnostics -- one row
per contrast -- to a single styled Excel sheet.  It is the cross-contrast
companion to {helpb msm_diagnose}: where {cmd:msm_diagnose, accumulate()}
appends a one-row summary per weighted panel to a frame, {cmd:msm_diagtab}
exports that whole frame at once.

{pstd}
This fills the gap that {helpb msm_table} does not: {cmd:msm_table} writes one
panel's detailed balance and weight tables to fixed sheets, so calling it inside
a contrast loop overwrites the previous panel.  {cmd:msm_diagtab} instead
renders an already-accumulated, multi-row summary frame as a single table, with
one line per contrast.

{pstd}
The command reads the frame; it does not require any pipeline state and does not
alter the data in memory.  It errors cleanly if the named frame does not exist
or has no rows.


{marker options}{...}
{title:Options}

{phang}
{opt frame(name)} specifies the frame to export.  This is normally a frame built
by repeated calls to {cmd:msm_diagnose, accumulate(}{it:name}{cmd:)}.  The frame
must already exist and contain at least one row.

{phang}
{opt xlsx(filename)} specifies the Excel output file.  The file name must end in
{cmd:.xlsx}.

{phang}
{opt sheet(string)} sets the worksheet name.  The default is
{cmd:Weight Diagnostics}.

{phang}
{opt title(string)} sets the title written to cell A1 and merged across the
table width.  The default describes the table contents.

{phang}
{opt footnote(string)} writes a merged, italicized footnote in the row below the
table.  If omitted, a default footnote defines ESS% and the imbalance count and
states the {cmd:threshold()}.

{phang}
{opt decimals(#)} sets the number of decimal places for the weight columns and
{cmd:max_abs_smd}.  ESS and the count columns are always shown as integers and
ESS% as a single decimal with a percent sign.  The default is {cmd:3}.

{phang}
{opt threshold(#)} is the imbalance threshold reported in the default footnote.
It does not recompute anything -- {cmd:n_imbalanced} was already computed by
{cmd:msm_diagnose} -- it only documents the threshold used.  The default is
{cmd:0.1}.

{phang}
{opt font(string)}, {opt fontsize(#)}, and {opt border:style(string)} control
table appearance, matching {helpb msm_table}.  {cmd:borderstyle()} must be
{cmd:thin}, {cmd:medium}, or {cmd:academic}.

{phang}
{opt zebra} applies alternating light-gray shading to data rows.

{phang}
{opt open} attempts to open the workbook after export (skipped in batch mode).

{phang}
{opt replace} replaces the target sheet in an existing workbook, preserving
unrelated sheets.  Without {cmd:replace}, an existing file is an error.


{marker schema}{...}
{title:Frame schema}

{pstd}
{cmd:msm_diagtab} expects the columns written by {cmd:msm_diagnose, accumulate()}:

{synoptset 16 tabbed}{...}
{synopt:{cmd:contrast}}contrast label (string){p_end}
{synopt:{cmd:outcome}}outcome label (string, may be empty){p_end}
{synopt:{cmd:n_obs}}person-periods used{p_end}
{synopt:{cmd:ess}}effective sample size{p_end}
{synopt:{cmd:ess_pct}}ESS as a percentage of person-periods{p_end}
{synopt:{cmd:max_weight}}maximum weight{p_end}
{synopt:{cmd:p99_weight}}99th-percentile weight{p_end}
{synopt:{cmd:n_extreme}}number of weights above P99{p_end}
{synopt:{cmd:n_imbalanced}}covariates with |weighted SMD| > threshold (missing if balance not assessed){p_end}
{synopt:{cmd:max_abs_smd}}maximum |weighted SMD| (missing if balance not assessed){p_end}

{pstd}
Missing balance values are shown as {cmd:n/a} in the exported sheet.


{marker examples}{...}
{title:Examples}

{pstd}
{bf:Accumulate diagnostics across contrasts, then export:}{p_end}

{phang2}{cmd:. capture frame drop wd}{p_end}
{phang2}{cmd:. foreach c in classA classB {c -(}}{p_end}
{phang2}{cmd:.     use panel_`c'.dta, clear}{p_end}
{phang2}{cmd:.     msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) covariates(biomarker comorbidity) baseline_covariates(age sex)}{p_end}
{phang2}{cmd:.     msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) truncate(1 99) nolog}{p_end}
{phang2}{cmd:.     msm_diagnose, accumulate(wd) contrast("`c' vs platform") outcome("death")}{p_end}
{phang2}{cmd:. {c )-}}{p_end}
{phang2}{cmd:. msm_diagtab, frame(wd) xlsx("contrast_diagnostics.xlsx") replace}{p_end}

{pstd}
{bf:Custom styling:}{p_end}

{phang2}{cmd:. msm_diagtab, frame(wd) xlsx("contrast_diagnostics.xlsx")}{p_end}
{phang2}{cmd:    sheet("Table S13") title("Per-contrast weight diagnostics")}{p_end}
{phang2}{cmd:    decimals(2) borderstyle(academic) zebra replace}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Timothy P Copeland, Karolinska Institutet{break}
Department of Clinical Neuroscience
{p_end}

{hline}

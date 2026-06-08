{smcl}
{* *! version 1.6.1  08jun2026}{...}
{viewerjumpto "Syntax" "xlsxcompose##syntax"}{...}
{viewerjumpto "Description" "xlsxcompose##description"}{...}
{viewerjumpto "Examples" "xlsxcompose##examples"}{...}
{vieweralsosee "stacktab" "help stacktab"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{hline}
Help for {hi:xlsxcompose}{right:(tabtools)}
{hline}

{title:Title}

{p 4 4 2}
{bf:xlsxcompose} {hline 2} Deprecated alias for {helpb stacktab}

{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:xlsxcompose} {cmd:using} {it:outbook.xlsx}{cmd:,}
  {opt bl:ocks(blockspec)}
  {opt sheet:(sheetname)}
  [{it:options}]

{marker description}{...}
{title:Description}

{p 4 4 2}
{cmd:xlsxcompose} was the standalone command that assembled multi-sheet
composite Excel tables from source blocks. It has been folded into the
{helpb tabtools} suite as {helpb stacktab}. {cmd:xlsxcompose} is retained as a
{it:deprecated alias}: it forwards every argument to {cmd:stacktab} unchanged,
re-posts {cmd:stacktab}'s stored results, and displays a one-line deprecation
note. Existing scripts keep working without modification.

{p 4 4 2}
New code should call {helpb stacktab} directly. See {bf:{help stacktab}} for
the full syntax, options, examples, and stored results.

{marker examples}{...}
{title:Examples}

{p 4 4 2}
The following calls are equivalent; the second is the supported form:

{p 8 12 2}
{cmd:. xlsxcompose using final.xlsx, sheet("Table 2") blocks(sheet(A) \ sheet(B))}{break}
{cmd:. stacktab using final.xlsx, sheet("Table 2") blocks(sheet(A) \ sheet(B))}

{p 4 4 2}
See {helpb stacktab:stacktab Examples} for complete worked examples.

{title:Also see}

{psee}
{helpb stacktab}, {helpb puttab}, {helpb tabtools}, {helpb tabtools_cheatsheet}
{p_end}

{title:Author}

{p 4 4 2}
Timothy P Copeland, Karolinska Institutet{break}
{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{break}
Version 1.6.1
{p 4 4 2}
{hline}

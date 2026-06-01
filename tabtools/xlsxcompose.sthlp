{smcl}
{* *! version 1.3.6  01jun2026}{...}
{vieweralsosee "stacktab" "help stacktab"}{...}
{vieweralsosee "puttab" "help puttab"}{...}
{vieweralsosee "tabtools" "help tabtools"}{...}
{hline}
Help for {hi:xlsxcompose}{right:(tabtools)}
{hline}

{title:Title}

{p 4 4 2}
{bf:xlsxcompose} {hline 2} Deprecated alias for {helpb stacktab}

{title:Syntax}

{p 8 16 2}
{cmd:xlsxcompose} {cmd:using} {it:outbook.xlsx}{cmd:,}
  {opt bl:ocks(blockspec)}
  {opt sheet:(sheetname)}
  [{it:options}]

{title:Description}

{p 4 4 2}
{cmd:xlsxcompose} was the standalone command that assembled multi-sheet
composite Excel tables from source blocks. It has been folded into the
{helpb tabtools} suite as {helpb stacktab}. {cmd:xlsxcompose} is retained as a
{it:deprecated alias}: it forwards every argument to {cmd:stacktab} unchanged,
re-posts the same {cmd:r()} results, and displays a one-line deprecation note.
Existing scripts keep working without modification.

{p 4 4 2}
New code should call {helpb stacktab} directly. See {bf:{help stacktab}} for
the full syntax, options, examples, and stored results.

{title:Also see}

{psee}
{helpb stacktab}, {helpb puttab}, {helpb tabtools}, {helpb tabtools_cheatsheet}
{p_end}

{title:Author}

{p 4 4 2}
Timothy P Copeland, Karolinska Institutet{break}
{browse "mailto:timothy.copeland@ki.se":timothy.copeland@ki.se}{break}
Version 1.3.6
{p 4 4 2}
{hline}

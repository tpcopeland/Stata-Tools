*! _tvtools_rule Version 1.15.0  2026/08/10
*! Draw the standard tvtools report rule
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package
*! Program class: nclass

* The suite prints two rule widths and no others. 68 is the house width: it
* frames a label/value block and still fits an 80-column terminal. 78 is for
* the two reports that embed Stata's own tables -- tvweight wraps a logit
* table and tvdiagnose wraps tabulate/summarize, both of which are 78 wide, so
* a 68 rule would leave the borrowed output hanging past its own frame.
*
* Callers inside a quietly block prefix the call, not an option:
*     noisily _tvtools_rule, width(78)
capture program drop _tvtools_rule
program define _tvtools_rule
    version 16.0
    syntax [, Width(integer 68)]

    if !inlist(`width', 68, 78) {
        display as error "_tvtools_rule: width() must be 68 or 78"
        exit 198
    }

    display as text "{hline `width'}"
end

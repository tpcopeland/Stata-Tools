*! _tvtools_row Version 1.13.0  2026/08/02
*! Print one aligned label/value row of a tvtools report
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package
*! Program class: nclass

* One row of the house layout:
*
*     <indent><label padded to pad()> : <value>[  <note>]
*
* Every report in the suite routes its label/value lines through here so the
* colons and the value column land in the same place in every command. The
* number path right-aligns in a fixed field so digits stack into a column;
* the string path is left-aligned because names, frames, and variable lists
* read left to right.
*
* The label is peeled with gettoken rather than read from a string option, so
* a label containing a comma or an equals sign cannot be re-parsed as options.
*
* Callers inside a quietly block prefix the call:
*     noisily _tvtools_row "persons", num(200)
capture program drop _tvtools_row
program define _tvtools_row
    version 16.0

    gettoken _lbl 0 : 0, parse(" ,")
    syntax [, Value(string) Num(string) Fmt(string) Note(string) ///
        PAD(integer 28) INDent(integer 2)]

    if `pad' < 1 {
        display as error "_tvtools_row: pad() must be positive"
        exit 198
    }
    if `indent' < 0 {
        display as error "_tvtools_row: indent() must be non-negative"
        exit 198
    }
    if `"`value'"' != "" & `"`num'"' != "" {
        display as error "_tvtools_row: specify value() or num(), not both"
        exit 198
    }

    * A label longer than pad() pushes its own colon right rather than being
    * truncated. Losing a character off a label is worse than losing alignment
    * on one row, and the overflow is visible so it gets fixed at the source.
    local _w = `pad'
    if length(`"`_lbl'"') > `_w' local _w = length(`"`_lbl'"')
    local _w = `_w' + `indent'
    local _text `"`=char(32) * `indent''`_lbl'"'

    if `"`num'"' != "" {
        if `"`fmt'"' == "" local fmt "%14.0fc"
        if `"`note'"' != "" {
            display as text %-`_w's `"`_text'"' " : " ///
                as result `fmt' `num' as text `"  `note'"'
        }
        else {
            display as text %-`_w's `"`_text'"' " : " as result `fmt' `num'
        }
    }
    else if `"`value'"' != "" {
        if `"`note'"' != "" {
            display as text %-`_w's `"`_text'"' " : " ///
                as result `"`value'"' as text `"  `note'"'
        }
        else {
            display as text %-`_w's `"`_text'"' " : " as result `"`value'"'
        }
    }
    else {
        * A label with no value is a sub-heading inside the block.
        display as text `"`_text'"'
    }
end

*! xlsxcompose Version 1.6.2  2026/06/08
*! Deprecated alias for stacktab (tabtools); forwards all arguments and r()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
xlsxcompose was the standalone command that assembled multi-sheet composite
Excel tables from source blocks. It has been folded into the tabtools suite as
stacktab. This alias forwards every argument to stacktab unchanged and
re-posts stacktab's r() results, so existing scripts keep working. New code
should call stacktab directly.
*/

program define xlsxcompose, rclass
    version 16.0
    display as text ///
        "note: xlsxcompose is a deprecated alias for {bf:stacktab}; please use stacktab"
    stacktab `0'
    return add
end

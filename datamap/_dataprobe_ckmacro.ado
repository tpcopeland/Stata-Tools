*! _dataprobe_ckmacro Version 2.1.0  2026/11/16
*! Refuse a dataprobe checks() spec row whose text holds a Stata macro character
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// 2.1.0 (R1).  dataprobe reads each checks() row as if its text had been
// typed in the option, and that text passes through local macros, so a
// backtick or a $ that starts a global name ($name, ${name}) in a row was
// expanded once: a row expression s != "a$b" silently became s != "a".  A
// typed option never reaches dataprobe with such text (the do-file expands
// it first), so in a row it can only be a literal the user meant, or a
// reference meant to be resolved at run time.  Neither can be honoured
// safely, so the row is refused (rc 198), naming the row and column.  A $
// that does not start a name ($ at the end of a regex, "$5") is plain text
// and is accepted.  Run in the frame that holds the spec; it reads the
// columns dataprobe reads: gate (or check), var (or variable), arg1, arg2,
// values, pattern and kind.
program define _dataprobe_ckmacro, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        local cols ""
        foreach v in gate check var variable arg1 arg2 values pattern kind {
            capture confirm string variable `v', exact
            if !_rc local cols "`cols' `v'"
        }
        if "`cols'" != "" {
            mata: _dataprobe_ckmacro_scan(tokens(st_local("cols")))
            if `_ck_row' {
                display as error "checks(): row `_ck_row', column `_ck_col', holds a backtick or a " ///
                    "$ before a name, which dataprobe would expand as a macro; write the character " ///
                    "as char(96) or char(36) in an expression, or remove it"
                exit 198
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture mata: mata drop _dataprobe_ckmacro_scan()
mata:
// the first row (and its column) whose text holds a backtick, or a $
// followed by a letter, underscore or {; _ck_row 0 when none
void _dataprobe_ckmacro_scan(string rowvector cl)
{
	real scalar i, j
	string scalar x, re
	st_local("_ck_row", "0")
	st_local("_ck_col", "")
	re = "[" + char(36) + "][A-Za-z_{]"
	for (i = 1; i <= st_nobs(); i++) {
		for (j = 1; j <= cols(cl); j++) {
			x = _st_sdata(i, st_varindex(cl[j]))
			if (strpos(x, char(96)) | ustrregexm(x, re)) {
				st_local("_ck_row", strofreal(i, "%20.0f"))
				st_local("_ck_col", cl[j])
				return
			}
		}
	}
}
end

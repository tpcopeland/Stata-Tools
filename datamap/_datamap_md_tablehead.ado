*! _datamap_md_tablehead Version 2.0.0  2026/11/10
*! The header and divider lines of datamap's Markdown variable table
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// _datamap_md_tablehead using file, columns(list)
// Appends the header row and the divider row for the columns named in
// columns() (as normalized by _datamap_md_columns) to `file'.
capture mata: mata drop _dmth_put()
mata:
void _dmth_put(string scalar path, string scalar cols)
{
	string rowvector cl
	string scalar h, d, lab
	real scalar j, fh

	cl = tokens(cols)
	h = "|"
	d = "|"
	for (j = 1; j <= cols(cl); j++) {
		if (cl[j] == "variable") lab = "Variable"
		else if (cl[j] == "label") lab = "Label"
		else if (cl[j] == "type") lab = "Type"
		else if (cl[j] == "class") lab = "Class"
		else if (cl[j] == "format") lab = "Format"
		else if (cl[j] == "vallabel") lab = "Value label"
		else if (cl[j] == "missing") lab = "Missing"
		else if (cl[j] == "values") lab = "Values/Statistics"
		else if (cl[j] == "notes") lab = "Notes"
		else if (cl[j] == "chars") lab = "Characteristics"
		else if (cl[j] == "unique") lab = "Unique"
		else if (cl[j] == "position") lab = "Position"
		else {
			errprintf("_datamap_md_tablehead: unknown column %s\n", cl[j])
			exit(198)
		}
		h = h + " " + lab + " |"
		d = d + "---|"
	}
	fh = _fopen(path, "a")
	if (fh < 0) {
		errprintf("_datamap_md_tablehead: cannot open %s (error %g)\n", path, fh)
		exit(603)
	}
	fput(fh, h)
	fput(fh, d)
	fclose(fh)
}
end

program define _datamap_md_tablehead, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , COLumns(string)
        mata: _dmth_put(st_local("using"), "`columns'")
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

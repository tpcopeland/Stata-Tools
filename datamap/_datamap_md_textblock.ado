*! _datamap_md_textblock Version 2.0.0  2026/11/10
*! A Markdown text block (notes(), changelog()) from text or a text file
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// _datamap_md_textblock using file, text(string)
// text(): the option value as datamap transports it (_datamap_transport_encode:
// $, `, line breaks and the transport prefix encoded, so no macro or quote
// syntax in the text is read on the way here).  When the decoded text names
// an existing file, each line of that file is written, escaped for Markdown;
// otherwise the text itself is (a line break in it becomes a space).  Written
// in Mata, appended to `file'.
capture mata: mata drop _dmtb_esc()
capture mata: mata drop _dmtb_unquote()
capture mata: mata drop _dmtb_decode()
capture mata: mata drop _dmtb_put()
mata:
string scalar _dmtb_esc(string scalar text)
{
	real scalar i
	text = subinstr(text, char(92), char(92) + char(92))
	text = subinstr(text, "|", char(92) + "|")
	text = subinstr(text, char(36), "&#36;")
	text = subinstr(text, char(96), "&#96;")
	text = subinstr(text, char(34) + char(39), char(34) + "&#39;")
	text = subinstr(text, char(13) + char(10), " ")
	text = subinstr(text, char(10), " ")
	text = subinstr(text, char(13), " ")
	for (i = 1; i <= 31; i++) text = subinstr(text, char(i), " ")
	text = subinstr(text, char(127), " ")
	text = subinstr(text, "<", "&lt;")
	text = subinstr(text, ">", "&gt;")
	return(text)
}
string scalar _dmtb_unquote(string scalar value)
{
	real scalar n
	n = strlen(value)
	while (n >= 4 & substr(value, 1, 2) == char(96) + char(34) &
		substr(value, n - 1, 2) == char(34) + char(39)) {
		value = substr(value, 3, n - 4)
		n = strlen(value)
	}
	return(value)
}
string scalar _dmtb_decode(string scalar text)
{
	string scalar p
	p = "__DATAMAP_68F73A__"
	text = subinstr(text, p + "D", char(36))
	text = subinstr(text, p + "T", char(96))
	text = subinstr(text, p + "N", char(10))
	text = subinstr(text, p + "R", char(13))
	text = subinstr(text, p + "P", p)
	return(text)
}
void _dmtb_put(string scalar path, string scalar enc)
{
	string scalar t
	string colvector L
	real scalar fh, i

	t = _dmtb_decode(_dmtb_unquote(enc))
	if (t == "") return
	if (fileexists(t)) L = cat(t)
	else L = t
	for (i = 1; i <= rows(L); i++) L[i] = _dmtb_esc(L[i])
	fh = _fopen(path, "a")
	if (fh < 0) {
		errprintf("_datamap_md_textblock: cannot open %s (error %g)\n", path, fh)
		exit(603)
	}
	for (i = 1; i <= rows(L); i++) fput(fh, L[i])
	fclose(fh)
}
end

program define _datamap_md_textblock, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ , [TEXT(string asis)]
        mata: _dmtb_put(st_local("using"), st_local("text"))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

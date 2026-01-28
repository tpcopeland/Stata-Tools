#!/usr/bin/env python3
"""
Stata Code Snippets Library

Provides common Stata code patterns for package development.
"""

import json
from pathlib import Path
from typing import Optional, List, Dict, Any

# Paths
DATA_DIR = Path(__file__).parent.parent / "data"

# Built-in snippets for common patterns
SNIPPETS = {
    # Program structure
    "program_rclass": {
        "name": "program_rclass",
        "purpose": "Basic rclass program structure",
        "keywords": ["program", "rclass", "template", "basic"],
        "code": '''program define mycommand, rclass
    version 16.0
    set varabbrev off

    syntax varlist [if] [in] [, options]

    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000

    // ... computation ...

    return scalar N = r(N)
end'''
    },

    "program_eclass": {
        "name": "program_eclass",
        "purpose": "Basic eclass program structure for estimation",
        "keywords": ["program", "eclass", "estimation", "template"],
        "code": '''program define myestimate, eclass
    version 16.0
    set varabbrev off

    syntax varlist(min=2) [if] [in] [, Level(cilevel)]

    marksample touse
    gettoken depvar indepvars : varlist

    tempname b V
    // ... estimation ...

    ereturn post `b' `V', obs(`=r(N)') esample(`touse')
    ereturn local cmd "myestimate"
    ereturn local depvar "`depvar'"
end'''
    },

    # Syntax patterns
    "syntax_basic": {
        "name": "syntax_basic",
        "purpose": "Basic syntax with options",
        "keywords": ["syntax", "options", "parsing"],
        "code": '''syntax varlist [if] [in] [, ///
    by(varlist)           /// Grouping variable
    GENerate(name)        /// New variable name
    Replace               /// Overwrite existing
    ]'''
    },

    "syntax_using": {
        "name": "syntax_using",
        "purpose": "Syntax with using file",
        "keywords": ["syntax", "using", "file"],
        "code": '''syntax [varlist] using/ [if] [in] [, ///
    id(varname)           /// ID variable
    Replace               /// Overwrite
    ]

capture confirm file `"`using'"'
if _rc != 0 {
    display as error "File not found: `using'"
    exit 601
}'''
    },

    # Sample marking
    "marksample_basic": {
        "name": "marksample_basic",
        "purpose": "Basic sample marking pattern",
        "keywords": ["marksample", "touse", "if", "in"],
        "code": '''marksample touse
quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
local n = r(N)'''
    },

    "marksample_full": {
        "name": "marksample_full",
        "purpose": "Full sample marking with option variables",
        "keywords": ["marksample", "markout", "touse", "options"],
        "code": '''marksample touse
markout `touse' `byvar' `idvar'

quietly count if `touse'
if r(N) == 0 {
    display as error "no observations"
    exit 2000
}
local n = r(N)'''
    },

    # Temporary objects
    "tempvar_usage": {
        "name": "tempvar_usage",
        "purpose": "Temporary variable pattern",
        "keywords": ["tempvar", "temporary", "variable"],
        "code": '''tempvar result flag counter

gen double `result' = . if `touse'
gen byte `flag' = 0
gen long `counter' = _n

// Variables automatically dropped at program end'''
    },

    "tempfile_merge": {
        "name": "tempfile_merge",
        "purpose": "Temporary file for merge operations",
        "keywords": ["tempfile", "merge", "save"],
        "code": '''tempfile original merged

save `original', replace
// ... process data ...
merge 1:1 id using `merged', nogenerate
// Files automatically deleted at program end'''
    },

    # Loops
    "foreach_varlist": {
        "name": "foreach_varlist",
        "purpose": "Loop over varlist",
        "keywords": ["foreach", "loop", "varlist"],
        "code": '''foreach var of varlist `varlist' {
    quietly summarize `var' if `touse'
    display "`var': mean = " r(mean)
}'''
    },

    "forvalues_years": {
        "name": "forvalues_years",
        "purpose": "Loop over year range",
        "keywords": ["forvalues", "loop", "years", "append"],
        "code": '''clear
local first = 1
forvalues yr = 2000/2024 {
    capture confirm file "`datadir'/data_`yr'.dta"
    if _rc == 0 {
        if `first' {
            use "`datadir'/data_`yr'.dta", clear
            local first = 0
        }
        else {
            append using "`datadir'/data_`yr'.dta"
        }
    }
}'''
    },

    # Error handling
    "capture_check": {
        "name": "capture_check",
        "purpose": "Capture with error check",
        "keywords": ["capture", "error", "_rc"],
        "code": '''capture noisily mycommand args
if _rc != 0 {
    display as error "Command failed with error `_rc'"
    exit _rc
}'''
    },

    "confirm_variable": {
        "name": "confirm_variable",
        "purpose": "Confirm variable exists and is numeric",
        "keywords": ["confirm", "variable", "validate"],
        "code": '''capture confirm variable `varname'
if _rc != 0 {
    display as error "Variable `varname' not found"
    exit 111
}

capture confirm numeric variable `varname'
if _rc != 0 {
    display as error "Variable `varname' must be numeric"
    exit 109
}'''
    },

    # Output formatting
    "display_table": {
        "name": "display_table",
        "purpose": "Display formatted table",
        "keywords": ["display", "table", "output", "format"],
        "code": '''display ""
display as text _dup(60) "-"
display as text "Results"
display as text _dup(60) "-"
display as text "Observations:   " as result %12.0fc `n'
display as text "Mean:           " as result %12.4f `mean'
display as text _dup(60) "-"'''
    },

    "display_progress": {
        "name": "display_progress",
        "purpose": "Display progress indicator",
        "keywords": ["display", "progress", "loop"],
        "code": '''local total = _N
forvalues i = 1/`total' {
    if mod(`i', 1000) == 0 {
        display as text "." _continue
    }
}
display ""  // New line after dots'''
    },

    # gettoken parsing
    "gettoken_basic": {
        "name": "gettoken_basic",
        "purpose": "Basic gettoken parsing",
        "keywords": ["gettoken", "parse", "tokenize"],
        "code": '''local mylist "apple banana cherry"
gettoken first rest : mylist
// first = "apple", rest = "banana cherry"'''
    },

    "gettoken_loop": {
        "name": "gettoken_loop",
        "purpose": "Loop through list with gettoken",
        "keywords": ["gettoken", "loop", "parse"],
        "code": '''local mylist "`varlist'"
while "`mylist'" != "" {
    gettoken element mylist : mylist
    display "Processing: `element'"
}'''
    },

    # Extended macro functions
    "wordcount": {
        "name": "wordcount",
        "purpose": "Count words in list",
        "keywords": ["word", "count", "macro", "function"],
        "code": '''local n: word count `varlist'
local first: word 1 of `varlist'
local last: word `n' of `varlist'
display "Processing `n' variables: `first' ... `last'"'''
    },

    "list_functions": {
        "name": "list_functions",
        "purpose": "List manipulation functions",
        "keywords": ["list", "macro", "function", "sort", "unique"],
        "code": '''local unique: list uniq mylist
local count: list sizeof mylist
local sorted: list sort mylist
local combined: list list1 | list2
local common: list list1 & list2
local diff: list list1 - list2'''
    },

    # Return values
    "return_scalar": {
        "name": "return_scalar",
        "purpose": "Return scalar values",
        "keywords": ["return", "scalar", "rclass"],
        "code": """return scalar N = `n'
return scalar mean = `mean_val'
return scalar sd = `sd_val'
return scalar min = `min_val'
return scalar max = `max_val'"""
    },

    "return_matrix": {
        "name": "return_matrix",
        "purpose": "Return matrix values",
        "keywords": ["return", "matrix", "rclass"],
        "code": """tempname results
matrix `results' = J(5, 3, .)
// ... fill matrix ...
matrix colnames `results' = estimate se pvalue
matrix rownames `results' = var1 var2 var3 var4 var5
return matrix results = `results'"""
    },

    # Character repetition (common mistake)
    "display_line": {
        "name": "display_line",
        "purpose": "Correct character repetition (not string*n)",
        "keywords": ["display", "line", "_dup", "repeat"],
        "code": '''// CORRECT - use _dup()
display _dup(60) "="
display _dup(60) "-"
display _dup(40) "*"

// WRONG - don't use string multiplication
// display "=" * 60  // This doesn't work in Stata!'''
    },

    # Sorting without functions
    "bysort_nofunc": {
        "name": "bysort_nofunc",
        "purpose": "Sorting without functions in sort spec",
        "keywords": ["bysort", "sort", "function"],
        "code": '''// WRONG - can't use functions in sort spec
// bysort id (abs(diff)): keep if _n == 1

// CORRECT - create temp variable first
gen temp_abs = abs(diff)
bysort id (temp_abs): keep if _n == 1
drop temp_abs'''
    }
}


def get_snippet(name: str) -> Optional[Dict[str, Any]]:
    """
    Get a specific code snippet.

    Args:
        name: Snippet name (e.g., "marksample_basic", "foreach_varlist")

    Returns:
        Dictionary with snippet info or None if not found.
        {
            "name": "marksample_basic",
            "purpose": "Basic sample marking pattern",
            "code": "marksample touse\\n..."
        }
    """
    return SNIPPETS.get(name)


def search_snippets(query: str, limit: int = 5) -> List[Dict[str, Any]]:
    """
    Search snippets by keyword.

    Args:
        query: Search term
        limit: Maximum results

    Returns:
        List of matching snippets.
    """
    query_lower = query.lower()
    matches = []

    for name, snippet in SNIPPETS.items():
        score = 0

        # Check name
        if query_lower in name.lower():
            score += 10

        # Check purpose
        if query_lower in snippet.get("purpose", "").lower():
            score += 5

        # Check keywords
        for kw in snippet.get("keywords", []):
            if query_lower in kw.lower():
                score += 3

        # Check code
        if query_lower in snippet.get("code", "").lower():
            score += 1

        if score > 0:
            matches.append((score, {
                "name": name,
                "purpose": snippet.get("purpose", ""),
                "keywords": snippet.get("keywords", [])
            }))

    matches.sort(key=lambda x: x[0], reverse=True)
    return [m[1] for m in matches[:limit]]


def list_snippets(category: Optional[str] = None) -> List[Dict[str, str]]:
    """
    List available snippets.

    Args:
        category: Filter by keyword category (optional)

    Returns:
        List of snippets with name and purpose.
    """
    result = []

    for name, snippet in SNIPPETS.items():
        if category:
            if category.lower() not in [k.lower() for k in snippet.get("keywords", [])]:
                continue

        result.append({
            "name": name,
            "purpose": snippet.get("purpose", ""),
            "keywords": snippet.get("keywords", [])
        })

    return sorted(result, key=lambda x: x["name"])


# CLI for testing
if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: snippets.py <command> [args]")
        print("Commands: get <name>, search <query>, list [category]")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "get" and len(sys.argv) > 2:
        result = get_snippet(sys.argv[2])
        if result:
            print(f"# {result['name']}: {result['purpose']}")
            print(result['code'])
        else:
            print(f"Snippet not found: {sys.argv[2]}")

    elif cmd == "search" and len(sys.argv) > 2:
        results = search_snippets(sys.argv[2])
        print(json.dumps(results, indent=2))

    elif cmd == "list":
        category = sys.argv[2] if len(sys.argv) > 2 else None
        results = list_snippets(category)
        for s in results:
            print(f"{s['name']}: {s['purpose']}")

    else:
        print(f"Unknown command: {cmd}")

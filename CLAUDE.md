# Stata Coding Guide for Claude

**Purpose**: Quick reference for developing Stata packages, auditing .do files, and writing Stata commands. Optimized for Claude Opus 4.5.

---

## Critical Rules (Always Follow)

1. **Always set**: `version 18.0`, `set varabbrev off`, `set more off`
2. **Use `marksample touse`** for if/in conditions in programs
3. **Return results** via `return` (rclass) or `ereturn` (eclass)
4. **Use temp objects**: `tempvar`, `tempfile`, `tempname` for temporary variables/files/matrices
5. **Validate inputs** before processing, provide clear error messages
6. **Never abbreviate** variable names in production code

---

## Minimal Working Package

**mycommand.ado**:
```stata
*! version 1.0.0  15jan2024
program define mycommand, rclass
    version 18.0
    syntax varlist(numeric) [if] [in] [, Option1 Option2(string)]

    marksample touse
    quietly count if `touse'
    if r(N) == 0 error 2000

    quietly {
        // computation
    }

    return scalar N = r(N)
    return local varlist "`varlist'"
end
```

**mycommand.sthlp**:
```smcl
{smcl}
{title:Title}
{p2colset 5 18 20 2}{p2col:{cmd:mycommand}}Brief description{p_end}{p2colreset}

{title:Syntax}
{p 8 16 2}{cmd:mycommand} {varlist} {ifin} [{cmd:,} {it:options}]

{title:Description}
{pstd}{cmd:mycommand} does...

{title:Examples}
{phang2}{cmd:. sysuse auto}{p_end}
{phang2}{cmd:. mycommand price mpg}{p_end}

{title:Author}
{pstd}Your Name
```

**mycommand.pkg**:
```stata
v 3
d mycommand: Brief description
d Author: Your Name
f mycommand.ado
f mycommand.sthlp
```

---

## Program Classes

| Class | Use Case | Declaration | Returns |
|-------|----------|-------------|---------|
| `rclass` | General commands | `program define cmd, rclass` | `return scalar/local/matrix` |
| `eclass` | Estimation commands | `program define cmd, eclass` | `ereturn post/scalar/local` |
| `sclass` | String parsing | `program define cmd, sclass` | `sreturn local` |

---

## Essential Syntax Patterns

```stata
* Basic
syntax varlist [if] [in] [, options]

* Numeric only
syntax varlist(numeric) [if] [in]

* Exact variable count
syntax varlist(min=2 max=2) [if] [in]

* With file
syntax using/ [, options]

* Required option (uppercase first letter)
syntax varlist [, REQuired optional]

* Option with argument
syntax varlist [, option(string)]
```

---

## Common Error Codes

- 100: varlist required
- 109: type mismatch
- 111: variable not found
- 198: invalid syntax
- 601: file not found
- 2000: no observations

---

## Testing Pattern

```stata
clear all
set seed 12345

* Test 1: Basic functionality
sysuse auto
mycommand price mpg
assert r(N) == 74
assert !missing(r(mean))

* Test 2: Error handling
clear
set obs 0
capture mycommand price
assert _rc != 0

* Test 3: Tolerance check
assert abs(actual - expected) < 1e-8
```

---

## Synthetic Data Generation

```stata
clear all
set seed 12345
set obs 1000

* Binary
generate treated = runiform() < 0.3

* Categorical with probabilities
generate temp = runiform()
generate edu = cond(temp<.2, 1, cond(temp<.5, 2, cond(temp<.8, 3, 4)))
drop temp

* Continuous
generate age = 18 + runiform() * 62
generate income = exp(rnormal(10.5, 0.7))

* Correlated variables (rho=0.7)
generate z1 = rnormal()
generate z2 = rnormal()
local rho = 0.7
generate x = z1
generate y = `rho'*z1 + sqrt(1-`rho'^2)*z2
```

---

## Performance Rules

1. **Vectorize**: Use `generate y = x^2` not loops
2. **Single pass**: Calculate multiple stats together
3. **Use Mata for**: matrix ops, intensive loops, custom algorithms
4. **Use Stata for**: data management, standard estimation, graphics
5. **Profile**: `timer on/off` to identify bottlenecks

**When NOT to use Mata**:
```stata
* Simple transformations (Stata is clearer)
generate y = log(x + 1)              // NOT: mata: st_store(...)

* Standard estimation (built-in commands)
regress y x1 x2                      // NOT: mata: invsym(...)

* Data management (Stata excels here)
merge 1:1 id using other.dta         // NOT: mata custom merge
```

---

## Mata Quick Reference

```stata
program define mycommand
    version 18.0
    syntax varlist
    mata: do_computation("`varlist'")
end

mata
void do_computation(string scalar varlist) {
    real matrix X
    st_view(X, ., tokens(varlist))  // View data (efficient)

    result = mean(X)

    st_numscalar("r(mean)", result)  // Return to Stata
}
end
```

**Key functions**: `st_view()`, `st_data()`, `st_store()`, `st_matrix()`, `st_numscalar()`, `st_local()`

---

## Debugging Workflow

```stata
* Step 1: Enable trace
set trace on
mycommand args
set trace off

* Step 2: Add pauses
program define mycommand
    pause on
    pause              // Execution stops here
    display "Debug: varlist = `varlist'"
end

* Step 3: Inspect returns
mycommand y x
return list
```

---

## Project Structure

```
project/
├── code/
│   ├── 00_master.do
│   ├── 01_cleaning.do
│   ├── 02_analysis.do
│   └── functions/
│       ├── myfunction.ado
│       └── myfunction.sthlp
├── data/
│   ├── raw/
│   ├── processed/
│   └── final/
└── output/
    ├── tables/
    ├── figures/
    └── logs/
```

**Master script**:
```stata
clear all
set more off
set varabbrev off

global project_dir "`c(pwd)'"
global data_dir "${project_dir}/data"
global output_dir "${project_dir}/output"

adopath ++ "${project_dir}/code/functions"

log using "${output_dir}/logs/analysis.log", replace

do "${project_dir}/code/01_cleaning.do"
do "${project_dir}/code/02_analysis.do"

log close
```

---

## Error Handling

```stata
* Validate variable exists
capture confirm variable varname
if _rc {
    display as error "variable varname not found"
    exit 111
}

* Check conditions
if condition_fails {
    display as error "Clear error message"
    display as error "What user should do"
    exit 198
}
```

---

## Common Pitfalls

| Issue | Problem | Solution |
|-------|---------|----------|
| varabbrev | Variable abbreviation | `set varabbrev off` |
| Random seed | Non-reproducible | `set seed 12345` |
| File paths | Backslashes fail | Use forward slashes |
| Missing values | Ignored | Use `marksample touse` |
| Global pollution | Persistent state | Use locals, not globals |
| No version | Breaking changes | `version 18.0` |

---

## Distribution Checklist

- [ ] Version in header (`*! version 1.0.0`)
- [ ] Help file exists and complete
- [ ] Examples in help file work
- [ ] Tests pass
- [ ] Works with `set varabbrev off`
- [ ] Error messages informative
- [ ] No hardcoded paths
- [ ] Handles missing data
- [ ] README with installation
- [ ] License file

---

## Quick Command Reference

| Task | Command |
|------|---------|
| Mark sample | `marksample touse` |
| Validate variable | `confirm variable var` |
| Check file exists | `confirm file "path"` |
| Temporary objects | `tempvar/tempfile/tempname` |
| Profile performance | `timer on/off` |
| Debug | `set trace on`, `pause` |
| Test assertion | `assert condition` |

---

## Input Validation & Security

```stata
* Validate numeric ranges
if `threshold' < 0 | `threshold' > 1 {
    display as error "threshold() must be between 0 and 1"
    exit 198
}

* Sanitize file paths - prevent injection
if regexm("`filename'", "[;&|><\$\`]") {
    display as error "filename() contains invalid characters"
    exit 198
}

* Check file existence before operations
confirm file "`using'"

* Validate variable types
capture confirm numeric variable `var'
if _rc {
    display as error "`var' must be numeric"
    exit 109
}
```

**Security Rules**:
- NEVER execute user input directly
- Validate ALL file paths before shell commands
- Check numeric ranges to prevent overflow
- Don't expose sensitive info in error messages
- Use `confirm` for existence checks

---

## Testing Pattern (Essential)

```stata
* Basic unit test structure
program define test_mycommand
    clear all
    set seed 12345

    * Test 1: Basic functionality
    set obs 100
    generate x = rnormal()
    mycommand x
    assert r(N) == 100
    assert abs(r(mean)) < 0.5

    * Test 2: Error handling (should fail)
    clear
    set obs 0
    capture mycommand x
    assert _rc != 0

    * Test 3: Tolerance for floats
    assert abs(actual - expected) < 1e-8

    display "All tests PASSED"
end
```

**Test Edge Cases**:
- Empty dataset (0 obs)
- Single observation
- All missing values
- Perfect collinearity
- Zero variance
- Extreme values

---

## Panel Data Generation

```stata
clear
set seed 12345
set obs 500  // individuals

generate id = _n
generate ability = rnormal()  // individual effect

expand 10  // 10 time periods
bysort id: generate time = _n

* Time-varying with individual effects
bysort id: generate experience = time - 1
generate outcome = 2.5 + 0.05*experience + ability + rnormal(0, 0.2)

xtset id time
```

---

## Correlated Variables

```stata
* Two correlated variables (rho = 0.7)
generate z1 = rnormal()
generate z2 = rnormal()
local rho = 0.7
generate x = z1
generate y = `rho'*z1 + sqrt(1-`rho'^2)*z2

* Multiple correlated variables (Cholesky)
matrix C = (1, 0.5, 0.3 \ 0.5, 1, 0.6 \ 0.3, 0.6, 1)
matrix L = cholesky(C)

generate u1 = rnormal()
generate u2 = rnormal()
generate u3 = rnormal()

generate v1 = L[1,1]*u1
generate v2 = L[2,1]*u1 + L[2,2]*u2
generate v3 = L[3,1]*u1 + L[3,2]*u2 + L[3,3]*u3
```

---

## Project Organization

```
project/
├── code/
│   ├── 00_master.do          # Run all scripts
│   ├── 01_cleaning.do
│   ├── 02_analysis.do
│   └── functions/            # Custom ado files
├── data/
│   ├── raw/                  # NEVER modify
│   ├── processed/
│   └── final/
├── output/
│   ├── tables/
│   ├── figures/
│   └── logs/
└── tests/
    └── test_*.do
```

**Master Script**:
```stata
clear all
set more off
set varabbrev off

global project_dir "`c(pwd)'"
global code_dir "${project_dir}/code"
global data_dir "${project_dir}/data"
global output_dir "${project_dir}/output"

adopath ++ "${code_dir}/functions"

log using "${output_dir}/logs/analysis.log", replace

do "${code_dir}/01_cleaning.do"
do "${code_dir}/02_analysis.do"

log close
```

---

## Top Pitfalls to Avoid

1. **Not setting `varabbrev off`** - Variables get abbreviated ambiguously
2. **Not setting seed** - Non-reproducible random results
3. **Backslashes in paths** - Use `/` not `\` (works all OS)
4. **Not quoting paths with spaces** - Always quote: `"my file.dta"`
5. **Forgetting `clear`** - Data in memory warning
6. **Modifying raw data** - NEVER save over raw data files
7. **Ignoring missing values** - Use `if !missing(var)`
8. **Assuming sorted** - Use `bysort` not `by`
9. **String vs numeric** - Check with `describe`, use `destring`
10. **Global pollution** - Use `local` not `global` when possible

---

## Common Errors Decoded

| Error | Meaning | Fix |
|-------|---------|-----|
| `r(111)` | Variable not found | Check spelling, use `describe` |
| `r(198)` | Invalid syntax | Check comma, brackets, help file |
| `r(2000)` | No observations | Check if/in conditions, count |
| `r(601)` | File not found | Check path, use forward slashes |

---

## File Path Rules

```stata
* ALWAYS use forward slashes (works everywhere)
use "C:/data/file.dta", clear  // Good
use "C:\data\file.dta", clear  // Bad (Windows only)

* ALWAYS quote paths
use "my data/file.dta", clear   // Good
use my data/file.dta, clear     // Bad (fails)

* Use globals for projects
global data_dir "${project_dir}/data"
use "${data_dir}/analysis.dta", clear
```

---

## Return Values Quick Reference

```stata
* After regress
display e(N)      // N observations
display e(r2)     // R-squared
display e(df_m)   // Model df
matrix b = e(b)   // Coefficients

* After summarize
display r(N)      // N observations
display r(mean)   // Mean
display r(sd)     // SD
display r(min)    // Min
display r(max)    // Max
```

---

## Debugging Checklist

```stata
* 1. Enable trace
set trace on
mycommand args
set trace off

* 2. Add checkpoints
display "Checkpoint 1: varlist = `varlist'"
display "Checkpoint 2: N = " _N

* 3. Check data
list in 1/10
codebook varname
inspect varname

* 4. Test incrementally
mycommand var1          // Works?
mycommand var1 var2     // Works?
mycommand var1 var2 var3  // Fails? Problem is var3
```

---

## Frames (Stata 16+) - Multi-Dataset Management

```stata
* Create and work with multiple datasets in memory
frame create analysis
frame analysis: use "data.dta", clear

frame create temp
frame temp: use "other.dta", clear

* Switch between frames
frame change analysis

* Link frames (like merge without combining)
frame analysis {
    frlink 1:1 id, frame(temp)
    frget var1 var2, from(temp)
}

* Always clean up
frame drop temp

* List all frames
frame dir
```

**When to use**: Iterative operations needing multiple datasets, avoiding repeated save/load cycles.

---

## Factor Variables & Time Series Operators

### Factor Variables

```stata
* i. = indicator (dummy) variables
regress y i.treatment              // treatment dummies

* c. = continuous (explicit)
regress y c.age

* # = interaction only
regress y i.treatment#c.age        // interaction only

* ## = full factorial (main + interaction)
regress y i.treatment##c.age       // treatment + age + treatment*age

* ib. = set base level
regress y ib2.treatment            // treatment==2 is reference

* ibn. = no base (all levels, no constant)
regress y ibn.treatment, noconstant
```

### Time Series Operators (require `tsset` first)

```stata
tsset time_var                     // or tsset panel_var time_var

* L. = lag
generate lag1 = L.varname
generate lag2 = L2.varname

* F. = forward/lead
generate lead1 = F.varname

* D. = difference
generate diff = D.varname          // varname - L.varname

* S. = seasonal difference
generate sdiff = S12.varname       // varname - L12.varname

* In regressions
regress y L.y L(0/4).x             // AR(1) with distributed lags
```

---

## Panel Data Quick Reference

```stata
* Setup panel structure
xtset id time
xtset id time, delta(1)

* Explore structure
xtdescribe
xtsum varlist                      // within/between/overall variation
xttab varname

* Fixed effects
xtreg y x1 x2, fe
xtreg y x1 x2, fe robust
xtreg y x1 x2, fe cluster(id)

* Random effects
xtreg y x1 x2, re
xtreg y x1 x2, re robust

* Hausman test (FE vs RE)
quietly xtreg y x1 x2, fe
estimates store fe
quietly xtreg y x1 x2, re
estimates store re
hausman fe re

* Dynamic panel (GMM)
xtabond y x1 x2, lags(2)
xtdpdsys y x1 x2, lags(2)

* Panel transformations
bysort id: egen mean_x = mean(x)  // between
generate x_within = x - mean_x    // within
generate d_x = D.x                // first difference
```

---

## Graphics for Publication

```stata
* Basic publication-quality scatter
twoway (scatter y x, mcolor(navy%60) msize(small)) ///
       (lfit y x, lcolor(red) lwidth(medium)), ///
    title("Title") ///
    xtitle("X Label") ytitle("Y Label") ///
    xlabel(, grid) ylabel(, grid angle(horizontal)) ///
    legend(order(1 "Data" 2 "Fit") position(11) ring(0)) ///
    graphregion(color(white)) ///
    scheme(s2mono)

* Save and export
graph save "figure.gph", replace
graph export "figure.png", width(3000) replace
graph export "figure.pdf", replace
graph export "figure.eps", preview(off) replace

* Combine multiple graphs
graph save "g1.gph", replace
graph save "g2.gph", replace
graph combine "g1.gph" "g2.gph", rows(1)

* By-groups (small multiples)
scatter y x, by(group, title("Title") graphregion(color(white)))

* Margins plots (after estimation)
regress y i.group##c.x
margins group, at(x=(0(1)10))
marginsplot, title("Predicted Y by Group")
```

**Key settings**:
- `scheme(s2mono)` for B&W publications
- `width(3000)` for high-res PNG
- Always use `graphregion(color(white))`
- Position legend: `position(11) ring(0)` = NW corner inside plot

---

## Data Import/Export Patterns

### Import Common Formats

```stata
* CSV/delimited
import delimited "file.csv", clear varnames(1)
import delimited "file.csv", stringcols(_all) clear  // All as string first
import delimited "file.csv", encoding("UTF-8") clear

* Excel
import excel "file.xlsx", firstrow clear
import excel "file.xlsx", sheet("Data") cellrange(A1:E100) firstrow clear

* SPSS/SAS
import spss using "file.sav", clear
import sas using "file.sas7bdat", clear

* Fixed-width (need dictionary)
infix int id 1-5 str20 name 6-25 double value 26-35 using "data.txt", clear

* Database (ODBC)
odbc load, table("TableName") dsn("DataSource") clear
odbc load, exec("SELECT * FROM table WHERE year=2020") dsn("DataSource") clear

* Web
use "http://example.com/data.dta", clear
copy "http://example.com/data.csv" "local.csv", replace
import delimited "local.csv", clear
```

### Export Formats

```stata
* Stata format
save "data.dta", replace
saveold "data_v14.dta", version(14) replace

* CSV
export delimited using "output.csv", replace
export delimited using "output.csv", delimiter(tab) replace

* Excel
export excel using "output.xlsx", firstrow(variables) replace
export excel using "output.xlsx", sheet("Results") firstrow(variables) replace

* LaTeX (requires estout)
esttab using "table.tex", replace
```

### Common Import Issues

```stata
* Issue 1: Mixed types in column
import delimited "data.csv", stringcols(_all) clear
destring income, replace force  // Convert to numeric, . for failures

* Issue 2: Dates as strings
import delimited "data.csv", clear
generate date_var = date(date_str, "YMD")  // or "MDY", "DMY"
format date_var %td

* Issue 3: Encoding problems
import delimited "data.csv", encoding("UTF-8") clear
unicode analyze *
unicode translate *

* Issue 4: Large files
import delimited "huge.csv" in 1/100000, clear  // Load subset
import delimited id outcome treatment using "huge.csv", clear  // Load columns
```

---

## Multiple Imputation Workflow

### Setup and Impute

```stata
* 1. Setup MI structure
mi set mlong

* 2. Register variables
mi register imputed var1 var2       // Variables to impute
mi register regular var3 var4       // Complete variables
mi register passive log_var1        // Derived from imputed

* 3. Create passive variables
mi passive: replace log_var1 = log(var1)

* 4. Impute (M=20-50 typically)
mi impute pmm var1 var2 = var3 var4, add(30) rseed(12345) knn(5)

* For multiple variables with different methods
mi impute chained ///
    (pmm, knn(5)) continuous_var ///
    (logit) binary_var ///
    (ologit) ordinal_var ///
    = complete_vars, ///
    add(30) rseed(12345) dots
```

### Analysis After Imputation

```stata
* Run analysis on all imputations (pooled results)
mi estimate: regress y x1 x2

* With options
mi estimate, dots: regress y x1 x2
mi estimate, saving(miests): regress y x1 x2

* Post-estimation
mi estimate: regress y x1 x2
mi test x1 = x2

* Margins with MI
mi estimate, saving(m1): regress y i.group##c.x
mi margins group
```

### Diagnostics

```stata
* Check patterns before imputation
misstable patterns
misstable summarize

* After imputation, check if reasonable
mi xeq 0: summarize var1 var2      // Original data
mi xeq 1/5: summarize var1 var2    // First 5 imputations

* Check convergence
mi impute chained (...), savetrace(trace, replace)
use trace, clear
tsset iter
tsline *_mean  // Should stabilize quickly
```

**Key Rules**:
1. Never impute outcome variable (only predictors)
2. Use M=20-50 imputations (check FMI in results)
3. Include auxiliary variables that predict missingness
4. Use PMM for robustness (instead of regress)
5. Set seed for reproducibility
6. Validate: imputed values should be plausible

---

## Regex Patterns (Advanced String Operations)

```stata
* Test if matches pattern
generate has_email = regexm(text, "[a-zA-Z0-9]+@[a-zA-Z0-9]+\.[a-z]+")

* Extract matched text
generate email = regexs(0) if regexm(text, "[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-z]+")

* Replace with regex
generate clean = regexr(text, "[^a-zA-Z0-9 ]", "")  // Remove special chars

* Common patterns
local email "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
local phone "^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$"
local url "https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/[^\s]*)?"
local date_ymd "[0-9]{4}-[0-9]{2}-[0-9]{2}"
```

---

## Date/Time Operations

```stata
* Create dates from components
generate date = mdy(month, day, year)
format date %td

* From strings
generate date = date("2024-01-15", "YMD")  // or "MDY", "DMY"
format date %td

* Extract components
generate year = year(date)
generate month = month(date)
generate day = day(date)
generate dow = dow(date)           // Day of week (0=Sunday)

* Date arithmetic
generate tomorrow = date + 1
generate days_diff = date2 - date1
generate age_years = (today - birth_date) / 365.25

* Time series dates
generate month_var = monthly("2024-01", "YM")
format month_var %tm

generate quarter_var = quarterly("2024-Q1", "YQ")
format quarter_var %tq
```

---

## Bootstrap & Simulation Quick Reference

```stata
* Monte Carlo simulation
program define sim_program, rclass
    drop _all
    set obs 100
    generate x = rnormal()
    generate y = 2*x + rnormal()
    regress y x
    return scalar beta = _b[x]
end

simulate beta=r(beta), reps(1000) seed(12345): sim_program

* Bootstrap
bootstrap _b, reps(1000) seed(12345): regress y x1 x2

* Clustered bootstrap
bootstrap _b, reps(500) cluster(id) seed(12345): regress y x

* Power analysis
power twomeans 10 12, sd(5) n(100)
```

**Key Rules**:
- Always set seed for reproducibility
- M=1000+ for Monte Carlo, 500+ for bootstrap
- Use cluster bootstrap for panel data
- Use wild bootstrap for heteroskedasticity

---

## Dynamic Documents Quick Reference

```stata
* Markdown + Stata (dyndoc)
<<dd_do>>
sysuse auto, clear
regress mpg weight
<</dd_do>>

The R-squared is <<dd_display: %5.4f e(r2)>>.

<<dd_graph: height(400)>>

* Process: dyndoc report.md, replace

* Word document (putdocx)
putdocx clear
putdocx begin
putdocx paragraph, style(Heading1)
putdocx text ("Title")
putdocx table tbl1 = etable
putdocx save "report.docx", replace

* Excel (putexcel)
putexcel set "results.xlsx", replace
putexcel A1 = "Variable"
putexcel B1 = "Mean"
putexcel A1:B1, bold
putexcel B2 = r(mean), nformat(number_d2)

* PDF (putpdf)
putpdf clear
putpdf begin
putpdf paragraph
putpdf text ("PDF content")
putpdf save "report.pdf", replace
```

**When to use**:
- dyndoc: Technical reports, version control friendly
- putdocx: Client reports, manuscripts
- putexcel: Data tables, dashboards
- putpdf: Publication-ready documents

---

## Debugging Quick Reference

```stata
* Enable trace
set trace on
mycommand args
set trace off

* Add pause for inspection
pause on
pause                  // Stops here, type "end" to continue
pause off

* Timer to find bottlenecks
timer clear
timer on 1
// slow code section
timer off 1
timer list

* Conditional breakpoint
if r(N) > 0 {
    display "Found issue"
    pause on
    list problematic_cases
    pause
    pause off
}

* Assert for validation
assert !missing(id)
assert inrange(x, 0, 100)
```

---

## Summary: Critical Success Factors

1. **Always use**: `version 18.0`, `set varabbrev off`, `marksample touse`, `set seed`
2. **Test**: Edge cases, error handling, reproducibility (use `assert`)
3. **Document**: Help file, examples, return values
4. **Validate**: All inputs, sanitize file paths, check ranges
5. **Optimize**: Vectorize, use Mata for intensive operations
6. **Organize**: Clear project structure, version control, master script
7. **Security**: Validate inputs, never execute user strings, check files
8. **Paths**: Forward slashes, always quote, use globals
9. **Debug**: Trace, checkpoints, inspect data, test incrementally
10. **Avoid**: Top 10 pitfalls listed above
11. **Factor variables**: Use `i.`, `##` for interactions in regressions
12. **Panel data**: Always `xtset` first, use `fe/re`, check Hausman
13. **Graphics**: High-res exports, white background, clear schemes
14. **Import**: Handle encoding, mixed types, validate after import
15. **Missing data**: MI with PMM, M=20-50, never impute outcome
16. **Mata**: Use for intensive loops, matrix ops; `st_view()` not `st_data()`
17. **Simulation**: Always set seed, sufficient reps, save intermediate results
18. **Dynamic docs**: Reproducible reports, no manual copy-paste
19. **Performance**: Profile first, vectorize, avoid row-by-row operations
20. **Classes**: For code reuse, complex objects, OOP design

---

**End of Stata Coding Guide for Claude**

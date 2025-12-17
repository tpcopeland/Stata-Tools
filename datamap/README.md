# datamap

![Stata 16+](https://img.shields.io/badge/Stata-16%2B-brightgreen)
![MIT License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Status-Active-success)

Privacy-safe dataset documentation and Markdown data dictionaries for Stata.

## Description

The **datamap** package provides two complementary commands for documenting Stata datasets:

1. **datamap** - Generates comprehensive, privacy-safe text documentation of datasets with automatic variable classification and privacy controls
2. **datadict** - Creates professional Markdown data dictionaries optimized for GitHub, documentation systems, and conversion to other formats

Both commands are designed for researchers who need to document datasets for sharing, archiving, IRB compliance, or collaboration while protecting sensitive information.

## Package Contents

| Command | Purpose | Output Format |
|---------|---------|---------------|
| **datamap** | Privacy-safe dataset documentation with statistics | Plain text (.txt) |
| **datadict** | Professional data dictionaries for documentation | Markdown (.md) |

## Key Features

**Privacy controls:**
- Exclude sensitive variables from documentation
- Date-safe mode to protect date-based identifiers
- Suppress detailed statistics or frequencies
- Automatic classification of variable types

**Flexible input modes:**
- Document single datasets
- Scan entire directories
- Process lists of datasets from text files
- Recursive directory scanning

**Multiple output options:**
- Combined documentation for all datasets
- Separate files for each dataset
- Append to existing documentation
- Customizable formatting and metadata

## Dependencies

None - both commands use only built-in Stata functionality.

## Installation

```stata
net install datamap, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datamap")
```

This installs both `datamap` and `datadict` commands.

## Quick Start

```stata
* Generate privacy-safe documentation
datamap, single(mydata.dta) exclude(patient_id patient_name) datesafe

* Create Markdown data dictionary
datadict, single(mydata.dta) title("Study Dataset") author("Research Team")
```

---

# Command 1: datamap

Generate comprehensive, privacy-safe documentation for Stata datasets in plain text format.

## Description

`datamap` is designed for researchers who need to share dataset descriptions without revealing sensitive information. It automatically classifies variables as categorical, continuous, date, string, or excluded, and generates appropriate documentation for each type with comprehensive privacy controls.

The command is ideal for:
- IRB submissions requiring dataset documentation
- Data sharing agreements
- Archival documentation
- Collaboration with external researchers
- Dataset codebooks for team members

## Syntax

```stata
datamap, input_option [options]
```

### Input options (choose one required)

| Option | Description |
|--------|-------------|
| **single(filename)** | Document a single Stata dataset (.dta file) |
| **directory(path)** | Document all .dta files in a directory |
| **filelist(filename)** | Document datasets listed in a text file (one per line) |

## Options

### Output control

| Option | Description | Default |
|--------|-------------|---------|
| **output(filename)** | Name of output file | datamap.txt |
| **format(format)** | Output format (currently only text supported) | text |
| **separate** | Create separate output file for each dataset | Single combined file |
| **append** | Append to existing output file | Replace file |

### Privacy controls

| Option | Description | Default |
|--------|-------------|---------|
| **exclude(varlist)** | Exclude specified variables from documentation | None excluded |
| **datesafe** | Show only date ranges, not individual values | Show frequencies |

### Content controls

| Option | Description | Default |
|--------|-------------|---------|
| **nostats** | Suppress summary statistics for continuous variables | Show statistics |
| **nofreq** | Suppress frequency tables for categorical variables | Show frequencies |
| **nolabels** | Suppress value label definitions | Show labels |
| **nonotes** | Suppress dataset notes | Show notes |

### Parameters

| Option | Description | Default |
|--------|-------------|---------|
| **maxfreq(#)** | Maximum unique values to show frequencies for | 25 |
| **maxcat(#)** | Maximum unique values to classify as categorical | 25 |

### Detection features

| Option | Description | Default |
|--------|-------------|---------|
| **detect(options)** | Enable specific detection features (panel, binary, survival, survey, common) | None |
| **autodetect** | Enable all detection features | Disabled |
| **panelid(varname)** | Specify panel ID variable for panel detection | Auto-detect |
| **survivalvars(varlist)** | Specify survival analysis variables | Auto-detect |

### Data quality

| Option | Description | Default |
|--------|-------------|---------|
| **quality** | Enable basic data quality checks | Disabled |
| **quality2(strict)** | Enable strict data quality checks | Disabled |
| **missing(option)** | Missing data analysis (detail or pattern) | None |

### Sample data

| Option | Description | Default |
|--------|-------------|---------|
| **samples(#)** | Include # sample observations in output | 0 |

### Advanced

| Option | Description | Default |
|--------|-------------|---------|
| **recursive** | Scan subdirectories recursively (with directory option) | Current level only |

## Variable Classification

`datamap` automatically classifies variables based on type, format, and cardinality:

### Classification hierarchy

1. **Excluded** - Variables in the `exclude()` list
   - Listed but no values or statistics shown
   - Use for: PII, patient IDs, names, addresses, SSNs

2. **String** - String variables (str#)
   - Shows unique value count and examples (if not excluded)
   - Useful for: text fields, comments, categorical text

3. **Date** - Variables with date formats (%t*)
   - Shows date ranges (min/max)
   - With `datesafe`: only ranges shown, no individual values
   - Use for: dates of birth, visit dates, event dates

4. **Categorical** - Numeric variables with value labels or ≤ maxcat unique values
   - Shows frequency tables and value labels
   - Use for: coded categories, Likert scales, yes/no variables

5. **Continuous** - All other numeric variables
   - Shows summary statistics (mean, SD, min, max, percentiles)
   - Use for: age, BMI, lab values, scores

### Customizing classification

Adjust the `maxcat()` parameter to control the categorical threshold:

```stata
* Treat variables with ≤10 unique values as categorical
datamap, single(data.dta) maxcat(10)

* Higher threshold for data with many categories
datamap, single(survey.dta) maxcat(50)
```

## Input Modes

### Mode 1: Single file

Document a specific dataset:

```stata
datamap, single(patients.dta)
datamap, single("C:/Data/My Files/study.dta")
```

### Mode 2: Directory scan

Document all .dta files in a directory:

```stata
* Current directory
datamap, directory(.)

* Specific directory
datamap, directory("C:/Data/Study Files")

* Recursive scan including subdirectories
datamap, directory(.) recursive
```

### Mode 3: File list

Create a text file listing dataset paths (one per line):

```
* datasets.txt
baseline.dta
followup_6mo.dta
followup_12mo.dta
* This is a comment
final.dta
```

Then document all listed datasets:

```stata
datamap, filelist(datasets.txt)
```

Lines starting with `*` are treated as comments and ignored.

## Privacy Best Practices

### Direct identifiers

Always exclude direct identifiers:

```stata
datamap, single(patients.dta) ///
    exclude(patient_id patient_name ssn address phone email)
```

### Date-based identifiers

Use `datesafe` for datasets with dates that could identify individuals:

```stata
datamap, single(patients.dta) ///
    exclude(patient_id patient_name) ///
    datesafe
```

This shows only date ranges (earliest to latest) without individual values.

### High-cardinality variables

For variables with many unique values that might be identifying:

```stata
datamap, single(patients.dta) ///
    exclude(patient_id zip_code medical_record_number) ///
    maxfreq(10)
```

Variables with more than 10 unique values won't show detailed frequencies.

### Minimal documentation mode

For maximum privacy, suppress all statistics and frequencies:

```stata
datamap, single(patients.dta) ///
    exclude(patient_id patient_name dob ssn) ///
    nostats nofreq nolabels
```

This creates a minimal variable list with types only.

## Output Formats

### Combined output (default)

All datasets documented in a single file:

```stata
datamap, directory(.) output(all_datasets.txt)
```

### Separate files

Each dataset gets its own file:

```stata
datamap, directory(.) separate
```

Output files are named: `datasetname_map.txt`

### Appending

Add to existing documentation:

```stata
datamap, single(new_data.dta) output(documentation.txt) append
```

## Examples

### Example 1: Basic dataset documentation

```stata
datamap, single(patients.dta)
```

Creates `datamap.txt` with complete documentation of all variables.

### Example 2: Privacy-protected documentation

```stata
datamap, single(patients.dta) ///
    exclude(patient_id patient_name ssn date_of_birth) ///
    datesafe ///
    output(safe_documentation.txt)
```

Excludes PII and uses date-safe mode for remaining date variables.

### Example 3: Document entire project

```stata
datamap, directory("C:/Project/Data") ///
    recursive ///
    separate ///
    exclude(id name ssn)
```

Scans all subdirectories and creates separate documentation file for each dataset.

### Example 4: Minimal documentation

```stata
datamap, single(patients.dta) ///
    nostats nofreq nolabels nonotes
```

Creates variable list with types only, no detailed information.

### Example 5: Custom classification thresholds

```stata
datamap, single(survey.dta) ///
    maxcat(10) ///
    maxfreq(15) ///
    output(survey_docs.txt)
```

Classifies variables with ≤10 unique values as categorical; shows frequencies for variables with ≤15 unique values.

### Example 6: Clinical trial documentation

```stata
datamap, filelist(study_datasets.txt) ///
    exclude(subject_id site_id randomization_date) ///
    datesafe ///
    output(trial_documentation.txt)
```

Documents multiple trial datasets with privacy controls.

### Example 7: IRB submission package

```stata
datamap, directory(.) ///
    exclude(patient_identifier medical_record_number) ///
    datesafe ///
    maxfreq(20) ///
    output(IRB_dataset_documentation.txt)
```

Creates comprehensive documentation suitable for IRB submission.

### Example 8: Incremental documentation

```stata
* Document baseline data
datamap, single(baseline.dta) ///
    exclude(id name) ///
    output(study_docs.txt)

* Add followup data
datamap, single(followup.dta) ///
    exclude(id name) ///
    output(study_docs.txt) ///
    append
```

Builds documentation incrementally.

### Example 9: Data sharing documentation

```stata
datamap, single(analysis_data.dta) ///
    exclude(id institution investigator) ///
    datesafe nostats ///
    output(data_sharing_codebook.txt)
```

Creates documentation for external data sharing (no individual-level statistics).

### Example 10: Archive documentation

```stata
datamap, directory("../Archive") ///
    recursive separate ///
    output(archive_)
```

Documents archived datasets with separate files for each.

## Stored Results

`datamap` stores the following in `r()`:

**Scalars:**
- `r(nfiles)` - Number of datasets documented

**Macros:**
- `r(format)` - Output format used (text)
- `r(output)` - Name of output file created

## Use Cases

### IRB submissions

```stata
datamap, directory(.) ///
    exclude(patient_id mrn) ///
    datesafe ///
    output(IRB_codebook.txt)
```

### Data archiving

```stata
datamap, directory(.) recursive separate
```

### Collaboration

```stata
datamap, single(analysis.dta) ///
    exclude(id) ///
    output(data_description.txt)
```

### Quality control

```stata
datamap, single(cleaned_data.dta) ///
    output(QC_report.txt)
```

## Detection Features

`datamap` includes automatic detection of common data structures to help identify key variables and inform analysis planning.

### Available detection features

Enable specific features with `detect()` or all features with `autodetect`:

```stata
datamap, single(data.dta) detect(panel survival)
datamap, single(data.dta) autodetect
```

### Panel/longitudinal data detection

Detects repeated observations per unit and reports panel structure:

```stata
datamap, single(cohort.dta) detect(panel) panelid(patient_id)
```

Output includes:
- ID variable identified
- Number of unique units
- Average observations per unit

### Survival analysis detection

Identifies time-to-event and censoring variables:

```stata
datamap, single(survival_data.dta) detect(survival)
```

Output includes:
- Likely time variables (time, duration, followup)
- Likely event indicators (event, failure, death, status)
- Event rates and time ranges

### Survey design detection

Detects sampling weights, strata, and cluster variables:

```stata
datamap, single(survey.dta) detect(survey)
```

Output includes:
- Sampling weights with ranges
- Stratification variables and strata counts
- Clustering variables and PSU counts

### Binary variable detection

Identifies variables with exactly 2 unique values as potential outcomes:

```stata
datamap, single(analysis.dta) detect(binary)
```

Flags binary variables suitable for binary outcome models.

### Common pattern detection

Identifies common variable naming patterns:

```stata
datamap, single(data.dta) detect(common)
```

Detects:
- ID variables (id, patient_id, subject)
- Date variables (date, dob, death)
- Outcome variables (outcome, death, event)
- Exposure variables (exposure, treatment, drug)
- Demographics (age, sex, gender, race)

## Data Quality Checks

Enable automatic flagging of potential data quality issues:

```stata
datamap, single(clinical.dta) quality
datamap, single(clinical.dta) quality2(strict)
```

### Basic quality checks

The `quality` option flags:
- Negative age values
- Ages > 120
- Negative counts
- Percentages outside 0-100 range

### Strict quality checks

The `quality2(strict)` option uses more conservative thresholds:
- Ages > 100 (instead of >120)
- Other checks as above

Quality flags appear in a dedicated section listing variables and issues found.

## Missing Data Analysis

Generate detailed missing data summaries:

```stata
datamap, single(study.dta) missing(detail)
datamap, single(study.dta) missing(pattern)
```

### Detail level

Shows:
- Count of variables with >50% missing
- Count of variables with >10% missing
- Number and percentage of complete cases

### Pattern level

Includes all detail-level information plus pattern analysis across variables.

## Sample Data Output

Include sample observations in output (use with caution):

```stata
datamap, single(demo_data.dta) samples(5) exclude(id name)
```

**Important:**
- Always combine with `exclude()` to mask sensitive variables
- Sample data may contain identifiable information
- Review output before sharing
- Excluded variables appear as [MASKED] in samples

---

# Command 2: datadict

Generate professional Markdown data dictionaries from Stata datasets.

## Description

`datadict` creates beautiful, professional data dictionaries in Markdown format. The output includes:
- Automatic table of contents
- Dataset metadata
- Formatted variable tables (Variable | Label | Type | Values/Notes)
- Value label definitions
- Customizable headers and footers
- Professional styling for GitHub and documentation systems

The command is ideal for:
- GitHub repository documentation
- Project documentation systems
- Conversion to PDF/HTML via Pandoc
- Team collaboration
- Publication supplements

## Syntax

```stata
datadict, input_option [options]
```

### Input options (choose one required)

| Option | Description |
|--------|-------------|
| **single(filename)** | Document a single .dta file |
| **directory(path)** | Document all .dta files in directory |
| **filelist(filename)** | Text file listing .dta files to process |
| **recursive** | Scan subdirectories when using directory() |

## Options

### Output control

| Option | Description | Default |
|--------|-------------|---------|
| **output(filename)** | Output markdown file | data_dictionary.md |
| **separate** | Create separate output file per dataset | Single combined file |

### Document metadata

| Option | Description | Default |
|--------|-------------|---------|
| **title(string)** | Document title | Data Dictionary |
| **subtitle(string)** | Subtitle or description line | None |
| **version(string)** | Version number for documentation | None |
| **author(string)** | Author name (can include markdown links) | None |
| **date(string)** | Date string | Current date |

### Content sections

| Option | Description | Default |
|--------|-------------|---------|
| **notes(filename)** | Path to text file with notes to append | Default notes |
| **changelog(filename)** | Path to text file with changelog to append | None |
| **missing** | Include missing n (%) column for each variable | Not included |
| **stats** | Include descriptive statistics column for each variable | Not included |

### Parameters

| Option | Description | Default |
|--------|-------------|---------|
| **maxcat(#)** | Maximum unique values to classify as categorical | 25 |
| **maxfreq(#)** | Maximum unique values to show frequencies for | 25 |

## Output Structure

The generated Markdown file includes:

1. **Title and metadata** - Document title, version, author, date
2. **Table of contents** - Automatic TOC with links to datasets
3. **Dataset sections** - One section per dataset containing:
   - Dataset name and metadata
   - Variable table (Variable | Label | Type | Values/Notes)
   - Value label definitions
4. **Notes section** - Information about date formats and missing values
5. **Change log** - Optional version history
6. **Footer** - Author and version information

## Variable Type Display

`datadict` formats variables based on their Stata type:

| Stata Type | Display | Example |
|------------|---------|---------|
| Numeric (no label) | Numeric | Numeric |
| Numeric (with label) | Numeric | Numeric (1=Yes, 2=No) |
| String | String | String |
| Date format | Date | Date (%td) |
| DateTime format | DateTime | DateTime (%tc) |

### Value labels

**For variables with ≤15 categories:**
- Shows all values inline: `Numeric (1=Strongly disagree, 2=Disagree, 3=Neutral, 4=Agree, 5=Strongly agree)`

**For variables with >15 categories:**
- Shows count only: `Numeric (87 categories - see value labels below)`
- Full mapping appears in Value Labels section

## Markdown Features

The output uses standard Markdown features:

- **Tables** - GitHub-flavored Markdown tables with alignment
- **Headers** - Hierarchical section headers (##, ###)
- **Links** - Table of contents with anchor links
- **Code blocks** - Formatted dataset names and paths
- **Emphasis** - Bold for headers, italic for metadata

The output renders beautifully on:
- GitHub
- GitLab
- Bitbucket
- MkDocs
- Sphinx
- Jekyll
- Any Markdown renderer

## Conversion to Other Formats

Use Pandoc to convert to other formats:

```bash
# Convert to PDF
pandoc data_dictionary.md -o data_dictionary.pdf

# Convert to HTML
pandoc data_dictionary.md -o data_dictionary.html

# Convert to Word
pandoc data_dictionary.md -o data_dictionary.docx

# Convert to PDF with table of contents
pandoc data_dictionary.md --toc -o data_dictionary.pdf
```

## Enhanced Output Options

### Missing data column

Add a Missing column showing count and percentage of missing values:

```stata
datadict, single(patients.dta) missing
```

Variable table includes: Variable | Label | Type | Missing | Values/Notes

### Statistics column

Add descriptive statistics based on variable classification:

```stata
datadict, single(patients.dta) stats
```

Statistics shown by type:
- **Categorical:** Value frequencies (e.g., "1=Male, 2=Female")
- **Continuous:** Mean, SD, and range (e.g., "Mean=45.2; SD=12.3; Range=18-89")
- **Date:** Date range (e.g., "Range: 01jan2020 to 31dec2023")
- **String:** Count of unique values

### Both missing and statistics

Combine both options for comprehensive variable information:

```stata
datadict, single(patients.dta) missing stats
```

Variable table includes: Variable | Label | Type | Missing | Statistics/Values

### Customizing classification thresholds

Control how variables are classified:

```stata
* Classify variables with ≤10 unique values as categorical
datadict, single(data.dta) maxcat(10)

* Show frequencies for up to 50 categories
datadict, single(survey.dta) maxfreq(50)
```

## Examples

### Example 1: Basic data dictionary

```stata
datadict, single(patients.dta)
```

Creates `data_dictionary.md` with default settings.

### Example 2: Custom title and metadata

```stata
datadict, single(patients.dta) ///
    output(patient_dict.md) ///
    title("Patient Registry Data Dictionary") ///
    version("1.0") ///
    author("Research Team") ///
    subtitle("Clinical trial baseline data")
```

Creates a professionally formatted dictionary with custom metadata.

### Example 3: Document entire project

```stata
datadict, directory(.) ///
    output(project_dictionary.md) ///
    title("Project Data Documentation") ///
    author("Jane Doe")
```

Combines all datasets in current directory into one dictionary.

### Example 4: Separate dictionaries per dataset

```stata
datadict, directory(.) ///
    recursive ///
    separate ///
    title("Study Data")
```

Creates individual `datasetname_dictionary.md` files for each dataset.

### Example 5: GitHub documentation

```stata
datadict, directory(.) ///
    output(DATA_DICTIONARY.md) ///
    title("Repository Data Files") ///
    subtitle("Last updated: 2025-11-27") ///
    author("[Research Team](https://example.com)")
```

Creates a dictionary for a GitHub repository with hyperlinked author.

### Example 6: Documentation with changelog

Create `changelog.txt`:
```
## Version 1.1 (2025-11-27)
- Added follow-up visit data
- Updated variable labels for clarity

## Version 1.0 (2025-10-01)
- Initial data dictionary release
```

Then generate:
```stata
datadict, single(study.dta) ///
    version("1.1") ///
    changelog(changelog.txt)
```

### Example 7: Custom notes

Create `custom_notes.txt`:
```
## Data Collection Notes

- All data collected using REDCap
- Missing values coded as .a (not applicable), .b (refused), .c (don't know)
- Date variables represent visit dates, not dates of birth
- All continuous variables checked for outliers
```

Then generate:
```stata
datadict, single(study.dta) ///
    notes(custom_notes.txt)
```

### Example 8: Multiple datasets from file list

Create `datasets.txt`:
```
data/baseline.dta
data/followup_6mo.dta
data/followup_12mo.dta
data/final.dta
```

Then generate:
```stata
datadict, filelist(datasets.txt) ///
    output(longitudinal_dictionary.md) ///
    title("Longitudinal Study Data") ///
    version("2.0") ///
    author("Study Team")
```

### Example 9: MkDocs documentation

```stata
datadict, directory(../data) ///
    output(docs/data_dictionary.md) ///
    title("Data Files") ///
    subtitle("Documentation for project data files")
```

Outputs directly to MkDocs documentation directory.

### Example 10: Publication supplement

```stata
datadict, single(analysis_data.dta) ///
    output(Supplementary_Data_Dictionary.md) ///
    title("Supplementary Material: Data Dictionary") ///
    subtitle("Analysis dataset for manuscript XYZ-2025") ///
    version("1.0") ///
    author("Authors et al. (2025)")
```

Creates a data dictionary suitable for journal supplementary materials.

### Example 11: Versioned documentation

```stata
local version "2.1"
local today : display %tdCY-N-D date(c(current_date), "DMY")

datadict, single(data.dta) ///
    output(dictionary_v`version'.md) ///
    title("Study Data Dictionary") ///
    version("`version'") ///
    date("`today'")
```

Automatically incorporates version numbers and current date.

### Example 12: Multi-site study

```stata
datadict, directory("../data/sites") ///
    recursive ///
    separate ///
    title("Site Data") ///
    author("Coordinating Center")
```

Creates separate dictionaries for each site's data files.

### Example 13: Enhanced dictionary with missing data and statistics

```stata
datadict, single(clinical_trial.dta) ///
    output(comprehensive_dict.md) ///
    title("Clinical Trial Data Dictionary") ///
    version("1.0") ///
    missing stats ///
    author("Study Team")
```

Includes both missing data percentages and descriptive statistics for all variables.

### Example 14: Custom thresholds for survey data

```stata
datadict, single(survey_responses.dta) ///
    output(survey_dict.md) ///
    stats ///
    maxcat(10) ///
    maxfreq(50) ///
    title("Survey Data Dictionary")
```

Classifies variables with ≤10 unique values as categorical and shows frequencies for up to 50 categories.

## Stored Results

`datadict` stores the following in `r()`:

**Scalars:**
- `r(nfiles)` - Number of datasets documented

**Macros:**
- `r(output)` - Output filename

## Markdown Best Practices

### File naming

Use descriptive names:
- `README.md` - Main documentation
- `DATA_DICTIONARY.md` - Dataset reference
- `CODEBOOK.md` - Alternative name
- `docs/data.md` - For documentation systems

### Integration with GitHub

Add to repository root or `docs/` folder:

```stata
datadict, directory(data) ///
    output(DATA_DICTIONARY.md) ///
    title("Dataset Documentation")
```

Link from your main README.md:
```markdown
## Data

See [DATA_DICTIONARY.md](DATA_DICTIONARY.md) for detailed variable descriptions.
```

### Version control

Include in git commits:
```bash
git add DATA_DICTIONARY.md
git commit -m "Update data dictionary for version 2.0"
```

## Use Cases

### Open source projects

```stata
datadict, directory(data) ///
    output(docs/DATA.md) ///
    title("Project Datasets") ///
    author("[Contributors](CONTRIBUTORS.md)")
```

### Academic research

```stata
datadict, single(analysis.dta) ///
    output(supplementary_codebook.md) ///
    title("Supplementary Codebook") ///
    version("1.0")
```

### Team collaboration

```stata
datadict, directory(.) ///
    recursive ///
    output(team_documentation.md) ///
    title("Team Data Files") ///
    author("Data Management Team")
```

### Institutional repositories

```stata
datadict, filelist(datasets.txt) ///
    output(repository_dictionary.md) ///
    title("Data Archive Documentation") ///
    version("1.0") ///
    author("Archive Team")
```

---

# Comparison: datamap vs datadict

Choose the right command for your needs:

## Use datamap when you need:

- Privacy-safe documentation with exclusion controls
- Plain text output for IRB submissions
- Date-safe mode for protecting identifiers
- Summary statistics and frequency tables
- Content controls (suppress stats/frequencies)
- Traditional codebook format

## Use datadict when you need:

- Professional Markdown documentation
- GitHub/GitLab repository documentation
- Integration with documentation systems (MkDocs, Sphinx)
- Conversion to PDF/HTML/Word via Pandoc
- Beautiful rendered output
- Version control friendly format
- Publication supplements

## Combined workflow

Use both commands together for comprehensive documentation:

```stata
* Privacy-safe documentation for IRB
datamap, single(data.dta) ///
    exclude(id name dob) ///
    datesafe ///
    output(IRB_submission.txt)

* Public-facing documentation for GitHub
datadict, single(data.dta) ///
    output(DATA_DICTIONARY.md) ///
    title("Public Dataset Documentation")
```

---

# Package Information

## Requirements

- Stata 16.0 or higher
- No external dependencies

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/datamap
net install datamap
```

## Version History

- **Version 1.0.1** (3 December 2025): Added version statements to all helper programs for Stata version compatibility
- **Version 1.0.0** (2 December 2025): GitHub publication release

## Author

Timothy P Copeland<br>
Department of Clinical Neuroscience<br>
Karolinska Institutet

## License

MIT License

## Support

For detailed help on each command:

```stata
help datamap
help datadict
```

For issues or feature requests, please contact the author or visit the GitHub repository.

## See Also

**Stata commands:**
- `describe` - Basic variable descriptions
- `codebook` - Detailed codebook information
- `labelbook` - Value label documentation

**External tools:**
- Pandoc - Convert Markdown to other formats
- MkDocs - Documentation site generator
- Sphinx - Documentation builder

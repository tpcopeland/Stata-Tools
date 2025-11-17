# Comprehensive Guide to Synthetic Data Generation in Stata

## Table of Contents
1. [Introduction and Purpose](#introduction-and-purpose)
2. [When to Use Synthetic Data](#when-to-use-synthetic-data)
3. [Core Principles](#core-principles)
4. [Basic Techniques](#basic-techniques)
5. [Advanced Techniques](#advanced-techniques)
6. [Privacy and Confidentiality](#privacy-and-confidentiality)
7. [Validation and Quality Checks](#validation-and-quality-checks)
8. [Common Patterns and Examples](#common-patterns-and-examples)
9. [Pitfalls to Avoid](#pitfalls-to-avoid)
10. [Performance Considerations](#performance-considerations)

---

## Introduction and Purpose

Synthetic data generation in Stata serves multiple critical purposes:
- **Testing and Development**: Create realistic test datasets without exposing sensitive information
- **Reproducible Examples**: Generate example datasets for documentation, help files, and tutorials
- **Privacy Protection**: Share data structures while protecting confidential information
- **Simulation Studies**: Create datasets with known properties to test statistical methods
- **Teaching**: Provide students with realistic but fictional data

**Key Principle**: Synthetic data should preserve the statistical properties and relationships of real data while ensuring no actual observations can be re-identified.

---

## When to Use Synthetic Data

### Appropriate Use Cases
1. **Restricted Data Scenarios**: When working with protected health information, confidential business data, or classified information
2. **Package Development**: Creating examples for ado files and help documentation
3. **Methodological Research**: Testing statistical methods with known data-generating processes
4. **Educational Materials**: Teaching statistical concepts without privacy concerns
5. **Collaborative Research**: Sharing data structure and analysis code before real data is available

### When NOT to Use Synthetic Data
- **Final Analysis**: Never substitute synthetic data for real data in actual research
- **Publication**: Always use real data for published results (synthetic data only for examples)
- **Validation**: Cannot validate real-world hypotheses with purely synthetic data

---

## Core Principles

### 1. Preserve Statistical Properties
Your synthetic data should maintain:
- **Distributions**: Match univariate distributions (means, variances, skewness, kurtosis)
- **Correlations**: Preserve relationships between variables
- **Covariance Structure**: Maintain multivariate relationships
- **Missing Data Patterns**: Replicate missing data mechanisms if relevant

### 2. Ensure Privacy Protection
- **k-Anonymity**: Ensure groups of similar records exist
- **Differential Privacy**: Add controlled noise to prevent re-identification
- **Avoid Outliers**: Extreme values may be identifiable in real data

### 3. Match Data Types and Constraints
- **Categorical Variables**: Preserve categories and their frequencies
- **Continuous Variables**: Match ranges and distributions
- **Constraints**: Respect logical constraints (e.g., age at death ≥ age at birth)
- **Temporal Patterns**: Maintain time series properties if applicable

### 4. Document Everything
- Always include comments explaining the data generation process
- Document assumptions about distributions and relationships
- Note any deviations from real data patterns
- Provide seed values for reproducibility

---

## Basic Techniques

### Setting the Foundation

```stata
* Always start with a clear workspace and set seed for reproducibility
clear all
set seed 12345  // Use a fixed seed for reproducibility

* Set number of observations
set obs 1000
```

### Generating ID Variables

```stata
* Simple sequential ID
generate id = _n

* ID with gaps (e.g., simulating attrition)
generate id = _n * 2 if runiform() > 0.1

* Multi-level IDs (e.g., students within schools)
generate school_id = ceil(_n / 30)  // 30 students per school
bysort school_id: generate student_id = _n
```

### Generating Categorical Variables

```stata
* Binary variable (50/50 split)
generate female = runiform() > 0.5

* Binary with specific probability
generate treatment = runiform() < 0.3  // 30% treatment

* Categorical variable with equal probabilities
generate region = ceil(runiform() * 4)  // 4 regions
label define region_lbl 1 "North" 2 "South" 3 "East" 4 "West"
label values region region_lbl

* Categorical with specific probabilities
generate temp = runiform()
generate education = 1 if temp < 0.2          // 20% less than HS
replace education = 2 if temp >= 0.2 & temp < 0.5  // 30% HS
replace education = 3 if temp >= 0.5 & temp < 0.8  // 30% some college
replace education = 4 if temp >= 0.8          // 20% college+
drop temp
label define educ_lbl 1 "Less than HS" 2 "HS" 3 "Some College" 4 "College+"
label values education educ_lbl
```

### Generating Continuous Variables

```stata
* Uniform distribution
generate random_uniform = runiform()  // [0,1)
generate age = 18 + runiform() * 62   // Uniform between 18 and 80

* Normal distribution
generate iq = 100 + rnormal() * 15    // Mean 100, SD 15

* Exponential distribution
generate wait_time = -ln(runiform()) * 10  // Mean 10

* Log-normal distribution (for income, wealth, etc.)
generate income = exp(rnormal(10.5, 0.7))  // Log-normal distribution

* Rounded/discretized continuous
generate age_years = floor(18 + runiform() * 62)

* Bounded normal (truncated)
generate test_score = rnormal(75, 10)
replace test_score = 0 if test_score < 0
replace test_score = 100 if test_score > 100
```

### Generating Date Variables

```stata
* Random dates within a range
generate random_date = mdy(1, 1, 2020) + floor(runiform() * 365)
format random_date %td

* Birth dates creating realistic age distribution
generate birth_year = 1945 + floor(rchi2(2) * 5)  // Skewed toward younger
generate birth_month = ceil(runiform() * 12)
generate birth_day = ceil(runiform() * 28)  // Avoid invalid dates
generate birth_date = mdy(birth_month, birth_day, birth_year)
format birth_date %td

* Event dates with survival pattern
generate event_time = -ln(runiform()) / 0.1  // Exponential hazard
generate event_date = mdy(1, 1, 2020) + floor(event_time)
format event_date %td
```

---

## Advanced Techniques

### Creating Correlated Variables

```stata
* Two correlated normal variables
clear
set obs 1000
set seed 12345

* Generate base variables
generate z1 = rnormal()
generate z2 = rnormal()

* Create correlation of approximately 0.7
local rho = 0.7
generate x = z1
generate y = `rho' * z1 + sqrt(1 - `rho'^2) * z2

* Verify correlation
corr x y

* Create multiple correlated variables using Cholesky decomposition
matrix C = (1, 0.5, 0.3 \ 0.5, 1, 0.6 \ 0.3, 0.6, 1)
matrix L = cholesky(C)

generate u1 = rnormal()
generate u2 = rnormal()
generate u3 = rnormal()

generate v1 = L[1,1]*u1
generate v2 = L[2,1]*u1 + L[2,2]*u2
generate v3 = L[3,1]*u1 + L[3,2]*u2 + L[3,3]*u3

corr v1 v2 v3  // Check correlation structure
```

### Creating Realistic Panel Data

```stata
clear
set obs 500  // 500 individuals
set seed 54321

* Generate individual IDs
generate id = _n

* Individual-level characteristics (time-invariant)
generate female = runiform() > 0.5
generate ability = rnormal()  // Unobserved ability

* Expand to create panel
expand 10  // 10 time periods per individual
bysort id: generate time = _n

* Generate time-varying variables with individual effects
bysort id: generate experience = time - 1 + floor(rnormal(0, 1))
replace experience = max(0, experience)  // Non-negative

* Generate outcome with individual fixed effect
generate log_wage = 2.5 + 0.05*experience + 0.3*female ///
                    + ability + rnormal(0, 0.2)
generate wage = exp(log_wage)

* Add attrition (dropout over time)
bysort id: generate dropout = time > 5 & runiform() < 0.1
bysort id: replace dropout = 1 if dropout[_n-1] == 1 & _n > 1
drop if dropout

* Declare panel structure
xtset id time
```

### Using Mata for Complex Distributions

```stata
clear
set obs 1000
set seed 99999

* Generate multivariate normal with specific covariance
mata:
    n = 1000
    mu = (50, 60, 70)  // Means
    Sigma = (100, 40, 30 \ 40, 100, 50 \ 30, 50, 100)  // Covariance
    L = cholesky(Sigma)
    Z = rnormal(n, 3, 0, 1)
    X = Z * L' :+ mu
    st_store(., st_addvar("double", ("var1", "var2", "var3")), X)
end

summarize var1 var2 var3
correlate var1 var2 var3
```

### Using Multiple Imputation for Synthetic Data

```stata
* Load real data (or summary statistics)
* Suppose we have real data and want to create synthetic version

clear
set obs 1000
set seed 77777

* Create initial variables
generate age = 30 + rnormal() * 10
generate income = exp(9 + 0.05*age + rnormal(0, 0.5))

* Deliberately create missing pattern similar to real data
generate temp = runiform()
replace age = . if temp < 0.1
replace income = . if temp < 0.15

* Use multiple imputation to create synthetic complete dataset
mi set wide
mi register imputed age income

mi impute chained ///
    (regress) age ///
    (regress) income ///
    = , add(5) rseed(123)

* Extract one imputed dataset as synthetic data
mi extract 1, clear
```

### Creating Nested/Hierarchical Data

```stata
clear
set obs 50  // 50 clusters (e.g., hospitals)
set seed 11111

* Cluster-level variables
generate cluster_id = _n
generate cluster_size = 10 + floor(rpoisson(20))  // Variable cluster sizes
generate cluster_quality = rnormal(0, 1)  // Cluster-level effect

* Expand to individuals within clusters
expand cluster_size
bysort cluster_id: generate person_id = _n

* Individual-level variables correlated with cluster
generate individual_error = rnormal(0, 1)
generate outcome = 50 + 5*cluster_quality + individual_error

* Add covariates
generate age = 40 + rnormal(0, 15)
replace age = max(18, min(95, age))  // Constrain to reasonable range

* Declare cluster structure
egen cluster_num = group(cluster_id)
```

### Generating Survey Data with Sampling Weights

```stata
clear
set obs 10000  // True population
set seed 22222

* Population characteristics
generate age = 18 + floor(rchi2(4) * 10)  // Skewed age distribution
generate urban = runiform() < 0.75  // 75% urban
generate income = exp(9.5 + 0.02*age + 0.3*urban + rnormal(0, 0.6))

* Stratified sampling (oversample certain groups)
generate sample_prob = 0.1  // Base 10% sampling rate
replace sample_prob = 0.3 if age > 65  // Oversample elderly
replace sample_prob = 0.2 if urban == 0  // Oversample rural

* Draw sample
generate selected = runiform() < sample_prob
keep if selected

* Create sampling weights (inverse probability)
generate weight = 1 / sample_prob

* Verify weighted estimates match population
* (In real scenario, you'd compare to known population values)
mean age [pweight=weight]
```

---

## Privacy and Confidentiality

### Differential Privacy Approach

```stata
* Add calibrated noise to preserve privacy
clear
set obs 1000
set seed 33333

* Original sensitive data (simulated)
generate true_income = exp(rnormal(11, 0.7))

* Add Laplace noise for differential privacy
* Epsilon controls privacy level (smaller = more private)
local epsilon = 1
local sensitivity = 10000  // Maximum change in one record
local laplace_scale = `sensitivity' / `epsilon'

generate u = runiform()
generate laplace_noise = -`laplace_scale' * sign(u - 0.5) * ln(1 - 2*abs(u - 0.5))
generate private_income = true_income + laplace_noise

* Ensure non-negative
replace private_income = max(0, private_income)
```

### k-Anonymity Implementation

```stata
* Ensure each combination of quasi-identifiers appears at least k times
clear
set obs 10000
set seed 44444

generate age = 20 + floor(runiform() * 60)
generate zip = 10000 + floor(runiform() * 90000)
generate gender = runiform() > 0.5

* Create age groups for k-anonymity
generate age_group = .
replace age_group = 1 if age < 30
replace age_group = 2 if age >= 30 & age < 50
replace age_group = 3 if age >= 50

* Check k-anonymity
bysort age_group zip gender: generate group_size = _N
summarize group_size, detail

* Remove groups smaller than k=5
local k = 5
drop if group_size < `k'
```

### Data Swapping Technique

```stata
* Swap values between similar records
clear
set obs 1000
set seed 55555

generate age = 30 + rnormal() * 10
generate income = exp(10 + 0.02*age + rnormal(0, 0.5))
generate zipcode = 10000 + floor(runiform() * 90000)

* Randomly swap zipcodes for 10% of records
generate swap_group = ceil(_n / 2) if runiform() < 0.1
bysort swap_group: generate swap_zip = zipcode[_N - _n + 1] if swap_group != .
replace zipcode = swap_zip if swap_zip != .
drop swap_group swap_zip
```

---

## Validation and Quality Checks

### Statistical Validation

```stata
* Compare synthetic data properties to target properties
* (Assuming you have target means, SDs, correlations from real data)

* Check univariate distributions
summarize age income education, detail
tabulate gender
tabulate region

* Check correlations
pwcorr age income education, star(0.05)

* Check cross-tabulations
tabulate education gender, chi2 expected
tabulate region urban, chi2

* Visual inspection
histogram age, normal
graph box income, over(education)
scatter income age

* Kolmogorov-Smirnov test against known distribution
ksmirnov age = normal((age - 45) / 15)  // Test if age ~ N(45, 15)
```

### Logical Consistency Checks

```stata
* Assert statements to verify data constraints
assert age >= 0 & age <= 120
assert income >= 0
assert !missing(id)
assert inrange(education, 1, 4)

* Verify relationships
assert date_death >= date_birth if !missing(date_death)
assert years_education <= age - 5
assert employed == 0 if age < 16 | age > 75

* Check for duplicates
duplicates report id
assert r(unique_value) == r(N)  // No duplicate IDs
```

### Utility Preservation Tests

```stata
* Ensure synthetic data produces similar analysis results
* Run same regression on real and synthetic data

* Synthetic data regression
regress outcome treatment age income education
estimates store synthetic_model

* Compare coefficients (ideally you'd have real data results to compare)
* Check if confidence intervals overlap
* Verify sign and approximate magnitude of coefficients

* Check prediction accuracy
predict yhat
correlate outcome yhat  // Should be reasonably high
```

---

## Common Patterns and Examples

### Example 1: Clinical Trial Data

```stata
clear all
set seed 2024
set obs 500

* Patient ID
generate patient_id = _n

* Baseline characteristics
generate age = 45 + rnormal() * 12
replace age = max(18, min(85, age))
generate female = runiform() > 0.45
generate bmi = 25 + rnormal() * 4
replace bmi = max(15, min(45, bmi))

* Comorbidities (correlated)
generate diabetes = runiform() < 0.25
generate hypertension = runiform() < (0.3 + 0.2*diabetes)
generate baseline_score = 60 + rnormal() * 15
replace baseline_score = max(0, min(100, baseline_score))

* Randomization (stratified by diabetes)
bysort diabetes: generate rand = runiform()
bysort diabetes: generate treatment = rand < 0.5
drop rand

* Follow-up measurements
expand 4  // 4 time points
bysort patient_id: generate visit = _n - 1  // 0, 1, 2, 3

* Generate outcome with treatment effect
generate treatment_effect = -10 if treatment == 1 & visit > 0
replace treatment_effect = 0 if missing(treatment_effect)

generate outcome = baseline_score + treatment_effect ///
                   - 2*visit ///  // Natural decline
                   + rnormal(0, 5)  // Measurement error

replace outcome = max(0, min(100, outcome))

* Add missing data (dropout more common in control group)
generate dropout_prob = 0.05 * visit
replace dropout_prob = dropout_prob * 1.5 if treatment == 0
bysort patient_id: generate dropped = runiform() < dropout_prob
bysort patient_id: replace dropped = 1 if dropped[_n-1] == 1 & _n > 1
replace outcome = . if dropped

* Add adverse events
generate adverse_event = runiform() < 0.02 if visit > 0

* Clean up
keep patient_id visit age female bmi diabetes hypertension ///
     treatment baseline_score outcome adverse_event
order patient_id visit

* Declare panel
xtset patient_id visit
```

### Example 2: Economic Panel Data

```stata
clear all
set seed 2025
set obs 1000

* Individual characteristics
generate individual_id = _n
generate education = 1 + floor(rchi2(3) * 2)  // 1-7 years of education
replace education = min(education, 18)
generate ability = rnormal()  // Unobserved ability

* Expand to yearly observations
expand 20  // 20 years
bysort individual_id: generate year = 1995 + _n - 1

* Time-varying characteristics
bysort individual_id: generate experience = max(0, year - 1995 - education - 6)
generate age = education + 6 + experience

* Labor market status
generate employed_prob = invlogit(-2 + 0.1*education + 0.05*experience + ability)
generate employed = runiform() < employed_prob

* Earnings (only when employed)
generate log_earnings = 9 + 0.08*education + 0.04*experience ///
                        - 0.001*experience^2 + 0.3*ability ///
                        + rnormal(0, 0.3) if employed
generate earnings = exp(log_earnings)
replace earnings = 0 if !employed

* Macroeconomic shocks
generate recession = inlist(year, 2001, 2008, 2009, 2020)
replace earnings = earnings * 0.9 if recession & employed

* Family structure (evolving over time)
generate married = runiform() < (0.1 + 0.03*age) & age >= 18
bysort individual_id: replace married = 1 if married[_n-1] == 1 & runiform() > 0.05
generate children = rpoisson(married * 1.5)

* Keep relevant variables
keep individual_id year age education experience employed earnings married children
order individual_id year

xtset individual_id year
```

### Example 3: Survey Data with Complex Design

```stata
clear all
set seed 1234
set obs 5000

* Geographic hierarchy
generate state = ceil(runiform() * 10)
bysort state: generate county = ceil(runiform() * 5)
egen psu = group(state county)

* Demographics with geographic variation
bysort state: egen state_income_mean = mean(10.5 + rnormal(0, 0.3))
generate log_income = state_income_mean + rnormal(0, 0.6)
generate income = exp(log_income)

generate age = 18 + floor(rchi2(5) * 8)
generate female = runiform() > 0.48
generate race = 1 if runiform() < 0.6
replace race = 2 if race == . & runiform() < 0.7
replace race = 3 if race == . & runiform() < 0.8
replace race = 4 if missing(race)

* Complex sampling design
generate selection_prob = 0.1
replace selection_prob = 0.2 if age >= 65  // Oversample elderly
replace selection_prob = 0.15 if race != 1  // Oversample minorities

generate in_sample = runiform() < selection_prob

* Sampling weights
generate weight = 1 / selection_prob if in_sample

* Design effects
bysort psu: egen cluster_effect = mean(rnormal(0, 1))

* Outcome with clustering
generate health_status = 3 + cluster_effect + rnormal(0, 1)
replace health_status = max(1, min(5, round(health_status)))

* Keep only sampled observations
keep if in_sample

* Set survey design
svyset psu [pweight=weight]
```

### Example 4: Time Series Data

```stata
clear all
set seed 7890

* Create monthly time series
set obs 240  // 20 years of monthly data
generate time = _n
generate date = ym(2005, 1) + _n - 1
format date %tm

* Trend component
generate trend = 100 + 0.5 * time

* Seasonal component (monthly)
generate month = mod(time - 1, 12) + 1
generate seasonal = 0
replace seasonal = 10 if inlist(month, 12, 1, 2)  // Winter peak
replace seasonal = -5 if inlist(month, 6, 7, 8)  // Summer dip

* Cyclical component (business cycle)
generate cycle = 15 * sin(2 * _pi * time / 48)  // 4-year cycle

* Random component (AR(1) process)
generate epsilon = rnormal() in 1
replace epsilon = 0.7 * epsilon[_n-1] + rnormal() in 2/L

* Combine components
generate value = trend + seasonal + cycle + epsilon

* Add structural break
replace value = value + 20 if time > 120  // Break at midpoint

* Add occasional outliers
replace value = value + rnormal(0, 30) if runiform() < 0.02

* Set as time series
tsset time
```

---

## Pitfalls to Avoid

### 1. Independence Violations
**WRONG:**
```stata
* Generating correlated outcomes without accounting for it
generate x = rnormal()
generate y = rnormal()  // Uncorrelated
regress y x  // Will show no relationship
```

**RIGHT:**
```stata
* Explicitly create correlation
generate x = rnormal()
generate y = 0.5*x + rnormal(0, sqrt(0.75))  // Correlation ≈ 0.5
regress y x  // Will show expected relationship
```

### 2. Unrealistic Distributions
**WRONG:**
```stata
* Using normal distribution for income
generate income = 50000 + rnormal() * 20000  // Can be negative!
```

**RIGHT:**
```stata
* Use log-normal for income
generate log_income = log(50000) + rnormal(0, 0.5)
generate income = exp(log_income)  // Always positive, right-skewed
```

### 3. Ignoring Constraints
**WRONG:**
```stata
* Independent dates
generate birth_date = mdy(1,1,1950) + floor(runiform()*25000)
generate hire_date = mdy(1,1,2000) + floor(runiform()*7300)
* hire_date could be before birth_date!
```

**RIGHT:**
```stata
* Respecting chronological constraints
generate birth_date = mdy(1,1,1950) + floor(runiform()*18000)
generate hire_date = birth_date + floor(runiform()*15000) + 6570  // At least 18 years later
```

### 4. Forgetting Reproducibility
**WRONG:**
```stata
* No seed set
clear
set obs 1000
generate x = rnormal()  // Different every time!
```

**RIGHT:**
```stata
* Always set seed
clear
set seed 12345  // Reproducible
set obs 1000
generate x = rnormal()
```

### 5. Creating Impossible Combinations
**WRONG:**
```stata
generate pregnant = runiform() < 0.1
generate male = runiform() < 0.5
* 5% of males are pregnant!
```

**RIGHT:**
```stata
generate male = runiform() < 0.5
generate pregnant = runiform() < 0.1 if male == 0
replace pregnant = 0 if male == 1
```

### 6. Over-Simplifying Relationships
**WRONG:**
```stata
* Linear relationship for everything
generate income = 20000 + 5000*education + rnormal(0,1000)
```

**RIGHT:**
```stata
* Non-linear, heteroskedastic relationship
generate log_income = 9 + 0.1*education + 0.005*education^2 ///
                      + rnormal(0, 0.2 + 0.05*education)
generate income = exp(log_income)
```

### 7. Ignoring Panel Structure
**WRONG:**
```stata
* Treating panel observations as independent
generate id = ceil(_n/10)
generate time = mod(_n-1, 10) + 1
generate outcome = 50 + rnormal()  // No individual effect
```

**RIGHT:**
```stata
* Including individual-specific effects
generate id = ceil(_n/10)
bysort id: generate time = _n
bysort id: generate individual_effect = rnormal() if _n == 1
bysort id: replace individual_effect = individual_effect[1]
generate outcome = 50 + individual_effect + rnormal(0, 0.5)
```

---

## Performance Considerations

### Efficient Random Number Generation

```stata
* SLOW: Loop-based generation
clear
set obs 1000000
generate x = .
quietly {
    forvalues i = 1/1000000 {
        replace x = rnormal() in `i'
    }
}

* FAST: Vectorized generation
clear
set obs 1000000
generate x = rnormal()  // Much faster!
```

### Memory Management for Large Synthetic Datasets

```stata
* Set memory appropriately
set maxvar 10000  // If you need many variables
clear

* Generate in chunks if memory is limited
forvalues chunk = 1/10 {
    clear
    set obs 100000
    generate id = _n + (`chunk' - 1) * 100000
    * Generate other variables...

    if `chunk' == 1 {
        save synthetic_data, replace
    }
    else {
        append using synthetic_data
        save synthetic_data, replace
    }
}
```

### Parallel Processing (Stata MP)

```stata
* If using Stata MP, leverage parallel processing
* For simulation studies
set seed 12345
parallel setclusters 4  // Use 4 cores

program define sim_data
    drop _all
    set obs 1000
    generate x = rnormal()
    generate y = 2*x + rnormal()
    regress y x
end

* Run multiple simulations in parallel
parallel sim, reps(1000): sim_data
```

---

## Final Checklist for Synthetic Data

Before finalizing your synthetic dataset:

- [ ] **Reproducibility**: Seed is set and documented
- [ ] **Documentation**: Code is well-commented explaining each variable
- [ ] **Distributions**: Checked that distributions match intended patterns
- [ ] **Correlations**: Verified relationships between variables
- [ ] **Constraints**: All logical constraints are satisfied (no impossible values)
- [ ] **Missing Data**: Missing patterns are realistic and intentional
- [ ] **Privacy**: If based on real data, privacy protections are adequate
- [ ] **Validation**: Statistical properties checked against targets
- [ ] **Labeling**: All variables have descriptive labels
- [ ] **Value Labels**: Categorical variables have value labels
- [ ] **Format**: Date and numeric formats are appropriate
- [ ] **Testing**: Run basic analyses to ensure data behaves as expected
- [ ] **Sample Size**: Adequate for intended purpose
- [ ] **Save**: Data saved with clear filename and documentation

---

## Additional Resources

1. **Stata Documentation**: `help egen`, `help generate`, `help rnormal`, `help runiform`
2. **Multiple Imputation**: `help mi impute` for synthetic data based on real patterns
3. **Mata Programming**: For complex multivariate distributions
4. **SSC Packages**:
   - `ssc install jnsn` (Johnson distribution fitting)
   - `ssc install rsource` (Interface with R for complex distributions)
5. **World Bank DIME Wiki**: Comprehensive guides on data generation
6. **Stata Journal Articles**: Search for "simulation" and "synthetic data"

---

## Example: Complete Synthetic Dataset Generation Script

```stata
/*****************************************************************************
* Project: Synthetic Dataset for Educational Research Example
* Author: [Your Name]
* Date: 2024-01-15
* Purpose: Generate realistic synthetic student performance data
*          Preserves statistical properties while ensuring privacy
*
* Structure:
*   - 100 schools
*   - ~30 students per school (variable)
*   - 4 years of test scores
*   - Individual and school-level covariates
*****************************************************************************/

clear all
set seed 20240115  // Date-based seed for reproducibility

*------------------------------------------------------------------------------
* 1. School-Level Data
*------------------------------------------------------------------------------
clear
set obs 100

generate school_id = _n
generate school_size = 25 + ceil(rchi2(3) * 5)  // 25-50 students, right-skewed
generate urban = runiform() < 0.6
generate poverty_rate = runiform() * 0.5
replace poverty_rate = poverty_rate * 1.3 if urban == 0  // Higher rural poverty
generate school_quality = rnormal(0, 1)  // Unobserved quality

* School resources
generate per_pupil_spending = 8000 + 2000*urban + rnormal(0, 1000)
replace per_pupil_spending = max(5000, per_pupil_spending)

tempfile schools
save `schools'

*------------------------------------------------------------------------------
* 2. Student-Level Data
*------------------------------------------------------------------------------
* Expand to students within schools
expand school_size
bysort school_id: generate student_id = _n

* Student demographics
generate female = runiform() > 0.48
generate race = 1 if runiform() < 0.5
replace race = 2 if missing(race) & runiform() < 0.7
replace race = 3 if missing(race) & runiform() < 0.9
replace race = 4 if missing(race)
label define race_lbl 1 "White" 2 "Black" 3 "Hispanic" 4 "Asian/Other"
label values race race_lbl

* Socioeconomic status (correlated with school poverty rate)
bysort school_id: generate low_income = runiform() < poverty_rate

* Ability (correlated with SES and school quality)
generate ability = rnormal(0, 1)
replace ability = ability + 0.3*school_quality
replace ability = ability - 0.2 if low_income

* Create unique student identifier
egen student_unique_id = group(school_id student_id)

tempfile students
save `students'

*------------------------------------------------------------------------------
* 3. Longitudinal Test Scores
*------------------------------------------------------------------------------
* Expand to yearly observations
expand 4
bysort student_unique_id: generate year = _n + 2

* Grade level
bysort student_unique_id: generate grade = 6 + _n - 1  // Grades 6-9

* Generate test scores with realistic structure
bysort student_unique_id: generate test_score_math = ///
    500 + ///  Baseline
    10 * grade + ///  Grade level improvement
    15 * ability + ///  Ability effect
    5 * school_quality + ///  School effect
    10 * female + ///  Gender effect (females better in this cohort)
    rnormal(0, 20) if _n == 1  // Initial error

* Carry forward with growth and persistence
bysort student_unique_id: replace test_score_math = ///
    test_score_math[_n-1] + ///  Persistence
    5 + ///  Average growth
    rnormal(0, 15) ///  Innovation
    if _n > 1

* Add intervention effect (reading program in year 3+)
generate reading_program = school_id <= 50 & year >= 4  // Half schools, years 3-4
bysort student_unique_id: replace test_score_math = ///
    test_score_math + 8 if reading_program

* Bound scores realistically
replace test_score_math = max(200, min(800, test_score_math))

* Add missing data (more likely for low-income, later years)
generate missing_prob = 0.02 + 0.05*low_income + 0.02*year
replace test_score_math = . if runiform() < missing_prob

*------------------------------------------------------------------------------
* 4. Clean and Label
*------------------------------------------------------------------------------
* Labels
label variable school_id "School Identifier"
label variable student_id "Student ID within School"
label variable student_unique_id "Unique Student Identifier"
label variable year "Academic Year (1-4)"
label variable grade "Grade Level"
label variable female "Female Student"
label variable race "Student Race/Ethnicity"
label variable low_income "Low Income Status"
label variable test_score_math "Mathematics Test Score (200-800)"
label variable urban "Urban School"
label variable poverty_rate "School Poverty Rate"
label variable per_pupil_spending "Per-Pupil Spending ($)"
label variable reading_program "Participated in Reading Program"

* Keep only necessary variables
keep school_id student_id student_unique_id year grade female race ///
     low_income test_score_math urban poverty_rate per_pupil_spending ///
     reading_program school_quality ability

order school_id student_id student_unique_id year grade

* Declare panel structure
xtset student_unique_id year

*------------------------------------------------------------------------------
* 5. Validation
*------------------------------------------------------------------------------
* Check distributions
summarize test_score_math, detail
tabulate grade, summarize(test_score_math)
tabulate female, summarize(test_score_math)

* Check correlations
pwcorr test_score_math ability school_quality per_pupil_spending

* Check for logical violations
assert grade >= 6 & grade <= 9
assert inrange(test_score_math, 200, 800) if !missing(test_score_math)
assert year >= 1 & year <= 4

* Check sample sizes
bysort school_id: egen students_per_school = count(student_id) if year == 1
summarize students_per_school

*------------------------------------------------------------------------------
* 6. Save
*------------------------------------------------------------------------------
compress
save "synthetic_student_data.dta", replace

* Create codebook
log using "synthetic_student_data_codebook.txt", text replace
describe
codebook
log close

display as result _n "Synthetic data generation complete!"
display as result "Dataset: synthetic_student_data.dta"
display as result "Codebook: synthetic_student_data_codebook.txt"
display as result "N students: " _N / 4
display as result "N observations: " _N
```

---

**End of Synthetic Data Generation Guide**

Remember: The goal of synthetic data is to enable testing, development, and sharing while preserving privacy and statistical properties. Always validate your synthetic data before using it for development or examples.

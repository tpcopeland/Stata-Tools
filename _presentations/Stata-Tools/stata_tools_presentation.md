---
theme: default
title: "Stata-Tools: A Research Toolkit"
info: |
  ## Stata-Tools
  A collection of Stata packages for data science, epidemiology, and research workflows.

  From data preparation to publication-ready output.
author: Timothy P Copeland
keywords: stata,packages,epidemiology,data-science,research
class: text-center
highlighter: shiki
drawings:
  persist: false
transition: fade
mdc: true
aspectRatio: '16/9'
lineNumbers: false
colorSchema: light
fonts:
  sans: Inter
  mono: Fira Code
---

# Stata-Tools

<div class="mt-4 text-2xl text-gray-500 font-light tracking-wide">
A Research Toolkit for <span class="text-gray-800 font-medium">Data Science</span> in Stata
</div>

<div class="mt-16">
  <span class="px-6 py-3 rounded-full bg-gray-900 text-white text-lg font-medium tracking-wide">
    15 Packages · From Prep to Publication
  </span>
</div>

<div class="abs-br m-8 flex gap-3 items-center">
  <span class="text-sm text-gray-400">github.com/tpcopeland/Stata-Tools</span>
  <a href="https://github.com/tpcopeland/Stata-Tools" target="_blank" class="text-xl text-gray-400 hover:text-gray-600 transition-colors">
    <carbon-logo-github />
  </a>
</div>

<style>
h1 {
  font-size: 3.5rem !important;
  font-weight: 600 !important;
  color: #1a1a1a !important;
  letter-spacing: -0.02em;
}
</style>

---
layout: center
class: text-center
---

# The Research Workflow Challenge

<div class="mt-12 max-w-3xl mx-auto">

<div class="grid grid-cols-4 gap-4">

<div v-click class="challenge-step">
  <carbon-data-base class="text-3xl text-gray-400 mb-3" />
  <div class="step-label">Raw Data</div>
  <div class="step-issue">Messy dates, formats, quality issues</div>
</div>

<div v-click class="challenge-step">
  <carbon-analytics class="text-3xl text-gray-400 mb-3" />
  <div class="step-label">Analysis</div>
  <div class="step-issue">Missing patterns, survival metrics</div>
</div>

<div v-click class="challenge-step">
  <carbon-document class="text-3xl text-gray-400 mb-3" />
  <div class="step-label">Documentation</div>
  <div class="step-issue">Privacy, reproducibility</div>
</div>

<div v-click class="challenge-step">
  <carbon-table class="text-3xl text-gray-400 mb-3" />
  <div class="step-label">Output</div>
  <div class="step-issue">Tables, formatting, Excel</div>
</div>

</div>

<div v-click class="mt-12 solution-box">
  <div class="text-lg font-medium text-gray-800">Stata-Tools addresses each stage</div>
  <div class="text-sm text-gray-500 mt-2">Purpose-built commands that integrate seamlessly</div>
</div>

</div>

<style>
.challenge-step {
  @apply bg-gray-50 p-5 rounded-xl;
}
.step-label {
  @apply font-semibold text-gray-800 mb-1;
}
.step-issue {
  @apply text-sm text-gray-500;
}
.solution-box {
  @apply bg-blue-50 p-5 rounded-xl border border-blue-100;
}
</style>

---

# The Toolkit Overview

<div class="flex-1 flex items-center justify-center -mt-4">
<div class="w-full">

<div class="grid grid-cols-5 gap-3">

<div v-click class="pkg-category cat-prep">
  <div class="cat-header">Data Prep</div>
  <div class="pkg-list">
    <span>check</span>
    <span>datefix</span>
    <span>compress_tc</span>
    <span>massdesas</span>
  </div>
</div>

<div v-click class="pkg-category cat-doc">
  <div class="cat-header">Documentation</div>
  <div class="pkg-list">
    <span>datamap</span>
    <span>datadict</span>
  </div>
</div>

<div v-click class="pkg-category cat-analysis">
  <div class="cat-header">Analysis</div>
  <div class="pkg-list">
    <span>mvp</span>
    <span>cstat_surv</span>
    <span>table1_tc</span>
    <span>synthdata</span>
    <span>tvtools</span>
  </div>
</div>

<div v-click class="pkg-category cat-output">
  <div class="cat-header">Output</div>
  <div class="pkg-list">
    <span>table1_tc</span>
    <span>regtab</span>
    <span>stratetab</span>
  </div>
</div>

<div v-click class="pkg-category cat-utility">
  <div class="cat-header">Utilities</div>
  <div class="pkg-list">
    <span>today</span>
    <span>pkgtransfer</span>
    <span>setools</span>
  </div>
</div>

</div>

<div v-click class="mt-8 text-center">
  <div class="inline-flex items-center gap-6 text-sm text-gray-500">
    <span class="flex items-center gap-2"><span class="w-3 h-3 rounded bg-emerald-500"></span> GUI Available</span>
    <span>table1_tc · regtab · tvtools</span>
  </div>
</div>

</div>
</div>

<style>
.pkg-category {
  @apply rounded-xl p-4 text-center;
}
.cat-header {
  @apply font-semibold text-sm mb-3 pb-2 border-b;
}
.pkg-list {
  @apply flex flex-col gap-1;
}
.pkg-list span {
  @apply text-xs font-mono bg-white/50 py-1 px-2 rounded;
}
.cat-prep { @apply bg-blue-50; .cat-header { @apply border-blue-200 text-blue-700; } }
.cat-doc { @apply bg-purple-50; .cat-header { @apply border-purple-200 text-purple-700; } }
.cat-analysis { @apply bg-emerald-50; .cat-header { @apply border-emerald-200 text-emerald-700; } }
.cat-output { @apply bg-amber-50; .cat-header { @apply border-amber-200 text-amber-700; } }
.cat-utility { @apply bg-gray-100; .cat-header { @apply border-gray-300 text-gray-700; } }
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# Anatomy of a Stata Package

<div class="section-subtitle">How these tools are built</div>

</div>

<style>
.section-header h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.section-subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
</style>

---

# Package Structure

<div class="grid grid-cols-2 gap-10 mt-6">

<div>

### The Files

<div class="file-tree mt-4">

<div v-click class="file-item">
  <carbon-code class="file-icon text-blue-500" />
  <span class="file-name">mycommand.ado</span>
  <span class="file-desc">The executable code</span>
</div>

<div v-click class="file-item">
  <carbon-help class="file-icon text-purple-500" />
  <span class="file-name">mycommand.sthlp</span>
  <span class="file-desc">Documentation (SMCL format)</span>
</div>

<div v-click class="file-item">
  <carbon-gui class="file-icon text-emerald-500" />
  <span class="file-name">mycommand.dlg</span>
  <span class="file-desc">Dialog interface (optional)</span>
</div>

<div v-click class="file-item">
  <carbon-package class="file-icon text-amber-500" />
  <span class="file-name">mycommand.pkg</span>
  <span class="file-desc">Package metadata</span>
</div>

<div v-click class="file-item">
  <carbon-list class="file-icon text-gray-500" />
  <span class="file-name">stata.toc</span>
  <span class="file-desc">Table of contents</span>
</div>

</div>

</div>

<div v-click>

### The .ado Pattern

```stata
*! version 1.0.0  01dec2025
program define mycommand, rclass
    version 16.0
    syntax varlist [if] [in] [, Options]

    // Mark sample
    marksample touse
    quietly count if `touse'

    // Computation
    quietly {
        summarize `varlist' if `touse'
    }

    // Return results
    return scalar N = r(N)
end
```

</div>

</div>

<style>
.file-tree {
  @apply flex flex-col gap-3;
}
.file-item {
  @apply flex items-center gap-3 bg-gray-50 p-3 rounded-lg;
}
.file-icon {
  @apply text-lg;
}
.file-name {
  @apply font-mono text-sm font-medium;
}
.file-desc {
  @apply text-sm text-gray-500 ml-auto;
}
</style>

---

# Dialog Files: GUI for Everyone

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

### Why Dialogs Matter

<v-clicks>

- **Accessibility** — Not everyone codes daily
- **Discoverability** — See all options at once
- **Validation** — Prevent syntax errors
- **Onboarding** — Learn command structure visually

</v-clicks>

<div v-click class="mt-6 gui-commands">

```stata
* Access any dialog
db table1_tc
db regtab
db tvexpose
```

</div>

</div>

<div v-click>

### Dialog Structure

```stata
VERSION 16.0
POSITION . . 640 400

DIALOG main, tabtitle("Main")
BEGIN
  TEXT     tx_var  20  20 280 ., ///
           label("Variable:")
  VARNAME  vn_var  @  +20 @   .
END

PROGRAM command
BEGIN
    put "mycommand "
    require vn_var
    put vn_var
END
```

<div class="mt-4 text-sm text-gray-500">
  Dialogs build the command string from user inputs
</div>

</div>

</div>

<style>
.gui-commands {
  @apply bg-gray-900 p-4 rounded-xl text-sm;
}
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# Data Preparation

<div class="section-subtitle">check · datefix · compress_tc · massdesas</div>

</div>

<style>
.section-header h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.section-subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
</style>

---

# check — Variable Summary at a Glance

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

### The Problem

<div class="problem-box">
  To understand a variable, you run <code>codebook</code>, then <code>summarize</code>, then <code>tabulate</code>...
</div>

<div v-click class="mt-6">

### The Solution

```stata
check age sex income diagnosis_date
```

<div class="mt-4 output-preview">

```
Variable    N      Miss   Uniq  Type    Label
─────────────────────────────────────────────
age         1,234  0      67    float   Age at baseline
sex         1,234  0      2     byte    Patient sex
income      1,189  45     892   double  Annual income
diagnosis   1,234  0      1,102 float   Date of diagnosis
```

</div>

</div>

</div>

<div v-click>

### What You Get

<div class="feature-grid">

<div class="feature-item">
  <carbon-checkmark-filled class="text-emerald-500" />
  <span>N and missing counts</span>
</div>

<div class="feature-item">
  <carbon-checkmark-filled class="text-emerald-500" />
  <span>Unique values</span>
</div>

<div class="feature-item">
  <carbon-checkmark-filled class="text-emerald-500" />
  <span>Storage type and format</span>
</div>

<div class="feature-item">
  <carbon-checkmark-filled class="text-emerald-500" />
  <span>Variable labels</span>
</div>

<div class="feature-item">
  <carbon-checkmark-filled class="text-emerald-500" />
  <span>Optional: mean, SD, percentiles</span>
</div>

</div>

<div class="mt-6 insight-box">
  <div class="font-medium">One command. Complete picture.</div>
  <div class="text-sm text-gray-500 mt-1">Combines codebook + summarize + tabulate</div>
</div>

</div>

</div>

<style>
.problem-box {
  @apply bg-rose-50 p-4 rounded-xl text-sm text-gray-700 border border-rose-100;
}
.output-preview {
  @apply bg-gray-900 text-green-400 p-3 rounded-xl text-xs font-mono;
}
.feature-grid {
  @apply flex flex-col gap-2 mt-4;
}
.feature-item {
  @apply flex items-center gap-2 text-sm;
}
.insight-box {
  @apply bg-blue-50 p-4 rounded-xl border border-blue-100;
}
</style>

---

# datefix — Intelligent Date Conversion

<div class="flex-1 flex items-center">
<div class="w-full">

<div class="grid grid-cols-2 gap-8">

<div>

### The Problem

<div class="problem-box">
  String dates in inconsistent formats: "03/15/2024", "15-Mar-24", "2024.03.15"
</div>

<div v-click class="mt-6">

### The Solution

```stata
datefix admission_date, order(MDY)
```

</div>

<div v-click class="mt-4 transform-demo">
  <div class="before">
    <span class="label">Before</span>
    <span class="value">"03/15/2024"</span>
    <span class="type">str10</span>
  </div>
  <div class="arrow">→</div>
  <div class="after">
    <span class="label">After</span>
    <span class="value">15mar2024</span>
    <span class="type">float (%td)</span>
  </div>
</div>

</div>

<div v-click>

### Key Features

<div class="feature-list">

<div class="feature">
  <div class="feature-title">Auto-detection</div>
  <div class="feature-desc">Tries MDY, DMY, YMD — picks best match</div>
</div>

<div class="feature">
  <div class="feature-title">Two-digit years</div>
  <div class="feature-desc"><code>topyear(2025)</code> handles "03/15/24"</div>
</div>

<div class="feature">
  <div class="feature-title">Preserve or replace</div>
  <div class="feature-desc"><code>newvar(date_clean)</code> or replace in-place</div>
</div>

<div class="feature">
  <div class="feature-title">Custom format</div>
  <div class="feature-desc"><code>df(%tdCY-N-D)</code> for ISO dates</div>
</div>

</div>

</div>

</div>

</div>
</div>

<style>
.problem-box {
  @apply bg-rose-50 p-4 rounded-xl text-sm text-gray-700 border border-rose-100;
}
.transform-demo {
  @apply flex items-center gap-4 bg-gray-50 p-4 rounded-xl;
}
.transform-demo .before, .transform-demo .after {
  @apply flex flex-col gap-1;
}
.transform-demo .label {
  @apply text-xs text-gray-400;
}
.transform-demo .value {
  @apply font-mono text-sm font-medium;
}
.transform-demo .type {
  @apply text-xs text-gray-500;
}
.transform-demo .arrow {
  @apply text-gray-300 text-xl;
}
.feature-list {
  @apply flex flex-col gap-3;
}
.feature {
  @apply bg-gray-50 p-3 rounded-lg;
}
.feature-title {
  @apply font-medium text-sm;
}
.feature-desc {
  @apply text-xs text-gray-500 mt-1;
}
</style>

---

# compress_tc & massdesas

<div class="flex-1 flex items-center">
<div class="w-full">

<div class="grid grid-cols-2 gap-8">

<div v-click>

### compress_tc — String Compression

<div class="cmd-box">

```stata
compress_tc
```

</div>

<div class="mt-4 benefit-grid">

<div class="benefit">
  <div class="benefit-num">2x</div>
  <div class="benefit-text">Compression beyond standard <code>compress</code></div>
</div>

<div class="benefit">
  <div class="benefit-num">strL</div>
  <div class="benefit-text">Converts fixed-length to variable-length strings</div>
</div>

</div>

<div class="mt-4 text-sm text-gray-500">
  Especially effective for datasets with repeated long strings or text fields
</div>

</div>

<div v-click>

### massdesas — Batch SAS Conversion

<div class="cmd-box">

```stata
massdesas, directory("/data/sas_files")
```

</div>

<div class="mt-4 benefit-grid">

<div class="benefit">
  <div class="benefit-num">∞</div>
  <div class="benefit-text">Recursive directory scanning</div>
</div>

<div class="benefit">
  <div class="benefit-num">1:1</div>
  <div class="benefit-text">Preserves folder structure</div>
</div>

</div>

<div class="mt-4 options-list">
  <span class="option"><code>erase</code> — Delete .sas7bdat after</span>
  <span class="option"><code>lower</code> — Lowercase variable names</span>
</div>

</div>

</div>

</div>
</div>

<style>
.cmd-box {
  @apply bg-gray-900 p-4 rounded-xl text-sm;
}
.benefit-grid {
  @apply grid grid-cols-2 gap-3;
}
.benefit {
  @apply bg-gray-50 p-3 rounded-lg text-center;
}
.benefit-num {
  @apply text-2xl font-bold text-blue-600;
}
.benefit-text {
  @apply text-xs text-gray-600 mt-1;
}
.options-list {
  @apply flex flex-col gap-1 text-sm text-gray-600;
}
.option code {
  @apply text-blue-600;
}
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# Data Documentation

<div class="section-subtitle">datamap · datadict</div>

</div>

<style>
.section-header h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.section-subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
</style>

---

# datamap — Privacy-Safe Documentation

<div class="flex-1 flex items-center">
<div class="w-full">

<div class="grid grid-cols-2 gap-8">

<div>

### The Challenge

<div class="problem-box">
  Document datasets for collaborators without exposing sensitive values or patient identifiers
</div>

<div v-click class="mt-6">

### Two Commands

<div class="cmd-pair">

<div class="cmd-item">
  <div class="cmd-name">datamap</div>
  <div class="cmd-desc">Plain text output</div>
</div>

<div class="cmd-item">
  <div class="cmd-name">datadict</div>
  <div class="cmd-desc">Markdown with TOC</div>
</div>

</div>

</div>

<div v-click class="mt-6">

```stata
datamap, single("patient_data.dta") ///
    exclude(ssn name address) ///
    datesafe stats frequencies
```

</div>

</div>

<div v-click>

### Auto-Classification

<div class="class-grid">

<div class="class-item class-excluded">
  <span class="class-label">Excluded</span>
  <span class="class-desc">Sensitive variables</span>
</div>

<div class="class-item class-string">
  <span class="class-label">String</span>
  <span class="class-desc">Text fields</span>
</div>

<div class="class-item class-date">
  <span class="class-label">Date</span>
  <span class="class-desc">Temporal variables</span>
</div>

<div class="class-item class-cat">
  <span class="class-label">Categorical</span>
  <span class="class-desc">≤20 unique values</span>
</div>

<div class="class-item class-cont">
  <span class="class-label">Continuous</span>
  <span class="class-desc">Numeric, >20 unique</span>
</div>

</div>

<div class="mt-6 insight-box">
  <carbon-security class="text-emerald-500 text-xl" />
  <span><strong>datesafe</strong> mode suppresses exact date ranges</span>
</div>

</div>

</div>

</div>
</div>

<style>
.problem-box {
  @apply bg-rose-50 p-4 rounded-xl text-sm text-gray-700 border border-rose-100;
}
.cmd-pair {
  @apply grid grid-cols-2 gap-3;
}
.cmd-item {
  @apply bg-gray-50 p-3 rounded-lg text-center;
}
.cmd-name {
  @apply font-mono font-bold text-blue-600;
}
.cmd-desc {
  @apply text-xs text-gray-500 mt-1;
}
.class-grid {
  @apply grid grid-cols-1 gap-2;
}
.class-item {
  @apply flex justify-between items-center p-2 rounded-lg text-sm;
}
.class-label {
  @apply font-medium;
}
.class-desc {
  @apply text-xs text-gray-500;
}
.class-excluded { @apply bg-red-50; .class-label { @apply text-red-600; } }
.class-string { @apply bg-purple-50; .class-label { @apply text-purple-600; } }
.class-date { @apply bg-blue-50; .class-label { @apply text-blue-600; } }
.class-cat { @apply bg-amber-50; .class-label { @apply text-amber-600; } }
.class-cont { @apply bg-emerald-50; .class-label { @apply text-emerald-600; } }
.insight-box {
  @apply flex items-center gap-3 bg-emerald-50 p-4 rounded-xl text-sm;
}
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# Missing Value Analysis

<div class="section-subtitle">mvp — Missing Value Patterns</div>

</div>

<style>
.section-header h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.section-subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
</style>

---

# mvp — Understanding Missing Data

<div class="flex-1 flex items-center">
<div class="w-full">

<div class="grid grid-cols-2 gap-8">

<div>

### Pattern Display

```stata
mvp age income education occupation
```

<div v-click class="mt-4 pattern-output">

```
Pattern    Freq    Percent
──────────────────────────
++++       8,432   67.5%
+++.       1,891   15.1%
++..       1,245    9.9%
+...         934    7.5%
──────────────────────────
+ = nonmissing    . = missing
```

</div>

<div v-click class="mt-4 insight-box">
  67.5% complete cases — is that enough?
</div>

</div>

<div v-click>

### Visualization Options

<div class="viz-grid">

<div class="viz-item">
  <carbon-chart-bar class="viz-icon text-blue-500" />
  <span>Bar chart (% missing)</span>
</div>

<div class="viz-item">
  <carbon-chart-stacked class="viz-icon text-purple-500" />
  <span>Pattern frequencies</span>
</div>

<div class="viz-item">
  <carbon-heat-map class="viz-icon text-amber-500" />
  <span>Heatmap</span>
</div>

<div class="viz-item">
  <carbon-network-4 class="viz-icon text-emerald-500" />
  <span>Correlation matrix</span>
</div>

</div>

<div class="mt-6">

### Additional Features

```stata
mvp varlist, ///
    minmissing(1) maxmissing(3) ///
    generate(miss_pattern) ///
    monotone
```

<div class="mt-2 text-xs text-gray-500">
  Test for monotone patterns • Generate indicators • Filter by missingness
</div>

</div>

</div>

</div>

</div>
</div>

<style>
.pattern-output {
  @apply bg-gray-900 text-green-400 p-4 rounded-xl text-xs font-mono;
}
.insight-box {
  @apply bg-blue-50 p-3 rounded-xl text-sm text-blue-700;
}
.viz-grid {
  @apply grid grid-cols-2 gap-3;
}
.viz-item {
  @apply flex items-center gap-2 bg-gray-50 p-3 rounded-lg text-sm;
}
.viz-icon {
  @apply text-lg;
}
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# Statistical Analysis

<div class="section-subtitle">cstat_surv · table1_tc · synthdata</div>

</div>

<style>
.section-header h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.section-subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
</style>

---

# cstat_surv — Model Discrimination

<div class="grid grid-cols-2 gap-8 mt-6">

<div>

### Harrell's C-Statistic

<div class="concept-box">
  How well does your Cox model distinguish between patients who experience the event sooner vs. later?
</div>

<div v-click class="mt-6">

```stata
stset time, failure(event)
stcox age sex treatment comorbidity
cstat_surv
```

</div>

<div v-click class="mt-4 result-box">

```
Harrell's C-statistic = 0.782
Standard error        = 0.018
95% CI: [0.747, 0.817]

Concordant pairs:     45,832
Discordant pairs:     12,891
Tied pairs:              234
```

</div>

</div>

<div v-click>

### Interpretation Guide

<div class="interp-scale">
  <div class="scale-bar">
    <div class="segment seg-poor" style="flex:1">0.5</div>
    <div class="segment seg-ok" style="flex:1">0.6</div>
    <div class="segment seg-good" style="flex:1">0.7</div>
    <div class="segment seg-excellent" style="flex:1">0.8</div>
    <div class="segment seg-perfect" style="flex:1">0.9</div>
  </div>
  <div class="scale-labels">
    <span>Random</span>
    <span>Poor</span>
    <span>Acceptable</span>
    <span>Excellent</span>
    <span>Perfect</span>
  </div>
</div>

<div class="mt-8 key-point">
  <div class="kp-title">Key insight</div>
  <div class="kp-text">Accounts for censoring — standard AUC doesn't work for survival data</div>
</div>

</div>

</div>

<style>
.concept-box {
  @apply bg-gray-50 p-4 rounded-xl text-sm text-gray-700;
}
.result-box {
  @apply bg-gray-900 text-green-400 p-4 rounded-xl text-xs font-mono;
}
.interp-scale {
  @apply mt-4;
}
.scale-bar {
  @apply flex h-10 rounded-lg overflow-hidden;
}
.segment {
  @apply flex items-center justify-center text-white text-xs font-medium;
}
.seg-poor { background: #EF4444; }
.seg-ok { background: #F59E0B; }
.seg-good { background: #84CC16; }
.seg-excellent { background: #22C55E; }
.seg-perfect { background: #10B981; }
.scale-labels {
  @apply flex justify-between mt-2 text-xs text-gray-500;
}
.key-point {
  @apply bg-blue-50 p-4 rounded-xl border border-blue-100;
}
.kp-title {
  @apply font-medium text-blue-700;
}
.kp-text {
  @apply text-sm text-gray-600 mt-1;
}
</style>

---

# table1_tc — Baseline Characteristics

<div class="grid grid-cols-2 gap-6 mt-4">

<div>

### Publication-Ready Table 1

```stata
table1_tc, vars( ///
    age contn %5.1f ///
  \ sex cat ///
  \ bmi conts %5.1f ///
  \ smoking cat ///
) by(treatment) xlsx("Table1.xlsx")
```

<div v-click class="mt-4 var-types">

| Type | Description | Test |
|------|-------------|------|
| `contn` | Normal continuous | t-test |
| `conts` | Skewed continuous | Wilcoxon |
| `contln` | Log-normal | t-test on log |
| `cat` | Categorical | Chi-square |
| `bin` | Binary | Chi-square |

</div>

</div>

<div v-click>

### Output Preview

<div class="table-preview">
  <div class="table-header">
    <span></span>
    <span>Control<br/>(N=523)</span>
    <span>Treatment<br/>(N=511)</span>
    <span>p-value</span>
  </div>
  <div class="table-row">
    <span class="var-name">Age, mean (SD)</span>
    <span>54.2 (12.3)</span>
    <span>53.8 (11.9)</span>
    <span>0.612</span>
  </div>
  <div class="table-row">
    <span class="var-name">Female, n (%)</span>
    <span>312 (59.7)</span>
    <span>298 (58.3)</span>
    <span>0.658</span>
  </div>
  <div class="table-row">
    <span class="var-name">BMI, median [IQR]</span>
    <span>27.1 [24.2-31.4]</span>
    <span>26.8 [23.9-30.8]</span>
    <span>0.423</span>
  </div>
</div>

<div class="mt-4 gui-note">
  <carbon-gui class="text-emerald-500" />
  <span><code>db table1_tc</code> — Full GUI available</span>
</div>

</div>

</div>

<style>
.var-types {
  @apply text-xs;
}
.var-types table {
  @apply w-full;
}
.var-types th, .var-types td {
  @apply p-2 text-left border-b border-gray-100;
}
.table-preview {
  @apply bg-white border border-gray-200 rounded-xl overflow-hidden text-xs;
}
.table-header {
  @apply grid grid-cols-4 gap-2 bg-gray-50 p-3 font-semibold text-center;
}
.table-row {
  @apply grid grid-cols-4 gap-2 p-3 border-t border-gray-100 text-center;
}
.var-name {
  @apply text-left font-medium;
}
.gui-note {
  @apply flex items-center gap-2 bg-emerald-50 p-3 rounded-lg text-sm;
}
</style>

---

# synthdata — Privacy-Preserving Data

<div class="flex-1 flex items-center">
<div class="w-full">

<div class="grid grid-cols-2 gap-8">

<div>

### The Need

<div class="problem-box">
  Share data for collaboration, teaching, or code testing — without exposing real patient information
</div>

<div v-click class="mt-6">

### Synthesis Methods

<div class="method-grid">

<div class="method">
  <div class="method-name">parametric</div>
  <div class="method-desc">Cholesky decomposition (default)</div>
</div>

<div class="method">
  <div class="method-name">sequential</div>
  <div class="method-desc">Sequential regression</div>
</div>

<div class="method">
  <div class="method-name">bootstrap</div>
  <div class="method-desc">Bootstrap with perturbation</div>
</div>

<div class="method">
  <div class="method-name">permute</div>
  <div class="method-desc">Independent permutation</div>
</div>

</div>

</div>

</div>

<div v-click>

### Usage

```stata
synthdata age sex income diagnosis, ///
    parametric ///
    mincell(5) ///
    validate ///
    saveas("synthetic_data.dta")
```

<div class="mt-4 privacy-features">

<div class="pf-item">
  <carbon-locked class="text-emerald-500" />
  <span>Rare category protection</span>
</div>

<div class="pf-item">
  <carbon-cut-out class="text-emerald-500" />
  <span>Extreme value trimming</span>
</div>

<div class="pf-item">
  <carbon-chart-relationship class="text-emerald-500" />
  <span>Preserves correlations</span>
</div>

<div class="pf-item">
  <carbon-report class="text-emerald-500" />
  <span>Validation reports</span>
</div>

</div>

</div>

</div>

</div>
</div>

<style>
.problem-box {
  @apply bg-rose-50 p-4 rounded-xl text-sm text-gray-700 border border-rose-100;
}
.method-grid {
  @apply grid grid-cols-2 gap-2;
}
.method {
  @apply bg-gray-50 p-3 rounded-lg;
}
.method-name {
  @apply font-mono text-sm font-medium text-blue-600;
}
.method-desc {
  @apply text-xs text-gray-500 mt-1;
}
.privacy-features {
  @apply grid grid-cols-2 gap-2;
}
.pf-item {
  @apply flex items-center gap-2 bg-emerald-50 p-2 rounded-lg text-sm;
}
</style>

---

# tvtools — Time-Varying Exposures

<div class="mt-6 text-center">

<div class="tvtools-banner">
  <div class="banner-title">Dedicated Presentation Available</div>
  <div class="banner-subtitle">Comprehensive toolkit for survival analysis with time-varying exposures</div>
</div>

<div class="grid grid-cols-3 gap-6 mt-8 max-w-3xl mx-auto">

<div v-click class="tv-cmd">
  <div class="cmd-name text-blue-600">tvexpose</div>
  <div class="cmd-desc">Transform prescriptions to time-varying intervals</div>
</div>

<div v-click class="tv-cmd">
  <div class="cmd-name text-purple-600">tvmerge</div>
  <div class="cmd-desc">Combine multiple time-varying exposures</div>
</div>

<div v-click class="tv-cmd">
  <div class="cmd-name text-emerald-600">tvevent</div>
  <div class="cmd-desc">Integrate outcomes and competing risks</div>
</div>

</div>

<div v-click class="mt-8">

```stata
db tvexpose    // Full GUI available
```

</div>

<div v-click class="mt-6 text-sm text-gray-500">
  See the tvtools presentation for detailed workflow and examples
</div>

</div>

<style>
.tvtools-banner {
  @apply bg-gradient-to-r from-blue-50 to-purple-50 p-8 rounded-2xl;
  @apply border border-blue-100;
}
.banner-title {
  @apply text-2xl font-semibold text-gray-800;
}
.banner-subtitle {
  @apply text-gray-500 mt-2;
}
.tv-cmd {
  @apply bg-white p-5 rounded-xl shadow-sm;
}
.cmd-name {
  @apply text-xl font-semibold font-mono;
}
.cmd-desc {
  @apply text-sm text-gray-500 mt-2;
}
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# Output & Reporting

<div class="section-subtitle">regtab · stratetab</div>

</div>

<style>
.section-header h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.section-subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
</style>

---

# regtab — Regression Tables to Excel

<div class="grid grid-cols-2 gap-8 mt-4">

<div>

### The Workflow

```stata {all|1-3|5-7|9-12|all}
* Run models with collect
collect clear
collect: regress outcome treatment age sex

* Or multiple models
collect: regress outcome treatment, vce(robust)
collect: regress outcome treatment age sex, vce(robust)

* Export to Excel
regtab, xlsx("regression_results.xlsx") ///
    sheet("Main Analysis") ///
    models("Unadjusted" "Adjusted")
```

</div>

<div v-click>

### Output Features

<div class="feature-list">

<div class="feature">
  <carbon-table class="text-blue-500" />
  <span>Estimate, 95% CI, p-value columns</span>
</div>

<div class="feature">
  <carbon-text-annotation-toggle class="text-purple-500" />
  <span>Model headers above column groups</span>
</div>

<div class="feature">
  <carbon-filter class="text-amber-500" />
  <span>Drop intercept / random effects</span>
</div>

<div class="feature">
  <carbon-ruler class="text-emerald-500" />
  <span>Auto column widths, borders</span>
</div>

</div>

<div class="mt-6 gui-note">
  <carbon-gui class="text-emerald-500" />
  <span><code>db regtab</code> — GUI available</span>
</div>

<div class="mt-4 req-note">
  Requires Stata 17+ (uses <code>collect</code> framework)
</div>

</div>

</div>

<style>
.feature-list {
  @apply flex flex-col gap-3;
}
.feature {
  @apply flex items-center gap-3 bg-gray-50 p-3 rounded-lg text-sm;
}
.gui-note {
  @apply flex items-center gap-2 bg-emerald-50 p-3 rounded-lg text-sm;
}
.req-note {
  @apply text-xs text-gray-400;
}
</style>

---

# stratetab — Incidence Rate Tables

<div class="flex-1 flex items-center">
<div class="w-full">

<div class="grid grid-cols-2 gap-8">

<div>

### Purpose

<div class="concept-box">
  Combine multiple <code>strate</code> output files into a single Excel table with outcomes as column groups
</div>

<div v-click class="mt-6">

```stata
stratetab, ///
    using("cancer.dta cvd.dta death.dta") ///
    xlsx("incidence_rates.xlsx") ///
    outcomes(3) ///
    outcomelabels("Cancer" "CVD" "Death") ///
    exposurelabels("Treatment" "Control")
```

</div>

</div>

<div v-click>

### Output Structure

<div class="table-structure">
  <table>
    <thead>
      <tr class="header-row">
        <th></th>
        <th colspan="2">Cancer</th>
        <th colspan="2">CVD</th>
        <th colspan="2">Death</th>
      </tr>
      <tr class="subheader-row">
        <th></th>
        <th>Events</th><th>Rate</th>
        <th>Events</th><th>Rate</th>
        <th>Events</th><th>Rate</th>
      </tr>
    </thead>
    <tbody>
      <tr><td>Treatment</td><td>45</td><td>3.6</td><td>23</td><td>1.9</td><td>12</td><td>1.0</td></tr>
      <tr><td>Control</td><td>67</td><td>5.6</td><td>34</td><td>2.9</td><td>28</td><td>2.4</td></tr>
    </tbody>
  </table>
</div>

<div class="mt-4 text-xs text-gray-500">
  Rates per 1,000 person-years with 95% CI
</div>

</div>

</div>

</div>
</div>

<style>
.concept-box {
  @apply bg-gray-50 p-4 rounded-xl text-sm;
}
.table-structure {
  @apply bg-white border border-gray-200 rounded-xl overflow-hidden;
}
.table-structure table {
  @apply w-full text-xs;
}
.table-structure th, .table-structure td {
  @apply p-2 text-center;
}
.table-structure .header-row th {
  @apply bg-gray-100 font-semibold;
}
.table-structure .subheader-row th {
  @apply bg-gray-50 text-gray-500 font-normal;
}
.table-structure tbody td {
  @apply border-t border-gray-100;
}
.table-structure tbody td:first-child {
  @apply text-left font-medium;
}
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# Utilities & Specialized

<div class="section-subtitle">today · pkgtransfer · setools</div>

</div>

<style>
.section-header h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.section-subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
</style>

---

# Utility Commands

<div class="grid grid-cols-2 gap-8 mt-6">

<div v-click>

### today — Timestamp Automation

```stata
today
display "$today"        // 2025-12-03
display "$today_time"   // 14:32:45

* Custom format
today, df(dmony)        // 03dec2025

* Use in filenames
save "analysis_$today.dta"
log using "run_$today_$today_time.log"
```

<div class="mt-4 use-case">
  <carbon-time class="text-blue-500" />
  <span>Perfect for versioned outputs and logs</span>
</div>

</div>

<div v-click>

### pkgtransfer — Package Migration

```stata
* Generate installation script
pkgtransfer

* Offline mode with downloads
pkgtransfer, download

* Specific packages only
pkgtransfer, limited("estout coefplot")
```

<div class="mt-4 use-case">
  <carbon-cloud-download class="text-purple-500" />
  <span>Transfer packages between machines or create backups</span>
</div>

<div class="mt-4 modes">
  <span class="mode"><strong>Online:</strong> Generates do-file with net/ssc commands</span>
  <span class="mode"><strong>Offline:</strong> Downloads files + creates ZIP archive</span>
</div>

</div>

</div>

<style>
.use-case {
  @apply flex items-center gap-2 bg-gray-50 p-3 rounded-lg text-sm;
}
.modes {
  @apply flex flex-col gap-1 text-xs text-gray-500;
}
</style>

---

# setools — Swedish Registry Analysis

<div class="flex-1 flex items-center">
<div class="w-full">

<div class="grid grid-cols-2 gap-8">

<div v-click>

### migrations

<div class="concept-box">
  Process Swedish migration registry data for epidemiological cohorts
</div>

```stata
migrations, migfile("migration.dta") ///
    idvar(lopnr) startvar(study_start) ///
    immigvar(immigdate) emigvar(emigdate)
```

<div class="mt-4 output-list">
  <span>Identifies emigration exclusions</span>
  <span>Determines censoring dates</span>
  <span>Handles residency at baseline</span>
</div>

</div>

<div v-click>

### sustainedss

<div class="concept-box">
  Compute sustained EDSS progression for MS studies
</div>

```stata
sustainedss lopnr edss edss_date, ///
    threshold(1) confirmwindow(90) ///
    baseline(edss_baseline)
```

<div class="mt-4 output-list">
  <span>Identifies progression events</span>
  <span>Requires confirmation window</span>
  <span>Rejects reversals</span>
</div>

</div>

</div>

<div v-click class="mt-6 text-center text-sm text-gray-500">
  Specialized for Swedish national registry research workflows
</div>

</div>
</div>

<style>
.concept-box {
  @apply bg-gray-50 p-3 rounded-lg text-sm mb-4;
}
.output-list {
  @apply flex flex-col gap-1 text-sm text-gray-600;
}
</style>

---

# Cross-Language Validation

<div class="mt-8 text-center">

<div class="reimp-box">
  <carbon-code class="text-4xl text-gray-400 mb-4" />
  <div class="reimp-title">tvtools-reimplementations</div>
  <div class="reimp-desc">Reference implementations in Python and R</div>
</div>

<div class="grid grid-cols-3 gap-6 mt-8 max-w-2xl mx-auto">

<div v-click class="lang-card">
  <div class="lang-name">Stata</div>
  <div class="lang-role">Production</div>
</div>

<div v-click class="lang-card">
  <div class="lang-name">Python</div>
  <div class="lang-role">Validation</div>
</div>

<div v-click class="lang-card">
  <div class="lang-name">R</div>
  <div class="lang-role">Validation</div>
</div>

</div>

<div v-click class="mt-8 insight-box max-w-xl mx-auto">
  <carbon-checkmark-filled class="text-emerald-500 text-xl" />
  <span>Cross-language testing ensures algorithmic correctness</span>
</div>

</div>

<style>
.reimp-box {
  @apply bg-gray-50 p-8 rounded-2xl max-w-md mx-auto;
}
.reimp-title {
  @apply text-xl font-semibold text-gray-800;
}
.reimp-desc {
  @apply text-gray-500 mt-2;
}
.lang-card {
  @apply bg-white p-4 rounded-xl shadow-sm text-center;
}
.lang-name {
  @apply text-lg font-semibold;
}
.lang-role {
  @apply text-sm text-gray-500;
}
.insight-box {
  @apply flex items-center justify-center gap-3 bg-emerald-50 p-4 rounded-xl;
}
</style>

---

# Installation

<div class="mt-8 max-w-3xl mx-auto">

<div class="install-method">

### From GitHub

```stata
* Individual packages
net install check, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/check")
net install table1_tc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/table1_tc")
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")

* Browse available packages
net from "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main"
```

</div>

<div v-click class="mt-8 grid grid-cols-3 gap-4">

<div class="req-box">
  <div class="req-title">Stata 14+</div>
  <div class="req-list">check, datefix, mvp, table1_tc, today, pkgtransfer, massdesas</div>
</div>

<div class="req-box">
  <div class="req-title">Stata 16+</div>
  <div class="req-list">datamap, synthdata, tvtools, cstat_surv</div>
</div>

<div class="req-box">
  <div class="req-title">Stata 17+</div>
  <div class="req-list">regtab, stratetab</div>
</div>

</div>

</div>

<style>
.install-method {
  @apply bg-gray-900 p-6 rounded-2xl;
}
.install-method h3 {
  @apply text-white text-lg mb-4;
}
.req-box {
  @apply bg-gray-50 p-4 rounded-xl;
}
.req-title {
  @apply font-semibold text-sm mb-2;
}
.req-list {
  @apply text-xs text-gray-500;
}
</style>

---
layout: two-cols
---

# Quick Reference

<div class="mt-4 space-y-2">

<div class="ref-item">
  <span class="ref-cmd">check</span>
  <span class="ref-desc">Variable summary</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">datefix</span>
  <span class="ref-desc">String to date</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">compress_tc</span>
  <span class="ref-desc">String compression</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">datamap</span>
  <span class="ref-desc">Documentation</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">mvp</span>
  <span class="ref-desc">Missing patterns</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">cstat_surv</span>
  <span class="ref-desc">C-statistic</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">table1_tc</span>
  <span class="ref-desc">Baseline table</span>
</div>

</div>

::right::

<div class="pl-8 mt-4 space-y-2">

<div class="ref-item">
  <span class="ref-cmd">synthdata</span>
  <span class="ref-desc">Synthetic data</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">tvtools</span>
  <span class="ref-desc">Time-varying</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">regtab</span>
  <span class="ref-desc">Regression tables</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">stratetab</span>
  <span class="ref-desc">Rate tables</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">setools</span>
  <span class="ref-desc">Swedish registries</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">today</span>
  <span class="ref-desc">Timestamps</span>
</div>

<div class="ref-item">
  <span class="ref-cmd">pkgtransfer</span>
  <span class="ref-desc">Package migration</span>
</div>

</div>

<style>
.ref-item {
  @apply flex items-center gap-3 bg-gray-50 p-2 rounded-lg;
}
.ref-cmd {
  @apply font-mono text-sm font-medium text-blue-600 w-24;
}
.ref-desc {
  @apply text-sm text-gray-600;
}
</style>

---
layout: center
class: text-center
---

<div class="thank-you">

# Thank You

<div class="subtitle">Stata-Tools — A Research Toolkit for Data Science</div>

<div class="links mt-12">

<div class="link-item">
  <carbon-logo-github class="link-icon" />
  <div class="link-text">tpcopeland/Stata-Tools</div>
</div>

<div class="link-item">
  <carbon-document class="link-icon" />
  <div class="link-text">help [command]</div>
</div>

<div class="link-item">
  <carbon-email class="link-icon" />
  <div class="link-text">Questions welcome</div>
</div>

</div>

</div>

<div class="abs-bl m-8 text-sm text-gray-400">
  Timothy P Copeland · Department of Clinical Neuroscience · Karolinska Institutet
</div>

<style>
.thank-you h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.subtitle {
  @apply text-xl text-gray-500 mt-4 font-light;
}
.links {
  @apply flex justify-center gap-16;
}
.link-item {
  @apply flex flex-col items-center gap-2;
}
.link-icon {
  @apply text-3xl text-gray-400;
}
.link-text {
  @apply text-sm text-gray-500;
}
</style>

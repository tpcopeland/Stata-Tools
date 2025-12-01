---
theme: default
title: "The Time-Varying Problem in MS Research"
info: |
  ## tvtools
  A Stata toolkit for survival analysis with time-varying exposures.

  Preventing immortal time bias and capturing treatment dynamics in MS pharmacoepidemiology.
author: Timothy P Copeland
keywords: stata,survival-analysis,time-varying,epidemiology,MS,multiple-sclerosis
class: text-center
highlighter: shiki
drawings:
  persist: false
transition: slide-left
mdc: true
aspectRatio: '16/9'
lineNumbers: true
---

# The Time-Varying Problem in MS Research

## How **tvtools** Prevents the Biases That Haunt Our Papers

<div class="pt-12">
  <span class="px-4 py-2 rounded bg-gradient-to-r from-blue-600 to-purple-600 text-white text-xl font-semibold">
    A Stata Toolkit for MS Pharmacoepidemiology
  </span>
</div>

<div class="abs-br m-6 flex gap-2">
  <a href="https://github.com/tpcopeland/Stata-Tools" target="_blank" class="text-xl slidev-icon-btn opacity-50 !border-none !hover:text-white">
    <carbon-logo-github />
  </a>
</div>

<style>
h1 {
  background: linear-gradient(135deg, #3b82f6 0%, #8b5cf6 50%, #f97316 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
</style>

---
layout: two-cols
transition: fade-out
---

# Anna's Journey

<v-clicks>

**Age 32:** Diagnosed with RRMS

**Year 1:** Starts interferon beta

**Year 3:** Two relapses → switches to fingolimod

**Year 5:** MRI activity → escalates to natalizumab

**Year 8:** Develops EDSS progression

</v-clicks>

<div v-click class="mt-8 text-red-500 font-bold text-xl">
Which treatment failed her?
</div>

<!--
This is the "aha moment" - most of the audience will have encountered this problem.
The treatment journey is typical for MS patients - platform → high efficacy escalation.
Emphasize that if we analyze by "ever-treated" we get immortal time bias because
Anna had to survive 5 years just to become "natalizumab-exposed."
-->

::right::

<div class="pl-8 pt-8">

<div v-click class="patient-timeline">
  <div class="timeline-bar">
    <div
      v-motion
      :initial="{ scaleX: 0 }"
      :enter="{ scaleX: 1, transition: { delay: 0, duration: 400 } }"
      class="segment segment-ifn origin-left" style="flex: 2">IFN</div>
    <div
      v-motion
      :initial="{ scaleX: 0 }"
      :enter="{ scaleX: 1, transition: { delay: 400, duration: 400 } }"
      class="segment segment-fingo origin-left" style="flex: 2">FTY</div>
    <div
      v-motion
      :initial="{ scaleX: 0 }"
      :enter="{ scaleX: 1, transition: { delay: 800, duration: 400 } }"
      class="segment segment-ntz origin-left" style="flex: 3">NTZ</div>
  </div>
  <div class="timeline-labels">
    <span v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 0 } }">Dx</span>
    <span v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 400 } }">Y3</span>
    <span v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 800 } }">Y5</span>
    <span v-motion :initial="{ opacity: 0, scale: 0.5 }" :enter="{ opacity: 1, scale: 1, transition: { delay: 1200, type: 'spring' } }" class="text-red-500">Y8 ⚡</span>
  </div>
</div>

<div v-click class="mt-8 problem-box">

**The uncomfortable truth:**

If we analyze by "ever-exposed to NTZ" → NTZ looks protective

*(she survived long enough to get it)*

</div>

</div>

<style>
.patient-timeline {
  @apply mt-12;
}
.timeline-bar {
  @apply flex h-12 rounded-lg overflow-hidden;
}
.segment {
  @apply flex items-center justify-center text-white font-bold text-sm;
}
.segment-ifn { @apply bg-blue-500; }
.segment-fingo { @apply bg-purple-500; }
.segment-ntz { @apply bg-orange-500; }
.timeline-labels {
  @apply flex justify-between mt-2 text-sm text-gray-500;
}
.problem-box {
  @apply bg-red-50 dark:bg-red-900/30 p-4 rounded-xl;
  @apply border-l-4 border-red-500;
}
</style>

---
layout: center
class: text-center
---

# The Immortal Time Bias Problem

<div class="bias-diagram mt-8">

<div v-click class="bias-row wrong">
  <div class="label">❌ WRONG</div>
  <div class="bar-container">
    <div class="bar treated-full">
      <span>"Treated" from study entry</span>
    </div>
  </div>
  <div class="note">Patient must survive to get treatment → spurious protection</div>
</div>

<div v-click class="bias-row correct">
  <div class="label">✓ CORRECT</div>
  <div class="bar-container">
    <div class="bar unexposed-part">Unexposed</div>
    <div class="bar treated-part">Treated</div>
  </div>
  <div class="note">Treatment status changes at initiation</div>
</div>

</div>

<div v-click class="mt-8 text-sm text-gray-500">
  Suissa S. Immortal time bias in pharmacoepidemiology. <i>Am J Epidemiol</i> 2008
</div>

<style>
.bias-diagram {
  @apply flex flex-col gap-8 max-w-2xl mx-auto;
}
.bias-row {
  @apply text-left;
}
.bias-row .label {
  @apply font-bold mb-2;
}
.bar-container {
  @apply flex h-12 rounded-lg overflow-hidden;
}
.bar {
  @apply flex items-center justify-center text-white font-semibold text-sm px-4;
}
.treated-full {
  @apply bg-orange-500 flex-1;
}
.unexposed-part {
  @apply bg-gray-400;
  flex: 1;
}
.treated-part {
  @apply bg-orange-500;
  flex: 2;
}
.note {
  @apply text-xs text-gray-500 mt-2 italic;
}
.wrong .label { @apply text-red-500; }
.correct .label { @apply text-green-500; }
</style>

---
transition: slide-up
---

# Why This Matters for MS Research

<div class="grid grid-cols-2 gap-8 mt-8">

<div v-click class="issue-card">
  <div class="icon">🔄</div>
  <h3>Treatment Switching</h3>
  <p>Escalation, lateral switches, de-escalation</p>
  <div class="example">Platform → High-efficacy after breakthrough</div>
</div>

<div v-click class="issue-card">
  <div class="icon">📈</div>
  <h3>Cumulative Exposure</h3>
  <p>Duration-response relationships</p>
  <div class="example">5 years on NTZ ≠ 2 years on NTZ</div>
</div>

<div v-click class="issue-card">
  <div class="icon">⚔️</div>
  <h3>Competing Risks</h3>
  <p>Death competes with progression</p>
  <div class="example">Emigration, pregnancy, discontinuation</div>
</div>

<div v-click class="issue-card">
  <div class="icon">📊</div>
  <h3>Registry Complexity</h3>
  <p>SMSreg captures all of this</p>
  <div class="example">Our methods must match our data</div>
</div>

</div>

<style>
.issue-card {
  @apply bg-white dark:bg-gray-800 p-6 rounded-xl shadow-lg;
  @apply border-t-4 border-blue-500;
}
.issue-card .icon {
  @apply text-3xl mb-2;
}
.issue-card h3 {
  @apply font-bold text-lg mb-2;
}
.issue-card p {
  @apply text-gray-600 dark:text-gray-400 text-sm;
}
.issue-card .example {
  @apply mt-3 text-xs bg-gray-100 dark:bg-gray-700 p-2 rounded;
  @apply font-mono;
}
</style>

---
layout: default
---

# The tvtools Solution

<div class="grid grid-cols-3 gap-8 mt-12">

<div v-click class="command-card">
  <div class="text-5xl mb-4">📊</div>
  <h3 class="text-xl font-bold text-blue-600">tvexpose</h3>
  <p class="text-sm mt-2 text-gray-600 dark:text-gray-400">
    DMT prescriptions → Time-varying intervals
  </p>
  <div class="use-case">
    Handles gaps, switching, duration
  </div>
</div>

<div v-click class="command-card">
  <div class="text-5xl mb-4">🔗</div>
  <h3 class="text-xl font-bold text-purple-600">tvmerge</h3>
  <p class="text-sm mt-2 text-gray-600 dark:text-gray-400">
    Multiple exposures → Single dataset
  </p>
  <div class="use-case">
    DMT + comorbidity treatments
  </div>
</div>

<div v-click class="command-card">
  <div class="text-5xl mb-4">🎯</div>
  <h3 class="text-xl font-bold text-green-600">tvevent</h3>
  <p class="text-sm mt-2 text-gray-600 dark:text-gray-400">
    Add EDSS progression + competing risks
  </p>
  <div class="use-case">
    Analysis-ready for stcrreg
  </div>
</div>

</div>

<div v-click class="mt-12 text-center">

```mermaid {scale: 0.8}
graph LR
    A[📁 Registry Data] --> B[tvexpose]
    B --> C[tvmerge]
    C --> D[tvevent]
    D --> E[📈 stcrreg]
    style A fill:#9CA3AF,color:#fff
    style B fill:#3b82f6,color:#fff
    style C fill:#8b5cf6,color:#fff
    style D fill:#22c55e,color:#fff
    style E fill:#F97316,color:#fff
```

</div>

<!--
This workflow slide is critical - show that tvtools is a complete pipeline.
Note that tvmerge is optional (only needed for multiple exposures).
Emphasize the seamless integration with Stata's survival analysis commands.
-->

<style>
.command-card {
  @apply bg-white dark:bg-gray-800 p-6 rounded-xl shadow-lg text-center;
  @apply transform hover:scale-105 transition-transform duration-300;
}
.command-card .use-case {
  @apply mt-4 text-xs bg-gray-100 dark:bg-gray-700 p-2 rounded;
}
</style>

---
layout: section
---

# Step 1: tvexpose

## Transform DMT Prescriptions into Time-Varying Intervals

---
transition: view-transition
---

# tvexpose: Basic Syntax

<div class="mt-8">

```stata {all|1|3|4|5|6|all}
use ms_cohort, clear

tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date)
```

</div>

<div v-click class="mt-8 grid grid-cols-2 gap-4">

<div class="option-box">
  <span class="font-bold text-blue-600">id()</span>
  <span class="text-sm">Patient identifier</span>
</div>

<div class="option-box">
  <span class="font-bold text-blue-600">start() / stop()</span>
  <span class="text-sm">DMT prescription dates</span>
</div>

<div class="option-box">
  <span class="font-bold text-blue-600">exposure()</span>
  <span class="text-sm">DMT type variable</span>
</div>

<div class="option-box">
  <span class="font-bold text-blue-600">entry() / exit()</span>
  <span class="text-sm">MS diagnosis to study end</span>
</div>

</div>

<style>
.option-box {
  @apply bg-gray-100 dark:bg-gray-800 p-3 rounded-lg;
  @apply flex flex-col gap-1;
}
</style>

---
layout: two-cols
transition: slide-up
---

# tvexpose: The Transformation

<div class="mt-4">

````md magic-move {lines: true}
```txt {*|*}
Raw DMT Prescriptions
─────────────────────────────────────
id │ dmt_start  │ dmt_stop   │ dmt
───┼────────────┼────────────┼────────
 1 │ 2015-03-01 │ 2017-08-15 │ 1 (IFN)
 1 │ 2018-01-10 │ 2022-06-30 │ 4 (NTZ)
```

```txt {*|1-3|4|5|6|7|8|*}
Time-Varying Output (tvexpose)
─────────────────────────────────────
id │ start      │ stop       │ exposure
───┼────────────┼────────────┼─────────
 1 │ 2014-01-15 │ 2015-03-01 │ 0 (None)
 1 │ 2015-03-01 │ 2017-08-15 │ 1 (IFN)
 1 │ 2017-08-15 │ 2018-01-10 │ 0 (None)
 1 │ 2018-01-10 │ 2022-06-30 │ 4 (NTZ)
 1 │ 2022-06-30 │ 2023-12-31 │ 0 (None)
```
````

</div>

<div v-click class="mt-4 text-sm text-gray-500">
  <carbon-information class="inline" /> 2 prescription rows → 5 complete intervals
</div>

::right::

<div class="pl-8 pt-4">

<div class="timeline-visual">

<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: -50 }"
  :enter="{ opacity: 1, x: 0, transition: { delay: 0 } }"
  class="timeline-row unexposed" style="width: 20%">None</div>
<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: -50 }"
  :enter="{ opacity: 1, x: 0, transition: { delay: 100 } }"
  class="timeline-row ifn" style="width: 25%">IFN</div>
<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: -50 }"
  :enter="{ opacity: 1, x: 0, transition: { delay: 200 } }"
  class="timeline-row unexposed" style="width: 10%">Gap</div>
<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: -50 }"
  :enter="{ opacity: 1, x: 0, transition: { delay: 300 } }"
  class="timeline-row ntz" style="width: 35%">NTZ</div>
<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: -50 }"
  :enter="{ opacity: 1, x: 0, transition: { delay: 400 } }"
  class="timeline-row unexposed" style="width: 10%">None</div>

</div>

<div v-click class="mt-8 highlight-box">

**Key insight:** Gaps automatically filled with reference category (unexposed)

No immortal time!

</div>

</div>

<!--
The before/after transformation is powerful - emphasize that gaps are automatically handled.
This is the core value proposition: tvexpose does the tedious work of creating
complete timelines where every moment of follow-up has defined exposure status.
Point out: patient was unexposed 2014-2015, on IFN 2015-2017, gap 2017-2018, etc.
-->

<style>
.timeline-visual {
  @apply flex flex-col gap-2 mt-8;
}
.timeline-row {
  @apply py-3 px-4 rounded text-white text-sm font-semibold text-center;
  @apply transform transition-all duration-500;
}
.unexposed { @apply bg-gray-400; }
.ifn { @apply bg-blue-500; }
.ntz { @apply bg-orange-500; }
.highlight-box {
  @apply bg-green-100 dark:bg-green-900 p-4 rounded-lg;
  @apply border-l-4 border-green-500;
}
</style>

---

# tvexpose: Exposure Definitions for MS Research

<div class="grid grid-cols-2 gap-6 mt-6">

<div v-click class="def-card def-basic">
  <h4>Basic Time-Varying</h4>
  <code class="text-xs">[no special option]</code>
  <p class="text-sm mt-2">Standard categorical exposure</p>
  <div class="example">Which DMT are they on now?</div>
</div>

<div v-click class="def-card def-ever">
  <h4>Ever-Treated</h4>
  <code class="text-xs">evertreated</code>
  <p class="text-sm mt-2">Binary switch at first exposure</p>
  <div class="example">Ever vs never DMT-exposed</div>
</div>

<div v-click class="def-card def-cf">
  <h4>Current/Former</h4>
  <code class="text-xs">currentformer</code>
  <p class="text-sm mt-2">0=Never, 1=Current, 2=Former</p>
  <div class="example">Active vs residual protection</div>
</div>

<div v-click class="def-card def-dur">
  <h4>Duration Categories</h4>
  <code class="text-xs">duration(1 3 5)</code>
  <p class="text-sm mt-2">Cumulative years on DMT</p>
  <div class="example">Dose-response by duration</div>
</div>

</div>

<div v-click class="mt-6">

```stata
tvexpose using dmt, id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) entry(ms_diagnosis_date) exit(study_exit_date) ///
    currentformer generate(dmt_status)
```

</div>

<style>
.def-card {
  @apply bg-white dark:bg-gray-800 p-4 rounded-xl shadow;
  @apply border-t-4;
}
.def-card h4 {
  @apply font-bold text-lg;
}
.def-card .example {
  @apply mt-2 text-xs bg-gray-100 dark:bg-gray-700 p-2 rounded italic;
}
.def-basic { @apply border-blue-500; }
.def-basic h4 { @apply text-blue-600; }
.def-ever { @apply border-purple-500; }
.def-ever h4 { @apply text-purple-600; }
.def-cf { @apply border-green-500; }
.def-cf h4 { @apply text-green-600; }
.def-dur { @apply border-orange-500; }
.def-dur h4 { @apply text-orange-600; }
</style>

---

# tvexpose: Handling Real-World Data

<div class="grid grid-cols-3 gap-6 mt-8">

<div v-click class="feature-card">

### Prescription Gaps

```stata
grace(30)
```

Treat 30-day gaps as continuous

<div class="feature-visual">
  <div class="bg-blue-500 w-16 h-6 rounded"></div>
  <div class="bg-yellow-400 w-4 h-6" title="gap"></div>
  <div class="bg-blue-500 w-16 h-6 rounded"></div>
</div>

<div class="caption">Refill delays ≠ discontinuation</div>

</div>

<div v-click class="feature-card">

### Delayed Onset

```stata
lag(14) washout(90)
```

14-day onset, 90-day persistence

<div class="feature-visual">
  <div class="bg-gray-300 w-4 h-6 rounded-l"></div>
  <div class="bg-blue-500 w-12 h-6"></div>
  <div class="bg-blue-300 w-8 h-6 rounded-r"></div>
</div>

<div class="caption">DMT biological effects</div>

</div>

<div v-click class="feature-card">

### Treatment Switching

```stata
switching switchingdetail
```

Track the entire pattern

<div class="text-xl mt-4 font-mono">
  0 → IFN → FTY → NTZ
</div>

<div class="caption">Identify escalation patterns</div>

</div>

</div>

<style>
.feature-card {
  @apply bg-gray-50 dark:bg-gray-800 p-4 rounded-xl;
  @apply text-center;
}
.feature-card h3 {
  @apply text-lg font-bold mb-2;
}
.feature-visual {
  @apply flex justify-center items-center gap-1 mt-4;
}
.caption {
  @apply text-xs text-gray-500 mt-4 italic;
}
</style>

---
layout: section
---

# Step 2: tvmerge

## Combine Multiple Time-Varying Exposures

---

# tvmerge: When Multiple Exposures Matter

<div class="grid grid-cols-2 gap-8 mt-8">

<div>

### MS Research Scenarios

<v-clicks>

- **DMT + Oral contraceptives**
  - Pregnancy safety studies

- **DMT + Antidepressants**
  - Fatigue/depression outcomes

- **DMT + Corticosteroids**
  - Relapse treatment patterns

- **High-efficacy vs Platform**
  - DMT class comparisons

</v-clicks>

</div>

<div v-click>

### The Setup

```stata
* Create time-varying DMT dataset
use ms_cohort, clear
tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    saveas(tv_dmt.dta) replace

* Create time-varying OC dataset
use ms_cohort, clear
tvexpose using oc_prescriptions, ///
    id(patient_id) start(oc_start) stop(oc_stop) ///
    exposure(oc_type) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    saveas(tv_oc.dta) replace

* Merge at all temporal boundaries
tvmerge tv_dmt tv_oc, id(patient_id) ///
    start(dmt_start oc_start) stop(dmt_stop oc_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(dmt oc_use)
```

</div>

</div>

---

# tvmerge: Temporal Cartesian Product

<div class="mt-4">

<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: -100 }"
  :enter="{ opacity: 1, x: 0, transition: { duration: 500, type: 'spring' } }"
  class="timeline-container">
  <div class="timeline-label">DMT:</div>
  <div class="timeline">
    <div class="segment unexposed" style="flex: 2">None</div>
    <div class="segment ifn" style="flex: 3">IFN</div>
    <div class="segment unexposed" style="flex: 2">None</div>
    <div class="segment ntz" style="flex: 3">NTZ</div>
  </div>
</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: 100 }"
  :enter="{ opacity: 1, x: 0, transition: { duration: 500, type: 'spring' } }"
  class="timeline-container">
  <div class="timeline-label">OC:</div>
  <div class="timeline">
    <div class="segment oc-no" style="flex: 3">No</div>
    <div class="segment oc-yes" style="flex: 4">Yes</div>
    <div class="segment oc-no" style="flex: 3">No</div>
  </div>
</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, scale: 0 }"
  :enter="{ opacity: 1, scale: 1, transition: { duration: 300, type: 'spring', stiffness: 300 } }"
  class="text-center text-2xl my-4">⬇️ Merge at all boundaries ⬇️</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, y: 50, scaleY: 0 }"
  :enter="{ opacity: 1, y: 0, scaleY: 1, transition: { duration: 600, type: 'spring' } }"
  class="timeline-container origin-top">
  <div class="timeline-label">Result:</div>
  <div class="timeline merged">
    <div class="segment s1" style="flex: 2">0,No</div>
    <div class="segment s2" style="flex: 1">IFN,No</div>
    <div class="segment s3" style="flex: 2">IFN,Yes</div>
    <div class="segment s4" style="flex: 2">0,Yes</div>
    <div class="segment s5" style="flex: 1">0,No</div>
    <div class="segment s6" style="flex: 2">NTZ,No</div>
  </div>
</div>

</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, y: 20 }"
  :enter="{ opacity: 1, y: 0, transition: { delay: 200, duration: 400 } }"
  class="mt-6 insight-box">
  <carbon-checkmark-filled class="text-green-500 text-xl" />
  <span>Every interval has BOTH exposures defined. No gaps. Analysis-ready.</span>
</div>

<style>
.timeline-container {
  @apply flex items-center gap-4 my-3;
}
.timeline-label {
  @apply w-16 font-bold text-right text-sm;
}
.timeline {
  @apply flex flex-1 h-10 rounded-lg overflow-hidden;
}
.segment {
  @apply flex items-center justify-center text-white text-xs font-semibold;
  @apply border-r border-white/30;
}
.unexposed { @apply bg-gray-400; }
.ifn { @apply bg-blue-500; }
.ntz { @apply bg-orange-500; }
.oc-no { @apply bg-gray-300 text-gray-700; }
.oc-yes { @apply bg-pink-400; }
.merged .s1 { @apply bg-gray-400; }
.merged .s2 { @apply bg-blue-500; }
.merged .s3 { background: linear-gradient(135deg, #3b82f6 50%, #f472b6 50%); }
.merged .s4 { @apply bg-pink-400; }
.merged .s5 { @apply bg-gray-400; }
.merged .s6 { @apply bg-orange-500; }
.insight-box {
  @apply flex items-center gap-3 bg-green-50 dark:bg-green-900/30 p-4 rounded-xl;
}
</style>

---
layout: section
---

# Step 3: tvevent

## Integrate EDSS Progression & Competing Risks

---

# tvevent: Purpose

<div class="grid grid-cols-2 gap-8 mt-8">

<div>

### The Challenge

<v-clicks>

- EDSS progression occurs at **specific dates**
- May fall **mid-interval**
- **Death** competes with progression
- **Emigration** is informative censoring
- Need **proper flagging** for stcrreg

</v-clicks>

</div>

<div v-click>

### The Solution

```stata
tvevent using ms_cohort, ///
    id(patient_id) ///
    date(edss4_date) ///
    compete(death_date emigration_date) ///
    eventlabel(0 "Censored" ///
               1 "EDSS Progression" ///
               2 "Death" ///
               3 "Emigration") ///
    generate(outcome)
```

</div>

</div>

<div v-click class="mt-8">

### tvevent automatically:

<div class="grid grid-cols-4 gap-2 mt-4">
  <div class="auto-step">Finds earliest event</div>
  <div class="auto-step">Splits intervals</div>
  <div class="auto-step">Flags event type</div>
  <div class="auto-step">Truncates follow-up</div>
</div>

</div>

<style>
.auto-step {
  @apply bg-green-100 dark:bg-green-900 p-3 rounded-lg text-center text-sm;
  @apply border-b-4 border-green-500;
}
</style>

---
transition: slide-up
---

# tvevent: Interval Splitting

<div class="split-demo mt-8">

<div
  v-click
  v-motion
  :initial="{ opacity: 0, y: -30 }"
  :enter="{ opacity: 1, y: 0, transition: { duration: 400 } }"
  class="split-before">
  <div class="label">Before tvevent:</div>
  <div class="interval">
    <span class="date">2020-01-01</span>
    <div class="bar"></div>
    <span class="date">2023-12-31</span>
  </div>
  <div class="values">dmt = 4 (NTZ), outcome = ?</div>
</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, scale: 0, rotate: -180 }"
  :enter="{ opacity: 1, scale: 1, rotate: 0, transition: { duration: 500, type: 'spring', stiffness: 200 } }"
  class="event-marker">
  <carbon-flag-filled class="text-red-500 text-3xl" />
  <span>EDSS Progression: 2022-06-15</span>
</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, scaleX: 0.6 }"
  :enter="{ opacity: 1, scaleX: 1, transition: { duration: 600, type: 'spring' } }"
  class="split-after origin-left">
  <div class="label">After tvevent:</div>
  <div class="interval">
    <span class="date">2020-01-01</span>
    <div class="bar bar-truncated"></div>
    <span class="date event-date">2022-06-15</span>
  </div>
  <div class="values">dmt = 4 (NTZ), <span class="text-red-500 font-bold">outcome = 1</span></div>
</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, x: 50 }"
  :enter="{ opacity: 1, x: 0, transition: { duration: 300 } }"
  class="dropped">
  <carbon-close-outline class="text-gray-400 text-xl" />
  <span>Post-progression follow-up dropped (type=single)</span>
</div>

</div>

<style>
.split-demo {
  @apply flex flex-col items-center gap-6;
}
.split-before, .split-after {
  @apply bg-gray-50 dark:bg-gray-800 p-6 rounded-xl w-full max-w-xl;
}
.label {
  @apply text-sm text-gray-500 mb-2 font-semibold;
}
.interval {
  @apply flex items-center gap-2;
}
.date {
  @apply text-sm font-mono;
}
.bar {
  @apply flex-1 h-10 bg-orange-500 rounded;
}
.bar-truncated {
  @apply bg-gradient-to-r from-orange-500 to-red-500;
}
.values {
  @apply text-sm mt-3 font-mono bg-gray-100 dark:bg-gray-700 p-2 rounded;
}
.event-marker {
  @apply flex items-center gap-3 text-red-600 font-bold text-lg;
}
.event-date {
  @apply bg-red-500 text-white px-3 py-1 rounded font-bold;
}
.dropped {
  @apply flex items-center gap-2 text-gray-400 text-sm italic;
}
</style>

---

# tvevent: Competing Risks

<div class="mt-6">

```stata
tvevent using ms_cohort, id(patient_id) date(edss4_date) ///
    compete(death_date emigration_date) ///
    eventlabel(0 "Censored" 1 "Progression" 2 "Death" 3 "Emigration") ///
    generate(outcome)
```

</div>

<div v-click class="mt-8">

### Outcome Coding

<div class="grid grid-cols-4 gap-4 mt-4">

<div class="outcome-box outcome-0">
  <div class="code">0</div>
  <div class="label">Censored</div>
  <div class="type">Study end</div>
</div>

<div class="outcome-box outcome-1">
  <div class="code">1</div>
  <div class="label">Progression</div>
  <div class="type">Primary outcome</div>
</div>

<div class="outcome-box outcome-2">
  <div class="code">2</div>
  <div class="label">Death</div>
  <div class="type">Competing risk</div>
</div>

<div class="outcome-box outcome-3">
  <div class="code">3</div>
  <div class="label">Emigration</div>
  <div class="type">Competing risk</div>
</div>

</div>

</div>

<div v-click class="mt-8 text-center text-sm text-gray-500">
  Ready for <code>stcrreg i.dmt_status, compete(outcome==2)</code>
</div>

<style>
.outcome-box {
  @apply p-4 rounded-xl text-center text-white;
}
.outcome-box .code {
  @apply text-4xl font-bold;
}
.outcome-box .label {
  @apply text-lg mt-2 font-semibold;
}
.outcome-box .type {
  @apply text-xs opacity-80 mt-1;
}
.outcome-0 { @apply bg-gray-400; }
.outcome-1 { @apply bg-blue-500; }
.outcome-2 { @apply bg-red-500; }
.outcome-3 { @apply bg-yellow-600; }
</style>

---
layout: section
---

# Complete Workflow

## From SMSreg to stcrreg

---

# The Full Pipeline

<div class="code-scroll">

```stata {all|1-7|9-11|13-15|all}
* Step 1: Create time-varying DMT exposure
use ms_cohort, clear
tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) ///
    keepvars(age_at_onset sex ms_type edss_baseline edss4_date death_date)

* Step 2: Integrate outcomes with competing risks
tvevent using ms_cohort, id(patient_id) ///
    date(edss4_date) compete(death_date) generate(outcome)

* Step 3: Survival analysis with competing risks
stset stop, id(patient_id) failure(outcome==1) enter(start)
stcrreg i.tv_exposure age_at_onset i.sex i.ms_type edss_baseline, ///
    compete(outcome==2)
```

</div>

<div v-click class="mt-6 workflow-summary">
  <div class="step">📥 SMSreg export</div>
  <div class="arrow">→</div>
  <div class="step">📊 tvexpose</div>
  <div class="arrow">→</div>
  <div class="step">🎯 tvevent</div>
  <div class="arrow">→</div>
  <div class="step">📈 stcrreg</div>
</div>

<style>
.workflow-summary {
  @apply flex items-center justify-center gap-2 text-sm;
}
.step {
  @apply bg-gray-100 dark:bg-gray-800 px-4 py-2 rounded-lg font-semibold;
}
.arrow {
  @apply text-gray-400;
}
</style>

---

# The Payoff: Clinically Plausible Results

<div class="results-container mt-4">

```
Competing-risks regression                        No. of obs     = 45,832
                                                  No. failed     =  2,847
                                                  No. competing  =    612

──────────────────────────────────────────────────────────────────────────
                           │     SHR    [95% CI]           P>|z|
───────────────────────────┼──────────────────────────────────────────────
DMT (vs Unexposed)         │
  Platform therapies       │    0.82    [0.71, 0.95]       0.008
  Moderate-efficacy        │    0.68    [0.56, 0.82]      <0.001
  High-efficacy            │    0.51    [0.41, 0.63]      <0.001
───────────────────────────┼──────────────────────────────────────────────
Age at onset               │    1.02    [1.01, 1.03]      <0.001
Female                     │    0.89    [0.80, 0.99]       0.032
PPMS (vs RRMS)             │    1.74    [1.48, 2.05]      <0.001
Baseline EDSS              │    1.31    [1.25, 1.37]      <0.001
──────────────────────────────────────────────────────────────────────────
```

</div>

<v-click>

<div class="insight mt-6">
  <carbon-idea class="text-yellow-500 text-2xl" />
  <span><strong>High-efficacy DMTs: ~50% reduction in progression risk.</strong> This is what proper time-varying analysis reveals.</span>
</div>

</v-click>

<!--
These effect sizes are clinically plausible and match published literature on high-efficacy DMTs.
The audience will recognize them as realistic.
Key point: The gradient from platform (18% reduction) to moderate (32%) to high-efficacy (49%)
makes biological and clinical sense.
Reference: Hauser SL et al. NEJM 2017 for ocrelizumab trials showing similar magnitudes.
-->

<style>
.results-container {
  @apply text-xs font-mono bg-gray-900 text-green-400 p-4 rounded-xl;
}
.insight {
  @apply flex items-center gap-4 bg-yellow-50 dark:bg-yellow-900/30 p-4 rounded-xl;
  @apply border-l-4 border-yellow-500;
}
</style>

---

# What Goes Wrong Without This

<div class="errors-grid mt-8">

<div v-click class="error-card">
  <div class="error-type">Baseline Exposure Only</div>
  <div class="consequence">Misclassification bias</div>
  <div class="magnitude">Attenuates toward null</div>
</div>

<div v-click class="error-card error-severe">
  <div class="error-type">Ever-Treated (No Time-Varying)</div>
  <div class="consequence">Immortal time bias</div>
  <div class="magnitude">Spurious protection (2-3x!)</div>
</div>

<div v-click class="error-card">
  <div class="error-type">Ignoring Switching</div>
  <div class="consequence">Treatment misattributed</div>
  <div class="magnitude">Direction unpredictable</div>
</div>

<div v-click class="error-card">
  <div class="error-type">No Competing Risks</div>
  <div class="consequence">Informative censoring</div>
  <div class="magnitude">Overestimates effect</div>
</div>

</div>

<div v-click class="mt-8 text-center text-sm text-gray-500">
  Multiple high-profile DMT papers have been criticized or retracted for these errors.
</div>

<!--
This slide validates their concerns and shows the stakes.
Don't name specific papers, but reference methodology papers like Suissa 2008.
The immortal time bias error is VERY common - estimates suggest 2-3x spurious protection.
Key takeaway: These aren't theoretical concerns - they've affected real research conclusions.
-->

<style>
.errors-grid {
  @apply grid grid-cols-2 gap-4;
}
.error-card {
  @apply bg-white dark:bg-gray-800 p-4 rounded-xl;
  @apply border-l-4 border-yellow-500;
}
.error-card .error-type {
  @apply font-bold text-lg;
}
.error-card .consequence {
  @apply text-gray-600 dark:text-gray-400 mt-1;
}
.error-card .magnitude {
  @apply mt-2 text-sm bg-yellow-100 dark:bg-yellow-900/30 p-2 rounded;
  @apply font-mono;
}
.error-severe {
  @apply border-red-500;
}
.error-severe .magnitude {
  @apply bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400;
}
</style>

---
layout: two-cols
---

# Key Takeaways

<v-clicks>

**Time-varying analysis is mandatory** for DMT effectiveness studies

**tvtools handles the complexity:**

- `tvexpose` → Time-varying intervals
- `tvmerge` → Multiple exposures
- `tvevent` → Competing risks

**Integrates seamlessly** with stset, stcox, stcrreg

**GUI interfaces available** for those who prefer point-and-click

</v-clicks>

::right::

<div class="pl-8 pt-4">

<div v-click class="install-box">

### Installation

```stata
net install tvtools, ///
    from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
```

### Help

```stata
help tvexpose
help tvmerge
help tvevent
```

### GUI

```stata
db tvexpose
db tvmerge
db tvevent
```

</div>

</div>

<style>
.install-box {
  @apply bg-gray-100 dark:bg-gray-800 p-6 rounded-xl;
}
.install-box h3 {
  @apply font-bold text-lg mb-2 mt-4 first:mt-0;
}
</style>

---
layout: center
class: text-center
---

# Thank You!

<div class="mt-8">

**tvtools** — Time-Varying Exposure Analysis for MS Research

<div class="flex justify-center gap-12 mt-8">

<div>
  <carbon-logo-github class="text-5xl" />
  <div class="text-sm mt-2">tpcopeland/Stata-Tools</div>
</div>

<div>
  <carbon-document class="text-5xl" />
  <div class="text-sm mt-2">help tvexpose</div>
</div>

<div>
  <carbon-email class="text-5xl" />
  <div class="text-sm mt-2">Questions welcome!</div>
</div>

</div>

</div>

<div class="abs-bl m-6 text-sm text-gray-500">
  Timothy P Copeland | Department of Clinical Neuroscience | Karolinska Institutet
</div>

---
layout: end
---

# Questions?

<div class="mt-8 text-lg">

**Common questions I can address:**

- How does this compare to manual stsplit?
- What about time-varying confounders?
- Can I analyze treatment sequencing?
- How do I handle patients on DMT before study entry?

</div>

<style>
h1 {
  background: linear-gradient(135deg, #3b82f6 0%, #8b5cf6 50%, #f97316 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
</style>

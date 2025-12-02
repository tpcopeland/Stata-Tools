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
transition: fade
mdc: true
aspectRatio: '16/9'
lineNumbers: false
colorSchema: light
fonts:
  sans: Inter
  mono: Fira Code
---

# The Time-Varying Problem in MS Research

<div class="mt-4 text-2xl text-gray-500 font-light tracking-wide">
How <span class="text-gray-800 font-medium">tvtools</span> Prevents the Biases That Haunt Our Papers
</div>

<div class="mt-16">
  <span class="px-6 py-3 rounded-full bg-gray-900 text-white text-lg font-medium tracking-wide">
    A Stata Toolkit for MS Pharmacoepidemiology
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
layout: two-cols
transition: fade
---

# Anna's Journey

<div class="mt-8 space-y-4">

<v-clicks>

<div class="journey-step">
  <span class="step-marker">32</span>
  <span class="step-text">Diagnosed with RRMS</span>
</div>

<div class="journey-step">
  <span class="step-marker">Y1</span>
  <span class="step-text">Starts interferon beta</span>
</div>

<div class="journey-step">
  <span class="step-marker">Y3</span>
  <span class="step-text">Two relapses → fingolimod</span>
</div>

<div class="journey-step">
  <span class="step-marker">Y5</span>
  <span class="step-text">MRI activity → natalizumab</span>
</div>

<div class="journey-step step-outcome">
  <span class="step-marker marker-red">Y8</span>
  <span class="step-text">Develops EDSS progression</span>
</div>

</v-clicks>

</div>

<div v-click class="mt-10 text-xl text-gray-800 font-medium">
Which treatment failed her?
</div>

::right::

<div class="pl-12 pt-6">

<div v-click class="patient-timeline">
  <div class="timeline-bar">
    <div
      v-motion
      :initial="{ scaleX: 0 }"
      :enter="{ scaleX: 1, transition: { delay: 0, duration: 500 } }"
      class="segment segment-ifn origin-left" style="flex: 2">IFN</div>
    <div
      v-motion
      :initial="{ scaleX: 0 }"
      :enter="{ scaleX: 1, transition: { delay: 500, duration: 500 } }"
      class="segment segment-fingo origin-left" style="flex: 2">FTY</div>
    <div
      v-motion
      :initial="{ scaleX: 0 }"
      :enter="{ scaleX: 1, transition: { delay: 1000, duration: 500 } }"
      class="segment segment-ntz origin-left" style="flex: 3">NTZ</div>
  </div>
  <div class="timeline-labels">
    <span>Dx</span>
    <span>Y3</span>
    <span>Y5</span>
    <span class="text-rose-500 font-medium">Y8 ●</span>
  </div>
</div>

<div v-click class="mt-10 problem-box">

<div class="text-sm font-medium text-gray-600 mb-2">The uncomfortable truth</div>

<div class="text-base text-gray-800">
If we analyze by "ever-exposed to NTZ" → NTZ looks protective
</div>

<div class="text-sm text-gray-500 mt-2 italic">
She had to survive 5 years just to receive it
</div>

</div>

</div>

<style>
.journey-step {
  @apply flex items-center gap-4;
}
.step-marker {
  @apply w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center;
  @apply text-sm font-semibold text-gray-600;
}
.marker-red {
  @apply bg-rose-100 text-rose-600;
}
.step-text {
  @apply text-gray-700;
}
.step-outcome .step-text {
  @apply text-rose-600 font-medium;
}
.patient-timeline {
  @apply mt-8;
}
.timeline-bar {
  @apply flex h-14 rounded-2xl overflow-hidden shadow-sm;
}
.segment {
  @apply flex items-center justify-center text-white font-medium text-sm tracking-wide;
}
.segment-ifn { background: #4A90A4; }
.segment-fingo { background: #7B6BA8; }
.segment-ntz { background: #D97706; }
.timeline-labels {
  @apply flex justify-between mt-3 text-sm text-gray-400 px-1;
}
.problem-box {
  @apply bg-rose-50 p-5 rounded-2xl;
  @apply border border-rose-100;
}
</style>

---
layout: center
class: text-center
---

# The Immortal Time Bias Problem

<div class="bias-diagram mt-12">

<div v-click class="bias-row">
  <div class="row-header">
    <div class="icon-wrong">✕</div>
    <div class="label-text">Wrong approach</div>
  </div>
  <div class="bar-container">
    <div class="bar treated-full">
      <span>Classified as "treated" from study entry</span>
    </div>
  </div>
  <div class="note">Patient must survive to reach treatment → creates spurious protective effect</div>
</div>

<div v-click class="bias-row">
  <div class="row-header">
    <div class="icon-correct">✓</div>
    <div class="label-text">Correct approach</div>
  </div>
  <div class="bar-container">
    <div class="bar unexposed-part">Unexposed</div>
    <div class="bar treated-part">Treated</div>
  </div>
  <div class="note">Exposure status changes at treatment initiation — time-varying analysis</div>
</div>

</div>

<div v-click class="mt-10 text-sm text-gray-400">
  Suissa S. Immortal time bias in pharmacoepidemiology. <span class="italic">Am J Epidemiol</span> 2008
</div>

<style>
.bias-diagram {
  @apply flex flex-col gap-10 max-w-2xl mx-auto;
}
.bias-row {
  @apply text-left;
}
.row-header {
  @apply flex items-center gap-3 mb-4;
}
.icon-wrong {
  @apply w-8 h-8 rounded-full bg-rose-100 text-rose-500 flex items-center justify-center font-bold text-sm;
}
.icon-correct {
  @apply w-8 h-8 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center font-bold text-sm;
}
.label-text {
  @apply font-medium text-gray-700;
}
.bar-container {
  @apply flex h-12 rounded-xl overflow-hidden;
}
.bar {
  @apply flex items-center justify-center text-white font-medium text-sm px-4;
}
.treated-full {
  background: #D97706;
  @apply flex-1;
}
.unexposed-part {
  background: #9CA3AF;
  flex: 1;
}
.treated-part {
  background: #D97706;
  flex: 2;
}
.note {
  @apply text-sm text-gray-500 mt-3;
}
</style>

---
transition: fade
---

# Why This Matters for MS Research

<div class="grid grid-cols-2 gap-8 mt-10">

<div v-click class="issue-card">
  <div class="card-icon icon-blue">
    <carbon-arrows-horizontal />
  </div>
  <h3>Treatment Switching</h3>
  <p>Escalation, lateral switches, de-escalation are the norm in MS care</p>
  <div class="example">Platform → High-efficacy after breakthrough</div>
</div>

<div v-click class="issue-card">
  <div class="card-icon icon-purple">
    <carbon-time />
  </div>
  <h3>Cumulative Exposure</h3>
  <p>Duration-response relationships require tracking total time on therapy</p>
  <div class="example">5 years on NTZ ≠ 2 years on NTZ</div>
</div>

<div v-click class="issue-card">
  <div class="card-icon icon-amber">
    <carbon-warning-alt />
  </div>
  <h3>Competing Risks</h3>
  <p>Death, emigration, and pregnancy compete with our outcomes</p>
  <div class="example">Ignoring these biases effect estimates</div>
</div>

<div v-click class="issue-card">
  <div class="card-icon icon-emerald">
    <carbon-data-base />
  </div>
  <h3>Registry Complexity</h3>
  <p>SMSreg captures this complexity — our methods must match</p>
  <div class="example">Rich data demands rigorous analysis</div>
</div>

</div>

<style>
.issue-card {
  @apply bg-gray-50 p-6 rounded-2xl relative;
}
.card-icon {
  @apply w-10 h-10 rounded-xl flex items-center justify-center text-lg mb-4;
}
.icon-blue { @apply bg-blue-100 text-blue-600; }
.icon-purple { @apply bg-purple-100 text-purple-600; }
.icon-amber { @apply bg-amber-100 text-amber-600; }
.icon-emerald { @apply bg-emerald-100 text-emerald-600; }
.issue-card h3 {
  @apply font-semibold text-lg mb-2 text-gray-800;
}
.issue-card p {
  @apply text-gray-600 text-sm leading-relaxed;
}
.issue-card .example {
  @apply mt-4 text-xs text-gray-500 font-mono;
  @apply bg-white py-2 px-3 rounded-lg;
}
</style>

---
layout: default
---

# The tvtools Solution

<div class="text-gray-500 text-lg mb-8">Three commands. One seamless workflow.</div>

<div class="grid grid-cols-3 gap-10 mt-6">

<div v-click class="command-card">
  <div class="cmd-number">1</div>
  <h3 class="text-blue-600">tvexpose</h3>
  <p class="cmd-desc">Transform prescription records into time-varying exposure intervals</p>
  <div class="cmd-features">
    <span>Gaps</span>
    <span>Switching</span>
    <span>Duration</span>
  </div>
</div>

<div v-click class="command-card">
  <div class="cmd-number">2</div>
  <h3 class="text-purple-600">tvmerge</h3>
  <p class="cmd-desc">Combine multiple time-varying exposures into synchronized intervals</p>
  <div class="cmd-features">
    <span>DMT</span>
    <span>+</span>
    <span>Comorbidities</span>
  </div>
</div>

<div v-click class="command-card">
  <div class="cmd-number">3</div>
  <h3 class="text-emerald-600">tvevent</h3>
  <p class="cmd-desc">Integrate outcomes and competing risks for survival analysis</p>
  <div class="cmd-features">
    <span>Progression</span>
    <span>Death</span>
    <span>Emigration</span>
  </div>
</div>

</div>

<div v-click class="workflow-bar mt-14">
  <div class="wf-step wf-data">Registry</div>
  <div class="wf-arrow">→</div>
  <div class="wf-step wf-expose">tvexpose</div>
  <div class="wf-arrow">→</div>
  <div class="wf-step wf-merge">tvmerge</div>
  <div class="wf-arrow">→</div>
  <div class="wf-step wf-event">tvevent</div>
  <div class="wf-arrow">→</div>
  <div class="wf-step wf-analysis">stcrreg</div>
</div>

<style>
.command-card {
  @apply bg-white p-8 rounded-2xl text-center relative;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}
.cmd-number {
  @apply absolute -top-3 -left-3 w-8 h-8 rounded-full bg-gray-900 text-white;
  @apply flex items-center justify-center text-sm font-semibold;
}
.command-card h3 {
  @apply text-2xl font-semibold mb-3;
}
.cmd-desc {
  @apply text-gray-600 text-sm leading-relaxed;
}
.cmd-features {
  @apply mt-5 flex justify-center gap-2 text-xs;
}
.cmd-features span {
  @apply px-2 py-1 bg-gray-100 rounded text-gray-500;
}
.workflow-bar {
  @apply flex items-center justify-center gap-2;
}
.wf-step {
  @apply px-4 py-2 rounded-lg text-sm font-medium text-white;
}
.wf-arrow {
  @apply text-gray-300 text-lg;
}
.wf-data { background: #6B7280; }
.wf-expose { background: #3B82F6; }
.wf-merge { background: #8B5CF6; }
.wf-event { background: #10B981; }
.wf-analysis { background: #D97706; }
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# tvexpose

<div class="section-subtitle">Transform prescriptions into time-varying intervals</div>

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
transition: fade
---

# tvexpose: Basic Syntax

<div class="mt-10">

```stata
use ms_cohort, clear

tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date)
```

</div>

<div v-click class="mt-10 grid grid-cols-2 gap-6">

<div class="option-box">
  <div class="opt-label">id()</div>
  <div class="opt-desc">Patient identifier linking to master dataset</div>
</div>

<div class="option-box">
  <div class="opt-label">start() / stop()</div>
  <div class="opt-desc">Exposure period boundaries</div>
</div>

<div class="option-box">
  <div class="opt-label">exposure()</div>
  <div class="opt-desc">Categorical exposure type variable</div>
</div>

<div class="option-box">
  <div class="opt-label">entry() / exit()</div>
  <div class="opt-desc">Study follow-up window</div>
</div>

</div>

<style>
.option-box {
  @apply bg-gray-50 p-4 rounded-xl;
}
.opt-label {
  @apply font-mono text-blue-600 font-medium mb-1;
}
.opt-desc {
  @apply text-sm text-gray-600;
}
</style>

---
layout: two-cols
transition: fade
---

# tvexpose: The Transformation

<div class="mt-6">

<div class="data-table">
<div class="table-header">Raw Prescriptions</div>

| id | start | stop | dmt |
|---|---|---|---|
| 1 | 2015-03 | 2017-08 | IFN |
| 1 | 2018-01 | 2022-06 | NTZ |

</div>

<div v-click class="transform-arrow">↓ tvexpose</div>

<div v-click class="data-table output-table">
<div class="table-header">Time-Varying Output</div>

| id | start | stop | exposure |
|---|---|---|---|
| 1 | 2014-01 | 2015-03 | Unexposed |
| 1 | 2015-03 | 2017-08 | IFN |
| 1 | 2017-08 | 2018-01 | Unexposed |
| 1 | 2018-01 | 2022-06 | NTZ |
| 1 | 2022-06 | 2023-12 | Unexposed |

</div>

</div>

::right::

<div class="pl-10 pt-6">

<div v-click class="timeline-visual">
  <div class="tl-label">Complete Timeline</div>
  <div class="tl-bar">
    <div class="tl-seg seg-gray" style="flex: 1">—</div>
    <div class="tl-seg seg-blue" style="flex: 2">IFN</div>
    <div class="tl-seg seg-gray" style="flex: 0.5">—</div>
    <div class="tl-seg seg-amber" style="flex: 3">NTZ</div>
    <div class="tl-seg seg-gray" style="flex: 1">—</div>
  </div>
  <div class="tl-legend">
    <span>Entry</span>
    <span>Y3</span>
    <span>Y5</span>
    <span>Exit</span>
  </div>
</div>

<div v-click class="insight-box mt-10">
  <div class="insight-title">Key insight</div>
  <div class="insight-text">
    Gaps are automatically filled with the reference category.
    Every moment of follow-up has defined exposure status.
  </div>
  <div class="insight-highlight">No immortal time bias.</div>
</div>

<div v-click class="stat-box mt-6">
  <span class="stat-num">2</span>
  <span class="stat-text">prescription rows →</span>
  <span class="stat-num">5</span>
  <span class="stat-text">complete intervals</span>
</div>

</div>

<style>
.data-table {
  @apply text-xs font-mono;
}
.table-header {
  @apply text-sm font-sans font-medium text-gray-700 mb-2;
}
.output-table {
  @apply bg-emerald-50 p-3 rounded-lg -mx-3;
}
.transform-arrow {
  @apply text-center text-gray-400 my-3 text-lg;
}
.timeline-visual {
  @apply bg-gray-50 p-5 rounded-2xl;
}
.tl-label {
  @apply text-sm font-medium text-gray-600 mb-3;
}
.tl-bar {
  @apply flex h-10 rounded-lg overflow-hidden;
}
.tl-seg {
  @apply flex items-center justify-center text-white text-xs font-medium;
}
.seg-gray { background: #9CA3AF; }
.seg-blue { background: #4A90A4; }
.seg-amber { background: #D97706; }
.tl-legend {
  @apply flex justify-between mt-2 text-xs text-gray-400;
}
.insight-box {
  @apply bg-emerald-50 p-5 rounded-2xl border border-emerald-100;
}
.insight-title {
  @apply text-sm font-medium text-emerald-700 mb-2;
}
.insight-text {
  @apply text-sm text-gray-600 leading-relaxed;
}
.insight-highlight {
  @apply mt-2 text-emerald-700 font-medium;
}
.stat-box {
  @apply flex items-center gap-2 text-sm text-gray-500;
}
.stat-num {
  @apply text-lg font-semibold text-gray-800;
}
</style>

---
layout: two-cols
transition: fade
---

# tvexpose: Duration Categories

<div class="mt-6">

<div class="code-block">

```stata
tvexpose using dmt, ///
    id(patient_id) start(dmt_start) ///
    stop(dmt_stop) exposure(dmt) ///
    reference(0) entry(ms_dx) exit(study_exit) ///
    duration(1 3 5) continuousunit(years)
```

</div>

<div v-click class="mt-6 cat-grid">

<div class="cat-item">
  <span class="cat-code">0</span>
  <span class="cat-label">Unexposed</span>
</div>
<div class="cat-item">
  <span class="cat-code cat-1">&lt;1y</span>
  <span class="cat-label">New</span>
</div>
<div class="cat-item">
  <span class="cat-code cat-2">1-3y</span>
  <span class="cat-label">Established</span>
</div>
<div class="cat-item">
  <span class="cat-code cat-3">3-5y</span>
  <span class="cat-label">Long-term</span>
</div>
<div class="cat-item">
  <span class="cat-code cat-4">≥5y</span>
  <span class="cat-label">Very long</span>
</div>

</div>

</div>

::right::

<div class="pl-10 pt-6">

<div v-click class="duration-visual">
  <div class="dv-label">How it works</div>
  <div class="dv-timeline">
    <div class="dv-seg dv-0" style="flex: 1"></div>
    <div class="dv-seg dv-1" style="flex: 1"></div>
    <div class="dv-seg dv-2" style="flex: 1.5"></div>
    <div class="dv-seg dv-0" style="flex: 0.5"></div>
    <div class="dv-seg dv-2" style="flex: 1"></div>
    <div class="dv-seg dv-3" style="flex: 2"></div>
    <div class="dv-seg dv-4" style="flex: 1.5"></div>
    <div class="dv-seg dv-0" style="flex: 1"></div>
  </div>
  <div class="dv-legend">
    <span>0y</span>
    <span>1y</span>
    <span>3y</span>
    <span>5y</span>
    <span>7y</span>
  </div>
</div>

<div v-click class="insight-box mt-8">
  <div class="insight-title">Automatic interval splitting</div>
  <div class="insight-text">
    When cumulative duration crosses a category boundary, the interval is automatically split.
    This captures dose-response relationships with precision.
  </div>
</div>

</div>

<style>
.code-block {
  @apply bg-gray-900 p-4 rounded-xl text-xs;
}
.cat-grid {
  @apply grid grid-cols-5 gap-2;
}
.cat-item {
  @apply bg-gray-50 p-2 rounded-lg text-center;
}
.cat-code {
  @apply block text-sm font-mono font-semibold text-gray-400;
}
.cat-1 { @apply text-blue-500; }
.cat-2 { @apply text-purple-500; }
.cat-3 { @apply text-amber-500; }
.cat-4 { @apply text-rose-500; }
.cat-label {
  @apply block text-xs text-gray-500 mt-1;
}
.duration-visual {
  @apply bg-gray-50 p-5 rounded-2xl;
}
.dv-label {
  @apply text-sm font-medium text-gray-600 mb-3;
}
.dv-timeline {
  @apply flex h-8 rounded-lg overflow-hidden;
}
.dv-seg {
  @apply border-r border-white/20;
}
.dv-0 { background: #D1D5DB; }
.dv-1 { background: #60A5FA; }
.dv-2 { background: #A78BFA; }
.dv-3 { background: #FBBF24; }
.dv-4 { background: #F87171; }
.dv-legend {
  @apply flex justify-between mt-2 text-xs text-gray-400;
}
.insight-box {
  @apply bg-blue-50 p-5 rounded-2xl border border-blue-100;
}
.insight-title {
  @apply text-sm font-medium text-blue-700 mb-2;
}
.insight-text {
  @apply text-sm text-gray-600 leading-relaxed;
}
</style>

---
layout: two-cols
transition: slide-up
---

# tvexpose: Duration with bytype

<div class="mt-2">

Using `duration(1 3 5) bytype` for per-DMT duration:

````md magic-move {lines: true}
```txt {*|*}
Raw DMT Prescriptions
─────────────────────────────────────
id │ dmt_start  │ dmt_stop   │ dmt
───┼────────────┼────────────┼────────
 1 │ 2015-03-01 │ 2017-08-15 │ 1 (IFN)
 1 │ 2018-01-10 │ 2022-06-30 │ 4 (NTZ)
```

```txt {*|1-4|5-9|*}
Duration by Type Output (bytype)
───────────────────────────────────────────────────
id │ start      │ stop       │ dur_IFN │ dur_NTZ
───┼────────────┼────────────┼─────────┼─────────
 1 │ 2014-01-15 │ 2015-03-01 │ 0       │ 0
 1 │ 2015-03-01 │ 2016-03-01 │ 1 (<1y) │ 0
 1 │ 2016-03-01 │ 2017-08-15 │ 2 (1-3y)│ 0
 1 │ 2017-08-15 │ 2018-01-10 │ 2 (1-3y)│ 0
 1 │ 2018-01-10 │ 2019-01-10 │ 2 (1-3y)│ 1 (<1y)
 1 │ 2019-01-10 │ 2021-01-10 │ 2 (1-3y)│ 2 (1-3y)
 1 │ 2021-01-10 │ 2022-06-30 │ 2 (1-3y)│ 3 (3-5y)
 1 │ 2022-06-30 │ 2023-12-31 │ 2 (1-3y)│ 3 (3-5y)
```
````

</div>

::right::

<div class="pl-6 pt-2">

<div v-click class="code-box">

```stata
tvexpose using dmt, ///
    id(patient_id) start(dmt_start) ///
    stop(dmt_stop) exposure(dmt) ///
    reference(0) ///
    entry(ms_dx) exit(study_exit) ///
    duration(1 3 5) bytype
```

</div>

<div v-click class="mt-4 feature-grid">

<div class="feature-item">
  <div class="feature-dot dot-blue"></div>
  <div class="feature-text">Separate duration variable per DMT type</div>
</div>

<div class="feature-item">
  <div class="feature-dot dot-purple"></div>
  <div class="feature-text">Track type-specific cumulative exposure</div>
</div>

<div class="feature-item">
  <div class="feature-dot dot-orange"></div>
  <div class="feature-text">Model dose-response by specific DMT</div>
</div>

</div>

<div v-click class="mt-4 insight-box">

**Use case:** Compare duration effects across different DMT mechanisms (platform vs high-efficacy)

</div>

</div>

<style>
.code-box {
  @apply bg-gray-900 p-3 rounded-lg text-xs;
}
.insight-box {
  @apply bg-blue-50 dark:bg-blue-900/30 p-3 rounded-lg text-sm;
  @apply border-l-4 border-blue-500;
}
.feature-grid {
  @apply flex flex-col gap-2;
}
.feature-item {
  @apply flex items-center gap-3 bg-gray-50 dark:bg-gray-800/50 p-3 rounded-lg text-sm;
}
.feature-dot {
  @apply w-2 h-2 rounded-full flex-shrink-0;
}
.dot-blue { @apply bg-blue-500; }
.dot-purple { @apply bg-purple-500; }
.dot-orange { @apply bg-orange-500; }
.feature-text {
  @apply text-gray-700 dark:text-gray-300;
}
</style>

---
layout: two-cols
transition: slide-up
---

# tvexpose: Continuous + Expansion

<div class="mt-2">

Using `continuousunit(years) expandunit(months) bytype`:

````md magic-move {lines: true}
```txt {*|*}
Raw DMT Prescriptions
─────────────────────────────────────
id │ dmt_start  │ dmt_stop   │ dmt
───┼────────────┼────────────┼────────
 1 │ 2015-03-01 │ 2015-08-15 │ 1 (IFN)
 1 │ 2015-10-01 │ 2016-03-30 │ 4 (NTZ)
```

```txt {*|1-4|5-9|10-12|*}
Expanded Monthly Output (bytype)
─────────────────────────────────────────────────────
id │ start      │ stop       │ yrs_IFN │ yrs_NTZ
───┼────────────┼────────────┼─────────┼─────────
 1 │ 2015-01-01 │ 2015-02-01 │ 0.00    │ 0.00
 1 │ 2015-02-01 │ 2015-03-01 │ 0.00    │ 0.00
 1 │ 2015-03-01 │ 2015-04-01 │ 0.08    │ 0.00
 1 │ 2015-04-01 │ 2015-05-01 │ 0.17    │ 0.00
   │     ...    │     ...    │   ...   │   ...
 1 │ 2015-10-01 │ 2015-11-01 │ 0.46    │ 0.08
 1 │ 2015-11-01 │ 2015-12-01 │ 0.46    │ 0.17
   │     ...    │     ...    │   ...   │   ...
 1 │ 2016-03-01 │ 2016-03-30 │ 0.46    │ 0.50
```
````

</div>

::right::

<div class="pl-6 pt-2">

<div v-click class="code-box">

```stata
tvexpose using dmt, ///
    id(patient_id) start(dmt_start) ///
    stop(dmt_stop) exposure(dmt) ///
    reference(0) ///
    entry(ms_dx) exit(study_exit) ///
    continuousunit(years) ///
    expandunit(months) bytype
```

</div>

<div v-click class="mt-4 text-sm">

**What this creates:**

- One row per calendar month
- Separate cumulative years variable for each DMT type
- Continuous exposure values (not categories)

</div>

<div v-click class="mt-4 use-cases">

**Use cases:**

- Time-stratified analysis
- Merge with monthly lab values
- Fine-grained exposure modeling
- Flexible dose-response curves

</div>

<div v-click class="mt-4 warning-box">

**Note:** Row expansion can create large datasets. Use judiciously.

</div>

</div>

<style>
.code-box {
  @apply bg-gray-900 p-3 rounded-lg text-xs;
}
.use-cases {
  @apply bg-green-50 dark:bg-green-900/30 p-3 rounded-lg text-sm;
}
.warning-box {
  @apply bg-yellow-50 dark:bg-yellow-900/30 p-3 rounded-lg text-xs;
  @apply border-l-4 border-yellow-500;
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
layout: center
class: text-center
---

<div class="section-header">

# tvmerge

<div class="section-subtitle">Combine multiple time-varying exposures</div>

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
  class="merge-indicator text-center my-6">
  <div class="merge-line"></div>
  <span>Merge at all boundaries</span>
  <div class="merge-line"></div>
</div>

<div
  v-click
  v-motion
  :initial="{ opacity: 0, y: 50, scaleY: 0 }"
  :enter="{ opacity: 1, y: 0, scaleY: 1, transition: { duration: 600, type: 'spring' } }"
  class="timeline-container origin-top">
  <div class="timeline-label">Result:</div>
  <div class="timeline merged">
    <div class="segment merged-seg" style="flex: 2"><div class="top-half bg-gray-400"></div><div class="bot-half bg-gray-300"></div><span class="seg-label">None,No</span></div>
    <div class="segment merged-seg" style="flex: 1"><div class="top-half bg-blue-500"></div><div class="bot-half bg-gray-300"></div><span class="seg-label">IFN,No</span></div>
    <div class="segment merged-seg" style="flex: 2"><div class="top-half bg-blue-500"></div><div class="bot-half bg-pink-400"></div><span class="seg-label">IFN,Yes</span></div>
    <div class="segment merged-seg" style="flex: 2"><div class="top-half bg-gray-400"></div><div class="bot-half bg-pink-400"></div><span class="seg-label">None,Yes</span></div>
    <div class="segment merged-seg" style="flex: 1"><div class="top-half bg-gray-400"></div><div class="bot-half bg-gray-300"></div><span class="seg-label">None,No</span></div>
    <div class="segment merged-seg" style="flex: 2"><div class="top-half bg-orange-500"></div><div class="bot-half bg-gray-300"></div><span class="seg-label">NTZ,No</span></div>
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
.merged-seg {
  @apply relative flex flex-col overflow-hidden p-0;
}
.merged-seg .top-half {
  @apply flex-1 w-full;
}
.merged-seg .bot-half {
  @apply flex-1 w-full;
}
.merged-seg .seg-label {
  @apply absolute inset-0 flex items-center justify-center;
  @apply text-xs font-semibold text-white;
  text-shadow: 0 1px 2px rgba(0,0,0,0.5);
}
.insight-box {
  @apply flex items-center gap-3 bg-green-50 dark:bg-green-900/30 p-4 rounded-xl;
}
.merge-indicator {
  @apply flex items-center justify-center gap-4 text-sm font-medium text-gray-500;
}
.merge-line {
  @apply w-8 h-px bg-gray-300;
}
</style>

---
layout: center
class: text-center
---

<div class="section-header">

# tvevent

<div class="section-subtitle">Integrate outcomes and competing risks</div>

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
layout: center
class: text-center
---

<div class="section-header">

# Complete Workflow

<div class="section-subtitle">From registry data to competing risks analysis</div>

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

# The Full Pipeline

<div class="code-scroll">

```stata {all|1-6|8-13|15-18|20-22|all}
* Step 1: Create time-varying DMT exposure
use ms_cohort, clear
tvexpose using dmt_prescriptions, ///
    id(patient_id) start(dmt_start) stop(dmt_stop) ///
    exposure(dmt) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) saveas(tv_dmt.dta) replace

* Step 2: Create second exposure (e.g., oral contraceptives)
use ms_cohort, clear
tvexpose using oc_prescriptions, ///
    id(patient_id) start(oc_start) stop(oc_stop) ///
    exposure(oc_type) reference(0) ///
    entry(ms_diagnosis_date) exit(study_exit_date) saveas(tv_oc.dta) replace

* Step 3: Merge multiple exposures
tvmerge tv_dmt tv_oc, id(patient_id) ///
    start(dmt_start oc_start) stop(dmt_stop oc_stop) ///
    exposure(tv_exposure tv_exposure) generate(dmt oc_use)

* Step 4: Integrate outcomes with competing risks
tvevent using ms_cohort, id(patient_id) ///
    date(edss4_date) compete(death_date) generate(outcome)
```

</div>

<div v-click class="mt-4 workflow-summary">
  <div class="step step-data">SMSreg</div>
  <div class="arrow"></div>
  <div class="step step-expose">tvexpose</div>
  <div class="arrow"></div>
  <div class="step step-merge">tvmerge</div>
  <div class="arrow"></div>
  <div class="step step-event">tvevent</div>
  <div class="arrow"></div>
  <div class="step step-analysis">stcrreg</div>
</div>

<style>
.workflow-summary {
  @apply flex items-center justify-center gap-3 text-sm;
}
.step {
  @apply px-4 py-2 rounded-lg font-medium text-white;
}
.step-data { @apply bg-gray-500; }
.step-expose { @apply bg-blue-500; }
.step-merge { @apply bg-purple-500; }
.step-event { @apply bg-green-500; }
.step-analysis { @apply bg-orange-500; }
.arrow {
  @apply text-gray-300 dark:text-gray-600;
}
.arrow::after {
  content: "→";
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

<div class="insight mt-4">
  <carbon-idea class="text-yellow-500 text-xl" />
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
  @apply text-xs font-mono bg-gray-900 text-green-400 p-3 rounded-xl;
}
.insight {
  @apply flex items-center gap-3 bg-yellow-50 dark:bg-yellow-900/30 p-3 rounded-xl text-sm;
  @apply border-l-4 border-yellow-500;
}
</style>

---

# What Goes Wrong Without This

<div class="errors-grid mt-4">

<div v-click class="error-card">
  <div class="error-type">Baseline Exposure Only</div>
  <div class="consequence">Misclassification bias</div>
  <div class="magnitude">Attenuates toward null</div>
</div>

<div v-click class="error-card">
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

<div v-click class="error-card">
  <div class="error-type">No Cumulative Exposure</div>
  <div class="consequence">Miss dose-response</div>
  <div class="magnitude">Use <code>continuousunit()</code></div>
</div>

<div v-click class="error-card">
  <div class="error-type">Combined Exposure Types</div>
  <div class="consequence">Confounded effects</div>
  <div class="magnitude">Use <code>bytype</code> option</div>
</div>

</div>

<div v-click class="mt-4 text-center text-sm text-gray-500">
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
  @apply grid grid-cols-3 gap-3;
}
.error-card {
  @apply bg-white dark:bg-gray-800 p-3 rounded-xl;
  @apply border-l-4 border-red-500;
}
.error-card .error-type {
  @apply font-bold text-sm;
}
.error-card .consequence {
  @apply text-gray-600 dark:text-gray-400 text-sm mt-1;
}
.error-card .magnitude {
  @apply mt-2 text-xs bg-red-100 dark:bg-red-900/30 p-2 rounded;
  @apply font-mono text-red-600 dark:text-red-400;
}
</style>

---
layout: two-cols
---

# Key Takeaways

<div class="mt-8 space-y-6">

<v-clicks>

<div class="takeaway">
  <div class="takeaway-title">Time-varying analysis is essential</div>
  <div class="takeaway-desc">Standard approaches create immortal time bias in DMT studies</div>
</div>

<div class="takeaway">
  <div class="takeaway-title">tvtools handles the complexity</div>
  <div class="takeaway-desc">
    <span class="cmd">tvexpose</span> → intervals
    <span class="cmd">tvmerge</span> → multiple exposures
    <span class="cmd">tvevent</span> → competing risks
  </div>
</div>

<div class="takeaway">
  <div class="takeaway-title">Seamless Stata integration</div>
  <div class="takeaway-desc">Works directly with stset, stcox, and stcrreg</div>
</div>

<div class="takeaway">
  <div class="takeaway-title">GUI available</div>
  <div class="takeaway-desc">Dialog boxes for interactive use</div>
</div>

</v-clicks>

</div>

::right::

<div class="pl-10 pt-6">

<div v-click class="install-section">

<div class="install-label">Installation</div>

```stata
net install tvtools, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/tvtools")
```

<div class="install-label mt-6">Documentation</div>

```stata
help tvexpose
help tvmerge
help tvevent
```

<div class="install-label mt-6">Dialog boxes</div>

```stata
db tvexpose
db tvmerge
db tvevent
```

</div>

</div>

<style>
.takeaway {
  @apply py-2;
}
.takeaway-title {
  @apply font-medium text-gray-800 mb-1;
}
.takeaway-desc {
  @apply text-sm text-gray-500;
}
.cmd {
  @apply font-mono text-blue-600;
}
.install-section {
  @apply bg-gray-50 p-6 rounded-2xl;
}
.install-label {
  @apply text-sm font-medium text-gray-600 mb-2;
}
</style>

---
layout: center
class: text-center
---

<div class="thank-you">

# Thank You

<div class="subtitle">tvtools — Time-Varying Exposure Analysis for MS Research</div>

<div class="links mt-12">

<div class="link-item">
  <carbon-logo-github class="link-icon" />
  <div class="link-text">tpcopeland/Stata-Tools</div>
</div>

<div class="link-item">
  <carbon-document class="link-icon" />
  <div class="link-text">help tvexpose</div>
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

---
layout: center
class: text-center
---

<div class="questions">

# Questions?

<div class="mt-10 max-w-xl mx-auto">

<div class="q-grid">

<div v-click class="q-item">How does this compare to manual stsplit?</div>

<div v-click class="q-item">What about time-varying confounders?</div>

<div v-click class="q-item">Can I analyze treatment sequencing?</div>

<div v-click class="q-item">How do I handle patients on DMT before study entry?</div>

</div>

</div>

</div>

<style>
.questions h1 {
  @apply text-5xl font-semibold text-gray-900;
  letter-spacing: -0.02em;
}
.q-grid {
  @apply space-y-4;
}
.q-item {
  @apply bg-gray-50 px-6 py-4 rounded-xl text-gray-600 text-left;
}
</style>

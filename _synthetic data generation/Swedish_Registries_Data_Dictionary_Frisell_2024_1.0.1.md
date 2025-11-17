# Data Dictionary of Swedish Registries

 Based on [Thomas Frisell's](https://ki.se/personer/thomas-frisell) 2024 MS Registry Extract with Matched Controls 

 Version 1.0.1

## Table of Contents
1. [LISA - Socioeconomic Dataset](#1-lisa---socioeconomic-dataset)
2. [RTB - Residence Data](#2-rtb---residence-data)
3. [Case Control Data](#3-case-control-data)
4. [SBC Demographics](#4-sbc-demographics)
5. [Migrations](#5-migrations)
6. [Migrations Wide](#6-migrations-wide)
7. [Inpatient Registry](#7-inpatient-registry)
8. [Outpatient Registry](#8-outpatient-registry)
9. [Prescription Registry (Rx)](#9-prescription-registry-rx)
10. [MS Registry Datasets](#10-ms-registry-datasets)
    - [Relapses (skov)](#101-ms-relapses-skov)
    - [Visits (besoksdata)](#102-ms-visits-besoksdata)
    - [Therapy/DMTs (terapi)](#103-ms-therapydmts-terapi)
    - [EDSS](#104-ms-edss)
    - [EDSS from Visits](#105-ms-edss-from-visits)
    - [Baseline/Core Dataset (basdata)](#106-ms-baselinecore-dataset-basdata)
    - [SDMT](#107-ms-sdmt)
    - [Smoking](#108-ms-smoking)
11. [Birth Registry](#11-birth-registry)
12. [Cancer Registry](#12-cancer-registry)
13. [Death Registry](#13-death-registry) 
14. [Notes](#notes)
15. [Change Log](#change-log)
---

## 1. LISA - Socioeconomic Dataset

**Filename:** `lisa.dta`  
**Description:** LISA Socioeconomic Dataset containing comprehensive socioeconomic, employment, income, and benefit information for Swedish residents.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Personal number | Numeric | Unique identifier |
| `year` | Year | Numeric | Year of observation |
| `educ_lev` | Highest education level (7 categories) | Numeric | 1=Primary <9 yrs, 2=Primary 9 yrs, 3=Secondary <=2 yrs, 4=Secondary 3 yrs, 5=Tertiary <2 yrs, 6=Tertiary >=2 yrs, 7=Postgraduate, 99=Unknown |
| `educ_lev` | Highest education level (granular) | String | Detailed field code |
| `grad_year` | Graduation year | Numeric | Year of graduation |
| `source_code` | Data source code | String | Code indicating data source |
| `emp_status_old` | Employment status (old method) | Numeric | 1=Employed, 5=Not employed has earnings, 6=Not employed no earnings |
| `emp_status` | Employment status (Nov) | Numeric | 1=Employed, 5=Not employed has earnings, 6=Not employed no earnings |
| `emp_status_j` | Employment status adjusted 2004 | Numeric | 1=Employed, 5=Not employed has earnings, 6=Not employed no earnings |
| `emp_status_11` | Employment status 2011 method | Numeric | 1=Employed, 5=Not employed has earnings, 6=Not employed no earnings |
| `emp_status_19` | Employment status 2019 method | Numeric | 1=Employed, 5=Not employed has earnings, 6=Not employed no earnings |
| `emp_type` | Employment type (Nov) | Numeric | 0=No taxable income, 1=Sailors, 2=Employed, 3=Self-employed combination, 4=Self-employed, 5=Self-employed w/ company |
| `emp_type_j` | Employment type adjusted 2004 | Numeric | 0=No taxable income, 1=Sailors, 2=Employed, 3=Self-employed combination, 4=Self-employed, 5=Self-employed w/ company |
| `emp_comb` | Combined employment status | String | Combined status code |
| `wage_inc` | Wage income | Numeric | Wage income amount |
| `wage_inc_j` | Wage income adjusted 2004 | Numeric | Wage income amount adjusted |
| `se_inc_net` | Net self-employment income | Numeric | Net income from self-employment (active) |
| `se_inc_net_act` | Net self-employment income (active) | Numeric | Net income from self-employment (all) |
| `wage_declared` | Declared wage income | Numeric | Declared wage income amount |
| `disp_inc` | Disposable income (individual) | Numeric | Individual disposable income |
| `disp_inc_fam` | Disposable income (family) | Numeric | Family disposable income |
| `disp_inc_cons` | Disposable income (consumption equivalent) | Numeric | Consumption equivalent disposable income |
| `disp_inc_04` | Disposable income 2004 method | Numeric | Disposable income using 2004 method |
| `disp_inc_fam_04` | Disposable income family 2004 method | Numeric | Family disposable income using 2004 method |
| `disp_inc_cons_04` | Disposable income consumption equiv 2004 | Numeric | Consumption equivalent using 2004 method |
| `disp_inc_04_lgp` | Disposable income 2004 incl long-term pension | Numeric | 2004 method including long-term pension |
| `disp_inc_fam_04_lgp` | Disposable income family 2004 incl long-term pension | Numeric | Family income 2004 method including long-term pension |
| `disp_inc_cons_04_lgp` | Disposable income consumption equiv 2004 incl lgp | Numeric | Consumption equivalent 2004 including long-term pension |
| `sick_bin` | Presence of sick-leave/work-related injury compensation | Numeric | 0=No, 1=Yes |
| `unemp_inc` | Unemployment income sum | Numeric | Number of unemployment days |
| `unemp_comp_type` | Tyep of unemployment compensation | Numeric | 0=No, 1=Yes |
| `sick_started_n` | # of sickness spells started during the year | Numeric | Count of sickness spells started |
| `sick_ended_n` | # of sickness spells ended during the year | Numeric | Count of sickness spells ended |
| `sick_spells_transitioned` | # of sickness spells transitioned to sick-leave, work-injury, rehab comp. | Numeric | Total count of sickness spells |
| `sick_days_comp` | Sickness days with compensation | Numeric | Days with sickness compensation |
| `sick_days_net` | Sickness days net | Numeric | Net sickness days |
| `sick_amt` | Sickness benefit amount | Numeric | Total sickness benefit amount |
| `sick_days_comp_p` | Sickness days compensated (period) | Numeric | Period-specific compensated days |
| `sick_days_net_p` | Sickness days net (period) | Numeric | Period-specific net days |
| `sick_amt_p` | Sickness benefit amount (period) | Numeric | Period-specific benefit amount |
| `sick_days_empl` | Employer-paid sickness days | Numeric | Days paid by employer |
| `sick_days_empl_net` | Employer-paid sickness days net | Numeric | Net employer-paid days |
| `sick_amt_empl` | Employer-paid sickness benefit amount | Numeric | Employer-paid benefit amount |
| `di_days_comp` | Disability pension days compensated | Numeric | Compensated disability pension days |
| `di_days_net` | Disability pension days net | Numeric | Net disability pension days |
| `di_amt` | Disability pension amount | Numeric | Disability pension amount |
| `di_days_total` | Disability pension total days | Numeric | Total disability pension days |
| `sick_comp_days` | Sickness compensation days | Numeric | Days of sickness compensation |
| `sick_comp_days_net` | Sickness compensation days net | Numeric | Net sickness compensation days |
| `sick_comp_amt` | Sickness compensation amount | Numeric | Sickness compensation amount |
| `forpeng_days_comp` | Parental benefit days compensated | Numeric | Compensated parental benefit days |
| `forpeng_days_net` | Parental benefit days net | Numeric | Net parental benefit days |
| `forpeng_amt` | Parental benefit amount | Numeric | Parental benefit amount |
| `forpeng_days_comp_m` | Parental benefit days compensated (MIDAS) | Numeric | MIDAS compensated parental days |
| `forpeng_days_net_m` | Parental benefit days net (MIDAS) | Numeric | MIDAS net parental days |
| `forpeng_amt_m` | Parental benefit amount (MIDAS) | Numeric | MIDAS parental benefit amount |
| `forpeng_days_total` | Parental benefit total days | Numeric | Total parental benefit days |
| `sa_bin` | Social assistance presence | Numeric | 0=No, 1=Yes |
| `disab_allow` | Disability Allowance | Numeric | Per-person housing cost |
| `sa_fam` | Social assistance (family) | Numeric | Family social assistance amount |
| `sa_share` | Assistance shared with primary & coapplicants | Numeric | Unemployment social assistance |
| `rehab_bin` | Rehabilitation compensation presence | Numeric | 0=No, 1=Yes |
| `unemp_status` | Unemployment status (PES) | Numeric | 0=Not seeking, 1=With UI, 2=Without UI, 3=In program, 4=Subsidized job |
| `almp_type` | ALMP program type | Numeric | 0=None, 1=Training, 2=Subsidized job, 3=Other program |
| `unemp_pes_days` | Unemployment days (PES) | Numeric | PES unemployment days |
| `unemp_partial_days` | Partial unemployment days | Numeric | Days of partial unemployment |
| `pes_jobseeker` | Job seeker at PES in Nov | Numeric | 0=No, 1=Full-time seeking, 2=Part-time seeking, 3=Program participant, 4=Subsidized employment, 5=Other |
| `brutto_days` | Brutto days w/ activity comp. | Numeric | Compensated activity support days |
| `activity_supp_days_net` | Activity support days net | Numeric | Net activity support days |
| `activity_supp_amt` | Activity support amount | Numeric | Activity support amount |
| `educ_lev_old_20` | Highest Education Level | Numeric | 1=Primary <9 yrs, 2=Primary 9 yrs, 3=Secondary <=2 yrs, 4=Secondary 3 yrs, 5=Tertiary <2 yrs, 6=Tertiary >=2 yrs, 7=Postgraduate, 99=Unknown |
| `educ_lev_old_20` | Highest Education Level | String | 2020 classification field code |
| `substitute_inc` | Additional cost compensation | Numeric | Substitute income amount |
| `sick_spell_start` | Sickness spell start date | Date | Date of sickness spell start |

---

## 2. RTB - Residence Data

**Filename:** `rtb.dta`  
**Description:** Residence Data containing civil status and municipality information.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `married` | Civil/marital status code | String | Civil/marital status code |
| `city` | Municipality code | String | Municipality code |
| `yr` | Year of RTB Data | Numeric | Year of residence data |

---

## 3. Case Control Data

**Filename:** `ccids.dta`  
**Description:** Case/Control Data containing matched case-control study identifiers and matching information.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `case` | Case=1/Control=0 | Numeric | 0=Control, 1=Case |
| `matchid` | Match ID | Numeric | Unique match identifier |
| `indexdate` | Index date | Date | Index date for case-control matching |
| `byear` | Birth year | Numeric | Year of birth |
| `sex` | Sex | Numeric | 1=Male, 2=Female |
| `region` | Region Code | String | Region code |

**Note:** Individuals who appear as both case and control are deduplicated, keeping only their case record.

---

## 4. SBC Demographics

**Filename:** `sbc_demos.dta`  
**Description:** SBC Demographics containing basic demographic information from Statistics Sweden.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `sex` | Sex | Numeric | 1=Male, 2=Female |
| `bcountry` | Birth country | String | Birth country code |
| `deathdt` | Date of death | Date | Date of death (if deceased) |
| `dob` | Date of birth | Date | Date of birth |

---

## 5. Migrations

**Filename:** `migrations.dta`  
**Description:** Migration Data containing emigration and immigration events.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `event_date` | Event date | Date | Date of migration event |
| `event_type` | Event type | String | "Inv" (immigration) or "Utv" (emigration) |

---

## 6. Migrations Wide

**Filename:** `migrations_wide.dta`  
**Description:** Migration Data reshaped to wide format with separate columns for each immigration and emigration event.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `in_1` to `in_13` | Immigration dates | Date | Immigration event dates (numbered sequentially) |
| `out_1` to `out_13` | Emigration dates | Date | Emigration event dates (numbered sequentially) |

---

## 7. Inpatient Registry

**Filename:** `inpatient.dta`  
**Description:** Inpatient (1964-2025) - Hospital inpatient care episodes with diagnoses, procedures, and administrative information.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `dischyear` | Discharge year | Numeric | Year of discharge |
| `admitdt` | Admission date | Date | Date of hospital admission |
| `disdt` | Discharge date | Date | Date of hospital discharge |
| `hospital` | Hospital code | String | Hospital identifier code |
| `medarea` | Medical specialty area code (MVO) | Numeric | Medical specialty (see value labels below) |
| `los` | Length of stay (days) | Numeric | Number of days in hospital |
| `planned` | Planned care contact | Numeric | 1=Planned, 2=Unplanned |
| `admittype` | Admission mode/type | Numeric | 1=Other hospital/clinic, 2=Specialized housing, 3=Ordinary housing |
| `dx1` to `dx30` | Secondary Diagnoses 1-30 | String | ICD diagnosis codes |
| `ext1` to `ext5` | External cause code 1-5 | String | External cause codes |
| `proc1` to `proc30` | Procedure 1-30 | String | Procedure codes |
| `dt_proc1` to `dt_proc30` | Date Proc 1-30 | Date | Dates of procedures |
| `drgchap` | DRG chapter | String | Diagnosis-related group chapter |
| `finalreported` | Contact reported final within 3-month window | String | Final reporting status |
| `tdis` | Mode of Discharge | Numeric | 1=Other hospital/Clinic, 2=Specialized Housing, 3=Ordinary Housing, 4=Deceased |
| `bcontinent` | Birth continent | Numeric | 1=Europe, 2=Asia, 3=Africa, 4=South America, 5=North America, 6=Oceana, 7=Other |
| `atco` | ATC Codes | String | Anatomical Therapeutic Chemical codes |
| `drg` | Diagnosis-related group (DRG) | String | DRG code |
| `rtc` | Return Code from DRG | Numeric | 0=Grouping accomplished, 1=Missing main diagnosis, 2=Missing sex, 3=Invalid combination of sex and diagnosis, 4=Age too low for diagnosis, 5=Age too high for diagnosis, 6=Invalid age >125 years, 7=Unusual procedures within MDC, 8=Main diagnosis invalid, 9=Other error |
| `ndx` | Number of reported diagnoses | Numeric | Count of diagnoses |
| `nproc` | Number of procedures | Numeric | Count of procedures |

**Medical Specialty Area (medarea) Values:**
3=Maternal health care (antenatal), 9=Child health services, 11=General practitioner care, 14=District nurse services, 15=On-call physician services, 16=General care, 19=Primary care-affiliated home healthcare, 20=Health care in special housing, 21=Short-term care, 22=Occupational health services, 23=School health services, 24=Youth clinic care, 41=Observation unit care, 45=Ambulance services, 46=Admissions/Emergency services, 56=Low-acuity care, 61=Palliative care, 76=Aftercare, 86=Convalescent care, 96=Day hospital care, 100=Acute clinic (emergency department), 101=Internal medicine, 105=Gastroenterology, 107=Cardiovascular medicine, 108=Hematology, 109=Stroke care, 111=Respiratory medicine, 121=Infectious diseases, 131=Rheumatology, 141=Allergy medicine, 142=Pediatric allergy medicine, 151=Nephrology, 156=Dialysis care, 161=Endocrinology, 171=Occupational medicine, 181=Environmental medicine, 201=Pediatric medicine, 203=Pediatric cardiology, 206=Preterm infant care, 207=Neonatal intensive care, 211=Dermatology and venereology, 215=Occupational dermatology, 221=Neurology, 231=Cardiology, 241=Geriatrics, 243=Hospital-affiliated home healthcare, 246=Long-term care medicine, 249=Geriatric rehabilitation, 251=Pediatric neurology, 301=Surgery, 303=Gastrointestinal care, 304=Vascular surgery, 306=Burns care, 311=Orthopedics, 312=Spine care, 316=Oral and maxillofacial surgery, 321=Hand surgery, 331=Neurosurgery, 335=Neurotrauma care, 341=Thoracic surgery, 351=Plastic surgery, 361=Urology, 371=Transplant surgery, 401=Pediatric surgery, 411=Anesthesia and intensive care, 412=Pain management, 413=Pediatric anesthesiology, 421=Specialized anesthesia care, 431=Gynecology, 441=Maternity/delivery care, 451=Obstetrics and gynecology, 511=Ophthalmology, 515=Orthoptics, 521=Otolaryngology (ENT), 531=Audiology, 532=Pediatric audiology, 541=Phoniatrics, 551=Rehabilitation medicine, 552=Neurological rehabilitation, 553=Habilitation, 561=Physiotherapy services, 564=Occupational therapy services, 565=Sports medicine, 566=Chiropractic services, 567=Naprapathy services, 570=General dentistry, 571=Oral surgery, 572=Specialist dental care, 573=Dental hygienist services, 581=Social medicine, 601=Poison Information Centre, 611=Pharmacy services, 711=Clinical pathology, 712=Forensic medicine, 713=Clinical histopathology, 715=Clinical cytology, 721=Radiopathology, 722=Nuclear medicine lab/department, 731=Medical radiology, 741=Oncology general, 751=Gynecologic oncology, 761=Pediatric radiology, 762=Thoracic radiology, 763=Neuroradiology, 811=Transfusion medicine, 821=Clinical bacteriology, 831=Clinical physiology, 832=Clinical physiology - thorax, 841=Clinical chemistry, 845=Coagulation and bleeding disorders, 851=Clinical neurophysiology, 881=Clinical pharmacology, 882=Clinical genetics, 883=Clinical nutrition, 892=Clinical allergology, 893=Medical radiation physics, 894=Clinical virology, 895=Hormone laboratory, 896=Clinical immunology, 901=General adult psychiatry, 906=Psychiatric nursing home care, 928=Geriatric psychiatry, 931=Child and adolescent psychiatry, 943=Forensic psychiatric regional care, 944=Specialized psychiatric care, 945=Alcohol treatment services, 948=Psychotherapy services, 950=Medical social work services, 951=Psychology services, 952=Family care, 953=Substance dependence care, 954=Drug addiction care, 955=Somatic care at psychiatric hospital, 956=Forensic psychiatric assessment services, 957=Psychiatric rehabilitation, 971=Care under the Communicable Diseases Act, 991=Care for persons with intellectual disability adults, 993=Care for persons with intellectual disability children

---

## 8. Outpatient Registry

**Filename:** `out_YYYY.dta` (separate files for years 1997-2025)  
**Description:** Outpatient Visits (YYYY) - Specialized outpatient care visits with diagnoses and procedures.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `vyear` | Visit year | Numeric | Year of visit |
| `visitdt` | Visit date | Date | Date of outpatient visit |
| `hospital` | Hospital code | String | Hospital identifier code |
| `medarea` | Medical specialty area code (MVO) | Numeric | Medical specialty (see inpatient section for codes) |
| `otype` | Form of outpatient contact | Numeric | 0=1 patient 1 care professional, 1=1 patient several professionals >1 responsible, 2=several patients 1 professional, 3=several patients several professionals, 4=patient's home 1 professional, 5=patient's home several healthcare professionals, 6=1 patient in another place 1 professional, 7=1 patient in another place several professionals, 8=distance contact |
| `planned` | Planned visit (coding per PR spec) | String | Planned visit indicator |
| `dx1` to `dx30` | Secondary Diagnoses 1-30 | String | ICD-10 diagnosis codes |
| `ndx` | Number of reported diagnoses | Numeric | Count of diagnoses |
| `ext1` to `ext7` | External cause code 1-7 | String | External cause codes |
| `nproc` | Number of procedures | Numeric | Count of procedures |
| `proc1` to `proc30` | Procedure 1-30 | String | Procedure codes |
| `drgchap` | DRG chapter | String | Diagnosis-related group chapter |
| `ed_assess_tc` | ED physician assessment time (%tc) | Clock time | Emergency department physician assessment time |
| `ed_end_tc` | ED contact end time (%tc) | Clock time | Emergency department contact end time |
| `edactivity` | "ED activity code"  // Akutverksamhet. | Numeric | 0=Non-emergency service, 1=Emergency department 2+ somatic specialities co-located, 2=Emergency department 1 somatic speciality, 3=Psychiatric emergency department, 4=Urgent care, 5=Other emergency service |
| `finalreported` | Contact reported final within 3-month window | String | Final reporting status |
| `lk` | County municipality code (from 2016) | String | County/municipality code (2016+) |
| `lkf` | County municipality code (through 2015) | String | County/municipality code (through 2015) |
| `atco` | ATC Codes | String | Anatomical Therapeutic Chemical codes |
| `drg` | Diagnosis-related group (DRG) | String | DRG code |
| `rtc` | Return Code from DRG | Numeric | 0=Grouping accomplished, 1=Missing main diagnosis, 2=Missing sex, 3=Invalid combination of sex and diagnosis, 4=Age too low for diagnosis, 5=Age too high for diagnosis, 6=Invalid age >125 years, 7=Unusual procedures within MDC, 8=Main diagnosis invalid, 9=Other error |

---

## 9. Prescription Registry (Rx)

**Filename:** `rx_YYYY.dta` (separate files for years 2005-2025)  
**Description:** Prescriptions (YYYY) - Dispensed prescription medications with prescriber and product information.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Anon Person ID | Numeric | Anonymous person identifier |
| `dispyear` | Dispensing year | Numeric | Year of dispensing |
| `dispdt` | Dispensing date | Date | Date medication was dispensed |
| `prescdt` | Prescription date | Date | Date medication was prescribed |
| `atc` | ATC code | String | Anatomical Therapeutic Chemical code |
| `substance` | Substance name | String | Active substance name |
| `packddd` | Package DDD (Defined Daily Doses) | Numeric | Package defined daily doses |
| `packsize` | Package size | Numeric | Package size |
| `strength` | Strength (text) | String | Drug strength as text |
| `strengthnum` | Strength (numeric) | Numeric | Drug strength numeric value |
| `strengthunit` | Strength unit | String | Unit of drug strength |
| `npacks` | Number of packages | Numeric | Number of packages dispensed |
| `product` | Drug product | String | Drug product name |
| `dosetxt` | Dosage text | String | Dosage instructions |
| `workplid` | Prescriber's workplace pseudonym | String | Pseudonymized workplace identifier |
| `spec1` to `spec3` | Physician specialty code 1-3 | Numeric | Specialty codes (see values below) |
| `ordtype` | Order type / mode of sale | Numeric | 0=Dose-dispensable daily dose, 1=Dose-dispensable non-daily dose, 2=Dose-standing whole pack, 3=Dose-as needed whole pack, 4=Dose-aid whole pack, 5=Prescription, 6=Aid Card, 7=Food Instructions, 8=Food for Adults |
| `benetype` | Benefit type within pharmaceutical benefits | Numeric | 1=Free, 2=Food for children, 3=Discounted, 4=Outside benefit no discount, 5=Refund of benefit, 6=Outside benefit other payer |
| `transtype` | Transaction type | Numeric | 1=Prescription for dose patients, 2=Regular Prescription |
| `itemtype` | Item type | Numeric | 1=Basic service county council agreement, 2=Commodity, 3=Outpatient care, 4=Prescription required, 5=Over-the-counter, 6=Additional service county council agreement |
| `totcost` | Total cost (excl. VAT) | Numeric | Total cost excluding VAT |
| `regcost` | County/benefit cost (excl. VAT) | Numeric | County/benefit cost excluding VAT |
| `patcost` | Patient cost (excl. VAT) | Numeric | Patient out-of-pocket cost excluding VAT |
| `itemno` | Dispensed item number | String | Dispensed item number |
| `itemno_rx` | Prescribed item number (if different) | String | Prescribed item number |
| `nameform` | Product name + form/strength | String | Product name with formulation |
| `form` | Drug/administration form | String | Drug form/route |
| `prctype` | Price type | Numeric | 1=Generic, 2=Original, 3=Unspecified, 4=Parallel Distribution, 5=Parallel Import |
| `packnum` | Pack size numeric (no unit) | Numeric | Numeric pack size |

**Physician Specialty Codes (spec1-spec3):**
0=General practice, 1=Anesthesiology & intensive care / Pediatric dentistry, 2=Orthodontics, 3=Periodontology, 4=Oral surgery, 5=Pediatrics / Endodontics, 6=Prosthodontics, 7=Dental and maxillofacial radiology, 8=Dermatology & venereology / Oral physiology, 9=Special training in pharmacology & pathology (district nurse), 10=Internal medicine, 11=Endocrinology and diabetology, 12=Cardiology, 13=Infectious diseases, 14=Pulmonology, 15=Gastroenterology and hepatology, 16=Nephrology, 17=Rheumatology, 18=Geriatrics, 19=Occupational and environmental medicine, 20=Surgery, 21=Pediatric surgery, 22=Hand surgery, 23=Neurosurgery, 24=Orthopedics, 25=Plastic surgery, 26=Thoracic surgery, 27=Urology, 30=Clinical immunology and transfusion medicine, 31=Clinical bacteriology and virology, 32=Clinical physiology, 33=Clinical chemistry, 34=Clinical neurophysiology, 35=Clinical pathology, 36=Clinical bacteriology and virology, 37=Clinical immunology and transfusion medicine, 40=Obstetrics and gynecology, 45=Neurology, 50=Psychiatry, 51=Child and adolescent psychiatry, 52=Forensic psychiatry, 54=Social medicine, 60=Medical radiology, 61=Oncology, 62=Gynecologic oncology, 65=Ophthalmology, 70=Otolaryngology (ENT), 71=Audiology, 72=Voice and speech disorders, 73=Pain management, 74=Nuclear medicine, 75=Rehabilitation medicine, 76=Hematology, 77=Allergic diseases, 78=Pediatric allergology, 79=Pediatric neurology with habilitation, 80=Diseases of the teeth, 81=Massage and physiotherapy, 82-90=Various radiotherapy specialties, 91-98=Various subspecialties, 99=General practice, 100-101=European GP qualification, 199-9999=Extended specialty codes, 10010-80800=Detailed specialty codes, 99001-99201=Additional specialties

---

## 10. MS Registry Datasets

### 10.1 MS Relapses (skov)

**Filename:** `msreg_skov.dta`  
**Description:** MS Registry relapse data containing information about multiple sclerosis relapses/attacks.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `center` | Healthcare center | String | Healthcare center code |
| `total_relapses` | Total relapses | Numeric | Total count of relapses for patient |
| `relapse_dt` | Relapse date | Date | Date of relapse |
| `relapse_dt_approx` | Relapse date approximation | Numeric | 1=Month, 2=Year |
| `debut_relapse` | Debut/first relapse | Numeric | 0=No, 1=Yes |
| `steroid_tx` | Steroid treatment given | Numeric | 0=No, 1=Yes |
| `plasmapheresis_tx` | Plasmapheresis treatment given | Numeric | 0=No, 1=Yes |
| `verified_by` | Relapse verified by | Numeric | 1=Neurologist, 2=Other physician, 3=Anamnestic |
| `isolated_on` | Isolated optic neuritis | Numeric | 0=No, 1=Yes |
| `afferent_only` | Only afferent symptoms (non-ON) | Numeric | 0=No, 1=Yes |
| `single_system` | Only one functional system involved | Numeric | 0=No, 1=Yes |
| `complete_remit_12mo` | Complete remission within 12 months | Numeric | 0=No, 1=Yes |
| `comment` | Relapse comment | String | Free text comment |
| `created` | Record created (datetime) | Clock time | Record creation timestamp |
| `modified` | Record last modified (datetime) | Clock time | Last modification timestamp |

---

### 10.2 MS Visits (besoksdata)

**Filename:** `msreg_besoksdata.dta`  
**Description:** MS Registry visit data containing clinical assessments and patient-reported outcomes.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `center` | Healthcare center | String | Healthcare center code |
| `visit_dt` | Visit date | Date | Date of clinic visit |
| `total_visits` | Total visits | Numeric | Total count of visits for patient |
| `gen_health` | General health status | Numeric | 1=Poor, 2=Fair, 3=Good, 4=Very good, 5=Excellent |
| `edss` | EDSS score | Numeric | Expanded Disability Status Scale score |
| `msss_score` | MSSS score | Numeric | Multiple Sclerosis Severity Score |
| `umsss_score` | UMSSS score | Numeric | Updated MSSS score |
| `armss_score` | ARMSS score | Numeric | Age-Related MSSS score |
| `edss_severity` | EDSS severity grade | Numeric | 1=Normal, 2=Mild, 3=Moderate, 4=Severe |
| `relapse_since_last_visit` | Relapse since last visit | Numeric | 0=No, 1=Yes |
| `adverse_event` | Serious/unexpected adverse event since last visit | Numeric | 0=No, 1=Yes |
| `malignancy` | Malignancy | Numeric | 0=No, 1=Yes |
| `skin_cancer` | Skin cancer (non-melanoma) | Numeric | 0=No, 1=Yes |
| `treatment_infection` | Treatment-related infection | Numeric | 0=No, 1=Yes |
| `other_adverse` | Other serious/unexpected adverse event | Numeric | 0=No, 1=Yes |
| `rehab_12mo` | Rehabilitation period in last 12 months | Numeric | 0=No, 1=Yes |
| `intervention_6mo` | Assessment of intervention in last 6 months | Numeric | 0=No, 1=Yes |
| `falls_2mo` | Falls in last 2 months | Numeric | 0=No, 1=Yes |
| `covid19_since_last` | COVID-19 infection since last visit | Numeric | 0=No, 1=Yes |
| `visit_type` | Visit type | Numeric | 1=Physician contact, 2=Nurse contact, 3=Physiotherapist |
| `visit_type_text` | Visit type (text) | String | Visit type description |
| `contact_mode` | How contact occurred | Numeric | 1=Office visit, 2=Phone contact, 3=Video contact, 4=Admission, 5=Emergency visit, 6=Other |
| `contact_mode_text` | Contact mode (text) | String | Contact mode description |
| `comment` | Visit comment | String | Free text comment |
| `created` | Record created (datetime) | Clock time | Record creation timestamp |
| `modified` | Record last modified (datetime) | Clock time | Last modification timestamp |

---

### 10.3 MS Therapy/DMTs (terapi)

**Filename:** `msreg_terapi.dta`  
**Description:** Treatment/Therapy Dataset containing disease-modifying treatment information.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `tx_id` | Treatment/therapy record ID | Numeric | Unique treatment record ID |
| `clinic_id` | Affiliation ID | String | Clinic affiliation ID |
| `clinic` | Affiliation group | String | Clinic name/group |
| `county` | County | String | County |
| `tx_name` | Treatment preparation name | String | Name of treatment/medication |
| `tx_category` | Treatment category | Numeric | 1=Anti-CD20, 2=High-efficacy, 3=Platform (injectable), 4=Moderate-efficacy oral, 5=Symptomatic/Corticosteroids, 6=No treatment, 7=Study drug, 8=Other |
| `rituximab` | Rituximab | Numeric | 0=No, 1=Yes (indicator for rituximab specifically) |
| `prescribed_date` | Date treatment prescribed | Date | Date treatment was prescribed |
| `start_date` | Date treatment initiated/started | Date | Date treatment started |
| `stop_date` | Date treatment discontinued | Date | Date treatment stopped |
| `reason_untreated` | Reason for no treatment | String | Free text reason |
| `reason_untreated_code` | Reason for no treatment (coded) | Numeric | 1=Never treated, 2=Benign MS, 3=Pregnancy, 4=Unacceptable side effects, 5=Unclear diagnosis, 6=Primary progressive MS, 7=Patient decision, 8=Planned pregnancy, 9=Remission, 10=Secondary progressive MS, 11=Social reasons, 12=Stable condition, 99=Other reason |
| `stop_reason` | Reason for discontinuation | String | Free text reason |
| `stop_reason_code` | Reason for discontinuation (coded) | Numeric | 1=Antibodies to medication, 2=Adverse effects, 3=Lack of efficacy, 4=Pregnancy, 5=Planned pregnancy, 6=Secondary progressive MS, 7=Stable condition, 99=Other reason |
| `ongoing_tx` | Ongoing treatment with this preparation | String | Ongoing treatment indicator |
| `ongoing_strategy` | Ongoing treatment strategy | String | Ongoing strategy description |
| `dmt_flag` | Disease-modifying treatment | String | DMT flag |
| `comment` | Treatment comment | String | Free text comment |
| `created` | Record created (datetime) | Clock time | Record creation timestamp |
| `modified` | Record last modified (datetime) | Clock time | Last modification timestamp |

---

### 10.4 MS EDSS

**Filename:** `msreg_edss.dta`  
**Description:** EDSS assessments from 2017 onwards with functional system subscores.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `edss_dt` | EDSS assessment date | Date | Date of EDSS assessment |
| `edss_calc` | EDSS: Overall score (calculated) | Numeric | Calculated overall EDSS score |
| `edss_manual` | EDSS: Overall score (manual entry) | Numeric | Manually entered overall EDSS score |
| `edss_vis` | EDSS: Visual FS score | Numeric | Visual functional system score |
| `edss_bst` | EDSS: Brainstem FS score | Numeric | Brainstem functional system score |
| `edss_pyr` | EDSS: Pyramidal FS score | Numeric | Pyramidal functional system score |
| `edss_cer` | EDSS: Cerebellar FS score | Numeric | Cerebellar functional system score |
| `edss_sen` | EDSS: Sensory FS score | Numeric | Sensory functional system score |
| `edss_blbw` | EDSS: Bladder & Bowel FS score | Numeric | Bladder and bowel functional system score |
| `edss_men` | EDSS: Mental FS score | Numeric | Mental functional system score |
| `edss_walk_score` | EDSS: Ambulation/walking score | Numeric | Ambulation/walking score |
| `edss_walk_aid` | EDSS: Ambulation aid type | Numeric | 0=Normal, 1=Requires assistance |
| `edss_cmt` | EDSS: Assessment comment | String | Free text comment |
| `created` | Record created (datetime) | Clock time | Record creation timestamp |
| `modified` | Record last modified (datetime) | Clock time | Last modification timestamp |

---

### 10.5 MS EDSS from Visits

**Filename:** `msreg_visit_edss.dta`  
**Description:** EDSS scores extracted from visit data.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `total_edss` | Total EDSS measurements | Numeric | Total count of EDSS assessments |
| `edss` | EDSS score | Numeric | EDSS score |
| `edss_dt` | EDSS date | Date | Date of EDSS assessment |

---

### 10.6 MS Baseline/Core Dataset (basdata)

**Filename:** `msreg_basdata.dta`  
**Description:** Baseline/Core MS Registry Dataset containing comprehensive baseline and summary information.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `dob` | Date of birth | Date | Date of birth |
| `sex` | Sex | Numeric | 1=Male, 2=Female |
| `dominant_hand` | Dominant Hand | Numeric | 1=Right, 2=Left |
| `fam_hist_ms` | Family history of MS | String | Family history indicator |
| `city` | City/Town of residence | String | City/town |
| `region` | Health care region | String | Healthcare region |
| `reg_date` | Registration date in registry | Date | Date registered in MS registry |
| `diagnosis` | Diagnosis | String | Diagnosis description |
| `ms_criteria` | Fulfills diagnostic criteria for MS | String | MS diagnostic criteria fulfillment |
| `mstype` | MS Subtype | Numeric | 1=Primary Progressive, 2=Secondary Progressive, 3=Relapsing-Remitting |
| `dx_date` | Date of diagnosis | Date | MS diagnosis date |
| `dx_date_approx` | Diagnosis date is approximate | String | Date approximation indicator |
| `onset_date` | Date of symptom debut | Date | Symptom onset date |
| `onset_date_approx` | Debut date is approximate | String | Date approximation indicator |
| `to_sp_year` | Year of transition to Secondary Progressive MS | Numeric | Year of transition to SPMS |
| `referral_date` | Referral date | Date | Date of referral |
| `end_date` | Date of exclusion/end of follow-up | Date | End of follow-up date |
| `end_reason` | Reason for exclusion/end of follow-up | String | Reason for ending follow-up |
| `cod_ms` | MS as cause of death | String | MS as cause of death indicator |
| `ongoing_tx` | Patient has ongoing treatment | String | Ongoing treatment indicator |
| `last_visit_date` | Date of last visit | Date | Most recent visit date |
| `n_relapse_onset` | Number of relapses at MS onset | Numeric | Relapses at onset count |
| `n_treatments` | Number of treatments | Numeric | Total treatments count |
| `n_mri` | Number of MRIs | Numeric | Total MRI count |
| `n_relapses` | Number of relapses | Numeric | Total relapses count |
| `n_csf` | Number of CSF samples | Numeric | Total CSF samples count |
| `n_visits` | Number of visits | Numeric | Total visits count |
| `n_eq5d` | Number of EQ-5D assessments | Numeric | Total EQ-5D assessments |
| `n_edss` | Number of EDSS assessments | Numeric | Total EDSS assessments |
| `n_sf36` | Number of SF-36 assessments | Numeric | Total SF-36 assessments |
| `n_msis29` | Number of MSIS-29 assessments | Numeric | Total MSIS-29 assessments |
| `n_sdmt` | Number of SDMT assessments | Numeric | Total SDMT assessments |
| `last_relapse_date` | Date of last relapse | Date | Most recent relapse date |
| `first_tx_name` | Name of first treatment | String | First treatment name |
| `first_tx_category` | First Treatment Category | Numeric | 1=Anti-CD20, 2=High-efficacy, 3=Platform (injectable), 4=Moderate-efficacy oral, 5=Symptomatic/Corticosteroids, 6=No treatment, 7=Study drug, 8=Other |
| `first_tx_start_date` | Start date of first treatment | Date | First treatment start date |
| `first_tx_stop_date` | Stop date of first treatment | Date | First treatment stop date |
| `last_tx_start_date` | Start date of most recent treatment | Date | Most recent treatment start date |
| `last_tx_name` | Name of most recent treatment preparation | String | Most recent treatment name |
| `last_tx_category` | Last Treatment Category | Numeric | 1=Anti-CD20, 2=High-efficacy, 3=Platform (injectable), 4=Moderate-efficacy oral, 5=Symptomatic/Corticosteroids, 6=No treatment, 7=Study drug, 8=Other |
| `last_csf_date` | Date of last CSF sample | Date | Most recent CSF date |
| `last_csf_result` | Result of last CSF sample | String | Most recent CSF result |
| `last_mri_date` | Date of last MRI | Date | Most recent MRI date |
| `last_sdmt_date` | Date of last SDMT | Date | Most recent SDMT date |
| `last_sdmt_result` | Result of last SDMT | Numeric | Most recent SDMT score |
| `last_edss_date` | Date of last EDSS assessment | Date | Most recent EDSS date |
| `last_edss_score` | Score of last EDSS assessment | Numeric | Most recent EDSS score |
| `hypogamma_ms` | Hypogammaglobulinemia related to MS | String | Hypogammaglobulinemia indicator |
| `hypogamma_ms_date` | Date of hypogammaglobulinemia diagnosis | Date | Hypogammaglobulinemia diagnosis date |
| `clinic` | Affiliation group | String | Clinic name/group |
| `clinic_id` | Affiliation ID | String | Clinic affiliation ID |
| `center` | Treatment Center | String | Treatment center |
| `eims_study` | EIMS study participant | String | EIMS study participation |
| `vip1_study` | VIP1 study participant | String | VIP1 study participation |
| `vip2_study` | VIP2 study participant | String | VIP2 study participation |
| `code1` | Registry code 1 | String | Registry code 1 |
| `code2` | Registry code 2 | String | Registry code 2 |
| `code3` | Registry code 3 | String | Registry code 3 |
| `consent` | Consent status for registry participation | String | Consent status |
| `consent_date` | Date of consent/information | Date | Consent date |
| `biobank_consent` | Consent for biobank | String | Biobank consent status |
| `research_consult_flag` | Research participation only after PAL consult | String | Research consultation flag |
| `county` | County | String | County |
| `county_id` | County ID | String | County ID |
| `note` | General note | String | Free text note |
| `created` | Record created date/flag | String | Creation indicator |
| `modified_datetime` | Record last modified (datetime) | Clock time | Last modification timestamp |

---

### 10.7 MS SDMT

**Filename:** `msreg_sdmt.dta`  
**Description:** Symbol Digit Modalities Test (SDMT) cognitive assessments.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `total_sdmt` | Total SDMT assessments | Numeric | Total count of SDMT assessments |
| `sdmt_dt` | SDMT assessment date | Date | Date of SDMT assessment |
| `sdmt_score` | SDMT score (number correct) | Numeric | Number of correct responses |
| `comment` | SDMT assessment comment | String | Free text comment |
| `created` | Record created (datetime) | Clock time | Record creation timestamp |
| `modified` | Record last modified (datetime) | Clock time | Last modification timestamp |

---

### 10.8 MS Smoking

**Filename:** `msreg_smoking.dta`  
**Description:** Smoking Assessment Dataset containing smoking history and status.

#### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `msreg` | MS Registry Number | Numeric | MS registry number |
| `id` | Patient identifier | Numeric | Anonymous patient ID |
| `assessment_date` | Date of smoking assessment | Date | Assessment date |
| `smoking_status` | Smoking status | Numeric | 1=Never smoker, 2=Former smoker, 3=Daily smoker, 4=Non-daily smoker, 5=Daily non-cigarette tobacco user |
| `quit_date` | Date of smoking cessation | Date | Date quit smoking |
| `smoke_free_6mo` | Smoke-free more than 6 months | Numeric | 0=No, 1=Yes |
| `cigs_per_day` | Number of cigarettes per day | Numeric | Daily cigarette count |
| `comment` | Smoking assessment comment | String | Free text comment |
| `created` | Record created (datetime) | Clock time | Record creation timestamp |
| `modified` | Record last modified (datetime) | Clock time | Last modification timestamp |

---

## 11. Birth Registry

**Filename:** `births.dta`  
**Description:** Swedish Birth Registry Dataset containing pregnancy, delivery, and neonatal information.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Mother's ID | Numeric | Mother's identifier |
| `child_id` | Child's ID | Numeric | Child's identifier |
| `year` | Child's birth year | Numeric | Birth year |
| `mdob` | Mother's date of birth | Date | Mother's date of birth |
| `dob` | Child's date of birth | Date | Child's date of birth |
| `id_quality_mb` | Personal number quality for multiple births | Numeric | 0=Valid, 5=Stillborn, 8=Uncertain |
| `mcountry` | Mother's country of birth | String | Mother's birth country |
| `mage` | Mother's age at delivery (years) | Numeric | Maternal age |
| `parity` | Child's birth order (including current birth) | Numeric | Birth order |
| `parity_del` | Delivery order (including current delivery) | Numeric | Delivery order |
| `anc_enroll_date` | Antenatal care enrollment date | Date | ANC enrollment date |
| `lmp_date` | Date of last menstrual period (first day) | Date | Last menstrual period |
| `edd_lmp` | Estimated delivery date based on LMP | Date | EDD from LMP |
| `edd_us` | Estimated delivery date based on ultrasound | Date | EDD from ultrasound |
| `mwt_kg` | Mother's weight at ANC enrollment (kg) | Numeric | Maternal weight (kg) |
| `mht_cm` | Mother's height (cm) | Numeric | Maternal height (cm) |
| `smk_3mo_pre` | Smoking 3 months before pregnancy | Numeric | 1=Non-smoker, 2=1-9 cigs/day, 3=10+ cigs/day |
| `snus_3mo_pre` | Snus use 3 months before pregnancy | Numeric | 0=No, 1=Yes |
| `smk_enroll` | Smoking at ANC enrollment | Numeric | 1=Non-smoker, 2=1-9 cigs/day, 3=10+ cigs/day |
| `snus_enroll` | Snus use at ANC enrollment | Numeric | 0=No, 1=Yes |
| `famsit` | Family situation | Numeric | 1=Living with child's father, 2=Single, 3=Other family situation |
| `work` | Work status at ANC enrollment | Numeric | 1=Full-time, 2=Part-time, 3=No |
| `prev_miscarr` | Number of previous spontaneous abortions | Numeric | Previous miscarriages count |
| `prev_ectopic` | Number of previous ectopic pregnancies | Numeric | Previous ectopic pregnancies count |
| `prev_stillb` | Number of previous stillbirths | Numeric | Previous stillbirths count |
| `prev_liveb` | Number of previous live births | Numeric | Previous live births count |
| `prev_death_early` | Number of previous deaths 0-6 days | Numeric | Early neonatal deaths count |
| `prev_death_late` | Number of previous deaths >6 days | Numeric | Late neonatal deaths count |
| `kidney` | Chronic kidney disease | Numeric | 1=Current or previous, 2=Previous only |
| `diabetes` | Diabetes mellitus (not gestational) | Numeric | 1=Current or previous, 2=Previous only |
| `epilepsy` | Epilepsy | Numeric | 1=Current or previous, 2=Previous only |
| `asthma` | Lung disease/asthma | Numeric | 1=Current or previous, 2=Previous only |
| `ibd` | Ulcerative colitis or Crohn's disease | Numeric | 1=Current or previous, 2=Previous only |
| `sle` | Systemic lupus erythematosus | Numeric | 1=Current or previous, 2=Previous only |
| `htn` | Chronic hypertension | Numeric | 1=Current or previous, 2=Previous only |
| `anc_visits` | Number of antenatal care visits | Numeric | ANC visits count |
| `smk_wk30` | Smoking at gestational weeks 30-32 | Numeric | 1=Non-smoker, 2=1-9 cigs/day, 3=10+ cigs/day |
| `snus_wk30` | Snus use at gestational weeks 30-32 | Numeric | 0=No, 1=Yes |
| `cvs` | Chorionic villus sampling performed | Numeric | 0=No, 1=Yes |
| `cvs_date` | Date of chorionic villus sampling | Date | CVS date |
| `cvs_result` | CVS result | Numeric | 1=No abnormality, 2=Abnormality detected |
| `pregdiag1` to `pregdiag4` | Diagnosis/procedure during pregnancy 1-4 | String | ICD/KVA codes during pregnancy |
| `del_admit_date` | Admission date for delivery | Date | Delivery admission date |
| `mwt_del` | Mother's weight at delivery (kg) | Numeric | Maternal weight at delivery |
| `presentation` | Fetal presentation | Numeric | 0=Other presentation, 1=Cephalic vertex, 4=Face/brow, 6=Breech/footling |
| `prev_cs` | Previous cesarean section | Numeric | 0=No, 1=Yes |
| `prev_cs_year` | Year of previous cesarean section | Numeric | Previous CS year |
| `labor_spont` | Labor started spontaneously | Numeric | 0=No, 1=Yes |
| `labor_induced` | Labor induced | Numeric | 0=No, 1=Yes |
| `cs_before_labor` | Cesarean before labor onset | Numeric | 0=No, 1=Yes |
| `cs_elective` | Elective or emergency cesarean | Numeric | 1=Elective, 2=Emergency |
| `del_vaginal` | Vaginal delivery (non-instrumental) | Numeric | 0=No, 1=Yes |
| `del_vacuum` | Vacuum extraction delivery | Numeric | 0=No, 1=Yes |
| `del_forceps` | Forceps delivery | Numeric | 0=No, 1=Yes |
| `del_cs` | Cesarean delivery | Numeric | 0=No, 1=Yes |
| `forceps_used` | Forceps used at any point during delivery | Numeric | 0=No, 1=Yes |
| `vacuum_used` | Vacuum used at any point during delivery | Numeric | 0=No, 1=Yes |
| `cs_performed` | Cesarean section performed | Numeric | 0=No, 1=Yes |
| `del_proc_other` | Other delivery procedure (KVA code) | String | Other delivery procedure code |
| `epidural` | Epidural anesthesia | Numeric | 0=No, 1=Yes |
| `sedatives` | Sedative hypnotics | Numeric | 0=No, 1=Yes |
| `tens` | Transcutaneous electrical nerve stimulation | Numeric | 0=No, 1=Yes |
| `tear_perineum` | Perineal tear | Numeric | 0=No, 1=Yes |
| `tear_sphincter` | Sphincter tear | Numeric | 0=No, 1=Yes |
| `tear_rectum` | Rectal tear | Numeric | 0=No, 1=Yes |
| `episiotomy` | Episiotomy | Numeric | 1=Right medio-lateral, 2=Median, 3=Left medio-lateral, 9=Type unknown |
| `icd` | ICD classification version | Numeric | 8=ICD-8, 9=ICD-9, 10=ICD-10 |
| `mdiag1` to `mdiag12` | Mother's diagnosis 1-12 | String | ICD codes for maternal diagnoses |
| `mdiagnos` | Mother's diagnoses 1-12 (concatenated) | String | Concatenated ICD codes |
| `mproc1` to `mproc12` | Mother's procedure 1-12 | String | KVA codes for maternal procedures |
| `placenta_wt` | Placenta weight (grams) | Numeric | Placenta weight |
| `cs_type_detail` | Cesarean type: elective or not elective | Numeric | 1=Elective, 2=Not elective |
| `mdisch_date` | Mother's discharge date | Date | Maternal discharge date |
| `mdisch_status` | Mother's discharge status | Numeric | 1=Home, 2=Other care facility, 3=Other clinic, 4=Other address, 5=Died autopsied, 6=Died not autopsied |
| `birth_time` | Time of birth (HHMM) | String | Birth time |
| `birth_type` | Singleton or multiple birth | Numeric | 1=Singleton, 2=Multiple |
| `birth_order_mb` | Birth order and total number in multiple births | String | Birth order in multiple births |
| `stillborn` | Stillborn | Numeric | 1=Before labor, 2=During labor |
| `death_time` | Time of death (HHMM) | String | Time of neonatal death |
| `sex` | Child's sex | Numeric | 1=Male, 2=Female |
| `ga_wks_journal` | Gestational age in weeks (journal entry) | Numeric | GA weeks from journal |
| `ga_days_journal` | Gestational age in days beyond weeks (journal) | Numeric | GA days beyond weeks |
| `ga_wks` | Gestational age in weeks (best estimate) | Numeric | Best estimate GA weeks |
| `ga_days` | Gestational age in total days (best estimate) | Numeric | Best estimate GA days |
| `ga_method` | Method used for gestational age estimation | String | GA estimation method |
| `bwt` | Birth weight (grams) | Numeric | Birth weight |
| `blen` | Birth length (cm) | Numeric | Birth length |
| `hc` | Head circumference (cm) | Numeric | Head circumference |
| `apgar1` | Apgar score at 1 minute | Numeric | 1-minute Apgar |
| `apgar5` | Apgar score at 5 minutes | Numeric | 5-minute Apgar |
| `apgar10` | Apgar score at 10 minutes | Numeric | 10-minute Apgar |
| `resus_vent_min` | Resuscitation: mask ventilation (minutes) | Numeric | Minutes of mask ventilation |
| `resus_intub_min` | Resuscitation: intubation ventilation (minutes) | Numeric | Minutes of intubation ventilation |
| `bdiag1` to `bdiag12` | Child's diagnosis 1-12 | String | ICD codes for child diagnoses |
| `bdiagnos` | Child's diagnoses 1-12 (concatenated) | String | Concatenated child ICD codes |
| `bproc1` to `bproc12` | Child's procedure 1-12 | String | KVA codes for child procedures |
| `bproc` | Child's procedures 1-12 (concatenated) | String | Concatenated child procedure codes |
| `healthy` | Healthy child examined at maternity ward | Numeric | 1=Healthy child (Z00.1A), 2=Other diagnoses |
| `bdisch_status` | Child's discharge status | Numeric | 1=Home, 2=Other address, 3=Not discharged by 28 days |
| `bdisch_date` | Child's discharge/home date | Date | Child discharge date |
| `death_age_days` | Age at death (days, neonatal period only) | Numeric | Neonatal death age in days |
| `neonatal_surv` | Survival status in neonatal period | Numeric | 1=Stillborn, 2=Died 0-6 days, 3=Died 7-27 days |
| `cong_anom` | Congenital malformation diagnosis present | Numeric | 0=No, 1=Yes |
| `sga` | Small for gestational age (SGA) | Numeric | 0=No, 1=Yes |
| `lga` | Large for gestational age (LGA) | Numeric | 0=No, 1=Yes |

---

## 12. Cancer Registry

**Filename:** `cancer.dta`  
**Description:** Swedish Cancer Registry Dataset containing cancer diagnoses with staging and classification information.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | Personal number | Numeric | Personal identifier |
| `dx_date` | Date of cancer diagnosis | Date | Cancer diagnosis date |
| `cancerdate` | Cancer diagnosis date (Stata date format) | Date | Cancer diagnosis date (Stata format) |
| `year` | Year of cancer diagnosis | Numeric | Diagnosis year |
| `age` | Age at cancer diagnosis (years) | Numeric | Age at diagnosis |
| `icd7` | ICD-7 code | String | ICD-7 classification code |
| `icd9` | ICD-9 code | String | ICD-9 classification code |
| `icdo10` | ICD-10 code | String | ICD-10 classification code |
| `icdo3` | ICD-O-3 topography code | String | ICD-O-3 topography code |
| `pad` | PAD code (Pathological-Anatomical Diagnosis) | String | PAD code |
| `snomed3` | SNOMED-3 morphology code | String | SNOMED-3 code |
| `snomedo10` | SNOMED morphology code (ICD-O-3) | String | SNOMED ICD-O-3 code |
| `laterality` | Laterality (side of body) | Numeric | 1=Right, 2=Left, 9=Not applicable/unknown |
| `malignant` | Behavior code (malignant) | Numeric | 3=Malignant |
| `dx_certainty` | Diagnostic certainty | Numeric | 1=Death certificate only, 2=Clinical, 3=Clinical investigation, 4=Specific tumor markers, 5=Cytology/hematology, 6=Histology of metastasis, 8=Histology of primary tumor |
| `tnm_basis` | Basis for TNM classification | String | 1=Clinical, 2=Pathological |
| `tnm_t` | TNM T stage (tumor) | String | TNM T stage |
| `tnm_n` | TNM N stage (nodes) | String | TNM N stage |
| `tnm_m` | TNM M stage (metastasis) | String | TNM M stage |
| `figo` | FIGO stage (gynecologic cancers) | String | FIGO staging |
| `tumor_n` | Tumor number (sequential) | Numeric | Sequential tumor number |
| `tumor_n_malig` | Malignant tumor number (sequential) | Numeric | Sequential malignant tumor number |
| `autopsy` | Autopsy finding | Numeric | 1=Tumor not known before death, 2=Tumor known before death |

---

## 13. Death Registry

**Filename:** `death.dta`  
**Description:** Swedish Death Registry Dataset containing cause of death information.

### Variables

| Variable | Label | Type | Values/Notes |
|----------|-------|------|--------------|
| `id` | ID | Numeric | Personal identifier |
| `death_date` | Date of death | Date | Date of death |
| `deathdate` | Date of death (Stata date format) | Date | Date of death (Stata format) |
| `year` | Year of death | Numeric | Death year |
| `age` | Age at death (years) | Numeric | Age at death |
| `icd` | ICD classification version | Numeric | 9=ICD-9, 10=ICD-10 |
| `ucod` | Underlying cause of death (ICD code) | String | Underlying cause of death ICD code |
| `extcause` | External cause of death - ICD Chapter 19/20 | String | External cause ICD code |
| `cod1` to `cod20` | Contributing cause of death 1-20 | String | Contributing causes of death ICD codes |
| `place` | Place of death | Numeric | 1=Hospital/care facility, 2=Residence, 3=Other location, 4=Unknown |
| `death_abroad` | Death occurred abroad | Numeric | 0=No, 1=Yes |
| `congenanom` | Congenital anomaly - ICD Chapter 17 | String | Congenital anomaly ICD code |

---

## Notes

- All date variables are formatted as %tdCCYY/NN/DD (Stata date format: CCYY/MM/DD)
- All datetime variables are formatted as %tcCCYY/NN/DD_hh:mm:ss (Stata clock format)
- Missing values for categorical variables are typically coded as . (numeric missing) or empty string
- Some datasets have year-specific files (Outpatient: 1997-2025, Prescriptions: 2005-2025)
- ICD codes may be in different versions (ICD-7, ICD-8, ICD-9, ICD-10) depending on the time period
- All datasets contain anonymous identifiers (id or msreg) for linking

---

## Change Log 

### 1.0.1 Changes

*My sincere thanks to [Astrid Pedersen](https://ki.se/en/people/astrid-pedersen) for her patience and meticulous work in identifying and implementing the changes in this version.*

#### lisa.dta

* `activity_supp_days` → `brutto_days`
  * Rename: `activity_supp_days` → `brutto_days`
  * Variable label: "Activity support days compensated" → "Brutto days w/ activity comp."

* `unemp_days` → `unemp_inc`
  * Rename: `unemp_days` → `unemp_inc`
  * Variable label: "Unemployment days" → "Unemployment income sum"

* `unemp_type` → `unemp_comp_type`
  * Rename: `unemp_type` → `unemp_comp_type`
  * Variable label: "Unemployment type" → "Tyep of unemployment compensation"
  * Added value label definition: yesno (0 "No", 1 "Yes")

* `housing_cost_pers` → `disab_allow`
  * Rename: `housing_cost_pers` → `disab_allow`
  * Variable label: "Housing cost per person" → "Disability Allowance"

* `se_inc_net` → `se_inc_net`
  * Variable label: "Net self-employment income (active)" → "Net self-employment income"

* `se_inc_net_all` → `se_inc_net_act`
  * Rename: `se_inc_net_all` → `se_inc_net_act`
  * Variable label: "Net self-employment income (all)" → "Net self-employment income (active)"

* `substitute_inc` → `substitute_inc`
  * Variable label: "Substitute income replacement" → "Additional cost compensation"

* `rehab_type` → `rehab_bin`
  * Rename: `rehab_type` → `rehab_bin`
  * Variable label: "Rehabilitation type" → "Rehabilitation compensation presence"
  * Added value label definition: yesno (0 "No", 1 "Yes")

* `sick_spells_n` → `sick_spells_transitioned`
  * Rename: `sick_spells_n` → `sick_spells_transitioned`
  * Variable label: "Number of sickness spells" → "# of sickness spells transitioned to sick-leave, work-injury, rehab comp."

* `sick_ended_n` → `sick_ended_n`
  * Variable label: "Number of sickness spells ended" → "# of sickness spells ended during the year"

* `sick_started_n` → `sick_started_n`
  * Variable label: "Number of sickness spells started" → "# of sickness spells started during the year"

* `sick_type` → `sick_bin`
  * Rename: `sick_type` → `sick_bin`
  * Variable label: "Sickness benefit type" → "Sickness, work-injury, rehab compensation"
  * Added value label definition: yesno (0 "No", 1 "Yes")

* `sa_type` → `sa_bin`
  * Rename: `sa_type` → `sa_bin`
  * Variable label: "Social assistance type" → "Social assistance presence"
  * Added value label definition: yesno (0 "No", 1 "Yes")

* `sa_unemp` → `sa_share`
  * Rename: `sa_unemp` → `sa_share`
  * Variable label: "Social assistance for unemployed" → "Share of social assistance with primary & coapplicants"

* `educ_field` → `educ_lev`
  * Rename: `educ_field` → `educ_lev`
  * Variable label: "Education field (detailed)" → "Highest education level (granular)"
  * Value label name set to: `educ_lev`

* `educ_field_20` → `educ_lev_20`
  * Rename: `educ_field_20` → `educ_lev_20`
  * Variable label: "Education field 2020 classification" → "Highest Finished Education Level"

* `educ_lev_20` → `educ_lev_old_20`
  * Rename: `educ_lev_20` → `educ_lev_old_20`
  * Variable label: "Education level 2020 classification" → "Highest Education Level"
  * Value label name set to: `educ_lev`


#### msreg_besoksdata.dta

* `ongoing_relapse` → `relapse_since_last_visit`
  * Rename: `ongoing_relapse` → `relapse_since_last_visit`


#### out_YYYY.dta

* `edactivity` → `edactivity`
  * Value label definition updated (category wording):
    * Category 4: "Walk-in centre" → "Urgent care"

---

**Document Version:** 1.0.1 

**Author:** [Tim Copeland](https://ki.se/en/people/timothy-copeland)

**Last Updated:** 2025-10-27  
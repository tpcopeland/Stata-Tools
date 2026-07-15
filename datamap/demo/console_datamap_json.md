---
title: "console_datamap_json"
---

## JSON output for metadata pipelines

```stata
. noisily datamap, single("`pkg_dir'/_demo_cohort.dta")
>     output("`pkg_dir'/datamap_metadata.json")
>     format(json) exclude(patient_id subject_id patient_name)
>     datesafe mincell(5) quality missing(detail) uniqcap(100)
```

```
Output written to: datamap/demo/datamap_metadata.json
Documentation generated successfully

```

```stata
. noisily _demo_type_head using "`pkg_dir'/datamap_metadata.json", lines(70)
```

```
{
  "datamap_version": "1.6.0",
  "generated": "15 Jul 2026 00:26:56",
  "format": "json",
  "datasets": [
    {
      "name": "_demo_cohort.dta",
      "observations": 1200,
      "variables": 17,
      "label": "Synthetic Clinical Trial Cohort (N=1200)",
      "data_signature": "1200:17(68284):2844760337:3810411015",
      "sort_order": "",
      "privacy": {
        "mincell": 5,
        "datesafe": true,
        "excluded_variables": 3,
        "likely_identifiers_not_excluded": 0,
        "suggested_exclude": ""
      },
      "class_counts": {
        "categorical": 6,
        "continuous": 6,
        "date": 2,
        "string": 0,
        "excluded": 3
      },
      "variable_metadata": [
        {
          "name": "patient_id",
          "type": "double",
          "format": "%10.0g",
          "label": "Patient identifier",
          "value_label": "",
          "classification": "excluded",
          "missing_n": 0,
          "missing_pct": 0,
          "unique_values": null,
          "unique_values_capped": false,
          "max_length": null,
          "summary": {
          },
          "frequencies": [
          ]
        },
        {
          "name": "subject_id",
          "type": "double",
          "format": "%10.0g",
          "label": "Study subject identifier",
          "value_label": "",
          "classification": "excluded",
          "missing_n": 0,
          "missing_pct": 0,
          "unique_values": null,
          "unique_values_capped": false,
          "max_length": null,
          "summary": {
          },
          "frequencies": [
          ]
        },
        {
          "name": "patient_name",
          "type": "str32",
          "format": "%32s",
          "label": "Patient full name",
          "value_label": "",
          "classification": "excluded",
          "missing_n": 0,
          "missing_pct": 0,
... [output truncated]

```

```stata
. noisily display as text "Censored unique-count flags:"
```

```
Censored unique-count flags:

```

```stata
. noisily _demo_type_matches using "`pkg_dir'/datamap_metadata.json",
>     text("unique_values_capped") lines(8)
```

```
          "unique_values_capped": false,
          "unique_values_capped": false,
          "unique_values_capped": false,
          "unique_values_capped": true,
          "unique_values_capped": false,
          "unique_values_capped": false,
          "unique_values_capped": true,
          "unique_values_capped": true,

```

```stata
. noisily display as text "Suppressed JSON cells:"
```

```
Suppressed JSON cells:

```

```stata
. noisily _demo_type_matches using "`pkg_dir'/datamap_metadata.json",
>     text("suppressed") lines(8)
```

```
              "suppressed": false,
              "suppressed": false,
              "suppressed": false,
              "suppressed": false,
              "suppressed": false,
              "suppressed": false,
              "suppressed": false,
              "suppressed": false,

```

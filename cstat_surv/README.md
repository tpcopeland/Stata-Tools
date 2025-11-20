# cstat_surv

![Stata 14+](https://img.shields.io/badge/Stata-14%2B-brightgreen) ![MIT License](https://img.shields.io/badge/License-MIT-blue) ![Status](https://img.shields.io/badge/Status-Active-success)

Calculate C-statistic (concordance statistic) for survival models.

## Description

cstat_surv calculates the C-statistic for survival models after fitting a Cox proportional hazards model. The C-statistic measures the model's ability to discriminate between subjects who experience the event and those who do not. The command uses Somers' D transformation to account for censoring in survival data.

## Installation

```stata
net from https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/cstat_surv
net install cstat_surv
```

## Prerequisites

Requires the somersd package from SSC:
```stata
ssc install somersd
```

## Syntax

```stata
cstat_surv
```

Run immediately after fitting a Cox model with stcox.

## Example

```stata
* Load survival data
webuse drugtr, clear

* Set survival data
stset studytime, failure(died)

* Fit Cox model
stcox age drug

* Calculate C-statistic
cstat_surv
```

## Interpretation

The C-statistic ranges from 0 to 1:
- C = 0.5 indicates no discrimination (random predictions)
- C > 0.7 indicates acceptable discrimination
- C > 0.8 indicates excellent discrimination

## Requirements

- Stata 14.0 or higher
- Data must be stset
- somersd package from SSC

## Author

Timothy P Copeland
Department of Clinical Neuroscience
Karolinska Institutet

## License

MIT License

## Help

For more information:
```stata
help cstat_surv
```

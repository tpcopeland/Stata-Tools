---
title: "console_describe"
---

```stata
. noisily codescan_describe dx1 dx2 dx3 dx4, top(15)
```

```
codescan describe: 4 variables, 61 unique codes,      3,411 total entries

  Code             Frequency      Percent     Cumul %
  ----------------------------------------------------
  I110                    80         2.3%        2.3%
  C34                     71         2.1%        4.4%
  E114                    68         2.0%        6.4%
  G81                     67         2.0%        8.4%
  E119                    67         2.0%       10.3%
  E102                    66         1.9%       12.3%
  C85                     65         1.9%       14.2%
  C80                     65         1.9%       16.1%
  Z96                     64         1.9%       18.0%
  G820                    63         1.8%       19.8%
  I71                     63         1.8%       21.7%
  C79                     61         1.8%       23.5%
  M06                     61         1.8%       25.2%
  G311                    61         1.8%       27.0%
  K25                     61         1.8%       28.8%
  ... (46 more codes)

  By first character:
  Char         Codes     Entries
  ----------------------------------
  I               10         558
  C                9         527
  E                8         488
  K                5         263
  G                4         238
  F                4         221
  D                4         217
  J                3         168
  M                3         167
  N                3         161
  Z                3         160
  B                3         153
  R                2          90

  Suggested patterns:
    define(chapter_I "I") — 10 codes, 558 entries
    define(chapter_C "C") — 9 codes, 527 entries
    define(chapter_E "E") — 8 codes, 488 entries
    define(chapter_K "K") — 5 codes, 263 entries
    define(chapter_G "G") — 4 codes, 238 entries

```

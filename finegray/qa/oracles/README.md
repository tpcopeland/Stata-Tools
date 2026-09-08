# Frozen R references

These files are intentional QA fixtures, excluded from the installable package. They were frozen on 2026-09-08 from existing R reference outputs after checking every cached output against its recorded digest. No Stata estimate was substituted for an R answer.

Each `<name>/<key>/` directory contains `key.txt` (ordered generator/input content hashes and scalar parameters), `index.csv` (ordered output names and digests), `index.md5` (manifest digest), `PROVENANCE.txt` (original generating inputs, R version, platform, and package versions), and the output blobs. The short directory key addresses an entry; the complete key and output checksums authorize its use. Temporary input basenames are deliberately excluded. Identical references formerly stored under different temporary names were deduplicated only after comparing their output digests.

There are 15 reference entries for 11 R generators; multiple entries cover different fixture inputs. The two CIF entries preserve the historical float- and double-profile inputs. The `.dta` blob is a deliberate frozen `haven` reference, not generated run debris. The ZZF entry includes 100 datasets, the oracle coefficient table, the manifest, and six baseline curves.

Ordinary QA only restores these references and errors on a miss or damaged entry. It does not require a populated user cache and does not regenerate estimates after an R upgrade. `FG_ORACLE_REFRESH=1` is an explicit maintenance action that recomputes and replaces the matching references using the current R toolchain. Review such changes numerically and retain their provenance. `test_finegray_oracles.do` runs the integrity and refusal tests.

"""
Cross-validation oracle for cci_se: independent Python implementation of the
Swedish Charlson Comorbidity Index (Ludvigsson et al. 2021, ICD-10 only).

Usage:
    python3 _crossval_cci_se_python.py <input_csv> <output_csv>

Input CSV columns: id, icd, visit_date (Stata date integer)
Output CSV columns: id, charlson, cci_mi ... cci_aids (18 components)

This implements the same prefix-matching logic as the Mata engine but
independently, serving as an end-to-end oracle for ICD-10 data (year >= 1998).
"""

import sys
import csv
from collections import defaultdict


# --- ICD-10 prefix -> component index (1-19) ---
# Built from Ludvigsson et al. 2021, Table 2

def build_icd10_table():
    """Build prefix lookup table for ICD-10 codes."""
    table = {}

    # 1. Myocardial infarction
    for pfx in ["I21", "I22", "I252"]:
        table[pfx] = 1

    # 2. Congestive heart failure
    for pfx in ["I110", "I130", "I132", "I255", "I420", "I426", "I427",
                "I428", "I429", "I43", "I50"]:
        table[pfx] = 2

    # 3. Peripheral vascular disease
    for pfx in ["I70", "I71", "I731", "I738", "I739", "I771", "I790",
                "I792", "K55"]:
        table[pfx] = 3

    # 4. Cerebrovascular disease
    for pfx in ["G45", "I60", "I61", "I62", "I63", "I64", "I67", "I69"]:
        table[pfx] = 4

    # 5. COPD
    for pfx in ["J43", "J44"]:
        table[pfx] = 5

    # 6. Other chronic pulmonary disease
    for pfx in ["J41", "J42", "J45", "J46", "J47", "J60", "J61", "J62",
                "J63", "J64", "J65", "J66", "J67", "J68", "J69", "J70"]:
        table[pfx] = 6

    # 7. Rheumatic disease
    for pfx in ["M05", "M06", "M123", "M070", "M071", "M072", "M073",
                "M08", "M13", "M30", "M313", "M314", "M315", "M316",
                "M32", "M33", "M34", "M350", "M351", "M353", "M45", "M46"]:
        table[pfx] = 7

    # 8. Dementia
    for pfx in ["F00", "F01", "F02", "F03", "F051", "G30", "G311", "G319"]:
        table[pfx] = 8

    # 9. Hemiplegia/paraplegia
    for pfx in ["G114", "G80", "G81", "G82", "G830", "G831", "G832",
                "G833", "G838"]:
        table[pfx] = 9

    # 10. Diabetes without complications
    for pfx in ["E100", "E101", "E106", "E109", "E110", "E111", "E119",
                "E120", "E121", "E129", "E130", "E131", "E139", "E140",
                "E141", "E149"]:
        table[pfx] = 10

    # 11. Diabetes with complications
    for pfx in ["E102", "E103", "E104", "E105", "E107", "E112", "E113",
                "E114", "E115", "E116", "E117", "E122", "E123", "E124",
                "E125", "E126", "E127", "E132", "E133", "E134", "E135",
                "E136", "E137", "E142", "E143", "E144", "E145", "E146",
                "E147"]:
        table[pfx] = 11

    # 12. Renal disease
    for pfx in ["I120", "I131", "N032", "N033", "N034", "N035", "N036",
                "N037", "N052", "N053", "N054", "N055", "N056", "N057",
                "N11", "N18", "N19", "N250", "Q611", "Q612", "Q613",
                "Q614", "Z49", "Z940", "Z992"]:
        table[pfx] = 12

    # 13. Mild liver disease
    for pfx in ["B15", "B16", "B17", "B18", "B19", "K703", "K709", "K73",
                "K746", "K754"]:
        table[pfx] = 13

    # 14. Ascites (internal, for liver hierarchy)
    table["R18"] = 14

    # 15. Moderate/severe liver disease
    for pfx in ["I850", "I859", "I982", "I983"]:
        table[pfx] = 15

    # 16. Peptic ulcer disease
    for pfx in ["K25", "K26", "K27", "K28"]:
        table[pfx] = 16

    # 17. Malignancy (non-metastatic): C00-C76, C81-C97 excl C42, C44, C87
    for i in range(0, 77):
        code = f"C{i:02d}"
        table[code] = 17
    for i in range(81, 98):
        code = f"C{i:02d}"
        table[code] = 17
    # Remove exclusions
    for excl in ["C42", "C44", "C87"]:
        if excl in table:
            del table[excl]

    # 18. Metastatic cancer (C77-C80) — overwrites any C77-C80 from above
    for pfx in ["C77", "C78", "C79", "C80"]:
        table[pfx] = 18

    # 19. AIDS/HIV
    for pfx in ["B20", "B21", "B22", "B23", "B24", "F024", "O987", "R75",
                "Z219", "Z717"]:
        table[pfx] = 19

    return table


def lookup_token(table, token):
    """Try progressively shorter prefixes of token against the table."""
    token = token.upper().replace(".", "")
    for plen in range(len(token), 1, -1):
        pfx = token[:plen]
        if pfx in table:
            return table[pfx]
    return None


def compute_cci(input_path, output_path):
    """Compute CCI from diagnosis-level CSV, write patient-level results."""
    table = build_icd10_table()

    # Read input: id, icd, visit_date
    # Accumulate per-patient component indicators
    patient_components = defaultdict(lambda: set())
    all_patients = set()

    with open(input_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            pid = row["id"]
            all_patients.add(pid)
            icd_raw = row["icd"].strip()
            if not icd_raw:
                continue

            # Handle multiple space-separated codes per cell
            tokens = icd_raw.split()
            for tok in tokens:
                tok_clean = tok.upper().replace(".", "")
                comp = lookup_token(table, tok_clean)
                if comp is not None:
                    patient_components[pid].add(comp)

    # Apply hierarchy rules and compute scores
    component_names = [
        "mi", "chf", "pvd", "cevd", "copd", "pulm", "rheum", "dem",
        "plegia", "diab", "diabcomp", "renal", "livmild", "livsev",
        "pud", "cancer", "mets", "aids"
    ]
    # Map component name to index (skipping 14=ascites)
    comp_indices = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19]

    weights = {
        1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1,
        9: 2, 10: 1, 11: 2, 12: 2, 13: 1, 15: 3, 16: 1,
        17: 2, 18: 6, 19: 6
    }

    results = []
    for pid in all_patients:
        comps = patient_components[pid]  # empty set if no matches

        # Liver hierarchy: mild (13) + ascites (14) -> severe (15)
        if 13 in comps and 14 in comps:
            comps.add(15)
        if 15 in comps:
            comps.discard(13)

        # Diabetes hierarchy
        if 11 in comps:
            comps.discard(10)

        # Cancer hierarchy
        if 18 in comps:
            comps.discard(17)

        # Compute weighted score
        score = sum(weights.get(c, 0) for c in comps if c in weights)

        # Build output row
        row = {"id": pid, "charlson": score}
        for name, idx in zip(component_names, comp_indices):
            row[f"cci_{name}"] = 1 if idx in comps else 0
        results.append(row)

    # Sort by id for deterministic output
    results.sort(key=lambda r: int(r["id"]) if r["id"].isdigit() else r["id"])

    # Write output
    fieldnames = ["id", "charlson"] + [f"cci_{n}" for n in component_names]
    with open(output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)

    print(f"Processed {len(results)} patients")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input_csv> <output_csv>")
        sys.exit(1)
    compute_cci(sys.argv[1], sys.argv[2])

*! qa-lib _qa_fx_a7 1.0.0 sha256:4e24f84d0822a92815e43215d5cca1dc7baa87f7c538a2311e5b1044fd9522f4
* _qa_fx_a7.do -- A7 deterministic labelled datasets / owned file trees
* Timothy P Copeland, Karolinska Institutet
*
* qa_fx_a7_labelled, clear [tier(micro|unit) seed(#) perturb(op)]
* Both tiers contain exactly40 rows (no statistical recovery tier supplied).
* Schema id group shared y x text date all_missing onelevel extended.
* group=1,2,5,9 in successive10-row blocks; x=id, y=mod(id,2); exact mean20.5,
* group frequencies10 each, crosstab(y=0,y=1)5 each. Date starts01jan2020.
* Labels shared across group/shared; unicode and long labels, extended missing
* .a-.z plus ordinary .; onelevel=1; all_missing is entirely ordinary missing.
* r(truth_cells): group n y0 y1 xsum xmean; r(truth_mean),r(truth_x_defined).
* Operators label_gaps (group5 unlabeled, gaps1/2/5/9, long/shared labels),
* miss_all_column (x entirely missing, mean undefined flagged, no fake value),
* single_row (id1 alone, truth changes), boundary_values (date29feb2020 and
* immediately adjacent days in first three rows), unsorted (reverse id).
* Primitives string_hostile,long_names,codes_negative,codes_big,miss_extended,
* time_hostile refuse198 and point to existing _qa_hostile.do helpers.
*
* qa_fx_a7_files, clear [tier(micro|unit) seed(#) perturb(op)]
* Requires Stata Python integration and openpyxl. Both tiers create the same
* finite uniquely owned temporary tree under Python tempfile.gettempdir().
* root is never caller-selected. Schema root and path_<key> (strL), one row.
* r(root),r(path_<key>) plus _dta[qa_path_<key>] carry generated paths.
* Keys: hostile readonly missing long noext dta xlsx sas log smcl active.
* Real .dta and .xlsx, extensionless name, quoted/unicode/long path, readonly
* directory(mode0555), absent directory, wrapped .log/.smcl. SAS suffix input
* is TEXT: discovery-only stand-in, never a conversion oracle. r(sas_valid)=0.
* Readonly proves mode bits, not a refusal for privileged/root processes.
* Operators path_hostile (active path spaces+quotes+unicode, >250-byte long
* path additionally returned), path_noext (active name, existing name.dta and
* name.xlsx), stale_sheet (package_summary/package_detail seeded stale cells,
* user_notes contains USER_KEEP). F active is ordinary export.xlsx.
* r(truth_file_count)=10; r(truth_user_cell)="USER_KEEP"; persistent truth chars.
* Successful generation leaves tree for consumer tests. Always call
* qa_fx_a7_cleanup, root(`"`macval(root)'"') after tests (also on failure).
* Cleanup refuses symlinks, wrong basename and missing/mismatched ownership
* marker; never shells out. Makes owned readonly dirs writable before removal.
* Operator expectation EXACT except path_noext REFUSED without replace;
* this is a fixture expectation, not proof that a writer honors the contract.
* unsupported tiers/operators ->198 before replacing data; clear required.
* r(perturb_n_<op>) and _dta[qa_fx_perturb_n] count affected/witness units
* (arms/contrast rows, coefficient rows, labelled rows or workbook sheets).
* All publish r(N/seed/tier/perturb/perturb_applied/expect_class), metadata
* _dta[qa_fx_generator/version/seed/tier/perturb/schema]; truth %21x chars.

python:
def _qa_fxa7_py_1():
    from pathlib import Path
    import os, shutil
    from sfi import Macro
    fxroot = Path(Macro.getLocal("root"))
    try:
        if fxroot.is_symlink() or not fxroot.is_dir() or not fxroot.name.startswith("qa-fx-a7-"):
            raise ValueError("not an owned A7 fixture directory")
        marker = fxroot / ".qa_fx_a7_owner"
        if marker.is_symlink() or marker.read_text(encoding="utf-8") != "qa_fx_a7_files 1.0.0\n":
            raise ValueError("ownership marker mismatch")
        for base, dirs, files in os.walk(fxroot, followlinks=False):
            os.chmod(base, 0o700)
        shutil.rmtree(fxroot)
        if fxroot.exists():
            raise ValueError("tree remains after cleanup")
        Macro.setLocal("cleanok", "1")
    except Exception as exc:
        print("qa_fx_a7_cleanup: " + str(exc))

def _qa_fxa7_py_2():
    from pathlib import Path
    import tempfile, os, shutil
    from sfi import Macro
    from openpyxl import Workbook, load_workbook
    fxroot = None
    try:
        fxroot = Path(tempfile.mkdtemp(prefix="qa-fx-a7-"))
        (fxroot / ".qa_fx_a7_owner").write_text("qa_fx_a7_files 1.0.0\n", encoding="utf-8")
        hostile = fxroot / 'spaces "quotes" Å'
        hostile.mkdir()
        longdir = hostile / ("long_" + "x" * 100) / ("deep_" + "y" * 100)
        longdir.mkdir(parents=True)
        readonly = fxroot / "readonly"
        readonly.mkdir()
        paths = dict(hostile=hostile / 'export "literal" Å.xlsx', readonly=readonly,
                     missing=fxroot / "absent" / "export.xlsx", long=longdir / "long.txt",
                     noext=fxroot / "name", dta=fxroot / "name.dta", xlsx=fxroot / "name.xlsx",
                     sas=fxroot / "discovery.sas7bdat", log=fxroot / "wrapped.log",
                     smcl=fxroot / "wrapped.smcl")
        paths["noext"].write_text("EXTENSIONLESS_KEEP\n", encoding="utf-8")
        paths["sas"].write_text("DISCOVERY STAND-IN; NOT A SAS BINARY\n", encoding="utf-8")
        paths["log"].write_text("line 1: " + "wrapped text "*20 + "\nline 2: END\n", encoding="utf-8")
        paths["smcl"].write_text("{smcl}\n{text}line 1: " + "wrapped text "*20 + "\n{text}line 2: END\n", encoding="utf-8")
        (hostile / "roundtrip.txt").write_text('literal spaces "quotes" Å\n', encoding="utf-8")
        paths["long"].write_text("LONG_KEEP\n", encoding="utf-8")
        (readonly / "keep.txt").write_text("READONLY_KEEP\n", encoding="utf-8")
        os.chmod(readonly, 0o555)
        wb = Workbook()
        wb.active.title = "user_notes"
        wb.active["A1"] = "USER_KEEP"
        if Macro.getLocal("perturb") == "stale_sheet":
            wb.create_sheet("package_summary")["A1"] = "STALE_SUMMARY"
            wb.create_sheet("package_detail")["A1"] = "STALE_DETAIL"
        wb.save(paths["xlsx"])
        wb.close()
        check = load_workbook(paths["xlsx"])
        assert check["user_notes"]["A1"].value == "USER_KEEP"
        if Macro.getLocal("perturb") == "stale_sheet":
            assert check["package_summary"]["A1"].value == "STALE_SUMMARY"
            assert check["package_detail"]["A1"].value == "STALE_DETAIL"
        check.close()
        assert os.stat(readonly).st_mode & 0o222 == 0
        assert not paths["missing"].parent.exists()
        assert len(str(paths["long"]).encode("utf-8")) > 250
        assert sum(len(files) for _, _, files in os.walk(fxroot)) == 9
        paths["active"] = paths["hostile"] if Macro.getLocal("perturb") == "path_hostile" else paths["noext"] if Macro.getLocal("perturb") == "path_noext" else fxroot / "export.xlsx"
        Macro.setLocal("root", str(fxroot))
        for key, value in paths.items():
            Macro.setLocal("path_" + key, str(value))
        Macro.setLocal("fxok", "1")
    except Exception as exc:
        print("qa_fx_a7_files: " + str(exc))
        if fxroot is not None:
            for base, dirs, files in os.walk(fxroot, followlinks=False):
                os.chmod(base, 0o700)
            shutil.rmtree(fxroot)
import types, sys
_qa_fx_a7_module = types.ModuleType("_qa_fixture_a7")
_qa_fx_a7_module.cleanup = _qa_fxa7_py_1
_qa_fx_a7_module.create = _qa_fxa7_py_2
sys.modules["_qa_fixture_a7"] = _qa_fx_a7_module
end

capture program drop _qa_fxa7_args
program define _qa_fxa7_args
    version 16.0
    args who tier op known
    if !inlist("`tier'","micro","unit") {
        di as error "`who': finite deterministic micro/unit only; no recovery MC DGP"
        exit 198
    }
    foreach pair in miss_extended:qa_hostile_missing codes_negative:qa_hostile_codes ///
        codes_big:qa_hostile_codes long_names:qa_hostile_names ///
        string_hostile:qa_hostile_strings time_hostile:qa_hostile_times {
        gettoken primitive helper : pair, parse(":")
        if "`op'"=="`primitive'" {
            di as error "`who': primitive `op'; use `=substr("`helper'",2,.)' in _qa_hostile.do"
            exit 198
        }
    }
    if "`op'"!="" & !`: list op in known' {
        di as error "`who': exactly one supported operator required: `known'"
        exit 198
    }
end

capture program drop _qa_fxa7_meta
program define _qa_fxa7_meta
    version 16.0
    args generator seed tier op schema
    char _dta[qa_fx_generator] "_qa_fx_a7 `generator'"
    char _dta[qa_fx_version] "1.0.0"
    char _dta[qa_fx_seed] "`seed'"
    char _dta[qa_fx_tier] "`tier'"
    char _dta[qa_fx_perturb] "`op'"
    char _dta[qa_fx_schema] "`schema'"
end

capture program drop qa_fx_a7_labelled
program define qa_fx_a7_labelled, rclass
    version 16.0
    syntax , CLEAR [TIER(string) SEED(integer 20260930) PERTurb(string)]
    if "`tier'"=="" local tier unit
    local known label_gaps miss_all_column single_row boundary_values unsorted
    _qa_fxa7_args qa_fx_a7_labelled "`tier'" "`perturb'" "`known'"
    clear
    quietly {
        set obs 40
        gen long id=_n
        gen double group=cond(id<=10,1,cond(id<=20,2,cond(id<=30,5,9)))
        gen double shared=group
        gen byte y=mod(id,2)
        gen double x=id
        gen str40 text=cond(y,"Ångström","plain")
        gen double date=td(01jan2020)+id-1
        format date %td
        gen double all_missing=.
        gen byte onelevel=1
        gen double extended=.
    }
    forvalues j=1/26 {
        local letter=char(96+`j')
        quietly replace extended=.`letter' in `j'
    }
    local lbl _qa_fx_a7_group
    local longlabel "Long label LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL"
    label define `lbl' 1 "One Å" 2 "`longlabel'" 5 "Five" 9 "Nine", replace
    label values group `lbl'
    label values shared `lbl'
    label variable x "Exact sequence 1–40"
    if "`perturb'"=="label_gaps" {
        label define `lbl' 5 "", modify
        local vlabel : label (group) 5, strict
        assert "`vlabel'"==""
        local sharedlabel : value label shared
        assert "`sharedlabel'"=="`lbl'"
        local large : label (group) 2
        assert strlen("`large'")>100
    }
    if "`perturb'"=="miss_all_column" {
        quietly replace x=.
        assert missing(x)
    }
    if "`perturb'"=="single_row" {
        quietly keep in 1
        assert _N==1 & id==1
    }
    if "`perturb'"=="boundary_values" {
        quietly replace date=td(28feb2020) in 1
        quietly replace date=td(29feb2020) in 2
        quietly replace date=td(01mar2020) in 3
        assert date[2]-date[1]==1 & date[3]-date[2]==1
    }
    tempname C
    matrix `C'=(1,10,5,5,55,5.5\2,10,5,5,155,15.5\5,10,5,5,255,25.5\9,10,5,5,355,35.5)
    local mean=20.5
    local defined=1
    if "`perturb'"=="single_row" {
        matrix `C'=(1,1,0,1,1,1)
        local mean=1
    }
    if "`perturb'"=="miss_all_column" {
        forvalues i=1/4 {
            matrix `C'[`i',5]=.
            matrix `C'[`i',6]=.
        }
        local mean=.
        local defined=0
    }
    matrix colnames `C'=group n y0 y1 xsum xmean
    if "`perturb'"=="unsorted" {
        gsort -id
        assert id[1]>id[_N]
    }
    _qa_fxa7_meta qa_fx_a7_labelled `seed' `tier' "`perturb'" "id group shared y x text date all_missing onelevel extended"
    char _dta[qa_truth_cells_rows] "`=rowsof(`C')'"
    char _dta[qa_truth_cells_cols] "6"
    char _dta[qa_truth_cells_colnames] "group n y0 y1 xsum xmean"
    forvalues i=1/`=rowsof(`C')' {
        forvalues j=1/6 {
            char _dta[qa_t_cells_`i'_`j'] "`: display %21x `C'[`i',`j']'"
        }
    }
    char _dta[qa_truth_mean] "`: display %21x `mean''"
    char _dta[qa_truth_x_defined] "`: display %21x `defined''"
    return matrix truth_cells=`C'
    return scalar truth_mean=`mean'
    local affected=cond("`perturb'"=="label_gaps",10,cond("`perturb'"=="boundary_values",3,_N))
    if "`perturb'"=="" local affected=0
    char _dta[qa_fx_perturb_n] "`: display %21x `affected''"
    return scalar truth_x_defined=`defined'
    if "`perturb'"!="" return scalar perturb_n_`perturb'=`affected'
    return scalar N=_N
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`perturb'"
    return local perturb_applied "`perturb'"
    return local expect_class=cond("`perturb'"=="","",cond("`perturb'"=="unsorted","INVARIANT",cond("`perturb'"=="miss_all_column","REFUSED","EXACT")))
end

capture program drop qa_fx_a7_cleanup
program define qa_fx_a7_cleanup
    version 16.0
    syntax , ROOT(string)
    local cleanok=0
    python: __import__("_qa_fixture_a7").cleanup()
    if !`cleanok' exit 198
end

capture program drop qa_fx_a7_files
program define qa_fx_a7_files, rclass
    version 16.0
    syntax , CLEAR [TIER(string) SEED(integer 20260930) PERTurb(string)]
    if "`tier'"=="" local tier unit
    _qa_fxa7_args qa_fx_a7_files "`tier'" "`perturb'" "path_hostile path_noext stale_sheet"
    local fxok=0
    python: __import__("_qa_fixture_a7").create()
    if !`fxok' exit 9
    clear
    quietly set obs 1
    quietly gen strL root=`"`macval(root)'"'
    local keys hostile readonly missing long noext dta xlsx sas log smcl active
    foreach key of local keys {
        quietly gen strL path_`key'=`"`macval(path_`key')'"'
        char _dta[qa_path_`key'] `"`macval(path_`key')'"'
    }
    _qa_fxa7_meta qa_fx_a7_files `seed' `tier' "`perturb'" "root path_hostile path_readonly path_missing path_long path_noext path_dta path_xlsx path_sas path_log path_smcl path_active"
    char _dta[qa_path_root] `"`macval(root)'"'
    char _dta[qa_truth_file_count] "`: display %21x 10'"
    char _dta[qa_truth_sas_valid] "`: display %21x 0'"
    char _dta[qa_truth_user_cell] "USER_KEEP"
    local affected=cond("`perturb'"=="stale_sheet",2,1)
    if "`perturb'"=="" local affected=0
    char _dta[qa_fx_perturb_n] "`: display %21x `affected''"
    char _dta[qa_truth_sas_scope] "discovery fixture only; text stand-in, not conversion oracle"
    capture quietly save `"`macval(path_dta)'"', replace
    local saverc=_rc
    if `saverc' {
        qa_fx_a7_cleanup, root(`"`macval(root)'"')
        exit `saverc'
    }
    foreach key of local keys {
        return local path_`key' `"`macval(path_`key')'"'
    }
    return local root `"`macval(root)'"'
    return local truth_user_cell "USER_KEEP"
    return scalar truth_file_count=10
    return scalar sas_valid=0
    if "`perturb'"!="" return scalar perturb_n_`perturb'=`affected'
    return scalar N=1
    return scalar seed=`seed'
    return local tier "`tier'"
    return local perturb "`perturb'"
    return local perturb_applied "`perturb'"
    return local expect_class=cond("`perturb'"=="","",cond("`perturb'"=="path_noext","REFUSED","EXACT"))
end

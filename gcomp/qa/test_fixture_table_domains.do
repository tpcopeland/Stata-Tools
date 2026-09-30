*! test_fixture_table_domains.do 2026/09/30
*! Author: Timothy P Copeland, Karolinska Institutet
*! A6 model formatter bounds; raw table and actual XLSX text/font/borders/bold.
version 16.0
clear all
set processors 1
set more off
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a6.do"
do "`qa_dir'/_qa_metamorphic.do"
do "`qa_dir'/_qa_state.do"
capture program drop _fx_domain_setup
program define _fx_domain_setup
 qa_fx_a6_estmat, clear post
 matrix fx_expected_B=r(b)
 matrix fx_expected_V=r(V)
 capture estimates drop domain_model
 estimates store domain_model
 quietly regress b se
end
capture program drop _fx_domain_table
program define _fx_domain_table
 assert r(N_models)==1 & r(N_rows)==3 & colsof(r(table))==1
 forvalues i=1/3 {
  assert !missing(r(table)[`i',1],fx_expected_B[1,`i'])
  assert abs(r(table)[`i',1]-fx_expected_B[1,`i'])<1e-12
 }
end
capture program drop _fx_domain_r
program define _fx_domain_r,rclass
 tempname payload
 matrix `payload'=(1,2\3,4)
 return scalar marker=17/120
 return matrix payload=`payload'
 mata: st_local("opaque",char(36)+"bait "+char(96)+"tick"+char(39)+char(34))
 return local opaque `"`macval(opaque)'"'
end
python:
from sfi import Macro,Matrix
from openpyxl import load_workbook
from pathlib import Path
import math,hashlib,sys,types
m=types.ModuleType('_qa_table_domains')
def payload():
 p=Macro.getLocal('property');v=Macro.getLocal('value');book=Macro.getLocal('book')
 w=load_workbook(book,data_only=True);s=w['Fixture'];B=Matrix.get('fx_expected_B')[0];V=Matrix.get('fx_expected_V')
 decimals=int(v) if p=='decimal' else 3
 for i,b in enumerate(B):
  c=s.cell(3+i,2)
  assert c.value==f'{b:.{decimals}f}',(p,v,c.coordinate,c.value,b)
  assert c.font.sz==(int(v) if p=='fontsize' else 10),(p,v,c.font.sz)
  if p=='boldp':
   prob=math.erfc(abs(b/math.sqrt(V[i][i]))/math.sqrt(2))
   assert bool(c.font.b)==(float(v)>0 and prob<float(v)),(v,b,prob,c.font.b)
  if p=='borderstyle':
   styles=[c.border.left.style,c.border.right.style,c.border.top.style,c.border.bottom.style]
   if v in ('thin','medium'): assert styles==[v]*4,(v,styles)
   elif v=='academic': assert styles==[None,None,None,('medium' if i==len(B)-1 else None)],(v,i,styles)
   else: assert styles==[None]*4,(v,styles)
 w.close()
def digest():return hashlib.sha256(Path(Macro.getLocal('book')).read_bytes()).hexdigest()
m.payload=payload;m.digest=digest;sys.modules[m.__name__]=m
end
local tests 0
local pass 0
local fail 0
foreach property in decimal fontsize borderstyle boldp {
 local inside "1 6"
 local outside "0 7"
 local cause "must be between 1 and 6"
 if "`property'"=="fontsize" {
  local inside "1 72"
  local outside "0 73"
  local cause "must be between 1 and 72"
 }
 if "`property'"=="borderstyle" {
  local inside "academic thin medium none"
  local outside "invalid thick"
  local cause "must be academic, thin, medium, or none"
 }
 if "`property'"=="boldp" {
  local inside "0 .001 .999"
  local outside "-.1 1"
  local cause "must be between 0 and 1"
 }
 foreach value of local inside {
  local ++tests
  capture noisily {
   _fx_domain_setup
   tempfile bookbase
   local book "`bookbase'.xlsx"
   _fx_domain_r
   qa_state_snapshot, tag(domainsuccess) rreturn predict(xb stdp)
   quietly gcomptab, models usemodels(domain_model) noeform keepintercept xlsx("`book'") sheet("Fixture") `property'(`value')
   _fx_domain_table
   qa_state_compare, tag(domainsuccess) allow(r)
   python: __import__('_qa_table_domains').payload()
   erase "`book'"
  }
  if !_rc {
   local ++pass
   display "PASS: `property'/`value' actual table/workbook payload"
  }
  else {
   local ++fail
   display "FAIL: `property'/`value' payload rc=" _rc
  }
 }
 foreach value of local outside {
  * expect: REFUSED
  local ++tests
  capture noisily {
   _fx_domain_setup
   tempfile bookbase refusal
   local book "`bookbase'.xlsx"
   quietly gcomptab, models usemodels(domain_model) noeform keepintercept xlsx("`book'") sheet("Fixture")
   python: __import__('sfi').Macro.setLocal('before',__import__('_qa_table_domains').digest())
   log using "`refusal'",text name(fxref)
   _fx_domain_r
   qa_state_snapshot, tag(domain) rreturn predict(xb stdp)
   capture noisily gcomptab, models usemodels(domain_model) noeform keepintercept xlsx("`book'") sheet("Fixture") `property'(`value')
   local rc=_rc
   qa_state_compare, tag(domain)
   log close fxref
   assert `rc'==198
   python: assert __import__('sfi').Macro.getLocal('cause') in Path(Macro.getLocal('refusal')).read_text(); assert Macro.getLocal('before')==__import__('_qa_table_domains').digest()
   erase "`book'"
  }
  if !_rc {
   local ++pass
   display "PASS: `property'/`value' full named refusal and workbook unchanged"
  }
  else {
   local ++fail
   display "FAIL: `property'/`value' refusal rc=" _rc
   capture log close fxref
  }
 }
}
* expect: REFUSED
qa_option_domain, command(gcomptab, models usemodels(domain_model) noeform keepintercept display decimal(@v@)) range(1 6) integer setup(_fx_domain_setup) check(_fx_domain_table)
* expect: REFUSED
qa_option_domain, command(gcomptab, models usemodels(domain_model) noeform keepintercept display fontsize(@v@)) range(1 72) integer setup(_fx_domain_setup) check(_fx_domain_table)
* expect: REFUSED
qa_option_domain, command(gcomptab, models usemodels(domain_model) noeform keepintercept display borderstyle(@v@)) inside(academic thin medium none) outside(invalid thick) setup(_fx_domain_setup) check(_fx_domain_table)
* expect: REFUSED
qa_option_domain, command(gcomptab, models usemodels(domain_model) noeform keepintercept display boldp(@v@)) inside(0 .001 .999) outside(-.1 1) setup(_fx_domain_setup) check(_fx_domain_table)
if `fail'>0 {
 display "RESULT: test_fixture_table_domains tests=`tests' pass=`pass' fail=`fail' status=FAIL"
 capture log close _all
 exit 1
}
else {
 display "RESULT: test_fixture_table_domains tests=`tests' pass=`pass' fail=`fail' status=PASS"
 capture log close _all
}

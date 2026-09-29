#!/usr/bin/env python3
"""Build and independently inspect fixtures for the September 2026 review."""
import argparse
import base64
import os
from pathlib import Path
import re
import shutil
import zipfile

p = argparse.ArgumentParser()
p.add_argument('action', choices=['setup', 'verify'])
p.add_argument('case')
p.add_argument('directory', type=Path)
p.add_argument('receipt', type=Path)
p.add_argument('--size', type=int)
a = p.parse_args()
d = a.directory
if a.receipt.exists():
    a.receipt.unlink()

if a.action == 'setup':
    if d.exists():
        shutil.rmtree(d)
    d.mkdir(parents=True)
    (d / 'a.log').write_text('. display "ALPHA"\nALPHA\n')
    (d / 'b.log').write_text('. display "BETA"\nBETA\n')
    (d / 'empty.log').write_text('')
    if a.case.startswith('F1'):
        ext = a.case.split('-')[1] if '-' in a.case else 'html'
        os.link(d / 'a.log', d / ('out.' + ext))
    if a.case.startswith('F2'):
        (d / 'out.md').write_text('OLD MARKDOWN')
        (d / 'out.md').chmod(0o444)
    if a.case.startswith('F3'):
        (d / 'source').mkdir()
        (d / 'source' / 'a.log').write_text('. graph export "graph.svg", replace\n')
        (d / 'source' / 'graph.svg').write_text('<svg>CORRECT SOURCE GRAPH</svg>')
        (d / 'graph.svg').write_text('<svg>WRONG CWD GRAPH</svg>')
    if a.case == 'F4':
        (d / 'batch').mkdir()
        shutil.copy(d / 'a.log', d / 'batch' / 'same.log')
        (d / 'batch' / 'same.smcl').write_text('{smcl}\n{com}. display "BETA"\n{res}BETA\n')
    if a.case in ('session_graph', 'run_graph'):
        (d / 'graph.svg').write_text('<svg>EXECUTION DIRECTORY GRAPH</svg>')
        (d / 'run.do').write_text('sysuse auto, clear\nscatter price mpg\ngraph export graph.svg, replace\n')
else:
    if a.case.startswith('F1'):
        ext = a.case.split('-')[1] if '-' in a.case else 'html'
        assert (d / 'a.log').read_text() == '. display "ALPHA"\nALPHA\n'
        assert os.path.samefile(d / 'a.log', d / ('out.' + ext))
    elif a.case.startswith('F2'):
        assert (d / 'out.md').read_text() == 'OLD MARKDOWN'
        assert 'ALPHA' in (d / 'out.html').read_text()
    elif a.case.startswith('F3') or a.case in ('session_graph', 'run_graph'):
        expected = ('EXECUTION DIRECTORY GRAPH' if a.case.endswith('_graph')
                    else 'CORRECT SOURCE GRAPH')
        if a.case == 'F3-md':
            text = (d / 'out.md').read_text()
            assert 'source/graph.svg' in text
        elif a.case == 'F3-tex':
            text = (d / 'out.tex').read_text()
            assert 'source/graph.svg' in text
        else:
            text = (d / 'out.html').read_text()
            payloads = re.findall(r'data:image/[^;]+;base64,([^"\s]+)', text)
            decoded = [base64.b64decode(x).decode() for x in payloads]
            if a.case.endswith('_graph'):
                assert (d / 'graph.svg').read_text() in decoded
            else:
                assert any(expected in x for x in decoded), decoded
            assert all('WRONG CWD GRAPH' not in x for x in decoded)
    elif a.case == 'F4':
        assert not list((d / 'out').glob('*'))
        assert 'ALPHA' in (d / 'batch' / 'same.log').read_text()
        assert 'BETA' in (d / 'batch' / 'same.smcl').read_text()
    elif a.case.startswith('F5'):
        for name in ('out.html', 'reverse.html'):
            text = (d / name).read_text()
            assert 'BETA' in text
            assert 'ALPHA' not in text
    elif a.case == 'F6':
        text = (d / 'out.html').read_text()
        assert 'SESSION_TEXT_119' in text
        assert 'body { background: #191a1f;' in text
    elif a.case == 'F8':
        assert 'ALPHA' in (d / 'out.html').read_text()
        assert 'BETA' in (d / 'out.md').read_text()
    elif a.case.startswith('F9'):
        ext = a.case.split('-')[1]
        artifact = d / ('out.' + ext)
        assert a.size == artifact.stat().st_size, (a.size, artifact.stat().st_size)
        if ext == 'docx':
            with zipfile.ZipFile(artifact) as z:
                assert b'ALPHA' in z.read('word/document.xml')
        else:
            from pypdf import PdfReader
            assert 'ALPHA' in ''.join(page.extract_text() for page in PdfReader(artifact).pages)
    else:
        raise ValueError(a.case)
a.receipt.write_text('PASS\n')

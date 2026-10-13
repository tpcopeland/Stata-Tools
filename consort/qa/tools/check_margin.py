# Author: Timothy P Copeland, Karolinska Institutet
# Text must sit inside its box with a visible margin (inches), at several DPIs
import importlib.util, sys
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
from matplotlib.patches import FancyBboxPatch
root = sys.argv[1]
spec = importlib.util.spec_from_file_location("diagram", Path(root) / "consort_diagram.py")
m = importlib.util.module_from_spec(spec); sys.modules["diagram"] = m; spec.loader.exec_module(m)
worst = 1e9
for dpi in (100, 150, 300):
    d = m.ConsortDiagram("Persons with antidepressant dispensing", 15000)
    d.exclude("Follow-up < 30 days", 41)
    fig, ax = d.render(dpi=dpi)
    fig.canvas.draw()
    r = fig.canvas.get_renderer()
    patches = [p for p in ax.patches if isinstance(p, FancyBboxPatch)]
    assert len(ax.texts) == 3 and len(patches) == 3
    for t in ax.texts:
        tb = t.get_window_extent(r)
        cx, cy = (tb.x0 + tb.x1) / 2, (tb.y0 + tb.y1) / 2
        for p in patches:
            pb = p.get_window_extent(r)
            if pb.x0 <= cx <= pb.x1 and pb.y0 <= cy <= pb.y1:
                mg = min(tb.x0 - pb.x0, pb.x1 - tb.x1, tb.y0 - pb.y0, pb.y1 - tb.y1) / dpi
                worst = min(worst, mg)
print("WORST_MARGIN_IN", round(worst, 4))
assert worst >= 0.055, worst
print("MARGIN_PASS")

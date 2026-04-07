#!/usr/bin/env python3
"""
CONSORT-style exclusion diagram generator with automatic layout.

This script is part of the Stata consort package. It generates publication-ready
CONSORT (Consolidated Standards of Reporting Trials) style flowcharts.

Usage (Python API):
    from consort_diagram import ConsortDiagram
    diagram = ConsortDiagram("Initial Population", 10000)
    diagram.exclude("Missing lab values", 234)
    diagram.exclude("Age < 18", 89, remaining="Eligible patients")
    diagram.save("output.png")

Usage (Command line):
    python consort_diagram.py input.csv output.png [--shading] [--dpi 300]

CSV format:
    label,n,remaining
    Initial Population,10000,
    Missing lab values,234,
    Age < 18,89,Eligible patients

The first data row is the initial population (n = total count).
Subsequent rows are exclusions (n = number excluded at this step).
The 'remaining' column provides custom labels for boxes after exclusions.

Requirements:
    Python 3.7+
    matplotlib
"""

from __future__ import annotations

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib.font_manager import FontProperties
import argparse
import csv
import sys
import textwrap
from dataclasses import dataclass


@dataclass
class Box:
    text: str
    x: float
    y: float
    width: float
    height: float


class ConsortDiagram:
    def __init__(self, initial_label: str, initial_n: int, shading: bool = False):
        self.initial_label = initial_label
        self.initial_n = initial_n
        self.exclusions: list[tuple[str, int, str]] = []
        
        # Styling
        self.main_box_color = "#d4e6f1"
        self.exclusion_box_color = "#fadbd8"
        self.edge_color = "#2c3e50"
        self.font_size = 10
        self.title_font_size = 11
        self.box_padding = 0.06
        self.tight_padding = 0.04
        self.medium_padding = 0.05
        self.min_box_width = 0.5
        self.min_excl_width = 0.2
        self.vertical_gap = 0.1
        self.horizontal_gap = 0.2
        self.shading = shading
    
    def exclude(self, label: str, n_excluded: int, remaining: str = ""):
        """Add an exclusion step. remaining="" means auto-generate."""
        self.exclusions.append((label, n_excluded, remaining))
        return self
    
    def set_shading(self, enabled: bool = True):
        """Enable or disable box shading."""
        self.shading = enabled
        return self
    
    def _wrap_text(self, text: str, max_chars: int = 40) -> str:
        """Wrap long text lines to fit in boxes."""
        lines = text.split('\n')
        wrapped_lines = []
        for line in lines:
            if len(line) > max_chars:
                wrapped_lines.extend(textwrap.wrap(line, width=max_chars))
            else:
                wrapped_lines.append(line)
        return '\n'.join(wrapped_lines)

    def _measure_text(self, text: str, fontsize: int) -> tuple[float, float]:
        """Measure text dimensions using matplotlib's renderer.

        Returns width and height in inches.
        """
        fig = plt.figure(figsize=(1, 1), dpi=100)
        renderer = fig.canvas.get_renderer()
        fp = FontProperties(size=fontsize)
        t = fig.text(0, 0, text, fontproperties=fp)
        bbox = t.get_window_extent(renderer=renderer)
        # Small safety margin (8%) to absorb residual scale drift between passes
        w_inches = bbox.width / 100.0 * 1.08
        h_inches = bbox.height / 100.0 * 1.05
        plt.close(fig)
        return w_inches, h_inches
    
    def _format_box(self, label: str, n: int) -> str:
        return f"{label}\nn={n:,}"
    
    def _format_remaining(self, n: int) -> str:
        """Format intermediate remaining boxes - just n value."""
        return f"n={n:,}"
    
    def _draw_arrow(self, ax, start: tuple, end: tuple):
        """Draw an arrow between two points."""
        arrow = FancyArrowPatch(
            start, end,
            arrowstyle='-|>',
            mutation_scale=10,
            color=self.edge_color,
            linewidth=1.5
        )
        ax.add_patch(arrow)
    
    def _compute_box_size(self, text: str, fontsize: int, padding: float,
                          min_width: float, is_exclusion: bool = False) -> tuple[str, float, float]:
        """Wrap text and compute box dimensions in inches. Returns (wrapped_text, w, h)."""
        max_chars = 35 if is_exclusion else 45
        wrapped = self._wrap_text(text, max_chars=max_chars)
        w_in, h_in = self._measure_text(wrapped, fontsize)
        w = max(w_in + padding * 2, min_width)
        h = h_in + padding * 2
        return wrapped, w, h

    def _layout(self) -> list[dict]:
        """Compute box positions and sizes in inches. Returns layout specs."""
        main_x = 0
        current_y = 0
        current_n = self.initial_n
        items = []

        # Initial box
        text = self._format_box(self.initial_label, current_n)
        wrapped, w, h = self._compute_box_size(text, self.title_font_size,
                                                self.medium_padding, self.min_box_width)
        main_box = Box(wrapped, main_x, current_y, w, h)
        items.append({'type': 'main', 'box': main_box, 'fontsize': self.title_font_size,
                       'medium': True, 'tight': False})

        excl_left_x = main_x + main_box.width/2 + self.horizontal_gap

        for i, (label, n_excluded, remaining) in enumerate(self.exclusions):
            current_n -= n_excluded
            is_last = (i == len(self.exclusions) - 1)

            # Exclusion box
            excl_text = self._format_box(label, n_excluded)
            wrapped_e, ew, eh = self._compute_box_size(excl_text, self.font_size,
                                                        self.tight_padding, self.min_excl_width,
                                                        is_exclusion=True)
            excl_y = main_box.y - main_box.height/2 - self.vertical_gap - eh/2
            excl_x = excl_left_x + ew/2
            excl_box = Box(wrapped_e, excl_x, excl_y, ew, eh)
            items.append({'type': 'excl', 'box': excl_box})

            # Next main box
            next_y = excl_y - eh/2 - self.vertical_gap
            if remaining:
                next_text = self._format_box(remaining, current_n)
                use_medium = True
            elif is_last:
                next_text = self._format_box("Final Cohort", current_n)
                use_medium = True
            else:
                next_text = self._format_remaining(current_n)
                use_medium = False

            pad = self.medium_padding if use_medium else self.tight_padding
            wrapped_n, nw, nh = self._compute_box_size(next_text, self.font_size,
                                                        pad, self.min_box_width)
            next_y = next_y - nh/2
            next_box = Box(wrapped_n, main_x, next_y, nw, nh)
            items.append({'type': 'main', 'box': next_box, 'fontsize': self.font_size,
                           'medium': use_medium, 'tight': not use_medium,
                           'prev_main': main_box, 'excl_left_x': excl_left_x,
                           'arrow_y': excl_y})

            main_box = next_box

        return items

    def render(self, figsize: tuple = None, dpi: int = 150) -> tuple[plt.Figure, plt.Axes]:
        """Render the diagram. Layout is computed in inches for exact sizing."""
        # Layout in inches (1 data unit = 1 inch)
        items = self._layout()
        all_boxes = [item['box'] for item in items]

        # Compute bounding box of layout in inches
        margin = 0.4
        min_x = min(b.x - b.width/2 for b in all_boxes) - margin
        max_x = max(b.x + b.width/2 for b in all_boxes) + margin
        min_y = min(b.y - b.height/2 for b in all_boxes) - margin
        max_y = max(b.y + b.height/2 for b in all_boxes) + margin

        # Derive figure size from content (1 data unit = 1 inch)
        content_w = max_x - min_x
        content_h = max_y - min_y
        if figsize is None:
            figsize = (content_w, content_h)

        fig, ax = plt.subplots(figsize=figsize, dpi=dpi)
        ax.axis('off')
        ax.set_xlim(min_x, max_x)
        ax.set_ylim(min_y, max_y)

        # Draw all elements
        for item in items:
            box = item['box']
            if item['type'] == 'main':
                fontsize = item.get('fontsize', self.font_size)
                facecolor = self.main_box_color if self.shading else "white"

                rounding = min(0.05, box.height * 0.3, box.width * 0.1)
                rect = FancyBboxPatch(
                    (box.x - box.width/2, box.y - box.height/2), box.width, box.height,
                    boxstyle=f"round,pad=0.02,rounding_size={rounding:.3f}",
                    facecolor=facecolor, edgecolor=self.edge_color, linewidth=1.5
                )
                ax.add_patch(rect)
                ax.text(box.x, box.y, box.text, ha='center', va='center', fontsize=fontsize)

                # Draw arrows from previous main box
                if 'prev_main' in item:
                    prev = item['prev_main']
                    self._draw_arrow(ax,
                                   (0, prev.y - prev.height/2),
                                   (0, box.y + box.height/2))
                    overlap = 0.01
                    self._draw_arrow(ax,
                                   (-overlap, item['arrow_y']),
                                   (item['excl_left_x'], item['arrow_y']))

            elif item['type'] == 'excl':
                facecolor = self.exclusion_box_color if self.shading else "white"
                rounding = min(0.05, box.height * 0.3, box.width * 0.1)
                rect = FancyBboxPatch(
                    (box.x - box.width/2, box.y - box.height/2), box.width, box.height,
                    boxstyle=f"round,pad=0.02,rounding_size={rounding:.3f}",
                    facecolor=facecolor, edgecolor=self.edge_color, linewidth=1.5
                )
                ax.add_patch(rect)
                ax.text(box.x, box.y, box.text, ha='center', va='center',
                        fontsize=self.font_size)

        plt.tight_layout()
        return fig, ax
    
    def save(self, filename: str, **kwargs):
        """Render and save to file."""
        fig, ax = self.render(**kwargs)
        fig.savefig(filename, bbox_inches='tight', facecolor='white', edgecolor='none')
        plt.close(fig)
        print(f"Saved: {filename}")
    
    def show(self, **kwargs):
        """Render and display."""
        self.render(**kwargs)
        plt.show()


def from_csv(filepath: str) -> ConsortDiagram:
    """
    Load diagram from CSV.
    
    Format:
        label,n,remaining
        Initial Population,10000,
        Missing lab values,234,
        Age < 18,89,Eligible patients
    
    First row = initial population (n = total).
    Subsequent rows = exclusions (n = excluded count).
    """
    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    if not rows:
        raise ValueError("CSV file is empty")
    
    # First row is initial population
    initial = rows[0]
    diagram = ConsortDiagram(initial['label'], int(initial['n']))
    
    # Rest are exclusions
    for row in rows[1:]:
        remaining = row.get('remaining', '').strip()
        diagram.exclude(row['label'], int(row['n']), remaining)
    
    return diagram


def main():
    parser = argparse.ArgumentParser(
        description="Generate CONSORT-style exclusion flowcharts from CSV data.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
CSV format:
  The CSV must have columns: label, n, remaining (remaining is optional)

  First row = initial population (n = total count)
  Subsequent rows = exclusions (n = number excluded)

Example CSV:
  label,n,remaining
  All patients 2015-2023,10000,
  Missing lab values,234,
  Age < 18 years,89,Eligible patients
"""
    )

    parser.add_argument(
        "input",
        nargs="?",
        help="Input CSV file with exclusion data"
    )
    parser.add_argument(
        "output",
        nargs="?",
        help="Output image file (PNG recommended)"
    )
    parser.add_argument(
        "--shading",
        action="store_true",
        help="Enable box color shading (blue for flow, red for exclusions)"
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=150,
        help="Output resolution in DPI (default: 150)"
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Generate a demo diagram"
    )

    args = parser.parse_args()

    # Demo mode
    if args.demo or (args.input is None and args.output is None):
        print("Demo mode - creating sample diagram...")
        diagram = ConsortDiagram("Patients in database\n2015-2023", 45892, shading=args.shading)
        diagram.exclude("Missing baseline labs", 3241)
        diagram.exclude("Age < 18 years", 892)
        diagram.exclude("Prior cancer diagnosis", 2105)
        diagram.exclude("Lost to follow-up < 30 days", 567)
        diagram.exclude("Missing outcome data", 1893, "Final Analytic Cohort")
        diagram.save("consort_demo.png", dpi=args.dpi)
        print("\nUsage: python consort_diagram.py input.csv output.png [--shading] [--dpi 300]")
        return

    # Validate arguments
    if args.input is None or args.output is None:
        parser.error("both input CSV and output file are required")

    # Load and generate diagram
    try:
        diagram = from_csv(args.input)
        if args.shading:
            diagram.set_shading(True)
        diagram.save(args.output, dpi=args.dpi)
    except FileNotFoundError:
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error generating diagram: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

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
    Python 3.6+
    matplotlib
"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import argparse
import csv
import sys
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
    
    def _estimate_text_size(self, text: str, fontsize: int, tight: bool = False, medium: bool = False) -> tuple[float, float]:
        """Estimate text dimensions based on character count."""
        lines = text.split('\n')
        max_chars = max(len(line) for line in lines)
        n_lines = len(lines)
        
        # Approximate character dimensions in data units
        if tight:
            char_width = fontsize * 0.0042
            char_height = fontsize * 0.020
        elif medium:
            char_width = fontsize * 0.0052
            char_height = fontsize * 0.022
        else:
            char_width = fontsize * 0.007
            char_height = fontsize * 0.025
        
        width = max_chars * char_width
        height = n_lines * char_height
        return width, height
    
    def _format_box(self, label: str, n: int) -> str:
        return f"{label}\nn={n:,}"
    
    def _format_remaining(self, n: int) -> str:
        """Format intermediate remaining boxes - just n value."""
        return f"n={n:,}"
    
    def _draw_box(self, ax, x: float, y: float, text: str, color: str, 
                  fontsize: int = None, min_width: float = None, tight: bool = False, medium: bool = False) -> Box:
        """Draw a rounded box with centered text."""
        if fontsize is None:
            fontsize = self.font_size
        if min_width is None:
            min_width = self.min_box_width
        
        if tight:
            padding = self.tight_padding
        elif medium:
            padding = self.medium_padding
        else:
            padding = self.box_padding
            
        w, h = self._estimate_text_size(text, fontsize, tight=tight, medium=medium)
        w = max(w + padding * 2, min_width)
        h = h + padding * 2
        
        facecolor = color if self.shading else "white"
        
        rect = FancyBboxPatch(
            (x - w/2, y - h/2), w, h,
            boxstyle="round,pad=0.02,rounding_size=0.1",
            facecolor=facecolor,
            edgecolor=self.edge_color,
            linewidth=1.5
        )
        ax.add_patch(rect)
        ax.text(x, y, text, ha='center', va='center', fontsize=fontsize)
        
        return Box(text, x, y, w, h)
    
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
    
    def render(self, figsize: tuple = None, dpi: int = 150) -> tuple[plt.Figure, plt.Axes]:
        """Render the diagram."""
        n_steps = len(self.exclusions) + 1
        if figsize is None:
            figsize = (7, max(3, n_steps * 1.1))
        
        fig, ax = plt.subplots(figsize=figsize, dpi=dpi)
        ax.axis('off')
        
        main_x = 0
        current_y = 0
        current_n = self.initial_n
        all_boxes = []
        
        # Draw initial box (medium tight)
        text = self._format_box(self.initial_label, current_n)
        main_box = self._draw_box(ax, main_x, current_y, text, self.main_box_color,
                                   self.title_font_size, medium=True)
        all_boxes.append(main_box)
        
        # Fixed left edge for all exclusion boxes (based on initial box width)
        excl_left_x = main_x + main_box.width/2 + self.horizontal_gap
        
        for i, (label, n_excluded, remaining) in enumerate(self.exclusions):
            current_n -= n_excluded
            is_last = (i == len(self.exclusions) - 1)
            
            # Calculate positions
            excl_text = self._format_box(label, n_excluded)
            
            # Measure exclusion box (tight fit)
            ew, eh = self._estimate_text_size(excl_text, self.font_size, tight=True)
            ew = max(ew + self.tight_padding * 2, self.min_excl_width)
            eh = eh + self.tight_padding * 2
            
            # Exclusion box y is between main boxes
            excl_y = main_box.y - main_box.height/2 - self.vertical_gap - eh/2
            
            # Exclusion box x: left edge aligned, center varies by width
            excl_x = excl_left_x + ew/2
            
            # Draw exclusion box
            excl_box = self._draw_box(ax, excl_x, excl_y, excl_text, 
                                       self.exclusion_box_color,
                                       min_width=self.min_excl_width,
                                       tight=True)
            all_boxes.append(excl_box)
            
            # Next main box position
            next_y = excl_y - eh/2 - self.vertical_gap
            
            # Format next main box - use label only for last box or if custom remaining specified
            if remaining:
                next_text = self._format_box(remaining, current_n)
                use_medium = True  # custom label = medium
            elif is_last:
                next_text = self._format_box("Final Cohort", current_n)
                use_medium = True  # final box = medium
            else:
                next_text = self._format_remaining(current_n)
                use_medium = False  # intermediate = tight
            
            if use_medium:
                nw, nh = self._estimate_text_size(next_text, self.font_size, medium=True)
                nw = max(nw + self.medium_padding * 2, self.min_box_width)
                nh = nh + self.medium_padding * 2
            else:
                nw, nh = self._estimate_text_size(next_text, self.font_size, tight=True)
                nw = max(nw + self.tight_padding * 2, self.min_box_width)
                nh = nh + self.tight_padding * 2
            next_y = next_y - nh/2
            
            next_box = self._draw_box(ax, main_x, next_y, next_text, self.main_box_color,
                                      tight=not use_medium, medium=use_medium)
            all_boxes.append(next_box)
            
            # Draw arrows
            # Vertical arrow first (drawn below horizontal)
            self._draw_arrow(ax,
                           (main_x, main_box.y - main_box.height/2),
                           (main_x, next_box.y + next_box.height/2))
            
            # Horizontal arrow: starts slightly left of vertical line for overlap
            arrow_y = excl_y
            overlap = 0.01
            self._draw_arrow(ax,
                           (main_x - overlap, arrow_y),
                           (excl_left_x, arrow_y))
            
            main_box = next_box
        
        # Adjust view limits
        if all_boxes:
            min_x = min(b.x - b.width/2 for b in all_boxes) - 0.3
            max_x = max(b.x + b.width/2 for b in all_boxes) + 0.3
            min_y = min(b.y - b.height/2 for b in all_boxes) - 0.3
            max_y = max(b.y + b.height/2 for b in all_boxes) + 0.3
            
            ax.set_xlim(min_x, max_x)
            ax.set_ylim(min_y, max_y)
        
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

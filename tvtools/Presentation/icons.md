# Icon Plan for tvtools Presentation

## Current State

Slide 5 (The tvtools Solution) currently uses emoji icons:
- `tvexpose`: 📊 (bar chart)
- `tvmerge`: 🔗 (link)
- `tvevent`: 🎯 (target)

These are functional but could be more visually distinctive and professional.

## Proposed Custom Icons

### 1. tvexpose Icon
**Filename:** `tvexpose-icon.svg` (or `.png` at 128x128px)

**Design Concept:** A timeline being transformed/expanded
- **Visual Elements:**
  - Left side: A simple horizontal line (representing raw prescription data)
  - Right side: Multiple stacked horizontal segments in different colors (blue, purple, orange) representing time-varying intervals
  - An arrow or transformation symbol connecting them
- **Color Palette:**
  - Primary: Blue (#3b82f6)
  - Accent segments: Purple (#8b5cf6), Orange (#f97316), Gray (#9ca3af)
- **Style:** Flat design, no gradients, clean lines, 2-3px stroke weight
- **Dimensions:** Square aspect ratio, designed to work at 48-64px display size

**Prompt for Gemini:**
> Create a flat-design icon representing data transformation. Show a single horizontal bar on the left side transforming (via an arrow or abstract flow) into multiple stacked horizontal segments on the right side. The segments should be in blue (#3b82f6), purple (#8b5cf6), orange (#f97316), and gray (#9ca3af). Style should be minimalist, modern, suitable for a professional presentation. No text. White or transparent background. 128x128px PNG or SVG.

---

### 2. tvmerge Icon
**Filename:** `tvmerge-icon.svg` (or `.png` at 128x128px)

**Design Concept:** Two timelines merging into one synchronized timeline
- **Visual Elements:**
  - Two separate horizontal timelines at top (one blue, one pink/magenta)
  - Converging lines or arrows pointing downward
  - Single combined timeline at bottom showing the merged result (with both colors represented)
- **Color Palette:**
  - Timeline 1: Blue (#3b82f6)
  - Timeline 2: Pink/Magenta (#f472b6)
  - Merged: Gradient or split showing both colors
- **Style:** Flat design, clean geometric shapes
- **Dimensions:** Square aspect ratio, designed to work at 48-64px display size

**Prompt for Gemini:**
> Create a flat-design icon showing two horizontal timelines merging into one. The top portion shows two parallel horizontal bars (one blue #3b82f6, one pink #f472b6). Converging lines or arrows flow downward to a single combined timeline at the bottom that incorporates both colors. Minimalist, modern style suitable for a professional data analysis presentation. No text. White or transparent background. 128x128px PNG or SVG.

---

### 3. tvevent Icon
**Filename:** `tvevent-icon.svg` (or `.png` at 128x128px)

**Design Concept:** A timeline with event markers and competing risks
- **Visual Elements:**
  - Horizontal timeline bar (green representing the tvevent command)
  - A prominent event marker (flag, star, or diamond) at a point on the timeline
  - Secondary markers in different colors representing competing risks (red for death, yellow for emigration)
- **Color Palette:**
  - Timeline: Green (#22c55e)
  - Primary event: Blue (#3b82f6) or Green
  - Competing risk 1: Red (#ef4444)
  - Competing risk 2: Yellow (#eab308)
- **Style:** Flat design, event markers should be distinct and immediately recognizable
- **Dimensions:** Square aspect ratio, designed to work at 48-64px display size

**Prompt for Gemini:**
> Create a flat-design icon representing event integration on a timeline. Show a horizontal green (#22c55e) timeline bar with a prominent blue (#3b82f6) event marker (like a flag or diamond shape) at a central point. Include smaller competing risk markers in red (#ef4444) and yellow (#eab308) at different positions. The design should convey "adding events to a timeline." Minimalist, modern style suitable for a professional medical/statistical presentation. No text. White or transparent background. 128x128px PNG or SVG.

---

## Alternative: Icon Set Theme

For visual consistency, consider having Gemini generate all three icons as a cohesive set with these shared characteristics:

**Unified Style Guidelines:**
- All icons use the same stroke weight (2-3px)
- All icons share a common visual language (rounded corners or sharp corners, not mixed)
- Timeline bars are the central element in all three
- Consistent icon padding/margins
- Same level of detail/complexity

**Combined Prompt for Gemini (generate as a set):**
> Create a set of three matching flat-design icons for a data analysis toolkit called "tvtools". All icons should share a consistent visual style with 2-3px strokes, rounded corners, and be designed for professional presentation slides.
>
> Icon 1 (tvexpose): A single timeline bar transforming into multiple stacked colored segments (blue, purple, orange, gray). Represents "expanding data into time-varying intervals."
>
> Icon 2 (tvmerge): Two parallel timelines (blue and pink) converging/merging into a single combined timeline below. Represents "merging multiple data sources."
>
> Icon 3 (tvevent): A green timeline bar with event markers - a prominent flag/diamond in blue, plus smaller red and yellow markers. Represents "adding events and competing risks."
>
> Colors: Blue #3b82f6, Purple #8b5cf6, Orange #f97316, Gray #9ca3af, Pink #f472b6, Green #22c55e, Red #ef4444, Yellow #eab308.
>
> Each icon: 128x128px, PNG or SVG, transparent background. Deliver as three separate files.

---

## Integration into Presentation

Once icons are generated, place them in the `public/` folder of the sli.dev presentation:

```
tvtools/Presentation/
├── public/
│   ├── tvexpose-icon.png
│   ├── tvmerge-icon.png
│   └── tvevent-icon.png
└── tvtools_presentation.md
```

Then update slide 5 in `tvtools_presentation.md`:

```md
<div v-click class="command-card">
  <img src="/tvexpose-icon.png" class="w-16 h-16 mx-auto mb-4" alt="tvexpose icon" />
  <h3 class="text-xl font-bold text-blue-600">tvexpose</h3>
  ...
</div>
```

Replace:
```md
<div class="text-5xl mb-4">📊</div>
```

With:
```md
<img src="/tvexpose-icon.png" class="w-12 h-12 mx-auto mb-4" alt="tvexpose" />
```

---

## Summary

| Command | Current | Proposed Icon | Key Visual |
|---------|---------|---------------|------------|
| tvexpose | 📊 | tvexpose-icon.png | Single bar → stacked segments |
| tvmerge | 🔗 | tvmerge-icon.png | Two timelines → one merged |
| tvevent | 🎯 | tvevent-icon.png | Timeline with event flags |

**Next Steps:**
1. Generate icons using Gemini with the prompts above
2. Save as PNG files at 128x128px (or SVG)
3. Place in `public/` folder
4. Update slide 5 HTML to reference the new icons

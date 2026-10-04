# Visual references and experiments

**Status:** current capture guidance; browser design lab is a proposed tool.

Tiny Demons uses three different kinds of visual evidence. Keep them labeled so
an experiment cannot be mistaken for the shipped game.

## 1. Captures of the real game

Use an in-game capture when documenting actual appearance, behavior, layout,
or performance. Capture through the active Godot editor/MCP workflow or the
published browser build. Preserve the original image. If a crop or annotation
helps explain it, keep that as a separate derivative and say what changed.

Store curated wiki captures under `docs/wiki/media/game/` and use descriptive
names such as `electric-status-room-web-0.3.33.png`. Do not commit every
debugging screenshot; keep raw investigation captures local unless they are
needed to reproduce a finding.

Every capture should include nearby text or a caption with:

- build version and commit (or explicitly say **unversioned local build**);
- capture date and target (desktop, mobile browser, or device/browser details);
- scene or gameplay state shown;
- capture path (Godot editor, exported web build, or device);
- any crop, markup, palette change, or other alteration.

Use PNG for pixel-art stills and short, tightly cropped GIF/WebM for motion.
Prefer a few representative images over repeated near-identical frames. Capture
at native game resolution when inspecting pixels; provide a nearest-neighbor
scaled view when a larger reading size helps.

## 2. Browser-only design sketches

A small web page can make an idea easy to compare without launching Godot. The
most practical first version is a static HTML page with JavaScript and Canvas or
SVG. It can show authored sprites, palette variants, simple timing, layout,
range, and parameter controls in a browser.

This is a **prototype renderer**, not the Godot renderer. GDScript, Godot scene
trees, materials, collision, physics, and real game timing do not run in that
page. For a browser sketch to stay connected to the game:

1. Reuse approved PNG sprite/art assets or generated preview images; do not make
   a second copy of art or silently alter the production asset.
2. Read a small, stable JSON preview contract for tunable values where that data
   can be exported safely. Do not hand-copy numbers into JavaScript and then
   call the page authoritative.
3. Keep prototype code isolated under a future `design-lab/` directory and make
   it open locally as static files. Avoid adding dependencies until a real
   experiment needs them.
4. Label every render **prototype** and link it to the feature brief and its
   current source of rules.
5. Promote a result only after the game implementation is checked in Godot and
   compared in the real game. A browser sketch cannot validate hitboxes,
   collision, in-engine palette shaders, or mobile performance.

The current Pages workflow publishes the Godot web export. A hosted design lab
would need an intentional deployment layout (for example a separate `/lab/`
path) and an update to that workflow. Keep it as a separate proposal until its
first useful preview and build integration are designed; do not mix prototype
files into the game's export output by accident.

## 3. Diagrams and generated maps

Use SVG or Mermaid for explanatory diagrams and procedural map summaries when
they are generated from data. Keep the generator and its input alongside the
output, and label fixed-seed outputs with their seed and run. These explain the
rules; they are not screenshots of the game.

## First design-lab slice

When the lab is built, start with one low-risk visual question (for example,
comparing status-aura colors around the same sprite). Keep the first page
static, include the real source sprite, allow a small number of controls, and
save a screenshot of the chosen comparison in the feature brief. Do not begin
with a broad simulated combat engine.

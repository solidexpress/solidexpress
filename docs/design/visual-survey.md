# Visual survey — SolidExpress vs CAD references

Analysis only. No product-code change is implied by this file. Ranked work
below is the backlog a later agent should implement; the chrome contract for
*how* a change must land stays in [`docs/plan/landing-protocol.md`](../plan/landing-protocol.md).

**Date:** 2026-10-17. **Branch:** `cursor/visual-survey`.

---

## Method and sources

### 1. SolidWorks (primary, pixel evidence)

412 JPEGs from the Fully Defined *Revolves and Sweeps* candlestick tutorial
(SolidWorks 2022, white graphics area). Index:
[`docs/loop/rung-06-frames/index.md`](../loop/rung-06-frames/index.md)
(YouTube `m7GuVfPN164`). Frames cited below are those files.

Sampled with ffmpeg (`rgb24`) on the 960×540 JPEGs:

| Sample | RGB | Where |
|---|---|---|
| Graphics empty | **(244, 245, 249)** ≈ `#F4F5F9` | `t0051.jpg` centre of the viewport |
| Feature tree / ribbon | **(65, 65, 65)** | `t0051.jpg` FeatureManager and CommandManager |
| Body mid-grey | **(146–164, 147–165, 149–167)** | `t0820.jpg`, `t0813.jpg` |
| Body crease / silhouette | **(80–113, 80–114, 82–116)** | `t0820.jpg` |
| Cut preview (drafted hole) | **(141–148, 142–156, 106–118)** olive | `t0890.jpg` |
| Transparent body | **(192–205, 193–206, 197–208)** | `t0915.jpg` |

### 2. Onshape, Fusion 360, FreeCAD, Plasticity (docs + public screenshots)

Cited URLs are in each section. These are the current public help pages, not
in-app captures from this machine.

### 3. SolidExpress current look

**Headless / live render:** not available in this environment. `tools/godot/godot`,
`game/bin/libsxcore.so`, and `/opt/occt-8.0.1` are missing, so `make run`,
`SX_AUTOMATION=1` + `tools/sxdrive.py screenshot`, and Godot `--headless`
viewport capture cannot start. The existing screenshot path is
`game/scripts/automation_bridge.gd` `_cmd_screenshot` (writes a PNG of
`Viewport.get_texture()`).

**Used instead:** film posters in `website/assets/screenshots/` (1600×900,
sampled as PNG RGB) plus the constants in the scripts those posters were
shot from. Newer films (`ubc_wrench.png`, `tutor1.png`, `fillet_chain_pocket.png`,
`sketch_tools.png`) are the **current shop look**. Older films
(`precision_plate.png`, `extrude_cylinder.png`) still show View → Scenic
(canyon HDRI) and denser docks — useful as the opt-in environment, not the
default.

| Sample | RGB | File |
|---|---|---|
| Shop viewport | **(31, 36, 46)** | `ubc_wrench.png`, `sketch_tools.png` |
| Left rail / HUD panel | **(25, 27, 27)** / **(25, 26, 29)** | `ubc_wrench.png` |
| Film-look body | **(194, 204, 224)** | `ubc_wrench.png` (film albedo, not app default) |
| Sketch pad fill | **(32, 61, 77)** | `sketch_tools.png` |
| Scenic sky | **(138, 178, 217)** | `precision_plate.png` |

App defaults in code (flat, non-film): background `Color(0.16, 0.17, 0.20)` →
**(41, 43, 51)** before ACES; body `BODY_COLOR = Color(0.72, 0.74, 0.78)` with
metallic **0** / roughness **0.78** when Scenic is off. Films call
`Main.apply_film_look()` (`Color(0.78, 0.84, 0.92)`, key energy 1.65), so
posters are a stop brighter than a user's first launch.

---

## 1. Background (gradient, flat, environment)

**SolidWorks.** This tutorial uses a **plain near-white** graphics area, not
the classic blue gradient. `t0051.jpg`, `t0310.jpg`, `t0820.jpg` are all
`#F4F5F9` with no floor, no HDRI, no vignette. Officially SW scenes still
support Color / Gradient / Image / Environment, and lighting can be a
spherical HDRI **while the 2D backdrop stays a solid or gradient**
([Edit Scene — Basic](https://help.solidworks.com/2023/english/SolidWorks/sldworks/HIDD_DVE_SCENE_EDITOR_BASIC.htm),
[System Colors](https://help.solidworks.com/2024/english/SolidWorks/sldworks/HIDD_OPTIONS_SYSTEM_COLORS.htm),
[Javelin background how-to](https://www.javelin-tech.com/blog/2022/12/solidworks-background-colors/)).
Dassault still notes that a **blue gradient** is the stock pairing with
status colours
([Background Color](https://help.solidworks.com/2025/english/SolidWorks/acadhelp/c_Background_Color.htm)).

**Onshape.** Part Studio is a light-grey/white canvas in light theme; Dark
mode inverts chrome. Render Studio can **decouple** HDRI lighting from the
visible backdrop (solid `#FFFFFF`, image, or unchecked Background)
([Camera panel](https://cad.onshape.com/help/Content/RenderStudio/render_studio_interface_camera_panel.htm),
[Environments library](https://cad.onshape.com/help/Content/RenderStudio/render_studio_interface_environments_library.htm)).

**Fusion.** Design workspace Environments: Photo Booth (default white), Grey
Room, Dark Sky, Tranquility Blue, Infinity Blue
([choose lighting environment](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/How-to-choose-different-lighting-environment-in-design-workspace.html)).
Render: Environment vs Solid Color, plus ground plane
([scene settings](https://help.autodesk.com/view/fusion360/ENU/?contextId=RND-SCENE-SETTINGS)).

**FreeCAD.** Preferences → Display → Colors: Simple / Linear gradient /
Radial gradient. Default linear gradient is a dark-blue top
`(51, 51, 101)` to a grey-blue bottom `(151, 151, 170)`
([Preferences Editor](https://wiki.freecad.org/Preferences_Editor),
[`DlgSettingsViewColor.ui`](https://github.com/FreeCAD/FreeCAD/blob/6438b1bb/src/Gui/PreferencePages/DlgSettingsViewColor.ui)).

**Plasticity.** Dark viewport; colour is a preference (Viewport Colors).
Render Mode applies an HDRI **for lighting only** — “this won't affect the
viewport background”
([Render Mode](https://doc.plasticity.xyz/plasticity-essentials/render-mode),
[Preferences](https://doc.plasticity.xyz/plasticity-essentials/preferences)).

**SolidExpress.** Default is **flat shop charcoal**
`Environment.BG_COLOR` `Color(0.16, 0.17, 0.20)` (`game/scripts/main.gd`
`_sync_world_background`, `_make_canyon_environment`). View → Scenic swaps
to the canyon panorama (`game/canyon_hdri/`) and turns body metallic on.
Sketch and section **force flat** so the infinite sky does not punch through
the workplane. Films lock flat (`FilmPresentation.FLAT_BG`). A faint XY grid
(`world_gizmos.gd` alpha 0.18/0.28) and three origin-plane quads
(`DATUM_PLANE_COLOR` alpha 0.22) sit on top of that colour, so empty space
never reads as a clean sheet (`hexkey.png`, `tutor1.png`).

**Gap.** Peers treat backdrop, lighting, and floor as three knobs. SX
bundles lighting with the panorama (Scenic) and always composites grid +
planes onto the shop colour. Sketch in SW/Onshape/Fusion is a **light
sheet**; SX sketch is the same dark shop (`sketch_tools.png`).

---

## 2. Shading and materials

**SolidWorks.** `t0813.jpg` / `t0820.jpg` / `t0828.jpg`: **matte mid-grey
plastic**, simple key light, darker undersides, no environment reflection,
no SSAO halo, no floor shadow. Shaded with Edges (spoken at 13:33,
`t0813.jpg`). `t0890.jpg` shows a yellow-green cut preview on the same
shader. `t0915.jpg` is Display Pane transparency — a ghosted grey body, not
a glass BSDF.

**Onshape.** Default **Shaded with edges**. Parts get a rotating 8-colour
palette; faces are Lambert-ish with a soft highlight. Per-part
transparency is a 0–1 slider
([Shaded / Unshaded / Translucent](https://cad.onshape.com/help/Content/View/shaded_unshaded__and_translucent.htm),
[Colors](https://cad.onshape.com/help/Content/colors.htm)).

**Fusion.** Photo Booth is a bright studio HDRI on a white cyclorama;
Grey Room is a dimmer grey. Sketch line colours **flip** with the
environment (blue/black vs purple/white)
([sketch line colours](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/What-does-the-color-line-means-in-Fusion-360-sketch.html)).

**FreeCAD.** Coin3D: directional lights + optional gradient. Selection cyan
`(0, 171, 255)`, preselection `(10, 200, 255)`
([`DlgSettingsSelection.ui`](https://github.com/FreeCAD/FreeCAD/blob/6438b1bb/src/Gui/PreferencePages/DlgSettingsSelection.ui)).

**Plasticity.** Default **Ceramic Dark matcap** (view-locked lighting, very
readable form). Render Mode: HDRI + **always-on AO** + ground-plane shadow
([Shader Mode](https://doc.plasticity.xyz/plasticity-essentials/plasticity-interface/shader-mode),
[25.2 notes](https://plasticity-document-revisions.vercel.app/release-notes/whats-new-2025.2)).

**SolidExpress.** Spatial shader `diffuse_lambert` + `specular_schlick_ggx`
(`document_view.gd` `_make_body_shader`). Flat shop: metallic **0**,
roughness **0.78**, ACES, key `DirectionalLight3D` energy **0.55**, ambient
`Color(0.55, 0.57, 0.62)` × 0.75. **No SSAO / SSIL / glow.** Back faces
multiply albedo by 0.55 so shells read. Scenic restores metallic **0.92** /
roughness **0.35** and sky IBL (`ssr_enabled`). Films further lift exposure
and add 0.16 emission, which is why `ubc_wrench.png` looks chalky-blue
rather than SW grey. `tutor1.png` still shows a dull, slightly brown-grey
top face against a dark grid — form is harder to read than `t0820.jpg`.

**Gap.** SW/Onshape sell **clay + edges**. Plasticity sells **matcap + AO**.
SX shop mode is clay without AO, with a cold film albedo on marketing
shots and a darker default in-app. Scenic is a canyon, not a studio.

---

## 3. Edge and silhouette lines

**SolidWorks.** `t0820.jpg` / `t0813.jpg`: every B-rep edge is a **dark
grey/black hairline**, including silhouettes of the revolve and the sweep.
Hidden edges off. Tangent edges on the fillet-like revolve blends are
drawn. The edge is darker than the body crease, so the outline is a
drawing, not a crack.

**Onshape.** Shaded with edges is the default; tangent edges can be
visible / phantom / removed
([Camera and render options](https://cad.onshape.com/help/Content/View/camera_and_render_options.htm),
[Graphics preferences](https://cad.onshape.com/help/Content/View/graphics_preferences.htm)
also expose phantom-edge styling). Highlight boundary edges is a separate
toggle.

**Fusion.** Display Settings → Visibility of sketch/body edges; shaded with
visible edges is the usual Design look.

**FreeCAD.** `DrawStyle` plus per-object Line Color / Line Width.

**Plasticity.** Viewport toggles for Edges / Curves / Faces; default edges
are **black**, selection **yellow**. X-Ray shows occluded edges
([object types](https://doc.plasticity.xyz/plasticity-essentials/object-types)).
Black Silhouette / Color Silhouette shaders exist for form check.

**SolidExpress.** Default `DisplayMode.SHADED_EDGES`. Edges are
`ImmediateMesh` `PRIMITIVE_LINES`, unshaded `EDGE_COLOR = Color(0.12, 0.13, 0.16)`
(`document_view.gd` `_rebuild_edges`). One framebuffer pixel, no screen-space
width, no hidden-line dashed style, no tangent-edge filter. On the dark
shop they read as **cracks**; on the pale film body (`ubc_wrench.png`,
`fillet_chain_pocket.png`) they are closer to SW but still thinner and
colder. `ViewHud` cycles Shade / Edges / Wire (`view_hud.gd`).

**Gap.** Need a slightly **lighter, 1.5–2 px** edge (or a silhouette pass)
and a tangent-edge option. Wireframe hidden-line (dashed) is missing.

---

## 4. Selection and hover (faces, edges, vertices, preselection)

**SolidWorks.** Sketch: selected entities go **cyan/light-blue**; trim-to-
closest paints the doomed segment **orange-brown** (`t0214.jpg`). Equal
relation: two verticals selected together (`t0233.jpg`). 3D: the top face
of the candlestick is a **green** preselect/select in `t0828.jpg` before
Extruded Cut. Cut preview is olive with a **green** contour (`t0890.jpg`).
Property-manager picks colour-match the viewport (blue profile / pink path
at `t0785.jpg`–`t0804.jpg`).

**Onshape.** Graphics selection is **vivid yellow `#ffc107`**. Sketch hover
`#f3bf8e`, sketch select `#ffc107`. Tree names highlight blue
([Colors](https://cad.onshape.com/help/Content/colors.htm),
[Viewing and selecting](https://cad.onshape.com/help/Content/Primer/viewing_and_selecting.htm)).

**Fusion.** Body/face prehighlight is a cool **teal/cyan**; selection is a
stronger cyan. Sketch selection is typically blue → darker.

**FreeCAD.** Selection `(0, 171, 255)`, preselection `(10, 200, 255)` —
two close cyans, documented as a colour-vision problem in sketch
([issue 10607](https://github.com/FreeCAD/FreeCAD/issues/10607)).

**Plasticity.** Hover lighter, selection **yellow outline**; faces go light
yellow; curves blue → yellow
([object types](https://doc.plasticity.xyz/plasticity-essentials/object-types)).

**SolidExpress.** Distinct materials already exist (`document_view.gd`):

| State | Colour |
|---|---|
| Body select | `Color(0.55, 0.68, 0.9)` cool blue |
| Face select | `Color(1.0, 0.62, 0.15)` orange |
| Body hover | `Color(0.78, 0.84, 0.92)` pale |
| Face hover | `Color(0.95, 0.82, 0.45)` yellow |
| Edge hover | same yellow, `no_depth_test` |
| Edge select overlay | same orange as face, `no_depth_test` |
| AABB corners | `Color(0.15, 0.55, 1.0)` |

Hover is wired (`viewport_interaction.gd` `_update_hover` →
`DocumentView.set_hover`). **Vertices** have no hover glyph in 3D (sketch
points do). Face hover (yellow) and face select (orange) are adjacent
hues — weaker than Onshape yellow-on-clay or SW green-on-grey. The blue
AABB corners (`document_view.gd` `_selection_corners`) are a SX extra that
peers do not draw; they fight the part on small bodies
(`fillet_chain_pocket.png` does not show them because the film caption
hides idle selection chrome).

**Gap.** Pick one industry language and stick to it: **yellow select /
cooler hover** (Onshape/Plasticity) or **green face / cyan sketch** (SW).
Do not keep orange-select + yellow-hover + blue-corners as three competing
accents.

---

## 5. Dimension and sketch display

**SolidWorks.** `t0073.jpg` (under-defined stub), `t0160.jpg` (R10 +
coincident), `t0310.jpg` (mixed blue/black profile + green square glyphs +
black `220.00` / `R10.00` / `90.00` with arrows and witness lines),
`t0460.jpg` (hidden-lines-removed body + blue centerline), `t0750.jpg`
(heads-up Hide/Show Temporary Axes). Spoken at 05:09: green relation
squares can be hidden (`t0309.jpg`–`t0314.jpg`). Status bar shows
Under Defined / Fully Defined.

Industry colour grammar (SW / Onshape / Fusion Photo Booth):

| State | Colour |
|---|---|
| Under-defined entity | Blue (`#0000FF` in Onshape) |
| Fully defined | Black (white on Fusion Grey Room) |
| Over-defined / error | Red (`#bd3039` Onshape) |
| Construction | Grey / orange dashed (Fusion) |
| Relation glyph | Green square (SW); grey/black icon (Onshape) |
| Dim text + arrows | Black |
| Inference while drawing | Yellow (SW) |

Onshape documents this exactly
([troubleshooting sketches](https://cad.onshape.com/help/Content/Sketch/troubleshooting_sketch_geometry.htm),
[Colors](https://cad.onshape.com/help/Content/colors.htm)). Fusion:
([line colour meanings](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/What-does-the-color-line-means-in-Fusion-360-sketch.html)).

**SolidExpress.** Constants in `sketch_mode.gd`:

| Token | Value | Role |
|---|---|---|
| `COLOR_ENTITY` | `(0.95, 0.95, 1.0)` | **All** unconstrained geometry (white) |
| `COLOR_CONSTRAINED` | `(0.35, 0.85, 0.45)` | Whole sketch when `last_dofs == 0` |
| `COLOR_CONFLICT` | `(0.95, 0.3, 0.25)` | Conflicting entities |
| `COLOR_CONSTRUCTION` | `(0.45, 0.45, 0.48)` | Construction |
| `COLOR_GLYPH` | `(0.65, 0.8, 1.0)` | H / V / ∥ / ⊥ / = / ◉ / ⌒ letters |
| inference label | `(1.0, 0.85, 0.3)` | Yellow — this one matches SW |

The landing protocol already states the intended grammar: “gray weak dims,
yellow inference, **blue/black/red entities**”
(`docs/plan/landing-protocol.md` Visibility). Code has not followed it.
Solver reports **whole-sketch DOF only**, so green is a flood fill, not
per-entity black (`_entity_draw_color`).

Dimensions are **Label3D text** (`DIM_LABEL_FONT` 18 px, outline 4, default
white) with **no witness lines and no arrows**. `ui_icons.gd` already
draws a proper dimension glyph (`M5 8v12M19 8v12M5 14h14` plus arrowheads)
for the toolbar icon; the viewport does not. Driven vs driving is
Alt+click (`docs/howto/visual-sketch-tools.md`) but not a grey-vs-black
colour. DOF chip on the sketch rail: `"%d"` blue / `"OK"` green / `"!"`
red (`main.gd` `_on_sketch_solve`).

Committed sketches in 3D become **gold pads** (`sketch_pad_overlay.gd`
`PROFILE_COLOR_CLOSED = (0.98, 0.78, 0.08)`) — see `sketch_tools.png`.
That is a SX invention; SW inactive sketches are thin grey
(`t0460.jpg`, `t0750.jpg`).

**Gap.** Highest-leverage CAD-literacy miss in the product: people trained
on SW/Onshape/Fusion cannot read DOF from colour, and they cannot see
what a dimension is measuring.

---

## 6. View cube and triad

**SolidWorks.** This tutorial never shows a 3D ViewCube. Navigation is the
**heads-up View toolbar** (`t0750.jpg` Hide/Show flyout in the graphics
area) plus an **RGB origin triad** in the lower-left of the viewport
(`t0051.jpg`, `t0820.jpg`). Standard views live on that toolbar / View
Orientation (spacebar).

**Onshape.** 3D View Cube, upper-right: faces = orthographic, corner
circles = trimetric, arrows = 45°. A smaller cube under it is Camera and
render options
([View cube](https://cad.onshape.com/help/Content/View/view_navigation_and_the_view_cube.htm),
[primer](https://cad.onshape.com/help/Content/Primer/viewing_and_selecting.htm)).

**Fusion.** Autodesk ViewCube, typically upper-right; its shading even
previews the scene light
([101 tips PDF](https://static.au-uw2-prd.autodesk.com/Class_Handout_CP226398_101_Fusion_360_Tips_and_Tricks_Scott_Moyse.pdf)).

**FreeCAD.** NaviCube (default on, corner configurable, inactive opacity
in 1.0). Default base `e2e8efc0`, highlight `aae2ffff`
([Navigation Cube](https://wiki.freecad.org/Navigation_Cube)). Separate
corner coordinate system.

**Plasticity.** No cube. Viewport header + keyboard. Overlay toggle for
grid/axes.

**SolidExpress.** Two widgets, both bottom-right (`view_hud.gd`):

1. `OriginTriadHud` — RGB sticks, 2 px, ~40 px tall, `COLOR_X/Y/Z`
   matching `world_gizmos.gd`. Visible in `ubc_wrench.png`.
2. `ViewWidget` — **92×92 3×3 orthographic grid** of labelled cells
   (FRONT / TOP / ISO / …), not a cube. Fill
   `Color(0.28, 0.32, 0.38)`, active `Color(0.35, 0.55, 0.75)`.
   Under it: Shade / Section / Zebra / Frame / View strip
   (`tutor1.png`, `ubc_wrench.png`).

The 3×3 map works but does not **preview camera attitude** the way a cube
does, and it does not match Fusion/Onshape muscle memory. The triad is
correct and small; SW's triad sits on the **model** lower-left, SX's sits
on the HUD.

**Gap.** Replace or supplement `ViewWidget` with a real perspective cube
(FreeCAD NaviCube / Onshape). Keep the triad; consider moving it to the
viewport corner like SW.

---

## 7. Panels and toolbars

**SolidWorks.** Dense: CommandManager tabs (Features / Sketch / …) with
**colour icons**, dark FeatureManager (~`#414141`) listing History /
Sensors / Origin + features, PropertyManager that **replaces** the tree
during a command (`t0205.jpg` Trim, `t0760.jpg` Sweep, `t0865.jpg` Cut
Extrude), Task Pane tutorial on the right in this video. Heads-up view
toolbar floats in the graphics area. Sketch confirmation is a green
checkmark (`t0214.jpg`).

**Onshape.** Browser: Feature list left, Parts list under it, thin toolbar
top, right-side appearance/properties. Much less ribbon.

**Fusion.** Horizontal toolbar + **timeline along the bottom**. Browser
left. Marking menu.

**FreeCAD.** Classic workbench toolbars + Combo View tree. Heavier than
Onshape, lighter than a SW ribbon.

**Plasticity.** Minimal: outliner, viewport header, command line. Keyboard
first.

**SolidExpress.** Deliberately sparse (landing-protocol chrome budget):

- File / Edit / Insert / View / Snap on a dark `TopChrome`
- 36×36 **stroke icons** `#dde2ea` / accent `#6ab0f3` (`ui_icons.gd`)
- Left rail swaps Create / Sketch / Modify (`main.gd`)
- Timeline / Variables **off until View-toggled**; films often force them
  (`lesson2_box.png`, `hexkey.png`)
- `SelectionStrip` top-centre verbs
- `PropertyPanel` JSON schema, 240 px cap
- Body 13 px (`UiScale`), panel fill `Color(0.16, 0.17, 0.20)` with
  `Color(0.22, 0.23, 0.26)` 1 px border (`main.gd`
  `_opaque_popup_panel_style`, `timeline_panel.gd`, `view_hud.gd`)

`ubc_wrench.png` is the target density: rail + HUD + status, model in the
clear. `precision_plate.png` is the anti-pattern: Scenic HDRI + timeline +
selection card + TriBall rings + captions.

Icons are consistent but **monochrome**. SW/Fusion sketch tools are
coloured (line blue, smart dim, trim orange). SX Jaw / Sketch / primitives
all share the same silver stroke, so the rail is a column of similar
glyphs (`ubc_wrench.png` left edge).

**Gap.** Keep the density budget. Recolour a **small set** of rail icons
(Sketch, Smart Dim, Trim, Extrude, Fillet) so they scan like SW without
growing a ribbon. Timeline rows already have type icons — good. Do not
add a CommandManager.

---

## 8. Planned background-removal (flat colour, transparent, renders / exports)

How the references do it:

| Product | Viewport | Still / render export |
|---|---|---|
| **SolidWorks** | Scene background Color / Gradient / Image / None. Lighting can stay | PhotoView / Visualize: save **PNG**; alpha from “None” background or automatic PNG alpha ([Javelin](https://www.javelin-tech.com/blog/2013/05/photoview-360-transparent-background-render/), [Final Render](https://my.solidworks.com/reader/onlinehelp/2021%252Fenglish%252Fsolidworks%252Fsldworks%252Fr_final_render_window.htm/final-render-window)) |
| **Onshape** | Theme + Graphics preferences | Render Studio: Format PNG + **Remove Background** (alpha) ([Render options](https://cad.onshape.com/help/Content/RenderStudio/render_studio_interface_render_options.htm)). Camera panel: solid colour vs environment |
| **Fusion** | Design Environments (white / grey / dark) | In-canvas Capture Image: PNG + **Transparent background** checkbox ([Capture](https://help.autodesk.com/cloudhelp/ENU/Fusion-Render/files/GUID-BF31CE62-D1A2-4FE0-9EBA-692EF841EE9A.htm)). Render Scene Settings: Background Environment or Solid Color |
| **FreeCAD** | Simple / gradient | TechDraw / screenshot; no first-class transparent-PNG render |
| **Plasticity** | Viewport colour preference; HDRI does not change it | Export image of the viewport; AO/HDRI stay in Render Mode |

**SolidExpress today.**

- Viewport: Flat `#292B33` (`0.16, 0.17, 0.20`) or Scenic canyon. No
  “None”. `Window.transparent_bg` is forced **false**
  (`main.gd` `_opaque_popup_window`; tests in
  `game/tests/run_rung01_replan13_chrome.gd`).
- File menu exports STEP / STL / 3MF / glTF / drawings / AI context —
  **no PNG/JPEG of the viewport** (`main.gd` ~3455).
- Automation screenshot is RGB, no alpha
  (`automation_bridge.gd` `_cmd_screenshot`).
- Films always flatten (`apply_film_presentation`). Website posters
  therefore cannot composite onto marketing pages without a dark
  rectangle (`ubc_wrench.png`).

`t0895.jpg`–`t0915.jpg` are **body** transparency (Display Pane), which SX
also lacks as a per-body slider. That is a different knob from backdrop
removal.

**How SX should do it** (three stacked options, matching SW scene + Fusion
capture):

1. **Shop (default)** — current flat colour. Optionally lift to a light
   shop `#E8EAEE`–`#F4F5F9` when we take sketch colour-literacy (see
   ranked #2). Keep Scenic as opt-in IBL.
2. **Solid backdrop** — user colour, lighting unchanged (Plasticity /
   Onshape Render Studio pattern). Needed for white product shots without
   the canyon.
3. **Transparent** — `Environment.BG_COLOR` alpha 0 + viewport transparent
   clear, **hide grid, origin planes, HUD, captions**. File → Export Image
   (PNG). Same path for film outros and `website/assets/screenshots` so
   posters composite. Keep IBL/key so metals still shade (do not turn
   lights off with the backdrop).

Phase 9 already budgets a screenshot pipeline
(`docs/plan/implementation-plan.md` 9.3–9.4). Background-removal is the
user-facing slice of that, not a new architecture.

---

## Ranked improvements

Effort: **S** one file / constants; **M** a few scripts + tests; **L** new
shader/pass or kernel DOF.

### 1. Sketch entity colours: blue / black / red — **S/M**

- **Change:** `COLOR_ENTITY` → `Color(0.25, 0.55, 1.0)` (readable blue on
  dark; or `#1A73E8`). `COLOR_CONSTRAINED` → `Color(0.92, 0.94, 0.96)`
  (near-white “black” on dark shop) **or** switch the sketch sheet to light
  and use `#000000`. `COLOR_CONFLICT` stay red. If/when the solver yields
  per-entity DOF, colour per entity; until then keep whole-sketch flip but
  use black/white, not green.
- **Why:** `t0073.jpg`, `t0310.jpg`; Onshape `#0000ff` / `#000000` /
  `#bd3039`; Fusion Photo Booth; landing-protocol Visibility line.
- **Impact:** First-session literacy. Highest.
- **Files:** `game/scripts/sketch_mode.gd` (`COLOR_*`, `_entity_draw_color`);
  `game/scripts/main.gd` (`_on_sketch_solve` chip); tests
  `game/tests/run_sketch_fully_defined*.gd`, `run_visual_ux_tests.gd`.

### 2. Sketch sheet vs shop — **M**

- **Change:** While `sketch_mode.active`, backdrop
  `Color(0.94, 0.95, 0.97)` (match sampled SW `#F4F5F9`) **or** a 10%
  vertical gradient `(0.90, 0.91, 0.94) → (0.96, 0.97, 0.98)`. Hide or
  freeze the world grid. Keep 3D shop dark on Exit.
- **Why:** Every SW sketch frame in this set; Fusion Photo Booth; Onshape
  light theme. Dark+white lines (`sketch_tools.png`) is the opposite of
  the trained grammar.
- **Impact:** Makes #1 honest (real black fully-defined lines).
- **Files:** `game/scripts/main.gd` `_sync_world_background`;
  `game/scripts/world_gizmos.gd`; `game/tests/lib/film_presentation.gd`
  `FLAT_BG` (films may keep charcoal — do not silently restyle
  existing posters).

### 3. Dimension witness lines + arrows — **M**

- **Change:** For each `dimensions[]` record, draw extension lines,
  a dimension line, and filled arrowheads in the sketch plane (2 px
  screen-space ribbon, same trick as `_append_leader_ribbon`). Colour:
  driving = entity colour (blue/black); driven/reference = `Color(0.55, 0.58, 0.62)`.
  Keep the Label3D; drop the heavy black outline on a light sheet.
- **Why:** `t0160.jpg`, `t0310.jpg`, `t0220.jpg`. Onshape “Black:
  dimension values, arrows, and lines.” `ui_icons.gd` `"dimension"`
  already encodes the shape.
- **Impact:** Dims become measurements, not floating HUD numbers.
- **Files:** `game/scripts/sketch_mode.gd` `_rebuild_dimension_labels`
  and a new `_rebuild_dimension_geometry`; `game/scripts/ui_icons.gd`
  (reference); tests `run_rung01_replan9_smart_dim*.gd`, sketch-tools.

### 4. Relation glyphs: green badges, not pale-blue letters — **S**

- **Change:** `COLOR_GLYPH` → `Color(0.20, 0.72, 0.38)` (SW green).
  Draw a 14×14 rounded square behind H/V/∥/⊥/= (billboard quad) so they
  match `t0310.jpg` / `t0160.jpg`. Keep coincident as ◉. Selected glyph
  can stay `COLOR_GLYPH_SELECTED` orange **or** invert to white-on-green.
- **Why:** Spoken at 05:09 (`t0309.jpg`) “little green squares.” Onshape
  uses quieter icons; SW is the education default (A20).
- **Impact:** Relations become visible and “official.”
- **Files:** `game/scripts/sketch_mode.gd` `COLOR_GLYPH`,
  `_rebuild_constraint_glyphs`; `game/tests/run_rung01_replan17_glyphs.gd`.

### 5. Edge colour and width — **S/M**

- **Change:** `EDGE_COLOR` `Color(0.12, 0.13, 0.16)` →
  `Color(0.22, 0.24, 0.28)` on dark shop, `Color(0.18, 0.19, 0.21)` on
  a light sheet. Draw a 1.5–2.0 px screen-space ribbon (reuse the glyph
  leader ribbon) instead of `PRIMITIVE_LINES`. Optional: slightly darker
  silhouette-only pass later (**L**).
- **Why:** `t0820.jpg` hairlines are dark but not crushed; Plasticity
  black edges on grey clay. `fillet_chain_pocket.png` / `ubc_wrench.png`
  edges currently look engraved.
- **Impact:** Parts look manufactured, not wireframed.
- **Files:** `game/scripts/document_view.gd` `EDGE_COLOR`, `_rebuild_edges`,
  `_edge_material`; `game/tests/run_display_tests.gd`.

### 6. Hover vs select accents — **S**

- **Change:** Face/edge **select** → Onshape yellow `Color(1.0, 0.76, 0.03)`
  (`#ffc107`). Face/edge **hover** → cooler
  `Color(0.45, 0.78, 0.95)` (Fusion-ish cyan). Body select: keep a blue
  tint or switch to a yellow outline only (Plasticity). Kill or dim AABB
  corners (`Color(0.15, 0.55, 1.0)` → alpha 0, or 4 px ticks only).
- **Why:** `t0828.jpg` green face; Onshape yellow table; Plasticity yellow
  outline. SX orange≈yellow is the muddy pair.
- **Impact:** Preselection becomes obvious.
- **Files:** `game/scripts/document_view.gd` colour consts +
  `_selection_corners`; `game/scripts/viewport_interaction.gd` box-select
  fill/edge `Color(0.35, 0.6, 0.95, …)`; `game/tests/run_select_tests.gd`,
  `run_visual_ux_tests.gd`.

### 7. SSAO (shop) + quieter key — **S**

- **Change:** On the shop `Environment`, `ssao_enabled = true`,
  radius ~0.8 m (model-mm? Godot units = m, so ~0.02–0.05), intensity
  0.6. Leave SSR on only for Scenic. Do not add glow.
- **Why:** Plasticity Render Mode AO; SW RealView contact shadow. `tutor1.png`
  pocket and `lesson2_box.png` interior are flat.
- **Impact:** Form reading without HDRI.
- **Files:** `game/scripts/main.gd` `_make_canyon_environment`,
  `apply_film_look`; `game/canyon_hdri/resources/canyon_lighting_environment.tres`.

### 8. Grid and origin planes default — **S**

- **Change:** Origin-plane quads **off** until Sketch-on-plane pick
  (`origin_planes_visible = false` by default; films already hide them).
  Grid: default **on in sketch / place**, **off** (or alpha 0.08) in
  idle part mode. `G` still toggles.
- **Why:** `t0820.jpg` has neither grid nor rainbow planes.
  `hexkey.png` is dominated by cyan/green quads.
- **Impact:** The part is the picture.
- **Files:** `game/scripts/document_view.gd` `origin_planes_visible`;
  `game/scripts/world_gizmos.gd`; `game/scripts/main.gd` File → New;
  `game/scripts/origin_planes.gd`; tests `run_display_tests.gd`,
  `run_wrench_placement_tests.gd`.

### 9. Default body albedo (non-film) — **S**

- **Change:** `BODY_COLOR` `Color(0.72, 0.74, 0.78)` →
  `Color(0.66, 0.67, 0.70)` (closer to sampled SW 150/256). Keep film
  look separate. Optional: one “Plastic / Aluminum / Steel” triad later
  (Phase 9.3).
- **Why:** `t0820.jpg` mid-grey; Onshape first-part grey-blue.
- **Impact:** Less chalk, more clay.
- **Files:** `game/scripts/document_view.gd` `BODY_COLOR`, shader default
  `vec4(0.72, …)`; `game/scripts/main.gd` `apply_film_look`.

### 10. Real ViewCube — **M/L**

- **Change:** Replace the 3×3 `ViewWidget` with a 70–90 px perspective
  cube: six faces labelled Front/Top/…, corners = iso, hover highlight
  `Color(0.35, 0.55, 0.75)` (already the active cell colour). Keep
  `OriginTriadHud` above or move triad to lower-left of the **viewport**
  (SW).
- **Why:** Onshape / Fusion / FreeCAD NaviCube. SX 3×3 does not show
  attitude (`tutor1.png` HUD).
- **Impact:** Navigation confidence.
- **Files:** `game/scripts/view_widget.gd` (rewrite `_draw`);
  `game/scripts/view_hud.gd`; `game/scripts/origin_triad_hud.gd`;
  `game/tests/run_viewcube_tests.gd`.

### 11. Background-removal + Export Image — **M**

- **Change:** View menu: Shop colour / Scenic / **Solid…** / **Transparent**.
  File → Export Image… (`*.png`) using the automation screenshot path plus
  alpha when Transparent. Hide grid, planes, HUD, selection corners,
  captions. Keep KeyLight + IBL.
- **Why:** Fusion Capture Image; Onshape Remove Background; SW PNG alpha.
  Website posters currently carry a charcoal plate.
- **Impact:** Docs, site, slides, slicer screenshots.
- **Files:** `game/scripts/main.gd` (`show_scenic_bg`, File menu ~3455,
  `_sync_world_background`); `game/scripts/automation_bridge.gd`
  `_cmd_screenshot` / `_viewport_image`; `game/tests/lib/film_chrome.gd`;
  `game/tests/lib/film_presentation.gd`.

### 12. Per-body transparency (display, not backdrop) — **M**

- **Change:** Timeline / display pane: opacity 0–1 on a body, shader
  already discards `a < 0.01` but comments **forbid ALPHA** because of
  the transparent pass / boolean-hole flicker (`document_view.gd`
  `_make_body_shader`). Needs an opaque dither or a second depth-prepass
  before true alpha.
- **Why:** `t0895.jpg`–`t0918.jpg` Display Pane transparency column.
  Onshape translucent mode + per-part slider.
- **Impact:** Inspect cuts without a section plane.
- **Files:** `game/scripts/document_view.gd` shader + materials;
  `game/scripts/timeline_panel.gd`; `game/tests/run_display_tests.gd`.
  **Do not** land this in the first batch (the comment is a real bug).

### 13. Recolour a handful of rail icons — **S**

- **Change:** Keep stroke icons; tint Sketch `#6ab0f3` (already `ACCENT`),
  Smart Dim `#f0c040`, Trim `#e07050`, Extrude `#7ec27a`, Fillet
  `#c090e0`. One accent per primary verb.
- **Why:** SW CommandManager in every frame (`t0051.jpg`, `t0085.jpg`).
  SX rail is a grey barcode (`ubc_wrench.png`).
- **Impact:** Scanability without a ribbon.
- **Files:** `game/scripts/ui_icons.gd` `GLYPHS` / `_wrap`;
  `game/tests/run_icon_tests.gd`.

### 14. Gold committed-sketch pads → SW-grey inactive sketches — **S**

- **Change:** `PROFILE_COLOR_CLOSED` `(0.98, 0.78, 0.08)` →
  `Color(0.55, 0.58, 0.62)`; pad fill alpha stay ~0.03. Open paths can
  remain cyan (`PATH_COLOR`).
- **Why:** `t0460.jpg` / `t0750.jpg` inactive sketches are thin grey, not
  yellow slabs. `sketch_tools.png` gold house fights the part.
- **Impact:** 3D reads as a solid, not a highlighter.
- **Files:** `game/scripts/sketch_pad_overlay.gd`; path overlay
  `game/scripts/path_overlay.gd`; sketch-to-3D tests.

### 15. Hidden-line / tangent-edge display options — **L**

- **Change:** Dashed occluded edges; tangent-edge visible/phantom/removed
  (Onshape Camera menu). Needs a second edge pass with depth test
  inverted or a kernel silhouette.
- **Why:** `t0460.jpg` HLR; Onshape hidden-edges modes; spoken “shaded
  with edges” at `t0813.jpg`.
- **Impact:** Drawings + dense fillets.
- **Files:** `document_view.gd` display mode enum; kernel
  `get_edge_lines` / possible silhouette API in `sxkernel`. After #5.

---

## Recommended first batch

Ship **#1, #3, #4, #5, #6, #8** together (one visual PR, films
re-shot only if captions still land). Why this cut:

- All **S/M**, no new kernel DOF, no transparent-pass rewrite.
- Restores the SW/Onshape **sketch grammar** (colour + glyphs + arrows)
  that the candlestick frames spend 11 minutes teaching.
- Makes 3D clay+edge closer to `t0820.jpg` without turning Scenic on.
- Clears planes/grid so the model is the picture (`ubc_wrench.png`
  already wants this; `hexkey.png` shows the failure).

Hold **#2** (light sketch sheet) if it collides with film goldens — it is
the right follow-up the moment #1's blue is hard to see on charcoal.
Hold **#7 SSAO** to a display-only PR with `run_display_tests.gd` pixel
pins. Hold **#10 ViewCube** and **#11 Export Image** as the second batch
(chrome + I/O, not look-dev). Hold **#12** until the opaque-hole comment
is designed.

Acceptance for the first batch, using this repo's own tools once OCCT +
Godot are present: `SX_AUTOMATION=1` screenshot of (a) an under-defined
rectangle, (b) a fully defined rectangle, (c) the default box in shaded-
with-edges, compared against `t0073.jpg` / `t0310.jpg` / `t0820.jpg`
for colour grammar — not pixel-diff, but “blue vs black vs clay+hairline”
that a SW-trained user would name correctly.

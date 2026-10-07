# Replan 15 WP2 — Contours chips highlight their region and name it (leftover 2)

You are a BUILD agent (grok-4.7, medium effort, standard speed, `starting_ref` = the full 40-character sha of `main` at launch time). This is the **only C++ WP** of replan 15. Read [`rung-01-replan-15.md`](rung-01-replan-15.md) (decisions 2, 11, 13) and [`rung-01-leftovers-sx035.md`](rung-01-leftovers-sx035.md) (item 2) first.

**Merge gate:** Merge when FINISHED and quick CI is green (linux kernel, godot-smoke, website-demos); do not wait for windows-export; macos-kernel skippable. **Do not merge your own PR**: mark it ready for review and stop; the parent merges.

Build first (`make build`), and after every C++ edit rebuild so `game/bin/libsxcore.so` carries the new binding before any Godot run. `LD_LIBRARY_PATH=/opt/occt-8.0.1/lib` before every Godot / kernel command.

| File | Hunk (search by name; line numbers are `d534765c`) |
|---|---|
| `sxkernel/include/sx/sketch.hpp` | new `struct ContourOutline` and `std::vector<ContourOutline> contour_outlines(double deflection = 0.05, std::string* err = nullptr) const;` declared right after `contour_faces` (~168) |
| `sxkernel/src/sketch.cpp` | new `Sketch::contour_outlines` after `Sketch::contour_faces` (~765, before `profile_face_selected`); new includes at the top (`BRepAdaptor_Curve.hxx`, `BRepTools_WireExplorer.hxx`, `GCPnts_QuasiUniformDeflection.hxx`) |
| `sxcore/src/sx_sketch.hpp`, `sxcore/src/sx_sketch.cpp` | new `godot::Array contour_outlines() const;` next to `contour_count` (hpp ~75, cpp ~373) and its `ClassDB::bind_method` next to `contour_count`'s (~474) |
| `sxkernel/tests/test_features.cpp` | new `TEST_CASE`s **after** `"contour_faces keeps nested wire as a hole"` (~529–540). The existing contour kernel tests live here, not in `test_sketch.cpp` |
| `game/scripts/sketch_mode.gd` | new `_contour_node`, `_contour_fill_material`, `_contour_line_material`, `_contour_tags` created in `_ready` right after the `_selected_node` block (~228–234); new `set_contour_highlight`, `contour_label`, `contour_highlight_state`, `_redraw_contour_highlight` placed next to `_redraw_selected` (~3888); **one line** in `_sync_contour_bar` (~1189) and **one line** in `_clear_meshes` (~5778) |
| `game/scripts/sketch_context_chrome.gd` | `refresh_contours` (~1262) and the `else` branch of `show_for_session` (~1337–1341) **only** |
| `game/tests/run_rung01_replan15_contours.gd` | new |

No other file. Do not touch `contour_faces`, `nest_solid_contours`, `contours_by_planar_split`, `profile_face_selected`, `contour_count`, the Extrude path that consumes `selected_contours`, or anything the replan-15 spin-outs table lists. WP6 owns `_chain_breaker_status` in `sketch_mode.gd` and WP3b (if launched) owns its own hunks: stay out of both; the hunks above are all new functions plus two one-line calls.

## The defect (sx-035 leftover 2, verbatim)

> "Contours 1 / 2 toggles have no highlight."

Two or more closed regions show a `Contours` bar of `CheckButton`s `1`, `2`, … (`refresh_contours`). Nothing in the viewport says which region a number is, so a toggle is a guess (and on the wrench the chips are numbered by area, so the big head is `1` and the slot or jaw is `2` or `3`). The user must be able to tell: hover or toggle a chip, see the region.

## Causes (read from `d534765c`; hypotheses until the gate runs)

1. `refresh_contours` builds `CheckButton`s whose only effect is `_selected_contours` (an index list). Nothing is drawn.
2. The kernel exposes `Sketch::contour_faces()` (OCCT faces) and `SxSketch.contour_count()`; there is no geometry for the regions in GDScript. A highlight needs the region outlines in sketch UV, in the **same order** as the chips (area descending, ties centroid x then y: the sort at the end of `nest_solid_contours`; `contour_faces` returns that order for the circle-only, planar-split and nested paths).
3. The sketch overlay nodes (`_draw_node`, `_preview_node`, `_selected_node`) are unshaded `ImmediateMesh` children of `SketchMode` positioned through `_to3()` (plane origin + `plane_x` / `plane_y`). A region overlay follows the same pattern.

## Design (decision 2)

### Kernel: `Sketch::contour_outlines`

```
struct ContourOutline {
	std::vector<std::array<double, 2>> outer;                  // closed loop in sketch UV, last point != first
	std::vector<std::vector<std::array<double, 2>>> holes;
	double area = 0.0;                                         // outer minus holes, mm^2
	std::array<double, 2> min{0, 0}, size{0, 0}, center{0, 0}; // bbox of `outer`, UV
};
std::vector<ContourOutline> contour_outlines(double deflection = 0.05, std::string* err = nullptr) const;
```

Implementation: `auto faces = contour_faces(err)`; for each face, for each `TopAbs_WIRE` (`TopExp_Explorer`), walk its edges **in wire order** with `BRepTools_WireExplorer`, sample each edge with `GCPnts_QuasiUniformDeflection` on a `BRepAdaptor_Curve` (a line yields its two ends; a circle yields a polyline within `deflection`; reverse the sample order when the edge orientation is `TopAbs_REVERSED`), drop a point equal to the previous one (1e-9), then project each 3D point with the sketch plane: `u = (P − origin)·x_dir`, `v = (P − origin)·y_dir` (`plane_.origin`, `plane_.x_dir`, `plane_.y_dir`; all unit). A lone full circle is one edge: sample it to ≥ 48 points (the quasi-uniform sampler does this at deflection 0.05 for any radius ≥ 1; clamp to ≥ 48 for tiny circles). The outer wire is `BRepTools::OuterWire(face)`; every other wire is a hole. `area` from `shape::area(face)` (already used by the sort). Return `{}` and the same `err` text as `contour_faces` when it fails. Output order = `contour_faces` order, so chip `i` is `contour_outlines()[i]`.

### Binding: `SxSketch.contour_outlines() -> Array`

One `Dictionary` per region: `outer` (`PackedVector2Array`), `holes` (`Array` of `PackedVector2Array`), `area` (`float`), `min`, `size`, `center` (`Vector2`). Return an empty `Array` when the kernel call fails. Bind it as `ClassDB::bind_method(D_METHOD("contour_outlines"), &SxSketch::contour_outlines)`.

### GDScript: `SketchMode`

```
const CONTOUR_COLORS := [Color(0.20, 0.65, 1.00), Color(1.00, 0.55, 0.15), Color(0.35, 0.85, 0.45), Color(0.85, 0.40, 0.90)]
const CONTOUR_FILL_ALPHA := 0.28
const CONTOUR_FOCUS_ALPHA := 0.50
const CONTOUR_OFF_COLOR := Color(0.55, 0.55, 0.55, 0.8)
var _contour_node: MeshInstance3D                  # triangles (fills) + lines (outlines), vertex colours
var _contour_tags: Node3D                          # Label3D tag for the focused region
var _contour_included: Array = []                  # chip indices that are on
var _contour_focus := -1
func set_contour_highlight(included: Array, focus: int = -1) -> void
func contour_label(index: int) -> String           # "Contour 2 of 2 — 41.0 × 10.0 mm at (93.5, 0.0)"
func contour_highlight_state() -> Dictionary       # {count, included, focus, fills:[alpha per region], outlines:int, tag:String}
func _redraw_contour_highlight() -> void
```

- `_redraw_contour_highlight()` reads `sketch.contour_outlines()` (cache it per `_contour_sig`; recompute when `_sync_contour_bar` sees a new signature). For region `i` (colour `CONTOUR_COLORS[i % 4]`): **on** → translucent fill (alpha `CONTOUR_FILL_ALPHA`, or `CONTOUR_FOCUS_ALPHA` when `i == _contour_focus`) + opaque outline in the region colour; **off** → outline only in `CONTOUR_OFF_COLOR`, no fill. A focused region always draws its outline thicker (doubled by an inward-offset second outline, or by a second pass `0.15 mm` along the plane normal; pick the simpler). Fill triangulation: `Geometry2D.triangulate_polygon` of the outer loop when there are no holes; with holes use `Geometry2D.clip_polygons(outer, hole)` and triangulate each returned non-hole polygon (a hole is `is_polygon_clockwise` after clipping; skip those). Unshaded, `TRANSPARENCY_ALPHA`, `no_depth_test` **off** (the overlay sits `0.05 mm` above the sketch plane along `plane_normal()` so it does not z-fight the grid), `vertex_color_use_as_albedo`, `render_priority` below the sketch lines so the entity lines stay on top.
- The tag: one `Label3D` at `_to3(center)` showing `str(focus + 1)`, billboard, fixed size like the dimension labels, `no_depth_test`, only for `_contour_focus ≥ 0`.
- `contour_label(i)`: `"Contour %d of %d — %.1f × %.1f mm at (%.1f, %.1f)" % [i + 1, n, size.x, size.y, center.x, center.y]` (bbox size and bbox centre, UV mm).
- `set_contour_highlight` stores the arguments and calls `_redraw_contour_highlight()`; an empty outline set (`contour_count() < 2`, or no sketch) clears the mesh and the tag.
- `_sync_contour_bar` (~1189): after the existing `chrome.refresh_contours(sketch)` add `_redraw_contour_highlight()` (the signature changed, so the regions may have changed). When `sig` is unchanged do nothing new (the early return stays).
- `_clear_meshes` (~5778): add `_contour_node.mesh = null` and clear the tag, next to `_selected_node.mesh = null`.
- The overlay is **not** a selectable entity: it must not receive picks (`MeshInstance3D` only; `SketchMode.click` hit-tests the sketch, not meshes), and must not change `_redraw`'s `has` / entity colouring or the finish-bar layout.

### GDScript: `SketchContextChrome.refresh_contours`

- Keep every existing behaviour (chip list, `_selected_contours`, tooltips, `_stack_sketch_rows`). Add to each chip (`CheckButton b`): `mouse_entered` → `sketch_mode.set_contour_highlight(_selected_contours, idx)`; `mouse_exited` and `focus_exited` → `set_contour_highlight(_selected_contours, -1)`; `focus_entered` → highlight with `idx`. In the existing `toggled` lambda, after updating `_selected_contours`, call `sketch_mode.set_contour_highlight(_selected_contours, idx)` and `sketch_mode.status.emit(sketch_mode.contour_label(idx) + (" — included" if on else " — skipped"))`.
- Guard every `sketch_mode` use with `sketch_mode != null` (the chrome is built before a session).
- After the chips are built call `sketch_mode.set_contour_highlight(_selected_contours, -1)` once so a fresh bar shows every region filled; `n <= 1` or `sketch == null` → `set_contour_highlight([], -1)` (clears).
- `show_for_session(false)` (the `else` branch ~1337–1341): after `_contour_bar.visible = false` add the clear (`set_contour_highlight([], -1)`, guarded). Switching sketches, finishing, or cancelling must leave no overlay behind.
- Status strings are exactly `Contour 1 of 2 — 41.0 × 10.0 mm at (93.5, 0.0) — skipped` / `— included` (the example numbers follow the live regions). They **do not** name a jaw or a slot.

## Reproduce-first gate

Write `run_rung01_replan15_contours.gd` and the kernel cases first; run them on the starting ref **before** any product edit and paste the output.

Expected on `d534765c`: the kernel cases do **not compile** (`contour_outlines` missing: paste the compiler error, that is the red); the Godot suite is red on `sketch.has_method("contour_outlines")`, `_contour_node` absent, and no status after a chip click; the chip-list rows (count, all on after refresh, toggle changes `_selected_contours`) are green (the net). If the Godot highlight rows already pass on `main`, stop and report: do not invent a gap.

## Kernel cases (`test_features.cpp`, tag `[sketch][contours]`)

1. `contour_outlines: disjoint rect and circle` — rect `(0,0)–(40,20)` (four lines) + circle `(80,10) r 6`. Expect 2 regions; region 0 is the rect (area 800, `size ≈ (40,20)`, `center ≈ (20,10)`, 4 outline points); region 1 is the circle (area ≈ 113.1, `size ≈ (12,12)`, `center ≈ (80,10)`, ≥ 48 points, every point within `0.06` of radius 6 from the centre). Order matches `contour_faces()` (`outline[i].area == Approx(shape::area(faces[i]))` for both).
2. `contour_outlines: nested circle is a hole` — rect `(0,0)–(40,30)` + circle `(20,15) r 5`. Expect 1 region with `holes.size() == 1`, hole points all within `0.06` of radius 5, `area ≈ 1200 − 25π`.
3. `contour_outlines: circle split by a chord` — same sketch as `"contour_faces splits a circle by a shared chord"`. Expect 2 regions, each `area ≈ 157.1`, each outline closed (first ≠ last point), `size.y ≈ 10`, `size.x ≈ 20`.
4. `contour_outlines: plane origin and orientation` — a `Sketch` on a plane with a non-zero origin and swapped axes (`SketchPlane` fields as `test_rung01_extrude.cpp` builds them): the same rect gives the **same UV** outline as on the default plane.
5. `contour_outlines: no profile` — one open line → empty vector (and `err` set or empty, same as `contour_faces`).

## Godot suite (`run_rung01_replan15_contours.gd`, real input, 1280×800)

Setup: `FilmUI.enter_sketch`, then add entities with the sketch API (`sm.sketch.add_line` / `add_circle`; setup only), `await process_frame` twice so `_redraw` runs `_sync_contour_bar`. Every pointer / key under test is a real event pushed through the viewport (chips are real controls: click = `_x11_click_screen(vp, chip.get_global_rect().get_center())`, copied from `run_rung01_replan14_trim.gd`; do **not** use `FilmUI.click_control`, it sends no real mouse event (cue animation, then `button.pressed.emit()`); hover = a real `InputEventMouseMotion` over the chip centre).

| Row | Steps | Assertions |
|---|---|---|
| A1 | rect `(0,0)–(40,20)` + circle `(80,10) r 6` | bar visible with 2 chips (both on); `sm.sketch.contour_outlines().size() == 2`; outline 0 `size ≈ (40,20)`; `contour_highlight_state().count == 2`, both `fills` > 0 |
| A2 | hover chip 2 (real motion) | `focus == 1`; `fills[1] ≈ 0.50`, `fills[0] ≈ 0.28`; `tag == "2"`; `_contour_node.mesh != null`; the tag `Label3D` is at the UV centre of region 2 (`_to3(center)` within 0.01 mm) |
| A3 | move off the chip | `focus == -1`, no tag |
| A4 | click chip 1 (real click) → off | `sm.sketch` contours unchanged; `chrome._selected_contours == [1]`; `fills[0] == 0` (no fill) and an outline still drawn for region 0; status log last item begins `Contour 1 of 2 — 40.0 × 20.0 mm at (20.0, 10.0)` and ends `— skipped` |
| A5 | click chip 1 again | on; `fills[0] > 0`; status ends `— included` |
| A6 | pixel check on the **sketch overlay mesh** (not a rendered screenshot, the headless renderer has none): `_contour_node.mesh.get_aabb()` matches the union of the outlines in `_to3` space within 0.1 mm | |
| A7 | region ordering matches chips: chip 1 is the larger region (`outline[0].area >= outline[1].area`) and `contour_label(0)` shows the larger size | |
| B1 | add a circle `(20,10) r 5` inside the rect (a hole) | bar still 2 chips; region 0 has `holes.size() == 1`; the fill triangles do not cover the hole (sum of triangle areas ≈ `800 − 25π` within 1 %) |
| B2 | delete the circle (select-and-delete through the real Select tool, or `sm.sketch.remove_entity` in setup) leaving one region | the bar hides (`n <= 1`), `contour_highlight_state().count == 0`, `_contour_node.mesh == null` |
| C1 | `Extrude` with chip 1 off still honours only chip 2 (the wiring did not change): finish the sketch with a real click on the Extrude button (`_x11_click_screen`) with Distance 10 | one new body whose bbox equals region 2's bbox (≈ `12 × 12 × 10`); `show_for_session(false)` left `_contour_node.mesh == null` |
| C2 | open the Chamfer / Sketch tools while the bar is visible | the overlay does not change `selected` / `_redraw` colouring (entity line colours identical to a run with the overlay cleared) |
| D1 | pick one region of the pliers-style sketch (circle + chord, two D regions) | each chip highlights a different half (centres differ by > 8 mm) |

Counts are what the run prints. No `select_entity`, `.text =`, `.value =`, `*.emit`, `set_extrude_distance`, `_look_along(`, `set_view(`, `.yaw =`, `.pitch =`, `.basis =` on a path under test.

## Do not

- Do not change `contour_faces`, `contour_count`, their order, or the `selected_contours` index semantics.
- Do not name regions "jaw" / "slot". Do not add a new chip layout (size, order, or captions) beyond the number; `_chip_h()` and `_stack_sketch_rows()` stay.
- Do not draw the highlight outside a sketch session or leave it behind after `finished` / `cancelled` / `show_for_session(false)`.
- Do not add per-frame work: recompute outlines only when `_contour_sig` changes.
- Do not edit `check_rung01.py`, any status string from the spin-outs table, or `run_rung01_wrench.gd` (WP7 adds the walk row `B15.contours`).

## Run before the PR

`make build`; `make test-kernel` (new cases green, nothing else changed); the new Godot suite; `python3 tools/lint_rung01_e2e.py`; `run_rung01_wrench.gd` (0 failures, 5/5, 7/7, 28/28, 7/7); `run_rung01_replan14_ctxbar.gd`, `run_rung01_replan14_trim.gd`, `run_rung01_replan14_savelabels.gd`, `run_rung01_replan12_slotarm.gd`, `run_rung01_replan13_*.gd` one at a time; `run_sketch_tests.gd`; `run_parse_sweep_tests.gd`. PR title: `Rung 1 replan 15 WP2: Contours chips highlight their region`. PR body: leftover 2 fixed; the reproduce-first run (paste); kernel test counts before / after; a screenshot of the sketch with the bar visible and chip 2 hovered **if** the soft-GL renderer produces one (do not block on it).

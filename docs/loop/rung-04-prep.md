# Rung 4 prep — hex key, Swept Boss (Pano Central)

Analysis only, against `main` `f0de099`. Video: [Solidworks Hex Key using Swept Boss](https://www.youtube.com/watch?v=8IfR-YH6Ghw) (Pano Central, 7:33). Transcript: `sx-loop/sources/subs/8IfR-YH6Ghw.txt`. No frames were opened.

**Assumption.** **7.65 mm is across flats.** An 8 mm key is an across-flats size; the narrator undersizes it for print shrink and types 7.65. In SolidWorks the polygon’s inscribed circle is tangent to the flats, so that circle’s diameter is the across-flats size. A frame could still show a vertex-to-vertex dimension (across corners = 7.65 × 2/√3 = 8.833 mm). Until then, checkers use across flats.

**195 mm** is the internet “standard length” he reads aloud. He never types it. The model uses **37**, **94**, and **Ø30**.

## 1. Demands (video order)

1. **New part, MMGS.** Millimeter, gram, second, then OK.
2. **Front plane, Sketch.** Profile sketch on the Front plane.
3. **Polygon, 6 sides, from the origin.** Inscribed circle. Width **7.65** “from this end to this end”.
4. **Vertical vertex pair.** Two points (a vertex and the origin, or the opposite vertex) made vertical, so one vertex pair stands vertical. He treats that plus the width as fully defined.
5. **Exit sketch.**
6. **Right plane, Sketch.** The Right plane is perpendicular to the profile and passes through those two vertical vertices, so no extra reference plane.
7. **Normal To.** Ctrl+8 makes the Right plane face the screen.
8. **Path lines.** From that point: a **horizontal** line **37**, then a **vertical** line **94**.
9. **Construction.** Both lines converted to construction.
10. **Tangent bend.** A perimeter circle, tangent to each line, click to place, **diameter 30**.
11. **Trim to closest.** The circle becomes the bend arc (tangent at both ends, diameter 30).
12. **Redraw the legs.** A solid line through each pair of points (outer end → arc end), twice. He says the path is then defined.
13. **Exit sketch.**
14. **Swept Boss/Base.** Features → Swept Boss/Base. Profile sketch + path sketch (he says SolidWorks sometimes selects them). OK. One solid.

UI he uses along the way: plane pick before Sketch, the Sketch button, relations (horizontal, vertical, tangent), Smart Dimension, For Construction, trim-to-closest, Normal To, and a feature command that consumes two sketches.

## 2. Gap critique

| # | Demand | Mark | What the code does |
|---|---|---|---|
| 1 | MMGS | PARTIAL | Lengths are millimetres (`sketch_mode.gd` `PICK_TOLERANCE` comment; datum offset suffix `mm` in `main.gd` `_build_datum_offset_dialog`). No unit-system command. Mass uses `density_g_cm3` (`sxkernel/tests/test_materials.cpp`). |
| 2 | Front plane + Sketch | PARTIAL | Empty click starts ground XY, normal +Z (`viewport_interaction.gd` `_commit_pick_sketch_host` → `main.gd` `_start_sketch_on_ground`). That matches the rung-3 Front=XY map. A new part has no named Front plane (`datum::plane_xy` is only constructed in tests). |
| 3 | Hexagon, 6, 7.65 AF, at the origin | PARTIAL | `sketch_mode.gd` `_polygon_ring_vertices`: AF variant forces 6 sides and the drag/typed length is the across-flats size (`Polygon AF %.4f`). Six lines only — no inscribed construction circle. No `SketchOriginAnchor` on the polygon (that call exists for centre-rect and circle). No driving 7.65 afterwards: `smart_dim_table.gd` line–line is an angle, and `solver_planegcs.cpp` `Distance` is point–point or point–line. |
| 4 | Vertical vertex pair | MISSING | AF locks `start_angle = 0` (flats horizontal), so the opposite vertices lie on X. `ConstraintType::Vertical` (`solver_planegcs.cpp`) applies to a line only. `Horizontal` does accept two points. `sketch_mode.gd` `constrain` adds vertical only when the entity is a line. |
| 5, 13 | Exit sketch | HAVE | `sketch_mode.gd` `exit_sketch`. |
| 6 | Sketch on the Right plane | MISSING | Host pick is face, yellow pad, or ground (`_commit_pick_sketch_host`). `datum::plane_yz` (normal +X, the Right plane in this axis map) is not seeded into a new document. `sketch_mode.gd` `begin_on_plane` can place a sketch on an explicit plane; its comment limits that to path legs and UI movies. Datum offset (`main.gd` `_on_datum_offset_confirmed`) creates a plane and does not start a sketch on it. |
| 7 | Ctrl+8 Normal To | PARTIAL | Entering a sketch calls `camera.enter_sketch_view` (`sketch_mode.gd` `begin`). Key 8 is Bottom (`orbit_camera.gd` `standard_view_table`). |
| 8 | Horizontal 37, vertical 94 | HAVE | Line tool, `_infer_line` (horizontal/vertical), Smart Dim `line_length` (`smart_dim_table.gd`). |
| 9 | Construction legs | HAVE | `sketch_mode.gd` `toggle_construction_selected`; `Sketch::set_construction`; X key in `viewport_interaction.gd`. Centerline draws construction directly. |
| 10 | Ø30 circle tangent to both legs | PARTIAL | `solver_planegcs.cpp` `Tangent` covers line–circle and line–arc. Smart Dim can set diameter (`_apply_diameter_dim`). Circle variant `perimeter` is a 3-point circumcircle (`_click_circle`), with no tangent-to-line picks. Arc variant `tangent` (`_click_arc`) drops a free arc and adds no tangent constraint. `fillet_selected` → `fillet_corner` builds a tangent arc of a typed **radius** between two solid lines — a different command than construction + perimeter circle. |
| 11 | Trim to closest | PARTIAL | `sketch_tools.cpp` `trim_entity` / `trim_circle` delete the picked span out to intersections. `collect_circle_intersections` skips `construction` entities. `trim_at` says the kernel trim ignores construction geometry. After step 9 the only cutters are construction lines, so the Ø30 circle has nothing to trim against. |
| 12 | Redraw the two solid legs | HAVE | Line tool plus coincident inference (`_infer_line`). |
| 14 | Swept Boss/Base | PARTIAL | `feature_ops::apply_sweep` (`ops_sweep.cpp`) builds a solid from a profile face and a path. UI is Ctrl+click pads then Sweep (`main.gd` `_sweep_profile_along_path`, `SxDocument::graph_add_sweep_along_path`), not a command that asks for profile and path. `_sketch_pad_role` marks any sketch that still contains a circle as a profile, construction or not. |

**Readiness.** A click-through of this video stops at the second plane. Lines, dimensions, construction toggle, and exit sketch are in place. The operations this rung adds — point-up across-flats hex, a sketch on the Right plane, a tangent bend trimmed off construction geometry, and a circular-spine sweep — are missing or only partly there. A scripted polyline sweep can already make a solid (`game/tests/run_sweep_loft_solid_tests.gd`); that is not this part.

**Risks, largest first.**

- **Sweep spine.** `sketch_ordered_polyline` (`features.cpp`) turns an arc into chords (`samples = max(8, ceil(span / (π/12)))` → 8 on a quarter circle). `sweep_along_polyline` wires those chords (`make_polyline_wire`) and sets `BRepBuilderAPI_RightCorner`. The bend is faceted (sagitta about 0.072 mm on R15). There is no circular edge in the path feature.
- **Profile–path pierce.** Nothing requires the path to hit the profile. `MakePipeShell::Add(..., withContact=false, withCorrection=true)` carries the section onto the spine. `pierce_edge` (`sketch3d.cpp`) is a body-edge ∩ sketch-plane hit for Convert, not a sweep relation. A path that misses the hex still sweeps.
- **Same-plane path.** With only ground XY, both sketches lie in one plane. The comment on `sweep_along_polyline` records that a spine tangent lying in the profile plane is the case that used to produce an empty pipe.
- **Tangent arc.** The narrated bend needs a circle tangent to two construction lines and a trim that sees those lines. Trim skips construction. The fillet tool can make an R15 arc only while the legs are still solid profile lines.
- **Right plane.** No origin plane to click, so the path cannot be drawn through the hex’s vertical diameter.
- **Polygon orientation.** AF is flats-horizontal and unlocked (no origin coincident, no driving width, no point–point vertical). The Right plane “already through the two vertices” depends on the point-up pose.

## 3. Checker numbers

Frame, same axis map as rung 3: Front = XY (normal +Z), Right = YZ (normal +X). Point-up hex, across flats 7.65 along X, centre at the origin. Spine through the **centroid** (the origin lies on the Right plane). Construction legs meet at a corner: horizontal 37 along +Z, vertical 94 along +Y. Ø30 circle in the elbow, so the tangent points sit **15 mm** back from the corner. Solid legs are 22 and 79; the bend is a quarter circle R15.

\[
R = \frac{7.65}{\sqrt{3}} = 4.416730\ \text{mm}
\]

\[
A = \frac{\sqrt{3}}{2}\,(7.65)^2 = 50.681972\ \text{mm}^2
\]

\[
L = (37-15) + (94-15) + 15\cdot\frac{\pi}{2} = 124.561945\ \text{mm}
\]

\[
V = A \cdot L = 6313.045\ \text{mm}^3
\]

Volume equals area times centreline length because the centroid rides the spine and the section does not cross the bend centre (inner radius \(15 - R = 10.583\) mm).

| | min | max | size |
|---|---:|---:|---:|
| X | −3.825 | 3.825 | 7.650 |
| Y | −4.416730 | 94 | 98.416730 |
| Z | 0 | 41.416730 | 41.416730 |

X is the across-flats width and does not rotate (the bend is in YZ). Y runs from the bottom vertex on the short arm to the end face. Z runs from the start face to the outer vertex on the long arm (\(37 + R\)).

Spine stations: `(0,0,0)` → `(0,0,22)` → quarter circle, centre `(0,15,22)`, to `(0,15,37)` → `(0,94,37)`.

Inside, for a solid check: `(0, 0, 5)` short arm; `(0, 4.393, 32.607)` arc at 45°; `(0, 50, 37)` long arm. Outside: `(3.9, 0, 5)`, `(0, −4.5, 5)`, `(0, 50, 42)`, `(0, 95, 37)`.

**If a frame shows the path starting on the top vertex** instead of the centre, the centroid rides outside the spine on the arc (radius \(15+R\)) and \(V = 6664.665\ \text{mm}^3\). Bottom-vertex start gives \(V = 5961.424\ \text{mm}^3\). Those two are discriminants, not the target. The target above is the centred key.

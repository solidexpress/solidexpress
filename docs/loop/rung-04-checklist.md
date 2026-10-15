# Rung 4 checklist — hex key, Swept Boss

Row list for `tools/walk_rung04.py`. How to build each row: [`rung-04-plan.md`](rung-04-plan.md). Numbers come from `check_rung04.py params` after WP1 (`AF 7.65`, volume `6313.045`, bbox `7.650 × 98.417 × 41.417`).

**A** action (the video step, named tool). **L** look. **N** negative. Clauses are bridge reads or one checker line. Statuses are `[status-trace]` result lines since the row's mark.

Centred spine only. Volume `6664.665` (path on the top vertex) and `5961.424` (bottom vertex) are checker mutations, not walk rows.

## Chunk 1 — hex on Front (10)

| Row | Does | Clauses |
|---|---|---|
| N1 | Window first: size ≥ 1272 × 750 or maximized; status bar, File menu, and the rail inside the window | `window`; `chrome inside` |
| A1 | File → New. Status is the pinned sentence (`New — empty part, Top plane (XY)…`). `state.units` is `mmgs`. No second dialog. | `new`; `units mmgs`; `no dialog` |
| A2 | Click datum Front (not empty ground), Sketch. Session is the ground-sketch path. Origin `(0,0,0)`, normal `+Z`, `x = +X`, `y = +Y`. | `datum Front`; `sketch`; `ground status`; `normal`; `basis` |
| L1 | Rail labels Polygon, Line, Circle, Smart Dim, Trim visible, none clipped. Plane names Front, Top, Right visible. | `rail labels`; `plane names`; `not clipped` |
| A3 | `rail:Polygon`, variant `across_flats`. Centre `(0,0)`, place the hex. Six profile lines. Centre on the origin. One construction circle, radius half the current AF, not in the profile loop. Flats still horizontal (vertices on ±X). | `six lines`; `centre origin`; `inscribed circle`; `circle construction`; `flats horizontal` |
| A4 | Smart Dim the two opposite flats, type `7.65`. Label `7.65`. One driving distance. Flat-to-flat is 7.65 along Y (pose is still flats-horizontal; A5 turns that into the X width). | `label 7.65`; `driving distance`; `af 7.65` |
| N2 | Smart Dim `0`: refused, size unchanged. `-5` refused. Esc clears the editor. | `zero refused`; `negative refused`; `unchanged`; `esc` |
| A5 | Vertical on the two vertices that lie on X (the pair through the origin). Status names Vertical. Those vertices share `x = 0` and sit at `y = ±R`. AF still 7.65, now along X. DOF chip `0`. | `vertical`; `point up`; `af along x`; `dof 0` |
| L2 | The point-up hex is on screen: a vertex above the origin, vertical flats left and right, the `7.65` label readable and not on the origin. Construction circle drawn as reference. | `vertex up`; `label visible`; `circle reference` |
| A6 | Exit Sketch. One sketch, no body. That sketch's role is profile. Save `hex.sxp`. | `exit`; `one sketch`; `no body`; `role profile`; `saved` |

## Chunk 2 — path on Right (12)

| Row | Does | Clauses |
|---|---|---|
| A7 | Click datum Right, Sketch. UV `(37, 0)` is world `(0, 0, 37)`. UV `(0, 94)` is world `(0, 94, 0)`. | `datum Right`; `sketch`; `u is +Z`; `v is +Y` |
| A8 | Ctrl+8. Camera looks along the sketch normal, up = plane Y. This row does not press key 8 alone. | `normal to`; `up is +Y`; `not bottom` |
| L3 | The Right sketch fills the chrome-free canvas. The origin is on screen. A screen-horizontal rubber band grows world Z, not world Y. | `framed`; `origin on screen`; `screen horizontal +Z` |
| A9 | Line, horizontal, length 37: world `(0,0,0)` → `(0,0,37)`. Line, vertical, length 94: `(0,0,37)` → `(0,94,37)`. They meet at the corner. | `line 37`; `line 94`; `corner`; `labels` |
| A10 | Both lines set to construction. They are not profile edges. | `both construction`; `not profile` |
| L4 | Both legs draw as construction (dashed or the construction flag). Labels `37` and `94` visible, not piled on the corner. | `construction style`; `labels visible`; `no overlap` |
| A11 | Circle, variant `perimeter`. Pick the two construction lines, click the elbow (the side of centre `(0, 15, 22)`). Smart Dim `Ø30`. Two tangent constraints. Centre within 0.2 of `(0, 15, 22)`. Lines still construction. | `tangent pair`; `diameter 30`; `centre`; `lines remain` |
| N3 | Diameter `0`: refused, circle unchanged. A perimeter click in empty space with no line under it: refused, no extra entity. Esc disarms. | `zero refused`; `empty refused`; `unchanged`; `esc` |
| A12 | Trim the outer part of the circle (the side away from the corner). One arc, radius 15, span 90° ± 1°, endpoints `(0,0,22)` and `(0,15,37)`. No circle left. Both construction lines remain. | `one arc`; `radius 15`; `quarter`; `endpoints`; `lines remain` |
| L5 | The bend draws as one arc, not a polyline of chords. It is solid, not construction. End labels do not cover the arc. | `arc style`; `not construction`; `labels clear` |
| A13 | Solid line `(0,0,0)` → `(0,0,22)`. Solid line `(0,15,37)` → `(0,94,37)`. Lengths 22 and 79. Coincident at the arc ends. | `leg 22`; `leg 79`; `coincident`; `solid` |
| A14 | Exit Sketch. Path sketch role is rail. The hex sketch is still the profile. No body. Save `path.sxp`. | `exit`; `role rail`; `hex remains`; `no body`; `saved` |

## Chunk 3 — sweep (10)

| Row | Does | Clauses |
|---|---|---|
| N4 | `sweep:Boss` with only the profile sketch picked, OK: refused, no body, timeline unchanged. | `refused`; `no body`; `timeline unchanged` |
| A15 | `sweep:Boss`, pick the hex as profile, pick the path, `sweep:Ok`. Not Ctrl+click. Status is the sweep sentence. One body. | `profile`; `path`; `status`; `one body` |
| A16 | Export `final.3mf`. `check_rung04.py final`: `bbox` PASS. Min `(−3.825, −4.416730, 0)`, size `7.650 × 98.417 × 41.417`, each edge within 0.2. | `exported`; `bbox` |
| A17 | Same file: `volume` PASS, `6313.045` within 0.5 %. | `volume` |
| A18 | Same file: `inside` PASS at `(0, 0, 5)`, `(0, 4.393, 32.607)`, `(0, 50, 37)`. | `inside short`; `inside arc`; `inside long` |
| A19 | Same file: `outside` PASS at `(3.9, 0, 5)`, `(0, −4.5, 5)`, `(0, 50, 42)`, `(0, 95, 37)`, and `watertight` PASS (one closed solid). | `outside`; `watertight` |
| L6 | Timeline: two sketches then the sweep, names distinct, none truncated. One body. | `order`; `names distinct`; `one body` |
| A20 | Save As `final.sxp`. File exists. Title shows `final`. | `saved`; `file exists`; `title` |
| N5 | File → New, File → Open `final.sxp`. One body, no status error. Re-export: `bbox` and `volume` PASS again. | `reopened`; `one body`; `no error`; `bbox`; `volume` |
| A21 | Headless evidence, needs `--a15` (without it: `BLOCKED-by-flag`). Kernel, godot suites `0 failed`, lint, `test_check_rung04.py`, registry. Engine noise only as rung 1 R9 allows. | `kernel`; `godot`; `lint`; `unit`; `registry`; `errors` |

Total: 10 + 12 + 10 = **32** (21 A, 6 L, 5 N).

Pass bar: `PASS 32`, no `FAIL`, `PARTIAL`, `BLOCKED`, or `runner-gap`. Every `check-*.txt` has no `FAIL`. The walk's `[ERROR]` list is empty apart from rung 1 R9 engine noise and the refusals in N2, N3, and N4.

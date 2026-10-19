# Combination spanner: ellipse, 12-point, mid-plane, mirrored recess

Goal: build the Mahtabalam combination spanner (How to Sketch Combination Spanner in Solidworks, RZB8m9li098) with clicks only — a Front C from a 17° construction and 3-click ellipse, Parallel jaw offsets, Mirror Entities, Power Trim, two AF-25 hexes trimmed to a 12-point box end, Mid Plane 10 / 6 extrudes, R30/R20 neck fillets, Convert + Offset 5 Cut Blind 1, R3, Feature Mirror about Front, R1.

## Steps

1. **Front** view. Click **Sketch**, pick the Front origin plane.
2. **Line**, variant **Centerline**, through the origin along +X. **Ellipse** three clicks: centre at the origin, major **55** steep along 17°, minor **50** along 17°.
3. **Centerline** at **17°**. **Smart Dimension** the angle **17**.
4. **Line** the upper jaw (offset **12.50**, length **20**). Select the 17° axis and the jaw, chip **Parallel**. Coincident the outer tip to the ellipse. Dimension major **55**, minor **50**, offset **12.5**, length **20**.
5. **Mirror Entities** the jaw across the 17° axis. **Arc**, variant **Three Point**, **R15** between the inner ends.
6. **Trim** the ellipse on the −X opening so a C remains. Coincident each jaw tip onto the remaining C.
7. **Circle** Ø**33** at **240**. **Polygon**, variant **Across Flats**, AF **25**. Second polygon, variant **Vertex**, rotated 30°. **Trim** the inner leftover sides for a 12-point.
8. **Centerline** origin → Ø33, dimension **240**. **Line** the upper handle at y = **10**, chip **Horizontal**, dimension **10**. **Mirror** across the CL. Coincident the handle ends to the C and the Ø33. **Trim** the overflows.
9. **Exit Sketch**. Timeline pencil. Contour chips: C + ring. Finish bar **New**, **Mid Plane**, **10**, **Extrude**. Pencil again. Contour chip: handle. **Fuse**, **Mid Plane**, **6**.
10. **Iso** / **Top**. **Fillet** **R30** on the 6 mm neck Z-edges at the open end, **R20** at the box end. Zoom so those edges are vertical (Top), not covered by the C.
11. **Top**. Click the handle top face, **Sketch**. **Convert** the outline. **Offset** **5**, Reverse inward. Finish bar **Cut**, **Blind**, **1**.
12. **Fillet** **R3** on the recess ends. **Feature Mirror**, origin **Front**, Shift+click the R3 fillet and the cut, **OK**. **Fillet** **R1** remaining.

Film: spanner.

## Pending publish

The website card stays off the live Release list until `spanner.webm` is on `demo-movies`. Do not add the id to `published-demos.json` or `demo-catalog.json` before that. After the webm and vtt are rendered outside the tree:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber spanner.webm spanner.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies spanner
```

Then a person who can upload decides whether to feature it (swap, not grow past 12). `website/features.html` renders `demo-catalog.json` ∩ the live Release list; it needs no markup change.

# Combination spanner: ellipse, 12-point, mid-plane, mirrored recess

Goal: build the How to Sketch Combination Spanner in Solidworks part with clicks only — a Front 17° construction, 3-click ellipse 55 steep × 50 along 17°, Parallel jaw offsets, Mirror Entities, 3-point R15, Power Trim C opening, Ø33 with two AF-25 hexes Power Trim 12-point, handle half-width 10, Mid Plane 10 heads then Mid Plane 6 handle fuse, R30 / R20 neck fillets, Convert + Offset 5 Cut Blind 1, R3, Feature Mirror about Front, R1 remaining.

## Steps

1. **Front** view. Click **Sketch**, pick the Front origin plane.
2. **Ellipse**: origin, major 55/2 steep along 17°, minor 50/2 along 17°.
3. **Line**, variant **Centerline**: through the origin along +X, then the 17° axis. **Smart Dimension** the angle **17**.
4. **Line** the upper jaw (offset 12.50, length 20). **Select** the 17° axis and the jaw. **Parallel**. Coincident the outer tip to the ellipse.
5. **Select** the axis and the jaw. **Mirror**. Confirm in empty space.
6. **Arc**, variant **Three Point**, through the inner jaw ends and the R15 throat. **Smart Dimension** **15**.
7. **Trim** the ellipse opening on −X so the C remains.
8. **Circle** Ø**33** at 240 on the axis. **Polygon**, variant **Across Flats**, AF **25**. Second hex, variant **Vertex**, rotated 30°. **Trim** the inner leftovers into a 12-point.
9. **Line** the handle at y = **10**. **Horizontal**. **Mirror** about the axis. **Trim** the overflows at the C and the ring.
10. Finish bar: contours C + ring, **New**, **Midplane**, distance **10**. Click **Extrude**.
11. Timeline pencil the sketch. Contour the handle. **Fuse**, **Midplane**, distance **6**. Click **Extrude**.
12. Select the body. **Fillet** **30** on the open-end neck Z-edges. **Fillet** **20** on the box-end neck.
13. **Top**. Click the handle top. **Sketch**. **Convert** the outline. **Offset** **5**, **Reverse**, **Apply**. Finish bar: **Cut**, **Blind**, distance **1**. Click **Extrude**.
14. **Fillet** **3** on the recess ends. **Features**. Click origin **Front**. Shift+click the last fillet and cut. **OK**.
15. **Fillet** **1** remaining.

Film: spanner.

## Pending publish

The website card stays off the live Release list until `spanner.webm` is on `demo-movies`. Do not add the id to `published-demos.json` or `demo-catalog.json` before that. After the webm and vtt are rendered outside the tree:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber spanner.webm spanner.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies spanner
```

Then a person who can upload decides whether to feature it (swap, not grow past 12). `website/features.html` renders `demo-catalog.json` ∩ the live Release list; it needs no markup change.

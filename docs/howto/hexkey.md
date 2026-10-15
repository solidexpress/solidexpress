# Hex key: Swept Boss

Goal: build the Pano Central hex key with clicks only — a 7.65 mm across-flats hex on the origin (point-up), a Right-plane path (37, 94, Ø30 elbow, solid legs), then Swept Boss.

## Steps

1. Click **Sketch** and pick empty ground (Front / XY).
2. **Polygon**, variant **Across Flats**. Click the origin. Type **7.65** Enter.
3. **Smart Dimension** the opposite flats, type **7.65** Enter.
4. **Select** the ±X vertices. **Vertical**. **Exit Sketch**.
5. **Right** view. Click the Right origin plane, **Sketch**.
6. **Line** (0, 0) → (37, 0), then (37, 0) → (37, 94). Toggle both **Construction**.
7. **Circle**, variant **Perimeter**: the two lines, then the elbow side. **Smart Dimension** Ø**30**.
8. **Trim** the outer arc. Draw the two solid legs (22 and 79). **Exit Sketch**.
9. **Swept Boss**. Pick the hex pad, pick the path pad, **OK**.

Film: hexkey.

## Pending publish

The website card stays off the live Release list until `hexkey.webm` is on `demo-movies`. After the webm and vtt are rendered outside the tree:

```
gh release upload demo-movies -R solidexpress/solidexpress.github.io --clobber hexkey.webm hexkey.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature hexkey
```

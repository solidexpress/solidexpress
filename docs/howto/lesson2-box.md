# Lesson 2 box: sketch, fillet, shell, side hole, resize

Goal: build the Student Guide box with clicks only — a 100 × 65 rectangle edited to 60, extruded 50, one R10 fillet, a 5 mm shell with the top open, a Ø10 hole from the right-hand face, then the width back to 65 so the fillet, shell, and hole follow.

## Steps

1. Click **Sketch** and pick empty ground (Top).
2. **Rect**: click the origin, then the opposite corner at 100 × 65.
3. **Smart Dimension** the top line, type **100** Enter. **Smart Dimension** the right edge, type **65** Enter.
4. **Select** the **65** label. Type **60** Enter.
5. Distance **50**. Click **Extrude**.
6. Select the body. **Fillet**, type **10** Enter. Isometric: click the two vertical corners on the near side. **Right**: click the far corner on the right face. **Left**: click the far corner on the left face. Enter.
7. Click the top face. **Shell**, thickness **5**, **Apply**.
8. Click the right-hand face. **Right** view. **Sketch** on the selection strip.
9. **Circle** at 25 from the left edge of that face and 40 up, rim for Ø10. **Convert** the left edge of the face, then the bottom edge. **Smart Dimension** the circle **10**, the centre to the left edge **25**, the centre to the bottom edge **40**.
10. Finish bar: **Cut**, **Through All**. Click **Extrude**.
11. **View → Timeline**. Pencil on the first sketch. Edit **60** to **65** Enter. **Exit Sketch**. The fillet, shell, and hole regenerate.

Film: `lesson2_box`.

## Pending publish

The website card stays off until `lesson2_box.webm` is on Release `demo-movies`. Do not add the id to `published-demos.json` or `demo-catalog.json` before that. After the webm and vtt are rendered outside the tree:

```
gh release upload demo-movies -R solidexpress/solidexpress.github.io --clobber lesson2_box.webm lesson2_box.vtt
SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature lesson2_box
```

Then one follow-up commit of the two JSON files. `website/features.html` reads the catalog ∩ the live Release list; it needs no markup change.

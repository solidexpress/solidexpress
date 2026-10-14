# Tutor1: boss, offset cut, fillets, shell, section

Goal: build the Lesson 1 part with clicks only — a 120 × 120 rectangle from the centre, extruded 30, a Ø70 boss 25 tall, a 5 mm inward offset cut through, R5 on the corners and the front face, R1.5 on the hole rims, a 1 mm shell open at the back, then a Top section turned off.

## Steps

1. Click **Sketch** and pick empty ground (Top).
2. **Rect**, variant **Center**. Click the origin, then the corner at 60 × 60.
3. **Smart Dimension** the top line, type **120** Enter. **Smart Dimension** the right edge, type **120** Enter.
4. Finish bar: **New**, **Blind**, distance **30**. Click **Extrude**.
5. **Top** view. Click the front face (z = 30). **Sketch** on the selection strip.
6. **Circle** at the centre, rim 35 out (Ø70). Finish bar: **Fuse**, **Blind**, distance **25**. Click **Extrude**.
7. **Top** view. Click the boss top (z = 55). **Sketch** on the selection strip.
8. **Offset**, distance **5**, **Reverse**, click the rim, **Apply**. Finish bar: **Cut**, **Through All**. Click **Extrude**.
9. Select the body. **Fillet**, type **5** Enter. **Right**: click the two vertical corners on that side. **Left**: click the two vertical corners on that side. **Top**: Shift+click the front face. Enter.
10. **Fillet**, type **1.5** Enter. **Top**: click the boss top so both hole rims are picked. Enter.
11. **Bottom** view. Click the back face. **Shell**, thickness **1**, **Apply**.
12. **Section**, choose **Top**. Click **Section** again to turn it off.

Film: tutor1.

## Pending publish

The website card stays off until `tutor1.webm` is on Release `demo-movies`. Do not add the id to `published-demos.json` or `demo-catalog.json` before that. After the webm and vtt are rendered outside the tree:

```
gh release upload demo-movies -R solidexpress/solidexpress.github.io --clobber tutor1.webm tutor1.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature tutor1
```

Then one follow-up commit of the two JSON files. `website/features.html` reads the catalog ∩ the live Release list; it needs no markup change.

# Candlestick: revolve, sweep, drafted cut

Goal: build the SolidWorks Tutorials Revolve & Sweep candlestick with clicks only — a Front profile revolved 360, a Front path (60, R150, R20 hook) sitting 10 mm above the base, a 35×10 Right ellipse coincident to the path start, Swept Boss fused onto the revolve, then a Ø30 Blind 25 cut with 15° inward draft. No fillet.

## Steps

1. **Front** view. Click **Sketch**, pick the Front origin plane.
2. **Line** the axis (0, 0) → (0, **220**), the top **20**, and the base toward **90**.
3. **Arc**, variant **Tangent**, from the top-horizontal end down to the stem. **Smart Dimension** **R10**.
4. **Line** the upper stem. **Arc**, variant **Three Point**, **R20** through the outer bulge. **Line** the lower stem.
5. **Arc** **R60** down, then the connecting **R12.50** rim clipped on y = 0. Close to the origin.
6. **Select** the 220 mm axis. Finish bar **Revolve** Blind 360°.
7. **Front** again. **View ▸ Temporary Axes**. **Line** **60** along +X at y = **10**. **Tangent Arc** **R150** up, then the **R20** hook (not a line). **Smart Dimension** the path **10** above the base silhouette. **Exit Sketch**.
8. **Right** view. Click the Right origin plane, **Sketch**. **Ellipse** centre / major / minor: **35×10**, major horizontal. Centre coincident to the path start. **Exit Sketch**.
9. **Swept Boss**. Pick the ellipse, pick the path, **OK** (fuse onto the revolve).
10. **Top**. Click the Ø40 disc on the revolve. **Sketch**. **Circle** Ø**30**. Finish bar: **Cut**, **Blind**, distance **25**, **Draft** On, **15°**. Click **Extrude**.

Film: candlestick.

## Pending publish

The website card stays off the live Release list until `candlestick.webm` is on `demo-movies`. Do not add the id to `published-demos.json` or `demo-catalog.json` before that. After the webm and vtt are rendered outside the tree:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber candlestick.webm candlestick.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies candlestick
```

Then a person who can upload decides whether to put it on the homepage (`website.home`); every `website` film is on the features page. `website/features.html` renders `demo-catalog.json` ∩ the live Release list; it needs no markup change.

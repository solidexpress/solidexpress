# Flanged pipe: shell, pattern, mirror, fillet

Goal: build the UBC ELEC391 Exercise 3 flanged pipe with clicks only — a Ø150 Front circle extruded 250, Shell 10 on both planar ends, a Ø225 flange fused 10, a Ø130 bore plus eight Ø10 holes on a 94 mm pitch cut 10, Feature Mirror of those four features about z = 0, re-shell the mirrored half 10, Fillet R5 on both flange outer faces.

## Steps

1. **Front** view. Click **Sketch**, pick the Front origin plane.
2. **Circle** at the origin, rim at 75 (Ø**150**). **Smart Dimension** the diameter, type **150** Enter.
3. Finish bar: **New**, **Blind**, distance **250**. Click **Extrude**.
4. Iso. Click the body. **Top**: click the +Z end. **Bottom**: Shift+click the z = 0 end. **Shell**, thickness **10**, **Apply**.
5. **Top** view. Click the +Z face (z = 250). **Sketch**. **Circle** Ø**225**. Finish bar: **Fuse**, **Blind**, distance **10**. Click **Extrude**.
6. Click the flange outer face (z = 260). **Sketch**. **Circle** Ø**130** at the origin. **Circle** Ø**10** at (0, 94). **Smart Dimension** Ø10 and distance **94**. **Select** both centres, **Vertical**.
7. **Select** the Ø10 seed. **Pattern**, variant **Circular**, Count **8**, Angle **360**, **Apply**. Finish bar: **Cut**, **Blind**, distance **10**. Click **Extrude**.
8. **View ▸ Timeline**. **Features**. Click the z = 0 plane. Click the first extrude row, Shift+click Shell, flange, and cut. **OK**.
9. **Bottom** view. Click the z = −260 face. **Shell**, thickness **10**, **Apply**.
10. Select the body. **Fillet**, type **5** Enter. **Top**: click the +Z flange face. **Bottom**: Shift+click the −Z flange face. Enter.

Film: flanged_pipe.

## Pending publish

The website card stays off the live Release list until `flanged_pipe.webm` is on `demo-movies`. Do not add the id to `published-demos.json` or `demo-catalog.json` before that. After the webm and vtt are rendered outside the tree:

```
gh release upload demo-movies -R solidexpress/solidexpress --clobber flanged_pipe.webm flanged_pipe.vtt
SX_MOVIES_OUT=/tmp/sx-movies SX_SKIP_UPLOAD=1 scripts/sx-publish-demo-movies --feature flanged_pipe
```

Then one follow-up commit of the two JSON files (and the `website` object + `EXPECTED_COUNT`) by a person who can upload. `website/features.html` renders `demo-catalog.json` ∩ the live Release list; it needs no markup change.

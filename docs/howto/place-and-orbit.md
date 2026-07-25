# Place a box and orbit the camera

Goal: drop one solid that sits on the ground plane, keep it selected, and orbit — including on a touchpad with no middle button.

## Steps

1. The empty scene starts zoomed in on a **0.1 mm** ground grid (1 mm majors). In the left **Primitives** palette, click **Box** (do not drag). The status bar says *Click ground or a face to place box*. A translucent ghost appears with its **floor** on the active plane (ground by default). A bottom bar shows editable **X/Y/Z** (place point) and **W×H×D** size. The compact **Snap** dock at the top of the screen (default on, 0.1 mm) stays visible at all times.
2. Move the pointer — the ghost tracks on the active plane (screen ray mapped to that plane’s XY; solid sits on your side of the plane). Optionally type a precise size in the bottom bar before placing. Click the plane (or a face). The solid appears under the ghost.
3. The new box stays **selected** (highlighted with a blue AABB / corner brackets). The left rail swaps: **Primitives** hides and **Modify** tools take that space. Position and size stay editable in the bottom HUD.
4. Orbit with any of:
   - **Two-finger drag** on a trackpad (pan gesture) — hold a left-click while two-finger dragging for a stronger turn; over a scrollbar panel, two-finger scroll moves the panel instead
   - **Shift + two-finger** or **3-finger grip** (middle-click drag on clickfinger trackpads) — pan the view (SX/Fusion default)
   - **Empty-space drag** (left-drag where nothing is picked)
   - **Right-drag** (right-**click** alone opens the context menu)
   - **Alt + left-drag** — orbit on SX/SW (handy on a touchpad); Fusion matches middle (pans)
   - **Middle-drag** on a mouse — SX/Fusion: pan; SolidWorks-style middle-orbit exists as a nav preset in code
   - **Shift** held with middle → orbit under SX/Fusion (or pan under SW); **Alt+Shift** pans under SX/SW
   - **Double-middle** → fit selection (or all)
   - **Wheel** or **pinch** → zoom toward the cursor (same UI rule as two-finger scroll)
   - **Shift+wheel** → pan vertically; **Alt+wheel** → yaw; **Shift+Alt+wheel** → pan horizontally; **Ctrl+wheel** → stronger zoom
   - **Touch**: one-finger drag orbits (mouse emulation); two-finger drag pans and pinch-zooms
   - **Arrow keys** → pan; **Shift+arrows** → orbit; **WASD** → fly in/out + strafe; **Alt+WASD** → screen pan (while sketching, plain WASD stays with tools)
   - **+ / − / Page Up / Page Down** → zoom at view center; **Home** same as **F**
   - **Ctrl + empty-drag** → rubber-band box select
   - **Shift + click** → add / toggle multi-select (Shift+empty keeps selection)
   - **Empty click** → clear selection
   - **F** frames the **selection** (or all if none); **Shift+F** always frames all; **Space** opens the orientation panel; **1 / 2 / 3 / 7** jump to front / right / top / isometric; **5** toggles ortho
5. Drag on the solid to **move** it on the active plane (old/new centers + editable Δ). Grab the yellow **lift** grip (inset elevator along the plane normal) to leave / approach the plane. Tap **X**/**Y**/**Z** mid-drag to lock that axis. Blue **stretch arrows** (single outward chevron) on each face or a **rotate arc** reshape / rotate — Enter refines the focused Δ / Δ°.
   - Set the active plane with **View → Set Active Plane…** (then click a flat face), or select a face and use **Active plane** on the strip / **Set as active plane** on RMB. The white grid follows that plane; empty ground during pick mode resets both to world XY.
6. To cancel a place before committing, press **Esc** (or right-click without dragging). Click empty space to deselect and bring **Primitives** back.

## What “good” looks like

- The ghost tracks the pointer after you arm place (not stuck at screen center).
- The top **Snap** dock is always visible; position/size HUD shows while place is armed.
- The box sits on the ground (`z = 0` floor, top at 5 for the default 5 mm cube).
- After the place click, the box remains selected with clear corner brackets; left chrome shows Modify tools, not Primitives.
- Empty-space drag and Alt-drag orbit even when side panels are open.
- Scrolling a dock with a scrollbar does not zoom the 3D view.

Verified by `run_howto_tests.gd` / `howto_place_and_orbit`.

Next: reshape and move with on-canvas handles — [direct-edit.md](direct-edit.md).

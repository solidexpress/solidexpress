# Parametric wrench: blank to 3MF

Goal: build the UBC rung-1 wrench with clicks only — two circles, shaft lines, extrude, open jaw, grip slot, fillets, thickness 14, export 3MF.

## Steps

1. Click **Sketch** on the palette and pick empty ground (Top / XY).
2. **Circle** at the origin, type **10** Enter (Ø20 pivot). **Circle** again on the right, type **22.5** Enter (Ø45 head).
3. **Smart Dimension** the two centres, type **200** Enter.
4. **Select** both circle edges. Click the **Shaft Lines** chip.
5. Set Extrude distance **10**. Click **Extrude**.
6. Click the top face, then **Sketch**. **Jaw**: centre on the head, along the axis, then half-width. Edit the width label to **20** and the angle to **45°**. Draw the Ø45 and Ø10 circles if they are not already on the face. **Line** → **Centerline** across the jaw, then a leftover offset centreline. **Trim** on the shaft side of the cutter (`Trimmed open jaw`).
7. Finish bar: **Cut**, **Up To Surface**, **Opposite face**. Click **Extrude**.
8. Sketch on the top face. **Slot**, type radius **5**, first centre on the shaft, type c-c **150**. **Cut**, **Blind**, distance **2.5**. **Extrude**.
9. Select the body. **Fillet** R10 on both neck edges (Front / Back). **Fillet** R1 on the top face, bottom face, and slot floor.
10. **View → Timeline**. Double-click the base extrude. Type **14** Enter. Click empty viewport to keep 14. The jaw and slot stay through.
11. **File → Export 3MF…**. Save the mesh.

See also: [print-a-wrench.md](print-a-wrench.md) (Box + Hole Wizard route, not this film).

Film: `ubc_wrench`.

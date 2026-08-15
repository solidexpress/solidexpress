# How to print a parametric wrench (UBC-style)

Click path only — no private APIs.

1. Start a new document.
2. Insert a base block: use the left palette “Box”, then resize with the HUD to rough jaw dimensions.
3. Sketch the wrench profile on the top face:
   - Click the face, then “Sketch”.
   - Draw the handle/profile with rectangles/lines.
   - Finish on the sketch chrome.
4. Extrude Cut defaults to Through All:
   - On the sketch chrome, set Result to “Cut”.
   - End defaults to “Through All” so jaw/through cuts survive thickness edits.
   - Click “Extrude”.
5. Add holes with Hole Wizard from context chrome:
   - Select the jaw face.
   - On the Selection strip, click “Hole Wizard…”.
   - Click multiple points; press “Apply holes”.
6. Add external thread for the screw:
   - Select the screw body (or cylinder blank).
   - Insert → Thread… (also in Ops on the right).
   - Threads are modeled by default when appropriate.
7. Orient for print (optional): View → Set Active Plane…; use the Ops shell/draft as needed.
8. Export for printing: File → Export 3MF.

Notes:
- “Through All” avoids Blind 10 mm cuts that fail when thickness changes.
- Hex dimensions are across-flats by design intent; use polygon where available. If AF as a first-class label requires kernel changes, it is intentionally deferred here.


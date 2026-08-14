# Drop a bolt and it fastens

Goal: dragging a component over a connector and letting go creates the mate. No dialog, no two-click flow for the common case.

## Steps

1. Place a plate, and a bolt beside it.
2. Select the bolt → **Place instance of selection**.
3. Drag the instance over a face of the plate. The connector frame under the cursor lights up and the status line reads *release to fasten*.
4. Let go.

## What “good” looks like

- One new mate of type `fastened`, named `Snap`.
- The bolt's own connector — the one nearest where you grabbed it — is the side that seats.
- Dropping over empty space still just moves the part, so the magnet never fires by surprise.

Film: `snap_bolt_drop`. Kernel: `[mates]` fastened case.

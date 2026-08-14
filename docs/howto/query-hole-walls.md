# Query hole walls

Goal: `type=face created-by=<fid>` lights the faces that feature created.

## Steps

1. Place a box.
2. Run query `type=face created-by=<primitive id>`.
3. Card digest names the feature.

## What “good” looks like

- At least 6 face hits.
- Digest contains `primitive`.

Film: `query_hole_walls`. Kernel: `[wave3][query]`.

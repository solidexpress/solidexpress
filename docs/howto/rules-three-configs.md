# Rules — suppress when wide

Goal: `if width > 100 then suppress rib`. Variables panel Rules fold — not a new dock.

## Steps

1. Place a box and add a rib.
2. Set variable `width` = 120.
3. Apply rule `width > 100` → `suppress rib`.

## What “good” looks like

- Rule fires once; the rib feature is suppressed.

Film: `rules_three_configs`. Kernel: `[wave3][rules]`.

# Pattern a bolt around its joint

Goal: a circular pattern of a jointed component reuses the *one* joint definition. Eight bolts on a pitch circle are not eight independently defined mates.

## Steps

1. Place a plate and instance a bolt.
2. Add a revolute (or fastened) joint between the plate and the bolt if you want the copies to inherit a driver.
3. Select the instance → **Pattern around joint**.
4. The copies land around the joint axis; each carries a copy of the seed joint.

## What “good” looks like

- Instance count equals the pattern count (seed + copies).
- Joint count matches — every copy inherited the definition.
- Driving the seed still poses that instance; the copies keep their own frames.

Film: `bolt_circle_pattern`. Kernel: `[pattern]`.

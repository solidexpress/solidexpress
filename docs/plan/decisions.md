# Architecture decisions

Short ADRs for load-bearing choices. Full rationale also lives in
[implementation-plan.md](implementation-plan.md).

## ADR-001: FeatureGraph is the model of record

**Status:** Accepted (2026-07-24)

**Decision:** Every user-visible body-creating or body-editing operation from
the UI must commit a `Feature` on `FeatureGraph`. Direct `Command` types
(`PushPullCommand`, `FilletCommand`, …) remain as kernel helpers and free-body
fallbacks (bodies not owned by the timeline, e.g. legacy imports), not as the
primary interactive path.

**Consequences:** Timeline, rollback, undo via `GraphSnapshotCommand`, semantic
cards, and AI context stay coherent. Placement-only ops (`translate_body` /
`rotate_body` for move gizmos) stay off-graph and sync feature placement params
quietly when applicable.

## ADR-002: Topology refs are durable UUIDs

**Status:** Accepted (2026-07-24)

**Decision:** Fillet, chamfer, shell, push-pull, and draft feature params store
face/edge **EntityId strings**. Apply resolves them through
`Document::find_subshape` after naming remaps survivors. Legacy 1-based TopExp
map indices still load for old `.sxp` files.

**Consequences:** Dress-ups survive upstream parametric edits when naming
matches. Ambiguous topology still needs TNI improvements (plan task 3.2+).

## ADR-003: Non-throwing Godot boundary

**Status:** Accepted (2026-07-24)

**Decision:** `sxcore` methods catch `std::exception` at the GDExtension
boundary and return `false` / empty ids / error dictionaries. Kernel internals
may still throw for programmer errors; public bridge APIs must not propagate
exceptions into Godot.

## ADR-004: Async regenerate is opt-in

**Status:** Accepted (spike, 2026-07-24)

**Decision:** `SxDocument.set_async_regen(true)` enables
`graph_regenerate_async` / `graph_async_regen_poll`. Default remains synchronous
regen on the calling thread. While a worker is pending, the document must not
be mutated from another thread (OCCT exclusivity).

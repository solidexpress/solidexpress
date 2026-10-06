# Replan 13 WP4 — a refused feature edit leaves the document clean (no Discard prompt)

You are a BUILD agent (grok-4.6, effort high, fast false, `starting_ref` = `main`). **The only WP that touches C++.** Edit only the files below; add `sxkernel/tests/test_rung01_replan13_dirty.cpp` (picked up by the existing glob in `sxkernel/CMakeLists.txt`; `make build` re-runs CMake) and `game/tests/run_rung01_replan13_dirty.gd`. After the change `make build` and `make test-kernel` must pass; Godot must be run against the rebuilt `libsxcore.so`.

| File | Hunk |
|---|---|
| `sxkernel/include/sx/document.hpp` | next to `revision()` (~96): `void restore_revision(uint64_t r) { revision_ = r; }` with a comment that it is only for rolling back a refused edit |
| `sxcore/src/sx_document.cpp` | `SxDocument::apply_graph_edit` (~713): remember the revision before `mutate()`, restore it after the refused edit has been reverted |
| `game/scripts/main.gd` | none expected; `_document_is_dirty` (~2520) stays revision-based |

## The bug (sx-033 A11d/A5b)

Leftover 7: after a fillet that was **refused** (`exceeds the … mm limit`, `fillet the R10 neck first`), File → New or Open shows `Discard unsaved changes?` although the model did not change. The walker had saved first and made no edit since.

## Cause (read on `0573dea2`; **reproduce first**)

`main._document_is_dirty()` is `doc.revision() != _last_saved_revision` (and the document has bodies or features). A refused edit goes through `SxDocument::apply_graph_edit`: `mutate()` adds the fillet feature, `regenerate` fails, and the revert path runs `doc_->set_graph(from_json(before))` (`Document::set_graph` calls `bump_revision()`) and a second `regenerate` (it replaces bodies and bumps again). The model is bit-for-bit the one the walker saved, but `revision()` moved by several steps. `ops_panel._apply_dressup` may also try `view.doc.fillet_edges` as a fallback for a stale-edge refusal (`value <= 10.0 and not _dressup_radius_refused()`): that path must not bump either when it returns false.

## Decisions (see `rung-01-replan-13.md` 7)

- **Roll the revision back, do not hash the document.** A content hash would call a body-colour or move edit clean. Only `apply_graph_edit`'s failure branch restores the number (`const uint64_t rev0 = doc_->revision();` before `mutate`, `doc_->restore_revision(rev0);` after the revert and the second `regenerate`). The success path is unchanged.
- The undo stack is not touched on failure (it already is not: `push_executed` is only reached on success).
- Any other `SxDocument` entry that adds then removes on failure (`graph_add_fillet_var`'s second `apply_graph_edit("fillet radius2", …)`, `fillet_edges` / `chamfer_edges` direct paths) must leave the revision equal when they return failure. Audit them with the same test; fix only the ones that fail it.
- A refused edit still sets `last_graph_error_` / `last_failed_fid_` exactly as today (replan-11/12 fillet-error suites read them).
- `_last_autosaved_revision` comparison (`rev == _last_autosaved_revision`) is unaffected: restoring to a value the document already had cannot trigger a new autosave.

## Failing-first tests

**Kernel** — `sxkernel/tests/test_rung01_replan13_dirty.cpp`, tag `[replan13]`: build a box through the graph, record `doc.revision()`, call the refused-edit path (a fillet of the box's top edges with a radius larger than the face, going through the same function the GD binding calls; if `apply_graph_edit` is not reachable from the kernel, test through a small `SxDocument`-free helper that wraps `regenerate` failure + `set_graph` and assert the helper restores). Assertions: refused edit returns false; `revision()` equals the recorded value; `graph().features().size()` equal; `regenerate` still ok. A second case: an **accepted** edit increases `revision()`. A third: a refused edit followed by an accepted one still increases it. Expected red: the first case (revision moved by ≥ 2). Expected total after the change: `All tests passed (7943 + new assertions, 333 + 3 test cases)` — record the real numbers in the PR.

**Godot** — `game/tests/run_rung01_replan13_dirty.gd` (template `run_rung01_replan12_fillet.gd`; the real widgets): new document, a primitive box, `main._last_saved_revision = doc.revision()` through the real Save As path with a temp absolute path (`ProjectSettings.globalize_path`, never `user://` into C++), then `ops_panel.arm_or_apply_fillet()` with the neck-too-large radius so the refusal text appears:

1. `main._document_is_dirty()` is false after the refusal (red on `0573dea2`).
2. `main.view.doc.revision()` equals the saved revision.
3. File → New: no `confirm_dialog` pops up (`not main.confirm_dialog.visible` after `_on_file_menu` New with the tree processed two frames).
4. A real edit (colour change, or a successful R1) afterwards **is** dirty and File → New does prompt (the rollback must not hide real changes).
5. Refuse **twice in a row**, then Esc: still clean.

## Commands

```
make build && make test-kernel          # new case + all existing kernel cases
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan13_dirty.gd
for t in run_rung01_replan9_dirty run_rung01_replan12_fillet run_rung01_replan11_fillet_err run_rung01_replan10_new; do
  tools/godot/godot --headless --path game --script res://tests/$t.gd 2>&1 | tail -1; done
```

`run_rung01_replan9_dirty` (13/0) is the existing dirty-tracking suite; it must stay 13/0.

## Do not

- Replace the revision with a content hash or make `_document_is_dirty` smarter in GDScript.
- Change `regenerate`, `set_graph` or `bump_revision` themselves.
- Add a public `set_revision` that GDScript can call; `restore_revision` stays a kernel-internal helper.

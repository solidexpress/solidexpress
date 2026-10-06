# Replan 12 WP1 — fillets survive a thickness edit; lost edges warn

You are a BUILD agent. This is the **only kernel WP** of replan 12. Edit only the files listed here. Add `sxkernel/tests/test_rung01_replan12_fillet.cpp` and `game/tests/run_rung01_replan12_fillet.gd`.

| File | Function / hunk |
|---|---|
| `sxkernel/src/features/ops_dress.cpp` | new includes; `note_faulty_contour` (~142); new helpers before `resolve_dressup_edge` (~295); `apply_fillet_chamfer` (~309) |
| `sxkernel/include/sx/features.hpp` | `FeatureGraph`: `warnings()`, `add_warning()`, `warnings_` (next to `last_error()` ~137 and the private members) |
| `sxkernel/src/features.cpp` | `FeatureGraph::regenerate` (~2127): `warnings_.clear()` |
| `sxcore/src/sx_document.hpp` / `.cpp` | `graph_warnings()`; the `warning` key in `graph_features()` (~683); the bind in `_bind_methods` |
| `game/scripts/property_panel.gd` | `_set_param` (~545): append the warnings to the preview status |
| `game/scripts/timeline_panel.gd` | `_make_row` (~259): the `WarnBadge` label |

Do not touch `sketch_mode.gd`, `main.gd`, `ops_panel.gd`, `document_view.gd`, `viewport_interaction.gd` (other WPs) or any checker.

## The bug

A fillet made by clicking a face stores the ids of that face's edges plus an absolute `edge_cues` (midpoint + direction, 0.5 mm gate). Editing the base extrude from 10 to 14 re-mints the ids and moves each vertical edge's midpoint by 2 mm, so `match_edge_cue` finds nothing. `apply_fillet_chamfer` then logs `fillet soft-skip: missing edge uuid …` for every edge and `graph_regenerate` reports ok. The walk's `wrench-t14.3mf` has 2438 triangles: the top R1, the bottom R1, the slot-floor R1 and the neck R10 are all gone and nothing says so.

## Decisions this WP implements (see `rung-01-replan-12.md` 8, 9, 10)

- A fillet/chamfer persists `face_cues` (`[{point:[x,y,z], normal:[x,y,z]}]`) for every planar face (≥ 3 edges) all of whose edges are in its edge set. They are rewritten on every successful apply.
- When some named edges do not resolve, each cue is matched to the planar face with the same normal (dot ≥ 0.999) that contains the cue point after sliding it along the normal onto that face's plane; the smallest slide wins. The matched face's edges join the set.
- Edges that still do not resolve are **warned**, never failed: `<feature name>: all N edges lost on rebuild — it changes nothing now` / `<feature name>: L of N edges lost on rebuild`. The rebuild succeeds.
- `note_faulty_contour` is guarded: `ic < 1 || ic > mk.NbContours() || mk.NbEdges(ic) < 1`. Without it a stale R10 selection segfaults in `BRepFilletAPI_MakeFillet::NbEdges` (reproduced on `2606160c` by the new walk).
- Documents saved before this WP have no `face_cues`. No migration: they get the warning.

## Step by step

1. Start with the two tests below (they define the behaviour). Create both files exactly as shown. `make build` must **fail to compile** `test_rung01_replan12_fillet.cpp` on `2606160c` (`warnings()` does not exist): that is the kernel red.
2. Apply the kernel and sxcore diff below. Search by function name; the hunk line numbers are for `2606160c`.
3. Apply the two GDScript diffs (`property_panel.gd`, `timeline_panel.gd`).
4. `CMAKE_PREFIX_PATH=/opt/occt-8.0.1 make build`, then run the commands in the next section.

### Kernel and sxcore diff (measured)

```diff
diff --git a/sxcore/src/sx_document.cpp b/sxcore/src/sx_document.cpp
index 08bdf2b..6f2e030 100644
--- a/sxcore/src/sx_document.cpp
+++ b/sxcore/src/sx_document.cpp
@@ -693,6 +693,10 @@ Array SxDocument::graph_features() const {
         const bool failed = !last_failed_fid_.empty() && f.id.str() == last_failed_fid_;
         d["failed"] = failed;
         d["error"] = failed ? to_gd(last_graph_error_) : String();
+        String warning;
+        for (const auto& w : doc_->graph().warnings())
+            if (w.first == f.id.str()) warning = to_gd(w.second);
+        d["warning"] = warning;
         String ctx_id;
         if (f.params.contains("context")) ctx_id = to_gd(f.params["context"].get<std::string>());
         d["context_id"] = ctx_id;
@@ -1151,6 +1155,12 @@ String SxDocument::last_graph_error() const {
     return to_gd(last_graph_error_);
 }
 
+PackedStringArray SxDocument::graph_warnings() const {
+    PackedStringArray out;
+    for (const auto& w : doc_->graph().warnings()) out.push_back(to_gd(w.second));
+    return out;
+}
+
 bool SxDocument::remove_variable(const String& name) {
     // Unlike other graph edits, keep the removal even when regenerate fails
     // (features may still reference the name). Undo restores the prior
@@ -2480,6 +2490,7 @@ void SxDocument::_bind_methods() {
     ClassDB::bind_method(D_METHOD("get_card_notes", "entity_id"), &SxDocument::get_card_notes);
     ClassDB::bind_method(D_METHOD("export_context"), &SxDocument::export_context);
     ClassDB::bind_method(D_METHOD("graph_features"), &SxDocument::graph_features);
+    ClassDB::bind_method(D_METHOD("graph_warnings"), &SxDocument::graph_warnings);
     ClassDB::bind_method(D_METHOD("graph_add_primitive", "kind", "a", "b", "c", "origin"), &SxDocument::graph_add_primitive);
     ClassDB::bind_method(D_METHOD("graph_add_sketch", "sketch"), &SxDocument::graph_add_sketch);
     ClassDB::bind_method(D_METHOD("graph_get_sketch", "fid"), &SxDocument::graph_get_sketch);
diff --git a/sxcore/src/sx_document.hpp b/sxcore/src/sx_document.hpp
index ee4540b..f5fd7af 100644
--- a/sxcore/src/sx_document.hpp
+++ b/sxcore/src/sx_document.hpp
@@ -235,6 +235,9 @@ public:
     bool remove_variable(const godot::String& name);
     // Last regenerate error from apply_graph_edit / set_variable (empty if ok).
     godot::String last_graph_error() const;
+    // Notes from the last regenerate that did not stop it (a fillet that lost
+    // some edges). Empty when the rebuild was clean.
+    godot::PackedStringArray graph_warnings() const;
     // Array of {name, expr, value (float; NAN on error), error: String}.
     godot::Array list_variables() const;
 
diff --git a/sxkernel/include/sx/features.hpp b/sxkernel/include/sx/features.hpp
index 61c013f..14ff6d3 100644
--- a/sxkernel/include/sx/features.hpp
+++ b/sxkernel/include/sx/features.hpp
@@ -136,6 +136,15 @@ public:
     const EntityId& last_failed_feature() const { return last_failed_; }
     const std::string& last_error() const { return last_error_; }
 
+    // Non-fatal notes from the last regenerate: (feature id, message). A fillet
+    // that lost some of its edges on a rebuild still builds and says so here.
+    const std::vector<std::pair<std::string, std::string>>& warnings() const {
+        return warnings_;
+    }
+    void add_warning(const EntityId& feature, std::string message) {
+        warnings_.emplace_back(feature.str(), std::move(message));
+    }
+
     // Full rebuild: removes all graph-owned bodies from the document and
     // replays the timeline. On failure, err names the offending feature and
     // the document is left with features applied up to that point.
@@ -159,6 +168,7 @@ private:
     int rollback_index_ = -1;
     EntityId last_failed_;
     std::string last_error_;
+    std::vector<std::pair<std::string, std::string>> warnings_;
     // Body ids created by the last regenerate. Needed so bodies belonging to
     // features that were since removed from the timeline still get cleaned up.
     std::vector<EntityId> generated_;
diff --git a/sxkernel/src/features.cpp b/sxkernel/src/features.cpp
index 14d3a3f..ca941ae 100644
--- a/sxkernel/src/features.cpp
+++ b/sxkernel/src/features.cpp
@@ -2133,6 +2133,7 @@ bool FeatureGraph::regenerate(Document& doc, std::string* err) {
     std::map<std::string, double> env;
     last_failed_ = {};
     last_error_.clear();
+    warnings_.clear();
     try {
         env = variables_.evaluate();
     } catch (const std::exception& e) {
diff --git a/sxkernel/src/features/ops_dress.cpp b/sxkernel/src/features/ops_dress.cpp
index a906cbe..b680701 100644
--- a/sxkernel/src/features/ops_dress.cpp
+++ b/sxkernel/src/features/ops_dress.cpp
@@ -5,11 +5,14 @@
 #include <BRepAlgoAPI_Cut.hxx>
 #include <BRepAlgoAPI_Fuse.hxx>
 #include <BRepBuilderAPI_MakeVertex.hxx>
+#include <BRepClass_FaceClassifier.hxx>
 #include <BRepExtrema_DistShapeShape.hxx>
 #include <BRepFilletAPI_MakeChamfer.hxx>
 #include <BRepFilletAPI_MakeFillet.hxx>
 #include <BRepGProp.hxx>
+#include <BRepTools.hxx>
 #include <BRep_Tool.hxx>
+#include <ElSLib.hxx>
 #include <ShapeUpgrade_UnifySameDomain.hxx>
 #include <GProp_GProps.hxx>
 #include <TopExp.hxx>
@@ -27,6 +30,7 @@
 #include <gp_Dir.hxx>
 #include <gp_Lin.hxx>
 #include <gp_Pln.hxx>
+#include <gp_Pnt2d.hxx>
 #include <gp_Vec.hxx>
 
 #include <algorithm>
@@ -144,7 +148,7 @@ void note_faulty_contour(BRepFilletAPI_MakeFillet& mk, std::string* fault) {
     fault->clear();
     if (mk.NbFaultyContours() < 1) return;
     const int ic = mk.FaultyContour(1);
-    if (mk.NbEdges(ic) < 1) return;
+    if (ic < 1 || ic > mk.NbContours() || mk.NbEdges(ic) < 1) return;
     const TopoDS_Edge fe = mk.Edge(ic, 1);
     if (!fe.IsNull()) *fault = edge_phrase(fe);
 }
@@ -292,6 +296,125 @@ bool fillet_unified(const TopoDS_Shape& shape, const std::vector<TopoDS_Edge>& p
     return build_fillet(unified, chosen, v, r2, out, fault);
 }
 
+// A face pick fillets every edge of that face. Edge ids and cues move when an
+// upstream edit (a thicker base extrude) moves the face, so the feature also
+// remembers the face itself: its plane normal and one point inside it.
+std::vector<TopoDS_Edge> face_edges(const TopoDS_Face& face) {
+    sx::occt::ShapeIndexedMap map;
+    TopExp::MapShapes(face, TopAbs_EDGE, map);
+    std::vector<TopoDS_Edge> out;
+    for (int i = 1; i <= map.Extent(); ++i) {
+        const TopoDS_Edge edge = TopoDS::Edge(map(i));
+        if (!BRep_Tool::Degenerated(edge)) out.push_back(edge);
+    }
+    return out;
+}
+
+bool contains_edge(const std::vector<TopoDS_Edge>& edges, const TopoDS_Edge& edge) {
+    for (const auto& e : edges)
+        if (e.IsSame(edge)) return true;
+    return false;
+}
+
+bool planar_face_normal(const TopoDS_Face& face, gp_Dir& n) {
+    BRepAdaptor_Surface surf(face);
+    if (surf.GetType() != GeomAbs_Plane) return false;
+    n = surf.Plane().Axis().Direction();
+    if (face.Orientation() == TopAbs_REVERSED) n.Reverse();
+    return true;
+}
+
+// The grid sample inside the face that sits nearest the middle of its UV box.
+bool face_interior_point(const TopoDS_Face& face, gp_Pnt& out) {
+    double u0, u1, v0, v1;
+    BRepTools::UVBounds(face, u0, u1, v0, v1);
+    BRepAdaptor_Surface surf(face);
+    const int n = 16;
+    double best = 1e300;
+    bool found = false;
+    for (int i = 1; i < n; ++i) {
+        for (int j = 1; j < n; ++j) {
+            const double fu = static_cast<double>(i) / n;
+            const double fv = static_cast<double>(j) / n;
+            const double u = u0 + (u1 - u0) * fu;
+            const double v = v0 + (v1 - v0) * fv;
+            BRepClass_FaceClassifier cl(face, gp_Pnt2d(u, v), 1e-7);
+            if (cl.State() != TopAbs_IN) continue;
+            const double d = (fu - 0.5) * (fu - 0.5) + (fv - 0.5) * (fv - 0.5);
+            if (d < best) {
+                best = d;
+                out = surf.Value(u, v);
+                found = true;
+            }
+        }
+    }
+    return found;
+}
+
+nlohmann::json face_cues_for(const TopoDS_Shape& shape, const std::vector<TopoDS_Edge>& edges) {
+    nlohmann::json cues = nlohmann::json::array();
+    sx::occt::ShapeIndexedMap faces;
+    TopExp::MapShapes(shape, TopAbs_FACE, faces);
+    for (int i = 1; i <= faces.Extent(); ++i) {
+        const TopoDS_Face face = TopoDS::Face(faces(i));
+        gp_Dir n;
+        if (!planar_face_normal(face, n)) continue;
+        const std::vector<TopoDS_Edge> fe = face_edges(face);
+        if (fe.size() < 3) continue;
+        bool covered = true;
+        for (const auto& e : fe) {
+            if (!contains_edge(edges, e)) {
+                covered = false;
+                break;
+            }
+        }
+        if (!covered) continue;
+        gp_Pnt p;
+        if (!face_interior_point(face, p)) continue;
+        cues.push_back({{"point", {p.X(), p.Y(), p.Z()}}, {"normal", {n.X(), n.Y(), n.Z()}}});
+    }
+    return cues;
+}
+
+// The planar face with the cue's normal that still contains the cue point once
+// the point slides along the normal onto the face's plane. When several faces
+// qualify (a pocket floor under the top face), the one whose plane moved
+// least wins.
+bool match_face_cue(const TopoDS_Shape& shape, const nlohmann::json& cue, TopoDS_Face& out) {
+    if (!cue.is_object() || !cue.contains("point") || !cue.contains("normal")) return false;
+    const auto& pj = cue["point"];
+    const auto& nj = cue["normal"];
+    if (!pj.is_array() || pj.size() < 3 || !nj.is_array() || nj.size() < 3) return false;
+    const gp_Pnt want(pj[0].get<double>(), pj[1].get<double>(), pj[2].get<double>());
+    gp_Vec want_n(nj[0].get<double>(), nj[1].get<double>(), nj[2].get<double>());
+    if (want_n.Magnitude() < 1e-12) return false;
+    want_n.Normalize();
+    sx::occt::ShapeIndexedMap faces;
+    TopExp::MapShapes(shape, TopAbs_FACE, faces);
+    double best = 1e300;
+    bool found = false;
+    for (int i = 1; i <= faces.Extent(); ++i) {
+        const TopoDS_Face face = TopoDS::Face(faces(i));
+        gp_Dir n;
+        if (!planar_face_normal(face, n)) continue;
+        if (gp_Vec(n).Dot(want_n) < 0.999) continue;
+        BRepAdaptor_Surface surf(face);
+        const gp_Pln pln = surf.Plane();
+        const double shift = gp_Vec(want, pln.Location()).Dot(want_n);
+        const gp_Pnt on_plane = want.Translated(want_n * shift);
+        double u, v;
+        ElSLib::PlaneParameters(pln.Position(), on_plane, u, v);
+        BRepClass_FaceClassifier cl(face, gp_Pnt2d(u, v), 1e-4);
+        if (cl.State() != TopAbs_IN && cl.State() != TopAbs_ON) continue;
+        if (std::abs(shift) < best) {
+            best = std::abs(shift);
+            out = face;
+            found = true;
+        }
+    }
+    return found;
+}
+
 bool resolve_dressup_edge(ApplyCtx& ctx, const Body& body, const nlohmann::json& je,
                           TopoDS_Shape& es, std::string* why) {
     if (resolve_topo_shape(ctx.doc, body, EntityKind::Edge, je, es, why)) return true;
@@ -304,6 +427,65 @@ bool resolve_dressup_edge(ApplyCtx& ctx, const Body& body, const nlohmann::json&
     return true;
 }
 
+struct DressupEdges {
+    std::vector<TopoDS_Edge> edges;
+    int total = 0;
+    int lost = 0;
+};
+
+// Every edge the feature names that still resolves. Edges that do not are
+// re-found through the face the feature was built from (face_cues). What
+// stays unresolved after that is counted in `lost`.
+DressupEdges resolve_dressup_edges(ApplyCtx& ctx, const Body& body, const char* soft_skip_tag) {
+    DressupEdges out;
+    for (const auto& je : ctx.params.at("edges")) {
+        ++out.total;
+        TopoDS_Shape es;
+        std::string why;
+        if (!resolve_dressup_edge(ctx, body, je, es, &why)) {
+            sx::log::error(std::string(soft_skip_tag) + why);
+            continue;
+        }
+        const TopoDS_Edge edge = TopoDS::Edge(es);
+        if (!contains_edge(out.edges, edge)) out.edges.push_back(edge);
+    }
+    if (static_cast<int>(out.edges.size()) < out.total) {
+        const auto& cues = ctx.feature.params.value("face_cues", nlohmann::json::array());
+        if (cues.is_array()) {
+            for (const auto& cue : cues) {
+                TopoDS_Face face;
+                if (!match_face_cue(body.shape, cue, face)) continue;
+                for (const auto& e : face_edges(face))
+                    if (!contains_edge(out.edges, e)) out.edges.push_back(e);
+            }
+        }
+    }
+    out.lost = std::max(0, out.total - static_cast<int>(out.edges.size()));
+    return out;
+}
+
+// Lost edges never fail the rebuild: unrelated edits (a later sketch, a hole)
+// must not be rolled back. They are reported as a warning the status line and
+// the timeline row show.
+bool report_lost_edges(ApplyCtx& ctx, const DressupEdges& found) {
+    if (found.total == 0 || found.lost == 0) return true;
+    const std::string what =
+        found.edges.empty()
+            ? "all " + std::to_string(found.total) + " edges lost on rebuild — it changes nothing now"
+            : std::to_string(found.lost) + " of " + std::to_string(found.total)
+                  + " edges lost on rebuild";
+    ctx.graph.add_warning(ctx.feature.id, ctx.feature.name + ": " + what);
+    return true;
+}
+
+void remember_face_cues(ApplyCtx& ctx, const Body& body, const std::vector<TopoDS_Edge>& edges) {
+    nlohmann::json cues = face_cues_for(body.shape, edges);
+    if (cues.empty())
+        ctx.feature.params.erase("face_cues");
+    else
+        ctx.feature.params["face_cues"] = std::move(cues);
+}
+
 }  // namespace
 
 bool apply_fillet_chamfer(ApplyCtx& ctx) {
@@ -320,30 +502,19 @@ bool apply_fillet_chamfer(ApplyCtx& ctx) {
         const double r2 = ctx.params.contains("radius2")
                               ? num_param(ctx.params, "radius2", v, ctx.env)
                               : v;
-        int added = 0;
         double limit = std::numeric_limits<double>::infinity();
         TopoDS_Edge limit_edge;
-        std::vector<TopoDS_Edge> resolved;
-        for (const auto& je : ctx.params.at("edges")) {
-            TopoDS_Shape es;
-            std::string why;
-            if (!resolve_dressup_edge(ctx, *tb, je, es, &why)) {
-                // Soft-skip only a missing edge id (upstream regen dropped it
-                // and no pre-regen cue matches). A radius the user just typed
-                // still fails below once any edge resolves.
-                sx::log::error(std::string("fillet soft-skip: ") + why);
-                continue;
-            }
-            TopoDS_Edge edge = TopoDS::Edge(es);
+        const DressupEdges found = resolve_dressup_edges(ctx, *tb, "fillet soft-skip: ");
+        if (!report_lost_edges(ctx, found)) return false;
+        std::vector<TopoDS_Edge> resolved = found.edges;
+        for (const auto& edge : resolved) {
             const double this_limit = 0.5 * min_departure_length(tb->shape, edge);
             if (this_limit < limit) {
                 limit = this_limit;
                 limit_edge = edge;
             }
-            resolved.push_back(edge);
-            ++added;
         }
-        if (added == 0) return true;
+        if (resolved.empty()) return true;
         const double asked = std::max(v, r2);
         // "fillet failed (limit …)" is only for a radius that does not fit.
         if (limit < 1e290 && asked > limit + 1e-4) {
@@ -363,23 +534,17 @@ bool apply_fillet_chamfer(ApplyCtx& ctx) {
                 return ctx.fail("fillet failed");
             }
         }
+        remember_face_cues(ctx, *tb, resolved);
     } else {
         BRepFilletAPI_MakeChamfer mk(tb->shape);
-        int added = 0;
-        for (const auto& je : ctx.params.at("edges")) {
-            TopoDS_Shape es;
-            std::string why;
-            if (!resolve_dressup_edge(ctx, *tb, je, es, &why)) {
-                sx::log::error(std::string("chamfer soft-skip: ") + why);
-                return true;
-            }
-            mk.Add(v, TopoDS::Edge(es));
-            ++added;
-        }
-        if (added == 0) return true;
+        const DressupEdges found = resolve_dressup_edges(ctx, *tb, "chamfer soft-skip: ");
+        if (!report_lost_edges(ctx, found)) return false;
+        if (found.edges.empty()) return true;
+        for (const auto& edge : found.edges) mk.Add(v, edge);
         mk.Build();
         if (!mk.IsDone()) return ctx.fail("chamfer failed");
         result = mk.Shape();
+        remember_face_cues(ctx, *tb, found.edges);
     }
     if (!shape::is_valid(result)) return ctx.fail("result invalid");
     ctx.doc.replace_body_shape(target, result);
```

### `game/scripts/property_panel.gd`

```diff
diff --git a/game/scripts/property_panel.gd b/game/scripts/property_panel.gd
index c008512..fdf6158 100644
--- a/game/scripts/property_panel.gd
+++ b/game/scripts/property_panel.gd
@@ -551,7 +551,12 @@ func _set_param(key: String, value) -> void:
 	if view.doc.graph_set_params(_fid, JSON.stringify(_params)):
 		_edits += 1
 		view.graph_changed()
-		status.emit("Preview: %s = %s" % [key, str(value)])
+		var note := ""
+		if view.doc.has_method("graph_warnings"):
+			var warnings: PackedStringArray = view.doc.graph_warnings()
+			if not warnings.is_empty():
+				note = " — " + "; ".join(warnings)
+		status.emit("Preview: %s = %s%s" % [key, str(value), note])
 		# End = Up To Surface reveals the face row; other ends hide it.
 		if key == "end" and _type != "":
 			_build_fields.call_deferred(_type)
```

### `game/scripts/timeline_panel.gd`

```diff
diff --git a/game/scripts/timeline_panel.gd b/game/scripts/timeline_panel.gd
index 22c9670..7cf73cd 100644
--- a/game/scripts/timeline_panel.gd
+++ b/game/scripts/timeline_panel.gd
@@ -310,6 +310,16 @@ func _make_row(f: Dictionary, index: int, count: int) -> Control:
 		row.add_child(badge)
 		name_btn.modulate = Color(1.0, 0.55, 0.5)
 
+	if str(f.get("warning", "")) != "" and not f.get("failed", false):
+		var warn := Label.new()
+		warn.name = "WarnBadge"
+		warn.text = "⚠"
+		warn.tooltip_text = str(f["warning"])
+		warn.mouse_filter = Control.MOUSE_FILTER_STOP
+		warn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
+		warn.add_theme_font_size_override("font_size", UiScale.font(16))
+		row.add_child(warn)
+
 	if f.get("context_stale", false):
 		var upd := Button.new()
 		upd.name = "UpdateContext"
```

## Test 1 — `sxkernel/tests/test_rung01_replan12_fillet.cpp` (create)

Three cases tagged `[replan12]`: a face-derived top fillet survives T 10→14→10 (the body at T=14 has the rounded corner; the probe outside the corner is not solid); all edges lost → one warning naming the feature and the edit stands (`last_failed_feature().is_null()`); a fillet that loses one of two edges → `1 of 2 edges lost on rebuild`.

`sxkernel/tests/test_rung01_replan12_fillet.cpp`

```cpp
#include <catch.hpp>

#include <BRepAdaptor_Surface.hxx>
#include <BRepClass3d_SolidClassifier.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <GeomAbs_SurfaceType.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>

#include <cmath>
#include <string>

#include "sx/document.hpp"
#include "sx/features.hpp"
#include "sx/query.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch.hpp"

using namespace sx;
using nlohmann::json;

namespace {

bool point_inside(const TopoDS_Shape& shape, const gp_Pnt& p) {
    for (TopExp_Explorer ex(shape, TopAbs_SOLID); ex.More(); ex.Next()) {
        BRepClass3d_SolidClassifier cl(ex.Current());
        cl.Perform(p, 1e-6);
        if (cl.State() == TopAbs_IN) return true;
    }
    return false;
}

gp_Pnt edge_midpoint(const TopoDS_Edge& edge) {
    GProp_GProps props;
    BRepGProp::LinearProperties(edge, props);
    return props.CentreOfMass();
}

EntityId face_at_z(const Document& doc, const EntityId& body, double z_want) {
    EntityId best;
    double best_d = 1e300;
    const Body* b = doc.body(body);
    if (!b) return best;
    for (const auto& fid : b->subshape_ids.at(EntityKind::Face)) {
        TopoDS_Shape s = doc.resolve(fid);
        if (s.IsNull() || s.ShapeType() != TopAbs_FACE) continue;
        BRepAdaptor_Surface surf(TopoDS::Face(s));
        if (surf.GetType() != GeomAbs_Plane) continue;
        if (std::abs(surf.Plane().Axis().Direction().Z()) < 0.9) continue;
        GProp_GProps props;
        BRepGProp::SurfaceProperties(TopoDS::Face(s), props);
        const double d = std::abs(props.CentreOfMass().Z() - z_want);
        if (d < best_d) {
            best_d = d;
            best = fid;
        }
    }
    return best;
}

void add_rect(Sketch& sk, double x0, double y0, double x1, double y1) {
    sk.add_line(x0, y0, x1, y0);
    sk.add_line(x1, y0, x1, y1);
    sk.add_line(x1, y1, x0, y1);
    sk.add_line(x0, y1, x0, y0);
}

json ids_json(const std::vector<EntityId>& ids) {
    json out = json::array();
    for (const auto& e : ids) out.push_back(e.str());
    return out;
}

struct Plate {
    Document doc;
    FeatureGraph graph;
    EntityId ext_id;
    EntityId body;
    std::string err;

    // 40 x 30 x 10 plate with a 20 x 10 x 2.5 slot cut from the top. The slot
    // sketch carries support keys, so a thickness edit moves it with the top.
    Plate() {
        Feature skf;
        skf.type = FeatureType::Sketch;
        skf.sketch = std::make_shared<Sketch>("Plate");
        add_rect(*skf.sketch, -20, -15, 20, 15);
        auto sk_id = graph.add(std::move(skf));
        Feature ext;
        ext.type = FeatureType::Extrude;
        ext.params = {{"sketch", sk_id.str()}, {"distance", 10.0}, {"op", "new"},
                      {"end", "blind"}};
        ext_id = graph.add(std::move(ext));
        REQUIRE(graph.regenerate(doc, &err));
        body = graph.feature(ext_id)->output_body;

        Feature slot_sk;
        slot_sk.type = FeatureType::Sketch;
        SketchPlane plane;
        plane.origin = {0, 0, 10};
        plane.x_dir = {1, 0, 0};
        plane.y_dir = {0, 1, 0};
        slot_sk.sketch = std::make_shared<Sketch>("Slot", plane);
        add_rect(*slot_sk.sketch, -10, -5, 10, 5);
        slot_sk.params = {{"support_host", ext_id.str()},
                          {"support_normal", {0.0, 0.0, 1.0}},
                          {"support_side", "max"}};
        auto slot_sk_id = graph.add(std::move(slot_sk));
        Feature slot;
        slot.type = FeatureType::Extrude;
        slot.params = {{"sketch", slot_sk_id.str()}, {"distance", -2.5}, {"end", "blind"},
                       {"op", "cut"}, {"target", ext_id.str()}};
        graph.add(std::move(slot));
        REQUIRE(graph.regenerate(doc, &err));
    }

    EntityId add_fillet(const json& edges, double radius) {
        Feature fil;
        fil.type = FeatureType::Fillet;
        fil.params = {{"target", ext_id.str()}, {"radius", radius}, {"edges", edges}};
        auto id = graph.add(std::move(fil));
        REQUIRE(graph.regenerate(doc, &err));
        return id;
    }

    bool set_thickness(double t) {
        json p = graph.feature(ext_id)->params;
        p["distance"] = t;
        REQUIRE(graph.set_params(ext_id, p));
        err.clear();
        return graph.regenerate(doc, &err);
    }

    const TopoDS_Shape& shape() const { return doc.body(body)->shape; }

    json edges_where(double z, double tol, bool want_outer_x) const {
        json out = json::array();
        const Body* b = doc.body(body);
        for (const auto& eid : b->subshape_ids.at(EntityKind::Edge)) {
            TopoDS_Shape s = doc.resolve(eid);
            if (s.IsNull() || s.ShapeType() != TopAbs_EDGE) continue;
            const gp_Pnt m = edge_midpoint(TopoDS::Edge(s));
            if (std::abs(m.Z() - z) > tol) continue;
            if (want_outer_x && std::abs(std::abs(m.X()) - 20.0) > 0.6) continue;
            out.push_back(eid.str());
        }
        return out;
    }
};

}  // namespace

TEST_CASE("face-derived top and slot-floor R1 survive a thickness edit",
          "[rung01][replan12][fillet]") {
    Plate plate;
    const EntityId top = face_at_z(plate.doc, plate.body, 10.0);
    REQUIRE(!top.is_null());
    const auto top_edges = edges_of_face(plate.doc, top);
    REQUIRE(top_edges.size() >= 8);
    plate.add_fillet(ids_json(top_edges), 1.0);
    REQUIRE_FALSE(point_inside(plate.shape(), gp_Pnt(-19.9, 0, 9.9)));

    const EntityId floor = face_at_z(plate.doc, plate.body, 7.5);
    REQUIRE(!floor.is_null());
    const auto floor_edges = edges_of_face(plate.doc, floor);
    REQUIRE(floor_edges.size() >= 4);
    plate.add_fillet(ids_json(floor_edges), 1.0);
    REQUIRE(point_inside(plate.shape(), gp_Pnt(0.0, 4.9, 7.6)));

    REQUIRE(plate.set_thickness(14.0));
    INFO(plate.err);
    CHECK(plate.graph.warnings().empty());
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(-19.9, 0, 13.9)));
    CHECK(point_inside(plate.shape(), gp_Pnt(-19.7, 0, 9.0)));
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(9.9, 0, 13.9)));
    CHECK(point_inside(plate.shape(), gp_Pnt(0.0, 4.9, 11.6)));
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(0.0, 0.0, 12.0)));

    // Back to 10: the same fillets still resolve (cues and faces re-anchored).
    REQUIRE(plate.set_thickness(10.0));
    CHECK_FALSE(point_inside(plate.shape(), gp_Pnt(-19.9, 0, 9.9)));
    CHECK(point_inside(plate.shape(), gp_Pnt(0.0, 4.9, 7.6)));
}

TEST_CASE("a fillet whose edges are all lost warns by name and the edit stands",
          "[rung01][replan12][fillet]") {
    Plate plate;
    json two = json::array();
    json floor = plate.edges_where(7.5, 0.1, false);
    REQUIRE(floor.size() >= 2);
    two.push_back(floor[0]);
    two.push_back(floor[1]);
    plate.add_fillet(two, 1.0);

    REQUIRE(plate.set_thickness(14.0));
    INFO(plate.err);
    REQUIRE(plate.graph.warnings().size() == 1);
    const std::string msg = plate.graph.warnings()[0].second;
    CHECK(msg.find("fillet") != std::string::npos);
    CHECK(msg.find("all 2 edges lost on rebuild") != std::string::npos);
    CHECK(plate.graph.last_failed_feature().is_null());
}

TEST_CASE("a fillet that loses some edges still builds and warns",
          "[rung01][replan12][fillet]") {
    Plate plate;
    json floor = plate.edges_where(7.5, 0.1, false);
    json bottom = plate.edges_where(0.0, 0.1, false);
    REQUIRE(floor.size() >= 1);
    REQUIRE(bottom.size() >= 1);
    json mixed = json::array();
    mixed.push_back(floor[0]);
    mixed.push_back(bottom[0]);
    plate.add_fillet(mixed, 1.0);
    REQUIRE(plate.graph.warnings().empty());

    REQUIRE(plate.set_thickness(14.0));
    INFO(plate.err);
    REQUIRE(plate.graph.warnings().size() == 1);
    const std::string msg = plate.graph.warnings()[0].second;
    CHECK(msg.find("1 of 2 edges lost on rebuild") != std::string::npos);
    CHECK(msg.find("fillet") != std::string::npos);
}
```

## Test 2 — `game/tests/run_rung01_replan12_fillet.gd` (create)

`game/tests/run_rung01_replan12_fillet.gd`

```gdscript
extends SceneTree
## Rung 1 replan 12 WP1. Validation: fillets survive a thickness edit, and a fillet
## that loses edges says so.
## Run:
## LD_LIBRARY_PATH=/opt/occt-8.0.1/lib tools/godot/godot --headless --path game --script tests/run_rung01_replan12_fillet.gd

const FilmUI = preload("res://tests/lib/film_ui.gd")
const ROOT_SIZE := Vector2i(1280, 800)
var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   - " + what)
	else:
		failures += 1
		printerr("  FAIL - " + what)


func _init() -> void:
	print("rung01 replan12 WP1 fillets survive thickness")
	await _case_face()
	await _case_all_lost()
	await _case_partial()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _fresh() -> Dictionary:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ctx := FilmContext.new()
	ctx.main = main
	ctx.view = main.view
	ctx.tree = self
	await FilmUI.ensure_test_viewport(ctx, ROOT_SIZE)
	var view: DocumentView = main.view
	var body: String = view.insert_primitive("box", Vector3.ZERO, Vector3(40, 20, 10))
	await process_frame
	return {"main": main, "view": view, "doc": view.doc, "body": body,
			"prim": view.feature_of_body(body)}


func _top_face(doc: SxDocument, body: String) -> String:
	var best := ""
	var best_z := -1e9
	for fid in doc.get_face_ids(body):
		var bb: Dictionary = doc.measure_bbox(str(fid))
		if bb.is_empty():
			continue
		var mn: Vector3 = bb["min"]
		var mx: Vector3 = bb["max"]
		if mx.z - mn.z > 0.1:
			continue
		if mx.z > best_z:
			best_z = mx.z
			best = str(fid)
	return best


## Edge of `body` whose polyline midpoint is within 0.1 mm of `mid`.
func _edge_at(doc: SxDocument, body: String, mid: Vector3) -> String:
	var lines: Dictionary = doc.get_edge_lines(body)
	for id in lines:
		var pts: PackedVector3Array = lines[id]
		if pts.size() < 2:
			continue
		var m := (pts[0] + pts[pts.size() - 1]) * 0.5
		if m.distance_to(mid) < 0.1:
			return str(id)
	return ""


func _set_thickness(ctx: Dictionary, t: float) -> bool:
	var doc: SxDocument = ctx["doc"]
	var prim := str(ctx["prim"])
	var params = JSON.parse_string(_params_of(doc, prim))
	params["c"] = t
	return doc.graph_set_params(prim, JSON.stringify(params))


func _params_of(doc: SxDocument, fid: String) -> String:
	for f in doc.graph_features():
		if str(f.get("id", "")) == fid:
			return str(f.get("params", ""))
	return ""


func _case_face() -> void:
	print("- face-derived top fillet follows the top")
	var c := await _fresh()
	var doc: SxDocument = c["doc"]
	var body := str(c["body"])
	var top := _top_face(doc, body)
	var edges := doc.edges_of_face(top)
	check(edges.size() == 4, "top face has 4 edges (got %d)" % edges.size())
	var ff := doc.graph_add_fillet(str(c["prim"]), edges, 1.0)
	check(ff != "", "face fillet created (err '%s')" % doc.last_graph_error())
	check(_params_of(doc, ff).contains("face_cues"), "fillet params carry face_cues")
	var ok := _set_thickness(c, 14.0)
	check(ok, "thickness 14 accepted (err '%s')" % doc.last_graph_error())
	check(_warnings(doc).is_empty(), "no warnings (got %s)" % str(_warnings(doc)))
	var mesh := _load_mesh(doc, body)
	check(not _inside(mesh, Vector3(-19.9, 0, 13.9)), "top rim is rounded at z=13.9")
	check(_inside(mesh, Vector3(-19.7, 0, 9.0)), "wall is solid at z=9")
	(c["main"] as Node).queue_free()
	await process_frame


## Cuts a 8 x 4 x 2.5 pocket from the top of the box with the sketch session the
## GUI uses. Its floor edges get new ids every rebuild.
func _cut_pocket(c: Dictionary) -> void:
	var main = c["main"]
	var sm: SketchMode = main.sketch_mode
	main._start_sketch_on_face(_top_face(c["doc"], str(c["body"])), str(c["body"]))
	await process_frame
	sm.sketch.add_line(-4, -2, 4, -2)
	sm.sketch.add_line(4, -2, 4, 2)
	sm.sketch.add_line(4, 2, -4, 2)
	sm.sketch.add_line(-4, 2, -4, -2)
	sm.finish_extrude(2.5, "cut", "blind")
	await process_frame
	await process_frame


func _case_all_lost() -> void:
	print("- a fillet whose edges all vanish warns by name and the edit stands")
	var c := await _fresh()
	await _cut_pocket(c)
	var doc: SxDocument = c["doc"]
	var body := str(c["body"])
	var a := _edge_at(doc, body, Vector3(0, -2, 7.5))
	var b := _edge_at(doc, body, Vector3(0, 2, 7.5))
	check(a != "" and b != "", "pocket floor edges found")
	var ff := doc.graph_add_fillet((c["view"] as DocumentView).feature_of_body(body), PackedStringArray([a, b]), 0.5)
	check(ff != "", "two-edge floor fillet created (err '%s')" % doc.last_graph_error())
	var ok := _set_thickness(c, 14.0)
	check(ok, "thickness 14 is accepted (err '%s')" % doc.last_graph_error())
	var warnings := _warnings(doc)
	check(warnings.size() == 1 and warnings[0].contains("all 2 edges lost on rebuild") and warnings[0].contains("fillet"),
			"the warning names the loss (got %s)" % str(warnings))
	var bb: Dictionary = doc.measure_bbox(body)
	var ext: Vector3 = (bb["max"] as Vector3) - (bb["min"] as Vector3)
	check(absf(ext.z - 14.0) < 0.01, "body is 14 thick (got %.3f)" % ext.z)
	(c["main"] as Node).queue_free()
	await process_frame


func _warnings(doc: SxDocument) -> PackedStringArray:
	if not doc.has_method("graph_warnings"):
		return PackedStringArray()
	return doc.call("graph_warnings")


func _case_partial() -> void:
	print("- a fillet that loses one of two edges warns")
	var c := await _fresh()
	await _cut_pocket(c)
	var main = c["main"]
	var doc: SxDocument = c["doc"]
	var body := str(c["body"])
	var floor_edge := _edge_at(doc, body, Vector3(0, -2, 7.5))
	var bottom := _edge_at(doc, body, Vector3(0, -10, 0))
	check(floor_edge != "" and bottom != "", "pocket floor edge and a bottom edge found")
	var ff := doc.graph_add_fillet((c["view"] as DocumentView).feature_of_body(body), PackedStringArray([floor_edge, bottom]), 0.5)
	check(ff != "", "mixed fillet created (err '%s')" % doc.last_graph_error())
	check(_warnings(doc).is_empty(), "no warning before the edit")
	var ok := _set_thickness(c, 14.0)
	check(ok, "thickness 14 accepted (err '%s')" % doc.last_graph_error())
	var warnings := _warnings(doc)
	check(warnings.size() == 1 and warnings[0].contains("1 of 2 edges lost on rebuild"),
			"one warning (got %s)" % str(warnings))
	var row_warning := ""
	for f in doc.graph_features():
		if str(f.get("id", "")) == ff:
			row_warning = str(f.get("warning", ""))
	check(row_warning.contains("1 of 2 edges lost on rebuild"),
			"graph_features names the warning (got '%s')" % row_warning)
	main.show_timeline = true
	main._update_panel_visibility()
	main.timeline.refresh()
	await process_frame
	check(main.timeline.find_child("WarnBadge", true, false) != null, "timeline row shows a warning badge")
	main.queue_free()
	await process_frame


func _load_mesh(doc: SxDocument, body: String) -> Array:
	var mesh: ArrayMesh = doc.get_mesh(body)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(v)
		var ii: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if ii.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ii:
				idx.append(base + i)
	return [verts, idx]


func _ray_hits(mesh: Array, origin: Vector3, dir: Vector3) -> Array[float]:
	var verts: PackedVector3Array = mesh[0]
	var idx: PackedInt32Array = mesh[1]
	var d := dir.normalized()
	var hits: Array[float] = []
	var ntri := idx.size() / 3
	for t in ntri:
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var e1 := b - a
		var e2 := c - a
		var pvec := d.cross(e2)
		var det := e1.dot(pvec)
		if absf(det) < 1e-12:
			continue
		var inv := 1.0 / det
		var s := origin - a
		var u := s.dot(pvec) * inv
		if u < 0.0 or u > 1.0:
			continue
		var q := s.cross(e1)
		var v := d.dot(q) * inv
		if v < 0.0 or u + v > 1.0:
			continue
		var dist := e2.dot(q) * inv
		if dist > 1e-6:
			hits.append(dist)
	hits.sort()
	return hits


func _inside(mesh: Array, pt: Vector3) -> bool:
	var votes := 0
	for d in [Vector3(1, 0.0123, 0.0071), Vector3(0.0091, 1, 0.0137), Vector3(0.0113, 0.0067, 1)]:
		if _ray_hits(mesh, pt, d).size() % 2 == 1:
			votes += 1
	return votes >= 2
```

## Commands and expected output

```
CMAKE_PREFIX_PATH=/opt/occt-8.0.1 make build
./build/sxkernel/sxkernel_tests "[replan12]"
#   All tests passed (43 assertions in 3 test cases)
make test-kernel
#   All tests passed (7943 assertions in 333 test cases)       (was 7900 in 330)
export LD_LIBRARY_PATH=/opt/occt-8.0.1/lib
tools/godot/godot --headless --path game --script res://tests/run_rung01_replan12_fillet.gd
#   19 checks, 0 failures
```

The kernel log prints `[ERROR] fillet soft-skip: missing edge uuid …` lines while these tests run. They are the existing per-edge log for edges that did not resolve by id (they are re-found by `face_cues`); do not remove them.

**Red on `2606160c`** (kernel rebuilt from baseline sources): the Catch2 file does not compile; `run_rung01_replan12_fillet.gd` prints `19 checks, 6 failures`: `fillet params carry face_cues`, `top rim is rounded at z=13.9`, `the warning names the loss`, `one warning`, `graph_features names the warning`, `timeline row shows a warning badge`.

Also run, unchanged: `run_critic_walk_tests` (46/0: ordinary flows lose edges silently and the feature must stay), `run_rung01_fillet_tests` (30/0), `run_rung01_replan3_fillet` (60/0), `run_rung01_replan11_fillet_err` (8/0), `run_rung01_replan11_fillet_ui` (14/0), `run_rung01_replan11_slot` (9/0). The Godot extension must be rebuilt (`make build`) before any Godot suite, because `libsxcore.so` changed.

## Do not

- Make a lost edge fail the feature or the regenerate. A hard failure rolls back unrelated later edits and broke `run_critic_walk_tests` (4 failures) in the prototype.
- Add a migration for old documents or a second blend strategy.
- Change the 0.5 mm `match_edge_cue` gate or any radius limit.
- Edit the walk, the lint or the checker (WP7).

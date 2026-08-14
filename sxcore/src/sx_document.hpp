#pragma once
// SxDocument: the Godot-facing wrapper around the sxkernel Document plus its
// command stack. All ids cross the boundary as UUID strings.

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include <functional>
#include <memory>

#include "sx/command.hpp"
#include "sx/commands_basic.hpp"
#include "sx/document.hpp"

namespace sx_godot {

class SxDocument : public godot::RefCounted {
    GDCLASS(SxDocument, godot::RefCounted)

public:
    SxDocument();
    ~SxDocument() override = default;

    // --- creation (drag-and-drop palette) ---
    godot::String add_box(double dx, double dy, double dz, const godot::Vector3& origin);
    godot::String add_cylinder(double radius, double height, const godot::Vector3& origin);
    godot::String add_sphere(double radius, const godot::Vector3& origin);
    godot::String add_cone(double r1, double r2, double height, const godot::Vector3& origin);
    godot::String add_torus(double major_r, double minor_r, const godot::Vector3& origin);

    // --- sketch features ---
    // Extrudes the sketch's closed profile along its plane normal; returns the
    // new body's uuid ("" on failure).
    godot::String extrude_sketch(const godot::Ref<class SxSketch>& sketch, double distance,
                                 bool symmetric);
    godot::String revolve_sketch(const godot::Ref<class SxSketch>& sketch,
                                 const godot::Vector2& axis_point,
                                 const godot::Vector2& axis_dir, double angle);

    // --- editing ---
    bool delete_body(const godot::String& body_id);
    bool translate_body(const godot::String& body_id, const godot::Vector3& delta);
    bool push_pull(const godot::String& face_id, double distance);
    // op: "fuse" | "cut" | "common". Tool body is consumed unless keep_tool.
    bool boolean_op(const godot::String& target_body, const godot::String& tool_body,
                    const godot::String& op, bool keep_tool);
    bool fillet_edges(const godot::PackedStringArray& edge_ids, double radius);
    bool chamfer_edges(const godot::PackedStringArray& edge_ids, double distance);

    // --- transforms & patterns ---
    // Returns the new body's uuid ("" on failure).
    godot::String mirror_body(const godot::String& body_id, const godot::Vector3& plane_point,
                              const godot::Vector3& plane_normal, bool keep_original);
    // Returns uuids of the new copies (count includes the original).
    godot::PackedStringArray linear_pattern(const godot::String& body_id,
                                            const godot::Vector3& direction, double spacing,
                                            int count);
    godot::PackedStringArray circular_pattern(const godot::String& body_id,
                                              const godot::Vector3& axis_point,
                                              const godot::Vector3& axis_dir, int count,
                                              double total_angle);
    bool rotate_body(const godot::String& body_id, const godot::Vector3& axis_point,
                     const godot::Vector3& axis_dir, double angle);

    // --- shell / offset / draft ---
    bool shell_body(const godot::PackedStringArray& faces_to_remove, double thickness);
    bool offset_body(const godot::String& body_id, double offset);
    // angle_deg is converted to radians for the kernel. Pull direction and
    // neutral plane are in model space. Returns false without stacking on
    // invalid input or OCCT failure.
    bool draft_faces(const godot::PackedStringArray& face_ids, double angle_deg,
                     const godot::Vector3& pull_dir, const godot::Vector3& neutral_point,
                     const godot::Vector3& neutral_normal);

    // --- measurement ---
    // {distance: float, point_a: Vector3, point_b: Vector3} or {} on failure.
    godot::Dictionary measure_distance(const godot::String& a, const godot::String& b) const;
    // Closest point on `shape_id` to `from` — {distance, point_a, point_b} or {}.
    godot::Dictionary closest_point_on(const godot::String& shape_id,
                                       const godot::Vector3& from) const;
    // UV midpoint of a face in model space, or ZERO if invalid.
    godot::Vector3 face_midpoint(const godot::String& face_id) const;
    // {min: Vector3, max: Vector3} or {}.
    godot::Dictionary measure_bbox(const godot::String& id) const;
    // {volume, surface_area, center_of_mass: Vector3} or {}.
    godot::Dictionary measure_mass(const godot::String& body_id) const;
    double measure_edge_length(const godot::String& edge_id) const;
    double measure_face_area(const godot::String& face_id) const;
    // Radians; -1.0 when faces are not planar / invalid.
    double measure_face_angle(const godot::String& f1, const godot::String& f2) const;

    // --- interop ---
    bool export_step(const godot::String& path);
    bool export_stl(const godot::String& path, bool binary);
    // Returns uuids of imported bodies (empty on failure).
    godot::PackedStringArray import_step(const godot::String& path);
    godot::PackedStringArray import_stl(const godot::String& path);

    // --- undo/redo ---
    bool undo();
    bool redo();
    bool can_undo() const;
    bool can_redo() const;

    // --- queries ---
    godot::PackedStringArray body_ids() const;
    godot::String body_name(const godot::String& body_id) const;
    bool rename_body(const godot::String& body_id, const godot::String& name);
    bool set_body_color(const godot::String& body_id, const godot::Color& color);
    godot::Color get_body_color(const godot::String& body_id) const;
    bool set_body_material(const godot::String& body_id, const godot::String& material);
    godot::String body_material(const godot::String& body_id) const;
    godot::Array material_list() const;

    // --- configurations (named variable-table snapshots) ---
    bool save_configuration(const godot::String& name);
    bool activate_configuration(const godot::String& name);  // then regenerate
    bool remove_configuration(const godot::String& name);
    godot::Array configuration_list() const;
    godot::String active_configuration() const;
    double body_volume(const godot::String& body_id) const;
    uint64_t revision() const;

    // Tessellation: ArrayMesh with one surface per face; surface index order
    // matches get_face_ids(body_id).
    godot::Ref<godot::ArrayMesh> get_mesh(const godot::String& body_id) const;
    godot::PackedStringArray get_face_ids(const godot::String& body_id) const;
    godot::PackedStringArray get_edge_ids(const godot::String& body_id) const;
    // Edge wireframe as a Dictionary {edge_uuid: PackedVector3Array}.
    godot::Dictionary get_edge_lines(const godot::String& body_id) const;

    // Exact B-rep picking. Returns {} on miss, else
    // {body: String, face: String, point: Vector3, distance: float}.
    godot::Dictionary pick(const godot::Vector3& origin, const godot::Vector3& direction) const;

    // --- semantic cards ---
    godot::String card_markdown(const godot::String& entity_id) const;
    void set_card_alias(const godot::String& entity_id, const godot::String& text);
    void set_card_notes(const godot::String& entity_id, const godot::String& text);
    godot::String get_card_alias(const godot::String& entity_id) const;
    godot::String get_card_notes(const godot::String& entity_id) const;
    // Whole-document markdown bundle (timeline + bodies + cards) for AI use.
    godot::String export_context() const;

    // --- feature graph (parametric timeline) ---
    // Features are returned as Dictionaries {id, name, type, suppressed,
    // params (JSON string), output_body}. Graph mutations regenerate the
    // document immediately and are undoable (whole-graph snapshots).
    godot::Array graph_features() const;
    godot::String graph_add_primitive(const godot::String& kind, double a, double b, double c,
                                      const godot::Vector3& origin);
    godot::String graph_add_sketch(const godot::Ref<class SxSketch>& sketch);
    // Deep-copy of a Sketch feature's geometry (null Ref if missing / wrong type).
    godot::Ref<class SxSketch> graph_get_sketch(const godot::String& fid) const;
    // Replace a Sketch feature's geometry and regenerate dependents (undoable).
    bool graph_update_sketch(const godot::String& fid, const godot::Ref<class SxSketch>& sketch);
    // op: "new" | "fuse" | "cut"; target_fid required for fuse/cut.
    godot::String graph_add_extrude(const godot::String& sketch_fid, double distance,
                                    bool symmetric, const godot::String& op,
                                    const godot::String& target_fid,
                                    const godot::String& end = godot::String("blind"),
                                    double thin_thickness = 0.0,
                                    const godot::String& thin_type = godot::String("one_side"),
                                    bool flip_side = false,
                                    const godot::Array& selected_contours = godot::Array());
    // Axis in sketch 2D coordinates (point + direction on the sketch plane).
    godot::String graph_add_revolve(const godot::String& sketch_fid,
                                    const godot::Vector2& axis_point,
                                    const godot::Vector2& axis_dir, double angle,
                                    const godot::String& op, const godot::String& target_fid);
    // Sweep a sketch profile along a 3D polyline path (at least two points).
    godot::String graph_add_sweep(const godot::String& sketch_fid,
                                  const godot::PackedVector3Array& path);
    // Sweep along a Path feature (params rebuilt associatively from source sketches).
    godot::String graph_add_sweep_along_path(const godot::String& sketch_fid,
                                             const godot::String& path_fid,
                                             const godot::PackedStringArray& guide_fids = {});
    // Composite 3D path from two or more planar sketches (SW 3D-sketch substitute).
    // mode: "join_endpoints" | "bridge_spline" | "composite"
    godot::String graph_add_path(const godot::PackedStringArray& sketch_fids,
                                 const godot::String& mode);
    // Loft through two or more sketch profiles (each on its own plane).
    godot::String graph_add_loft(const godot::PackedStringArray& sketch_fids, bool ruled,
                                 const godot::PackedStringArray& guide_fids = {});
    // Dress-up features on a timeline body. Edge ids are converted to the
    // 1-based edge-map indices the graph stores.
    godot::String graph_add_fillet(const godot::String& target_fid,
                                   const godot::PackedStringArray& edge_ids, double radius);
    godot::String graph_add_chamfer(const godot::String& target_fid,
                                    const godot::PackedStringArray& edge_ids, double distance);
    // Drill a parametric hole into a timeline body's output. type:
    // "simple" | "counterbore" | "countersink". depth <= 0 = through-all.
    godot::String graph_add_hole(const godot::String& target_fid, const godot::String& type,
                                 const godot::Vector3& position, const godot::Vector3& direction,
                                 float diameter, float depth, float cb_diameter, float cb_depth,
                                 float cs_diameter, float cs_angle_deg);
    // Import a STEP solid as a timeline BASE feature (index 0, uniform scale).
    godot::String graph_add_import_step(const godot::String& path, float scale);
    // Import an STL mesh as a timeline BASE feature (uniform scale).
    godot::String graph_add_import_stl(const godot::String& path, float scale);
    // Body-level boolean on the timeline. op: "fuse" | "cut" | "common".
    // Target keeps the result; tool feature's body is consumed on regenerate.
    godot::String graph_add_boolean(const godot::String& op, const godot::String& target_fid,
                                    const godot::String& tool_fid);
    bool graph_set_params(const godot::String& fid, const godot::String& params_json);
    // Write feature params without regenerating geometry. Used after a live-body
    // translate/rotate so the timeline placement stays in sync without rebuilding
    // (and undoing) committed BREP edits.
    bool graph_set_params_no_regen(const godot::String& fid, const godot::String& params_json);
    bool graph_set_suppressed(const godot::String& fid, bool suppressed);
    bool graph_remove(const godot::String& fid);
    bool graph_move(const godot::String& fid, int new_index);
    bool graph_rename(const godot::String& fid, const godot::String& name);
    // Rollback bar: features at timeline position >= index are skipped during
    // regenerate. index = -1 (or the timeline size) rolls to end. Undoable.
    bool graph_set_rollback(int index);
    int graph_rollback() const;
    // Returns {ok: bool, error: String}.
    godot::Dictionary graph_regenerate();

    // --- variables (equations table) ---
    // Upsert / remove a named expression. Both go through apply_graph_edit so
    // they regenerate and are undoable (the table serializes with the graph).
    // remove_variable keeps the removal even if regenerate fails (features may
    // still reference the name); inspect via graph_regenerate / undo.
    bool set_variable(const godot::String& name, const godot::String& expr);
    bool remove_variable(const godot::String& name);
    // Array of {name, expr, value (float; NAN on error), error: String}.
    godot::Array list_variables() const;

    // --- persistence ---
    bool save(const godot::String& path);
    bool load(const godot::String& path);
    // Multi-doc Insert Components: deep-copy bodies from an external .sxp and
    // place an instance of each. Returns {ok, error, body_ids, instance_ids}.
    // First instance into an empty assembly is Fixed (SolidWorks default).
    godot::Dictionary insert_sxp(const godot::String& path, const godot::Vector3& translation);

    // --- datums (reference geometry) ---
    godot::String add_datum_plane(const godot::Vector3& point, const godot::Vector3& normal);
    godot::String add_datum_axis(const godot::Vector3& point, const godot::Vector3& dir);
    godot::String add_datum_point(const godot::Vector3& p);
    godot::Array datum_list() const;
    bool remove_datum(const godot::String& id);

    // --- instances (assembly placements; direct doc mutation, not undoable v1) ---
    // rotation_axis + rotation_angle_deg are converted to a unit quaternion for
    // the kernel. Bump revision happens in the kernel.
    godot::String add_instance(const godot::String& source_body, const godot::Vector3& translation,
                               const godot::Vector3& rotation_axis, double rotation_angle_deg,
                               const godot::String& name);
    // Array of {id, source_body, name, translation, rotation_axis, rotation_angle_deg,
    //           fixed, source_path}.
    godot::Array instance_list() const;
    bool remove_instance(const godot::String& id);
    bool set_instance_transform(const godot::String& id, const godot::Vector3& translation,
                                const godot::Vector3& rotation_axis, double rotation_angle_deg);
    // Fix/Float restraint (SolidWorks Video 6). Fixed instances refuse drag.
    bool set_instance_fixed(const godot::String& id, bool fixed);

    // --- assembly mates (closed-form placement; solve moves instance_b) ---
    // type: "fixed" | "plane_coincident" | "plane_parallel" | "concentric" | "fastened".
    // instance_a may be "" for a grounded body reference. Returns the mate id or "".
    godot::String add_mate(const godot::String& type, const godot::String& instance_a,
                           const godot::String& face_a, const godot::String& instance_b,
                           const godot::String& face_b, double offset, bool flip,
                           const godot::String& name);
    // Array of {id, type, instance_a, face_a, instance_b, face_b, offset, flip, name}.
    godot::Array mate_list() const;
    bool remove_mate(const godot::String& id);
    // Applies all mates in order; true when every mate solved.
    bool solve_mates();

    // Implicit Onshape-style connector on a face (empty dict if not planar/cyl).
    godot::Dictionary implicit_connector(const godot::String& instance,
                                         const godot::String& face) const;
    godot::Array connector_list() const;

    // DOF joints on connectors: the two picked faces become the joint frames.
    godot::String add_joint(const godot::String& type, const godot::String& instance_a,
                            const godot::String& face_a, const godot::String& instance_b,
                            const godot::String& face_b, const godot::String& name);
    godot::Array joint_list() const;
    bool remove_joint(const godot::String& id);
    // Drives the free degree of freedom (radians or mm) and re-poses the part.
    bool set_joint_value(const godot::String& id, double value);
    int solve_joints();

    // Exploded view: factor 0 collapses back to the assembled placement.
    int explode_assembly(double factor);
    bool is_exploded() const;
    // Copies a component around its joint axis; each copy inherits the joint.
    godot::PackedStringArray pattern_instance(const godot::String& instance, int count,
                                              double total_angle);

    godot::String graph_add_extrude_end(const godot::String& sketch_fid, double distance,
                                        const godot::String& end, const godot::String& op,
                                        const godot::String& target_fid);
    godot::String graph_add_fillet_var(const godot::String& target_fid,
                                       const godot::PackedStringArray& edge_ids, double radius,
                                       double radius2);
    godot::String graph_add_direct_edit(const godot::String& target_fid, const godot::String& kind,
                                        const godot::String& face_id, double distance,
                                        const godot::Vector3& direction);
    godot::String graph_add_holes(const godot::String& target_fid, const godot::String& type,
                                  const godot::PackedVector3Array& positions,
                                  const godot::Vector3& direction, float diameter, float depth,
                                  float cb_diameter, float cb_depth, float cs_diameter,
                                  float cs_angle_deg);
    godot::String graph_add_shell(const godot::String& target_fid,
                                  const godot::PackedStringArray& face_ids, double thickness);
    godot::String graph_add_helix(float profile_radius, float helix_radius, float pitch,
                                  float turns, bool left_handed, const godot::Vector3& axis_point,
                                  const godot::Vector3& axis_dir);
    double interference_volume(const godot::String& body_a, const godot::String& body_b) const;
    godot::String import_dxf(const godot::String& path);
    bool export_3mf(const godot::String& path);
    bool export_gltf(const godot::String& path);
    godot::String heal_report(const godot::String& fid) const;

    godot::String graph_add_rib(const godot::String& target_fid, const godot::String& sketch_fid,
                                double thickness, double height, bool flip);
    godot::String graph_add_flange(double length, double thickness, double k_factor, double radius,
                                   double width);
    godot::String graph_add_frame(const godot::PackedVector3Array& path, double profile_w,
                                  double profile_h);
    godot::Array run_query(const godot::String& query) const;
    godot::String card_digest(const godot::String& fid) const;
    int apply_rule(const godot::String& when, const godot::String& then);
    double crank_slider_x(double crank, double rod, double theta) const;
    double sheet_flat_length(double leg1, double leg2, double thickness, double k_factor,
                             double radius) const;
    godot::PackedVector3Array cam_pocket(double x0, double y0, double x1, double y1, double depth,
                                         double stepover) const;
    double fea_cantilever(double force_n, double length_mm, double e_mpa, double width_mm,
                          double thickness_mm) const;
    godot::Dictionary catalog_fastener(const godot::String& designation) const;

    // Three-view (front/top/right) HLR drawing sheet as SVG. False when the
    // document has no bodies or the file cannot be written.
    bool export_drawing_svg(const godot::String& path, double scale);

    // --- in-context snapshots ---
    godot::String capture_context(const godot::String& source_body, const godot::String& name);
    bool is_context_stale(const godot::String& context_id) const;
    bool update_context(const godot::String& context_id);
    godot::String graph_add_in_context(const godot::String& context_id, double a, double b);
    godot::Array context_list() const;

    // --- drawing document ---
    godot::String ensure_drawing_sheet();
    godot::String add_drawing_dim(const godot::String& entity_a, const godot::String& entity_b);
    int refresh_drawing_dims();
    godot::Array bom_rows() const;
    godot::Dictionary drawing_preview() const;
    bool export_drawing_dxf(const godot::String& path);
    bool export_drawing_pdf(const godot::String& path);

    // --- sheet convert / welds ---
    godot::String graph_add_convert_sheet(const godot::String& target_fid);
    godot::String add_weld(const godot::String& edge, const godot::String& symbol, double size);
    godot::Array weld_list() const;

    // --- queries / What's Wrong ---
    godot::Dictionary diagnose_feature(const godot::String& fid) const;
    int auto_dimension();
    godot::Array propose_chips() const;
    godot::String graph_add_user_csink(const godot::String& target_fid, const godot::Vector3& pos,
                                       double diameter, double depth, double cs_diameter);
    godot::String add_sketch3d(const godot::PackedVector3Array& points);
    int convert_edges(const godot::String& sketch_fid, const godot::PackedStringArray& edge_ids);
    int pdm_commit(const godot::String& message);
    godot::Array pdm_log() const;

    // --- print-first ---
    godot::Dictionary print_analyze(const godot::String& body_id);
    godot::Dictionary print_orient(const godot::String& body_id);
    godot::Dictionary print_setup() const;
    void set_print_min_wall(double mm);

protected:
    static void _bind_methods();

private:
    godot::String add_primitive(sx::PrimitiveType type, double a, double b, double c,
                                const godot::Vector3& origin);
    bool apply_graph_edit(const std::string& label, const std::function<bool()>& mutate);
    godot::String graph_add_dressup(bool fillet, const godot::String& target_fid,
                                    const godot::PackedStringArray& edge_ids, double value);

    std::unique_ptr<sx::Document> doc_;
    // Feature blamed for the most recent failed regenerate (empty when the
    // last graph operation succeeded). Surfaced as failed/error flags in
    // graph_features() so the timeline can badge the offending row.
    std::string last_failed_fid_;
    std::string last_graph_error_;
    sx::CommandStack stack_;
};

}  // namespace sx_godot

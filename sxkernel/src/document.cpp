#include "sx/document.hpp"

#include <TopExp.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>

#include <algorithm>
#include <cmath>
#include <sstream>
#include <type_traits>

#include "sx/cards.hpp"
#include "sx/features.hpp"
#include "sx/materials.hpp"
#include "sx/naming.hpp"
#include "sx/shape_utils.hpp"

namespace sx {
namespace {

constexpr double kDatumEps = 1e-12;

std::array<double, 3> normalize3(const std::array<double, 3>& v) {
    const double len = std::sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (len < kDatumEps) return {0, 0, 0};
    return {v[0] / len, v[1] / len, v[2] / len};
}

std::array<double, 3> cross3(const std::array<double, 3>& a,
                             const std::array<double, 3>& b) {
    return {a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0]};
}

// Arbitrary unit vector in the plane perpendicular to `n` (assumed unit).
std::array<double, 3> plane_x_dir(const std::array<double, 3>& n) {
    const std::array<double, 3> ref =
        (std::abs(n[0]) < 0.9) ? std::array<double, 3>{1, 0, 0}
                               : std::array<double, 3>{0, 1, 0};
    return normalize3(cross3(ref, n));
}

EntityId datum_entity_id(const Datum& d) {
    return std::visit([](const auto& x) { return x.id; }, d);
}

std::string format_vec3(const std::array<double, 3>& v) {
    std::ostringstream os;
    os << '(' << v[0] << ", " << v[1] << ", " << v[2] << ')';
    return os.str();
}

}  // namespace

Document::Document()
    : cards_(std::make_unique<CardRegistry>()),
      graph_(std::make_unique<FeatureGraph>()) {
    // Wave 6.2: seed built-in print/config variables for new documents (mm).
    // These are user-editable and serialize with the graph.
    // Do this only for fresh documents; loaders use restore paths that replace the graph.
    try {
        // Only seed when empty to avoid clobbering programmatic construction in tests
        // that immediately set variables before regeneration.
        if (graph_->variables().entries().empty()) {
            graph_->variables().set("clearance", "0.3");
            graph_->variables().set("hole_compensation", "0.2");
            graph_->variables().set("layer", "0.2");
            graph_->variables().set("nozzle", "0.4");
            graph_->variables().set("jaw_af", "10");
        }
    } catch (...) {
        // Never throw from constructor — variables are best-effort seeds.
    }
}
Document::~Document() = default;

void Document::set_graph(FeatureGraph g) {
    graph_ = std::make_unique<FeatureGraph>(std::move(g));
    bump_revision();
}

static const std::array<std::pair<EntityKind, TopAbs_ShapeEnum>, 3> kSubKinds = {{
    {EntityKind::Face, TopAbs_FACE},
    {EntityKind::Edge, TopAbs_EDGE},
    {EntityKind::Vertex, TopAbs_VERTEX},
}};

EntityId Document::add_body(const TopoDS_Shape& shape, const std::string& name,
                            const EntityId& keep_id) {
    auto b = std::make_unique<Body>();
    b->id = keep_id.is_null() ? EntityId::generate() : keep_id;
    b->name = name;
    b->shape = shape;
    register_subshapes(*b, /*fresh_ids=*/true);

    Body* raw = b.get();
    body_index_[b->id] = bodies_.size();
    bodies_.push_back(std::move(b));
    regenerate_cards_for_body(*raw);
    bump_revision();
    return raw->id;
}

void Document::restore_body(Body&& body) {
    auto b = std::make_unique<Body>(std::move(body));
    register_subshapes(*b, /*fresh_ids=*/false);
    Body* raw = b.get();
    body_index_[b->id] = bodies_.size();
    bodies_.push_back(std::move(b));
    regenerate_cards_for_body(*raw);
    bump_revision();
}

void Document::replace_body_shape(const EntityId& body_id, const TopoDS_Shape& shape) {
    Body* b = body_mut(body_id);
    if (!b) return;
    // Topological naming: geometrically match new subshapes against the old
    // shape so surviving faces/edges/vertices keep their EntityIds (and
    // therefore their cards, aliases, and selections).
    auto match = naming::match_subshapes(b->shape, b->subshape_ids, shape);
    last_released_ = match.released;
    for (const auto& [kind, ids] : b->subshape_ids)
        for (const auto& id : ids) subshape_index_.erase(id);
    for (const auto& id : match.released) cards_->erase(id);
    b->shape = shape;
    b->subshape_ids = std::move(match.ids);
    register_subshapes(*b, /*fresh_ids=*/false);
    regenerate_cards_for_body(*b);
    bump_revision();
}

bool Document::set_body_material(const EntityId& body_id, const std::string& material) {
    Body* b = body_mut(body_id);
    if (!b || !materials::find(material)) return false;
    b->material = material;
    bump_revision();
    return true;
}

bool Document::rename_body(const EntityId& body_id, const std::string& name) {
    Body* b = body_mut(body_id);
    if (!b) return false;
    b->name = name;
    regenerate_cards_for_body(*b);  // upsert preserves aliases/notes
    bump_revision();
    return true;
}

bool Document::remove_body(const EntityId& body_id) {
    auto it = body_index_.find(body_id);
    if (it == body_index_.end()) return false;
    // Cascade: drop every instance whose source is this body.
    {
        std::vector<EntityId> orphaned;
        for (const auto& inst : instances_) {
            if (inst.source_body == body_id) orphaned.push_back(inst.id);
        }
        for (const auto& id : orphaned) remove_instance(id);
    }
    size_t idx = it->second;
    unregister_body_entities(*bodies_[idx]);
    cards_->erase(body_id);
    bodies_.erase(bodies_.begin() + static_cast<long>(idx));
    body_index_.erase(it);
    // Reindex the remaining bodies.
    for (size_t i = idx; i < bodies_.size(); ++i) body_index_[bodies_[i]->id] = i;
    bump_revision();
    return true;
}

const Body* Document::body(const EntityId& id) const {
    auto it = body_index_.find(id);
    return it == body_index_.end() ? nullptr : bodies_[it->second].get();
}

Body* Document::body_mut(const EntityId& id) {
    auto it = body_index_.find(id);
    return it == body_index_.end() ? nullptr : bodies_[it->second].get();
}

std::vector<EntityId> Document::body_ids() const {
    std::vector<EntityId> out;
    out.reserve(bodies_.size());
    for (const auto& b : bodies_) out.push_back(b->id);
    return out;
}

std::optional<SubshapeRef> Document::find_subshape(const EntityId& id) const {
    auto it = subshape_index_.find(id);
    if (it == subshape_index_.end()) return std::nullopt;
    return it->second;
}

TopoDS_Shape Document::resolve(const EntityId& id) const {
    if (const Body* b = body(id)) return b->shape;
    auto ref = find_subshape(id);
    if (!ref) return {};
    const Body* b = body(ref->body);
    if (!b) return {};
    TopAbs_ShapeEnum occt_kind = TopAbs_FACE;
    for (const auto& [kind, abs] : kSubKinds)
        if (kind == ref->kind) occt_kind = abs;
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(b->shape, occt_kind, map);
    if (ref->index < 1 || ref->index > map.Extent()) return {};
    return map(ref->index);
}

std::optional<EntityId> Document::owning_body(const EntityId& id) const {
    if (body(id)) return id;
    auto ref = find_subshape(id);
    if (!ref) return std::nullopt;
    return ref->body;
}

EntityId Document::subshape_id(const EntityId& body_id, EntityKind kind, int index1) const {
    const Body* b = body(body_id);
    if (!b) return {};
    auto found = b->subshape_ids.find(kind);
    if (found == b->subshape_ids.end()) return {};
    if (index1 < 1 || static_cast<size_t>(index1) > found->second.size()) return {};
    return found->second[static_cast<size_t>(index1 - 1)];
}

void Document::register_subshapes(Body& b, bool fresh_ids) {
    for (const auto& [kind, abs] : kSubKinds) {
        TopTools_IndexedMapOfShape map;
        TopExp::MapShapes(b.shape, abs, map);
        auto& ids = b.subshape_ids[kind];
        if (fresh_ids || static_cast<int>(ids.size()) != map.Extent()) {
            ids.clear();
            ids.reserve(static_cast<size_t>(map.Extent()));
            for (int i = 0; i < map.Extent(); ++i) ids.push_back(EntityId::generate());
        }
        for (int i = 1; i <= map.Extent(); ++i) {
            subshape_index_[ids[static_cast<size_t>(i - 1)]] =
                SubshapeRef{b.id, kind, i};
        }
    }
}

void Document::unregister_body_entities(const Body& b) {
    for (const auto& [kind, ids] : b.subshape_ids) {
        for (const auto& id : ids) {
            subshape_index_.erase(id);
            cards_->erase(id);
        }
    }
}

void Document::regenerate_cards_for_body(const Body& b) {
    Card bc;
    bc.id = b.id;
    bc.kind = EntityKind::Body;
    bc.title = b.name;
    auto tc = shape::count(b.shape);
    bc.digest = "solid body `" + b.name + "` with " + std::to_string(tc.faces) +
                " faces, " + std::to_string(tc.edges) + " edges, volume " +
                std::to_string(shape::volume(b.shape)) + " mm^3";
    cards_->upsert(std::move(bc));

    // Face cards (edges/vertices get cards lazily later; faces are the primary
    // selectable for the drag-and-drop phase).
    TopTools_IndexedMapOfShape faces;
    TopExp::MapShapes(b.shape, TopAbs_FACE, faces);
    const auto& face_ids = b.subshape_ids.at(EntityKind::Face);
    for (int i = 1; i <= faces.Extent(); ++i) {
        Card fc;
        fc.id = face_ids[static_cast<size_t>(i - 1)];
        fc.kind = EntityKind::Face;
        fc.title = "Face " + std::to_string(i) + " of " + b.name;
        fc.digest = shape::describe_face(faces(i));
        fc.relations = {b.id};
        cards_->upsert(std::move(fc));
    }

    // Adjacency: faces that share an edge become card relations (and feed
    // adjacent-to= queries / the selection-card digest).
    TopTools_IndexedDataMapOfShapeListOfShape edge_faces;
    TopExp::MapShapesAndAncestors(b.shape, TopAbs_EDGE, TopAbs_FACE, edge_faces);
    for (int i = 1; i <= faces.Extent(); ++i) {
        const EntityId face_id = face_ids[static_cast<size_t>(i - 1)];
        Card* fc = cards_->find_mut(face_id);
        if (!fc) continue;
        TopTools_IndexedMapOfShape my_edges;
        TopExp::MapShapes(faces(i), TopAbs_EDGE, my_edges);
        for (int e = 1; e <= my_edges.Extent(); ++e) {
            if (!edge_faces.Contains(my_edges(e))) continue;
            const TopTools_ListOfShape& nbrs = edge_faces.FindFromKey(my_edges(e));
            for (const TopoDS_Shape& n : nbrs) {
                const int fi = faces.FindIndex(n);
                if (fi < 1 || fi == i) continue;
                const EntityId nid = face_ids[static_cast<size_t>(fi - 1)];
                if (std::find(fc->relations.begin(), fc->relations.end(), nid) ==
                    fc->relations.end())
                    fc->relations.push_back(nid);
            }
        }
    }
}

void Document::index_datum(Datum&& d) {
    const EntityId id = datum_entity_id(d);
    datum_index_[id] = datums_.size();
    datums_.push_back(std::move(d));
    bump_revision();
}

void Document::upsert_card_for_datum(const Datum& d) {
    Card c;
    std::visit(
        [&](const auto& x) {
            using T = std::decay_t<decltype(x)>;
            c.id = x.id;
            c.title = x.name;
            if constexpr (std::is_same_v<T, DatumPlane>) {
                c.kind = EntityKind::DatumPlane;
                c.digest = "datum plane origin " + format_vec3(x.origin) +
                           " normal " + format_vec3(x.normal);
            } else if constexpr (std::is_same_v<T, DatumAxis>) {
                c.kind = EntityKind::DatumAxis;
                c.digest = "datum axis point " + format_vec3(x.point) +
                           " direction " + format_vec3(x.direction);
            } else if constexpr (std::is_same_v<T, DatumPoint>) {
                c.kind = EntityKind::DatumPoint;
                c.digest = "datum point position " + format_vec3(x.position);
            }
        },
        d);
    cards_->upsert(std::move(c));
}

void Document::ensure_datum_cards() {
    for (const auto& d : datums_) upsert_card_for_datum(d);
}

EntityId Document::add_datum_plane(const std::array<double, 3>& origin,
                                   const std::array<double, 3>& normal,
                                   const EntityId& keep_id) {
    DatumPlane p;
    p.id = keep_id.is_null() ? EntityId::generate() : keep_id;
    p.name = "Datum Plane " + std::to_string(++datum_plane_seq_);
    p.origin = origin;
    p.normal = normalize3(normal);
    if (p.normal[0] == 0 && p.normal[1] == 0 && p.normal[2] == 0)
        p.normal = {0, 0, 1};
    p.x_dir = plane_x_dir(p.normal);
    const EntityId id = p.id;
    Datum stored{std::move(p)};
    upsert_card_for_datum(stored);
    index_datum(std::move(stored));
    return id;
}

EntityId Document::add_datum_axis(const std::array<double, 3>& point,
                                  const std::array<double, 3>& direction,
                                  const EntityId& keep_id) {
    DatumAxis a;
    a.id = keep_id.is_null() ? EntityId::generate() : keep_id;
    a.name = "Datum Axis " + std::to_string(++datum_axis_seq_);
    a.point = point;
    a.direction = normalize3(direction);
    if (a.direction[0] == 0 && a.direction[1] == 0 && a.direction[2] == 0)
        a.direction = {0, 0, 1};
    const EntityId id = a.id;
    Datum stored{std::move(a)};
    upsert_card_for_datum(stored);
    index_datum(std::move(stored));
    return id;
}

EntityId Document::add_datum_point(const std::array<double, 3>& position,
                                   const EntityId& keep_id) {
    DatumPoint p;
    p.id = keep_id.is_null() ? EntityId::generate() : keep_id;
    p.name = "Datum Point " + std::to_string(++datum_point_seq_);
    p.position = position;
    const EntityId id = p.id;
    Datum stored{std::move(p)};
    upsert_card_for_datum(stored);
    index_datum(std::move(stored));
    return id;
}

bool Document::remove_datum(const EntityId& id) {
    auto it = datum_index_.find(id);
    if (it == datum_index_.end()) return false;
    const size_t idx = it->second;
    datums_.erase(datums_.begin() + static_cast<long>(idx));
    datum_index_.erase(it);
    cards_->erase(id);
    for (size_t i = idx; i < datums_.size(); ++i)
        datum_index_[datum_entity_id(datums_[i])] = i;
    bump_revision();
    return true;
}

void Document::restore_datum(Datum&& d) {
    upsert_card_for_datum(d);
    index_datum(std::move(d));
}

EntityId Document::add_instance(const EntityId& source_body,
                                const std::array<double, 3>& translation,
                                const std::array<double, 4>& rotation_quat,
                                const std::string& name) {
    if (!body(source_body)) return {};
    Instance inst;
    inst.id = EntityId::generate();
    inst.source_body = source_body;
    inst.translation = translation;
    inst.rotation_quat = rotation_quat;
    inst.name = name;
    const EntityId id = inst.id;
    instance_index_[id] = instances_.size();
    instances_.push_back(std::move(inst));
    bump_revision();
    return id;
}

bool Document::remove_instance(const EntityId& id) {
    auto it = instance_index_.find(id);
    if (it == instance_index_.end()) return false;
    // Cascade: mates referencing a removed instance are meaningless.
    std::erase_if(mates_, [&](const Mate& m) {
        return m.instance_a == id || m.instance_b == id;
    });
    const size_t idx = it->second;
    instances_.erase(instances_.begin() + static_cast<long>(idx));
    instance_index_.erase(it);
    for (size_t i = idx; i < instances_.size(); ++i)
        instance_index_[instances_[i].id] = i;
    bump_revision();
    return true;
}

bool Document::set_instance_transform(const EntityId& id,
                                      const std::array<double, 3>& translation,
                                      const std::array<double, 4>& rotation_quat) {
    auto it = instance_index_.find(id);
    if (it == instance_index_.end()) return false;
    Instance& inst = instances_[it->second];
    if (inst.fixed) return false;  // Fix restraint: refuse drag / transform edits
    inst.translation = translation;
    inst.rotation_quat = rotation_quat;
    bump_revision();
    return true;
}

bool Document::set_instance_fixed(const EntityId& id, bool fixed) {
    Instance* inst = instance_mut(id);
    if (!inst) return false;
    if (inst->fixed == fixed) return true;
    inst->fixed = fixed;
    if (fixed) {
        // Upsert a Fixed mate so solve_mates keeps this instance put.
        bool has_fixed = false;
        for (const auto& m : mates_) {
            if (m.type == MateType::Fixed && m.instance_b == id) {
                has_fixed = true;
                break;
            }
        }
        if (!has_fixed) {
            Mate m;
            m.type = MateType::Fixed;
            m.instance_b = id;
            m.name = "Fixed";
            add_mate(std::move(m));
        }
    } else {
        std::vector<EntityId> drop;
        for (const auto& m : mates_) {
            if (m.type == MateType::Fixed && m.instance_b == id) drop.push_back(m.id);
        }
        for (const auto& mid : drop) remove_mate(mid);
    }
    bump_revision();
    return true;
}

bool Document::set_instance_source_path(const EntityId& id, const std::string& path) {
    Instance* inst = instance_mut(id);
    if (!inst) return false;
    inst->source_path = path;
    bump_revision();
    return true;
}

const Instance* Document::instance(const EntityId& id) const {
    auto it = instance_index_.find(id);
    return it == instance_index_.end() ? nullptr : &instances_[it->second];
}

Instance* Document::instance_mut(const EntityId& id) {
    auto it = instance_index_.find(id);
    return it == instance_index_.end() ? nullptr : &instances_[it->second];
}

void Document::restore_instance(Instance&& inst) {
    instance_index_[inst.id] = instances_.size();
    instances_.push_back(std::move(inst));
    bump_revision();
}

EntityId Document::add_mate(Mate m) {
    if (m.type != MateType::Fixed || !m.instance_b.is_null()) {
        if (!instance(m.instance_b)) return {};
    }
    // Concentric is a radial fit constraint: callers must declare a positive
    // clearance up front. Enclosure / geometry checks run on apply.
    if (m.type == MateType::Concentric && m.offset <= 0.0) return {};
    if (m.id.is_null()) m.id = EntityId::generate();
    if (m.name.empty())
        m.name = std::string(to_string(m.type)) + " " + std::to_string(mates_.size() + 1);
    const EntityId id = m.id;
    mates_.push_back(std::move(m));
    bump_revision();
    return id;
}

bool Document::remove_mate(const EntityId& id) {
    for (size_t i = 0; i < mates_.size(); ++i) {
        if (mates_[i].id == id) {
            mates_.erase(mates_.begin() + static_cast<long>(i));
            bump_revision();
            return true;
        }
    }
    return false;
}

void Document::restore_mate(Mate&& m) {
    mates_.push_back(std::move(m));
    bump_revision();
}

EntityId Document::add_connector(MateConnector c) {
    if (c.id.is_null()) c.id = EntityId::generate();
    if (c.name.empty())
        c.name = "Connector " + std::to_string(connectors_.size() + 1);
    const EntityId id = c.id;
    connectors_.push_back(std::move(c));
    bump_revision();
    return id;
}

bool Document::remove_connector(const EntityId& id) {
    for (size_t i = 0; i < connectors_.size(); ++i) {
        if (connectors_[i].id == id) {
            connectors_.erase(connectors_.begin() + static_cast<long>(i));
            bump_revision();
            return true;
        }
    }
    return false;
}

void Document::restore_connector(MateConnector&& c) {
    connectors_.push_back(std::move(c));
    bump_revision();
}

EntityId Document::add_joint(Joint j) {
    if (!instance(j.b.instance)) return {};
    if (j.id.is_null()) j.id = EntityId::generate();
    if (j.name.empty())
        j.name = std::string(to_string(j.type)) + " " + std::to_string(joints_.size() + 1);
    const EntityId id = j.id;
    joints_.push_back(std::move(j));
    bump_revision();
    return id;
}

bool Document::remove_joint(const EntityId& id) {
    for (size_t i = 0; i < joints_.size(); ++i) {
        if (joints_[i].id == id) {
            joints_.erase(joints_.begin() + static_cast<long>(i));
            bump_revision();
            return true;
        }
    }
    return false;
}

bool Document::set_joint_value(const EntityId& id, double value) {
    for (auto& j : joints_) {
        if (j.id != id) continue;
        j.value = j.has_limits ? std::clamp(value, j.limit_min, j.limit_max) : value;
        bump_revision();
        return true;
    }
    return false;
}

const Joint* Document::joint(const EntityId& id) const {
    for (const auto& j : joints_) {
        if (j.id == id) return &j;
    }
    return nullptr;
}

void Document::restore_joint(Joint&& j) {
    joints_.push_back(std::move(j));
    bump_revision();
}

Document::Configuration* find_configuration(std::vector<Document::Configuration>& configs,
                                            const std::string& name) {
    for (auto& c : configs) {
        if (c.name == name) return &c;
    }
    return nullptr;
}

bool Document::save_configuration(const std::string& name) {
    if (name.empty()) return false;
    Configuration snapshot{name, graph_->variables().entries()};
    if (Configuration* existing = find_configuration(configurations_, name)) {
        *existing = std::move(snapshot);
    } else {
        configurations_.push_back(std::move(snapshot));
    }
    active_configuration_ = name;
    bump_revision();
    return true;
}

bool Document::activate_configuration(const std::string& name) {
    Configuration* c = find_configuration(configurations_, name);
    if (!c) return false;
    VariableTable table;
    for (const auto& [var, expr] : c->variables) table.set(var, expr);
    graph_->variables() = std::move(table);
    active_configuration_ = name;
    bump_revision();
    return true;
}

bool Document::remove_configuration(const std::string& name) {
    for (auto it = configurations_.begin(); it != configurations_.end(); ++it) {
        if (it->name == name) {
            configurations_.erase(it);
            if (active_configuration_ == name) active_configuration_.clear();
            bump_revision();
            return true;
        }
    }
    return false;
}

void Document::restore_configuration(Configuration&& c, bool active) {
    if (active) active_configuration_ = c.name;
    if (Configuration* existing = find_configuration(configurations_, c.name)) {
        *existing = std::move(c);
    } else {
        configurations_.push_back(std::move(c));
    }
}

EntityId Document::add_context(ContextSnapshot snap) {
    if (snap.id.is_null()) snap.id = EntityId::generate();
    if (snap.name.empty()) snap.name = "Context " + std::to_string(contexts_.size() + 1);
    const EntityId id = snap.id;
    contexts_.push_back(std::move(snap));
    bump_revision();
    return id;
}

bool Document::remove_context(const EntityId& id) {
    for (size_t i = 0; i < contexts_.size(); ++i) {
        if (contexts_[i].id == id) {
            contexts_.erase(contexts_.begin() + static_cast<long>(i));
            bump_revision();
            return true;
        }
    }
    return false;
}

const ContextSnapshot* Document::context(const EntityId& id) const {
    for (const auto& c : contexts_)
        if (c.id == id) return &c;
    return nullptr;
}

ContextSnapshot* Document::context_mut(const EntityId& id) {
    for (auto& c : contexts_)
        if (c.id == id) return &c;
    return nullptr;
}

void Document::restore_context(ContextSnapshot&& c) {
    contexts_.push_back(std::move(c));
    bump_revision();
}

EntityId Document::add_drawing_sheet(DrawingSheetDoc sheet) {
    if (sheet.id.is_null()) sheet.id = EntityId::generate();
    const EntityId id = sheet.id;
    drawing_sheets_.push_back(std::move(sheet));
    bump_revision();
    return id;
}

bool Document::remove_drawing_sheet(const EntityId& id) {
    for (size_t i = 0; i < drawing_sheets_.size(); ++i) {
        if (drawing_sheets_[i].id == id) {
            drawing_sheets_.erase(drawing_sheets_.begin() + static_cast<long>(i));
            bump_revision();
            return true;
        }
    }
    return false;
}

const DrawingSheetDoc* Document::drawing_sheet(const EntityId& id) const {
    for (const auto& s : drawing_sheets_)
        if (s.id == id) return &s;
    return nullptr;
}

DrawingSheetDoc* Document::drawing_sheet_mut(const EntityId& id) {
    for (auto& s : drawing_sheets_)
        if (s.id == id) return &s;
    return nullptr;
}

void Document::restore_drawing_sheet(DrawingSheetDoc&& s) {
    drawing_sheets_.push_back(std::move(s));
    bump_revision();
}

EntityId Document::add_weld(CosmeticWeld w) {
    if (w.id.is_null()) w.id = EntityId::generate();
    const EntityId id = w.id;
    welds_.push_back(std::move(w));
    bump_revision();
    return id;
}

bool Document::remove_weld(const EntityId& id) {
    for (size_t i = 0; i < welds_.size(); ++i) {
        if (welds_[i].id == id) {
            welds_.erase(welds_.begin() + static_cast<long>(i));
            bump_revision();
            return true;
        }
    }
    return false;
}

void Document::restore_weld(CosmeticWeld&& w) {
    welds_.push_back(std::move(w));
    bump_revision();
}

EntityId Document::add_sketch3d(Sketch3D s) {
    if (s.id.is_null()) s.id = EntityId::generate();
    if (s.name.empty()) s.name = "3D Sketch " + std::to_string(sketches3d_.size() + 1);
    const EntityId id = s.id;
    sketches3d_.push_back(std::move(s));
    bump_revision();
    return id;
}

bool Document::remove_sketch3d(const EntityId& id) {
    for (size_t i = 0; i < sketches3d_.size(); ++i) {
        if (sketches3d_[i].id == id) {
            sketches3d_.erase(sketches3d_.begin() + static_cast<long>(i));
            bump_revision();
            return true;
        }
    }
    return false;
}

const Sketch3D* Document::sketch3d(const EntityId& id) const {
    for (const auto& s : sketches3d_)
        if (s.id == id) return &s;
    return nullptr;
}

void Document::restore_sketch3d(Sketch3D&& s) {
    sketches3d_.push_back(std::move(s));
    bump_revision();
}

void Document::add_pdm_entry(const std::string& message) {
    pdm_.emplace_back(message, revision_);
    bump_revision();
}

void Document::restore_pdm(std::vector<std::pair<std::string, uint64_t>> entries) {
    pdm_ = std::move(entries);
}

void Document::set_print_setup(PrintSetup s) {
    print_setup_ = std::move(s);
    bump_revision();
}

void Document::restore_print_setup(PrintSetup s) {
    print_setup_ = std::move(s);
}

}  // namespace sx

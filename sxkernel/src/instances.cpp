#include "sx/instances.hpp"

#include <cmath>

#include <TopLoc_Location.hxx>
#include <gp_Quaternion.hxx>
#include <gp_Vec.hxx>

#include "sx/document.hpp"

namespace sx {
namespace {

constexpr double kEps = 1e-12;

nlohmann::json arr3_to_json(const std::array<double, 3>& v) {
    return nlohmann::json::array({v[0], v[1], v[2]});
}

nlohmann::json arr4_to_json(const std::array<double, 4>& v) {
    return nlohmann::json::array({v[0], v[1], v[2], v[3]});
}

std::array<double, 3> arr3_from_json(const nlohmann::json& j) {
    return {j.at(0).get<double>(), j.at(1).get<double>(), j.at(2).get<double>()};
}

std::array<double, 4> arr4_from_json(const nlohmann::json& j) {
    return {j.at(0).get<double>(), j.at(1).get<double>(), j.at(2).get<double>(),
            j.at(3).get<double>()};
}

}  // namespace

void to_json(nlohmann::json& j, const Instance& inst) {
    j = nlohmann::json{{"id", inst.id.str()},
                       {"source_body", inst.source_body.str()},
                       {"translation", arr3_to_json(inst.translation)},
                       {"rotation_quat", arr4_to_json(inst.rotation_quat)},
                       {"name", inst.name},
                       {"fixed", inst.fixed},
                       {"source_path", inst.source_path},
                       {"assembled_translation", arr3_to_json(inst.assembled_translation)},
                       {"exploded", inst.exploded}};
}

void from_json(const nlohmann::json& j, Instance& inst) {
    inst.id = EntityId::from_string(j.at("id").get<std::string>());
    inst.source_body = EntityId::from_string(j.at("source_body").get<std::string>());
    inst.translation = arr3_from_json(j.at("translation"));
    inst.rotation_quat = arr4_from_json(j.at("rotation_quat"));
    inst.name = j.at("name").get<std::string>();
    // Optional for older .sxp archives.
    inst.fixed = j.value("fixed", false);
    inst.source_path = j.value("source_path", "");
    inst.exploded = j.value("exploded", false);
    inst.assembled_translation = j.contains("assembled_translation")
                                     ? arr3_from_json(j.at("assembled_translation"))
                                     : inst.translation;
}

gp_Trsf transform_of(const Instance& inst) {
    const auto& q = inst.rotation_quat;
    gp_Quaternion quat(q[0], q[1], q[2], q[3]);
    const double n2 = quat.Norm();
    if (n2 < kEps) {
        quat.Set(0, 0, 0, 1);
    } else {
        quat.Normalize();
    }
    gp_Trsf t;
    t.SetTransformation(quat, gp_Vec(inst.translation[0], inst.translation[1],
                                     inst.translation[2]));
    return t;
}

TopoDS_Shape resolved_shape(const Document& doc, const Instance& inst) {
    const Body* b = doc.body(inst.source_body);
    if (!b || b->shape.IsNull()) return {};
    return b->shape.Moved(TopLoc_Location(transform_of(inst)));
}

}  // namespace sx

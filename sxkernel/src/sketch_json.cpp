#include "sx/sketch_json.hpp"

using nlohmann::json;

namespace sx {

// Friend of Sketch: rebuilds private state on load.
struct SketchSerde {
    static void restore(Sketch& sk, const json& j) {
        sk.id_ = EntityId::from_string(j.at("id").get<std::string>());
        sk.name_ = j.value("name", "Sketch");

        const auto& jp = j.at("plane");
        for (int i = 0; i < 3; ++i) {
            sk.plane_.origin[i] = jp.at("origin")[i].get<double>();
            sk.plane_.x_dir[i] = jp.at("x_dir")[i].get<double>();
            sk.plane_.y_dir[i] = jp.at("y_dir")[i].get<double>();
        }

        sk.params_.clear();
        for (const auto& v : j.at("params")) sk.params_.push_back(v.get<double>());

        sk.entities_.clear();
        for (const auto& je : j.at("entities")) {
            SketchEntity e;
            e.id = EntityId::from_string(je.at("id").get<std::string>());
            std::string t = je.at("type").get<std::string>();
            if (t == "point") e.type = SketchEntityType::Point;
            else if (t == "line") e.type = SketchEntityType::Line;
            else if (t == "circle") e.type = SketchEntityType::Circle;
            else e.type = SketchEntityType::Arc;
            e.construction = je.value("construction", false);
            for (const auto& idx : je.at("params")) e.params.push_back(idx.get<size_t>());
            sk.entities_.push_back(std::move(e));
        }

        sk.constraints_.clear();
        for (const auto& jc : j.at("constraints")) {
            SketchConstraint c;
            c.id = EntityId::from_string(jc.at("id").get<std::string>());
            std::string t = jc.at("type").get<std::string>();
            using CT = ConstraintType;
            for (CT ct : {CT::Coincident, CT::Horizontal, CT::Vertical, CT::Parallel,
                          CT::Perpendicular, CT::PointOnLine, CT::Tangent, CT::Equal,
                          CT::Distance, CT::Radius, CT::Angle, CT::Concentric,
                          CT::Symmetric, CT::Midpoint, CT::Fix, CT::Collinear}) {
                if (t == to_string(ct)) c.type = ct;
            }
            c.value = jc.value("value", 0.0);
            c.driving = jc.value("driving", true);
            c.weak = jc.value("weak", false);
            for (const auto& jr : jc.at("refs")) {
                PointRef r;
                r.entity = EntityId::from_string(jr.at("entity").get<std::string>());
                std::string role = jr.value("role", "self");
                if (role == "start") r.role = PointRole::Start;
                else if (role == "end") r.role = PointRole::End;
                else if (role == "center") r.role = PointRole::Center;
                else r.role = PointRole::Self;
                c.refs.push_back(r);
            }
            sk.constraints_.push_back(std::move(c));
        }
        ++sk.revision_;
    }
};

static const char* role_name(PointRole r) {
    switch (r) {
        case PointRole::Start: return "start";
        case PointRole::End: return "end";
        case PointRole::Center: return "center";
        case PointRole::Self: return "self";
    }
    return "self";
}

json sketch_to_json(const Sketch& sk) {
    json j;
    j["id"] = sk.id().str();
    j["name"] = sk.name();
    j["plane"] = {
        {"origin", sk.plane().origin},
        {"x_dir", sk.plane().x_dir},
        {"y_dir", sk.plane().y_dir},
    };
    json params = json::array();
    for (size_t i = 0; i < sk.param_count(); ++i) params.push_back(sk.param(i));
    j["params"] = params;

    json entities = json::array();
    for (const auto& e : sk.entities()) {
        json je;
        je["id"] = e.id.str();
        switch (e.type) {
            case SketchEntityType::Point: je["type"] = "point"; break;
            case SketchEntityType::Line: je["type"] = "line"; break;
            case SketchEntityType::Circle: je["type"] = "circle"; break;
            case SketchEntityType::Arc: je["type"] = "arc"; break;
        }
        je["construction"] = e.construction;
        je["params"] = e.params;
        entities.push_back(je);
    }
    j["entities"] = entities;

    json constraints = json::array();
    for (const auto& c : sk.constraints()) {
        json jc;
        jc["id"] = c.id.str();
        jc["type"] = to_string(c.type);
        jc["value"] = c.value;
        jc["driving"] = c.driving;
        jc["weak"] = c.weak;
        json refs = json::array();
        for (const auto& r : c.refs)
            refs.push_back({{"entity", r.entity.str()}, {"role", role_name(r.role)}});
        jc["refs"] = refs;
        constraints.push_back(jc);
    }
    j["constraints"] = constraints;
    return j;
}

std::shared_ptr<Sketch> sketch_from_json(const json& j) {
    auto sk = std::make_shared<Sketch>();
    SketchSerde::restore(*sk, j);
    return sk;
}

}  // namespace sx

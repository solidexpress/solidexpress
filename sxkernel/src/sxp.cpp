#include "sx/sxp.hpp"

#include <miniz.h>

#include <BRepBuilderAPI_Copy.hxx>
#include <type_traits>

#include <nlohmann/json.hpp>

#include "sx/cards.hpp"
#include "sx/datum.hpp"
#include "sx/document.hpp"
#include "sx/drawing_doc.hpp"
#include "sx/features.hpp"
#include "sx/instances.hpp"
#include "sx/joints.hpp"
#include "sx/log.hpp"
#include "sx/mates.hpp"
#include "sx/shape_utils.hpp"
#include "sx/sketch3d.hpp"
#include "sx/xref.hpp"

using nlohmann::json;

namespace sx {

static constexpr int kFormatVersion = 1;

bool save_sxp(const Document& doc, const std::string& path, std::string* err) {
    mz_zip_archive zip{};
    if (!mz_zip_writer_init_file(&zip, path.c_str(), 0)) {
        if (err) *err = "cannot create " + path;
        return false;
    }
    auto add = [&](const std::string& name, const std::string& data) {
        return mz_zip_writer_add_mem(&zip, name.c_str(), data.data(), data.size(),
                                     MZ_DEFAULT_COMPRESSION) == MZ_TRUE;
    };

    json manifest;
    manifest["format"] = "sxp";
    manifest["version"] = kFormatVersion;
    manifest["bodies"] = json::array();

    bool ok = true;
    for (const auto& body_id : doc.body_ids()) {
        const Body* b = doc.body(body_id);
        json jb;
        jb["uuid"] = b->id.str();
        jb["name"] = b->name;
        jb["brep"] = "breps/" + b->id.str() + ".brep";
        jb["color"] = {b->color[0], b->color[1], b->color[2]};
        jb["material"] = b->material;
        for (const auto& [kind, ids] : b->subshape_ids) {
            json arr = json::array();
            for (const auto& id : ids) arr.push_back(id.str());
            jb["subshapes"][to_string(kind)] = arr;
        }
        manifest["bodies"].push_back(jb);
        ok = ok && add("breps/" + b->id.str() + ".brep", shape::to_brep_string(b->shape));
    }

    for (const auto& card_id : doc.cards().ids()) {
        const Card* c = doc.cards().find(card_id);
        ok = ok && add("cards/" + card_id.str() + ".md", c->to_markdown());
    }

    json datums_json;
    datums_json["planes"] = json::array();
    datums_json["axes"] = json::array();
    datums_json["points"] = json::array();
    for (const auto& d : doc.datums()) {
        std::visit(
            [&](const auto& x) {
                using T = std::decay_t<decltype(x)>;
                if constexpr (std::is_same_v<T, DatumPlane>) {
                    datums_json["planes"].push_back(x);
                } else if constexpr (std::is_same_v<T, DatumAxis>) {
                    datums_json["axes"].push_back(x);
                } else if constexpr (std::is_same_v<T, DatumPoint>) {
                    datums_json["points"].push_back(x);
                }
            },
            d);
    }

    json instances_json = json::array();
    for (const auto& inst : doc.instances()) instances_json.push_back(inst);

    json mates_json = json::array();
    for (const auto& m : doc.mates()) mates_json.push_back(m);

    json connectors_json = json::array();
    for (const auto& c : doc.connectors()) connectors_json.push_back(c);

    json joints_json = json::array();
    for (const auto& j : doc.joints()) joints_json.push_back(j);

    json configs_json;
    configs_json["active"] = doc.active_configuration();
    configs_json["configurations"] = json::array();
    for (const auto& c : doc.configurations()) {
        json jc;
        jc["name"] = c.name;
        jc["variables"] = json::array();
        for (const auto& [var, expr] : c.variables) jc["variables"].push_back({var, expr});
        configs_json["configurations"].push_back(jc);
    }

    ok = ok && add("features.json", doc.graph().to_json().dump(2));
    ok = ok && add("datums.json", datums_json.dump(2));
    ok = ok && add("instances.json", instances_json.dump(2));
    ok = ok && add("mates.json", mates_json.dump(2));
    ok = ok && add("connectors.json", connectors_json.dump(2));
    ok = ok && add("joints.json", joints_json.dump(2));
    ok = ok && add("configurations.json", configs_json.dump(2));
    ok = ok && add("xrefs.json", json(doc.contexts()).dump(2));
    ok = ok && add("drawings.json", json(doc.drawing_sheets()).dump(2));
    ok = ok && add("welds.json", json(doc.welds()).dump(2));
    ok = ok && add("sketches3d.json", json(doc.sketches3d()).dump(2));
    ok = ok && add("pdm.json", json(doc.pdm_entries()).dump(2));
    ok = ok && add("print.json", json(doc.print_setup()).dump(2));
    ok = ok && add("manifest.json", manifest.dump(2));
    ok = ok && mz_zip_writer_finalize_archive(&zip) == MZ_TRUE;
    mz_zip_writer_end(&zip);
    if (!ok && err) *err = "zip write failed for " + path;
    return ok;
}

static std::string read_entry(mz_zip_archive& zip, const std::string& name, bool* found) {
    int idx = mz_zip_reader_locate_file(&zip, name.c_str(), nullptr, 0);
    if (idx < 0) {
        if (found) *found = false;
        return {};
    }
    if (found) *found = true;
    size_t size = 0;
    void* p = mz_zip_reader_extract_to_heap(&zip, static_cast<mz_uint>(idx), &size, 0);
    if (!p) return {};
    std::string data(static_cast<char*>(p), size);
    mz_free(p);
    return data;
}

bool load_sxp(Document& doc, const std::string& path, std::string* err) {
    mz_zip_archive zip{};
    if (!mz_zip_reader_init_file(&zip, path.c_str(), 0)) {
        if (err) *err = "cannot open " + path;
        return false;
    }
    struct Closer {
        mz_zip_archive* z;
        ~Closer() { mz_zip_reader_end(z); }
    } closer{&zip};

    bool found = false;
    std::string manifest_text = read_entry(zip, "manifest.json", &found);
    if (!found) {
        if (err) *err = "manifest.json missing";
        return false;
    }

    json manifest;
    try {
        manifest = json::parse(manifest_text);
    } catch (const std::exception& e) {
        if (err) *err = std::string("bad manifest: ") + e.what();
        return false;
    }
    if (manifest.value("format", "") != "sxp") {
        if (err) *err = "not an sxp file";
        return false;
    }

    // Clear existing bodies before loading (also cascades instance removal).
    for (const auto& id : doc.body_ids()) doc.remove_body(id);
    {
        std::vector<EntityId> datum_ids;
        datum_ids.reserve(doc.datums().size());
        for (const auto& d : doc.datums()) {
            datum_ids.push_back(std::visit([](const auto& x) { return x.id; }, d));
        }
        for (const auto& id : datum_ids) doc.remove_datum(id);
    }
    {
        std::vector<EntityId> instance_ids;
        instance_ids.reserve(doc.instances().size());
        for (const auto& inst : doc.instances()) instance_ids.push_back(inst.id);
        for (const auto& id : instance_ids) doc.remove_instance(id);
    }
    {
        std::vector<EntityId> mate_ids;
        mate_ids.reserve(doc.mates().size());
        for (const auto& m : doc.mates()) mate_ids.push_back(m.id);
        for (const auto& id : mate_ids) doc.remove_mate(id);
    }
    {
        std::vector<std::string> config_names;
        for (const auto& c : doc.configurations()) config_names.push_back(c.name);
        for (const auto& n : config_names) doc.remove_configuration(n);
    }
    {
        std::vector<EntityId> ids;
        for (const auto& c : doc.contexts()) ids.push_back(c.id);
        for (const auto& id : ids) doc.remove_context(id);
        ids.clear();
        for (const auto& s : doc.drawing_sheets()) ids.push_back(s.id);
        for (const auto& id : ids) doc.remove_drawing_sheet(id);
        ids.clear();
        for (const auto& w : doc.welds()) ids.push_back(w.id);
        for (const auto& id : ids) doc.remove_weld(id);
        ids.clear();
        for (const auto& s : doc.sketches3d()) ids.push_back(s.id);
        for (const auto& id : ids) doc.remove_sketch3d(id);
    }

    try {
        for (const auto& jb : manifest["bodies"]) {
            Body b;
            b.id = EntityId::from_string(jb["uuid"].get<std::string>());
            b.name = jb.value("name", "Body");
            if (jb.contains("color")) {
                for (int i = 0; i < 3; ++i) b.color[i] = jb["color"][i].get<float>();
            }
            b.material = jb.value("material", "Unspecified");
            std::string brep = read_entry(zip, jb["brep"].get<std::string>(), &found);
            if (!found) throw std::runtime_error("missing brep for " + b.name);
            b.shape = shape::from_brep_string(brep);
            if (b.shape.IsNull()) throw std::runtime_error("bad brep for " + b.name);
            if (jb.contains("subshapes")) {
                for (const auto& [kind_name, arr] : jb["subshapes"].items()) {
                    auto& ids = b.subshape_ids[entity_kind_from_string(kind_name)];
                    for (const auto& s : arr) ids.push_back(EntityId::from_string(s.get<std::string>()));
                }
            }
            doc.restore_body(std::move(b));
        }
    } catch (const std::exception& e) {
        if (err) *err = e.what();
        return false;
    }

    // Restore the parametric feature timeline (bodies were already restored
    // exactly from BREP, so no regeneration is needed here).
    std::string features_text = read_entry(zip, "features.json", &found);
    if (found) {
        try {
            doc.set_graph(FeatureGraph::from_json(json::parse(features_text)));
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad features.json: ") + e.what());
        }
    }

    // Datums are optional for backward compatibility with older .sxp files.
    std::string datums_text = read_entry(zip, "datums.json", &found);
    if (found) {
        try {
            json dj = json::parse(datums_text);
            if (dj.contains("planes")) {
                for (const auto& jp : dj["planes"]) {
                    doc.restore_datum(Datum{jp.get<DatumPlane>()});
                }
            }
            if (dj.contains("axes")) {
                for (const auto& ja : dj["axes"]) {
                    doc.restore_datum(Datum{ja.get<DatumAxis>()});
                }
            }
            if (dj.contains("points")) {
                for (const auto& jp : dj["points"]) {
                    doc.restore_datum(Datum{jp.get<DatumPoint>()});
                }
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad datums.json: ") + e.what());
        }
    }

    // Instances are optional for backward compatibility with older .sxp files.
    std::string instances_text = read_entry(zip, "instances.json", &found);
    if (found) {
        try {
            json ij = json::parse(instances_text);
            for (const auto& ji : ij) {
                Instance inst = ji.get<Instance>();
                if (!doc.body(inst.source_body)) {
                    log::warn("sxp: dropping instance '" + inst.name +
                              "' — missing source body " + inst.source_body.str());
                    continue;
                }
                doc.restore_instance(std::move(inst));
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad instances.json: ") + e.what());
        }
    }

    // Mates are optional for backward compatibility with older .sxp files.
    std::string mates_text = read_entry(zip, "mates.json", &found);
    if (found) {
        try {
            json mj = json::parse(mates_text);
            for (const auto& jm : mj) {
                Mate m = jm.get<Mate>();
                if (!m.instance_b.is_null() && !doc.instance(m.instance_b)) {
                    log::warn("sxp: dropping mate '" + m.name +
                              "' — missing instance " + m.instance_b.str());
                    continue;
                }
                doc.restore_mate(std::move(m));
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad mates.json: ") + e.what());
        }
    }

    std::string connectors_text = read_entry(zip, "connectors.json", &found);
    if (found) {
        try {
            json cj = json::parse(connectors_text);
            for (const auto& jc : cj) {
                MateConnector c = jc.get<MateConnector>();
                if (c.id.is_null()) c.id = EntityId::generate();
                doc.restore_connector(std::move(c));
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad connectors.json: ") + e.what());
        }
    }

    // Joints are optional: documents saved before DOF joints existed have none.
    std::string joints_text = read_entry(zip, "joints.json", &found);
    if (found) {
        try {
            json jj = json::parse(joints_text);
            for (const auto& j : jj) {
                Joint jnt = j.get<Joint>();
                if (jnt.id.is_null()) jnt.id = EntityId::generate();
                if (!doc.instance(jnt.b.instance)) {
                    log::warn("sxp: dropping joint '" + jnt.name + "' — missing instance " +
                              jnt.b.instance.str());
                    continue;
                }
                doc.restore_joint(std::move(jnt));
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad joints.json: ") + e.what());
        }
    }

    // Configurations are optional for backward compatibility.
    std::string configs_text = read_entry(zip, "configurations.json", &found);
    if (found) {
        try {
            json cj = json::parse(configs_text);
            std::string active = cj.value("active", "");
            for (const auto& jc : cj["configurations"]) {
                Document::Configuration c;
                c.name = jc.value("name", "");
                if (c.name.empty()) continue;
                for (const auto& jv : jc["variables"]) {
                    c.variables.emplace_back(jv[0].get<std::string>(), jv[1].get<std::string>());
                }
                bool is_active = c.name == active;
                doc.restore_configuration(std::move(c), is_active);
            }
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad configurations.json: ") + e.what());
        }
    }

    auto load_optional = [&](const char* name, auto restore) {
        std::string text = read_entry(zip, name, &found);
        if (!found) return;
        try {
            restore(json::parse(text));
        } catch (const std::exception& e) {
            log::warn(std::string("sxp: ignoring bad ") + name + ": " + e.what());
        }
    };
    load_optional("xrefs.json", [&](const json& j) {
        for (const auto& jc : j) doc.restore_context(jc.get<ContextSnapshot>());
    });
    load_optional("drawings.json", [&](const json& j) {
        for (const auto& js : j) doc.restore_drawing_sheet(js.get<DrawingSheetDoc>());
    });
    load_optional("welds.json", [&](const json& j) {
        for (const auto& jw : j) doc.restore_weld(jw.get<CosmeticWeld>());
    });
    load_optional("sketches3d.json", [&](const json& j) {
        for (const auto& js : j) doc.restore_sketch3d(js.get<Sketch3D>());
    });
    load_optional("print.json", [&](const json& j) {
        doc.restore_print_setup(j.get<PrintSetup>());
    });
    load_optional("pdm.json", [&](const json& j) {
        std::vector<std::pair<std::string, uint64_t>> entries;
        for (const auto& je : j) {
            if (je.is_array() && je.size() >= 2)
                entries.emplace_back(je[0].get<std::string>(), je[1].get<uint64_t>());
        }
        doc.restore_pdm(std::move(entries));
    });

    // Restore preserved card free-text (registered cards were regenerated by
    // restore_body; overlay aliases/notes from the archive).
    mz_uint num = mz_zip_reader_get_num_files(&zip);
    for (mz_uint i = 0; i < num; ++i) {
        char name[512];
        mz_zip_reader_get_filename(&zip, i, name, sizeof(name));
        std::string fname(name);
        if (fname.rfind("cards/", 0) != 0) continue;
        std::string md = read_entry(zip, fname, nullptr);
        auto card = Card::from_markdown(md);
        if (!card) continue;
        if (!card->aliases.empty()) doc.cards().set_alias(card->id, card->aliases);
        if (!card->notes.empty()) doc.cards().set_notes(card->id, card->notes);
    }
    return true;
}

bool insert_sxp(Document& dest, const std::string& path,
                const std::array<double, 3>& base_translation, InsertSxpResult* out,
                std::string* err) {
    Document tmp;
    if (!load_sxp(tmp, path, err)) return false;
    const auto src_ids = tmp.body_ids();
    if (src_ids.empty()) {
        if (err) *err = "no bodies in " + path;
        return false;
    }

    InsertSxpResult local;
    InsertSxpResult& result = out ? *out : local;
    result.body_ids.clear();
    result.instance_ids.clear();

    // First component into an empty assembly is Fixed (SolidWorks default).
    const bool fix_first = dest.instances().empty();

    for (size_t i = 0; i < src_ids.size(); ++i) {
        const Body* src = tmp.body(src_ids[i]);
        if (!src || src->shape.IsNull()) {
            if (err) *err = "null body in " + path;
            return false;
        }
        BRepBuilderAPI_Copy copier(src->shape, /*copyGeom=*/true, /*copyMesh=*/true);
        if (!copier.IsDone()) {
            if (err) *err = "BREP copy failed for body in " + path;
            return false;
        }
        const std::string name = src->name.empty() ? "Component" : src->name;
        const EntityId new_body = dest.add_body(copier.Shape(), name);
        if (new_body.is_null()) {
            if (err) *err = "add_body failed during insert";
            return false;
        }
        if (Body* b = dest.body_mut(new_body)) {
            b->color = src->color;
            b->material = src->material;
        }

        // Stagger subsequent bodies so multi-body parts don't stack.
        const std::array<double, 3> t{base_translation[0] + static_cast<double>(i) * 40.0,
                                      base_translation[1], base_translation[2]};
        const EntityId iid = dest.add_instance(new_body, t, {0, 0, 0, 1}, name);
        if (iid.is_null()) {
            if (err) *err = "add_instance failed during insert";
            return false;
        }
        dest.set_instance_source_path(iid, path);
        if (fix_first && i == 0) dest.set_instance_fixed(iid, true);

        result.body_ids.push_back(new_body);
        result.instance_ids.push_back(iid);
    }
    return true;
}

SxpComponentInfo sxp_component_info(const std::string& path) {
    SxpComponentInfo info;
    Document tmp;
    std::string err;
    if (!load_sxp(tmp, path, &err)) {
        info.error = err.empty() ? "load failed" : err;
        return info;
    }
    info.ok = true;
    for (const auto& id : tmp.body_ids()) {
        const Body* b = tmp.body(id);
        if (!b) continue;
        info.body_ids.push_back(id.str());
        info.body_names.push_back(b->name.empty() ? "Body" : b->name);
        info.volumes.push_back(shape::volume(b->shape));
    }
    return info;
}

}  // namespace sx

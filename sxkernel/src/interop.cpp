#include "sx/interop.hpp"

#include "sx/document.hpp"
#include "sx/shape_utils.hpp"
#include "sx/tessellate.hpp"

#include <miniz.h>

#include <BRepBuilderAPI_Sewing.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Builder.hxx>
#include <ShapeFix_Shape.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <IGESControl_Reader.hxx>
#include <IGESControl_Writer.hxx>
#include <Interface_Static.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <StlAPI_Reader.hxx>
#include <StlAPI_Writer.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Shape.hxx>

#include <Standard_Failure.hxx>
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <exception>
#include <fstream>
#include <sstream>

namespace sx::interop {
namespace {

void set_err(std::string* err, const std::string& msg) {
    if (err) *err = msg;
}

// One body per solid when the root contains solids; otherwise the root itself
// (shells/surfaces from IGES, mesh compounds from STL, etc.).
void collect_units(const TopoDS_Shape& root, std::vector<TopoDS_Shape>& out) {
    if (root.IsNull()) return;
    TopTools_IndexedMapOfShape solids;
    TopExp::MapShapes(root, TopAbs_SOLID, solids);
    if (solids.Extent() > 0) {
        for (int i = 1; i <= solids.Extent(); ++i) out.push_back(solids(i));
    } else {
        out.push_back(root);
    }
}

std::vector<EntityId> add_units(Document& doc,
                                const std::vector<TopoDS_Shape>& units,
                                const std::string& name_prefix,
                                std::string* err) {
    if (units.empty()) {
        set_err(err, "no shapes to import");
        return {};
    }
    std::vector<EntityId> ids;
    ids.reserve(units.size());
    for (size_t i = 0; i < units.size(); ++i) {
        std::ostringstream name;
        name << name_prefix << (i + 1);
        ids.push_back(doc.add_body(units[i], name.str()));
    }
    return ids;
}

TopoDS_Shape make_compound(const Document& doc) {
    TopoDS_Compound compound;
    BRep_Builder builder;
    builder.MakeCompound(compound);
    for (const auto& id : doc.body_ids()) {
        const Body* b = doc.body(id);
        if (!b || b->shape.IsNull()) continue;
        builder.Add(compound, b->shape);
    }
    return compound;
}

}  // namespace

bool export_step(const Document& doc, const std::string& path, std::string* err) {
    try {
        auto ids = doc.body_ids();
        if (ids.empty()) {
            set_err(err, "document has no bodies");
            return false;
        }
        Interface_Static::SetCVal("write.step.schema", "AP214");
        STEPControl_Writer writer;
        for (const auto& id : ids) {
            const Body* b = doc.body(id);
            if (!b || b->shape.IsNull()) continue;
            IFSelect_ReturnStatus st = writer.Transfer(b->shape, STEPControl_AsIs);
            if (st != IFSelect_RetDone) {
                set_err(err, "STEP transfer failed for body " + b->name);
                return false;
            }
        }
        IFSelect_ReturnStatus st = writer.Write(path.c_str());
        if (st != IFSelect_RetDone) {
            set_err(err, "cannot write STEP file " + path);
            return false;
        }
        return true;
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STEP export: ") + e.GetMessageString());
        return false;
    } catch (const std::exception& e) {
        set_err(err, std::string("STEP export: ") + e.what());
        return false;
    }
}

std::vector<EntityId> import_step(Document& doc, const std::string& path, std::string* err) {
    try {
        STEPControl_Reader reader;
        IFSelect_ReturnStatus st = reader.ReadFile(path.c_str());
        if (st != IFSelect_RetDone) {
            set_err(err, "cannot read STEP file " + path);
            return {};
        }
        reader.TransferRoots();
        const int n = reader.NbShapes();
        if (n <= 0) {
            set_err(err, "STEP file contains no shapes: " + path);
            return {};
        }
        std::vector<TopoDS_Shape> units;
        for (int i = 1; i <= n; ++i) collect_units(reader.Shape(i), units);
        return add_units(doc, units, "Imported ", err);
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STEP import: ") + e.GetMessageString());
        return {};
    } catch (const std::exception& e) {
        set_err(err, std::string("STEP import: ") + e.what());
        return {};
    }
}

bool export_iges(const Document& doc, const std::string& path, std::string* err) {
    try {
        auto ids = doc.body_ids();
        if (ids.empty()) {
            set_err(err, "document has no bodies");
            return false;
        }
        // BRep mode (1) preserves solid topology better than Face mode.
        IGESControl_Writer writer("MM", 1);
        for (const auto& id : ids) {
            const Body* b = doc.body(id);
            if (!b || b->shape.IsNull()) continue;
            if (!writer.AddShape(b->shape)) {
                set_err(err, "IGES transfer failed for body " + b->name);
                return false;
            }
        }
        writer.ComputeModel();
        if (!writer.Write(path.c_str())) {
            set_err(err, "cannot write IGES file " + path);
            return false;
        }
        return true;
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("IGES export: ") + e.GetMessageString());
        return false;
    } catch (const std::exception& e) {
        set_err(err, std::string("IGES export: ") + e.what());
        return false;
    }
}

std::vector<EntityId> import_iges(Document& doc, const std::string& path, std::string* err) {
    try {
        IGESControl_Reader reader;
        IFSelect_ReturnStatus st = reader.ReadFile(path.c_str());
        if (st != IFSelect_RetDone) {
            set_err(err, "cannot read IGES file " + path);
            return {};
        }
        reader.TransferRoots();
        const int n = reader.NbShapes();
        if (n <= 0) {
            set_err(err, "IGES file contains no shapes: " + path);
            return {};
        }
        std::vector<TopoDS_Shape> units;
        for (int i = 1; i <= n; ++i) collect_units(reader.Shape(i), units);
        return add_units(doc, units, "Imported ", err);
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("IGES import: ") + e.GetMessageString());
        return {};
    } catch (const std::exception& e) {
        set_err(err, std::string("IGES import: ") + e.what());
        return {};
    }
}

bool export_stl(const Document& doc, const std::string& path, bool binary, std::string* err) {
    try {
        auto ids = doc.body_ids();
        if (ids.empty()) {
            set_err(err, "document has no bodies");
            return false;
        }

        TopoDS_Shape shape;
        if (ids.size() == 1) {
            const Body* b = doc.body(ids[0]);
            if (!b || b->shape.IsNull()) {
                set_err(err, "body has null shape");
                return false;
            }
            shape = b->shape;
        } else {
            shape = make_compound(doc);
            if (shape.IsNull()) {
                set_err(err, "failed to build compound for STL export");
                return false;
            }
        }

        BRepMesh_IncrementalMesh mesher(shape, 0.1);
        (void)mesher;

        StlAPI_Writer writer;
        writer.ASCIIMode() = binary ? Standard_False : Standard_True;
        if (!writer.Write(shape, path.c_str())) {
            set_err(err, "cannot write STL file " + path);
            return false;
        }
        return true;
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STL export: ") + e.GetMessageString());
        return false;
    } catch (const std::exception& e) {
        set_err(err, std::string("STL export: ") + e.what());
        return false;
    }
}

std::vector<EntityId> import_stl(Document& doc, const std::string& path, std::string* err) {
    try {
        TopoDS_Shape shape;
        StlAPI_Reader reader;
        if (!reader.Read(shape, path.c_str()) || shape.IsNull()) {
            set_err(err, "cannot read STL file " + path);
            return {};
        }
        return {doc.add_body(shape, "Mesh 1")};
    } catch (const Standard_Failure& e) {
        set_err(err, std::string("STL import: ") + e.GetMessageString());
        return {};
    } catch (const std::exception& e) {
        set_err(err, std::string("STL import: ") + e.what());
        return {};
    }
}

TopoDS_Shape heal_shape(const TopoDS_Shape& shape, std::string* report) {
    if (shape.IsNull()) {
        if (report) *report = "heal: empty shape";
        return shape;
    }
    const auto before = shape::count(shape);
    TopoDS_Shape work = shape;
    try {
        BRepBuilderAPI_Sewing sew(1.0e-3);
        sew.Add(shape);
        sew.Perform();
        if (!sew.SewedShape().IsNull()) work = sew.SewedShape();
        Handle(ShapeFix_Shape) fix = new ShapeFix_Shape(work);
        fix->Perform();
        if (!fix->Shape().IsNull()) work = fix->Shape();
    } catch (const Standard_Failure& e) {
        if (report) *report = std::string("heal: ShapeFix failed (") + e.GetMessageString() + ")";
        return shape;
    }
    const auto after = shape::count(work);
    BRepCheck_Analyzer chk(work);
    const bool valid = chk.IsValid();
    std::ostringstream ss;
    ss << "heal: faces " << before.faces << "→" << after.faces << ", solids "
       << before.solids << "→" << after.solids << (valid ? ", valid" : ", still open");
    if (report) *report = ss.str();
    return work;
}

namespace {

struct TriMesh {
    std::vector<float> positions;
    std::vector<uint32_t> indices;
};

TriMesh collect_mesh(const Document& doc) {
    TriMesh m;
    for (const auto& id : doc.body_ids()) {
        BodyMesh bm = tessellate_body(doc, id);
        for (const auto& face : bm.faces) {
            const uint32_t base = static_cast<uint32_t>(m.positions.size() / 3);
            m.positions.insert(m.positions.end(), face.positions.begin(), face.positions.end());
            for (uint32_t idx : face.indices) m.indices.push_back(base + idx);
        }
    }
    return m;
}

std::string b64(const std::string& raw) {
    static const char* tbl =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    out.reserve(((raw.size() + 2) / 3) * 4);
    size_t i = 0;
    while (i + 2 < raw.size()) {
        unsigned n = (static_cast<unsigned char>(raw[i]) << 16) |
                     (static_cast<unsigned char>(raw[i + 1]) << 8) |
                     static_cast<unsigned char>(raw[i + 2]);
        out.push_back(tbl[(n >> 18) & 63]);
        out.push_back(tbl[(n >> 12) & 63]);
        out.push_back(tbl[(n >> 6) & 63]);
        out.push_back(tbl[n & 63]);
        i += 3;
    }
    if (i < raw.size()) {
        unsigned n = static_cast<unsigned char>(raw[i]) << 16;
        if (i + 1 < raw.size()) n |= static_cast<unsigned char>(raw[i + 1]) << 8;
        out.push_back(tbl[(n >> 18) & 63]);
        out.push_back(tbl[(n >> 12) & 63]);
        out.push_back(i + 1 < raw.size() ? tbl[(n >> 6) & 63] : '=');
        out.push_back('=');
    }
    return out;
}

}  // namespace

bool export_3mf(const Document& doc, const std::string& path, std::string* err) {
    try {
        TriMesh mesh = collect_mesh(doc);
        if (mesh.indices.empty()) {
            set_err(err, "no tessellated triangles to export");
            return false;
        }
        const PrintSetup& ps = doc.print_setup();
        auto xform = [&](float x, float y, float z) {
            return std::array<double, 3>{
                ps.rot[0] * x + ps.rot[1] * y + ps.rot[2] * z,
                ps.rot[3] * x + ps.rot[4] * y + ps.rot[5] * z,
                ps.rot[6] * x + ps.rot[7] * y + ps.rot[8] * z};
        };
        std::ostringstream model;
        model << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
              << "<model unit=\"millimeter\" "
              << "xmlns=\"http://schemas.microsoft.com/3dmanufacturing/core/2015/02\">\n"
              << "  <metadata name=\"sx:bed\">" << ps.bed_x << "x" << ps.bed_y << "x"
              << ps.bed_z << "</metadata>\n"
              << "  <metadata name=\"sx:layer\">" << ps.layer_height << "</metadata>\n"
              << "  <metadata name=\"sx:min_wall\">" << ps.min_wall << "</metadata>\n"
              << "  <resources>\n    <object id=\"1\" type=\"model\">\n      <mesh>\n"
              << "        <vertices>\n";
        for (size_t i = 0; i + 2 < mesh.positions.size(); i += 3) {
            const auto p = xform(mesh.positions[i], mesh.positions[i + 1], mesh.positions[i + 2]);
            model << "          <vertex x=\"" << p[0] << "\" y=\"" << p[1] << "\" z=\""
                  << p[2] << "\"/>\n";
        }
        model << "        </vertices>\n        <triangles>\n";
        for (size_t i = 0; i + 2 < mesh.indices.size(); i += 3) {
            model << "          <triangle v1=\"" << mesh.indices[i] << "\" v2=\""
                  << mesh.indices[i + 1] << "\" v3=\"" << mesh.indices[i + 2] << "\"/>\n";
        }
        model << "        </triangles>\n      </mesh>\n    </object>\n  </resources>\n"
              << "  <build><item objectid=\"1\"/></build>\n</model>\n";
        const std::string xml = model.str();
        const std::string ctypes =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
            "<Default Extension=\"rels\" "
            "ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
            "<Default Extension=\"model\" "
            "ContentType=\"application/vnd.ms-package.3dmanufacturing-3dmodel+xml\"/>"
            "</Types>";
        const std::string rels =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
            "<Relationship Target=\"/3D/3dmodel.model\" Id=\"rel0\" "
            "Type=\"http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel\"/>"
            "</Relationships>";
        mz_zip_archive zip{};
        if (!mz_zip_writer_init_file(&zip, path.c_str(), 0)) {
            set_err(err, "cannot create " + path);
            return false;
        }
        auto add = [&](const char* name, const std::string& data) {
            return mz_zip_writer_add_mem(&zip, name, data.data(), data.size(),
                                         MZ_DEFAULT_COMPRESSION) == MZ_TRUE;
        };
        bool ok = add("[Content_Types].xml", ctypes) && add("_rels/.rels", rels) &&
                  add("3D/3dmodel.model", xml);
        ok = ok && mz_zip_writer_finalize_archive(&zip) == MZ_TRUE;
        mz_zip_writer_end(&zip);
        if (!ok) set_err(err, "3MF zip write failed");
        return ok;
    } catch (const std::exception& e) {
        set_err(err, std::string("3MF export: ") + e.what());
        return false;
    }
}

bool export_gltf(const Document& doc, const std::string& path, std::string* err) {
    try {
        TriMesh mesh = collect_mesh(doc);
        if (mesh.indices.empty()) {
            set_err(err, "no tessellated triangles to export");
            return false;
        }
        std::string bin;
        bin.resize(mesh.positions.size() * sizeof(float) + mesh.indices.size() * sizeof(uint32_t));
        std::memcpy(bin.data(), mesh.positions.data(), mesh.positions.size() * sizeof(float));
        std::memcpy(bin.data() + mesh.positions.size() * sizeof(float), mesh.indices.data(),
                    mesh.indices.size() * sizeof(uint32_t));
        const size_t pos_bytes = mesh.positions.size() * sizeof(float);
        const size_t idx_bytes = mesh.indices.size() * sizeof(uint32_t);
        float minx = mesh.positions[0], miny = mesh.positions[1], minz = mesh.positions[2];
        float maxx = minx, maxy = miny, maxz = minz;
        for (size_t i = 0; i + 2 < mesh.positions.size(); i += 3) {
            minx = std::min(minx, mesh.positions[i]);
            miny = std::min(miny, mesh.positions[i + 1]);
            minz = std::min(minz, mesh.positions[i + 2]);
            maxx = std::max(maxx, mesh.positions[i]);
            maxy = std::max(maxy, mesh.positions[i + 1]);
            maxz = std::max(maxz, mesh.positions[i + 2]);
        }
        const int nvert = static_cast<int>(mesh.positions.size() / 3);
        const int nidx = static_cast<int>(mesh.indices.size());
        std::ostringstream j;
        j << "{\n  \"asset\": {\"version\": \"2.0\", \"generator\": \"SolidExpress\"},\n"
          << "  \"scene\": 0,\n  \"scenes\": [{\"nodes\": [0]}],\n"
          << "  \"nodes\": [{\"mesh\": 0}],\n"
          << "  \"meshes\": [{\"primitives\": [{\"attributes\": {\"POSITION\": 0}, \"indices\": 1}]}],\n"
          << "  \"accessors\": [\n"
          << "    {\"bufferView\": 0, \"componentType\": 5126, \"count\": " << nvert
          << ", \"type\": \"VEC3\", \"min\": [" << minx << "," << miny << "," << minz
          << "], \"max\": [" << maxx << "," << maxy << "," << maxz << "]},\n"
          << "    {\"bufferView\": 1, \"componentType\": 5125, \"count\": " << nidx
          << ", \"type\": \"SCALAR\"}\n  ],\n"
          << "  \"bufferViews\": [\n"
          << "    {\"buffer\": 0, \"byteOffset\": 0, \"byteLength\": " << pos_bytes << "},\n"
          << "    {\"buffer\": 0, \"byteOffset\": " << pos_bytes << ", \"byteLength\": " << idx_bytes
          << "}\n  ],\n"
          << "  \"buffers\": [{\"byteLength\": " << bin.size()
          << ", \"uri\": \"data:application/octet-stream;base64," << b64(bin) << "\"}]\n}\n";
        std::ofstream out(path);
        if (!out) {
            set_err(err, "cannot write " + path);
            return false;
        }
        out << j.str();
        return true;
    } catch (const std::exception& e) {
        set_err(err, std::string("glTF export: ") + e.what());
        return false;
    }
}

}  // namespace sx::interop

#include "sx/voice.hpp"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <sstream>
#include <unordered_map>

namespace sx::voice {
namespace {

std::string trim(std::string s) {
    auto not_space = [](unsigned char c) { return !std::isspace(c); };
    s.erase(s.begin(), std::find_if(s.begin(), s.end(), not_space));
    s.erase(std::find_if(s.rbegin(), s.rend(), not_space).base(), s.end());
    return s;
}

std::vector<std::string> tokens(const std::string& norm) {
    std::vector<std::string> out;
    std::istringstream iss(norm);
    std::string t;
    while (iss >> t) out.push_back(t);
    return out;
}

// English number words → int (0..20) for "shell this two".
std::optional<double> word_number(const std::string& w) {
    static const std::unordered_map<std::string, double> map{
        {"zero", 0},   {"one", 1},   {"two", 2},   {"three", 3},
        {"four", 4},   {"five", 5},  {"six", 6},   {"seven", 7},
        {"eight", 8},  {"nine", 9},  {"ten", 10},  {"eleven", 11},
        {"twelve", 12}, {"thirteen", 13}, {"fourteen", 14},
        {"fifteen", 15}, {"sixteen", 16}, {"seventeen", 17},
        {"eighteen", 18}, {"nineteen", 19}, {"twenty", 20},
        {"half", 0.5}, {"quarter", 0.25},
    };
    auto it = map.find(w);
    if (it == map.end()) return std::nullopt;
    return it->second;
}

std::optional<double> parse_number(const std::string& w) {
    if (auto wn = word_number(w)) return wn;
    try {
        size_t idx = 0;
        double v = std::stod(w, &idx);
        if (idx == w.size()) return v;
    } catch (...) {
    }
    return std::nullopt;
}

// Scan tokens for first number + optional unit after it.
struct NumberHit {
    double value = 0;
    std::string unit;
    size_t at = 0;
};

std::optional<NumberHit> find_number(const std::vector<std::string>& tok, size_t from = 0) {
    for (size_t i = from; i < tok.size(); ++i) {
        auto n = parse_number(tok[i]);
        if (!n) continue;
        NumberHit h{*n, "", i};
        if (i + 1 < tok.size()) {
            const auto& u = tok[i + 1];
            if (u == "mm" || u == "millimeter" || u == "millimeters")
                h.unit = "mm";
            else if (u == "in" || u == "inch" || u == "inches")
                h.unit = "in";
            else if (u == "deg" || u == "degree" || u == "degrees")
                h.unit = "deg";
            else if (u == "m" && i + 1 < tok.size()) {
                // "m" alone is ambiguous; treat as mm if "meters" not used
            }
        }
        // Strip unit glued to number: "3mm", "10.5in"
        const std::string& w = tok[i];
        if (w.size() > 2 && w.ends_with("mm")) {
            if (auto v = parse_number(w.substr(0, w.size() - 2))) {
                h.value = *v;
                h.unit = "mm";
            }
        } else if (w.size() > 2 && w.ends_with("in")) {
            if (auto v = parse_number(w.substr(0, w.size() - 2))) {
                h.value = *v;
                h.unit = "in";
            }
        }
        return h;
    }
    return std::nullopt;
}

bool contains(const std::vector<std::string>& tok, const std::string& w) {
    return std::find(tok.begin(), tok.end(), w) != tok.end();
}

bool contains_any(const std::vector<std::string>& tok,
                  std::initializer_list<const char*> words) {
    for (const char* w : words)
        if (contains(tok, w)) return true;
    return false;
}

bool phrase_has(const std::string& norm, const char* needle) {
    return norm.find(needle) != std::string::npos;
}

Intent make(IntentKind k, std::string verb, float conf = 1.f) {
    Intent i;
    i.kind = k;
    i.verb = std::move(verb);
    i.confidence = conf;
    return i;
}

void attach_selection_prompt(Intent& i, const SelectionContext* sel) {
    if (!sel || i.kind == IntentKind::Unmatched) return;

    auto n_bodies = sel->bodies.size();
    auto n_faces = sel->faces.size();
    auto n_edges = sel->edges.size();
    auto n_sk = sel->sketch_entities.size();

    if (i.kind == IntentKind::Constraint) {
        if (!sel->sketch_active) {
            i.prompt = "Enter a sketch first, then select geometry and ask again";
            return;
        }
        if (i.verb == "horizontal" || i.verb == "vertical" || i.verb == "fix") {
            if (n_sk < 1)
                i.prompt = "Select a line in the sketch, then ask again";
        } else if (i.verb == "parallel" || i.verb == "perpendicular" ||
                   i.verb == "equal" || i.verb == "tangent") {
            if (n_sk < 2)
                i.prompt = "Select two sketch entities, then ask again";
        } else if (i.verb == "coincident" || i.verb == "concentric") {
            if (n_sk < 2)
                i.prompt = "Select two points or circles, then ask again";
        } else if (i.verb == "distance" || i.verb == "angle" || i.verb == "radius") {
            if (n_sk < 1)
                i.prompt = "Select the sketch entity to dimension, then ask again";
        }
        return;
    }

    if (i.kind == IntentKind::Model) {
        if (i.verb == "fillet" || i.verb == "chamfer") {
            if (n_edges < 1 && n_bodies < 1)
                i.prompt = "Select an edge (or a body), then ask again";
        } else if (i.verb == "shell") {
            if (n_faces < 1 && n_bodies < 1)
                i.prompt = "Select a face to open (or a body), then ask again";
        } else if (i.verb == "hole") {
            if (n_faces < 1)
                i.prompt = "Select a planar face for the hole, then ask again";
        } else if (i.verb == "hide" || i.verb == "isolate" || i.verb == "delete") {
            if (n_bodies < 1)
                i.prompt = "Select a body, then ask again";
        } else if (i.verb == "mirror") {
            if (n_bodies < 1)
                i.prompt = "Select a body to mirror, then ask again";
        } else if (i.verb == "fasten" || i.verb == "flush") {
            if (n_faces < 2)
                i.prompt = "Select two faces, then ask again";
        }
        if (i.verb == "delete") i.needs_confirm = true;
        return;
    }

    if (i.kind == IntentKind::Query) {
        if (i.verb == "mass" || i.verb == "volume") {
            if (n_bodies < 1)
                i.prompt = "Select a body, then ask again";
        } else if (i.verb == "area") {
            if (n_faces < 1)
                i.prompt = "Select a face, then ask again";
        } else if (i.verb == "distance_between") {
            if (n_bodies + n_faces + n_edges < 2)
                i.prompt = "Select two things, then ask for the distance";
        }
    }
}

}  // namespace

const char* to_string(IntentKind k) {
    switch (k) {
        case IntentKind::Constraint: return "constraint";
        case IntentKind::Model: return "model";
        case IntentKind::View: return "view";
        case IntentKind::App: return "app";
        case IntentKind::Variable: return "variable";
        case IntentKind::Query: return "query";
        case IntentKind::Unmatched: return "unmatched";
    }
    return "unmatched";
}

std::optional<IntentKind> kind_from_string(const std::string& s) {
    if (s == "constraint") return IntentKind::Constraint;
    if (s == "model") return IntentKind::Model;
    if (s == "view") return IntentKind::View;
    if (s == "app") return IntentKind::App;
    if (s == "variable") return IntentKind::Variable;
    if (s == "query") return IntentKind::Query;
    if (s == "unmatched") return IntentKind::Unmatched;
    return std::nullopt;
}

std::string normalize(const std::string& text) {
    std::string out;
    out.reserve(text.size());
    bool space = false;
    for (size_t i = 0; i < text.size(); ++i) {
        unsigned char c = static_cast<unsigned char>(text[i]);
        if (std::isalpha(c)) {
            out.push_back(static_cast<char>(std::tolower(c)));
            space = false;
        } else if (std::isdigit(c) || c == '-') {
            out.push_back(static_cast<char>(c));
            space = false;
        } else if (c == '.') {
            // Keep decimal points between digits; drop trailing/other dots.
            bool prev_digit = !out.empty() && std::isdigit(static_cast<unsigned char>(out.back()));
            bool next_digit = i + 1 < text.size() &&
                              std::isdigit(static_cast<unsigned char>(text[i + 1]));
            if (prev_digit && next_digit) {
                out.push_back('.');
                space = false;
            } else if (!out.empty() && !space) {
                out.push_back(' ');
                space = true;
            }
        } else if (std::isspace(c) || c == ',' || c == ';' || c == '!' ||
                   c == '?' || c == ':' || c == '"' || c == '\'') {
            if (!out.empty() && !space) {
                out.push_back(' ');
                space = true;
            }
        }
        // drop other punctuation
    }
    return trim(out);
}

nlohmann::json Intent::to_json() const {
    nlohmann::json j;
    j["kind"] = to_string(kind);
    j["verb"] = verb;
    if (value) j["value"] = *value;
    else j["value"] = nullptr;
    j["unit"] = unit;
    j["name"] = name;
    j["expression"] = expression;
    j["raw_text"] = raw_text;
    j["confidence"] = confidence;
    j["prompt"] = prompt;
    j["needs_confirm"] = needs_confirm;
    return j;
}

Intent Intent::from_json(const nlohmann::json& j) {
    Intent i;
    if (auto k = kind_from_string(j.value("kind", "unmatched"))) i.kind = *k;
    i.verb = j.value("verb", "");
    if (j.contains("value") && !j["value"].is_null()) i.value = j["value"].get<double>();
    i.unit = j.value("unit", "");
    i.name = j.value("name", "");
    i.expression = j.value("expression", "");
    i.raw_text = j.value("raw_text", "");
    i.confidence = j.value("confidence", 0.f);
    i.prompt = j.value("prompt", "");
    i.needs_confirm = j.value("needs_confirm", false);
    return i;
}

Intent interpret(const std::string& utterance, const SelectionContext* selection) {
    Intent out;
    out.raw_text = utterance;
    const std::string norm = normalize(utterance);
    if (norm.empty()) {
        out.kind = IntentKind::Unmatched;
        out.confidence = 0.f;
        out.prompt = "I didn't catch that — hold V and try again";
        return out;
    }
    const auto tok = tokens(norm);

    // Prefer explicit query keywords before short view aliases ("top"/"right")
    // that could otherwise collide with longer phrases.
    if (contains(tok, "volume") || phrase_has(norm, "how heavy") ||
        contains(tok, "mass") || phrase_has(norm, "weigh") ||
        (contains(tok, "area") && !contains(tok, "square")) ||
        phrase_has(norm, "how far") || phrase_has(norm, "distance between") ||
        phrase_has(norm, "how far apart") || phrase_has(norm, "measure distance") ||
        norm == "help" || phrase_has(norm, "what can i say") ||
        phrase_has(norm, "voice help")) {
        if (contains(tok, "volume") || phrase_has(norm, "volume of")) {
            out = make(IntentKind::Query, "volume");
        } else if (contains(tok, "mass") || phrase_has(norm, "how heavy") ||
                   phrase_has(norm, "weigh")) {
            out = make(IntentKind::Query, "mass");
        } else if (contains(tok, "area")) {
            out = make(IntentKind::Query, "area");
        } else if (phrase_has(norm, "how far") || phrase_has(norm, "distance between") ||
                   phrase_has(norm, "how far apart") || phrase_has(norm, "measure distance")) {
            out = make(IntentKind::Query, "distance_between");
        } else {
            out = make(IntentKind::Query, "help");
        }
    }

    // --- App (undo/redo/save/cancel/ok) ---
    else if (phrase_has(norm, "undo") || norm == "oops" || phrase_has(norm, "take that back")) {
        out = make(IntentKind::App, "undo");
    } else if (phrase_has(norm, "redo")) {
        out = make(IntentKind::App, "redo");
    } else if (norm == "save" || phrase_has(norm, "save file") ||
               phrase_has(norm, "save the file")) {
        out = make(IntentKind::App, "save");
    } else if (norm == "cancel" || norm == "never mind" || norm == "nevermind" ||
               norm == "abort") {
        out = make(IntentKind::App, "cancel");
    } else if (norm == "ok" || norm == "okay" || norm == "confirm" ||
               norm == "accept" || norm == "done") {
        out = make(IntentKind::App, "ok");
    }

    // --- View ---
    else if (phrase_has(norm, "zoom to fit") || phrase_has(norm, "fit all") ||
             phrase_has(norm, "frame all") || norm == "zoom fit") {
        out = make(IntentKind::View, "zoom_fit");
    } else if (phrase_has(norm, "isometric") || norm == "iso" ||
               phrase_has(norm, "iso view")) {
        out = make(IntentKind::View, "iso");
    } else if (phrase_has(norm, "front view") || phrase_has(norm, "look at the front") ||
               phrase_has(norm, "look front") || norm == "front") {
        out = make(IntentKind::View, "front");
    } else if (phrase_has(norm, "top view") || phrase_has(norm, "look at the top") ||
               phrase_has(norm, "look top") || norm == "top") {
        out = make(IntentKind::View, "top");
    } else if (phrase_has(norm, "right view") || phrase_has(norm, "look at the right") ||
               phrase_has(norm, "look right") || norm == "right") {
        out = make(IntentKind::View, "right");
    } else if (phrase_has(norm, "left view") || norm == "left") {
        out = make(IntentKind::View, "left");
    } else if (phrase_has(norm, "back view") || norm == "back") {
        out = make(IntentKind::View, "back");
    } else if (phrase_has(norm, "bottom view") || norm == "bottom") {
        out = make(IntentKind::View, "bottom");
    } else if (phrase_has(norm, "section") || phrase_has(norm, "cutaway")) {
        out = make(IntentKind::View, "section");
    } else if (phrase_has(norm, "orthographic") || phrase_has(norm, "ortho")) {
        out = make(IntentKind::View, "ortho");
    } else if (phrase_has(norm, "perspective")) {
        out = make(IntentKind::View, "perspective");
    }

    // --- Variables: "set width to 55", "make height twice the width" ---
    // Tried first among remaining; if parse fails, fall through to constraints.
    else if (contains(tok, "set") ||
             (contains(tok, "make") && contains_any(tok, {"twice", "half"}))) {
        auto set_it = std::find(tok.begin(), tok.end(), "set");
        if (set_it != tok.end() && set_it + 1 != tok.end()) {
            std::string var = *(set_it + 1);
            auto num = find_number(tok, static_cast<size_t>(set_it - tok.begin()) + 2);
            if (num) {
                out = make(IntentKind::Variable, "set_var");
                out.name = var;
                out.value = num->value;
                out.unit = num->unit;
            } else {
                auto to_it = std::find(set_it, tok.end(), "to");
                if (to_it != tok.end() && to_it + 1 != tok.end()) {
                    out = make(IntentKind::Variable, "set_expr");
                    out.name = var;
                    std::ostringstream expr;
                    for (auto it = to_it + 1; it != tok.end(); ++it) {
                        if (it != to_it + 1) expr << ' ';
                        expr << *it;
                    }
                    out.expression = expr.str();
                }
            }
        }
        if (out.kind == IntentKind::Unmatched && phrase_has(norm, "twice")) {
            auto make_it = std::find(tok.begin(), tok.end(), "make");
            auto twice_it = std::find(tok.begin(), tok.end(), "twice");
            if (make_it != tok.end() && twice_it != tok.end() && make_it + 1 < twice_it) {
                out = make(IntentKind::Variable, "set_expr");
                out.name = *(make_it + 1);
                for (auto it = twice_it + 1; it != tok.end(); ++it) {
                    if (*it == "the" || *it == "a") continue;
                    out.expression = "2*" + *it;
                    break;
                }
            }
        }
        if (out.kind == IntentKind::Unmatched && phrase_has(norm, "half")) {
            auto make_it = std::find(tok.begin(), tok.end(), "make");
            auto half_it = std::find(tok.begin(), tok.end(), "half");
            if (make_it != tok.end() && half_it != tok.end() && make_it + 1 < half_it) {
                out = make(IntentKind::Variable, "set_expr");
                out.name = *(make_it + 1);
                for (auto it = half_it + 1; it != tok.end(); ++it) {
                    if (*it == "the" || *it == "a" || *it == "of") continue;
                    out.expression = *it + "/2";
                    break;
                }
            }
        }
    }

    if (out.kind != IntentKind::Unmatched) {
        // already matched app/view/query/variable
    }
    // --- Constraints ---
    else if (contains(tok, "flush") || contains(tok, "fasten") ||
             phrase_has(norm, "mate these") || phrase_has(norm, "make these flush")) {
        out = make(IntentKind::Model, "fasten");
        out.value = 0.0;
        out.unit = "mm";
    } else if (contains(tok, "horizontal") || phrase_has(norm, "make this horizontal") ||
             phrase_has(norm, "make it horizontal")) {
        out = make(IntentKind::Constraint, "horizontal");
    } else if (contains(tok, "vertical") || phrase_has(norm, "make this vertical") ||
               phrase_has(norm, "make it vertical")) {
        out = make(IntentKind::Constraint, "vertical");
    } else if (contains(tok, "parallel")) {
        out = make(IntentKind::Constraint, "parallel");
    } else if (contains(tok, "perpendicular") || contains(tok, "square")) {
        out = make(IntentKind::Constraint, "perpendicular");
    } else if (contains(tok, "tangent")) {
        out = make(IntentKind::Constraint, "tangent");
    } else if (contains(tok, "equal") || phrase_has(norm, "same length") ||
               phrase_has(norm, "same radius")) {
        out = make(IntentKind::Constraint, "equal");
    } else if (contains(tok, "coincident") || phrase_has(norm, "snap together") ||
               phrase_has(norm, "join these")) {
        out = make(IntentKind::Constraint, "coincident");
    } else if (contains(tok, "concentric")) {
        out = make(IntentKind::Constraint, "concentric");
    } else if (contains(tok, "lock") || contains(tok, "fixed") ||
               phrase_has(norm, "lock this down") || phrase_has(norm, "fix this")) {
        out = make(IntentKind::Constraint, "fix");
    } else if (contains(tok, "dimension") || contains(tok, "distance") ||
               (phrase_has(norm, "make this") && find_number(tok))) {
        // "dimension this to 40", "distance 25 mm", "make this 40"
        if (auto num = find_number(tok)) {
            if (contains(tok, "radius") || contains(tok, "diameter")) {
                out = make(IntentKind::Constraint, "radius");
                out.value = contains(tok, "diameter") ? num->value / 2.0 : num->value;
                out.unit = num->unit.empty() ? "mm" : num->unit;
            } else if (contains(tok, "angle") || num->unit == "deg") {
                out = make(IntentKind::Constraint, "angle");
                out.value = num->value;
                out.unit = "deg";
            } else {
                out = make(IntentKind::Constraint, "distance");
                out.value = num->value;
                out.unit = num->unit.empty() ? "mm" : num->unit;
            }
        } else if (contains(tok, "radius")) {
            out = make(IntentKind::Constraint, "radius");
        } else if (contains(tok, "angle")) {
            out = make(IntentKind::Constraint, "angle");
        } else {
            out = make(IntentKind::Constraint, "distance", 0.6f);
            out.needs_confirm = true;
        }
    } else if (contains(tok, "radius") && find_number(tok)) {
        auto num = find_number(tok);
        out = make(IntentKind::Constraint, "radius");
        out.value = num->value;
        out.unit = num->unit.empty() ? "mm" : num->unit;
    } else if (contains(tok, "angle") && find_number(tok)) {
        auto num = find_number(tok);
        out = make(IntentKind::Constraint, "angle");
        out.value = num->value;
        out.unit = "deg";
    }

    // --- Model ops ---
    else if (contains(tok, "fillet") || contains(tok, "round")) {
        out = make(IntentKind::Model, "fillet");
        if (auto num = find_number(tok)) {
            out.value = num->value;
            out.unit = num->unit.empty() ? "mm" : num->unit;
        } else {
            out.value = 1.0;
            out.unit = "mm";
            out.confidence = 0.7f;
        }
    } else if (contains(tok, "chamfer") || contains(tok, "bevel")) {
        out = make(IntentKind::Model, "chamfer");
        if (auto num = find_number(tok)) {
            out.value = num->value;
            out.unit = num->unit.empty() ? "mm" : num->unit;
        } else {
            out.value = 1.0;
            out.unit = "mm";
            out.confidence = 0.7f;
        }
    } else if (contains(tok, "shell") || contains(tok, "hollow")) {
        out = make(IntentKind::Model, "shell");
        if (auto num = find_number(tok)) {
            out.value = num->value;
            out.unit = num->unit.empty() ? "mm" : num->unit;
        } else {
            out.value = 1.0;
            out.unit = "mm";
            out.confidence = 0.7f;
        }
    } else if (contains(tok, "extrude") || phrase_has(norm, "pull this") ||
               phrase_has(norm, "push this")) {
        out = make(IntentKind::Model, "extrude");
        if (auto num = find_number(tok)) {
            out.value = num->value;
            out.unit = num->unit.empty() ? "mm" : num->unit;
        }
    } else if (contains(tok, "revolve") || contains(tok, "spin")) {
        out = make(IntentKind::Model, "revolve");
        if (auto num = find_number(tok)) {
            out.value = num->value;
            out.unit = num->unit.empty() ? "deg" : num->unit;
        } else {
            out.value = 360.0;
            out.unit = "deg";
        }
    } else if (contains(tok, "hole") || contains(tok, "drill")) {
        out = make(IntentKind::Model, "hole");
        // "hole M6" / "make a hole m6 here"
        for (const auto& t : tok) {
            if (t.size() >= 2 && (t[0] == 'm' || t[0] == 'M') &&
                std::isdigit(static_cast<unsigned char>(t[1]))) {
                out.name = t;  // thread/size token e.g. m6
                break;
            }
        }
        if (auto num = find_number(tok)) {
            out.value = num->value;
            out.unit = num->unit.empty() ? "mm" : num->unit;
        }
    } else if (contains(tok, "mirror")) {
        out = make(IntentKind::Model, "mirror");
    } else if (contains(tok, "isolate")) {
        out = make(IntentKind::Model, "isolate");
    } else if (contains(tok, "hide")) {
        out = make(IntentKind::Model, "hide");
    } else if (phrase_has(norm, "show all") || phrase_has(norm, "unhide") ||
               phrase_has(norm, "show everything")) {
        out = make(IntentKind::Model, "show_all");
    } else if (contains(tok, "delete") || contains(tok, "remove") ||
               phrase_has(norm, "get rid of")) {
        out = make(IntentKind::Model, "delete");
        out.needs_confirm = true;
    }

    // Fallthrough: maybe a bare number with prior sketch context implied — no.
    if (out.kind == IntentKind::Unmatched) {
        out.confidence = 0.f;
        out.prompt = "I don't know that command yet — try \"fillet this 3\" or "
                     "\"make this horizontal\". Unmatched asks are logged for the "
                     "future AI solver.";
    } else {
        out.raw_text = utterance;
        if (out.confidence <= 0.f) out.confidence = 1.f;
        attach_selection_prompt(out, selection);
        if (out.confidence < 0.75f) out.needs_confirm = true;
    }
    out.raw_text = utterance;
    return out;
}

}  // namespace sx::voice

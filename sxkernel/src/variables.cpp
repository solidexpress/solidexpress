#include "sx/variables.hpp"

#include <cctype>
#include <functional>
#include <set>
#include <stdexcept>

using nlohmann::json;

namespace sx {
namespace {

using Lookup = std::function<double(const std::string&)>;

struct Parser {
    const std::string& s;
    Lookup lookup;
    size_t i = 0;

    Parser(const std::string& expr, Lookup lu) : s(expr), lookup(std::move(lu)) {}

    void skip() {
        while (i < s.size() && std::isspace(static_cast<unsigned char>(s[i]))) ++i;
    }

    [[noreturn]] void error(const std::string& msg) const {
        throw std::runtime_error("expression error: " + msg + " at pos " +
                                 std::to_string(i));
    }

    double parse() {
        skip();
        double v = expr();
        skip();
        if (i != s.size()) error("unexpected trailing input");
        return v;
    }

    double expr() {
        double v = term();
        for (;;) {
            skip();
            if (i < s.size() && s[i] == '+') {
                ++i;
                v += term();
            } else if (i < s.size() && s[i] == '-') {
                ++i;
                v -= term();
            } else
                break;
        }
        return v;
    }

    double term() {
        double v = factor();
        for (;;) {
            skip();
            if (i < s.size() && s[i] == '*') {
                ++i;
                v *= factor();
            } else if (i < s.size() && s[i] == '/') {
                ++i;
                double d = factor();
                if (d == 0.0) error("division by zero");
                v /= d;
            } else
                break;
        }
        return v;
    }

    double factor() {
        skip();
        if (i < s.size() && s[i] == '-') {
            ++i;
            return -factor();
        }
        return primary();
    }

    double primary() {
        skip();
        if (i >= s.size()) error("unexpected end of expression");

        if (s[i] == '(') {
            ++i;
            double v = expr();
            skip();
            if (i >= s.size() || s[i] != ')') error("expected ')'");
            ++i;
            return v;
        }

        if (std::isdigit(static_cast<unsigned char>(s[i])) || s[i] == '.') {
            size_t start = i;
            while (i < s.size() &&
                   (std::isdigit(static_cast<unsigned char>(s[i])) || s[i] == '.'))
                ++i;
            try {
                return std::stod(s.substr(start, i - start));
            } catch (...) {
                error("invalid number");
            }
        }

        if (std::isalpha(static_cast<unsigned char>(s[i])) || s[i] == '_') {
            size_t start = i;
            ++i;
            while (i < s.size() &&
                   (std::isalnum(static_cast<unsigned char>(s[i])) || s[i] == '_'))
                ++i;
            return lookup(s.substr(start, i - start));
        }

        error("unexpected character");
    }
};

double eval_with_lookup(const std::string& expr, Lookup lookup) {
    return Parser(expr, std::move(lookup)).parse();
}

void resolve_value(json& j, const std::map<std::string, double>& env) {
    if (j.is_object()) {
        for (auto& [k, v] : j.items()) {
            (void)k;
            resolve_value(v, env);
        }
    } else if (j.is_array()) {
        for (auto& v : j) resolve_value(v, env);
    } else if (j.is_string()) {
        const std::string& s = j.get_ref<const std::string&>();
        if (!s.empty() && s[0] == '=') j = eval_expression(s.substr(1), env);
    }
}

}  // namespace

void VariableTable::set(const std::string& name, const std::string& expr) {
    for (auto& e : entries_) {
        if (e.first == name) {
            e.second = expr;
            return;
        }
    }
    entries_.emplace_back(name, expr);
}

bool VariableTable::remove(const std::string& name) {
    for (auto it = entries_.begin(); it != entries_.end(); ++it) {
        if (it->first == name) {
            entries_.erase(it);
            return true;
        }
    }
    return false;
}

bool VariableTable::contains(const std::string& name) const {
    return get(name) != nullptr;
}

const std::string* VariableTable::get(const std::string& name) const {
    for (const auto& e : entries_) {
        if (e.first == name) return &e.second;
    }
    return nullptr;
}

std::map<std::string, double> VariableTable::evaluate() const {
    std::map<std::string, double> cache;
    std::set<std::string> visiting;

    std::function<double(const std::string&)> eval_var =
        [&](const std::string& name) -> double {
        if (auto it = cache.find(name); it != cache.end()) return it->second;
        if (visiting.count(name))
            throw std::runtime_error("cyclic variable dependency: " + name);
        const std::string* expr = get(name);
        if (!expr) throw std::runtime_error("unknown variable: " + name);

        visiting.insert(name);
        double v = eval_with_lookup(*expr, eval_var);
        visiting.erase(name);
        cache[name] = v;
        return v;
    };

    for (const auto& e : entries_) eval_var(e.first);
    return cache;
}

json VariableTable::to_json() const {
    json j = json::object();
    for (const auto& e : entries_) j[e.first] = e.second;
    return j;
}

VariableTable VariableTable::from_json(const json& j) {
    VariableTable t;
    if (j.is_null()) return t;
    if (!j.is_object()) throw std::runtime_error("variables: expected object");
    for (auto it = j.begin(); it != j.end(); ++it) {
        if (!it.value().is_string())
            throw std::runtime_error("variables: expression must be string");
        t.set(it.key(), it.value().get<std::string>());
    }
    return t;
}

double eval_expression(const std::string& expr,
                       const std::map<std::string, double>& env) {
    return eval_with_lookup(expr, [&](const std::string& name) -> double {
        auto it = env.find(name);
        if (it == env.end()) throw std::runtime_error("unknown variable: " + name);
        return it->second;
    });
}

double num_param(const json& params, const char* key, double def,
                 const std::map<std::string, double>& env) {
    if (!params.contains(key)) return def;
    const json& v = params.at(key);
    if (v.is_number()) return v.get<double>();
    if (v.is_string()) {
        const std::string& s = v.get_ref<const std::string&>();
        if (!s.empty() && s[0] == '=') return eval_expression(s.substr(1), env);
        // Accept plain numeric strings (e.g. "12.5") as numbers.
        // We require full consumption (ignoring trailing whitespace).
        try {
            size_t pos = 0;
            double val = std::stod(s, &pos);
            // Skip any trailing whitespace
            while (pos < s.size() &&
                   std::isspace(static_cast<unsigned char>(s[pos]))) {
                ++pos;
            }
            if (pos == s.size()) return val;
        } catch (...) {
            // fallthrough to error below
        }
        throw std::runtime_error(std::string("param '") + key +
                                 "' string must be a number or start with '=' for expression");
    }
    throw std::runtime_error(std::string("param '") + key + "' is not numeric");
}

json resolve_params(json params, const std::map<std::string, double>& env) {
    resolve_value(params, env);
    return params;
}

}  // namespace sx

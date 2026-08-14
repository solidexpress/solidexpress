#pragma once
// Global variables / equations table: named expressions that feature params
// can reference (SolidWorks-style equations).
//
// Grammar (recursive descent):
//   expr   = term { ('+'|'-') term }
//   term   = factor { ('*'|'/') factor }
//   factor = '-' factor | primary
//   primary = number | ident | '(' expr ')'

#include <nlohmann/json.hpp>

#include <map>
#include <string>
#include <utility>
#include <vector>

namespace sx {

class VariableTable {
public:
    void set(const std::string& name, const std::string& expr);
    bool remove(const std::string& name);
    bool contains(const std::string& name) const;
    // nullptr if missing
    const std::string* get(const std::string& name) const;
    const std::vector<std::pair<std::string, std::string>>& entries() const {
        return entries_;
    }

    // Resolve all variables. Throws std::runtime_error on parse error,
    // missing reference, or cycle.
    std::map<std::string, double> evaluate() const;

    nlohmann::json to_json() const;
    static VariableTable from_json(const nlohmann::json& j);

private:
    // Insertion-ordered name -> expression.
    std::vector<std::pair<std::string, std::string>> entries_;
};

// Evaluate a single expression against an already-resolved environment.
double eval_expression(const std::string& expr,
                       const std::map<std::string, double>& env);

// Read a numeric feature param. Accepted forms:
// - plain JSON number
// - string starting with '=' evaluated as an expression against `env`
// - plain numeric string (e.g. "12.5", with optional surrounding whitespace)
double num_param(const nlohmann::json& params, const char* key, double def,
                 const std::map<std::string, double>& env);

// Deep-copy `params`, replacing every string value that starts with '=' with
// its evaluated numeric result.
nlohmann::json resolve_params(nlohmann::json params,
                              const std::map<std::string, double>& env);

}  // namespace sx

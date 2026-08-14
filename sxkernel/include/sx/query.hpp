#pragma once
// Selection query language (Wave 3): type= face created-by= <fid> adjacent-to= <id>

#include <string>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Document;

struct QueryHit {
    EntityId id;
    std::string kind;
};

// Parses a small query. Unknown clauses are ignored. Empty query → empty hits.
std::vector<QueryHit> run_query(const Document& doc, const std::string& query);

// One-sentence card digest from feature type + params.
std::string card_digest(const class Feature& f);

}  // namespace sx

#pragma once
// SolverBackend: the seam where constraint solving plugs in. PlaneGCS is the
// v1 numeric backend. The planned AI-first backend will consume the same
// Sketch (plus semantic cards for language-based references) and must be able
// to delegate to a numeric backend, so keep this interface small and
// stateless: solve mutates sketch parameters in place and reports diagnostics.

#include <memory>
#include <vector>

#include "sx/ids.hpp"

namespace sx {

class Sketch;

enum class SolveStatus { Success, Converged, Failed };

struct SolveResult {
    SolveStatus status = SolveStatus::Failed;
    int dofs = -1;  // remaining degrees of freedom (-1 = unknown)
    std::vector<EntityId> conflicting;  // constraints that conflict
    std::vector<EntityId> redundant;    // constraints that are redundant
    double residual = 0.0;              // max |constraint error| after solve
    bool ok() const { return status != SolveStatus::Failed; }
};

class SolverBackend {
public:
    virtual ~SolverBackend() = default;
    virtual const char* name() const = 0;
    // Solves the sketch's constraint system, writing solved parameter values
    // back into the sketch. Never throws; failures land in the result.
    virtual SolveResult solve(Sketch& sketch) = 0;
};

std::unique_ptr<SolverBackend> make_planegcs_backend();

}  // namespace sx

# Plan docs — where intent lives

Agents have limited context. **Do not keep “we should do this later” only in chat, a PR comment, or a transient plan file.** Write it into the file below that owns that kind of decision, then stop repeating it.

| Question | Permanent home |
|---|---|
| What to build, in what order, whose tool we copy | [roadmap.md](roadmap.md) + [../survey/tool-approaches.md](../survey/tool-approaches.md) (picks A1–A20) |
| How a feature must land (chrome budget, L1–L5, film id, slices) | [landing-protocol.md](landing-protocol.md) |
| What has already shipped | [STATUS.md](STATUS.md) |
| Architecture, licenses, `SolverBackend`, cards | [implementation-plan.md](implementation-plan.md) |
| What the market ships | [../survey/README.md](../survey/README.md) |
| How peers make actions visible | [../survey/interaction-patterns.md](../survey/interaction-patterns.md) |

## Parking a later idea

1. If it is a **capability** (new tool, environment, or track): add a row to the matching wave in [roadmap.md](roadmap.md), or to Wave 4 / the deferred list if it is not scheduled.
2. If it is **how it should look or be tested**: add chrome + a film id in [landing-protocol.md](landing-protocol.md).
3. If it **shipped**: tick [STATUS.md](STATUS.md) and point the roadmap row at the film / howto.
4. Do not invent a parallel doc. Do not leave the idea in conversation history.

Execute Wave 0 first. Later waves are fully specified in those two files so a fresh agent can resume without this chat.

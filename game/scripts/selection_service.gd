class_name SelectionService
extends RefCounted
## Multi-select set helpers used by DocumentView.
## DocumentView still owns the primary selection fields and arrays; this
## service centralizes toggle / clear / query mutations so selection logic
## can move off DocumentView incrementally.


## Add `id` if absent, remove if present. No-op for empty id.
func toggle_in(arr: Array[String], id: String) -> void:
	if id == "":
		return
	if arr.has(id):
		arr.erase(id)
	else:
		arr.append(id)


## Clear body / face / edge multi-select sets in place.
func clear_sets(bodies: Array[String], faces: Array[String],
		edges: Array[String]) -> void:
	bodies.clear()
	faces.clear()
	edges.clear()


## True when `body` is the primary body or listed in the multi-body set.
func body_selected(primary: String, bodies: Array[String], body: String) -> bool:
	return body != "" and (body == primary or bodies.has(body))


## Count of entities across sets; falls back to 1 when only primary is set.
func selection_count(bodies: Array[String], faces: Array[String],
		edges: Array[String], primary_body: String = "") -> int:
	var n := bodies.size() + faces.size() + edges.size()
	if n == 0 and primary_body != "":
		n = 1
	return n


## True when any multi-select set (or primary body) is non-empty.
func has_selection(bodies: Array[String], faces: Array[String],
		edges: Array[String], primary_body: String = "") -> bool:
	return selection_count(bodies, faces, edges, primary_body) > 0


## Most recent id in a set, or "" when empty.
func primary_from_set(arr: Array[String]) -> String:
	if arr.is_empty():
		return ""
	return arr.back()

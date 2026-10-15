class_name IntentResolver
extends RefCounted
## Finish defaults for a picked region. A host-face region is a cut
## through the body; a ground contour stays New / Blind. Bosses on a
## face keep the bar at New until the user picks a region.

static func on_body(host_face_id: String, target_fid: String) -> bool:
	return host_face_id != "" or target_fid != ""


static func finish_op(host_face_id: String, target_fid: String) -> String:
	return "cut" if on_body(host_face_id, target_fid) else "new"


static func finish_end(host_face_id: String, target_fid: String) -> String:
	return "through_all" if on_body(host_face_id, target_fid) else "blind"


static func apply_finish(chrome: SketchContextChrome, host_face_id: String, target_fid: String) -> void:
	if chrome == null:
		return
	chrome.set_finish_op(finish_op(host_face_id, target_fid))
	chrome.set_finish_end(finish_end(host_face_id, target_fid))

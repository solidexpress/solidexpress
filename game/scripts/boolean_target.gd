## Cut/fuse target resolution order.
## Session, then support host, then host-face body, then the only body.
class_name BooleanTarget
extends RefCounted

const POLICY: PackedStringArray = ["session", "support_host", "host_face", "sole_body"]


static func resolve(sm) -> String:
	for key in POLICY:
		var hit := _try_key(sm, str(key))
		if hit != "":
			return hit
	return ""


static func _try_key(sm, key: String) -> String:
	match key:
		"session":
			return sm.target_fid
		"support_host":
			return sm.support_host
		"host_face":
			return _from_host_face(sm)
		"sole_body":
			return _sole_body_feature(sm)
	return ""


static func _from_host_face(sm) -> String:
	if sm.host_face_id == "" or sm.view == null:
		return ""
	var body := ""
	if sm.view.has_method("body_of_face"):
		body = sm.view.body_of_face(sm.host_face_id)
	if body == "" and sm.view.has_method("body_of_feature"):
		body = sm.view.body_of_feature(sm.support_host)
	if body != "" and sm.view.has_method("feature_of_body"):
		return str(sm.view.feature_of_body(body))
	return ""


static func _sole_body_feature(sm) -> String:
	if sm.view == null or sm.view.doc == null or not sm.view.has_method("feature_of_body"):
		return ""
	var ids: PackedStringArray = sm.view.doc.body_ids()
	if ids.size() != 1:
		return ""
	return str(sm.view.feature_of_body(ids[0]))

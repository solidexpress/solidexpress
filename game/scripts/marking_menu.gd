class_name MarkingMenu
extends PopupPanel
## Hold-RMB / S-key pie for the current pick. Overflow, not a ribbon.

signal verb_picked(verb: String)
signal pick_chosen(entity_id: String)

var _verbs: PackedStringArray = PackedStringArray()
var _picks: Array = []  # {id, label}
var _col: VBoxContainer


func _ready() -> void:
	name = "MarkingMenu"
	_col = VBoxContainer.new()
	_col.name = "MarkingCol"
	add_child(_col)


func show_for(screen_pos: Vector2, verbs: PackedStringArray, picks: Array = []) -> void:
	_verbs = verbs
	_picks = picks
	for c in _col.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Marking"
	_col.add_child(title)
	for v in _verbs:
		var b := Button.new()
		b.text = v
		b.tooltip_text = v
		var verb := v
		b.pressed.connect(func() -> void:
			hide()
			verb_picked.emit(verb)
		)
		_col.add_child(b)
	if not _picks.is_empty():
		var sep := HSeparator.new()
		_col.add_child(sep)
		var pick_title := Label.new()
		pick_title.text = "Overlapping"
		_col.add_child(pick_title)
		for p in _picks:
			var id := str(p.get("id", ""))
			var label := str(p.get("label", id))
			var pb := Button.new()
			pb.text = label
			pb.tooltip_text = id
			pb.pressed.connect(func() -> void:
				hide()
				pick_chosen.emit(id)
			)
			_col.add_child(pb)
	position = Vector2i(screen_pos)
	popup()

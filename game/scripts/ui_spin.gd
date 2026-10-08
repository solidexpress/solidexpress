class_name SxUi
extends RefCounted
## Shared UI helpers. SpinBoxes use a fine step so typed values are not snapped
## to min+k*step (Godot Range default); arrows still move by `arrow_step`.

static func configure_spin(spin: SpinBox, min_v: float, max_v: float, arrow_step: float,
		value: float, as_int := false) -> SpinBox:
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1.0 if as_int else 0.001
	spin.custom_arrow_step = arrow_step
	spin.rounded = as_int
	spin.value = value
	# Focus selects the digits so a typed replacement (and Ctrl+A) edits the
	# number instead of appending, and instead of selecting scene bodies.
	spin.select_all_on_focus = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin


static func labeled_spin(parent: Container, text: String, min_v: float, max_v: float,
		arrow_step: float, value: float, as_int := false) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(64, 0)
	lbl.add_theme_font_size_override("font_size", UiScale.body())
	row.add_child(lbl)
	var spin := SpinBox.new()
	configure_spin(spin, min_v, max_v, arrow_step, value, as_int)
	row.add_child(spin)
	return spin


## Compact number for a SpinBox LineEdit: "10" / "1.5" / "0.05", never
## "10.000" which clips to look like "0.0 mm" in a narrow field.
static func compact_number(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	var s := "%.4f" % v
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


## Write the committed value into the LineEdit and pin the caret at the start
## so the leading digits stay visible (suffix "mm" must not scroll "10.0 mm"
## into a tail that reads "0.0 mm").
static func reveal_committed_spin(spin: SpinBox, v: float = NAN) -> void:
	if spin == null:
		return
	if is_nan(v):
		v = spin.value
	v = clampf(v, spin.min_value, spin.max_value)
	spin.set_value_no_signal(v)
	var le := spin.get_line_edit()
	if le == null:
		return
	# A live edit ("1." / "1.5") must not be snapped back to the committed
	# number. SpinBox parses "1." as 1 and would otherwise drop the dot.
	if le.is_editing():
		return
	var shown := compact_number(v)
	var suffix := str(spin.suffix)
	if suffix != "":
		shown += " " + suffix
	le.text = shown
	pin_line_start(le)
	pin_line_start.call_deferred(le)


static func pin_line_start(le: LineEdit) -> void:
	if le == null or not is_instance_valid(le):
		return
	le.caret_column = 0
	# SpinBoxLineEdit has no scroll_horizontal (Godot 4.7). caret_column 0 is
	# the public way to keep the leading digits in view.


## True when a LineEdit / SpinBox / TextEdit currently owns keyboard focus —
## view keys (1/2/3/7/W/H/D/…) must not fire.
static func numeric_field_focused(vp: Viewport) -> bool:
	if vp == null:
		return false
	var f := vp.gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is SpinBox \
			or (f != null and f.get_parent() is SpinBox)


## Opt-in: after Enter / an arrow click, give the viewport the keys back.
## Does not change `configure_spin` — property panels, dim blanks, and Extrude
## Distance keep today's keep-focus behaviour.
static func release_focus_on_commit(spin: SpinBox) -> void:
	if spin == null:
		return
	if spin.has_meta("_sx_release_focus_on_commit"):
		return
	spin.set_meta("_sx_release_focus_on_commit", true)
	var line := spin.get_line_edit()
	if line != null:
		line.text_submitted.connect(func(_t: String) -> void:
			# Commit handlers are connected first and have already read the
			# text. Release in this same signal so the focus border is gone
			# before the next key. A deferred release left the line looking
			# focused after LineEdit unedit(), and that next key was swallowed.
			release_line_now(line))
	# Arrow clicks only. A LineEdit gui_input uses line-local x, which is
	# greater than 68% of the spin on the right half of the text and was
	# released as if it were the arrow. The field then kept a selection
	# with no keyboard focus, so 1/0 and Ctrl+A hit the viewport.
	spin.gui_input.connect(func(event: InputEvent) -> void:
		_note_arrow_press(spin, line, event))
	spin.value_changed.connect(func(_v: float) -> void:
		if not _is_arrow_commit(spin, line):
			return
		if line != null:
			_queue_release_line(line)
		else:
			spin.release_focus.call_deferred())


static func _note_arrow_press(spin: SpinBox, line: LineEdit, event: InputEvent) -> void:
	if spin == null or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# gui_input.position is local to the control that received it.
	var local := mb.position
	if line != null:
		# A press on the text is typing, not an arrow. global_position is
		# the hit; line-local x compared to the spin width false-positives
		# on the right half of the digits.
		var lr: Rect2 = line.get_global_rect()
		var at := mb.global_position
		if at == Vector2.ZERO:
			at = lr.position + local
		if lr.has_point(at):
			return
	var on_arrow := local.x > spin.size.x * 0.68 and local.x <= spin.size.x + 2.0 \
			and local.y >= 0.0 and local.y <= spin.size.y
	if not on_arrow:
		return
	spin.set_meta("_sx_arrow_press", true)
	# SpinBox::_gui_input emits value_changed before this signal, so the
	# value_changed handler cannot see the meta yet. Viewport.push_input
	# also does not update get_global_mouse_position. Release from here.
	if line != null:
		_queue_release_line(line)
	else:
		spin.release_focus.call_deferred()


static func _is_arrow_commit(spin: SpinBox, line: LineEdit) -> bool:
	if spin == null:
		return false
	var marked := bool(spin.get_meta("_sx_arrow_press", false))
	if marked:
		spin.set_meta("_sx_arrow_press", false)
		return true
	# Typing: caret in the line and the text is not the committed value.
	if line != null and line.has_focus() and _line_mismatches_value(spin, line):
		return false
	var mouse_at := spin.get_global_mouse_position()
	var r: Rect2 = spin.get_global_rect()
	if not r.has_point(mouse_at):
		return false
	# Arrow gutter: right of the field. LMB-down is the real click; a parked
	# pointer over the arrows after a synthetic press still counts.
	return mouse_at.x >= r.position.x + r.size.x * 0.68


static func _line_mismatches_value(spin: SpinBox, line: LineEdit) -> bool:
	var raw := line.text.strip_edges().replace("mm", "").replace("MM", "").strip_edges()
	if not raw.is_valid_float():
		return true
	return not is_equal_approx(float(raw), spin.value)


static func _queue_release_line(line: LineEdit) -> void:
	if line == null:
		return
	var gen := int(line.get_meta("_sx_focus_claim", 0))
	_release_line_if_claim.call_deferred(line, gen)


static func _release_line_if_claim(line: LineEdit, gen: int) -> void:
	if line == null or not is_instance_valid(line):
		return
	if int(line.get_meta("_sx_focus_claim", 0)) != gen:
		return
	release_line_now(line)


## Drop keyboard focus and the selection together. A leftover select_all
## draws the "focused" look after the viewport has taken the keys back.
static func release_line_now(line: LineEdit) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.set_meta("_sx_focus_claim", int(line.get_meta("_sx_focus_claim", 0)) + 1)
	disarm_replace(line)
	if line.has_focus():
		line.release_focus()


## Click / tool arm: this line is the keyboard owner, even if a deferred
## arrow-release was already queued for the previous claim.
static func claim_keyboard_focus(line: LineEdit) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.set_meta("_sx_focus_claim", int(line.get_meta("_sx_focus_claim", 0)) + 1)
	if not line.has_focus():
		line.grab_focus()
	if line.has_focus() and not line.is_editing():
		line.edit()
	arm_replace_on_focus(line)


static func disarm_replace(line: LineEdit) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.set_meta("_sx_replace_armed", false)
	line.set_meta("_sx_select_gen", int(line.get_meta("_sx_select_gen", 0)) + 1)
	mark_mid_entry(line, false)
	line.deselect()


## True after a digit has landed in this focus session. Tool shortcuts and
## sketch redo must keep working until that happens (the field may already
## own focus because a tool armed it, or because a label editor just opened).
static func mark_mid_entry(line: LineEdit, on: bool) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.set_meta("_sx_mid_entry", on)


static func mid_entry(line: LineEdit) -> bool:
	return line != null and is_instance_valid(line) \
			and bool(line.get_meta("_sx_mid_entry", false))


static func focus_owner_mid_entry(vp: Viewport) -> bool:
	if vp == null:
		return false
	var f := vp.gui_get_focus_owner()
	return f is LineEdit and mid_entry(f as LineEdit)


## Built-in select_all_on_focus applies on mouse-up. That select can land
## after the first typed digit and turn "10" into "0". Callers select through
## arm_replace_on_focus, which a typed character cancels.
static func use_armed_replace_select(line: LineEdit) -> void:
	if line == null:
		return
	line.select_all_on_focus = false


## Enter keeps the caret. Godot otherwise unedit()s but leaves the focus
## border up, and every following digit is dropped (finish-bar Distance).
static func keep_editing_on_submit(line: LineEdit) -> void:
	if line == null:
		return
	line.keep_editing_on_text_submit = true


## After a commit, the line is still the focus owner. Make sure it is actually
## editing and that the next digit replaces the committed text.
static func rearm_replace_after_commit(line: LineEdit) -> void:
	if line == null or not is_instance_valid(line):
		return
	if line.has_focus() and not line.is_editing():
		line.edit()
	arm_replace_on_focus(line)


## Arm replace-on-next-key and select the current text one frame later.
## Never select_all synchronously from focus_entered — that re-enters Window
## focus and the deferred select used to eat the first typed digit.
static func arm_replace_on_focus(line: LineEdit) -> void:
	if line == null:
		return
	line.set_meta("_sx_replace_armed", true)
	var gen := int(line.get_meta("_sx_select_gen", 0)) + 1
	line.set_meta("_sx_select_gen", gen)
	_select_line_if_gen.call_deferred(line, gen)


static func replace_armed(line: LineEdit) -> bool:
	return line != null and is_instance_valid(line) \
			and bool(line.get_meta("_sx_replace_armed", false))


## Replace the line with `text`, caret at the end, and cancel any pending
## select_all. A deferred reassert puts the same characters back if a SpinBox
## reformats "2" into "2.00" without turning a later "20" back into "2".
static func write_typed_text(line: LineEdit, text: String) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.set_meta("_sx_replace_armed", false)
	var gen := int(line.get_meta("_sx_select_gen", 0)) + 1
	line.set_meta("_sx_select_gen", gen)
	line.set_meta("_sx_typed", text)
	mark_mid_entry(line, true)
	# SpinBox may rewrite "22." to "22" inside the text assignment. Put the
	# owned characters back before the function returns so the next key in
	# this same frame appends to "22." and not to "22".
	line.text = text
	if str(line.text) != text:
		line.text = text
	line.caret_column = text.length()
	line.deselect()
	# A text_changed handler may have disarmed the line while applying `text`.
	mark_mid_entry(line, true)
	_reassert_typed.call_deferred(line, text)


static func _select_line_if_gen(line: LineEdit, gen: int) -> void:
	if line == null or not is_instance_valid(line):
		return
	if int(line.get_meta("_sx_select_gen", 0)) != gen:
		return
	if not bool(line.get_meta("_sx_replace_armed", false)):
		return
	# Selection without keyboard focus looks editable while 1/0 and Ctrl+A
	# still hit the viewport. Only select once this line owns the keys.
	if not line.has_focus():
		return
	if not line.is_editing():
		line.edit()
	line.select_all()


static func _reassert_typed(line: LineEdit, _text: String) -> void:
	if line == null or not is_instance_valid(line):
		return
	# Later keys in the same frame already replaced the snapshot this call
	# was scheduled with. Restoring that snapshot is how a fast "45" / "22.5"
	# collapses back to the first character.
	var text := str(line.get_meta("_sx_typed", ""))
	if text == "":
		return
	var current := str(line.text)
	if current == text:
		if line.caret_column != text.length():
			line.caret_column = text.length()
			line.deselect()
		return
	# "1" then "." becomes "1." before this deferred reassert of "1".
	# Putting "1" back is how a typed 1.5 turns into 15.
	if _user_continued(current, text):
		return
	if not _is_reformat_of(current, text):
		return
	line.text = text
	line.caret_column = text.length()
	line.deselect()


## True when `current` is the typed snapshot plus characters the user added
## ("1" → "1." / "1.5" / "15"), not a zero-padded reformat ("2" → "2.00").
static func _user_continued(current: String, typed: String) -> bool:
	var c := _numeric_body(current)
	var t := _numeric_body(typed)
	if c == t or t == "" or not c.begins_with(t):
		return false
	return not _is_zero_padded(c, t)


## "2.00" / "1.50" are reformats. "1." and "15" are not.
static func _is_reformat_of(current: String, typed: String) -> bool:
	var c := _numeric_body(current)
	var t := _numeric_body(typed)
	if c == t:
		return true
	if c.ends_with(".") or t.ends_with("."):
		return false
	return _is_zero_padded(c, t)


static func _is_zero_padded(current: String, typed: String) -> bool:
	if not current.begins_with(typed) or current.length() == typed.length():
		return false
	var extra := current.substr(typed.length())
	if typed.contains("."):
		return extra.replace("0", "") == ""
	if not extra.begins_with("."):
		return false
	var frac := extra.substr(1)
	return frac != "" and frac.replace("0", "") == ""


## Next line body after one numeric key. Armed replace (or an existing
## selection) becomes just `ch`; otherwise `ch` is appended. Suffix stripped.
## A SpinBox may have padded the snapshot ("2" or "2." shown as "2.0"). Append
## to that snapshot so the next key makes "2.5", not "2.05".
static func compose_typed_char(line: LineEdit, ch: String) -> String:
	if line == null or ch == "":
		return ch
	if replace_armed(line):
		return ch
	if line.has_selection():
		return ch
	var body := _numeric_body(line.text)
	var typed := _numeric_body(str(line.get_meta("_sx_typed", "")))
	var base := body
	if typed != "" and _display_follows_typed(body, typed):
		base = typed
	return base + ch


## True when the visible body is the typed snapshot, a zero-pad of it
## ("2" / "2." → "2.0"), or a dropped trailing dot ("2." → "2").
static func _display_follows_typed(display: String, typed: String) -> bool:
	if display == typed or _is_zero_padded(display, typed):
		return true
	if typed.ends_with("."):
		var stem := typed.substr(0, typed.length() - 1)
		return display == stem or _is_zero_padded(display, stem)
	return false


## Digit, keypad digit, '.', or '-' from a key event. Empty when it is not one.
static func numeric_key_char(k: InputEventKey) -> String:
	if k == null:
		return ""
	var code := k.keycode
	if code >= KEY_0 and code <= KEY_9:
		return str(code - KEY_0)
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return str(code - KEY_KP_0)
	if code == KEY_PERIOD or code == KEY_KP_PERIOD:
		return "."
	if code == KEY_MINUS or code == KEY_KP_SUBTRACT:
		return "-"
	var ch := k.unicode
	if ch >= 48 and ch <= 57:
		return char(ch)
	if ch == 46 or ch == 45:
		return char(ch)
	return ""


## Same committed text in the strip and the Modify panel: "10 mm", "1.5 mm".
static func fmt_mm(v: float) -> String:
	return compact_number(v) + " mm"


## Keep a resting SpinBox line on `fmt_mm` ("2 mm", not Godot's "2.0 mm").
## Skips the line while it has focus so a partial type ("1.") is left alone.
static func pin_fmt_mm(spin: SpinBox) -> void:
	if spin == null or spin.has_meta("_sx_fmt_mm"):
		return
	spin.set_meta("_sx_fmt_mm", true)
	if str(spin.suffix).strip_edges() == "":
		spin.suffix = "mm"
	var line := spin.get_line_edit()
	if line == null:
		return
	line.text_changed.connect(func(new_text: String) -> void:
		_reassert_fmt_mm(spin, line, new_text))
	_reassert_fmt_mm(spin, line, line.text)


static func _reassert_fmt_mm(spin: SpinBox, line: LineEdit, new_text: String) -> void:
	if spin == null or line == null or not is_instance_valid(line):
		return
	if bool(spin.get_meta("_sx_fmt_mm_writing", false)):
		return
	if line.has_focus():
		return
	var want := fmt_mm(spin.value)
	if new_text == want:
		return
	spin.set_meta("_sx_fmt_mm_writing", true)
	line.text = want
	pin_line_start(line)
	spin.set_meta("_sx_fmt_mm_writing", false)


static func _numeric_body(raw: String) -> String:
	var text := raw.strip_edges()
	if text.ends_with(" mm"):
		text = text.substr(0, text.length() - 3)
	elif text.ends_with("mm"):
		text = text.substr(0, text.length() - 2)
	elif text.ends_with(" AF"):
		text = text.substr(0, text.length() - 3)
	return text.strip_edges().replace(",", ".")

class_name Shortcuts
## Thin wrapper over CommandRegistry so HelpOverlay / tests keep calling
## Shortcuts.* while the table lives in one place.


## Compat alias for callers that read Shortcuts.TABLE (film cue comments, etc.).
static var TABLE: Array[Dictionary]:
	get:
		return CommandRegistry.TABLE


static func all() -> Array[Dictionary]:
	return CommandRegistry.entries()


static func by_context() -> Dictionary:
	return CommandRegistry.by_context()


static func describe(keys: String) -> String:
	return CommandRegistry.describe(keys)

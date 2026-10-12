class_name ViewCache
extends RefCounted
## One cached query, replaced when its key changes.
## The automation bridge uses it for face and edge lists.


var key
var value


func fetch(new_key, build: Callable):
	if key != new_key:
		value = build.call()
		key = new_key
	return value

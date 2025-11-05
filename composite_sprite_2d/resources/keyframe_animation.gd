@tool
class_name KeyframeAnimation 
extends Resource

# I wish I could put these three arrays in a dictionary, but then they couldn't
# have a static type, and adding keyframes would be tedious because every possible
# type would show up in the dropdown in the Inspector.
@export var keyframes_up: Array[Vector2i] = []
@export var keyframes_down: Array[Vector2i] = []
@export var keyframes_side: Array[Vector2i] = []


func get_keyframes(facing: String) -> Array[Vector2i]:
	match facing.to_lower():
		"up":
			return keyframes_up
		"down":
			return keyframes_down
		"side":
			return keyframes_side
		_:
			print("Facing of %s is invalid" % facing)
			return []

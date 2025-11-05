@tool
class_name PuppetAnimation 
extends Resource

## Maps animation name to keyframes.
@export var animations: Dictionary[String, KeyframeAnimation]


func get_keyframes_facing(anim_name: String, facing: String) -> Array[Vector2i]:
	if not animations.has(anim_name):
		printerr("Puppet animation %s has no animation %s" % [self, anim_name])
		return []
	return animations[anim_name].get_keyframes(facing)

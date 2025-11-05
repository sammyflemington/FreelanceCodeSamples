@tool
class_name CompositeSpriteLayerPuppeted
extends CompositeSpriteLayer
## Allows you to move a sprite layer around using keyframes, as if it
## were a puppet.

@export var puppet_animations: PuppetAnimation : set = set_puppet_animations
@export var frame_rate : float = 5.0 ## Frames per second


## Puppet animation playback relies on the AnimatedSprite2D's frame_changed signal,
## so one-frame-long animations do not work correctly. This function is called by 
## CompositeSprite2D, and duplicates one frame in any single-frame animations.
func fix_one_frame_animations() -> void:
	for anim_name : String in animations.keys():
		for facing_anim_name : String in animations[anim_name].get_animation_names():
			if animations[anim_name].get_frame_count(facing_anim_name) == 1:
				var first_frame_texture : Texture2D = animations[anim_name].get_frame_texture(facing_anim_name, 0)
				animations[anim_name].add_frame(facing_anim_name, first_frame_texture)


func set_puppet_animations(_animations: PuppetAnimation) -> void:
	puppet_animations = _animations


func get_keyframe(anim_name: String, facing: String, index: int) -> Vector2i:
	return get_keyframes(anim_name, facing)[index]


func get_keyframes(anim_name: String, facing: String) -> Array[Vector2i]:
	return puppet_animations.get_keyframes_facing(anim_name, facing)

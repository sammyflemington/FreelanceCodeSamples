@tool
class_name CompositeSpriteLayer
extends Resource
## Holds animations to be used with CompositeSprite2D.
##
## Each animation ("walk", "idle") is mapped to a SpriteFrames that includes body type variations
## as well as directional variants (for facing up, down, or side). See CharacterSheetImporter.

## Emits signal "changed" whenever values are changed so that CompositeSprite2D can reflect
## changes while in-editor.

@export var layer_name : String = "Head" : 
	set(new_layer_name):
		layer_name = new_layer_name
		changed.emit()
## Key is animation name (i.e. "walk", "idle"), value is the spriteframes for this layer.
@export var animations: Dictionary[String, SpriteFrames] :
	set(new_animations):
		animations = new_animations
		changed.emit()

@export var takes_skin_tone : bool = false :
	set(new_takes_skin_tone):
		takes_skin_tone = new_takes_skin_tone
		changed.emit()
@export var visible : bool = true :
	set(new_visible):
		visible = new_visible
		changed.emit()

@export_category("Z values for walk directions")
@export var z_offset_up : int = 0 :
	set(new_offset):
		z_offset_up = new_offset
		changed.emit()
@export var z_offset_side: int = 0 :
	set(new_offset):
		z_offset_side = new_offset
		changed.emit()
@export var z_offset_down : int = 0 :
	set(new_offset):
		z_offset_down = new_offset
		changed.emit()


func get_animation_names() -> Array[String]:
	return animations.keys()


func get_variation_count() -> int:
	# NOTE: Assumes all animations (walk, idle) have the same number of variations.
	if len(animations) == 0:
		return 0
	var anim_base_name : String = animations.keys()[0]
	var frames : SpriteFrames = animations[anim_base_name]
	
	var max_variation_found : int = 0
	for anim_name : String in frames.get_animation_names():
		var variation : String = anim_name.split("_v")[-1]
		if int(variation) > max_variation_found:
			max_variation_found = int(variation)
	return max_variation_found + 1 # Add 1 because the variations begin at 0


func instantiate_sprite() -> AnimatedSubSprite2D:
	var sprite : AnimatedSubSprite2D = AnimatedSubSprite2D.new()
	sprite.z_as_relative = true
	sprite._layer = self
	return sprite


func get_z_offset_for_direction(facing: String) -> int:
	match facing.to_lower():
		"up":
			return z_offset_up
		"down":
			return z_offset_down
		"side":
			return z_offset_side
		_:
			return 0


static func format_animation_key(facing : String, body_variation : int = 0) -> String:
	return "%s_v%s" % [facing.to_lower(), body_variation]

@tool
@icon("res://assets/editor/composite_sprite_2d.svg")
class_name CompositeSprite2D
extends Node2D
## Controls animations for a character made from multiple layers, composited together. Also handles
## animation variations, such as for character customization.
##
## CompositeSprite2D is meant to mimic the functionality of AnimatedSprite2D.
## CompositeSpriteLayer represents one layer of this sprite. For example, the character's head has
## its own CompositeSpriteLayer, the body has its own layer, etc.
## You can add and remove CompositeSpriteLayers at runtime for things like equipping armor or new
## weapons using add_layer() and remove_layer()
## Use the Layer Variations dictionary to change variations / body types of each CompositeSpriteLayer.

## Each layer has a dictionary, 'animations', that holds the SpriteFrames for each animation (walk, idle, etc.).
## The spriteframes also hold the three directional variations of each animation for that layer.

# This node works by creating a child node, an AnimatedSprite2D, for each CompositeSpriteLayer. 
# When you play an animation on this node, it will
# 1) Check what the value of 'facing' is to determine which directional variation to use
# 2) Play the requested animation on all layers. If a layer is missing the desired animation, it is hidden.


# For some reason, even though "Nearest" is selected in project settings, getting
# this value from the project settings returns 0, even though 
# TextureFilter.TEXTURE_FILTER_NEAREST is equal to 1. So we have to hard-code it.
# ProjectSettings.get("rendering/textures/canvas_textures/default_texture_filter")
const DEFAULT_TEXTURE_FILTER : TextureFilter = TEXTURE_FILTER_NEAREST
const FAKE_Z_INDEX : String = "fake_z_index"

@export var current_animation : String = "" : set = _set_animation

@export var data : CompositeSpriteData : set = _set_data

@export var playing : bool = false : set = _set_playing

@export_range(0.0, 10.0, 0.01, "or_greater") var speed_scale : float = 1.0 : set = set_speed_scale
@export_enum("UP", "DOWN", "SIDE") var facing : String = "DOWN" : set = set_facing

@export_group("Customization")
## Gives control of variations (body types) by mapping layer_name to body_type.
@export var layer_variations : Dictionary[String, int] = {} : set = set_layer_variations
@export_color_no_alpha var skin_tone : Color = Color(1,1,1,1) : set = set_skin_tone

var _layer_sprite_map : Dictionary[CompositeSpriteLayer, AnimatedSubSprite2D] = {}


func _ready() -> void:
	for layer : CompositeSpriteLayer in data.get_layers():
		if layer is CompositeSpriteLayerPuppeted:
			layer.fix_one_frame_animations()
	
	set_texture_filter(DEFAULT_TEXTURE_FILTER)
	_set_data(data)
	if not data:
		return
	_create_child_sprites(data.get_layers())
	_set_animation(current_animation)
	set_facing(facing)
	set_skin_tone(skin_tone)
	set_speed_scale(speed_scale)
	_sort_sprites_by_fake_z_index()


## Play an animation, facing the direction specified by 'facing'.
func play(anim_name : String, _facing : String = facing) -> void:
	set_facing(_facing)
	current_animation = anim_name
	_set_playing(true)


## Stop the currently playing animation.
func stop() -> void:
	for sprite : AnimatedSubSprite2D in _layer_sprite_map.values():
		sprite.stop()


## Add a layer to this sprite.
func add_layer(layer : CompositeSpriteLayer) -> void:
	if data:
		data.add_layer(layer)


## Remove a layer from this sprite.
func remove_layer(layer: CompositeSpriteLayer) -> void:
	if data:
		data.remove_layer(layer)


## Set the facing direction ("up", "down", "side").
func set_facing(new_facing : String) -> void:
	# If facing is not changed, we don't need to call _sort_sprites_by_fake_z_index
	var facing_was_changed: bool = new_facing != facing
	facing = new_facing
	
	for layer : CompositeSpriteLayer in _layer_sprite_map.keys():
		var sprite : AnimatedSubSprite2D = _layer_sprite_map[layer]
		sprite.set_meta(FAKE_Z_INDEX, layer.get_z_offset_for_direction(facing))
	
	if facing_was_changed:
		_sort_sprites_by_fake_z_index()
	
	_set_animation(current_animation)


## Set the skin tone for skin-tone layers.
func set_skin_tone(new_tone : Color) -> void:
	skin_tone = new_tone
	for layer : CompositeSpriteLayer in get_layers():
		if layer.takes_skin_tone:
			_layer_sprite_map[layer].modulate = skin_tone
		else:
			_layer_sprite_map[layer].modulate = Color(1,1,1,1)


## Sets speed scale. Must be > 0
func set_speed_scale(new_speed_scale : float) -> void:
	speed_scale = max(0.0, new_speed_scale)
	for layer : CompositeSpriteLayer in get_layers():
		_layer_sprite_map[layer].speed_scale = speed_scale


## Set the variation of a given CompositeSpriteLayer. Automatically clamped to valid variations.
func set_layer_variation(layer: CompositeSpriteLayer, variation: int) -> void:
	variation = clamp(variation, 0, layer.get_variation_count() - 1)
	
	layer_variations[layer.layer_name] = variation
	notify_property_list_changed()


## Set multiple layer variations at once by their key strings.
func set_layer_variations(variations: Dictionary[String, int]) -> void:
	layer_variations.clear()
	# This double loop is not ideal but I don't anticipate us having more than 10 layers nor 
	# calling this very often, so it's fine for now
	for key : String in variations:
		for layer : CompositeSpriteLayer in get_layers():
			if layer.layer_name == key:
				set_layer_variation(layer, variations[key])
				break
	
	stop()
	_set_animation(current_animation)


## Returns all CompositeSpriteLayers on this CompositeSprite2D.
func get_layers() -> Array[CompositeSpriteLayer]:
	return _layer_sprite_map.keys()

#region private methods
# The following methods are not intended to be used outside of CompositeSprite2D.

func _create_child_sprites(layers: Array[CompositeSpriteLayer]) -> void:
	# Remove old sprite children
	for sprite : AnimatedSubSprite2D in _layer_sprite_map.values():
		sprite.queue_free()
	
	_layer_sprite_map.clear()
	
	# Create new children with new data
	for layer : CompositeSpriteLayer in layers:
		var sprite : AnimatedSubSprite2D = layer.instantiate_sprite()
		_layer_sprite_map[layer] = sprite
		_set_layer_visible(layer, layer.visible)
		sprite.name = "AnimatedSubSprite2D_" + layer.layer_name
		add_child(sprite)


## For CompositeSprite2D to work with y-sorting, all of its component
## sprites need to be on the same Z index. Therefore, we have to accomplish
## ordering by tree order.
func _sort_sprites_by_fake_z_index() -> void:
	var sprites : Array[AnimatedSubSprite2D] = _layer_sprite_map.values().duplicate()
	
	# Sort sprites by their fake z index metadata
	sprites.sort_custom(func(a: AnimatedSubSprite2D, b: AnimatedSubSprite2D) -> bool:
		return a.get_meta(FAKE_Z_INDEX) > b.get_meta(FAKE_Z_INDEX)
	)
	
	for sprite : AnimatedSubSprite2D in sprites:
		move_child(sprite, 0)


func _on_layers_changed(layers: Array[CompositeSpriteLayer]) -> void:
	_create_child_sprites(layers)
	
	for layer : CompositeSpriteLayer in layers:
		# If layer is not set yet, skip it.
		if not layer:
			continue
		if not layer.layer_name in layer_variations.keys():
			layer_variations[layer.layer_name] = 0
		
	_set_animation(current_animation)
	for layer : CompositeSpriteLayer in layers:
		_on_layer_updated(layer)
	_sort_sprites_by_fake_z_index()
	notify_property_list_changed()


func _on_layer_updated(layer: CompositeSpriteLayer) -> void:
	if not layer:
		return
	_set_layer_animation(layer, current_animation)
	set_facing(facing)
	set_skin_tone(skin_tone)
	set_speed_scale(speed_scale)
	_set_layer_visible(layer, layer.visible)


func _set_data(new_data : CompositeSpriteData) -> void:
	data = new_data
	if not data:
		_create_child_sprites([])
		layer_variations.clear()
		notify_property_list_changed()
		return
	
	if not data.layers_changed.is_connected(_on_layers_changed):
		data.layers_changed.connect(_on_layers_changed)
	if not data.layer_updated.is_connected(_on_layer_updated):
		data.layer_updated.connect(_on_layer_updated)
	_on_layers_changed(data.layers)


func _set_layer_visible(layer: CompositeSpriteLayer, vis: bool) -> void:
	_layer_sprite_map[layer].visible = vis


func _set_layer_animation(layer: CompositeSpriteLayer, anim_name : String) -> void:
	var sprite : AnimatedSubSprite2D = _layer_sprite_map[layer]
	
	sprite.set_active_animation(anim_name, facing, playing, layer_variations[layer.layer_name])
	
	if not playing:
		sprite.stop()


func _set_animation(anim_name : String) -> void:
	current_animation = anim_name
	
	for layer : CompositeSpriteLayer in get_layers():
		_set_layer_animation(layer, anim_name)


func _set_playing(tf: bool) -> void:
	playing = tf
	if playing:
		_set_animation(current_animation)
	else:
		stop()

#endregion

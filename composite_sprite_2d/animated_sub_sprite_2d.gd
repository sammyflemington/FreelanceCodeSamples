@tool
class_name AnimatedSubSprite2D
extends AnimatedSprite2D
## Handles the data provided by a CompositeSpriteLayer, such as parsing its animations,
## playing them, as well as handling special cases like CompositeSpriteLayerPuppeted

# Puppeting is handled by the signal frame_changed, because using AnimatedSprite2D's
# existing functionality was easier than re-creating it for puppet frames.
# Whenever frame_changed is emitted, the puppet frame increments by 1.

# The length of the puppet animation and the spriteframes animation need not be the same,
# but they will play independently if they are not.

var current_spriteframes_animation_name : String = ""
var tween : Tween

var _puppet_frame: int = 0
var _puppet_keyframes: Array[Vector2i] = []
var _layer : CompositeSpriteLayer : set = set_layer


func _ready() -> void:
	if _layer is CompositeSpriteLayerPuppeted:
		frame_changed.connect(next_puppet_frame)


func next_puppet_frame() -> void:
	if len(_puppet_keyframes) == 0:
		return
	
	if not _layer is CompositeSpriteLayerPuppeted:
		return
	
	_puppet_frame = (_puppet_frame + 1) % len(_puppet_keyframes)
	
	apply_puppet_frame()


func apply_puppet_frame() -> void:
	if not _layer is CompositeSpriteLayerPuppeted:
		return
	if len(_puppet_keyframes) <= _puppet_frame:
		return
	
	position = Vector2(_puppet_keyframes[_puppet_frame])


func set_layer(layer: CompositeSpriteLayer) -> void:
	_layer = layer


func set_active_animation(anim_name : String, facing: String, playing: bool = true, variant: int = 0) -> void:
	if _layer is CompositeSpriteLayerPuppeted:
		play_puppeted_animation(anim_name, facing, variant)
	elif _layer is CompositeSpriteLayer:
		play_spriteframes_animation(anim_name, facing, variant)
	
	if not playing:
		stop()


func play_spriteframes_animation(anim_name: String, facing: String, variant: int = 0) -> void:
	# anim_name specifies the high-level animation name, i.e. "walk" or "idle".
	# formatted_anim_name represents the animation name inside the SpriteFrames for the given anim_name, such as 'up_v0'
	var formatted_anim_name : String = CompositeSpriteLayer.format_animation_key(facing, variant)
	
	if _layer.animations.has(anim_name):
		sprite_frames = _layer.animations[anim_name]
	else:
		sprite_frames = null
	
	if sprite_frames:
		if sprite_frames.has_animation(formatted_anim_name):
			show()
			
			# Used to track when the animation changes, because the animation_changed signal
			# was not behaving as expected.
			var full_animation_name : String = anim_name + formatted_anim_name
			
			if full_animation_name != current_spriteframes_animation_name:
				stop()
				_on_animation_changed()
			
			play(formatted_anim_name)
			current_spriteframes_animation_name = full_animation_name
		else:
			hide()


func play_puppeted_animation(anim_name: String, facing: String, variant: int = 0) -> void:
	if _layer is CompositeSpriteLayerPuppeted:
		set_puppet_keyframes(_layer.get_keyframes(anim_name, facing))
	else:
		printerr("Can't play puppet animation without CompositeSpriteLayerPuppeted!")
	
	play_spriteframes_animation(anim_name, facing, variant)


func set_puppet_keyframes(new_keyframes: Array[Vector2i]) -> void:
	_puppet_keyframes = new_keyframes


func _on_animation_changed() -> void:
	_puppet_frame = 0
	apply_puppet_frame()

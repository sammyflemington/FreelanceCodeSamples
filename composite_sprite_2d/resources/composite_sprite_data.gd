@tool
class_name CompositeSpriteData
extends Resource
## Holds the CompositeSpriteLayers associated with a CompositeSprite2D for easy resource management.
##
## CompositeSpriteData can be saved as a single resource and all its CompositeSpriteLayers
## and their respective SpriteFrames will be saved along with it.
signal layers_changed(new_layers: Array[CompositeSpriteLayer])
signal layer_updated(layer: CompositeSpriteLayer)

@export var layers : Array[CompositeSpriteLayer] = [] :
	set = set_layers, get = get_layers


func _init(_layers: Array[CompositeSpriteLayer] = []) -> void:
	layers = _layers
	layers_changed.connect(_on_layers_changed)


func set_layers(new_layers: Array[CompositeSpriteLayer]) -> void:
	layers = new_layers
	layers_changed.emit(layers)


func add_layer(new_layer : CompositeSpriteLayer) -> void:
	layers.append(new_layer)
	layers_changed.emit(layers)


func remove_layer(layer: CompositeSpriteLayer) -> bool:
	if layer in layers:
		layer.changed.disconnect(layer_updated.emit)
		layers.erase(layer)
		layers_changed.emit(layers)
		return true
	return false


func get_layers() -> Array[CompositeSpriteLayer]:
	return layers


func _on_layers_changed(_layers: Array[CompositeSpriteLayer]) -> void:
	# Connect to signal to propagate changes in the editor
	for layer : CompositeSpriteLayer in layers:
		if not layer.changed.is_connected(layer_updated.emit):
			layer.changed.connect(layer_updated.emit.bind(layer))

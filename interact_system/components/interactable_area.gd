class_name InteractableArea
extends Area2D
## A component that can be interacted with. 
##
## Attach [class InteractAction]s as children and connect to their "activated" and "cancelled"
## signals (server-side) to create behavior.

## The name displayed on the interaction toolbar. i.e. "Door", "Chest", or the name of the NPC.
@export var object_name : String = ""

var _actions : Array[InteractAction] = [] : get = get_actions

var _collision_shapes : Array[CollisionShape2D] = []


func _ready() -> void:
	set_collision_layer_value(GameData.CollisionLayer.DEFAULT, false)
	set_collision_mask_value(GameData.CollisionLayer.DEFAULT, false)
	set_collision_mask_value(GameData.CollisionLayer.INTERACTABLES, true)
	set_collision_layer_value(GameData.CollisionLayer.INTERACTABLES, true)
	
	# Find actions and collision shapes
	for child : Node in get_children():
		if child is InteractAction:
			_actions.append(child)
		elif child is CollisionShape2D:
			_collision_shapes.append(child)


func disable() -> void:
	for shape : CollisionShape2D in _collision_shapes:
		shape.disabled = true


func enable() -> void:
	for shape : CollisionShape2D in _collision_shapes:
		shape.disabled = false


func get_actions() -> Array[InteractAction]:
	return _actions

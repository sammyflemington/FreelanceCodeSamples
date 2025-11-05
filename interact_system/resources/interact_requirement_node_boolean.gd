class_name InteractRequirementNodeBoolean
extends InteractRequirement
## You must add a signal that is emitted when property at [member property_name] is changed.
## This is how CharacterInteractArea knows to re-check requirements.

@export var node : NodePath
@export var property_name : String
@export var property_changed_signal_name : String
@export var required_value : bool


func initialize() -> void:
	super.initialize()
	# Watch for changes to property and emit requirement_updated if it changes.
	var property_changed_signal : Signal = owner_action.get_node(node).get_indexed(property_changed_signal_name)
	property_changed_signal.connect(requirement_updated.emit)


func character_meets_requirements(_character: Character) -> bool:
	return owner_action.get_node(node).get_indexed(property_name) == required_value


func get_requirement_description() -> Dictionary:
	return {}

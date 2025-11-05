class_name InteractRequirement
extends Resource
## Base class for defining requirements to perform an interaction with an object
## This class is meant to be extended for each type of requirement, such as 
## character class, having an item in inventory, etc.

## Emit this whenever something relevant to this requirement updates so that CharacterInteractArea
## can re-check requirements.
# This is needed for signals that come from interactables themselves, such as InteractRequirementNodeBoolean,
# because we can't hook into signals from CharacterInteractArea's Character.
signal requirement_updated

var owner_action : InteractAction = null


## Called by InteractAction after owner_action is set.
func initialize() -> void:
	pass


func character_meets_requirements(character: Character) -> bool:
	return false


## Currently not used for anything, but planned to display information to the player
## when they cannot perform an action. e.g. a tooltip that says "Requires Graveyard Key"
func get_requirement_description() -> Dictionary:
	return {}

class_name InteractRequirementItem
extends InteractRequirement


@export var item: Item


func character_meets_requirements(character: Character) -> bool:
	if character is Player:
		if character.inventory.has_item(item):
			return true
	
	return false


func get_requirement_description() -> Dictionary:
	return {
		"item": item
	}

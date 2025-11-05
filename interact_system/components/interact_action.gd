class_name InteractAction
extends Node
## Connect to [signal activated] and [signal cancelled] to create behavior.
##
## For examples, see npc.gd or door_lockable.tscn.

signal activated(character: Character, action_point_cost : int)
signal cancelled(character: Character)

signal requirement_updated

enum LogicType {
	ANY, ## Character must meet at least one requirement to perform this action
	ALL ## Character must meet ALL requirements to perform this action
}

#enum ActionKey {
	#NONE, ## No shortcut associated with this action
	#PRIMARY, ## Space bar
	#SECONDARY, ## Q key
#}

#enum ActionVisibility {
	#VISIBLE,
	#SECRET,
	#INTERNAL_ONLY
#}

enum ActionType {
	ONE_SHOT, ## Action is activated and that's it.
	CONTINUED ## Action is activated, and must be cancelled before starting a new action.
}

## Used to tell the player what action they are going to perform. TODO: Translations -- use the getter!
@export var display_name : String = "" : get = get_display_name
@export var requirements : Array[InteractRequirement] = []
@export var requirement_logic_type : LogicType = LogicType.ANY

## If true, player will be unable to move while performing this action
## until this action emits [signal cancelled].
## This functionality is handled by CharacterInteractArea.
@export var disables_player_movement : bool = false

# Preferred hotkey for this action.
#@export var hotkey : ActionKey = ActionKey.NONE

## If true, this action will not appear in interaction menus unless the requirements are met.
## Otherwise, it will appear but be grayed-out.
@export var is_secret : bool = false

## (NOT IMPLEMENTED) If true, this action will not appear in any menu, but can be activated through code.
#@export var is_internal_only : bool = false

@export var action_type : ActionType = ActionType.ONE_SHOT

## If true, this action will be activated instantly when a character walks over its InteractArea.
@export var auto_activate : bool = false

@export var action_point_cost : int = 0


func _ready() -> void:
	for requirement : InteractRequirement in requirements:
		requirement.owner_action = self
		requirement.requirement_updated.connect(self.requirement_updated.emit)
		requirement.initialize()


## Returns whether the action was successful (aka if requirements were met).
## Can be called by interactables (see NPC triggering quest menu) as long as the character is
## touching this InteractAction's InteractableArea.
func activate(character: Character) -> bool:
	if not Network.is_server_executing(get_path()):
		return false
	
	var meets_requirements : bool = character_meets_requirements(character)
	if meets_requirements:
		activated.emit(character, action_point_cost)
		return true
	
	return false


## Stops / finishes this interact action. Automatically called when the player exits the associated
## InteractableArea. [b]You must call this manually if action_type is CONTINUED and disables_player_movement
## is true![/b]
## Can be called by interactables (see NPC triggering quest menu) as long as the character is
## touching this InteractAction's InteractableArea.
func cancel(character: Character) -> void:
	if not Network.is_server_executing(get_path()):
		return
	cancelled.emit(character)


func character_meets_requirements(character: Character) -> bool:
	# If there are no requirements, they are always considered met.
	if requirements.is_empty():
		return true
	
	match requirement_logic_type:
		LogicType.ANY:
			# If the character meets any requirement, return true.
			for requirement : InteractRequirement in requirements:
				if requirement.character_meets_requirements(character):
					return true
			return false
		
		LogicType.ALL:
			# If the character fails any requirement, return false.
			for requirement : InteractRequirement in requirements:
				if not requirement.character_meets_requirements(character):
					return false
			return true
		
		_:
			return false


func get_requirement_description() -> Dictionary:
	return {}


func get_display_name() -> String:
	return display_name

@tool
class_name CharacterInteractArea
extends Area2D
## A component that manages interacting with InteractableAreas. 
##
## Make this a child of Character and set the Character property, and the rest is automatic.
## Call [method client_choose_action] client-side, or [method do_action] server-side
## to perform an action.


signal primary_hotkey_pressed()

const INTERACTION_TOOLBAR_SCN : PackedScene = preload("res://client/ui/interaction_toolbar/interaction_toolbar.tscn")

@export var character : Character :
	set(val):
		character = val
		update_configuration_warnings()

## Used to disable player movement for certain InteractActions. If null,
## this feature is ignored.
@export var input_synchronizer : PlayerInputSynchronizer

## Tracks the active action so that it can be cancelled when walking away
## from an NPC, for example.
var active_action : InteractAction = null

## Server-side only list of interactables touching me
var interactable_areas_touching: Array[InteractableArea] = []

## List of available actions maintained client-side. Used for hotkeys
var available_actions : Array[InteractAction] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		Utility.disable(self)
		return
	
	set_collision_layer_value(GameData.CollisionLayer.DEFAULT, false)
	set_collision_mask_value(GameData.CollisionLayer.DEFAULT, false)
	set_collision_mask_value(GameData.CollisionLayer.INTERACTABLES, true)
	set_collision_layer_value(GameData.CollisionLayer.INTERACTABLES, true)
	
	if Network.is_server_executing(get_path()):
		area_entered.connect(_on_area_entered)
		area_exited.connect(_on_area_exited)
	
	if character:
		character.action_request.connect(_on_character_action_request)
	
	# TODO: connect character's inventory_updated signal to update_all_action_requirements()

#region client
## Hotkey usage. This code runs client-side.
func _on_character_action_request(action : GameData.Action) -> void:
	match action:
		GameData.Action.USE:
			# Tell interact menu to choose the selected action
			primary_hotkey_pressed.emit()


@rpc("authority", "call_remote", "reliable")
func add_available_action(action_path: NodePath, meets_requirements: bool) -> void:
	if Network.is_server_executing(get_path()):
		return
	
	update_toolbar()
	
	var action : InteractAction = Network.get_client().get_node(action_path)
	
	available_actions.append(action)
	
	UI.push_update(UI.Update.ADD_ACTION, {"action": action, "meets_requirements": meets_requirements})


@rpc("authority", "call_remote", "reliable")
func update_action(action_path: NodePath, meets_requirements: bool) -> void:
	if Network.is_server_executing(get_path()):
		return
	
	var action : InteractAction = Network.get_client().get_node(action_path)
	
	UI.push_update(UI.Update.UPDATE_ACTION, {"action": action, "meets_requirements": meets_requirements})


@rpc("authority", "call_remote", "reliable")
func remove_available_interactable_area(area_path : NodePath) -> void:
	if Network.is_server_executing(get_path()):
		return
	
	# We remove all InteractArea's actions at once to reduce the number of RPCs
	var area: InteractableArea = Network.get_client().get_node(area_path)
	
	for action : InteractAction in area.get_actions():
		if action in available_actions:
			available_actions.erase(action)
	
	UI.push_update(UI.Update.REMOVE_INTERACTABLE, {"area": area})


func update_toolbar() -> void:
	# Create toolbar. NOTE: It is never freed. It is invisible when empty.
	var menu : InteractionToolbar = UI.add_menu_return_instance(INTERACTION_TOOLBAR_SCN)
	# If the menu exists already, add_menu_return_instance returns null.
	if menu:
		menu.action_chosen.connect(_on_interaction_toolbar_action_chosen)
		primary_hotkey_pressed.connect(menu._on_character_interact_area_primary_hotkey_pressed)


## Called when an action is chosen through the interaction toolbar menu.
func _on_interaction_toolbar_action_chosen(action: InteractAction) -> void:
	client_choose_action(action)


func client_choose_action(action : InteractAction) -> void:
	do_action.rpc_id(1, Network.get_client().get_path_to(action))


@rpc("authority", "call_remote", "reliable")
func client_set_has_active_action(has_active_action: bool) -> void:
	# Emit signal received by InteractionToolbar which tells it to enable / disable itself.
	UI.push_update(UI.Update.ENABLE_DISABLE_INTERACTION_TOOLBAR, {"has_active_action": has_active_action})

#endregion


#region server
# NOTE:
# Redesign idea: do_action calls action.activate()
# All actions touching this area are connected to _on_action_activated, which
# tracks the active action and connects the cancelled signal.
# This way we can activate actions through code on interactable objects if we want
## Runs server-side
@rpc("any_peer", "call_remote", "reliable")
func do_action(action_path: NodePath) -> bool:
	if not Network.is_server_executing(get_path()):
		return false
	
	if active_action:
		return false
	
	var action : InteractAction = Network.get_server().get_node(action_path)
	
	# Server-side check that this player is touching the area they are trying to activate
	# an action on. Prevents cheating by activating actions on objects they
	# aren't touching.
	if not action.get_parent() in interactable_areas_touching:
		return false
	
	# Will be false if the character doesn't meet requirements (which should have made
	# it impossible to select this action from the menu, but this covers edge cases)
	var success: bool = action.activate(character)
	
	return success


func set_active_action(new_action: InteractAction) -> void:
	# Prevent unnecessary RPCs
	if new_action == active_action:
		return
	
	active_action = new_action
	
	# Tell client to disable the action toolbar if active_action is not null,
	# or to enable it if active_action is null.
	client_set_has_active_action.rpc_id(character.multiplayer_id, active_action != null)


# TODO: Use the below function to update actions when inventory is updated.
## Re-checks requirements of all available actions and tells the client to update UI to 
## reflect any changes.
func update_all_action_requirements() -> void:
	if not Network.is_server_executing(get_path()):
		return
	
	for area : InteractableArea in interactable_areas_touching:
		for action : InteractAction in area.get_actions():
			update_action.rpc_id(character.multiplayer_id,
					Network.get_server().get_path_to(action),
					action.character_meets_requirements(character)
			)


func _on_action_requirement_updated(action: InteractAction) -> void:
	if not Network.is_server_executing(get_path()):
		return
	
	var meets_requirements: bool = action.character_meets_requirements(character)
	update_action.rpc_id(character.multiplayer_id, Network.get_server().get_path_to(action), meets_requirements)


func _on_action_activated(_character: Character, action_point_cost: int, action: InteractAction) -> void:
	match action.action_type:
		InteractAction.ActionType.ONE_SHOT:
			pass
		InteractAction.ActionType.CONTINUED:
			# We need to keep track of continued actions in the active_action member.
			set_active_action(action)
			# Disabling player movement if applicable
			if active_action.disables_player_movement:
				if input_synchronizer:
					input_synchronizer.disable_movement()


func _on_action_cancelled(_character: Character, action: InteractAction) -> void:
	# If this action was the active action, handle movement locking and resetting
	# active action.
	if action == active_action:
		if active_action.disables_player_movement:
			if input_synchronizer:
				input_synchronizer.enable_movement()
	
		set_active_action(null)


# NOTE: _on_area_entered and _on_area_exited are only connected to signals on SERVER SIDE
func _on_area_entered(area: Area2D) -> void:
	if area is InteractableArea:
		interactable_areas_touching.append(area)
		
		for action : InteractAction in area.get_actions():
			# Determine if this action should be available to this player
			var meets_requirements : bool = action.character_meets_requirements(character)
			
			# Connect action requirement re-check signals
			action.requirement_updated.connect(_on_action_requirement_updated.bind(action))
			
			action.activated.connect(_on_action_activated.bind(action))
			action.cancelled.connect(_on_action_cancelled.bind(action))
			
			# Trigger auto-activate actions (such as standing on a button)
			if action.auto_activate and meets_requirements:
				action.activate(character)
				return
			
			var hidden_action : bool = action.is_secret and not meets_requirements
			
			# Secret actions are not shown if you don't meet the requirements.
			if hidden_action:
				continue
			
			add_available_action.rpc_id(
					character.multiplayer_id,
					Network.get_server().get_path_to(action), 
					meets_requirements
			)


func _on_area_exited(area: Area2D) -> void:
	if area is InteractableArea:
		if area in interactable_areas_touching:
			interactable_areas_touching.erase(area)
			
			# Cancel active action if it comes from this InteractableArea.
			for action : InteractAction in area.get_actions():
				if action == active_action:
					action.cancel(character)
					continue
				# Also, we need to cancel any auto-activate actions.
				elif action.auto_activate:
					action.cancel(character)
			
			# Disconnect action signals
			for action : InteractAction in area.get_actions():
				# Requirement re-check signal
				if action.requirement_updated.is_connected(_on_action_requirement_updated):
					action.requirement_updated.disconnect(_on_action_requirement_updated)
				
				action.activated.disconnect(_on_action_activated)
				action.cancelled.disconnect(_on_action_cancelled)
			
			remove_available_interactable_area.rpc_id(
					character.multiplayer_id,
					Network.get_server().get_path_to(area)
			)
#endregion


#region utility
func get_can_interact() -> bool:
	return len(interactable_areas_touching) > 0
#endregion


#region configwarnings
func _get_configuration_warnings() -> PackedStringArray:
	var warnings : PackedStringArray = []
	if not character:
		warnings.append("character is not set!")
	return warnings
#endregion

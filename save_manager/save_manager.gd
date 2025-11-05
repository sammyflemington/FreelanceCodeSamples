extends Node
## Manages the creation of, writing to and reading from save data.
##
## Each save has 5 backups stored like a FIFO queue, each of which is created when saving the game.
## [br][br]Saving:
## [br]SaveManager supports two types of saves: [br]
## full_save() -> moves the current save to the end of the backup queue and saves the game state as save.json.
## quick_save() -> saves the game state to the main save file, but does not touch the backup files.
## [br][br]Loading:
## [br]The server is responsible for loading game state information. As SaveManager loads data, 
## the [signal load_data] signal is emitted. Game objects should connect to this signal to read
## data, and handle client-side replication on their own. See quest_manager.gd for an example.
## [br][br]
## Folder structure:
## [br]base directory: user://userdata/saves/
## [br]- metadata.cfg
## [br]- save folder 1
## [br]  - main save file, save.json
## [br]  - backup 1, backup 2, backup 3 etc. named "save_b1.json", "save_b2.json"...
## [br]       1 is the most recent backup.
## [br][br]
## TODO features include: a way to recover backups (without manually going into the file system). 

# Common failure modes to think about:
# A save file was deleted [tested - OK]
# A save folder was added without being added to metadata.cfg [will not be recognized]
# Trying to create a save with a name that is taken

## Connect to this signals to display UI (such as a saving icon)
signal saving_started()
## Emitted when saving completes.
signal saving_finished(error: Error)

## Emitted when [member _save_data_buffer] has been populated by game state.
## Used internally to control flow via await
signal save_buffer_populated()

## Connect to this signal and call [method add_save_section] to save a node's
## data.
signal save_data()

## Connect to this signal to load data when a save file is loaded by SaveManager.
## Check [code]if (node == self)[/code] to determine whether the data is meant for a given node.
## [br][br]
## [b]Does not guarantee that the node at specified NodePath exists![/b] To load data this
## way, the node at the specified NodePath must exist when the save file is loaded. Otherwise,
## read from [member active_save]
signal load_data(node: NodePath, data: Dictionary)

## Emitted when a save is created or deleted. Use for menus that display a list of saves.
signal save_files_changed()

const SAVES_DIR : String = "user://saves"
const BASE_SAVE_FILE : String = "save.json"
const BACKUP_SAVE_FILE_BASE : String = "save_b%s.json"
## Path to the .json save file for a fresh game save.
const NEW_GAME_SAVE_FILE_PATH : String = "res://server/data/new_game_save_file.json"

const METADATA_PATH : String = "user://saves/metadata.cfg"
const MD_SAVE_FOLDER_NAME : StringName = &"folder"
const MD_LAST_PLAYED : StringName = &"last_played"

## The number of backup files the game will store for each save
const BACKUP_COUNT : int = 5

## Metadata holds information about each save file on this machine. 
## Format: 
## [br] Section<save_name, i.e. "Sammy's Campaign"> :
## [br] - <MD_SAVE_FOLDER_NAME> : <save_1> 
## [br] - <MD_LAST_PLAYED> : <datetime_dict> 
## [br] - ...
## [br] Section<save_name_2> :
## [br] ...
var metadata : ConfigFile

## Holds data temporarily while it is being saved
var _save_data_buffer: Dictionary = {}

## Holds the currently active save data.
var active_save : Dictionary = {}
var active_save_name : String = ""


func _ready() -> void:
	# Ensure folder structure is correct
	verify_folder_structure()
	# Read saved metadata file
	load_metadata()
	# Used to send messages in the server gui
	saving_finished.connect(_on_saving_finished)


#region public
## Create a fresh save from the template save file, with a given or auto-generated name.
## _modifiers is a placeholder for when we add settings for a new save, like difficulty or
## challenge runs or anything of that nature.
func create_fresh_save(save_name : String = generate_new_save_name(), _modifiers: Dictionary = {}) -> Error:
	# Read template file
	var template_file : FileAccess = FileAccess.open(NEW_GAME_SAVE_FILE_PATH, FileAccess.READ)
	var contents : String = template_file.get_as_text()
	template_file.close()
	
	# If user://saves does not exist, error out.
	if !DirAccess.dir_exists_absolute(SAVES_DIR):
		printerr("User save folder does not exist! Cannot create new save.")
		return FAILED
	
	# This is the name given to the folder that holds the save files for this save
	var internal_save_name : String = save_name.to_snake_case()
	
	# Create folder for this save slot
	if !DirAccess.dir_exists_absolute(SAVES_DIR.path_join(internal_save_name)):
		DirAccess.make_dir_absolute(SAVES_DIR.path_join(internal_save_name))
	else:
		printerr("A save slot with name %s already exists! Cannot create fresh save." % internal_save_name)
		return FAILED
	
	# Create save.json file
	var save_file : FileAccess = FileAccess.open(SAVES_DIR.path_join(internal_save_name).path_join(BASE_SAVE_FILE), FileAccess.WRITE)
	if save_file:
		save_file.close()
	else:
		printerr("Could not create save file in directory %s" % internal_save_name)
		return FAILED
	
	# Create new metadata
	metadata.set_value(save_name, MD_SAVE_FOLDER_NAME, internal_save_name)
	metadata.set_value(save_name, MD_LAST_PLAYED, Time.get_datetime_dict_from_system())
	
	# Save the game data to the new file
	_save_data_buffer = JSON.parse_string(contents)
	_write_data_buffer_to_save(save_name, BASE_SAVE_FILE)
	metadata.save(METADATA_PATH)
	
	save_files_changed.emit()
	
	return OK


## Saves the game without updating the save's backup files.
func quick_save() -> void:
	if active_save_name.is_empty():
		printerr("Can't quick save when no save file is loaded!")
		return
	saving_started.emit()
	
	# Tell game objects to write game state to the buffer
	_save_game_to_buffer()
	await save_buffer_populated
	# Write the buffer's data to the main save file
	var err : Error = _write_data_buffer_to_save(active_save_name, BASE_SAVE_FILE)
	if err == OK:
		metadata.set_value(active_save_name, MD_LAST_PLAYED, Time.get_datetime_dict_from_system())
		metadata.save(METADATA_PATH)
		saving_finished.emit(OK)
	else:
		# Save failed for some reason
		saving_finished.emit(err)


## Saves the game and updates save backup files. Don't do this [i]too[/i] often, or the backups may become
## useless (because they are all very close to each other in time).
func full_save() -> void:
	if active_save_name.is_empty():
		printerr("Can't save when no save file is loaded!")
		return
	saving_started.emit()
	
	# Tell game objects to write game state to the buffer
	_save_game_to_buffer()
	await save_buffer_populated
	
	var save_folder_name : String = get_save_folder_name(active_save_name)
	if save_folder_name.is_empty():
		# This indicates bad metadata or trying to read a save that does not exist
		saving_finished.emit(FAILED)
		return
	
	# Delete the last backup in the queue
	var dir : DirAccess = DirAccess.open(SAVES_DIR.path_join(save_folder_name))
	dir.remove(BACKUP_SAVE_FILE_BASE % BACKUP_COUNT)
	
	# Rename backup save files 1-4 to 2-5
	for i : int in range(BACKUP_COUNT - 1, 0, -1):
		dir.rename(BACKUP_SAVE_FILE_BASE % i, BACKUP_SAVE_FILE_BASE % (i + 1))
	
	# Rename the old base save (save.json) to the first backup (save_b1.json)
	dir.rename(BASE_SAVE_FILE, BACKUP_SAVE_FILE_BASE % 1)
	
	# Finally, save the new game state to save.json
	var err : Error = _write_data_buffer_to_save(active_save_name, BASE_SAVE_FILE)
	if err == OK:
		metadata.set_value(active_save_name, MD_LAST_PLAYED, Time.get_datetime_dict_from_system())
		metadata.save(METADATA_PATH)
		saving_finished.emit(OK)
	else:
		saving_finished.emit(err)


## Load a save. Pass the backup file name to <file_name> to load a backup instead of the main
## save file.
func load_game(save_name : String, file_name : String = BASE_SAVE_FILE) -> Error:
	var save_folder_name : String = get_save_folder_name(save_name)
	if save_folder_name.is_empty():
		return ERR_FILE_NOT_FOUND
	
	# Read the requested save file into active_save dictionary
	var file : FileAccess = FileAccess.open(SAVES_DIR.path_join(save_folder_name).path_join(file_name), FileAccess.READ)
	if file:
		var txt : String = file.get_as_text()
		if txt.is_empty():
			return ERR_FILE_CORRUPT
		active_save = JSON.parse_string(txt)
		file.close()
	else:
		return ERR_CANT_OPEN
	
	# emit load_data signal for nodes to load their saved state.
	for node_path : NodePath in active_save.keys():
		var node : Node = get_node_or_null(node_path)
		if node:
			load_data.emit(node, active_save[str(node_path)])
		else:
			printerr("Could not find node at path specified: %s" % node_path)
	
	active_save_name = save_name
	UI.push_update(UI.Update.SERVER_LOG, {"msg": "Loaded save: %s" % save_name})
	return OK


## Moves a save folder to the OS trash can.
func delete_save(save_name: String) -> Error:
	var folder : String = get_save_folder_name(save_name)
	if folder.is_empty():
		return ERR_FILE_NOT_FOUND
	var user_relative_path : String = SAVES_DIR.path_join(folder)
	var error : Error = OS.move_to_trash(ProjectSettings.globalize_path(user_relative_path))
	
	if error == OK:
		# Remove metadata for the deleted save
		metadata.erase_section(save_name)
		metadata.save(METADATA_PATH)
	
		save_files_changed.emit()
	
	return error


## Any SERVER-SIDE node that needs to save data shold call this function upon receiving [signal save_data]
## to store its data.
func add_save_section(node: Node, data: Dictionary) -> void:
	var node_path : NodePath = node.get_path()
	_save_data_buffer[node_path] = data


## Returns a list of the names of save files to be used for selecting a save from a menu.
func get_save_names() -> Array[String]:
	var save_names : Array[String] = []
	for save_name : String in metadata.get_sections():
		save_names.append(save_name)
	return save_names


## Checks whether this save name is taken by another save. Use this for save file configuration menu
func is_save_name_valid(save_name : String) -> bool:
	return not (save_name in metadata.get_sections())

#endregion

#region helpers
## Write the contents of [member _save_data_buffer] to a file at <user_file_path>
func _write_data_buffer_to_file(user_file_path : String) -> Error:
	var dir : DirAccess = DirAccess.open("user://")
	dir.make_dir_recursive(SAVES_DIR)
	
	var file : FileAccess = FileAccess.open(user_file_path, FileAccess.WRITE_READ)
	var error : Error = OK
	if file:
		file.store_string(JSON.stringify(_save_data_buffer))
		file.close()
	else:
		error = FileAccess.get_open_error()
	
	_save_data_buffer.clear()
	return error


## Calls [method _write_data_buffer_to_file] inside the save folder associated with <save_name>.
func _write_data_buffer_to_save(save_name: String, file_name : String) -> Error:
	var save_folder_name : String = get_save_folder_name(save_name)
	if save_folder_name.is_empty():
		return ERR_FILE_NOT_FOUND
	var path : String = SAVES_DIR.path_join(save_folder_name).path_join(file_name)
	return _write_data_buffer_to_file(path)


## Tells game objects to save their states to [member _save_data_buffer] and emits [signal save_buffer_populated]
## upon completion.
func _save_game_to_buffer() -> void:
	_save_data_buffer.clear()
	save_data.emit()
	
	await get_tree().process_frame
	
	# Now _save_data_buffer should be populated with game data and is ready to be written to a file.
	save_buffer_populated.emit()


func _on_saving_finished(error: Error) -> void:
	if error == OK:
		UI.push_update(UI.Update.SERVER_LOG, {"msg": "Save successful."})
	else:
		UI.push_update(UI.Update.SERVER_LOG, {"msg": "Save failed with error code %s!" % error})


## Get the name of the folder associated with a given save.
func get_save_folder_name(save_name : String) -> String:
	if not metadata.has_section_key(save_name, MD_SAVE_FOLDER_NAME):
		return ""
	return metadata.get_value(save_name, MD_SAVE_FOLDER_NAME)


## Get the datetime dictionary of the last time a save was played (it's actually
## the last time the game was saved, but good enough.)
func get_save_last_played_datetime(save_name: String) -> Dictionary:
	if not metadata.has_section_key(save_name, MD_LAST_PLAYED):
		return {}
	return metadata.get_value(save_name, MD_LAST_PLAYED)


func load_metadata() -> void:
	metadata = ConfigFile.new()
	if metadata.load(METADATA_PATH) != OK:
		metadata.save(METADATA_PATH)


## Checks user save folder structure and creates required folders if they do not exist.
func verify_folder_structure() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)


## Generates a unique name for a new save.
func generate_new_save_name() -> String:
	var i : int = 0
	while not is_save_name_valid("Save %s" % i):
		i += 1
	return "Save %s" % i


# TODO: remove this, it's just for testing.
func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("gui_server"):
		if event is InputEventKey:
			if event.pressed:
				if event.keycode == KEY_Q:
					quick_save()
				elif event.keycode == KEY_L:
					load_game("Save 0")
				elif event.keycode == KEY_N:
					create_fresh_save()
				elif event.keycode == KEY_X:
					delete_save("Save 1")
				elif event.keycode == KEY_F:
					full_save()

#endregion

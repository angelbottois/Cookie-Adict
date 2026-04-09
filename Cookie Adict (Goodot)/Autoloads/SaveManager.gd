# autoloads/SaveManager.gd
extends Node

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1  # Incrementar si el formato cambia

# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------

func save_game() -> void:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"game": GameManager.get_save_data(),
		"shop": ShopManager.get_save_data(),
		"prestige": PrestigeManager.get_save_data(),
		"localization": LocalizationManager.get_save_data(),
	}

	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("SaveManager: no se pudo abrir el archivo para escribir — %s" % SAVE_PATH)
		return

	file.store_string(json_string)
	file.close()

# ---------------------------------------------------------------------------
# Carga
# ---------------------------------------------------------------------------

func load_game() -> void:
	if not has_save():
		push_warning("SaveManager: no hay archivo de guardado en %s" % SAVE_PATH)
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: no se pudo abrir el archivo para leer — %s" % SAVE_PATH)
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)

	if parse_result != OK:
		push_error("SaveManager: error al parsear JSON — línea %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	var save_data: Dictionary = json.get_data()

	if not _validate_save(save_data):
		push_error("SaveManager: archivo de guardado inválido o versión incompatible.")
		return

	# Restaurar cada sistema en orden (LocalizationManager primero para UI correcta)
	LocalizationManager.load_save_data(save_data.get("localization", {}))
	GameManager.load_save_data(save_data.get("game", {}))
	ShopManager.load_save_data(save_data.get("shop", {}))
	PrestigeManager.load_save_data(save_data.get("prestige", {}))

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func _validate_save(data: Dictionary) -> bool:
	if not data.has("version"):
		return false
	# Aquí se puede añadir migración entre versiones en el futuro
	if data["version"] != SAVE_VERSION:
		push_warning("SaveManager: versión del guardado (%d) distinta a la actual (%d)." % [data["version"], SAVE_VERSION])
		return false
	return true

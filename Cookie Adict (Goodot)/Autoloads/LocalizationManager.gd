# autoloads/LocalizationManager.gd
extends Node

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------
signal locale_changed(new_locale: String)

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
const SUPPORTED_LOCALES: Array[String] = ["es", "en"]
const DEFAULT_LOCALE: String = "es"

# ---------------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------------
var current_locale: String = DEFAULT_LOCALE

# ---------------------------------------------------------------------------
# Inicialización
# ---------------------------------------------------------------------------

func _ready() -> void:
	# El idioma se restaura desde SaveManager; aquí solo aplicamos el default
	_apply_locale(DEFAULT_LOCALE)

# ---------------------------------------------------------------------------
# Cambio de idioma
# ---------------------------------------------------------------------------

func set_locale(locale: String) -> void:
	if locale not in SUPPORTED_LOCALES:
		push_warning("LocalizationManager: locale '%s' no soportado." % locale)
		return

	if locale == current_locale:
		return

	current_locale = locale
	_apply_locale(locale)
	emit_signal("locale_changed", current_locale)

func toggle_locale() -> void:
	var next_index: int = (SUPPORTED_LOCALES.find(current_locale) + 1) % SUPPORTED_LOCALES.size()
	set_locale(SUPPORTED_LOCALES[next_index])

func _apply_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)

# ---------------------------------------------------------------------------
# Traducción
# ---------------------------------------------------------------------------

# Wrapper central: usar siempre este método en lugar de tr() directo
# para facilitar depuración y posibles extensiones futuras
func tr_key(key: String) -> String:
	var result: String = TranslationServer.translate(key)
	# Si la clave no tiene traducción, devuelve la propia clave para detectarla fácilmente
	if result == key:
		push_warning("LocalizationManager: clave sin traducción — '%s'" % key)
	return result

# Traducción con parámetros de sustitución
# Ejemplo: tr_format("ui.hud.day", {"day": 3}) -> "Día 3"
func tr_format(key: String, params: Dictionary) -> String:
	var text: String = tr_key(key)
	for param_key in params:
		text = text.replace("{%s}" % param_key, str(params[param_key]))
	return text

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

func get_current_locale() -> String:
	return current_locale

func get_locale_display_name() -> String:
	match current_locale:
		"es": return "Español"
		"en": return "English"
		_: return current_locale.to_upper()

# ---------------------------------------------------------------------------
# Serialización (llamado por SaveManager)
# ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"locale": current_locale,
	}

func load_save_data(data: Dictionary) -> void:
	var saved_locale: String = data.get("locale", DEFAULT_LOCALE)
	set_locale(saved_locale)

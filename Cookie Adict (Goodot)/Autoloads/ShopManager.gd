# autoloads/ShopManager.gd
extends Node

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------
signal item_purchased(category: String, level: int)
signal pet_changed(pet_id: String)
signal shop_updated()

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------
const CATEGORIES: Array[String] = ["container", "sign", "rest_zone"]
const MAX_LEVEL: int = 8

# Costes base de cada nivel por categoría (índice 0 = nivel 1)
# Ajustables en fase de balanceo
const ITEM_COSTS: Dictionary = {
	"container":  [5.0, 15.0, 40.0, 100.0, 250.0, 600.0, 1500.0, 4000.0],
	"sign":       [5.0, 15.0, 40.0, 100.0, 250.0, 600.0, 1500.0, 4000.0],
	"rest_zone":  [5.0, 15.0, 40.0, 100.0, 250.0, 600.0, 1500.0, 4000.0],
}

# Bonuses de cada nivel por categoría (como multiplicador: 0.05 = +5%)
const ITEM_EFFECTS: Dictionary = {
	"container":  [0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.18, 0.25],
	"sign":       [0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.18, 0.25],
	"rest_zone":  [0.01, 0.02, 0.03, 0.05, 0.08, 0.12, 0.18, 0.25],
}

# Costes de mascotas
const PET_COSTS: Dictionary = {
	"dog":  200.0,
	"cat":  200.0,
	"parrot": 350.0,
	"rat":  500.0,
}

# ---------------------------------------------------------------------------
# Estado persistente
# ---------------------------------------------------------------------------

# Nivel comprado actualmente en cada categoría (0 = ninguno comprado)
var purchased_items: Dictionary = {
	"container": 0,
	"sign":      0,
	"rest_zone": 0,
}

# Nivel máximo que el jugador ha visto alguna vez en cada categoría
# (persiste tras Prestige para mantener visibilidad en tienda)
var discovered_items: Dictionary = {
	"container": 1,
	"sign":      1,
	"rest_zone": 1,
}

var active_pet: String = ""               # ID de la mascota activa (vacío = ninguna)
var purchased_pets: Array[String] = []    # Mascotas ya compradas (persisten tras Prestige)

# ---------------------------------------------------------------------------
# Inicialización
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Esperar a que GameManager esté listo antes de aplicar efectos iniciales
	await get_tree().process_frame
	_apply_all_effects()

# ---------------------------------------------------------------------------
# Compra de objetos
# ---------------------------------------------------------------------------

func can_purchase_item(category: String) -> bool:
	if not category in CATEGORIES:
		return false
	var current_level: int = purchased_items[category]
	if current_level >= MAX_LEVEL:
		return false
	var cost: float = get_next_item_cost(category)
	return GameManager.money >= cost

func purchase_item(category: String) -> bool:
	if not can_purchase_item(category):
		return false

	var next_level: int = purchased_items[category] + 1
	var cost: float = get_next_item_cost(category)

	GameManager.money -= cost
	purchased_items[category] = next_level

	# Actualizar nivel descubierto si corresponde
	var discovered_next: int = next_level + 1
	if discovered_next <= MAX_LEVEL:
		discovered_items[category] = max(discovered_items[category], discovered_next)

	_apply_category_effect(category)
	emit_signal("item_purchased", category, next_level)
	emit_signal("shop_updated")
	return true

# ---------------------------------------------------------------------------
# Compra de mascotas
# ---------------------------------------------------------------------------

func can_purchase_pet(pet_id: String) -> bool:
	if pet_id in purchased_pets:
		return false
	if not pet_id in PET_COSTS:
		return false
	return GameManager.money >= PET_COSTS[pet_id]

func purchase_pet(pet_id: String) -> bool:
	if not can_purchase_pet(pet_id):
		return false

	GameManager.money -= PET_COSTS[pet_id]
	purchased_pets.append(pet_id)
	set_active_pet(pet_id)
	return true

func set_active_pet(pet_id: String) -> void:
	# Quitar efecto de la mascota anterior
	if active_pet != "":
		_remove_pet_effect(active_pet)

	active_pet = pet_id

	# Aplicar efecto de la nueva mascota
	if active_pet != "":
		_apply_pet_effect(active_pet)

	emit_signal("pet_changed", active_pet)
	emit_signal("shop_updated")

# ---------------------------------------------------------------------------
# Getters de utilidad para la UI
# ---------------------------------------------------------------------------

func get_next_item_cost(category: String) -> float:
	var current_level: int = purchased_items[category]
	if current_level >= MAX_LEVEL:
		return -1.0  # Ya en nivel máximo
	return ITEM_COSTS[category][current_level]

func get_current_item_effect(category: String) -> float:
	var current_level: int = purchased_items[category]
	if current_level == 0:
		return 0.0
	return ITEM_EFFECTS[category][current_level - 1]

func get_total_effect(category: String) -> float:
	# Suma acumulada de todos los niveles comprados
	var total: float = 0.0
	var current_level: int = purchased_items[category]
	for i in range(current_level):
		total += ITEM_EFFECTS[category][i]
	return total

func is_item_visible(category: String, level: int) -> bool:
	return level <= discovered_items[category]

func is_max_level(category: String) -> bool:
	return purchased_items[category] >= MAX_LEVEL

# ---------------------------------------------------------------------------
# Aplicación de efectos sobre GameManager
# ---------------------------------------------------------------------------

func _apply_all_effects() -> void:
	for category in CATEGORIES:
		_apply_category_effect(category)
	if active_pet != "":
		_apply_pet_effect(active_pet)

func _apply_category_effect(category: String) -> void:
	# Recalcular desde cero para evitar acumulación incorrecta
	# GameManager expone multiplicadores base; ShopManager los sobreescribe con el total
	match category:
		"container":
			GameManager.donation_value_multiplier = 1.0 + get_total_effect("container")
		"sign":
			# donation_chance incluye la base (1%) más el bonus acumulado
			GameManager.donation_chance = 0.01 + get_total_effect("sign")
		"rest_zone":
			GameManager.event_chance = GameManager.BASE_EVENT_CHANCE + get_total_effect("rest_zone")
	GameManager.emit_signal("stats_recalculated")

func _apply_pet_effect(pet_id: String) -> void:
	match pet_id:
		"dog":
			GameManager.passersby_per_second += GameManager.PET_DOG_BONUS
		"cat":
			GameManager.donation_value_multiplier += GameManager.PET_CAT_BONUS
		"parrot":
			GameManager.event_chance += GameManager.PET_PARROT_BONUS
		"rat":
			GameManager.rat_duplicate_chance = GameManager.PET_RAT_BASE_CHANCE
	GameManager.emit_signal("stats_recalculated")

func _remove_pet_effect(pet_id: String) -> void:
	match pet_id:
		"dog":
			GameManager.passersby_per_second -= GameManager.PET_DOG_BONUS
		"cat":
			GameManager.donation_value_multiplier -= GameManager.PET_CAT_BONUS
		"parrot":
			GameManager.event_chance -= GameManager.PET_PARROT_BONUS
		"rat":
			GameManager.rat_duplicate_chance = 0.0
	GameManager.emit_signal("stats_recalculated")

# ---------------------------------------------------------------------------
# Prestige: resetear compras pero conservar descubrimientos y mascotas
# ---------------------------------------------------------------------------

func reset_for_prestige() -> void:
	for category in CATEGORIES:
		purchased_items[category] = 0
		# discovered_items se conserva intencionalmente

	# Las mascotas compradas se conservan; solo se desactiva la activa
	# (el jugador tendrá que reactivarla comprándola de nuevo si fue gratis,
	#  o simplemente seleccionarla si ya la tiene — a definir en diseño)
	active_pet = ""

	# Recalcular efectos con todo a 0 (resetea multiplicadores en GameManager)
	_apply_all_effects()
	emit_signal("shop_updated")

# ---------------------------------------------------------------------------
# Serialización (llamado por SaveManager)
# ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"purchased_items": purchased_items.duplicate(),
		"discovered_items": discovered_items.duplicate(),
		"active_pet": active_pet,
		"purchased_pets": purchased_pets.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	purchased_items = data.get("purchased_items", purchased_items)
	discovered_items = data.get("discovered_items", discovered_items)
	active_pet = data.get("active_pet", "")
	purchased_pets = data.get("purchased_pets", [])
	_apply_all_effects()
	emit_signal("shop_updated")

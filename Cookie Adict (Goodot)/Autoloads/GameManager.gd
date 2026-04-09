extends Node

# ---------------------------------------------------------------------------
# SEÑALES
# ---------------------------------------------------------------------------
signal money_changed(new_value: float)
signal cookies_changed(new_amount: int)
signal penalty_started()
signal penalty_ended()
signal stats_recalculated()

# ---------------------------------------------------------------------------
# CONSTANTES BASE
# ---------------------------------------------------------------------------
const BASE_PASSERSBY_PER_SECOND: float = 10.0
const BASE_DONATION_CHANCE: float = 0.01       # 1%
const BASE_EVENT_CHANCE: float = 0.005         # 0.5% por transeúnte
const BASE_COOKIE_COST: float = 2.0
const BASE_COOKIE_CONSUMPTION_RATE: float = 1.0  # galletas/día (ajustar en balanceo)
const PENALTY_DONATION_CHANCE_MULT: float = 0.5
const PENALTY_VALUE_MULT: float = 0.5
const PENALTY_EVENT_MULT: float = 0.5

# ---------------------------------------------------------------------------
# TABLA DE PROBABILIDADES DE DONACIÓN
# { valor_en_euros: probabilidad_base }
# ---------------------------------------------------------------------------
const DONATION_TABLE: Array = [
	{ "value": 0.10, "chance": 0.8000 },
	{ "value": 0.20, "chance": 0.1000 },
	{ "value": 0.50, "chance": 0.0900 },
	{ "value": 1.00, "chance": 0.0090 },
	{ "value": 2.00, "chance": 0.0010 },
	{ "value": 5.00, "chance": 0.0000 },
	{ "value": 10.00, "chance": 0.0000 },
	{ "value": 20.00, "chance": 0.0000 },
	{ "value": 50.00, "chance": 0.0000 },
	{ "value": 100.00, "chance": 0.0000 },
	{ "value": 200.00, "chance": 0.0000 },
	{ "value": 500.00, "chance": 0.0000 },
]

# ---------------------------------------------------------------------------
# ESTADO DEL JUEGO
# ---------------------------------------------------------------------------
var money: float = 0.0
var cookies_stock: int = 0
var income_rate: float = 0.0           # €/segundo (calculado, solo lectura externa)
var game_day: int = 1
var is_penalized: bool = false
var bills_unlocked: bool = false

# Parámetros que combinan base + bonificaciones de objetos/mascotas/prestige
var passersby_per_second: float = BASE_PASSERSBY_PER_SECOND
var donation_chance: float = BASE_DONATION_CHANCE
var donation_value_multiplier: float = 1.0
var event_chance: float = BASE_EVENT_CHANCE
var cookie_consumption_rate: float = BASE_COOKIE_CONSUMPTION_RATE

# Tabla activa (copia modificable de DONATION_TABLE)
var active_donation_table: Array = []

# ---------------------------------------------------------------------------
# ACUMULADOR INTERNO para consumo de galletas
# ---------------------------------------------------------------------------
var _cookie_consumption_accumulator: float = 0.0
var _game_day_duration: float = 60.0   # segundos de juego = 1 día (ajustar en balanceo)
var _day_timer: float = 0.0

# ---------------------------------------------------------------------------
# READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	active_donation_table = DONATION_TABLE.duplicate(true)

# ---------------------------------------------------------------------------
# PROCESS — solo gestiona el día de juego y el consumo de galletas
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if get_tree().paused:
		return

	_day_timer += delta
	if _day_timer >= _game_day_duration:
		_day_timer -= _game_day_duration
		_advance_game_day()

# ---------------------------------------------------------------------------
# DINERO
# ---------------------------------------------------------------------------
func add_money(amount: float) -> void:
	money += amount
	money_changed.emit(money)

func spend_money(amount: float) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

# ---------------------------------------------------------------------------
# GALLETAS
# ---------------------------------------------------------------------------
func add_cookies(amount: int) -> void:
	cookies_stock += amount
	cookies_changed.emit(cookies_stock)
	if is_penalized and cookies_stock > 0:
		_end_penalty()

func consume_cookies(amount: int) -> void:
	cookies_stock = max(0, cookies_stock - amount)
	cookies_changed.emit(cookies_stock)
	if cookies_stock == 0 and not is_penalized:
		_start_penalty()

# ---------------------------------------------------------------------------
# PENALIZACIÓN
# ---------------------------------------------------------------------------
func _start_penalty() -> void:
	is_penalized = true
	penalty_started.emit()
	recalculate_stats()

func _end_penalty() -> void:
	is_penalized = false
	penalty_ended.emit()
	recalculate_stats()

# ---------------------------------------------------------------------------
# DÍAS DE JUEGO Y CONSUMO DE GALLETAS
# ---------------------------------------------------------------------------
func _advance_game_day() -> void:
	game_day += 1
	# El consumo escala levemente con los días (ajustar curva en balanceo)
	var to_consume: int = int(cookie_consumption_rate)
	consume_cookies(to_consume)

# ---------------------------------------------------------------------------
# RECÁLCULO DE ESTADÍSTICAS DERIVADAS
# Llamar tras cualquier cambio de bonificaciones (compra de objeto, mascota, prestige)
# ---------------------------------------------------------------------------
func recalculate_stats() -> void:
	var penalty_mult: float = PENALTY_DONATION_CHANCE_MULT if is_penalized else 1.0

	# income_rate es aproximado: transeúntes/s * % donan * valor medio ponderado
	var mean_donation: float = _calculate_mean_donation()
	income_rate = passersby_per_second * (donation_chance * penalty_mult) \
				* mean_donation * donation_value_multiplier

	stats_recalculated.emit()

func _calculate_mean_donation() -> float:
	var total: float = 0.0
	var weight_sum: float = 0.0
	for entry in active_donation_table:
		total += entry["value"] * entry["chance"]
		weight_sum += entry["chance"]
	if weight_sum == 0.0:
		return 0.0
	return total / weight_sum

# ---------------------------------------------------------------------------
# DONACIÓN — llamado por Passerby al pasar junto al mendigo
# ---------------------------------------------------------------------------
func roll_donation() -> float:
	var penalty_mult: float = PENALTY_VALUE_MULT if is_penalized else 1.0
	var effective_chance: float = donation_chance \
		* (PENALTY_DONATION_CHANCE_MULT if is_penalized else 1.0)

	if randf() > effective_chance:
		return 0.0

	var amount: float = _roll_donation_value() * donation_value_multiplier * penalty_mult
	add_money(amount)
	return amount

func _roll_donation_value() -> float:
	# Si los billetes no están desbloqueados, limita a valores <= 2 €
	var table: Array = active_donation_table if bills_unlocked \
		else active_donation_table.filter(func(e): return e["value"] <= 2.0)

	var roll: float = randf()
	var cumulative: float = 0.0
	for entry in table:
		cumulative += entry["chance"]
		if roll <= cumulative:
			return entry["value"]

	# Fallback al valor más bajo
	return table[0]["value"]

# ---------------------------------------------------------------------------
# EVENTO ESPECIAL — ¿aparece transeúnte generoso?
# ---------------------------------------------------------------------------
func roll_special_event() -> bool:
	var effective_chance: float = event_chance \
		* (PENALTY_EVENT_MULT if is_penalized else 1.0)
	return randf() < effective_chance

# ---------------------------------------------------------------------------
# RESET (usado por Prestige)
# ---------------------------------------------------------------------------
func reset_for_prestige() -> void:
	money = 0.0
	cookies_stock = 0
	is_penalized = false
	game_day = 1
	_day_timer = 0.0

	# Los parámetros derivados se recalcularán desde ShopManager y PrestigeManager
	passersby_per_second = BASE_PASSERSBY_PER_SECOND
	donation_chance = BASE_DONATION_CHANCE
	donation_value_multiplier = 1.0
	event_chance = BASE_EVENT_CHANCE
	cookie_consumption_rate = BASE_COOKIE_CONSUMPTION_RATE
	active_donation_table = DONATION_TABLE.duplicate(true)

	money_changed.emit(money)
	cookies_changed.emit(cookies_stock)
	recalculate_stats()

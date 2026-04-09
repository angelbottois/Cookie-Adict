# autoloads/PrestigeManager.gd
extends Node

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------
signal prestige_executed(count: int)
signal skill_unlocked(skill_id: String)
signal prestige_points_changed(points: int)

# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

# Dinero necesario para el primer Prestige; escala exponencialmente
const BASE_PRESTIGE_THRESHOLD: float = 10000.0
const PRESTIGE_THRESHOLD_MULTIPLIER: float = 2.5

# Puntos Prestige que otorga cada reinicio (escala lineal por ahora)
const BASE_POINTS_PER_PRESTIGE: int = 3
const BONUS_POINTS_PER_PRESTIGE: int = 1  # +1 punto adicional por cada Prestige previo

# ---------------------------------------------------------------------------
# Definición estática del árbol de habilidades
# Estructura: id -> { cost, prerequisites, effect_type, effect_value, position }
# Las posiciones son en coordenadas del árbol visual (Vector2)
# ---------------------------------------------------------------------------
const SKILL_TREE: Dictionary = {
	# — Rama central: mejoras de ingresos base —
	"faster_walkers": {
		"cost": 1,
		"prerequisites": [],
		"effect_type": "passersby_per_second",
		"effect_value": 2.0,          # +2 transeúntes/s
		"position": Vector2(0, 0),
	},
	"generous_crowd": {
		"cost": 1,
		"prerequisites": ["faster_walkers"],
		"effect_type": "donation_chance",
		"effect_value": 0.005,        # +0.5% donantes
		"position": Vector2(0, -120),
	},
	"better_pitch": {
		"cost": 2,
		"prerequisites": ["generous_crowd"],
		"effect_type": "donation_value_multiplier",
		"effect_value": 0.10,         # +10% valor de donación
		"position": Vector2(0, -240),
	},

	# — Rama izquierda: billetes y dinero —
	"unlock_bills": {
		"cost": 2,
		"prerequisites": ["faster_walkers"],
		"effect_type": "unlock_bills",
		"effect_value": 1.0,          # flag booleano (1 = activado)
		"position": Vector2(-200, 0),
	},
	"better_bills": {
		"cost": 2,
		"prerequisites": ["unlock_bills"],
		"effect_type": "donation_value_multiplier",
		"effect_value": 0.20,         # +20% valor (afecta especialmente a billetes)
		"position": Vector2(-200, -120),
	},
	"rat_synergy": {
		"cost": 3,
		"prerequisites": ["better_bills", "unlock_bills"],
		"effect_type": "rat_duplicate_bonus",
		"effect_value": 0.05,         # +5% probabilidad de duplicado de la Rata
		"position": Vector2(-200, -240),
	},

	# — Rama derecha: evento especial y minijuego —
	"sixth_sense": {
		"cost": 1,
		"prerequisites": ["faster_walkers"],
		"effect_type": "event_chance",
		"effect_value": 0.01,         # +1% probabilidad de transeúnte generoso
		"position": Vector2(200, 0),
	},
	"wider_zone": {
		"cost": 2,
		"prerequisites": ["sixth_sense"],
		"effect_type": "minigame_center_width",
		"effect_value": 0.10,         # +10% anchura de zona central del minijuego
		"position": Vector2(200, -120),
	},
	"slower_bar": {
		"cost": 2,
		"prerequisites": ["sixth_sense"],
		"effect_type": "minigame_bar_speed",
		"effect_value": -0.15,        # -15% velocidad de la barra (más fácil)
		"position": Vector2(300, -60),
	},
	"jackpot": {
		"cost": 3,
		"prerequisites": ["wider_zone", "slower_bar"],
		"effect_type": "minigame_reward_multiplier",
		"effect_value": 0.50,         # +50% recompensa máxima del minijuego
		"position": Vector2(250, -240),
	},

	# — Habilidad final: caos total —
	"cookie_madness": {
		"cost": 5,
		"prerequisites": ["better_pitch", "rat_synergy", "jackpot"],
		"effect_type": "global_multiplier",
		"effect_value": 0.25,         # +25% a todos los ingresos
		"position": Vector2(0, -360),
	},
}

# ---------------------------------------------------------------------------
# Estado persistente
# ---------------------------------------------------------------------------
var prestige_count: int = 0
var prestige_points: int = 0
var unlocked_skills: Array[String] = []   # Persisten entre Prestigios
var prestige_threshold: float = BASE_PRESTIGE_THRESHOLD

# ---------------------------------------------------------------------------
# Inicialización
# ---------------------------------------------------------------------------

func _ready() -> void:
	await get_tree().process_frame
	_recalculate_threshold()

# ---------------------------------------------------------------------------
# Comprobación y ejecución del Prestige
# ---------------------------------------------------------------------------

func can_prestige() -> bool:
	return GameManager.money >= prestige_threshold

func execute_prestige() -> void:
	if not can_prestige():
		return

	prestige_count += 1

	# Calcular y otorgar puntos
	var points_earned: int = BASE_POINTS_PER_PRESTIGE + (prestige_count - 1) * BONUS_POINTS_PER_PRESTIGE
	prestige_points += points_earned
	emit_signal("prestige_points_changed", prestige_points)

	# Resetear estado de juego
	GameManager.reset_for_prestige()
	ShopManager.reset_for_prestige()

	# Recalcular umbral del siguiente Prestige
	_recalculate_threshold()

	# Reaplicar efectos de habilidades desbloqueadas sobre el estado reseteado
	_apply_all_skill_effects()

	emit_signal("prestige_executed", prestige_count)

func _recalculate_threshold() -> void:
	prestige_threshold = BASE_PRESTIGE_THRESHOLD * pow(PRESTIGE_THRESHOLD_MULTIPLIER, prestige_count)

# ---------------------------------------------------------------------------
# Árbol de habilidades
# ---------------------------------------------------------------------------

func can_unlock_skill(skill_id: String) -> bool:
	if not skill_id in SKILL_TREE:
		return false
	if skill_id in unlocked_skills:
		return false

	var skill: Dictionary = SKILL_TREE[skill_id]

	if prestige_points < skill["cost"]:
		return false

	# Comprobar que todos los prerequisitos están desbloqueados
	for prereq in skill["prerequisites"]:
		if not prereq in unlocked_skills:
			return false

	return true

func unlock_skill(skill_id: String) -> bool:
	if not can_unlock_skill(skill_id):
		return false

	var skill: Dictionary = SKILL_TREE[skill_id]
	prestige_points -= skill["cost"]
	unlocked_skills.append(skill_id)

	_apply_skill_effect(skill_id)

	emit_signal("skill_unlocked", skill_id)
	emit_signal("prestige_points_changed", prestige_points)
	return true

func is_skill_unlocked(skill_id: String) -> bool:
	return skill_id in unlocked_skills

func is_skill_available(skill_id: String) -> bool:
	# Visible y con prerequisitos cumplidos, aunque no haya puntos suficientes
	if not skill_id in SKILL_TREE:
		return false
	if skill_id in unlocked_skills:
		return false
	for prereq in SKILL_TREE[skill_id]["prerequisites"]:
		if not prereq in unlocked_skills:
			return false
	return true

# ---------------------------------------------------------------------------
# Aplicación de efectos de habilidades
# ---------------------------------------------------------------------------

func _apply_all_skill_effects() -> void:
	for skill_id in unlocked_skills:
		_apply_skill_effect(skill_id)
	GameManager.emit_signal("stats_recalculated")

func _apply_skill_effect(skill_id: String) -> void:
	var skill: Dictionary = SKILL_TREE[skill_id]
	var effect_type: String = skill["effect_type"]
	var value: float = skill["effect_value"]

	match effect_type:
		"passersby_per_second":
			GameManager.passersby_per_second += value
		"donation_chance":
			GameManager.donation_chance += value
		"donation_value_multiplier":
			GameManager.donation_value_multiplier += value
		"unlock_bills":
			GameManager.bills_unlocked = true
		"rat_duplicate_bonus":
			GameManager.rat_duplicate_chance += value
		"event_chance":
			GameManager.event_chance += value
		"minigame_center_width":
			GameManager.minigame_center_width_bonus += value
		"minigame_bar_speed":
			GameManager.minigame_bar_speed_multiplier += value   # valor negativo = más lento
		"minigame_reward_multiplier":
			GameManager.minigame_reward_multiplier += value
		"global_multiplier":
			GameManager.global_income_multiplier += value

# ---------------------------------------------------------------------------
# Serialización (llamado por SaveManager)
# ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {
		"prestige_count": prestige_count,
		"prestige_points": prestige_points,
		"unlocked_skills": unlocked_skills.duplicate(),
		"prestige_threshold": prestige_threshold,
	}

func load_save_data(data: Dictionary) -> void:
	prestige_count = data.get("prestige_count", 0)
	prestige_points = data.get("prestige_points", 0)
	unlocked_skills = data.get("unlocked_skills", [])
	prestige_threshold = data.get("prestige_threshold", BASE_PRESTIGE_THRESHOLD)
	_apply_all_skill_effects()
	emit_signal("prestige_points_changed", prestige_points)

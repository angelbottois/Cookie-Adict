extends Control
 
enum Phase { INTRO, PLAYING }
 
const FADE_DURATION := 0.4
const PULSE_SCALE := 1.08
const PULSE_DURATION := 0.8
 
var _phase: Phase = Phase.INTRO
var _pulse_tween: Tween
 
@onready var hud_left: Control = $HUDLeft
@onready var hud_right: Control = $HUDRight
@onready var game_world: Node2D = $GameWorld
@onready var intro_overlay: CanvasLayer = $IntroOverlay
@onready var tap_label: Label = $IntroOverlay/TapToPlayLabel
@onready var shop_popup: Control = $PopupLayer/ShopPopup
@onready var precision_minigame: Control = $PopupLayer/PrecisionMinigame
@onready var confirm_dialog: Control = $PopupLayer/ConfirmDialog
 
 
func _ready() -> void:
	get_tree().paused = true
 
	hud_left.visible = false
	hud_right.visible = false
	hud_left.modulate.a = 0.0
	hud_right.modulate.a = 0.0
 
	tap_label.text = LocalizationManager.tr_key("ui.intro.tap_to_play")
	_start_pulse()
 
	# Conectar señales entrantes
	game_world.shop_requested.connect(_on_shop_requested)
	game_world.minigame_requested.connect(_on_minigame_requested)
	hud_right.prestige_requested.connect(_on_prestige_requested)
 
	# Conectar señal de fin de intro del mendigo
	var beggar = game_world.get_beggar()
	if beggar:
		beggar.intro_finished.connect(_on_intro_finished)
 
 
func _input(event: InputEvent) -> void:
	if _phase != Phase.INTRO:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_intro_sequence()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_start_intro_sequence()
		get_viewport().set_input_as_handled()
 
 
# --- Flujo de intro ---
 
func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(tap_label, "scale", Vector2.ONE * PULSE_SCALE, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(tap_label, "scale", Vector2.ONE, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 
 
func _start_intro_sequence() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
 
	var tween = create_tween()
	tween.tween_property(intro_overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	intro_overlay.visible = false
 
	var beggar = game_world.get_beggar()
	if beggar:
		beggar.play_intro_animation()
 
 
func _on_intro_finished() -> void:
	if SaveManager.has_save():
		SaveManager.load_game()
 
	get_tree().paused = false
 
	hud_left.visible = true
	hud_right.visible = true
	var tween = create_tween().set_parallel()
	tween.tween_property(hud_left, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_property(hud_right, "modulate:a", 1.0, FADE_DURATION)
 
	GameManager.game_started = true
	GameManager.emit_signal("game_started")
 
	_phase = Phase.PLAYING
 
 
# --- Apertura de popups ---
 
func _on_shop_requested() -> void:
	shop_popup.open()
 
 
func _on_minigame_requested() -> void:
	precision_minigame.open()
 
 
func _on_prestige_requested() -> void:
	# PrestigeScreen se implementará en el apartado 5
	pass

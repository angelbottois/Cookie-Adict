# 🍪 Cookie Addict — Arquitectura de Escenas (Godot 4)

**Versión:** 1.1  
**Motor:** Godot 4 — GDScript  
**Última revisión:** 2026-04

---

## Índice

1. [Estructura general del proyecto](#1-estructura-general-del-proyecto)
2. [Autoloads (singletons globales)](#2-autoloads-singletons-globales)
3. [Escena raíz y navegación](#3-escena-raíz-y-navegación)
4. [Escenas principales](#4-escenas-principales)
5. [Escenas de UI y popups](#5-escenas-de-ui-y-popups)
6. [Escenas de personajes y objetos](#6-escenas-de-personajes-y-objetos)
7. [Resources (datos)](#7-resources-datos)
8. [Sistema de localización](#8-sistema-de-localización)
9. [Convenciones de nomenclatura](#9-convenciones-de-nomenclatura)
10. [Diagrama de dependencias](#10-diagrama-de-dependencias)

---

## 1. Estructura general del proyecto

```
res://
├── autoloads/
│   ├── GameManager.gd
│   ├── ShopManager.gd
│   ├── PrestigeManager.gd
│   ├── LocalizationManager.gd
│   └── SaveManager.gd
│
├── scenes/
│   ├── main/
│   │   ├── Main.tscn               # Escena raíz del juego
│   │   └── GameScreen.tscn         # Pantalla de juego principal (layout completo)
│   │
│   ├── game/
│   │   ├── GameWorld.tscn          # Centro: calle, mendigo, transeúntes, objetos
│   │   ├── Beggar.tscn             # Mendigo principal (animaciones, estado)
│   │   ├── Passerby.tscn           # Transeúnte genérico (pooling)
│   │   ├── SpecialPasserby.tscn    # Transeúnte generoso (minijuego)
│   │   └── Pet.tscn                # Mascota activa (intercambiable)
│   │
│   ├── ui/
│   │   ├── HUDLeft.tscn            # Panel izquierdo: estadísticas en tiempo real
│   │   ├── HUDRight.tscn           # Panel derecho: acceso a Prestige y secundarios
│   │   ├── ShopPopup.tscn          # Popup de tienda (pausa el juego)
│   │   ├── PrestigeScreen.tscn     # Pantalla árbol de habilidades Prestige
│   │   ├── PrecisionMinigame.tscn  # Minijuego de la barra rebotante
│   │   └── ConfirmDialog.tscn      # Diálogo genérico de confirmación
│   │
│   └── objects/
│       ├── DonationContainer.tscn  # Objeto visual: recipiente de donaciones
│       ├── SignBoard.tscn          # Objeto visual: cartel del mendigo
│       └── RestZone.tscn           # Objeto visual: zona de descanso
│
├── resources/
│   ├── items/
│   │   ├── ItemData.gd             # Resource base para objetos de tienda
│   │   ├── containers/             # .tres de cada recipiente (nivel 1–8)
│   │   ├── signs/                  # .tres de cada cartel (nivel 1–8)
│   │   └── rest_zones/             # .tres de cada zona de descanso (nivel 1–8)
│   ├── pets/
│   │   ├── PetData.gd              # Resource base para mascotas
│   │   └── *.tres                  # .tres de cada mascota
│   └── prestige/
│       ├── SkillData.gd            # Resource base para habilidades del árbol
│       └── *.tres                  # .tres de cada habilidad Prestige
│
├── assets/
│   ├── sprites/
│   │   ├── beggar/                 # Spritesheet del mendigo por estado
│   │   ├── passersby/              # Sprites de transeúntes (variantes)
│   │   ├── objects/                # Sprites de objetos comprados
│   │   ├── pets/                   # Sprites de mascotas
│   │   ├── ui/                     # Iconos, fondos, botones
│   │   └── backgrounds/            # Fondos de calle (día/noche, clima)
│   └── audio/
│       ├── sfx/
│       └── music/
│
├── locale/
│   ├── strings.es.translation
│   └── strings.en.translation
│
└── project.godot
```

---

## 2. Autoloads (singletons globales)

Los autoloads son el núcleo del estado global del juego. Se registran en Project > Autoload en este orden (el orden importa por dependencias):

### GameManager.gd
**Responsabilidad:** Estado central del juego en tiempo real.

Variables principales:
- `money: float` — dinero actual
- `cookies_stock: int` — galletas en stock
- `income_rate: float` — ingresos por segundo (calculado)
- `passersby_per_second: float` — transeúntes por segundo
- `donation_chance: float` — % de transeúntes que donan (base 1%)
- `donation_value_multiplier: float` — multiplicador de valor de donación
- `event_chance: float` — probabilidad de transeúnte generoso
- `cookie_consumption_rate: float` — galletas consumidas por día de juego
- `is_penalized: bool` — penalización activa por falta de galletas
- `game_day: int` — día actual de juego (afecta al consumo)
- `bills_unlocked: bool` — billetes desbloqueados vía Prestige
- `game_started: bool` — false hasta que el jugador pulsa y la animación de entrada termina

Señales:
- `money_changed(new_value: float)`
- `cookies_changed(new_amount: int)`
- `penalty_started()`
- `penalty_ended()`
- `stats_recalculated()`
- `game_started()` — emitida al completarse la animación de entrada del mendigo

### ShopManager.gd
**Responsabilidad:** Catálogo de objetos, estado de compras y efectos sobre GameManager.

Variables principales:
- `purchased_items: Dictionary` — { category: nivel_actual }
- `discovered_items: Dictionary` — { category: nivel_máximo_visto }
- `active_pet: String` — ID de la mascota activa (vacío si ninguna)
- `purchased_pets: Array[String]` — mascotas compradas

Señales:
- `item_purchased(category: String, level: int)`
- `pet_changed(pet_id: String)`
- `shop_updated()`

### PrestigeManager.gd
**Responsabilidad:** Gestión del sistema Prestige y árbol de habilidades.

Variables principales:
- `prestige_count: int` — número de prestigios realizados
- `prestige_points: int` — puntos disponibles para el árbol
- `unlocked_skills: Array[String]` — IDs de habilidades compradas (persisten)
- `prestige_threshold: float` — dinero necesario para hacer Prestige

Señales:
- `prestige_executed(count: int)`
- `skill_unlocked(skill_id: String)`
- `prestige_points_changed(points: int)`

### LocalizationManager.gd
**Responsabilidad:** Idioma activo y acceso centralizado a cadenas localizadas.

Variables principales:
- `current_locale: String` — "es" o "en"

Funciones clave:
- `tr_key(key: String) -> String` — wrapper de TranslationServer.translate()
- `set_locale(locale: String)` — cambia idioma y emite señal

Señales:
- `locale_changed(new_locale: String)`

### SaveManager.gd
**Responsabilidad:** Serialización y carga del estado completo del juego.

Funciones clave:
- `save_game()` — guarda GameManager + ShopManager + PrestigeManager a disco
- `load_game()` — carga y restaura el estado
- `has_save() -> bool`

---

## 3. Escena raíz y navegación

### Main.tscn
```
Main (Node)
└── SceneTransition (CanvasLayer)        # Fade in/out entre escenas
└── CurrentScene (Node)                  # Escena activa (intercambiable)
```

**Lógica:** Main.gd carga directamente GameScreen al arrancar. No existe MainMenu como escena separada. El estado de "menú" es gestionado internamente por GameScreen mediante su fase de intro (ver sección 4).

---

## 4. Escenas principales

### GameScreen.tscn
**Única pantalla del juego.** Gestiona tanto la fase de intro como el juego activo.

```
GameScreen (Control)
├── HUDLeft (HUDLeft.tscn instanciada)       # Panel izquierdo — estadísticas
│   └── [oculto durante la intro]
├── GameWorld (GameWorld.tscn instanciada)   # Centro — escena del juego
├── HUDRight (HUDRight.tscn instanciada)     # Panel derecho — acceso Prestige
│   └── [oculto durante la intro]
├── IntroOverlay (CanvasLayer)               # Capa de intro (z_index alto, process_mode = ALWAYS)
│   └── TapToPlayLabel (Label)               # Texto "TAP TO PLAY" centrado, animación pulse
└── PopupLayer (CanvasLayer)                 # Capa de popups (z_index más alto aún)
    ├── ShopPopup (ShopPopup.tscn)
    ├── PrecisionMinigame (PrecisionMinigame.tscn)
    └── ConfirmDialog (ConfirmDialog.tscn)
```

**Flujo de la intro:**

1. Al cargar GameScreen, `get_tree().paused = true`. GameWorld se muestra (calle con transeúntes de fondo corriendo en modo ALWAYS), pero el mendigo está oculto y los HUDs están ocultos.
2. IntroOverlay muestra el texto "TAP TO PLAY" con animación de pulso (Tween en loop).
3. Al recibir cualquier input (clic / tap), IntroOverlay se oculta con fade out.
4. Se llama a `Beggar.play_intro_animation()`: el mendigo aparece desde detrás del callejón lateral (fuera de pantalla) y camina hasta su posición central mediante Tween/AnimationPlayer.
5. Al completarse la animación, `get_tree().paused = false`, los HUDs hacen fade in y `GameManager.game_started` pasa a `true`.
6. Si `SaveManager.has_save()`, el estado guardado se aplica sobre GameManager/ShopManager antes del paso 5, de forma que el juego arranca con los datos restaurados en el mismo instante en que el mendigo llega a su posición.

**Selección de idioma:** No ocurre en la intro. El jugador puede cambiar el idioma en cualquier momento desde un botón en HUDRight.

---

## 5. Escenas de UI y popups

### HUDLeft.tscn
```
HUDLeft (PanelContainer)
└── VBoxContainer
    ├── MoneyLabel (Label)               # Dinero actual formateado
    ├── IncomeRateLabel (Label)          # €/segundo
    ├── CookiesLabel (Label)             # Stock de galletas + icono
    ├── BeggarStatusLabel (Label)        # Estado: Normal / Penalizado
    └── DayLabel (Label)                 # Día de juego
```

Se actualiza conectando señales de GameManager (money_changed, cookies_changed, etc.). No hace polling en _process.

### HUDRight.tscn
```
HUDRight (PanelContainer)
└── VBoxContainer
    ├── BtnPrestige (Button)             # Abre PrestigeScreen (solo visible si umbral alcanzado)
    ├── BtnLanguage (Button)             # Alterna ES / EN en cualquier momento
    └── BtnSave (Button)                 # Guardado manual
```

### ShopPopup.tscn
```
ShopPopup (Control) [process_mode = ALWAYS]
├── DimBackground (ColorRect)           # Fondo semitransparente
└── PopupPanel (PanelContainer)
    ├── CloseButton (Button)
    ├── TabContainer
    │   ├── Tab "Recipiente" (ItemCategoryList)
    │   ├── Tab "Cartel" (ItemCategoryList)
    │   ├── Tab "Descanso" (ItemCategoryList)
    │   └── Tab "Mascotas" (PetList)
    └── [sin footer — precio y descripción inline en cada fila]
```

Al abrirse: `get_tree().paused = true`. Al cerrarse: `get_tree().paused = false`.

Subelemento reutilizable **ItemCategoryList** (Control): lista vertical de ítems de una categoría. Cada fila muestra icono, nombre localizado, efecto, coste y botón Comprar (deshabilitado si no alcanzado o sin fondos).

### PrestigeScreen.tscn
```
PrestigeScreen (Control)
├── Background (ColorRect)
├── SkillTree (Node2D)                  # Nodos y conexiones del árbol (generado por código)
│   └── [SkillNode instancias dinámicas]
├── PointsLabel (Label)                 # Puntos disponibles
└── BtnClose (Button)
```

El árbol se construye dinámicamente en _ready() leyendo los SkillData resources y el estado de PrestigeManager.

### PrecisionMinigame.tscn
```
PrecisionMinigame (Control) [process_mode = ALWAYS]
├── DimBackground (ColorRect)
├── InstructionLabel (Label)
├── BarContainer (Control)
│   ├── BarBackground (TextureRect)
│   ├── MovingIndicator (TextureRect)   # La barra que se desplaza
│   └── CenterZone (TextureRect)        # Zona central resaltada
└── RewardLabel (Label)                 # Resultado tras clic
```

---

## 6. Escenas de personajes y objetos

### GameWorld.tscn
**El corazón visual del juego.** Contiene la calle, el mendigo, los objetos comprados y el flujo de transeúntes.

```
GameWorld (Node2D)
├── Background (ParallaxBackground)     # Fondo de calle con capas (edificios, cielo)
│   ├── BackgroundLayer (ParallaxLayer) # Edificios del fondo
│   └── StreetLayer (ParallaxLayer)     # Acera / suelo
│
├── AlleyEntrance (Marker2D)            # Punto de spawn del mendigo en la intro (fuera de pantalla, lateral)
│
├── DayNightOverlay (ColorRect)         # Overlay de ciclo día/noche (alpha variable)
│
├── ObjectsLayer (Node2D)               # Objetos comprados (aparecen al comprar)
│   ├── DonationContainerSlot (Marker2D) # Posición fija del recipiente activo
│   ├── SignBoardSlot (Marker2D)         # Posición fija del cartel activo
│   └── RestZoneSlot (Marker2D)          # Posición fija de la zona de descanso activa
│
├── BeggarNode (Beggar.tscn)            # El mendigo; oculto al inicio, visible tras intro
│
├── PetSlot (Marker2D)                  # Posición de la mascota junto al mendigo
│   └── [Pet.tscn instanciada dinámicamente]
│
├── PasserbyPool (Node2D)               # Pool de transeúntes activos
│   └── [Passerby.tscn instancias reutilizadas]
│
└── ShopSign (Area2D)                   # Cartel de tienda clickable (integrado en el fondo)
    ├── CollisionShape2D
    └── ShopSignSprite (Sprite2D)
```

**AlleyEntrance:** Marker2D situado fuera del borde lateral de la pantalla, junto a la boca de un callejón pintado en el fondo. Es el punto de partida de la animación de entrada del mendigo.

**PasserbyPool:** se gestiona con object pooling. El número de instancias activas simultáneas es limitado (máximo ~30). Cuando un transeúnte sale de pantalla, se recicla en lugar de eliminarse. Los transeúntes corren durante la intro (process_mode = ALWAYS en el pool) para dar vida a la calle mientras se muestra "TAP TO PLAY".

**ShopSign** es el punto de entrada a la tienda. Al hacer clic sobre él, emite señal que GameScreen captura para abrir ShopPopup. Permanece inactivo (input_pickable = false) durante la fase de intro.

### Beggar.tscn
```
Beggar (CharacterBody2D)
├── AnimatedSprite2D                    # Estados: intro_walk, idle, happy, sad, eating
├── CollisionShape2D
└── StatusIcon (Sprite2D)               # Icono de estado (opcional: zzz, !, etc.)
```

Estados del mendigo:
- `intro_walk` — animación de caminar usada durante la entrada desde el callejón
- `idle` — estado normal de juego
- `happy` — tras recibir donación grande
- `sad` — penalización por falta de galletas
- `eating` — animación de consumo de galleta

Función pública: `play_intro_animation()` — mueve el nodo desde AlleyEntrance hasta su posición central mediante Tween, reproduciendo `intro_walk`. Al finalizar, emite la señal `intro_finished`.

### Passerby.tscn
```
Passerby (CharacterBody2D)
├── AnimatedSprite2D                    # Variantes visuales (al menos 4 sprites diferentes)
├── CollisionShape2D
└── DonationParticle (CPUParticles2D)   # Partícula al donar (moneda volando)
```

Lógica (Passerby.gd):
- Se mueve horizontalmente a velocidad variable (de izquierda a derecha o viceversa).
- Al spawn, se decide si donará (según donation_chance de GameManager). Durante la intro, nunca donan (game_started = false).
- Si dona, al pasar junto al mendigo emite señal `donated(amount)` y activa la partícula.
- Al salir de pantalla, emite señal `exited` para que el pool lo recicle.

### SpecialPasserby.tscn
```
SpecialPasserby (CharacterBody2D)
├── AnimatedSprite2D                    # Sprite diferenciado (color, sombrero, etc.)
├── CollisionShape2D
├── ExclamationIcon (Sprite2D)          # El ❗ sobre la cabeza
├── ClickArea (Area2D)                  # Área de clic del jugador
└── CollisionShape2D (del ClickArea)
```

Lógica: si el jugador hace clic sobre el ClickArea mientras el transeúnte está en pantalla, se pausa el juego y se abre PrecisionMinigame. No puede aparecer durante la intro.

### Pet.tscn
```
Pet (Node2D)
├── AnimatedSprite2D                    # Sprite de la mascota activa
├── PetBowl (Sprite2D)                  # Cuenco propio de la mascota
└── AnimationPlayer                     # Animaciones idle, feliz, etc.
```

Se instancia dinámicamente en PetSlot cuando el jugador cambia de mascota activa en la tienda. La mascota anterior se libera.

### DonationContainer.tscn / SignBoard.tscn / RestZone.tscn
```
[NombreObjeto] (Node2D)
└── Sprite2D                            # Sprite del nivel actual del objeto
```

Cada objeto visual es simple: solo un Sprite2D que muestra el arte correspondiente al nivel comprado. Se instancia en su Slot de ObjectsLayer al comprar. Al comprar el siguiente nivel, se reemplaza el sprite.

---

## 7. Resources (datos)

Se usan Resources personalizados de Godot 4 para definir los datos de objetos, mascotas y habilidades. Esto permite editar valores desde el Inspector sin tocar código.

### ItemData.gd (extends Resource)
```gdscript
@export var id: String
@export var category: String            # "container" | "sign" | "rest_zone"
@export var level: int
@export var name_key: String            # Clave de localización
@export var description_key: String
@export var effect_value: float         # Valor del bonus (ej: 0.05 = +5%)
@export var effect_type: String         # "donation_value" | "donation_chance" | "event_chance"
@export var cost: float                 # Precio en €
@export var sprite: Texture2D           # Arte del objeto en escena
@export var icon: Texture2D             # Icono para la tienda
```

### PetData.gd (extends Resource)
```gdscript
@export var id: String
@export var name_key: String
@export var description_key: String
@export var effect_type: String         # "passersby_bonus" | "money_bonus" | "event_bonus" | "duplicate_chance"
@export var effect_value: float
@export var cost: float
@export var sprite: Texture2D
@export var icon: Texture2D
@export var bowl_sprite: Texture2D
```

### SkillData.gd (extends Resource)
```gdscript
@export var id: String
@export var name_key: String
@export var description_key: String
@export var cost_points: int            # Puntos Prestige necesarios
@export var prerequisites: Array[String] # IDs de habilidades previas requeridas
@export var effect_type: String         # Tipo de efecto especial
@export var effect_value: float
@export var icon: Texture2D
@export var tree_position: Vector2      # Posición en el árbol visual
```

---

## 8. Sistema de localización

Se usa el sistema nativo de Godot 4 (TranslationServer + archivos .po/.translation).

**Estructura de claves:**
```
ui.intro.tap_to_play      → "TAP TO PLAY" / "TAP TO PLAY"
ui.hud.money              → "Dinero:" / "Money:"
ui.hud.cookies            → "Galletas:" / "Cookies:"
ui.hud.income_rate        → "Ingresos/s:" / "Income/s:"
ui.hud.language           → "ES / EN" / "ES / EN"
ui.shop.title             → "Tienda" / "Shop"
ui.shop.buy               → "Comprar" / "Buy"
items.container.1.name    → "Vaso de cartón" / "Cardboard Cup"
items.container.1.desc    → "..." / "..."
pets.dog.name             → "Perro" / "Dog"
prestige.title            → "Árbol de Habilidades" / "Skill Tree"
[etc.]
```

**Regla:** Ningún texto visible al jugador se escribe directamente en el código o en escenas. Siempre se usa `tr("clave")` o `LocalizationManager.tr_key("clave")`.

El idioma puede cambiarse en cualquier momento desde el botón en HUDRight. El idioma activo se guarda en SaveManager y se restaura al iniciar.

---

## 9. Convenciones de nomenclatura

| Elemento | Convención | Ejemplo |
|---|---|---|
| Escenas | PascalCase.tscn | `ShopPopup.tscn` |
| Scripts | PascalCase.gd | `GameManager.gd` |
| Nodos en escena | PascalCase | `DonationContainer` |
| Variables GDScript | snake_case | `donation_chance` |
| Señales | snake_case | `money_changed` |
| Constantes | UPPER_SNAKE | `BASE_COOKIE_COST` |
| Resources .tres | snake_case | `container_level_1.tres` |
| Claves de localización | dot.notation.lowercase | `items.container.1.name` |
| Carpetas | snake_case | `rest_zones/` |

---

## 10. Diagrama de dependencias

```
Main.tscn
└── GameScreen.tscn
    ├── IntroOverlay (CanvasLayer)       # Activo solo durante la intro
    │   └── TapToPlayLabel              # Input → dispara intro del mendigo
    ├── HUDLeft.tscn          ←── GameManager (señales)         [oculto en intro]
    ├── HUDRight.tscn         ←── PrestigeManager (señales)     [oculto en intro]
    ├── GameWorld.tscn
    │   ├── Beggar.tscn       ←── GameManager (estado)          [oculto en intro hasta animación]
    │   │   └── intro_finished ──→ GameScreen (inicia juego)
    │   ├── PasserbyPool      ←── GameManager (spawn rate)       [activo en intro, sin donar]
    │   ├── Pet.tscn          ←── ShopManager (mascota activa)
    │   ├── ObjectsLayer      ←── ShopManager (objetos comprados)
    │   └── ShopSign          ──→ ShopPopup (señal on_click)     [inactivo en intro]
    └── PopupLayer
        ├── ShopPopup.tscn    ←→ ShopManager (compras, catálogo)
        ├── PrecisionMinigame ←→ GameManager (recompensa, evento)
        ├── PrestigeScreen    ←→ PrestigeManager (árbol, puntos)
        └── ConfirmDialog     ←── PrestigeManager (confirmar Prestige)

Autoloads (disponibles globalmente en todas las escenas):
├── GameManager
├── ShopManager
├── PrestigeManager
├── LocalizationManager
└── SaveManager
```

---

## Notas de diseño técnico

**Intro sin MainMenu:** La fase de intro (calle vacía + "TAP TO PLAY") se gestiona enteramente dentro de GameScreen mediante un CanvasLayer (IntroOverlay) y el estado `game_started` de GameManager. No hay cambio de escena; solo aparición/ocultación de nodos y control de pausa.

**Object pooling en transeúntes:** Con 10–20 transeúntes por segundo, crear y destruir nodos continuamente sería costoso. Se mantiene un pool de instancias pre-creadas (máximo 30) que se reutilizan al salir de pantalla. El pool corre durante la intro para dar vida a la calle.

**Pausa selectiva:** Los popups (ShopPopup, PrecisionMinigame) y el IntroOverlay usan `process_mode = ALWAYS` para responder a input aunque el árbol esté pausado. El GameWorld y los transeúntes tienen `process_mode = PAUSABLE` (default), excepto el PasserbyPool durante la intro que necesita correr.

**Compatibilidad móvil:** Los botones y áreas clicables se dimensionan con mínimo 44×44 px táctiles desde el inicio. El layout usa anclas relativas (no posiciones fijas) para adaptarse a distintas resoluciones.

**Ciclo día/noche:** DayNightOverlay es un ColorRect que va de alpha 0 (día) a alpha 0.6 color azul oscuro (noche) mediante Tween, sincronizado con game_day en GameManager.

**Señales sobre polling:** Toda la UI se actualiza por señales, nunca con _process(delta). Esto reduce la carga especialmente en la HUD, que de otro modo actualizaría decenas de Labels cada frame.

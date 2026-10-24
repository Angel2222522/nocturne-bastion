extends Control

const BattleSimulationScript = preload("res://core/battle_simulation.gd")
const BoardViewScript = preload("res://visuals/board_view.gd")
const RegularFont = preload("res://assets/fonts/DejaVuSans.ttf")
const BoldFont = preload("res://assets/fonts/DejaVuSans-Bold.ttf")
const PresenterScript = preload("res://visuals/battle_presenter.gd")

const PANEL: Color = Color("382c48")
const PANEL_BORDER: Color = Color("776181")
const ACCENT: Color = Color("d7afff")
const GOLD: Color = Color("f0c582")
const MUTED: Color = Color("d6c9db")
const TOWER_IDS: Array[String] = ["rapid", "nuclear", "barracks", "mage", "enhancer"]
const TOWER_SHORT_NAMES: Dictionary = {
	"rapid": "ΤΑΧΥΒΟΛΟΣ", "nuclear": "ΠΥΡΗΝΙΚΟΣ", "barracks": "ΣΤΡΑΤΩΝΑΣ",
	"mage": "ΜΑΓΟΣ", "enhancer": "ΕΝΙΣΧΥΤΗΣ"
}
const TOWER_COLORS: Dictionary = {
	"rapid": Color("85d7db"), "nuclear": Color("ff937c"), "barracks": Color("e7c77f"),
	"mage": Color("bda0ed"), "enhancer": Color("a5dc9e")
}

var presenter: BattlePresenter = PresenterScript.new()
var simulation: BattleSimulation
var board: BoardView
var gold_label: Label
var lives_label: Label
var phase_label: Label
var wave_summary_label: Label
var selection_label: Label
var hint_label: Label
var tower_buttons: Dictionary = {}
var level_button: Button
var branch_a_button: Button
var branch_b_button: Button
var wave_button: Button
var selected_slot: int = -1
var selected_tower_type: String = "rapid"
var frame_accumulator: float = 0.0


func _ready() -> void:
	simulation = BattleSimulationScript.new()
	_build_interface()
	_refresh()


func _process(delta: float) -> void:
	if simulation.phase != "active":
		return
	frame_accumulator += minf(delta, 0.5)
	var updated: bool = false
	while frame_accumulator >= BattleSimulationScript.FIXED_STEP:
		simulation.tick(BattleSimulationScript.FIXED_STEP)
		frame_accumulator -= BattleSimulationScript.FIXED_STEP
		board.set_snapshot(presenter.capture(simulation))
		updated = true
	if updated:
		_refresh(false)


func _build_interface() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = PANEL
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	board = BoardViewScript.new()
	_set_rect(board, 0.0, 0.09, 1.0, 0.79)
	board.build_slot_pressed.connect(_on_build_slot_pressed)
	add_child(board)

	var header: PanelContainer = PanelContainer.new()
	_set_rect(header, 0.0, 0.0, 1.0, 0.09)
	header.add_theme_stylebox_override("panel", _panel_style(PANEL, PANEL_BORDER, 0))
	add_child(header)
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 22)
	header.add_child(header_row)
	var brand: VBoxContainer = VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	header_row.add_child(brand)
	brand.add_child(_label("PULSE", 24, Color("fff1dc"), true))
	brand.add_child(_label("ΟΡΥΚΤΗ ΚΟΙΛΑΔΑ  /  01", 10, MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	phase_label = _label("", 15, ACCENT, true)
	header_row.add_child(phase_label)
	wave_summary_label = _label("", 12, MUTED)
	header_row.add_child(wave_summary_label)
	gold_label = _label("", 19, GOLD, true)
	header_row.add_child(gold_label)
	lives_label = _label("", 19, Color("fff1dc"), true)
	header_row.add_child(lives_label)

	var footer: PanelContainer = PanelContainer.new()
	_set_rect(footer, 0.0, 0.79, 1.0, 1.0)
	footer.add_theme_stylebox_override("panel", _panel_style(PANEL, PANEL_BORDER, 0))
	add_child(footer)
	var footer_column: VBoxContainer = VBoxContainer.new()
	footer_column.add_theme_constant_override("separation", 6)
	footer.add_child(footer_column)
	var tower_row: HBoxContainer = HBoxContainer.new()
	tower_row.add_theme_constant_override("separation", 8)
	footer_column.add_child(tower_row)
	for tower_id in TOWER_IDS:
		var button: Button = _button("", TOWER_COLORS[tower_id], 43)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_tower_type_pressed.bind(tower_id))
		tower_row.add_child(button)
		tower_buttons[tower_id] = button

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	footer_column.add_child(action_row)
	var context: VBoxContainer = VBoxContainer.new()
	context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.add_theme_constant_override("separation", 0)
	action_row.add_child(context)
	selection_label = _label("", 14, Color("fff1dc"), true)
	context.add_child(selection_label)
	hint_label = _label("", 11, MUTED)
	context.add_child(hint_label)
	level_button = _button("ΑΝΑΒΑΘΜΙΣΗ", GOLD, 48)
	level_button.custom_minimum_size.x = 132.0
	level_button.pressed.connect(_on_upgrade_pressed.bind(""))
	action_row.add_child(level_button)
	branch_a_button = _button("ΕΞΕΙΔΙΚΕΥΣΗ Α", ACCENT, 48)
	branch_a_button.custom_minimum_size.x = 98.0
	branch_a_button.pressed.connect(_on_upgrade_pressed.bind("A"))
	action_row.add_child(branch_a_button)
	branch_b_button = _button("ΕΞΕΙΔΙΚΕΥΣΗ Β", ACCENT, 48)
	branch_b_button.custom_minimum_size.x = 98.0
	branch_b_button.pressed.connect(_on_upgrade_pressed.bind("B"))
	action_row.add_child(branch_b_button)
	wave_button = _button("ΕΝΑΡΞΗ ΚΥΜΑΤΟΣ", ACCENT, 48)
	wave_button.custom_minimum_size.x = 165.0
	wave_button.pressed.connect(_on_wave_pressed)
	action_row.add_child(wave_button)


func _set_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", BoldFont if bold else RegularFont)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _button(text: String, accent_color: Color, height: float) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, height)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_font_override("font", BoldFont)
	button.add_theme_color_override("font_color", Color("382c48"))
	button.add_theme_color_override("font_disabled_color", Color("b8a9bd"))
	button.add_theme_stylebox_override("normal", _panel_style(accent_color, accent_color.lightened(0.12), 9))
	button.add_theme_stylebox_override("hover", _panel_style(accent_color.lightened(0.12), accent_color, 9))
	button.add_theme_stylebox_override("pressed", _panel_style(accent_color.darkened(0.08), accent_color, 9))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("51435e"), Color("766381"), 9))
	return button


func _on_tower_type_pressed(tower_id: String) -> void:
	selected_tower_type = tower_id
	if selected_slot >= 0 and not simulation.towers.has(selected_slot):
		_try_build_selected()
	_refresh()


func _on_build_slot_pressed(slot_id: int) -> void:
	selected_slot = slot_id
	board.set_selected_slot(slot_id)
	if not simulation.towers.has(slot_id):
		_try_build_selected()
	_refresh()


func _try_build_selected() -> void:
	if selected_slot >= 0 and simulation.request_build(selected_slot, selected_tower_type):
		hint_label.text = "%s κατασκευάστηκε στη θέση %02d." % [TOWER_SHORT_NAMES[selected_tower_type], selected_slot + 1]
	else:
		hint_label.text = "Δεν επαρκεί ο χρυσός ή η θέση είναι κατειλημμένη."


func _on_upgrade_pressed(branch: String) -> void:
	if selected_slot < 0:
		return
	if simulation.upgrade_tower(selected_slot, branch):
		hint_label.text = "Η εξέλιξη του πύργου ολοκληρώθηκε."
	else:
		hint_label.text = "Δεν επαρκεί ο χρυσός ή αυτή η εξέλιξη δεν είναι διαθέσιμη."
	_refresh()


func _on_wave_pressed() -> void:
	if simulation.phase in ["ready", "intermission"]:
		if simulation.start_wave():
			hint_label.text = "Κύμα %d: %s" % [simulation.wave_index + 1, String(simulation.active_wave.get("display_name", ""))]
	elif simulation.phase in ["won", "lost"]:
		get_tree().reload_current_scene()
	_refresh()


func _refresh(update_board: bool = true) -> void:
	if update_board:
		board.set_snapshot(presenter.capture(simulation))
	board.set_selected_slot(selected_slot)
	gold_label.text = "ΧΡΥΣΟΣ  %d" % simulation.wallet.gold
	lives_label.text = "ΠΥΡΗΝΑΣ  %d" % simulation.lives
	var current_wave: int = maxi(1, simulation.wave_index + 1)
	wave_summary_label.text = "ΚΥΜΑ %d / %d  ·  %d/%d  ·  ΕΞΟΝΤΩΣΕΙΣ %d" % [current_wave, simulation.snapshot()["wave_total"], simulation.wave_spawned_count, simulation.wave_enemy_total, simulation.wave_kills]
	phase_label.text = _phase_text()
	phase_label.add_theme_color_override("font_color", Color("f27e73") if simulation.phase == "lost" else ACCENT)
	for tower_id in TOWER_IDS:
		var button: Button = tower_buttons[tower_id]
		var cost: int = simulation.build_cost(tower_id)
		button.text = "%s\n%d ΧΡ" % [TOWER_SHORT_NAMES[tower_id], cost]
		button.disabled = simulation.phase in ["won", "lost"] or not simulation.wallet.can_afford(cost)
		button.add_theme_stylebox_override("normal", _panel_style(TOWER_COLORS[tower_id] if selected_tower_type == tower_id else Color("786b83"), TOWER_COLORS[tower_id], 8))
	_refresh_selection()
	_refresh_wave_button()


func _refresh_selection() -> void:
	var selected: bool = selected_slot >= 0 and selected_slot < simulation.build_slots.size()
	var occupied: bool = selected and simulation.towers.has(selected_slot)
	level_button.visible = occupied
	branch_a_button.visible = false
	branch_b_button.visible = false
	if not selected:
		selection_label.text = "ΕΠΙΛΕΞΕ ΠΥΡΓΟ ΚΑΙ ΑΓΓΙΞΕ ΜΙΑ ΕΛΕΥΘΕΡΗ ΒΑΣΗ"
		hint_label.text = "Η μάχη παίζεται αυτόματα. Κατασκευή και αναβάθμιση με αφή."
		return
	if not occupied:
		var cost: int = simulation.build_cost(selected_tower_type)
		selection_label.text = "ΘΕΣΗ %02d  ·  %s  ·  %d ΧΡΥΣΟΣ" % [selected_slot + 1, TOWER_SHORT_NAMES[selected_tower_type], cost]
		if hint_label.text.is_empty() or hint_label.text.begins_with("ΕΠΙΛΕΞΕ"):
			hint_label.text = "Άγγιξε ξανά τη βάση για κατασκευή."
		return
	var runtime: Dictionary = simulation.towers[selected_slot]
	var state: TowerState = runtime["state"]
	var levels: Array = state.definition.get("levels", [])
	var can_specialize: bool = state.specialization.is_empty() and state.level >= levels.size()
	branch_a_button.visible = can_specialize and state.definition.get("specializations", {}).has("A")
	branch_b_button.visible = can_specialize and state.definition.get("specializations", {}).has("B")
	var stats: Dictionary = simulation.snapshot()["slots"][selected_slot]["stats"]
	var display_name: String = String(simulation.catalog.tower_definition(state.tower_id).get("display_name", TOWER_SHORT_NAMES[state.tower_id]))
	var suffix: String = "  ·  %s" % state.specialization if not state.specialization.is_empty() else ""
	selection_label.text = "ΘΕΣΗ %02d  ·  %s L%d%s  ·  %s" % [selected_slot + 1, display_name, state.level, suffix, _stat_summary(state.tower_id, stats)]
	var level_cost: int = simulation.upgrade_cost(selected_slot)
	level_button.text = "ΑΝΑΒΑΘΜ. · %d ΧΡ" % level_cost if level_cost >= 0 else "ΜΕΓΙΣΤΟ ΕΠΙΠΕΔΟ"
	level_button.disabled = level_cost < 0 or not simulation.wallet.can_afford(level_cost) or simulation.phase in ["won", "lost"]
	var cost_a: int = simulation.upgrade_cost(selected_slot, "A")
	var cost_b: int = simulation.upgrade_cost(selected_slot, "B")
	branch_a_button.text = "Α · %d ΧΡ" % cost_a
	branch_b_button.text = "Β · %d ΧΡ" % cost_b
	branch_a_button.disabled = cost_a < 0 or not simulation.wallet.can_afford(cost_a) or simulation.phase in ["won", "lost"]
	branch_b_button.disabled = cost_b < 0 or not simulation.wallet.can_afford(cost_b) or simulation.phase in ["won", "lost"]


func _stat_summary(tower_id: String, stats: Dictionary) -> String:
	if tower_id == "barracks":
		return "%d ΜΑΧΗΤΕΣ" % int(stats.get("soldiers_per_cycle", 1))
	if tower_id == "enhancer":
		return "ΕΝΙΣΧΥΣΗ ΠΙΣΤΑΣ"
	if stats.has("targeting"):
		return "ΠΑΓΚΟΣΜΙΑ ΣΤΟΧΕΥΣΗ · ΖΗΜΙΑ %.0f" % float(stats.get("damage", 0.0))
	return "ΖΗΜΙΑ %.0f  ·  ΕΜΒΕΛΕΙΑ %.1f" % [float(stats.get("damage", 0.0)), float(stats.get("range", 0.0))]


func _refresh_wave_button() -> void:
	var waves_total: int = int(simulation.snapshot()["wave_total"])
	wave_button.disabled = false
	match simulation.phase:
		"ready":
			wave_button.text = "ΕΝΑΡΞΗ ΚΥΜΑΤΟΣ 1"
		"intermission":
			wave_button.text = "ΕΠΟΜΕΝΟ ΚΥΜΑ %d" % (simulation.wave_index + 2)
		"active":
			wave_button.text = "ΚΥΜΑ %d · ΜΑΧΗ" % (simulation.wave_index + 1)
			wave_button.disabled = true
		"won":
			wave_button.text = "ΝΙΚΗ · ΞΑΝΑ"
		"lost":
			wave_button.text = "ΗΤΤΑ · ΞΑΝΑ"
	if simulation.phase == "intermission" and simulation.wave_index + 1 >= waves_total:
		wave_button.disabled = true


func _phase_text() -> String:
	match simulation.phase:
		"active":
			return "ΣΕ ΕΞΕΛΙΞΗ"
		"intermission":
			return "ΜΕΣΟΔΙΑΣΤΗΜΑ"
		"won":
			return "ΝΙΚΗ"
		"lost":
			return "ΗΤΤΑ"
		_:
			return "ΕΤΟΙΜΟ"

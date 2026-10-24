extends Control

const BattleSimulationScript = preload("res://core/battle_simulation.gd")
const BoardViewScript = preload("res://visuals/board_view.gd")
const RegularFont = preload("res://assets/fonts/DejaVuSans.ttf")
const BoldFont = preload("res://assets/fonts/DejaVuSans-Bold.ttf")

const PANEL: Color = Color("192720")
const PANEL_BORDER: Color = Color("50634f")
const ACCENT: Color = Color("78d9bd")
const GOLD: Color = Color("e9b765")
const MUTED: Color = Color("c0b99f")

var simulation: BattleSimulation
var board: BoardView
var gold_label: Label
var lives_label: Label
var phase_label: Label
var slot_label: Label
var wave_summary_label: Label
var hint_label: Label
var build_button: Button
var start_button: Button
var selected_slot: int = -1
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
		updated = true
	if updated:
		_refresh()


func _build_interface() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("0b120f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var header: PanelContainer = PanelContainer.new()
	_set_rect(header, 0.02, 0.025, 0.98, 0.135)
	header.add_theme_stylebox_override("panel", _panel_style(PANEL, PANEL_BORDER, 18))
	add_child(header)
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 20)
	header.add_child(header_row)
	var title_column: VBoxContainer = VBoxContainer.new()
	title_column.add_theme_constant_override("separation", 0)
	header_row.add_child(title_column)
	var title: Label = _label("PULSE", 25, Color("f3ecd9"), true)
	title_column.add_child(title)
	title_column.add_child(_label("ΑΜΥΝΑ ΠΥΡΗΝΑ  /  ΠΡΩΤΟΤΥΠΟ 0.1.1", 12, MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	gold_label = _label("ΧΡΥΣΟΣ", 18, GOLD, true)
	header_row.add_child(gold_label)
	lives_label = _label("ΠΥΡΗΝΑΣ", 18, ACCENT, true)
	header_row.add_child(lives_label)
	phase_label = _label("ΕΤΟΙΜΟ", 17, Color("d8e2eb"), true)
	header_row.add_child(phase_label)

	board = BoardViewScript.new()
	_set_rect(board, 0.02, 0.16, 0.725, 0.97)
	board.build_slot_pressed.connect(_on_build_slot_pressed)
	add_child(board)

	var sidebar: PanelContainer = PanelContainer.new()
	_set_rect(sidebar, 0.745, 0.16, 0.98, 0.97)
	sidebar.add_theme_stylebox_override("panel", _panel_style(PANEL, PANEL_BORDER, 18))
	add_child(sidebar)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	sidebar.add_child(margin)
	var controls: VBoxContainer = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	margin.add_child(controls)
	controls.add_child(_label("ΚΕΝΤΡΟ ΔΙΟΙΚΗΣΗΣ", 19, Color("f3ecd9"), true))
	controls.add_child(_label("Δοκιμαστικός τομέας 01", 14, MUTED))
	controls.add_child(_separator())
	controls.add_child(_label("ΕΠΙΛΕΓΜΕΝΗ ΘΕΣΗ", 12, ACCENT, true))
	slot_label = _label("Άγγιξε έναν κύκλο στον χάρτη", 15, Color("e5ebf1"))
	slot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(slot_label)
	build_button = _button("ΚΑΤΑΣΚΕΥΑΣΕ ΤΑΧΥΒΟΛΟ", GOLD)
	build_button.pressed.connect(_on_build_pressed)
	controls.add_child(build_button)
	controls.add_child(_separator())
	controls.add_child(_label("ΚΥΜΑ 1", 12, ACCENT, true))
	wave_summary_label = _label("Δοκιμαστικοί αντίπαλοι", 15, Color("e5ebf1"))
	controls.add_child(wave_summary_label)
	start_button = _button("ΕΝΑΡΞΗ ΚΥΜΑΤΟΣ", ACCENT)
	start_button.pressed.connect(_on_start_pressed)
	controls.add_child(start_button)
	var lower_spacer: Control = Control.new()
	lower_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(lower_spacer)
	hint_label = _label("Στήσε άμυνα και ξεκίνα το κύμα. Οι βολές και οι ανταμοιβές υπολογίζονται αυτόματα.", 13, MUTED)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(hint_label)


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
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", BoldFont)
	else:
		label.add_theme_font_override("font", RegularFont)
	return label


func _button(text: String, accent_color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_font_override("font", BoldFont)
	button.add_theme_color_override("font_color", Color("101b2b"))
	button.add_theme_color_override("font_disabled_color", Color("718095"))
	button.add_theme_stylebox_override("normal", _panel_style(accent_color, accent_color.lightened(0.12), 12))
	button.add_theme_stylebox_override("hover", _panel_style(accent_color.lightened(0.12), accent_color, 12))
	button.add_theme_stylebox_override("pressed", _panel_style(accent_color.darkened(0.08), accent_color, 12))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("344457"), Color("40556b"), 12))
	return button


func _separator() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_color_override("separator", PANEL_BORDER)
	return separator


func _on_build_slot_pressed(slot_id: int) -> void:
	selected_slot = slot_id
	board.set_selected_slot(slot_id)
	_refresh()


func _on_build_pressed() -> void:
	if selected_slot >= 0 and simulation.request_build(selected_slot, "rapid"):
		hint_label.text = "Ο Ταχυβόλος είναι έτοιμος. Μπορείς να κατασκευάσεις κι άλλους πριν ή κατά τη διάρκεια του κύματος."
	_refresh()


func _on_start_pressed() -> void:
	if simulation.start_wave():
		hint_label.text = "Οι αντίπαλοι κινούνται στη διαδρομή. Κάθε διαρροή αφαιρεί μία ζωή από τον πυρήνα."
	_refresh()


func _refresh() -> void:
	var snapshot: Dictionary = simulation.snapshot()
	board.set_snapshot(snapshot)
	board.set_selected_slot(selected_slot)
	gold_label.text = "ΧΡΥΣΟΣ  %d" % simulation.wallet.gold
	lives_label.text = "ΠΥΡΗΝΑΣ  %d" % simulation.lives
	wave_summary_label.text = "%d δοκιμαστικοί αντίπαλοι" % simulation.wave_enemy_total
	phase_label.text = _phase_text(simulation.phase)
	phase_label.add_theme_color_override("font_color", ACCENT if simulation.phase != "lost" else Color("f27e73"))
	var selected_is_occupied: bool = selected_slot >= 0 and simulation.towers.has(selected_slot)
	if selected_slot < 0:
		slot_label.text = "Άγγιξε έναν κύκλο στον χάρτη"
	elif selected_is_occupied:
		var tower: Dictionary = simulation.towers[selected_slot]
		slot_label.text = "Θέση %02d · Ταχυβόλος επιπέδου %d" % [selected_slot + 1, int(tower["level"])]
	else:
		slot_label.text = "Θέση %02d · Κενή" % (selected_slot + 1)
	var cost: int = simulation.build_cost("rapid")
	build_button.text = "ΚΑΤΑΣΚΕΥΑΣΕ ΤΑΧΥΒΟΛΟ\n%d νομίσματα" % cost
	build_button.disabled = selected_slot < 0 or selected_is_occupied or cost < 0 or not simulation.wallet.can_afford(cost) or simulation.phase in ["won", "lost"]
	start_button.disabled = simulation.phase != "ready"
	match simulation.phase:
		"active":
			start_button.text = "ΚΥΜΑ ΣΕ ΕΞΕΛΙΞΗ"
		"won":
			start_button.text = "ΝΙΚΗ · ΚΥΜΑ ΟΛΟΚΛΗΡΩΘΗΚΕ"
			hint_label.text = "Καθαρίστηκε το δοκιμαστικό κύμα. Η ισορροπία χρειάζεται playtest πριν οριστικοποιηθεί."
		"lost":
			start_button.text = "ΗΤΤΑ · ΠΥΡΗΝΑΣ ΕΞΑΝΤΛΗΘΗΚΕ"
			hint_label.text = "Ο πυρήνας έμεινε χωρίς ζωές."
		_:
			start_button.text = "ΕΝΑΡΞΗ ΚΥΜΑΤΟΣ"


func _phase_text(current_phase: String) -> String:
	match current_phase:
		"active":
			return "ΚΥΜΑ ΣΕ ΕΞΕΛΙΞΗ"
		"won":
			return "ΝΙΚΗ"
		"lost":
			return "ΗΤΤΑ"
		_:
			return "ΕΤΟΙΜΟ"

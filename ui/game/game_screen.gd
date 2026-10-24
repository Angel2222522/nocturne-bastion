extends Control

const BattleSimulationScript = preload("res://core/battle_simulation.gd")
const BoardViewScript = preload("res://visuals/board_view.gd")
const RegularFont = preload("res://assets/fonts/DejaVuSans.ttf")
const BoldFont = preload("res://assets/fonts/DejaVuSans-Bold.ttf")

const PANEL: Color = Color("382c48")
const PANEL_BORDER: Color = Color("776181")
const ACCENT: Color = Color("d7afff")
const GOLD: Color = Color("f0c582")
const MUTED: Color = Color("d6c9db")

const PresenterScript = preload("res://visuals/battle_presenter.gd")

var presenter: BattlePresenter = PresenterScript.new()
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

	# Almost the entire width belongs to the battlefield. No permanent sidebar.
	board = BoardViewScript.new()
	_set_rect(board, 0.0, 0.095, 1.0, 0.89)
	board.build_slot_pressed.connect(_on_build_slot_pressed)
	add_child(board)

	var header: PanelContainer = PanelContainer.new()
	_set_rect(header, 0.0, 0.0, 1.0, 0.095)
	header.add_theme_stylebox_override("panel", _panel_style(PANEL, PANEL_BORDER, 0))
	add_child(header)
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 30)
	header.add_child(header_row)
	var brand: VBoxContainer = VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	header_row.add_child(brand)
	brand.add_child(_label("PULSE", 26, Color("fff1dc"), true))
	brand.add_child(_label("ΟΡΥΚΤΗ ΚΟΙΛΑΔΑ  /  01", 11, MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	gold_label = _label("", 22, GOLD, true)
	header_row.add_child(gold_label)
	lives_label = _label("", 22, ACCENT, true)
	header_row.add_child(lives_label)
	var wave_column: VBoxContainer = VBoxContainer.new()
	wave_column.add_theme_constant_override("separation", 0)
	header_row.add_child(wave_column)
	phase_label = _label("", 15, Color("fff1dc"), true)
	wave_column.add_child(phase_label)
	wave_summary_label = _label("", 12, MUTED)
	wave_column.add_child(wave_summary_label)

	var footer: PanelContainer = PanelContainer.new()
	_set_rect(footer, 0.0, 0.89, 1.0, 1.0)
	footer.add_theme_stylebox_override("panel", _panel_style(PANEL, PANEL_BORDER, 0))
	add_child(footer)
	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 18)
	footer.add_child(footer_row)
	var context: VBoxContainer = VBoxContainer.new()
	context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.add_theme_constant_override("separation", 3)
	footer_row.add_child(context)
	slot_label = _label("", 19, Color("fff1dc"), true)
	context.add_child(slot_label)
	hint_label = _label("", 13, MUTED)
	context.add_child(hint_label)
	build_button = _button("", GOLD)
	build_button.custom_minimum_size.x = 280.0
	build_button.pressed.connect(_on_build_pressed)
	footer_row.add_child(build_button)
	start_button = _button("ΕΝΑΡΞΗ ΚΥΜΑΤΟΣ", ACCENT)
	start_button.custom_minimum_size.x = 265.0
	start_button.pressed.connect(_on_start_pressed)
	footer_row.add_child(start_button)


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
	button.add_theme_color_override("font_color", Color("382c48"))
	button.add_theme_color_override("font_disabled_color", Color("b8a9bd"))
	button.add_theme_stylebox_override("normal", _panel_style(accent_color, accent_color.lightened(0.12), 12))
	button.add_theme_stylebox_override("hover", _panel_style(accent_color.lightened(0.12), accent_color, 12))
	button.add_theme_stylebox_override("pressed", _panel_style(accent_color.darkened(0.08), accent_color, 12))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("51435e"), Color("766381"), 12))
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


func _refresh(refresh_visuals: bool = true) -> void:
	if refresh_visuals:
		board.set_snapshot(presenter.capture(simulation))
	board.set_selected_slot(selected_slot)
	gold_label.text = "ΧΡΥΣΟΣ  %d" % simulation.wallet.gold
	lives_label.text = "ΠΥΡΗΝΑΣ  %d" % simulation.lives
	wave_summary_label.text = "%d / %d εμφανίστηκαν  ·  %d εξοντώσεις" % [simulation.spawned_count, simulation.wave_enemy_total, simulation.killed_count]
	phase_label.text = _phase_text(simulation.phase)
	phase_label.add_theme_color_override("font_color", ACCENT if simulation.phase != "lost" else Color("f27e73"))
	var selected_is_occupied: bool = selected_slot >= 0 and simulation.towers.has(selected_slot)
	if selected_slot < 0:
		slot_label.text = "Επίλεξε βάση κατασκευής"
	elif selected_is_occupied:
		var tower: Dictionary = simulation.towers[selected_slot]
		slot_label.text = "ΘΕΣΗ %02d  ·  ΤΑΧΥΒΟΛΟΣ %d" % [selected_slot + 1, int(tower["level"])]
	else:
		slot_label.text = "ΘΕΣΗ %02d  ·  ΕΛΕΥΘΕΡΗ ΒΑΣΗ" % (selected_slot + 1)
	var cost: int = simulation.build_cost("rapid")
	build_button.text = "ΤΑΧΥΒΟΛΟΣ  ·  %d ΧΡΥΣΟΣ" % cost
	build_button.visible = selected_slot >= 0 and not selected_is_occupied
	hint_label.text = "Κατασκευή με αφή · Αυτόματη επίθεση" if selected_slot < 0 else ("Ο πύργος επιτίθεται αυτόματα." if selected_is_occupied else "Άγγιξε ΤΑΧΥΒΟΛΟΣ για κατασκευή.")
	build_button.disabled = selected_slot < 0 or selected_is_occupied or cost < 0 or not simulation.wallet.can_afford(cost) or simulation.phase in ["won", "lost"]
	start_button.disabled = simulation.phase != "ready"
	match simulation.phase:
		"active":
			start_button.text = "ΚΥΜΑ 1 · ΣΕ ΕΞΕΛΙΞΗ"
		"won":
			start_button.text = "ΚΥΜΑ 1 · ΝΙΚΗ"
			hint_label.text = "Το δοκιμαστικό κύμα ολοκληρώθηκε."
		"lost":
			start_button.text = "ΚΥΜΑ 1 · ΗΤΤΑ"
			hint_label.text = "Ο πυρήνας έμεινε χωρίς ζωές."
		_:
			start_button.text = "ΕΝΑΡΞΗ ΚΥΜΑΤΟΣ"


func _phase_text(current_phase: String) -> String:
	match current_phase:
		"active":
			return "ΚΥΜΑ 1 · ΣΕ ΕΞΕΛΙΞΗ"
		"won":
			return "ΝΙΚΗ"
		"lost":
			return "ΗΤΤΑ"
		_:
			return "ΕΤΟΙΜΟ"

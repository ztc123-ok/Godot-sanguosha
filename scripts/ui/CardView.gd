class_name CardView
extends PanelContainer
## 单张手牌视图：支持点击和 Godot 4.x 原生拖拽数据。

signal card_clicked(hand_index: int)

var hand_index: int = -1
var card: Card
var face_down: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(112.0, 138.0)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE


func configure(p_card: Card, p_index: int, p_face_down: bool = false) -> void:
	card = p_card
	hand_index = p_index
	face_down = p_face_down
	_build_visual()


func set_selected(value: bool) -> void:
	if value:
		scale = Vector2(1.06, 1.06)
		modulate = Color("fff1ad")
	else:
		scale = Vector2.ONE
		modulate = Color.WHITE


func _build_visual() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("263449") if face_down else Color("f4ead5")
	panel_style.border_color = Color("d0a85c") if face_down else card.accent_color
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	panel_style.shadow_size = 5
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	var card_margin: int = 5 if face_down else 8
	margin.add_theme_constant_override("margin_left", card_margin)
	margin.add_theme_constant_override("margin_top", card_margin)
	margin.add_theme_constant_override("margin_right", card_margin)
	margin.add_theme_constant_override("margin_bottom", card_margin)
	add_child(margin)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22 if face_down else 28)
	name_label.add_theme_color_override("font_color", Color("f1d18c") if face_down else Color("392b25"))
	name_label.text = "牌" if face_down else card.display_name
	content.add_child(name_label)

	var rule := Label.new()
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rule.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.autowrap_mode = TextServer.AUTOWRAP_OFF
	rule.clip_text = true
	rule.add_theme_font_size_override("font_size", 13)
	rule.add_theme_color_override("font_color", Color("aebbd0") if face_down else Color("5d4c40"))
	rule.text = "基础牌" if face_down else _short_rule(card.card_type)
	content.add_child(rule)

	tooltip_text = "" if face_down else card.description


func _short_rule(card_type: Card.CardType) -> String:
	match card_type:
		Card.CardType.SLASH:
			return "指定敌方\n需【闪】抵消\n造成 1 点伤害"
		Card.CardType.DODGE:
			return "响应【杀】\n令本次伤害\n无效"
		Card.CardType.PEACH:
			return "回复 1 体力\n濒死时\n可以自救"
		Card.CardType.WINE:
			return "下一张【杀】\n伤害 +1\n濒死时自救"
	return ""


func _gui_input(event: InputEvent) -> void:
	if face_down:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		card_clicked.emit(hand_index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if face_down or card == null:
		return null
	var preview := CardView.new()
	preview.configure(card, hand_index)
	preview.modulate = Color(1.0, 1.0, 1.0, 0.88)
	set_drag_preview(preview)
	return {
		"kind": "hand_card",
		"hand_index": hand_index,
	}

class_name PlayerDropZone
extends PanelContainer
## 角色目标区：接收手牌拖放，也支持点击选中目标。

signal card_dropped(hand_index: int, target_index: int)
signal target_clicked(target_index: int)

@export_range(0, 1, 1) var player_index: int = 0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		target_clicked.emit(player_index)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		data is Dictionary
		and data.get("kind", "") == "hand_card"
		and data.has("hand_index")
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(int(data["hand_index"]), player_index)

